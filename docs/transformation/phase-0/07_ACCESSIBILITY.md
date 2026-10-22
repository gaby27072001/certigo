# Phase 0 — Étape 7 : Audit détaillé d'accessibilité (Dynamic Type, VoiceOver, Contraste, Cibles tactiles, Transparence)

> **Branche auditée :** `transform/phase-0-audit` (`HEAD` `778f9c247ceb9c0db29fb931a8573bd328b492ab`)
> **Périmètre :** 100 % des écrans, vues, feuilles et widgets inventoriés dans `03_SCREENS_AND_ROUTES.md` (`apps/apple/CertigoNative/Sources/*.swift`, `apps/apple/CertigoNative/WidgetExtension/*.swift`).
> **Règle Phase 0 :** lecture seule stricte — aucun fichier existant modifié.

---

## 1. Légende épistémique et statut de l'hypothèse H4

- **VÉRIFIÉ :** constat observé dans le code source Swift et vérifié par la suite de tests statiques (`tools/tests/test_native_prism_presentation.py`).
- **INFÉRÉ :** comportement de mise en page aux tailles d'accessibilité extrêmes (`AX3` / `AX5` = `accessibilityExtraExtraExtraLarge` / `accessibility5`) déduit des modificateurs `.frame`, `HStack`, `lineLimit`, `@ScaledMetric` et `ViewThatFits`.
- **NON VÉRIFIABLE / NON EXÉCUTÉ — macOS/Xcode requis :** exécution en direct de `XCUIApplication().performAccessibilityAudit()` sur simulateur iOS et parcours VoiceOver interactif sur appareil.

