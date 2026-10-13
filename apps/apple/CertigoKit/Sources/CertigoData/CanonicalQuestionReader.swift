import CoreFoundation
import Foundation

/// Canonical corpus wire reader, deliberately separate from the HTTP lesson projection.
#if canImport(CryptoKit)
    import CryptoKit
#else
    import Crypto
#endif
public enum CanonicalContentError: Error, Equatable, Sendable {
    case malformed
    case unsupportedSchema(String)
    case unsupportedCapability(String)
    case integrityMismatch
    case payloadTooLarge
}
public struct CanonicalQuestionMetadata: Equatable, Sendable {
    public let provider: String
    public let certification: String
    public let blueprintVersion: String
    public let objective: String
    public let domainId: String?
    public let conceptId: String?
}
public struct CanonicalOption: Equatable, Sendable {
    public let id: String
    public let label: String
}
public enum CanonicalQuestionOptions: Equatable, Sendable {
    case legacyChoices([String])
    case identified([CanonicalOption])
}
public struct CanonicalPublicQuestion: Equatable, Sendable {
    public let id: String
    public let legacyId: String?
    public let schemaVersion: String
    public let metadata: CanonicalQuestionMetadata
    public let itemType: String
    public let difficulty: Int?
    public let prompt: String
    public let options: CanonicalQuestionOptions

    public func requireBasicCapability() throws {
        guard itemType == "mcq" else {
            throw CanonicalContentError.unsupportedCapability("itemType:\(itemType)")
        }
    }
}
public struct ContentFileDigest: Equatable, Sendable {
    public let size: Int
    public let sha256: String
}
public enum CanonicalQuestionReader {
    public static let maximumPayloadBytes = 1_048_576
    private static let segment = "[a-z0-9]+(?:-[a-z0-9]+)*"
    private static let provider = "(?:aws|gcp|microsoft)"

    public static func decode(_ data: Data) throws -> CanonicalPublicQuestion {
        let root = try object(data)
        let schema = try string(root, "schemaVersion")
        guard schema == "v3" || schema == "v4" else {
            throw CanonicalContentError.unsupportedSchema(schema)
        }
        let v4 = schema == "v4"
        try keys(
            root,
            required: v4
                ? [
                    "id", "schemaVersion", "kind", "metadata", "itemType", "difficulty", "prompt",
                    "options",
                ]
                : ["id", "schemaVersion", "kind", "metadata", "prompt", "choices"],
            optional: v4 ? ["legacyId"] : []
        )
        guard try string(root, "kind") == "public" else { throw CanonicalContentError.malformed }
        let id = try string(root, "id")
        try matches(id, "\(provider)\\.\(segment)\\.\(segment)\\.\(segment)\\.[0-9]{3}")
        let prompt = try string(root, "prompt")
        let metadata = try metadata(root["metadata"], v4: v4)
        if !v4 {
            guard let choices = root["choices"] as? [String], choices.count >= 2,
                choices.allSatisfy({ !$0.isEmpty }),
                Set(choices.map { Data($0.utf8) }).count == choices.count
            else { throw CanonicalContentError.malformed }
            return CanonicalPublicQuestion(
                id: id, legacyId: nil, schemaVersion: schema, metadata: metadata,
                itemType: "mcq", difficulty: nil, prompt: prompt, options: .legacyChoices(choices)
            )
        }
        let legacyId = try root["legacyId"].map { value -> String in
            guard let id = value as? String else { throw CanonicalContentError.malformed }
            try matches(id, segment)
            return id
        }
        let type = try string(root, "itemType")
        guard ["mcq", "multi", "scenario", "spotTheIssue"].contains(type),
            let number = root["difficulty"] as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(),
            number.doubleValue.rounded() == number.doubleValue,
            (1...3).contains(number.doubleValue),
            let rawOptions = root["options"] as? [[String: Any]],
            (2...8).contains(rawOptions.count)
        else { throw CanonicalContentError.malformed }
        let options = try rawOptions.map { option in
            try keys(option, required: ["id", "label"])
            let id = try string(option, "id")
            try matches(id, segment)
            return CanonicalOption(id: id, label: try string(option, "label"))
        }
        // Schema uniqueItems compares whole options, not just identifiers.
        let optionBytes = try rawOptions.map {
            try JSONSerialization.data(
                withJSONObject: $0, options: [.sortedKeys, .withoutEscapingSlashes])
        }
        guard Set(optionBytes).count == options.count else { throw CanonicalContentError.malformed }
        return CanonicalPublicQuestion(
            id: id, legacyId: legacyId, schemaVersion: schema, metadata: metadata,
            itemType: type, difficulty: number.intValue, prompt: prompt,
            options: .identified(options)
        )
    }

