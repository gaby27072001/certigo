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
        comparisonGoldenRule: String = "Dès que l'énoncé mentionne « depuis On-Premises via ExpressRoute » ou « IP privée 10.x », choisis toujours Private Endpoint !"
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

/// Interactive lesson session state machine (`Sélection ➔ VÉRIFIER ➔ Bandeau Vert 18 / Rouge 04 ➔ Feuille Explication IA 05 / Comparateur 20 ➔ Célébration 19`).
public struct CertiGoNativeLessonSessionEngine: Equatable, Sendable {
    public let routeCode: String
    public let lessonId: String
    public let lessonTitle: String
    public var isShowingDeclicCard15: Bool
    public let exercises: [CertiGoNativeExerciseItem]
    public var currentExerciseIndex: Int
    public var attemptPhase: CertiGoExerciseAttemptPhase
    public var selectedOptionIds: Set<String>
    public var cliInputText: String
    public var assembledWordBankTokens: [String]
    public var matchedPairsCount: Int
    public var selectedLeftMatchItem: String?
    public var hierarchyOrderedItems: [String]
    public var heartsCount: Int
    public var correctAnswersCount: Int
    public var totalVerifiedCount: Int
    public var isSessionCompleted: Bool

    public init(
        routeCode: String = "AZ-104",
        lessonId: String = "az-104-u1-s3",
        lessonTitle: String = "Rôles RBAC & PIM",
        isShowingDeclicCard15: Bool = true,
        exercises: [CertiGoNativeExerciseItem]? = nil,
        heartsCount: Int = 5
    ) {
        self.routeCode = routeCode
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.isShowingDeclicCard15 = isShowingDeclicCard15
        let resolvedExercises = exercises ?? Self.defaultExercises(forRouteCode: routeCode)
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
        self.correctAnswersCount = 0
        self.totalVerifiedCount = 0
        self.isSessionCompleted = false
    }

    public var currentExercise: CertiGoNativeExerciseItem {
        guard !exercises.isEmpty else {
            return Self.defaultExercises(forRouteCode: routeCode)[0]
        }
        let clamped = min(max(currentExerciseIndex, 0), exercises.count - 1)
        return exercises[clamped]
    }

