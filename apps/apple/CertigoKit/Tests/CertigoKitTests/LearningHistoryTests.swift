import CertigoDomain
import Foundation
import XCTest

@testable import CertigoData

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
private func historyBytes(cursor: String? = nil) -> Data {
    Data(
        ("{\"items\":[{\"kind\":\"quiz\",\"attemptId\":\"server-result\","
            + "\"clientAttemptId\":\"11111111-1111-4111-8111-111111111111\","
            + "\"trackId\":\"track\",\"lessonId\":\"lesson\","
            + "\"submittedAt\":\"2026-10-20T14:00:00Z\",\"scorePct\":80,"
            + "\"answeredCount\":5,\"correctCount\":4,\"xpEarned\":25,\"gemsEarned\":0,"
            + "\"publicManifestId\":null}],\"nextCursor\":"
            + (cursor.map { "\"\($0)\"" } ?? "null") + "}").utf8)
}
private actor HistoryRaceTransport: HTTPTransport {
    private var owner = "owner-A"
    private var waiter: CheckedContinuation<Void, Never>?
    func setOwner(_ value: String) { owner = value }
    func waiting() -> Bool { waiter != nil }
    func resume() {
        waiter?.resume()
        waiter = nil
    }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        if request.url?.path.hasSuffix("/me/history") == true {
            await withCheckedContinuation { waiter = $0 }
            data = historyBytes()
        } else {
            data = Data(
                "{\"id\":\"\(owner)\",\"displayName\":\"Synthetic\",\"xp\":0,\"activeTrackId\":null}"
                    .utf8)
        }
        return (
            data,
            HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
        )
    }
}
final class LearningHistoryTests: XCTestCase {
    private func page(_ bytes: Data = historyBytes()) throws -> LearningHistoryPage {
        try CertigoAPI.decoder().decode(LearningHistoryPage.self, from: bytes)
    }

