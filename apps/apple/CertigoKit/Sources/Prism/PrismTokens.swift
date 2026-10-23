import Foundation

public enum PrismSpacing {
  public static let xxs: CGFloat = 2
  public static let xs: CGFloat = 4
  public static let s: CGFloat = 8
  public static let m: CGFloat = 12
  public static let l: CGFloat = 16
  public static let xl: CGFloat = 20
  public static let xxl: CGFloat = 24
  public static let xxxl: CGFloat = 32
  public static let huge: CGFloat = 48
  public static let giant: CGFloat = 64
}

public enum PrismRadius {
  public static let s: CGFloat = 8
  public static let m: CGFloat = 12
  public static let l: CGFloat = 16
  public static let xl: CGFloat = 24
  public static let capsule = PrismCorner.capsule
}

public enum PrismCorner: Equatable, Sendable {
  case continuous(CGFloat)
  case capsule
}

public enum PrismSize {
  public static let minTouch: CGFloat = 44
  public static let primaryButtonHeight: CGFloat = 50
  public static let readableWidth: CGFloat = 672
  public static let brandS: CGFloat = 20
  public static let brandM: CGFloat = 28
  public static let brandL: CGFloat = 40
  public static let brandXL: CGFloat = 56
}

public enum PrismTextStyle: String, CaseIterable, Sendable {
  case display, title1, title2, title3, headline, body, editorial, callout
  case subheadline, footnote, caption, code, codeSmall, numeric
}

public enum PrismMotionToken: String, CaseIterable, Sendable {
  case quick, snappy, smooth, expressive
}

public struct PrismResolvedMotion: Equatable, Sendable {
  public enum Curve: Equatable, Sendable { case easeOut, spring, keyframes }
  public let duration: Double
  public let curve: Curve
  public let opacityOnly: Bool
}

public enum PrismMotion {
  /// Selection feedback, card orientation, spatial continuity, earned celebration respectively.
  public static func resolve(
    _ token: PrismMotionToken, reduceMotion: Bool
  ) -> PrismResolvedMotion {
    if reduceMotion {
      return .init(
        duration: token == .quick ? 0.15 : token == .expressive ? 0.3 : 0.2,
        curve: .easeOut, opacityOnly: true)
    }
    switch token {
    case .quick: return .init(duration: 0.15, curve: .easeOut, opacityOnly: true)
    case .snappy: return .init(duration: 0.3, curve: .spring, opacityOnly: false)
    case .smooth: return .init(duration: 0.45, curve: .spring, opacityOnly: false)
    case .expressive: return .init(duration: 1.2, curve: .keyframes, opacityOnly: false)
    }
  }
}

public enum PrismHapticToken: String, CaseIterable, Sendable {
  case selection, correct, incorrectSoft, warning, declic
}

public enum PrismSoundToken: String, CaseIterable, Sendable {
  case answer, declic, milestone
}

public enum PrismMaterialRole: String, CaseIterable, Sendable {
  case navigationGlass, floatingControlGlass

  public func usesOpaqueSurface(reduceTransparency: Bool) -> Bool { reduceTransparency }
}

public enum PrismCelebrationLevel: Int, CaseIterable, Sendable {
  case tick = 0
  case pulse = 1
  case refraction = 2
  case milestone = 3

  public func resolved(calmMode: Bool) -> Self {
    calmMode && rawValue > Self.pulse.rawValue ? .pulse : self
  }
}
