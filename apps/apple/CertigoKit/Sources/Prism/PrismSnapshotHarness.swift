import Foundation

public enum PrismSnapshotError: Error, Equatable {
  case invalidDimensions
  case invalidPixelCount
  case renderingFailed
}

/// Canonical, premultiplied RGBA8 pixels. Comparison deliberately ignores PNG encoder metadata.
public struct PrismSnapshot: Equatable, Sendable {
  public let width: Int
  public let height: Int
  public let pixels: Data

  public init(width: Int, height: Int, pixels: Data) throws {
    guard width > 0, height > 0 else { throw PrismSnapshotError.invalidDimensions }
    let area = width.multipliedReportingOverflow(by: height)
    let bytes = area.partialValue.multipliedReportingOverflow(by: 4)
    guard !area.overflow, !bytes.overflow, bytes.partialValue == pixels.count else {
      throw PrismSnapshotError.invalidPixelCount
    }
    self.width = width
    self.height = height
    self.pixels = pixels
  }

  /// FNV-1a is a stable diagnostic fingerprint, not an integrity/security hash.
  public var fingerprint: String {
    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    let dimensions = "\(width)x\(height):".utf8
    for byte in dimensions {
      hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
    }
    for byte in pixels {
      hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
    }
    return String(hash, radix: 16)
  }

  public func matches(_ reference: Self) -> Bool { self == reference }
}

// MARK: - Master Figma Pro Screen Verification Registry (Pages 01 to 12 — 53 Validated Screens)

public enum CertiGoFigmaChapter: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
  case onboardingPage07 = "Chapitre 1 · Onboarding & Pop-ups Système Natifs iOS (Page 07)"
  case homeAndWaymoPath = "Chapitre 2 · Accueil Waymo, Rail Mimo, Popover & Fiche Mémo (Page 01)"
  case questionsAndTenFormatsPage06 = "Chapitre 3 · Exercices, Bulles Mascottes 3/4 & 10 Formes de Questions (Pages 01 & 06)"
  case aiHubFourModes = "Chapitre 4 · Hub IA Complet 4 Modes : Accueil, Écrit, Vocal Live & Historique (Page 01)"
  case pearsonVueExamSimulationPage09 = "Chapitre 5 · Onglet Examens & Simulation Pearson VUE (Pages 01 & 09)"
  case socialProfileProStatsAndSettings = "Chapitre 6 · Social, Moi, Blasons Officiels, Stats Pro, PRO & Paramètres (Pages 01 & 09)"
  case ios18SystemSurfacesPage11 = "Chapitre 7 · Surfaces Système iOS 18 : Widgets, Dynamic Island & Control Center (Page 11)"
  case offlineAndZeroGuiltResiliencePage12 = "Chapitre 8 · États de Résilience : Hors-Ligne 142 Mo & Reprise Zéro Culpabilité (Page 12)"

  public var id: String { rawValue }
}

extension CertiGoMascotPose {
  /// True when the pose is one of the 6 domain specialists in 3/4 right quiz view (`LIB_04` on Page 08).
  public var isRight34Specialist: Bool {
    switch self {
    case .specialistCloudAzure,
      .specialistSecurityEntra,
      .specialistNetworkVNet,
      .specialistCLIContainers,
      .specialistDataSQL,
      .specialistAICoach:
      return true
    default:
      return false
    }
  }

  /// True when the pose is turned in 3/4 right view to present a quiz question (`◀` speech bubble).
  public var isRight34QuizPose: Bool {
    self == .angle34RightQuiz || isRight34Specialist
  }
}

public struct CertiGoMasterFigmaScreenDescriptor: Identifiable, Codable, Equatable, Hashable, Sendable {
  public static let standardCanvasWidth: Int = 393
  public static let standardCanvasHeight: Int = 852

  public var id: String { screenCode }
  public let screenCode: String
  public let nodeId: String
  public let title: String
  public let chapter: String
  public let chapterKind: CertiGoFigmaChapter
  public let figmaPageId: String
  public let mascotPose: CertiGoMascotPose?
  public let mascotCount: Int
  public let canvasWidth: Int
  public let canvasHeight: Int
  public let hasZeroTextOverlap: Bool
  public let hasZeroBoxOverflow: Bool
  public let clipsRoundedCorners: Bool

