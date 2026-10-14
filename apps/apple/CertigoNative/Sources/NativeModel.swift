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

@Observable @MainActor
final class NativeModel {
    var baseURL = ""
    var token = ""
    private(set) var profile: Profile?
    private(set) var tracks: [Track] = []
    private(set) var path: LearningPath?
    private(set) var lesson: Lesson?
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
        return lesson.questions.allSatisfy { selections[$0.id] != nil }
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
                "La connexion de test ne peut pas être restaurée. Reconnectez le compte de test."
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
        busy = true
        errorMessage = nil
        defer { if generation == marker { busy = false } }
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
                    "La session locale est fermée, mais le retrait du compte du SDK n’est pas confirmé. Réessayez la déconnexion."
            }
        } else {
            do { try vault.clear() } catch {
                errorMessage =
                    "Le coffre n’a pas confirmé la déconnexion. Réessayez avant de fermer l’app."
            }
        }
    }

    private func clearSession() {
        client = nil
        profile = nil
        tracks = []
        path = nil
        lesson = nil
        selections = [:]
        questionStarted = [:]
        latencies = [:]
        queue = []
        outcome = nil
        submittedRequest = nil
        token = ""
        tokenExpiresAt = nil
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
        let marker = generation
        busy = true
        lesson = nil
        errorMessage = nil
        defer { if generation == marker { busy = false } }
        do {
            let value = try await client.lesson(trackId: path.trackId, lessonId: node.id)
            guard generation == marker else { return }
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

    func questionAppeared(_ id: String) {
        if questionStarted[id] == nil { questionStarted[id] = ContinuousClock.now }
    }

    func select(_ option: QuizOption, question: QuizItem) {
        guard outcome == nil, submittedRequest == nil, !busy else { return }
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
        case CIAMAuthenticationFailure.interactionRequired:
            errorMessage = "Une connexion explicite du compte de test est nécessaire."
        case is CIAMAuthenticationFailure:
            errorMessage =
                "La connexion du compte de test n’est pas confirmée. Aucun compte ni renouvellement n’est supposé."
        case APIError.unauthorized:
            errorMessage = "La connexion de test a expiré. Déconnectez puis reconnectez ce compte."
        case APIError.configuration:
            errorMessage = "Indiquez une URL API HTTPS valide, sans identifiant ni paramètre."
        case APIError.staleSession:
            errorMessage = "Le compte a changé. Cette réponse n’a pas été affichée."
        case APIError.transport:
            errorMessage = "Le serveur est injoignable. Vérifiez la connexion puis réessayez."
        case APIError.http(let status):
            errorMessage =
                "Le serveur a refusé la requête (HTTP \(status)). Réessayez ou contactez le support."
        case ContractError.unsupported:
            errorMessage =
                "Ce contenu nécessite une capacité non disponible dans cette première version native."
        case StoreError.corruptArchive:
            errorMessage =
                "Les réponses locales sont illisibles. Elles ont été conservées, sans être renvoyées."
        case StoreError.capacity:
            errorMessage =
                "Le stockage des réponses est plein. Les réponses ne sont pas confirmées comme enregistrées."
        default:
            errorMessage =
                "L’opération n’a pas pu être confirmée. Aucune réussite n’est supposée. Réessayez."
        }
    }
}
