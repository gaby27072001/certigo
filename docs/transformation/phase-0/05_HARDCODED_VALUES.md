# 05 — Inventaire des valeurs codées en dur (Étape 5 — Phase 0)

> **Statut :** VÉRIFIÉ (analyse statique automatisée par script Python sur 100 % des fichiers Swift cibles)
> **Branche :** `transform/phase-0-audit` (`HEAD` `778f9c247ceb9c0db29fb931a8573bd328b492ab`)
> **Fichier de données associé :** [`hardcoded_values.csv`](./hardcoded_values.csv) (526 entrées vérifiées, colonnes `fichier,ligne,categorie,valeur,extrait`)

---

## 1. Méthodologie et périmètre exact analysé

### 1.1 Périmètre des fichiers Swift analysés (**VÉRIFIÉ**)

Conformément au cahier des charges de l'Étape 5 (§4 de la Phase 0) et aux règles de garde-fous du §38.2 du Master Prompt, l'analyse statique couvre **100 % des fichiers `.swift`** de `apps/apple/CertigoNative` (incluant `Sources/`, `WidgetExtension/`, ainsi que `DemoTests/` et `ModelTests/`) et de `apps/apple/CertigoKit/Sources/` :

| Sous-périmètre | Nombre de fichiers `.swift` | Nombre total de lignes | Occurrences détectées | Part de la dette |
|---|---:|---:|---:|---:|
| `apps/apple/CertigoNative/Sources/` (code de production app) | 7 | 12 531 | 514 | 97,72 % |
| `apps/apple/CertigoNative/WidgetExtension/` (extension WidgetKit) | 1 | 75 | 2 | 0,38 % |
| `apps/apple/CertigoKit/Sources/` (`CertigoCortex`, `CertigoData`, `CertigoDomain`) | 29 | 8 257 | 10 | 1,90 % |
| **Sous-total production (`CertigoNative` + `CertigoKit/Sources`)** | **37** | **20 863** | **526** | **100,00 %** |
| `apps/apple/CertigoNative/DemoTests/` + `ModelTests/` (tests cibles `CertigoNative`) | 2 | 3 690 | 0 | 0,00 % |
| **Total périmètre `CertigoNative` (complet) + `CertigoKit/Sources/`** | **39** | **24 553** | **526** | **100,00 %** |

