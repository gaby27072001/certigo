import CoreFoundation
/// Public package resources only. Authorized quiz POST feedback is not subject to this rule.
import Foundation

public enum PublicResourceReader {
    private static let segment = "[a-z0-9]+(?:-[a-z0-9]+)*"
    private static let provider = "(?:aws|gcp|microsoft)"
    private static let certification = "\(provider):\(segment)"
    private static let blueprint = "[a-z0-9]+(?:[._-][a-z0-9]+)*"
    private static let objective = "(?:domain|section)-[1-9][0-9]*"
    private static let question = "\(provider)\\.\(segment)\\.\(segment)\\.\(segment)\\.[0-9]{3}"
    private static let forbidden: Set<String> = [
        "answerkey", "correct", "correctoptionids", "explanation", "privatemanifestid",
        "rationale", "releaseid", "solution",
    ]

    public static func validate(_ bytes: Data, file: PublicPackageFile) throws {
        try CanonicalQuestionReader.verifyFile(bytes, size: file.size, sha256: file.hash)
        let root = try PublicReleaseContracts.json(bytes)
        try rejectPrivate(root)
        switch file.resourceType {
        case "question":
            let value = try CanonicalQuestionReader.decode(bytes)
            guard value.id == file.id else { throw PublicReleaseError.integrity }
            try value.requireBasicCapability()
        case "certificationCatalog":
            guard file.id == "certification-catalog" else { throw PublicReleaseError.integrity }
            try catalog(root)
        case "coverageMatrix":
            guard try text(root, "certification") == file.id else {
                throw PublicReleaseError.integrity
            }
            try coverage(root)
        case "track", "domain", "unit", "lesson", "concept":
            guard try text(root, "id") == file.id else { throw PublicReleaseError.integrity }
            try runtime(root, type: file.resourceType)
        default: throw PublicReleaseError.unsupportedResource(file.resourceType)
        }
    }

    private static func runtime(_ root: [String: Any], type: String) throws {
        try schema(root, "certigo.runtime.\(type)/v1")
        let common: Set<String> = [
            "schema", "resourceType", "id", "certificationId", "blueprintVersion", "lifecycle",
        ]
        let extra: Set<String>
        switch type {
        case "track": extra = ["mode", "summary", "domainIds", "unitIds"]
        case "domain": extra = ["objectiveId"]
        case "unit": extra = ["domainId", "title", "lessonIds"]
        case "concept": extra = ["domainId", "title"]
        case "lesson": extra = ["unitId", "title", "estimatedMinutes", "blocks"]
        default: throw PublicReleaseError.unsupportedResource(type)
        }
        try closed(root, common.union(extra), optional: ["legacyId"])
        guard try text(root, "resourceType") == type else { throw PublicReleaseError.malformed }
        try string(root, "id", pattern: resourceID(type))
        try string(root, "certificationId", pattern: certification)
        try string(root, "blueprintVersion", pattern: blueprint)
        if root["legacyId"] != nil { try string(root, "legacyId", pattern: segment) }
        try runtimeLifecycle(object(root, "lifecycle"))
        switch type {
        case "track":
            try choice(root, "mode", ["guided", "questionBank"])
            _ = try text(root, "summary")
            try strings(root, "domainIds", pattern: resourceID("domain"), minimum: 1)
            let units = try strings(root, "unitIds", pattern: resourceID("unit"))
            let guided = try text(root, "mode") == "guided"
            guard guided ? !units.isEmpty : units.isEmpty else {
                throw PublicReleaseError.malformed
            }
        case "domain": try string(root, "objectiveId", pattern: objective)
        case "unit":
            try string(root, "domainId", pattern: resourceID("domain"))
            _ = try text(root, "title")
            try strings(root, "lessonIds", pattern: resourceID("lesson"), minimum: 1)
        case "concept":
            try string(root, "domainId", pattern: resourceID("domain"))
            _ = try text(root, "title")
        case "lesson":
            try string(root, "unitId", pattern: resourceID("unit"))
            _ = try text(root, "title")
            let minutes = try PublicReleaseContracts.integer(root, "estimatedMinutes", maximum: 60)
            guard minutes >= 1 else { throw PublicReleaseError.malformed }
            let blocks = try objects(root, "blocks", minimum: 2, unique: true)
            for block in blocks { try lessonBlock(block) }
        default: throw PublicReleaseError.unsupportedResource(type)
        }
    }

