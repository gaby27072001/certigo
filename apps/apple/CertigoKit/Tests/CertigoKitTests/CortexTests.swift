import CertigoCortex
import Foundation
import XCTest

final class CortexTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_735_689_600)

    func testAlgorithmVersionMatchesTheSingleSharedVectorSource() throws {
        XCTAssertEqual(CortexAlgorithm.version, try vectors().algoVersion)
    }

    func testSharedAnswerGradingVectorsCoverEveryType() throws {
        let cases = try vectors().parity.answerGrading
        XCTAssertEqual(Set(cases.map(\.type)), Set(AnswerItemType.allCases.map(\.rawValue)))
        for vector in cases {
            let type = try XCTUnwrap(AnswerItemType(rawValue: vector.type))
            XCTAssertEqual(
                try AnswerGrading.isCorrect(
                    type: type, correct: vector.correct, selected: vector.selected
                ),
                vector.expected, vector.name
            )
        }
    }

    func testSharedSchedulerVectorsKeepFractionalDaysAndFloatTolerance() throws {
        for vector in try vectors().parity.scheduler {
            var state = try ConceptMastery.fresh(conceptId: "c", trackId: "t", now: now)
            for name in vector.grades {
                let grade = try XCTUnwrap(
                    ReviewGrade.allCases.first { String(describing: $0) == name })
                state = try ReviewScheduler.apply(state, grade: grade, now: now)
            }
            XCTAssertEqual(state.stability, vector.expected.stability, accuracy: 1e-9, vector.name)
            XCTAssertEqual(
                state.difficulty, vector.expected.difficulty, accuracy: 1e-9, vector.name)
            XCTAssertEqual(state.reps, vector.expected.reps, vector.name)
            XCTAssertEqual(state.lapses, vector.expected.lapses, vector.name)
            XCTAssertEqual(
                state.masteryScore, 1 - exp(-vector.expected.stability / 20),
                accuracy: 1e-9, vector.name
            )
            XCTAssertEqual(state.lastReviewedAt, now)
            XCTAssertEqual(state.trackId, "t")
            XCTAssertEqual(state.conceptId, "c")
            if vector.checkDueAt {
                XCTAssertEqual(
                    state.dueAt.timeIntervalSince(now), vector.dueAtOffsetSeconds,
                    accuracy: 0.001, vector.name
                )
            }
        }
    }

    func testSharedWeaknessVectors() throws {
        for vector in try vectors().parity.weakness {
            let state = try mastery(score: vector.masteryScore, reps: vector.reps)
            XCTAssertEqual(state.isWeak, vector.expectedIsWeak, vector.name)
        }
    }

    func testSharedReadinessVectors() throws {
        for vector in try vectors().parity.readiness {
            let states = try vector.masteries.map {
                try ConceptMastery(
                    conceptId: $0.conceptId, trackId: vector.trackId,
                    masteryScore: $0.masteryScore, dueAt: now, reps: $0.reps,
                    lastReviewedAt: now.addingTimeInterval(-$0.lastReviewedAtOffsetDays * 86_400)
                )
            }
            let domains = try vector.domains.map {
                try ReadinessDomain(
                    domainId: $0.domainId, weight: $0.weight, conceptCount: $0.conceptsInDomain
                )
            }
            let mapping = Dictionary(
                uniqueKeysWithValues: vector.masteries.map { ($0.conceptId, $0.domainId) }
            )
            let result = try ReadinessCalculator.compute(
                trackId: vector.trackId, domains: domains, masteries: states,
                conceptDomains: mapping, now: now
            )
            XCTAssertEqual(result.score, vector.expectedTrackScore, vector.name)
            for domain in result.domains {
                XCTAssertEqual(
                    domain.score, vector.expectedDomainScores[domain.domainId], vector.name)
            }
        }
    }

    func testSharedDartOnlyPlannerVectorsDoNotImplyServerRecommendations() throws {
        for vector in try vectors().cortexOnly.sessionPlanner {
            let states = try vector.states.map {
                try ConceptMastery(
                    conceptId: $0.conceptId, trackId: "t", masteryScore: $0.masteryScore,
                    dueAt: now.addingTimeInterval($0.dueAtOffsetDays * 86_400), reps: $0.reps,
                    lastReviewedAt: now.addingTimeInterval(-$0.lastReviewedAtOffsetDays * 86_400)
                )
            }
            XCTAssertEqual(
                try SessionPlanner().plan(
                    trackId: "t", states: states,
                    candidateNewConceptIds: vector.candidateNewConceptIds,
                    now: now, size: vector.size
                ),
                vector.expectedOrder, vector.name
            )
        }
    }

    func testServerReadinessUsesEvenMidpointRoundingNotDartAwayFromZero() throws {
        let domain = try ReadinessDomain(domainId: "d", weight: 1, conceptCount: 1)
        let result = try ReadinessCalculator.compute(
            trackId: "t", domains: [domain], masteries: [mastery(score: 0.505)],
            conceptDomains: ["c": "d"], now: now
        )
        XCTAssertEqual(result.score, 50)
        XCTAssertEqual(result.domains[0].score, 50)
        let weighted = try ReadinessCalculator.compute(
            trackId: "t",
            domains: [
                ReadinessDomain(domainId: "a", weight: 1, conceptCount: 1),
                ReadinessDomain(domainId: "b", weight: 1, conceptCount: 1),
            ],
            masteries: [
                mastery(id: "a:c", score: 0.5), mastery(id: "b:c", score: 0.51),
            ],
            conceptDomains: [:], now: now
        )
        XCTAssertEqual(weighted.score, 50)
    }

    func testServerZeroConceptDenominatorAndTinyWeightFloorAreExplicit() throws {
        let domain = try ReadinessDomain(domainId: "d", weight: 0.00001, conceptCount: 0)
        let result = try ReadinessCalculator.compute(
            trackId: "t", domains: [domain], masteries: [mastery(score: 1)],
            conceptDomains: ["c": "d"], now: now
        )
        XCTAssertEqual(result.domains[0].score, 100)
        XCTAssertEqual(result.score, 10)
        XCTAssertEqual(
            try ReadinessCalculator.compute(
                trackId: "t", domains: [], masteries: [], conceptDomains: [:], now: now
            ).score,
            0
        )
    }

    func testServerAnswerComparisonIgnoresASCIICaseButDoesNotGuessUnicodeRules() throws {
        XCTAssertTrue(
            try AnswerGrading.isCorrect(type: .multi, correct: ["A", "b"], selected: ["B", "a"]))
        XCTAssertFalse(
            try AnswerGrading.isCorrect(type: .multi, correct: ["a", "b"], selected: ["A", "A"]))
        XCTAssertFalse(
            try AnswerGrading.isCorrect(
                type: .ordering, correct: ["a", "b"], selected: ["B", "A"]))
        XCTAssertFalse(try AnswerGrading.isCorrect(type: .mcq, correct: ["a"], selected: nil))
        XCTAssertThrowsError(
            try AnswerGrading.isCorrect(type: .mcq, correct: ["\u{00E9}"], selected: ["\u{00E9}"])
        ) { XCTAssertEqual($0 as? CortexError, .unsupportedIdentifier) }
    }

    func testGradeLatencyBoundariesAndDueInclusiveBoundary() throws {
        for latency in [0, 3_999] {
            XCTAssertEqual(ReviewGrade.from(correct: true, latencyMs: latency), .easy)
        }
        for latency in [4_000, 8_999] {
            XCTAssertEqual(ReviewGrade.from(correct: true, latencyMs: latency), .good)
        }
        XCTAssertEqual(ReviewGrade.from(correct: true, latencyMs: 9_000), .hard)
        XCTAssertEqual(ReviewGrade.from(correct: false, latencyMs: 0), .again)
        let state = try ConceptMastery.fresh(conceptId: "c", trackId: "t", now: now)
        XCTAssertTrue(state.isDue(at: now))
        XCTAssertFalse(state.isDue(at: now.addingTimeInterval(-0.001)))
        // Seconds, not Calendar days: scheduling is independent of DST and device timezone.
        let dstBoundary = Date(timeIntervalSince1970: 1_741_478_400)
        let scheduled = try ReviewScheduler.apply(state, grade: .good, now: dstBoundary)
        XCTAssertEqual(scheduled.dueAt.timeIntervalSince(dstBoundary), 138_240, accuracy: 0.001)
    }

    func testLocalPlannerTiesAreStableAndDeduplicatedWithoutClaimingServerParity() throws {
        let states = try [
            mastery(id: "z", score: 0.8, reps: 1),
            mastery(id: "a", score: 0.8, reps: 1),
            mastery(id: "b", score: 0.8, reps: 1),
        ]
        let planner = try SessionPlanner()
        for _ in 0..<10 {
            XCTAssertEqual(
                try planner.plan(
                    trackId: "t", states: states, candidateNewConceptIds: ["z", "new", "new"],
                    now: now, size: 4
                ),
                ["z", "a", "b", "new"]
            )
        }
        XCTAssertEqual(
            try planner.plan(
                trackId: "t", states: states, candidateNewConceptIds: [], now: now, size: 0),
            []
        )
    }

    func testInvalidStatesAndCrossTrackInputsFailExplicitly() throws {
        XCTAssertThrowsError(try mastery(score: .nan))
        XCTAssertThrowsError(try mastery(score: 1.1))
        XCTAssertThrowsError(try SessionPlanner(dueWeight: .infinity))
        let other = try ConceptMastery.fresh(conceptId: "c", trackId: "other", now: now)
        XCTAssertThrowsError(
            try SessionPlanner().plan(
                trackId: "t", states: [other], candidateNewConceptIds: [], now: now
            )
        ) { XCTAssertEqual($0 as? CortexError, .mixedTracks) }
        XCTAssertThrowsError(
            try ReadinessCalculator.compute(
                trackId: "t", domains: [], masteries: [other], conceptDomains: [:], now: now
            )
        ) { XCTAssertEqual($0 as? CortexError, .mixedTracks) }
        XCTAssertThrowsError(
            try SessionPlanner().plan(
                trackId: "t", states: [], candidateNewConceptIds: [], now: now, size: -1)
        )
    }

    private func mastery(id: String = "c", score: Double, reps: Int = 0) throws -> ConceptMastery {
        try ConceptMastery(
            conceptId: id, trackId: "t", masteryScore: score, dueAt: now,
            reps: reps, lastReviewedAt: now
        )
    }

    private func vectors() throws -> GoldenVectors {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<6 { root.deleteLastPathComponent() }
        let source = root.appendingPathComponent(
            "packages/cortex/test/golden/cortex_golden_vectors.json")
        return try JSONDecoder().decode(GoldenVectors.self, from: Data(contentsOf: source))
    }
}
private struct GoldenVectors: Decodable {
    let algoVersion: String
    let parity: Parity
    let cortexOnly: Local

