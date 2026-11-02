import Foundation

// MARK: - 1. Contextual Mascot Outfits (`CertiGoMascotOutfit`)

/// The 8 official contextual outfits and emotional states of the CertiGo mascot,
/// synchronized between in-app vector rendering and the iOS Home Screen dynamic app icon.
public enum CertiGoMascotOutfit: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case happyActive = "happy_active"
    case sadMissing = "sad_missing"
    case morningPajama = "morning_pajama"
    case coffeeBoost = "coffee_boost"
    case suitBoss = "suit_boss"
    case airplaneOffline = "airplane_offline"
    case streakFire = "streak_fire"
    case prestigePro = "prestige_pro"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .happyActive:
            return "Heureux & Actif"
        case .sadMissing:
            return "Triste · Tu nous manques"
        case .morningPajama:
            return "Réveil Pyjama & Café"
        case .coffeeBoost:
            return "Pause Café Focus"
        case .suitBoss:
            return "Costume Cravate · Examen"
        case .airplaneOffline:
            return "Aviateur · Mode Avion"
        case .streakFire:
            return "Série Enflammée"
        case .prestigePro:
            return "Prestige Or & Noir PRO"
        }
    }

    public var badgeLabel: String {
        switch self {
        case .happyActive:
            return "DÉFAUT #07.1 / #07.2"
        case .sadMissing:
            return "INACTIF > 48H"
        case .morningPajama:
            return "MATIN 06H–09H30"
        case .coffeeBoost:
            return "FOCUS 09H30–14H"
        case .suitBoss:
            return "MODE EXAMEN"
        case .airplaneOffline:
            return "HORS-LIGNE · AVION"
        case .streakFire:
            return "SÉRIE ≥ 3 JOURS"
        case .prestigePro:
            return "CERTIGO PRO #07.10"
        }
    }

    public var subtitle: String {
        switch self {
        case .happyActive:
            return "Ailes levées victorieuses quand tu es actif et à jour dans tes révisions CertiGo."
        case .sadMissing:
            return "Ailes baissées, sourcils tristes et larme cristalline après 36h à 48h sans session."
        case .morningPajama:
            return "Pyjama rayé, bonnet de nuit et tasse de café fumante au réveil avant la 1re séance."
        case .coffeeBoost:
            return "Gobelet de café fumant à l'aile pour le sprint focus de la matinée (9h30–14h)."
        case .suitBoss:
            return "Costume-cravate d'architecte Cloud pendant la préparation d'un Examen Blanc."
        case .airplaneOffline:
            return "Casque, lunettes d'aviateur et écharpe au vent dès que l'iPhone passe en Mode Avion."
        case .streakFire:
            return "Couronne de flammes dorées quand ta série active atteint 3 jours ou plus."
        case .prestigePro:
            return "Armure Or & Noir #07.10 réservée aux membres CertiGo PRO."
        }
    }

    /// Alternate icon name registered in `CertigoAssets.xcassets` and `Info.plist`.
    /// Each `.appiconset` bundles both Light (`Any`, `#07.1`) and Dark (`Dark`, `#07.2` / `#07.10`) 1024×1024 PNGs.
    public var alternateIconName: String {
        switch self {
        case .happyActive:
            return "CertiGoMascotHappyActive"
        case .sadMissing:
            return "CertiGoMascotSadMissing"
        case .morningPajama:
            return "CertiGoMascotMorningPajama"
        case .coffeeBoost:
            return "CertiGoMascotCoffeeBoost"
        case .suitBoss:
            return "CertiGoMascotSuitBoss"
        case .airplaneOffline:
            return "CertiGoMascotAirplaneOffline"
        case .streakFire:
            return "CertiGoMascotStreakFire"
        case .prestigePro:
            return "CertiGoMascotPrestigePro"
        }
    }

    /// Explicit alternate icon name when the user forces Light or Dark appearance on the Home Screen,
    /// or `nil` when resetting to the primary default icon.
    public func resolvedAlternateIconName(
        for theme: CertiGoMascotThemeVariant,
        usePrimaryDefaultForHappyLight: Bool = false
    ) -> String? {
        if self == .happyActive && theme == .light && usePrimaryDefaultForHappyLight {
            return nil
        }
        return alternateIconName
    }
}

// MARK: - 2. Light / Dark / Prestige Theme Variants (`#07.1`, `#07.2`, `#07.10`)

