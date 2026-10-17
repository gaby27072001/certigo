import Foundation

/// Cloud's public 2026-10-13 snapshot; not active configuration or registration permission.
public enum CIAMDevelopmentCandidate {
    public static let observedAt = "2026-10-13"
    public static let bundleIdentifier = "com.certigo.native.dev"
    public static let clientID = "4d1f1075-7bc5-4764-947b-701435a85f8c"
    public static let tenantID = "af721be8-5901-422a-b299-b9c57847b968"
    public static let apiAudience = "12910b8e-6c75-4d51-91d8-4d5fb8a6e915"
    public static let redirect = "msauth.com.certigo.native.dev://auth"
    public static let historicallyRegisteredRedirects: Set<String> = [
        "certigo://auth", "certigo://auth/",
    ]

    public static func validatedMetadata(
        registeredRedirects: Set<String>, declaredSchemes: Set<String>,
        otherAppSchemes: Set<String>
    ) throws -> CIAMConfiguration {
        func url(_ text: String) throws -> URL {
            guard let value = URL(string: text) else {
                throw CIAMAuthenticationFailure.configuration
            }
            return value
        }
        return try CIAMConfiguration(
            clientID: clientID, tenantID: tenantID,
            authority: url("https://\(tenantID).ciamlogin.com"),
            issuer: url("https://\(tenantID).ciamlogin.com/\(tenantID)/v2.0"),
            authorityKind: .standard,
            // ARM host plus the source API route prefix is a candidate, not a health proof.
            apiBaseURL: url("https://func-certigo-staging-hwbsyiwa7tqnw.azurewebsites.net/api"),
            apiScope: "api://\(apiAudience)/user_impersonation", apiAudience: apiAudience,
            redirectURI: url(redirect), registeredRedirects: registeredRedirects,
            declaredCallbackSchemes: declaredSchemes, otherAppCallbackSchemes: otherAppSchemes
        )
    }
}
