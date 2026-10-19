import CertigoData
import CertigoDomain
import Foundation
import Observation

struct DeveloperConnection: Codable {
    let baseURL: String
    let accessToken: String
}
protocol DeveloperConnectionVault {
    func read() throws -> DeveloperConnection?
    func save(_ connection: DeveloperConnection) throws
    func clear() throws
}

enum NativeResumeError: Error, Equatable {
    case malformed, ownerChanged, scopeChanged, releaseChanged
    case submissionUnresolved, attemptMismatch, duplicateSubmission
}

enum NativePilotError: Error {
    case connectionRequired
    case operationInProgress
    case ownerChanged
    case lessonUnavailable
}

// Navigation metadata only; the existing outbox remains the sole persisted submission authority.
struct NativeResumeState: Codable, Equatable, Sendable {
    enum Tab: String, Codable, Sendable { case learn, coach, social, profile }
    enum Phase: String, Codable, Sendable { case draft, submitting, pending, confirmed, failed }
    struct Session: Codable, Equatable, Sendable {
        let trackId: String
        let lessonId: String
        let publicManifestId: String?
        var phase: Phase
        var attemptId: String?
    }

    let schema: Int
    var tab: Tab
    let ownerId: String
    let apiScope: String
    var session: Session?

    init(tab: Tab, ownerId: String, apiScope: String, session: Session? = nil) throws {
        schema = 2
        self.tab = tab
        self.ownerId = ownerId
        self.apiScope = apiScope
        self.session = session
        try validate()
    }

    func encoded() throws -> Data {
        try validate()
        let bytes = try JSONEncoder().encode(self)
        guard bytes.count <= 8_192 else { throw NativeResumeError.malformed }
        return bytes
    }

    static func decode(_ bytes: Data) throws -> Self {
        guard bytes.count <= 8_192 else { throw NativeResumeError.malformed }
        // A closed shape rejects future/unknown fields rather than silently losing their meaning.
        let value: Any
        do { value = try JSONSerialization.jsonObject(with: bytes) } catch {
            throw NativeResumeError.malformed
        }
        guard let object = value as? [String: Any],
            Set(object.keys).isSubset(of: ["schema", "tab", "ownerId", "apiScope", "session"])
        else { throw NativeResumeError.malformed }
        if let session = object["session"], !(session is NSNull) {
            guard let fields = session as? [String: Any],
                Set(fields.keys).isSubset(of: [
                    "trackId", "lessonId", "publicManifestId", "phase", "attemptId",
                ])
            else { throw NativeResumeError.malformed }
        }
        let decoded: Self
        do { decoded = try JSONDecoder().decode(Self.self, from: bytes) } catch is DecodingError {
            throw NativeResumeError.malformed
        }
        try decoded.validate()
        return decoded
    }

    func beginningSubmission(_ request: QuizSubmission) throws -> Self {
        try validate()
        guard var session, session.phase == .draft else {
            throw NativeResumeError.duplicateSubmission
        }
        _ = try request.validated()
        guard request.trackId == session.trackId,
            request.publicManifestId == session.publicManifestId
        else { throw NativeResumeError.attemptMismatch }
        session.phase = .submitting
        session.attemptId = request.clientAttemptId
        var next = self
        next.session = session
        return next
    }

    func reconciled(
        ownerId: String, apiScope: String, currentManifestId: String?,
        submissions: [SavedSubmission]
    ) throws -> Self {
        try validate()
        guard self.ownerId == ownerId else { throw NativeResumeError.ownerChanged }
        guard self.apiScope == apiScope else { throw NativeResumeError.scopeChanged }
        guard var session else { return self }
        if session.phase == .draft {
            guard session.publicManifestId == currentManifestId else {
                throw NativeResumeError.releaseChanged
            }
            return self
        }
        let matches = submissions.filter { $0.id == session.attemptId }
        guard matches.count == 1, let saved = matches.first else {
            // A submitting marker is never evidence that an attempt was durably enqueued or ACKed.
            throw NativeResumeError.submissionUnresolved
        }
        guard saved.ownerId == ownerId, saved.apiScope == apiScope,
            saved.lessonId == session.lessonId, saved.submission.trackId == session.trackId,
            saved.submission.publicManifestId == session.publicManifestId
        else { throw NativeResumeError.attemptMismatch }
        _ = try saved.submission.validated()
        switch saved.status {
        case .pendingCorrection:
            guard saved.result == nil else { throw NativeResumeError.attemptMismatch }
            session.phase = .pending
        case .corrected:
            guard let result = saved.result else { throw NativeResumeError.attemptMismatch }
            _ = try result.validated(for: saved.submission)
            session.phase = .confirmed
        case .failed:
            guard saved.result == nil else { throw NativeResumeError.attemptMismatch }
            session.phase = .failed
        }
        var next = self
        next.session = session
        return next
    }

