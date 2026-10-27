import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Parallel Certification Tracks (13 Tracks) & AI Frontier Tracks (5 Tracks)

public enum CertiGoParallelCertificationTrackID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case az104 = "AZ-104"
    case az900 = "AZ-900"
    case ai102 = "AI-102"
    case az305 = "AZ-305"
    case saaC03 = "SAA-C03"
    case clfC02 = "CLF-C02"
    case ace = "ACE"
    case pca = "PCA"
    case gh300 = "GH-300"
    case cka = "CKA"
    case tf003 = "TF-003"
    case ccna = "CCNA"
    case ccaF = "CCA-F"

    public var id: String { rawValue }
}

public enum CertiGoAIFrontierTrackID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case openAIGPT = "AI-OPENAI"
    case anthropicClaude = "AI-ANTHROPIC"
    case googleGeminiVertex = "AI-GEMINI"
    case microsoftFoundryCopilot = "AI-FOUNDRY"
    case mistralOpenWeight = "AI-MISTRAL"

    public var id: String { rawValue }

    public var officialTitle: String {
        switch self {
        case .openAIGPT:
            return "OpenAI & Architecture GPT"
        case .anthropicClaude:
            return "Anthropic & Claude CCA-F"
        case .googleGeminiVertex:
            return "Google Gemini & Vertex AI"
        case .microsoftFoundryCopilot:
            return "Microsoft Foundry & Copilot"
        case .mistralOpenWeight:
            return "Mistral AI & Modèles Open-Weight"
        }
    }
}

// MARK: - 2. Rich Curriculum Unit & Interactive Format Payloads (Q_TYPE_01 .. Q_TYPE_10)

public struct CertiGoPathStepSpec: Codable, Equatable, Hashable, Sendable, Identifiable {
    public enum StepState: String, Codable, Equatable, Hashable, Sendable {
        case done, active, locked, chest
    }
    public enum RowAlignment: String, Codable, Equatable, Hashable, Sendable {
        case centerRight, leadingRight, trailingLeft, farTrailingLeft
    }

    public let id: String
    public let title: String
    public let subtitle: String?
    public let state: StepState
    public let symbol: String
    public let alignment: RowAlignment

    public init(
        id: String,
        title: String,
        subtitle: String?,
        state: StepState,
        symbol: String,
        alignment: RowAlignment
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.state = state
        self.symbol = symbol
        self.alignment = alignment
    }
}

public struct CertiGoCurriculumUnit: Equatable, Sendable, Identifiable {
    public let id: String
    public let unitNumber: Int
    public let supertitle: String
    public let title: String
    public let examWeightText: String
    public let guideArchitectureLine: String
    public let guideCLICommand: String
    public let guideExamTrap: String
    public let serviceAssetNames: [String]
    public let steps: [CertiGoPathStepSpec]

    public init(
        id: String,
        unitNumber: Int,
        supertitle: String,
        title: String,
        examWeightText: String,
        guideArchitectureLine: String,
        guideCLICommand: String,
        guideExamTrap: String,
        serviceAssetNames: [String],
        steps: [CertiGoPathStepSpec]
    ) {
        self.id = id
        self.unitNumber = unitNumber
        self.supertitle = supertitle
        self.title = title
        self.examWeightText = examWeightText
        self.guideArchitectureLine = guideArchitectureLine
        self.guideCLICommand = guideCLICommand
        self.guideExamTrap = guideExamTrap
        self.serviceAssetNames = serviceAssetNames
        self.steps = steps
    }
}

public struct CertiGoServiceGridOption: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let badge: String
    public let serviceTitle: String
    public let subtitle: String
    public let assetName: String
    public let isCorrect: Bool
    public let explanation: String

    public init(
        id: String,
        badge: String,
        serviceTitle: String,
        subtitle: String,
        assetName: String,
        isCorrect: Bool,
        explanation: String
    ) {
        self.id = id
        self.badge = badge
        self.serviceTitle = serviceTitle
        self.subtitle = subtitle
        self.assetName = assetName
        self.isCorrect = isCorrect
        self.explanation = explanation
    }
}

public struct CertiGoDiagramSlotSpec: Codable, Equatable, Hashable, Sendable {
    public let sourceLabel: String
    public let sourceAssetName: String
    public let missingSlotPrompt: String
    public let targetLabel: String
    public let targetAssetName: String
    public let candidateOptions: [CertiGoServiceGridOption]

    public init(
        sourceLabel: String,
        sourceAssetName: String,
        missingSlotPrompt: String,
        targetLabel: String,
        targetAssetName: String,
        candidateOptions: [CertiGoServiceGridOption]
    ) {
        self.sourceLabel = sourceLabel
        self.sourceAssetName = sourceAssetName
        self.missingSlotPrompt = missingSlotPrompt
        self.targetLabel = targetLabel
        self.targetAssetName = targetAssetName
        self.candidateOptions = candidateOptions
    }
}

public struct CertiGoKeyboardInputSpec: Codable, Equatable, Hashable, Sendable {
    public let commandPrefix: String
    public let placeholder: String
    public let expectedAnswer: String
    public let acceptedAliases: [String]
    public let commandSuffix: String
    public let explanation: String

    public init(
        commandPrefix: String,
        placeholder: String,
        expectedAnswer: String,
        acceptedAliases: [String] = [],
        commandSuffix: String = "",
        explanation: String
    ) {
        self.commandPrefix = commandPrefix
        self.placeholder = placeholder
        self.expectedAnswer = expectedAnswer
        self.acceptedAliases = acceptedAliases
        self.commandSuffix = commandSuffix
        self.explanation = explanation
    }

    public func matches(_ rawInput: String) -> Bool {
        let normalized = rawInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == expectedAnswer.lowercased() {
            return true
        }
        return acceptedAliases.contains { $0.lowercased() == normalized }
    }
}

public struct CertiGoMatchingPairSpec: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let id: String
    public let leftSymbolOrService: String
    public let leftAssetName: String
    public let rightRoleDescription: String

    public init(
        id: String,
        leftSymbolOrService: String,
        leftAssetName: String,
        rightRoleDescription: String
    ) {
        self.id = id
        self.leftSymbolOrService = leftSymbolOrService
        self.leftAssetName = leftAssetName
        self.rightRoleDescription = rightRoleDescription
    }
}

public struct CertiGoArchitectureVerdictSpec: Codable, Equatable, Hashable, Sendable {
    public let flowChainText: String
    public let constraintBanner: String
    public let involvedAssetNames: [String]
    public let verdictOptions: [PrismChoiceOption]

    public init(
        flowChainText: String,
        constraintBanner: String,
        involvedAssetNames: [String],
        verdictOptions: [PrismChoiceOption]
    ) {
        self.flowChainText = flowChainText
        self.constraintBanner = constraintBanner
        self.involvedAssetNames = involvedAssetNames
        self.verdictOptions = verdictOptions
    }
}

public struct CertiGoInteractiveExerciseSpec: Equatable, Sendable, Identifiable {
    public let id: String
    public let trackCode: String
    public let unitId: String
    public let format: CertiGoQuestionFormatID
    public let badgeTitle: String
    public let stem: String
    public let region: PrismRegion
    public let product: BrandProductID
    public let mascotPose: CertiGoMascotPose
    public let primaryAssetName: String
    public let optionAssetNames: [String]
    public let serviceGridOptions: [CertiGoServiceGridOption]
    public let diagramSlot: CertiGoDiagramSlotSpec?
    public let keyboardInput: CertiGoKeyboardInputSpec?
    public let matchingPairs: [CertiGoMatchingPairSpec]
    public let architectureVerdict: CertiGoArchitectureVerdictSpec?
    public let sessionItem: PrismSessionItemModel

    public init(
        id: String,
        trackCode: String,
        unitId: String,
        format: CertiGoQuestionFormatID,
        badgeTitle: String? = nil,
        stem: String,
        region: PrismRegion,
        product: BrandProductID,
        mascotPose: CertiGoMascotPose? = nil,
        primaryAssetName: String,
        optionAssetNames: [String],
        serviceGridOptions: [CertiGoServiceGridOption] = [],
        diagramSlot: CertiGoDiagramSlotSpec? = nil,
        keyboardInput: CertiGoKeyboardInputSpec? = nil,
        matchingPairs: [CertiGoMatchingPairSpec] = [],
        architectureVerdict: CertiGoArchitectureVerdictSpec? = nil,
        sessionItem: PrismSessionItemModel
    ) {
        self.id = id
        self.trackCode = trackCode
        self.unitId = unitId
        self.format = format
        self.badgeTitle = badgeTitle ?? format.badgeTitle
        self.stem = stem
        self.region = region
        self.product = product
        self.mascotPose = mascotPose ?? CertiGoMascotPose.specialist(for: region)
        self.primaryAssetName = primaryAssetName
        self.optionAssetNames = optionAssetNames
        self.serviceGridOptions = serviceGridOptions
        self.diagramSlot = diagramSlot
        self.keyboardInput = keyboardInput
        self.matchingPairs = matchingPairs
        self.architectureVerdict = architectureVerdict
        self.sessionItem = sessionItem
    }
}

public struct CertiGoTrackDescriptor: Equatable, Sendable, Identifiable {
    public let id: String
    public let code: String
    public let officialTitle: String
    public let shortSubtitle: String
    public let vendorId: String
    public let isAIFrontierTrack: Bool
    public let region: PrismRegion
    public let product: BrandProductID
    public let mascotPose: CertiGoMascotPose
    public let certificationAssetName: String
    public let brandLogoAssetName: String
    public let serviceAssetNames: [String]
    public let readinessPercentage: Int
    public let activeUnitIndex: Int
    public let completedStepsCount: Int
    public let totalStepsCount: Int
    public let units: [CertiGoCurriculumUnit]
    public let exercises: [CertiGoInteractiveExerciseSpec]

    public init(
        id: String,
        code: String,
        officialTitle: String,
        shortSubtitle: String,
        vendorId: String,
        isAIFrontierTrack: Bool,
        region: PrismRegion,
        product: BrandProductID,
        mascotPose: CertiGoMascotPose? = nil,
        certificationAssetName: String,
        brandLogoAssetName: String,
        serviceAssetNames: [String],
        readinessPercentage: Int,
        activeUnitIndex: Int = 0,
        completedStepsCount: Int = 2,
        totalStepsCount: Int = 15,
        units: [CertiGoCurriculumUnit],
        exercises: [CertiGoInteractiveExerciseSpec]
    ) {
        self.id = id
        self.code = code
        self.officialTitle = officialTitle
        self.shortSubtitle = shortSubtitle
        self.vendorId = vendorId
        self.isAIFrontierTrack = isAIFrontierTrack
        self.region = region
        self.product = product
        self.mascotPose = mascotPose ?? CertiGoMascotPose.specialist(for: region)
        self.certificationAssetName = certificationAssetName
        self.brandLogoAssetName = brandLogoAssetName
        self.serviceAssetNames = serviceAssetNames
        self.readinessPercentage = min(max(readinessPercentage, 0), 100)
        self.activeUnitIndex = max(0, activeUnitIndex)
        self.completedStepsCount = max(0, completedStepsCount)
        self.totalStepsCount = max(1, totalStepsCount)
        self.units = units
        self.exercises = exercises
    }

    public var activeUnit: CertiGoCurriculumUnit {
        guard !units.isEmpty else {
            return CertiGoMultiTrackAndAIContentCatalog.fallbackUnit(for: code)
        }
        let clamped = min(max(activeUnitIndex, 0), units.count - 1)
        return units[clamped]
    }

    public var coveredQuestionFormats: Set<CertiGoQuestionFormatID> {
        Set(exercises.map(\.format))
    }

    public var allReferencedAssetNames: [String] {
        var assets: [String] = [certificationAssetName, brandLogoAssetName]
        assets.append(contentsOf: serviceAssetNames)
        for unit in units {
            assets.append(contentsOf: unit.serviceAssetNames)
        }
        for exercise in exercises {
            assets.append(exercise.primaryAssetName)
            assets.append(contentsOf: exercise.optionAssetNames)
        }
        return Array(Set(assets)).sorted()
    }
}

// MARK: - 3. Master Multi-Certification & AI Frontier Catalog Builder

public enum CertiGoMultiTrackAndAIContentCatalog {

    public static let parallelCertificationTrackCodes: [String] =
        CertiGoParallelCertificationTrackID.allCases.map(\.rawValue)

    public static let aiFrontierTrackTitles: [String] =
        CertiGoAIFrontierTrackID.allCases.map(\.officialTitle)

    public static let parallelCertificationTracks: [CertiGoTrackDescriptor] =
        CertiGoParallelCertificationTrackID.allCases.map(buildParallelTrack)

    public static let aiFrontierTracks: [CertiGoTrackDescriptor] =
        CertiGoAIFrontierTrackID.allCases.map(buildAIFrontierTrack)

    public static var allTracks: [CertiGoTrackDescriptor] {
        parallelCertificationTracks + aiFrontierTracks
    }

