import CertigoDomain
import CoreFoundation
import Foundation

/// In-memory inspection only. Retain exact input; do not import, replay or rewrite preferences.

public enum FlutterQueueIssue: String, Sendable {
    case invalidJSON, rootNotList, duplicateJSONKey, tooManyEntries
    case malformedEntry, unsupportedEntry, missingOwner, missingSourceAPI
    case idempotencyMismatch, manifestMismatch, missingManifest, conflictingIdentity
    case completedOrDead
}
public struct FlutterQueueInspection: Sendable {
    public let index: Int
    public let entryID: String?
    public let ownerID: String?
    public let idempotencyKey: String?
    public let publicManifestID: String?
    public let sourceAPI: URL?
    public let sourceEvidenceID: String?
    public let issues: [FlutterQueueIssue]
}
public struct FlutterQueueDryRun: Sendable {
    public let originalData: Data
    public let fingerprint: String
    public let documentIssue: FlutterQueueIssue?
    public let entries: [FlutterQueueInspection]
}
public struct FlutterEntryProvenance: Sendable {
    public let apiBaseURL: URL
    public let evidenceID: String

    public init(apiBaseURL: URL, evidenceID: String) throws {
        try CertigoAPI.validateBaseURL(apiBaseURL)
        guard !evidenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ContractError.malformed("migration provenance")
        }
        self.apiBaseURL = apiBaseURL
        self.evidenceID = evidenceID
    }
}
public enum FlutterQueueReader {
    public static let preferencesKey = "certigo.sync.queue.v1"
    public static let maximumEntries = 1_000

    public static func inspect(
        _ data: Data, provenanceByEntryID: [String: FlutterEntryProvenance] = [:]
    ) throws -> FlutterQueueDryRun {
        let fingerprint = try CanonicalQuestionReader.digest(data).sha256
        func report(_ issue: FlutterQueueIssue) -> FlutterQueueDryRun {
            FlutterQueueDryRun(
                originalData: data, fingerprint: fingerprint, documentIssue: issue, entries: [])
        }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch let error as NSError where error.domain == NSCocoaErrorDomain {
            return report(.invalidJSON)
        }
        guard try !containsDuplicateKeys(data) else { return report(.duplicateJSONKey) }
        guard let values = parsed as? [Any] else { return report(.rootNotList) }
        guard values.count <= maximumEntries else { return report(.tooManyEntries) }
        let objects = values.map { $0 as? [String: Any] }
        let entryIDs = objects.compactMap { $0?["id"] as? String }
        let attempts = objects.compactMap { $0?["idempotencyKey"] as? String }
        let duplicateIDs = Set(
            Dictionary(grouping: entryIDs, by: { $0 }).filter { $0.value.count > 1 }.keys)
        let duplicateAttempts = Set(
            Dictionary(grouping: attempts, by: { $0 }).filter { $0.value.count > 1 }.keys)
        let entries = objects.enumerated().map { index, object -> FlutterQueueInspection in
            let entryID = object?["id"] as? String
            let owner = object?["ownerId"] as? String
            let attempt = object?["idempotencyKey"] as? String
            let manifest = object?["publicManifestId"] as? String
            let provenance = entryID.flatMap { provenanceByEntryID[$0] }
            var issues: [FlutterQueueIssue] = []
            guard let object else {
                return FlutterQueueInspection(
                    index: index, entryID: nil, ownerID: nil, idempotencyKey: nil,
                    publicManifestID: nil, sourceAPI: nil, sourceEvidenceID: nil,
                    issues: [.malformedEntry])
            }
            let allowed: Set<String> = [
                "id", "kind", "endpoint", "payload", "idempotencyKey", "createdAt", "ownerId",
                "publicManifestId", "status", "attempts", "nextAttemptAt", "lastError",
                "completedAt",
            ]
            if !Set(object.keys).isSubset(of: allowed) || object["kind"] as? String != "quizSubmit"
            {
                issues.append(.unsupportedEntry)
            }
            if entryID?.isEmpty != false || attempt?.isEmpty != false
                || !validDate(object["createdAt"])
                || !validOptionalDate(object["nextAttemptAt"])
                || !validOptionalDate(object["completedAt"])
                || !validOptionalString(object["lastError"])
                || !validInteger(object["attempts"])
                || !validEndpoint(object["endpoint"])
            {
                issues.append(.malformedEntry)
            }
            if owner == nil
                || owner?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
            {
                issues.append(.missingOwner)
            } else if owner != owner?.trimmingCharacters(in: .whitespacesAndNewlines) {
                issues.append(.malformedEntry)
            }
            if provenance == nil { issues.append(.missingSourceAPI) }
            if duplicateIDs.contains(entryID ?? "") || duplicateAttempts.contains(attempt ?? "") {
                issues.append(.conflictingIdentity)
            }
            switch object["status"] as? String {
            case "pending": break
            case "done", "dead": issues.append(.completedOrDead)
            default: issues.append(.malformedEntry)
            }
            if !validManifest(manifest) { issues.append(.missingManifest) }
            if let payload = object["payload"] as? [String: Any] {
                if payload["clientAttemptId"] as? String != attempt {
                    issues.append(.idempotencyMismatch)
                }
                if payload["publicManifestId"] as? String != manifest {
                    issues.append(.manifestMismatch)
                }
                if (payload["trackId"] as? String)?.isEmpty != false
                    || !validDate(payload["startedAt"])
                    || (payload["answers"] as? [[String: Any]])?.isEmpty != false
                    || payload["ownerId"] != nil || payload["userId"] != nil
                {
                    issues.append(.malformedEntry)
                }
            } else {
                issues.append(.malformedEntry)
            }
            return FlutterQueueInspection(
                index: index, entryID: entryID, ownerID: owner, idempotencyKey: attempt,
                publicManifestID: manifest, sourceAPI: provenance?.apiBaseURL,
                sourceEvidenceID: provenance?.evidenceID, issues: issues)
        }
        return FlutterQueueDryRun(
            originalData: data, fingerprint: fingerprint, documentIssue: nil, entries: entries)
    }

