import Foundation

public enum CIAMConfigurationEnvironmentError: Error, Equatable, LocalizedError, Sendable {
    case invalidOptIn
    case missingValue(String)
    case invalidValue(String)
    case releaseOptInNotAllowed
    case productionBuildRequired
    case unsupportedProductionBundle
    case missingBundleIdentifier
    case callbackNotDeclared
    case callbackCollision
    case redirectDoesNotMatchBundle

    public var errorDescription: String? {
        return switch self {
        case .invalidOptIn:
            "CERTIGO_CIAM_ENABLED must be exactly true or false."
        case .missingValue(let name):
            "Set the missing local Xcode scheme value \(name)."
        case .invalidValue(let name):
            "Correct the local Xcode scheme value \(name)."
        case .releaseOptInNotAllowed:
            "CIAM test sign-in can only be enabled in a development build."
        case .productionBuildRequired:
            "Microsoft production sign-in is available only in the Distribution build."
        case .unsupportedProductionBundle:
            "Microsoft production sign-in requires the Certigo App Store bundle identifier."
        case .missingBundleIdentifier:
            "The app bundle identifier is unavailable; CIAM sign-in cannot be initialized."
        case .callbackNotDeclared:
            "The CIAM callback scheme is not registered by this app's Info.plist."
        case .callbackCollision:
            "The CIAM callback scheme is duplicated in this app's Info.plist."
        case .redirectDoesNotMatchBundle:
            "Use the msauth.<bundle-id>://auth redirect for this app."
        }
    }
}
public enum CIAMConfigurationEnvironment {
    private static let enabledKey = "CERTIGO_CIAM_ENABLED"
    private static let clientIDKey = "CERTIGO_CIAM_CLIENT_ID"
    private static let tenantIDKey = "CERTIGO_CIAM_TENANT_ID"
    private static let authorityKey = "CERTIGO_CIAM_AUTHORITY"
    private static let issuerKey = "CERTIGO_CIAM_ISSUER"
    private static let authorityKindKey = "CERTIGO_CIAM_AUTHORITY_KIND"
    private static let apiBaseURLKey = "CERTIGO_CIAM_API_BASE_URL"
    private static let apiScopeKey = "CERTIGO_CIAM_API_SCOPE"
    private static let apiAudienceKey = "CERTIGO_CIAM_API_AUDIENCE"
    private static let redirectURIKey = "CERTIGO_CIAM_REDIRECT_URI"

    public static func configuration(
        environment: [String: String],
        bundleIdentifier: String?,
        infoDictionary: [String: Any],
        isDevelopmentBuild: Bool
    ) throws -> CIAMConfiguration? {
        guard let enabled = environment[enabledKey] else { return nil }
        switch enabled {
        case "false":
            return nil
        case "true":
            break
        default:
            throw CIAMConfigurationEnvironmentError.invalidOptIn
        }
        guard isDevelopmentBuild else {
            throw CIAMConfigurationEnvironmentError.releaseOptInNotAllowed
        }

        return try validatedConfiguration(
            environment: environment, bundleIdentifier: bundleIdentifier,
            infoDictionary: infoDictionary)
    }

    public static func productionConfiguration(
        infoDictionary: [String: Any],
        bundleIdentifier: String?,
        isDevelopmentBuild: Bool
    ) throws -> CIAMConfiguration {
        guard !isDevelopmentBuild else {
            throw CIAMConfigurationEnvironmentError.productionBuildRequired
        }
        guard let bundleIdentifier else {
            throw CIAMConfigurationEnvironmentError.missingBundleIdentifier
        }
        guard bundleIdentifier == "com.certigo.mobileapp" else {
            throw CIAMConfigurationEnvironmentError.unsupportedProductionBundle
        }
        guard infoDictionary["CertigoProductionAuthMode"] as? String == "microsoft" else {
            throw CIAMConfigurationEnvironmentError.missingValue("CertigoProductionAuthMode")
        }
        var environment: [String: String] = [:]
        for name in [
            "CLIENT_ID", "TENANT_ID", "AUTHORITY", "ISSUER", "AUTHORITY_KIND",
            "API_BASE_URL", "API_SCOPE", "API_AUDIENCE",
        ] {
            let key = "CertigoProductionCIAM\(name)"
            guard let value = infoDictionary[key] as? String,
                !value.isEmpty, !value.contains("$(")
            else { throw CIAMConfigurationEnvironmentError.missingValue(key) }
            environment["CERTIGO_CIAM_\(name)"] = value
        }
        let callbackScheme = "msauth.\(bundleIdentifier)"
        environment["CERTIGO_CIAM_REDIRECT_URI"] = "\(callbackScheme)://auth"
        return try validatedConfiguration(
            environment: environment, bundleIdentifier: bundleIdentifier,
            infoDictionary: infoDictionary)
    }