public enum CertiGoMascotThemeVariant: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    /// `#07.1` Blanc Pur & Halo Azur
    case light = "light_07_1"
    /// `#07.2` Azur Profond & Anneau Verre
    case dark = "dark_07_2"
    /// `#07.10` Prestige Or & Noir
    case prestigeGoldBlack = "prestige_07_10"

    public var id: String { rawValue }

    public var codeLabel: String {
        switch self {
        case .light: return "#07.1"
        case .dark: return "#07.2"
        case .prestigeGoldBlack: return "#07.10"
        }
    }

    public var displayName: String {
        switch self {
        case .light: return "Clair (#07.1 Blanc Pur & Halo Azur)"
        case .dark: return "Sombre (#07.2 Azur Profond & Verre)"
        case .prestigeGoldBlack: return "Prestige (#07.10 Or & Noir)"
        }
    }

    public var shortTitle: String {
        switch self {
        case .light: return "Clair #07.1"
        case .dark: return "Sombre #07.2"
        case .prestigeGoldBlack: return "Or & Noir #07.10"
        }
    }

    public var backgroundPrimaryHex: String {
        switch self {
        case .light: return "#ffffff"
        case .dark: return "#071426"
        case .prestigeGoldBlack: return "#09090b"
        }
    }

    public var backgroundSecondaryHex: String {
        switch self {
        case .light: return "#e0f2fe"
        case .dark: return "#0c2d57"
        case .prestigeGoldBlack: return "#1c1917"
        }
    }

    public var haloRingHex: String {
        switch self {
        case .light: return "#38bdf8"
        case .dark: return "#60a5fa"
        case .prestigeGoldBlack: return "#f59e0b"
        }
    }
}

// MARK: - 3. Vector Anatomy & Proportion Verification Spec (`CertiGoMascotVectorGeometrySpec`)

public enum CertiGoMascotEyebrowArcKind: String, Codable, Equatable, Sendable {
    case joyfulArch
    case sadSloped
    case sleepyRelaxed
    case focusedSip
    case confidentExecutive
    case aviatorAlert
    case blazingDetermined
    case royalPrestige
}

public enum CertiGoMascotChestPlastronKind: String, Codable, Equatable, Sendable {
    case azureCoreEmblem
    case mutedDropletEmblem
    case stripedPajamaTop
    case baristaApronBadge
    case cloudArchitectSuitTie
    case aviatorWindScarf
    case solarFlameCrest
    case goldBlackRoyalArmor
}

public enum CertiGoMascotWingPoseKind: String, Codable, Equatable, Sendable {
    case raisedVictory
    case droopedSad
    case holdingWarmMug
    case holdingToGoCoffeeCup
    case structuredExecutive
    case aviatorSalute
    case raisedFlameAura
    case armoredShieldPose
}

/// Normalized (`0.0 ... 1.0`) anatomical geometry specification for the refactored CertiGo mascot.
/// Guarantees Gabriel's visual quality invariants:
/// 1. Expressive arched eyebrows cleanly above the eyes (`eyebrowBottomY < eyeTopY` with positive clearance).
/// 2. Centered chest emblem / outfit strictly inside the shield contour (`chestPlastronMaxRadiusRatio <= 0.72 < shieldInnerContourRatio 0.88`, zero V-bar touching border).
/// 3. 100% symmetric orange feet (`leftFootCenterX + rightFootCenterX == 1.0`, equal Y and width).
/// 4. Crisp eyes with a single specular highlight (`hasOverlappingStarAndHighlight == false`) and a well-proportioned golden beak.
public struct CertiGoMascotVectorGeometrySpec: Equatable, Sendable {
    public let outfit: CertiGoMascotOutfit
    public let eyebrowArc: CertiGoMascotEyebrowArcKind
    public let chestPlastron: CertiGoMascotChestPlastronKind
    public let wingPose: CertiGoMascotWingPoseKind

    /// Normalized Y of the bottom edge of the sculpted eyebrow arc.
    public let eyebrowBottomY: Double
    /// Normalized Y of the top edge of the eye sclera/iris.
    public let eyeTopY: Double
    /// Positive vertical gap between the eyebrow arc and the top of the eye (`eyeTopY - eyebrowBottomY`).
    public var eyebrowClearanceAboveEye: Double { eyeTopY - eyebrowBottomY }

    /// Normalized radius of the inner shield border.
    public let shieldInnerContourRatio: Double
    /// Maximum normalized extent of the chest emblem / outfit from the shield center.
    public let chestPlastronMaxRadiusRatio: Double
    /// Guaranteed margin between the chest outfit/plastron and the shield border.
    public var chestPlastronMarginToShieldBorder: Double {
        shieldInnerContourRatio - chestPlastronMaxRadiusRatio
    }
    /// Confirms the legacy V-bar touching the shield border has been completely eliminated.
    public let hasLegacyVBarTouchingShieldBorder: Bool

    /// Normalized center coordinates and dimensions of the left and right orange feet.
    public let leftFootCenterX: Double
    public let rightFootCenterX: Double
    public let feetCenterY: Double
    public let footWidthRatio: Double
    public let footHeightRatio: Double