    private func validate() throws {
        func identifier(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 1_024
                && value.rangeOfCharacter(from: .controlCharacters) == nil
        }
        guard schema == 2, identifier(ownerId), identifier(apiScope),
            let url = URL(string: apiScope), url.scheme == "https", url.host != nil,
            url.user == nil, url.password == nil, url.query == nil, url.fragment == nil
        else { throw NativeResumeError.malformed }
        guard let session else { return }
        guard identifier(session.trackId), identifier(session.lessonId),
            !session.trackId.contains("/"), !session.lessonId.contains("/"),
            !session.trackId.contains("\\"), !session.lessonId.contains("\\"),
            session.trackId != ".", session.trackId != "..",
            session.lessonId != ".", session.lessonId != ".."
        else { throw NativeResumeError.malformed }
        if let manifest = session.publicManifestId {
            guard manifest.hasPrefix("sha256:"), manifest.count == 71,
                manifest.dropFirst(7).utf8.allSatisfy({
                    (48...57).contains($0) || (97...102).contains($0)
                })
            else { throw NativeResumeError.malformed }
        }
        if session.phase == .draft {
            guard session.attemptId == nil else { throw NativeResumeError.malformed }
        } else {
            guard let attemptId = session.attemptId, UUID(uuidString: attemptId) != nil else {
                throw NativeResumeError.malformed
            }
        }
    }
}

@Observable @MainActor
final class NativeModel {
    var baseURL = ""
    var token = ""
    private(set) var profile: Profile?
    private(set) var tracks: [Track] = []
    private(set) var path: LearningPath?
    private(set) var lesson: Lesson?
    private(set) var editorialPilot: EditorialPilotSnapshot?
    private(set) var pilotHistory: PilotHistory?
    private(set) var queue: [SavedSubmission] = []
    private(set) var outcome: SubmissionOutcome?
    private(set) var busy = false
    var errorMessage: String?
    var selections: [String: String] = [:]
    private var latencies: [String: Int] = [:]
    private var questionStarted: [String: ContinuousClock.Instant] = [:]
    private var attemptID = UUID().uuidString
    private var submittedRequest: QuizSubmission?
    private var startedAt = Date()
    private var generation = UUID()
    private var client: LearningClient?
    private let vault: any DeveloperConnectionVault
    private let defaults: UserDefaults
    private let makeClient: (URL) throws -> LearningClient
    private let authentication:
        (provider: any CIAMAuthenticationProvider, configuration: CIAMConfiguration)?
    private let now: () -> Date
    private var tokenExpiresAt: Date?
    private var pendingGoal: (trackId: String, expectedTrackId: String?)?
    private static let signedOutKey = "certigo.native.dev.signed-out.v1"

    init(
        vault: any DeveloperConnectionVault = CredentialVault(),
        defaults: UserDefaults = .standard,
        clientFactory: ((URL) throws -> LearningClient)? = nil,
        authentication: (
            provider: any CIAMAuthenticationProvider, configuration: CIAMConfiguration
        )? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.vault = vault
        self.defaults = defaults
        self.authentication = authentication
        self.now = now
        makeClient =
            clientFactory ?? { url in
                let api = try CertigoAPI(baseURL: url)
                let directory = try FileManager.default.url(
                    for: .applicationSupportDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: true)
                return LearningClient(
                    api: api,
                    store: SubmissionStore(
                        file: directory.appendingPathComponent("CertigoNative/submissions-v1.json"))
                )
            }
    }

