import BrandAssets
import CertigoDomain
import Foundation

#if canImport(SwiftUI)
import SwiftUI
import Symbols
#endif

// MARK: - 1. Pure & Testable SF Symbols Animation Presets (`CertiGoSymbolAnimationPreset`)

/// Canonical Apple SF Symbols (`Symbols` framework iOS 18+ / iOS 26) animation presets used across CertiGo.
public enum CertiGoSymbolAnimationPreset: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// Discrete upward layer bounce on tab selection, gem/XP/streak increment, or key button tap.
    case bounceUpByLayer = "bounce.up.byLayer"
    /// Smooth magic replace transition between outline and `.fill` symbol variants (e.g. inactive -> active tab, speaker -> pause).
    case magicReplace = "replace.magic"
    /// Continuous iterative reversing variable color wave during AI voice reading (`speaker.wave.3.fill` / `waveform`).
    case variableColorIterative = "variableColor.iterative.reversing"
    /// Gentle layer breathing pulse on `sparkles` when CertiGo AI is thinking, listening, or synthesizing.
    case breathePulseByLayer = "breathe.pulse.byLayer"
    /// Lateral/rotational shake on a locked step padlock (`lock.fill`) or wrong answer cross (`xmark.circle.fill`).
    case wiggleByLayer = "wiggle.byLayer"
    /// Layer rotation on `arrow.clockwise` / `arrow.trianglehead.2.clockwise` when refreshing live Tech News feeds.
    case rotateByLayer = "rotate.byLayer"
    /// Persistent scale-up emphasis on an active filter, tool, or unlocked certification shield.
    case scaleUpActive = "scale.up.byLayer"

    public var id: String { rawValue }

    /// True when the animation is triggered by a discrete state change value rather than an indefinite boolean state.
    public var isDiscreteTrigger: Bool {
        switch self {
        case .bounceUpByLayer, .magicReplace, .wiggleByLayer, .rotateByLayer:
            return true
        case .variableColorIterative, .breathePulseByLayer, .scaleUpActive:
            return false
        }
    }

    /// True when the animation runs continuously while an `isActive` condition holds.
    public var isIndefiniteActive: Bool {
        !isDiscreteTrigger
    }

    /// True when individual SF Symbol layers animate with staggered phase offsets (`.byLayer`).
    public var usesByLayerRendering: Bool {
        switch self {
        case .bounceUpByLayer, .breathePulseByLayer, .wiggleByLayer, .rotateByLayer, .scaleUpActive:
            return true
        case .magicReplace, .variableColorIterative:
            return false
        }
    }

    /// Apple HIG motion purpose description for design and accessibility audits.
    public var higPurposeSummary: String {
        switch self {
        case .bounceUpByLayer:
            return "Feedback tactile immédiat sur sélection d'onglet ou gain de récompense"
        case .magicReplace:
            return "Continuité morphologique entre état contour inactif et état plein actif"
        case .variableColorIterative:
            return "Indication d'activité vocale et flux audio en cours"
        case .breathePulseByLayer:
            return "Présence vivante et calme de CertiGo AI en réflexion ou écoute"
        case .wiggleByLayer:
            return "Alerte non punitive d'élément verrouillé ou d'erreur de réponse"
        case .rotateByLayer:
            return "Confirmation visuelle de synchronisation RSS en direct"
        case .scaleUpActive:
            return "Mise en avant persistante d'un filtre actif ou d'un blason débloqué"
        }
    }

    /// Evaluates whether the full motion effect should play given the user's Accessibility Reduce Motion setting.
    public func isMotionEnabled(reduceMotion: Bool) -> Bool {
        guard reduceMotion else { return true }
        switch self {
        case .magicReplace:
            // Crossfade replacement remains legible and non-vestibular under Reduce Motion.
            return true
        case .bounceUpByLayer, .variableColorIterative, .breathePulseByLayer, .wiggleByLayer, .rotateByLayer, .scaleUpActive:
            return false
        }
    }
}

// MARK: - 2. WWDC 2026 Interactive 3D Holographic Shield Tilt Physics (`CertiGoHolographicTiltState`)

