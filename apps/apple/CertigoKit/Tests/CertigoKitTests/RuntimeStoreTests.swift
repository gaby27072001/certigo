import Foundation
import XCTest

@testable import CertigoData

#if canImport(Darwin)
    import Darwin
#else
    import Glibc
#endif
struct RuntimeFixture {
    let snapshot: RuntimeContentSnapshot
    let files: [Data]

    init(version: Int = 0, owner: String = "owner-A", apiScope: String = "https://certigo.test/api")
        throws
    {
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        var first = try Data(
            contentsOf: root.appendingPathComponent("apple-compat/v1/supported/question-v3.json"))
        if version != 0 {
            var question = try XCTUnwrap(
                JSONSerialization.jsonObject(with: first) as? [String: Any])
            question["prompt"] = "Synthetic revision \(version)"
            first = try JSONSerialization.data(
                withJSONObject: question, options: [.sortedKeys, .withoutEscapingSlashes])
            first.append(0x0A)
        }
        let second = try Data(
            contentsOf: root.appendingPathComponent(
                "apple-compat/v1/supported/question-v4-mcq.json"))
        files = [first, second]
        let bytes = try Data(contentsOf: root.appendingPathComponent("runtime/manifest-v3.json"))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var entries = try XCTUnwrap(object["files"] as? [[String: Any]])
        for index in entries.indices {
            let digest = try CanonicalQuestionReader.digest(files[index])
            entries[index]["hash"] = digest.sha256
            entries[index]["size"] = digest.size
        }
        object["files"] = entries
        object.removeValue(forKey: "rootHash")
        object.removeValue(forKey: "manifestId")
        let body = try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        let digest = try CanonicalQuestionReader.digest(body).sha256
        object["rootHash"] = digest
        object["manifestId"] = "sha256:\(digest)"
        let release = "sha256:" + String(repeating: String(version, radix: 16), count: 64)
        object["releaseId"] = release
        let manifest = try PublicReleaseContracts.manifest(
            JSONSerialization.data(
                withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]))
        let binding = try PublicReleaseContracts.bind(
            manifest, releaseId: release,
            manifestId: manifest.manifestId, etag: "\"\(manifest.manifestId)\"")
        snapshot = RuntimeContentSnapshot(
            ownerId: owner, apiScope: apiScope, manifest: manifest, binding: binding)
    }

    func activate(_ store: RuntimeContentStore) throws {
        let stage = try store.begin(snapshot)
        for index in files.indices {
            try store.saveFile(files[index], file: snapshot.manifest.files[index])
        }
        _ = try store.activate(stage)
    }
}
final class RuntimeStoreTests: XCTestCase {
    func testIncompleteStagingNeverReplacesActiveAndRestartReusesVerifiedFiles() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let old = try RuntimeFixture()
        try old.activate(store)
        let next = try RuntimeFixture(version: 1)
        let stage = try store.begin(next.snapshot)
        XCTAssertThrowsError(try store.activate(stage)) {
            XCTAssertEqual($0 as? RuntimeStoreError, .missingFile)
        }
        try store.saveFile(next.files[0], file: next.snapshot.manifest.files[0])
        let restarted = try RuntimeContentStore(root: root)
        XCTAssertEqual(
            try restarted.active(ownerId: "owner-A", apiScope: old.snapshot.apiScope)?.binding,
            old.snapshot.binding)
        XCTAssertEqual(try restarted.cachedFile(next.snapshot.manifest.files[0]), next.files[0])
        try next.activate(restarted)
        XCTAssertEqual(
            try restarted.previous(ownerId: "owner-A", apiScope: old.snapshot.apiScope)?.binding,
            old.snapshot.binding)
    }

    func testPinsFromAllOwnersAndScopesSurviveRotationAndRestartWithoutPayloadRewriting() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let old = try RuntimeFixture()
        let pins = [
            RuntimeManifestPin(
                ownerId: "owner-A", apiScope: old.snapshot.apiScope,
                manifestId: old.snapshot.manifest.manifestId),
            RuntimeManifestPin(
                ownerId: "owner-B", apiScope: "https://other.test/api",
                manifestId: old.snapshot.manifest.manifestId),
        ]
        try store.retainPins(pins)
        for version in 0..<4 { try RuntimeFixture(version: version).activate(store) }
        let restarted = try RuntimeContentStore(root: root)
        XCTAssertEqual(Set(try restarted.retainedPins()), Set(pins))
        XCTAssertEqual(try restarted.cachedFile(old.snapshot.manifest.files[0]), old.files[0])
        XCTAssertNil(try restarted.active(ownerId: "owner-B", apiScope: old.snapshot.apiScope))
        XCTAssertNil(try restarted.active(ownerId: "owner-A", apiScope: "https://other.test/api"))
    }

    func testTamperedBlobIsVisibleAndDoesNotSilentlyRedownloadOrRollback() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let old = try RuntimeFixture()
        try old.activate(store)
        let next = try RuntimeFixture(version: 1)
        try next.activate(store)
        let target = root.appendingPathComponent("b-\(next.snapshot.manifest.files[0].hash).json")
        try Data(repeating: 0x20, count: next.files[0].count).write(to: target)
        XCTAssertThrowsError(try store.active(ownerId: "owner-A", apiScope: old.snapshot.apiScope))
        {
            XCTAssertEqual($0 as? CanonicalContentError, .integrityMismatch)
        }
        XCTAssertEqual(
            try store.previous(ownerId: "owner-A", apiScope: old.snapshot.apiScope)?.binding,
            old.snapshot.binding)
        let recovered = try store.restorePrevious(
            ownerId: "owner-A", apiScope: old.snapshot.apiScope)
        XCTAssertEqual(recovered.binding, old.snapshot.binding)
    }

    func testCorruptArchiveAndWrongOwnerCapsuleAreNeverAnEmptyCache() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let fixture = try RuntimeFixture()
        try fixture.activate(store)
        let capsule = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
                .first(where: { $0.lastPathComponent.hasPrefix("x-") }))
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: capsule)) as? [String: Any])
        object["ownerId"] = "owner-B"
        try JSONSerialization.data(withJSONObject: object).write(to: capsule)
        XCTAssertThrowsError(
            try store.active(ownerId: "owner-A", apiScope: fixture.snapshot.apiScope)
        ) {
            XCTAssertEqual($0 as? RuntimeStoreError, .corruptState)
        }
        try Data("broken".utf8).write(to: root.appendingPathComponent("state.json"))
        XCTAssertThrowsError(
            try store.active(ownerId: "absent", apiScope: fixture.snapshot.apiScope)
        ) {
            XCTAssertEqual($0 as? RuntimeStoreError, .corruptState)
        }
    }

    func testSymlinksAndHardLinksCannotReadOrOverwriteAnOutsideFile() throws {
        let root = temporaryRoot()
        let outside = temporaryRoot()
        defer {
            XCTAssertNoThrow(try FileManager.default.removeItem(at: root))
            XCTAssertNoThrow(try FileManager.default.removeItem(at: outside))
        }
        let store = try RuntimeContentStore(root: root)
        let fixture = try RuntimeFixture()
        let outsideBytes = Data("outside sentinel".utf8)
        try outsideBytes.write(to: outside)
        let target = root.appendingPathComponent(
            "b-\(fixture.snapshot.manifest.files[0].hash).json")
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: outside)
        XCTAssertThrowsError(try store.cachedFile(fixture.snapshot.manifest.files[0])) {
            XCTAssertEqual($0 as? RuntimeStoreError, .unsafeDiskEntry)
        }
        XCTAssertThrowsError(
            try store.saveFile(fixture.files[0], file: fixture.snapshot.manifest.files[0]))
        XCTAssertEqual(try Data(contentsOf: outside), outsideBytes)
        try FileManager.default.removeItem(at: target)
        try FileManager.default.linkItem(at: outside, to: target)
        XCTAssertThrowsError(try store.cachedFile(fixture.snapshot.manifest.files[0])) {
            XCTAssertEqual($0 as? RuntimeStoreError, .unsafeDiskEntry)
        }
    }

    func testCapacityAndDiskFailureKeepThePreviouslyActivatedSnapshot() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let initial = try RuntimeContentStore(root: root)
        let fixture = try RuntimeFixture()
        try fixture.activate(initial)
        let limited = try RuntimeContentStore(root: root, maximumBytes: 1)
        XCTAssertThrowsError(try RuntimeFixture(version: 1).activate(limited)) {
            XCTAssertEqual($0 as? RuntimeStoreError, .capacity)
        }
        let failing = try RuntimeContentStore(root: root) { point, name in
            if point == .beforeRename, name == "state.json" { throw RuntimeStoreError.io(EIO) }
        }
        XCTAssertThrowsError(try RuntimeFixture(version: 1).activate(failing)) {
            XCTAssertEqual($0 as? RuntimeStoreError, .io(EIO))
        }
        XCTAssertEqual(
            try initial.active(ownerId: "owner-A", apiScope: fixture.snapshot.apiScope)?.binding,
            fixture.snapshot.binding)
    }

    func testNewerStagingInvalidatesOldActivationWithoutChangingActive() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let first = try RuntimeFixture()
        try first.activate(store)
        let stage = try store.begin(RuntimeFixture(version: 1).snapshot)
        _ = try store.begin(RuntimeFixture(version: 2).snapshot)
        XCTAssertThrowsError(try store.activate(stage)) {
            XCTAssertEqual($0 as? RuntimeStoreError, .staleActivation)
        }
        XCTAssertEqual(
            try store.active(ownerId: "owner-A", apiScope: first.snapshot.apiScope)?.binding,
            first.snapshot.binding)
    }

    #if os(Linux) || os(macOS)
        func testProcessDeathBeforeAndAfterAtomicActivationRestartsConsistently() throws {
            if let root = ProcessInfo.processInfo.environment["CERTIGO_RUNTIME_CRASH_ROOT"] {
                let phase = ProcessInfo.processInfo.environment["CERTIGO_RUNTIME_CRASH_PHASE"]
                let fixture = try RuntimeFixture(version: 1)
                let store = try RuntimeContentStore(root: URL(fileURLWithPath: root))
                let stage = try store.begin(fixture.snapshot)
                for index in fixture.files.indices {
                    try store.saveFile(
                        fixture.files[index], file: fixture.snapshot.manifest.files[index])
                }
                let crashing = try RuntimeContentStore(root: URL(fileURLWithPath: root)) {
                    point, name in
                    let selected =
                        phase == "before" ? point == .beforeRename : point == .afterRename
                    if selected, name == "state.json" { raise(SIGKILL) }
                }
                _ = try crashing.activate(stage)
                return XCTFail("Crash point did not kill the subprocess")
            }
            for phase in ["before", "after"] {
                let root = temporaryRoot()
                defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
                let old = try RuntimeFixture()
                try old.activate(RuntimeContentStore(root: root))
                let process = Process()
                process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
                let selection =
                    "CertigoKitTests.RuntimeStoreTests/testProcessDeathBeforeAndAfterAtomicActivationRestartsConsistently"
                #if os(macOS)
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                    process.arguments = [
                        "xctest", "-XCTest", selection,
                        Bundle(for: RuntimeStoreTests.self).bundleURL.path,
                    ]
                #else
                    process.arguments = [selection]
                #endif
                var environment = ProcessInfo.processInfo.environment
                environment["CERTIGO_RUNTIME_CRASH_ROOT"] = root.path
                environment["CERTIGO_RUNTIME_CRASH_PHASE"] = phase
                process.environment = environment
                let output = Pipe()
                process.standardOutput = output
                process.standardError = output
                try process.run()
                let deadline = Date().addingTimeInterval(15)
                while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
                if process.isRunning { process.terminate() }
                process.waitUntilExit()
                let diagnostics = String(
                    decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                XCTAssertEqual(process.terminationReason, .uncaughtSignal, diagnostics)
                XCTAssertEqual(process.terminationStatus, SIGKILL, diagnostics)
                let restarted = try RuntimeContentStore(root: root)
                let expected = try RuntimeFixture(version: phase == "before" ? 0 : 1)
                XCTAssertEqual(
                    try restarted.active(ownerId: "owner-A", apiScope: old.snapshot.apiScope)?
                        .binding, expected.snapshot.binding)
                let next = try RuntimeFixture(version: 1)
                XCTAssertEqual(
                    try restarted.cachedFile(next.snapshot.manifest.files[0]), next.files[0])
                try next.activate(restarted)
                XCTAssertEqual(
                    try restarted.active(ownerId: "owner-A", apiScope: old.snapshot.apiScope)?
                        .binding, next.snapshot.binding)
            }
        }
    #endif

    func testBoundedCleanupProtectsAllScopesPinsPreviousAndStagingButRemovesObsoleteData() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let first = try RuntimeFixture()
        try first.activate(store)
        try store.retainPins([
            RuntimeManifestPin(
                ownerId: "owner-A", apiScope: first.snapshot.apiScope,
                manifestId: first.snapshot.manifest.manifestId)
        ])
        for version in 1..<4 { try RuntimeFixture(version: version).activate(store) }
        let other = try RuntimeFixture(
            version: 5, owner: "owner-B", apiScope: "https://other.test/api")
        try other.activate(store)
        let pending = try RuntimeFixture(version: 4)
        let stage = try store.begin(pending.snapshot)
        try store.saveFile(pending.files[0], file: pending.snapshot.manifest.files[0])
        let deleted = try store.cleanup()
        XCTAssertGreaterThanOrEqual(deleted, 2)
        XCTAssertLessThanOrEqual(deleted, 32)
        XCTAssertEqual(try store.cachedFile(first.snapshot.manifest.files[0]), first.files[0])
        let obsolete = try RuntimeFixture(version: 1)
        XCTAssertNil(try store.cachedFile(obsolete.snapshot.manifest.files[0]))
        XCTAssertEqual(
            try store.previous(ownerId: "owner-A", apiScope: first.snapshot.apiScope)?.binding,
            try RuntimeFixture(version: 2).snapshot.binding)
        XCTAssertEqual(
            try store.active(ownerId: "owner-B", apiScope: other.snapshot.apiScope)?.binding,
            other.snapshot.binding)
        XCTAssertEqual(try store.activate(stage).binding, pending.snapshot.binding)
    }

    func testMissingArchiveWithExistingSnapshotsIsCorruptionNotANewEmptyCache() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let fixture = try RuntimeFixture()
        try fixture.activate(store)
        try FileManager.default.removeItem(at: root.appendingPathComponent("state.json"))
        XCTAssertThrowsError(
            try store.active(ownerId: "owner-A", apiScope: fixture.snapshot.apiScope)
        ) {
            XCTAssertEqual($0 as? RuntimeStoreError, .corruptState)
        }
        XCTAssertThrowsError(try store.cleanup()) {
            XCTAssertEqual($0 as? RuntimeStoreError, .corruptState)
        }
    }

    func testCleanupReallyStopsAtThirtyTwoFilesIncludingInterruptedTemporaryWrites() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let store = try RuntimeContentStore(root: root)
        let fixture = try RuntimeFixture()
        try fixture.activate(store)
        for _ in 0..<40 {
            try Data([0x20]).write(to: root.appendingPathComponent(".tmp-\(UUID().uuidString)"))
        }
        XCTAssertEqual(try store.cleanup(), 32)
        let remaining = try FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix(".tmp-") }
        XCTAssertEqual(remaining.count, 8)
        XCTAssertEqual(try store.cleanup(), 8)
        XCTAssertEqual(
            try store.active(ownerId: "owner-A", apiScope: fixture.snapshot.apiScope)?.binding,
            fixture.snapshot.binding)
    }

    func testBusyDirectoryTransactionIsRejectedRatherThanOverlappingAnotherWriter() throws {
        let root = temporaryRoot()
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: root)) }
        let disk = try RuntimeDisk(root: root, maximumBytes: 384 * 1_024 * 1_024)
        let store = try RuntimeContentStore(root: root)
        let fixture = try RuntimeFixture()
        try disk.exclusive {
            XCTAssertThrowsError(try fixture.activate(store)) {
                XCTAssertEqual($0 as? RuntimeStoreError, .busy)
            }
        }
        try fixture.activate(store)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "certigo-runtime-\(UUID().uuidString)")
    }

    func testMissingNestedRootIsCreatedAtTheExactRequestedPathThroughAnExistingAlias() throws {
        let parent = temporaryRoot()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: parent)) }
        let target = parent.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let alias = parent.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        let root = alias.appendingPathComponent("missing", isDirectory: true)
            .appendingPathComponent("cache", isDirectory: true)
        let foundationBeforeCreation = root.resolvingSymlinksInPath().path
        let name = "b-\(String(repeating: "a", count: 64)).json"
        let disk = try RuntimeDisk(root: root, maximumBytes: 1_024)
        try disk.exclusive { try disk.write(Data([0x42]), name: name) }
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(name)), Data([0x42]))
        XCTAssertEqual(
            try Data(
                contentsOf: target.appendingPathComponent("missing/cache").appendingPathComponent(
                    name)),
            Data([0x42]))
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: target.appendingPathComponent(name).path))
        print(
            "Foundation preserved missing alias suffix: \(foundationBeforeCreation == root.resolvingSymlinksInPath().path)"
        )
    }

    func testRootSymlinkAndDanglingAncestorAreRejectedWithoutCreatingTheirDestination() throws {
        let parent = temporaryRoot()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: false)
        defer { XCTAssertNoThrow(try FileManager.default.removeItem(at: parent)) }
        let target = parent.appendingPathComponent("target", isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        let alias = parent.appendingPathComponent("alias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: target)
        XCTAssertThrowsError(try RuntimeDisk(root: alias, maximumBytes: 1_024)) {
            XCTAssertEqual($0 as? RuntimeStoreError, .unsafeDiskEntry)
        }
        let absent = parent.appendingPathComponent("absent", isDirectory: true)
        let dangling = parent.appendingPathComponent("dangling", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: dangling, withDestinationURL: absent)
        XCTAssertThrowsError(
            try RuntimeDisk(root: dangling.appendingPathComponent("cache"), maximumBytes: 1_024)
        ) {
            XCTAssertEqual($0 as? RuntimeStoreError, .unsafeDiskEntry)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: absent.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.path), [])
    }
}
