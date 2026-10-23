import Foundation

public enum ContractError: Error, Equatable, Sendable {
    case malformed(String)
    case unsupported(String)
}
public struct Profile: Decodable, Sendable {
    public let id: String
    public let displayName: String
    public let xp: Int
    public let activeTrackId: String?
    public let level: Int?
    public let streakDays: Int?
    public let dailyGoalXp: Int?
    public let dailyXpEarned: Int?
    public let gems: Int?
}
public struct Catalog: Decodable, Sendable {
    public let schema: String
    public let sourceSchema: String
    public let tracks: [Track]

    public func validated() throws -> Self {
        guard schema == "certigo.app-certification-catalog/v2",
            sourceSchema == "certigo.certification-catalog/v1"
        else {
            throw ContractError.unsupported("catalog schema")
        }
        guard Set(tracks.map(\.id)).count == tracks.count,
            tracks.allSatisfy({ !$0.id.isEmpty && !$0.title.isEmpty })
        else {
            throw ContractError.malformed("catalog identities")
        }
        return self
    }
}
public struct Track: Decodable, Identifiable, Sendable {
    public let id: String
    public let code: String
    public let title: String
    public let summary: String
    public let learningAvailable: Bool
    public let languages: [String]?
}
public struct LearningPath: Decodable, Sendable {
    public let trackId: String
    public let trackName: String
    public let readinessScore: Int
    public let units: [PathUnit]
    public let domains: [DomainProgress]?
    public let readinessTrend7d: Int?
}
public struct DomainProgress: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let weight: Double
    public let score: Int
}
public struct PathUnit: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let lessons: [PathLesson]
    public let domainId: String?
    public let status: String?
}
public enum NodeStatus: String, Decodable, Sendable {
    case locked, available, inProgress, completed, mastered
}
public struct PathLesson: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let status: NodeStatus
    public let estMinutes: Int
    public let masteryPct: Int?

    public var canOpen: Bool { status != .locked }
}

public struct EditorialPilot: Decodable, Identifiable, Sendable {
    public let schema: String
    public let id: String
    public let locale: String
    public let status: String
    public let purpose: String
    public let title: String
    public let audience: String
    public let prerequisites: String
    public let estimatedMinutes: Int
    public let asOf: String
    public let scope: String
    public let sources: [EditorialPilotSource]
    public let lessons: [EditorialPilotLesson]

    public func validated() throws -> Self {
        guard schema == "certigo.editorial.pilot/v1",
            id == "responsible-ai-assistants", locale == "fr-FR",
            status == "draft", purpose == "learning-not-certification",
            !title.isEmpty, !audience.isEmpty, !prerequisites.isEmpty, !scope.isEmpty,
            estimatedMinutes > 0,
            sources.count == 4, Set(sources.map(\.id)).count == sources.count,
            lessons.count == 3, Set(lessons.map(\.id)).count == lessons.count
        else { throw ContractError.malformed("editorial pilot identity") }

        let sourceIDs = Set(sources.map(\.id))
        guard
            sources.allSatisfy({
                !$0.title.isEmpty && $0.url.hasPrefix("https://")
                    && !$0.checkedOn.isEmpty && !$0.supports.isEmpty && !$0.limits.isEmpty
            }),
            lessons.allSatisfy({ lesson in
                !lesson.title.isEmpty && !lesson.objective.isEmpty && !lesson.hook.isEmpty
                    && !lesson.recap.isEmpty && lesson.estimatedMinutes > 0
                    && !lesson.keyIdeas.isEmpty && !lesson.workedExample.situation.isEmpty
                    && !lesson.workedExample.steps.isEmpty && !lesson.workedExample.decision.isEmpty
                    && !lesson.practice.prompt.isEmpty && !lesson.practice.successCriteria.isEmpty
                    && !lesson.practice.feedback.isEmpty && !lesson.sourceIDs.isEmpty
                    && lesson.sourceIDs.allSatisfy(sourceIDs.contains)
            })
        else {
            throw ContractError.malformed("editorial pilot content")
        }
        return self
    }
}

public struct EditorialPilotSource: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let url: String
    public let checkedOn: String
    public let supports: String
    public let limits: String
}

