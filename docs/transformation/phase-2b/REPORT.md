# Étape 2B — Official brand assets — Rapport

## 1. Résumé (5 lignes max) et statut : COMPLETE / PARTIAL / BLOCKED
- **Statut : `COMPLETE`** (`DR-010 APPROVED` ; validation complète Swift 6.2.3 WSL + Python 100 % verte).
- Création du référentiel [`content/brands/registry.yaml`](../../../content/brands/registry.yaml) (`132` produits et certifications issus de `brand_references.csv`) et du manifeste [`brand-manifest.json`](../../../apps/apple/CertigoKit/Sources/BrandAssets/Resources/brand-manifest.json).
- Acquisition et import sans aucune modification (`SHA-256` vérifié octet par octet, `template-rendering-intent: original`) des **80 icônes vectorielles officielles de Niveau 1** (`213,6 Ko` au total `<= 2 Mo` §22A.9) + archivage daté des conditions dans [`docs/legal/brand-terms/`](../../legal/brand-terms/), [`BRAND_ASSETS_CHANGELOG.md`](../../legal/BRAND_ASSETS_CHANGELOG.md) et [`THIRD_PARTY_NOTICES.md`](../../../THIRD_PARTY_NOTICES.md).
- Implémentation du module SPM `BrandAssets` (`BrandRegistry`) et des composants `Prism/Brand` (`BrandIcon`, `BrandLabel`, `BrandFallbackMark`, `BrandNoticesView`) avec interrupteurs par éditeur (`brand.icons.<vendor>`) et global (`brand.icons.v1`).
- Extension additive des schémas `content/schema/lesson.schema.json` et `track.schema.json` (`products`) + `tools/validate_content.mjs` + garde-fous automatisés `BrandAssetsTests.swift` et `test_brand_assets.py`.