    struct Parity: Decodable {
        let answerGrading: [Answer]
        let scheduler: [Schedule]
        let weakness: [Weakness]
        let readiness: [ReadinessVector]
    }

    struct Local: Decodable { let sessionPlanner: [Plan] }

    struct Answer: Decodable {
        let name, type: String
        let correct, selected: [String]
        let expected: Bool
    }

    struct Schedule: Decodable {
        let name: String
        let grades: [String]
        let expected: State
        let checkDueAt: Bool
        let dueAtOffsetSeconds: Double
    }

    struct State: Decodable {
        let stability, difficulty: Double
        let reps, lapses: Int
    }

    struct Weakness: Decodable {
        let name: String
        let reps: Int
        let masteryScore: Double
        let expectedIsWeak: Bool
    }

    struct ReadinessVector: Decodable {
        let name, trackId: String
        let domains: [Domain]
        let masteries: [Mastery]
        let expectedDomainScores: [String: Int]
        let expectedTrackScore: Int
    }

    struct Domain: Decodable {
        let domainId: String
        let weight: Double
        let conceptsInDomain: Int
    }

    struct Mastery: Decodable {
        let conceptId, domainId: String
        let masteryScore, lastReviewedAtOffsetDays: Double
        let reps: Int
    }

    struct Plan: Decodable {
        let name: String
        let size: Int
        let states: [PlannerState]
        let candidateNewConceptIds, expectedOrder: [String]
    }

    struct PlannerState: Decodable {
        let conceptId: String
        let masteryScore, dueAtOffsetDays, lastReviewedAtOffsetDays: Double
        let reps: Int
    }
}
