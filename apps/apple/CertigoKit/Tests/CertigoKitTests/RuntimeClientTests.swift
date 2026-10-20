import CertigoDomain
import Foundation
import XCTest

@testable import CertigoData

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
private final class ActivationWriteFailure: @unchecked Sendable {
    private let lock = NSLock()
    private var stateWrites = 0

    func check(_ point: RuntimeWritePoint, _ name: String) throws {
        guard point == .beforeRename, name == "state.json" else { return }
        lock.lock()
        defer { lock.unlock() }
        stateWrites += 1
        // An existing archive writes staging first, then the activation pointer.
        if stateWrites == 2 { throw URLError(.cannotWriteToFile) }
    }
}
private actor RuntimeTransport: BoundedHTTPTransport {
    private var fixture: RuntimeFixture
    private var failingIndex: Int?
    private var pauseNext = false
    private var waiter: CheckedContinuation<Void, Never>?
    private var counts: [String: Int] = [:]
    init(_ fixture: RuntimeFixture) { self.fixture = fixture }
    func setFixture(_ value: RuntimeFixture) { fixture = value }
    func fail(_ index: Int?) { failingIndex = index }
    func pauseNextFile() { pauseNext = true }
    func isWaiting() -> Bool { waiter != nil }
    func resume() {
        waiter?.resume()
        waiter = nil
    }
    func requestCount(_ hash: String) -> Int { counts[hash, default: 0] }

    func send(_ request: URLRequest, maximumBytes: Int) async throws -> (Data, HTTPURLResponse) {
        let captured = fixture
        let manifest = captured.snapshot.manifest
        let url = try XCTUnwrap(request.url)
        let data: Data
        var headers = [
            "X-Content-Release-Id": captured.snapshot.binding.releaseId,
            "X-Content-Manifest-Id": manifest.manifestId, "Content-Type": "application/json",
        ]
        if url.path.hasSuffix("/active/manifest") {
            data = manifest.bytes
            headers["ETag"] = "\"\(manifest.manifestId)\""
            headers["Cache-Control"] = "private, no-cache"
        } else {
            let index = try XCTUnwrap(
                manifest.files.firstIndex {
                    url.path.hasSuffix("/\($0.hash)/\($0.path)")
                })
            let file = manifest.files[index]
            counts[file.hash, default: 0] += 1
            if pauseNext {
                pauseNext = false
                await withCheckedContinuation { waiter = $0 }
            }
            if failingIndex == index { throw URLError(.notConnectedToInternet) }
            data = captured.files[index]
            headers["ETag"] = "\"sha256:\(file.hash)\""
            headers["X-Content-SHA256"] = file.hash
            headers["Content-Length"] = String(file.size)
            headers["Accept-Ranges"] = "none"
            headers["Cache-Control"] = "private, max-age=31536000, immutable"
        }
        return (
            data,
            try XCTUnwrap(
                HTTPURLResponse(
                    url: url, statusCode: 200,
                    httpVersion: nil, headerFields: headers))
        )
    }
}
@MainActor
final class RuntimeClientTests: XCTestCase {
    func testVerifiedMCQPendingRestartAndPinnedReplayOnlyUseServerFeedback() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let initial = try RuntimeFixture()
        let source = RuntimeTransport(initial)
        let server = RoutingTransport()
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: initial.snapshot.apiScope)), transport: server)
        let cacheRoot = root.appendingPathComponent("cache")
        let queueFile = root.appendingPathComponent("outbox.json")
        let cache = try RuntimeContentStore(root: cacheRoot)
        let client = LearningClient(
            api: api, store: SubmissionStore(file: queueFile),
            runtimeStore: cache, runtimeTransport: source)
        _ = try await client.connect(accessToken: "synthetic-only")
        let active = try await client.synchronizePublicContent()
        let file = active.manifest.files[1]
        let bytes = try XCTUnwrap(cache.cachedFile(file))
        let question = try CanonicalQuestionReader.decode(bytes)
        try question.requireBasicCapability()
        guard case .identified(let options) = question.options else {
            return XCTFail("Expected public identified MCQ options")
        }
        let selected = try XCTUnwrap(options.first?.id)
        let request = QuizSubmission(
            clientAttemptId: "602c351a-19c0-44c9-99da-1a0d8c9b43c3",
            trackId: question.metadata.certification,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            answers: [
                QuizAnswer(
                    itemId: question.id, itemType: question.itemType,
                    selected: [selected], latencyMs: 321)
            ],
            publicManifestId: active.manifest.manifestId)
        await server.setOffline(true)
        let pending = try await client.submit(
            lessonId: "synthetic-bank-session", submission: request)
        XCTAssertEqual(pending, .pendingCorrection)
        let pendingEntries = try await client.savedSubmissions()
        let saved = try XCTUnwrap(pendingEntries.first)
        XCTAssertEqual(saved.status, .pendingCorrection)
        XCTAssertNil(saved.result)
        XCTAssertEqual(saved.submission, request)
        await client.disconnect()

        let reopenedCache = try RuntimeContentStore(root: cacheRoot)
        let restarted = LearningClient(
            api: api, store: SubmissionStore(file: queueFile),
            runtimeStore: reopenedCache, runtimeTransport: source)
        _ = try await restarted.connect(accessToken: "synthetic-only")
        let restored = try await restarted.savedSubmissions()
        XCTAssertEqual(restored, [saved])
        let restoredContent = try await restarted.cachedPublicContent()
        XCTAssertEqual(restoredContent?.binding, active.binding)
        XCTAssertEqual(try reopenedCache.cachedFile(file), bytes)
        await server.setOwner("owner-B")
        _ = try await restarted.connect(accessToken: "synthetic-B")
        let otherQueue = try await restarted.savedSubmissions()
        XCTAssertTrue(otherQueue.isEmpty)
        let otherContent = try await restarted.cachedPublicContent()
        XCTAssertNil(otherContent)
        do {
            _ = try await restarted.retry(attemptId: request.clientAttemptId)
            XCTFail("Another owner replayed the pending attempt")
        } catch { XCTAssertEqual(error as? StoreError, .invalidRecord) }
        await server.setOwner("owner-A")
        _ = try await restarted.connect(accessToken: "synthetic-A")
        let next = try RuntimeFixture(version: 1)
        await source.setFixture(next)
        _ = try await restarted.synchronizePublicContent()
        XCTAssertTrue(
            try reopenedCache.retainedPins().contains(
                RuntimeManifestPin(
                    ownerId: saved.ownerId, apiScope: saved.apiScope,
                    manifestId: active.manifest.manifestId)))

        var response = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixture("result")) as? [String: Any])
        var results = try XCTUnwrap(response["results"] as? [[String: Any]])
        results[0]["itemId"] = question.id
        results[0]["correct"] = false
        results[0]["correctAnswer"] = [try XCTUnwrap(options.dropFirst().first?.id)]
        results[0]["explanation"] = "Synthetic authoritative feedback after replay only."
        response["results"] = results
        response["scorePct"] = 0
        let responseBytes = try JSONSerialization.data(withJSONObject: response)
        await server.setResult(responseBytes)
        await server.setOffline(false)
        let corrected = try await restarted.retry(attemptId: request.clientAttemptId)
        guard case .corrected(let result) = corrected else {
            return XCTFail("Mock server did not correct the pending attempt")
        }
        XCTAssertEqual(result.scorePct, 0)
        XCTAssertFalse(try XCTUnwrap(result.results.first).correct)
        XCTAssertEqual(
            result.results.first?.explanation,
            "Synthetic authoritative feedback after replay only.")
        let payloads = await server.posts()
        XCTAssertEqual(payloads.count, 2)
        XCTAssertEqual(payloads[0], payloads[1])
        let wire = try CertigoAPI.decoder().decode(QuizSubmission.self, from: payloads[1])
        XCTAssertEqual(wire, request)
        let finalQueue = try await SubmissionStore(file: queueFile).entries(
            ownerId: saved.ownerId, apiScope: saved.apiScope)
        XCTAssertEqual(finalQueue.first?.result, result)
        let repeatResult = try await restarted.retry(attemptId: request.clientAttemptId)
        XCTAssertEqual(repeatResult, corrected)
        let afterRepeat = await server.posts()
        XCTAssertEqual(afterRepeat.count, 2)
    }

    func testLogoutDuringReleaseFetchCannotPublishOrActivateCandidate() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let fixture = try RuntimeFixture()
        let source = RuntimeTransport(fixture)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: fixture.snapshot.apiScope)),
            transport: RoutingTransport())
        let cache = try RuntimeContentStore(root: root.appendingPathComponent("cache"))
        let client = LearningClient(
            api: api, store: SubmissionStore(file: root.appendingPathComponent("outbox.json")),
            runtimeStore: cache, runtimeTransport: source)
        _ = try await client.connect(accessToken: "synthetic-only")
        _ = try await client.synchronizePublicContent()
        await source.setFixture(try RuntimeFixture(version: 1))
        await source.pauseNextFile()
        let request = Task { try await client.synchronizePublicContent() }
        try await waitForSuspension(source)
        await client.disconnect()
        await source.resume()
        do {
            _ = try await request.value
            XCTFail("Logged-out candidate published")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        do {
            _ = try await client.cachedPublicContent()
            XCTFail("Logged-out content exposed")
        } catch { XCTAssertEqual(error as? APIError, .unauthorized) }
        XCTAssertEqual(
            try cache.active(ownerId: "owner-A", apiScope: api.scope)?.binding,
            fixture.snapshot.binding)
    }

    func testInterruptedReplacementKeepsActiveAndPreviousAcrossRestart() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let first = try RuntimeFixture()
        let source = RuntimeTransport(first)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: first.snapshot.apiScope)), transport: RoutingTransport())
        let cacheRoot = root.appendingPathComponent("cache")
        let queueFile = root.appendingPathComponent("outbox.json")
        let client = LearningClient(
            api: api, store: SubmissionStore(file: queueFile),
            runtimeStore: try RuntimeContentStore(root: cacheRoot), runtimeTransport: source)
        _ = try await client.connect(accessToken: "synthetic-only")
        _ = try await client.synchronizePublicContent()
        let second = try RuntimeFixture(version: 1)
        await source.setFixture(second)
        _ = try await client.synchronizePublicContent()
        let candidate = try RuntimeFixture(version: 2)
        await source.setFixture(candidate)
        await source.fail(0)
        do {
            _ = try await client.synchronizePublicContent()
            XCTFail("Interrupted candidate activated")
        } catch {
            XCTAssertEqual(error as? APIError, .transport(URLError.notConnectedToInternet.rawValue))
        }
        let reopened = try RuntimeContentStore(root: cacheRoot)
        XCTAssertEqual(
            try reopened.active(ownerId: "owner-A", apiScope: api.scope)?.binding,
            second.snapshot.binding)
        XCTAssertEqual(
            try reopened.previous(ownerId: "owner-A", apiScope: api.scope)?.binding,
            first.snapshot.binding)
        let restarted = LearningClient(
            api: api, store: SubmissionStore(file: queueFile),
            runtimeStore: reopened, runtimeTransport: source)
        _ = try await restarted.connect(accessToken: "synthetic-only")
        await source.fail(nil)
        let activated = try await restarted.synchronizePublicContent()
        XCTAssertEqual(activated.binding, candidate.snapshot.binding)
        XCTAssertEqual(
            try reopened.previous(ownerId: "owner-A", apiScope: api.scope)?.binding,
            second.snapshot.binding)
    }

    func testUnsupportedCandidateFailsStagingWithoutReplacingReleaseOrChangingQueue() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let supported = try RuntimeFixture()
        let source = RuntimeTransport(supported)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: supported.snapshot.apiScope)),
            transport: RoutingTransport())
        let cache = try RuntimeContentStore(root: root.appendingPathComponent("cache"))
        let client = LearningClient(
            api: api, store: SubmissionStore(file: root.appendingPathComponent("outbox.json")),
            runtimeStore: cache, runtimeTransport: source)
        _ = try await client.connect(accessToken: "synthetic-only")
        _ = try await client.synchronizePublicContent()
        let unsupported = try RuntimeFixture(version: 1, secondItemType: "spotTheIssue")
        await source.setFixture(unsupported)
        do {
            _ = try await client.synchronizePublicContent()
            XCTFail("Unsupported exercise activated as MCQ")
        } catch {
            XCTAssertEqual(
                error as? CanonicalContentError, .unsupportedCapability("itemType:spotTheIssue"))
        }
        let active = try await client.cachedPublicContent()
        XCTAssertEqual(active?.binding, supported.snapshot.binding)
        XCTAssertNil(try cache.cachedFile(unsupported.snapshot.manifest.files[1]))
        let saved = try await client.savedSubmissions()
        XCTAssertTrue(saved.isEmpty)
    }

    func testActivationPointerWriteFailureKeepsActiveAndPreviousForRestartedClient() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let first = try RuntimeFixture()
        let second = try RuntimeFixture(version: 1)
        let candidate = try RuntimeFixture(version: 2)
        let cacheRoot = root.appendingPathComponent("cache")
        let initial = try RuntimeContentStore(root: cacheRoot)
        try first.activate(initial)
        try second.activate(initial)
        let failure = ActivationWriteFailure()
        let interrupted = try RuntimeContentStore(root: cacheRoot, fault: failure.check)
        let source = RuntimeTransport(candidate)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: first.snapshot.apiScope)), transport: RoutingTransport())
        let queueFile = root.appendingPathComponent("outbox.json")
        let client = LearningClient(
            api: api, store: SubmissionStore(file: queueFile),
            runtimeStore: interrupted, runtimeTransport: source)
        _ = try await client.connect(accessToken: "synthetic-only")
        do {
            _ = try await client.synchronizePublicContent()
            XCTFail("Uncommitted activation returned success")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .cannotWriteToFile)
        }
        let reopened = try RuntimeContentStore(root: cacheRoot)
        XCTAssertEqual(
            try reopened.active(ownerId: "owner-A", apiScope: api.scope)?.binding,
            second.snapshot.binding)
        XCTAssertEqual(
            try reopened.previous(ownerId: "owner-A", apiScope: api.scope)?.binding,
            first.snapshot.binding)
        XCTAssertEqual(
            try reopened.cachedFile(candidate.snapshot.manifest.files[0]), candidate.files[0])
        let restarted = LearningClient(
            api: api, store: SubmissionStore(file: queueFile),
            runtimeStore: reopened, runtimeTransport: source)
        _ = try await restarted.connect(accessToken: "synthetic-only")
        let visible = try await restarted.cachedPublicContent()
        XCTAssertEqual(visible?.binding, second.snapshot.binding)
        let activated = try await restarted.synchronizePublicContent()
        XCTAssertEqual(activated.binding, candidate.snapshot.binding)
        XCTAssertEqual(
            try reopened.previous(ownerId: "owner-A", apiScope: api.scope)?.binding,
            second.snapshot.binding)
    }

    func testInterruptedDownloadResumesWithVerifiedCASWithoutActivatingPartialRelease() async throws
    {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let fixture = try RuntimeFixture()
        let transport = RuntimeTransport(fixture)
        let profile = RoutingTransport()
        let cache = try RuntimeContentStore(root: root.appendingPathComponent("cache"))
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: fixture.snapshot.apiScope)), transport: profile)
        let queue = SubmissionStore(file: root.appendingPathComponent("outbox.json"))
        let client = LearningClient(
            api: api, store: queue, runtimeStore: cache, runtimeTransport: transport)
        _ = try await client.connect(accessToken: "synthetic-only")
        await transport.fail(1)
        do {
            _ = try await client.synchronizePublicContent()
            XCTFail("Partial release activated")
        } catch {
            XCTAssertEqual(error as? APIError, .transport(URLError.notConnectedToInternet.rawValue))
        }
        let absent = try await client.cachedPublicContent()
        XCTAssertNil(absent)
        let restarted = LearningClient(
            api: api, store: queue,
            runtimeStore: try RuntimeContentStore(root: root.appendingPathComponent("cache")),
            runtimeTransport: transport)
        _ = try await restarted.connect(accessToken: "synthetic-only")
        await transport.fail(nil)
        let active = try await restarted.synchronizePublicContent()
        XCTAssertEqual(active.binding, fixture.snapshot.binding)
        let firstCount = await transport.requestCount(fixture.snapshot.manifest.files[0].hash)
        let secondCount = await transport.requestCount(fixture.snapshot.manifest.files[1].hash)
        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(secondCount, 2)
    }

    func testOwnerSwitchDuringDownloadCannotActivateOrPublishOldOwnerContent() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let fixture = try RuntimeFixture()
        let transport = RuntimeTransport(fixture)
        let profile = RoutingTransport()
        let cache = try RuntimeContentStore(root: root.appendingPathComponent("cache"))
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: fixture.snapshot.apiScope)), transport: profile)
        let client = LearningClient(
            api: api, store: SubmissionStore(file: root.appendingPathComponent("outbox.json")),
            runtimeStore: cache, runtimeTransport: transport)
        _ = try await client.connect(accessToken: "synthetic-A")
        await transport.pauseNextFile()
        let request = Task { try await client.synchronizePublicContent() }
        try await waitForSuspension(transport)
        await profile.setOwner("owner-B")
        _ = try await client.connect(accessToken: "synthetic-B")
        await transport.resume()
        do {
            _ = try await request.value
            XCTFail("Old owner activation published")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        let absent = try await client.cachedPublicContent()
        XCTAssertNil(absent)
        XCTAssertNil(try cache.active(ownerId: "owner-A", apiScope: api.scope))
    }

    func testDeletionBarrierPreventsLateDownloadedFilesAndActivation() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let fixture = try RuntimeFixture()
        let transport = RuntimeTransport(fixture)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: fixture.snapshot.apiScope)),
            transport: RoutingTransport())
        let cacheRoot = root.appendingPathComponent("cache")
        let cache = try RuntimeContentStore(root: cacheRoot)
        let client = LearningClient(
            api: api, store: SubmissionStore(file: root.appendingPathComponent("outbox.json")),
            runtimeStore: cache, runtimeTransport: transport)
        _ = try await client.connect(accessToken: "synthetic-only")
        await transport.pauseNextFile()
        let request = Task { try await client.synchronizePublicContent() }
        try await waitForSuspension(transport)
        _ = try await client.pauseForAccountDeletion()
        try await client.purgeDeletedAccount(ownerId: "owner-A")
        await transport.resume()
        do {
            _ = try await request.value
            XCTFail("Late download activated after account purge")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        XCTAssertNil(try cache.active(ownerId: "owner-A", apiScope: api.scope))
        let remaining = try FileManager.default.contentsOfDirectory(atPath: cacheRoot.path)
        XCTAssertFalse(remaining.contains { $0.hasPrefix("x-") || $0.hasPrefix("b-") })
    }

    func testNewerSyncWinsAndLateGenerationCannotOverwriteItsActivePointer() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let first = try RuntimeFixture()
        let transport = RuntimeTransport(first)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: first.snapshot.apiScope)), transport: RoutingTransport())
        let client = LearningClient(
            api: api, store: SubmissionStore(file: root.appendingPathComponent("outbox.json")),
            runtimeStore: try RuntimeContentStore(root: root.appendingPathComponent("cache")),
            runtimeTransport: transport)
        _ = try await client.connect(accessToken: "synthetic-only")
        _ = try await client.synchronizePublicContent()
        let next = try RuntimeFixture(version: 1)
        await transport.setFixture(next)
        await transport.pauseNextFile()
        let oldRequest = Task { try await client.synchronizePublicContent() }
        try await waitForSuspension(transport)
        let winner = try await client.synchronizePublicContent()
        await transport.resume()
        do {
            _ = try await oldRequest.value
            XCTFail("Old generation republished")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        let actual = try await client.cachedPublicContent()
        XCTAssertEqual(winner.binding, next.snapshot.binding)
        XCTAssertEqual(actual?.binding, winner.binding)
    }

    func testOriginalPendingAttemptAndOtherOwnerPinsRemainAfterNewActivation() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let fixture = try RuntimeFixture()
        let profile = RoutingTransport()
        let source = RuntimeTransport(fixture)
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: fixture.snapshot.apiScope)), transport: profile)
        let queue = SubmissionStore(file: root.appendingPathComponent("outbox.json"))
        let cache = try RuntimeContentStore(root: root.appendingPathComponent("cache"))
        let original = submission()
        let pinned = QuizSubmission(
            clientAttemptId: original.clientAttemptId,
            trackId: original.trackId, startedAt: original.startedAt, answers: original.answers,
            publicManifestId: fixture.snapshot.manifest.manifestId)
        let other = QuizSubmission(
            clientAttemptId: "343c0c62-fccc-4453-a880-16d75a7a4071",
            trackId: original.trackId, startedAt: original.startedAt, answers: original.answers,
            publicManifestId: fixture.snapshot.manifest.manifestId)
        _ = try await queue.enqueue(
            SavedSubmission(
                ownerId: "owner-B", apiScope: "https://other.test/api",
                lessonId: "fixture-lesson", submission: other))
        let client = LearningClient(
            api: api, store: queue, runtimeStore: cache, runtimeTransport: source)
        _ = try await client.connect(accessToken: "synthetic-only")
        _ = try await client.synchronizePublicContent()
        await profile.setOffline(true)
        let outcome = try await client.submit(lessonId: "fixture-lesson", submission: pinned)
        XCTAssertEqual(outcome, .pendingCorrection)
        for version in 1..<4 {
            try await source.setFixture(RuntimeFixture(version: version))
            _ = try await client.synchronizePublicContent()
        }
        _ = try await client.cleanupPublicContent()
        let entries = try await client.savedSubmissions()
        XCTAssertEqual(entries.first?.submission, pinned)
        XCTAssertEqual(entries.first?.status, .pendingCorrection)
        XCTAssertNil(entries.first?.result)
        let pins = try RuntimeContentStore(root: root.appendingPathComponent("cache"))
            .retainedPins()
        XCTAssertEqual(Set(pins.map(\.ownerId)), ["owner-A", "owner-B"])
        XCTAssertEqual(try cache.cachedFile(fixture.snapshot.manifest.files[0]), fixture.files[0])
    }

    func testInvalidAttemptCannotPersistAPinBeforeSubmissionValidation() async throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let fixture = try RuntimeFixture()
        let api = try CertigoAPI(
            baseURL: XCTUnwrap(URL(string: fixture.snapshot.apiScope)),
            transport: RoutingTransport())
        let queue = SubmissionStore(file: root.appendingPathComponent("outbox.json"))
        let cache = try RuntimeContentStore(root: root.appendingPathComponent("cache"))
        let client = LearningClient(api: api, store: queue, runtimeStore: cache)
        _ = try await client.connect(accessToken: "synthetic-only")
        let original = submission()
        let invalid = QuizSubmission(
            clientAttemptId: "", trackId: original.trackId,
            startedAt: original.startedAt, answers: original.answers,
            publicManifestId: fixture.snapshot.manifest.manifestId)
        do {
            _ = try await client.submit(lessonId: "fixture-lesson", submission: invalid)
            XCTFail("Invalid attempt accepted")
        } catch { XCTAssertTrue(error is ContractError) }
        XCTAssertTrue(try cache.retainedPins().isEmpty)
        let saved = try await queue.entries(ownerId: "owner-A", apiScope: api.scope)
        XCTAssertTrue(saved.isEmpty)
    }

    private func waitForSuspension(_ transport: RuntimeTransport) async throws {
        for _ in 0..<10_000 {
            if await transport.isWaiting() { return }
            await Task.yield()
        }
        XCTFail("Synthetic file transport did not suspend")
        throw APIError.invalidResponse
    }
    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "certigo-runtime-client-\(UUID().uuidString)")
    }
}
