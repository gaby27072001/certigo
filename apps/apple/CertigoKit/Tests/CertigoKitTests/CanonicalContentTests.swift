import CertigoData
import Foundation
import XCTest

final class CanonicalContentTests: XCTestCase {
    func testProducerVectorsKeepWireVariantsAndCapabilityOutcomesSeparate() throws {
        let suite = try expectations()
        XCTAssertEqual(suite.suite, "certigo.apple-compat/v1")
        XCTAssertEqual(suite.capabilityProfile.id, "apple-basic-v1")
        XCTAssertEqual(suite.capabilityProfile.supportedItemTypes, ["mcq"])
        for vector in suite.vectors {
            let question = try CanonicalQuestionReader.decode(resource(vector.file))
            XCTAssertEqual(question.schemaVersion, vector.schemaVersion, vector.file)
            XCTAssertEqual(vector.contract, "valid")
            if vector.client == "supported" {
                XCTAssertNoThrow(try question.requireBasicCapability(), vector.file)
            } else {
                XCTAssertEqual(vector.client, "unsupported-capability")
                XCTAssertEqual(vector.notMalformed, true)
                XCTAssertThrowsError(try question.requireBasicCapability()) {
                    XCTAssertEqual(
                        $0 as? CanonicalContentError,
                        .unsupportedCapability(vector.requiredCapability ?? ""), vector.file
                    )
                }
            }
            switch question.options {
            case .legacyChoices(let choices):
                XCTAssertEqual(question.schemaVersion, "v3")
                XCTAssertEqual(choices.count, 4)
                XCTAssertNil(question.metadata.conceptId)
                XCTAssertNil(question.difficulty)
            case .identified(let options):
                XCTAssertEqual(question.schemaVersion, "v4")
                XCTAssertNotNil(question.metadata.conceptId)
                XCTAssertFalse(options.isEmpty)
            }
        }
    }

    func testRealSHA256MatchesEveryProducerCanonicalBodyAndLFPackageVector() throws {
        let suite = try expectations()
        XCTAssertEqual(suite.canonicalization, "json-sorted-keys-compact-utf8")
        XCTAssertEqual(suite.packageSerialization, "json-sorted-keys-compact-utf8-lf")
        for vector in suite.vectors {
            let source = try resource(vector.file)
            let body = try CanonicalQuestionReader.canonicalBody(source)
            let file = try CanonicalQuestionReader.packageFile(source)
            XCTAssertEqual(file, body + Data([0x0A]), vector.file)
            let bodyDigest = try CanonicalQuestionReader.digest(body)
            let fileDigest = try CanonicalQuestionReader.digest(file)
            XCTAssertEqual(bodyDigest.size, vector.payloadDigests.canonicalBody.size, vector.file)
            XCTAssertEqual(
                bodyDigest.sha256, vector.payloadDigests.canonicalBody.sha256, vector.file)
            XCTAssertEqual(fileDigest.size, vector.payloadDigests.packageFile.size, vector.file)
            XCTAssertEqual(fileDigest.sha256, vector.payloadDigests.packageFile.sha256, vector.file)
            XCTAssertNoThrow(
                try CanonicalQuestionReader.verifyFile(
                    file, size: vector.payloadDigests.packageFile.size,
                    sha256: vector.payloadDigests.packageFile.sha256
                ), vector.file
            )
            XCTAssertThrowsError(
                try CanonicalQuestionReader.verifyFile(
                    body, size: vector.payloadDigests.packageFile.size,
                    sha256: vector.payloadDigests.packageFile.sha256
                ), vector.file
            )
        }
    }

    func testProducerNegativeMutationsAreMalformedBeforeCapabilityHandling() throws {
        let suite = try expectations()
        for vector in suite.vectors {
            let source = try resource(vector.file)
            for negative in suite.negativeCases {
                XCTAssertEqual(negative.expected, "malformed")
                XCTAssertFalse(negative.schemaValid)
                let key = try XCTUnwrap(
                    negative.mutation.addProperty ?? negative.mutation.addForbiddenProperty
                )
                let malformed = try mutate(source) { $0[key] = [] as [String] }
                XCTAssertThrowsError(try CanonicalQuestionReader.decode(malformed)) {
                    XCTAssertEqual($0 as? CanonicalContentError, .malformed, negative.id)
                }
                XCTAssertThrowsError(try CanonicalQuestionReader.canonicalBody(malformed))
            }
        }
    }

