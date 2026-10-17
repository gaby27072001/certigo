import CertigoData
import Foundation
import XCTest

final class PublicReleaseContractTests: XCTestCase {
    private let manifestId =
        "sha256:248eb967705fb7126a7eaf159a68ac9b51c61ff8170b2ed6b62ae7c036f350c0"
    private let releaseId =
        "sha256:92bde38713c6a4671428994a32b85ea385904a509efe818d85ccf7b430962a66"
    private let otherId = "sha256:" + String(repeating: "a", count: 64)

    func testV3ManifestBodyDigestIsIndependentOfSerializedManifestFileBytes() throws {
        let bytes = try fixture("manifest-v3")
        let manifest = try PublicReleaseContracts.manifest(bytes)
        XCTAssertEqual(manifest.manifestId, manifestId)
        XCTAssertNil(manifest.releaseId)
        XCTAssertEqual(manifest.files.count, 2)
        XCTAssertEqual(manifest.totalBytes, 1_323)
        XCTAssertNotEqual(
            "sha256:" + (try CanonicalQuestionReader.digest(bytes).sha256), manifestId)
        for file in manifest.files {
            let producerPath =
                file.id.hasPrefix("aws") ? "supported/question-v3" : "supported/question-v4-mcq"
            let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
            let producer = try Data(
                contentsOf: root.appendingPathComponent("apple-compat/v1/\(producerPath).json"))
            let payload = try CanonicalQuestionReader.packageFile(producer)
            XCTAssertNoThrow(
                try CanonicalQuestionReader.verifyFile(payload, size: file.size, sha256: file.hash))
        }
    }

    func testReleaseIDExclusionDoesNotAuthenticateItsBindingToTheResponse() throws {
        let first = try activeManifest(release: releaseId)
        let changed = try activeManifest(release: otherId)
        XCTAssertEqual(first.manifestId, changed.manifestId)
        XCTAssertNoThrow(
            try PublicReleaseContracts.bind(
                first, releaseId: releaseId, manifestId: manifestId, etag: "\"\(manifestId)\""
            )
        )
        XCTAssertThrowsError(
            try PublicReleaseContracts.bind(
                changed, releaseId: releaseId, manifestId: manifestId, etag: "\"\(manifestId)\""
            )
        ) { XCTAssertEqual($0 as? PublicReleaseError, .provenance) }
        XCTAssertThrowsError(
            try PublicReleaseContracts.bind(
                first, releaseId: releaseId, manifestId: otherId, etag: "\"\(otherId)\""
            )
        )
    }

    func testManifestAndRootHashAreExcludedButRecomputedRatherThanTrusted() throws {
        for key in ["manifestId", "rootHash"] {
            let value = key == "manifestId" ? otherId : String(repeating: "a", count: 64)
            let changed = try mutate(fixture("manifest-v3")) { $0[key] = value }
            XCTAssertThrowsError(try PublicReleaseContracts.manifest(changed)) {
                XCTAssertEqual($0 as? PublicReleaseError, .integrity)
            }
        }
        let changed = try mutate(fixture("manifest-v3")) { $0["fileCount"] = 3 }
        XCTAssertThrowsError(try PublicReleaseContracts.manifest(changed))
    }

    func testPrivateDescriptorIdentityIsAllowedOnlyInTheSeparateDescriptorContract() throws {
        let descriptor = try PublicReleaseContracts.descriptor(
            fixture("release-v1"), requestedReleaseId: releaseId
        )
        XCTAssertEqual(descriptor.publicManifestId, manifestId)
        XCTAssertEqual(descriptor.releaseId, releaseId)
        let publicLeak = try mutate(fixture("manifest-v3")) { $0["privateManifestId"] = otherId }
        XCTAssertThrowsError(try PublicReleaseContracts.manifest(publicLeak)) {
            XCTAssertEqual($0 as? PublicReleaseError, .malformed)
        }
        let changed = try mutate(fixture("release-v1")) { $0["privateManifestId"] = otherId }
        XCTAssertThrowsError(
            try PublicReleaseContracts.descriptor(changed, requestedReleaseId: releaseId)
        ) { XCTAssertEqual($0 as? PublicReleaseError, .integrity) }
    }

    func testPathsRejectTraversalEscapesControlsAndPrivateNamespaces() throws {
        for path in [
            "/questions/a.json", "questions/../a.json", "questions/./a.json",
            "questions//a.json", "questions\\a.json", "questions/%2e%2e/a.json",
            "questions/a.json\n", "solutions/a.json",
        ] {
            let data = try mutate(fixture("manifest-v3")) { root in
                var files = try XCTUnwrap(root["files"] as? [[String: Any]])
                files[0]["path"] = path
                root["files"] = files
            }
            XCTAssertThrowsError(try PublicReleaseContracts.manifest(data), path)
        }
    }