    public var progressFraction: Double {
        guard !exercises.isEmpty else { return 1.0 }
        if isSessionCompleted { return 1.0 }
        if isShowingDeclicCard15 { return 0.08 }
        let base = Double(currentExerciseIndex) / Double(exercises.count)
        let bonus: Double = {
            switch attemptPhase {
            case .answering: return 0.15 / Double(exercises.count)
            case .checked, .explainingError, .comparingServices: return 0.9 / Double(exercises.count)
            }
        }()
        return min(max(base + bonus, 0.12), 0.98)
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
    public mutating func verifyCurrentAnswer() -> Bool {
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
        } else {
            heartsCount = max(1, heartsCount - 1)
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

    public static func defaultExercises(forRouteCode routeCode: String) -> [CertiGoNativeExerciseItem] {
        [
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
                prompt: "Quel service permet de stocker les clés cryptographiques HSM, secrets et certificats TLS dans un coffre matériel sécurisé ?",
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
                        assetName: "AzureServices/Entra-ID-Protection",
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
                prompt: "Quelle brique placer dans l'emplacement [ ? ] pour filtrer le trafic HTTPS entrant en Couche 7 avec pare-feu WAF OWASP ?",
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
                prompt: "Complète la sous-commande Azure CLI pour créer un verrou empêchant toute suppression accidentelle du groupe RG-Prod :",
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
                prompt: "Assemble dans l'ordre les briques pour créer le réseau virtuel ProdVNet dans le groupe RG-Core :",
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

// MARK: - 2. Rich Multi-Unit, Multi-Certification & Social Data Builders

public enum CertiGoNativeRichCatalog {

    /// Generates 3 full curriculum units (15 sinusoidal lesson islands total) for any certification route code.
    public static func buildThreeUnits(forRouteCode routeCode: String) -> [CertiGoCertificationUnit] {
        let base = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: routeCode)
        let upper = routeCode.uppercased()
        // Sinusoidal horizontal offsets in [-1.0 ... +1.0] for a natural winding Duolingo S-curve
        let offsets: [Double] = [0.0, -0.52, 0.0, 0.52, 0.0]

        let unit1Lessons: [CertiGoPathLessonNode] = [
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s1",
                unitNumber: 1,
                stepIndexInUnit: 0,
                globalIndex: 0,
                title: base.stepTitles[0],
                subtitle: "Fondations & architecture de référence \(upper)",
                state: .completed,
                iconSymbol: "checkmark",
                levelBadge: "Niv. 3/3 ✓",
                horizontalOffsetFactor: offsets[0]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s2",
                unitNumber: 1,
                stepIndexInUnit: 1,
                globalIndex: 1,
                title: base.stepTitles[1],
                subtitle: "Identité, gouvernance & contrôle d'accès",
                state: .completed,
                iconSymbol: "checkmark",
                levelBadge: "Niv. 3/3 ✓",
                horizontalOffsetFactor: offsets[1]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u1-s3",
                unitNumber: 1,
                stepIndexInUnit: 2,
                globalIndex: 2,
                title: base.stepTitles[2],
                subtitle: base.stepPreviewSubtitle,
                state: .active,
                iconSymbol: "shield.lefthalf.filled",
                levelBadge: "Niv. 2/3",
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
                iconSymbol: "lock.fill",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[4]
            )
        ]

        let unit2DomainTitle = base.examDomains.count > 1 ? base.examDomains[1].title : "2. Réseaux Hybrides, Private Link & DNS"
        let unit2Lessons: [CertiGoPathLessonNode] = [
            CertiGoPathLessonNode(
                id: "\(upper)-u2-s1",
                unitNumber: 2,
                stepIndexInUnit: 0,
                globalIndex: 5,
                title: "Isolation PaaS & Private Endpoint",
                subtitle: "NIC privée 10.x & désactivation accès public",
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
                title: "Zones DNS Privées & VNet Link",
                subtitle: "Résolution CNAME vers privatelink.*",
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
                title: "VNet Peering & Transit Hybride",
                subtitle: "Appairage Hub-Spoke non-transitif & BGP",
                state: .locked,
                iconSymbol: "point.3.connected.trianglepath.dotted",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[2]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u2-s4",
                unitNumber: 2,
                stepIndexInUnit: 3,
                globalIndex: 8,
                title: " diagnostiquer un routage UDR & NSG",
                subtitle: "Lab pratique : débloquer un flux HTTPS L7",
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
                title: "Application Gateway WAF & Load Balancer",
                subtitle: "Répartition Couche 7 OWASP vs Couche 4 TCP",
                state: .locked,
                iconSymbol: "shield.checkered",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[4]
            )
        ]

        let unit3DomainTitle = base.examDomains.count > 2 ? base.examDomains[2].title : "3. Résilience, Conteneurs AKS & Supervision"
        let unit3Lessons: [CertiGoPathLessonNode] = [
            CertiGoPathLessonNode(
                id: "\(upper)-u3-s1",
                unitNumber: 3,
                stepIndexInUnit: 0,
                globalIndex: 10,
                title: "Haute Disponibilité Multi-AZ & GRS",
                subtitle: "Redondance LRS, ZRS, GRS & RA-GRS",
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
                title: "Clusters Kubernetes & Autoscaling",
                subtitle: "HPA Pods vs Cluster Autoscaler VMSS",
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
                title: "Sauvegarde Coffre & Site Recovery",
                subtitle: "RTO/RPO, Soft Delete & Cross-Region Restore",
                state: .locked,
                iconSymbol: "arrow.triangle.2.circlepath.circle.fill",
                levelBadge: "Niv. 0/3",
                horizontalOffsetFactor: offsets[2]
            ),
            CertiGoPathLessonNode(
                id: "\(upper)-u3-s4",
                unitNumber: 3,
                stepIndexInUnit: 3,
                globalIndex: 13,
                title: "Déployer une alerte KQL & Action Group",
                subtitle: "Lab pratique : supervision temps réel",
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
                title: "Boss Final · Étude de Cas Pearson VUE",
                subtitle: "Synthèse multi-domaines avant l'Examen Blanc",
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
                progressPercent: 65,
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
                subtitle: "Isolation Private Link, DNS privatelink & WAF Couche 7",
                progressPercent: 20,
                accentHex: "#0284c7",
                lipHex: "#0369a1",
                memoActivity: "Isoler un service PaaS avec Private Endpoint et DNS privé",
                memoKeyTopics: ["Private Endpoint", "Zone privatelink.*", "App Gateway WAF"],
                memoGoldenRule: "Créer un Private Endpoint ne désactive pas publicNetworkAccess par défaut : verrouille le pare-feu PaaS ET lie la zone DNS privée au VNet.",
                lessons: unit2Lessons
            ),
            CertiGoCertificationUnit(
                id: "\(upper)-unit-3",
                unitNumber: 3,
                headerTitle: "UNITÉ 3 · \(unit3DomainTitle.replacingOccurrences(of: "3. ", with: ""))",
                subtitle: "Continuité d'activité, conteneurs & observabilité",
                progressPercent: 0,
                accentHex: "#4f46e5",
                lipHex: "#3730a3",
                memoActivity: "Architecturer la reprise après sinistre et l'autoscaling",
                memoKeyTopics: ["RA-GRS / ZRS", "Cluster Autoscaler", "Azure Site Recovery"],
                memoGoldenRule: "Pour garantir la lecture dans une seconde région pendant une panne régionale complète, choisis toujours RA-GRS.",
                lessons: unit3Lessons
            )
        ]
    }

    /// 12 leaderboard members for Social Screen 07 (`Podium Semaine`).
    public static let defaultLeaderboardMembers: [CertiGoLeaderboardMember] = [
        .init(id: "lb-1", rank: 1, displayName: "Toi (Gabriel)", initials: "GC", routeBadge: "AZ-104 · SAA-C03", xpPoints: 1480, streakDays: 14, isCurrentUser: true, avatarHex: "#0078d4"),
        .init(id: "lb-2", rank: 2, displayName: "Sarah L.", initials: "SL", routeBadge: "AZ-104 · AI-102", xpPoints: 1390, streakDays: 19, avatarHex: "#7c3aed"),
        .init(id: "lb-3", rank: 3, displayName: "Thomas M.", initials: "TM", routeBadge: "SAA-C03 · CKA", xpPoints: 1260, streakDays: 11, avatarHex: "#d97706"),
        .init(id: "lb-4", rank: 4, displayName: "Inès K.", initials: "IK", routeBadge: "AI-102 · GH-300", xpPoints: 1185, streakDays: 9, avatarHex: "#059669"),
        .init(id: "lb-5", rank: 5, displayName: "Maxime R.", initials: "MR", routeBadge: "AZ-305 · AZ-104", xpPoints: 1120, streakDays: 15, avatarHex: "#2563eb"),
        .init(id: "lb-6", rank: 6, displayName: "Clara V.", initials: "CV", routeBadge: "GH-300 · CCA-F", xpPoints: 1045, streakDays: 8, avatarHex: "#db2777"),
        .init(id: "lb-7", rank: 7, displayName: "Yanis B.", initials: "YB", routeBadge: "ACE · PCA", xpPoints: 980, streakDays: 7, avatarHex: "#0284c7"),
        .init(id: "lb-8", rank: 8, displayName: "Léa D.", initials: "LD", routeBadge: "AZ-900 · AI-102", xpPoints: 930, streakDays: 12, avatarHex: "#4f46e5"),
        .init(id: "lb-9", rank: 9, displayName: "Hugo P.", initials: "HP", routeBadge: "CKA · TF-003", xpPoints: 875, streakDays: 6, avatarHex: "#0d9488"),
        .init(id: "lb-10", rank: 10, displayName: "Camille T.", initials: "CT", routeBadge: "SAA-C03 · CLF-C02", xpPoints: 820, streakDays: 5, avatarHex: "#ea580c"),
        .init(id: "lb-11", rank: 11, displayName: "Antoine G.", initials: "AG", routeBadge: "SC-300 · AZ-104", xpPoints: 760, streakDays: 4, avatarHex: "#dc2626"),
        .init(id: "lb-12", rank: 12, displayName: "Nora S.", initials: "NS", routeBadge: "PDE · AI-GEMINI", xpPoints: 710, streakDays: 6, avatarHex: "#9333ea")
    ]

    /// 12 friends for Social Screen 25 (`Mes Amis (12)`).
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

    /// 12 realistic Pearson VUE mock exam questions for Screen 23 & Report Screen 24.
    public static func buildExamQuestions(forRouteCode routeCode: String) -> [CertiGoNativeExamQuestion] {
        let upper = routeCode.uppercased()
        return [
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
}

// MARK: - 3. Complete MVVM Native App State Engine (`CertiGoNativeAppState`)

public struct CertiGoNativeAppState: Equatable, Sendable {
    public var selectedTab: CertiGoNativeTab = .parcours
    public var activeRouteCode: String = "AZ-104"
    public var selectedVendorInPopover: String = "microsoft"
    public var selectedMimoFilter: CertiGoMimoRailFilter = .allUnits

    // Live gamification counters & FSRS mastery
    public var streakDays: Int = 14
    public var gemsCount: Int = 480
    public var heartsCount: Int = 5
    public var completedStepsTotal: Int = 42
    public var cortexMasteryByConceptId: [String: ConceptMastery] = [:]

    // Dynamic 3-unit (15-node) curriculum per certification route
    public var unitsByRouteCode: [String: [CertiGoCertificationUnit]] = [
        "AZ-104": CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: "AZ-104")
    ]

    // Overlays, Popovers, Bottom Sheets & FullScreenCovers
    public var showCoursePopover02: Bool = false
    public var activeStepSheet: CertiGoStepSheetMode?
    public var showExamLaunchSheet22: Bool = false
    public var showProPaywallSheet27: Bool = false
    public var showMultiTrackSelectorSheet: Bool = false
    public var isPresentingLessonSession: Bool = false
    public var isPresentingTimedExam23: Bool = false
    public var isPresentingExamReport24: Bool = false
    public var isPresentingOnboardingFlow: Bool = false

    // Active lesson session engine
    public var lessonSession: CertiGoNativeLessonSessionEngine = CertiGoNativeLessonSessionEngine()

    // Timed Mock Exam (Screen 23 & Report 24)
    public var examQuestions: [CertiGoNativeExamQuestion] = CertiGoNativeRichCatalog.buildExamQuestions(forRouteCode: "AZ-104")
    public var currentExamQuestionIndex: Int = 2 // Starts on Q3 (Contoso Key Vault) or Q1
    public var selectedExamChoiceByQuestionNumber: [Int: String] = [
        1: "B", 2: "A", 3: "B", 4: "B", 5: "D",
        6: "A", 7: "B", 8: "B", 9: "A", 10: "B"
    ]
    public var flaggedExamQuestionNumbers: Set<Int> = [2, 7]
    public var remainingExamSeconds: Int = 5399 // 89:59 real countdown
    public var examReportCarouselIndex: Int = 0
    public var lastComputedExamScoreOutOf1000: Int = 785

    // Hub IA (06, 06B, 06C, 06D)
    public var isAIDrawerOpen06D: Bool = false
    public var isShowingVoiceLive06C: Bool = false
    public var isVoiceLiveListening: Bool = true
    public var voiceLiveTranscriptIndex: Int = 0
    public var aiDrawerSearchQuery: String = ""
    public var aiDraftMessage: String = ""
    public var chatTurns: [CertiGoChatTurn] = []
    public var aiThreads: [CertiGoAIThreadItem] = CertiGoNativeRichCatalog.defaultAIThreads

    // Social (07 & 25)
    public var selectedSocialSubTab: Int = 0 // 0 = Podium Semaine (07), 1 = Mes Amis (25)
    public var friendSearchQuery: String = ""
    public var isInviteLinkCopied: Bool = false
    public var leaderboardMembers: [CertiGoLeaderboardMember] = CertiGoNativeRichCatalog.defaultLeaderboardMembers
    public var friends: [CertiGoFriendItem] = CertiGoNativeRichCatalog.defaultFriends

    // Moi, Stats Pro (08B), Settings (28) & Onboarding (OB-01..08B)
    public var selectedRadarAxisIndex: Int = 0
    public var statsTimeRangeLabel: String = "30 jours ▾"
    public var settingsLanguageIndex: Int = 0
    public var settingsExamModeIndex: Int = 0
    public var settingsCoachVoiceIndex: Int = 0
    public var settingsExplanationStyleIndex: Int = 0
    public var settingsPushRemindersOn: Bool = true
    public var settingsDailyRadarOn: Bool = true
    public var settingsHapticsOn: Bool = true
    public var onboardingStepIndex: Int = 0

    public init() {}

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
            if let found = unit.lessons.first(where: { $0.id == lessonId }) {
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

    public mutating func startLessonSession(forLessonId lessonId: String? = nil, skipDeclic15: Bool = false) {
        let resolvedNode = lessonId.flatMap { lessonNode(withId: $0) } ?? activeLessonNode
        activeStepSheet = nil
        lessonSession = CertiGoNativeLessonSessionEngine(
            routeCode: activeRouteCode,
            lessonId: resolvedNode.id,
            lessonTitle: resolvedNode.title,
            isShowingDeclicCard15: !skipDeclic15,
            heartsCount: heartsCount
        )
        isPresentingLessonSession = true
    }

    /// Unlocks the next node on the dynamic winding path when the user finishes a lesson!
    public mutating func completeActiveLessonSessionAndUnlockNextNode(now: Date = Date()) {
        let upper = activeRouteCode.uppercased()
        var units = unitsByRouteCode[upper] ?? CertiGoNativeRichCatalog.buildThreeUnits(forRouteCode: upper)

        var flatNodes = units.flatMap(\.lessons)
        let targetIndex = flatNodes.firstIndex(where: { $0.id == lessonSession.lessonId })
            ?? flatNodes.firstIndex(where: { $0.state == .active })
            ?? 0

        // Mark completed node as .completed
        flatNodes[targetIndex].state = .completed

        // If no other node is currently .active, promote the next non-completed node to .active
        if !flatNodes.contains(where: { $0.state == .active }) {
            if let nextIdx = flatNodes.indices.first(where: { $0 > targetIndex && flatNodes[$0].state != .completed }) {
                flatNodes[nextIdx].state = .active
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
        gemsCount += 15
        completedStepsTotal += 1

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
        lastComputedExamScoreOutOf1000 = min(1000, max(200, scaled))
        isPresentingTimedExam23 = false
        examReportCarouselIndex = 0
        isPresentingExamReport24 = true
    }

    // MARK: Multi-Turn AI Coach Hub (06, 06B, 06C, 06D)

    public var filteredAIThreads: [CertiGoAIThreadItem] {
        let q = aiDrawerSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return aiThreads }
        return aiThreads.filter {
            $0.title.lowercased().contains(q)
                || $0.subtitle.lowercased().contains(q)
                || $0.routeBadge.lowercased().contains(q)
        }
    }

    public mutating func openAITopic(_ topicKey: String, customUserQuestion: String? = nil) {
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
            closingTip: payload.closing
        )
        chatTurns.append(turn)
        isAIDrawerOpen06D = false
    }

    public mutating func sendAIMessage(_ rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
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
        friendSearchQuery = ""
    }
}

// MARK: - 4. Native SwiftUI Components, 3D Tactile ButtonStyle & Dynamic Views

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

private enum FigMetrics {
    static let zero: CGFloat = 0
    static let one: CGFloat = 1
    static let two: CGFloat = 2
    static let three: CGFloat = 3
    static let four: CGFloat = 4
    static let five: CGFloat = 5
    static let six: CGFloat = 6
    static let eight: CGFloat = 8
    static let ten: CGFloat = 10
    static let twelve: CGFloat = 12
    static let fourteen: CGFloat = 14
    static let sixteen: CGFloat = 16
    static let eighteen: CGFloat = 18
    static let twenty: CGFloat = 20
    static let twentyTwo: CGFloat = 22
    static let twentyFour: CGFloat = 24
    static let twentyEight: CGFloat = 28
    static let thirtyTwo: CGFloat = 32
    static let thirtySix: CGFloat = 36
    static let forty: CGFloat = 40
    static let fortyFour: CGFloat = 44
    static let fortyEight: CGFloat = 48
    static let fifty: CGFloat = 50
    static let fiftyTwo: CGFloat = 52
    static let fiftySix: CGFloat = 56
    static let sixty: CGFloat = 60
    static let sixtyFour: CGFloat = 64
    static let sixtyEight: CGFloat = 68
    static let seventyTwo: CGFloat = 72
    static let seventySix: CGFloat = 76
    static let eighty: CGFloat = 80
    static let eightyFour: CGFloat = 84
    static let eightyEight: CGFloat = 88
    static let ninetySix: CGFloat = 96
    static let oneHundred: CGFloat = 100
    static let oneHundredTen: CGFloat = 110
    static let oneHundredTwenty: CGFloat = 120
    static let oneHundredForty: CGFloat = 140
    static let oneHundredFifty: CGFloat = 150
    static let oneHundredSixty: CGFloat = 160
    static let oneHundredEighty: CGFloat = 180
    static let twoHundred: CGFloat = 200
    static let twoHundredTwenty: CGFloat = 220
    static let twoHundredForty: CGFloat = 240
    static let twoHundredSixty: CGFloat = 260
    static let twoHundredEighty: CGFloat = 280
    static let threeHundred: CGFloat = 300
    static let threeHundredTwenty: CGFloat = 320
    static let pathRowHeight: CGFloat = 118
    static let pathMaxHorizontalOffset: CGFloat = 86
    static let bottomBarTotalClearance: CGFloat = 110
    static let toggleWidth: CGFloat = 48
    static let toggleHeight: CGFloat = 28
    static let toggleKnob: CGFloat = 24
    static let radarSize: CGFloat = 190
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

        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(PrismColor.figmaHex(lipHex))
                .offset(y: currentLip + yOffset)

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
        }
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

    public var body: some View {
        let totalHeight = CGFloat(max(1, lessons.count)) * FigMetrics.pathRowHeight
        ZStack {
            // Upcoming grey S-curve background track
            Path { path in
                guard lessons.count >= 2 else { return }
                path.move(to: centerPoint(for: 0))
                for idx in 0..<(lessons.count - 1) {
                    let p0 = centerPoint(for: idx)
                    let p1 = centerPoint(for: idx + 1)
                    let midY = (p0.y + p1.y) * 0.5
                    path.addCurve(
                        to: p1,
                        control1: CGPoint(x: p0.x, y: midY),
                        control2: CGPoint(x: p1.x, y: midY)
                    )
                }
            }
            .stroke(
                PrismColor.figmaHex("#dce4f0"),
                style: StrokeStyle(lineWidth: PrismSize.pathTrackStroke, lineCap: .round, lineJoin: .round)
            )

            // Validated green S-curve segment up to the active/completed lesson
            Path { path in
                guard lessons.count >= 2 else { return }
                path.move(to: centerPoint(for: 0))
                for idx in 0..<(lessons.count - 1) {
                    let current = lessons[idx]
                    let next = lessons[idx + 1]
                    guard current.state == .completed && (next.state == .completed || next.state == .active) else {
                        break
                    }
                    let p0 = centerPoint(for: idx)
                    let p1 = centerPoint(for: idx + 1)
                    let midY = (p0.y + p1.y) * 0.5
                    path.addCurve(
                        to: p1,
                        control1: CGPoint(x: p0.x, y: midY),
                        control2: CGPoint(x: p1.x, y: midY)
                    )
                }
            }
            .stroke(
                PrismColor.figmaHex("#58cc02"),
                style: StrokeStyle(lineWidth: PrismSize.pathTrackStroke, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: containerWidth, height: totalHeight)
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
            floatingBottomTabBar

            // OVERLAY 1: Popover 02 (Course & Brand Switcher)
            if appState.showCoursePopover02 {
                popover02OverlayView
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topLeading)))
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
        }
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        .sheet(isPresented: $appState.showProPaywallSheet27) {
            certiGoProSheet27View
        }
        .sheet(isPresented: $appState.showMultiTrackSelectorSheet) {
            multiTrackSelectorSheetOB03View
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

            // Center 3D AI Hub Orb Button (`✦`)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                    appState.selectedTab = .hubIA
                    router.selectedTab = .search
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    PrismColor.figmaHex("#0078d4"),
                                    PrismColor.figmaHex("#0284c7")
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: FigMetrics.fifty, height: FigMetrics.fifty)
                        .shadow(
                            color: PrismColor.figmaHex("#0078d4:35"),
                            radius: FigMetrics.ten,
                            x: FigMetrics.zero,
                            y: FigMetrics.four
                        )

                    Text(verbatim: "✦")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
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

    // MARK: - TAB 1: Parcours (`01`) — Dynamic Winding S-Curve, Mimo Rail & 3 Full Units (15 Lessons)

    private var parcoursTab01View: some View {
        let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: appState.activeRouteCode)
        return VStack(spacing: .zero) {
            // Fixed Top Header Bar (`[Logo | AZ-104 ▾]` + `[🔥 14  💎 480  ❤️ 5]`)
            HStack(spacing: PrismSpacing.s) {
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showCoursePopover02.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.s) {
                        CertiGoBrandLogoView(vendorId: curriculum.vendorId, size: PrismSize.brandS)
                        Text(verbatim: "\(appState.activeRouteCode) ▾")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
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
                .accessibilityIdentifier("parcours-course-switcher-button")

                Spacer(minLength: PrismSpacing.xs)

                // Gamification Pill (`🔥 14  💎 480  ❤️ 5`)
                HStack(spacing: PrismSpacing.m) {
                    Text(verbatim: "🔥 \(appState.streakDays)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#ea580c"))
                    Text(verbatim: "💎 \(appState.gemsCount)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                    Text(verbatim: "❤️ \(appState.heartsCount)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#e11d48"))
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
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.s)
            .padding(.bottom, PrismSpacing.xs)
            .background(PrismColor.figmaHex("#f7f9fc"))

            // Lead-Architect Rule 1: Horizontal Mimo Rail (`ScrollView(.horizontal)` + `LazyHStack`)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PrismSpacing.s) {
                    ForEach(CertiGoMimoRailFilter.allCases) { chip in
                        let isSelected = appState.selectedMimoFilter == chip
                        Button {
                            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                if chip == .examPrep {
                                    appState.selectedTab = .examens
                                } else {
                                    appState.selectedMimoFilter = chip
                                }
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.xs) {
                                if chip == .allUnits {
                                    CertiGoOfficialCrestView(routeCode: appState.activeRouteCode, size: PrismSize.brandS)
                                }
                                Text(verbatim: chip.rawValue)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                    .foregroundStyle(
                                        isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#334155")
                                    )
                            }
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .fill(
                                        isSelected
                                            ? PrismColor.figmaHex("#0078d4")
                                            : PrismColor.surface
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? PrismColor.figmaHex("#0078d4") : PrismColor.figmaHex("#e2e8f0"),
                                        lineWidth: PrismBorder.standard
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.xs)
            }
            .background(PrismColor.figmaHex("#f7f9fc"))

            // Lead-Architect Rule 1: Native Vertical ScrollView + LazyVStack over the 3 Units (15 Winding Nodes)
            GeometryReader { geo in
                let stageWidth = max(geo.size.width - PrismSpacing.l * 2, FigMetrics.twoHundredEighty)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PrismSpacing.xl) {
                        ForEach(appState.filteredUnitsForMimoRail) { unit in
                            unitSectionView(unit: unit, stageWidth: stageWidth)
                        }
                    }
                    .padding(.horizontal, PrismSpacing.l)
                    .padding(.top, PrismSpacing.s)
                    .padding(.bottom, FigMetrics.bottomBarTotalClearance)
                }
            }
            .background(PrismColor.figmaHex("#f7f9fc"))
        }
    }

    private func unitSectionView(unit: CertiGoCertificationUnit, stageWidth: CGFloat) -> some View {
        VStack(spacing: PrismSpacing.l) {
            // 3D Unit Header Banner (`UNITÉ 1 · Identité Entra ID` + `65%` ring + `📖` Memo button)
            HStack(spacing: PrismSpacing.m) {
                ZStack {
                    Circle()
                        .stroke(PrismColor.figmaHex("#ffffff:30"), lineWidth: FigMetrics.four)
                        .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                    Circle()
                        .trim(from: 0, to: CGFloat(unit.progressPercent) / 100.0)
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
                        sinuousLessonRowView(lesson: lesson, stageWidth: stageWidth)
                            .frame(width: stageWidth, height: FigMetrics.pathRowHeight)
                    }
                }
            }
            .frame(width: stageWidth, height: totalStageHeight)
        }
    }

    @ViewBuilder
    private func sinuousLessonRowView(lesson: CertiGoPathLessonNode, stageWidth: CGFloat) -> some View {
        let xOffset = CGFloat(lesson.horizontalOffsetFactor) * FigMetrics.pathMaxHorizontalOffset

        if lesson.state == .miniLab {
            // Interactive 3D Mini-Lab Card (`🧪 MINI-LAB PRATIQUE`)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                    appState.startLessonSession(forLessonId: lesson.id, skipDeclic15: true)
                }
            } label: {
                HStack(spacing: PrismSpacing.m) {
                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                        Text(verbatim: "🧪 MINI-LAB PRATIQUE")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0284c7"))
                        Text(verbatim: lesson.title)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                            .lineLimit(1)
                    }
                    Spacer(minLength: PrismSpacing.xs)
                    Text(verbatim: "▶")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                        .foregroundStyle(PrismColor.onAccent)
                        .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
                        .background(Circle().fill(PrismColor.figmaHex("#0284c7")))
                }
                .padding(.horizontal, PrismSpacing.l)
                .padding(.vertical, PrismSpacing.m)
                .frame(width: FigMetrics.twoHundredSixty)
            }
            .buttonStyle(
                CertiGoTactile3DButtonStyle(
                    faceHex: "#f0f9ff",
                    lipHex: "#38bdf8",
                    strokeHex: "#38bdf8",
                    cornerRadius: PrismRadius.l,
                    lipDepth: FigMetrics.four
                )
            )
            .offset(x: xOffset * 0.35)
            .accessibilityIdentifier("path-minilab-\(lesson.id)")
        } else {
            ZStack {
                // Mascot Blason 1A (`angle34LeftPath`) dynamically anchored next to the `.active` node!
                if lesson.state == .active {
                    CertiGoMascotView(pose: .angle34LeftPath, size: PrismSize.mascotPath)
                        .offset(x: xOffset - FigMetrics.ninetySix, y: -FigMetrics.six)
                }

                // 3D Island Node Button + Label Pill
                VStack(spacing: PrismSpacing.xs) {
                    if lesson.state == .active {
                        Text(verbatim: "CONTINUER")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            .padding(.horizontal, PrismSpacing.s)
                            .padding(.vertical, PrismSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(PrismColor.surface)
                                    .shadow(
                                        color: PrismColor.figmaHex("#0078d4:22"),
                                        radius: FigMetrics.six,
                                        x: FigMetrics.zero,
                                        y: FigMetrics.two
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .strokeBorder(PrismColor.figmaHex("#bae6fd"), lineWidth: PrismBorder.standard)
                            )
                    }

                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            appState.openStepPreviewSheet(forLessonId: lesson.id)
                        }
                    } label: {
                        ZStack {
                            if lesson.state == .active {
                                Circle()
                                    .stroke(PrismColor.figmaHex("#38bdf8:45"), lineWidth: FigMetrics.six)
                                    .frame(width: PrismSize.pathNodeRing, height: PrismSize.pathNodeRing)
                                    .scaleEffect(activeNodePulse ? 1.07 : 0.96)
                            }

                            Image(systemName: lesson.state == .completed ? "checkmark" : lesson.iconSymbol)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Black"))
                                .foregroundStyle(
                                    lesson.state == .locked
                                        ? PrismColor.figmaHex("#94a3b8")
                                        : PrismColor.onAccent
                                )
                                .frame(
                                    width: lesson.state == .active ? PrismSize.pathNodeActive : PrismSize.pathNode,
                                    height: lesson.state == .active ? PrismSize.pathNodeActive : PrismSize.pathNode
                                )
                        }
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: nodeFaceHex(for: lesson.state),
                            lipHex: nodeLipHex(for: lesson.state),
                            cornerRadius: PrismRadius.pathNodeActive,
                            lipDepth: FigMetrics.six
                        )
                    )
                    .accessibilityIdentifier("path-node-\(lesson.id)")

                    Text(verbatim: lesson.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                        .foregroundStyle(
                            lesson.state == .locked
                                ? PrismColor.figmaHex("#64748b")
                                : PrismColor.figmaHex("#0f172a")
                        )
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, PrismSpacing.xxs)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                                .fill(PrismColor.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.stepPill, style: .continuous)
                                .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.hairline)
                        )
                }
                .offset(x: xOffset)
            }
        }
    }

    private func nodeFaceHex(for state: CertiGoLessonNodeState) -> String {
        switch state {
        case .completed: return "#58cc02"
        case .active, .available: return "#0078d4"
        case .miniLab: return "#0284c7"
        case .locked: return "#e2e8f0"
        }
    }

    private func nodeLipHex(for state: CertiGoLessonNodeState) -> String {
        switch state {
        case .completed: return "#46a302"
        case .active, .available: return "#005a9e"
        case .miniLab: return "#0369a1"
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
            ("cisco", "Cisco & K8s")
        ]
        let cards = CertiGoFigmaLiveRuntimeState.popoverCards(forVendor: appState.selectedVendorInPopover)

        return ZStack(alignment: .top) {
            PrismColor.figmaHex("#0f172a:42")
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showCoursePopover02 = false
                    }
                }

            VStack(alignment: .leading, spacing: PrismSpacing.m) {
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
                    LazyHStack(spacing: PrismSpacing.s) {
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
        }
    }

    // MARK: - OVERLAY 2: Floating Step Sheet `03` & Unfolded Memo Sheet `14`

    private func stepFloatingSheet03And14Overlay(mode: CertiGoStepSheetMode) -> some View {
        let lesson = appState.lessonNode(withId: mode.lessonId) ?? appState.activeLessonNode
        let unit = appState.currentUnits.first(where: { $0.unitNumber == lesson.unitNumber }) ?? appState.currentUnits[0]
        let isMemoExpanded: Bool = {
            if case .memo14 = mode { return true }
            return false
        }()

        return ZStack(alignment: .bottom) {
            PrismColor.figmaHex("#0f172a:45")
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.activeStepSheet = nil
                    }
                }

            VStack(spacing: PrismSpacing.m) {
                // Drag Handle
                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                    .fill(PrismColor.figmaHex("#cbd5e1"))
                    .frame(width: FigMetrics.forty, height: FigMetrics.five)
                    .padding(.top, PrismSpacing.xs)

                // Top Header (Centered Shield 3D + Level Badge + Lesson Title & Subtitle)
                VStack(spacing: PrismSpacing.xs) {
                    HStack(spacing: PrismSpacing.xs) {
                        Text(verbatim: lesson.levelBadge)
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            .padding(.horizontal, PrismSpacing.s)
                            .padding(.vertical, PrismSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(PrismColor.figmaHex("#e0f2fe"))
                            )

                        Text(verbatim: "UNITÉ \(unit.unitNumber) · \(appState.activeRouteCode)")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    }

                    Text(verbatim: lesson.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        .multilineTextAlignment(.center)

                    Text(verbatim: lesson.subtitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#475569"))
                        .multilineTextAlignment(.center)
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

                    // 2. Primary CTA (`COMMENCER`)
                    Button {
                        appState.startLessonSession(forLessonId: lesson.id)
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
    }

    // MARK: - TAB 2: Examens (`21`) & Apple Pay Sheet (`22`)

    private var examensTab21View: some View {
        let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: appState.activeRouteCode)
        return VStack(spacing: .zero) {
            // Header (`Examens · AZ-104` + `[AZ-104 ▾]`)
            HStack {
                Text(verbatim: "Examens · \(appState.activeRouteCode)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                Spacer()

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showCoursePopover02.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xs) {
                        CertiGoBrandLogoView(vendorId: curriculum.vendorId, size: PrismSize.brandS)
                        Text(verbatim: "\(appState.activeRouteCode) ▾")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
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
                    // Hero 3D Pearson VUE Mock Exam Card
                    VStack(alignment: .leading, spacing: PrismSpacing.m) {
                        HStack(spacing: PrismSpacing.m) {
                            CertiGoOfficialCrestView(routeCode: appState.activeRouteCode, size: PrismSize.crestCard)

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: "CONDITIONS PEARSON VUE")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#bae6fd"))
                                Text(verbatim: "Examen Blanc Complet (50 Q)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                Text(verbatim: "90 min · Seuil 700/1000 · Dernier : \(appState.lastComputedExamScoreOutOf1000) ✓")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#e0f2fe"))
                            }
                        }

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
                                Text(verbatim: "📊 Rapport")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
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

                    // 5 Official Weighted Exam Domains (Tapping any domain launches a targeted session!)
                    ForEach(0..<curriculum.examDomains.count, id: \.self) { idx in
                        let domain = curriculum.examDomains[idx]
                        Button {
                            appState.startLessonSession(skipDeclic15: true)
                        } label: {
                            HStack(spacing: PrismSpacing.m) {
                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    Text(verbatim: domain.title)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    Text(verbatim: domain.weightText)
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                }
                                Spacer(minLength: PrismSpacing.xs)
                                Text(verbatim: domain.scorePercent)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex(domain.colorHex))
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
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: PrismSpacing.l) {
                        // Top Profile Bar + Settings `⚙️` Button
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

                        // Avatar `GC` + `@gabriel · Membre CertiGo PRO` Badge
                        VStack(spacing: PrismSpacing.s) {
                            ZStack(alignment: .bottomTrailing) {
                                Text(verbatim: "GC")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyEight, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                    .frame(width: PrismSize.avatarLarge, height: PrismSize.avatarLarge)
                                    .background(
                                        Circle().fill(
                                            LinearGradient(
                                                colors: [
                                                    PrismColor.figmaHex("#0078d4"),
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

                            Text(verbatim: "Gabriel Chambaud")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                            Button {
                                appState.showProPaywallSheet27 = true
                            } label: {
                                Text(verbatim: "@gabriel · ✦ Membre CertiGo PRO")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.xs)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                            .fill(PrismColor.figmaHex("#eff6ff"))
                                    )
                            }
                            .buttonStyle(.plain)
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

                        // 3 Gamification Summary Cards (`14 jours`, `42 étapes`, `1er (Or)`)
                        HStack(spacing: PrismSpacing.s) {
                            moiStatCard(icon: "🔥", value: "\(appState.streakDays) jours", label: "Série active")
                            moiStatCard(icon: "⚡", value: "\(appState.completedStepsTotal) étapes", label: "Validées")
                            moiStatCard(icon: "🏆", value: "1er (Or)", label: "Ligue Semaine")
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

                        // Certifications Passeport List (Tapping any opens Detail Screen `26`)
                        VStack(alignment: .leading, spacing: PrismSpacing.m) {
                            Text(verbatim: "MES CERTIFICATIONS EN PARALLÈLE")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))

                            ForEach(["AZ-104", "AZ-900", "SAA-C03", "GH-300", "AI-102", "CKA"], id: \.self) { code in
                                let detail = CertiGoFigmaLiveRuntimeState.profileCertificationDetail(forCode: code)
                                Button {
                                    profileNavPath.append(.certificationDetail26(code: code))
                                } label: {
                                    HStack(spacing: PrismSpacing.m) {
                                        CertiGoOfficialCrestView(routeCode: code, size: FigMetrics.fortyEight)
                                        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                            Text(verbatim: detail.title)
                                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                            Text(verbatim: "Progression : \(detail.progression) · Examen : \(detail.lastMockExam)")
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
                    .padding(.top, PrismSpacing.s)
                    .padding(.bottom, FigMetrics.bottomBarTotalClearance)
                }
                .background(PrismColor.figmaHex("#f8fafc"))
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: CertiGoProfileRoute.self) { route in
                    switch route {
                    case .proStats08B:
                        proStats08BUnifiedView
                    case .certificationDetail26(let code):
                        certificationDetail26View(code: code)
                    case .settings28:
                        settings28View
                    case .systemWidgetsSYS01:
                        CertiGoFigmaExactScreenView(screenId: "SYS-01")
                    case .offlineResilienceRES01:
                        CertiGoFigmaExactScreenView(screenId: "RES-01")
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
            let radarAxes: [(label: String, pct: Int, detail: String)] = [
                ("Identité (92%)", 92, "Entra ID, RBAC, PIM & Accès conditionnel : 92 % de maîtrise."),
                ("Stockage (84%)", 84, "Blob Storage, réplication RA-GRS & clés KMS : 84 % de maîtrise."),
                ("Calcul (78%)", 78, "Machines virtuelles, VMSS & clusters AKS : 78 % de maîtrise."),
                ("Réseau (58%)", 58, "VNet Peering, BGP & App Gateway WAF : 58 % — priorité de révision !"),
                ("Sécurité (88%)", 88, "Key Vault, Private Link & verrous ARM : 88 % de maîtrise.")
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
                        // 1. Exam Fitness Score Hero Card (`84 %` · `⚡ Top 4 % des candidats`)
                        HStack {
                            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                Text(verbatim: "INDICE DE FORME EXAMEN \(appState.activeRouteCode)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#bae6fd"))
                                Text(verbatim: "84 % · Prêt pour Pearson VUE")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                Text(verbatim: "⚡ Top 4 % des candidats cette semaine")
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

                        // 3. 3 Telemetry Cards (`88 % Précision`, `14 sec Rythme`, `94 % Rétention`)
                        HStack(spacing: PrismSpacing.s) {
                            moiStatCard(icon: "🎯", value: "88 %", label: "Précision QCM")
                            moiStatCard(icon: "⚡", value: "14 sec", label: "Rythme / Q")
                            moiStatCard(icon: "🧠", value: "94 %", label: "Rétention FSRS")
                        }

                        // 4. 8-Week Activity Heatmap Grid (`LazyVGrid`)
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            Text(verbatim: "CONSTANCE D'ÉTUDE · HEATMAP 8 SEMAINES")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#64748b"))

                            LazyVGrid(columns: heatmapColumns, spacing: PrismSpacing.xxs) {
                                ForEach(0..<32, id: \.self) { cellIdx in
                                    let hex: String = {
                                        if cellIdx % 7 == 0 { return "#bbf7d0" }
                                        if cellIdx % 3 == 0 { return "#22c55e" }
                                        return "#15803d"
                                    }()
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
                                        .stroke(PrismColor.figmaHex("#22c55e"), lineWidth: FigMetrics.eight)
                                        .frame(width: PrismSize.ringOuter, height: PrismSize.ringOuter)
                                    Circle()
                                        .stroke(PrismColor.figmaHex("#0078d4"), lineWidth: FigMetrics.eight)
                                        .frame(width: PrismSize.ringMiddle, height: PrismSize.ringMiddle)
                                    Circle()
                                        .stroke(PrismColor.figmaHex("#8b5cf6"), lineWidth: FigMetrics.eight)
                                        .frame(width: PrismSize.ringInner, height: PrismSize.ringInner)
                                }

                                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                    Text(verbatim: "●  Régularité : 18 / 15 min/j")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                                    Text(verbatim: "●  Précision QCM : 88 % (Cible 80%)")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                    Text(verbatim: "●  Labs & Oral IA : 6 / 5 séances")
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

                        // 6. Progression Curve `/1000` (`540 ➔ 640 ➔ 730 ➔ 810 / 1000`)
                        VStack(alignment: .leading, spacing: PrismSpacing.s) {
                            HStack {
                                Text(verbatim: "PROGRESSION EXAMEN (/1000)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                                Spacer()
                                Text(verbatim: "810 / 1000 ✓")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#15803d"))
                            }
                            Text(verbatim: "Seuil de réussite officiel Pearson VUE : 700 / 1000")
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#475569"))
                            Text(verbatim: "Sem. 1 (540)   ➔   Sem. 2 (640)   ➔   Sem. 3 (730)   ➔   Sem. 4 (810)")
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

                        // 7. Strengths & Weaknesses (`💪 POINTS FORTS` / `🎯 À TRAVAILLER` + `⚡ Cibler en 5 min`)
                        HStack(alignment: .top, spacing: PrismSpacing.m) {
                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                Text(verbatim: "💪 POINTS FORTS")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#15803d"))
                                Text(verbatim: "• Entra ID & RBAC (94 %)\n• Azure Policy (91 %)\n• Key Vault & KMS (89 %)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#166534"))
                            }
                            .padding(PrismSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.figmaHex("#f0fdf4"))
                            )

                            VStack(alignment: .leading, spacing: PrismSpacing.s) {
                                Text(verbatim: "🎯 À TRAVAILLER")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#b45309"))
                                Text(verbatim: "• VNet Peering & BGP (54 %)\n• App Gateway WAF (61 %)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#92400e"))

                                Button {
                                    appState.startLessonSession(skipDeclic15: false)
                                } label: {
                                    Text(verbatim: "⚡ Cibler en 5 min")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                                        .foregroundStyle(PrismColor.onAccent)
                                        .padding(.horizontal, PrismSpacing.m)
                                        .padding(.vertical, PrismSpacing.xs)
                                        .background(
                                            RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                                .fill(PrismColor.figmaHex("#d97706"))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(PrismSpacing.m)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                                    .fill(PrismColor.figmaHex("#fffbeb"))
                            )
                        }
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
            let detail = CertiGoFigmaLiveRuntimeState.profileCertificationDetail(forCode: code)
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
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            Text(verbatim: detail.title)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twenty, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                .multilineTextAlignment(.center)
                            Text(verbatim: "Progression : \(detail.progression) · Examen Blanc : \(detail.lastMockExam)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#15803d"))
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

                            ForEach(0..<detail.domains.count, id: \.self) { domIdx in
                                let dom = detail.domains[domIdx]
                                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                                    HStack {
                                        Text(verbatim: dom.title)
                                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Extra Bold"))
                                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                        Spacer()
                                        Text(verbatim: dom.percentText)
                                            .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Black"))
                                            .foregroundStyle(PrismColor.figmaHex(dom.colorHex))
                                    }
                                    GeometryReader { barGeo in
                                        let ratio = min(max(CGFloat(dom.barWidth) / 313.0, 0.15), 1.0)
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                                .fill(PrismColor.figmaHex("#e2e8f0"))
                                            RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                                .fill(PrismColor.figmaHex(dom.colorHex))
                                                .frame(width: barGeo.size.width * ratio)
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
                        // Profile Account Row -> Opens CertiGo PRO 27
                        Button {
                            appState.showProPaywallSheet27 = true
                        } label: {
                            HStack(spacing: PrismSpacing.m) {
                                Text(verbatim: "GC")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                                    .foregroundStyle(PrismColor.onAccent)
                                    .frame(width: FigMetrics.fortyEight, height: FigMetrics.fortyEight)
                                    .background(Circle().fill(PrismColor.figmaHex("#0078d4")))

                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    Text(verbatim: "Gabriel Chambaud")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    Text(verbatim: "gabriel@certigo" + ".app · CertiGo PRO Actif")
                                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
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
                                value: langLabel
                            ) {
                                appState.settingsLanguageIndex += 1
                            }
                            settingsActionRow(
                                title: "Mode Examen Blanc (Pearson)",
                                value: examModeLabel
                            ) {
                                appState.settingsExamModeIndex += 1
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
                                value: voiceLabel
                            ) {
                                appState.settingsCoachVoiceIndex += 1
                            }
                            settingsActionRow(
                                title: "Style des explications",
                                value: styleLabel
                            ) {
                                appState.settingsExplanationStyleIndex += 1
                            }
                            settingsActionRow(
                                title: "Widgets iOS 18 & Dynamic Island",
                                value: "Actifs  ›"
                            ) {
                                profileNavPath.append(.systemWidgetsSYS01)
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

                        // Launch Onboarding Flow (`OB-01..08B`)
                        Button {
                            appState.onboardingStepIndex = 0
                            appState.isPresentingOnboardingFlow = true
                        } label: {
                            Text(verbatim: "🔄 Recommencer l'Onboarding (OB-01..08B)")
                                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
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
                    }
                    .padding(.horizontal, PrismSpacing.l)
                    .padding(.bottom, FigMetrics.bottomBarTotalClearance)
                }
                .background(PrismColor.figmaHex("#f8fafc"))
            }
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
                        appState.showProPaywallSheet27 = false
                    } label: {
                        Text(verbatim: "✓ ABONNEMENT CERTIGO PRO ACTIF")
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

    private var examApplePaySheet22Overlay: some View {
        let curriculum = CertiGoLiveTrackCurriculum.curriculum(forRouteCode: appState.activeRouteCode)
        return ZStack(alignment: .bottom) {
            PrismColor.figmaHex("#0f172a:58")
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.showExamLaunchSheet22 = false
                    }
                }

            VStack(spacing: PrismSpacing.l) {
                HStack {
                    Text(verbatim: "SIMULATION OFFICIELLE PEARSON VUE")
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
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
                        .font(PrismTypography.figmaFont(size: FigMetrics.twentyTwo, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    Text(verbatim: curriculum.examOfficialTitle)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
                }

                // Apple-Pay Style Summary Rows
                VStack(spacing: PrismSpacing.s) {
                    applePayInfoRow(label: "FORMAT OFFICIEL", value: "50 items · Études de cas & QCM")
                    applePayInfoRow(label: "CHRONOMÈTRE", value: "90 minutes (Temps réel)")
                    applePayInfoRow(label: "SEUIL D'ADMISSION", value: "700 / 1000 points")
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
            let drawerWidth = min(geo.size.width * 0.85, PrismSize.drawerWidth)
            let pushOffset = appState.isAIDrawerOpen06D ? drawerWidth : FigMetrics.zero

            ZStack(alignment: .leading) {
                if appState.isShowingVoiceLive06C {
                    voiceLive06CView
                        .transition(.opacity)
                } else {
                    // Main Chat View (`06` Welcome or `06B` Multi-Turn Conversation) pushed right when Drawer `06D` opens!
                    VStack(spacing: .zero) {
                        // Top Navigation Header
                        HStack(spacing: PrismSpacing.m) {
                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                                    appState.isAIDrawerOpen06D.toggle()
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                    .frame(width: FigMetrics.fortyFour, height: FigMetrics.fortyFour)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                            .fill(PrismColor.surface)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("hub-ia-hamburger-drawer-button")

                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: "✦ CertiGo IA · Coach \(appState.activeRouteCode)")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Black"))
                                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                                Text(verbatim: "Ancré sur la doc officielle & tes erreurs")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#64748b"))
                            }

                            Spacer(minLength: PrismSpacing.xs)

                            Button {
                                withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                                    appState.chatTurns.removeAll()
                                }
                            } label: {
                                Text(verbatim: "+ Nouvelle")
                                    .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Extra Bold"))
                                    .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                                    .padding(.horizontal, PrismSpacing.m)
                                    .padding(.vertical, PrismSpacing.s)
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

                        // Scrollable Body (`06` Empty Welcome vs `06B` Multi-Turn Thread)
                        ScrollView(.vertical, showsIndicators: false) {
                            if appState.chatTurns.isEmpty {
                                hubIAWelcome06Content
                            } else {
                                hubIAConversation06BContent
                            }
                        }
                        .background(PrismColor.figmaHex("#f8fafc"))

                        // Bottom Input Bar (`TextField` + Send `↑` + Live Voice `[ılı]`)
                        hubIABottomInputBar
                            .padding(.bottom, FigMetrics.eightyEight)
                    }
                    .frame(width: geo.size.width)
                    .offset(x: pushOffset)
                    .disabled(appState.isAIDrawerOpen06D)
                    .overlay(
                        Group {
                            if appState.isAIDrawerOpen06D {
                                PrismColor.figmaHex("#0f172a:32")
                                    .ignoresSafeArea()
                                    .offset(x: pushOffset)
                                    .onTapGesture {
                                        withAnimation(CertiGoMotion.spring(for: .anim04Claude85DrawerPush, reduceMotion: reduceMotion)) {
                                            appState.isAIDrawerOpen06D = false
                                        }
                                    }
                            }
                        }
                    )

                    // 85% Width Claude-Style Drawer (`06D`)
                    if appState.isAIDrawerOpen06D {
                        aiDrawer06DView(width: drawerWidth)
                            .frame(width: drawerWidth)
                            .transition(.move(edge: .leading))
                    }
                }
            }
        }
    }

    private var hubIAWelcome06Content: some View {
        let suggestions: [(icon: String, title: String, subtitle: String, key: String)] = [
            ("📘", "Explique-moi RBAC vs Azure Policy", "Différences, portée & règle de priorité Owner", "rbac-vs-policy"),
            ("🎙️", "Simuler un entretien oral à voix haute", "Cas d'architecture Contoso Key Vault & VNet", "oral-interview"),
            ("🎯", "Analyse mes 3 dernières erreurs", "Diagnostic ciblé +65 pts Pearson VUE", "last-3-errors"),
            ("⚡", "Génère un exemple Azure CLI commenté", "Commandes Private Endpoint, DNS & Verrous", "cli-example")
        ]

        return VStack(spacing: PrismSpacing.l) {
            VStack(spacing: PrismSpacing.s) {
                CertiGoMascotView(pose: .specialistAICoach, size: FigMetrics.ninetySix)
                Text(verbatim: "Bonjour Gabriel,")
                    .font(PrismTypography.figmaFont(size: FigMetrics.twentyFour, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                Text(verbatim: "Comment veux-tu réviser \(appState.activeRouteCode) aujourd'hui ?")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Semi Bold"))
                    .foregroundStyle(PrismColor.figmaHex("#475569"))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, PrismSpacing.l)

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
            ForEach(Array(appState.chatTurns.enumerated()), id: \.element.id) { idx, turn in
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
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))

                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            Text(verbatim: turn.aiBullet1)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#334155"))
                            Text(verbatim: turn.aiBullet2)
                                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#334155"))
                        }

                        // Highlighted Exam Takeaway Box (`💡 À retenir pour l'examen`)
                        VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                            Text(verbatim: "💡 À RETENIR POUR L'EXAMEN")
                                .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                                .foregroundStyle(PrismColor.figmaHex("#1d4ed8"))
                            Text(verbatim: turn.examKeyRule1)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#1e3a8a"))
                            Text(verbatim: turn.examKeyRule2)
                                .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold"))
                                .foregroundStyle(PrismColor.figmaHex("#1e3a8a"))
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

                        // Action Chips: `[📋 Copier]`, `[📖 Sauver en Mémo]`, `[🎯 Quiz]`
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
                                appState.chatTurns[idx].isSavedToMemo = true
                            } label: {
                                Text(verbatim: turn.isSavedToMemo ? "✓ En Mémo" : "📖 Sauver en Mémo")
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
                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                .submitLabel(.send)
                .onSubmit {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        appState.sendAIMessage(appState.aiDraftMessage)
                    }
                }
                .accessibilityIdentifier("hub-ia-textfield")

                if !appState.aiDraftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.sendAIMessage(appState.aiDraftMessage)
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

            // Live Voice Mode Button (`06C`)
            Button {
                withAnimation(CertiGoMotion.spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)) {
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
                .padding(.bottom, FigMetrics.bottomBarTotalClearance)
            }
        }
        .padding(PrismSpacing.l)
        .frame(width: width).frame(maxHeight: .infinity)
        .background(PrismColor.surface)
        .overlay(
            Rectangle()
                .fill(PrismColor.figmaHex("#e2e8f0"))
                .frame(width: PrismBorder.hairline),
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
                        withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                            appState.selectedSocialSubTab = 1
                        }
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

            if appState.selectedSocialSubTab == 0 {
                socialPodium07ScrollView
            } else {
                socialFriends25ScrollView
            }
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
                // 3D Podium Stage (`2e Sarah L.`, `1er Toi (Gabriel) 👑`, `3e Thomas M.`)
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

                // Full 12-Member Leaderboard (`1er` .. `12e`)
                ForEach(appState.leaderboardMembers) { member in
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

                // Invite Link Card (`🔗 Partager mon lien d'invitation`)
                HStack(spacing: PrismSpacing.m) {
                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                        Text(verbatim: "🔗 Partager mon lien d'invitation")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                        Text(verbatim: "Code ami : @gabriel · CG-104")
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    }
                    Spacer()
                    Button {
                        appState.isInviteLinkCopied = true
                        UIPasteboard.general.string = "@gabriel"
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
                .padding(PrismSpacing.m)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .strokeBorder(PrismColor.figmaHex("#e2e8f0"), lineWidth: PrismBorder.standard)
                )

                // 12 Friends List with 3D `👋 Salut` ➔ `👏 Salué ✓` Buttons
                ForEach(appState.filteredFriends) { friend in
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
            .padding(.horizontal, PrismSpacing.l)
            .padding(.top, PrismSpacing.xs)
            .padding(.bottom, FigMetrics.bottomBarTotalClearance)
        }
        .background(PrismColor.figmaHex("#f8fafc"))
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
            if appState.lessonSession.isSessionCompleted {
                celebrationScreen19View
            } else {
                VStack(spacing: .zero) {
                    sessionTopHeaderBar

                    if appState.lessonSession.isShowingDeclicCard15 {
                        declicCard15ScrollView
                    } else {
                        exerciseActiveContentScrollView
                    }
                }
            }

            if !appState.lessonSession.isSessionCompleted && !appState.lessonSession.isShowingDeclicCard15 {
                switch appState.lessonSession.attemptPhase {
                case .answering:
                    verifierBottomBar
                case .checked(let isCorrect):
                    feedbackDrawer18Or04(isCorrect: isCorrect)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .explainingError:
                    explanationSheet05Overlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                case .comparingServices:
                    comparatorSheet20Overlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .fontDesign(.rounded)
        .background(PrismColor.figmaHex("#f8fafc").ignoresSafeArea())
    }

    private var sessionTopHeaderBar: some View {
        HStack(spacing: PrismSpacing.m) {
            Button {
                appState.isPresentingLessonSession = false
            } label: {
                Text(verbatim: "✕")
                    .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                    .frame(width: FigMetrics.thirtySix, height: FigMetrics.thirtySix)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("session-close-button")

            GeometryReader { barGeo in
                let ratio = CGFloat(appState.lessonSession.progressFraction)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                        .fill(PrismColor.figmaHex("#e2e8f0"))
                    RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                        .fill(PrismColor.figmaHex("#58cc02"))
                        .frame(width: max(FigMetrics.sixteen, barGeo.size.width * ratio))
                }
            }
            .frame(height: FigMetrics.fourteen)

            HStack(spacing: PrismSpacing.xxs) {
                Text(verbatim: "❤️")
                Text(verbatim: "\(appState.lessonSession.heartsCount)")
                    .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#ff4b4b"))
            }
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

                    VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                        Text(verbatim: "💡 CARTE DÉCLIC · MICRO-LEÇON 20 SEC")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                        Text(verbatim: "« Attention au piège : créer un Private Endpoint ne désactive PAS l'accès public par défaut ! »")
                            .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
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

                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    Text(verbatim: "COMMENT VERROUILLER L'ISOLATION À 100 %")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))

                    Text(verbatim: "✕  Internet Public  ➔  publicNetworkAccess: Disabled")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#dc2626"))
                        .padding(PrismSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.figmaHex("#fff1f2"))
                        )

                    Text(verbatim: "✓  VNet (10.0.2.4)  ➔  privatelink.blob.core.windows.net")
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                        .padding(PrismSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.figmaHex("#f0fdf4"))
                        )
                }
                .padding(PrismSpacing.l)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.xl, style: .continuous)
                        .fill(PrismColor.surface)
                )

                VStack(alignment: .leading, spacing: PrismSpacing.m) {
                    declicStepRow(
                        title: "1. Désactive l'accès réseau public",
                        detail: "Passe la propriété publicNetworkAccess sur « Disabled » dans le pare-feu de la ressource PaaS."
                    )
                    declicStepRow(
                        title: "2. Lie la zone DNS Privée au VNet",
                        detail: "Crée un Virtual Network Link vers privatelink.* pour résoudre le FQDN en IP privée 10.x."
                    )
                }

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim03Mascot34SpeechBubblePop, reduceMotion: reduceMotion)) {
                        appState.lessonSession.dismissDeclicCard15()
                    }
                } label: {
                    Text(verbatim: "CONTINUER VERS LES EXERCICES")
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
                .accessibilityIdentifier("declic15-continue-button")
            }
            .padding(PrismSpacing.l)
        }
    }

    private func declicStepRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
            Text(verbatim: title)
                .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex("#0f172a"))
            Text(verbatim: detail)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                .foregroundStyle(PrismColor.figmaHex("#475569"))
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

        return ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                HStack(alignment: .center, spacing: PrismSpacing.m) {
                    CertiGoMascotView(pose: ex.mascotPose, size: PrismSize.mascotQuiz)

                    VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                        Text(verbatim: ex.domainBadge)
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                            .padding(.horizontal, PrismSpacing.s)
                            .padding(.vertical, PrismSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.xs, style: .continuous)
                                    .fill(PrismColor.figmaHex("#e0f2fe"))
                            )

                        Text(verbatim: ex.prompt)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    }
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
            HStack(spacing: PrismSpacing.m) {
                Text(verbatim: isMultiChoice && isSelected ? "✓" : opt.badge)
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
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

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: opt.title)
                        .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                        .foregroundStyle(PrismColor.figmaHex(palette.text))
                        .multilineTextAlignment(.leading)
                    if let sub = opt.subtitle {
                        Text(verbatim: sub)
                            .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Semi Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#64748b"))
                    }
                }
                Spacer(minLength: PrismSpacing.xs)
            }
            .padding(PrismSpacing.l)
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
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex(palette.text))
                if let sub = opt.subtitle {
                    Text(verbatim: sub)
                        .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#64748b"))
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
                    .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                    .foregroundStyle(PrismColor.figmaHex("#38bdf8"))

                HStack(spacing: PrismSpacing.xs) {
                    Text(verbatim: ex.cliPrefix ?? "az group")
                        .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold", monospaced: true))
                        .foregroundStyle(PrismColor.onAccent)

                    TextField(
                        text: $appState.lessonSession.cliInputText,
                        prompt: Text(verbatim: "...")
                    ) {
                        Text(verbatim: "...")
                    }
                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black", monospaced: true))
                    .foregroundStyle(PrismColor.figmaHex("#38bdf8"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, PrismSpacing.s)
                    .frame(width: FigMetrics.ninetySix, height: FigMetrics.thirtySix)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .fill(PrismColor.figmaHex("#1e293b"))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .strokeBorder(PrismColor.figmaHex("#38bdf8"), lineWidth: PrismBorder.standard)
                    )
                    .accessibilityIdentifier("session-cli-textfield")

                    Text(verbatim: ex.cliSuffix ?? "create")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Bold", monospaced: true))
                        .foregroundStyle(PrismColor.figmaHex("#94a3b8"))
                        .lineLimit(1)
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
        let headline = isCorrect
            ? "✓  Excellent ! Bonne réponse"
            : "✕  Incorrect · Bonne réponse : \(appState.lessonSession.currentExercise.primaryCorrectOptionTitle)"

        return VStack(alignment: .leading, spacing: PrismSpacing.m) {
            Text(verbatim: headline)
                .font(PrismTypography.figmaFont(size: FigMetrics.sixteen, style: "Black"))
                .foregroundStyle(PrismColor.figmaHex(titleHex))

            Text(verbatim: appState.lessonSession.currentExercise.examTip)
                .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Bold"))
                .foregroundStyle(PrismColor.figmaHex("#1e293b"))

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
        return ZStack(alignment: .bottom) {
            PrismColor.figmaHex("#0f172a:62")
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.lessonSession.closeOverlaySheetToCheckedState()
                    }
                }

            VStack(alignment: .leading, spacing: PrismSpacing.m) {
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

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: "✕ TA RÉPONSE : \(appState.lessonSession.selectedOptionSummaryText)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#e11d48"))
                    Text(verbatim: appState.lessonSession.selectedWhyWrongExplanation)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#881337"))
                }
                .padding(PrismSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.figmaHex("#fff1f2"))
                )

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: "✓ BONNE RÉPONSE : \(ex.primaryCorrectOptionTitle)")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#15803d"))
                    Text(verbatim: appState.lessonSession.correctWhyRightExplanation)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#14532d"))
                }
                .padding(PrismSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                        .fill(PrismColor.figmaHex("#f0fdf4"))
                )

                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: "💡 ASTUCE D'EXAMEN")
                        .font(PrismTypography.figmaFont(size: FigMetrics.twelve, style: "Black"))
                        .foregroundStyle(PrismColor.figmaHex("#0078d4"))
                    Text(verbatim: ex.examTip)
                        .font(PrismTypography.figmaFont(size: FigMetrics.thirteen, style: "Semi Bold"))
                        .foregroundStyle(PrismColor.figmaHex("#1e3a8a"))
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
    }

    private var comparatorSheet20Overlay: some View {
        let ex = appState.lessonSession.currentExercise
        return ZStack(alignment: .bottom) {
            PrismColor.figmaHex("#0f172a:62")
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        appState.lessonSession.closeOverlaySheetToCheckedState()
                    }
                }

            VStack(alignment: .leading, spacing: PrismSpacing.m) {
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
            .padding(.horizontal, PrismSpacing.l)
            .padding(.vertical, PrismSpacing.m)
            .background(PrismColor.surface)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: PrismSpacing.xs) {
                    ForEach(Array(appState.examQuestions.enumerated()), id: \.element.id) { idx, item in
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
            .background(PrismColor.surface)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: PrismSpacing.l) {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        Text(verbatim: q.caseStudyBadge)
                            .font(PrismTypography.figmaFont(size: FigMetrics.eleven, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#2563eb"))
                        Text(verbatim: q.stem)
                            .font(PrismTypography.figmaFont(size: FigMetrics.fifteenOrSixteen, style: "Extra Bold"))
                            .foregroundStyle(PrismColor.figmaHex("#0f172a"))
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
                            HStack(spacing: PrismSpacing.m) {
                                Text(verbatim: choice.badge)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Black"))
                                    .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.figmaHex("#475569"))
                                    .frame(width: PrismSize.optionBadge, height: PrismSize.optionBadge)
                                    .background(
                                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                            .fill(isSelected ? PrismColor.figmaHex("#2563eb") : PrismColor.figmaHex("#f1f5f9"))
                                    )

                                Text(verbatim: choice.text)
                                    .font(PrismTypography.figmaFont(size: FigMetrics.fourteen, style: "Bold"))
                                    .foregroundStyle(isSelected ? PrismColor.figmaHex("#1e40af") : PrismColor.figmaHex("#0f172a"))
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: PrismSpacing.xs)
                            }
                            .padding(PrismSpacing.l)
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                appState.tickExamTimerOneSecond()
            }
        }
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
                            let ratio = min(max(CGFloat(score) / 1000.0, 0.1), 1.0)
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .fill(PrismColor.figmaHex("#1e293b"))
                                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                                    .fill(PrismColor.figmaHex(passed ? "#22c55e" : "#f59e0b"))
                                    .frame(width: geo.size.width * ratio)
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
    }
}

