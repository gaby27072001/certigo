import CertigoDomain
import Foundation
import XCTest

@testable import CertigoData

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
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
