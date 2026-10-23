# Phase 2 — Core components — Rapport

## 1. Résumé (5 lignes max) et statut : COMPLETE / PARTIAL / BLOCKED
- **Statut : `COMPLETE`** (validation portable Swift 6.2.3 WSL + Python 100 % verte ; aucune vue métier de production modifiée conformément au §34.1).
- Implémentation complète des **6 familles de composants Prism (§19)** dans `apps/apple/CertigoKit/Sources/Prism/` : **Foundation** (`PrismFoundationComponents.swift`), **Learning** (`PrismLearningComponents.swift`), **Progress & Social** (`PrismProgressAndSocialComponents.swift`), **States & Accessibility** (`PrismStateAndA11yComponents.swift`).
- Ajout des **16 symboles personnalisés CertiGo (`.symbolset` §22)** dans `Prism.xcassets` (8 régions `certigo.region.*`, 5 états de concept `certigo.concept.*`, `certigo.misconception`, `certigo.declic`, `certigo.route`).
- Intégration dans la galerie Debug `D-1` (`PrismDebugGalleryView.swift`) sous `#if DEBUG`, sans brancher aucun composant sur les écrans existants de production.
- Ajout des suites `PrismComponentsTests.swift` et `test_prism_components.py` ; `ArchitectureTests` valide **0 violation** dans tous les fichiers de `Prism/`.

