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

// MARK: - 3. Exact Recursive 53-Screen Scene-Graph Model & Store (`figma-scene-graph-53-screens.json`)

public struct CertiGoFigmaSceneNode: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let i: String
    public let n: String
    public let t: String
    public let x: Double
    public let y: Double
    public let w: Double
    public let h: Double
    public let f: String?
    public let s: String?
    public let sh: String?
    public let r: Double?
    public let cl: Int?
    public let op: Double?
    public let rot: Double?
    public let d: String?
    public let tx: String?
    public let fs: Double?
    public let fw: String?
    public let mo: Int?
    public let al: String?
    public let va: String?
    public let vp: String?
    public let eo: Int?
    public let c: [CertiGoFigmaSceneNode]?

    public var id: String { i }

    public init(
        i: String,
        n: String,
        t: String,
        x: Double,
        y: Double,
        w: Double,
        h: Double,
        f: String? = nil,
        s: String? = nil,
        sh: String? = nil,
        r: Double? = nil,
        cl: Int? = nil,
        op: Double? = nil,
        rot: Double? = nil,
        d: String? = nil,
        tx: String? = nil,
        fs: Double? = nil,
        fw: String? = nil,
        mo: Int? = nil,
        al: String? = nil,
        va: String? = nil,
        vp: String? = nil,
        eo: Int? = nil,
        c: [CertiGoFigmaSceneNode]? = nil
    ) {
        self.i = i
        self.n = n
        self.t = t
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.f = f
        self.s = s
        self.sh = sh
        self.r = r
        self.cl = cl
        self.op = op
        self.rot = rot
        self.d = d
        self.tx = tx
        self.fs = fs
        self.fw = fw
        self.mo = mo
        self.al = al
        self.va = va
        self.vp = vp
        self.eo = eo
        self.c = c
    }

    public var totalDescendantAndSelfCount: Int {
        1 + (c ?? []).reduce(0) { $0 + $1.totalDescendantAndSelfCount }
    }

    public var allNodes: [CertiGoFigmaSceneNode] {
        [self] + (c ?? []).flatMap(\.allNodes)
    }

    public var vectorNodes: [CertiGoFigmaSceneNode] {
        allNodes.filter { $0.t == "V" }
    }

    public var hotspotNodes: [CertiGoFigmaSceneNode] {
        allNodes.filter { $0.d != nil }
    }

    public var resolvedImageAssetName: String? {
        guard let fill = f, fill.hasPrefix("img:") else { return nil }
        switch fill {
        case "img:b013ad43b2d3595a186095aadef93d171712e4d6":
            return "BrandLogos/brand-aws-official"
        case "img:e3041bf6f6e2b3d0b97ee7a5aba3518aefc60108":
            return "Certifications/tech-aws-solutions-architect"
        case "img:7149e104bfe0be393cbd68e92a1dba4c1f0f7936":
            return "Certifications/tech-github-copilot"
        default:
            return nil
        }
    }

    public func isFilteredMockupChrome(parentWidth: Double, parentHeight: Double) -> Bool {
        if n == "Status Bar - iPhone" || n == "Home Indicator" {
            return true
        }
        let isRootScreenFrame = abs(parentWidth - 393.0) < 0.5 && abs(parentHeight - 852.0) < 0.5
        guard isRootScreenFrame else { return false }

        let statusBarTexts: Set<String> = ["9:41", "5G 100%", "5G  100%", "✈️  100%", "✈️ 100%"]
        if y < 36.0 && (statusBarTexts.contains(n) || statusBarTexts.contains(tx ?? "")) {
            return true
        }
        if abs(x - 136.0) < 0.5 && abs(y - 11.0) < 0.5 && abs(w - 120.0) < 0.5 && abs(h - 30.0) < 0.5 {
            return true
        }
        if y >= 820.0 && h <= 32.0 && (abs(w - 139.0) < 0.5 || abs(w - 144.0) < 0.5) {
            return true
        }
        return false
    }

    public static let linearFlowRootNodeIds: Set<String> = [
        "132:182", "132:264", "132:339", "132:438", "132:519",
        "132:581", "132:651", "132:759", "132:877", "132:945", "132:1009",
        "73:332", "26:807", "26:826", "26:863", "26:890", "26:912",
        "73:393", "73:442", "73:509", "73:575", "73:743",
        "73:818", "73:898", "73:958", "73:1019", "73:1070",
        "142:478", "142:540",
        "161:93", "161:134", "162:93", "162:120"
    ]

    public var shouldAttachRootTapGesture: Bool {
        guard d != nil else { return false }
        let visibleDescendants = (c ?? [])
            .filter { !$0.isFilteredMockupChrome(parentWidth: w, parentHeight: h) }
            .flatMap(\.allNodes)
        if !visibleDescendants.contains(where: { $0.d != nil }) {
            return true
        }
        return Self.linearFlowRootNodeIds.contains(i)
    }

    public func filteringDirectChildren(
        _ isIncluded: (CertiGoFigmaSceneNode) -> Bool
    ) -> CertiGoFigmaSceneNode {
        CertiGoFigmaSceneNode(
            i: i,
            n: n,
            t: t,
            x: x,
            y: y,
            w: w,
            h: h,
            f: f,
            s: s,
            sh: sh,
            r: r,
            cl: cl,
            op: op,
            rot: rot,
            d: d,
            tx: tx,
            fs: fs,
            fw: fw,
            mo: mo,
            al: al,
            va: va,
            vp: vp,
            eo: eo,
            c: (c ?? []).filter(isIncluded)
        )
    }

    public func updating(
        x: Double? = nil,
        y: Double? = nil,
        w: Double? = nil,
        h: Double? = nil,
        f: String?? = nil,
        s: String?? = nil,
        sh: String?? = nil,
        r: Double?? = nil,
        op: Double?? = nil,
        d: String?? = nil,
        tx: String?? = nil,
        c: [CertiGoFigmaSceneNode]?? = nil
    ) -> CertiGoFigmaSceneNode {
        CertiGoFigmaSceneNode(
            i: i,
            n: n,
            t: t,
            x: x ?? self.x,
            y: y ?? self.y,
            w: w ?? self.w,
            h: h ?? self.h,
            f: f ?? self.f,
            s: s ?? self.s,
            sh: sh ?? self.sh,
            r: r ?? self.r,
            cl: cl,
            op: op ?? self.op,
            rot: rot,
            d: d ?? self.d,
            tx: tx ?? self.tx,
            fs: fs,
            fw: fw,
            mo: mo,
            al: al,
            va: va,
            vp: vp,
            eo: eo,
            c: c ?? self.c
        )
    }

    public func mapAllNodes(
        _ transform: (CertiGoFigmaSceneNode) -> CertiGoFigmaSceneNode
    ) -> CertiGoFigmaSceneNode {
        let mappedChildren = c?.map { $0.mapAllNodes(transform) }
        return transform(updating(c: .some(mappedChildren)))
    }

    public func clearingDescendantDestinations() -> CertiGoFigmaSceneNode {
        guard let children = c else { return self }
        let cleared = children.map { child in
            child.mapAllNodes { node in
                node.d == nil ? node : node.updating(d: .some(nil))
            }
        }
        return updating(c: .some(cleared))
    }

    public func node(withId targetId: String) -> CertiGoFigmaSceneNode? {
        allNodes.first { $0.i == targetId }
    }
}

public enum CertiGoFigmaSVGCommand: Equatable, Hashable, Sendable {
    case moveTo(x: Double, y: Double)
    case lineTo(x: Double, y: Double)
    case curveTo(x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double)
    case closeSubpath

    public static func parse(_ vp: String) -> [CertiGoFigmaSVGCommand] {
        let tokens = vp.split { $0.isWhitespace || $0 == "," }
        guard !tokens.isEmpty else { return [] }
        var commands: [CertiGoFigmaSVGCommand] = []
        commands.reserveCapacity(tokens.count / 3 + 1)
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            switch token {
            case "M", "m":
                guard index + 2 < tokens.count,
                      let x = Double(tokens[index + 1]),
                      let y = Double(tokens[index + 2])
                else {
                    index += 1
                    continue
                }
                commands.append(.moveTo(x: x, y: y))
                index += 3
            case "L", "l":
                guard index + 2 < tokens.count,
                      let x = Double(tokens[index + 1]),
                      let y = Double(tokens[index + 2])
                else {
                    index += 1
                    continue
                }
                commands.append(.lineTo(x: x, y: y))
                index += 3
            case "C", "c":
                guard index + 6 < tokens.count,
                      let x1 = Double(tokens[index + 1]),
                      let y1 = Double(tokens[index + 2]),
                      let x2 = Double(tokens[index + 3]),
                      let y2 = Double(tokens[index + 4]),
                      let x = Double(tokens[index + 5]),
                      let y = Double(tokens[index + 6])
                else {
                    index += 1
                    continue
                }
                commands.append(.curveTo(x1: x1, y1: y1, x2: x2, y2: y2, x: x, y: y))
                index += 7
            case "Z", "z":
                commands.append(.closeSubpath)
                index += 1
            default:
                index += 1
            }
        }
        return commands
    }
}

public final class CertiGoFigmaSceneGraphStore: Sendable {
    public static let shared = CertiGoFigmaSceneGraphStore()
    public static let expectedScreenCount: Int = 53
    public static let expectedTotalNodeCount: Int = 4712
    public static let expectedVectorCount: Int = 1429
    public static let expectedHotspotCount: Int = 407

    public let screensByNodeId: [String: CertiGoFigmaSceneNode]

    public init(screensByNodeId: [String: CertiGoFigmaSceneNode]? = nil) {
        if let screensByNodeId {
            self.screensByNodeId = screensByNodeId
        } else {
            self.screensByNodeId = Self.loadFromBundleOrDisk()
        }
    }

    private static func loadFromBundleOrDisk() -> [String: CertiGoFigmaSceneNode] {
        if let url = Bundle.module.url(forResource: "figma-scene-graph-53-screens", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: CertiGoFigmaSceneNode].self, from: data)
        {
            return decoded
        }
        let fallbackURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/figma-scene-graph-53-screens.json")
        if let data = try? Data(contentsOf: fallbackURL),
           let decoded = try? JSONDecoder().decode([String: CertiGoFigmaSceneNode].self, from: data)
        {
            return decoded
        }
        return [:]
    }

    public func nodeTree(forScreenNodeId nodeId: String) -> CertiGoFigmaSceneNode? {
        let trimmed = nodeId.trimmingCharacters(in: .whitespacesAndNewlines)
        return screensByNodeId[trimmed]
    }

    public func nodeTree(forScreenId screenId: String) -> CertiGoFigmaSceneNode? {
        let trimmed = screenId.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = screensByNodeId[trimmed] {
            return direct
        }
        if let content = CertiGoFigmaExactScreenParity.content(forScreenId: trimmed) {
            return screensByNodeId[content.nodeId]
        }
        if let descriptor = CertiGoMasterScreenCatalog.descriptor(forScreenCode: trimmed) {
            return screensByNodeId[descriptor.nodeId]
        }
        return nil
    }

    public var totalScreenCount: Int {
        screensByNodeId.count
    }

    public var totalNodeCount: Int {
        screensByNodeId.values.reduce(0) { $0 + $1.totalDescendantAndSelfCount }
    }

    public var totalVectorCount: Int {
        screensByNodeId.values.reduce(0) { $0 + $1.vectorNodes.count }
    }

    public var totalHotspotCount: Int {
        screensByNodeId.values.reduce(0) { $0 + $1.hotspotNodes.count }
    }

    public func mergedStatistiquesProNodes() -> (
        top: CertiGoFigmaSceneNode,
        bottom: CertiGoFigmaSceneNode
    )? {
        guard let rawTop = nodeTree(forScreenNodeId: "97:498"),
              let rawBottom = nodeTree(forScreenNodeId: "97:636")
        else {
            return nil
        }
        let top = rawTop.filteringDirectChildren { child in
            child.i != "97:609" && child.y < 740.0
        }
        let bottom = rawBottom.filteringDirectChildren { child in
            child.y >= 92.0 && !["97:640", "97:642", "97:643"].contains(child.i)
        }
        return (top: top, bottom: bottom)
    }

    public static func recommendedAnimationPreset(
        forDestinationNodeId nodeId: String
    ) -> CertiGoAnimationPresetID {
        switch nodeId {
        case "42:375", "49:368", "58:705", "62:346", "26:1009", "132:651", "132:759", "132:1009":
            return .anim02ApplePayBottomSheet
        case "85:317":
            return .anim04Claude85DrawerPush
        case "81:345":
            return .anim05NovaLiveVoicePulse
        case "142:540":
            return .anim06PearsonBarometerFill
        case "132:877", "97:498", "97:636":
            return .anim07DualCurveAndFitnessRings
        case "26:912":
            return .anim08CelebrationVictoryJump
        default:
            if nodeId.hasPrefix("73:") || nodeId == "26:826" || nodeId == "26:863" || nodeId == "26:890" {
                return .anim03Mascot34SpeechBubblePop
            }
            return .anim01Tactile3DPress
        }
    }
}

public enum CertiGoQuickChapterGroup: String, CaseIterable, Identifiable, Sendable {
    case onboarding = "Onboarding OB-01..08B"
    case parcours = "Parcours 01..03/14"
    case seanceAndQuestions = "Séance & Q_TYPE_01..10"
    case aiHub = "Hub IA 06..06D"
    case exams = "Examens 21..24"
    case social = "Social 07/25"
    case profileAndStats = "Moi & Stats Pro 08/08B/26/27/28"
    case widgetsAndIsland = "Widgets & Dynamic Island SYS-01/02"
    case offlineResilience = "Hors-Ligne RES-01/02"

    public var id: String { rawValue }

    public var screenNodeIds: [String] {
        switch self {
        case .onboarding:
            return [
                "132:182", "132:264", "132:339", "132:438", "132:519",
                "132:581", "132:651", "132:759", "132:877", "132:945", "132:1009"
            ]
        case .parcours:
            return ["37:375", "42:375", "49:368", "58:705"]
        case .seanceAndQuestions:
            return [
                "73:332", "62:346", "26:807", "26:826", "26:863", "26:890", "26:912", "26:939",
                "73:393", "73:442", "73:509", "73:575", "73:743",
                "73:818", "73:898", "73:958", "73:1019", "73:1070"
            ]
        case .aiHub:
            return ["79:332", "78:332", "81:345", "85:317"]
        case .exams:
            return ["142:385", "26:1009", "142:478", "142:540"]
        case .social:
            return ["88:317", "89:317"]
        case .profileAndStats:
            return ["97:287", "97:498", "97:636", "97:417", "144:137", "145:122"]
        case .widgetsAndIsland:
            return ["161:93", "161:134"]
        case .offlineResilience:
            return ["162:93", "162:120"]
        }
    }

    public static var orderedScreenNodeIds: [String] {
        allCases.flatMap(\.screenNodeIds)
    }

    public static func group(containingNodeId nodeId: String) -> CertiGoQuickChapterGroup {
        allCases.first { $0.screenNodeIds.contains(nodeId) } ?? .parcours
    }
}

// MARK: - 3B. Live Interactive Runtime State for the 53 Figma Pro Screens (`CertiGoFigmaLiveRuntimeState`)

public struct CertiGoFigmaLiveRuntimeState: Equatable, Sendable {
    public struct PopoverCertificationCardItem: Equatable, Sendable {
        public let code: String
        public let title: String

        public init(code: String, title: String) {
            self.code = code
            self.title = title
        }
    }

    public struct AITopicPayload: Equatable, Sendable {
        public let id: String
        public let question: String
        public let intro: String
        public let bullet1: String
        public let bullet2: String
        public let examHeader: String
        public let examRule1: String
        public let examRule2: String
        public let closing: String

        public init(
            id: String,
            question: String,
            intro: String,
            bullet1: String,
            bullet2: String,
            examHeader: String = "💡  À retenir pour l'examen AZ-104 :",
            examRule1: String,
            examRule2: String,
            closing: String
        ) {
            self.id = id
            self.question = question
            self.intro = intro
            self.bullet1 = bullet1
            self.bullet2 = bullet2
            self.examHeader = examHeader
            self.examRule1 = examRule1
            self.examRule2 = examRule2
            self.closing = closing
        }
    }

    public struct MockExamQuestionPayload: Equatable, Sendable {
        public let number: Int
        public let badge: String
        public let stem: String
        public let optionA: String
        public let optionB: String
        public let optionC: String
        public let optionD: String

        public init(
            number: Int,
            badge: String,
            stem: String,
            optionA: String,
            optionB: String,
            optionC: String,
            optionD: String
        ) {
            self.number = number
            self.badge = badge
            self.stem = stem
            self.optionA = optionA
            self.optionB = optionB
            self.optionC = optionC
            self.optionD = optionD
        }
    }

    public struct ProfileCertificationDetailPayload: Equatable, Sendable {
        public let code: String
        public let badge: String
        public let title: String
        public let progression: String
        public let lastMockExam: String
        public let crestImageFill: String?
        public let domains: [(title: String, percentText: String, barWidth: Double, colorHex: String)]

        public static func == (
            lhs: ProfileCertificationDetailPayload,
            rhs: ProfileCertificationDetailPayload
        ) -> Bool {
            lhs.code == rhs.code
                && lhs.badge == rhs.badge
                && lhs.title == rhs.title
                && lhs.progression == rhs.progression
                && lhs.lastMockExam == rhs.lastMockExam
                && lhs.crestImageFill == rhs.crestImageFill
                && lhs.domains.count == rhs.domains.count
                && zip(lhs.domains, rhs.domains).allSatisfy {
                    $0.title == $1.title
                        && $0.percentText == $1.percentText
                        && $0.barWidth == $1.barWidth
                        && $0.colorHex == $1.colorHex
                }
        }
    }