/// Deterministic 3D holographic tilt, specular shimmer offset, and sparkle intensity for certification shields (WWDC 2026 Pin Collection style).
public struct CertiGoHolographicTiltState: Equatable, Hashable, Codable, Sendable {
    public struct ShimmerOffset: Equatable, Hashable, Codable, Sendable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }

        public static let zero = ShimmerOffset(x: 0.0, y: 0.0)
    }

    /// Maximum 3D tilt angle in degrees along pitch or yaw axes (`±14°`).
    public static let maxTiltDegrees: Double = 14.0
    /// Drag distance in points that saturates the 3D tilt to `±14°`.
    public static let fullDeflectionDragDistance: Double = 80.0
    /// Interactive spring response when releasing the badge back to rest.
    public static let defaultSpringResponse: Double = 0.35
    /// Interactive spring damping fraction when releasing the badge back to rest.
    public static let defaultSpringDampingFraction: Double = 0.72

    /// Vertical tilt around the X axis in degrees, clamped to `[-14.0, +14.0]`.
    public let pitchDegrees: Double
    /// Horizontal tilt around the Y axis in degrees, clamped to `[-14.0, +14.0]`.
    public let yawDegrees: Double
    /// Normalized diagonal specular reflection offset in `[-1.0, +1.0]`.
    public let shimmerOffset: ShimmerOffset
    /// Normalized sparkle highlight intensity in `[0.0, 1.0]`.
    public let sparkleIntensity: Double
    /// Whether the badge is currently being touched/dragged.
    public let isInteracting: Bool

    public static let neutral = CertiGoHolographicTiltState(
        dragTranslation: (dx: 0.0, dy: 0.0),
        isUnlocked: true,
        reduceMotion: false
    )

    public init(
        dragTranslation: (dx: Double, dy: Double),
        isUnlocked: Bool = true,
        reduceMotion: Bool = false
    ) {
        let safeDX = dragTranslation.dx.isFinite ? dragTranslation.dx : 0.0
        let safeDY = dragTranslation.dy.isFinite ? dragTranslation.dy : 0.0

        if reduceMotion || (abs(safeDX) < 0.001 && abs(safeDY) < 0.001) {
            self.pitchDegrees = 0.0
            self.yawDegrees = 0.0
            self.shimmerOffset = .zero
            self.sparkleIntensity = isUnlocked && !reduceMotion ? 0.18 : 0.0
            self.isInteracting = false
            return
        }

        let normalizedX = min(max(safeDX / Self.fullDeflectionDragDistance, -1.0), 1.0)
        let normalizedY = min(max(safeDY / Self.fullDeflectionDragDistance, -1.0), 1.0)

        // Dragging right tilts yaw positively; dragging down tilts pitch negatively for natural physical card feel.
        let computedYaw = normalizedX * Self.maxTiltDegrees
        let computedPitch = -normalizedY * Self.maxTiltDegrees

        self.pitchDegrees = min(max(computedPitch, -Self.maxTiltDegrees), Self.maxTiltDegrees)
        self.yawDegrees = min(max(computedYaw, -Self.maxTiltDegrees), Self.maxTiltDegrees)
        self.shimmerOffset = ShimmerOffset(
            x: min(max(normalizedX * 0.85, -1.0), 1.0),
            y: min(max(normalizedY * 0.85, -1.0), 1.0)
        )

        let radialMagnitude = min(hypot(normalizedX, normalizedY), 1.0)
        let baseSparkle = isUnlocked ? (0.28 + 0.72 * radialMagnitude) : (0.15 * radialMagnitude)
        self.sparkleIntensity = min(max(baseSparkle, 0.0), 1.0)
        self.isInteracting = true
    }

    public init(
        dx: Double,
        dy: Double,
        isUnlocked: Bool = true,
        reduceMotion: Bool = false
    ) {
        self.init(
            dragTranslation: (dx: dx, dy: dy),
            isUnlocked: isUnlocked,
            reduceMotion: reduceMotion
        )
    }

    public static func compute(
        dragTranslation: (dx: Double, dy: Double),
        isUnlocked: Bool = true,
        reduceMotion: Bool = false
    ) -> CertiGoHolographicTiltState {
        CertiGoHolographicTiltState(
            dragTranslation: dragTranslation,
            isUnlocked: isUnlocked,
            reduceMotion: reduceMotion
        )
    }

    /// Angular magnitude in degrees (`0.0 ... 19.8°`).
    public var totalTiltMagnitudeDegrees: Double {
        hypot(pitchDegrees, yawDegrees)
    }
}

// MARK: - 3. Catalog of CertiGo UI Components & Native SF Symbols Mapping (`CertiGoAnimatedSymbolCatalog`)

