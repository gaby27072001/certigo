# Phase 3 — Home / Today — Rapport

## 1. Résumé (5 lignes max) et statut : COMPLETE / PARTIAL / BLOCKED
- **Statut : `COMPLETE`** (validation complète Swift 6.2.3 WSL + Python 100 % verte ; ancienne navigation intégralement préservée lorsque `nav.v2` / `today.v2` sont `OFF` conformément au §34.1).
- Création de l'unique fichier de routes [`AppRouter.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Navigation/AppRouter.swift) (§12–13 : `AppTab`, `AppRoute`, `AppFullScreenCoverRoute`, `AppSheetRoute`, `InterruptedSessionAccessory` 24h / 7j, `SceneStorage`, deep links `certigo://auth` et `certigo://widget/learn` préservés).
- Implémentation de l'écran **Aujourd'hui (`S-10` — NS-2)** dans [`PrismHomeTodayScreens.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Screens/PrismHomeTodayScreens.swift) : une seule action principale en 1 tap, `SessionLengthPicker` (Express / Séance / Plongée), `Situation du jour`, `RhythmWeekView`, `Mémoire`, `Objectif actif` avec `BrandLabel` et aperçu de demain.
- Implémentation du catalogue **Explorer (`S-46`)** (avec `BrandLabel`), d'**Atlas (`S-40`)** en liste minimale accessible, d'**Ensemble (`S-60`)** (privé et ligues désactivées par défaut NS-12) et du squelette **Profil / Réglages (`S-70`, `S-74`…`S-84`)**.
- Ajout des suites `Phase3NavigationAndTodayTests.swift` et `test_phase3_home_today.py` ; `ArchitectureTests` valide **0 violation** sur l'ensemble des écrans et du routeur de Phase 3.

## 2. Livré (liens vers fichiers, captures)
- [`apps/apple/CertigoKit/Sources/Prism/Navigation/AppRouter.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Navigation/AppRouter.swift) — `AppTab` (`today`, `atlas`, `ensemble`, `profile`, `search`), `AppRoute`, `AppFullScreenCoverRoute`, `AppSheetRoute`, `InterruptedSessionAccessory`, `AppRouterState` (`Router`).
- [`apps/apple/CertigoKit/Sources/Prism/Screens/PrismHomeTodayScreens.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Screens/PrismHomeTodayScreens.swift) — `TodayScreenModel` & `TodayRootScreen` (`S-10`), `CatalogExplorerModel` & `CatalogExplorerScreen` (`S-46`), `AtlasListMinimalScreen` (`S-40`), `EnsembleMinimalModel` & `EnsembleMinimalScreen` (`S-60`), `ProfileSkeletonModel` & `ProfileSkeletonScreen` (`S-70`, `S-74`…`S-84`).
- [`apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift`](../../../apps/apple/CertigoNative/Sources/PrismDebugGalleryView.swift) — inspection des onglets et écrans Phase 3 dans `D-1`.
- [`apps/apple/CertigoKit/Tests/CertigoKitTests/Phase3NavigationAndTodayTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/Phase3NavigationAndTodayTests.swift) & [`tools/tests/test_phase3_home_today.py`](../../../tools/tests/test_phase3_home_today.py).