    // MARK: Popover 02 & Active Route
    public var selectedVendorInPopover: String
    public var activeRouteCode: String

    // MARK: Interactive Exercises (04, 16, 17, Q_TYPE_01..10)
    public var selectedOptionNodeIdsByScreen: [String: Set<String>]
    public var qType04InputText: String
    public var qType06PendingLeftNodeId: String?
    public var qType06PairedRightByLeftNodeId: [String: String]
    public var qType08OrderedRowNodeIds: [String]
    public var qType08SelectedRowNodeId: String?

    // MARK: Live AI Hub (06, 06B, 06C, 06D)
    public var aiActiveTopicId: String
    public var aiCustomPromptText: String
    public var aiHistorySearchText: String
    public var isAIResponseCopied: Bool
    public var isVoiceLiveListening: Bool

    // MARK: Mock Exam 23 & Report Carousel 24
    public var examCurrentQuestionNumber: Int
    public var examSelectedOptionByQuestion: [Int: String]
    public var examFlaggedQuestions: Set<Int>
    public var examReportCarouselIndex: Int

    // MARK: Social 25
    public var salutedFriendNodeIds: Set<String>
    public var isFriendInviteCopied: Bool

    // MARK: Profile 08, Detail 26, PRO 27 & Settings 28
    public var selectedProfileCertificationCode: String
    public var selectedProPlanNodeId: String
    public var isProTrialActivated: Bool
    public var settingsToggleStates: [String: Bool]
    public var settingsLanguageIndex: Int
    public var settingsExamModeIndex: Int
    public var settingsCoachVoiceIndex: Int
    public var settingsExplanationStyleIndex: Int

    // MARK: Onboarding (OB_02, OB_03A, OB_03B, OB_04, OB_06A)
    public var onboardingSelectedNodeIdsByScreen: [String: Set<String>]
    public var onboardingReminderTimeIndex: Int

    public init(
        selectedVendorInPopover: String = "microsoft",
        activeRouteCode: String = "AZ-104",
        selectedOptionNodeIdsByScreen: [String: Set<String>] = Self.defaultSelectedOptionsByScreen,
        qType04InputText: String = "lock",
        qType06PendingLeftNodeId: String? = "73:851",
        qType06PairedRightByLeftNodeId: [String: String] = ["73:842": "73:881", "73:851": "73:877"],
        qType08OrderedRowNodeIds: [String] = ["73:982", "73:990", "73:998", "73:1006"],
        qType08SelectedRowNodeId: String? = "73:990",
        aiActiveTopicId: String = "rbac-vs-policy",
        aiCustomPromptText: String = "",
        aiHistorySearchText: String = "",
        isAIResponseCopied: Bool = false,
        isVoiceLiveListening: Bool = true,
        examCurrentQuestionNumber: Int = 14,
        examSelectedOptionByQuestion: [Int: String] = [
            12: "142:508",
            13: "142:520",
            14: "142:514",
            15: "142:514",
            16: "142:526",
            17: "142:508"
        ],
        examFlaggedQuestions: Set<Int> = [13],
        examReportCarouselIndex: Int = 0,
        salutedFriendNodeIds: Set<String> = [],
        isFriendInviteCopied: Bool = false,
        selectedProfileCertificationCode: String = "AZ-104",
        selectedProPlanNodeId: String = "144:179",
        isProTrialActivated: Bool = false,
        settingsToggleStates: [String: Bool] = [
            "145:174": true,
            "145:181": true,
            "145:187": true,
            "145:193": true
        ],
        settingsLanguageIndex: Int = 0,
        settingsExamModeIndex: Int = 0,
        settingsCoachVoiceIndex: Int = 0,
        settingsExplanationStyleIndex: Int = 0,
        onboardingSelectedNodeIdsByScreen: [String: Set<String>] = Self.defaultOnboardingSelectionsByScreen,
        onboardingReminderTimeIndex: Int = 0
    ) {
        self.selectedVendorInPopover = selectedVendorInPopover
        self.activeRouteCode = activeRouteCode
        self.selectedOptionNodeIdsByScreen = selectedOptionNodeIdsByScreen
        self.qType04InputText = qType04InputText
        self.qType06PendingLeftNodeId = qType06PendingLeftNodeId
        self.qType06PairedRightByLeftNodeId = qType06PairedRightByLeftNodeId
        self.qType08OrderedRowNodeIds = qType08OrderedRowNodeIds
        self.qType08SelectedRowNodeId = qType08SelectedRowNodeId
        self.aiActiveTopicId = aiActiveTopicId
        self.aiCustomPromptText = aiCustomPromptText
        self.aiHistorySearchText = aiHistorySearchText
        self.isAIResponseCopied = isAIResponseCopied
        self.isVoiceLiveListening = isVoiceLiveListening
        self.examCurrentQuestionNumber = examCurrentQuestionNumber
        self.examSelectedOptionByQuestion = examSelectedOptionByQuestion
        self.examFlaggedQuestions = examFlaggedQuestions
        self.examReportCarouselIndex = examReportCarouselIndex
        self.salutedFriendNodeIds = salutedFriendNodeIds
        self.isFriendInviteCopied = isFriendInviteCopied
        self.selectedProfileCertificationCode = selectedProfileCertificationCode
        self.selectedProPlanNodeId = selectedProPlanNodeId
        self.isProTrialActivated = isProTrialActivated
        self.settingsToggleStates = settingsToggleStates
        self.settingsLanguageIndex = settingsLanguageIndex
        self.settingsExamModeIndex = settingsExamModeIndex
        self.settingsCoachVoiceIndex = settingsCoachVoiceIndex
        self.settingsExplanationStyleIndex = settingsExplanationStyleIndex
        self.onboardingSelectedNodeIdsByScreen = onboardingSelectedNodeIdsByScreen
        self.onboardingReminderTimeIndex = onboardingReminderTimeIndex
    }

    public static let defaultSelectedOptionsByScreen: [String: Set<String>] = [
        "73:332": ["73:364"],
        "26:826": ["26:837"],
        "26:863": ["26:876", "26:879"],
        "73:393": ["73:425"],
        "73:442": ["73:467"],
        "73:509": ["73:554"],
        "73:743": ["73:767", "73:771", "73:775", "73:779", "73:784", "73:788"],
        "73:818": ["73:851", "73:877"],
        "73:898": ["73:941"],
        "73:1019": ["73:1058"],
        "73:1070": ["73:1095", "73:1101"]
    ]

    public static let defaultOnboardingSelectionsByScreen: [String: Set<String>] = [
        "132:264": ["132:301", "132:310"],
        "132:339": ["132:379", "132:396", "132:406"],
        "132:438": ["132:452", "132:463", "132:474"],
        "132:519": ["132:539", "132:562"],
        "132:581": ["132:600"]
    ]

    public static let singleSelectOptionGroupsByScreen: [String: [String]] = [
        "73:332": ["73:360", "73:364", "73:368", "73:372"],
        "26:826": ["26:837", "26:843", "26:849", "26:855"],
        "73:393": ["73:421", "73:425", "73:429", "73:433"],
        "73:442": ["73:467", "73:476", "73:485", "73:493"],
        "73:509": ["73:554", "73:558", "73:562", "73:566"],
        "73:898": ["73:923", "73:929", "73:935", "73:941", "73:947"],
        "73:1019": ["73:1051", "73:1058"]
    ]

    public static let multiSelectOptionGroupsByScreen: [String: [String]] = [
        "73:1070": ["73:1095", "73:1101", "73:1107", "73:1112"],
        "73:743": [
            "73:767", "73:771", "73:775", "73:779", "73:784",
            "73:788", "73:795", "73:800", "73:804", "73:809"
        ],
        "26:863": ["26:876", "26:879", "26:882", "26:885"]
    ]

    public static let vendorByTileNodeId: [String: String] = [
        "42:491": "microsoft",
        "42:498": "aws",
        "42:505": "google",
        "42:511": "github",
        "42:514": "cisco"
    ]

    public static let vendorDisplayNames: [String: String] = [
        "microsoft": "Microsoft",
        "aws": "AWS",
        "google": "Google",
        "github": "GitHub",
        "cisco": "Cisco"
    ]

    public static func popoverCards(forVendor vendor: String) -> [PopoverCertificationCardItem] {
        switch vendor.lowercased() {
        case "aws":
            return [
                PopoverCertificationCardItem(code: "SAA-C03", title: "Solutions Architect"),
                PopoverCertificationCardItem(code: "CLF-C02", title: "Cloud Practitioner"),
                PopoverCertificationCardItem(code: "AIF-C01", title: "AI Practitioner")
            ]
        case "google", "gcp":
            return [
                PopoverCertificationCardItem(code: "ACE", title: "Cloud Engineer"),
                PopoverCertificationCardItem(code: "PCA", title: "Cloud Architect"),
                PopoverCertificationCardItem(code: "PDE", title: "Data Engineer")
            ]
        case "github":
            return [
                PopoverCertificationCardItem(code: "GH-300", title: "GitHub Copilot"),
                PopoverCertificationCardItem(code: "GH-900", title: "Foundations"),
                PopoverCertificationCardItem(code: "GH-AS", title: "Advanced Security")
            ]
        case "cisco", "cncf":
            return [
                PopoverCertificationCardItem(code: "CCNA", title: "Network Associate"),
                PopoverCertificationCardItem(code: "CKA", title: "Kubernetes Admin"),
                PopoverCertificationCardItem(code: "TF-003", title: "Terraform")
            ]
        default:
            return [
                PopoverCertificationCardItem(code: "AZ-104", title: "Azure Administrator"),
                PopoverCertificationCardItem(code: "AZ-900", title: "Azure Fundamentals"),
                PopoverCertificationCardItem(code: "AI-102", title: "Azure AI Engineer")
            ]
        }
    }

    public var currentPopoverCards: [PopoverCertificationCardItem] {
        Self.popoverCards(forVendor: selectedVendorInPopover)
    }

    public static let settingsLanguageOptions: [String] = [
        "FR + Termes EN  ›",
        "Français intégral  ›",
        "English (US)  ›"
    ]

    public static let settingsExamModeOptions: [String] = [
        "Chrono 90m  ›",
        "Temps majoré ×1,5  ›",
        "Sans limite  ›"
    ]

    public static let settingsCoachVoiceOptions: [String] = [
        "Nova (1,0×)  ›",
        "Nova (1,2×)  ›",
        "Alloy (1,0×)  ›"
    ]

    public static let settingsExplanationStyleOptions: [String] = [
        "Détaillé + CLI  ›",
        "Synthèse Flash  ›",
        "Socrate (Guidé)  ›"
    ]

    public static let onboardingReminderTimeOptions: [String] = [
        "19 : 30",
        "08 : 30",
        "12 : 30",
        "20 : 30"
    ]

    public var currentSettingsLanguageLabel: String {
        Self.settingsLanguageOptions[settingsLanguageIndex % Self.settingsLanguageOptions.count]
    }

    public var currentSettingsExamModeLabel: String {
        Self.settingsExamModeOptions[settingsExamModeIndex % Self.settingsExamModeOptions.count]
    }

    public var currentSettingsCoachVoiceLabel: String {
        Self.settingsCoachVoiceOptions[settingsCoachVoiceIndex % Self.settingsCoachVoiceOptions.count]
    }

    public var currentSettingsExplanationStyleLabel: String {
        Self.settingsExplanationStyleOptions[settingsExplanationStyleIndex % Self.settingsExplanationStyleOptions.count]
    }

    public var isCurrentExamQuestionFlagged: Bool {
        examFlaggedQuestions.contains(examCurrentQuestionNumber)
    }

    public var currentExamSelectedOptionNodeId: String {
        examSelectedOptionByQuestion[examCurrentQuestionNumber] ?? "142:514"
    }

    public func isOptionSelected(_ nodeId: String, inScreen screenNodeId: String) -> Bool {
        selectedOptionNodeIdsByScreen[screenNodeId]?.contains(nodeId) ?? false
    }

    public func isSettingsToggleOn(_ nodeId: String) -> Bool {
        settingsToggleStates[nodeId] ?? true
    }

    public func isFriendSaluted(_ nodeId: String) -> Bool {
        salutedFriendNodeIds.contains(nodeId)
    }

    // MARK: AI Topics Catalog

