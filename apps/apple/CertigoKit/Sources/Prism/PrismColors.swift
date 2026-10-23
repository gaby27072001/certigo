import Foundation

public enum PrismAppearance: String, Codable, Hashable, CaseIterable, Sendable {
  case light, dark, highContrastLight, highContrastDark

  public var isDark: Bool { self == .dark || self == .highContrastDark }
  public var isHighContrast: Bool { self == .highContrastLight || self == .highContrastDark }
}

public struct PrismRGBA: Equatable, Sendable {
  public let red: Double
  public let green: Double
  public let blue: Double
  public let alpha: Double

  public init(hex: UInt32, alpha: Double = 1) {
    precondition((0...1).contains(alpha))
    red = Double((hex >> 16) & 255) / 255
    green = Double((hex >> 8) & 255) / 255
    blue = Double(hex & 255) / 255
    self.alpha = alpha
  }

  private init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
    alpha = 1
  }

  public func composited(over background: Self) -> Self {
    precondition(background.alpha == 1)
    return .init(
      red: red * alpha + background.red * (1 - alpha),
      green: green * alpha + background.green * (1 - alpha),
      blue: blue * alpha + background.blue * (1 - alpha))
  }

  public var luminance: Double {
    func linear(_ value: Double) -> Double {
      value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  public func contrastRatio(over background: Self) -> Double {
    let foreground = composited(over: background).luminance
    let back = background.luminance
    return (max(foreground, back) + 0.05) / (min(foreground, back) + 0.05)
  }
}

public enum PrismColorRole: String, Codable, Hashable, CaseIterable, Sendable {
  case canvas, surface, surfaceRaised, surfaceArtifact
  case textPrimary, textSecondary, textTertiary, separator
  case accent, accentFill, onAccent, positive, negative, caution, brandPlate

  /// Reference sRGB values for portable checks. Apple semantic neutrals resolve through UIKit.
  public func rgba(in appearance: PrismAppearance) -> PrismRGBA {
    let values: [UInt32]
    switch self {
    case .canvas: values = [0xF2F2F7, 0x000000, 0xF2F2F7, 0x000000]
    case .surface: values = [0xFFFFFF, 0x1C1C1E, 0xFFFFFF, 0x1C1C1E]
    case .surfaceRaised: values = [0xF2F2F7, 0x2C2C2E, 0xF2F2F7, 0x2C2C2E]
    case .surfaceArtifact: values = [0xF5F6F8, 0x151517, 0xEEF0F3, 0x0E0E10]
    case .textPrimary: values = [0x000000, 0xFFFFFF, 0x000000, 0xFFFFFF]
    case .textSecondary: values = [0x3C3C43, 0xEBEBF5, 0x3C3C43, 0xEBEBF5]
    case .textTertiary: values = [0x3C3C43, 0xEBEBF5, 0x3C3C43, 0xEBEBF5]
    case .separator: values = [0x3C3C43, 0x545458, 0x3C3C43, 0x545458]
    case .accent: values = [0x4338CA, 0x8E8CFF, 0x4338CA, 0xB4B2FF]
    case .accentFill: values = [0x4338CA, 0x5B52F0, 0x3A30B5, 0x5B52F0]
    case .onAccent: values = [0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF]
    case .positive: values = [0x1A7F37, 0x3FB950, 0x135D28, 0x6BCD79]
    case .negative: values = [0xB42318, 0xFF7B72, 0x9D1F15, 0xFF9F98]
    case .caution: values = [0x8A5A00, 0xE3B341, 0x704900, 0xE3B341]
    case .brandPlate: values = [0xFFFFFF, 0xE5E5EA, 0xFFFFFF, 0xE5E5EA]
    }
    let index = PrismAppearance.allCases.firstIndex(of: appearance)!
    let alpha: Double
    switch self {
    case .textSecondary: alpha = appearance.isHighContrast ? 0.8 : 0.6
    case .textTertiary: alpha = appearance.isHighContrast ? 0.7 : 0.3
    case .separator: alpha = appearance.isHighContrast ? 0.65 : 0.29
    default: alpha = 1
    }
    return PrismRGBA(hex: values[index], alpha: alpha)
  }
}

public enum PrismRegion: String, Codable, Hashable, CaseIterable, Sendable {
  case cloud, ai, data, security, network, devops, code, systems

  public func rgba(in appearance: PrismAppearance) -> PrismRGBA {
    let values: [UInt32]
    switch self {
    case .cloud: values = [0x0A5FC2, 0x5AA9FF, 0x0850A2, 0x80BDFF]
    case .ai: values = [0x7A35E8, 0xB996FF, 0x6319D9, 0xC7AAFF]
    case .data: values = [0x0B6E87, 0x3DD5F3, 0x09596D, 0x3DD5F3]
    case .security: values = [0xC0263D, 0xFF7A8A, 0x9C1F32, 0xFF9EA9]
    case .network: values = [0x0B7268, 0x3FD9C4, 0x095B53, 0x3FD9C4]
    case .devops: values = [0xB8430B, 0xFF9F5A, 0x8F3409, 0xFFA25F]
    case .code: values = [0x8F5A00, 0xF5C64A, 0x734800, 0xF5C64A]
    case .systems: values = [0x167A3B, 0x5BDB8A, 0x115E2D, 0x5BDB8A]
    }
    return PrismRGBA(hex: values[PrismAppearance.allCases.firstIndex(of: appearance)!])
  }

  public var soft: PrismRegionSoft { PrismRegionSoft(region: self) }
}

public struct PrismRegionSoft: Equatable, Sendable {
  public let region: PrismRegion

  public func rgba(in appearance: PrismAppearance) -> PrismRGBA {
    let color = region.rgba(in: appearance)
    let hex =
      UInt32((color.red * 255).rounded()) << 16
      | UInt32((color.green * 255).rounded()) << 8
      | UInt32((color.blue * 255).rounded())
    return PrismRGBA(hex: hex, alpha: appearance.isDark ? 0.2 : 0.12)
  }
}

public enum PrismSyntax: String, Codable, Hashable, CaseIterable, Sendable {
  case plain, keyword, string, comment, number, type, flaggedLineBackground

  public func rgba(in appearance: PrismAppearance) -> PrismRGBA {
    let values: [UInt32]
    switch self {
    case .plain: values = [0x1D1D1F, 0xE6E6EA, 0x1D1D1F, 0xE6E6EA]
    case .keyword: values = [0xA0287A, 0xFF7AC6, 0x862266, 0xFF9ED5]
    case .string: values = [0x1F7A1F, 0x7EE787, 0x165A16, 0x7EE787]
    case .comment: values = [0x5E6470, 0x9AA3AF, 0x484D56, 0xB5BDC8]
    case .number: values = [0x9A4D00, 0xFFB86B, 0x793C00, 0xFFB86B]
    case .type: values = [0x0B5FA8, 0x79C0FF, 0x094E8A, 0x79C0FF]
    case .flaggedLineBackground: values = [0xFDE7E9, 0x4A1D22, 0xFDE7E9, 0x4A1D22]
    }
    return PrismRGBA(hex: values[PrismAppearance.allCases.firstIndex(of: appearance)!])
  }
}

extension PrismColorRole {
  public static let accentPrimary: Self = .accent
  public static let accentSubtle: Self = .surfaceRaised
  public static let surfaceElevated: Self = .surfaceRaised
  public static let borderSubtle: Self = .separator
  public static let borderStrong: Self = .textPrimary
  public static let positiveSubtle: Self = .surfaceRaised
  public static let cautionSubtle: Self = .surfaceRaised
  public static let negativeSubtle: Self = .surfaceRaised
  public static let inkPrimary: Self = .textPrimary
  public static let inkSecondary: Self = .textSecondary
  public static let inkMuted: Self = .textTertiary
}

extension PrismRegion {
  public static let azure: Self = .cloud

  public var displayName: String {
    switch self {
    case .cloud: "Cloud"
    case .ai: "AI"
    case .data: "Data"
    case .security: "Security"
    case .network: "Network"
    case .devops: "DevOps"
    case .code: "Code"
    case .systems: "Systems"
    }
  }

  public var sfSymbolFallback: String {
    switch self {
    case .cloud: "cloud.fill"
    case .ai: "sparkles"
    case .data: "cylinder.split.1x2.fill"
    case .security: "lock.shield.fill"
    case .network: "network"
    case .devops: "gearshape.2.fill"
    case .code: "chevron.left.forwardslash.chevron.right"
    case .systems: "cpu.fill"
    }
  }
}
