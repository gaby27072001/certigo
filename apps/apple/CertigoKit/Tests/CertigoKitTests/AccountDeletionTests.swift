import CertigoDomain
import Foundation
import XCTest

@testable import CertigoData

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
private func deletionBody(_ status: String = "pending") -> Data {
    let steps = status == "completed" ? 6 : 2
    let completedAt = status == "completed" ? "\"2026-10-20T15:01:00Z\"" : "null"
    let retry = status == "pending" ? "5" : "null"
    return Data(
        ("{\"status\":\"\(status)\",\"completedSteps\":\(steps),\"totalSteps\":6,"
            + "\"requestedAt\":\"2026-10-20T15:00:00Z\",\"completedAt\":\(completedAt),"
            + "\"failureCode\":null,\"retryAfterSeconds\":\(retry)}").utf8)
}
private actor DeletionRaceTransport: HTTPTransport {
    private var continuation: CheckedContinuation<Void, Never>?
    func waiting() -> Bool { continuation != nil }
    func resume() {
        continuation?.resume()
        continuation = nil
    }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let body: Data
        if request.httpMethod == "POST" {
            await withCheckedContinuation { continuation = $0 }
            body = try fixture("result")
        } else {
            body = Data(
                #"{"id":"owner-A","displayName":"Synthetic","xp":0,"activeTrackId":null}"#.utf8)
        }
        return (
            body,
            HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
        )
    }
}
final class AccountDeletionTests: XCTestCase {
    func testBodylessRouteProofAndPendingAreExact() async throws {
        let transport = StubTransport(body: deletionBody(), status: 202)
        let api = try CertigoAPI(
            baseURL: URL(string: "https://certigo.test/api")!, transport: transport)
        let status = try await api.accountDeletion(
            accessToken: "synthetic-access", proof: "synthetic.id.proof", submit: true)
        XCTAssertEqual(status.status, .pending)
        XCTAssertEqual(status.retryAfterSeconds, 5)
        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://certigo.test/api/account/deletion")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "X-Certigo-Reauthentication"), "synthetic.id.proof")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-access")
        XCTAssertNotNil(
            request.value(forHTTPHeaderField: "x-correlation-id").flatMap(UUID.init(uuidString:)))
    }

