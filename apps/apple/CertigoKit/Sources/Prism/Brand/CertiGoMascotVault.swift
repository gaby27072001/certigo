import BrandAssets
import CertigoData
import CertigoDomain
import Foundation

#if canImport(Network)
import Network
#endif

// MARK: - 1. Contextual Mascot Vault Catalog (`CertiGoMascotVault`)

public enum CertiGoMascotVault {
    public static let allOutfits: [CertiGoMascotOutfit] = CertiGoMascotOutfit.allCases
    public static let allThemes: [CertiGoMascotThemeVariant] = CertiGoMascotThemeVariant.allCases

    public static func geometrySpec(for outfit: CertiGoMascotOutfit) -> CertiGoMascotVectorGeometrySpec {
        CertiGoMascotVectorGeometrySpec.spec(for: outfit)
    }

    /// Maps legacy 24-pose enum cases to their closest contextual mascot outfit when rendered in vector mode.
    public static func outfit(for pose: CertiGoMascotPose) -> CertiGoMascotOutfit {
        switch pose {
        case .emotionOnFire:
            return .streakFire
        case .emotionBossCrown:
            return .prestigePro
        case .emotionOopsCaring:
            return .sadMissing
        case .poseCLICoder, .poseAnalyst:
            return .coffeeBoost
        case .posePresenter, .poseCrossedArms, .emotionDetermined:
            return .suitBoss
        case .poseReaderMemo:
            return .morningPajama
        default:
            return .happyActive
        }
    }
}

// MARK: - 2. Alternate App Icon Driver Protocol & iOS Dynamic App Icon Manager (`CertiGoDynamicAppIconManager`)

public protocol CertiGoAlternateIconDriver: Sendable {
    @MainActor var supportsAlternateIcons: Bool { get }
    @MainActor var currentAlternateIconName: String? { get }
    @MainActor func setAlternateIconName(_ name: String?) async throws
}

public struct CertiGoSystemAlternateIconDriver: CertiGoAlternateIconDriver {
    public init() {}

    @MainActor
    public var supportsAlternateIcons: Bool {
        #if canImport(UIKit) && !os(macOS)
        return UIApplication.shared.supportsAlternateIcons
        #else
        return true
        #endif
    }

    @MainActor
    public var currentAlternateIconName: String? {
        #if canImport(UIKit) && !os(macOS)
        return UIApplication.shared.alternateIconName
        #else
        return nil
        #endif
    }

    @MainActor
    public func setAlternateIconName(_ name: String?) async throws {
        #if canImport(UIKit) && !os(macOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        if UIApplication.shared.alternateIconName != name {
            try await UIApplication.shared.setAlternateIconName(name)
        }
        #endif
    }
}

/// Manages automatic and manual iOS Home Screen dynamic icons (`UIApplication.shared.setAlternateIconName`)
/// and real-time Airplane/Offline detection (`NWPathMonitor`).
@MainActor
public final class CertiGoDynamicAppIconManager {
    public static let shared = CertiGoDynamicAppIconManager()
    public static let preferencesDefaultsKey = "com.certigo.native.mascot-vault-preferences.v1"

    public private(set) var preferences: CertiGoMascotDynamicPreferences
    public private(set) var currentContext: CertiGoMascotContextInput
    public private(set) var activeOutfit: CertiGoMascotOutfit
    public private(set) var activeTheme: CertiGoMascotThemeVariant
    public private(set) var lastAppliedAlternateIconName: String?
    public private(set) var isNetworkOfflineDetected: Bool = false
    public private(set) var lastIconSyncMessage: String?

    private let defaults: UserDefaults
    private let preferencesKey: String
    private let driver: any CertiGoAlternateIconDriver

    #if canImport(Network)
    private var pathMonitor: NWPathMonitor?
    private let monitorQueue = DispatchQueue(label: "com.certigo.native.mascot-network-monitor")
    #endif

    public init(
        defaults: UserDefaults = .standard,
        preferencesKey: String = CertiGoDynamicAppIconManager.preferencesDefaultsKey,
        driver: any CertiGoAlternateIconDriver = CertiGoSystemAlternateIconDriver(),
        initialContext: CertiGoMascotContextInput = CertiGoMascotContextInput(),
        startNetworkMonitor: Bool = false
    ) {
        self.defaults = defaults
        self.preferencesKey = preferencesKey
        self.driver = driver
        if let data = defaults.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(CertiGoMascotDynamicPreferences.self, from: data)
        {
            self.preferences = decoded
        } else {
            self.preferences = CertiGoMascotDynamicPreferences()
        }
        self.currentContext = initialContext
        let resolvedOutfit = CertiGoMascotContextEvaluator.recommendedOutfit(
            for: initialContext,
            preferences: self.preferences
        )
        self.activeOutfit = resolvedOutfit
        self.activeTheme = CertiGoMascotContextEvaluator.resolvedTheme(
            for: resolvedOutfit,
            context: initialContext,
            preferences: self.preferences
        )
        self.lastAppliedAlternateIconName = driver.currentAlternateIconName

        if startNetworkMonitor {
            startMonitoringNetworkPath()
        }
    }

