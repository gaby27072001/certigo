import Foundation

/// Validates supplied public metadata, not SDK initialization, grants or app entitlements.

/// An Apple SDK adapter must own its account/cache and return no guessed backend owner ID.
public enum CIAMConfigurationError: Error, Equatable, Sendable {
    case invalidIdentity
    case invalidAuthority
    case issuerMismatch
    case invalidAPIScope
    case invalidAPIURL
    case invalidRedirect
    case redirectNotRegistered
    case callbackNotDeclared
    case callbackCollision
}
public struct CIAMConfiguration: Sendable {
    public enum AuthorityKind: Sendable {
        case standard
        case customDomain
    }

    public let clientID: String
    public let tenantID: String
    public let authority: URL
    public let issuer: URL
    public let apiBaseURL: URL
    public let apiScope: String
    public let apiAudience: String
    public let redirectURI: URL

    public init(
        clientID: String, tenantID: String, authority: URL, issuer: URL,
        authorityKind: AuthorityKind, apiBaseURL: URL, apiScope: String,
        apiAudience: String, redirectURI: URL, registeredRedirects: Set<String>,
        declaredCallbackSchemes: Set<String>, otherAppCallbackSchemes: Set<String>
    ) throws {
        guard UUID(uuidString: clientID) != nil, let tenant = UUID(uuidString: tenantID),
            UUID(uuidString: apiAudience) != nil
        else { throw CIAMConfigurationError.invalidIdentity }
        let tenantPath = tenant.uuidString.lowercased()
        guard Self.isHTTPSOrigin(authority), Self.isHTTPSOrigin(issuer) else {
            throw CIAMConfigurationError.invalidAuthority
        }
        switch authorityKind {
        case .standard:
            guard let host = authority.host, host.hasSuffix(".ciamlogin.com"),
                host.split(separator: ".").count == 3,
                authority.path.isEmpty || authority.path == "/"
                    || authority.path == "/\(tenantPath)"
            else { throw CIAMConfigurationError.invalidAuthority }
        case .customDomain:
            guard authority.path == "/\(tenantPath)" else {
                throw CIAMConfigurationError.invalidAuthority
            }
        }
        guard issuer.host == authority.host,
            issuer.path == "/\(tenantPath)/v2.0"
        else { throw CIAMConfigurationError.issuerMismatch }
        do {
            try CertigoAPI.validateBaseURL(apiBaseURL)
        } catch APIError.configuration {
            throw CIAMConfigurationError.invalidAPIURL
        }
        let prefix = "api://\(apiAudience)/"
        guard apiScope.hasPrefix(prefix) else { throw CIAMConfigurationError.invalidAPIScope }
        let permission = apiScope.dropFirst(prefix.count)
        guard !permission.isEmpty,
            permission.utf8.allSatisfy({
                (65...90).contains($0) || (97...122).contains($0)
                    || (48...57).contains($0) || $0 == 95 || $0 == 45 || $0 == 46
            })
        else { throw CIAMConfigurationError.invalidAPIScope }
        guard let scheme = redirectURI.scheme?.lowercased(), scheme != "https", scheme != "http",
            let host = redirectURI.host, !host.isEmpty,
            redirectURI.user == nil, redirectURI.password == nil, redirectURI.port == nil,
            redirectURI.query == nil, redirectURI.fragment == nil,
            redirectURI.path.isEmpty || redirectURI.path == "/"
        else { throw CIAMConfigurationError.invalidRedirect }
        // Registration matching is exact: never silently trim the Flutter trailing slash.
        guard registeredRedirects.contains(redirectURI.absoluteString) else {
            throw CIAMConfigurationError.redirectNotRegistered
        }
        guard declaredCallbackSchemes.contains(where: { $0.lowercased() == scheme }) else {
            throw CIAMConfigurationError.callbackNotDeclared
        }
        guard !otherAppCallbackSchemes.contains(where: { $0.lowercased() == scheme }) else {
            throw CIAMConfigurationError.callbackCollision
        }
        self.clientID = clientID
        self.tenantID = tenantID
        self.authority = authority
        self.issuer = issuer
        self.apiBaseURL = apiBaseURL
        self.apiScope = apiScope
        self.apiAudience = apiAudience
        self.redirectURI = redirectURI
    }

    private static func isHTTPSOrigin(_ url: URL) -> Bool {
        url.scheme == "https" && url.host != nil && (url.port == nil || url.port == 443)
            && url.user == nil && url.password == nil && url.query == nil && url.fragment == nil
    }
}
public struct CIAMAccessToken: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let value: String
    public let expiresAt: Date

    public init(value: String, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }

    public var description: String { "CIAMAccessToken(redacted)" }
    public var debugDescription: String { description }
}
@MainActor
public protocol CIAMAuthenticationProvider {
    func acquireSilently() async throws -> CIAMAccessToken
    func acquireInteractively() async throws -> CIAMAccessToken
    func removeLocalAccount() async throws
}