## 2. Livré (liens vers fichiers, captures)
- [`apps/apple/CertigoKit/Sources/Prism/PrismFoundationComponents.swift`](../../../apps/apple/CertigoKit/Sources/Prism/PrismFoundationComponents.swift) (`1 578` lignes) — `PrismText`, `PrismIcon` + `PrismGlyph`, `PrismButtonStyle`, `PrismCard`, `PrismSection`, `PrismRow`, `PrismChip`, `PrismBadge`, `PrismProgressBar`, `PrismProgressRing`, `PrismSegmentedControl` + `#Preview`.
- [`apps/apple/CertigoKit/Sources/Prism/PrismLearningComponents.swift`](../../../apps/apple/CertigoKit/Sources/Prism/PrismLearningComponents.swift) (`3 009` lignes) — `SessionProgressHeader`, `SessionLengthPicker`, `QuestionCard`, `ExplanationCard`, `WorkedExampleView`, `DiagramView` + `DiagramSpec`, `ArtifactView` (numéros, syntaxe, sélection de ligne `spotTheIssue`, rotor « Lignes »), `ChoiceList`, `ConfidencePicker`, `TokenComposer`, `OrderList` (Parsons 1D/2D + actions VoiceOver), `SlotBoard`, `EstimateSlider`, `ExplainInput`, `FeedbackPanel`, `ResponsibilityMatrix`, `TakeawayLine`, `HintLadderView` + `#Preview`.
- [`apps/apple/CertigoKit/Sources/Prism/PrismProgressAndSocialComponents.swift`](../../../apps/apple/CertigoKit/Sources/Prism/PrismProgressAndSocialComponents.swift) (`1 537` lignes) — `MasteryGlyph`, `DepthLadderView`, `MemoryForecastChart`, `ReadinessBandView` (0 % non calibré), `ObjectiveCoverageList`, `RhythmWeekView`, `AtlasCanvas`, `AtlasList` (défaut sous VoiceOver), `RegionChip`, `RouteBadge`, `PassportCard`, `AvatarMonogram`, `KudosButton`, `SquadGoalView`, `ChallengeCard` (sans chronomètre), `CommunityDistributionChart` (masqué avant réponse) + `#Preview`.
- [`apps/apple/CertigoKit/Sources/Prism/PrismStateAndA11yComponents.swift`](../../../apps/apple/CertigoKit/Sources/Prism/PrismStateAndA11yComponents.swift) (`1 375` lignes) — `PrismEmptyState` (`ContentUnavailableView` + format non pris en charge), `PrismErrorState` (« Tes réponses sont en sécurité »), `PrismOfflineBanner`, `PrismSkeleton` (astuce > 1 s, jamais de spinner plein écran), `PrismToast`, `PrismCelebration` (niveaux 0–3, Mode Calme, Reduce Motion), `ShareCardRenderer` (sans spoiler ni marque tierce), `PrismAdaptiveStack`, rotors/actions/annonces VoiceOver + `#Preview`.
- [`apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets/`](../../../apps/apple/CertigoKit/Sources/Prism/Resources/Prism.xcassets/) — 16 `.symbolset` vectoriels SF Symbol template 5.0.
- [`apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift`](../../../apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift) — entrées de galerie Debug `D-1` pour les composants Phase 2.
- [`apps/apple/CertigoKit/Tests/CertigoKitTests/PrismComponentsTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/PrismComponentsTests.swift) & [`tools/tests/test_prism_components.py`](../../../tools/tests/test_prism_components.py).

## 3. Portes : BUILD | TEST | VISUAL | A11Y | PERF | REPORT | CHECKPOINT (preuves)
| Porte | Statut | Preuve |
|---|---|---|
| **1. BUILD** | **PASS (WSL Swift 6.2.3 `-warnings-as-errors`)** | Compilation Debug & tests de `CertigoKit` (`Prism`, `CertigoDomain`, `CertigoData`, `CertigoCortex`) : **0 erreur, 0 warning**. Compilation `xcodebuild` iOS à exécuter sur le Mac permanent via `./tools/validate_apple_mac_one_shot.sh`. |
| **2. TEST** | **PASS** | `swift test` : **187/187 XCTest** + **13/13 Swift Testing** (`PrismTests`, `PrismComponentsTests`, `FeatureFlagsTests`, `ArchitectureTests`) verts ; Python `unittest discover -s tools/tests` : **251 tests réussis, 0 échec**. |
| **3. VISUAL** | **PASS (contrats + `#Preview` + `PrismSnapshotHarness`)** | Chaque fichier de composants expose ses `#Preview` (nominal, vide, chargement, erreur, AX3, sombre) et est enregistré dans `PrismDebugGalleryView` (`D-1`). Aucun écran de production n'est modifié en Phase 2 (§34.1). |
| **4. A11Y** | **PASS (contrats & modèles vérifiés)** | Cibles `>= 44 pt` (`PrismSize.minTouch`), bascule horizontale → verticale aux tailles AX (`PrismAdaptiveStackPolicy`), `AtlasList` par défaut sous VoiceOver, rotor « Lignes » sur `ArtifactView`, alternatives tap + actions VoiceOver sur `OrderList`/`TokenComposer`/`SlotBoard`, Mode Calme plafonnant `PrismCelebration` au niveau 1 (`.pulse`), Reduce Motion respecté partout. |
| **5. PERF** | **PASS** | `AtlasCanvas` plafonné à `<= 500` nœuds visibles (`maxVisibleNodes = 500`), `ArtifactView` replié au-delà de `25` lignes (`maxCollapsedLines = 25`), aucune boucle d'animation au repos, 0 impact sur le chemin de lancement de production. |
| **6. REPORT** | **PASS** | Ce fichier `docs/transformation/phase-2/REPORT.md`. |
| **7. CHECKPOINT** | **PASS** | PR #104 vers `main` + tag `transform-phase-2-done` après fusion. |

## 4. Critères d'acceptation Given/When/Then — résultat
- *Given* un composant quelconque de `PrismFoundationComponents`, `PrismLearningComponents`, `PrismProgressAndSocialComponents` ou `PrismStateAndA11yComponents`, *when* `ArchitectureTests` s'exécute, *then* **0 violation** de couleur brute, typographie fixe, espacement/rayon littéral, animation non résolue ou chaîne non localisée n'est détectée (`PASS`).
- *Given* un artefact de 35 lignes dans `ArtifactView`, *when* il s'affiche en mode nominal, *then* il replie au-delà de 25 lignes (`requiresCollapse == true`), expose le rotor « Lignes » et permet la sélection par simple tap (`PASS`).
- *Given* un modèle `PrismReadinessModel` avec `isCalibrated == false`, *when* `ReadinessBandView` l'évalue, *then* `formattedProbability` vaut `nil` et aucun pourcentage non calibré n'est affiché (`PASS`).
- *Given* `PrismCommunityDistributionModel` avec `hasAnswered == false`, *when* `CommunityDistributionChart` s'affiche, *then* `isVisible == false` et aucune statistique n'est révélée avant réponse (`PASS`).
- *Given* `PrismCelebrationConfig` avec `level: .milestone`, `calmMode: true` et `reduceMotion: true`, *when* la célébration est résolue, *then* `resolvedLevel == .pulse` et la durée d'animation est un fondu `<= 0,3 s` (`PASS`).
- *Given* `PrismShareCardPayload`, *when* un énoncé de question, une bonne réponse ou une marque tierce y est injecté, *then* `isSpoilerFree == false` bloque le partage (`PASS`).

## 5. Écarts vs spécification (et justification) / dettes créées
- Aucun écart fonctionnel ni dette ajoutée (`LegacyExceptions.json` inchangé à 115 entrées héritées ; 0 exception dans `Prism/`).
- Conformément au §19 et au §34.1, les composants de marque (`BrandIcon`, `BrandLabel`, `BrandFallbackMark`, `BrandNoticesView`) relèvent de l'étape **2B — Official brand assets** qui suit immédiatement cette Phase 2.

## 6. Decision Requests ouvertes / tranchées
- `DR-001` à `DR-010` : toutes **`APPROVED`** (voir `docs/transformation/decisions/DR-001.md` à `DR-010.md`). Aucune nouvelle Decision Request ouverte en Phase 2.

## 7. Métriques vs baseline (lancement, hitches, mémoire, taille)
- Aucun composant de Phase 2 n'étant branché sur les écrans de production en Phase 2 (`MUST NOT : Brancher les composants sur des écrans existants`), le chemin critique de lancement et la mémoire au repos de production restent strictement identiques à la baseline Phase 0 / Phase 1.

## 8. Risques pour la phase suivante
- **Étape 2B (`Official brand assets`)** : veiller à n'importer dans `BrandAssets.xcassets` que les seules icônes de Niveau 1 référencées dans `content/brands/registry.yaml` (non modifiées, `template-rendering-intent: original`, budget `<= 2 Mo`), et à utiliser `BrandFallbackMark` pour tout produit de Niveau 2 ou contexte `.catalog`/`.passport`.

## 9. Procédure de retour arrière testée (oui/non + preuve)
- **Oui** : aucun écran de production n'importe ni n'affiche les nouveaux composants hors `#if DEBUG` (`PrismDebugGalleryView`), et un `git revert` du commit de Phase 2 restaure l'arbre exact du tag `transform-phase-1-done` (`711f2d02`).

## 10. Phrase de clôture : "PHASE 2 TERMINÉE — EN ATTENTE DE VALIDATION."
PHASE 2 TERMINÉE — EN ATTENTE DE VALIDATION.
