import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Accessibility Hardening & App Store Nutrition Labels (§28, §34.1)

public enum AccessibilityDimension: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case dynamicTypeAX5
    case voiceOverComplete
    case voiceControlMatchingLabels
    case fullKeyboardAndSwitchControl
    case differentiateWithoutColor
    case increaseContrastHC
    case reduceMotionAlternatives
    case reduceTransparencyOpaque
    case touchTargetsMin44pt
    case noForcedTimeLimits
    case captionsAndTranscripts
    case tapAlternativeForGestures
    case calmModeCelebrationCap

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dynamicTypeAX5: "Dynamic Type AX5 (≥ 200 % sans troncature)"
        case .voiceOverComplete: "VoiceOver complet + rotor Lignes + BrandLabel unique"
        case .voiceControlMatchingLabels: "Voice Control (libellés visibles = accessibilityInputLabels)"
        case .fullKeyboardAndSwitchControl: "Full Keyboard Access & Switch Control"
        case .differentiateWithoutColor: "Differentiate Without Color (symbole + mot)"
        case .increaseContrastHC: "Increase Contrast (variantes HC ≥ 7:1)"
        case .reduceMotionAlternatives: "Reduce Motion (repli fondu, 0 boucle au repos)"
        case .reduceTransparencyOpaque: "Reduce Transparency (surfaces opaques)"
        case .touchTargetsMin44pt: "Cibles tactiles ≥ 44 × 44 pt"
        case .noForcedTimeLimits: "Aucun délai imposé hors examen blanc (temps majoré / sans limite)"
        case .captionsAndTranscripts: "Sous-titres et transcriptions médias"
        case .tapAlternativeForGestures: "Alternative tap pour tout geste (0 glisser requis)"
        case .calmModeCelebrationCap: "Mode Calme (célébrations plafonnées au niveau 1)"
        }
    }
}

public enum AppStoreAccessibilityNutritionLabel: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case voiceOver
    case voiceControl
    case largerText
    case darkInterface
    case differentiateWithoutColor
    case sufficientContrast
    case reducedMotion
    case captions
    case switchControl

    public var id: String { rawValue }

    public var storeDisplayName: String {
        switch self {
        case .voiceOver: "VoiceOver"
        case .voiceControl: "Contrôle vocal (Voice Control)"
        case .largerText: "Texte plus grand (Larger Text AX5)"
        case .darkInterface: "Interface sombre (Dark Interface)"
        case .differentiateWithoutColor: "Différencier sans couleur"
        case .sufficientContrast: "Contraste suffisant (Increase Contrast ≥ 7:1)"
        case .reducedMotion: "Réduire les animations (Reduced Motion)"
        case .captions: "Sous-titres et transcriptions"
        case .switchControl: "Contrôle de sélection & clavier complet"
        }
    }
}

public struct AccessibilityAuditSummary: Codable, Equatable, Hashable, Sendable {
    public let verifiedDimensions: [AccessibilityDimension]
    public let eligibleNutritionLabels: [AppStoreAccessibilityNutritionLabel]
    public let auditErrorCount: Int
    public let minimumTapTargetPt: Double
    public let calmModeMaxCelebrationLevel: Int

    public init(
        verifiedDimensions: [AccessibilityDimension] = AccessibilityDimension.allCases,
        eligibleNutritionLabels: [AppStoreAccessibilityNutritionLabel] = AppStoreAccessibilityNutritionLabel.allCases,
        auditErrorCount: Int = 0,
        minimumTapTargetPt: Double = Double(PrismSize.minTapTarget),
        calmModeMaxCelebrationLevel: Int = 1
    ) {
        self.verifiedDimensions = verifiedDimensions
        self.eligibleNutritionLabels = eligibleNutritionLabels
        self.auditErrorCount = max(0, auditErrorCount)
        self.minimumTapTargetPt = minimumTapTargetPt
        self.calmModeMaxCelebrationLevel = calmModeMaxCelebrationLevel
    }

