import CertigoData
import CertigoDomain
import Foundation
/// Exact synthetic serializer vectors also exercised by the real C# HTTP functions.
import XCTest

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

private actor GoalWireTransport: HTTPTransport {
    let body: Data
    var requests: [URLRequest] = []
    init(body: Data) { self.body = body }
    func captured() -> [URLRequest] { requests }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (
            body,
            HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json; charset=utf-8"])!
        )
    }
}

final class SharedHTTPWireTests: XCTestCase {
    func testExplicitGoalRejectsResponseForAnotherTarget() async throws {
        let transport = GoalWireTransport(body: try wire("profile"))
        let api = try CertigoAPI(
            baseURL: URL(string: "https://example.invalid/api")!, transport: transport)
        do {
            _ = try await api.setActiveTrack(
                trackId: "different-track", expectedTrackId: "previous-track",
                credentials: APICredentials(ownerId: "demo-owner", accessToken: "synthetic"))
            XCTFail("Mismatched goal accepted")
        } catch {
            XCTAssertEqual(error as? APIError, .invalidResponse)
        }
    }

    func testExplicitGoalUsesPinnedBackendRequestAndAuthoritativeProfileWithoutClientETag()
        async throws
    {
        let transport = GoalWireTransport(body: try wire("profile"))
        let api = try CertigoAPI(
            baseURL: URL(string: "https://example.invalid/api")!, transport: transport)
        let profile = try await api.setActiveTrack(
            trackId: "demo-track", expectedTrackId: nil,
            credentials: APICredentials(ownerId: "demo-owner", accessToken: "synthetic"))
        XCTAssertEqual(profile.id, "demo-owner")
        XCTAssertEqual(profile.activeTrackId, "demo-track")
        XCTAssertEqual(profile.xp, 100)
        let requests = await transport.captured()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/api/me/active-track")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertNil(request.value(forHTTPHeaderField: "If-Match"))
        XCTAssertEqual(
            try object(XCTUnwrap(request.httpBody)) as NSDictionary,
            try object(wire("active-track-request")) as NSDictionary)
    }

    func testSharedCatalogProjectionDecodesNullableMetadataWithoutInventingValues() throws {
        let catalog = try CertigoAPI.decoder().decode(Catalog.self, from: wire("catalog"))
            .validated()
        XCTAssertEqual(catalog.tracks.count, 1)
        XCTAssertEqual(catalog.tracks[0].id, "demo-track")
        XCTAssertEqual(catalog.tracks[0].title, "Synthetic certification")
        XCTAssertTrue(catalog.tracks[0].learningAvailable)
        let raw = try object(wire("catalog"))
        let tracks = try XCTUnwrap(raw["tracks"] as? [[String: Any]])
        XCTAssertTrue(tracks[0]["guide"] is NSNull)
        XCTAssertTrue(tracks[0]["blueprintPublishedOn"] is NSNull)
        XCTAssertEqual(raw["sourceAsOf"] as? String, "2026-10-01")
    }

    func testSharedPathKeepsTheWireStatusWithoutClaimingAnExhaustiveServerEnumeration() throws {
        let path = try CertigoAPI.decoder().decode(LearningPath.self, from: wire("path"))
        XCTAssertEqual(path.trackId, "demo-track")
        XCTAssertEqual(path.readinessScore, 42)
        let lesson = try XCTUnwrap(path.units.first?.lessons.first)
        XCTAssertEqual(lesson.id, "demo-lesson")
        XCTAssertEqual(lesson.status, .available)
        XCTAssertTrue(lesson.canOpen)
    }

    func testSharedLessonNullAndOmittedFieldsDecodeButUnimplementedMatchingStaysUnsupported() throws
    {
        let lesson = try CertigoAPI.decoder().decode(Lesson.self, from: wire("lesson"))
        XCTAssertEqual(lesson.trackId, "demo-track")
        XCTAssertEqual(lesson.blocks.count, 3)
        let questions = lesson.questions
        XCTAssertEqual(questions.map(\.type), ["mcq", "matchPairs"])
        XCTAssertEqual(questions[0].options.map(\.label), ["Option A", "Option B"])
        XCTAssertNoThrow(try questions[0].validateCapability())
        XCTAssertThrowsError(try lesson.validated(trackId: "demo-track", lessonId: "demo-lesson")) {
            XCTAssertEqual($0 as? ContractError, .unsupported("itemType:matchPairs"))
        }
        let raw = try object(wire("lesson"))
        let blocks = try XCTUnwrap(raw["blocks"] as? [[String: Any]])
        let mcq = try XCTUnwrap(blocks[1]["check"] as? [String: Any])
        let pairs = try XCTUnwrap(blocks[2]["check"] as? [String: Any])
        XCTAssertNil(mcq["matches"])
        XCTAssertNotNil(pairs["matches"])
        XCTAssertTrue(blocks[1]["body"] is NSNull)
        XCTAssertNil(mcq["correctAnswer"])
        XCTAssertNil(mcq["explanation"])
    }

    func testSharedRequestIsASerializerVectorNotAnAutomaticallyReplayableNativeAttempt() throws {
        let request = try CertigoAPI.decoder().decode(
            QuizSubmission.self, from: wire("quiz-submit-request"))
        XCTAssertEqual(request.clientAttemptId, "demo-client-attempt")
        XCTAssertEqual(request.trackId, "demo-track")
        XCTAssertEqual(request.answers.map(\.itemId), ["demo-item"])
        XCTAssertEqual(request.answers[0].selected, ["b"])
        XCTAssertEqual(request.answers[0].latencyMs, 4_200)
        XCTAssertEqual(request.publicManifestId, "sha256:" + String(repeating: "0", count: 64))
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(
            request.startedAt, try XCTUnwrap(formatter.date(from: "2026-10-01T12:00:00Z")))
        // The current native creation policy generates UUIDs; the fixture is not a live attempt.
        XCTAssertThrowsError(try request.validated()) {
            XCTAssertEqual($0 as? ContractError, .malformed("submission"))
        }
    }

    func testSharedAuthorizedResultsKeepWrongAnswerIDsAndCorrectNullFeedbackDistinct() throws {
        let request = try CertigoAPI.decoder().decode(
            QuizSubmission.self, from: wire("quiz-submit-request"))
        let wrong = try CertigoAPI.decoder().decode(
            QuizResult.self, from: wire("quiz-submit-result")
        )
        .validated(for: request)
        let correct = try CertigoAPI.decoder().decode(
            QuizResult.self, from: wire("quiz-submit-correct-result")
        )
        .validated(for: request)
        XCTAssertEqual(wrong.scorePct, 0)
        XCTAssertEqual(wrong.results.first?.correctAnswer, ["a"])
        XCTAssertEqual(correct.scorePct, 100)
        XCTAssertEqual(correct.results.first?.correct, true)
        XCTAssertNil(correct.results.first?.correctAnswer)
        XCTAssertEqual(correct.rewards.xpEarned, 10)
        let nullable = try object(wire("quiz-submit-correct-result"))
        XCTAssertTrue(nullable["nextReviewDueAt"] is NSNull)
        // These independent serializer vectors do not grade the request locally.
    }

    private func wire(_ name: String) throws -> Data {
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try Data(contentsOf: root.appendingPathComponent("http-wire/v1/\(name).json"))
    }
    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
