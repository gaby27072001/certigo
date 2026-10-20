import Foundation

// Synchronous transactions hold both the instance lock and the dedicated directory's process lock.
// LearningClient can guard its session and commit without an intervening actor suspension.
public struct RuntimeManifestPin: Codable, Hashable, Sendable {
    public let ownerId: String
    public let apiScope: String
    public let manifestId: String
}
public struct RuntimeContentSnapshot: Sendable {
    public let ownerId: String
    public let apiScope: String
    public let manifest: PublicPackageManifest
    public let binding: ValidatedReleaseBinding
}
struct RuntimeStage: Sendable {
    let snapshot: RuntimeContentSnapshot
    let key: String
    let revision: UInt64
}
public final class RuntimeContentStore: @unchecked Sendable {
    private struct Scope: Codable {
        let ownerId: String
        let apiScope: String
        var active: String?
        var previous: String?
        var staged: String?
    }
    private struct Archive: Codable {
        let schema: String
        var revision: UInt64
        var scopes: [Scope]
        var pins: [RuntimeManifestPin]
    }
    private struct Capsule: Codable {
        let ownerId: String
        let apiScope: String
        let releaseId: String
        let manifestId: String
        let manifestBytes: Data
    }
    private let lock = NSLock()
    private let disk: RuntimeDisk
    private static let schema = "certigo.apple.runtime-cache/v1"
    private static let maximumStateBytes = 1_024 * 1_024
    private static let maximumCapsuleBytes = 3 * 1_024 * 1_024

    public init(root: URL, maximumBytes: Int = 384 * 1_024 * 1_024) throws {
        disk = try RuntimeDisk(root: root, maximumBytes: maximumBytes)
    }
    init(
        root: URL, maximumBytes: Int = 384 * 1_024 * 1_024,
        fault: @escaping @Sendable (RuntimeWritePoint, String) throws -> Void
    ) throws {
        disk = try RuntimeDisk(root: root, maximumBytes: maximumBytes, fault: fault)
    }

    public func active(ownerId: String, apiScope: String) throws -> RuntimeContentSnapshot? {
        try transaction {
            let state = try archive()
            guard
                let scope = state.scopes.first(where: {
                    $0.ownerId == ownerId && $0.apiScope == apiScope
                }),
                let key = scope.active
            else { return nil }
            let value = try snapshot(key, ownerId: ownerId, apiScope: apiScope)
            try verifyComplete(value)
            return value
        }
    }

    public func previous(ownerId: String, apiScope: String) throws -> RuntimeContentSnapshot? {
        try transaction {
            let state = try archive()
            guard
                let scope = state.scopes.first(where: {
                    $0.ownerId == ownerId && $0.apiScope == apiScope
                }),
                let key = scope.previous
            else { return nil }
            let value = try snapshot(key, ownerId: ownerId, apiScope: apiScope)
            try verifyComplete(value)
            return value
        }
    }

    public func questionPack(
        trackId: String, ownerId: String, apiScope: String, manifestId: String? = nil
    ) throws -> OfflineQuestionPack? {
        try transaction {
            let state = try archive()
            try scope(ownerId, apiScope)
            let key: String
            if let manifestId {
                try PublicReleaseContracts.digestId(manifestId)
                let keys = try disk.entries().map(\.name).filter { $0.hasPrefix("x-") }
                var matching: String?
                for candidate in keys {
                    let capsule = try readCapsule(candidate)
                    if capsule.ownerId == ownerId && capsule.apiScope == apiScope
                        && capsule.manifestId == manifestId
                    {
                        matching = candidate
                    }
                }
                guard let matching else { throw RuntimeStoreError.missingFile }
                key = matching
            } else {
                guard
                    let active = state.scopes.first(where: {
                        $0.ownerId == ownerId && $0.apiScope == apiScope
                    })?.active
                else { return nil }
                key = active
            }
            let value = try snapshot(key, ownerId: ownerId, apiScope: apiScope)
            try verifyComplete(value)
            return try OfflineQuestionPackReader.read(trackId: trackId, snapshot: value) { file in
                guard let bytes = try verifiedFile(file) else {
                    throw RuntimeStoreError.missingFile
                }
                return bytes
            }
        }
    }

    /// Explicit recovery only: a corrupt active snapshot never silently becomes the previous one.
    public func restorePrevious(ownerId: String, apiScope: String) throws -> RuntimeContentSnapshot
    {
        try transaction {
            var state = try archive()
            guard
                let index = state.scopes.firstIndex(where: {
                    $0.ownerId == ownerId && $0.apiScope == apiScope
                }),
                let key = state.scopes[index].previous
            else { throw RuntimeStoreError.missingFile }
            let value = try snapshot(key, ownerId: ownerId, apiScope: apiScope)
            try verifyComplete(value)
            let old = state.scopes[index].active
            state.scopes[index].active = key
            state.scopes[index].previous = old
            try persist(&state)
            return value
        }
    }

