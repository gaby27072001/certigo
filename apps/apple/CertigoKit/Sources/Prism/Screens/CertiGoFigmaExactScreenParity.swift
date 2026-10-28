import BrandAssets
import CertigoDomain
import Foundation

// MARK: - 1. Exact 1-for-1 Figma Pro Screen Content Model (49 Page 01 Screens + 4 Page 11/12 Screens)

public struct CertiGoFigmaExactScreenContent: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let screenCode: String
    public let figmaScreenKey: String
    public let nodeId: String
    public let figmaFrameName: String
    public let isPage01GroundTruthScreen: Bool
    public let chapterKind: CertiGoFigmaChapter
    public let region: PrismRegion
    public let title: String
    public let subtitle: String?
    public let badges: [String]
    public let counters: [String]
    public let buttonLabels: [String]
    public let exactTexts: [String]
    public let mascotPose: CertiGoMascotPose?
    public let officialCrestRouteCodes: [String]
    public let brandVendorIds: [String]
    public let serviceAssetNames: [String]

    public var id: String { screenCode }

    /// Alias matching `figma-ground-truth-49-screens.json` `"texts"` key.
    public var texts: [String] { exactTexts }

    public init(
        screenCode: String,
        figmaScreenKey: String,
        nodeId: String,
        figmaFrameName: String,
        isPage01GroundTruthScreen: Bool = true,
        chapterKind: CertiGoFigmaChapter,
        region: PrismRegion,
        title: String,
        subtitle: String? = nil,
        badges: [String] = [],
        counters: [String] = [],
        buttonLabels: [String] = [],
        exactTexts: [String],
        mascotPose: CertiGoMascotPose? = nil,
        officialCrestRouteCodes: [String] = [],
        brandVendorIds: [String] = [],
        serviceAssetNames: [String] = []
    ) {
        self.screenCode = screenCode
        self.figmaScreenKey = figmaScreenKey
        self.nodeId = nodeId
        self.figmaFrameName = figmaFrameName
        self.isPage01GroundTruthScreen = isPage01GroundTruthScreen
        self.chapterKind = chapterKind
        self.region = region
        self.title = title
        self.subtitle = subtitle
        self.badges = badges
        self.counters = counters
        self.buttonLabels = buttonLabels
        self.exactTexts = exactTexts
        self.mascotPose = mascotPose
        self.officialCrestRouteCodes = officialCrestRouteCodes
        self.brandVendorIds = brandVendorIds
        self.serviceAssetNames = serviceAssetNames
    }

    public static var page01Screens: [CertiGoFigmaExactScreenContent] {
        CertiGoFigmaExactScreenParity.page01Screens
    }

    public static var systemAndResilienceScreens: [CertiGoFigmaExactScreenContent] {
        CertiGoFigmaExactScreenParity.systemAndResilienceScreens
    }

    public static var allScreens: [CertiGoFigmaExactScreenContent] {
        CertiGoFigmaExactScreenParity.allScreens
    }

    public static func screen(forId screenId: String) -> CertiGoFigmaExactScreenContent? {
        CertiGoFigmaExactScreenParity.content(forScreenId: screenId)
    }
}

// MARK: - 2. Canonical Registry of the 49 Ground-Truth Page 01 Screens + 4 System/Resilience Screens

public enum CertiGoFigmaExactScreenParity {
    public static let expectedPage01ScreenCount: Int = 49
    public static let expectedSystemAndResilienceScreenCount: Int = 4
    public static let expectedTotalScreenCount: Int = 53