    public func startMonitoringNetworkPath() {
        #if canImport(Network)
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isOffline = (path.status != .satisfied)
            Task { @MainActor [weak self] in
                self?.handleNetworkOfflineStatusChanged(isOffline)
            }
        }
        monitor.start(queue: monitorQueue)
        self.pathMonitor = monitor
        #endif
    }

    public func stopMonitoringNetworkPath() {
        #if canImport(Network)
        pathMonitor?.cancel()
        pathMonitor = nil
        #endif
    }

    public func handleNetworkOfflineStatusChanged(_ isOffline: Bool) {
        isNetworkOfflineDetected = isOffline
        var updatedContext = currentContext
        updatedContext.isOfflineOrAirplaneMode = isOffline
        Task { @MainActor in
            await evaluateAndApply(context: updatedContext)
        }
    }

    @discardableResult
    public func evaluateAndApply(
        context: CertiGoMascotContextInput,
        calendar: Calendar = .current
    ) async -> CertiGoMascotOutfit {
        self.currentContext = context
        let outfit = CertiGoMascotContextEvaluator.recommendedOutfit(
            for: context,
            preferences: preferences,
            calendar: calendar
        )
        let theme = CertiGoMascotContextEvaluator.resolvedTheme(
            for: outfit,
            context: context,
            preferences: preferences
        )
        self.activeOutfit = outfit
        self.activeTheme = theme
        await applyIconToHomeScreen(outfit: outfit, theme: theme)
        return outfit
    }

    public func setSelectionMode(_ mode: CertigoAppIconSelectionMode) async {
        preferences.selectionMode = mode
        savePreferences()
        await evaluateAndApply(context: currentContext)
    }

    public func selectManualOutfit(_ outfit: CertiGoMascotOutfit) async {
        preferences.selectionMode = .manual
        preferences.manualOutfit = outfit
        if outfit == .prestigePro {
            preferences.preferredTheme = .prestigeGoldBlack
        }
        savePreferences()
        await evaluateAndApply(context: currentContext)
    }

    public func selectPreferredTheme(_ theme: CertiGoMascotThemeVariant?) async {
        preferences.preferredTheme = theme
        savePreferences()
        await evaluateAndApply(context: currentContext)
    }

    private func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            defaults.set(encoded, forKey: preferencesKey)
        }
    }

    private func applyIconToHomeScreen(
        outfit: CertiGoMascotOutfit,
        theme: CertiGoMascotThemeVariant
    ) async {
        let targetIconName = outfit.resolvedAlternateIconName(for: theme)
        guard driver.supportsAlternateIcons else {
            lastIconSyncMessage = "Aperçu actif dans CertiGo (\(outfit.displayName) · \(theme.shortTitle))"
            return
        }
        if lastAppliedAlternateIconName == targetIconName && driver.currentAlternateIconName == targetIconName {
            lastIconSyncMessage = "Icône iOS synchronisée : \(outfit.displayName) (\(theme.shortTitle))"
            return
        }
        do {
            try await driver.setAlternateIconName(targetIconName)
            lastAppliedAlternateIconName = targetIconName
            lastIconSyncMessage = "Icône d'accueil iPhone mise à jour : \(outfit.displayName) (\(theme.shortTitle))"
        } catch {
            lastAppliedAlternateIconName = targetIconName
            lastIconSyncMessage = "Costume appliqué dans CertiGo : \(outfit.displayName) (\(theme.shortTitle))"
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

// MARK: - 3. Pro Vector Mascot Avatar Renderer (`CertiGoMascotAvatarView`)

/// Renders the refactored CertiGo owl-shield mascot with 100% vector precision across all 8 contextual outfits
/// and Light (`#07.1`), Dark (`#07.2`), and Prestige (`#07.10`) themes.
public struct CertiGoMascotAvatarView: View {
    public let outfit: CertiGoMascotOutfit
    public let theme: CertiGoMascotThemeVariant
    public let size: CGFloat
    public let showAppIconSquircle: Bool

    public init(
        outfit: CertiGoMascotOutfit = .happyActive,
        theme: CertiGoMascotThemeVariant = .light,
        size: CGFloat = PrismSize.mascotQuiz,
        showAppIconSquircle: Bool = false
    ) {
        self.outfit = outfit
        self.theme = theme
        self.size = size
        self.showAppIconSquircle = showAppIconSquircle
    }

    public var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let spec = CertiGoMascotVectorGeometrySpec.spec(for: outfit)

            // 1. Optional App Icon Squircle Backdrop (#07.1 Light, #07.2 Dark, #07.10 Prestige Gold & Black)
            if showAppIconSquircle {
                let squircleRect = CGRect(x: 0, y: 0, width: w, height: h)
                let squirclePath = Path(
                    roundedRect: squircleRect,
                    cornerRadius: w * 0.225
                )
                context.fill(
                    squirclePath,
                    with: .linearGradient(
                        Gradient(colors: [
                            PrismColor.figmaHex(theme.backgroundPrimaryHex),
                            PrismColor.figmaHex(theme.backgroundSecondaryHex)
                        ]),
                        startPoint: CGPoint(x: w * 0.5, y: 0),
                        endPoint: CGPoint(x: w * 0.5, y: h)
                    )
                )

                // Subtle Azure / Gold Halo Ring inside the App Icon
                let haloRect = squircleRect.insetBy(dx: w * 0.055, dy: h * 0.055)
                let haloPath = Path(ellipseIn: haloRect)
                context.stroke(
                    haloPath,
                    with: .color(PrismColor.figmaHex(theme.haloRingHex).opacity(theme == .light ? 0.28 : 0.42)),
                    lineWidth: max(1.5, w * 0.022)
                )
            }

            // 2. Symmetric Orange Feet (100% symmetric: left = 0.39, right = 0.61, y = 0.865)
            let footW = w * CGFloat(spec.footWidthRatio)
            let footH = h * CGFloat(spec.footHeightRatio)
            let footY = h * CGFloat(spec.feetCenterY) - footH * 0.5
            for centerXRatio in [spec.leftFootCenterX, spec.rightFootCenterX] {
                let footX = w * CGFloat(centerXRatio) - footW * 0.5
                let footRect = CGRect(x: footX, y: footY, width: footW, height: footH)
                let footPath = Path(roundedRect: footRect, cornerRadius: footH * 0.48)
                context.fill(footPath, with: .color(PrismColor.figmaHex("#f97316")))
                context.stroke(
                    footPath,
                    with: .color(PrismColor.figmaHex("#c2410c")),
                    lineWidth: max(1.0, w * 0.015)
                )
            }

            // 3. Contextual Wings (behind/beside shield)
            drawWings(in: &context, width: w, height: h, outfit: outfit, theme: theme)

            // 4. Outer & Inner Shield Body (Blason CertiGo 1A)
            let shieldOuter = shieldPath(width: w, height: h, insetFactor: 0.12)
            let shieldInner = shieldPath(width: w, height: h, insetFactor: 0.17)

            let outerTopHex: String
            let outerBottomHex: String
            let innerTopHex: String
            let innerBottomHex: String

            switch (outfit, theme) {
            case (.prestigePro, _), (_, .prestigeGoldBlack):
                outerTopHex = "#fbbf24"
                outerBottomHex = "#b45309"
                innerTopHex = "#18181b"
                innerBottomHex = "#09090b"
            case (.streakFire, _):
                outerTopHex = "#fb923c"
                outerBottomHex = "#ea580c"
                innerTopHex = "#0284c7"
                innerBottomHex = "#0369a1"
            case (.sadMissing, _):
                outerTopHex = "#64748b"
                outerBottomHex = "#334155"
                innerTopHex = "#0284c7"
                innerBottomHex = "#0f172a"
            default:
                outerTopHex = "#38bdf8"
                outerBottomHex = "#0284c7"
                innerTopHex = "#0078d4"
                innerBottomHex = "#004e8c"
            }

            context.fill(
                shieldOuter,
                with: .linearGradient(
                    Gradient(colors: [
                        PrismColor.figmaHex(outerTopHex),
                        PrismColor.figmaHex(outerBottomHex)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.10),
                    endPoint: CGPoint(x: w * 0.5, y: h * 0.88)
                )
            )
            context.fill(
                shieldInner,
                with: .linearGradient(
                    Gradient(colors: [
                        PrismColor.figmaHex(innerTopHex),
                        PrismColor.figmaHex(innerBottomHex)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.15),
                    endPoint: CGPoint(x: w * 0.5, y: h * 0.84)
                )
            )

            // 5. Centered Pectoral Plastron / Contextual Outfit (strictly inside shield, never touching border!)
            drawCenteredChestOutfit(in: &context, width: w, height: h, outfit: outfit)

            // 6. Crisp Eyes (Single clean specular highlight per eye, zero overlapping stars)
            drawCleanEyes(in: &context, width: w, height: h, outfit: outfit)

            // 7. Expressive Sculpted Eyebrow Arcs (strictly ABOVE the eyes with clear separation)
            drawSculptedEyebrows(in: &context, width: w, height: h, spec: spec)

            // 8. Well-Proportioned Golden Diamond Beak
            drawGoldenBeak(in: &context, width: w, height: h, spec: spec)

            // 9. Contextual Headgear & Props (Nightcap, Coffee Cup, Aviator Goggles, Flame Crown, PRO Crown, Tear)
            drawHeadgearAndProps(in: &context, width: w, height: h, outfit: outfit)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text(verbatim: "Mascotte CertiGo · \(outfit.displayName) · \(theme.shortTitle)"))
        .accessibilityAddTraits(.isImage)
    }

    private func shieldPath(width w: CGFloat, height h: CGFloat, insetFactor: CGFloat) -> Path {
        let left = w * insetFactor
        let right = w * (1.0 - insetFactor)
        let top = h * (insetFactor + 0.02)
        let shoulderY = h * 0.24
        let midY = h * 0.56
        let bottom = h * (0.90 - (insetFactor - 0.12) * 0.85)

        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: top))
        path.addQuadCurve(
            to: CGPoint(x: right, y: shoulderY),
            control: CGPoint(x: w * 0.78, y: top)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: bottom),
            control1: CGPoint(x: right, y: midY),
            control2: CGPoint(x: w * 0.72, y: bottom * 0.96)
        )
        path.addCurve(
            to: CGPoint(x: left, y: shoulderY),
            control1: CGPoint(x: w * 0.28, y: bottom * 0.96),
            control2: CGPoint(x: left, y: midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.5, y: top),
            control: CGPoint(x: w * 0.22, y: top)
        )
        path.closeSubpath()
        return path
    }

    private func drawWings(
        in context: inout GraphicsContext,
        width w: CGFloat,
        height h: CGFloat,
        outfit: CertiGoMascotOutfit,
        theme: CertiGoMascotThemeVariant
    ) {
        let wingColor: Color = {
            if outfit == .prestigePro || theme == .prestigeGoldBlack {
                return PrismColor.figmaHex("#f59e0b")
            }
            if outfit == .sadMissing {
                return PrismColor.figmaHex("#64748b")
            }
            if outfit == .suitBoss {
                return PrismColor.figmaHex("#1e293b")
            }
            return PrismColor.figmaHex("#0284c7")
        }()

        let isRaised = (outfit == .happyActive || outfit == .streakFire || outfit == .airplaneOffline)
        let isDrooped = (outfit == .sadMissing)

        let leftWing = Path { p in
            p.move(to: CGPoint(x: w * 0.18, y: h * 0.42))
            if isRaised {
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.05, y: h * 0.26),
                    control: CGPoint(x: w * 0.04, y: h * 0.36)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.19, y: h * 0.56),
                    control: CGPoint(x: w * 0.08, y: h * 0.48)
                )
            } else if isDrooped {
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.08, y: h * 0.64),
                    control: CGPoint(x: w * 0.05, y: h * 0.50)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.22, y: h * 0.62),
                    control: CGPoint(x: w * 0.14, y: h * 0.68)
                )
            } else {
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.06, y: h * 0.48),
                    control: CGPoint(x: w * 0.04, y: h * 0.38)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.20, y: h * 0.58),
                    control: CGPoint(x: w * 0.09, y: h * 0.58)
                )
            }
            p.closeSubpath()
        }

        let rightWing = Path { p in
            p.move(to: CGPoint(x: w * 0.82, y: h * 0.42))
            if isRaised {
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.95, y: h * 0.26),
                    control: CGPoint(x: w * 0.96, y: h * 0.36)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.81, y: h * 0.56),
                    control: CGPoint(x: w * 0.92, y: h * 0.48)
                )
            } else if isDrooped {
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.92, y: h * 0.64),
                    control: CGPoint(x: w * 0.95, y: h * 0.50)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.78, y: h * 0.62),
                    control: CGPoint(x: w * 0.86, y: h * 0.68)
                )
            } else {
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.94, y: h * 0.48),
                    control: CGPoint(x: w * 0.96, y: h * 0.38)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.80, y: h * 0.58),
                    control: CGPoint(x: w * 0.91, y: h * 0.58)
                )
            }
            p.closeSubpath()
        }

        context.fill(leftWing, with: .color(wingColor))
        context.fill(rightWing, with: .color(wingColor))
    }

    private func drawCenteredChestOutfit(
        in context: inout GraphicsContext,
        width w: CGFloat,
        height h: CGFloat,
        outfit: CertiGoMascotOutfit
    ) {
        // Strictly centered inside the lower chest (x: 0.31..0.69, y: 0.57..0.77) -> generous margin inside shield!
        let plastronRect = CGRect(x: w * 0.31, y: h * 0.57, width: w * 0.38, height: h * 0.19)
        let plastronPath = Path(roundedRect: plastronRect, cornerRadius: w * 0.08)

        switch outfit {
        case .morningPajama:
            // Soft sky pajama top with vertical stripes strictly inside the chest badge
            context.fill(plastronPath, with: .color(PrismColor.figmaHex("#e0f2fe")))
            for ratio in [0.37, 0.45, 0.55, 0.63] {
                let stripeRect = CGRect(
                    x: w * CGFloat(ratio),
                    y: plastronRect.minY + h * 0.015,
                    width: w * 0.025,
                    height: plastronRect.height - h * 0.03
                )
                context.fill(
                    Path(roundedRect: stripeRect, cornerRadius: w * 0.01),
                    with: .color(PrismColor.figmaHex("#38bdf8"))
                )
            }

        case .suitBoss:
            // Cloud Architect Navy Suit Lapels + White Shirt + Azure Tie centered with margin
            context.fill(plastronPath, with: .color(PrismColor.figmaHex("#0f172a")))
            let shirtTriangle = Path { p in
                p.move(to: CGPoint(x: w * 0.42, y: plastronRect.minY))
                p.addLine(to: CGPoint(x: w * 0.58, y: plastronRect.minY))
                p.addLine(to: CGPoint(x: w * 0.50, y: plastronRect.maxY - h * 0.02))
                p.closeSubpath()
            }
            context.fill(shirtTriangle, with: .color(PrismColor.figmaHex("#f8fafc")))
            let tiePath = Path { p in
                p.move(to: CGPoint(x: w * 0.485, y: plastronRect.minY + h * 0.01))
                p.addLine(to: CGPoint(x: w * 0.515, y: plastronRect.minY + h * 0.01))
                p.addLine(to: CGPoint(x: w * 0.525, y: plastronRect.maxY - h * 0.04))
                p.addLine(to: CGPoint(x: w * 0.50, y: plastronRect.maxY - h * 0.015))
                p.addLine(to: CGPoint(x: w * 0.475, y: plastronRect.maxY - h * 0.04))
                p.closeSubpath()
            }
            context.fill(tiePath, with: .color(PrismColor.figmaHex("#0ea5e9")))

        case .airplaneOffline:
            // Warm Aviator Scarf centered below the beak with flowing tail inside the chest
            let scarfCollar = CGRect(x: w * 0.32, y: h * 0.565, width: w * 0.36, height: h * 0.065)
            context.fill(
                Path(roundedRect: scarfCollar, cornerRadius: h * 0.03),
                with: .color(PrismColor.figmaHex("#ef4444"))
            )
            let scarfTail = Path { p in
                p.move(to: CGPoint(x: w * 0.52, y: h * 0.61))
                p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.68))
                p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.74))
                p.addLine(to: CGPoint(x: w * 0.47, y: h * 0.63))
                p.closeSubpath()
            }
            context.fill(scarfTail, with: .color(PrismColor.figmaHex("#dc2626")))

        case .prestigePro:
            // Royal Gold & Black engraved chest crest (#07.10)
            context.fill(plastronPath, with: .color(PrismColor.figmaHex("#1c1917")))
            context.stroke(
                plastronPath,
                with: .color(PrismColor.figmaHex("#fbbf24")),
                lineWidth: max(1.5, w * 0.022)
            )
            let diamond = centeredDiamondPath(centerX: w * 0.5, centerY: h * 0.665, radius: w * 0.065)
            context.fill(diamond, with: .color(PrismColor.figmaHex("#fbbf24")))

        case .streakFire:
            // Solar Flame Crest centered on chest
            context.fill(plastronPath, with: .color(PrismColor.figmaHex("#0369a1")))
            let flame = centeredDiamondPath(centerX: w * 0.5, centerY: h * 0.665, radius: w * 0.07)
            context.fill(flame, with: .color(PrismColor.figmaHex("#fb923c")))

        case .coffeeBoost:
            // Focus Espresso Crest centered on chest
            context.fill(plastronPath, with: .color(PrismColor.figmaHex("#0284c7")))
            let bean = Path(
                ellipseIn: CGRect(x: w * 0.445, y: h * 0.625, width: w * 0.11, height: h * 0.08)
            )
            context.fill(bean, with: .color(PrismColor.figmaHex("#fde68a")))

        case .sadMissing:
            // Soft muted chest medallion
            context.fill(plastronPath, with: .color(PrismColor.figmaHex("#1e293b").opacity(0.65)))
            let core = centeredDiamondPath(centerX: w * 0.5, centerY: h * 0.665, radius: w * 0.055)
            context.fill(core, with: .color(PrismColor.figmaHex("#94a3b8")))

        case .happyActive:
            // Crisp centered Azure pectoral shield medallion (replaces the old V-bar!)
            context.fill(plastronPath, with: .color(PrismColor.figmaHex("#0284c7").opacity(0.85)))
            context.stroke(
                plastronPath,
                with: .color(PrismColor.figmaHex("#7dd3fc")),
                lineWidth: max(1.2, w * 0.018)
            )
            let core = centeredDiamondPath(centerX: w * 0.5, centerY: h * 0.665, radius: w * 0.06)
            context.fill(core, with: .color(PrismColor.figmaHex("#e0f2fe")))
        }
    }

    private func centeredDiamondPath(centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: centerX, y: centerY - radius))
            p.addLine(to: CGPoint(x: centerX + radius, y: centerY))
            p.addLine(to: CGPoint(x: centerX, y: centerY + radius))
            p.addLine(to: CGPoint(x: centerX - radius, y: centerY))
            p.closeSubpath()
        }
    }

    private func drawCleanEyes(
        in context: inout GraphicsContext,
        width w: CGFloat,
        height h: CGFloat,
        outfit: CertiGoMascotOutfit
    ) {
        let eyeRadius = w * 0.095
        let eyeCenterY = h * 0.415
        let leftEyeX = w * 0.365
        let rightEyeX = w * 0.635

        for cx in [leftEyeX, rightEyeX] {
            let scleraRect = CGRect(
                x: cx - eyeRadius,
                y: eyeCenterY - eyeRadius,
                width: eyeRadius * 2,
                height: eyeRadius * 2
            )
            context.fill(Path(ellipseIn: scleraRect), with: .color(PrismColor.figmaHex("#ffffff")))

            let pupilRadius = eyeRadius * 0.62
            let pupilRect = CGRect(
                x: cx - pupilRadius,
                y: eyeCenterY - pupilRadius,
                width: pupilRadius * 2,
                height: pupilRadius * 2
            )
            context.fill(Path(ellipseIn: pupilRect), with: .color(PrismColor.figmaHex("#0f172a")))

            // Single clean specular highlight (no overlapping star!)
            let specRadius = eyeRadius * 0.24
            let specRect = CGRect(
                x: cx - pupilRadius * 0.48,
                y: eyeCenterY - pupilRadius * 0.52,
                width: specRadius * 2,
                height: specRadius * 2
            )
            context.fill(Path(ellipseIn: specRect), with: .color(PrismColor.figmaHex("#ffffff")))

            if outfit == .morningPajama {
                // Warm sleepy upper eyelid crescent
                let lidRect = CGRect(
                    x: cx - eyeRadius,
                    y: eyeCenterY - eyeRadius,
                    width: eyeRadius * 2,
                    height: eyeRadius * 0.72
                )
                context.fill(Path(ellipseIn: lidRect), with: .color(PrismColor.figmaHex("#0284c7")))
            }
        }
    }

    private func drawSculptedEyebrows(
        in context: inout GraphicsContext,
        width w: CGFloat,
        height h: CGFloat,
        spec: CertiGoMascotVectorGeometrySpec
    ) {
        // Eyebrows are positioned strictly ABOVE the eyes (`eyebrowBottomY` ~ 0.295 vs `eyeTopY` = 0.365)
        let browY = h * CGFloat(spec.eyebrowBottomY)
        let strokeW = max(2.0, w * 0.032)
        let browHex = (spec.outfit == .prestigePro) ? "#fbbf24" : "#e0f2fe"

        var leftBrow = Path()
        var rightBrow = Path()

        switch spec.eyebrowArc {
        case .sadSloped:
            // Inner ends raised, outer ends sloped down gently (expressive sad brow above eye)
            leftBrow.move(to: CGPoint(x: w * 0.26, y: browY + h * 0.012))
            leftBrow.addQuadCurve(
                to: CGPoint(x: w * 0.45, y: browY - h * 0.022),
                control: CGPoint(x: w * 0.35, y: browY - h * 0.018)
            )
            rightBrow.move(to: CGPoint(x: w * 0.55, y: browY - h * 0.022))
            rightBrow.addQuadCurve(
                to: CGPoint(x: w * 0.74, y: browY + h * 0.012),
                control: CGPoint(x: w * 0.65, y: browY - h * 0.018)
            )

        case .confidentExecutive, .blazingDetermined, .royalPrestige:
            // Focused, heroic arch cleanly above the eyes
            leftBrow.move(to: CGPoint(x: w * 0.26, y: browY - h * 0.010))
            leftBrow.addQuadCurve(
                to: CGPoint(x: w * 0.45, y: browY + h * 0.004),
                control: CGPoint(x: w * 0.36, y: browY - h * 0.028)
            )
            rightBrow.move(to: CGPoint(x: w * 0.55, y: browY + h * 0.004))
            rightBrow.addQuadCurve(
                to: CGPoint(x: w * 0.74, y: browY - h * 0.010),
                control: CGPoint(x: w * 0.64, y: browY - h * 0.028)
            )

        default:
            // Harmonious joyful/alert arch cleanly above the eyes
            leftBrow.move(to: CGPoint(x: w * 0.26, y: browY))
            leftBrow.addQuadCurve(
                to: CGPoint(x: w * 0.45, y: browY),
                control: CGPoint(x: w * 0.355, y: browY - h * 0.032)
            )
            rightBrow.move(to: CGPoint(x: w * 0.55, y: browY))
            rightBrow.addQuadCurve(
                to: CGPoint(x: w * 0.74, y: browY),
                control: CGPoint(x: w * 0.645, y: browY - h * 0.032)
            )
        }

        context.stroke(
            leftBrow,
            with: .color(PrismColor.figmaHex(browHex)),
            style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
        )
        context.stroke(
            rightBrow,
            with: .color(PrismColor.figmaHex(browHex)),
            style: StrokeStyle(lineWidth: strokeW, lineCap: .round)
        )
    }

    private func drawGoldenBeak(
        in context: inout GraphicsContext,
        width w: CGFloat,
        height h: CGFloat,
        spec: CertiGoMascotVectorGeometrySpec
    ) {
        let cx = w * CGFloat(spec.beakCenterX)
        let cy = h * CGFloat(spec.beakCenterY)
        let halfW = w * CGFloat(spec.beakWidthRatio) * 0.5
        let halfH = h * CGFloat(spec.beakHeightRatio) * 0.5

        let beakPath = Path { p in
            p.move(to: CGPoint(x: cx, y: cy - halfH))
            p.addLine(to: CGPoint(x: cx + halfW, y: cy))
            p.addLine(to: CGPoint(x: cx, y: cy + halfH))
            p.addLine(to: CGPoint(x: cx - halfW, y: cy))
            p.closeSubpath()
        }
        context.fill(
            beakPath,
            with: .linearGradient(
                Gradient(colors: [
                    PrismColor.figmaHex("#fbbf24"),
                    PrismColor.figmaHex("#d97706")
                ]),
                startPoint: CGPoint(x: cx, y: cy - halfH),
                endPoint: CGPoint(x: cx, y: cy + halfH)
            )
        )
    }

    private func drawHeadgearAndProps(
        in context: inout GraphicsContext,
        width w: CGFloat,
        height h: CGFloat,
        outfit: CertiGoMascotOutfit
    ) {
        switch outfit {
        case .sadMissing:
            // Crystalline tear droplet under the left eye
            let tearPath = Path { p in
                p.move(to: CGPoint(x: w * 0.31, y: h * 0.48))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.31, y: h * 0.56),
                    control: CGPoint(x: w * 0.26, y: h * 0.54)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.31, y: h * 0.48),
                    control: CGPoint(x: w * 0.36, y: h * 0.54)
                )
                p.closeSubpath()
            }
            context.fill(tearPath, with: .color(PrismColor.figmaHex("#38bdf8")))

        case .morningPajama:
            // Cozy Nightcap on head + pom-pom + steaming mug held on right side
            let capPath = Path { p in
                p.move(to: CGPoint(x: w * 0.28, y: h * 0.20))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.74, y: h * 0.12),
                    control: CGPoint(x: w * 0.52, y: h * 0.04)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.70, y: h * 0.21),
                    control: CGPoint(x: w * 0.78, y: h * 0.18)
                )
                p.closeSubpath()
            }
            context.fill(capPath, with: .color(PrismColor.figmaHex("#6366f1")))
            let pomPom = Path(
                ellipseIn: CGRect(x: w * 0.71, y: h * 0.09, width: w * 0.08, height: h * 0.08)
            )
            context.fill(pomPom, with: .color(PrismColor.figmaHex("#fef08a")))
            drawSteamingCoffeeCup(in: &context, width: w, height: h, isToGoCup: false)

        case .coffeeBoost:
            drawSteamingCoffeeCup(in: &context, width: w, height: h, isToGoCup: true)

        case .airplaneOffline:
            // Vintage Aviator Goggles perched cleanly on forehead above the eyebrows
            let strapRect = CGRect(x: w * 0.24, y: h * 0.18, width: w * 0.52, height: h * 0.045)
            context.fill(Path(roundedRect: strapRect, cornerRadius: h * 0.02), with: .color(PrismColor.figmaHex("#78350f")))
            for gx in [w * 0.33, w * 0.53] {
                let lensRect = CGRect(x: gx, y: h * 0.155, width: w * 0.14, height: h * 0.09)
                let lensPath = Path(roundedRect: lensRect, cornerRadius: h * 0.03)
                context.fill(lensPath, with: .color(PrismColor.figmaHex("#38bdf8")))
                context.stroke(lensPath, with: .color(PrismColor.figmaHex("#f59e0b")), lineWidth: max(1.5, w * 0.02))
            }

        case .streakFire:
            // Golden-Orange Flame Crown at crest of head
            let crownPath = Path { p in
                p.move(to: CGPoint(x: w * 0.34, y: h * 0.20))
                p.addLine(to: CGPoint(x: w * 0.40, y: h * 0.08))
                p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.05))
                p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.60, y: h * 0.08))
                p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.20))
                p.closeSubpath()
            }
            context.fill(crownPath, with: .color(PrismColor.figmaHex("#f97316")))

        case .prestigePro:
            // Sovereign Gold & Obsidian Crown (#07.10)
            let crownPath = Path { p in
                p.move(to: CGPoint(x: w * 0.33, y: h * 0.20))
                p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.09))
                p.addLine(to: CGPoint(x: w * 0.44, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.07))
                p.addLine(to: CGPoint(x: w * 0.56, y: h * 0.16))
                p.addLine(to: CGPoint(x: w * 0.64, y: h * 0.09))
                p.addLine(to: CGPoint(x: w * 0.67, y: h * 0.20))
                p.closeSubpath()
            }
            context.fill(crownPath, with: .color(PrismColor.figmaHex("#fbbf24")))

        case .happyActive, .suitBoss:
            break
        }
    }

    private func drawSteamingCoffeeCup(
        in context: inout GraphicsContext,
        width w: CGFloat,
        height h: CGFloat,
        isToGoCup: Bool
    ) {
        let cupRect = CGRect(x: w * 0.74, y: h * 0.48, width: w * 0.16, height: h * 0.19)
        let cupPath = Path(roundedRect: cupRect, cornerRadius: w * 0.03)
        context.fill(
            cupPath,
            with: .color(PrismColor.figmaHex(isToGoCup ? "#f59e0b" : "#ffffff"))
        )
        context.stroke(
            cupPath,
            with: .color(PrismColor.figmaHex("#78350f")),
            lineWidth: max(1.2, w * 0.018)
        )
        // Coffee sleeve / band
        let sleeveRect = CGRect(x: w * 0.74, y: h * 0.54, width: w * 0.16, height: h * 0.06)
        context.fill(Path(sleeveRect), with: .color(PrismColor.figmaHex("#92400e")))

        // Rising steam wisps
        for steamX in [w * 0.79, w * 0.85] {
            var steam = Path()
            steam.move(to: CGPoint(x: steamX, y: h * 0.45))
            steam.addQuadCurve(
                to: CGPoint(x: steamX, y: h * 0.36),
                control: CGPoint(x: steamX + w * 0.03, y: h * 0.40)
            )
            context.stroke(
                steam,
                with: .color(PrismColor.figmaHex("#bae6fd")),
                style: StrokeStyle(lineWidth: max(1.2, w * 0.018), lineCap: .round)
            )
        }
    }
}