    func begin(_ value: RuntimeContentSnapshot) throws -> RuntimeStage {
        try transaction {
            try scope(value.ownerId, value.apiScope)
            var state = try archive()
            if try disk.read("state.json", maximum: Self.maximumStateBytes) == nil {
                try persist(&state)
            }
            _ = try PublicReleaseContracts.bind(
                value.manifest, releaseId: value.binding.releaseId,
                manifestId: value.binding.publicManifestId,
                etag: "\"\(value.binding.publicManifestId)\"")
            let key = try capsuleKey(value)
            let capsule = Capsule(
                ownerId: value.ownerId, apiScope: value.apiScope,
                releaseId: value.binding.releaseId, manifestId: value.binding.publicManifestId,
                manifestBytes: value.manifest.bytes)
            let bytes = try encode(capsule)
            guard bytes.count <= Self.maximumCapsuleBytes else { throw RuntimeStoreError.capacity }
            if let existing = try disk.read(key, maximum: Self.maximumCapsuleBytes) {
                _ = try snapshot(key, ownerId: value.ownerId, apiScope: value.apiScope)
                if existing != bytes { try disk.write(bytes, name: key) }
            } else {
                try disk.write(bytes, name: key)
            }
            if let index = state.scopes.firstIndex(where: {
                $0.ownerId == value.ownerId && $0.apiScope == value.apiScope
            }) {
                state.scopes[index].staged = key
            } else {
                guard state.scopes.count < 256 else { throw RuntimeStoreError.capacity }
                state.scopes.append(
                    Scope(ownerId: value.ownerId, apiScope: value.apiScope, staged: key))
            }
            try persist(&state)
            return RuntimeStage(snapshot: value, key: key, revision: state.revision)
        }
    }

    func cachedFile(_ file: PublicPackageFile) throws -> Data? {
        try transaction { try verifiedFile(file) }
    }

    func saveFile(_ bytes: Data, file: PublicPackageFile) throws {
        try transaction {
            try PublicResourceReader.validate(bytes, file: file)
            let name = try blobName(file.hash)
            if let existing = try verifiedFile(file) {
                guard existing == bytes else { throw PublicReleaseError.integrity }
            } else {
                try disk.write(bytes, name: name)
            }
        }
    }

    func activate(_ stage: RuntimeStage) throws -> RuntimeContentSnapshot {
        try transaction {
            var state = try archive()
            guard state.revision == stage.revision,
                let index = state.scopes.firstIndex(where: {
                    $0.ownerId == stage.snapshot.ownerId && $0.apiScope == stage.snapshot.apiScope
                }), state.scopes[index].staged == stage.key
            else {
                throw RuntimeStoreError.staleActivation
            }
            let value = try snapshot(
                stage.key, ownerId: stage.snapshot.ownerId, apiScope: stage.snapshot.apiScope)
            try verifyComplete(value)
            if state.scopes[index].active != stage.key {
                state.scopes[index].previous = state.scopes[index].active
                state.scopes[index].active = stage.key
            }
            state.scopes[index].staged = nil
            try persist(&state)
            return value
        }
    }

    func retainPins(_ pins: [RuntimeManifestPin]) throws {
        try transaction {
            for pin in pins {
                try scope(pin.ownerId, pin.apiScope)
                try PublicReleaseContracts.digestId(pin.manifestId)
            }
            var state = try archive()
            let existing = Set(state.pins)
            let combined = existing.union(pins)
            guard combined.count <= 1_000 else { throw RuntimeStoreError.capacity }
            if combined != existing {
                state.pins = combined.sorted {
                    [$0.apiScope, $0.ownerId, $0.manifestId].lexicographicallyPrecedes(
                        [$1.apiScope, $1.ownerId, $1.manifestId])
                }
                try persist(&state)
            }
        }
    }

    func retainedPins() throws -> [RuntimeManifestPin] { try transaction { try archive().pins } }

    /// Called only after LearningClient imports all persisted outbox pins. Never releases a pin.
    func cleanup() throws -> Int {
        try transaction {
            let state = try archive()
            let entries = try disk.entries()
            var protected = Set(
                state.scopes.flatMap {
                    [$0.active, $0.previous, $0.staged].compactMap { $0 }
                })
            let pins = Set(state.pins)
            var snapshots: [String: RuntimeContentSnapshot] = [:]
            for entry in entries where entry.name.hasPrefix("x-") {
                let capsule = try readCapsule(entry.name)
                let value = try snapshot(
                    entry.name, ownerId: capsule.ownerId, apiScope: capsule.apiScope)
                snapshots[entry.name] = value
                if pins.contains(
                    RuntimeManifestPin(
                        ownerId: value.ownerId, apiScope: value.apiScope,
                        manifestId: value.manifest.manifestId))
                {
                    protected.insert(entry.name)
                }
            }
            var blobs: Set<String> = []
            for key in protected {
                guard let value = snapshots[key] else { throw RuntimeStoreError.missingFile }
                for file in value.manifest.files { blobs.insert(try blobName(file.hash)) }
            }
            let candidates = entries.map(\.name).filter {
                ($0.hasPrefix("x-") && !protected.contains($0))
                    || ($0.hasPrefix("b-") && !blobs.contains($0)) || $0.hasPrefix(".tmp-")
            }.sorted()
            for name in candidates.prefix(32) { try disk.remove(name) }
            return min(32, candidates.count)
        }
    }