    /// All 49 screens extracted from Page 01 of Figma Pro (`figma-ground-truth-49-screens.json`).
    public static let page01Screens: [CertiGoFigmaExactScreenContent] = [
        // 15 · 26:807
        CertiGoFigmaExactScreenContent(
            screenCode: "15",
            figmaScreenKey: "15",
            nodeId: "26:807",
            figmaFrameName: "15 · Carte Déclic Visuelle (Micro-Leçon 20s)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "COMMENT VERROUILLER L'ISOLATION À 100 %",
            subtitle: "« Attention au piège : créer un Private Endpoint ne désactive PAS l'accès public par défaut ! »",
            badges: ["💡 CARTE DÉCLIC · MICRO-LEÇON 20 SEC"],
            counters: ["5"],
            buttonLabels: ["✕", "CONTINUER"],
            exactTexts: [
                "✕",
                "5",
                "CONTINUER",
                "COMMENT VERROUILLER L'ISOLATION À 100 %",
                "✕  Internet Public  ➔  publicNetworkAccess: Disabled",
                "✓  VNet (10.0.2.4)  ➔  privatelink.blob.core.windows.net",
                "1. Désactive l'accès réseau public",
                "Passe la propriété publicNetworkAccess sur « Disabled » dans le pare-feu de la ressource PaaS.",
                "2. Lie la zone DNS Privée au VNet",
                "Crée un Virtual Network Link vers privatelink.* pour résoudre le FQDN en IP privée 10.x.",
                "💡 CARTE DÉCLIC · MICRO-LEÇON 20 SEC",
                "« Attention au piège : créer un Private Endpoint ne désactive PAS l'accès public par défaut ! »"
            ],
            mascotPose: .emotionAhaIdea,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Private-Link", "AzureServices/DNS-Zones", "AzureServices/Virtual-Networks"]
        ),
        // 16 · 26:826
        CertiGoFigmaExactScreenContent(
            screenCode: "16",
            figmaScreenKey: "16",
            nodeId: "26:826",
            figmaFrameName: "16 · Exercice Grille 2×2 Visuelle (Duolingo 3D)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .ai,
            title: "Lequel de ces services fournit l'orchestration d'agents IA et le RAG vectoriel dans Azure ?",
            subtitle: "Grille 2×2 Visuelle de Services Officiels",
            badges: ["Azure AI Foundry", "AWS VPC", "Kubernetes CKA", "Azure VNet"],
            counters: ["5"],
            buttonLabels: ["✕", "VÉRIFIER"],
            exactTexts: [
                "✕",
                "5",
                "Lequel de ces services fournit l'orchestration d'agents IA et le RAG vectoriel dans Azure ?",
                "Azure AI Foundry",
                "AWS VPC",
                "Kubernetes CKA",
                "Azure VNet",
                "VÉRIFIER"
            ],
            mascotPose: .specialistCloudAzure,
            officialCrestRouteCodes: ["AI-102"],
            brandVendorIds: ["azure", "aws", "kubernetes"],
            serviceAssetNames: [
                "AzureServices/Cognitive-Services",
                "AWSServices/Amazon-Virtual-Private-Cloud",
                "AzureServices/Kubernetes-Services",
                "AzureServices/Virtual-Networks"
            ]
        ),
        // 17 · 26:863
        CertiGoFigmaExactScreenContent(
            screenCode: "17",
            figmaScreenKey: "17",
            nodeId: "26:863",
            figmaFrameName: "17 · Exercice Constructeur CLI & Code",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .devops,
            title: "Complète la commande Azure CLI pour créer le lien DNS privé sans auto-enregistrement :",
            subtitle: "1  az network private-dns link vnet create \\\n2    -g rg-prod \\\n3    -z privatelink.blob.core.windows.net \\\n4    -v vnet-hub -e false",
            badges: ["link vnet create", "-e false", "--public-ip true", "zone delete"],
            counters: ["5"],
            buttonLabels: ["✕", "VÉRIFIER"],
            exactTexts: [
                "✕",
                "5",
                "Complète la commande Azure CLI pour créer le lien DNS privé sans auto-enregistrement :",
                "1  az network private-dns link vnet create \\\n2    -g rg-prod \\\n3    -z privatelink.blob.core.windows.net \\\n4    -v vnet-hub -e false",
                "link vnet create",
                "-e false",
                "--public-ip true",
                "zone delete",
                "VÉRIFIER"
            ],
            mascotPose: .poseCLICoder,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/DNS-Zones", "AzureServices/Virtual-Networks"]
        ),
        // 18 · 26:890
        CertiGoFigmaExactScreenContent(
            screenCode: "18",
            figmaScreenKey: "18",
            nodeId: "26:890",
            figmaFrameName: "18 · Validation Réussie + Bouton IA [✦ EXPLIQUER MA RÉPONSE]",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "Quel enregistrement DNS redirige automatiquement le nom public vers la zone privatelink ?",
            subtitle: "✓  Un alias CNAME vers privatelink.blob.core.windows.net",
            badges: ["⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ", "✓  Excellent ! Bonne réponse"],
            counters: ["5"],
            buttonLabels: ["✕", "EXPLIQUER MA RÉPONSE", "CONTINUER"],
            exactTexts: [
                "✕",
                "5",
                "✓  Excellent ! Bonne réponse",
                "EXPLIQUER MA RÉPONSE",
                "CONTINUER",
                "✓  Un alias CNAME vers privatelink.blob.core.windows.net",
                "⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ",
                "Quel enregistrement DNS redirige automatiquement le nom public vers la zone privatelink ?"
            ],
            mascotPose: .poseVictoryJump,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/DNS-Zones", "AzureServices/Private-Link"]
        ),
        // 19 · 26:912
        CertiGoFigmaExactScreenContent(
            screenCode: "19",
            figmaScreenKey: "19",
            nodeId: "26:912",
            figmaFrameName: "19 · Célébration de Fin d'Étape (Coussin 3D Validé ✓, Précision 94 % & Série)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "Étape terminée !",
            subtitle: "Private Endpoint & DNS privé maîtrisé",
            badges: ["RYTHME", "PRÉCISION", "SÉRIE", "✓"],
            counters: ["14 sec ⚡", "94 %", "12 j 🔥"],
            buttonLabels: ["RETOUR AU PARCOURS"],
            exactTexts: [
                "Étape terminée !",
                "Private Endpoint & DNS privé maîtrisé",
                "RYTHME",
                "14 sec ⚡",
                "PRÉCISION",
                "94 %",
                "SÉRIE",
                "12 j 🔥",
                "RETOUR AU PARCOURS",
                "✓"
            ],
            mascotPose: .angleFrontCelebration,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Private-Link", "AzureServices/DNS-Zones"]
        ),
        // 20 · 26:939
        CertiGoFigmaExactScreenContent(
            screenCode: "20",
            figmaScreenKey: "20",
            nodeId: "26:939",
            figmaFrameName: "20 · Réponse IA & Comparateur Côte-à-Côte",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "←   Comparer 2 services Azure",
            subtitle: "Dès que l'énoncé mentionne « depuis On-Premises via ExpressRoute » ou « IP privée 10.x », choisis toujours Private Endpoint !",
            badges: ["Service Endpoint", "Private Endpoint", "✓ RÈGLE D'OR POUR L'EXAMEN AZ-104"],
            counters: [],
            buttonLabels: ["Parcours", "Examens", "Social", "Moi"],
            exactTexts: [
                "←   Comparer 2 services Azure",
                "Service Endpoint",
                "• Garde l'IP publique du service PaaS\n\n• Pas besoin de DNS privé\n\n• Non routable depuis On-Premises (VPN / ExpressRoute)",
                "Private Endpoint",
                "• Crée une NIC avec IP privée (10.x) dans ton Subnet\n\n• Requiert une zone privatelink\n\n• Accessible depuis On-Premises",
                "✓ RÈGLE D'OR POUR L'EXAMEN AZ-104",
                "Dès que l'énoncé mentionne « depuis On-Premises via ExpressRoute » ou « IP privée 10.x », choisis toujours Private Endpoint !",
                "Parcours",
                "Examens",
                "Social",
                "Moi"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Virtual-Networks", "AzureServices/Private-Link"]
        ),
        // 22 · 26:1009
        CertiGoFigmaExactScreenContent(
            screenCode: "22",
            figmaScreenKey: "22",
            nodeId: "26:1009",
            figmaFrameName: "22 · Lancement Examen Blanc (Feuille Apple Pay + Vrai Blason Officiel AZ-104)",
            chapterKind: .pearsonVueExamSimulationPage09,
            region: .cloud,
            title: "Examen Blanc Complet (50 Q)",
            subtitle: "90 min · Seuil 700/1000 · Dernier : 785 ✓",
            badges: ["CONDITIONS PEARSON VUE", "AZ-104 ▾", "S'ENTRAÎNER PAR DOMAINE OFFICIEL AZ-104"],
            counters: ["88 %", "82 %"],
            buttonLabels: ["DÉMARRER L'EXAMEN COMPLET", "Parcours", "Examens", "Social", "Moi"],
            exactTexts: [
                "Parcours",
                "Examens",
                "Social",
                "Moi",
                "Examens · AZ-104",
                "AZ-104 ▾",
                "CONDITIONS PEARSON VUE",
                "Examen Blanc Complet (50 Q)",
                "90 min · Seuil 700/1000 · Dernier : 785 ✓",
                "DÉMARRER L'EXAMEN COMPLET",
                "S'ENTRAÎNER PAR DOMAINE OFFICIEL AZ-104",
                "1. Identité & Gouvernance Entra ID",
                "Poids officiel : 20–25 %",
                "88 %",
                "2. Stockage & Sécurité des données",
                "Poids officiel : 15–20 %",
                "82 %",
                "3. Déploiement Calcul, VM & AKS"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups", "AzureServices/Storage-Accounts", "AzureServices/Virtual-Machine"]
        ),
        // 01 · 37:375
        CertiGoFigmaExactScreenContent(
            screenCode: "01",
            figmaScreenKey: "01",
            nodeId: "37:375",
            figmaFrameName: "01 · Accueil Fondateur (Îlots Waymo + Rail Mimo Logos 3D)",
            chapterKind: .homeAndWaymoPath,
            region: .cloud,
            title: "UNITÉ 1 · Identité Entra ID",
            subtitle: "Rôles RBAC & PIM",
            badges: ["AZ-104 ▾", "🧪 MINI-LAB PRATIQUE", "✓", "▶", "📖"],
            counters: ["🔥 14", "💎 480", "❤️ 5", "65%"],
            buttonLabels: ["CONTINUER", "Parcours"],
            exactTexts: [
                "✓",
                "Concepts Cloud Azure",
                "✓",
                "Identité Entra ID",
                "CONTINUER",
                "Rôles RBAC & PIM",
                "🧪 MINI-LAB PRATIQUE",
                "Réparer un accès RBAC refusé",
                "▶",
                "Accès Conditionnel",
                "AZ-104 ▾",
                "🔥 14",
                "💎 480",
                "❤️ 5",
                "65%",
                "UNITÉ 1 · Identité Entra ID",
                "📖",
                "Parcours"
            ],
            mascotPose: .angle34LeftPath,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure", "aws", "gcp", "github"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups", "AzureServices/Key-Vaults", "AzureServices/Virtual-Networks"]
        ),
        // 02 · 42:375
        CertiGoFigmaExactScreenContent(
            screenCode: "02",
            figmaScreenKey: "02",
            nodeId: "42:375",
            figmaFrameName: "02 · Popover Flottant (Logos Officiels + Nom Actif Seul)",
            chapterKind: .homeAndWaymoPath,
            region: .cloud,
            title: "UNITÉ 1 · Identité Entra ID",
            subtitle: "Popover Flottant Marques & Certifications",
            badges: ["AZ-104 ▾", "🧪 MINI-LAB PRATIQUE"],
            counters: ["🔥 14", "💎 480", "❤️ 5", "65%"],
            buttonLabels: ["CONTINUER", "Parcours"],
            exactTexts: [
                "✓",
                "Concepts Cloud Azure",
                "✓",
                "Identité Entra ID",
                "CONTINUER",
                "Rôles RBAC & PIM",
                "🧪 MINI-LAB PRATIQUE",
                "Réparer un accès RBAC refusé",
                "▶",
                "Accès Conditionnel",
                "AZ-104 ▾",
                "🔥 14",
                "💎 480",
                "❤️ 5",
                "65%",
                "UNITÉ 1 · Identité Entra ID",
                "📖",
                "Parcours"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104", "SAA-C03", "GH-300"],
            brandVendorIds: ["microsoft", "aws", "gcp", "github", "claude", "openai"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups", "AWSServices/Amazon-Virtual-Private-Cloud"]
        ),
        // 03 · 49:368
        CertiGoFigmaExactScreenContent(
            screenCode: "03",
            figmaScreenKey: "03",
            nodeId: "49:368",
            figmaFrameName: "03 · Feuille Flottante Épurée (Mix B+C : Haut Centré + 3 Boutons [📖 | COMMENCER | ✦])",
            chapterKind: .homeAndWaymoPath,
            region: .security,
            title: "Rôles RBAC & PIM",
            subtitle: "UNITÉ 1 · Identité Entra ID",
            badges: ["AZ-104 ▾", "🧪 MINI-LAB PRATIQUE"],
            counters: ["🔥 14", "💎 480", "❤️ 5", "65%"],
            buttonLabels: ["CONTINUER", "📖", "Parcours"],
            exactTexts: [
                "✓",
                "Concepts Cloud Azure",
                "✓",
                "Identité Entra ID",
                "CONTINUER",
                "Rôles RBAC & PIM",
                "🧪 MINI-LAB PRATIQUE",
                "Réparer un accès RBAC refusé",
                "▶",
                "Accès Conditionnel",
                "AZ-104 ▾",
                "🔥 14",
                "💎 480",
                "❤️ 5",
                "65%",
                "UNITÉ 1 · Identité Entra ID",
                "📖",
                "Parcours"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups"]
        ),
        // 14 · 58:705
        CertiGoFigmaExactScreenContent(
            screenCode: "14",
            figmaScreenKey: "14",
            nodeId: "58:705",
            figmaFrameName: "14 · Fiche Mémo Dépliée (Structure C Tableau Apple Pay : Activité · Sujets Clés · Règle d'Or)",
            chapterKind: .homeAndWaymoPath,
            region: .security,
            title: "UNITÉ 1 · Identité Entra ID",
            subtitle: "Fiche Mémo Dépliée · Rôles RBAC & PIM",
            badges: ["AZ-104 ▾", "🧪 MINI-LAB PRATIQUE"],
            counters: ["🔥 14", "💎 480", "❤️ 5", "65%"],
            buttonLabels: ["CONTINUER", "📖", "Parcours"],
            exactTexts: [
                "✓",
                "Concepts Cloud Azure",
                "✓",
                "Identité Entra ID",
                "CONTINUER",
                "Rôles RBAC & PIM",
                "🧪 MINI-LAB PRATIQUE",
                "Réparer un accès RBAC refusé",
                "▶",
                "Accès Conditionnel",
                "AZ-104 ▾",
                "🔥 14",
                "💎 480",
                "❤️ 5",
                "65%",
                "UNITÉ 1 · Identité Entra ID",
                "📖",
                "Parcours"
            ],
            mascotPose: .poseReaderMemo,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups", "AzureServices/Key-Vaults"]
        ),
        // 05 · 62:346
        CertiGoFigmaExactScreenContent(
            screenCode: "05",
            figmaScreenKey: "05",
            nodeId: "62:346",
            figmaFrameName: "05 · Feuille Flottante d'Explication IA (Mix B+D : 3 Cartes Colorées sur Question + [✦ Question IA | CONTINUER])",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "Pas tout à fait...",
            subtitle: "Bonne réponse : Lecteur (Reader)",
            badges: ["⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ", "ISOLATION PAAS · PRIVATE LINK", "Explication de ta réponse"],
            counters: ["❤️ 4"],
            buttonLabels: ["✕", "EXPLIQUER MON ERREUR", "J'AI COMPRIS"],
            exactTexts: [
                "✕",
                "❤️ 4",
                "⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ",
                "ISOLATION PAAS · PRIVATE LINK",
                "Une VM dans VNet-Prod doit lire un coffre Key Vault via une IP privée 10.0.2.4 sans exposition Internet.",
                "B",
                "Lecteur (Reader)",
                "✓",
                "C",
                "Propriétaire (Owner)",
                "D",
                "Administrateur de l'accès utilisateur",
                "✕",
                "Pas tout à fait...",
                "Bonne réponse : Lecteur (Reader)",
                "EXPLIQUER MON ERREUR",
                "J'AI COMPRIS",
                "Explication de ta réponse"
            ],
            mascotPose: .specialistAICoach,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Private-Link", "AzureServices/Key-Vaults"]
        ),
        // 04 · 73:332
        CertiGoFigmaExactScreenContent(
            screenCode: "04",
            figmaScreenKey: "04",
            nodeId: "73:332",
            figmaFrameName: "04 · Exercice Flashcard Empilée Duolingo (Possibilité 4 Validée)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "Une VM dans VNet-Prod doit lire un coffre Key Vault via une IP privée 10.0.2.4 sans exposition Internet.\nQuel service déploies-tu ?",
            subtitle: "Incorrect · Bonne réponse : Lecteur",
            badges: ["⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ"],
            counters: ["4"],
            buttonLabels: ["✕", "EXPLIQUER MON ERREUR", "CONTINUER"],
            exactTexts: [
                "4",
                "Contributeur (Contributor)",
                "Lecteur (Reader)",
                "Propriétaire (Owner)",
                "Administrateur de l'accès",
                "✕",
                "Incorrect · Bonne réponse : Lecteur",
                "EXPLIQUER MON ERREUR",
                "CONTINUER",
                "⚡ RÉSEAUX VIRTUELS & DNS PRIVÉ",
                "Une VM dans VNet-Prod doit lire un coffre Key Vault via une IP privée 10.0.2.4 sans exposition Internet.\nQuel service déploies-tu ?"
            ],
            mascotPose: .specialistSecurityEntra,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Private-Link", "AzureServices/Key-Vaults", "AzureServices/Virtual-Networks"]
        ),
        // Q_TYPE_01 · 73:393
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_01",
            figmaScreenKey: "Q_TYPE_01",
            nodeId: "73:393",
            figmaFrameName: "Q_TYPE_01 · QCM Scénario & Pilule Bleu Ciel (Possibilité 4)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .security,
            title: "Un auditeur externe doit vérifier toutes les ressources d'un abonnement Azure en lecture seule.\nQuel rôle intégré lui attribuer ?",
            subtitle: "Rôles RBAC & PIM",
            badges: ["Rôles RBAC & PIM"],
            counters: ["5"],
            buttonLabels: ["VÉRIFIER"],
            exactTexts: [
                "5",
                "Rôles RBAC & PIM",
                "Contributeur (Contributor)",
                "Lecteur (Reader)",
                "Propriétaire (Owner)",
                "Administrateur de l'accès",
                "VÉRIFIER",
                "Un auditeur externe doit vérifier toutes les ressources d'un abonnement Azure en lecture seule.\nQuel rôle intégré lui attribuer ?"
            ],
            mascotPose: .specialistSecurityEntra,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups"]
        ),
        // Q_TYPE_02 · 73:442
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_02",
            figmaScreenKey: "Q_TYPE_02",
            nodeId: "73:442",
            figmaFrameName: "Q_TYPE_02 · Sélection de Symboles de Services (Grille 2×2)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .security,
            title: "Quel service Azure permet de stocker les clés cryptographiques et certificats TLS dans un coffre matériel ?",
            subtitle: "Sécurité Azure",
            badges: ["Sécurité Azure", "Key Vault", "Entra ID", "Azure Firewall", "Blob Storage"],
            counters: ["5"],
            buttonLabels: ["VÉRIFIER"],
            exactTexts: [
                "5",
                "Sécurité Azure",
                "Key Vault",
                "Entra ID",
                "Azure Firewall",
                "Blob Storage",
                "VÉRIFIER",
                "Quel service Azure permet de stocker les clés cryptographiques et certificats TLS dans un coffre matériel ?"
            ],
            mascotPose: .specialistCloudAzure,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: [
                "AzureServices/Key-Vaults",
                "AzureServices/Network-Security-Groups",
                "AzureServices/Firewalls",
                "AzureServices/Storage-Accounts"
            ]
        ),
        // Q_TYPE_03 · 73:509
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_03",
            figmaScreenKey: "Q_TYPE_03",
            nodeId: "73:509",
            figmaFrameName: "Q_TYPE_03 · Schéma d'Architecture Interactif",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "Quelle brique placer dans l'emplacement [ ? ]",
            subtitle: "pour filtrer le trafic HTTPS (WAF Couche 7)",
            badges: ["Architecture VNet", "Flux : Internet ➔ Inspection WAF L7 ➔ VNet"],
            counters: ["5"],
            buttonLabels: ["Azure Application Gateway (WAF)", "Azure Load Balancer (Couche 4 TCP/UDP)", "Azure NAT Gateway"],
            exactTexts: [
                "5",
                "Architecture VNet",
                "Quelle brique placer dans l'emplacement [ ? ]",
                "pour filtrer le trafic HTTPS (WAF Couche 7)",
                "🌐",
                "Clients",
                "HTTPS",
                "➔",
                "?",
                "Couche 7",
                "+ WAF",
                "➔",
                "VNet Privé",
                "App Web",
                "Flux : Internet ➔ Inspection WAF L7 ➔ VNet",
                "Azure Application Gateway (WAF)",
                "Azure Load Balancer (Couche 4 TCP/UDP)",
                "Azure NAT Gateway"
            ],
            mascotPose: .specialistNetworkVNet,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: [
                "AzureServices/Application-Gateways",
                "AzureServices/Load-Balancers",
                "AzureServices/NAT",
                "AzureServices/Virtual-Networks"
            ]
        ),
        // Q_TYPE_04 · 73:575
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_04",
            figmaScreenKey: "Q_TYPE_04",
            nodeId: "73:575",
            figmaFrameName: "Q_TYPE_04 · Saisie au Clavier iOS",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .devops,
            title: "az group lock create --lock-type CanNotDelete -g RG-Prod",
            subtitle: "Azure CLI",
            badges: ["Azure CLI", "\"lock\"", "lock", "list"],
            counters: ["5"],
            buttonLabels: ["VÉRIFIER", "A", "Z", "E", "R", "T", "Y", "U", "I"],
            exactTexts: [
                "5",
                "Azure CLI",
                "az group",
                "lock",
                "create",
                "--lock-type CanNotDelete -g RG-Prod",
                "VÉRIFIER",
                "\"lock\"",
                "lock",
                "list",
                "A",
                "Z",
                "E",
                "R",
                "T",
                "Y",
                "U",
                "I"
            ],
            mascotPose: .specialistCLIContainers,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Resource-Groups"]
        ),
        // Q_TYPE_05 · 73:743
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_05",
            figmaScreenKey: "Q_TYPE_05",
            nodeId: "73:743",
            figmaFrameName: "Q_TYPE_05 · Assemblage de Briques (Word Bank)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .devops,
            title: "Construis la commande CLI qui crée le réseau virtuel ProdVNet dans le groupe RG-Core :",
            subtitle: "PowerShell & CLI",
            badges: ["PowerShell & CLI", "az", "network", "vnet", "create", "--name ProdVNet", "-g RG-Core"],
            counters: ["5"],
            buttonLabels: ["VÉRIFIER"],
            exactTexts: [
                "5",
                "PowerShell & CLI",
                "az",
                "network",
                "vnet",
                "create",
                "--name ProdVNet",
                "-g RG-Core",
                "delete",
                "vm",
                "--sku Basic",
                "list",
                "VÉRIFIER",
                "Construis la commande CLI qui crée le réseau virtuel ProdVNet dans le groupe RG-Core :"
            ],
            mascotPose: .specialistCLIContainers,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Virtual-Networks", "AzureServices/Resource-Groups"]
        ),
        // Q_TYPE_06 · 73:818
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_06",
            figmaScreenKey: "Q_TYPE_06",
            nodeId: "73:818",
            figmaFrameName: "Q_TYPE_06 · Paires à Relier (Symboles ↔ Rôles)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .data,
            title: "Associe chaque symbole de service Cloud à sa fonction exacte :",
            subtitle: "Services Azure",
            badges: ["Services Azure", "Entra ID", "Key Vault", "VNet", "Firewall"],
            counters: ["5"],
            buttonLabels: ["VÉRIFIER"],
            exactTexts: [
                "5",
                "Services Azure",
                "Entra ID",
                "Key Vault",
                "VNet",
                "Firewall",
                "Coffre de secrets & clés",
                "Identité & SSO",
                "Filtrage réseau L3-L7",
                "Réseau virtuel isolé",
                "VÉRIFIER",
                "Associe chaque symbole de service Cloud à sa fonction exacte :"
            ],
            mascotPose: .specialistDataSQL,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: [
                "AzureServices/Network-Security-Groups",
                "AzureServices/Key-Vaults",
                "AzureServices/Virtual-Networks",
                "AzureServices/Firewalls"
            ]
        ),
        // Q_TYPE_07 · 73:898
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_07",
            figmaScreenKey: "Q_TYPE_07",
            nodeId: "73:898",
            figmaFrameName: "Q_TYPE_07 · Diagnostic d'Erreur dans une Règle JSON",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .security,
            title: "Ce rôle personnalisé doit uniquement lire les VMs. Touche la ligne JSON qui bloque tout :",
            subtitle: "Rôles Personnalisés",
            badges: ["Rôles Personnalisés"],
            counters: ["5", "1", "2", "3", "4", "5"],
            buttonLabels: ["VÉRIFIER"],
            exactTexts: [
                "5",
                "Rôles Personnalisés",
                "1",
                "\"Name\": \"VM Audit Reader\",",
                "2",
                "\"IsCustom\": true,",
                "3",
                "\"Actions\": [ \"Microsoft.Compute/*/read\" ],",
                "4",
                "\"NotActions\": [ \"*\" ],",
                "5",
                "\"AssignableScopes\": [ \"/subscriptions/sub-1\" ]",
                "VÉRIFIER",
                "Ce rôle personnalisé doit uniquement lire les VMs. Touche la ligne JSON qui bloque tout :"
            ],
            mascotPose: .specialistSecurityEntra,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Virtual-Machine", "AzureServices/Network-Security-Groups"]
        ),
        // Q_TYPE_08 · 73:958
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_08",
            figmaScreenKey: "Q_TYPE_08",
            nodeId: "73:958",
            figmaFrameName: "Q_TYPE_08 · Classer dans l'Ordre (Hiérarchie Scope)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .cloud,
            title: "Gouvernance Azure",
            subtitle: "Hiérarchie Scope (1 ➔ 4)",
            badges: ["Gouvernance Azure"],
            counters: ["5", "1", "2", "3", "4"],
            buttonLabels: ["≡"],
            exactTexts: [
                "5",
                "Gouvernance Azure",
                "1",
                "Groupe d'administration",
                "Management Group (Multi-abonnements)",
                "≡",
                "2",
                "Abonnement (Subscription)",
                "Facturation & limites globales",
                "≡",
                "3",
                "Groupe de ressources",
                "Conteneur logique de cycle de vie",
                "≡",
                "4",
                "Ressource individuelle",
                "Ex. Machine virtuelle, Key Vault, VNet",
                "≡"
            ],
            mascotPose: .specialistCloudAzure,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Management-Groups", "AzureServices/Subscriptions", "AzureServices/Resource-Groups"]
        ),
        // Q_TYPE_09 · 73:1019
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_09",
            figmaScreenKey: "Q_TYPE_09",
            nodeId: "73:1019",
            figmaFrameName: "Q_TYPE_09 · Verdict Architecture (Autorisé vs Bloqué)",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .network,
            title: "Alice pourra-t-elle supprimer la base SQL ?",
            subtitle: "Verrous Azure",
            badges: ["Verrous Azure", "AUTORISÉ", "BLOQUÉ"],
            counters: ["5"],
            buttonLabels: ["AUTORISÉ", "BLOQUÉ", "VÉRIFIER"],
            exactTexts: [
                "5",
                "Verrous Azure",
                "Alice pourra-t-elle supprimer la base SQL ?",
                "1. PERMISSION RBAC D'ALICE",
                "✓  Rôle « Propriétaire (Owner) » sur l'abonnement",
                "2. VERROU SUR LE GROUPE DE RESSOURCES",
                "🔒  Verrou « CanNotDelete » actif sur RG-Prod",
                "3. ACTION TENTÉE PAR ALICE",
                "Supprimer la ressource « sql-prod-db »",
                "✓",
                "AUTORISÉ",
                "Owner est prioritaire",
                "🔒",
                "BLOQUÉ",
                "Le verrou s'applique",
                "VÉRIFIER"
            ],
            mascotPose: .specialistNetworkVNet,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/SQL-Database", "AzureServices/Resource-Groups"]
        ),
        // Q_TYPE_10 · 73:1070
        CertiGoFigmaExactScreenContent(
            screenCode: "Q_TYPE_10",
            figmaScreenKey: "Q_TYPE_10",
            nodeId: "73:1070",
            figmaFrameName: "Q_TYPE_10 · Multi-Sélection à Cases à Cocher",
            chapterKind: .questionsAndTenFormatsPage06,
            region: .ai,
            title: "Quelles vérifications peux-tu exiger lors de l'activation d'un rôle Entra PIM ? (Choisis 2 réponses)",
            subtitle: "Entra ID PIM",
            badges: ["Entra ID PIM", "✓"],
            counters: ["5"],
            buttonLabels: ["VÉRIFIER"],
            exactTexts: [
                "5",
                "Entra ID PIM",
                "Authentification multifacteur (MFA)",
                "✓",
                "Justification métier + approbation",
                "✓",
                "Redémarrage du contrôleur de domaine",
                "Suppression du groupe de ressources",
                "VÉRIFIER",
                "Quelles vérifications peux-tu exiger lors de l'activation d'un rôle Entra PIM ? (Choisis 2 réponses)"
            ],
            mascotPose: .specialistAICoach,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups"]
        ),
        // 06B · 78:332
        CertiGoFigmaExactScreenContent(
            screenCode: "06B",
            figmaScreenKey: "06B",
            nodeId: "78:332",
            figmaFrameName: "06B · Réponse Écrite Style Gemini (avec Bouton Historique & Barre Vocale)",
            chapterKind: .aiHubFourModes,
            region: .ai,
            title: "Quelle est la différence entre RBAC et Azure Policy ?",
            subtitle: "CertiGo IA",
            badges: ["CertiGo IA", "💡  À retenir pour l'examen AZ-104 :"],
            counters: [],
            buttonLabels: ["Copier", "📖  Sauver en Mémo", "🎯 Quiz", "+"],
            exactTexts: [
                "Quelle est la différence entre RBAC et Azure Policy ?",
                "CertiGo IA",
                "Ces deux services assurent la gouvernance Azure, mais ils agissent sur deux dimensions différentes :",
                "•  Azure RBAC (Qui fait quoi) : Gère les accès des utilisateurs et groupes en attribuant des rôles (Lecteur, Contributeur, Propriétaire).",
                "•  Azure Policy (Sous quelles règles) : Vérifie la conformité des ressources elles-mêmes (ex. imposer une région ou un tag obligatoire).",
                "💡  À retenir pour l'examen AZ-104 :",
                "•  Priorité des règles : Même un utilisateur Propriétaire (Owner) est bloqué si une Azure Policy interdit la région choisie.",
                "•  Cumul : Un utilisateur doit être autorisé à la fois par son rôle RBAC et par les stratégies Azure Policy actives.",
                "Si tu veux, je peux te montrer un exemple JSON ou te poser une question type examen sur ce sujet.",
                "Copier",
                "📖  Sauver en Mémo",
                "🎯 Quiz",
                "+",
                "Demander à CertiGo IA..."
            ],
            mascotPose: .specialistAICoach,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure", "copilot"],
            serviceAssetNames: ["AzureServices/Policy", "AzureServices/Network-Security-Groups"]
        ),
        // 06A / 06 · 79:332
        CertiGoFigmaExactScreenContent(
            screenCode: "06A",
            figmaScreenKey: "06",
            nodeId: "79:332",
            figmaFrameName: "06 · Accueil Hub IA (Style Gemini + Suggestions + Barre Écrit & Vocal [ılı])",
            chapterKind: .aiHubFourModes,
            region: .ai,
            title: "Bonjour Gabriel,",
            subtitle: "Comment veux-tu réviser aujourd'hui ?",
            badges: ["📘", "🎙️", "🎯", "⚡"],
            counters: [],
            buttonLabels: ["+", "Parcours", "Examens"],
            exactTexts: [
                "Bonjour Gabriel,",
                "Comment veux-tu réviser aujourd'hui ?",
                "📘",
                "Explique-moi RBAC vs Azure Policy",
                "Synthèse claire + astuce d'examen AZ-104",
                "🎙️",
                "Simuler un entretien oral à voix haute",
                "Mode Conversation Vocale Live avec l'IA",
                "🎯",
                "Analyse mes 3 dernières erreurs",
                "Diagnostic ciblé sur tes points faibles",
                "⚡",
                "Génère un exemple Azure CLI commenté",
                "Commandes prêtes pour le lab pratique",
                "+",
                "Écrire ou parler à CertiGo IA...",
                "Parcours",
                "Examens"
            ],
            mascotPose: .specialistAICoach,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure", "copilot", "claude", "gemini"],
            serviceAssetNames: ["AzureServices/Cognitive-Services", "AzureServices/Policy"]
        ),
        // 06C · 81:345
        CertiGoFigmaExactScreenContent(
            screenCode: "06C",
            figmaScreenKey: "06C",
            nodeId: "81:345",
            figmaFrameName: "06C · Conversation Vocale Live (Option 1 : Logo IA Animé + Texte Épuré + Indicateur Voix Utilisateur Central)",
            chapterKind: .aiHubFourModes,
            region: .ai,
            title: "« Et si je suis Propriétaire mais qu'une Azure Policy bloque la région ? »",
            subtitle: "C'est toujours l'Azure Policy qui l'emporte. Même avec le rôle Propriétaire, la création sera refusée tant que la région ne respecte pas la règle...",
            badges: ["LIVE VOCAL IA"],
            counters: [],
            buttonLabels: [],
            exactTexts: [
                "« Et si je suis Propriétaire mais qu'une Azure Policy bloque la région ? »",
                "C'est toujours l'Azure Policy qui l'emporte. Même avec le rôle Propriétaire, la création sera refusée tant que la région ne respecte pas la règle..."
            ],
            mascotPose: .specialistAICoach,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure", "copilot"],
            serviceAssetNames: ["AzureServices/Policy"]
        ),
        // 06D · 85:317
        CertiGoFigmaExactScreenContent(
            screenCode: "06D",
            figmaScreenKey: "06D",
            nodeId: "85:317",
            figmaFrameName: "06D · Historique des Conversations IA (Choix A : Tiroir Push Claude 85% Largeur)",
            chapterKind: .aiHubFourModes,
            region: .ai,
            title: "Différence RBAC vs Azure Policy",
            subtitle: "🔍   Rechercher une discussion...",
            badges: ["Épinglées", "CertiGo IA"],
            counters: [],
            buttonLabels: ["Copier", "📖  Sauver en Mémo", "🎯 Quiz", "+"],
            exactTexts: [
                "Quelle est la différence entre RBAC et Azure Policy ?",
                "CertiGo IA",
                "Ces deux services assurent la gouvernance Azure, mais ils agissent sur deux dimensions différentes :",
                "•  Azure RBAC (Qui fait quoi) : Gère les accès des utilisateurs et groupes en attribuant des rôles (Lecteur, Contributeur, Propriétaire).",
                "•  Azure Policy (Sous quelles règles) : Vérifie la conformité des ressources elles-mêmes (ex. imposer une région ou un tag obligatoire).",
                "💡  À retenir pour l'examen AZ-104 :",
                "•  Priorité des règles : Même un utilisateur Propriétaire (Owner) est bloqué si une Azure Policy interdit la région choisie.",
                "•  Cumul : Un utilisateur doit être autorisé à la fois par son rôle RBAC et par les stratégies Azure Policy actives.",
                "Si tu veux, je peux te montrer un exemple JSON ou te poser une question type examen sur ce sujet.",
                "Copier",
                "📖  Sauver en Mémo",
                "🎯 Quiz",
                "+",
                "Demander à CertiGo IA...",
                "CertiGo IA",
                "🔍   Rechercher une discussion...",
                "Épinglées",
                "Différence RBAC vs Azure Policy"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["claude", "copilot", "azure"],
            serviceAssetNames: ["AzureServices/Policy"]
        ),
        // 07A / 07 · 88:317
        CertiGoFigmaExactScreenContent(
            screenCode: "07A",
            figmaScreenKey: "07",
            nodeId: "88:317",
            figmaFrameName: "07 · Onglet Social : Podium 3D Semaine (Variante A Validée)",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .cloud,
            title: "Social",
            subtitle: "🏆 Podium Semaine",
            badges: ["⏳ Semaine · 3j", "🏆 Podium Semaine", "👥 Mes Amis (12)"],
            counters: ["14 étapes", "19 étapes · 🔥14", "2e", "1er", "3"],
            buttonLabels: ["Ajouter"],
            exactTexts: [
                "Social",
                "⏳ Semaine · 3j",
                "Ajouter",
                "🏆 Podium Semaine",
                "👥 Mes Amis (12)",
                "SL",
                "2",
                "Sarah L.",
                "14 étapes",
                "2e",
                "GC",
                "1",
                "Toi (Gabriel)",
                "19 étapes · 🔥14",
                "1er",
                "TM",
                "3",
                "Thomas M."
            ],
            mascotPose: .angleLookupPodium,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "aws", "gcp"],
            serviceAssetNames: []
        ),
        // 25 · 89:317
        CertiGoFigmaExactScreenContent(
            screenCode: "25",
            figmaScreenKey: "25",
            nodeId: "89:317",
            figmaFrameName: "25 · Onglet Social : Vue « Mes Amis (12) & Ajouter un Ami » (Variante A)",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .cloud,
            title: "👥 Mes Amis (12)",
            subtitle: "EN LIGNE / ACTIFS AUJOURD'HUI",
            badges: ["⏳ Semaine · 3j", "EN LIGNE / ACTIFS AUJOURD'HUI"],
            counters: ["En train de réviser GCP ACE · 🔥 18j"],
            buttonLabels: ["Ajouter", "Copier", "👋 Salut", "Parcours", "Examens", "Social", "Moi"],
            exactTexts: [
                "Social",
                "⏳ Semaine · 3j",
                "Ajouter",
                "Parcours",
                "Examens",
                "Social",
                "Moi",
                "🏆 Podium Semaine",
                "👥 Mes Amis (12)",
                "🔍   Chercher ou ajouter un pseudo...",
                "🔗  Partager mon lien d'invitation d'ami",
                "Copier",
                "EN LIGNE / ACTIFS AUJOURD'HUI",
                "SL",
                "Sarah Laurent",
                "En train de réviser GCP ACE · 🔥 18j",
                "👋 Salut",
                "TM"
            ],
            mascotPose: .angleSprintRight,
            officialCrestRouteCodes: ["ACE", "AZ-104"],
            brandVendorIds: ["gcp", "azure"],
            serviceAssetNames: []
        ),
        // 08 · 97:287
        CertiGoFigmaExactScreenContent(
            screenCode: "08",
            figmaScreenKey: "08",
            nodeId: "97:287",
            figmaFrameName: "08 · Onglet Moi (Variante A : Stylo Photo + Bouton Statistiques Pro + Vrais Blasons Officiels)",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .cloud,
            title: "Mon Profil",
            subtitle: "Gabriel Chambaud · @gabriel  ·  Membre CertiGo PRO",
            badges: ["CERTIFICATIONS PROFESSIONNELLES", "AzureFundamentals · Certifié ✓"],
            counters: ["14 jours", "42 étapes", "1er (Or)", "65%"],
            buttonLabels: ["Voir mes Statistiques & Analyses Pro"],
            exactTexts: [
                "Mon Profil",
                "GC",
                "Gabriel Chambaud",
                "@gabriel  ·  Membre CertiGo PRO",
                "14 jours",
                "Série active",
                "42 étapes",
                "Chapitres validés",
                "1er (Or)",
                "Podium Semaine",
                "Voir mes Statistiques & Analyses Pro",
                "➔",
                "CERTIFICATIONS PROFESSIONNELLES",
                "Microsoft AZ-104",
                "Azure Administrator Associate · 12/18",
                "65%",
                "Microsoft AZ-900",
                "Azure Fundamentals · Certifié ✓"
            ],
            mascotPose: .emotionBossCrown,
            officialCrestRouteCodes: ["AZ-104", "AZ-900"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: []
        ),
        // 26 · 97:417
        CertiGoFigmaExactScreenContent(
            screenCode: "26",
            figmaScreenKey: "26",
            nodeId: "97:417",
            figmaFrameName: "26 · Détail Certification avec Vrai Blason Officiel Microsoft Associate",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .cloud,
            title: "Azure Administrator (AZ-104)",
            subtitle: "MICROSOFT CERTIFIED ASSOCIATE",
            badges: ["MICROSOFT CERTIFIED ASSOCIATE", "MAÎTRISE PAR DOMAINE OFFICIEL"],
            counters: ["65 % (12/18)", "760 / 1000 ✓", "85%", "72%", "64%", "45%"],
            buttonLabels: ["←  Moi", "🎓  Partager ma progression sur LinkedIn"],
            exactTexts: [
                "←  Moi",
                "Détail Certification",
                "MICROSOFT CERTIFIED ASSOCIATE",
                "Azure Administrator (AZ-104)",
                "PROGRESSION PARCOURS",
                "65 % (12/18)",
                "DERNIER EXAMEN BLANC",
                "760 / 1000 ✓",
                "MAÎTRISE PAR DOMAINE OFFICIEL",
                "1. Identité & Gouvernance Entra ID",
                "85%",
                "2. Stockage & Comptes Azure",
                "72%",
                "3. Calcul & Conteneurs (VMs / AKS)",
                "64%",
                "4. Réseaux Virtuels (VNet / DNS)",
                "45%",
                "🎓  Partager ma progression sur LinkedIn"
            ],
            mascotPose: .emotionStarryEyes,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: [
                "AzureServices/Network-Security-Groups",
                "AzureServices/Storage-Accounts",
                "AzureServices/Virtual-Machine",
                "AzureServices/Virtual-Networks"
            ]
        ),
        // 08B-1 · 97:498
        CertiGoFigmaExactScreenContent(
            screenCode: "08B-1",
            figmaScreenKey: "08B-1",
            nodeId: "97:498",
            figmaFrameName: "08B-1 · Statistiques Pro (Haut : Forme 84 %, Radar 5 Axes, Télémétrie & Heatmap)",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .cloud,
            title: "Statistiques Pro",
            subtitle: "Prêt pour l'examen AZ-104",
            badges: ["INDICE DE FORME EXAMEN", "RADAR DE COMPÉTENCES TECHNIQUES", "⚡ Top 4 % des candidats"],
            counters: ["84%", "88 %", "+6% vs sem. dernière", "14 sec"],
            buttonLabels: ["←  Moi", "30 jours ▾"],
            exactTexts: [
                "←  Moi",
                "Statistiques Pro",
                "30 jours ▾",
                "84%",
                "INDICE DE FORME EXAMEN",
                "Prêt pour l'examen AZ-104",
                "📈 +12 % cette semaine · Seuil officiel dépassé",
                "⚡ Top 4 % des candidats",
                "RADAR DE COMPÉTENCES TECHNIQUES",
                "Identité (92%)",
                "Stockage\n(84%)",
                "Calcul (78%)",
                "Réseau (58%)",
                "Sécurité\n(88%)",
                "88 %",
                "Précision globale",
                "+6% vs sem. dernière",
                "14 sec"
            ],
            mascotPose: .poseAnalyst,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: []
        ),
        // 08B-2 · 97:636
        CertiGoFigmaExactScreenContent(
            screenCode: "08B-2",
            figmaScreenKey: "08B-2",
            nodeId: "97:636",
            figmaFrameName: "08B-2 · Statistiques Pro (Bas en défilant : 3 Anneaux, Courbe /1000 & Forces/Faiblesses)",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .cloud,
            title: "PROGRESSION EXAMEN (/1000)",
            subtitle: "810 / 1000 · Seuil de réussite officiel (700)",
            badges: ["ANNEAUX DE PERFORMANCE", "DIAGNOSTIC DE TON COACH IA", "💪 POINTS FORTS", "🎯 À TRAVAILLER"],
            counters: ["810 / 1000"],
            buttonLabels: ["←  Moi", "30 jours ▾", "⚡ Cibler en 5 min", "Parcours"],
            exactTexts: [
                "←  Moi",
                "Statistiques Pro",
                "30 jours ▾",
                "ANNEAUX DE PERFORMANCE",
                "●  Régularité : 18 / 15 min/j",
                "●  Précision QCM : 88 % (Cible 80%)",
                "●  Labs & Oral IA : 6 / 5 séances",
                "PROGRESSION EXAMEN (/1000)",
                "810 / 1000",
                "Seuil de réussite officiel (700)",
                "Sem. 1 (540)          Sem. 2 (640)          Sem. 3 (730)          Sem. 4 (810)",
                "DIAGNOSTIC DE TON COACH IA",
                "💪 POINTS FORTS",
                "• Entra ID & RBAC\n  94 % de réussite\n\n• Azure Policy\n  91 % de réussite\n\n• Key Vault & KMS\n  89 % de réussite",
                "🎯 À TRAVAILLER",
                "• VNet Peering & BGP\n  54 % de réussite\n\n• App Gateway WAF\n  61 % de réussite",
                "⚡ Cibler en 5 min",
                "Parcours"
            ],
            mascotPose: .emotionDetermined,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups", "AzureServices/Policy", "AzureServices/Key-Vaults"]
        ),
        // OB-01 / OB_01 · 132:182
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-01",
            figmaScreenKey: "OB_01",
            nodeId: "132:182",
            figmaFrameName: "OB_01 · Étape 1 : Ouverture (Design 4 + Vrai Logo AWS + Multi-Parcours & Veille IA)",
            chapterKind: .onboardingPage07,
            region: .cloud,
            title: "Décroche tes certifications.\nMaîtrise l'IA & la Tech en continu.",
            subtitle: "Suis plusieurs parcours en parallèle : certifications officielles, acteurs majeurs de l'IA et nouveautés Tech ajoutées chaque semaine.",
            badges: ["Multi-Parcours", "Certifs + IA", "Nouveautés 🔄"],
            counters: [],
            buttonLabels: ["C'EST PARTI !", "J'AI DÉJÀ UN COMPTE"],
            exactTexts: [
                "CertiGo",
                "Décroche tes certifications.\nMaîtrise l'IA & la Tech en continu.",
                "Suis plusieurs parcours en parallèle : certifications officielles, acteurs majeurs de l'IA et nouveautés Tech ajoutées chaque semaine.",
                "Multi-Parcours",
                "En parallèle",
                "Certifs + IA",
                "Veille & Acteurs",
                "Nouveautés 🔄",
                "Chaque semaine",
                "C'EST PARTI !",
                "J'AI DÉJÀ UN COMPTE"
            ],
            mascotPose: .angleFrontCelebration,
            officialCrestRouteCodes: ["AZ-104", "SAA-C03", "GH-300"],
            brandVendorIds: ["google", "microsoft", "aws", "github"],
            serviceAssetNames: []
        ),
        // OB-02 / OB_02 · 132:264
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-02",
            figmaScreenKey: "OB_02",
            nodeId: "132:264",
            figmaFrameName: "OB_02 · Étape 2 : Objectifs (Certifications + Veille IA & Nouvelles Tech)",
            chapterKind: .onboardingPage07,
            region: .ai,
            title: "Qu'est-ce qui t'amène sur CertiGo ?",
            subtitle: "Tu peux combiner certifications officielles et veille sur les nouvelles avancées Tech & IA.",
            badges: ["CHOIX MULTIPLE POSSIBLE"],
            counters: ["1/7"],
            buttonLabels: ["←"],
            exactTexts: [
                "←",
                "1/7",
                "CHOIX MULTIPLE POSSIBLE",
                "Qu'est-ce qui t'amène sur CertiGo ?",
                "Tu peux combiner certifications officielles et veille sur les nouvelles avancées Tech & IA.",
                "🎓",
                "Décrocher 1 ou plusieurs certifications",
                "Microsoft, AWS, Google Cloud, GitHub ou Cisco",
                "✓",
                "✦",
                "Me tenir à jour sur l'IA & la Tech",
                "Maîtriser les acteurs de l'IA (OpenAI, Claude, Foundry…)",
                "✓",
                "🚀",
                "Accélérer ma carrière & mes projets",
                "Pratiquer sur des cas réels d'architecture & CLI",
                "🏢",
                "Valider des compétences en entreprise"
            ],
            mascotPose: .posePresenter,
            officialCrestRouteCodes: ["AZ-104", "SAA-C03"],
            brandVendorIds: ["microsoft", "aws", "gcp", "github", "cisco", "openai", "claude"],
            serviceAssetNames: []
        ),
        // OB-03A / OB_03A · 132:339
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-03A",
            figmaScreenKey: "OB_03A",
            nodeId: "132:339",
            figmaFrameName: "OB_03A · Étape 3A : Choisir Plusieurs Certifications en Parallèle (Vrai Logo AWS)",
            chapterKind: .onboardingPage07,
            region: .cloud,
            title: "Quelles certifications veux-tu  ?",
            subtitle: "🔀 MULTI-PARCOURS : SUIS PLUSIEURS CERTIFS EN PARALLÈLE",
            badges: ["PARCOURS 1 ACTIF", "PARCOURS 2 EN PARALLÈLE", "PARCOURS 3 EN PARALLÈLE", "DÉBUTANT · FUNDAMENTALS"],
            counters: ["2/7"],
            buttonLabels: ["←"],
            exactTexts: [
                "←",
                "2/7",
                "🔀 MULTI-PARCOURS : SUIS PLUSIEURS CERTIFS EN PARALLÈLE",
                "Quelles certifications veux-tu  ?",
                "Microsoft",
                "PARCOURS 1 ACTIF",
                "AZ-104 · Azure Administrator",
                "Microsoft · Réseaux VNet, Entra ID, Stockage & Calcul",
                "✓",
                "PARCOURS 2 EN PARALLÈLE",
                "SAA-C03 · Solutions Architect",
                "AWS · Architecture résiliente, VPC, S3 & IAM",
                "✓",
                "PARCOURS 3 EN PARALLÈLE",
                "GitHub Copilot & AI Dev",
                "GitHub · IA générative, Prompting & Sécurité du code",
                "✓",
                "DÉBUTANT · FUNDAMENTALS"
            ],
            mascotPose: .specialistCloudAzure,
            officialCrestRouteCodes: ["AZ-104", "SAA-C03", "GH-300"],
            brandVendorIds: ["microsoft", "aws", "github"],
            serviceAssetNames: ["AzureServices/Virtual-Networks", "AWSServices/Amazon-Virtual-Private-Cloud"]
        ),
        // OB-03B / OB_03B · 132:438
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-03B",
            figmaScreenKey: "OB_03B",
            nodeId: "132:438",
            figmaFrameName: "OB_03B · Étape 3B (Nouveau) : Cours sur les Acteurs de l'IA, Veille Tech & Catalogue Vivant",
            chapterKind: .onboardingPage07,
            region: .ai,
            title: "Reste à la pointe de l'IA\net des nouvelles Tech.",
            subtitle: "En parallèle de tes certifications, quels parcours d'actualité technologique et d'IA veux-tu suivre ?",
            badges: [
                "✦ BIEN PLUS QU'UNE APP DE CERTIFICATION : RADAR IA & TECH",
                "NOUVEAU · COURS DÉDIÉS",
                "AVANCÉES IA EN DIRECT",
                "MIS À JOUR CHAQUE SEMAINE"
            ],
            counters: ["3/7"],
            buttonLabels: ["←"],
            exactTexts: [
                "←",
                "3/7",
                "✦ BIEN PLUS QU'UNE APP DE CERTIFICATION : RADAR IA & TECH",
                "Reste à la pointe de l'IA\net des nouvelles Tech.",
                "En parallèle de tes certifications, quels parcours d'actualité technologique et d'IA veux-tu suivre ?",
                "🧠",
                "NOUVEAU · COURS DÉDIÉS",
                "Les Grands Acteurs & Modèles de l'IA",
                "OpenAI (GPT/o3), Anthropic Claude, Google Gemini, Mistral & Meta",
                "✓",
                "🤖",
                "AVANCÉES IA EN DIRECT",
                "Agents IA, MCP & Outils Développeur",
                "Microsoft Foundry, GitHub Copilot, Serveurs MCP, RAG & Orchestration",
                "✓",
                "⚡",
                "MIS À JOUR CHAQUE SEMAINE",
                "Radar Hebdo des Nouveautés Cloud"
            ],
            mascotPose: .specialistAICoach,
            officialCrestRouteCodes: ["AI-102", "GH-300", "CCA-F"],
            brandVendorIds: ["openai", "claude", "gemini", "mistral", "meta", "copilot"],
            serviceAssetNames: ["AzureServices/Cognitive-Services", "GCPServices/gcp-vertexai"]
        ),
        // OB-04 / OB_04 · 132:519
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-04",
            figmaScreenKey: "OB_04",
            nodeId: "132:519",
            figmaFrameName: "OB_04 · Étape 4 : Calibrage du Niveau & Échéance d'Examen (Validé)",
            chapterKind: .onboardingPage07,
            region: .cloud,
            title: "Quel est ton niveau actuel ?",
            subtitle: "CALIBRAGE SUR-MESURE",
            badges: ["CALIBRAGE SUR-MESURE", "QUAND VISES-TU TA 1re CERTIFICATION ?"],
            counters: ["4/7"],
            buttonLabels: ["←", "⚡ Dans 30 jours", "🎯 Dans 6 semaines"],
            exactTexts: [
                "←",
                "4/7",
                "CALIBRAGE SUR-MESURE",
                "Quel est ton niveau actuel ?",
                "▮▯▯",
                "Je débute sur le Cloud & l'IA",
                "On part des bases visuelles étape par étape.",
                "▮▮▯",
                "Intermédiaire (Recommandé)",
                "Je connais déjà les bases et je veux pratiquer.",
                "✓",
                "▮▮▮",
                "Avancé · Sprint & Examens",
                "Débloque directement les cas complexes et labs CLI.",
                "QUAND VISES-TU TA 1re CERTIFICATION ?",
                "⚡ Dans 30 jours",
                "Sprint intensif",
                "🎯 Dans 6 semaines"
            ],
            mascotPose: .poseAnalyst,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "aws"],
            serviceAssetNames: []
        ),
        // OB-06A / OB_06A · 132:581
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-06A",
            figmaScreenKey: "OB_06A",
            nodeId: "132:581",
            figmaFrameName: "OB_06A · Étape 5A : Choix du Rythme & Heure du Rappel (Avant Pop-up iOS)",
            chapterKind: .onboardingPage07,
            region: .cloud,
            title: "Fixe ton rythme quotidien",
            subtitle: "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.",
            badges: ["HABITUDE & RÉGULARITÉ", "🔔  RAPPEL INTELLIGENT QUOTIDIEN"],
            counters: ["5/7", "19:30", "19 : 30"],
            buttonLabels: ["←", "5 min / jour", "10 min / jour", "20 min / jour"],
            exactTexts: [
                "←",
                "5/7",
                "HABITUDE & RÉGULARITÉ",
                "Fixe ton rythme quotidien",
                "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.",
                "5 min / jour",
                "Régulier · 1 étape / jour",
                "10 min / jour",
                "Recommandé · Progression ×3",
                "20 min / jour",
                "Intensif · Sprint rapide",
                "🔔  RAPPEL INTELLIGENT QUOTIDIEN",
                "On te prévient au meilleur moment pour garder ta série active et découvrir les nouveautés IA.",
                "CertiGo · Rappel & Radar IA 🔥",
                "19:30",
                "Ton défi AZ-104 (5 min) et le nouveau cours sur Claude & Foundry sont prêts !",
                "Heure du rappel quotidien",
                "19 : 30"
            ],
            mascotPose: .emotionOnFire,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure", "claude"],
            serviceAssetNames: []
        ),
        // OB-06B / OB_06B · 132:651
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-06B",
            figmaScreenKey: "OB_06B",
            nodeId: "132:651",
            figmaFrameName: "OB_06B · Pop-up Système Natif iOS 1 : Autorisation des Notifications Push",
            chapterKind: .onboardingPage07,
            region: .cloud,
            title: "Fixe ton rythme quotidien",
            subtitle: "Pop-up Système Natif iOS 1 : Autorisation des Notifications Push",
            badges: ["HABITUDE & RÉGULARITÉ", "🔔  RAPPEL INTELLIGENT QUOTIDIEN"],
            counters: ["5/7", "19:30", "19 : 30"],
            buttonLabels: ["←", "5 min / jour", "10 min / jour", "20 min / jour"],
            exactTexts: [
                "←",
                "5/7",
                "HABITUDE & RÉGULARITÉ",
                "Fixe ton rythme quotidien",
                "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.",
                "5 min / jour",
                "Régulier · 1 étape / jour",
                "10 min / jour",
                "Recommandé · Progression ×3",
                "20 min / jour",
                "Intensif · Sprint rapide",
                "🔔  RAPPEL INTELLIGENT QUOTIDIEN",
                "On te prévient au meilleur moment pour garder ta série active et découvrir les nouveautés IA.",
                "CertiGo · Rappel & Radar IA 🔥",
                "19:30",
                "Ton défi AZ-104 (5 min) et le nouveau cours sur Claude & Foundry sont prêts !",
                "Heure du rappel quotidien",
                "19 : 30"
            ],
            mascotPose: .emotionStarryEyes,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure", "claude"],
            serviceAssetNames: []
        ),
        // OB-06C / OB_06C · 132:759
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-06C",
            figmaScreenKey: "OB_06C",
            nodeId: "132:759",
            figmaFrameName: "OB_06C · Pop-up Système iOS 2 : Ajouter le Widget Série & IA sur l'Écran d'Accueil (Style Duolingo)",
            chapterKind: .onboardingPage07,
            region: .cloud,
            title: "Fixe ton rythme quotidien",
            subtitle: "Pop-up Système iOS 2 : Ajouter le Widget Série & IA sur l'Écran d'Accueil",
            badges: ["HABITUDE & RÉGULARITÉ", "🔔  RAPPEL INTELLIGENT QUOTIDIEN"],
            counters: ["5/7", "19:30", "19 : 30"],
            buttonLabels: ["←", "5 min / jour", "10 min / jour", "20 min / jour"],
            exactTexts: [
                "←",
                "5/7",
                "HABITUDE & RÉGULARITÉ",
                "Fixe ton rythme quotidien",
                "5 à 10 minutes par jour suffisent pour avancer sur tes certifs et suivre les nouveautés IA.",
                "5 min / jour",
                "Régulier · 1 étape / jour",
                "10 min / jour",
                "Recommandé · Progression ×3",
                "20 min / jour",
                "Intensif · Sprint rapide",
                "🔔  RAPPEL INTELLIGENT QUOTIDIEN",
                "On te prévient au meilleur moment pour garder ta série active et découvrir les nouveautés IA.",
                "CertiGo · Rappel & Radar IA 🔥",
                "19:30",
                "Ton défi AZ-104 (5 min) et le nouveau cours sur Claude & Foundry sont prêts !",
                "Heure du rappel quotidien",
                "19 : 30"
            ],
            mascotPose: .emotionOnFire,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure", "claude"],
            serviceAssetNames: []
        ),
        // OB-07 / OB_07 · 132:877
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-07",
            figmaScreenKey: "OB_07",
            nodeId: "132:877",
            figmaFrameName: "OB_07 · Étape 6 : Plan Épuré & Graphique Comparatif (Avec CertiGo vs Sans CertiGo)",
            chapterKind: .onboardingPage07,
            region: .cloud,
            title: "3,4× plus rapide\navec la méthode CertiGo.",
            subtitle: "Prêt pour l'examen dès le 18 Juin · Veille IA en continu",
            badges: ["✓ TON PLAN MULTI-PARCOURS EST PRÊT", "✦ Avec CertiGo (810+)", "Sans CertiGo (Seul / PDF)"],
            counters: ["6/7", "18 Juin 🎯"],
            buttonLabels: ["←", "SAUVEGARDER MON PLAN  →"],
            exactTexts: [
                "←",
                "6/7",
                "✓ TON PLAN MULTI-PARCOURS EST PRÊT",
                "3,4× plus rapide\navec la méthode CertiGo.",
                "Prêt pour l'examen dès le 18 Juin · Veille IA en continu",
                "MAÎTRISE DES CERTIFICATIONS & DE L'IA",
                "✦ Avec CertiGo (810+)",
                "Sans CertiGo (Seul / PDF)",
                "Aujourd'hui",
                "Semaine 3",
                "18 Juin 🎯",
                "Parcours actifs : AZ-104 · AWS · Acteurs IA 🔄",
                "🔄 Nouveaux chapitres, examens blancs et cours sur les derniers modèles IA débloqués chaque semaine.",
                "SAUVEGARDER MON PLAN  →"
            ],
            mascotPose: .emotionDetermined,
            officialCrestRouteCodes: ["AZ-104", "SAA-C03"],
            brandVendorIds: ["microsoft", "aws", "openai", "claude"],
            serviceAssetNames: []
        ),
        // OB-08A / OB_08A · 132:945
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-08A",
            figmaScreenKey: "OB_08A",
            nodeId: "132:945",
            figmaFrameName: "OB_08A · Étape 7A : Création du Profil en 1 Tap (Épuré sans bandeau en haut)",
            chapterKind: .onboardingPage07,
            region: .security,
            title: "Crée ton profil pour\nsauvegarder tes parcours",
            subtitle: "Synchronise tes certifications en parallèle, ta série 🔥 et ton radar IA sur tous tes appareils.",
            badges: [],
            counters: ["7/7"],
            buttonLabels: [
                "←",
                "   Continuer avec Apple",
                "Continuer avec Microsoft",
                "Continuer avec Google",
                "✉️   Continuer avec mon adresse e-mail",
                "Explorer ma 1re leçon sans créer de compte  →"
            ],
            exactTexts: [
                "←",
                "7/7",
                "Crée ton profil pour\nsauvegarder tes parcours",
                "Synchronise tes certifications en parallèle, ta série 🔥 et ton radar IA sur tous tes appareils.",
                "   Continuer avec Apple",
                "Continuer avec Microsoft",
                "Continuer avec Google",
                "✉️   Continuer avec mon adresse e-mail",
                "Explorer ma 1re leçon sans créer de compte  →",
                "En continuant, tu acceptes les Conditions d'utilisation et la Politique de confidentialité de CertiGo."
            ],
            mascotPose: .poseVictoryJump,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "google"],
            serviceAssetNames: []
        ),
        // OB-08B / OB_08B · 132:1009
        CertiGoFigmaExactScreenContent(
            screenCode: "OB-08B",
            figmaScreenKey: "OB_08B",
            nodeId: "132:1009",
            figmaFrameName: "OB_08B · Pop-up Système Natif iOS 3 : Feuille « Connexion avec Apple (Face ID) »",
            chapterKind: .onboardingPage07,
            region: .security,
            title: "Connexion avec l'identifiant Apple",
            subtitle: "Créez un compte pour CertiGo à l'aide de votre identifiant Apple.",
            badges: ["Masquer mon adresse e-mail", "✓"],
            counters: ["7/7"],
            buttonLabels: ["←", "✕", "Continuer"],
            exactTexts: [
                "←",
                "7/7",
                "Crée ton profil pour\nsauvegarder tes parcours",
                "Synchronise tes certifications en parallèle, ta série 🔥 et ton radar IA sur tous tes appareils.",
                "   Continuer avec Apple",
                "Continuer avec Microsoft",
                "Continuer avec Google",
                "✉️   Continuer avec mon adresse e-mail",
                "Explorer ma 1re leçon sans créer de compte  →",
                "En continuant, tu acceptes les Conditions d'utilisation et la Politique de confidentialité de CertiGo.",
                "Connexion avec l'identifiant Apple",
                "✕",
                "Créez un compte pour CertiGo à l'aide de votre identifiant Apple.",
                "Nom",
                "Gabriel Chambaud",
                "Masquer mon adresse e-mail",
                "✓",
                "Continuer"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "google"],
            serviceAssetNames: []
        ),
        // 21 · 142:385
        CertiGoFigmaExactScreenContent(
            screenCode: "21",
            figmaScreenKey: "21",
            nodeId: "142:385",
            figmaFrameName: "21 · Onglet Examens (Variante C Centrée & Épurée)",
            chapterKind: .pearsonVueExamSimulationPage09,
            region: .cloud,
            title: "Examens · AZ-104",
            subtitle: "Examen Blanc Complet (50 Q) · 90 min · Seuil 700/1000 · Dernier : 785 ✓",
            badges: ["AZ-104 ▾", "CONDITIONS PEARSON VUE", "S'ENTRAÎNER PAR DOMAINE OFFICIEL AZ-104"],
            counters: ["88 %", "82 %"],
            buttonLabels: ["DÉMARRER L'EXAMEN COMPLET", "Parcours", "Examens", "Social", "Moi"],
            exactTexts: [
                "Parcours",
                "Examens",
                "Social",
                "Moi",
                "Examens · AZ-104",
                "AZ-104 ▾",
                "CONDITIONS PEARSON VUE",
                "Examen Blanc Complet (50 Q)",
                "90 min · Seuil 700/1000 · Dernier : 785 ✓",
                "DÉMARRER L'EXAMEN COMPLET",
                "S'ENTRAÎNER PAR DOMAINE OFFICIEL AZ-104",
                "1. Identité & Gouvernance Entra ID",
                "Poids officiel : 20–25 %",
                "88 %",
                "2. Stockage & Sécurité des données",
                "Poids officiel : 15–20 %",
                "82 %",
                "3. Déploiement Calcul, VM & AKS"
            ],
            mascotPose: .poseCrossedArms,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups", "AzureServices/Storage-Accounts", "AzureServices/Virtual-Machine"]
        ),
        // 23 · 142:478
        CertiGoFigmaExactScreenContent(
            screenCode: "23",
            figmaScreenKey: "23",
            nodeId: "142:478",
            figmaFrameName: "23 · Examen Blanc Chronométré en Cours (Cockpit Centré)",
            chapterKind: .pearsonVueExamSimulationPage09,
            region: .security,
            title: "50 VMs dans VNet-Spoke doivent lire les secrets d'un coffre Azure Key Vault sans exposition Internet et avec contrôle RBAC unifié.\nQuelle architecture déployez-vous ?",
            subtitle: "ÉTUDE DE CAS CONTOSO · SÉCURITÉ",
            badges: ["ÉTUDE DE CAS CONTOSO · SÉCURITÉ", "🏳 Marquer"],
            counters: ["⏱  42 : 18", "12 ✓", "13 🏳", "14 / 50", "15", "16", "17"],
            buttonLabels: ["✕", "🏳 Marquer", "A", "B", "C", "D"],
            exactTexts: [
                "✕",
                "⏱  42 : 18",
                "🏳 Marquer",
                "12 ✓",
                "13 🏳",
                "14 / 50",
                "15",
                "16",
                "17",
                "ÉTUDE DE CAS CONTOSO · SÉCURITÉ",
                "50 VMs dans VNet-Spoke doivent lire les secrets d'un coffre Azure Key Vault sans exposition Internet et avec contrôle RBAC unifié.\nQuelle architecture déployez-vous ?",
                "A",
                "Service Endpoint + Stratégie d'accès Key Vault classique sur le sous-réseau",
                "B",
                "Private Endpoint + Zone DNS privatelink + Rôle RBAC Key Vault Secrets User",
                "C",
                "Azure NAT Gateway + Pare-feu public Key Vault limité à l'IP sortante",
                "D"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure"],
            serviceAssetNames: ["AzureServices/Key-Vaults", "AzureServices/Private-Link", "AzureServices/DNS-Zones"]
        ),
        // 24 · 142:540
        CertiGoFigmaExactScreenContent(
            screenCode: "24",
            figmaScreenKey: "24",
            nodeId: "142:540",
            figmaFrameName: "24 · Rapport Examen Blanc & Score /1000 (Carrousel Haut ●○○ + Bas Épuré)",
            chapterKind: .pearsonVueExamSimulationPage09,
            region: .cloud,
            title: "785 / 1000",
            subtitle: "✓ EXAMEN RÉUSSI · +85 PTS AU-DESSUS DU SEUIL",
            badges: ["✓ EXAMEN RÉUSSI · +85 PTS AU-DESSUS DU SEUIL", "ÉCHELLE OFFICIELLE PEARSON VUE (SEUIL : 700)"],
            counters: ["785", "/ 1000", "✓ 39 Exactes", "✕ 11 Erreurs", "⏱ 38 min", "88 %"],
            buttonLabels: ["›"],
            exactTexts: [
                "✓ EXAMEN RÉUSSI · +85 PTS AU-DESSUS DU SEUIL",
                "785",
                "/ 1000",
                "📈 +70 pts vs Essai #2",
                "ÉCHELLE OFFICIELLE PEARSON VUE (SEUIL : 700)",
                "Seuil 700",
                "0",
                "1000",
                "›",
                "✓ 39 Exactes",
                "78 % réussite",
                "✕ 11 Erreurs",
                "3 marquées 🏳",
                "⏱ 38 min",
                "45 sec / Q",
                "SCORE PAR DOMAINE OFFICIEL AZ-104",
                "Identité & Gouvernance Entra ID",
                "88 %"
            ],
            mascotPose: .emotionBossCrown,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "azure"],
            serviceAssetNames: ["AzureServices/Network-Security-Groups"]
        ),
        // 27 · 144:137
        CertiGoFigmaExactScreenContent(
            screenCode: "27",
            figmaScreenKey: "27",
            nodeId: "144:137",
            figmaFrameName: "27 · CertiGo PRO (Variante 27-A Validée : Tableau Comparatif Gratuit vs PRO + Tarifs)",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .ai,
            title: "Réussis tes certifications\n2,8× plus vite.",
            subtitle: "✦  CERTIGO PRO",
            badges: ["✦  CERTIGO PRO", "AVANTAGES INCLUS", "GRATUIT", "PRO ✦"],
            counters: ["5 ❤️", "∞ Illimité", "✦ 24/7 Max"],
            buttonLabels: ["✕"],
            exactTexts: [
                "✕",
                "✦  CERTIGO PRO",
                "Réussis tes certifications\n2,8× plus vite.",
                "AVANTAGES INCLUS",
                "GRATUIT",
                "PRO ✦",
                "Parcours Multi-Certifs & Veille IA",
                "✓",
                "✓ Illimité",
                "Vies & Énergie quotidienne",
                "5 ❤️",
                "∞ Illimité",
                "Coach IA Vocal Live & Explications",
                "Limité",
                "✦ 24/7 Max",
                "Examens Blancs Pearson VUE (/1000)",
                "1 essai",
                "✓ Illimités"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104", "SAA-C03", "GH-300"],
            brandVendorIds: ["microsoft", "aws", "gcp", "github"],
            serviceAssetNames: []
        ),
        // 28 · 145:122
        CertiGoFigmaExactScreenContent(
            screenCode: "28",
            figmaScreenKey: "28",
            nodeId: "145:122",
            figmaFrameName: "28 · Paramètres Complets (Style 1 ChatGPT iOS 2026 Validé : Icônes Vectorielles Fines)",
            chapterKind: .socialProfileProStatsAndSettings,
            region: .cloud,
            title: "Paramètres",
            subtitle: "gabriel@certigo" + ".app · CertiGo PRO Actif",
            badges: ["Parcours & Examens", "Coach IA Vocal & Écrit"],
            counters: ["AZ-104 + 2  ›", "FR + Termes EN  ›", "Chrono 90m  ›", "142 Mo  ›", "Nova (1,0×)  ›"],
            buttonLabels: ["✕", "›"],
            exactTexts: [
                "Paramètres",
                "✕",
                "GC",
                "Gabriel Chambaud",
                "gabriel@certigo" + ".app · CertiGo PRO Actif",
                "›",
                "Parcours & Examens",
                "Parcours actifs en parallèle",
                "AZ-104 + 2  ›",
                "Langue des cours & examens",
                "FR + Termes EN  ›",
                "Mode Examen Blanc (Pearson)",
                "Chrono 90m  ›",
                "Cours téléchargés (Hors-Ligne)",
                "142 Mo  ›",
                "Coach IA Vocal & Écrit",
                "Voix du Coach IA Live",
                "Nova (1,0×)  ›"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["microsoft", "aws", "github"],
            serviceAssetNames: []
        )
    ]

    /// The 4 additional validated screens on Pages 11 and 12 (`SYS-01`, `SYS-02`, `RES-01`, `RES-02`).
    public static let systemAndResilienceScreens: [CertiGoFigmaExactScreenContent] = [
        CertiGoFigmaExactScreenContent(
            screenCode: "SYS-01",
            figmaScreenKey: "SYS-01",
            nodeId: "161:93",
            figmaFrameName: "SYS-01 · Widgets Écran d'Accueil iOS 18 (W-1, W-Radar, W-2 & W-3 Interactif NS-14)",
            isPage01GroundTruthScreen: false,
            chapterKind: .ios18SystemSurfacesPage11,
            region: .ai,
            title: "Widgets Écran d'Accueil iOS 18",
            subtitle: "W-1 Série 🔥 12j · W-Radar Claude 4 & Agents MCP · W-2 Situation +25 XP · W-3 Carte Interactive A/B/C",
            badges: ["W-1", "W-Radar", "W-2", "W-3"],
            counters: ["🔥 12j", "10/10 min ✓", "AZ-104 + 2", "+25 XP"],
            buttonLabels: ["A", "B", "C"],
            exactTexts: [
                "SYS-01",
                "W-1",
                "🔥 12j",
                "10/10 min ✓",
                "AZ-104 + 2",
                "W-Radar",
                "Nouveau cours IA : Claude 4 & Agents MCP",
                "W-2",
                "Protection d'un coffre Key Vault critique · +25 XP",
                "W-3",
                "A",
                "B",
                "C"
            ],
            mascotPose: .emotionOnFire,
            officialCrestRouteCodes: [],
            brandVendorIds: [],
            serviceAssetNames: []
        ),
        CertiGoFigmaExactScreenContent(
            screenCode: "SYS-02",
            figmaScreenKey: "SYS-02",
            nodeId: "161:134",
            figmaFrameName: "SYS-02 · Dynamic Island, Live Activities (LA-1..LA-3) & Control Center (CC-1)",
            isPage01GroundTruthScreen: false,
            chapterKind: .ios18SystemSurfacesPage11,
            region: .cloud,
            title: "Dynamic Island, Live Activities & Control Center",
            subtitle: "LA-1 Examen Blanc · LA-2 Plongée · LA-3 Compagnon Jour J · CC-1 Express 5 min",
            badges: ["LA-1", "LA-2", "LA-3", "CC-1"],
            counters: ["⏱️ 64:18", "Question 14/50", "Seuil 700/1000", "4/6 étapes"],
            buttonLabels: ["Express 5 min"],
            exactTexts: [
                "SYS-02",
                "LA-1",
                "⏱️ 64:18 · Question 14/50 · Seuil 700/1000",
                "LA-2",
                "4/6 étapes · Série protégée",
                "LA-3",
                "3 Fiches Mémo Clés · Zéro nouvelle question anxiogène",
                "CC-1",
                "Express 5 min"
            ],
            mascotPose: nil,
            officialCrestRouteCodes: [],
            brandVendorIds: [],
            serviceAssetNames: []
        ),
        CertiGoFigmaExactScreenContent(
            screenCode: "RES-01",
            figmaScreenKey: "RES-01",
            nodeId: "162:93",
            figmaFrameName: "RES-01 · Mode Hors-Ligne Train / Avion (Packs 142 Mo & File DR-004)",
            isPage01GroundTruthScreen: false,
            chapterKind: .offlineAndZeroGuiltResiliencePage12,
            region: .cloud,
            title: "Continuité Hors-Ligne Multi-Parcours",
            subtitle: "Mode Train / Avion · 142 Mo (AZ-104 68 Mo + AWS SAA-C03 52 Mo + Veille IA 22 Mo)",
            badges: ["RES-01", "Mode Train / Avion · 142 Mo", "0 clé de réponse locale (DR-004)"],
            counters: ["142 Mo", "68 Mo", "52 Mo", "22 Mo", "2/2 séances"],
            buttonLabels: ["Synchroniser à la reconnexion (idempotent)"],
            exactTexts: [
                "RES-01",
                "Mode Train / Avion · 142 Mo",
                "Continuité Hors-Ligne Multi-Parcours",
                "AZ-104 · Microsoft Azure Administrator",
                "68 Mo",
                "SAA-C03 · AWS Solutions Architect Associate",
                "52 Mo",
                "Veille IA Claude 4 / GPT / Foundry",
                "22 Mo",
                "0 clé de réponse locale (DR-004)",
                "Synchroniser à la reconnexion (idempotent)"
            ],
            mascotPose: .poseReaderMemo,
            officialCrestRouteCodes: ["AZ-104", "SAA-C03"],
            brandVendorIds: ["azure", "aws", "claude"],
            serviceAssetNames: ["AzureServices/Virtual-Networks", "AWSServices/Amazon-Virtual-Private-Cloud"]
        ),
        CertiGoFigmaExactScreenContent(
            screenCode: "RES-02",
            figmaScreenKey: "RES-02",
            nodeId: "162:120",
            figmaFrameName: "RES-02 · Reprise Bienveillante Zéro Culpabilité (Séance Express 5 min)",
            isPage01GroundTruthScreen: false,
            chapterKind: .offlineAndZeroGuiltResiliencePage12,
            region: .cloud,
            title: "Ravi de te revoir, Gabriel !",
            subtitle: "Reprise Bienveillante Zéro Culpabilité · Aucune pénalité sur tes acquis",
            badges: ["RES-02", "ZÉRO CULPABILITÉ"],
            counters: ["5 min"],
            buttonLabels: ["Reprendre en douceur (5 min)"],
            exactTexts: [
                "RES-02",
                "ZÉRO CULPABILITÉ",
                "Ravi de te revoir, Gabriel !",
                "Tes acquis AZ-104, AWS et IA sont intacts. Reprends à ton rythme avec une séance Express de 5 minutes sans aucune pénalité.",
                "Reprendre en douceur (5 min)"
            ],
            mascotPose: .emotionOopsCaring,
            officialCrestRouteCodes: ["AZ-104"],
            brandVendorIds: ["azure", "aws"],
            serviceAssetNames: []
        )
    ]

    public static var allScreens: [CertiGoFigmaExactScreenContent] {
        page01Screens + systemAndResilienceScreens
    }

    public static func canonicalScreenCode(for rawScreenId: String) -> String {
        let trimmed = rawScreenId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed == "06" { return "06A" }
        if trimmed == "07" { return "07A" }
        if trimmed.hasPrefix("OB_") {
            return "OB-" + String(trimmed.dropFirst(3))
        }
        if trimmed.hasPrefix("SYS_") {
            return "SYS-" + String(trimmed.dropFirst(4))
        }
        if trimmed.hasPrefix("RES_") {
            return "RES-" + String(trimmed.dropFirst(4))
        }
        return trimmed
    }

    public static func content(forScreenId screenId: String) -> CertiGoFigmaExactScreenContent? {
        let trimmed = screenId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let byNode = allScreens.first(where: { $0.nodeId == trimmed }) {
            return byNode
        }
        let canonical = canonicalScreenCode(for: trimmed)
        let upper = trimmed.uppercased()
        return allScreens.first {
            $0.screenCode.uppercased() == canonical
                || $0.figmaScreenKey.uppercased() == upper
                || $0.figmaScreenKey.uppercased() == canonical
        }
    }

    public static func content(forNodeId nodeId: String) -> CertiGoFigmaExactScreenContent? {
        let trimmed = nodeId.trimmingCharacters(in: .whitespacesAndNewlines)
        return allScreens.first { $0.nodeId == trimmed }
    }

    public static func verifyAllGroundTruthScreens() -> Bool {
        guard page01Screens.count == expectedPage01ScreenCount else { return false }
        guard systemAndResilienceScreens.count == expectedSystemAndResilienceScreenCount else { return false }
        guard allScreens.count == expectedTotalScreenCount else { return false }
        guard Set(allScreens.map(\.nodeId)).count == expectedTotalScreenCount else { return false }
        guard Set(allScreens.map(\.screenCode)).count == expectedTotalScreenCount else { return false }
        return allScreens.allSatisfy { screen in
            !screen.nodeId.isEmpty
                && !screen.figmaFrameName.isEmpty
                && !screen.exactTexts.isEmpty
                && !screen.title.isEmpty
        }
    }
}

