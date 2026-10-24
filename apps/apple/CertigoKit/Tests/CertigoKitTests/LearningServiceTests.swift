import CertigoData
import CertigoDomain
import Foundation
import XCTest

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
private let servicePin = "sha256:" + String(repeating: "a", count: 64)
private let tutorJSON = """
    {"itemId":"item","conceptId":"concept","correct":false,"headline":"Synthetic explanation",
    "points":["Synthetic point"],"encouragement":"Keep practicing","recommendation":"Review",
    "citedConceptIds":["concept"],"source":"grounded","personalization":{"attempts":2,"errors":1,
    "accuracyPct":50,"recurringStruggle":true,"masteredBefore":false,"trend":"stable",
    "topConfusedOption":null}}
    """
private let recommendationsJSON = """
    {"trackId":"track","generatedAt":"2026-10-21T10:00:00Z","items":[
    {"kind":"review","lessonId":"lesson","unitId":"unit","conceptId":null,"title":"Review",
    "domainId":"domain","domainName":"Domain","reason":"Source language reason",
    "estMinutes":7,"priority":90,"masteryPct":40,"forgettingRiskPct":70}]}
    """
private let examJSON = """
    {"examId":"exam","trackId":"track","trackCode":"TEST","trackTitle":"Synthetic",
    "timeLimitSeconds":60,"passingScore":700,"blueprint":[
    {"domainId":"domain","name":"Domain","weight":1.0,"itemCount":1}],
    "items":[{"itemId":"item","lessonId":"lesson","domainId":"domain","type":"mcq",
    "stem":"Synthetic?","options":[{"id":"a","label":"A"},{"id":"b","label":"B"}]}],
    "publicManifestId":"\(servicePin)"}
    """
private let examResultJSON = """
    {"attemptId":"result","examId":"exam","scaledScore":900,"pct":90,"passed":true,
    "passingScore":700,"correct":1,"total":1,"domains":[{"domainId":"domain","name":"Domain",
    "weight":1.0,"correct":1,"total":1,"pct":100}],"results":[{"itemId":"item",
    "conceptId":"concept","correct":true,"correctAnswer":null,"explanation":"Synthetic",
    "masteryDelta":0.1}],"rewards":{"xpEarned":1,"newXp":1,"levelUp":false,
    "streakExtended":false,"gemsEarned":0,"achievementsUnlocked":[]},"weakConcepts":[]}
    """
private let achievementJSON = """
    {"unlocked":1,"total":1,"achievements":[{"id":"a","kind":"practice","name":"Synthetic",
    "description":"Synthetic","tier":"bronze","threshold":1,"progress":1,"rewardGems":0,"unlocked":true}]}
    """
private let questJSON = """
    {"date":"2026-10-21","gems":0,"quests":[{"id":"q","kind":"practice","title":"Synthetic",
    "target":1,"current":0,"rewardGems":1,"completed":false,"claimed":false,"claimable":false}]}
    """
private let notificationJSON = """
    {"localDate":"2026-10-21","notifications":[{"kind":"review","priority":"high",
    "scheduledUtc":"2026-10-21T19:00:00Z","localHour":19,"mascot":"synthetic","title":"Review",
    "body":"Review concept","deeplink":"certigo://review","dedupeKey":"key"}]}
    """
private let settingsJSON = """
    {"enabled":false,"utcOffsetMinutes":60,"quietHoursStart":22,"quietHoursEnd":7,
    "preferredHour":19,"maxPerDay":2,"streakAlerts":true,"questAlerts":false,"leagueAlerts":false}
    """