    func testDuplicateIDsPathsNullOptionalsAndUnsafeSizesAreRejectedBeforeDigestVerification()
        throws
    {
        for field in ["id", "path"] {
            let changed = try mutate(fixture("manifest-v3")) { root in
                var files = try XCTUnwrap(root["files"] as? [[String: Any]])
                files[1][field] = files[0][field]
                root["files"] = files
            }
            XCTAssertThrowsError(try PublicReleaseContracts.manifest(changed)) {
                XCTAssertEqual($0 as? PublicReleaseError, .malformed)
            }
        }
        let changed = try mutate(fixture("manifest-v3")) { root in
            var files = try XCTUnwrap(root["files"] as? [[String: Any]])
            files[0]["provider"] = NSNull()
            root["files"] = files
        }
        XCTAssertThrowsError(try PublicReleaseContracts.manifest(changed)) {
            XCTAssertEqual($0 as? PublicReleaseError, .malformed)
        }
        for size in [0, PublicReleaseContracts.maximumFileBytes + 1] {
            let changed = try mutate(fixture("manifest-v3")) { root in
                var files = try XCTUnwrap(root["files"] as? [[String: Any]])
                files[0]["size"] = size
                root["files"] = files
            }
            XCTAssertThrowsError(try PublicReleaseContracts.manifest(changed))
        }
    }

    func testUnsupportedSchemasAndResourcesDoNotFallBackToLegacy() throws {
        let changed = try mutate(fixture("manifest-v3")) {
            $0["schema"] = "certigo.content.package-manifest/v999"
        }
        XCTAssertThrowsError(try PublicReleaseContracts.manifest(changed)) {
            XCTAssertEqual($0 as? PublicReleaseError, .unsupportedSchema)
        }
        let unsupported = try mutate(fixture("manifest-v3")) { root in
            var files = try XCTUnwrap(root["files"] as? [[String: Any]])
            files[0]["resourceType"] = "unknown"
            root["files"] = files
        }
        XCTAssertThrowsError(try PublicReleaseContracts.manifest(unsupported)) {
            XCTAssertEqual($0 as? PublicReleaseError, .unsupportedResource("unknown"))
        }
    }

    func testManifestByteCountAndFileCountLimitsAreRealBounds() throws {
        XCTAssertThrowsError(
            try PublicReleaseContracts.manifest(
                Data(repeating: 0x20, count: PublicReleaseContracts.maximumManifestBytes + 1)
            )
        ) { XCTAssertEqual($0 as? PublicReleaseError, .limitExceeded) }
        let excessive = try mutate(fixture("manifest-v3")) {
            $0["fileCount"] = PublicReleaseContracts.maximumFiles + 1
        }

        XCTAssertThrowsError(try PublicReleaseContracts.manifest(excessive)) {
            XCTAssertEqual($0 as? PublicReleaseError, .limitExceeded)
        }
    }

    func testAggregateReleaseQuotaIsCheckedWithoutOverflowBeforeHashing() throws {
        let excessive = try mutate(fixture("manifest-v3")) { root in
            let original = try XCTUnwrap((root["files"] as? [[String: Any]])?.first)
            let count =
                PublicReleaseContracts.maximumReleaseBytes
                / PublicReleaseContracts.maximumFileBytes + 1
            root["files"] = (0..<count).map { index in
                var file = original
                file["id"] = "synthetic-\(index)"
                file["path"] = "questions/synthetic-\(index).json"
                file["size"] = PublicReleaseContracts.maximumFileBytes
                return file
            }
            root["fileCount"] = count
        }
        XCTAssertThrowsError(try PublicReleaseContracts.manifest(excessive)) {
            XCTAssertEqual($0 as? PublicReleaseError, .limitExceeded)
        }
    }

    private func activeManifest(release: String) throws -> PublicPackageManifest {
        try PublicReleaseContracts.manifest(
            mutate(fixture("manifest-v3")) { $0["releaseId"] = release })
    }

    private func fixture(_ name: String) throws -> Data {
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try Data(contentsOf: root.appendingPathComponent("runtime/\(name).json"))
    }

    private func mutate(
        _ data: Data, mutation: (inout [String: Any]) throws -> Void
    ) throws -> Data {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        try mutation(&root)
        return try JSONSerialization.data(
            withJSONObject: root, options: [.sortedKeys, .withoutEscapingSlashes])
    }
}
