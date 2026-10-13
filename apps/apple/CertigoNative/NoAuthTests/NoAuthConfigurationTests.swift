import CertigoData
import Foundation
import MSAL
import XCTest

final class NoAuthConfigurationTests: XCTestCase {
    func testTestBundleIsDistinctFromDevelopmentAndFlutterApplications() {
        // XCTest bundle identity is not proof of the runner's signed Keychain identity.
        XCTAssertEqual(Bundle(for: Self.self).bundleIdentifier, "com.certigo.native.noauth-tests")
        XCTAssertNotEqual(
            Bundle(for: Self.self).bundleIdentifier, CIAMDevelopmentCandidate.bundleIdentifier)
        XCTAssertNotEqual(Bundle(for: Self.self).bundleIdentifier, "com.certigo.mobileapp")
    }

    func testObservedRegistrationStillRejectsNativeRedirectWithoutSDKConstruction() {
        XCTAssertThrowsError(
            try CIAMDevelopmentCandidate.validatedMetadata(
                registeredRedirects: CIAMDevelopmentCandidate.historicallyRegisteredRedirects,
                declaredSchemes: ["msauth.com.certigo.native.dev"], otherAppSchemes: ["certigo"])
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .redirectNotRegistered)
        }
    }

    func testHypotheticalMetadataDoesNotRemoveCaseInsensitiveCollisionGate() {
        XCTAssertThrowsError(
            try CIAMDevelopmentCandidate.validatedMetadata(
                registeredRedirects: [CIAMDevelopmentCandidate.redirect],
                declaredSchemes: ["msauth.com.certigo.native.dev"],
                otherAppSchemes: ["MSAUTH.COM.CERTIGO.NATIVE.DEV"])
        ) {
            XCTAssertEqual($0 as? CIAMConfigurationError, .callbackCollision)
        }
    }
}