public enum CertiGoAnimatedSymbolComponentID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case bottomTabBar = "bottom_tab_bar"
    case lockedStepPadlock = "locked_step_padlock"
    case audioReaderSpeaker = "audio_reader_speaker"
    case aiCoachSparkles = "ai_coach_sparkles"
    case quizCorrectCheckmark = "quiz_correct_checkmark"
    case quizWrongCross = "quiz_wrong_cross"
    case topHeaderCounters = "top_header_counters"
    case techNewsRefresh = "tech_news_refresh"
    case certificationShieldBadge = "certification_shield_badge"

    public var id: String { rawValue }
}

public struct CertiGoAnimatedSymbolSpec: Equatable, Hashable, Codable, Sendable, Identifiable {
    public var id: String { component.rawValue }
    public let component: CertiGoAnimatedSymbolComponentID
    public let primaryPreset: CertiGoSymbolAnimationPreset
    public let secondaryPreset: CertiGoSymbolAnimationPreset?
    public let inactiveSymbol: String
    public let activeSymbol: String
    public let renderingModeName: String
    public let respectedByDefault: Bool
    public let isMotionActive: Bool

    public init(
        component: CertiGoAnimatedSymbolComponentID,
        primaryPreset: CertiGoSymbolAnimationPreset,
        secondaryPreset: CertiGoSymbolAnimationPreset? = nil,
        inactiveSymbol: String,
        activeSymbol: String,
        renderingModeName: String = "hierarchical",
        respectedByDefault: Bool = true,
        reduceMotion: Bool = false
    ) {
        self.component = component
        self.primaryPreset = primaryPreset
        self.secondaryPreset = secondaryPreset
        self.inactiveSymbol = inactiveSymbol
        self.activeSymbol = activeSymbol
        self.renderingModeName = renderingModeName
        self.respectedByDefault = respectedByDefault
        self.isMotionActive = primaryPreset.isMotionEnabled(reduceMotion: reduceMotion)
    }

    public var respectsReduceMotion: Bool {
        respectedByDefault
    }

    public func symbolName(isActive: Bool) -> String {
        isActive ? activeSymbol : inactiveSymbol
    }
}

public enum CertiGoAnimatedSymbolCatalog {
    /// Returns the complete SF Symbols animation specification for any CertiGo UI component.
    public static func spec(
        for component: CertiGoAnimatedSymbolComponentID,
        reduceMotion: Bool = false
    ) -> CertiGoAnimatedSymbolSpec {
        switch component {
        case .bottomTabBar:
            return CertiGoAnimatedSymbolSpec(
                component: .bottomTabBar,
                primaryPreset: .bounceUpByLayer,
                secondaryPreset: .magicReplace,
                inactiveSymbol: "map",
                activeSymbol: "map.fill",
                renderingModeName: "hierarchical",
                reduceMotion: reduceMotion
            )
        case .lockedStepPadlock:
            return CertiGoAnimatedSymbolSpec(
                component: .lockedStepPadlock,
                primaryPreset: .wiggleByLayer,
                secondaryPreset: nil,
                inactiveSymbol: "lock.fill",
                activeSymbol: "lock.fill",
                renderingModeName: "hierarchical",
                reduceMotion: reduceMotion
            )
        case .audioReaderSpeaker:
            return CertiGoAnimatedSymbolSpec(
                component: .audioReaderSpeaker,
                primaryPreset: .variableColorIterative,
                secondaryPreset: .magicReplace,
                inactiveSymbol: "speaker.wave.3.fill",
                activeSymbol: "pause.fill",
                renderingModeName: "hierarchical",
                reduceMotion: reduceMotion
            )
        case .aiCoachSparkles:
            return CertiGoAnimatedSymbolSpec(
                component: .aiCoachSparkles,
                primaryPreset: .breathePulseByLayer,
                secondaryPreset: nil,
                inactiveSymbol: "sparkles",
                activeSymbol: "sparkles",
                renderingModeName: "multicolor",
                reduceMotion: reduceMotion
            )
        case .quizCorrectCheckmark:
            return CertiGoAnimatedSymbolSpec(
                component: .quizCorrectCheckmark,
                primaryPreset: .bounceUpByLayer,
                secondaryPreset: .magicReplace,
                inactiveSymbol: "circle",
                activeSymbol: "checkmark.circle.fill",
                renderingModeName: "palette",
                reduceMotion: reduceMotion
            )
        case .quizWrongCross:
            return CertiGoAnimatedSymbolSpec(
                component: .quizWrongCross,
                primaryPreset: .wiggleByLayer,
                secondaryPreset: .magicReplace,
                inactiveSymbol: "circle",
                activeSymbol: "xmark.circle.fill",
                renderingModeName: "palette",
                reduceMotion: reduceMotion
            )
        case .topHeaderCounters:
            return CertiGoAnimatedSymbolSpec(
                component: .topHeaderCounters,
                primaryPreset: .bounceUpByLayer,
                secondaryPreset: .magicReplace,
                inactiveSymbol: "flame.fill",
                activeSymbol: "diamond.fill",
                renderingModeName: "multicolor",
                reduceMotion: reduceMotion
            )
        case .techNewsRefresh:
            return CertiGoAnimatedSymbolSpec(
                component: .techNewsRefresh,
                primaryPreset: .rotateByLayer,
                secondaryPreset: .magicReplace,
                inactiveSymbol: "arrow.clockwise",
                activeSymbol: "arrow.trianglehead.2.clockwise",
                renderingModeName: "hierarchical",
                reduceMotion: reduceMotion
            )
        case .certificationShieldBadge:
            return CertiGoAnimatedSymbolSpec(
                component: .certificationShieldBadge,
                primaryPreset: .scaleUpActive,
                secondaryPreset: .breathePulseByLayer,
                inactiveSymbol: "shield",
                activeSymbol: "shield.checkered",
                renderingModeName: "hierarchical",
                reduceMotion: reduceMotion
            )
        }
    }

