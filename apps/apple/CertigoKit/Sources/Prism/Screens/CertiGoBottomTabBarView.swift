import Foundation

// MARK: - 1. Semantic Tab Aliases & Pure Testable Bottom Tab Item Specifications

extension CertiGoNativeTab {
    /// Semantic alias for Tab #1 (`Parcours`).
    public static var learn: CertiGoNativeTab { .parcours }

    /// Semantic alias for Tab #2 (`Actus`).
    public static var techNews: CertiGoNativeTab { .examens }

    /// Semantic alias for Tab #3 (`✦ IA` / ChatGPT AI Tutor).
    public static var aiTutor: CertiGoNativeTab { .hubIA }

    /// Semantic alias for Tab #4 (`Social`).
    public static var league: CertiGoNativeTab { .social }

    /// Semantic alias for Tab #5 (`Moi`).
    public static var profile: CertiGoNativeTab { .moi }

    /// Stable accessibility slug used by the bottom navigation bar buttons.
    public var accessibilitySlug: String {
        switch self {
        case .parcours: return "parcours"
        case .examens: return "examens"
        case .hubIA: return "hub-ia"
        case .social: return "social"
        case .moi: return "moi"
        }
    }

    /// Selected SF Symbol icon for the 5-tab bottom navigation bar.
    public var selectedBottomBarSymbol: String {
        switch self {
        case .parcours: return "map.fill"
        case .examens: return "newspaper.fill"
        case .hubIA: return "sparkles"
        case .social: return "person.2.fill"
        case .moi: return "person.crop.circle.fill"
        }
    }

    /// Unselected SF Symbol icon for the 5-tab bottom navigation bar.
    public var unselectedBottomBarSymbol: String {
        switch self {
        case .parcours: return "map"
        case .examens: return "newspaper"
        case .hubIA: return "sparkles"
        case .social: return "person.2"
        case .moi: return "person.crop.circle"
        }
    }
}

/// Pure, deterministic specification of a single bottom tab bar item, testable outside SwiftUI on Linux and macOS/iOS.
public struct CertiGoBottomTabItemSpec: Identifiable, Equatable, Sendable {
    /// Exact ordered 5-tab sequence required across the application.
    public static let orderedTabs: [CertiGoNativeTab] = [
        .learn,
        .techNews,
        .hubIA,
        .league,
        .profile
    ]

    public let index: Int
    public let tab: CertiGoNativeTab
    public let title: String
    public let defaultTitle: String
    public let selectedSymbol: String
    public let unselectedSymbol: String
    public let iconOpacity: Double
    public let titleOpacity: Double
    public let accessibilityIdentifier: String

    public var id: CertiGoNativeTab { tab }

    public init(
        index: Int,
        tab: CertiGoNativeTab,
        title: String,
        defaultTitle: String,
        selectedSymbol: String,
        unselectedSymbol: String,
        iconOpacity: Double = 1.0,
        titleOpacity: Double = 1.0,
        accessibilityIdentifier: String? = nil
    ) {
        self.index = index
        self.tab = tab
        self.title = title
        self.defaultTitle = defaultTitle
        self.selectedSymbol = selectedSymbol
        self.unselectedSymbol = unselectedSymbol
        self.iconOpacity = 1.0
        self.titleOpacity = 1.0
        self.accessibilityIdentifier = accessibilityIdentifier ?? "native-tab-\(tab.accessibilitySlug)"
    }

    /// Returns the appropriate SF Symbol name for the current selection state.
    public func symbolName(isSelected: Bool) -> String {
        isSelected ? selectedSymbol : unselectedSymbol
    }

    /// Builds the specification for a single tab in the given language mode (`0 ... 11`).
    public static func spec(
        for tab: CertiGoNativeTab,
        languageIndex: Int = 0
    ) -> CertiGoBottomTabItemSpec {
        let index = orderedTabs.firstIndex(of: tab) ?? 0
        let localized = CertiGoMultilingualEngine.localizedTabTitle(tab, lang: languageIndex)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = localized.isEmpty ? tab.title : localized
        return CertiGoBottomTabItemSpec(
            index: index,
            tab: tab,
            title: resolvedTitle,
            defaultTitle: tab.title,
            selectedSymbol: tab.selectedBottomBarSymbol,
            unselectedSymbol: tab.unselectedBottomBarSymbol,
            iconOpacity: 1.0,
            titleOpacity: 1.0
        )
    }

    /// Builds the complete 5-item bottom bar specification in exact canonical order.
    public static func allItems(languageIndex: Int = 0) -> [CertiGoBottomTabItemSpec] {
        orderedTabs.map { spec(for: $0, languageIndex: languageIndex) }
    }
}

// MARK: - 2. Pure Testable Optical & Layout Metrics (`CertiGoBottomTabBarStyleMetrics`)

