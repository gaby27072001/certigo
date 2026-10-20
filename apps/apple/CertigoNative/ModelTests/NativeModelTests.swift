// Linux-only source harness: the real Security vault, UIKit and MSAL are not linked or executed.
#if os(Linux)
    import CertigoData
    import CertigoDomain
    import Foundation
    import FoundationNetworking

    private enum ModelTestFailure: Error {
        case assertion(String)
        case forbiddenVaultOperation
        case forbiddenActivityOperation
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
        private var catalog: Data
        private let lesson: Data
        private let result: Data
        let manifestId = "sha256:" + String(repeating: "a", count: 64)
        private var owner = "server-owner-A"
        private var pathRequests = 0
        private var pause = false
        private var waiter: CheckedContinuation<Void, Never>?
        private var requests = 0
        private var offline = false
        private var corrected = false
        private var lessonStatus = 200
        private var submissionStatus = 200
        private var pathStatus = 200
        private var nodeStatus: String?
        private var replacementLesson: Data?
        private var pauseLesson = false
        private var posts: [Data] = []
        private var replacementManifest: String?
        private var activeGoal: String?
        private var goalPosts: [Data] = []
        private var goalStatus = 200
        private var pauseGoal = false
        private var goalResponseOwner: String?
        private var profileStatus = 200
        private var profileXP = 0
        private var profileRequests = 0
        private var pilotContent: Data?
        private var pilotLessonID = "verify-claims"
        private var pausePilotHistory = false
        private var pilotHistoryStatus = 200
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
        func enablePilot(_ content: Data) { pilotContent = content }
        func setPilotLesson(_ value: String) { pilotLessonID = value }
        func suspendPilotHistory() { pausePilotHistory = true }
        func failPilotHistory(_ status: Int) { pilotHistoryStatus = status }
        func pathRequestCount() -> Int { pathRequests }
        func addSecondGoal() throws {
            guard var object = try JSONSerialization.jsonObject(with: catalog) as? [String: Any],
                var tracks = object["tracks"] as? [[String: Any]], var second = tracks.first
            else { throw ModelTestFailure.assertion("Missing synthetic catalog track") }
            second["id"] = "fixture:second"
            tracks.append(second)
            object["tracks"] = tracks
            catalog = try JSONSerialization.data(withJSONObject: object)
        }
        func setGoal(_ value: String?) { activeGoal = value }
        func failGoal(_ status: Int) { goalStatus = status }
        func failProfile(_ status: Int) { profileStatus = status }
        func setProfileXP(_ value: Int) { profileXP = value }
        func profileRequestCount() -> Int { profileRequests }
        func allowProfiles() { pause = false }
        func suspendGoal() { pauseGoal = true }
        func respondAsOwner(_ value: String?) { goalResponseOwner = value }
        func goalPayloads() -> [Data] { goalPosts }
        func pauseProfile() { pause = true }
        func suspendLesson() { pauseLesson = true }
        func setOffline(_ value: Bool) { offline = value }
        func failLesson(_ status: Int) { lessonStatus = status }
        func failSubmission(_ status: Int) { submissionStatus = status }
        func failPath(_ status: Int) { pathStatus = status }
        func setNodeStatus(_ value: String) { nodeStatus = value }
        func removeTracks() throws {
            guard var object = try JSONSerialization.jsonObject(with: catalog) as? [String: Any]
            else { throw ModelTestFailure.assertion("Missing catalog") }
            object["tracks"] = []
            catalog = try JSONSerialization.data(withJSONObject: object)
        }
        func changeLesson() throws {
            guard var object = try JSONSerialization.jsonObject(with: lesson) as? [String: Any]
            else { throw ModelTestFailure.assertion("Missing lesson") }
            object["title"] = "Changed content under the same manifest"
            replacementLesson = try JSONSerialization.data(withJSONObject: object)
        }
        func addQuestion() throws {
            guard var object = try JSONSerialization.jsonObject(with: lesson) as? [String: Any],
                var blocks = object["blocks"] as? [[String: Any]],
                var block = blocks.first(where: { $0["type"] as? String == "check" }),
                var question = block["check"] as? [String: Any]
            else { throw ModelTestFailure.assertion("Missing check block") }
            question["id"] = "second-question"
            block["check"] = question
            blocks.append(block)
            object["blocks"] = blocks
            replacementLesson = try JSONSerialization.data(withJSONObject: object)
        }
        func setManifest(_ value: String) { replacementManifest = value }
        func payloads() -> [Data] { posts }
        func isWaiting() -> Bool { waiter != nil }
        func count() -> Int { requests }
        func resume() {
            waiter?.resume()
            waiter = nil
            pause = false
            pauseLesson = false
            pauseGoal = false
        }
        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests += 1
            guard let url = request.url else { throw APIError.configuration }
            let bytes: Data
            var status = 200
            var headers = ["Content-Type": "application/json"]
            if url.path.hasSuffix("/me") {
                profileRequests += 1
                status = profileStatus
                let capturedOwner = owner
                let capturedXP = profileXP
                let goal = activeGoal.map { "\"\($0)\"" } ?? "null"
                if pause { await withCheckedContinuation { waiter = $0 } }
                bytes = Data(
                    """
                    {"id":"\(capturedOwner)","displayName":"Synthetic","xp":\(capturedXP),"activeTrackId":\(goal)}
                    """.utf8)
            } else if url.path.hasSuffix("/me/active-track"), request.httpMethod == "POST" {
                guard let payload = request.httpBody,
                    let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any],
                    let target = object["trackId"] as? String
                else { throw APIError.invalidResponse }
                goalPosts.append(payload)
                let expected = object["expectedTrackId"] as? String
                status = goalStatus
                if status == 200 {
                    if activeGoal?.lowercased() == target.lowercased() || activeGoal == expected {
                        activeGoal = target.lowercased()
                    } else {
                        status = 409
                    }
                }
                let capturedOwner = goalResponseOwner ?? owner
                let capturedGoal = activeGoal.map { "\"\($0)\"" } ?? "null"
                if pauseGoal { await withCheckedContinuation { waiter = $0 } }
                if offline { throw URLError(.networkConnectionLost) }
                bytes = Data(
                    """
                    {"id":"\(capturedOwner)","displayName":"Authoritative","xp":321,"activeTrackId":\(capturedGoal)}
                    """.utf8)
            } else if url.path.hasSuffix("/catalog/tracks") {
                bytes = catalog
            } else if url.path.hasSuffix("/pilots/responsible-ai-assistants/content"),
                let content = pilotContent
            {
                bytes = content
                let digest = "sha256:\(try CanonicalQuestionReader.digest(content).sha256)"
                headers["X-Certigo-Pilot-Content-Digest"] = digest
                headers["ETag"] = "\"\(digest)\""
            } else if url.path.contains("/pilots/responsible-ai-assistants/history/"),
                let content = pilotContent
            {
                let digest = "sha256:\(try CanonicalQuestionReader.digest(content).sha256)"
                bytes = Data(
                    """
                    {"pilotId":"responsible-ai-assistants","contentDigest":"\(digest)",
                    "lastLessonId":"\(pilotLessonID)","lessons":[
                    {"lessonId":"\(pilotLessonID)","lastAccessedAt":"2026-10-19T10:01:00Z",
                    "markedReadAt":null}]}
                    """.utf8)
                status = pilotHistoryStatus
                if pausePilotHistory {
                    pausePilotHistory = false
                    await withCheckedContinuation { waiter = $0 }
                }
            } else if url.path.contains("/pilots/responsible-ai-assistants/lessons/"),
                request.httpMethod == "POST", pilotContent != nil
            {
                let marked = url.path.contains("/read/") ? "\"2026-10-19T10:02:00Z\"" : "null"
                bytes = Data(
                    """
                    {"lessonId":"\(pilotLessonID)","lastAccessedAt":"2026-10-19T10:01:00Z",
                    "markedReadAt":\(marked)}
                    """.utf8)
            } else if url.path.hasSuffix("/me/paths/fixture:foundations") {
                pathRequests += 1
                let state = nodeStatus ?? (corrected ? "completed" : "available")
                status = pathStatus
                bytes = Data(
                    """
                    {"trackId":"fixture:foundations","trackName":"Synthetic","readinessScore":12,
                    "units":[{"id":"fixture-unit","title":"Synthetic practice","lessons":[
                    {"id":"fixture-lesson","title":"Synthetic exercise","status":"\(state)","estMinutes":1}]}]}
                    """.utf8)
            } else if url.path.hasSuffix("/tracks/fixture:foundations/lessons/fixture-lesson") {
                if pauseLesson { await withCheckedContinuation { waiter = $0 } }
                bytes = replacementLesson ?? lesson
                status = lessonStatus
                let pin = replacementManifest ?? manifestId
                headers["X-Content-Manifest-Id"] = pin
                headers["ETag"] = "\"\(pin)\""
            } else if url.path.hasSuffix("/quiz/fixture-lesson/submit"),
                request.httpMethod == "POST"
            {
                guard let payload = request.httpBody else { throw APIError.invalidResponse }
                posts.append(payload)
                if offline { throw URLError(.notConnectedToInternet) }
                status = submissionStatus
                corrected = status == 200
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
        var rejectActivityAccess = false
        var activityFile: URL { root.appendingPathComponent("activity.json") }
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
                activityStore: {
                    if self.rejectActivityAccess {
                        throw ModelTestFailure.forbiddenActivityOperation
                    }
                    return NativeActivityStore(file: self.activityFile)
                },
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
            try await rejectedRetryRefreshesSavedState(resources)
            try await confirmedProfileAfterCorrection(resources)
            try await confirmedProfileAfterPendingRetry(resources)
            try await confirmedProfileFailurePreservesCorrection(resources)
            try await lateConfirmedProfileIsNotRepublished(resources)
            try await manualConnection(resources)
            try await authoritativeOwnerAndRefresh(resources)
            try await stalePathSelectionAfterOwnerRefresh(resources)
            try await expiredTokenAndSilentFailure(resources)
            try await logoutDuringLogin(resources)
            try await logoutDuringRefresh(resources)
            try await logoutDuringProfile(resources)
            try await refusedCacheRemoval(resources)
            try await expiryDuringProfile(resources)
            try await manualLessonJourney(resources)
            try await lessonFailureAndLateOwner(resources)
            try await pendingReleaseAndAccountRecovery(resources)
            try await failedAndAmbiguousRecovery(resources)
            try await explicitGoalSelection(resources)
            try await lateGoalResponse(resources)
            try await pilotHistorySessionIsolation(resources)
            try resumeNavigation(resources)
            try await coldActivityRestoration(resources)
            try await partialDraftRestoration(resources)
            try await invalidActivityRestoration(resources)
            try await interruptedActivityRestoration(resources)
            try await submittedActivityRestoration(resources)
            try await activityStorageFailure(resources)
            try await sameOwnerRefreshKeepsDraft(resources)
            print(
                "NativeModel: coordination/journeys, pilot-history isolation, resume-state and cold activity restoration checks passed."
            )
        }
        static func expect(_ condition: Bool, _ message: String) throws {
            if !condition { throw ModelTestFailure.assertion(message) }
        }
        @MainActor static func rejectedRetryRefreshesSavedState(_ resources: URL) async throws {
            for status in [403, 422, 401, 503] {
                let fixture = try ModelFixture(resources: resources)
                defer { fixture.cleanup() }
                let model = try await prepareDraft(fixture)
                await fixture.server.setOffline(true)
                await model.submit()
                guard let pending = model.queue.first else {
                    throw ModelTestFailure.assertion("Missing pending recovery fixture")
                }
                await fixture.server.setOffline(false)
                await fixture.server.failSubmission(status)
                await model.retry(pending)
                let terminal = status == 403 || status == 422
                let expectedStatus: SubmissionStatus = terminal ? .failed : .pendingCorrection
                try expect(
                    model.queue.first?.status == expectedStatus,
                    "Rejected retry left a stale pending row instead of durable failed state")
                try expect(
                    model.outcome == (terminal ? nil : .pendingCorrection) && !model.canSubmit
                        && !model.busy && model.queue.first?.result == nil,
                    "Rejected retry retained a false pending outcome or became editable")
                if terminal {
                    try expect(
                        model.errorMessage?.contains("HTTP \(status)") == true,
                        "Rejected retry lost its explicit HTTP feedback")
                }
                let reopened = fixture.model(authenticated: false)
                await reopened.restore()
                try expect(
                    reopened.queue == model.queue,
                    "Displayed retry status disagrees with the reopened durable outbox")
                try expect(
                    reopened.outcome == model.outcome && !reopened.canSubmit,
                    "Saved activity restored a rejected retry as pending or editable")
                if terminal {
                    await model.retry(pending)
                    let posts = await fixture.server.payloads()
                    try expect(
                        posts.count == 2 && model.queue.first?.status == .failed,
                        "Terminal retry was posted again or reverted to pending")
                }
                let feedback = model.errorMessage ?? ""
                try expect(
                    !feedback.contains("synthetic-A")
                        && !feedback.contains("https://example.invalid")
                        && !feedback.contains(pending.submission.clientAttemptId)
                        && !feedback.contains("fixture-question"),
                    "Recovery feedback exposed connection or answer details")
            }
        }
        @MainActor static func confirmedProfileAfterCorrection(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = try await prepareDraft(fixture)
            try expect(model.profile?.xp == 0, "Unexpected initial synthetic profile")
            await fixture.server.setProfileXP(963)
            await model.submit()
            guard let saved = model.queue.first, case .corrected(let result) = model.outcome else {
                throw ModelTestFailure.assertion("Missing server correction")
            }
            try expect(
                model.profile?.xp == 963 && result.rewards.xpEarned == 10,
                "Confirmed profile XP remained stale or was computed from quiz rewards")
            try expect(
                saved.status == .corrected && !model.busy && !model.canSubmit,
                "Profile refresh lost correction state")
            let profiles = await fixture.server.profileRequestCount()
            try expect(profiles == 2, "Confirmed correction did not reload /me once")
            await fixture.server.setProfileXP(1_007)
            await model.retry(saved)
            let posts = await fixture.server.payloads()
            try expect(
                model.profile?.xp == 1_007 && posts.count == 1,
                "Rechecking an ACK added local XP or resubmitted the quiz")
        }
        @MainActor static func confirmedProfileAfterPendingRetry(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = try await prepareDraft(fixture)
            await fixture.server.setProfileXP(963)
            await fixture.server.setOffline(true)
            await model.submit()
            let profiles = await fixture.server.profileRequestCount()
            try expect(
                model.outcome == .pendingCorrection && model.profile?.xp == 0 && profiles == 1,
                "Pending correction refreshed or awarded unconfirmed XP")
            guard let saved = model.queue.first else {
                throw ModelTestFailure.assertion("Missing pending request")
            }
            await fixture.server.setOffline(false)
            await model.retry(saved)
            let posts = await fixture.server.payloads()
            try expect(
                model.profile?.xp == 963 && model.queue.first?.status == .corrected,
                "Confirmed retry did not reload authoritative profile")
            try expect(
                posts.count == 2 && posts[0] == posts[1],
                "Profile refresh changed the pending attempt or posted twice")
        }
        @MainActor static func confirmedProfileFailurePreservesCorrection(_ resources: URL)
            async throws
        {
            for status in [401, 503, 200] {
                let fixture = try ModelFixture(resources: resources)
                defer { fixture.cleanup() }
                let model = try await prepareDraft(fixture)
                await fixture.server.setProfileXP(963)
                await fixture.server.failProfile(status)
                if status == 200 { await fixture.server.setOwner("unexpected-owner") }
                await model.submit()
                guard let saved = model.queue.first, case .corrected = model.outcome else {
                    throw ModelTestFailure.assertion("Profile failure rolled back a valid ACK")
                }
                try expect(
                    saved.status == .corrected && saved.result != nil && !model.canSubmit
                        && !model.busy && model.errorMessage != nil,
                    "Profile failure hid error or removed durable correction")
                try expect(
                    model.profile?.id == "server-owner-A" && model.profile?.xp == 0,
                    "Failed or foreign profile replaced authoritative account/XP")
                await fixture.server.failProfile(200)
                await fixture.server.setOwner("server-owner-A")
                await model.retry(saved)
                let posts = await fixture.server.payloads()
                try expect(
                    model.profile?.xp == 963 && model.errorMessage == nil && posts.count == 1,
                    "Profile recovery failed or credited the ACK a second time")
            }
        }
        @MainActor static func lateConfirmedProfileIsNotRepublished(_ resources: URL) async throws {
            for retrying in [false, true] {
                let fixture = try ModelFixture(resources: resources)
                defer { fixture.cleanup() }
                let model = try await prepareDraft(fixture)
                if retrying {
                    await fixture.server.setOffline(true)
                    await model.submit()
                    await fixture.server.setOffline(false)
                }
                let pending = model.queue.first
                await fixture.server.setProfileXP(963)
                await fixture.server.pauseProfile()
                let late = Task {
                    if let pending {
                        await model.retry(pending)
                    } else {
                        await model.submit()
                    }
                }
                try await wait { await fixture.server.isWaiting() }
                try expect(
                    model.queue.first?.status == .corrected && model.busy,
                    "ACK was not retained while profile refresh was pending")
                await model.disconnect()
                await fixture.server.allowProfiles()
                await fixture.server.setOwner("server-owner-B")
                await fixture.server.setProfileXP(1_729)
                model.token = "synthetic-B"
                await model.connect()
                await fixture.server.resume()
                await late.value
                try expect(
                    model.profile?.id == "server-owner-B" && model.profile?.xp == 1_729
                        && model.queue.isEmpty && model.outcome == nil
                        && model.errorMessage == nil && !model.busy,
                    "Old correction/profile refresh leaked into the replacement session")
                let entries = try await SubmissionStore(
                    file: fixture.root.appendingPathComponent("outbox.json")
                ).entries(ownerId: "server-owner-A", apiScope: "https://example.invalid/api")
                try expect(
                    entries.count == 1 && entries.first?.status == .corrected,
                    "Account switch lost the original owner's ACK")
            }
        }
        @MainActor static func prepareDraft(_ fixture: ModelFixture) async throws -> NativeModel {
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-A"
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing draft track")
            }
            await model.loadPath(track)
            guard let node = model.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("Missing draft node")
            }
            await model.loadLesson(node)
            guard let question = model.lesson?.questions.first, let option = question.options.first
            else { throw ModelTestFailure.assertion("Missing draft question") }
            model.select(option, question: question)
            return model
        }
        @MainActor static func coldActivityRestoration(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = try await prepareDraft(fixture)
            model.selectedTab = .profile
            guard let bytes = try NativeActivityStore(file: fixture.activityFile).read() else {
                throw ModelTestFailure.assertion("Draft was not persisted")
            }
            let snapshot = try NativeActivitySnapshot.decode(bytes)
            try expect(
                snapshot.draft?.startedAt == fixture.time && snapshot.draft?.latencies == [:]
                    && !String(decoding: bytes, as: UTF8.self).contains("synthetic-A"),
                "Draft lost deterministic timing or persisted a token")
            let reopened = fixture.model(authenticated: false)
            await reopened.restore()
            try expect(
                reopened.path?.trackId == model.path?.trackId
                    && reopened.lesson?.id == model.lesson?.id
                    && reopened.selections == model.selections
                    && reopened.selectedTab == .profile && reopened.canSubmit
                    && reopened.queue.isEmpty && reopened.outcome == nil
                    && reopened.restorationRevision == 1 && reopened.errorMessage == nil,
                "Cold restore lost route, selections, or draft editability")
            let noPosts = await fixture.server.payloads()
            try expect(noPosts.isEmpty, "Restoration automatically submitted a draft")
            guard let track = reopened.tracks.first else {
                throw ModelTestFailure.assertion("Missing restored track")
            }
            await reopened.loadPath(track)
            try expect(
                reopened.lesson?.id == model.lesson?.id && reopened.selections == model.selections,
                "Browsing discarded the active unsent activity")
            let again = fixture.model(authenticated: false)
            await again.restore()
            await again.submit()
            let posts = await fixture.server.payloads()
            guard let payload = posts.first else {
                throw ModelTestFailure.assertion("Explicit restored submission was not sent")
            }
            let request = try CertigoAPI.decoder().decode(QuizSubmission.self, from: payload)
            try expect(
                posts.count == 1 && request.clientAttemptId == snapshot.draft?.attemptId
                    && request.startedAt == fixture.time && request.answers[0].selected == ["first"]
                    && request.answers[0].latencyMs == 0,
                "Explicit submission changed the restored attempt or answer")
            await again.disconnect()
            try expect(
                try NativeActivityStore(file: fixture.activityFile).read() == nil,
                "Logout retained the draft/navigation")
            let signedOut = fixture.model(authenticated: false)
            await signedOut.restore()
            try expect(signedOut.profile == nil && signedOut.lesson == nil, "Logout auto-reopened")

            let pathOnly = fixture.model(authenticated: false)
            pathOnly.baseURL = "https://example.invalid/api"
            pathOnly.token = "synthetic-A"
            await pathOnly.connect()
            await pathOnly.loadPath(track)
            pathOnly.selectedTab = .social
            let pathReopened = fixture.model(authenticated: false)
            await pathReopened.restore()
            try expect(
                pathReopened.path?.trackId == track.id && pathReopened.lesson == nil
                    && pathReopened.selectedTab == .social,
                "Path-only navigation was not restored")
        }
        @MainActor static func partialDraftRestoration(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            try await fixture.server.addQuestion()
            let model = try await prepareDraft(fixture)
            let partial = fixture.model(authenticated: false)
            await partial.restore()
            try expect(
                partial.lesson?.questions.count == 2 && partial.selections == model.selections
                    && partial.selections.count == 1 && !partial.canSubmit,
                "Partial draft was discarded or became submittable")
            guard let node = partial.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("Missing draft lesson")
            }
            await partial.loadLesson(node)
            let empty = fixture.model(authenticated: false)
            await empty.restore()
            try expect(
                empty.lesson?.id == node.id && empty.selections.isEmpty && !empty.canSubmit,
                "Reading an unanswered lesson did not survive cold restore")
            await empty.disconnect()
            let authenticated = fixture.model()
            await authenticated.connect()
            guard let track = authenticated.tracks.first else {
                throw ModelTestFailure.assertion("Missing authenticated track")
            }
            await authenticated.loadPath(track)
            await authenticated.loadLesson(node)
            guard let question = authenticated.lesson?.questions.first,
                let option = question.options.first
            else { throw ModelTestFailure.assertion("Missing authenticated question") }
            authenticated.select(option, question: question)
            fixture.time = Date(timeIntervalSince1970: 1_990)
            await fixture.server.setOwner("server-owner-B")
            fixture.provider.token = CIAMAccessToken(
                value: "synthetic-B", expiresAt: Date(timeIntervalSince1970: 3_000))
            await authenticated.refreshAuthenticationIfNeeded()
            try expect(
                authenticated.profile?.id == "server-owner-B" && authenticated.lesson == nil
                    && authenticated.selections.isEmpty
                    && !FileManager.default.fileExists(atPath: fixture.activityFile.path),
                "Silent account switch retained another owner's draft")
        }
        @MainActor static func invalidActivityRestoration(_ resources: URL) async throws {
            for invalidation in [
                "owner", "scope", "manifest", "content", "locked", "removed", "deleted",
                "malformed", "oversize", "future", "selection",
            ] {
                let fixture = try ModelFixture(resources: resources)
                defer { fixture.cleanup() }
                _ = try await prepareDraft(fixture)
                switch invalidation {
                case "owner": await fixture.server.setOwner("server-owner-B")
                case "scope":
                    fixture.vault.saved = DeveloperConnection(
                        baseURL: "https://other.invalid/api", accessToken: "synthetic-B")
                case "manifest":
                    await fixture.server.setManifest("sha256:" + String(repeating: "b", count: 64))
                case "content": try await fixture.server.changeLesson()
                case "locked": await fixture.server.setNodeStatus("locked")
                case "removed": try await fixture.server.removeTracks()
                case "deleted": await fixture.server.failLesson(404)
                case "malformed":
                    try Data("invalid".utf8).write(to: fixture.activityFile)
                case "oversize":
                    try Data(repeating: 0, count: 65_537).write(to: fixture.activityFile)
                default:
                    guard let bytes = try NativeActivityStore(file: fixture.activityFile).read(),
                        var object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
                    else { throw ModelTestFailure.assertion("Missing snapshot object") }
                    if invalidation == "future" {
                        object["schema"] = 99
                    } else {
                        guard var draft = object["draft"] as? [String: Any] else {
                            throw ModelTestFailure.assertion("Missing draft object")
                        }
                        draft["selections"] = ["fixture-question": "foreign-option"]
                        object["draft"] = draft
                    }
                    try JSONSerialization.data(withJSONObject: object).write(
                        to: fixture.activityFile)
                }
                let reopened = fixture.model(authenticated: false)
                await reopened.restore()
                let posts = await fixture.server.payloads()
                try expect(
                    reopened.profile != nil && reopened.lesson == nil
                        && reopened.selections.isEmpty && !reopened.canSubmit && posts.isEmpty
                        && reopened.errorMessage?.contains("was cleared") == true
                        && !FileManager.default.fileExists(atPath: fixture.activityFile.path),
                    "Incompatible \(invalidation) activity was restored or not explicitly purged")
            }
        }
        @MainActor static func interruptedActivityRestoration(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            _ = try await prepareDraft(fixture)
            let original = try NativeActivityStore(file: fixture.activityFile).read()
            await fixture.server.failPath(503)
            let unavailable = fixture.model(authenticated: false)
            await unavailable.restore()
            unavailable.selectedTab = .coach
            try expect(
                unavailable.lesson == nil && unavailable.errorMessage?.contains("was kept") == true
                    && (try NativeActivityStore(file: fixture.activityFile).read()) == original,
                "Transient restore failure overwrote the draft")
            await fixture.server.failPath(200)
            guard let track = unavailable.tracks.first else {
                throw ModelTestFailure.assertion("Missing track after transient failure")
            }
            await unavailable.loadPath(track)
            try expect(
                try NativeActivityStore(file: fixture.activityFile).read() == original,
                "Browsing after failed restoration overwrote the retained draft")
            let reopened = fixture.model(authenticated: false)
            await reopened.restore()
            try expect(
                reopened.canSubmit && reopened.errorMessage == nil, "Restore retry lost draft")
            await fixture.server.suspendLesson()
            let late = fixture.model(authenticated: false)
            let pending = Task { await late.restore() }
            try await wait { await fixture.server.isWaiting() }
            await late.disconnect()
            await fixture.server.resume()
            await pending.value
            try expect(
                late.profile == nil && late.lesson == nil && late.selections.isEmpty
                    && !FileManager.default.fileExists(atPath: fixture.activityFile.path),
                "Late restoration resurrected signed-out activity")
        }
        @MainActor static func submittedActivityRestoration(_ resources: URL) async throws {
            for status in ["pending", "corrected", "failed"] {
                let fixture = try ModelFixture(resources: resources)
                defer { fixture.cleanup() }
                let model = try await prepareDraft(fixture)
                await fixture.server.setOffline(status == "pending")
                if status == "failed" { await fixture.server.failSubmission(400) }
                await model.submit()
                let original = await fixture.server.payloads()
                let reopened = fixture.model(authenticated: false)
                await reopened.restore()
                await reopened.submit()
                let after = await fixture.server.payloads()
                try expect(
                    !reopened.canSubmit && reopened.outcome == model.outcome
                        && reopened.selections == model.selections && after == original
                        && (status == "failed" || reopened.errorMessage == nil),
                    "Submitted restoration fabricated a verdict, draft, or duplicate POST")
            }
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            _ = try await prepareDraft(fixture)
            guard let bytes = try NativeActivityStore(file: fixture.activityFile).read() else {
                throw ModelTestFailure.assertion("Missing in-flight fixture")
            }
            let snapshot = try NativeActivitySnapshot.decode(bytes)
            guard let draft = snapshot.draft, let session = snapshot.navigation.session else {
                throw ModelTestFailure.assertion("Missing in-flight draft/session")
            }
            let request = QuizSubmission(
                clientAttemptId: draft.attemptId,
                trackId: session.trackId, startedAt: fixture.time,
                answers: [
                    QuizAnswer(
                        itemId: "fixture-question", itemType: "mcq",
                        selected: ["first"], latencyMs: 0)
                ], publicManifestId: session.publicManifestId)
            let fenced = NativeActivitySnapshot(
                schema: 1, navigation: try snapshot.navigation.beginningSubmission(request),
                trackId: snapshot.trackId, draft: nil)
            try NativeActivityStore(file: fixture.activityFile).save(fenced.encoded())
            let ambiguous = fixture.model(authenticated: false)
            await ambiguous.restore()
            let posts = await fixture.server.payloads()
            try expect(
                ambiguous.lesson == nil && !ambiguous.canSubmit && posts.isEmpty
                    && ambiguous.errorMessage != nil,
                "In-flight marker without outbox was treated as an unsent draft or ACK")
        }
        @MainActor static func activityStorageFailure(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = try await prepareDraft(fixture)
            let original = try NativeActivityStore(file: fixture.activityFile).read()
            fixture.rejectActivityAccess = true
            guard let question = model.lesson?.questions.first, let option = question.options.last
            else {
                throw ModelTestFailure.assertion("Missing alternate selection")
            }
            model.select(option, question: question)
            try expect(
                model.errorMessage?.contains("could not be saved") == true,
                "Draft write failure was silent")
            await model.submit()
            let posts = await fixture.server.payloads()
            try expect(posts.isEmpty, "Submission bypassed a failed durable in-flight fence")
            let unreadable = fixture.model(authenticated: false)
            await unreadable.restore()
            try expect(
                unreadable.lesson == nil && unreadable.errorMessage?.contains("was kept") == true,
                "Storage read failure became an empty successful restoration")
            await model.disconnect()
            try expect(
                model.profile == nil
                    && model.errorMessage?.contains("removal is not confirmed") == true
                    && (try NativeActivityStore(file: fixture.activityFile).read()) == original,
                "Unconfirmed draft removal was reported as successful")
            model.token = "synthetic-A"
            await model.connect()
            try expect(
                model.profile == nil && model.lesson == nil && model.errorMessage != nil,
                "Explicit reconnect bypassed unconfirmed signed-out activity removal")
            fixture.rejectActivityAccess = false
            await model.disconnect()
            try expect(
                try NativeActivityStore(file: fixture.activityFile).read() == nil,
                "Explicit sign-out retry did not remove the draft")
        }
        @MainActor static func sameOwnerRefreshKeepsDraft(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing same-owner track")
            }
            await model.loadPath(track)
            guard let node = model.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("Missing same-owner node")
            }
            await model.loadLesson(node)
            guard let question = model.lesson?.questions.first, let option = question.options.last
            else {
                throw ModelTestFailure.assertion("Missing same-owner option")
            }
            fixture.rejectActivityAccess = true
            model.select(option, question: question)
            let pathRequests = await fixture.server.pathRequestCount()
            fixture.time = Date(timeIntervalSince1970: 1_990)
            fixture.provider.token = CIAMAccessToken(
                value: "synthetic-renewed", expiresAt: Date(timeIntervalSince1970: 3_000))
            await model.refreshAuthenticationIfNeeded()
            let refreshedPathRequests = await fixture.server.pathRequestCount()
            try expect(
                model.selections[question.id] == option.id && model.canSubmit
                    && model.lesson?.id == node.id
                    && model.errorMessage?.contains("could not be saved") == true
                    && refreshedPathRequests == pathRequests,
                "Same-owner renewal reloaded or overwrote the in-memory unsaved draft")
        }
        @MainActor static func pilotHistorySessionIsolation(_ resources: URL) async throws {
            let root = (0..<5).reduce(URL(fileURLWithPath: #filePath)) { url, _ in
                url.deletingLastPathComponent()
            }
            let content = try Data(
                contentsOf: root.appendingPathComponent(
                    "backend/src/Certigo.Infrastructure/Learning/Fixtures/responsible-ai-assistants.json"
                ))
            for markRead in [false, true] {
                for reconnect in [false, true] {
                    let fixture = try ModelFixture(resources: resources)
                    defer { fixture.cleanup() }
                    await fixture.server.enablePilot(content)
                    let model = fixture.model(authenticated: false)
                    model.baseURL = "https://example.invalid/api"
                    model.token = "synthetic-A"
                    await model.connect()
                    try await model.loadEditorialPilot()
                    let original = model.pilotHistory?.lastLessonId
                    try expect(original == "verify-claims", "Initial pilot history missing")
                    if markRead {
                        try await model.markEditorialPilotLessonRead("verify-claims")
                    } else {
                        try await model.accessEditorialPilotLesson("verify-claims")
                    }
                    try expect(
                        model.pilotHistory?.lastLessonId == original && !model.busy,
                        "Current-session activity did not refresh history")
                    await fixture.server.failPilotHistory(503)
                    do {
                        try await model.accessEditorialPilotLesson("verify-claims")
                        throw ModelTestFailure.assertion("History failure became success")
                    } catch APIError.http(503) {}
                    try expect(
                        model.pilotHistory?.lastLessonId == original && !model.busy,
                        "Failed history refresh changed existing state or stayed busy")
                    await fixture.server.failPilotHistory(200)
                    await fixture.server.suspendPilotHistory()
                    let pending = Task {
                        do {
                            if markRead {
                                try await model.markEditorialPilotLessonRead("verify-claims")
                            } else {
                                try await model.accessEditorialPilotLesson("verify-claims")
                            }
                            return false
                        } catch NativePilotError.ownerChanged {
                            return true
                        } catch APIError.staleSession {
                            return true
                        }
                    }
                    try await wait { await fixture.server.isWaiting() }
                    await model.disconnect()
                    if reconnect {
                        await fixture.server.setOwner("server-owner-B")
                        await fixture.server.setPilotLesson("retrieval-not-training")
                        model.token = "synthetic-B"
                        await model.connect()
                        try await model.loadEditorialPilot()
                    }
                    let expected = model.pilotHistory?.lastLessonId
                    try expect(
                        expected == (reconnect ? "retrieval-not-training" : nil),
                        "Replacement session history not established")
                    await fixture.server.resume()
                    let rejected = try await pending.value
                    try expect(rejected, "Late old-session history did not report owner change")
                    try expect(
                        model.pilotHistory?.lastLessonId == expected && !model.busy,
                        "Late old-session history overwrote disconnected or replacement state")
                }
            }
        }
        @MainActor static func explicitGoalSelection(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            try await fixture.server.addSecondGoal()
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-A"
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing goal")
            }
            await model.loadPath(track)
            try expect(model.profile?.activeTrackId == nil, "Browsing chose an active goal")
            let noWrites = await fixture.server.goalPayloads()
            try expect(noWrites.isEmpty, "Browsing posted an active goal")
            guard let node = model.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("Missing lesson")
            }
            await model.loadLesson(node)
            guard let question = model.lesson?.questions.first, let option = question.options.first
            else {
                throw ModelTestFailure.assertion("Missing exercise")
            }
            model.select(option, question: question)
            await fixture.server.setOffline(true)
            await model.submit()
            await fixture.server.setOffline(false)
            let saved = model.queue
            await model.chooseActiveTrack(track)
            try expect(
                model.profile?.activeTrackId == track.id && model.profile?.xp == 321,
                "Goal confirmation did not use authoritative profile")
            try expect(
                model.queue == saved && !saved.isEmpty && model.lesson?.id == node.id
                    && model.outcome == .pendingCorrection && !model.canSubmit,
                "Choosing a goal changed the existing pending activity")
            await model.chooseActiveTrack(track)
            let posts = await fixture.server.goalPayloads()
            let first = try JSONSerialization.jsonObject(with: posts[0]) as? [String: Any]
            let second = try JSONSerialization.jsonObject(with: posts[1]) as? [String: Any]
            try expect(
                first?["expectedTrackId"] is NSNull
                    && second?["expectedTrackId"] as? String == track.id,
                "Goal expected value was not the confirmed profile")
            try expect(model.errorMessage == nil, "Same-goal idempotency failed")
            await fixture.server.setGoal("another-goal")
            await model.chooseActiveTrack(track)
            try expect(
                model.profile?.activeTrackId == "another-goal"
                    && model.errorMessage?.contains("changed elsewhere") == true,
                "Conflict overwrote concurrent goal or failed to reconcile profile")
            let afterConflict = await fixture.server.goalPayloads()
            try expect(afterConflict.count == 3, "Conflict automatically reposted a selection")
            await model.loadPath(track)
            try expect(
                model.profile?.activeTrackId == "another-goal",
                "Browsing the old goal replaced the active goal")
            await fixture.server.setOffline(true)
            await model.chooseActiveTrack(track)
            try expect(
                model.profile?.activeTrackId == "another-goal" && model.errorMessage != nil,
                "Lost response optimistically confirmed goal")
            guard let secondGoal = model.tracks.last, secondGoal.id != track.id else {
                throw ModelTestFailure.assertion("Missing second goal")
            }
            await model.chooseActiveTrack(secondGoal)
            let stillPending = await fixture.server.goalPayloads()
            try expect(
                stillPending.count == 4
                    && model.errorMessage?.contains("previous goal selection is not confirmed")
                        == true,
                "Different goal overwrote the uncertain original decision")
            await fixture.server.setOffline(false)
            await model.chooseActiveTrack(track)
            let retried = await fixture.server.goalPayloads()
            try expect(retried[3] == retried[4], "Uncertain goal retry changed expected body")
            try expect(
                model.profile?.activeTrackId == track.id, "Already-applied goal did not reconcile")
            await fixture.server.failGoal(404)
            await model.chooseActiveTrack(track)
            try expect(
                model.profile?.activeTrackId == track.id
                    && model.errorMessage?.contains("HTTP 404") == true,
                "Missing goal was not an explicit English error")
            await fixture.server.failGoal(200)
            await fixture.server.respondAsOwner("foreign-owner")
            await model.chooseActiveTrack(track)
            try expect(
                model.profile?.id == "server-owner-A" && model.errorMessage != nil,
                "Foreign goal response replaced the profile")
            await fixture.server.respondAsOwner(nil)
            await fixture.server.setGoal("third-goal")
            await fixture.server.failProfile(503)
            await model.chooseActiveTrack(track)
            try expect(
                model.profile?.activeTrackId == track.id
                    && model.errorMessage?.contains("could not be reloaded") == true,
                "Failed conflict reload claimed an authoritative goal")
            await fixture.server.failProfile(200)
            await model.chooseActiveTrack(track)
            try expect(
                model.profile?.activeTrackId == "third-goal"
                    && model.errorMessage?.contains("changed elsewhere") == true,
                "Conflict reload recovery forced a new goal")
        }
        @MainActor static func lateGoalResponse(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-A"
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing goal")
            }
            await fixture.server.suspendGoal()
            let task = Task { await model.chooseActiveTrack(track) }
            try await wait { await fixture.server.isWaiting() }
            try expect(
                model.profile?.activeTrackId == nil && model.busy, "Pending goal appeared confirmed"
            )
            await model.chooseActiveTrack(track)
            let pendingPosts = await fixture.server.goalPayloads()
            try expect(pendingPosts.count == 1, "Concurrent goal action posted twice")
            await model.disconnect()
            await fixture.server.setOwner("server-owner-B")
            await fixture.server.setGoal(nil)
            model.token = "synthetic-B"
            await model.connect()
            await fixture.server.resume()
            await task.value
            try expect(
                model.profile?.id == "server-owner-B" && model.profile?.activeTrackId == nil
                    && model.errorMessage == nil && !model.busy,
                "Late old-owner goal response altered current account")
            await model.chooseActiveTrack(track)
            let posts = await fixture.server.goalPayloads()
            let body = try JSONSerialization.jsonObject(with: posts[1]) as? [String: Any]
            try expect(
                body?["expectedTrackId"] is NSNull, "Old owner's pending decision survived logout")
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
            for tab in [NativeResumeState.Tab.learn, .coach, .social, .profile] {
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
                tab: .learn, ownerId: owner, apiScope: scope, session: session)
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
            try expectResumeError(.malformed) {
                _ = try NativeResumeState.decode(JSONSerialization.data(withJSONObject: object))
            }
            object["schema"] = 2
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
                    tab: .learn, ownerId: owner, apiScope: scope, session: traversal)
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
        @MainActor static func stalePathSelectionAfterOwnerRefresh(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model()
            await model.connect()
            guard let previousOwnerTrack = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing previous-owner track")
            }
            fixture.time = Date(timeIntervalSince1970: 1_990)
            fixture.provider.token = CIAMAccessToken(
                value: "synthetic-owner-B", expiresAt: Date(timeIntervalSince1970: 3_000))
            await fixture.server.setOwner("server-owner-B")

            await model.loadPath(previousOwnerTrack)

            try expect(model.profile?.id == "server-owner-B", "Silent refresh did not switch owner")
            try expect(
                await fixture.server.pathRequestCount() == 0 && model.path == nil,
                "Stale track selection loaded a path after the account changed")
            try expect(model.errorMessage != nil, "Stale track selection was silently dropped")
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
            let invalidOption = try JSONDecoder().decode(
                QuizOption.self,
                from: Data(#"{"id":"foreign","label":"Not in this exercise"}"#.utf8))
            model.select(invalidOption, question: question)
            try expect(
                model.selections.isEmpty && model.errorMessage != nil,
                "Foreign option entered current activity")
            model.selections[question.id] = "foreign"
            try expect(!model.canSubmit, "Invalid directly bound option enabled submission")
            model.selections = [:]
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
            await reopened.loadPath(track)
            await reopened.loadLesson(node)
            try expect(
                reopened.outcome == .pendingCorrection && !reopened.canSubmit,
                "Reopening a pending lesson discarded its attempt")
            try expect(
                reopened.selections[question.id] == option.id,
                "Reopening did not restore the queued answer identity")
            await reopened.submit()
            let beforeRetry = await fixture.server.payloads()
            try expect(beforeRetry.count == 1, "Reopened pending lesson submitted a new attempt")
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
        @MainActor static func pendingReleaseAndAccountRecovery(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-A"
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing synthetic track")
            }
            await model.loadPath(track)
            guard let node = model.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("Missing synthetic node")
            }
            await model.loadLesson(node)
            guard let question = model.lesson?.questions.first,
                let option = question.options.first
            else { throw ModelTestFailure.assertion("Missing synthetic question") }
            model.select(option, question: question)
            await fixture.server.setOffline(true)
            await model.submit()
            guard let saved = model.queue.first else {
                throw ModelTestFailure.assertion("Missing pending attempt")
            }
            await fixture.server.setManifest("sha256:" + String(repeating: "b", count: 64))
            await model.loadLesson(node)
            try expect(
                model.lesson == nil && !model.canSubmit && model.errorMessage != nil,
                "Changed release reopened a pending attempt as a fresh exercise")
            try expect(model.queue.first == saved, "Changed release rewrote original pending pin")
            await fixture.server.setOffline(false)
            await model.retry(saved)
            let payloads = await fixture.server.payloads()
            try expect(payloads.count == 2 && payloads[0] == payloads[1], "Old pin retry changed")
            await model.loadLesson(node)
            guard let loadedQuestion = model.lesson?.questions.first,
                let loadedOption = loadedQuestion.options.first
            else { throw ModelTestFailure.assertion("New practice after correction unavailable") }
            model.select(loadedOption, question: loadedQuestion)
            await fixture.server.setOwner("server-owner-B")
            model.token = "synthetic-B"
            await model.connect()
            try expect(
                model.profile?.id == "server-owner-B" && model.lesson == nil
                    && model.path == nil && model.selections.isEmpty && model.queue.isEmpty
                    && model.outcome == nil && !model.canSubmit,
                "Manual reconnect exposed old-owner activity")
        }
        @MainActor static func failedAndAmbiguousRecovery(_ resources: URL) async throws {
            let fixture = try ModelFixture(resources: resources)
            defer { fixture.cleanup() }
            let store = SubmissionStore(file: fixture.root.appendingPathComponent("outbox.json"))
            func request(_ id: String) -> QuizSubmission {
                QuizSubmission(
                    clientAttemptId: id, trackId: "fixture:foundations",
                    startedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    answers: [
                        QuizAnswer(
                            itemId: "fixture-question", itemType: "mcq", selected: ["first"],
                            latencyMs: 10)
                    ], publicManifestId: fixture.server.manifestId)
            }
            let entry = SavedSubmission(
                ownerId: "server-owner-A", apiScope: "https://example.invalid/api",
                lessonId: "fixture-lesson",
                submission: request("3d78ef1a-9ea5-442d-baf6-5c2247b1ad59"))
            _ = try await store.enqueue(entry)
            try await store.recordFailure("synthetic-rejection", entry: entry)
            let model = fixture.model(authenticated: false)
            model.baseURL = "https://example.invalid/api"
            model.token = "synthetic-A"
            await model.connect()
            guard let track = model.tracks.first else {
                throw ModelTestFailure.assertion("Missing track")
            }
            await model.loadPath(track)
            guard let node = model.path?.units.first?.lessons.first else {
                throw ModelTestFailure.assertion("Missing node")
            }
            await model.loadLesson(node)
            try expect(
                model.lesson != nil && model.outcome == nil && !model.canSubmit
                    && model.errorMessage != nil && model.queue.first?.status == .failed,
                "Rejected attempt was converted to a new editable attempt")
            await model.submit()
            let noPosts = await fixture.server.payloads()
            try expect(noPosts.isEmpty, "Rejected attempt bypassed explicit failure")
            _ = try await store.enqueue(
                SavedSubmission(
                    ownerId: entry.ownerId, apiScope: entry.apiScope, lessonId: entry.lessonId,
                    submission: request("eb1f0a2b-dc55-49ee-9d1b-a954c40fe8e6")))
            // Reopen the model/store to read the newly persisted independent attempt.
            let reopened = fixture.model(authenticated: false)
            await reopened.restore()
            await reopened.loadPath(track)
            await reopened.loadLesson(node)
            try expect(
                reopened.lesson == nil && reopened.errorMessage != nil
                    && reopened.queue.count == 2 && !reopened.canSubmit,
                "Ambiguous pending attempts silently selected one")
        }
    }
#endif