    /// All 9 component specifications in the CertiGo SF Symbols catalog.
    public static func allSpecs(reduceMotion: Bool = false) -> [CertiGoAnimatedSymbolSpec] {
        CertiGoAnimatedSymbolComponentID.allCases.map { spec(for: $0, reduceMotion: reduceMotion) }
    }

    /// Outline (inactive) and filled (selected) SF Symbol pair for each of the 5 bottom tabs in CertiGo.
    public static func tabSymbols(for tab: CertiGoNativeTab) -> (inactiveSymbol: String, activeSymbol: String) {
        switch tab {
        case .parcours:
            return ("map", "map.fill")
        case .examens:
            return ("newspaper", "newspaper.fill")
        case .hubIA:
            return ("sparkles", "sparkles")
        case .social:
            return ("person.2", "person.2.fill")
        case .moi:
            return ("person.crop.circle", "person.crop.circle.fill")
        }
    }

    /// Resolves the appropriate outline or filled SF Symbol name for a tab.
    public static func symbolName(for tab: CertiGoNativeTab, isSelected: Bool) -> String {
        let pair = tabSymbols(for: tab)
        return isSelected ? pair.activeSymbol : pair.inactiveSymbol
    }
}

// MARK: - 4. WWDC 2026 Shared Intelligence Context & AppIntents Screen Entity Annotations (Zero Multimodal Photo)

/// Unified learning context shared across `Parcours`, `Examens Blancs`, and `Actus` so CertiGo AI connects theory with real-world tech news.
/// Note: Multimodal camera/photo analysis is intentionally disabled (`isMultimodalPhotoEnabled == false`) per product specification.
public struct CertiGoSharedIntelligenceContext: Codable, Equatable, Hashable, Sendable {
    public var activeRouteCode: String
    public var activeRouteTitle: String
    public var lastStudiedLessonId: String?
    public var lastStudiedLessonTitle: String?
    public var lastReviewedConceptTitle: String?
    public var lastMockExamScoreOutOf1000: Int?
    public var lastReadNewsArticleId: String?
    public var lastReadNewsHeadline: String?
    public var lastReadNewsSourceName: String?
    public var lastReadNewsLinkedCertificationCode: String?
    /// Multimodal photo/camera feature is explicitly excluded (`false`).
    public var isMultimodalPhotoEnabled: Bool { false }

