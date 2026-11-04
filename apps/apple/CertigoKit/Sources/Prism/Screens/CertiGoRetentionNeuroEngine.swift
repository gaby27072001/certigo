import BrandAssets
import CertigoCortex
import CertigoData
import CertigoDomain
import Foundation
#if canImport(CoreHaptics)
import CoreHaptics
#endif

// MARK: - 0. Duolingo-Style CoreHaptics & UIKit Haptics Engine (`CertiGoHapticsEngine`)

public enum CertiGoHapticEventKind: String, Codable, CaseIterable, Hashable, Sendable {
    case buttonPress = "button_press"
    case buttonRelease = "button_release"
    case optionSelection = "option_selection"
    case correctAnswer = "correct_answer"
    case wrongAnswer = "wrong_answer"
    case stampSealed = "stamp_sealed"
    case lessonCompleteFanfare = "lesson_complete_fanfare"

    public var prismToken: PrismHapticToken {
        switch self {
        case .buttonPress, .buttonRelease, .optionSelection:
            return .selection
        case .correctAnswer, .stampSealed:
            return .correct
        case .wrongAnswer:
            return .incorrectSoft
        case .lessonCompleteFanfare:
            return .declic
        }
    }
}

public struct CertiGoHapticTransientPulseSpec: Codable, Equatable, Hashable, Sendable {
    public let relativeTimeSeconds: Double
    public let intensity: Float
    public let sharpness: Float

    public init(relativeTimeSeconds: Double, intensity: Float, sharpness: Float) {
        self.relativeTimeSeconds = relativeTimeSeconds
        self.intensity = intensity
        self.sharpness = sharpness
    }
}

public final class CertiGoHapticsEngine: @unchecked Sendable {
    public static let shared = CertiGoHapticsEngine()
    nonisolated(unsafe) public private(set) static var totalTriggeredHapticsCount: Int = 0
    nonisolated(unsafe) public private(set) static var lastTriggeredHapticToken: PrismHapticToken? = nil

    private let lock = NSLock()
    private var _isEnabled: Bool = true
    private var _recordedEvents: [CertiGoHapticEventKind] = []

    #if canImport(CoreHaptics)
    private var hapticEngine: CHHapticEngine?
    #endif

    public init(isEnabled: Bool = true) {
        self._isEnabled = isEnabled
        prepareCoreHapticsIfAvailable()
    }

    public static func resetTestCounters() {
        totalTriggeredHapticsCount = 0
        lastTriggeredHapticToken = nil
    }

    public static func play(_ token: PrismHapticToken, isEnabled: Bool = true) {
        guard isEnabled else { return }
        totalTriggeredHapticsCount += 1
        lastTriggeredHapticToken = token
        let pulses = Self.pulseSchedule(for: {
            switch token {
            case .selection: return .optionSelection
            case .correct: return .correctAnswer
            case .declic: return .lessonCompleteFanfare
            case .incorrectSoft, .warning: return .wrongAnswer
            }
        }())
        _ = shared.playCoreHapticsPulses(pulses)
    }

    public var isEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isEnabled
        }
        set {
            lock.lock()
            _isEnabled = newValue
            lock.unlock()
        }
    }

    public var recordedEvents: [CertiGoHapticEventKind] {
        lock.lock()
        defer { lock.unlock() }
        return _recordedEvents
    }

    public func resetRecordedEvents() {
        lock.lock()
        _recordedEvents.removeAll()
        lock.unlock()
    }

    /// Exact CoreHaptics transient pulse schedule for each Duolingo-style interaction.
    public static func pulseSchedule(for event: CertiGoHapticEventKind) -> [CertiGoHapticTransientPulseSpec] {
        switch event {
        case .buttonPress:
            return [.init(relativeTimeSeconds: 0.0, intensity: 0.75, sharpness: 0.85)]
        case .buttonRelease:
            return [.init(relativeTimeSeconds: 0.0, intensity: 0.45, sharpness: 0.65)]
        case .optionSelection:
            return [.init(relativeTimeSeconds: 0.0, intensity: 0.55, sharpness: 0.75)]
        case .correctAnswer:
            return [
                .init(relativeTimeSeconds: 0.0, intensity: 0.70, sharpness: 0.80),
                .init(relativeTimeSeconds: 0.08, intensity: 1.00, sharpness: 0.95)
            ]
        case .wrongAnswer:
            return [
                .init(relativeTimeSeconds: 0.0, intensity: 0.90, sharpness: 0.20),
                .init(relativeTimeSeconds: 0.11, intensity: 0.85, sharpness: 0.15)
            ]
        case .stampSealed:
            return [
                .init(relativeTimeSeconds: 0.0, intensity: 0.45, sharpness: 0.35),
                .init(relativeTimeSeconds: 0.05, intensity: 1.00, sharpness: 0.80)
            ]
        case .lessonCompleteFanfare:
            return [
                .init(relativeTimeSeconds: 0.0, intensity: 0.55, sharpness: 0.60),
                .init(relativeTimeSeconds: 0.07, intensity: 0.70, sharpness: 0.72),
                .init(relativeTimeSeconds: 0.14, intensity: 0.85, sharpness: 0.84),
                .init(relativeTimeSeconds: 0.24, intensity: 1.00, sharpness: 0.96)
            ]
        }
    }

    public func playButtonPress() {
        recordAndPlay(.buttonPress)
    }

    public func playButtonRelease() {
        recordAndPlay(.buttonRelease)
    }

    public func playOptionSelection() {
        recordAndPlay(.optionSelection)
    }

    public func playCorrectAnswer() {
        recordAndPlay(.correctAnswer)
    }

    public func playWrongAnswer() {
        recordAndPlay(.wrongAnswer)
    }

    public func playStampSealed() {
        recordAndPlay(.stampSealed)
    }

    public func playLessonCompleteFanfare() {
        recordAndPlay(.lessonCompleteFanfare)
    }

    private func recordAndPlay(_ kind: CertiGoHapticEventKind) {
        lock.lock()
        let enabled = _isEnabled
        if enabled {
            _recordedEvents.append(kind)
        }
        lock.unlock()
        guard enabled else { return }

        let pulses = Self.pulseSchedule(for: kind)
        let playedCoreHaptics = playCoreHapticsPulses(pulses)
        playUIKitFallback(for: kind, includeImpactFallback: !playedCoreHaptics)
    }

    private func prepareCoreHapticsIfAvailable() {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            try engine.start()
            self.hapticEngine = engine
        } catch {
            self.hapticEngine = nil
        }
        #endif
    }

    private func playCoreHapticsPulses(_ pulses: [CertiGoHapticTransientPulseSpec]) -> Bool {
        #if canImport(CoreHaptics)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return false }
        if hapticEngine == nil {
            prepareCoreHapticsIfAvailable()
        }
        guard let engine = hapticEngine else { return false }
        do {
            let events: [CHHapticEvent] = pulses.map { spec in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: spec.intensity),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: spec.sharpness)
                    ],
                    relativeTime: spec.relativeTimeSeconds
                )
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    private func playUIKitFallback(for kind: CertiGoHapticEventKind, includeImpactFallback: Bool) {
        #if canImport(UIKit) && !os(watchOS)
        typealias ImpactDriver = UIImpactFeedbackGenerator
        let token = kind.prismToken
        Task { @MainActor in
            _ = token
            switch kind {
            case .buttonPress:
                guard includeImpactFallback else { return }
                let gen = ImpactDriver.init(style: .rigid)
                gen.prepare()
                gen.impactOccurred(intensity: 0.75)
            case .buttonRelease:
                guard includeImpactFallback else { return }
                let gen = ImpactDriver.init(style: .light)
                gen.prepare()
                gen.impactOccurred(intensity: 0.45)
            case .optionSelection:
                let sel = UISelectionFeedbackGenerator()
                sel.prepare()
                sel.selectionChanged()
                if includeImpactFallback {
                    let light = ImpactDriver.init(style: .light)
                    light.impactOccurred(intensity: 0.55)
                }
            case .correctAnswer:
                let notif = UINotificationFeedbackGenerator()
                notif.prepare()
                notif.notificationOccurred(.success)
            case .wrongAnswer:
                let notif = UINotificationFeedbackGenerator()
                notif.prepare()
                notif.notificationOccurred(.error)
            case .stampSealed:
                guard includeImpactFallback else { return }
                let soft = ImpactDriver.init(style: .soft)
                soft.impactOccurred(intensity: 0.45)
                let heavy = ImpactDriver.init(style: .heavy)
                heavy.impactOccurred(intensity: 1.0)
            case .lessonCompleteFanfare:
                let notif = UINotificationFeedbackGenerator()
                notif.prepare()
                notif.notificationOccurred(.success)
                if includeImpactFallback {
                    let heavy = ImpactDriver.init(style: .heavy)
                    heavy.impactOccurred(intensity: 1.0)
                }
            }
        }
        #endif
    }
}

// MARK: - 1. A1 : Schultz Positive Prediction Error Engine (EPR > 0) & Single Fluid Error Feedback