    private static func lessonBlock(_ block: [String: Any]) throws {
        try closed(
            block, ["id", "type", "conceptId"],
            optional: ["title", "body", "code", "language", "questionId"])
        try string(block, "id", pattern: "\(resourceID("lesson"))\\.block\\.[0-9]{3}")
        try string(block, "conceptId", pattern: resourceID("concept"))
        try choice(block, "type", ["hook", "concept", "example", "code", "check", "recap"])
        for key in ["title", "body", "code", "language"] where block[key] != nil {
            _ = try text(block, key)
        }
        let type = try text(block, "type")
        if type == "check" {
            try closed(block, ["id", "type", "conceptId", "questionId"])
            try string(block, "questionId", pattern: question)
        } else {
            guard block["questionId"] == nil else { throw PublicReleaseError.malformed }
            if type == "code" {
                _ = try text(block, "code")
                _ = try text(block, "language")
            } else {
                _ = try text(block, "body")
            }
        }
    }

    private static func runtimeLifecycle(_ root: [String: Any]) throws {
        try closed(root, ["status"], optional: ["retiredOn", "replacedBy"])
        try choice(root, "status", ["planned", "active", "retiring", "retired", "replaced"])
        let status = try text(root, "status")
        if root["retiredOn"] != nil || status == "retired" { try date(text(root, "retiredOn")) }
        if root["replacedBy"] != nil || status == "replaced" { _ = try text(root, "replacedBy") }
    }

    private static func coverage(_ root: [String: Any]) throws {
        try schema(root, "certigo.coverage-matrix/v1")
        try closed(
            root,
            ["schema", "provider", "certification", "blueprintVersion", "status", "objectives"])
        try choice(root, "provider", ["aws", "gcp", "microsoft"])
        try string(root, "certification", pattern: certification)
        try string(root, "blueprintVersion", pattern: blueprint)
        try choice(root, "status", ["planned", "in-progress", "complete", "retiring", "retired"])
        for value in try objects(root, "objectives", minimum: 1) {
            try closed(value, ["objective", "title", "weightPercent", "weightType", "questionIds"])
            try string(value, "objective", pattern: objective)
            try weight(value)
            try strings(
                value, "questionIds", pattern: "(?:\(question)|[a-z][a-z0-9]*(?:-[a-z0-9]+)+)")
        }
    }

    private static func catalog(_ root: [String: Any]) throws {
        try schema(root, "certigo.certification-catalog/v1")
        try closed(root, ["schema", "asOf", "freshness", "providers", "certifications"])
        try date(text(root, "asOf"))
        let freshness = try object(root, "freshness")
        try closed(freshness, ["maxAgeDays", "reviewDueOn"])
        guard try PublicReleaseContracts.integer(freshness, "maxAgeDays", maximum: Int.max) >= 1
        else {
            throw PublicReleaseError.malformed
        }
        try date(text(freshness, "reviewDueOn"))
        for value in try objects(root, "providers", minimum: 3, unique: true) {
            try closed(
                value,
                ["id", "name", "namespace", "officialCatalogUrl", "sourceHosts", "checkedOn"])
            try choice(value, "id", ["aws", "gcp", "microsoft"])
            try choice(value, "namespace", ["aws", "gcp", "microsoft"])
            _ = try text(value, "name")
            try nullable(value, "officialCatalogUrl", validate: uri)
            try nullable(value, "checkedOn", validate: date)
            try strings(value, "sourceHosts", pattern: "[a-z0-9.-]+", minimum: 1)
        }
        for value in try objects(root, "certifications", minimum: 1) {
            try closed(
                value,
                [
                    "id", "provider", "slug", "officialCode", "officialSlug", "title", "level",
                    "status", "officialUrl", "guide", "blueprint", "provenance",
                ], optional: ["lifecycle"])
            try string(value, "id", pattern: certification)
            try choice(value, "provider", ["aws", "gcp", "microsoft"])
            try string(value, "slug", pattern: segment)
            try string(value, "officialSlug", pattern: segment)
            try nullable(value, "officialCode") { try pattern($0, "[A-Z0-9]+(?:-[A-Z0-9]+)*") }
            _ = try text(value, "title")
            try choice(value, "level", ["foundational", "associate", "professional", "specialty"])
            try choice(
                value, "status", ["announced", "active", "active-retiring", "retired", "replaced"])
            try uri(text(value, "officialUrl"))
            try guide(object(value, "guide"))
            let blueprint = try object(value, "blueprint")
            try closed(blueprint, ["version", "objectives"])
            try string(blueprint, "version", pattern: Self.blueprint)
            for item in try objects(blueprint, "objectives", minimum: 1) {
                try closed(item, ["id", "title", "weightPercent", "weightType"])
                try string(item, "id", pattern: objective)
                try weight(item)
            }
            let provenance = try object(value, "provenance")
            try closed(provenance, ["checkedOn", "sources"])
            try date(text(provenance, "checkedOn"))
            for source in try objects(provenance, "sources", minimum: 2) {
                try closed(source, ["kind", "url"])
                try choice(source, "kind", ["certification-page", "exam-guide", "lifecycle"])
                try uri(text(source, "url"))
            }
            if value["lifecycle"] != nil { try catalogLifecycle(object(value, "lifecycle")) }
        }
    }