    public static let aiTopicsById: [String: AITopicPayload] = [
        "rbac-vs-policy": AITopicPayload(
            id: "rbac-vs-policy",
            question: "Quelle est la différence entre RBAC et Azure Policy ?",
            intro: "Ces deux services assurent la gouvernance Azure, mais ils agissent sur deux dimensions différentes :",
            bullet1: "•  Azure RBAC (Qui fait quoi) : Gère les accès des utilisateurs et groupes en attribuant des rôles (Lecteur, Contributeur, Propriétaire).",
            bullet2: "•  Azure Policy (Sous quelles règles) : Vérifie la conformité des ressources elles-mêmes (ex. imposer une région ou un tag obligatoire).",
            examRule1: "•  Priorité des règles : Même un utilisateur Propriétaire (Owner) est bloqué si une Azure Policy interdit la région choisie.",
            examRule2: "•  Cumul : Un utilisateur doit être autorisé à la fois par son rôle RBAC et par les stratégies Azure Policy actives.",
            closing: "Si tu veux, je peux te montrer un exemple JSON ou te poser une question type examen sur ce sujet."
        ),
        "oral-interview": AITopicPayload(
            id: "oral-interview",
            question: "Simuler un entretien oral : Architecture & Gouvernance Azure",
            intro: "Voici le scénario d'entretien oral AZ-104 sur lequel je t'interroge en direct :",
            bullet1: "•  Cas Contoso : 50 VMs dans un VNet-Spoke doivent accéder à Key Vault sans exposition Internet et sans secret stocké dans le code.",
            bullet2: "•  Réponse attendue à l'oral : Managed Identity (Identité managée) + Rôle RBAC Key Vault Secrets User + Private Endpoint avec zone DNS privatelink.",
            examRule1: "•  Question de relance : Que se passe-t-il si un verrou CanNotDelete est posé sur le groupe de ressources ?",
            examRule2: "•  Verdict : Même un Propriétaire (Owner) doit retirer le verrou avant toute suppression.",
            closing: "Touche le bouton vocal bleu pour continuer l'entretien oral à voix haute !"
        ),
        "last-3-errors": AITopicPayload(
            id: "last-3-errors",
            question: "Analyse mes 3 dernières erreurs et mes points faibles",
            intro: "J'ai analysé tes 3 dernières erreurs sur AZ-104. Voici ton diagnostic ciblé :",
            bullet1: "•  1. Private Endpoint & DNS (58 %) : Créer le Private Endpoint ne désactive pas publicNetworkAccess et requiert un Virtual Network Link sur privatelink.*.",
            bullet2: "•  2. Rôles JSON personnalisés : Mettre \"*\" dans NotActions soustrait toutes les permissions d'Actions — le rôle ne peut plus rien faire.",
            examRule1: "•  3. Verrous Azure : Un verrou CanNotDelete prime toujours sur le rôle Propriétaire (Owner) tant qu'il n'est pas retiré.",
            examRule2: "•  Action recommandée : Lance le quiz ciblé de 5 questions pour transformer ces 3 pièges en points forts (+65 pts Pearson VUE).",
            closing: "Touche « 🎯 Quiz » ci-dessous pour t'entraîner immédiatement sur ces 3 sujets !"
        ),
        "cli-example": AITopicPayload(
            id: "cli-example",
            question: "Génère un exemple Azure CLI commenté pour le lab pratique",
            intro: "Voici les 3 commandes Azure CLI indispensables pour isoler un service PaaS avec Private Link :",
            bullet1: "•  1. Créer le VNet & Subnet : az network vnet create -g RG-Prod -n VNet-Core --address-prefix 10.0.0.0/16 --subnet-name snet-pe",
            bullet2: "•  2. Lier la zone DNS privée : az network private-dns link vnet create -g RG-Prod -z privatelink.blob.core.windows.net -v VNet-Core -e false",
            examRule1: "•  Piège CLI à l'examen : Le paramètre -e false (--registration-enabled false) est obligatoire sur une zone privatelink PaaS.",
            examRule2: "•  Verrouillage CLI : az group lock create --lock-type CanNotDelete -n Lock-Prod -g RG-Prod.",
            closing: "Sauvegarde cet extrait dans tes Fiches Mémo avec le bouton « 📖 Sauver en Mémo » !"
        ),
        "vnet-peering-cli": AITopicPayload(
            id: "vnet-peering-cli",
            question: "Commandes CLI pour VNet Peering bidirectionnel",
            intro: "Le VNet Peering n'est ni transitif par défaut ni unidirectionnel : il faut créer les 2 liens :",
            bullet1: "•  Lien Hub ➔ Spoke : az network vnet peering create -g RG-Net -n HubToSpoke --vnet-name VNet-Hub --remote-vnet VNet-Spoke --allow-vnet-access",
            bullet2: "•  Lien Spoke ➔ Hub : az network vnet peering create -g RG-Net -n SpokeToHub --vnet-name VNet-Spoke --remote-vnet VNet-Hub --allow-forwarded-traffic",
            examRule1: "•  Transit VPN / ExpressRoute : Associe --allow-gateway-transit sur le Hub et --use-remote-gateways sur le Spoke.",
            examRule2: "•  Non-chevauchement CIDR : Deux VNets dont les plages IP se chevauchent ne peuvent jamais être appairés.",
            closing: "Tu peux lancer un exercice d'architecture VNet en touchant « 🎯 Quiz »."
        ),
        "entra-pim-oral": AITopicPayload(
            id: "entra-pim-oral",
            question: "Simulation orale : Entra ID Privileged Identity Management (PIM)",
            intro: "Entra ID PIM remplace les rôles permanents par une élévation Just-In-Time (JIT) :",
            bullet1: "•  Attribution Éligible (Eligible) : L'administrateur doit activer son rôle temporairement (ex. 4 heures) pour agir.",
            bullet2: "•  Contrôles d'activation : Tu peux exiger MFA, une justification métier, un numéro de ticket et une approbation.",
            examRule1: "•  Licence requise : Entra ID P2 (ou Microsoft Entra ID Governance) pour chaque utilisateur géré par PIM.",
            examRule2: "•  Revue d'accès (Access Reviews) : Permet de révoquer automatiquement les accès des invités inactifs.",
            closing: "Touche « 🎯 Quiz » pour vérifier ce point sur la question Q_TYPE_10 !"
        ),
        "cannotdelete-lock": AITopicPayload(
            id: "cannotdelete-lock",
            question: "Explication erreur : Verrou CanNotDelete vs Rôle Propriétaire",
            intro: "Pourquoi Alice (Propriétaire / Owner de l'abonnement) ne peut-elle pas supprimer sql-prod-db ?",
            bullet1: "•  Héritage du verrou : Un verrou CanNotDelete posé sur RG-Prod s'applique automatiquement à toutes les ressources enfants.",
            bullet2: "•  Évaluation ARM : Azure Resource Manager vérifie les verrous AVANT d'exécuter l'opération DELETE, quel que soit le rôle RBAC.",
            examRule1: "•  ReadOnly vs CanNotDelete : Un verrou ReadOnly bloque même le listKeys d'un Storage Account ou Key Vault !",
            examRule2: "•  Solution : Comme Alice est Owner, elle a le droit de supprimer le verrou d'abord, puis de supprimer la base SQL.",
            closing: "Retiens cette règle : Verrou ARM > Rôle RBAC Owner tant que le verrou est actif."
        ),
        "appgw-vs-lb": AITopicPayload(
            id: "appgw-vs-lb",
            question: "Application Gateway (Couche 7) vs Azure Load Balancer (Couche 4)",
            intro: "Choisis ton répartiteur de charge Azure selon la couche OSI et le besoin de sécurité :",
            bullet1: "•  Azure Application Gateway (L7 HTTP/HTTPS) : Routage par URL (/images, /api), déchiffrement TLS, affinité par cookie et pare-feu WAF.",
            bullet2: "•  Azure Load Balancer (L4 TCP/UDP) : Ultra-faible latence pour le trafic non-HTTP (SQL, RDP, SSH, microservices TCP).",
            examRule1: "•  Portée régionale vs globale : Application Gateway et Load Balancer sont régionaux ; Front Door et Traffic Manager sont globaux.",
            examRule2: "•  Règle d'or AZ-104 : Dès que l'énoncé mentionne « WAF OWASP » ou « routage par chemin d'URL », choisis Application Gateway.",
            closing: "Tu peux retrouver ce schéma interactif dans l'exercice Q_TYPE_03."
        ),
        "nsg-priority": AITopicPayload(
            id: "nsg-priority",
            question: "Règles NSG (Network Security Group) et priorités de trafic",
            intro: "Un NSG filtre le trafic à l'entrée et à la sortie d'un sous-réseau ou d'une carte réseau (NIC) :",
            bullet1: "•  Priorité de 100 à 4096 : La règle avec le numéro le plus petit (ex. 100) est évaluée en premier et arrête l'évaluation dès qu'elle correspond.",
            bullet2: "•  Stateful (avec état) : Si un flux entrant HTTPS (443) est autorisé, la réponse sortante est automatiquement autorisée.",
            examRule1: "•  Double NSG (Subnet + NIC) : En trafic entrant, le NSG du Subnet est évalué d'abord, puis celui de la NIC (les deux doivent autoriser).",
            examRule2: "•  ASG (Application Security Group) : Regroupe des VMs par rôle métier (Web, App, DB) sans gérer d'adresses IP en dur.",
            closing: "Pense toujours à vérifier à la fois le NSG du sous-réseau et celui de la NIC !"
        ),
        "azure-backup": AITopicPayload(
            id: "azure-backup",
            question: "Sauvegarde Azure Backup vs Azure Site Recovery (ASR)",
            intro: "Distingue clairement la restauration granulaire de données (Backup) et la reprise après sinistre (ASR) :",
            bullet1: "•  Azure Backup (Recovery Services Vault) : Protège contre la corruption ou suppression accidentelle (rétention longue durée, Soft Delete 14 jours).",
            bullet2: "•  Azure Site Recovery (ASR) : Réplique en continu les VMs vers une région secondaire pour un basculement (Failover) avec RTO en minutes.",
            examRule1: "•  Règle de région : Un Recovery Services Vault de sauvegarde VM doit être dans la même région que la VM source.",
            examRule2: "•  Cross-Region Restore (CRR) : Nécessite une redondance GRS (Geo-Redundant Storage) activée sur le coffre.",
            closing: "C'est l'un des sujets favoris du domaine 5 (Supervision & Sauvegarde) d'AZ-104."
        ),
        "iam-vs-s3-policy": AITopicPayload(
            id: "iam-vs-s3-policy",
            question: "Rôles AWS IAM vs Bucket Policy S3 (Multi-Parcours SAA-C03)",
            intro: "Sur AWS SAA-C03, IAM et les Bucket Policies S3 combinent politiques basées sur l'identité et sur la ressource :",
            bullet1: "•  IAM Role / Policy (Identity-based) : Attaché à un utilisateur, groupe ou service EC2/Lambda (Qui a le droit de faire quoi).",
            bullet2: "•  S3 Bucket Policy (Resource-based) : Attachée directement au bucket S3 (idéal pour l'accès inter-comptes AWS ou CloudFront OAC).",
            examRule1: "•  Explicit Deny : Comme dans Azure, un Deny explicite dans une Bucket Policy ou SCP l'emporte toujours sur n'importe quel Allow.",
            examRule2: "•  S3 Block Public Access : Verrouille l'exposition publique au niveau du bucket ou du compte AWS entier.",
            closing: "Bascule sur le parcours SAA-C03 depuis l'accueil pour pratiquer les labs AWS !"
        )
    ]