public enum CertiGoSchultzPredictionErrorEngine: Sendable {
    /// Computes a deterministic, realistic percentage of exam candidates who fall into a specific trap on exam day (64%..86%).
    public static func examTrapCandidateFallRatePercent(
        forExerciseId exerciseId: String,
        difficulty: Double = 0.58
    ) -> Int {
        let seed = exerciseId.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) & 0x7FFF }
        let base = Int((min(max(difficulty, 0.30), 0.90) * 20.0).rounded())
        return min(86, max(64, 62 + (seed % 17) + (base / 3)))
    }

    /// Ultra-concise Page 17 pill badge (`🎯 Piège d'examen (68 %)`).
    public static func compactExamTrapPillText(
        forExerciseId exerciseId: String,
        difficulty: Double = 0.58
    ) -> String {
        let pct = examTrapCandidateFallRatePercent(forExerciseId: exerciseId, difficulty: difficulty)
        return "🎯 Piège d'examen (\(pct) %)"
    }

    /// Positive-EPR badge transforming an error into strategic exam-day information gain (`EPR > 0`).
    public static func examTrapBadgeText(
        forExerciseId exerciseId: String,
        difficulty: Double = 0.58
    ) -> String {
        let pct = examTrapCandidateFallRatePercent(forExerciseId: exerciseId, difficulty: difficulty)
        return "🎯 Piège d'examen démasqué · \(pct) % des candidats tombent dedans le jour J"
    }

    /// Ensures vertical choice badges are always ordered `A, B, C, D` top-to-bottom even when option propositions are shuffled.
    public static func normalizeOrderedChoiceBadges(
        _ options: [CertiGoNativeExerciseItem.OptionItem]
    ) -> [CertiGoNativeExerciseItem.OptionItem] {
        guard !options.isEmpty else { return [] }
        let positionalLetters = ["A", "B", "C", "D", "E", "F"]
        let validLetterBadges: Set<String> = Set(positionalLetters)
        let usesLetterBadges = options.allSatisfy { validLetterBadges.contains($0.badge.uppercased()) }
        guard usesLetterBadges else { return options }
        return options.enumerated().map { idx, opt in
            CertiGoNativeExerciseItem.OptionItem(
                id: opt.id,
                badge: positionalLetters[min(idx, positionalLetters.count - 1)],
                title: opt.title,
                plainLanguageTitle: opt.plainLanguageTitle,
                subtitle: opt.subtitle,
                assetName: opt.assetName,
                isCorrect: opt.isCorrect,
                whyWrongOrRight: opt.whyWrongOrRight
            )
        }
    }
}

// MARK: - 2. A2 : Variable Reward Vault (Schultz & Eyal Variable Schedule + Master Stroke < 8s)

public enum CertiGoVariableRewardKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case examinerTrapCard = "examiner_trap_card"
    case masterStrokeDoubleBoost = "master_stroke_double_boost"
    case goldenArchitectureCard = "golden_architecture_card"

    public var id: String { rawValue }

    public var displayBadge: String {
        switch self {
        case .examinerTrapCard:
            return "🎯 FICHE PIÈGE OFFICIELLE D'EXAMINATEUR"
        case .masterStrokeDoubleBoost:
            return "⚡ BOOST DE MAÎTRISE ×2 · COUP DE MAÎTRE"
        case .goldenArchitectureCard:
            return "👑 CARTE OR ARCHITECTURE COLLECTIONNABLE"
        }
    }
}

public struct CertiGoVariableRewardItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let kind: CertiGoVariableRewardKind
    public let routeCode: String
    public let title: String
    public let subtitle: String
    public let architecturalRule: String
    public let bonusXP: Int
    public let isMasterStrokeTriggered: Bool

    public init(
        id: String,
        kind: CertiGoVariableRewardKind,
        routeCode: String,
        title: String,
        subtitle: String,
        architecturalRule: String,
        bonusXP: Int,
        isMasterStrokeTriggered: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.routeCode = routeCode
        self.title = title
        self.subtitle = subtitle
        self.architecturalRule = architecturalRule
        self.bonusXP = bonusXP
        self.isMasterStrokeTriggered = isMasterStrokeTriggered
    }
}

public struct CertiGoVariableRewardVault: Codable, Equatable, Sendable {
    public var unlockedRewards: [CertiGoVariableRewardItem]
    public var lastAwardedReward: CertiGoVariableRewardItem?
    public var masterStrokeCount: Int
    public var currentSessionHadMasterStroke: Bool

    public init(
        unlockedRewards: [CertiGoVariableRewardItem] = [],
        lastAwardedReward: CertiGoVariableRewardItem? = nil,
        masterStrokeCount: Int = 0,
        currentSessionHadMasterStroke: Bool = false
    ) {
        self.unlockedRewards = unlockedRewards
        self.lastAwardedReward = lastAwardedReward
        self.masterStrokeCount = masterStrokeCount
        self.currentSessionHadMasterStroke = currentSessionHadMasterStroke
    }

    /// Detects a "Coup de Maître ×2": solving a hard question (`difficulty >= 0.50`) on the 1st try in `< 8s` (`latencyMs < 8_000`).
    public static func isMasterStroke(
        isCorrect: Bool,
        isFirstAttemptOnQuestion: Bool,
        latencyMs: Int,
        difficulty: Double
    ) -> Bool {
        isCorrect && isFirstAttemptOnQuestion && latencyMs > 0 && latencyMs < 8_000 && difficulty >= 0.50
    }

    @discardableResult
    public mutating func registerExerciseAttempt(
        isCorrect: Bool,
        isFirstAttemptOnQuestion: Bool,
        latencyMs: Int,
        difficulty: Double
    ) -> Bool {
        if Self.isMasterStroke(
            isCorrect: isCorrect,
            isFirstAttemptOnQuestion: isFirstAttemptOnQuestion,
            latencyMs: latencyMs,
            difficulty: difficulty
        ) {
            masterStrokeCount += 1
            currentSessionHadMasterStroke = true
            return true
        }
        return false
    }

    @discardableResult
    public mutating func awardSurpriseRewardAtSessionEnd(
        routeCode: String,
        lessonId: String,
        lessonTitle: String,
        sessionIndex: Int
    ) -> CertiGoVariableRewardItem {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let chosenKind: CertiGoVariableRewardKind = {
            if currentSessionHadMasterStroke && sessionIndex % 2 == 1 {
                return .masterStrokeDoubleBoost
            }
            let rotation = abs(sessionIndex + lessonId.count) % 3
            switch rotation {
            case 0:
                return .examinerTrapCard
            case 1:
                return currentSessionHadMasterStroke ? .masterStrokeDoubleBoost : .goldenArchitectureCard
            default:
                return .goldenArchitectureCard
            }
        }()

        let reward: CertiGoVariableRewardItem = {
            switch chosenKind {
            case .examinerTrapCard:
                return CertiGoVariableRewardItem(
                    id: "vr-trap-\(upper.lowercased())-\(unlockedRewards.count + 1)",
                    kind: .examinerTrapCard,
                    routeCode: upper,
                    title: "Fiche Piège Officielle d'Examinateur · \(upper)",
                    subtitle: "Débloquée sur « \(lessonTitle) »",
                    architecturalRule: Self.examinerTrapRule(forRouteCode: upper),
                    bonusXP: 20,
                    isMasterStrokeTriggered: currentSessionHadMasterStroke
                )
            case .masterStrokeDoubleBoost:
                return CertiGoVariableRewardItem(
                    id: "vr-master-\(upper.lowercased())-\(unlockedRewards.count + 1)",
                    kind: .masterStrokeDoubleBoost,
                    routeCode: upper,
                    title: "Boost de Maîtrise ×2 (Coup de Maître < 8s)",
                    subtitle: "Résolution éclair validée du 1er coup sur « \(lessonTitle) »",
                    architecturalRule: "Ton réflexe rapide sur question complexe double ton gain de maîtrise FSRS sur cette session.",
                    bonusXP: 30,
                    isMasterStrokeTriggered: true
                )
            case .goldenArchitectureCard:
                return CertiGoVariableRewardItem(
                    id: "vr-gold-\(upper.lowercased())-\(unlockedRewards.count + 1)",
                    kind: .goldenArchitectureCard,
                    routeCode: upper,
                    title: "Carte Or Architecture · \(upper)",
                    subtitle: "Patron de référence ajouté à ton coffre d'architecte",
                    architecturalRule: Self.goldenArchitecturePattern(forRouteCode: upper),
                    bonusXP: 25,
                    isMasterStrokeTriggered: currentSessionHadMasterStroke
                )
            }
        }()

        lastAwardedReward = reward
        if !unlockedRewards.contains(where: { $0.id == reward.id }) {
            unlockedRewards.insert(reward, at: 0)
        }
        currentSessionHadMasterStroke = false
        return reward
    }

    private static func examinerTrapRule(forRouteCode upper: String) -> String {
        switch upper {
        case "SAA-C03", "CLF-C02", "AIF-C01":
            return "Piège AWS : Un Security Group est stateful (retour auto) mais ne permet jamais de règle Deny explicite ; seule une NACL stateless le peut."
        case "CKA", "CKAD", "CKS":
            return "Piège CKA : Une readinessProbe qui échoue isole le pod du Service sans le redémarrer, tandis que livenessProbe tue le conteneur."
        case "PDE", "PCA", "ACE":
            return "Piège GCP : Sans filtre sur la colonne de partitionnement, BigQuery scanne toutes les partitions malgré le clustering."
        case "GH-300", "CCA-F":
            return "Piège Agentique : Le Prompt Caching exige que les définitions d'outils MCP et le System Prompt restent strictement fixes en préfixe."
        default:
            return "Piège Azure : Un verrou ARM CanNotDelete s'applique au plan de contrôle et bloque la suppression même pour un Propriétaire (Owner)."
        }
    }