    func testHistoryRouteAndSummaryAreDistinctFromCorrection() async throws {
        let transport = StubTransport(body: historyBytes(cursor: "opaque_cursor-1"))
        let api = try CertigoAPI(
            baseURL: URL(string: "https://certigo.test/api")!, transport: transport)
        let page = try await api.history(
            credentials: APICredentials(ownerId: "owner-A", accessToken: "synthetic"),
            limit: 7, cursor: "opaque_cursor-0")
        XCTAssertEqual(page.items.first?.xpEarned, 25)
        XCTAssertEqual(page.nextCursor, "opaque_cursor-1")
        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(
            request.url?.absoluteString,
            "https://certigo.test/api/me/history?limit=7&cursor=opaque_cursor-0")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testClosedSummaryRejectsInvalidFieldsAndPrivatePayloads() throws {
        let valid = try XCTUnwrap(
            JSONSerialization.jsonObject(with: historyBytes()) as? [String: Any])
        let items = try XCTUnwrap(valid["items"] as? [[String: Any]])
        let first = try XCTUnwrap(items.first)
        let invalid: [(String, Any)] = [
            ("kind", "exam"), ("attemptId", ""), ("clientAttemptId", "with space"),
            ("trackId", ""), ("lessonId", String(repeating: "x", count: 257)),
            ("scorePct", 101), ("answeredCount", -1), ("correctCount", 6),
            ("xpEarned", -1), ("gemsEarned", -1), ("scorePct", 2.5),
            ("publicManifestId", "private-manifest"), ("submittedAt", "not-a-date"),
            ("results", [["correctAnswer": ["private"]]]),
            ("userId", "untrusted-owner"), ("explanation", "private"),
        ]
        for (key, value) in invalid {
            var row = first
            row[key] = value
            var object = valid
            object["items"] = [row]
            XCTAssertThrowsError(try page(JSONSerialization.data(withJSONObject: object)), key)
        }
        for key in first.keys {
            var row = first
            row.removeValue(forKey: key)
            var object = valid
            object["items"] = [row]
            XCTAssertThrowsError(try page(JSONSerialization.data(withJSONObject: object)), key)
        }
        for cursor in ["", "a&userId=owner", String(repeating: "x", count: 2_049)] {
            XCTAssertThrowsError(try page(historyBytes(cursor: cursor)))
        }
        let empty = try page(Data(#"{"items":[],"nextCursor":"still_more"}"#.utf8))
        XCTAssertTrue(empty.items.isEmpty)
        XCTAssertEqual(empty.nextCursor, "still_more")
        XCTAssertThrowsError(
            try page(Data(#"{"items":[],"nextCursor":null,"userId":"owner"}"#.utf8)))
    }

    func testQueryValidationAndHTTPFailuresNeverBecomeEmptyHistory() async throws {
        for code in [201, 202, 204, 400, 401, 423, 429, 503] {
            let api = try CertigoAPI(
                baseURL: URL(string: "https://certigo.test/api")!,
                transport: StubTransport(body: historyBytes(), status: code))
            do {
                _ = try await api.history(
                    credentials: APICredentials(ownerId: "owner-A", accessToken: "synthetic"))
                XCTFail("HTTP \(code) accepted")
            } catch {
                XCTAssertEqual(
                    error as? APIError,
                    code == 401 ? .unauthorized : code < 300 ? .invalidResponse : .http(code))
            }
        }
        let transport = StubTransport(body: historyBytes())
        let api = try CertigoAPI(
            baseURL: URL(string: "https://certigo.test/api")!, transport: transport)
        let credentials = APICredentials(ownerId: "owner-A", accessToken: "synthetic")
        for (limit, cursor) in [(0, nil), (51, nil), (20, ""), (20, "x&userId=y")] {
            do {
                _ = try await api.history(credentials: credentials, limit: limit, cursor: cursor)
                XCTFail("Invalid query accepted")
            } catch { XCTAssertEqual(error as? APIError, .configuration) }
        }
        let versioned = try CertigoAPI(
            baseURL: URL(string: "https://certigo.test/api/v1")!, transport: transport)
        do {
            _ = try await versioned.history(credentials: credentials)
            XCTFail("Versioned route accepted")
        } catch { XCTAssertEqual(error as? APIError, .configuration) }
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
        let offline = try CertigoAPI(
            baseURL: URL(string: "https://certigo.test/api")!,
            transport: StubTransport(body: Data(), failure: URLError(.notConnectedToInternet)))
        do {
            _ = try await offline.history(credentials: credentials)
            XCTFail("Offline became empty")
        } catch {
            XCTAssertEqual(error as? APIError, .transport(URLError.notConnectedToInternet.rawValue))
        }
    }

    func testLearningClientRejectsLateOwnerResponseWithoutTouchingOutbox() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            if FileManager.default.fileExists(atPath: root.path) {
                do { try FileManager.default.removeItem(at: root) } catch {
                    XCTFail("Synthetic history fixture cleanup failed")
                }
            }
        }
        let transport = HistoryRaceTransport()
        let store = SubmissionStore(file: root.appendingPathComponent("outbox.json"))
        let client = LearningClient(
            api: try CertigoAPI(
                baseURL: URL(string: "https://certigo.test/api")!, transport: transport),
            store: store)
        _ = try await client.connect(accessToken: "synthetic-A")
        let task = Task { try await client.history() }
        for _ in 0..<10_000 {
            if await transport.waiting() { break }
            await Task.yield()
        }
        let waiting = await transport.waiting()
        XCTAssertTrue(waiting)
        guard waiting else {
            task.cancel()
            return
        }
        await client.disconnect()
        await transport.setOwner("owner-B")
        _ = try await client.connect(accessToken: "synthetic-B")
        await transport.resume()
        do {
            _ = try await task.value
            XCTFail("Late owner history was displayed")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testDeterministicMergeKeepsLocalWorkAndNeverFabricatesCorrection() throws {
        let row = try XCTUnwrap(page().items.first)
        let submission = QuizSubmission(
            clientAttemptId: row.clientAttemptId.lowercased(), trackId: row.trackId,
            startedAt: Date(timeIntervalSince1970: 1_000),
            answers: [QuizAnswer(itemId: "q", itemType: "mcq", selected: ["a"], latencyMs: 0)],
            publicManifestId: nil)
        let pending = SavedSubmission(
            ownerId: "owner-A", apiScope: "scope-A", lessonId: row.lessonId,
            submission: submission)
        var failed = pending
        failed.status = .failed
        let original = failed
        let merged = try LearningHistoryPresentation(
            server: [row, row], local: [failed], ownerId: "owner-A", apiScope: "scope-A")
        XCTAssertEqual(merged.confirmed.count, 1)
        XCTAssertTrue(merged.onDevice.isEmpty)
        XCTAssertTrue(merged.confirmedOnDevice.isEmpty)
        XCTAssertEqual(failed, original)
        XCTAssertNil(failed.result)
        XCTAssertEqual(failed.status, .failed)
        let otherOwner = try LearningHistoryPresentation(
            server: [], local: [pending], ownerId: "owner-B", apiScope: "scope-A")
        XCTAssertTrue(otherOwner.onDevice.isEmpty)
        let otherScope = try LearningHistoryPresentation(
            server: [], local: [pending], ownerId: "owner-A", apiScope: "scope-B")
        XCTAssertTrue(otherScope.onDevice.isEmpty)
        let localOnly = try LearningHistoryPresentation(
            server: [], local: [pending], ownerId: "owner-A", apiScope: "scope-A")
        XCTAssertEqual(localOnly.onDevice, [pending])
        var ack = pending
        ack.status = .corrected
        ack.result = try CertigoAPI.decoder().decode(QuizResult.self, from: fixture("result"))
        let acknowledged = try LearningHistoryPresentation(
            server: [], local: [ack], ownerId: "owner-A", apiScope: "scope-A")
        XCTAssertEqual(acknowledged.confirmedOnDevice, [ack])
        XCTAssertThrowsError(
            try LearningHistoryPresentation(
                server: [row], local: [ack], ownerId: "owner-A", apiScope: "scope-A"))
    }

    func testConflictsRejectInsteadOfLastWriterWinsAndTiesAreStable() throws {
        let first = try XCTUnwrap(page().items.first)
        let bytes = String(decoding: historyBytes(), as: UTF8.self)
        let second = try XCTUnwrap(
            page(
                Data(
                    bytes.replacingOccurrences(of: "server-result", with: "z-result")
                        .replacingOccurrences(
                            of: "11111111-1111-4111-8111-111111111111",
                            with: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
                        ).utf8)
            ).items.first)
        let upper = try XCTUnwrap(
            page(
                Data(
                    bytes.replacingOccurrences(
                        of: "11111111-1111-4111-8111-111111111111",
                        with: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
                    )
                    .replacingOccurrences(of: "server-result", with: "z-result").utf8)
            ).items.first)
        XCTAssertEqual(
            try LearningHistoryPresentation.summaries([first, second, upper]).map(\.attemptId),
            ["z-result", "server-result"])
        for replacement in [
            ("\"track\"", "\"other-track\""), ("\"lesson\"", "\"other-lesson\""),
            ("\"scorePct\":80", "\"scorePct\":79"),
            (
                "\"publicManifestId\":null",
                "\"publicManifestId\":\"sha256:\(String(repeating: "a", count: 64))\""
            ),
        ] {
            let changed = try XCTUnwrap(
                page(
                    Data(
                        bytes.replacingOccurrences(
                            of: replacement.0, with: replacement.1
                        ).utf8)
                ).items.first)
            XCTAssertThrowsError(try LearningHistoryPresentation.summaries([first, changed]))
        }
        let wrongTrack = SavedSubmission(
            ownerId: "owner", apiScope: "scope", lessonId: first.lessonId,
            submission: QuizSubmission(
                clientAttemptId: first.clientAttemptId, trackId: "different",
                startedAt: Date(), answers: [], publicManifestId: nil))
        XCTAssertThrowsError(
            try LearningHistoryPresentation(
                server: [first], local: [wrongTrack], ownerId: "owner", apiScope: "scope"))
        let manifest = "sha256:" + String(repeating: "a", count: 64)
        let pinned = try XCTUnwrap(
            page(
                Data(
                    bytes.replacingOccurrences(
                        of: "\"publicManifestId\":null",
                        with: "\"publicManifestId\":\"\(manifest)\""
                    ).utf8)
            ).items.first)
        let wrongManifest = SavedSubmission(
            ownerId: "owner", apiScope: "scope", lessonId: first.lessonId,
            submission: QuizSubmission(
                clientAttemptId: first.clientAttemptId, trackId: first.trackId,
                startedAt: Date(), answers: [],
                publicManifestId: "sha256:" + String(repeating: "b", count: 64)))
        XCTAssertThrowsError(
            try LearningHistoryPresentation(
                server: [pinned], local: [wrongManifest], ownerId: "owner", apiScope: "scope"))
    }
}
