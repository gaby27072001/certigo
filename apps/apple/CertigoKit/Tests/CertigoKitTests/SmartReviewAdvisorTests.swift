import CertigoDomain
import Foundation
import XCTest

@testable import CertigoData

final class SmartReviewAdvisorTests: XCTestCase {
    private func path(_ statuses: [String] = ["available", "available", "locked"]) throws
        -> LearningPath
    {
        let units = statuses.enumerated().map { index, status in
            """
            {"id":"unit\(index)","title":"Unit \(index)","lessons":[
            {"id":"lesson\(index)","title":"Lesson","status":"\(status)","estMinutes":5}]}
            """
        }.joined(separator: ",")
        return try JSONDecoder().decode(
            LearningPath.self,
            from: Data(
                "{\"trackId\":\"track\",\"trackName\":\"Track\",\"readinessScore\":0,\"units\":[\(units)]}"
                    .utf8))
    }

    private func entry(
        lesson: Int, score: Int, attempt: String = "a", date: Int = 21,
        track: String = "track", answered: Int = 1
    ) throws -> QuizAttemptHistoryItem {
        let json = """
            {"kind":"quiz","attemptId":"\(attempt)","clientAttemptId":"\(attempt)",
            "trackId":"\(track)","lessonId":"lesson\(lesson)","submittedAt":"2026-10-\(date)T12:00:00Z",
            "scorePct":\(score),"answeredCount":\(answered),"correctCount":0,
            "xpEarned":0,"gemsEarned":0,"publicManifestId":null}
            """
        return try CertigoAPI.decoder().decode(QuizAttemptHistoryItem.self, from: Data(json.utf8))
    }

    func testFreshLearnerAndLockedOrCompletedPaths() throws {
        let recommendation = try XCTUnwrap(SmartReviewAdvisor.recommend(path: path(), history: []))
        XCTAssertEqual(recommendation.unit.id, "unit0")
        XCTAssertEqual(recommendation.reason, .notYetAttempted)
        XCTAssertNil(recommendation.scorePercent)
        XCTAssertNil(try SmartReviewAdvisor.recommend(path: path(["locked"]), history: []))
        XCTAssertNil(try SmartReviewAdvisor.recommend(path: path(["mastered"]), history: []))
        XCTAssertNil(try SmartReviewAdvisor.recommend(path: path(["completed"]), history: []))
        let continuing = try SmartReviewAdvisor.recommend(
            path: path(["available", "inProgress"]), history: [])
        XCTAssertEqual(continuing?.unit.id, "unit1")
        XCTAssertEqual(continuing?.reason, .nextUnlockedUnit)
        let contradictory = """
            {"trackId":"track","trackName":"Track","readinessScore":0,"units":[
            {"id":"unit","title":"Unit","status":"locked","lessons":[
            {"id":"lesson","title":"Lesson","status":"available","estMinutes":5}]}]}
            """
        let lockedUnit = try JSONDecoder().decode(
            LearningPath.self, from: Data(contradictory.utf8))
        XCTAssertNil(SmartReviewAdvisor.recommend(path: lockedUnit, history: []))
    }

    func testWeakestOpenUnitUsesLatestResultNotStaleFailureOrOtherTracks() throws {
        let history = try [
            entry(lesson: 0, score: 0, attempt: "old", date: 20),
            entry(lesson: 0, score: 100, attempt: "new"),
            entry(lesson: 1, score: 60, attempt: "other"),
            entry(lesson: 2, score: 0, attempt: "locked"),
            entry(lesson: 0, score: 0, attempt: "foreign", track: "another"),
        ]
        let result = try XCTUnwrap(SmartReviewAdvisor.recommend(path: path(), history: history))
        XCTAssertEqual(result.unit.id, "unit1")
        XCTAssertEqual(result.reason, .lowestScore(60))
        XCTAssertEqual(result.scorePercent, 60)
        XCTAssertEqual(
            try SmartReviewAdvisor.recommend(path: path(), history: history.reversed()), result)
    }

