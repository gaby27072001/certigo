import CertigoData
import Foundation
import XCTest

final class CIAMConfigurationTests: XCTestCase {
    private let tenant = "11111111-1111-4111-8111-111111111111"
    private let audience = "22222222-2222-4222-8222-222222222222"
    private let callback = "msauth.example.native.dev://auth"
    private let bundleIdentifier = "example.native.dev"

    func testDevelopmentCandidateUsesTheSelectedDevelopmentAPIWithRoutePrefix() throws {
        let value = try CIAMDevelopmentCandidate.validatedMetadata(
            registeredRedirects: [CIAMDevelopmentCandidate.redirect],
            declaredSchemes: ["msauth.\(CIAMDevelopmentCandidate.bundleIdentifier)"],
            otherAppSchemes: [])
        XCTAssertEqual(
            value.apiBaseURL.absoluteString,
            "https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api")
        XCTAssertEqual(value.tenantID, CIAMDevelopmentCandidate.tenantID)
        XCTAssertEqual(value.redirectURI.absoluteString, CIAMDevelopmentCandidate.redirect)
    }

    func testSuppliedStandardPublicConfigurationDoesNotNormalizeTheIssuerIntoTheSDKAuthority()
        throws
    {
        let value = try config()
        XCTAssertEqual(value.authority.absoluteString, "https://synthetic.ciamlogin.com")
        XCTAssertEqual(value.issuer.path, "/\(tenant)/v2.0")
        XCTAssertEqual(value.apiScope, "api://\(audience)/user_impersonation")
        XCTAssertEqual(value.redirectURI.absoluteString, callback)
    }

    func testIssuerAndAuthorityAreDistinctAndTenantBound() {
        rejects(.invalidAuthority, authority: "https://synthetic.ciamlogin.com/\(tenant)/v2.0")
        rejects(.issuerMismatch, issuer: "https://different.ciamlogin.com/\(tenant)/v2.0")
        rejects(.issuerMismatch, issuer: "https://synthetic.ciamlogin.com/\(audience)/v2.0")
        rejects(.invalidAuthority, authority: "https://synthetic.ciamlogin.com.evil.invalid")
    }

    func testStandardAuthorityAcceptsOnlyItsExplicitTenantPathOrAnOrigin() throws {
        let host = "https://\(tenant).ciamlogin.com"
        let issuer = "\(host)/\(tenant)/v2.0"
        for authority in [host, "\(host)/", "\(host)/\(tenant)"] {
            let value = try config(authority: authority, issuer: issuer)
            XCTAssertEqual(value.authority.absoluteString, authority)
            XCTAssertEqual(value.issuer.absoluteString, issuer)
        }
        for path in ["/\(audience)", "/common", "/\(tenant)/v2.0", "/\(tenant)/extra"] {
            rejects(.invalidAuthority, authority: "\(host)\(path)", issuer: issuer)
        }
    }

    func testCustomDomainRequiresAnExplicitKindAndTheMatchingSuppliedIssuer() throws {
        let host = "https://login.example.invalid"
        let authority = "\(host)/\(tenant)"
        let issuer = "\(authority)/v2.0"
        rejects(.invalidAuthority, authority: authority, issuer: issuer)
        XCTAssertNoThrow(
            try config(authority: authority, issuer: issuer, kind: .customDomain))
        XCTAssertThrowsError(
            try config(authority: host, issuer: issuer, kind: .customDomain))
    }

