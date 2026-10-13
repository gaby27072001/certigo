import CertigoDomain

import Foundation

public enum SubmissionOutcome: Equatable, Sendable {
    case pendingCorrection
    case corrected(QuizResult)
}
public actor LearningClient {
    private let api: CertigoAPI
    private let store: SubmissionStore
    private var current: APICredentials?
    private var generation = UUID()
    private var sending: Set<String> = []

    public init(api: CertigoAPI, store: SubmissionStore) {
        self.api = api
        self.store = store
    }

    public func connect(accessToken: String) async throws -> Profile {
        generation = UUID()
        current = nil
        let requestGeneration = generation
        let profile = try await api.profile(accessToken: accessToken)
        guard generation == requestGeneration else { throw APIError.staleSession }
        current = APICredentials(
            ownerId: profile.id, accessToken: accessToken, generation: requestGeneration
        )
        return profile
    }

    public func disconnect() {
        generation = UUID()
        current = nil
    }

    public func catalog() async throws -> [Track] {
        let context = try credentials()
        let value = try await api.catalog(context)
        try assertCurrent(context)
        return value
    }

    public func path(trackId: String) async throws -> LearningPath {
        let context = try credentials()
        let value = try await api.path(trackId: trackId, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func lesson(trackId: String, lessonId: String) async throws -> Lesson {
        let context = try credentials()
        let value = try await api.lesson(trackId: trackId, lessonId: lessonId, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func savedSubmissions() async throws -> [SavedSubmission] {
        let context = try credentials()
        let entries = try await store.entries(ownerId: context.ownerId, apiScope: api.scope)
        try assertCurrent(context)
        return entries
    }

    public func submit(lessonId: String, submission: QuizSubmission) async throws
        -> SubmissionOutcome
    {
        let context = try credentials()
        let saved = try await store.enqueue(
            SavedSubmission(
                ownerId: context.ownerId, apiScope: api.scope, lessonId: lessonId,
                submission: submission
            ))
        try assertCurrent(context)
        return try await send(saved, context: context)
    }

    public func retry(attemptId: String) async throws -> SubmissionOutcome {
        let context = try credentials()
        let entries = try await store.entries(ownerId: context.ownerId, apiScope: api.scope)
        try assertCurrent(context)
        guard let entry = entries.first(where: { $0.id == attemptId }) else {
            throw StoreError.invalidRecord
        }
        return try await send(entry, context: context)
    }

    private func send(_ entry: SavedSubmission, context: APICredentials) async throws
        -> SubmissionOutcome
    {
        if let result = entry.result { return .corrected(result) }
        guard entry.status == .pendingCorrection else { throw StoreError.invalidRecord }
        guard !sending.contains(entry.id) else { return .pendingCorrection }
        sending.insert(entry.id)
        defer { sending.remove(entry.id) }
        try assertCurrent(context)
        let result: QuizResult
        do {
            result = try await api.submit(
                lessonId: entry.lessonId, submission: entry.submission, credentials: context
            )
        } catch let error as APIError where error.isRetryable {
            try assertCurrent(context)
            return .pendingCorrection
        } catch let error as APIError {
            if error != .unauthorized {
                try await store.recordFailure("api:\(error)", entry: entry)
            }
            try assertCurrent(context)
            throw error
        } catch let error as ContractError {
            try await store.recordFailure("contract", entry: entry)
            try assertCurrent(context)
            throw error
        }
        // An ACK belongs to its original owner even if logout happened during the request.
        try await store.recordResult(result, entry: entry)
        try assertCurrent(context)
        return .corrected(result)
    }

    private func credentials() throws -> APICredentials {
        guard let current else { throw APIError.unauthorized }
        return current
    }

    private func assertCurrent(_ context: APICredentials) throws {
        guard current?.generation == context.generation, generation == context.generation else {
            throw APIError.staleSession
        }
    }
}