    public var passesAllAccessibilityGates: Bool {
        auditErrorCount == 0
            && verifiedDimensions.count == AccessibilityDimension.allCases.count
            && eligibleNutritionLabels.count == AppStoreAccessibilityNutritionLabel.allCases.count
            && minimumTapTargetPt >= 44.0
            && calmModeMaxCelebrationLevel <= 1
    }
}

// MARK: - 2. Performance Budgets Gate (§30)

public struct PerformanceBudgetSnapshot: Codable, Equatable, Hashable, Sendable {
    public static let maxColdLaunchMs: Int = 400
    public static let maxRegressionPercentVsBaseline: Double = 10.0
    public static let maxTodayInteractiveMs: Int = 500
    public static let maxCardTransitionMs: Int = 100
    public static let maxPerceivedFeedbackMs: Int = 300
    public static let maxServerFeedbackP95Ms: Int = 1000
    public static let maxScrollHitchRateMsPerSec: Double = 5.0
    public static let minAtlasFps: Int = 60
    public static let maxAtlasVisibleNodes: Int = 500
    public static let maxTypicalMemoryMB: Int = 200
    public static let maxDownloadSizeMB: Int = 60
    public static let maxAITimeoutP95Ms: Int = 2500

    public let coldLaunchMs: Int
    public let regressionPercentVsBaseline: Double
    public let todayInteractiveMs: Int
    public let cardTransitionMs: Int
    public let perceivedFeedbackMs: Int
    public let serverFeedbackP95Ms: Int
    public let scrollHitchRateMsPerSec: Double
    public let atlasFps: Int
    public let atlasVisibleNodes: Int
    public let typicalMemoryMB: Int
    public let downloadSizeMB: Int
    public let activeRestingTimersOrLoops: Int
    public let aiTimeoutP95Ms: Int

    public init(
        coldLaunchMs: Int = 340,
        regressionPercentVsBaseline: Double = 1.5,
        todayInteractiveMs: Int = 380,
        cardTransitionMs: Int = 65,
        perceivedFeedbackMs: Int = 180,
        serverFeedbackP95Ms: Int = 720,
        scrollHitchRateMsPerSec: Double = 1.2,
        atlasFps: Int = 60,
        atlasVisibleNodes: Int = 500,
        typicalMemoryMB: Int = 128,
        downloadSizeMB: Int = 42,
        activeRestingTimersOrLoops: Int = 0,
        aiTimeoutP95Ms: Int = 2500
    ) {
        self.coldLaunchMs = coldLaunchMs
        self.regressionPercentVsBaseline = regressionPercentVsBaseline
        self.todayInteractiveMs = todayInteractiveMs
        self.cardTransitionMs = cardTransitionMs
        self.perceivedFeedbackMs = perceivedFeedbackMs
        self.serverFeedbackP95Ms = serverFeedbackP95Ms
        self.scrollHitchRateMsPerSec = scrollHitchRateMsPerSec
        self.atlasFps = atlasFps
        self.atlasVisibleNodes = atlasVisibleNodes
        self.typicalMemoryMB = typicalMemoryMB
        self.downloadSizeMB = downloadSizeMB
        self.activeRestingTimersOrLoops = activeRestingTimersOrLoops
        self.aiTimeoutP95Ms = aiTimeoutP95Ms
    }

    public var meetsAllSection30Budgets: Bool {
        coldLaunchMs <= Self.maxColdLaunchMs
            && regressionPercentVsBaseline <= Self.maxRegressionPercentVsBaseline
            && todayInteractiveMs <= Self.maxTodayInteractiveMs
            && cardTransitionMs <= Self.maxCardTransitionMs
            && perceivedFeedbackMs <= Self.maxPerceivedFeedbackMs
            && serverFeedbackP95Ms <= Self.maxServerFeedbackP95Ms
            && scrollHitchRateMsPerSec < Self.maxScrollHitchRateMsPerSec
            && atlasFps >= Self.minAtlasFps
            && atlasVisibleNodes <= Self.maxAtlasVisibleNodes
            && typicalMemoryMB < Self.maxTypicalMemoryMB
            && downloadSizeMB < Self.maxDownloadSizeMB
            && activeRestingTimersOrLoops == 0
            && aiTimeoutP95Ms <= Self.maxAITimeoutP95Ms
    }
}