    public static func track(forCode code: String) -> CertiGoTrackDescriptor {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let found = allTracks.first(where: { $0.code.uppercased() == normalized || $0.id.uppercased() == normalized }) {
            return found
        }
        if let foundByTitle = aiFrontierTracks.first(where: { $0.officialTitle.lowercased() == code.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }) {
            return foundByTitle
        }
        return parallelCertificationTracks[0]
    }

    public static func aiFrontierTrack(titledOrCoded query: String) -> CertiGoTrackDescriptor? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return aiFrontierTracks.first {
            $0.code.lowercased() == trimmed
                || $0.id.lowercased() == trimmed
                || $0.officialTitle.lowercased() == trimmed
                || $0.officialTitle.lowercased().contains(trimmed)
        }
    }

    public static func activeUnit(forTrackCode code: String) -> CertiGoCurriculumUnit {
        track(forCode: code).activeUnit
    }

    public static func exercises(forTrackCode code: String) -> [CertiGoInteractiveExerciseSpec] {
        track(forCode: code).exercises
    }

    public static func exercise(
        forTrackCode code: String,
        format: CertiGoQuestionFormatID
    ) -> CertiGoInteractiveExerciseSpec {
        let list = exercises(forTrackCode: code)
        if let match = list.first(where: { $0.format == format }) {
            return match
        }
        return list[0]
    }

    public static func sessionPlan(
        forTrackCode code: String,
        length: PrismSessionLength = .standard
    ) -> PrismSessionPlan {
        let descriptor = track(forCode: code)
        let unit = descriptor.activeUnit
        let workedExample = PrismWorkedExample(
            id: "we-\(descriptor.code.lowercased())",
            title: unit.title,
            problemContext: unit.guideArchitectureLine,
            steps: [
                PrismWorkedStep(
                    id: "\(descriptor.code.lowercased())-s1",
                    stepNumber: 1,
                    subgoalTitle: "Analyser la topologie cible",
                    detail: unit.guideArchitectureLine,
                    formulaOrCommand: unit.guideCLICommand
                ),
                PrismWorkedStep(
                    id: "\(descriptor.code.lowercased())-s2",
                    stepNumber: 2,
                    subgoalTitle: "Déjouer le piège classique d'examen",
                    detail: unit.guideExamTrap
                )
            ],
            conclusion: "Architecture validée pour \(descriptor.code) (\(descriptor.officialTitle)).",
            isSkippable: true
        )
        let learnCard = PrismLearningCardModel(
            id: "learn-\(descriptor.code.lowercased())",
            conceptId: "\(descriptor.code.lowercased()).core",
            title: unit.title,
            product: descriptor.product,
            kind: .workedExample(workedExample, skipVerificationItemId: descriptor.exercises[0].sessionItem.id)
        )
        let itemAtoms = descriptor.exercises.map { PrismSessionCardAtom.item($0.sessionItem) }
        let firstItem = descriptor.exercises[0].sessionItem
        return PrismSessionPlan(
            id: "plan-\(descriptor.code.lowercased())-\(length.rawValue)",
            length: length,
            cards: [.learning(learnCard)] + itemAtoms,
            skipVerificationItems: [firstItem.id: firstItem]
        )
    }

    public static func sessionMachine(
        forTrackCode code: String,
        length: PrismSessionLength = .standard
    ) -> SessionPlayerStateMachine {
        SessionPlayerStateMachine(plan: sessionPlan(forTrackCode: code, length: length))
    }

    public static func catalogRouteItems(activeRouteCode: String = "AZ-104") -> [CatalogRouteItem] {
        allTracks.map { track in
            CatalogRouteItem(
                id: track.id,
                code: track.code,
                officialTitle: track.officialTitle,
                region: track.region,
                product: track.product,
                availablePracticeCount: track.exercises.count,
                isConfirmedActiveGoal: track.code.uppercased() == activeRouteCode.uppercased()
            )
        }
    }

    // MARK: - Internal Track Seed Specification

    private struct TrackSeed {
        let id: String
        let code: String
        let officialTitle: String
        let shortSubtitle: String
        let vendorId: String
        let isAIFrontierTrack: Bool
        let region: PrismRegion
        let product: BrandProductID
        let mascotPose: CertiGoMascotPose
        let certificationAssetName: String
        let brandLogoAssetName: String
        let serviceAssets: [String]
        let serviceLabels: [String]
        let readinessPercentage: Int
        let activeUnitIndex: Int
        let unit1Title: String
        let unit2Title: String
        let unit3Title: String
        let architectureFlow: String
        let cliPrefix: String
        let cliTokens: [String]
        let cliExpectedKeyword: String
        let configFileName: String
        let configLanguage: String
        let configValidLine1: String
        let configBuggyLine2: String
        let configValidLine3: String
        let scopeOrder: [String]
        let examTrapNote: String
    }

    private static func buildParallelTrack(_ id: CertiGoParallelCertificationTrackID) -> CertiGoTrackDescriptor {
        let seed: TrackSeed
        switch id {
        case .az104:
            seed = TrackSeed(
                id: "track-az-104",
                code: "AZ-104",
                officialTitle: "Microsoft Azure Administrator",
                shortSubtitle: "Unité 3 · Isolation VNet, Private Link & Entra ID",
                vendorId: "azure",
                isAIFrontierTrack: false,
                region: .network,
                product: .azureVirtualNetwork,
                mascotPose: .specialistNetworkVNet,
                certificationAssetName: "Certifications/ms-official-associate-badge",
                brandLogoAssetName: "BrandLogos/brand-microsoft-azure",
                serviceAssets: [
                    "AzureServices/Virtual-Networks",
                    "AzureServices/Private-Link",
                    "AzureServices/DNS-Zones",
                    "AzureServices/Network-Security-Groups",
                    "AzureServices/Key-Vaults",
                    "AzureServices/Storage-Accounts"
                ],
                serviceLabels: [
                    "Azure Private Link",
                    "Azure Virtual Network",
                    "Azure Private DNS Zone",
                    "Network Security Group"
                ],
                readinessPercentage: 68,
                activeUnitIndex: 2,
                unit1Title: "Identité Entra ID, RBAC & Gouvernance",
                unit2Title: "Stockage Blob, GRS & Protection Key Vault",
                unit3Title: "Isolation VNet, Private Endpoint & DNS privé",
                architectureFlow: "VM Hub (10.0.0.4) ──► Private Endpoint (10.2.0.5) ──► Storage Blob",
                cliPrefix: "az network private-dns link vnet",
                cliTokens: ["create", "-g", "rg-prod", "-z", "privatelink.blob.core.windows.net", "-v", "vnet-hub", "-e", "false"],
                cliExpectedKeyword: "privatelink.blob.core.windows.net",
                configFileName: "storage-pe.bicep",
                configLanguage: "bicep",
                configValidLine1: "resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {",
                configBuggyLine2: "  properties: { publicNetworkAccess: 'Enabled', allowBlobPublicAccess: true }",
                configValidLine3: "}",
                scopeOrder: [
                    "Management Group (Groupe d'administration)",
                    "Subscription (Abonnement Azure)",
                    "Resource Group (Groupe de ressources)",
                    "Resource (Ressource individuelle)"
                ],
                examTrapNote: "Un Private Endpoint projette une IP privée dans le sous-réseau et exige un Virtual Network Link sur la zone privatelink."
            )

        case .az900:
            seed = TrackSeed(
                id: "track-az-900",
                code: "AZ-900",
                officialTitle: "Microsoft Azure Fundamentals",
                shortSubtitle: "Unité 2 · Responsabilité partagée, Régions & Coûts",
                vendorId: "azure",
                isAIFrontierTrack: false,
                region: .cloud,
                product: .microsoftAzure,
                mascotPose: .specialistCloudAzure,
                certificationAssetName: "Certifications/ms-official-fundamentals-badge",
                brandLogoAssetName: "BrandLogos/brand-microsoft-azure",
                serviceAssets: [
                    "AzureServices/Cost-Management",
                    "AzureServices/Policy",
                    "AzureServices/Management-Groups",
                    "AzureServices/Availability-Sets",
                    "AzureServices/Virtual-Machine",
                    "AzureServices/Monitor"
                ],
                serviceLabels: [
                    "Azure Cost Management",
                    "Azure Policy",
                    "Management Groups",
                    "Availability Zones"
                ],
                readinessPercentage: 84,
                activeUnitIndex: 1,
                unit1Title: "Concepts Cloud, Haute Disponibilité & IaaS/PaaS/SaaS",
                unit2Title: "Architecture Azure, Zones de disponibilité & Gouvernance",
                unit3Title: "Gestion des coûts, TCO, Budgets & Verrous (Locks)",
                architectureFlow: "Management Group ──► Subscription ──► Resource Group ──► Azure Policy",
                cliPrefix: "az lock",
                cliTokens: ["create", "--name", "lock-prod", "--lock-type", "CanNotDelete", "--resource-group", "rg-core"],
                cliExpectedKeyword: "CanNotDelete",
                configFileName: "policy-tag.json",
                configLanguage: "json",
                configValidLine1: "{ \"if\": { \"field\": \"tags['CostCenter']\", \"exists\": \"false\" },",
                configBuggyLine2: "  \"then\": { \"effect\": \"disabled\" }",
                configValidLine3: "}",
                scopeOrder: [
                    "SaaS (Responsabilité client minimale : données & accès)",
                    "PaaS (Responsabilité partagée : application & configuration)",
                    "IaaS (Responsabilité client étendue : OS, patchs & middleware)",
                    "On-Premises (Responsabilité client intégrale : datacenters physiques)"
                ],
                examTrapNote: "Un verrou ReadOnly empêche aussi les opérations POST comme listKeys sur un compte de stockage ; préférer CanNotDelete pour protéger contre la suppression."
            )

        case .ai102:
            seed = TrackSeed(
                id: "track-ai-102",
                code: "AI-102",
                officialTitle: "Microsoft Azure AI Engineer Associate",
                shortSubtitle: "Unité 2 · Foundry Agent Service, AI Search & RAG",
                vendorId: "azure",
                isAIFrontierTrack: false,
                region: .ai,
                product: .microsoftFoundry,
                mascotPose: .specialistAICoach,
                certificationAssetName: "Certifications/ms-official-associate-badge",
                brandLogoAssetName: "BrandLogos/brand-microsoft-azure",
                serviceAssets: [
                    "AzureServices/Cognitive-Services",
                    "AzureServices/Search-Services",
                    "AzureServices/Bot-Services",
                    "AzureServices/Azure-Cosmos-DB",
                    "AzureServices/Key-Vaults",
                    "AzureServices/Application-Insights"
                ],
                serviceLabels: [
                    "Azure AI Search (Vector + Semantic)",
                    "Azure OpenAI / Foundry Models",
                    "Azure AI Content Safety",
                    "Azure Cosmos DB Vector Store"
                ],
                readinessPercentage: 62,
                activeUnitIndex: 1,
                unit1Title: "Gouvernance Foundry, Identité managée & Content Safety",
                unit2Title: "RAG Hybride (Vecteurs + BM25) & Reclassement Sémantique",
                unit3Title: "Orchestration d'Agents, Function Calling & Évaluation",
                architectureFlow: "Requête ──► Embedding ──► Recherche Hybride + Reranker Sémantique ──► Réponse Ancrée",
                cliPrefix: "az cognitiveservices account deployment",
                cliTokens: ["create", "-g", "rg-ai", "-n", "aoai-prod", "--deployment-name", "gpt-4o", "--model-name", "gpt-4o"],
                cliExpectedKeyword: "semantic",
                configFileName: "rag-search-request.json",
                configLanguage: "json",
                configValidLine1: "{ \"search\": \"politique de rétention\", \"vectorQueries\": [{ \"kind\": \"vector\", \"k\": 50 }],",
                configBuggyLine2: "  \"queryType\": \"simple\", \"semanticConfiguration\": null,",
                configValidLine3: "  \"select\": \"id,title,chunk\" }",
                scopeOrder: [
                    "Découpage documentaire (Chunking avec chevauchement)",
                    "Vectorisation par modèle d'embedding (text-embedding-3-large)",
                    "Rappel hybride (Vecteurs HNSW + BM25 lexical via RRF)",
                    "Reclassement sémantique (Semantic Ranker L2) & génération ancrée"
                ],
                examTrapNote: "Pour obtenir les captions et les scores @search.rerankerScore dans Azure AI Search, il faut activer queryType: 'semantic' avec une semanticConfiguration valide."
            )

        case .az305:
            seed = TrackSeed(
                id: "track-az-305",
                code: "AZ-305",
                officialTitle: "Designing Microsoft Azure Infrastructure Solutions",
                shortSubtitle: "Unité 4 · Architecture Multi-Régions, Front Door & RPO/RTO",
                vendorId: "azure",
                isAIFrontierTrack: false,
                region: .cloud,
                product: .azureVirtualMachines,
                mascotPose: .specialistCloudAzure,
                certificationAssetName: "Certifications/ms-official-expert-badge",
                brandLogoAssetName: "BrandLogos/brand-microsoft-azure",
                serviceAssets: [
                    "AzureServices/Front-Doors",
                    "AzureServices/Azure-Cosmos-DB",
                    "AzureServices/SQL-Database",
                    "AzureServices/Recovery-Services-Vaults",
                    "AzureServices/ExpressRoute-Circuits",
                    "AzureServices/Application-Gateways"
                ],
                serviceLabels: [
                    "Azure Front Door Premium (Anycast + WAF)",
                    "Azure Cosmos DB Multi-Region Writes",
                    "Azure SQL Failover Groups",
                    "ExpressRoute avec FastPath"
                ],
                readinessPercentage: 54,
                activeUnitIndex: 2,
                unit1Title: "Identité Zero-Trust, Entra PIM & Landing Zones",
                unit2Title: "Architecture Données : Cosmos DB, SQL Failover & Data Lake",
                unit3Title: "Haute Disponibilité Multi-Régions, Front Door & PRA",
                architectureFlow: "Utilisateurs Globaux ──► Azure Front Door (WAF) ──► AKS Multi-Régions ──► Cosmos DB",
                cliPrefix: "az afd profile",
                cliTokens: ["create", "--profile-name", "afd-global", "--resource-group", "rg-edge", "--sku", "Premium_AzureFrontDoor"],
                cliExpectedKeyword: "Premium_AzureFrontDoor",
                configFileName: "cosmos-ha.bicep",
                configLanguage: "bicep",
                configValidLine1: "resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2023-11-15' = {",
                configBuggyLine2: "  properties: { enableAutomaticFailover: false, enableMultipleWriteLocations: false }",
                configValidLine3: "}",
                scopeOrder: [
                    "Single VM avec Premium SSD (SLA 99,9 %)",
                    "Availability Set multi-fault-domains (SLA 99,95 %)",
                    "Availability Zones dans une région (SLA 99,99 %)",
                    "Multi-Régions Actif/Actif avec Front Door + Cosmos DB (SLA 99,999 %)"
                ],
                examTrapNote: "Seul Azure Front Door Premium prend en charge l'intégration Private Link directe vers des origines internes (App Service, AKS Internal Load Balancer, Storage)."
            )

        case .saaC03:
            seed = TrackSeed(
                id: "track-saa-c03",
                code: "SAA-C03",
                officialTitle: "AWS Certified Solutions Architect – Associate",
                shortSubtitle: "Unité 1 · VPC Endpoints, AWS PrivateLink & Multi-AZ",
                vendorId: "aws",
                isAIFrontierTrack: false,
                region: .cloud,
                product: .aws,
                mascotPose: .specialistNetworkVNet,
                certificationAssetName: "Certifications/tech-aws-solutions-architect",
                brandLogoAssetName: "BrandLogos/brand-aws-official",
                serviceAssets: [
                    "AWSServices/Amazon-Virtual-Private-Cloud",
                    "AWSServices/AWS-PrivateLink",
                    "AWSServices/Amazon-Simple-Storage-Service",
                    "AWSServices/Amazon-DynamoDB",
                    "AWSServices/Amazon-RDS",
                    "AWSServices/AWS-Transit-Gateway"
                ],
                serviceLabels: [
                    "Gateway VPC Endpoint (S3 & DynamoDB)",
                    "Interface VPC Endpoint (AWS PrivateLink)",
                    "AWS Transit Gateway",
                    "Amazon Aurora Multi-AZ"
                ],
                readinessPercentage: 61,
                activeUnitIndex: 0,
                unit1Title: "VPC, Gateway Endpoints (S3/DynamoDB) & AWS PrivateLink",
                unit2Title: "Calcul Élastique : EC2 Auto Scaling, ALB & AWS Lambda",
                unit3Title: "Données Résilientes : Aurora Multi-AZ, S3 Lifecycle & KMS",
                architectureFlow: "Sous-réseau Privé EC2 ──► Gateway VPC Endpoint (Gratuit) ──► Amazon S3",
                cliPrefix: "aws ec2",
                cliTokens: ["create-vpc-endpoint", "--vpc-id", "vpc-0a1b2c", "--service-name", "com.amazonaws.eu-west-1.s3", "--vpc-endpoint-type", "Gateway"],
                cliExpectedKeyword: "Gateway",
                configFileName: "s3-bucket-policy.json",
                configLanguage: "json",
                configValidLine1: "{ \"Effect\": \"Deny\", \"Principal\": \"*\", \"Action\": \"s3:*\",",
                configBuggyLine2: "  \"Condition\": { \"Bool\": { \"aws:SecureTransport\": \"true\" } }",
                configValidLine3: "}",
                scopeOrder: [
                    "S3 Standard (Accès fréquent, 3+ AZ, latence milliseconde)",
                    "S3 Standard-IA (Accès peu fréquent, retenue min. 30 jours)",
                    "S3 Glacier Flexible Retrieval (Archives minutes à heures, min. 90 jours)",
                    "S3 Glacier Deep Archive (Conservation légale long terme, min. 180 jours)"
                ],
                examTrapNote: "Amazon S3 et DynamoDB prennent en charge les Gateway VPC Endpoints (gratuits via table de routage), évitant le coût horaire d'un NAT Gateway ou d'un Interface Endpoint."
            )

        case .clfC02:
            seed = TrackSeed(
                id: "track-clf-c02",
                code: "CLF-C02",
                officialTitle: "AWS Certified Cloud Practitioner",
                shortSubtitle: "Unité 1 · CAF, Well-Architected, Sécurité IAM & Facturation",
                vendorId: "aws",
                isAIFrontierTrack: false,
                region: .cloud,
                product: .aws,
                mascotPose: .specialistCloudAzure,
                certificationAssetName: "Certifications/tech-aws-cloud-practitioner",
                brandLogoAssetName: "BrandLogos/brand-aws-official",
                serviceAssets: [
                    "AWSServices/AWS-Identity-and-Access-Management",
                    "AWSServices/AWS-Organizations",
                    "AWSServices/AWS-Cost-Explorer",
                    "AWSServices/AWS-Trusted-Advisor",
                    "AWSServices/AWS-Shield",
                    "AWSServices/AWS-CloudTrail"
                ],
                serviceLabels: [
                    "AWS Organizations & SCP",
                    "AWS Cost Explorer & Budgets",
                    "AWS Trusted Advisor",
                    "AWS CloudTrail (Audit API)"
                ],
                readinessPercentage: 79,
                activeUnitIndex: 0,
                unit1Title: "Responsabilité partagée AWS, IAM & AWS Shield/WAF",
                unit2Title: "Services Clés : EC2, S3, RDS, Lambda & CloudFront",
                unit3Title: "Facturation Consolidée, Savings Plans & Cost Explorer",
                architectureFlow: "AWS Organizations (Root) ──► Organizational Unit (OU) ──► SCP ──► Compte Membre",
                cliPrefix: "aws sts",
                cliTokens: ["get-caller-identity", "--output", "json", "--region", "eu-west-1"],
                cliExpectedKeyword: "get-caller-identity",
                configFileName: "iam-mfa-policy.json",
                configLanguage: "json",
                configValidLine1: "{ \"Version\": \"2012-10-17\", \"Statement\": [{",
                configBuggyLine2: "  \"Effect\": \"Allow\", \"Action\": \"*\", \"Resource\": \"*\"",
                configValidLine3: "}] }",
                scopeOrder: [
                    "Organisation Root (Racine AWS Organizations)",
                    "Organizational Unit (Unité organisationnelle par environnement)",
                    "Member Account (Compte AWS isolé)",
                    "IAM Role & Least-Privilege Policy (Identité temporaire)"
                ],
                examTrapNote: "AWS CloudTrail enregistre qui a appelé quelle API AWS (audit), tandis qu'Amazon CloudWatch collecte les métriques de performance et les journaux d'exécution."
            )

        case .ace:
            seed = TrackSeed(
                id: "track-ace",
                code: "ACE",
                officialTitle: "Google Cloud Associate Cloud Engineer",
                shortSubtitle: "Unité 2 · IAM Hiérarchique, GKE Autopilot & Cloud Run",
                vendorId: "gcp",
                isAIFrontierTrack: false,
                region: .cloud,
                product: .googleCloud,
                mascotPose: .specialistCLIContainers,
                certificationAssetName: "Certifications/tech-gcp-cloud-engineer",
                brandLogoAssetName: "BrandLogos/brand-google-cloud",
                serviceAssets: [
                    "GCPServices/gcp-identity-and-access-management",
                    "GCPServices/gcp-google-kubernetes-engine",
                    "GCPServices/gcp-cloud-run",
                    "GCPServices/gcp-compute-engine",
                    "GCPServices/gcp-cloud-storage",
                    "GCPServices/gcp-bigquery"
                ],
                serviceLabels: [
                    "Google Cloud IAM & Workload Identity",
                    "Google Kubernetes Engine (GKE)",
                    "Cloud Run (Serverless Containers)",
                    "BigQuery Serverless Warehouse"
                ],
                readinessPercentage: 48,
                activeUnitIndex: 1,
                unit1Title: "Hiérarchie Ressources GCP, Projets & Comptes de Service",
                unit2Title: "Déploiement GKE, Workload Identity & Cloud Run",
                unit3Title: "VPC Global, Cloud NAT, Cloud Armor & Cloud Monitoring",
                architectureFlow: "Pod GKE (KSA) ──► Workload Identity Federation ──► IAM Service Account ──► Cloud SQL",
                cliPrefix: "gcloud projects",
                cliTokens: ["add-iam-policy-binding", "prj-prod-01", "--member=serviceAccount:app@prj-prod-01.iam.gserviceaccount.com", "--role=roles/storage.objectViewer"],
                cliExpectedKeyword: "add-iam-policy-binding",
                configFileName: "gke-workload-identity.yaml",
                configLanguage: "yaml",
                configValidLine1: "apiVersion: v1\nkind: ServiceAccount",
                configBuggyLine2: "metadata:\n  annotations: { iam.gke.io/gcp-service-account: \"\" }",
                configValidLine3: "  name: ksa-payments",
                scopeOrder: [
                    "Organization Node (Organisation Google Cloud)",
                    "Folder (Dossier Département / Environnement)",
                    "Project (Projet GCP : limite de facturation et d'API)",
                    "Resource (Bucket Cloud Storage, instance GCE, dataset BigQuery)"
                ],
                examTrapNote: "Ne jamais exporter de clé JSON de Service Account sur GKE : utiliser Workload Identity pour lier le Kubernetes ServiceAccount au Google Service Account."
            )

        case .pca:
            seed = TrackSeed(
                id: "track-pca",
                code: "PCA",
                officialTitle: "Google Cloud Professional Cloud Architect",
                shortSubtitle: "Unité 3 · Shared VPC, Cloud Spanner Global & Anthos",
                vendorId: "gcp",
                isAIFrontierTrack: false,
                region: .network,
                product: .googleCloud,
                mascotPose: .specialistNetworkVNet,
                certificationAssetName: "Certifications/tech-gcp-cloud-architect",
                brandLogoAssetName: "BrandLogos/brand-google-cloud",
                serviceAssets: [
                    "GCPServices/gcp-cloud-spanner",
                    "GCPServices/gcp-virtual-private-cloud",
                    "GCPServices/gcp-cloud-load-balancing",
                    "GCPServices/gcp-cloud-armor",
                    "GCPServices/gcp-private-service-connect",
                    "GCPServices/gcp-bigquery"
                ],
                serviceLabels: [
                    "Cloud Spanner (Relationnel Global 99,999 %)",
                    "Global External Application Load Balancer",
                    "Google Cloud Armor (DDoS + WAF)",
                    "Private Service Connect (PSC)"
                ],
                readinessPercentage: 44,
                activeUnitIndex: 2,
                unit1Title: "Conception Résiliente : Cloud Spanner, Bigtable & BigQuery",
                unit2Title: "Architecture Réseau : Shared VPC, PSC & Cloud Interconnect",
                unit3Title: "Sécurité Zero-Trust : VPC Service Controls & BeyondCorp",
                architectureFlow: "Global Anycast LB + Cloud Armor ──► Cloud Run Multi-Régions ──► Cloud Spanner",
                cliPrefix: "gcloud spanner instances",
                cliTokens: ["create", "spanner-global", "--config=nam-eur-asia1", "--description=GlobalProd", "--processing-units=1000"],
                cliExpectedKeyword: "nam-eur-asia1",
                configFileName: "vpc-sc-perimeter.yaml",
                configLanguage: "yaml",
                configValidLine1: "status:\n  restrictedServices:\n    - storage.googleapis.com",
                configBuggyLine2: "  accessLevels: [\"*\"] # Ouverture non bornée du périmètre",
                configValidLine3: "  resources: [\"projects/123456789\"]",
                scopeOrder: [
                    "Cloud SQL Regional HA (Relationnel régional MySQL/PostgreSQL)",
                    "Cloud Spanner Regional (Scalabilité horizontale SQL dans 1 région)",
                    "Cloud Spanner Multi-Region (Consistance forte externe mondiale 99,999 %)",
                    "VPC Service Controls + CMEK + Access Transparency (Souveraineté maximale)"
                ],
                examTrapNote: "Pour une base relationnelle transactionnelle globale avec consistance forte et SLA 99,999 %, choisir Cloud Spanner Multi-Region (pas Bigtable qui est NoSQL ni BigQuery qui est analytique OLAP)."
            )

        case .gh300:
            seed = TrackSeed(
                id: "track-gh-300",
                code: "GH-300",
                officialTitle: "GitHub Copilot Certification",
                shortSubtitle: "Unité 2 · Ingénierie de Contexte, Sécurité & Gouvernance",
                vendorId: "copilot",
                isAIFrontierTrack: false,
                region: .devops,
                product: .githubCopilot,
                mascotPose: .specialistAICoach,
                certificationAssetName: "Certifications/tech-github-copilot",
                brandLogoAssetName: "BrandLogos/brand-github-copilot",
                serviceAssets: [
                    "BrandLogos/brand-github-copilot",
                    "BrandLogos/brand-github",
                    "Certifications/tech-github-copilot",
                    "Certifications/tech-github-advanced-security",
                    "Certifications/tech-github-actions",
                    "Certifications/tech-github-foundations"
                ],
                serviceLabels: [
                    "GitHub Copilot Coding Agent & Chat",
                    "Content Exclusion (Exclusions de fichiers)",
                    "Duplicate Code Detection Filter",
                    "GitHub Advanced Security & Secret Scanning"
                ],
                readinessPercentage: 75,
                activeUnitIndex: 1,
                unit1Title: "Plans Copilot (Individual, Business, Enterprise) & Confidentialité",
                unit2Title: "Ingénierie de Prompt, Fichiers d'Instructions & Contexte IDE",
                unit3Title: "Gouvernance : Content Exclusion, Audit Logs & Filtre Public Code",
                architectureFlow: "Fichiers Ouverts + .github/copilot-instructions.md ──► Prompt Assembleur ──► Filtre Sécurité",
                cliPrefix: "gh api",
                cliTokens: ["/orgs/acme/copilot/billing/seats", "--method", "GET", "-H", "Accept: application/vnd.github+json"],
                cliExpectedKeyword: "copilot-instructions.md",
                configFileName: "copilot-content-exclusion.yml",
                configLanguage: "yaml",
                configValidLine1: "# Exclure les secrets du contexte GitHub Copilot",
                configBuggyLine2: "- \"**/*.md\" # Oubli des fichiers .env et clés privées",
                configValidLine3: "- \"/config/production-secrets/**\"",
                scopeOrder: [
                    "Politique d'Entreprise (GitHub Enterprise Cloud Policy)",
                    "Politique d'Organisation (Organization Copilot Settings & Content Exclusion)",
                    "Configuration du Dépôt (.github/copilot-instructions.md & exclusion repo)",
                    "Session IDE Locale (Onglets ouverts, sélection active & participants @workspace)"
                ],
                examTrapNote: "La fonctionnalité Content Exclusion empêche Copilot de lire les fichiers exclus dans l'IDE, mais ne remplace pas le contrôle d'accès Git ni Secret Scanning sur le dépôt."
            )

        case .cka:
            seed = TrackSeed(
                id: "track-cka",
                code: "CKA",
                officialTitle: "Certified Kubernetes Administrator",
                shortSubtitle: "Unité 1 · Control Plane, sauvegarde etcd, RBAC & NetworkPolicy",
                vendorId: "kubernetes",
                isAIFrontierTrack: false,
                region: .devops,
                product: .kubernetes,
                mascotPose: .specialistCLIContainers,
                certificationAssetName: "Certifications/tech-cka",
                brandLogoAssetName: "BrandLogos/brand-kubernetes",
                serviceAssets: [
                    "BrandLogos/brand-kubernetes",
                    "Certifications/tech-cka",
                    "Certifications/tech-cncf-ckad",
                    "Certifications/tech-cks",
                    "AzureServices/Kubernetes-Services",
                    "GCPServices/gcp-google-kubernetes-engine"
                ],
                serviceLabels: [
                    "etcd Snapshot & Restore (etcdctl)",
                    "Kubernetes RBAC (Role / ClusterRoleBinding)",
                    "NetworkPolicy (Isolation Ingress/Egress)",
                    "kubeadm Cluster Upgrade (Drain / Uncordon)"
                ],
                readinessPercentage: 52,
                activeUnitIndex: 0,
                unit1Title: "Architecture Control Plane, Sauvegarde etcd & Mise à jour kubeadm",
                unit2Title: "Ordonnancement : Taints/Tolerations, NodeAffinity & Static Pods",
                unit3Title: "Réseau CNI, CoreDNS, Ingress, NetworkPolicy & Dépannage",
                architectureFlow: "kubectl ──► kube-apiserver ──► etcd (mTLS) ──► kube-scheduler ──► kubelet",
                cliPrefix: "ETCDCTL_API=3 etcdctl",
                cliTokens: ["snapshot", "save", "/backup/etcd-snapshot.db", "--endpoints=https://127.0.0.1:2379", "--cacert=/etc/kubernetes/pki/etcd/ca.crt"],
                cliExpectedKeyword: "snapshot",
                configFileName: "deny-all-netpol.yaml",
                configLanguage: "yaml",
                configValidLine1: "apiVersion: networking.k8s.io/v1\nkind: NetworkPolicy",
                configBuggyLine2: "spec:\n  podSelector: {}\n  policyTypes: [] # Aucune direction bloquée",
                configValidLine3: "  # Doit contenir Ingress et Egress pour isoler",
                scopeOrder: [
                    "kubeadm upgrade plan & upgrade apply sur le nœud Control Plane",
                    "kubectl drain <node> --ignore-daemonsets --delete-emptydir-data",
                    "Mise à jour de kubelet et kubectl puis systemctl restart kubelet",
                    "kubectl uncordon <node> pour réintégrer le nœud au scheduling"
                ],
                examTrapNote: "Une NetworkPolicy avec podSelector: {} et policyTypes: [Ingress, Egress] sans règles ingress/egress bloque tout le trafic entrant et sortant du namespace."
            )

        case .tf003:
            seed = TrackSeed(
                id: "track-tf-003",
                code: "TF-003",
                officialTitle: "HashiCorp Certified: Terraform Associate (003)",
                shortSubtitle: "Unité 2 · État Distant Chiffré, Verrouillage & Blocs moved/import",
                vendorId: "terraform",
                isAIFrontierTrack: false,
                region: .devops,
                product: .microsoftAzure,
                mascotPose: .specialistCLIContainers,
                certificationAssetName: "Certifications/tech-terraform-associate",
                brandLogoAssetName: "BrandLogos/brand-terraform",
                serviceAssets: [
                    "BrandLogos/brand-terraform",
                    "Certifications/tech-terraform-associate",
                    "Certifications/tech-vault-associate",
                    "BrandLogos/brand-hashicorp-vault",
                    "AzureServices/Storage-Accounts",
                    "AWSServices/Amazon-DynamoDB"
                ],
                serviceLabels: [
                    "Remote Backend + State Locking",
                    "Declarative Refactoring (moved block)",
                    "Config-Driven Import (import block)",
                    "Dynamic Blocks & for_each Meta-Argument"
                ],
                readinessPercentage: 66,
                activeUnitIndex: 1,
                unit1Title: "Cycle de Vie IaC : init, validate, plan, apply & Providers",
                unit2Title: "Sécurité du State : Backend Distant, Locking & Sensitive Variables",
                unit3Title: "Modules Réutilisables, for_each vs count & Refactoring sans Downtime",
                architectureFlow: "terraform init ──► State Lock ──► terraform plan ──► terraform apply",
                cliPrefix: "terraform",
                cliTokens: ["plan", "-out=tfplan.binary", "-var-file=prod.tfvars", "-lock=true"],
                cliExpectedKeyword: "for_each",
                configFileName: "refactor-network.tf",
                configLanguage: "hcl",
                configValidLine1: "moved {\n  from = azurerm_virtual_network.legacy",
                configBuggyLine2: "  to   = \"azurerm_virtual_network.hub\" # Erreur : guillemets sur référence",
                configValidLine3: "}",
                scopeOrder: [
                    "Variables d'environnement TF_VAR_<name> (Priorité la plus basse)",
                    "Fichier terraform.tfvars chargé automatiquement",
                    "Fichier *.auto.tfvars dans l'ordre lexical",
                    "Options explicites -var et -var-file en ligne de commande (Priorité maximale)"
                ],
                examTrapNote: "Marquer une variable sensitive = true masque sa valeur dans la sortie CLI de terraform plan/apply, mais la valeur reste stockée en clair dans le fichier terraform.tfstate."
            )

        case .ccna:
            seed = TrackSeed(
                id: "track-ccna",
                code: "CCNA",
                officialTitle: "Cisco Certified Network Associate (200-301)",
                shortSubtitle: "Unité 2 · Routage OSPF, Rapid PVST+, EtherChannel LACP & ACL",
                vendorId: "cisco",
                isAIFrontierTrack: false,
                region: .network,
                product: .azureVirtualNetwork,
                mascotPose: .specialistNetworkVNet,
                certificationAssetName: "Certifications/tech-cisco-ccna",
                brandLogoAssetName: "BrandLogos/brand-cisco",
                serviceAssets: [
                    "BrandLogos/brand-cisco",
                    "Certifications/tech-cisco-ccna",
                    "Certifications/tech-comptia-network-plus",
                    "AzureServices/Virtual-Networks",
                    "AzureServices/Firewalls",
                    "AzureServices/Route-Tables"
                ],
                serviceLabels: [
                    "OSPFv2 Single-Area (AD 110, Coût bande passante)",
                    "EtherChannel LACP (802.3ad Active/Passive)",
                    "Rapid PVST+ (PortFast & BPDU Guard)",
                    "Extended ACL & NAT Overload (PAT)"
                ],
                readinessPercentage: 57,
                activeUnitIndex: 1,
                unit1Title: "Commutation Niveau 2 : VLAN, Trunk 802.1Q, STP & LACP",
                unit2Title: "Routage IPv4/IPv6 : Longest Prefix Match, OSPF & FHRP (HSRP)",
                unit3Title: "Sécurité Réseau : DAI, DHCP Snooping, ACL & Automatisation RESTCONF",
                architectureFlow: "Accès (PortFast + BPDU Guard) ──► Distribution (LACP 802.3ad) ──► Cœur OSPF Area 0",
                cliPrefix: "ip route",
                cliTokens: ["0.0.0.0", "0.0.0.0", "10.254.0.1", "250"],
                cliExpectedKeyword: "passive-interface",
                configFileName: "cisco-l2-security.ios",
                configLanguage: "ios",
                configValidLine1: "interface GigabitEthernet0/1\n switchport mode access",
                configBuggyLine2: " channel-group 1 mode on ! Risque de boucle sans négociation LACP",
                configValidLine3: " spanning-tree portfast\n spanning-tree bpduguard enable",
                scopeOrder: [
                    "Interface directement connectée (Administrative Distance = 0)",
                    "Route statique configurée manuellement (Administrative Distance = 1)",
                    "Route dynamique EIGRP interne (Administrative Distance = 90)",
                    "Route dynamique OSPF (Administrative Distance = 110)"
                ],
                examTrapNote: "Le routeur choisit toujours d'abord la route ayant le masque de sous-réseau le plus long (Longest Prefix Match /28 avant /24) AVant de comparer la distance administrative."
            )

        case .ccaF:
            seed = TrackSeed(
                id: "track-cca-f",
                code: "CCA-F",
                officialTitle: "Anthropic Claude Certified Architect – Foundations",
                shortSubtitle: "Unité 2 · Prompt Caching, Extended Thinking, Tool Use & MCP",
                vendorId: "claude",
                isAIFrontierTrack: false,
                region: .ai,
                product: .microsoftFoundry,
                mascotPose: .specialistAICoach,
                certificationAssetName: "Certifications/tech-anthropic-cca-foundations",
                brandLogoAssetName: "BrandLogos/brand-claude-ai",
                serviceAssets: [
                    "Certifications/tech-anthropic-cca-foundations",
                    "BrandLogos/brand-claude-ai",
                    "BrandLogos/brand-anthropic",
                    "AWSServices/Amazon-SageMaker",
                    "GCPServices/gcp-vertexai",
                    "AzureServices/Cognitive-Services"
                ],
                serviceLabels: [
                    "Claude Prompt Caching (cache_control ephemeral)",
                    "Extended Thinking (Budget de tokens de raisonnement)",
                    "Model Context Protocol (MCP Tools & Resources)",
                    "Constitutional AI & Guardrails d'architecture"
                ],
                readinessPercentage: 71,
                activeUnitIndex: 1,
                unit1Title: "Famille Claude (Haiku, Sonnet, Opus), Fenêtre 200k+ & Prompting XML",
                unit2Title: "Optimisation de Latence : Prompt Caching & Batch API (-50 %)",
                unit3Title: "Agents Fiables : Tool Use strict, MCP & Évaluations Automatisées",
                architectureFlow: "System Prompt + Outils (Cache Ephemeral) ──► Extended Thinking ──► Appel MCP Typé",
                cliPrefix: "curl https://api.anthropic.com/v1/messages",
                cliTokens: ["-H", "x-api-key: $ANTHROPIC_API_KEY", "-H", "anthropic-version: 2023-06-01", "-d", "@request.json"],
                cliExpectedKeyword: "cache_control",
                configFileName: "claude-tool-use.json",
                configLanguage: "json",
                configValidLine1: "{ \"model\": \"claude-sonnet-4-20250514\", \"max_tokens\": 4096,",
                configBuggyLine2: "  \"thinking\": { \"type\": \"enabled\", \"budget_tokens\": 8000 },",
                configValidLine3: "  \"system\": [{ \"type\": \"text\", \"text\": \"Tu es architecte.\", \"cache_control\": { \"type\": \"ephemeral\" } }] }",
                scopeOrder: [
                    "Définitions d'outils (tools) placées en tête pour maximiser le préfixe de cache",
                    "Instructions système (system) structurées avec balises XML et cache_control",
                    "Documents de référence et exemples few-shot stables mis en cache",
                    "Tour de conversation dynamique de l'utilisateur (non mis en cache)"
                ],
                examTrapNote: "Dans l'API Messages de Claude, budget_tokens pour Extended Thinking doit toujours être strictement inférieur à max_tokens, et le cache de prompt opère par préfixe exact."
            )
        }
        return makeTrackDescriptor(from: seed)
    }

    private static func buildAIFrontierTrack(_ id: CertiGoAIFrontierTrackID) -> CertiGoTrackDescriptor {
        let seed: TrackSeed
        switch id {
        case .openAIGPT:
            seed = TrackSeed(
                id: "track-ai-openai",
                code: "AI-OPENAI",
                officialTitle: "OpenAI & Architecture GPT",
                shortSubtitle: "Veille Acteurs IA · Modèles GPT/o-series, Structured Outputs & Responses API",
                vendorId: "openai",
                isAIFrontierTrack: true,
                region: .ai,
                product: .azureOpenAIService,
                mascotPose: .specialistAICoach,
                certificationAssetName: "BrandLogos/brand-openai",
                brandLogoAssetName: "BrandLogos/brand-openai",
                serviceAssets: [
                    "BrandLogos/brand-openai",
                    "AzureServices/Cognitive-Services",
                    "AzureServices/Search-Services",
                    "AzureServices/Key-Vaults",
                    "BrandLogos/brand-microsoft-azure",
                    "BrandLogos/brand-python"
                ],
                serviceLabels: [
                    "Structured Outputs (strict: true JSON Schema)",
                    "Modèles de raisonnement vs Modèles multimodaux",
                    "Automatic Prompt Caching (Préfixes >= 1024 tokens)",
                    "Responses API & Exécution d'outils parallèles"
                ],
                readinessPercentage: 76,
                activeUnitIndex: 0,
                unit1Title: "Architecture Transformer, Tokenizer & Structured Outputs (strict: true)",
                unit2Title: "Modèles de Raisonnement, effort de calcul & Prompt Caching",
                unit3Title: "Agents Multi-Outils, Recherche Vectorielle & Évaluation Evals",
                architectureFlow: "Prompt Préfixe Statique ──► Structured Output (strict: true) ──► Validation Schéma",
                cliPrefix: "openai api",
                cliTokens: ["responses.create", "-m", "gpt-4.1", "--temperature", "0", "--response-format", "json_schema"],
                cliExpectedKeyword: "strict",
                configFileName: "openai-structured-schema.json",
                configLanguage: "json",
                configValidLine1: "{ \"type\": \"json_schema\", \"json_schema\": { \"name\": \"audit_result\", \"strict\": true,",
                configBuggyLine2: "  \"schema\": { \"type\": \"object\", \"additionalProperties\": true }",
                configValidLine3: "} }",
                scopeOrder: [
                    "Instructions système et schémas d'outils statiques (en tête pour le cache)",
                    "Contexte documentaire RAG vérifié et horodaté",
                    "Exemples few-shot canoniques d'entrée/sortie",
                    "Question utilisateur courante et paramètres d'exécution"
                ],
                examTrapNote: "Avec Structured Outputs (strict: true), chaque objet du JSON Schema doit explicitement définir additionalProperties: false et lister toutes ses propriétés dans required."
            )

        case .anthropicClaude:
            seed = TrackSeed(
                id: "track-ai-anthropic",
                code: "AI-ANTHROPIC",
                officialTitle: "Anthropic & Claude CCA-F",
                shortSubtitle: "Veille Acteurs IA · Constitutional AI, MCP, Extended Thinking & Claude Code",
                vendorId: "claude",
                isAIFrontierTrack: true,
                region: .ai,
                product: .microsoftFoundry,
                mascotPose: .specialistAICoach,
                certificationAssetName: "Certifications/tech-anthropic-cca-foundations",
                brandLogoAssetName: "BrandLogos/brand-claude-ai",
                serviceAssets: [
                    "BrandLogos/brand-claude-ai",
                    "BrandLogos/brand-anthropic",
                    "Certifications/tech-anthropic-cca-foundations",
                    "AWSServices/Amazon-SageMaker",
                    "GCPServices/gcp-vertexai",
                    "BrandLogos/brand-github"
                ],
                serviceLabels: [
                    "Model Context Protocol (Serveurs MCP & Transports)",
                    "Extended Thinking & Citations Vérifiables",
                    "Prompt Caching multi-paliers (jusqu'à 4 breakpoints)",
                    "Orchestration Subagents à contexte isolé"
                ],
                readinessPercentage: 80,
                activeUnitIndex: 0,
                unit1Title: "Architecture Claude, Balisage XML & Citations Documentaires",
                unit2Title: "Model Context Protocol (MCP) : Tools, Resources & Prompts",
                unit3Title: "Boucles Agentiques, Sous-Agents Isolés & Sécurité d'Exécution",
                architectureFlow: "Hôte IA ──► Client MCP (JSON-RPC 2.0) ──► Serveur MCP Local/Distant ──► Ressource",
                cliPrefix: "npx",
                cliTokens: ["@modelcontextprotocol/inspector", "--transport", "stdio", "--server", "./build/index.js"],
                cliExpectedKeyword: "ephemeral",
                configFileName: "mcp-server-config.json",
                configLanguage: "json",
                configValidLine1: "{ \"mcpServers\": { \"postgres-readonly\": {",
                configBuggyLine2: "  \"command\": \"npx\", \"env\": { \"DB_PASSWORD\": \"PlaintextSecret123!\" }",
                configValidLine3: "} } }",
                scopeOrder: [
                    "Primitives Resources (Lecture de contexte contrôlée par l'application)",
                    "Primitives Prompts (Modèles d'interaction déclenchés par l'utilisateur)",
                    "Primitives Tools (Actions exécutables appelées par le modèle avec validation)",
                    "Approbation humaine (Human-in-the-loop) sur toute action destructive"
                ],
                examTrapNote: "Dans MCP, les Tools sont pilotés par le modèle (model-controlled), les Resources par l'application, et les Prompts par l'utilisateur ; toute action destructive exige confirmation."
            )

        case .googleGeminiVertex:
            seed = TrackSeed(
                id: "track-ai-gemini",
                code: "AI-GEMINI",
                officialTitle: "Google Gemini & Vertex AI",
                shortSubtitle: "Veille Acteurs IA · Contexte Multimodal 1M+, Context Caching & Grounding",
                vendorId: "gemini",
                isAIFrontierTrack: true,
                region: .ai,
                product: .googleCloud,
                mascotPose: .specialistAICoach,
                certificationAssetName: "Certifications/tech-gcp-ml-engineer",
                brandLogoAssetName: "BrandLogos/brand-google-gemini",
                serviceAssets: [
                    "BrandLogos/brand-google-gemini",
                    "GCPServices/gcp-vertexai",
                    "GCPServices/gcp-ai-platform",
                    "GCPServices/gcp-bigquery",
                    "GCPServices/gcp-cloud-run",
                    "BrandLogos/brand-google-cloud"
                ],
                serviceLabels: [
                    "Gemini Multimodalité Native (Texte, Audio, Vidéo, Code)",
                    "Vertex AI Context Caching (TTL configurable)",
                    "Grounding avec Vertex AI Search",
                    "Vertex AI Agent Builder & Extensions"
                ],
                readinessPercentage: 69,
                activeUnitIndex: 0,
                unit1Title: "Architecture Gemini Multimodale Native & Fenêtre Long Contexte",
                unit2Title: "Vertex AI Context Caching, Grounding & Récupération d'Entreprise",
                unit3Title: "Déploiement Vertex AI Endpoints, IAM & Surveillance Model Monitoring",
                architectureFlow: "Corpus Vidéo/PDF ──► Vertex AI Context Cache ──► Gemini Pro/Flash ──► Grounded Citations",
                cliPrefix: "gcloud ai endpoints",
                cliTokens: ["deploy-model", "ep-gemini-prod", "--region=europe-west1", "--model=gemini-2.5-pro", "--traffic-split=0=100"],
                cliExpectedKeyword: "cachedContent",
                configFileName: "vertex-grounding.json",
                configLanguage: "json",
                configValidLine1: "{ \"contents\": [{ \"role\": \"user\", \"parts\": [{ \"text\": \"Analyse le SLA\" }] }],",
                configBuggyLine2: "  \"safetySettings\": [{ \"category\": \"HARM_CATEGORY_DANGEROUS_CONTENT\", \"threshold\": \"BLOCK_NONE\" }],",
                configValidLine3: "  \"tools\": [{ \"vertexAiSearch\": { \"datastore\": \"projects/p/locations/global/collections/default\" } }] }",
                scopeOrder: [
                    "Ingestion multimodale dans Cloud Storage avec contrôle IAM",
                    "Création d'un objet CachedContent Vertex AI avec TTL borné",
                    "Ancrage (Grounding) sur Vertex AI Search Datastore d'entreprise",
                    "Vérification des groundingMetadata et citations avant affichage"
                ],
                examTrapNote: "Pour réutiliser un corpus massif (vidéos, longs PDF, dépôts) à travers de multiples requêtes sur Vertex AI sans repayer la tokenisation complète, créer un CachedContent explicite."
            )

        case .microsoftFoundryCopilot:
            seed = TrackSeed(
                id: "track-ai-foundry",
                code: "AI-FOUNDRY",
                officialTitle: "Microsoft Foundry & Copilot",
                shortSubtitle: "Veille Acteurs IA · Foundry Agent Service, Model Router, Evaluations & Content Safety",
                vendorId: "copilot",
                isAIFrontierTrack: true,
                region: .ai,
                product: .microsoftFoundry,
                mascotPose: .specialistAICoach,
                certificationAssetName: "Certifications/tech-github-copilot",
                brandLogoAssetName: "BrandLogos/brand-github-copilot",
                serviceAssets: [
                    "BrandLogos/brand-github-copilot",
                    "BrandLogos/brand-microsoft-azure",
                    "AzureServices/Cognitive-Services",
                    "AzureServices/Search-Services",
                    "AzureServices/Key-Vaults",
                    "AzureServices/Application-Insights"
                ],
                serviceLabels: [
                    "Microsoft Foundry Agent Service",
                    "Azure AI Content Safety & Prompt Shields",
                    "Évaluation Qualité & Sécurité (Groundedness / Relevance)",
                    "Entra Managed Identity & Isolation Private Link"
                ],
                readinessPercentage: 82,
                activeUnitIndex: 0,
                unit1Title: "Microsoft Foundry Hub/Project, Catalogue de Modèles & Serverless API",
                unit2Title: "Foundry Agent Service, Connexions AI Search & Identité Managée",
                unit3Title: "Prompt Shields (Jailbreak/Indirect Injection), Tracing OpenTelemetry & Evals",
                architectureFlow: "Application ──► Prompt Shields ──► Foundry Agent ──► AI Search (Managed Identity)",
                cliPrefix: "az ml workspace",
                cliTokens: ["create", "--kind", "project", "--hub-id", "/subscriptions/sub/resourceGroups/rg/providers/Microsoft.MachineLearningServices/workspaces/hub-prod", "-n", "prj-copilot"],
                cliExpectedKeyword: "SystemAssigned",
                configFileName: "foundry-agent-host.bicep",
                configLanguage: "bicep",
                configValidLine1: "resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {",
                configBuggyLine2: "  properties: { disableLocalAuth: false, publicNetworkAccess: 'Enabled' }",
                configValidLine3: "  identity: { type: 'SystemAssigned' } }",
                scopeOrder: [
                    "Désactivation des clés locales (disableLocalAuth: true) au profit d'Entra ID",
                    "Filtrage d'entrée par Azure AI Content Safety Prompt Shields (User + Documents)",
                    "Exécution de l'Agent Foundry avec outils bornés et traçage OpenTelemetry",
                    "Validation de sortie (Groundedness Detection) avant restitution"
                ],
                examTrapNote: "En production sur Microsoft Foundry, désactiver l'authentification par clé locale (disableLocalAuth: true) et imposer Entra ID Managed Identity avec Prompt Shields contre l'injection indirecte."
            )

        case .mistralOpenWeight:
            seed = TrackSeed(
                id: "track-ai-mistral",
                code: "AI-MISTRAL",
                officialTitle: "Mistral AI & Modèles Open-Weight",
                shortSubtitle: "Veille Acteurs IA · Mixture-of-Experts (MoE), vLLM, Quantization & Souveraineté",
                vendorId: "mistral",
                isAIFrontierTrack: true,
                region: .ai,
                product: .microsoftFoundry,
                mascotPose: .specialistAICoach,
                certificationAssetName: "BrandLogos/brand-mistral-ai",
                brandLogoAssetName: "BrandLogos/brand-mistral-ai",
                serviceAssets: [
                    "BrandLogos/brand-mistral-ai",
                    "BrandLogos/brand-hugging-face",
                    "BrandLogos/brand-nvidia",
                    "BrandLogos/brand-meta",
                    "AzureServices/Kubernetes-Services",
                    "GCPServices/gcp-cloud-gpu"
                ],
                serviceLabels: [
                    "Architecture Sparse Mixture-of-Experts (SMoE)",
                    "Inférence Haute Performance (vLLM & PagedAttention)",
                    "Quantification AWQ / FP8 & Dimensionnement VRAM",
                    "Déploiement Souverain Auto-Hébergé ou Managé"
                ],
                readinessPercentage: 65,
                activeUnitIndex: 0,
                unit1Title: "Architecture Dense vs Sparse Mixture-of-Experts (MoE) & KV Cache",
                unit2Title: "Service d'Inférence vLLM, PagedAttention, Continuous Batching & FP8",
                unit3Title: "Fine-Tuning LoRA/QLoRA, Évaluation & Déploiement Souverain sur Kubernetes",
                architectureFlow: "Passerelle API ──► Routeur Token MoE (Top-2 Experts) ──► vLLM PagedAttention GPU",
                cliPrefix: "vllm",
                cliTokens: ["serve", "mistralai/Mistral-Small-24B-Instruct-2501", "--tensor-parallel-size", "2", "--max-model-len", "32768", "--quantization", "fp8"],
                cliExpectedKeyword: "tensor-parallel-size",
                configFileName: "vllm-k8s-deployment.yaml",
                configLanguage: "yaml",
                configValidLine1: "resources:\n  limits:\n    nvidia.com/gpu: \"2\"",
                configBuggyLine2: "args: [\"--trust-remote-code\", \"--host\", \"0.0.0.0\", \"--api-key\", \"\"]",
                configValidLine3: "volumeMounts:\n  - mountPath: /dev/shm\n    name: dshm",
                scopeOrder: [
                    "Dimensionnement mémoire totale (Tous les experts MoE doivent résider en VRAM)",
                    "Activation de PagedAttention et Continuous Batching dans vLLM",
                    "Parallélisme de tenseurs (--tensor-parallel-size) sur GPU NVLink",
                    "Exposition sécurisée derrière passerelle authentifiée avec quotas de tokens"
                ],
                examTrapNote: "Dans un modèle Sparse MoE, seuls les experts actifs par token déterminent les FLOPs d'inférence, mais TOUS les paramètres du modèle doivent être chargés en mémoire GPU (VRAM)."
            )
        }
        return makeTrackDescriptor(from: seed)
    }

    // MARK: - Deterministic Unit + 10-Format Exercise Bank Factory

    private static func makeTrackDescriptor(from seed: TrackSeed) -> CertiGoTrackDescriptor {
        let units = makeUnits(from: seed)
        let exercises = makeAllTenFormatExercises(from: seed, activeUnitId: units[min(seed.activeUnitIndex, units.count - 1)].id)
        return CertiGoTrackDescriptor(
            id: seed.id,
            code: seed.code,
            officialTitle: seed.officialTitle,
            shortSubtitle: seed.shortSubtitle,
            vendorId: seed.vendorId,
            isAIFrontierTrack: seed.isAIFrontierTrack,
            region: seed.region,
            product: seed.product,
            mascotPose: seed.mascotPose,
            certificationAssetName: seed.certificationAssetName,
            brandLogoAssetName: seed.brandLogoAssetName,
            serviceAssetNames: seed.serviceAssets,
            readinessPercentage: seed.readinessPercentage,
            activeUnitIndex: seed.activeUnitIndex,
            completedStepsCount: 7,
            totalStepsCount: 15,
            units: units,
            exercises: exercises
        )
    }

    private static func makeUnits(from seed: TrackSeed) -> [CertiGoCurriculumUnit] {
        let titles = [seed.unit1Title, seed.unit2Title, seed.unit3Title]
        let weights = [
            "5 étapes · Objectif examen : 30–35 %",
            "5 étapes · Objectif examen : 35–40 %",
            "5 étapes · Objectif examen : 25–30 %"
        ]
        return titles.enumerated().map { idx, unitTitle -> CertiGoCurriculumUnit in
            let unitNum = idx + 1
            let unitId = "\(seed.code.lowercased())-u\(unitNum)"
            let steps: [CertiGoPathStepSpec] = [
                .init(
                    id: "\(unitId)-s1",
                    title: "Fondations & Topologie",
                    subtitle: nil,
                    state: .done,
                    symbol: "checkmark",
                    alignment: .centerRight
                ),
                .init(
                    id: "\(unitId)-s2",
                    title: "Sécurité & Moindre Privilège",
                    subtitle: nil,
                    state: .done,
                    symbol: "shield.fill",
                    alignment: .leadingRight
                ),
                .init(
                    id: "\(unitId)-s3",
                    title: unitTitle,
                    subtitle: "Étape 3 sur 5",
                    state: .active,
                    symbol: seed.isAIFrontierTrack ? "sparkles" : "point.3.connected.trianglepath.dotted",
                    alignment: .trailingLeft
                ),
                .init(
                    id: "\(unitId)-s4",
                    title: "Diagnostic CLI & Scénarios Pièges",
                    subtitle: nil,
                    state: .locked,
                    symbol: "lock.fill",
                    alignment: .farTrailingLeft
                ),
                .init(
                    id: "\(unitId)-s5",
                    title: "Coffre de l'Unité \(unitNum)",
                    subtitle: "Défi synthèse",
                    state: .chest,
                    symbol: "shippingbox.fill",
                    alignment: .leadingRight
                )
            ]
            return CertiGoCurriculumUnit(
                id: unitId,
                unitNumber: unitNum,
                supertitle: "UNITÉ \(unitNum) · \(seed.code)",
                title: unitTitle,
                examWeightText: weights[idx],
                guideArchitectureLine: seed.architectureFlow,
                guideCLICommand: ([seed.cliPrefix] + seed.cliTokens).joined(separator: " "),
                guideExamTrap: seed.examTrapNote,
                serviceAssetNames: Array(seed.serviceAssets.prefix(4)),
                steps: steps
            )
        }
    }

    private static func makeAllTenFormatExercises(
        from seed: TrackSeed,
        activeUnitId: String
    ) -> [CertiGoInteractiveExerciseSpec] {
        let codeLower = seed.code.lowercased()
        let assets = seed.serviceAssets
        let labels = seed.serviceLabels

        // Q_TYPE_01 — Scénario QCM Classique (Bulle 3/4 + 4 Options A/B/C/D)
        let q01Options = [
            PrismChoiceOption(
                id: "\(codeLower)-q01-a",
                badge: "A",
                text: "\(labels[0]) avec contrôle d'accès strict",
                explanation: seed.examTrapNote,
                isCorrect: true
            ),
            PrismChoiceOption(
                id: "\(codeLower)-q01-b",
                badge: "B",
                text: "Exposition publique directe sans filtrage ni authentification",
                explanation: "Crée une surface d'attaque critique contraire aux bonnes pratiques \(seed.code).",
                isCorrect: false
            ),
            PrismChoiceOption(
                id: "\(codeLower)-q01-c",
                badge: "C",
                text: "Partage de clés statiques administrateur dans le dépôt Git",
                explanation: "Viole le principe du moindre privilège et de rotation des identités.",
                isCorrect: false
            ),
            PrismChoiceOption(
                id: "\(codeLower)-q01-d",
                badge: "D",
                text: "Désactivation complète de la journalisation et des alertes",
                explanation: "Supprime toute observabilité et traçabilité d'audit.",
                isCorrect: false
            )
        ]
        let q01 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q01",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q01ScenarioQCM,
            stem: "[\(seed.code)] Quelle architecture garantit le respect des exigences de sécurité et de résilience pour « \(seed.unit2Title) » ?",
            region: seed.region,
            product: seed.product,
            mascotPose: seed.mascotPose,
            primaryAssetName: assets[0],
            optionAssetNames: Array(assets.prefix(4)),
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q01",
                conceptId: "\(codeLower).q01",
                product: seed.product,
                rung: 2,
                difficulty: 2,
                stem: "[\(seed.code)] Quelle architecture garantit le respect des exigences de sécurité et de résilience pour « \(seed.unit2Title) » ?",
                captureConfidence: true,
                payload: .choice(options: q01Options, allowsMultipleSelection: false)
            )
        )

        // Q_TYPE_02 — Grille 2x2 de Services Officiels (Vraies Icônes SVG)
        let gridCards: [CertiGoServiceGridOption] = [
            CertiGoServiceGridOption(
                id: "\(codeLower)-q02-a",
                badge: "A",
                serviceTitle: labels[0],
                subtitle: "Recommandé pour \(seed.code)",
                assetName: assets[0],
                isCorrect: true,
                explanation: seed.examTrapNote
            ),
            CertiGoServiceGridOption(
                id: "\(codeLower)-q02-b",
                badge: "B",
                serviceTitle: labels[1],
                subtitle: "Composant périphérique",
                assetName: assets[1],
                isCorrect: false,
                explanation: "Complémentaire mais ne remplace pas \(labels[0])."
            ),
            CertiGoServiceGridOption(
                id: "\(codeLower)-q02-c",
                badge: "C",
                serviceTitle: labels[2],
                subtitle: "Rôle distinct dans la topologie",
                assetName: assets[2],
                isCorrect: false,
                explanation: "Assure un rôle différent dans la chaîne \(seed.architectureFlow)."
            ),
            CertiGoServiceGridOption(
                id: "\(codeLower)-q02-d",
                badge: "D",
                serviceTitle: labels[3],
                subtitle: "Contrôle secondaire",
                assetName: assets[3],
                isCorrect: false,
                explanation: "Ne répond pas directement au besoin principal de l'énoncé."
            )
        ]
        let q02ChoiceOptions = gridCards.map { card in
            PrismChoiceOption(
                id: card.id,
                badge: card.badge,
                text: "\(card.serviceTitle) — \(card.subtitle)",
                explanation: card.explanation,
                isCorrect: card.isCorrect
            )
        }
        let q02 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q02",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q02ServiceGrid2x2,
            stem: "[\(seed.code)] Sélectionne dans la grille 2×2 le service officiel qui répond directement à : \(seed.architectureFlow)",
            region: seed.region,
            product: seed.product,
            mascotPose: seed.mascotPose,
            primaryAssetName: assets[0],
            optionAssetNames: gridCards.map(\.assetName),
            serviceGridOptions: gridCards,
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q02",
                conceptId: "\(codeLower).q02",
                product: seed.product,
                rung: 2,
                difficulty: 2,
                stem: "[\(seed.code)] Sélectionne dans la grille 2×2 le service officiel qui répond directement à : \(seed.architectureFlow)",
                payload: .choice(options: q02ChoiceOptions, allowsMultipleSelection: false)
            )
        )

        // Q_TYPE_03 — Schéma d'Architecture Interactif à Compléter ([ ? ])
        let diagramSpec = CertiGoDiagramSlotSpec(
            sourceLabel: labels[1],
            sourceAssetName: assets[1],
            missingSlotPrompt: "[ ? BRIQUE MANQUANTE ]",
            targetLabel: labels[2],
            targetAssetName: assets[2],
            candidateOptions: gridCards
        )
        let diagramArtifact = PrismArtifactDocument(
            id: "\(codeLower)-diag-doc",
            title: "topologie-\(codeLower).arch",
            language: "text",
            lines: [
                PrismArtifactLine(lineNumber: 1, text: "Flux cible : \(seed.architectureFlow)"),
                PrismArtifactLine(lineNumber: 2, text: "Brique à insérer au centre : \(labels[0])")
            ],
            spotTheIssueInteractive: false
        )
        let q03 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q03",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q03InteractiveDiagram,
            stem: "[\(seed.code)] Quelle brique officielle complète l'emplacement [ ? ] dans le schéma « \(seed.architectureFlow) » ?",
            region: seed.region,
            product: seed.product,
            mascotPose: .posePresenter,
            primaryAssetName: assets[1],
            optionAssetNames: [assets[0], assets[1], assets[2], assets[3]],
            diagramSlot: diagramSpec,
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q03",
                conceptId: "\(codeLower).q03",
                product: seed.product,
                rung: 3,
                difficulty: 2,
                stem: "[\(seed.code)] Quelle brique officielle complète l'emplacement [ ? ] dans le schéma « \(seed.architectureFlow) » ?",
                payload: .situation(
                    contextNarrative: "Complète le chaînon manquant pour sécuriser le flux \(seed.architectureFlow).",
                    artifact: diagramArtifact,
                    decisions: [
                        SituationDecisionStep(
                            id: "\(codeLower)-q03-step1",
                            prompt: "Choisis le composant central exact :",
                            options: q02ChoiceOptions
                        )
                    ]
                )
            )
        )

        // Q_TYPE_04 — Saisie Clavier iOS (Paramètre / Zone / Commande)
        let keyboardSpec = CertiGoKeyboardInputSpec(
            commandPrefix: seed.cliPrefix,
            placeholder: seed.cliExpectedKeyword,
            expectedAnswer: seed.cliExpectedKeyword,
            acceptedAliases: [seed.cliExpectedKeyword.lowercased()],
            commandSuffix: seed.cliTokens.last ?? "",
            explanation: seed.examTrapNote
        )
        let q04Tokens = [
            PrismCommandToken(id: "\(codeLower)-q04-t1", text: seed.cliExpectedKeyword),
            PrismCommandToken(id: "\(codeLower)-q04-t2", text: "invalid-default"),
            PrismCommandToken(id: "\(codeLower)-q04-t3", text: "skip-verification")
        ]
        let q04 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q04",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q04IOSKeyboardInput,
            stem: "[\(seed.code)] Saisis le paramètre ou identifiant exact requis dans la commande « \(seed.cliPrefix) » :",
            region: seed.region,
            product: seed.product,
            mascotPose: .poseCLICoder,
            primaryAssetName: assets[2],
            optionAssetNames: [assets[2], seed.brandLogoAssetName],
            keyboardInput: keyboardSpec,
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q04",
                conceptId: "\(codeLower).q04",
                product: seed.product,
                rung: 3,
                difficulty: 2,
                stem: "[\(seed.code)] Saisis le paramètre ou identifiant exact requis dans la commande « \(seed.cliPrefix) » :",
                payload: .commandComposer(
                    promptCommandPrefix: seed.cliPrefix,
                    availableTokens: q04Tokens
                )
            )
        )

        // Q_TYPE_05 — Assemblage de Briques CLI (Word Bank Duolingo)
        let q05Tokens = seed.cliTokens.enumerated().map { idx, tok in
            PrismCommandToken(id: "\(codeLower)-q05-tok-\(idx)", text: tok)
        }
        let q05 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q05",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q05WordBankBricks,
            stem: "[\(seed.code)] Assemble dans l'ordre les briques CLI pour exécuter l'opération officielle :",
            region: seed.region,
            product: seed.product,
            mascotPose: .specialistCLIContainers,
            primaryAssetName: assets[3],
            optionAssetNames: [assets[3], seed.certificationAssetName],
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q05",
                conceptId: "\(codeLower).q05",
                product: seed.product,
                rung: 3,
                difficulty: 2,
                stem: "[\(seed.code)] Assemble dans l'ordre les briques CLI pour exécuter l'opération officielle :",
                payload: .commandComposer(
                    promptCommandPrefix: seed.cliPrefix,
                    availableTokens: q05Tokens
                )
            )
        )

        // Q_TYPE_06 — Paires à Relier (Symboles ↔ Rôles Exact)
        let pairs: [CertiGoMatchingPairSpec] = [
            CertiGoMatchingPairSpec(
                id: "\(codeLower)-pair-1",
                leftSymbolOrService: labels[0],
                leftAssetName: assets[0],
                rightRoleDescription: "Composant principal d'isolation et de contrôle (\(seed.code))"
            ),
            CertiGoMatchingPairSpec(
                id: "\(codeLower)-pair-2",
                leftSymbolOrService: labels[1],
                leftAssetName: assets[1],
                rightRoleDescription: "Socle d'infrastructure et d'interconnexion"
            ),
            CertiGoMatchingPairSpec(
                id: "\(codeLower)-pair-3",
                leftSymbolOrService: labels[2],
                leftAssetName: assets[2],
                rightRoleDescription: "Résolution, routage ou indexation dédiée"
            ),
            CertiGoMatchingPairSpec(
                id: "\(codeLower)-pair-4",
                leftSymbolOrService: labels[3],
                leftAssetName: assets[3],
                rightRoleDescription: "Gouvernance, filtrage et supervision continue"
            )
        ]
        let q06Options = pairs.enumerated().map { idx, pair in
            PrismChoiceOption(
                id: pair.id,
                badge: "\(idx + 1)",
                text: "\(pair.leftSymbolOrService) ↔ \(pair.rightRoleDescription)",
                explanation: "Association vérifiée dans le référentiel \(seed.code).",
                isCorrect: idx == 0
            )
        }
        let q06 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q06",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q06MatchingPairs,
            stem: "[\(seed.code)] Relie chaque service officiel à sa responsabilité exacte dans l'architecture :",
            region: seed.region,
            product: seed.product,
            mascotPose: .poseAnalyst,
            primaryAssetName: assets[0],
            optionAssetNames: pairs.map(\.leftAssetName),
            matchingPairs: pairs,
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q06",
                conceptId: "\(codeLower).q06",
                product: seed.product,
                rung: 2,
                difficulty: 2,
                stem: "[\(seed.code)] Relie chaque service officiel à sa responsabilité exacte dans l'architecture :",
                payload: .choice(options: q06Options, allowsMultipleSelection: false)
            )
        )

        // Q_TYPE_07 — Diagnostic d'Anomalie JSON / YAML / Bicep (Trouver la Ligne Fautive)
        let bugArtifact = PrismArtifactDocument(
            id: "\(codeLower)-bug-doc",
            title: seed.configFileName,
            language: seed.configLanguage,
            lines: [
                PrismArtifactLine(lineNumber: 1, text: seed.configValidLine1),
                PrismArtifactLine(
                    lineNumber: 2,
                    text: seed.configBuggyLine2,
                    diagnosticNote: seed.examTrapNote
                ),
                PrismArtifactLine(lineNumber: 3, text: seed.configValidLine3)
            ],
            spotTheIssueInteractive: true
        )
        let q07 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q07",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q07JSONBugDiagnosis,
            stem: "[\(seed.code)] Touche la ligne fautive ou vulnérable dans « \(seed.configFileName) » :",
            region: .security,
            product: seed.product,
            mascotPose: .specialistSecurityEntra,
            primaryAssetName: assets[4 % assets.count],
            optionAssetNames: [assets[4 % assets.count], seed.brandLogoAssetName],
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q07",
                conceptId: "\(codeLower).q07",
                product: seed.product,
                rung: 4,
                difficulty: 3,
                stem: "[\(seed.code)] Touche la ligne fautive ou vulnérable dans « \(seed.configFileName) » :",
                payload: .spotTheIssue(artifact: bugArtifact, allowsMultipleLines: false)
            )
        )

        // Q_TYPE_08 — Hiérarchie de Portée à Ordonner (1 ➔ 4)
        let orderItems = seed.scopeOrder.enumerated().map { idx, text in
            PrismOrderItem(id: "\(codeLower)-ord-\(idx + 1)", text: text, indentLevel: idx)
        }
        let q08 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q08",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q08ScopeHierarchyOrdering,
            stem: "[\(seed.code)] Classe ces 4 niveaux dans l'ordre exact de priorité ou d'héritage architectural (1 ➔ 4) :",
            region: seed.region,
            product: seed.product,
            mascotPose: .angleThinking34,
            primaryAssetName: seed.certificationAssetName,
            optionAssetNames: Array(assets.prefix(4)),
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q08",
                conceptId: "\(codeLower).q08",
                product: seed.product,
                rung: 3,
                difficulty: 2,
                stem: "[\(seed.code)] Classe ces 4 niveaux dans l'ordre exact de priorité ou d'héritage architectural (1 ➔ 4) :",
                payload: .ordering(items: orderItems)
            )
        )

        // Q_TYPE_09 — Verdict Rapide d'Architecture (Autorisé / Bloqué / Conforme)
        let verdictOptions = [
            PrismChoiceOption(
                id: "\(codeLower)-q09-allow",
                badge: "✓",
                text: "CONFORME · Le flux respecte l'isolation et la résolution attendue",
                explanation: seed.examTrapNote,
                isCorrect: true
            ),
            PrismChoiceOption(
                id: "\(codeLower)-q09-deny",
                badge: "✕",
                text: "BLOQUÉ · Le flux échoue faute de liaison DNS ou d'autorisation",
                explanation: "Si le lien ou le rôle manque, la requête est rejetée.",
                isCorrect: false
            )
        ]
        let verdictSpec = CertiGoArchitectureVerdictSpec(
            flowChainText: seed.architectureFlow,
            constraintBanner: seed.examTrapNote,
            involvedAssetNames: [assets[0], assets[1], assets[2]],
            verdictOptions: verdictOptions
        )
        let verdictArtifact = PrismArtifactDocument(
            id: "\(codeLower)-verdict-doc",
            title: "verdict-\(codeLower).flow",
            language: "text",
            lines: [
                PrismArtifactLine(lineNumber: 1, text: seed.architectureFlow),
                PrismArtifactLine(lineNumber: 2, text: "Règle active : \(seed.examTrapNote)")
            ],
            spotTheIssueInteractive: false
        )
        let q09 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q09",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q09ArchitectureVerdict,
            stem: "[\(seed.code)] Quel est le verdict d'exécution pour le flux « \(seed.architectureFlow) » lorsque la configuration recommandée est active ?",
            region: seed.region,
            product: seed.product,
            mascotPose: .poseCrossedArms,
            primaryAssetName: assets[1],
            optionAssetNames: [assets[0], assets[1], assets[2]],
            architectureVerdict: verdictSpec,
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q09",
                conceptId: "\(codeLower).q09",
                product: seed.product,
                rung: 3,
                difficulty: 2,
                stem: "[\(seed.code)] Quel est le verdict d'exécution pour le flux « \(seed.architectureFlow) » lorsque la configuration recommandée est active ?",
                payload: .predict(artifact: verdictArtifact, options: verdictOptions)
            )
        )

        // Q_TYPE_10 — Multi-Sélection à Cases à Cocher (Exactement 2 Réponses)
        let q10Options = [
            PrismChoiceOption(
                id: "\(codeLower)-q10-1",
                badge: "1",
                text: "Activer \(labels[0]) avec identité ou liaison privée vérifiée",
                explanation: "Première condition indispensable pour sécuriser \(seed.code).",
                isCorrect: true
            ),
            PrismChoiceOption(
                id: "\(codeLower)-q10-2",
                badge: "2",
                text: "Configurer \(labels[2]) et valider la règle : \(seed.cliExpectedKeyword)",
                explanation: "Seconde condition requise pour garantir la résolution et la conformité.",
                isCorrect: true
            ),
            PrismChoiceOption(
                id: "\(codeLower)-q10-3",
                badge: "3",
                text: "Ouvrir le trafic 0.0.0.0/0 sans authentification ni chiffrement TLS",
                explanation: "Interdit par les exigences de sécurité \(seed.code).",
                isCorrect: false
            ),
            PrismChoiceOption(
                id: "\(codeLower)-q10-4",
                badge: "4",
                text: "Supprimer les journaux d'audit et désactiver les sauvegardes",
                explanation: "Compromet la résilience et la conformité.",
                isCorrect: false
            )
        ]
        let q10 = CertiGoInteractiveExerciseSpec(
            id: "\(codeLower)-q10",
            trackCode: seed.code,
            unitId: activeUnitId,
            format: .q10MultiSelectCheckboxes,
            stem: "[\(seed.code)] Sélectionne les 2 actions obligatoires pour valider la mise en production de « \(seed.unit3Title) » :",
            region: seed.region,
            product: seed.product,
            mascotPose: .emotionDetermined,
            primaryAssetName: assets[5 % assets.count],
            optionAssetNames: Array(assets.prefix(4)),
            sessionItem: PrismSessionItemModel(
                id: "\(codeLower)-item-q10",
                conceptId: "\(codeLower).q10",
                product: seed.product,
                rung: 4,
                difficulty: 3,
                stem: "[\(seed.code)] Sélectionne les 2 actions obligatoires pour valider la mise en production de « \(seed.unit3Title) » :",
                captureConfidence: true,
                payload: .choice(options: q10Options, allowsMultipleSelection: true)
            )
        )

        return [q01, q02, q03, q04, q05, q06, q07, q08, q09, q10]
    }

    public static func fallbackUnit(for code: String) -> CertiGoCurriculumUnit {
        parallelCertificationTracks[0].units[0]
    }
}

