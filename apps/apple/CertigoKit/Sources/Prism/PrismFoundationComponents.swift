import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit
#endif

// MARK: - 1. PrismText Model

public struct PrismTextConfiguration: Equatable, Hashable, Sendable {
    public let text: String
    public let style: PrismTextStyle
    public let role: PrismColorRole
    public let lineLimit: Int?
    public let isMonospacedDigits: Bool

    public init(
        text: String,
        style: PrismTextStyle = .body,
        role: PrismColorRole = .textPrimary,
        lineLimit: Int? = nil,
        isMonospacedDigits: Bool = false
    ) {
        self.text = text
        self.style = style
        self.role = role
        self.lineLimit = lineLimit
        self.isMonospacedDigits = isMonospacedDigits || style.usesMonospacedDigits
    }
}

// MARK: - 2. PrismGlyph & PrismIcon Models (§19, §22)

public enum PrismConceptStateGlyph: String, CaseIterable, Codable, Hashable, Sendable {
    case undiscovered
    case discovered
    case practicing
    case anchored
    case mastered

    public var assetName: String {
        "certigo.concept.\(rawValue)"
    }

    public var sfSymbolFallback: String {
        switch self {
        case .undiscovered:
            return "circle.dashed"
        case .discovered:
            return "sparkle"
        case .practicing:
            return "arrow.triangle.2.circlepath.circle"
        case .anchored:
            return "checkmark.circle"
        case .mastered:
            return "checkmark.seal.fill"
        }
    }
}

public enum PrismGlyph: RawRepresentable, CaseIterable, Codable, Hashable, Equatable, Sendable {
    case region(PrismRegion)
    case conceptState(PrismConceptStateGlyph)
    case misconception
    case declic
    case route

    public typealias RawValue = String

    public static var allCases: [PrismGlyph] {
        let regionGlyphs = PrismRegion.allCases.map(PrismGlyph.region)
        let conceptGlyphs = PrismConceptStateGlyph.allCases.map(PrismGlyph.conceptState)
        return regionGlyphs + conceptGlyphs + [.misconception, .declic, .route]
    }

    public init?(rawValue: String) {
        if rawValue == "certigo.misconception" || rawValue == "misconception" {
            self = .misconception
            return
        }
        if rawValue == "certigo.declic" || rawValue == "declic" {
            self = .declic
            return
        }
        if rawValue == "certigo.route" || rawValue == "route" {
            self = .route
            return
        }
        for region in PrismRegion.allCases {
            if rawValue == "certigo.region.\(region.rawValue)" || rawValue == "region.\(region.rawValue)" {
                self = .region(region)
                return
            }
        }
        for state in PrismConceptStateGlyph.allCases {
            if rawValue == state.assetName || rawValue == "conceptState.\(state.rawValue)" {
                self = .conceptState(state)
                return
            }
        }
        return nil
    }

    public var rawValue: String {
        assetName
    }

    public var assetName: String {
        switch self {
        case let .region(region):
            return "certigo.region.\(region.rawValue)"
        case let .conceptState(state):
            return state.assetName
        case .misconception:
            return "certigo.misconception"
        case .declic:
            return "certigo.declic"
        case .route:
            return "certigo.route"
        }
    }