    private static func validManifest(_ value: String?) -> Bool {
        guard let value, value.utf8.count == 71, value.hasPrefix("sha256:") else { return false }
        return value.dropFirst(7).utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }

    private static func validOptionalString(_ value: Any?) -> Bool {
        value == nil || value is NSNull || value is String
    }

    private static func validInteger(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return false
        }
        return number.doubleValue.isFinite && number.doubleValue.rounded() == number.doubleValue
            && (0...Double(Int32.max)).contains(number.doubleValue)
    }

    private static func validOptionalDate(_ value: Any?) -> Bool {
        value == nil || value is NSNull || validDate(value)
    }

    private static func validDate(_ value: Any?) -> Bool {
        guard let text = value as? String,
            text.range(
                of: #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]{1,6})?Z\z"#,
                options: .regularExpression) != nil
        else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions =
            text.contains(".")
            ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        guard let date = formatter.date(from: text) else { return false }
        let expected = text.prefix(19).split(whereSeparator: { "-T:".contains($0) }).compactMap {
            Int($0)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        return expected
            == [
                components.year, components.month, components.day, components.hour,
                components.minute, components.second,
            ].compactMap { $0 }
    }

    private static func validEndpoint(_ value: Any?) -> Bool {
        guard let text = value as? String else { return false }
        let parts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 4, parts[0].isEmpty, parts[1] == "quiz", parts[3] == "submit",
            let lesson = String(parts[2]).removingPercentEncoding, !lesson.isEmpty,
            lesson != ".", lesson != "..",
            !lesson.contains("/"), !lesson.contains("\\"),
            !lesson.utf8.contains(where: { $0 < 32 || $0 == 127 }),
            !text.contains("?"), !text.contains("#")
        else { return false }
        return true
    }

    /// Foundation already checked syntax; scan original tokens to detect escaped duplicate keys.
    private static func containsDuplicateKeys(_ data: Data) throws -> Bool {
        let bytes = Array(data)
        struct Frame {
            var keys: Set<String>?
            var expectingKey = true
        }
        var frames: [Frame] = []
        var index = 0
        while index < bytes.count {
            switch bytes[index] {
            case 123: frames.append(Frame(keys: []))
            case 91: frames.append(Frame(keys: nil))
            case 125, 93: frames.removeLast()
            case 44:
                if !frames.isEmpty { frames[frames.count - 1].expectingKey = true }
            case 34:
                let start = index
                index += 1
                while index < bytes.count && bytes[index] != 34 {
                    index += bytes[index] == 92 ? 2 : 1
                }
                if !frames.isEmpty, frames[frames.count - 1].keys != nil,
                    frames[frames.count - 1].expectingKey
                {
                    guard
                        let key = try JSONSerialization.jsonObject(
                            with: Data(bytes[start...index]), options: [.fragmentsAllowed])
                            as? String
                    else { throw ContractError.malformed("migration JSON key") }
                    let top = frames.count - 1
                    guard frames[top].keys?.insert(key).inserted == true else { return true }
                    frames[top].expectingKey = false
                }
            default: break
            }
            index += 1
        }
        return false
    }
}