/// Pure, deterministic optical and layout metrics for `CertiGoBottomTabBarView`, testable outside SwiftUI.
/// Guarantees that button count is always 5 and that icon/title foreground opacities remain 1.0 regardless of `liquidGlassIntensity`.
public struct CertiGoBottomTabBarStyleMetrics: Equatable, Sendable {
    public static let mandatoryButtonCount: Int = 5
    public static let fixedBarHeight: CGFloat = 62
    public static let horizontalInnerPadding: CGFloat = 6
    public static let verticalInnerPadding: CGFloat = 6
    public static let interItemSpacing: CGFloat = 4
    public static let iconTextVerticalSpacing: CGFloat = 3
    public static let iconPointSize: CGFloat = 19
    public static let titlePointSize: CGFloat = 11
    public static let minimumTitleScaleFactor: CGFloat = 0.8

    public static let selectedForegroundHex: String = "#1D4ED8"
    public static let selectedLensHighlightHex: String = "#2563EB"
    public static let unselectedForegroundHex: String = "#334155"

    /// Clamped Liquid Glass intensity in `0.0 ... 1.0` (`0.0` when `reduceTransparency` is enabled).
    public let liquidGlassIntensity: Double
    public let reduceTransparency: Bool

    /// Contract invariants: 5 buttons whose icons and titles are always 100% opaque (`1.0`).
    public let buttonCount: Int = CertiGoBottomTabBarStyleMetrics.mandatoryButtonCount
    public let iconOpacity: Double = 1.0
    public let titleOpacity: Double = 1.0

    public init(
        liquidGlassIntensity: Double,
        reduceTransparency: Bool = false
    ) {
        let clamped = min(max(liquidGlassIntensity, 0.0), 1.0)
        self.reduceTransparency = reduceTransparency
        self.liquidGlassIntensity = reduceTransparency ? 0.0 : clamped
    }

    public init(
        intensityPercent: Int,
        reduceTransparency: Bool = false
    ) {
        let normalized = Double(min(max(intensityPercent, 0), 100)) / 100.0
        self.init(liquidGlassIntensity: normalized, reduceTransparency: reduceTransparency)
    }

    /// White veil opacity over `.ultraThinMaterial`: `0.96` at `0%` down to `0.58` at `100%`.
    /// Ensures crisp readability at all settings while letting underlying cards blur and refract through the dock.
    public var surfaceWhiteOpacity: Double {
        0.96 - (0.38 * liquidGlassIntensity)
    }

    /// Luminous Liquid Glass lens fill opacity behind the active tab button (`0.94` at `0%` to `0.76` at `100%`).
    public var activeLensFillOpacity: Double {
        0.94 - (0.18 * liquidGlassIntensity)
    }

    /// Specular border opacity along the top-leading rim (`0.38` at `0%` up to `0.92` at `100%`).
    public var specularBorderOpacity: Double {
        0.38 + (0.54 * liquidGlassIntensity)
    }

    /// Soft chromatic refraction glow opacity at the top of the dock (`0.08` at `0%` up to `0.44` at `100%`).
    public var prismGlowOpacity: Double {
        0.08 + (0.36 * liquidGlassIntensity)
    }

    /// Floating dock drop-shadow opacity (`0.08` at `0%` up to `0.18` at `100%`).
    public var dropShadowOpacity: Double {
        0.08 + (0.10 * liquidGlassIntensity)
    }

    /// Floating dock drop-shadow radius (`8pt` at `0%` up to `16pt` at `100%`).
    public var dropShadowRadius: CGFloat {
        8.0 + (8.0 * CGFloat(liquidGlassIntensity))
    }
}

// MARK: - 3. Flat, Deterministic SwiftUI Bottom Tab Bar View (`CertiGoBottomTabBarView`)

#if canImport(SwiftUI)
import SwiftUI
import Symbols