    public var sfSymbolFallback: String {
        switch self {
        case let .region(region):
            return region.sfSymbolFallback
        case let .conceptState(state):
            return state.sfSymbolFallback
        case .misconception:
            return "exclamationmark.triangle.fill"
        case .declic:
            return "sparkles"
        case .route:
            return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}

public enum PrismIconSource: Equatable, Hashable, Sendable {
    case system(String)
    case glyph(PrismGlyph)

    public var sfSymbolName: String {
        switch self {
        case let .system(name):
            return name
        case let .glyph(glyph):
            return glyph.sfSymbolFallback
        }
    }

    public var customAssetName: String? {
        switch self {
        case .system:
            return nil
        case let .glyph(glyph):
            return glyph.assetName
        }
    }
}

public struct PrismIconConfiguration: Equatable, Hashable, Sendable {
    public let source: PrismIconSource
    public let style: PrismTextStyle
    public let role: PrismColorRole
    public let accessibilityLabel: String?

    public var isDecorative: Bool {
        guard let accessibilityLabel else { return true }
        return accessibilityLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        source: PrismIconSource,
        style: PrismTextStyle = .body,
        role: PrismColorRole = .textPrimary,
        accessibilityLabel: String? = nil
    ) {
        self.source = source
        self.style = style
        self.role = role
        self.accessibilityLabel = accessibilityLabel
    }

    public init(
        systemName: String,
        style: PrismTextStyle = .body,
        role: PrismColorRole = .textPrimary,
        accessibilityLabel: String? = nil
    ) {
        self.init(
            source: .system(systemName),
            style: style,
            role: role,
            accessibilityLabel: accessibilityLabel
        )
    }

    public init(
        glyph: PrismGlyph,
        style: PrismTextStyle = .body,
        role: PrismColorRole = .textPrimary,
        accessibilityLabel: String? = nil
    ) {
        self.init(
            source: .glyph(glyph),
            style: style,
            role: role,
            accessibilityLabel: accessibilityLabel
        )
    }
}

// MARK: - 3. PrismButtonVariant & PrismButtonMetrics (§19)

public enum PrismButtonVariant: String, CaseIterable, Codable, Hashable, Sendable {
    case primary
    case secondary
    case tertiary
    case destructive
    case inline
}

public struct PrismButtonMetrics: Equatable, Hashable, Sendable {
    public let variant: PrismButtonVariant
    public let isLoading: Bool
    public let isEnabled: Bool
    public let minHeight: CGFloat
    public let horizontalPadding: CGFloat
    public let verticalPadding: CGFloat
    public let cornerRadius: CGFloat
    public let foregroundRole: PrismColorRole
    public let backgroundRole: PrismColorRole?
    public let borderRole: PrismColorRole?

    public var isInteractive: Bool {
        isEnabled && !isLoading
    }

    public init(
        variant: PrismButtonVariant,
        isLoading: Bool = false,
        isEnabled: Bool = true
    ) {
        self.variant = variant
        self.isLoading = isLoading
        self.isEnabled = isEnabled

        switch variant {
        case .primary, .secondary, .destructive:
            self.minHeight = PrismSize.primaryButtonHeight
            self.horizontalPadding = PrismSpacing.l
            self.verticalPadding = PrismSpacing.s
            self.cornerRadius = PrismRadius.m
        case .tertiary:
            self.minHeight = PrismSize.minTouch
            self.horizontalPadding = PrismSpacing.m
            self.verticalPadding = PrismSpacing.xs
            self.cornerRadius = PrismRadius.s
        case .inline:
            self.minHeight = PrismSize.minTouch
            self.horizontalPadding = PrismSpacing.s
            self.verticalPadding = PrismSpacing.xxs
            self.cornerRadius = PrismRadius.xs
        }

        if !isEnabled {
            self.foregroundRole = .textTertiary
            self.backgroundRole = (variant == .tertiary || variant == .inline) ? nil : .surfaceElevated
            self.borderRole = variant == .secondary ? .borderSubtle : nil
            return
        }

        switch variant {
        case .primary:
            self.foregroundRole = .surface
            self.backgroundRole = .accentPrimary
            self.borderRole = nil
        case .secondary:
            self.foregroundRole = .textPrimary
            self.backgroundRole = .surfaceRaised
            self.borderRole = .borderStrong
        case .tertiary:
            self.foregroundRole = .accentPrimary
            self.backgroundRole = .accentSubtle
            self.borderRole = nil
        case .destructive:
            self.foregroundRole = .surface
            self.backgroundRole = .negative
            self.borderRole = nil
        case .inline:
            self.foregroundRole = .accentPrimary
            self.backgroundRole = nil
            self.borderRole = nil
        }
    }
}

// MARK: - 4. PrismCardVariant & PrismCardConfiguration (§19, §24)

public enum PrismCardVariant: String, CaseIterable, Codable, Hashable, Sendable {
    case standard
    case hero
    case artifact
    case feedback
    case situation
}

public struct PrismCardConfiguration: Equatable, Hashable, Sendable {
    public let variant: PrismCardVariant
    public let semanticBorderRole: PrismColorRole?
    public let isIncreasedContrast: Bool

    public var surfaceRole: PrismColorRole {
        switch variant {
        case .standard:
            return .surface
        case .hero, .situation, .feedback:
            return .surfaceRaised
        case .artifact:
            return .surfaceArtifact
        }
    }

    public var borderRole: PrismColorRole {
        if let semanticBorderRole {
            return semanticBorderRole
        }
        if isIncreasedContrast {
            return .borderStrong
        }
        switch variant {
        case .hero, .artifact, .feedback, .situation:
            return .borderStrong
        case .standard:
            return .borderSubtle
        }
    }

    public var borderWidth: CGFloat {
        if isIncreasedContrast {
            return PrismBorder.regular
        }
        switch variant {
        case .hero, .feedback, .artifact:
            return PrismBorder.regular
        case .standard, .situation:
            return PrismBorder.thin
        }
    }

    public var cornerRadius: CGFloat {
        switch variant {
        case .hero, .situation:
            return PrismRadius.xl
        case .standard, .artifact, .feedback:
            return PrismRadius.l
        }
    }

    public var padding: CGFloat {
        switch variant {
        case .hero, .situation:
            return PrismSpacing.l
        case .standard, .artifact, .feedback:
            return PrismSpacing.m
        }
    }

    public var isOpaqueSurface: Bool {
        true
    }

    public var usesGlassEffect: Bool {
        false
    }

    public init(
        variant: PrismCardVariant = .standard,
        semanticBorderRole: PrismColorRole? = nil,
        isIncreasedContrast: Bool = false
    ) {
        self.variant = variant
        self.semanticBorderRole = semanticBorderRole
        self.isIncreasedContrast = isIncreasedContrast
    }
}

// MARK: - 5. PrismSection Configuration

public struct PrismSectionConfiguration: Equatable, Hashable, Sendable {
    public let title: String
    public let subtitle: String?
    public let actionTitle: String?

    public init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
    }
}

// MARK: - 6. PrismRow Configuration

public struct PrismRowConfiguration: Equatable, Hashable, Sendable {
    public let title: String
    public let subtitle: String?
    public let leadingIcon: PrismIconSource?
    public let trailingText: String?
    public let showsChevron: Bool
    public let isInteractive: Bool

