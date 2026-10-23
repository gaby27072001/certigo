import Foundation

public enum PrismSnapshotError: Error, Equatable {
  case invalidDimensions
  case invalidPixelCount
  case renderingFailed
}

/// Canonical, premultiplied RGBA8 pixels. Comparison deliberately ignores PNG encoder metadata.
public struct PrismSnapshot: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public let pixels: Data

  public init(width: Int, height: Int, pixels: Data) throws {
    guard width > 0, height > 0 else { throw PrismSnapshotError.invalidDimensions }
    let area = width.multipliedReportingOverflow(by: height)
    let bytes = area.partialValue.multipliedReportingOverflow(by: 4)
    guard !area.overflow, !bytes.overflow, bytes.partialValue == pixels.count else {
      throw PrismSnapshotError.invalidPixelCount
    }
    self.width = width
    self.height = height
    self.pixels = pixels
  }

  /// FNV-1a is a stable diagnostic fingerprint, not an integrity/security hash.
  public var fingerprint: String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    let dimensions = "\(width)x\(height):".utf8
    for byte in dimensions {
      hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
    }
    for byte in pixels {
      hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
    }
    return String(hash, radix: 16)
  }

  public func matches(_ reference: Self) -> Bool { self == reference }
}

#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  @MainActor
  public enum PrismSnapshotHarness {
    public struct Configuration {
      public let size: CGSize
      public let appearance: PrismAppearance
      public let dynamicType: DynamicTypeSize
      public let locale: Locale

      public init(
        size: CGSize, appearance: PrismAppearance = .light,
        dynamicType: DynamicTypeSize = .large, locale: Locale = Locale(identifier: "fr")
      ) {
        self.size = size
        self.appearance = appearance
        self.dynamicType = dynamicType
        self.locale = locale
      }
    }

    public static func render<V: View>(
      _ view: V, configuration: Configuration
    ) throws -> PrismSnapshot {
      guard configuration.size.width.isFinite, configuration.size.height.isFinite,
        configuration.size.width > 0, configuration.size.height > 0,
        configuration.size.width <= 8192, configuration.size.height <= 8192
      else { throw PrismSnapshotError.invalidDimensions }
      let renderer = ImageRenderer(
        content:
          view
          .environment(\.colorScheme, configuration.appearance.isDark ? .dark : .light)
          .environment(
            \.colorSchemeContrast,
            configuration.appearance.isHighContrast ? .increased : .standard
          )
          .environment(\.dynamicTypeSize, configuration.dynamicType)
          .environment(\.locale, configuration.locale)
          .environment(\.accessibilityReduceMotion, true)
          .environment(\.accessibilityReduceTransparency, true)
          .frame(width: configuration.size.width, height: configuration.size.height))
      renderer.scale = 1
      renderer.isOpaque = true
      guard let image = renderer.cgImage else { throw PrismSnapshotError.renderingFailed }
      return try snapshot(image)
    }

    public static func decodePNG(_ data: Data) throws -> PrismSnapshot {
      guard let image = UIImage(data: data)?.cgImage else {
        throw PrismSnapshotError.renderingFailed
      }
      return try snapshot(image)
    }

    public static func pngData(_ snapshot: PrismSnapshot) throws -> Data {
      guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let provider = CGDataProvider(data: snapshot.pixels as CFData),
        let image = CGImage(
          width: snapshot.width, height: snapshot.height, bitsPerComponent: 8,
          bitsPerPixel: 32, bytesPerRow: snapshot.width * 4,
          space: space,
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
        let data = UIImage(cgImage: image).pngData()
      else { throw PrismSnapshotError.renderingFailed }
      return data
    }

    private static func snapshot(_ image: CGImage) throws -> PrismSnapshot {
      var pixels = Data(count: image.width * image.height * 4)
      let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: buffer.baseAddress, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
      }
      guard rendered else { throw PrismSnapshotError.renderingFailed }
      return try PrismSnapshot(width: image.width, height: image.height, pixels: pixels)
    }
  }
#endif