*(Pour complétude documentaire : l'arborescence complète `apps/apple/` compte par ailleurs 25 fichiers de tests dans `apps/apple/CertigoKit/Tests/CertigoKitTests/` [6 513 lignes], `apps/apple/CertigoKit/Package.swift` [35 lignes] et `apps/apple/CertigoProtectionDeviceTests/ProtectionTestHost/ProtectionTestHostAppDelegate.swift` [45 lignes], soit **66 fichiers `.swift` et 31 146 lignes** au total dans `apps/apple/`.)*

### 1.2 Règles de détection appliquées (`hardcoded_values.csv`)

L'extracteur Python inspecte chaque ligne non commentée des **39 fichiers Swift** selon les **5 catégories normatives** :

1. **`raw_color`** :
   - littéraux hexadécimaux `0xRRGGBB` (palettes `NativePrism.ink`, `NativePrism.glow`, `NativeEcosystemArtwork.microsoftTileColors` et motifs éditeurs) ;
   - constructeurs RVB bruts `Color(red:green:blue:)`, `Color(.sRGB, red:green:blue:opacity:)` et `UIColor(red:green:blue:alpha:)` ;
   - appels directs à `Color(uiColor: .system...)` dans les vues de fonctionnalités hors `NativePrism` (`.systemRed`, `.systemGroupedBackground`, `.secondarySystemGroupedBackground`, `.tertiarySystemFill`, `.separator`) ;
   - littéraux de couleur SwiftUI utilisés comme couleur d'habillage ou de sémantique (`.orange`, `.white`, `Color.white`) ;
   - opacités numériques codées en dur `.opacity(<littéral>)` (`0.07`, `0.08`, `0.1`, `0.10`, `0.12`, `0.13`, `0.15`, `0.16`, `0.18`, `0.24`, `0.25`, `0.5`).
2. **`raw_typography`** :
   - tailles fixes `.font(.system(size: ...))` (interdites hors `Prism` par §20 et §38.2) ;
   - polices système ad hoc avec design arrondi `.font(.system(.title2, design: .rounded, weight: .bold))` hors `PrismTextStyle` ;
   - surcharges locales de graisse `.fontWeight(...)` et `.font(.<style>.weight(...))` / `.font(.<style>.bold())` hors `PrismTextStyle` ;
   - métriques dynamiques à valeur de base codée en dur `@ScaledMetric(...) private var ... = <littéral>` ;
   - facteurs de réduction `.minimumScaleFactor(<littéral>)` et restrictions de lignes `.lineLimit(<littéral>)` (dont `.lineLimit(1)`).
3. **`raw_spacing_size_radius`** :
   - marges internes numériques `.padding(<littéral>)` et `.padding(.<edge>, <littéral>)` ;
   - espacements de piles et grilles `spacing: <littéral>` (`VStack`, `HStack`, `LazyVGrid`, `HStackLayout`, `VStackLayout`) ;
   - dimensions fixes ou bornées `.frame(width: / height: / minWidth: / minHeight: / maxWidth: / maxHeight: <littéral>)` ;
   - rayons de courbure arbitraires `RoundedRectangle(cornerRadius: <littéral>)`, `.cornerRadius(<littéral>)` et `cornerRadius: <littéral>`.
4. **`raw_animation`** :
   - courbes et durées d'animation littérales (`Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)`).
5. **`unlocalized_string`** :
   - contrôles et conteneurs SwiftUI affichant des littéraux ou formats en dur hors `NativeLabel` / `AppLanguage` : `Text("...")`, `Label("...", ...)`, `Button("...")`, `.navigationTitle("...")`, `.configurationDisplayName("...")`, `.description("...")` ;
   - chaînes visibles en dur dans les structures de présentation et le mode Démo (`NativeRadarCategory.title`, `NativeActivityDestination.resumeTitle`, `NativeShowcaseTile`, `DemoCatalogScenario`, `DemoSocialSection`, `NativeDemoFlow`, `NativeDemoPractice`, `NativeShowcaseUniverse`, `NativeLessonReadingContent`) ainsi que les messages `LocalizedError.errorDescription` en anglais seul dans `CIAMConfigurationEnvironment.swift`.
   - *Note :* les dictionnaires de traduction légitimes (`enum NativeLabel` aux lignes 313–2755 de `CertigoNativeApp.swift`, `AppLanguage.swift`, `CertigoAppIconCopy` dans `CertigoAppIconSelection.swift`, `CertigoWidgetCopy` dans `CertigoWidgetSnapshot.swift`), les `accessibilityIdentifier` techniques et les noms de SF Symbols (`systemName:` / `systemImage:`) sont exclus des faux positifs.

---

## 2. Synthèse globale par catégorie (**VÉRIFIÉ**)

| Catégorie | Occurrences (`hardcoded_values.csv`) | Part du total | Fichiers touchés (sur 39) | Cible de remplacement Prism (§18–21, §25, §38.2) |
|---|---:|---:|---:|---|
| `raw_spacing_size_radius` | **260** | 49,43 % | 4 | `PrismSpacing` (`xxs`..`giant`), `PrismRadius` (`s`..`xl`, `capsule`), `PrismSize` (`minTouch`, `primaryButtonHeight`, `readableWidth`, `brandS`..`brandXL`) |
| `raw_color` | **103** | 19,58 % | 3 | `PrismColorRole` (`canvas`, `surface`, `surfaceRaised`, `surfaceArtifact`, `textPrimary`..`caution`), `PrismRegion` (+ `.soft`), `PrismSyntax` dans `Prism.xcassets` |
| `raw_typography` | **81** | 15,40 % | 4 | `PrismTextStyle` (`display`, `title1`..`caption`, `editorial`, `code`, `codeSmall`, `numeric`) et composant `PrismText` |
| `unlocalized_string` | **81** | 15,40 % | 5 | Catalogue de chaînes localisées 8 langues (`fr`, `en`, `hi`, `zh-Hans`, `ko`, `es`, `it`, `de`) + retrait des textes Démo en dur (DR-009) |
| `raw_animation` | **1** | 0,19 % | 1 | `PrismMotionToken` (`quick`, `snappy`, `smooth`, `expressive`) résolu selon `accessibilityReduceMotion` |
| **TOTAL** | **526** | **100,00 %** | **6** | **0 valeur brute hors `Prism/` vérifiée par `ArchitectureTests` (§38.2)** |

> **Constat structurel majeur :** En raison de l'architecture monolithique actuelle (H3), **6 fichiers seulement sur 39** concentrent 100 % des 526 valeurs codées en dur, et le seul fichier `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift` (8 565 lignes) en regroupe **390 (74,14 %)**. Les 33 autres fichiers Swift (couche `NativeModel`, authentification MSAL, Keychain, et 28 des 29 fichiers de `CertigoKit/Sources/` ainsi que les 2 fichiers de tests `CertigoNative`) présentent **0 occurrence** de dette UI/chaînes codées en dur.

---

## 3. Classement des fichiers Swift les plus endettés (Top 20 et inventaire complet des 39 fichiers)

### 3.1 Top 20 des fichiers `.swift` par nombre de valeurs codées en dur (**VÉRIFIÉ**)

| Rang | Fichier | Lignes | `raw_color` | `raw_typography` | `raw_spacing_size_radius` | `raw_animation` | `unlocalized_string` | **Total** |
|---:|---|---:|---:|---:|---:|---:|---:|---:|
| **1** | [`apps/apple/CertigoNative/Sources/CertigoNativeApp.swift`](../../../apps/apple/CertigoNative/Sources/CertigoNativeApp.swift) | 8 565 | 83 | 46 | 195 | 1 | 65 | **390** |
| **2** | [`apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift`](../../../apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift) | 284 | 10 | 26 | 28 | 0 | 2 | **66** |
| **3** | [`apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift`](../../../apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift) | 604 | 10 | 6 | 24 | 0 | 2 | **42** |
| **4** | [`apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift`](../../../apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift) | 375 | 0 | 3 | 13 | 0 | 0 | **16** |
| **5** | [`apps/apple/CertigoKit/Sources/CertigoData/CIAMConfigurationEnvironment.swift`](../../../apps/apple/CertigoKit/Sources/CertigoData/CIAMConfigurationEnvironment.swift) | 237 | 0 | 0 | 0 | 0 | 10 | **10** |
| **6** | [`apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift`](../../../apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift) | 75 | 0 | 0 | 0 | 0 | 2 | **2** |
| **7** | [`apps/apple/CertigoNative/Sources/NativeModel.swift`](../../../apps/apple/CertigoNative/Sources/NativeModel.swift) | 2 412 | 0 | 0 | 0 | 0 | 0 | **0** |
| **8** | [`apps/apple/CertigoKit/Sources/CertigoDomain/AppLanguage.swift`](../../../apps/apple/CertigoKit/Sources/CertigoDomain/AppLanguage.swift) | 2 147 | 0 | 0 | 0 | 0 | 0 | **0** |
| **9** | [`apps/apple/CertigoKit/Sources/CertigoDomain/CertigoWidgetSnapshot.swift`](../../../apps/apple/CertigoKit/Sources/CertigoDomain/CertigoWidgetSnapshot.swift) | 542 | 0 | 0 | 0 | 0 | 0 | **0** |
| **10** | [`apps/apple/CertigoKit/Sources/CertigoDomain/Contracts.swift`](../../../apps/apple/CertigoKit/Sources/CertigoDomain/Contracts.swift) | 524 | 0 | 0 | 0 | 0 | 0 | **0** |
| **11** | [`apps/apple/CertigoKit/Sources/CertigoData/CertigoAPI.swift`](../../../apps/apple/CertigoKit/Sources/CertigoData/CertigoAPI.swift) | 464 | 0 | 0 | 0 | 0 | 0 | **0** |
| **12** | [`apps/apple/CertigoKit/Sources/CertigoData/RuntimeContentStore.swift`](../../../apps/apple/CertigoKit/Sources/CertigoData/RuntimeContentStore.swift) | 430 | 0 | 0 | 0 | 0 | 0 | **0** |
| **13** | [`apps/apple/CertigoKit/Sources/CertigoData/RuntimeDisk.swift`](../../../apps/apple/CertigoKit/Sources/CertigoData/RuntimeDisk.swift) | 409 | 0 | 0 | 0 | 0 | 0 | **0** |
| **14** | [`apps/apple/CertigoKit/Sources/CertigoData/LearningClient.swift`](../../../apps/apple/CertigoKit/Sources/CertigoData/LearningClient.swift) | 407 | 0 | 0 | 0 | 0 | 0 | **0** |
| **15** | [`apps/apple/CertigoKit/Sources/CertigoData/PublicResourceReader.swift`](../../../apps/apple/CertigoKit/Sources/CertigoData/PublicResourceReader.swift) | 334 | 0 | 0 | 0 | 0 | 0 | **0** |
| **16** | [`apps/apple/CertigoKit/Sources/CertigoCortex/Cortex.swift`](../../../apps/apple/CertigoKit/Sources/CertigoCortex/Cortex.swift) | 252 | 0 | 0 | 0 | 0 | 0 | **0** |
| **17** | [`apps/apple/CertigoKit/Sources/CertigoData/PublicReleaseContracts.swift`](../../../apps/apple/CertigoKit/Sources/CertigoData/PublicReleaseContracts.swift) | 247 | 0 | 0 | 0 | 0 | 0 | **0** |
| **18** | [`apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift`](../../../apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift) | 243 | 0 | 0 | 0 | 0 | 0 | **0** |
| **19** | [`apps/apple/CertigoKit/Sources/CertigoDomain/CertigoAppIconSelection.swift`](../../../apps/apple/CertigoKit/Sources/CertigoDomain/CertigoAppIconSelection.swift) | 231 | 0 | 0 | 0 | 0 | 0 | **0** |
| **20** | [`apps/apple/CertigoKit/Sources/CertigoDomain/LearningServices.swift`](../../../apps/apple/CertigoKit/Sources/CertigoDomain/LearningServices.swift) | 221 | 0 | 0 | 0 | 0 | 0 | **0** |

### 3.2 Fichiers 21 à 39 du périmètre (tous à 0 dette UI codée en dur — **VÉRIFIÉ**)

| Rang | Fichier | Lignes | Statut |
|---:|---|---:|---|
| 21 | `apps/apple/CertigoKit/Sources/CertigoData/CanonicalQuestionReader.swift` | 217 | 0 occurrence (lecteur JSON canonique pur) |
| 22 | `apps/apple/CertigoKit/Sources/CertigoDomain/SmartReviewAdvisor.swift` | 196 | 0 occurrence (logique de révision pure) |
| 23 | `apps/apple/CertigoKit/Sources/CertigoData/OfflineQuestionPack.swift` | 194 | 0 occurrence (stockage packs hors ligne) |
| 24 | `apps/apple/CertigoKit/Sources/CertigoData/SubmissionStore.swift` | 186 | 0 occurrence (file d'idempotence des soumissions) |
| 25 | `apps/apple/CertigoKit/Sources/CertigoData/CertigoWidgetStore.swift` | 167 | 0 occurrence (stockage snapshot App Group) |
| 26 | `apps/apple/CertigoKit/Sources/CertigoData/BoundedHTTPTransport.swift` | 152 | 0 occurrence (transport HTTP borné) |
| 27 | `apps/apple/CertigoKit/Sources/CertigoData/PublicReleaseAPI.swift` | 135 | 0 occurrence (client API release publique) |
| 28 | `apps/apple/CertigoKit/Sources/CertigoData/CIAMConfiguration.swift` | 122 | 0 occurrence (validation de configuration CIAM) |
| 29 | `apps/apple/CertigoKit/Sources/CertigoData/LearningHistoryPresentation.swift` | 90 | 0 occurrence (agrégation d'historique) |
| 30 | `apps/apple/CertigoKit/Sources/CertigoData/AccountDeletion.swift` | 86 | 0 occurrence (preuve de suppression de compte) |
| 31 | `apps/apple/CertigoKit/Sources/CertigoDomain/CertigoStudyPlanPreference.swift` | 52 | 0 occurrence (modèle de plan d'étude) |
| 32 | `apps/apple/CertigoKit/Sources/CertigoData/CertigoAppIconPreferenceStore.swift` | 50 | 0 occurrence (persistance d'icône d'application) |
| 33 | `apps/apple/CertigoKit/Sources/CertigoData/FileProtectionPolicy.swift` | 48 | 0 occurrence (politique `NSFileProtectionComplete`) |
| 34 | `apps/apple/CertigoNative/Sources/CredentialVault.swift` | 48 | 0 occurrence (Keychain natif) |
| 35 | `apps/apple/CertigoKit/Sources/CertigoDomain/EditorialPilotLessonLink.swift` | 46 | 0 occurrence (routeur de lien profond pilote) |
| 36 | `apps/apple/CertigoKit/Sources/CertigoData/CIAMDevelopmentCandidate.swift` | 37 | 0 occurrence (candidat CIAM dev) |
| 37 | `apps/apple/CertigoKit/Sources/CertigoData/CIAMAuthenticationFailure.swift` | 34 | 0 occurrence (classification d'erreur MSAL) |
| 38 | `apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift` | 892 | 0 occurrence (tests unitaires Démo) |
| 39 | `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift` | 2 798 | 0 occurrence (tests unitaires `NativeModel`) |

### 3.3 Ventilation interne du monolithe `CertigoNativeApp.swift` (par sous-ensemble logique)

Comme `CertigoNativeApp.swift` regroupe à lui seul 390 occurrences, le tableau ci-dessous détaille où se concentre la dette à l'intérieur de ce fichier pour préparer son découpage en Phase 1 :

| Plage de lignes | Sous-ensemble / Vues dans `CertigoNativeApp.swift` | `raw_color` | `raw_typography` | `raw_spacing_size_radius` | `raw_animation` | `unlocalized_string` | **Total** |
|---|---|---:|---:|---:|---:|---:|---:|
| `L1–L312` | `NativeRadarCategory`, `NativeTrackAppearance`, `NativeActivityDestination` | 0 | 0 | 0 | 0 | 8 | **8** |
| `L2756–L3064` | `NativeContentLanguageBadges`, `NativeStudyPlanView`, `NativeMockExamView`, `NativeNotificationPreferencesView` | 0 | 8 | 3 | 0 | 1 | **12** |
| `L3125–L3282` | `NativeAppLanguagePicker`, `NativePrism`, `NativeTrackTheme`, `NativeSymbolMedallion` | 18 | 1 | 5 | 1 | 0 | **25** |
| `L3284–L3760` | `NativeEcosystemArtwork`, `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCertificationCrest`, `NativeShowcaseTile` | 37 | 4 | 18 | 0 | 1 | **60** |
| `L3762–L4140` | `NativeReadinessRing`, `NativeMetricTile`, `NativeGoalHero`, `NativeCertificationCard`, `NativeAnswerLabel`, `NativeQuestionProgress`, `NativeReadingPage`, `NativePrimaryButton`, `NativeChoiceButtonStyle`, `NativeEntryHeading` | 15 | 13 | 47 | 0 | 1 | **76** |
| `L4142–L4582` | `NativeEntry`, `NativeProductionEntry`, `NativeDeveloperConnector` | 0 | 0 | 18 | 0 | 7 | **25** |
| `L4584–L5645` | `NativeDemoRoot`, composants `Demo*`, `NativeDemoFlow`, `NativeDemoPractice` | 9 | 12 | 58 | 0 | 39 | **118** |
| `L5830–L8565` | `NativeAccountDeletionView`, `NativeRoot` (4 onglets production), `NativeLessonAudioControls`, `NativeLessonReadingContent` | 4 | 8 | 46 | 0 | 8 | **66** |
| **Total** | **`CertigoNativeApp.swift`** | **83** | **46** | **195** | **1** | **65** | **390** |

---

## 4. Analyse détaillée et exemples représentatifs par catégorie

### 4.1 Couleurs brutes (`raw_color` — 103 occurrences)

1. **Palettes hexadécimales codées en dur dans le code Swift au lieu d'un Asset Catalog (`Prism.xcassets`) :**
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3167` : `0x3B35F2, 0x901BAE, 0xA91A66, 0x924A13, 0x177331, 0x176C7A, 0x1562AA` (`NativePrism.ink` — 7 entiers hexadécimaux qui ne correspondent pas aux valeurs normatives WCAG du §21 du Master Prompt : ex. `#3B35F2` au lieu de `#4338CA` pour `accent`).
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3170` : `0x8097F8, 0xD764F8, 0xF95DA5, 0xEC7B26, 0x2DBC55, 0x2CB0C7, 0x52A2F8` (`NativePrism.glow`).
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3292` : `0xF25022, 0x7FBA00, 0x00A4EF, 0xFFB900` (couleurs officielles du logo Microsoft à 4 carrés recodées en dur dans `NativeEcosystemArtwork.microsoftTileColors`).
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3307-3355` : 28 valeurs hexadécimales imitant les chartes GitHub (`0x24292F, 0x8534F3, 0xBF3989, 0x2DA44E`), AWS (`0x232F3E, 0xFF9900`), Google (`0x4285F4, 0xEA4335, 0xFBBC05, 0x34A853`), Microsoft Fabric (`0x00B7C3, 0x117865, 0x79E7C5`), Microsoft Security (`0x008559, 0x0078D4, 0xA5E8D1`), Azure (`0x0078D4, 0x50E6FF, 0x00A4EF`), CompTIA (`0xC8102E, 0xF58CA1, 0x54253F`) et Kubernetes/CNCF (`0x326CE5, 0x8DD9FF, 0x5962B8`).
2. **Constructeurs RVB flottants dans les widgets et la galerie :**
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:43-46` :
     ```swift
     case .readyToStart: Color(red: 0.12, green: 0.48, blue: 0.91)
     case .inProgress: Color(red: 0.19, green: 0.57, blue: 0.87)
     case .streakAtRisk: Color(red: 0.91, green: 0.36, blue: 0.20)
     case .goalCompleted: Color(red: 0.16, green: 0.62, blue: 0.42)
     ```
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:270-271` : dégradé `CertigoWidgetMark` avec `Color(red: 0.12, green: 0.48, blue: 0.91)` et `Color(red: 0.31, green: 0.39, blue: 0.87)`.
   - `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:301` : `static let accent = Color(red: 0.12, green: 0.48, blue: 0.91)`.
3. **Littéraux SwiftUI et `UIColor` système hors `Prism` :**
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5147` : `Image(systemName: "clock.fill").foregroundStyle(.orange)`
   - `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:109,153` : `.foregroundStyle(.orange)` pour les messages d'erreur (au lieu de `PrismColorRole.caution` ou `negative`).
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:6933` : `case .weak: Color(uiColor: .systemRed)` (sans jeton `PrismColorRole.negative`).
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4995,5030,5120,5127,5217,5230,5300,5335` : `Color(uiColor: .systemGroupedBackground)` / `.secondarySystemGroupedBackground` / `.separator` appelés directement dans `NativeDemoRoot` au lieu de passer par les tokens `Prism`.
4. **Opacités magiques dispersées (`.opacity(<littéral>)`) :**
   - 26 occurrences avec 11 valeurs distinctes (`0.07`, `0.08`, `0.1`, `0.10`, `0.12`, `0.13`, `0.15`, `0.16`, `0.18`, `0.24`, `0.25`, `0.5`), ex. `CertigoNativeApp.swift:3278` (`accent.opacity(0.12)`), `CertigoNativeApp.swift:3930` (`theme.accent.opacity(0.24)`), `NativeWidgetGalleryView.swift:78` (`Color.secondary.opacity(0.07)`), alors que le §21 fixe normativement les variantes `soft` à **12 % en clair et 20 % en sombre**.

### 4.2 Typographie brute (`raw_typography` — 81 occurrences)

1. **Tailles fixes `.font(.system(size: ...))` (violation directe de Dynamic Type et du §20) :**
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:181` : `.font(.system(size: 14, weight: .bold))`
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:184` : `.font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())`
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:256` : `.font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())`
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:278` : `.font(.system(size: 11, weight: .bold))`
2. **Design `.rounded` ad hoc (contraire à la direction éditoriale SF Pro / SF Serif / SF Mono du §20) :**
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3717,3799,3821,3889,3909,3914,3947` : 7 usages de `.font(.system(.caption / .title2 / .title3 / .headline, design: .rounded, weight: .bold))`.
3. **Réduction forcée d'échelle et troncature à 1 ligne (`minimumScaleFactor` / `lineLimit`) :**
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:100,136,257` : `.minimumScaleFactor(0.8)` (×2) et `.minimumScaleFactor(0.75)` (×1).
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:112,141,162,206` : `.lineLimit(1)` (×4), plus `.lineLimit(2)` aux lignes `99,135` et `.lineLimit(3)` à la ligne `220`.
   - `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:71,177` : `.lineLimit(2)` sur les boutons de phase et les titres de variantes d'icône (risque de troncature en `AX3`).
4. **Surcharges locales de graisse hors `PrismTextStyle` (56 occurrences) :**
   - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5375` : `.fontWeight(state == .current ? .semibold : .regular)`
   - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:201` : `.fontWeight(.semibold)`
   - `apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift:256` : `.fontWeight(.medium)`
   - 53 appels `.font(.<style>.weight(...))` ou `.font(.<style>.bold())` dispersés dans `CertigoNativeApp.swift` (37), `CertigoWidgetPresentation.swift` (10), `NativeWidgetGalleryView.swift` (4) et `NativeEditorialPilotView.swift` (2).

### 4.3 Espacements, tailles et rayons arbitraires (`raw_spacing_size_radius` — 260 occurrences)

1. **Rayons de courbure hors grille `PrismRadius` (`8, 12, 16, 24`) :**
   - `CertigoWidgetPresentation.swift:266` : `RoundedRectangle(cornerRadius: 7, style: .continuous)` (`7` hors grille).
   - `NativeWidgetGalleryView.swift:79,202,204,102` : `cornerRadius: 13`, `cornerRadius: 15` (×2), `cornerRadius: 22` — aucune de ces 3 valeurs n'appartient à `PrismRadius` (`8, 12, 16, 24`).
   - `CertigoNativeApp.swift:3278,3742,3756,3830,3888,3929,3952,4060,4083,4111,4869` : `cornerRadius: 18` (`NativeSymbolMedallion`, `NativeChoiceButtonStyle`, `NativePrimaryButton`), `cornerRadius: 20` (`NativeShowcaseTile`, `NativeMetricTile`), `cornerRadius: 22` (`NativeReadingCard`), `cornerRadius: 24` (`NativeCertificationCard`), `cornerRadius: 26` (`NativeShowcaseTile`), `cornerRadius: 28` (`NativeGoalHero`).
2. **Marges internes `.padding(<littéral>)` hors grille `PrismSpacing` (`2, 4, 8, 12, 16, 20, 24, 32, 48, 64`) :**
   - `NativeWidgetGalleryView.swift:74,196,232,233` : `.padding(10)`, `.padding(9)`, `.padding(.horizontal, 13)`, `.padding(.vertical, 9)`.
   - `CertigoWidgetPresentation.swift:120,222` : `.padding(14)`.
   - `CertigoNativeApp.swift:3704,3705,3721,3911,3975,4002` : `.padding(6)`, `.padding(compact ? 10 : 16)`, `.padding(.vertical, 6)`, `.padding(.horizontal, 10)`.
3. **Espacements `spacing: <littéral>` hors grille `PrismSpacing` :**
   - `CertigoWidgetPresentation.swift:85,102,124,125,152,195,196` : `spacing: 10`, `spacing: 9`, `spacing: 18`, `spacing: 6`, `spacing: 3`, `spacing: 5`.
   - `NativeWidgetGalleryView.swift:59,64,124,140,166` : `spacing: 10`, `spacing: 7`, `spacing: 14`, `spacing: 9`.
   - `CertigoNativeApp.swift:3904,3940,4014,4040,4054` : `spacing: 14`, `spacing: 18`.
4. **Dimensions fixes `.frame(...)` :**
   - Cibles tactiles codées en dur `.frame(minHeight: 44)` / `.frame(minWidth: 44, minHeight: 44)` répétés **54 fois** à la main dans `CertigoNativeApp.swift` et `NativeEditorialPilotView.swift` au lieu d'utiliser `PrismSize.minTouch`.
   - Tailles d'icônes et de cartes en dur : `.frame(width: 200)` (`CertigoNativeApp.swift:3754`), `.frame(maxWidth: 760)` (`CertigoNativeApp.swift:4017` et `5228`, alors que `PrismSize.readableWidth` est fixé normativement à **672 pt** au §18), `.frame(width: 34, height: 34)` (`CertigoNativeApp.swift:3948`), `.frame(width: 52, height: 52)` (`CertigoNativeApp.swift:3277`, `NativeWidgetGalleryView.swift:170`).

### 4.4 Animations codées en dur (`raw_animation` — 1 occurrence)

- `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3183` :
  ```swift
  static let feedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
  ```
  Défini dans `NativePrism` et utilisé aux lignes `3805` (`NativeReadinessRing`) et `4116` (`NativeChoiceButtonStyle`) avec garde `reduceMotion ? nil : NativePrism.feedback`. Doit être remplacé par `PrismMotionToken` (`quick`, `snappy`, `smooth`, `expressive`) au §18 et §25.

### 4.5 Chaînes d'interface non localisées (`unlocalized_string` — 81 occurrences)

1. **Catégories Radar en anglais seul (`CertigoNativeApp.swift:14-20`) :**
   - `"Cloud platforms"`, `"AI & foundation models"`, `"Apple & mobile"`, `"Data & analytics"`, `"DevOps & cloud native"`, `"Security & networking"`, `"Enterprise & delivery"` dans `NativeRadarCategory.title` (propriété non localisée coexistant avec `func title(_ copy: AppInterfaceCopy)`).
2. **Titre d'action en anglais seul (`CertigoNativeApp.swift:199`) :**
   - `var resumeTitle: String { "Resume \(title)" }` dans `NativeActivityDestination`.
3. **Bouton d'accès au pilote éditorial en français seul (`CertigoNativeApp.swift:6564`) :**
   - `Button("Assistants IA responsables", systemImage: "text.book.closed")` affiché dans l'onglet `Apprendre` quelle que soit la langue choisie parmi les 8 langues de l'application.
4. **Titres de sections de lecture audio en français seul (`CertigoNativeApp.swift:8481,8484,8491`) :**
   - `.title("Idées clés")`, `parts.append(.title("Exemple résolu"))`, `parts.append(.title("À retenir"))` dans `NativeLessonReadingContent`, lus par `AVSpeechSynthesizer` même si l'interface est configurée dans une autre langue.
5. **Scénarios et contenus complets du mode Démo en français ou anglais seul (`CertigoNativeApp.swift:4585-4593, 5476-5643`) :**
   - `DemoCatalogScenario` (`"Available"`, `"Loading"`, `"Empty"`, `"Error"`) et `DemoSocialSection` (`"Friends"`, `"Teams"`).
   - `NativeDemoFlow.Objective` (`"Cloud · découverte"`, `"Cloud · exploitation"`, `"Les fondamentaux du cloud"`, `"Les services cloud au quotidien"`), `NativeDemoFlow.options` (3 options en français) et `NativeDemoPractice.fundamentals` / `.operations` (26 chaînes pédagogiques en français codées en dur dans le binaire).
6. **Tuiles d'écosystèmes et univers (`CertigoNativeApp.swift:4180-4183, 6385-6388`) :**
   - `"Microsoft Azure"`, `"GitHub & Copilot"`, `"Microsoft Fabric"`, `"Data & Fabric"`, `"AWS"` (dont `"GitHub & Copilot"` et `"Data & Fabric"` qui mélangent deux marques ou concepts hors nomenclature officielle §22A.7).
7. **Extension WidgetKit en anglais seul (`CertigoWidgetExtension.swift:62-63`) :**
   - `.configurationDisplayName("Certigo")` et `.description("A gentle reminder of your learning progress.")` non localisés dans la galerie de widgets iOS.
8. **Messages d'erreur `CIAMConfigurationEnvironmentError` en anglais seul (`CIAMConfigurationEnvironment.swift:18-36`) :**
   - 10 chaînes `errorDescription` en anglais (`"CERTIGO_CIAM_ENABLED must be exactly true or false."`, `"Microsoft production sign-in is available only in the Distribution build."`, etc.).

---

## 5. Plan de résorption vers `Prism` (§18 et §38.2)

### 5.1 Table de correspondance Current → Tokens `Prism` (§18)

| Valeur actuelle codée en dur | Occurrences | Token / Composant `Prism` cible (§18–21) | Phase de résorption |
|---|---:|---|---|
| `NativePrism.ink` / `glow` + `Color(red:...)` + `Color(uiColor:...)` + `.orange` / `.white` | 49 | `PrismColorRole` (`canvas`, `surface`, `surfaceRaised`, `surfaceArtifact`, `textPrimary`, `textSecondary`, `textTertiary`, `separator`, `accent`, `accentFill`, `onAccent`, `positive`, `negative`, `caution`) + `PrismRegion` dans `Prism.xcassets` (4 variantes : Any / Dark / High Contrast / Dark High Contrast) | Phase 1 (tokens) & Phase 2–3 (composants/écrans) |
| Couleurs hexadécimales d'éditeurs dans `NativeEcosystemArtwork` (`0xF25022`, `0xFF9900`, `0x4285F4`…) | 28 | **Suppression totale** de `NativeEcosystemArtwork` ; remplacement par les actifs officiels non modifiés de `BrandAssets.xcassets` sur plaque neutre `PrismColor.brandPlate` (§22A.6) ou `BrandFallbackMark` | Étape 2B |
| `.opacity(0.07..0.5)` (26 occurrences) | 26 | Variantes `PrismRegion.*.soft` (12 % clair / 20 % sombre, §21) et tokens de bordure/surface `PrismColorRole` | Phase 1–2 |
| `.font(.system(size: 11/14/15))` + `.font(.system(..., design: .rounded))` + `.fontWeight(...)` + `.font(.<style>.weight(...))` | 67 | `PrismTextStyle` (`display`, `title1`, `title2`, `title3`, `headline`, `body`, `editorial`, `callout`, `subheadline`, `footnote`, `caption`, `code`, `codeSmall`, `numeric`) via `PrismText` (SF Pro / SF Serif / SF Mono, 0 design `.rounded`, 0 taille fixe) | Phase 1–2 |
| `.lineLimit(1/2/3)` + `.minimumScaleFactor(0.75/0.8)` + `@ScaledMetric` ad hoc | 14 | Layouts adaptatifs `ViewThatFits` / `AnyLayout` aux tailles `accessibility1..5` (§20 & §28) ; `PrismTextStyle.display` seul autorisé à utiliser `@ScaledMetric(relativeTo: .largeTitle)` | Phase 2 |
| `.padding(2/4/6/8/9/10/12/13/14/16/20/24)` et `spacing: 0..20` | 142 | `PrismSpacing` (`xxs=2`, `xs=4`, `s=8`, `m=12`, `l=16`, `xl=20`, `xxl=24`, `xxxl=32`, `huge=48`, `giant=64`) : arrondir `6→xs(4)/s(8)`, `7/9/10→s(8)/m(12)`, `13/14→m(12)/l(16)`, `18→l(16)/xl(20)` | Phase 1–3 |
| `RoundedRectangle(cornerRadius: 7/12/13/15/18/20/22/24/26/28)` | 24 | `PrismRadius` (`s=8`, `m=12`, `l=16`, `xl=24`, `.capsule`, coins continus `.continuous`) | Phase 1–2 |
| `.frame(minHeight: 44)` / `.frame(maxWidth: 760)` / `.frame(width:height:)` | 94 | `PrismSize.minTouch` (`44`), `PrismSize.primaryButtonHeight` (`50`), `PrismSize.readableWidth` (`672` au lieu de `760`), `PrismSize.brandS/M/L/XL` (`20/28/40/56`) | Phase 1–2 |
| `Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)` | 1 | `PrismMotionToken` (`quick`, `snappy`, `smooth`, `expressive`) centralisé avec respect automatique de `accessibilityReduceMotion` | Phase 1 |
| Chaînes non localisées (`unlocalized_string`) | 81 | Bascule dans le catalogue localisé 8 langues (`AppLanguage` / `.xcstrings`) pour les chaînes de production ; extraction/suppression du mode Démo hors build de production (DR-009) | Phase 1–3 |

### 5.2 Garde-fous automatisés en CI (`ArchitectureTests` — §38.2, Phase 1)

Dès la Phase 1, le target `ArchitectureTests` exécutera un lint statique sur tous les fichiers Swift hors `apps/apple/CertigoKit/Sources/Prism/` et échouera sur toute régression :
- **Interdits couleurs :** `Color(red:`, `Color(.sRGB`, `Color(hue:`, `Color(#`, `UIColor(red:`, `0x[0-9A-Fa-f]{6}`, `.indigo`, `.blue`, `.purple`, `.orange`, `.green`, `.red`, `.yellow`, `.teal`, `.cyan`, `.mint`, `.pink`, `.opacity(`.
- **Interdits typographie :** `.font(.system(size:`, `design: .rounded`, `Font.custom(`, `.fontWeight(`, `.minimumScaleFactor(`.
- **Interdits géométrie :** `.padding(<littéral>)`, `spacing: <littéral>`, `.frame(width: <littéral> / height: <littéral>)`, `cornerRadius: <littéral>`, `.cornerRadius(<littéral>)`.
- **Interdits animation & haptique :** `Animation.timingCurve(`, `withAnimation(.easeIn...(duration:`, `.spring(response:`, `UIImpactFeedbackGenerator(`.
- **Interdits localisation :** `Text("...")`, `Label("...")`, `Button("...")`, `.navigationTitle("...")` avec littéral non localisé dans le code de production.
