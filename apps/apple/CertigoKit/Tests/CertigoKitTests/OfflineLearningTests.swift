import CertigoDomain
import Foundation
import XCTest

@testable import CertigoData

final class OfflineLearningTests: XCTestCase {
    func testAuthoredFixtureResolvesBlocksAndRejectsCrossBlueprintQuestion() throws {
        let resources = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let fixture = try OfflinePackFixture(resources: resources, guided: true)
        let manifest = try PublicReleaseContracts.manifest(fixture.manifest)
        let binding = try PublicReleaseContracts.bind(
            manifest, releaseId: fixture.releaseId, manifestId: manifest.manifestId,
            etag: "\"\(manifest.manifestId)\"")
        let snapshot = RuntimeContentSnapshot(
            ownerId: "owner-A", apiScope: "https://certigo.test/api",
            manifest: manifest, binding: binding)
        let pack = try XCTUnwrap(
            OfflineQuestionPackReader.read(
                trackId: "fixture-track", snapshot: snapshot
            ) { file in
                let bytes = try XCTUnwrap(fixture.files[file.path])
                try PublicResourceReader.validate(bytes, file: file)
                return bytes
            })
        XCTAssertEqual(pack.lessons.first?.id, "synthetic-guided-lesson")
        XCTAssertEqual(pack.lessons.first?.blocks.first?.body, "Synthetic public teaching text.")
        XCTAssertEqual(pack.lessons.first?.questions.first?.id, "az900-l-cloud-models-check-1")
        XCTAssertThrowsError(
            try OfflineQuestionPackReader.read(
                trackId: "fixture-track", snapshot: snapshot
            ) { file in
                let bytes = try XCTUnwrap(fixture.files[file.path])
                if file.resourceType != "question" { return bytes }
                var object = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: bytes) as? [String: Any])
                var metadata = try XCTUnwrap(object["metadata"] as? [String: Any])
                metadata["blueprintVersion"] = "unexpected-version"
                object["metadata"] = metadata
                return try JSONSerialization.data(withJSONObject: object)
            })
    }

    func testLegacyV3OptionsUseServerAdapterIDsNotChoiceIndexes() async throws {
        let resources = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let fixture = try OfflinePackFixture(resources: resources, legacyChoices: true)
        let manifest = try PublicReleaseContracts.manifest(fixture.manifest)
        let binding = try PublicReleaseContracts.bind(
            manifest, releaseId: fixture.releaseId, manifestId: manifest.manifestId,
            etag: "\"\(manifest.manifestId)\"")
        let pack = try XCTUnwrap(
            OfflineQuestionPackReader.read(
                trackId: "fixture-track",
                snapshot: RuntimeContentSnapshot(
                    ownerId: "owner-A", apiScope: "https://certigo.test/api",
                    manifest: manifest, binding: binding)
            ) { try XCTUnwrap(fixture.files[$0.path]) })
        let question = try XCTUnwrap(pack.lessons.first?.questions.first)
        XCTAssertEqual(question.id, "microsoft.az-900.section-1.cloud-models.001")
        XCTAssertEqual(question.conceptId, "fixture-concept")
        let hash = try CanonicalQuestionReader.digest(Data("PaaS".utf8)).sha256.prefix(8)
        XCTAssertEqual(question.options[1].id, "paas-\(hash)")
        XCTAssertEqual(question.options[1].label, "PaaS")
    }

    func testQuestionPackMatchesServerProjectionAndSurvivesRotationWithExactPin() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = try RuntimeContentStore(root: root)
        let resources = try XCTUnwrap(
            Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        func activate(_ fixture: OfflinePackFixture) throws -> PublicPackageManifest {
            let manifest = try PublicReleaseContracts.manifest(fixture.manifest)
            let binding = try PublicReleaseContracts.bind(
                manifest, releaseId: fixture.releaseId, manifestId: manifest.manifestId,
                etag: "\"\(manifest.manifestId)\"")
            let stage = try cache.begin(
                RuntimeContentSnapshot(
                    ownerId: "owner-A", apiScope: "https://certigo.test/api",
                    manifest: manifest, binding: binding))
            for file in manifest.files {
                try cache.saveFile(XCTUnwrap(fixture.files[file.path]), file: file)
            }
            _ = try cache.activate(stage)
            return manifest
        }
        let original = try activate(OfflinePackFixture(resources: resources))
        let pack = try XCTUnwrap(
            cache.questionPack(
                trackId: "fixture-track", ownerId: "owner-A", apiScope: "https://certigo.test/api"))
        let lesson = try XCTUnwrap(pack.lessons.first)
        XCTAssertEqual(lesson.id, "fixture-track.lesson.section-1.practice")
        XCTAssertEqual(lesson.publicManifestId, original.manifestId)
        XCTAssertEqual(lesson.questions.first?.id, "az900-l-cloud-models-check-1")
        XCTAssertEqual(lesson.questions.first?.conceptId, "fixture-concept")
        XCTAssertEqual(
            lesson.questions.first?.options.map(\.id), ["iaas", "paas", "saas", "on-premises"])
        try cache.retainPins([
            RuntimeManifestPin(
                ownerId: "owner-A", apiScope: "https://certigo.test/api",
                manifestId: original.manifestId)
        ])
        _ = try activate(OfflinePackFixture(resources: resources, revision: 1))
        _ = try activate(OfflinePackFixture(resources: resources, revision: 2))
        _ = try cache.cleanup()
        let reopened = try RuntimeContentStore(root: root)
        let pinned = try XCTUnwrap(
            reopened.questionPack(
                trackId: "fixture-track", ownerId: "owner-A", apiScope: "https://certigo.test/api",
                manifestId: original.manifestId))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(try encoder.encode(pinned.lessons.first), try encoder.encode(lesson))
        XCTAssertThrowsError(
            try reopened.questionPack(
                trackId: "fixture-track", ownerId: "owner-B", apiScope: "https://certigo.test/api",
                manifestId: original.manifestId))
        let entry = try XCTUnwrap(original.files.first(where: { $0.resourceType == "question" }))
        let blob = root.appendingPathComponent("b-\(entry.hash).json")
        try Data("damaged".utf8).write(to: blob)
        XCTAssertThrowsError(
            try reopened.questionPack(
                trackId: "fixture-track", ownerId: "owner-A", apiScope: "https://certigo.test/api",
                manifestId: original.manifestId))
    }

    func testCachedReaderIsScopedAndRequiresExactPinnedManifest() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = try RuntimeContentStore(root: root)
        let fixture = try RuntimeFixture()
        try fixture.activate(cache)
        XCTAssertNil(
            try cache.questionPack(
                trackId: "not-present", ownerId: "owner-B", apiScope: fixture.snapshot.apiScope))
        XCTAssertNil(
            try cache.questionPack(
                trackId: "not-present", ownerId: "owner-A", apiScope: "https://other.test/api"))
        XCTAssertThrowsError(
            try cache.questionPack(
                trackId: "not-present", ownerId: "owner-A", apiScope: fixture.snapshot.apiScope,
                manifestId: "sha256:" + String(repeating: "f", count: 64)))
        XCTAssertNil(
            try cache.questionPack(
                trackId: "not-present", ownerId: "owner-A", apiScope: fixture.snapshot.apiScope))
    }
}