private func tutorRequest() -> TutorExplainRequest {
    .init(
        trackId: "track", lessonId: "lesson", itemId: "item", selected: ["b"],
        publicManifestId: servicePin)
}
private func examSubmission() -> SubmitMockExamRequest {
    .init(
        clientAttemptId: "11111111-1111-4111-8111-111111111111", trackId: "track",
        examId: "exam", startedAt: Date(timeIntervalSince1970: 1_700_000_000),
        answers: [.init(itemId: "item", itemType: "mcq", selected: ["a"], latencyMs: 100)])
}
private actor ServiceRaceTransport: HTTPTransport {
    private var waiter: CheckedContinuation<Void, Never>?
    private let body: Data
    init(body: String) { self.body = Data(body.utf8) }
    func waiting() -> Bool { waiter != nil }
    func release() {
        waiter?.resume()
        waiter = nil
    }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let result: Data
        if request.url?.path == "/api/me" {
            result = Data(
                #"{"id":"owner","displayName":"Synthetic","xp":0,"activeTrackId":null}"#.utf8)
        } else {
            await withCheckedContinuation { waiter = $0 }
            result = body
        }
        return (
            result,
            HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!
        )
    }
}
final class LearningServiceTests: XCTestCase {
    private let credentials = APICredentials(ownerId: "owner", accessToken: "synthetic")
    private func api(_ transport: any HTTPTransport, prefix: String = "/api") throws -> CertigoAPI {
        try CertigoAPI(baseURL: URL(string: "https://certigo.test\(prefix)")!, transport: transport)
    }

    private func roundTrip<T: Codable & Equatable>(_ type: T.Type, json: String) throws {
        let value = try CertigoAPI.decoder().decode(type, from: Data(json.utf8))
        XCTAssertEqual(
            try CertigoAPI.decoder().decode(type, from: CertigoAPI.encoder().encode(value)), value)
    }

    func testDTOsRoundTripExactBackendShapesAndNullableFields() throws {
        try roundTrip(TutorExplanation.self, json: tutorJSON)
        try roundTrip(NextBestRecommendations.self, json: recommendationsJSON)
        try roundTrip(MockExam.self, json: examJSON)
        try roundTrip(MockExamResult.self, json: examResultJSON)
        try roundTrip(AchievementBoard.self, json: achievementJSON)
        try roundTrip(QuestBoard.self, json: questJSON)
        try roundTrip(NotificationPlan.self, json: notificationJSON)
        try roundTrip(NotificationSettings.self, json: settingsJSON)
        let explanation = try CertigoAPI.decoder().decode(
            TutorExplanation.self, from: Data(tutorJSON.utf8))
        XCTAssertNil(explanation.personalization.topConfusedOption)
        XCTAssertEqual(explanation.personalization.attempts, 2)
        let request = tutorRequest()
        XCTAssertEqual(
            try CertigoAPI.decoder().decode(
                TutorExplainRequest.self, from: CertigoAPI.encoder().encode(request)), request)
        let legacy = TutorExplainRequest(
            trackId: "track", lessonId: "lesson", itemId: "item", selected: [])
        XCTAssertNil(
            try CertigoAPI.decoder().decode(
                TutorExplainRequest.self, from: CertigoAPI.encoder().encode(legacy)
            ).publicManifestId)
        let submit = examSubmission()
        XCTAssertEqual(
            try CertigoAPI.decoder().decode(
                SubmitMockExamRequest.self, from: CertigoAPI.encoder().encode(submit)), submit)
    }

    func testTutorUsesAuthenticatedPostAndPreservesPinWithoutOwnerInBody() async throws {
        let transport = StubTransport(body: Data(tutorJSON.utf8))
        let value = try await api(transport).explainAnswer(tutorRequest(), credentials: credentials)
        XCTAssertFalse(value.correct)
        let requests = await transport.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/api/tutor/explain")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody)
        XCTAssertEqual(
            try CertigoAPI.decoder().decode(TutorExplainRequest.self, from: body), tutorRequest())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(
            Set(object.keys), ["trackId", "lessonId", "itemId", "selected", "publicManifestId"])
    }