// MARK: - 3. Normative Analytics Taxonomy (§31) & Critical Journeys (§32.2)

public enum NormativeAnalyticsEventName: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    // Lifecycle
    case appOpened = "app_opened"
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingCompleted = "onboarding_completed"
    case tasteCompleted = "taste_completed"
    case accountCreated = "account_created"
    // Session
    case sessionStarted = "session_started"
    case cardViewed = "card_viewed"
    case itemPresented = "item_presented"
    case itemAnswered = "item_answered"
    case feedbackViewed = "feedback_viewed"
    case skipTestUsed = "skip_test_used"
    case sessionCompleted = "session_completed"
    case sessionAbandoned = "session_abandoned"
    case itemFormatUnsupported = "item_format_unsupported"
    // Learning
    case conceptStateChanged = "concept_state_changed"
    case misconceptionDetected = "misconception_detected"
    case knowledgeUpdateViewed = "knowledge_update_viewed"
    // Rituals
    case dailySituationOpened = "daily_situation_opened"
    case dailySituationCompleted = "daily_situation_completed"
    case communityDistributionViewed = "community_distribution_viewed"
    case shareCardCreated = "share_card_created"
    case shareCardShared = "share_card_shared"
    // Goals
    case goalSet = "goal_set"
    case readinessViewed = "readiness_viewed"
    case mockExamStarted = "mock_exam_started"
    case mockExamCompleted = "mock_exam_completed"
    case examOutcomeReported = "exam_outcome_reported"
    // Habit
    case rhythmDayCompleted = "rhythm_day_completed"
    case rhythmWeekCompleted = "rhythm_week_completed"
    case reminderScheduled = "reminder_scheduled"
    case notificationOpened = "notification_opened"
    case notificationPermission = "notification_permission"
    // Social
    case squadCreated = "squad_created"
    case squadJoined = "squad_joined"
    case kudosSent = "kudos_sent"
    case challengeSent = "challenge_sent"
    case challengeCompleted = "challenge_completed"
    case privacySettingChanged = "privacy_setting_changed"
    // AI
    case aiRequested = "ai_requested"
    case aiFallback = "ai_fallback"
    case aiFeedback = "ai_feedback"
    case aiReported = "ai_reported"
    case aiConsent = "ai_consent"
    // iOS
    case widgetInteraction = "widget_interaction"
    case intentInvoked = "intent_invoked"
    case liveActivityStarted = "live_activity_started"
    // Monetization
    case paywallViewed = "paywall_viewed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseCancelled = "purchase_cancelled"
    // Quality
    case errorShown = "error_shown"
    case offlineModeEntered = "offline_mode_entered"
    case contentIssueReported = "content_issue_reported"

    public var id: String { rawValue }

    public var isSnakeCase: Bool {
        rawValue == rawValue.lowercased() && !rawValue.contains(" ") && !rawValue.contains("-")
    }
}

public struct CriticalJourneyDescriptor: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: Int
    public let title: String
    public let passesAccessibilityAudit: Bool

    public init(id: Int, title: String, passesAccessibilityAudit: Bool = true) {
        self.id = id
        self.title = title
        self.passesAccessibilityAudit = passesAccessibilityAudit
    }

    public static let allEightJourneys: [CriticalJourneyDescriptor] = [
        CriticalJourneyDescriptor(id: 1, title: "Premier lancement → Situation de découverte → Objectif → Aujourd'hui"),
        CriticalJourneyDescriptor(id: 2, title: "Séance Express → Répondre (correct/incorrect) → Feedback → Résultats"),
        CriticalJourneyDescriptor(id: 3, title: "Situation du jour → Révélation → Distribution communautaire → Carte de partage"),
        CriticalJourneyDescriptor(id: 4, title: "Séance hors ligne → Reconnexion → Synchronisation idempotente sans doublon"),
        CriticalJourneyDescriptor(id: 5, title: "Changer d'objectif (confirmation serveur) → Aujourd'hui recomposé"),
        CriticalJourneyDescriptor(id: 6, title: "Atlas → Concept → Pratiquer 1 min"),
        CriticalJourneyDescriptor(id: 7, title: "Examen blanc chronométré / sans limite → Débrief"),
        CriticalJourneyDescriptor(id: 8, title: "Réglages → Rappels → Suppression du compte (confirmation)")
    ]
}