    var canSubmit: Bool {
        guard let lesson, !busy, outcome == nil, submittedRequest == nil else { return false }
        return lesson.questions.allSatisfy { question in
            question.options.contains { $0.id == selections[question.id] }
        }
    }

    func restore() async {
        guard profile == nil, !busy,
            !defaults.bool(forKey: Self.signedOutKey)
        else { return }
        if authentication != nil {
            await connectUsingAuthentication(interactive: false)
            return
        }
        do {
            guard let saved = try vault.read() else { return }
            baseURL = saved.baseURL
            token = saved.accessToken
            await connect()
        } catch {
            errorMessage =
                "The test connection could not be restored. Reconnect the test account."
        }
    }

    func connect() async {
        guard !busy else { return }
        if authentication != nil {
            await connectUsingAuthentication(interactive: true)
            return
        }
        let marker = UUID()
        generation = marker
        let previous = client
        let enteredToken = token
        clearSession()
        token = enteredToken
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        await previous?.disconnect()
        guard generation == marker else { return }
        do {
            guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
            else {
                throw APIError.configuration
            }
            let api = try CertigoAPI(baseURL: url)
            let next = try makeClient(api.baseURL)
            let accessToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            let loadedProfile = try await next.connect(accessToken: accessToken)
            let loadedTracks = try await next.catalog()
            let loadedQueue = try await next.savedSubmissions()
            guard generation == marker else { return }
            try vault.save(DeveloperConnection(baseURL: api.scope, accessToken: accessToken))
            defaults.set(false, forKey: Self.signedOutKey)
            client = next
            profile = loadedProfile
            tracks = loadedTracks
            queue = loadedQueue
            token = ""
        } catch {
            guard generation == marker else { return }
            report(error)
        }
    }

    func disconnect() async {
        let previous = client
        defaults.set(true, forKey: Self.signedOutKey)
        generation = UUID()
        let marker = generation
        clearSession()
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        await previous?.disconnect()
        guard generation == marker else { return }
        if let authentication {
            do {
                try await authentication.provider.removeLocalAccount()
            } catch {
                guard generation == marker else { return }
                errorMessage =
                    "The local session is closed, but SDK account removal is not confirmed. Retry signing out."
            }
        } else {
            do { try vault.clear() } catch {
                errorMessage =
                    "Secure storage did not confirm sign-out. Retry before closing the app."
            }
        }
    }

    private func clearSession() {
        client = nil
        profile = nil
        tracks = []
        path = nil
        lesson = nil
        editorialPilot = nil
        pilotHistory = nil
        selections = [:]
        questionStarted = [:]
        latencies = [:]
        queue = []
        outcome = nil
        submittedRequest = nil
        token = ""
        tokenExpiresAt = nil
        pendingGoal = nil
        busy = false
    }

    private func connectUsingAuthentication(interactive: Bool) async {
        guard let authentication, !busy else { return }
        let previous = client
        let marker = UUID()
        generation = marker
        if interactive {
            clearSession()
        } else {
            client = nil
        }
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        await previous?.disconnect()
        guard generation == marker else { return }
        do {
            let acquired: CIAMAccessToken
            if interactive {
                acquired = try await authentication.provider.acquireInteractively()
            } else {
                acquired = try await authentication.provider.acquireSilently()
            }
            guard generation == marker else { return }
            guard acquired.expiresAt > now(),
                !acquired.value.isEmpty,
                acquired.value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
            else { throw CIAMAuthenticationFailure.invalidToken }
            let next = try makeClient(authentication.configuration.apiBaseURL)
            let loadedProfile = try await next.connect(accessToken: acquired.value)
            guard generation == marker else {
                await next.disconnect()
                return
            }
            guard acquired.expiresAt > now() else {
                await next.disconnect()
                throw CIAMAuthenticationFailure.invalidToken
            }
            let loadedTracks = try await next.catalog()
            guard generation == marker else {
                await next.disconnect()
                return
            }
            guard acquired.expiresAt > now() else {
                await next.disconnect()
                throw CIAMAuthenticationFailure.invalidToken
            }
            let loadedQueue = try await next.savedSubmissions()
            guard generation == marker, acquired.expiresAt > now() else {
                await next.disconnect()
                if generation == marker { throw CIAMAuthenticationFailure.invalidToken }
                return
            }
            if profile?.id != loadedProfile.id {
                clearSession()
                busy = true
            }
            defaults.set(false, forKey: Self.signedOutKey)
            client = next
            profile = loadedProfile
            tracks = loadedTracks
            queue = loadedQueue
            tokenExpiresAt = acquired.expiresAt
        } catch {
            guard generation == marker else { return }
            clearSession()
            report(error)
        }
    }

