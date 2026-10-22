import CertigoDomain
import Foundation

public enum CertigoAppIconPreferenceStoreError: Error, Equatable, Sendable {
  case corruptPreferences
  case encodingFailed
}

public final class CertigoAppIconPreferenceStore: @unchecked Sendable {
  public static let defaultKey = "com.certigo.native.app-icon-preferences.v1"

  private let defaults: UserDefaults
  private let key: String
  private let lock = NSLock()

  public init(
    defaults: UserDefaults = .standard,
    key: String = CertigoAppIconPreferenceStore.defaultKey
  ) {
    self.defaults = defaults
    self.key = key
  }

  public func load() throws -> CertigoAppIconPreferences? {
    lock.lock()
    defer { lock.unlock() }
    guard let data = defaults.data(forKey: key) else { return nil }
    do {
      return try JSONDecoder().decode(CertigoAppIconPreferences.self, from: data)
    } catch {
      throw CertigoAppIconPreferenceStoreError.corruptPreferences
    }
  }

  public func save(_ preferences: CertigoAppIconPreferences) throws {
    lock.lock()
    defer { lock.unlock() }
    do {
      defaults.set(try JSONEncoder().encode(preferences), forKey: key)
    } catch {
      throw CertigoAppIconPreferenceStoreError.encodingFailed
    }
  }

  public func reset() {
    lock.lock()
    defer { lock.unlock() }
    defaults.removeObject(forKey: key)
  }
}