    public var currentAITopicPayload: AITopicPayload {
        if aiActiveTopicId == "custom", !aiCustomPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmed = aiCustomPromptText.trimmingCharacters(in: .whitespacesAndNewlines)
            return AITopicPayload(
                id: "custom",
                question: trimmed,
                intro: "Voici la synthèse structurée CertiGo IA pour ta question sur \(activeRouteCode) :",
                bullet1: "•  Principe architectural : Sépare toujours le plan d'identité (RBAC / IAM) du plan réseau (Private Link / VNet) et de la gouvernance (Policy / Verrous).",
                bullet2: "•  Mise en œuvre : Privilégie les identités managées (Managed Identities) et l'isolation PaaS privée avec résolution DNS dédiée.",
                examRule1: "•  Réflexe d'examen : Repère dans l'énoncé les contraintes « sans exposition Internet », « moindre privilège » et « SLA 99,99 % ».",
                examRule2: "•  Commande clé : Vérifie systématiquement la portée (Scope) et les verrous actifs avant toute action de modification.",
                closing: "Touche « 📖 Sauver en Mémo » pour conserver cette fiche ou « 🎯 Quiz » pour tester ce concept !"
            )
        }
        return Self.aiTopicsById[aiActiveTopicId] ?? Self.aiTopicsById["rbac-vs-policy"]!
    }

    // MARK: Mock Exam Questions Catalog (Screen 23)

    public static let mockExamQuestionsByNumber: [Int: MockExamQuestionPayload] = [
        12: MockExamQuestionPayload(
            number: 12,
            badge: "ÉTUDE DE CAS CONTOSO · IDENTITÉ ENTRA ID",
            stem: "Un administrateur doit activer le rôle Global Reader uniquement pendant 4 heures avec approbation obligatoire et MFA.\nQuelle fonctionnalité déployez-vous ?",
            optionA: "Attributions RBAC permanentes avec groupe de sécurité dynamique",
            optionB: "Microsoft Entra ID Privileged Identity Management (PIM) — rôle éligible",
            optionC: "Stratégie Azure Policy AuditIfNotExists sur l'abonnement",
            optionD: "Verrou Resource Manager ReadOnly sur le groupe d'administration"
        ),
        13: MockExamQuestionPayload(
            number: 13,
            badge: "ÉTUDE DE CAS CONTOSO · RÉSEAUX HYBRIDES",
            stem: "Deux VNets (10.1.0.0/16 et 10.2.0.0/16) appairés en VNet Peering doivent partager la passerelle ExpressRoute du VNet-Hub.\nQuels paramètres activez-vous ?",
            optionA: "Autoriser le transit de passerelle sur le Hub + Utiliser les passerelles distantes sur le Spoke",
            optionB: "Créer deux passerelles VPN redondantes avec BGP actif-actif dans chaque Spoke",
            optionC: "Déployer un Azure Load Balancer Standard Interne entre les deux VNets",
            optionD: "Activer Service Endpoint Microsoft.Network sur tous les sous-réseaux"
        ),
        14: MockExamQuestionPayload(
            number: 14,
            badge: "ÉTUDE DE CAS CONTOSO · SÉCURITÉ",
            stem: "50 VMs dans VNet-Spoke doivent lire les secrets d'un coffre Azure Key Vault sans exposition Internet et avec contrôle RBAC unifié.\nQuelle architecture déployez-vous ?",
            optionA: "Service Endpoint + Stratégie d'accès Key Vault classique sur le sous-réseau",
            optionB: "Private Endpoint + Zone DNS privatelink + Rôle RBAC Key Vault Secrets User",
            optionC: "Azure NAT Gateway + Pare-feu public Key Vault limité à l'IP sortante",
            optionD: "Appeler Key Vault via une adresse IP publique avec jeton SAS temporaire"
        ),
        15: MockExamQuestionPayload(
            number: 15,
            badge: "ÉTUDE DE CAS CONTOSO · STOCKAGE & RÉSILIENCE",
            stem: "Un compte de stockage contenant des archives légales doit rester lisible dans une région secondaire même en cas de panne régionale complète.\nQuelle redondance choisissez-vous ?",
            optionA: "LRS (Locally Redundant Storage) avec Soft Delete 14 jours",
            optionB: "RA-GRS (Read-Access Geo-Redundant Storage)",
            optionC: "ZRS (Zone-Redundant Storage) sur 3 zones de disponibilité",
            optionD: " Stockage Blob Premium avec réplication locale synchrone"
        ),
        16: MockExamQuestionPayload(
            number: 16,
            badge: "ÉTUDE DE CAS CONTOSO · CALCUL & AKS",
            stem: "Votre cluster AKS de production doit mettre à l'échelle automatiquement le nombre de nœuds VM lorsque les pods sont en état Pending par manque de CPU.\nQuel composant activez-vous ?",
            optionA: "Horizontal Pod Autoscaler (HPA) uniquement sur le déploiement Kubernetes",
            optionB: "Azure Traffic Manager en mode Performance",
            optionC: "AzureUpdate Manager avec maintenance planifiée",
            optionD: "Cluster Autoscaler sur le pool de nœuds AKS (Virtual Machine Scale Sets)"
        ),
        17: MockExamQuestionPayload(
            number: 17,
            badge: "ÉTUDE DE CAS CONTOSO · SUPERVISION & BACKUP",
            stem: "Vous devez sauvegarder 12 VMs Azure situées dans West Europe vers un coffre Recovery Services Vault avec restauration inter-régions.\nQuelle configuration est requise ?",
            optionA: "Coffre dans West Europe en stockage GRS avec Cross-Region Restore (CRR) activé",
            optionB: "Coffre dans North Europe en stockage LRS sans agent",
            optionC: "Instantanés (Snapshots) manuels stockés dans le même groupe de ressources",
            optionD: "Règle d'alerte Azure Monitor Log Analytics sans coffre de sauvegarde"
        )
    ]

    public var currentMockExamQuestionPayload: MockExamQuestionPayload {
        Self.mockExamQuestionsByNumber[examCurrentQuestionNumber]
            ?? Self.mockExamQuestionsByNumber[14]!
    }

    // MARK: Profile Certification Detail Catalog (Screen 26)

    public static func profileCertificationDetail(
        forCode code: String
    ) -> ProfileCertificationDetailPayload {
        switch code.uppercased() {
        case "AZ-900":
            return ProfileCertificationDetailPayload(
                code: "AZ-900",
                badge: "MICROSOFT CERTIFIED FUNDAMENTALS",
                title: "Azure Fundamentals (AZ-900)",
                progression: "100 % (10/10)",
                lastMockExam: "890 / 1000 ✓",
                crestImageFill: nil,
                domains: [
                    ("1. Concepts Cloud & Haute Disponibilité", "94%", 295.0, "#58cc02"),
                    ("2. Architecture & Services Azure (Calcul/Data)", "90%", 280.0, "#58cc02"),
                    ("3. Sécurité, Gouvernance & Conformité", "88%", 270.0, "#0078d4"),
                    ("4. Tarification, TCO & Cycle de vie SLA", "85%", 260.0, "#0078d4")
                ]
            )
        case "SAA-C03":
            return ProfileCertificationDetailPayload(
                code: "SAA-C03",
                badge: "AWS CERTIFIED ASSOCIATE",
                title: "Solutions Architect (SAA-C03)",
                progression: "25 % (4/16)",
                lastMockExam: "715 / 1000 ✓",
                crestImageFill: "img:e3041bf6f6e2b3d0b97ee7a5aba3518aefc60108",
                domains: [
                    ("1. Conception d'architectures sécurisées (IAM)", "78%", 240.0, "#58cc02"),
                    ("2. Architectures résilientes (Multi-AZ / VPC)", "68%", 210.0, "#0078d4"),
                    ("3. Haute performance (S3, CloudFront, Aurora)", "54%", 168.0, "#f59e0b"),
                    ("4. Optimisation des coûts AWS (Savings Plans)", "48%", 150.0, "#f59e0b")
                ]
            )
        case "GH-300":
            return ProfileCertificationDetailPayload(
                code: "GH-300",
                badge: "GITHUB OFFICIAL CERTIFICATION",
                title: "GitHub Copilot (GH-300)",
                progression: "80 % (8/10)",
                lastMockExam: "840 / 1000 ✓",
                crestImageFill: "img:7149e104bfe0be393cbd68e92a1dba4c1f0f7936",
                domains: [
                    ("1. IA Responsable & Confidentialité du code", "92%", 290.0, "#58cc02"),
                    ("2. Ingénierie de Prompt & Contexte IDE", "86%", 265.0, "#58cc02"),
                    ("3. Tests unitaires, Refactoring & Débogage IA", "80%", 248.0, "#0078d4"),
                    ("4. Gouvernance Enterprise, CLI & Sécurité", "74%", 225.0, "#0078d4")
                ]
            )
        default:
            return ProfileCertificationDetailPayload(
                code: "AZ-104",
                badge: "MICROSOFT CERTIFIED ASSOCIATE",
                title: "Azure Administrator (AZ-104)",
                progression: "65 % (12/18)",
                lastMockExam: "760 / 1000 ✓",
                crestImageFill: nil,
                domains: [
                    ("1. Identité & Gouvernance Entra ID", "85%", 260.0, "#58cc02"),
                    ("2. Stockage & Comptes Azure", "72%", 220.0, "#0078d4"),
                    ("3. Calcul & Conteneurs (VMs / AKS)", "64%", 196.0, "#0078d4"),
                    ("4. Réseaux Virtuels (VNet / DNS)", "45%", 138.0, "#f59e0b")
                ]
            )
        }
    }

    // MARK: Interactive Tap Handler

    /// Handles an interactive tap on a Figma node or `"act:<nodeId>"` target.
    /// Returns an optional destination screen `nodeId` if the interaction also navigates to another screen.
    @discardableResult
    public mutating func handleTap(
        onNodeId rawTarget: String,
        inScreenNodeId screenNodeId: String,
        coordinator: inout PrismAppShellCoordinatorModel
    ) -> String? {
        let nodeId: String = {
            if rawTarget.hasPrefix("act:") {
                return String(rawTarget.dropFirst(4))
            }
            return rawTarget
        }()

        // 1. Popover 02 (42:375) vendor tiles & certification cards
        if let vendor = Self.vendorByTileNodeId[nodeId] {
            selectedVendorInPopover = vendor
            return nil
        }
        if screenNodeId == "42:375" || ["42:522", "42:532", "42:540"].contains(nodeId) {
            let cards = currentPopoverCards
            let selectedIndex: Int? = {
                switch nodeId {
                case "42:522": return 0
                case "42:532": return 1
                case "42:540": return 2
                default: return nil
                }
            }()
            if let idx = selectedIndex, idx < cards.count {
                let code = cards[idx].code
                activeRouteCode = code
                coordinator.parallelTracksPreference.setActiveTrack(code)
                coordinator.todayModel.activeRouteCode = code
                coordinator.todayModel.activeRouteTitle = cards[idx].title
                return "37:375"
            }
        }

        // 2. Single-choice QCM screens (73:332, 26:826, 73:393, 73:442, 73:509, 73:898, 73:1019)
        for (qScreenId, options) in Self.singleSelectOptionGroupsByScreen {
            if (screenNodeId == qScreenId || options.contains(nodeId)), options.contains(nodeId) {
                selectedOptionNodeIdsByScreen[qScreenId] = [nodeId]
                return nil
            }
        }

        // 3. Multi-select & Word Bank screens (73:1070, 73:743, 26:863)
        for (mScreenId, options) in Self.multiSelectOptionGroupsByScreen {
            if (screenNodeId == mScreenId || options.contains(nodeId)), options.contains(nodeId) {
                var current = selectedOptionNodeIdsByScreen[mScreenId] ?? []
                if current.contains(nodeId) {
                    if current.count > 1 {
                        current.remove(nodeId)
                    } else {
                        current.remove(nodeId)
                    }
                } else {
                    current.insert(nodeId)
                }
                selectedOptionNodeIdsByScreen[mScreenId] = current
                return nil
            }
        }

        // 4. Q_TYPE_06 Matching Pairs (73:818)
        let leftPairs = ["73:842", "73:851", "73:860", "73:869"]
        let rightPairs = ["73:877", "73:881", "73:885", "73:889"]
        if leftPairs.contains(nodeId) {
            qType06PendingLeftNodeId = nodeId
            var set = selectedOptionNodeIdsByScreen["73:818"] ?? []
            set.insert(nodeId)
            selectedOptionNodeIdsByScreen["73:818"] = set
            return nil
        }
        if rightPairs.contains(nodeId) {
            let leftId = qType06PendingLeftNodeId ?? "73:851"
            qType06PairedRightByLeftNodeId[leftId] = nodeId
            selectedOptionNodeIdsByScreen["73:818"] = [leftId, nodeId]
            return nil
        }

        // 5. Q_TYPE_08 Scope Ordering (73:958)
        let orderRows = ["73:982", "73:990", "73:998", "73:1006"]
        if orderRows.contains(nodeId) {
            if let previous = qType08SelectedRowNodeId,
               previous != nodeId,
               let firstIdx = qType08OrderedRowNodeIds.firstIndex(of: previous),
               let secondIdx = qType08OrderedRowNodeIds.firstIndex(of: nodeId)
            {
                qType08OrderedRowNodeIds.swapAt(firstIdx, secondIdx)
                qType08SelectedRowNodeId = nodeId
            } else {
                qType08SelectedRowNodeId = nodeId
            }
            selectedOptionNodeIdsByScreen["73:958"] = [nodeId]
            return nil
        }

        // 6. Q_TYPE_04 iOS Keyboard & CLI Input (73:575)
        if nodeId == "73:613" || nodeId == "73:615" {
            qType04InputText = "lock"
            return nil
        }
        if nodeId == "73:617" {
            qType04InputText = "list"
            return nil
        }
        if nodeId == "73:726" {
            if !qType04InputText.isEmpty {
                qType04InputText.removeLast()
            }
            return nil
        }
        if nodeId == "73:734" {
            qType04InputText += " "
            return nil
        }
        if nodeId == "73:738" {
            return "73:743"
        }
        if let keyLetter = Self.keyboardLetterByNodeId[nodeId] {
            if qType04InputText == "lock" || qType04InputText == "list" {
                qType04InputText = keyLetter.lowercased()
            } else if qType04InputText.count < 14 {
                qType04InputText += keyLetter.lowercased()
            }
            return nil
        }

        // 7. Hub IA (79:332, 78:332, 81:345, 85:317)
        switch nodeId {
        case "79:352":
            aiActiveTopicId = "rbac-vs-policy"
            isAIResponseCopied = false
            return "78:332"
        case "79:356":
            aiActiveTopicId = "oral-interview"
            isVoiceLiveListening = true
            return "81:345"
        case "79:360":
            aiActiveTopicId = "last-3-errors"
            isAIResponseCopied = false
            return "78:332"
        case "79:364":
            aiActiveTopicId = "cli-example"
            isAIResponseCopied = false
            return "78:332"
        case "78:366":
            isAIResponseCopied = true
            return nil
        case "78:371":
            return "58:705"
        case "78:373":
            return "73:393"
        case "81:365":
            isVoiceLiveListening.toggle()
            return nil
        case "85:378":
            aiActiveTopicId = "rbac-vs-policy"
            isAIResponseCopied = false
            return "78:332"
        case "85:380":
            aiActiveTopicId = "vnet-peering-cli"
            isAIResponseCopied = false
            return "78:332"
        case "85:383":
            aiActiveTopicId = "entra-pim-oral"
            isAIResponseCopied = false
            return "78:332"
        case "85:387":
            aiActiveTopicId = "cannotdelete-lock"
            isAIResponseCopied = false
            return "78:332"
        case "85:388":
            aiActiveTopicId = "appgw-vs-lb"
            isAIResponseCopied = false
            return "78:332"
        case "85:392":
            aiActiveTopicId = "nsg-priority"
            isAIResponseCopied = false
            return "78:332"
        case "85:393":
            aiActiveTopicId = "azure-backup"
            isAIResponseCopied = false
            return "78:332"
        case "85:394":
            aiActiveTopicId = "iam-vs-s3-policy"
            isAIResponseCopied = false
            return "78:332"
        case "85:395":
            aiCustomPromptText = ""
            return "79:332"
        default:
            break
        }

        // 8. Cockpit Examen Blanc 23 (142:478) & Carrousel Rapport 24 (142:540)
        if ["142:508", "142:514", "142:520", "142:526"].contains(nodeId) {
            examSelectedOptionByQuestion[examCurrentQuestionNumber] = nodeId
            return nil
        }
        if nodeId == "142:487" || nodeId == "142:488" {
            if examFlaggedQuestions.contains(examCurrentQuestionNumber) {
                examFlaggedQuestions.remove(examCurrentQuestionNumber)
            } else {
                examFlaggedQuestions.insert(examCurrentQuestionNumber)
            }
            return nil
        }
        let examPillToNumber: [String: Int] = [
            "142:490": 12,
            "142:492": 13,
            "142:494": 14,
            "142:496": 15,
            "142:498": 16,
            "142:500": 17
        ]
        if let qNum = examPillToNumber[nodeId] {
            examCurrentQuestionNumber = qNum
            return nil
        }
        if nodeId == "142:532" {
            if examCurrentQuestionNumber > 12 {
                examCurrentQuestionNumber -= 1
                return nil
            }
            return "142:385"
        }
        if nodeId == "142:536" {
            if examCurrentQuestionNumber < 17 {
                examCurrentQuestionNumber += 1
                return nil
            }
            return "142:540"
        }
        if nodeId == "142:573" || nodeId == "142:574" || nodeId == "142:584" {
            examReportCarouselIndex = (examReportCarouselIndex + 1) % 3
            return nil
        }
        if nodeId == "142:585" {
            examReportCarouselIndex = 0
            return nil
        }
        if nodeId == "142:586" {
            examReportCarouselIndex = 1
            return nil
        }
        if nodeId == "142:587" {
            examReportCarouselIndex = 2
            return nil
        }

        // 9. Social 25 (89:317)
        if ["89:493", "89:504", "89:515", "89:526", "89:537"].contains(nodeId) {
            if salutedFriendNodeIds.contains(nodeId) {
                salutedFriendNodeIds.remove(nodeId)
            } else {
                salutedFriendNodeIds.insert(nodeId)
            }
            return nil
        }
        if nodeId == "89:480" || nodeId == "89:484" {
            isFriendInviteCopied = true
            return nil
        }

        // 10. Profil 08 (97:287), Détail Certif 26 (97:417), PRO 27 (144:137) & Paramètres 28 (145:122)
        let profileCardToCode: [String: String] = [
            "97:336": "AZ-104",
            "97:338": "AZ-104",
            "97:355": "AZ-900",
            "97:374": "SAA-C03",
            "97:382": "GH-300"
        ]
        if let certCode = profileCardToCode[nodeId] {
            selectedProfileCertificationCode = certCode
            return "97:417"
        }
        if nodeId == "144:179" || nodeId == "144:187" {
            selectedProPlanNodeId = nodeId
            return nil
        }
        if nodeId == "144:195" {
            isProTrialActivated = true
            return "97:287"
        }
        if ["145:174", "145:181", "145:187", "145:193"].contains(nodeId) {
            let current = settingsToggleStates[nodeId] ?? true
            settingsToggleStates[nodeId] = !current
            return nil
        }
        if nodeId == "145:146" || nodeId == "145:147" {
            settingsLanguageIndex = (settingsLanguageIndex + 1) % Self.settingsLanguageOptions.count
            coordinator.parallelTracksPreference.bilingualTechnicalTermsEN = (settingsLanguageIndex == 0)
            return nil
        }
        if nodeId == "145:152" || nodeId == "145:153" {
            settingsExamModeIndex = (settingsExamModeIndex + 1) % Self.settingsExamModeOptions.count
            coordinator.parallelTracksPreference.strictTimed90Min = (settingsExamModeIndex == 0)
            return nil
        }
        if nodeId == "145:157" || nodeId == "145:158" {
            return "162:93"
        }
        if nodeId == "145:163" || nodeId == "145:164" {
            settingsCoachVoiceIndex = (settingsCoachVoiceIndex + 1) % Self.settingsCoachVoiceOptions.count
            return nil
        }
        if nodeId == "145:168" || nodeId == "145:169" {
            settingsExplanationStyleIndex = (settingsExplanationStyleIndex + 1) % Self.settingsExplanationStyleOptions.count
            return nil
        }

        // 11. Onboarding (132:264, 132:339, 132:438, 132:519, 132:581)
        let ob02Cards = ["132:301", "132:310", "132:319", "132:327"]
        if ob02Cards.contains(nodeId) {
            toggleOnboardingMultiCard(nodeId, inScreen: "132:264")
            return nil
        }
        let ob03ACardToTrack: [String: String] = [
            "132:379": "AZ-104",
            "132:396": "SAA-C03",
            "132:406": "GH-300",
            "132:416": "AZ-900"
        ]
        if let trackCode = ob03ACardToTrack[nodeId] {
            toggleOnboardingMultiCard(nodeId, inScreen: "132:339")
            coordinator.parallelTracksPreference.toggleParallelTrack(trackCode)
            activeRouteCode = coordinator.parallelTracksPreference.activeTrackCode
            return nil
        }
        let ob03BCardToAITrack: [String: String] = [
            "132:452": "AI-CLAUDE",
            "132:463": "AI-FOUNDRY",
            "132:474": "AI-OPENAI"
        ]
        if let aiCode = ob03BCardToAITrack[nodeId] {
            toggleOnboardingMultiCard(nodeId, inScreen: "132:438")
            coordinator.parallelTracksPreference.toggleAIFrontierTrack(aiCode)
            return nil
        }
        let ob04LevelCards = ["132:531", "132:539", "132:548"]
        if ob04LevelCards.contains(nodeId) {
            var current = onboardingSelectedNodeIdsByScreen["132:519"] ?? ["132:539", "132:562"]
            for id in ob04LevelCards { current.remove(id) }
            current.insert(nodeId)
            onboardingSelectedNodeIdsByScreen["132:519"] = current
            return nil
        }
        let ob04DeadlineCards = ["132:557", "132:562", "132:567", "132:572"]
        if ob04DeadlineCards.contains(nodeId) {
            var current = onboardingSelectedNodeIdsByScreen["132:519"] ?? ["132:539", "132:562"]
            for id in ob04DeadlineCards { current.remove(id) }
            current.insert(nodeId)
            onboardingSelectedNodeIdsByScreen["132:519"] = current
            return nil
        }
        let ob06ARhythmCards = ["132:594", "132:600", "132:606"]
        if ob06ARhythmCards.contains(nodeId) {
            onboardingSelectedNodeIdsByScreen["132:581"] = [nodeId]
            return nil
        }
        if nodeId == "132:645" || nodeId == "132:646" {
            onboardingReminderTimeIndex = (onboardingReminderTimeIndex + 1) % Self.onboardingReminderTimeOptions.count
            return nil
        }

        return nil
    }

    public mutating func submitAIPrompt(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "78:332" }
        aiCustomPromptText = trimmed
        aiActiveTopicId = "custom"
        isAIResponseCopied = false
        return "78:332"
    }

    private mutating func toggleOnboardingMultiCard(_ nodeId: String, inScreen screenId: String) {
        var set = onboardingSelectedNodeIdsByScreen[screenId] ?? []
        if set.contains(nodeId) {
            if set.count > 1 {
                set.remove(nodeId)
            }
        } else {
            set.insert(nodeId)
        }
        onboardingSelectedNodeIdsByScreen[screenId] = set
    }

    public static let keyboardLetterByNodeId: [String: String] = [
        "73:618": "A", "73:622": "Z", "73:626": "E", "73:630": "R", "73:634": "T",
        "73:638": "Y", "73:642": "U", "73:646": "I", "73:650": "O", "73:654": "P",
        "73:658": "Q", "73:662": "S", "73:666": "D", "73:670": "F", "73:674": "G",
        "73:678": "H", "73:682": "J", "73:686": "K", "73:690": "L", "73:694": "M",
        "73:702": "W", "73:706": "X", "73:710": "C", "73:714": "V", "73:718": "B", "73:722": "N"
    ]

    // MARK: Live Scene-Graph Transformation (`applyingLiveState(to:)`)

    public func applyingLiveState(
        to rootNode: CertiGoFigmaSceneNode,
        additionalParallelTracksCount: Int = 2
    ) -> CertiGoFigmaSceneNode {
        let screenId = rootNode.i
        var transformed = rootNode.mapAllNodes { node in
            transformNode(
                node,
                inScreenId: screenId,
                additionalParallelTracksCount: additionalParallelTracksCount
            )
        }

        // Screen-level structural adjustments
        switch screenId {
        case "26:826":
            transformed = applyScreen16GridSelection(to: transformed)
        case "26:863":
            transformed = applyScreen17CLISelection(to: transformed)
        case "145:122":
            transformed = applyScreen28SettingsHitTargets(to: transformed)
        case "162:93":
            transformed = applyScreenRES01BackButton(to: transformed)
        default:
            break
        }

        return transformed
    }

    private func transformNode(
        _ node: CertiGoFigmaSceneNode,
        inScreenId screenId: String,
        additionalParallelTracksCount: Int
    ) -> CertiGoFigmaSceneNode {
        // 1. Global Route Code Badges & Headers
        switch node.i {
        case "37:447", "42:447", "142:423", "151:205":
            return node.updating(w: max(node.w, 72.0), tx: .some("\(activeRouteCode) ▾"))
        case "42:486":
            return node.updating(w: max(node.w, 72.0), tx: .some("\(activeRouteCode) ▴"))
        case "142:416", "151:198":
            return node.updating(w: max(node.w, 225.0), tx: .some("Examens · \(activeRouteCode)"))
        case "142:442", "151:217":
            return node.updating(w: max(node.w, 280.0), tx: .some("S'ENTRAÎNER PAR DOMAINE OFFICIEL \(activeRouteCode)"))
        default:
            break
        }

        // 2. Popover 02 (42:375)
        if screenId == "42:375" {
            if node.i == "42:490" {
                return node.updating(d: .some(nil))
            }
            if let tileVendor = Self.vendorByTileNodeId[node.i] {
                let isSelected = (tileVendor == selectedVendorInPopover.lowercased())
                var updated = node
                    .clearingDescendantDestinations()
                    .updating(
                        f: .some(isSelected ? "#ffffff" : "#f1f5f9"),
                        s: .some(isSelected ? "#0078d4:1.5" : nil),
                        d: .some("act:\(node.i)")
                    )
                if node.i == "42:491" {
                    let label = Self.vendorDisplayNames[selectedVendorInPopover.lowercased()] ?? "Microsoft"
                    let children = (updated.c ?? []).map { child in
                        child.i == "42:497" ? child.updating(w: 66.0, tx: .some(label)) : child
                    }
                    updated = updated.updating(c: .some(children))
                }
                return updated
            }
            if ["42:522", "42:532", "42:540"].contains(node.i) {
                let cards = currentPopoverCards
                let index = (node.i == "42:522") ? 0 : (node.i == "42:532" ? 1 : 2)
                guard index < cards.count else { return node }
                let item = cards[index]
                let matchesAny = cards.contains { $0.code == activeRouteCode }
                let isSelected = (item.code == activeRouteCode) || (!matchesAny && index == 0)

                var children = (node.c ?? []).filter { $0.i != "42:530" }
                children = children.map { child in
                    if ["42:528", "42:538", "42:546"].contains(child.i) {
                        return child.updating(w: 96.0, tx: .some(item.code))
                    }
                    if ["42:529", "42:539", "42:547"].contains(child.i) {
                        return child.updating(w: 176.0, tx: .some(item.title))
                    }
                    return child
                }
                if isSelected {
                    let checkBadge = CertiGoFigmaSceneNode(
                        i: "42:530",
                        n: "Frame",
                        t: "F",
                        x: 232,
                        y: 13,
                        w: 24,
                        h: 24,
                        f: "#0078d4",
                        r: 12,
                        c: [
                            CertiGoFigmaSceneNode(
                                i: "42:531",
                                n: "✓",
                                t: "T",
                                x: 7,
                                y: 3,
                                w: 10,
                                h: 16,
                                f: "#ffffff",
                                tx: "✓",
                                fs: 13,
                                fw: "Black",
                                al: "C",
                                va: "C"
                            )
                        ]
                    )
                    children.append(checkBadge)
                }
                return node
                    .updating(
                        f: .some(isSelected ? "#eff6ff" : "#f8fafc"),
                        s: .some(isSelected ? "#0078d4:2" : "#e2e8f0:1"),
                        d: .some("act:\(node.i)"),
                        c: .some(children)
                    )
            }
        }

        // 3. Single-choice QCM Option Cards (73:332, 73:393, 73:442, 73:509, 73:898, 73:1019)
        if let options = Self.singleSelectOptionGroupsByScreen[screenId],
           screenId != "26:826",
           options.contains(node.i)
        {
            let isSelected = isOptionSelected(node.i, inScreen: screenId)
            return Self.style3DCardNode(
                node,
                isSelected: isSelected,
                actionId: "act:\(node.i)"
            )
        }

        // 4. Multi-select Checkbox Cards on Q_TYPE_10 (73:1070)
        if screenId == "73:1070", ["73:1095", "73:1101", "73:1107", "73:1112"].contains(node.i) {
            let isSelected = isOptionSelected(node.i, inScreen: "73:1070")
            return Self.styleCheckbox3DCardNode(
                node,
                isSelected: isSelected,
                actionId: "act:\(node.i)"
            )
        }

        // 5. Word Bank Bricks on Q_TYPE_05 (73:743)
        if screenId == "73:743",
           let bricks = Self.multiSelectOptionGroupsByScreen["73:743"],
           bricks.contains(node.i)
        {
            let isSelected = isOptionSelected(node.i, inScreen: "73:743")
            return Self.style3DCardNode(
                node,
                isSelected: isSelected,
                actionId: "act:\(node.i)"
            )
        }

        // 6. Matching Pairs on Q_TYPE_06 (73:818)
        if screenId == "73:818",
           ["73:842", "73:851", "73:860", "73:869", "73:877", "73:881", "73:885", "73:889"].contains(node.i)
        {
            let isActive = isOptionSelected(node.i, inScreen: "73:818") || (qType06PendingLeftNodeId == node.i)
            let isPaired = qType06PairedRightByLeftNodeId.keys.contains(node.i)
                || qType06PairedRightByLeftNodeId.values.contains(node.i)
            if isActive {
                return Self.style3DCardNode(node, isSelected: true, actionId: "act:\(node.i)")
            } else if isPaired {
                return Self.style3DCardNode(
                    node,
                    isSelected: true,
                    actionId: "act:\(node.i)",
                    selectedLipHex: "#22c55e",
                    selectedFaceHex: "#dcfce7",
                    selectedStrokeSpec: "#86efac:1.8",
                    selectedTextHex: "#15803d"
                )
            } else {
                return Self.style3DCardNode(node, isSelected: false, actionId: "act:\(node.i)")
            }
        }

        // 7. Scope Ordering on Q_TYPE_08 (73:958)
        if screenId == "73:958", ["73:982", "73:990", "73:998", "73:1006"].contains(node.i) {
            let slotIds = ["73:982", "73:990", "73:998", "73:1006"]
            let slotIndex = slotIds.firstIndex(of: node.i) ?? 0
            let orderedId = slotIndex < qType08OrderedRowNodeIds.count ? qType08OrderedRowNodeIds[slotIndex] : node.i
            let itemText = Self.qType08ItemsByOriginalRowId[orderedId] ?? ("Groupe d'administration", "Management Group (Multi-abonnements)")
            let isSelected = (qType08SelectedRowNodeId == node.i)
            var styled = Self.style3DCardNode(node, isSelected: isSelected, actionId: "act:\(node.i)")
            if var children = styled.c, children.count >= 2, var faceChildren = children[1].c {
                faceChildren = faceChildren.map { child in
                    if ["73:987", "73:995", "73:1003", "73:1011"].contains(child.i) {
                        return child.updating(w: 235.0, tx: .some(itemText.title))
                    }
                    if ["73:988", "73:996", "73:1004", "73:1012"].contains(child.i) {
                        return child.updating(w: 235.0, f: .some("#64748b"), tx: .some(itemText.subtitle))
                    }
                    if ["73:989", "73:997", "73:1005", "73:1013"].contains(child.i) {
                        return child.updating(f: .some("#94a3b8"))
                    }
                    return child
                }
                children[1] = children[1].updating(c: .some(faceChildren))
                styled = styled.updating(c: .some(children))
            }
            return styled
        }

        // 8. iOS Keyboard & CLI Input on Q_TYPE_04 (73:575)
        if screenId == "73:575" {
            if node.i == "73:603" {
                return node.updating(w: 110.0, tx: .some(qType04InputText))
            }
            if node.i == "73:604" {
                let cursorX = min(118.0, 16.0 + Double(qType04InputText.count) * 9.5)
                return node.updating(x: cursorX)
            }
            if ["73:613", "73:615", "73:617", "73:726", "73:734", "73:738"].contains(node.i)
                || Self.keyboardLetterByNodeId[node.i] != nil
            {
                return node.clearingDescendantDestinations().updating(d: .some("act:\(node.i)"))
            }
        }

        // 9. Hub IA Vivant (79:332, 78:332, 81:345, 85:317)
        if screenId == "79:332", ["79:352", "79:356", "79:360", "79:364"].contains(node.i) {
            return node.clearingDescendantDestinations().updating(d: .some("act:\(node.i)"))
        }
        if screenId == "78:332" {
            let payload = currentAITopicPayload
            switch node.i {
            case "78:348":
                return node.updating(tx: .some(payload.question))
            case "78:357":
                return node.updating(tx: .some(payload.intro))
            case "78:358":
                return node.updating(tx: .some(payload.bullet1))
            case "78:359":
                return node.updating(tx: .some(payload.bullet2))
            case "78:361":
                return node.updating(tx: .some(payload.examHeader))
            case "78:362":
                return node.updating(tx: .some(payload.examRule1))
            case "78:363":
                return node.updating(tx: .some(payload.examRule2))
            case "78:365":
                return node.updating(tx: .some(payload.closing))
            case "78:366":
                var updated = node
                    .clearingDescendantDestinations()
                    .updating(
                        f: .some(isAIResponseCopied ? "#dcfce7" : "#f0f4f9"),
                        s: .some(isAIResponseCopied ? "#22c55e:1.5" : nil),
                        d: .some("act:78:366")
                    )
                if let children = updated.c {
                    let mapped = children.map { child in
                        if child.i == "78:370" {
                            return child.updating(
                                x: isAIResponseCopied ? 16 : 34,
                                w: isAIResponseCopied ? 64 : 39,
                                f: .some(isAIResponseCopied ? "#15803d" : "#1f2937"),
                                tx: .some(isAIResponseCopied ? "✓ Copié" : "Copier")
                            )
                        }
                        return child
                    }
                    updated = updated.updating(c: .some(mapped))
                }
                return updated
            default:
                break
            }
        }
        if screenId == "81:345" {
            if node.i == "81:365" {
                return node
                    .clearingDescendantDestinations()
                    .updating(
                        f: .some(isVoiceLiveListening ? "#eff6ff" : "#fef3c7"),
                        s: .some(isVoiceLiveListening ? "#93c5fd:1.8" : "#f59e0b:1.8"),
                        d: .some("act:81:365")
                    )
            }
            if node.i == "81:358", !isVoiceLiveListening {
                return node.updating(tx: .some("⏸ Écoute vocale en pause — touche le micro central pour reprendre"))
            }
        }
        if screenId == "85:317" {
            if ["85:378", "85:380", "85:383", "85:387", "85:388", "85:392", "85:393", "85:394", "85:395"].contains(node.i) {
                return node.clearingDescendantDestinations().updating(d: .some("act:\(node.i)"))
            }
        }

        // 10. Cockpit Examen Blanc 23 (142:478)
        if screenId == "142:478" {
            let qPayload = currentMockExamQuestionPayload
            if node.i == "142:487" {
                let flagged = isCurrentExamQuestionFlagged
                let children = (node.c ?? []).map { child in
                    child.i == "142:488"
                        ? child.updating(
                            f: .some("#b45309"),
                            tx: .some(flagged ? "🏳 Marquée ✓" : "🏳 Marquer")
                        )
                        : child
                }
                return node.updating(
                    f: .some(flagged ? "#fef3c7" : "#fffbeb"),
                    s: .some(flagged ? "#f59e0b:2" : "#fcd34d:1.5"),
                    d: .some("act:142:487"),
                    c: .some(children)
                )
            }
            let pillNumberMap: [String: (num: Int, textId: String)] = [
                "142:490": (12, "142:491"),
                "142:492": (13, "142:493"),
                "142:494": (14, "142:495"),
                "142:496": (15, "142:497"),
                "142:498": (16, "142:499"),
                "142:500": (17, "142:501")
            ]
            if let pillInfo = pillNumberMap[node.i] {
                let isCurrent = (pillInfo.num == examCurrentQuestionNumber)
                let isFlagged = examFlaggedQuestions.contains(pillInfo.num)
                let isAnswered = examSelectedOptionByQuestion[pillInfo.num] != nil
                let fillHex: String = isCurrent ? "#2563eb" : (isFlagged ? "#fef3c7" : (isAnswered ? "#dcfce7" : "#f1f5f9"))
                let textHex: String = isCurrent ? "#ffffff" : (isFlagged ? "#b45309" : (isAnswered ? "#15803d" : "#64748b"))
                let label: String = isCurrent
                    ? "\(pillInfo.num) / 50"
                    : (isFlagged ? "\(pillInfo.num) 🏳" : (isAnswered ? "\(pillInfo.num) ✓" : "\(pillInfo.num)"))
                let children = (node.c ?? []).map { child in
                    child.i == pillInfo.textId ? child.updating(f: .some(textHex), tx: .some(label)) : child
                }
                return node.updating(f: .some(fillHex), d: .some("act:\(node.i)"), c: .some(children))
            }
            if node.i == "142:506" {
                return node.updating(w: 202.0, tx: .some(qPayload.badge))
            }
            if node.i == "142:507" {
                return node.updating(tx: .some(qPayload.stem))
            }
            if ["142:508", "142:514", "142:520", "142:526"].contains(node.i) {
                let isSelected = (currentExamSelectedOptionNodeId == node.i)
                let optionText: String = {
                    switch node.i {
                    case "142:508": return qPayload.optionA
                    case "142:514": return qPayload.optionB
                    case "142:520": return qPayload.optionC
                    default: return qPayload.optionD
                    }
                }()
                return Self.styleExamOptionCardNode(
                    node,
                    isSelected: isSelected,
                    optionText: optionText,
                    actionId: "act:\(node.i)"
                )
            }
            if node.i == "142:532" || node.i == "142:536" {
                return node.clearingDescendantDestinations().updating(d: .some("act:\(node.i)"))
            }
        }

        // 11. Carrousel Rapport /1000 sur Écran 24 (142:540)
        if screenId == "142:540" {
            let idx = examReportCarouselIndex % 3
            if node.i == "142:573" {
                return node.clearingDescendantDestinations().updating(d: .some("act:142:573"))
            }
            if node.i == "142:585" {
                return node.updating(
                    x: 14,
                    w: idx == 0 ? 16 : 8,
                    f: .some(idx == 0 ? "#2563eb" : "#cbd5e1"),
                    d: .some("act:142:585")
                )
            }
            if node.i == "142:586" {
                return node.updating(
                    x: idx == 0 ? 36 : 28,
                    w: idx == 1 ? 16 : 8,
                    f: .some(idx == 1 ? "#2563eb" : "#cbd5e1"),
                    d: .some("act:142:586")
                )
            }
            if node.i == "142:587" {
                return node.updating(
                    x: idx == 2 ? 42 : 50,
                    w: idx == 2 ? 16 : 8,
                    f: .some(idx == 2 ? "#2563eb" : "#cbd5e1"),
                    d: .some("act:142:587")
                )
            }
            if idx == 1 {
                switch node.i {
                case "142:550":
                    return node.updating(tx: .some("⏱ RYTHME CHRONO & CALIBRATION PEARSON VUE"))
                case "142:559":
                    return node.updating(w: 112.0, tx: .some("38m"))
                case "142:560":
                    return node.updating(x: 128.0, tx: .some("/ 90m"))
                case "142:562":
                    return node.updating(tx: .some("⚡ 45s / question"))
                case "142:564":
                    return node.updating(tx: .some("GESTION DU TEMPS PAR BLOC D'EXAMEN (90 MIN)"))
                case "142:576":
                    return node.updating(tx: .some("✓ 92 % Calibré"))
                case "142:579":
                    return node.updating(tx: .some("🏳 3 Marquées"))
                case "142:582":
                    return node.updating(tx: .some("🎯 52m marge"))
                default:
                    break
                }
            } else if idx == 2 {
                switch node.i {
                case "142:550":
                    return node.updating(tx: .some("🎯 ANALYSE DES 11 ERREURS & RELANCE COACH IA"))
                case "142:559":
                    return node.updating(w: 112.0, tx: .some("11"))
                case "142:560":
                    return node.updating(x: 84.0, w: 68.0, tx: .some("erreurs"))
                case "142:562":
                    return node.updating(tx: .some("✦ Priorité DNS & VNet"))
                case "142:564":
                    return node.updating(tx: .some("3 PIÈGES IDENTIFIÉS : PRIVATE DNS · VERROUS · NSG"))
                case "142:576":
                    return node.updating(tx: .some("1. Private DNS"))
                case "142:579":
                    return node.updating(tx: .some("2. Verrou RG"))
                case "142:582":
                    return node.updating(tx: .some("3. NSG L4/L7"))
                default:
                    break
                }
            }
        }

        // 12. Social 25 (89:317)
        if screenId == "89:317" {
            if ["89:493", "89:504", "89:515", "89:526", "89:537"].contains(node.i) {
                let isSaluted = isFriendSaluted(node.i)
                var children = node.c ?? []
                if children.count >= 2 {
                    children[0] = children[0].updating(f: .some(isSaluted ? "#16a34a" : "#e5e5e5"))
                    var faceChildren = children[1].c ?? []
                    faceChildren = faceChildren.map { child in
                        if child.t == "T" {
                            return child.updating(
                                f: .some(isSaluted ? "#15803d" : "#0078d4"),
                                tx: .some(isSaluted ? "👏 Salué ✓" : "👋 Salut")
                            )
                        }
                        return child
                    }
                    children[1] = children[1].updating(
                        f: .some(isSaluted ? "#dcfce7" : "#f8fafc"),
                        s: .some(isSaluted ? "#22c55e:1.8" : "#e5e5e5:1.8"),
                        c: .some(faceChildren)
                    )
                }
                return node
                    .clearingDescendantDestinations()
                    .updating(d: .some("act:\(node.i)"), c: .some(children))
            }
            if node.i == "89:480" {
                return node.clearingDescendantDestinations().updating(d: .some("act:89:480"))
            }
            if node.i == "89:484", isFriendInviteCopied {
                return node.updating(x: 278, w: 58, f: .some("#15803d"), tx: .some("✓ Copié"))
            }
        }

        // 13. Profil 08 (97:287), Détail Certif 26 (97:417), PRO 27 (144:137) & Paramètres 28 (145:122)
        if screenId == "97:287", ["97:336", "97:355", "97:374", "97:382"].contains(node.i) {
            return node.clearingDescendantDestinations().updating(d: .some("act:\(node.i)"))
        }
        if screenId == "97:417" {
            let detail = Self.profileCertificationDetail(forCode: selectedProfileCertificationCode)
            switch node.i {
            case "98:304":
                if let imgFill = detail.crestImageFill {
                    return node.updating(f: .some(imgFill), c: .some([]))
                }
                return node
            case "97:438":
                return node.updating(tx: .some(detail.badge))
            case "97:439":
                return node.updating(tx: .some(detail.title))
            case "97:442":
                return node.updating(tx: .some(detail.progression))
            case "97:445":
                return node.updating(tx: .some(detail.lastMockExam))
            case "97:448":
                return node.updating(w: 265.0, tx: .some(detail.domains[0].title))
            case "97:449":
                return node.updating(f: .some(detail.domains[0].colorHex), tx: .some(detail.domains[0].percentText))
            case "97:451":
                return node.updating(w: detail.domains[0].barWidth, f: .some(detail.domains[0].colorHex))
            case "97:453":
                return node.updating(w: 265.0, tx: .some(detail.domains[1].title))
            case "97:454":
                return node.updating(f: .some(detail.domains[1].colorHex), tx: .some(detail.domains[1].percentText))
            case "97:456":
                return node.updating(w: detail.domains[1].barWidth, f: .some(detail.domains[1].colorHex))
            case "97:458":
                return node.updating(w: 265.0, tx: .some(detail.domains[2].title))
            case "97:459":
                return node.updating(f: .some(detail.domains[2].colorHex), tx: .some(detail.domains[2].percentText))
            case "97:461":
                return node.updating(w: detail.domains[2].barWidth, f: .some(detail.domains[2].colorHex))
            case "97:463":
                return node.updating(w: 265.0, tx: .some(detail.domains[3].title))
            case "97:464":
                return node.updating(f: .some(detail.domains[3].colorHex), tx: .some(detail.domains[3].percentText))
            case "97:466":
                return node.updating(w: detail.domains[3].barWidth, f: .some(detail.domains[3].colorHex))
            default:
                break
            }
        }
        if screenId == "144:137" {
            if node.i == "144:179" || node.i == "144:187" {
                let isSelected = (selectedProPlanNodeId == node.i)
                var children = node.c ?? []
                if children.count >= 2 {
                    children[0] = children[0].updating(f: .some(isSelected ? "#2563eb" : "#cbd5e1"))
                    children[1] = children[1].updating(
                        f: .some(isSelected ? "#eff6ff" : "#ffffff"),
                        s: .some(isSelected ? "#3b82f6:2" : "#e2e8f0:2")
                    )
                }
                return node.clearingDescendantDestinations().updating(
                    d: .some("act:\(node.i)"),
                    c: .some(children)
                )
            }
            if node.i == "144:195" {
                return node.clearingDescendantDestinations().updating(d: .some("act:144:195"))
            }
        }
        if screenId == "145:122" {
            switch node.i {
            case "145:141":
                let summary = additionalParallelTracksCount > 0
                    ? "\(activeRouteCode) + \(additionalParallelTracksCount)  ›"
                    : "\(activeRouteCode)  ›"
                return node.updating(tx: .some(summary))
            case "145:147":
                return node.updating(tx: .some(currentSettingsLanguageLabel))
            case "145:153":
                return node.updating(tx: .some(currentSettingsExamModeLabel))
            case "145:164":
                return node.updating(tx: .some(currentSettingsCoachVoiceLabel))
            case "145:169":
                return node.updating(tx: .some(currentSettingsExplanationStyleLabel))
            case "145:174", "145:181", "145:187", "145:193":
                let isOn = isSettingsToggleOn(node.i)
                let children = (node.c ?? []).map { thumb in
                    thumb.updating(x: isOn ? 22.0 : 2.0)
                }
                return node.updating(
                    f: .some(isOn ? "#22c55e" : "#cbd5e1"),
                    d: .some("act:\(node.i)"),
                    c: .some(children)
                )
            default:
                break
            }
        }

        // 14. Onboarding Choice Cards (132:264, 132:339, 132:438, 132:519, 132:581)
        if screenId == "132:264" {
            if ["132:301", "132:310", "132:319", "132:327"].contains(node.i) {
                let isSelected = onboardingSelectedNodeIdsByScreen["132:264"]?.contains(node.i) ?? false
                return Self.styleOnboardingCardNode(node, isSelected: isSelected, actionId: "act:\(node.i)")
            }
            if node.i == "132:338" {
                let count = max(1, onboardingSelectedNodeIdsByScreen["132:264"]?.count ?? 2)
                let label = count > 1
                    ? "CONTINUER (\(count) OBJECTIFS CHOISIS)"
                    : "CONTINUER (1 OBJECTIF CHOISI)"
                return node.updating(tx: .some(label))
            }
        }
        if screenId == "132:339" {
            if ["132:379", "132:396", "132:406", "132:416"].contains(node.i) {
                let isSelected = onboardingSelectedNodeIdsByScreen["132:339"]?.contains(node.i) ?? false
                return Self.styleOnboardingCardNode(node, isSelected: isSelected, actionId: "act:\(node.i)")
            }
            if node.i == "132:437" {
                let count = max(1, onboardingSelectedNodeIdsByScreen["132:339"]?.count ?? 3)
                return node.updating(tx: .some("SUIVRE CES \(count) PARCOURS  →"))
            }
        }
        if screenId == "132:438", ["132:452", "132:463", "132:474"].contains(node.i) {
            let isSelected = onboardingSelectedNodeIdsByScreen["132:438"]?.contains(node.i) ?? false
            return Self.styleOnboardingCardNode(
                node,
                isSelected: isSelected,
                actionId: "act:\(node.i)",
                accentHex: "#7c3aed",
                faceHex: "#ffffff",
                strokeSpec: "#c4b5fd:2"
            )
        }
        if screenId == "132:519" {
            if ["132:531", "132:539", "132:548"].contains(node.i) {
                let isSelected = onboardingSelectedNodeIdsByScreen["132:519"]?.contains(node.i) ?? false
                return Self.styleOnboardingCardNode(node, isSelected: isSelected, actionId: "act:\(node.i)")
            }
            if ["132:557", "132:562", "132:567", "132:572"].contains(node.i) {
                let isSelected = onboardingSelectedNodeIdsByScreen["132:519"]?.contains(node.i) ?? false
                return Self.style3DCardNode(
                    node,
                    isSelected: isSelected,
                    actionId: "act:\(node.i)",
                    selectedLipHex: "#2563eb",
                    selectedFaceHex: "#eff6ff",
                    selectedStrokeSpec: "#3b82f6:2",
                    selectedTextHex: "#1d4ed8"
                )
            }
        }
        if screenId == "132:581" {
            if ["132:594", "132:600", "132:606"].contains(node.i) {
                let isSelected = onboardingSelectedNodeIdsByScreen["132:581"]?.contains(node.i) ?? false
                return Self.style3DCardNode(
                    node,
                    isSelected: isSelected,
                    actionId: "act:\(node.i)",
                    selectedLipHex: "#2563eb",
                    selectedFaceHex: "#eff6ff",
                    selectedStrokeSpec: "#3b82f6:2",
                    selectedTextHex: "#1d4ed8"
                )
            }
            if node.i == "132:645" {
                return node.updating(d: .some("act:132:645"))
            }
            if node.i == "132:646" {
                let timeLabel = Self.onboardingReminderTimeOptions[
                    onboardingReminderTimeIndex % Self.onboardingReminderTimeOptions.count
                ]
                return node.updating(tx: .some(timeLabel))
            }
        }

        return node
    }

    // MARK: Screen-Level Helpers

    private static let qType08ItemsByOriginalRowId: [String: (title: String, subtitle: String)] = [
        "73:982": ("Groupe d'administration", "Management Group (Multi-abonnements)"),
        "73:990": ("Abonnement (Subscription)", "Facturation & limites globales"),
        "73:998": ("Groupe de ressources", "Conteneur logique de cycle de vie"),
        "73:1006": ("Ressource individuelle", "Ex. Machine virtuelle, Key Vault, VNet")
    ]

    private func applyScreen16GridSelection(to root: CertiGoFigmaSceneNode) -> CertiGoFigmaSceneNode {
        let pairs: [(lipId: String, faceId: String)] = [
            ("26:836", "26:837"),
            ("26:842", "26:843"),
            ("26:848", "26:849"),
            ("26:854", "26:855")
        ]
        let lipToFace = Dictionary(uniqueKeysWithValues: pairs.map { ($0.lipId, $0.faceId) })
        let faceSet = Set(pairs.map(\.faceId))
        let children = (root.c ?? []).map { child -> CertiGoFigmaSceneNode in
            if let faceId = lipToFace[child.i] {
                let isSelected = isOptionSelected(faceId, inScreen: "26:826")
                return child.updating(f: .some(isSelected ? "#1cb0f6" : "#e5e5e5"))
            }
            if faceSet.contains(child.i) {
                let isSelected = isOptionSelected(child.i, inScreen: "26:826")
                let faceChildren = (child.c ?? []).map { sub in
                    sub.t == "T" ? sub.updating(f: .some(isSelected ? "#1899d6" : "#334155")) : sub
                }
                return child.clearingDescendantDestinations().updating(
                    f: .some(isSelected ? "#ddf4ff" : "#ffffff"),
                    s: .some(isSelected ? "#84d8ff:1.8" : "#e5e5e5:1.8"),
                    d: .some("act:\(child.i)"),
                    c: .some(faceChildren)
                )
            }
            return child
        }
        return root.updating(c: .some(children))
    }

    private func applyScreen17CLISelection(to root: CertiGoFigmaSceneNode) -> CertiGoFigmaSceneNode {
        let pairs: [(lipId: String, faceId: String)] = [
            ("26:875", "26:876"),
            ("26:878", "26:879"),
            ("26:881", "26:882"),
            ("26:884", "26:885")
        ]
        let lipToFace = Dictionary(uniqueKeysWithValues: pairs.map { ($0.lipId, $0.faceId) })
        let faceSet = Set(pairs.map(\.faceId))
        let children = (root.c ?? []).map { child -> CertiGoFigmaSceneNode in
            if let faceId = lipToFace[child.i] {
                let isSelected = isOptionSelected(faceId, inScreen: "26:863")
                return child.updating(f: .some(isSelected ? "#1cb0f6" : "#e5e5e5"))
            }
            if faceSet.contains(child.i) {
                let isSelected = isOptionSelected(child.i, inScreen: "26:863")
                let faceChildren = (child.c ?? []).map { sub in
                    sub.t == "T" ? sub.updating(f: .some(isSelected ? "#1899d6" : "#334155")) : sub
                }
                return child.clearingDescendantDestinations().updating(
                    f: .some(isSelected ? "#ddf4ff" : "#ffffff"),
                    s: .some(isSelected ? "#84d8ff:1.8" : "#e5e5e5:1.8"),
                    d: .some("act:\(child.i)"),
                    c: .some(faceChildren)
                )
            }
            return child
        }
        return root.updating(c: .some(children))
    }

    private func applyScreen28SettingsHitTargets(to root: CertiGoFigmaSceneNode) -> CertiGoFigmaSceneNode {
        let children = (root.c ?? []).map { child -> CertiGoFigmaSceneNode in
            if child.i == "145:137" {
                var sub = child.c ?? []
                sub.append(contentsOf: [
                    Self.transparentHitRow(id: "145:137-row0", y: 0, h: 50, destination: "132:339"),
                    Self.transparentHitRow(id: "145:137-row1", y: 50, h: 50, destination: "act:145:146"),
                    Self.transparentHitRow(id: "145:137-row2", y: 100, h: 50, destination: "act:145:152"),
                    Self.transparentHitRow(id: "145:137-row3", y: 150, h: 50, destination: "162:93")
                ])
                return child.updating(d: .some(nil), c: .some(sub))
            }
            if child.i == "145:160" {
                var sub = child.c ?? []
                sub.append(contentsOf: [
                    Self.transparentHitRow(id: "145:160-row0", y: 0, h: 50, destination: "act:145:163"),
                    Self.transparentHitRow(id: "145:160-row1", y: 50, h: 50, destination: "act:145:168"),
                    Self.transparentHitRow(id: "145:160-row2", y: 100, h: 50, destination: "act:145:174")
                ])
                return child.updating(d: .some(nil), c: .some(sub))
            }
            if child.i == "145:177" {
                var sub = child.c ?? []
                sub.append(contentsOf: [
                    Self.transparentHitRow(id: "145:177-row0", y: 0, h: 50, destination: "act:145:181"),
                    Self.transparentHitRow(id: "145:177-row1", y: 50, h: 50, destination: "act:145:187"),
                    Self.transparentHitRow(id: "145:177-row2", y: 100, h: 50, destination: "act:145:193")
                ])
                return child.updating(d: .some(nil), c: .some(sub))
            }
            return child
        }
        return root.updating(c: .some(children))
    }

    private func applyScreenRES01BackButton(to root: CertiGoFigmaSceneNode) -> CertiGoFigmaSceneNode {
        var children = (root.c ?? []).map { child -> CertiGoFigmaSceneNode in
            if child.i == "162:99" {
                let inner = (child.c ?? []).map { sub in
                    sub.i == "162:102" ? sub.updating(d: .some("73:393")) : sub
                }
                return child.updating(c: .some(inner))
            }
            return child
        }
        let backButton = CertiGoFigmaSceneNode(
            i: "162:93-back-settings",
            n: "BackToSettings",
            t: "F",
            x: 20,
            y: 780,
            w: 353,
            h: 44,
            f: "#ffffff",
            s: "#cbd5e1:1.5",
            r: 14,
            d: "145:122",
            c: [
                CertiGoFigmaSceneNode(
                    i: "162:93-back-settings-tx",
                    n: "← Retour aux Paramètres",
                    t: "T",
                    x: 0,
                    y: 12,
                    w: 353,
                    h: 18,
                    f: "#0f172a",
                    tx: "←  Retour aux Paramètres",
                    fs: 14,
                    fw: "Bold",
                    al: "C",
                    va: "C"
                )
            ]
        )
        children.append(backButton)
        return root.updating(c: .some(children))
    }

    private static func transparentHitRow(
        id: String,
        y: Double,
        h: Double,
        destination: String
    ) -> CertiGoFigmaSceneNode {
        CertiGoFigmaSceneNode(
            i: id,
            n: "HitRow",
            t: "F",
            x: 0,
            y: y,
            w: 357,
            h: h,
            d: destination
        )
    }

    private static func style3DCardNode(
        _ node: CertiGoFigmaSceneNode,
        isSelected: Bool,
        actionId: String,
        selectedLipHex: String = "#1cb0f6",
        selectedFaceHex: String = "#ddf4ff",
        selectedStrokeSpec: String = "#84d8ff:1.8",
        selectedTextHex: String = "#1899d6"
    ) -> CertiGoFigmaSceneNode {
        var children = node.c ?? []
        if children.count >= 2 {
            children[0] = children[0].updating(f: .some(isSelected ? selectedLipHex : "#e5e5e5"))
            let faceChildren = (children[1].c ?? []).map { child -> CertiGoFigmaSceneNode in
                if child.t == "T" {
                    return child.updating(f: .some(isSelected ? selectedTextHex : "#334155"))
                }
                if ["73:926", "73:932", "73:938", "73:944", "73:950", "73:985", "73:993", "73:1001", "73:1009"].contains(child.i) {
                    let badgeChildren = (child.c ?? []).map { sub in
                        sub.t == "T" ? sub.updating(f: .some(isSelected ? "#ffffff" : "#64748b")) : sub
                    }
                    return child.updating(
                        f: .some(isSelected ? selectedLipHex : "#e2e8f0"),
                        c: .some(badgeChildren)
                    )
                }
                return child
            }
            children[1] = children[1].updating(
                f: .some(isSelected ? selectedFaceHex : "#ffffff"),
                s: .some(isSelected ? selectedStrokeSpec : "#e5e5e5:1.8"),
                c: .some(faceChildren)
            )
        }
        return node
            .clearingDescendantDestinations()
            .updating(d: .some(actionId), c: .some(children))
    }

    private static func styleCheckbox3DCardNode(
        _ node: CertiGoFigmaSceneNode,
        isSelected: Bool,
        actionId: String
    ) -> CertiGoFigmaSceneNode {
        var styled = style3DCardNode(node, isSelected: isSelected, actionId: actionId)
        if var children = styled.c, children.count >= 2, var faceChildren = children[1].c {
            faceChildren = faceChildren.map { child in
                guard ["73:1099", "73:1105", "73:1111", "73:1116"].contains(child.i) else {
                    return child
                }
                let checkChild: [CertiGoFigmaSceneNode] = isSelected
                    ? [
                        CertiGoFigmaSceneNode(
                            i: "\(child.i)-check",
                            n: "✓",
                            t: "T",
                            x: 0,
                            y: 4,
                            w: 28,
                            h: 19,
                            f: "#ffffff",
                            tx: "✓",
                            fs: 15,
                            fw: "Black",
                            al: "C",
                            va: "C"
                        )
                    ]
                    : []
                return child.updating(
                    f: .some(isSelected ? "#1cb0f6" : "#ffffff"),
                    s: .some(isSelected ? "#1cb0f6:2" : "#e5e5e5:2"),
                    c: .some(checkChild)
                )
            }
            children[1] = children[1].updating(c: .some(faceChildren))
            styled = styled.updating(c: .some(children))
        }
        return styled
    }

    private static func styleExamOptionCardNode(
        _ node: CertiGoFigmaSceneNode,
        isSelected: Bool,
        optionText: String,
        actionId: String
    ) -> CertiGoFigmaSceneNode {
        var children = node.c ?? []
        if children.count >= 2 {
            children[0] = children[0].updating(f: .some(isSelected ? "#2563eb" : "#cbd5e1"))
            let faceChildren = (children[1].c ?? []).map { child -> CertiGoFigmaSceneNode in
                if child.t == "T" {
                    return child.updating(
                        f: .some(isSelected ? "#1e40af" : "#0f172a"),
                        tx: .some(optionText)
                    )
                }
                if ["142:511", "142:517", "142:523", "142:529"].contains(child.i) {
                    let badgeChildren = (child.c ?? []).map { sub in
                        sub.t == "T" ? sub.updating(f: .some(isSelected ? "#ffffff" : "#475569")) : sub
                    }
                    return child.updating(
                        f: .some(isSelected ? "#2563eb" : "#f1f5f9"),
                        c: .some(badgeChildren)
                    )
                }
                return child
            }
            children[1] = children[1].updating(
                f: .some(isSelected ? "#eff6ff" : "#ffffff"),
                s: .some(isSelected ? "#3b82f6:2" : "#e2e8f0:2"),
                c: .some(faceChildren)
            )
        }
        return node
            .clearingDescendantDestinations()
            .updating(d: .some(actionId), c: .some(children))
    }

    private static func styleOnboardingCardNode(
        _ node: CertiGoFigmaSceneNode,
        isSelected: Bool,
        actionId: String,
        accentHex: String = "#2563eb",
        faceHex: String = "#eff6ff",
        strokeSpec: String = "#3b82f6:2"
    ) -> CertiGoFigmaSceneNode {
        var children = node.c ?? []
        if children.count >= 2 {
            children[0] = children[0].updating(f: .some(isSelected ? accentHex : "#cbd5e1"))
            let faceChildren = (children[1].c ?? []).map { child -> CertiGoFigmaSceneNode in
                if abs(child.w - 24.0) < 0.5 && abs(child.h - 24.0) < 0.5 && child.x >= 300.0 {
                    let checkChildren: [CertiGoFigmaSceneNode] = isSelected
                        ? [
                            CertiGoFigmaSceneNode(
                                i: "\(child.i)-check",
                                n: "✓",
                                t: "T",
                                x: 0,
                                y: 4,
                                w: 24,
                                h: 16,
                                f: "#ffffff",
                                tx: "✓",
                                fs: 13,
                                fw: "Black",
                                al: "C",
                                va: "C"
                            )
                        ]
                        : []
                    return child.updating(
                        f: .some(isSelected ? accentHex : "#ffffff"),
                        s: .some(isSelected ? "\(accentHex):2" : "#cbd5e1:2"),
                        c: .some(checkChildren)
                    )
                }
                return child
            }
            children[1] = children[1].updating(
                f: .some(isSelected ? faceHex : "#ffffff"),
                s: .some(isSelected ? strokeSpec : "#e2e8f0:2"),
                c: .some(faceChildren)
            )
        }
        return node
            .clearingDescendantDestinations()
            .updating(d: .some(actionId), c: .some(children))
    }
}