    func refreshAuthenticationIfNeeded() async {
        guard authentication != nil, profile != nil, !busy else { return }
        if let tokenExpiresAt, tokenExpiresAt > now().addingTimeInterval(30) { return }
        await connectUsingAuthentication(interactive: false)
    }

    func chooseActiveTrack(_ track: Track) async {
        guard !busy else { return }
        let owner = profile?.id
        await refreshAuthenticationIfNeeded()
        guard let client, let profile, !busy else { return }
        guard profile.id == owner else {
            report(APIError.staleSession)
            return
        }
        guard tracks.contains(where: { $0.id == track.id }) else {
            report(APIError.configuration)
            return
        }
        if let pendingGoal, pendingGoal.trackId != track.id {
            errorMessage =
                "Your previous goal selection is not confirmed. Retry that same goal before choosing another."
            return
        }
        let decision = pendingGoal ?? (trackId: track.id, expectedTrackId: profile.activeTrackId)
        pendingGoal = decision
        let marker = generation
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        do {
            let value = try await client.setActiveTrack(
                trackId: decision.trackId, expectedTrackId: decision.expectedTrackId)
            guard generation == marker else { return }
            self.profile = value
            pendingGoal = nil
        } catch APIError.http(409) {
            guard generation == marker else { return }
            do {
                let value = try await client.refreshProfile()
                guard generation == marker else { return }
                self.profile = value
                pendingGoal = nil
                errorMessage =
                    "Your active goal changed elsewhere. The current goal was reloaded; choose again to confirm a different goal."
            } catch {
                guard generation == marker else { return }
                errorMessage =
                    "Your goal selection conflicted and the current goal could not be reloaded. Retry the same selection to reconcile; no change is confirmed."
            }
        } catch {
            guard generation == marker else { return }
            if case APIError.http(404) = error { pendingGoal = nil }
            report(error)
        }
    }

    func loadPath(_ track: Track) async {
        guard !busy else { return }
        await refreshAuthenticationIfNeeded()
        guard let client, !busy else { return }
        let marker = generation
        busy = true
        path = nil
        lesson = nil
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        do {
            let value = try await client.path(trackId: track.id)
            guard generation == marker else { return }
            path = value
        } catch {
            guard generation == marker else { return }
            report(error)
        }
    }

    func loadLesson(_ node: PathLesson) async {
        guard !busy else { return }
        await refreshAuthenticationIfNeeded()
        guard let client, let path, !busy else { return }
        guard path.units.flatMap(\.lessons).contains(where: { $0.id == node.id && $0.canOpen })
        else {
            report(NativeResumeError.malformed)
            return
        }
        let marker = generation
        busy = true
        lesson = nil
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        do {
            let value = try await client.lesson(trackId: path.trackId, lessonId: node.id)
            guard generation == marker else { return }
            let saved = try await client.savedSubmissions()
            guard generation == marker else { return }
            queue = saved
            let unresolved = saved.filter {
                $0.lessonId == value.id && $0.submission.trackId == value.trackId
                    && $0.status != .corrected
            }
            guard unresolved.count <= 1 else { throw NativeResumeError.submissionUnresolved }
            if let pending = unresolved.first {
                guard pending.submission.publicManifestId == value.publicManifestId else {
                    throw NativeResumeError.releaseChanged
                }
                guard pending.submission.answers.count == value.questions.count,
                    pending.submission.answers.allSatisfy({ answer in
                        value.questions.contains { question in
                            question.id == answer.itemId && question.type == answer.itemType
                                && answer.selected.count == 1
                                && question.options.contains { $0.id == answer.selected[0] }
                        }
                    })
                else { throw NativeResumeError.attemptMismatch }
                lesson = value
                submittedRequest = pending.submission
                attemptID = pending.id
                startedAt = pending.submission.startedAt
                selections = Dictionary(
                    uniqueKeysWithValues: pending.submission.answers.map {
                        ($0.itemId, $0.selected[0])
                    })
                latencies = Dictionary(
                    uniqueKeysWithValues: pending.submission.answers.map {
                        ($0.itemId, $0.latencyMs)
                    })
                questionStarted = [:]
                outcome = pending.status == .pendingCorrection ? .pendingCorrection : nil
                if pending.status == .failed { report(StoreError.invalidRecord) }
                return
            }
            lesson = value
            selections = [:]
            latencies = [:]
            questionStarted = [:]
            outcome = nil
            submittedRequest = nil
            attemptID = UUID().uuidString
            startedAt = Date()
        } catch {
            guard generation == marker else { return }
            report(error)
        }
    }

