import Foundation
import XCTest

@testable import CertigoData

final class PublicResourceTests: XCTestCase {
    func testAllFiveClosedRuntimeFormsAndQuestionBankModeAreValidated() throws {
        for type in ["track", "domain", "unit", "lesson", "concept"] {
            XCTAssertNoThrow(try validate(runtime(type), type: type), type)
        }
        var guided = runtime("track")
        guided["mode"] = "guided"
        guided["unitIds"] = [id("unit")]
        XCTAssertNoThrow(try validate(guided, type: "track"))
        guided["unitIds"] = []
        XCTAssertThrowsError(try validate(guided, type: "track"))
        var bank = runtime("track")
        bank["unitIds"] = [id("unit")]
        XCTAssertThrowsError(try validate(bank, type: "track"))
    }

    func testRuntimeBlocksDoNotEmbedCorrectionKeysOrInlineVerdicts() throws {
        for key in ["correct", "correctOptionIds", "privateManifestId", "explanation", "rationale"]
        {
            var root = runtime("lesson")
            var blocks = try XCTUnwrap(root["blocks"] as? [[String: Any]])
            blocks[1][key] = ["synthetic"]
            root["blocks"] = blocks
            XCTAssertThrowsError(try validate(root, type: "lesson")) {
                XCTAssertEqual($0 as? PublicReleaseError, .malformed)
            }
        }
        var root = runtime("lesson")
        var blocks = try XCTUnwrap(root["blocks"] as? [[String: Any]])
        blocks[1]["body"] = "Check must reference a question, not contain a lesson body"
        root["blocks"] = blocks
        XCTAssertThrowsError(try validate(root, type: "lesson"))
    }

    func testCoverageUsesItsOwnIdentityClosedObjectivesAndNumericWeights() throws {
        var root: [String: Any] = [
            "schema": "certigo.coverage-matrix/v1", "provider": "microsoft",
            "certification": "microsoft:azure-fundamentals", "blueprintVersion": "2026-09",
            "status": "planned",
            "objectives": [
                [
                    "objective": "domain-1", "title": "Synthetic objective", "weightPercent": 50.5,
                    "weightType": "approximate", "questionIds": [],
                ] as [String: Any]
            ],
        ]
        XCTAssertNoThrow(try validate(root, type: "coverageMatrix"))
        root["objectives"] = [
            [
                "objective": "domain-1", "title": "Synthetic objective", "weightPercent": true,
                "weightType": "approximate", "questionIds": [],
            ] as [String: Any]
        ]
        XCTAssertThrowsError(try validate(root, type: "coverageMatrix"))
    }

    func testCatalogExplicitNullableFieldsAreValidAndLifecycleDatesAreStrict() throws {
        let root = catalog()
        XCTAssertNoThrow(try validate(root, type: "certificationCatalog"))
        var bad = root
        bad["asOf"] = "2026-02-30"
        XCTAssertThrowsError(try validate(bad, type: "certificationCatalog"))
        var certifications = try XCTUnwrap(root["certifications"] as? [[String: Any]])
        var guide = try XCTUnwrap(certifications[0]["guide"] as? [String: Any])
        guide["versionSource"] = "unknown"
        certifications[0]["guide"] = guide
        bad = root
        bad["certifications"] = certifications
        XCTAssertThrowsError(try validate(bad, type: "certificationCatalog"))
    }

    func testRuntimeUnsupportedSchemaIdentityAndRequiredLifecycleFieldsAreDistinct() throws {
        var root = runtime("concept")
        root["schema"] = "certigo.runtime.concept/v99"
        XCTAssertThrowsError(try validate(root, type: "concept")) {
            XCTAssertEqual($0 as? PublicReleaseError, .unsupportedSchema)
        }
        root = runtime("concept")
        root["lifecycle"] = ["status": "retired"]
        XCTAssertThrowsError(try validate(root, type: "concept"))
        root["lifecycle"] = ["status": "retired", "retiredOn": "2026-10-13"]
        XCTAssertNoThrow(try validate(root, type: "concept"))
        root["lifecycle"] = ["status": "replaced"]
        XCTAssertThrowsError(try validate(root, type: "concept"))
        root["lifecycle"] = ["status": "replaced", "replacedBy": id("concept")]
        XCTAssertNoThrow(try validate(root, type: "concept"))
    }

