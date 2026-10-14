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
        private var owner = "server-owner-A"
        private var pause = false
        private var waiter: CheckedContinuation<Void, Never>?
        private var requests = 0
        init(catalog: Data) { self.catalog = catalog }
        func setOwner(_ value: String) { owner = value }
        func pauseProfile() { pause = true }
        func isWaiting() -> Bool { waiter != nil }
        func count() -> Int { requests }
        func resume() {
            waiter?.resume()
            waiter = nil
            pause = false
        }
        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests += 1
            guard let url = request.url else { throw APIError.configuration }
            let bytes: Data
            if url.path.hasSuffix("/me") {
                let capturedOwner = owner
                if pause { await withCheckedContinuation { waiter = $0 } }
                bytes = Data(
                    """
                    {"id":"\(capturedOwner)","displayName":"Synthetic","xp":0,"activeTrackId":null}
                    """.utf8)
            } else if url.path.hasSuffix("/catalog/tracks") {
                bytes = catalog
            } else {
                throw APIError.invalidResponse
            }
            guard
                let response = HTTPURLResponse(
                    url: url, statusCode: 200, httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"])
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
            server = ModelTransport(
                catalog: try Data(contentsOf: resources.appendingPathComponent("catalog.json")))
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
            print("NativeModel: 8 synthetic coordination scenarios passed (Linux source harness).")
        }
        static func expect(_ condition: Bool, _ message: String) throws {
            if !condition { throw ModelTestFailure.assertion(message) }
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
    }
#endif
