import Foundation
import XCTest

@testable import CertigoData

#if os(iOS)
    final class RuntimeDiskProtectionTests: XCTestCase {
        func testFoundationProtectionSetterReadsBackExactPolicyOnEmptyFile() throws {
            let manager = FileManager.default
            let root = manager.temporaryDirectory.appendingPathComponent(
                "certigo-foundation-protection-test-\(UUID().uuidString)")
            try manager.createDirectory(at: root, withIntermediateDirectories: false)
            defer { XCTAssertNoThrow(try manager.removeItem(at: root)) }
            let url = root.appendingPathComponent("empty-witness")
            XCTAssertTrue(manager.createFile(atPath: url.path, contents: Data()))
            try manager.setAttributes(
                [
                    .protectionKey:
                        FileProtectionType.completeUntilFirstUserAuthentication.rawValue as NSString
                ],
                ofItemAtPath: url.path)
            let attributes = try manager.attributesOfItem(atPath: url.path)
            try FileProtectionPolicy.requireFirstUnlock(attributes[.protectionKey])
            XCTAssertEqual(try Data(contentsOf: url), Data())
        }

        func testProtectionAttributeRepresentationsFailClosed() {
            let policy = FileProtectionType.completeUntilFirstUserAuthentication
            XCTAssertTrue(FileProtectionPolicy.isFirstUnlock(policy))
            XCTAssertTrue(FileProtectionPolicy.isFirstUnlock(policy.rawValue))
            XCTAssertTrue(FileProtectionPolicy.isFirstUnlock(policy.rawValue as NSString))
            for other in [
                FileProtectionType.none, .complete, .completeUnlessOpen,
            ] {
                XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(other))
                XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(other.rawValue))
                XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(other.rawValue as NSString))
            }
            XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(nil))
            XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(NSNumber(value: 3)))
            XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(policy.rawValue + "\n"))
            XCTAssertFalse(FileProtectionPolicy.isFirstUnlock(policy.rawValue.lowercased()))
            XCTAssertEqual(FileProtectionPolicy.rejection(nil), .missingAttribute)
            XCTAssertEqual(
                FileProtectionPolicy.rejection(NSNumber(value: 3)), .nonstringAttribute)
            XCTAssertEqual(
                FileProtectionPolicy.rejection(FileProtectionType.none),
                .differentKnownPolicy)
            XCTAssertEqual(
                FileProtectionPolicy.rejection(policy.rawValue + "\n"), .unrecognizedPolicy)
        }

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
            XCTAssertTrue(FileProtectionPolicy.isFirstUnlock(attributes[.protectionKey]))
            XCTAssertEqual(
                Set(try FileManager.default.contentsOfDirectory(atPath: root.path)),
                Set([".lock", name]))
        }
    }
#endif
