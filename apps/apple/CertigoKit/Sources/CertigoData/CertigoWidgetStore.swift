import Foundation
import CertigoDomain

public enum CertigoWidgetStoreLocation: Equatable, Sendable {
  case appGroup
  case localFallback
  case explicitFile
  case unavailable
}

public enum CertigoWidgetLoadState: Equatable, Sendable {
  case ready(CertigoWidgetSnapshot)
  case unconfigured
}

public enum CertigoWidgetStoreError: Error, Equatable, Sendable {
  case invalidPath
  case appGroupUnavailable
  case storageUnavailable
  case oversizedSnapshot
  case corruptSnapshot
  case staleSnapshot
  case protectionPolicy
}

public final class CertigoWidgetStore: @unchecked Sendable {
  public static let defaultAppGroupIdentifier = "group.com.certigo.shared"
  public static let legacyAppGroupIdentifier = "group.com.certigo.native"
  public static let supportedAppGroupIdentifiers = [
    "group.com.certigo.shared",
    "group.com.certigo.native",
  ]
  public static let userDefaultsSnapshotKey = "certigo.widget.snapshot.json"
  public static let maximumSnapshotBytes = 64 * 1_024

  private let appGroupIdentifier: String
  private let sharedContainerOnly: Bool
  private let fallbackDirectory: URL?
  private let explicitFileURL: URL?
  private let fileManager: FileManager
  private let lock = NSLock()

  public init(
    appGroupIdentifier: String = CertigoWidgetStore.defaultAppGroupIdentifier,
    sharedContainerOnly: Bool = false,
    fallbackDirectory: URL? = nil,
    fileManager: FileManager = .default
  ) {
    self.appGroupIdentifier = appGroupIdentifier
    self.sharedContainerOnly = sharedContainerOnly
    self.fallbackDirectory = fallbackDirectory
    self.explicitFileURL = nil
    self.fileManager = fileManager
  }

  public init(fileURL: URL, fileManager: FileManager = .default) throws {
    guard fileURL.isFileURL, fileURL.lastPathComponent == "snapshot.json" else {
      throw CertigoWidgetStoreError.invalidPath
    }
    self.appGroupIdentifier = ""
    self.sharedContainerOnly = false
    self.fallbackDirectory = nil
    self.explicitFileURL = fileURL
    self.fileManager = fileManager
  }

  public var location: CertigoWidgetStoreLocation {
    if explicitFileURL != nil { return .explicitFile }
    if appGroupDirectory() != nil { return .appGroup }
    if sharedContainerOnly { return .unavailable }
    return .localFallback
  }

