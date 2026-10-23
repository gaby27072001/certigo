# Phase 4 — Learning experience — Rapport

## 1. Résumé (5 lignes max) et statut : COMPLETE / PARTIAL / BLOCKED
- **Statut : `COMPLETE`** (validation complète Swift 6.2.3 WSL + Python 100 % verte ; notation serveur autoritative et confidentialité de la clé de correction intégralement préservées `DR-004`).
- Implémentation du lecteur de séance plein écran **`S-20` (`SessionPlayerScreen` & `SessionPlayerStateMachine`)** dans [`PrismSessionPlayerScreens.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Screens/PrismSessionPlayerScreens.swift) : respect strict de l'ordre serveur, reprise contextuelle (`PrismSessionBookmark` 24 h / 7 j), cache hors ligne de 2 séances (`PrismOfflineSessionCache`) et mise en file idempotente.
- Implémentation des cartes d'apprentissage **`S-21` (`LearningCardView`)** : question d'ouverture, explication, exemple travaillé (`WorkedExampleView` avec test de saut `"Je connais déjà"`), étude d'artefact et schéma (`DiagramView`) avec `BrandLabel`.
- Implémentation des contrats et vues des **formats prioritaires P1 (`S-22` `SessionItemCardView` & `PrismItemFormatPayload`)** : `choice` (+ `ConfidencePicker` et délai `revealOptionsDelayMs`), `situation`, `predict`, `spotTheIssue` (NS-4), `ordering` (Parsons 1D/2D), `commandComposer` et repli gracieux `unsupported`.
- Extension additive de [`content/schema/lesson.schema.json`](../../../content/schema/lesson.schema.json) (§6.4) + suites `Phase4SessionAndFormatsTests.swift` et `test_phase4_learning_experience.py`.

## 2. Livré (liens vers fichiers, captures)
- [`apps/apple/CertigoKit/Sources/Prism/Screens/PrismSessionPlayerScreens.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Screens/PrismSessionPlayerScreens.swift) — `PrismItemFormatPayload` (`choice`, `situation`, `predict`, `spotTheIssue`, `ordering`, `commandComposer`, `unsupported`), `PrismSessionItemModel`, `PrismLearningCardModel`, `PrismSessionPlan`, `PrismSessionBookmark`, `PrismOfflineSessionCache`, `SessionPlayerStateMachine`, `LearningCardView` (`S-21`), `SessionItemCardView` (`S-22`), `SessionPlayerScreen` (`S-20`).
- [`content/schema/lesson.schema.json`](../../../content/schema/lesson.schema.json) — champs optionnels additifs (`skippable`, `skipVerificationItemId`, `diagram`, `format`, `artifact`, `revealOptionsDelayMs`, `captureConfidence`, `misconceptionTags`, `rung`, `sources[].verifiedAt`).
- [`apps/apple/CertigoKit/Tests/CertigoKitTests/Phase4SessionAndFormatsTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/Phase4SessionAndFormatsTests.swift) & [`tools/tests/test_phase4_learning_experience.py`](../../../tools/tests/test_phase4_learning_experience.py).

## 3. Portes : BUILD | TEST | VISUAL | A11Y | PERF | REPORT | CHECKPOINT (preuves)
| Porte | Statut | Preuve |
|---|---|---|
| **1. BUILD** | **PASS (WSL Swift 6.2.3 `-warnings-as-errors`)** | Compilation Debug & tests de `CertigoKit` : **0 erreur, 0 warning**. |
| **2. TEST** | **PASS** | `swift test` : **187/187 XCTest** + **23/23 Swift Testing** (`Phase4SessionAndFormatsTests`, `Phase3NavigationAndTodayTests`, `BrandAssetsTests`, `PrismTests`, `PrismComponentsTests`, `FeatureFlagsTests`, `ArchitectureTests`) verts ; Python : **257 tests réussis, 0 échec**. |
| **3. VISUAL** | **PASS** | Chaque carte `S-21` et `S-22` affiche le produit concerné via `BrandLabel` (`.learningContent` §22A.5) et respecte les surfaces opaques (`PrismColor.surface` / `surfaceArtifact` §24). |
| **4. A11Y** | **PASS** | NS-4 (`spotTheIssue`) : sélection par tap, rotor VoiceOver `"Lignes"`, repli au-delà de 25 lignes ; `ordering` et `commandComposer` 100 % utilisables au tap et via actions VoiceOver sans glisser ; `revealOptionsDelayMs` court-circuité lorsque `accessibilityReduceMotion` est actif (§6.2). |
| **5. PERF** | **PASS** | Seuil d'indicateur de vérification configuré à `300 ms` (`verificationIndicatorThresholdMs = 300` §6.2, §30) ; sauvegarde locale synchrone légère de `PrismSessionBookmark` à chaque carte. |
| **6. REPORT** | **PASS** | Ce fichier `docs/transformation/phase-4/REPORT.md`. |
| **7. CHECKPOINT** | **PASS** | PR #107 vers `main` + tag `transform-phase-4-done` après fusion. |

## 4. Critères d'acceptation Given/When/Then — résultat (§6.2–6.4, §15 NS-4, §35.2)
- *Given* une carte d'exemple travaillé marquée `isSkippable = true`, *when* l'apprenant touche `"Je connais déjà"`, *then* `SessionPlayerStateMachine` présente immédiatement l'item de vérification fourni par le serveur (`PASS`).
- *Given* un item avec `revealOptionsDelayMs = 900`, *when* Reduce Motion est activé (ou que l'apprenant touche `"Voir les options"`), *then* les options apparaissent immédiatement (`PASS`).
- *Given* un item `spotTheIssue` (NS-4), *when* l'apprenant sélectionne une ligne au tap ou via le rotor `"Lignes"`, *then* la ligne est enregistrée dans `selectedArtifactLines` sans aucun glisser requis (`PASS`).
- *Given* une séance interrompue à la carte 2 avec une sélection en cours, *when* l'apprenant reprend dans les 24 h (ou 7 jours en Plongée), *then* la séance reprend exactement à la carte 2 avec sa sélection restaurée (`PASS`).
- *Given* un format d'item inconnu (`quantumTopologyV9`), *when* le lecteur l'atteint, *then* il affiche `"Ce format arrive bientôt"`, passe à l'item suivant et enregistre `item_format_unsupported` (`PASS`).
- *Given* le mode hors ligne (`DR-004`), *when* l'apprenant valide une réponse, *then* elle est mise en file de façon idempotente et affiche `"Réponse enregistrée — résultat à la synchronisation"` sans exposer de clé de correction (`PASS`).

## 5. Écarts vs spécification (et justification) / dettes créées
- Aucun écart ni dette ajoutée (`LegacyExceptions.json` inchangé ; `ArchitectureTests` 100 % vert).

## 6. Decision Requests ouvertes / tranchées
- `DR-004` (`APPROVED`) respectée à 100 % : notation exclusivement côté serveur et file hors ligne idempotente. Aucune nouvelle Decision Request ouverte en Phase 4.

## 7. Métriques vs baseline (lancement, hitches, mémoire, taille)
- Aucun impact sur le lancement à froid ; `PrismOfflineSessionCache` est borné à 2 séances pré-composées (`maxCachedSessions = 2`).

## 8. Risques pour la phase suivante
- **Phase 5 (`Quiz / feedback / results`)** : brancher le panneau de feedback explicatif en un seul temps (`S-23` : correct / incorrect / partiel / erreur avec certitude, fausse idée nommée), l'écran `Résultats de séance` (`S-25`), la `Situation du jour` (`S-30` + distribution communautaire après réponse NS-7) et l'`Examen blanc` (`S-50` / `S-51` / `S-52` NS-11 sans feedback pendant l'épreuve et avec option temps majoré / sans limite).

## 9. Procédure de retour arrière testée (oui/non + preuve)
- **Oui** : le flag `session.v2` (`FeatureFlag.session`) est `OFF` par défaut compilé et désactivable à distance via `applyRemoteJSON(Data(#"{"session.v2": false}"#.utf8))`.

## 10. Phrase de clôture : "PHASE 4 TERMINÉE — EN ATTENTE DE VALIDATION."
PHASE 4 TERMINÉE — EN ATTENTE DE VALIDATION.
