import Foundation
import XCTest

@testable import CertigoData

final class FileProtectionPolicyTests: XCTestCase {
    func testFoundationStringAndNSStringRepresentationsRequireTheExactFirstUnlockPolicy() {
        let raw = "NSFileProtectionCompleteUntilFirstUserAuthentication"
        XCTAssertTrue(FileProtectionPolicy.isFirstUnlock(raw))
        XCTAssertTrue(FileProtectionPolicy.isFirstUnlock(raw as NSString))
        for value: Any in [
            "NSFileProtectionNone", "NSFileProtectionComplete",
            raw + "\n", raw.lowercased(), "", 3, NSNumber(value: 3),
            [raw], ["policy": raw],
        ] {
            XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(value))
        }
        XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(nil))
    }

    func testRejectionReportsOnlyTheAttributeCategory() throws {
        try FileProtectionPolicy.requireFirstUnlock(
            "NSFileProtectionCompleteUntilFirstUserAuthentication" as NSString)
        for (value, expected): (Any?, FileProtectionPolicy.Rejection) in [
            (nil, .missingAttribute),
            (NSNumber(value: 3), .nonstringAttribute),
            ("NSFileProtectionNone", .differentKnownPolicy),
            ("NSFileProtectionComplete", .differentKnownPolicy),
            ("NSFileProtectionCompleteUnlessOpen", .differentKnownPolicy),
            ("NSFileProtectionCompleteUntilFirstUserAuthentication\n", .unrecognizedPolicy),
        ] {
            XCTAssertEqual(FileProtectionPolicy.rejection(value), expected)
            XCTAssertThrowsError(try FileProtectionPolicy.requireFirstUnlock(value)) {
                XCTAssertEqual($0 as? FileProtectionPolicy.Rejection, expected)
            }
        }
    }
}
