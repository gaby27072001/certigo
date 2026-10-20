import CoreFoundation
import Foundation

public enum PublicReleaseError: Error, Equatable, Sendable {
    case malformed
    case unsupportedSchema
    case unsupportedResource(String)
    case unsafePath
    case integrity
    case provenance
    case limitExceeded
}
public struct PublicPackageFile: Equatable, Sendable {
    public let id: String
    public let path: String
    public let resourceType: String
    public let hash: String
    public let size: Int
}
public struct PublicPackageManifest: Equatable, Sendable {
    public let manifestId: String
    public let releaseId: String?
    public let files: [PublicPackageFile]
    public let bytes: Data
    public var totalBytes: Int { files.reduce(0) { $0 + $1.size } }
}
public struct ValidatedReleaseBinding: Equatable, Sendable {
    public let releaseId: String
    public let publicManifestId: String
}
public enum PublicReleaseContracts {
    public static let maximumManifestBytes = 2 * 1_024 * 1_024
    public static let maximumFiles = 10_000
    public static let maximumFileBytes = 2 * 1_024 * 1_024
    public static let maximumReleaseBytes = 128 * 1_024 * 1_024
    private static let segment = "[a-z0-9]+(?:-[a-z0-9]+)*"

    public static func manifest(_ data: Data) throws -> PublicPackageManifest {
        guard data.count <= maximumManifestBytes else { throw PublicReleaseError.limitExceeded }
        let root = try json(data)
        guard try text(root, "schema") == "certigo.content.package-manifest/v3" else {
            throw PublicReleaseError.unsupportedSchema
        }
        try closed(
            root,
            required: [
                "schema", "channel", "artifact", "algorithm", "serialization",
                "fileCount", "files", "manifestId", "rootHash",
            ],
            optional: ["releaseId"]
        )
        guard try text(root, "channel") == "public", try text(root, "artifact") == "public",
            try text(root, "algorithm") == "sha256",
            try text(root, "serialization") == "json-sorted-keys-compact-utf8-lf",
            let entries = root["files"] as? [[String: Any]]
        else { throw PublicReleaseError.malformed }
        let count = try integer(root, "fileCount", maximum: maximumFiles)
        guard count > 0, entries.count == count else { throw PublicReleaseError.malformed }
        let files = try entries.map(file)
        guard Set(files.map(\.id)).count == files.count,
            Set(files.map(\.path)).count == files.count
        else { throw PublicReleaseError.malformed }
        var total = 0
        for file in files {
            guard file.size <= maximumReleaseBytes - total else {
                throw PublicReleaseError.limitExceeded
            }
            total += file.size
        }
        let manifestId = try text(root, "manifestId")
        try digestId(manifestId)
        let rootHash = try text(root, "rootHash")
        try hexDigest(rootHash)
        var body = root
        body.removeValue(forKey: "manifestId")
        body.removeValue(forKey: "rootHash")
        body.removeValue(forKey: "releaseId")
        let expected = try canonicalDigest(body)
        guard rootHash == expected, manifestId == "sha256:\(expected)" else {
            throw PublicReleaseError.integrity
        }
        let releaseId: String?
        if root["releaseId"] != nil {
            let value = try text(root, "releaseId")
            try digestId(value)
            releaseId = value
        } else {
            releaseId = nil
        }
        return PublicPackageManifest(
            manifestId: manifestId, releaseId: releaseId, files: files, bytes: data)
    }

    /// Pure optional descriptor validation. There is no public descriptor download route.
    public static func descriptor(_ data: Data, requestedReleaseId: String) throws
        -> ValidatedReleaseBinding
    {
        let root = try json(data)
        try closed(
            root,
            required: [
                "schema", "algorithm", "canonicalization", "publicManifestId", "privateManifestId",
                "releaseId",
            ]
        )
        guard try text(root, "schema") == "certigo.content.release/v1" else {
            throw PublicReleaseError.unsupportedSchema
        }
        guard try text(root, "algorithm") == "sha256",
            try text(root, "canonicalization") == "json-sorted-keys-compact-utf8"
        else { throw PublicReleaseError.malformed }
        let publicId = try text(root, "publicManifestId")
        try digestId(publicId)
        try digestId(text(root, "privateManifestId"))
        let releaseId = try text(root, "releaseId")
        try digestId(releaseId)
        try digestId(requestedReleaseId)
        var body = root
        body.removeValue(forKey: "releaseId")
        let expected = "sha256:\(try canonicalDigest(body))"
        guard releaseId == expected, requestedReleaseId == expected else {
            throw PublicReleaseError.integrity
        }
        return ValidatedReleaseBinding(releaseId: releaseId, publicManifestId: publicId)
    }

