# Étape 12 — Plan de Migration (Phases 1 à 11 + Étape 2B)

> **Branche auditée :** `transform/phase-0-audit` (`HEAD` `778f9c247ceb9c0db29fb931a8573bd328b492ab`)
> **Référence normative :** Master Prompt §34 (Migration Order), §35 (Acceptance Criteria), §36 (Rollback Strategy), §38 (Prevent Vibe-Coding Drift), §39 (Definition of Done).
> **Règle d'exécution :** **une seule phase à la fois**, dans l'ordre strict `Phase 1 → Phase 2 → Étape 2B → Phase 3 → … → Phase 11`, clôturée par les **7 portes** (`BUILD → TEST → VISUAL VALIDATION → ACCESSIBILITY VALIDATION → PERFORMANCE CHECK → REPORT → SAFE CHECKPOINT`) et un arrêt pour validation explicite du propriétaire.

---

## 1. Architecture des Feature Flags (`FeatureFlags` dans `CertigoDomain`, §34.1 & §36)

Tous les changements visibles par l'utilisateur sont placés derrière un flag typé dans `apps/apple/CertigoKit/Sources/CertigoDomain/FeatureFlags.swift` :
- **Ordre de résolution :** `killSwitchDistant(flag)` (priorité absolue si `false`) → `debugOverride(flag)` (`#if DEBUG`, persisté localement pour `D-1`) → `compiledDefault(flag)` (**`false` par défaut** jusqu'à validation de la phase).
- **Conservation de l'ancien chemin :** l'ancien chemin reste compilé et fonctionnel tant que le flag n'a pas été activé ≥ 2 semaines en production sans incident critique (nettoyage final en Phase 11).

| Flag | Phase d'introduction | Portée | Défaut initial | Kill switch distant |
|---|---|---|---|---|
| `prism.enabled` | Phase 1 | Activation des styles et tokens `Prism` sur les composants | `false` | Oui |
| `brand.icons.v1` | Étape 2B | Affichage global des icônes officielles `BrandIcon` / `BrandLabel` | `false` | Oui |
| `brand.icons.<vendor>` | Étape 2B | Interrupteur par éditeur (`microsoft`, `github`, `aws`, `google`, `cncf`, `cisco`, `python`, `linux`) basculant instantanément en `BrandFallbackMark` sous 48 h (§22A.5, §22A.12) | `true` (subordonné à `brand.icons.v1`) | Oui |
| `nav.v2` | Phase 3 | `TabView` cible (`Aujourd'hui`, `Atlas`, `Ensemble`, `Profil` + `.search`) et `Router` central | `false` | Oui |
| `today.v2` | Phase 3 | Écran `Aujourd'hui` (`S-10`) composé à partir des données existantes | `false` | Oui |
| `session.v2` | Phase 4 | Lecteur de séance plein écran (`S-20`), cartes `S-21` et items multi-formats `S-22` | `false` | Oui |
| `feedback.v2` | Phase 5 | `FeedbackPanel` en un seul temps (`S-23`), `S-25` Résultats et Examen blanc 3 écrans (`S-50..52`) | `false` | Oui |
| `daily.situation` | Phase 5 | Situation du jour (`S-30`) et partage sans spoiler (`S-95`) | `false` | Oui |
| `atlas.v1` | Phase 6 | Atlas (`S-40` Liste + Carte), Région/Territoire (`S-41/42`), Concept (`S-43`), Mémoire (`S-11`), Passeport (`S-71`) | `false` | Oui |
| `readiness.v2` | Phase 6 | Préparation honnête par bandes (`S-49`), Objectif d'examen (`S-48`), Calibration (`S-72`, `S-53`) | `false` | Oui |
| `rhythm.v1` | Phase 7 | Rythme hebdomadaire (`RhythmWeekView`), `S-12` Bon retour, retrait UI XP/série anxiogène | `false` | Oui |
| `rhythm.dailyStreakOptIn` | Phase 7 | Affichage optionnel de la série quotidienne dans `Profil` uniquement (désactivé par défaut §9) | `false` | Oui |
| `celebrations.v1` | Phase 7 | Jalons de maîtrise et `PrismCelebration` niveaux 0–3 | `false` | Oui |
| `missions.v1` | Phase 7 | ≤ 3 missions hebdomadaires liées à une compétence | `false` | Oui |
| `events.v1` | Phase 7 | Temps forts coopératifs (≤ 4/an, sans battle pass) | `false` | Oui |
| `social.v2` | Phase 8 | Ensemble (`S-60`), Squads (`S-61/62`), Amis privés par défaut (`S-63/64`), Défis (`S-65`), Ligues de progression opt-in (`S-66`) | `false` | Oui |
| `ai.contextual` | Phase 9 | `AIRouter`, `S-24` Indice/Expliquer, `S-44` Comparer, `S-45` Fausses idées | `false` | Oui |
| `onboarding.v2` | Phase 10 | Premier lancement 60 s (`S-01`…`S-06`) et Mode Invité sur contenu public réel | `false` | Oui |
| `pro.v1` | Phase 10 | Offre CertiGo Pro (`S-73`, StoreKit 2 `SubscriptionStoreView`) | `false` | Oui |
| `widgets.v1` | Phase 10 | Widgets `W-1`..`W-3`, Live Activities `LA-1`..`LA-3`, Control Center `CC-1`, App Intents `AI-1` | `false` | Oui |

---

## 2. Plan chirurgical de découpage du monolithe `CertigoNativeApp.swift` (Phase 1 — Lot 1.3)

### 2.1 État observé à `HEAD` `778f9c24`
`apps/apple/CertigoNative/Sources/CertigoNativeApp.swift` compte **8 565 lignes** et regroupe dans un seul fichier :
1. Logique portable hors SwiftUI (catégories radar, filtres catalogue, couverture de parcours, badges de langue, durées, extensions `NativeDemoFlow`, dictionnaire de localisation `AppInterfaceCopy.NativeLabel` de **2 438 lignes** : lignes `1–2750`).
2. Vues de fonctionnalités secondaires (`NativeContentLanguageBadges`, `NativeStudyPlanView`, `NativeMockExamView`, `NativeNotificationPreferencesView` : lignes `2751–3062`).
3. Point d'entrée `@main CertigoNativeApp`, clés d'environnement et `NativeLanguageRoot` / `NativeAppLanguagePicker` (lignes `3064–3157`).
4. Pseudo-design system `NativePrism`, `NativeTrackTheme`, `NativeSymbolMedallion`, emblèmes/crêtes `NativeEcosystemArtwork` / `NativeCertificationCrest` et composants partagés `NativeReadinessRing`, `NativeMetricTile`, `NativeGoalHero`, `NativeCertificationCard`, `NativeAnswerLabel`, `NativeQuestionProgress`, `NativeReadingPage`, `NativePrimaryButton`, `NativeChoiceButtonStyle` (lignes `3159–4140`).
5. Points d'entrée d'authentification et de routage initial `NativeEntry`, `NativeProductionEntry`, `NativeDeveloperConnector` (lignes `4142–4582`).
6. Mode Démo complet `NativeDemoRoot` + machine d'états `NativeDemoFlow` / `NativeDemoNavigationState` / `NativeDemoSnapshot` (lignes `4584–5827`).
7. Suppression de compte `NativeAccountDeletionView` (lignes `5830–5988`).
8. Coquille connectée principale `NativeRoot` (onglets `Apprendre`, `Coach`, `Communauté`, `Profil`, `path`, `progressHistory`, `session` : lignes `5990–8241`).
9. Synthèse vocale `NativeLessonAudioControls` / `NativeLessonSpeech` / `NativeLessonReadingContent` et types de navigation `NativeActiveGoalPresentation` / `NativeLearningNavigation` (lignes `8243–8565`).

### 2.2 Contraintes d'outillage et de tests à respecter impérativement lors du découpage
1. **`tools/tests/test_native_source_membership.py:58-110` :**
   - Vérifie que chaque fichier `.swift` sous `apps/apple/CertigoNative/Sources` possède une entrée `PBXFileReference` (`lastKnownFileType = sourcecode.swift; sourceTree = "<group>";`), une entrée `PBXBuildFile` dans la phase `PBXSourcesBuildPhase` (`000000000000000000000030`) de la target `CertigoNative` (`000000000000000000000050`), **et** figure dans la liste `children` du `PBXGroup` `Sources` (`000000000000000000000021`, `project.pbxproj:81-94`).
   - Vérifie aussi dans `tools/tests/test_native_distribution.py:22-46` que tous les identifiants hexadécimaux de 24 caractères dans `project.pbxproj` sont uniques et équilibrés.
2. **`tools/tests/test_native_prism_presentation.py:16-20,393-416` :**
   - Lit actuellement `(SOURCES / "CertigoNativeApp.swift").read_text(encoding="utf-8")` (`:18`) et découpe le texte avec `.split("struct NativePrimaryButton:", 1)`, `.split("private struct NativeRoot:", 1)`, etc., et compile la tranche portable `self.app.split("#if canImport(SwiftUI)", 1)[0]` via `swift -warnings-as-errors` (`:393-416`).
   - **Règle Phase 1 :** adapter `setUpClass` dans `test_native_prism_presentation.py` pour charger l'ensemble des fichiers `.swift` de `Sources/` dans un ordre canonique déterministe (et compiler les fichiers portables ensemble dans `test_showcase_universes_are_exclusive_for_loaded_code_namespaces`), **sans supprimer ni affaiblir une seule assertion existante** (§32.3).
3. **`apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift` :**
   - Compile les types portables de `CertigoNativeApp.swift` sous Linux/macOS. Les fichiers contenant les types portables (`NativeCatalogModels.swift`, `NativeCopyCatalog.swift`, `NativeDemoModels.swift`, `NativeLessonReadingContent.swift`) doivent donc garder leurs gardes `#if canImport(SwiftUI)` exactes ou être passés au compilateur dans le script de test.

### 2.3 Plan d'extraction fichier par fichier (12 fichiers sous `apps/apple/CertigoNative/Sources/`, 0 changement de comportement)

| # | Nouveau fichier sous `apps/apple/CertigoNative/Sources/` | Lignes extraites de `CertigoNativeApp.swift` | Types et responsabilités déplacés (visibilité `private` → `internal` quand partagé entre fichiers du module `CertigoNative`) | IDs `PBXFileReference` / `PBXBuildFile` à ajouter dans `project.pbxproj` |
|---|---|---|---|---|
| 1 | `CertigoNativeApp.swift` | `3064–3157` | `@main struct CertigoNativeApp`, `NativeLanguagePreferenceKey`, `NativeInterfaceCopyKey`, `EnvironmentValues`, `NativeLanguageRoot`, `NativeAppLanguagePicker` (~100 lignes) | Conserve `000000000000000000000011` / `000000000000000000000001` |
| 2 | `NativeCatalogModels.swift` | `1–306`, `8523–8565` | `NativeRadarCategory`, `NativeTrackAppearance`, `NativeCatalogFilter`, `NativeShowcaseUniverse`, `NativePathCoverage`, `NativeActivityDestination`, `NativeDeclaredContentLanguage`, `NativeLearningDuration`, `NativeActiveGoalPresentation`, `NativeLearningNavigation` | `0000000000000000000000E1` / `0000000000000000000000F1` |
| 3 | `NativeCopyCatalog.swift` | `307–2750` | `extension AppInterfaceCopy` (`minutes(_:)`, `enum NativeLabel` + table des 8 langues vérifiée par précondition) | `0000000000000000000000E2` / `0000000000000000000000F2` |
| 4 | `NativeSharedComponents.swift` | `2756–2772`, `3159–4140` | `NativeContentLanguageBadges`, `NativePrism`, `NativeTrackTheme`, `NativeSymbolMedallion`, `NativeEcosystemArtwork`, `NativeCrestOutline`, `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCertificationCrest`, `NativeShowcaseTile`, `NativeDeveloperToolbar`, `NativeReadinessRing`, `NativeMetricTile`, `NativeMetricGrid`, `NativeGoalHero`, `NativeCertificationCard`, `NativeAnswerLabel`, `NativeQuestionProgress`, `NativePracticeBadge`, `NativeReadingPage`, `NativeCatalogSearch`, `NativeReadingSection`, `NativeReadingCard`, `NativePrimaryButton`, `NativeChoiceButtonStyle`, `NativeEntryHeading` | `0000000000000000000000E3` / `0000000000000000000000F3` |
| 5 | `NativeEntryViews.swift` | `4142–4582` | `NativeEntry`, `NativeProductionEntry` (`#if CERTIGO_PRODUCTION_DISTRIBUTION`), `NativeDeveloperConnector` (`#if DEBUG`) | `0000000000000000000000E4` / `0000000000000000000000F4` |
| 6 | `NativeDemoModels.swift` | `5473–5827` | `NativeDemoFlow`, `NativeDemoPracticeStage`, `NativeDemoPracticeStepState`, `NativeDemoPracticeProgress`, `NativeDemoPractice`, `NativeDemoDestination`, `NativeDemoLearnSection`, `NativeDemoTab`, `NativeDemoRoute`, `NativeDemoNavigationState`, `NativeDemoPersistence`, `NativeDemoSnapshot` | `0000000000000000000000E5` / `0000000000000000000000F5` |
| 7 | `NativeDemoViews.swift` | `4584–5471` | `DemoCatalogScenario`, `DemoSocialSection`, `NativeDemoRoot`, `DemoReadingSection`, `DemoPracticeTrail`, `DemoTakeaway`, `DemoResponsibilities`, `DemoPrimaryButton` | `0000000000000000000000E6` / `0000000000000000000000F6` |
| 8 | `NativeStudyAndExamViews.swift` | `2774–3062` | `NativeStudyPlanView`, `NativeMockExamView`, `NativeNotificationPreferencesView` | `0000000000000000000000E7` / `0000000000000000000000F7` |
| 9 | `NativeAccountDeletionView.swift` | `5830–5988` | `NativeAccountDeletionView` | `0000000000000000000000E8` / `0000000000000000000000F8` |
| 10 | `NativeRootView.swift` | `5990–7456` | `NativeRoot` (structure principale `TabView`, `coach`, `learning`, `myLearningPlan`, `smartReview`, `learningInsights`, `confirmedGoal`, `profile`, `rewards`, `questCards`, `activityMetrics`, `activityStrip`, `connection`) | `0000000000000000000000E9` / `0000000000000000000000F9` |
| 11 | `NativePathAndSessionViews.swift` | `7458–8241` | `extension NativeRoot` (`path`, `pathLearningSections`, `progressHistory`, `coverageSummary`, `savedAnswers`, `savedAnswer`, `activeGoalSection`, `session`, `learningCycle`, `questionView`) | `0000000000000000000000EA` / `0000000000000000000000FA` |
| 12 | `NativeLessonAudioViews.swift` | `8243–8521` | `NativeLessonAudioControls`, `NativeLessonSpeech`, `NativeLessonReadingContent` | `0000000000000000000000EB` / `0000000000000000000000FB` |
---

## 3. Plan détaillé phase par phase (Phases 1 à 11 + Étape 2B)

### Phase 1 — Prism Foundations & Découpage du Monolithe
- **Taille estimée :** **M** (6 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-1-prism-foundations` · **Tag de sortie :** `transform-phase-1-done`
- **Prérequis :** Validation Phase 0 par le propriétaire ; **DR-001**, **DR-002**, **DR-007** et **DR-009** tranchées.
- **Flags introduits :** Infrastructure `FeatureFlags` + `prism.enabled` (défaut `false`).
- **Tests à écrire AVANT toute modification :**
  1. Tests de caractérisation du découpage vérifiant que l'ensemble des suites existantes (`swift test` dans `CertigoKit`, `NativeDemoFlowTests`, `NativeModelTests`, `test_native_source_membership.py`, `test_native_prism_presentation.py`, `test_native_distribution.py`) passent à 100 %.
  2. Tests unitaires WCAG dans `PrismTests` vérifiant le ratio de contraste ≥ `4,5:1` (texte) et ≥ `3:1` (éléments graphiques) et ≥ `7:1` (High Contrast) pour chaque paire `PrismColorRole` / `PrismRegion` / `PrismSyntax` (§21).
  3. Tests unitaires de `FeatureFlags` (défaut compilé, surcharge Debug, kill switch distant prioritaire).
  4. Target `ArchitectureTests` (§38.2) scannant les fichiers de fonctionnalités migrés (0 couleur brute, 0 `.font(.system(size:))`, 0 espacement/rayon littéral, 0 `print(`, 0 chaîne UI non localisée).
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 1.1 :** Implémenter `FeatureFlags` et le protocole `AnalyticsClient` dans `CertigoDomain` + leurs tests unitaires.
  - **Lot 1.2 :** Découper chirurgicalement `CertigoNativeApp.swift` (`8 565` lignes) en 12 fichiers sous `apps/apple/CertigoNative/Sources/` selon le tableau §2.3 ci-dessus, avec mise à jour atomique de `project.pbxproj:10-28,31-45,81-94,251-264` et du lecteur multi-fichiers de `tools/tests/test_native_prism_presentation.py:16-20`, **sans aucun changement d'UI ni de comportement**.
  - **Lot 1.3 :** Créer la target SPM `Prism` dans `apps/apple/CertigoKit/Package.swift` + `Sources/Prism/Resources/Prism.xcassets` et implémenter tous les jetons normatifs du §18 (`PrismSpacing`, `PrismRadius`, `PrismSize`, `PrismColorRole`, `PrismRegion`, `PrismSyntax`, `PrismTextStyle`, `PrismMotionToken`, `PrismHapticToken`, `PrismSoundToken`, `PrismMaterialRole`, `PrismCelebrationLevel`) + les lier dans `project.pbxproj`.
  - **Lot 1.4 :** Implémenter le harnais de snapshots sans dépendance externe (`ImageRenderer` + comparaison PNG déterministe, selon **DR-007**) et la suite `ArchitectureTests` (§38.2).
  - **Lot 1.5 :** Construire l'écran `D-1` (`PrismGalleryDebugView`, compilé exclusivement sous `#if DEBUG`) regroupant la galerie des jetons Prism, le simulateur de widgets déplacé depuis `Profil`, le panneau de surcharge `FeatureFlags` et le connecteur développeur.
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* le découpage de `CertigoNativeApp.swift` en 12 fichiers, *when* `python3 -m unittest discover -s tools/tests -p "test_native*.py"` et `xcodebuild build` s'exécutent, *then* 100 % des tests et builds Debug/Release/Distribution réussissent avec 0 warning et un comportement UI strictement identique.
  - *Given* toutes les paires de couleurs `PrismColorRole` / `PrismRegion` / `PrismSyntax` en modes Clair, Sombre, Contraste élevé clair et Contraste élevé sombre, *when* `PrismContrastTests` s'exécute, *then* 100 % des paires texte/fond atteignent ≥ 4,5:1 (≥ 7:1 en HC).
  - *Given* un build `Release` ou `Distribution`, *when* l'app est compilée, *then* `D-1` (galerie Prism, surcharge de flags, simulateur de widgets et connecteur de test) est absent du binaire.

---

### Phase 2 — Core Components (Composants Prism fondamentaux et d'apprentissage)
- **Taille estimée :** **L** (6 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-2-core-components` · **Tag de sortie :** `transform-phase-2-done`
- **Prérequis :** `transform-phase-1-done` validé.
- **Flags :** `prism.enabled` (aucun branchement sur les écrans métier en Phase 2, §34.1 MUST NOT).
- **Tests à écrire AVANT toute modification :**
  1. Tests unitaires et d'accessibilité (`AccessibilityRepresentation`, labels, traits, bascule AX `ViewThatFits`, respect de `accessibilityReduceMotion` / `accessibilityReduceTransparency`) pour chaque composant du §19.
  2. Snapshots de référence (Clair, Sombre, Increase Contrast, Dynamic Type `.large` et `.accessibility3`, `fr` + `en` + `de`).
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 2.1 (Foundation) :** `PrismText`, `PrismIcon` (+ `.symbolset` des 8 régions, 5 états de concept, fausse idée, Déclic, route), `PrismButtonStyle`, `PrismCard`, `PrismSection`, `PrismRow`, `PrismChip`, `PrismBadge`, `PrismProgressBar`, `PrismProgressRing`, `PrismSegmentedControl`.
  - **Lot 2.2 (States & A11y) :** `PrismEmptyState`, `PrismErrorState`, `PrismOfflineBanner`, `PrismSkeleton`, `PrismToast`, `PrismCelebration` (niveaux 0–3 + variantes Reduce Motion / Mode Calme), `ShareCardRenderer`, helpers de rotors et bascule de disposition AX.
  - **Lot 2.3 (Learning P1 — lecture & artefacts) :** `SessionProgressHeader`, `SessionLengthPicker`, `QuestionCard`, `ExplanationCard`, `WorkedExampleView` (avec bouton « Je connais déjà »), `DiagramView` (formes natives + description structurée VoiceOver), `ArtifactView` (numéros de ligne, coloration `PrismSyntax`, zoom, retour à la ligne, sélection de ligne, rotor « Lignes »).
  - **Lot 2.4 (Learning P1 — saisie & feedback) :** `ChoiceList`, `ConfidencePicker`, `TokenComposer`, `OrderList` (avec alternative tap et actions VoiceOver sans glisser obligatoire), `FeedbackPanel` (dont variante « Erreur avec certitude »), `ResponsibilityMatrix`, `TakeawayLine`, `HintLadderView`.
  - **Lot 2.5 (Progress Foundations) :** `MasteryGlyph`, `DepthLadderView`, `ReadinessBandView`, `RhythmWeekView`, `RegionChip`, `RouteBadge`, `PassportCard` + enregistrement de tous les composants dans la galerie `D-1`.
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* chaque composant Prism livré en Phase 2, *when* la suite de snapshots et d'audit a11y s'exécute en Clair, Sombre, HC et AX3 (`fr`/`en`/`de`), *then* aucune troncature ni violation de cible tactile (`< 44×44 pt`) n'est détectée.
  - *Given* `ArtifactView` avec 25 lignes de code et VoiceOver actif, *when* l'utilisateur utilise le rotor « Lignes », *then* chaque ligne est lue individuellement avec son numéro et peut être sélectionnée par l'action « Sélectionner cette ligne » (NS-4).

---

### Étape 2B — Official Brand Assets (Les vrais symboles des éditeurs, §22A)
- **Taille estimée :** **M** (5 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-2b-official-brand-assets` · **Tag de sortie :** `transform-phase-2b-done`
- **Prérequis :** `transform-phase-2-done` validé + **DR-006** et **DR-010 `APPROVED`**.
- **Flags introduits :** `brand.icons.v1` (défaut `false`), `brand.icons.<vendor>` (`microsoft`, `github`, `aws`, `google`, `cncf`, `cisco`, `python`, `linux`).
- **Tests à écrire AVANT toute modification (§22A.10) :**
  1. `BrandAssetsTests` : (a) complétude bidirectionnelle `BrandAssets.xcassets` ↔ `brand-manifest.json` et `template-rendering-intent == "original"`, (b) intégrité SHA-256 fichier = manifeste = archive source, (c) couverture 100 % des produits de `content/` dans `content/brands/registry.yaml`, (d) lint Swift interdisant tout usage direct de `BrandAssets` hors `BrandIcon`, tout modificateur interdit (§22A.6) et tout actif tiers dans `AppIcon` / `ShareCardRenderer` / `PrismCelebration` / `WidgetExtension`, (e) test de non-teinte pixel et snapshots `BrandLabel` (Clair, Sombre, HC, AX3), (f) alerte fraîcheur > 90 jours.
  2. Extension du validateur `node tools/validate_content.mjs` pour valider les champs optionnels `products` et `DiagramSpec.node.product`.
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 2B.1 :** Créer `content/brands/registry.yaml` à partir de `brand_references.csv` (Phase 0) + étendre de façon additive `content/schema/lesson.schema.json` et `tools/validate_content.mjs`.
  - **Lot 2B.2 :** Importer depuis les kits officiels (§22A.3, ou depuis `brand-assets/inbox/`) les **seules** icônes de Niveau 1 référencées (non modifiées, budget total ≤ `2 Mo`), générer `brand-manifest.json` avec SHA-256 et archiver les conditions datées dans `docs/legal/brand-terms/` + `docs/legal/BRAND_ASSETS_CHANGELOG.md` + `THIRD_PARTY_NOTICES.md`.
  - **Lot 2B.3 :** Implémenter le module `BrandAssets` (`BrandRegistry.swift`, application stricte des contextes `.diagram`, `.learningContent`, `.catalog`, `.passport` et des kill switches `brand.icons.<vendor>`) et les composants `Prism/Brand/` (`BrandIcon`, `BrandLabel`, `BrandFallbackMark`, `BrandNoticesView`).
  - **Lot 2B.4 :** Brancher derrière `brand.icons.v1` : (a) `BrandLabel` sur les en-têtes des leçons et ateliers (`.learningContent`), (b) `BrandFallbackMark` + `RouteBadge` sur les cartes de certification (`.catalog`), **retirer `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem` et `NativeCertificationCrest`** (en mettant à jour `tools/tests/test_native_prism_presentation.py:346-377,457-480`), et (c) brancher l'écran `BrandNoticesView` dans `Profil › À propos › Marques et mentions légales`.
- **Critères d'acceptation (Given / When / Then) :**
  - Tous les 8 critères Given/When/Then normatifs du **§22A.13** du Master Prompt (couverture 100 %, SHA-256 exact, rendu `.diagram` Azure, repli `.catalog` AZ-900 sans crête ni badge, repli MOS Excel Niveau 2, mode sombre + HC + Smart Invert, kill switch `brand.icons.<vendor>` OFF, et écran `BrandNoticesView` complet).

---

### Phase 3 — Home / Today & Structure de Navigation v2
- **Taille estimée :** **M** (4 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-3-home-today` · **Tag de sortie :** `transform-phase-3-done`
- **Prérequis :** `transform-phase-2b-done` validé.
- **Flags :** `nav.v2`, `today.v2`.
- **Tests à écrire AVANT toute modification :**
  1. Tests unitaires de `AppRoute` et `Router` (navigation par onglet, sheets, covers, restauration `SceneStorage`, deep links `certigo://…` et Universal Links).
  2. Tests unitaires du ViewModel `TodayViewModel` (composition d'Aujourd'hui à partir de `Profile`, `LearningPath`, `NextBestRecommendations`, `CertigoStudyPlanPreference` et `SavedSubmission`).
  3. XCUITest du parcours `Aujourd'hui → 1 tap → lancement de séance` + `performAccessibilityAudit()`.
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 3.1 :** Implémenter `AppRoute` et `Router` centralisé + `TabView` cible derrière `nav.v2` (`Aujourd'hui`, `Atlas`, `Ensemble`, `Profil` + `.search` iOS 26+, `sidebarAdaptable`, accessoire « Séance en cours »). L'ancienne `TabView` reste intacte quand `nav.v2 == false`.
  - **Lot 3.2 :** Implémenter l'écran **Aujourd'hui** (`S-10`, NS-2) derrière `today.v2` : carte héros de Séance avec `SessionLengthPicker` (Express 5 min / Séance 15 min / Plongée 30–45 min) et **une seule action principale** en 1 tap, aperçu Situation du jour, Rythme, Mémoire et Objectif actif, états complets (`PrismSkeleton` sans spinner plein écran, `PrismOfflineBanner`, `PrismErrorState`).
  - **Lot 3.3 :** Implémenter les vues initiales d'**Atlas** en mode Liste (`S-40` liste + `S-46` Explorer catalogue des routes utilisant `BrandFallbackMark` / `BrandLabel`), le squelette d'**Ensemble** (`S-60`) et de **Profil** (`S-70` + `S-74` Réglages).
  - **Lot 3.4 :** Émettre les événements analytics du cycle de vie et d'Aujourd'hui (`app_opened`, `goal_set`) et valider le budget de lancement (`Aujourd'hui interactif ≤ 500 ms` avec cache, §30).
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un utilisateur connecté avec un objectif actif et des données en cache, *when* il ouvre l'app avec `nav.v2` et `today.v2` activés, *then* Aujourd'hui est interactif en ≤ 500 ms, propose une seule action principale qui lance la séance en 1 tap, et passe `performAccessibilityAudit()` ainsi que le rendu AX5 sans troncature (NS-2).
  - *Given* `nav.v2` passé à `false` via le kill switch, *then* l'application revient immédiatement aux 4 onglets historiques sans perte de session ni d'activité locale.
---

### Phase 4 — Learning Experience (Le lecteur de séance et les formats natifs de la tech)
- **Taille estimée :** **L** (6 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-4-learning-experience` · **Tag de sortie :** `transform-phase-4-done`
- **Prérequis :** `transform-phase-3-done` validé.
- **Flags :** `session.v2`.
- **Tests à écrire AVANT toute modification :**
  1. Tests de contrats JSON (`CertigoKit/Tests/CertigoKitTests/Fixtures/`) pour le décodage additif des nouveaux formats P1 (`choice` avec `revealOptionsDelayMs` et `captureConfidence`, `situation`, `predict`, `spotTheIssue`, `ordering`, `commandComposer`) et du repli gracieux `item_format_unsupported` (§6.4).
  2. Tests unitaires de persistance carte par carte dans `NativeActivityStore` (expiration 24 h pour Express/Séance, 7 jours pour Plongée, §6.2).
  3. Tests xUnit backend et tests du validateur `node tools/validate_content.mjs` pour les extensions additives du schéma de leçon.
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 4.1 :** Étendre de manière **strictement additive** `Contracts.swift`, `CanonicalQuestionReader.swift` et `OfflineQuestionPack.swift` pour décoder `ItemPayload` versionné (`choice`, `situation`, `predict`, `spotTheIssue`, `ordering`, `commandComposer`, plus repli `.unsupportedFormat`) sans casser la validation existante des `mcq`.
  - **Lot 4.2 :** Construire le lecteur plein écran **S-20** (`SessionPlayerView`) derrière `session.v2` : en-tête `SessionProgressHeader`, transition carte → carte `≤ 100 ms` (`PrismMotionToken.snappy`), fermeture « Terminer et sauvegarder » (confirmation uniquement si saisie en cours), et reprise carte par carte via `NativeActivityStore`.
  - **Lot 4.3 :** Assembler les cartes d'apprentissage **S-21** (`QuestionCard` d'ouverture, `ExplanationCard`, `WorkedExampleView` avec test de saut « Je connais déjà », `DiagramView` avec `BrandIcon` niveau 1, et mode Plongée éditoriale).
  - **Lot 4.4 :** Assembler les sous-écrans d'items **S-22 (P1)** : `choice` (`revealOptionsDelayMs` 0–1 500 ms + bouton « Voir les options » + `ConfidencePicker`), `situation` (contexte + `ArtifactView` + 1–3 décisions), `predict`.
  - **Lot 4.5 :** Assembler les sous-écrans d'items **S-22 (P1 suite)** : `spotTheIssue` (sélection de ligne dans `ArtifactView` + rotor « Lignes » NS-4), `ordering` (Parsons 1D/2D avec alternative tap sans glisser), `commandComposer` (`TokenComposer`), et repli gracieux « Ce format arrive bientôt » + événement `item_format_unsupported`.
  - **Lot 4.6 :** Intégrer `NativeLessonAudioControls` habillé en Prism et valider XCUITest + `XCTOSSignpostMetric` sur la transition carte → carte (`≤ 100 ms`).
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un item `spotTheIssue` avec un artefact de 25 lignes à la taille Dynamic Type AX5 et VoiceOver actif, *when* l'apprenant navigue avec le rotor « Lignes », *then* aucune ligne n'est tronquée, chaque ligne est énoncée avec son numéro et l'action « Sélectionner cette ligne » valide le choix sans aucun geste de glisser (NS-4).
  - *Given* un format d'item futur inconnu du client, *when* la séance atteint cet item, *then* l'app affiche `PrismEmptyState` compact (« Ce format arrive bientôt »), émet `item_format_unsupported{format}` et permet de passer à la carte suivante sans plantage (§6.4).

---

### Phase 5 — Quiz, Feedback, Résultats, Situation du jour & Examen blanc
- **Taille estimée :** **L** (5 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-5-quiz-feedback-results` · **Tag de sortie :** `transform-phase-5-done`
- **Prérequis :** `transform-phase-4-done` validé + **DR-004 `APPROVED`**.
- **Flags :** `feedback.v2`, `daily.situation`.
- **Tests à écrire AVANT toute modification :**
  1. Tests unitaires de `FeedbackPanel` (états correct, incorrect, partiel, variante « Erreur avec certitude », explication de l'option choisie + bonne réponse + dépliage des autres options, fausse idée nommée, `ResponsibilityMatrix`, `TakeawayLine`).
  2. Tests unitaires et XCUITest de la **Situation du jour (`S-30`)** vérifiant qu'aucune statistique communautaire n'est accessible avant soumission et que la carte de partage `S-95` ne contient ni l'énoncé ni la bonne réponse ni aucune icône d'éditeur (NS-7, §22A.5).
  3. Tests unitaires et XCUITest de l'**Examen blanc (`S-50`, `S-51`, `S-52`)** vérifiant l'absence totale de feedback pendant l'épreuve et l'option temps majoré / sans limite (NS-11).
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 5.1 :** Implémenter **S-23 (`FeedbackPanel`)** en un seul temps derrière `feedback.v2` : indicateur de vérification dès `300 ms`, affichage ≤ `1 s` p95 en ligne, haptique `PrismHapticToken.correct` / `incorrectSoft` (jamais `.error`), explication par option et fausse idée nommée.
  - **Lot 5.2 :** Implémenter **S-25 (Résultats de séance)** : bilan des concepts ancrés, fausses idées résolues, mise à jour du Rythme, retour à Aujourd'hui.
  - **Lot 5.3 :** Implémenter **S-30 (Situation du jour)** et **S-95 (`ShareCardRenderer`)** derrière `daily.situation` : révélation de `CommunityDistributionChart` après réponse uniquement, génération d'image de partage sans spoiler ni marque tierce.
  - **Lot 5.4 :** Restructurer `NativeMockExamView` en **S-50 (Intro + choix du temps : normal / majoré +50 % / sans limite)**, **S-51 (Lecteur d'examen blanc sans feedback)** et **S-52 (Débrief par domaine d'examen)** tout en préservant `examStore` et `POST /api/exam/generate` / `POST /api/exam/submit`.
  - **Lot 5.5 :** Implémenter les formats d'items P2 (`readLog`, `diagnose`, `diagramCompletion`, `tradeOff`, `classify`) et valider les parcours XCUITest #2, #3, #4 et #7 (§32.2).
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un apprenant qui choisit « Sûr » sur `ConfidencePicker` puis valide une réponse erronée, *when* le serveur répond, *then* `FeedbackPanel` s'affiche en ≤ 1 s perçu avec la variante dédiée « Erreur avec certitude », l'explication de l'option choisie, la bonne réponse et la fausse idée nommée (NS-5).
  - *Given* la Situation du jour `S-30`, *when* l'apprenant n'a pas encore répondu, *then* aucune distribution communautaire n'est présente en mémoire UI ni à l'écran ; *and when* il génère la carte de partage `S-95`, *then* l'image rendue ne contient ni la question, ni la réponse, ni aucun logo tiers (NS-7, §22A.5).

---

### Phase 6 — Progress, Mastery, Readiness & Atlas
- **Taille estimée :** **L** (6 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-6-atlas-mastery-readiness` · **Tag de sortie :** `transform-phase-6-done`
- **Prérequis :** `transform-phase-5-done` validé.
- **Flags :** `atlas.v1`, `readiness.v2`.
- **Tests à écrire AVANT toute modification :**
  1. Tests unitaires de mapping des états de concept (`Découvert`, `En pratique`, `Ancré`, `Maîtrisé`), des 5 échelons (`DepthLadderView`), de la rétention prédite en mots (« solide », « à raviver bientôt », « s'estompe ») et des bandes de Préparation (`insufficientEvidence`, `notYet`, `onTrack`, `readyToTry`, `veryReady`).
  2. Test unitaire vérifiant qu'aucun pourcentage de réussite n'est affiché tant que `calibrated != true` (NS-10, §8).
  3. Test de performance Instruments / XCTest sur `AtlasCanvas` (`60 i/s` avec ≤ 500 nœuds visibles) et test d'équivalence VoiceOver (`AtlasList` activé par défaut sous VoiceOver, NS-8).
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 6.1 :** Implémenter **S-40 (`AtlasList` + `AtlasCanvas`)**, **S-41 (Région)** et **S-42 (Territoire)** derrière `atlas.v1`, avec bascule automatique sur `AtlasList` lorsque `UIAccessibility.isVoiceOverRunning == true` (NS-8).
  - **Lot 6.2 :** Implémenter **S-43 (Page Concept)** : `MasteryGlyph`, `DepthLadderView`, rétention en mots, fausse idée active, `BrandLabel` (`.learningContent` niveau 1), et bouton « Pratiquer 1 min ».
  - **Lot 6.3 :** Implémenter **S-11 (Mémoire détail)** avec `MemoryForecastChart` (Swift Charts + motifs accessibles Differentiate Without Color §28).
  - **Lot 6.4 :** Implémenter **S-47 (Route / Objectif)**, **S-48 (Objectif d'examen détail)**, **S-49 (Préparation honnête `ReadinessBandView` NS-10)** et **S-53 (Déclarer mon résultat d'examen)** derrière `readiness.v2`.
  - **Lot 6.5 :** Implémenter **S-71 (Passeport)** (avec liens de vérification externe Credly/Microsoft Learn sans jamais intégrer d'image de badge §22A.2), **S-72 (Historique & calibration)** et **S-90 (Recherche globale)**.
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un objectif actif avec un nombre de preuves insuffisant ou un modèle serveur non calibré (`calibrated == false`), *when* l'utilisateur ouvre `S-49` Préparation, *then* l'écran affiche la bande (`Preuves insuffisantes` / `En bonne voie`), la barre d'incertitude et les 3 actions recommandées, sans **aucun** pourcentage de probabilité de réussite (NS-10).
  - *Given* VoiceOver actif, *when* l'utilisateur ouvre l'onglet Atlas `S-40`, *then* le mode Liste accessible est présenté par défaut avec 100 % des informations et actions de la Carte, et la Carte maintient 60 i/s avec 500 nœuds (NS-8).

---

### Phase 7 — Gamification au service de l'apprentissage
- **Taille estimée :** **M** (4 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-7-gamification` · **Tag de sortie :** `transform-phase-7-done`
- **Prérequis :** `transform-phase-6-done` validé + **DR-005 `APPROVED`**.
- **Flags :** `rhythm.v1`, `rhythm.dailyStreakOptIn`, `celebrations.v1`, `missions.v1`, `events.v1`.
- **Tests à écrire AVANT toute modification :**
  1. Fichiers de spécification dans `docs/transformation/specs/` citant la règle d'apprentissage servie par chaque mécanique (§9, §16 principe 1).
  2. Tests unitaires de `RhythmWeekView` (objectif 3–6 j/sem, 2 jours de repos inclus, pause jusqu'à 4 semaines, rattrapage gratuit par 3 rappels, validation d'un jour dès 1 séance Express ou 1 Situation du jour + 3 rappels, §7, §9).
  3. Tests unitaires de `PrismCelebration` (niveaux 0–3, plafonnement au niveau 1 en Mode Calme, fondu ≤ `0,3 s` sous Reduce Motion, touchable pour passer).
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 7.1 :** Implémenter le **Rythme hebdomadaire (`RhythmWeekView`)**, le réglage `S-75` (3–6 j/sem + pause) et l'état **S-12 (Bon retour)** derrière `rhythm.v1`.
  - **Lot 7.2 :** Implémenter les **Jalons de maîtrise** (1er *Maîtrisé*, territoire complet, examen blanc ≥ 80 %, 10 fausses idées corrigées, passage au lab) et les célébrations « Réfraction » (`PrismCelebration` + haptique/son `declic`) derrière `celebrations.v1`.
  - **Lot 7.3 :** Implémenter les **Missions hebdomadaires** (≤ 3 par semaine liées à une compétence, dont 1 coopérative Squad) derrière `missions.v1` et le support des Temps forts (`events.v1`).
  - **Lot 7.4 :** Sous `rhythm.v1`, masquer de l'UI l'XP, les niveaux génériques, les succès de volume et désactiver le basculement automatique d'icône `streakAtRisk` (en mettant à jour `test_native_prism_presentation.py:268-285`) ; exposer l'option `rhythm.dailyStreakOptIn` (désactivée par défaut) dans `Profil` uniquement.
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un utilisateur qui revient après 5 jours d'absence avec `rhythm.v1` activé, *when* il ouvre Aujourd'hui, *then* l'état `S-12` « Bon retour » s'affiche sans aucun message de perte ni icône `streakAtRisk`, et propose un rattrapage gratuit en 3 rappels.
  - *Given* Reduce Motion ou le Mode Calme activé, *when* un concept passe à l'état *Maîtrisé*, *then* la célébration respecte le plafond configuré (fondu ≤ 0,3 s sous Reduce Motion ; niveau ≤ 1 en Mode Calme) et s'annonce une seule fois sous VoiceOver.
---

### Phase 8 — Social, Collaborative & Competitive (`Ensemble`)
- **Taille estimée :** **M** (4 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-8-social-ensemble` · **Tag de sortie :** `transform-phase-8-done`
- **Prérequis :** `transform-phase-7-done` validé.
- **Flags :** `social.v2`.
- **Tests à écrire AVANT toute modification :**
  1. Tests unitaires vérifiant que le profil social est **privé par défaut**, que les ligues sont **désactivées par défaut** (NS-12), qu'aucun échec n'est jamais exposé à autrui et qu'aucun accès aux contacts n'est demandé (§10).
  2. Tests unitaires et de contrats pour les Squads (`S-61/62`), Amis (`S-63/64`), Défis asynchrones sans chronomètre (`S-65`), Ligues de progression Glicko-2 (`S-66`) et actions de sécurité (bloquer, masquer, signaler).
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 8.1 :** Implémenter **S-60 (Ensemble)**, **S-78 (Confidentialité & visibilité granulaire)** et les contrôles de modération (bloquer, masquer, signaler, mode mineurs / âge minimum) derrière `social.v2`.
  - **Lot 8.2 :** Implémenter **S-61 / S-62 (Squad coopérative 3–8 membres, `SquadGoalView`, `KudosButton` en 1 tap sans texte libre)** et **S-67 (Inviter par lien / code / QR)**.
  - **Lot 8.3 :** Implémenter **S-63 / S-64 (Amis & Profil ami)** (branchés sur `/api/friends` existant) et **S-31 (Historique des Situations du jour)**.
  - **Lot 8.4 :** Implémenter **S-65 (Défi asynchrone : 5 items, score = justesse × calibration, sans chronomètre)** et **S-66 (Ligues de progression opt-in : ±3 voisins, pas de relégation les 4 premières semaines)**.
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un nouvel utilisateur ou un utilisateur existant activant `social.v2`, *when* il ouvre l'onglet `Ensemble` (`S-60`), *then* son profil est privé par défaut, les ligues de progression sont désactivées par défaut, et aucune boîte de dialogue d'accès aux contacts n'est déclenchée (NS-12).
  - *Given* un défi asynchrone `S-65`, *when* l'apprenant répond aux 5 items, *then* aucun chronomètre n'est affiché ni pris en compte dans le score (`justesse × calibration`).

---

### Phase 9 — AI-Native Experience (IA contextuelle, ancrée et à contrat d'effort)
- **Taille estimée :** **M** (4 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-9-contextual-ai` · **Tag de sortie :** `transform-phase-9-done`
- **Prérequis :** `transform-phase-8-done` validé.
- **Flags :** `ai.contextual`.
- **Tests à écrire AVANT toute modification (§11) :**
  1. Tests unitaires de `AIRouter` dans `CertigoData` : (a) cascade `FoundationModels` sur appareil → PCC → `POST /api/tutor/explain` → explication auteur déterministe → abstention + lien doc officielle, (b) timeout strict p95 `2,5 s` basculant vers le niveau suivant, (c) blocage de tout appel cloud tant que le consentement nommant le fournisseur (`S-79`) n'est pas accordé, (d) expurgation locale des secrets/PII avant envoi, (e) **contrat d'effort** (impossible d'appeler l'IA avant une 1re tentative).
  2. Suite d'évaluation adverse (`AIEvaluationTests`, bloquante pour la release §11) : scripts « donne la réponse », « vraies questions d'examen », prompt injection, et test de non-complaisance (jamais de verdict renversé sous la pression).
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 9.1 :** Implémenter `AIRouter` dans `CertigoData` + expurgation locale de secrets + réglage de consentement `S-79` (App Review 5.1.2(i)).
  - **Lot 9.2 :** Implémenter **S-24 (Sheet `Indice` gradué à 4 niveaux / `Expliquer autrement` / `Pourquoi ?` 2 tours max)** avec étiquette obligatoire « IA · d'après la fiche *X* · vérifiée le *date* » et boutons pouce haut/bas + Signaler.
  - **Lot 9.3 :** Implémenter **S-44 (Comparer deux concepts/produits)**, **S-45 (Carte de mes fausses idées)** et l'item formatif `explain` (explain-it-back texte/dictée).
  - **Lot 9.4 :** Exécuter et documenter la suite complète `AIEvaluationTests` (jeux de référence + scripts adverses).
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un item auquel l'apprenant n'a pas encore tenté de répondre, *when* l'écran d'item s'affiche, *then* aucune action IA ni indice ne révèle la réponse avant une première tentative (§11, §16 principe 3).
  - *Given* un délai serveur > `2,5 s` ou le réglage « IA dans le cloud » désactivé sans modèle local disponible, *when* l'apprenant demande « Expliquer autrement », *then* `AIRouter` bascule silencieusement sur l'explication auteur déterministe et émet `ai_fallback{from, reason}` (§11, §29).

---

### Phase 10 — Remaining Screens & Surfaces Système iOS
- **Taille estimée :** **L** (5 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-10-onboarding-pro-ios-surfaces` · **Tag de sortie :** `transform-phase-10-done`
- **Prérequis :** `transform-phase-9-done` validé + **DR-009 `APPROVED`**.
- **Flags :** `onboarding.v2`, `pro.v1`, `widgets.v1`.
- **Tests à écrire AVANT toute modification :**
  1. XCUITest du parcours critique #1 (`Premier lancement S-01 → Situation de découverte S-02 hors ligne → Premier Déclic S-03 → Objectif & Rythme S-04 → Sauvegarder S-05 → Aujourd'hui S-10 → 1re séance → S-06 notifications`, NS-1).
  2. Tests StoreKit 2 (`Configuration.storekit` local) pour `S-73` CertiGo Pro (achat, restauration, annulation, absence totale de paywall pendant l'onboarding).
  3. Tests unitaires et d'intégration pour `W-1`..`W-3` (dont `W-3` interactif mettant la réponse en file sans ouvrir l'app, NS-14), `LA-1`..`LA-3`, `CC-1` et `AI-1` (App Intents + Spotlight en 8 langues), ainsi que la purge complète lors de `performDeletionCleanup()`.
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 10.1 :** Implémenter le premier lancement en 60 s (**S-01 à S-06**, NS-1) et le **Mode Invité** sur contenu public réel derrière `onboarding.v2` ; confiner définitivement `NativeDemoRoot` sous `#if DEBUG` (**DR-009**).
  - **Lot 10.2 :** Compléter tous les écrans de **Réglages (`S-74` à `S-84`)**, y compris l'habillage Prism de **S-82 (Suppression du compte)** et la purge explicite de `CertigoWidgetStore` + `CertigoAppIconPreferenceStore` dans `performDeletionCleanup()`.
  - **Lot 10.3 :** Implémenter **S-73 (CertiGo Pro)** avec StoreKit 2 (`SubscriptionStoreView`) derrière `pro.v1`.
  - **Lot 10.4 :** Ajouter l'entitlement `com.apple.security.application-groups` (`group.com.certigo.native`), finaliser **W-1 (Aujourd'hui)**, **W-2 (Situation du jour)** et **W-3 (Carte de révision interactive via App Intents, NS-14)** dans `CertigoWidgetExtension` derrière `widgets.v1` (**sans aucun actif de marque tiers** §22A.5).
  - **Lot 10.5 :** Implémenter **LA-1 / LA-2 / LA-3 (Live Activities `ActivityKit`)**, **CC-1 (Control Center « Express 5 min »)** et **AI-1 (App Intents + Spotlight `ConceptEntity` / `RouteEntity` localisés en 8 langues)**.
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* un premier lancement à froid hors ligne (mode avion), *when* l'utilisateur ouvre l'app, *then* il réalise sa première décision technique dans `S-02` en ≤ 2 écrans, sans aucun champ texte ni paywall (NS-1).
  - *Given* le widget interactif `W-3` (Carte de révision), *when* l'utilisateur valide une réponse depuis l'écran d'accueil iOS, *then* la réponse est enregistrée dans `SubmissionStore` du conteneur App Group sans ouvrir l'application (NS-14).

---

### Phase 11 — Accessibility, Performance & Visual Hardening
- **Taille estimée :** **M** (4 lots ≤ 1 journée d'agent chacun)
- **Branche :** `transform/phase-11-hardening` · **Tag de sortie :** `transform-phase-11-done`
- **Prérequis :** `transform-phase-10-done` validé + ≥ 2 semaines de stabilité flags ON pour le nettoyage des anciens chemins (§36).
- **Flags :** Passage des valeurs par défaut compilées à `true` et suppression des anciens chemins de code obsolètes.
- **Lots de travail (≤ 1 j chacun) :**
  - **Lot 11.1 (Audit Accessibilité complet §28) :** Exécution de `XCUIApplication().performAccessibilityAudit()` sur 100 % des écrans (`S-01` à `S-95`), validation AX5, VoiceOver, Voice Control (`accessibilityInputLabels`), Full Keyboard Access, Increase Contrast, Reduce Motion, Reduce Transparency, Differentiate Without Color, Mode Calme → dossier d'éligibilité aux **Accessibility Nutrition Labels** App Store.
  - **Lot 11.2 (Performance & Énergie §30) :** Campagne Instruments (App Launch ≤ 400 ms / ≤ +10 % vs baseline, Hitches < 5 ms/s sur Aujourd'hui et Atlas, Atlas 60 i/s / 120 ProMotion, Mémoire < 200 Mo, Taille < 60 Mo hors packs, 0 timer/animation au repos).
  - **Lot 11.3 (Conformité Marques & App Store §22A.7, §22A.10) :** Audit final `BrandAssetsTests` + génération du jeu de captures App Store **sans aucune icône ni logo d'éditeur tiers** (mode capture dédiée / `brand.icons.v1 == false`) + notes pour App Review.
  - **Lot 11.4 (Nettoyage & Documentation finale §35.1) :** Retrait des anciens chemins d'UI rendus obsolètes après ≥ 2 semaines flags ON, vérification `0 violation` dans `ArchitectureTests`, mise à jour de `docs/transformation/CHANGELOG.md`.
- **Critères d'acceptation (Given / When / Then) :**
  - *Given* l'ensemble du code des fonctionnalités de `CertigoNative`, *when* `ArchitectureTests` et `BrandAssetsTests` s'exécutent, *then* 0 valeur brute hors `Prism` et 0 violation de marque tierce ne subsistent (§35.1).
  - *Given* les 8 parcours critiques XCUITest (§32.2), *when* la suite UI et `performAccessibilityAudit()` s'exécutent sur iPhone et iPad, *then* 100 % des parcours et audits sont verts et tous les budgets du §30 sont respectés.

---

## 4. Tableau récapitulatif des Phases, Tailles, Flags et Points de contrôle

| Phase | Intitulé | Taille | Nb Lots (≤ 1 j) | Flags activables | DR prérequises | Tag Git de contrôle |
|---|---|---|---|---|---|---|
| **0** | Audit + Baseline (lecture seule) | M | — | — | — | `transform-baseline` |
| **1** | Prism Foundations & Découpage du monolithe | **M** | 5 | `prism.enabled` | DR-001, DR-002, DR-007, DR-009 | `transform-phase-1-done` |
| **2** | Core Components | **L** | 5 | — | — | `transform-phase-2-done` |
| **2B** | Official Brand Assets (§22A) | **M** | 4 | `brand.icons.v1`, `brand.icons.<vendor>` | **DR-006**, **DR-010** | `transform-phase-2b-done` |
| **3** | Home / Today & Navigation v2 | **M** | 4 | `nav.v2`, `today.v2` | — | `transform-phase-3-done` |
| **4** | Learning Experience (Séance & Formats P1) | **L** | 6 | `session.v2` | — | `transform-phase-4-done` |
| **5** | Quiz, Feedback, Résultats & Situation du jour | **L** | 5 | `feedback.v2`, `daily.situation` | **DR-004** | `transform-phase-5-done` |
| **6** | Progress, Mastery, Readiness & Atlas | **L** | 5 | `atlas.v1`, `readiness.v2` | — | `transform-phase-6-done` |
| **7** | Gamification (Rythme & Célébrations) | **M** | 4 | `rhythm.v1`, `rhythm.dailyStreakOptIn`, `celebrations.v1`, `missions.v1`, `events.v1` | **DR-005** | `transform-phase-7-done` |
| **8** | Social, Collaborative & Competitive (`Ensemble`) | **M** | 4 | `social.v2` | — | `transform-phase-8-done` |
| **9** | AI-Native Experience (`AIRouter` & Aides ancrées) | **M** | 4 | `ai.contextual` | — | `transform-phase-9-done` |
| **10** | Onboarding 60 s, Pro & Surfaces système iOS | **L** | 5 | `onboarding.v2`, `pro.v1`, `widgets.v1` | **DR-009** | `transform-phase-10-done` |
| **11** | Accessibility, Performance & Visual Hardening | **M** | 4 | Activation par défaut + nettoyage | **DR-003**, **DR-008** | `transform-phase-11-done` |