    func testEveryServiceUsesExpectedRouteMethodAndRequestShape() async throws {
        let cases: [(String, String, String)] = [
            (recommendationsJSON, "/api/me/recommendations/track", "GET"),
            (examJSON, "/api/exam/generate", "POST"),
            (examResultJSON, "/api/exam/submit", "POST"),
            (achievementJSON, "/api/achievements", "GET"),
            (questJSON, "/api/quests", "GET"),
            (notificationJSON, "/api/me/notifications/plan", "GET"),
            (settingsJSON, "/api/me/notifications/settings", "GET"),
            (settingsJSON, "/api/me/notifications/settings", "POST"),
        ]
        for (index, entry) in cases.enumerated() {
            let transport = StubTransport(body: Data(entry.0.utf8))
            try await call(index, api: api(transport))
            let requests = await transport.recordedRequests()
            let request = try XCTUnwrap(requests.first)
            XCTAssertEqual(request.url?.path, entry.1)
            XCTAssertEqual(request.httpMethod, entry.2)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic")
            if entry.2 == "GET" { XCTAssertNil(request.httpBody) }
            if index == 1 {
                let body = try CertigoAPI.decoder().decode(
                    MockExamRequest.self, from: XCTUnwrap(request.httpBody))
                XCTAssertEqual(body.publicManifestId, servicePin)
            }
            if index == 2 {
                let body = try CertigoAPI.decoder().decode(
                    SubmitMockExamRequest.self, from: XCTUnwrap(request.httpBody))
                XCTAssertEqual(body.clientAttemptId, examSubmission().clientAttemptId)
            }
        }
    }

    private func call(_ index: Int, api: CertigoAPI) async throws {
        switch index {
        case 0:
            _ = try await api.nextBestRecommendations(trackId: "track", credentials: credentials)
        case 1:
            _ = try await api.generateMockExam(
                .init(trackId: "track", publicManifestId: servicePin), credentials: credentials)
        case 2: _ = try await api.submitMockExam(examSubmission(), credentials: credentials)
        case 3: _ = try await api.achievements(credentials: credentials)
        case 4: _ = try await api.quests(credentials: credentials)
        case 5: _ = try await api.notificationPlan(credentials: credentials)
        case 6: _ = try await api.notificationSettings(credentials: credentials)
        default:
            let settings = try CertigoAPI.decoder().decode(
                NotificationSettings.self, from: Data(settingsJSON.utf8))
            _ = try await api.updateNotificationSettings(settings, credentials: credentials)
        }
    }

    func testHTTPFailuresInvalidResponsesAndUnsupportedRoutesRemainExplicit() async throws {
        for status in [201, 204, 401, 403, 429, 503] {
            do {
                _ = try await api(StubTransport(body: Data(tutorJSON.utf8), status: status))
                    .explainAnswer(tutorRequest(), credentials: credentials)
                XCTFail("Accepted \(status)")
            } catch {
                XCTAssertEqual(
                    error as? APIError,
                    status == 401 ? .unauthorized : status < 300 ? .invalidResponse : .http(status))
            }
        }
        for json in [
            "{}",
            tutorJSON.replacingOccurrences(of: "\"itemId\":\"item\"", with: "\"itemId\":\"other\""),
            tutorJSON.replacingOccurrences(of: "\"accuracyPct\":50", with: "\"accuracyPct\":101"),
        ] {
            do {
                _ = try await api(StubTransport(body: Data(json.utf8))).explainAnswer(
                    tutorRequest(), credentials: credentials)
                XCTFail("Malformed response accepted")
            } catch { XCTAssertEqual(error as? APIError, .invalidResponse) }
        }
        for index in 0..<8 {
            let transport = StubTransport(body: Data("{}".utf8))
            do {
                try await call(index, api: api(transport, prefix: "/api/v1"))
                XCTFail("Unsupported route prefix accepted")
            } catch { XCTAssertEqual(error as? APIError, .configuration) }
            let requests = await transport.recordedRequests()
            XCTAssertTrue(requests.isEmpty)
        }
        let transport = StubTransport(
            body: Data(tutorJSON.utf8), failure: URLError(.notConnectedToInternet))
        do {
            _ = try await api(transport).explainAnswer(tutorRequest(), credentials: credentials)
            XCTFail("Offline request succeeded")
        } catch {
            XCTAssertEqual(error as? APIError, .transport(URLError.notConnectedToInternet.rawValue))
        }
    }

