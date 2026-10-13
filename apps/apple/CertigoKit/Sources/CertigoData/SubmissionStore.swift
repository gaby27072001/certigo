import CertigoDomain
import Foundation

public enum SubmissionStatus: String, Codable, Sendable {
    case pendingCorrection, corrected, failed
}
public struct SavedSubmission: Codable, Identifiable, Equatable, Sendable {
    public var id: String { submission.clientAttemptId }
    public let ownerId: String
    public let apiScope: String
    public let lessonId: String
    public let submission: QuizSubmission
    public var status: SubmissionStatus
    public var result: QuizResult?
    public var failureCategory: String?

    public init(ownerId: String, apiScope: String, lessonId: String, submission: QuizSubmission) {
        self.ownerId = ownerId
        self.apiScope = apiScope
        self.lessonId = lessonId
        self.submission = submission
        status = .pendingCorrection
    }
}
public enum StoreError: Error, Equatable, Sendable {
    case invalidRecord
    case conflictingAttempt
    case corruptArchive
    case capacity
}
public actor SubmissionStore {
    private struct Archive: Codable {
        let schema: String
        let entries: [SavedSubmission]
    }

    private let file: URL
    private var loaded: [SavedSubmission]?
    private static let schema = "certigo.apple.submissions/v1"

    public init(file: URL) { self.file = file }

    public func entries(ownerId: String, apiScope: String) throws -> [SavedSubmission] {
        try read().filter { $0.ownerId == ownerId && $0.apiScope == apiScope }
    }

    public func manifestPins() throws -> [RuntimeManifestPin] {
        try read().compactMap { entry in
            entry.submission.publicManifestId.map {
                RuntimeManifestPin(ownerId: entry.ownerId, apiScope: entry.apiScope, manifestId: $0)
            }
        }
    }

    public func enqueue(_ entry: SavedSubmission) throws -> SavedSubmission {
        try validate(entry)
        var entries = try read()
        if let existing = entries.first(where: { $0.id == entry.id }) {
            guard existing.ownerId == entry.ownerId, existing.apiScope == entry.apiScope,
                existing.lessonId == entry.lessonId, existing.submission == entry.submission
            else {
                throw StoreError.conflictingAttempt
            }
            return existing
        }
        guard entries.count < 1_000 else { throw StoreError.capacity }
        entries.append(entry)
        try persist(entries)
        return entry
    }

    public func recordResult(_ result: QuizResult, entry: SavedSubmission) throws {
        let result = try result.validated(for: entry.submission)
        try update(entry) {
            $0.status = .corrected
            $0.result = result
            $0.failureCategory = nil
        }
    }

    public func recordFailure(_ category: String, entry: SavedSubmission) throws {
        try update(entry) {
            $0.status = .failed
            $0.failureCategory = category
        }
    }

    private func update(_ entry: SavedSubmission, change: (inout SavedSubmission) -> Void) throws {
        var entries = try read()
        guard
            let index = entries.firstIndex(where: {
                $0.id == entry.id && $0.ownerId == entry.ownerId && $0.apiScope == entry.apiScope
            })
        else { throw StoreError.invalidRecord }
        change(&entries[index])
        try persist(entries)
    }

    private func read() throws -> [SavedSubmission] {
        if let loaded { return loaded }
        guard FileManager.default.fileExists(atPath: file.path) else {
            loaded = []
            return []
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue <= 8 * 1_024 * 1_024 else {
            throw StoreError.capacity
        }
        let bytes = try Data(contentsOf: file)
        guard bytes.count <= 8 * 1_024 * 1_024 else { throw StoreError.capacity }
        let archive: Archive
        do {
            archive = try CertigoAPI.decoder().decode(Archive.self, from: bytes)
        } catch is DecodingError { throw StoreError.corruptArchive }
        guard archive.schema == Self.schema, archive.entries.count <= 1_000,
            Set(archive.entries.map(\.id)).count == archive.entries.count
        else {
            throw StoreError.corruptArchive
        }
        for entry in archive.entries { try validate(entry) }
        loaded = archive.entries
        return archive.entries
    }

    private func validate(_ entry: SavedSubmission) throws {
        guard !entry.ownerId.isEmpty, !entry.apiScope.isEmpty, !entry.lessonId.isEmpty else {
            throw StoreError.invalidRecord
        }
        _ = try entry.submission.validated()
        switch entry.status {
        case .corrected:
            guard let result = entry.result else { throw StoreError.invalidRecord }
            _ = try result.validated(for: entry.submission)
        case .pendingCorrection, .failed:
            guard entry.result == nil else { throw StoreError.invalidRecord }
        }
    }

    private func persist(_ entries: [SavedSubmission]) throws {
        let bytes = try CertigoAPI.encoder().encode(Archive(schema: Self.schema, entries: entries))
        guard bytes.count <= 8 * 1_024 * 1_024 else { throw StoreError.capacity }
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )
        #endif
        try bytes.write(to: file, options: .atomic)
        #if os(iOS)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: file.path
            )
        #endif
        loaded = entries
    }
}