// MARK: - 4. SwiftUI 1-for-1 Figma Pro Scene-Graph Engine (`CertiGoFigmaSVGPathShape`, `CertiGoFigmaSceneNodeView`, `CertiGoFigmaInteractiveAppView`)

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

public struct CertiGoFigmaSVGPathShape: Shape {
    public let vp: String
    public let scaleX: CGFloat
    public let scaleY: CGFloat

    public init(vp: String, scaleX: CGFloat = 1.0, scaleY: CGFloat = 1.0) {
        self.vp = vp
        self.scaleX = scaleX
        self.scaleY = scaleY
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let commands = CertiGoFigmaSVGCommand.parse(vp)
        for command in commands {
            switch command {
            case .moveTo(let x, let y):
                path.move(to: CGPoint(x: CGFloat(x) * scaleX, y: CGFloat(y) * scaleY))
            case .lineTo(let x, let y):
                path.addLine(to: CGPoint(x: CGFloat(x) * scaleX, y: CGFloat(y) * scaleY))
            case .curveTo(let x1, let y1, let x2, let y2, let x, let y):
                path.addCurve(
                    to: CGPoint(x: CGFloat(x) * scaleX, y: CGFloat(y) * scaleY),
                    control1: CGPoint(x: CGFloat(x1) * scaleX, y: CGFloat(y1) * scaleY),
                    control2: CGPoint(x: CGFloat(x2) * scaleX, y: CGFloat(y2) * scaleY)
                )
            case .closeSubpath:
                path.closeSubpath()
            }
        }
        return path
    }
}