    func testClientRejectsTutorResponseAfterDisconnect() async throws {
        let transport = ServiceRaceTransport(body: tutorJSON)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("store")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let client = LearningClient(api: try api(transport), store: SubmissionStore(file: file))
        _ = try await client.connect(accessToken: "synthetic")
        let task = Task { try await client.explainAnswer(tutorRequest()) }
        while !(await transport.waiting()) { await Task.yield() }
        await client.disconnect()
        await transport.release()
        do {
            _ = try await task.value
            XCTFail("Stale tutor response accepted")
        } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        do {
            _ = try await client.explainAnswer(tutorRequest())
            XCTFail("Disconnected tutor request accepted")
        } catch { XCTAssertEqual(error as? APIError, .unauthorized) }
    }

    func testEmptyExamIsRepresentableAndUnsupportedQuestionCannotBeRendered() throws {
        let empty = """
            {"examId":"exam","trackId":"track","trackCode":"TEST","trackTitle":"Test",
            "timeLimitSeconds":0,"passingScore":700,"blueprint":[],"items":[]}
            """
        XCTAssertTrue(
            try CertigoAPI.decoder().decode(MockExam.self, from: Data(empty.utf8)).validated().items
                .isEmpty)
        let unsupported = examJSON.replacingOccurrences(
            of: "\"type\":\"mcq\"", with: "\"type\":\"multi\"")
        XCTAssertThrowsError(
            try CertigoAPI.decoder().decode(MockExam.self, from: Data(unsupported.utf8)).validated()
        ) {
            XCTAssertEqual($0 as? ContractError, .unsupported("exam itemType:multi"))
        }
    }

    func testAllServiceActorsRejectResponsesAfterSessionChanges() async throws {
        let bodies = [
            recommendationsJSON, examJSON, examResultJSON, achievementJSON, questJSON,
            notificationJSON, settingsJSON, settingsJSON,
        ]
        for (index, body) in bodies.enumerated() {
            let transport = ServiceRaceTransport(body: body)
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let client = LearningClient(
                api: try api(transport),
                store: SubmissionStore(file: directory.appendingPathComponent("store")))
            _ = try await client.connect(accessToken: "synthetic")
            let task = Task {
                switch index {
                case 0: _ = try await client.nextBestRecommendations(trackId: "track")
                case 1:
                    _ = try await client.generateMockExam(
                        .init(trackId: "track", publicManifestId: servicePin))
                case 2: _ = try await client.submitMockExam(examSubmission())
                case 3: _ = try await client.achievements()
                case 4: _ = try await client.quests()
                case 5: _ = try await client.notificationPlan()
                case 6: _ = try await client.notificationSettings()
                default:
                    let settings = try CertigoAPI.decoder().decode(
                        NotificationSettings.self, from: Data(settingsJSON.utf8))
                    _ = try await client.updateNotificationSettings(settings)
                }
            }
            while !(await transport.waiting()) { await Task.yield() }
            _ = try await client.connect(accessToken: "new-generation")
            await transport.release()
            do {
                try await task.value
                XCTFail("Stale service \(index) accepted")
            } catch { XCTAssertEqual(error as? APIError, .staleSession) }
        }
    }