    public static func bind(
        _ manifest: PublicPackageManifest, releaseId: String, manifestId: String, etag: String
    ) throws -> ValidatedReleaseBinding {
        try digestId(releaseId)
        guard manifest.releaseId == releaseId, manifest.manifestId == manifestId,
            etag == "\"\(manifestId)\""
        else { throw PublicReleaseError.provenance }
        return ValidatedReleaseBinding(releaseId: releaseId, publicManifestId: manifestId)
    }

    public static func safePath(_ path: String) throws {
        guard !path.isEmpty, path.utf8.count <= 1_024, !path.hasPrefix("/"),
            !path.contains("\\"), !path.contains("%"),
            !path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
            path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({
                !$0.isEmpty && $0 != "." && $0 != ".."
            })
        else { throw PublicReleaseError.unsafePath }
    }

    static func digestId(_ value: String) throws {
        guard value.hasPrefix("sha256:") else { throw PublicReleaseError.integrity }
        try hexDigest(String(value.dropFirst(7)))
    }

    static func hexDigest(_ value: String) throws {
        guard value.utf8.count == 64,
            value.utf8.allSatisfy({
                (48...57).contains($0) || (97...102).contains($0)
            })
        else { throw PublicReleaseError.integrity }
    }

    private static func file(_ entry: [String: Any]) throws -> PublicPackageFile {
        try closed(
            entry, required: ["id", "path", "resourceType", "hash", "size"],
            optional: ["provider", "certification", "blueprintVersion", "objective"]
        )
        let id = try text(entry, "id")
        guard id.utf8.count <= 256 else { throw PublicReleaseError.malformed }
        try pattern(id, "[A-Za-z0-9][A-Za-z0-9._:-]*")
        let path = try text(entry, "path")
        try safePath(path)
        let type = try text(entry, "resourceType")
        let prefix: String
        switch type {
        case "question": prefix = "questions/"
        case "certificationCatalog": prefix = "catalog/"
        case "coverageMatrix": prefix = "coverage/"
        case "track": prefix = "runtime/tracks/"
        case "domain": prefix = "runtime/domains/"
        case "unit": prefix = "runtime/units/"
        case "lesson": prefix = "runtime/lessons/"
        case "concept": prefix = "runtime/concepts/"
        default: throw PublicReleaseError.unsupportedResource(type)
        }
        guard path.hasPrefix(prefix), path.hasSuffix(".json"),
            type != "certificationCatalog" || path == "catalog/certifications.json"
        else { throw PublicReleaseError.unsafePath }
        let hash = try text(entry, "hash")
        try hexDigest(hash)
        let size = try integer(entry, "size", maximum: maximumFileBytes)
        guard size > 0 else { throw PublicReleaseError.malformed }
        for key in ["provider", "certification", "blueprintVersion", "objective"]
        where entry[key] != nil {
            let value = try text(entry, key)
            switch key {
            case "provider": try pattern(value, "(?:aws|gcp|microsoft)")
            case "certification": try pattern(value, "(?:aws|gcp|microsoft):\(segment)")
            case "blueprintVersion": try pattern(value, "[a-z0-9]+(?:[._-][a-z0-9]+)*")
            default: try pattern(value, "(?:domain|section)-[1-9][0-9]*")
            }
        }
        return PublicPackageFile(id: id, path: path, resourceType: type, hash: hash, size: size)
    }

    static func canonicalDigest(_ object: [String: Any]) throws -> String {
        let bytes = try JSONSerialization.data(
            withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return try CanonicalQuestionReader.digest(bytes).sha256
    }

    static func json(_ data: Data) throws -> [String: Any] {
        guard data.count <= maximumManifestBytes else { throw PublicReleaseError.limitExceeded }
        do { return try CanonicalQuestionReader.object(data) } catch is CanonicalContentError {
            throw PublicReleaseError.malformed
        }
    }

    static func text(_ object: [String: Any], _ key: String) throws -> String {
        do { return try CanonicalQuestionReader.string(object, key) } catch is CanonicalContentError
        {
            throw PublicReleaseError.malformed
        }
    }

    static func closed(
        _ object: [String: Any], required: Set<String>, optional: Set<String> = []
    ) throws {
        do {
            try CanonicalQuestionReader.keys(object, required: required, optional: optional)
        } catch is CanonicalContentError { throw PublicReleaseError.malformed }
    }

    static func pattern(_ value: String, _ expression: String) throws {
        do { try CanonicalQuestionReader.matches(value, expression) } catch is CanonicalContentError
        {
            throw PublicReleaseError.malformed
        }
    }

    static func integer(_ object: [String: Any], _ key: String, maximum: Int) throws -> Int {
        guard let number = object[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
            number.doubleValue.isFinite, number.doubleValue.rounded() == number.doubleValue,
            number.doubleValue >= 0
        else { throw PublicReleaseError.malformed }
        guard number.doubleValue <= Double(maximum) else { throw PublicReleaseError.limitExceeded }
        return number.intValue
    }
}