public struct CertiGoFigmaSceneNodeView: View {
    public let node: CertiGoFigmaSceneNode
    public let scaleX: CGFloat
    public let scaleY: CGFloat
    public let isRootScreen: Bool
    public let onNavigateToNodeId: (String) -> Void
    public let onLongPressDiagnosticTrigger: (() -> Void)?

    public init(
        node: CertiGoFigmaSceneNode,
        scaleX: CGFloat = 1.0,
        scaleY: CGFloat = 1.0,
        isRootScreen: Bool = false,
        onNavigateToNodeId: @escaping (String) -> Void = { _ in },
        onLongPressDiagnosticTrigger: (() -> Void)? = nil
    ) {
        self.node = node
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.isRootScreen = isRootScreen
        self.onNavigateToNodeId = onNavigateToNodeId
        self.onLongPressDiagnosticTrigger = onLongPressDiagnosticTrigger
    }

    private var uniformScale: CGFloat {
        min(scaleX, scaleY)
    }

    private var scaledWidth: CGFloat {
        max(CGFloat(node.w) * scaleX, PrismBorder.hairline)
    }

    private var scaledHeight: CGFloat {
        max(CGFloat(node.h) * scaleY, PrismBorder.hairline)
    }

    private var scaledCornerRadius: CGFloat {
        isRootScreen ? 0 : CGFloat(node.r ?? 0) * uniformScale
    }