    public init(
        activeRouteCode: String = "AZ-104",
        activeRouteTitle: String = "Microsoft Azure Administrator",
        lastStudiedLessonId: String? = nil,
        lastStudiedLessonTitle: String? = nil,
        lastReviewedConceptTitle: String? = nil,
        lastMockExamScoreOutOf1000: Int? = nil,
        lastReadNewsArticleId: String? = nil,
        lastReadNewsHeadline: String? = nil,
        lastReadNewsSourceName: String? = nil,
        lastReadNewsLinkedCertificationCode: String? = nil
    ) {
        self.activeRouteCode = activeRouteCode
        self.activeRouteTitle = activeRouteTitle
        self.lastStudiedLessonId = lastStudiedLessonId
        self.lastStudiedLessonTitle = lastStudiedLessonTitle
        self.lastReviewedConceptTitle = lastReviewedConceptTitle
        self.lastMockExamScoreOutOf1000 = lastMockExamScoreOutOf1000
        self.lastReadNewsArticleId = lastReadNewsArticleId
        self.lastReadNewsHeadline = lastReadNewsHeadline
        self.lastReadNewsSourceName = lastReadNewsSourceName
        self.lastReadNewsLinkedCertificationCode = lastReadNewsLinkedCertificationCode
    }

    public mutating func recordLessonStudy(
        routeCode: String,
        routeTitle: String,
        lessonId: String,
        lessonTitle: String,
        conceptTitle: String
    ) {
        self.activeRouteCode = routeCode
        self.activeRouteTitle = routeTitle
        self.lastStudiedLessonId = lessonId
        self.lastStudiedLessonTitle = lessonTitle
        self.lastReviewedConceptTitle = conceptTitle
    }

    public mutating func recordMockExamResult(routeCode: String, scoreOutOf1000: Int) {
        self.activeRouteCode = routeCode
        self.lastMockExamScoreOutOf1000 = min(max(scoreOutOf1000, 0), 1000)
    }

    public mutating func recordTechNewsInteraction(
        article: CertiGoTechNewsArticle,
        languageIndex: Int = 0
    ) {
        self.lastReadNewsArticleId = article.id
        self.lastReadNewsHeadline = article.localizedHeadline(languageIndex: languageIndex)
        self.lastReadNewsSourceName = article.editorialMediaName
        self.lastReadNewsLinkedCertificationCode = article.linkedCertificationCode
    }

    /// Synthesizes a cross-surface coaching summary linking `Parcours`, `Examens Blancs`, and `Actus` for CertiGo AI.
    public func buildCrossSurfaceCoachingSummary(languageIndex: Int = 0) -> String {
        let isEN = (languageIndex % 6) == 2
        var parts: [String] = []
        if isEN {
            parts.append("Active certification: \(activeRouteCode) (\(activeRouteTitle))")
            if let lesson = lastStudiedLessonTitle {
                parts.append("Latest step: \(lesson)")
            }
            if let concept = lastReviewedConceptTitle {
                parts.append("Key concept: \(concept)")
            }
            if let score = lastMockExamScoreOutOf1000 {
                parts.append("Mock exam score: \(score)/1000")
            }
            if let news = lastReadNewsHeadline, let source = lastReadNewsSourceName {
                parts.append("Recent tech news read: « \(news) » (\(source))")
            }
        } else {
            parts.append("Certification suivie : \(activeRouteCode) (\(activeRouteTitle))")
            if let lesson = lastStudiedLessonTitle {
                parts.append("Dernière étape étudiée : \(lesson)")
            }
            if let concept = lastReviewedConceptTitle {
                parts.append("Concept révisé : \(concept)")
            }
            if let score = lastMockExamScoreOutOf1000 {
                parts.append("Score examen blanc : \(score)/1000")
            }
            if let news = lastReadNewsHeadline, let source = lastReadNewsSourceName {
                parts.append("Dernière actu Tech consultée : « \(news) » (\(source))")
            }
        }
        return parts.joined(separator: " · ")
    }
}