    public var minHeight: CGFloat {
        PrismSize.minTouch
    }

    public var combinedAccessibilityLabel: String {
        [title, subtitle, trailingText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    public init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: PrismIconSource? = nil,
        trailingText: String? = nil,
        showsChevron: Bool = false,
        isInteractive: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingIcon = leadingIcon
        self.trailingText = trailingText
        self.showsChevron = showsChevron
        self.isInteractive = isInteractive
    }
}

// MARK: - 7. PrismChip Configuration

public struct PrismChipConfiguration: Equatable, Hashable, Sendable {
    public let title: String
    public let icon: PrismIconSource?
    public let isSelected: Bool
    public let region: PrismRegion?

    public var cornerRadius: CGFloat {
        PrismRadius.s
    }

    public var minHeight: CGFloat {
        PrismSize.minTouch
    }

    public var selectionIndicatorSymbol: String {
        "checkmark"
    }

    public init(
        title: String,
        icon: PrismIconSource? = nil,
        isSelected: Bool = false,
        region: PrismRegion? = nil
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.region = region
    }
}

// MARK: - 8. PrismBadge Semantics & Configuration

public enum PrismBadgeSemantics: Equatable, Hashable, Sendable {
    case neutral
    case accent
    case positive
    case caution
    case negative
    case region(PrismRegion)
    public static let warning: Self = .caution

    public var foregroundRole: PrismColorRole {
        switch self {
        case .neutral:
            return .textSecondary
        case .accent:
            return .accentPrimary
        case .positive:
            return .positive
        case .caution:
            return .caution
        case .negative:
            return .negative
        case .region:
            return .textPrimary
        }
    }

    public var backgroundRole: PrismColorRole {
        switch self {
        case .neutral:
            return .surfaceElevated
        case .accent:
            return .accentSubtle
        case .positive:
            return .positiveSubtle
        case .caution:
            return .cautionSubtle
        case .negative:
            return .negativeSubtle
        case .region:
            return .surfaceRaised
        }
    }

    public var borderRole: PrismColorRole {
        switch self {
        case .neutral:
            return .borderSubtle
        case .accent:
            return .accentPrimary
        case .positive:
            return .positive
        case .caution:
            return .caution
        case .negative:
            return .negative
        case .region:
            return .borderStrong
        }
    }
}

public struct PrismBadgeConfiguration: Equatable, Hashable, Sendable {
    public let text: String
    public let semantics: PrismBadgeSemantics
    public let icon: PrismIconSource?

    public init(
        text: String,
        semantics: PrismBadgeSemantics = .neutral,
        icon: PrismIconSource? = nil
    ) {
        self.text = text
        self.semantics = semantics
        self.icon = icon
    }
}

// MARK: - 9. PrismProgressBar Configuration

public struct PrismProgressBarConfiguration: Equatable, Hashable, Sendable {
    public let rawProgress: Double
    public let clampedProgress: Double
    public let colorRole: PrismColorRole
    public let label: String?

    public var barHeight: CGFloat {
        PrismSpacing.s
    }

    public var percentageValue: Int {
        Int((clampedProgress * 100.0).rounded())
    }

    public var accessibilityPercentageText: String {
        "\(percentageValue) %"
    }

    public init(
        progress: Double,
        colorRole: PrismColorRole = .accentPrimary,
        label: String? = nil
    ) {
        self.rawProgress = progress
        if progress.isNaN {
            self.clampedProgress = 0.0
        } else {
            self.clampedProgress = min(max(progress, 0.0), 1.0)
        }
        self.colorRole = colorRole
        self.label = label
    }
}

// MARK: - 10. PrismProgressRing Configuration

public struct PrismProgressRingConfiguration: Equatable, Hashable, Sendable {
    public let rawProgress: Double
    public let clampedProgress: Double
    public let colorRole: PrismColorRole
    public let centerLabel: String?
    public let diameter: CGFloat

