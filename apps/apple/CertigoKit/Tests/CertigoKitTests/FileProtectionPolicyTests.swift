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
}