/// On-screen entity annotation for `AppIntents` / `NSUserActivity` surface donation (WWDC 2026 System Intelligence).
public struct CertiGoScreenEntityAnnotation: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum EntityKind: String, Codable, Hashable, Sendable {
        case certificationCourse = "certification_course"
        case techNewsArticle = "tech_news_article"
    }

    public let id: String
    public let kind: EntityKind
    public let title: String
    public let subtitle: String
    public let routeCode: String
    public let canonicalURLString: String
    public let activityType: String

    public init(
        id: String,
        kind: EntityKind,
        title: String,
        subtitle: String,
        routeCode: String,
        canonicalURLString: String,
        activityType: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.routeCode = routeCode
        self.canonicalURLString = canonicalURLString
        self.activityType = activityType
    }

    public var userInfoPayload: [String: String] {
        [
            "entityId": id,
            "entityKind": kind.rawValue,
            "title": title,
            "subtitle": subtitle,
            "routeCode": routeCode,
            "url": canonicalURLString
        ]
    }

    public static func forCourse(
        routeCode: String,
        title: String,
        unitBannerTitle: String
    ) -> CertiGoScreenEntityAnnotation {
        let code = routeCode.uppercased()
        return CertiGoScreenEntityAnnotation(
            id: "course-\(code)",
            kind: .certificationCourse,
            title: "\(code) · \(title)",
            subtitle: unitBannerTitle,
            routeCode: code,
            canonicalURLString: "https://www.certigo-app.com/courses/\(code.lowercased())",
            activityType: "com.certigo.app.entity.course"
        )
    }

    public static func forTechNewsArticle(
        _ article: CertiGoTechNewsArticle,
        languageIndex: Int = 0
    ) -> CertiGoScreenEntityAnnotation {
        CertiGoScreenEntityAnnotation(
            id: "article-\(article.id)",
            kind: .techNewsArticle,
            title: article.localizedHeadline(languageIndex: languageIndex),
            subtitle: "\(article.editorialMediaName) · \(article.linkedCertificationCode)",
            routeCode: article.linkedCertificationCode,
            canonicalURLString: article.articleURL,
            activityType: "com.certigo.app.entity.technews"
        )
    }
}

/// Thread-safe registry and system donor for on-screen CertiGo entities (`AppIntents` / `NSUserActivity`).
public final class CertiGoInteractionDonationCenter: @unchecked Sendable {
    public static let shared = CertiGoInteractionDonationCenter()

    private let lock = NSLock()
    private var _donatedAnnotations: [CertiGoScreenEntityAnnotation] = []

    public init() {}

    public var donatedAnnotations: [CertiGoScreenEntityAnnotation] {
        lock.lock()
        defer { lock.unlock() }
        return _donatedAnnotations
    }

    public var lastDonatedAnnotation: CertiGoScreenEntityAnnotation? {
        lock.lock()
        defer { lock.unlock() }
        return _donatedAnnotations.last
    }

    public func resetDonations() {
        lock.lock()
        _donatedAnnotations.removeAll()
        lock.unlock()
    }

    public func donate(_ annotation: CertiGoScreenEntityAnnotation) {
        lock.lock()
        _donatedAnnotations.append(annotation)
        lock.unlock()

        #if canImport(Foundation) && !os(Linux)
        let activity = NSUserActivity(activityType: annotation.activityType)
        activity.title = annotation.title
        activity.userInfo = annotation.userInfoPayload
        if let url = URL(string: annotation.canonicalURLString) {
            activity.webpageURL = url
        }
        activity.isEligibleForSearch = true
        #if os(iOS)
        activity.isEligibleForPrediction = true
        #endif
        activity.becomeCurrent()
        #endif
    }
}

/// Convenience function to donate a CertiGo course or Tech News interaction to system intelligence.
public func donateCertiGoInteraction(_ annotation: CertiGoScreenEntityAnnotation) {
    CertiGoInteractionDonationCenter.shared.donate(annotation)
}

// MARK: - 5. Native SwiftUI Modifiers (`#if canImport(SwiftUI)`) with `Symbols` Framework

#if canImport(SwiftUI)

/// 1. `.certiGoSymbolBounce(trigger:)` : Applies `.symbolEffect(.bounce.up.byLayer, value: trigger)` + `.contentTransition(.symbolEffect(.replace))` while respecting `accessibilityReduceMotion`.
public struct CertiGoSymbolBounceModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let trigger: Trigger

    public init(trigger: Trigger) {
        self.trigger = trigger
    }

    public func body(content: Content) -> some View {
        if reduceMotion {
            content
                .contentTransition(.symbolEffect(.replace))
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce.up.byLayer, value: trigger)
        }
    }
}

/// 2. `.certiGoSymbolVariableColor(isActive:)` : Applies `.symbolEffect(.variableColor.iterative.reversing, isActive: isActive)` + `.contentTransition(.symbolEffect(.replace))` (ideal for `speaker.wave.3.fill` in `Actus`).
public struct CertiGoSymbolVariableColorModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let isActive: Bool

    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public func body(content: Content) -> some View {
        content
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.variableColor.iterative.reversing, isActive: !reduceMotion && isActive)
    }
}

