import Foundation
import CertigoDomain

public enum CertigoWidgetStoreLocation: Equatable, Sendable {
  case appGroup
  case localFallback
  case explicitFile
  case unavailable
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
  public static let defaultAppGroupIdentifier = "group.com.certigo.native"
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
    let url = try snapshotURL()
    guard fileManager.fileExists(atPath: url.path) else { return }
    try fileManager.removeItem(at: url)
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
      return fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )?.appendingPathComponent("CertigoWidget", isDirectory: true)
    #else
      return nil
    #endif
  }
}
