import CertigoData
import CertigoDomain
import Foundation
import XCTest

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
actor RoutingTransport: HTTPTransport {
    var owner = "owner-A"
    var offline = false
    var postCount = 0
    var postPayloads: [Data] = []
    var profileWaiter: CheckedContinuation<Void, Never>?
    var pauseProfile = false
    private var resultBody: Data?
    private var postFailure: URLError.Code?

    func setOwner(_ value: String) { owner = value }
    func setOffline(_ value: Bool) { offline = value }
    func setPauseProfile(_ value: Bool) { pauseProfile = value }
    func resumeProfile() {
        profileWaiter?.resume()
        profileWaiter = nil
    }
    func isWaiting() -> Bool { profileWaiter != nil }
    func posts() -> [Data] { postPayloads }
    func setResult(_ body: Data) { resultBody = body }
    func setPostFailure(_ code: URLError.Code?) { postFailure = code }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body: Data
        if request.httpMethod == "POST" {
            postCount += 1
            postPayloads.append(request.httpBody!)
            if offline { throw URLError(.notConnectedToInternet) }
            if let postFailure { throw URLError(postFailure) }
            body = try resultBody ?? fixture("result")
        } else {
            let capturedOwner = owner
            if pauseProfile {
                await withCheckedContinuation { profileWaiter = $0 }
            }
            body = Data(
                """
                {"id":"\(capturedOwner)","displayName":"Synthetic learner","xp":10,"activeTrackId":null}
                """.utf8)
        }
        return (
            body,
            HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
        )
    }
}
final class SubmissionTests: XCTestCase {
    private func withFile(
        _ operation: (URL) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch {
                XCTFail("Temporary fixture cleanup failed: \(error)")
            }
        }
        try await operation(directory.appendingPathComponent("submissions.json"))
    }

    func testQueueSurvivesRestartWithoutChangingAttemptOrOwner() async throws {
        try await withFile { file in
            let store = SubmissionStore(file: file)
            let entry = SavedSubmission(
                ownerId: "owner-A", apiScope: "https://example.invalid/api",
                lessonId: "fixture-lesson", submission: submission()
            )
            let saved = try await store.enqueue(entry)
            XCTAssertEqual(saved, entry)
            let reopened = SubmissionStore(file: file)
            let restored = try await reopened.entries(
                ownerId: "owner-A", apiScope: "https://example.invalid/api"
            )
            XCTAssertEqual(restored, [entry])
            let otherOwner = try await reopened.entries(
                ownerId: "owner-B", apiScope: "https://example.invalid/api"
            )
            XCTAssertTrue(otherOwner.isEmpty)
            let otherEnvironment = try await reopened.entries(
                ownerId: "owner-A", apiScope: "https://other.invalid/api"
            )
            XCTAssertTrue(otherEnvironment.isEmpty)
        }
    }

    func testSameAttemptCannotBeReassignedToAnotherOwner() async throws {
        try await withFile { file in
            let store = SubmissionStore(file: file)
            _ = try await store.enqueue(
                SavedSubmission(
                    ownerId: "owner-A", apiScope: "scope", lessonId: "fixture-lesson",
                    submission: submission()
                ))
            do {
                _ = try await store.enqueue(
                    SavedSubmission(
                        ownerId: "owner-B", apiScope: "scope", lessonId: "fixture-lesson",
                        submission: submission()
                    ))
                XCTFail("Attempt reassigned to a different account")
            } catch let error as StoreError {
                XCTAssertEqual(error, .conflictingAttempt)
            }
        }
    }

    func testMalformedArchiveIsNotSilentlyReplacedWithEmptyQueue() async throws {
        try await withFile { file in
            try Data("not JSON".utf8).write(to: file)
            let store = SubmissionStore(file: file)
            do {
                _ = try await store.entries(ownerId: "owner-A", apiScope: "scope")
                XCTFail("Corruption became an empty successful queue")
            } catch let error as StoreError {
                XCTAssertEqual(error, .corruptArchive)
            }
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "not JSON")
        }
    }

    func testOfflineAnswerRemainsPendingUntilServerCorrectsExactlySamePayload() async throws {
        try await withFile { file in
            let transport = RoutingTransport()
            let api = try CertigoAPI(
                baseURL: URL(string: "https://example.invalid/api")!, transport: transport
            )
            let client = LearningClient(api: api, store: SubmissionStore(file: file))
            _ = try await client.connect(accessToken: "test-only")
            await transport.setOffline(true)
            let pending = try await client.submit(
                lessonId: "fixture-lesson", submission: submission()
            )
            XCTAssertEqual(pending, .pendingCorrection)
            let entries = try await client.savedSubmissions()
            XCTAssertEqual(entries.count, 1)
            XCTAssertNil(entries[0].result)
            XCTAssertEqual(entries[0].status, .pendingCorrection)
            await transport.setOffline(false)
            let corrected = try await client.retry(attemptId: submission().clientAttemptId)
            guard case .corrected(let result) = corrected else { return XCTFail("Not corrected") }
            XCTAssertEqual(result.rewards.xpEarned, 10)
            let replayed = try await client.retry(attemptId: submission().clientAttemptId)
            XCTAssertEqual(replayed, corrected)
            let payloads = await transport.posts()
            XCTAssertEqual(payloads.count, 2)
            XCTAssertEqual(payloads[0], payloads[1])
            let restored = try await SubmissionStore(file: file).entries(
                ownerId: "owner-A", apiScope: api.scope
            )
            XCTAssertEqual(restored[0].result, result)
        }
    }

    func testOwnerSwitchCannotReplayPreviousAccountQueue() async throws {
        try await withFile { file in
            let transport = RoutingTransport()
            let api = try CertigoAPI(
                baseURL: URL(string: "https://example.invalid/api")!, transport: transport
            )
            let client = LearningClient(api: api, store: SubmissionStore(file: file))
            _ = try await client.connect(accessToken: "test-A")
            await transport.setOffline(true)
            _ = try await client.submit(lessonId: "fixture-lesson", submission: submission())
            await client.disconnect()
            await transport.setOwner("owner-B")
            _ = try await client.connect(accessToken: "test-B")
            do {
                _ = try await client.retry(attemptId: submission().clientAttemptId)
                XCTFail("Account B replayed account A")
            } catch let error as StoreError {
                XCTAssertEqual(error, .invalidRecord)
            }
            let payloads = await transport.posts()
            XCTAssertEqual(payloads.count, 1)
        }
    }

    func testCancelledSubmissionRemainsPendingAndCanReplayAfterRestart() async throws {
        try await checkCancelledRequest(retrying: false)
    }

    func testCancelledRetryRemainsPendingAndCanReplayAfterRestart() async throws {
        try await checkCancelledRequest(retrying: true)
    }

    func testNonCancellationTransportFailureStillRequiresReview() async throws {
        try await withFile { file in
            let transport = RoutingTransport()
            let api = try CertigoAPI(
                baseURL: URL(string: "https://example.invalid/api")!, transport: transport)
            let client = LearningClient(api: api, store: SubmissionStore(file: file))
            _ = try await client.connect(accessToken: "test-only")
            await transport.setPostFailure(.secureConnectionFailed)
            do {
                _ = try await client.submit(
                    lessonId: "fixture-lesson", submission: submission())
                XCTFail("An unsafe connection must not become a successful outcome")
            } catch let error as APIError {
                XCTAssertEqual(error, .transport(URLError.secureConnectionFailed.rawValue))
            }
            let entries = try await SubmissionStore(file: file).entries(
                ownerId: "owner-A", apiScope: api.scope)
            let entry = try XCTUnwrap(entries.first)
            XCTAssertEqual(entry.status, .failed)
            XCTAssertNil(entry.result)
            XCTAssertNotNil(entry.failureCategory)
        }
    }

    private func checkCancelledRequest(retrying: Bool) async throws {
        try await withFile { file in
            let transport = RoutingTransport()
            let api = try CertigoAPI(
                baseURL: URL(string: "https://example.invalid/api")!, transport: transport)
            let client = LearningClient(api: api, store: SubmissionStore(file: file))
            _ = try await client.connect(accessToken: "test-only")
            if retrying {
                await transport.setOffline(true)
                let pending = try await client.submit(
                    lessonId: "fixture-lesson", submission: submission())
                XCTAssertEqual(pending, .pendingCorrection)
                await transport.setOffline(false)
            }
            await transport.setPostFailure(.cancelled)
            do {
                if retrying {
                    _ = try await client.retry(attemptId: submission().clientAttemptId)
                } else {
                    _ = try await client.submit(
                        lessonId: "fixture-lesson", submission: submission())
                }
                XCTFail("Cancellation must propagate, not become a successful outcome")
            } catch let error as APIError {
                XCTAssertEqual(error, .transport(URLError.cancelled.rawValue))
                XCTAssertFalse(error.isRetryable)
            }
            await client.disconnect()
            let reopened = LearningClient(api: api, store: SubmissionStore(file: file))
            _ = try await reopened.connect(accessToken: "test-only")
            let entries = try await reopened.savedSubmissions()
            XCTAssertEqual(entries.count, 1)
            let entry = try XCTUnwrap(entries.first)
            XCTAssertEqual(entry.submission, submission())
            XCTAssertNil(entry.result)
            XCTAssertNil(entry.failureCategory)
            guard entry.status == .pendingCorrection else {
                return XCTFail("Cancellation permanently rejected an unconfirmed submission")
            }
            await transport.setPostFailure(nil)
            let corrected = try await reopened.retry(attemptId: entry.id)
            guard case .corrected(let result) = corrected else {
                return XCTFail("Preserved attempt could not be corrected")
            }
            XCTAssertEqual(result.rewards.xpEarned, 10)
            let replayed = try await reopened.retry(attemptId: entry.id)
            XCTAssertEqual(replayed, corrected)
            let payloads = await transport.posts()
            XCTAssertEqual(payloads.count, retrying ? 3 : 2)
            XCTAssertTrue(payloads.allSatisfy { $0 == payloads.first })
            let saved = try await reopened.savedSubmissions()
            XCTAssertEqual(saved.first?.status, .corrected)
        }
    }

    func testLogoutDuringProfileFetchCannotRestoreSession() async throws {
        try await withFile { file in
            let transport = RoutingTransport()
            await transport.setPauseProfile(true)
            let api = try CertigoAPI(
                baseURL: URL(string: "https://example.invalid/api")!, transport: transport
            )
            let client = LearningClient(api: api, store: SubmissionStore(file: file))
            let connection = Task { try await client.connect(accessToken: "test-only") }
            for _ in 0..<1_000 {
                if await transport.isWaiting() { break }
                await Task.yield()
            }
            let isWaiting = await transport.isWaiting()
            guard isWaiting else {
                connection.cancel()
                return XCTFail("Profile did not suspend")
            }
            await client.disconnect()
            await transport.resumeProfile()
            do {
                _ = try await connection.value
                XCTFail("Logout was overwritten by late profile response")
            } catch let error as APIError {
                XCTAssertEqual(error, .staleSession)
            }
        }
    }
}