    public var lineWidth: CGFloat {
        PrismSpacing.s
    }

    public var percentageValue: Int {
        Int((clampedProgress * 100.0).rounded())
    }

    public var accessibilityPercentageText: String {
        "\(percentageValue) %"
    }

    public init(
        progress: Double,
        colorRole: PrismColorRole = .accentPrimary,
        centerLabel: String? = nil,
        diameter: CGFloat = PrismSize.minTouch
    ) {
        self.rawProgress = progress
        if progress.isNaN {
            self.clampedProgress = 0.0
        } else {
            self.clampedProgress = min(max(progress, 0.0), 1.0)
        }
        self.colorRole = colorRole
        self.centerLabel = centerLabel
        self.diameter = max(diameter, PrismSize.minTouch)
    }
}

// MARK: - 11. PrismSegmentedControl Models

public struct PrismSegmentOption<Value: Hashable & Sendable>: Identifiable, Equatable, Hashable, Sendable {
    public let id: Value
    public let value: Value
    public let title: String
    public let icon: PrismIconSource?

    public init(
        value: Value,
        title: String,
        icon: PrismIconSource? = nil
    ) {
        self.id = value
        self.value = value
        self.title = title
        self.icon = icon
    }
}

public struct PrismSegmentedControlConfiguration<Value: Hashable & Sendable>: Equatable, Sendable {
    public let options: [PrismSegmentOption<Value>]
    public let selectedValue: Value
    public let accessibilityLabel: String

    public var minHeight: CGFloat {
        PrismSize.minTouch
    }

    public init(
        options: [PrismSegmentOption<Value>],
        selectedValue: Value,
        accessibilityLabel: String
    ) {
        self.options = options
        self.selectedValue = selectedValue
        self.accessibilityLabel = accessibilityLabel
    }
}

// MARK: - SwiftUI Views & Styles

#if canImport(SwiftUI) && canImport(UIKit)

public struct PrismText: View {
    public let configuration: PrismTextConfiguration

    public init(configuration: PrismTextConfiguration) {
        self.configuration = configuration
    }

    public init(
        _ text: String,
        style: PrismTextStyle = .body,
        role: PrismColorRole = .textPrimary,
        lineLimit: Int? = nil,
        isMonospacedDigits: Bool = false
    ) {
        self.configuration = PrismTextConfiguration(
            text: text,
            style: style,
            role: role,
            lineLimit: lineLimit,
            isMonospacedDigits: isMonospacedDigits
        )
    }

    public var body: some View {
        Group {
            if configuration.isMonospacedDigits {
                Text(verbatim: configuration.text)
                    .monospacedDigit()
            } else {
                Text(verbatim: configuration.text)
            }
        }
        .prismTextStyle(configuration.style)
        .foregroundStyle(PrismColor.color(configuration.role))
        .lineLimit(configuration.lineLimit)
        .fixedSize(horizontal: false, vertical: configuration.lineLimit == nil)
    }
}

public struct PrismIcon: View {
    public let configuration: PrismIconConfiguration

    public init(configuration: PrismIconConfiguration) {
        self.configuration = configuration
    }

    public init(
        systemName: String,
        style: PrismTextStyle = .body,
        role: PrismColorRole = .textPrimary,
        accessibilityLabel: String? = nil
    ) {
        self.configuration = PrismIconConfiguration(
            systemName: systemName,
            style: style,
            role: role,
            accessibilityLabel: accessibilityLabel
        )
    }

    public init(
        glyph: PrismGlyph,
        style: PrismTextStyle = .body,
        role: PrismColorRole = .textPrimary,
        accessibilityLabel: String? = nil
    ) {
        self.configuration = PrismIconConfiguration(
            glyph: glyph,
            style: style,
            role: role,
            accessibilityLabel: accessibilityLabel
        )
    }

    @ViewBuilder
    private var rawImage: some View {
        switch configuration.source {
        case let .system(systemName):
            Image(systemName: systemName)
        case let .glyph(glyph):
            if UIImage(named: glyph.assetName, in: .module, with: nil) != nil {
                Image(glyph.assetName, bundle: .module)
            } else {
                Image(systemName: glyph.sfSymbolFallback)
            }
        }
    }

    public var body: some View {
        Group {
            if let label = configuration.accessibilityLabel, !configuration.isDecorative {
                rawImage
                    .accessibilityHidden(false)
                    .accessibilityLabel(Text(verbatim: label))
            } else {
                rawImage
                    .accessibilityHidden(true)
            }
        }
        .prismTextStyle(configuration.style)
        .foregroundStyle(PrismColor.color(configuration.role))
    }
}

public struct PrismButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public let variant: PrismButtonVariant
    public let isLoading: Bool

    public init(
        variant: PrismButtonVariant = .primary,
        isLoading: Bool = false
    ) {
        self.variant = variant
        self.isLoading = isLoading
    }

