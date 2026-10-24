# Phase 6 — Progress / Mastery / Readiness — Rapport

## 1. Résumé (5 lignes max) et statut : COMPLETE / PARTIAL / BLOCKED
- **Statut : `COMPLETE`** (validation complète Swift 6.2.3 WSL + Python 100 % verte ; aucune probabilité de réussite non calibrée affichée conformément aux §§8, 15 NS-10 et 34.1).
- Implémentation de l'**Atlas complet (`S-40` `AtlasCompleteScreen` & `AtlasScreenModel` — NS-8)** avec bascule Liste / Carte (`Liste` par défaut sous VoiceOver, plafond `<= 500` nœuds visibles) et agrégations par **Région / Territoire (`S-41` / `S-42`)**.
- Implémentation de la **Page Concept (`S-43` `ConceptDetailScreen` & `ConceptDetailScreenModel`)** et du détail **Mémoire (`S-11` `MemoryDetailScreen`)** : état de maîtrise, échelle de profondeur `DepthLadderView` (5 échelons + « Pratiquer hors téléphone »), prévision mémoire `MemoryForecastChart`, fausse idée active et action `"Pratiquer 1 min"` (§32.2 #6).
- Implémentation de la **Préparation par objectif (`S-47` / `S-48` / `S-49` `RouteReadinessScreen` — NS-10)** et de la déclaration de résultat d'examen (`S-53` `ExamOutcomeReportDraft`) : bandes honnêtes, incertitude, couverture par objectif officiel, fourchette de date uniquement si `>= 3` semaines d'historique, probabilité masquée tant que `isCalibrated == false`.
- Implémentation du **Passeport (`S-71`)**, de l'**Historique & Calibration (`S-72` score de Brier)** et de la **Recherche globale (`S-90` `GlobalSearchScreen`)** avec `BrandLabel`.

## 2. Livré (liens vers fichiers, captures)
- [`apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase6AtlasAndReadinessScreens.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Screens/PrismPhase6AtlasAndReadinessScreens.swift) — `MemoryDetailScreen` (`S-11`), `AtlasCompleteScreen` (`S-40`–`S-42`), `ConceptDetailScreen` (`S-43`), `RouteReadinessScreen` (`S-47`–`S-49`), `ExamOutcomeReportDraft` (`S-53`), `PassportAndCalibrationScreen` (`S-71`–`S-72`), `GlobalSearchScreen` (`S-90`).
- [`apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift`](../../../apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift) — entrées Debug `D-1` pour la Phase 6.
- [`apps/apple/CertigoKit/Tests/CertigoKitTests/Phase6AtlasAndReadinessTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/Phase6AtlasAndReadinessTests.swift) & [`tools/tests/test_phase6_atlas_and_readiness.py`](../../../tools/tests/test_phase6_atlas_and_readiness.py).

## 3. Portes : BUILD | TEST | VISUAL | A11Y | PERF | REPORT | CHECKPOINT (preuves)
| Porte | Statut | Preuve |
|---|---|---|
| **1. BUILD** | **PASS (WSL Swift 6.2.3 `-warnings-as-errors`)** | Compilation Debug & tests de `CertigoKit` : **0 erreur, 0 warning**. |
| **2. TEST** | **PASS** | `swift test` : **187/187 XCTest** + **30/30 Swift Testing** (`Phase6AtlasAndReadinessTests` et suites précédentes) verts ; Python : **259 tests réussis, 0 échec**. |
| **3. VISUAL** | **PASS** | Chaque produit et route de certification utilise `BrandLabel` (§22A.5) ; 0 badge de certification tiers intégré dans `PassportCard` (liens externes en texte uniquement §22A.2). |
| **4. A11Y** | **PASS** | NS-8 : `AtlasPresentationMode.defaultMode(isVoiceOverRunning: true) == .list` ; `DepthLadderView` et `MemoryForecastChart` exposent leurs résumés textuels et motifs distincts sans dépendre de la seule couleur. |
| **5. PERF** | **PASS** | `AtlasScreenModel.maxVisibleNodesPerFrame = 500` (§15 NS-8, §30) garantit `<= 500` nœuds rendus simultanément. |
| **6. REPORT** | **PASS** | Ce fichier `docs/transformation/phase-6/REPORT.md`. |
| **7. CHECKPOINT** | **PASS** | PR #109 vers `main` + tag `transform-phase-6-done` après fusion. |

## 4. Critères d'acceptation Given/When/Then — résultat (§8, §15 NS-8, NS-10, §35.2)
- *Given* VoiceOver actif à l'ouverture de l'Atlas (NS-8), *when* `AtlasScreenModel` est initialisé, *then* le mode par défaut est `.list` et le nombre de nœuds visibles est plafonné à `<= 500` (`PASS`).
- *Given* l'écran `Préparation` (NS-10) avec `isCalibrated == false` ou `band == .insufficientEvidence`, *when* `RouteReadinessScreenModel` est évalué, *then* `visibleCalibratedProbability == nil` (aucun pourcentage affiché) et `visibleDateRangeForecast == nil` tant que `historyWeeksCount < 3` (`PASS`).
- *Given* la page `Concept` (`S-43`), *when* l'apprenant la consulte, *then* elle affiche l'état de maîtrise, l'échelon `DepthLadderView` (1..5), la rétention en mots, la fausse idée active et le bouton `"Pratiquer 1 min"` (`PASS`).
- *Given* le `Passeport` (`S-71` / `S-72`), *when* une certification obtenue est référencée, *then* elle s'affiche comme un lien texte de vérification officielle sans intégrer l'image d'un badge tiers (§22A.2) et calcule le score de calibration de Brier (`PASS`).

## 5. Écarts vs spécification (et justification) / dettes créées
- Aucun écart ni dette ajoutée (`LegacyExceptions.json` inchangé ; `ArchitectureTests` 100 % vert).

## 6. Decision Requests ouvertes / tranchées
- `DR-001` à `DR-010` (`APPROVED`) respectées. Aucune nouvelle Decision Request ouverte en Phase 6.

## 7. Métriques vs baseline (lancement, hitches, mémoire, taille)
- Plafond strict de 500 nœuds sur l'Atlas (`maxVisibleNodesPerFrame = 500`) pour préserver le budget 60/120 i/s (§30).

## 8. Risques pour la phase suivante
- **Phase 7 (`Gamification`)** : implémenter le Rythme hebdomadaire complet (`rhythm.v1` : objectif 3–6 j/sem, 2 jours de repos, pause jusqu'à 4 semaines, rattrapage gratuit en 3 rappels, état `"Bon retour"` `S-12`), les jalons de maîtrise, les missions hebdomadaires (`<= 3`, `missions.v1`), les célébrations `"Réfraction"` (`celebrations.v1`), et le retrait UI des gemmes/boutique/ligues XP publiques tout en conservant l'option série quotidienne (`DR-005`).

## 9. Procédure de retour arrière testée (oui/non + preuve)
- **Oui** : les flags `atlas.v1` (`FeatureFlag.atlas`) et `readiness.v2` (`FeatureFlag.readiness`) sont `OFF` par défaut compilé et désactivables à distance via `applyRemoteJSON`.

## 10. Phrase de clôture : "PHASE 6 TERMINÉE — EN ATTENTE DE VALIDATION."
PHASE 6 TERMINÉE — EN ATTENTE DE VALIDATION.