## 3. Portes : BUILD | TEST | VISUAL | A11Y | PERF | REPORT | CHECKPOINT (preuves)
| Porte | Statut | Preuve |
|---|---|---|
| **1. BUILD** | **PASS (WSL Swift 6.2.3 `-warnings-as-errors`)** | Compilation Debug & tests de `CertigoKit` (`Prism`, `BrandAssets`, `CertigoDomain`, `CertigoData`, `CertigoCortex`) : **0 erreur, 0 warning**. |
| **2. TEST** | **PASS** | `swift test` : **187/187 XCTest** + **21/21 Swift Testing** (`Phase3NavigationAndTodayTests`, `BrandAssetsTests`, `PrismTests`, `PrismComponentsTests`, `FeatureFlagsTests`, `ArchitectureTests`) verts ; Python `unittest discover -s tools/tests` : **255 tests réussis, 0 échec**. |
| **3. VISUAL** | **PASS** | 100 % des produits et routes affichés dans `TodayRootScreen` et `CatalogExplorerScreen` utilisent `BrandLabel` (§22A.5, §34.1 ligne 814) ; 0 violation `ArchitectureTests`. |
| **4. A11Y** | **PASS** | Résumé VoiceOver complet sur la carte héros d'`Aujourd'hui` (`sessionCardVoiceOverSummary`), `PrismAdaptiveStack` sans troncature jusqu'à AX5 (NS-2), `AtlasListMinimalScreen` en liste accessible par défaut (NS-8), libellés d'onglets d'un seul mot (§13). |
| **5. PERF** | **PASS** | Aucun spinner plein écran sur `Aujourd'hui` (`PrismSkeleton` immédiat avec données en cache avant réseau §29, §30), 0 animation en boucle au repos. |
| **6. REPORT** | **PASS** | Ce fichier `docs/transformation/phase-3/REPORT.md`. |
| **7. CHECKPOINT** | **PASS** | PR #106 vers `main` + tag `transform-phase-3-done` après fusion. |

## 4. Critères d'acceptation Given/When/Then — résultat (§15 NS-2, §35.2)
- *Given* un utilisateur avec 6 révisions dues, *when* il ouvre `Aujourd'hui`, *then* la carte Séance affiche `"6 rappels"` dans la composition et le bouton principal démarre la séance en 1 tap (`PASS`).
- *Given* une séance interrompue depuis moins de 24 h (ou 7 jours en Plongée), *when* `Aujourd'hui` ou la tab bar s'affiche, *then* l'accessoire `"Séance en cours"` est actif et le bouton principal propose `"Reprendre la séance"` (`PASS`).
- *Given* un plein écran de séance, *when* l'utilisateur le ferme sans saisie en cours, *then* il sauvegarde et ferme immédiatement sans dialogue de confirmation ; *and when* une réponse est en cours de saisie, *then* une confirmation est demandée (`PASS`).
- *Given* les liens profonds `certigo://auth` et `certigo://widget/learn`, *when* `Router.handleDeepLink` les reçoit, *then* le callback d'authentification MSAL/CIAM et l'ouverture de séance depuis le widget sont préservés (`PASS`).
- *Given* tout produit ou route de certification affiché dans `TodayRootScreen` ou `CatalogExplorerScreen`, *when* l'écran est rendu, *then* il utilise `BrandLabel` (icône officielle en `.learningContent` ou `BrandFallbackMark` + code d'examen en `.catalog`) (`PASS`).

## 5. Écarts vs spécification (et justification) / dettes créées
- Aucun écart ni dette ajoutée (`LegacyExceptions.json` inchangé ; l'ancienne navigation reste accessible lorsque `nav.v2` / `today.v2` sont `OFF` conformément au §34.1 et au §36).

## 6. Decision Requests ouvertes / tranchées
- `DR-001` à `DR-010` : toutes **`APPROVED`**. Aucune nouvelle Decision Request ouverte en Phase 3.

## 7. Métriques vs baseline (lancement, hitches, mémoire, taille)
- Aucune dépendance externe ajoutée ; `TodayRootScreen` affiche immédiatement son état local ou `PrismSkeleton` sans bloquer le thread principal.

## 8. Risques pour la phase suivante
- **Phase 4 (`Learning experience`)** : implémenter le lecteur de séance plein écran (`S-20`) et les formats prioritaires P1 (`choice` + confiance, `situation`, `spotTheIssue`, `ordering`, `commandComposer`) avec persistance de reprise à chaque carte et extensions additives de `content/schema/lesson.schema.json`.

## 9. Procédure de retour arrière testée (oui/non + preuve)
- **Oui** : les flags `nav.v2` et `today.v2` sont `OFF` par défaut compilé et désactivables à distance via `applyRemoteJSON(Data(#"{"nav.v2": false, "today.v2": false}"#.utf8))`, conservant l'ancien chemin intact (§36).

## 10. Phrase de clôture : "PHASE 3 TERMINÉE — EN ATTENTE DE VALIDATION."
PHASE 3 TERMINÉE — EN ATTENTE DE VALIDATION.