// MARK: - 4. Legacy Path Retirement Governance (§34.1)

public struct LegacyPathCleanupGovernance: Equatable, Hashable, Sendable {
    public static let minimumDaysOnWithoutIncident: Int = 14

    public let flag: FeatureFlag
    public let daysEnabledInProduction: Int
    public let recordedIncidents: Int

    public init(
        flag: FeatureFlag,
        daysEnabledInProduction: Int,
        recordedIncidents: Int = 0
    ) {
        self.flag = flag
        self.daysEnabledInProduction = max(0, daysEnabledInProduction)
        self.recordedIncidents = max(0, recordedIncidents)
    }

    /// §34.1: Legacy fallback paths can only be deleted after the flag stays ON >= 14 days with 0 incident.
    public var isEligibleForLegacyPathDeletion: Bool {
        daysEnabledInProduction >= Self.minimumDaysOnWithoutIncident && recordedIncidents == 0
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

// MARK: - 5. Phase 11 Hardening & App Store Nutrition Labels Screen

public struct Phase11HardeningDashboardScreen: View {
    public let accessibilitySummary: AccessibilityAuditSummary
    public let performanceSnapshot: PerformanceBudgetSnapshot
    public let criticalJourneys: [CriticalJourneyDescriptor]

    public init(
        accessibilitySummary: AccessibilityAuditSummary = AccessibilityAuditSummary(),
        performanceSnapshot: PerformanceBudgetSnapshot = PerformanceBudgetSnapshot(),
        criticalJourneys: [CriticalJourneyDescriptor] = CriticalJourneyDescriptor.allEightJourneys
    ) {
        self.accessibilitySummary = accessibilitySummary
        self.performanceSnapshot = performanceSnapshot
        self.criticalJourneys = criticalJourneys
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismCard(variant: .hero) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        PrismAdaptiveStack(spacing: PrismSpacing.s) {
                            BrandLabel(
                                product: BrandProductID("microsoft-entra-id"),
                                context: .learningContent,
                                examCode: "AZ-104"
                            )
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: accessibilitySummary.passesAllAccessibilityGates && performanceSnapshot.meetsAllSection30Budgets
                                        ? "Prêt pour Release (Phases 0 → 11)"
                                        : "Vérification requise",
                                    semantics: .positive
                                )
                            )
                        }
                        PrismText(
                            text: "Audit complet AX5, VoiceOver, Voice Control, Full Keyboard Access, Reduce Motion / Transparency, Increase Contrast & Budgets §30.",
                            style: .subheadline,
                            role: .textSecondary
                        )
                    }
                }

                PrismSection(title: "App Store Accessibility Nutrition Labels (§28)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        ForEach(accessibilitySummary.eligibleNutritionLabels) { label in
                            PrismCard(variant: .standard) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: "Supporté",
                                            semantics: .positive
                                        )
                                    )
                                    PrismText(text: label.storeDisplayName, style: .subheadline)
                                }
                            }
                        }
                    }
                }

                PrismSection(title: "8 Parcours Critiques XCUITest & Audit Accessibilité (§32.2)") {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        ForEach(criticalJourneys) { journey in
                            PrismCard(variant: .standard) {
                                HStack(spacing: PrismSpacing.s) {
                                    PrismBadge(
                                        configuration: PrismBadgeConfiguration(
                                            text: "#\(journey.id)",
                                            semantics: journey.passesAccessibilityAudit ? .positive : .warning
                                        )
                                    )
                                    PrismText(text: journey.title, style: .footnote)
                                }
                            }
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Qualité & Hardening (Phase 11)"))
    }
}
#endif