/// 3. `.certiGoSymbolBreathe(isActive:)` : Applies `.symbolEffect(.breathe.pulse.byLayer, isActive: isActive)` on iOS 18+ / macOS 15+ with `.pulse.byLayer` fallback (ideal for `sparkles` in `✦ IA` and `Actus`).
public struct CertiGoSymbolBreatheModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let isActive: Bool

    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public func body(content: Content) -> some View {
        let effectiveActive = !reduceMotion && isActive
        if #available(iOS 18.0, macOS 15.0, *) {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.breathe.pulse.byLayer, isActive: effectiveActive)
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse.byLayer, isActive: effectiveActive)
        }
    }
}

/// 4. `.certiGoSymbolWiggle(trigger:)` : Applies `.symbolEffect(.wiggle.byLayer, value: trigger)` on iOS 18+ / macOS 15+ with `.bounce.down.byLayer` fallback (ideal for locked `lock.fill` or wrong answer `xmark.circle.fill`).
public struct CertiGoSymbolWiggleModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let trigger: Trigger

    public init(trigger: Trigger) {
        self.trigger = trigger
    }

    public func body(content: Content) -> some View {
        if reduceMotion {
            content
                .contentTransition(.symbolEffect(.replace))
        } else if #available(iOS 18.0, macOS 15.0, *) {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.wiggle.byLayer, value: trigger)
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce.down.byLayer, value: trigger)
        }
    }
}

/// 5A. `.certiGoSymbolRotate(trigger:)` : Applies `.symbolEffect(.rotate.byLayer, value: trigger)` on iOS 18+ / macOS 15+ with `.bounce` fallback (ideal for the `Actus` refresh button).
public struct CertiGoSymbolRotateTriggerModifier<Trigger: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let trigger: Trigger

    public init(trigger: Trigger) {
        self.trigger = trigger
    }

    public func body(content: Content) -> some View {
        if reduceMotion {
            content
                .contentTransition(.symbolEffect(.replace))
        } else if #available(iOS 18.0, macOS 15.0, *) {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.rotate.byLayer, value: trigger)
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: trigger)
        }
    }
}

/// 5B. `.certiGoSymbolRotate(isActive:)` : Continuous rotation variant while an async operation is active.
public struct CertiGoSymbolRotateActiveModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let isActive: Bool

    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public func body(content: Content) -> some View {
        let effectiveActive = !reduceMotion && isActive
        if #available(iOS 18.0, macOS 15.0, *) {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.rotate.byLayer, isActive: effectiveActive)
        } else {
            content
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse.byLayer, isActive: effectiveActive)
        }
    }
}

/// 6. `.certiGoHolographicBadgeEffect()` : Interactive WWDC 2026 3D Holographic tilt + diagonal iridescent specular reflection + animated `sparkles` on unlock.
public struct CertiGoHolographicBadgeModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTranslation: CGSize = .zero

    public let isUnlocked: Bool
    public let showSparklesBadge: Bool

    public init(isUnlocked: Bool = true, showSparklesBadge: Bool = false) {
        self.isUnlocked = isUnlocked
        self.showSparklesBadge = showSparklesBadge
    }

    public var currentTiltState: CertiGoHolographicTiltState {
        CertiGoHolographicTiltState.compute(
            dragTranslation: (dx: Double(dragTranslation.width), dy: Double(dragTranslation.height)),
            isUnlocked: isUnlocked,
            reduceMotion: reduceMotion
        )
    }

    public func body(content: Content) -> some View {
        let state = currentTiltState
        let shimmerStart = UnitPoint(
            x: 0.15 + state.shimmerOffset.x * 0.35,
            y: 0.10 + state.shimmerOffset.y * 0.35
        )
        let shimmerEnd = UnitPoint(
            x: 0.85 + state.shimmerOffset.x * 0.35,
            y: 0.90 + state.shimmerOffset.y * 0.35
        )

        content
            .overlay {
                if !reduceMotion && (state.isInteracting || isUnlocked) {
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.0), location: 0.0),
                            .init(
                                color: Color.white.opacity(state.isInteracting ? 0.36 : 0.12),
                                location: 0.42
                            ),
                            .init(
                                color: PrismColor.figmaHex("#06b6d4").opacity(state.isInteracting ? 0.24 : 0.06),
                                location: 0.54
                            ),
                            .init(
                                color: PrismColor.figmaHex("#8b5cf6").opacity(state.isInteracting ? 0.20 : 0.04),
                                location: 0.66
                            ),
                            .init(color: Color.white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: shimmerStart,
                        endPoint: shimmerEnd
                    )
                    .blendMode(.plusLighter)
                    .clipShape(RoundedRectangle(cornerRadius: FigMetrics.fourteen, style: .continuous))
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isUnlocked && (showSparklesBadge || state.isInteracting) {
                    Image(systemName: "sparkles")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(PrismColor.figmaHex("#eab308"))
                        .opacity(state.sparkleIntensity)
                        .certiGoSymbolBreathe(isActive: state.isInteracting || showSparklesBadge)
                        .offset(x: FigMetrics.four, y: -FigMetrics.four)
                        .allowsHitTesting(false)
                }
            }
            .rotation3DEffect(
                .degrees(state.pitchDegrees),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.45
            )
            .rotation3DEffect(
                .degrees(state.yawDegrees),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.45
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: FigMetrics.four)
                    .onChanged { value in
                        guard !reduceMotion else { return }
                        dragTranslation = value.translation
                    }
                    .onEnded { _ in
                        let springMotion = PrismMotion.resolve(.snappy, reduceMotion: reduceMotion)
                        withAnimation(springMotion.animation) {
                            dragTranslation = .zero
                        }
                    }
            )
    }
}

