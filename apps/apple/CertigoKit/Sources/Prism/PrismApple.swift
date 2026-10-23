#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  public enum PrismColor {
    public static func color(_ role: PrismColorRole) -> Color {
      switch role {
      case .canvas: return Color(uiColor: .systemGroupedBackground)
      case .surface: return Color(uiColor: .secondarySystemGroupedBackground)
      case .surfaceRaised: return Color(uiColor: .tertiarySystemGroupedBackground)
      case .textPrimary: return Color(uiColor: .label)
      case .textSecondary: return Color(uiColor: .secondaryLabel)
      case .textTertiary: return Color(uiColor: .tertiaryLabel)
      case .separator: return Color(uiColor: .separator)
      default: return Color(role.rawValue, bundle: .module)
      }
    }

    public static let canvas = color(.canvas)
    public static let surface = color(.surface)
    public static let surfaceRaised = color(.surfaceRaised)
    public static let surfaceArtifact = color(.surfaceArtifact)
    public static let textPrimary = color(.textPrimary)
    public static let textSecondary = color(.textSecondary)
    public static let textTertiary = color(.textTertiary)
    public static let separator = color(.separator)
    public static let accent = color(.accent)
    public static let accentFill = color(.accentFill)
    public static let onAccent = color(.onAccent)
    public static let positive = color(.positive)
    public static let negative = color(.negative)
    public static let caution = color(.caution)
    public static let brandPlate = color(.brandPlate)
    public static let accentPrimary = accent
    public static let accentSubtle = surfaceRaised
    public static let borderStrong = textPrimary
    public static let borderSubtle = separator
    public static let surfaceElevated = surfaceRaised
    public static let surfacePrimary = surface
    public static let surfaceSecondary = surfaceRaised
    public static let inkPrimary = textPrimary
    public static let inkSecondary = textSecondary
    public static let inkMuted = textTertiary
    public static let brandPrimary = accent
    public static let feedbackInfo = accent
    public static let feedbackSuccess = positive
    public static let feedbackWarning = caution
    public static let danger = negative
    public static let engage = accent
    public static let engageSoft = surfaceRaised
    public static let focus = accent
    public static let focusSoft = surfaceRaised
    public static let info = PrismRegion.cloud.color
    public static let infoSoft = surfaceRaised
    public static let mastery = PrismRegion.ai.color
    public static let masterySoft = surfaceRaised
    public static let success = positive
    public static let successSoft = surfaceRaised
    public static let warning = caution
  }

  public typealias PrismSemanticColor = Color
  public typealias PrismColorScheme = ColorScheme

  extension Color {
    public func color(in scheme: ColorScheme) -> Color { self }
  }

  extension PrismRegion {
    public var accent: Color { color }
  }

  extension PrismRegion {
    public var color: Color { Color("region.\(rawValue)", bundle: .module) }
  }

  extension PrismRegionSoft {
    public func color(in scheme: ColorScheme) -> Color {
      region.color.opacity(scheme == .dark ? 0.2 : 0.12)
    }
  }

  extension PrismSyntax {
    public var color: Color { Color("syntax.\(rawValue)", bundle: .module) }
  }

  extension PrismTextStyle {
    /// `display` is scaled relative to largeTitle rather than a fixed-point feature font.
    public func font(displaySize: CGFloat = 40) -> Font {
      switch self {
      case .display: .system(size: displaySize, weight: .bold)
      case .title1: .title
      case .title2: .title2
      case .title3: .title3
      case .headline: .headline
      case .body: .body
      case .editorial: .system(.body, design: .serif)
      case .callout: .callout
      case .subheadline: .subheadline
      case .footnote: .footnote
      case .caption: .caption
      case .code: .system(.body, design: .monospaced).monospacedDigit()
      case .codeSmall: .system(.callout, design: .monospaced).monospacedDigit()
      case .numeric: .body.monospacedDigit()
      }
    }
  }

  private struct PrismTextStyleModifier: ViewModifier {
    let style: PrismTextStyle
    @ScaledMetric(relativeTo: .largeTitle) private var displaySize: CGFloat = 40

    func body(content: Content) -> some View { content.font(style.font(displaySize: displaySize)) }
  }

  extension View {
    public func prismTextStyle(_ style: PrismTextStyle) -> some View {
      modifier(PrismTextStyleModifier(style: style))
    }
  }

  extension PrismResolvedMotion {
    public var animation: Animation {
      switch curve {
      case .easeOut: .easeOut(duration: duration)
      case .spring: .spring(response: duration, dampingFraction: 1)
      case .keyframes: .easeInOut(duration: duration)
      }
    }
  }

  extension PrismHapticToken {
    /// The custom Declic pattern is introduced with celebrations; success is its native fallback.
    public var sensoryFeedback: SensoryFeedback {
      switch self {
      case .selection: .selection
      case .correct, .declic: .success
      case .incorrectSoft: .impact(weight: .light)
      case .warning: .warning
      }
    }
  }
#endif
