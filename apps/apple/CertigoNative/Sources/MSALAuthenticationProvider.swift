import CertigoData
import Foundation
import MSAL
import UIKit

/// Unwired Apple-only candidate. Compilation, callbacks/cache and live auth still require Apple proof.
@MainActor
final class MSALAuthenticationProvider: CIAMAuthenticationProvider {
    private let application: MSALPublicClientApplication
    private let configuration: CIAMConfiguration
    private let presentation: @MainActor () throws -> UIViewController
    private var accountIdentifier: String?
    private var returnedAuthority: MSALAuthority?
    private var busy = false

    init(
        configuration: CIAMConfiguration,
        presentation: @escaping @MainActor () throws -> UIViewController
    ) throws {
        guard Bundle.main.bundleIdentifier == CIAMDevelopmentCandidate.bundleIdentifier,
            configuration.redirectURI.absoluteString == CIAMDevelopmentCandidate.redirect
        else { throw CIAMAuthenticationFailure.configuration }
        let authority: MSALCIAMAuthority
        do {
            authority = try MSALCIAMAuthority(url: configuration.authority)
        } catch {
            throw Self.failure(error)
        }
        let parameters = MSALPublicClientApplicationConfig(
            clientId: configuration.clientID, redirectUri: configuration.redirectURI.absoluteString,
            authority: authority)
        // Official SDK private-group option; no shared Keychain entitlement or broker is enabled.
        parameters.cacheConfig.keychainSharingGroup = CIAMDevelopmentCandidate.bundleIdentifier
        MSALGlobalConfig.brokerAvailability = .none
        MSALGlobalConfig.loggerConfig.logLevel = .nothing
        // Redirect verification stays enabled; knownAuthorities is not used to bypass validation.
        do {
            application = try MSALPublicClientApplication(configuration: parameters)
        } catch {
            throw Self.failure(error)
        }
        self.configuration = configuration
        self.presentation = presentation
    }

    func acquireSilently() async throws -> CIAMAccessToken {
        guard !busy else { throw CIAMAuthenticationFailure.operationInProgress }
        guard !Task.isCancelled else { throw CIAMAuthenticationFailure.cancelled }
        guard let identifier = accountIdentifier else {
            throw CIAMAuthenticationFailure.interactionRequired
        }
        let account: MSALAccount
        do {
            account = try application.account(forIdentifier: identifier)
        } catch let error as CIAMAuthenticationFailure {
            throw error
        } catch {
            throw Self.failure(error)
        }
        let parameters = MSALSilentTokenParameters(
            scopes: [configuration.apiScope], account: account)
        parameters.authority = returnedAuthority
        busy = true
        defer { busy = false }
        let result: MSALResult = try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { result, error in
                Self.complete(result, error, continuation)
            }
        }
        guard !Task.isCancelled else { throw CIAMAuthenticationFailure.cancelled }
        guard result.account.identifier == identifier else {
            throw CIAMAuthenticationFailure.accountChanged
        }
        return try accept(result)
    }

    func acquireInteractively() async throws -> CIAMAccessToken {
        guard !busy else { throw CIAMAuthenticationFailure.operationInProgress }
        guard !Task.isCancelled else { throw CIAMAuthenticationFailure.cancelled }
        let controller: UIViewController
        do {
            controller = try presentation()
        } catch {
            throw CIAMAuthenticationFailure.configuration
        }
        guard controller.viewIfLoaded?.window != nil else {
            throw CIAMAuthenticationFailure.configuration
        }
        let web = MSALWebviewParameters(authPresentationViewController: controller)
        web.webviewType = .authenticationSession
        web.prefersEphemeralWebBrowserSession = true
        let parameters = MSALInteractiveTokenParameters(
            scopes: [configuration.apiScope], webviewParameters: web)
        parameters.promptType = .selectAccount
        busy = true
        defer { busy = false }
        let result: MSALResult = try await withCheckedThrowingContinuation { continuation in
            application.acquireToken(with: parameters) { result, error in
                Self.complete(result, error, continuation)
            }
        }
        guard !Task.isCancelled else { throw CIAMAuthenticationFailure.cancelled }
        return try accept(result)
    }

    func removeLocalAccount() async throws {
        // Refuse success while an SDK request could still repopulate its cache after removal.
        guard !busy else { throw CIAMAuthenticationFailure.operationInProgress }
        guard let identifier = accountIdentifier else {
            throw CIAMAuthenticationFailure.accountMissing
        }
        do {
            let account = try application.account(forIdentifier: identifier)
            try application.remove(account)
            accountIdentifier = nil
            returnedAuthority = nil
        } catch let error as CIAMAuthenticationFailure {
            throw error
        } catch {
            throw Self.failure(error)
        }
    }

    func handleCallback(_ url: URL, sourceApplication: String?) -> Bool {
        guard url.scheme?.lowercased() == configuration.redirectURI.scheme?.lowercased(),
            url.host == configuration.redirectURI.host
        else { return false }
        return MSALPublicClientApplication.handleMSALResponse(
            url, sourceApplication: sourceApplication)
    }

    private func accept(_ result: MSALResult) throws -> CIAMAccessToken {
        guard result.scopes.contains(configuration.apiScope) else {
            throw CIAMAuthenticationFailure.permissionDenied
        }
        guard !result.accessToken.isEmpty,
            result.accessToken.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
            let expiry = result.expiresOn, expiry > Date(),
            result.authenticationScheme.trimmingCharacters(in: .whitespaces) == "Bearer",
            let identifier = result.account.identifier, !identifier.isEmpty,
            result.authority.url.host?.lowercased() == configuration.authority.host?.lowercased(),
            result.tenantProfile.tenantId.flatMap(UUID.init(uuidString:))
                == UUID(uuidString: configuration.tenantID)
        else { throw CIAMAuthenticationFailure.invalidToken }
        // This opaque ID is only for SDK cache lookup, never the API/outbox owner.
        accountIdentifier = identifier
        returnedAuthority = result.authority
        return CIAMAccessToken(value: result.accessToken, expiresAt: expiry)
    }

    nonisolated private static func complete(
        _ result: MSALResult?, _ error: Error?,
        _ continuation: CheckedContinuation<MSALResult, Error>
    ) {
        if let error {
            continuation.resume(throwing: failure(error))
        } else if let result {
            continuation.resume(returning: result)
        } else {
            continuation.resume(throwing: CIAMAuthenticationFailure.invalidToken)
        }
    }

    nonisolated private static func failure(_ error: Error) -> CIAMAuthenticationFailure {
        let value = error as NSError
        let underlying = value.userInfo[NSUnderlyingErrorKey] as? NSError
        return CIAMAuthenticationFailure.classify(
            domain: value.domain, code: value.code, msalDomain: MSALErrorDomain,
            underlyingNetworkCode: underlying?.domain == NSURLErrorDomain ? underlying?.code : nil)
    }
}