    private var visibleChildren: [CertiGoFigmaSceneNode] {
        (node.c ?? []).filter { child in
            !child.isFilteredMockupChrome(parentWidth: node.w, parentHeight: node.h)
        }
    }

    private var shouldAttachTapGesture: Bool {
        guard node.d != nil else { return false }
        guard isRootScreen else { return true }
        return !visibleChildren.flatMap(\.allNodes).contains(where: { $0.d != nil })
    }

    private var isDiagnosticLongPressNode: Bool {
        ["37:440", "37:441", "42:479", "142:417", "145:127"].contains(node.i)
    }

    public var body: some View {
        let baseContent = coreNodeContent
            .opacity(node.op ?? 1.0)
            .rotationEffect(.degrees(-(node.rot ?? 0)))

        let shadowedContent: AnyView = {
            if let shSpec = node.sh, let shadow = PrismColor.figmaShadow(shSpec) {
                return AnyView(
                    baseContent.shadow(
                        color: shadow.color,
                        radius: shadow.radius * uniformScale,
                        x: shadow.dx * scaleX,
                        y: shadow.dy * scaleY
                    )
                )
            }
            return AnyView(baseContent)
        }()

        if let destinationNodeId = node.d, shouldAttachTapGesture {
            if isDiagnosticLongPressNode, let onLongPressDiagnosticTrigger {
                shadowedContent
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onNavigateToNodeId(destinationNodeId)
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                            onLongPressDiagnosticTrigger()
                        }
                    )
            } else {
                shadowedContent
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onNavigateToNodeId(destinationNodeId)
                    }
            }
        } else if isDiagnosticLongPressNode, let onLongPressDiagnosticTrigger {
            shadowedContent
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 0.5) {
                    onLongPressDiagnosticTrigger()
                }
        } else {
            shadowedContent
        }
    }

    @ViewBuilder
    private var coreNodeContent: some View {
        let widthVal = scaledWidth
        let heightVal = scaledHeight

        if node.t == "V" {
            vectorContent
                .frame(width: widthVal, height: heightVal)
        } else if node.t == "T" {
            textContent
        } else {
            containerOrShapeContent
                .frame(width: widthVal, height: heightVal)
        }
    }

    @ViewBuilder
    private var vectorContent: some View {
        let shape = CertiGoFigmaSVGPathShape(
            vp: node.vp ?? "",
            scaleX: scaleX,
            scaleY: scaleY
        )
        let fillStyle = FillStyle(eoFill: node.eo == 1)

        ZStack {
            if let fillSpec = node.f {
                if fillSpec.hasPrefix("grad:") {
                    shape.fill(
                        LinearGradient(
                            colors: PrismColor.figmaGradientColors(fillSpec),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: fillStyle
                    )
                } else {
                    shape.fill(
                        PrismColor.figmaHex(fillSpec),
                        style: fillStyle
                    )
                }
            }

            if let strokeSpec = node.s {
                let lineWidth = PrismColor.figmaStrokeWidth(strokeSpec) * uniformScale
                let isDashed = PrismColor.figmaStrokeIsDashed(strokeSpec)
                let dashUnit = PrismSpacing.xs * uniformScale
                let strokeStyle = StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: isDashed ? [dashUnit, dashUnit] : []
                )
                shape.stroke(
                    PrismColor.figmaStrokeColor(strokeSpec),
                    style: strokeStyle
                )
            }
        }
    }

    @ViewBuilder
    private var textContent: some View {
        let rawText = node.tx ?? ""
        let rawFontSize = node.fs ?? 14.0
        let scaledFS = CGFloat(rawFontSize) * uniformScale
        let isSingleLine = !rawText.contains("\n") && node.h < rawFontSize * 1.65
        let expandedTextW = scaledWidth + 6.0 * scaleX
        let heightVal = scaledHeight
        let effectiveTextH = isSingleLine
            ? max(heightVal, scaledFS * 1.25)
            : max(heightVal * 1.15, scaledFS * 2.2)
        let textAlignment: TextAlignment = {
            switch node.al {
            case "C": return .center
            case "R": return .trailing
            default: return .leading
            }
        }()
        let isVerticallyCentered = isSingleLine || node.va == "C"
        let frameAlignment: Alignment = {
            switch node.al {
            case "C": return isVerticallyCentered ? .center : .top
            case "R": return isVerticallyCentered ? .trailing : .topTrailing
            default: return isVerticallyCentered ? .leading : .topLeading
            }
        }()

        Text(verbatim: rawText)
            .font(
                PrismTypography.figmaFont(
                    size: scaledFS,
                    style: node.fw,
                    monospaced: node.mo == 1
                )
            )
            .foregroundStyle(PrismColor.figmaHex(node.f ?? "#0f172a"))
            .multilineTextAlignment(textAlignment)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .lineLimit(isSingleLine ? 1 : nil)
            .frame(width: expandedTextW, height: effectiveTextH, alignment: frameAlignment)
    }

    @ViewBuilder
    private var containerOrShapeContent: some View {
        let widthVal = scaledWidth
        let heightVal = scaledHeight
        let radiusVal = scaledCornerRadius
        let children = visibleChildren

        let stack = ZStack(alignment: .topLeading) {
            Color.clear
                .frame(width: widthVal, height: heightVal)

            if let assetName = node.resolvedImageAssetName {
                Image(assetName, bundle: .module)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: widthVal, height: heightVal)
            } else if let fillSpec = node.f {
                if fillSpec.hasPrefix("grad:") {
                    RoundedRectangle(cornerRadius: radiusVal, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: PrismColor.figmaGradientColors(fillSpec),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: widthVal, height: heightVal)
                } else {
                    RoundedRectangle(cornerRadius: radiusVal, style: .continuous)
                        .fill(PrismColor.figmaHex(fillSpec))
                        .frame(width: widthVal, height: heightVal)
                }
            }

            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                let childW = max(CGFloat(child.w) * scaleX, PrismBorder.hairline)
                let childH = max(CGFloat(child.h) * scaleY, PrismBorder.hairline)
                let childCenterX = (CGFloat(child.x) + CGFloat(child.w) * 0.5) * scaleX
                let childCenterY = (CGFloat(child.y) + CGFloat(child.h) * 0.5) * scaleY
                let childIsTopAlignedMultilineText: Bool = {
                    guard child.t == "T", child.va != "C" else { return false }
                    let childText = child.tx ?? ""
                    let childFS = child.fs ?? 14.0
                    let singleLine = !childText.contains("\n") && child.h < childFS * 1.65
                    return !singleLine
                }()

                CertiGoFigmaSceneNodeView(
                    node: child,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    onNavigateToNodeId: onNavigateToNodeId,
                    onLongPressDiagnosticTrigger: onLongPressDiagnosticTrigger
                )
                .frame(
                    width: childW,
                    height: childH,
                    alignment: childIsTopAlignedMultilineText ? .top : .center
                )
                .position(x: childCenterX, y: childCenterY)
            }
        }
        .frame(width: widthVal, height: heightVal)

        let clippedStack: AnyView = {
            if !isRootScreen, node.cl == 1 {
                return AnyView(
                    stack.clipShape(
                        RoundedRectangle(cornerRadius: radiusVal, style: .continuous)
                    )
                )
            }
            return AnyView(stack)
        }()

        if !isRootScreen, let strokeSpec = node.s {
            let lineWidth = PrismColor.figmaStrokeWidth(strokeSpec) * uniformScale
            let isDashed = PrismColor.figmaStrokeIsDashed(strokeSpec)
            let dashUnit = PrismSpacing.xs * uniformScale
            clippedStack.overlay(
                RoundedRectangle(cornerRadius: radiusVal, style: .continuous)
                    .stroke(
                        PrismColor.figmaStrokeColor(strokeSpec),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round,
                            dash: isDashed ? [dashUnit, dashUnit] : []
                        )
                    )
            )
        } else {
            clippedStack
        }
    }
}

public struct CertiGoFigmaExactScreenView: View {
    public let screenId: String
    public let content: CertiGoFigmaExactScreenContent
    public let liveState: CertiGoFigmaLiveRuntimeState
    public let additionalParallelTracksCount: Int
    public let onNavigateToNodeId: (String) -> Void
    public let onLongPressDiagnosticTrigger: (() -> Void)?

    public init(
        screenId: String,
        liveState: CertiGoFigmaLiveRuntimeState = CertiGoFigmaLiveRuntimeState(),
        additionalParallelTracksCount: Int = 2,
        onNavigateToNodeId: @escaping (String) -> Void = { _ in },
        onLongPressDiagnosticTrigger: (() -> Void)? = nil
    ) {
        self.screenId = screenId
        self.content = CertiGoFigmaExactScreenParity.content(forScreenId: screenId)
            ?? CertiGoFigmaExactScreenParity.page01Screens[0]
        self.liveState = liveState
        self.additionalParallelTracksCount = additionalParallelTracksCount
        self.onNavigateToNodeId = onNavigateToNodeId
        self.onLongPressDiagnosticTrigger = onLongPressDiagnosticTrigger
    }

    public init(
        content: CertiGoFigmaExactScreenContent,
        liveState: CertiGoFigmaLiveRuntimeState = CertiGoFigmaLiveRuntimeState(),
        additionalParallelTracksCount: Int = 2,
        onNavigateToNodeId: @escaping (String) -> Void = { _ in },
        onLongPressDiagnosticTrigger: (() -> Void)? = nil
    ) {
        self.screenId = content.screenCode
        self.content = content
        self.liveState = liveState
        self.additionalParallelTracksCount = additionalParallelTracksCount
        self.onNavigateToNodeId = onNavigateToNodeId
        self.onLongPressDiagnosticTrigger = onLongPressDiagnosticTrigger
    }

    public var body: some View {
        GeometryReader { proxy in
            let availableW = max(proxy.size.width, PrismSize.brandXL)
            let availableH = max(proxy.size.height, PrismSize.brandXL)

            if content.nodeId == "97:498",
               let merged = CertiGoFigmaSceneGraphStore.shared.mergedStatistiquesProNodes()
            {
                let topNode = liveState.applyingLiveState(
                    to: merged.top,
                    additionalParallelTracksCount: additionalParallelTracksCount
                )
                let bottomNode = liveState.applyingLiveState(
                    to: merged.bottom,
                    additionalParallelTracksCount: additionalParallelTracksCount
                )
                let baseW = CGFloat(max(topNode.w, 1.0))
                let baseH = CGFloat(max(topNode.h, 1.0))
                let scaleX = availableW / baseW
                let scaleY = availableH / baseH
                let pageH = baseH * scaleY

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: .zero) {
                        CertiGoFigmaSceneNodeView(
                            node: topNode,
                            scaleX: scaleX,
                            scaleY: scaleY,
                            isRootScreen: true,
                            onNavigateToNodeId: onNavigateToNodeId,
                            onLongPressDiagnosticTrigger: onLongPressDiagnosticTrigger
                        )
                        .frame(width: availableW, height: pageH)

                        CertiGoFigmaSceneNodeView(
                            node: bottomNode,
                            scaleX: scaleX,
                            scaleY: scaleY,
                            isRootScreen: true,
                            onNavigateToNodeId: onNavigateToNodeId,
                            onLongPressDiagnosticTrigger: onLongPressDiagnosticTrigger
                        )
                        .frame(width: availableW, height: pageH)
                        .padding(.top, -200.0 * scaleY)
                    }
                }
                .frame(width: availableW, height: availableH)
                .background(PrismColor.figmaHex(topNode.f ?? "#f8fafc"))
            } else if content.nodeId == "37:375",
                      let rawRoot = CertiGoFigmaSceneGraphStore.shared.nodeTree(forScreenNodeId: "37:375")
            {
                let liveRoot = liveState.applyingLiveState(
                    to: rawRoot,
                    additionalParallelTracksCount: additionalParallelTracksCount
                )
                let baseW = CGFloat(max(liveRoot.w, 1.0))
                let baseH = CGFloat(max(liveRoot.h, 1.0))
                let scaleX = availableW / baseW
                let scaleY = availableH / baseH
                let scrollingChildren = (liveRoot.c ?? []).filter { $0.i == "37:376" }
                let pinnedChildren = (liveRoot.c ?? []).filter {
                    ["37:440", "37:448", "37:452", "57:360"].contains($0.i)
                }
                let scrollingContainer = liveRoot.updating(
                    f: .some(nil),
                    d: .some(nil),
                    c: .some(scrollingChildren)
                )

                let extraScrollH = CGFloat(140.0) * scaleY

                ZStack(alignment: .topLeading) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: .zero) {
                            CertiGoFigmaSceneNodeView(
                                node: scrollingContainer,
                                scaleX: scaleX,
                                scaleY: scaleY,
                                isRootScreen: true,
                                onNavigateToNodeId: onNavigateToNodeId,
                                onLongPressDiagnosticTrigger: onLongPressDiagnosticTrigger
                            )
                            .frame(width: availableW, height: baseH * scaleY)
                            Color.clear
                                .frame(width: availableW, height: extraScrollH)
                        }
                    }
                    .frame(width: availableW, height: availableH)

                    ForEach(Array(pinnedChildren.enumerated()), id: \.offset) { _, child in
                        let childW = max(CGFloat(child.w) * scaleX, PrismBorder.hairline)
                        let childH = max(CGFloat(child.h) * scaleY, PrismBorder.hairline)
                        let childCenterX = (CGFloat(child.x) + CGFloat(child.w) * 0.5) * scaleX
                        let childCenterY = (CGFloat(child.y) + CGFloat(child.h) * 0.5) * scaleY

                        CertiGoFigmaSceneNodeView(
                            node: child,
                            scaleX: scaleX,
                            scaleY: scaleY,
                            onNavigateToNodeId: onNavigateToNodeId,
                            onLongPressDiagnosticTrigger: onLongPressDiagnosticTrigger
                        )
                        .frame(width: childW, height: childH)
                        .position(x: childCenterX, y: childCenterY)
                    }
                }
                .frame(width: availableW, height: availableH)
                .background(PrismColor.figmaHex(liveRoot.f ?? "#f7f9fc"))
            } else if let rawRootNode = CertiGoFigmaSceneGraphStore.shared.nodeTree(forScreenNodeId: content.nodeId) {
                let rootNode = liveState.applyingLiveState(
                    to: rawRootNode,
                    additionalParallelTracksCount: additionalParallelTracksCount
                )
                let baseW = CGFloat(max(rootNode.w, 1.0))
                let baseH = CGFloat(max(rootNode.h, 1.0))
                let scaleX = availableW / baseW
                let scaleY = availableH / baseH

                CertiGoFigmaSceneNodeView(
                    node: rootNode,
                    scaleX: scaleX,
                    scaleY: scaleY,
                    isRootScreen: true,
                    onNavigateToNodeId: onNavigateToNodeId,
                    onLongPressDiagnosticTrigger: onLongPressDiagnosticTrigger
                )
                .frame(width: availableW, height: availableH)
                .background(PrismColor.figmaHex(rootNode.f ?? "#f8fafc"))
            } else {
                Text(verbatim: content.title)
                    .prismTextStyle(.headline)
                    .foregroundStyle(PrismColor.textPrimary)
                    .frame(width: availableW, height: availableH)
                    .background(PrismColor.canvas)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("figma-exact-screen-\(content.screenCode)")
    }
}