    func loadEditorialPilot() async throws {
        guard !busy else { throw NativePilotError.operationInProgress }
        guard let owner = profile?.id else { throw NativePilotError.connectionRequired }
        await refreshAuthenticationIfNeeded()
        guard let client, profile?.id == owner, !busy else {
            throw NativePilotError.ownerChanged
        }
        let marker = generation
        busy = true
        editorialPilot = nil
        pilotHistory = nil
        defer { if generation == marker { busy = false } }
        let snapshot = try await client.editorialPilot(pilotId: "responsible-ai-assistants")
        guard generation == marker, profile?.id == owner else {
            throw NativePilotError.ownerChanged
        }
        let history = try await client.pilotHistory(snapshot)
        guard generation == marker, profile?.id == owner else {
            throw NativePilotError.ownerChanged
        }
        editorialPilot = snapshot
        pilotHistory = history
    }

    func accessEditorialPilotLesson(_ lessonId: String) async throws {
        try await updateEditorialPilotLesson(lessonId, markRead: false)
    }

    func markEditorialPilotLessonRead(_ lessonId: String) async throws {
        try await updateEditorialPilotLesson(lessonId, markRead: true)
    }

    private func updateEditorialPilotLesson(_ lessonId: String, markRead: Bool) async throws {
        guard !busy else { throw NativePilotError.operationInProgress }
        guard let owner = profile?.id, let snapshot = editorialPilot,
            snapshot.pilot.lessons.contains(where: { $0.id == lessonId })
        else { throw NativePilotError.lessonUnavailable }
        await refreshAuthenticationIfNeeded()
        guard let client, profile?.id == owner, !busy else {
            throw NativePilotError.ownerChanged
        }
        let marker = generation
        busy = true
        defer { if generation == marker { busy = false } }
        if markRead {
            _ = try await client.markPilotLessonRead(snapshot, lessonId: lessonId)
        } else {
            _ = try await client.recordPilotLessonAccess(snapshot, lessonId: lessonId)
        }
        guard generation == marker, profile?.id == owner else {
            throw NativePilotError.ownerChanged
        }
        pilotHistory = try await client.pilotHistory(snapshot)
        guard generation == marker, profile?.id == owner else {
            throw NativePilotError.ownerChanged
        }
    }

    func questionAppeared(_ id: String) {
        if questionStarted[id] == nil { questionStarted[id] = ContinuousClock.now }
    }

    func select(_ option: QuizOption, question: QuizItem) {
        guard outcome == nil, submittedRequest == nil, !busy else { return }
        guard let actual = lesson?.questions.first(where: { $0.id == question.id }),
            actual.options.contains(where: { $0.id == option.id })
        else {
            report(NativeResumeError.attemptMismatch)
            return
        }
        selections[question.id] = option.id
        if let start = questionStarted[question.id] {
            let duration = start.duration(to: ContinuousClock.now)
            let milliseconds =
                duration.components.seconds * 1_000 + duration.components.attoseconds
                / 1_000_000_000_000_000
            latencies[question.id] = Int(clamping: max(0, milliseconds))
        }
    }