// MARK: - 4. Coordinator & Explorer Integration Extensions

extension CatalogExplorerModel {
    public static func multiTrackAndAIExplorer(activeRouteCode: String = "AZ-104") -> CatalogExplorerModel {
        CatalogExplorerModel(
            routes: CertiGoMultiTrackAndAIContentCatalog.catalogRouteItems(activeRouteCode: activeRouteCode)
        )
    }
}

extension PrismAppShellCoordinatorModel {
    public mutating func activateTrack(code: String) {
        let descriptor = CertiGoMultiTrackAndAIContentCatalog.track(forCode: code)
        let activeUnit = descriptor.activeUnit
        todayModel = TodayScreenModel(
            state: todayModel.state,
            suggestedLength: todayModel.suggestedLength,
            selectedLength: todayModel.selectedLength,
            composition: TodaySessionAtomSummary(
                dueRecallsCount: 6,
                newConceptsCount: 2,
                recommendedConceptTitle: activeUnit.title,
                recommendedProduct: descriptor.product
            ),
            activeRouteCode: descriptor.code,
            activeRouteTitle: descriptor.officialTitle,
            dailySituation: todayModel.dailySituation,
            rhythm: todayModel.rhythm
        )
        sessionPlayerMachine = CertiGoMultiTrackAndAIContentCatalog.sessionMachine(forTrackCode: descriptor.code)
        catalogExplorer = CatalogExplorerModel.multiTrackAndAIExplorer(activeRouteCode: descriptor.code)
    }
}

