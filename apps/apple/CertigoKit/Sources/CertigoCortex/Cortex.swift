import Foundation

public enum CortexAlgorithm {
    public static let version = "1.0.0"
}
public enum CortexError: Error, Equatable, Sendable {
    case invalidState
    case invalidDate
    case invalidDomain
    case mixedTracks
    case invalidSession
    case unsupportedIdentifier
}
public struct ConceptMastery: Equatable, Sendable {
    public let conceptId: String
    public let trackId: String
    public let masteryScore: Double
    public let stability: Double
    public let difficulty: Double
    public let dueAt: Date
    public let reps: Int
    public let lapses: Int
    public let lastReviewedAt: Date

    public init(
        conceptId: String, trackId: String, masteryScore: Double = 0,
        stability: Double = 1, difficulty: Double = 5,
        dueAt: Date, reps: Int = 0, lapses: Int = 0, lastReviewedAt: Date
    ) throws {
        guard !conceptId.isEmpty, !trackId.isEmpty,
            masteryScore.isFinite, (0...1).contains(masteryScore),
            stability.isFinite, stability > 0,
            difficulty.isFinite, (1...10).contains(difficulty),
            reps >= 0, lapses >= 0, lapses <= reps
        else { throw CortexError.invalidState }
        guard dueAt.timeIntervalSinceReferenceDate.isFinite,
            lastReviewedAt.timeIntervalSinceReferenceDate.isFinite
        else { throw CortexError.invalidDate }
        self.conceptId = conceptId
        self.trackId = trackId
        self.masteryScore = masteryScore
        self.stability = stability
        self.difficulty = difficulty
        self.dueAt = dueAt
        self.reps = reps
        self.lapses = lapses
        self.lastReviewedAt = lastReviewedAt
    }

    public static func fresh(conceptId: String, trackId: String, now: Date) throws -> Self {
        try Self(conceptId: conceptId, trackId: trackId, dueAt: now, lastReviewedAt: now)
    }

    public func isDue(at now: Date) -> Bool { dueAt <= now }
    public var isWeak: Bool { reps > 0 && masteryScore < 0.5 }
}
public enum ReviewGrade: Int, CaseIterable, Sendable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    public static func from(correct: Bool, latencyMs: Int) -> Self {
        if !correct { return .again }
        if latencyMs < 4_000 { return .easy }
        if latencyMs < 9_000 { return .good }
        return .hard
    }
}
public enum ReviewScheduler {
    public static func apply(
        _ state: ConceptMastery, grade: ReviewGrade, now: Date
    ) throws -> ConceptMastery {
        let again = grade == .again
        let factor: Double
        switch grade {
        case .again: factor = 0.5
        case .hard: factor = 1.1
        case .good: factor = 1.6
        case .easy: factor = 2.1
        }
        let stability = again ? max(0.5, state.stability * 0.4) : state.stability * factor
        let difficulty = min(10, max(1, state.difficulty + (again ? 0.8 : -0.15)))
        let mastery = min(1, max(0, 1 - exp(-stability / 20)))
        // Dart rounds fractional days to microseconds; the shared cross-language gate allows 1ms.
        let seconds = (stability * 86_400_000_000).rounded(.toNearestOrAwayFromZero) / 1_000_000
        guard seconds.isFinite, state.reps < Int.max, state.lapses < Int.max else {
            throw CortexError.invalidState
        }
        return try ConceptMastery(
            conceptId: state.conceptId, trackId: state.trackId,
            masteryScore: mastery, stability: stability, difficulty: difficulty,
            dueAt: now.addingTimeInterval(seconds), reps: state.reps + 1,
            lapses: state.lapses + (again ? 1 : 0), lastReviewedAt: now
        )
    }
}
public struct ReadinessDomain: Equatable, Sendable {
    public let domainId: String
    public let weight: Double
    public let conceptCount: Int