    func submit() async {
        guard !busy else { return }
        await refreshAuthenticationIfNeeded()
        guard let client, let lesson, canSubmit else { return }
        let marker = generation
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        do {
            let answers = try lesson.questions.map { question in
                guard let selected = selections[question.id] else {
                    throw ContractError.malformed("missing selection")
                }
                return QuizAnswer(
                    itemId: question.id, itemType: question.type, selected: [selected],
                    latencyMs: latencies[question.id] ?? 0
                )
            }
            let request = QuizSubmission(
                clientAttemptId: attemptID, trackId: lesson.trackId, startedAt: startedAt,
                answers: answers, publicManifestId: lesson.publicManifestId
            )
            let response = try await client.submit(lessonId: lesson.id, submission: request)
            guard generation == marker else { return }
            submittedRequest = request
            outcome = response
            let values = try await client.savedSubmissions()
            guard generation == marker else { return }
            queue = values
        } catch {
            guard generation == marker else { return }
            report(error)
            do {
                let values = try await client.savedSubmissions()
                guard generation == marker else { return }
                queue = values
                if let saved = values.first(where: { $0.id == attemptID }) {
                    submittedRequest = saved.submission
                    if saved.status == .pendingCorrection { outcome = .pendingCorrection }
                    if let result = saved.result { outcome = .corrected(result) }
                }
            } catch {
                guard generation == marker else { return }
                report(error)
            }
        }
    }

    func retry(_ saved: SavedSubmission) async {
        guard !busy else { return }
        await refreshAuthenticationIfNeeded()
        guard let client, !busy else { return }
        let marker = generation
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        do {
            let response = try await client.retry(attemptId: saved.id)
            guard generation == marker else { return }
            if saved.id == attemptID { outcome = response }
            let values = try await client.savedSubmissions()
            guard generation == marker else { return }
            queue = values
        } catch {
            guard generation == marker else { return }
            report(error)
        }
    }

    func refreshProgress() async {
        guard !busy else { return }
        await refreshAuthenticationIfNeeded()
        guard let client, let path, !busy else { return }
        let marker = generation
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        do {
            let value = try await client.path(trackId: path.trackId)
            guard generation == marker else { return }
            self.path = value
        } catch {
            guard generation == marker else { return }
            report(error)
        }
    }

    private func report(_ error: any Error) {
        switch error {
        case NativeResumeError.releaseChanged:
            errorMessage =
                "This content version changed. Your saved attempt was preserved; retry its original submission from saved responses."
        case is NativeResumeError:
            errorMessage =
                "This activity cannot be safely resumed. Your saved responses were preserved; choose a valid activity or review saved submissions."
        case CIAMAuthenticationFailure.interactionRequired:
            errorMessage = "Sign in explicitly with the test account to continue."
        case is CIAMAuthenticationFailure:
            errorMessage =
                "The test account connection is not confirmed. No sign-in or renewal is assumed."
        case APIError.unauthorized:
            errorMessage = "The test connection expired. Sign out, then reconnect this account."
        case APIError.configuration:
            errorMessage = "Enter a valid HTTPS API URL without credentials or query parameters."
        case APIError.staleSession:
            errorMessage = "The account changed. This response was not displayed."
        case APIError.transport:
            errorMessage = "The server is unreachable. Check the connection and retry."
        case APIError.http(let status):
            errorMessage =
                "The server rejected the request (HTTP \(status)). Retry or contact support."
        case ContractError.unsupported:
            errorMessage =
                "This content requires a capability that is unavailable in this native version."
        case StoreError.corruptArchive:
            errorMessage =
                "Saved responses could not be read. They were preserved and were not resent."
        case StoreError.capacity:
            errorMessage =
                "Response storage is full. Your answers are not confirmed as saved."
        case StoreError.invalidRecord:
            errorMessage =
                "This saved submission cannot be retried. Your answers were preserved; review its failure before starting another attempt."
        default:
            errorMessage =
                "The operation could not be confirmed. No success is assumed. Retry."
        }
    }
}
