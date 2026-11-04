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

  /// Apple HIG Concentric Corner Radius Law: R_inner = max(8, R_outer - padding).
  public static func concentric(outer: CGFloat, padding: CGFloat) -> CGFloat {
    max(8, outer - padding)
  }
}

public enum PrismCorner: Equatable, Sendable {
  case continuous(CGFloat)
  case capsule
}

public enum PrismSize {
  public static let minTouch: CGFloat = 44
  public static let primaryButtonHeight: CGFloat = 52
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
  public static let bottomBarHeight: CGFloat = 64
  public static let tabItemHeight: CGFloat = 52
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
  public static let bottomBar: CGFloat = 32
  public static let bottomBarDroplet: CGFloat = concentric(outer: 32, padding: 6)
  public static let unitBanner: CGFloat = 24
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
  public static let celebrationJumpOffset: CGFloat = 18
}

extension PrismMotion {
  public static var allAnimationPresets: [CertiGoAnimationPresetID] {
    CertiGoAnimationPresetID.allCases
  }

  public static func resolve(
    _ preset: CertiGoAnimationPresetID, reduceMotion: Bool
  ) -> PrismResolvedMotion {
    preset.resolved(reduceMotion: reduceMotion)
  }
}

extension PrismRadius {
  public static let sheet: CGFloat = 32
  public static let mascotBubble: CGFloat = 20
  public static let crestPedestal: CGFloat = 28
}

/// Les 6 tokens typographiques sémantiques officiels CertiGo V3 (+ 1 token technique CLI).
/// Règle d'or par écran : max 4 tokens de taille distincts et 2 graisses actives.
public enum CertiGoTypeToken: String, Codable, Hashable, CaseIterable, Sendable {
  /// 28pt Bold Rounded : Chiffre Hero, score final d'examen, titre de célébration majeure (max 1/écran).
  case displayHero
  /// 22pt Bold Rounded : Titre d'écran, titre de sheet modale, question principale d'onboarding.
  case screenTitle
  /// 17pt SemiBold Rounded : Titre de carte, bannière d'unité, en-tête de section, énoncé de question QCM.
  case sectionCardTitle
  /// 16pt Regular Rounded : Corps de lecture, scénario QCM, explication Coach IA.
  case bodyQuestion
  /// 16pt Medium Rounded : Proposition de réponse QCM (choix A/B/C/D) et ligne interactive de lecture.
  case bodyQuestionMedium
  /// 14pt SemiBold Rounded : Bouton CTA, pilule 1 ligne, onglet segmenté, contrôle de navigation.
  case controlButtonPill
  /// 12pt SemiBold Rounded : Badge, tag de certification, compteur de barre supérieure, légende, eyebrow.
  case captionBadge
  /// 13pt Medium Monospaced : Blocs de code/terminal CLI et jetons techniques uniquement.
  case codeMono

  public var pointSize: CGFloat {
    switch self {
    case .displayHero: return 28
    case .screenTitle: return 22
    case .sectionCardTitle: return 17
    case .bodyQuestion, .bodyQuestionMedium: return 16
    case .controlButtonPill: return 14
    case .codeMono: return 13
    case .captionBadge: return 12
    }
  }

  public var tracking: CGFloat {
    switch self {
    case .displayHero: return -0.5
    case .screenTitle: return -0.3
    case .sectionCardTitle: return -0.2
    case .bodyQuestion, .bodyQuestionMedium, .controlButtonPill, .codeMono: return 0.0
    case .captionBadge: return 0.2
    }
  }

  public var lineSpacing: CGFloat {
    switch self {
    case .displayHero: return 4
    case .screenTitle: return 4
    case .sectionCardTitle: return 5
    case .bodyQuestion, .bodyQuestionMedium: return 6
    case .controlButtonPill: return 4
    case .codeMono: return 5
    case .captionBadge: return 3
    }
  }
}