    private static func goldenArchitecturePattern(forRouteCode upper: String) -> String {
        switch upper {
        case "SAA-C03", "CLF-C02", "AIF-C01":
            return "Patron Or AWS : CloudFront + OAC ➔ ALB + WAF ➔ EC2 Auto Scaling privé + Rôle IAM STS ➔ Gateway VPC Endpoint S3."
        case "CKA", "CKAD", "CKS":
            return "Patron Or K8s : Ingress TLS ➔ Service ClusterIP ➔ Pod (ServiceAccount dédié + RoleBinding local + NetworkPolicy Ingress/Egress)."
        case "PDE", "PCA", "ACE":
            return "Patron Or GCP : Cloud Pub/Sub (Ordering Key + Dead-Letter) ➔ Cloud Dataflow ➔ BigQuery (Partition Date + 4 colonnes Cluster)."
        default:
            return "Patron Or Azure : Front Door WAF ➔ App Gateway L7 ➔ Private Endpoint + Private DNS privatelink.* ➔ PaaS (publicNetworkAccess: Disabled)."
        }
    }
}

// MARK: - 3. B1 : Visual Architecture Diagram Engine (Berridge Liking)

public struct CertiGoVisualArchitectureBrick: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let icon: String
    public let title: String
    public let subtitle: String
    public let pillBadge: String
    public let borderHex: String
    public let bgHex: String
    public let textHex: String

    public init(
        id: String,
        icon: String,
        title: String,
        subtitle: String,
        pillBadge: String,
        borderHex: String,
        bgHex: String,
        textHex: String
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.pillBadge = pillBadge
        self.borderHex = borderHex
        self.bgHex = bgHex
        self.textHex = textHex
    }
}

public struct CertiGoVisualArchitectureDiagramSpec: Codable, Equatable, Sendable {
    public let routeCode: String
    public let headerTitle: String
    public let compactFlowChain: String
    public let bricks: [CertiGoVisualArchitectureBrick]
    public let goldenTakeaway: String

    public static func diagram(
        forRouteCode routeCode: String,
        lessonId: String = ""
    ) -> CertiGoVisualArchitectureDiagramSpec {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch upper {
        case "SAA-C03", "CLF-C02", "AIF-C01":
            return CertiGoVisualArchitectureDiagramSpec(
                routeCode: upper,
                headerTitle: "SCHÉMA D'ARCHITECTURE VISUEL · \(upper)",
                compactFlowChain: "[🌐 VPC] ➔ [🛡️ Security Group] ➔ [⚡ EC2 / S3]",
                bricks: [
                    CertiGoVisualArchitectureBrick(
                        id: "aws-1",
                        icon: "🌐",
                        title: "VPC & Sous-réseau Privé",
                        subtitle: "Isolation réseau + Route Table vers Gateway Endpoint",
                        pillBadge: "1. PÉRIMÈTRE",
                        borderHex: "#93c5fd",
                        bgHex: "#eff6ff",
                        textHex: "#1e3a8a"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "aws-2",
                        icon: "🛡️",
                        title: "Security Group + Rôle IAM STS",
                        subtitle: "Filtrage Stateful L4 & jetons temporaires sans clé statique",
                        pillBadge: "2. SÉCURITÉ",
                        borderHex: "#fcd34d",
                        bgHex: "#fffbeb",
                        textHex: "#92400e"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "aws-3",
                        icon: "⚡",
                        title: "Amazon EC2 / S3 Privé (SSE-KMS)",
                        subtitle: "Accès direct privé gratuit + Block Public Access activé",
                        pillBadge: "3. WORKLOAD",
                        borderHex: "#34d399",
                        bgHex: "#ecfdf5",
                        textHex: "#065f46"
                    )
                ],
                goldenTakeaway: "Flux AWS certifié : [🌐 VPC] ➔ [🛡️ Security Group + Rôle IAM] ➔ [⚡ EC2 / S3 via Gateway Endpoint]."
            )

        case "CKA", "CKAD", "CKS", "CCNA", "TF-003":
            return CertiGoVisualArchitectureDiagramSpec(
                routeCode: upper,
                headerTitle: "SCHÉMA D'ARCHITECTURE VISUEL · \(upper)",
                compactFlowChain: "[🧭 API Server] ➔ [🔐 RBAC RoleBinding] ➔ [📦 Pod / ServiceAccount]",
                bricks: [
                    CertiGoVisualArchitectureBrick(
                        id: "k8s-1",
                        icon: "🧭",
                        title: "API Server & etcd Control Plane",
                        subtitle: "Point d'entrée mTLS unique + sauvegarde etcdctl snapshot",
                        pillBadge: "1. CONTROL PLANE",
                        borderHex: "#93c5fd",
                        bgHex: "#eff6ff",
                        textHex: "#1e3a8a"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "k8s-2",
                        icon: "🔐",
                        title: "RBAC Role + RoleBinding",
                        subtitle: "Autorisation bornée au Namespace (moindre privilège)",
                        pillBadge: "2. AUTORISATION",
                        borderHex: "#c4b5fd",
                        bgHex: "#f5f3ff",
                        textHex: "#5b21b6"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "k8s-3",
                        icon: "📦",
                        title: "Pod / ServiceAccount + NetworkPolicy",
                        subtitle: "Identité applicative isolée & cloisonnement réseau CNI",
                        pillBadge: "3. EXÉCUTION",
                        borderHex: "#34d399",
                        bgHex: "#ecfdf5",
                        textHex: "#065f46"
                    )
                ],
                goldenTakeaway: "Flux Kubernetes certifié : [🧭 API Server] ➔ [🔐 RBAC RoleBinding] ➔ [📦 Pod / ServiceAccount]."
            )

        case "PDE", "PCA", "ACE":
            return CertiGoVisualArchitectureDiagramSpec(
                routeCode: upper,
                headerTitle: "SCHÉMA D'ARCHITECTURE VISUEL · \(upper)",
                compactFlowChain: "[📨 Cloud Pub/Sub] ➔ [🌊 Cloud Dataflow] ➔ [📊 BigQuery Partition + Cluster]",
                bricks: [
                    CertiGoVisualArchitectureBrick(
                        id: "gcp-1",
                        icon: "📨",
                        title: "Cloud Pub/Sub (Ordering + DLQ)",
                        subtitle: "Ingestion mondiale temps réel avec Dead-Letter Topic",
                        pillBadge: "1. INGESTION",
                        borderHex: "#93c5fd",
                        bgHex: "#eff6ff",
                        textHex: "#1e3a8a"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "gcp-2",
                        icon: "🌊",
                        title: "Cloud Dataflow (Apache Beam)",
                        subtitle: "Traitement streaming exactement-une-fois & fenêtrage",
                        pillBadge: "2. PIPELINE",
                        borderHex: "#fcd34d",
                        bgHex: "#fffbeb",
                        textHex: "#92400e"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "gcp-3",
                        icon: "📊",
                        title: "BigQuery (Partition Date + Clustering)",
                        subtitle: "Élagage des partitions + chiffrement CMEK Cloud KMS",
                        pillBadge: "3. ANALYTIQUE",
                        borderHex: "#34d399",
                        bgHex: "#ecfdf5",
                        textHex: "#065f46"
                    )
                ],
                goldenTakeaway: "Flux Google Cloud certifié : [📨 Pub/Sub] ➔ [🌊 Dataflow] ➔ [📊 BigQuery Partitionné & Clusterisé]."
            )

        case "AI-102", "GH-300", "CCA-F":
            return CertiGoVisualArchitectureDiagramSpec(
                routeCode: upper,
                headerTitle: "SCHÉMA D'ARCHITECTURE VISUEL · \(upper)",
                compactFlowChain: "[📚 AI Search / MCP] ➔ [🧠 Prompt Cache + Modèle] ➔ [🛡️ Content Safety]",
                bricks: [
                    CertiGoVisualArchitectureBrick(
                        id: "ai-1",
                        icon: "📚",
                        title: "AI Search Hybride / Serveur MCP",
                        subtitle: "Recherche Vecteurs + BM25 + Semantic Ranker & Tools typés",
                        pillBadge: "1. CONTEXTE",
                        borderHex: "#93c5fd",
                        bgHex: "#eff6ff",
                        textHex: "#1e3a8a"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "ai-2",
                        icon: "🧠",
                        title: "Modèle Génératif + Prompt Caching",
                        subtitle: "Préfixe statique en cache + ancrage documentaire strict",
                        pillBadge: "2. INFÉRENCE",
                        borderHex: "#c4b5fd",
                        bgHex: "#f5f3ff",
                        textHex: "#5b21b6"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "ai-3",
                        icon: "🛡️",
                        title: "Content Safety & Groundedness",
                        subtitle: "Prompt Shields anti-injection & vérification des citations",
                        pillBadge: "3. GARDE-FOU",
                        borderHex: "#34d399",
                        bgHex: "#ecfdf5",
                        textHex: "#065f46"
                    )
                ],
                goldenTakeaway: "Flux IA certifié : [📚 Recherche Hybride / MCP] ➔ [🧠 Modèle Ancré] ➔ [🛡️ Prompt Shields]."
            )

        default:
            return CertiGoVisualArchitectureDiagramSpec(
                routeCode: upper,
                headerTitle: "SCHÉMA D'ARCHITECTURE VISUEL · \(upper)",
                compactFlowChain: "[🏛️ Management Group] ➔ [🔑 Subscription] ➔ [📦 Resource Group + 🔒 CanNotDelete] ➔ [👤 Reader / Owner]",
                bricks: [
                    CertiGoVisualArchitectureBrick(
                        id: "az-1",
                        icon: "🏛️",
                        title: "Management Group & Subscription",
                        subtitle: "Gouvernance Azure Policy & budgets hérités par abonnement",
                        pillBadge: "1. GOUVERNANCE",
                        borderHex: "#93c5fd",
                        bgHex: "#eff6ff",
                        textHex: "#1e3a8a"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "az-2",
                        icon: "📦",
                        title: "Resource Group + 🔒 CanNotDelete",
                        subtitle: "Cycle de vie commun & verrou ARM anti-suppression",
                        pillBadge: "2. PROTECTION",
                        borderHex: "#fcd34d",
                        bgHex: "#fffbeb",
                        textHex: "#92400e"
                    ),
                    CertiGoVisualArchitectureBrick(
                        id: "az-3",
                        icon: "👤",
                        title: "RBAC Reader / Owner + Entra PIM",
                        subtitle: "Moindre privilège & élévation Just-In-Time sous contrôle ARM",
                        pillBadge: "3. IDENTITÉ",
                        borderHex: "#34d399",
                        bgHex: "#ecfdf5",
                        textHex: "#065f46"
                    )
                ],
                goldenTakeaway: "Flux Azure certifié : [🏛️ Management Group] ➔ [🔑 Subscription] ➔ [📦 Resource Group + 🔒 CanNotDelete] ➔ [👤 Reader / Owner]."
            )
        }
    }
}