    func testFutureSchemaIsUnsupportedButInvalidKnownTypeIsMalformed() throws {
        let source = try resource("supported/question-v4-mcq.json")
        let future = try mutate(source) { $0["schemaVersion"] = "v999" }
        XCTAssertThrowsError(try CanonicalQuestionReader.decode(future)) {
            XCTAssertEqual($0 as? CanonicalContentError, .unsupportedSchema("v999"))
        }
        let invalid = try mutate(source) { $0["itemType"] = "not-a-v4-type" }
        XCTAssertThrowsError(try CanonicalQuestionReader.decode(invalid)) {
            XCTAssertEqual($0 as? CanonicalContentError, .malformed)
        }
        for type in ["multi", "scenario", "spotTheIssue"] {
            let payload = try mutate(source) { $0["itemType"] = type }
            let question = try CanonicalQuestionReader.decode(payload)
            XCTAssertThrowsError(try question.requireBasicCapability()) {
                XCTAssertEqual(
                    $0 as? CanonicalContentError, .unsupportedCapability("itemType:\(type)"))
            }
        }
    }

    func testMalformedNestedKeysAndNumbersCannotPassAsPublicQuestions() throws {
        let source = try resource("supported/question-v4-mcq.json")
        let invalidValues: [Any] = [
            true, 0, 4, 1.5, "2", NSNull(), NSDecimalNumber(string: "18446744073709551617"),
        ]
        for difficulty in invalidValues {
            let malformed = try mutate(source) { $0["difficulty"] = difficulty }
            XCTAssertThrowsError(try CanonicalQuestionReader.decode(malformed)) {
                XCTAssertEqual($0 as? CanonicalContentError, .malformed)
            }
        }
        let nestedLeak = try mutate(source) { root in
            var metadata = try XCTUnwrap(root["metadata"] as? [String: Any])
            metadata["correctOptionIds"] = [] as [String]
            root["metadata"] = metadata
        }
        XCTAssertThrowsError(try CanonicalQuestionReader.decode(nestedLeak)) {
            XCTAssertEqual($0 as? CanonicalContentError, .malformed)
        }
        for bytes in [Data("[]".utf8), Data("{".utf8), Data("null".utf8)] {
            XCTAssertThrowsError(try CanonicalQuestionReader.decode(bytes)) {
                XCTAssertEqual($0 as? CanonicalContentError, .malformed)
            }
        }
    }

    func testInvalidHashOrChangedBytesNeverPassIntegrityAndPayloadLimitIsEnforced() throws {
        let source = try resource("supported/question-v3.json")
        let file = try CanonicalQuestionReader.packageFile(source)
        let expected = try CanonicalQuestionReader.digest(file)
        var damaged = file
        damaged[0] ^= 0x01
        XCTAssertThrowsError(
            try CanonicalQuestionReader.verifyFile(
                damaged, size: expected.size, sha256: expected.sha256)
        ) { XCTAssertEqual($0 as? CanonicalContentError, .integrityMismatch) }
        XCTAssertThrowsError(
            try CanonicalQuestionReader.verifyFile(file, size: expected.size, sha256: "not-a-hash")
        )
        let oversized = Data(
            repeating: 0x20, count: CanonicalQuestionReader.maximumPayloadBytes + 1)
        XCTAssertThrowsError(try CanonicalQuestionReader.decode(oversized)) {
            XCTAssertEqual($0 as? CanonicalContentError, .payloadTooLarge)
        }
        XCTAssertThrowsError(try CanonicalQuestionReader.digest(oversized)) {
            XCTAssertEqual($0 as? CanonicalContentError, .payloadTooLarge)
        }
    }

    private func resource(_ path: String) throws -> Data {
        let base = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try Data(contentsOf: base.appendingPathComponent("apple-compat/v1/\(path)"))
    }

    private func expectations() throws -> Expectations {
        try JSONDecoder().decode(Expectations.self, from: resource("expected-outcomes.json"))
    }

    private func mutate(
        _ data: Data, mutation: (inout [String: Any]) throws -> Void
    ) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        try mutation(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
private struct Expectations: Decodable {
    let suite, canonicalization, packageSerialization: String
    let capabilityProfile: Profile
    let vectors: [Vector]
    let negativeCases: [Negative]

    struct Profile: Decodable {
        let id: String
        let supportedItemTypes: [String]
    }

    struct Vector: Decodable {
        let file, schemaVersion, contract, client: String
        let requiredCapability: String?
        let notMalformed: Bool?
        let payloadDigests: PayloadDigests
    }

    struct PayloadDigests: Decodable { let canonicalBody, packageFile: Digest }
    struct Digest: Decodable {
        let size: Int
        let sha256: String
    }

    struct Negative: Decodable {
        let id, expected: String
        let mutation: Mutation
        let schemaValid: Bool
    }

    struct Mutation: Decodable {
        let addProperty: String?
        let addForbiddenProperty: String?
    }
}