    func testUnsupportedExercisesStayUnsupportedAtStagingRatherThanBecomingMCQ() throws {
        let root = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(
            contentsOf: root.appendingPathComponent(
                "apple-compat/v1/capability-probes/question-v4-spot-the-issue.json"))
        let question = try CanonicalQuestionReader.decode(bytes)
        let digest = try CanonicalQuestionReader.digest(bytes)
        let file = PublicPackageFile(
            id: question.id, path: "questions/synthetic.json",
            resourceType: "question", hash: digest.sha256, size: digest.size)
        XCTAssertThrowsError(try PublicResourceReader.validate(bytes, file: file)) {
            XCTAssertEqual(
                $0 as? CanonicalContentError, .unsupportedCapability("itemType:spotTheIssue"))
        }
        let mismatched = PublicPackageFile(
            id: "wrong-id", path: file.path,
            resourceType: file.resourceType, hash: file.hash, size: file.size)
        XCTAssertThrowsError(try PublicResourceReader.validate(bytes, file: mismatched)) {
            XCTAssertEqual($0 as? PublicReleaseError, .integrity)
        }
    }

    private func id(_ type: String) -> String { "microsoft.azure-fundamentals.\(type).intro" }

    private func runtime(_ type: String) -> [String: Any] {
        var root: [String: Any] = [
            "schema": "certigo.runtime.\(type)/v1", "resourceType": type, "id": id(type),
            "certificationId": "microsoft:azure-fundamentals", "blueprintVersion": "2026-09",
            "lifecycle": ["status": "active"],
        ]
        switch type {
        case "track":
            root["mode"] = "questionBank"
            root["summary"] = "Synthetic public bank"
            root["domainIds"] = [id("domain")]
            root["unitIds"] = []
        case "domain": root["objectiveId"] = "domain-1"
        case "unit":
            root["domainId"] = id("domain")
            root["title"] = "Synthetic unit"
            root["lessonIds"] = [id("lesson")]
        case "concept":
            root["domainId"] = id("domain")
            root["title"] = "Synthetic concept"
        case "lesson":
            root["unitId"] = id("unit")
            root["title"] = "Synthetic lesson"
            root["estimatedMinutes"] = 5
            root["blocks"] = [
                [
                    "id": "\(id("lesson")).block.001", "type": "hook", "conceptId": id("concept"),
                    "body": "Synthetic text",
                ],
                [
                    "id": "\(id("lesson")).block.002", "type": "check", "conceptId": id("concept"),
                    "questionId": "microsoft.azure-fundamentals.domain-1.intro.001",
                ],
            ]
        default: break
        }
        return root
    }

    private func catalog() -> [String: Any] {
        [
            "schema": "certigo.certification-catalog/v1", "asOf": "2026-10-13",
            "freshness": ["maxAgeDays": 30, "reviewDueOn": "2026-11-12"],
            "providers": ["aws", "gcp", "microsoft"].map {
                [
                    "id": $0, "name": $0, "namespace": $0, "officialCatalogUrl": NSNull(),
                    "sourceHosts": ["certigo.test"], "checkedOn": NSNull(),
                ] as [String: Any]
            },
            "certifications": [
                [
                    "id": "microsoft:azure-fundamentals", "provider": "microsoft",
                    "slug": "azure-fundamentals",
                    "officialCode": NSNull(), "officialSlug": "azure-fundamentals",
                    "title": "Synthetic certification",
                    "level": "foundational", "status": "active",
                    "officialUrl": "https://certigo.test/catalog",
                    "guide": [
                        "url": "https://certigo.test/guide", "version": NSNull(),
                        "publishedOn": NSNull(),
                        "versionSource": NSNull(), "revisionToken": NSNull(),
                    ] as [String: Any],
                    "blueprint": [
                        "version": "2026-09",
                        "objectives": [
                            [
                                "id": "domain-1", "title": "Synthetic domain", "weightPercent": 100,
                                "weightType": "exact",
                            ]
                        ],
                    ] as [String: Any],
                    "provenance": [
                        "checkedOn": "2026-10-13",
                        "sources": [
                            ["kind": "certification-page", "url": "https://certigo.test/catalog"],
                            ["kind": "exam-guide", "url": "https://certigo.test/guide"],
                        ],
                    ] as [String: Any],
                ] as [String: Any]
            ],
        ]
    }

    private func validate(_ root: [String: Any], type: String) throws {
        let bytes = try JSONSerialization.data(
            withJSONObject: root, options: [.sortedKeys, .withoutEscapingSlashes])
        let digest = try CanonicalQuestionReader.digest(bytes)
        let identity: String
        switch type {
        case "certificationCatalog": identity = "certification-catalog"
        case "coverageMatrix": identity = try XCTUnwrap(root["certification"] as? String)
        default: identity = try XCTUnwrap(root["id"] as? String)
        }
        let file = PublicPackageFile(
            id: identity, path: "unused-by-direct-payload-validator.json",
            resourceType: type, hash: digest.sha256, size: digest.size)
        try PublicResourceReader.validate(bytes, file: file)
    }
}