// MARK: - 4. B2 : Readable CLI Terminal Output & Offline AI Coach Instant Synthesis

public enum CertiGoCLITerminalOutputBuilder: Sendable {
    public static func fullCommandLine(for exercise: CertiGoNativeExerciseItem, userInput: String) -> String {
        let prefix = exercise.cliPrefix ?? "az group"
        let token = userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (exercise.expectedCLIInput ?? "lock")
            : userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = exercise.cliSuffix ?? "create --lock-type CanNotDelete -n LockProd -g RG-Prod"
        return "$ \(prefix) \(token) \(suffix)"
    }

    public static func successOutputText(for exercise: CertiGoNativeExerciseItem) -> String {
        "✓ Output : Commande exécutée avec succès (\(exercise.expectedCLIInput ?? "lock") validé · Code retour 0)"
    }
}

public struct CertiGoOfflineCoachSynthesisPayload: Equatable, Sendable {
    public let topicKey: String
    public let routeCode: String
    public let questionPrompt: String
    public let headline: String
    public let comparisonBullet1: String
    public let comparisonBullet2: String
    public let examRule1: String
    public let examRule2: String
    public let recentConceptsReminder: String
    public let closingTip: String
}

public enum CertiGoOfflineAICoachSynthesisEngine: Sendable {
    public static func buildStructuredOfflineSynthesis(
        forTopicKey topicKey: String,
        routeCode: String,
        weakConceptsSummary: [String] = [],
        recentMistakesSummary: [String] = [],
        customQuestion: String? = nil
    ) -> CertiGoOfflineCoachSynthesisPayload {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let reminderText: String = {
            if let firstMistake = recentMistakesSummary.first {
                return "🔁 Dernière notion à revoir en priorité : \(firstMistake)"
            }
            if let firstWeak = weakConceptsSummary.first {
                return "🔁 Notion prioritaire détectée dans ton parcours : \(firstWeak)"
            }
            return "🔁 Notion clé à consolider sur \(upper) : Moindre privilège, isolation privée et haute disponibilité."
        }()

        switch topicKey {
        case "oral-interview":
            return CertiGoOfflineCoachSynthesisPayload(
                topicKey: topicKey,
                routeCode: upper,
                questionPrompt: customQuestion ?? "Simuler un entretien technique d'architecture \(upper)",
                headline: "🎙️ Réponse Synthèse Locale du Coach CertiGo · Entretien Architecture \(upper)",
                comparisonBullet1: "•  1. Structure ta réponse en 3 couches : Identité (Moindre privilège / PIM), Réseau privé (Private Endpoint / VPC Endpoint) et Résilience (Multi-AZ / RA-GRS).",
                comparisonBullet2: "•  2. Compare toujours le coût et l'exploitation : privilégie les services managés PaaS et les jetons temporaires (Managed Identity / Rôle IAM STS).",
                examRule1: "•  Conseil d'examen \(upper) : Élimine immédiatement toute option mentionnant des clés statiques dans le code ou une ouverture publique 0.0.0.0/0.",
                examRule2: "•  \(reminderText)",
                recentConceptsReminder: reminderText,
                closingTip: "Entraîne-toi à justifier ton choix en 30 secondes chrono.\n\nℹ️ Synthèse locale hors-ligne certifiée · Le mode conversationnel libre nécessite la connexion Azure AI Foundry (CG-ERR-1001)."
            )

        case "last-3-errors":
            return CertiGoOfflineCoachSynthesisPayload(
                topicKey: topicKey,
                routeCode: upper,
                questionPrompt: customQuestion ?? "Analyse ma progression et mes erreurs récentes sur \(upper)",
                headline: "🎯 Réponse Synthèse Locale du Coach CertiGo · Bilan & Pièges \(upper)",
                comparisonBullet1: "•  1. Comparatif clé : Autorisation d'identité (RBAC / IAM = QUI agit) vs Conformité des ressources (Policy / SCP = QUOI est autorisé) vs Verrou (CanNotDelete = INTERDICTION de supprimer).",
                comparisonBullet2: "•  2. Réseau & Sécurité : Couche 7 HTTP/WAF (Application Gateway / ALB) vs Couche 4 TCP/UDP (Load Balancer / NLB).",
                examRule1: "•  Conseil d'examen \(upper) : Relis toujours la dernière phrase de l'énoncé pour repérer la contrainte décisive (coût minimal, zéro downtime ou conformité).",
                examRule2: "•  \(reminderText)",
                recentConceptsReminder: reminderText,
                closingTip: "Lance un Sprint Express de 5 questions pour transformer ces rappels en maîtrise durable.\n\nℹ️ Synthèse locale hors-ligne certifiée · Le mode conversationnel libre nécessite la connexion Azure AI Foundry (CG-ERR-1001)."
            )

        case "cli-example":
            let cliLine: String = {
                switch upper {
                case "SAA-C03", "CLF-C02", "AIF-C01":
                    return "aws s3api put-bucket-versioning --bucket prod-eu --versioning-configuration Status=Enabled"
                case "CKA", "CKAD", "CKS":
                    return "ETCDCTL_API=3 etcdctl snapshot save /var/lib/backup/etcd.db --cacert=/etc/kubernetes/pki/etcd/ca.crt"
                case "PDE", "PCA", "ACE":
                    return "bq query --use_legacy_sql=false --dry_run 'SELECT * FROM prod.events WHERE event_date = CURRENT_DATE()'"
                default:
                    return "az group lock create --lock-type CanNotDelete -n LockProd -g RG-Prod"
                }
            }()
            return CertiGoOfflineCoachSynthesisPayload(
                topicKey: topicKey,
                routeCode: upper,
                questionPrompt: customQuestion ?? "Donne-moi un exemple de commande CLI essentielle pour \(upper)",
                headline: "⚡ Réponse Synthèse Locale du Coach CertiGo · Mémo CLI \(upper)",
                comparisonBullet1: "•  1. Commande de référence : \(cliLine)",
                comparisonBullet2: "•  2. Comparatif des options : vérifie toujours la portée (-g / --namespace / --project) et le mode de protection (CanNotDelete vs ReadOnly / --dry_run).",
                examRule1: "•  Conseil d'examen \(upper) : Repère d'abord le verbe d'action principal (create, snapshot save, query --dry_run, modify-db-instance).",
                examRule2: "•  \(reminderText)",
                recentConceptsReminder: reminderText,
                closingTip: "Épingle cette commande dans tes Mémos IA pour la revoir avant l'examen.\n\nℹ️ Synthèse locale hors-ligne certifiée · Le mode conversationnel libre nécessite la connexion Azure AI Foundry (CG-ERR-1001)."
            )

        default:
            return CertiGoOfflineCoachSynthesisPayload(
                topicKey: topicKey,
                routeCode: upper,
                questionPrompt: customQuestion ?? "Explique-moi la différence entre RBAC, Policy et Verrous sur \(upper)",
                headline: "📘 Réponse Synthèse Locale du Coach CertiGo · Comparatif Architecture \(upper)",
                comparisonBullet1: "•  1. RBAC / IAM (Identité) : définit QUI a le droit d'agir (Reader, Contributor, Owner) avec élévation temporaire PIM.",
                comparisonBullet2: "•  2. Policy & Verrous (Gouvernance) : Policy impose QUELLES propriétés sont conformes (régions, tags), et le verrou CanNotDelete interdit toute suppression même à un Owner.",
                examRule1: "•  Conseil d'examen \(upper) : En cas de conflit, un Deny explicite ou un verrou CanNotDelete l'emporte toujours sur un rôle Owner.",
                examRule2: "•  \(reminderText)",
                recentConceptsReminder: reminderText,
                closingTip: "Touche 📌 pour sauvegarder cette fiche comparative dans ton Carnet.\n\nℹ️ Synthèse locale hors-ligne certifiée · Le mode conversationnel libre nécessite la connexion Azure AI Foundry (CG-ERR-1001)."
            )
        }
    }
}