    private static func guide(_ root: [String: Any]) throws {
        try closed(root, ["url", "version", "publishedOn", "versionSource", "revisionToken"])
        try uri(text(root, "url"))
        try nullable(root, "version") { _ = $0 }
        try nullable(root, "revisionToken") { _ = $0 }
        try nullable(root, "publishedOn", validate: date)
        try nullable(root, "versionSource") {
            guard ["change-history", "document-header", "document-title", "filename"].contains($0)
            else {
                throw PublicReleaseError.malformed
            }
        }
    }

    private static func catalogLifecycle(_ root: [String: Any]) throws {
        try closed(
            root, [],
            optional: [
                "transition", "reviewOn", "lastExamOn", "recommendThrough", "replaces", "successor",
                "note",
            ])
        if root["transition"] != nil {
            try choice(root, "transition", ["announced", "none-announced"])
        }
        for key in ["reviewOn", "lastExamOn", "recommendThrough"] where root[key] != nil {
            try date(text(root, key))
        }
        if root["replaces"] != nil { try strings(root, "replaces", pattern: certification) }
        if root["successor"] != nil { try string(root, "successor", pattern: certification) }
        if root["note"] != nil { _ = try text(root, "note") }
    }

    private static func weight(_ root: [String: Any]) throws {
        _ = try text(root, "title")
        try choice(root, "weightType", ["exact", "approximate"])
        guard let number = root["weightPercent"] as? NSNumber,
            CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue > 0,
            number.doubleValue <= 100
        else { throw PublicReleaseError.malformed }
    }
    private static func rejectPrivate(_ value: Any) throws {
        if let object = value as? [String: Any] {
            for (key, child) in object {
                guard !forbidden.contains(key.lowercased()) else {
                    throw PublicReleaseError.malformed
                }
                try rejectPrivate(child)
            }
        } else if let array = value as? [Any] {
            for child in array { try rejectPrivate(child) }
        }
    }
    private static func resourceID(_ type: String) -> String {
        "\(provider)\\.\(segment)\\.\(type)\\.\(segment)"
    }
    private static func schema(_ root: [String: Any], _ expected: String) throws {
        guard try text(root, "schema") == expected else {
            throw PublicReleaseError.unsupportedSchema
        }
    }
    private static func closed(
        _ root: [String: Any], _ required: Set<String>, optional: Set<String> = []
    ) throws {
        try PublicReleaseContracts.closed(root, required: required, optional: optional)
    }
    private static func text(_ root: [String: Any], _ key: String) throws -> String {
        try PublicReleaseContracts.text(root, key)
    }
    private static func pattern(_ text: String, _ expression: String) throws {
        try PublicReleaseContracts.pattern(text, expression)
    }
    private static func string(_ root: [String: Any], _ key: String, pattern expression: String)
        throws
    {
        try pattern(text(root, key), expression)
    }
    private static func choice(_ root: [String: Any], _ key: String, _ values: Set<String>) throws {
        guard try values.contains(text(root, key)) else { throw PublicReleaseError.malformed }
    }
    private static func object(_ root: [String: Any], _ key: String) throws -> [String: Any] {
        guard let value = root[key] as? [String: Any] else { throw PublicReleaseError.malformed }
        return value
    }
    private static func objects(
        _ root: [String: Any], _ key: String, minimum: Int, unique: Bool = false
    ) throws -> [[String: Any]] {
        guard let values = root[key] as? [[String: Any]], values.count >= minimum else {
            throw PublicReleaseError.malformed
        }
        if unique {
            let encoded = try values.map {
                try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys])
            }
            guard Set(encoded).count == values.count else { throw PublicReleaseError.malformed }
        }
        return values
    }
    @discardableResult
    private static func strings(
        _ root: [String: Any], _ key: String, pattern expression: String, minimum: Int = 0
    ) throws -> [String] {
        guard let values = root[key] as? [String], values.count >= minimum,
            Set(values.map { Data($0.utf8) }).count == values.count
        else { throw PublicReleaseError.malformed }
        for value in values { try pattern(value, expression) }
        return values
    }
    private static func nullable(
        _ root: [String: Any], _ key: String, validate: (String) throws -> Void
    ) throws {
        if root[key] is NSNull { return }
        try validate(text(root, key))
    }
    private static func uri(_ value: String) throws {
        guard let components = URLComponents(string: value), let scheme = components.scheme,
            !value.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains),
            components.url != nil
        else { throw PublicReleaseError.malformed }
        try pattern(scheme, "[A-Za-z][A-Za-z0-9+.-]*")
    }
    private static func date(_ value: String) throws {
        try pattern(value, "[0-9]{4}-[0-9]{2}-[0-9]{2}")
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[0] > 0 else { throw PublicReleaseError.malformed }
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components),
            calendar.dateComponents([.year, .month, .day], from: date) == components
        else {
            throw PublicReleaseError.malformed
        }
    }
}
