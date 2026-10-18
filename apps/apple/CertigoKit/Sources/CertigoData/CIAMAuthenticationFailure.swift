import Foundation

public enum CIAMAuthenticationFailure: Error, Equatable, Sendable {
    case interactionRequired
    case cancelled
    case network
    case permissionDenied
    case providerFailure
    case invalidToken
    case accountMissing
    case operationInProgress
    case accountChanged
    case configuration

    /// Only domains/codes cross this boundary, never SDK userInfo, descriptions, claims or tokens.
    public static func classify(
        domain: String, code: Int, msalDomain: String, underlyingNetworkCode: Int? = nil
    ) -> Self {
        // Official MSAL 2.16.0 public MSALError.h enum values.
        if domain == msalDomain {
            switch code {
            case -50_002: return .interactionRequired
            case -50_003: return .permissionDenied
            case -50_005: return .cancelled
            default: break
            }
        }
        if domain == NSURLErrorDomain || underlyingNetworkCode != nil {
            let networkCode = domain == NSURLErrorDomain ? code : underlyingNetworkCode
            return networkCode == NSURLErrorCancelled ? .cancelled : .network
        }
        return .providerFailure
    }
}