// MARK: - 5. C1 & C2 : 1-Tap Sprint Impulse & Graybiel Striatal Action-Chunking Bracket Ritual

public struct CertiGoActionChunkingBracketRitual: Codable, Equatable, Sendable {
    public var isOpeningBracketActive: Bool
    public var isClosingBracketActive: Bool
    public var openingBracketCount: Int
    public var closingBracketCount: Int
    public var hapticCueTriggeredCount: Int

    public init(
        isOpeningBracketActive: Bool = false,
        isClosingBracketActive: Bool = false,
        openingBracketCount: Int = 0,
        closingBracketCount: Int = 0,
        hapticCueTriggeredCount: Int = 0
    ) {
        self.isOpeningBracketActive = isOpeningBracketActive
        self.isClosingBracketActive = isClosingBracketActive
        self.openingBracketCount = openingBracketCount
        self.closingBracketCount = closingBracketCount
        self.hapticCueTriggeredCount = hapticCueTriggeredCount
    }

    public var openingBannerText: String {
        "⟦ Parenthèse d'ouverture · Focus Architecture activé ⟧"
    }

    public var closingBannerText: String {
        "⟧ Parenthèse de clôture · Acquis consolidés en mémoire ⟦"
    }

    public mutating func triggerOpeningBracket(hapticsEnabled: Bool = true) {
        isOpeningBracketActive = true
        isClosingBracketActive = false
        openingBracketCount += 1
        if hapticsEnabled {
            hapticCueTriggeredCount += 1
            CertiGoHapticDirector.playGentleBracketCue(isOpening: true)
        }
    }

    public mutating func triggerClosingBracket(hapticsEnabled: Bool = true) {
        isOpeningBracketActive = false
        isClosingBracketActive = true
        closingBracketCount += 1
        if hapticsEnabled {
            hapticCueTriggeredCount += 1
            CertiGoHapticDirector.playGentleBracketCue(isOpening: false)
        }
    }
}

public enum CertiGoHapticDirector: Sendable {
    public static func playGentleBracketCue(isOpening: Bool) {
        if isOpening {
            CertiGoHapticsEngine.shared.playButtonPress()
        } else {
            CertiGoHapticsEngine.shared.playLessonCompleteFanfare()
        }
    }
}

// MARK: - 6. D1 : Fogg Facilitator: 90-Second Rescue Sprint (3 Flash Cards) & 3 Local Notifications

public enum CertiGoFoggTriggerKind: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case signal = "signal"
    case facilitator90s = "facilitator_90s"
    case spark48hBonus = "spark_48h_bonus"

    public var id: String { rawValue }
}

public struct CertiGoFoggLocalNotificationSpec: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let kind: CertiGoFoggTriggerKind
    public let title: String
    public let body: String
    public let scheduledTimeText: String
    public let deepLinkAction: String

    public init(
        id: String,
        kind: CertiGoFoggTriggerKind,
        title: String,
        body: String,
        scheduledTimeText: String,
        deepLinkAction: String
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.scheduledTimeText = scheduledTimeText
        self.deepLinkAction = deepLinkAction
    }
}

public enum CertiGoFoggFacilitatorEngine: Sendable {
    public static let rescueFlashCardCount: Int = 3
    public static let rescueDurationSeconds: Int = 90

    /// Automatically highlights the 90-second Rescue Mode in the evening from 20:00 onwards (20:00..23:59 or 00:00..03:59).
    public static func isEveningRescueWindow(
        at date: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 20 || hour < 4
    }

    /// Selects 3 fast, high-clarity Flash multiple-choice cards for the 90-second Rescue Sprint.
    public static func buildRescueThreeFlashExercises(
        forRouteCode routeCode: String,
        lessonId: String,
        lessonTitle: String
    ) -> [CertiGoNativeExerciseItem] {
        let base = CertiGoNativeLessonSessionEngine.defaultExercises(
            forRouteCode: routeCode,
            lessonId: lessonId,
            lessonTitle: lessonTitle
        )
        let adapted = CertiGoNativeLessonSessionEngine.adaptExercisesForExperienceLevel(
            base,
            routeCode: routeCode,
            lessonId: lessonId,
            experienceLevelIndex: 0
        )
        let normalized = adapted.prefix(Self.rescueFlashCardCount).enumerated().map { idx, item -> CertiGoNativeExerciseItem in
            var copy = item
            copy.options = CertiGoSchultzPredictionErrorEngine.normalizeOrderedChoiceBadges(item.options)
            return CertiGoNativeExerciseItem(
                id: "\(copy.id)-flash-\(idx + 1)",
                formatCode: copy.options.isEmpty ? "Q_TYPE_01" : copy.formatCode,
                domainBadge: "⚡ CARTE FLASH \(idx + 1)/3 · \(routeCode.uppercased())",
                subBadge: "MODE SAUVETAGE 90 SECONDES",
                prompt: copy.prompt,
                plainLanguagePrompt: copy.plainLanguagePrompt,
                jargonGlossaryBridge: copy.jargonGlossaryBridge,
                mascotPose: copy.mascotPose,
                options: copy.options,
                examTip: copy.examTip,
                comparisonLeftTitle: copy.comparisonLeftTitle,
                comparisonLeftBullets: copy.comparisonLeftBullets,
                comparisonRightTitle: copy.comparisonRightTitle,
                comparisonRightBullets: copy.comparisonRightBullets,
                comparisonGoldenRule: copy.comparisonGoldenRule,
                conceptId: copy.conceptId,
                conceptTitle: copy.conceptTitle,
                difficulty: min(0.45, copy.difficulty),
                variantGroupId: copy.variantGroupId,
                isReviewReplay: false
            )
        }
        return Array(normalized)
    }

    /// Builds the 3 Fogg local notifications: Signal (chosen anchor time), Facilitateur 90s (21:00 if not done), and Étincelle +20 XP (after 48h).
    public static func buildThreeFoggNotifications(
        routeCode: String,
        preferredAnchorTime: String,
        hasCompletedSessionToday: Bool
    ) -> [CertiGoFoggLocalNotificationSpec] {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanTime = preferredAnchorTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "19:30"
            : preferredAnchorTime

        let signal = CertiGoFoggLocalNotificationSpec(
            id: "fogg-signal-\(upper.lowercased())",
            kind: .signal,
            title: "🔔 Signal CertiGo · Ton créneau \(upper) (\(cleanTime))",
            body: "Ta parenthèse d'architecture de 5 min est prête. Lance ton sprint en 1 seul clic !",
            scheduledTimeText: cleanTime,
            deepLinkAction: "certigo://sprint/one-tap?route=\(upper)"
        )

        let facilitator = CertiGoFoggLocalNotificationSpec(
            id: "fogg-facilitator-21h-\(upper.lowercased())",
            kind: .facilitator90s,
            title: "⚡ Fatigué ce soir ? Mode Sauvetage 90 secondes",
            body: hasCompletedSessionToday
                ? "Objectif déjà validé aujourd'hui ✓ : mode 3 cartes Flash prêt pour demain soir si besoin."
                : "3 cartes Flash sur \(upper) en 90 secondes suffisent pour garder ton rythme sans t'épuiser.",
            scheduledTimeText: "21:00",
            deepLinkAction: "certigo://sprint/rescue-90s?route=\(upper)"
        )

        let spark = CertiGoFoggLocalNotificationSpec(
            id: "fogg-spark-48h-\(upper.lowercased())",
            kind: .spark48hBonus,
            title: "🌱 Étincelle Reprise +20 XP sur \(upper)",
            body: "Reprends en douceur après 48h : +20 XP offerts dès ta première carte validée, zéro pénalité.",
            scheduledTimeText: "+48h",
            deepLinkAction: "certigo://sprint/kind-comeback?route=\(upper)"
        )

        return [signal, facilitator, spark]
    }
}

// MARK: - 7. E1 & E2 : Nunes & Drèze Endowed Progress ("Jamais 0 %") + Eyal Day-One Notebook ("Carnet Jour-J")

public struct CertiGoHullMilestoneStamp: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let index: Int
    public let isStamped: Bool
    public let isEndowedBonus: Bool
    public let label: String

    public init(id: Int, index: Int, isStamped: Bool, isEndowedBonus: Bool, label: String) {
        self.id = id
        self.index = index
        self.isStamped = isStamped
        self.isEndowedBonus = isEndowedBonus
        self.label = label
    }
}