    /// Confirms 100% horizontal and vertical symmetry of the two orange feet.
    public var areFeetSymmetric: Bool {
        abs((leftFootCenterX + rightFootCenterX) - 1.0) < 0.0001
            && leftFootCenterX < 0.5
            && rightFootCenterX > 0.5
            && footWidthRatio > 0.08
            && footHeightRatio > 0.04
    }

    /// Confirms eyes have a single crisp specular highlight without star/highlight overlap.
    public let hasOverlappingStarAndHighlight: Bool
    public let specularHighlightCountPerEye: Int

    /// Normalized golden beak proportions.
    public let beakCenterX: Double
    public let beakCenterY: Double
    public let beakWidthRatio: Double
    public let beakHeightRatio: Double

    public static func spec(for outfit: CertiGoMascotOutfit) -> CertiGoMascotVectorGeometrySpec {
        let eyebrowArc: CertiGoMascotEyebrowArcKind
        let chestPlastron: CertiGoMascotChestPlastronKind
        let wingPose: CertiGoMascotWingPoseKind
        let eyebrowBottomY: Double

        switch outfit {
        case .happyActive:
            eyebrowArc = .joyfulArch
            chestPlastron = .azureCoreEmblem
            wingPose = .raisedVictory
            eyebrowBottomY = 0.295
        case .sadMissing:
            eyebrowArc = .sadSloped
            chestPlastron = .mutedDropletEmblem
            wingPose = .droopedSad
            eyebrowBottomY = 0.305
        case .morningPajama:
            eyebrowArc = .sleepyRelaxed
            chestPlastron = .stripedPajamaTop
            wingPose = .holdingWarmMug
            eyebrowBottomY = 0.302
        case .coffeeBoost:
            eyebrowArc = .focusedSip
            chestPlastron = .baristaApronBadge
            wingPose = .holdingToGoCoffeeCup
            eyebrowBottomY = 0.298
        case .suitBoss:
            eyebrowArc = .confidentExecutive
            chestPlastron = .cloudArchitectSuitTie
            wingPose = .structuredExecutive
            eyebrowBottomY = 0.296
        case .airplaneOffline:
            eyebrowArc = .aviatorAlert
            chestPlastron = .aviatorWindScarf
            wingPose = .aviatorSalute
            eyebrowBottomY = 0.294
        case .streakFire:
            eyebrowArc = .blazingDetermined
            chestPlastron = .solarFlameCrest
            wingPose = .raisedFlameAura
            eyebrowBottomY = 0.292
        case .prestigePro:
            eyebrowArc = .royalPrestige
            chestPlastron = .goldBlackRoyalArmor
            wingPose = .armoredShieldPose
            eyebrowBottomY = 0.294
        }

        return CertiGoMascotVectorGeometrySpec(
            outfit: outfit,
            eyebrowArc: eyebrowArc,
            chestPlastron: chestPlastron,
            wingPose: wingPose,
            eyebrowBottomY: eyebrowBottomY,
            eyeTopY: 0.365,
            shieldInnerContourRatio: 0.88,
            chestPlastronMaxRadiusRatio: 0.64,
            hasLegacyVBarTouchingShieldBorder: false,
            leftFootCenterX: 0.39,
            rightFootCenterX: 0.61,
            feetCenterY: 0.865,
            footWidthRatio: 0.12,
            footHeightRatio: 0.058,
            hasOverlappingStarAndHighlight: false,
            specularHighlightCountPerEye: 1,
            beakCenterX: 0.50,
            beakCenterY: 0.495,
            beakWidthRatio: 0.145,
            beakHeightRatio: 0.095
        )
    }
}

// MARK: - 4. Contextual Participation & Device Signal Evaluator

public struct CertiGoMascotContextInput: Equatable, Sendable {
    public var isOfflineOrAirplaneMode: Bool
    public var lastActiveDate: Date?
    public var now: Date
    public var hasCompletedFirstSessionToday: Bool
    public var isQuickSprintMode: Bool
    public var isExamPrepMode: Bool
    public var streakDays: Int
    public var isProMember: Bool
    public var preferPrestigeWhenPro: Bool
    public var isDarkSystemAppearance: Bool

    public init(
        isOfflineOrAirplaneMode: Bool = false,
        lastActiveDate: Date? = nil,
        now: Date = Date(),
        hasCompletedFirstSessionToday: Bool = false,
        isQuickSprintMode: Bool = false,
        isExamPrepMode: Bool = false,
        streakDays: Int = 0,
        isProMember: Bool = false,
        preferPrestigeWhenPro: Bool = false,
        isDarkSystemAppearance: Bool = false
    ) {
        self.isOfflineOrAirplaneMode = isOfflineOrAirplaneMode
        self.lastActiveDate = lastActiveDate
        self.now = now
        self.hasCompletedFirstSessionToday = hasCompletedFirstSessionToday
        self.isQuickSprintMode = isQuickSprintMode
        self.isExamPrepMode = isExamPrepMode
        self.streakDays = streakDays
        self.isProMember = isProMember
        self.preferPrestigeWhenPro = preferPrestigeWhenPro
        self.isDarkSystemAppearance = isDarkSystemAppearance
    }

