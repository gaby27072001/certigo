import CertigoData
import Foundation
import XCTest

final class FlutterQueueDryRunTests: XCTestCase {
    private var entry: String {
        """
        {"id":"queue-entry-1","kind":"quizSubmit","endpoint":"/quiz/demo-lesson/submit",
         "idempotencyKey":"original-non-uuid-attempt","ownerId":"original-owner",
         "createdAt":"2026-10-01T12:00:01.123456Z","status":"pending","attempts":2,
         "nextAttemptAt":"2026-10-01T12:10:01.123456Z",
         "publicManifestId":"sha256:\(String(repeating: "a", count: 64))",
         "payload":{"clientAttemptId":"original-non-uuid-attempt","trackId":"legacy-track",
           "startedAt":"2026-10-01T12:00:00.123456Z",
           "publicManifestId":"sha256:\(String(repeating: "a", count: 64))",
           "answers":[{"itemId":"legacy-item","itemType":"mcq","selected":["b"],"latencyMs":4200}]}}
        """
    }

    private func inspect(_ entry: String, withProvenance: Bool = true) throws -> FlutterQueueDryRun
    {
        let provenance = try FlutterEntryProvenance(
            apiBaseURL: XCTUnwrap(URL(string: "https://source.example.invalid/api")),
            evidenceID: "synthetic per-entry source-environment evidence")
        return try FlutterQueueReader.inspect(
            Data("[\(entry)]".utf8),
            provenanceByEntryID: withProvenance ? ["queue-entry-1": provenance] : [:])
    }

    func testExactOriginalIntentIsRetainedWithoutUUIDReplacementDateNormalizationOrOwnerAssignment()
        throws
    {
        let original = Data("[\(entry)]".utf8)
        let report = try inspect(entry)
        XCTAssertEqual(report.originalData, original)
        XCTAssertNil(report.documentIssue)
        let value = try XCTUnwrap(report.entries.first)
        XCTAssertTrue(value.issues.isEmpty)
        XCTAssertEqual(value.entryID, "queue-entry-1")
        XCTAssertEqual(value.idempotencyKey, "original-non-uuid-attempt")
        XCTAssertNotEqual(value.entryID, value.idempotencyKey)
        XCTAssertEqual(value.ownerID, "original-owner")
        XCTAssertEqual(value.sourceEvidenceID, "synthetic per-entry source-environment evidence")
        XCTAssertEqual(value.publicManifestID, "sha256:" + String(repeating: "a", count: 64))
        XCTAssertEqual(report.fingerprint, try CanonicalQuestionReader.digest(original).sha256)
        XCTAssertTrue(String(decoding: report.originalData, as: UTF8.self).contains(".123456Z"))
    }

    func testMissingSourceEnvironmentIsQuarantinedInsteadOfAssumingTheCurrentAPI() throws {
        let report = try inspect(entry, withProvenance: false)
        XCTAssertTrue(try XCTUnwrap(report.entries.first).issues.contains(.missingSourceAPI))
        XCTAssertNil(report.entries.first?.sourceAPI)
    }

    func testMissingAndWhitespaceOwnerRemainUnassigned() throws {
        for replacement in ["null", "\" \""] {
            let report = try inspect(
                entry.replacingOccurrences(of: "\"original-owner\"", with: replacement))
            XCTAssertTrue(try XCTUnwrap(report.entries.first).issues.contains(.missingOwner))
        }
        let report = try inspect(
            entry.replacingOccurrences(of: "\"original-owner\"", with: "\" owner \""))
        XCTAssertTrue(try XCTUnwrap(report.entries.first).issues.contains(.malformedEntry))
        XCTAssertEqual(report.entries.first?.ownerID, " owner ")
    }

    func testUnknownStatusAndFractionalOrBooleanRetryCountersAreNotDefaulted() throws {
        for malformed in [
            entry.replacingOccurrences(of: "\"pending\"", with: "\"future-status\""),
            entry.replacingOccurrences(of: "\"attempts\":2", with: "\"attempts\":1.5"),
            entry.replacingOccurrences(of: "\"attempts\":2", with: "\"attempts\":true"),
        ] {
            XCTAssertTrue(
                try XCTUnwrap(inspect(malformed).entries.first).issues.contains(.malformedEntry))
        }
    }

    func testCompletedAndDeadActionsNeverBecomePendingCandidates() throws {
        for status in ["done", "dead"] {
            let report = try inspect(
                entry.replacingOccurrences(of: "\"pending\"", with: "\"\(status)\""))
            XCTAssertTrue(try XCTUnwrap(report.entries.first).issues.contains(.completedOrDead))
        }
    }

    func testMismatchedAttemptOrPinRetainsTheOriginalDocumentForQuarantine() throws {
        let badAttempt = entry.replacingOccurrences(
            of: "\"idempotencyKey\":\"original-non-uuid-attempt\"",
            with: "\"idempotencyKey\":\"different\"")
        XCTAssertTrue(
            try XCTUnwrap(inspect(badAttempt).entries.first).issues.contains(.idempotencyMismatch))
        let badPin = entry.replacingOccurrences(
            of:
                "\"publicManifestId\":\"sha256:\(String(repeating: "a", count: 64))\",\n \"payload\"",
            with:
                "\"publicManifestId\":\"sha256:\(String(repeating: "b", count: 64))\",\n \"payload\""
        )
        let report = try inspect(badPin)
        XCTAssertNotEqual(badPin, entry)
        XCTAssertTrue(try XCTUnwrap(report.entries.first).issues.contains(.manifestMismatch))
    }

