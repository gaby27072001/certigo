@_exported import BrandAssets
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

public enum PrismTextStyle: String, Codable, Hashable, CaseIterable, Sendable {
  case display, title1, title2, title3, headline, body, editorial, callout
  case subheadline, footnote, caption, code, codeSmall, numeric
    public static let caption1: Self = .caption
    public static let numericMono: Self = .numeric
    public static let codeMono: Self = .code
    public static let monoCode: Self = .codeSmall
}

public enum PrismMotionToken: String, Codable, Hashable, CaseIterable, Sendable {
  case quick, snappy, smooth, expressive
    public static let standard: Self = .smooth
}

public struct PrismResolvedMotion: Equatable, Sendable {
  public enum Curve: Equatable, Sendable { case easeOut, spring, keyframes }
  public let duration: Double
  public let curve: Curve
  public let opacityOnly: Bool
}

public enum PrismMotion {
  public static var allCases: [PrismMotionToken] { PrismMotionToken.allCases }
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

public enum PrismHapticToken: String, Codable, Hashable, CaseIterable, Sendable {
  case selection, correct, incorrectSoft, warning, declic
}

public enum PrismSoundToken: String, Codable, Hashable, CaseIterable, Sendable {
  case answer, declic, milestone
}

public enum PrismMaterialRole: String, Codable, Hashable, CaseIterable, Sendable {
  case navigationGlass, floatingControlGlass

  public func usesOpaqueSurface(reduceTransparency: Bool) -> Bool { reduceTransparency }
}

public enum PrismCelebrationLevel: Int, Codable, Hashable, CaseIterable, Sendable {
  case tick = 0
  case pulse = 1
  case refraction = 2
  case milestone = 3

  public func resolved(calmMode: Bool) -> Self {
    calmMode && rawValue > Self.pulse.rawValue ? .pulse : self
  }
}

extension PrismSpacing {
  public static let sm: CGFloat = s
  public static let md: CGFloat = m
  public static let lg: CGFloat = l
}

extension PrismRadius {
  public static let xs: CGFloat = 4
  public static let sm: CGFloat = s
  public static let md: CGFloat = m
  public static let lg: CGFloat = l
  public static let pill: CGFloat = 999
}

public enum PrismBorder {
  public static let hairline: CGFloat = 1
  public static let thin: CGFloat = 1
  public static let regular: CGFloat = 1
  public static let standard: CGFloat = 1.5
  public static let emphasis: CGFloat = 2
  public static let strong: CGFloat = 2
  public static let thick: CGFloat = 2
}

extension PrismTextStyle {
  public var usesMonospacedDigits: Bool {
    self == .code || self == .codeSmall || self == .numeric
  }
}

public typealias PrismMotionSpec = PrismResolvedMotion

extension PrismSize {
  public static let minTapTarget: CGFloat = minTouch
  public static let progressBarHeight: CGFloat = 8
}

extension PrismRadius {
  public static let button: CGFloat = m
  public static let card: CGFloat = l
  public static let chip: CGFloat = s
  public static let heroCard: CGFloat = xl
}

extension PrismSize {
  public static let pathNode: CGFloat = 64
  public static let pathNodeActive: CGFloat = 74
  public static let pathNodeRing: CGFloat = 88
  public static let pathNodeIcon: CGFloat = 26
  public static let pathNodeActiveIcon: CGFloat = 30
  public static let pathStageWidth: CGFloat = 345
  public static let pathStageHeight: CGFloat = 536
  public static let pathTrackStroke: CGFloat = 10
  public static let centerAIButton: CGFloat = 58
  public static let centerAIHalo: CGFloat = 66
  public static let centerAIIcon: CGFloat = 24
  public static let bottomBarHeight: CGFloat = 66
  public static let tabItemHeight: CGFloat = 50
  public static let optionBadge: CGFloat = 32
  public static let statIcon: CGFloat = 15
  public static let lipDepth: CGFloat = 5
  public static let brandFilterWidth: CGFloat = 72
}

extension PrismRadius {
  public static let pathNode: CGFloat = 32
  public static let pathNodeActive: CGFloat = 37
  public static let pathNodeRing: CGFloat = 44
  public static let centerAI: CGFloat = 21
  public static let centerAIHalo: CGFloat = 24
  public static let bottomBar: CGFloat = 33
  public static let unitBanner: CGFloat = 22
  public static let stepPill: CGFloat = 14
}

extension PrismSize {
  public static let mascotQuiz: CGFloat = 76
  public static let mascotPath: CGFloat = 84
  public static let mascotHero: CGFloat = 120
  public static let crestHero: CGFloat = 96
  public static let crestPedestal: CGFloat = 100
  public static let crestCard: CGFloat = 64
  public static let avatarLarge: CGFloat = 80
  public static let avatarEditBadge: CGFloat = 28
  public static let speechPointerWidth: CGFloat = 12
  public static let speechPointerHeight: CGFloat = 20
  public static let drawerWidth: CGFloat = 334
  public static let barometerTrackHeight: CGFloat = 12
  public static let barometerThresholdWidth: CGFloat = 3
  public static let barometerThresholdHeight: CGFloat = 28
  public static let carouselDotActive: CGFloat = 18
  public static let carouselDotInactive: CGFloat = 6
  public static let ringOuter: CGFloat = 108
  public static let ringMiddle: CGFloat = 82
  public static let ringInner: CGFloat = 56
  public static let heatmapCellWidth: CGFloat = 21
  public static let heatmapCellHeight: CGFloat = 16
  public static let podiumFirstHeight: CGFloat = 96
  public static let podiumSecondHeight: CGFloat = 76
  public static let podiumThirdHeight: CGFloat = 62
  public static let dividerThickness: CGFloat = 1
  public static let dividerHeight: CGFloat = 40
}

extension PrismRadius {
  public static let sheet: CGFloat = 32
  public static let mascotBubble: CGFloat = 20
  public static let crestPedestal: CGFloat = 28
}