#if canImport(SwiftUI)
  import SwiftUI

  extension CertiGoTypeToken {
    public var weight: Font.Weight {
      switch self {
      case .displayHero, .screenTitle: return .bold
      case .sectionCardTitle, .controlButtonPill, .captionBadge: return .semibold
      case .bodyQuestionMedium, .codeMono: return .medium
      case .bodyQuestion: return .regular
      }
    }

    public var design: Font.Design {
      self == .codeMono ? .monospaced : .default
    }

    public var relativeTextStyle: Font.TextStyle {
      switch self {
      case .displayHero: return .largeTitle
      case .screenTitle: return .title2
      case .sectionCardTitle: return .headline
      case .bodyQuestion, .bodyQuestionMedium: return .body
      case .controlButtonPill: return .subheadline
      case .codeMono: return .footnote
      case .captionBadge: return .caption
      }
    }

    public func font(scaledSize: CGFloat? = nil, tabularDigits: Bool = false) -> Font {
      let base = Font.system(
        size: scaledSize ?? pointSize,
        weight: weight,
        design: design
      )
      return (tabularDigits || self == .codeMono) ? base.monospacedDigit() : base
    }
  }

  public enum PrismTypography {
    /// Point d'entrée officiel CertiGo V3 (Colonne 2 - Option A : 100 % Apple HIG Pur SF Pro `Font.Design.default`).
    public static func token(_ token: CertiGoTypeToken, tabularDigits: Bool = false) -> Font {
      token.font(tabularDigits: tabularDigits)
    }

    /// Résout de façon déterministe tout appel `(size, style, monospaced)` vers l'échelle officielle Apple HIG `SF Pro` (`Font.Design.default`).
    public static func resolveToken(
      size: CGFloat,
      style: String?,
      monospaced: Bool = false
    ) -> CertiGoTypeToken {
      if monospaced {
        return .codeMono
      }
      let normalized = (style ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      if size >= 26 {
        return .displayHero
      }
      if size >= 20 {
        return .screenTitle
      }
      if size >= 17 {
        if normalized == "regular" {
          return .bodyQuestion
        }
        return .sectionCardTitle
      }
      if size >= 15 {
        if size >= 16 && (normalized == "black" || normalized == "heavy" || normalized == "extra bold" || normalized == "extrabold" || normalized == "bold") {
          return .sectionCardTitle
        }
        if normalized == "medium" || normalized == "semi bold" || normalized == "semibold" {
          return .bodyQuestionMedium
        }
        return .bodyQuestion
      }
      if size >= 13 {
        if normalized == "regular" && size >= 14 {
          return .bodyQuestion
        }
        if normalized == "regular" || normalized == "medium" {
          return .captionBadge
        }
        return .controlButtonPill
      }
      return .captionBadge
    }

    /// 100 % Apple HIG Pur (`SF Pro` standard `Font.Design.default`, zéro `.rounded`, zéro `.black`/`.heavy`, plancher strict `12 pt`).
    public static func figmaFont(
      size: CGFloat,
      style: String?,
      monospaced: Bool = false
    ) -> Font {
      if monospaced {
        return Font.system(size: 13, weight: .medium, design: .monospaced).monospacedDigit()
      }
      let normalized = (style ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      // Apple HIG Large (Default) scale:
      // Title 1: 28pt Bold, Title 2: 22pt Bold, Headline: 17pt Semibold, Body: 17pt Regular, Callout: 16pt Regular/Medium, Subhead: 15pt Semibold, Footnote: 13pt Semibold, Caption 1: 12pt Semibold.
      let higPointSize: CGFloat
      let higWeight: Font.Weight
      if size >= 26 {
        higPointSize = 28
        higWeight = .bold
      } else if size >= 20 {
        higPointSize = 22
        higWeight = .bold
      } else if size >= 17 {
        higPointSize = 17
        higWeight = (normalized == "regular") ? .regular : .semibold
      } else if size >= 16 {
        if normalized == "black" || normalized == "heavy" || normalized == "extra bold" || normalized == "extrabold" || normalized == "bold" {
          higPointSize = 17
          higWeight = .semibold
        } else if normalized == "medium" || normalized == "semi bold" || normalized == "semibold" {
          higPointSize = 16
          higWeight = .medium
        } else {
          higPointSize = 16
          higWeight = .regular
        }
      } else if size >= 15 {
        if normalized == "regular" {
          higPointSize = 16
          higWeight = .regular
        } else if normalized == "medium" {
          higPointSize = 16
          higWeight = .medium
        } else {
          higPointSize = 15
          higWeight = .semibold
        }
      } else if size >= 14 {
        if normalized == "regular" {
          higPointSize = 16
          higWeight = .regular
        } else {
          higPointSize = 15
          higWeight = .semibold
        }
      } else if size >= 13 {
        higPointSize = 13
        higWeight = (normalized == "regular") ? .regular : .semibold
      } else {
        higPointSize = 12
        higWeight = .semibold
      }
      let effectivePointSize = max(higPointSize, size)
      return Font.system(size: effectivePointSize, weight: higWeight, design: .default)
    }
  }

  private struct CertiGoTypographyModifier: ViewModifier {
    let token: CertiGoTypeToken
    let tabularDigits: Bool
    @ScaledMetric private var scaledSize: CGFloat

    init(token: CertiGoTypeToken, tabularDigits: Bool = false) {
      self.token = token
      self.tabularDigits = tabularDigits
      self._scaledSize = ScaledMetric(
        wrappedValue: token.pointSize,
        relativeTo: token.relativeTextStyle
      )
    }

    func body(content: Content) -> some View {
      content
        .font(token.font(scaledSize: scaledSize, tabularDigits: tabularDigits))
        .tracking(token.tracking)
        .lineSpacing(token.lineSpacing)
    }
  }

  extension View {
    /// Applique un token typographique officiel CertiGo V3 avec Dynamic Type, tracking et interlignage.
    public func certigoTypography(
      _ token: CertiGoTypeToken,
      tabularDigits: Bool = false
    ) -> some View {
      modifier(CertiGoTypographyModifier(token: token, tabularDigits: tabularDigits))
    }
  }
#else
  public enum PrismTypography {
    public static func resolveToken(
      size: CGFloat,
      style: String?,
      monospaced: Bool = false
    ) -> CertiGoTypeToken {
      if monospaced { return .codeMono }
      let normalized = (style ?? "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      if size >= 26 { return .displayHero }
      if size >= 21 { return .screenTitle }
      if size >= 17 { return .sectionCardTitle }
      if size >= 15 {
        if size >= 16 && (normalized == "black" || normalized == "heavy" || normalized == "extra bold" || normalized == "extrabold" || normalized == "bold") {
          return .sectionCardTitle
        }
        if normalized == "medium" || normalized == "semi bold" || normalized == "semibold" {
          return .bodyQuestionMedium
        }
        return .bodyQuestion
      }
      if size >= 13 {
        if normalized == "regular" && size >= 14 { return .bodyQuestion }
        if normalized == "regular" || normalized == "medium" { return .captionBadge }
        return .controlButtonPill
      }
      return .captionBadge
    }
  }
#endif
