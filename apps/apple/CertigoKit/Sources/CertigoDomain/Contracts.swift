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
}
public struct LearningPath: Decodable, Sendable {
    public let trackId: String
    public let trackName: String
    public let readinessScore: Int
    public let units: [PathUnit]
}
public struct PathUnit: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let lessons: [PathLesson]
}
public enum NodeStatus: String, Decodable, Sendable {
    case locked, available, inProgress, completed, mastered
}
public struct PathLesson: Decodable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let status: NodeStatus
    public let estMinutes: Int

    public var canOpen: Bool { status != .locked }
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
public struct QuizOption: Codable, Identifiable, Sendable {
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