public struct CertiGoFigmaInteractiveAppView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding public var coordinator: PrismAppShellCoordinatorModel
    @Binding public var router: AppRouterState
    public let flags: FeatureFlags
    public let preferenceStore: CertigoParallelTracksPreferenceStore

    @State private var currentScreenNodeId: String
    @State private var isPickerExpanded: Bool = false
    @State private var selectedChapterGroup: CertiGoQuickChapterGroup
    @State private var liveState = CertiGoFigmaLiveRuntimeState()
    @State private var aiDraftText: String = ""
    @State private var voicePulsePhase: Bool = false

    public init(
        initialScreenNodeId: String = "37:375",
        coordinator: Binding<PrismAppShellCoordinatorModel>,
        router: Binding<AppRouterState>,
        flags: FeatureFlags = FeatureFlags(),
        preferenceStore: CertigoParallelTracksPreferenceStore = .shared
    ) {
        self._coordinator = coordinator
        self._router = router
        self.flags = flags
        self.preferenceStore = preferenceStore
        let resolvedInitial = CertiGoFigmaSceneGraphStore.shared.nodeTree(forScreenId: initialScreenNodeId)?.i
            ?? "37:375"
        self._currentScreenNodeId = State(initialValue: resolvedInitial)
        self._selectedChapterGroup = State(
            initialValue: CertiGoQuickChapterGroup.group(containingNodeId: resolvedInitial)
        )
    }

    private var currentScreenContent: CertiGoFigmaExactScreenContent {
        CertiGoFigmaExactScreenParity.content(forNodeId: currentScreenNodeId)
            ?? CertiGoFigmaExactScreenParity.content(forScreenId: "01")
            ?? CertiGoFigmaExactScreenParity.page01Screens[0]
    }

    private var orderedNodeIds: [String] {
        CertiGoQuickChapterGroup.orderedScreenNodeIds
    }

    private var currentScreenIndex: Int {
        orderedNodeIds.firstIndex(of: currentScreenNodeId) ?? 0
    }

    private func handleTargetOrNavigate(_ destinationOrAction: String) {
        if destinationOrAction.hasPrefix("act:") {
            let rawNodeId = String(destinationOrAction.dropFirst(4))
            var nextDestination: String?
            withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                nextDestination = liveState.handleTap(
                    onNodeId: rawNodeId,
                    inScreenNodeId: currentScreenNodeId,
                    coordinator: &coordinator
                )
            }
            if rawNodeId == "78:366" {
                let payload = liveState.currentAITopicPayload
                UIPasteboard.general.string = "\(payload.question)\n\(payload.intro)\n\(payload.bullet1)\n\(payload.bullet2)"
            } else if rawNodeId == "89:480" {
                UIPasteboard.general.string = "@gabriel"
            }
            if let nextDestination {
                navigate(to: nextDestination)
            }
            return
        }
        navigate(to: destinationOrAction)
    }

    private func navigate(to destinationId: String) {
        guard let targetNode = CertiGoFigmaSceneGraphStore.shared.nodeTree(forScreenId: destinationId) else {
            return
        }
        let targetNodeId = targetNode.i
        let preset = CertiGoFigmaSceneGraphStore.recommendedAnimationPreset(
            forDestinationNodeId: targetNodeId
        )
        withAnimation(CertiGoMotion.spring(for: preset, reduceMotion: reduceMotion)) {
            currentScreenNodeId = targetNodeId
            selectedChapterGroup = CertiGoQuickChapterGroup.group(containingNodeId: targetNodeId)
        }
        synchronizeRouterState(for: targetNodeId)
    }

    private func stepScreen(by delta: Int) {
        let list = orderedNodeIds
        guard !list.isEmpty else { return }
        let nextIndex = (currentScreenIndex + delta + list.count) % list.count
        navigate(to: list[nextIndex])
    }

    private func synchronizeRouterState(for nodeId: String) {
        switch nodeId {
        case "37:375":
            router.selectedTab = .today
        case "142:385":
            router.selectedTab = .atlas
        case "79:332":
            router.selectedTab = .search
        case "88:317", "89:317":
            router.selectedTab = .ensemble
        case "97:287":
            router.selectedTab = .profile
        default:
            break
        }
    }

    public var body: some View {
        GeometryReader { proxy in
            let scaleX = max(proxy.size.width, PrismSize.brandXL) / 393.0
            let scaleY = max(proxy.size.height, PrismSize.brandXL) / 852.0

            ZStack(alignment: .bottom) {
                CertiGoFigmaExactScreenView(
                    content: currentScreenContent,
                    liveState: liveState,
                    additionalParallelTracksCount: coordinator.parallelTracksPreference.additionalParallelTracksCount,
                    onNavigateToNodeId: { targetNodeId in
                        handleTargetOrNavigate(targetNodeId)
                    },
                    onLongPressDiagnosticTrigger: {
                        withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                            isPickerExpanded.toggle()
                        }
                    }
                )
                .id(currentScreenNodeId)
                .ignoresSafeArea()

                liveInteractiveNativeOverlays(scaleX: scaleX, scaleY: scaleY)

                if isPickerExpanded {
                    floatingChapterNavigatorOverlay
                        .padding(.horizontal, PrismSpacing.m)
                        .padding(.bottom, PrismSpacing.xxs)
                }
            }
        }
        .fontDesign(.rounded)
        .preferredColorScheme(.light)
        .task {
            let persisted = preferenceStore.loadOrDefault()
            if coordinator.parallelTracksPreference != persisted {
                coordinator.applyPersistedPreferences(persisted)
            }
            liveState.activeRouteCode = coordinator.parallelTracksPreference.activeTrackCode
            liveState.settingsLanguageIndex = coordinator.parallelTracksPreference.bilingualTechnicalTermsEN ? 0 : 1
            liveState.settingsExamModeIndex = coordinator.parallelTracksPreference.strictTimed90Min ? 0 : 1
        }
        .onChange(of: coordinator.parallelTracksPreference) { _, updated in
            if liveState.activeRouteCode != updated.activeTrackCode {
                liveState.activeRouteCode = updated.activeTrackCode
            }
            try? preferenceStore.save(updated)
        }
    }

    @ViewBuilder
    private func liveInteractiveNativeOverlays(scaleX: CGFloat, scaleY: CGFloat) -> some View {
        let uniformScale = min(scaleX, scaleY)
        ZStack(alignment: .topLeading) {
            Color.clear

            // 1. Q_TYPE_04 (73:575) native TextField overlay on CLI box (73:602)
            if currentScreenNodeId == "73:575" {
                let cliW = CGFloat(136.0) * scaleX
                let cliH = CGFloat(44.0) * scaleY
                TextField("", text: $liveState.qType04InputText)
                    .font(PrismTypography.figmaFont(size: 16 * uniformScale, style: "Bold", monospaced: true))
                    .foregroundStyle(Color.clear)
                    .tint(PrismColor.figmaHex("#1cb0f6"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(width: cliW, height: cliH)
                    .position(x: (124 + 68) * scaleX, y: (306 + 22) * scaleY)
                    .accessibilityIdentifier("figma-qtype04-cli-textfield")
            }

            // 2. Hub IA 06 (79:332) & 06B (78:332) interactive prompt input bar
            if currentScreenNodeId == "79:332" || currentScreenNodeId == "78:332" {
                let barY: CGFloat = currentScreenNodeId == "79:332" ? 678 : 676
                let sendBtnW = CGFloat(28.0) * scaleX
                let sendBtnH = CGFloat(28.0) * scaleY
                let promptW = CGFloat(215.0) * scaleX
                let promptH = CGFloat(44.0) * scaleY
                let promptRadius = PrismRadius.m * uniformScale
                HStack(spacing: PrismSpacing.xs) {
                    TextField(
                        currentScreenNodeId == "79:332"
                            ? "Écrire ou parler à CertiGo IA..."
                            : "Demander à CertiGo IA...",
                        text: $aiDraftText
                    )
                    .font(PrismTypography.figmaFont(size: 13 * uniformScale, style: "Medium"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .submitLabel(.send)
                    .onSubmit {
                        guard !aiDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let dest = liveState.submitAIPrompt(aiDraftText)
                        aiDraftText = ""
                        navigate(to: dest)
                    }
                    .accessibilityIdentifier("figma-ai-prompt-textfield")

                    if !aiDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            let dest = liveState.submitAIPrompt(aiDraftText)
                            aiDraftText = ""
                            navigate(to: dest)
                        } label: {
                            Text(verbatim: "↑")
                                .font(PrismTypography.figmaFont(size: 14 * uniformScale, style: "Black"))
                                .foregroundStyle(PrismColor.onAccent)
                                .frame(width: sendBtnW, height: sendBtnH)
                                .background(Circle().fill(PrismColor.figmaHex("#0078d4")))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("figma-ai-prompt-send")
                    }
                }
                .padding(.horizontal, PrismSpacing.xs)
                .frame(width: promptW, height: promptH)
                .background(
                    RoundedRectangle(cornerRadius: promptRadius, style: .continuous)
                        .fill(PrismColor.figmaHex("#f0f4f9"))
                )
                .position(x: (62 + 107.5) * scaleX, y: (barY + 28) * scaleY)
            }

            // 3. 06C Vocal Live (81:345) ANIM_05 spring voice halo animation
            if currentScreenNodeId == "81:345" {
                let haloW = CGFloat(224.0) * scaleX
                let haloH = CGFloat(224.0) * scaleY
                let haloLineW = CGFloat(3.0) * uniformScale
                Circle()
                    .strokeBorder(
                        PrismColor.figmaHex("#38bdf8:45"),
                        lineWidth: haloLineW
                    )
                    .frame(width: haloW, height: haloH)
                    .scaleEffect(liveState.isVoiceLiveListening ? (voicePulsePhase ? 1.08 : 0.94) : 0.88)
                    .opacity(liveState.isVoiceLiveListening ? (voicePulsePhase ? 0.85 : 0.35) : 0.15)
                    .position(x: 196 * scaleX, y: 218 * scaleY)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(
                            CertiGoMotion
                                .spring(for: .anim05NovaLiveVoicePulse, reduceMotion: reduceMotion)
                                .repeatForever(autoreverses: true)
                        ) {
                            voicePulsePhase = true
                        }
                    }
                    .onDisappear {
                        voicePulsePhase = false
                    }
            }

            // 4. 06D Tiroir Historique (85:317) interactive search field
            if currentScreenNodeId == "85:317" {
                let searchW = CGFloat(280.0) * scaleX
                let searchH = CGFloat(38.0) * scaleY
                let searchRadius = PrismRadius.m * uniformScale
                TextField("🔍   Rechercher une discussion...", text: $liveState.aiHistorySearchText)
                    .font(PrismTypography.figmaFont(size: 13 * uniformScale, style: "Medium"))
                    .foregroundStyle(PrismColor.figmaHex("#0f172a"))
                    .padding(.horizontal, PrismSpacing.s)
                    .frame(width: searchW, height: searchH)
                    .background(
                        RoundedRectangle(cornerRadius: searchRadius, style: .continuous)
                            .fill(PrismColor.figmaHex("#ffffff"))
                    )
                    .position(x: (22 + 145) * scaleX, y: (106 + 21) * scaleY)
                    .accessibilityIdentifier("figma-ai-history-search-textfield")
            }

            // 5. Écran 24 (142:540) horizontal swipe gesture on top Pearson VUE carousel card (142:546)
            if currentScreenNodeId == "142:540" {
                let cardSwipeW = CGFloat(315.0) * scaleX
                let cardSwipeH = CGFloat(240.0) * scaleY
                Color.clear
                    .frame(width: cardSwipeW, height: cardSwipeH)
                    .contentShape(Rectangle())
                    .position(x: (20 + 157.5) * scaleX, y: (56 + 125) * scaleY)
                    .gesture(
                        DragGesture(minimumDistance: 20)
                            .onEnded { value in
                                withAnimation(CertiGoMotion.spring(for: .anim06PearsonBarometerFill, reduceMotion: reduceMotion)) {
                                    if value.translation.width < -20 {
                                        liveState.examReportCarouselIndex = (liveState.examReportCarouselIndex + 1) % 3
                                    } else if value.translation.width > 20 {
                                        liveState.examReportCarouselIndex = (liveState.examReportCarouselIndex + 2) % 3
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        handleTargetOrNavigate("act:142:573")
                    }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var floatingChapterNavigatorOverlay: some View {
        VStack(alignment: .center, spacing: PrismSpacing.xs) {
            if isPickerExpanded {
                chapterPickerCard
            }

            HStack(spacing: PrismSpacing.xxs) {
                Button {
                    stepScreen(by: -1)
                } label: {
                    Text(verbatim: "‹")
                        .prismTextStyle(.subheadline)
                        .foregroundStyle(PrismColor.onAccent)
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, PrismSpacing.xxs)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("figma-Floating-Prev-Button")

                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim02ApplePayBottomSheet, reduceMotion: reduceMotion)) {
                        isPickerExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: PrismSpacing.xxs) {
                        Text(verbatim: "✦ \(currentScreenContent.screenCode)")
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.onAccent)
                        Text(verbatim: "\(currentScreenIndex + 1)/\(orderedNodeIds.count) ▾")
                            .prismTextStyle(.caption)
                            .foregroundStyle(PrismColor.onAccent.opacity(0.85))
                    }
                    .padding(.horizontal, PrismSpacing.s)
                    .padding(.vertical, PrismSpacing.xxs)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("figma-Floating-Picker-Toggle")

                Button {
                    stepScreen(by: 1)
                } label: {
                    Text(verbatim: "›")
                        .prismTextStyle(.subheadline)
                        .foregroundStyle(PrismColor.onAccent)
                        .padding(.horizontal, PrismSpacing.s)
                        .padding(.vertical, PrismSpacing.xxs)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("figma-Floating-Next-Button")
            }
            .background(
                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                    .fill(PrismColor.figmaHex("#0f172a:82"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PrismRadius.pill, style: .continuous)
                    .strokeBorder(PrismColor.figmaHex("#ffffff:24"), lineWidth: PrismBorder.hairline)
            )
        }
    }

    @ViewBuilder
    private var chapterPickerCard: some View {
        VStack(alignment: .leading, spacing: PrismSpacing.s) {
            HStack {
                Text(verbatim: "53 ÉCRANS FIGMA PRO (1:1 SCENE-GRAPH)")
                    .prismTextStyle(.caption)
                    .foregroundStyle(PrismColor.textSecondary)
                Spacer(minLength: PrismSpacing.xs)
                Button {
                    withAnimation(CertiGoMotion.spring(for: .anim01Tactile3DPress, reduceMotion: reduceMotion)) {
                        isPickerExpanded = false
                    }
                } label: {
                    Text(verbatim: "✕")
                        .prismTextStyle(.caption)
                        .foregroundStyle(PrismColor.textSecondary)
                        .padding(.horizontal, PrismSpacing.xs)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.xs) {
                    ForEach(CertiGoQuickChapterGroup.allCases) { group in
                        let isSelected = selectedChapterGroup == group
                        Button {
                            selectedChapterGroup = group
                        } label: {
                            Text(verbatim: group.rawValue)
                                .prismTextStyle(.caption)
                                .foregroundStyle(isSelected ? PrismColor.onAccent : PrismColor.textPrimary)
                                .padding(.horizontal, PrismSpacing.s)
                                .padding(.vertical, PrismSpacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                        .fill(isSelected ? PrismColor.accent : PrismColor.canvas)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PrismSpacing.xs) {
                    ForEach(selectedChapterGroup.screenNodeIds, id: \.self) { nodeId in
                        let screen = CertiGoFigmaExactScreenParity.content(forNodeId: nodeId)
                        let isCurrent = nodeId == currentScreenNodeId
                        Button {
                            navigate(to: nodeId)
                            isPickerExpanded = false
                        } label: {
                            VStack(alignment: .leading, spacing: PrismSpacing.xxs) {
                                Text(verbatim: screen?.screenCode ?? nodeId)
                                    .prismTextStyle(.caption)
                                    .foregroundStyle(isCurrent ? PrismColor.onAccent : PrismColor.accent)
                                Text(verbatim: screen?.figmaFrameName ?? nodeId)
                                    .prismTextStyle(.footnote)
                                    .foregroundStyle(isCurrent ? PrismColor.onAccent : PrismColor.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, PrismSpacing.m)
                            .padding(.vertical, PrismSpacing.s)
                            .background(
                                RoundedRectangle(cornerRadius: PrismRadius.m, style: .continuous)
                                    .fill(isCurrent ? PrismColor.accent : PrismColor.canvas)
                            )
                        }
                        .buttonStyle(.plain)
                    }
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
                .strokeBorder(PrismColor.separator, lineWidth: PrismBorder.standard)
        )
    }
}
#endif