// MARK: - 5. SwiftUI Views for Multi-Track Switcher, AI Frontier Hub & 10 Question Formats

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct CertiGoServiceAssetIconView: View {
    public let assetName: String
    public let size: CGFloat

    public init(assetName: String, size: CGFloat = PrismSize.brandM) {
        self.assetName = assetName
        self.size = size
    }

    public var body: some View {
        Image(assetName, bundle: .module)
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(Text(verbatim: assetName))
            .accessibilityAddTraits(.isImage)
    }
}

public struct CertiGoQuestionFormatCardView: View {
    public let exercise: CertiGoInteractiveExerciseSpec
    @State private var selectedOptionId: String?
    @State private var selectedMultiOptionIds: Set<String> = []
    @State private var typedKeyword: String = ""

    public init(exercise: CertiGoInteractiveExerciseSpec) {
        self.exercise = exercise
    }

    public var body: some View {
        PrismCard(variant: .standard) {
            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                HStack(spacing: PrismSpacing.s) {
                    CertiGoServiceAssetIconView(
                        assetName: exercise.primaryAssetName,
                        size: PrismSize.brandM
                    )
                    PrismBadge(
                        configuration: PrismBadgeConfiguration(
                            text: "\(exercise.format.rawValue) · \(exercise.badgeTitle)",
                            semantics: .accent
                        )
                    )
                    Spacer(minLength: PrismSpacing.xs)
                    Text(verbatim: exercise.trackCode)
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.textSecondary)
                }

                CertiGoSpeechBubbleHeaderView(
                    region: exercise.region,
                    badgeText: exercise.badgeTitle,
                    questionText: exercise.stem,
                    poseOverride: exercise.mascotPose
                )

                formatSpecificBody
            }
        }
    }

    @ViewBuilder
    private var formatSpecificBody: some View {
        switch exercise.format {
        case .q02ServiceGrid2x2:
            VStack(spacing: PrismSpacing.s) {
                ForEach(exercise.serviceGridOptions) { card in
                    let isSelected = selectedOptionId == card.id
                    Button {
                        selectedOptionId = card.id
                    } label: {
                        HStack(spacing: PrismSpacing.m) {
                            CertiGoServiceAssetIconView(
                                assetName: card.assetName,
                                size: PrismSize.brandL
                            )
                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: "\(card.badge). \(card.serviceTitle)")
                                    .prismTextStyle(.subheadline)
                                    .foregroundStyle(PrismColor.textPrimary)
                                Text(verbatim: card.subtitle)
                                    .prismTextStyle(.caption)
                                    .foregroundStyle(PrismColor.textSecondary)
                            }
                            Spacer(minLength: PrismSpacing.xs)
                        }
                        .padding(PrismSpacing.m)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(isSelected ? PrismColor.accent.opacity(0.12) : PrismColor.canvas)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .strokeBorder(
                                    isSelected ? PrismColor.accent : PrismColor.separator,
                                    lineWidth: isSelected ? PrismBorder.strong : PrismBorder.regular
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

        case .q03InteractiveDiagram:
            if let slot = exercise.diagramSlot {
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    HStack(spacing: PrismSpacing.s) {
                        CertiGoServiceAssetIconView(assetName: slot.sourceAssetName, size: PrismSize.brandM)
                        Text(verbatim: slot.sourceLabel)
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.textPrimary)
                        Text(verbatim: slot.missingSlotPrompt)
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.accent)
                            .padding(.horizontal, PrismSpacing.s)
                            .padding(.vertical, PrismSpacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(PrismColor.accent.opacity(0.12))
                            )
                        CertiGoServiceAssetIconView(assetName: slot.targetAssetName, size: PrismSize.brandM)
                    }
                    ForEach(slot.candidateOptions) { candidate in
                        HStack(spacing: PrismSpacing.s) {
                            CertiGoServiceAssetIconView(assetName: candidate.assetName, size: PrismSize.brandS)
                            Text(verbatim: "\(candidate.badge). \(candidate.serviceTitle)")
                                .prismTextStyle(.subheadline)
                                .foregroundStyle(PrismColor.textPrimary)
                        }
                    }
                }
            }

        case .q04IOSKeyboardInput:
            if let kb = exercise.keyboardInput {
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    Text(verbatim: "\(kb.commandPrefix) [ \(kb.placeholder) ] \(kb.commandSuffix)")
                        .prismTextStyle(.codeSmall)
                        .foregroundStyle(PrismColor.accent)
                        .padding(PrismSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                .fill(PrismColor.canvas)
                        )
                    TextField(text: $typedKeyword) {
                        Text(verbatim: kb.placeholder)
                    }
                    .prismTextStyle(.codeSmall)
                    .padding(PrismSpacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .fill(PrismColor.canvas)
                    )
                }
            }

        case .q06MatchingPairs:
            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                ForEach(exercise.matchingPairs) { pair in
                    HStack(spacing: PrismSpacing.s) {
                        CertiGoServiceAssetIconView(assetName: pair.leftAssetName, size: PrismSize.brandS)
                        Text(verbatim: pair.leftSymbolOrService)
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.textPrimary)
                        Spacer(minLength: PrismSpacing.xs)
                        Text(verbatim: pair.rightRoleDescription)
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.textSecondary)
                    }
                    .padding(PrismSpacing.s)
                    .background(
                        RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                            .fill(PrismColor.canvas)
                    )
                }
            }

        case .q09ArchitectureVerdict:
            if let verdict = exercise.architectureVerdict {
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    HStack(spacing: PrismSpacing.s) {
                        ForEach(verdict.involvedAssetNames, id: \.self) { asset in
                            CertiGoServiceAssetIconView(assetName: asset, size: PrismSize.brandM)
                        }
                    }
                    Text(verbatim: verdict.flowChainText)
                        .prismTextStyle(.codeSmall)
                        .foregroundStyle(PrismColor.textPrimary)
                    Text(verbatim: verdict.constraintBanner)
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.textSecondary)
                }
            }

        case .q10MultiSelectCheckboxes:
            if case .choice(let options, _) = exercise.sessionItem.payload {
                VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                    ForEach(options) { opt in
                        let isChecked = selectedMultiOptionIds.contains(opt.id)
                        Button {
                            if isChecked {
                                selectedMultiOptionIds.remove(opt.id)
                            } else {
                                selectedMultiOptionIds.insert(opt.id)
                            }
                        } label: {
                            HStack(spacing: PrismSpacing.s) {
                                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                    .prismTextStyle(.subheadline)
                                    .foregroundStyle(isChecked ? PrismColor.accent : PrismColor.textSecondary)
                                Text(verbatim: opt.text)
                                    .prismTextStyle(.subheadline)
                                    .foregroundStyle(PrismColor.textPrimary)
                                Spacer(minLength: PrismSpacing.xs)
                            }
                            .padding(PrismSpacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.s, style: .continuous)
                                    .fill(isChecked ? PrismColor.accent.opacity(0.12) : PrismColor.canvas)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

        case .q01ScenarioQCM, .q05WordBankBricks, .q07JSONBugDiagnosis, .q08ScopeHierarchyOrdering:
            HStack(spacing: PrismSpacing.s) {
                ForEach(exercise.optionAssetNames, id: \.self) { asset in
                    CertiGoServiceAssetIconView(assetName: asset, size: PrismSize.brandS)
                }
                Spacer(minLength: PrismSpacing.xs)
                Text(verbatim: exercise.sessionItem.payload.formatIdentifier)
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.textSecondary)
            }
        }
    }
}