public enum CertiGoEndowedProgressEngine: Sendable {
    public static let totalStampsPerUnit: Int = 10
    public static let firstUnitOnboardingEndowedPercent: Int = 20 // 2/10 jalons
    public static let unlockedUnitTransverseEndowedPercent: Int = 10 // 1/10 jalon

    /// Computes the Nunes & Drèze endowed progress percentage so an active/onboarded module is never stuck at 0%.
    /// - Unit 1 gets at least 20% (2/10 milestones) once onboarding is completed or a lesson is started.
    /// - Any unlocked Unit >= 2 gets at least 10% (1/10 transverse milestone).
    public static func endowedProgressPercent(
        forUnitNumber unitNumber: Int,
        rawPercent: Int,
        isUnlocked: Bool,
        hasCompletedOnboarding: Bool = true
    ) -> Int {
        if unitNumber == 1 && hasCompletedOnboarding {
            return max(rawPercent, firstUnitOnboardingEndowedPercent)
        }
        if unitNumber >= 2 && isUnlocked {
            return max(rawPercent, unlockedUnitTransverseEndowedPercent)
        }
        return rawPercent
    }

    /// Builds the 10 visual stamps (Hull's Goal-Gradient card) for a unit.
    public static func buildTenHullStamps(
        forUnitNumber unitNumber: Int,
        effectivePercent: Int
    ) -> [CertiGoHullMilestoneStamp] {
        let clampedPct = min(100, max(0, effectivePercent))
        let stampedCount = min(10, max(0, Int((Double(clampedPct) / 10.0).rounded())))
        let endowedCount = unitNumber == 1 ? 2 : 1
        return (1...totalStampsPerUnit).map { idx in
            let isStamped = idx <= stampedCount
            let isEndowed = idx <= endowedCount && isStamped
            let label = isEndowed ? "★\(idx)" : "\(idx)"
            return CertiGoHullMilestoneStamp(
                id: idx,
                index: idx,
                isStamped: isStamped,
                isEndowedBonus: isEndowed,
                label: label
            )
        }
    }
}

public struct CertiGoDayOneNotebookEntry: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let routeCode: String
    public let lessonId: String
    public let conceptId: String
    public let title: String
    public let trapSummary: String
    public let goldenRule: String
    public var isPrioritizedForNextSprint: Bool

    public init(
        id: String,
        routeCode: String,
        lessonId: String,
        conceptId: String,
        title: String,
        trapSummary: String,
        goldenRule: String,
        isPrioritizedForNextSprint: Bool = true
    ) {
        self.id = id
        self.routeCode = routeCode
        self.lessonId = lessonId
        self.conceptId = conceptId
        self.title = title
        self.trapSummary = trapSummary
        self.goldenRule = goldenRule
        self.isPrioritizedForNextSprint = isPrioritizedForNextSprint
    }
}

public struct CertiGoDayOneNotebook: Codable, Equatable, Sendable {
    public var entries: [CertiGoDayOneNotebookEntry]

    public init(entries: [CertiGoDayOneNotebookEntry] = []) {
        self.entries = entries
    }

    public func isPinned(lessonId: String, routeCode: String) -> Bool {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return entries.contains {
            $0.routeCode.uppercased() == upper && $0.lessonId.caseInsensitiveCompare(lessonId) == .orderedSame
        }
    }

    @discardableResult
    public mutating func pinTrapForTomorrowCoffee(
        routeCode: String,
        lessonId: String,
        lessonTitle: String,
        conceptId: String,
        trapSummary: String,
        goldenRule: String
    ) -> CertiGoDayOneNotebookEntry {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let entryId = "nb-\(upper.lowercased())-\(lessonId.lowercased())"
        let entry = CertiGoDayOneNotebookEntry(
            id: entryId,
            routeCode: upper,
            lessonId: lessonId,
            conceptId: conceptId,
            title: "\(upper) · \(lessonTitle)",
            trapSummary: trapSummary,
            goldenRule: goldenRule,
            isPrioritizedForNextSprint: true
        )
        entries.removeAll { $0.id == entryId }
        entries.insert(entry, at: 0)
        return entry
    }

    public mutating func removeEntry(id: String) {
        entries.removeAll { $0.id == id }
    }

    /// Prioritizes any pinned notebook concept at index 0 of the next sprint's exercise list (Eyal Phase 4 Investment loop).
    public static func prioritizePinnedConcepts(
        in exercises: [CertiGoNativeExerciseItem],
        routeCode: String,
        notebook: CertiGoDayOneNotebook
    ) -> [CertiGoNativeExerciseItem] {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let prioritizedEntries = notebook.entries.filter {
            $0.routeCode.uppercased() == upper && $0.isPrioritizedForNextSprint
        }
        guard let topEntry = prioritizedEntries.first, !exercises.isEmpty else {
            return exercises
        }

        if let matchIdx = exercises.firstIndex(where: {
            $0.conceptId.caseInsensitiveCompare(topEntry.conceptId) == .orderedSame
                || $0.id.localizedCaseInsensitiveContains(topEntry.lessonId)
        }), matchIdx > 0 {
            var reordered = exercises
            let match = reordered.remove(at: matchIdx)
            reordered.insert(match, at: 0)
            return reordered
        }
        return exercises
    }
}

// MARK: - 8. F1, F2, F3 : Domain Sprint Real Filtering, Cooperative Cohort Challenge & Healthy Stopping Point

public enum CertiGoDomainSprintFilterEngine: Sendable {
    /// Builds 5 domain-targeted exercises for the selected domain in `Examens` without repeating `az-104-qtype01` across domains or tracks.
    public static func exercisesForDomainSprint(
        routeCode: String,
        domainIndex: Int,
        domainTitle: String
    ) -> [CertiGoNativeExerciseItem] {
        let upper = routeCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let safeIdx = max(0, domainIndex)

        // 1. Convert track-specific mock exam questions matching this domain (or rotated by domainIndex) into interactive sprint exercises
        let allExamQuestions = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: upper)
        let domainKeywords = domainTitle
            .lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 4 }

        let matchedExamQuestions = allExamQuestions.filter { q in
            let qDom = q.domainTitle.lowercased()
            let qStem = q.stem.lowercased()
            return domainKeywords.contains { kw in qDom.contains(kw) || qStem.contains(kw) }
        }

        let orderedExamSlice: [CertiGoNativeExamQuestion] = {
            guard !allExamQuestions.isEmpty else { return [] }
            let start = (safeIdx * 3) % allExamQuestions.count
            let rotated = Array(allExamQuestions[start...]) + Array(allExamQuestions[..<start])
            let matchedOnRotated = rotated.filter { cand in
                matchedExamQuestions.contains(where: { $0.id == cand.id })
            }
            let remainingOnRotated = rotated.filter { cand in
                !matchedExamQuestions.contains(where: { $0.id == cand.id })
            }
            return matchedOnRotated + remainingOnRotated
        }()

        let convertedFromExam: [CertiGoNativeExerciseItem] = orderedExamSlice.prefix(5).enumerated().map { offset, eq in
            let options: [CertiGoNativeExerciseItem.OptionItem] = CertiGoSchultzPredictionErrorEngine.normalizeOrderedChoiceBadges(
                eq.choices.map { ch in
                    CertiGoNativeExerciseItem.OptionItem(
                        id: "dom-\(safeIdx + 1)-q\(eq.number)-\(ch.id.lowercased())",
                        badge: ch.badge,
                        title: ch.text,
                        plainLanguageTitle: ch.plainLanguageText,
                        isCorrect: ch.isCorrect,
                        whyWrongOrRight: ch.isCorrect
                            ? "Réponse officielle validée pour le domaine « \(domainTitle) » (\(upper))."
                            : "Cette option ne respecte pas les exigences d'architecture du domaine « \(domainTitle) »."
                    )
                }
            )
            return CertiGoNativeExerciseItem(
                id: "\(upper.lowercased())-dom\(safeIdx + 1)-ex\(offset + 1)-\(eq.number)",
                formatCode: "Q_TYPE_01",
                domainBadge: "🎯 DOMAINE \(safeIdx + 1) · \(domainTitle.uppercased())",
                subBadge: "\(eq.caseStudyBadge) · \(upper)",
                prompt: eq.stem,
                plainLanguagePrompt: eq.plainLanguageStem,
                jargonGlossaryBridge: eq.jargonGlossaryBridge,
                mascotPose: .poseAnalyst,
                options: options,
                examTip: CertiGoNativeRichCatalog.officialExplanation(forExamQuestion: eq),
                conceptId: "\(upper.lowercased()):domain-\(safeIdx + 1):concept-\(offset + 1)",
                conceptTitle: domainTitle,
                difficulty: 0.55 + Double(offset % 3) * 0.10,
                variantGroupId: "\(upper.lowercased())-dom-\(safeIdx + 1)",
                isReviewReplay: false
            )
        }

        if convertedFromExam.count == 5 {
            return convertedFromExam
        }

        let unitNum = min(3, max(1, (safeIdx % 3) + 1))
        let fallbackLessonId = "\(upper)-u\(unitNum)-s\((safeIdx % 3) + 1)"
        let fallback = CertiGoNativeLessonSessionEngine.defaultExercises(
            forRouteCode: upper,
            lessonId: fallbackLessonId,
            lessonTitle: domainTitle
        )
        return Array((convertedFromExam + fallback).prefix(5))
    }
}

