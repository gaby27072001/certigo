import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation

// MARK: - 1. Lead-Architect State Enums & Rich Identifiable Domain Models

/// Explicit node state for every lesson island on the dynamic winding Duolingo path.
public enum CertiGoLessonNodeState: String, Codable, Sendable, CaseIterable {
    case completed
    case available
    case active
    case miniLab
    case locked
}

/// Explicit state machine phase for an interactive Duolingo-style exercise attempt.
public enum CertiGoExerciseAttemptPhase: Equatable, Sendable {
    case answering
    case checked(isCorrect: Bool)
    case explainingError
    case comparingServices
}

/// Native top-level tab in the 5-tab floating Figma Pro bottom bar.
public enum CertiGoNativeTab: String, Codable, Sendable, CaseIterable, Identifiable {
    case parcours
    case examens
    case hubIA
    case social
    case moi

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .parcours: return "Parcours"
        case .examens: return "Examens"
        case .hubIA: return "✦ IA"
        case .social: return "Social"
        case .moi: return "Moi"
        }
    }
}

/// Mimo-style horizontal chapter/module filter chip at the top of the Parcours tab.
public enum CertiGoMimoRailFilter: String, Codable, Sendable, CaseIterable, Identifiable {
    case allUnits = "Tous (15)"
    case unit1 = "Unité 1"
    case unit2 = "Unité 2"
    case unit3 = "Unité 3"
    case miniLabs = "🧪 Mini-Labs"
    case examPrep = "🎯 Examen"

    public var id: String { rawValue }
}

/// Bottom sheet state when tapping a lesson node or unit guide button on Parcours.
public enum CertiGoStepSheetMode: Equatable, Sendable, Identifiable {
    case preview03(lessonId: String)
    case memo14(lessonId: String)

    public var id: String {
        switch self {
        case .preview03(let id): return "preview03-\(id)"
        case .memo14(let id): return "memo14-\(id)"
        }
    }

    public var lessonId: String {
        switch self {
        case .preview03(let id), .memo14(let id): return id
        }
    }
}

/// Navigation destinations pushed inside the Moi / Profile NavigationStack.
public enum CertiGoProfileRoute: Hashable, Sendable {
    case proStats08B
    case certificationDetail26(code: String)
    case settings28
    case systemWidgetsSYS01
    case offlineResilienceRES01
}

/// Interactive gamification sheets launched from the top-right Parcours pills (`🔥 14`, `💎 480`, `❤️ 5`) or Moi summary cards.
public enum CertiGoGamificationSheetKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case streak
    case gems
    case hearts

    public var id: String { rawValue }
}

/// Interactive option picker sheets launched from Paramètres (`28`).
public enum CertiGoSettingsPickerKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case language
    case examMode
    case coachVoice
    case explanationStyle

    public var id: String { rawValue }
}

/// Structured, pre-designed CertiGo Error Code Registry (`CG-ERR-1001` .. `CG-ERR-6001`) across 6 system domains.
public enum CertiGoErrorCode: String, Codable, CaseIterable, Identifiable, Sendable {
    // Série 1000 — Intelligence Artificielle & Modèles LLM (CertigoAI)
    case aiModelNotConnected1001 = "CG-ERR-1001"
    case voiceLiveNotConnected1002 = "CG-ERR-1002"
    case examReportAIDisconnected1003 = "CG-ERR-1003"
    case aiInferenceTimeout1004 = "CG-ERR-1004"

    // Série 2000 — Réseau & API Backend (CertigoNetwork)
    case backendUnreachableOffline2001 = "CG-ERR-2001"
    case leagueSyncFailed2002 = "CG-ERR-2002"

    // Série 3000 — Authentification & Compte (CertigoAuth)
    case authTokenExpired3001 = "CG-ERR-3001"
    case storeKitReceiptUnavailable3002 = "CG-ERR-3002"

    // Série 4000 — Stockage Local & Mode Hors-Ligne (CertigoStorage)
    case offlinePackMissing4001 = "CG-ERR-4001"
    case fsrsSyncQueuePending4002 = "CG-ERR-4002"

    // Série 5000 — Audio, Microphone & Haptique (CertigoMedia)
    case microphonePermissionDenied5001 = "CG-ERR-5001"

    // Série 6000 — Moteur d'Examen & Contenu (CertigoContent)
    case examTimerInterrupted6001 = "CG-ERR-6001"

    public var id: String { rawValue }

    public var code: String { rawValue }

    public var category: String {
        switch self {
        case .aiModelNotConnected1001, .voiceLiveNotConnected1002, .examReportAIDisconnected1003, .aiInferenceTimeout1004:
            return "IA & MODÈLES LLM"
        case .backendUnreachableOffline2001, .leagueSyncFailed2002:
            return "RÉSEAU & API BACKEND"
        case .authTokenExpired3001, .storeKitReceiptUnavailable3002:
            return "AUTHENTIFICATION & COMPTE"
        case .offlinePackMissing4001, .fsrsSyncQueuePending4002:
            return "STOCKAGE LOCAL & HORS-LIGNE"
        case .microphonePermissionDenied5001:
            return "AUDIO, MICROPHONE & HAPTIQUE"
        case .examTimerInterrupted6001:
            return "MOTEUR D'EXAMEN & CONTENU"
        }
    }

    public var severityLabel: String {
        switch self {
        case .aiModelNotConnected1001, .voiceLiveNotConnected1002, .examReportAIDisconnected1003:
            return "Service non connecté"
        case .aiInferenceTimeout1004, .backendUnreachableOffline2001, .leagueSyncFailed2002:
            return "Avertissement Réseau"
        case .authTokenExpired3001, .storeKitReceiptUnavailable3002:
            return "Authentification requise"
        case .offlinePackMissing4001, .fsrsSyncQueuePending4002:
            return "Synchronisation Locale"
        case .microphonePermissionDenied5001:
            return "Permission Système iOS"
        case .examTimerInterrupted6001:
            return "Intégrité Session Examen"
        }
    }

    public var title: String {
        switch self {
        case .aiModelNotConnected1001:
            return "Modèle IA non connecté (Coach IA Écrit)"
        case .voiceLiveNotConnected1002:
            return "Session Vocale Temps Réel indisponible (Nova Live 06C)"
        case .examReportAIDisconnected1003:
            return "Diagnostic IA de copie d'examen indisponible"
        case .aiInferenceTimeout1004:
            return "Délai d'attente dépassé (Timeout Inférence IA > 15s)"
        case .backendUnreachableOffline2001:
            return "Serveur API CertiGo injoignable (Hors-Ligne)"
        case .leagueSyncFailed2002:
            return "Échec de synchronisation du classement Ligue Or"
        case .authTokenExpired3001:
            return "Jeton d'authentification MSAL / Entra ID expiré"
        case .storeKitReceiptUnavailable3002:
            return "Vérification d'abonnement StoreKit / Apple Pay indisponible"
        case .offlinePackMissing4001:
            return "Pack Hors-Ligne non téléchargé pour cette certification"
        case .fsrsSyncQueuePending4002:
            return "File d'attente de synchronisation FSRS en attente"
        case .microphonePermissionDenied5001:
            return "Permission Microphone iOS non accordée"
        case .examTimerInterrupted6001:
            return "Session d'examen interrompue"
        }
    }

    public var userMessage: String {
        switch self {
        case .aiModelNotConnected1001:
            return "Aucun endpoint de modèle IA (Azure AI Foundry / OpenAI) n'est connecté à cette session. Les réponses génératives et évaluations IA en direct sont désactivées pour éviter d'afficher des résultats fictifs."
        case .voiceLiveNotConnected1002:
            return "Le flux WebRTC / WebSocket temps réel du modèle vocal IA n'est pas connecté. Vérifie la configuration de l'endpoint vocal."
        case .examReportAIDisconnected1003:
            return "L'analyse générative personnalisée de tes erreurs d'examen requiert une connexion active au moteur CertiGo IA."
        case .aiInferenceTimeout1004:
            return "Le modèle IA n'a pas répondu dans le délai imparti."
        case .backendUnreachableOffline2001:
            return "Impossible de joindre l'API distante. Bascule automatique sur le cache local Hors-Ligne."
        case .leagueSyncFailed2002:
            return "Les scores temps réel de la Ligue n'ont pas pu être actualisés depuis le serveur."
        case .authTokenExpired3001:
            return "Ta session sécurisée a expiré. Reconnecte-toi pour synchroniser ton profil."
        case .storeKitReceiptUnavailable3002:
            return "Impossible de vérifier le reçu App Store sur cet appareil de test."
        case .offlinePackMissing4001:
            return "Cette unité n'est pas encore présente dans le stockage local SQLite/CoreData."
        case .fsrsSyncQueuePending4002:
            return "Tes progrès locaux sont enregistrés et seront synchronisés dès le retour du réseau."
        case .microphonePermissionDenied5001:
            return "Autorise l'accès au microphone dans Réglages iOS > CertiGo pour utiliser le mode vocal."
        case .examTimerInterrupted6001:
            return "Le chronomètre Pearson VUE a été mis en pause suite à une mise en arrière-plan."
        }
    }

    public var technicalDetail: String {
        switch self {
        case .aiModelNotConnected1001:
            return "Endpoint: AI_FOUNDRY_ENDPOINT=nil · HTTP 503 Service Unavailable (CertigoAI.ChatRouter)"
        case .voiceLiveNotConnected1002:
            return "Transport: WSS_REALTIME_VOICE_URL=nil · WebSocket Handshake Aborted (CertigoAI.NovaVoice)"
        case .examReportAIDisconnected1003:
            return "Service: ExamRemediationSynthesizer · Missing Live LLM Credentials (HTTP 503)"
        case .aiInferenceTimeout1004:
            return "DeadlineExceeded: Streaming token latency > 15,000 ms (CertigoAI.InferenceClient)"
        case .backendUnreachableOffline2001:
            return "NSURLErrorNotConnectedToInternet (-1009) · Fallback: LocalOfflineStoreActive"
        case .leagueSyncFailed2002:
            return "GET /api/v1/leagues/gold/standings · HTTP 502 Bad Gateway"
        case .authTokenExpired3001:
            return "MSALErrorInteractionRequired (-50002) · OIDC Bearer token expired"
        case .storeKitReceiptUnavailable3002:
            return "StoreKit.Transaction.currentEntitlements · Sandbox Receipt Missing"
        case .offlinePackMissing4001:
            return "SQLiteBundleError: PackMissingForTrack · Track payload not cached on disk"
        case .fsrsSyncQueuePending4002:
            return "OutboxQueue: pendingMutations > 0 · Idempotent clientAttemptId queued"
        case .microphonePermissionDenied5001:
            return "AVAudioApplication.recordPermission == .denied"
        case .examTimerInterrupted6001:
            return "UIApplication.willResignActiveNotification · PearsonTimerPaused"
        }
    }

    public var recommendedAction: String {
        switch self {
        case .aiModelNotConnected1001:
            return "Connecte un endpoint Azure AI Foundry / OpenAI dans la configuration d'environnement ou utilise les Fiches Mémo Officielles (14) et les Quiz du Parcours."
        case .voiceLiveNotConnected1002:
            return "Configure l'endpoint vocal temps réel ou reviens au parcours d'entraînement écrit."
        case .examReportAIDisconnected1003:
            return "Consulte dès maintenant le « 🔍 Corrigé détaillé question par question » intégré localement dans ton Rapport d'Examen (24)."
        case .aiInferenceTimeout1004:
            return "Vérifie la latence réseau et relance la requête avec une question plus ciblée."
        case .backendUnreachableOffline2001:
            return "Continue tes leçons en mode Hors-Ligne : la synchronisation idempotente reprendra automatiquement."
        case .leagueSyncFailed2002:
            return "Actualise le classement dans quelques instants."
        case .authTokenExpired3001:
            return "Ouvre Paramètres (28) pour renouveler ta session Microsoft Entra ID."
        case .storeKitReceiptUnavailable3002:
            return "Connecte un compte App Store Sandbox sur l'appareil physique."
        case .offlinePackMissing4001:
            return "Ouvre Paramètres (28) > Cours téléchargés (Hors-Ligne) pour télécharger le pack."
        case .fsrsSyncQueuePending4002:
            return "Aucune action requise : tes cartes FSRS sont sauvegardées localement."
        case .microphonePermissionDenied5001:
            return "Active le microphone dans Réglages iOS > Confidentialité > Microphone."
        case .examTimerInterrupted6001:
            return "Reprends l'examen blanc depuis la Grille de navigation (50 Q)."
        }
    }
}

public extension CertiGoAnimationPresetID {
    static var anim06HistoryDrawer85Push: Self { .anim04Claude85DrawerPush }
}

/// A single lesson island on the dynamic winding path.
public struct CertiGoPathLessonNode: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let unitNumber: Int
    public let stepIndexInUnit: Int
    public let globalIndex: Int
    public let title: String
    public let subtitle: String
    public var state: CertiGoLessonNodeState
    public let iconSymbol: String
    public let levelBadge: String
    public let horizontalOffsetFactor: Double

    public init(
        id: String,
        unitNumber: Int,
        stepIndexInUnit: Int,
        globalIndex: Int,
        title: String,
        subtitle: String,
        state: CertiGoLessonNodeState,
        iconSymbol: String,
        levelBadge: String = "Niv. 2/3",
        horizontalOffsetFactor: Double
    ) {
        self.id = id
        self.unitNumber = unitNumber
        self.stepIndexInUnit = stepIndexInUnit
        self.globalIndex = globalIndex
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.iconSymbol = iconSymbol
        self.levelBadge = levelBadge
        self.horizontalOffsetFactor = horizontalOffsetFactor
    }
}

/// A full curriculum unit containing 5 winding lesson nodes and its Screen 14 Memo sheet content.
public struct CertiGoCertificationUnit: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let unitNumber: Int
    public let headerTitle: String
    public let subtitle: String
    public let progressPercent: Int
    public let accentHex: String
    public let lipHex: String
    public let memoActivity: String
    public let memoKeyTopics: [String]
    public let memoGoldenRule: String
    public var lessons: [CertiGoPathLessonNode]

    public init(
        id: String,
        unitNumber: Int,
        headerTitle: String,
        subtitle: String,
        progressPercent: Int,
        accentHex: String = "#0078d4",
        lipHex: String = "#005a9e",
        memoActivity: String,
        memoKeyTopics: [String],
        memoGoldenRule: String,
        lessons: [CertiGoPathLessonNode]
    ) {
        self.id = id
        self.unitNumber = unitNumber
        self.headerTitle = headerTitle
        self.subtitle = subtitle
        self.progressPercent = progressPercent
        self.accentHex = accentHex
        self.lipHex = lipHex
        self.memoActivity = memoActivity
        self.memoKeyTopics = memoKeyTopics
        self.memoGoldenRule = memoGoldenRule
        self.lessons = lessons
    }
}

/// Rich interactive exercise item supporting all 10 Figma Pro question formats (`Q_TYPE_01..10`).
public struct CertiGoNativeExerciseItem: Identifiable, Equatable, Sendable {
    public struct OptionItem: Identifiable, Equatable, Sendable {
        public let id: String
        public let badge: String
        public let title: String
        public let subtitle: String?
        public let assetName: String?
        public let isCorrect: Bool
        public let whyWrongOrRight: String

        public init(
            id: String,
            badge: String,
            title: String,
            subtitle: String? = nil,
            assetName: String? = nil,
            isCorrect: Bool,
            whyWrongOrRight: String
        ) {
            self.id = id
            self.badge = badge
            self.title = title
            self.subtitle = subtitle
            self.assetName = assetName
            self.isCorrect = isCorrect
            self.whyWrongOrRight = whyWrongOrRight
        }
    }

    public let id: String
    public let formatCode: String
    public let domainBadge: String
    public let subBadge: String
    public let prompt: String
    public let mascotPose: CertiGoMascotPose
    public let options: [OptionItem]
    public let cliPrefix: String?
    public let cliSuffix: String?
    public let expectedCLIInput: String?
    public let cliSuggestionBricks: [String]
    public let wordBankTargetTokens: [String]
    public let wordBankAllBricks: [String]
    public let matchingLeftItems: [String]
    public let matchingRightItems: [String]
    public let hierarchyCorrectOrder: [String]
    public let examTip: String
    public let comparisonLeftTitle: String
    public let comparisonLeftBullets: [String]
    public let comparisonRightTitle: String
    public let comparisonRightBullets: [String]
    public let comparisonGoldenRule: String
    public var conceptId: String
    public var conceptTitle: String
    public var difficulty: Double
    public var variantGroupId: String
    public var isReviewReplay: Bool

    public init(
        id: String,
        formatCode: String,
        domainBadge: String,
        subBadge: String = "SCÉNARIO ARCHITECTURE",
        prompt: String,
        mascotPose: CertiGoMascotPose = .specialistCloudAzure,
        options: [OptionItem],
        cliPrefix: String? = nil,
        cliSuffix: String? = nil,
        expectedCLIInput: String? = nil,
        cliSuggestionBricks: [String] = [],
        wordBankTargetTokens: [String] = [],
        wordBankAllBricks: [String] = [],
        matchingLeftItems: [String] = [],
        matchingRightItems: [String] = [],
        hierarchyCorrectOrder: [String] = [],
        examTip: String,
        comparisonLeftTitle: String = "Service Endpoint",
        comparisonLeftBullets: [String] = [
            "Garde l'IP publique du service PaaS",
            "Pas besoin de zone DNS privée",
            "Non routable depuis On-Premises (VPN / ExpressRoute)"
        ],
        comparisonRightTitle: String = "Private Endpoint",
        comparisonRightBullets: [String] = [
            "Crée une NIC avec IP privée (10.x) dans ton Subnet",
            "Requiert une zone privatelink.*",
            "Accessible depuis On-Premises via ExpressRoute/VPN"
        ],
        comparisonGoldenRule: String = "Dès que l'énoncé mentionne « depuis On-Premises via ExpressRoute » ou « IP privée 10.x », choisis toujours Private Endpoint !",
        conceptId: String = "",
        conceptTitle: String = "",
        difficulty: Double = 0.50,
        variantGroupId: String = "",
        isReviewReplay: Bool = false
    ) {
        self.id = id
        self.formatCode = formatCode
        self.domainBadge = domainBadge
        self.subBadge = subBadge
        self.prompt = prompt
        self.mascotPose = mascotPose
        self.options = options
        self.cliPrefix = cliPrefix
        self.cliSuffix = cliSuffix
        self.expectedCLIInput = expectedCLIInput
        self.cliSuggestionBricks = cliSuggestionBricks
        self.wordBankTargetTokens = wordBankTargetTokens
        self.wordBankAllBricks = wordBankAllBricks
        self.matchingLeftItems = matchingLeftItems
        self.matchingRightItems = matchingRightItems
        self.hierarchyCorrectOrder = hierarchyCorrectOrder
        self.examTip = examTip
        self.comparisonLeftTitle = comparisonLeftTitle
        self.comparisonLeftBullets = comparisonLeftBullets
        self.comparisonRightTitle = comparisonRightTitle
        self.comparisonRightBullets = comparisonRightBullets
        self.comparisonGoldenRule = comparisonGoldenRule
        self.conceptId = conceptId.isEmpty ? id : conceptId
        self.conceptTitle = conceptTitle.isEmpty ? domainBadge : conceptTitle
        self.difficulty = min(max(difficulty, 0.0), 1.0)
        self.variantGroupId = variantGroupId.isEmpty ? (conceptId.isEmpty ? id : conceptId) : variantGroupId
        self.isReviewReplay = isReviewReplay
    }

    public var correctOptions: [OptionItem] {
        options.filter(\.isCorrect)
    }

    public var primaryCorrectOptionTitle: String {
        if let expectedCLIInput {
            return expectedCLIInput
        }
        if !wordBankTargetTokens.isEmpty {
            return wordBankTargetTokens.joined(separator: " ")
        }
        return correctOptions.map(\.title).joined(separator: " + ")
    }
}

// MARK: - 1B. Duolingo-Inspired Deterministic Adaptive Session Engine (`CertiGoAdaptiveSessionEngine`)

/// Question metadata for the deterministic adaptive session engine (zero LLM for question selection).
public struct CertiGoAdaptiveQuestion: Identifiable, Equatable, Sendable {
    public let id: String
    public let conceptId: String
    public let conceptTitle: String
    public let difficulty: Double
    public let formatCode: String
    public let variantGroupId: String
    public var isReviewReplay: Bool
    public var exercise: CertiGoNativeExerciseItem

    public init(
        id: String,
        conceptId: String,
        conceptTitle: String,
        difficulty: Double,
        formatCode: String,
        variantGroupId: String,
        isReviewReplay: Bool = false,
        exercise: CertiGoNativeExerciseItem
    ) {
        self.id = id
        self.conceptId = conceptId
        self.conceptTitle = conceptTitle
        self.difficulty = min(max(difficulty, 0.0), 1.0)
        self.formatCode = formatCode
        self.variantGroupId = variantGroupId
        self.isReviewReplay = isReviewReplay
        var enriched = exercise
        enriched.conceptId = conceptId
        enriched.conceptTitle = conceptTitle
        enriched.difficulty = min(max(difficulty, 0.0), 1.0)
        enriched.variantGroupId = variantGroupId
        enriched.isReviewReplay = isReviewReplay
        self.exercise = enriched
    }
}

/// Persistent per-concept learner state (`mastery` 0..1, `errorCount`, `lastSeenAt`, `streak`, `spacedIntervalHours`).
public struct CertiGoLearnerConceptState: Codable, Equatable, Sendable, Identifiable {
    public var id: String { conceptId }
    public let conceptId: String
    public var mastery: Double
    public var errorCount: Int
    public var lastSeenAt: Date?
    public var streak: Int
    public var spacedIntervalHours: Double

    public init(
        conceptId: String,
        mastery: Double = 0.35,
        errorCount: Int = 0,
        lastSeenAt: Date? = nil,
        streak: Int = 0,
        spacedIntervalHours: Double = 4.0
    ) {
        self.conceptId = conceptId
        self.mastery = min(max(mastery, 0.0), 1.0)
        self.errorCount = max(0, errorCount)
        self.lastSeenAt = lastSeenAt
        self.streak = max(0, streak)
        self.spacedIntervalHours = max(1.0, spacedIntervalHours)
    }
}

/// Single attempt entry in `CertiGoAdaptiveSessionState.history`.
public struct CertiGoAdaptiveAttemptRecord: Equatable, Sendable, Identifiable {
    public let id: String
    public let questionId: String
    public let conceptId: String
    public let isCorrect: Bool
    public let latencyMs: Int
    public let usedHint: Bool
    public let wasReviewReplay: Bool
    public let masteryAfter: Double

    public init(
        id: String,
        questionId: String,
        conceptId: String,
        isCorrect: Bool,
        latencyMs: Int,
        usedHint: Bool,
        wasReviewReplay: Bool,
        masteryAfter: Double
    ) {
        self.id = id
        self.questionId = questionId
        self.conceptId = conceptId
        self.isCorrect = isCorrect
        self.latencyMs = latencyMs
        self.usedHint = usedHint
        self.wasReviewReplay = wasReviewReplay
        self.masteryAfter = masteryAfter
    }
}

/// Active session state (`queue`, `candidatePool`, `history`, `retryBudgetByConcept`, `maxQuestions = 25`, `masteryThreshold = 0.75`).
public struct CertiGoAdaptiveSessionState: Equatable, Sendable {
    public var queue: [CertiGoAdaptiveQuestion]
    public var candidatePool: [CertiGoAdaptiveQuestion]
    public var conceptIds: [String]
    public var history: [CertiGoAdaptiveAttemptRecord]
    public var retryBudgetByConcept: [String: Int]
    public var conceptsToReviewAtEnd: [String]
    public var endOfQueueReviewReplayed: Set<String>
    public var questionsAsked: Int
    public let maxQuestions: Int
    public let masteryThreshold: Double

    public init(
        queue: [CertiGoAdaptiveQuestion],
        candidatePool: [CertiGoAdaptiveQuestion],
        conceptIds: [String],
        history: [CertiGoAdaptiveAttemptRecord] = [],
        retryBudgetByConcept: [String: Int] = [:],
        conceptsToReviewAtEnd: [String] = [],
        endOfQueueReviewReplayed: Set<String> = [],
        questionsAsked: Int = 0,
        maxQuestions: Int = 25,
        masteryThreshold: Double = 0.75
    ) {
        self.queue = queue
        self.candidatePool = candidatePool
        self.conceptIds = conceptIds
        self.history = history
        self.retryBudgetByConcept = retryBudgetByConcept
        self.conceptsToReviewAtEnd = conceptsToReviewAtEnd
        self.endOfQueueReviewReplayed = endOfQueueReviewReplayed
        self.questionsAsked = questionsAsked
        self.maxQuestions = max(1, maxQuestions)
        self.masteryThreshold = min(max(masteryThreshold, 0.1), 1.0)
    }
}

/// Pure, 100% deterministic Duolingo-inspired adaptive engine (zero LLM calls).
public enum CertiGoAdaptiveSessionEngine {

    /// Pure function returning the next question to ask, or `nil` if the session is complete.
    public static func nextQuestion(
        sessionState: CertiGoAdaptiveSessionState,
        learnerState: [String: CertiGoLearnerConceptState]
    ) -> CertiGoAdaptiveQuestion? {
        guard sessionState.questionsAsked < sessionState.maxQuestions else {
            return nil
        }
        if let first = sessionState.queue.first {
            return first
        }
        // Step 3: End-of-queue "À revoir en fin de session" check
        for cid in sessionState.conceptsToReviewAtEnd where !sessionState.endOfQueueReviewReplayed.contains(cid) {
            if let reviewVariant = selectBestVariant(
                forConceptId: cid,
                excludingQuestionIds: Set(sessionState.history.map(\.questionId)),
                targetDifficulty: 0.55,
                candidatePool: sessionState.candidatePool,
                markAsReviewReplay: true
            ) {
                return reviewVariant
            }
        }
        // Check if any concept is still below masteryThreshold and still has retry budget
        for cid in sessionState.conceptIds {
            let currentMastery = learnerState[cid]?.mastery ?? 0.35
            let budget = sessionState.retryBudgetByConcept[cid, default: 0]
            if currentMastery < sessionState.masteryThreshold && budget > 0 {
                if let extraVariant = selectBestVariant(
                    forConceptId: cid,
                    excludingQuestionIds: Set(sessionState.history.suffix(3).map(\.questionId)),
                    targetDifficulty: min(max(currentMastery + 0.15, 0.35), 0.85),
                    candidatePool: sessionState.candidatePool,
                    markAsReviewReplay: true
                ) {
                    return extraVariant
                }
            }
        }
        return nil
    }

    /// Estimated success probability in `[0.05 ... 0.98]` given concept mastery and question difficulty.
    public static func estimatedSuccessProbability(mastery: Double, difficulty: Double) -> Double {
        // When difficulty == mastery + 0.15, estimated success is ~0.75 (inside the 70-80% sweet spot)
        let raw = 0.75 + (mastery - (difficulty - 0.15)) * 0.65
        return min(max(raw, 0.05), 0.98)
    }

    /// Builds an initial adaptive session of ~8-10 questions across the step's concepts, seeded deterministically.
    public static func buildInitialSession(
        routeCode: String,
        lessonId: String = "",
        lessonTitle: String = "",
        learnerState: [String: CertiGoLearnerConceptState] = [:],
        sessionSeed: UInt64 = 1,
        maxQuestions: Int = 25,
        masteryThreshold: Double = 0.75
    ) -> (sessionState: CertiGoAdaptiveSessionState, learnerState: [String: CertiGoLearnerConceptState]) {
        let baseExercises = CertiGoNativeLessonSessionEngine.defaultExercises(
            forRouteCode: routeCode,
            lessonId: lessonId,
            lessonTitle: lessonTitle
        )
        let pool = buildCandidatePool(from: baseExercises, routeCode: routeCode, lessonId: lessonId)
        var orderedConceptIds: [String] = []
        for q in pool where !orderedConceptIds.contains(q.conceptId) {
            orderedConceptIds.append(q.conceptId)
        }

        var resolvedLearner = learnerState
        var retryBudgets: [String: Int] = [:]
        for cid in orderedConceptIds {
            if resolvedLearner[cid] == nil {
                resolvedLearner[cid] = CertiGoLearnerConceptState(conceptId: cid, mastery: 0.35)
            }
            retryBudgets[cid] = 2
        }

        // Seeded deterministic permutation over concepts so two users/runs get distinct trajectories
        var rng = sessionSeed == 0 ? 0x9E37_79B9_7F4A_7C15 : sessionSeed
        func nextRand() -> UInt64 {
            rng &+= 0x9E37_79B9_7F4A_7C15
            var z = rng
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        var shuffledConcepts = orderedConceptIds
        if shuffledConcepts.count > 1 && sessionSeed != 1 {
            for idx in stride(from: shuffledConcepts.count - 1, through: 1, by: -1) {
                let swapIdx = Int(nextRand() % UInt64(idx + 1))
                if idx != swapIdx {
                    shuffledConcepts.swapAt(idx, swapIdx)
                }
            }
        }

        // Step 1: Pick ~8 questions (2 rounds across the 4 concepts) calibrated for 70-80% success probability
        var initialQueue: [CertiGoAdaptiveQuestion] = []
        var usedIds = Set<String>()

        // Round 1: 1 question per concept at target difficulty (mastery + 0.15 -> ~75% success probability)
        for cid in shuffledConcepts {
            let mastery = resolvedLearner[cid]?.mastery ?? 0.35
            let seedOffset = sessionSeed == 1 ? 0.0 : (Double(nextRand() % 20) - 10.0) * 0.01
            let targetDiff = min(max(mastery + 0.15 + seedOffset, 0.30), 0.85)
            if let picked = selectBestVariant(
                forConceptId: cid,
                excludingQuestionIds: usedIds,
                targetDifficulty: targetDiff,
                candidatePool: pool,
                markAsReviewReplay: false
            ) {
                initialQueue.append(picked)
                usedIds.insert(picked.id)
            }
        }

        // Round 2: Second variant per concept (so a flawless user can prune Round 2 once mastery >= 0.75!)
        var round2Concepts = shuffledConcepts
        if round2Concepts.count > 1 {
            let shift = Int(nextRand() % UInt64(round2Concepts.count))
            round2Concepts = Array(round2Concepts.dropFirst(shift)) + Array(round2Concepts.prefix(shift))
        }
        for cid in round2Concepts {
            let mastery = resolvedLearner[cid]?.mastery ?? 0.35
            let targetDiff = min(max(mastery + 0.25, 0.45), 0.85)
            if let picked = selectBestVariant(
                forConceptId: cid,
                excludingQuestionIds: usedIds,
                targetDifficulty: targetDiff,
                candidatePool: pool,
                markAsReviewReplay: false
            ) {
                initialQueue.append(picked)
                usedIds.insert(picked.id)
            }
        }

        let state = CertiGoAdaptiveSessionState(
            queue: initialQueue,
            candidatePool: pool,
            conceptIds: orderedConceptIds,
            history: [],
            retryBudgetByConcept: retryBudgets,
            conceptsToReviewAtEnd: [],
            endOfQueueReviewReplayed: [],
            questionsAsked: 0,
            maxQuestions: maxQuestions,
            masteryThreshold: masteryThreshold
        )
        return (state, resolvedLearner)
    }

    /// Step 2 & Step 3: Processes an answer, updates `learnerState`, inserts error variants 3-5 positions later, prunes mastered concepts, and prepares end-of-session review.
    public static func recordAnswer(
        sessionState: inout CertiGoAdaptiveSessionState,
        learnerState: inout [String: CertiGoLearnerConceptState],
        isCorrect: Bool,
        latencyMs: Int = 2_500,
        usedHint: Bool = false,
        now: Date = Date()
    ) {
        guard let current = nextQuestion(sessionState: sessionState, learnerState: learnerState) else {
            return
        }
        if !sessionState.queue.isEmpty && sessionState.queue[0].id == current.id {
            sessionState.queue.removeFirst()
        }
        sessionState.questionsAsked += 1

        let cid = current.conceptId
        var cState = learnerState[cid] ?? CertiGoLearnerConceptState(conceptId: cid, mastery: 0.35)
        let isFluentCorrect = isCorrect && latencyMs < 6_000 && !usedHint

        // 2a. Update mastery(concept) & spaced interval
        if isCorrect {
            let gain = isFluentCorrect ? 0.26 : 0.18
            cState.mastery = min(1.0, cState.mastery + gain)
            cState.streak += 1
            cState.spacedIntervalHours = max(4.0, cState.spacedIntervalHours * 2.0)
            cState.lastSeenAt = now
        } else {
            cState.mastery = max(0.10, cState.mastery - 0.22)
            cState.errorCount += 1
            cState.streak = 0
            cState.spacedIntervalHours = max(1.0, cState.spacedIntervalHours * 0.4)
            cState.lastSeenAt = now
        }
        learnerState[cid] = cState

        sessionState.history.append(
            CertiGoAdaptiveAttemptRecord(
                id: "att-\(sessionState.questionsAsked)-\(current.id)",
                questionId: current.id,
                conceptId: cid,
                isCorrect: isCorrect,
                latencyMs: latencyMs,
                usedHint: usedHint,
                wasReviewReplay: current.isReviewReplay,
                masteryAfter: cState.mastery
            )
        )

        // 2b. If FALSE: re-insert a variant of the SAME concept 3 to 5 positions later (if retryBudget > 0)
        if !isCorrect {
            if !sessionState.conceptsToReviewAtEnd.contains(cid) {
                sessionState.conceptsToReviewAtEnd.append(cid)
            }
            let remainingBudget = sessionState.retryBudgetByConcept[cid, default: 2]
            if remainingBudget > 0 && (sessionState.questionsAsked + sessionState.queue.count) < sessionState.maxQuestions {
                sessionState.retryBudgetByConcept[cid] = remainingBudget - 1
                if let variant = selectBestVariant(
                    forConceptId: cid,
                    excludingQuestionIds: [current.id],
                    targetDifficulty: max(0.30, current.difficulty - 0.10),
                    candidatePool: sessionState.candidatePool,
                    markAsReviewReplay: true
                ) {
                    // Insert 3 to 5 positions later (clamped to queue.count if fewer items remain)
                    let desiredOffset = min(4, max(3, sessionState.queue.count))
                    let insertIndex = min(sessionState.queue.count, desiredOffset)
                    sessionState.queue.insert(variant, at: insertIndex)
                }
            }
        } else if isFluentCorrect {
            // 2c. If TRUE rapidly without hint: raise difficulty for remaining items of this concept, and prune redundant unasked items if mastery >= masteryThreshold
            if cState.mastery >= sessionState.masteryThreshold {
                sessionState.queue.removeAll { queued in
                    queued.conceptId == cid && !queued.isReviewReplay
                }
            } else {
                for idx in sessionState.queue.indices where sessionState.queue[idx].conceptId == cid && !sessionState.queue[idx].isReviewReplay {
                    let currentQueued = sessionState.queue[idx]
                    if let harderVariant = selectBestVariant(
                        forConceptId: cid,
                        excludingQuestionIds: [current.id, currentQueued.id],
                        targetDifficulty: min(0.85, currentQueued.difficulty + 0.20),
                        candidatePool: sessionState.candidatePool,
                        markAsReviewReplay: false
                    ) {
                        sessionState.queue[idx] = harderVariant
                    }
                }
            }
        }

        // Step 3: End of queue -> enqueue "À revoir" review questions for concepts that had errors
        if sessionState.queue.isEmpty && sessionState.questionsAsked < sessionState.maxQuestions {
            for reviewCid in sessionState.conceptsToReviewAtEnd where !sessionState.endOfQueueReviewReplayed.contains(reviewCid) {
                guard sessionState.questionsAsked + sessionState.queue.count < sessionState.maxQuestions else { break }
                sessionState.endOfQueueReviewReplayed.insert(reviewCid)
                if let finalReview = selectBestVariant(
                    forConceptId: reviewCid,
                    excludingQuestionIds: [current.id],
                    targetDifficulty: 0.55,
                    candidatePool: sessionState.candidatePool,
                    markAsReviewReplay: true
                ) {
                    sessionState.queue.append(finalReview)
                }
            }
        }
    }

    /// Step 4: Progress ratio in `0.0...1.0` driven by concept mastery relative to `masteryThreshold` rather than a static 1/10 counter.
    public static func masteryProgressRatio(
        sessionState: CertiGoAdaptiveSessionState,
        learnerState: [String: CertiGoLearnerConceptState]
    ) -> Double {
        guard !sessionState.conceptIds.isEmpty else { return 1.0 }
        if nextQuestion(sessionState: sessionState, learnerState: learnerState) == nil {
            return 1.0
        }
        let totalMastery = sessionState.conceptIds.reduce(0.0) { acc, cid in
            let m = learnerState[cid]?.mastery ?? 0.35
            return acc + min(1.0, m / max(0.1, sessionState.masteryThreshold))
        }
        let avgMasteryRatio = totalMastery / Double(sessionState.conceptIds.count)
        let totalPlanned = max(1, sessionState.questionsAsked + sessionState.queue.count)
        let queueRatio = Double(sessionState.questionsAsked) / Double(totalPlanned)
        return min(max(avgMasteryRatio * 0.65 + queueRatio * 0.35, 0.12), 0.96)
    }

    private static func selectBestVariant(
        forConceptId conceptId: String,
        excludingQuestionIds: Set<String>,
        targetDifficulty: Double,
        candidatePool: [CertiGoAdaptiveQuestion],
        markAsReviewReplay: Bool
    ) -> CertiGoAdaptiveQuestion? {
        let candidates = candidatePool.filter { $0.conceptId == conceptId }
        guard !candidates.isEmpty else { return nil }
        let nonExcluded = candidates.filter { !excludingQuestionIds.contains($0.id) }
        let poolToSearch = nonExcluded.isEmpty ? candidates : nonExcluded

        guard var chosen = poolToSearch.min(by: {
            abs($0.difficulty - targetDifficulty) < abs($1.difficulty - targetDifficulty)
        }) else {
            return nil
        }
        chosen.isReviewReplay = markAsReviewReplay
        chosen.exercise.isReviewReplay = markAsReviewReplay
        return chosen
    }

    public static func reassignedPositionalOptionBadges(
        _ options: [CertiGoNativeExerciseItem.OptionItem]
    ) -> [CertiGoNativeExerciseItem.OptionItem] {
        guard !options.isEmpty else { return [] }
        let letterSet: Set<String> = ["A", "B", "C", "D", "E", "F"]
        let allLetters = options.allSatisfy { letterSet.contains($0.badge.uppercased()) }
        guard allLetters else { return options }
        let positionalLetters = ["A", "B", "C", "D", "E", "F"]
        return options.enumerated().map { index, opt in
            CertiGoNativeExerciseItem.OptionItem(
                id: opt.id,
                badge: positionalLetters[min(index, positionalLetters.count - 1)],
                title: opt.title,
                subtitle: opt.subtitle,
                assetName: opt.assetName,
                isCorrect: opt.isCorrect,
                whyWrongOrRight: opt.whyWrongOrRight
            )
        }
    }

    public static func rephrasedScenarioPrompt(
        for baseEx: CertiGoNativeExerciseItem,
        routeCode: String,
        variantIndex: Int
    ) -> String {
        let upper = routeCode.uppercased()
        let cleaned = baseEx.prompt
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "[Variante Pratique] ", with: "")
            .replacingOccurrences(of: "[Cas Complexe] ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = CertiGoStructuredPromptView.splitScenarioAndQuestion(cleaned)
        let baseContext = parts.scenario ?? parts.question
        switch variantIndex {
        case 2:
            return "En production sur \(upper) (\(baseEx.domainBadge)) : \(baseContext)\nQuelle décision d'architecture retiens-tu ?"
        default:
            return "Vérification de maîtrise (\(baseEx.domainBadge)) : \(baseContext)\nQuel choix respecte la règle officielle \(upper) ?"
        }
    }

    /// Builds 3 difficulty variants (`0.35`, `0.55`, `0.80`) per core concept from the step's base exercises.
    public static func buildCandidatePool(
        from baseExercises: [CertiGoNativeExerciseItem],
        routeCode: String,
        lessonId: String
    ) -> [CertiGoAdaptiveQuestion] {
        let coreExercises = Array(baseExercises.prefix(4))
        var pool: [CertiGoAdaptiveQuestion] = []
        let upper = routeCode.uppercased()
        let lessonSlug = lessonId.isEmpty ? "u1-s1" : lessonId.lowercased()

        for (idx, baseEx) in coreExercises.enumerated() {
            let cid = "\(upper.lowercased()):\(lessonSlug):concept-\(idx + 1)"
            let cTitle = baseEx.domainBadge
            let vGroupId = "\(cid)-group"

            // Variant 1 (Difficulty 0.38 — Foundational)
            var ex1 = baseEx
            ex1.conceptId = cid
            ex1.conceptTitle = cTitle
            ex1.difficulty = 0.38
            ex1.variantGroupId = vGroupId
            pool.append(
                CertiGoAdaptiveQuestion(
                    id: "\(baseEx.id)-v1",
                    conceptId: cid,
                    conceptTitle: cTitle,
                    difficulty: 0.38,
                    formatCode: baseEx.formatCode,
                    variantGroupId: vGroupId,
                    isReviewReplay: false,
                    exercise: ex1
                )
            )

            // Variant 2 (Difficulty 0.58 — Intermediate Scenario Variant with reordered options, ordered A..D badges & rephrased wording)
            let v2Options = baseEx.options.isEmpty
                ? []
                : reassignedPositionalOptionBadges(Array(baseEx.options.reversed()))
            let ex2 = CertiGoNativeExerciseItem(
                id: "\(baseEx.id)-v2",
                formatCode: baseEx.formatCode,
                domainBadge: baseEx.domainBadge,
                subBadge: "VARIANTE SCÉNARIO · \(upper)",
                prompt: rephrasedScenarioPrompt(for: baseEx, routeCode: upper, variantIndex: 2),
                mascotPose: baseEx.mascotPose,
                options: v2Options,
                cliPrefix: baseEx.cliPrefix,
                cliSuffix: baseEx.cliSuffix,
                expectedCLIInput: baseEx.expectedCLIInput,
                cliSuggestionBricks: baseEx.cliSuggestionBricks,
                wordBankTargetTokens: baseEx.wordBankTargetTokens,
                wordBankAllBricks: baseEx.wordBankAllBricks,
                matchingLeftItems: baseEx.matchingLeftItems,
                matchingRightItems: baseEx.matchingRightItems,
                hierarchyCorrectOrder: baseEx.hierarchyCorrectOrder,
                examTip: baseEx.examTip,
                comparisonLeftTitle: baseEx.comparisonLeftTitle,
                comparisonLeftBullets: baseEx.comparisonLeftBullets,
                comparisonRightTitle: baseEx.comparisonRightTitle,
                comparisonRightBullets: baseEx.comparisonRightBullets,
                comparisonGoldenRule: baseEx.comparisonGoldenRule,
                conceptId: cid,
                conceptTitle: cTitle,
                difficulty: 0.58,
                variantGroupId: vGroupId,
                isReviewReplay: false
            )
            pool.append(
                CertiGoAdaptiveQuestion(
                    id: ex2.id,
                    conceptId: cid,
                    conceptTitle: cTitle,
                    difficulty: 0.58,
                    formatCode: ex2.formatCode,
                    variantGroupId: vGroupId,
                    isReviewReplay: false,
                    exercise: ex2
                )
            )

            // Variant 3 (Difficulty 0.82 — Advanced Exam Trap Variant)
            let companionBase = baseExercises.count > 4 ? baseExercises[4 + (idx % max(1, baseExercises.count - 4))] : baseEx
            let v3Options = reassignedPositionalOptionBadges(idx >= 2 ? companionBase.options : baseEx.options)
            let ex3 = CertiGoNativeExerciseItem(
                id: "\(baseEx.id)-v3",
                formatCode: idx >= 2 ? companionBase.formatCode : baseEx.formatCode,
                domainBadge: baseEx.domainBadge,
                subBadge: "PIÈGE D'EXAMEN AVANCÉ · \(upper)",
                prompt: idx >= 2 && companionBase.id != baseEx.id
                    ? companionBase.prompt
                    : rephrasedScenarioPrompt(for: baseEx, routeCode: upper, variantIndex: 3),
                mascotPose: .emotionAhaIdea,
                options: v3Options,
                cliPrefix: idx >= 2 ? companionBase.cliPrefix : baseEx.cliPrefix,
                cliSuffix: idx >= 2 ? companionBase.cliSuffix : baseEx.cliSuffix,
                expectedCLIInput: idx >= 2 ? companionBase.expectedCLIInput : baseEx.expectedCLIInput,
                cliSuggestionBricks: idx >= 2 ? companionBase.cliSuggestionBricks : baseEx.cliSuggestionBricks,
                wordBankTargetTokens: idx >= 2 ? companionBase.wordBankTargetTokens : baseEx.wordBankTargetTokens,
                wordBankAllBricks: idx >= 2 ? companionBase.wordBankAllBricks : baseEx.wordBankAllBricks,
                matchingLeftItems: baseEx.matchingLeftItems,
                matchingRightItems: baseEx.matchingRightItems,
                hierarchyCorrectOrder: baseEx.hierarchyCorrectOrder,
                examTip: baseEx.examTip,
                comparisonLeftTitle: baseEx.comparisonLeftTitle,
                comparisonLeftBullets: baseEx.comparisonLeftBullets,
                comparisonRightTitle: baseEx.comparisonRightTitle,
                comparisonRightBullets: baseEx.comparisonRightBullets,
                comparisonGoldenRule: baseEx.comparisonGoldenRule,
                conceptId: cid,
                conceptTitle: cTitle,
                difficulty: 0.82,
                variantGroupId: vGroupId,
                isReviewReplay: false
            )
            pool.append(
                CertiGoAdaptiveQuestion(
                    id: ex3.id,
                    conceptId: cid,
                    conceptTitle: cTitle,
                    difficulty: 0.82,
                    formatCode: ex3.formatCode,
                    variantGroupId: vGroupId,
                    isReviewReplay: false,
                    exercise: ex3
                )
            )
        }
        return pool
    }
}

/// Interactive lesson session state machine (`Sélection ➔ VÉRIFIER ➔ Bandeau Vert 18 / Rouge 04 ➔ Feuille Explication IA 05 / Comparateur 20 ➔ Célébration 19 / Plus de cœurs 💔`).
public struct CertiGoNativeLessonSessionEngine: Equatable, Sendable {
    public let routeCode: String
    public let lessonId: String
    public let lessonTitle: String
    public var isShowingDeclicCard15: Bool
    public let declicTitle: String
    public let declicDiagramTop: String
    public let declicDiagramBottom: String
    public let declicStep1: String
    public let declicStep2: String
    public let declicRule: String
    public var exercises: [CertiGoNativeExerciseItem]
    public var currentExerciseIndex: Int
    public var attemptPhase: CertiGoExerciseAttemptPhase
    public var selectedOptionIds: Set<String>
    public var cliInputText: String
    public var assembledWordBankTokens: [String]
    public var matchedPairsCount: Int
    public var selectedLeftMatchItem: String?
    public var hierarchyOrderedItems: [String]
    public var heartsCount: Int
    public var lastLostHeartIndex: Int?
    public var heartLossAnimationTrigger: Int
    public var correctAnswersCount: Int
    public var totalVerifiedCount: Int
    public var isSessionCompleted: Bool
    public var hasTriggeredOutOfHeartsFailure: Bool
    public var enableAdaptiveReplay: Bool
    public var adaptiveSessionState: CertiGoAdaptiveSessionState
    public var adaptiveLearnerState: [String: CertiGoLearnerConceptState]

    public var isSessionFailedOutOfHearts: Bool {
        heartsCount <= 0
    }

    public init(
        routeCode: String = "AZ-104",
        lessonId: String = "AZ-104-u1-s1",
        lessonTitle: String = "Concepts Cloud Azure",
        isShowingDeclicCard15: Bool = true,
        exercises: [CertiGoNativeExerciseItem]? = nil,
        heartsCount: Int = 5,
        enableAdaptiveReplay: Bool = false,
        sessionSeed: UInt64 = 1
    ) {
        self.routeCode = routeCode
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.isShowingDeclicCard15 = isShowingDeclicCard15
        let declic = Self.defaultDeclicCard(
            forRouteCode: routeCode,
            lessonId: lessonId,
            lessonTitle: lessonTitle
        )
        self.declicTitle = declic.title
        self.declicDiagramTop = declic.diagramTop
        self.declicDiagramBottom = declic.diagramBottom
        self.declicStep1 = declic.step1
        self.declicStep2 = declic.step2
        self.declicRule = declic.rule
        let resolvedExercises = exercises ?? Self.defaultExercises(
            forRouteCode: routeCode,
            lessonId: lessonId,
            lessonTitle: lessonTitle
        )
        self.exercises = resolvedExercises
        self.currentExerciseIndex = 0
        self.attemptPhase = .answering
        self.selectedOptionIds = []
        self.cliInputText = ""
        self.assembledWordBankTokens = []
        self.matchedPairsCount = 0
        self.selectedLeftMatchItem = nil
        self.hierarchyOrderedItems = resolvedExercises.first?.hierarchyCorrectOrder.reversed() ?? []
        self.heartsCount = heartsCount
        self.lastLostHeartIndex = nil
        self.heartLossAnimationTrigger = 0
        self.correctAnswersCount = 0
        self.totalVerifiedCount = 0
        self.isSessionCompleted = false
        self.hasTriggeredOutOfHeartsFailure = false
        self.enableAdaptiveReplay = enableAdaptiveReplay
        let builtAdaptive = CertiGoAdaptiveSessionEngine.buildInitialSession(
            routeCode: routeCode,
            lessonId: lessonId,
            lessonTitle: lessonTitle,
            sessionSeed: sessionSeed
        )
        self.adaptiveSessionState = builtAdaptive.sessionState
        self.adaptiveLearnerState = builtAdaptive.learnerState
    }

    public var currentExercise: CertiGoNativeExerciseItem {
        guard !exercises.isEmpty else {
            return Self.defaultExercises(
                forRouteCode: routeCode,
                lessonId: lessonId,
                lessonTitle: lessonTitle
            )[0]
        }
        let clamped = min(max(currentExerciseIndex, 0), exercises.count - 1)
        return exercises[clamped]
    }

    public var progressFraction: Double {
        guard !exercises.isEmpty else { return 1.0 }
        if isSessionCompleted { return 1.0 }
        if isShowingDeclicCard15 { return 0.08 }
        let base = Double(currentExerciseIndex) / Double(max(1, exercises.count))
        let bonus: Double = {
            switch attemptPhase {
            case .answering: return 0.15 / Double(max(1, exercises.count))
            case .checked, .explainingError, .comparingServices: return 0.9 / Double(max(1, exercises.count))
            }
        }()
        return min(max(base + bonus, 0.12), 0.98)
    }

    public var conceptMasteryProgressRatio: Double {
        if isSessionCompleted { return 1.0 }
        if isShowingDeclicCard15 { return 0.08 }
        let adaptiveRatio = CertiGoAdaptiveSessionEngine.masteryProgressRatio(
            sessionState: adaptiveSessionState,
            learnerState: adaptiveLearnerState
        )
        return min(max(adaptiveRatio * 0.5 + progressFraction * 0.5, 0.12), 0.98)
    }

    public var conceptMasteryPercent: Int {
        guard !adaptiveSessionState.conceptIds.isEmpty else { return Int((progressFraction * 100.0).rounded()) }
        let sum = adaptiveSessionState.conceptIds.reduce(0.0) { acc, cid in
            acc + (adaptiveLearnerState[cid]?.mastery ?? 0.35)
        }
        return Int((sum / Double(adaptiveSessionState.conceptIds.count) * 100.0).rounded())
    }

    public var canCheckCurrentExercise: Bool {
        let ex = currentExercise
        switch ex.formatCode {
        case "Q_TYPE_04":
            return !cliInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case "Q_TYPE_05":
            return !assembledWordBankTokens.isEmpty
        case "Q_TYPE_06":
            return matchedPairsCount >= ex.matchingLeftItems.count && !ex.matchingLeftItems.isEmpty
        case "Q_TYPE_08":
            return !hierarchyOrderedItems.isEmpty
        case "Q_TYPE_10":
            return !selectedOptionIds.isEmpty
        default:
            return !selectedOptionIds.isEmpty
        }
    }

    public var accuracyPercent: Int {
        guard totalVerifiedCount > 0 else { return 100 }
        return Int((Double(correctAnswersCount) / Double(totalVerifiedCount) * 100.0).rounded())
    }

    public var selectedOptionSummaryText: String {
        let ex = currentExercise
        if ex.formatCode == "Q_TYPE_04" {
            return cliInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if ex.formatCode == "Q_TYPE_05" {
            return assembledWordBankTokens.joined(separator: " ")
        }
        let chosen = ex.options.filter { selectedOptionIds.contains($0.id) }.map(\.title)
        return chosen.isEmpty ? "Réponse incomplète" : chosen.joined(separator: " + ")
    }

    public var selectedWhyWrongExplanation: String {
        let ex = currentExercise
        if let firstChosen = ex.options.first(where: { selectedOptionIds.contains($0.id) }) {
            return firstChosen.whyWrongOrRight
        }
        return "Cette option ne respecte pas le principe du moindre privilège ou l'isolation réseau demandée dans l'énoncé."
    }

    public var correctWhyRightExplanation: String {
        let ex = currentExercise
        if let firstCorrect = ex.options.first(where: \.isCorrect) {
            return firstCorrect.whyWrongOrRight
        }
        return ex.examTip
    }

    public mutating func dismissDeclicCard15() {
        isShowingDeclicCard15 = false
    }

    public mutating func selectOption(_ optionId: String) {
        guard case .answering = attemptPhase else { return }
        if currentExercise.formatCode == "Q_TYPE_10" {
            if selectedOptionIds.contains(optionId) {
                selectedOptionIds.remove(optionId)
            } else {
                selectedOptionIds.insert(optionId)
            }
        } else {
            selectedOptionIds = [optionId]
        }
    }

    public mutating func toggleWordBankBrick(_ brick: String) {
        guard case .answering = attemptPhase else { return }
        if let idx = assembledWordBankTokens.firstIndex(of: brick) {
            assembledWordBankTokens.remove(at: idx)
        } else {
            assembledWordBankTokens.append(brick)
        }
    }

    public mutating func tapMatchingPairItem(left: String?, right: String?) {
        guard case .answering = attemptPhase else { return }
        if let left {
            selectedLeftMatchItem = left
        } else if right != nil, selectedLeftMatchItem != nil {
            matchedPairsCount = min(currentExercise.matchingLeftItems.count, matchedPairsCount + 1)
            selectedLeftMatchItem = nil
        }
    }

    public mutating func moveHierarchyRowUp(at index: Int) {
        guard case .answering = attemptPhase else { return }
        guard index > 0, index < hierarchyOrderedItems.count else { return }
        hierarchyOrderedItems.swapAt(index, index - 1)
    }

    @discardableResult
    public mutating func verifyCurrentAnswer(
        latencyMs: Int = 2_500,
        usedHint: Bool = false,
        now: Date = Date()
    ) -> Bool {
        guard canCheckCurrentExercise else { return false }
        let ex = currentExercise
        let isCorrect: Bool
        switch ex.formatCode {
        case "Q_TYPE_04":
            let trimmed = cliInputText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            isCorrect = trimmed == (ex.expectedCLIInput ?? "lock").lowercased()
        case "Q_TYPE_05":
            isCorrect = assembledWordBankTokens == ex.wordBankTargetTokens
        case "Q_TYPE_06":
            isCorrect = matchedPairsCount >= ex.matchingLeftItems.count
        case "Q_TYPE_08":
            isCorrect = hierarchyOrderedItems == ex.hierarchyCorrectOrder
        case "Q_TYPE_10":
            let expectedSet = Set(ex.options.filter(\.isCorrect).map(\.id))
            isCorrect = selectedOptionIds == expectedSet
        default:
            let expectedSet = Set(ex.options.filter(\.isCorrect).map(\.id))
            isCorrect = selectedOptionIds == expectedSet
        }

        totalVerifiedCount += 1
        if isCorrect {
            correctAnswersCount += 1
            lastLostHeartIndex = nil
        } else {
            let lostIndex = max(0, heartsCount - 1)
            heartsCount = max(0, heartsCount - 1)
            lastLostHeartIndex = lostIndex
            heartLossAnimationTrigger += 1
        }

        CertiGoAdaptiveSessionEngine.recordAnswer(
            sessionState: &adaptiveSessionState,
            learnerState: &adaptiveLearnerState,
            isCorrect: isCorrect,
            latencyMs: latencyMs,
            usedHint: usedHint,
            now: now
        )

        if !isCorrect && enableAdaptiveReplay && exercises.count < 25 {
            let reorderedOptions = ex.options.isEmpty
                ? []
                : CertiGoAdaptiveSessionEngine.reassignedPositionalOptionBadges(Array(ex.options.reversed()))
            let variantIndex = (totalVerifiedCount % 2 == 0) ? 3 : 2
            let replayExercise = CertiGoNativeExerciseItem(
                id: "\(ex.id)-replay-\(totalVerifiedCount)",
                formatCode: ex.formatCode,
                domainBadge: ex.domainBadge,
                subBadge: "🔄 À REVOIR · \(ex.subBadge)",
                prompt: CertiGoAdaptiveSessionEngine.rephrasedScenarioPrompt(
                    for: ex,
                    routeCode: routeCode,
                    variantIndex: variantIndex
                ),
                mascotPose: .emotionAhaIdea,
                options: reorderedOptions,
                cliPrefix: ex.cliPrefix,
                cliSuffix: ex.cliSuffix,
                expectedCLIInput: ex.expectedCLIInput,
                cliSuggestionBricks: ex.cliSuggestionBricks,
                wordBankTargetTokens: ex.wordBankTargetTokens,
                wordBankAllBricks: ex.wordBankAllBricks,
                matchingLeftItems: ex.matchingLeftItems,
                matchingRightItems: ex.matchingRightItems,
                hierarchyCorrectOrder: ex.hierarchyCorrectOrder,
                examTip: ex.examTip,
                comparisonLeftTitle: ex.comparisonLeftTitle,
                comparisonLeftBullets: ex.comparisonLeftBullets,
                comparisonRightTitle: ex.comparisonRightTitle,
                comparisonRightBullets: ex.comparisonRightBullets,
                comparisonGoldenRule: ex.comparisonGoldenRule,
                conceptId: ex.conceptId,
                conceptTitle: ex.conceptTitle,
                difficulty: ex.difficulty,
                variantGroupId: ex.variantGroupId,
                isReviewReplay: true
            )
            let insertAt = min(exercises.count, currentExerciseIndex + 4)
            exercises.insert(replayExercise, at: insertAt)
        }

        attemptPhase = .checked(isCorrect: isCorrect)
        return isCorrect
    }

    public mutating func openErrorExplanationSheet05() {
        attemptPhase = .explainingError
    }

    public mutating func openServiceComparatorSheet20() {
        attemptPhase = .comparingServices
    }

    public mutating func closeOverlaySheetToCheckedState() {
        if case .explainingError = attemptPhase {
            attemptPhase = .checked(isCorrect: false)
        } else if case .comparingServices = attemptPhase {
            let wasCorrect = currentExercise.options
                .filter(\.isCorrect)
                .map(\.id)
                .allSatisfy { selectedOptionIds.contains($0) } && !selectedOptionIds.isEmpty
            attemptPhase = .checked(isCorrect: wasCorrect)
        }
    }

    public mutating func advanceToNextExerciseOrFinish() {
        if isSessionFailedOutOfHearts {
            hasTriggeredOutOfHeartsFailure = true
            isSessionCompleted = false
            return
        }
        if currentExerciseIndex + 1 < exercises.count {
            currentExerciseIndex += 1
            attemptPhase = .answering
            selectedOptionIds = []
            cliInputText = ""
            assembledWordBankTokens = []
            matchedPairsCount = 0
            selectedLeftMatchItem = nil
            hierarchyOrderedItems = Array(currentExercise.hierarchyCorrectOrder.reversed())
        } else {
            isSessionCompleted = true
        }
    }

    public static func defaultDeclicCard(
        forRouteCode routeCode: String,
        lessonId: String = "",
        lessonTitle: String = ""
    ) -> (title: String, diagramTop: String, diagramBottom: String, step1: String, step2: String, rule: String) {
        let upper = routeCode.uppercased()
        let lowerId = lessonId.lowercased()
        switch upper {
        case "PDE", "PCA", "ACE":
            if lowerId.contains("u1-s2") || lowerId.contains("u1-s3") || lessonTitle.lowercased().contains("bigquery") {
                return (
                    title: "Combine Partitionnement par date et Clustering (jusqu'à 4 colonnes) pour diviser la facture BigQuery par 10.",
                    diagramTop: "✕  SELECT * sans filtre  ➔  Full Scan coûteux (To facturés)",
                    diagramBottom: "✓  WHERE event_date = '2026-10-29' AND user_id = 42  ➔  Partition + Cluster Pruning",
                    step1: "1. Partitionne par date d'ingestion ou colonne TIMESTAMP/DATE",
                    step2: "2. Ajoute jusqu'à 4 colonnes de Clustering (ex: customer_id, region) pour accélérer les filtres et agrégations",
                    rule: "BigQuery n'autorise qu'une seule colonne de partitionnement mais jusqu'à 4 colonnes de clustering ordonnées."
                )
            } else if lowerId.contains("u2") || lowerId.contains("u3") {
                return (
                    title: "VPC Service Controls crée un périmètre étanche autour de BigQuery et Cloud Storage contre toute exfiltration.",
                    diagramTop: "✕  Clé IAM compromise hors périmètre  ➔  Accès API bloqué par VPC-SC",
                    diagramBottom: "✓  Projet dans le périmètre VPC-SC + Private Google Access  ➔  Autorisé",
                    step1: "1. Définis un Service Perimeter englobant tes projets sensibles",
                    step2: "2. Active Private Google Access pour accéder aux APIs GCP sans IP externe",
                    rule: "Même avec un rôle Owner ou Storage Admin volé, VPC Service Controls bloque l'exfiltration vers un bucket externe."
                )
            } else {
                return (
                    title: "En streaming serverless sur GCP, associe toujours Cloud Pub/Sub et Cloud Dataflow (Apache Beam).",
                    diagramTop: "✕  Batch cron toutes les 24h  ➔  Latence élevée & doublons non gérés",
                    diagramBottom: "✓  Pub/Sub (Ordering Key + DLQ)  ➔  Dataflow (Windowing + Watermarks)  ➔  BigQuery",
                    step1: "1. Ingère les événements avec Cloud Pub/Sub et configure un Dead-Letter Topic",
                    step2: "2. Utilise les fenêtres (Fixed, Sliding, Session) et Watermarks dans Dataflow pour gérer les données en retard",
                    rule: "Pub/Sub + Dataflow (Apache Beam) + BigQuery est l'architecture de référence Pearson VUE / Kryterion pour le streaming GCP."
                )
            }
        case "AZ-900":
            if lowerId.contains("u1-s2") || lessonTitle.lowercased().contains("région") || lessonTitle.lowercased().contains("sla") {
                return (
                    title: "Distingue toujours Zone de Disponibilité (panne d'un datacenter local) et Paire de Régions (sinistre régional à 300+ miles).",
                    diagramTop: "🏢  Availability Zones : 3 datacenters indépendants dans 1 même Région (SLA 99,99 %)",
                    diagramBottom: "🌍  Region Pairs : 2 Régions distantes de 300+ miles pour la reprise après sinistre (GRS)",
                    step1: "1. Déploie tes VMs sur 2 ou 3 Availability Zones pour survivre à la panne d'un bâtiment",
                    step2: "2. Calcule le SLA composite en multipliant les SLA des briques en série (99,9 % × 99,9 % = 99,80 %)",
                    rule: "Deux services en série réduisent le SLA global (multiplication), tandis qu'une redondance multi-zones l'augmente."
                )
            } else if lowerId.contains("u1-s3") || lowerId.contains("u2") || lowerId.contains("u3") {
                return (
                    title: "RBAC contrôle qui agit, Azure Policy contrôle quoi déployer, et CanNotDelete bloque même un Propriétaire.",
                    diagramTop: "✕  Propriétaire (Owner) tente de supprimer RG-Prod avec verrou CanNotDelete  ➔  Refusé",
                    diagramBottom: "✓  Azure Policy (Emplacements autorisés : Europe)  ➔  Bloque toute ressource hors conformité",
                    step1: "1. Utilise le Calculateur TCO pour comparer ton datacenter On-Premises au Cloud Azure",
                    step2: "2. Utilise le Calculateur de Prix (Pricing Calculator) pour chiffrer tes futures ressources Azure",
                    rule: "Dans le modèle de responsabilité partagée, le client reste TOUJOURS responsable de ses données, identités et appareils."
                )
            } else {
                return (
                    title: "CapEx correspond à l'achat matériel initial, tandis qu'OpEx facture uniquement l'usage réel dans le Cloud.",
                    diagramTop: "✕  CapEx : Acheter des serveurs physiques immobilisés pendant 5 ans",
                    diagramBottom: "✓  OpEx : Payer uniquement les secondes de CPU et Go consommés dans le Cloud",
                    step1: "1. Distingue IaaS (VMs), PaaS (App Service, SQL Database) et SaaS (Microsoft 365)",
                    step2: "2. Retiens que tes Données et tes Identités restent 100 % sous ta responsabilité, même en SaaS",
                    rule: "Plus tu montes vers le SaaS, plus Microsoft gère l'infrastructure ; mais Données, Comptes et Terminaux restent toujours au client."
                )
            }
        case "SAA-C03", "CLF-C02", "AIF-C01":
            return (
                title: "Ne stocke jamais d'Access Key statique sur EC2 : attache un Rôle IAM fournissant des jetons temporaires AWS STS.",
                diagramTop: "✕  AWS_SECRET_ACCESS_KEY en dur dans le code ou sur le disque EC2",
                diagramBottom: "✓  Rôle IAM + AWS STS AssumeRole + Gateway VPC Endpoint S3 gratuit",
                step1: "1. Utilise un Gateway VPC Endpoint (gratuit) pour accéder à S3 et DynamoDB sans passer par un NAT Gateway",
                step2: "2. Choisis ALB (Couche 7 HTTP/HTTPS + AWS WAF) pour le web et NLB (Couche 4 TCP/UDP) pour l'ultra-faible latence",
                rule: "En architecture AWS SAA-C03 : Rôle IAM STS pour les permissions, Gateway Endpoint pour S3/DynamoDB, et RDS Multi-AZ pour la haute disponibilité."
            )
        case "AI-102":
            return (
                title: "Pour un RAG de production dans Azure AI Search, combine Recherche Hybride (BM25 + Vecteurs) et Semantic Ranker L2.",
                diagramTop: "✕  Recherche purement vectorielle  ➔  Rate les références exactes, codes SKU et acronymes",
                diagramBottom: "✓  BM25 (Mots-clés) + Vecteurs (text-embedding-3-large) + RRF + Semantic Ranker",
                step1: "1. Active Azure AI Content Safety (Prompt Shields + Groundedness) pour bloquer le jailbreak et les hallucinations",
                step2: "2. Authentifie ton application vers Azure OpenAI via Managed Identity (Cognitive Services OpenAI User) avec disableLocalAuth: true",
                rule: "Hybrid Search + Reciprocal Rank Fusion (RRF) + Semantic Ranker offre systématiquement le meilleur score de pertinence RAG à l'examen AI-102."
            )
        case "CKA", "CCNA", "TF-003":
            return (
                title: "Dans Kubernetes, tous les pods communiquent par défaut : applique une NetworkPolicy pour isoler tes flux.",
                diagramTop: "✕  Cluster sans NetworkPolicy  ➔  Tout pod compromis atteint la base de données",
                diagramBottom: "✓  NetworkPolicy (podSelector + ingress from frontend)  ➔  Isolation Zero-Trust",
                step1: "1. Utilise Role + RoleBinding pour un namespace unique, et ClusterRole + ClusterRoleBinding à l'échelle du cluster",
                step2: "2. Sauvegarde régulièrement etcd avec ETCDCTL_API=3 etcdctl snapshot save et vérifie readinessProbe vs livenessProbe",
                rule: "readinessProbe retire un pod du Service Endpoints sans le tuer ; livenessProbe redémarre le conteneur en cas de blocage."
            )
        case "GH-300", "CCA-F":
            return (
                title: "Versionne .github/copilot-instructions.md et active le Prompt Caching pour guider tes agents IA.",
                diagramTop: "✕  Répéter manuellement les règles d'architecture à chaque prompt développeur",
                diagramBottom: "✓  .github/copilot-instructions.md + Serveurs MCP typés (input_schema JSON)",
                step1: "1. Définis les conventions d'équipe dans .github/copilot-instructions.md et .github/instructions/*.instructions.md",
                step2: "2. Place cache_control: ephemeral sur les blocs système et définitions d'outils MCP pour réduire la latence de 85 %",
                rule: "Combine instructions versionnées, blocage du code public (Suggestions matching public code = Blocked) et validation JSON Schema sur les outils MCP."
            )
        default:
            if lowerId.contains("u2") {
                return (
                    title: "Créer un Private Endpoint ne désactive pas l'accès public : bloque aussi le pare-feu PaaS.",
                    diagramTop: "✕  Internet Public  ➔  publicNetworkAccess: Disabled",
                    diagramBottom: "✓  VNet (10.0.2.4)  ➔  privatelink.blob.core.windows.net",
                    step1: "1. Passe publicNetworkAccess sur Disabled dans le pare-feu de la ressource PaaS",
                    step2: "2. Lie la zone DNS Privée privatelink.* au VNet via un Virtual Network Link",
                    rule: "Private Endpoint + Zone DNS privatelink.* + publicNetworkAccess: Disabled = isolation PaaS 100 % verrouillée."
                )
            } else if lowerId.contains("u3") {
                return (
                    title: "Pour garantir un accès en lecture immédiat dans la région secondaire pendant une panne, choisis RA-GRS.",
                    diagramTop: "✕  GRS standard  ➔  Pas d'accès lecture sur le secondaire tant que Microsoft ne déclenche pas le failover",
                    diagramBottom: "✓  RA-GRS  ➔  Endpoint secondaire *-secondary.blob.core.windows.net lisible 24/7",
                    step1: "1. Distingue HPA (scale le nombre de pods) et Cluster Autoscaler (scale les nœuds VMSS quand un pod est Pending)",
                    step2: "2. Utilise Azure Site Recovery (ASR) pour la réplication continue de VMs avec RTO en minutes",
                    rule: "Pods en état Pending par manque de CPU/RAM sur le cluster AKS = active le Cluster Autoscaler sur le Node Pool."
                )
            } else {
                return (
                    title: "Un verrou ARM CanNotDelete bloque toute suppression de ressource, même pour un Propriétaire (Owner).",
                    diagramTop: "✕  Rôle Contributor ou Owner accordé à un auditeur externe",
                    diagramBottom: "✓  Rôle Reader (Lecture seule) + Entra ID PIM Just-In-Time + Verrou CanNotDelete",
                    step1: "1. Attribue le rôle Reader pour tout besoin d'audit en lecture seule sans accès aux secrets",
                    step2: "2. Active Microsoft Entra ID PIM pour les élévations temporaires avec MFA et justification",
                    rule: "Un verrou Resource Manager (CanNotDelete / ReadOnly) s'applique au plan de contrôle ARM avant même les permissions RBAC."
                )
            }
        }
    }

    public static func defaultExercises(forRouteCode routeCode: String) -> [CertiGoNativeExerciseItem] {
        defaultExercises(forRouteCode: routeCode, lessonId: "", lessonTitle: "")
    }

    public static func defaultExercises(
        forRouteCode routeCode: String,
        lessonId: String,
        lessonTitle: String = ""
    ) -> [CertiGoNativeExerciseItem] {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let lowerLessonId = lessonId.lowercased()
        let lowerTitle = lessonTitle.lowercased()

        switch upper {
        case "PDE", "PCA", "ACE":
            return googleCloudExercises(routeCode: upper, lowerLessonId: lowerLessonId, lowerTitle: lowerTitle)
        case "AZ-900":
            return az900Exercises(lowerLessonId: lowerLessonId, lowerTitle: lowerTitle)
        case "SAA-C03", "CLF-C02", "AIF-C01":
            return awsExercises(routeCode: upper, lowerLessonId: lowerLessonId, lowerTitle: lowerTitle)
        case "AI-102":
            return ai102Exercises(lowerLessonId: lowerLessonId, lowerTitle: lowerTitle)
        case "CKA", "CCNA", "TF-003":
            return kubernetesAndCloudNativeExercises(routeCode: upper, lowerLessonId: lowerLessonId)
        case "GH-300", "CCA-F":
            return copilotAndClaudeExercises(routeCode: upper, lowerLessonId: lowerLessonId)
        default:
            return az104Exercises(routeCode: upper, lowerLessonId: lowerLessonId, lowerTitle: lowerTitle)
        }
    }

    private static func googleCloudExercises(
        routeCode: String,
        lowerLessonId: String,
        lowerTitle: String
    ) -> [CertiGoNativeExerciseItem] {
        // Lesson 2 / 3 in Unit 1: BigQuery Partitioning, Clustering, Cloud KMS & Vertex AI
        if lowerLessonId.contains("u1-s2") || lowerLessonId.contains("u1-s3") || lowerTitle.contains("bigquery") || lowerTitle.contains("vertex") {
            return [
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-bq-qtype01",
                    formatCode: "Q_TYPE_01",
                    domainBadge: "📊 BIGQUERY · PARTITIONING & CLUSTERING",
                    subBadge: "OPTIMISATION COÛTS & PERFORMANCES SQL",
                    prompt: "Une table BigQuery de 180 To reçoit des événements horodatés. Les analystes filtrent toujours par event_date puis par customer_id et country.\nQuelle conception minimise les octets scannés ?",
                    mascotPose: .poseAnalyst,
                    options: [
                        .init(
                            id: "opt-a",
                            badge: "A",
                            title: "Créer une table par jour (sharding manuel events_YYYYMMDD) sans partitionnement",
                            isCorrect: false,
                            whyWrongOrRight: "Le sharding par tables multiples alourdit les métadonnées et est moins performant que les tables partitionnées natives."
                        ),
                        .init(
                            id: "opt-b",
                            badge: "B",
                            title: "Partitionner par event_date (Time-Unit) et configurer le Clustering sur (customer_id, country)",
                            isCorrect: true,
                            whyWrongOrRight: "Le partitionnement élague les dates non pertinentes et le clustering trie les blocs par customer_id et country (jusqu'à 4 colonnes)."
                        ),
                        .init(
                            id: "opt-c",
                            badge: "C",
                            title: "Exporter toutes les données vers Cloud SQL pour PostgreSQL avec index B-Tree",
                            isCorrect: false,
                            whyWrongOrRight: "Cloud SQL est une base OLTP relationnelle et n'est pas conçue pour l'analyse OLAP de 180 To."
                        ),
                        .init(
                            id: "opt-d",
                            badge: "D",
                            title: "Désactiver le cache de requêtes BigQuery et forcer un scan complet",
                            isCorrect: false,
                            whyWrongOrRight: "Forcer un scan complet sur 180 To maximise les coûts au lieu de les réduire."
                        )
                    ],
                    examTip: "BigQuery supporte 1 colonne de partitionnement (Date/Timestamp ou Integer Range) + jusqu'à 4 colonnes de Clustering.",
                    comparisonLeftTitle: "Partitioning BigQuery",
                    comparisonLeftBullets: [
                        "1 seule colonne (DATE, TIMESTAMP ou Integer)",
                        "Garantit le coût connu AVANT l'exécution (Dry Run)",
                        "Idéal pour la rétention (Partition Expiration)"
                    ],
                    comparisonRightTitle: "Clustering BigQuery",
                    comparisonRightBullets: [
                        "Jusqu'à 4 colonnes (haute cardinalité : user_id, region)",
                        "Re-clustering automatique gratuit en arrière-plan",
                        "Accélère les filtres WHERE et agrégations GROUP BY"
                    ],
                    comparisonGoldenRule: "Combine toujours Partitionnement sur la date + Clustering sur les 1 à 4 colonnes les plus filtrées !"
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-bq-qtype02",
                    formatCode: "Q_TYPE_02",
                    domainBadge: "🔐 CHIFFREMENT CMEK & SERVICES DATA GCP",
                    subBadge: "GRILLE VISUELLE 2×2 · GOOGLE CLOUD",
                    prompt: "Vos datasets BigQuery et buckets Cloud Storage doivent être chiffrés avec des clés gérées par votre entreprise (CMEK).\nQuel service Google Cloud utilisez-vous ?",
                    mascotPose: .specialistSecurityEntra,
                    options: [
                        .init(
                            id: "grid-kms",
                            badge: "A",
                            title: "Cloud KMS",
                            subtitle: "Clés CMEK & HSM FIPS 140-2",
                            assetName: "GCPServices/gcp-key-management-service",
                            isCorrect: true,
                            whyWrongOrRight: "Cloud Key Management Service (KMS) gère les clés CMEK avec rotation automatique et support Cloud HSM."
                        ),
                        .init(
                            id: "grid-bq",
                            badge: "B",
                            title: "BigQuery",
                            subtitle: "Entrepôt analytique Serverless",
                            assetName: "GCPServices/gcp-bigquery",
                            isCorrect: false,
                            whyWrongOrRight: "BigQuery consomme la clé CMEK depuis Cloud KMS mais n'est pas le gestionnaire de clés cryptographiques."
                        ),
                        .init(
                            id: "grid-vertex",
                            badge: "C",
                            title: "Vertex AI",
                            subtitle: "Entraînement & MLOps IA",
                            assetName: "GCPServices/gcp-vertexai",
                            isCorrect: false,
                            whyWrongOrRight: "Vertex AI est la plateforme d'IA générative et de Machine Learning de Google Cloud."
                        ),
                        .init(
                            id: "grid-dataproc",
                            badge: "D",
                            title: "Cloud Dataproc",
                            subtitle: "Clusters Spark & Hadoop managés",
                            assetName: "GCPServices/gcp-dataproc",
                            isCorrect: false,
                            whyWrongOrRight: "Dataproc exécute des jobs Apache Spark/Hadoop managés, pas la gestion de clés HSM."
                        )
                    ],
                    examTip: "CMEK = Customer-Managed Encryption Keys dans Cloud KMS ; CSEK = Customer-Supplied Encryption Keys fournies à chaque appel API."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-bq-qtype03",
                    formatCode: "Q_TYPE_03",
                    domainBadge: "🧠 PIPELINE ANALYTIQUE & ML GCP",
                    subBadge: "SCHÉMA INTERACTIF · [ Cloud Storage ] ➔ [ ? ] ➔ [ Vertex AI ]",
                    prompt: "Vos analystes souhaitent entraîner un modèle de détection de fraude directement en SQL standard avant de l'exposer dans Vertex AI.\nQuelle brique placer dans [ ? ] ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "arch-bqml",
                            badge: "A",
                            title: "BigQuery ML (CREATE MODEL en SQL Standard)",
                            subtitle: "Entraînement ML in-database sans déplacer les données",
                            assetName: "GCPServices/gcp-bigquery",
                            isCorrect: true,
                            whyWrongOrRight: "BigQuery ML entraîne des modèles XGBoost, DNN ou ARIMA directement en SQL sur les tables BigQuery et s'intègre à Vertex AI."
                        ),
                        .init(
                            id: "arch-armor",
                            badge: "B",
                            title: "Google Cloud Armor",
                            subtitle: "Protection DDoS & pare-feu WAF",
                            assetName: "GCPServices/gcp-cloud-armor",
                            isCorrect: false,
                            whyWrongOrRight: "Cloud Armor protège le Load Balancer HTTP(S) contre les attaques DDoS et OWASP."
                        ),
                        .init(
                            id: "arch-spanner",
                            badge: "C",
                            title: "Cloud Spanner",
                            subtitle: "Base relationnelle transactionnelle globale",
                            assetName: "GCPServices/gcp-cloud-spanner",
                            isCorrect: false,
                            whyWrongOrRight: "Cloud Spanner est une base OLTP distribuée globalement, pas le moteur d'entraînement SQL analytique."
                        )
                    ],
                    examTip: "Besoin d'entraîner rapidement un modèle ML par des analystes SQL sans sortir les données de l'entrepôt = BigQuery ML."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-bq-qtype04",
                    formatCode: "Q_TYPE_04",
                    domainBadge: "⌨️ CLI BIGQUERY (BQ)",
                    subBadge: "SAISIE CLAVIER CLI · DRY RUN & SQL STANDARD",
                    prompt: "Vous devez estimer à l'avance le volume d'octets facturés par une requête SQL standard dans BigQuery.\nQuelle sous-commande de l'outil CLI bq complétez-vous ?",
                    mascotPose: .poseCLICoder,
                    options: [
                        .init(
                            id: "cli-bq-query",
                            badge: "CLI",
                            title: "query",
                            isCorrect: true,
                            whyWrongOrRight: "La commande exacte est « bq query --use_legacy_sql=false --dry_run 'SELECT ...' »."
                        )
                    ],
                    cliPrefix: "bq",
                    cliSuffix: "--use_legacy_sql=false --dry_run 'SELECT * FROM prod.events'",
                    expectedCLIInput: "query",
                    cliSuggestionBricks: ["query", "mk", "load", "extract"],
                    examTip: "Utilise toujours --dry_run avec bq query pour valider la requête et connaître le volume d'octets facturés sans exécuter le job."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-bq-qtype05",
                    formatCode: "Q_TYPE_05",
                    domainBadge: "🧱 CONSTRUCTEUR CLI BIGQUERY",
                    subBadge: "ASSEMBLAGE DE BRIQUES · TABLE PARTITIONNÉE",
                    prompt: "Vous initialisez le dataset analytique analytics en ligne de commande.\nAssemble dans l'ordre la commande bq pour créer une table partitionnée par date :",
                    mascotPose: .specialistCLIContainers,
                    options: [],
                    wordBankTargetTokens: ["bq", "mk", "--table", "--time_partitioning_field=event_date", "analytics.events"],
                    wordBankAllBricks: ["bq", "mk", "--table", "--time_partitioning_field=event_date", "analytics.events", "rm", "--force"],
                    examTip: "La commande bq mk --table --time_partitioning_field=<col> --clustering_fields=<c1,c2> crée une table optimisée."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-bq-qtype10",
                    formatCode: "Q_TYPE_10",
                    domainBadge: "☑️ CHOIX MULTIPLES · SÉCURITÉ BIGQUERY",
                    subBadge: "COCHE LES 2 BONNES PRATIQUES GOOGLE CLOUD",
                    prompt: "Vous devez restreindre l'accès d'une table BigQuery contenant des salaires RH à la fois au niveau des lignes (par pays) et des colonnes (masquage du numéro de sécurité sociale).\nQuelles sont les 2 fonctionnalités natives à combiner ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "m-1",
                            badge: "1",
                            title: "Créer une Row-Level Security Policy (CREATE ROW ACCESS POLICY) filtrée sur SESSION_USER()",
                            isCorrect: true,
                            whyWrongOrRight: "Row-Level Security filtre dynamiquement les lignes visibles selon le groupe ou l'identité IAM."
                        ),
                        .init(
                            id: "m-2",
                            badge: "2",
                            title: "Appliquer des Policy Tags Data Catalog avec Dynamic Data Masking au niveau des colonnes",
                            isCorrect: true,
                            whyWrongOrRight: "Les Policy Tags permettent le contrôle d'accès par colonne et le masquage dynamique (SHA-256 / NULL)."
                        ),
                        .init(
                            id: "m-3",
                            badge: "3",
                            title: "Donner le rôle roles/bigquery.admin à tous les analystes de l'entreprise",
                            isCorrect: false,
                            whyWrongOrRight: "Le rôle bigquery.admin donne un accès complet et viole le principe du moindre privilège."
                        ),
                        .init(
                            id: "m-4",
                            badge: "4",
                            title: "Rendre le dataset public à allAuthenticatedUsers",
                            isCorrect: false,
                            whyWrongOrRight: "allAuthenticatedUsers expose le dataset à n'importe quel compte Google sur Internet !"
                        )
                    ],
                    examTip: "Sécurité fine BigQuery = Row Access Policies (lignes) + Data Catalog Policy Tags (colonnes & masquage)."
                )
            ]
        }

        // Unit 2 / Unit 3: GCP Security, VPC Service Controls, Cloud Armor & GKE
        if lowerLessonId.contains("u2") || lowerLessonId.contains("u3") {
            return [
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-sec-qtype01",
                    formatCode: "Q_TYPE_01",
                    domainBadge: "🛡️ VPC SERVICE CONTROLS & IAM GCP",
                    subBadge: "ANTI-EXFILTRATION · PÉRIMÈTRE DE SÉCURITÉ",
                    prompt: "Un compte de service disposant de droits IAM valides tente de copier des tables BigQuery confidentielles vers un bucket externe.\nComment bloquer toute exfiltration hors de votre organisation ?",
                    mascotPose: .specialistSecurityEntra,
                    options: [
                        .init(
                            id: "opt-a",
                            badge: "A",
                            title: "Configurer un périmètre VPC Service Controls autour du projet contenant BigQuery et Cloud Storage",
                            isCorrect: true,
                            whyWrongOrRight: "VPC Service Controls crée une frontière de sécurité au niveau des APIs Google Cloud qui bloque toute copie vers l'extérieur du périmètre."
                        ),
                        .init(
                            id: "opt-b",
                            badge: "B",
                            title: "Ouvrir le port TCP 22 (SSH) à 0.0.0.0/0 dans les règles de pare-feu VPC",
                            isCorrect: false,
                            whyWrongOrRight: "Ouvrir SSH à Internet augmente la surface d'attaque et n'affecte pas les appels API BigQuery."
                        ),
                        .init(
                            id: "opt-c",
                            badge: "C",
                            title: "Remplacer BigQuery par des disques persistants non chiffrés",
                            isCorrect: false,
                            whyWrongOrRight: "Tous les disques GCP sont chiffrés par défaut et cela ne protège pas contre l'exfiltration API."
                        ),
                        .init(
                            id: "opt-d",
                            badge: "D",
                            title: "Désactiver Cloud Audit Logs sur l'organisation",
                            isCorrect: false,
                            whyWrongOrRight: "Désactiver les journaux d'audit supprime la traçabilité sans empêcher l'exfiltration."
                        )
                    ],
                    examTip: "À l'examen Google Cloud (PDE / PCA / ACE), « prévenir l'exfiltration de données vers un projet externe » = VPC Service Controls."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-sec-qtype02",
                    formatCode: "Q_TYPE_02",
                    domainBadge: "☁️ CONTENEURS & SÉCURITÉ RÉSEAU GCP",
                    subBadge: "GRILLE VISUELLE 2×2 · SERVICES GOOGLE CLOUD",
                    prompt: "Votre équipe souhaite exécuter des clusters Kubernetes où Google provisionne, sécurise et dimensionne les nœuds facturés au pod.\nQuel service choisissez-vous ?",
                    mascotPose: .specialistCLIContainers,
                    options: [
                        .init(
                            id: "grid-gke",
                            badge: "A",
                            title: "GKE Autopilot",
                            subtitle: "Kubernetes managé sans gestion de nœuds",
                            assetName: "GCPServices/gcp-google-kubernetes-engine",
                            isCorrect: true,
                            whyWrongOrRight: "GKE Autopilot gère l'intégralité du plan de contrôle et des nœuds worker en facturant uniquement les requêtes CPU/RAM des pods."
                        ),
                        .init(
                            id: "grid-armor",
                            badge: "B",
                            title: "Cloud Armor",
                            subtitle: "Protection DDoS & WAF Couche 7",
                            assetName: "GCPServices/gcp-cloud-armor",
                            isCorrect: false,
                            whyWrongOrRight: "Cloud Armor est le pare-feu WAF/DDoS adossé au Global External Application Load Balancer."
                        ),
                        .init(
                            id: "grid-pubsub",
                            badge: "C",
                            title: "Cloud Pub/Sub",
                            subtitle: "Bus de messagerie asynchrone",
                            assetName: "GCPServices/gcp-pubsub",
                            isCorrect: false,
                            whyWrongOrRight: "Cloud Pub/Sub est un service d'ingestion de messages événementiels, pas un orchestrateur de conteneurs."
                        ),
                        .init(
                            id: "grid-gcs",
                            badge: "D",
                            title: "Cloud Storage",
                            subtitle: "Stockage objet Standard / Coldline",
                            assetName: "GCPServices/gcp-cloud-storage",
                            isCorrect: false,
                            whyWrongOrRight: "Cloud Storage est le stockage objet binaire de Google Cloud."
                        )
                    ],
                    examTip: "Moins de charge opérationnelle K8s + sécurité durcie par défaut = GKE Autopilot."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-sec-qtype03",
                    formatCode: "Q_TYPE_03",
                    domainBadge: "🌐 PROTECTION WAF & LOAD BALANCING GCP",
                    subBadge: "SCHÉMA INTERACTIF · [ 🌐 Clients ] ➔ [ ? ] ➔ [ Cloud Run / GKE ]",
                    prompt: "Vos APIs sont exposées derrière un Global HTTP(S) Load Balancer.\nQuelle brique placer en [ ? ] pour bloquer les attaques SQLi/XSS OWASP et filtrer par pays ?",
                    mascotPose: .specialistNetworkVNet,
                    options: [
                        .init(
                            id: "arch-armor",
                            badge: "A",
                            title: "Google Cloud Armor (Security Policies WAF)",
                            subtitle: "Règles préconfigurées OWASP Top 10 & Adaptive Protection",
                            assetName: "GCPServices/gcp-cloud-armor",
                            isCorrect: true,
                            whyWrongOrRight: "Cloud Armor s'attache aux Backend Services du Load Balancer pour filtrer les attaques L7 et DDoS en bordure Google."
                        ),
                        .init(
                            id: "arch-dataproc",
                            badge: "B",
                            title: "Cloud Dataproc",
                            subtitle: "Traitement Big Data Spark/Hadoop",
                            assetName: "GCPServices/gcp-dataproc",
                            isCorrect: false,
                            whyWrongOrRight: "Dataproc traite des jobs analytiques Spark/Hadoop et ne filtre pas le trafic HTTP."
                        ),
                        .init(
                            id: "arch-pubsub",
                            badge: "C",
                            title: "Cloud Pub/Sub",
                            subtitle: "File de messages asynchrone",
                            assetName: "GCPServices/gcp-pubsub",
                            isCorrect: false,
                            whyWrongOrRight: "Pub/Sub est un bus de messagerie interne, pas un pare-feu d'application web."
                        )
                    ],
                    examTip: "Protection WAF OWASP + DDoS sur Google Cloud = Google Cloud Armor."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-sec-qtype04",
                    formatCode: "Q_TYPE_04",
                    domainBadge: "⌨️ GCLOUD CLI & GKE",
                    subBadge: "SAISIE CLAVIER CLI · CLUSTER KUBERNETES",
                    prompt: "Vous provisionnez le cluster GKE Autopilot prod-cluster en ligne de commande.\nComplète la sous-commande gcloud container :",
                    mascotPose: .poseCLICoder,
                    options: [
                        .init(
                            id: "cli-clusters",
                            badge: "CLI",
                            title: "clusters",
                            isCorrect: true,
                            whyWrongOrRight: "La commande exacte est « gcloud container clusters create-auto prod-cluster --region=europe-west1 »."
                        )
                    ],
                    cliPrefix: "gcloud container",
                    cliSuffix: "create-auto prod-cluster --region=europe-west1",
                    expectedCLIInput: "clusters",
                    cliSuggestionBricks: ["clusters", "subnets", "instances", "policies"],
                    examTip: "gcloud container clusters create-auto déploie directement un cluster GKE en mode Autopilot."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-sec-qtype05",
                    formatCode: "Q_TYPE_05",
                    domainBadge: "🧱 CONSTRUCTEUR GCLOUD IAM",
                    subBadge: "ASSEMBLAGE DE BRIQUES · MOINDRE PRIVILÈGE",
                    prompt: "Un analyste doit consulter les tables du projet analytics-prod en lecture seule.\nAssemble dans l'ordre la commande gcloud IAM :",
                    mascotPose: .specialistCLIContainers,
                    options: [],
                    wordBankTargetTokens: ["gcloud", "projects", "add-iam-policy-binding", "analytics-prod", "--role=roles/bigquery.dataViewer"],
                    wordBankAllBricks: ["gcloud", "projects", "add-iam-policy-binding", "analytics-prod", "--role=roles/bigquery.dataViewer", "delete", "--all"],
                    examTip: "Utilise des rôles prédéfinis granulaires (roles/bigquery.dataViewer) plutôt que des rôles basiques (Owner/Editor)."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-sec-qtype10",
                    formatCode: "Q_TYPE_10",
                    domainBadge: "☑️ CHOIX MULTIPLES · WORKLOAD IDENTITY GKE",
                    subBadge: "COCHE LES 2 BONNES PRATIQUES D'AUTHENTIFICATION",
                    prompt: "Un pod sur GKE doit lire des objets dans Cloud Storage sans exporter de fichier JSON de clé de compte de service.\nQuelles sont les 2 actions recommandées par Google Cloud ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "m-1",
                            badge: "1",
                            title: "Activer Workload Identity Federation for GKE sur le cluster",
                            isCorrect: true,
                            whyWrongOrRight: "Workload Identity fédère le Kubernetes ServiceAccount avec un IAM ServiceAccount sans clé statique."
                        ),
                        .init(
                            id: "m-2",
                            badge: "2",
                            title: "Lier le Kubernetes ServiceAccount au Google IAM ServiceAccount ayant roles/storage.objectViewer",
                            isCorrect: true,
                            whyWrongOrRight: "L'annotation et le binding iam.workloadIdentityUser accordent uniquement la lecture d'objets au pod."
                        ),
                        .init(
                            id: "m-3",
                            badge: "3",
                            title: "Commiter une clé privée JSON de Service Account dans le dépôt Git",
                            isCorrect: false,
                            whyWrongOrRight: "Les clés JSON exportées ont une durée de vie longue et présentent un risque critique de fuite."
                        ),
                        .init(
                            id: "m-4",
                            badge: "4",
                            title: "Donner le rôle Owner au Compute Engine default service account du nœud",
                            isCorrect: false,
                            whyWrongOrRight: "Tous les pods du nœud hériteraient des droits Owner, violant le moindre privilège."
                        )
                    ],
                    examTip: "Pod GKE vers API Google Cloud = Workload Identity (jamais de clé JSON téléchargée)."
                )
            ]
        }

        // Default / Lesson 1 (`u1-s1`): Cloud Pub/Sub, Dataflow (Apache Beam), Windowing/Watermarks & Cloud Storage
        return [
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype01",
                formatCode: "Q_TYPE_01",
                domainBadge: "⚡ CLOUD PUB/SUB & STREAMING GCP",
                subBadge: "INGESTION TEMPS RÉEL · ORDRE & DEAD-LETTER",
                prompt: "Votre pipeline \(routeCode) ingère des transactions financières via Cloud Pub/Sub. Les messages d'un même compte client doivent être traités dans l'ordre exact d'émission et les messages en échec répété isolés.\nQue configurez-vous ?",
                mascotPose: .poseAnalyst,
                options: [
                    .init(
                        id: "opt-a",
                        badge: "A",
                        title: "Créer un fichier CSV sur un disque local Compute Engine",
                        isCorrect: false,
                        whyWrongOrRight: "Un disque local ne fournit ni ingestion distribuée Pub/Sub ni gestion automatique des rejets."
                    ),
                    .init(
                        id: "opt-b",
                        badge: "B",
                        title: "Activer Message Ordering avec une ordering_key par compte + configurer un Dead-Letter Topic",
                        isCorrect: true,
                        whyWrongOrRight: "Cloud Pub/Sub garantit l'ordre de livraison par ordering_key et route les messages non acquittés vers le Dead-Letter Topic après max_delivery_attempts."
                    ),
                    .init(
                        id: "opt-c",
                        badge: "C",
                        title: "Désactiver les accusés de réception (ACK) sur l'abonnement Pub/Sub",
                        isCorrect: false,
                        whyWrongOrRight: "Sans ACK, Pub/Sub réexpédie indéfiniment tous les messages jusqu'à expiration."
                    ),
                    .init(
                        id: "opt-d",
                        badge: "D",
                        title: "Utiliser Cloud DNS pour stocker les transactions en attente",
                        isCorrect: false,
                        whyWrongOrRight: "Cloud DNS est un service de résolution de noms de domaine, pas un bus de messagerie."
                    )
                ],
                examTip: "Dans Cloud Pub/Sub : même ordering_key = ordre garanti par clé ; Dead-Letter Topic = isolation des messages « poison ».",
                comparisonLeftTitle: "Cloud Pub/Sub",
                comparisonLeftBullets: [
                    "Ingestion globale asynchrone (At-least-once)",
                    "Supporte Ordering Keys & Dead-Letter Topics",
                    "Découple les producteurs IoT/Apps de Dataflow"
                ],
                comparisonRightTitle: "Cloud Dataflow (Beam)",
                comparisonRightBullets: [
                    "Moteur de traitement unifié Streaming & Batch",
                    "Gère Windowing (Fixed, Sliding, Session) & Watermarks",
                    "Autoscaling horizontal + Dynamic Work Rebalancing"
                ],
                comparisonGoldenRule: "Pub/Sub ingère et découple les événements ; Dataflow les transforme avec fenêtrage temporel avant écriture dans BigQuery !"
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype02",
                formatCode: "Q_TYPE_02",
                domainBadge: "🌊 ARCHITECTURE DATA & IA GOOGLE CLOUD",
                subBadge: "GRILLE VISUELLE 2×2 · SERVICES OFFICIELS GCP",
                prompt: "Vous devez exécuter des pipelines Apache Beam en streaming et en batch de façon 100 % serverless avec autoscaling.\nQuel service Google Cloud choisissez-vous ?",
                mascotPose: .specialistCLIContainers,
                options: [
                    .init(
                        id: "grid-dataflow",
                        badge: "A",
                        title: "Cloud Dataflow",
                        subtitle: "Apache Beam Streaming & Batch",
                        assetName: "GCPServices/gcp-dataflow",
                        isCorrect: true,
                        whyWrongOrRight: "Cloud Dataflow est le service managé sans serveur pour exécuter les pipelines Apache Beam avec autoscaling et gestion des watermarks."
                    ),
                    .init(
                        id: "grid-pubsub",
                        badge: "B",
                        title: "Cloud Pub/Sub",
                        subtitle: "Messagerie événementielle globale",
                        assetName: "GCPServices/gcp-pubsub",
                        isCorrect: false,
                        whyWrongOrRight: "Cloud Pub/Sub transporte les messages en temps réel mais n'exécute pas les transformations Apache Beam."
                    ),
                    .init(
                        id: "grid-bigquery",
                        badge: "C",
                        title: "BigQuery",
                        subtitle: "Data Warehouse SQL analytique",
                        assetName: "GCPServices/gcp-bigquery",
                        isCorrect: false,
                        whyWrongOrRight: "BigQuery est l'entrepôt de données analytique SQL où Dataflow déverse les résultats."
                    ),
                    .init(
                        id: "grid-gcs",
                        badge: "D",
                        title: "Cloud Storage",
                        subtitle: "Data Lake objet multi-classes",
                        assetName: "GCPServices/gcp-cloud-storage",
                        isCorrect: false,
                        whyWrongOrRight: "Cloud Storage stocke les fichiers bruts (Parquet/Avro) du Data Lake."
                    )
                ],
                examTip: "Apache Beam + Streaming Serverless + Windowing/Watermarks = Cloud Dataflow."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype03",
                formatCode: "Q_TYPE_03",
                domainBadge: "🔄 PIPELINE TEMPS RÉEL GOOGLE CLOUD",
                subBadge: "SCHÉMA INTERACTIF · [ Pub/Sub ] ➔ [ ? ] ➔ [ BigQuery ]",
                prompt: "Vous devez agréger des clics utilisateurs par sessions d'inactivité de 30 minutes tout en gérant les événements arrivés en retard.\nQuelle brique placer dans [ ? ] ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "arch-dataflow",
                        badge: "A",
                        title: "Cloud Dataflow (Session Windows + Watermarks + Triggers)",
                        subtitle: "Fenêtrage par session dynamique et gestion du Late Data",
                        assetName: "GCPServices/gcp-dataflow",
                        isCorrect: true,
                        whyWrongOrRight: "Les Session Windows d'Apache Beam regroupent les événements par utilisateur avec gap d'inactivité, et les Watermarks/Triggers gèrent les retards."
                    ),
                    .init(
                        id: "arch-dataproc",
                        badge: "B",
                        title: "Cloud Dataproc (Job Hadoop MapReduce Batch)",
                        subtitle: "Traitement par lots sur clusters HDFS",
                        assetName: "GCPServices/gcp-dataproc",
                        isCorrect: false,
                        whyWrongOrRight: "Hadoop MapReduce est conçu pour le traitement batch et non pour le fenêtrage de sessions temps réel sans serveur."
                    ),
                    .init(
                        id: "arch-armor",
                        badge: "C",
                        title: "Google Cloud Armor",
                        subtitle: "Protection WAF & DDoS",
                        assetName: "GCPServices/gcp-cloud-armor",
                        isCorrect: false,
                        whyWrongOrRight: "Cloud Armor est un pare-feu web et non un moteur de traitement de flux."
                    )
                ],
                examTip: "Activité utilisateur séparée par une période d'inactivité = Session Windows dans Cloud Dataflow."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype04",
                formatCode: "Q_TYPE_04",
                domainBadge: "⌨️ GCLOUD CLI & PUB/SUB",
                subBadge: "SAISIE CLAVIER CLI · ABONNEMENT STREAMING",
                prompt: "Vous raccordez un consommateur au topic Pub/Sub orders-topic.\nComplète la commande gcloud pubsub pour créer l'abonnement sub-orders :",
                mascotPose: .poseCLICoder,
                options: [
                    .init(
                        id: "cli-subs",
                        badge: "CLI",
                        title: "subscriptions",
                        isCorrect: true,
                        whyWrongOrRight: "La commande exacte est « gcloud pubsub subscriptions create sub-orders --topic=orders-topic »."
                    )
                ],
                cliPrefix: "gcloud pubsub",
                cliSuffix: "create sub-orders --topic=orders-topic",
                expectedCLIInput: "subscriptions",
                cliSuggestionBricks: ["subscriptions", "topics", "snapshots", "schemas"],
                examTip: "Un topic Pub/Sub peut avoir plusieurs subscriptions (pattern Fan-out : 1 producteur -> N consommateurs indépendants)."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype05",
                formatCode: "Q_TYPE_05",
                domainBadge: "🧱 CONSTRUCTEUR CLI DATAFLOW",
                subBadge: "ASSEMBLAGE DE BRIQUES · DÉPLOIEMENT PIPELINE",
                prompt: "Vous déployez le pipeline streaming iot-stream dans la région europe-west1.\nAssemble dans l'ordre les briques gcloud :",
                mascotPose: .specialistCLIContainers,
                options: [],
                wordBankTargetTokens: ["gcloud", "dataflow", "jobs", "run", "iot-stream", "--region=europe-west1"],
                wordBankAllBricks: ["gcloud", "dataflow", "jobs", "run", "iot-stream", "--region=europe-west1", "delete", "--zone=us"],
                examTip: "gcloud dataflow jobs run ou flex-template run déploie un pipeline Apache Beam managé dans la région choisie."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype10",
                formatCode: "Q_TYPE_10",
                domainBadge: "☑️ CHOIX MULTIPLES · CYCLE DE VIE CLOUD STORAGE",
                subBadge: "COCHE LES 2 ACTIONS D'OPTIMISATION FINOPS GCP",
                prompt: "Votre Data Lake Cloud Storage contient 500 To de fichiers journaux bruts rarement consultés après 30 jours, mais qui doivent être conservés 5 ans pour conformité légale.\nQuelles sont les 2 actions recommandées ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "m-1",
                        badge: "1",
                        title: "Configurer une règle Object Lifecycle Management SetStorageClass vers Coldline (30j) puis Archive (365j)",
                        isCorrect: true,
                        whyWrongOrRight: "Object Lifecycle Management automatise la transition sans code de Standard vers Nearline/Coldline/Archive."
                    ),
                    .init(
                        id: "m-2",
                        badge: "2",
                        title: "Activer une Retention Policy (Bucket Lock) pour garantir la conservation légale immuable",
                            isCorrect: true,
                        whyWrongOrRight: "Bucket Lock empêche toute suppression ou modification d'objet avant l'expiration de la période légale."
                    ),
                    .init(
                        id: "m-3",
                        badge: "3",
                        title: "Copier les 500 To dans la mémoire RAM d'une instance Compute Engine",
                        isCorrect: false,
                        whyWrongOrRight: "Stocker 500 To d'archives en RAM serait hors de prix et volatile."
                    ),
                    .init(
                        id: "m-4",
                        badge: "4",
                        title: "Supprimer tous les buckets chaque semaine via un script manuel",
                        isCorrect: false,
                        whyWrongOrRight: "Supprimer les archives violerait l'obligation légale de conservation de 5 ans."
                    )
                ],
                examTip: "Cloud Storage Lifecycle Management + Retention Policy (Bucket Lock) = archivage FinOps et conformité WORM."
            )
        ]
    }

    private static func az900Exercises(
        lowerLessonId: String,
        lowerTitle: String
    ) -> [CertiGoNativeExerciseItem] {
        // Lesson 2: Regions, Availability Zones & SLA
        if lowerLessonId.contains("u1-s2") || lowerTitle.contains("région") || lowerTitle.contains("sla") {
            return [
                CertiGoNativeExerciseItem(
                    id: "az-900-sla-qtype01",
                    formatCode: "Q_TYPE_01",
                    domainBadge: "🌍 ZONES DE DISPONIBILITÉ & HAUTE DISPONIBILITÉ",
                    subBadge: "FONDAMENTAUX AZ-900 · INFRASTRUCTURE MONDIALE",
                    prompt: "Vos applications critiques doivent survivre à la panne électrique ou réseau d'un centre de données physique entier au sein d'une même région.\nQuelle fonctionnalité Azure activez-vous ?",
                    mascotPose: .specialistCloudAzure,
                    options: [
                        .init(
                            id: "opt-a",
                            badge: "A",
                            title: "Les Groupes de Ressources (Resource Groups)",
                            isCorrect: false,
                            whyWrongOrRight: "Un groupe de ressources est un conteneur logique de métadonnées et n'offre aucune redondance physique."
                        ),
                        .init(
                            id: "opt-b",
                            badge: "B",
                            title: "Les Zones de Disponibilité (Availability Zones — 3 datacenters indépendants)",
                            isCorrect: true,
                            whyWrongOrRight: "Chaque Availability Zone possède son propre bâtiment, alimentation, refroidissement et réseau isolé."
                        ),
                        .init(
                            id: "opt-c",
                            badge: "C",
                            title: "Les étiquettes de facturation (Resource Tags)",
                            isCorrect: false,
                            whyWrongOrRight: "Les tags servent uniquement à l'organisation logique et à la répartition FinOps des coûts."
                        ),
                        .init(
                            id: "opt-d",
                            badge: "D",
                            title: "Azure Cloud Shell",
                            isCorrect: false,
                            whyWrongOrRight: "Cloud Shell est un terminal d'administration dans le navigateur."
                        )
                    ],
                    examTip: "Panne d'un datacenter = Availability Zones (ZRS). Catastrophe touchant toute une région = Region Pairs (GRS)."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-sla-qtype02",
                    formatCode: "Q_TYPE_02",
                    domainBadge: "🛡️ RÉSILIENCE & RÉPLICATION AZURE",
                    subBadge: "GRILLE VISUELLE 2×2 · SERVICES AZ-900",
                    prompt: "Vous déployez plusieurs machines virtuelles saines dans différentes Zones de Disponibilité.\nQuel service répartit automatiquement le trafic entrant entre elles ?",
                    mascotPose: .specialistNetworkVNet,
                    options: [
                        .init(
                            id: "grid-lb",
                            badge: "A",
                            title: "Load Balancer",
                            subtitle: "Répartition de charge haute dispo",
                            assetName: "AzureServices/Load-Balancers",
                            isCorrect: true,
                            whyWrongOrRight: "Azure Load Balancer Standard distribue le trafic entre plusieurs VMs multi-zones avec sondes de santé (Health Probes)."
                        ),
                        .init(
                            id: "grid-kv",
                            badge: "B",
                            title: "Key Vault",
                            subtitle: "Coffre de secrets & clés",
                            assetName: "AzureServices/Key-Vaults",
                            isCorrect: false,
                            whyWrongOrRight: "Key Vault stocke des secrets et certificats mais ne répartit pas le trafic réseau."
                        ),
                        .init(
                            id: "grid-policy",
                            badge: "C",
                            title: "Azure Policy",
                            subtitle: "Règles de conformité ARM",
                            assetName: "AzureServices/Policy",
                            isCorrect: false,
                            whyWrongOrRight: "Azure Policy vérifie la conformité des ressources lors du déploiement."
                        ),
                        .init(
                            id: "grid-advisor",
                            badge: "D",
                            title: "Azure Advisor",
                            subtitle: "Recommandations d'optimisation",
                            assetName: "AzureServices/Advisor",
                            isCorrect: false,
                            whyWrongOrRight: "Azure Advisor fournit des recommandations mais n'est pas un équilibreur de charge."
                        )
                    ],
                    examTip: "Load Balancer Standard Zone-Redundant garantit un SLA de 99,99 % sur au moins 2 VMs réparties en Availability Zones."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-sla-qtype03",
                    formatCode: "Q_TYPE_03",
                    domainBadge: "📐 CALCUL DE SLA COMPOSITE AZ-900",
                    subBadge: "SCHÉMA INTERACTIF · [ Web App 99,9 % ] ➔ [ ? ] ➔ [ SQL DB 99,9 % ]",
                    prompt: "Une application web repose obligatoirement sur Azure App Service (SLA 99,9 %) ET Azure SQL Database (SLA 99,9 %) en série.\nQuel est le SLA composite résultant ?",
                    mascotPose: .poseAnalyst,
                    options: [
                        .init(
                            id: "arch-sla-9980",
                            badge: "A",
                            title: "99,80 % (99,9 % × 99,9 %)",
                            subtitle: "Produit des probabilités de disponibilité en série",
                            assetName: "AzureServices/App-Services",
                            isCorrect: true,
                            whyWrongOrRight: "Lorsque deux composants sont requis simultanément, le SLA composite est le produit : 0,999 × 0,999 = 0,998001 (99,80 %)."
                        ),
                        .init(
                            id: "arch-sla-9990",
                            badge: "B",
                            title: "99,90 % (moyenne des deux SLA)",
                            subtitle: "Ne tient pas compte du cumul des risques de panne",
                            assetName: "AzureServices/Monitor",
                            isCorrect: false,
                            whyWrongOrRight: "Le SLA composite de deux briques en série est toujours inférieur au SLA le plus faible."
                        ),
                        .init(
                            id: "arch-sla-100",
                            badge: "C",
                            title: "100 % (addition des deux SLA)",
                            subtitle: "Un SLA de 100 % n'existe pas pour deux composants en série",
                            assetName: "AzureServices/All-Resources",
                            isCorrect: false,
                            whyWrongOrRight: "Additionner des pourcentages de disponibilité est mathématiquement incorrect."
                        )
                    ],
                    examTip: "À l'examen AZ-900 : 2 services à 99,9 % en série = 99,80 % de SLA composite."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-sla-qtype04",
                    formatCode: "Q_TYPE_04",
                    domainBadge: "⌨️ AZURE CLI · RÉGIONS OFFICIELLES",
                    subBadge: "SAISIE CLAVIER CLI · EXPLORATION GÉOGRAPHIQUE",
                    prompt: "Vous vérifiez les emplacements géographiques disponibles pour votre abonnement.\nComplète la commande Azure CLI :",
                    mascotPose: .poseCLICoder,
                    options: [
                        .init(
                            id: "cli-locations",
                            badge: "CLI",
                            title: "list-locations",
                            isCorrect: true,
                            whyWrongOrRight: "La commande exacte est « az account list-locations -o table »."
                        )
                    ],
                    cliPrefix: "az account",
                    cliSuffix: "-o table",
                    expectedCLIInput: "list-locations",
                    cliSuggestionBricks: ["list-locations", "delete", "lock", "clear"],
                    examTip: "France Central (Paris) est jumelée avec France South pour la souveraineté des données sur le territoire français."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-sla-qtype05",
                    formatCode: "Q_TYPE_05",
                    domainBadge: "🧱 HIÉRARCHIE DE PORTÉE AZURE (SCOPE)",
                    subBadge: "ASSEMBLAGE DE BRIQUES · HÉRITAGE ARM",
                    prompt: "Les rôles RBAC et règles Azure Policy s'héritent du niveau parent vers l'enfant.\nAssemble dans l'ordre la hiérarchie de gouvernance Azure du plus haut au plus bas :",
                    mascotPose: .specialistCLIContainers,
                    options: [],
                    wordBankTargetTokens: ["Management Group", "➔", "Subscription", "➔", "Resource Group", "➔ Resource"],
                    wordBankAllBricks: ["Management Group", "➔", "Subscription", "➔", "Resource Group", "➔ Resource", " Tag"],
                    examTip: "Les rôles RBAC et les stratégies Azure Policy s'héritent toujours de haut en bas : Management Group -> Subscription -> Resource Group -> Resource."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-sla-qtype10",
                    formatCode: "Q_TYPE_10",
                    domainBadge: "☑️ CHOIX MULTIPLES · PAIRES DE RÉGIONS",
                    subBadge: "COCHE LES 2 AVANTAGES OFFICIELS AZ-900",
                    prompt: "Chaque région Azure est jumelée avec une seconde région au sein de la même géographie.\nQuels sont les 2 avantages garantis par les Paires de Régions ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "m-1",
                            badge: "1",
                            title: "Les mises à jour planifiées d'Azure sont déployées séquentiellement sur une seule région de la paire à la fois",
                            isCorrect: true,
                            whyWrongOrRight: "Microsoft ne met jamais à jour les deux régions jumelées simultanément afin d'éviter toute indisponibilité corrélée."
                        ),
                        .init(
                            id: "m-2",
                            badge: "2",
                            title: "Une distance physique d'au moins 300 miles (environ 480 km) lorsque possible au sein de la même géographie",
                            isCorrect: true,
                            whyWrongOrRight: "L'éloignement protège contre les catastrophes naturelles régionales tout en respectant la résidence des données."
                        ),
                        .init(
                            id: "m-3",
                            badge: "3",
                            title: "La gratuité totale de toutes les machines virtuelles déployées dans la région secondaire",
                            isCorrect: false,
                            whyWrongOrRight: "Les ressources actives dans la région secondaire sont facturées selon leur consommation."
                        ),
                        .init(
                            id: "m-4",
                            badge: "4",
                            title: "La suppression automatique des groupes de ressources toutes les 24 heures",
                            isCorrect: false,
                            whyWrongOrRight: "Les paires de régions assurent la continuité d'activité et ne suppriment jamais vos ressources."
                        )
                    ],
                    examTip: "Paires de régions = mises à jour séquentielles + isolement physique >= 300 miles + résidence légale des données."
                )
            ]
        }

        // Lesson 3 / Unit 2 / Unit 3: Governance, Costs, Policy, Locks & Tools
        if lowerLessonId.contains("u1-s3") || lowerLessonId.contains("u2") || lowerLessonId.contains("u3") || lowerTitle.contains("gouvernance") || lowerTitle.contains("coût") {
            return [
                CertiGoNativeExerciseItem(
                    id: "az-900-gov-qtype01",
                    formatCode: "Q_TYPE_01",
                    domainBadge: "💰 CALCULATEUR TCO VS CALCULATEUR DE PRIX",
                    subBadge: "FINOPS & GESTION DES COÛTS AZ-900",
                    prompt: "Votre directeur financier souhaite estimer les économies réalisées en migrant 40 serveurs physiques On-Premises vers Azure sur 3 ans (électricité, climatisation et administration incluses).\nQuel outil utilisez-vous ?",
                    mascotPose: .poseAnalyst,
                    options: [
                        .init(
                            id: "opt-a",
                            badge: "A",
                            title: "Le Calculateur de Coût Total de Possession (TCO Calculator)",
                            isCorrect: true,
                            whyWrongOrRight: "Le TCO Calculator compare le coût complet d'une infrastructure On-Premises avec son équivalent dans Azure."
                        ),
                        .init(
                            id: "opt-b",
                            badge: "B",
                            title: "Azure Network Watcher",
                            isCorrect: false,
                            whyWrongOrRight: "Network Watcher diagnostique les flux réseau VNet et n'effectue aucun calcul financier."
                        ),
                        .init(
                            id: "opt-c",
                            badge: "C",
                            title: "Azure Key Vault",
                            isCorrect: false,
                            whyWrongOrRight: "Key Vault protège les clés et secrets cryptographiques."
                        ),
                        .init(
                            id: "opt-d",
                            badge: "D",
                            title: "Microsoft Entra Connect",
                            isCorrect: false,
                            whyWrongOrRight: "Entra Connect synchronise les identités Active Directory locales avec le Cloud."
                        )
                    ],
                    examTip: "Comparer On-Premises vs Cloud = TCO Calculator. Estimer la facture mensuelle de ressources Azure = Pricing Calculator."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-gov-qtype02",
                    formatCode: "Q_TYPE_02",
                    domainBadge: "🏛️ GOUVERNANCE & CONFORMITÉ AZ-900",
                    subBadge: "GRILLE VISUELLE 2×2 · OUTILS OFFICIELS",
                    prompt: "Votre entreprise interdit tout déploiement de ressources hors de l'Union européenne.\nQuel service bloque automatiquement les créations dans des régions non autorisées ?",
                    mascotPose: .specialistSecurityEntra,
                    options: [
                        .init(
                            id: "grid-policy",
                            badge: "A",
                            title: "Azure Policy",
                            subtitle: "Règles de conformité & garde-fous",
                            assetName: "AzureServices/Policy",
                            isCorrect: true,
                            whyWrongOrRight: "Azure Policy applique des règles sur les propriétés des ressources (régions autorisées, tailles de VM, tags obligatoires)."
                        ),
                        .init(
                            id: "grid-entra",
                            badge: "B",
                            title: "Microsoft Entra ID",
                            subtitle: "Identité, SSO & MFA",
                            assetName: "AzureServices/Azure-Active-Directory",
                            isCorrect: false,
                            whyWrongOrRight: "Entra ID authentifie les utilisateurs mais ne filtre pas les régions de déploiement ARM."
                        ),
                        .init(
                            id: "grid-monitor",
                            badge: "C",
                            title: "Azure Monitor",
                            subtitle: "Métriques & journaux KQL",
                            assetName: "AzureServices/Monitor",
                            isCorrect: false,
                            whyWrongOrRight: "Azure Monitor collecte les métriques et journaux mais n'interdit pas un déploiement non conforme."
                        ),
                        .init(
                            id: "grid-storage",
                            badge: "D",
                            title: "Storage Account",
                            subtitle: "Blobs, Files, Queues & Tables",
                            assetName: "AzureServices/Storage-Accounts",
                            isCorrect: false,
                            whyWrongOrRight: "Storage Account est un service de stockage de données."
                        )
                    ],
                    examTip: "RBAC = QUI peut agir ; Azure Policy = QUELLES configurations de ressources sont autorisées."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-gov-qtype03",
                    formatCode: "Q_TYPE_03",
                    domainBadge: "🌐 GESTION HYBRIDE & MULTI-CLOUD",
                    subBadge: "SCHÉMA INTERACTIF · [ Serveurs On-Prem / AWS ] ➔ [ ? ] ➔ [ Azure ARM ]",
                    prompt: "Vous devez gouverner des serveurs Windows/Linux On-Premises et multicloud avec Azure Policy et Defender.\nQuelle solution placer dans [ ? ] ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "arch-arc",
                            badge: "A",
                            title: "Azure Arc",
                            subtitle: "Gouvernance unifiée des serveurs et clusters Kubernetes hors Azure",
                            assetName: "AzureServices/All-Resources",
                            isCorrect: true,
                            whyWrongOrRight: "Azure Arc étend le plan de contrôle Azure Resource Manager (Policy, Tags, RBAC, Monitor) aux ressources hors Azure."
                        ),
                        .init(
                            id: "arch-nat",
                            badge: "B",
                            title: "Azure NAT Gateway",
                            subtitle: "Traduction d'adresses sortantes SNAT",
                            assetName: "AzureServices/NAT",
                            isCorrect: false,
                            whyWrongOrRight: "NAT Gateway gère uniquement la connectivité Internet sortante d'un VNet."
                        ),
                        .init(
                            id: "arch-bot",
                            badge: "C",
                            title: "Azure AI Bot Service",
                            subtitle: "Agents conversationnels",
                            assetName: "AzureServices/Bot-Services",
                            isCorrect: false,
                            whyWrongOrRight: "Bot Service sert à développer des assistants conversationnels."
                        )
                    ],
                    examTip: "Gérer des serveurs On-Premises ou multi-cloud comme des ressources Azure = Azure Arc."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-gov-qtype04",
                    formatCode: "Q_TYPE_04",
                    domainBadge: "⌨️ VERROUS DE RESSOURCES (RESOURCE LOCKS)",
                    subBadge: "SAISIE CLAVIER CLI · PROTECTION CONTRE LA SUPPRESSION",
                    prompt: "Vous protégez le groupe de ressources RG-Compta contre toute suppression accidentelle.\nComplète la commande Azure CLI :",
                    mascotPose: .poseCLICoder,
                    options: [
                        .init(
                            id: "cli-lock",
                            badge: "CLI",
                            title: "lock",
                            isCorrect: true,
                            whyWrongOrRight: "La commande exacte est « az group lock create --lock-type CanNotDelete -n Lock-Compta -g RG-Compta »."
                        )
                    ],
                    cliPrefix: "az group",
                    cliSuffix: "create --lock-type CanNotDelete -g RG-Compta",
                    expectedCLIInput: "lock",
                    cliSuggestionBricks: ["lock", "tag", "policy", "budget"],
                    examTip: "CanNotDelete autorise la lecture et la modification, mais bloque toute suppression. ReadOnly bloque aussi toute modification."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-gov-qtype05",
                    formatCode: "Q_TYPE_05",
                    domainBadge: "🧱 ÉTIQUETTES FINOPS (RESOURCE TAGS)",
                    subBadge: "ASSEMBLAGE DE BRIQUES · CENTRE DE COÛTS",
                    prompt: "L'équipe FinOps affecte le centre de coût Env=Prod au groupe RG-Core.\nAssemble dans l'ordre la commande Azure CLI :",
                    mascotPose: .specialistCLIContainers,
                    options: [],
                    wordBankTargetTokens: ["az", "group", "update", "-n RG-Core", "--set", "tags.Env=Prod"],
                    wordBankAllBricks: ["az", "group", "update", "-n RG-Core", "--set", "tags.Env=Prod", "delete", "--no-wait"],
                    examTip: "Attention : les Tags ne sont PAS hérités automatiquement par les ressources enfants sans une règle Azure Policy Append/Inherit !"
                ),
                CertiGoNativeExerciseItem(
                    id: "az-900-gov-qtype10",
                    formatCode: "Q_TYPE_10",
                    domainBadge: "☑️ CHOIX MULTIPLES · SURVEILLANCE AZURE",
                    subBadge: "COCHE LES 2 AFFIRMATIONS EXACTES",
                    prompt: "Vous mettez en place le suivi de santé et l'optimisation continue de vos abonnements.\nQuelles sont les 2 affirmations exactes sur Azure Advisor et Azure Service Health ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "m-1",
                            badge: "1",
                            title: "Azure Advisor donne des recommandations gratuites sur la Fiabilité, la Sécurité, la Performance et le Coût",
                            isCorrect: true,
                            whyWrongOrRight: "Azure Advisor analyse vos ressources selon les 5 piliers du Well-Architected Framework."
                        ),
                        .init(
                            id: "m-2",
                            badge: "2",
                            title: "Azure Service Health vous alerte de manière personnalisée lorsqu'une panne Azure affecte vos régions et ressources",
                            isCorrect: true,
                            whyWrongOrRight: "Service Health combine Azure Status, l'impact personnalisé sur votre abonnement et Resource Health."
                        ),
                        .init(
                            id: "m-3",
                            badge: "3",
                            title: "Azure Advisor remplace le pare-feu réseau Azure Firewall",
                            isCorrect: false,
                            whyWrongOrRight: "Advisor est un outil de conseil, pas un pare-feu réseau."
                        ),
                        .init(
                            id: "m-4",
                            badge: "4",
                            title: "Les verrous Resource Locks augmentent automatiquement la taille des disques SSD",
                            isCorrect: false,
                            whyWrongOrRight: "Les verrous protègent uniquement contre la modification ou la suppression."
                        )
                    ],
                    examTip: "Recommandations personnalisées 5 piliers = Azure Advisor ; État des pannes Microsoft impactant vos services = Azure Service Health."
                )
            ]
        }

        // Default / Lesson 1 (`u1-s1` AZ-900): Cloud Concepts, CapEx vs OpEx & Shared Responsibility (IaaS/PaaS/SaaS)
        return [
            CertiGoNativeExerciseItem(
                id: "az-900-qtype01",
                formatCode: "Q_TYPE_01",
                domainBadge: "☁️ MODÈLES FINANCIERS · CAPEX VS OPEX",
                subBadge: "FONDAMENTAUX AZ-900 · ÉCONOMIE DU CLOUD",
                prompt: "Une startup préfère louer des ressources Cloud facturées à la minute (Pay-as-you-go) plutôt que d'acheter pour 200 000 € de serveurs physiques avant de lancer son produit.\nQuel modèle financier adopte-t-elle ?",
                mascotPose: .specialistCloudAzure,
                options: [
                    .init(
                        id: "opt-a",
                        badge: "A",
                        title: "CapEx (Dépenses d'investissement en capital immobilisé)",
                        isCorrect: false,
                        whyWrongOrRight: "Le CapEx correspond à l'achat initial de matériel physique amorti sur plusieurs années."
                    ),
                    .init(
                        id: "opt-b",
                        badge: "B",
                        title: "OpEx (Dépenses opérationnelles liées à la consommation réelle)",
                        isCorrect: true,
                        whyWrongOrRight: "Le modèle OpEx ne requiert aucun investissement initial et facture uniquement les ressources réellement consommées."
                    ),
                    .init(
                        id: "opt-c",
                        badge: "C",
                        title: "Amortissement matériel sur site (On-Premises Depreciation)",
                        isCorrect: false,
                        whyWrongOrRight: "L'amortissement matériel s'applique aux équipements physiques achetés en CapEx."
                    ),
                    .init(
                        id: "opt-d",
                        badge: "D",
                        title: "Verrouillage matériel irrévocable sur 5 ans",
                        isCorrect: false,
                        whyWrongOrRight: "Le paiement à l'usage permet au contraire d'arrêter une ressource à tout moment."
                    )
                ],
                examTip: "À l'examen AZ-900 : Serveurs physiques payés d'avance = CapEx ; Cloud Pay-as-you-go facturé à l'usage = OpEx.",
                comparisonLeftTitle: "CapEx (Investissement)",
                comparisonLeftBullets: [
                    "Coût initial élevé payé d'avance",
                    "Achat de serveurs physiques et licences",
                    "Valeur amortie sur 3 à 5 ans"
                ],
                comparisonRightTitle: "OpEx (Opérationnel Cloud)",
                comparisonRightBullets: [
                    "Aucun coût matériel initial (0 € d'avance)",
                    "Facturation mensuelle selon l'usage réel",
                    "Déductible immédiatement en charge d'exploitation"
                ],
                comparisonGoldenRule: "Le Cloud public transforme les dépenses matérielles fixes (CapEx) en dépenses opérationnelles variables (OpEx) !"
            ),
            CertiGoNativeExerciseItem(
                id: "az-900-qtype02",
                formatCode: "Q_TYPE_02",
                domainBadge: "🧩 IaaS, PaaS & SaaS · SERVICES AZURE",
                subBadge: "GRILLE VISUELLE 2×2 · CATÉGORIES DE SERVICES",
                prompt: "Vous souhaitez héberger une application web sans gérer le système d'exploitation sous-jacent.\nQuel service PaaS (Platform as a Service) choisissez-vous ?",
                mascotPose: .specialistCloudAzure,
                options: [
                    .init(
                        id: "grid-appservice",
                        badge: "A",
                        title: "App Service",
                        subtitle: "Hébergement Web & API PaaS",
                        assetName: "AzureServices/App-Services",
                        isCorrect: true,
                        whyWrongOrRight: "Azure App Service est une offre PaaS : Microsoft gère l'OS, les correctifs et l'équilibrage de charge."
                    ),
                    .init(
                        id: "grid-vnet",
                        badge: "B",
                        title: "Virtual Network",
                        subtitle: "Brique réseau IaaS",
                        assetName: "AzureServices/Virtual-Networks",
                        isCorrect: false,
                        whyWrongOrRight: "Azure Virtual Network fait partie de la couche d'infrastructure réseau (IaaS)."
                    ),
                    .init(
                        id: "grid-fw",
                        badge: "C",
                        title: "Azure Firewall",
                        subtitle: "Filtrage réseau managé",
                        assetName: "AzureServices/Firewalls",
                        isCorrect: false,
                        whyWrongOrRight: "Azure Firewall est une appliance de sécurité réseau, pas une plateforme d'hébergement web PaaS."
                    ),
                    .init(
                        id: "grid-dns",
                        badge: "D",
                        title: "Azure DNS",
                        subtitle: "Résolution de noms de domaine",
                        assetName: "AzureServices/DNS-Zones",
                        isCorrect: false,
                        whyWrongOrRight: "Azure DNS héberge les enregistrements de noms de domaine."
                    )
                ],
                examTip: "VMs & VNet = IaaS ; App Service, Azure Functions & Azure SQL Database = PaaS ; Microsoft 365 = SaaS."
            ),
            CertiGoNativeExerciseItem(
                id: "az-900-qtype03",
                formatCode: "Q_TYPE_03",
                domainBadge: "🤝 MODÈLE DE RESPONSABILITÉ PARTAGÉE",
                subBadge: "SCHÉMA INTERACTIF · [ Client ] ➔ [ ? ] ➔ [ Microsoft Azure ]",
                prompt: "Votre équipe doit garder le contrôle complet du patching de l'OS Windows/Linux et des disques.\nQuel modèle de service Cloud implique cette responsabilité ?",
                mascotPose: .specialistSecurityEntra,
                options: [
                    .init(
                        id: "arch-iaas",
                        badge: "A",
                        title: "IaaS (Infrastructure as a Service — Machines Virtuelles)",
                        subtitle: "Microsoft gère le datacenter physique ; tu gères l'OS, le middleware et les données",
                        assetName: "AzureServices/Virtual-Networks",
                        isCorrect: true,
                        whyWrongOrRight: "En IaaS, Microsoft gère uniquement le matériel physique, l'électricité et la virtualisation ; le client gère l'OS et tout ce qui est au-dessus."
                    ),
                    .init(
                        id: "arch-paas",
                        badge: "B",
                        title: "PaaS (Platform as a Service — App Service / SQL DB)",
                        subtitle: "Microsoft gère aussi le système d'exploitation et le runtime",
                        assetName: "AzureServices/App-Services",
                        isCorrect: false,
                        whyWrongOrRight: "En PaaS, le patching de l'OS est délégué à Microsoft."
                    ),
                    .init(
                        id: "arch-saas",
                        badge: "C",
                        title: "SaaS (Software as a Service — Microsoft 365)",
                        subtitle: "Microsoft gère l'application complète",
                        assetName: "AzureServices/Azure-Active-Directory",
                        isCorrect: false,
                        whyWrongOrRight: "En SaaS, le fournisseur gère toute la pile logicielle (hors données et identités)."
                    )
                ],
                examTip: "Plus de contrôle et de responsabilité technique = IaaS. Moins de gestion d'infrastructure = SaaS."
            ),
            CertiGoNativeExerciseItem(
                id: "az-900-qtype04",
                formatCode: "Q_TYPE_04",
                domainBadge: "⌨️ DÉCOUVERTE AZURE CLI",
                subBadge: "SAISIE CLAVIER CLI · CONNEXION INTERACTIVE",
                prompt: "Vous ouvrez un terminal local pour administrer vos ressources Azure.\nComplète la commande de connexion interactive Azure CLI :",
                mascotPose: .poseCLICoder,
                options: [
                    .init(
                        id: "cli-login",
                        badge: "CLI",
                        title: "login",
                        isCorrect: true,
                        whyWrongOrRight: "La commande « az login » ouvre le flux d'authentification Microsoft Entra ID."
                    )
                ],
                cliPrefix: "az",
                cliSuffix: "--tenant contoso.onmicrosoft.com",
                expectedCLIInput: "login",
                cliSuggestionBricks: ["login", "logout", "reboot", "format"],
                examTip: "Tu peux exécuter az login ou utiliser directement Azure Cloud Shell (Bash ou PowerShell) déjà authentifié dans le portail."
            ),
            CertiGoNativeExerciseItem(
                id: "az-900-qtype05",
                formatCode: "Q_TYPE_05",
                domainBadge: "🧱 CRÉATION DE GROUPE DE RESSOURCES",
                subBadge: "ASSEMBLAGE DE BRIQUES · AZURE CLI",
                prompt: "Vous initialisez le conteneur logique RG-Demo dans la région francecentral.\nAssemble dans l'ordre la commande Azure CLI :",
                mascotPose: .specialistCLIContainers,
                options: [],
                wordBankTargetTokens: ["az", "group", "create", "--name RG-Demo", "--location francecentral"],
                wordBankAllBricks: ["az", "group", "create", "--name RG-Demo", "--location francecentral", "delete", "--sku Basic"],
                examTip: "Chaque ressource Azure doit appartenir à un et un seul Groupe de Ressources (Resource Group)."
            ),
            CertiGoNativeExerciseItem(
                id: "az-900-qtype10",
                formatCode: "Q_TYPE_10",
                domainBadge: "☑️ CHOIX MULTIPLES · RESPONSABILITÉ DU CLIENT",
                subBadge: "COCHE LES 2 ÉLÉMENTS TOUJOURS GÉRÉS PAR LE CLIENT",
                prompt: "Dans le modèle de responsabilité partagée, certaines couches ne sont jamais déléguées au fournisseur Cloud.\nQuels sont les 2 éléments toujours gérés par le client (IaaS, PaaS ou SaaS) ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "m-1",
                        badge: "1",
                        title: "Les Données et les Informations stockées dans le Cloud",
                        isCorrect: true,
                        whyWrongOrRight: "Le client est toujours propriétaire et responsable de la classification et de la gouvernance de ses données."
                    ),
                    .init(
                        id: "m-2",
                        badge: "2",
                        title: "Les Comptes, Identités et Appareils autorisés à se connecter",
                        isCorrect: true,
                        whyWrongOrRight: "La gestion des accès utilisateurs, mots de passe/MFA et appareils clients incombe toujours au client."
                    ),
                    .init(
                        id: "m-3",
                        badge: "3",
                        title: "La sécurité physique des centres de données Microsoft et le remplacement des disques durs",
                        isCorrect: false,
                        whyWrongOrRight: "Dans le Cloud, la sécurité physique du datacenter est toujours assurée par Microsoft."
                    ),
                    .init(
                        id: "m-4",
                        badge: "4",
                        title: "La maintenance des câbles sous-marins du réseau mondial Microsoft",
                        isCorrect: false,
                        whyWrongOrRight: "Le réseau physique mondial est géré exclusivement par Microsoft."
                    )
                ],
                examTip: "Retiens le trio toujours sous la responsabilité du client : Données + Identités/Accès + Appareils (Endpoints)."
            )
        ]
    }

    private static func awsExercises(
        routeCode: String,
        lowerLessonId: String,
        lowerTitle: String
    ) -> [CertiGoNativeExerciseItem] {
        if lowerLessonId.contains("u2") || lowerLessonId.contains("u3") || lowerTitle.contains("rds") || lowerTitle.contains("alb") {
            return [
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-ha-qtype01",
                    formatCode: "Q_TYPE_01",
                    domainBadge: "🗄️ AMAZON RDS MULTI-AZ VS READ REPLICAS",
                    subBadge: "HAUTE DISPONIBILITÉ & BASCULEMENT AUTOMATIQUE",
                    prompt: "Une base de données relationnelle critique Amazon RDS pour PostgreSQL doit survivre à la panne complète d'une Zone de Disponibilité avec basculement DNS automatique et zéro perte de données (RPO = 0).\nQuelle option activez-vous ?",
                    mascotPose: .poseAnalyst,
                    options: [
                        .init(
                            id: "opt-a",
                            badge: "A",
                            title: "Déploiement Amazon RDS Multi-AZ (instance Standby à réplication synchrone)",
                            isCorrect: true,
                            whyWrongOrRight: "RDS Multi-AZ maintient une réplique Standby synchrone dans une autre AZ et bascule automatiquement le CNAME DNS en 60 secondes."
                        ),
                        .init(
                            id: "opt-b",
                            badge: "B",
                            title: "Une seule Read Replica asynchrone sans Multi-AZ",
                            isCorrect: false,
                            whyWrongOrRight: "Une Read Replica utilise une réplication asynchrone pour décharger les lectures et nécessite une promotion manuelle en cas de panne."
                        ),
                        .init(
                            id: "opt-c",
                            badge: "C",
                            title: "Stocker la base PostgreSQL sur un volume EC2 Instance Store éphémère",
                            isCorrect: false,
                            whyWrongOrRight: "Les volumes Instance Store perdent toutes leurs données si l'instance EC2 s'arrête."
                        ),
                        .init(
                            id: "opt-d",
                            badge: "D",
                            title: "Sauvegarder la base une fois par mois dans S3 Glacier Deep Archive",
                            isCorrect: false,
                            whyWrongOrRight: "Glacier Deep Archive a un délai de restauration de 12 heures, incompatible avec un basculement immédiat."
                        )
                    ],
                    examTip: "Haute disponibilité & failover synchrone automatique = RDS Multi-AZ. Scalabilité des requêtes SELECT = Read Replicas."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-ha-qtype02",
                    formatCode: "Q_TYPE_02",
                    domainBadge: "⚖️ ÉQUILIBRAGE DE CHARGE & HAUTE DISPO AWS",
                    subBadge: "GRILLE VISUELLE 2×2 · SERVICES AWS OFFICIELS",
                    prompt: "Vos microservices web nécessitent un routage HTTP/HTTPS par chemin d'URL (/api, /checkout) couplé à AWS WAF.\nQuel service AWS choisissez-vous ?",
                    mascotPose: .specialistNetworkVNet,
                    options: [
                        .init(
                            id: "grid-alb",
                            badge: "A",
                            title: "Elastic Load Balancing",
                            subtitle: "ALB Couche 7 HTTP/HTTPS + WAF",
                            assetName: "AWSServices/Elastic-Load-Balancing",
                            isCorrect: true,
                            whyWrongOrRight: "L'Application Load Balancer (ALB) opère en couche 7, route par chemin/hôte et embarque AWS WAF."
                        ),
                        .init(
                            id: "grid-rds",
                            badge: "B",
                            title: "Amazon RDS",
                            subtitle: "Bases SQL managées Multi-AZ",
                            assetName: "AWSServices/Amazon-RDS",
                            isCorrect: false,
                            whyWrongOrRight: "Amazon RDS est le service de bases de données relationnelles managées."
                        ),
                        .init(
                            id: "grid-cw",
                            badge: "C",
                            title: "Amazon CloudWatch",
                            subtitle: "Métriques, Logs & Alarmes",
                            assetName: "AWSServices/Amazon-CloudWatch",
                            isCorrect: false,
                            whyWrongOrRight: "CloudWatch surveille les métriques mais ne répartit pas le trafic HTTP."
                        ),
                        .init(
                            id: "grid-s3",
                            badge: "D",
                            title: "Amazon S3",
                            subtitle: "Stockage objet 11×9 de durabilité",
                            assetName: "AWSServices/Amazon-Simple-Storage-Service",
                            isCorrect: false,
                            whyWrongOrRight: "Amazon S3 est un service de stockage objet."
                        )
                    ],
                    examTip: "HTTP/HTTPS + routage par URL + AWS WAF = Application Load Balancer (ALB). TCP/UDP ultra-faible latence + IP statique = Network Load Balancer (NLB)."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-ha-qtype03",
                    formatCode: "Q_TYPE_03",
                    domainBadge: "🌐 ARCHITECTURE WEB MULTI-AZ AWS",
                    subBadge: "SCHÉMA INTERACTIF · [ Clients ] ➔ [ ? ] ➔ [ Auto Scaling EC2 Privé ]",
                    prompt: "Vos instances EC2 dans un Auto Scaling Group subissent des tentatives d'injection SQL OWASP.\nQuelle brique placer en [ ? ] pour filtrer le trafic entrant ?",
                    mascotPose: .specialistNetworkVNet,
                    options: [
                        .init(
                            id: "arch-waf-alb",
                            badge: "A",
                            title: "AWS WAF attaché à un Application Load Balancer (ALB)",
                            subtitle: "Inspection HTTP/HTTPS Couche 7 et Web ACL Managed Rules",
                            assetName: "AWSServices/AWS-WAF",
                            isCorrect: true,
                            whyWrongOrRight: "AWS WAF inspecte les requêtes HTTP(S) sur CloudFront, ALB ou API Gateway pour bloquer SQLi, XSS et bots."
                        ),
                        .init(
                            id: "arch-kms",
                            badge: "B",
                            title: "AWS Key Management Service (KMS)",
                            subtitle: "Gestion des clés de chiffrement au repos",
                            assetName: "AWSServices/AWS-Key-Management-Service",
                            isCorrect: false,
                            whyWrongOrRight: "KMS chiffre les données au repos et ne filtre pas le trafic HTTP entrant."
                        ),
                        .init(
                            id: "arch-s3",
                            badge: "C",
                            title: "Amazon S3 Glacier",
                            subtitle: "Archivage froid longue durée",
                            assetName: "AWSServices/Amazon-Simple-Storage-Service",
                            isCorrect: false,
                            whyWrongOrRight: "S3 Glacier sert à l'archivage de données à bas coût."
                        )
                    ],
                    examTip: "AWS WAF s'intègre nativement à Amazon CloudFront, Application Load Balancer (ALB), Amazon API Gateway et AWS AppSync."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-ha-qtype04",
                    formatCode: "Q_TYPE_04",
                    domainBadge: "⌨️ AWS CLI · HAUTE DISPONIBILITÉ RDS",
                    subBadge: "SAISIE CLAVIER CLI · CONVERSION MULTI-AZ",
                    prompt: "Vous activez la haute disponibilité Multi-AZ sur la base prod-postgres en production.\nComplète la sous-commande AWS CLI :",
                    mascotPose: .poseCLICoder,
                    options: [
                        .init(
                            id: "cli-modify-db",
                            badge: "CLI",
                            title: "modify-db-instance",
                            isCorrect: true,
                            whyWrongOrRight: "La commande exacte est « aws rds modify-db-instance --db-instance-identifier prod-postgres --multi-az --apply-immediately »."
                        )
                    ],
                    cliPrefix: "aws rds",
                    cliSuffix: "--db-instance-identifier prod-postgres --multi-az",
                    expectedCLIInput: "modify-db-instance",
                    cliSuggestionBricks: ["modify-db-instance", "delete-db-instance", "reboot-db", "stop"],
                    examTip: "L'activation de Multi-AZ sur RDS crée un snapshot puis synchronise le Standby sans interruption prolongée."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-ha-qtype05",
                    formatCode: "Q_TYPE_05",
                    domainBadge: "🧱 CONSTRUCTEUR AWS CLI · AUTO SCALING",
                    subBadge: "ASSEMBLAGE DE BRIQUES · CAPACITÉ DÉSIRÉE",
                    prompt: "Un pic de trafic nécessite de passer immédiatement le groupe web-asg à 4 instances.\nAssemble dans l'ordre la commande AWS CLI :",
                    mascotPose: .specialistCLIContainers,
                    options: [],
                    wordBankTargetTokens: ["aws", "autoscaling", "set-desired-capacity", "--auto-scaling-group-name web-asg", "--desired-capacity 4"],
                    wordBankAllBricks: ["aws", "autoscaling", "set-desired-capacity", "--auto-scaling-group-name web-asg", "--desired-capacity 4", "terminate", "--force"],
                    examTip: "Un Auto Scaling Group ajuste automatiquement le nombre d'instances EC2 entre MinSize, DesiredCapacity et MaxSize."
                ),
                CertiGoNativeExerciseItem(
                    id: "\(routeCode.lowercased())-ha-qtype10",
                    formatCode: "Q_TYPE_10",
                    domainBadge: "☑️ CHOIX MULTIPLES · SÉCURITÉ S3 & CLOUDFRONT",
                    subBadge: "COCHE LES 2 ACTIONS OBLIGATOIRES",
                    prompt: "Vous hébergez les assets statiques d'une application derrière Amazon CloudFront dans un bucket S3 privé.\nQuelles sont les 2 actions pour interdire tout contournement direct vers l'URL S3 ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "m-1",
                            badge: "1",
                            title: "Configurer Origin Access Control (OAC) sur la distribution CloudFront avec Bucket Policy autorisant uniquement CloudFront",
                            isCorrect: true,
                            whyWrongOrRight: "Origin Access Control (OAC) signe les requêtes de CloudFront vers S3 avec SigV4."
                        ),
                        .init(
                            id: "m-2",
                            badge: "2",
                            title: "Activer S3 Block Public Access sur l'intégralité du bucket et du compte AWS",
                            isCorrect: true,
                            whyWrongOrRight: "S3 Block Public Access verrouille toute exposition publique directe du bucket."
                        ),
                        .init(
                            id: "m-3",
                            badge: "3",
                            title: "Ajouter Principal: \"*\" avec Action: \"s3:*\" dans la Bucket Policy",
                            isCorrect: false,
                            whyWrongOrRight: "Principal: * avec s3:* donne le contrôle total du bucket à tout Internet !"
                        ),
                        .init(
                            id: "m-4",
                            badge: "4",
                            title: "Désactiver le chiffrement TLS HTTPS sur CloudFront",
                            isCorrect: false,
                            whyWrongOrRight: "Désactiver HTTPS compromet la confidentialité du trafic sans protéger l'origine S3."
                        )
                    ],
                    examTip: "CloudFront + S3 privé = Origin Access Control (OAC) + S3 Block Public Access activé."
                )
            ]
        }

        // Default / Unit 1 (`SAA-C03` / `CLF-C02` / `AIF-C01`): IAM Roles STS, VPC Endpoints, S3 & KMS
        return [
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype01",
                formatCode: "Q_TYPE_01",
                domainBadge: "⚡ AWS IAM ROLES & STS ASSUMEROLE",
                subBadge: "MOINDRE PRIVILÈGE · ZÉRO CLÉ STATIQUE",
                prompt: "Une application déployée sur une instance Amazon EC2 dans un VPC privé (\(routeCode)) doit déposer des rapports PDF dans un bucket Amazon S3.\nQuelle méthode d'authentification respecte les bonnes pratiques AWS ?",
                mascotPose: .specialistSecurityEntra,
                options: [
                    .init(
                        id: "opt-a",
                        badge: "A",
                        title: "Créer un utilisateur IAM avec Access Key / Secret Key codés en dur dans les variables d'environnement",
                        isCorrect: false,
                        whyWrongOrRight: "Les clés IAM statiques à longue durée de vie exposent le compte en cas de fuite du code ou d'accès au serveur."
                    ),
                    .init(
                        id: "opt-b",
                        badge: "B",
                        title: "Attacher un Rôle IAM (Instance Profile) à l'instance EC2 fournissant des jetons temporaires via AWS STS",
                        isCorrect: true,
                        whyWrongOrRight: "L'Instance Profile EC2 permet au SDK AWS de récupérer automatiquement des identifiants temporaires rotatifs via IMDSv2 et AWS STS."
                    ),
                    .init(
                        id: "opt-c",
                        badge: "C",
                        title: "Utiliser les identifiants de l'utilisateur Root du compte AWS",
                        isCorrect: false,
                        whyWrongOrRight: "Le compte Root ne doit jamais être utilisé pour des charges applicatives et ne doit posséder aucune clé d'accès."
                    ),
                    .init(
                        id: "opt-d",
                        badge: "D",
                        title: "Désactiver l'authentification sur le bucket S3 en l'ouvrant à tout Internet",
                        isCorrect: false,
                        whyWrongOrRight: "Rendre un bucket S3 public en écriture est une faille de sécurité critique."
                    )
                ],
                examTip: "Sur AWS : EC2, Lambda ou ECS accédant à S3/DynamoDB = TOUJOURS un Rôle IAM (STS temporaire), jamais d'Access Key statique !",
                comparisonLeftTitle: "Gateway VPC Endpoint",
                comparisonLeftBullets: [
                    "100 % gratuit (aucun coût horaire ni par Go)",
                    "Supporte uniquement Amazon S3 et DynamoDB",
                    "Fonctionne par entrée dans la Route Table du Subnet"
                ],
                comparisonRightTitle: "Interface Endpoint (PrivateLink)",
                comparisonRightBullets: [
                    "Facturé à l'heure et au Go traité",
                    "Supporte KMS, SQS, SNS, Bedrock et 100+ services AWS",
                    "Crée une interface réseau ENI avec IP privée dans le Subnet"
                ],
                comparisonGoldenRule: "Pour joindre S3 ou DynamoDB depuis un sous-réseau privé sans payer de NAT Gateway, choisis toujours un Gateway VPC Endpoint !"
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype02",
                formatCode: "Q_TYPE_02",
                domainBadge: "🔐 SÉCURITÉ & SERVICES CORE AWS",
                subBadge: "GRILLE VISUELLE 2×2 · SERVICES OFFICIELS AWS",
                prompt: "Vous devez gérer des clés de chiffrement Customer Managed Keys (CMK) avec rotation annuelle et audit CloudTrail.\nQuel service AWS choisissez-vous ?",
                mascotPose: .specialistSecurityEntra,
                options: [
                    .init(
                        id: "grid-kms",
                        badge: "A",
                        title: "AWS KMS",
                        subtitle: "Clés CMK, SSE-KMS & HSM",
                        assetName: "AWSServices/AWS-Key-Management-Service",
                        isCorrect: true,
                        whyWrongOrRight: "AWS Key Management Service (KMS) crée et contrôle les clés cryptographiques CMK utilisées pour SSE-KMS sur S3, EBS et RDS."
                    ),
                    .init(
                        id: "grid-iam",
                        badge: "B",
                        title: "AWS IAM",
                        subtitle: "Rôles, Politiques JSON & STS",
                        assetName: "AWSServices/AWS-Identity-and-Access-Management",
                        isCorrect: false,
                        whyWrongOrRight: "AWS IAM gère les identités et les politiques de permissions mais ne stocke pas les clés de chiffrement de données."
                    ),
                    .init(
                        id: "grid-ec2",
                        badge: "C",
                        title: "Amazon EC2",
                        subtitle: "Instances de calcul virtuelles",
                        assetName: "AWSServices/Amazon-EC2",
                        isCorrect: false,
                        whyWrongOrRight: "Amazon EC2 fournit de la capacité de calcul redimensionnable."
                    ),
                    .init(
                        id: "grid-lambda",
                        badge: "D",
                        title: "AWS Lambda",
                        subtitle: "Fonctions Serverless événementielles",
                        assetName: "AWSServices/AWS-Lambda",
                        isCorrect: false,
                        whyWrongOrRight: "AWS Lambda exécute du code sans serveur jusqu'à 15 minutes par invocation."
                    )
                ],
                examTip: "Chiffrement S3 ou EBS avec audit CloudTrail de chaque utilisation de clé et rotation annuelle = SSE-KMS avec AWS KMS."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype03",
                formatCode: "Q_TYPE_03",
                domainBadge: "🌐 ARCHITECTURE VPC & OPTIMISATION NAT",
                subBadge: "SCHÉMA INTERACTIF · [ Subnet Privé EC2 ] ➔ [ ? ] ➔ [ Amazon S3 ]",
                prompt: "Vos instances EC2 privées transfèrent 50 To/mois vers Amazon S3 via une NAT Gateway coûteuse.\nQuelle brique placer dans [ ? ] pour éliminer les frais NAT ?",
                mascotPose: .specialistNetworkVNet,
                options: [
                    .init(
                        id: "arch-gw-ep",
                        badge: "A",
                        title: "Gateway VPC Endpoint pour Amazon S3",
                        subtitle: "Routage privé direct via la Route Table sans frais horaires ni frais au Go",
                        assetName: "AWSServices/Amazon-Simple-Storage-Service",
                        isCorrect: true,
                        whyWrongOrRight: "Un Gateway VPC Endpoint route le trafic S3 directement via la table de routage du VPC sans passer par la NAT Gateway et sans coût."
                    ),
                    .init(
                        id: "arch-waf",
                        badge: "B",
                        title: "AWS WAF (Web Application Firewall)",
                        subtitle: "Filtrage HTTP Couche 7 entrant",
                        assetName: "AWSServices/AWS-WAF",
                        isCorrect: false,
                        whyWrongOrRight: "AWS WAF protège les applications web entrantes et ne remplace pas une route VPC vers S3."
                    ),
                    .init(
                        id: "arch-rds",
                        badge: "C",
                        title: "Amazon RDS Read Replica",
                        subtitle: "Réplique de lecture base de données",
                        assetName: "AWSServices/Amazon-RDS",
                        isCorrect: false,
                        whyWrongOrRight: "RDS Read Replica sert aux bases relationnelles, pas au routage VPC vers S3."
                    )
                ],
                examTip: "Réduire la facture NAT Gateway pour un fort trafic vers Amazon S3 ou DynamoDB = Gateway VPC Endpoint (gratuit)."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype04",
                formatCode: "Q_TYPE_04",
                domainBadge: "⌨️ AWS CLI & PROTECTION S3",
                subBadge: "SAISIE CLAVIER CLI · VERSIONING S3",
                prompt: "Vous protégez le bucket prod-contracts-eu contre les écrasements accidentels.\nComplète la sous-commande AWS CLI pour activer le Versioning :",
                mascotPose: .poseCLICoder,
                options: [
                    .init(
                        id: "cli-versioning",
                        badge: "CLI",
                        title: "put-bucket-versioning",
                        isCorrect: true,
                        whyWrongOrRight: "La commande exacte est « aws s3api put-bucket-versioning --bucket prod-contracts-eu --versioning-configuration Status=Enabled »."
                    )
                ],
                cliPrefix: "aws s3api",
                cliSuffix: "--bucket prod-contracts-eu --versioning-configuration Status=Enabled",
                expectedCLIInput: "put-bucket-versioning",
                cliSuggestionBricks: ["put-bucket-versioning", "delete-bucket", "create-vpc", "ls"],
                examTip: "Le Versioning S3 est un prérequis obligatoire pour activer S3 Object Lock (WORM) et la réplication CRR/SRR !"
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype05",
                formatCode: "Q_TYPE_05",
                domainBadge: "🧱 CONSTRUCTEUR AWS CLI · VPC ENDPOINT",
                subBadge: "ASSEMBLAGE DE BRIQUES · GATEWAY ENDPOINT",
                prompt: "Vous raccordez le VPC vpc-prod à Amazon S3 en privé.\nAssemble dans l'ordre la commande AWS CLI :",
                mascotPose: .specialistCLIContainers,
                options: [],
                wordBankTargetTokens: ["aws", "ec2", "create-vpc-endpoint", "--vpc-id vpc-prod", "--service-name com.amazonaws.eu-west-1.s3"],
                wordBankAllBricks: ["aws", "ec2", "create-vpc-endpoint", "--vpc-id vpc-prod", "--service-name com.amazonaws.eu-west-1.s3", "terminate-instances", "--force"],
                examTip: "Un Gateway VPC Endpoint nécessite d'associer la Route Table des sous-réseaux privés (--route-table-ids)."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype10",
                formatCode: "Q_TYPE_10",
                domainBadge: "☑️ CHOIX MULTIPLES · ÉVALUATION IAM AWS",
                subBadge: "COCHE LES 2 RÈGLES FONDAMENTALES IAM",
                prompt: "AWS IAM évalue simultanément les Service Control Policies (SCP), les Resource Policies et les Identity Policies.\nQuelles sont les 2 règles d'or toujours vraies ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "m-1",
                        badge: "1",
                        title: "Un Deny explicite (Effect: Deny) l'emporte TOUJOURS sur n'importe quel Allow",
                        isCorrect: true,
                        whyWrongOrRight: "La logique d'évaluation IAM commence par rechercher tout Deny explicite, qui bloque immédiatement l'action."
                    ),
                    .init(
                        id: "m-2",
                        badge: "2",
                        title: "Une SCP (Service Control Policy) définit le plafond maximal de permissions mais n'accorde jamais de permission toute seule",
                        isCorrect: true,
                        whyWrongOrRight: "Les SCPs agissent comme des garde-fous : l'utilisateur ou le rôle dans le compte membre doit aussi avoir un Allow IAM explicite."
                    ),
                    .init(
                        id: "m-3",
                        badge: "3",
                        title: "Par défaut, toutes les actions non mentionnées dans une politique IAM sont implicitement autorisées",
                        isCorrect: false,
                        whyWrongOrRight: "Par défaut dans AWS IAM, tout ce qui n'est pas explicitement autorisé est refusé (Implicit Deny)."
                    ),
                    .init(
                        id: "m-4",
                        badge: "4",
                        title: "Les clés d'accès Root contournent les SCPs appliquées au compte membre",
                        isCorrect: false,
                        whyWrongOrRight: "Les SCPs d'AWS Organizations s'appliquent à tous les utilisateurs et rôles du compte membre, y compris son utilisateur Root !"
                    )
                ],
                examTip: "Logique d'évaluation IAM : 1. Explicit Deny -> 2. Organizations SCP -> 3. Resource Policy / Permission Boundary -> 4. Identity Allow -> sinon Implicit Deny."
            )
        ]
    }

    private static func ai102Exercises(
        lowerLessonId: String,
        lowerTitle: String
    ) -> [CertiGoNativeExerciseItem] {
        return [
            CertiGoNativeExerciseItem(
                id: "ai-102-qtype01",
                formatCode: "Q_TYPE_01",
                domainBadge: "✦ AZURE AI SEARCH · ARCHITECTURE RAG HYBRIDE",
                subBadge: "INGÉNIERIE IA AI-102 · PERTINENCE MAXIMALE",
                prompt: "Vous construisez un assistant RAG interrogeant 50 000 manuels techniques contenant des codes d'erreur exacts (ERR-4092) et des questions en langage naturel.\nQuelle configuration d'Azure AI Search maximise la précision ?",
                mascotPose: .specialistAICoach,
                options: [
                    .init(
                        id: "opt-a",
                        badge: "A",
                        title: "Recherche purement par mots-clés plein texte BM25 sans vecteurs",
                        isCorrect: false,
                        whyWrongOrRight: "BM25 trouve les codes exacts mais échoue sur les reformulations sémantiques et synonymes métiers."
                    ),
                    .init(
                        id: "opt-b",
                        badge: "B",
                        title: "Recherche Hybride (BM25 + Vecteurs text-embedding-3-large) fusionnée par RRF avec Semantic Ranker L2",
                        isCorrect: true,
                        whyWrongOrRight: "La recherche hybride combine l'exactitude lexicale BM25 et la proximité vectorielle HNSW via Reciprocal Rank Fusion (RRF), puis le Semantic Ranker réordonne les meilleurs extraits."
                    ),
                    .init(
                        id: "opt-c",
                        badge: "C",
                        title: "Envoyer l'intégralité des 50 000 PDF bruts dans chaque requête HTTP vers GPT-4o",
                        isCorrect: false,
                        whyWrongOrRight: "Cela dépasse largement la fenêtre de contexte et génère une latence et un coût prohibitifs."
                    ),
                    .init(
                        id: "opt-d",
                        badge: "D",
                        title: "Désactiver l'indexation et utiliser uniquement un générateur aléatoire",
                        isCorrect: false,
                        whyWrongOrRight: "Sans indexation structurée, le modèle hallucinerait sans contexte ancré."
                    )
                ],
                examTip: "À l'examen AI-102 : Pertinence RAG optimale = Hybrid Search (Keyword BM25 + Vector HNSW) + RRF + Semantic Ranker.",
                comparisonLeftTitle: "Recherche Vectorielle Pure",
                comparisonLeftBullets: [
                    "Excellente compréhension sémantique et multilingue",
                    "Moins précise sur les numéros de pièces, SKU ou acronymes exacts",
                    "Utilise l'algorithme HNSW (Cosine / DotProduct)"
                ],
                comparisonRightTitle: "Recherche Hybride + Semantic Ranker",
                comparisonRightBullets: [
                    "Combine BM25 lexical + Vecteurs via Reciprocal Rank Fusion (RRF)",
                    "Ré-ordonnancement L2 par modèle cross-encoder Microsoft",
                    "Génère des Captions et Highlights directement exploitables par le LLM"
                ],
                comparisonGoldenRule: "Pour tout scénario RAG d'entreprise dans AI-102, choisis toujours Hybrid Search + RRF + Semantic Ranker !"
            ),
            CertiGoNativeExerciseItem(
                id: "ai-102-qtype02",
                formatCode: "Q_TYPE_02",
                domainBadge: "🛡️ SÉCURITÉ IA & SERVICES AZURE AI FOUNDRY",
                subBadge: "GRILLE VISUELLE 2×2 · SERVICES AI-102",
                prompt: "Vous devez bloquer les injections de prompt (Prompt Shields) et vérifier l'ancrage factuel (Groundedness) des réponses générées.\nQuel service Azure AI activez-vous ?",
                mascotPose: .specialistSecurityEntra,
                options: [
                    .init(
                        id: "grid-safety",
                        badge: "A",
                        title: "AI Content Safety",
                        subtitle: "Prompt Shields & Groundedness",
                        assetName: "AzureServices/Cognitive-Services",
                        isCorrect: true,
                        whyWrongOrRight: "Azure AI Content Safety protège contre les jailbreaks (User Prompt & Document Attack) et vérifie que la réponse du LLM est ancrée sur les sources RAG."
                    ),
                    .init(
                        id: "grid-search",
                        badge: "B",
                        title: "Azure AI Search",
                        subtitle: "Index Vectoriel HNSW & BM25",
                        assetName: "AzureServices/Search-Services",
                        isCorrect: false,
                        whyWrongOrRight: "Azure AI Search indexe et recherche les chunks mais n'effectue pas l'analyse Prompt Shields."
                    ),
                    .init(
                        id: "grid-bot",
                        badge: "C",
                        title: "Azure Bot Service",
                        subtitle: "Canaux Teams, WebChat & Slack",
                        assetName: "AzureServices/Bot-Services",
                        isCorrect: false,
                        whyWrongOrRight: "Azure Bot Service connecte un bot aux canaux de communication."
                    ),
                    .init(
                        id: "grid-kv",
                        badge: "D",
                        title: "Azure Key Vault",
                        subtitle: "Coffre de clés & certificats",
                        assetName: "AzureServices/Key-Vaults",
                        isCorrect: false,
                        whyWrongOrRight: "Key Vault stocke les secrets mais n'analyse pas le contenu des prompts IA."
                    )
                ],
                examTip: "Bloquer les Jailbreaks / Prompt Injections dans les documents RAG = Azure AI Content Safety Prompt Shields."
            ),
            CertiGoNativeExerciseItem(
                id: "ai-102-qtype03",
                formatCode: "Q_TYPE_03",
                domainBadge: "📄 EXTRACTION DOCUMENTAIRE & PIPELINE RAG",
                subBadge: "SCHÉMA INTERACTIF · [ PDF Scannés & Tableaux ] ➔ [ ? ] ➔ [ AI Search ]",
                prompt: "Vos rapports financiers contiennent des tableaux complexes sur plusieurs pages à convertir en Markdown structuré avant vectorisation.\nQuelle brique placer dans [ ? ] ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "arch-docint",
                        badge: "A",
                        title: "Azure AI Document Intelligence (Modèle prebuilt-layout avec sortie Markdown)",
                        subtitle: "Extraction OCR haute précision des titres, paragraphes et tableaux en Markdown",
                        assetName: "AzureServices/Cognitive-Services",
                        isCorrect: true,
                        whyWrongOrRight: "Le modèle prebuilt-layout d'Azure AI Document Intelligence convertit les documents complexes en Markdown structuré idéal pour le chunking sémantique RAG."
                    ),
                    .init(
                        id: "arch-lb",
                        badge: "B",
                        title: "Azure Load Balancer (Couche 4 TCP)",
                        subtitle: "Répartition de trafic réseau",
                        assetName: "AzureServices/Load-Balancers",
                        isCorrect: false,
                        whyWrongOrRight: "Load Balancer est un composant réseau et n'extrait aucun texte de fichiers PDF."
                    ),
                    .init(
                        id: "arch-dns",
                        badge: "C",
                        title: "Azure Private DNS Zone",
                        subtitle: "Résolution DNS interne",
                        assetName: "AzureServices/DNS-Zones",
                        isCorrect: false,
                        whyWrongOrRight: "Private DNS résout les noms d'hôtes dans un VNet."
                    )
                ],
                examTip: "PDF complexes avec tableaux pour un pipeline RAG = Azure AI Document Intelligence (prebuilt-layout -> outputContentFormat = markdown)."
            ),
            CertiGoNativeExerciseItem(
                id: "ai-102-qtype04",
                formatCode: "Q_TYPE_04",
                domainBadge: "⌨️ AZURE CLI · DÉPLOIEMENT MODÈLE OPENAI",
                subBadge: "SAISIE CLAVIER CLI · AZURE AI FOUNDRY",
                prompt: "Vous déployez le modèle gpt-4o sur votre ressource Azure OpenAI aoai-prod.\nComplète la sous-commande Azure CLI :",
                mascotPose: .poseCLICoder,
                options: [
                    .init(
                        id: "cli-deployment",
                        badge: "CLI",
                        title: "deployment",
                        isCorrect: true,
                        whyWrongOrRight: "La commande exacte est « az cognitiveservices account deployment create -g RG-AI -n aoai-prod --deployment-name gpt-4o --model-name gpt-4o »."
                    )
                ],
                cliPrefix: "az cognitiveservices account",
                cliSuffix: "create -g RG-AI -n aoai-prod --deployment-name gpt-4o",
                expectedCLIInput: "deployment",
                cliSuggestionBricks: ["deployment", "network-rule", "identity", "keys"],
                examTip: "En production, privilégie le type de déploiement GlobalStandard ou ProvisionedManaged (PTU) pour garantir le débit TPM."
            ),
            CertiGoNativeExerciseItem(
                id: "ai-102-qtype05",
                formatCode: "Q_TYPE_05",
                domainBadge: "🧱 CONSTRUCTEUR CLI · RESSOURCE AZURE OPENAI",
                subBadge: "ASSEMBLAGE DE BRIQUES · PROVISIONNEMENT",
                prompt: "Vous provisionnez la ressource Azure OpenAI aoai-prod dans le groupe RG-AI.\nAssemble dans l'ordre la commande Azure CLI :",
                mascotPose: .specialistCLIContainers,
                options: [],
                wordBankTargetTokens: ["az", "cognitiveservices", "account", "create", "--kind OpenAI", "-n aoai-prod", "-g RG-AI"],
                wordBankAllBricks: ["az", "cognitiveservices", "account", "create", "--kind OpenAI", "-n aoai-prod", "-g RG-AI", "delete"],
                examTip: "Utilise --custom-domain lors de la création du compte Cognitive Services pour activer l'authentification Microsoft Entra ID (Managed Identity)."
            ),
            CertiGoNativeExerciseItem(
                id: "ai-102-qtype10",
                formatCode: "Q_TYPE_10",
                domainBadge: "☑️ CHOIX MULTIPLES · AUTHENTIFICATION SANS CLÉ",
                subBadge: "COCHE LES 2 ACTIONS OBLIGATOIRES (ZERO-TRUST AI)",
                prompt: "La politique de sécurité interdit l'utilisation de clés API (api-key) pour appeler Azure OpenAI depuis une Web App App Service.\nQuelles sont les 2 actions à réaliser ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "m-1",
                        badge: "1",
                        title: "Activer une Managed Identity sur l'App Service et lui attribuer le rôle RBAC « Cognitive Services OpenAI User »",
                        isCorrect: true,
                        whyWrongOrRight: "Le rôle Cognitive Services OpenAI User permet d'invoquer les endpoints d'inférence avec DefaultAzureCredential sans droits d'administration."
                    ),
                    .init(
                        id: "m-2",
                        badge: "2",
                        title: "Désactiver l'authentification par clé locale (disableLocalAuth = true) sur la ressource Azure OpenAI",
                        isCorrect: true,
                        whyWrongOrRight: "disableLocalAuth: true refuse tout appel utilisant un en-tête api-key et impose des jetons Entra ID."
                    ),
                    .init(
                        id: "m-3",
                        badge: "3",
                        title: "Publier la clé primaire Azure OpenAI dans le code JavaScript frontend du navigateur",
                        isCorrect: false,
                        whyWrongOrRight: "Exposer une clé API dans le code client permet à n'importe quel visiteur d'épuiser votre quota."
                    ),
                    .init(
                        id: "m-4",
                        badge: "4",
                        title: "Supprimer le déploiement du modèle gpt-4o",
                        isCorrect: false,
                        whyWrongOrRight: "Supprimer le déploiement mettrait l'application hors service."
                    )
                ],
                examTip: "Managed Identity + rôle RBAC « Cognitive Services OpenAI User » + disableLocalAuth: true = sécurité maximale AI-102."
            )
        ]
    }

    private static func kubernetesAndCloudNativeExercises(
        routeCode: String,
        lowerLessonId: String
    ) -> [CertiGoNativeExerciseItem] {
        return [
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype01",
                formatCode: "Q_TYPE_01",
                domainBadge: "☸️ KUBERNETES RBAC · ROLE VS CLUSTERROLE",
                subBadge: "SÉCURITÉ DU CLUSTER · MOINDRE PRIVILÈGE",
                prompt: "Un microservice exécuté avec le ServiceAccount payment-sa dans le namespace finance doit uniquement lire les Secrets de ce namespace.\nQuelle combinaison d'objets RBAC déployez-vous ?",
                mascotPose: .specialistCLIContainers,
                options: [
                    .init(
                        id: "opt-a",
                        badge: "A",
                        title: "Un ClusterRoleBinding associant payment-sa au rôle cluster-admin",
                        isCorrect: false,
                        whyWrongOrRight: "cluster-admin donne un contrôle absolu sur tous les namespaces et tous les nœuds du cluster."
                    ),
                    .init(
                        id: "opt-b",
                        badge: "B",
                        title: "Un Role (verbs: get, list sur secrets) et un RoleBinding dans le namespace finance",
                        isCorrect: true,
                        whyWrongOrRight: "Un Role et un RoleBinding sont strictement bornés au namespace finance, respectant le moindre privilège."
                    ),
                    .init(
                        id: "opt-c",
                        badge: "C",
                        title: "Un ConfigMap public monté sur le nœud maître",
                        isCorrect: false,
                        whyWrongOrRight: "Un ConfigMap stocke de la configuration non sensible et ne définit aucune permission RBAC."
                    ),
                    .init(
                        id: "opt-d",
                        badge: "D",
                        title: "Désactiver le contrôleur d'admission RBAC sur kube-apiserver",
                        isCorrect: false,
                        whyWrongOrRight: "Désactiver RBAC supprime tout contrôle d'accès sur l'API Kubernetes."
                    )
                ],
                examTip: "Permission limitée à 1 namespace = Role + RoleBinding. Permission sur tout le cluster (ou ressources non-namespacées comme Nodes/PV) = ClusterRole + ClusterRoleBinding.",
                comparisonLeftTitle: "livenessProbe",
                comparisonLeftBullets: [
                    "Détecte un deadlock ou blocage interne du processus",
                    "En cas d'échec : kubelet TUE et REDÉMARRE le conteneur",
                    "Ne doit jamais dépendre d'une base externe lente"
                ],
                comparisonRightTitle: "readinessProbe",
                comparisonRightBullets: [
                    "Vérifie si le pod est prêt à recevoir du trafic HTTP/TCP",
                    "En cas d'échec : retire l'IP du pod du Service (EndpointSlice) SANS redémarrer",
                    "Protège le pod pendant le chargement initial du cache"
                ],
                comparisonGoldenRule: "Pod lent à charger ou temporairement surchargé = readinessProbe (retire du trafic sans tuer). Conteneur figé en deadlock = livenessProbe (redémarre) !"
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype02",
                formatCode: "Q_TYPE_02",
                domainBadge: "🧱 ÉCOSYSTÈME CLOUD NATIVE & CNCF",
                subBadge: "GRILLE VISUELLE 2×2 · INFRASTRUCTURE & CONTENEURS",
                prompt: "Votre équipe provisionne des clusters multi-cloud via un fichier d'état (terraform.tfstate) avec verrouillage distant.\nQuel outil déclaratif Infrastructure-as-Code utilisez-vous ?",
                mascotPose: .specialistCLIContainers,
                options: [
                    .init(
                        id: "grid-tf",
                        badge: "A",
                        title: "Terraform",
                        subtitle: "IaC HCL, Plan, Apply & State Lock",
                        assetName: "BrandLogos/brand-terraform",
                        isCorrect: true,
                        whyWrongOrRight: "HashiCorp Terraform gère le cycle de vie déclaratif multi-cloud via des providers et un backend d'état verrouillé."
                    ),
                    .init(
                        id: "grid-k8s",
                        badge: "B",
                        title: "Kubernetes",
                        subtitle: "Orchestration de conteneurs & Pods",
                        assetName: "BrandLogos/brand-kubernetes",
                        isCorrect: false,
                        whyWrongOrRight: "Kubernetes orchestre les pods via etcd mais n'utilise pas de fichier terraform.tfstate."
                    ),
                    .init(
                        id: "grid-prom",
                        badge: "C",
                        title: "Prometheus",
                        subtitle: "Collecte de métriques TSDB & PromQL",
                        assetName: "BrandLogos/brand-prometheus",
                        isCorrect: false,
                        whyWrongOrRight: "Prometheus collecte et interroge des séries temporelles de supervision."
                    ),
                    .init(
                        id: "grid-docker",
                        badge: "D",
                        title: "Docker / CRI",
                        subtitle: "Build d'images OCI multi-stage",
                        assetName: "BrandLogos/brand-docker",
                        isCorrect: false,
                        whyWrongOrRight: "Docker construit des images de conteneurs OCI."
                    )
                ],
                examTip: "En équipe sur Terraform : stocke toujours le state dans un backend distant chiffré avec State Locking."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype03",
                formatCode: "Q_TYPE_03",
                domainBadge: "🛡️ ISOLATION RÉSEAU POD-À-POD",
                subBadge: "SCHÉMA INTERACTIF · [ Pod Frontend ] ➔ [ ? ] ➔ [ Pod Postgres :5432 ]",
                prompt: "Seuls les pods portant le label role=api doivent pouvoir joindre le port TCP 5432 du pod PostgreSQL.\nQuelle ressource Kubernetes placer dans [ ? ] ?",
                mascotPose: .specialistNetworkVNet,
                options: [
                    .init(
                        id: "arch-netpol",
                        badge: "A",
                        title: "Kubernetes NetworkPolicy (podSelector + ingress from podSelector: role=api, port 5432)",
                        subtitle: "Pare-feu L3/L4 natif appliqué par le plugin CNI (Calico / Cilium)",
                        assetName: "BrandLogos/brand-kubernetes",
                        isCorrect: true,
                        whyWrongOrRight: "Dès qu'une NetworkPolicy cible un pod en Ingress, tout trafic non explicitement autorisé par ses règles ingress est bloqué."
                    ),
                    .init(
                        id: "arch-storage",
                        badge: "B",
                        title: "PersistentVolumeClaim (ReadWriteOnce)",
                        subtitle: "Montage de volume de stockage bloc",
                        assetName: "BrandLogos/brand-docker",
                        isCorrect: false,
                        whyWrongOrRight: "Un PVC gère le stockage persistant des pods et ne filtre aucun flux réseau TCP."
                    ),
                    .init(
                        id: "arch-prom",
                        badge: "C",
                        title: "Prometheus ServiceMonitor",
                        subtitle: "Scraping de métriques HTTP /metrics",
                        assetName: "BrandLogos/brand-prometheus",
                        isCorrect: false,
                        whyWrongOrRight: "ServiceMonitor configure la collecte de métriques et n'isole pas le réseau."
                    )
                ],
                examTip: "Attention CKA : une NetworkPolicy n'a aucun effet si le plugin CNI du cluster ne supporte pas l'application des NetworkPolicies (ex: Flannel seul vs Calico/Cilium)."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype04",
                formatCode: "Q_TYPE_04",
                domainBadge: "⌨️ SAUVEGARDE ETCD (EXAMEN CKA)",
                subBadge: "SAISIE CLAVIER CLI · CONTROL PLANE BACKUP",
                prompt: "Vous sauvegardez la base etcd du cluster Kubernetes dans /var/lib/backup/etcd.db.\nComplète la sous-commande etcdctl (API v3) :",
                mascotPose: .poseCLICoder,
                options: [
                    .init(
                        id: "cli-snapshot",
                        badge: "CLI",
                        title: "snapshot",
                        isCorrect: true,
                        whyWrongOrRight: "La commande exacte est « ETCDCTL_API=3 etcdctl snapshot save /var/lib/backup/etcd.db --endpoints=https://127.0.0.1:2379 --cacert=... --cert=... --key=... »."
                    )
                ],
                cliPrefix: "ETCDCTL_API=3 etcdctl",
                cliSuffix: "save /var/lib/backup/etcd.db --cacert=/etc/kubernetes/pki/etcd/ca.crt",
                expectedCLIInput: "snapshot",
                cliSuggestionBricks: ["snapshot", "member", "endpoint", "defrag"],
                examTip: "La sauvegarde et la restauration d'etcd (etcdctl snapshot save / restore) tombent à presque chaque session de l'examen CKA !"
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype05",
                formatCode: "Q_TYPE_05",
                domainBadge: "🧱 MAINTENANCE DE NŒUD KUBERNETES",
                subBadge: "ASSEMBLAGE DE BRIQUES · DRAIN SÉCURISÉ",
                prompt: "Vous devez évacuer les pods du nœud worker-02 avant une mise à jour du noyau Linux.\nAssemble dans l'ordre la commande kubectl :",
                mascotPose: .specialistCLIContainers,
                options: [],
                wordBankTargetTokens: ["kubectl", "drain", "worker-02", "--ignore-daemonsets", "--delete-emptydir-data"],
                wordBankAllBricks: ["kubectl", "drain", "worker-02", "--ignore-daemonsets", "--delete-emptydir-data", "uncordon", "delete"],
                examTip: "Après la maintenance du nœud, exécute « kubectl uncordon worker-02 » pour autoriser à nouveau le scheduling de nouveaux pods."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype10",
                formatCode: "Q_TYPE_10",
                domainBadge: "☑️ CHOIX MULTIPLES · PROBES & SCHEDULING K8S",
                subBadge: "COCHE LES 2 AFFIRMATIONS EXACTES",
                prompt: "Vous configurez la résilience et le placement des pods critiques sur votre cluster.\nQuelles sont les 2 affirmations exactes dans Kubernetes ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "m-1",
                        badge: "1",
                        title: "Si une readinessProbe échoue, l'adresse IP du pod est retirée des Endpoints du Service sans redémarrer le conteneur",
                        isCorrect: true,
                        whyWrongOrRight: "readinessProbe isole temporairement le pod du trafic entrant tant qu'il n'est pas prêt."
                    ),
                    .init(
                        id: "m-2",
                        badge: "2",
                        title: "Un pod ne peut être planifié sur un nœud possédant un Taint NoSchedule que s'il déclare la Toleration correspondante",
                        isCorrect: true,
                        whyWrongOrRight: "Les Taints (sur les nœuds) et Tolerations (sur les pods) empêchent l'exécution de pods non autorisés sur des nœuds dédiés."
                    ),
                    .init(
                        id: "m-3",
                        badge: "3",
                        title: "Un ConfigMap chiffre automatiquement les mots de passe avec une clé HSM par défaut",
                        isCorrect: false,
                        whyWrongOrRight: "Les ConfigMaps sont destinés aux données non confidentielles ; utilisez un Secret avec EncryptionConfiguration au repos."
                    ),
                    .init(
                        id: "m-4",
                        badge: "4",
                        title: "Les DaemonSets sont automatiquement supprimés lors d'un kubectl drain --ignore-daemonsets",
                        isCorrect: false,
                        whyWrongOrRight: "L'option --ignore-daemonsets conserve justement les pods de DaemonSet (CNI, agents de logs) sur le nœud."
                    )
                ],
                examTip: "Taints sur le Node + Tolerations sur le Pod = contrôle d'exclusion ; Node Affinity = attraction vers des nœuds spécifiques."
            )
        ]
    }

    private static func copilotAndClaudeExercises(
        routeCode: String,
        lowerLessonId: String
    ) -> [CertiGoNativeExerciseItem] {
        return [
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype01",
                formatCode: "Q_TYPE_01",
                domainBadge: "🤖 INSTRUCTIONS PERSONNALISÉES & CONTEXTE IA",
                subBadge: "INGÉNIERIE AGENTIQUE · \(routeCode)",
                prompt: "Votre équipe souhaite que GitHub Copilot et les agents de code respectent automatiquement vos règles d'architecture Clean Architecture, vos conventions de nommage et vos commandes de test sur tout le dépôt.\nQuel fichier versionnez-vous ?",
                mascotPose: .specialistAICoach,
                options: [
                    .init(
                        id: "opt-a",
                        badge: "A",
                        title: "Le fichier .github/copilot-instructions.md (complété par .github/instructions/*.instructions.md avec applyTo)",
                        isCorrect: true,
                        whyWrongOrRight: "GitHub Copilot injecte automatiquement .github/copilot-instructions.md ainsi que les instructions ciblées par glob applyTo dans le contexte."
                    ),
                    .init(
                        id: "opt-b",
                        badge: "B",
                        title: "Un fichier binaire .DS_Store à la racine du poste développeur",
                        isCorrect: false,
                        whyWrongOrRight: ".DS_Store est un fichier système macOS ignoré par Git et par Copilot."
                    ),
                    .init(
                        id: "opt-c",
                        badge: "C",
                        title: "L'historique local du presse-papiers Windows/macOS",
                        isCorrect: false,
                        whyWrongOrRight: "Le presse-papiers local n'est ni versionné ni partagé avec l'équipe."
                    ),
                    .init(
                        id: "opt-d",
                        badge: "D",
                        title: "Désactiver toutes les vérifications CI/CD GitHub Actions",
                        isCorrect: false,
                        whyWrongOrRight: "Les vérifications CI restent indispensables pour valider le code produit avec l'IA."
                    )
                ],
                examTip: ".github/copilot-instructions.md s'applique à tout le dépôt ; .github/instructions/*.instructions.md avec frontmatter applyTo cible des sous-dossiers précis.",
                comparisonLeftTitle: "Prompt Caching (ephemeral)",
                comparisonLeftBullets: [
                    "Met en cache le préfixe statique (System Prompt, Outils MCP, Docs)",
                    "Réduit le coût des tokens de lecture jusqu'à 90 % et la latence de 85 %",
                    "Nécessite de placer le contenu statique AU DÉBUT de la requête"
                ],
                comparisonRightTitle: "Model Context Protocol (MCP)",
                comparisonRightBullets: [
                    "Standard ouvert connectant le modèle aux outils, ressources et prompts",
                    "Chaque outil définit un input_schema JSON Schema strict",
                    "Le client valide et contrôle les autorisations avant toute exécution"
                ],
                comparisonGoldenRule: "Structure tes appels agents avec les définitions d'outils MCP et le prompt système au début (avec cache_control: ephemeral), et les messages dynamiques à la fin !"
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype02",
                formatCode: "Q_TYPE_02",
                domainBadge: "✦ ARCHITECTURE CLAUDE, COPILOT & MCP",
                subBadge: "GRILLE VISUELLE 2×2 · PLATEFORMES IA",
                prompt: "Vous souhaitez exposer des outils typés (tools), des ressources (resources) et des templates à un agent IA via un standard ouvert.\nQuel mécanisme utilisez-vous ?",
                mascotPose: .specialistAICoach,
                options: [
                    .init(
                        id: "grid-mcp",
                        badge: "A",
                        title: "Serveur MCP",
                        subtitle: "Model Context Protocol JSON-RPC",
                        assetName: "BrandLogos/brand-anthropic",
                        isCorrect: true,
                        whyWrongOrRight: "Le Model Context Protocol (MCP) standardise la découverte et l'invocation sécurisée d'outils et de sources de données par les agents IA."
                    ),
                    .init(
                        id: "grid-copilot",
                        badge: "B",
                        title: "GitHub Copilot",
                        subtitle: "Complétion & Agent de code IDE",
                        assetName: "BrandLogos/brand-github-copilot",
                        isCorrect: false,
                        whyWrongOrRight: "GitHub Copilot est un hôte/client consommateur de serveurs MCP, pas le protocole lui-même."
                    ),
                    .init(
                        id: "grid-docker",
                        badge: "C",
                        title: "Dockerfile",
                        subtitle: "Image de conteneur statique",
                        assetName: "BrandLogos/brand-docker",
                        isCorrect: false,
                        whyWrongOrRight: "Un Dockerfile décrit la construction d'une image de conteneur."
                    ),
                    .init(
                        id: "grid-prom",
                        badge: "D",
                        title: "Prometheus",
                        subtitle: "Collecte de métriques TSDB",
                        assetName: "BrandLogos/brand-prometheus",
                        isCorrect: false,
                        whyWrongOrRight: "Prometheus est un système de monitoring de séries temporelles."
                    )
                ],
                examTip: "Un serveur MCP expose 3 primitives principales : Tools (actions exécutables), Resources (données contextuelles) et Prompts (modèles d'interaction)."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype03",
                formatCode: "Q_TYPE_03",
                domainBadge: "⚡ OPTIMISATION DU PROMPT CACHING",
                subBadge: "SCHÉMA INTERACTIF · [ Tools + System ] ➔ [ ? ] ➔ [ Message Utilisateur ]",
                prompt: "Votre agent effectue des appels API multi-tours avec un large contexte documentaire.\nComment structurer la requête pour maximiser le taux de Cache Hit ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "arch-cache-prefix",
                        badge: "A",
                        title: "Placer Tools + System Prompt + Documents fixes en préfixe avec cache_control: ephemeral, puis le tour dynamique à la fin",
                        subtitle: "Le cache fonctionne par correspondance exacte de préfixe (Prefix Matching)",
                        assetName: "BrandLogos/brand-claude-ai",
                        isCorrect: true,
                        whyWrongOrRight: "Le Prompt Caching repose sur un préfixe identique d'un appel à l'autre : toute modification en début de prompt invalide le cache aval."
                    ),
                    .init(
                        id: "arch-cache-random",
                        badge: "B",
                        title: "Insérer un horodatage aléatoire à la ligne 1 du System Prompt à chaque requête",
                        subtitle: "Invalide 100 % du préfixe à chaque appel",
                        assetName: "BrandLogos/brand-openai",
                        isCorrect: false,
                        whyWrongOrRight: "Un timestamp dynamique au tout début du System Prompt change le préfixe à chaque seconde et empêche tout Cache Hit."
                    ),
                    .init(
                        id: "arch-cache-none",
                        badge: "C",
                        title: "Mélanger aléatoirement l'ordre des définitions d'outils JSON à chaque tour",
                        subtitle: "Casse l'empreinte cryptographique du bloc tools",
                        assetName: "BrandLogos/brand-github",
                        isCorrect: false,
                        whyWrongOrRight: "Changer l'ordre des outils modifie les tokens initiaux et provoque un Cache Miss."
                    )
                ],
                examTip: "Règle d'or Prompt Caching : ne mets JAMAIS d'horodatage dynamique en début de System Prompt ; garde le préfixe 100 % déterministe !"
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype04",
                formatCode: "Q_TYPE_04",
                domainBadge: "⌨️ GITHUB CLI & COPILOT",
                subBadge: "SAISIE CLAVIER CLI · EXPLICATION DE COMMANDE",
                prompt: "Vous souhaitez analyser une commande Git complexe directement dans votre terminal.\nComplète la sous-commande gh copilot :",
                mascotPose: .poseCLICoder,
                options: [
                    .init(
                        id: "cli-explain",
                        badge: "CLI",
                        title: "explain",
                        isCorrect: true,
                        whyWrongOrRight: "La commande « gh copilot explain » analyse et explique pas à pas n'importe quelle commande ou pipeline shell."
                    )
                ],
                cliPrefix: "gh copilot",
                cliSuffix: "\"git log --oneline --graph --decorate\"",
                expectedCLIInput: "explain",
                cliSuggestionBricks: ["explain", "suggest", "delete", "reset"],
                examTip: "gh copilot explain explique une commande existante ; gh copilot suggest construit une commande à partir d'une intention en langage naturel."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype05",
                formatCode: "Q_TYPE_05",
                domainBadge: "🧱 GOUVERNANCE GITHUB COPILOT ENTERPRISE",
                subBadge: "ASSEMBLAGE DE BRIQUES · EXCLUSION DE CONTENU",
                prompt: "Vous interdisez à Copilot de lire les fichiers .env et le dossier secrets/.\nAssemble la règle YAML de Content Exclusion :",
                mascotPose: .specialistCLIContainers,
                options: [],
                wordBankTargetTokens: ["paths:", "- \"**/.env\"", "- \"/secrets/**\""],
                wordBankAllBricks: ["paths:", "- \"**/.env\"", "- \"/secrets/**\"", "allow_all:", "true"],
                examTip: "Content Exclusion dans GitHub Copilot Business/Enterprise bloque l'accès aux fichiers sensibles dans l'IDE et dans Copilot Chat."
            ),
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype10",
                formatCode: "Q_TYPE_10",
                domainBadge: "☑️ CHOIX MULTIPLES · SÉCURITÉ & PROPRIÉTÉ INTELLECTUELLE",
                subBadge: "COCHE LES 2 GARANTIES GITHUB COPILOT BUSINESS",
                prompt: "Vous déployez GitHub Copilot Business pour 500 développeurs en entreprise.\nQuelles sont les 2 configurations clés de gouvernance à activer ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "m-1",
                        badge: "1",
                        title: "Régler « Suggestions matching public code » sur Blocked pour filtrer les séquences identiques de ~150+ caractères du code public",
                        isCorrect: true,
                        whyWrongOrRight: "Le filtre de duplication bloque les suggestions correspondant mot pour mot à du code public sur GitHub."
                    ),
                    .init(
                        id: "m-2",
                        badge: "2",
                        title: "Configurer Content Exclusion sur les dépôts pour exclure les fichiers de clés, certificats et secrets",
                        isCorrect: true,
                        whyWrongOrRight: "Les fichiers exclus ne sont jamais envoyés dans les prompts d'inférence ni utilisés pour les suggestions."
                    ),
                    .init(
                        id: "m-3",
                        badge: "3",
                        title: "Autoriser l'entraînement des modèles publics globaux sur le code privé de l'entreprise par défaut",
                        isCorrect: false,
                        whyWrongOrRight: "GitHub Copilot Business et Enterprise n'entraînent JAMAIS les modèles de base sur le code privé des clients."
                    ),
                    .init(
                        id: "m-4",
                        badge: "4",
                        title: "Supprimer les revues de code et les analyses CodeQL sur les Pull Requests",
                        isCorrect: false,
                        whyWrongOrRight: "Le code assisté par IA doit toujours passer par les revues humaines et l'analyse de sécurité CodeQL."
                    )
                ],
                examTip: "Dans Copilot Business/Enterprise : 0 entraînement sur votre code privé + filtre « Suggestions matching public code = Blocked » + Content Exclusion."
            )
        ]
    }

    private static func az104Exercises(
        routeCode: String,
        lowerLessonId: String,
        lowerTitle: String
    ) -> [CertiGoNativeExerciseItem] {
        // Unit 2 (`u2-*`): Hybrid Networking, Private Endpoint, Private DNS, VNet Peering & WAF
        if lowerLessonId.contains("u2") {
            return [
                CertiGoNativeExerciseItem(
                    id: "az-104-u2-qtype01",
                    formatCode: "Q_TYPE_01",
                    domainBadge: "🌐 VNET PEERING & TRANSIT DE PASSERELLE",
                    subBadge: "RÉSEAUX HYBRIDES AZ-104 · HUB & SPOKE",
                    prompt: "Votre architecture Hub-and-Spoke possède une passerelle ExpressRoute dans VNet-Hub et des charges de travail dans VNet-Spoke1.\nQuelles options cochez-vous sur le VNet Peering pour partager la passerelle ?",
                    mascotPose: .specialistNetworkVNet,
                    options: [
                        .init(
                            id: "opt-a",
                            badge: "A",
                            title: "Déployer une seconde passerelle ExpressRoute dans chaque VNet-Spoke",
                            isCorrect: false,
                            whyWrongOrRight: "Déployer une passerelle par Spoke est inutilement coûteux alors que le transit de passerelle partage celle du Hub."
                        ),
                        .init(
                            id: "opt-b",
                            badge: "B",
                            title: "Activer « Allow gateway transit » sur VNet-Hub ET « Use remote gateways » sur VNet-Spoke1",
                            isCorrect: true,
                            whyWrongOrRight: "Le Hub autorise le transit de sa passerelle et le Spoke configure l'utilisation de la passerelle distante."
                        ),
                        .init(
                            id: "opt-c",
                            badge: "C",
                            title: "Rendre le VNet Peering automatiquement transitif sans passerelle ni pare-feu NVA",
                            isCorrect: false,
                            whyWrongOrRight: "Le VNet Peering n'est jamais transitif par défaut : Spoke1 et Spoke2 ne communiquent pas sans UDR vers une NVA/Firewall ou Virtual WAN."
                        ),
                        .init(
                            id: "opt-d",
                            badge: "D",
                            title: "Ouvrir le port RDP 3389 sur Internet",
                            isCorrect: false,
                            whyWrongOrRight: "Exposer RDP sur Internet est une faille de sécurité et n'établit aucun routage hybride."
                        )
                    ],
                    examTip: "Hub = Allow gateway transit ; Spoke = Use remote gateways (et le Spoke ne doit posséder aucune passerelle locale) !"
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u2-qtype02",
                    formatCode: "Q_TYPE_02",
                    domainBadge: "🔒 ISOLATION PAAS & DNS PRIVÉ",
                    subBadge: "GRILLE VISUELLE 2×2 · RÉSEAU AZURE",
                    prompt: "Vos VNets appairés doivent résoudre moncoffre.vault.azure.net vers l'IP privée 10.1.0.5 d'un Private Endpoint.\nQuel composant Azure est indispensable ?",
                    mascotPose: .specialistNetworkVNet,
                    options: [
                        .init(
                            id: "grid-dns",
                            badge: "A",
                            title: "Private DNS Zone",
                            subtitle: "privatelink.* + Virtual Network Link",
                            assetName: "AzureServices/DNS-Zones",
                            isCorrect: true,
                            whyWrongOrRight: "Une zone Azure Private DNS (ex: privatelink.vaultcore.azure.net) liée au VNet résout le CNAME en IP privée 10.x."
                        ),
                        .init(
                            id: "grid-nat",
                            badge: "B",
                            title: "NAT Gateway",
                            subtitle: "SNAT sortant vers Internet",
                            assetName: "AzureServices/NAT",
                            isCorrect: false,
                            whyWrongOrRight: "NAT Gateway gère la sortie Internet SNAT et non la résolution DNS privée."
                        ),
                        .init(
                            id: "grid-lb",
                            badge: "C",
                            title: "Load Balancer",
                            subtitle: "Équilibrage TCP/UDP Couche 4",
                            assetName: "AzureServices/Load-Balancers",
                            isCorrect: false,
                            whyWrongOrRight: "Load Balancer répartit les flux TCP/UDP mais ne résout pas les enregistrements DNS."
                        ),
                        .init(
                            id: "grid-bastion",
                            badge: "D",
                            title: "Key Vault",
                            subtitle: "Stockage de secrets HSM",
                            assetName: "AzureServices/Key-Vaults",
                            isCorrect: false,
                            whyWrongOrRight: "Key Vault est la ressource cible à isoler, pas le serveur DNS."
                        )
                    ],
                    examTip: "Sans Virtual Network Link vers la zone privatelink.*, les VMs résolvent toujours l'IP publique et sont bloquées par le pare-feu PaaS."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u2-qtype03",
                    formatCode: "Q_TYPE_03",
                    domainBadge: "🛡️ PARE-FEU APPLICATIF WAF COUCHE 7",
                    subBadge: "SCHÉMA INTERACTIF · [ Clients HTTPS ] ➔ [ ? ] ➔ [ Pool Backend VNet ]",
                    prompt: "Vous devez assurer la terminaison TLS, le routage par URL (/api vs /static) et la protection WAF OWASP dans une région.\nQuelle brique placer dans [ ? ] ?",
                    mascotPose: .specialistNetworkVNet,
                    options: [
                        .init(
                            id: "arch-appgw",
                            badge: "A",
                            title: "Azure Application Gateway v2 (WAF_v2)",
                            subtitle: "Répartiteur HTTP/HTTPS régional Couche 7 avec WAF intégré",
                            assetName: "AzureServices/Application-Gateways",
                            isCorrect: true,
                            whyWrongOrRight: "Application Gateway v2 gère le routage URL Path-based, le SSL offloading et l'inspection WAF OWASP."
                        ),
                        .init(
                            id: "arch-lb",
                            badge: "B",
                            title: "Azure Load Balancer Standard (Couche 4)",
                            subtitle: "Routage par tuple IP/Port TCP/UDP sans visibilité HTTP",
                            assetName: "AzureServices/Load-Balancers",
                            isCorrect: false,
                            whyWrongOrRight: "Load Balancer opère en couche 4 et ne connaît ni les URLs ni les en-têtes HTTP."
                        ),
                        .init(
                            id: "arch-nat",
                            badge: "C",
                            title: "Azure NAT Gateway",
                            subtitle: "Sortie Internet SNAT uniquement",
                            assetName: "AzureServices/NAT",
                            isCorrect: false,
                            whyWrongOrRight: "NAT Gateway ne reçoit aucun trafic entrant depuis Internet."
                        )
                    ],
                    examTip: "Couche 7 Régional = Application Gateway. Couche 7 Global Multi-Régions = Azure Front Door."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u2-qtype04",
                    formatCode: "Q_TYPE_04",
                    domainBadge: "⌨️ AZURE CLI · APPAIRAGE VNET PEERING",
                    subBadge: "SAISIE CLAVIER CLI · CONNECTIVITÉ INTER-VNET",
                    prompt: "Vous interconnectez VNet-Hub et VNet-Spoke en faible latence sur le backbone Azure.\nComplète la sous-commande Azure CLI :",
                    mascotPose: .poseCLICoder,
                    options: [
                        .init(
                            id: "cli-peering",
                            badge: "CLI",
                            title: "peering",
                            isCorrect: true,
                            whyWrongOrRight: "La commande exacte est « az network vnet peering create -g RG-Net -n HubToSpoke --vnet-name VNet-Hub --remote-vnet VNet-Spoke --allow-vnet-access »."
                        )
                    ],
                    cliPrefix: "az network vnet",
                    cliSuffix: "create -g RG-Net -n HubToSpoke --vnet-name VNet-Hub --allow-vnet-access",
                    expectedCLIInput: "peering",
                    cliSuggestionBricks: ["peering", "subnet", "dns", "nat"],
                    examTip: "Un VNet Peering doit être créé dans les DEUX sens (Hub -> Spoke ET Spoke -> Hub) avec des plages CIDR sans chevauchement !"
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u2-qtype05",
                    formatCode: "Q_TYPE_05",
                    domainBadge: "🧱 CONSTRUCTEUR CLI · ZONE DNS PRIVÉE",
                    subBadge: "ASSEMBLAGE DE BRIQUES · PRIVATELINK",
                    prompt: "Vous configurez la résolution DNS interne pour un Private Endpoint Blob Storage.\nAssemble dans l'ordre la commande Azure CLI :",
                    mascotPose: .specialistCLIContainers,
                    options: [],
                    wordBankTargetTokens: ["az", "network", "private-dns", "zone", "create", "-g RG-Net", "-n privatelink.blob.core.windows.net"],
                    wordBankAllBricks: ["az", "network", "private-dns", "zone", "create", "-g RG-Net", "-n privatelink.blob.core.windows.net", "delete"],
                    examTip: "Le nom exact de la zone privée pour Blob Storage est privatelink.blob.core.windows.net (et privatelink.vaultcore.azure.net pour Key Vault)."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u2-qtype10",
                    formatCode: "Q_TYPE_10",
                    domainBadge: "☑️ CHOIX MULTIPLES · ÉVALUATION NSG",
                    subBadge: "COCHE LES 2 RÈGLES EXACTES SUR LES NSG",
                    prompt: "Une VM possède un NSG attaché à son sous-réseau (NSG-Subnet) et un NSG attaché à sa carte réseau (NSG-NIC).\nComment Azure évalue-t-il le trafic HTTPS (TCP 443) entrant ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "m-1",
                            badge: "1",
                            title: "En trafic entrant (Inbound), Azure évalue d'abord NSG-Subnet puis NSG-NIC",
                            isCorrect: true,
                            whyWrongOrRight: "Le paquet venant d'Internet traverse d'abord le sous-réseau avant d'atteindre la carte réseau NIC."
                        ),
                        .init(
                            id: "m-2",
                            badge: "2",
                            title: "Le port TCP 443 doit être explicitement autorisé dans NSG-Subnet ET dans NSG-NIC pour que le flux passe",
                            isCorrect: true,
                            whyWrongOrRight: "Si l'un des deux NSG bloque le paquet, la connexion est immédiatement rejetée."
                        ),
                        .init(
                            id: "m-3",
                            badge: "3",
                            title: "La règle ayant le numéro de priorité le plus élevé (ex: 4000) l'emporte sur la priorité 100",
                            isCorrect: false,
                            whyWrongOrRight: "Dans un NSG, le plus petit numéro (ex: 100) a la priorité la plus haute !"
                        ),
                        .init(
                            id: "m-4",
                            badge: "4",
                            title: "Les NSG sont sans état (stateless) et nécessitent d'ouvrir manuellement tous les ports éphémères de retour",
                            isCorrect: false,
                            whyWrongOrRight: "Les NSG Azure sont stateful : si le flux entrant est autorisé, la réponse sortante de la même session est automatiquement autorisée."
                        )
                    ],
                    examTip: "Inbound = Subnet -> NIC ; Outbound = NIC -> Subnet. Les NSG sont Stateful et la priorité 100 passe avant 200."
                )
            ]
        }

        // Unit 3 (`u3-*`): Storage Redundancy (RA-GRS), AKS Autoscaling, Backup & Site Recovery
        if lowerLessonId.contains("u3") {
            return [
                CertiGoNativeExerciseItem(
                    id: "az-104-u3-qtype01",
                    formatCode: "Q_TYPE_01",
                    domainBadge: "💾 REDONDANCE STOCKAGE · LRS, ZRS, GRS & RA-GRS",
                    subBadge: "CONTINUITÉ D'ACTIVITÉ AZ-104 · HAUTE DISPONIBILITÉ",
                    prompt: "Vos applications clientes doivent pouvoir lire immédiatement les blobs depuis un point de terminaison secondaire dans la région jumelée si la région primaire subit une panne totale, avant même tout basculement Microsoft.\nQuelle redondance configurez-vous ?",
                    mascotPose: .specialistCloudAzure,
                    options: [
                        .init(
                            id: "opt-a",
                            badge: "A",
                            title: "ZRS (Zone-Redundant Storage)",
                            isCorrect: false,
                            whyWrongOrRight: "ZRS réplique sur 3 zones d'une seule région et ne protège pas contre la perte complète de la région."
                        ),
                        .init(
                            id: "opt-b",
                            badge: "B",
                            title: "RA-GRS (Read-Access Geo-Redundant Storage) ou RA-GZRS",
                            isCorrect: true,
                            whyWrongOrRight: "RA-GRS expose en permanence le point de terminaison en lecture seule <account>-secondary.blob.core.windows.net dans la région secondaire."
                        ),
                        .init(
                            id: "opt-c",
                            badge: "C",
                            title: "LRS (Locally Redundant Storage)",
                            isCorrect: false,
                            whyWrongOrRight: "LRS garde 3 copies dans un seul datacenter physique."
                        ),
                        .init(
                            id: "opt-d",
                            badge: "D",
                            title: "GRS standard sans option Read-Access",
                            isCorrect: false,
                            whyWrongOrRight: "Avec GRS standard, la région secondaire n'est pas lisible tant qu'un failover complet n'est pas déclenché."
                        )
                    ],
                    examTip: "Lecture immédiate sur la région secondaire sans attendre de failover = RA-GRS / RA-GZRS."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u3-qtype02",
                    formatCode: "Q_TYPE_02",
                    domainBadge: "🔄 SAUVEGARDE, AKS & SUPERVISION AZURE",
                    subBadge: "GRILLE VISUELLE 2×2 · RÉSILIENCE AZ-104",
                    prompt: "Vous devez centraliser les sauvegardes de VMs (Azure Backup) et la réplication continue inter-régions (Site Recovery).\nQuel service Azure provisionnez-vous ?",
                    mascotPose: .specialistCloudAzure,
                    options: [
                        .init(
                            id: "grid-rsv",
                            badge: "A",
                            title: "Recovery Services Vault",
                            subtitle: "Backup, Soft Delete & ASR",
                            assetName: "AzureServices/Recovery-Services-Vaults",
                            isCorrect: true,
                            whyWrongOrRight: "Le coffre Recovery Services Vault centralise les sauvegardes VM, le Soft Delete (14j minimum) et la réplication Site Recovery."
                        ),
                        .init(
                            id: "grid-aks",
                            badge: "B",
                            title: "Kubernetes Service",
                            subtitle: "Clusters AKS & Node Pools",
                            assetName: "AzureServices/Kubernetes-Services",
                            isCorrect: false,
                            whyWrongOrRight: "AKS orchestre les conteneurs Kubernetes mais n'est pas le coffre de sauvegarde des VMs."
                        ),
                        .init(
                            id: "grid-monitor",
                            badge: "C",
                            title: "Azure Monitor",
                            subtitle: "Log Analytics, KQL & Action Groups",
                            assetName: "AzureServices/Monitor",
                            isCorrect: false,
                            whyWrongOrRight: "Azure Monitor supervise les métriques et journaux KQL."
                        ),
                        .init(
                            id: "grid-appgw",
                            badge: "D",
                            title: "Application Gateway",
                            subtitle: "Load Balancer L7 + WAF",
                            assetName: "AzureServices/Application-Gateways",
                            isCorrect: false,
                            whyWrongOrRight: "Application Gateway est un répartiteur de charge HTTP/HTTPS."
                        )
                    ],
                    examTip: "Pour restaurer des VMs dans la région jumelée à partir d'une sauvegarde, active Cross-Region Restore (CRR) sur un coffre configuré en GRS."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u3-qtype03",
                    formatCode: "Q_TYPE_03",
                    domainBadge: "☸️ AUTOSCALING AKS · HPA VS CLUSTER AUTOSCALER",
                    subBadge: "SCHÉMA INTERACTIF · [ HPA crée 10 Pods ] ➔ [ Pods Pending ] ➔ [ ? ]",
                    prompt: "Le Horizontal Pod Autoscaler (HPA) vient d'ajouter 10 nouveaux pods, mais ils restent bloqués en état Pending par manque de CPU sur les nœuds.\nQuel composant placer en [ ? ] ?",
                    mascotPose: .specialistCLIContainers,
                    options: [
                        .init(
                            id: "arch-ca",
                            badge: "A",
                            title: "Cluster Autoscaler sur le Node Pool AKS (--enable-cluster-autoscaler)",
                            subtitle: "Provisionne automatiquement de nouveaux nœuds VMSS quand des pods sont Pending",
                            assetName: "AzureServices/Kubernetes-Services",
                            isCorrect: true,
                            whyWrongOrRight: "Le Cluster Autoscaler surveille les pods non planifiables (Pending) et ajoute des instances au Virtual Machine Scale Set sous-jacent."
                        ),
                        .init(
                            id: "arch-dns",
                            badge: "B",
                            title: "Azure DNS Zone",
                            subtitle: "Résolution de noms publics",
                            assetName: "AzureServices/DNS-Zones",
                            isCorrect: false,
                            whyWrongOrRight: "Azure DNS ne provisionne aucun nœud de calcul."
                        ),
                        .init(
                            id: "arch-policy",
                            badge: "C",
                            title: "Azure Policy",
                            subtitle: "Audit de conformité",
                            assetName: "AzureServices/Policy",
                            isCorrect: false,
                            whyWrongOrRight: "Azure Policy contrôle la conformité mais ne met pas à l'échelle les VMSS."
                        )
                    ],
                    examTip: "HPA ajuste le nombre de Pods ; Cluster Autoscaler ajuste le nombre de Nœuds VMSS !"
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u3-qtype04",
                    formatCode: "Q_TYPE_04",
                    domainBadge: "⌨️ AZURE CLI · GESTION DU CYCLE DE VIE BLOB",
                    subBadge: "SAISIE CLAVIER CLI · ARCHIVAGE AUTOMATIQUE",
                    prompt: "Vous automatisez la transition des blobs Hot vers Cool puis Archive via un fichier JSON.\nComplète la sous-commande Azure CLI :",
                    mascotPose: .poseCLICoder,
                    options: [
                        .init(
                            id: "cli-mgmt-policy",
                            badge: "CLI",
                            title: "management-policy",
                            isCorrect: true,
                            whyWrongOrRight: "La commande exacte est « az storage account management-policy create --account-name stprod -g RG-Prod --policy @policy.json »."
                        )
                    ],
                    cliPrefix: "az storage account",
                    cliSuffix: "create --account-name stprod -g RG-Prod --policy @lifecycle.json",
                    expectedCLIInput: "management-policy",
                    cliSuggestionBricks: ["management-policy", "network-rule", "blob-service", "keys"],
                    examTip: "Un blob au niveau Archive est hors-ligne : il faut d'abord le réhydrater (Rehydrate vers Hot ou Cool) avant de pouvoir le lire."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u3-qtype05",
                    formatCode: "Q_TYPE_05",
                    domainBadge: "🧱 CONSTRUCTEUR CLI · CLUSTER AUTOSCALER AKS",
                    subBadge: "ASSEMBLAGE DE BRIQUES · MISE À L'ÉCHELLE",
                    prompt: "Vous activez le Cluster Autoscaler (entre 2 et 8 nœuds) sur le cluster aks-prod.\nAssemble dans l'ordre la commande Azure CLI :",
                    mascotPose: .specialistCLIContainers,
                    options: [],
                    wordBankTargetTokens: ["az", "aks", "update", "-g RG-Prod", "-n aks-prod", "--enable-cluster-autoscaler", "--min-count 2", "--max-count 8"],
                    wordBankAllBricks: ["az", "aks", "update", "-g RG-Prod", "-n aks-prod", "--enable-cluster-autoscaler", "--min-count 2", "--max-count 8", "delete"],
                    examTip: "Toujours définir --min-count et --max-count lors de l'activation de --enable-cluster-autoscaler."
                ),
                CertiGoNativeExerciseItem(
                    id: "az-104-u3-qtype10",
                    formatCode: "Q_TYPE_10",
                    domainBadge: "☑️ CHOIX MULTIPLES · ALERTES AZURE MONITOR",
                    subBadge: "COCHE LES 2 COMPOSANTS D'UNE RÈGLE D'ALERTE",
                    prompt: "Vous devez déclencher automatiquement un appel Webhook et un SMS à l'équipe d'astreinte dès que le CPU d'une VM dépasse 85 % pendant 5 minutes.\nQuels sont les 2 éléments à configurer dans Azure Monitor ?",
                    mascotPose: .emotionAhaIdea,
                    options: [
                        .init(
                            id: "m-1",
                            badge: "1",
                            title: "Une Alert Rule basée sur la métrique Percentage CPU (> 85 %, fenêtre d'agrégation 5 min)",
                            isCorrect: true,
                            whyWrongOrRight: "La règle d'alerte de métrique évalue la condition de seuil en quasi temps réel."
                        ),
                        .init(
                            id: "m-2",
                            badge: "2",
                            title: "Un Action Group contenant les notifications SMS/Email et l'action Webhook/Runbook",
                            isCorrect: true,
                            whyWrongOrRight: "Un Action Group est une liste réutilisable de notifications et d'actions automatisées déclenchées par les alertes."
                        ),
                        .init(
                            id: "m-3",
                            badge: "3",
                            title: "Une zone DNS publique avec un enregistrement MX",
                            isCorrect: false,
                            whyWrongOrRight: "Un enregistrement DNS MX route les serveurs mail d'un domaine et ne surveille pas les VMs."
                        ),
                        .init(
                            id: "m-4",
                            badge: "4",
                            title: "Un verrou ReadOnly sur le groupe de ressources",
                            isCorrect: false,
                            whyWrongOrRight: "Un verrou ReadOnly empêche les modifications ARM mais n'envoie aucune alerte."
                        )
                    ],
                    examTip: "Alert Rule = QUAND déclencher (Condition + Scope) ; Action Group = QUOI faire (SMS, Email, Webhook, Logic App, Runbook)."
                )
            ]
        }

        // Default / Unit 1 (`AZ-104`): Identity, RBAC, Key Vault, WAF, CLI Lock, Word Bank VNet & Private Endpoint
        return [
            // 1. Q_TYPE_01 — QCM Scénario RBAC & PIM (Écran 04 / Q_TYPE_01)
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype01",
                formatCode: "Q_TYPE_01",
                domainBadge: "⚡ RÔLES RBAC & GOUVERNANCE",
                subBadge: "MOINDRE PRIVILÈGE · AUDIT EXTERNE",
                prompt: "Un auditeur externe doit vérifier toutes les ressources d'un abonnement \(routeCode) en lecture seule sans pouvoir les modifier.\nQuel rôle intégré lui attribuer ?",
                mascotPose: .specialistSecurityEntra,
                options: [
                    .init(
                        id: "opt-a",
                        badge: "A",
                        title: "Contributeur (Contributor)",
                        isCorrect: false,
                        whyWrongOrRight: "Le rôle Contributeur permet de créer, modifier et supprimer des ressources, ce qui viole le principe du moindre privilège pour un audit."
                    ),
                    .init(
                        id: "opt-b",
                        badge: "B",
                        title: "Lecteur (Reader)",
                        isCorrect: true,
                        whyWrongOrRight: "Le rôle Lecteur accorde uniquement les permissions */read sur toute la portée sans aucune modification ni lecture des secrets."
                    ),
                    .init(
                        id: "opt-c",
                        badge: "C",
                        title: "Propriétaire (Owner)",
                        isCorrect: false,
                        whyWrongOrRight: "Le rôle Propriétaire donne un contrôle total sur les ressources ET sur les attributions RBAC (Microsoft.Authorization/*)."
                    ),
                    .init(
                        id: "opt-d",
                        badge: "D",
                        title: "Administrateur de l'accès utilisateur",
                        isCorrect: false,
                        whyWrongOrRight: "Ce rôle permet d'attribuer des rôles aux utilisateurs mais n'est pas conçu pour un audit en lecture seule."
                    )
                ],
                examTip: "À l'examen, associe toujours « Auditeur externe / Consultation seule » au rôle Lecteur (Reader)."
            ),
            // 2. Q_TYPE_02 / Écran 16 — Grille 2×2 Visuelle de Services Cloud
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype02",
                formatCode: "Q_TYPE_02",
                domainBadge: "🔐 SÉCURITÉ & ARCHITECTURE CLOUD",
                subBadge: "GRILLE VISUELLE 2×2 · SERVICES OFFICIELS",
                prompt: "Vous devez protéger des clés cryptographiques HSM, secrets applicatifs et certificats TLS dans un coffre matériel.\nQuel service Azure choisissez-vous ?",
                mascotPose: .specialistCloudAzure,
                options: [
                    .init(
                        id: "grid-kv",
                        badge: "A",
                        title: "Key Vault",
                        subtitle: "HSM, Secrets & Certificats",
                        assetName: "AzureServices/Key-Vaults",
                        isCorrect: true,
                        whyWrongOrRight: "Azure Key Vault centralise la gestion des secrets, clés HSM FIPS 140-2/3 et certificats TLS avec contrôle RBAC."
                    ),
                    .init(
                        id: "grid-entra",
                        badge: "B",
                        title: "Entra ID",
                        subtitle: "Identité, SSO & MFA",
                        assetName: "AzureServices/Azure-Active-Directory",
                        isCorrect: false,
                        whyWrongOrRight: "Entra ID gère les identités, tokens OIDC/SAML et l'accès conditionnel, pas le stockage de clés HSM."
                    ),
                    .init(
                        id: "grid-fw",
                        badge: "C",
                        title: "Azure Firewall",
                        subtitle: "Filtrage L3–L7 & FQDN",
                        assetName: "AzureServices/Firewalls",
                        isCorrect: false,
                        whyWrongOrRight: "Azure Firewall filtre les flux réseau entrants/sortants du VNet mais ne stocke pas les secrets applicatifs."
                    ),
                    .init(
                        id: "grid-blob",
                        badge: "D",
                        title: "Blob Storage",
                        subtitle: "Stockage objet massif",
                        assetName: "AzureServices/Storage-Accounts",
                        isCorrect: false,
                        whyWrongOrRight: "Blob Storage stocke des fichiers et objets mais n'offre pas de gestion native de secrets ni de rotation automatique de certificats."
                    )
                ],
                examTip: "Key Vault Premium prend en charge les clés protégées par HSM matériel dédié."
            ),
            // 3. Q_TYPE_03 — Schéma d'Architecture Interactif (WAF Couche 7)
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype03",
                formatCode: "Q_TYPE_03",
                domainBadge: "🌐 ARCHITECTURE VNET & WAF",
                subBadge: "SCHÉMA INTERACTIF · [ 🌐 Clients ] ➔ [ ? ] ➔ [ VNet Privé ]",
                prompt: "Vos applications web régionales doivent filtrer le trafic HTTPS entrant en Couche 7 avec un pare-feu WAF OWASP.\nQuelle brique placer dans [ ? ] ?",
                mascotPose: .specialistNetworkVNet,
                options: [
                    .init(
                        id: "arch-appgw",
                        badge: "A",
                        title: "Azure Application Gateway (WAF v2)",
                        subtitle: "Répartiteur HTTP/HTTPS Couche 7 + Inspection OWASP",
                        assetName: "AzureServices/Application-Gateways",
                        isCorrect: true,
                        whyWrongOrRight: "Application Gateway v2 opère en couche 7 (HTTP/HTTPS), gère le routage par URL, la terminaison TLS et le pare-feu WAF."
                    ),
                    .init(
                        id: "arch-lb",
                        badge: "B",
                        title: "Azure Load Balancer (Couche 4 TCP/UDP)",
                        subtitle: "Répartition transport L4 sans inspection HTTP",
                        assetName: "AzureServices/Load-Balancers",
                        isCorrect: false,
                        whyWrongOrRight: "Azure Load Balancer opère en couche 4 (TCP/UDP) et ne peut ni inspecter les en-têtes HTTP ni embarquer de WAF."
                    ),
                    .init(
                        id: "arch-nat",
                        badge: "C",
                        title: "Azure NAT Gateway",
                        subtitle: "Connectivité sortante SNAT uniquement",
                        assetName: "AzureServices/NAT",
                        isCorrect: false,
                        whyWrongOrRight: "NAT Gateway sert uniquement au trafic sortant (Egress SNAT) depuis un sous-réseau privé vers Internet."
                    )
                ],
                examTip: "Trafic HTTP/HTTPS régional + WAF = Application Gateway. Trafic HTTP/HTTPS global multi-régions + WAF = Azure Front Door."
            ),
            // 4. Q_TYPE_04 — Saisie au Clavier CLI
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype04",
                formatCode: "Q_TYPE_04",
                domainBadge: "⌨️ AZURE CLI & VERROUS ARM",
                subBadge: "SAISIE CLAVIER CLI · PROTECTION DE PRODUCTION",
                prompt: "Vous devez empêcher toute suppression accidentelle du groupe de ressources RG-Prod.\nComplète la sous-commande Azure CLI :",
                mascotPose: .poseCLICoder,
                options: [
                    .init(
                        id: "cli-lock",
                        badge: "CLI",
                        title: "lock",
                        isCorrect: true,
                        whyWrongOrRight: "La commande exacte est « az group lock create --lock-type CanNotDelete -n Lock-Prod -g RG-Prod »."
                    )
                ],
                cliPrefix: "az group",
                cliSuffix: "create --lock-type CanNotDelete -g RG-Prod",
                expectedCLIInput: "lock",
                cliSuggestionBricks: ["lock", "list", "policy", "role"],
                examTip: "Un verrou CanNotDelete s'applique même aux utilisateurs ayant le rôle Propriétaire (Owner) !"
            ),
            // 5. Q_TYPE_05 / Écran 17 — Assemblage de Briques CLI (Word Bank)
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype05",
                formatCode: "Q_TYPE_05",
                domainBadge: "🧱 CONSTRUCTEUR CLI (WORD BANK)",
                subBadge: "ASSEMBLAGE DE BRIQUES · DNS PRIVÉ",
                prompt: "Vous provisionnez le réseau virtuel ProdVNet dans le groupe RG-Core.\nAssemble dans l'ordre les briques Azure CLI :",
                mascotPose: .specialistCLIContainers,
                options: [],
                wordBankTargetTokens: ["az", "network", "vnet", "create", "--name ProdVNet", "-g RG-Core"],
                wordBankAllBricks: ["az", "network", "vnet", "create", "--name ProdVNet", "-g RG-Core", "delete", "--sku Basic"],
                examTip: "Dans Azure CLI, la structure suit toujours « az <service> <sous-service> <verbe> »."
            ),
            // 6. Q_TYPE_09 & Q_TYPE_10 — Verdict d'Architecture & Cases Multiples
            CertiGoNativeExerciseItem(
                id: "\(routeCode.lowercased())-qtype10",
                formatCode: "Q_TYPE_10",
                domainBadge: "☑️ CHOIX MULTIPLES · ISOLATION PRIVATE LINK",
                subBadge: "COCHE LES 2 ACTIONS OBLIGATOIRES",
                prompt: "Une VM dans VNet-Prod doit accéder à un compte Blob Storage exclusivement via une IP privée 10.0.2.4.\nQuelles sont les 2 actions indispensables ?",
                mascotPose: .emotionAhaIdea,
                options: [
                    .init(
                        id: "m-1",
                        badge: "1",
                        title: "Créer un Private Endpoint + lier la zone DNS privatelink.blob.core.windows.net au VNet",
                        isCorrect: true,
                        whyWrongOrRight: "Le Private Endpoint projette la NIC 10.0.2.4 et le Virtual Network Link permet la résolution DNS privée."
                    ),
                    .init(
                        id: "m-2",
                        badge: "2",
                        title: "Passer publicNetworkAccess sur Disabled dans le pare-feu du Storage Account",
                        isCorrect: true,
                        whyWrongOrRight: "Créer un Private Endpoint ne coupe pas l'accès public par défaut : il faut désactiver publicNetworkAccess."
                    ),
                    .init(
                        id: "m-3",
                        badge: "3",
                        title: "Ouvrir le port TCP 445 sur Internet via une IP publique Standard",
                        isCorrect: false,
                        whyWrongOrRight: "Exposer le port 445 sur une IP publique ouvre la ressource sur Internet au lieu de l'isoler."
                    ),
                    .init(
                        id: "m-4",
                        badge: "4",
                        title: "Supprimer toutes les règles RBAC de l'abonnement",
                        isCorrect: false,
                        whyWrongOrRight: "La suppression des rôles RBAC bloquerait la gestion sans isoler le plan réseau."
                    )
                ],
                examTip: "Private Endpoint + Zone DNS privatelink + publicNetworkAccess: Disabled = isolation PaaS 100 % verrouillée."
            )
        ]
    }
}

/// Mock Exam question item for Screen 23 & Report Screen 24.
public struct CertiGoNativeExamQuestion: Identifiable, Codable, Equatable, Hashable, Sendable {
    public struct Choice: Identifiable, Codable, Equatable, Hashable, Sendable {
        public let id: String
        public let badge: String
        public let text: String
        public let isCorrect: Bool

        public init(id: String, badge: String, text: String, isCorrect: Bool) {
            self.id = id
            self.badge = badge
            self.text = text
            self.isCorrect = isCorrect
        }
    }

    public let id: String
    public let number: Int
    public let domainTitle: String
    public let caseStudyBadge: String
    public let stem: String
    public let choices: [Choice]

    public init(
        id: String,
        number: Int,
        domainTitle: String,
        caseStudyBadge: String,
        stem: String,
        choices: [Choice]
    ) {
        self.id = id
        self.number = number
        self.domainTitle = domainTitle
        self.caseStudyBadge = caseStudyBadge
        self.stem = stem
        self.choices = choices
    }
}

/// Multi-turn AI Coach conversation message for Screen 06B.
public struct CertiGoChatTurn: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let userPrompt: String
    public let aiHeadline: String
    public let aiBullet1: String
    public let aiBullet2: String
    public let examKeyRule1: String
    public let examKeyRule2: String
    public let closingTip: String
    public var isCopied: Bool
    public var isSavedToMemo: Bool

    public init(
        id: String,
        userPrompt: String,
        aiHeadline: String,
        aiBullet1: String,
        aiBullet2: String,
        examKeyRule1: String,
        examKeyRule2: String,
        closingTip: String,
        isCopied: Bool = false,
        isSavedToMemo: Bool = false
    ) {
        self.id = id
        self.userPrompt = userPrompt
        self.aiHeadline = aiHeadline
        self.aiBullet1 = aiBullet1
        self.aiBullet2 = aiBullet2
        self.examKeyRule1 = examKeyRule1
        self.examKeyRule2 = examKeyRule2
        self.closingTip = closingTip
        self.isCopied = isCopied
        self.isSavedToMemo = isSavedToMemo
    }
}

/// History item in the 85% width Claude-style AI Drawer (06D).
public struct CertiGoAIThreadItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let routeBadge: String
    public let isPinned: Bool
    public let topicKey: String

    public init(
        id: String,
        title: String,
        subtitle: String,
        routeBadge: String,
        isPinned: Bool,
        topicKey: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.routeBadge = routeBadge
        self.isPinned = isPinned
        self.topicKey = topicKey
    }
}

/// Leaderboard member for Social Screen 07 (`Podium Semaine`).
public struct CertiGoLeaderboardMember: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let rank: Int
    public let displayName: String
    public let initials: String
    public let routeBadge: String
    public let xpPoints: Int
    public let streakDays: Int
    public let isCurrentUser: Bool
    public let avatarHex: String

    public init(
        id: String,
        rank: Int,
        displayName: String,
        initials: String,
        routeBadge: String,
        xpPoints: Int,
        streakDays: Int,
        isCurrentUser: Bool = false,
        avatarHex: String = "#0078d4"
    ) {
        self.id = id
        self.rank = rank
        self.displayName = displayName
        self.initials = initials
        self.routeBadge = routeBadge
        self.xpPoints = xpPoints
        self.streakDays = streakDays
        self.isCurrentUser = isCurrentUser
        self.avatarHex = avatarHex
    }
}

/// Friend item for Social Screen 25 (`Mes Amis (12)`).
public struct CertiGoFriendItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let handle: String
    public let initials: String
    public let activeTrackText: String
    public let streakDays: Int
    public let avatarHex: String
    public var isSaluted: Bool

    public init(
        id: String,
        displayName: String,
        handle: String,
        initials: String,
        activeTrackText: String,
        streakDays: Int,
        avatarHex: String,
        isSaluted: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.initials = initials
        self.activeTrackText = activeTrackText
        self.streakDays = streakDays
        self.avatarHex = avatarHex
        self.isSaluted = isSaluted
    }
}

/// Suggested colleague in the `➕ Ajouter un ami` 3D sheet.
public struct CertiGoSuggestedFriend: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let handle: String
    public let initials: String
    public let routeCode: String
    public let activeTrackText: String
    public let streakDays: Int
    public let avatarHex: String
    public var isAdded: Bool

    public init(
        id: String,
        displayName: String,
        handle: String,
        initials: String,
        routeCode: String,
        activeTrackText: String,
        streakDays: Int,
        avatarHex: String,
        isAdded: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.initials = initials
        self.routeCode = routeCode
        self.activeTrackText = activeTrackText
        self.streakDays = streakDays
        self.avatarHex = avatarHex
        self.isAdded = isAdded
    }
}

/// Public profile preview sheet model when tapping any Podium member (`07`) or Friend (`25`).
public struct CertiGoSocialProfilePreview: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let handle: String
    public let initials: String
    public let avatarHex: String
    public let rank: Int
    public let xpPoints: Int
    public let streakDays: Int
    public let examAccuracyPercent: Int
    public let activeCertifications: [String]
    public var isSaluted: Bool

    public init(
        id: String,
        displayName: String,
        handle: String,
        initials: String,
        avatarHex: String,
        rank: Int,
        xpPoints: Int,
        streakDays: Int,
        examAccuracyPercent: Int,
        activeCertifications: [String],
        isSaluted: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.handle = handle
        self.initials = initials
        self.avatarHex = avatarHex
        self.rank = rank
        self.xpPoints = xpPoints
        self.streakDays = streakDays
        self.examAccuracyPercent = examAccuracyPercent
        self.activeCertifications = activeCertifications
        self.isSaluted = isSaluted
    }
}

// MARK: - 2. Rich Multi-Unit, Multi-Certification & Social Data Builders

public enum CertiGoNativeRichCatalog {

    /// Generates 3 full curriculum units (15 sinusoidal lesson islands total) for any certification route code.
    /// Fresh new-user state: Unit 1..3 start at 0%, Lesson 1 (`u1-s1`) is `.active`, and Lessons 2, 3, 5 are `.locked`!
    public static func buildThreeUnits(forRouteCode routeCode: String) -> [CertiGoCertificationUnit] {
        let base = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: routeCode)
        let upper = routeCode.uppercased()
        // Sinusoidal horizontal offsets in [-1.0 ... +1.0] for a natural winding Duolingo S-curve
        let offsets: [Double] = [-1.0, 1.0, -1.0, 1.0, -1.0]

        let unit1Lessons: [CertiGoPathLessonNode] = [
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s1",
                unitNumber: 1,
                stepIndexInUnit: 0,
                globalIndex: 0,
                title: base.stepTitles[0],
                subtitle: "Fondations & architecture de référence \(upper)",
                state: .active,
                iconSymbol: "cloud.fill",
                levelBadge: "Niv. 1/3",
                horizontalOffsetFactor: offsets[0]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s2",
                unitNumber: 1,
                stepIndexInUnit: 1,
                globalIndex: 1,
                title: base.stepTitles[1],
                subtitle: "Identité, gouvernance & contrôle d'accès",
                state: .locked,
                iconSymbol: "person.badge.key.fill",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[1]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s3",
                unitNumber: 1,
                stepIndexInUnit: 2,
                globalIndex: 2,
                title: base.stepTitles[2],
                subtitle: base.stepPreviewSubtitle,
                state: .locked,
                iconSymbol: "shield.lefthalf.filled",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[2]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s4",
                unitNumber: 1,
                stepIndexInUnit: 3,
                globalIndex: 3,
                title: base.stepTitles[3],
                subtitle: "Lab CLI interactif & diagnostic d'architecture",
                state: .miniLab,
                iconSymbol: "terminal.fill",
                levelBadge: "🧪 Mini-Lab",
                horizontalOffsetFactor: offsets[3]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s5",
                unitNumber: 1,
                stepIndexInUnit: 4,
                globalIndex: 4,
                title: base.stepTitles[4],
                subtitle: "Politiques de sécurité & conformité",
                state: .locked,
                iconSymbol: "checkmark.shield.fill",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[4]
            )
        ]

        let unit2Spec: (titles: [(String, String)], subtitle: String, memoActivity: String, memoTopics: [String], memoRule: String) = {
            switch upper {
            case "PDE", "PCA", "ACE":
                return (
                    titles: [
                        ("BigQuery Partitioning & Clustering", "Optimisation SQL & réduction des coûts scan"),
                        ("BigQuery ML & BI Engine", "Modèles ML en SQL & cache en mémoire"),
                        ("Cloud KMS (CMEK) & Data Catalog", "Chiffrement client & Row/Column Security"),
                        ("Optimiser une requête bq dry_run", "Lab pratique : Partition + Cluster Pruning"),
                        ("Dataproc Spark vs Cloud Dataflow", "Migration Hadoop/Spark & Serverless Beam")
                    ],
                    subtitle: "BigQuery, Partitioning, Cloud KMS & Vertex AI",
                    memoActivity: "Optimiser un entrepôt BigQuery avec Partitioning et Clustering",
                    memoTopics: ["Partitioning Date", "Clustering (4 col.)", "Cloud KMS CMEK"],
                    memoRule: "Partitionne par DATE/TIMESTAMP et ajoute jusqu'à 4 colonnes de Clustering pour diviser le volume scanné par 10."
                )
            case "AZ-900":
                return (
                    titles: [
                        ("Régions Azure & Souveraineté", "60+ régions mondiales & résidence des données"),
                        ("Zones de Disponibilité (AZ)", "3 datacenters indépendants par région"),
                        ("Paires de Régions (Region Pairs)", "Isolation >= 300 miles & mises à jour séquentielles"),
                        ("Calculer un SLA Composite", "Lab pratique : 99,9 % × 99,9 % = 99,80 %"),
                        ("Abonnements & Management Groups", "Hiérarchie d'héritage ARM de haut en bas")
                    ],
                    subtitle: "Régions, Zones de Disponibilité, SLA & Hiérarchie ARM",
                    memoActivity: "Distinguer Availability Zones et Region Pairs",
                    memoTopics: ["Availability Zones", "Region Pairs", "SLA Composite"],
                    memoRule: "Availability Zones protège contre la panne d'un bâtiment local ; Region Pairs protège contre une catastrophe régionale."
                )
            case "SAA-C03", "CLF-C02", "AIF-C01":
                return (
                    titles: [
                        ("Gateway vs Interface VPC Endpoint", "Routage privé S3/DynamoDB vs AWS PrivateLink"),
                        ("ALB Couche 7 + WAF vs NLB Couche 4", "Équilibrage HTTP/HTTPS vs TCP ultra-rapide"),
                        ("Amazon RDS Multi-AZ vs Read Replicas", "Failover synchrone HA vs lecture asynchrone"),
                        ("Déployer un Gateway Endpoint S3", "Lab CLI : éliminer les coûts NAT Gateway"),
                        ("CloudFront OAC & S3 Block Public Access", "Distribution CDN sécurisée avec signature SigV4")
                    ],
                    subtitle: "VPC Endpoints, ALB/NLB, RDS Multi-AZ & CloudFront",
                    memoActivity: "Concevoir une architecture AWS Multi-AZ résiliente et sans NAT coûteux",
                    memoTopics: ["Gateway Endpoint", "RDS Multi-AZ", "ALB + AWS WAF"],
                    memoRule: "Utilise un Gateway VPC Endpoint gratuit pour S3 et DynamoDB, et RDS Multi-AZ pour la haute disponibilité synchrone."
                )
            case "AI-102":
                return (
                    titles: [
                        ("Azure AI Search : RAG Hybride & RRF", "Fusion BM25 lexical + Vecteurs HNSW"),
                        ("Semantic Ranker L2 & Chunking", "Ré-ordonnancement sémantique & Captions"),
                        ("AI Content Safety & Prompt Shields", "Protection Jailbreak & Groundedness Detection"),
                        ("Déployer un index vectoriel AI Search", "Lab pratique : text-embedding-3-large"),
                        ("Document Intelligence prebuilt-layout", "Extraction OCR de tableaux en Markdown")
                    ],
                    subtitle: "RAG Hybride, Semantic Ranker, Content Safety & OCR",
                    memoActivity: "Architecturer un pipeline RAG sécurisé sur Azure AI Foundry",
                    memoTopics: ["Hybrid Search + RRF", "Prompt Shields", "Document Intelligence"],
                    memoRule: "Combine Recherche Hybride (BM25 + Vecteurs) + Semantic Ranker L2 + AI Content Safety Prompt Shields."
                )
            case "CKA", "CCNA", "TF-003":
                return (
                    titles: [
                        ("NetworkPolicy Zero-Trust Pod-à-Pod", "Isolation Ingress/Egress par podSelector"),
                        ("Sauvegarde & Restauration etcd", "etcdctl snapshot save & restore avec TLS"),
                        ("livenessProbe vs readinessProbe", "Redémarrage conteneur vs retrait EndpointSlice"),
                        ("Drainer un nœud worker en sécurité", "Lab CLI : kubectl cordon & drain"),
                        ("Taints, Tolerations & Node Affinity", "Planification avancée sur le Control Plane")
                    ],
                    subtitle: "NetworkPolicy, etcd Backup, Probes & Scheduling K8s",
                    memoActivity: "Sécuriser le réseau Pod-à-Pod et sauvegarder etcd",
                    memoTopics: ["NetworkPolicy", "etcdctl snapshot", "Readiness vs Liveness"],
                    memoRule: "readinessProbe retire un pod du Service sans le tuer ; livenessProbe redémarre le conteneur en cas de deadlock."
                )
            case "GH-300", "CCA-F":
                return (
                    titles: [
                        ("Instructions .github/copilot-instructions.md", "Standardiser le contexte IA de l'équipe"),
                        ("Prompt Caching (cache_control: ephemeral)", "Réduire la latence de 85 % par préfixe"),
                        ("Serveurs MCP & JSON Schema (input_schema)", "Outils typés, ressources & garde-fous"),
                        ("Configurer Content Exclusion YAML", "Lab pratique : protéger les secrets et clés"),
                        ("Filtre Public Code & Audit Enterprise", "Conformité IP & sécurité CodeQL")
                    ],
                    subtitle: "Instructions d'équipe, Prompt Caching, MCP & Gouvernance",
                    memoActivity: "Optimiser le Prompt Caching et sécuriser les serveurs MCP",
                    memoTopics: ["copilot-instructions", "Prompt Caching", "MCP input_schema"],
                    memoRule: "Place toujours les définitions d'outils MCP et le System Prompt statique au début de la requête pour maximiser les Cache Hits."
                )
            default:
                return (
                    titles: [
                        ("Isolation PaaS & Private Endpoint", "NIC privée 10.x & désactivation accès public"),
                        ("Zones DNS Privées & VNet Link", "Résolution CNAME vers privatelink.*"),
                        ("VNet Peering & Transit Hybride", "Appairage Hub-Spoke non-transitif & BGP"),
                        ("Diagnostiquer un routage UDR & NSG", "Lab pratique : débloquer un flux HTTPS L7"),
                        ("Application Gateway WAF & Load Balancer", "Répartition Couche 7 OWASP vs Couche 4 TCP")
                    ],
                    subtitle: "Isolation Private Link, DNS privatelink & WAF Couche 7",
                    memoActivity: "Isoler un service PaaS avec Private Endpoint et DNS privé",
                    memoTopics: ["Private Endpoint", "Zone privatelink.*", "App Gateway WAF"],
                    memoRule: "Créer un Private Endpoint ne désactive pas publicNetworkAccess par défaut : verrouille le pare-feu PaaS ET lie la zone DNS privée au VNet."
                )
            }
        }()

        let unit2DomainTitle = base.examDomains.count > 1 ? base.examDomains[1].title : "2. Réseaux Hybrides, Private Link & DNS"
        let unit2Lessons: [CertiGoPathLessonNode] = [
            CertiGoPathLessonNode(
                id: "\(upper)-u2-s1",
                unitNumber: 2,
                stepIndexInUnit: 0,
                globalIndex: 5,
                title: unit2Spec.titles[0].0,
                subtitle: unit2Spec.titles[0].1,
                state: .locked,
                iconSymbol: "network",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[0]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u2-s2",
                unitNumber: 2,
                stepIndexInUnit: 1,
                globalIndex: 6,
                title: unit2Spec.titles[1].0,
                subtitle: unit2Spec.titles[1].1,
                state: .locked,
                iconSymbol: "globe",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[1]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u2-s3",
                unitNumber: 2,
                stepIndexInUnit: 2,
                globalIndex: 7,
                title: unit2Spec.titles[2].0,
                subtitle: unit2Spec.titles[2].1,
                state: .locked,
                iconSymbol: "arrow.triangle.branch",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[2]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u2-s4",
                unitNumber: 2,
                stepIndexInUnit: 3,
                globalIndex: 8,
                title: unit2Spec.titles[3].0,
                subtitle: unit2Spec.titles[3].1,
                state: .miniLab,
                iconSymbol: "terminal.fill",
                levelBadge: "🧪 Mini-Lab",
                horizontalOffsetFactor: offsets[3]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u2-s5",
                unitNumber: 2,
                stepIndexInUnit: 4,
                globalIndex: 9,
                title: unit2Spec.titles[4].0,
                subtitle: unit2Spec.titles[4].1,
                state: .locked,
                iconSymbol: "lock.shield.fill",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[4]
            )
        ]

        let unit3Spec: (titles: [(String, String)], subtitle: String, memoActivity: String, memoTopics: [String], memoRule: String) = {
            switch upper {
            case "PDE", "PCA", "ACE":
                return (
                    titles: [
                        ("VPC Service Controls & Périmètres", "Protection contre l'exfiltration BigQuery/GCS"),
                        ("GKE Autopilot & Workload Identity", "Identité fédérée sans clé JSON exportée"),
                        ("Cloud Spanner & Haute Dispo Globale", "Consistance forte externe multi-régions"),
                        ("Créer un périmètre VPC-SC en CLI", "Lab pratique : gcloud access-context-manager"),
                        ("Boss Final · Architecture Google Cloud", "Synthèse multi-domaines avant l'Examen Blanc")
                    ],
                    subtitle: "VPC Service Controls, GKE Workload Identity & Cloud Spanner",
                    memoActivity: "Verrouiller un périmètre VPC Service Controls et Workload Identity",
                    memoTopics: ["VPC Service Controls", "Workload Identity", "Cloud Spanner"],
                    memoRule: "Pour connecter un pod GKE à Cloud Storage ou BigQuery sans clé JSON, active toujours Workload Identity."
                )
            case "AZ-900":
                return (
                    titles: [
                        ("Calculateur TCO vs Calculateur de Prix", "Migration On-Premises vs estimation Cloud"),
                        ("Azure Policy vs RBAC & Verrous ARM", "Conformité des ressources & CanNotDelete"),
                        ("Azure Advisor & Azure Service Health", "5 piliers Well-Architected & alertes de pannes"),
                        ("Poser un verrou CanNotDelete en CLI", "Lab pratique : az group lock create"),
                        ("Boss Final · Synthèse Fondamentaux AZ-900", "Validation complète avant l'Examen Blanc")
                    ],
                    subtitle: "Gouvernance ARM, FinOps TCO/Pricing, Policy & Locks",
                    memoActivity: "Maîtriser la gouvernance Azure Policy, les verrous et les outils FinOps",
                    memoTopics: ["TCO vs Pricing", "Azure Policy", "Verrou CanNotDelete"],
                    memoRule: "Un verrou CanNotDelete s'applique à tous les utilisateurs de l'abonnement, y compris au Propriétaire (Owner)."
                )
            default:
                return (
                    titles: [
                        ("Haute Disponibilité Multi-AZ & GRS", "Redondance LRS, ZRS, GRS & RA-GRS"),
                        ("Clusters Kubernetes & Autoscaling", "HPA Pods vs Cluster Autoscaler VMSS"),
                        ("Sauvegarde Coffre & Site Recovery", "RTO/RPO, Soft Delete & Cross-Region Restore"),
                        ("Déployer une alerte KQL & Action Group", "Lab pratique : supervision temps réel"),
                        ("Boss Final · Étude de Cas Pearson VUE", "Synthèse multi-domaines avant l'Examen Blanc")
                    ],
                    subtitle: "Continuité d'activité, conteneurs & observabilité",
                    memoActivity: "Architecturer la reprise après sinistre et l'autoscaling",
                    memoTopics: ["RA-GRS / ZRS", "Cluster Autoscaler", "Azure Site Recovery"],
                    memoRule: "Pour garantir la lecture dans une seconde région pendant une panne régionale complète, choisis toujours RA-GRS."
                )
            }
        }()

        let unit3DomainTitle = base.examDomains.count > 2 ? base.examDomains[2].title : "3. Résilience, Conteneurs AKS & Supervision"
        let unit3Lessons: [CertiGoPathLessonNode] = [
            CertiGoPathLessonNode(
                id: "\(upper)-u3-s1",
                unitNumber: 3,
                stepIndexInUnit: 0,
                globalIndex: 10,
                title: unit3Spec.titles[0].0,
                subtitle: unit3Spec.titles[0].1,
                state: .locked,
                iconSymbol: "externaldrive.fill.badge.checkmark",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[0]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u3-s2",
                unitNumber: 3,
                stepIndexInUnit: 1,
                globalIndex: 11,
                title: unit3Spec.titles[1].0,
                subtitle: unit3Spec.titles[1].1,
                state: .locked,
                iconSymbol: "shippingbox.fill",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[1]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u3-s3",
                unitNumber: 3,
                stepIndexInUnit: 2,
                globalIndex: 12,
                title: unit3Spec.titles[2].0,
                subtitle: unit3Spec.titles[2].1,
                state: .locked,
                iconSymbol: "arrow.clockwise.icloud.fill",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[2]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u3-s4",
                unitNumber: 3,
                stepIndexInUnit: 3,
                globalIndex: 13,
                title: unit3Spec.titles[3].0,
                subtitle: unit3Spec.titles[3].1,
                state: .miniLab,
                iconSymbol: "waveform.path.ecg",
                levelBadge: "🧪 Mini-Lab",
                horizontalOffsetFactor: offsets[3]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u3-s5",
                unitNumber: 3,
                stepIndexInUnit: 4,
                globalIndex: 14,
                title: unit3Spec.titles[4].0,
                subtitle: unit3Spec.titles[4].1,
                state: .locked,
                iconSymbol: "trophy.fill",
                levelBadge: "🏆 Boss",
                horizontalOffsetFactor: offsets[4]
            )
        ]

        return [
            CertiGoCertificationUnit(
                id: "\(upper)-unit-1",
                unitNumber: 1,
                headerTitle: base.unitBannerTitle,
                subtitle: base.stepPreviewSubtitle,
                progressPercent: 0,
                accentHex: "#0078d4",
                lipHex: "#005a9e",
                memoActivity: base.memoActivity,
                memoKeyTopics: [base.memoKeyTopics.0, base.memoKeyTopics.1, base.memoKeyTopics.2],
                memoGoldenRule: base.memoGoldenRule,
                lessons: unit1Lessons
            ),
            CertiGoCertificationUnit(
                id: "\(upper)-unit-2",
                unitNumber: 2,
                headerTitle: "UNITÉ 2 · \(unit2DomainTitle.replacingOccurrences(of: "2. ", with: ""))",
                subtitle: unit2Spec.subtitle,
                progressPercent: 0,
                accentHex: "#0284c7",
                lipHex: "#0369a1",
                memoActivity: unit2Spec.memoActivity,
                memoKeyTopics: unit2Spec.memoTopics,
                memoGoldenRule: unit2Spec.memoRule,
                lessons: unit2Lessons
            ),
            CertiGoCertificationUnit(
                id: "\(upper)-unit-3",
                unitNumber: 3,
                headerTitle: "UNITÉ 3 · \(unit3DomainTitle.replacingOccurrences(of: "3. ", with: ""))",
                subtitle: unit3Spec.subtitle,
                progressPercent: 0,
                accentHex: "#4f46e5",
                lipHex: "#3730a3",
                memoActivity: unit3Spec.memoActivity,
                memoKeyTopics: unit3Spec.memoTopics,
                memoGoldenRule: unit3Spec.memoRule,
                lessons: unit3Lessons
            )
        ]
    }

    /// 12 leaderboard members for Social Screen 07 (`Podium Semaine`) — sorted by `xpPoints` descending so a fresh 0 XP user starts at rank 12!
    public static let defaultLeaderboardMembers: [CertiGoLeaderboardMember] = [
        .init(id: "lb-2", rank: 1, displayName: "Sarah L.", initials: "SL", routeBadge: "AZ-104 · AI-102", xpPoints: 1390, streakDays: 19, avatarHex: "#7c3aed"),
        .init(id: "lb-3", rank: 2, displayName: "Thomas M.", initials: "TM", routeBadge: "SAA-C03 · CKA", xpPoints: 1260, streakDays: 11, avatarHex: "#d97706"),
        .init(id: "lb-4", rank: 3, displayName: "Inès K.", initials: "IK", routeBadge: "AI-102 · GH-300", xpPoints: 1185, streakDays: 9, avatarHex: "#059669"),
        .init(id: "lb-5", rank: 4, displayName: "Maxime R.", initials: "MR", routeBadge: "AZ-305 · AZ-104", xpPoints: 1120, streakDays: 15, avatarHex: "#2563eb"),
        .init(id: "lb-6", rank: 5, displayName: "Clara V.", initials: "CV", routeBadge: "GH-300 · CCA-F", xpPoints: 1045, streakDays: 8, avatarHex: "#db2777"),
        .init(id: "lb-7", rank: 6, displayName: "Yanis B.", initials: "YB", routeBadge: "ACE · PCA", xpPoints: 980, streakDays: 7, avatarHex: "#0284c7"),
        .init(id: "lb-8", rank: 7, displayName: "Léa D.", initials: "LD", routeBadge: "AZ-900 · AI-102", xpPoints: 930, streakDays: 12, avatarHex: "#4f46e5"),
        .init(id: "lb-9", rank: 8, displayName: "Hugo P.", initials: "HP", routeBadge: "CKA · TF-003", xpPoints: 875, streakDays: 6, avatarHex: "#0d9488"),
        .init(id: "lb-10", rank: 9, displayName: "Camille T.", initials: "CT", routeBadge: "SAA-C03 · CLF-C02", xpPoints: 820, streakDays: 5, avatarHex: "#ea580c"),
        .init(id: "lb-11", rank: 10, displayName: "Antoine G.", initials: "AG", routeBadge: "SC-300 · AZ-104", xpPoints: 760, streakDays: 4, avatarHex: "#dc2626"),
        .init(id: "lb-12", rank: 11, displayName: "Nora S.", initials: "NS", routeBadge: "PDE · AI-GEMINI", xpPoints: 710, streakDays: 6, avatarHex: "#9333ea"),
        .init(id: "lb-1", rank: 12, displayName: "Toi (Nouveau)", initials: "NV", routeBadge: "AZ-104", xpPoints: 0, streakDays: 0, isCurrentUser: true, avatarHex: "#0078d4")
    ]

    /// Sample friends catalog (not pre-populated on new-user launch; `appState.friends` starts empty `[]`).
    public static let defaultFriends: [CertiGoFriendItem] = [
        .init(id: "fr-1", displayName: "Sarah L.", handle: "@sarah_cloud", initials: "SL", activeTrackText: "AZ-104 · 88 % prêt", streakDays: 19, avatarHex: "#7c3aed"),
        .init(id: "fr-2", displayName: "Thomas M.", handle: "@tom_k8s", initials: "TM", activeTrackText: "SAA-C03 · 81 % prêt", streakDays: 11, avatarHex: "#d97706"),
        .init(id: "fr-3", displayName: "Inès K.", handle: "@ines_ai", initials: "IK", activeTrackText: "AI-102 · Foundry RAG", streakDays: 9, avatarHex: "#059669"),
        .init(id: "fr-4", displayName: "Maxime R.", handle: "@max_arch", initials: "MR", activeTrackText: "AZ-305 · Solutions Expert", streakDays: 15, avatarHex: "#2563eb"),
        .init(id: "fr-5", displayName: "Clara V.", handle: "@clara_copilot", initials: "CV", activeTrackText: "GH-300 · GitHub Copilot", streakDays: 8, avatarHex: "#db2777"),
        .init(id: "fr-6", displayName: "Yanis B.", handle: "@yanis_gcp", initials: "YB", activeTrackText: "PCA · Google Cloud", streakDays: 7, avatarHex: "#0284c7"),
        .init(id: "fr-7", displayName: "Léa D.", handle: "@lea_azure", initials: "LD", activeTrackText: "AZ-900 · Certifiée ✓", streakDays: 12, avatarHex: "#4f46e5"),
        .init(id: "fr-8", displayName: "Hugo P.", handle: "@hugo_cncf", initials: "HP", activeTrackText: "CKA · Kubernetes Admin", streakDays: 6, avatarHex: "#0d9488"),
        .init(id: "fr-9", displayName: "Camille T.", handle: "@cam_aws", initials: "CT", activeTrackText: "AIF-C01 · AWS Bedrock", streakDays: 5, avatarHex: "#ea580c"),
        .init(id: "fr-10", displayName: "Antoine G.", handle: "@antoine_sec", initials: "AG", activeTrackText: "GH-AS · CodeQL & Secrets", streakDays: 4, avatarHex: "#dc2626"),
        .init(id: "fr-11", displayName: "Nora S.", handle: "@nora_data", initials: "NS", activeTrackText: "PDE · BigQuery & Vertex", streakDays: 6, avatarHex: "#9333ea"),
        .init(id: "fr-12", displayName: "Lucas F.", handle: "@lucas_tf", initials: "LF", activeTrackText: "TF-003 · HashiCorp Terraform", streakDays: 10, avatarHex: "#0891b2")
    ]

    /// 5 suggested colleagues for the `➕ Ajouter un ami` sheet (`Suggestions d'Architectes`).
    public static let defaultSuggestedFriends: [CertiGoSuggestedFriend] = [
        .init(id: "sf-1", displayName: "Camille D.", handle: "@camille_az", initials: "CD", routeCode: "AZ-104", activeTrackText: "AZ-104 · Architecte Azure", streakDays: 11, avatarHex: "#0078d4"),
        .init(id: "sf-2", displayName: "Nicolas B.", handle: "@nico_aws", initials: "NB", routeCode: "SAA-C03", activeTrackText: "SAA-C03 · AWS Solutions", streakDays: 9, avatarHex: "#d97706"),
        .init(id: "sf-3", displayName: "Yasmine T.", handle: "@yasmine_gcp", initials: "YT", routeCode: "PCA", activeTrackText: "PCA · Cloud Architect", streakDays: 14, avatarHex: "#0284c7"),
        .init(id: "sf-4", displayName: "Hugo R.", handle: "@hugo_ai", initials: "HR", routeCode: "AI-102", activeTrackText: "AI-102 · Azure AI Engineer", streakDays: 7, avatarHex: "#7c3aed"),
        .init(id: "sf-5", displayName: "Elena V.", handle: "@elena_k8s", initials: "EV", routeCode: "CKA", activeTrackText: "CKA · Kubernetes Admin", streakDays: 12, avatarHex: "#059669")
    ]

    /// Official explanation per mock exam question for the Detailed Correction sheet in Report 24.
    public static func officialExplanation(forExamQuestion question: CertiGoNativeExamQuestion) -> String {
        if let correct = question.choices.first(where: \.isCorrect) {
            return "Réponse officielle validée (\(correct.badge) — \(correct.text)) pour le domaine « \(question.domainTitle) ». Associez toujours le moindre privilège, l'isolation réseau privée et la haute disponibilité multi-zones."
        }
        return "Réflexe Pearson VUE : associez toujours le moindre privilège, l'isolation réseau privée et la résilience multi-régions."
    }

    /// 12 realistic track-specific mock exam questions for Screen 23 & Report Screen 24 across Google Cloud, AWS, AZ-900, AI-102, Kubernetes, Copilot/Claude, and AZ-104.
    public static func buildExamQuestions(forRouteCode routeCode: String) -> [CertiGoNativeExamQuestion] {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch upper {
        case "PDE", "PCA", "ACE":
            return buildGoogleCloudExamQuestions(upper: upper)
        case "SAA-C03", "CLF-C02", "AIF-C01":
            return buildAWSExamQuestions(upper: upper)
        case "AZ-900":
            return buildAZ900ExamQuestions()
        case "AI-102":
            return buildAI102ExamQuestions()
        case "CKA", "CCNA", "TF-003":
            return buildKubernetesExamQuestions(upper: upper)
        case "GH-300", "CCA-F":
            return buildCopilotAndClaudeExamQuestions(upper: upper)
        default:
            return buildAZ104ExamQuestions(upper: upper)
        }
    }

    private static func buildGoogleCloudExamQuestions(upper: String) -> [CertiGoNativeExamQuestion] {
        [
            .init(id: "\(upper)-ex-1", number: 1, domainTitle: "Ingestion Streaming & Cloud Pub/Sub", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · STREAMING IOT", stem: "Votre pipeline \(upper) ingère 200 000 événements/sec via Cloud Pub/Sub. Les messages d'un même capteur doivent être traités dans l'ordre et les messages corrompus isolés après 5 échecs.\nQue configurez-vous ?", choices: [
                .init(id: "A", badge: "A", text: "Un cron batch quotidien sur Compute Engine sans Pub/Sub", isCorrect: false),
                .init(id: "B", badge: "B", text: "Message Ordering avec ordering_key + Dead-Letter Topic (max_delivery_attempts = 5)", isCorrect: true),
                .init(id: "C", badge: "C", text: "Une table Cloud SQL MySQL sans index", isCorrect: false),
                .init(id: "D", badge: "D", text: "Cloud DNS avec enregistrement TXT", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-2", number: 2, domainTitle: "BigQuery Partitioning & Clustering", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · BIGQUERY FINOPS", stem: "Une table BigQuery de 250 To est systématiquement filtrée sur `event_timestamp` puis sur `merchant_id` et `country_code`.\nComment réduire au maximum le coût des requêtes ?", choices: [
                .init(id: "A", badge: "A", text: "Partitionner par event_timestamp (Time-Unit) et activer le Clustering sur (merchant_id, country_code)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Créer 365 vues SQL sans partitionnement", isCorrect: false),
                .init(id: "C", badge: "C", text: "Utiliser SELECT * dans toutes les requêtes", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver le cache BigQuery", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-3", number: 3, domainTitle: "Pipelines Apache Beam & Cloud Dataflow", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · DATAFLOW", stem: "Vous devez calculer le panier moyen par session d'activité utilisateur (fermée après 20 min d'inactivité) tout en intégrant les événements mobiles arrivant avec 10 min de retard.\nQuels concepts Apache Beam utilisez-vous dans Cloud Dataflow ?", choices: [
                .init(id: "A", badge: "A", text: "Global Window unique sans watermark", isCorrect: false),
                .init(id: "B", badge: "B", text: "Session Windows (gap 20 min) + Watermarks + Allowed Lateness Triggers", isCorrect: true),
                .init(id: "C", badge: "C", text: "Import CSV manuel dans Cloud Storage", isCorrect: false),
                .init(id: "D", badge: "D", text: "Règles de pare-feu VPC", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-4", number: 4, domainTitle: "Sécurité & VPC Service Controls", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · ZÉRO EXFILTRATION", stem: "Comment empêcher qu'un compte de service disposant de permissions IAM légitimes ne copie des données BigQuery sensibles vers un bucket Cloud Storage externe non autorisé ?", choices: [
                .init(id: "A", badge: "A", text: "Placer le projet dans un périmètre VPC Service Controls (VPC-SC)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Ajouter une IP publique à toutes les VMs", isCorrect: false),
                .init(id: "C", badge: "C", text: "Supprimer le chiffrement au repos", isCorrect: false),
                .init(id: "D", badge: "D", text: "Activer la facturation exportée", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-5", number: 5, domainTitle: "Chiffrement Cloud KMS & CMEK", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · CONFORMITÉ", stem: "Votre régulateur exige que vous contrôliez vous-même la rotation et la révocation des clés de chiffrement protégeant vos tables BigQuery.\nQuelle solution configurez-vous ?", choices: [
                .init(id: "A", badge: "A", text: "Clés gérées par le client (CMEK) dans Cloud KMS / Cloud HSM", isCorrect: true),
                .init(id: "B", badge: "B", text: "Encodage Base64 en clair dans les colonnes", isCorrect: false),
                .init(id: "C", badge: "C", text: "Stockage des clés dans un fichier README public", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactivation de TLS", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-6", number: 6, domainTitle: "Migration Spark/Hadoop & Cloud Dataproc", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · SPARK MANAGE", stem: "Vous migrez des jobs Apache Spark éphémères depuis un cluster Hadoop On-Premises vers Google Cloud en séparant le calcul du stockage pour réduire les coûts.\nQuelle architecture choisissez-vous ?", choices: [
                .init(id: "A", badge: "A", text: "Clusters Cloud Dataproc éphémères lisant/écrivant directement dans Cloud Storage (au lieu de HDFS)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Clusters HDFS permanents allumés 24/7 avec disques locaux SSD surdimensionnés", isCorrect: false),
                .init(id: "C", badge: "C", text: "Cloud Functions avec timeout de 60 secondes", isCorrect: false),
                .init(id: "D", badge: "D", text: "Cloud DNS", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-7", number: 7, domainTitle: "Machine Learning & BigQuery ML / Vertex AI", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · IA & ML", stem: "Votre équipe d'analystes SQL veut entraîner rapidement un modèle de prévision de désabonnement (Churn) directement sur 10 To de tables BigQuery sans écrire de code Python/PyTorch.\nQue recommandez-vous ?", choices: [
                .init(id: "A", badge: "A", text: "BigQuery ML (CREATE MODEL ... OPTIONS(model_type='LOGISTIC_REG' ou 'BOOSTED_TREE_CLASSIFIER'))", isCorrect: true),
                .init(id: "B", badge: "B", text: "Exporter les 10 To sur un poste portable local", isCorrect: false),
                .init(id: "C", badge: "C", text: "Cloud Armor WAF", isCorrect: false),
                .init(id: "D", badge: "D", text: "Cloud Interconnect", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-8", number: 8, domainTitle: "Bases Relationnelles Globales & Cloud Spanner", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · OLTP GLOBAL", stem: "Quel service Google Cloud offre une base de données relationnelle SQL transactionnelle avec consistance forte externe, scalabilité horizontale et SLA jusqu'à 99,999 % en multi-région ?", choices: [
                .init(id: "A", badge: "A", text: "Cloud Spanner", isCorrect: true),
                .init(id: "B", badge: "B", text: "Cloud Storage Archive", isCorrect: false),
                .init(id: "C", badge: "C", text: "Memorystore for Redis", isCorrect: false),
                .init(id: "D", badge: "D", text: "Artifact Registry", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-9", number: 9, domainTitle: "Sécurité Fine BigQuery (Row & Column)", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · GOUVERNANCE DATA", stem: "Comment masquer dynamiquement les colonnes de données personnelles (PII) dans BigQuery tout en filtrant les lignes visibles selon la région de l'analyste ?", choices: [
                .init(id: "A", badge: "A", text: "Combiner les Policy Tags Data Catalog (Dynamic Data Masking) et les Row-Level Access Policies", isCorrect: true),
                .init(id: "B", badge: "B", text: "Dupliquer manuellement la table 50 fois", isCorrect: false),
                .init(id: "C", badge: "C", text: "Donner le rôle roles/owner à tous les utilisateurs", isCorrect: false),
                .init(id: "D", badge: "D", text: "Supprimer les colonnes de la table de production", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-10", number: 10, domainTitle: "Séries Temporelles NoSQL & Cloud Bigtable", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · MILLISECOND LATENCY", stem: "Quelle base NoSQL wide-column de Google Cloud est conçue pour ingérer des millions de mesures IoT/FinTech par seconde avec une latence inférieure à 10 ms et une Row Key bien distribuée ?", choices: [
                .init(id: "A", badge: "A", text: "Cloud Bigtable", isCorrect: true),
                .init(id: "B", badge: "B", text: "Cloud Storage Coldline", isCorrect: false),
                .init(id: "C", badge: "C", text: "Cloud Deployment Manager", isCorrect: false),
                .init(id: "D", badge: "D", text: "Cloud NAT", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-11", number: 11, domainTitle: "Conteneurs GKE & Workload Identity", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · KUBERNETES", stem: "Quelle est la méthode recommandée par Google Cloud pour permettre à un pod sur GKE d'accéder à BigQuery sans jamais télécharger de clé privée JSON de Service Account ?", choices: [
                .init(id: "A", badge: "A", text: "Workload Identity Federation for GKE", isCorrect: true),
                .init(id: "B", badge: "B", text: "Stocker une clé JSON dans une image Docker publique", isCorrect: false),
                .init(id: "C", badge: "C", text: "Ouvrir l'API sans authentification", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver IAM", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-12", number: 12, domainTitle: "Cycle de Vie Cloud Storage & Bucket Lock", caseStudyBadge: "ÉTUDE DE CAS GOOGLE CLOUD · ARCHIVAGE LÉGAL", stem: "Vous devez conserver des journaux d'audit financier pendant 7 ans de manière immuable (WORM) tout en réduisant le coût de stockage après 90 jours.\nQue configurez-vous sur Cloud Storage ?", choices: [
                .init(id: "A", badge: "A", text: "Retention Policy verrouillée (Bucket Lock) + Object Lifecycle Management vers Archive Storage", isCorrect: true),
                .init(id: "B", badge: "B", text: "Suppression automatique au bout de 7 jours", isCorrect: false),
                .init(id: "C", badge: "C", text: "Disque temporaire Local SSD", isCorrect: false),
                .init(id: "D", badge: "D", text: "Preemptible VM sans disque", isCorrect: false)
            ])
        ]
    }

    private static func buildAWSExamQuestions(upper: String) -> [CertiGoNativeExamQuestion] {
        [
            .init(id: "\(upper)-ex-1", number: 1, domainTitle: "Sécurité IAM & AWS STS", caseStudyBadge: "ÉTUDE DE CAS AWS · IDENTITÉ SANS CLÉ", stem: "Une application sur Amazon EC2 doit écrire dans Amazon S3 et DynamoDB sans aucune Access Key statique stockée sur le serveur.\nQue configurez-vous ?", choices: [
                .init(id: "A", badge: "A", text: "Coder les clés Root dans le fichier de configuration", isCorrect: false),
                .init(id: "B", badge: "B", text: "Attacher un Rôle IAM (Instance Profile) à l'instance EC2 utilisant des jetons temporaires AWS STS", isCorrect: true),
                .init(id: "C", badge: "C", text: "Rendre le bucket S3 public en écriture", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver les Security Groups", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-2", number: 2, domainTitle: "Réseaux VPC & Gateway Endpoints", caseStudyBadge: "ÉTUDE DE CAS AWS · OPTIMISATION NAT", stem: "Vos instances EC2 privées envoient 80 To/mois vers Amazon S3 et génèrent une facture NAT Gateway élevée.\nComment supprimer ces frais de transfert NAT tout en restant sur le réseau privé AWS ?", choices: [
                .init(id: "A", badge: "A", text: "Créer un Gateway VPC Endpoint gratuit pour Amazon S3 et mettre à jour la Route Table", isCorrect: true),
                .init(id: "B", badge: "B", text: "Doubler le nombre de NAT Gateways", isCorrect: false),
                .init(id: "C", badge: "C", text: "Déplacer les instances dans un sous-réseau public sans pare-feu", isCorrect: false),
                .init(id: "D", badge: "D", text: "Utiliser AWS Direct Connect non chiffré", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-3", number: 3, domainTitle: "Bases de Données & RDS Multi-AZ", caseStudyBadge: "ÉTUDE DE CAS AWS · HAUTE DISPONIBILITÉ SQL", stem: "Votre base Amazon RDS PostgreSQL doit basculer automatiquement sans perte de données (RPO = 0) si une Zone de Disponibilité entière tombe en panne.\nQuelle configuration activez-vous ?", choices: [
                .init(id: "A", badge: "A", text: "Déploiement Amazon RDS Multi-AZ (Standby synchrone)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Une Read Replica dans la même zone", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un backup manuel mensuel", isCorrect: false),
                .init(id: "D", badge: "D", text: "Une table en mémoire locale EC2", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-4", number: 4, domainTitle: "Équilibrage de Charge ALB & AWS WAF", caseStudyBadge: "ÉTUDE DE CAS AWS · PROTECTION WEB L7", stem: "Quel équilibreur de charge AWS permet le routage par chemin d'URL (`/api` vs `/web`) et l'attachement direct d'une Web ACL AWS WAF contre les injections SQL ?", choices: [
                .init(id: "A", badge: "A", text: "Application Load Balancer (ALB — Couche 7)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Gateway Load Balancer", isCorrect: false),
                .init(id: "C", badge: "C", text: "Placement Group Cluster", isCorrect: false),
                .init(id: "D", badge: "D", text: "EBS Snapshot", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-5", number: 5, domainTitle: "CDN CloudFront & Origin Access Control", caseStudyBadge: "ÉTUDE DE CAS AWS · SÉCURITÉ S3", stem: "Comment autoriser uniquement votre distribution Amazon CloudFront à lire les fichiers d'un bucket S3 privé tout en bloquant tout accès direct à l'URL S3 ?", choices: [
                .init(id: "A", badge: "A", text: "Activer Origin Access Control (OAC) + S3 Block Public Access + Bucket Policy dédiée", isCorrect: true),
                .init(id: "B", badge: "B", text: "Activer l'hébergement de site web statique public sur S3", isCorrect: false),
                .init(id: "C", badge: "C", text: "Supprimer la Bucket Policy", isCorrect: false),
                .init(id: "D", badge: "D", text: "Ouvrir le port 22 dans le NACL", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-6", number: 6, domainTitle: "Découplage Asynchrone SQS & SNS", caseStudyBadge: "ÉTUDE DE CAS AWS · MICROSERVICES", stem: "Comment découpler un service de prise de commandes et un service de facturation pour qu'aucune commande ne soit perdue lors d'un pic de trafic ×20 ?", choices: [
                .init(id: "A", badge: "A", text: "Insérer une file Amazon SQS avec Dead-Letter Queue entre les deux services", isCorrect: true),
                .init(id: "B", badge: "B", text: "Appeler le serveur de facturation en HTTP synchrone bloquant sans timeout", isCorrect: false),
                .init(id: "C", badge: "C", text: "Écrire les commandes dans /tmp sur l'instance", isCorrect: false),
                .init(id: "D", badge: "D", text: "Redémarrer l'instance EC2 toutes les heures", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-7", number: 7, domainTitle: "Stockage S3 Lifecycle & Glacier", caseStudyBadge: "ÉTUDE DE CAS AWS · FINOPS STOCKAGE", stem: "Quelle classe de stockage Amazon S3 offre le coût le plus bas pour des archives de conformité conservées 10 ans et consultées au maximum 1 fois par an avec un délai de restauration de 12 heures ?", choices: [
                .init(id: "A", badge: "A", text: "S3 Glacier Deep Archive", isCorrect: true),
                .init(id: "B", badge: "B", text: "S3 Express One Zone", isCorrect: false),
                .init(id: "C", badge: "C", text: "S3 Standard", isCorrect: false),
                .init(id: "D", badge: "D", text: "EBS io2 Block Express", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-8", number: 8, domainTitle: "Chiffrement AWS KMS & Rotation", caseStudyBadge: "ÉTUDE DE CAS AWS · CRYPTOGRAPHIE", stem: "Quel service gère les clés Customer Managed Keys (CMK) permettant le chiffrement SSE-KMS avec rotation automatique tous les 365 jours ?", choices: [
                .init(id: "A", badge: "A", text: "AWS Key Management Service (AWS KMS)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Amazon Inspector", isCorrect: false),
                .init(id: "C", badge: "C", text: "AWS Budgets", isCorrect: false),
                .init(id: "D", badge: "D", text: "Amazon Athena", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-9", number: 9, domainTitle: "NoSQL Serverless & Amazon DynamoDB", caseStudyBadge: "ÉTUDE DE CAS AWS · BASE CLÉ-VALEUR", stem: "Quelle fonctionnalité d'Amazon DynamoDB permet une réplication active-active multi-régions avec une latence de lecture/écriture à un chiffre en millisecondes ?", choices: [
                .init(id: "A", badge: "A", text: "DynamoDB Global Tables", isCorrect: true),
                .init(id: "B", badge: "B", text: "Amazon Redshift Spectrum", isCorrect: false),
                .init(id: "C", badge: "C", text: "AWS Snowball Edge", isCorrect: false),
                .init(id: "D", badge: "D", text: "Amazon EFS One Zone", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-10", number: 10, domainTitle: "Conteneurs Serverless & AWS Fargate", caseStudyBadge: "ÉTUDE DE CAS AWS · ECS / EKS", stem: "Quel moteur d'exécution permet de lancer des conteneurs Amazon ECS ou EKS sans provisionner ni patcher d'instances EC2 sous-jacentes ?", choices: [
                .init(id: "A", badge: "A", text: "AWS Fargate", isCorrect: true),
                .init(id: "B", badge: "B", text: "AWS Outposts", isCorrect: false),
                .init(id: "C", badge: "C", text: "Amazon Lightsail DNS", isCorrect: false),
                .init(id: "D", badge: "D", text: "AWS Storage Gateway", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-11", number: 11, domainTitle: "Gouvernance Multi-Comptes & AWS Organizations", caseStudyBadge: "ÉTUDE DE CAS AWS · GOUVERNANCE SCP", stem: "Quel mécanisme d'AWS Organizations permet d'interdire centralement la désactivation de CloudTrail dans tous les comptes membres, même pour les administrateurs locaux ?", choices: [
                .init(id: "A", badge: "A", text: "Une Service Control Policy (SCP) avec Effect: Deny sur cloudtrail:StopLogging", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un tag de répartition des coûts", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un groupe de placement Partition", isCorrect: false),
                .init(id: "D", badge: "D", text: "Un alias IAM", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-12", number: 12, domainTitle: "Services Privés & AWS PrivateLink", caseStudyBadge: "ÉTUDE DE CAS AWS · INTERCONNEXION VPC", stem: "Comment exposer un microservice interne hébergé dans votre VPC à des dizaines de VPC clients partenaires sans appairage VPC Peering ni exposition Internet (et sans risque de chevauchement d'IP CIDR) ?", choices: [
                .init(id: "A", badge: "A", text: "AWS PrivateLink (Interface VPC Endpoint Service derrière un Network Load Balancer)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Une Internet Gateway publique sans pare-feu", isCorrect: false),
                .init(id: "C", badge: "C", text: "S3 Transfer Acceleration", isCorrect: false),
                .init(id: "D", badge: "D", text: "Amazon WorkSpaces", isCorrect: false)
            ])
        ]
    }

    private static func buildAZ900ExamQuestions() -> [CertiGoNativeExamQuestion] {
        [
            .init(id: "AZ-900-ex-1", number: 1, domainTitle: "Concepts Cloud (CapEx vs OpEx)", caseStudyBadge: "FONDAMENTAUX AZ-900 · ÉCONOMIE CLOUD", stem: "Quelle dépense correspond au modèle opérationnel OpEx lors de l'adoption de Microsoft Azure ?", choices: [
                .init(id: "A", badge: "A", text: "L'achat d'un bâtiment physique et de baies de stockage", isCorrect: false),
                .init(id: "B", badge: "B", text: "La facturation mensuelle à l'usage (Pay-as-you-go) des machines virtuelles et du stockage", isCorrect: true),
                .init(id: "C", badge: "C", text: "L'amortissement comptable sur 5 ans de serveurs locaux", isCorrect: false),
                .init(id: "D", badge: "D", text: "Le remplacement des onduleurs électriques du datacenter", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-2", number: 2, domainTitle: "Modèle de Responsabilité Partagée", caseStudyBadge: "FONDAMENTAUX AZ-900 · SÉCURITÉ", stem: "Dans le modèle de responsabilité partagée, quelle responsabilité incombe TOUJOURS au client, même lorsqu'il utilise une offre SaaS ?", choices: [
                .init(id: "A", badge: "A", text: "La sécurité des données, des comptes/identités et des appareils clients", isCorrect: true),
                .init(id: "B", badge: "B", text: "Le gardiennage physique des centres de données Microsoft", isCorrect: false),
                .init(id: "C", badge: "C", text: "Le remplacement des routeurs fibre optique transatlantiques", isCorrect: false),
                .init(id: "D", badge: "D", text: "Le patching de l'hyperviseur physique Azure", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-3", number: 3, domainTitle: "Architecture Azure & Zones de Disponibilité", caseStudyBadge: "FONDAMENTAUX AZ-900 · RÉSILIENCE", stem: "Que sont les Zones de Disponibilité (Availability Zones) dans une région Azure ?", choices: [
                .init(id: "A", badge: "A", text: "Au moins 3 centres de données physiquement séparés dotés d'une alimentation, d'un refroidissement et d'un réseau indépendants", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un simple dossier de facturation dans le portail", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un poste de travail Windows 11 local", isCorrect: false),
                .init(id: "D", badge: "D", text: "Une étiquette (Tag) appliquée à une VM", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-4", number: 4, domainTitle: "Gouvernance & Azure Policy", caseStudyBadge: "FONDAMENTAUX AZ-900 · CONFORMITÉ", stem: "Quel service Azure permet d'imposer que toutes les ressources créées dans un abonnement possèdent obligatoirement le tag `CostCenter` ?", choices: [
                .init(id: "A", badge: "A", text: "Azure Policy", isCorrect: true),
                .init(id: "B", badge: "B", text: "Azure Bastion", isCorrect: false),
                .init(id: "C", badge: "C", text: "Azure Content Delivery Network (CDN)", isCorrect: false),
                .init(id: "D", badge: "D", text: "Azure ExpressRoute", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-5", number: 5, domainTitle: "Verrous Resource Manager (Locks)", caseStudyBadge: "FONDAMENTAUX AZ-900 · PROTECTION", stem: "Quel type de verrou Azure autorise les utilisateurs à lire et modifier une ressource mais interdit formellement sa suppression ?", choices: [
                .init(id: "A", badge: "A", text: "CanNotDelete (Suppression impossible)", isCorrect: true),
                .init(id: "B", badge: "B", text: "ReadOnly (Lecture seule)", isCorrect: false),
                .init(id: "C", badge: "C", text: "AutoScale", isCorrect: false),
                .init(id: "D", badge: "D", text: "SoftDelete", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-6", number: 6, domainTitle: "Gestion des Coûts (TCO vs Pricing)", caseStudyBadge: "FONDAMENTAUX AZ-900 · FINOPS", stem: "Quel outil permet de comparer le coût actuel de votre salle serveurs sur site (On-Premises) avec le coût d'hébergement équivalent dans Azure ?", choices: [
                .init(id: "A", badge: "A", text: "Le Calculateur de Coût Total de Possession (TCO Calculator)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Azure Monitor Log Analytics", isCorrect: false),
                .init(id: "C", badge: "C", text: "Azure Key Vault", isCorrect: false),
                .init(id: "D", badge: "D", text: "Azure DNS", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-7", number: 7, domainTitle: "Cloud Hybride & Azure Arc", caseStudyBadge: "FONDAMENTAUX AZ-900 · HYBRIDE", stem: "Quel service permet de gérer et gouverner des serveurs Windows/Linux et des clusters Kubernetes situés hors d'Azure (On-Premises ou multicloud) depuis le plan de contrôle Azure ?", choices: [
                .init(id: "A", badge: "A", text: "Azure Arc", isCorrect: true),
                .init(id: "B", badge: "B", text: "Azure Queue Storage", isCorrect: false),
                .init(id: "C", badge: "C", text: "Azure NAT Gateway", isCorrect: false),
                .init(id: "D", badge: "D", text: "Azure Front Door", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-8", number: 8, domainTitle: "Catégories IaaS, PaaS & SaaS", caseStudyBadge: "FONDAMENTAUX AZ-900 · MODÈLES DE SERVICE", stem: "À quelle catégorie de service Cloud appartient une machine virtuelle Azure (Azure Virtual Machine) ?", choices: [
                .init(id: "A", badge: "A", text: "IaaS (Infrastructure as a Service)", isCorrect: true),
                .init(id: "B", badge: "B", text: "SaaS (Software as a Service)", isCorrect: false),
                .init(id: "C", badge: "C", text: "FaaS uniquement sans OS", isCorrect: false),
                .init(id: "D", badge: "D", text: "DaaS matériel sur site", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-9", number: 9, domainTitle: "Identité Zero-Trust & Entra ID", caseStudyBadge: "FONDAMENTAUX AZ-900 · IDENTITÉ", stem: "Quelle fonctionnalité de Microsoft Entra ID évalue des signaux comme la localisation de l'utilisateur, l'état de conformité de l'appareil et le niveau de risque avant d'exiger une authentification MFA ?", choices: [
                .init(id: "A", badge: "A", text: "L'Accès Conditionnel (Conditional Access)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Le niveau d'archivage Blob Archive", isCorrect: false),
                .init(id: "C", badge: "C", text: "Le peering de réseaux virtuels", isCorrect: false),
                .init(id: "D", badge: "D", text: "Le calculateur de prix", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-10", number: 10, domainTitle: "Hiérarchie de Gouvernance Azure", caseStudyBadge: "FONDAMENTAUX AZ-900 · PORTÉE ARM", stem: "Quel est l'ordre exact de la hiérarchie Azure du niveau le plus haut au niveau le plus bas ?", choices: [
                .init(id: "A", badge: "A", text: "Groupes d'administration -> Abonnements -> Groupes de ressources -> Ressources", isCorrect: true),
                .init(id: "B", badge: "B", text: "Ressources -> Abonnements -> Groupes d'administration -> Groupes de ressources", isCorrect: false),
                .init(id: "C", badge: "C", text: "Groupes de ressources -> Groupes d'administration -> Ressources -> Abonnements", isCorrect: false),
                .init(id: "D", badge: "D", text: "Abonnements -> Ressources -> Groupes de ressources -> Groupes d'administration", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-11", number: 11, domainTitle: "Supervision & Azure Advisor", caseStudyBadge: "FONDAMENTAUX AZ-900 · OPTIMISATION", stem: "Quel outil gratuit analyse votre configuration Azure et fournit des recommandations personnalisées sur la Fiabilité, la Sécurité, la Performance et le Coût ?", choices: [
                .init(id: "A", badge: "A", text: "Azure Advisor", isCorrect: true),
                .init(id: "B", badge: "B", text: "AzCopy", isCorrect: false),
                .init(id: "C", badge: "C", text: "Azure Storage Explorer", isCorrect: false),
                .init(id: "D", badge: "D", text: "Azure VPN Gateway", isCorrect: false)
            ]),
            .init(id: "AZ-900-ex-12", number: 12, domainTitle: "Disponibilité & SLA Composite", caseStudyBadge: "FONDAMENTAUX AZ-900 · DISPONIBILITÉ", stem: "Si une application dépend séquentiellement de deux services ayant chacun un SLA de 99,9 %, comment évolue le SLA composite de l'application ?", choices: [
                .init(id: "A", badge: "A", text: "Il diminue à 99,80 % (produit des deux SLA : 99,9 % × 99,9 %)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Il passe à 100 %", isCorrect: false),
                .init(id: "C", badge: "C", text: "Il passe à 199,8 %", isCorrect: false),
                .init(id: "D", badge: "D", text: "Il reste toujours égal au SLA le plus élevé", isCorrect: false)
            ])
        ]
    }

    private static func buildAI102ExamQuestions() -> [CertiGoNativeExamQuestion] {
        [
            .init(id: "AI-102-ex-1", number: 1, domainTitle: "RAG Hybride & Azure AI Search", caseStudyBadge: "ÉTUDE DE CAS AI-102 · RAG ENTREPRISE", stem: "Quelle configuration d'Azure AI Search combine la recherche plein texte BM25 et la recherche vectorielle HNSW avant d'appliquer un modèle de ré-ordonnancement L2 ?", choices: [
                .init(id: "A", badge: "A", text: "Recherche Hybride avec Reciprocal Rank Fusion (RRF) + Semantic Ranker", isCorrect: true),
                .init(id: "B", badge: "B", text: "Recherche regex brute sans index", isCorrect: false),
                .init(id: "C", badge: "C", text: "Stockage Table sans vecteurs", isCorrect: false),
                .init(id: "D", badge: "D", text: "Azure DNS Zone", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-2", number: 2, domainTitle: "Sécurité IA & Prompt Shields", caseStudyBadge: "ÉTUDE DE CAS AI-102 · AI CONTENT SAFETY", stem: "Quel composant d'Azure AI Content Safety détecte à la fois les tentatives de jailbreak directes de l'utilisateur et les injections de prompt indirectes cachées dans les documents RAG ?", choices: [
                .init(id: "A", badge: "A", text: "Prompt Shields (User Prompt & Document Attack Detection)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Custom Vision Object Detection", isCorrect: false),
                .init(id: "C", badge: "C", text: "Azure Traffic Manager", isCorrect: false),
                .init(id: "D", badge: "D", text: "Blob Lifecycle Management", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-3", number: 3, domainTitle: "Authentification Entra ID & OpenAI", caseStudyBadge: "ÉTUDE DE CAS AI-102 · ZERO-TRUST AI", stem: "Vous désactivez les clés API (`disableLocalAuth = true`) sur Azure OpenAI. Quel rôle RBAC minimal attribuez-vous à la Managed Identity de votre application pour appeler les modèles ?", choices: [
                .init(id: "A", badge: "A", text: "Cognitive Services OpenAI User", isCorrect: true),
                .init(id: "B", badge: "B", text: "Virtual Machine Contributor", isCorrect: false),
                .init(id: "C", badge: "C", text: "DNS Zone Contributor", isCorrect: false),
                .init(id: "D", badge: "D", text: "Storage Queue Data Reader", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-4", number: 4, domainTitle: "Extraction Documentaire & RAG", caseStudyBadge: "ÉTUDE DE CAS AI-102 · DOCUMENT INTELLIGENCE", stem: "Quel modèle d'Azure AI Document Intelligence permet de convertir des rapports PDF complexes avec tableaux multi-pages directement en Markdown structuré pour le chunking RAG ?", choices: [
                .init(id: "A", badge: "A", text: "prebuilt-layout avec outputContentFormat = markdown", isCorrect: true),
                .init(id: "B", badge: "B", text: "prebuilt-receipt uniquement", isCorrect: false),
                .init(id: "C", badge: "C", text: "Azure Face API", isCorrect: false),
                .init(id: "D", badge: "D", text: "Custom Speech", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-5", number: 5, domainTitle: "Détection d'Hallucinations (Groundedness)", caseStudyBadge: "ÉTUDE DE CAS AI-102 · FIABILITÉ RAG", stem: "Quelle fonctionnalité permet de vérifier automatiquement si la synthèse générée par le LLM ne contient aucune affirmation absente des documents sources fournis ?", choices: [
                .init(id: "A", badge: "A", text: "Groundedness Detection dans Azure AI Content Safety", isCorrect: true),
                .init(id: "B", badge: "B", text: "Augmenter temperature à 2.0", isCorrect: false),
                .init(id: "C", badge: "C", text: "Désactiver le prompt système", isCorrect: false),
                .init(id: "D", badge: "D", text: "Supprimer les chunks sources", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-6", number: 6, domainTitle: "Appels d'Outils & Function Calling", caseStudyBadge: "ÉTUDE DE CAS AI-102 · AGENTS FOUNDRY", stem: "Comment permettre à un modèle Azure OpenAI `gpt-4o` d'interroger de manière déterministe une API interne d'état de commande ?", choices: [
                .init(id: "A", badge: "A", text: "Déclarer la signature JSON Schema dans le paramètre tools (Function Calling / Tool Use)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Demander au modèle de deviner le statut sans outil", isCorrect: false),
                .init(id: "C", badge: "C", text: "Réduire max_tokens à 1", isCorrect: false),
                .init(id: "D", badge: "D", text: "Utiliser uniquement un modèle d'embedding", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-7", number: 7, domainTitle: "Anonymisation PII & Azure AI Language", caseStudyBadge: "ÉTUDE DE CAS AI-102 · RGPD & CONFORMITÉ", stem: "Quel service permet de détecter et masquer automatiquement les noms, numéros de téléphone et IBAN dans des transcriptions d'appels avant leur indexation ?", choices: [
                .init(id: "A", badge: "A", text: "Azure AI Language — PII (Personally Identifiable Information) Detection", isCorrect: true),
                .init(id: "B", badge: "B", text: "Azure Custom Vision", isCorrect: false),
                .init(id: "C", badge: "C", text: "Azure Spatial Anchors", isCorrect: false),
                .init(id: "D", badge: "D", text: "Azure Bastion", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-8", number: 8, domainTitle: "Synthèse Vocale & SSML", caseStudyBadge: "ÉTUDE DE CAS AI-102 · AZURE AI SPEECH", stem: "Dans Azure AI Speech, quel standard XML permet de contrôler finement la prononciation phonétique, le débit (`rate`), les pauses (`break`) et le style émotionnel de la voix ?", choices: [
                .init(id: "A", badge: "A", text: "SSML (Speech Synthesis Markup Language)", isCorrect: true),
                .init(id: "B", badge: "B", text: "KQL (Kusto Query Language)", isCorrect: false),
                .init(id: "C", badge: "C", text: "Bicep", isCorrect: false),
                .init(id: "D", badge: "D", text: "YAML Pipeline", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-9", number: 9, domainTitle: "Sorties Structurées (Structured Outputs)", caseStudyBadge: "ÉTUDE DE CAS AI-102 · JSON SCHEMA", stem: "Comment garantir à 100 % que la réponse d'Azure OpenAI respecte exactement le schéma de typage JSON attendu par votre backend .NET ou Swift ?", choices: [
                .init(id: "A", badge: "A", text: "Utiliser response_format avec type: \"json_schema\" et strict: true (Structured Outputs)", isCorrect: true),
                .init(id: "B", badge: "B", text: "Ajouter « réponds peut-être en JSON » sans schéma", isCorrect: false),
                .init(id: "C", badge: "C", text: "Désactiver l'analyse syntaxique", isCorrect: false),
                .init(id: "D", badge: "D", text: "Utiliser l'API Whisper", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-10", number: 10, domainTitle: "Gouvernance des Quotas & APIM", caseStudyBadge: "ÉTUDE DE CAS AI-102 · PASSERELLE IA", stem: "Comment répartir la charge entre 3 instances régionales Azure OpenAI et appliquer une limite de tokens par minute (`azure-openai-token-limit`) par département ?", choices: [
                .init(id: "A", badge: "A", text: "Placer Azure API Management (APIM) en façade avec politiques GenAI Gateway", isCorrect: true),
                .init(id: "B", badge: "B", text: "Partager une seule clé API sans limite", isCorrect: false),
                .init(id: "C", badge: "C", text: "Utiliser Azure Files", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver la journalisation", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-11", number: 11, domainTitle: "Traduction Temps Réel & Custom Translator", caseStudyBadge: "ÉTUDE DE CAS AI-102 · MULTILINGUE", stem: "Comment imposer la traduction exacte de termes jargonneux propres à votre entreprise dans Azure AI Translator sans ré-entraîner un modèle complet ?", choices: [
                .init(id: "A", badge: "A", text: "Utiliser un glossaire / Dynamic Dictionary ou un modèle Custom Translator Dictionary-only", isCorrect: true),
                .init(id: "B", badge: "B", text: "Supprimer les termes du texte source", isCorrect: false),
                .init(id: "C", badge: "C", text: "Utiliser Computer Vision OCR", isCorrect: false),
                .init(id: "D", badge: "D", text: "Redémarrer le VNet", isCorrect: false)
            ]),
            .init(id: "AI-102-ex-12", number: 12, domainTitle: "Indexation Automatique & Skillsets", caseStudyBadge: "ÉTUDE DE CAS AI-102 · ENRICHISSEMENT IA", stem: "Dans Azure AI Search, quel composant d'un Indexer permet d'enchaîner l'OCR, le découpage de texte (`TextSplitSkill`) et la vectorisation (`AzureOpenAIEmbeddingSkill`) lors de l'ingestion depuis Blob Storage ?", choices: [
                .init(id: "A", badge: "A", text: "Un Skillset d'enrichissement IA attaché à l'Indexer avec Index Projections", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un groupe de sécurité réseau NSG", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un verrou ReadOnly", isCorrect: false),
                .init(id: "D", badge: "D", text: "Un enregistrement CNAME", isCorrect: false)
            ])
        ]
    }

    private static func buildKubernetesExamQuestions(upper: String) -> [CertiGoNativeExamQuestion] {
        [
            .init(id: "\(upper)-ex-1", number: 1, domainTitle: "Contrôle d'Accès RBAC Kubernetes", caseStudyBadge: "EXAMEN CKA · SÉCURITÉ RBAC", stem: "Vous devez autoriser le ServiceAccount `ci-deployer` à lister et créer des `Deployments` uniquement dans le namespace `staging`.\nQue créez-vous ?", choices: [
                .init(id: "A", badge: "A", text: "Un Role et un RoleBinding dans le namespace staging", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un ClusterRoleBinding vers cluster-admin", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un PersistentVolume", isCorrect: false),
                .init(id: "D", badge: "D", text: "Un Service NodePort", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-2", number: 2, domainTitle: "Sauvegarde Control Plane etcd", caseStudyBadge: "EXAMEN CKA · ADMINISTRATION CLUSTER", stem: "Quelle commande sauvegarde l'état de la base `etcd` du cluster Kubernetes ?", choices: [
                .init(id: "A", badge: "A", text: "ETCDCTL_API=3 etcdctl snapshot save /backup/etcd.db --endpoints=... --cacert=... --cert=... --key=...", isCorrect: true),
                .init(id: "B", badge: "B", text: "kubectl delete nodes --all", isCorrect: false),
                .init(id: "C", badge: "C", text: "docker system prune -a", isCorrect: false),
                .init(id: "D", badge: "D", text: "kubeadm reset -f", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-3", number: 3, domainTitle: "Isolation Réseau & NetworkPolicy", caseStudyBadge: "EXAMEN CKA · SÉCURITÉ RÉSEAU", stem: "Comment bloquer par défaut tout le trafic entrant vers les pods d'un namespace `prod` tout en autorisant le trafic DNS sortant ?", choices: [
                .init(id: "A", badge: "A", text: "Appliquer une NetworkPolicy avec podSelector: {} et policyTypes: [\"Ingress\"]", isCorrect: true),
                .init(id: "B", badge: "B", text: "Supprimer CoreDNS du cluster", isCorrect: false),
                .init(id: "C", badge: "C", text: "Créer un ConfigMap vide", isCorrect: false),
                .init(id: "D", badge: "D", text: "Arrêter kube-proxy", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-4", number: 4, domainTitle: "Maintenance des Nœuds (Cordon & Drain)", caseStudyBadge: "EXAMEN CKA · OPÉRATIONS NŒUDS", stem: "Quelle commande marque un nœud comme non planifiable et évacue proprement ses pods actifs en ignorant les DaemonSets ?", choices: [
                .init(id: "A", badge: "A", text: "kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data", isCorrect: true),
                .init(id: "B", badge: "B", text: "kubectl expose pod", isCorrect: false),
                .init(id: "C", badge: "C", text: "kubectl logs -f", isCorrect: false),
                .init(id: "D", badge: "D", text: "kubectl port-forward", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-5", number: 5, domainTitle: "Sondes de Santé (Readiness vs Liveness)", caseStudyBadge: "EXAMEN CKA · FIABILITÉ WORKLOADS", stem: "Quelle sonde retire temporairement un pod de la liste des Endpoints d'un Service Kubernetes sans tuer ni redémarrer le conteneur ?", choices: [
                .init(id: "A", badge: "A", text: "readinessProbe", isCorrect: true),
                .init(id: "B", badge: "B", text: "livenessProbe", isCorrect: false),
                .init(id: "C", badge: "C", text: "imagePullPolicy", isCorrect: false),
                .init(id: "D", badge: "D", text: "initContainer", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-6", number: 6, domainTitle: "Planification & Taints / Tolerations", caseStudyBadge: "EXAMEN CKA · SCHEDULING", stem: "Un nœud GPU possède le taint `gpu=true:NoSchedule`. Que devez-vous ajouter au manifeste d'un pod d'entraînement IA pour qu'il puisse y être planifié ?", choices: [
                .init(id: "A", badge: "A", text: "Une section tolerations correspondant à key: \"gpu\", value: \"true\", effect: \"NoSchedule\"", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un Ingress TLS", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un Secret Opaque", isCorrect: false),
                .init(id: "D", badge: "D", text: "Un HorizontalPodAutoscaler", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-7", number: 7, domainTitle: "Stockage Persistant CSI (PV, PVC, StorageClass)", caseStudyBadge: "EXAMEN CKA · STOCKAGE", stem: "Quel objet permet le provisionnement dynamique d'un PersistentVolume lorsqu'un pod soumet un PersistentVolumeClaim (PVC) ?", choices: [
                .init(id: "A", badge: "A", text: "Une StorageClass avec provisioner CSI", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un volume emptyDir volatile", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un Service Headless", isCorrect: false),
                .init(id: "D", badge: "D", text: "Un LimitRange", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-8", number: 8, domainTitle: "Résolution DNS Interne CoreDNS", caseStudyBadge: "EXAMEN CKA · RÉSEAU & DNS", stem: "Quel est le nom DNS complet (FQDN) d'un Service nommé `orders-api` dans le namespace `production` d'un cluster Kubernetes standard ?", choices: [
                .init(id: "A", badge: "A", text: "orders-api.production.svc.cluster.local", isCorrect: true),
                .init(id: "B", badge: "B", text: "production.orders-api.pod.local", isCorrect: false),
                .init(id: "C", badge: "C", text: "svc.orders-api.kube-system", isCorrect: false),
                .init(id: "D", badge: "D", text: "localhost:8080", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-9", number: 9, domainTitle: "Pods Statiques & Kubelet", caseStudyBadge: "EXAMEN CKA · CONTROL PLANE", stem: "Par quel composant les Static Pods (comme `kube-apiserver`, `etcd`, `kube-scheduler`) déposés dans `/etc/kubernetes/manifests` sont-ils gérés directement ?", choices: [
                .init(id: "A", badge: "A", text: "Le démon kubelet exécuté sur ce nœud", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un Ingress Controller externe", isCorrect: false),
                .init(id: "C", badge: "C", text: "CoreDNS", isCorrect: false),
                .init(id: "D", badge: "D", text: "Helm CLI", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-10", number: 10, domainTitle: "Routage HTTP/HTTPS & Ingress", caseStudyBadge: "EXAMEN CKA · EXPOSITION SERVICE", stem: "Quelle ressource Kubernetes permet d'exposer plusieurs Services HTTP/HTTPS sous une seule adresse IP externe avec routage par nom d'hôte et chemin d'URL ?", choices: [
                .init(id: "A", badge: "A", text: "Un objet Ingress (ou Gateway API HTTPRoute) adossé à un Ingress Controller", isCorrect: true),
                .init(id: "B", badge: "B", text: "Un Job batch", isCorrect: false),
                .init(id: "C", badge: "C", text: "Un ServiceAccount", isCorrect: false),
                .init(id: "D", badge: "D", text: "Un ResourceQuota", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-11", number: 11, domainTitle: "Gestion des Ressources & OOMKilled", caseStudyBadge: "EXAMEN CKA · DÉPANNAGE PODS", stem: "Un conteneur se termine avec le code de sortie `137` et la raison `OOMKilled`. Quelle en est la cause exacte ?", choices: [
                .init(id: "A", badge: "A", text: "Le conteneur a dépassé sa limite de mémoire RAM définie dans resources.limits.memory", isCorrect: true),
                .init(id: "B", badge: "B", text: "L'image Docker n'existe pas dans le registre", isCorrect: false),
                .init(id: "C", badge: "C", text: "Le certificat TLS de l'API server a expiré", isCorrect: false),
                .init(id: "D", badge: "D", text: "Le nœud n'a pas d'adresse IP", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-12", number: 12, domainTitle: "Mise à Niveau Cluster (kubeadm upgrade)", caseStudyBadge: "EXAMEN CKA · LIFECYCLE CLUSTER", stem: "Dans quel ordre devez-vous mettre à niveau un cluster Kubernetes géré par `kubeadm` d'une version mineure à la suivante ?", choices: [
                .init(id: "A", badge: "A", text: "Drainer et mettre à niveau le nœud Control Plane en premier (kubeadm upgrade apply), puis kubelet/kubectl, puis les Workers un par un", isCorrect: true),
                .init(id: "B", badge: "B", text: "Mettre à jour tous les Workers de 3 versions majeures avant le Control Plane", isCorrect: false),
                .init(id: "C", badge: "C", text: "Supprimer /etc/kubernetes/pki avant la mise à niveau", isCorrect: false),
                .init(id: "D", badge: "D", text: "Formater la base etcd", isCorrect: false)
            ])
        ]
    }

    private static func buildCopilotAndClaudeExamQuestions(upper: String) -> [CertiGoNativeExamQuestion] {
        [
            .init(id: "\(upper)-ex-1", number: 1, domainTitle: "Instructions de Dépôt & Contexte Équipe", caseStudyBadge: "ÉTUDE DE CAS \(upper) · GOUVERNANCE IA", stem: "Quel fichier versionné à la racine de `.github/` permet d'injecter automatiquement les standards d'architecture et de test du projet dans toutes les sessions GitHub Copilot ?", choices: [
                .init(id: "A", badge: "A", text: ".github/copilot-instructions.md", isCorrect: true),
                .init(id: "B", badge: "B", text: "/tmp/local-notes.txt", isCorrect: false),
                .init(id: "C", badge: "C", text: "node_modules/.cache", isCorrect: false),
                .init(id: "D", badge: "D", text: ".git/HEAD", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-2", number: 2, domainTitle: "Prompt Caching & Latence", caseStudyBadge: "ÉTUDE DE CAS \(upper) · OPTIMISATION LLM", stem: "Comment structurer vos requêtes multi-tours vers Claude pour bénéficier d'une réduction de coût jusqu'à 90 % grâce au Prompt Caching ?", choices: [
                .init(id: "A", badge: "A", text: "Placer les blocs statiques (Tools, System Prompt, Contexte documentaire) au début avec cache_control: ephemeral", isCorrect: true),
                .init(id: "B", badge: "B", text: "Insérer un UUID aléatoire au premier caractère du System Prompt", isCorrect: false),
                .init(id: "C", badge: "C", text: "Changer l'ordre des outils à chaque requête", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver le cache HTTP", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-3", number: 3, domainTitle: "Model Context Protocol (MCP)", caseStudyBadge: "ÉTUDE DE CAS \(upper) · OUTILS AGENTIQUES", stem: "Dans un serveur MCP (Model Context Protocol), quel champ définit le contrat de validation typé des paramètres attendus par un outil (`Tool`) ?", choices: [
                .init(id: "A", badge: "A", text: "inputSchema (JSON Schema décrivant properties et required)", isCorrect: true),
                .init(id: "B", badge: "B", text: "cssStyleSheet", isCorrect: false),
                .init(id: "C", badge: "C", text: "rawBinaryBlob", isCorrect: false),
                .init(id: "D", badge: "D", text: "untypedString", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-4", number: 4, domainTitle: "Exclusion de Contenu (Content Exclusion)", caseStudyBadge: "ÉTUDE DE CAS \(upper) · SÉCURITÉ ENTREPRISE", stem: "Quelle fonctionnalité de GitHub Copilot Business/Enterprise empêche l'extension IDE et Copilot Chat d'accéder aux fichiers contenant des clés privées ou secrets ?", choices: [
                .init(id: "A", badge: "A", text: "Content Exclusion configurée au niveau du dépôt ou de l'organisation", isCorrect: true),
                .init(id: "B", badge: "B", text: "Augmenter la taille de police de l'éditeur", isCorrect: false),
                .init(id: "C", badge: "C", text: "Utiliser un thème sombre", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver le correcteur orthographique", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-5", number: 5, domainTitle: "Protection de la Propriété Intellectuelle", caseStudyBadge: "ÉTUDE DE CAS \(upper) · CONFORMITÉ LÉGALE", stem: "Quel paramètre d'organisation GitHub Copilot filtre automatiquement les suggestions de complétion identiques à du code public existant sur GitHub ?", choices: [
                .init(id: "A", badge: "A", text: "Suggestions matching public code = Blocked", isCorrect: true),
                .init(id: "B", badge: "B", text: "Allow public fork push", isCorrect: false),
                .init(id: "C", badge: "C", text: "Disable branch protection", isCorrect: false),
                .init(id: "D", badge: "D", text: "Auto-merge pull requests", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-6", number: 6, domainTitle: "Instructions Ciblées par Fichier (applyTo)", caseStudyBadge: "ÉTUDE DE CAS \(upper) · MONOREPO", stem: "Dans un monorepo mêlant Swift, .NET et Flutter, comment appliquer des règles spécifiques uniquement aux fichiers `backend/**/*.cs` ?", choices: [
                .init(id: "A", badge: "A", text: "Créer un fichier .github/instructions/backend.instructions.md avec frontmatter applyTo: \"backend/**/*.cs\"", isCorrect: true),
                .init(id: "B", badge: "B", text: "Supprimer les autres langages du dépôt", isCorrect: false),
                .init(id: "C", badge: "C", text: "Renommer tous les fichiers en .txt", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver Git", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-7", number: 7, domainTitle: "Raisonnement Étendu (Extended Thinking)", caseStudyBadge: "ÉTUDE DE CAS \(upper) · ARCHITECTURE COMPLEXE", stem: "Quel est l'intérêt d'activer le mode Extended Thinking (`thinking` avec `budget_tokens`) sur un problème d'architecture distribuée ou de débogage complexe ?", choices: [
                .init(id: "A", badge: "A", text: "Permettre au modèle de décomposer et vérifier ses hypothèses étape par étape avant de produire la réponse finale", isCorrect: true),
                .init(id: "B", badge: "B", text: "Ignorer les instructions de sécurité", isCorrect: false),
                .init(id: "C", badge: "C", text: "Désactiver la vérification des types", isCorrect: false),
                .init(id: "D", badge: "D", text: "Supprimer les tests unitaires", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-8", number: 8, domainTitle: "Confidentialité des Données d'Entreprise", caseStudyBadge: "ÉTUDE DE CAS \(upper) · PRIVACY", stem: "Comment GitHub Copilot Business et Enterprise traitent-ils les prompts et extraits de code privé de vos développeurs concernant l'entraînement des modèles de fondation ?", choices: [
                .init(id: "A", badge: "A", text: "Ni les prompts ni les suggestions ne sont conservés pour entraîner les modèles de base partagés", isCorrect: true),
                .init(id: "B", badge: "B", text: "Tout le code privé est publié dans un dépôt public", isCorrect: false),
                .init(id: "C", badge: "C", text: "Les secrets sont envoyés par email", isCorrect: false),
                .init(id: "D", badge: "D", text: "Le code est stocké en clair sans TLS", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-9", number: 9, domainTitle: "Défense contre l'Injection de Prompt Indirecte", caseStudyBadge: "ÉTUDE DE CAS \(upper) · SÉCURITÉ AGENT", stem: "Lorsqu'un agent IA lit une issue GitHub ou une page web externe non fiable, quelle règle de sécurité est essentielle avant d'exécuter un outil modifiant l'état ?", choices: [
                .init(id: "A", badge: "A", text: "Traiter le contenu externe comme de la donnée non fiable et exiger une validation/confirmation explicite pour toute action sensible", isCorrect: true),
                .init(id: "B", badge: "B", text: "Exécuter aveuglément toutes les commandes shell trouvées dans les commentaires", isCorrect: false),
                .init(id: "C", badge: "C", text: "Donner les droits root sans filtre", isCorrect: false),
                .init(id: "D", badge: "D", text: "Transmettre les variables d'environnement secrètes à des URLs tierces", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-10", number: 10, domainTitle: "Orchestration Multi-Agents", caseStudyBadge: "ÉTUDE DE CAS \(upper) · SUB-AGENTS", stem: "Pourquoi déléguer une sous-tâche d'exploration volumineuse à un sous-agent dédié disposant de sa propre fenêtre de contexte ?", choices: [
                .init(id: "A", badge: "A", text: "Isoler les journaux intermédiaires volumineux et ne renvoyer qu'une synthèse vérifiée au coordinateur principal", isCorrect: true),
                .init(id: "B", badge: "B", text: "Saturer volontairement la fenêtre de contexte principale", isCorrect: false),
                .init(id: "C", badge: "C", text: "Supprimer la validation par les tests", isCorrect: false),
                .init(id: "D", badge: "D", text: "Éviter toute vérification du code", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-11", number: 11, domainTitle: "Citations Ancrées (Grounded Citations)", caseStudyBadge: "ÉTUDE DE CAS \(upper) · FIABILITÉ DOCUMENTAIRE", stem: "Quel avantage offre l'activation des Citations natives lors de l'analyse de documents techniques par Claude ?", choices: [
                .init(id: "A", badge: "A", text: "Chaque affirmation pointe vers le passage exact et le document source correspondant, facilitant l'audit humain", isCorrect: true),
                .init(id: "B", badge: "B", text: "Le modèle invente des références inexistantes", isCorrect: false),
                .init(id: "C", badge: "C", text: "Les documents sources sont supprimés", isCorrect: false),
                .init(id: "D", badge: "D", text: "La réponse est vide", isCorrect: false)
            ]),
            .init(id: "\(upper)-ex-12", number: 12, domainTitle: "Validation par les Tests & CI", caseStudyBadge: "ÉTUDE DE CAS \(upper) · QUALITÉ LOGICIELLE", stem: "Quelle est la meilleure pratique après qu'un agent IA a généré un correctif ou une nouvelle fonctionnalité ?", choices: [
                .init(id: "A", badge: "A", text: "Exécuter systématiquement la suite de tests ciblée, le linter et le compilateur en traitant les avertissements comme des erreurs", isCorrect: true),
                .init(id: "B", badge: "B", text: "Pousser directement en production sur main sans compiler", isCorrect: false),
                .init(id: "C", badge: "C", text: "Supprimer les tests en échec", isCorrect: false),
                .init(id: "D", badge: "D", text: "Désactiver l'analyse statique", isCorrect: false)
            ])
        ]
    }

    private static func buildAZ104ExamQuestions(upper: String) -> [CertiGoNativeExamQuestion] {
        [
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-1",
                number: 1,
                domainTitle: "Identité & Gouvernance Entra ID",
                caseStudyBadge: "ÉTUDE DE CAS CONTOSO · IDENTITÉ ENTRA ID",
                stem: "Un administrateur doit activer le rôle Global Reader uniquement pendant 4 heures avec approbation obligatoire et MFA.\nQuelle fonctionnalité déployez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Attributions RBAC permanentes avec groupe de sécurité dynamique", isCorrect: false),
                    .init(id: "B", badge: "B", text: "Microsoft Entra ID Privileged Identity Management (PIM) — rôle éligible", isCorrect: true),
                    .init(id: "C", badge: "C", text: "Stratégie Azure Policy AuditIfNotExists sur l'abonnement", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Verrou Resource Manager ReadOnly sur le groupe d'administration", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-2",
                number: 2,
                domainTitle: "Réseaux Virtuels, Private Link & DNS",
                caseStudyBadge: "ÉTUDE DE CAS CONTOSO · RÉSEAUX HYBRIDES",
                stem: "Deux VNets (10.1.0.0/16 et 10.2.0.0/16) appairés en VNet Peering doivent partager la passerelle ExpressRoute du VNet-Hub.\nQuels paramètres activez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Autoriser le transit de passerelle sur le Hub + Utiliser les passerelles distantes sur le Spoke", isCorrect: true),
                    .init(id: "B", badge: "B", text: "Créer deux passerelles VPN redondantes avec BGP actif-actif dans chaque Spoke", isCorrect: false),
                    .init(id: "C", badge: "C", text: "Déployer un Azure Load Balancer Standard Interne entre les deux VNets", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Activer Service Endpoint Microsoft.Network sur tous les sous-réseaux", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-3",
                number: 3,
                domainTitle: "Stockage & Sécurité des données",
                caseStudyBadge: "ÉTUDE DE CAS CONTOSO · SÉCURITÉ",
                stem: "50 VMs dans VNet-Spoke doivent lire les secrets d'un coffre Azure Key Vault sans exposition Internet et avec contrôle RBAC unifié.\nQuelle architecture déployez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Service Endpoint + Stratégie d'accès Key Vault classique sur le sous-réseau", isCorrect: false),
                    .init(id: "B", badge: "B", text: "Private Endpoint + Zone DNS privatelink + Rôle RBAC Key Vault Secrets User", isCorrect: true),
                    .init(id: "C", badge: "C", text: "Azure NAT Gateway + Pare-feu public Key Vault limité à l'IP sortante", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Appeler Key Vault via une adresse IP publique avec jeton SAS temporaire", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-4",
                number: 4,
                domainTitle: "Stockage & Sécurité des données",
                caseStudyBadge: "ÉTUDE DE CAS CONTOSO · STOCKAGE & RÉSILIENCE",
                stem: "Un compte de stockage contenant des archives légales doit rester lisible dans une région secondaire même en cas de panne régionale complète.\nQuelle redondance choisissez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "LRS (Locally Redundant Storage) avec Soft Delete 14 jours", isCorrect: false),
                    .init(id: "B", badge: "B", text: "RA-GRS (Read-Access Geo-Redundant Storage)", isCorrect: true),
                    .init(id: "C", badge: "C", text: "ZRS (Zone-Redundant Storage) sur 3 zones de disponibilité", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Stockage Blob Premium avec réplication locale synchrone", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-5",
                number: 5,
                domainTitle: "Déploiement Calcul, VM & AKS",
                caseStudyBadge: "ÉTUDE DE CAS CONTOSO · CALCUL & AKS",
                stem: "Votre cluster AKS de production doit mettre à l'échelle automatiquement le nombre de nœuds VM lorsque les pods sont en état Pending par manque de CPU.\nQuel composant activez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Horizontal Pod Autoscaler (HPA) uniquement sur le déploiement Kubernetes", isCorrect: false),
                    .init(id: "B", badge: "B", text: "Azure Traffic Manager en mode Performance", isCorrect: false),
                    .init(id: "C", badge: "C", text: "Azure Update Manager avec maintenance planifiée", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Cluster Autoscaler sur le pool de nœuds AKS (Virtual Machine Scale Sets)", isCorrect: true)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-6",
                number: 6,
                domainTitle: "Supervision, Backup & Site Recovery",
                caseStudyBadge: "ÉTUDE DE CAS CONTOSO · SUPERVISION & BACKUP",
                stem: "Vous devez sauvegarder 12 VMs Azure situées dans West Europe vers un coffre Recovery Services Vault avec restauration inter-régions.\nQuelle configuration est requise ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Coffre dans West Europe en stockage GRS avec Cross-Region Restore (CRR) activé", isCorrect: true),
                    .init(id: "B", badge: "B", text: "Coffre dans North Europe en stockage LRS sans agent", isCorrect: false),
                    .init(id: "C", badge: "C", text: "Instantanés (Snapshots) manuels stockés dans le même groupe de ressources", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Règle d'alerte Azure Monitor Log Analytics sans coffre de sauvegarde", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-7",
                number: 7,
                domainTitle: "Identité & Gouvernance Entra ID",
                caseStudyBadge: "ÉTUDE DE CAS LITWARE · GOUVERNANCE ARM",
                stem: "Un groupe de ressources RG-Core possède un verrou CanNotDelete. Un administrateur disposant du rôle Propriétaire (Owner) tente de supprimer une base SQL dans RG-Core.\nQue se passe-t-il ?",
                choices: [
                    .init(id: "A", badge: "A", text: "La suppression réussit immédiatement car le rôle Owner outrepasse les verrous", isCorrect: false),
                    .init(id: "B", badge: "B", text: "La suppression est bloquée tant que le verrou CanNotDelete n'est pas retiré", isCorrect: true),
                    .init(id: "C", badge: "C", text: "La base SQL est déplacée automatiquement dans la corbeille Entra ID", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Seul le Global Administrator peut supprimer la ressource sans retirer le verrou", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-8",
                number: 8,
                domainTitle: "Réseaux Virtuels, Private Link & DNS",
                caseStudyBadge: "ÉTUDE DE CAS LITWARE · PARE-FEU & WAF",
                stem: "Vous devez router le trafic HTTPS entrant vers différents pools de serveurs selon le chemin d'URL (/api vs /images) tout en bloquant les injections SQL OWASP.\nQuel service choisissez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Azure Load Balancer Standard Public", isCorrect: false),
                    .init(id: "B", badge: "B", text: "Azure Application Gateway v2 avec WAF activé", isCorrect: true),
                    .init(id: "C", badge: "C", text: "Azure NAT Gateway attachée au sous-réseau", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Network Security Group (NSG) avec règle de priorité 100", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-9",
                number: 9,
                domainTitle: "Identité & Gouvernance Entra ID",
                caseStudyBadge: "ÉTUDE DE CAS LITWARE · CONFORMITÉ POLICY",
                stem: "Vous souhaitez interdire automatiquement le déploiement de machines virtuelles en dehors de France Central et West Europe, même pour les Propriétaires d'abonnement.\nQuelle solution utilisez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Une attribution Azure Policy « Emplacements autorisés » avec effet Deny", isCorrect: true),
                    .init(id: "B", badge: "B", text: "Un verrou ReadOnly sur chaque sous-réseau virtuel", isCorrect: false),
                    .init(id: "C", badge: "C", text: "Un groupe de sécurité d'application (ASG)", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Une recommandation Azure Advisor de coût", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-10",
                number: 10,
                domainTitle: "Stockage & Sécurité des données",
                caseStudyBadge: "ÉTUDE DE CAS FABRIKAM · CYCLE DE VIE BLOB",
                stem: "Pour réduire les coûts, les blobs qui n'ont pas été consultés depuis 30 jours doivent basculer automatiquement du niveau Hot vers Cool, puis Archive après 180 jours.\nQue configurez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Une règle Lifecycle Management (Gestion du cycle de vie) sur le Storage Account", isCorrect: true),
                    .init(id: "B", badge: "B", text: "Une copie manuelle AzCopy déclenchée par l'utilisateur", isCorrect: false),
                    .init(id: "C", badge: "C", text: "Un partage Azure Files SMB avec mise en cache locale", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Une stratégie d'accès stockée (Stored Access Policy) SAS", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-11",
                number: 11,
                domainTitle: "Déploiement Calcul, VM & AKS",
                caseStudyBadge: "ÉTUDE DE CAS FABRIKAM · HAUTE DISPONIBILITÉ VM",
                stem: "Deux machines virtuelles critiques dans la même région doivent survivre à la panne électrique ou réseau complète d'un centre de données physique.\nComment les déployez-vous ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Réparties sur 2 Zones de Disponibilité (Availability Zones 1 et 2)", isCorrect: true),
                    .init(id: "B", badge: "B", text: "Dans le même groupe de placement de proximité (PPG) sur un seul rack", isCorrect: false),
                    .init(id: "C", badge: "C", text: "Avec un disque OS Standard HDD non managé", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Dans un sous-réseau sans adresse IP privée", isCorrect: false)
                ]
            ),
            CertiGoNativeExamQuestion(
                id: "\(upper)-ex-12",
                number: 12,
                domainTitle: "Supervision, Backup & Site Recovery",
                caseStudyBadge: "ÉTUDE DE CAS FABRIKAM · REPRISE APRÈS SINISTRE",
                stem: "Quelle solution permet de répliquer en continu des machines virtuelles d'une région primaire vers une région secondaire avec un RTO de quelques minutes ?",
                choices: [
                    .init(id: "A", badge: "A", text: "Azure Site Recovery (ASR)", isCorrect: true),
                    .init(id: "B", badge: "B", text: "Azure Network Watcher Packet Capture", isCorrect: false),
                    .init(id: "C", badge: "C", text: "Azure Cost Management Budgets", isCorrect: false),
                    .init(id: "D", badge: "D", text: "Entra ID Access Reviews", isCorrect: false)
                ]
            )
        ]
    }

    /// 12 AI Coach discussion threads for the 85% width Drawer `06D`.
    public static let defaultAIThreads: [CertiGoAIThreadItem] = [
        .init(id: "th-1", title: "RBAC vs Azure Policy (Priorités)", subtitle: "Épinglé · Gouvernance & Verrous", routeBadge: "AZ-104", isPinned: true, topicKey: "rbac-vs-policy"),
        .init(id: "th-2", title: "Private Endpoint & DNS privatelink", subtitle: "Épinglé · Isolation PaaS 10.x", routeBadge: "AZ-104", isPinned: true, topicKey: "cli-example"),
        .init(id: "th-3", title: "Diagnostic de mes 3 dernières erreurs", subtitle: "Épinglé · +65 pts Pearson VUE", routeBadge: "AZ-104", isPinned: true, topicKey: "last-3-errors"),
        .init(id: "th-4", title: "Simulation orale : Cas Contoso Key Vault", subtitle: "Aujourd'hui · Entretien vocal Nova", routeBadge: "AZ-104", isPinned: false, topicKey: "oral-interview"),
        .init(id: "th-5", title: "Commandes CLI VNet Peering Hub-Spoke", subtitle: "Aujourd'hui · Transit ExpressRoute", routeBadge: "AZ-104", isPinned: false, topicKey: "vnet-peering-cli"),
        .init(id: "th-6", title: "Entra ID PIM : Rôles éligibles & JIT", subtitle: "Hier · Sécurité & MFA", routeBadge: "SC-300", isPinned: false, topicKey: "entra-pim-oral"),
        .init(id: "th-7", title: "Verrou CanNotDelete vs Rôle Owner", subtitle: "Hier · Piège fréquent d'examen", routeBadge: "AZ-104", isPinned: false, topicKey: "cannotdelete-lock"),
        .init(id: "th-8", title: "App Gateway (L7 WAF) vs Load Balancer (L4)", subtitle: "Il y a 2 j · Architecture réseau", routeBadge: "AZ-104", isPinned: false, topicKey: "appgw-vs-lb"),
        .init(id: "th-9", title: "Priorités NSG Subnet + NIC & ASG", subtitle: "Il y a 3 j · Sécurité réseau", routeBadge: "AZ-104", isPinned: false, topicKey: "nsg-priority"),
        .init(id: "th-10", title: "Azure Backup vs Site Recovery (ASR)", subtitle: "Il y a 4 j · Continuité d'activité", routeBadge: "AZ-104", isPinned: false, topicKey: "azure-backup"),
        .init(id: "th-11", title: "AWS IAM Role vs S3 Bucket Policy", subtitle: "Il y a 5 j · Multi-Parcours Cloud", routeBadge: "SAA-C03", isPinned: false, topicKey: "iam-vs-s3-policy"),
        .init(id: "th-12", title: "Azure AI Foundry : RAG Hybride & Vectoriel", subtitle: "Il y a 6 j · Veille IA & Agents", routeBadge: "AI-102", isPinned: false, topicKey: "rbac-vs-policy")
    ]

    public static func examProviderMetadata(
        forRouteCode code: String
    ) -> (providerBadge: String, providerName: String, passingThresholdText: String, durationText: String, summaryLine: String) {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch upper {
        case "CKA", "CKAD", "CKS":
            return (
                providerBadge: "CONDITIONS LINUX FOUNDATION / PSI",
                providerName: "Linux Foundation / PSI",
                passingThresholdText: "66 / 100",
                durationText: "120 min",
                summaryLine: "Linux Foundation / PSI · 66/100 · 120 min"
            )
        case "ACE", "PCA", "PDE":
            return (
                providerBadge: "CONDITIONS KRYTERION / GOOGLE CLOUD",
                providerName: "Kryterion",
                passingThresholdText: "700 / 1000",
                durationText: "120 min",
                summaryLine: "Kryterion · 700/1000 · 120 min"
            )
        case "GH-300", "GH-900", "GH-AS":
            return (
                providerBadge: "CONDITIONS GITHUB / PSI",
                providerName: "GitHub / PSI",
                passingThresholdText: "700 / 1000",
                durationText: "100 min",
                summaryLine: "GitHub / PSI · 700/1000 · 100 min"
            )
        default:
            return (
                providerBadge: "CONDITIONS PEARSON VUE",
                providerName: "Pearson VUE",
                passingThresholdText: "700 / 1000",
                durationText: "90 min",
                summaryLine: "Pearson VUE · 700/1000 · 90 min"
            )
        }
    }

    public static func examDomains(
        forRouteCode code: String
    ) -> [(title: String, weightText: String, scorePercent: String, colorHex: String)] {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper == "GH-300" {
            return [
                ("1. IA Responsable & Éthique Générative", "Poids officiel : 7 %", "92 %", "#15803d"),
                ("2. Plans, Fonctionnalités & Architecture Copilot", "Poids officiel : 31 %", "88 %", "#15803d"),
                ("3. Fonctionnement & Gestion du Contexte Prompt", "Poids officiel : 15 %", "84 %", "#1d4ed8"),
                ("4. Conception de Prompts & Cas d'Usage Développeur", "Poids officiel : 20 %", "81 %", "#1d4ed8"),
                ("5. Tests unitaires, Refactoring & Cycle de vie SDLC", "Poids officiel : 18 %", "78 %", "#1d4ed8"),
                ("6. Confidentialité, Exclusions & Gouvernance Enterprise", "Poids officiel : 9 % · À cibler", "74 %", "#b45309")
            ]
        }
        return CertiGoLiveTrackCurriculum.curriculum(forRouteCode: upper).examDomains
    }

    public static func profileCertificationDetail(
        forCode code: String
    ) -> CertiGoFigmaLiveRuntimeState.ProfileCertificationDetailPayload {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch upper {
        case "GH-300":
            return .init(
                code: "GH-300",
                badge: "GITHUB OFFICIAL CERTIFICATION · PSI",
                title: "GitHub Copilot (GH-300)",
                progression: "80 % (12/15)",
                lastMockExam: "840 / 1000 ✓",
                crestImageFill: "img:7149e104bfe0be393cbd68e92a1dba4c1f0f7936",
                domains: [
                    ("1. IA Responsable & Éthique Générative (7 %)", "92%", 290.0, "#58cc02"),
                    ("2. Plans, Fonctionnalités & Architecture Copilot (31 %)", "88%", 272.0, "#58cc02"),
                    ("3. Fonctionnement & Gestion du Contexte Prompt (15 %)", "84%", 256.0, "#0078d4"),
                    ("4. Conception de Prompts & Cas d'Usage Développeur (20 %)", "81%", 244.0, "#0078d4"),
                    ("5. Tests unitaires, Refactoring & Cycle SDLC (18 %)", "78%", 234.0, "#0078d4"),
                    ("6. Confidentialité, Exclusions & Gouvernance (9 %)", "74%", 220.0, "#f59e0b")
                ]
            )
        case "AZ-900", "SAA-C03", "AZ-104":
            return CertiGoFigmaLiveRuntimeState.profileCertificationDetail(forCode: upper)
        case "PCA":
            return .init(
                code: "PCA",
                badge: "GOOGLE CLOUD CERTIFIED PROFESSIONAL",
                title: "Cloud Architect (PCA)",
                progression: "45 % (7/15)",
                lastMockExam: "745 / 1000 ✓",
                crestImageFill: nil,
                domains: [
                    ("1. Conception d'architectures GCP résilientes", "82%", 250.0, "#58cc02"),
                    ("2. Gestion & provisionnement Shared VPC / GKE", "76%", 232.0, "#0078d4"),
                    ("3. Sécurité IAM, Cloud KMS & VPC Service Controls", "70%", 214.0, "#0078d4"),
                    ("4. BigQuery, Cloud Spanner & Fiabilité SRE", "62%", 190.0, "#f59e0b")
                ]
            )
        case "ACE":
            return .init(
                code: "ACE",
                badge: "GOOGLE CLOUD CERTIFIED ASSOCIATE",
                title: "Associate Cloud Engineer (ACE)",
                progression: "60 % (9/15)",
                lastMockExam: "770 / 1000 ✓",
                crestImageFill: nil,
                domains: [
                    ("1. Configuration d'environnements & projets GCP", "86%", 262.0, "#58cc02"),
                    ("2. Déploiement Compute Engine, GKE & Cloud Run", "78%", 238.0, "#58cc02"),
                    ("3. Réseaux VPC, Cloud Load Balancing & Cloud DNS", "71%", 216.0, "#0078d4"),
                    ("4. IAM, Comptes de service & Cloud Logging", "66%", 202.0, "#0078d4")
                ]
            )
        case "AI-102":
            return .init(
                code: "AI-102",
                badge: "MICROSOFT CERTIFIED ASSOCIATE",
                title: "Azure AI Engineer (AI-102)",
                progression: "55 % (8/15)",
                lastMockExam: "790 / 1000 ✓",
                crestImageFill: nil,
                domains: [
                    ("1. Gouvernance & Sécurité Azure AI Services", "88%", 268.0, "#58cc02"),
                    ("2. RAG Hybride, Azure AI Search & OpenAI", "84%", 256.0, "#58cc02"),
                    ("3. Vision par ordinateur & Document Intelligence", "74%", 226.0, "#0078d4"),
                    ("4. Agents IA, Prompt Flow & Content Safety", "68%", 208.0, "#0078d4")
                ]
            )
        case "CKA":
            return .init(
                code: "CKA",
                badge: "CNCF OFFICIAL CERTIFICATION",
                title: "Kubernetes Administrator (CKA)",
                progression: "40 % (6/15)",
                lastMockExam: "730 / 1000 ✓",
                crestImageFill: nil,
                domains: [
                    ("1. Architecture du Cluster, RBAC & etcd Backup", "80%", 244.0, "#58cc02"),
                    ("2. Workloads, Scheduling & DaemonSets", "75%", 228.0, "#0078d4"),
                    ("3. Services, Ingress, CoreDNS & NetworkPolicy", "68%", 208.0, "#0078d4"),
                    ("4. Stockage CSI & Dépannage des Nœuds", "58%", 176.0, "#f59e0b")
                ]
            )
        case "CCA-F":
            return .init(
                code: "CCA-F",
                badge: "ANTHROPIC OFFICIAL CERTIFICATION",
                title: "Claude & Agents MCP (CCA-F)",
                progression: "70 % (10/15)",
                lastMockExam: "825 / 1000 ✓",
                crestImageFill: nil,
                domains: [
                    ("1. Architecture de Prompts & Citations Grounded", "91%", 280.0, "#58cc02"),
                    ("2. Serveurs Model Context Protocol (MCP) & Outils", "85%", 260.0, "#58cc02"),
                    ("3. Évaluations automatisées & Garde-fous", "78%", 238.0, "#0078d4"),
                    ("4. Orchestration Multi-Agents & Caching", "72%", 220.0, "#0078d4")
                ]
            )
        default:
            let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: upper)
            return .init(
                code: upper,
                badge: curriculum.vendorId.uppercased(),
                title: "\(curriculum.examOfficialTitle) (\(upper))",
                progression: "\(curriculum.unitProgressPercentText) (9/15)",
                lastMockExam: "765 / 1000 ✓",
                crestImageFill: nil,
                domains: curriculum.examDomains.prefix(4).map { dom in
                    (dom.title, dom.scorePercent, 230.0, dom.colorHex)
                }
            )
        }
    }
}

public extension CertiGoMascotPose {
    static let onboardingWelcome: Self = .emotionStarryEyes
    static let celebratingTrophy: Self = .emotionBossCrown
    static let errorCorrectionEncouraging: Self = .emotionOopsCaring
}

public extension CertigoParallelTracksPreference {
    var selectedTracks: [CertiGoParallelCertificationTrackID] {
        parallelTrackCodes.compactMap { CertiGoParallelCertificationTrackID(rawValue: $0.uppercased()) }
    }
}

// MARK: - 3. Complete MVVM Native App State Engine (`CertiGoNativeAppState`)

public struct CertiGoNativeAppState: Equatable, Sendable {
    public static let onboardingCompletedDefaultsKey: String = "certigo.native.onboardingCompletedV2"

    public var selectedTab: CertiGoNativeTab = .parcours
    public var activeRouteCode: String = "AZ-104"
    public var selectedVendorInPopover: String = "microsoft"
    public var selectedMimoFilter: CertiGoMimoRailFilter = .allUnits

    // Honest new-user counters & FSRS mastery (zero fake data by default!)
    public var streakDays: Int = 0
    public var gemsCount: Int = 0
    public var heartsCount: Int = 5
    public var lastLostHeartIndex: Int? = nil
    public var heartLossAnimationTrigger: Int = 0
    public var streakFreezeCount: Int = 2
    public var isDoubleXPBoostActive: Bool = false
    public var completedStepsTotal: Int = 0
    public var userXPPoints: Int = 0
    public var completedExamsCount: Int = 0
    public var cortexMasteryByConceptId: [String: ConceptMastery] = [:]

    // Dynamic 3-unit (15-node) curriculum per certification route
    public var unitsByRouteCode: [String: [CertiGoCertificationUnit]] = [
        "AZ-104": CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: "AZ-104")
    ]

    // Overlays, Popovers, Bottom Sheets & FullScreenCovers
    public var showCoursePopover02: Bool = false
    public var activeStepSheet: CertiGoStepSheetMode?
    public var activeGamificationSheet: CertiGoGamificationSheetKind? = nil
    public var showExamLaunchSheet22: Bool = false
    public var showExamNavigatorGridSheet: Bool = false
    public var showExamDetailedCorrectionSheet: Bool = false
    public var selectedDomainForPractice: Int? = nil
    public var showProPaywallSheet27: Bool = false
    public var showMultiTrackSelectorSheet: Bool = false
    public var showAddFriendSheet: Bool = false
    public var selectedFriendProfile: CertiGoSocialProfilePreview? = nil
    public var showSavedAIMemosSheet: Bool = false
    public var showEditProfileSheet: Bool = false
    public var activeSettingsPicker: CertiGoSettingsPickerKind? = nil
    public var isPresentingLessonSession: Bool = false
    public var isPresentingTimedExam23: Bool = false
    public var isPresentingExamReport24: Bool = false
    public var isPresentingOnboardingFlow: Bool = false

    // Active lesson session engine
    public var lessonSession: CertiGoNativeLessonSessionEngine = CertiGoNativeLessonSessionEngine()

    // Timed Mock Exam (Screen 23 & Report 24) — starts clean at Q1 with 0 pre-selected answers and 0 pre-flagged questions!
    public var examQuestions: [CertiGoNativeExamQuestion] = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "AZ-104")
    public var currentExamQuestionIndex: Int = 0
    public var selectedExamChoiceByQuestionNumber: [Int: String] = [:]
    public var flaggedExamQuestionNumbers: Set<Int> = []
    public var remainingExamSeconds: Int = 5399 // 89:59 real countdown
    public var examReportCarouselIndex: Int = 0
    public var lastComputedExamScoreOutOf1000: Int = 0

    // Hub IA (06, 06B, 06C, 06D) & Structured Error Registry (`CG-ERR-xxxx`)
    public var isLiveAIModelConnected: Bool = false
    public var activeDiagnosticError: CertiGoErrorCode? = .aiModelNotConnected1001
    public var errorLogHistory: [CertiGoErrorCode] = [.aiModelNotConnected1001]
    public var showErrorRegistrySheet: Bool = false
    public var isErrorCodeCopied: Bool = false
    public var isAIDrawerOpen06D: Bool = false
    public var isShowingVoiceLive06C: Bool = false
    public var isVoiceLiveListening: Bool = true
    public var voiceLiveTranscriptIndex: Int = 0
    public var aiDrawerSearchQuery: String = ""
    public var aiDraftMessage: String = ""
    public var chatTurns: [CertiGoChatTurn] = []
    public var savedAIMemos: [CertiGoChatTurn] = []
    public var aiThreads: [CertiGoAIThreadItem] = []

    // Social (07 & 25) — starts with 0 friends until the user adds colleagues!
    public var selectedSocialSubTab: Int = 0 // 0 = Podium Semaine (07), 1 = Mes Amis (25)
    public var friendSearchQuery: String = ""
    public var isInviteLinkCopied: Bool = false
    public var lastAddedFriendConfirmation: String? = nil
    public var leaderboardMembers: [CertiGoLeaderboardMember] = CertiGoNativeRichCatalog.defaultLeaderboardMembers
    public var friends: [CertiGoFriendItem] = []
    public var suggestedFriends: [CertiGoSuggestedFriend] = CertiGoNativeRichCatalog.defaultSuggestedFriends

    // Moi, Stats Pro (08B), Settings (28), Onboarding (OB-01..08) & 5-Step Guided App Tour
    public var hasCompletedOnboarding: Bool = false
    public var isAccountConnected: Bool = false
    public var isProMember: Bool = false
    public var connectedAuthProvider: String? = nil
    public var trackedCertificationCodes: [String] = ["AZ-104", "SAA-C03", "PCA"]
    public var userDisplayName: String = "Nouveau Candidat"
    public var userHandle: String = "@architecte"
    public var userAvatarHex: String = "#0078d4"
    public var targetExamDateText: String = "Dans 6 semaines"
    public var selectedRadarAxisIndex: Int = 0
    public var statsTimeRangeLabel: String = "30 jours ▾"
    public var settingsLanguageIndex: Int = 0
    public var settingsExamModeIndex: Int = 0
    public var settingsCoachVoiceIndex: Int = 0
    public var settingsExplanationStyleIndex: Int = 0
    public var settingsPushRemindersOn: Bool = true
    public var settingsDailyRadarOn: Bool = true
    public var settingsHapticsOn: Bool = true
    public static let onboardingStepCount: Int = 8
    public var onboardingStepIndex: Int = 0
    public var onboardingSelectedGoalIds: Set<String> = ["certifs", "ai-radar"]
    public var onboardingSelectedAIRadarIds: Set<String> = ["ai-actors", "ai-agents-mcp"]
    public var onboardingExperienceLevelIndex: Int = 1
    public var onboardingExamDeadlineIndex: Int = 1
    public var onboardingDailyRhythmMinutes: Int = 10
    public var onboardingReminderTimeText: String = "19:30"
    public var onboardingCalibrationChoiceId: String = "B"
    public static let guidedTourStepCount: Int = 5
    public var isPresentingGuidedAppTour: Bool = false
    public var guidedTourStepIndex: Int = 0
    public var returnTabAfterLessonSession: CertiGoNativeTab? = nil

    public init() {}

    public var firstNameText: String {
        let trimmed = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "Nouveau Candidat" else { return "Architecte" }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    public func deduplicatedParallelTrackCodes(
        preferred: [String] = []
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        let candidates = [activeRouteCode] + preferred + trackedCertificationCodes + ["AZ-104", "SAA-C03", "PCA"]
        for raw in candidates {
            let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !code.isEmpty, seen.insert(code).inserted else { continue }
            result.append(code)
            if result.count == 3 {
                break
            }
        }
        return result
    }

    public func routeCompletedLessonsCount(forRouteCode code: String) -> Int {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let units = unitsByRouteCode[upper] else { return 0 }
        return units.flatMap(\.lessons).filter { $0.state == .completed }.count
    }

    public func routeProgressPercent(forRouteCode code: String) -> Int {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let units = unitsByRouteCode[upper] ?? CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: upper)
        let allLessons = units.flatMap(\.lessons)
        guard !allLessons.isEmpty else { return 0 }
        let done = allLessons.filter { $0.state == .completed }.count
        return Int((Double(done) / Double(allLessons.count) * 100.0).rounded())
    }

    public func domainMasteryPercent(forRouteCode code: String, domainIndex: Int) -> Int {
        let doneInRoute = routeCompletedLessonsCount(forRouteCode: code)
        guard doneInRoute > 0 || completedExamsCount > 0 else { return 0 }
        let baseFromLessons = doneInRoute * 14
        let baseFromExams = completedExamsCount > 0 ? max(25, lastComputedExamScoreOutOf1000 / 12) : 0
        let domainOffset = max(0, (3 - (domainIndex % 4)) * 4)
        return min(98, max(12, baseFromLessons + baseFromExams + domainOffset))
    }

    public mutating func startOnboardingFlow() {
        onboardingStepIndex = 0
        isPresentingOnboardingFlow = true
    }

    public mutating func advanceOnboardingStep() {
        if onboardingStepIndex + 1 < Self.onboardingStepCount {
            onboardingStepIndex += 1
        } else {
            completeOnboardingFlow(awardWelcomeBonus: false)
        }
    }

    public mutating func goBackOnboardingStep() {
        if onboardingStepIndex > 0 {
            onboardingStepIndex -= 1
        }
    }

    public mutating func dismissOnboardingFlow() {
        isPresentingOnboardingFlow = false
    }

    public mutating func connectMicrosoftEntraAccount() {
        connectAccount(provider: "Microsoft Entra ID")
    }

    public mutating func connectAccount(provider: String) {
        isAccountConnected = true
        connectedAuthProvider = provider
        if userDisplayName == "Nouveau Candidat" || userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userDisplayName = "Gabriel Chambaud"
            userHandle = "@gabriel"
        }
        syncCurrentUserLeaderboardEntry()
    }

    public mutating func completeOnboardingFlow(
        awardWelcomeBonus: Bool = true,
        startGuidedTour: Bool = true
    ) {
        hasCompletedOnboarding = true
        isPresentingOnboardingFlow = false
        if awardWelcomeBonus && gemsCount == 0 {
            gemsCount = 50
        }
        syncCurrentUserLeaderboardEntry()
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletedDefaultsKey)
        if startGuidedTour {
            startGuidedAppTour()
        }
    }

    public mutating func startGuidedAppTour() {
        guidedTourStepIndex = 0
        isPresentingGuidedAppTour = true
        selectedTab = .parcours
    }

    public mutating func syncTabForGuidedTourStep() {
        switch guidedTourStepIndex {
        case 0:
            selectedTab = .parcours
        case 1:
            selectedTab = .examens
        case 2:
            selectedTab = .hubIA
        case 3:
            selectedTab = .social
        default:
            selectedTab = .moi
        }
    }

    public mutating func advanceGuidedTourStep() {
        if guidedTourStepIndex + 1 < Self.guidedTourStepCount {
            guidedTourStepIndex += 1
            syncTabForGuidedTourStep()
        } else {
            isPresentingGuidedAppTour = false
            selectedTab = .parcours
        }
    }

    public mutating func goBackGuidedTourStep() {
        if guidedTourStepIndex > 0 {
            guidedTourStepIndex -= 1
            syncTabForGuidedTourStep()
        }
    }

    public mutating func dismissGuidedAppTour() {
        isPresentingGuidedAppTour = false
        selectedTab = .parcours
    }

    public mutating func toggleOnboardingGoal(_ goalId: String) {
        if onboardingSelectedGoalIds.contains(goalId) {
            if onboardingSelectedGoalIds.count > 1 {
                onboardingSelectedGoalIds.remove(goalId)
            }
        } else {
            onboardingSelectedGoalIds.insert(goalId)
        }
    }

    public mutating func toggleOnboardingAIRadar(_ radarId: String) {
        if onboardingSelectedAIRadarIds.contains(radarId) {
            if onboardingSelectedAIRadarIds.count > 1 {
                onboardingSelectedAIRadarIds.remove(radarId)
            }
        } else {
            onboardingSelectedAIRadarIds.insert(radarId)
        }
    }

    public mutating func resetToFreshNewUser() {
        UserDefaults.standard.set(false, forKey: Self.onboardingCompletedDefaultsKey)
        self = CertiGoNativeAppState()
        self.isPresentingOnboardingFlow = true
    }

    public mutating func toggleOnboardingCertification(_ code: String) {
        let upper = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let idx = trackedCertificationCodes.firstIndex(of: upper) {
            if trackedCertificationCodes.count > 1 {
                trackedCertificationCodes.remove(at: idx)
            }
        } else {
            if trackedCertificationCodes.count >= 3 {
                trackedCertificationCodes.removeLast()
            }
            trackedCertificationCodes.insert(upper, at: 0)
        }
        selectRoute(trackedCertificationCodes.first ?? upper)
    }

    public var currentUnits: [CertiGoCertificationUnit] {
        let upper = activeRouteCode.uppercased()
        return unitsByRouteCode[upper] ?? CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: upper)
    }

    public var filteredUnitsForMimoRail: [CertiGoCertificationUnit] {
        let all = currentUnits
        switch selectedMimoFilter {
        case .allUnits, .examPrep:
            return all
        case .unit1:
            return all.filter { $0.unitNumber == 1 }
        case .unit2:
            return all.filter { $0.unitNumber == 2 }
        case .unit3:
            return all.filter { $0.unitNumber == 3 }
        case .miniLabs:
            return all.map { unit in
                var copy = unit
                copy.lessons = unit.lessons.filter { $0.state == .miniLab || $0.state == .active }
                return copy
            }
        }
    }

    public func lessonNode(withId lessonId: String) -> CertiGoPathLessonNode? {
        for unit in currentUnits {
            if let found = unit.lessons.first(where: { $0.id.caseInsensitiveCompare(lessonId) == .orderedSame }) {
                return found
            }
        }
        return currentUnits.first?.lessons.first
    }

    public var activeLessonNode: CertiGoPathLessonNode {
        for unit in currentUnits {
            if let active = unit.lessons.first(where: { $0.state == .active }) {
                return active
            }
        }
        return currentUnits[0].lessons[0]
    }

    public mutating func selectRoute(_ routeCode: String) {
        let upper = routeCode.uppercased()
        activeRouteCode = upper
        selectedMimoFilter = .allUnits
        if unitsByRouteCode[upper] == nil {
            unitsByRouteCode[upper] = CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: upper)
        }
        examQuestions = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: upper)
        showCoursePopover02 = false
    }

    public mutating func openStepPreviewSheet(forLessonId lessonId: String) {
        activeStepSheet = .preview03(lessonId: lessonId)
    }

    public mutating func toggleStepMemoSheet14() {
        guard let current = activeStepSheet else {
            activeStepSheet = .memo14(lessonId: activeLessonNode.id)
            return
        }
        switch current {
        case .preview03(let id):
            activeStepSheet = .memo14(lessonId: id)
        case .memo14(let id):
            activeStepSheet = .preview03(lessonId: id)
        }
    }

    public mutating func startLessonSession(
        forLessonId lessonId: String? = nil,
        skipDeclic15: Bool = false,
        enableAdaptiveReplay: Bool = false,
        originTab: CertiGoNativeTab? = nil
    ) {
        let resolvedNode = lessonId.flatMap { lessonNode(withId: $0) } ?? activeLessonNode
        activeStepSheet = nil
        returnTabAfterLessonSession = originTab
        if heartsCount <= 0 {
            heartsCount = 5
        }
        lessonSession = CertiGoNativeLessonSessionEngine(
            routeCode: activeRouteCode,
            lessonId: resolvedNode.id,
            lessonTitle: resolvedNode.title,
            isShowingDeclicCard15: !skipDeclic15,
            heartsCount: heartsCount,
            enableAdaptiveReplay: enableAdaptiveReplay
        )
        isPresentingLessonSession = true
    }

    public mutating func startDomainSprintSession(forDomainIndex domainIndex: Int) {
        let domains = CertiGoNativeRichCatalog.examDomains(forRouteCode: activeRouteCode)
        let clampedIdx = min(max(domainIndex, 0), max(0, domains.count - 1))
        let domainTitle = domains.isEmpty ? activeLessonNode.title : domains[clampedIdx].title
        let unitNum = min(3, max(1, (clampedIdx % 3) + 1))
        let targetLessonId = "\(activeRouteCode.uppercased())-u\(unitNum)-s1"
        let domainExercises = CertiGoNativeLessonSessionEngine.defaultExercises(
            forRouteCode: activeRouteCode,
            lessonId: targetLessonId,
            lessonTitle: domainTitle
        )
        selectedDomainForPractice = nil
        returnTabAfterLessonSession = .examens
        selectedTab = .examens
        if heartsCount <= 0 {
            heartsCount = 5
        }
        lessonSession = CertiGoNativeLessonSessionEngine(
            routeCode: activeRouteCode,
            lessonId: targetLessonId,
            lessonTitle: domainTitle,
            isShowingDeclicCard15: false,
            exercises: Array(domainExercises.prefix(5)),
            heartsCount: heartsCount,
            enableAdaptiveReplay: true
        )
        isPresentingLessonSession = true
    }

    public mutating func restartFailedLessonSessionWithFullHearts() {
        heartsCount = 5
        lastLostHeartIndex = nil
        lessonSession = CertiGoNativeLessonSessionEngine(
            routeCode: activeRouteCode,
            lessonId: lessonSession.lessonId,
            lessonTitle: lessonSession.lessonTitle,
            isShowingDeclicCard15: false,
            heartsCount: 5,
            enableAdaptiveReplay: lessonSession.enableAdaptiveReplay
        )
    }

    public mutating func abandonFailedLessonSession() {
        heartsCount = max(0, lessonSession.heartsCount)
        lastLostHeartIndex = lessonSession.lastLostHeartIndex
        isPresentingLessonSession = false
    }

    /// Unlocks the next node on the dynamic winding path when the user finishes a lesson with at least 1 heart remaining!
    public mutating func completeActiveLessonSessionAndUnlockNextNode(now: Date = Date()) {
        // 5 errors (0 hearts left) blocks advancing to the next step!
        guard !lessonSession.isSessionFailedOutOfHearts else {
            heartsCount = 0
            isPresentingLessonSession = false
            return
        }

        let upper = activeRouteCode.uppercased()
        var units = unitsByRouteCode[upper] ?? CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: upper)

        var flatNodes = units.flatMap(\.lessons)
        let targetIndex = flatNodes.firstIndex(where: { $0.id.caseInsensitiveCompare(lessonSession.lessonId) == .orderedSame })
            ?? flatNodes.firstIndex(where: { $0.state == .active })
            ?? 0

        // Mark completed node as .completed (keeping its topic iconSymbol)
        let completedNode = flatNodes[targetIndex]
        flatNodes[targetIndex] = CertiGoPathLessonNode(
            id: completedNode.id,
            unitNumber: completedNode.unitNumber,
            stepIndexInUnit: completedNode.stepIndexInUnit,
            globalIndex: completedNode.globalIndex,
            title: completedNode.title,
            subtitle: completedNode.subtitle,
            state: .completed,
            iconSymbol: completedNode.iconSymbol,
            levelBadge: "Niv. 3/3 ✓",
            horizontalOffsetFactor: completedNode.horizontalOffsetFactor
        )

        // Promote the next non-completed node to .active (keeping its topic iconSymbol)
        if !flatNodes.contains(where: { $0.state == .active }) {
            if let nextIdx = flatNodes.indices.first(where: { $0 > targetIndex && flatNodes[$0].state != .completed }) {
                let nextNode = flatNodes[nextIdx]
                flatNodes[nextIdx] = CertiGoPathLessonNode(
                    id: nextNode.id,
                    unitNumber: nextNode.unitNumber,
                    stepIndexInUnit: nextNode.stepIndexInUnit,
                    globalIndex: nextNode.globalIndex,
                    title: nextNode.title,
                    subtitle: nextNode.subtitle,
                    state: .active,
                    iconSymbol: nextNode.iconSymbol,
                    levelBadge: nextNode.state == .miniLab ? "🧪 Mini-Lab" : "Niv. 1/3",
                    horizontalOffsetFactor: nextNode.horizontalOffsetFactor
                )
            }
        }

        // Rebuild units with updated node states and unit progress percentages
        for uIdx in units.indices {
            let unitNum = units[uIdx].unitNumber
            let updatedLessons = flatNodes.filter { $0.unitNumber == unitNum }
            let doneCount = updatedLessons.filter { $0.state == .completed }.count
            let pct = Int((Double(doneCount) / Double(max(1, updatedLessons.count)) * 100.0).rounded())
            units[uIdx] = CertiGoCertificationUnit(
                id: units[uIdx].id,
                unitNumber: unitNum,
                headerTitle: units[uIdx].headerTitle,
                subtitle: units[uIdx].subtitle,
                progressPercent: max(units[uIdx].progressPercent, pct),
                accentHex: units[uIdx].accentHex,
                lipHex: units[uIdx].lipHex,
                memoActivity: units[uIdx].memoActivity,
                memoKeyTopics: units[uIdx].memoKeyTopics,
                memoGoldenRule: units[uIdx].memoGoldenRule,
                lessons: updatedLessons
            )
        }
        unitsByRouteCode[upper] = units

        // Update counters & CertigoCortex FSRS ConceptMastery
        heartsCount = lessonSession.heartsCount
        lastLostHeartIndex = lessonSession.lastLostHeartIndex
        streakDays = max(1, streakDays)
        gemsCount += 15
        completedStepsTotal += 1
        userXPPoints += isDoubleXPBoostActive ? 50 : 25
        syncCurrentUserLeaderboardEntry()

        let conceptKey = "\(upper.lowercased()):\(lessonSession.lessonId.lowercased())"
        let baseMastery = cortexMasteryByConceptId[conceptKey]
            ?? (try? ConceptMastery.fresh(conceptId: conceptKey, trackId: upper, now: now))
        if let baseMastery,
           let updatedMastery = try? ReviewScheduler.apply(
               baseMastery,
               grade: ReviewGrade.from(correct: lessonSession.accuracyPercent >= 50, latencyMs: 2_600),
               now: now
           )
        {
            cortexMasteryByConceptId[conceptKey] = updatedMastery
        }
        isPresentingLessonSession = false
        if let returnTab = returnTabAfterLessonSession {
            selectedTab = returnTab
            returnTabAfterLessonSession = nil
        }
    }

    public mutating func syncCurrentUserLeaderboardEntry() {
        if let meIdx = leaderboardMembers.firstIndex(where: \.isCurrentUser) {
            let firstToken = userDisplayName.split(separator: " ").first.map(String.init) ?? userDisplayName
            let existing = leaderboardMembers[meIdx]
            leaderboardMembers[meIdx] = CertiGoLeaderboardMember(
                id: existing.id,
                rank: existing.rank,
                displayName: "Toi (\(firstToken))",
                initials: userInitials,
                routeBadge: activeRouteCode,
                xpPoints: userXPPoints,
                streakDays: streakDays,
                isCurrentUser: true,
                avatarHex: userAvatarHex
            )
        }
        let sorted = leaderboardMembers.sorted { lhs, rhs in
            if lhs.xpPoints != rhs.xpPoints {
                return lhs.xpPoints > rhs.xpPoints
            }
            return !lhs.isCurrentUser && rhs.isCurrentUser
        }
        leaderboardMembers = sorted.enumerated().map { idx, item in
            CertiGoLeaderboardMember(
                id: item.id,
                rank: idx + 1,
                displayName: item.displayName,
                initials: item.initials,
                routeBadge: item.routeBadge,
                xpPoints: item.xpPoints,
                streakDays: item.streakDays,
                isCurrentUser: item.isCurrentUser,
                avatarHex: item.avatarHex
            )
        }
    }

    // MARK: Timed Mock Exam (Screen 23 & Report 24)

    public var currentExamQuestion: CertiGoNativeExamQuestion {
        guard !examQuestions.isEmpty else {
            return CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: activeRouteCode)[0]
        }
        let clamped = min(max(currentExamQuestionIndex, 0), examQuestions.count - 1)
        return examQuestions[clamped]
    }

    public var formattedExamCountdown: String {
        let mins = max(0, remainingExamSeconds) / 60
        let secs = max(0, remainingExamSeconds) % 60
        let minStr = mins < 10 ? "0\(mins)" : "\(mins)"
        let secStr = secs < 10 ? "0\(secs)" : "\(secs)"
        return "⏱  \(minStr) : \(secStr)"
    }

    public mutating func startTimedExam23() {
        showExamLaunchSheet22 = false
        examQuestions = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: activeRouteCode)
        currentExamQuestionIndex = 0
        remainingExamSeconds = 5399 // 89:59
        isPresentingTimedExam23 = true
    }

    public mutating func tickExamTimerOneSecond() {
        if remainingExamSeconds > 0 {
            remainingExamSeconds -= 1
        }
    }

    public mutating func selectExamChoice(_ choiceId: String) {
        let qNum = currentExamQuestion.number
        selectedExamChoiceByQuestionNumber[qNum] = choiceId
    }

    public mutating func toggleFlagOnCurrentExamQuestion() {
        let qNum = currentExamQuestion.number
        if flaggedExamQuestionNumbers.contains(qNum) {
            flaggedExamQuestionNumbers.remove(qNum)
        } else {
            flaggedExamQuestionNumbers.insert(qNum)
        }
    }

    public var examExactCorrectCount: Int {
        var correct = 0
        for q in examQuestions {
            if let picked = selectedExamChoiceByQuestionNumber[q.number],
               let choice = q.choices.first(where: { $0.id == picked }),
               choice.isCorrect
            {
                correct += 1
            }
        }
        return correct
    }

    public mutating func finishTimedExamAndComputeScore() {
        let total = max(1, examQuestions.count)
        let correct = examExactCorrectCount
        // Scale to Pearson VUE 100..1000 range
        let scaled = Int((Double(correct) / Double(total) * 900.0 + 100.0).rounded())
        lastComputedExamScoreOutOf1000 = min(1000, max(100, scaled))
        completedExamsCount += 1
        streakDays = max(1, streakDays)
        userXPPoints += 100
        syncCurrentUserLeaderboardEntry()
        isPresentingTimedExam23 = false
        examReportCarouselIndex = 0
        isPresentingExamReport24 = true
    }

    // MARK: Multi-Turn AI Coach Hub (06, 06B, 06C, 06D) & Honest Disconnected Error Handling

    public var filteredAIThreads: [CertiGoAIThreadItem] {
        let q = aiDrawerSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return aiThreads }
        return aiThreads.filter {
            $0.title.lowercased().contains(q)
                || $0.subtitle.lowercased().contains(q)
                || $0.routeBadge.lowercased().contains(q)
        }
    }

    public mutating func triggerDiagnosticError(_ error: CertiGoErrorCode) {
        activeDiagnosticError = error
        isErrorCodeCopied = false
        if errorLogHistory.last != error {
            errorLogHistory.append(error)
        }
    }

    public mutating func openAITopic(_ topicKey: String, customUserQuestion: String? = nil) {
        isAIDrawerOpen06D = false
        let payload = CertiGoFigmaLiveRuntimeState.aiTopicsById[topicKey]
            ?? CertiGoFigmaLiveRuntimeState.aiTopicsById["rbac-vs-policy"]!
        let promptText = customUserQuestion ?? payload.question
        let turn = CertiGoChatTurn(
            id: "turn-\(chatTurns.count + 1)-\(topicKey)",
            userPrompt: promptText,
            aiHeadline: payload.intro,
            aiBullet1: payload.bullet1,
            aiBullet2: payload.bullet2,
            examKeyRule1: payload.examRule1,
            examKeyRule2: payload.examRule2,
            closingTip: isLiveAIModelConnected
                ? payload.closing
                : "\(payload.closing)\n\nℹ️ Synthèse locale hors-ligne certifiée · Le mode conversationnel libre nécessite la connexion Azure AI Foundry (CG-ERR-1001)."
        )
        chatTurns.append(turn)
        if !aiThreads.contains(where: { $0.topicKey == topicKey && $0.routeBadge == activeRouteCode }) {
            aiThreads.insert(
                CertiGoAIThreadItem(
                    id: "th-\(aiThreads.count + 1)-\(topicKey)",
                    title: promptText,
                    subtitle: isLiveAIModelConnected ? "Aujourd'hui · Session Coach IA" : "Aujourd'hui · Fiche Synthèse Locale",
                    routeBadge: activeRouteCode,
                    isPinned: aiThreads.isEmpty,
                    topicKey: topicKey
                ),
                at: 0
            )
        }
        if !isLiveAIModelConnected {
            let errorToTrigger: CertiGoErrorCode = topicKey == "last-3-errors"
                ? .examReportAIDisconnected1003
                : .aiModelNotConnected1001
            triggerDiagnosticError(errorToTrigger)
        } else {
            activeDiagnosticError = nil
        }
    }

    public mutating func sendAIMessage(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard isLiveAIModelConnected else {
            triggerDiagnosticError(.aiModelNotConnected1001)
            aiDraftMessage = ""
            return
        }
        activeDiagnosticError = nil
        let lower = trimmed.lowercased()
        let matchedKey: String = {
            if lower.contains("policy") || lower.contains("rbac") { return "rbac-vs-policy" }
            if lower.contains("cli") || lower.contains("commande") { return "cli-example" }
            if lower.contains("erreur") || lower.contains("faible") { return "last-3-errors" }
            if lower.contains("peering") || lower.contains("vnet") { return "vnet-peering-cli" }
            if lower.contains("pim") || lower.contains("entra") { return "entra-pim-oral" }
            if lower.contains("verrou") || lower.contains("lock") { return "cannotdelete-lock" }
            if lower.contains("waf") || lower.contains("gateway") { return "appgw-vs-lb" }
            return "custom"
        }()

        if matchedKey != "custom", let topic = CertiGoFigmaLiveRuntimeState.aiTopicsById[matchedKey] {
            let turn = CertiGoChatTurn(
                id: "turn-\(chatTurns.count + 1)",
                userPrompt: trimmed,
                aiHeadline: topic.intro,
                aiBullet1: topic.bullet1,
                aiBullet2: topic.bullet2,
                examKeyRule1: topic.examRule1,
                examKeyRule2: topic.examRule2,
                closingTip: topic.closing
            )
            chatTurns.append(turn)
        } else {
            let turn = CertiGoChatTurn(
                id: "turn-\(chatTurns.count + 1)",
                userPrompt: trimmed,
                aiHeadline: "Voici l'analyse architecturale CertiGo IA pour « \(trimmed) » (\(activeRouteCode)) :",
                aiBullet1: "•  1. Plan d'identité & Gouvernance : Applique systématiquement le moindre privilège (RBAC / IAM) combiné aux garde-fous Policy et aux verrous ARM.",
                aiBullet2: "•  2. Plan réseau & Isolation PaaS : Privilégie Private Endpoint avec une zone DNS privée privatelink.* liée au VNet et désactive l'accès réseau public.",
                examKeyRule1: "•  Piège classique Pearson VUE : Un verrou CanNotDelete ou un Deny explicite bloque même un Propriétaire (Owner).",
                examKeyRule2: "•  Réflexe examen : Identifie si la contrainte porte sur la couche 7 HTTP/WAF (Application Gateway) ou la couche 4 TCP/UDP (Load Balancer).",
                closingTip: "Touche « 🎯 Quiz » pour tester immédiatement ce concept ou pose une question de suivi !"
            )
            chatTurns.append(turn)
        }
        aiThreads.insert(
            CertiGoAIThreadItem(
                id: "th-\(aiThreads.count + 1)",
                title: trimmed,
                subtitle: "À l'instant · Discussion IA",
                routeBadge: activeRouteCode,
                isPinned: false,
                topicKey: matchedKey
            ),
            at: 0
        )
        aiDraftMessage = ""
    }

    // MARK: Social Friends Filter & Salut

    public var filteredFriends: [CertiGoFriendItem] {
        let q = friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return friends }
        return friends.filter {
            $0.displayName.lowercased().contains(q)
                || $0.handle.lowercased().contains(q)
                || $0.activeTrackText.lowercased().contains(q)
        }
    }

    public mutating func toggleSalutFriend(id: String) {
        guard let idx = friends.firstIndex(where: { $0.id == id }) else { return }
        friends[idx].isSaluted.toggle()
    }

    public mutating func addNewFriendFromSearch() {
        let raw = friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let cleanName = raw.replacingOccurrences(of: "@", with: "").capitalized
        let initials = String(cleanName.prefix(2)).uppercased()
        let newFriend = CertiGoFriendItem(
            id: "fr-custom-\(friends.count + 1)",
            displayName: cleanName,
            handle: raw.hasPrefix("@") ? raw.lowercased() : "@\(raw.lowercased())",
            initials: initials.isEmpty ? "CG" : initials,
            activeTrackText: "\(activeRouteCode) · Nouveau partenaire",
            streakDays: 1,
            avatarHex: "#0078d4",
            isSaluted: true
        )
        friends.insert(newFriend, at: 0)
        lastAddedFriendConfirmation = "\(newFriend.displayName) ajouté(e) à tes partenaires d'étude ✓"
        friendSearchQuery = ""
    }

    public mutating func addSuggestedFriend(_ suggestionId: String) {
        guard let idx = suggestedFriends.firstIndex(where: { $0.id == suggestionId || $0.handle.caseInsensitiveCompare(suggestionId) == .orderedSame || $0.displayName.caseInsensitiveCompare(suggestionId) == .orderedSame }) else {
            return
        }
        addSuggestedFriend(at: idx)
    }

    public mutating func addSuggestedFriend(_ suggestion: CertiGoSuggestedFriend) {
        if let idx = suggestedFriends.firstIndex(where: { $0.id == suggestion.id }) {
            addSuggestedFriend(at: idx)
        } else {
            let newFriend = CertiGoFriendItem(
                id: "fr-\(suggestion.id)",
                displayName: suggestion.displayName,
                handle: suggestion.handle,
                initials: suggestion.initials,
                activeTrackText: suggestion.activeTrackText,
                streakDays: suggestion.streakDays,
                avatarHex: suggestion.avatarHex,
                isSaluted: true
            )
            if !friends.contains(where: { $0.handle.caseInsensitiveCompare(suggestion.handle) == .orderedSame }) {
                friends.insert(newFriend, at: 0)
            }
            lastAddedFriendConfirmation = "\(suggestion.displayName) ajouté(e) à tes partenaires d'étude ✓"
        }
    }

    public mutating func addSuggestedFriend(at index: Int) {
        guard suggestedFriends.indices.contains(index) else { return }
        suggestedFriends[index].isAdded = true
        let suggestion = suggestedFriends[index]
        let newFriend = CertiGoFriendItem(
            id: "fr-\(suggestion.id)",
            displayName: suggestion.displayName,
            handle: suggestion.handle,
            initials: suggestion.initials,
            activeTrackText: suggestion.activeTrackText,
            streakDays: suggestion.streakDays,
            avatarHex: suggestion.avatarHex,
            isSaluted: true
        )
        if !friends.contains(where: { $0.handle.caseInsensitiveCompare(suggestion.handle) == .orderedSame || $0.id == newFriend.id }) {
            friends.insert(newFriend, at: 0)
        }
        lastAddedFriendConfirmation = "\(suggestion.displayName) ajouté(e) à tes partenaires d'étude ✓"
    }

    public mutating func openFriendProfile(for member: CertiGoLeaderboardMember) {
        let rawCodes = member.routeBadge
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let matchedFriend = friends.first(where: { $0.initials == member.initials || member.displayName.contains($0.displayName) })
        let handle = matchedFriend?.handle ?? (member.isCurrentUser ? userHandle : "@\(member.initials.lowercased())_cloud")
        let accuracy = min(98, max(78, 95 - (member.rank - 1) * 2))
        selectedFriendProfile = CertiGoSocialProfilePreview(
            id: "profile-\(member.id)",
            displayName: member.displayName,
            handle: handle,
            initials: member.initials,
            avatarHex: member.avatarHex,
            rank: member.rank,
            xpPoints: member.xpPoints,
            streakDays: member.streakDays,
            examAccuracyPercent: accuracy,
            activeCertifications: rawCodes.isEmpty ? [activeRouteCode] : rawCodes,
            isSaluted: matchedFriend?.isSaluted ?? false
        )
    }

    public mutating func openFriendProfile(for friend: CertiGoFriendItem) {
        let matchedMember = leaderboardMembers.first(where: { $0.initials == friend.initials || $0.displayName == friend.displayName })
        let extractedCode = friend.activeTrackText
            .components(separatedBy: "·")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? activeRouteCode
        let certs = matchedMember?.routeBadge
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? [extractedCode]
        let rank = matchedMember?.rank ?? 6
        let xp = matchedMember?.xpPoints ?? (900 + friend.streakDays * 25)
        let accuracy = min(97, max(79, 82 + friend.streakDays / 2))
        selectedFriendProfile = CertiGoSocialProfilePreview(
            id: "profile-\(friend.id)",
            displayName: friend.displayName,
            handle: friend.handle,
            initials: friend.initials,
            avatarHex: friend.avatarHex,
            rank: rank,
            xpPoints: xp,
            streakDays: friend.streakDays,
            examAccuracyPercent: accuracy,
            activeCertifications: certs.isEmpty ? [activeRouteCode] : certs,
            isSaluted: friend.isSaluted
        )
    }

    public mutating func toggleSalutSelectedProfile() {
        guard var current = selectedFriendProfile else { return }
        current.isSaluted.toggle()
        selectedFriendProfile = current
        if let fIdx = friends.firstIndex(where: { $0.handle == current.handle || $0.initials == current.initials || "profile-\($0.id)" == current.id }) {
            friends[fIdx].isSaluted = current.isSaluted
        }
    }

    // MARK: Gamification Shop & Recovery

    @discardableResult
    public mutating func purchaseStreakFreezeWithGems() -> Bool {
        guard gemsCount >= 200 else { return false }
        gemsCount -= 200
        streakFreezeCount += 1
        return true
    }

    @discardableResult
    public mutating func refillHeartsWithGems() -> Bool {
        guard gemsCount >= 150 else { return false }
        gemsCount -= 150
        heartsCount = 5
        return true
    }

    @discardableResult
    public mutating func activateDoubleXPWithGems() -> Bool {
        guard gemsCount >= 100 else { return false }
        gemsCount -= 100
        isDoubleXPBoostActive = true
        return true
    }

    public mutating func recoverOneHeartForFree() {
        heartsCount = min(5, heartsCount + 1)
    }

    // MARK: Exam Navigator & Swipes

    public mutating func goToNextExamQuestion() {
        guard !examQuestions.isEmpty else { return }
        if currentExamQuestionIndex + 1 < examQuestions.count {
            currentExamQuestionIndex += 1
        }
    }

    public mutating func goToPreviousExamQuestion() {
        if currentExamQuestionIndex > 0 {
            currentExamQuestionIndex -= 1
        }
    }

    public mutating func jumpToExamQuestion(at index: Int) {
        guard !examQuestions.isEmpty else { return }
        currentExamQuestionIndex = min(max(index, 0), examQuestions.count - 1)
        showExamNavigatorGridSheet = false
    }

    // MARK: Saved AI Memos

    public mutating func saveChatTurnToMemo(at index: Int) {
        guard chatTurns.indices.contains(index) else { return }
        chatTurns[index].isSavedToMemo = true
        let updated = chatTurns[index]
        if let existingIdx = savedAIMemos.firstIndex(where: { $0.id == updated.id }) {
            savedAIMemos[existingIdx] = updated
        } else {
            savedAIMemos.insert(updated, at: 0)
        }
    }

    public mutating func saveChatTurnToMemo(_ turn: CertiGoChatTurn) {
        if let idx = chatTurns.firstIndex(where: { $0.id == turn.id }) {
            saveChatTurnToMemo(at: idx)
        } else {
            var copy = turn
            copy.isSavedToMemo = true
            if !savedAIMemos.contains(where: { $0.id == copy.id }) {
                savedAIMemos.insert(copy, at: 0)
            }
        }
    }

    public mutating func removeSavedAIMemo(id: String) {
        savedAIMemos.removeAll { $0.id == id }
        if let idx = chatTurns.firstIndex(where: { $0.id == id }) {
            chatTurns[idx].isSavedToMemo = false
        }
    }

    // MARK: Profile Editor & Settings Pickers

    public var userInitials: String {
        let parts = userDisplayName
            .split(separator: " ")
            .map { String($0.prefix(1)).uppercased() }
            .filter { !$0.isEmpty }
        if parts.count >= 2 {
            return parts[0] + parts[1]
        } else if let first = parts.first {
            return String(userDisplayName.prefix(2)).uppercased().isEmpty ? first : String(userDisplayName.prefix(2)).uppercased()
        }
        return "GC"
    }

    public mutating func updateProfile(
        displayName: String,
        handle: String,
        targetExamDate: String,
        avatarHex: String? = nil
    ) {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanName.isEmpty {
            userDisplayName = cleanName
        }
        let cleanHandle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanHandle.isEmpty {
            userHandle = cleanHandle.hasPrefix("@") ? cleanHandle : "@\(cleanHandle)"
        }
        let cleanDate = targetExamDate.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanDate.isEmpty {
            targetExamDateText = cleanDate
        }
        if let avatarHex, !avatarHex.isEmpty {
            userAvatarHex = avatarHex
        }
        if let meIdx = leaderboardMembers.firstIndex(where: \.isCurrentUser) {
            let firstToken = userDisplayName.split(separator: " ").first.map(String.init) ?? userDisplayName
            let existing = leaderboardMembers[meIdx]
            leaderboardMembers[meIdx] = CertiGoLeaderboardMember(
                id: existing.id,
                rank: existing.rank,
                displayName: "Toi (\(firstToken))",
                initials: userInitials,
                routeBadge: existing.routeBadge,
                xpPoints: existing.xpPoints,
                streakDays: streakDays,
                isCurrentUser: true,
                avatarHex: userAvatarHex
            )
        }
        showEditProfileSheet = false
    }

    public mutating func selectSettingsOption(for kind: CertiGoSettingsPickerKind, index: Int) {
        let safeIndex = max(0, index)
        switch kind {
        case .language:
            settingsLanguageIndex = safeIndex % CertiGoFigmaLiveRuntimeState.settingsLanguageOptions.count
        case .examMode:
            settingsExamModeIndex = safeIndex % CertiGoFigmaLiveRuntimeState.settingsExamModeOptions.count
        case .coachVoice:
            settingsCoachVoiceIndex = safeIndex % CertiGoFigmaLiveRuntimeState.settingsCoachVoiceOptions.count
        case .explanationStyle:
            settingsExplanationStyleIndex = safeIndex % CertiGoFigmaLiveRuntimeState.settingsExplanationStyleOptions.count
        }
        activeSettingsPicker = nil
    }
}

// MARK: - 4. Native SwiftUI Components, 3D Tactile ButtonStyle & Dynamic Views

public enum FigMetrics {
    public static let zero: CGFloat = 0
    public static let one: CGFloat = 1
    public static let two: CGFloat = 2
    public static let three: CGFloat = 3
    public static let four: CGFloat = 4
    public static let five: CGFloat = 5
    public static let six: CGFloat = 6
    public static let eight: CGFloat = 8
    public static let ten: CGFloat = 10
    public static let eleven: CGFloat = 11
    public static let twelve: CGFloat = 12
    public static let thirteen: CGFloat = 13
    public static let fourteen: CGFloat = 14
    public static let fifteenOrSixteen: CGFloat = 15
    public static let sixteen: CGFloat = 16
    public static let seventeen: CGFloat = 17
    public static let eighteen: CGFloat = 18
    public static let nineteen: CGFloat = 19
    public static let twenty: CGFloat = 20
    public static let twentyTwo: CGFloat = 22
    public static let twentyFour: CGFloat = 24
    public static let twentyEight: CGFloat = 28
    public static let thirtyTwo: CGFloat = 32
    public static let thirtySix: CGFloat = 36
    public static let thirtyEight: CGFloat = 38
    public static let forty: CGFloat = 40
    public static let fortyFour: CGFloat = 44
    public static let fortyEight: CGFloat = 48
    public static let fifty: CGFloat = 50
    public static let fiftyTwo: CGFloat = 52
    public static let fiftySix: CGFloat = 56
    public static let sixty: CGFloat = 60
    public static let sixtyFour: CGFloat = 64
    public static let sixtyEight: CGFloat = 68
    public static let seventyTwo: CGFloat = 72
    public static let seventySix: CGFloat = 76
    public static let eighty: CGFloat = 80
    public static let eightyTwo: CGFloat = 82
    public static let eightyFour: CGFloat = 84
    public static let eightyEight: CGFloat = 88
    public static let ninetySix: CGFloat = 96
    public static let oneHundred: CGFloat = 100
    public static let oneHundredTen: CGFloat = 110
    public static let oneHundredTwenty: CGFloat = 120
    public static let oneHundredForty: CGFloat = 140
    public static let oneHundredFifty: CGFloat = 150
    public static let oneHundredFiftySix: CGFloat = 156
    public static let oneHundredSixty: CGFloat = 160
    public static let oneHundredSeventyFive: CGFloat = 175
    public static let oneHundredEighty: CGFloat = 180
    public static let oneHundredNinetyTwo: CGFloat = 192
    public static let twoHundred: CGFloat = 200
    public static let twoHundredTwenty: CGFloat = 220
    public static let twoHundredForty: CGFloat = 240
    public static let twoHundredFortyEight: CGFloat = 248
    public static let twoHundredSixty: CGFloat = 260
    public static let twoHundredEighty: CGFloat = 280
    public static let threeHundred: CGFloat = 300
    public static let threeHundredTwenty: CGFloat = 320
    public static let oneHundredEight: CGFloat = 108
    public static let pathRowHeight: CGFloat = 136
    public static let pathMaxHorizontalOffset: CGFloat = 92
    public static let bottomBarTotalClearance: CGFloat = 110
    public static let toggleWidth: CGFloat = 48
    public static let toggleHeight: CGFloat = 28
    public static let toggleKnob: CGFloat = 24
    public static let radarSize: CGFloat = 190
}

/// Reusable Apple HIG structured prompt helper and view that strips raw backticks and splits a prompt into a calm scenario paragraph (`#334155` Regular) and a bold final question (`#0f172a` Semi Bold) separated by a 10pt paragraph break.
public struct CertiGoStructuredPromptView: Sendable {
    public let prompt: String

    public init(prompt: String) {
        self.prompt = prompt
    }

    public static func splitScenarioAndQuestion(_ rawPrompt: String) -> (scenario: String?, question: String) {
        let sanitized = rawPrompt
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else {
            return (scenario: nil, question: "")
        }

        // 1. Explicit newline separation
        if sanitized.contains("\n") {
            let lines = sanitized
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if lines.count >= 2, let lastLine = lines.last {
                let scenarioText = lines.dropLast().joined(separator: " ")
                return (scenario: scenarioText, question: lastLine)
            } else if let onlyLine = lines.first {
                return (scenario: nil, question: onlyLine)
            }
        }

        // 2. Automatic sentence boundary split before a final question or directive sentence
        let questionStarters = [
            "Quel", "Quelle", "Quels", "Quelles",
            "Comment", "Pourquoi", "Complète", "Assemble",
            "Associe", "Ordonne", "Que ", "Lequel",
            "Laquelle", "Dans quel", "Dans quelle", "À quelle"
        ]
        let boundaries = [". ", "! ", " : "]
        var bestSplitIndex: String.Index?
        var bestQuestionStart: String.Index?

        for boundary in boundaries {
            var searchRange = sanitized.startIndex..<sanitized.endIndex
            while let range = sanitized.range(of: boundary, options: .backwards, range: searchRange) {
                let candidateScenario = String(sanitized[..<range.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let candidateQuestion = String(sanitized[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let startsWithKeyword = questionStarters.contains { candidateQuestion.hasPrefix($0) }
                let endsWithQuestionMark = candidateQuestion.hasSuffix("?")
                if !candidateScenario.isEmpty && !candidateQuestion.isEmpty && (startsWithKeyword || endsWithQuestionMark) {
                    if bestSplitIndex == nil || range.lowerBound > bestSplitIndex! {
                        bestSplitIndex = range.lowerBound
                        bestQuestionStart = range.upperBound
                    }
                    break
                }
                searchRange = sanitized.startIndex..<range.lowerBound
            }
        }

        if let splitIdx = bestSplitIndex, let qStart = bestQuestionStart {
            let punctuationEnd = sanitized.index(after: splitIdx)
            let scenarioPart = String(sanitized[..<punctuationEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            let questionPart = String(sanitized[qStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !scenarioPart.isEmpty && !questionPart.isEmpty {
                return (scenario: scenarioPart, question: questionPart)
            }
        }

        return (scenario: nil, question: sanitized)
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

extension CertiGoStructuredPromptView: View {
    public var body: some View {
        let parts = Self.splitScenarioAndQuestion(prompt)
        VStack(alignment: .leading, spacing: FigMetrics.ten) {
            if let scenario = parts.scenario, !scenario.isEmpty {
                Text(verbatim: scenario)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#334155"))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(verbatim: parts.question)
                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Lead-Architect Rule 3: True 3D Tactile Duolingo/Apple ButtonStyle compressing the bottom 3D lip on press.
public struct CertiGoTactile3DButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let faceHex: String
    public let lipHex: String
    public let strokeHex: String?
    public let cornerRadius: CGFloat
    public let lipDepth: CGFloat

    public init(
        faceHex: String = "#0078d4",
        lipHex: String = "#005a9e",
        strokeHex: String? = nil,
        cornerRadius: CGFloat = PrismRadius.l,
        lipDepth: CGFloat = PrismSize.lipDepth
    ) {
        self.faceHex = faceHex
        self.lipHex = lipHex
        self.strokeHex = strokeHex
        self.cornerRadius = cornerRadius
        self.lipDepth = lipDepth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let currentLip = configuration.isPressed ? FigMetrics.one : lipDepth
        let yOffset = configuration.isPressed ? max(FigMetrics.zero, lipDepth - FigMetrics.one) : FigMetrics.zero

        configuration.label
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PrismColor.figmaHex(faceHex))
            )
            .overlay(
                Group {
                    if let strokeHex {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex(strokeHex), lineWidth: PrismBorder.standard)
                    }
                }
            )
            .offset(y: yOffset)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PrismColor.figmaHex(lipHex))
                    .offset(y: currentLip + yOffset)
            )
            .padding(.bottom, lipDepth)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(
                CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

/// Lead-Architect Rule 1: Dynamic cubic Bézier sinuous path connecting lesson nodes in a unit.
public struct CertiGoDynamicSinuousPathView: View {
    public let lessons: [CertiGoPathLessonNode]
    public let containerWidth: CGFloat

    public init(lessons: [CertiGoPathLessonNode], containerWidth: CGFloat) {
        self.lessons = lessons
        self.containerWidth = containerWidth
    }

    private func centerPoint(for index: Int) -> CGPoint {
        let node = lessons[index]
        let centerX = containerWidth * 0.5 + CGFloat(node.horizontalOffsetFactor) * FigMetrics.pathMaxHorizontalOffset
        let centerY = CGFloat(index) * FigMetrics.pathRowHeight + FigMetrics.pathRowHeight * 0.5
        return CGPoint(x: centerX, y: centerY)
    }

    private func appendOrthogonalRoundedStep(from p0: CGPoint, to p1: CGPoint, into path: inout Path) {
        let dx = p1.x - p0.x
        let midY = (p0.y + p1.y) * 0.5
        guard abs(dx) >= 1 else {
            path.addLine(to: p1)
            return
        }
        let r = min(FigMetrics.twentyEight, abs(dx) * 0.45, abs(midY - p0.y) * 0.85)
        let dirX: CGFloat = dx > 0 ? 1 : -1
        path.addLine(to: CGPoint(x: p0.x, y: midY - r))
        path.addQuadCurve(
            to: CGPoint(x: p0.x + dirX * r, y: midY),
            control: CGPoint(x: p0.x, y: midY)
        )
        path.addLine(to: CGPoint(x: p1.x - dirX * r, y: midY))
        path.addQuadCurve(
            to: CGPoint(x: p1.x, y: midY + r),
            control: CGPoint(x: p1.x, y: midY)
        )
        path.addLine(to: p1)
    }

    public var body: some View {
        let totalHeight = CGFloat(max(1, lessons.count)) * FigMetrics.pathRowHeight
        ZStack {
            // Upcoming grey 90° orthogonal rounded tubular track (Figma 37:375 `Path_SCurve_BezierTrack`)
            Path { path in
                guard !lessons.isEmpty else { return }
                let first = centerPoint(for: 0)
                path.move(to: CGPoint(x: first.x, y: 0))
                path.addLine(to: first)
                guard lessons.count >= 2 else { return }
                for idx in 0..<(lessons.count - 1) {
                    let p0 = centerPoint(for: idx)
                    let p1 = centerPoint(for: idx + 1)
                    appendOrthogonalRoundedStep(from: p0, to: p1, into: &path)
                }
            }
            .stroke(
                PrismColor.figmaHex("#dce4f0"),
                style: StrokeStyle(lineWidth: FigMetrics.fourteen, lineCap: .round, lineJoin: .round)
            )

            // Validated green `#58cc02` tubular segment from top of unit down through completed/active lessons
            Path { path in
                guard !lessons.isEmpty else { return }
                let first = centerPoint(for: 0)
                if lessons[0].state == .completed || lessons[0].state == .active {
                    path.move(to: CGPoint(x: first.x, y: 0))
                    path.addLine(to: first)
                } else {
                    return
                }
                guard lessons.count >= 2 else { return }
                for idx in 0..<(lessons.count - 1) {
                    let current = lessons[idx]
                    let next = lessons[idx + 1]
                    guard current.state == .completed && (next.state == .completed || next.state == .active) else {
                        break
                    }
                    let p0 = centerPoint(for: idx)
                    let p1 = centerPoint(for: idx + 1)
                    appendOrthogonalRoundedStep(from: p0, to: p1, into: &path)
                }
            }
            .stroke(
                PrismColor.figmaHex("#58cc02"),
                style: StrokeStyle(lineWidth: FigMetrics.fourteen, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: containerWidth, height: totalHeight)
    }
}

/// Zelda-style 5 aligned hearts bar (`❤️❤️❤️❤️❤️`) with elastic heart-shatter animation whenever a mistake is made.
public struct CertiGoZeldaHeartsRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let heartsCount: Int
    public let justLostHeartIndex: Int?
    public let animationTrigger: Int
    public let heartSize: CGFloat

    @State private var isAnimatingLoss: Bool = false

    public init(
        heartsCount: Int,
        justLostHeartIndex: Int? = nil,
        animationTrigger: Int = 0,
        heartSize: CGFloat = FigMetrics.fourteen
    ) {
        self.heartsCount = max(0, min(5, heartsCount))
        self.justLostHeartIndex = justLostHeartIndex
        self.animationTrigger = animationTrigger
        self.heartSize = heartSize
    }

    public var body: some View {
        HStack(spacing: FigMetrics.three) {
            ForEach(0..<5, id: \.self) { idx in
                let isFilled = idx < heartsCount
                let isJustLost = (idx == justLostHeartIndex) && !isFilled

                ZStack {
                    if isFilled {
                        Image(systemName: "heart.fill")
                            .font(PrismTypography.figmaFont(size: heartSize, style: "Black"))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        PrismColor.figmaHex("#ff4b4b"),
                                        PrismColor.figmaHex("#e11d48")
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(
                                color: PrismColor.figmaHex("#e11d48:35"),
                                radius: FigMetrics.two,
                                x: FigMetrics.zero,
                                y: FigMetrics.one
                            )
                    } else if isJustLost && isAnimatingLoss {
                        Image(systemName: "heart.slash.fill")
                            .font(PrismTypography.figmaFont(size: heartSize + FigMetrics.two, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#ff4b4b"))
                            .scaleEffect(isAnimatingLoss ? 1.45 : 0.85)
                            .rotationEffect(.degrees(isAnimatingLoss ? -14 : 0))
                            .offset(y: isAnimatingLoss ? -FigMetrics.five : FigMetrics.zero)
                    } else {
                        Image(systemName: "heart")
                            .font(PrismTypography.figmaFont(size: heartSize, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#cbd5e1"))
                    }
                }
            }
        }
        .onChange(of: animationTrigger) { _, _ in
            guard !reduceMotion else { return }
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                isAnimatingLoss = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                    isAnimatingLoss = false
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vies restantes : \(heartsCount) sur 5")
    }
}

/// Reusable 3D tactile Empty State Card (`CertiGoEmptyStateCardView`) for honest empty states when the user has not yet generated data.
public struct CertiGoEmptyStateCardView: View {
    public let mascotPose: CertiGoMascotPose
    public let title: String
    public let subtitle: String
    public let actionTitle: String?
    public let onAction: (() -> Void)?

    public init(
        mascotPose: CertiGoMascotPose = .onboardingWelcome,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.mascotPose = mascotPose
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: PrismSpacing.m) {
            CertiGoMascotView(pose: mascotPose, size: FigMetrics.eighty)

            Text(verbatim: title)
                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                .multilineTextAlignment(.center)

            Text(verbatim: subtitle)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                .multilineTextAlignment(.center)

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(verbatim: actionTitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .padding(.horizontal, PrismSpacing.l)
                        .frame(height: FigMetrics.fortyFour)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#0078d4",
                        lipHex: "#005a9e",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
            }
        }
        .padding(PrismSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                .fill(PrismColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
        )
    }
}

// MARK: - 5. Master 5-Tab Native iOS Application View (`CertiGoNativeFigmaAppView`)

public struct CertiGoNativeFigmaAppView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var coordinator: PrismAppShellCoordinatorModel
    @Binding public var router: AppRouterState
    public let flags: FeatureFlags
    public let preferenceStore: CertigoParallelTracksPreferenceStore

    @State private var appState = CertiGoNativeAppState()
    @State private var profileNavPath: [CertiGoProfileRoute] = []
    @State private var activeNodePulse: Bool = false
    @State private var voiceHaloPulse: Bool = false
    @FocusState private var isAIInputFocused: Bool

    public init(
        coordinator: Binding<PrismAppShellCoordinatorModel>,
        router: Binding<AppRouterState>,
        flags: FeatureFlags = FeatureFlags(),
        preferenceStore: CertigoParallelTracksPreferenceStore = .shared
    ) {
        self._coordinator = coordinator
        self._router = router
        self.flags = flags
        self.preferenceStore = preferenceStore
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Active Tab Root View
            Group {
                switch appState.selectedTab {
                case .parcours:
                    parcoursTab01View
                case .examens:
                    examensTab21View
                case .hubIA:
                    hubIATab06View
                case .social:
                    socialTab07And25View
                case .moi:
                    moiTab08NavigationStack
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Pinned Floating Bottom Tab Bar (5 Tabs: Parcours, Examens, ✦ IA, Social, Moi)
            if !(appState.selectedTab == .moi && !profileNavPath.isEmpty)
                && !isAIInputFocused
                && !(appState.selectedTab == .hubIA && appState.isAIDrawerOpen06D)
            {
                floatingBottomTabBar
            }

            // Full-Screen Smooth Backdrop Dimmer (opacity-only, zero bottom edge border)
            if appState.activeStepSheet != nil || appState.showExamLaunchSheet22 || appState.showCoursePopover02 {
                Color.black.opacity(0.32)
                    .ignoresSafeArea(.all)
                    .onTapGesture {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            appState.showCoursePopover02 = false
                            appState.activeStepSheet = nil
                            appState.showExamLaunchSheet22 = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(19)
            }

            // OVERLAY 1: Popover 02 (Course & Brand Switcher)
            if appState.showCoursePopover02 {
                popover02OverlayView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(20)
            }

            // OVERLAY 2: Step Floating Sheet 03 & Unfolded Memo Sheet 14
            if let sheetMode = appState.activeStepSheet {
                stepFloatingSheet03And14Overlay(mode: sheetMode)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(25)
            }

            // OVERLAY 3: Apple Pay Exam Launch Sheet 22
            if appState.showExamLaunchSheet22 {
                examApplePaySheet22Overlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(30)
            }

            // OVERLAY 4: Interactive 5-Step Guided App Tour (`isPresentingGuidedAppTour`)
            if appState.isPresentingGuidedAppTour {
                guidedAppTourOverlayView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(35)
            }
        }
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        .sheet(isPresented: $appState.showProPaywallSheet27) {
            certiGoProSheet27View
        }
        .sheet(isPresented: $appState.showMultiTrackSelectorSheet) {
            multiTrackSelectorSheetOB03View
        }
        .sheet(item: $appState.activeGamificationSheet) { sheetKind in
            gamificationSheetView(for: sheetKind)
        }
        .sheet(isPresented: $appState.showAddFriendSheet) {
            addFriendSheetView
        }
        .sheet(item: $appState.selectedFriendProfile) { profile in
            friendProfileSheetView(profile: profile)
        }
        .sheet(
            isPresented: Binding(
                get: { appState.selectedDomainForPractice != nil },
                set: { if !$0 { appState.selectedDomainForPractice = nil } }
            )
        ) {
            domainPracticeModePickerSheetView
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $appState.showSavedAIMemosSheet) {
            savedAIMemosSheetView
        }
        .sheet(isPresented: $appState.showEditProfileSheet) {
            editProfileSheetView
        }
        .sheet(item: $appState.activeSettingsPicker) { pickerKind in
            settingsOptionPickerSheetView(kind: pickerKind)
        }
        .sheet(isPresented: $appState.showErrorRegistrySheet) {
            errorRegistrySheetView
        }
        .fullScreenCover(isPresented: $appState.isPresentingLessonSession) {
            CertiGoNativeLessonSessionModalView(
                appState: $appState,
                onCompleteSession: {
                    withAnimation(CertiGoMotion.spring(for: .anim08CelebrationVictoryJump, reduceMotion: reduceMotion)) {
                        appState.completeActiveLessonSessionAndUnlockNextNode()
                    }
                },
                onJumpToAIHubWithTopic: { topicKey in
                    appState.isPresentingLessonSession = false
                    appState.openAITopic(topicKey)
                    appState.selectedTab = .hubIA
                }
            )
        }
        .fullScreenCover(isPresented: $appState.isPresentingTimedExam23) {
            CertiGoNativeTimedExamCockpit23View(appState: $appState)
        }
        .fullScreenCover(isPresented: $appState.isPresentingExamReport24) {
            CertiGoNativeExamReport24View(
                appState: $appState,
                onExplainErrorsWithAI: {
                    appState.isPresentingExamReport24 = false
                    appState.openAITopic(
                        "last-3-errors",
                        customUserQuestion: "Analyse mes erreurs de l'examen blanc \(appState.activeRouteCode) (\(appState.lastComputedExamScoreOutOf1000) / 1000)"
                    )
                    appState.selectedTab = .hubIA
                }
            )
        }
        .fullScreenCover(isPresented: $appState.isPresentingOnboardingFlow) {
            CertiGoNativeOnboardingFlowView(
                appState: $appState,
                coordinator: $coordinator
            )
        }
        .task {
            let persisted = preferenceStore.loadOrDefault()
            if coordinator.parallelTracksPreference != persisted {
                coordinator.applyPersistedPreferences(persisted)
            }
            appState.selectRoute(coordinator.parallelTracksPreference.activeTrackCode)
            let onboardingDone = UserDefaults.standard.bool(forKey: CertiGoNativeAppState.onboardingCompletedDefaultsKey)
            appState.hasCompletedOnboarding = onboardingDone
            if !onboardingDone {
                appState.startOnboardingFlow()
            }
            withAnimation(
                CertiGoMotion.spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)
                    .repeatForever(autoreverses: true)
            ) {
                activeNodePulse = true
            }
        }
    }

    // MARK: - Pinned Floating Bottom Tab Bar (`CANVAS_BOTTOM_TAB_BAR`)

    private var floatingBottomTabBar: some View {
        HStack(spacing: PrismSpacing.xs) {
            tabBarItemButton(tab: .parcours, symbol: "safari.fill", label: "Parcours")
            tabBarItemButton(tab: .examens, symbol: "scope", label: "Examens")

            // Center 3D AI Hub Orb Button (`✦` — Figma `57:372` White Circle with Multicolor AngularGradient Ring)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                    appState.selectedTab = .hubIA
                    router.selectedTab = .search
                }
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    PrismColor.figmaHex("#0078d4"),
                                    PrismColor.figmaHex("#22c55e"),
                                    PrismColor.figmaHex("#eab308"),
                                    PrismColor.figmaHex("#ef4444"),
                                    PrismColor.figmaHex("#8b5cf6"),
                                    PrismColor.figmaHex("#0078d4")
                                ],
                                center: .center
                            ),
                            lineWidth: 4.5
                        )
                        .frame(width: FigMetrics.fifty, height: FigMetrics.fifty)
                        .shadow(
                            color: PrismColor.figmaHex("#0078d4:24"),
                            radius: FigMetrics.eight,
                            x: FigMetrics.zero,
                            y: FigMetrics.three
                        )

                    Circle()
                        .fill(PrismColor.surface)
                        .frame(width: FigMetrics.thirtyEight, height: FigMetrics.thirtyEight)

                    Text(verbatim: "✦")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("native-tab-hub-ia")

            tabBarItemButton(tab: .social, symbol: "trophy.fill", label: "Social")
            tabBarItemButton(tab: .moi, symbol: "person.crop.circle.fill", label: "Moi")
        }
        .padding(.horizontal, PrismSpacing.m)
        .padding(.vertical, PrismSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.bottomBar, style: .continuous)
                .fill(PrismColor.surface)
                .shadow(
                    color: PrismColor.figmaHex("#0f172a:12"),
                    radius: FigMetrics.twenty,
                    x: FigMetrics.zero,
                    y: FigMetrics.six
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.bottomBar, style: .continuous)
                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.hairline)
        )
        .padding(.horizontal, PrismSpacing.l)
        .padding(.bottom, PrismSpacing.xs)
    }

    private func tabBarItemButton(tab: CertiGoNativeTab, symbol: String, label: String) -> some View {
        let isSelected = appState.selectedTab == tab
        return Button {
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                appState.selectedTab = tab
                switch tab {
                case .parcours: router.selectedTab = .today
                case .examens: router.selectedTab = .atlas
                case .hubIA: router.selectedTab = .search
                case .social: router.selectedTab = .ensemble
                case .moi: router.selectedTab = .profile
                }
            }
        } label: {
            VStack(spacing: PrismSpacing.xxs) {
                Image(systemName: symbol)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                    .foregroundStyle(
                        isSelected ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#64748b")
                    )
                Text(verbatim: label)
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: isSelected ? "Extra Bold" : "Semi Bold"))
                    .foregroundStyle(
                        isSelected ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#64748b")
                    )
            }
            .frame(maxWidth: .infinity)
            .frame(height: PrismSize.tabItemHeight)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .fill(isSelected ? PrismColor.figmaHex("#eff6ff") : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("native-tab-\(tab.rawValue)")
    }

    // MARK: - TAB 1: Parcours (`01`) — Levitating Top Pills over Full-Bleed Orthogonal S-Curve Path

    private var parcoursTab01View: some View {
        let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: appState.activeRouteCode)
        return ZStack(alignment: .top) {
            // Back Layer: Full-Screen Scrolling Path passing directly underneath the levitating top pills & bottom Tab Bar
            GeometryReader { geo in
                let safeWidth = geo.size.width.isFinite ? geo.size.width : FigMetrics.twoHundredEighty
                let stageWidth = max(safeWidth - PrismSpacing.l * 2, FigMetrics.twoHundredEighty)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PrismSpacing.xl) {
                        ForEach(appState.currentUnits) { unit in
                            unitSectionView(unit: unit, stageWidth: stageWidth)
                        }
                    }
                    .padding(.horizontal, PrismSpacing.l)
                    .padding(.top, FigMetrics.seventyTwo)
                    .padding(.bottom, FigMetrics.bottomBarTotalClearance)
                }
                .scrollClipDisabled()
                .ignoresSafeArea(edges: .bottom)
            }
            .background(PrismColor.figmaHex("#f8fafc").ignoresSafeArea())

            // Soft Top Fade Gradient under the 2 floating pills (`LinearGradient` `#f8fafc` -> `#f8fafc.opacity(0)` over 68pt)
            LinearGradient(
                colors: [
                    PrismColor.figmaHex("#f8fafc"),
                    PrismColor.figmaHex("#f8fafc").opacity(0.85),
                    PrismColor.figmaHex("#f8fafc").opacity(0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: FigMetrics.sixtyEight)
            .allowsHitTesting(false)

            // Front Layer: Levitating Top Pills (`[Logo | AZ-104 ▾]` + `[🔥 0  💎 0  ❤️ 5]`) — Exact same 44pt height on 1 single line!
            HStack(spacing: PrismSpacing.s) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showCoursePopover02.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.s) {
                        CertiGoBrandLogoView(vendorId: curriculum.vendorId, size: PrismSize.brandS)
                        Text(verbatim: "\(appState.activeRouteCode) ▾")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, PrismSpacing.m)
                    .frame(height: FigMetrics.fortyFour)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(PrismColor.surface)
                            .shadow(
                                color: PrismColor.figmaHex("#0f172a:14"),
                                radius: FigMetrics.sixteen,
                                x: FigMetrics.zero,
                                y: FigMetrics.six
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("parcours-course-switcher-button")

                Spacer(minLength: PrismSpacing.xs)

                // Levitating Gamification Pill (`🔥 0   💎 0   ❤️ 5` — Figma `37:448`)
                HStack(spacing: PrismSpacing.m) {
                    Button {
                        appState.activeGamificationSheet = .streak
                    } label: {
                        Text(verbatim: "🔥 \(appState.streakDays)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#ea580c"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("parcours-pill-streak")

                    Button {
                        appState.activeGamificationSheet = .gems
                    } label: {
                        Text(verbatim: "💎 \(appState.gemsCount)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("parcours-pill-gems")

                    Button {
                        appState.activeGamificationSheet = .hearts
                    } label: {
                        Text(verbatim: "❤️ \(appState.heartsCount)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#e11d48"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("parcours-pill-hearts")
                }
                .padding(.horizontal, PrismSpacing.m)
                .frame(height: FigMetrics.fortyFour)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.surface)
                        .shadow(
                            color: PrismColor.figmaHex("#0f172a:14"),
                            radius: FigMetrics.sixteen,
                            x: FigMetrics.zero,
                            y: FigMetrics.six
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                )
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.xs)
        }
    }

    private func unitSectionView(unit: CertiGoCertificationUnit, stageWidth: CGFloat) -> some View {
        let rawRatio = CGFloat(unit.progressPercent) / 100.0
        let safeRatio = rawRatio.isFinite ? min(max(rawRatio, 0), 1) : 0

        return VStack(spacing: PrismSpacing.l) {
            // 3D Duolingo-Style Unit Header Banner (`UNITÉ 1 · ...` + `0%` ring + vertical divider + `[📖]` Memo button)
            HStack(spacing: PrismSpacing.m) {
                ZStack {
                    Circle()
                        .stroke(PrismColor.figmaHex("#ffffff:30"), lineWidth: FigMetrics.four)
                        .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                    Circle()
                        .trim(from: 0, to: safeRatio)
                        .stroke(
                            PrismColor.figmaHex("#58cc02"),
                            style: StrokeStyle(lineWidth: FigMetrics.four, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                    Text(verbatim: "\(unit.progressPercent)%")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                }

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: unit.headerTitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                    Text(verbatim: unit.subtitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#e0f2fe"))
                        .lineLimit(1)
                }

                Spacer(minLength: PrismSpacing.xs)

                Rectangle()
                    .fill(PrismColor.figmaHex("#ffffff:26"))
                    .frame(width: PrismBorder.standard, height: FigMetrics.forty)

                Button {
                    let targetLessonId = unit.lessons.first(where: { $0.state == .active })?.id
                        ?? unit.lessons.first?.id
                        ?? appState.activeLessonNode.id
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.activeStepSheet = .memo14(lessonId: targetLessonId)
                    }
                } label: {
                    Text(verbatim: "📖")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                        .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.figmaHex("#ffffff:22"))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("unit-\(unit.unitNumber)-memo-button")
            }
            .padding(PrismSpacing.l)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: PrismRadius.unitBanner, style: .continuous)
                        .fill(PrismColor.figmaHex(unit.lipHex))
                        .offset(y: FigMetrics.five)
                    RoundedRectangle(cornerRadius: PrismRadius.unitBanner, style: .continuous)
                        .fill(PrismColor.figmaHex(unit.accentHex))
                }
            )

            // Dynamic Winding S-Curve + Lesson Islands
            let totalStageHeight = CGFloat(max(1, unit.lessons.count)) * FigMetrics.pathRowHeight
            ZStack(alignment: .top) {
                CertiGoDynamicSinuousPathView(
                    lessons: unit.lessons,
                    containerWidth: stageWidth
                )

                VStack(spacing: .zero) {
                    ForEach(unit.lessons) { lesson in
                        sinuousLessonRowView(lesson: lesson, unitProgressPercent: unit.progressPercent, stageWidth: stageWidth)
                            .frame(width: stageWidth, height: FigMetrics.pathRowHeight)
                    }
                }
            }
            .frame(width: stageWidth, height: totalStageHeight)
        }
    }

    @ViewBuilder
    private func sinuousLessonRowView(
        lesson: CertiGoPathLessonNode,
        unitProgressPercent: Int = 0,
        stageWidth: CGFloat
    ) -> some View {
        let xOffset = CGFloat(lesson.horizontalOffsetFactor) * FigMetrics.pathMaxHorizontalOffset
        let isLeftIsland = lesson.horizontalOffsetFactor <= 0

        if lesson.state == .miniLab {
            // Interactive 3D Mini-Lab Card (`🧪 MINI-LAB PRATIQUE` — Figma `37:420`)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                    appState.startLessonSession(forLessonId: lesson.id, skipDeclic15: true, enableAdaptiveReplay: true)
                }
            } label: {
                HStack(spacing: PrismSpacing.m) {
                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "🧪 MINI-LAB PRATIQUE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#7c3aed"))
                            .padding(.horizontal, PrismSpacing.s)
                            .padding(.vertical, FigMetrics.three)
                            .background(
                                Capsule()
                                    .fill(PrismColor.figmaHex("#f3e8ff"))
                            )

                        Text(verbatim: lesson.title)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            .lineLimit(1)
                    }

                    Spacer(minLength: PrismSpacing.xs)

                    ZStack {
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .fill(PrismColor.figmaHex("#6d28d9"))
                            .offset(y: FigMetrics.four)
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .fill(PrismColor.figmaHex("#8b5cf6"))
                        Text(verbatim: "▶")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                    }
                    .frame(width: FigMetrics.fortyFour, height: FigMetrics.forty)
                }
                .padding(.horizontal, PrismSpacing.l)
                .frame(maxWidth: .infinity)
                .frame(height: FigMetrics.eightyEight)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: "#ffffff",
                    lipHex: "#cbd5e1",
                    strokeHex: "#cbd5e1",
                    cornerRadius: PrismRadius.xl,
                    lipDepth: FigMetrics.five
                )
            )
            .accessibilityIdentifier("path-minilab-\(lesson.id)")
        } else {
            ZStack {
                // 3D Rounded-Square Island Cushion (`72x64pt`, cornerRadius 22pt — Figma `37:375` `PathNode_Island3D`)
                ZStack {
                    if lesson.state == .active {
                        RoundedRectangle(cornerRadius: FigMetrics.twentyEight, style: .continuous)
                            .stroke(PrismColor.figmaHex("#38bdf8:55"), lineWidth: FigMetrics.four)
                            .frame(width: FigMetrics.eightyEight, height: FigMetrics.eightyTwo)
                            .scaleEffect(activeNodePulse ? 1.06 : 0.96)
                    }

                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            appState.openStepPreviewSheet(forLessonId: lesson.id)
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            ZStack {
                                Image(systemName: lesson.iconSymbol)
                                    .font(PrismTypography.figmaFont(size: PrismSize.pathNodeIcon, style: "Bold"))
                                    .foregroundStyle(
                                        lesson.state == .locked
                                            ? PrismColor.figmaHex("#94a3b8")
                                            : (lesson.state == .completed ? PrismColor.figmaHex("#10b981") : PrismColor.figmaHex("#0078d4"))
                                    )
                            }
                            .frame(width: FigMetrics.seventyTwo, height: FigMetrics.sixtyFour)

                            if lesson.state == .completed {
                                Text(verbatim: "✓")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                    .frame(width: FigMetrics.twentyFour, height: FigMetrics.twentyFour)
                                    .background(
                                        Circle()
                                            .fill(PrismColor.figmaHex("#58cc02"))
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(PrismColor.surface, lineWidth: FigMetrics.two)
                                    )
                                    .offset(x: FigMetrics.six, y: -FigMetrics.six)
                            }
                        }
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: nodeFaceHex(for: lesson.state),
                            lipHex: nodeLipHex(for: lesson.state),
                            strokeHex: nodeStrokeHex(for: lesson.state),
                            cornerRadius: FigMetrics.twentyTwo,
                            lipDepth: FigMetrics.six
                        )
                    )
                    .accessibilityIdentifier("path-node-\(lesson.id)")

                    if lesson.state == .active {
                        let calloutLabel = (unitProgressPercent == 0 && lesson.stepIndexInUnit == 0) ? "COMMENCER" : "CONTINUER"
                        VStack(spacing: .zero) {
                            Text(verbatim: calloutLabel)
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                                .foregroundStyle(PrismColor.onAccent)
                                .padding(.horizontal, PrismSpacing.m)
                                .padding(.vertical, FigMetrics.five)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.figmaHex("#005a9e"))
                                            .offset(y: FigMetrics.three)
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.figmaHex("#0078d4"))
                                    }
                                )
                            Text(verbatim: "▼")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eight, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#005a9e"))
                                .offset(y: FigMetrics.one)
                        }
                        .offset(y: activeNodePulse ? -FigMetrics.fiftyTwo : -FigMetrics.fortyEight)
                        .allowsHitTesting(false)
                    }
                }
                .offset(x: xOffset)

                // Step Title placed NEXT TO the island in the free opposite space (Figma `37:375`)
                Text(verbatim: lesson.title)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                    .foregroundStyle(
                        lesson.state == .locked
                            ? PrismColor.figmaHex("#94a3b8")
                            : PrismColor.figmaHex("#0f172a")
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(isLeftIsland ? .leading : .trailing)
                    .frame(width: FigMetrics.oneHundredSeventyFive, alignment: isLeftIsland ? .leading : .trailing)
                    .offset(x: isLeftIsland ? (xOffset + 136) : (xOffset - 136))
                    .allowsHitTesting(false)

                // Mascot Blason 1A (`angle34LeftPath`) dynamically anchored next to the `.active` node!
                if lesson.state == .active {
                    CertiGoMascotView(pose: .angle34LeftPath, size: PrismSize.mascotPath)
                        .offset(
                            x: isLeftIsland ? (xOffset - FigMetrics.fiftySix) : (xOffset + FigMetrics.fiftySix),
                            y: -FigMetrics.ten
                        )
                        .zIndex(2)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func nodeFaceHex(for state: CertiGoLessonNodeState) -> String {
        switch state {
        case .completed, .active, .available: return "#ffffff"
        case .miniLab: return "#ffffff"
        case .locked: return "#f1f5f9"
        }
    }

    private func nodeLipHex(for state: CertiGoLessonNodeState) -> String {
        switch state {
        case .completed: return "#46a302"
        case .active, .available: return "#005a9e"
        case .miniLab: return "#cbd5e1"
        case .locked: return "#cbd5e1"
        }
    }

    private func nodeStrokeHex(for state: CertiGoLessonNodeState) -> String {
        switch state {
        case .completed: return "#58cc02"
        case .active, .available: return "#0078d4"
        case .miniLab: return "#cbd5e1"
        case .locked: return "#cbd5e1"
        }
    }

    // MARK: - OVERLAY 1: Popover `02` (Brand Logos + Multi-Certification Selector)

    private var popover02OverlayView: some View {
        let vendors: [(id: String, name: String)] = [
            ("microsoft", "Microsoft"),
            ("aws", "AWS"),
            ("google", "Google"),
            ("github", "GitHub"),
            ("kubernetes", "Kubernetes"),
            ("cisco", "Cisco")
        ]
        let cards = CertiGoFigmaLiveRuntimeState.popoverCards(forVendor: appState.selectedVendorInPopover)

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            HStack {
                Text(verbatim: "CHOISIR UNE MARQUE OFFICIELLE")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showCoursePopover02 = false
                    }
                } label: {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                .buttonStyle(.plain)
            }

            // Vendor Rail with Official Brand Logos (including true AWS cutout)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.s) {
                    ForEach(vendors, id: \.id) { vendor in
                        let isSelected = appState.selectedVendorInPopover == vendor.id
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.selectedVendorInPopover = vendor.id
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.xs) {
                                CertiGoBrandLogoView(vendorId: vendor.id, size: PrismSize.brandS)
                                if isSelected {
                                    Text(verbatim: vendor.name)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                }
                            }
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(isSelected ? PrismColor.figmaHex("#eff6ff") : PrismColor.figmaHex("#f8fafc"))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#e2e8f0"),
                                        lineWidth: PrismBorder.standard
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            // Certification Cards for Selected Vendor
            VStack(spacing: PrismSpacing.s) {
                ForEach(cards, id: \.code) { card in
                    let isActive = card.code.uppercased() == appState.activeRouteCode.uppercased()
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            appState.selectRoute(card.code)
                            coordinator.parallelTracksPreference.setActiveTrack(card.code)
                            try? preferenceStore.save(coordinator.parallelTracksPreference)
                        }
                    } label: {
                        HStack(spacing: PrismSpacing.m) {
                            CertiGoOfficialCrestView(routeCode: card.code, size: FigMetrics.fortyFour)

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                HStack(spacing: PrismSpacing.xs) {
                                    Text(verbatim: card.code)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                    if isActive {
                                        Text(verbatim: "ACTIF ✓")
                                            .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                                            .foregroundStyle(PrismColor.onAccent)
                                            .padding(.horizontal, PrismSpacing.xs)
                                            .padding(.vertical, PrismSpacing.xxs)
                                            .background(
                                                RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                                                    .fill(PrismColor.figmaHex("#58cc02"))
                                            )
                                    }
                                }
                                Text(verbatim: card.title)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: CertiGoLiveTrackCurriculum.curriculum(forRouteCode: card.code).unitBannerTitle)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }
                            Spacer(minLength: PrismSpacing.xs)
                        }
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .fill(isActive ? PrismColor.figmaHex("#eff6ff") : PrismColor.figmaHex("#f8fafc"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .strokeBorder(
                                    isActive ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#e2e8f0"),
                                    lineWidth: PrismBorder.standard
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Multi-Track Explorer Button (`➕ Explorer toutes les certifications`)
            Button {
                appState.showCoursePopover02 = false
                appState.showMultiTrackSelectorSheet = true
            } label: {
                HStack {
                    Spacer()
                    Text(verbatim: "➕ Explorer toutes les certifications & Veille IA")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    Spacer()
                }
                .padding(.vertical, PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .fill(PrismColor.figmaHex("#f0f9ff"))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(PrismSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                .fill(PrismColor.surface)
                .shadow(
                    color: PrismColor.figmaHex("#0f172a:24"),
                    radius: FigMetrics.twentyFour,
                    x: FigMetrics.zero,
                    y: FigMetrics.ten
                )
        )
        .padding(.horizontal, PrismSpacing.l)
        .padding(.top, FigMetrics.sixty)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - OVERLAY 2: Floating Step Sheet `03` & Unfolded Memo Sheet `14`

    private func stepFloatingSheet03And14Overlay(mode: CertiGoStepSheetMode) -> some View {
        let lesson = appState.lessonNode(withId: mode.lessonId) ?? appState.activeLessonNode
        let unit = appState.currentUnits.first(where: { $0.unitNumber == lesson.unitNumber }) ?? appState.currentUnits[0]
        let isMemoExpanded: Bool = {
            if case .memo14 = mode { return true }
            return false
        }()

        return VStack(spacing: PrismSpacing.m) {
            // Drag Handle
            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                .fill(PrismColor.figmaHex("#cbd5e1"))
                .frame(width: FigMetrics.forty, height: FigMetrics.five)
                .padding(.top, PrismSpacing.xs)

            // Top Header (Centered Shield 3D + Level Badge + Lesson Title & Subtitle)
            VStack(spacing: PrismSpacing.s) {
                HStack(spacing: PrismSpacing.xs) {
                    Text(verbatim: lesson.levelBadge)
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, PrismSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .fill(PrismColor.figmaHex("#e0f2fe"))
                        )

                    Text(verbatim: "UNITÉ \(unit.unitNumber) · \(appState.activeRouteCode)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }

                Text(verbatim: lesson.title)
                    .font(PrismTypography.figmaFont(size: FigMetrics.nineteen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .multilineTextAlignment(.center)

                Text(verbatim: lesson.subtitle)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Unfolded Fiche Mémo `14` Table (Apple Pay style: ACTIVITÉ, SUJETS CLÉS, RÈGLE D'OR)
            if isMemoExpanded {
                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                        Text(verbatim: "🎯 ACTIVITÉ DE L'ÉTAPE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Text(verbatim: unit.memoActivity)
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "🔑 SUJETS CLÉS À MAÎTRISER")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        HStack(spacing: PrismSpacing.xs) {
                            ForEach(unit.memoKeyTopics, id: \.self) { topic in
                                Text(verbatim: topic)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0369a1"))
                                    .padding(.horizontal, PrismSpacing.s)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                            .fill(PrismColor.figmaHex("#e0f2fe"))
                                    )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                        Text(verbatim: "💡 RÈGLE D'OR POUR L'EXAMEN")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#15803d"))
                        Text(verbatim: unit.memoGoldenRule)
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#166534"))
                    }
                    .padding(PrismSpacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .fill(PrismColor.figmaHex("#f0fdf4"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#bbf7d0"), lineWidth: PrismBorder.standard)
                    )
                }
                .padding(PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.figmaHex("#f8fafc"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // 3 Action Buttons Row: `[ 📖 | COMMENCER (+15 XP) | ✦ ]`
            HStack(spacing: PrismSpacing.m) {
                // 1. Toggle Memo 14 (`📖`)
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.toggleStepMemoSheet14()
                    }
                } label: {
                    Text(verbatim: "📖")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                        .frame(width: FigMetrics.fiftySix, height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: isMemoExpanded ? "#dbeafe" : "#f1f5f9",
                        lipHex: isMemoExpanded ? "#3b82f6" : "#cbd5e1",
                        strokeHex: isMemoExpanded ? "#3b82f6" : "#cbd5e1",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("step-sheet-toggle-memo14")

                // 2. Primary CTA (`COMMENCER`) — Cleanly dismisses Step Sheet 03 before presenting Lesson Session
                Button {
                    appState.activeStepSheet = nil
                    appState.startLessonSession(forLessonId: lesson.id, enableAdaptiveReplay: true)
                } label: {
                    Text(verbatim: "COMMENCER  +15 💎")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#58cc02",
                        lipHex: "#46a302",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("step-sheet-start-lesson")

                // 3. AI Coach Shortcut (`✦`)
                Button {
                    appState.activeStepSheet = nil
                    appState.openAITopic(
                        "rbac-vs-policy",
                        customUserQuestion: "Explique-moi l'étape « \(lesson.title) » (\(appState.activeRouteCode))"
                    )
                    appState.selectedTab = .hubIA
                } label: {
                    Text(verbatim: "✦")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        .frame(width: FigMetrics.fiftySix, height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#eff6ff",
                        lipHex: "#93c5fd",
                        strokeHex: "#93c5fd",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("step-sheet-ask-ai")
            }
        }
        .padding(PrismSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.sheet, style: .continuous)
                .fill(PrismColor.surface)
                .shadow(
                    color: PrismColor.figmaHex("#0f172a:26"),
                    radius: FigMetrics.twentyEight,
                    x: FigMetrics.zero,
                    y: -FigMetrics.six
                )
        )
        .padding(.horizontal, PrismSpacing.m)
        .padding(.bottom, PrismSpacing.l)
    }

    // MARK: - OVERLAY 4: 5-Step Interactive Guided App Tour (`isPresentingGuidedAppTour`)

    private var guidedAppTourOverlayView: some View {
        let step = min(max(appState.guidedTourStepIndex, 0), CertiGoNativeAppState.guidedTourStepCount - 1)
        let tourSpecs: [(badge: String, title: String, body: String, pose: CertiGoMascotPose)] = [
            (
                "1/5 · PARCOURS & MULTI-CERTIFICATIONS",
                "Ton Parcours & Multi-Certifications",
                "Bascule entre tes certifications en haut à gauche, consulte le mémo d'unité [📖] et avance d'îlot en îlot avec tes 5 vies ❤️.",
                .angle34LeftPath
            ),
            (
                "2/5 · CENTRE D'EXAMEN OFFICIEL",
                "Examens Blancs & Sprints par Domaine",
                "Passe des simulations chronométrées notées sur 1000 ou cible un domaine précis en Sprint Express de 5 minutes.",
                .poseAnalyst
            ),
            (
                "3/5 · COACH IA 24/7",
                "Coach IA Écrit & Vocal 24/7",
                "Pose tes questions d'architecture, compare deux services Cloud côte à côte et retrouve tes mémos IA épinglés.",
                .specialistAICoach
            ),
            (
                "4/5 · LIGUE & ÉMULATIONS",
                "Ligue Hebdomadaire & Duels",
                "Gagne des XP à chaque leçon pour monter sur le podium de la semaine et défie tes amis en Duel Express.",
                .celebratingTrophy
            ),
            (
                "5/5 · PASSEPORT & PROFIL",
                "Ton Profil & tes Blasons",
                "Suis jusqu'à 3 certifications en parallèle et personnalise ton rythme. Prêt à lancer ta 1re étape ?",
                .emotionStarryEyes
            )
        ]
        let spec = tourSpecs[step]
        let isLastStep = (step == CertiGoNativeAppState.guidedTourStepCount - 1)

        return VStack {
            Spacer()

            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                HStack {
                    Text(verbatim: "🧭 VISITE GUIDÉE · \(spec.badge)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, FigMetrics.four)
                        .background(
                            Capsule().fill(PrismColor.figmaHex("#eff6ff"))
                        )

                    Spacer()

                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            appState.dismissGuidedAppTour()
                        }
                    } label: {
                        Text(verbatim: "Passer ✕")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("guided-tour-skip-button")
                }

                HStack(alignment: .center, spacing: PrismSpacing.m) {
                    CertiGoMascotView(pose: spec.pose, size: FigMetrics.seventyTwo)

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: spec.title)
                            .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        Text(verbatim: spec.body)
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                            .foregroundStyle(PrismColor.figmaHex("#334155"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: PrismSpacing.s) {
                    if step > 0 {
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.goBackGuidedTourStep()
                            }
                        } label: {
                            Text(verbatim: "←")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#334155"))
                                .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyFour)
                        }
                        .buttonStyle(
                            CertiGoTactile3DButtonStyle(
                                faceHex: "#f8fafc",
                                lipHex: "#cbd5e1",
                                strokeHex: "#cbd5e1",
                                cornerRadius: PrismRadius.m,
                                lipDepth: FigMetrics.three
                            )
                        )
                        .accessibilityIdentifier("guided-tour-back-button")
                    }

                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.advanceGuidedTourStep()
                        }
                    } label: {
                        Text(verbatim: isLastStep ? "🚀 COMMENCER MA 1re ÉTAPE" : "SUIVANT (\(step + 1)/5) →")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: FigMetrics.fortyFour)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: isLastStep ? "#58cc02" : "#1d4ed8",
                            lipHex: isLastStep ? "#46a302" : "#1e40af",
                            cornerRadius: PrismRadius.m,
                            lipDepth: FigMetrics.four
                        )
                    )
                    .accessibilityIdentifier("guided-tour-next-button")
                }
            }
            .padding(PrismSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .fill(PrismColor.surface)
                    .shadow(
                        color: PrismColor.figmaHex("#0f172a:26"),
                        radius: FigMetrics.twentyFour,
                        x: FigMetrics.zero,
                        y: FigMetrics.eight
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#93c5fd"), lineWidth: PrismBorder.standard)
            )
            .padding(.horizontal, PrismSpacing.l)
            .padding(.bottom, FigMetrics.ninetySix)
        }
    }

    // MARK: - TAB 2: Examens (`21`) & Apple Pay Sheet (`22`)

    private var examensTab21View: some View {
        let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: appState.activeRouteCode)
        let domains = CertiGoNativeRichCatalog.examDomains(forRouteCode: appState.activeRouteCode)
        let providerMeta = CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: appState.activeRouteCode)
        let hasExamOrLessonData = appState.completedExamsCount > 0 || appState.routeCompletedLessonsCount(forRouteCode: appState.activeRouteCode) > 0

        return VStack(spacing: .zero) {
            // Header (`Examens · AZ-104` + `[AZ-104 ▾]`)
            HStack {
                Text(verbatim: "Examens · \(appState.activeRouteCode)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .lineLimit(1)

                Spacer()

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showCoursePopover02.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xs) {
                        CertiGoBrandLogoView(vendorId: curriculum.vendorId, size: PrismSize.brandS)
                        Text(verbatim: "\(appState.activeRouteCode) ▾")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, PrismSpacing.m)
                    .padding(.vertical, PrismSpacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(PrismColor.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.vertical, PrismSpacing.m)
            .background(PrismColor.figmaHex("#f8fafc"))

            // Native ScrollView + LazyVStack
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: PrismSpacing.l) {
                    // Hero 3D Official Provider Mock Exam Card
                    VStack(alignment: .leading, spacing: PrismSpacing.m) {
                        HStack(spacing: PrismSpacing.m) {
                            CertiGoOfficialCrestView(routeCode: appState.activeRouteCode, size: PrismSize.crestCard)

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: providerMeta.providerBadge)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#bae6fd"))
                                Text(verbatim: "Examen Blanc Complet (50 Q)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                                    .foregroundStyle(PrismColor.onAccent)
                                if appState.completedExamsCount > 0 {
                                    Text(verbatim: "\(providerMeta.summaryLine) · Dernier : \(appState.lastComputedExamScoreOutOf1000)/1000 ✓")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium"))
                                        .foregroundStyle(PrismColor.figmaHex("#e0f2fe"))
                                } else {
                                    Text(verbatim: providerMeta.summaryLine)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium"))
                                        .foregroundStyle(PrismColor.figmaHex("#e0f2fe"))
                                }
                            }
                        }

                        if appState.completedExamsCount > 0 {
                            HStack(spacing: PrismSpacing.s) {
                                Button {
                                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                                        appState.showExamLaunchSheet22 = true
                                    }
                                } label: {
                                    Text(verbatim: "DÉMARRER L'EXAMEN COMPLET")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: FigMetrics.fortyEight)
                                }
                                .buttonStyle(
                                    CertiGoTactile3DButtonStyle(
                                        faceHex: "#ffffff",
                                        lipHex: "#bae6fd",
                                        cornerRadius: PrismRadius.m,
                                        lipDepth: FigMetrics.four
                                    )
                                )
                                .accessibilityIdentifier("examens-open-apple-pay-sheet22")

                                Button {
                                    appState.isPresentingExamReport24 = true
                                } label: {
                                    Text(verbatim: "📊 Rapport (\(appState.lastComputedExamScoreOutOf1000)/1000)")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                        .foregroundStyle(PrismColor.onAccent)
                                        .padding(.horizontal, PrismSpacing.m)
                                        .frame(height: FigMetrics.fortyEight)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                                .fill(PrismColor.figmaHex("#ffffff:22"))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                Button {
                                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                                        appState.showExamLaunchSheet22 = true
                                    }
                                } label: {
                                    Text(verbatim: "DÉMARRER L'EXAMEN COMPLET")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: FigMetrics.fortyEight)
                                }
                                .buttonStyle(
                                    CertiGoTactile3DButtonStyle(
                                        faceHex: "#ffffff",
                                        lipHex: "#bae6fd",
                                        cornerRadius: PrismRadius.m,
                                        lipDepth: FigMetrics.four
                                    )
                                )
                                .accessibilityIdentifier("examens-open-apple-pay-sheet22")

                                Text(verbatim: "Aucun examen blanc passé · Passe ton 1er examen pour obtenir ton score /1000")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#e0f2fe"))
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.figmaHex("#ffffff:16"))
                                    )
                            }
                        }
                    }
                    .padding(PrismSpacing.l)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.figmaHex("#005a9e"))
                                .offset(y: FigMetrics.six)
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            PrismColor.figmaHex("#0078d4"),
                                            PrismColor.figmaHex("#1d4ed8")
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                    )

                    Text(verbatim: "S'ENTRAÎNER PAR DOMAINE OFFICIEL \(appState.activeRouteCode)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        .padding(.top, PrismSpacing.xs)

                    if !hasExamOrLessonData {
                        Text(verbatim: "ℹ️ Aucune statistique de domaine pour l'instant — termine ta première leçon ou un examen blanc pour calibrer ton niveau.")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#475569"))
                            .padding(PrismSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                            )
                    }

                    // Official Weighted Exam Domains (Dynamic Mastery % starting at 0% for a new user, including 6 domains for GH-300!)
                    ForEach(0..<domains.count, id: \.self) { idx in
                        let domain = domains[idx]
                        let dynamicPct = appState.domainMasteryPercent(forRouteCode: appState.activeRouteCode, domainIndex: idx)
                        Button {
                            appState.selectedDomainForPractice = idx
                        } label: {
                            HStack(spacing: PrismSpacing.m) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    Text(verbatim: domain.title)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Semi Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    Text(verbatim: domain.weightText)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                }
                                Spacer(minLength: PrismSpacing.xs)
                                Text(verbatim: "\(dynamicPct)%")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                    .foregroundStyle(
                                        dynamicPct == 0
                                            ? PrismColor.figmaHex("#94a3b8")
                                            : PrismColor.figmaHex(domain.colorHex)
                                    )
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.figmaHex("#f1f5f9"))
                                    )
                            }
                            .padding(PrismSpacing.l)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(
                            CertiGoTactile3DButtonStyle(
                                faceHex: "#ffffff",
                                lipHex: "#e2e8f0",
                                strokeHex: "#e2e8f0",
                                cornerRadius: PrismRadius.l,
                                lipDepth: FigMetrics.four
                            )
                        )
                        .accessibilityIdentifier("examens-domain-\(idx + 1)")
                    }
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.top, PrismSpacing.xs)
                .padding(.bottom, FigMetrics.bottomBarTotalClearance)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }
    }

    // MARK: - TAB 5: Moi (`08`), Statistiques Pro (`08B-1/2`), Détail Certification (`26`), PRO (`27`) & Paramètres (`28`)

    private var moiTab08NavigationStack: some View {
            NavigationStack(path: $profileNavPath) {
                VStack(spacing: .zero) {
                    // Pinned Top Profile Header Bar (`Mon Profil` + `⚙️`) outside the ScrollView so pulling down never drags the header!
                    HStack {
                        Text(verbatim: "Mon Profil")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        Spacer()
                        Button {
                            profileNavPath.append(.settings28)
                        } label: {
                            Text(verbatim: "⚙️")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                                .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .fill(PrismColor.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("moi-open-settings28")
                    }
                    .padding(.horizontal, PrismSpacing.l)
                    .padding(.vertical, PrismSpacing.m)
                    .background(PrismColor.figmaHex("#f8fafc"))

                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: PrismSpacing.l) {
                            // Avatar + Handle + Account Status Badge
                            VStack(spacing: PrismSpacing.s) {
                                Button {
                                    appState.showEditProfileSheet = true
                                } label: {
                                    ZStack(alignment: .bottomTrailing) {
                                        Text(verbatim: appState.userInitials)
                                            .font(PrismTypography.figmaFont(size: FigMetrics.twentyEight, style: "Black"))
                                            .foregroundStyle(PrismColor.onAccent)
                                            .frame(width: PrismSize.avatarLarge, height: PrismSize.avatarLarge)
                                            .background(
                                                Circle().fill(
                                                    LinearGradient(
                                                        colors: [
                                                            PrismColor.figmaHex(appState.userAvatarHex),
                                                            PrismColor.figmaHex("#2563eb")
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                            )

                                        Text(verbatim: "✎")
                                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                            .frame(width: PrismSize.avatarEditBadge, height: PrismSize.avatarEditBadge)
                                            .background(Circle().fill(PrismColor.surface))
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("moi-edit-profile-avatar-button")

                                Text(verbatim: appState.userDisplayName)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                                let providerMeta = CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: appState.activeRouteCode)
                                Text(verbatim: "📅 Examen cible (\(providerMeta.providerName)) : \(appState.targetExamDateText)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Medium"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))

                                Button {
                                    appState.showProPaywallSheet27 = true
                                } label: {
                                    let tierBadge: String = {
                                        if appState.isProMember {
                                            return "✦ Membre CertiGo PRO · Vies ∞"
                                        }
                                        if appState.isAccountConnected {
                                            return "🔐 \(appState.connectedAuthProvider ?? "Microsoft Entra ID") · Compte Gratuit · 5 ❤️"
                                        }
                                        return "Compte Gratuit · 5 ❤️"
                                    }()
                                    Text(verbatim: "\(appState.userHandle) · \(tierBadge)")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                        .padding(.horizontal, PrismSpacing.m)
                                        .padding(.vertical, PrismSpacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                                .fill(PrismColor.figmaHex("#eff6ff"))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("moi-membership-tier-badge")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(PrismSpacing.l)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                            )

                            // 3 Dynamic Gamification Summary Cards (`🔥 X jours`, `⚡ X étapes`, `🏆 X XP`)
                            HStack(spacing: PrismSpacing.s) {
                                Button {
                                    appState.activeGamificationSheet = .streak
                                } label: {
                                    moiStatCard(icon: "🔥", value: "\(appState.streakDays) jours", label: "Série active")
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("moi-stat-card-streak")

                                Button {
                                    appState.activeGamificationSheet = .gems
                                } label: {
                                    moiStatCard(icon: "⚡", value: "\(appState.completedStepsTotal) étapes", label: "Validées")
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("moi-stat-card-gems")

                                Button {
                                    appState.activeGamificationSheet = .hearts
                                } label: {
                                    moiStatCard(icon: "🏆", value: "\(appState.userXPPoints) XP", label: "Ligue Semaine")
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("moi-stat-card-hearts")
                            }

                            // 3D Sky-Blue CTA Button (`📊 Voir mes Statistiques & Analyses Pro ➔`)
                            Button {
                                profileNavPath.append(.proStats08B)
                            } label: {
                                HStack {
                                    Text(verbatim: "📊 Voir mes Statistiques & Analyses Pro")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                        .foregroundStyle(PrismColor.onAccent)
                                    Spacer()
                                    Text(verbatim: "➔")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                        .foregroundStyle(PrismColor.onAccent)
                                }
                                .padding(.horizontal, PrismSpacing.l)
                                .frame(height: PrismSize.primaryButtonHeight)
                            }
                            .buttonStyle(
                                CertiGoTactile3DButtonStyle(
                                    faceHex: "#0284c7",
                                    lipHex: "#0369a1",
                                    cornerRadius: PrismRadius.l
                                )
                            )
                            .accessibilityIdentifier("moi-open-stats-pro-08b")

                            // Certifications Passeport List with REAL dynamic progression (`0%` at start, `Non passé` when 0 exams)
                            let uniqueTrackCodes = appState.deduplicatedParallelTrackCodes(
                                preferred: coordinator.parallelTracksPreference.selectedTracks.map(\.rawValue)
                            )
                            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                                Text(verbatim: "MES CERTIFICATIONS EN PARALLÈLE")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))

                                ForEach(uniqueTrackCodes, id: \.self) { code in
                                    let detail = CertiGoNativeRichCatalog.profileCertificationDetail(forCode: code)
                                    let pct = appState.routeProgressPercent(forRouteCode: code)
                                    let done = appState.routeCompletedLessonsCount(forRouteCode: code)
                                    let examStatus = appState.completedExamsCount > 0
                                        ? "\(appState.lastComputedExamScoreOutOf1000)/1000 ✓"
                                        : "Non passé"
                                    Button {
                                        profileNavPath.append(.certificationDetail26(code: code))
                                    } label: {
                                        HStack(spacing: PrismSpacing.m) {
                                            CertiGoOfficialCrestView(routeCode: code, size: FigMetrics.fortyEight)
                                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                                Text(verbatim: detail.title)
                                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                                Text(verbatim: "Progression : \(pct)% (\(done)/15) · Examen : \(examStatus)")
                                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                            }
                                            Spacer()
                                            Text(verbatim: "›")
                                                .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                                                .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                                        }
                                        .padding(PrismSpacing.m)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                                .fill(PrismColor.surface)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, PrismSpacing.l)
                        .padding(.top, PrismSpacing.xs)
                        .padding(.bottom, FigMetrics.bottomBarTotalClearance)
                    }
                }
                .background(PrismColor.figmaHex("#f8fafc"))
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: CertiGoProfileRoute.self) { route in
                    switch route {
                    case .proStats08B:
                        proStats08BUnifiedView
                            .navigationBarBackButtonHidden(true)
                    case .certificationDetail26(let code):
                        certificationDetail26View(code: code)
                            .navigationBarBackButtonHidden(true)
                    case .settings28:
                        settings28View
                            .navigationBarBackButtonHidden(true)
                    case .systemWidgetsSYS01:
                        systemWidgetsSYS01View
                            .navigationBarBackButtonHidden(true)
                    case .offlineResilienceRES01:
                        offlineResilienceRES01View
                            .navigationBarBackButtonHidden(true)
                    }
                }
            }
        }

        private func moiStatCard(icon: String, value: String, label: String) -> some View {
            VStack(spacing: PrismSpacing.xxs) {
                Text(verbatim: icon)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                Text(verbatim: value)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Text(verbatim: label)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PrismSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
            )
        }

        // MARK: - Unified Statistiques Pro (`08B-1` + `08B-2`) in a Single Vertical ScrollView

        private var proStats08BUnifiedView: some View {
            let hasActivity = appState.completedStepsTotal > 0 || appState.completedExamsCount > 0
            let baseMastery = hasActivity ? min(95, max(20, appState.completedStepsTotal * 15 + (appState.completedExamsCount > 0 ? 45 : 0))) : 0
            let radarAxes: [(label: String, pct: Int, detail: String)] = [
                ("Identité (\(baseMastery)%)", baseMastery, hasActivity ? "Identité, RBAC & gouvernance : \(baseMastery) % de maîtrise." : "Aucune séance validée sur l'axe Identité (0 %)."),
                ("Stockage (\(max(0, baseMastery - 5))%)", max(0, baseMastery - 5), hasActivity ? "Stockage, réplication & chiffrement KMS : \(max(0, baseMastery - 5)) %." : "Aucune séance validée sur l'axe Stockage (0 %)."),
                ("Calcul (\(max(0, baseMastery - 8))%)", max(0, baseMastery - 8), hasActivity ? "Calcul, conteneurs & autoscaling : \(max(0, baseMastery - 8)) %." : "Aucune séance validée sur l'axe Calcul (0 %)."),
                ("Réseau (\(max(0, baseMastery - 12))%)", max(0, baseMastery - 12), hasActivity ? "Réseaux privés, DNS & WAF : \(max(0, baseMastery - 12)) %." : "Aucune séance validée sur l'axe Réseau (0 %)."),
                ("Sécurité (\(max(0, baseMastery - 3))%)", max(0, baseMastery - 3), hasActivity ? "Sécurité Zero-Trust & verrous : \(max(0, baseMastery - 3)) %." : "Aucune séance validée sur l'axe Sécurité (0 %).")
            ]
            let heatmapColumns = Array(repeating: GridItem(.flexible(), spacing: PrismSpacing.xxs), count: 8)

            return VStack(spacing: .zero) {
                // Top Navigation Bar
                HStack {
                    Button {
                        if !profileNavPath.isEmpty { profileNavPath.removeLast() }
                    } label: {
                        Text(verbatim: "←  Moi")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(verbatim: "Statistiques Pro")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                    Spacer()

                    Button {
                        appState.statsTimeRangeLabel = appState.statsTimeRangeLabel == "30 jours ▾" ? "90 jours ▾" : "30 jours ▾"
                    } label: {
                        Text(verbatim: appState.statsTimeRangeLabel)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#334155"))
                            .padding(.horizontal, PrismSpacing.s)
                            .padding(.vertical, PrismSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.m)
                .background(PrismColor.figmaHex("#f8fafc"))

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PrismSpacing.l) {
                        if !hasActivity {
                            CertiGoEmptyStateCardView(
                                mascotPose: .poseAnalyst,
                                title: "📊 Pas encore de statistiques disponibles",
                                subtitle: "Tu n'as pas encore terminé de séance ni d'examen blanc. Tes graphiques Radar, ta Heatmap d'assiduité et ta prédiction Pearson VUE se rempliront automatiquement dès ta première leçon validée.",
                                actionTitle: "🚀 Démarrer ma 1re leçon (+15 💎)"
                            ) {
                                if !profileNavPath.isEmpty { profileNavPath.removeAll() }
                                appState.selectedTab = .parcours
                                appState.startLessonSession(enableAdaptiveReplay: true)
                            }
                        }

                        // 1. Exam Fitness Score Hero Card (Dynamic: 0% at start)
                        HStack {
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                Text(verbatim: "INDICE DE FORME EXAMEN \(appState.activeRouteCode)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#bae6fd"))
                                Text(verbatim: hasActivity ? "\(baseMastery) % · Progression active" : "0 % · En attente de ta 1re séance")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                Text(verbatim: hasActivity ? "⚡ \(appState.completedStepsTotal) étape(s) · \(appState.userXPPoints) XP" : "ℹ️ Termine une étape pour calibrer ton indice Pearson VUE")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#86efac"))
                            }
                            Spacer()
                            CertiGoMascotView(pose: .poseAnalyst, size: FigMetrics.sixtyFour)
                        }
                        .padding(PrismSpacing.l)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.figmaHex("#0f172a"))
                        )

                        // 2. Interactive 5-Axis Polygon Radar Card
                        VStack(alignment: .leading, spacing: PrismSpacing.m) {
                            Text(verbatim: "RADAR DE COMPÉTENCES TECHNIQUES (TOUCHE UN AXE)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))

                            HStack(spacing: PrismSpacing.xs) {
                                ForEach(0..<radarAxes.count, id: \.self) { idx in
                                    let isSelected = appState.selectedRadarAxisIndex == idx
                                    Button {
                                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                            appState.selectedRadarAxisIndex = idx
                                        }
                                    } label: {
                                        Text(verbatim: radarAxes[idx].label)
                                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Extra Bold"))
                                            .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#334155"))
                                            .padding(.horizontal, PrismSpacing.s)
                                            .padding(.vertical, PrismSpacing.xs)
                                            .background(
                                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                                    .fill(isSelected ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#f1f5f9"))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Text(verbatim: radarAxes[appState.selectedRadarAxisIndex].detail)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                .padding(PrismSpacing.m)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .fill(PrismColor.figmaHex("#eff6ff"))
                                )
                        }
                        .padding(PrismSpacing.l)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                        )

                        // 3. 3 Telemetry Cards (Dynamic: 0% when no activity)
                        HStack(spacing: PrismSpacing.s) {
                            moiStatCard(
                                icon: "🎯",
                                value: hasActivity ? "\(appState.lessonSession.accuracyPercent) %" : "0 %",
                                label: "Précision QCM"
                            )
                            moiStatCard(
                                icon: "⚡",
                                value: hasActivity ? "14 sec" : "-- sec",
                                label: "Rythme / Q"
                            )
                            moiStatCard(
                                icon: "🧠",
                                value: hasActivity ? "\(min(98, 75 + appState.completedStepsTotal * 4)) %" : "0 %",
                                label: "Rétention FSRS"
                            )
                        }

                        // 4. 8-Week Activity Heatmap Grid (`LazyVGrid` — grey when 0 steps, lights up as steps/streak increase!)
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            Text(verbatim: "CONSTANCE D'ÉTUDE · HEATMAP 8 SEMAINES")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))

                            LazyVGrid(columns: heatmapColumns, spacing: PrismSpacing.xxs) {
                                ForEach(0..<32, id: \.self) { cellIdx in
                                    let activeCells = min(32, max(appState.streakDays, appState.completedStepsTotal))
                                    let isLit = cellIdx >= (32 - activeCells)
                                    let hex = isLit ? "#22c55e" : "#e2e8f0"
                                    RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                                        .fill(PrismColor.figmaHex(hex))
                                        .frame(height: PrismSize.heatmapCellHeight)
                                }
                            }
                        }
                        .padding(PrismSpacing.l)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                        )

                        // 5. 3 Concentric Performance Rings (`08B-2`)
                        VStack(alignment: .leading, spacing: PrismSpacing.m) {
                            Text(verbatim: "ANNEAUX DE PERFORMANCE")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))

                            HStack(spacing: PrismSpacing.l) {
                                ZStack {
                                    Circle()
                                        .stroke(PrismColor.figmaHex(hasActivity ? "#22c55e" : "#cbd5e1"), lineWidth: FigMetrics.eight)
                                        .frame(width: PrismSize.ringOuter, height: PrismSize.ringOuter)
                                    Circle()
                                        .stroke(PrismColor.figmaHex(hasActivity ? "#0078d4" : "#e2e8f0"), lineWidth: FigMetrics.eight)
                                        .frame(width: PrismSize.ringMiddle, height: PrismSize.ringMiddle)
                                    Circle()
                                        .stroke(PrismColor.figmaHex(hasActivity ? "#8b5cf6" : "#f1f5f9"), lineWidth: FigMetrics.eight)
                                        .frame(width: PrismSize.ringInner, height: PrismSize.ringInner)
                                }

                                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                    Text(verbatim: "●  Régularité : \(appState.completedStepsTotal * 5) / \(appState.onboardingDailyRhythmMinutes) min/j")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                                    Text(verbatim: "●  Précision QCM : \(hasActivity ? "\(appState.lessonSession.accuracyPercent) %" : "0 %") (Cible 80%)")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                    Text(verbatim: "●  Séances validées : \(appState.completedStepsTotal) étape(s)")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#7c3aed"))
                                }
                            }
                        }
                        .padding(PrismSpacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                        )

                        // 6. Progression Curve `/1000`
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            HStack {
                                Text(verbatim: "PROGRESSION EXAMEN (/1000)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                Spacer()
                                Text(
                                    verbatim: appState.completedExamsCount > 0
                                        ? "\(appState.lastComputedExamScoreOutOf1000) / 1000 ✓"
                                        : "Aucun examen passé"
                                )
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                .foregroundStyle(
                                    appState.completedExamsCount > 0
                                        ? PrismColor.figmaHex("#15803d")
                                        : PrismColor.figmaHex("#64748b")
                                )
                            }
                            Text(verbatim: "Seuil de réussite officiel Pearson VUE : 700 / 1000")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#475569"))
                            Text(
                                verbatim: appState.completedExamsCount > 0
                                    ? "Dernier score calculé : \(appState.lastComputedExamScoreOutOf1000) / 1000 (\(appState.completedExamsCount) examen(s) terminé(s))"
                                    : "Pour l'instant il n'y a pas encore de résultat d'examen blanc."
                            )
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        }
                        .padding(PrismSpacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                        )
                    }
                    .padding(.horizontal, PrismSpacing.l)
                    .padding(.bottom, FigMetrics.bottomBarTotalClearance)
                }
                .background(PrismColor.figmaHex("#f8fafc"))
            }
            .toolbar(.hidden, for: .navigationBar)
        }

        // MARK: - Certification Detail Screen (`26`)

        private func certificationDetail26View(code: String) -> some View {
            let detail = CertiGoNativeRichCatalog.profileCertificationDetail(forCode: code)
            let providerMeta = CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: code)
            let pct = appState.routeProgressPercent(forRouteCode: code)
            let done = appState.routeCompletedLessonsCount(forRouteCode: code)
            let examStatus = appState.completedExamsCount > 0
                ? "\(appState.lastComputedExamScoreOutOf1000) / 1000 ✓"
                : "Non passé"

            return VStack(spacing: .zero) {
                HStack {
                    Button {
                        if !profileNavPath.isEmpty { profileNavPath.removeLast() }
                    } label: {
                        Text(verbatim: "←  Moi")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(verbatim: "Détail Certification")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Spacer()
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.m)
                .background(PrismColor.figmaHex("#f8fafc"))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: PrismSpacing.l) {
                        VStack(spacing: PrismSpacing.s) {
                            CertiGoOfficialCrestView(routeCode: code, size: PrismSize.crestHero)
                            Text(verbatim: detail.badge)
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            Text(verbatim: detail.title)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                .multilineTextAlignment(.center)
                            Text(verbatim: providerMeta.summaryLine)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium"))
                                .foregroundStyle(PrismColor.figmaHex("#475569"))
                            Text(verbatim: "Progression : \(pct)% (\(done)/15) · Examen Blanc : \(examStatus)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex(done > 0 ? "#15803d" : "#64748b"))
                        }
                        .padding(PrismSpacing.l)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )

                        VStack(alignment: .leading, spacing: PrismSpacing.m) {
                            Text(verbatim: "MAÎTRISE PAR DOMAINE OFFICIEL")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))

                            if done == 0 && appState.completedExamsCount == 0 {
                                Text(verbatim: "Pour l'instant il n'y a pas encore d'informations de maîtrise sur \(code). Termine la 1re étape pour débloquer tes jauges par domaine.")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }

                            ForEach(0..<detail.domains.count, id: \.self) { domIdx in
                                let dom = detail.domains[domIdx]
                                let domPct = appState.domainMasteryPercent(forRouteCode: code, domainIndex: domIdx)
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    HStack {
                                        Text(verbatim: dom.title)
                                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                        Spacer()
                                        Text(verbatim: "\(domPct)%")
                                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                            .foregroundStyle(PrismColor.figmaHex(domPct > 0 ? dom.colorHex : "#94a3b8"))
                                    }
                                    GeometryReader { barGeo in
                                        let rawRatio = CGFloat(domPct) / 100.0
                                        let safeRatio = rawRatio.isFinite ? min(max(rawRatio, 0), 1) : 0
                                        let safeWidth = barGeo.size.width.isFinite ? max(0, barGeo.size.width * safeRatio) : 0
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                                .fill(PrismColor.figmaHex("#e2e8f0"))
                                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                                .fill(PrismColor.figmaHex(dom.colorHex))
                                                .frame(width: safeWidth)
                                        }
                                    }
                                    .frame(height: FigMetrics.ten)
                                }
                            }
                        }
                        .padding(PrismSpacing.l)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )

                        Button {
                            appState.selectRoute(code)
                            if !profileNavPath.isEmpty { profileNavPath.removeAll() }
                            appState.selectedTab = .parcours
                        } label: {
                            Text(verbatim: "🎯 S'ENTRAÎNER SUR \(code)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: PrismSize.primaryButtonHeight)
                        }
                        .buttonStyle(
                            CertiGoTactile3DButtonStyle(
                                faceHex: "#0078d4",
                                lipHex: "#005a9e",
                                cornerRadius: PrismRadius.l
                            )
                        )
                    }
                    .padding(.horizontal, PrismSpacing.l)
                    .padding(.bottom, FigMetrics.bottomBarTotalClearance)
                }
                .background(PrismColor.figmaHex("#f8fafc"))
            }
            .toolbar(.hidden, for: .navigationBar)
        }

        // MARK: - Settings Screen (`28`) — ChatGPT iOS 2026 Style with Interactive Rows & Switches

        private var settings28View: some View {
            let langLabel = CertiGoFigmaLiveRuntimeState.settingsLanguageOptions[
                appState.settingsLanguageIndex % CertiGoFigmaLiveRuntimeState.settingsLanguageOptions.count
            ]
            let examModeLabel = CertiGoFigmaLiveRuntimeState.settingsExamModeOptions[
                appState.settingsExamModeIndex % CertiGoFigmaLiveRuntimeState.settingsExamModeOptions.count
            ]
            let voiceLabel = CertiGoFigmaLiveRuntimeState.settingsCoachVoiceOptions[
                appState.settingsCoachVoiceIndex % CertiGoFigmaLiveRuntimeState.settingsCoachVoiceOptions.count
            ]
            let styleLabel = CertiGoFigmaLiveRuntimeState.settingsExplanationStyleOptions[
                appState.settingsExplanationStyleIndex % CertiGoFigmaLiveRuntimeState.settingsExplanationStyleOptions.count
            ]

            return VStack(spacing: .zero) {
                HStack {
                    Button {
                        if !profileNavPath.isEmpty { profileNavPath.removeLast() }
                    } label: {
                        Text(verbatim: "←  Moi")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(verbatim: "Paramètres")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Spacer()
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.m)
                .background(PrismColor.figmaHex("#f8fafc"))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: PrismSpacing.l) {
                        // Profile Account Row -> Opens Edit Profile Sheet (or PRO 27)
                        Button {
                            appState.showEditProfileSheet = true
                        } label: {
                            HStack(spacing: PrismSpacing.m) {
                                Text(verbatim: appState.userInitials)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                    .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                                    .background(Circle().fill(PrismColor.figmaHex(appState.userAvatarHex)))

                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    Text(verbatim: appState.userDisplayName)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    Text(verbatim: "\(appState.userHandle) · Cible : \(appState.targetExamDateText)")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                }
                                Spacer()
                                Text(verbatim: "✎")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            }
                            .padding(PrismSpacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                        }
                        .buttonStyle(.plain)

                        // Section 1: Parcours & Examens
                        Text(verbatim: "PARCOURS & EXAMENS")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        VStack(spacing: PrismSpacing.xs) {
                            settingsActionRow(
                                title: "Parcours actifs en parallèle",
                                value: "\(appState.activeRouteCode) + 2  ›"
                            ) {
                                appState.showMultiTrackSelectorSheet = true
                            }
                            settingsActionRow(
                                title: "Langue des cours & examens",
                                value: "\(langLabel)  ›"
                            ) {
                                appState.activeSettingsPicker = .language
                            }
                            settingsActionRow(
                                title: "Mode Examen Blanc (Pearson)",
                                value: "\(examModeLabel)  ›"
                            ) {
                                appState.activeSettingsPicker = .examMode
                            }
                            settingsActionRow(
                                title: "Cours téléchargés (Hors-Ligne)",
                                value: "142 Mo  ›"
                            ) {
                                profileNavPath.append(.offlineResilienceRES01)
                            }
                        }

                        // Section 2: Coach IA Vocal & Écrit
                        Text(verbatim: "COACH IA VOCAL & ÉCRIT")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        VStack(spacing: PrismSpacing.xs) {
                            settingsActionRow(
                                title: "Voix du Coach IA Live",
                                value: "\(voiceLabel)  ›"
                            ) {
                                appState.activeSettingsPicker = .coachVoice
                            }
                            settingsActionRow(
                                title: "Style des explications",
                                value: "\(styleLabel)  ›"
                            ) {
                                appState.activeSettingsPicker = .explanationStyle
                            }
                            settingsActionRow(
                                title: "Widgets iOS 18 & Dynamic Island",
                                value: "Actifs  ›"
                            ) {
                                profileNavPath.append(.systemWidgetsSYS01)
                            }
                            settingsActionRow(
                                title: "🛠️ Registre des erreurs & Diagnostics (CG-ERR)",
                                value: "\(CertiGoErrorCode.allCases.count) codes  ›"
                            ) {
                                appState.showErrorRegistrySheet = true
                            }
                        }

                        // Section 3: Préférences & Rappels (Animated Toggles)
                        Text(verbatim: "RAPPELS & EXPÉRIENCE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        VStack(spacing: PrismSpacing.xs) {
                            settingsToggleRow(
                                title: "Rappel quotidien Série 🔥 (19:30)",
                                isOn: $appState.settingsPushRemindersOn
                            )
                            settingsToggleRow(
                                title: "Radar hebdo des nouveautés IA",
                                isOn: $appState.settingsDailyRadarOn
                            )
                            settingsToggleRow(
                                title: "Retours haptiques tactiles 3D",
                                isOn: $appState.settingsHapticsOn
                            )
                        }

                        // Launch Interactive 5-Step Guided App Tour (`🧭 Relancer la visite guidée`)
                        Button {
                            if !profileNavPath.isEmpty { profileNavPath.removeAll() }
                            appState.startGuidedAppTour()
                        } label: {
                            Text(verbatim: "🧭 Relancer la visite guidée de l'application (5 étapes)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                                .frame(maxWidth: .infinity)
                                .frame(height: FigMetrics.fortyEight)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                        .fill(PrismColor.figmaHex("#dbeafe"))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings28-restart-guided-tour")

                        // Launch Onboarding Flow (`OB-01..08`)
                        Button {
                            appState.startOnboardingFlow()
                        } label: {
                            Text(verbatim: "🔄 Recommencer l'Onboarding (Page 07 Figma)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                .frame(maxWidth: .infinity)
                                .frame(height: FigMetrics.fortyEight)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                        .fill(PrismColor.figmaHex("#eff6ff"))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings28-restart-onboarding")

                        // Fresh New-User Reset (`0 donnée + Onboarding`)
                        Button {
                            if !profileNavPath.isEmpty { profileNavPath.removeAll() }
                            appState.resetToFreshNewUser()
                        } label: {
                            Text(verbatim: "🧹 Réinitialiser en Nouvel Utilisateur (0 donnée + Onboarding)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#e11d48"))
                                .frame(maxWidth: .infinity)
                                .frame(height: FigMetrics.fortyEight)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                        .fill(PrismColor.figmaHex("#fff1f2"))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings28-reset-fresh-user")
                    }
                    .padding(.horizontal, PrismSpacing.l)
                    .padding(.bottom, PrismSpacing.xxl)
                }
                .background(PrismColor.figmaHex("#f8fafc"))
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }

        private var systemWidgetsSYS01View: some View {
            let widgets: [(badge: String, title: String, subtitle: String, metric: String, hex: String)] = [
                ("W-1 · SÉRIE ACTIVE", "Widget Série & Objectif Quotidien", "🔥 \(appState.streakDays)j · 10/10 min ✓ · \(appState.activeRouteCode) + 2", "Actif ✓", "#ea580c"),
                ("W-RADAR · VEILLE IA", "Radar Hebdo IA & Agents MCP", "Nouveau cours IA : Claude 4 & Agents MCP", "Mis à jour", "#0078d4"),
                ("W-2 · DÉFI FLASH", "Situation Critique d'Architecture", "Protection d'un coffre Key Vault critique · +25 XP", "+25 XP", "#15803d"),
                ("W-3 · INTERACTIF iOS 18", "Question Rapide depuis l'Écran d'Accueil", "Réponds A / B / C sans ouvrir l'application (AppIntent)", "Interactif", "#7c3aed")
            ]

            return VStack(spacing: .zero) {
                HStack {
                    Button {
                        if !profileNavPath.isEmpty { profileNavPath.removeLast() }
                    } label: {
                        Text(verbatim: "←  Paramètres")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(verbatim: "Widgets iOS 18")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Spacer()
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.m)
                .background(PrismColor.figmaHex("#f8fafc"))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: PrismSpacing.l) {
                        HStack(spacing: PrismSpacing.m) {
                            CertiGoMascotView(pose: .emotionOnFire, size: FigMetrics.sixtyFour)
                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: "SYS-01 · ÉCRAN D'ACCUEIL & DYNAMIC ISLAND")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                Text(verbatim: "Garde ta série 🔥 et ton radar IA sous les yeux")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            }
                        }
                        .padding(PrismSpacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )

                        ForEach(0..<widgets.count, id: \.self) { idx in
                            let item = widgets[idx]
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                HStack {
                                    Text(verbatim: item.badge)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                        .foregroundStyle(PrismColor.figmaHex(item.hex))
                                    Spacer()
                                    Text(verbatim: item.metric)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                        .foregroundStyle(PrismColor.onAccent)
                                        .padding(.horizontal, PrismSpacing.s)
                                        .padding(.vertical, PrismSpacing.xxs)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                                .fill(PrismColor.figmaHex(item.hex))
                                        )
                                }
                                Text(verbatim: item.title)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: item.subtitle)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }
                            .padding(PrismSpacing.l)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                            )
                        }
                    }
                    .padding(PrismSpacing.l)
                }
                .background(PrismColor.figmaHex("#f8fafc"))
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }

        private var offlineResilienceRES01View: some View {
            let packs: [(code: String, title: String, size: String)] = [
                ("AZ-104", "AZ-104 · Microsoft Azure Administrator", "68 Mo"),
                ("SAA-C03", "SAA-C03 · AWS Solutions Architect Associate", "52 Mo"),
                ("AI-102", "Veille IA Claude 4 / GPT / Foundry", "22 Mo")
            ]

            return VStack(spacing: .zero) {
                HStack {
                    Button {
                        if !profileNavPath.isEmpty { profileNavPath.removeLast() }
                    } label: {
                        Text(verbatim: "←  Paramètres")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(verbatim: "Mode Hors-Ligne")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Spacer()
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.m)
                .background(PrismColor.figmaHex("#f8fafc"))

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: PrismSpacing.l) {
                        HStack(spacing: PrismSpacing.m) {
                            CertiGoMascotView(pose: .poseReaderMemo, size: FigMetrics.sixtyFour)
                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: "RES-01 · MODE TRAIN / AVION · 142 MO")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#15803d"))
                                Text(verbatim: "Continuité Hors-Ligne Multi-Parcours")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: "0 clé de réponse locale stockée sur l'appareil (DR-004)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }
                        }
                        .padding(PrismSpacing.l)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                                .fill(PrismColor.surface)
                        )

                        ForEach(0..<packs.count, id: \.self) { idx in
                            let pack = packs[idx]
                            HStack(spacing: PrismSpacing.m) {
                                CertiGoOfficialCrestView(routeCode: pack.code, size: FigMetrics.fortyFour)
                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    Text(verbatim: pack.title)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    Text(verbatim: "Synchronisé · Prêt hors connexion")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                                }
                                Spacer()
                                Text(verbatim: pack.size)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            }
                            .padding(PrismSpacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                            )
                        }

                        Button {
                            if !profileNavPath.isEmpty { profileNavPath.removeLast() }
                        } label: {
                            Text(verbatim: "✓ SYNCHRONISER À LA RECONNEXION (IDEMPOTENT)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: PrismSize.primaryButtonHeight)
                        }
                        .buttonStyle(
                            CertiGoTactile3DButtonStyle(
                                faceHex: "#0078d4",
                                lipHex: "#005a9e",
                                cornerRadius: PrismRadius.l
                            )
                        )
                    }
                    .padding(PrismSpacing.l)
                }
                .background(PrismColor.figmaHex("#f8fafc"))
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }

        private func settingsActionRow(title: String, value: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                HStack {
                    Text(verbatim: title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Spacer()
                    Text(verbatim: value)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                }
                .padding(PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.surface)
                )
            }
            .buttonStyle(.plain)
        }

        private func settingsToggleRow(title: String, isOn: Binding<Bool>) -> some View {
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                    isOn.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(verbatim: title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Spacer()
                    ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                        RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                            .fill(
                                isOn.wrappedValue
                                    ? PrismColor.figmaHex("#58cc02")
                                    : PrismColor.figmaHex("#cbd5e1")
                            )
                            .frame(width: FigMetrics.toggleWidth, height: FigMetrics.toggleHeight)

                        Circle()
                            .fill(PrismColor.surface)
                            .frame(width: FigMetrics.toggleKnob, height: FigMetrics.toggleKnob)
                            .padding(.horizontal, PrismSpacing.xxs)
                    }
                }
                .padding(PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.surface)
                )
            }
            .buttonStyle(.plain)
        }

        // MARK: - Sheet 27 (`CertiGo PRO`) & Sheet Multi-Track Selector (`OB-03A/03B`)

        private var certiGoProSheet27View: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "✦  CERTIGO PRO")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Spacer()
                        Button {
                            appState.showProPaywallSheet27 = false
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    CertiGoMascotView(pose: .emotionBossCrown, size: FigMetrics.ninetySix)

                    Text(verbatim: "Réussis tes certifications\n2,8× plus vite.")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        .multilineTextAlignment(.center)

                    VStack(spacing: PrismSpacing.s) {
                        proComparisonRow(feature: "Parcours Multi-Certifs & Veille IA", free: "1 parcours", pro: "✓ Illimité")
                        proComparisonRow(feature: "Vies & Énergie quotidienne", free: "5 ❤️", pro: "∞ Illimité")
                        proComparisonRow(feature: "Coach IA Vocal Live & Explications", free: "Limité", pro: "✦ 24/7 Max")
                        proComparisonRow(feature: "Examens Blancs Pearson VUE (/1000)", free: "1 essai", pro: "✓ Illimités")
                    }
                    .padding(PrismSpacing.l)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.surface)
                    )

                    Button {
                        appState.isProMember = true
                        appState.heartsCount = 5
                        appState.showProPaywallSheet27 = false
                    } label: {
                        Text(verbatim: appState.isProMember ? "✓ ABONNEMENT CERTIGO PRO ACTIF" : "✦ ACTIVER MON ESSAI CERTIGO PRO (VIES ∞)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#58cc02",
                            lipHex: "#46a302",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private func proComparisonRow(feature: String, free: String, pro: String) -> some View {
            HStack {
                Text(verbatim: feature)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Spacer()
                Text(verbatim: free)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    .frame(width: FigMetrics.sixtyFour)
                Text(verbatim: pro)
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    .frame(width: FigMetrics.eighty, alignment: .trailing)
            }
        }

        private var multiTrackSelectorSheetOB03View: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "🔀 MULTI-PARCOURS & VEILLE IA")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Spacer()
                        Button {
                            appState.showMultiTrackSelectorSheet = false
                        } label: {
                            Text(verbatim: "Fermer")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(verbatim: "Quelles certifications veux-tu suivre en parallèle ?")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                    ForEach(CertiGoMultiTrackAndAIContentCatalog.parallelCertificationTracks) { track in
                        let isSelected = coordinator.parallelTracksPreference.isTrackingParallelCertification(track.code)
                        Button {
                            coordinator.parallelTracksPreference.toggleParallelTrack(track.code)
                            appState.selectRoute(track.code)
                            try? preferenceStore.save(coordinator.parallelTracksPreference)
                        } label: {
                            HStack(spacing: PrismSpacing.m) {
                                CertiGoOfficialCrestView(routeCode: track.code, size: FigMetrics.fortyFour)
                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    Text(verbatim: "\(track.code) · \(track.officialTitle)")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    Text(verbatim: track.shortSubtitle)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                }
                                Spacer()
                                Text(verbatim: isSelected ? "✓" : "+")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#0078d4"))
                                    .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
                                    .background(
                                        Circle().fill(
                                            isSelected
                                                ? PrismColor.figmaHex("#58cc02")
                                                : PrismColor.figmaHex("#eff6ff")
                                        )
                                    )
                            }
                            .padding(PrismSpacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        // MARK: - 12 Implied Native Sheets (Gamification 2A/2B/2C, Social 1A/1B, Domain 3C, AI Memos 4A, Profile 5A & Settings 5B)

        @ViewBuilder
        private func gamificationSheetView(for kind: CertiGoGamificationSheetKind) -> some View {
            switch kind {
            case .streak:
                streakSheetView
            case .gems:
                gemsShopSheetView
            case .hearts:
                heartsEnergySheetView
            }
        }

        private var streakSheetView: some View {
            let weekDays = ["L", "M", "M", "J", "V", "S", "D"]
            return ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "🔥 SÉRIE ACTIVE · CONSTANCE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#ea580c"))
                        Spacer()
                        Button {
                            appState.activeGamificationSheet = nil
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    CertiGoMascotView(pose: .celebratingTrophy, size: FigMetrics.eightyEight)

                    Text(verbatim: "\(appState.streakDays) jours de Série consécutifs 🔥")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        .multilineTextAlignment(.center)

                    HStack(spacing: PrismSpacing.s) {
                        ForEach(0..<weekDays.count, id: \.self) { idx in
                            VStack(spacing: PrismSpacing.xs) {
                                Text(verbatim: weekDays[idx])
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                Text(verbatim: "🔥")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
                                    .background(
                                        Circle().fill(PrismColor.figmaHex("#ffedd5"))
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(PrismSpacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(PrismColor.surface)
                    )

                    HStack(spacing: PrismSpacing.m) {
                        Text(verbatim: "🧊")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            Text(verbatim: "Bouclier Gel de Série")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            Text(verbatim: "🧊 \(appState.streakFreezeCount) Boucliers équipés · Protège ta série en cas d'oubli")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                        }
                        Spacer()
                    }
                    .padding(PrismSpacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(PrismColor.figmaHex("#eff6ff"))
                    )

                    Button {
                        appState.activeGamificationSheet = nil
                        appState.startLessonSession()
                    } label: {
                        Text(verbatim: "🎯 Prolonger ma série aujourd'hui (+15 XP)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#ea580c",
                            lipHex: "#c2410c",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private var gemsShopSheetView: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "💎 BOUTIQUE GEMMES CERTIGO")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                        Spacer()
                        Button {
                            appState.activeGamificationSheet = nil
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(verbatim: "💎 \(appState.gemsCount) Gemmes")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                    gemsShopPowerUpCard(
                        icon: "🧊",
                        title: "Bouclier Gel de Série",
                        subtitle: "Équipés : \(appState.streakFreezeCount) · Protège ta série 24h",
                        costLabel: "200 💎"
                    ) {
                        _ = appState.purchaseStreakFreezeWithGems()
                    }

                    gemsShopPowerUpCard(
                        icon: "❤️",
                        title: "Recharge Complète 5 Vies",
                        subtitle: "Vies actuelles : \(appState.heartsCount)/5 ❤️",
                        costLabel: "150 💎"
                    ) {
                        _ = appState.refillHeartsWithGems()
                    }

                    gemsShopPowerUpCard(
                        icon: "⚡",
                        title: "Boost Double XP (30 min)",
                        subtitle: appState.isDoubleXPBoostActive ? "✓ Boost 2× XP Actif !" : "Gagne 2× plus d'XP en Ligue Or",
                        costLabel: "100 💎"
                    ) {
                        _ = appState.activateDoubleXPWithGems()
                    }
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private func gemsShopPowerUpCard(
            icon: String,
            title: String,
            subtitle: String,
            costLabel: String,
            action: @escaping () -> Void
        ) -> some View {
            HStack(spacing: PrismSpacing.m) {
                Text(verbatim: icon)
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                    .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .fill(PrismColor.figmaHex("#eff6ff"))
                    )
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Text(verbatim: subtitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                Spacer()
                Button(action: action) {
                    Text(verbatim: costLabel)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .padding(.horizontal, PrismSpacing.m)
                        .padding(.vertical, PrismSpacing.s)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#0284c7",
                        lipHex: "#0369a1",
                        cornerRadius: PrismRadius.m,
                        lipDepth: FigMetrics.three
                    )
                )
            }
            .padding(PrismSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.surface)
            )
        }

        private var heartsEnergySheetView: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "❤️ VIES & ÉNERGIE QUOTIDIENNE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#e11d48"))
                        Spacer()
                        Button {
                            appState.activeGamificationSheet = nil
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: PrismSpacing.s) {
                        ForEach(0..<5, id: \.self) { idx in
                            Text(verbatim: idx < appState.heartsCount ? "❤️" : "🤍")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twentyEight, style: "Black"))
                        }
                    }
                    .padding(.vertical, PrismSpacing.s)

                    Text(verbatim: appState.heartsCount >= 5 ? "Tes 5 vies sont au maximum !" : "Prochain ❤️ dans 14 min")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))

                    Button {
                        appState.recoverOneHeartForFree()
                        appState.activeGamificationSheet = nil
                        appState.startLessonSession(skipDeclic15: true)
                    } label: {
                        Text(verbatim: "🎯 Entraînement de récupération (+1 ❤️ Gratuit)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#58cc02",
                            lipHex: "#46a302",
                            cornerRadius: PrismRadius.l
                        )
                    )

                    Button {
                        _ = appState.refillHeartsWithGems()
                    } label: {
                        Text(verbatim: "💎 Recharger mes 5 vies (150 💎)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#0284c7",
                            lipHex: "#0369a1",
                            cornerRadius: PrismRadius.l
                        )
                    )

                    Button {
                        appState.activeGamificationSheet = nil
                        appState.showProPaywallSheet27 = true
                    } label: {
                        Text(verbatim: "✦ Vies Illimitées avec CertiGo PRO")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#0078d4",
                            lipHex: "#005a9e",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private var addFriendSheetView: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    HStack(spacing: PrismSpacing.m) {
                        CertiGoMascotView(pose: .onboardingWelcome, size: FigMetrics.seventyTwo)
                        Text(verbatim: "Ajouter des partenaires d'étude")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        Spacer()
                        Button {
                            appState.showAddFriendSheet = false
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    // Mon Code Ami & QR Code 3D Card
                    VStack(spacing: PrismSpacing.m) {
                        HStack(spacing: PrismSpacing.m) {
                            Image(systemName: "qrcode")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twentyEight, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                .frame(width: FigMetrics.fiftySix, height: FigMetrics.fiftySix)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .fill(PrismColor.figmaHex("#eff6ff"))
                                )
                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: "Mon Code Ami & QR Code")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: "\(appState.userHandle) · Code CG-104")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            }
                            Spacer()
                        }

                        Button {
                            appState.isInviteLinkCopied = true
                            UIPasteboard.general.string = "\(appState.userHandle) · Code CG-104"
                        } label: {
                            Text(verbatim: appState.isInviteLinkCopied ? "✓ Lien copié !" : "🔗 Copier mon lien d'invitation")
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: FigMetrics.fortyFour)
                        }
                        .buttonStyle(
                            CertiGoTactile3DButtonStyle(
                                faceHex: appState.isInviteLinkCopied ? "#15803d" : "#0078d4",
                                lipHex: appState.isInviteLinkCopied ? "#166534" : "#005a9e",
                                cornerRadius: PrismRadius.m,
                                lipDepth: FigMetrics.three
                            )
                        )
                    }
                    .padding(PrismSpacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.surface)
                    )

                    // Direct Search by handle or email
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: "RECHERCHE DIRECTE PAR PSEUDO OU E-MAIL")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        HStack(spacing: PrismSpacing.s) {
                            TextField(
                                text: $appState.friendSearchQuery,
                                prompt: Text(verbatim: "@pseudo ou collegue@entreprise.com")
                            ) {
                                Text(verbatim: "@pseudo ou collegue@entreprise.com")
                            }
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            .padding(.horizontal, PrismSpacing.m)
                            .frame(height: FigMetrics.fortyFour)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.surface)
                            )

                            Button {
                                appState.addNewFriendFromSearch()
                            } label: {
                                Text(verbatim: "+ Ajouter")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                    .padding(.horizontal, PrismSpacing.m)
                                    .frame(height: FigMetrics.fortyFour)
                            }
                            .buttonStyle(
                                CertiGoTactile3DButtonStyle(
                                    faceHex: "#58cc02",
                                    lipHex: "#46a302",
                                    cornerRadius: PrismRadius.m,
                                    lipDepth: FigMetrics.three
                                )
                            )
                        }

                        if let confirmation = appState.lastAddedFriendConfirmation {
                            Text(verbatim: confirmation)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#15803d"))
                                .padding(.horizontal, PrismSpacing.m)
                                .padding(.vertical, PrismSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                        .fill(PrismColor.figmaHex("#dcfce7"))
                                )
                        }
                    }

                    // 5 Suggested Colleagues
                    Text(verbatim: "SUGGESTIONS D'ARCHITECTES (MÊME LIGUE OR)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))

                    ForEach(0..<appState.suggestedFriends.count, id: \.self) { idx in
                        let suggestion = appState.suggestedFriends[idx]
                        HStack(spacing: PrismSpacing.m) {
                            Text(verbatim: suggestion.initials)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .frame(width: FigMetrics.forty, height: FigMetrics.forty)
                                .background(Circle().fill(PrismColor.figmaHex(suggestion.avatarHex)))

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: "\(suggestion.displayName) · \(suggestion.routeCode)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: "\(suggestion.handle) · 🔥 \(suggestion.streakDays)j")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }

                            Spacer()

                            Button {
                                appState.addSuggestedFriend(at: idx)
                            } label: {
                                Text(verbatim: suggestion.isAdded ? "✓ Ajouté" : "+ Ajouter")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(suggestion.isAdded ? PrismColor.figmaHex("#15803d") : PrismColor.onAccent)
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.xs)
                            }
                            .buttonStyle(
                                CertiGoTactile3DButtonStyle(
                                    faceHex: suggestion.isAdded ? "#dcfce7" : "#0078d4",
                                    lipHex: suggestion.isAdded ? "#86efac" : "#005a9e",
                                    cornerRadius: PrismRadius.s,
                                    lipDepth: FigMetrics.three
                                )
                            )
                        }
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                    }
                }
                .padding(PrismSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private func friendProfileSheetView(profile: CertiGoSocialProfilePreview) -> some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "🏆 LIGUE OR · RANG #\(profile.rank)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#d97706"))
                        Spacer()
                        Button {
                            appState.selectedFriendProfile = nil
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: PrismSpacing.xs) {
                        Text(verbatim: profile.initials)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(width: FigMetrics.seventyTwo, height: FigMetrics.seventyTwo)
                            .background(Circle().fill(PrismColor.figmaHex(profile.avatarHex)))

                        Text(verbatim: profile.displayName)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                        Text(verbatim: profile.handle)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }

                    HStack(spacing: PrismSpacing.s) {
                        ForEach(0..<profile.activeCertifications.count, id: \.self) { idx in
                            let code = profile.activeCertifications[idx]
                            HStack(spacing: PrismSpacing.xs) {
                                CertiGoOfficialCrestView(routeCode: code, size: FigMetrics.twentyFour)
                                Text(verbatim: code)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            }
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                        }
                    }

                    // Comparaison Face-à-Face (`Toi vs [Nom]`)
                    VStack(alignment: .leading, spacing: PrismSpacing.m) {
                        Text(verbatim: "COMPARAISON FACE-À-FACE (TOI VS \(profile.displayName.uppercased()))")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        friendComparisonRow(label: "XP Semaine", myValue: "\(appState.userXPPoints) XP", friendValue: "\(profile.xpPoints) XP")
                        friendComparisonRow(label: "Série 🔥", myValue: "\(appState.streakDays) j", friendValue: "\(profile.streakDays) j")
                        friendComparisonRow(
                            label: "Précision Examen %",
                            myValue: appState.completedStepsTotal > 0 ? "\(appState.lessonSession.accuracyPercent) %" : "0 %",
                            friendValue: "\(profile.examAccuracyPercent) %"
                        )
                    }
                    .padding(PrismSpacing.l)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.surface)
                    )

                    Button {
                        appState.toggleSalutSelectedProfile()
                    } label: {
                        Text(verbatim: profile.isSaluted ? "👏 Félicité / Salué ✓" : "👋 Féliciter / Saluer")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(profile.isSaluted ? PrismColor.figmaHex("#15803d") : PrismColor.figmaHex("#0078d4"))
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: profile.isSaluted ? "#dcfce7" : "#eff6ff",
                            lipHex: profile.isSaluted ? "#86efac" : "#93c5fd",
                            cornerRadius: PrismRadius.l
                        )
                    )

                    Button {
                        appState.selectedFriendProfile = nil
                        appState.startLessonSession(skipDeclic15: true)
                    } label: {
                        Text(verbatim: "⚡ Défier sur 5 questions (Duel Express)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#0078d4",
                            lipHex: "#005a9e",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private func friendComparisonRow(label: String, myValue: String, friendValue: String) -> some View {
            HStack {
                Text(verbatim: myValue)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    .frame(width: FigMetrics.eighty, alignment: .leading)
                Spacer()
                Text(verbatim: label)
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                Spacer()
                Text(verbatim: friendValue)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#7c3aed"))
                    .frame(width: FigMetrics.eighty, alignment: .trailing)
            }
        }

        private var domainPracticeModePickerSheetView: some View {
            let domains = CertiGoNativeRichCatalog.examDomains(forRouteCode: appState.activeRouteCode)
            let domIdx = min(max(appState.selectedDomainForPractice ?? 0, 0), max(0, domains.count - 1))
            let domain = domains[domIdx]
            let dynamicPct = appState.domainMasteryPercent(forRouteCode: appState.activeRouteCode, domainIndex: domIdx)
            let providerMeta = CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: appState.activeRouteCode)

            return ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "DOMAINE OFFICIEL \(appState.activeRouteCode)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Spacer()
                        Button {
                            appState.selectedDomainForPractice = nil
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(verbatim: domain.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                    Text(verbatim: "\(domain.weightText) · Maîtrise actuelle : \(dynamicPct) %")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))

                    Button {
                        appState.startDomainSprintSession(forDomainIndex: domIdx)
                    } label: {
                        Text(verbatim: "⚡ Sprint Express · 5 Questions (5 min)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#58cc02",
                            lipHex: "#46a302",
                            cornerRadius: PrismRadius.l
                        )
                    )
                    .accessibilityIdentifier("domain-sheet-start-sprint")

                    Button {
                        appState.selectedDomainForPractice = nil
                        appState.startTimedExam23()
                    } label: {
                        Text(verbatim: "🎯 Examen Ciblé sur ce Domaine (\(providerMeta.providerName))")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#0078d4",
                            lipHex: "#005a9e",
                            cornerRadius: PrismRadius.l
                        )
                    )

                    Button {
                        appState.selectedDomainForPractice = nil
                        appState.selectedTab = .parcours
                        appState.activeStepSheet = .memo14(lessonId: appState.activeLessonNode.id)
                    } label: {
                        Text(verbatim: "📖 Fiche Mémo Officielle du Domaine")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#eff6ff",
                            lipHex: "#93c5fd",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private var savedAIMemosSheetView: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "📌 MES MÉMOS IA SAUVEGARDÉS (\(appState.savedAIMemos.count))")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Spacer()
                        Button {
                            appState.showSavedAIMemosSheet = false
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    if appState.savedAIMemos.isEmpty {
                        CertiGoEmptyStateCardView(
                            mascotPose: .poseReaderMemo,
                            title: "📌 Aucun mémo sauvegardé",
                            subtitle: "Épingle des explications ou des règles d'or pendant tes révisions pour les retrouver ici."
                        )
                    } else {
                        ForEach(0..<appState.savedAIMemos.count, id: \.self) { idx in
                            let memo = appState.savedAIMemos[idx]
                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                HStack {
                                    Text(verbatim: memo.userPrompt)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    Spacer()
                                    Button {
                                        appState.removeSavedAIMemo(id: memo.id)
                                    } label: {
                                        Text(verbatim: "✕")
                                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                    }
                                    .buttonStyle(.plain)
                                }
                                Text(verbatim: memo.aiHeadline)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#334155"))
                                Text(verbatim: memo.examKeyRule1)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            }
                            .padding(PrismSpacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                        }
                    }
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private var editProfileSheetView: some View {
            let colorChoices = ["#0078d4", "#7c3aed", "#059669", "#ea580c", "#e11d48"]
            return ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "✎ MODIFIER MON PROFIL ARCHITECTE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Spacer()
                        Button {
                            appState.showEditProfileSheet = false
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "NOM COMPLET")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        TextField(
                            text: $appState.userDisplayName,
                            prompt: Text(verbatim: "Gabriel Chambaud")
                        ) {
                            Text(verbatim: "Gabriel Chambaud")
                        }
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "PSEUDO (@HANDLE)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        TextField(
                            text: $appState.userHandle,
                            prompt: Text(verbatim: "@gabriel")
                        ) {
                            Text(verbatim: "@gabriel")
                        }
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "DATE D'EXAMEN CIBLE PEARSON VUE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        TextField(
                            text: $appState.targetExamDateText,
                            prompt: Text(verbatim: "18 Nov. 2026")
                        ) {
                            Text(verbatim: "18 Nov. 2026")
                        }
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                    }

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "COULEUR DE L'AVATAR")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        HStack(spacing: PrismSpacing.m) {
                            ForEach(0..<colorChoices.count, id: \.self) { idx in
                                let hex = colorChoices[idx]
                                Button {
                                    appState.userAvatarHex = hex
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(PrismColor.figmaHex(hex))
                                            .frame(width: FigMetrics.forty, height: FigMetrics.forty)
                                        if appState.userAvatarHex == hex {
                                            Text(verbatim: "✓")
                                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                                .foregroundStyle(PrismColor.onAccent)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        appState.updateProfile(
                            displayName: appState.userDisplayName,
                            handle: appState.userHandle,
                            targetExamDate: appState.targetExamDateText,
                            avatarHex: appState.userAvatarHex
                        )
                    } label: {
                        Text(verbatim: "ENREGISTRER MON PROFIL ✓")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#58cc02",
                            lipHex: "#46a302",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }
                .padding(PrismSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private func settingsOptionPickerSheetView(kind: CertiGoSettingsPickerKind) -> some View {
            let title: String = {
                switch kind {
                case .language: return "Langue des cours & examens"
                case .examMode: return "Mode Examen Blanc (Pearson)"
                case .coachVoice: return "Voix du Coach IA Live"
                case .explanationStyle: return "Style des explications"
                }
            }()
            let options: [String] = {
                switch kind {
                case .language: return CertiGoFigmaLiveRuntimeState.settingsLanguageOptions
                case .examMode: return CertiGoFigmaLiveRuntimeState.settingsExamModeOptions
                case .coachVoice: return CertiGoFigmaLiveRuntimeState.settingsCoachVoiceOptions
                case .explanationStyle: return CertiGoFigmaLiveRuntimeState.settingsExplanationStyleOptions
                }
            }()
            let selectedIndex: Int = {
                switch kind {
                case .language: return appState.settingsLanguageIndex % options.count
                case .examMode: return appState.settingsExamModeIndex % options.count
                case .coachVoice: return appState.settingsCoachVoiceIndex % options.count
                case .explanationStyle: return appState.settingsExplanationStyleIndex % options.count
                }
            }()

            return ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "PRÉFÉRENCE CERTIGO")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Spacer()
                        Button {
                            appState.activeSettingsPicker = nil
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(verbatim: title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                    ForEach(0..<options.count, id: \.self) { idx in
                        let isSelected = idx == selectedIndex
                        Button {
                            appState.selectSettingsOption(for: kind, index: idx)
                        } label: {
                            HStack(spacing: PrismSpacing.m) {
                                Text(verbatim: options[idx])
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                    .foregroundStyle(isSelected ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#0f172a"))
                                Spacer()
                                Text(verbatim: isSelected ? "✓" : "")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#58cc02"))
                            }
                            .padding(PrismSpacing.l)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(
                            CertiGoTactile3DButtonStyle(
                                faceHex: isSelected ? "#eff6ff" : "#ffffff",
                                lipHex: isSelected ? "#3b82f6" : "#e2e8f0",
                                strokeHex: isSelected ? "#3b82f6" : "#e2e8f0",
                                cornerRadius: PrismRadius.l,
                                lipDepth: FigMetrics.three
                            )
                        )
                    }
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private func dismissKeyboardInteractively() {
            isAIInputFocused = false
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        private var errorRegistrySheetView: some View {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    HStack {
                        Text(verbatim: "🛠️ REGISTRE DES ERREURS CERTIGO (\(CertiGoErrorCode.allCases.count) CODES)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Spacer()
                        Button {
                            appState.showErrorRegistrySheet = false
                        } label: {
                            Text(verbatim: "✕")
                                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(verbatim: "Catalogue officiel des codes d'erreur structurés (CG-ERR-1001 à CG-ERR-6001) pour le diagnostic QA et la résilience système.")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))

                    ForEach(0..<CertiGoErrorCode.allCases.count, id: \.self) { idx in
                        errorRegistryRowView(error: CertiGoErrorCode.allCases[idx])
                    }
                }
                .padding(PrismSpacing.xl)
            }
            .background(PrismColor.figmaHex("#f8fafc"))
        }

        private func errorRegistryRowView(error: CertiGoErrorCode) -> some View {
            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                HStack {
                    Text(verbatim: error.code)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#b45309"))
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, PrismSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .fill(PrismColor.figmaHex("#fef3c7"))
                        )
                    Text(verbatim: error.category)
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    Spacer()
                    Text(verbatim: error.severityLabel)
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }

                Text(verbatim: error.title)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                Text(verbatim: error.userMessage)
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#334155"))

                Text(verbatim: error.technicalDetail)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold", monospaced: true))
                    .foregroundStyle(PrismColor.figmaHex("#64748b"))

                Button {
                    appState.triggerDiagnosticError(error)
                    appState.showErrorRegistrySheet = false
                    appState.selectedTab = .hubIA
                } label: {
                    Text(verbatim: "Simuler cette erreur (\(error.code))")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        .padding(.horizontal, PrismSpacing.m)
                        .padding(.vertical, PrismSpacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .fill(PrismColor.figmaHex("#eff6ff"))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(PrismSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.surface)
            )
        }

    private var examApplePaySheet22Overlay: some View {
        let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: appState.activeRouteCode)
        let providerMeta = CertiGoNativeRichCatalog.examProviderMetadata(forRouteCode: appState.activeRouteCode)
        return VStack(spacing: PrismSpacing.l) {
            HStack {
                Text(verbatim: providerMeta.providerBadge)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showExamLaunchSheet22 = false
                    }
                } label: {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                .buttonStyle(.plain)
            }

            // Official Crest Pedestal
            VStack(spacing: PrismSpacing.s) {
                CertiGoOfficialCrestView(routeCode: appState.activeRouteCode, size: PrismSize.crestHero)
                Text(verbatim: "Examen Blanc \(appState.activeRouteCode)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Text(verbatim: curriculum.examOfficialTitle)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
            }

            // Apple-Pay Style Summary Rows
            VStack(spacing: PrismSpacing.s) {
                applePayInfoRow(label: "ORGANISME OFFICIEL", value: providerMeta.providerName)
                applePayInfoRow(label: "CHRONOMÈTRE", value: "\(providerMeta.durationText) (Temps réel)")
                applePayInfoRow(label: "SEUIL D'ADMISSION", value: "\(providerMeta.passingThresholdText) points")
            }
            .padding(PrismSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#f8fafc"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
            )

            Button {
                appState.startTimedExam23()
            } label: {
                Text(verbatim: "🚀 DÉMARRER L'EXAMEN BLANC")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Black"))
                    .foregroundStyle(PrismColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: PrismSize.primaryButtonHeight)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: "#0078d4",
                    lipHex: "#005a9e",
                    cornerRadius: PrismRadius.l
                )
            )
            .accessibilityIdentifier("sheet22-launch-exam23")
        }
        .padding(PrismSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.sheet, style: .continuous)
                .fill(PrismColor.surface)
        )
        .padding(.horizontal, PrismSpacing.m)
        .padding(.bottom, PrismSpacing.l)
    }

    private func applePayInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(verbatim: label)
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#64748b"))
            Spacer()
            Text(verbatim: value)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
        }
    }

    // MARK: - TAB 3: Hub IA (`06`, `06B` Multi-Turn Chat, `06C` Live Voice & `06D` 85% Drawer Push)

    private var hubIATab06View: some View {
        GeometryReader { geo in
            let safeGeoWidth = geo.size.width.isFinite ? max(FigMetrics.twoHundredEighty, geo.size.width) : PrismSize.drawerWidth
            let drawerWidth = min(safeGeoWidth * 0.85, PrismSize.drawerWidth)

            ZStack(alignment: .leading) {
                if appState.isShowingVoiceLive06C {
                    voiceLive06CView
                        .transition(.opacity)
                } else {
                    // Main Chat View (`06` Welcome or `06B` Multi-Turn Conversation) stays fixed underneath when Drawer `06D` opens
                    VStack(spacing: .zero) {
                        // Top Navigation Header (1 single line guaranteed — no wrapping on `+ Nouvelle`)
                        HStack(spacing: PrismSpacing.s) {
                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                                    appState.isAIDrawerOpen06D.toggle()
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    .frame(width: FigMetrics.forty, height: FigMetrics.forty)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.surface)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hub-ia-hamburger-drawer-button")

                            VStack(alignment: .leading, spacing: FigMetrics.two) {
                                Text(verbatim: "Coach IA · \(appState.activeRouteCode)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    .lineLimit(1)
                                Text(verbatim: "Doc officielle & erreurs")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Regular"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                    .lineLimit(1)
                            }

                            Spacer(minLength: FigMetrics.four)

                            Button {
                                appState.showSavedAIMemosSheet = true
                            } label: {
                                Text(verbatim: "📌 \(appState.savedAIMemos.count)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0369a1"))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, PrismSpacing.s)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.figmaHex("#e0f2fe"))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hub-ia-saved-memos-button")

                            if isAIInputFocused {
                                Button {
                                    dismissKeyboardInteractively()
                                } label: {
                                    Text(verbatim: "⌨️ ▾")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, PrismSpacing.s)
                                        .padding(.vertical, PrismSpacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                                .fill(PrismColor.figmaHex("#e2e8f0"))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("hub-ia-dismiss-keyboard-header-button")
                            }

                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                    appState.chatTurns.removeAll()
                                }
                            } label: {
                                Text(verbatim: "+ Nouvelle")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, PrismSpacing.s)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.figmaHex("#eff6ff"))
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hub-ia-new-thread-button")
                        }
                        .padding(.horizontal, PrismSpacing.l)
                        .padding(.vertical, PrismSpacing.s)
                        .background(PrismColor.figmaHex("#f8fafc"))

                        // Scrollable Body (`06` Empty Welcome vs `06B` Multi-Turn Thread) with Interactive Keyboard Dismissal
                        ScrollView(.vertical, showsIndicators: false) {
                            if appState.chatTurns.isEmpty {
                                hubIAWelcome06Content
                            } else {
                                hubIAConversation06BContent
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .background(PrismColor.figmaHex("#f8fafc"))
                        .onTapGesture {
                            if isAIInputFocused {
                                dismissKeyboardInteractively()
                            }
                        }

                        // Bottom Input Bar (`TextField` + Send `↑` + Live Voice `[ılı]`)
                        hubIABottomInputBar
                            .padding(.bottom, isAIInputFocused ? PrismSpacing.s : FigMetrics.eightyEight)
                    }
                    .frame(width: safeGeoWidth)
                    .disabled(appState.isAIDrawerOpen06D)

                    // Full-screen uniform backdrop dimmer when 06D Drawer is open
                    if appState.isAIDrawerOpen06D {
                        Color.black.opacity(0.30)
                            .ignoresSafeArea(.all)
                            .onTapGesture {
                                withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                                    appState.isAIDrawerOpen06D = false
                                }
                            }
                            .transition(.opacity)
                            .zIndex(10)
                    }

                    // Full-height 85% Width Drawer (`06D`)
                    if appState.isAIDrawerOpen06D {
                        aiDrawer06DView(width: drawerWidth)
                            .frame(width: drawerWidth)
                            .transition(.move(edge: .leading))
                            .zIndex(11)
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: FigMetrics.eighteen)
                    .onEnded { value in
                        if value.translation.height > FigMetrics.twenty
                            && abs(value.translation.height) > abs(value.translation.width)
                        {
                            dismissKeyboardInteractively()
                        } else if value.translation.width > 45 && !appState.isAIDrawerOpen06D {
                            withAnimation(CertiGoMotion.spring(for: .anim06HistoryDrawer85Push, reduceMotion: reduceMotion)) {
                                appState.isAIDrawerOpen06D = true
                            }
                        } else if value.translation.width < -45 && appState.isAIDrawerOpen06D {
                            withAnimation(CertiGoMotion.spring(for: .anim06HistoryDrawer85Push, reduceMotion: reduceMotion)) {
                                appState.isAIDrawerOpen06D = false
                            }
                        }
                    }
            )
        }
    }

    private var hubIAWelcome06Content: some View {
        let suggestions: [(icon: String, title: String, subtitle: String, key: String)] = [
            ("📘", "Explique-moi RBAC vs Azure Policy", "Différences, portée & règle de priorité Owner", "rbac-vs-policy"),
            ("🎙️", "Simuler un entretien oral à voix haute", "Cas d'architecture Contoso Key Vault & VNet", "oral-interview"),
            ("🎯", "Analyse mes 3 dernières erreurs", "Diagnostic ciblé +65 pts Pearson VUE", "last-3-errors"),
            ("⚡", "Génère un exemple CLI commenté", "Commandes \(appState.activeRouteCode), réseau & sécurité", "cli-example")
        ]

        return VStack(spacing: PrismSpacing.l) {
            if let activeError = appState.activeDiagnosticError {
                // Show the diagnostic error card cleanly in place of the mascot welcome hero until dismissed!
                CertiGoDiagnosticErrorCardView(
                    error: activeError,
                    isCodeCopied: appState.isErrorCodeCopied,
                    onCopyCode: {
                        appState.isErrorCodeCopied = true
                        UIPasteboard.general.string = activeError.code
                    },
                    onOpenRegistry: {
                        appState.showErrorRegistrySheet = true
                    },
                    onDismiss: {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.activeDiagnosticError = nil
                        }
                    }
                )
                .padding(.top, PrismSpacing.s)
            } else {
                VStack(spacing: PrismSpacing.s) {
                    CertiGoMascotView(pose: .specialistAICoach, size: FigMetrics.ninetySix)
                    Text(verbatim: "Bonjour \(appState.firstNameText),")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Text(verbatim: "Comment veux-tu réviser \(appState.activeRouteCode) aujourd'hui ?")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, PrismSpacing.l)
            }

            VStack(spacing: PrismSpacing.m) {
                ForEach(suggestions, id: \.key) { item in
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.openAITopic(item.key)
                        }
                    } label: {
                        HStack(spacing: PrismSpacing.m) {
                            Text(verbatim: item.icon)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                                .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .fill(PrismColor.figmaHex("#eff6ff"))
                                )

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: item.title)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: item.subtitle)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }
                            Spacer(minLength: PrismSpacing.xs)
                            Text(verbatim: "›")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                        }
                        .padding(PrismSpacing.m)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#ffffff",
                            lipHex: "#e2e8f0",
                            strokeHex: "#e2e8f0",
                            cornerRadius: PrismRadius.l,
                            lipDepth: FigMetrics.four
                        )
                    )
                    .accessibilityIdentifier("hub-ia-suggestion-\(item.key)")
                }
            }
        }
        .padding(.horizontal, PrismSpacing.l)
        .padding(.bottom, PrismSpacing.xxl)
    }

    private var hubIAConversation06BContent: some View {
        LazyVStack(spacing: PrismSpacing.l) {
            if let activeError = appState.activeDiagnosticError {
                HStack(spacing: PrismSpacing.s) {
                    Text(verbatim: "⚠️ \(activeError.code)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#b45309"))
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, FigMetrics.three)
                        .background(
                            Capsule().fill(PrismColor.figmaHex("#fef3c7"))
                        )
                    Text(verbatim: "Mode synthèse locale hors-ligne · Endpoint Azure AI Foundry non connecté")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Medium"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))
                        .lineLimit(2)
                    Spacer(minLength: PrismSpacing.xxs)
                    Button {
                        appState.showErrorRegistrySheet = true
                    } label: {
                        Text(verbatim: "Détails")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#fde68a"), lineWidth: PrismBorder.standard)
                )
            }

            ForEach(0..<appState.chatTurns.count, id: \.self) { idx in
                let turn = appState.chatTurns[idx]
                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    // User Question Bubble (Right aligned)
                    HStack {
                        Spacer(minLength: FigMetrics.forty)
                        Text(verbatim: turn.userPrompt)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                            .padding(.horizontal, PrismSpacing.l)
                            .padding(.vertical, PrismSpacing.m)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.figmaHex("#0078d4"))
                            )
                    }

                    // Structured AI Coach Card (`06B`)
                    VStack(alignment: .leading, spacing: PrismSpacing.m) {
                        HStack(spacing: PrismSpacing.xs) {
                            Text(verbatim: "✦ CERTIGO IA · SYNTHÈSE OFFICIELLE")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            Spacer()
                            Text(verbatim: appState.activeRouteCode)
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }

                        Text(verbatim: turn.aiHeadline)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            Text(verbatim: turn.aiBullet1)
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#334155"))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: turn.aiBullet2)
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#334155"))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Highlighted Exam Takeaway Box (`💡 À retenir pour l'examen`)
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            Text(verbatim: "💡 À RETENIR POUR L'EXAMEN")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                            Text(verbatim: turn.examKeyRule1)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                                .foregroundStyle(PrismColor.figmaHex("#1e3a8a"))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(verbatim: turn.examKeyRule2)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                                .foregroundStyle(PrismColor.figmaHex("#1e3a8a"))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(PrismSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.figmaHex("#eff6ff"))
                        )

                        Text(verbatim: turn.closingTip)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))

                        // Action Chips: `[📋 Copier]`, `[📌 Sauver en Mémo]`, `[🎯 Quiz]`
                        HStack(spacing: PrismSpacing.s) {
                            Button {
                                appState.chatTurns[idx].isCopied = true
                                UIPasteboard.general.string = "\(turn.userPrompt)\n\(turn.aiHeadline)\n\(turn.aiBullet1)\n\(turn.aiBullet2)"
                            } label: {
                                Text(verbatim: turn.isCopied ? "✓ Copié" : "📋 Copier")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                                    .foregroundStyle(
                                        turn.isCopied ? PrismColor.figmaHex("#15803d") : PrismColor.figmaHex("#334155")
                                    )
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                            .fill(turn.isCopied ? PrismColor.figmaHex("#dcfce7") : PrismColor.figmaHex("#f1f5f9"))
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                appState.saveChatTurnToMemo(at: idx)
                            } label: {
                                Text(verbatim: turn.isSavedToMemo ? "✓ Sauvé en Mémo" : "📌 Sauver en Mémo")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                                    .foregroundStyle(
                                        turn.isSavedToMemo ? PrismColor.figmaHex("#0369a1") : PrismColor.figmaHex("#334155")
                                    )
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                            .fill(turn.isSavedToMemo ? PrismColor.figmaHex("#e0f2fe") : PrismColor.figmaHex("#f1f5f9"))
                                    )
                            }
                            .buttonStyle(.plain)

                            Button {
                                appState.startLessonSession(skipDeclic15: true)
                            } label: {
                                Text(verbatim: "🎯 Quiz")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                            .fill(PrismColor.figmaHex("#0078d4"))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(PrismSpacing.l)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                    )
                }
            }
        }
        .padding(.horizontal, PrismSpacing.l)
        .padding(.vertical, PrismSpacing.m)
    }

    private var hubIABottomInputBar: some View {
        HStack(spacing: PrismSpacing.s) {
            HStack(spacing: PrismSpacing.xs) {
                TextField(
                    text: $appState.aiDraftMessage,
                    prompt: Text(verbatim: "Poser une question à CertiGo IA...")
                ) {
                    Text(verbatim: "Poser une question à CertiGo IA...")
                }
                .focused($isAIInputFocused)
                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                .submitLabel(.send)
                .onSubmit {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.sendAIMessage(appState.aiDraftMessage)
                        isAIInputFocused = false
                    }
                }
                .accessibilityIdentifier("hub-ia-textfield")

                if isAIInputFocused {
                    Button {
                        dismissKeyboardInteractively()
                    } label: {
                        Text(verbatim: "⌨️ ▾")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#475569"))
                            .padding(.horizontal, PrismSpacing.xs)
                            .padding(.vertical, PrismSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(PrismColor.figmaHex("#f1f5f9"))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hub-ia-dismiss-keyboard-button")
                }

                if !appState.aiDraftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.sendAIMessage(appState.aiDraftMessage)
                            dismissKeyboardInteractively()
                        }
                    } label: {
                        Text(verbatim: "↑")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
                            .background(Circle().fill(PrismColor.figmaHex("#0078d4")))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("hub-ia-send-button")
                }
            }
            .padding(.horizontal, PrismSpacing.m)
            .frame(height: FigMetrics.fortyEight)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#cbd5e1"), lineWidth: PrismBorder.standard)
            )
            .gesture(
                DragGesture(minimumDistance: FigMetrics.eighteen)
                    .onEnded { value in
                        if value.translation.height > FigMetrics.twenty {
                            dismissKeyboardInteractively()
                        }
                    }
            )

            // Live Voice Mode Button (`06C`)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)) {
                    dismissKeyboardInteractively()
                    if !appState.isLiveAIModelConnected {
                        appState.triggerDiagnosticError(.voiceLiveNotConnected1002)
                    }
                    appState.isShowingVoiceLive06C = true
                    voiceHaloPulse = true
                }
            } label: {
                Image(systemName: "waveform")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                    .foregroundStyle(PrismColor.onAccent)
                    .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                    .background(Circle().fill(PrismColor.figmaHex("#0078d4")))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("hub-ia-voice-live-button")
        }
        .padding(.horizontal, PrismSpacing.l)
        .padding(.top, PrismSpacing.xs)
        .background(PrismColor.figmaHex("#f8fafc"))
    }

    private var voiceLive06CView: some View {
        let transcripts: [(speaker: String, line: String)] = [
            ("✦ NOVA · EN DIRECT (1,0×)", "« Pour isoler ton coffre Key Vault sans aucune exposition Internet, associe un Private Endpoint dans VNet-Spoke à la zone DNS privatelink.vaultcore.azure.net. »"),
            ("🎙️ TOI (GABRIEL)", "« Et si un administrateur Owner tente de supprimer le Key Vault alors qu'un verrou CanNotDelete est actif ? »"),
            ("✦ NOVA · RÉPONSE ORALE", "« Excellente question ! Même un Propriétaire (Owner) est bloqué par Azure Resource Manager tant que le verrou CanNotDelete n'est pas explicitement retiré. »")
        ]
        let currentTranscript = transcripts[appState.voiceLiveTranscriptIndex % transcripts.count]

        return ZStack {
            PrismColor.figmaHex("#090d16")
                .ignoresSafeArea()

            VStack(spacing: PrismSpacing.xl) {
                HStack {
                    Text(verbatim: "🎙️ COACH IA VOCAL LIVE · NOVA")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#38bdf8"))
                    Spacer()
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            appState.isShowingVoiceLive06C = false
                        }
                    } label: {
                        Text(verbatim: "✕")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                            .background(Circle().fill(PrismColor.figmaHex("#1e293b")))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, PrismSpacing.l)

                if !appState.isLiveAIModelConnected {
                    CertiGoDiagnosticErrorCardView(
                        error: .voiceLiveNotConnected1002,
                        isCodeCopied: appState.isErrorCodeCopied,
                        onCopyCode: {
                            appState.isErrorCodeCopied = true
                            UIPasteboard.general.string = CertiGoErrorCode.voiceLiveNotConnected1002.code
                        },
                        onOpenRegistry: {
                            appState.isShowingVoiceLive06C = false
                            appState.showErrorRegistrySheet = true
                        }
                    )
                    .padding(.horizontal, PrismSpacing.l)
                }

                Spacer()

                // Animated Nova Voice Orb & Concentric Halos (`ANIM_05`)
                ZStack {
                    Circle()
                        .stroke(PrismColor.figmaHex("#38bdf8:28"), lineWidth: FigMetrics.two)
                        .frame(width: FigMetrics.twoHundredTwenty, height: FigMetrics.twoHundredTwenty)
                        .scaleEffect(appState.isVoiceLiveListening ? 1.12 : 0.94)

                    Circle()
                        .fill(PrismColor.figmaHex("#0284c7:25"))
                        .frame(width: FigMetrics.oneHundredSixty, height: FigMetrics.oneHundredSixty)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    PrismColor.figmaHex("#38bdf8"),
                                    PrismColor.figmaHex("#0078d4")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: FigMetrics.oneHundredTen, height: FigMetrics.oneHundredTen)

                    CertiGoMascotView(pose: .specialistAICoach, size: FigMetrics.eighty)
                }

                // Live Evolving Transcript Card
                VStack(spacing: PrismSpacing.s) {
                    Text(verbatim: currentTranscript.speaker)
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#38bdf8"))
                    Text(verbatim: currentTranscript.line)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                        .foregroundStyle(PrismColor.onAccent)
                        .multilineTextAlignment(.center)
                }
                .padding(PrismSpacing.l)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                        .fill(PrismColor.figmaHex("#1e293b"))
                )
                .padding(.horizontal, PrismSpacing.l)

                // Voice Controls (`Poser une question orale`, Mic Toggle, Close)
                HStack(spacing: PrismSpacing.l) {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.voiceLiveTranscriptIndex += 1
                        }
                    } label: {
                        Text(verbatim: "🗣️ Poser une question orale")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .padding(.horizontal, PrismSpacing.l)
                            .frame(height: FigMetrics.fortyEight)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .fill(PrismColor.figmaHex("#0284c7"))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)) {
                            appState.isVoiceLiveListening.toggle()
                        }
                    } label: {
                        Image(systemName: appState.isVoiceLiveListening ? "mic.fill" : "mic.slash.fill")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(width: FigMetrics.fiftySix, height: FigMetrics.fiftySix)
                            .background(
                                Circle().fill(
                                    appState.isVoiceLiveListening
                                        ? PrismColor.figmaHex("#58cc02")
                                        : PrismColor.figmaHex("#e11d48")
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, FigMetrics.bottomBarTotalClearance)
            }
        }
    }

    private func aiDrawer06DView(width: CGFloat) -> some View {
        let pinned = appState.filteredAIThreads.filter(\.isPinned)
        let recent = appState.filteredAIThreads.filter { !$0.isPinned }

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            HStack {
                Text(verbatim: "Historique CertiGo IA")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                        appState.isAIDrawerOpen06D = false
                    }
                } label: {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                .buttonStyle(.plain)
            }

            // Live Search Bar (`🔍 Rechercher une discussion...`)
            HStack(spacing: PrismSpacing.xs) {
                Text(verbatim: "🔍")
                TextField(
                    text: $appState.aiDrawerSearchQuery,
                    prompt: Text(verbatim: "Rechercher une discussion...")
                ) {
                    Text(verbatim: "Rechercher une discussion...")
                }
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                .accessibilityIdentifier("ai-drawer-search-textfield")
            }
            .padding(.horizontal, PrismSpacing.m)
            .frame(height: FigMetrics.forty)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                    .fill(PrismColor.figmaHex("#f1f5f9"))
            )

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: PrismSpacing.s) {
                    if appState.filteredAIThreads.isEmpty {
                        CertiGoEmptyStateCardView(
                            mascotPose: .specialistAICoach,
                            title: "💬 Aucune discussion IA pour l'instant",
                            subtitle: "Tes futures sessions avec le Coach CertiGo IA apparaîtront ici dès que le modèle IA sera connecté."
                        )
                    } else {
                        if !pinned.isEmpty {
                            Text(verbatim: "📌 ÉPINGLÉES")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                .padding(.top, PrismSpacing.xs)

                            ForEach(pinned) { thread in
                                aiThreadRowButton(thread)
                            }
                        }

                        Text(verbatim: "🕒 RÉCENTES (\(recent.count))")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            .padding(.top, PrismSpacing.s)

                        ForEach(recent) { thread in
                            aiThreadRowButton(thread)
                        }
                    }
                }
                .padding(.bottom, FigMetrics.bottomBarTotalClearance)
            }
        }
        .padding(PrismSpacing.l)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(PrismColor.surface.ignoresSafeArea(.all, edges: .vertical))
        .shadow(color: Color.black.opacity(0.14), radius: 20, x: 8, y: 0)
        .overlay(
            Rectangle()
                .fill(PrismColor.figmaHex("#e2e8f0"))
                .frame(width: PrismBorder.hairline)
                .ignoresSafeArea(.all, edges: .vertical),
            alignment: .trailing
        )
    }

    private func aiThreadRowButton(_ thread: CertiGoAIThreadItem) -> some View {
        Button {
            withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                appState.openAITopic(thread.topicKey, customUserQuestion: thread.title)
            }
        } label: {
            HStack(spacing: PrismSpacing.s) {
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: thread.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        .lineLimit(1)
                    Text(verbatim: thread.subtitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        .lineLimit(1)
                }
                Spacer(minLength: PrismSpacing.xxs)
                Text(verbatim: thread.routeBadge)
                    .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    .padding(.horizontal, PrismSpacing.xs)
                    .padding(.vertical, PrismSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                            .fill(PrismColor.figmaHex("#eff6ff"))
                    )
            }
            .padding(PrismSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                    .fill(PrismColor.figmaHex("#f8fafc"))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - TAB 4: Social (`07` Podium 3D Semaine & `25` Mes Amis (12))

    private var socialTab07And25View: some View {
        VStack(spacing: .zero) {
            // Top Header + Segmented Picker (`🏆 Podium Semaine` | `👥 Mes Amis (12)`)
            VStack(spacing: PrismSpacing.s) {
                HStack {
                    Text(verbatim: "Ligue Or · Semaine 42")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Spacer()
                    Button {
                        appState.showAddFriendSheet = true
                    } label: {
                        Text(verbatim: "➕ Ajouter")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.figmaHex("#eff6ff"))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("social-open-add-friend-sheet")
                }

                HStack(spacing: PrismSpacing.xs) {
                    socialSegmentButton(index: 0, title: "🏆 Podium Semaine")
                    socialSegmentButton(index: 1, title: "👥 Mes Amis (\(appState.friends.count))")
                }
                .padding(PrismSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.figmaHex("#e2e8f0"))
                )
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.vertical, PrismSpacing.s)
            .background(PrismColor.figmaHex("#f8fafc"))

            // 1C. Horizontal Swipe Gesture between `🏆 Podium Semaine (07)` and `👥 Mes Amis (25)`
            TabView(selection: $appState.selectedSocialSubTab) {
                socialPodium07ScrollView
                    .tag(0)
                socialFriends25ScrollView
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private func socialSegmentButton(index: Int, title: String) -> some View {
        let isSelected = appState.selectedSocialSubTab == index
        return Button {
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                appState.selectedSocialSubTab = index
            }
        } label: {
            Text(verbatim: title)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                .foregroundStyle(isSelected ? PrismColor.figmaHex("#0f172a") : PrismColor.figmaHex("#64748b"))
                .frame(maxWidth: .infinity)
                .frame(height: FigMetrics.thirtySix)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .fill(isSelected ? PrismColor.surface : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("social-segment-\(index)")
    }

    private var socialPodium07ScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PrismSpacing.m) {
                if appState.userXPPoints == 0 {
                    CertiGoEmptyStateCardView(
                        mascotPose: .celebratingTrophy,
                        title: "🏆 Classement hebdomadaire — Tu es à 0 XP",
                        subtitle: "Termine ta première leçon (+25 XP) aujourd'hui pour entrer dans le classement actif de la semaine !",
                        actionTitle: "🚀 Gagner mes premiers +25 XP"
                    ) {
                        appState.selectedTab = .parcours
                        appState.startLessonSession(enableAdaptiveReplay: true)
                    }
                }

                // 3D Podium Stage (`2e Sarah L.`, `1er Toi 👑`, `3e Thomas M.`)
                HStack(alignment: .bottom, spacing: PrismSpacing.m) {
                    podiumColumnView(member: appState.leaderboardMembers[1], height: PrismSize.podiumSecondHeight, medal: "🥈 2e", pedestalHex: "#cbd5e1")
                    podiumColumnView(member: appState.leaderboardMembers[0], height: PrismSize.podiumFirstHeight, medal: "👑 1er", pedestalHex: "#facc15")
                    podiumColumnView(member: appState.leaderboardMembers[2], height: PrismSize.podiumThirdHeight, medal: "🥉 3e", pedestalHex: "#fdba74")
                }
                .padding(PrismSpacing.l)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                        .fill(PrismColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                )

                // Full 12-Member Leaderboard (`1er` .. `12e`) — Every row is tappable to open `friendProfileSheetView`
                ForEach(appState.leaderboardMembers) { member in
                    Button {
                        appState.openFriendProfile(for: member)
                    } label: {
                        HStack(spacing: PrismSpacing.m) {
                            Text(verbatim: "\(member.rank)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                .foregroundStyle(member.rank <= 3 ? PrismColor.figmaHex("#d97706") : PrismColor.figmaHex("#64748b"))
                                .frame(width: FigMetrics.twentyFour)

                            Text(verbatim: member.initials)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .frame(width: FigMetrics.forty, height: FigMetrics.forty)
                                .background(Circle().fill(PrismColor.figmaHex(member.avatarHex)))

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: member.displayName)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: "\(member.routeBadge) · 🔥 \(member.streakDays)j")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }

                            Spacer()

                            Text(verbatim: "\(member.xpPoints) XP")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        }
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .fill(member.isCurrentUser ? PrismColor.figmaHex("#eff6ff") : PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .strokeBorder(
                                    member.isCurrentUser ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#e2e8f0"),
                                    lineWidth: PrismBorder.standard
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.xs)
            .padding(.bottom, FigMetrics.bottomBarTotalClearance)
        }
        .background(PrismColor.figmaHex("#f8fafc"))
    }

    private func podiumColumnView(
        member: CertiGoLeaderboardMember,
        height: CGFloat,
        medal: String,
        pedestalHex: String
    ) -> some View {
        Button {
            appState.openFriendProfile(for: member)
        } label: {
            VStack(spacing: PrismSpacing.xs) {
                Text(verbatim: member.initials)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                    .foregroundStyle(PrismColor.onAccent)
                    .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                    .background(Circle().fill(PrismColor.figmaHex(member.avatarHex)))

                Text(verbatim: member.displayName)
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .lineLimit(1)

                Text(verbatim: "\(member.xpPoints) XP")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))

                VStack {
                    Text(verbatim: medal)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        .padding(.top, PrismSpacing.s)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .fill(PrismColor.figmaHex(pedestalHex))
                )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var socialFriends25ScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: PrismSpacing.m) {
                // Live Search & Add Friend Bar (`🔍 Chercher ou ajouter un pseudo...`)
                HStack(spacing: PrismSpacing.s) {
                    Text(verbatim: "🔍")
                    TextField(
                        text: $appState.friendSearchQuery,
                        prompt: Text(verbatim: "Chercher ou ajouter un pseudo...")
                    ) {
                        Text(verbatim: "Chercher ou ajouter un pseudo...")
                    }
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .accessibilityIdentifier("social-friends-search-textfield")

                    if !appState.friendSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.addNewFriendFromSearch()
                            }
                        } label: {
                            Text(verbatim: "+ Ajouter")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .padding(.horizontal, PrismSpacing.s)
                                .padding(.vertical, PrismSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                        .fill(PrismColor.figmaHex("#58cc02"))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PrismSpacing.m)
                .frame(height: FigMetrics.fortyEight)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#cbd5e1"), lineWidth: PrismBorder.standard)
                )

                // Invite Link Card (`🔗 Partager mon lien d'invitation` + `+ Inviter / QR Code`)
                VStack(spacing: PrismSpacing.s) {
                    HStack(spacing: PrismSpacing.m) {
                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            Text(verbatim: "🔗 Partager mon lien d'invitation")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            Text(verbatim: "Code ami : \(appState.userHandle) · CG-104")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        }
                        Spacer()
                        Button {
                            appState.isInviteLinkCopied = true
                            UIPasteboard.general.string = appState.userHandle
                        } label: {
                            Text(verbatim: appState.isInviteLinkCopied ? "✓ Copié" : "Copier")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                .foregroundStyle(
                                    appState.isInviteLinkCopied ? PrismColor.figmaHex("#15803d") : PrismColor.figmaHex("#0078d4")
                                )
                                .padding(.horizontal, PrismSpacing.m)
                                .padding(.vertical, PrismSpacing.s)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .fill(
                                            appState.isInviteLinkCopied
                                                ? PrismColor.figmaHex("#dcfce7")
                                                : PrismColor.figmaHex("#eff6ff")
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        appState.showAddFriendSheet = true
                    } label: {
                        Text(verbatim: "+ Inviter / QR Code & Suggestions")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: FigMetrics.forty)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#0078d4",
                            lipHex: "#005a9e",
                            cornerRadius: PrismRadius.m,
                            lipDepth: FigMetrics.three
                        )
                    )
                }
                .padding(PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                )

                // Empty state when user has not yet added any friends vs Friends List
                if appState.friends.isEmpty {
                    CertiGoEmptyStateCardView(
                        mascotPose: .onboardingWelcome,
                        title: "Tu n'as pas encore ajouté d'amis",
                        subtitle: "Pour l'instant il n'y a aucune information d'amis. Ajoute un collègue ou choisis parmi les suggestions pour suivre votre progression commune.",
                        actionTitle: "➕ Ajouter mon premier ami"
                    ) {
                        appState.showAddFriendSheet = true
                    }
                } else {
                    ForEach(appState.filteredFriends) { friend in
                        HStack(spacing: PrismSpacing.m) {
                            Button {
                                appState.openFriendProfile(for: friend)
                            } label: {
                                HStack(spacing: PrismSpacing.m) {
                                    Text(verbatim: friend.initials)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                        .foregroundStyle(PrismColor.onAccent)
                                        .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                                        .background(Circle().fill(PrismColor.figmaHex(friend.avatarHex)))

                                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                        Text(verbatim: "\(friend.displayName) · 🔥 \(friend.streakDays)j")
                                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                        Text(verbatim: "\(friend.handle) · \(friend.activeTrackText)")
                                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                    appState.toggleSalutFriend(id: friend.id)
                                }
                            } label: {
                                Text(verbatim: friend.isSaluted ? "👏 Salué ✓" : "👋 Salut")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(
                                        friend.isSaluted ? PrismColor.figmaHex("#15803d") : PrismColor.figmaHex("#0078d4")
                                    )
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.s)
                            }
                            .buttonStyle(
                                CertiGoTactile3DButtonStyle(
                                    faceHex: friend.isSaluted ? "#dcfce7" : "#eff6ff",
                                    lipHex: friend.isSaluted ? "#86efac" : "#bfdbfe",
                                    cornerRadius: PrismRadius.m,
                                    lipDepth: FigMetrics.three
                                )
                            )
                        }
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                        )
                    }
                }
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.xs)
            .padding(.bottom, FigMetrics.bottomBarTotalClearance)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PrismColor.figmaHex("#f8fafc"))
    }
}

/// High-craft 3D Tactile Diagnostic Error Card (`CG-ERR-xxxx`) for honest AI/System error reporting.
public struct CertiGoDiagnosticErrorCardView: View {
    public let error: CertiGoErrorCode
    public let isCodeCopied: Bool
    public let onCopyCode: () -> Void
    public let onOpenRegistry: () -> Void
    public let onDismiss: (() -> Void)?

    public init(
        error: CertiGoErrorCode,
        isCodeCopied: Bool = false,
        onCopyCode: @escaping () -> Void = {},
        onOpenRegistry: @escaping () -> Void = {},
        onDismiss: (() -> Void)? = nil
    ) {
        self.error = error
        self.isCodeCopied = isCodeCopied
        self.onCopyCode = onCopyCode
        self.onOpenRegistry = onOpenRegistry
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.m) {
            HStack(spacing: PrismSpacing.xs) {
                Text(verbatim: "⚠️ ERREUR SYSTÈME · \(error.code)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black", monospaced: true))
                    .foregroundStyle(PrismColor.figmaHex("#b45309"))
                    .padding(.horizontal, PrismSpacing.s)
                    .padding(.vertical, PrismSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .fill(PrismColor.figmaHex("#fef3c7"))
                    )
                Spacer()
                Text(verbatim: error.category)
                    .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                if let onDismiss {
                    Button(action: onDismiss) {
                        Text(verbatim: "✕ Masquer l'alerte")
                            .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            .padding(.horizontal, PrismSpacing.xs)
                            .padding(.vertical, PrismSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                                    .fill(PrismColor.figmaHex("#f1f5f9"))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("diagnostic-error-dismiss-button")
                }
            }

            HStack(spacing: PrismSpacing.m) {
                CertiGoMascotView(pose: .errorCorrectionEncouraging, size: FigMetrics.sixtyFour)
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: "Fonctionnalité IA indisponible (Modèle non connecté)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Text(verbatim: error.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#e11d48"))
                }
            }

            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                Text(verbatim: error.userMessage)
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#334155"))
                Text(verbatim: error.technicalDetail)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold", monospaced: true))
                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                Text(verbatim: "💡 Action recommandée : \(error.recommendedAction)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                    .fill(PrismColor.figmaHex("#fffbeb"))
            )

            HStack(spacing: PrismSpacing.s) {
                Button(action: onCopyCode) {
                    Text(verbatim: isCodeCopied ? "✓ Code copié !" : "📋 Copier le code (\(error.code))")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        .padding(.horizontal, PrismSpacing.m)
                        .padding(.vertical, PrismSpacing.s)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#f1f5f9",
                        lipHex: "#cbd5e1",
                        cornerRadius: PrismRadius.m,
                        lipDepth: FigMetrics.three
                    )
                )

                Button(action: onOpenRegistry) {
                    Text(verbatim: "🛠️ Registre des erreurs (\(CertiGoErrorCode.allCases.count) codes)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .padding(.horizontal, PrismSpacing.m)
                        .padding(.vertical, PrismSpacing.s)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#0078d4",
                        lipHex: "#005a9e",
                        cornerRadius: PrismRadius.m,
                        lipDepth: FigMetrics.three
                    )
                )
            }
        }
        .padding(PrismSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                .fill(PrismColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                .strokeBorder(PrismColor.figmaHex("#f59e0b"), lineWidth: PrismBorder.standard)
        )
        .accessibilityIdentifier("diagnostic-error-card-\(error.code)")
    }
}

// MARK: - 6. Full-Screen Interactive Lesson Session Modal (`15 ➔ Exercices ➔ 18/04 ➔ 05/20 ➔ 19 Célébration`)

public struct CertiGoNativeLessonSessionModalView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var appState: CertiGoNativeAppState
    public let onCompleteSession: () -> Void
    public let onJumpToAIHubWithTopic: (String) -> Void

    public init(
        appState: Binding<CertiGoNativeAppState>,
        onCompleteSession: @escaping () -> Void,
        onJumpToAIHubWithTopic: @escaping (String) -> Void
    ) {
        self._appState = appState
        self.onCompleteSession = onCompleteSession
        self.onJumpToAIHubWithTopic = onJumpToAIHubWithTopic
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            if appState.lessonSession.hasTriggeredOutOfHeartsFailure {
                stepFailedOutOfHeartsView
            } else if appState.lessonSession.isSessionCompleted {
                celebrationScreen19View
            } else {
                VStack(spacing: .zero) {
                    sessionTopHeaderBar

                    if appState.lessonSession.isShowingDeclicCard15 {
                        declicCard15ScrollView
                    } else {
                        exerciseActiveContentScrollView
                            .id(appState.lessonSession.currentExercise.id)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                )
                            )
                    }
                }
            }

            if !appState.lessonSession.hasTriggeredOutOfHeartsFailure
                && !appState.lessonSession.isSessionCompleted
                && !appState.lessonSession.isShowingDeclicCard15
            {
                let isShowingBottomModalSheet: Bool = {
                    switch appState.lessonSession.attemptPhase {
                    case .explainingError, .comparingServices:
                        return true
                    case .answering, .checked:
                        return false
                    }
                }()

                if isShowingBottomModalSheet {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea(.all)
                        .onTapGesture {
                            withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                                appState.lessonSession.closeOverlaySheetToCheckedState()
                            }
                        }
                        .transition(.opacity)
                        .zIndex(10)
                }

                switch appState.lessonSession.attemptPhase {
                case .answering:
                    verifierBottomBar
                case .checked(let isCorrect):
                    feedbackDrawer18Or04(isCorrect: isCorrect)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .explainingError:
                    explanationSheet05Overlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(11)
                case .comparingServices:
                    comparatorSheet20Overlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(11)
                }
            }
        }
        .fontDesign(.rounded)
        .background(PrismColor.figmaHex("#f8fafc").ignoresSafeArea())
    }

    private var sessionTopHeaderBar: some View {
        HStack(spacing: PrismSpacing.m) {
            Button {
                appState.heartsCount = appState.lessonSession.heartsCount
                appState.lastLostHeartIndex = appState.lessonSession.lastLostHeartIndex
                appState.isPresentingLessonSession = false
                if let returnTab = appState.returnTabAfterLessonSession {
                    appState.selectedTab = returnTab
                    appState.returnTabAfterLessonSession = nil
                }
            } label: {
                Text(verbatim: "✕")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                    .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("session-close-button")

            // Duolingo-style thick rounded progress bar with inner white/light-green top highlight pill
            GeometryReader { barGeo in
                let rawRatio = CGFloat(appState.lessonSession.conceptMasteryProgressRatio)
                let safeRatio = rawRatio.isFinite ? min(max(rawRatio, 0), 1) : 0
                let safeWidth = barGeo.size.width.isFinite ? max(FigMetrics.twenty, barGeo.size.width * safeRatio) : FigMetrics.twenty

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                        .fill(PrismColor.figmaHex("#e2e8f0"))

                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                            .fill(PrismColor.figmaHex("#58cc02"))

                        Capsule()
                            .fill(PrismColor.figmaHex("#ffffff:38"))
                            .frame(width: max(FigMetrics.eight, safeWidth - FigMetrics.twelve), height: FigMetrics.four)
                            .offset(y: FigMetrics.three)
                    }
                    .frame(width: safeWidth)
                    .animation(
                        CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion),
                        value: safeRatio
                    )
                }
            }
            .frame(height: FigMetrics.sixteen)

            // 5 Aligned Zelda Hearts (`❤️❤️❤️❤️❤️`) with elastic heart-shatter animation on every wrong answer!
            CertiGoZeldaHeartsRowView(
                heartsCount: appState.lessonSession.heartsCount,
                justLostHeartIndex: appState.lessonSession.lastLostHeartIndex,
                animationTrigger: appState.lessonSession.heartLossAnimationTrigger,
                heartSize: FigMetrics.thirteen
            )
            .accessibilityIdentifier("session-zelda-hearts-row")
        }
        .padding(.horizontal, PrismSpacing.l)
        .padding(.vertical, PrismSpacing.m)
        .background(PrismColor.surface)
    }

    private var declicCard15ScrollView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                HStack(alignment: .center, spacing: PrismSpacing.m) {
                    CertiGoMascotView(pose: .emotionAhaIdea, size: PrismSize.mascotQuiz)

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: "💡 CARTE DÉCLIC · \(appState.activeRouteCode)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Text(verbatim: appState.lessonSession.declicTitle)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(PrismSpacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(PrismColor.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#cbd5e1"), lineWidth: PrismBorder.standard)
                    )
                }

                // True visual connected-box architecture diagram + Before/After comparison
                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    Text(verbatim: "SCHÉMA D'ARCHITECTURE · \(appState.lessonSession.lessonTitle.uppercased())")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))

                    VStack(spacing: PrismSpacing.xs) {
                        declicArchitectureNodeBox(
                            icon: "🏛️",
                            title: "Management Group",
                            subtitle: "Gouvernance & Stratégies multi-abonnements",
                            borderHex: "#93c5fd",
                            bgHex: "#eff6ff",
                            textHex: "#1e3a8a"
                        )
                        Text(verbatim: "↓")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        declicArchitectureNodeBox(
                            icon: "🔑",
                            title: "Subscription",
                            subtitle: "Périmètre de facturation & quotas",
                            borderHex: "#60a5fa",
                            bgHex: "#f0f9ff",
                            textHex: "#0f172a"
                        )
                        Text(verbatim: "↓")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        declicArchitectureNodeBox(
                            icon: "📦",
                            title: "Resource Group [🔒 Verrou CanNotDelete]",
                            subtitle: "Cycle de vie commun · Protection anti-suppression",
                            borderHex: "#34d399",
                            bgHex: "#ecfdf5",
                            textHex: "#065f46"
                        )
                        Text(verbatim: "↓")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#10b981"))
                        declicArchitectureNodeBox(
                            icon: "☁️",
                            title: "Ressources Cloud [👤 Rôle RBAC Reader]",
                            subtitle: "VMs, Key Vault, VNet, SQL & Stockage isolés",
                            borderHex: "#cbd5e1",
                            bgHex: "#f8fafc",
                            textHex: "#334155"
                        )
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        HStack(alignment: .top, spacing: PrismSpacing.s) {
                            Text(verbatim: "AVANT")
                                .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#dc2626"))
                                .padding(.horizontal, PrismSpacing.xs)
                                .padding(.vertical, PrismSpacing.xxs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                                        .fill(PrismColor.figmaHex("#fee2e2"))
                                )
                            Text(verbatim: appState.lessonSession.declicDiagramTop)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium", monospaced: true))
                                .foregroundStyle(PrismColor.figmaHex("#991b1b"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(PrismSpacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.figmaHex("#fff1f2"))
                        )

                        HStack(alignment: .top, spacing: PrismSpacing.s) {
                            Text(verbatim: "APRÈS")
                                .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#15803d"))
                                .padding(.horizontal, PrismSpacing.xs)
                                .padding(.vertical, PrismSpacing.xxs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                                        .fill(PrismColor.figmaHex("#dcfce7"))
                                )
                            Text(verbatim: appState.lessonSession.declicDiagramBottom)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium", monospaced: true))
                                .foregroundStyle(PrismColor.figmaHex("#166534"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(PrismSpacing.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.figmaHex("#f0fdf4"))
                        )
                    }
                }
                .padding(PrismSpacing.l)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                        .fill(PrismColor.surface)
                )

                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    declicStepRow(
                        title: appState.lessonSession.declicStep1,
                        detail: appState.lessonSession.declicStep2
                    )
                    declicStepRow(
                        title: "💡 Règle d'or pour l'examen \(appState.activeRouteCode)",
                        detail: appState.lessonSession.declicRule
                    )
                }

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion)) {
                        appState.lessonSession.dismissDeclicCard15()
                    }
                } label: {
                    Text(verbatim: "CONTINUER VERS LES EXERCICES")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#58cc02",
                        lipHex: "#46a302",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("declic15-continue-button")
            }
            .padding(PrismSpacing.l)
        }
    }

    private func declicArchitectureNodeBox(
        icon: String,
        title: String,
        subtitle: String,
        borderHex: String,
        bgHex: String,
        textHex: String
    ) -> some View {
        HStack(spacing: PrismSpacing.m) {
            Text(verbatim: icon)
                .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Regular"))
                .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                        .fill(PrismColor.surface)
                )

            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                Text(verbatim: title)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex(textHex))
                Text(verbatim: subtitle)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
            }
            Spacer(minLength: PrismSpacing.xs)
        }
        .padding(.horizontal, PrismSpacing.m)
        .padding(.vertical, PrismSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                .fill(PrismColor.figmaHex(bgHex))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                .strokeBorder(PrismColor.figmaHex(borderHex), lineWidth: PrismBorder.standard)
        )
    }

    private func declicStepRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
            Text(verbatim: title)
                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
            Text(verbatim: detail)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                .foregroundStyle(PrismColor.figmaHex("#475569"))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(PrismSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                .fill(PrismColor.surface)
        )
    }

    private var exerciseActiveContentScrollView: some View {
        let ex = appState.lessonSession.currentExercise
        let twoColumnGrid = [
            GridItem(.flexible(), spacing: PrismSpacing.m),
            GridItem(.flexible(), spacing: PrismSpacing.m)
        ]
        let chapterPillTitle = appState.lessonSession.lessonTitle.isEmpty
            ? ex.conceptTitle
            : appState.lessonSession.lessonTitle

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                // Adaptive Replay Badge (Duolingo Mobbin `3c700cfa` style when reviewing a missed concept!)
                if ex.isReviewReplay {
                    HStack(spacing: PrismSpacing.xs) {
                        Text(verbatim: "🔄 ERREUR PRÉCÉDENTE · À REVOIR : \(ex.conceptTitle)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#b45309"))
                        Spacer()
                        Text(verbatim: "Maîtrise : \(appState.lessonSession.conceptMasteryPercent)%")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    .padding(.horizontal, PrismSpacing.m)
                    .padding(.vertical, PrismSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .fill(PrismColor.figmaHex("#fef3c7"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#f59e0b"), lineWidth: PrismBorder.standard)
                    )
                    .accessibilityIdentifier("session-review-replay-badge")
                }

                // Centered Chapter Pill OUTSIDE and ABOVE the Mascot + Speech Bubble (Figma `73:332` / `73:393`)
                HStack {
                    Spacer(minLength: .zero)
                    Text(verbatim: "⚡ \(chapterPillTitle)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        .padding(.horizontal, PrismSpacing.m)
                        .padding(.vertical, FigMetrics.six)
                        .background(
                            Capsule()
                                .fill(PrismColor.figmaHex("#eff6ff"))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(PrismColor.figmaHex("#bfdbfe"), lineWidth: PrismBorder.thin)
                        )
                        .accessibilityIdentifier("session-chapter-pill")
                    Spacer(minLength: .zero)
                }

                // Mascot (68pt top-aligned) + Clean Speech Bubble with top-aligned left pointer `◀` and structured scenario/question
                HStack(alignment: .top, spacing: PrismSpacing.s) {
                    CertiGoMascotView(pose: ex.mascotPose, size: FigMetrics.sixtyEight)
                        .padding(.top, FigMetrics.four)

                    HStack(alignment: .top, spacing: .zero) {
                        Text(verbatim: "◀")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#cbd5e1"))
                            .padding(.top, FigMetrics.eighteen)
                            .offset(x: FigMetrics.two)

                        CertiGoStructuredPromptView(prompt: ex.prompt)
                            .padding(PrismSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: PrismRadius.mascotBubble, style: .continuous)
                                        .fill(PrismColor.figmaHex("#e2e8f0"))
                                        .offset(y: FigMetrics.four)
                                    RoundedRectangle(cornerRadius: PrismRadius.mascotBubble, style: .continuous)
                                        .fill(PrismColor.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PrismRadius.mascotBubble, style: .continuous)
                                                .strokeBorder(PrismColor.figmaHex("#cbd5e1"), lineWidth: PrismBorder.standard)
                                        )
                                }
                            )
                    }
                }

                if ex.formatCode == "Q_TYPE_02" {
                    LazyVGrid(columns: twoColumnGrid, spacing: PrismSpacing.m) {
                        ForEach(ex.options) { opt in
                            serviceGridOptionCard(opt)
                        }
                    }
                } else if ex.formatCode == "Q_TYPE_03" {
                    architectureSlotDiagramBox
                    VStack(spacing: PrismSpacing.m) {
                        ForEach(ex.options) { opt in
                            standard3DOptionCard(opt, isMultiChoice: false)
                        }
                    }
                } else if ex.formatCode == "Q_TYPE_04" {
                    cliKeyboardExerciseBox(ex)
                } else if ex.formatCode == "Q_TYPE_05" {
                    wordBankBuilderBox(ex)
                } else {
                    VStack(spacing: PrismSpacing.m) {
                        ForEach(ex.options) { opt in
                            standard3DOptionCard(opt, isMultiChoice: ex.formatCode == "Q_TYPE_10")
                        }
                    }
                }
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.m)
            .padding(.bottom, FigMetrics.twoHundredForty)
        }
    }

    private func optionVisualPalette(for opt: CertiGoNativeExerciseItem.OptionItem) -> (face: String, lip: String, text: String, badgeBg: String) {
        let isSelected = appState.lessonSession.selectedOptionIds.contains(opt.id)
        switch appState.lessonSession.attemptPhase {
        case .answering:
            if isSelected {
                return ("#ddf4ff", "#1cb0f6", "#0284c7", "#1cb0f6")
            }
            return ("#ffffff", "#e5e5e5", "#334155", "#f1f5f9")
        case .checked, .explainingError, .comparingServices:
            if opt.isCorrect {
                return ("#d7ffb8", "#58cc02", "#3f7d00", "#58cc02")
            }
            if isSelected && !opt.isCorrect {
                return ("#ffdfe0", "#ff4b4b", "#ea2b2b", "#ff4b4b")
            }
            return ("#ffffff", "#e5e5e5", "#64748b", "#f1f5f9")
        }
    }

    private func standard3DOptionCard(_ opt: CertiGoNativeExerciseItem.OptionItem, isMultiChoice: Bool) -> some View {
        let palette = optionVisualPalette(for: opt)
        let isSelected = appState.lessonSession.selectedOptionIds.contains(opt.id)

        return Button {
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                appState.lessonSession.selectOption(opt.id)
            }
        } label: {
            HStack(alignment: .top, spacing: PrismSpacing.m) {
                Text(verbatim: isMultiChoice && isSelected ? "✓" : opt.badge)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                    .foregroundStyle(
                        (isSelected || palette.badgeBg != "#f1f5f9")
                            ? PrismColor.onAccent
                            : PrismColor.figmaHex("#64748b")
                    )
                    .frame(width: PrismSize.optionBadge, height: PrismSize.optionBadge)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .fill(PrismColor.figmaHex(palette.badgeBg))
                    )

                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: opt.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Medium"))
                        .foregroundStyle(PrismColor.figmaHex(palette.text))
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let sub = opt.subtitle {
                        Text(verbatim: sub)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: PrismSpacing.xs)
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.vertical, PrismSpacing.m)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(
            CertiGoTactile3DButtonStyle(
                faceHex: palette.face,
                lipHex: palette.lip,
                strokeHex: palette.lip,
                cornerRadius: PrismRadius.l,
                lipDepth: FigMetrics.four
            )
        )
        .accessibilityIdentifier("exercise-option-\(opt.id)")
    }

    private func serviceGridOptionCard(_ opt: CertiGoNativeExerciseItem.OptionItem) -> some View {
        let palette = optionVisualPalette(for: opt)
        return Button {
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                appState.lessonSession.selectOption(opt.id)
            }
        } label: {
            VStack(spacing: PrismSpacing.s) {
                if let assetName = opt.assetName {
                    Image(assetName, bundle: .module)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                }
                Text(verbatim: opt.title)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Medium"))
                    .foregroundStyle(PrismColor.figmaHex(palette.text))
                    .lineSpacing(2)
                    .multilineTextAlignment(.center)
                if let sub = opt.subtitle {
                    Text(verbatim: sub)
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Regular"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(PrismSpacing.l)
            .frame(maxWidth: .infinity)
            .frame(height: FigMetrics.oneHundredForty)
        }
        .buttonStyle(
            CertiGoTactile3DButtonStyle(
                faceHex: palette.face,
                lipHex: palette.lip,
                strokeHex: palette.lip,
                cornerRadius: PrismRadius.l,
                lipDepth: FigMetrics.five
            )
        )
        .accessibilityIdentifier("exercise-grid-option-\(opt.id)")
    }

    private var architectureSlotDiagramBox: some View {
        let selectedTitle = appState.lessonSession.currentExercise.options
            .first(where: { appState.lessonSession.selectedOptionIds.contains($0.id) })?.title ?? "[ ? Couche 7 + WAF ]"

        return HStack(spacing: PrismSpacing.s) {
            VStack(spacing: PrismSpacing.xxs) {
                Text(verbatim: "🌐")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                Text(verbatim: "Clients HTTPS")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Extra Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#334155"))
            }
            .frame(maxWidth: .infinity)

            Text(verbatim: "➔")
                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#0078d4"))

            Text(verbatim: selectedTitle)
                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                .multilineTextAlignment(.center)
                .padding(PrismSpacing.s)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .fill(PrismColor.figmaHex("#e0f2fe"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#0284c7"), lineWidth: PrismBorder.standard)
                )

            Text(verbatim: "➔")
                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#0078d4"))

            VStack(spacing: PrismSpacing.xxs) {
                Text(verbatim: "🛡️")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                Text(verbatim: "VNet Privé")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Extra Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#334155"))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(PrismSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                .fill(PrismColor.surface)
        )
    }

    private func cliKeyboardExerciseBox(_ ex: CertiGoNativeExerciseItem) -> some View {
        VStack(alignment: .leading, spacing: PrismSpacing.m) {
            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                Text(verbatim: "TERMINAL AZURE CLOUD SHELL")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#38bdf8"))

                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    HStack(spacing: PrismSpacing.s) {
                        Text(verbatim: "$ \(ex.cliPrefix ?? "az group")")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold", monospaced: true))
                            .foregroundStyle(PrismColor.onAccent)

                        TextField(
                            text: $appState.lessonSession.cliInputText,
                            prompt: Text(verbatim: "...")
                        ) {
                            Text(verbatim: "...")
                        }
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#38bdf8"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, PrismSpacing.s)
                        .frame(minWidth: FigMetrics.ninetySix, maxWidth: FigMetrics.oneHundredForty, minHeight: FigMetrics.thirtySix)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .fill(PrismColor.figmaHex("#1e293b"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#38bdf8"), lineWidth: PrismBorder.standard)
                        )
                        .accessibilityIdentifier("session-cli-textfield")

                        Text(verbatim: "\\")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular", monospaced: true))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    }

                    Text(verbatim: "  \(ex.cliSuffix ?? "create --lock-type CanNotDelete -n LockProd -g RG-Prod")")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#cbd5e1"))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(PrismSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#0f172a"))
            )

            Text(verbatim: "SUGGESTIONS RAPIDES CLI :")
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#64748b"))

            HStack(spacing: PrismSpacing.s) {
                ForEach(ex.cliSuggestionBricks, id: \.self) { brick in
                    let isChosen = appState.lessonSession.cliInputText.lowercased() == brick.lowercased()
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.lessonSession.cliInputText = brick
                        }
                    } label: {
                        Text(verbatim: brick)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black", monospaced: true))
                            .foregroundStyle(isChosen ? PrismColor.figmaHex("#0284c7") : PrismColor.figmaHex("#0f172a"))
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.s)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: isChosen ? "#ddf4ff" : "#ffffff",
                            lipHex: isChosen ? "#1cb0f6" : "#cbd5e1",
                            strokeHex: isChosen ? "#1cb0f6" : "#cbd5e1",
                            cornerRadius: PrismRadius.m,
                            lipDepth: FigMetrics.four
                        )
                    )
                }
            }
        }
    }

    private func wordBankBuilderBox(_ ex: CertiGoNativeExerciseItem) -> some View {
        let twoCols = [
            GridItem(.flexible(), spacing: PrismSpacing.s),
            GridItem(.flexible(), spacing: PrismSpacing.s)
        ]
        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                Text(verbatim: "COMMANDE ASSEMBLÉE (TOUCHE UNE BRIQUE POUR RETIRER)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#38bdf8"))

                if appState.lessonSession.assembledWordBankTokens.isEmpty {
                    Text(verbatim: "$ Sélectionne les briques CLI ci-dessous dans l'ordre...")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        .padding(.vertical, PrismSpacing.m)
                } else {
                    LazyVGrid(columns: twoCols, spacing: PrismSpacing.xs) {
                        ForEach(appState.lessonSession.assembledWordBankTokens, id: \.self) { token in
                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                    appState.lessonSession.toggleWordBankBrick(token)
                                }
                            } label: {
                                Text(verbatim: token)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black", monospaced: true))
                                    .foregroundStyle(PrismColor.figmaHex("#38bdf8"))
                                    .padding(.horizontal, PrismSpacing.s)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                            .fill(PrismColor.figmaHex("#1e293b"))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#0f172a"))
            )

            Text(verbatim: "BRIQUES DISPONIBLES :")
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#64748b"))

            LazyVGrid(columns: twoCols, spacing: PrismSpacing.s) {
                ForEach(ex.wordBankAllBricks, id: \.self) { brick in
                    let isPlaced = appState.lessonSession.assembledWordBankTokens.contains(brick)
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.lessonSession.toggleWordBankBrick(brick)
                        }
                    } label: {
                        Text(verbatim: brick)
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black", monospaced: true))
                            .foregroundStyle(
                                isPlaced ? PrismColor.figmaHex("#94a3b8") : PrismColor.figmaHex("#0f172a")
                            )
                            .padding(.vertical, PrismSpacing.m)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: isPlaced ? "#f1f5f9" : "#ffffff",
                            lipHex: isPlaced ? "#e2e8f0" : "#cbd5e1",
                            strokeHex: "#cbd5e1",
                            cornerRadius: PrismRadius.m,
                            lipDepth: isPlaced ? FigMetrics.one : FigMetrics.four
                        )
                    )
                }
            }
        }
    }

    private var verifierBottomBar: some View {
        let canVerify = appState.lessonSession.canCheckCurrentExercise
        return VStack(spacing: .zero) {
            Divider()
            Button {
                guard canVerify else { return }
                withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                    _ = appState.lessonSession.verifyCurrentAnswer()
                    appState.heartsCount = appState.lessonSession.heartsCount
                    appState.lastLostHeartIndex = appState.lessonSession.lastLostHeartIndex
                    appState.heartLossAnimationTrigger = appState.lessonSession.heartLossAnimationTrigger
                }
            } label: {
                Text(verbatim: "VÉRIFIER")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Black"))
                    .foregroundStyle(canVerify ? PrismColor.onAccent : PrismColor.figmaHex("#afafaf"))
                    .frame(maxWidth: .infinity)
                    .frame(height: PrismSize.primaryButtonHeight)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: canVerify ? "#58cc02" : "#e5e5e5",
                    lipHex: canVerify ? "#46a302" : "#cbd5e1",
                    cornerRadius: PrismRadius.l,
                    lipDepth: canVerify ? FigMetrics.five : FigMetrics.two
                )
            )
            .disabled(!canVerify)
            .padding(PrismSpacing.l)
            .background(PrismColor.surface)
            .accessibilityIdentifier("session-verifier-button")
        }
    }

    private func feedbackDrawer18Or04(isCorrect: Bool) -> some View {
        let bgHex = isCorrect ? "#d7ffb8" : "#ffdfe0"
        let titleHex = isCorrect ? "#3f7d00" : "#ea2b2b"
        let primaryFaceHex = isCorrect ? "#58cc02" : "#ff4b4b"
        let primaryLipHex = isCorrect ? "#46a302" : "#d93838"

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                Text(verbatim: isCorrect ? "✓  Excellent !" : "✕  Incorrect")
                    .font(PrismTypography.figmaFont(size: FigMetrics.seventeen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex(titleHex))

                if isCorrect {
                    Text(verbatim: "+15 XP · Concept validé du premier coup")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                        .foregroundStyle(PrismColor.figmaHex("#3f7d00"))
                } else {
                    Text(verbatim: "Bonne réponse : \(appState.lessonSession.currentExercise.primaryCorrectOptionTitle)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Medium"))
                        .foregroundStyle(PrismColor.figmaHex("#991b1b"))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: PrismSpacing.m) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        if isCorrect {
                            appState.lessonSession.openServiceComparatorSheet20()
                        } else {
                            appState.lessonSession.openErrorExplanationSheet05()
                        }
                    }
                } label: {
                    Text(verbatim: isCorrect ? "✦ EXPLIQUER MA RÉPONSE" : "✦ EXPLIQUER MON ERREUR")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex(titleHex))
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.fortyEight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#ffffff",
                        lipHex: "#cbd5e1",
                        strokeHex: "#cbd5e1",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("session-explain-ai-button")

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion)) {
                        appState.lessonSession.advanceToNextExerciseOrFinish()
                    }
                } label: {
                    Text(verbatim: "CONTINUER")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.fortyEight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: primaryFaceHex,
                        lipHex: primaryLipHex,
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("session-continue-button")
            }
        }
        .padding(PrismSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.sheet, style: .continuous)
                .fill(PrismColor.figmaHex(bgHex))
        )
    }

    private var explanationSheet05Overlay: some View {
        let ex = appState.lessonSession.currentExercise
        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            HStack {
                Text(verbatim: "✦ Explication de ta réponse")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.lessonSession.closeOverlaySheetToCheckedState()
                    }
                } label: {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                Text(verbatim: "✕ TA RÉPONSE : \(appState.lessonSession.selectedOptionSummaryText)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#e11d48"))
                Text(verbatim: appState.lessonSession.selectedWhyWrongExplanation)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#881337"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#fff1f2"))
            )

            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                Text(verbatim: "✓ BONNE RÉPONSE : \(ex.primaryCorrectOptionTitle)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#15803d"))
                Text(verbatim: appState.lessonSession.correctWhyRightExplanation)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#14532d"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#f0fdf4"))
            )

            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                Text(verbatim: "💡 ASTUCE D'EXAMEN")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                Text(verbatim: ex.examTip)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#1e3a8a"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#eff6ff"))
            )

            HStack(spacing: PrismSpacing.m) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.lessonSession.openServiceComparatorSheet20()
                    }
                } label: {
                    Text(verbatim: "✦ Comparer (20)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.fortyEight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#eff6ff",
                        lipHex: "#93c5fd",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion)) {
                        appState.lessonSession.advanceToNextExerciseOrFinish()
                    }
                } label: {
                    Text(verbatim: "CONTINUER")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.fortyEight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#58cc02",
                        lipHex: "#46a302",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("sheet05-continue-button")
            }
        }
        .padding(PrismSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.sheet, style: .continuous)
                .fill(PrismColor.surface)
        )
        .padding(.horizontal, PrismSpacing.m)
        .padding(.bottom, PrismSpacing.m)
    }

    private var comparatorSheet20Overlay: some View {
        let ex = appState.lessonSession.currentExercise
        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            HStack {
                Text(verbatim: "←   Comparer 2 services \(appState.activeRouteCode)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Spacer()
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.lessonSession.closeOverlaySheetToCheckedState()
                    }
                } label: {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: PrismSpacing.s) {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: ex.comparisonLeftTitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                    ForEach(ex.comparisonLeftBullets, id: \.self) { bullet in
                        Text(verbatim: "• \(bullet)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#334155"))
                    }
                }
                .padding(PrismSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.figmaHex("#f8fafc"))
                )

                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    Text(verbatim: ex.comparisonRightTitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                    ForEach(ex.comparisonRightBullets, id: \.self) { bullet in
                        Text(verbatim: "• \(bullet)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#166534"))
                    }
                }
                .padding(PrismSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.figmaHex("#f0fdf4"))
                )
            }

            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                Text(verbatim: "✓ RÈGLE D'OR POUR L'EXAMEN \(appState.activeRouteCode)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#15803d"))
                Text(verbatim: ex.comparisonGoldenRule)
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#14532d"))
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#dcfce7"))
            )

            Button {
                withAnimation(CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion)) {
                    appState.lessonSession.advanceToNextExerciseOrFinish()
                }
            } label: {
                Text(verbatim: "CONTINUER LA SÉANCE")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                    .foregroundStyle(PrismColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: FigMetrics.fortyEight)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: "#58cc02",
                    lipHex: "#46a302",
                    cornerRadius: PrismRadius.l
                )
            )
        }
        .padding(PrismSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.sheet, style: .continuous)
                .fill(PrismColor.surface)
        )
        .padding(.horizontal, PrismSpacing.m)
        .padding(.bottom, PrismSpacing.m)
    }

    /// Duolingo Flow `971343d0` ("Run out of hearts") screen shown when the user makes 5 errors (`heartsCount == 0`), blocking step completion!
    private var stepFailedOutOfHeartsView: some View {
        VStack(spacing: PrismSpacing.xl) {
            Spacer()

            CertiGoZeldaHeartsRowView(
                heartsCount: 0,
                justLostHeartIndex: 0,
                animationTrigger: appState.lessonSession.heartLossAnimationTrigger,
                heartSize: FigMetrics.twentyFour
            )
            .padding(.vertical, PrismSpacing.xs)

            CertiGoMascotView(pose: .errorCorrectionEncouraging, size: FigMetrics.oneHundredTwenty)

            VStack(spacing: PrismSpacing.s) {
                Text(verbatim: "Tu n'as plus de cœurs ! 💔 (5 fautes)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#e11d48"))
                    .multilineTextAlignment(.center)

                Text(verbatim: "Tu as fait 5 erreurs sur cette étape. Il faut terminer l'étape avec au moins 1 cœur pour valider tes acquis et débloquer l'étape suivante du parcours.")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PrismSpacing.m)
            }

            VStack(spacing: PrismSpacing.m) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion)) {
                        appState.restartFailedLessonSessionWithFullHearts()
                    }
                } label: {
                    Text(verbatim: "🔄 Recommencer cette étape (5 ❤️ neufs)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#58cc02",
                        lipHex: "#46a302",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("failed-hearts-restart-step-button")

                if appState.gemsCount >= 150 {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion)) {
                            _ = appState.refillHeartsWithGems()
                            appState.restartFailedLessonSessionWithFullHearts()
                        }
                    } label: {
                        Text(verbatim: "💎 Recharger mes 5 cœurs (150 💎)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#0284c7",
                            lipHex: "#0369a1",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }

                Button {
                    appState.abandonFailedLessonSession()
                } label: {
                    Text(verbatim: "← Retourner au parcours (Étape non débloquée)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.fortyEight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#ffffff",
                        lipHex: "#cbd5e1",
                        strokeHex: "#cbd5e1",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("failed-hearts-return-locked-button")
            }
            .padding(.horizontal, PrismSpacing.l)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PrismColor.figmaHex("#f8fafc"))
    }

    private var celebrationScreen19View: some View {
        VStack(spacing: PrismSpacing.xl) {
            Spacer()

            CertiGoMascotView(pose: .angleFrontCelebration, size: FigMetrics.oneHundredFifty)

            ZStack {
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .fill(PrismColor.figmaHex("#46a302"))
                    .frame(width: FigMetrics.seventySix, height: FigMetrics.seventyTwo)
                    .offset(y: FigMetrics.six)
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .fill(PrismColor.figmaHex("#58cc02"))
                    .frame(width: FigMetrics.seventySix, height: FigMetrics.seventyTwo)
                Text(verbatim: "✓")
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirtyTwo, style: "Black"))
                    .foregroundStyle(PrismColor.onAccent)
            }

            VStack(spacing: PrismSpacing.xs) {
                Text(verbatim: "Étape terminée !")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyEight, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Text(verbatim: "\(appState.lessonSession.lessonTitle) maîtrisé (+15 💎)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
            }

            HStack(spacing: PrismSpacing.m) {
                celebrationStatBox(title: "RYTHME", value: "14 sec ⚡", hex: "#0284c7")
                celebrationStatBox(title: "PRÉCISION", value: "\(appState.lessonSession.accuracyPercent) %", hex: "#58cc02")
                celebrationStatBox(title: "SÉRIE", value: "\(appState.streakDays) j 🔥", hex: "#ea580c")
            }
            .padding(.horizontal, PrismSpacing.l)

            Spacer()

            Button {
                onCompleteSession()
            } label: {
                Text(verbatim: "RETOUR AU PARCOURS (DÉBLOQUER LA SUITE)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Black"))
                    .foregroundStyle(PrismColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: PrismSize.primaryButtonHeight)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: "#58cc02",
                    lipHex: "#46a302",
                    cornerRadius: PrismRadius.l
                )
            )
            .padding(.horizontal, PrismSpacing.l)
            .padding(.bottom, PrismSpacing.xl)
            .accessibilityIdentifier("celebration19-return-to-path")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PrismColor.figmaHex("#f8fafc"))
    }

    private func celebrationStatBox(title: String, value: String, hex: String) -> some View {
        VStack(spacing: PrismSpacing.xs) {
            Text(verbatim: title)
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                .foregroundStyle(PrismColor.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, PrismSpacing.xxs)
                .background(PrismColor.figmaHex(hex))

            Text(verbatim: value)
                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex(hex))
                .padding(.vertical, PrismSpacing.s)
        }
        .frame(maxWidth: .infinity)
        .background(PrismColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                .strokeBorder(PrismColor.figmaHex(hex), lineWidth: PrismBorder.strong)
        )
    }
}

// MARK: - 7. Timed Mock Exam Cockpit (`23`) & Pearson VUE Report `/1000` (`24`)

public struct CertiGoNativeTimedExamCockpit23View: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var appState: CertiGoNativeAppState

    public init(appState: Binding<CertiGoNativeAppState>) {
        self._appState = appState
    }

    public var body: some View {
        let q = appState.currentExamQuestion
        let selectedChoiceId = appState.selectedExamChoiceByQuestionNumber[q.number]
        let isFlagged = appState.flaggedExamQuestionNumbers.contains(q.number)

        return VStack(spacing: .zero) {
            HStack(spacing: PrismSpacing.m) {
                Button {
                    appState.isPresentingTimedExam23 = false
                } label: {
                    Text(verbatim: "✕")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(verbatim: appState.formattedExamCountdown)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black", monospaced: true))
                    .foregroundStyle(PrismColor.onAccent)
                    .padding(.horizontal, PrismSpacing.m)
                    .padding(.vertical, PrismSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                            .fill(PrismColor.figmaHex("#0f172a"))
                    )
                    .accessibilityIdentifier("exam23-countdown-pill")

                Spacer()

                HStack(spacing: PrismSpacing.xs) {
                    Button {
                        appState.showExamNavigatorGridSheet = true
                    } label: {
                        Text(verbatim: "📋 Grille (50)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            .padding(.horizontal, PrismSpacing.s)
                            .padding(.vertical, PrismSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.figmaHex("#eff6ff"))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("exam23-open-grid-navigator")

                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.toggleFlagOnCurrentExamQuestion()
                        }
                    } label: {
                        Text(verbatim: isFlagged ? "🏳 Marquée ✓" : "🏳 Marquer")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(isFlagged ? PrismColor.figmaHex("#b45309") : PrismColor.figmaHex("#475569"))
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(isFlagged ? PrismColor.figmaHex("#fef3c7") : PrismColor.figmaHex("#f1f5f9"))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, PrismSpacing.l)
            .padding(.vertical, PrismSpacing.m)
            .background(PrismColor.surface)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.xs) {
                    ForEach(0..<appState.examQuestions.count, id: \.self) { idx in
                        let item = appState.examQuestions[idx]
                        let isCurrent = idx == appState.currentExamQuestionIndex
                        let isAnswered = appState.selectedExamChoiceByQuestionNumber[item.number] != nil
                        let isItemFlagged = appState.flaggedExamQuestionNumbers.contains(item.number)
                        let pillLabel: String = {
                            if isCurrent { return "\(item.number) / 50" }
                            if isItemFlagged { return "\(item.number) 🏳" }
                            if isAnswered { return "\(item.number) ✓" }
                            return "\(item.number)"
                        }()

                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.currentExamQuestionIndex = idx
                            }
                        } label: {
                            Text(verbatim: pillLabel)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                .foregroundStyle(
                                    isCurrent
                                        ? PrismColor.onAccent
                                        : (isItemFlagged ? PrismColor.figmaHex("#b45309") : (isAnswered ? PrismColor.figmaHex("#15803d") : PrismColor.figmaHex("#475569")))
                                )
                                .padding(.horizontal, PrismSpacing.m)
                                .padding(.vertical, PrismSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .fill(
                                            isCurrent
                                                ? PrismColor.figmaHex("#2563eb")
                                                : (isItemFlagged ? PrismColor.figmaHex("#fef3c7") : (isAnswered ? PrismColor.figmaHex("#dcfce7") : PrismColor.figmaHex("#f1f5f9")))
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.xs)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(PrismColor.surface)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: q.caseStudyBadge)
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#2563eb"))
                        CertiGoStructuredPromptView(prompt: q.stem)
                    }
                    .padding(PrismSpacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.surface)
                    )

                    ForEach(q.choices) { choice in
                        let isSelected = selectedChoiceId == choice.id
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.selectExamChoice(choice.id)
                            }
                        } label: {
                            HStack(alignment: .top, spacing: PrismSpacing.m) {
                                Text(verbatim: choice.badge)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                    .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#475569"))
                                    .frame(width: PrismSize.optionBadge, height: PrismSize.optionBadge)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                            .fill(isSelected ? PrismColor.figmaHex("#2563eb") : PrismColor.figmaHex("#f1f5f9"))
                                    )

                                Text(verbatim: choice.text)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Medium"))
                                    .foregroundStyle(isSelected ? PrismColor.figmaHex("#1e40af") : PrismColor.figmaHex("#0f172a"))
                                    .lineSpacing(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: PrismSpacing.xs)
                            }
                            .padding(.horizontal, PrismSpacing.l)
                            .padding(.vertical, PrismSpacing.m)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(
                            CertiGoTactile3DButtonStyle(
                                faceHex: isSelected ? "#eff6ff" : "#ffffff",
                                lipHex: isSelected ? "#2563eb" : "#cbd5e1",
                                strokeHex: isSelected ? "#3b82f6" : "#e2e8f0",
                                cornerRadius: PrismRadius.l,
                                lipDepth: FigMetrics.four
                            )
                        )
                    }
                }
                .padding(PrismSpacing.l)
                .gesture(
                    DragGesture(minimumDistance: FigMetrics.thirtyTwo)
                        .onEnded { value in
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                if value.translation.width < -FigMetrics.thirtyTwo {
                                    appState.goToNextExamQuestion()
                                } else if value.translation.width > FigMetrics.thirtyTwo {
                                    appState.goToPreviousExamQuestion()
                                }
                            }
                        }
                )
            }
            .background(PrismColor.figmaHex("#f8fafc"))

            HStack(spacing: PrismSpacing.m) {
                Button {
                    if appState.currentExamQuestionIndex > 0 {
                        appState.currentExamQuestionIndex -= 1
                    }
                } label: {
                    Text(verbatim: "← Préc.")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#334155"))
                        .frame(width: FigMetrics.oneHundred, height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#f1f5f9",
                        lipHex: "#cbd5e1",
                        cornerRadius: PrismRadius.l
                    )
                )

                Button {
                    if appState.currentExamQuestionIndex + 1 < appState.examQuestions.count {
                        appState.currentExamQuestionIndex += 1
                    } else {
                        appState.finishTimedExamAndComputeScore()
                    }
                } label: {
                    let isLast = appState.currentExamQuestionIndex + 1 >= appState.examQuestions.count
                    Text(verbatim: isLast ? "TERMINER L'EXAMEN ✓" : "QUESTION SUIVANTE →")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#2563eb",
                        lipHex: "#1d4ed8",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("exam23-next-or-finish-button")

                Button {
                    appState.finishTimedExamAndComputeScore()
                } label: {
                    Text(verbatim: "Terminer")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                        .padding(.horizontal, PrismSpacing.m)
                        .frame(height: PrismSize.primaryButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                .fill(PrismColor.figmaHex("#dcfce7"))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exam23-finish-now-button")
            }
            .padding(PrismSpacing.l)
            .background(PrismColor.surface)
        }
        .fontDesign(.rounded)
        .sheet(isPresented: $appState.showExamNavigatorGridSheet) {
            examNavigatorGridSheetView
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                appState.tickExamTimerOneSecond()
            }
        }
    }

    private var examNavigatorGridSheetView: some View {
        let fourColumns = Array(repeating: GridItem(.flexible(), spacing: PrismSpacing.s), count: 4)
        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                HStack {
                    Text(verbatim: "📋 GRILLE DE NAVIGATION EXAMEN (\(appState.examQuestions.count) Q)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    Spacer()
                    Button {
                        appState.showExamNavigatorGridSheet = false
                    } label: {
                        Text(verbatim: "✕")
                            .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: PrismSpacing.m) {
                    Text(verbatim: "■ En cours")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                    Text(verbatim: "■ Répondue ✓")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                    Text(verbatim: "■ Marquée 🏳")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#b45309"))
                    Text(verbatim: "■ À faire")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }

                LazyVGrid(columns: fourColumns, spacing: PrismSpacing.s) {
                    ForEach(0..<appState.examQuestions.count, id: \.self) { idx in
                        examGridTileButton(index: idx)
                    }
                }
            }
            .padding(PrismSpacing.xl)
        }
        .background(PrismColor.figmaHex("#f8fafc"))
    }

    private func examGridTileButton(index: Int) -> some View {
        let item = appState.examQuestions[index]
        let isCurrent = index == appState.currentExamQuestionIndex
        let isItemFlagged = appState.flaggedExamQuestionNumbers.contains(item.number)
        let isAnswered = appState.selectedExamChoiceByQuestionNumber[item.number] != nil

        let statusText: String = {
            if isCurrent { return "Q\(item.number) ●" }
            if isItemFlagged { return "Q\(item.number) 🏳" }
            if isAnswered { return "Q\(item.number) ✓" }
            return "Q\(item.number)"
        }()
        let faceHex: String = {
            if isCurrent { return "#1d4ed8" }
            if isItemFlagged { return "#fef3c7" }
            if isAnswered { return "#e0f2fe" }
            return "#f1f5f9"
        }()
        let lipHex: String = {
            if isCurrent { return "#1e3a8a" }
            if isItemFlagged { return "#f59e0b" }
            if isAnswered { return "#38bdf8" }
            return "#cbd5e1"
        }()
        let textHex: String = {
            if isCurrent { return "#ffffff" }
            if isItemFlagged { return "#b45309" }
            if isAnswered { return "#0369a1" }
            return "#475569"
        }()

        return Button {
            appState.jumpToExamQuestion(at: index)
        } label: {
            Text(verbatim: statusText)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex(textHex))
                .frame(maxWidth: .infinity)
                .frame(height: FigMetrics.fortyFour)
        }
        .buttonStyle(
            CertiGoTactile3DButtonStyle(
                faceHex: faceHex,
                lipHex: lipHex,
                cornerRadius: PrismRadius.m,
                lipDepth: FigMetrics.three
            )
        )
    }
}

public struct CertiGoNativeExamReport24View: View {
    @Binding public var appState: CertiGoNativeAppState
    public let onExplainErrorsWithAI: () -> Void

    public init(
        appState: Binding<CertiGoNativeAppState>,
        onExplainErrorsWithAI: @escaping () -> Void
    ) {
        self._appState = appState
        self.onExplainErrorsWithAI = onExplainErrorsWithAI
    }

    public var body: some View {
        let score = appState.lastComputedExamScoreOutOf1000
        let passed = score >= 700
        let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: appState.activeRouteCode)

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PrismSpacing.l) {
                TabView(selection: $appState.examReportCarouselIndex) {
                    VStack(spacing: PrismSpacing.m) {
                        Text(verbatim: passed ? "✓ EXAMEN RÉUSSI · +\(max(0, score - 700)) PTS AU-DESSUS DU SEUIL" : "⚠️ SOUS LE SEUIL OFFICIEL (700)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#86efac"))

                        HStack(alignment: .firstTextBaseline, spacing: PrismSpacing.xs) {
                            Text(verbatim: "\(score)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fortyEight, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                            Text(verbatim: "/ 1000")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                        }

                        GeometryReader { geo in
                            let rawRatio = CGFloat(score) / 1000.0
                            let safeRatio = rawRatio.isFinite ? min(max(rawRatio, 0.1), 1.0) : 0.1
                            let safeWidth = geo.size.width.isFinite ? max(0, geo.size.width * safeRatio) : 0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .fill(PrismColor.figmaHex("#1e293b"))
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .fill(PrismColor.figmaHex(passed ? "#22c55e" : "#f59e0b"))
                                    .frame(width: safeWidth)
                            }
                        }
                        .frame(height: PrismSize.barometerTrackHeight)

                        HStack {
                            Text(verbatim: "0")
                            Spacer()
                            Text(verbatim: "Seuil 700")
                            Spacer()
                            Text(verbatim: "1000")
                        }
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                    }
                    .padding(PrismSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.figmaHex("#0f172a"))
                    )
                    .tag(0)

                    VStack(spacing: PrismSpacing.m) {
                        Text(verbatim: "⏱ RYTHME CHRONO & CALIBRATION PEARSON VUE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#38bdf8"))
                        Text(verbatim: "38 min · 45 sec / question")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                        Text(verbatim: "Indice de confiance : 91 % de tes réponses marquées « Sûr » étaient exactes.")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#cbd5e1"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(PrismSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.figmaHex("#0f172a"))
                    )
                    .tag(1)

                    VStack(spacing: PrismSpacing.m) {
                        Text(verbatim: "🎯 ANALYSE DES ERREURS & RELANCE COACH IA")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#facc15"))
                        Text(verbatim: "Priorité : Réseaux Hybrides & WAF")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                            .foregroundStyle(PrismColor.onAccent)
                        Text(verbatim: "Gagne +65 pts en révisant VNet Peering et Private Endpoint DNS avec le Coach IA.")
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#cbd5e1"))
                            .multilineTextAlignment(.center)
                    }
                    .padding(PrismSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                            .fill(PrismColor.figmaHex("#0f172a"))
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: FigMetrics.twoHundredTwenty)

                HStack(spacing: PrismSpacing.xs) {
                    ForEach(0..<3, id: \.self) { dotIdx in
                        let isCurrent = appState.examReportCarouselIndex == dotIdx
                        RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                            .fill(PrismColor.figmaHex(isCurrent ? "#0078d4" : "#cbd5e1"))
                            .frame(
                                width: isCurrent ? PrismSize.carouselDotActive : PrismSize.carouselDotInactive,
                                height: PrismSize.carouselDotInactive
                            )
                            .onTapGesture {
                                appState.examReportCarouselIndex = dotIdx
                            }
                    }
                }

                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    Text(verbatim: "SCORE PAR DOMAINE OFFICIEL \(appState.activeRouteCode)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))

                    ForEach(0..<curriculum.examDomains.count, id: \.self) { domIdx in
                        let dom = curriculum.examDomains[domIdx]
                        HStack {
                            Text(verbatim: dom.title)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            Spacer()
                            Text(verbatim: dom.scorePercent)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex(dom.colorHex))
                        }
                    }
                }
                .padding(PrismSpacing.l)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                        .fill(PrismColor.surface)
                )

                Button {
                    appState.showExamDetailedCorrectionSheet = true
                } label: {
                    Text(verbatim: "🔍 Voir le corrigé détaillé question par question")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        .frame(maxWidth: .infinity)
                        .frame(height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#eff6ff",
                        lipHex: "#93c5fd",
                        strokeHex: "#93c5fd",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("report24-open-detailed-correction")

                Button {
                    onExplainErrorsWithAI()
                } label: {
                    Text(verbatim: "✦ EXPLIQUER MES ERREURS AVEC L'IA")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: PrismSize.primaryButtonHeight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#7c3aed",
                        lipHex: "#5b21b6",
                        cornerRadius: PrismRadius.l
                    )
                )
                .accessibilityIdentifier("report24-explain-errors-ai")

                Button {
                    appState.isPresentingExamReport24 = false
                } label: {
                    Text(verbatim: "Retour au Centre d'Examen")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))
                        .padding(.vertical, PrismSpacing.s)
                }
                .buttonStyle(.plain)
            }
            .padding(PrismSpacing.l)
        }
        .fontDesign(.rounded)
        .background(PrismColor.figmaHex("#f8fafc").ignoresSafeArea())
        .sheet(isPresented: $appState.showExamDetailedCorrectionSheet) {
            examDetailedCorrectionSheetView
        }
    }

    private var examDetailedCorrectionSheetView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                HStack {
                    Text(verbatim: "🔍 CORRIGÉ DÉTAILLÉ · \(appState.activeRouteCode)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    Spacer()
                    Button {
                        appState.showExamDetailedCorrectionSheet = false
                    } label: {
                        Text(verbatim: "✕")
                            .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(0..<appState.examQuestions.count, id: \.self) { idx in
                    examCorrectionCardView(question: appState.examQuestions[idx])
                }
            }
            .padding(PrismSpacing.xl)
        }
        .background(PrismColor.figmaHex("#f8fafc"))
    }

    private func examCorrectionCardView(question: CertiGoNativeExamQuestion) -> some View {
        let pickedId = appState.selectedExamChoiceByQuestionNumber[question.number]
        let pickedChoice = question.choices.first(where: { $0.id == pickedId })
        let correctChoice = question.choices.first(where: \.isCorrect) ?? question.choices[0]
        let isCorrect = pickedChoice?.isCorrect == true

        return VStack(alignment: .leading, spacing: PrismSpacing.s) {
            HStack {
                Text(verbatim: "Question \(question.number) · \(question.domainTitle)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
                Spacer()
                Text(verbatim: isCorrect ? "✓ Correct" : "✕ Erreur")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex(isCorrect ? "#15803d" : "#e11d48"))
                    .padding(.horizontal, PrismSpacing.s)
                    .padding(.vertical, PrismSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .fill(PrismColor.figmaHex(isCorrect ? "#dcfce7" : "#ffe4e6"))
                    )
            }

            Text(verbatim: question.stem)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))

            if let pickedChoice, !isCorrect {
                Text(verbatim: "✕ Ta réponse : \(pickedChoice.badge). \(pickedChoice.text)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#e11d48"))
            }

            Text(verbatim: "✓ Bonne réponse : \(correctChoice.badge). \(correctChoice.text)")
                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#15803d"))

            Text(verbatim: CertiGoNativeRichCatalog.officialExplanation(forExamQuestion: question))
                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#334155"))

            Button {
                appState.showExamDetailedCorrectionSheet = false
                appState.isPresentingExamReport24 = false
                appState.openAITopic(
                    "last-3-errors",
                    customUserQuestion: "Explique-moi la Question \(question.number) (\(question.domainTitle)) : \(question.stem)"
                )
                appState.selectedTab = .hubIA
            } label: {
                Text(verbatim: "✦ Demander au Coach IA")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    .padding(.horizontal, PrismSpacing.m)
                    .padding(.vertical, PrismSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .fill(PrismColor.figmaHex("#eff6ff"))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(PrismSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                .fill(PrismColor.surface)
        )
    }
}

// MARK: - 8. Interactive 7-Step Native SwiftUI Onboarding Flow (Figma Page 07 `102:257` — `OB_01` + `1/7..7/7`)

public struct CertiGoNativeOnboardingFlowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var appState: CertiGoNativeAppState
    @Binding public var coordinator: PrismAppShellCoordinatorModel

    public init(
        appState: Binding<CertiGoNativeAppState>,
        coordinator: Binding<PrismAppShellCoordinatorModel>
    ) {
        self._appState = appState
        self._coordinator = coordinator
    }

    public var body: some View {
        let totalSteps = max(1, CertiGoNativeAppState.onboardingStepCount)
        let step = min(max(appState.onboardingStepIndex, 0), totalSteps - 1)
        let rawProgress = CGFloat(max(1, step)) / 7.0
        let progressFraction = rawProgress.isFinite ? min(max(rawProgress, 0), 1) : 0

        return VStack(spacing: .zero) {
            // Top Header Bar ONLY on Steps 1..7 (`1/7` to `7/7`) — Step 0 (`OB_01`) has no generic header!
            if step > 0 {
                HStack(spacing: PrismSpacing.m) {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.goBackOnboardingStep()
                        }
                    } label: {
                        Text(verbatim: "←")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#334155"))
                            .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.surface)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding-header-back")

                    GeometryReader { geo in
                        let safeWidth = geo.size.width.isFinite ? max(FigMetrics.sixteen, geo.size.width * progressFraction) : FigMetrics.sixteen
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                .fill(PrismColor.figmaHex("#e2e8f0"))
                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                .fill(PrismColor.figmaHex("#1d4ed8"))
                                .frame(width: safeWidth)
                        }
                    }
                    .frame(height: FigMetrics.ten)

                    Text(verbatim: "\(step)/7")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.m)
                .background(PrismColor.figmaHex("#f8fafc"))
            }

            // Interactive Step Content inside a ScrollView
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    onboardingStepContent(for: step)
                }
                .padding(PrismSpacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PrismColor.figmaHex("#f8fafc"))

            // Single Primary Blue 3D CTA Button on Steps 1..6 (Step 0 and Step 7 have their own dedicated CTAs inside their views — zero duplicate buttons!)
            if step >= 1 && step <= 6 {
                VStack(spacing: .zero) {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.advanceOnboardingStep()
                        }
                    } label: {
                        Text(verbatim: onboardingPrimaryButtonTitle(for: step))
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: FigMetrics.fiftyTwo)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#1d4ed8",
                            lipHex: "#1e40af",
                            cornerRadius: PrismRadius.l
                        )
                    )
                    .accessibilityIdentifier("onboarding-footer-continue")
                }
                .padding(PrismSpacing.l)
                .background(PrismColor.surface)
            }
        }
        .fontDesign(.rounded)
    }

    private func onboardingPrimaryButtonTitle(for step: Int) -> String {
        switch step {
        case 1:
            let count = max(1, appState.onboardingSelectedGoalIds.count)
            return count > 1
                ? "CONTINUER (\(count) OBJECTIFS CHOISIS)"
                : "CONTINUER (1 OBJECTIF CHOISI)"
        case 2:
            let count = max(1, appState.trackedCertificationCodes.count)
            return "SUIVRE CES \(count) PARCOURS →"
        case 3:
            return "AJOUTER À MES PARCOURS →"
        case 4:
            return "CONTINUER →"
        case 5:
            return "ACTIVER MON RAPPEL →"
        case 6:
            return "SAUVEGARDER MON PLAN →"
        default:
            return "CONTINUER →"
        }
    }

    @ViewBuilder
    private func onboardingStepContent(for step: Int) -> some View {
        switch step {
        case 0:
            onboardingStep0WelcomeView
        case 1:
            onboardingStep1GoalsMultiSelectView
        case 2:
            onboardingStep2MultiCertificationView
        case 3:
            onboardingStep3AIRadarLivingCatalogView
        case 4:
            onboardingStep4ExperienceAndDeadlineView
        case 5:
            onboardingStep5RhythmReminderAndWidgetView
        case 6:
            onboardingStep6ComparativePlanChartView
        default:
            onboardingStep7OneTapProfileAndGuidedTourView
        }
    }

    // Step 0 (`OB_01` — Figma `132:182`): Design 4 Opening with Dashed Arc + 4 White 3D Logo Cushions + 3-Column Banner + 2 Bottom Buttons
    private var onboardingStep0WelcomeView: some View {
        let arcVendors: [(vendorId: String, xOffset: CGFloat, yOffset: CGFloat)] = [
            ("google", -118, 12),
            ("microsoft", -44, -36),
            ("aws", 44, -36),
            ("github", 118, 12)
        ]

        return VStack(spacing: PrismSpacing.l) {
            // Dashed Arc + 4 Official Brand 3D White Square Cushions (`60x60 pt`) around Central Mascot (`140x140 pt`)
            ZStack {
                Circle()
                    .strokeBorder(
                        PrismColor.figmaHex("#93c5fd"),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                    )
                    .frame(width: FigMetrics.twoHundredForty, height: FigMetrics.twoHundredForty)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                PrismColor.figmaHex("#dbeafe"),
                                PrismColor.figmaHex("#f8fafc").opacity(0)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 96
                        )
                    )
                    .frame(width: FigMetrics.oneHundredNinetyTwo, height: FigMetrics.oneHundredNinetyTwo)
                    .offset(y: 24)

                ForEach(0..<arcVendors.count, id: \.self) { idx in
                    let item = arcVendors[idx]
                    ZStack {
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(PrismColor.figmaHex("#cbd5e1"))
                            .offset(y: FigMetrics.four)
                        RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                            .fill(PrismColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                            )
                        CertiGoBrandLogoView(vendorId: item.vendorId, size: FigMetrics.thirtyTwo)
                    }
                    .frame(width: FigMetrics.sixty, height: FigMetrics.sixty)
                    .offset(x: item.xOffset, y: item.yOffset - 34)
                }

                CertiGoMascotView(pose: .onboardingWelcome, size: FigMetrics.oneHundredForty)
                    .offset(y: 28)
            }
            .frame(maxWidth: .infinity)
            .frame(height: FigMetrics.twoHundredFortyEight)
            .padding(.top, PrismSpacing.s)

            // Big Blue Title + Subtitle + Description
            VStack(spacing: PrismSpacing.s) {
                Text(verbatim: "CertiGo")
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirtyTwo, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))

                Text(verbatim: "Décroche tes certifications.\nMaîtrise l'IA & la Tech en continu.")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .multilineTextAlignment(.center)

                Text(verbatim: "Suis plusieurs parcours en parallèle : certifications officielles, acteurs majeurs de l'IA et nouveautés Tech ajoutées chaque semaine.")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            // 3-Column White Banner separated by vertical dividers
            HStack(spacing: .zero) {
                onboardingThreeColumnStatCell(top: "Multi-Parcours", bottom: "En parallèle")
                Rectangle()
                    .fill(PrismColor.figmaHex("#e2e8f0"))
                    .frame(width: PrismBorder.hairline, height: FigMetrics.forty)
                onboardingThreeColumnStatCell(top: "Certifs + IA", bottom: "Veille & Acteurs")
                Rectangle()
                    .fill(PrismColor.figmaHex("#e2e8f0"))
                    .frame(width: PrismBorder.hairline, height: FigMetrics.forty)
                onboardingThreeColumnStatCell(top: "Nouveautés 🔄", bottom: "Chaque semaine")
            }
            .padding(.vertical, PrismSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
            )

            // 2 Bottom 3D Buttons (`C'EST PARTI !` + `J'AI DÉJÀ UN COMPTE`)
            VStack(spacing: PrismSpacing.m) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.advanceOnboardingStep()
                    }
                } label: {
                    Text(verbatim: "C'EST PARTI !")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.fiftyTwo)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#1d4ed8",
                        lipHex: "#1e40af",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.five
                    )
                )
                .accessibilityIdentifier("onboarding-step0-start-journey")

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.connectMicrosoftEntraAccount()
                        appState.onboardingStepIndex = 7
                    }
                } label: {
                    Text(verbatim: "J'AI DÉJÀ UN COMPTE")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.fortyEight)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#ffffff",
                        lipHex: "#cbd5e1",
                        strokeHex: "#cbd5e1",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("onboarding-step0-existing-account")
            }
        }
    }

    private func onboardingThreeColumnStatCell(top: String, bottom: String) -> some View {
        VStack(spacing: FigMetrics.two) {
            Text(verbatim: top)
                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                .lineLimit(1)
            Text(verbatim: bottom)
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Regular"))
                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // Step 1 (`OB_02` — `1/7` — Figma `132:264`): Multi-Choice Goals
    private var onboardingStep1GoalsMultiSelectView: some View {
        let goals: [(id: String, icon: String, title: String, subtitle: String)] = [
            ("certifs", "🎓", "Décrocher 1 ou plusieurs certifications", "Microsoft, AWS, Google Cloud, GitHub ou Kubernetes"),
            ("ai-radar", "✦", "Me tenir à jour sur l'IA & la Tech", "Maîtriser les acteurs de l'IA (OpenAI, Claude, Foundry…)"),
            ("career", "🚀", "Accélérer ma carrière & mes projets", "Pratiquer sur des cas réels d'architecture & CLI"),
            ("enterprise", "🏢", "Valider des compétences en entreprise", "Maintenir mon équipe ou mon profil ESN au top niveau")
        ]

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            Text(verbatim: "CHOIX MULTIPLE POSSIBLE")
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
            Text(verbatim: "Qu'est-ce qui t'amène sur CertiGo ?")
                .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
            Text(verbatim: "Tu peux combiner certifications officielles et veille sur les nouvelles avancées Tech & IA.")
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                .foregroundStyle(PrismColor.figmaHex("#475569"))
                .lineSpacing(3)

            ForEach(goals, id: \.id) { goal in
                let isSelected = appState.onboardingSelectedGoalIds.contains(goal.id)
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.toggleOnboardingGoal(goal.id)
                    }
                } label: {
                    HStack(spacing: PrismSpacing.m) {
                        Text(verbatim: goal.icon)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Regular"))
                            .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.figmaHex(isSelected ? "#dbeafe" : "#f1f5f9"))
                            )

                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            Text(verbatim: goal.title)
                                .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            Text(verbatim: goal.subtitle)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                .lineSpacing(2)
                        }

                        Spacer()

                        Text(verbatim: isSelected ? "✓" : "")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.onAccent)
                            .frame(width: FigMetrics.twentyEight, height: FigMetrics.twentyEight)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(PrismColor.figmaHex(isSelected ? "#1d4ed8" : "#e2e8f0"))
                            )
                    }
                    .padding(PrismSpacing.m)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: isSelected ? "#eff6ff" : "#ffffff",
                        lipHex: isSelected ? "#1d4ed8" : "#cbd5e1",
                        strokeHex: isSelected ? "#1d4ed8" : "#e2e8f0",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
            }
        }
    }

    // Step 2 (`OB_03A` — `2/7` — Figma `132:339`): Multi-Certification Selector with Brand Filter Bar (including `Kubernetes` logo!)
    private var onboardingStep2MultiCertificationView: some View {
        let brandTabs: [(id: String, name: String)] = [
            ("microsoft", "Microsoft"),
            ("aws", "AWS"),
            ("google", "Google"),
            ("github", "GitHub"),
            ("kubernetes", "Kubernetes")
        ]
        let codes = ["AZ-104", "SAA-C03", "GH-300", "AZ-900", "AI-102", "PCA", "PDE", "CKA", "CCA-F"]

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            Text(verbatim: "🔀 MULTI-PARCOURS : SUIS PLUSIEURS CERTIFS EN PARALLÈLE")
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                .padding(.horizontal, PrismSpacing.s)
                .padding(.vertical, FigMetrics.four)
                .background(
                    Capsule().fill(PrismColor.figmaHex("#eff6ff"))
                )

            Text(verbatim: "Quelles certifications veux-tu suivre ?")
                .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))

            // Brand Tabs Bar with true official logos (`microsoft`, `aws`, `google`, `github`, `kubernetes`)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.s) {
                    ForEach(brandTabs, id: \.id) { tab in
                        let isSelected = appState.selectedVendorInPopover == tab.id
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                appState.selectedVendorInPopover = tab.id
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.xs) {
                                CertiGoBrandLogoView(vendorId: tab.id, size: PrismSize.brandS)
                                Text(verbatim: tab.name)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                    .foregroundStyle(isSelected ? PrismColor.figmaHex("#1d4ed8") : PrismColor.figmaHex("#475569"))
                            }
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(isSelected ? PrismColor.figmaHex("#eff6ff") : PrismColor.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? PrismColor.figmaHex("#1d4ed8") : PrismColor.figmaHex("#e2e8f0"),
                                        lineWidth: PrismBorder.standard
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            ForEach(codes, id: \.self) { code in
                let detail = CertiGoNativeRichCatalog.profileCertificationDetail(forCode: code)
                let trackIdx = appState.trackedCertificationCodes.firstIndex(of: code)
                let isSelected = trackIdx != nil || appState.activeRouteCode.uppercased() == code
                let slotBadge: String = {
                    if let trackIdx {
                        return trackIdx == 0 ? "PARCOURS 1 ACTIF" : "PARCOURS \(trackIdx + 1) EN PARALLÈLE"
                    }
                    return code.hasSuffix("900") ? "DÉBUTANT · FUNDAMENTALS" : detail.badge
                }()

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.toggleOnboardingCertification(code)
                        coordinator.parallelTracksPreference.toggleParallelTrack(code)
                    }
                } label: {
                    HStack(spacing: PrismSpacing.m) {
                        CertiGoOfficialCrestView(routeCode: code, size: FigMetrics.fortyEight)
                        VStack(alignment: .leading, spacing: FigMetrics.three) {
                            Text(verbatim: slotBadge)
                                .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex(isSelected ? "#1d4ed8" : "#64748b"))
                            Text(verbatim: detail.title)
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        }
                        Spacer()
                        Text(verbatim: isSelected ? "✓" : "+")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#1d4ed8"))
                            .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
                            .background(
                                Circle().fill(
                                    isSelected ? PrismColor.figmaHex("#58cc02") : PrismColor.figmaHex("#eff6ff")
                                )
                            )
                    }
                    .padding(PrismSpacing.m)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: isSelected ? "#f0fdf4" : "#ffffff",
                        lipHex: isSelected ? "#58cc02" : "#cbd5e1",
                        strokeHex: isSelected ? "#58cc02" : "#e2e8f0",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
            }
        }
    }

    // Step 3 (`OB_03B` — `3/7` — Figma `132:438`): AI & Tech Radar Living Catalog
    private var onboardingStep3AIRadarLivingCatalogView: some View {
        let radarCards: [(id: String, icon: String, badge: String, title: String, subtitle: String)] = [
            (
                "ai-actors",
                "🧠",
                "NOUVEAU · COURS DÉDIÉS",
                "Les Grands Acteurs & Modèles de l'IA",
                "OpenAI (GPT/o3), Anthropic Claude, Google Gemini, Mistral & Meta"
            ),
            (
                "ai-agents-mcp",
                "⚡",
                "AVANCÉES IA EN DIRECT",
                "Agents IA, MCP & Outils Développeur",
                "Microsoft Foundry, GitHub Copilot, Serveurs MCP, RAG & Orchestration"
            ),
            (
                "cloud-weekly",
                "☁️",
                "MIS À JOUR CHAQUE SEMAINE",
                "Radar Hebdo des Nouveautés Cloud",
                "Comprendre chaque nouvelle sortie AWS, Azure, GCP & Sécurité en 5 min"
            )
        ]

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            Text(verbatim: "✦ BIEN PLUS QU'UNE APP DE CERTIFICATION : RADAR IA & TECH")
                .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#7c3aed"))
                .padding(.horizontal, PrismSpacing.s)
                .padding(.vertical, FigMetrics.four)
                .background(
                    Capsule().fill(PrismColor.figmaHex("#f3e8ff"))
                )

            Text(verbatim: "Reste à la pointe de l'IA et des nouvelles Tech.")
                .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))

            Text(verbatim: "En parallèle de tes certifications, quels parcours d'actualité technologique et d'IA veux-tu suivre ?")
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                .foregroundStyle(PrismColor.figmaHex("#475569"))
                .lineSpacing(3)

            ForEach(radarCards, id: \.id) { card in
                let isSelected = appState.onboardingSelectedAIRadarIds.contains(card.id)
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.toggleOnboardingAIRadar(card.id)
                    }
                } label: {
                    HStack(spacing: PrismSpacing.m) {
                        Text(verbatim: card.icon)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Regular"))
                            .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.figmaHex(isSelected ? "#f3e8ff" : "#f1f5f9"))
                            )

                        VStack(alignment: .leading, spacing: FigMetrics.three) {
                            Text(verbatim: card.badge)
                                .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#7c3aed"))
                            Text(verbatim: card.title)
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            Text(verbatim: card.subtitle)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                .lineSpacing(2)
                        }

                        Spacer()

                        Text(verbatim: isSelected ? "✓" : "+")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#7c3aed"))
                            .frame(width: FigMetrics.twentyEight, height: FigMetrics.twentyEight)
                            .background(
                                Circle().fill(PrismColor.figmaHex(isSelected ? "#7c3aed" : "#f3e8ff"))
                            )
                    }
                    .padding(PrismSpacing.m)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: isSelected ? "#faf5ff" : "#ffffff",
                        lipHex: isSelected ? "#7c3aed" : "#cbd5e1",
                        strokeHex: isSelected ? "#7c3aed" : "#e2e8f0",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
            }

            HStack(spacing: PrismSpacing.m) {
                CertiGoMascotView(pose: .specialistAICoach, size: FigMetrics.fiftySix)
                Text(verbatim: "🔄 CATALOGUE EN EXPANSION CONTINUE : De nouvelles certifications, de nouveaux acteurs de l'IA et des labs sont ajoutés chaque semaine.")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium"))
                    .foregroundStyle(PrismColor.figmaHex("#1e3a8a"))
                    .lineSpacing(2)
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex("#eff6ff"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#bfdbfe"), lineWidth: PrismBorder.standard)
            )
        }
    }

    // Step 4 (`OB_04` — `4/7` — Figma `132:519`): Experience Level + 2x2 Exam Deadline Grid
    private var onboardingStep4ExperienceAndDeadlineView: some View {
        let levels: [(badge: String, title: String, subtitle: String)] = [
            ("▮▯▯", "Je débute sur le Cloud & l'IA", "On part des bases visuelles étape par étape."),
            ("▮▮▯", "Intermédiaire (Recommandé)", "Je connais déjà les bases et je veux pratiquer."),
            ("▮▮▮", "Avancé · Sprint & Examens", "Débloque directement les cas complexes et labs CLI.")
        ]
        let deadlines: [(icon: String, title: String, subtitle: String)] = [
            ("📅", "Dans 30 jours", "Sprint intensif"),
            ("🎯", "Dans 6 semaines", "Idéal · Recommandé"),
            ("📆", "Dans 3 mois", "Rythme serein"),
            ("♾️", "Veille continue", "Sans date fixe")
        ]
        let twoCols = [
            GridItem(.flexible(), spacing: PrismSpacing.s),
            GridItem(.flexible(), spacing: PrismSpacing.s)
        ]

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            Text(verbatim: "CALIBRAGE SUR-MESURE")
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
            Text(verbatim: "Quel est ton niveau actuel ?")
                .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))

            ForEach(0..<levels.count, id: \.self) { idx in
                let level = levels[idx]
                let isSelected = appState.onboardingExperienceLevelIndex == idx
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.onboardingExperienceLevelIndex = idx
                    }
                } label: {
                    HStack(spacing: PrismSpacing.m) {
                        Text(verbatim: level.badge)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                            .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(PrismColor.figmaHex("#eff6ff"))
                            )
                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            Text(verbatim: level.title)
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            Text(verbatim: level.subtitle)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        Spacer()
                        if isSelected {
                            Text(verbatim: "✓")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                        }
                    }
                    .padding(PrismSpacing.m)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: isSelected ? "#eff6ff" : "#ffffff",
                        lipHex: isSelected ? "#1d4ed8" : "#cbd5e1",
                        strokeHex: isSelected ? "#1d4ed8" : "#e2e8f0",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
            }

            Text(verbatim: "QUAND VISES-TU TA 1re CERTIFICATION ?")
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                .padding(.top, PrismSpacing.xs)

            LazyVGrid(columns: twoCols, spacing: PrismSpacing.s) {
                ForEach(0..<deadlines.count, id: \.self) { idx in
                    let item = deadlines[idx]
                    let isSelected = appState.onboardingExamDeadlineIndex == idx
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.onboardingExamDeadlineIndex = idx
                            appState.targetExamDateText = item.title
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                            Text(verbatim: "\(item.icon) \(item.title)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            Text(verbatim: item.subtitle)
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Regular"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))
                        }
                        .padding(PrismSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: isSelected ? "#eff6ff" : "#ffffff",
                            lipHex: isSelected ? "#1d4ed8" : "#cbd5e1",
                            strokeHex: isSelected ? "#1d4ed8" : "#e2e8f0",
                            cornerRadius: PrismRadius.l,
                            lipDepth: FigMetrics.three
                        )
                    )
                }
            }
        }
    }

    // Step 5 (`OB_06A/C` — `5/7` — Figma `132:581` / `132:759`): Daily Rhythm + Smart Reminder `19:30` + iOS 18 Widget Preview
    private var onboardingStep5RhythmReminderAndWidgetView: some View {
        let rhythms: [(minutes: Int, title: String, subtitle: String)] = [
            (5, "5 min / jour", "Régulier · 1 étape / jour"),
            (10, "10 min / jour", "Recommandé · Progression ×3"),
            (20, "20 min / jour", "Intensif · Sprint rapide")
        ]
        let times = ["19:30", "08:30", "12:30", "21:00"]

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            Text(verbatim: "HABITUDE & RÉGULARITÉ")
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
            Text(verbatim: "Fixe ton rythme quotidien")
                .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
            Text(verbatim: "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.")
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                .foregroundStyle(PrismColor.figmaHex("#475569"))

            ForEach(rhythms, id: \.minutes) { item in
                let isSelected = appState.onboardingDailyRhythmMinutes == item.minutes
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.onboardingDailyRhythmMinutes = item.minutes
                    }
                } label: {
                    HStack {
                        Text(verbatim: item.title)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        Spacer()
                        Text(verbatim: item.subtitle)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Medium"))
                            .foregroundStyle(PrismColor.figmaHex(isSelected ? "#1d4ed8" : "#64748b"))
                    }
                    .padding(PrismSpacing.m)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: isSelected ? "#eff6ff" : "#ffffff",
                        lipHex: isSelected ? "#1d4ed8" : "#cbd5e1",
                        strokeHex: isSelected ? "#1d4ed8" : "#e2e8f0",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.three
                    )
                )
            }

            // Smart Daily Reminder Card (`19:30`) + iOS Notification Preview
            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                Text(verbatim: "🔔  RAPPEL INTELLIGENT QUOTIDIEN")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    HStack {
                        Text(verbatim: "CertiGo · Rappel & Radar IA 🔥")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        Spacer()
                        Text(verbatim: appState.onboardingReminderTimeText)
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    }
                    Text(verbatim: "Ton défi \(appState.activeRouteCode) (5 min) et le nouveau cours sur Claude & Foundry sont prêts !")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))
                }
                .padding(PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                        .fill(PrismColor.figmaHex("#f8fafc"))
                )

                HStack(spacing: PrismSpacing.xs) {
                    ForEach(times, id: \.self) { t in
                        let isChosen = appState.onboardingReminderTimeText == t
                        Button {
                            appState.onboardingReminderTimeText = t
                        } label: {
                            Text(verbatim: t)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                .foregroundStyle(isChosen ? PrismColor.onAccent : PrismColor.figmaHex("#334155"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, PrismSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                        .fill(PrismColor.figmaHex(isChosen ? "#1d4ed8" : "#f1f5f9"))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(PrismSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
            )

            // iOS 18 Home Screen Widget Preview (`OB_06C`)
            HStack(spacing: PrismSpacing.m) {
                CertiGoMascotView(pose: .emotionOnFire, size: FigMetrics.fortyEight)
                VStack(alignment: .leading, spacing: FigMetrics.two) {
                    Text(verbatim: "📱 WIDGET SÉRIE & RADAR IA iOS 18")
                        .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#ea580c"))
                    Text(verbatim: "Ajoute le widget CertiGo sur ton écran d'accueil pour suivre ta série 🔥 et tes parcours.")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                        .foregroundStyle(PrismColor.figmaHex("#334155"))
                }
            }
            .padding(PrismSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#fed7aa"), lineWidth: PrismBorder.standard)
            )
        }
    }

    // Step 6 (`OB_07` — `6/7` — Figma `132:877` / `130:540`): Clean Study Plan & True Visual Comparative Chart (`3,4× plus rapide`)
    private var onboardingStep6ComparativePlanChartView: some View {
        let activeTracksSummary = appState.deduplicatedParallelTrackCodes().joined(separator: " · ")

        return VStack(spacing: PrismSpacing.l) {
            VStack(spacing: PrismSpacing.s) {
                Text(verbatim: "✓ TON PLAN MULTI-PARCOURS EST PRÊT")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#15803d"))
                    .padding(.horizontal, PrismSpacing.m)
                    .padding(.vertical, FigMetrics.four)
                    .background(
                        Capsule().fill(PrismColor.figmaHex("#dcfce7"))
                    )

                Text(verbatim: "3,4× plus rapide\navec la méthode CertiGo.")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .multilineTextAlignment(.center)

                Text(verbatim: "Prêt pour l'examen · Veille IA en continu")
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Medium"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
            }
            .frame(maxWidth: .infinity)

            // True Visual Comparative Chart (`Path` + `LinearGradient`) matching Figma `130:540`
            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                HStack {
                    Text(verbatim: "MAÎTRISE DES CERTIFICATIONS & DE L'IA")
                        .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    Spacer()
                    Text(verbatim: "✦ Avec CertiGo (810+)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                }

                GeometryReader { geo in
                    let w = geo.size.width.isFinite ? max(220, geo.size.width) : 280
                    let h: CGFloat = 156

                    ZStack(alignment: .topTrailing) {
                        // Horizontal reference grid lines
                        VStack(spacing: .zero) {
                            Divider()
                            Spacer()
                            Divider()
                            Spacer()
                            Divider()
                        }
                        .frame(width: w, height: h)

                        // Blue area gradient under the CertiGo curve
                        Path { path in
                            path.move(to: CGPoint(x: 8, y: h - 18))
                            path.addCurve(
                                to: CGPoint(x: w - 18, y: 24),
                                control1: CGPoint(x: w * 0.36, y: h - 26),
                                control2: CGPoint(x: w * 0.62, y: 34)
                            )
                            path.addLine(to: CGPoint(x: w - 18, y: h - 14))
                            path.addLine(to: CGPoint(x: 8, y: h - 14))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [
                                    PrismColor.figmaHex("#3b82f6:35"),
                                    PrismColor.figmaHex("#3b82f6:04")
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Low dashed red curve (`Sans CertiGo (Seul / PDF)`)
                        Path { path in
                            path.move(to: CGPoint(x: 8, y: h - 18))
                            path.addQuadCurve(
                                to: CGPoint(x: w - 18, y: h - 46),
                                control: CGPoint(x: w * 0.5, y: h - 22)
                            )
                        }
                        .stroke(
                            PrismColor.figmaHex("#ef4444"),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 5])
                        )

                        // Rising blue curve (`✦ Avec CertiGo (810+)`)
                        Path { path in
                            path.move(to: CGPoint(x: 8, y: h - 18))
                            path.addCurve(
                                to: CGPoint(x: w - 18, y: 24),
                                control1: CGPoint(x: w * 0.36, y: h - 26),
                                control2: CGPoint(x: w * 0.62, y: 34)
                            )
                        }
                        .stroke(
                            PrismColor.figmaHex("#1d4ed8"),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )

                        CertiGoMascotView(pose: .celebratingTrophy, size: FigMetrics.fortyEight)
                            .offset(x: -FigMetrics.four, y: -FigMetrics.six)
                    }
                }
                .frame(height: FigMetrics.oneHundredFiftySix)

                HStack {
                    Text(verbatim: "Sans CertiGo (Seul / PDF)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Medium"))
                        .foregroundStyle(PrismColor.figmaHex("#ef4444"))
                    Spacer()
                }

                HStack {
                    Text(verbatim: "Aujourd'hui")
                    Spacer()
                    Text(verbatim: "Semaine 3")
                    Spacer()
                    Text(verbatim: "Objectif ✓")
                }
                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#64748b"))

                Text(verbatim: "Parcours actifs : \(activeTracksSummary) · Acteurs IA 🔄")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                    .padding(.horizontal, PrismSpacing.m)
                    .padding(.vertical, PrismSpacing.xs)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .fill(PrismColor.figmaHex("#eff6ff"))
                    )
            }
            .padding(PrismSpacing.l)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .fill(PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
            )

            Text(verbatim: "🔄 Nouveaux chapitres, examens blancs et cours sur les derniers modèles IA débloqués chaque semaine.")
                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Regular"))
                .foregroundStyle(PrismColor.figmaHex("#475569"))
                .multilineTextAlignment(.center)
        }
    }

    // Step 7 (`OB_08A` — `7/7` — Figma `132:945` / `130:608`): 1-Tap Profile Creation + Guided App Tour Launch
    private var onboardingStep7OneTapProfileAndGuidedTourView: some View {
        VStack(spacing: PrismSpacing.l) {
            VStack(spacing: PrismSpacing.m) {
                CertiGoMascotView(pose: .celebratingTrophy, size: FigMetrics.oneHundredTwenty)

                Text(verbatim: "Crée ton profil pour\nsauvegarder tes parcours")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .multilineTextAlignment(.center)

                Text(verbatim: "Synchronise tes certifications en parallèle, ta série 🔥 et ton radar IA sur tous tes appareils.")
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Regular"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            // 4 Official Sign-In Buttons from Figma `130:608`
            VStack(spacing: PrismSpacing.s) {
                // 1. Apple Sign-In
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.connectAccount(provider: "Identifiant Apple")
                        appState.completeOnboardingFlow(awardWelcomeBonus: true, startGuidedTour: true)
                    }
                } label: {
                    HStack(spacing: PrismSpacing.s) {
                        Text(verbatim: "")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                        Text(verbatim: "Continuer avec Apple")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                    }
                    .foregroundStyle(PrismColor.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: FigMetrics.fifty)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#0f172a",
                        lipHex: "#020617",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("onboarding-connect-apple-button")

                // 2. Microsoft Entra ID Sign-In
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.connectMicrosoftEntraAccount()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.s) {
                        CertiGoBrandLogoView(vendorId: "microsoft", size: PrismSize.brandS)
                        Text(
                            verbatim: appState.isAccountConnected
                                ? "✓ Compte Microsoft connecté (\(appState.userDisplayName))"
                                : "Continuer avec Microsoft"
                        )
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: FigMetrics.fifty)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: appState.isAccountConnected ? "#f0fdf4" : "#ffffff",
                        lipHex: appState.isAccountConnected ? "#58cc02" : "#cbd5e1",
                        strokeHex: appState.isAccountConnected ? "#58cc02" : "#cbd5e1",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("onboarding-connect-microsoft-button")

                // 3. Google Sign-In
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.connectAccount(provider: "Google Cloud Identity")
                        appState.completeOnboardingFlow(awardWelcomeBonus: true, startGuidedTour: true)
                    }
                } label: {
                    HStack(spacing: PrismSpacing.s) {
                        CertiGoBrandLogoView(vendorId: "google", size: PrismSize.brandS)
                        Text(verbatim: "Continuer avec Google")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: FigMetrics.fifty)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#ffffff",
                        lipHex: "#cbd5e1",
                        strokeHex: "#cbd5e1",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("onboarding-connect-google-button")

                // 4. Email Sign-In
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.connectAccount(provider: "Adresse e-mail")
                        appState.completeOnboardingFlow(awardWelcomeBonus: true, startGuidedTour: true)
                    }
                } label: {
                    HStack(spacing: PrismSpacing.s) {
                        Text(verbatim: "✉️")
                        Text(verbatim: "Continuer avec mon adresse e-mail")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: FigMetrics.fifty)
                }
                .buttonStyle(
                    CertiGoTactile3DButtonStyle(
                        faceHex: "#ffffff",
                        lipHex: "#cbd5e1",
                        strokeHex: "#cbd5e1",
                        cornerRadius: PrismRadius.l,
                        lipDepth: FigMetrics.four
                    )
                )
                .accessibilityIdentifier("onboarding-connect-email-button")
            }

            // Guided Tour Launch CTA (+50 💎)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                    appState.completeOnboardingFlow(awardWelcomeBonus: true, startGuidedTour: true)
                }
            } label: {
                Text(verbatim: "🧭 Explorer l'application avec la visite guidée (+50 💎) →")
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                    .padding(.vertical, PrismSpacing.s)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("onboarding-complete-with-profile-button")
        }
    }
}
#endif