    func testDuplicateEscapedJSONKeysQuarantineTheWholeExactSource() throws {
        let duplicate = entry.replacingOccurrences(
            of: "\"ownerId\":\"original-owner\"",
            with: "\"ownerId\":\"original-owner\",\"\\u006fwnerId\":\"different-owner\"")
        let report = try inspect(duplicate)
        XCTAssertEqual(report.documentIssue, .duplicateJSONKey)
        XCTAssertTrue(report.entries.isEmpty)
        XCTAssertEqual(report.originalData, Data("[\(duplicate)]".utf8))
    }

    func testDuplicateEntryAndAttemptIdentitiesAreReportedWithoutSilentDeduplication() throws {
        let report = try FlutterQueueReader.inspect(Data("[\(entry),\(entry)]".utf8))
        XCTAssertEqual(report.entries.count, 2)
        XCTAssertTrue(report.entries.allSatisfy { $0.issues.contains(.conflictingIdentity) })
    }

    func testInvalidRootAndJSONAreVisibleWithoutDiscardingTheirBytes() throws {
        for (text, issue) in [("{}", FlutterQueueIssue.rootNotList), ("[broken", .invalidJSON)] {
            let data = Data(text.utf8)
            let report = try FlutterQueueReader.inspect(data)
            XCTAssertEqual(report.originalData, data)
            XCTAssertEqual(report.documentIssue, issue)
        }
    }

    func testUnsafeCapturedRoutesAndUnknownActionKindsCannotBecomeCandidates() throws {
        for endpoint in ["/quiz/%2e%2e/submit", "/quiz/%2F/submit", "/quiz/demo/submit?bad=true"] {
            let malformed = entry.replacingOccurrences(
                of: "/quiz/demo-lesson/submit", with: endpoint)
            XCTAssertTrue(
                try XCTUnwrap(inspect(malformed).entries.first).issues.contains(.malformedEntry))
        }
        let unknown = entry.replacingOccurrences(of: "\"quizSubmit\"", with: "\"futureAction\"")
        XCTAssertTrue(
            try XCTUnwrap(inspect(unknown).entries.first).issues.contains(.unsupportedEntry))
    }

    func testLimitsAreMeasuredOnTheOriginalDocument() throws {
        let large = Data(repeating: 32, count: CanonicalQuestionReader.maximumPayloadBytes + 1)
        XCTAssertThrowsError(try FlutterQueueReader.inspect(large)) {
            XCTAssertEqual($0 as? CanonicalContentError, .payloadTooLarge)
        }
        let tooMany =
            "["
            + Array(repeating: "{}", count: FlutterQueueReader.maximumEntries + 1).joined(
                separator: ",") + "]"
        XCTAssertEqual(
            try FlutterQueueReader.inspect(Data(tooMany.utf8)).documentIssue, .tooManyEntries)
    }

    func testImpossibleDatesAndOffsetsAreNotSilentlyNormalized() throws {
        for date in [
            "2026-02-30T12:00:00.123456Z", "2026-10-01T25:00:00Z",
            "2026-10-01T12:00:60Z", "2026-10-01T12:00:00+02:00",
        ] {
            let changed = entry.replacingOccurrences(of: "2026-10-01T12:00:00.123456Z", with: date)
            XCTAssertTrue(
                try XCTUnwrap(inspect(changed).entries.first).issues.contains(.malformedEntry))
        }
    }

    func testDuplicateScannerHandlesNestedEscapedStringValuesWithoutMisidentifyingObjectKeys()
        throws
    {
        let changed = entry.replacingOccurrences(
            of: #""trackId":"legacy-track""#,
            with:
                #""trackId":"legacy-track","note":"braces {}, quote \" and a comma, inside a string""#
        )
        XCTAssertNil(try inspect(changed).documentIssue)
        let nestedDuplicate = entry.replacingOccurrences(
            of: #""itemId":"legacy-item""#, with: #""itemId":"legacy-item","itemId":"another""#)
        XCTAssertEqual(try inspect(nestedDuplicate).documentIssue, .duplicateJSONKey)
    }

    func testNonObjectAndRetainedCorruptionRecordsRemainQuarantined() throws {
        XCTAssertEqual(
            try FlutterQueueReader.inspect(Data("[true]".utf8)).entries.first?.issues,
            [.malformedEntry])
        let retained = #"{"__certigoRetainedCorruptQueueRoot":"original bad JSON"}"#
        XCTAssertTrue(
            try XCTUnwrap(inspect(retained).entries.first).issues.contains(.unsupportedEntry))
    }

    func testMatchingPinsWithTrailingTerminatorsAreStillInvalid() throws {
        let pin = "sha256:" + String(repeating: "a", count: 64)
        for suffix in ["\\n", "\\r\\n", "\\r"] {
            let changed = entry.replacingOccurrences(of: "\(pin)\"", with: "\(pin)\(suffix)\"")
            let value = try XCTUnwrap(inspect(changed).entries.first)
            XCTAssertTrue(value.issues.contains(.missingManifest))
            XCTAssertFalse(value.issues.contains(.manifestMismatch))
        }
    }

    func testUTCTimestampsWithTrailingTerminatorsAreInvalidRatherThanPartiallyMatched() throws {
        for suffix in ["\\n", "\\r\\n", "\\r"] {
            let changed = entry.replacingOccurrences(
                of: "2026-10-01T12:00:00.123456Z\"", with: "2026-10-01T12:00:00.123456Z\(suffix)\"")
            XCTAssertTrue(
                try XCTUnwrap(inspect(changed).entries.first).issues.contains(.malformedEntry))
        }
    }
}