## 2. Livré (liens vers fichiers, captures)
- [`content/brands/registry.yaml`](../../../content/brands/registry.yaml) — 8 groupes d'éditeurs, 132 produits/certifications (`80` Niveau 1 `approved`, `28` Niveau 2 `pending-permission`, `24` Niveau 3 / repli documenté).
- [`apps/apple/CertigoKit/Sources/BrandAssets/BrandRegistry.swift`](../../../apps/apple/CertigoKit/Sources/BrandAssets/BrandRegistry.swift), [`brand-manifest.json`](../../../apps/apple/CertigoKit/Sources/BrandAssets/Resources/brand-manifest.json) et [`BrandAssets.xcassets`](../../../apps/apple/CertigoKit/Sources/BrandAssets/Resources/BrandAssets.xcassets) (`80` `.imageset` SVG vectoriels d'origine, `213,6 Ko`).
- [`apps/apple/CertigoKit/Sources/Prism/Brand/BrandIcon.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Brand/BrandIcon.swift), [`BrandLabel.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Brand/BrandLabel.swift), [`BrandFallbackMark.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Brand/BrandFallbackMark.swift), [`BrandNoticesView.swift`](../../../apps/apple/CertigoKit/Sources/Prism/Brand/BrandNoticesView.swift).
- [`docs/legal/brand-terms/`](../../legal/brand-terms/), [`docs/legal/BRAND_ASSETS_CHANGELOG.md`](../../legal/BRAND_ASSETS_CHANGELOG.md), [`THIRD_PARTY_NOTICES.md`](../../../THIRD_PARTY_NOTICES.md).
- [`content/schema/lesson.schema.json`](../../../content/schema/lesson.schema.json), [`content/schema/track.schema.json`](../../../content/schema/track.schema.json), [`tools/validate_content.mjs`](../../../tools/validate_content.mjs).
- [`apps/apple/CertigoKit/Tests/CertigoKitTests/BrandAssetsTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/BrandAssetsTests.swift) & [`tools/tests/test_brand_assets.py`](../../../tools/tests/test_brand_assets.py).

## 3. Portes : BUILD | TEST | VISUAL | A11Y | PERF | REPORT | CHECKPOINT (preuves)
| Porte | Statut | Preuve |
|---|---|---|
| **1. BUILD** | **PASS (WSL Swift 6.2.3 `-warnings-as-errors`)** | Compilation Debug & tests de `BrandAssets`, `Prism`, `CertigoDomain`, `CertigoData`, `CertigoCortex` : **0 erreur, 0 warning**. |
| **2. TEST** | **PASS** | `swift test` : **187/187 XCTest** + **17/17 Swift Testing** (`BrandAssetsTests`, `PrismTests`, `PrismComponentsTests`, `FeatureFlagsTests`, `ArchitectureTests`) verts ; Python `unittest discover -s tools/tests` : **253 tests réussis, 0 échec**. |
| **3. VISUAL** | **PASS** | `BrandAssetsTests` et `test_brand_assets.py` vérifient `template-rendering-intent == "original"`, `preserves-vector-representation == true`, et le rapport de couverture (`132` produits : `80` icônes officielles Niveau 1, `52` en repli documenté). |
| **4. A11Y** | **PASS** | `BrandLabel` combine l'icône (`accessibilityHidden(true)`) et le nom officiel en **un seul** élément VoiceOver (`accessibilitySpokenLabel`), bascule en vertical aux tailles AX via `PrismAdaptiveStack`, et `BrandIcon` applique `accessibilityIgnoresInvertColors(true)` + plaque à bordure renforcée en Increase Contrast (§22A.8). |
| **5. PERF** | **PASS** | Taille totale de `BrandAssets.xcassets` = **213,6 Ko** (`218 699` octets), soit **10,4 %** du budget maximal de `2 Mo` (§22A.9). |
| **6. REPORT** | **PASS** | Ce fichier `docs/transformation/phase-2b/REPORT.md`. |
| **7. CHECKPOINT** | **PASS** | PR #105 vers `main` + tag `transform-phase-2b-done` après fusion. |

## 4. Critères d'acceptation Given/When/Then — résultat (§22A.13)
- *Given* le registre et le contenu, *when* le validateur et `BrandAssetsTests` s'exécutent, *then* 100 % des 132 produits cités ont une icône `approved` (80) ou un repli documenté (52), et le rapport de couverture est vérifié (`PASS`).
- *Given* une icône quelconque de `BrandAssets.xcassets`, *when* `BrandAssetsTests` et `test_brand_assets.py` s'exécutent, *then* son SHA-256 correspond exactement au fichier original du kit et son manifeste contient source, version, date, conditions archivées, niveau et contextes autorisés (`PASS`).
- *Given* une *Situation* dont le schéma contient Azure Virtual Machines, Azure Virtual Network et Azure Load Balancer, *when* il est résolu en `.diagram`, *then* chaque nœud résout vers son icône officielle Azure et son nom officiel (`PASS`).
- *Given* la route AZ-900 dans `.catalog` sans autorisation `.catalog`, *when* la carte est résolue, *then* elle retourne `BrandFallbackMark` (`AZ-900 · Microsoft Azure` en texte sans badge ni crête) ; *and when* `.catalog` est ajouté dans le manifeste, *then* l'icône officielle Azure apparaît sans changement de code (`PASS`).
- *Given* une leçon *Microsoft Office Specialist : Excel* sans licence de marque, *when* elle est résolue, *then* aucune icône Excel n'apparaît et le repli affiche `Microsoft Excel` en texte (`PASS`).
- *Given* l'interrupteur distant `brand.icons.microsoft` passé à `false`, *when* `BrandRegistry.resolve` est appelé, *then* toutes les icônes Microsoft basculent immédiatement en repli (`PASS`).
- *Given* `BrandNoticesView`, *when* son modèle est construit, *then* chaque éditeur présent dans le bundle y figure avec sa mention, son kit, sa version et le lien vers ses conditions (`PASS`).

## 5. Écarts vs spécification (et justification) / dettes créées
- Conformément à `test_native_extraction.py` (qui fige l'empreinte SHA-256 des fichiers extraits en Phase 1 jusqu'à la bascule des écrans en Phase 3), `BrandLabel` et `BrandNoticesView` sont exposés dans `Prism` et branchés dans `PrismDebugGalleryView` (`D-1`), prêts à être utilisés directement par les écrans `Aujourd'hui` / `Atlas` / `Profil` dès la Phase 3 (`nav.v2` / `today.v2`).

## 6. Decision Requests ouvertes / tranchées
- `DR-006` et `DR-010` : **`APPROVED`** et appliquées. Les 4 courriels de demande d'autorisation Niveau 2 (Microsoft, GitHub, AWS, CNCF) sont prêts dans `docs/transformation/phase-0/13_RISKS_AND_DECISIONS.md`.

## 7. Métriques vs baseline (lancement, hitches, mémoire, taille)
- **Taille de `BrandAssets.xcassets` :** `213,6 Ko` (`<= 2 048 Ko` budget §22A.9).
- **Impact lancement à froid :** `0 ms` (chargement paresseux de `BrandRegistry.shared` uniquement à la première résolution).

## 8. Risques pour la phase suivante
- **Phase 3 (`Home / Today`)** : veiller à ce que tout nouvel écran qui nomme un produit réel en Phase 3 utilise exclusivement `BrandLabel` / `BrandIcon` (§34.1 ligne 814) et que la nouvelle `TabView` (`Aujourd'hui · Atlas · Ensemble · Profil`) soit pilotée par un unique fichier de routes (`AppRoute` + `Router` §13) derrière les flags `nav.v2` et `today.v2`.

## 9. Procédure de retour arrière testée (oui/non + preuve)
- **Oui** : l'interrupteur distant `{"brand.icons.v1": false}` ou `{"brand.icons.<vendor>": false}` bascule instantanément tout ou partie des éditeurs sur `BrandFallbackMark` (testé unitairement dans `BrandAssetsTests`).

## 10. Phrase de clôture : "PHASE 2B TERMINÉE — EN ATTENTE DE VALIDATION."
PHASE 2B TERMINÉE — EN ATTENTE DE VALIDATION.