    func testOptionalPathProfileAndLanguageEvidenceIsNotFabricatedWhenAbsent() throws {
        let minimal = try JSONDecoder().decode(
            Profile.self,
            from: Data(
                #"{"id":"owner","displayName":"Synthetic","xp":0,"activeTrackId":null}"#.utf8))
        XCTAssertNil(minimal.level)
        XCTAssertNil(minimal.streakDays)
        let full = try JSONDecoder().decode(
            Profile.self,
            from: Data(
                #"{"id":"owner","displayName":"Synthetic","xp":10,"activeTrackId":"track","level":2,"streakDays":3,"dailyGoalXp":50,"dailyXpEarned":20,"gems":4}"#
                    .utf8))
        XCTAssertEqual(full.level, 2)
        XCTAssertEqual(full.streakDays, 3)
        XCTAssertEqual(full.dailyGoalXp, 50)
        XCTAssertEqual(full.dailyXpEarned, 20)
        XCTAssertEqual(full.gems, 4)
        let path = """
            {"trackId":"track","trackName":"Track","readinessScore":60,"readinessTrend7d":5,
            "domains":[{"id":"domain","name":"Domain","weight":1.0,"score":60}],
            "units":[{"id":"unit","title":"Unit","domainId":"domain","status":"inProgress",
            "lessons":[{"id":"lesson","title":"Lesson","status":"available","estMinutes":5,"masteryPct":60}]}]}
            """
        let decoded = try JSONDecoder().decode(LearningPath.self, from: Data(path.utf8))
        XCTAssertEqual(decoded.domains?.first?.score, 60)
        XCTAssertEqual(decoded.units.first?.domainId, "domain")
        XCTAssertEqual(decoded.units.first?.status, "inProgress")
        XCTAssertEqual(decoded.units.first?.lessons.first?.masteryPct, 60)
        XCTAssertEqual(decoded.readinessTrend7d, 5)
        let track =
            #"{"id":"track","code":"TEST","title":"Track","summary":"Synthetic","learningAvailable":true,"languages":["fr","en"]}"#
        XCTAssertEqual(
            try JSONDecoder().decode(Track.self, from: Data(track.utf8)).languages, ["fr", "en"])
        let legacy = track.replacingOccurrences(of: #","languages":["fr","en"]"#, with: "")
        XCTAssertNil(try JSONDecoder().decode(Track.self, from: Data(legacy.utf8)).languages)
    }

    func testReviewDueDateIsAnOptionalTopLevelServerValue() throws {
        var result = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(examResultJSON.utf8)) as? [String: Any])
        result["scorePct"] = 90
        let absent = try CertigoAPI.decoder().decode(
            QuizResult.self, from: JSONSerialization.data(withJSONObject: result))
        XCTAssertNil(absent.nextReviewDueAt)
        result["nextReviewDueAt"] = "2026-10-24T10:30:00Z"
        let present = try CertigoAPI.decoder().decode(
            QuizResult.self, from: JSONSerialization.data(withJSONObject: result))
        XCTAssertNotNil(present.nextReviewDueAt)
        XCTAssertEqual(
            try CertigoAPI.decoder().decode(
                QuizResult.self, from: CertigoAPI.encoder().encode(present)), present)
        result["nextReviewDueAt"] = "invented-date"
        XCTAssertThrowsError(
            try CertigoAPI.decoder().decode(
                QuizResult.self, from: JSONSerialization.data(withJSONObject: result)))
    }

    func testInvalidIdentitiesAndAllServiceHTTPFailuresDoNotBecomeSuccess() async throws {
        for index in 0..<8 {
            let transport = StubTransport(body: Data("{}".utf8), status: 503)
            do {
                try await call(index, api: api(transport))
                XCTFail("HTTP failure accepted \(index)")
            } catch { XCTAssertEqual(error as? APIError, .http(503)) }
        }
        let wrongTrack = recommendationsJSON.replacingOccurrences(
            of: "\"trackId\":\"track\"", with: "\"trackId\":\"foreign\"")
        do {
            _ = try await api(StubTransport(body: Data(wrongTrack.utf8)))
                .nextBestRecommendations(trackId: "track", credentials: credentials)
            XCTFail("Foreign-track recommendations accepted")
        } catch { XCTAssertEqual(error as? APIError, .invalidResponse) }
        let wrongExam = examResultJSON.replacingOccurrences(
            of: "\"examId\":\"exam\"", with: "\"examId\":\"other\"")
        do {
            _ = try await api(StubTransport(body: Data(wrongExam.utf8)))
                .submitMockExam(examSubmission(), credentials: credentials)
            XCTFail("Foreign exam correction accepted")
        } catch { XCTAssertEqual(error as? APIError, .invalidResponse) }
        let transport = StubTransport(body: Data(examJSON.utf8))
        do {
            _ = try await api(transport).explainAnswer(
                .init(trackId: "", lessonId: "lesson", itemId: "item", selected: []),
                credentials: credentials)
            XCTFail("Empty identity accepted")
        } catch { XCTAssertEqual(error as? APIError, .configuration) }
        let requests = await transport.recordedRequests()
        XCTAssertTrue(requests.isEmpty)
    }
}
