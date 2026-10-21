import Foundation

public enum SkillBand: String, Codable, CaseIterable, Sendable {
    case strong, developing, weak

    public static func resolved(percent: Int) throws -> SkillBand {
        guard (0...100).contains(percent) else {
            throw ContractError.malformed("skill percentage")
        }
        if percent >= 80 { return .strong }
        if percent >= 55 { return .developing }
        return .weak
    }
}
public enum MasteryStage: String, Codable, CaseIterable, Sendable {
    case notStarted, learning, practicing, mastered, examReady

    /// Conservative presentation of supplied evidence, not an exam pass prediction.
    public static func resolved(coverage: Double, mastery: Double, score: Int) throws -> Self {
        guard coverage.isFinite, mastery.isFinite,
            (0...1).contains(coverage), (0...1).contains(mastery), (0...100).contains(score)
        else { throw ContractError.malformed("mastery evidence") }
        if coverage == 0 && mastery == 0 && score == 0 { return .notStarted }
        if coverage < 1 { return .learning }
        if mastery < 1 { return .practicing }
        return score == 100 ? .examReady : .mastered
    }

    public var symbol: String {
        switch self {
        case .notStarted: "○"
        case .learning: "◔"
        case .practicing: "◑"
        case .mastered: "●"
        case .examReady: "◆"
        }
    }

    public var copyKey: AppInterfaceCopy.Key {
        switch self {
        case .notStarted: .masteryNotStarted
        case .learning: .masteryLearning
        case .practicing: .masteryPracticing
        case .mastered: .masteryMastered
        case .examReady: .masteryExamReady
        }
    }
}
public struct FocusArea: Equatable, Sendable {
    public let domain: DomainReadinessSummary
    public let recommendation: RecommendationItem?
    public let unit: PathUnit?
    public var estimatedMinutes: Int? { recommendation?.estMinutes }
}
public struct SmartReviewRecommendation: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case lowestScore(Int)
        case recurringErrors
        case notYetAttempted
        case nextUnlockedUnit
    }

    public let unit: PathUnit
    public let reason: Reason
    public let scorePercent: Int?

    public init(unit: PathUnit, reason: Reason, scorePercent: Int?) {
        self.unit = unit
        self.reason = reason
        self.scorePercent = scorePercent
    }
}
public struct SmartReviewLocalResult: Equatable, Sendable {
    public let lessonId: String
    public let scorePercent: Int

    public init(lessonId: String, scorePercent: Int) throws {
        guard !lessonId.isEmpty, (0...100).contains(scorePercent) else {
            throw ContractError.malformed("local review result")
        }
        self.lessonId = lessonId
        self.scorePercent = scorePercent
    }
}
public enum SmartReviewAdvisor {
    public static func focusArea(
        readiness: ReadinessSnapshot, path: LearningPath,
        recommendations: NextBestRecommendations
    ) throws -> FocusArea? {
        guard readiness.trackId == path.trackId, recommendations.trackId == path.trackId else {
            throw ContractError.malformed("focus track identity")
        }
        for domain in readiness.domains {
            _ = try MasteryStage.resolved(
                coverage: domain.coverage, mastery: domain.mastery, score: domain.score)
        }
        let weakest = readiness.domains.sorted {
            if $0.score != $1.score { return $0.score < $1.score }
            if $0.mastery != $1.mastery { return $0.mastery < $1.mastery }
            return $0.domainId < $1.domainId
        }.first
        guard let weakest else { return nil }
        let choices = recommendations.items.enumerated().filter { indexed in
            let item = indexed.element
            return item.domainId == weakest.domainId
                && (item.unitId != nil || item.lessonId != nil)
                && path.units.contains { unit in
                    unit.status != "locked"
                        && (unit.domainId == nil || unit.domainId == weakest.domainId)
                        && (item.unitId == nil || item.unitId == unit.id)
                        && unit.lessons.contains { lesson in
                            lesson.canOpen && (item.lessonId == nil || item.lessonId == lesson.id)
                        }
                }
        }.sorted {
            if $0.element.priority != $1.element.priority {
                return $0.element.priority > $1.element.priority
            }
            return $0.offset < $1.offset
        }
        let item = choices.first?.element
        let unit = item.flatMap { item in
            path.units.first { unit in
                unit.status != "locked"
                    && (unit.domainId == nil || unit.domainId == weakest.domainId)
                    && (item.unitId == nil || item.unitId == unit.id)
                    && unit.lessons.contains {
                        $0.canOpen && (item.lessonId == nil || item.lessonId == $0.id)
                    }
            }
        }
        return FocusArea(domain: weakest, recommendation: item, unit: unit)
    }

    /// Caller supplies the current owner's confirmed history. Pending answers are not grades.
    public static func recommend(
        path: LearningPath, history: [QuizAttemptHistoryItem],
        localResults: [SmartReviewLocalResult] = []
    ) -> SmartReviewRecommendation? {
        let relevant = history.filter {
            $0.trackId == path.trackId && $0.answeredCount > 0
        }.sorted {
            if $0.submittedAt != $1.submittedAt { return $0.submittedAt > $1.submittedAt }
            if $0.attemptId != $1.attemptId { return $0.attemptId < $1.attemptId }
            return $0.clientAttemptId < $1.clientAttemptId
        }
        var seen = Set<String>()
        let attempts = relevant.filter { seen.insert($0.id).inserted }
        var recurring: SmartReviewRecommendation?
        var weakest: SmartReviewRecommendation?
        var continuing: SmartReviewRecommendation?
        var unattempted: SmartReviewRecommendation?
        for unit in path.units {
            guard unit.status != "locked" else { continue }
            let open = unit.lessons.filter(\.canOpen)
            guard !open.isEmpty else { continue }
            let recent = open.compactMap { lesson in
                attempts.first { $0.lessonId == lesson.id }
            }
            // Untimestamped local acknowledgements cannot supersede dated server history.
            let local = open.flatMap { lesson in
                recent.contains(where: { $0.lessonId == lesson.id })
                    ? []
                    : localResults.filter { $0.lessonId == lesson.id }.map(\.scorePercent)
            }
            let score = (recent.map(\.scorePct) + local).min()
            let stillStruggling = open.contains { lesson in
                let lastTwo = attempts.filter { $0.lessonId == lesson.id }.prefix(2)
                return lastTwo.count == 2 && lastTwo.allSatisfy { $0.scorePct < 100 }
            }
            if stillStruggling,
                recurring == nil || (score ?? 100) < (recurring?.scorePercent ?? 100)
            {
                recurring = .init(unit: unit, reason: .recurringErrors, scorePercent: score)
            }
            if let score, score < 100,
                weakest == nil || score < (weakest?.scorePercent ?? 100)
            {
                weakest = .init(unit: unit, reason: .lowestScore(score), scorePercent: score)
            }
            if continuing == nil, open.contains(where: { $0.status == .inProgress }) {
                continuing = .init(unit: unit, reason: .nextUnlockedUnit, scorePercent: score)
            }
            if unattempted == nil,
                open.contains(where: { lesson in
                    lesson.status == .available
                        && !attempts.contains(where: { $0.lessonId == lesson.id })
                        && !localResults.contains(where: { $0.lessonId == lesson.id })
                })
            {
                unattempted = .init(unit: unit, reason: .notYetAttempted, scorePercent: nil)
            }
        }
        return recurring ?? weakest ?? continuing ?? unattempted
    }
}