    func testOnlyExplicitCompletedContractAllowsCompletion() async throws {
        for (code, status) in [(202, "completed"), (200, "pending"), (201, "completed")] {
            let api = try CertigoAPI(
                baseURL: URL(string: "https://certigo.test/api")!,
                transport: StubTransport(body: deletionBody(status), status: code))
            do {
                _ = try await api.accountDeletion(accessToken: "synthetic", submit: true)
                XCTFail("Mismatched status/HTTP accepted")
            } catch { XCTAssertEqual(error as? APIError, .invalidResponse) }
        }
        let api = try CertigoAPI(
            baseURL: URL(string: "https://certigo.test/api")!,
            transport: StubTransport(body: deletionBody("completed")))
        let status = try await api.accountDeletion(accessToken: "synthetic")
        XCTAssertEqual(status.status, .completed)
        let invalid = String(decoding: deletionBody(), as: UTF8.self)
            .replacingOccurrences(of: #""completedSteps":2"#, with: #""completedSteps":7"#)
        XCTAssertThrowsError(
            try CertigoAPI.decoder().decode(AccountDeletion.self, from: Data(invalid.utf8))
                .validated())
    }

    func testUnavailableUnauthorizedAndVersionedBaseNeverBecomeSuccess() async throws {
        for code in [401, 403, 409, 429, 503] {
            let transport = StubTransport(
                body: Data("private diagnostic must not be displayed".utf8), status: code)
            let api = try CertigoAPI(
                baseURL: URL(string: "https://certigo.test/api")!, transport: transport)
            do {
                _ = try await api.accountDeletion(accessToken: "synthetic", submit: true)
                XCTFail("HTTP failure accepted")
            } catch {
                XCTAssertEqual(error as? APIError, code == 401 ? .unauthorized : .http(code))
            }
        }
        let transport = StubTransport(body: deletionBody(), status: 202)
        let api = try CertigoAPI(
            baseURL: URL(string: "https://certigo.test/api/v1")!, transport: transport)
        do {
            _ = try await api.accountDeletion(accessToken: "synthetic", submit: true)
            XCTFail("Versioned deletion URL accepted")
        } catch { XCTAssertEqual(error as? APIError, .configuration) }
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testProofRejectsWrongAccountAudienceOrStaleAuthTimeAndRedacts() async throws {
        let now = Date(timeIntervalSince1970: 10_000)
        for (account, aud, authTime, accepted) in [
            ("original", "client", 9_999, true), ("different", "client", 9_999, false),
            ("original", "other-client", 9_999, false), ("original", "client", 9_399, false),
            ("original", "client", 10_121, false),
        ] {
            let payload = Data(#"{"aud":"\#(aud)","auth_time":\#(authTime),"exp":20000}"#.utf8)
                .base64EncodedString().replacingOccurrences(of: "=", with: "")
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            let proof = CIAMDeletionProof(
                accessToken: CIAMAccessToken(
                    value: "synthetic-sensitive-access", expiresAt: now.addingTimeInterval(60)),
                idToken: "synthetic.\(payload).signature", accountIdentifier: account)
            XCTAssertEqual(String(describing: proof), "CIAMDeletionProof(redacted)")
            XCTAssertEqual(String(reflecting: proof), "CIAMDeletionProof(redacted)")
            if accepted {
                XCTAssertNoThrow(
                    try proof.validated(expectedAccount: "original", clientID: "client", now: now))
            } else {
                XCTAssertThrowsError(
                    try proof.validated(expectedAccount: "original", clientID: "client", now: now))
            }
        }
    }

    func testScopedPurgePreservesOtherOwnersScopesAndSharedBlobs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let cache = try RuntimeContentStore(root: root.appendingPathComponent("runtime"))
        let first = try RuntimeFixture()
        let second = try RuntimeFixture(owner: "owner-B")
        let otherScope = try RuntimeFixture(apiScope: "https://other.test/api")
        for fixture in [first, second, otherScope] { try fixture.activate(cache) }
        try cache.retainPins([
            RuntimeManifestPin(
                ownerId: "owner-A", apiScope: first.snapshot.apiScope,
                manifestId: first.snapshot.manifest.manifestId),
            RuntimeManifestPin(
                ownerId: "owner-B", apiScope: first.snapshot.apiScope,
                manifestId: first.snapshot.manifest.manifestId),
        ])
        let store = SubmissionStore(file: root.appendingPathComponent("outbox.json"))
        let a = SavedSubmission(
            ownerId: "owner-A", apiScope: first.snapshot.apiScope, lessonId: "fixture-lesson",
            submission: submission())
        let b = SavedSubmission(
            ownerId: "owner-B", apiScope: first.snapshot.apiScope, lessonId: "fixture-lesson",
            submission: submission(attemptId: UUID().uuidString))
        let other = SavedSubmission(
            ownerId: "owner-A", apiScope: otherScope.snapshot.apiScope, lessonId: "fixture-lesson",
            submission: submission(attemptId: UUID().uuidString))
        _ = try await store.enqueue(a)
        _ = try await store.enqueue(b)
        _ = try await store.enqueue(other)
        try await store.purge(ownerId: "owner-A", apiScope: first.snapshot.apiScope)
        try cache.purge(ownerId: "owner-A", apiScope: first.snapshot.apiScope)
        try cache.purge(ownerId: "owner-A", apiScope: first.snapshot.apiScope)
        let retained = try await store.entries(
            ownerId: "owner-B", apiScope: first.snapshot.apiScope)
        XCTAssertEqual(retained, [b])
        let retainedScope = try await store.entries(
            ownerId: "owner-A", apiScope: otherScope.snapshot.apiScope)
        XCTAssertEqual(retainedScope, [other])
        // A late cancellation continuation must never reopen a purged scope.
        await store.suspend(ownerId: "owner-A", apiScope: first.snapshot.apiScope, suspended: false)
        do {
            _ = try await store.enqueue(a)
            XCTFail("Late enqueue resurrected deleted owner")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        XCTAssertNil(try cache.active(ownerId: "owner-A", apiScope: first.snapshot.apiScope))
        XCTAssertNotNil(try cache.active(ownerId: "owner-B", apiScope: first.snapshot.apiScope))
        XCTAssertNotNil(
            try cache.active(ownerId: "owner-A", apiScope: otherScope.snapshot.apiScope))
        XCTAssertFalse(
            try cache.retainedPins().contains {
                $0.ownerId == "owner-A" && $0.apiScope == first.snapshot.apiScope
            })
        let reopened = SubmissionStore(file: root.appendingPathComponent("outbox.json"))
        let deleted = try await reopened.entries(
            ownerId: "owner-A", apiScope: first.snapshot.apiScope)
        XCTAssertTrue(deleted.isEmpty)
    }

    func testLateACKCannotRewriteOutboxAfterDeletionBarrier() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let server = DeletionRaceTransport()
        let store = SubmissionStore(file: root.appendingPathComponent("outbox.json"))
        let client = LearningClient(
            api: try CertigoAPI(
                baseURL: URL(string: "https://certigo.test/api")!, transport: server),
            store: store)
        _ = try await client.connect(accessToken: "synthetic")
        let task = Task {
            try await client.submit(lessonId: "fixture-lesson", submission: submission())
        }
        for _ in 0..<10_000 {
            if await server.waiting() { break }
            await Task.yield()
        }
        let waiting = await server.waiting()
        XCTAssertTrue(waiting)
        guard waiting else {
            task.cancel()
            return
        }
        _ = try await client.pauseForAccountDeletion()
        try await client.purgeDeletedAccount(ownerId: "owner-A")
        await server.resume()
        do {
            _ = try await task.value
            XCTFail("Late ACK accepted after purge")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        let entries = try await store.entries(
            ownerId: "owner-A", apiScope: "https://certigo.test/api")
        XCTAssertTrue(entries.isEmpty)
    }
}