// MARK: - 4. Dedicated Interactive Mascot Vault & Dynamic App Icon Sheet (`CertiGoMascotVaultSheetView`)

public struct CertiGoMascotVaultSheetView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let selectedOutfit: CertiGoMascotOutfit
    public let selectedTheme: CertiGoMascotThemeVariant
    public let selectionMode: CertigoAppIconSelectionMode
    public let isOfflineSimulated: Bool
    public let isInactivitySimulated: Bool
    public let isMorningSimulated: Bool
    public let isCoffeeSimulated: Bool
    public let isExamModeSimulated: Bool
    public let isProMember: Bool
    public let streakDays: Int
    public let statusBannerText: String
    public let onSelectMode: (CertigoAppIconSelectionMode) -> Void
    public let onSelectOutfit: (CertiGoMascotOutfit) -> Void
    public let onSelectTheme: (CertiGoMascotThemeVariant) -> Void
    public let onToggleSimulationSignal: (String) -> Void
    public let onClose: () -> Void

    public init(
        selectedOutfit: CertiGoMascotOutfit,
        selectedTheme: CertiGoMascotThemeVariant,
        selectionMode: CertigoAppIconSelectionMode,
        isOfflineSimulated: Bool = false,
        isInactivitySimulated: Bool = false,
        isMorningSimulated: Bool = false,
        isCoffeeSimulated: Bool = false,
        isExamModeSimulated: Bool = false,
        isProMember: Bool = false,
        streakDays: Int = 0,
        statusBannerText: String = "",
        onSelectMode: @escaping (CertigoAppIconSelectionMode) -> Void,
        onSelectOutfit: @escaping (CertiGoMascotOutfit) -> Void,
        onSelectTheme: @escaping (CertiGoMascotThemeVariant) -> Void,
        onToggleSimulationSignal: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.selectedOutfit = selectedOutfit
        self.selectedTheme = selectedTheme
        self.selectionMode = selectionMode
        self.isOfflineSimulated = isOfflineSimulated
        self.isInactivitySimulated = isInactivitySimulated
        self.isMorningSimulated = isMorningSimulated
        self.isCoffeeSimulated = isCoffeeSimulated
        self.isExamModeSimulated = isExamModeSimulated
        self.isProMember = isProMember
        self.streakDays = streakDays
        self.statusBannerText = statusBannerText
        self.onSelectMode = onSelectMode
        self.onSelectOutfit = onSelectOutfit
        self.onSelectTheme = onSelectTheme
        self.onToggleSimulationSignal = onToggleSimulationSignal
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: .zero) {
            // Top Header Bar
            HStack {
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: "SHEET 05 · MASCOTTE & ICÔNE iOS DYNAMIQUE")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    Text(verbatim: "Banque & Costumes de la Mascotte")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                }
                Spacer()
                Button(action: onClose) {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
                        .background(Circle().fill(PrismColor.figmaHex("#e2e8f0")))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("mascot-vault-close-button")
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.vertical, PrismSpacing.m)
            .background(PrismColor.surface)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    // Hero Live Preview Card (In-App Avatar + Home Screen Squircle Preview Light & Dark)
                    VStack(spacing: PrismSpacing.m) {
                        HStack(spacing: PrismSpacing.l) {
                            VStack(spacing: PrismSpacing.xs) {
                                CertiGoMascotAvatarView(
                                    outfit: selectedOutfit,
                                    theme: selectedTheme,
                                    size: FigMetrics.ninetySix,
                                    showAppIconSquircle: false
                                )
                                Text(verbatim: "Mascotte App")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }

                            VStack(spacing: PrismSpacing.xs) {
                                CertiGoMascotAvatarView(
                                    outfit: selectedOutfit,
                                    theme: selectedTheme,
                                    size: FigMetrics.eightyEight,
                                    showAppIconSquircle: true
                                )
                                Text(verbatim: "CertiGo")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            }
                        }

                        Text(verbatim: selectedOutfit.displayName)
                            .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                        Text(verbatim: selectedOutfit.subtitle)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#475569"))
                            .multilineTextAlignment(.center)

                        if !statusBannerText.isEmpty {
                            Text(verbatim: statusBannerText)
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                                .padding(.horizontal, PrismSpacing.m)
                                .padding(.vertical, PrismSpacing.xs)
                                .background(
                                    Capsule().fill(PrismColor.figmaHex("#e0f2fe"))
                                )
                        }
                    }
                    .padding(PrismSpacing.l)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#cbd5e1"), lineWidth: PrismBorder.standard)
                    )

                    // Automatic vs Manual Mode Switcher
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: "MODE D'ADAPTATION DE L'ICÔNE iPHONE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        HStack(spacing: PrismSpacing.s) {
                            modePillButton(
                                title: "⚡ Automatique (Contextuel)",
                                isSelected: selectionMode == .automatic
                            ) {
                                onSelectMode(.automatic)
                            }
                            .accessibilityIdentifier("mascot-vault-mode-automatic")

                            modePillButton(
                                title: "🎨 Forcer un costume",
                                isSelected: selectionMode == .manual
                            ) {
                                onSelectMode(.manual)
                            }
                            .accessibilityIdentifier("mascot-vault-mode-manual")
                        }
                    }

                    // Light (#07.1) / Dark (#07.2) / Prestige (#07.10) Theme Switcher
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: "THÈME D'ICÔNE CLAIR / SOMBRE (#07.1 · #07.2 · #07.10)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        HStack(spacing: PrismSpacing.s) {
                            ForEach(CertiGoMascotThemeVariant.allCases) { themeVariant in
                                let isSelected = (selectedTheme == themeVariant)
                                Button {
                                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                        onSelectTheme(themeVariant)
                                    }
                                } label: {
                                    Text(verbatim: themeVariant.shortTitle)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                        .foregroundStyle(
                                            isSelected
                                                ? PrismColor.onAccent
                                                : PrismColor.figmaHex("#0f172a")
                                        )
                                        .padding(.horizontal, PrismSpacing.m)
                                        .frame(height: FigMetrics.thirtyEight)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                                .fill(
                                                    isSelected
                                                        ? PrismColor.figmaHex("#0078d4")
                                                        : PrismColor.surface
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                                .strokeBorder(
                                                    PrismColor.figmaHex(isSelected ? "#0078d4" : "#cbd5e1"),
                                                    lineWidth: PrismBorder.standard
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("mascot-vault-theme-\(themeVariant.rawValue)")
                            }
                        }
                    }

                    // Context Simulator Bar (test automatic triggers live!)
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: "SIMULER UN CONTEXTE iPHONE EN TEMPS RÉEL")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: PrismSpacing.s) {
                                contextSimChip(
                                    id: "airplane",
                                    label: "✈️ Mode Avion (NWPathMonitor)",
                                    active: isOfflineSimulated
                                )
                                contextSimChip(
                                    id: "inactive48h",
                                    label: "😢 Inactif > 48h",
                                    active: isInactivitySimulated
                                )
                                contextSimChip(
                                    id: "morning",
                                    label: "🛌 Réveil 06h–09h30",
                                    active: isMorningSimulated
                                )
                                contextSimChip(
                                    id: "coffee",
                                    label: "☕ Pause Café 09h30–14h",
                                    active: isCoffeeSimulated
                                )
                                contextSimChip(
                                    id: "exam",
                                    label: "👔 Mode Examen Blanc",
                                    active: isExamModeSimulated
                                )
                            }
                        }
                    }

                    // 8 Contextual Outfits Grid
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: "LES 8 TENUES & ÉTATS CONTEXTUELS DE LA MASCOTTE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        let columns = [
                            GridItem(.flexible(), spacing: PrismSpacing.m),
                            GridItem(.flexible(), spacing: PrismSpacing.m)
                        ]
                        LazyVGrid(columns: columns, spacing: PrismSpacing.m) {
                            ForEach(CertiGoMascotOutfit.allCases) { outfit in
                                outfitCardButton(outfit)
                            }
                        }
                    }
                }
                .padding(PrismSpacing.l)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }
    }

    private func modePillButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#0f172a"))
                .padding(.horizontal, PrismSpacing.m)
                .frame(height: FigMetrics.forty)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .fill(isSelected ? PrismColor.figmaHex("#0078d4") : PrismColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .strokeBorder(
                            PrismColor.figmaHex(isSelected ? "#0078d4" : "#cbd5e1"),
                            lineWidth: PrismBorder.standard
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func contextSimChip(id: String, label: String, active: Bool) -> some View {
        Button {
            onToggleSimulationSignal(id)
        } label: {
            Text(verbatim: label)
                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                .foregroundStyle(active ? PrismColor.onAccent : PrismColor.figmaHex("#334155"))
                .padding(.horizontal, PrismSpacing.m)
                .frame(height: FigMetrics.thirtySix)
                .background(
                    Capsule().fill(active ? PrismColor.figmaHex("#0284c7") : PrismColor.surface)
                )
                .overlay(
                    Capsule().strokeBorder(
                        PrismColor.figmaHex(active ? "#0284c7" : "#cbd5e1"),
                        lineWidth: PrismBorder.standard
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mascot-vault-sim-\(id)")
    }

    private func outfitCardButton(_ outfit: CertiGoMascotOutfit) -> some View {
        let isSelected = (selectedOutfit == outfit)
        let cardTheme: CertiGoMascotThemeVariant = (outfit == .prestigePro) ? .prestigeGoldBlack : selectedTheme
        return Button {
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                onSelectOutfit(outfit)
            }
        } label: {
            VStack(spacing: PrismSpacing.s) {
                CertiGoMascotAvatarView(
                    outfit: outfit,
                    theme: cardTheme,
                    size: FigMetrics.seventyTwo,
                    showAppIconSquircle: true
                )

                Text(verbatim: outfit.badgeLabel)
                    .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex(isSelected ? "#0078d4" : "#64748b"))
                    .lineLimit(1)

                Text(verbatim: outfit.displayName)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .lineLimit(1)
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(isSelected ? PrismColor.figmaHex("#eff6ff") : PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(
                        PrismColor.figmaHex(isSelected ? "#0078d4" : "#e2e8f0"),
                        lineWidth: isSelected ? FigMetrics.two : PrismBorder.standard
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mascot-vault-outfit-\(outfit.rawValue)")
    }
}
#endif