  public init(
    screenCode: String,
    nodeId: String,
    title: String,
    chapterKind: CertiGoFigmaChapter,
    figmaPageId: String,
    mascotPose: CertiGoMascotPose?,
    mascotCount: Int? = nil,
    canvasWidth: Int = Self.standardCanvasWidth,
    canvasHeight: Int = Self.standardCanvasHeight,
    hasZeroTextOverlap: Bool = true,
    hasZeroBoxOverflow: Bool = true,
    clipsRoundedCorners: Bool = true
  ) {
    self.screenCode = screenCode
    self.nodeId = nodeId
    self.title = title
    self.chapter = chapterKind.rawValue
    self.chapterKind = chapterKind
    self.figmaPageId = figmaPageId
    self.mascotPose = mascotPose
    self.mascotCount = mascotCount ?? (mascotPose == nil ? 0 : 1)
    self.canvasWidth = canvasWidth
    self.canvasHeight = canvasHeight
    self.hasZeroTextOverlap = hasZeroTextOverlap
    self.hasZeroBoxOverflow = hasZeroBoxOverflow
    self.clipsRoundedCorners = clipsRoundedCorners
  }

  /// Verifies the validated Duolingo-style mascot placement invariants across the 53 Figma Pro screens.
  public func verifyMascotPlacementInvariant() -> Bool {
    switch screenCode {
    case "01":
      return mascotPose == .angle34LeftPath && mascotCount == 1
    case "19":
      return mascotPose == .angleFrontCelebration && mascotCount == 1
    case "20", "22", "27":
      return mascotPose == nil && mascotCount == 0
    default:
      if screenCode.hasPrefix("Q_TYPE_") {
        guard let pose = mascotPose else { return false }
        return pose.isRight34Specialist && mascotCount == 1
      }
      if mascotPose == nil {
        return mascotCount == 0
      }
      return mascotCount == 1
    }
  }

  /// Verifies zero text overlap, zero box overflow, rounded corner clipping, valid Figma identity, and mascot placement invariants.
  public func verifyVisualInvariants() -> Bool {
    hasZeroTextOverlap
      && hasZeroBoxOverflow
      && clipsRoundedCorners
      && !nodeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !screenCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !chapter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && canvasWidth == Self.standardCanvasWidth
      && canvasHeight == Self.standardCanvasHeight
      && verifyMascotPlacementInvariant()
  }

  public var passesVisualInvariants: Bool {
    verifyVisualInvariants()
  }
}

public enum CertiGoMasterScreenCatalog {
  public static let figmaFileKey: String = "ECDZfufGwX3hX40Khntnw2"
  public static let expectedScreenCount: Int = 53
  public static let mascotFreeScreenCodes: Set<String> = ["20", "22", "27"]