    @MainActor
    public static func configuredProductionProvider<Provider>(
        infoDictionary: [String: Any],
        bundleIdentifier: String?,
        isDevelopmentBuild: Bool,
        makeProvider: @MainActor (CIAMConfiguration) throws -> Provider
    ) throws -> (configuration: CIAMConfiguration, provider: Provider) {
        let configuration = try productionConfiguration(
            infoDictionary: infoDictionary,
            bundleIdentifier: bundleIdentifier,
            isDevelopmentBuild: isDevelopmentBuild)
        return (configuration, try makeProvider(configuration))
    }

    private static func validatedConfiguration(
        environment: [String: String],
        bundleIdentifier: String?,
        infoDictionary: [String: Any]
    ) throws -> CIAMConfiguration {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            throw CIAMConfigurationEnvironmentError.missingBundleIdentifier
        }
        let clientID = try required(clientIDKey, from: environment)
        let tenantID = try required(tenantIDKey, from: environment)
        let authorityText = try required(authorityKey, from: environment)
        let issuerText = try required(issuerKey, from: environment)
        let authorityKindText = try required(authorityKindKey, from: environment)
        let rawAPIBaseURLText = try required(apiBaseURLKey, from: environment)
        let apiBaseURLText = rawAPIBaseURLText.replacingOccurrences(
            of: "func-certigo-staging-hwbsyiwa7tqnw.azurewebsites.net",
            with: "func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net"
        )
        let apiScope = try required(apiScopeKey, from: environment)
        let apiAudience = try required(apiAudienceKey, from: environment)
        let redirectText = try required(redirectURIKey, from: environment)

        let authorityKind: CIAMConfiguration.AuthorityKind
        switch authorityKindText {
        case "standard":
            authorityKind = .standard
        case "customDomain":
            authorityKind = .customDomain
        default:
            throw CIAMConfigurationEnvironmentError.invalidValue(authorityKindKey)
        }

        guard let authority = URL(string: authorityText) else {
            throw CIAMConfigurationEnvironmentError.invalidValue(authorityKey)
        }
        guard let issuer = URL(string: issuerText) else {
            throw CIAMConfigurationEnvironmentError.invalidValue(issuerKey)
        }
        guard let apiBaseURL = URL(string: apiBaseURLText) else {
            throw CIAMConfigurationEnvironmentError.invalidValue(apiBaseURLKey)
        }
        guard let redirectURI = URL(string: redirectText),
            let redirectScheme = redirectURI.scheme
        else {
            throw CIAMConfigurationEnvironmentError.invalidValue(redirectURIKey)
        }

        let expectedRedirect = "msauth.\(bundleIdentifier)://auth"
        guard redirectText == expectedRedirect else {
            throw CIAMConfigurationEnvironmentError.redirectDoesNotMatchBundle
        }
        let urlTypes = infoDictionary["CFBundleURLTypes"] as? [[String: Any]] ?? []
        let callbackDeclarationCount =
            urlTypes
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
            .filter { $0.caseInsensitiveCompare(redirectScheme) == .orderedSame }
            .count
        guard callbackDeclarationCount == 1 else {
            if callbackDeclarationCount > 1 {
                throw CIAMConfigurationEnvironmentError.callbackCollision
            }
            throw CIAMConfigurationEnvironmentError.callbackNotDeclared
        }
        let declaredSchemes = Set(
            urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        )

        return try CIAMConfiguration(
            clientID: clientID,
            tenantID: tenantID,
            authority: authority,
            issuer: issuer,
            authorityKind: authorityKind,
            apiBaseURL: apiBaseURL,
            apiScope: apiScope,
            apiAudience: apiAudience,
            redirectURI: redirectURI,
            // Reuse exact redirect-shape validation; external identity-provider registration is manual.
            registeredRedirects: [redirectText],
            declaredCallbackSchemes: declaredSchemes,
            otherAppCallbackSchemes: []
        )
    }

    @MainActor
    public static func configuredProvider<Provider>(
        environment: [String: String],
        bundleIdentifier: String?,
        infoDictionary: [String: Any],
        isDevelopmentBuild: Bool,
        makeProvider: @MainActor (CIAMConfiguration) throws -> Provider
    ) throws -> (configuration: CIAMConfiguration, provider: Provider)? {
        guard
            let configuration = try configuration(
                environment: environment,
                bundleIdentifier: bundleIdentifier,
                infoDictionary: infoDictionary,
                isDevelopmentBuild: isDevelopmentBuild
            )
        else {
            return nil
        }
        return (configuration, try makeProvider(configuration))
    }

    private static func required(
        _ name: String,
        from environment: [String: String]
    ) throws -> String {
        guard let value = environment[name], !value.isEmpty,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw CIAMConfigurationEnvironmentError.missingValue(name)
        }
        return value
    }
}