    public var hoursSinceLastActivity: Double? {
        guard let lastActiveDate else { return nil }
        return max(0, now.timeIntervalSince(lastActiveDate) / 3600.0)
    }
}

public struct CertiGoMascotDynamicPreferences: Codable, Equatable, Sendable {
    public var selectionMode: CertigoAppIconSelectionMode
    public var manualOutfit: CertiGoMascotOutfit
    public var preferredTheme: CertiGoMascotThemeVariant?
    public var preferPrestigeWhenPro: Bool

    public init(
        selectionMode: CertigoAppIconSelectionMode = .automatic,
        manualOutfit: CertiGoMascotOutfit = .happyActive,
        preferredTheme: CertiGoMascotThemeVariant? = nil,
        preferPrestigeWhenPro: Bool = false
    ) {
        self.selectionMode = selectionMode
        self.manualOutfit = manualOutfit
        self.preferredTheme = preferredTheme
        self.preferPrestigeWhenPro = preferPrestigeWhenPro
    }
}

public enum CertiGoMascotContextEvaluator {
    /// Threshold in hours after which the mascot switches to `.sadMissing` ("Tu nous manques").
    public static let inactivitySadThresholdHours: Double = 36.0

    /// Evaluates the optimal mascot outfit and dynamic app icon based on real device & learner signals.
    public static func recommendedOutfit(
        for context: CertiGoMascotContextInput,
        preferences: CertiGoMascotDynamicPreferences = CertiGoMascotDynamicPreferences(),
        calendar: Calendar = .current
    ) -> CertiGoMascotOutfit {
        if preferences.selectionMode == .manual {
            return preferences.manualOutfit
        }

        // 1. Airplane Mode / Offline via NWPathMonitor takes immediate contextual priority
        if context.isOfflineOrAirplaneMode {
            return .airplaneOffline
        }

        // 2. Prolonged inactivity (> 36h / 48h without studying) -> Sad / Missing you
        if let inactiveHours = context.hoursSinceLastActivity,
           inactiveHours >= inactivitySadThresholdHours
        {
            return .sadMissing
        }

        // 3. Mock Exam cockpit or Exam-style preparation -> Cloud Architect Suit & Tie
        if context.isExamPrepMode {
            return .suitBoss
        }

        // Extract local time-of-day in minutes from midnight
        let components = calendar.dateComponents([.hour, .minute], from: context.now)
        let hour = components.hour ?? 12
        let minute = components.minute ?? 0
        let minutesFromMidnight = hour * 60 + minute

        // 4. Morning Wake-Up (06:00 ..< 09:30) before the first session of the day -> Pajama + Nightcap + Coffee
        if minutesFromMidnight >= (6 * 60) && minutesFromMidnight < (9 * 60 + 30)
            && !context.hasCompletedFirstSessionToday
        {
            return .morningPajama
        }

        // 5. Coffee Focus Window (09:30 ..< 14:00 before first session, or Quick Sprint mode) -> Coffee Boost
        if context.isQuickSprintMode
            || (minutesFromMidnight >= (9 * 60 + 30) && minutesFromMidnight < (14 * 60)
                && !context.hasCompletedFirstSessionToday)
        {
            return .coffeeBoost
        }

        // 6. CertiGo PRO Prestige armor when explicitly preferred by a PRO member
        if context.isProMember && (context.preferPrestigeWhenPro || preferences.preferPrestigeWhenPro) {
            return .prestigePro
        }

        // 7. Active Streak >= 3 days -> Streak Fire crown
        if context.streakDays >= 3 {
            return .streakFire
        }

        // 8. CertiGo PRO member default when streak < 3 -> Prestige Gold & Black (#07.10)
        if context.isProMember {
            return .prestigePro
        }

        // 9. Default Active & Happy (#07.1 Light / #07.2 Dark)
        return .happyActive
    }

    /// Resolves the active Light (`#07.1`), Dark (`#07.2`), or Prestige (`#07.10`) theme variant.
    public static func resolvedTheme(
        for outfit: CertiGoMascotOutfit,
        context: CertiGoMascotContextInput,
        preferences: CertiGoMascotDynamicPreferences = CertiGoMascotDynamicPreferences()
    ) -> CertiGoMascotThemeVariant {
        if let explicitTheme = preferences.preferredTheme {
            return explicitTheme
        }
        if outfit == .prestigePro {
            return .prestigeGoldBlack
        }
        return context.isDarkSystemAppearance ? .dark : .light
    }
}
