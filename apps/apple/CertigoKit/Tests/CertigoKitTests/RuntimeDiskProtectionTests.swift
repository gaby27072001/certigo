import Foundation
import XCTest

@testable import CertigoData

#if os(iOS)
    final class RuntimeDiskProtectionTests: XCTestCase {
        func testProtectedDescriptorWriteRetainsFirstUnlockPolicyAndRemovesEmptyWitness() throws {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(
                "certigo-protection-test-\(UUID().uuidString)")
            let disk = try RuntimeDisk(root: root, maximumBytes: 1_024)
            defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
            let name = "b-\(String(repeating: "b", count: 64)).json"
            let bytes = Data([0x42])
            try disk.exclusive { try disk.write(bytes, name: name) }
            let url = root.appendingPathComponent(name)
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertEqual(
                attributes[.protectionKey] as? FileProtectionType,
                .completeUntilFirstUserAuthentication)
            XCTAssertEqual(
                Set(try FileManager.default.contentsOfDirectory(atPath: root.path)),
                Set([".lock", name]))
        }
    }
#endif