    func testRecurringErrorsRequireTwoDistinctRecentAttemptsAndBeatAnIsolatedLowScore() throws {
        let one = try entry(lesson: 0, score: 80)
        let other = try entry(lesson: 1, score: 20, attempt: "isolated")
        var history = [one, one, other]
        XCTAssertEqual(
            try SmartReviewAdvisor.recommend(path: path(), history: history)?.reason,
            .lowestScore(20))
        history.append(try entry(lesson: 0, score: 90, attempt: "earlier", date: 20))
        let result = try SmartReviewAdvisor.recommend(path: path(), history: history)
        XCTAssertEqual(result?.unit.id, "unit0")
        XCTAssertEqual(result?.reason, .recurringErrors)
        XCTAssertEqual(result?.scorePercent, 80)
    }

    func testStablePathOrderBreaksScoreTiesAndZeroAnsweredIsNotEvidence() throws {
        let history = try [
            entry(lesson: 1, score: 40, attempt: "b"),
            entry(lesson: 0, score: 40, attempt: "a"),
        ]
        XCTAssertEqual(
            try SmartReviewAdvisor.recommend(path: path(), history: history)?.unit.id, "unit0")
        let emptyAttempt = try entry(lesson: 0, score: 0, answered: 0)
        XCTAssertEqual(
            try SmartReviewAdvisor.recommend(path: path(), history: [emptyAttempt])?.reason,
            .notYetAttempted)
    }

    func testConfirmedLocalFallbackHasNoFabricatedDateAndDoesNotOverrideServerHistory() throws {
        let local = try SmartReviewLocalResult(lessonId: "lesson1", scorePercent: 30)
        let recommendation = try SmartReviewAdvisor.recommend(
            path: path(), history: [], localResults: [local, local])
        XCTAssertEqual(recommendation?.reason, .lowestScore(30))
        XCTAssertEqual(recommendation?.unit.id, "unit1")
        let history = try [entry(lesson: 1, score: 100)]
        XCTAssertEqual(
            try SmartReviewAdvisor.recommend(path: path(), history: history, localResults: [local])?
                .reason,
            .notYetAttempted)
        XCTAssertThrowsError(try SmartReviewLocalResult(lessonId: "", scorePercent: 20))
        XCTAssertThrowsError(try SmartReviewLocalResult(lessonId: "lesson", scorePercent: 101))
    }

    func testMasteryIsNotCompletionAndBandsHaveExactRequestedBoundaries() throws {
        XCTAssertEqual(try MasteryStage.resolved(coverage: 0, mastery: 0, score: 0), .notStarted)
        XCTAssertEqual(try MasteryStage.resolved(coverage: 0.5, mastery: 1, score: 100), .learning)
        XCTAssertEqual(
            try MasteryStage.resolved(coverage: 1, mastery: 0.8, score: 100), .practicing)
        XCTAssertEqual(try MasteryStage.resolved(coverage: 1, mastery: 1, score: 99), .mastered)
        XCTAssertEqual(try MasteryStage.resolved(coverage: 1, mastery: 1, score: 100), .examReady)
        for (coverage, mastery, score) in [
            (Double.nan, 0.0, 0), (1.1, 1, 100), (1, -0.1, 10), (1, 1, 101),
        ] {
            XCTAssertThrowsError(
                try MasteryStage.resolved(coverage: coverage, mastery: mastery, score: score))
        }
        for (score, band) in [
            (0, SkillBand.weak), (54, .weak), (55, .developing), (79, .developing), (80, .strong),
            (100, .strong),
        ] {
            XCTAssertEqual(try SkillBand.resolved(percent: score), band)
        }
        XCTAssertThrowsError(try SkillBand.resolved(percent: -1))
        XCTAssertThrowsError(try SkillBand.resolved(percent: 101))
        XCTAssertEqual(Set(MasteryStage.allCases.map(\.symbol)).count, 5)
        for language in AppLanguage.allCases {
            let copy = AppInterfaceCopy(language: language)
            for stage in MasteryStage.allCases { XCTAssertFalse(copy[stage.copyKey].isEmpty) }
        }
    }