extension CertiGoMasterFigmaScreenDescriptor {
    public var exactFigmaContent: CertiGoFigmaExactScreenContent? {
        CertiGoFigmaExactScreenParity.content(forNodeId: nodeId)
            ?? CertiGoFigmaExactScreenParity.content(forScreenId: screenCode)
    }
}

// MARK: - 3. SwiftUI 1-for-1 Figma Pro Screen View (CertiGoFigmaExactScreenView)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct CertiGoFigmaExactScreenView: View {
    public let screenId: String
    public let content: CertiGoFigmaExactScreenContent

    public init(screenId: String) {
        self.screenId = screenId
        self.content = CertiGoFigmaExactScreenParity.content(forScreenId: screenId)
            ?? CertiGoFigmaExactScreenParity.page01Screens[0]
    }

    public init(content: CertiGoFigmaExactScreenContent) {
        self.screenId = content.screenCode
        self.content = content
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PrismSpacing.m) {
                headerIdentityBanner
                visualAssetsStrip
                badgesAndCountersRow
                primaryHeroSection
                exactFigmaTextLinesSection
                actionButtonsFooter
            }
            .padding(PrismSpacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PrismColor.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("figma-exact-screen-\(content.screenCode)")
    }

    @ViewBuilder
    private var headerIdentityBanner: some View {
        PrismCard(variant: .standard) {
            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                HStack(spacing: PrismSpacing.s) {
                    PrismBadge(
                        configuration: PrismBadgeConfiguration(
                            text: content.figmaScreenKey,
                            semantics: .accent
                        )
                    )
                    PrismBadge(
                        configuration: PrismBadgeConfiguration(
                            text: content.nodeId,
                            semantics: .region(content.region)
                        )
                    )
                    Spacer(minLength: PrismSpacing.xs)
                }
                PrismText(text: content.figmaFrameName, style: .footnote, role: .textSecondary)
            }
        }
    }

    @ViewBuilder
    private var visualAssetsStrip: some View {
        if content.mascotPose != nil
            || !content.officialCrestRouteCodes.isEmpty
            || !content.brandVendorIds.isEmpty
            || !content.serviceAssetNames.isEmpty
        {
            PrismCard(variant: .standard) {
                VStack(alignment: .leading, spacing: PrismSpacing.s) {
                    if let pose = content.mascotPose {
                        if pose.isRight34QuizPose {
                            CertiGoSpeechBubbleHeaderView(
                                region: content.region,
                                badgeText: content.badges.first ?? content.figmaScreenKey,
                                questionText: content.title,
                                poseOverride: pose
                            )
                        } else {
                            HStack(spacing: PrismSpacing.m) {
                                CertiGoMascotView(pose: pose, size: PrismSize.mascotQuiz)
                                VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                    PrismText(text: content.title, style: .headline)
                                    if let subtitle = content.subtitle {
                                        PrismText(text: subtitle, style: .footnote, role: .textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    if !content.officialCrestRouteCodes.isEmpty || !content.brandVendorIds.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: PrismSpacing.m) {
                                ForEach(content.officialCrestRouteCodes, id: \.self) { routeCode in
                                    CertiGoOfficialCrestView(routeCode: routeCode, size: PrismSize.crestCard)
                                }
                                ForEach(content.brandVendorIds, id: \.self) { vendorId in
                                    CertiGoBrandLogoView(vendorId: vendorId, size: PrismSize.brandM)
                                }
                            }
                        }
                    }

                    if !content.serviceAssetNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: PrismSpacing.m) {
                                ForEach(content.serviceAssetNames, id: \.self) { serviceAsset in
                                    Image(serviceAsset, bundle: .module)
                                        .renderingMode(.original)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: PrismSize.brandM, height: PrismSize.brandM)
                                        .accessibilityLabel(Text(verbatim: serviceAsset))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var badgesAndCountersRow: some View {
        if !content.badges.isEmpty || !content.counters.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.xs) {
                    ForEach(Array(content.badges.enumerated()), id: \.offset) { _, badge in
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: badge,
                                semantics: .region(content.region)
                            )
                        )
                    }
                    ForEach(Array(content.counters.enumerated()), id: \.offset) { _, counter in
                        PrismBadge(
                            configuration: PrismBadgeConfiguration(
                                text: counter,
                                semantics: .positive
                            )
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var primaryHeroSection: some View {
        PrismCard(variant: .hero) {
            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                PrismText(text: content.title, style: .title3)
                if let subtitle = content.subtitle {
                    PrismText(text: subtitle, style: .subheadline, role: .textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var exactFigmaTextLinesSection: some View {
        PrismSection(title: "Textes Exacts Figma Pro (\(content.exactTexts.count))") {
            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                ForEach(Array(content.exactTexts.enumerated()), id: \.offset) { index, line in
                    PrismCard(variant: .standard) {
                        HStack(alignment: .top, spacing: PrismSpacing.s) {
                            PrismBadge(
                                configuration: PrismBadgeConfiguration(
                                    text: "#\(index + 1)",
                                    semantics: .neutral
                                )
                            )
                            Text(verbatim: line)
                                .prismTextStyle(line.contains("az ") || line.contains("\"Actions\"") ? .codeSmall : .subheadline)
                                .foregroundStyle(PrismColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: PrismSpacing.xxs)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtonsFooter: some View {
        if !content.buttonLabels.isEmpty {
            VStack(alignment: .leading, spacing: PrismSpacing.xs) {
                ForEach(Array(content.buttonLabels.enumerated()), id: \.offset) { index, label in
                    Button {} label: {
                        Text(verbatim: label)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrismButtonStyle(variant: index == 0 ? .primary : .secondary))
                }
            }
        }
    }
}
#endif