    public init(domainId: String, weight: Double, conceptCount: Int) throws {
        guard !domainId.isEmpty, weight.isFinite, weight >= 0, conceptCount >= 0 else {
            throw CortexError.invalidDomain
        }
        self.domainId = domainId
        self.weight = weight
        self.conceptCount = conceptCount
    }
}
public struct DomainReadiness: Equatable, Sendable {
    public let domainId: String
    public let weight: Double
    public let coverage: Double
    public let mastery: Double
    public let score: Int
}
public struct Readiness: Equatable, Sendable {
    public let trackId: String
    public let score: Int
    public let domains: [DomainReadiness]
}
public enum ReadinessCalculator {
    public static func compute(
        trackId: String, domains: [ReadinessDomain], masteries: [ConceptMastery],
        conceptDomains: [String: String], now: Date
    ) throws -> Readiness {
        guard now.timeIntervalSinceReferenceDate.isFinite else { throw CortexError.invalidDate }
        guard !trackId.isEmpty, masteries.allSatisfy({ $0.trackId == trackId }) else {
            throw CortexError.mixedTracks
        }
        guard Set(domains.map(\.domainId)).count == domains.count,
            Set(masteries.map(\.conceptId)).count == masteries.count
        else { throw CortexError.invalidDomain }
        let grouped = Dictionary(grouping: masteries) { state in
            if let mapped = conceptDomains[state.conceptId] { return mapped }
            let parts = state.conceptId.split(separator: ":", omittingEmptySubsequences: true)
            return parts.count > 1 ? String(parts[0]) : "default"
        }
        let scores = domains.map { domain in
            let states = grouped[domain.domainId] ?? []
            // These denominator and rounding rules follow authoritative .NET, not Dart edge cases.
            let coverage = min(1, Double(states.count) / Double(max(1, domain.conceptCount)))
            let mastery =
                states.isEmpty
                ? 0
                : min(1, max(0, states.reduce(0) { $0 + $1.masteryScore } / Double(states.count)))
            let recency =
                states.isEmpty
                ? 0
                : states.reduce(0) {
                    $0 + exp(-max(0, now.timeIntervalSince($1.lastReviewedAt) / 86_400) / 30)
                } / Double(states.count)
            let raw = 100 * pow(coverage, 0.5) * mastery * pow(recency, 0.3)
            return DomainReadiness(
                domainId: domain.domainId, weight: domain.weight, coverage: coverage,
                mastery: mastery, score: Int(raw.rounded(.toNearestOrEven))
            )
        }
        let totalWeight = scores.reduce(0) { $0 + $1.weight }
        let weighted =
            scores.reduce(0) { $0 + Double($1.score) * $1.weight }
            / max(0.0001, totalWeight)
        guard totalWeight.isFinite, weighted.isFinite else { throw CortexError.invalidDomain }
        return Readiness(
            trackId: trackId, score: Int(weighted.rounded(.toNearestOrEven)), domains: scores
        )
    }
}
public struct SessionPlanner: Sendable {
    private let weights: [Double]

    public init(
        dueWeight: Double = 0.4, weakWeight: Double = 0.3,
        newWeight: Double = 0.2, reinforceWeight: Double = 0.1
    ) throws {
        let weights = [dueWeight, weakWeight, newWeight, reinforceWeight]
        guard weights.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw CortexError.invalidSession
        }
        self.weights = weights
    }

    public func plan(
        trackId: String, states: [ConceptMastery], candidateNewConceptIds: [String],
        now: Date, size: Int = 12
    ) throws -> [String] {
        guard (0...1_000).contains(size), candidateNewConceptIds.allSatisfy({ !$0.isEmpty }) else {
            throw CortexError.invalidSession
        }
        guard states.allSatisfy({ $0.trackId == trackId }), !trackId.isEmpty else {
            throw CortexError.mixedTracks
        }
        guard now.timeIntervalSinceReferenceDate.isFinite else { throw CortexError.invalidDate }
        // Preserve input order for equal sort keys. Dart's golden vectors do not pin ties.
        let indexed = Array(states.enumerated())
        let due = indexed.filter { $0.element.isDue(at: now) }.sorted {
            if $0.element.dueAt == $1.element.dueAt { return $0.offset < $1.offset }
            return $0.element.dueAt < $1.element.dueAt
        }.map(\.element.conceptId)
        let weak = indexed.filter { $0.element.isWeak && !$0.element.isDue(at: now) }.sorted {
            if $0.element.masteryScore == $1.element.masteryScore { return $0.offset < $1.offset }
            return $0.element.masteryScore < $1.element.masteryScore
        }.map(\.element.conceptId)
        let reinforce = indexed.filter { !$0.element.isWeak && !$0.element.isDue(at: now) }.sorted {
            if $0.element.lastReviewedAt == $1.element.lastReviewedAt {
                return $0.offset < $1.offset
            }
            return $0.element.lastReviewedAt < $1.element.lastReviewedAt
        }.map(\.element.conceptId)
        let counts = weights.map { Int((Double(size) * $0).rounded(.toNearestOrAwayFromZero)) }
        let picks =
            Array(due.prefix(counts[0])) + Array(weak.prefix(counts[1]))
            + Array(candidateNewConceptIds.prefix(counts[2])) + Array(reinforce.prefix(counts[3]))
        var seen = Set<String>()
        var order = picks.filter { seen.insert($0).inserted }
        if order.count < size {
            for id in due + candidateNewConceptIds where order.count < size {
                if seen.insert(id).inserted { order.append(id) }
            }
        }
        return Array(order.prefix(size))
    }
}
public enum AnswerItemType: String, CaseIterable, Sendable {
    case mcq, multi, scenario, spotTheIssue, ordering, cloze, applied, matchPairs

    public var isOrdered: Bool { self == .ordering || self == .cloze || self == .applied }
}
public enum AnswerGrading {
    /// Use only an authorized answer/feedback, never an embedded private answer bank.
    public static func isCorrect(
        type: AnswerItemType, correct: [String], selected: [String]?
    ) throws -> Bool {
        guard let selected, selected.count == correct.count else { return false }
        let expected = try correct.map(foldASCII)
        let actual = try selected.map(foldASCII)
        if type.isOrdered { return expected == actual }
        return expected.sorted() == actual.sorted()
    }

    private static func foldASCII(_ identifier: String) throws -> String {
        guard identifier.utf8.allSatisfy({ $0 < 128 }) else {
            throw CortexError.unsupportedIdentifier
        }
        // Current identifiers are ASCII. Match server OrdinalIgnoreCase without locale folding.
        return String(
            decoding: identifier.utf8.map { (65...90).contains($0) ? $0 + 32 : $0 },
            as: UTF8.self)
    }
}
