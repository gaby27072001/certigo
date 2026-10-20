import CertigoDomain
import Foundation

public struct LearningHistoryPresentation: Sendable {
    public let confirmed: [QuizAttemptHistoryItem]
    public let confirmedOnDevice: [SavedSubmission]
    public let onDevice: [SavedSubmission]

    public static func summaries(
        _ items: [QuizAttemptHistoryItem]
    ) throws -> [QuizAttemptHistoryItem] {
        var unique: [String: QuizAttemptHistoryItem] = [:]
        var attempts: [String: String] = [:]
        for item in items {
            if let existing = unique[item.id], existing != item,
                !equivalent(existing, item)
            {
                throw ContractError.malformed("conflicting history summaries")
            }
            if let key = attempts[item.attemptId], key != item.id {
                throw ContractError.malformed("conflicting history attempt")
            }
            unique[item.id] = item
            attempts[item.attemptId] = item.id
        }
        return unique.values.sorted {
            if $0.submittedAt != $1.submittedAt { return $0.submittedAt > $1.submittedAt }
            return $0.attemptId > $1.attemptId
        }
    }

    private static func equivalent(
        _ lhs: QuizAttemptHistoryItem, _ rhs: QuizAttemptHistoryItem
    ) -> Bool {
        lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.attemptId == rhs.attemptId
            && lhs.trackId == rhs.trackId && lhs.lessonId == rhs.lessonId
            && lhs.submittedAt == rhs.submittedAt && lhs.scorePct == rhs.scorePct
            && lhs.answeredCount == rhs.answeredCount && lhs.correctCount == rhs.correctCount
            && lhs.xpEarned == rhs.xpEarned && lhs.gemsEarned == rhs.gemsEarned
            && lhs.publicManifestId == rhs.publicManifestId
    }

    public init(
        server: [QuizAttemptHistoryItem], local: [SavedSubmission],
        ownerId: String, apiScope: String
    ) throws {
        confirmed = try Self.summaries(server)
        let byID = Dictionary(uniqueKeysWithValues: confirmed.map { ($0.id, $0) })
        let scoped = local.filter { $0.ownerId == ownerId && $0.apiScope == apiScope }
        var localIDs: Set<String> = []
        var acknowledged: [SavedSubmission] = []
        var device: [SavedSubmission] = []
        for entry in scoped {
            let key = QuizAttemptHistoryItem.key(entry.id)
            guard localIDs.insert(key).inserted else {
                throw ContractError.malformed("duplicate local history")
            }
            if let row = byID[key] {
                guard row.trackId == entry.submission.trackId, row.lessonId == entry.lessonId,
                    row.publicManifestId == nil || entry.submission.publicManifestId == nil
                        || row.publicManifestId == entry.submission.publicManifestId
                else { throw ContractError.malformed("history submission identity") }
                if entry.status == .corrected {
                    guard let result = entry.result, result.attemptId == row.attemptId,
                        result.scorePct == row.scorePct,
                        result.results.count == row.answeredCount,
                        result.results.filter(\.correct).count == row.correctCount,
                        result.rewards.xpEarned == row.xpEarned,
                        result.rewards.gemsEarned == row.gemsEarned
                    else { throw ContractError.malformed("history correction identity") }
                }
            } else if entry.status == .corrected {
                guard entry.result != nil else {
                    throw ContractError.malformed("missing local correction")
                }
                acknowledged.append(entry)
            } else {
                device.append(entry)
            }
        }
        func ordered(_ lhs: SavedSubmission, _ rhs: SavedSubmission) -> Bool {
            if lhs.submission.startedAt != rhs.submission.startedAt {
                return lhs.submission.startedAt > rhs.submission.startedAt
            }
            return lhs.id > rhs.id
        }
        confirmedOnDevice = acknowledged.sorted(by: ordered)
        onDevice = device.sorted(by: ordered)
    }
}