    public func makeBody(configuration: Configuration) -> some View {
        let metrics = PrismButtonMetrics(
            variant: variant,
            isLoading: isLoading,
            isEnabled: isEnabled
        )
        let motion = PrismMotion.resolve(.quick, reduceMotion: reduceMotion)
        let borderWidth = colorSchemeContrast == .increased ? PrismBorder.regular : PrismBorder.thin

        HStack(spacing: PrismSpacing.xs) {
            if isLoading {
                ProgressView()
                    .tint(PrismColor.color(metrics.foregroundRole))
            }
            configuration.label
                .prismTextStyle(.callout)
                .foregroundStyle(PrismColor.color(metrics.foregroundRole))
        }
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, metrics.verticalPadding)
        .frame(minHeight: metrics.minHeight)
        .background {
            if let backgroundRole = metrics.backgroundRole {
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .fill(PrismColor.color(backgroundRole))
            }
        }
        .overlay {
            if let borderRole = metrics.borderRole {
                RoundedRectangle(cornerRadius: metrics.cornerRadius, style: .continuous)
                    .strokeBorder(PrismColor.color(borderRole), lineWidth: borderWidth)
            }
        }
        .opacity(configuration.isPressed && metrics.isInteractive ? 0.88 : 1.0)
        .animation(motion.animation, value: configuration.isPressed)
        .animation(motion.animation, value: isLoading)
        .sensoryFeedback(PrismHapticToken.selection.sensoryFeedback, trigger: configuration.isPressed)
        .allowsHitTesting(metrics.isInteractive)
    }
}

public struct PrismCard<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public let variant: PrismCardVariant
    public let semanticBorderRole: PrismColorRole?
    private let content: Content

    public init(
        variant: PrismCardVariant = .standard,
        semanticBorderRole: PrismColorRole? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.semanticBorderRole = semanticBorderRole
        self.content = content()
    }

    public var body: some View {
        let resolved = PrismCardConfiguration(
            variant: variant,
            semanticBorderRole: semanticBorderRole,
            isIncreasedContrast: colorSchemeContrast == .increased
        )

        content
            .padding(resolved.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: resolved.cornerRadius, style: .continuous)
                    .fill(PrismColor.color(resolved.surfaceRole))
            )
            .overlay(
                RoundedRectangle(cornerRadius: resolved.cornerRadius, style: .continuous)
                    .strokeBorder(
                        PrismColor.color(resolved.borderRole),
                        lineWidth: resolved.borderWidth
                    )
            )
    }
}

public struct PrismSection<Content: View>: View {
    public let configuration: PrismSectionConfiguration
    private let action: (() -> Void)?
    private let content: Content

    public init(
        configuration: PrismSectionConfiguration,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.action = action
        self.content = content()
    }

    public init(
        title: String,
        subtitle: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = PrismSectionConfiguration(
            title: title,
            subtitle: subtitle,
            actionTitle: actionTitle
        )
        self.action = action
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: PrismSpacing.s) {
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    PrismText(configuration.title, style: .headline, role: .textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle = configuration.subtitle {
                        PrismText(subtitle, style: .subheadline, role: .textSecondary)
                    }
                }
                Spacer(minLength: PrismSpacing.xs)
                if let actionTitle = configuration.actionTitle, let action {
                    Button(action: action) {
                        PrismText(actionTitle, style: .subheadline, role: .accentPrimary)
                    }
                    .buttonStyle(PrismButtonStyle(variant: .inline))
                }
            }
            content
        }
    }
}

public struct PrismRow: View {
    public let configuration: PrismRowConfiguration
    private let action: (() -> Void)?

    public init(
        configuration: PrismRowConfiguration,
        action: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.action = action
    }

    public init(
        title: String,
        subtitle: String? = nil,
        leadingIcon: PrismIconSource? = nil,
        trailingText: String? = nil,
        showsChevron: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.configuration = PrismRowConfiguration(
            title: title,
            subtitle: subtitle,
            leadingIcon: leadingIcon,
            trailingText: trailingText,
            showsChevron: showsChevron,
            isInteractive: action != nil
        )
        self.action = action
    }

    private var rowContent: some View {
        HStack(spacing: PrismSpacing.s) {
            if let leadingIcon = configuration.leadingIcon {
                PrismIcon(
                    configuration: PrismIconConfiguration(
                        source: leadingIcon,
                        style: .headline,
                        role: .accentPrimary
                    )
                )
            }
            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                PrismText(configuration.title, style: .body, role: .textPrimary)
                if let subtitle = configuration.subtitle {
                    PrismText(subtitle, style: .subheadline, role: .textSecondary)
                }
            }
            Spacer(minLength: PrismSpacing.xs)
            if let trailingText = configuration.trailingText {
                PrismText(
                    trailingText,
                    style: .subheadline,
                    role: .textSecondary,
                    isMonospacedDigits: true
                )
            }
            if configuration.showsChevron {
                PrismIcon(
                    systemName: "chevron.right",
                    style: .footnote,
                    role: .textTertiary
                )
            }
        }
        .padding(.vertical, PrismSpacing.xs)
        .padding(.horizontal, PrismSpacing.s)
        .frame(minHeight: configuration.minHeight)
        .contentShape(Rectangle())
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: configuration.combinedAccessibilityLabel))
    }
}