    public static func canonicalBody(_ data: Data) throws -> Data {
        _ = try decode(data)
        // Supported schemas have fixed ASCII object keys and only small integer numbers.
        // This is not a general-purpose ECMAScript/JCS serializer for arbitrary JSON.
        return try JSONSerialization.data(
            withJSONObject: object(data), options: [.sortedKeys, .withoutEscapingSlashes]
        )
    }

    public static func packageFile(_ data: Data) throws -> Data {
        var bytes = try canonicalBody(data)
        bytes.append(0x0A)
        return bytes
    }

    public static func digest(_ bytes: Data) throws -> ContentFileDigest {
        guard bytes.count <= maximumPayloadBytes else {
            throw CanonicalContentError.payloadTooLarge
        }
        let sha256 = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        return ContentFileDigest(size: bytes.count, sha256: sha256)
    }

    public static func verifyFile(_ bytes: Data, size: Int, sha256: String) throws {
        guard size >= 0, sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
        else {
            throw CanonicalContentError.integrityMismatch
        }
        let actual = try digest(bytes)
        guard actual.size == size, actual.sha256 == sha256 else {
            throw CanonicalContentError.integrityMismatch
        }
    }

    private static func metadata(_ value: Any?, v4: Bool) throws -> CanonicalQuestionMetadata {
        guard let object = value as? [String: Any] else { throw CanonicalContentError.malformed }
        var required: Set<String> = ["provider", "certification", "blueprintVersion", "objective"]
        if v4 { required.formUnion(["domainId", "conceptId"]) }
        try keys(object, required: required)
        let name = try string(object, "provider")
        guard ["aws", "gcp", "microsoft"].contains(name) else {
            throw CanonicalContentError.malformed
        }
        let certification = try string(object, "certification")
        try matches(certification, "\(provider):\(segment)")
        let blueprint = try string(object, "blueprintVersion")
        try matches(blueprint, "[a-z0-9]+(?:[._-][a-z0-9]+)*")
        let objective = try string(object, "objective")
        try matches(objective, v4 ? "(?:domain|section)-[1-9][0-9]*" : segment)
        let domainId = v4 ? try string(object, "domainId") : nil
        let conceptId = v4 ? try string(object, "conceptId") : nil
        if let domainId { try matches(domainId, "\(provider)\\.\(segment)\\.domain\\.\(segment)") }
        if let conceptId {
            try matches(conceptId, "\(provider)\\.\(segment)\\.concept\\.\(segment)")
        }
        return CanonicalQuestionMetadata(
            provider: name, certification: certification, blueprintVersion: blueprint,
            objective: objective, domainId: domainId, conceptId: conceptId
        )
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard data.count <= maximumPayloadBytes else { throw CanonicalContentError.payloadTooLarge }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CanonicalContentError.malformed
            }
            return object
        } catch {
            throw CanonicalContentError.malformed
        }
    }

    private static func keys(
        _ object: [String: Any], required: Set<String>, optional: Set<String> = []
    ) throws {
        let actual = Set(object.keys)
        guard required.isSubset(of: actual), actual.isSubset(of: required.union(optional)) else {
            throw CanonicalContentError.malformed
        }
    }

    private static func string(_ object: [String: Any], _ key: String) throws -> String {
        guard let value = object[key] as? String, !value.isEmpty else {
            throw CanonicalContentError.malformed
        }
        return value
    }

    private static func matches(_ value: String, _ pattern: String) throws {
        guard value.range(of: "\\A(?:\(pattern))\\z", options: .regularExpression) != nil else {
            throw CanonicalContentError.malformed
        }
    }
}