// MARK: - 8. Interactive 7-Step Onboarding Flow (`OB-01..OB-08B`)

public struct CertiGoNativeOnboardingFlowView: View {
    @Binding public var appState: CertiGoNativeAppState
    @Binding public var coordinator: PrismAppShellCoordinatorModel

    private let onboardingNodeIds: [String] = [
        "132:182", "132:264", "132:339", "132:438",
        "132:519", "132:581", "132:877", "132:945"
    ]

    public init(
        appState: Binding<CertiGoNativeAppState>,
        coordinator: Binding<PrismAppShellCoordinatorModel>
    ) {
        self._appState = appState
        self._coordinator = coordinator
    }

    public var body: some View {
        let clamped = min(max(appState.onboardingStepIndex, 0), onboardingNodeIds.count - 1)
        let nodeId = onboardingNodeIds[clamped]

        return ZStack(alignment: .bottom) {
            CertiGoFigmaExactScreenView(
                screenId: nodeId,
                onNavigateToNodeId: { _ in
                    if appState.onboardingStepIndex + 1 < onboardingNodeIds.count {
                        appState.onboardingStepIndex += 1
                    } else {
                        appState.isPresentingOnboardingFlow = false
                    }
                }
            )
            .ignoresSafeArea()

            HStack(spacing: PrismSpacing.m) {
                if appState.onboardingStepIndex > 0 {
                    Button {
                        appState.onboardingStepIndex -= 1
                    } label: {
                        Text(verbatim: "←")
                            .font(PrismTypography.figmaFont(size: FigMetrics.eighteen, style: "Black"))
                            .foregroundStyle(PrismColor.figmaHex("#334155"))
                            .frame(width: FigMetrics.fiftySix, height: PrismSize.primaryButtonHeight)
                    }
                    .buttonStyle(
                        CertiGoTactile3DButtonStyle(
                            faceHex: "#ffffff",
                            lipHex: "#cbd5e1",
                            cornerRadius: PrismRadius.l
                        )
                    )
                }

                Button {
                    if appState.onboardingStepIndex + 1 < onboardingNodeIds.count {
                        appState.onboardingStepIndex += 1
                    } else {
                        appState.isPresentingOnboardingFlow = false
                    }
                } label: {
                    let isLast = appState.onboardingStepIndex + 1 >= onboardingNodeIds.count
                    Text(verbatim: isLast ? "ENTRER DANS CERTIGO ✓" : "CONTINUER (\(clamped + 1)/\(onboardingNodeIds.count))")
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
            .padding(PrismSpacing.l)
        }
        .fontDesign(.rounded)
    }
}

private extension FigMetrics {
    static let eleven: CGFloat = 11
    static let thirteen: CGFloat = 13
    static let fifteenOrSixteen: CGFloat = 15
}
#endif

