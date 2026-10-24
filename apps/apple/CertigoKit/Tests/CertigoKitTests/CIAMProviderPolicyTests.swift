import CertigoData
import Foundation
import XCTest

final class CIAMProviderPolicyTests: XCTestCase {
    func testMSALPublicFailureCodesExposeCategoriesNotDiagnosticStrings() {
        let domain = "synthetic-msal"
        for (code, expected) in [
            (-50_002, CIAMAuthenticationFailure.interactionRequired),
            (-50_003, .permissionDenied), (-50_005, .cancelled),
            (-50_000, .providerFailure), (-50_004, .providerFailure),
            (-50_006, .providerFailure), (123, .providerFailure),
        ] {
            XCTAssertEqual(
                CIAMAuthenticationFailure.classify(domain: domain, code: code, msalDomain: domain),
                expected)
        }
        XCTAssertEqual(
            CIAMAuthenticationFailure.classify(domain: "other", code: -50_005, msalDomain: domain),
            .providerFailure)
    }

    func testDirectAndUnderlyingNetworkErrorsHaveAnExplicitCategory() {
        XCTAssertEqual(
            CIAMAuthenticationFailure.classify(
                domain: NSURLErrorDomain, code: NSURLErrorCancelled, msalDomain: "synthetic-msal"),
            .cancelled)
        XCTAssertEqual(
            CIAMAuthenticationFailure.classify(
                domain: "synthetic-msal", code: -50_005, msalDomain: "synthetic-msal",
                underlyingNetworkCode: NSURLErrorTimedOut), .cancelled)
        XCTAssertEqual(
            CIAMAuthenticationFailure.classify(
                domain: NSURLErrorDomain, code: NSURLErrorTimedOut, msalDomain: "synthetic-msal"),
            .network)
        XCTAssertEqual(
            CIAMAuthenticationFailure.classify(
                domain: "synthetic-msal", code: -50_000, msalDomain: "synthetic-msal",
                underlyingNetworkCode: NSURLErrorNotConnectedToInternet), .network)
    }

    func testDatedCandidateCannotTurnObservedFlutterRedirectsIntoNativeRegistration() {
        XCTAssertThrowsError(
            try CIAMDevelopmentCandidate.validatedMetadata(
                registeredRedirects: CIAMDevelopmentCandidate.historicallyRegisteredRedirects,
                declaredSchemes: ["msauth.com.certigo.native.dev"], otherAppSchemes: ["certigo"])
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .redirectNotRegistered)
        }
    }

    func testHypotheticalRegistrationIsMetadataOnlyAndStillChecksCollision() throws {
        let registered = CIAMDevelopmentCandidate.historicallyRegisteredRedirects.union([
            CIAMDevelopmentCandidate.redirect
        ])
        let value = try CIAMDevelopmentCandidate.validatedMetadata(
            registeredRedirects: registered, declaredSchemes: ["msauth.com.certigo.native.dev"],
            otherAppSchemes: ["certigo"])
        XCTAssertEqual(value.tenantID, CIAMDevelopmentCandidate.tenantID)
        XCTAssertEqual(
            value.apiScope, "api://\(CIAMDevelopmentCandidate.apiAudience)/user_impersonation")
        XCTAssertEqual(value.authority.path, "")
        XCTAssertEqual(value.issuer.path, "/\(value.tenantID)/v2.0")
        XCTAssertThrowsError(
            try CIAMDevelopmentCandidate.validatedMetadata(
                registeredRedirects: registered, declaredSchemes: ["msauth.com.certigo.native.dev"],
                otherAppSchemes: ["MSAUTH.COM.CERTIGO.NATIVE.DEV"])
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .callbackCollision)
        }
    }
}