  public func write(_ snapshot: CertigoWidgetSnapshot, now: Date = .now) throws {
    lock.lock()
    defer { lock.unlock() }
    do {
      let validated = try snapshot.validated()
      guard validated.isFresh(at: now) else { throw CertigoWidgetStoreError.staleSnapshot }
      let url = try snapshotURL()
      try fileManager.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let data = try encoder.encode(validated)
      guard data.count <= Self.maximumSnapshotBytes else {
        throw CertigoWidgetStoreError.oversizedSnapshot
      }
      try data.write(to: url, options: [.atomic])
      if explicitFileURL == nil {
        if !appGroupIdentifier.isEmpty,
          let suiteDefaults = UserDefaults(suiteName: appGroupIdentifier)
        {
          suiteDefaults.set(data, forKey: Self.userDefaultsSnapshotKey)
        }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsSnapshotKey)
      }
      #if os(iOS)
        do {
          try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
          )
        } catch {
          try? fileManager.removeItem(at: url)
          throw CertigoWidgetStoreError.protectionPolicy
        }
      #endif
    } catch let error as CertigoWidgetStoreError {
      throw error
    } catch let error as CertigoWidgetSnapshotError {
      switch error {
      case .invalid: throw CertigoWidgetStoreError.corruptSnapshot
      case .stale: throw CertigoWidgetStoreError.staleSnapshot
      }
    } catch {
      throw error
    }
  }

  public func read(now: Date = .now) throws -> CertigoWidgetSnapshot? {
    lock.lock()
    defer { lock.unlock() }
    let url = try snapshotURL()
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    let attributes = try fileManager.attributesOfItem(atPath: url.path)
#if os(iOS)
    guard FileProtectionPolicy.isFirstUnlock(attributes[.protectionKey]) else {
      throw CertigoWidgetStoreError.protectionPolicy
    }
#endif
    guard let fileSize = attributes[.size] as? NSNumber,
      fileSize.intValue <= Self.maximumSnapshotBytes
    else {
      throw CertigoWidgetStoreError.oversizedSnapshot
    }
    let snapshot: CertigoWidgetSnapshot
    do {
      snapshot = try JSONDecoder().decode(
        CertigoWidgetSnapshot.self, from: Data(contentsOf: url))
      _ = try snapshot.validated()
    } catch {
      throw CertigoWidgetStoreError.corruptSnapshot
    }
    guard snapshot.isFresh(at: now) else { throw CertigoWidgetStoreError.staleSnapshot }
    return snapshot
  }

  public func clear() throws {
    lock.lock()
    defer { lock.unlock() }
    if explicitFileURL == nil {
      if !appGroupIdentifier.isEmpty,
        let suiteDefaults = UserDefaults(suiteName: appGroupIdentifier)
      {
        suiteDefaults.removeObject(forKey: Self.userDefaultsSnapshotKey)
      }
      UserDefaults.standard.removeObject(forKey: Self.userDefaultsSnapshotKey)
    }
    let url = try snapshotURL()
    guard fileManager.fileExists(atPath: url.path) else { return }
    try fileManager.removeItem(at: url)
  }

  public func loadState(
    language: AppLanguage = .french,
    now: Date = .now
  ) -> CertigoWidgetLoadState {
    if let snapshot = try? read(now: now) {
      return .ready(snapshot)
    }
    if explicitFileURL == nil {
      var candidateData: [Data] = []
      if !appGroupIdentifier.isEmpty,
        let suiteDefaults = UserDefaults(suiteName: appGroupIdentifier),
        let data = suiteDefaults.data(forKey: Self.userDefaultsSnapshotKey)
      {
        candidateData.append(data)
      }
      if let stdData = UserDefaults.standard.data(forKey: Self.userDefaultsSnapshotKey) {
        candidateData.append(stdData)
      }
      for data in candidateData where data.count <= Self.maximumSnapshotBytes {
        if let decoded = try? JSONDecoder().decode(CertigoWidgetSnapshot.self, from: data),
          let validated = try? decoded.validated(),
          validated.isFresh(at: now)
        {
          return .ready(validated)
        }
      }
    }
    return .ready(CertigoWidgetSnapshot.defaultInitialSnapshot(language: language, now: now))
  }

  private func snapshotURL() throws -> URL {
    if let explicitFileURL { return explicitFileURL }
    if let directory = appGroupDirectory() {
      return directory.appendingPathComponent("snapshot.json", isDirectory: false)
    }
    guard !sharedContainerOnly else { throw CertigoWidgetStoreError.appGroupUnavailable }
    let directory: URL
    if let fallbackDirectory {
      directory = fallbackDirectory
    } else if let applicationSupport = fileManager.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first {
      directory = applicationSupport.appendingPathComponent("CertigoWidget", isDirectory: true)
    } else {
      throw CertigoWidgetStoreError.storageUnavailable
    }
    return directory.appendingPathComponent("snapshot.json", isDirectory: false)
  }

  private func appGroupDirectory() -> URL? {
    guard !appGroupIdentifier.isEmpty else { return nil }
    #if os(iOS) || os(macOS)
      let candidates: [String]
      if Self.supportedAppGroupIdentifiers.contains(appGroupIdentifier) {
        var ordered = [appGroupIdentifier]
        for group in Self.supportedAppGroupIdentifiers where !ordered.contains(group) {
          ordered.append(group)
        }
        candidates = ordered
      } else {
        candidates = [appGroupIdentifier]
      }
      for group in candidates {
        if let container = fileManager.containerURL(
          forSecurityApplicationGroupIdentifier: group
        ) {
          return container.appendingPathComponent("CertigoWidget", isDirectory: true)
        }
      }
      return nil
    #else
      return nil
    #endif
  }
}