public struct EditorialPilotLesson: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let objective: String
    public let estimatedMinutes: Int
    public let hook: String
    public let keyIdeas: [String]
    public let workedExample: EditorialPilotWorkedExample
    public let practice: EditorialPilotPractice
    public let recap: String
    public let sourceIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id, title, objective, estimatedMinutes, hook, keyIdeas, workedExample, practice, recap
        case sourceIDs = "sourceIds"
    }
}

public struct EditorialPilotWorkedExample: Decodable, Sendable {
    public let situation: String
    public let steps: [String]
    public let decision: String
}

public struct EditorialPilotPractice: Decodable, Sendable {
    public let prompt: String
    public let successCriteria: [String]
    public let feedback: String
}

public struct EditorialPilotSnapshot: Sendable {
    public let pilot: EditorialPilot
    public let contentDigest: String

    public init(pilot: EditorialPilot, contentDigest: String) {
        self.pilot = pilot
        self.contentDigest = contentDigest
    }

    public func validated() throws -> Self {
        guard
            contentDigest.range(
                of: "^sha256:[0-9a-f]{64}$",
                options: .regularExpression
            ) != nil
        else {
            throw ContractError.malformed("editorial pilot digest")
        }
        _ = try pilot.validated()
        return self
    }
}

public struct PilotLessonProgress: Decodable, Identifiable, Sendable {
    public let lessonId: String
    public let lastAccessedAt: Date
    public let markedReadAt: Date?
    public var id: String { lessonId }
}

public struct PilotHistory: Decodable, Sendable {
    public let pilotId: String
    public let contentDigest: String
    public let lastLessonId: String?
    public let lessons: [PilotLessonProgress]

    public func validated(for snapshot: EditorialPilotSnapshot) throws -> Self {
        let lessonIDs = Set(snapshot.pilot.lessons.map(\.id))
        guard pilotId == snapshot.pilot.id, contentDigest == snapshot.contentDigest,
            Set(lessons.map(\.lessonId)).count == lessons.count,
            lessons.allSatisfy({ lessonIDs.contains($0.lessonId) }),
            lessons.first?.lessonId == lastLessonId
        else { throw ContractError.malformed("editorial pilot history") }
        return self
    }
}

public struct Lesson: Codable, Sendable {
    public let id: String
    public let trackId: String
    public let title: String
    public let blocks: [LessonBlock]
    public var publicManifestId: String?

    public var questions: [QuizItem] { blocks.compactMap(\.check) }

    public func validated(trackId expectedTrack: String, lessonId expectedLesson: String) throws
        -> Self
    {
        guard id == expectedLesson, trackId == expectedTrack, !title.isEmpty else {
            throw ContractError.malformed("lesson identity")
        }
        let supportedBlocks: Set<String> = ["hook", "concept", "example", "code", "check", "recap"]
        guard blocks.allSatisfy({ supportedBlocks.contains($0.type) }) else {
            throw ContractError.unsupported("lesson block")
        }
        guard blocks.allSatisfy({ ($0.type == "check") == ($0.check != nil) }) else {
            throw ContractError.malformed("check block")
        }
        guard !questions.isEmpty, Set(questions.map(\.id)).count == questions.count else {
            throw ContractError.malformed("question identities")
        }
        for question in questions {
            try question.validateCapability()
        }
        return self
    }
}
public struct LessonBlock: Codable, Sendable {
    public let type: String
    public let title: String?
    public let body: String?
    public let code: String?
    public let check: QuizItem?
}
public struct QuizItem: Codable, Identifiable, Sendable {
    public let id: String
    public let conceptId: String
    public let type: String
    public let stem: String
    public let options: [QuizOption]

    public func validateCapability() throws {
        guard type == "mcq" else { throw ContractError.unsupported("itemType:\(type)") }
        guard !id.isEmpty, !conceptId.isEmpty, !stem.isEmpty, options.count >= 2,
            Set(options.map(\.id)).count == options.count,
            options.allSatisfy({ !$0.id.isEmpty && !$0.label.isEmpty })
        else {
            throw ContractError.malformed("question")
        }
    }
}
public struct QuizOption: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
}
public struct QuizAnswer: Codable, Equatable, Sendable {
    public let itemId: String
    public let itemType: String
    public let selected: [String]
    public let latencyMs: Int

