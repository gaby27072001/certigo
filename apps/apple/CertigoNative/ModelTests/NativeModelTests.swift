// Linux-only source harness: the real Security vault, UIKit and MSAL are not linked or executed.
#if os(Linux)
    import CertigoData
    import CertigoDomain
    import Foundation
    import FoundationNetworking

    private enum ModelTestFailure: Error {
        case assertion(String)
        case forbiddenVaultOperation
    }
    struct CredentialVault: DeveloperConnectionVault {
        func read() throws -> DeveloperConnection? {
            throw ModelTestFailure.forbiddenVaultOperation
        }
        func save(_ connection: DeveloperConnection) throws {
            throw ModelTestFailure.forbiddenVaultOperation
        }
        func clear() throws { throw ModelTestFailure.forbiddenVaultOperation }
    }
    private final class MemoryVault: DeveloperConnectionVault {
        var saved: DeveloperConnection?
        var reads = 0
        var saves = 0
        var clears = 0
        var rejectClear = false
        func read() throws -> DeveloperConnection? {
            reads += 1
            return saved
        }
        func save(_ connection: DeveloperConnection) {
            saves += 1
            saved = connection
        }
        func clear() throws {
            clears += 1
            if rejectClear { throw ModelTestFailure.forbiddenVaultOperation }
            saved = nil
        }
    }
    @MainActor private final class AuthenticationMock: CIAMAuthenticationProvider {
        var token = CIAMAccessToken(
            value: "synthetic-auth-token", expiresAt: Date(timeIntervalSince1970: 2_000))
        var interactiveCalls = 0
        var silentCalls = 0
        var removals = 0
        var pause = false
        var rejectRemoval = false
        var failure: CIAMAuthenticationFailure?
        var waiter: CheckedContinuation<Void, Never>?
        private var busy = false

        func acquireInteractively() async throws -> CIAMAccessToken {
            interactiveCalls += 1
            return try await acquire()
        }
        func acquireSilently() async throws -> CIAMAccessToken {
            silentCalls += 1
            return try await acquire()
        }
        private func acquire() async throws -> CIAMAccessToken {
            guard !busy else { throw CIAMAuthenticationFailure.operationInProgress }
            busy = true
            defer { busy = false }
            if pause { await withCheckedContinuation { waiter = $0 } }
            if let failure { throw failure }
            return token
        }
        func resume() {
            waiter?.resume()
            waiter = nil
        }
        func removeLocalAccount() async throws {
            removals += 1
            if busy || rejectRemoval { throw CIAMAuthenticationFailure.operationInProgress }
        }
    }
    private actor ModelTransport: HTTPTransport {
        private let catalog: Data
        private let lesson: Data
        private let result: Data
        let manifestId = "sha256:" + String(repeating: "a", count: 64)
        private var owner = "server-owner-A"
        private var pause = false
        private var waiter: CheckedContinuation<Void, Never>?
        private var requests = 0
        private var offline = false
        private var corrected = false
        private var lessonStatus = 200
        private var pauseLesson = false
        private var posts: [Data] = []
        init(resources: URL) throws {
            catalog = try Data(contentsOf: resources.appendingPathComponent("catalog.json"))
            lesson = try Data(contentsOf: resources.appendingPathComponent("lesson.json"))
            let object = try JSONSerialization.jsonObject(
                with: Data(contentsOf: resources.appendingPathComponent("result.json")))
            guard var response = object as? [String: Any],
                var items = response["results"] as? [[String: Any]], !items.isEmpty
            else { throw ModelTestFailure.assertion("Invalid synthetic feedback fixture") }
            items[0]["correct"] = false
            items[0]["correctAnswer"] = ["second"]
            response["results"] = items
            response["scorePct"] = 0
            result = try JSONSerialization.data(withJSONObject: response)
        }
        func setOwner(_ value: String) { owner = value }
        func pauseProfile() { pause = true }
        func suspendLesson() { pauseLesson = true }
        func setOffline(_ value: Bool) { offline = value }
        func failLesson(_ status: Int) { lessonStatus = status }
        func payloads() -> [Data] { posts }
        func isWaiting() -> Bool { waiter != nil }
        func count() -> Int { requests }
        func resume() {
            waiter?.resume()
            waiter = nil
            pause = false
            pauseLesson = false
        }
        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests += 1
            guard let url = request.url else { throw APIError.configuration }
            let bytes: Data
            var status = 200
            var headers = ["Content-Type": "application/json"]
            if url.path.hasSuffix("/me") {
                let capturedOwner = owner
                if pause { await withCheckedContinuation { waiter = $0 } }
                bytes = Data(
                    """
                    {"id":"\(capturedOwner)","displayName":"Synthetic","xp":0,"activeTrackId":null}
                    """.utf8)
            } else if url.path.hasSuffix("/catalog/tracks") {
                bytes = catalog
            } else if url.path.hasSuffix("/me/paths/fixture:foundations") {
                let state = corrected ? "completed" : "available"
                bytes = Data(
                    """
                    {"trackId":"fixture:foundations","trackName":"Synthetic","readinessScore":12,
                    "units":[{"id":"fixture-unit","title":"Synthetic practice","lessons":[
                    {"id":"fixture-lesson","title":"Synthetic exercise","status":"\(state)","estMinutes":1}]}]}
                    """.utf8)
            } else if url.path.hasSuffix("/tracks/fixture:foundations/lessons/fixture-lesson") {
                if pauseLesson { await withCheckedContinuation { waiter = $0 } }
                bytes = lesson
                status = lessonStatus
                headers["X-Content-Manifest-Id"] = manifestId
                headers["ETag"] = "\"\(manifestId)\""
            } else if url.path.hasSuffix("/quiz/fixture-lesson/submit"),
                request.httpMethod == "POST"
            {
                guard let payload = request.httpBody else { throw APIError.invalidResponse }
                posts.append(payload)
                if offline { throw URLError(.notConnectedToInternet) }
                corrected = true
                bytes = result
            } else {
                throw APIError.invalidResponse
            }
            guard
                let response = HTTPURLResponse(
                    url: url, statusCode: status, httpVersion: nil, headerFields: headers)
            else { throw APIError.invalidResponse }
            return (bytes, response)
        }
    }
    @MainActor private final class ModelFixture {
        let root: URL
        let defaults: UserDefaults
        let suite: String
        let vault = MemoryVault()
        let provider = AuthenticationMock()
        let server: ModelTransport
        var time = Date(timeIntervalSince1970: 1_000)
        let configuration: CIAMConfiguration

        init(resources: URL) throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "certigo-model-\(UUID().uuidString)")
            suite = "certigo-model-tests-\(UUID().uuidString)"
            guard let defaults = UserDefaults(suiteName: suite) else {
                throw ModelTestFailure.assertion("Cannot create isolated preferences")
            }
            self.defaults = defaults
            server = try ModelTransport(resources: resources)
            configuration = try CIAMConfiguration(
                clientID: "11111111-1111-4111-8111-111111111111",
                tenantID: "22222222-2222-4222-8222-222222222222",
                authority: URL(string: "https://synthetic.ciamlogin.com")!,
                issuer: URL(
                    string:
                        "https://synthetic.ciamlogin.com/22222222-2222-4222-8222-222222222222/v2.0")!,
                authorityKind: .standard, apiBaseURL: URL(string: "https://example.invalid/api")!,
                apiScope: "api://33333333-3333-4333-8333-333333333333/user_impersonation",
                apiAudience: "33333333-3333-4333-8333-333333333333",
                redirectURI: URL(string: "synthetic-test://auth")!,
                registeredRedirects: ["synthetic-test://auth"],
                declaredCallbackSchemes: ["synthetic-test"], otherAppCallbackSchemes: [])
        }
        func model(authenticated: Bool = true) -> NativeModel {
            NativeModel(
                vault: vault, defaults: defaults,
                clientFactory: { [server, root] url in
                    LearningClient(
                        api: try CertigoAPI(baseURL: url, transport: server),
                        store: SubmissionStore(file: root.appendingPathComponent("outbox.json")))
                },
                authentication: authenticated ? (provider, configuration) : nil,
                now: { self.time })
        }
        func cleanup() {
            defaults.removePersistentDomain(forName: suite)
            if FileManager.default.fileExists(atPath: root.path) {
                do { try FileManager.default.removeItem(at: root) } catch {
                    fatalError("Synthetic fixture cleanup failed: \(error)")
                }
            }
        }
    }
    @main private struct NativeModelTests {
        @MainActor static func main() async throws {
            let resources = URL(fileURLWithPath: CommandLine.arguments[1])
            try await manualConnection(resources)
            try await authoritativeOwnerAndRefresh(resources)
            try await expiredTokenAndSilentFailure(resources)
            try await logoutDuringLogin(resources)
            try await logoutDuringRefresh(resources)
            try await logoutDuringProfile(resources)
            try await refusedCacheRemoval(resources)
            try await expiryDuringProfile(resources)
            try await manualLessonJourney(resources)
            try await lessonFailureAndLateOwner(resources)
            try resumeNavigation(resources)
            print(
                "NativeModel: 10 coordination/journey scenarios and resume-state checks passed."
            )
        }
        static func expect(_ condition: Bool, _ message: String) throws {
            if !condition { throw ModelTestFailure.assertion(message) }
        }
        static func expectResumeError(
            _ expected: NativeResumeError, _ operation: () throws -> Void
        ) throws {
            do {
                try operation()
            } catch let error as NativeResumeError {
                try expect(error == expected, "Unexpected resume-state rejection: \(error)")
                return
            }
            throw ModelTestFailure.assertion("Invalid resume-state operation succeeded")
        }
        static func resumeNavigation(_ resources: URL) throws {
            let owner = "synthetic-owner"
            let scope = "https://example.invalid/api"
            let pin = "sha256:" + String(repeating: "a", count: 64)
            let otherPin = "sha256:" + String(repeating: "b", count: 64)
            let session = NativeResumeState.Session(
                trackId: "fixture:foundations", lessonId: "fixture-lesson",
                publicManifestId: pin, phase: .draft, attemptId: nil)
            for tab in [NativeResumeState.Tab.objective, .explorer, .followUp] {
                let root = try NativeResumeState(tab: tab, ownerId: owner, apiScope: scope)
                try expect(try NativeResumeState.decode(root.encoded()) == root, "Root tab changed")
                let draft = try NativeResumeState(
                    tab: tab, ownerId: owner, apiScope: scope, session: session)
                let reopened = try NativeResumeState.decode(draft.encoded())
                let resumed = try reopened.reconciled(
                    ownerId: owner, apiScope: scope, currentManifestId: pin, submissions: [])
                try expect(resumed == draft, "Draft navigation changed on relaunch")
            }
            let draft = try NativeResumeState(
                tab: .explorer, ownerId: owner, apiScope: scope, session: session)
            try expectResumeError(.ownerChanged) {
                _ = try draft.reconciled(
                    ownerId: "another-owner", apiScope: scope,
                    currentManifestId: pin, submissions: [])
            }
            try expectResumeError(.scopeChanged) {
                _ = try draft.reconciled(
                    ownerId: owner, apiScope: "https://other.invalid/api",
                    currentManifestId: pin, submissions: [])
            }
            try expectResumeError(.releaseChanged) {
                _ = try draft.reconciled(
                    ownerId: owner, apiScope: scope,
                    currentManifestId: otherPin, submissions: [])
            }
            let request = QuizSubmission(
                clientAttemptId: "5d67e221-7649-4f23-bc51-a984f756d84a",
                trackId: session.trackId, startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                answers: [
                    QuizAnswer(
                        itemId: "fixture-question", itemType: "mcq",
                        selected: ["first"], latencyMs: 10)
                ], publicManifestId: pin)
            let submitting = try draft.beginningSubmission(request)
            try expectResumeError(.duplicateSubmission) {
                _ = try submitting.beginningSubmission(request)
            }
            try expectResumeError(.submissionUnresolved) {
                _ = try submitting.reconciled(
                    ownerId: owner, apiScope: scope, currentManifestId: pin, submissions: [])
            }
            var saved = SavedSubmission(
                ownerId: owner, apiScope: scope, lessonId: session.lessonId, submission: request)
            let relaunched = try NativeResumeState.decode(submitting.encoded())
            let pending = try relaunched.reconciled(
                ownerId: owner, apiScope: scope, currentManifestId: otherPin, submissions: [saved])
            try expect(
                pending.session?.phase == .pending
                    && pending.session?.attemptId == request.clientAttemptId
                    && pending.session?.publicManifestId == pin,
                "Pending recovery changed original identity or pin")
            try expectResumeError(.duplicateSubmission) {
                _ = try pending.beginningSubmission(request)
            }
            let wrongOwner = SavedSubmission(
                ownerId: "another-owner", apiScope: scope,
                lessonId: session.lessonId, submission: request)
            try expectResumeError(.attemptMismatch) {
                _ = try pending.reconciled(
                    ownerId: owner, apiScope: scope, currentManifestId: pin,
                    submissions: [wrongOwner])
            }
            let wrongPin = QuizSubmission(
                clientAttemptId: request.clientAttemptId, trackId: request.trackId,
                startedAt: request.startedAt, answers: request.answers, publicManifestId: otherPin)
            let mismatched = SavedSubmission(
                ownerId: owner, apiScope: scope, lessonId: session.lessonId, submission: wrongPin)
            try expectResumeError(.attemptMismatch) {
                _ = try draft.beginningSubmission(wrongPin)
            }
            try expectResumeError(.attemptMismatch) {
                _ = try pending.reconciled(
                    ownerId: owner, apiScope: scope, currentManifestId: otherPin,
                    submissions: [mismatched])
            }
            for invalid in [
                SavedSubmission(
                    ownerId: owner, apiScope: "https://other.invalid/api",
                    lessonId: session.lessonId, submission: request),
                SavedSubmission(
                    ownerId: owner, apiScope: scope,
                    lessonId: "different-lesson", submission: request),
            ] {
                try expectResumeError(.attemptMismatch) {
                    _ = try pending.reconciled(
                        ownerId: owner, apiScope: scope, currentManifestId: pin,
                        submissions: [invalid])
                }
            }
            try expectResumeError(.submissionUnresolved) {
                _ = try pending.reconciled(
                    ownerId: owner, apiScope: scope, currentManifestId: pin,
                    submissions: [saved, saved])
            }
            saved.status = .corrected
            try expectResumeError(.attemptMismatch) {
                _ = try pending.reconciled(
                    ownerId: owner, apiScope: scope, currentManifestId: pin, submissions: [saved])
            }
            saved.result = try CertigoAPI.decoder().decode(
                QuizResult.self,
                from: Data(contentsOf: resources.appendingPathComponent("result.json")))
            let confirmed = try pending.reconciled(
                ownerId: owner, apiScope: scope, currentManifestId: otherPin, submissions: [saved])
            try expect(
                confirmed.session?.phase == .confirmed,
                "Outbox correction did not determine confirmed navigation")
            var stillPending = saved
            stillPending.status = .pendingCorrection
            stillPending.result = nil
            let notConfirmed = try confirmed.reconciled(
                ownerId: owner, apiScope: scope, currentManifestId: pin,
                submissions: [stillPending])
            try expect(
                notConfirmed.session?.phase == .pending,
                "Persisted confirmed marker overruled pending outbox")
            try expectResumeError(.submissionUnresolved) {
                _ = try NativeResumeState.decode(confirmed.encoded()).reconciled(
                    ownerId: owner, apiScope: scope, currentManifestId: pin, submissions: [])
            }
            saved.status = .failed
            saved.result = nil
            let failed = try confirmed.reconciled(
                ownerId: owner, apiScope: scope, currentManifestId: pin, submissions: [saved])
            try expect(failed.session?.phase == .failed, "Failed outbox entry became corrected")
            let rootObject = try JSONSerialization.jsonObject(with: draft.encoded())
            guard var object = rootObject as? [String: Any],
                var fields = object["session"] as? [String: Any]
            else { throw ModelTestFailure.assertion("Invalid synthetic route fixture") }
            object["unexpected"] = true
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(JSONSerialization.data(withJSONObject: object))
            }
            object.removeValue(forKey: "unexpected")
            object["schema"] = 99
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(JSONSerialization.data(withJSONObject: object))
            }
            object["schema"] = 1
            fields["unknown"] = true
            object["session"] = fields
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(JSONSerialization.data(withJSONObject: object))
            }
            fields.removeValue(forKey: "unknown")
            fields["phase"] = "correctLocally"
            object["session"] = fields
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(JSONSerialization.data(withJSONObject: object))
            }
            fields["phase"] = "submitting"
            fields["attemptId"] = "not-an-attempt-uuid"
            object["session"] = fields
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(JSONSerialization.data(withJSONObject: object))
            }
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(Data(repeating: 32, count: 8_193))
            }
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(Data("truncated {".utf8))
            }
            let traversal = NativeResumeState.Session(
                trackId: session.trackId, lessonId: "..", publicManifestId: pin,
                phase: .draft, attemptId: nil)
            try expectResumeError(.malformed) {
                _ = try NativeResumeState(
                    tab: .objective, ownerId: owner, apiScope: scope, session: traversal)
            }
        }
        @MainActor static func wait(_ condition: @MainActor () async -> Bool) async throws {
            for _ in 0..<10_000 {
                if await condition() { return }
                await Task.yield()
            }
            throw ModelTestFailure.assertion("Synthetic suspension not reached")
        }
        @MainActor static func manualConnection(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-manual-token"
            await model.connect()
            try expect(model.profile?.id == "server-owner-A", "Manual /me owner not published")
            try expect(fixture.vault.saves == 1 && model.token.isEmpty, "Manual vault save changed")
            try expect(fixture.provider.interactiveCalls == 0, "Manual flow called auth provider")
            let restored = fixture.model(authenticated: false)
            await restored.restore()
            try expect(restored.profile?.id == "server-owner-A", "Manual restore changed")
            try expect(fixture.vault.reads == 1, "Manual restore skipped injected vault")
            fixture.vault.rejectClear = true
            await model.disconnect()
            try expect(model.profile == nil && model.errorMessage != nil, "Vault failure hidden")
        }
        @MainActor static func authoritativeOwnerAndRefresh(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            await model.connect()
            try expect(model.profile?.id == "server-owner-A", "Auth owner not from /me")
            try expect(model.errorMessage == nil && !model.busy, "Auth publication failed")
            try expect(fixture.vault.saves == 0, "Auth token entered developer vault")
            await model.refreshAuthenticationIfNeeded()
            try expect(fixture.provider.silentCalls == 0, "Fresh token refreshed unnecessarily")
            model.selections = ["synthetic-question": "synthetic-selection"]
            fixture.time = Date(timeIntervalSince1970: 1_990)
            fixture.provider.token = CIAMAccessToken(
                value: "synthetic-refreshed", expiresAt: Date(timeIntervalSince1970: 3_000))
            await model.refreshAuthenticationIfNeeded()
            try expect(!model.selections.isEmpty, "Same-owner refresh discarded session state")
            await fixture.server.setOwner("server-owner-B")
            fixture.time = Date(timeIntervalSince1970: 2_990)
            fixture.provider.token = CIAMAccessToken(
                value: "synthetic-other-owner", expiresAt: Date(timeIntervalSince1970: 4_000))
            await model.refreshAuthenticationIfNeeded()
            try expect(model.profile?.id == "server-owner-B", "Refreshed /me owner not rebound")
            try expect(model.selections.isEmpty, "New owner retained old selections")
            try expect(fixture.provider.silentCalls == 2, "Silent refresh not called")
            await model.disconnect()
            try expect(model.profile == nil && fixture.provider.removals == 1, "Logout not closed")
            try expect(fixture.vault.clears == 0, "Auth logout touched developer vault")
            await model.restore()
            try expect(fixture.provider.silentCalls == 2, "Logout auto-restored auth")
        }
        @MainActor static func expiredTokenAndSilentFailure(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            fixture.provider.failure = .interactionRequired
            await model.restore()
            try expect(
                model.profile == nil && fixture.provider.interactiveCalls == 0,
                "Silent startup implicitly opened interaction")
            try expect(fixture.vault.reads == 0, "Auth restore read developer vault")
            fixture.provider.failure = nil
            fixture.provider.token = CIAMAccessToken(
                value: "synthetic-expired", expiresAt: fixture.time)
            await model.connect()
            let count = await fixture.server.count()
            try expect(count == 0 && model.profile == nil, "Expired token reached /me")
            try expect(model.errorMessage != nil, "Expired token returned success")
            fixture.provider.token = CIAMAccessToken(
                value: "synthetic-valid", expiresAt: Date(timeIntervalSince1970: 2_000))
            await model.connect()
            fixture.time = Date(timeIntervalSince1970: 1_990)
            fixture.provider.failure = .interactionRequired
            await model.refreshAuthenticationIfNeeded()
            try expect(model.profile == nil && model.errorMessage != nil, "Refresh failure hidden")
            try expect(fixture.provider.interactiveCalls == 2, "Silent failure opened interaction")
        }
        @MainActor static func logoutDuringLogin(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            fixture.provider.pause = true
            let login = Task { await model.connect() }
            try await wait { fixture.provider.waiter != nil }
            await model.disconnect()
            try expect(model.errorMessage != nil, "Busy cache removal presented success")
            fixture.provider.resume()
            await login.value
            let count = await fixture.server.count()
            try expect(count == 0 && model.profile == nil && !model.busy, "Late login republished")
            try expect(model.errorMessage != nil, "Late login hid failed cleanup")
            await model.disconnect()
            try expect(model.errorMessage == nil, "Explicit cleanup retry did not complete")
        }
        @MainActor static func logoutDuringRefresh(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            await model.connect()
            fixture.time = Date(timeIntervalSince1970: 1_990)
            fixture.provider.pause = true
            let refresh = Task { await model.refreshAuthenticationIfNeeded() }
            try await wait { fixture.provider.waiter != nil }
            await model.disconnect()
            fixture.provider.resume()
            await refresh.value
            try expect(model.profile == nil && model.errorMessage != nil, "Late refresh restored")
        }
        @MainActor static func logoutDuringProfile(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            await fixture.server.pauseProfile()
            let login = Task { await model.connect() }
            try await wait { await fixture.server.isWaiting() }
            await model.disconnect()
            await fixture.server.resume()
            await login.value
            try expect(model.profile == nil && model.tracks.isEmpty, "Late /me restored session")
            let count = await fixture.server.count()
            try expect(count == 1, "Stale /me started catalog request")
        }
        @MainActor static func refusedCacheRemoval(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            await model.connect()
            fixture.provider.rejectRemoval = true
            await model.disconnect()
            try expect(model.profile == nil && model.errorMessage != nil, "Removal refusal hidden")
            await model.restore()
            try expect(fixture.provider.silentCalls == 0, "Rejected logout auto-restored")
            fixture.provider.rejectRemoval = false
            await model.disconnect()
            try expect(model.errorMessage == nil, "Cleanup retry still reported failure")
        }
        @MainActor static func expiryDuringProfile(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            await fixture.server.pauseProfile()
            let login = Task { await model.connect() }
            try await wait { await fixture.server.isWaiting() }
            fixture.time = fixture.provider.token.expiresAt
            await fixture.server.resume()
            await login.value
            try expect(
                model.profile == nil && model.errorMessage != nil,
                "Token expiring during /me was published")
            let count = await fixture.server.count()
            try expect(count == 1, "Expired /me result triggered a catalog request")
        }
        @MainActor static func manualLessonJourney(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-manual-token"
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("No discovered catalog track")
            }
            await model.loadPath(track)
            guard let node = model.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("No discovered path lesson")
            }
            await model.loadLesson(node)
            guard let lesson = model.lesson, let question = lesson.questions.first,
                let option = question.options.first
            else { throw ModelTestFailure.assertion("No supported lesson question") }
            try expect(
                lesson.publicManifestId == fixture.server.manifestId,
                "Header-only pin not normalized into lesson")
            try expect(!model.canSubmit, "Unanswered lesson accepted")
            model.questionAppeared(question.id)
            model.select(option, question: question)
            try expect(model.canSubmit, "Identified option did not enable submission")
            await fixture.server.setOffline(true)
            await model.submit()
            try expect(model.outcome == .pendingCorrection, "Offline model guessed a verdict")
            try expect(!model.canSubmit && !model.busy, "Pending submission remained editable/busy")
            guard let saved = model.queue.first else {
                throw ModelTestFailure.assertion("Pending submission missing from model queue")
            }
            try expect(
                saved.ownerId == "server-owner-A" && saved.result == nil,
                "Pending attempt owner/result incorrect")
            try expect(
                saved.submission.answers.first?.selected == [option.id]
                    && saved.submission.publicManifestId == fixture.server.manifestId,
                "Option identity or header pin lost before persistence")
            let reopened = fixture.model(authenticated: false)
            await reopened.restore()
            try expect(reopened.queue == [saved], "Manual model restart changed pending request")
            await fixture.server.setOffline(false)
            await reopened.retry(saved)
            guard let result = reopened.queue.first?.result else {
                throw ModelTestFailure.assertion("Retry feedback not reflected in queue")
            }
            try expect(
                result.scorePct == 0 && !result.results[0].correct, "Server verdict replaced")
            try expect(
                !result.results[0].explanation.isEmpty, "Authorized feedback not displayed")
            let payloads = await fixture.server.payloads()
            try expect(
                payloads.count == 2 && payloads[0] == payloads[1],
                "Model retry changed attempt payload or emitted extra request")
            await reopened.loadPath(track)
            await reopened.refreshProgress()
            try expect(
                reopened.path?.units.first?.lessons.first?.status == .completed,
                "Reviewed concepts were not refreshed after wrong answer")
            try expect(reopened.queue.first?.result?.scorePct == 0, "Progress changed quiz score")
            await reopened.retry(saved)
            let afterRepeat = await fixture.server.payloads()
            try expect(afterRepeat.count == 2, "Corrected retry repeated POST")
        }
        @MainActor static func lessonFailureAndLateOwner(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-manual-token"
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing synthetic track")
            }
            await model.loadPath(track)
            guard let node = model.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("Missing synthetic lesson node")
            }
            await fixture.server.failLesson(503)
            await model.loadLesson(node)
            try expect(
                model.lesson == nil && model.errorMessage != nil && !model.busy,
                "Lesson loading failure became success or stayed busy")
            await fixture.server.failLesson(200)
            await model.loadLesson(node)
            try expect(model.lesson != nil && model.errorMessage == nil, "Retry did not recover")
            await fixture.server.suspendLesson()
            let late = Task { await model.loadLesson(node) }
            try await wait { await fixture.server.isWaiting() }
            try expect(model.busy, "Suspended lesson did not expose loading state")
            await model.disconnect()
            await fixture.server.setOwner("server-owner-B")
            model.token = "synthetic-owner-B-token"
            await model.connect()
            await fixture.server.resume()
            await late.value
            try expect(
                model.profile?.id == "server-owner-B" && model.lesson == nil
                    && model.queue.isEmpty && !model.busy,
                "Late previous-owner lesson leaked into new model session")
        }
    }
#endif