public struct CertiGoCooperativeCohortChallenge: Codable, Equatable, Sendable {
    public var cohortTitle: String
    public var validatedConceptsCount: Int
    public var weeklyTargetConceptsCount: Int
    public var userContributedConceptsCount: Int

    public init(
        cohortTitle: String = "Objectif hebdomadaire partagé",
        validatedConceptsCount: Int = 0,
        weeklyTargetConceptsCount: Int = 100,
        userContributedConceptsCount: Int = 0
    ) {
        self.cohortTitle = cohortTitle
        self.validatedConceptsCount = validatedConceptsCount
        self.weeklyTargetConceptsCount = weeklyTargetConceptsCount
        self.userContributedConceptsCount = userContributedConceptsCount
    }

    public var progressRatio: Double {
        guard weeklyTargetConceptsCount > 0 else { return 0.0 }
        return min(1.0, max(0.0, Double(validatedConceptsCount) / Double(weeklyTargetConceptsCount)))
    }

    public var summaryText: String {
        "\(cohortTitle) : \(validatedConceptsCount) / \(weeklyTargetConceptsCount) concepts validés : chaque bonne réponse fait progresser l'objectif !"
    }

    public mutating func recordUserValidatedConcepts(_ count: Int = 1) {
        let added = max(1, count)
        userContributedConceptsCount += added
        validatedConceptsCount = min(weeklyTargetConceptsCount, validatedConceptsCount + added)
    }
}

public enum CertiGoHealthyStoppingPointEngine: Sendable {
    public static let benevolentStoppingBannerTitle: String = "✅ Objectif quotidien atteint !"
    public static let benevolentStoppingBannerBody: String =
        "✅ Objectif quotidien atteint ! Ton cerveau consolide mieux ces architectures au repos. Tu peux fermer CertiGo l'esprit libre (ou continuer en exploration libre)."

    public static func isDailyGoalReached(completedStepsToday: Int) -> Bool {
        completedStepsToday >= 1
    }
}

// MARK: - 9. Typed SwiftUI Subviews for Recommendations A1 .. F3 (Page 17 Minimalist Pill Aesthetic)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// `A1` : Single fluid feedback card at the bottom of the quiz with ultra-concise Page 17 pills (`🎯 Piège d'examen (X %)`), 1-line answer summary, optional `🔎 Approfondir` button, and single-tap `CONTINUER`.
public struct CertiGoFluidErrorFeedbackCardView: View {
    public let isCorrect: Bool
    public let isMasterStroke: Bool
    public let trapBadgeText: String
    public let primaryCorrectTitle: String
    public let conciseExplanationText: String
    public let examTipText: String
    public let onTapDeepenExplanation: () -> Void
    public let onTapContinue: () -> Void

    public init(
        isCorrect: Bool,
        isMasterStroke: Bool = false,
        trapBadgeText: String,
        primaryCorrectTitle: String,
        conciseExplanationText: String,
        examTipText: String,
        onTapDeepenExplanation: @escaping () -> Void,
        onTapContinue: @escaping () -> Void
    ) {
        self.isCorrect = isCorrect
        self.isMasterStroke = isMasterStroke
        self.trapBadgeText = trapBadgeText
        self.primaryCorrectTitle = primaryCorrectTitle
        self.conciseExplanationText = conciseExplanationText
        self.examTipText = examTipText
        self.onTapDeepenExplanation = onTapDeepenExplanation
        self.onTapContinue = onTapContinue
    }

    public var body: some View {
        let bgHex = isCorrect ? "#d7ffb8" : "#ffdfe0"
        let titleHex = isCorrect ? "#3f7d00" : "#ea2b2b"
        let primaryFaceHex = isCorrect ? "#58cc02" : "#ff4b4b"
        let primaryLipHex = isCorrect ? "#46a302" : "#d93838"

        VStack(alignment: .leading, spacing: PrismSpacing.s) {
            HStack(spacing: PrismSpacing.xs) {
                Text(verbatim: isCorrect ? "✓  Exact !" : "✕  À retenir")
                    .font(PrismTypography.figmaFont(size: FigMetrics.seventeen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex(titleHex))
                    .lineLimit(1)

                Spacer()

                if isCorrect && isMasterStroke {
                    Text(verbatim: "⚡ Coup de Maître ×2")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#92400e"))
                        .lineLimit(1)
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, FigMetrics.three)
                        .background(Capsule().fill(PrismColor.figmaHex("#fef3c7")))
                        .accessibilityIdentifier("session-master-stroke-badge")
                }
            }

            if !isCorrect {
                Text(verbatim: "✓ \(primaryCorrectTitle)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#991b1b"))
                    .lineLimit(2)
            } else {
                Text(verbatim: isMasterStroke ? "⚡ +30 XP · < 8s" : "✓ +15 XP")
                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#3f7d00"))
                    .lineLimit(1)
            }

            HStack(spacing: PrismSpacing.m) {
                Button(action: onTapDeepenExplanation) {
                    Text(verbatim: "🔎 Approfondir")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex(titleHex))
                        .lineLimit(1)
                        .frame(width: FigMetrics.oneHundredTwentyEight, height: FigMetrics.fortyEight)
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

                Button(action: onTapContinue) {
                    Text(verbatim: "CONTINUER")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Bold"))
                        .foregroundStyle(PrismColor.onAccent)
                        .lineLimit(1)
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
        .padding(.horizontal, PrismSpacing.xl)
        .padding(.top, PrismSpacing.l)
        .padding(.bottom, PrismSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: PrismRadius.sheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: PrismRadius.sheet,
                style: .continuous
            )
            .fill(PrismColor.figmaHex(bgHex))
            .ignoresSafeArea(.all, edges: .bottom)
        )
    }
}

/// `B1` : Real 3-Brick Connected Visual Architecture Diagram on Déclic Cards (`15`) with Page 17 minimalist single-line pills.
public struct CertiGoVisualArchitectureDiagramView: View {
    public let spec: CertiGoVisualArchitectureDiagramSpec

    public init(routeCode: String, lessonId: String = "") {
        self.spec = CertiGoVisualArchitectureDiagramSpec.diagram(forRouteCode: routeCode, lessonId: lessonId)
    }

    public init(spec: CertiGoVisualArchitectureDiagramSpec) {
        self.spec = spec
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
            HStack {
                Text(verbatim: spec.headerTitle)
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    .lineLimit(1)
                Spacer()
                Text(verbatim: "3 BRIQUES")
                    .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#0369a1"))
                    .padding(.horizontal, PrismSpacing.xs)
                    .padding(.vertical, FigMetrics.two)
                    .background(Capsule().fill(PrismColor.figmaHex("#e0f2fe")))
            }

            ForEach(Array(spec.bricks.enumerated()), id: \.element.id) { index, brick in
                VStack(spacing: FigMetrics.two) {
                    HStack(spacing: PrismSpacing.s) {
                        Text(verbatim: brick.icon)
                            .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Regular"))
                            .frame(width: FigMetrics.thirtyTwo, height: FigMetrics.thirtyTwo)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(PrismColor.surface)
                            )

                        Text(verbatim: brick.title)
                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                            .foregroundStyle(PrismColor.figmaHex(brick.textHex))
                            .lineLimit(1)

                        Spacer(minLength: PrismSpacing.xs)

                        Text(verbatim: brick.pillBadge)
                            .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex(brick.textHex))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, PrismSpacing.m)
                    .padding(.vertical, PrismSpacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .fill(PrismColor.figmaHex(brick.bgHex))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex(brick.borderHex), lineWidth: PrismBorder.standard)
                    )

                    if index + 1 < spec.bricks.count {
                        Text(verbatim: "↓")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                }
            }
        }
        .padding(PrismSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                .fill(PrismColor.figmaHex("#f8fafc"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                .strokeBorder(PrismColor.figmaHex("#cbd5e1"), lineWidth: PrismBorder.standard)
        )
        .accessibilityIdentifier("declic15-visual-architecture-diagram")
    }
}

/// `C1` & `D1` : 1-Tap Direct Sprint Launch Bar + Evening 90-Second Rescue Mode (3 Flash Cards) on Parcours.
public struct CertiGoOneTapSprintBarView: View {
    public let activeRouteCode: String
    public let activeLessonTitle: String
    public let isEveningRescueHighlighted: Bool
    public let onStartOneTapSprint: () -> Void
    public let onStartRescue90sSprint: () -> Void

    public init(
        activeRouteCode: String,
        activeLessonTitle: String,
        isEveningRescueHighlighted: Bool,
        onStartOneTapSprint: @escaping () -> Void,
        onStartRescue90sSprint: @escaping () -> Void
    ) {
        self.activeRouteCode = activeRouteCode
        self.activeLessonTitle = activeLessonTitle
        self.isEveningRescueHighlighted = isEveningRescueHighlighted
        self.onStartOneTapSprint = onStartOneTapSprint
        self.onStartRescue90sSprint = onStartRescue90sSprint
    }