    private func verifiedFile(_ file: PublicPackageFile) throws -> Data? {
        guard
            let bytes = try disk.read(
                blobName(file.hash), maximum: PublicReleaseContracts.maximumFileBytes)
        else {
            return nil
        }
        try PublicResourceReader.validate(bytes, file: file)
        return bytes
    }

    private func verifyComplete(_ value: RuntimeContentSnapshot) throws {
        for file in value.manifest.files {
            try Task.checkCancellation()
            guard try verifiedFile(file) != nil else { throw RuntimeStoreError.missingFile }
        }
    }

    private func snapshot(_ key: String, ownerId: String, apiScope: String) throws
        -> RuntimeContentSnapshot
    {
        try scope(ownerId, apiScope)
        let capsule = try readCapsule(key)
        guard capsule.ownerId == ownerId, capsule.apiScope == apiScope else {
            throw RuntimeStoreError.corruptState
        }
        let manifest = try PublicReleaseContracts.manifest(capsule.manifestBytes)
        let binding = try PublicReleaseContracts.bind(
            manifest, releaseId: capsule.releaseId,
            manifestId: capsule.manifestId, etag: "\"\(capsule.manifestId)\"")
        let value = RuntimeContentSnapshot(
            ownerId: ownerId, apiScope: apiScope, manifest: manifest, binding: binding)
        guard try capsuleKey(value) == key else { throw RuntimeStoreError.corruptState }
        return value
    }

    private func readCapsule(_ key: String) throws -> Capsule {
        guard let bytes = try disk.read(key, maximum: Self.maximumCapsuleBytes) else {
            throw RuntimeStoreError.missingFile
        }
        do { return try JSONDecoder().decode(Capsule.self, from: bytes) } catch is DecodingError {
            throw RuntimeStoreError.corruptState
        }
    }

    private func archive() throws -> Archive {
        guard let bytes = try disk.read("state.json", maximum: Self.maximumStateBytes) else {
            guard
                try !disk.entries().contains(where: {
                    $0.name.hasPrefix("x-") || $0.name.hasPrefix("b-")
                })
            else { throw RuntimeStoreError.corruptState }
            return Archive(schema: Self.schema, revision: 0, scopes: [], pins: [])
        }
        let state: Archive
        do { state = try JSONDecoder().decode(Archive.self, from: bytes) } catch is DecodingError {
            throw RuntimeStoreError.corruptState
        }
        guard state.schema == Self.schema, state.scopes.count <= 256, state.pins.count <= 1_000,
            Set(state.pins).count == state.pins.count,
            Set(state.scopes.map { [$0.apiScope, $0.ownerId] }).count == state.scopes.count
        else {
            throw RuntimeStoreError.corruptState
        }
        for item in state.scopes {
            try scope(item.ownerId, item.apiScope)
            for name in [item.active, item.previous, item.staged].compactMap({ $0 }) {
                guard name.range(of: "^x-[0-9a-f]{64}\\.json$", options: .regularExpression) != nil
                else {
                    throw RuntimeStoreError.corruptState
                }
            }
        }
        for pin in state.pins {
            try scope(pin.ownerId, pin.apiScope)
            try PublicReleaseContracts.digestId(pin.manifestId)
        }
        return state
    }

    private func persist(_ state: inout Archive) throws {
        guard state.revision < UInt64.max else { throw RuntimeStoreError.capacity }
        state.revision += 1
        let bytes = try encode(state)
        guard bytes.count <= Self.maximumStateBytes else { throw RuntimeStoreError.capacity }
        try disk.write(bytes, name: "state.json")
    }
    private func scope(_ ownerId: String, _ apiScope: String) throws {
        guard !ownerId.isEmpty, ownerId.utf8.count <= 256, apiScope.utf8.count <= 4_096,
            let url = URL(string: apiScope)
        else { throw RuntimeStoreError.corruptState }
        try CertigoAPI.validateBaseURL(url)
    }
    private func capsuleKey(_ value: RuntimeContentSnapshot) throws -> String {
        let data = try encode([
            value.apiScope, value.ownerId, value.binding.releaseId, value.binding.publicManifestId,
        ])
        return "x-\(try CanonicalQuestionReader.digest(data).sha256).json"
    }
    private func blobName(_ hash: String) throws -> String {
        try PublicReleaseContracts.hexDigest(hash)
        return "b-\(hash).json"
    }
    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    private func transaction<T>(_ body: () throws -> T) throws -> T {
        try lock.withLock { try disk.exclusive(body) }
    }
}