public struct PrismChip: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let configuration: PrismChipConfiguration
    private let action: (() -> Void)?

    public init(
        configuration: PrismChipConfiguration,
        action: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        self.action = action
    }

    public init(
        title: String,
        icon: PrismIconSource? = nil,
        isSelected: Bool = false,
        region: PrismRegion? = nil,
        action: (() -> Void)? = nil
    ) {
        self.configuration = PrismChipConfiguration(
            title: title,
            icon: icon,
            isSelected: isSelected,
            region: region
        )
        self.action = action
    }

    private var foregroundColor: Color {
        if configuration.isSelected {
            if let region = configuration.region {
                return region.color
            }
            return PrismColor.accentPrimary
        }
        return PrismColor.textPrimary
    }

    private var backgroundColor: Color {
        if configuration.isSelected {
            return PrismColor.accentSubtle
        }
        return PrismColor.surfaceRaised
    }

    private var borderColor: Color {
        if configuration.isSelected {
            if let region = configuration.region {
                return region.color
            }
            return PrismColor.accentPrimary
        }
        return colorSchemeContrast == .increased ? PrismColor.borderStrong : PrismColor.borderSubtle
    }

    private var chipBody: some View {
        let borderWidth = (configuration.isSelected || colorSchemeContrast == .increased)
            ? PrismBorder.regular
            : PrismBorder.thin

        return HStack(spacing: PrismSpacing.xs) {
            if configuration.isSelected {
                Image(systemName: configuration.selectionIndicatorSymbol)
                    .prismTextStyle(.caption)
                    .foregroundStyle(foregroundColor)
                    .accessibilityHidden(true)
            } else if let icon = configuration.icon {
                PrismIcon(
                    configuration: PrismIconConfiguration(
                        source: icon,
                        style: .caption,
                        role: .textSecondary
                    )
                )
            }
            Text(verbatim: configuration.title)
                .prismTextStyle(.subheadline)
                .foregroundStyle(foregroundColor)
        }
        .padding(.horizontal, PrismSpacing.s)
        .padding(.vertical, PrismSpacing.xs)
        .frame(minHeight: configuration.minHeight)
        .background(
            RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
    }

    public var body: some View {
        let motion = PrismMotion.resolve(.quick, reduceMotion: reduceMotion)

        Group {
            if let action {
                Button(action: action) {
                    chipBody
                }
                .buttonStyle(.plain)
                .sensoryFeedback(PrismHapticToken.selection.sensoryFeedback, trigger: configuration.isSelected)
            } else {
                chipBody
            }
        }
        .animation(motion.animation, value: configuration.isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: configuration.title))
        .accessibilityAddTraits(configuration.isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

public struct PrismBadge: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public let configuration: PrismBadgeConfiguration

    public init(configuration: PrismBadgeConfiguration) {
        self.configuration = configuration
    }

    public init(
        text: String,
        semantics: PrismBadgeSemantics = .neutral,
        icon: PrismIconSource? = nil
    ) {
        self.configuration = PrismBadgeConfiguration(
            text: text,
            semantics: semantics,
            icon: icon
        )
    }

    private var foregroundColor: Color {
        switch configuration.semantics {
        case let .region(region):
            return region.color
        default:
            return PrismColor.color(configuration.semantics.foregroundRole)
        }
    }

    private var borderColor: Color {
        switch configuration.semantics {
        case let .region(region):
            return region.color
        default:
            return PrismColor.color(configuration.semantics.borderRole)
        }
    }

    public var body: some View {
        let borderWidth = colorSchemeContrast == .increased ? PrismBorder.regular : PrismBorder.thin

        HStack(spacing: PrismSpacing.xxs) {
            if let icon = configuration.icon {
                PrismIcon(
                    configuration: PrismIconConfiguration(
                        source: icon,
                        style: .caption,
                        role: configuration.semantics.foregroundRole
                    )
                )
            } else if case let .region(region) = configuration.semantics {
                PrismIcon(
                    glyph: .region(region),
                    style: .caption,
                    role: .textPrimary
                )
            }
            Text(verbatim: configuration.text)
                .prismTextStyle(.caption)
                .foregroundStyle(foregroundColor)
        }
        .padding(.horizontal, PrismSpacing.xs)
        .padding(.vertical, PrismSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                .fill(PrismColor.color(configuration.semantics.backgroundRole))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: configuration.text))
    }
}