    func testUnsafeAuthorityAndAPIURLsFailWithoutEchoingInput() {
        rejects(.invalidAuthority, authority: "http://synthetic.ciamlogin.com")
        rejects(.invalidAuthority, authority: "https://synthetic.ciamlogin.com?token=not-a-token")
        rejects(.invalidAuthority, authority: "https://synthetic.ciamlogin.com:444")
        XCTAssertThrowsError(try config(api: "http://api.example.invalid/api")) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .invalidAPIURL)
        }
    }

    func testProtectedScopeCannotTargetAnotherAudienceOrBundleSeveralPermissions() {
        for scope in [
            "api://\(tenant)/user_impersonation", "openid",
            "api://\(audience)/user_impersonation offline_access",
            "api://\(audience)/", "api://\(audience)/user_impersonation/extra",
        ] {
            XCTAssertThrowsError(try config(scope: scope)) {
                XCTAssertEqual($0 as? CIAMConfigurationError, .invalidAPIScope)
            }
        }
    }

    func testUnregisteredNativeCallbackCannotBeAuthorizedByTheFlutterRegistration() {
        XCTAssertThrowsError(try config(registered: ["certigo://auth", "certigo://auth/"])) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .redirectNotRegistered)
        }
    }

    func testDeclaredSchemeAndCollisionChecksAreIndependentOfRegistration() {
        XCTAssertThrowsError(try config(declared: [])) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .callbackNotDeclared)
        }
        XCTAssertThrowsError(try config(collisions: ["msauth.example.native.dev"])) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .callbackCollision)
        }
    }

    func testSchemeCollisionComparisonIsCaseInsensitiveWithoutRewritingRegisteredURI() {
        XCTAssertThrowsError(
            try config(collisions: ["MSAUTH.EXAMPLE.NATIVE.DEV"])
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .callbackCollision)
        }
    }

    func testMalformedPublicIdentifiersDoNotBecomeAValidConfiguration() {
        for input in [
            ("not-an-id", tenant, audience),
            ("33333333-3333-4333-8333-333333333333", "common", audience),
            ("33333333-3333-4333-8333-333333333333", tenant, "api://example"),
        ] {
            XCTAssertThrowsError(
                try config(clientID: input.0, tenantID: input.1, apiAudience: input.2)
            ) {
                XCTAssertEqual($0 as? CIAMConfigurationError, .invalidIdentity)
            }
        }
    }

    func testCustomRegisteredCallbackPreservesItsSlashButCannotCollideWithFlutter() throws {
        let custom = "certigo://auth/"
        let value = try config(
            redirect: custom, registered: [custom], declared: ["certigo"])
        XCTAssertEqual(value.redirectURI.absoluteString, custom)
        XCTAssertThrowsError(
            try config(
                redirect: custom, registered: [custom], declared: ["certigo"],
                collisions: ["certigo"])
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .callbackCollision)
        }
        XCTAssertThrowsError(
            try config(redirect: "certigo://auth", registered: [custom], declared: ["certigo"])
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .redirectNotRegistered)
        }
    }

    func testUnsupportedRedirectFormsAreNotSilentlyRewritten() {
        for redirect in [
            "https://example.invalid/auth", "certigo://auth/extra", "certigo://auth?state=example",
            "certigo://auth#fragment", "certigo://auth:42", "certigo:",
        ] {
            XCTAssertThrowsError(try config(redirect: redirect, registered: [redirect])) {
                XCTAssertEqual($0 as? CIAMConfigurationError, .invalidRedirect)
            }
        }
    }

    func testTokenDescriptionsAreRedactedAndHaveNoBackendOwnerProjection() {
        let value = CIAMAccessToken(
            value: "synthetic-not-a-token", expiresAt: Date(timeIntervalSince1970: 10))
        XCTAssertEqual(value.description, "CIAMAccessToken(redacted)")
        XCTAssertEqual(value.debugDescription, value.description)
    }

    func testMissingOrDisabledOptInLeavesTheManualConnectorSelectionUnchanged() async throws {
        let bundleIdentifier = self.bundleIdentifier
        try await MainActor.run {
            var providerCalls = 0
            let absent = try CIAMConfigurationEnvironment.configuredProvider(
                environment: [:], bundleIdentifier: bundleIdentifier, infoDictionary: [:],
                isDevelopmentBuild: true
            ) { _ in
                providerCalls += 1
                return "unexpected"
            }
            let disabled = try CIAMConfigurationEnvironment.configuredProvider(
                environment: ["CERTIGO_CIAM_ENABLED": "false"],
                bundleIdentifier: bundleIdentifier,
                infoDictionary: [:],
                isDevelopmentBuild: true
            ) { _ in
                providerCalls += 1
                return "unexpected"
            }

            XCTAssertNil(absent)
            XCTAssertNil(disabled)
            XCTAssertEqual(providerCalls, 0)
        }
    }

    func testInvalidOptInFailsInsteadOfSelectingTheManualConnector() {
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.configuration(
                environment: ["CERTIGO_CIAM_ENABLED": "yes"],
                bundleIdentifier: bundleIdentifier,
                infoDictionary: infoDictionary,
                isDevelopmentBuild: true
            )
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationEnvironmentError, .invalidOptIn)
        }
    }

    func testEnabledOptInRequiresEveryLocalValue() {
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.configuration(
                environment: ["CERTIGO_CIAM_ENABLED": "true"],
                bundleIdentifier: bundleIdentifier,
                infoDictionary: infoDictionary,
                isDevelopmentBuild: true
            )
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError,
                .missingValue("CERTIGO_CIAM_CLIENT_ID")
            )
        }
    }

    func testReleaseBuildCannotEnableTheDevelopmentProvider() {
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.configuration(
                environment: ["CERTIGO_CIAM_ENABLED": "true"],
                bundleIdentifier: bundleIdentifier,
                infoDictionary: infoDictionary,
                isDevelopmentBuild: false
            )
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError, .releaseOptInNotAllowed)
        }
    }

    func testEnabledOptInBuildsOnlyTheLocallySuppliedValidatedConfiguration() async throws {
        let localEnvironment = self.localEnvironment
        let bundleIdentifier = self.bundleIdentifier
        let tenant = self.tenant
        try await MainActor.run {
            let infoDictionary: [String: Any] = [
                "CFBundleURLTypes": [
                    ["CFBundleURLSchemes": ["msauth.\(bundleIdentifier)"]]
                ]
            ]
            let selected = try CIAMConfigurationEnvironment.configuredProvider(
                environment: localEnvironment,
                bundleIdentifier: bundleIdentifier,
                infoDictionary: infoDictionary,
                isDevelopmentBuild: true
            ) { configuration in
                configuration.apiBaseURL.absoluteString
            }

            XCTAssertEqual(selected?.configuration.clientID, "33333333-3333-4333-8333-333333333333")
            XCTAssertEqual(selected?.configuration.tenantID, tenant)
            XCTAssertEqual(
                selected?.configuration.apiBaseURL.absoluteString, "https://api.example.invalid/api"
            )
            XCTAssertEqual(selected?.provider, "https://api.example.invalid/api")
        }
    }

    func testRedirectMustMatchThisBundleAndBeUniquelyDeclaredByItsInfoPlist() {
        var wrongBundle = localEnvironment
        wrongBundle["CERTIGO_CIAM_REDIRECT_URI"] = "msauth.other.native.dev://auth"
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.configuration(
                environment: wrongBundle,
                bundleIdentifier: bundleIdentifier,
                infoDictionary: infoDictionary,
                isDevelopmentBuild: true
            )
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError, .redirectDoesNotMatchBundle)
        }

        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.configuration(
                environment: localEnvironment,
                bundleIdentifier: bundleIdentifier,
                infoDictionary: [:],
                isDevelopmentBuild: true
            )
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationEnvironmentError, .callbackNotDeclared)
        }

        var duplicatedCallback = infoDictionary
        duplicatedCallback["CFBundleURLTypes"] = [
            ["CFBundleURLSchemes": ["msauth.\(bundleIdentifier)"]],
            ["CFBundleURLSchemes": ["MSAUTH.\(bundleIdentifier)"]],
        ]
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.configuration(
                environment: localEnvironment,
                bundleIdentifier: bundleIdentifier,
                infoDictionary: duplicatedCallback,
                isDevelopmentBuild: true
            )
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationEnvironmentError, .callbackCollision)
        }
    }

    func testConfigurationNeedsNoSelfAttestedIdentityProviderRegistrationValue() throws {
        let configured = try CIAMConfigurationEnvironment.configuration(
            environment: localEnvironment,
            bundleIdentifier: bundleIdentifier,
            infoDictionary: infoDictionary,
            isDevelopmentBuild: true
        )
        XCTAssertEqual(configured?.redirectURI.absoluteString, callback)
    }

    func testInvalidConfigurationDoesNotInvokeProviderFactory() async throws {
        let bundleIdentifier = self.bundleIdentifier
        try await MainActor.run {
            var providerCalls = 0
            XCTAssertThrowsError(
                try CIAMConfigurationEnvironment.configuredProvider(
                    environment: ["CERTIGO_CIAM_ENABLED": "true"],
                    bundleIdentifier: bundleIdentifier,
                    infoDictionary: [:],
                    isDevelopmentBuild: true
                ) { _ in
                    providerCalls += 1
                    return "unexpected"
                }
            )
            XCTAssertEqual(providerCalls, 0)
        }
    }

    func testProviderConstructionFailurePropagatesWithoutManualFallback() async throws {
        let localEnvironment = self.localEnvironment
        let bundleIdentifier = self.bundleIdentifier
        try await MainActor.run {
            enum ProviderFailure: Error { case initialization }
            var providerCalls = 0

            XCTAssertThrowsError(
                try CIAMConfigurationEnvironment.configuredProvider(
                    environment: localEnvironment,
                    bundleIdentifier: bundleIdentifier,
                    infoDictionary: [
                        "CFBundleURLTypes": [
                            ["CFBundleURLSchemes": ["msauth.\(bundleIdentifier)"]]
                        ]
                    ],
                    isDevelopmentBuild: true
                ) { _ -> String in
                    providerCalls += 1
                    throw ProviderFailure.initialization
                }
            ) {
                XCTAssertEqual($0 as? ProviderFailure, .initialization)
            }
            XCTAssertEqual(providerCalls, 1)
        }
    }

    func testProductionProviderRequiresDistributionConfigurationAndNeverUsesDevelopmentValues()
        async throws
    {
        let missingIdentity: [String: Any] = [
            "CertigoProductionAuthMode": "microsoft",
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["msauth.com.certigo.mobileapp"]]
            ],
        ]
        let productionInfo = Self.productionInfoDictionary(
            tenant: tenant, audience: audience)
        try await MainActor.run {
            var providerCalls = 0
            XCTAssertThrowsError(
                try CIAMConfigurationEnvironment.configuredProductionProvider(
                    infoDictionary: missingIdentity,
                    bundleIdentifier: "com.certigo.mobileapp",
                    isDevelopmentBuild: false
                ) { _ in
                    providerCalls += 1
                    return "unexpected"
                }
            ) {
                XCTAssertEqual(
                    $0 as? CIAMConfigurationEnvironmentError,
                    .missingValue("CertigoProductionCIAMCLIENT_ID"))
            }
            XCTAssertEqual(providerCalls, 0)
        }
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.productionConfiguration(
                infoDictionary: productionInfo,
                bundleIdentifier: "com.certigo.mobileapp",
                isDevelopmentBuild: true
            )
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError, .productionBuildRequired)
        }
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.productionConfiguration(
                infoDictionary: productionInfo,
                bundleIdentifier: "com.certigo.native.dev",
                isDevelopmentBuild: false
            )
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError, .unsupportedProductionBundle)
        }
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.productionConfiguration(
                infoDictionary: productionInfo,
                bundleIdentifier: nil,
                isDevelopmentBuild: false)
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError, .missingBundleIdentifier)
        }
    }

    func testProductionConfigurationUsesOnlySuppliedDistributionMetadata() throws {
        let productionInfo = Self.productionInfoDictionary(
            tenant: tenant, audience: audience)
        let value = try CIAMConfigurationEnvironment.productionConfiguration(
            infoDictionary: productionInfo,
            bundleIdentifier: "com.certigo.mobileapp",
            isDevelopmentBuild: false)
        XCTAssertEqual(value.clientID, "33333333-3333-4333-8333-333333333333")
        XCTAssertEqual(value.apiBaseURL.absoluteString, "https://api.example.invalid/api")
        XCTAssertEqual(value.apiScope, "api://\(audience)/user_impersonation")
        XCTAssertEqual(
            value.redirectURI.absoluteString, "msauth.com.certigo.mobileapp://auth")

        var missingCallback = productionInfo
        missingCallback["CFBundleURLTypes"] = []
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.productionConfiguration(
                infoDictionary: missingCallback,
                bundleIdentifier: "com.certigo.mobileapp",
                isDevelopmentBuild: false)
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError, .callbackNotDeclared)
        }
        var duplicateCallback = productionInfo
        duplicateCallback["CFBundleURLTypes"] = [
            ["CFBundleURLSchemes": ["msauth.com.certigo.mobileapp"]],
            ["CFBundleURLSchemes": ["MSAUTH.COM.CERTIGO.MOBILEAPP"]],
        ]
        XCTAssertThrowsError(
            try CIAMConfigurationEnvironment.productionConfiguration(
                infoDictionary: duplicateCallback,
                bundleIdentifier: "com.certigo.mobileapp",
                isDevelopmentBuild: false)
        ) {
            XCTAssertEqual(
                $0 as? CIAMConfigurationEnvironmentError, .callbackCollision)
        }
    }

    func testUnexpandedDistributionBuildSettingsFailBeforeProviderConstruction() async throws {
        let settings = [
            ("CertigoProductionCIAMCLIENT_ID", "CERTIGO_PRODUCTION_CIAM_CLIENT_ID"),
            ("CertigoProductionCIAMTENANT_ID", "CERTIGO_PRODUCTION_CIAM_TENANT_ID"),
            ("CertigoProductionCIAMAUTHORITY", "CERTIGO_PRODUCTION_CIAM_AUTHORITY"),
            ("CertigoProductionCIAMISSUER", "CERTIGO_PRODUCTION_CIAM_ISSUER"),
            ("CertigoProductionCIAMAUTHORITY_KIND", "CERTIGO_PRODUCTION_CIAM_AUTHORITY_KIND"),
            ("CertigoProductionCIAMAPI_BASE_URL", "CERTIGO_PRODUCTION_CIAM_API_BASE_URL"),
            ("CertigoProductionCIAMAPI_SCOPE", "CERTIGO_PRODUCTION_CIAM_API_SCOPE"),
            ("CertigoProductionCIAMAPI_AUDIENCE", "CERTIGO_PRODUCTION_CIAM_API_AUDIENCE"),
        ]
        let tenant = self.tenant
        let audience = self.audience
        try await MainActor.run {
            var providerCalls = 0
            let baseInfo = Self.productionInfoDictionary(tenant: tenant, audience: audience)
            for (key, buildSetting) in settings {
                var info = baseInfo
                info[key] = "$(\(buildSetting))"
                XCTAssertThrowsError(
                    try CIAMConfigurationEnvironment.configuredProductionProvider(
                        infoDictionary: info,
                        bundleIdentifier: "com.certigo.mobileapp",
                        isDevelopmentBuild: false
                    ) { _ in
                        providerCalls += 1
                        return "unexpected"
                    }
                ) {
                    XCTAssertEqual($0 as? CIAMConfigurationEnvironmentError, .missingValue(key))
                }
            }
            XCTAssertEqual(providerCalls, 0)
        }
    }

    func testProductionProviderFactoryReceivesValidatedConfiguration() async throws {
        let tenant = self.tenant
        let audience = self.audience
        try await MainActor.run {
            var providerCalls = 0
            let info = Self.productionInfoDictionary(tenant: tenant, audience: audience)
            let configured = try CIAMConfigurationEnvironment.configuredProductionProvider(
                infoDictionary: info,
                bundleIdentifier: "com.certigo.mobileapp",
                isDevelopmentBuild: false
            ) { configuration in
                providerCalls += 1
                return configuration.apiBaseURL.absoluteString
            }
            XCTAssertEqual(providerCalls, 1)
            XCTAssertEqual(configured.provider, "https://api.example.invalid/api")
            XCTAssertEqual(
                configured.configuration.redirectURI.absoluteString,
                "msauth.com.certigo.mobileapp://auth")
        }
    }

    private var localEnvironment: [String: String] {
        [
            "CERTIGO_CIAM_ENABLED": "true",
            "CERTIGO_CIAM_CLIENT_ID": "33333333-3333-4333-8333-333333333333",
            "CERTIGO_CIAM_TENANT_ID": tenant,
            "CERTIGO_CIAM_AUTHORITY": "https://synthetic.ciamlogin.com",
            "CERTIGO_CIAM_ISSUER": "https://synthetic.ciamlogin.com/\(tenant)/v2.0",
            "CERTIGO_CIAM_AUTHORITY_KIND": "standard",
            "CERTIGO_CIAM_API_BASE_URL": "https://api.example.invalid/api",
            "CERTIGO_CIAM_API_SCOPE": "api://\(audience)/user_impersonation",
            "CERTIGO_CIAM_API_AUDIENCE": audience,
            "CERTIGO_CIAM_REDIRECT_URI": callback,
        ]
    }

    private static func productionInfoDictionary(tenant: String, audience: String) -> [String: Any]
    {
        [
            "CertigoProductionAuthMode": "microsoft",
            "CertigoProductionCIAMCLIENT_ID": "33333333-3333-4333-8333-333333333333",
            "CertigoProductionCIAMTENANT_ID": tenant,
            "CertigoProductionCIAMAUTHORITY": "https://synthetic.ciamlogin.com",
            "CertigoProductionCIAMISSUER": "https://synthetic.ciamlogin.com/\(tenant)/v2.0",
            "CertigoProductionCIAMAUTHORITY_KIND": "standard",
            "CertigoProductionCIAMAPI_BASE_URL": "https://api.example.invalid/api",
            "CertigoProductionCIAMAPI_SCOPE": "api://\(audience)/user_impersonation",
            "CertigoProductionCIAMAPI_AUDIENCE": audience,
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["msauth.com.certigo.mobileapp"]]
            ],
        ]
    }

    private var infoDictionary: [String: Any] {
        [
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["msauth.\(bundleIdentifier)"]]
            ]
        ]
    }

    private func config(
        authority: String = "https://synthetic.ciamlogin.com", issuer: String? = nil,
        kind: CIAMConfiguration.AuthorityKind = .standard,
        api: String = "https://api.example.invalid/api",
        scope: String? = nil, redirect: String? = nil, registered: Set<String>? = nil,
        declared: Set<String> = ["msauth.example.native.dev"], collisions: Set<String> = [],
        clientID: String = "33333333-3333-4333-8333-333333333333",
        tenantID: String? = nil, apiAudience: String? = nil
    ) throws -> CIAMConfiguration {
        try CIAMConfiguration(
            clientID: clientID, tenantID: tenantID ?? tenant,
            authority: XCTUnwrap(URL(string: authority)),
            issuer: XCTUnwrap(
                URL(string: issuer ?? "https://synthetic.ciamlogin.com/\(tenant)/v2.0")),
            authorityKind: kind, apiBaseURL: XCTUnwrap(URL(string: api)),
            apiScope: scope ?? "api://\(audience)/user_impersonation",
            apiAudience: apiAudience ?? audience,
            redirectURI: XCTUnwrap(URL(string: redirect ?? callback)),
            registeredRedirects: registered ?? [callback], declaredCallbackSchemes: declared,
            otherAppCallbackSchemes: collisions
        )
    }

    private func rejects(
        _ error: CIAMConfigurationError, authority: String = "https://synthetic.ciamlogin.com",
        issuer: String? = nil, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try config(authority: authority, issuer: issuer), file: file, line: line
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, error, file: file, line: line)
        }
    }
}