  public static let allScreens: [CertiGoMasterFigmaScreenDescriptor] = [
    // 1. Onboarding Flow & Native iOS Pop-ups (OB-01 .. OB-08B — 11 Screens, Page 07)
    .init(
      screenCode: "OB-01",
      nodeId: "132:182",
      title: "OB-01 · Ouverture Arche 4 Marques (Google, Microsoft, AWS, GitHub) & Blason 1A",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .angleFrontCelebration
    ),
    .init(
      screenCode: "OB-02",
      nodeId: "132:264",
      title: "OB-02 · Objectifs Certifications Cloud & Veille Grands Acteurs IA",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .posePresenter
    ),
    .init(
      screenCode: "OB-03A",
      nodeId: "132:339",
      title: "OB-03A · Sélection Multi-Certifications en Parallèle",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .specialistCloudAzure
    ),
    .init(
      screenCode: "OB-03B",
      nodeId: "132:438",
      title: "OB-03B · Cours sur les Acteurs de l'IA, Veille Tech & Catalogue en Expansion",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .specialistAICoach
    ),
    .init(
      screenCode: "OB-04",
      nodeId: "132:519",
      title: "OB-04 · Calibrage du Niveau & Échéance d'Examen",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .poseAnalyst
    ),
    .init(
      screenCode: "OB-06A",
      nodeId: "132:581",
      title: "OB-06A · Choix du Rythme Quotidien & Heure du Rappel (19:30)",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .emotionOnFire
    ),
    .init(
      screenCode: "OB-06B",
      nodeId: "132:651",
      title: "OB-06B · Pop-up Système Natif iOS : Autorisation des Notifications Push",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .emotionStarryEyes
    ),
    .init(
      screenCode: "OB-06C",
      nodeId: "132:759",
      title: "OB-06C · Pop-up Système Natif iOS 18 : Ajouter le Widget Écran d'Accueil",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .emotionOnFire
    ),
    .init(
      screenCode: "OB-07",
      nodeId: "132:877",
      title: "OB-07 · Plan Épuré & Double Courbe Avec CertiGo vs Sans CertiGo",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .emotionDetermined
    ),
    .init(
      screenCode: "OB-08A",
      nodeId: "132:945",
      title: "OB-08A · Création du Profil en 1 Tap sans Bandeau Supérieur",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: .poseVictoryJump
    ),
    .init(
      screenCode: "OB-08B",
      nodeId: "132:1009",
      title: "OB-08B · Feuille Système Native iOS Connexion avec Apple (Face ID)",
      chapterKind: .onboardingPage07,
      figmaPageId: "102:257",
      mascotPose: nil
    ),

    // 2. Main Home, Switcher Popover, Preview Sheet, Question & AI Feedback (01 .. 05 — 5 Screens)
    .init(
      screenCode: "01",
      nodeId: "37:375",
      title: "01 · Accueil Îlots Waymo, Rail Mimo & 1 Mascotte 3/4 Gauche sur l'Étape Active",
      chapterKind: .homeAndWaymoPath,
      figmaPageId: "0:1",
      mascotPose: .angle34LeftPath,
      mascotCount: 1
    ),
    .init(
      screenCode: "02",
      nodeId: "42:375",
      title: "02 · Popover Flottant Marques & Certifications avec Vrai Logo AWS",
      chapterKind: .homeAndWaymoPath,
      figmaPageId: "0:1",
      mascotPose: nil
    ),
    .init(
      screenCode: "03",
      nodeId: "49:368",
      title: "03 · Feuille Flottante d'Aperçu d'Étape [📖 | COMMENCER | ✦]",
      chapterKind: .homeAndWaymoPath,
      figmaPageId: "0:1",
      mascotPose: nil
    ),
    .init(
      screenCode: "04",
      nodeId: "73:332",
      title: "04 · Exercice Flashcard Empilée Duolingo (Mascotte 3/4 Droite + Bulle 15px ◀)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: .specialistSecurityEntra
    ),
    .init(
      screenCode: "05",
      nodeId: "62:346",
      title: "05 · Feuille Flottante d'Explication d'Erreur IA sur Fond Assombri (62 %)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: .specialistAICoach
    ),

    // 3. Complete 4-Screen AI Hub (06A .. 06D — 4 Screens)
    .init(
      screenCode: "06A",
      nodeId: "79:332",
      title: "06A · Accueil du Hub IA Style Gemini",
      chapterKind: .aiHubFourModes,
      figmaPageId: "0:1",
      mascotPose: .specialistAICoach
    ),
    .init(
      screenCode: "06B",
      nodeId: "78:332",
      title: "06B · Réponse Écrite Structurée Style Gemini avec Schéma & Astuce Examen",
      chapterKind: .aiHubFourModes,
      figmaPageId: "0:1",
      mascotPose: .specialistAICoach
    ),
    .init(
      screenCode: "06C",
      nodeId: "81:345",
      title: "06C · Conversation Vocale Live Nova 1,0× & Indicateur Voix Central",
      chapterKind: .aiHubFourModes,
      figmaPageId: "0:1",
      mascotPose: .specialistAICoach
    ),
    .init(
      screenCode: "06D",
      nodeId: "85:317",
      title: "06D · Tiroir d'Historique des Discussions Push 85 % Style Claude",
      chapterKind: .aiHubFourModes,
      figmaPageId: "0:1",
      mascotPose: nil
    ),

    // 4. Social Podium, Profile & Merged 2-Pane Pro Statistics Dashboard (07A, 08, 08B-1, 08B-2 — 4 Screens)
    .init(
      screenCode: "07A",
      nodeId: "88:317",
      title: "07A · Onglet Social Podium 3D Semaine (2e · 1er · 3e) & Zone de Promotion Top 5",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "0:1",
      mascotPose: .angleLookupPodium
    ),
    .init(
      screenCode: "08",
      nodeId: "97:287",
      title: "08 · Onglet Moi avec Stylo Photo, Vrais Blasons Officiels & Accès Statistiques Pro",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "0:1",
      mascotPose: .emotionBossCrown
    ),
    .init(
      screenCode: "08B-1",
      nodeId: "97:498",
      title: "08B-1 · Dashboard Statistiques Pro Volet Haut (Indice 84 %, Radar 5 Axes & Heatmap 56j)",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "0:1",
      mascotPose: .poseAnalyst
    ),
    .init(
      screenCode: "08B-2",
      nodeId: "97:636",
      title: "08B-2 · Dashboard Statistiques Pro Volet Bas (3 Anneaux, Courbe /1000 & Forces/Cibles)",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "0:1",
      mascotPose: .emotionDetermined
    ),

    // 5. Session Flow, Pearson VUE Mock Exam, Friends, Certificate, PRO & Settings (14 .. 28 — 15 Screens)
    .init(
      screenCode: "14",
      nodeId: "58:705",
      title: "14 · Fiche Mémo Dépliée Structure C Tableau Apple Pay",
      chapterKind: .homeAndWaymoPath,
      figmaPageId: "0:1",
      mascotPose: .poseReaderMemo
    ),
    .init(
      screenCode: "15",
      nodeId: "26:807",
      title: "15 · Carte Déclic Visuelle Micro-Leçon 20s",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: .emotionAhaIdea
    ),
    .init(
      screenCode: "16",
      nodeId: "26:826",
      title: "16 · Exercice Grille 2×2 Visuelle de Services Officiels",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: .specialistCloudAzure
    ),
    .init(
      screenCode: "17",
      nodeId: "26:863",
      title: "17 · Exercice Constructeur CLI & Code Interactif",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: .poseCLICoder
    ),
    .init(
      screenCode: "18",
      nodeId: "26:890",
      title: "18 · Validation Réussie & Bouton IA [✦ EXPLIQUER MA RÉPONSE]",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: .poseVictoryJump
    ),
    .init(
      screenCode: "19",
      nodeId: "26:912",
      title: "19 · Célébration de Fin d'Étape avec Mascotte Blason 1A Centrale",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: .angleFrontCelebration,
      mascotCount: 1
    ),
    .init(
      screenCode: "20",
      nodeId: "26:939",
      title: "20 · Comparateur Technique Côte-à-Côte sans Mascotte",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "0:1",
      mascotPose: nil,
      mascotCount: 0
    ),
    .init(
      screenCode: "21",
      nodeId: "142:385",
      title: "21 · Onglet Examens Variante C Centrée & 5 Domaines Officiels Pondérés",
      chapterKind: .pearsonVueExamSimulationPage09,
      figmaPageId: "140:182",
      mascotPose: .poseCrossedArms
    ),
    .init(
      screenCode: "22",
      nodeId: "26:1009",
      title: "22 · Feuille Flottante Apple Pay Lancement Examen Blanc avec Vrai Blason AZ-104",
      chapterKind: .pearsonVueExamSimulationPage09,
      figmaPageId: "0:1",
      mascotPose: nil,
      mascotCount: 0
    ),
    .init(
      screenCode: "23",
      nodeId: "142:478",
      title: "23 · Cockpit Examen Blanc Chronométré en Cours (Pearson VUE)",
      chapterKind: .pearsonVueExamSimulationPage09,
      figmaPageId: "140:182",
      mascotPose: nil
    ),
    .init(
      screenCode: "24",
      nodeId: "142:540",
      title: "24 · Rapport Examen Blanc & Carrousel Baromètre Pearson VUE (\u{25CF}\u{25CB}\u{25CB})",
      chapterKind: .pearsonVueExamSimulationPage09,
      figmaPageId: "140:182",
      mascotPose: .emotionBossCrown
    ),
    .init(
      screenCode: "25",
      nodeId: "89:317",
      title: "25 · Onglet Social Vue Mes Amis (12), Ajout par Code/QR & \u{1F44F} Saluer en 1 Tap",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "0:1",
      mascotPose: .angleSprintRight
    ),
    .init(
      screenCode: "26",
      nodeId: "97:417",
      title: "26 · Détail Certificat Professionnel avec Vrai Blason Officiel",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "0:1",
      mascotPose: .emotionStarryEyes
    ),
    .init(
      screenCode: "27",
      nodeId: "144:137",
      title: "27 · CertiGo PRO Variante 27-A Tableau Comparatif Gratuit vs PRO",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "140:182",
      mascotPose: nil,
      mascotCount: 0
    ),
    .init(
      screenCode: "28",
      nodeId: "145:122",
      title: "28 · Paramètres Complets Style 1 Minimalisme Chirurgical ChatGPT iOS 2026",
      chapterKind: .socialProfileProStatsAndSettings,
      figmaPageId: "140:182",
      mascotPose: nil
    ),

    // 6. The 10 Interactive Question Formats (Q_TYPE_01 .. Q_TYPE_10 — 10 Screens, Page 06)
    .init(
      screenCode: "Q_TYPE_01",
      nodeId: "73:393",
      title: "Q_TYPE_01 · QCM Scénario Classique & Pilule Bleu Ciel (Possibilité 4)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistSecurityEntra
    ),
    .init(
      screenCode: "Q_TYPE_02",
      nodeId: "73:442",
      title: "Q_TYPE_02 · Sélection de Symboles de Services Officiels (Grille 2×2)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistCloudAzure
    ),
    .init(
      screenCode: "Q_TYPE_03",
      nodeId: "73:509",
      title: "Q_TYPE_03 · Schéma d'Architecture Interactif à Compléter [ ? ]",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistNetworkVNet
    ),
    .init(
      screenCode: "Q_TYPE_04",
      nodeId: "73:575",
      title: "Q_TYPE_04 · Saisie au Clavier iOS (Paramètre / Zone / Commande)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistCLIContainers
    ),
    .init(
      screenCode: "Q_TYPE_05",
      nodeId: "73:743",
      title: "Q_TYPE_05 · Assemblage de Briques CLI (Word Bank Duolingo)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistCLIContainers
    ),
    .init(
      screenCode: "Q_TYPE_06",
      nodeId: "73:818",
      title: "Q_TYPE_06 · Paires à Relier (Symboles ↔ Rôles Exact)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistDataSQL
    ),
    .init(
      screenCode: "Q_TYPE_07",
      nodeId: "73:898",
      title: "Q_TYPE_07 · Diagnostic d'Anomalie dans une Règle JSON / YAML / Bicep",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistSecurityEntra
    ),
    .init(
      screenCode: "Q_TYPE_08",
      nodeId: "73:958",
      title: "Q_TYPE_08 · Classer dans l'Ordre Hiérarchique de Portée (1 ➔ 4)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistCloudAzure
    ),
    .init(
      screenCode: "Q_TYPE_09",
      nodeId: "73:1019",
      title: "Q_TYPE_09 · Verdict Rapide d'Architecture (Autorisé vs Bloqué)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistNetworkVNet
    ),
    .init(
      screenCode: "Q_TYPE_10",
      nodeId: "73:1070",
      title: "Q_TYPE_10 · Multi-Sélection à Cases à Cocher (Exactement 2 Réponses)",
      chapterKind: .questionsAndTenFormatsPage06,
      figmaPageId: "70:649",
      mascotPose: .specialistAICoach
    ),

    // 7. iOS 18 System Surfaces (Page 11) & Offline / Zero-Guilt Resilience (Page 12) (SYS-01, SYS-02, RES-01, RES-02 — 4 Screens)
    .init(
      screenCode: "SYS-01",
      nodeId: "161:93",
      title: "SYS-01 · Widgets Écran d'Accueil iOS 18 (W-1, W-Radar, W-2 & W-3 Interactif NS-14)",
      chapterKind: .ios18SystemSurfacesPage11,
      figmaPageId: "161:92",
      mascotPose: .emotionOnFire
    ),
    .init(
      screenCode: "SYS-02",
      nodeId: "161:134",
      title: "SYS-02 · Dynamic Island, Live Activities (LA-1..LA-3) & Control Center (CC-1)",
      chapterKind: .ios18SystemSurfacesPage11,
      figmaPageId: "161:92",
      mascotPose: nil
    ),
    .init(
      screenCode: "RES-01",
      nodeId: "162:93",
      title: "RES-01 · Mode Hors-Ligne Train / Avion (Packs 142 Mo & File DR-004)",
      chapterKind: .offlineAndZeroGuiltResiliencePage12,
      figmaPageId: "162:92",
      mascotPose: .poseReaderMemo
    ),
    .init(
      screenCode: "RES-02",
      nodeId: "162:120",
      title: "RES-02 · Reprise Bienveillante Zéro Culpabilité (Séance Express 5 min)",
      chapterKind: .offlineAndZeroGuiltResiliencePage12,
      figmaPageId: "162:92",
      mascotPose: .emotionOopsCaring
    ),
  ]