public struct CertiGoMultiTrackAndAICatalogScreen: View {
    @State private var selectedTrackCode: String
    public let onSelectTrack: (CertiGoTrackDescriptor) -> Void

    public init(
        initialTrackCode: String = "AZ-104",
        onSelectTrack: @escaping (CertiGoTrackDescriptor) -> Void = { _ in }
    ) {
        self._selectedTrackCode = State(initialValue: initialTrackCode)
        self.onSelectTrack = onSelectTrack
    }

    private var activeDescriptor: CertiGoTrackDescriptor {
        CertiGoMultiTrackAndAIContentCatalog.track(forCode: selectedTrackCode)
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PrismSpacing.l) {
                PrismSection(title: "13 Parcours Multi-Certifications en Parallèle") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PrismSpacing.s) {
                            ForEach(CertiGoMultiTrackAndAIContentCatalog.parallelCertificationTracks) { track in
                                trackChipButton(for: track)
                            }
                        }
                    }
                }

                PrismSection(title: "5 Parcours de Veille · Grands Acteurs de l'IA") {
                    VStack(alignment: .leading, spacing: PrismSpacing.s) {
                        ForEach(CertiGoMultiTrackAndAIContentCatalog.aiFrontierTracks) { aiTrack in
                            aiFrontierTrackRow(for: aiTrack)
                        }
                    }
                }

                PrismSection(title: "Unités & 10 Formats Validés (\(activeDescriptor.code))") {
                    VStack(alignment: .leading, spacing: PrismSpacing.m) {
                        ForEach(activeDescriptor.exercises) { exercise in
                            CertiGoQuestionFormatCardView(exercise: exercise)
                        }
                    }
                }
            }
            .padding(PrismSpacing.l)
        }
        .background(PrismColor.canvas)
        .navigationTitle(Text(verbatim: "Catalogue Multi-Certifs & Acteurs IA"))
    }

    @ViewBuilder
    private func trackChipButton(for track: CertiGoTrackDescriptor) -> some View {
        let isSelected = track.code == activeDescriptor.code
        Button {
            selectedTrackCode = track.code
            onSelectTrack(track)
        } label: {
            HStack(spacing: PrismSpacing.xs) {
                CertiGoServiceAssetIconView(assetName: track.certificationAssetName, size: PrismSize.brandM)
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: track.code)
                        .prismTextStyle(.subheadline)
                        .foregroundStyle(isSelected ? PrismColor.accent : PrismColor.textPrimary)
                    Text(verbatim: "\(track.readinessPercentage) % prêt")
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.textSecondary)
                }
            }
            .padding(.horizontal, PrismSpacing.m)
            .padding(.vertical, PrismSpacing.s)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(isSelected ? PrismColor.accent.opacity(0.12) : PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(
                        isSelected ? PrismColor.accent : PrismColor.separator,
                        lineWidth: isSelected ? PrismBorder.strong : PrismBorder.regular
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func aiFrontierTrackRow(for track: CertiGoTrackDescriptor) -> some View {
        let isSelected = track.code == activeDescriptor.code
        Button {
            selectedTrackCode = track.code
            onSelectTrack(track)
        } label: {
            HStack(spacing: PrismSpacing.m) {
                CertiGoServiceAssetIconView(assetName: track.brandLogoAssetName, size: PrismSize.brandM)
                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                    Text(verbatim: track.officialTitle)
                        .prismTextStyle(.headline)
                        .foregroundStyle(PrismColor.textPrimary)
                    Text(verbatim: track.shortSubtitle)
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.textSecondary)
                }
                Spacer(minLength: PrismSpacing.xs)
                PrismBadge(
                    configuration: PrismBadgeConfiguration(
                        text: "\(track.exercises.count) formats",
                        semantics: isSelected ? .accent : .neutral
                    )
                )
            }
            .padding(PrismSpacing.m)
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .fill(isSelected ? PrismColor.accent.opacity(0.1) : PrismColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.l, style: .continuous)
                    .strokeBorder(
                        isSelected ? PrismColor.accent : PrismColor.separator,
                        lineWidth: isSelected ? PrismBorder.strong : PrismBorder.regular
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