    public var body: some View {
        let trackTheme = CertiGoTrackThemePalette.palette(forRouteCode: activeRouteCode)
        HStack(spacing: PrismSpacing.s) {
            Button(action: onStartOneTapSprint) {
                HStack(spacing: PrismSpacing.xs) {
                    Text(verbatim: "▶ Reprendre mon Sprint")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .lineLimit(1)
                    Spacer(minLength: FigMetrics.four)
                    Text(verbatim: activeRouteCode)
                        .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex(trackTheme.primaryHex))
                        .padding(.horizontal, PrismSpacing.xs)
                        .padding(.vertical, FigMetrics.two)
                        .background(Capsule().fill(PrismColor.surface))
                }
                .padding(.horizontal, PrismSpacing.m)
                .frame(maxWidth: .infinity)
                .frame(height: FigMetrics.forty)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: trackTheme.primaryHex,
                    lipHex: trackTheme.lipHex,
                    cornerRadius: PrismRadius.l,
                    lipDepth: FigMetrics.four
                )
            )
            .accessibilityIdentifier("parcours-one-tap-sprint-button")

            CertiGoRescueSprintBannerView(
                isEveningHighlighted: isEveningRescueHighlighted,
                onTriggerRescue90s: onStartRescue90sSprint
            )
        }
    }
}

/// `D1` : Fogg Facilitator 90-second Rescue Sprint Pill (`⚡ Sprint 90s · 3 cartes`).
public struct CertiGoRescueSprintBannerView: View {
    public let isEveningHighlighted: Bool
    public let onTriggerRescue90s: () -> Void

    public init(
        isEveningHighlighted: Bool,
        onTriggerRescue90s: @escaping () -> Void
    ) {
        self.isEveningHighlighted = isEveningHighlighted
        self.onTriggerRescue90s = onTriggerRescue90s
    }

    public var body: some View {
        Button(action: onTriggerRescue90s) {
            HStack(spacing: FigMetrics.four) {
                Text(verbatim: isEveningHighlighted ? "🌙 Sprint 90s" : "⚡ Sprint 90s · 3 cartes")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#92400e"))
                    .lineLimit(1)
            }
            .padding(.horizontal, PrismSpacing.m)
            .frame(height: FigMetrics.forty)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(PrismColor.figmaHex(isEveningHighlighted ? "#fef3c7" : "#fffbeb"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#f59e0b"), lineWidth: PrismBorder.standard)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("parcours-rescue-90s-button")
    }
}

/// `C1` : Top progressive vignette under the two 44pt floating pills on Parcours.
public struct CertiGoTopProgressiveVignetteView: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [
                PrismColor.figmaHex("#f8fafc"),
                PrismColor.figmaHex("#f8fafc").opacity(0.92),
                PrismColor.figmaHex("#f8fafc").opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: FigMetrics.sixtyEight)
        .allowsHitTesting(false)
    }
}

/// `E1` : Hull 10-Stamp Visual Milestone Card (`Carte de palier à 10 tampons visuels`).
public struct CertiGoHullStampCardView: View {
    public let unitNumber: Int
    public let effectivePercent: Int

    public init(unitNumber: Int, effectivePercent: Int) {
        self.unitNumber = unitNumber
        self.effectivePercent = effectivePercent
    }

    public var body: some View {
        let stamps = CertiGoEndowedProgressEngine.buildTenHullStamps(
            forUnitNumber: unitNumber,
            effectivePercent: effectivePercent
        )

        HStack(spacing: FigMetrics.four) {
            ForEach(stamps) { stamp in
                ZStack {
                    RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                        .fill(
                            stamp.isStamped
                                ? PrismColor.figmaHex("#58cc02")
                                : PrismColor.figmaHex("#ffffff:22")
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: FigMetrics.eighteen)
                    Text(verbatim: stamp.isStamped ? "✓" : "\(stamp.index)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.ten, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                }
            }
        }
        .padding(.top, PrismSpacing.xxs)
        .accessibilityIdentifier("unit-\(unitNumber)-hull-stamp-card")
    }
}

/// `A2`, `C2`, `E2`, `F3` : End-of-Session Neuro-Retention Celebration Stack on Screen 19 (Page 17 minimalist single-line pills).
public struct CertiGoCelebrationNeuroStackView: View {
    public let variableReward: CertiGoVariableRewardItem?
    public let closingBracketText: String
    public let isPinnedToDayOneNotebook: Bool
    public let isDailyGoalReached: Bool
    public let onPinToDayOneNotebook: () -> Void

    public init(
        variableReward: CertiGoVariableRewardItem?,
        closingBracketText: String,
        isPinnedToDayOneNotebook: Bool,
        isDailyGoalReached: Bool,
        onPinToDayOneNotebook: @escaping () -> Void
    ) {
        self.variableReward = variableReward
        self.closingBracketText = closingBracketText
        self.isPinnedToDayOneNotebook = isPinnedToDayOneNotebook
        self.isDailyGoalReached = isDailyGoalReached
        self.onPinToDayOneNotebook = onPinToDayOneNotebook
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
            // A2: Variable Surprise Reward Single-Line Pill Card
            if let reward = variableReward {
                HStack(spacing: PrismSpacing.s) {
                    Text(verbatim: reward.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#92400e"))
                        .lineLimit(1)
                    Spacer()
                    Text(verbatim: "+\(reward.bonusXP) XP")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                        .lineLimit(1)
                }
                .padding(.horizontal, PrismSpacing.m)
                .padding(.vertical, PrismSpacing.s)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.figmaHex("#fffbeb"))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#f59e0b"), lineWidth: PrismBorder.standard)
                )
                .accessibilityIdentifier("celebration19-variable-reward-card")
            }

            // E2: 1-Tap Post-Session Micro-Investment Pill ("📌 Épingler pour demain")
            Button(action: onPinToDayOneNotebook) {
                HStack(spacing: PrismSpacing.xs) {
                    Text(
                        verbatim: isPinnedToDayOneNotebook
                            ? "✓ Épinglé · Carnet Jour-J"
                            : "📌 Épingler pour demain"
                    )
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                    .foregroundStyle(
                        isPinnedToDayOneNotebook
                            ? PrismColor.figmaHex("#15803d")
                            : PrismColor.figmaHex("#1e3a8a")
                    )
                    .lineLimit(1)
                    Spacer(minLength: FigMetrics.four)
                    Text(verbatim: isPinnedToDayOneNotebook ? "✓" : "+")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                }
                .padding(.horizontal, PrismSpacing.m)
                .padding(.vertical, PrismSpacing.s)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(
                            isPinnedToDayOneNotebook
                                ? PrismColor.figmaHex("#dcfce7")
                                : PrismColor.figmaHex("#eff6ff")
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(
                            isPinnedToDayOneNotebook
                                ? PrismColor.figmaHex("#22c55e")
                                : PrismColor.figmaHex("#93c5fd"),
                            lineWidth: PrismBorder.standard
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("celebration19-pin-day-one-notebook-button")

            // F3: Healthy Stopping Point Concise Pill
            if isDailyGoalReached {
                HStack(spacing: PrismSpacing.xs) {
                    Text(verbatim: "✅ Objectif quotidien atteint · Repos mérité")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#065f46"))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, PrismSpacing.m)
                .padding(.vertical, FigMetrics.six)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(PrismColor.figmaHex("#ecfdf5")))
                .overlay(
                    Capsule()
                        .strokeBorder(PrismColor.figmaHex("#34d399"), lineWidth: PrismBorder.thin)
                )
                .accessibilityIdentifier("celebration19-healthy-stopping-point-banner")
            }
        }
        .padding(.horizontal, PrismSpacing.l)
    }
}

/// `F2` : Cooperative Cohort Goal Card on Social / Leagues Tab (`🤝 Objectif Coopératif` : minimalist 1-line bar with 0 fake data).
public struct CertiGoCooperativeCohortCardView: View {
    public let challenge: CertiGoCooperativeCohortChallenge

    public init(challenge: CertiGoCooperativeCohortChallenge) {
        self.challenge = challenge
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
            HStack {
                Text(verbatim: "🤝 \(challenge.cohortTitle) : \(challenge.validatedConceptsCount) / \(challenge.weeklyTargetConceptsCount) concepts")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .lineLimit(1)
                Spacer()
                Text(verbatim: "\(Int((challenge.progressRatio * 100.0).rounded())) %")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#15803d"))
                    .lineLimit(1)
            }

            GeometryReader { geo in
                let rawWidth = geo.size.width.isFinite ? geo.size.width * CGFloat(challenge.progressRatio) : 0
                let w = challenge.validatedConceptsCount > 0 ? max(FigMetrics.eight, rawWidth) : FigMetrics.zero
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PrismColor.figmaHex("#e2e8f0"))
                    if w > 0 {
                        Capsule()
                            .fill(PrismColor.figmaHex("#58cc02"))
                            .frame(width: w)
                    }
                }
            }
            .frame(height: FigMetrics.eight)
        }
        .padding(PrismSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                .fill(PrismColor.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                .strokeBorder(PrismColor.figmaHex("#bae6fd"), lineWidth: PrismBorder.standard)
        )
        .accessibilityIdentifier("social-cooperative-cohort-card")
    }
}
#endif