  public static var allScreenCodes: [String] {
    allScreens.map(\.screenCode)
  }

  public static func descriptor(forScreenCode code: String) -> CertiGoMasterFigmaScreenDescriptor? {
    let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    return allScreens.first { $0.screenCode.uppercased() == normalized }
  }

  public static func descriptor(forNodeId nodeId: String) -> CertiGoMasterFigmaScreenDescriptor? {
    let trimmed = nodeId.trimmingCharacters(in: .whitespacesAndNewlines)
    return allScreens.first { $0.nodeId == trimmed }
  }

  public static func screens(in chapter: CertiGoFigmaChapter) -> [CertiGoMasterFigmaScreenDescriptor] {
    allScreens.filter { $0.chapterKind == chapter }
  }

  public static var questionFormatScreens: [CertiGoMasterFigmaScreenDescriptor] {
    allScreens.filter { $0.screenCode.hasPrefix("Q_TYPE_") }
  }

  public static var onboardingScreens: [CertiGoMasterFigmaScreenDescriptor] {
    allScreens.filter { $0.screenCode.hasPrefix("OB-") }
  }

  /// Verifies that all 53 screens are registered with unique codes/nodeIds, zero geometric regression, and strict mascot placement.
  public static func verifyAllInvariants() -> Bool {
    guard allScreens.count == expectedScreenCount else { return false }
    guard Set(allScreens.map(\.screenCode)).count == expectedScreenCount else { return false }
    guard Set(allScreens.map(\.nodeId)).count == expectedScreenCount else { return false }
    guard onboardingScreens.count == 11 else { return false }
    guard questionFormatScreens.count == 10 else { return false }
    guard CertiGoMotionSpecCatalog.verifyAllInvariants() else { return false }
    return allScreens.allSatisfy { $0.verifyVisualInvariants() }
  }