### Statut de l'hypothèse H4 (`@Environment(\.accessibilityContrast)`) (**VÉRIFIÉ — DÉJÀ CORRIGÉ DANS HEAD**)
- L'hypothèse H4 signalait un échec de compilation le 22/10/2026 sur `CertigoNativeApp.swift:3683` dû à `@Environment(\.accessibilityContrast)`.
- Dans `HEAD` (`778f9c247ceb9c0db29fb931a8573bd328b492ab`), ce bug a **déjà été corrigé** par le commit `f6dd2ea7` (PR #99) :
  - Preuve exacte : `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3683` déclare `@Environment(\.colorSchemeContrast) private var contrast` et `:3699` teste `contrast == .increased`.
  - Preuve de non-régression : `tools/tests/test_native_prism_presentation.py:362-366` vérifie la présence de `@Environment(\.colorSchemeContrast)` et l'absence de `@Environment(\.accessibilityContrast)`.

---

## 2. Dynamic Type (`@Environment(\.dynamicTypeSize)`, `@ScaledMetric`, `ViewThatFits`, `AnyLayout`, troncatures et tailles fixes)

### 2.1 Inventaire des mécanismes adaptatifs existants (**VÉRIFIÉ**)

| Mécanisme SwiftUI | `fichier:ligne` | Composant / Vue | Comportement observé |
|---|---|---|---|
| `@Environment(\.dynamicTypeSize)` + `typeSize.isAccessibilitySize` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3838, 3845` | `NativeMetricGrid` | Bascule `LazyVGrid` de **2 colonnes** à **1 colonne** dès que `typeSize.isAccessibilitySize == true`. Utilisé dans `learning` (`:6440`), `rewards` (`:7290`), `questCards` (`:7319`) et `activityMetrics` (`:7343`). |
| `@ScaledMetric(relativeTo: .headline)` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3684, 3708-3709` | `NativeCertificationCrest` | `emblemSize = 70.0`, borné par `min(112, emblemSize) * (compact ? 0.65 : 1)` pour ne pas écraser la colonne de lecture à AX5. |
| `@ScaledMetric(relativeTo: .title2)` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3786, 3802` | `NativeReadinessRing` | `diameter = 88.0`, appliqué à `.frame(width: diameter, height: diameter)` (**sans plafond** `min(...)` : à AX5, le diamètre dépasse ~180 pt). |
| `ViewThatFits(in: .horizontal)` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3860-3875` | `NativeGoalHero` | Bascule de `HStack(spacing: 24)` à `VStack(alignment: .leading, spacing: 24)` quand le titre et le `NativeReadinessRing` ne tiennent plus côte à côte. |
| `ViewThatFits(in: .horizontal)` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5358-5361` | `DemoPracticeTrail` | Bascule le rail des 3 étapes de `HStack(spacing: 16)` à `VStack(alignment: .leading, spacing: 8)`. |
| `ViewThatFits(in: .horizontal)` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:7375-7392` | `NativeRoot.activityStrip` | Bascule le bandeau XP + série de `HStack(spacing: 20)` (icône + chiffre) à `VStack(alignment: .leading, spacing: 12)` (libellé complet + chiffre). |
| `ViewThatFits(in: .horizontal)` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:8276-8279` | `NativeLessonAudioControls` | Bascule les boutons de lecture audio de `HStack` à `VStack(alignment: .leading)`. |
| `AnyLayout` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3690-3693` | `NativeCertificationCrest` | `compact ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(spacing: 8))` — **Attention :** dépend uniquement du paramètre statique `compact`, **pas** de `dynamicTypeSize.isAccessibilitySize` ! |

### 2.2 Inventaire des risques de troncature, chevauchement et tailles fixes à AX3 / AX5 (**VÉRIFIÉ / INFÉRÉ**)

| # | Type de risque | `fichier:ligne` | Extrait exact | Impact à AX3 / AX5 (**INFÉRÉ**) |
|---|---|---|---|---|
| DT-01 | Tailles de police fixes `.font(.system(size:))` (interdites hors Prism par §20) | `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:181, 184, 256, 278` | `.font(.system(size: 14, weight: .bold))`<br>`.font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())`<br>`.font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())`<br>`.font(.system(size: 11, weight: .bold))` | Les textes et symboles de `CertigoWidgetRing`, `CertigoWidgetMark` et `accessoryCircular` ne s'adaptent pas à Dynamic Type. |
| DT-02 | `lineLimit(1)` / `lineLimit(2)` + `minimumScaleFactor` | `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:99-100, 112, 135-136, 141, 162, 206, 220, 257`<br>`apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:71, 177` | `.lineLimit(1)` sur `activeTrackCode`, `earned / goal XP`, et titre `accessoryRectangular`<br>`.lineLimit(2)` sur les boutons de phase (`NativeWidgetGalleryView.swift:71`) et d'icône (`:177`) | Dans `NativeWidgetGalleryView`, à AX3/AX5 dans une grille fixe à 2 colonnes (`:59, :140`), les libellés traduits (notamment en allemand, français et hindi) sont tronqués après 2 lignes. |
| DT-03 | Boîte fixe `36×36 pt` contenant une police dynamique `.headline` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3947-3948` | `Text(...).font(.system(.headline, design: .rounded)).monospacedDigit().frame(width: 36, height: 36)` dans `NativeAnswerLabel` | À AX3/AX5, `.headline` dépasse 40–54 pt alors que son conteneur est figé à `36×36 pt` : la lettre d'option (`A`, `B`, `C`, `D`) est sévèrement rognée ou tronquée. |
| DT-04 | Boîte fixe `44×44 pt` + connecteur géométrique fixe dans `lessonLabel` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:6776-6779, 6803-6808` | `Text(number, format: .number).font(.headline.monospacedDigit()) ... .frame(width: 44, height: 44)` + `Rectangle().frame(width: 3, height: geometry.size.height / 2 + 20).offset(x: 20.5, y: ...)` | À AX3/AX5, le numéro en `.headline` déborde du cercle `44×44 pt` et la pile `HStack` (`cercle 44 pt + VStack + icône 44 pt`) comprime la colonne centrale du titre de leçon sur iPhone compact. |
| DT-05 | Boîte fixe `52×52 pt` dans `NativeSymbolMedallion` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3273-3278` | `Image(systemName: symbol).font(.title2.weight(.semibold)) ... .frame(width: 52, height: 52)` | L'icône SF Symbol en `.title2` grandit avec Dynamic Type et déborde du cadre fixe `52×52 pt` à partir de AX2/AX3. |
| DT-06 | Largeur fixe `.frame(width: 200)` dans `NativeShowcaseTile` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3754` | `.padding(20).frame(width: 200, alignment: .leading)` | À AX3/AX5, `"Microsoft Azure"` ou `"GitHub & Copilot"` en `.headline` sur une largeur utile de `160 pt` (`200 - 2×20`) force une césure multi-lignes très étroite. |
| DT-07 | Grilles `LazyVGrid` fixes à 2 colonnes dans `NativeWidgetGalleryView` | `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:59, 140` | `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10)` | Contrairement à `NativeMetricGrid` (`CertigoNativeApp.swift:3845`), ces deux grilles ne lisent pas `@Environment(\.dynamicTypeSize)` et restent sur 2 colonnes à AX5, écrasant le texte à côté de l'aperçu d'icône `52×52 pt` (`:170`). |
| DT-08 | `HStack` non adaptatives aux tailles AX | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3905, 6746, 8198`<br>`apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift:117, 249, 264` | En-tête de `NativeCertificationCard` (`NativeCertificationCrest` + `Spacer()` + pilule famille en `HStack`, `:3905-3913`), en-tête d'unité `unitProgress` (`NativeSymbolMedallion` + `Text(title).font(.title3)`, `:6746-6750`) | Violation du §20 (« aux tailles AX, piles horizontales → verticales ») : l'écusson et la pilule de famille restent côte à côte à AX5. |

---

## 3. VoiceOver (Inventaire des modificateurs et lacunes) (**VÉRIFIÉ**)

### 3.1 Inventaire exhaustif des modificateurs VoiceOver dans `CertigoNative`

| Modificateur | Nb | Emplacements exacts (`fichier:ligne`) et valeurs |
|---|---|---|
| `.accessibilityLabel(...)` | **11** | - `CertigoNativeApp.swift:2769` : `"\(copy.native(.contentLanguage)) · \(language)"` (`NativeContentLanguageBadges`)<br>- `CertigoNativeApp.swift:3726` : `"\(copy.native(.learningPath)) · \(code)"` (`NativeCertificationCrest`)<br>- `CertigoNativeApp.swift:3774-3776` : `"\(copy.native(.close)) · \(copy.native(.developerConnector))"` (`NativeDeveloperToolbar`)<br>- `CertigoNativeApp.swift:3807` : `title` (`NativeReadinessRing`)<br>- `CertigoNativeApp.swift:4952` : `copy.native(.demoSelectedGoal)` (coche objectif démo)<br>- `CertigoNativeApp.swift:5133` : `option` (bouton QCM démo)<br>- `CertigoNativeApp.swift:5364` : `progress.accessibilityLabel(copy)` (`DemoPracticeTrail`)<br>- `CertigoNativeApp.swift:6526` : `copy.native(.codeCategory)` (barre de puces catégories)<br>- `CertigoNativeApp.swift:7378, 7381` : `"\(copy.native(.confirmedXP)) · \(profile.xp)"` et `"\(copy.native(.streak)) · \(streak)"` (`activityStrip`)<br>- `CertigoWidgetPresentation.swift:259` : `accessibilityLabel` (`CertigoWidgetRing`)<br>- `NativeWidgetGalleryView.swift:208` : `iconCopy.title(for: variant)` (`appIconButton`) |
| `.accessibilityValue(...)` | **4** | - `CertigoNativeApp.swift:3808` : `"\(percent) %"` (`NativeReadinessRing`)<br>- `CertigoNativeApp.swift:5134-5137` : `flow.selection == index ? copy.native(.selected) : copy.native(.notSelected)` (QCM démo)<br>- `CertigoNativeApp.swift:8234-8236` : `model.selections[question.id] == option.id ? copy.native(.selected) : copy.native(.notSelected)` (QCM séance)<br>- `NativeWidgetGalleryView.swift:209` : `current ? iconCopy.currentIconLabel : ""` (`appIconButton`) |
| `.accessibilityHint(...)` | **1** | - `CertigoNativeApp.swift:5226` : `copy.native(.demoChooseBeforeContinue)` (bouton soumettre en mode Démo ; **absent** sur le bouton soumettre connecté `:8143-8149` et sur celui de l'examen blanc `:2953-2960` !) |
| `.accessibilityHidden(true)` | **22** | - `CertigoNativeApp.swift:3279` (`NativeSymbolMedallion`), `:3445` (`NativeMicrosoftVendorBadge`), `:3677` (`NativeEcosystemEmblem`), `:3750` (coche `NativeShowcaseTile`), `:3923` (flèche `NativeCertificationCard`), `:3954` (badge lettre `NativeAnswerLabel`), `:3959` (coche `NativeAnswerLabel`), `:3985` (barres `NativeQuestionProgress`), `:4128` (icône `NativeEntryHeading`), `:4939` (icône objectif démo), `:4967` (squelette `.redacted` démo), `:6174` (filet 1 pt `safeAreaInset`), `:6779` (anneau numéro `lessonLabel`), `:6797` (icône play/lock `lessonLabel`), `:6809` (connecteur vertical `lessonLabel`)<br>- `CertigoWidgetPresentation.swift:281` (`CertigoWidgetMark`)<br>- `NativeEditorialPilotView.swift:121` (`chevron.right`)<br>- `NativeWidgetGalleryView.swift:193` (coche `appIconButton`) |
| `.accessibilityElement(children:)` | **15** | - `.ignore` (**3**) : `NativeCertificationCrest` (`CertigoNativeApp.swift:3725`), `NativeReadinessRing` (`:3806`), `DemoPracticeTrail` (`:5363`)<br>- `.combine` (**12**) : `NativeShowcaseTile` (`:3758`), `NativeMetricTile` (`:3833`), `NativeQuestionProgress` (`:3987`), `selectedAnswer` démo (`:5250`), `DemoResponsibilities` ligne (`:5413`), `demoNotice` (`:5427`), `lessonLabel` (`:6812`), `learningCycle` (`:8207`), `CertigoWidgetCardView` (`CertigoWidgetPresentation.swift:65`) |
| `.accessibilityAddTraits(...)` | **29** | - `.isHeader` (**19**) : `NativeGoalHero` (`:3892`), `NativeReadingSection` (`:4043`), `NativeEntryHeading` (`:4130`), titres démo (`:5042, 5088, 5091, 5095, 5150, 5187, 5346, 5394, 5406`), `NativeAccountDeletionView` (`:5841`), `Explorer` (`.findGoal`, `:6483`), `path` (`track.title`, `:7468`), `session` (`lesson.title` `:7963`, `block.title` `:8006`, `question.stem` `:8215`), `NativeLessonAudioControls` (`:8254`), `NativeEditorialPilotLessonView` (`NativeEditorialPilotView.swift:207`)<br>- `.isSelected` (**10**) : options QCM examen blanc (`:2947`), options QCM démo (`:5130`), tuiles univers (`:6412`), puces catégories (`:6506, 6517`), étape active `learningCycle` (`:8203`), options QCM séance (`:8231`), phases/icônes/familles `NativeWidgetGalleryView` (`:83, 210, 242`) |
| `@AccessibilityFocusState` / `.accessibilityFocused` | **3** | - `CertigoNativeApp.swift:5836, 5842, 5848` : déplace automatiquement le focus VoiceOver vers `.status` lors d'un changement d'étape de suppression (`deletionStage`) ou vers `.error` lorsqu'un message `deletionMessage` apparaît dans `NativeAccountDeletionView`. |

### 3.2 Lacunes VoiceOver par rapport aux §§15, 22A.8 et 28 (**VÉRIFIÉ**)

1. **Aucun rotor personnalisé (`.accessibilityRotor`) dans tout `apps/apple/` :**
   - Le bloc de code dans `NativeRoot.session` (`CertigoNativeApp.swift:8011-8019`) est un simple `Text(code).font(.body.monospaced())` dans un `ScrollView(.horizontal)`. Il ne possède ni numérotation de lignes, ni rotor VoiceOver « Lignes », ni action personnalisée « Sélectionner cette ligne » exigés par **NS-4** (§15) et **§28**.
2. **Aucune annonce VoiceOver (`AccessibilityNotification.Announcement`) hors `NativeAccountDeletionView` :**
   - Lorsqu'un utilisateur soumet une séance (`NativeRoot.session`, `:8024-8139`) ou un examen blanc (`NativeMockExamView`, `:2861-2904`), le résultat (`.pendingCorrection` ou `.corrected(result)`) apparaît dans la page sans déplacer `@AccessibilityFocusState` ni poster d'annonce VoiceOver (« Correct / Incorrect », score ou état en attente, §28).
   - Même lacune lors de l'apparition de `tutorExplanation` dans `tutorContent(for:)` (`:6296-6332`).
3. **Redondance de lecture sur `NativeCertificationCrest` :**
   - `NativeCertificationCrest` (`CertigoNativeApp.swift:3725-3726`) expose toujours `.accessibilityLabel("\(copy.native(.learningPath)) · \(code)")`, même lorsqu'il est placé immédiatement au-dessus du titre complet de la certification dans `NativeGoalHero` (`:3884`), `NativeCertificationCard` (`:3906`), `NativeMockExamView` (`:2857`) et `NativeRoot.session` (`:7966`). Le §22A.8 exige au contraire que `BrandLabel` forme **un seul** élément VoiceOver lisant une seule fois le nom officiel, avec l'icône en `.accessibilityHidden(true)`.
4. **Absence d'`accessibilityValue` sur les options QCM de `NativeMockExamView` (`CertigoNativeApp.swift:2933-2950`) :**
   - Contrairement à `NativeRoot.questionView` (`:8234-8236`) et à `NativeDemoRoot.exercise` (`:5134-5137`) qui renseignent `.accessibilityValue(selected ? copy.native(.selected) : copy.native(.notSelected))`, `NativeMockExamView` (`:2947-2949`) ajoute seulement `.accessibilityAddTraits(.isSelected)` sans `.accessibilityValue`.
5. **Combinaison excessive dans `learningCycle` (`CertigoNativeApp.swift:8192-8208`) :**
   - Chaque étape du rail reçoit `.accessibilityAddTraits(index == active ? .isSelected : [])` (`:8203`), mais le conteneur parent applique `.accessibilityElement(children: .combine)` (`:8207`), ce qui concatène les 5 libellés d'étapes en un seul élément VoiceOver sans distinguer clairement laquelle porte le trait `.isSelected`.
---

## 4. Contraste & Couleur, Differentiate Without Color, Cibles tactiles, Reduce Transparency et Bold Text (**VÉRIFIÉ**)

### 4.1 `@Environment(\.colorSchemeContrast)` et tests de ratio WCAG existants

1. **Usages dans le code Swift (`apps/apple/`) :**
   - `CertigoNativeApp.swift:3683, 3699` : `@Environment(\.colorSchemeContrast) private var contrast` dans `NativeCertificationCrest` (remplace la bordure colorée par `NativePrism.edge` si `contrast == .increased`).
   - `CertigoNativeApp.swift:3175-3177` : `NativePrism.edge` utilise `UIColor { traits in traits.accessibilityContrast == .high ? .label : .separator }`.
   - `CertigoNativeApp.swift:3192-3208` : `NativePrism.accent(band:)` utilise `UIColor { traits in ... }` et interpole de `25 %` (`0.25`) vers le noir (clair) ou le blanc (sombre) lorsque `traits.accessibilityContrast == .high`.
2. **État des tests WCAG (`NativePrism.contrastRatio` absent en Swift — VÉRIFIÉ) :**
   - La méthode `NativePrism.contrastRatio` citée dans l'énoncé **n'existe pas** dans `apps/apple/`.
   - Le calcul de ratio WCAG sur `NativePrism` est actuellement réalisé en Python dans `tools/tests/test_native_prism_presentation.py:332-345` (`test_hero_gradient_white_text_contrast_at_interpolated_stops`), qui extrait `let ink: [UInt32]` de `CertigoNativeApp.swift` et vérifie sur 21 pas d'interpolation de chaque dégradé `NativeTrackTheme.gradient` que `1.05 / (luminance(rgb) + 0.05) >= 4.5` sous du texte blanc.
   - Deux autres implémentations WCAG existent hors `apps/apple/` : `tools/contrast.mjs:1-120` (Node.js, testé par `tools/tests/contrast.test.mjs`) et `packages/prism_ui/test/theme/prism_contrast_contract_test.dart:40-215` (Dart).
   - **Lacune vs §21 :** Aucun test unitaire dans `CertigoKitTests` ne calcule le ratio WCAG de chaque paire `PrismColorRole` / `PrismRegion` / `PrismSyntax` sur les 4 variantes (`Any`, `Dark`, `High Contrast`, `Dark High Contrast`). De plus, les couleurs du widget (`CertigoWidgetPresentation.swift:41-48`, `:269-272`) et de la galerie (`NativeWidgetGalleryView.swift:301`) sont des RGB fixes sans variante sombre ni High Contrast.

### 4.2 Differentiate Without Color (Information portée uniquement par la couleur)

- **Conforme sur la majorité des écrans :**
  - Les états d'items corrigés associent icône et texte : `Label(item.correct ? copy.native(.answerCorrect) : copy.native(.reviewNeeded), systemImage: item.correct ? "checkmark.circle" : "book")` (`CertigoNativeApp.swift:8062-8068`).
  - Les états en attente associent `clock` + `copy[.pendingCorrection]` (`:7872, :8028`).
  - Les niveaux de maîtrise associent symbole géométrique (`○ ◔ ◑ ● ◆`) et libellé traduit (`:6785, :6903`).
  - Les options QCM sélectionnées associent bordure 2 pt, fond teinté, icône `checkmark.circle.fill`, trait `.isSelected` et valeur textuelle `.selected` (`:3940-3960, :8226-8236`).
- **Non-conformités identifiées (**VÉRIFIÉ**) :**
  1. **`NativeRoot.learningInsights` (`CertigoNativeApp.swift:6874-6877`) :**
     ```swift
     if let band = try? SkillBand.resolved(percent: domain.score) {
         LabeledContent(domain.name, value: "\(domain.score) %")
             .foregroundStyle(domainScoreColor(band))
     }
     ```
     La qualification `SkillBand` (`.strong` ≥ 80 % en vert `confirmed`, `.developing` ≥ 55 % en ambre `pending`, `.weak` < 55 % en rouge `.systemRed`, `:6929-6935`) est communiquée **exclusivement par la couleur du texte** sans icône ni libellé textuel (`Fort` / `En progression` / `À renforcer`).
  2. **`NativeWidgetGalleryView` (`NativeWidgetGalleryView.swift:65-80`) :**
     Dans la grille de sélection de phase (`CertigoWidgetPhase`), l'état sélectionné visuel repose uniquement sur le remplissage d'un petit cercle (`9×9 pt`) et l'opacité du fond (`0.12` vs `0.07`), sans coche `checkmark` (contrairement à `appIconButton` en `:190-194` qui affiche `checkmark.circle.fill`).

### 4.3 Cibles tactiles `< 44×44 pt` (**VÉRIFIÉ**)

Alors que 37 boutons dans `CertigoNativeApp.swift` et `NativeEditorialPilotView.swift` déclarent explicitement `.frame(minHeight: 44)` (ou `minWidth: 44, minHeight: 44`), les contrôles interactifs suivants présentent une hauteur inférieure à `44 pt` en taille Dynamic Type standard :

| # | `fichier:ligne` | Contrôle interactif | Dimensions effectives au repos | Correction requise (§18 `PrismSize.minTouch = 44`, §28) |
|---|---|---|---|---|
| CT-01 | `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:60-84` | Boutons de phase `ForEach(CertigoWidgetPhase.allCases)` | `Text(.subheadline)` (~20 pt) + `.padding(10)` haut/bas = **~40 pt** (`< 44 pt`) | Ajouter `.frame(minHeight: 44)` et `.contentShape(...)` |
| CT-02 | `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:226-243` | Boutons capsules `familyButton(_:title:)` (`.systemSmall`, `.systemMedium`, etc.) | `Text(.subheadline)` (~20 pt) + `.padding(.vertical, 9)` = **~38 pt** (`< 44 pt`) | Ajouter `.frame(minHeight: 44)` |
| CT-03 | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4483-4484` | `Button(copy.native(.close)) { dismiss() }.buttonStyle(.bordered).padding()` dans l'overlay d'erreur de `NativeDeveloperConnector` | Bouton `.bordered` de taille `.regular` par défaut = **~34 pt** (`< 44 pt`) | Appliquer `.frame(minHeight: 44)` ou `NativeDeveloperToolbar` |
| CT-04 | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:43-47, 128-138` (`NativeWidgetGalleryView.swift`) et `:6052-6056` (`CertigoNativeApp.swift`) | `Picker` `.segmented` (`NativeWidgetGalleryView.swift:47, 138`) et `Picker` `.menu` sans `minHeight: 44` (`CertigoNativeApp.swift:6052-6056`, `:6427-6431`, `:8259-8265`, `:8269-8273`) | Un `UISegmentedControl` / `Picker(.segmented)` standard mesure **32 pt** de haut sur iOS ; les `Picker(.menu)` hors `List` sans `.frame(minHeight: 44)` (`:6052`) mesurent **~34 pt** | Appliquer `.frame(minHeight: 44)` comme fait sur `NativeAppLanguagePicker` (`:3150`) et `NativeDemoRoot.learnSelector` (`:4746`) |
| CT-05 | `apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift:43-45` | `Button(copy.retry) { Task { await load() } }.buttonStyle(.borderedProminent).padding()` | Bouton `.borderedProminent` sans `.controlSize(.large)` ni `.frame(minHeight: 44)` = **~36 pt** | Utiliser `PrismButtonStyle(.primary)` (`minHeight: 44` / `50`) |
| CT-06 | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:8174-8178` | `Button(copy.retry, systemImage: "arrow.clockwise").buttonStyle(.borderedProminent)` (erreur de chargement de séance) | Sans `.controlSize(.large)` ni `.frame(minHeight: 44)` = **~36 pt** | Utiliser `PrismButtonStyle(.primary)` |

### 4.4 `@Environment(\.accessibilityReduceTransparency)` et Bold Text (**VÉRIFIÉ**)

- **Reduce Transparency :**
  - `CertigoNativeApp.swift:4068, 4075-4079` (`NativePrimaryButton`) : si `reduceTransparency == true`, n'applique **pas** `.glassProminent` (iOS 26+) et bascule sur `.borderedProminent` opaque.
  - `CertigoNativeApp.swift:5992, 6166-6170` (`NativeRoot` `safeAreaInset` de chargement) : si `reduceTransparency == true`, remplace `Rectangle().fill(.regularMaterial)` par la couleur opaque `NativePrism.surface`.
  - Aucune vue de lecture (`NativeReadingCard`, `NativeReadingPage`) n'utilise de matériau translucide (vérifié par `tools/tests/test_native_prism_presentation.py:50-52, 162-163`).
- **Bold Text :**
  - Toutes les polices utilisent les styles système `Font` (`.body`, `.headline`, `.subheadline`, `.title2`, etc.) qui honorent automatiquement `UIAccessibility.isBoldTextEnabled` (`legibilityWeight`). Aucune graisse inférieure à `.regular` (`.light`, `.thin`, `.ultraLight`) n'est présente dans `apps/apple/`.
- **Smart Invert (`accessibilityIgnoresInvertColors`) :**
  - **0 occurrence** de `.accessibilityIgnoresInvertColors(true)` dans `apps/apple/`. Devra être ajouté sur `BrandIcon` à l'étape 2B conformément au §22A.8.

---

## 5. Synthèse d'audit d'accessibilité par écran inventorié (E-01 à E-32) (**VÉRIFIÉ / INFÉRÉ**)

| ID Écran (`03_SCREENS_AND_ROUTES.md`) | Dynamic Type (AX3 / AX5) | VoiceOver | Contraste & Couleur / Cibles / Transparence |
|---|---|---|---|
| **E-01 / E-02** `CertigoNativeApp` / `NativeLanguageRoot` | Neutre (conteneurs racines) | Injecte `\.locale` pour que VoiceOver prononce dans la langue choisie | `.tint(NativePrism.tint)` global |
| **E-03** `NativeEntry.developmentEntry` | **Risque DT-06** : 4 `NativeShowcaseTile` à largeur fixe `200 pt` (`:3754`) dans un `ScrollView(.horizontal)` | En-tête `.isHeader`, bouton `open-native-demo` libellé, tuiles combinées | Dégradé `NativeEntryHeading` vérifié ≥ 4,5:1 sous texte blanc ; `NativePrimaryButton` gère `reduceTransparency` |
| **E-04** `NativeProductionEntry` | Adaptatif (`NativeReadingPage` max 700 pt, bouton démo `minHeight: 44`) | `ContentUnavailableView` et alerte `.signInIncomplete` accessibles | Conforme |
| **E-05 / E-06** `NativeDeveloperConnector` / `connection` | Adaptatif (`Form` et `NativeReadingPage`) | Bouton de fermeture `NativeDeveloperToolbar` libellé (`44×44 pt`), `SecureField` `.privacySensitive()` | **Défaut CT-03** : bouton `.close` en overlay d'erreur (`:4483`) sans `minHeight: 44` |
| **E-07 / E-08** `NativeRoot` / `learning` | `NavigationSplitView` système ; bandeau `safeAreaInset` adaptatif | `TabView` système avec `Label` ; `Picker` `.learn` en ligne de `List` | Barre `safeAreaInset` bascule de `.regularMaterial` à `NativePrism.surface` sous `reduceTransparency` (`:6166`) |
| **E-09** `confirmedGoal` + `activityStrip` | `NativeGoalHero` et `activityStrip` utilisent `ViewThatFits(in: .horizontal)` (`:3860, :7375`) ; **Risque** : `NativeReadinessRing` non plafonné à AX5 (`:3786`) | **Défaut VoiceOver** : `NativeCertificationCrest` lit `"Parcours d'apprentissage · <code>"` en doublon avant le titre (`:3726`) | Dégradés `NativeTrackTheme` vérifiés ≥ 4,5:1 ; bouton `studyPlan` `minHeight: 44` (`:7080`) |
| **E-10** `myLearningPlan` (`unitProgress` + `lessonLabel`) | **Risques DT-04, DT-05, DT-08** : boîtes fixes `44×44 pt` (`:6779`) et `52×52 pt` (`:3277`), connecteur `GeometryReader` décalé en dur (`x: 20.5`), `HStack` non basculée en `VStack` | `lessonLabel` combiné (`.accessibilityElement(children: .combine)`), anneau et icône play/lock masqués (`.accessibilityHidden(true)`) | Statut de maîtrise porté par symbole Unicode (`○ ◔ ◑ ● ◆`) + texte traduit |
| **E-11** `smartReview` | Adaptatif (`NativeReadingPage`, bouton `minHeight: 44` en `:6835`) | Texte et boutons accessibles | Bouton `refreshHistory` (`:6841`) sans `minHeight: 44` explicite hors `List` (quand poussé dans `NativeReadingPage` via `:6442`) |
| **E-12** `learningInsights` | Adaptatif (`ScrollView(.horizontal)` sur la légende `MasteryStage` `:6900`) | Textes lisibles, mais la couleur de `domainScoreColor` n'est pas verbalisée | **Défaut Differentiate Without Color** : `domain.score` coloré par `SkillBand` (`:6876-6877`) sans icône ni mot de niveau |
| **E-13** Mode `Explorer` (`ecosystemShowcase` + filtres + cartes) | **Risques DT-06, DT-08** : `NativeShowcaseTile` fixe `200 pt` (`:3754`) ; en-tête `NativeCertificationCard` en `HStack` non basculée (`:3905`) | Puces catégories et tuiles univers portent `.isSelected` (`:6412, :6506, :6517`) ; `NativeCertificationCrest` redondant sur chaque carte | Puces catégories en `.controlSize(.large)` + `.frame(minHeight: 44)` (`:6521-6522`) |
| **E-14** `NativeRoot.path` | `List` `.insetGrouped` adaptative | `activeGoalSection` expose `active-goal-status` ; `savedAnswers` lisible | Boutons de `List` conformes |
| **E-15** `NativeRoot.session` (Lecteur de séance / QCM / Correction) | **Risque DT-03** : badge lettre `36×36 pt` fixe dans `NativeAnswerLabel` (`:3948`) ; code en `ScrollView(.horizontal)` sans retour à la ligne activable (`:8012`) | **Défauts VoiceOver** : aucun rotor « Lignes » sur le bloc de code (`:8012`) ; aucune annonce lors de l'affichage du résultat (`:8024`) ; `learningCycle` combiné (`:8207`) | **Défaut CT-06** : bouton `retry` d'erreur de chargement (`:8174`) sans `minHeight: 44` ; animation de choix respecte `reduceMotion` (`:4116`) |
| **E-16** `NativeMockExamView` | **Risque DT-03** : `NativeAnswerLabel` `36×36 pt` ; minuteur `TimelineView` sans `.monospacedDigit()` (`:2922`) | **Défaut VoiceOver** : options QCM sans `.accessibilityValue` (`:2947`) ; aucune annonce à la réception du score | Anneau de score respecte `reduceMotion` ; bouton `discardExam` `minHeight: 44` (`:2979`) |
| **E-17** `NativeRoot.coach` + `tutorContent` | Adaptatif (`NativeReadingPage`, `NativeReadingCard`) | **Défaut VoiceOver** : pas d'annonce à l'arrivée de `tutorExplanation` | Boutons `minHeight: 44` (`:6280, :6351`) |
| **E-18** Onglet `Communauté` (`Social`) | Adaptatif (`NativeReadingPage`) | Sections `.isHeader` via `NativeReadingSection` | **Défaut CT-04** : `Picker(copy.social)` (`:6052`) hors `List` sans `minHeight: 44` |
| **E-19 / E-20 / E-21** `profile` / `rewards` / `progressHistory` | `NativeMetricGrid` bascule de 2 à 1 colonne en tailles AX (`:3845`) ; **Risque DT-05** sur `NativeSymbolMedallion` (`52×52 pt`) | `NativeMetricTile` combiné ; erreurs d'historique dotées d'icône `wifi.slash` / `exclamationmark.triangle` | Tous les boutons d'action de `profile` et `progressHistory` ont `.frame(minHeight: 44)` (`:7179-7272, :7697-7771`) |
| **E-22 / E-23 / E-24** `Réglages` / `Notifications` / `NativeStudyPlanView` | `Form` système adaptatif | Contrôles `Toggle`, `Stepper`, `DatePicker`, `Picker` natifs | `NativeNotificationPreferencesView` bouton `save` `minHeight: 44` (`:3046`) |
| **E-25 / E-26** `NativeEditorialPilotView` / `NativeEditorialPilotLessonView` | Aucun `lineLimit` (vérifié par `test_native_prism_presentation.py:53`) ; **Risques DT-05, DT-08** sur `NativeSymbolMedallion` et étapes numérotées en `HStack` | Titre `.isHeader` (`:207`), `chevron.right` masqué (`:121`), liens et boutons `minHeight: 44` | **Défaut CT-05** : bouton `copy.retry` en overlay d'erreur (`:43-45`) sans `minHeight: 44` |
| **E-27** `NativeWidgetGalleryView` | **Risques DT-02, DT-07** : `lineLimit(2)` (`:71, :177`) dans deux `LazyVGrid` fixes à 2 colonnes (`:59, :140`) non adaptatives à AX3/AX5 ; aperçu widget à cadre fixe (`170×170` ou `340×112`, `:98-101`) | `.isSelected` sur phases, icônes et familles (`:83, :210, :242`), `.accessibilityLabel` et `.accessibilityValue` sur `appIconButton` (`:208-209`) | **Défauts CT-01, CT-02, CT-04** : boutons de phase (~40 pt), `familyButton` (~38 pt) et `Picker(.segmented)` (32 pt) `< 44 pt` ; palette `NativeWidgetGalleryPalette.accent` fixe sans variante HC |
| **E-28** `NativeAccountDeletionView` | `Form` système adaptatif | **Exemplaire** : `@AccessibilityFocusState` déplace le focus sur `.status` ou `.error` (`:5836-5848, :5962-5965`) | Conforme |
| **E-29** `NativeLessonAudioControls` | `ViewThatFits(in: .horizontal)` sur les boutons de lecture (`:8276`) | Détecte `UIAccessibility.isVoiceOverRunning` et coupe la synthèse vocale pour éviter tout chevauchement vocal (`:8291-8296, :8358, :8401`) | Boutons de lecture `minHeight: 44` (`:8305-8315`), mais les 2 `Picker` (`:8259, :8269`) n'ont pas `minHeight: 44` |
| **E-30** `NativeDemoRoot` (Mode Démo) | `DemoPracticeTrail` utilise `ViewThatFits` (`:5358`) ; `maxWidth: 680` | `demoNotice`, `DemoPracticeTrail`, options QCM (`.isSelected` + `.accessibilityLabel` + `.accessibilityValue`) et bouton soumettre (`.accessibilityHint`) bien balisés | Pas d'animation sur les options QCM démo |
| **E-31 / E-32** `CertigoDailyWidget` / `CertigoWidgetCardView` | **Risques DT-01, DT-02** : 4 tailles fixes `.font(.system(size: 11/14/15))` (`:181, 184, 256, 278`) et `lineLimit(1..3)` + `minimumScaleFactor(0.75/0.8)` | `.accessibilityElement(children: .combine)` sur la carte (`:65`), `CertigoWidgetRing` libellé (`:259`), `CertigoWidgetMark` masqué (`:281`), `.privacySensitive()` (`:64`) | Couleurs `accent` en RGB fixes (`:41-48`) sans variante sombre ni High Contrast |

---

## 6. Protocole et commande exacte `XCUITest` pour `performAccessibilityAudit()` sur macOS (**NON EXÉCUTÉ — macOS/Xcode requis**)

### 6.1 Pourquoi l'audit runtime `XCUITest` n'est pas exécuté ici
- L'environnement courant est **Windows** (`win32`), sans Xcode ni simulateur iOS (`xcodebuild` indisponible).
- De plus, `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj` ne contient actuellement **aucune** target `XCUITest` (`com.apple.product-type.bundle.ui-testing`) : les tests existants (`DemoTests/NativeDemoFlowTests.swift` et `ModelTests/NativeModelTests.swift`) sont des exécutables CLI autonomes (`@main`).

### 6.2 Extrait de test `XCUITest` de référence (à intégrer en Phase 1 après validation de la Phase 0)
```swift
import XCTest

final class CertigoAccessibilityAuditUITests: XCTestCase {
    @MainActor
    func testEntryAndDemoScreensPassAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()

        if #available(iOS 17.0, *) {
            // 1. Audit de l'écran d'entrée
            try app.performAccessibilityAudit()

            // 2. Ouverture du mode Démo et audit des 4 onglets accessibles sans secret
            let demoButton = app.buttons["open-native-demo"]
            if demoButton.waitForExistence(timeout: 5) {
                demoButton.tap()
                try app.performAccessibilityAudit()
            }
        }
    }
}
```

### 6.3 Commande exacte à exécuter sur le Mac du propriétaire (**NON EXÉCUTÉ — macOS/Xcode requis**)
```bash
xcodebuild test \
  -project apps/apple/CertigoNative/CertigoNative.xcodeproj \
  -scheme CertigoNative \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  -resultBundlePath artifacts/phase-0-a11y-audit.xcresult
```