    public init(itemId: String, itemType: String, selected: [String], latencyMs: Int) {
        self.itemId = itemId
        self.itemType = itemType
        self.selected = selected
        self.latencyMs = latencyMs
    }
}
public struct QuizSubmission: Codable, Equatable, Sendable {
    public let clientAttemptId: String
    public let trackId: String
    public let startedAt: Date
    public let answers: [QuizAnswer]
    public let publicManifestId: String?

    public init(
        clientAttemptId: String, trackId: String, startedAt: Date,
        answers: [QuizAnswer], publicManifestId: String?
    ) {
        self.clientAttemptId = clientAttemptId
        self.trackId = trackId
        self.startedAt = Date(
            timeIntervalSince1970: (startedAt.timeIntervalSince1970 * 1_000).rounded(.down) / 1_000
        )
        self.answers = answers
        self.publicManifestId = publicManifestId
    }

    public func validated() throws -> Self {
        guard UUID(uuidString: clientAttemptId) != nil, !trackId.isEmpty, !answers.isEmpty,
            Set(answers.map(\.itemId)).count == answers.count,
            answers.allSatisfy({
                !$0.itemId.isEmpty && $0.itemType == "mcq" && $0.selected.count == 1
                    && !$0.selected[0].isEmpty && $0.latencyMs >= 0
            })
        else {
            throw ContractError.malformed("submission")
        }
        return self
    }
}
public struct QuizResult: Codable, Equatable, Sendable {
    public let attemptId: String
    public let scorePct: Int
    public let results: [ItemResult]
    public let rewards: QuizRewards
    public let weakConcepts: [String]
    public let nextReviewDueAt: Date?

    public func validated(for submission: QuizSubmission) throws -> Self {
        guard !attemptId.isEmpty, (0...100).contains(scorePct),
            Set(results.map(\.itemId)).isSubset(of: Set(submission.answers.map(\.itemId))),
            Set(results.map(\.itemId)).count == results.count,
            results.allSatisfy({
                !$0.explanation.isEmpty && ($0.correct || !($0.correctAnswer ?? []).isEmpty)
            })
        else {
            throw ContractError.malformed("quiz result")
        }
        return self
    }
}
public struct ItemResult: Codable, Equatable, Identifiable, Sendable {
    public let itemId: String
    public let conceptId: String
    public let correct: Bool
    public let correctAnswer: [String]?
    public let explanation: String
    public let masteryDelta: Double
    public var id: String { itemId }
}
public struct QuizRewards: Codable, Equatable, Sendable {
    public let xpEarned: Int
    public let newXp: Int
    public let levelUp: Bool
    public let streakExtended: Bool
    public let gemsEarned: Int
    public let achievementsUnlocked: [String]
}

public struct TutorExplainRequest: Codable, Equatable, Sendable {
    public let trackId: String
    public let lessonId: String
    public let itemId: String
    public let selected: [String]
    public let publicManifestId: String?

    public init(
        trackId: String, lessonId: String, itemId: String, selected: [String],
        publicManifestId: String? = nil
    ) {
        self.trackId = trackId
        self.lessonId = lessonId
        self.itemId = itemId
        self.selected = selected
        self.publicManifestId = publicManifestId
    }
}

public struct TutorPersonalization: Codable, Equatable, Sendable {
    public let attempts: Int
    public let errors: Int
    public let accuracyPct: Int
    public let recurringStruggle: Bool
    public let masteredBefore: Bool
    public let trend: String
    public let topConfusedOption: String?

    public init(
        attempts: Int, errors: Int, accuracyPct: Int, recurringStruggle: Bool,
        masteredBefore: Bool, trend: String, topConfusedOption: String?
    ) {
        self.attempts = attempts
        self.errors = errors
        self.accuracyPct = accuracyPct
        self.recurringStruggle = recurringStruggle
        self.masteredBefore = masteredBefore
        self.trend = trend
        self.topConfusedOption = topConfusedOption
    }
}

public struct TutorExplanation: Codable, Equatable, Sendable {
    public let itemId: String
    public let conceptId: String
    public let correct: Bool
    public let headline: String
    public let points: [String]
    public let encouragement: String
    public let recommendation: String
    public let citedConceptIds: [String]
    public let source: String
    public let personalization: TutorPersonalization