extension View {
    /// Applies `.symbolEffect(.bounce.up.byLayer, value: trigger)` and `.contentTransition(.symbolEffect(.replace))` while respecting `accessibilityReduceMotion`.
    public func certiGoSymbolBounce<Trigger: Equatable>(trigger: Trigger) -> some View {
        modifier(CertiGoSymbolBounceModifier(trigger: trigger))
    }

    /// Applies `.symbolEffect(.variableColor.iterative.reversing, isActive: isActive)` and `.contentTransition(.symbolEffect(.replace))`.
    public func certiGoSymbolVariableColor(isActive: Bool) -> some View {
        modifier(CertiGoSymbolVariableColorModifier(isActive: isActive))
    }

    /// Applies `.symbolEffect(.breathe.pulse.byLayer, isActive: isActive)` on iOS 18+ / macOS 15+ with `.pulse.byLayer` fallback.
    public func certiGoSymbolBreathe(isActive: Bool) -> some View {
        modifier(CertiGoSymbolBreatheModifier(isActive: isActive))
    }

    /// Applies `.symbolEffect(.wiggle.byLayer, value: trigger)` on iOS 18+ / macOS 15+ with `.bounce.down.byLayer` fallback.
    public func certiGoSymbolWiggle<Trigger: Equatable>(trigger: Trigger) -> some View {
        modifier(CertiGoSymbolWiggleModifier(trigger: trigger))
    }

    /// Applies `.symbolEffect(.rotate.byLayer, value: trigger)` on iOS 18+ / macOS 15+ with `.bounce` fallback.
    public func certiGoSymbolRotate<Trigger: Equatable>(trigger: Trigger) -> some View {
        modifier(CertiGoSymbolRotateTriggerModifier(trigger: trigger))
    }

    /// Applies `.symbolEffect(.rotate.byLayer, isActive: isActive)` on iOS 18+ / macOS 15+ with `.pulse.byLayer` fallback.
    public func certiGoSymbolRotate(isActive: Bool) -> some View {
        modifier(CertiGoSymbolRotateActiveModifier(isActive: isActive))
    }

    /// Interactive WWDC 2026 3D Holographic badge effect with specular shimmer, `.spring(response: 0.35, dampingFraction: 0.72)` return, and unlock `sparkles`.
    public func certiGoHolographicBadgeEffect(
        isUnlocked: Bool = true,
        showSparklesBadge: Bool = false
    ) -> some View {
        modifier(
            CertiGoHolographicBadgeModifier(
                isUnlocked: isUnlocked,
                showSparklesBadge: showSparklesBadge
            )
        )
    }

    /// Annotates the view with a `CertiGoScreenEntityAnnotation` and donates it to system intelligence on appear.
    public func certiGoScreenEntityAnnotation(_ annotation: CertiGoScreenEntityAnnotation) -> some View {
        onAppear {
            donateCertiGoInteraction(annotation)
        }
    }
}

#endif