public struct PrismProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let configuration: PrismProgressBarConfiguration

    public init(configuration: PrismProgressBarConfiguration) {
        self.configuration = configuration
    }

    public init(
        progress: Double,
        colorRole: PrismColorRole = .accentPrimary,
        label: String? = nil
    ) {
        self.configuration = PrismProgressBarConfiguration(
            progress: progress,
            colorRole: colorRole,
            label: label
        )
    }

    public var body: some View {
        let motion = PrismMotion.resolve(.standard, reduceMotion: reduceMotion)

        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
            if let label = configuration.label {
                HStack(spacing: PrismSpacing.xs) {
                    PrismText(label, style: .caption, role: .textSecondary)
                    Spacer(minLength: PrismSpacing.xs)
                    PrismText(
                        configuration.accessibilityPercentageText,
                        style: .caption,
                        role: .textSecondary,
                        isMonospacedDigits: true
                    )
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                        .fill(PrismColor.surfaceElevated)
                    RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                        .fill(PrismColor.color(configuration.colorRole))
                        .frame(width: proxy.size.width * configuration.clampedProgress)
                        .animation(motion.animation, value: configuration.clampedProgress)
                }
            }
            .frame(height: configuration.barHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: configuration.label ?? "Progression"))
        .accessibilityValue(Text(verbatim: configuration.accessibilityPercentageText))
    }
}

public struct PrismProgressRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let configuration: PrismProgressRingConfiguration

    public init(configuration: PrismProgressRingConfiguration) {
        self.configuration = configuration
    }

    public init(
        progress: Double,
        colorRole: PrismColorRole = .accentPrimary,
        centerLabel: String? = nil,
        diameter: CGFloat = PrismSize.minTouch
    ) {
        self.configuration = PrismProgressRingConfiguration(
            progress: progress,
            colorRole: colorRole,
            centerLabel: centerLabel,
            diameter: diameter
        )
    }

    public var body: some View {
        let motion = PrismMotion.resolve(.standard, reduceMotion: reduceMotion)

        ZStack {
            Circle()
                .stroke(
                    PrismColor.surfaceElevated,
                    style: StrokeStyle(lineWidth: configuration.lineWidth, lineCap: .round)
                )
            Circle()
                .trim(from: 0.0, to: configuration.clampedProgress)
                .stroke(
                    PrismColor.color(configuration.colorRole),
                    style: StrokeStyle(lineWidth: configuration.lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90.0))
                .animation(motion.animation, value: configuration.clampedProgress)

            if let centerLabel = configuration.centerLabel {
                PrismText(
                    centerLabel,
                    style: .caption,
                    role: .textPrimary,
                    lineLimit: 1,
                    isMonospacedDigits: true
                )
            }
        }
        .frame(width: configuration.diameter, height: configuration.diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: configuration.centerLabel ?? "Progression"))
        .accessibilityValue(Text(verbatim: configuration.accessibilityPercentageText))
    }
}

public struct PrismSegmentedControl<Value: Hashable & Sendable>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public let configuration: PrismSegmentedControlConfiguration<Value>
    private let onSelect: (Value) -> Void

    public init(
        configuration: PrismSegmentedControlConfiguration<Value>,
        onSelect: @escaping (Value) -> Void
    ) {
        self.configuration = configuration
        self.onSelect = onSelect
    }

    public init(
        options: [PrismSegmentOption<Value>],
        selectedValue: Value,
        accessibilityLabel: String,
        onSelect: @escaping (Value) -> Void
    ) {
        self.configuration = PrismSegmentedControlConfiguration(
            options: options,
            selectedValue: selectedValue,
            accessibilityLabel: accessibilityLabel
        )
        self.onSelect = onSelect
    }

    public var body: some View {
        let motion = PrismMotion.resolve(.quick, reduceMotion: reduceMotion)
        let borderWidth = colorSchemeContrast == .increased ? PrismBorder.regular : PrismBorder.thin

        HStack(spacing: PrismSpacing.xxs) {
            ForEach(configuration.options) { option in
                let isSelected = option.value == configuration.selectedValue
                Button {
                    onSelect(option.value)
                } label: {
                    HStack(spacing: PrismSpacing.xxs) {
                        if isSelected {
                            PrismIcon(
                                systemName: "checkmark",
                                style: .caption,
                                role: .textPrimary
                            )
                        } else if let icon = option.icon {
                            PrismIcon(
                                configuration: PrismIconConfiguration(
                                    source: icon,
                                    style: .caption,
                                    role: .textSecondary
                                )
                            )
                        }
                        PrismText(
                            option.title,
                            style: .subheadline,
                            role: isSelected ? .textPrimary : .textSecondary,
                            lineLimit: 1
                        )
                    }
                    .padding(.horizontal, PrismSpacing.s)
                    .padding(.vertical, PrismSpacing.xs)
                    .frame(maxWidth: .infinity, minHeight: configuration.minHeight)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .fill(PrismColor.surfaceRaised)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                        .strokeBorder(PrismColor.borderStrong, lineWidth: borderWidth)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: option.title))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            }
        }
        .padding(PrismSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                .fill(PrismColor.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                .strokeBorder(PrismColor.borderSubtle, lineWidth: borderWidth)
        )
        .animation(motion.animation, value: configuration.selectedValue)
        .sensoryFeedback(PrismHapticToken.selection.sensoryFeedback, trigger: configuration.selectedValue)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: configuration.accessibilityLabel))
    }
}