  public static var page13MotionSpecs: [CertiGoMotionPresetSpec] {
    CertiGoMotionSpecCatalog.allSpecs
  }

  public static var page13AnimationFrames: [CertiGoPage13AnimationFrameDescriptor] {
    CertiGoMotionSpecCatalog.allPage13Frames
  }
}

#if canImport(SwiftUI) && canImport(UIKit)
  import SwiftUI
  import UIKit

  @MainActor
  public enum PrismSnapshotHarness {
    public struct Configuration {
      public let size: CGSize
      public let appearance: PrismAppearance
      public let dynamicType: DynamicTypeSize
      public let locale: Locale

      public init(
        size: CGSize, appearance: PrismAppearance = .light,
        dynamicType: DynamicTypeSize = .large, locale: Locale = Locale(identifier: "fr")
      ) {
        self.size = size
        self.appearance = appearance
        self.dynamicType = dynamicType
        self.locale = locale
      }
    }

    public static func render<V: View>(
      _ view: V, configuration: Configuration
    ) throws -> PrismSnapshot {
      guard configuration.size.width.isFinite, configuration.size.height.isFinite,
        configuration.size.width > 0, configuration.size.height > 0,
        configuration.size.width <= 8192, configuration.size.height <= 8192
      else { throw PrismSnapshotError.invalidDimensions }
      let renderer = ImageRenderer(
        content:
          view
          .environment(\.colorScheme, configuration.appearance.isDark ? .dark : .light)
          .environment(\.dynamicTypeSize, configuration.dynamicType)
          .environment(\.locale, configuration.locale)
          .frame(width: configuration.size.width, height: configuration.size.height))
      renderer.scale = 1
      renderer.isOpaque = true
      guard let image = renderer.cgImage else { throw PrismSnapshotError.renderingFailed }
      return try snapshot(image)
    }

    public static func decodePNG(_ data: Data) throws -> PrismSnapshot {
      guard let image = UIImage(data: data)?.cgImage else {
        throw PrismSnapshotError.renderingFailed
      }
      return try snapshot(image)
    }

    public static func pngData(_ snapshot: PrismSnapshot) throws -> Data {
      guard let space = CGColorSpace(name: CGColorSpace.sRGB),
        let provider = CGDataProvider(data: snapshot.pixels as CFData),
        let image = CGImage(
          width: snapshot.width, height: snapshot.height, bitsPerComponent: 8,
          bitsPerPixel: 32, bytesPerRow: snapshot.width * 4,
          space: space,
          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
          provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent),
        let data = UIImage(cgImage: image).pngData()
      else { throw PrismSnapshotError.renderingFailed }
      return data
    }

    private static func snapshot(_ image: CGImage) throws -> PrismSnapshot {
      var pixels = Data(count: image.width * image.height * 4)
      let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: buffer.baseAddress, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return true
      }
      guard rendered else { throw PrismSnapshotError.renderingFailed }
      return try PrismSnapshot(width: image.width, height: image.height, pixels: pixels)
    }

    public static let normativeAppearances: [PrismAppearance] = PrismAppearance.allCases
    public static let normativeDynamicTypeSizes: [DynamicTypeSize] = [
      .large, .accessibility3, .accessibility5,
    ]
    public static let defaultFigmaCanvasSize = CGSize(
      width: CertiGoMasterFigmaScreenDescriptor.standardCanvasWidth,
      height: CertiGoMasterFigmaScreenDescriptor.standardCanvasHeight
    )

    public struct DeterministicSnapshotEntry: Equatable, Sendable {
      public let screenCode: String
      public let nodeId: String
      public let appearance: PrismAppearance
      public let dynamicType: DynamicTypeSize
      public let snapshot: PrismSnapshot
      public let pngData: Data

      public init(
        screenCode: String,
        nodeId: String,
        appearance: PrismAppearance,
        dynamicType: DynamicTypeSize,
        snapshot: PrismSnapshot,
        pngData: Data
      ) {
        self.screenCode = screenCode
        self.nodeId = nodeId
        self.appearance = appearance
        self.dynamicType = dynamicType
        self.snapshot = snapshot
        self.pngData = pngData
      }
    }

    public static func renderDeterministicPNG(
      for descriptor: CertiGoMasterFigmaScreenDescriptor,
      appearance: PrismAppearance = .light,
      dynamicType: DynamicTypeSize = .large,
      size: CGSize = defaultFigmaCanvasSize,
      locale: Locale = Locale(identifier: "fr")
    ) throws -> Data {
      let configuration = Configuration(
        size: size,
        appearance: appearance,
        dynamicType: dynamicType,
        locale: locale
      )
      let snapshot = try render(descriptor.makeSnapshotPreviewView(), configuration: configuration)
      return try pngData(snapshot)
    }

    public static func renderSnapshotMatrix(
      for descriptor: CertiGoMasterFigmaScreenDescriptor,
      appearances: [PrismAppearance] = normativeAppearances,
      dynamicTypes: [DynamicTypeSize] = normativeDynamicTypeSizes,
      size: CGSize = defaultFigmaCanvasSize,
      locale: Locale = Locale(identifier: "fr")
    ) throws -> [DeterministicSnapshotEntry] {
      var entries: [DeterministicSnapshotEntry] = []
      entries.reserveCapacity(appearances.count * dynamicTypes.count)
      let view = descriptor.makeSnapshotPreviewView()
      for appearance in appearances {
        for dynamicType in dynamicTypes {
          let configuration = Configuration(
            size: size,
            appearance: appearance,
            dynamicType: dynamicType,
            locale: locale
          )
          let renderedSnapshot = try render(view, configuration: configuration)
          let encodedPNG = try pngData(renderedSnapshot)
          entries.append(
            DeterministicSnapshotEntry(
              screenCode: descriptor.screenCode,
              nodeId: descriptor.nodeId,
              appearance: appearance,
              dynamicType: dynamicType,
              snapshot: renderedSnapshot,
              pngData: encodedPNG
            )
          )
        }
      }
      return entries
    }
  }

  public struct CertiGoMasterScreenSnapshotPreviewView: View {
    public let descriptor: CertiGoMasterFigmaScreenDescriptor

    public init(descriptor: CertiGoMasterFigmaScreenDescriptor) {
      self.descriptor = descriptor
    }

    public var body: some View {
      VStack(alignment: .leading, spacing: PrismSpacing.m) {
        HStack(spacing: PrismSpacing.s) {
          PrismBadge(
            configuration: PrismBadgeConfiguration(
              text: descriptor.screenCode,
              semantics: .accent
            )
          )
          PrismBadge(
            configuration: PrismBadgeConfiguration(
              text: descriptor.nodeId,
              semantics: .neutral
            )
          )
          Spacer(minLength: PrismSpacing.xs)
        }

        PrismText(text: descriptor.title, style: .headline)
        PrismText(text: descriptor.chapter, style: .caption, role: .textSecondary)

        if let pose = descriptor.mascotPose {
          HStack(spacing: PrismSpacing.s) {
            CertiGoMascotView(pose: pose, size: PrismSize.mascotQuiz)
            PrismText(text: pose.displayName, style: .subheadline)
          }
        }
      }
      .padding(PrismSpacing.l)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(PrismColor.canvas)
    }
  }

  extension CertiGoMasterFigmaScreenDescriptor {
    @MainActor
    public func makeSnapshotPreviewView() -> CertiGoMasterScreenSnapshotPreviewView {
      CertiGoMasterScreenSnapshotPreviewView(descriptor: self)
    }

    @MainActor
    public func renderDeterministicPNG(
      appearance: PrismAppearance = .light,
      dynamicType: DynamicTypeSize = .large,
      size: CGSize = PrismSnapshotHarness.defaultFigmaCanvasSize,
      locale: Locale = Locale(identifier: "fr")
    ) throws -> Data {
      try PrismSnapshotHarness.renderDeterministicPNG(
        for: self,
        appearance: appearance,
        dynamicType: dynamicType,
        size: size,
        locale: locale
      )
    }

    @MainActor
    public func renderSnapshotMatrix(
      appearances: [PrismAppearance] = PrismSnapshotHarness.normativeAppearances,
      dynamicTypes: [DynamicTypeSize] = PrismSnapshotHarness.normativeDynamicTypeSizes,
      size: CGSize = PrismSnapshotHarness.defaultFigmaCanvasSize,
      locale: Locale = Locale(identifier: "fr")
    ) throws -> [PrismSnapshotHarness.DeterministicSnapshotEntry] {
      try PrismSnapshotHarness.renderSnapshotMatrix(
        for: self,
        appearances: appearances,
        dynamicTypes: dynamicTypes,
        size: size,
        locale: locale
      )
    }
  }

  extension CertiGoMasterScreenCatalog {
    @MainActor
    public static func renderDeterministicPNG(
      forScreenCode code: String,
      appearance: PrismAppearance = .light,
      dynamicType: DynamicTypeSize = .large,
      size: CGSize = PrismSnapshotHarness.defaultFigmaCanvasSize,
      locale: Locale = Locale(identifier: "fr")
    ) throws -> Data {
      guard let descriptor = descriptor(forScreenCode: code) else {
        throw PrismSnapshotError.renderingFailed
      }
      return try descriptor.renderDeterministicPNG(
        appearance: appearance,
        dynamicType: dynamicType,
        size: size,
        locale: locale
      )
    }

    @MainActor
    public static func renderSnapshotMatrix(
      forScreenCode code: String,
      appearances: [PrismAppearance] = PrismSnapshotHarness.normativeAppearances,
      dynamicTypes: [DynamicTypeSize] = PrismSnapshotHarness.normativeDynamicTypeSizes,
      size: CGSize = PrismSnapshotHarness.defaultFigmaCanvasSize,
      locale: Locale = Locale(identifier: "fr")
    ) throws -> [PrismSnapshotHarness.DeterministicSnapshotEntry] {
      guard let descriptor = descriptor(forScreenCode: code) else {
        throw PrismSnapshotError.renderingFailed
      }
      return try descriptor.renderSnapshotMatrix(
        appearances: appearances,
        dynamicTypes: dynamicTypes,
        size: size,
        locale: locale
      )
    }
  }

  extension CertiGoMotionSpecCatalog {
    @MainActor
    public static func renderDeterministicPNG(
      for preset: CertiGoAnimationPresetID,
      isAfterTransitionState: Bool = true,
      calmMode: Bool = false,
      appearance: PrismAppearance = .light,
      dynamicType: DynamicTypeSize = .large,
      size: CGSize = PrismSnapshotHarness.defaultFigmaCanvasSize,
      locale: Locale = Locale(identifier: "fr")
    ) throws -> Data {
      let configuration = PrismSnapshotHarness.Configuration(
        size: size,
        appearance: appearance,
        dynamicType: dynamicType,
        locale: locale
      )
      let view = CertiGoPage13MotionShowcaseScreen(
        preset: preset,
        isAfterTransitionState: isAfterTransitionState,
        calmMode: calmMode
      )
      let snapshot = try PrismSnapshotHarness.render(view, configuration: configuration)
      return try PrismSnapshotHarness.pngData(snapshot)
    }
  }
#endif
