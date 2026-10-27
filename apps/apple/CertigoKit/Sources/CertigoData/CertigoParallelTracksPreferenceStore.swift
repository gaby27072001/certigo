import CertigoDomain
import Foundation

public enum CertigoParallelTracksPreferenceStoreError: Error, Equatable, Sendable {
    case invalidKey
    case corruptPreferences
    case encodingFailed
}

public final class CertigoParallelTracksPreferenceStore: @unchecked Sendable {
    public static let defaultKey = CertigoParallelTracksPreference.storageKey

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    public init(
        defaults: UserDefaults = .standard,
        key: String = CertigoParallelTracksPreferenceStore.defaultKey
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() throws -> CertigoParallelTracksPreference? {
        lock.lock()
        defer { lock.unlock() }
        guard !key.isEmpty else {
            throw CertigoParallelTracksPreferenceStoreError.invalidKey
        }
        do {
            return try CertigoParallelTracksPreference.load(from: defaults, key: key)
        } catch {
            throw CertigoParallelTracksPreferenceStoreError.corruptPreferences
        }
    }

    public func loadOrDefault() -> CertigoParallelTracksPreference {
        (try? load()) ?? CertigoParallelTracksPreference()
    }

    public func save(_ preference: CertigoParallelTracksPreference) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !key.isEmpty else {
            throw CertigoParallelTracksPreferenceStoreError.invalidKey
        }
        do {
            try preference.save(to: defaults, key: key)
        } catch {
            throw CertigoParallelTracksPreferenceStoreError.encodingFailed
        }
    }

    @discardableResult
    public func update(
        _ mutate: (inout CertigoParallelTracksPreference) -> Void
    ) throws -> CertigoParallelTracksPreference {
        var current = (try? load()) ?? CertigoParallelTracksPreference()
        mutate(&current)
        try save(current)
        return current
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        CertigoParallelTracksPreference.reset(in: defaults, key: key)
    }
}