    public init(
        itemId: String, conceptId: String, correct: Bool, headline: String, points: [String],
        encouragement: String, recommendation: String, citedConceptIds: [String],
        source: String, personalization: TutorPersonalization
    ) {
        self.itemId = itemId
        self.conceptId = conceptId
        self.correct = correct
        self.headline = headline
        self.points = points
        self.encouragement = encouragement
        self.recommendation = recommendation
        self.citedConceptIds = citedConceptIds
        self.source = source
        self.personalization = personalization
    }
}

public struct LearningHistoryPage: Decodable, Equatable, Sendable {
    public let items: [QuizAttemptHistoryItem]
    public let nextCursor: String?

    enum CodingKeys: String, CodingKey, CaseIterable { case items, nextCursor }

    public init(from decoder: any Decoder) throws {
        try historyFields(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decode([QuizAttemptHistoryItem].self, forKey: .items)
        nextCursor = try values.decodeIfPresent(String.self, forKey: .nextCursor)
        guard items.count <= 50, Self.validCursor(nextCursor) else {
            throw ContractError.malformed("history page")
        }
    }

    public static func validCursor(_ cursor: String?) -> Bool {
        guard let cursor else { return true }
        return !cursor.isEmpty && cursor.utf8.count <= 2_048
            && cursor.utf8.allSatisfy {
                (65...90).contains($0) || (97...122).contains($0)
                    || (48...57).contains($0) || $0 == 45 || $0 == 95
            }
    }
}

public struct QuizAttemptHistoryItem: Decodable, Equatable, Identifiable, Sendable {
    public let kind: String
    public let attemptId: String
    public let clientAttemptId: String
    public let trackId: String
    public let lessonId: String
    public let submittedAt: Date
    public let scorePct: Int
    public let answeredCount: Int
    public let correctCount: Int
    public let xpEarned: Int
    public let gemsEarned: Int
    public let publicManifestId: String?
    public var id: String { Self.key(clientAttemptId) }

    public static func key(_ value: String) -> String {
        UUID(uuidString: value)?.uuidString ?? value
    }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case kind, attemptId, clientAttemptId, trackId, lessonId, submittedAt
        case scorePct, answeredCount, correctCount, xpEarned, gemsEarned, publicManifestId
    }

    public init(from decoder: any Decoder) throws {
        try historyFields(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let values = try decoder.container(keyedBy: CodingKeys.self)
        kind = try values.decode(String.self, forKey: .kind)
        attemptId = try values.decode(String.self, forKey: .attemptId)
        clientAttemptId = try values.decode(String.self, forKey: .clientAttemptId)
        trackId = try values.decode(String.self, forKey: .trackId)
        lessonId = try values.decode(String.self, forKey: .lessonId)
        submittedAt = try values.decode(Date.self, forKey: .submittedAt)
        scorePct = try values.decode(Int.self, forKey: .scorePct)
        answeredCount = try values.decode(Int.self, forKey: .answeredCount)
        correctCount = try values.decode(Int.self, forKey: .correctCount)
        xpEarned = try values.decode(Int.self, forKey: .xpEarned)
        gemsEarned = try values.decode(Int.self, forKey: .gemsEarned)
        publicManifestId = try values.decodeIfPresent(String.self, forKey: .publicManifestId)
        guard kind == "quiz",
            [attemptId, clientAttemptId, trackId, lessonId].allSatisfy({
                !$0.isEmpty && $0.utf8.count <= 256
                    && $0.rangeOfCharacter(from: .whitespacesAndNewlines.union(.controlCharacters))
                        == nil
            }),
            submittedAt.timeIntervalSince1970 >= -62_135_596_800,
            submittedAt.timeIntervalSince1970 < 253_402_300_800,
            (0...100).contains(scorePct),
            [answeredCount, correctCount, xpEarned, gemsEarned].allSatisfy({
                (0...Int(Int32.max)).contains($0)
            }), correctCount <= answeredCount,
            publicManifestId == nil
                || publicManifestId?.range(
                    of: "^sha256:[0-9a-f]{64}$", options: .regularExpression) != nil
        else { throw ContractError.malformed("history summary") }
    }
}

private struct HistoryField: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

private func historyFields(_ decoder: any Decoder, allowed: [String]) throws {
    let values = try decoder.container(keyedBy: HistoryField.self)
    guard Set(values.allKeys.map(\.stringValue)) == Set(allowed) else {
        throw ContractError.malformed("history fields")
    }
}