/// Flat, deterministic 5-button Liquid Glass bottom navigation bar.
/// Uses a single foreground HStack(spacing: 4) with a background material dock and a stroke-only specular rim
/// so the 5 foreground buttons are never occluded on iOS 26/27.
public struct CertiGoBottomTabBarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var activeTabLensNamespace

    public let selectedTab: CertiGoNativeTab
    public let liquidGlassIntensity: Double
    public let languageIndex: Int
    public let routeCode: String
    public let accessibilityPrefix: String
    public let onSelectTab: (CertiGoNativeTab) -> Void

    public init(
        selectedTab: CertiGoNativeTab,
        liquidGlassIntensity: Double,
        languageIndex: Int = 0,
        routeCode: String = "AZ-104",
        accessibilityPrefix: String = "native-tab",
        onSelectTab: @escaping (CertiGoNativeTab) -> Void
    ) {
        self.selectedTab = selectedTab
        self.liquidGlassIntensity = liquidGlassIntensity
        self.languageIndex = languageIndex
        self.routeCode = routeCode
        self.accessibilityPrefix = accessibilityPrefix
        self.onSelectTab = onSelectTab
    }

    public var items: [CertiGoBottomTabItemSpec] {
        CertiGoBottomTabItemSpec.allItems(languageIndex: languageIndex)
    }

    public var metrics: CertiGoBottomTabBarStyleMetrics {
        CertiGoBottomTabBarStyleMetrics(
            liquidGlassIntensity: liquidGlassIntensity,
            reduceTransparency: reduceTransparency
        )
    }

    public var body: some View {
        HStack(spacing: FigMetrics.four) {
            ForEach(items) { item in
                tabButton(for: item)
            }
        }
        .padding(.horizontal, FigMetrics.six)
        .padding(.vertical, FigMetrics.six)
        .frame(
            maxWidth: .infinity,
            minHeight: CertiGoBottomTabBarStyleMetrics.fixedBarHeight,
            maxHeight: CertiGoBottomTabBarStyleMetrics.fixedBarHeight
        )
        .background {
            liquidGlassDockBackground
        }
        .overlay {
            liquidGlassSpecularRim
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func tabButton(for item: CertiGoBottomTabItemSpec) -> some View {
        let isSelected = (item.tab == selectedTab)
        let fgHex = isSelected
            ? CertiGoBottomTabBarStyleMetrics.selectedForegroundHex
            : CertiGoBottomTabBarStyleMetrics.unselectedForegroundHex

        Button {
            onSelectTab(item.tab)
        } label: {
            VStack(spacing: FigMetrics.three) {
                Image(systemName: item.symbolName(isSelected: isSelected))
                    .font(
                        PrismTypography.figmaFont(
                            size: CertiGoBottomTabBarStyleMetrics.iconPointSize,
                            style: isSelected ? "Bold" : "Semi Bold"
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce.up.byLayer, value: selectedTab == item.tab)
                Text(verbatim: item.title)
                    .font(
                        PrismTypography.figmaFont(
                            size: CertiGoBottomTabBarStyleMetrics.titlePointSize,
                            style: isSelected ? "Bold" : "Medium"
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(CertiGoBottomTabBarStyleMetrics.minimumTitleScaleFactor)
            }
            .foregroundStyle(PrismColor.figmaHex(fgHex))
            .opacity(1.0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isSelected {
                    activeTabLiquidGlassLens
                        .matchedGeometryEffect(id: "activeBottomTabLens", in: activeTabLensNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier("\(accessibilityPrefix)-\(item.tab.accessibilitySlug)")
    }

    private var activeTabLiquidGlassLens: some View {
        let currentMetrics = metrics
        return ZStack {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(currentMetrics.activeLensFillOpacity))

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(
                                color: PrismColor.figmaHex("#E0F2FE")
                                    .opacity(0.65 + (0.30 * currentMetrics.liquidGlassIntensity)),
                                location: 0.0
                            ),
                            .init(
                                color: PrismColor.figmaHex("#DBEAFE")
                                    .opacity(0.45 + (0.35 * currentMetrics.liquidGlassIntensity)),
                                location: 0.55
                            ),
                            .init(
                                color: PrismColor.figmaHex(CertiGoBottomTabBarStyleMetrics.selectedLensHighlightHex)
                                    .opacity(0.14 + (0.14 * currentMetrics.liquidGlassIntensity)),
                                location: 1.0
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            PrismColor.figmaHex("#93C5FD").opacity(0.55 + (0.35 * currentMetrics.liquidGlassIntensity)),
                            PrismColor.figmaHex("#BFDBFE").opacity(0.45)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.25
                )
        }
        .shadow(
            color: PrismColor.figmaHex(CertiGoBottomTabBarStyleMetrics.selectedLensHighlightHex)
                .opacity(0.12 + (0.14 * currentMetrics.liquidGlassIntensity)),
            radius: 6,
            x: 0,
            y: 2
        )
    }

    private var liquidGlassDockBackground: some View {
        let currentMetrics = metrics
        return ZStack {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)

            Capsule(style: .continuous)
                .fill(Color.white.opacity(currentMetrics.surfaceWhiteOpacity))

            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(
                                color: Color.white.opacity(currentMetrics.specularBorderOpacity * 0.85),
                                location: 0.0
                            ),
                            .init(
                                color: PrismColor.figmaHex("#38BDF8").opacity(currentMetrics.prismGlowOpacity * 0.45),
                                location: 0.28
                            ),
                            .init(
                                color: Color.clear,
                                location: 0.65
                            ),
                            .init(
                                color: PrismColor.figmaHex("#6366F1").opacity(currentMetrics.prismGlowOpacity * 0.35),
                                location: 1.0
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(
            color: Color.black.opacity(currentMetrics.dropShadowOpacity),
            radius: currentMetrics.dropShadowRadius,
            x: 0,
            y: 4
        )
    }

    private var liquidGlassSpecularRim: some View {
        let currentMetrics = metrics
        return Capsule(style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(
                            color: Color.white.opacity(currentMetrics.specularBorderOpacity),
                            location: 0.0
                        ),
                        .init(
                            color: PrismColor.figmaHex("#93C5FD").opacity(currentMetrics.prismGlowOpacity),
                            location: 0.5
                        ),
                        .init(
                            color: PrismColor.figmaHex("#CBD5E1").opacity(0.85),
                            location: 1.0
                        )
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
    }
}
#endif
