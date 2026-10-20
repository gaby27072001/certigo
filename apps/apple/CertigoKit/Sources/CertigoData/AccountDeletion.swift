import CoreFoundation
import Foundation

public struct AccountDeletion: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case notRequested, pending, completed }
    public let status: Status
    public let completedSteps: Int
    public let totalSteps: Int
    public let requestedAt: Date?
    public let completedAt: Date?
    public let failureCode: String?
    public let retryAfterSeconds: Int?

    public func validated() throws -> Self {
        guard totalSteps > 0, totalSteps <= 100,
            (0...totalSteps).contains(completedSteps),
            retryAfterSeconds.map({ (0...300).contains($0) }) ?? true,
            failureCode.map({ $0.utf8.count <= 128 }) ?? true
        else { throw APIError.invalidResponse }
        switch status {
        case .notRequested:
            guard completedSteps == 0, requestedAt == nil, completedAt == nil else {
                throw APIError.invalidResponse
            }
        case .pending:
            guard requestedAt != nil, completedAt == nil else { throw APIError.invalidResponse }
        case .completed:
            guard completedSteps == totalSteps, let requestedAt, let completedAt,
                completedAt >= requestedAt, failureCode == nil
            else { throw APIError.invalidResponse }
        }
        return self
    }
}
public struct CIAMDeletionProof: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let accessToken: CIAMAccessToken
    public let idToken: String
    public let accountIdentifier: String

    public init(accessToken: CIAMAccessToken, idToken: String, accountIdentifier: String) {
        self.accessToken = accessToken
        self.idToken = idToken
        self.accountIdentifier = accountIdentifier
    }

    public var description: String { "CIAMDeletionProof(redacted)" }
    public var debugDescription: String { description }

    public func validated(expectedAccount: String, clientID: String, now: Date) throws -> Self {
        guard accountIdentifier == expectedAccount, !expectedAccount.isEmpty else {
            throw CIAMAuthenticationFailure.accountChanged
        }
        let parts = idToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, idToken.utf8.count <= 32_768,
            parts.allSatisfy({ !$0.isEmpty }),
            idToken.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            accessToken.expiresAt > now, !accessToken.value.isEmpty,
            accessToken.value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
        else { throw CIAMAuthenticationFailure.invalidToken }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let bytes = Data(base64Encoded: payload),
            let claims = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
            let audience = claims["aud"] as? String, audience == clientID,
            let authTime = claims["auth_time"] as? NSNumber,
            CFGetTypeID(authTime) != CFBooleanGetTypeID(),
            let expiry = claims["exp"] as? NSNumber,
            CFGetTypeID(expiry) != CFBooleanGetTypeID(),
            authTime.doubleValue.isFinite, expiry.doubleValue.isFinite,
            authTime.doubleValue.rounded() == authTime.doubleValue,
            expiry.doubleValue.rounded() == expiry.doubleValue,
            authTime.doubleValue >= now.timeIntervalSince1970 - 600,
            authTime.doubleValue <= now.timeIntervalSince1970 + 120,
            expiry.doubleValue > now.timeIntervalSince1970
        else { throw CIAMAuthenticationFailure.invalidToken }
        // Local rejection only: signature, issuer, subject and freshness remain server-validated.
        return self
    }
}
@MainActor
public protocol CIAMAccountDeletionProvider: CIAMAuthenticationProvider {
    var deletionAccountIdentifier: String? { get }
    func reauthenticateForAccountDeletion() async throws -> CIAMDeletionProof
    func removeAccountForDeletion(identifier: String) async throws
}
