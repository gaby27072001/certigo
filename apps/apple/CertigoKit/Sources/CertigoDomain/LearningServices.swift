import Foundation

public struct RecommendationItem: Codable, Equatable, Sendable {
    public let kind: String
    public let lessonId: String?
    public let unitId: String?
    public let conceptId: String?
    public let title: String
    public let domainId: String
    public let domainName: String
    public let reason: String
    public let estMinutes: Int
    public let priority: Int
    public let masteryPct: Int
    public let forgettingRiskPct: Int
}
public struct NextBestRecommendations: Codable, Equatable, Sendable {
    public let trackId: String
    public let generatedAt: Date
    public let items: [RecommendationItem]
}
public struct DomainReadinessSummary: Codable, Equatable, Sendable {
    public let domainId: String
    public let weight: Double
    public let coverage: Double
    public let mastery: Double
    public let score: Int

    public init(domainId: String, weight: Double, coverage: Double, mastery: Double, score: Int) {
        self.domainId = domainId
        self.weight = weight
        self.coverage = coverage
        self.mastery = mastery
        self.score = score
    }
}
public struct ReadinessSnapshot: Codable, Equatable, Sendable {
    public let trackId: String
    public let score: Int
    public let trend7d: Int
    public let domains: [DomainReadinessSummary]

    public init(trackId: String, score: Int, trend7d: Int, domains: [DomainReadinessSummary]) {
        self.trackId = trackId
        self.score = score
        self.trend7d = trend7d
        self.domains = domains
    }
}
public struct MockExamRequest: Codable, Equatable, Sendable {
    public let trackId: String
    public let length: Int?
    public let publicManifestId: String?

    public init(trackId: String, length: Int? = nil, publicManifestId: String? = nil) {
        self.trackId = trackId
        self.length = length
        self.publicManifestId = publicManifestId
    }
}
public struct MockExamBlueprintDomain: Codable, Equatable, Sendable {
    public let domainId: String
    public let name: String
    public let weight: Double
    public let itemCount: Int
}
public struct MockExamItem: Codable, Equatable, Sendable {
    public let itemId: String
    public let lessonId: String
    public let domainId: String
    public let type: String
    public let stem: String
    public let options: [QuizOption]
}
public struct MockExam: Codable, Equatable, Sendable {
    public let examId: String
    public let trackId: String
    public let trackCode: String
    public let trackTitle: String
    public let timeLimitSeconds: Int
    public let passingScore: Int
    public let blueprint: [MockExamBlueprintDomain]
    public let items: [MockExamItem]
    public let publicManifestId: String?

    public func validated() throws -> Self {
        guard !examId.isEmpty, !trackId.isEmpty, timeLimitSeconds >= 0,
            items.isEmpty ? timeLimitSeconds == 0 : timeLimitSeconds > 0,
            (0...1_000).contains(passingScore),
            Set(items.map(\.itemId)).count == items.count,
            blueprint.allSatisfy({ $0.weight.isFinite && $0.weight >= 0 && $0.itemCount >= 0 }),
            items.allSatisfy({ !$0.itemId.isEmpty && !$0.lessonId.isEmpty && !$0.stem.isEmpty })
        else { throw ContractError.malformed("mock exam") }
        for item in items {
            // Existing native renderer supports only MCQ; never silently downgrade other types.
            guard item.type == "mcq" else {
                throw ContractError.unsupported("exam itemType:\(item.type)")
            }
            guard item.options.count >= 2,
                Set(item.options.map(\.id)).count == item.options.count,
                item.options.allSatisfy({ !$0.id.isEmpty && !$0.label.isEmpty })
            else { throw ContractError.malformed("exam options") }
        }
        return self
    }
}
public struct SubmitMockExamRequest: Codable, Equatable, Sendable {
    public let clientAttemptId: String
    public let trackId: String
    public let examId: String
    public let startedAt: Date
    public let answers: [QuizAnswer]

    public init(
        clientAttemptId: String, trackId: String, examId: String, startedAt: Date,
        answers: [QuizAnswer]
    ) {
        self.clientAttemptId = clientAttemptId
        self.trackId = trackId
        self.examId = examId
        self.startedAt = startedAt
        self.answers = answers
    }
}
public struct ExamDomainScore: Codable, Equatable, Sendable {
    public let domainId: String
    public let name: String
    public let weight: Double
    public let correct: Int
    public let total: Int
    public let pct: Int
}
public struct MockExamResult: Codable, Equatable, Sendable {
    public let attemptId: String
    public let examId: String
    public let scaledScore: Int
    public let pct: Int
    public let passed: Bool
    public let passingScore: Int
    public let correct: Int
    public let total: Int
    public let domains: [ExamDomainScore]
    public let results: [ItemResult]
    public let rewards: QuizRewards
    public let weakConcepts: [String]
}
public struct AchievementItem: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let name: String
    public let description: String
    public let tier: String
    public let threshold: Int
    public let progress: Int
    public let rewardGems: Int
    public let unlocked: Bool
}
public struct AchievementBoard: Codable, Equatable, Sendable {
    public let unlocked: Int
    public let total: Int
    public let achievements: [AchievementItem]
}
public struct QuestItem: Codable, Equatable, Sendable {
    public let id: String
    public let kind: String
    public let title: String
    public let target: Int
    public let current: Int
    public let rewardGems: Int
    public let completed: Bool
    public let claimed: Bool
    public let claimable: Bool
}
public struct QuestBoard: Codable, Equatable, Sendable {
    /// ISO 8601 calendar date (backend DateOnly), not an instant in the device time zone.
    public let date: String
    public let gems: Int
    public let quests: [QuestItem]
}
public struct ScheduledNotificationItem: Codable, Equatable, Sendable {
    public let kind: String
    public let priority: String
    public let scheduledUtc: Date
    public let localHour: Int
    public let mascot: String
    public let title: String
    public let body: String
    public let deeplink: String
    public let dedupeKey: String
}
public struct NotificationPlan: Codable, Equatable, Sendable {
    public let localDate: String
    public let notifications: [ScheduledNotificationItem]
}
public struct NotificationSettings: Codable, Equatable, Sendable {
    public let enabled: Bool
    public let utcOffsetMinutes: Int
    public let quietHoursStart: Int
    public let quietHoursEnd: Int
    public let preferredHour: Int
    public let maxPerDay: Int
    public let streakAlerts: Bool
    public let questAlerts: Bool
    public let leagueAlerts: Bool

    public init(
        enabled: Bool, utcOffsetMinutes: Int, quietHoursStart: Int, quietHoursEnd: Int,
        preferredHour: Int, maxPerDay: Int, streakAlerts: Bool, questAlerts: Bool,
        leagueAlerts: Bool
    ) {
        self.enabled = enabled
        self.utcOffsetMinutes = utcOffsetMinutes
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.preferredHour = preferredHour
        self.maxPerDay = maxPerDay
        self.streakAlerts = streakAlerts
        self.questAlerts = questAlerts
        self.leagueAlerts = leagueAlerts
    }
}