// MARK: - Previews (Nominal, Vide, Chargement, Erreur, AX3, Sombre)

private struct PrismFoundationGalleryPreview: View {
    let stateTitle: String
    let isLoading: Bool
    let isError: Bool
    let isEmpty: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                PrismSection(
                    title: stateTitle,
                    subtitle: "Validation des composants Foundation",
                    actionTitle: "Action",
                    action: {}
                ) {
                    PrismCard(
                        variant: isError ? .feedback : .hero,
                        semanticBorderRole: isError ? .negative : nil
                    ) {
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            HStack(spacing: PrismSpacing.xs) {
                                PrismBadge(
                                    text: isError ? "Alerte" : "AZ-104",
                                    semantics: isError ? .negative : .region(.r1)
                                )
                                PrismBadge(
                                    text: "Ancré",
                                    semantics: .positive,
                                    icon: .glyph(.conceptState(.anchored))
                                )
                            }
                            PrismText(
                                isEmpty
                                    ? "Aucun concept actif pour le moment."
                                    : " Architecturer la connectivité hybride ExpressRoute et VPN.",
                                style: .title3,
                                role: .textPrimary
                            )
                            PrismProgressBar(
                                progress: isEmpty ? 0.0 : 0.72,
                                colorRole: isError ? .negative : .accentPrimary,
                                label: "Maîtrise du domaine"
                            )
                            HStack(spacing: PrismSpacing.s) {
                                PrismProgressRing(
                                    progress: isEmpty ? 0.0 : 0.72,
                                    colorRole: isError ? .negative : .positive,
                                    centerLabel: "72%"
                                )
                                Button(action: {}) {
                                    Text(verbatim: isLoading ? "Chargement" : "Continuer")
                                }
                                .buttonStyle(
                                    PrismButtonStyle(
                                        variant: isError ? .destructive : .primary,
                                        isLoading: isLoading
                                    )
                                )
                            }
                        }
                    }
                }

                HStack(spacing: PrismSpacing.xs) {
                    PrismChip(title: "Réseau", icon: .glyph(.region(.r1)), isSelected: true, region: .r1)
                    PrismChip(title: "Déclic", icon: .glyph(.declic), isSelected: false)
                }

                PrismSegmentedControl(
                    options: [
                        PrismSegmentOption(value: 0, title: "Carte", icon: .glyph(.route)),
                        PrismSegmentOption(value: 1, title: "Concepts", icon: .glyph(.declic))
                    ],
                    selectedValue: 0,
                    accessibilityLabel: "Mode d'exploration",
                    onSelect: { _ in }
                )

                PrismCard(variant: .standard) {
                    PrismRow(
                        title: "Sous-réseaux et passerelles",
                        subtitle: "4 concepts validés",
                        leadingIcon: .glyph(.region(.r1)),
                        trailingText: "85 %",
                        showsChevron: true,
                        action: {}
                    )
                }
            }
            .padding(PrismSpacing.m)
        }
        .background(PrismColor.canvas)
    }
}

#Preview("Nominal") {
    PrismFoundationGalleryPreview(
        stateTitle: "État nominal",
        isLoading: false,
        isError: false,
        isEmpty: false
    )
}

#Preview("Vide") {
    PrismFoundationGalleryPreview(
        stateTitle: "État vide",
        isLoading: false,
        isError: false,
        isEmpty: true
    )
}

#Preview("Chargement") {
    PrismFoundationGalleryPreview(
        stateTitle: "État chargement",
        isLoading: true,
        isError: false,
        isEmpty: false
    )
}

#Preview("Erreur") {
    PrismFoundationGalleryPreview(
        stateTitle: "État erreur",
        isLoading: false,
        isError: true,
        isEmpty: false
    )
}

#Preview("AX3 Dynamic Type") {
    PrismFoundationGalleryPreview(
        stateTitle: "Accessibilité AX3",
        isLoading: false,
        isError: false,
        isEmpty: false
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Sombre") {
    PrismFoundationGalleryPreview(
        stateTitle: "Mode sombre",
        isLoading: false,
        isError: false,
        isEmpty: false
    )
    .preferredColorScheme(.dark)
}

#endif
