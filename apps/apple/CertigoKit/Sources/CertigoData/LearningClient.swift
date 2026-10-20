import CertigoDomain
import Foundation

public enum SubmissionOutcome: Equatable, Sendable {
    case pendingCorrection
    case corrected(QuizResult)
}
public actor LearningClient {
    private let api: CertigoAPI
    private let store: SubmissionStore
    private let runtimeStore: RuntimeContentStore?
    private let publicSource: PublicReleaseAPI
    private var runtimeGeneration = UUID()
    private var current: APICredentials?
    private var generation = UUID()
    private var sending: Set<String> = []

    public init(
        api: CertigoAPI, store: SubmissionStore, runtimeStore: RuntimeContentStore? = nil,
        runtimeTransport: any BoundedHTTPTransport = BoundedURLSessionTransport()
    ) {
        self.api = api
        self.store = store
        self.runtimeStore = runtimeStore
        publicSource = PublicReleaseAPI(api: api, transport: runtimeTransport)
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

    public func refreshProfile() async throws -> Profile {
        let context = try credentials()
        let value = try await api.profile(accessToken: context.accessToken)
        try assertCurrent(context)
        guard value.id == context.ownerId else { throw APIError.invalidResponse }
        return value
    }

    public func setActiveTrack(trackId: String, expectedTrackId: String?) async throws -> Profile {
        let context = try credentials()
        let value = try await api.setActiveTrack(
            trackId: trackId, expectedTrackId: expectedTrackId, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func lesson(trackId: String, lessonId: String) async throws -> Lesson {
        let context = try credentials()
        let value = try await api.lesson(trackId: trackId, lessonId: lessonId, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func editorialPilot(pilotId: String) async throws -> EditorialPilotSnapshot {
        let context = try credentials()
        let value = try await api.editorialPilot(pilotId: pilotId, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func pilotHistory(_ snapshot: EditorialPilotSnapshot) async throws -> PilotHistory {
        let context = try credentials()
        let value = try await api.pilotHistory(snapshot, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func recordPilotLessonAccess(
        _ snapshot: EditorialPilotSnapshot, lessonId: String
    ) async throws -> PilotLessonProgress {
        let context = try credentials()
        let value = try await api.recordPilotLessonAccess(
            snapshot, lessonId: lessonId, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func markPilotLessonRead(
        _ snapshot: EditorialPilotSnapshot, lessonId: String
    ) async throws -> PilotLessonProgress {
        let context = try credentials()
        let value = try await api.markPilotLessonRead(
            snapshot, lessonId: lessonId, credentials: context)
        try assertCurrent(context)
        return value
    }

    public func savedSubmissions() async throws -> [SavedSubmission] {
        let context = try credentials()
        let entries = try await store.entries(ownerId: context.ownerId, apiScope: api.scope)
        try assertCurrent(context)
        return entries
    }

    public func synchronizePublicContent() async throws -> RuntimeContentSnapshot {
        let context = try credentials()
        guard let runtimeStore else { throw APIError.configuration }
        runtimeGeneration = UUID()
        let requestGeneration = runtimeGeneration
        let pins = try await store.manifestPins()
        try assertRuntimeCurrent(context, requestGeneration)
        try runtimeStore.retainPins(pins)
        let fetched = try await publicSource.activeManifest(credentials: context)
        try assertRuntimeCurrent(context, requestGeneration)
        guard case .fetched(let manifest, let binding, _) = fetched else {
            throw PublicReleaseError.provenance
        }
        let stage = try runtimeStore.begin(
            RuntimeContentSnapshot(
                ownerId: context.ownerId, apiScope: api.scope, manifest: manifest, binding: binding)
        )
        for file in manifest.files {
            try assertRuntimeCurrent(context, requestGeneration)
            if try runtimeStore.cachedFile(file) != nil { continue }
            let bytes = try await publicSource.file(
                file, manifest: manifest, binding: binding, credentials: context)
            try assertRuntimeCurrent(context, requestGeneration)
            try runtimeStore.saveFile(bytes, file: file)
        }
        try assertRuntimeCurrent(context, requestGeneration)
        // This guard and durable pointer transaction are synchronous on this same actor.
        return try runtimeStore.activate(stage)
    }

    public func cachedPublicContent() throws -> RuntimeContentSnapshot? {
        let context = try credentials()
        guard let runtimeStore else { throw APIError.configuration }
        return try runtimeStore.active(ownerId: context.ownerId, apiScope: api.scope)
    }

    public func restorePreviousPublicContent() throws -> RuntimeContentSnapshot {
        let context = try credentials()
        guard let runtimeStore else { throw APIError.configuration }
        return try runtimeStore.restorePrevious(ownerId: context.ownerId, apiScope: api.scope)
    }

    public func cleanupPublicContent() async throws -> Int {
        let context = try credentials()
        guard let runtimeStore else { throw APIError.configuration }
        let pins = try await store.manifestPins()
        try assertCurrent(context)
        try Task.checkCancellation()
        try runtimeStore.retainPins(pins)
        return try runtimeStore.cleanup()
    }

    private func assertRuntimeCurrent(_ context: APICredentials, _ requestGeneration: UUID) throws {
        try Task.checkCancellation()
        try assertCurrent(context)
        guard requestGeneration == runtimeGeneration else { throw APIError.staleSession }
    }

    public func submit(lessonId: String, submission: QuizSubmission) async throws
        -> SubmissionOutcome
    {
        let context = try credentials()
        _ = try submission.validated()
        if let manifestId = submission.publicManifestId {
            try runtimeStore?.retainPins([
                RuntimeManifestPin(
                    ownerId: context.ownerId, apiScope: api.scope, manifestId: manifestId)
            ])
        }
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
            // Cancellation does not establish whether the server committed this attempt.
            if error != .unauthorized && error != .transport(URLError.cancelled.rawValue) {
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