    func testFocusUsesWeakestDomainAndOnlyAnExplicitUnlockedRecommendationMapping() throws {
        let readiness = ReadinessSnapshot(
            trackId: "track", score: 60, trend7d: 0,
            domains: [
                .init(domainId: "strong", weight: 1, coverage: 1, mastery: 0.8, score: 80),
                .init(domainId: "weak", weight: 1, coverage: 0.5, mastery: 0.4, score: 40),
            ])
        let json = """
            {"trackId":"track","generatedAt":"2026-10-21T10:00:00Z","items":[
            {"kind":"review","lessonId":"lesson1","unitId":"unit1","conceptId":null,"title":"Review",
            "domainId":"weak","domainName":"Weak","reason":"Practice","estMinutes":8,"priority":90,
            "masteryPct":40,"forgettingRiskPct":70}]}
            """
        let recommendations = try CertigoAPI.decoder().decode(
            NextBestRecommendations.self, from: Data(json.utf8))
        let focus = try SmartReviewAdvisor.focusArea(
            readiness: readiness, path: path(), recommendations: recommendations)
        XCTAssertEqual(focus?.domain.domainId, "weak")
        XCTAssertEqual(focus?.unit?.id, "unit1")
        XCTAssertEqual(focus?.estimatedMinutes, 8)
        let locked = try SmartReviewAdvisor.focusArea(
            readiness: readiness, path: path(["available", "locked"]),
            recommendations: recommendations)
        XCTAssertNil(locked?.unit)
        XCTAssertNil(locked?.estimatedMinutes)
        let wrong = ReadinessSnapshot(trackId: "foreign", score: 0, trend7d: 0, domains: [])
        XCTAssertThrowsError(
            try SmartReviewAdvisor.focusArea(
                readiness: wrong, path: path(), recommendations: recommendations))
    }

    func testStudyPlanPersistenceIsInjectableAndCorruptionIsExplicit() throws {
        let suite = "Certigo.StudyPlan.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertNil(try CertigoStudyPlanPreference.load(from: defaults))
        for level in CertigoStudyPlanPreference.InitialLevel.allCases {
            let preference = try CertigoStudyPlanPreference(
                targetExamDate: Date(timeIntervalSince1970: 1_800_000_000), initialLevel: level,
                dailyMinutesGoal: 7)
            try preference.save(to: defaults)
            XCTAssertEqual(try CertigoStudyPlanPreference.load(from: defaults), preference)
        }
        XCTAssertThrowsError(try CertigoStudyPlanPreference(dailyMinutesGoal: 0))
        XCTAssertThrowsError(try CertigoStudyPlanPreference(dailyMinutesGoal: 1_441))
        defaults.set(Data("invalid".utf8), forKey: CertigoStudyPlanPreference.storageKey)
        XCTAssertThrowsError(try CertigoStudyPlanPreference.load(from: defaults))
        defaults.set("not data", forKey: CertigoStudyPlanPreference.storageKey)
        XCTAssertThrowsError(try CertigoStudyPlanPreference.load(from: defaults))
        let a = try CertigoStudyPlanPreference(initialLevel: .advanced, dailyMinutesGoal: 15)
        let b = try CertigoStudyPlanPreference(initialLevel: .beginner, dailyMinutesGoal: 5)
        try a.save(to: defaults, key: "owner-A.track-A")
        try b.save(to: defaults, key: "owner-B.track-B")
        XCTAssertEqual(
            try CertigoStudyPlanPreference.load(from: defaults, key: "owner-A.track-A"), a)
        XCTAssertEqual(
            try CertigoStudyPlanPreference.load(from: defaults, key: "owner-B.track-B"), b)
        defaults.removeObject(forKey: "owner-A.track-A")
        XCTAssertNil(try CertigoStudyPlanPreference.load(from: defaults, key: "owner-A.track-A"))
        XCTAssertEqual(
            try CertigoStudyPlanPreference.load(from: defaults, key: "owner-B.track-B"), b)
        XCTAssertThrowsError(try a.save(to: defaults, key: ""))
    }
}
