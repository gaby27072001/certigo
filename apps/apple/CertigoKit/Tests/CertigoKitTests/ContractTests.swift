import CertigoData
import CertigoDomain
import Foundation
import XCTest

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
func fixture(_ name: String) throws -> Data {
    let url = try XCTUnwrap(
        Bundle.module.url(
            forResource: name, withExtension: "json", subdirectory: "Fixtures"
        ))
    return try Data(contentsOf: url)
}
func submission(attemptId: String = "767f6ce0-a771-4165-b830-e340807a191c") -> QuizSubmission {
    QuizSubmission(
        clientAttemptId: attemptId, trackId: "fixture:foundations",
        startedAt: Date(timeIntervalSince1970: 1_700_000_000.123),
        answers: [
            QuizAnswer(
                itemId: "fixture-question", itemType: "mcq", selected: ["first"], latencyMs: 250
            )
        ], publicManifestId: nil
    )
}
actor StubTransport: HTTPTransport {
    private let body: Data
    private let status: Int
    private let failure: URLError?
    private let headers: [String: String]
    private var requests: [URLRequest] = []

    init(body: Data, status: Int = 200, failure: URLError? = nil, headers: [String: String] = [:]) {
        self.body = body
        self.status = status
        self.failure = failure
        self.headers = headers
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let failure { throw failure }
        let response = HTTPURLResponse(
            url: request.url!, statusCode: status, httpVersion: nil,
            headerFields: headers.merging(["Content-Type": "application/json"]) { first, _ in first
            }
        )!
        return (body, response)
    }

    func recordedRequests() -> [URLRequest] { requests }
}
final class ContractTests: XCTestCase {
    func testCatalogUsesExistingVersionedProjection() throws {
        let value = try CertigoAPI.decoder().decode(Catalog.self, from: fixture("catalog"))
            .validated()
        XCTAssertEqual(value.tracks[0].id, "fixture:foundations")
    }

    func testCatalogFutureSchemaIsUnsupportedNotMalformed() throws {
        let json = String(decoding: try fixture("catalog"), as: UTF8.self)
            .replacingOccurrences(of: "catalog/v2", with: "catalog/v99")
        let value = try CertigoAPI.decoder().decode(Catalog.self, from: Data(json.utf8))
        XCTAssertThrowsError(try value.validated()) {
            XCTAssertEqual($0 as? ContractError, .unsupported("catalog schema"))
        }
    }

    func testPublicLessonUsesOptionLabelsAndContainsNoAnswerKeys() throws {
        let value = try CertigoAPI.decoder().decode(Lesson.self, from: fixture("lesson"))
            .validated(trackId: "fixture:foundations", lessonId: "fixture-lesson")
        XCTAssertEqual(value.questions[0].options[0].label, "First synthetic option")
        let json = String(decoding: try CertigoAPI.encoder().encode(value), as: UTF8.self)
        XCTAssertFalse(json.contains("correctAnswer"))
        XCTAssertFalse(json.contains("answerKey"))
    }

    func testUnsupportedExerciseCannotStartAsMCQ() throws {
        let json = String(decoding: try fixture("lesson"), as: UTF8.self)
            .replacingOccurrences(of: "\"mcq\"", with: "\"ordering\"")
        let lesson = try CertigoAPI.decoder().decode(Lesson.self, from: Data(json.utf8))
        XCTAssertThrowsError(
            try lesson.validated(
                trackId: "fixture:foundations", lessonId: "fixture-lesson"
            )
        ) {
            XCTAssertEqual($0 as? ContractError, .unsupported("itemType:ordering"))
        }
    }

    func testResultCannotInventUnrequestedItems() throws {
        let result = try CertigoAPI.decoder().decode(QuizResult.self, from: fixture("result"))
        XCTAssertEqual(try result.validated(for: submission()).rewards.xpEarned, 10)
        XCTAssertThrowsError(
            try result.validated(
                for: QuizSubmission(
                    clientAttemptId: submission().clientAttemptId, trackId: "fixture:foundations",
                    startedAt: Date(), answers: [], publicManifestId: nil
                )))
    }

    func testCorrectResultMayOmitCorrectAnswerIDs() throws {
        let json = String(decoding: try fixture("result"), as: UTF8.self)
            .replacingOccurrences(
                of: "\"correctAnswer\": [\"first\"]", with: "\"correctAnswer\": null")
        let result = try CertigoAPI.decoder().decode(QuizResult.self, from: Data(json.utf8))
        XCTAssertNil(try result.validated(for: submission()).results[0].correctAnswer)
    }

    func testServerMayOmitUnknownAnsweredItemsWithoutInventedResults() throws {
        let result = try CertigoAPI.decoder().decode(QuizResult.self, from: fixture("result"))
        let input = QuizSubmission(
            clientAttemptId: submission().clientAttemptId, trackId: submission().trackId,
            startedAt: submission().startedAt,
            answers: submission().answers + [
                QuizAnswer(itemId: "unknown", itemType: "mcq", selected: ["first"], latencyMs: 1)
            ], publicManifestId: nil
        )
        XCTAssertEqual(try result.validated(for: input).results.count, 1)
    }

    func testSubmissionRoundTripPreservesWireTimeAndAttemptID() throws {
        let input = submission()
        let encoded = try CertigoAPI.encoder().encode(input)
        let decoded = try CertigoAPI.decoder().decode(QuizSubmission.self, from: encoded)
        XCTAssertEqual(input, decoded)
        let wire = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNil(wire["ownerId"])
        XCTAssertNil(wire["userId"])
        XCTAssertEqual(wire["startedAt"] as? String, "2023-11-14T22:13:20.123Z")
    }

    func testConfigurationRejectsHTTPAndCredentialsInURL() {
        for text in [
            "http://example.invalid/api", "https://user:pass@example.invalid/api",
            "https://example.invalid/api?token=secret",
        ] {
            XCTAssertThrowsError(try CertigoAPI(baseURL: URL(string: text)!))
        }
    }

    @MainActor
    func testAPIEncodesExistingSubmitRouteAndRawAnswers() async throws {
        let transport = StubTransport(body: try fixture("result"))
        let api = try CertigoAPI(
            baseURL: URL(string: "https://example.invalid/api")!, transport: transport
        )
        let result = try await api.submit(
            lessonId: "fixture-lesson", submission: submission(),
            credentials: APICredentials(ownerId: "owner-A", accessToken: "test-only")
        )
        XCTAssertEqual(result.scorePct, 100)
        let requests = await transport.recordedRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].url?.path, "/api/quiz/fixture-lesson/submit")
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertNotNil(requests[0].value(forHTTPHeaderField: "x-correlation-id"))
        XCTAssertEqual(requests[0].httpBody, try CertigoAPI.encoder().encode(submission()))
    }

    @MainActor
    func testNonSuccessAndMalformedPayloadNeverBecomeSuccess() async throws {
        for status in [401, 403, 429, 500] {
            let api = try CertigoAPI(
                baseURL: URL(string: "https://example.invalid/api")!,
                transport: StubTransport(body: Data("{}".utf8), status: status)
            )
            do {
                _ = try await api.profile(accessToken: "test-only")
                XCTFail("HTTP \(status) became success")
            } catch let error as APIError {
                XCTAssertEqual(error, status == 401 ? .unauthorized : .http(status))
            }
        }
        let api = try CertigoAPI(
            baseURL: URL(string: "https://example.invalid/api")!,
            transport: StubTransport(body: Data("{}".utf8))
        )
        do {
            _ = try await api.profile(accessToken: "test-only")
            XCTFail("Missing profile identity became success")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }
}
