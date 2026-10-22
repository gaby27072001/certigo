# Phase 0 — Étape 1 : Carte du dépôt et vérification des hypothèses (H1–H11)

> **Branche d'audit :** `transform/phase-0-audit`  
> **Commit HEAD audité :** `778f9c247ceb9c0db29fb931a8573bd328b492ab` (*Merge pull request #101 — Add dynamic native app icons*, 22/10/2026)  
> **Mode :** Lecture seule stricte (aucun fichier existant modifié, aucun artefact laissé dans le worktree)  
> **Taxonomie épistémique :**
> - **VÉRIFIÉ** : observé directement dans le dépôt (`fichier:ligne`) ou par exécution de commande reproductible.
> - **INFÉRÉ** : déduit logiquement à partir des preuves observées, avec explicitation du raisonnement.
> - **NON VÉRIFIABLE** : requiert un environnement macOS / Xcode / iOS Simulator / appareil physique ou un secret externe non disponible depuis l'environnement Windows/WSL d'audit (commande exacte fournie).

---

## 1. Arborescence commentée du dépôt (niveau 3)

**Statut : VÉRIFIÉ** (inspection directe de l'arbre Git à `778f9c247ceb9c0db29fb931a8573bd328b492ab`).

```text
certigo/ (778f9c247ceb9c0db29fb931a8573bd328b492ab)
├── .agents/
│   └── skills/                         # Compétences d'animation et design Apple/Emil Kowalski
│       ├── animate/
│       ├── animation-vocabulary/
│       ├── apple-design/
│       ├── emil-design-eng/
│       ├── find-animation-opportunities/
│       ├── improve-animations/
│       ├── review-animations/
│       └── LICENSE.emilkowalski-skills
├── .github/
│   ├── ci/
│   │   └── impact-matrix.json          # Matrice de filtrage des chemins CI
│   ├── codeql/
│   │   └── codeql-config.yml           # Configuration CodeQL
│   ├── sast/                           # Règles Semgrep SAST Dart et baseline
│   │   ├── rules/
│   │   ├── tests/
│   │   ├── baseline.json
│   │   ├── scope.json
│   │   ├── semgrep-requirements.in
│   │   └── semgrep-requirements.lock
│   ├── scripts/                        # Garde-fous CI Node.js (.mjs) + 34 fichiers *.test.mjs + Checkov
│   │   ├── dart-sast-workflow-forms/
│   │   ├── fixtures/
│   │   ├── native-apple-workflow-policy.mjs
│   │   ├── public-domain-contract.mjs
│   │   └── ... (64 scripts et tests de politique CI/CD)
│   ├── workflows/                      # 31 workflows GitHub Actions actifs (voir §4.1)
│   │   ├── cd-backend.yml
│   │   ├── ci-backend.yml
│   │   ├── ci-content-drift.yml
│   │   ├── ci-content.yml
│   │   ├── ci-cortex-parity.yml
│   │   ├── ci-infra.yml
│   │   ├── ci-migration-registry.yml
│   │   ├── ci-mobile.yml
│   │   ├── ci-preflight.yml
│   │   ├── ci-project-state.yml
│   │   ├── ciam-posture-monitor.yml
│   │   ├── codeql.yml
│   │   ├── content-infra-apply.yml
│   │   ├── content-infra-what-if.yml
│   │   ├── dependency-vuln-scan.yml
│   │   ├── deploy-privacy-policy.yml
│   │   ├── fork-pr-policy.yml
│   │   ├── governance-bootstrap-phase-a-what-if.yml
│   │   ├── governance-bootstrap-phase-b-what-if.yml
│   │   ├── lint-workflows.yml
│   │   ├── post-merge-cosmos-account-deletion.yml
│   │   ├── pr-head-freshness.yml
│   │   ├── promote-backend-staging-prod.yml
│   │   ├── publish-verified-public-pages.yml
│   │   ├── release-android.yml
│   │   ├── release-ios.yml
│   │   ├── runner-health.yml
│   │   ├── runner-resilience-drill.yml
│   │   ├── security-gate.yml
│   │   ├── security-scan.yml
│   │   └── sync-ios-certs.yml
│   ├── workflows-disabled/             # 2 workflows désactivés / archivés
│   │   ├── runner-image-attest.yml
│   │   └── test-account-deletion-cosmos.yml
│   ├── actionlint.yaml
│   ├── branch-protection-main.json
│   ├── CODEOWNERS
│   ├── dependabot.yml
│   └── osv-scanner.toml
├── .impeccable/
│   └── hook.cache.json
├── .vscode/
│   ├── extensions.json
│   └── settings.json
├── apps/
│   ├── apple/                          # CLIENT NATIF APPLE (cible de la transformation)
│   │   ├── .impeccable/
│   │   ├── CertigoKit/                 # Package SPM partagé (Domain, Data, Cortex, AppleFileIO, Tests)
│   │   ├── CertigoNative/              # App iOS SwiftUI + WidgetExtension + DemoTests + ModelTests
│   │   ├── CertigoProtectionDeviceTests/ # Hôte et tests XCTest de protection fichier sur iPhone physique
│   │   ├── CertigoProtectionTests/     # Tests XCTest de protection fichier sur simulateur iOS
│   │   ├── CIAM_LOCAL_DEVELOPMENT.md
│   │   ├── DESIGN.md
│   │   ├── NATIVE_UI_BRIEF.md
│   │   └── PRIVACY_MANIFEST.md
│   └── mobile/                         # CLIENT FLUTTER HÉRITAGE (référence fonctionnelle)
│       ├── android/
│       ├── assets/                     # Contient notamment assets/mascots/README.md
│       ├── distribution/
│       ├── integration_test/           # 2 fichiers de tests d'intégration Flutter
│       ├── ios/                        # Projet Xcode Runner Flutter utilisé par codemagic.yaml
│       ├── lib/
│       ├── test/                       # 105 fichiers de tests unitaires/widgets/structurels Flutter
│       ├── web/
│       ├── analysis_options.yaml
│       ├── pubspec.lock
│       ├── pubspec.yaml
│       └── README.md
├── backend/                            # BACKEND .NET 8 (Azure Functions isolées, autoritatif)
│   ├── BuildTasks/
│   │   └── CertigoBuildIdentityTask.cs
│   ├── src/
│   │   ├── Certigo.Api/                # Endpoints HTTP Azure Functions, Auth/JWT, Middleware
│   │   ├── Certigo.Application/        # Services applicatifs (Quiz, Exam, Shop, Streak, Tutor, etc.)
│   │   ├── Certigo.Domain/             # Modèles métier, notation, Cortex, ligues, readiness
│   │   └── Certigo.Infrastructure/     # Cosmos DB, Blob Storage, Entra/CIAM, OpenAI, App Insights
│   ├── tests/
│   │   ├── Certigo.Api.Tests/          # 53 fichiers C# (271 tests xUnit)
│   │   ├── Certigo.Application.Tests/  # 39 fichiers C# (417 tests xUnit)
│   │   ├── Certigo.Domain.Tests/       # 26 fichiers C# (340 tests xUnit)
│   │   └── Certigo.Infrastructure.Tests/ # 23 fichiers C# (115 tests xUnit dont 20 Skippable Cosmos)
│   ├── Certigo.sln
│   ├── run-account-deletion-cosmos-emulator.sh
│   ├── run-cosmos-gate.ps1
│   └── run-tutor-llm-live-gate.ps1
├── content/                            # CORPUS HISTORIQUE LOCAL (91 pistes, 147 leçons + schémas JSON)
│   ├── schema/
│   │   ├── lesson.schema.json          # Schéma JSON des leçons (8 types d'items canoniques)
│   │   └── track.schema.json           # Schéma JSON des pistes/certifications
│   ├── ai-900/, az-104/, az-900/, dp-900/, github-actions/, github-copilot/, ms-900/, pl-900/, sc-900/...
│   └── ... (91 dossiers de pistes contenant chacun track.yaml et lessons/*.lesson.yaml)
├── contracts/                          # Contrats JSON partagés multi-stacks
│   ├── content-package-v2.json
│   └── cosmos-containers.json
├── docs/                               # Documentation d'architecture, contrats, gouvernance et audit
│   ├── adr/                            # 14 ADR (ADR-013 à ADR-023 + ADR-O-01)
│   ├── archive/                        # Audits historiques archivés
│   ├── contracts/                      # Spécifications de contrats (native-client, learner-auth, etc.)
│   ├── evidence/                       # Captures PNG historiques
│   ├── legal/                          # Politiques de confidentialité et suppression de compte
│   ├── migration/                      # Registre et état des lots de migration
│   ├── plans/
│   ├── runbooks/                       # 26 runbooks opérationnels Azure / CI / CIAM / Cosmos
│   ├── transformation/
│   │   └── phase-0/                    # Livrables du présent audit Phase 0
│   ├── active-content-reference.json
│   ├── APPLE_DELIVERY_PLAN.md
│   ├── APPLE_NATIVE.md
│   ├── APPLE_NATIVE_UX_AUDIT.md
│   ├── ARCHITECTURE.md
│   ├── ETAT_DU_PROJET.md
│   └── project-state-reference.json
├── infra/                              # Infrastructure-as-Code Azure (Bicep + gouvernance + runners CI)
│   ├── ci-runner/
│   ├── content/
│   ├── finops/
│   ├── governance/
│   ├── modules/
│   ├── params/
│   ├── queries/
│   ├── tests/                          # 17 fichiers *.test.mjs de validation Bicep/ARM
│   ├── check-alert-receivers.mjs
│   ├── main.bicep
│   └── validate.sh
├── packages/                           # Packages Dart/Flutter héritage (workspace Melos)
│   ├── core/                           # Types et utilitaires partagés Dart (1 fichier test)
│   ├── cortex/                         # Algorithme de répétition espacée Dart + golden vectors (2 fichiers test)
│   ├── data/                           # Client API, cache hors ligne et sync Dart (27 fichiers test)
│   └── prism_ui/                       # Design system Flutter Prism (tokens, composants, vendor_brand, mascottes ; 43 fichiers test)
├── tools/                              # Outillage Python, Node.js et Bash de validation/publication
│   ├── checkov/                        # Patchs et adaptateurs Checkov Bicep + 8 fichiers test_*.py
│   ├── promotion/                      # Outillage de promotion de release backend
│   ├── secrets/
│   ├── tests/                          # 19 fichiers test_*.py + 6 fichiers *.test.mjs
│   ├── build_public_pages.mjs
│   ├── generated_contracts.py
│   ├── native_ciam_scheme.py
│   ├── project_state.py
│   ├── seed_content.py
│   ├── test_apple_model.sh
│   ├── validate_apple_mac_one_shot.sh
│   ├── validate_content.mjs
│   └── validate_native_distribution.sh
├── AGENTS.md
├── CLAUDE.md
├── codemagic.yaml                      # Pipeline Codemagic iOS (actuellement branché sur apps/mobile Flutter)
├── DESIGN.md
├── melos.yaml
├── package.json
├── package-lock.json
├── README.md
└── SECURITY.md
```

---

## 2. Projets Xcode, Targets, Schemes, Configurations et Réglages (`apps/apple/`)

### 2.1 Projet principal : [`apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj`](../../../apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj)

**Statut : VÉRIFIÉ** (`apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:1-581`).

| Élément | Valeur observée | Preuve (`fichier:ligne`) |
|---|---|---|
| `objectVersion` / `compatibilityVersion` | `60` / `"Xcode 14.0"` (`LastUpgradeCheck = 2600`) | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:6`, `:181-184` |
| `developmentRegion` / `knownRegions` | `fr` / `(fr, en, Base)` | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:185-191` |
| **Target 1 : `CertigoNative`** | `com.apple.product-type.application` (`CertigoNative.app`) | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:116-140` |
| Phases de build de `CertigoNative` | 1. `Validate distribution version` (script `tools/validate_native_distribution.sh` si `CONFIGURATION = Distribution`)<br>2. `Sources` (7 fichiers Swift)<br>3. `Frameworks` (`CertigoDomain`, `CertigoData`, `MSAL`)<br>4. `Resources` (`Certigo.icon`, `PrivacyInfo.xcprivacy`, `CertigoAssets.xcassets`)<br>5. `Embed App Extensions` (`CertigoWidgetExtension.appex`) | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:119-125`, `:208-264` |
| **Target 2 : `CertigoWidgetExtension`** | `com.apple.product-type.app-extension` (`CertigoWidgetExtension.appex`) | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:141-161` |
| Phases de build de `CertigoWidgetExtension` | 1. `Sources` (`CertigoWidgetPresentation.swift`, `CertigoWidgetExtension.swift`)<br>2. `Frameworks` (`CertigoData`, `CertigoDomain`)<br>3. `Resources` (vide) | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:144-148`, `:265-289` |
| Dépendance entre targets | `CertigoNative` dépend de `CertigoWidgetExtension` (`PBXTargetDependency`) | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:128-130`, `:162-173` |

#### Configurations de build (`Debug`, `Release`, `Distribution`)

**Statut : VÉRIFIÉ** (`apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:293-532`).

| Réglage | `Debug` (Dev) | `Release` (Dev) | `Distribution` (App Store / TestFlight) | Preuve (`project.pbxproj`) |
|---|---|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `17.0` | `17.0` | `17.0` | `:297`, `:340`, `:353`, `:431`, `:456`, `:480` |
| `SWIFT_VERSION` | `6.0` | `6.0` | `6.0` | `:301`, `:345`, `:357`, `:444`, `:468`, `:494` |
| `SWIFT_STRICT_CONCURRENCY` | `complete` | `complete` | `complete` | `:299`, `:343`, `:355`, `:442`, `:466`, `:492` |
| `SWIFT_TREAT_WARNINGS_AS_ERRORS` | `YES` | `YES` | `YES` | `:300`, `:344`, `:356`, `:443`, `:467`, `:493` |
| `ONLY_ACTIVE_ARCH` (projet) | `YES` | *(non défini)* | *(non défini)* | `:341` |
| `SWIFT_OPTIMIZATION_LEVEL` | `"-Onone"` | `"-O"` | `"-O"` | `:331`, `:388`, `:419`, `:491` |
| `SWIFT_ACTIVE_COMPILATION_CONDITIONS` | `DEBUG` | *(non défini)* | `CERTIGO_PRODUCTION_DISTRIBUTION` | `:330`, `:387`, `:441`, `:490` |
| `INFOPLIST_FILE` (`CertigoNative`) | `DevelopmentInfo.plist` | `DevelopmentInfo.plist` | `DistributionInfo.plist` | `:317`, `:374`, `:406` |
| `INFOPLIST_KEY_CFBundleDisplayName` | `"Certigo Dev"` | `"Certigo Dev"` | `Certigo` | `:318`, `:375`, `:407` |
| `PRODUCT_BUNDLE_IDENTIFIER` (`CertigoNative`) | `com.certigo.native.dev` | `com.certigo.native.dev` | `com.certigo.mobileapp` | `:327`, `:384`, `:416` |
| `PRODUCT_BUNDLE_IDENTIFIER` (`CertigoWidgetExtension`) | `com.certigo.native.dev.widget` | `com.certigo.native.dev.widget` | `com.certigo.mobileapp.widget` | `:437`, `:462`, `:486` |
| `CODE_SIGN_ENTITLEMENTS` (`CertigoNative`) | `CertigoNative.entitlements` (`aps-environment = development`) | `CertigoNative.entitlements` | *(omis — géré par le profil de distribution)* | `:371`, `:403` ; `apps/apple/CertigoNative/CertigoNative.entitlements:1-8` |
| `CODE_SIGNING_ALLOWED` | `NO` | `NO` | `NO` | `:314`, `:370`, `:402`, `:428`, `:453`, `:477` |
| `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` | `0.1.0` / `1` | `0.1.0` / `1` | `$(CERTIGO_DISTRIBUTION_VERSION)` / `$(CERTIGO_DISTRIBUTION_BUILD)` | `:315`, `:326`, `:372`, `:383`, `:404`, `:415` |
| `ASSETCATALOG_COMPILER_APPICON_NAME` | `Certigo` | `Certigo` | `Certigo` | `:313`, `:369`, `:401` |
| `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` | `CertigoIconStreakFire`, `CertigoIconStreakAtRisk`, `CertigoIconMasteryGold` | `CertigoIconStreakFire`, `CertigoIconStreakAtRisk`, `CertigoIconMasteryGold` | `CertigoIconStreakFire`, `CertigoIconStreakAtRisk`, `CertigoIconMasteryGold` | `:308-312`, `:364-368`, `:396-400` |
| `TARGETED_DEVICE_FAMILY` | `"1,2"` (iPhone + iPad) | `"1,2"` | `"1,2"` | `:332`, `:389`, `:420`, `:445`, `:469`, `:495` |

#### Schemes Xcode partagés (`xcshareddata/xcschemes/`)

**Statut : VÉRIFIÉ** (`apps/apple/CertigoNative/CertigoNative.xcodeproj/xcshareddata/xcschemes/`).

1. **`CertigoNative.xcscheme`** ([`apps/apple/CertigoNative/CertigoNative.xcodeproj/xcshareddata/xcschemes/CertigoNative.xcscheme:1-78`](../../../apps/apple/CertigoNative/CertigoNative.xcodeproj/xcshareddata/xcschemes/CertigoNative.xcscheme)) :
   - `BuildAction` : construit `CertigoNative.app` (`buildForTesting = YES`, `buildForRunning = YES`, `buildForProfiling = YES`, `buildForArchiving = YES`, `buildForAnalyzing = YES`).
   - `TestAction` (`Debug`) : `<Testables>` est **vide** (`:29-30`) — aucun target de test unitaire ou XCUITest n'est rattaché au scheme principal de l'application.
   - `LaunchAction` (`Debug`), `ProfileAction` (`Release`), `AnalyzeAction` (`Debug`), `ArchiveAction` (`Release`).
2. **`CertigoNative Distribution.xcscheme`** ([`apps/apple/CertigoNative/CertigoNative.xcodeproj/xcshareddata/xcschemes/CertigoNative Distribution.xcscheme:1-24`](../../../apps/apple/CertigoNative/CertigoNative.xcodeproj/xcshareddata/xcschemes/CertigoNative%20Distribution.xcscheme)) :
   - Dédié à l'archivage (`buildForArchiving = YES`, `buildForAnalyzing = YES`, autres actions `NO`) en configuration `Distribution`.
   - Exécute un `PreAction` shell `tools/validate_native_distribution.sh` avant l'archive (`:12-21`).
3. **Scheme local ignoré par Git (généré à la demande)** : `CertigoNative Local CIAM.xcscheme` (créé dans `xcuserdata/<user>.xcuserdatad/xcschemes/` par [`tools/native_ciam_scheme.py:1-210`](../../../tools/native_ciam_scheme.py) pour injecter les variables d'environnement CIAM de développement sans polluer l'arbre Git).

### 2.2 Projets Xcode auxiliaires de tests de protection de fichiers

**Statut : VÉRIFIÉ** :
- [`apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj/project.pbxproj`](../../../apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj/project.pbxproj) (`scheme` `CertigoProtectionTests`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`) : bundle `com.apple.product-type.bundle.unit-test` exécutant les 3 tests iOS de `RuntimeDiskProtectionTests` sur simulateur iOS.
- [`apps/apple/CertigoProtectionDeviceTests/CertigoProtectionDeviceTests.xcodeproj/project.pbxproj`](../../../apps/apple/CertigoProtectionDeviceTests/CertigoProtectionDeviceTests.xcodeproj/project.pbxproj) (`scheme` `CertigoProtectionDeviceTests`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`) : application hôte `CertigoProtectionTestHost.app` + bundle `CertigoProtectionDeviceTests.xctest` exécutant ces 3 mêmes tests sur iPhone physique.
---

## 3. Package SPM `CertigoKit`, Dépendances Résolues et Inventaire des Sources Swift

### 3.1 Manifeste [`apps/apple/CertigoKit/Package.swift`](../../../apps/apple/CertigoKit/Package.swift)

**Statut : VÉRIFIÉ** (`apps/apple/CertigoKit/Package.swift:1-35`).

- **Outils Swift :** `// swift-tools-version: 6.2` (`Package.swift:1`).
- **Plateformes déclarées :** `[.iOS(.v17), .macOS(.v14)]` (`Package.swift:7`).
- **Produits (`.library`) :**
  1. `CertigoCortex` (`Package.swift:9`)
  2. `CertigoDomain` (`Package.swift:10`)
  3. `CertigoData` (`Package.swift:11`)
- **Targets :**
  1. `CertigoCortex` (`Sources/CertigoCortex/Cortex.swift`, 252 lignes) — algorithme de répétition espacée et calcul de maîtrise/readiness local.
  2. `CertigoDomain` (`Sources/CertigoDomain/*.swift`, 8 fichiers, 3 959 lignes) — contrats domaine, langue d'interface (`AppLanguage`), icônes d'app, snapshots WidgetKit, plan d'étude, `SmartReviewAdvisor`.
  3. `CertigoAppleFileIO` (`Sources/CertigoAppleFileIO/CertigoAppleFileIO.c` + `include/CertigoAppleFileIO.h`) — wrappers C autour de `fcntl(F_GETPATH / F_GETPROTECTIONCLASS / F_SETPROTECTIONCLASS)` compilés sous `#if defined(__APPLE__)`.
  4. `CertigoData` (`Sources/CertigoData/*.swift`, 18 fichiers, 3 415 lignes) — transport HTTP borné (`BoundedHTTPTransport`), client API (`CertigoAPI`), synchronisation et cache runtime (`RuntimeContentStore`, `RuntimeDisk`, `PublicReleaseAPI`, `PublicResourceReader`), file de soumission hors ligne (`SubmissionStore`), configuration CIAM, stockage WidgetKit (`CertigoWidgetStore`), préférences d'icônes (`CertigoAppIconPreferenceStore`). Dépend de `CertigoDomain`, de `CertigoAppleFileIO` (condition `.when(platforms: [.iOS])`) et de `Crypto` de `swift-crypto` (condition `.when(platforms: [.linux])`).
  5. `CertigoKitTests` (`Tests/CertigoKitTests/*.swift`, 25 fichiers Swift, 5 613 lignes + dossier `Fixtures/`) — tests unitaires `XCTest`.

### 3.2 Dépendances résolues (`Package.resolved`)

**Statut : VÉRIFIÉ** :

| Package / Identité | Version exacte | Révision Git épinglée | Fichiers `Package.resolved` |
|---|---|---|---|
| `microsoft-authentication-library-for-objc` (produit `MSAL`) | **`2.16.0`** (`exactVersion`) | `8dfe5bf41fe10e6d2afed62a72c4232adbef20f4` | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:3-12` et `project.pbxproj:542-549` |
| `swift-crypto` (produit `Crypto`) | **`5.0.1`** (`exact`) | `1c80d3aff53fedc445b60692980cb4f19a618657` | `apps/apple/CertigoKit/Package.resolved:14-22`, `CertigoNative/.../Package.resolved:22-30` |
| `swift-asn1` (transitif de `swift-crypto`) | **`1.7.3`** | `3b6410f7dee09eb33cdd26260c5fd47fda19b0e2` | `apps/apple/CertigoKit/Package.resolved:5-13`, `CertigoNative/.../Package.resolved:13-21` |

### 3.3 Volumétrie exacte (`wc -l`) des fichiers de `apps/apple/CertigoNative`

**Statut : VÉRIFIÉ** :

| Fichier | Lignes (`wc -l`) | Target / Usage |
|---|---:|---|
| [`apps/apple/CertigoNative/Sources/CertigoNativeApp.swift`](../../../apps/apple/CertigoNative/Sources/CertigoNativeApp.swift) | **8 565** | Target `CertigoNative` (monolithe principal UI + modèles de présentation + mode Démo) |
| [`apps/apple/CertigoNative/Sources/NativeModel.swift`](../../../apps/apple/CertigoNative/Sources/NativeModel.swift) | **2 412** | Target `CertigoNative` (`@MainActor final class NativeModel: ObservableObject`) |
| [`apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift`](../../../apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift) | **604** | Target `CertigoNative` (galerie de widgets + sélecteur d'icônes dynamiques) |
| [`apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift`](../../../apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift) | **375** | Target `CertigoNative` (vue pilote éditorial *Responsible AI Assistants*) |
| [`apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift`](../../../apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift) | **284** | Partagé entre `CertigoNative` et `CertigoWidgetExtension` |
| [`apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift`](../../../apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift) | **243** | Target `CertigoNative` (intégration MSAL / Microsoft Entra External ID CIAM) |
| [`apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift`](../../../apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift) | **75** | Target `CertigoWidgetExtension` (`@main struct CertigoDailyWidget: Widget`) |
| [`apps/apple/CertigoNative/Sources/CredentialVault.swift`](../../../apps/apple/CertigoNative/Sources/CredentialVault.swift) | **48** | Target `CertigoNative` (stockage Keychain `SecItemAdd`/`SecItemCopyMatching`) |
| [`apps/apple/CertigoNative/ModelTests/NativeModelTests.swift`](../../../apps/apple/CertigoNative/ModelTests/NativeModelTests.swift) | **2 798** | Harnais de test Linux (`tools/test_apple_model.sh`) |
| [`apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift`](../../../apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift) | **892** | Harnais de test Foundation des modèles de présentation et du mode Démo |

---

## 4. CI/CD, Codemagic et Commandes de Build et Test Fonctionnelles

### 4.1 Workflows GitHub Actions actifs (`.github/workflows/*.yml`)

**Statut : VÉRIFIÉ** (`31` fichiers dans `.github/workflows/` vérifiés par `docs/ETAT_DU_PROJET.md:48` et `python -B tools/project_state.py --check`, plus `2` fichiers désactivés dans `.github/workflows-disabled/`).

| Catégorie | Workflows (`.github/workflows/`) | Rôle vérifié |
|---|---|---|
| **État du projet, contrats et gouvernance** | `ci-project-state.yml`, `ci-migration-registry.yml`, `lint-workflows.yml`, `ci-preflight.yml`, `fork-pr-policy.yml`, `pr-head-freshness.yml` | Exécutent notamment `python -P -m unittest discover -s tools/tests -p "test_*.py" -v` et `python -P tools/project_state.py --root "$PROJECT_WORKSPACE" --check` (`ci-project-state.yml:86-89`). |
| **Backend .NET et parité Cortex** | `ci-backend.yml`, `cd-backend.yml`, `ci-cortex-parity.yml`, `promote-backend-staging-prod.yml`, `post-merge-cosmos-account-deletion.yml` | Build et tests `.NET 8.0.x` (`Certigo.sln`), vérification de parité bit-à-bit des golden vectors Cortex entre Dart et .NET (`ci-cortex-parity.yml:136-142`), déploiement Azure Functions. |
| **Contenu pédagogique et pages publiques** | `ci-content.yml`, `ci-content-drift.yml`, `content-infra-what-if.yml`, `content-infra-apply.yml`, `deploy-privacy-policy.yml`, `publish-verified-public-pages.yml` | Validation du schéma de contenu (`node tools/validate_content.mjs`), détection de dérive du package de contenu actif, publication des pages légales et AASA. |
| **Mobile (Flutter héritage)** | `ci-mobile.yml`, `release-android.yml`, `release-ios.yml` (désactivé au profit de Codemagic), `sync-ios-certs.yml` | `ci-mobile.yml` exécute `dart analyze`, `dart test` (`core`, `cortex`, `data`), `flutter analyze`, `flutter test --coverage` (`apps/mobile`) et `flutter test` + golden tests (`packages/prism_ui`). **Aucun workflow GitHub Actions ne compile `apps/apple/CertigoNative` sur runner macOS** (interdit par `.github/scripts/native-apple-workflow-policy.mjs`). |
| **Infrastructure Azure, sécurité et runners** | `ci-infra.yml`, `codeql.yml`, `security-gate.yml`, `security-scan.yml`, `dependency-vuln-scan.yml`, `ciam-posture-monitor.yml`, `governance-bootstrap-phase-a-what-if.yml`, `governance-bootstrap-phase-b-what-if.yml`, `runner-health.yml`, `runner-resilience-drill.yml` | Validation Bicep/ARM, Checkov, OSV-Scanner, CodeQL, surveillance CIAM et gestion de la flotte de runners éphémères/auto-recovery. |

### 4.2 `codemagic.yaml`

**Statut : VÉRIFIÉ** ([`codemagic.yaml:1-510`](../../../codemagic.yaml)).
- `codemagic.yaml` existe à la racine du dépôt et définit 4 workflows sur instances `mac_mini_m2` (`xcode: "26.6"`, `flutter: 3.44.4`) :
  1. `ios-release` (`codemagic.yaml:247-338`) : déclenché sur tag `v*`, exécute `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build ipa --release` dans `apps/mobile` et soumet à TestFlight.
  2. `ios-release-dry` (`codemagic.yaml:343-417`) : déclenché sur push `main`, valide la signature et le build IPA Flutter sans upload.
  3. `ios-crash-smoke` (`codemagic.yaml:424-482`) : déclenchement manuel pour test de crash Sentry.
  4. `ios-refresh-signing` (`codemagic.yaml:488-510`) : rafraîchissement manuel des certificats/profils via App Store Connect API.
- **Constat clé :** `codemagic.yaml` cible encore `FLUTTER_APP_PATH: apps/mobile` (`codemagic.yaml:276`, `:359`). La validation et l'archivage de l'application native `apps/apple/CertigoNative` s'effectuent via le script macOS [`tools/validate_apple_mac_one_shot.sh`](../../../tools/validate_apple_mac_one_shot.sh).

### 4.3 Commandes de build et de test qui fonctionnent réellement

| Périmètre | Commande exacte | Environnement | Statut vérifié |
|---|---|---|---|
| **Tests unitaires SPM `CertigoKit`** | `swift test --package-path apps/apple/CertigoKit --scratch-path /tmp/certigo-phase0-swift -Xswiftc -warnings-as-errors` | WSL Ubuntu 24.04 aarch64 (Swift 6.2.3) ou macOS | **VÉRIFIÉ** — 187/187 tests XCTest réussis en 2,89 s, 0 warning. |
| **Build Release SPM `CertigoKit`** | `swift build --package-path apps/apple/CertigoKit --scratch-path /tmp/certigo-phase0-swift --force-resolved-versions -c release -Xswiftc -warnings-as-errors` | WSL Ubuntu 24.04 aarch64 (Swift 6.2.3) ou macOS | **VÉRIFIÉ** — compilation Release réussie en 65,95 s, 0 warning. |
| **Harnais de test `NativeModel`** | `bash tools/test_apple_model.sh /tmp/certigo-phase0-swift` | WSL Ubuntu 24.04 aarch64 (Swift 6.2.3) | **VÉRIFIÉ** — 254 assertions `expect()` réussies, 0 warning. |
| **Harnais de test `NativeDemoFlowTests`** | Compilation `swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete -warnings-as-errors` de `CertigoNativeApp.swift` + `NativeDemoFlowTests.swift` liés à `CertigoKit` | WSL Ubuntu 24.04 aarch64 (Swift 6.2.3) | **VÉRIFIÉ** — 3 304 vérifications Foundation réussies, 0 warning. |
| **Tests Python d'outillage & architecture** | `python -B -m unittest discover -s tools/tests -v` | Windows / Linux (Python 3.12) | **VÉRIFIÉ** — 240 tests découverts, 227 réussis, 13 ignorés (gardes POSIX sur Windows), 0 échec. |
| **Vérification de l'état généré du projet** | `python -B tools/project_state.py --check` | Windows / Linux (Python 3.12) | **VÉRIFIÉ** — `Project state is current.` |
| **Tests Backend .NET** | `dotnet test backend/Certigo.sln --nologo` | Windows / Linux (.NET 8 SDK) | **VÉRIFIÉ** — 1 143 tests au total : 1 122 réussis, 21 ignorés (Cosmos Emulator / LLM live), 0 échec. |
| **Validation du corpus de contenu** | `node tools/validate_content.mjs` | Node.js v24.19.0 (avec dépendances `ajv`, `ajv-formats`, `yaml`, `glob`) | **VÉRIFIÉ** — 91 pistes et 147 leçons valides (`✓ All content valid.`). |
| **Validation complète macOS / Xcode** | `CERTIGO_SIMULATOR_ID=<UDID> bash tools/validate_apple_mac_one_shot.sh [--prepare-archive]` | macOS + Xcode 26+ uniquement | **NON VÉRIFIABLE ICI** (environnement Windows/WSL) — script inspecté (`tools/validate_apple_mac_one_shot.sh:1-206`). |

---

## 5. Vérification des hypothèses de départ (H1 à H11)

### 5.1 Tableau récapitulatif H1–H11

| # | Énoncé de l'hypothèse (Master Prompt / Phase 0) | Statut sur `HEAD` (`778f9c24`) | Preuves exactes (`fichier:ligne`) |
|---|---|---|---|
| **H1** | Le client cible est l'app **SwiftUI native** `apps/apple/CertigoNative` + le package SPM `apps/apple/CertigoKit` (modules `CertigoDomain`, `CertigoData`, `CertigoAppleFileIO`, + `CertigoCortex`). | **VÉRIFIÉ** | `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:116-161`, `:193-204`, `:535-578` ; `apps/apple/CertigoKit/Package.swift:5-35` ; `docs/APPLE_NATIVE.md:6-17`. |
| **H2** | L'app Flutter `apps/mobile` (+ `packages/prism_ui`, `cortex`, `data`, `core`) est un **héritage** : référence fonctionnelle, plus le client cible de la refonte native. | **VÉRIFIÉ** | `apps/mobile/pubspec.yaml:1-35` ; `packages/prism_ui/pubspec.yaml:1-20` ; `docs/APPLE_NATIVE.md:578-580` ; historique Git récent (`PR #94` à `#101` exclusivement dédiés à `apps/apple/`). Note : `ci-mobile.yml:1-303` et `codemagic.yaml:247-417` restent actifs tant que la bascule de release iOS n'est pas effectuée. |
| **H3** | `CertigoNativeApp.swift` est un fichier monolithique contenant la majorité des vues. | **VÉRIFIÉ** | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift` compte **8 565 lignes** (> 8 400 lignes) et déclare **32 `struct ... : View`** (+ `CertigoNativeApp: App`, `NativeCrestOutline: Shape`, `NativeChoiceButtonStyle: ButtonStyle`, 2 `ViewModifier`). Voir détail complet des lignes et des vues en §5.2. |
| **H4** | Le build Debug du 22/10/2026 échouait sur `CertigoNativeApp.swift:3683` : `@Environment(\.accessibilityContrast)` (clé inexistante ; la clé SwiftUI est `\.colorSchemeContrast`). | **INFIRMÉ SUR HEAD ACTUEL (CORRIGÉ PAR PR #99 / `1a025a28`)** | Dans `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3683`, la propriété de `NativeCertificationCrest` est désormais `@Environment(\.colorSchemeContrast) private var contrast` (utilisée à la ligne `3699` : `contrast == .increased ? NativePrism.edge : NativePrism.accent(for: code)`), corrigée par le commit `f6dd2ea7` / merge `1a025a28` et protégée par `tools/tests/test_native_prism_presentation.py:130-137`. |
| **H5** | Cible de déploiement iOS **17.0**, Swift **6**, dépendance **MSAL**. | **VÉRIFIÉ** | `IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`, `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` (`project.pbxproj:297-301`, `:340-345`, `:353-357`, `:431-444`) ; `Package.swift:7` (`.iOS(.v17)`) ; `MSAL` **`2.16.0`** (`project.pbxproj:542-549`, `CertigoNative/.../Package.resolved:3-12`). |
| **H6** | 4 onglets (`Apprendre`, `Coach`, `Communauté`, `Profil`) ; un mode **Démo** (données fictives) et un **connecteur API de test** sont exposés dans l'UI. | **VÉRIFIÉ** | 4 onglets `learn`, `coach`, `social`, `profile` dans `NativeResumeState.Tab` (`NativeModel.swift:103`), `NativeDemoDestination` (`CertigoNativeApp.swift:5647-5649`), `NativeLessonSummaryAttempt.Tab` (`CertigoNativeApp.swift:8551`), `TabView` connectée (`CertigoNativeApp.swift:6041-6186`) et `TabView` Démo (`CertigoNativeApp.swift:4614-4696`), avec libellés localisés `.learn`, `.coach`, `.social` (« Communauté » / « Community »), `.profile` (`AppLanguage.swift:149`, `:237-240`). Mode Démo : `NativeDemoRoot` (`CertigoNativeApp.swift:4218`, `:4334`, `:4596-5338`). Connecteur développeur : `NativeDeveloperConnector` (`CertigoNativeApp.swift:4221`, `:4411-4594`, masqué uniquement sous `#if !CERTIGO_PRODUCTION_DISTRIBUTION` `:4145-4158`). |
| **H7** | 8 langues d'interface (`fr`, `en`, `hi`, `zh-Hans`, `ko`, `es`, `it`, `de`) via catalogue de chaînes ; le contenu pédagogique n'est pas traduit. | **VÉRIFIÉ** | `AppLanguage` (`apps/apple/CertigoKit/Sources/CertigoDomain/AppLanguage.swift:3-12`) définit `fr`, `en`, `hi`, `zh-Hans`, `ko`, `es`, `it`, `de` ; `AppInterfaceCopy` (`AppLanguage.swift:98-2147`) et ses extensions `NativeCopyKey` / `NativeFormatKey` / `NativeLabel` dans `CertigoNativeApp.swift:307-2745` fournissent les tables de traduction en Swift pur (aucun fichier `.xcstrings` ou `Localizable.strings` dans le dépôt). `NativeDeclaredContentLanguage` (`CertigoNativeApp.swift:203-214`) et `AppLanguageTests.swift` confirment que le contenu pédagogique reste dans sa langue déclarée sans traduction automatique. |
| **H8** | Notation, XP, streak, readiness, ligues et achats sont **autoritatifs côté serveur** (backend .NET `backend/`) ; la clé de correction n'est jamais envoyée au client. | **VÉRIFIÉ** | Côté client Swift : `CertigoAPI.swift:88-378` (endpoints `/me`, `/tracks`, `/tracks/{id}/path`, `/lessons/{id}`, `/quiz/submit`, `/exams/generate`, `/exams/submit`, `/tutor/explain`, `/recommendations/next-best`, `/gamification/*`, `/me/attempts`), `SubmissionStore.swift:31-186` (file hors ligne scellée par `ownerId`/`apiScope`, statut `.pending` jusqu'à correction serveur), `CanonicalQuestionReader.swift:1-217` (rejette toute charge utile contenant `correctOptionIds` / `answerKey`). Côté serveur : `backend/src/Certigo.Application/Services/QuizService.cs`, `ExamService.cs`, `GamificationServices.cs`, `LeaderboardService.cs`, `DurableEconomy.cs`, `backend/src/Certigo.Domain/Content/RuntimeContentProjector.cs` et `tools/tests/test_seed_content_anti_leak.py:1-127`. *(Note : les 8 `.csproj` de `backend/` ciblent actuellement `<TargetFramework>net8.0</TargetFramework>`, cf. `backend/src/Certigo.Api/Certigo.Api.csproj:4` et `docs/ETAT_DU_PROJET.md:43`).* |
| **H9** | Il n'existe **pas encore** de module design system natif séparé (`Prism` SPM), bien que des tokens internes aient été introduits dans le monolithe. | **VÉRIFIÉ (MODULE PRISM SPM ABSENT ; TOKENS INTERNES PRÉSENTS DANS LE MONOLITHE)** | `apps/apple/CertigoKit/Sources/Prism` n'existe pas (`Package.swift:16-33` ne déclare que `CertigoCortex`, `CertigoDomain`, `CertigoAppleFileIO`, `CertigoData`). Des tokens et composants internes (`enum NativePrism` à `CertigoNativeApp.swift:3164-3216`, `struct NativeTrackTheme` à `:3218-3266`, `NativeSymbolMedallion`, `NativeReadinessRing`, `NativeMetricTile`, `NativeGoalHero`) ont été ajoutés directement dans `CertigoNativeApp.swift` (PR #96 / #98). |
| **H10** | Aucune extension iOS (widgets, Live Activities, App Intents, notifications enrichies) n'est encore présente. | **PARTIELLEMENT INFIRMÉ SUR HEAD ACTUEL (WIDGETKIT PRÉSENT DEPUIS PR #100, AUTRES EXTENSIONS ABSENTES)** | **WidgetKit présent :** le target `CertigoWidgetExtension` (`project.pbxproj:141-161`) et `@main struct CertigoDailyWidget: Widget` (`apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift:54-75`) supportant `.systemSmall`, `.systemMedium`, `.accessoryCircular` et `.accessoryRectangular` ont été ajoutés par la PR #100 (`3b07d68d`), avec `CertigoWidgetPresentation.swift`, `NativeWidgetGalleryView.swift`, `CertigoWidgetSnapshot.swift` et `CertigoWidgetStore.swift`. **Autres extensions absentes :** 0 occurrence de `ActivityKit` / `ActivityAttributes` (Live Activities), `AppIntents` / `AppIntent`, `CoreSpotlight` / `CSSearchableItem`, ou `UNNotificationServiceExtension` / `UNNotificationContentExtension` dans `apps/apple/`. |
| **H11** | Le dépôt contient des visuels de marque tiers sans provenance ni conditions documentées (mascottes dérivées d'icônes Azure côté Flutter ; visuels de certification ad hoc tels que `NativeCertificationCrest` côté natif) et n'utilise **aucune** icône officielle d'éditeur de façon tracée. | **VÉRIFIÉ** | 1. **Mascottes Flutter dérivées d'icônes Azure :** `apps/mobile/assets/mascots/README.md:8-19` documente 7 mascottes (« *chacun = une icône Azure "cutifiée"* » : `nimbus`, `volt`, `cosmo`, `sentinel`, `bicky`, `pixel`, `pip`), câblées dans `packages/prism_ui/lib/src/components/aurora_mascot.dart`, `mascot_assets.dart:11-20` et `apps/mobile/lib/app/mascots.dart:16-26`.<br>2. **Logos éditeurs redessinés en code côté Flutter :** `packages/prism_ui/lib/src/components/vendor_brand.dart:65-75` (`VendorLogo` dessine en `CustomPaint` des approximations des logos Microsoft, GitHub, Google Cloud, AWS, OpenAI) et `packages/prism_ui/assets/fonts/FontAwesomeBrands-400.ttf`.<br>3. **Crêtes et emblèmes dessinés en code côté SwiftUI natif :** `NativeEcosystemArtwork` (`CertigoNativeApp.swift:3284-3393`), `NativeCrestOutline` (`:3395-3430`), `NativeMicrosoftVendorBadge` (`:3432-3447`, qui peint les 4 carrés Microsoft `#F25022`/`#7FBA00`/`#00A4EF`/`#FFB900`), `NativeEcosystemEmblem` (`:3449-3679`, qui dessine en `Canvas` le « A » Azure, l'Octocat GitHub, le sourire AWS, l'hexagone Google Cloud, etc.) et `NativeCertificationCrest` (`:3681-3729`).<br>4. **Absence de registre et de kits officiels :** `content/brands/registry.yaml` n'existe pas ; aucun SVG/PDF officiel non modifié n'est présent sous `apps/apple/`. |

---

### 5.2 Détail de H3 : Volumétrie des fichiers de `apps/apple/CertigoNative` et inventaire exhaustif des `struct ... : View`

**Statut : VÉRIFIÉ** (comptage exact sur `HEAD` `778f9c247ceb9c0db29fb931a8573bd328b492ab`).

#### Fichiers Swift de `apps/apple/CertigoNative` (hors `CertigoKit`)
- `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift` : **8 565 lignes**
- `apps/apple/CertigoNative/Sources/NativeModel.swift` : **2 412 lignes**
- `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift` : **604 lignes**
- `apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift` : **375 lignes**
- `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift` : **284 lignes**
- `apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift` : **243 lignes**
- `apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift` : **75 lignes**
- `apps/apple/CertigoNative/Sources/CredentialVault.swift` : **48 lignes**
- `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift` : **2 798 lignes**
- `apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift` : **892 lignes**

#### Liste complète des 38 `struct ... : View` (et types SwiftUI associés) dans `apps/apple/CertigoNative`

| # | Type SwiftUI | Conformité | Fichier : ligne | Rôle |
|---:|---|---|---|---|
| 1 | `NativeContentLanguageBadges` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:2756` | Badges de langue déclarée du contenu (`FR`, `EN`) |
| 2 | `NativeStudyPlanView` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:2774` | Feuille de configuration du plan d'étude (rythme, date d'examen) |
| 3 | `NativeMockExamView` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:2846` | Feuille d'examen blanc chronométré |
| 4 | `NativeNotificationPreferencesView` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:2993` | Feuille des préférences et aperçu du plan de notifications |
| — | `CertigoNativeApp` | `App` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3065` | Point d'entrée `@main` de l'application iOS |
| 5 | `NativeLanguageRoot` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3093` | Racine d'injection de la langue d'interface (`nativeInterfaceCopy`) |
| 6 | `NativeAppLanguagePicker` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3125` | Sélecteur des 8 langues d'interface + mode Système |
| 7 | `NativeSymbolMedallion` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3268` | Médaillon d'icône SF Symbol teinté par bande spectrale Prism |
| — | `NativeCrestOutline` | `Shape` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3395` | Forme géométrique (`pennant`, `hexagon`, `octagon`) des crêtes |
| 8 | `NativeMicrosoftVendorBadge` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3432` | Pastille 4 carrés Microsoft peinte en `Canvas` (à retirer en étape 2B / DR-006) |
| 9 | `NativeEcosystemEmblem` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3449` | Emblème vectoriel `Canvas` imitant les logos Azure, GitHub, AWS, GCP, Fabric, Security |
| 10 | `NativeCertificationCrest` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3681` | Crête de certification ad hoc combinant `NativeCrestOutline`, `NativeEcosystemEmblem` et `NativeMicrosoftVendorBadge` |
| 11 | `NativeShowcaseTile` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3731` | Tuile d'écosystème sur l'écran d'accueil / vitrine |
| — | `NativeDeveloperToolbar` | `ViewModifier` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3762` | Barre d'outils de session développeur |
| 12 | `NativeReadinessRing` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3784` | Anneau circulaire de score de préparation (readiness) |
| 13 | `NativeMetricTile` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3812` | Tuile de métrique compacte |
| 14 | `NativeMetricGrid<Content: View>` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3837` | Grille adaptative de métriques (1 colonne en taille d'accessibilité, 2 sinon) |
| 15 | `NativeGoalHero` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3851` | Carte héroïque de l'objectif actif avec dégradé et `NativeReadinessRing` |
| 16 | `NativeCertificationCard` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3898` | Carte de certification du catalogue avec `NativeCertificationCrest` |
| 17 | `NativeAnswerLabel` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3935` | Ligne d'option de réponse avec badge A/B/C/D et état sélectionné |
| 18 | `NativeQuestionProgress` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3966` | Barre de progression segmentée des étapes de leçon/exercice |
| 19 | `NativePracticeBadge` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3991` | Badge de statut d'étape dans le parcours |
| 20 | `NativeReadingPage<Content: View>` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4009` | Conteneur de page scrollable avec fond `NativePrism.canvas` |
| — | `NativeCatalogSearch` | `ViewModifier` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4023` | Modificateur `.searchable` conditionnel du catalogue |
| 21 | `NativeReadingSection<Content: View>` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4037` | Section titrée avec en-tête et sous-titre optionnel |
| 22 | `NativeReadingCard<Content: View>` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4050` | Carte de surface `NativePrism.surface` avec bordure `NativePrism.edge` |
| 23 | `NativePrimaryButton` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4067` | Bouton d'action primaire pleine largeur |
| — | `NativeChoiceButtonStyle` | `ButtonStyle` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4094` | Style de bouton de choix d'exercice |
| 24 | `NativeEntryHeading` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4120` | En-tête de marque avec médaillon et titre |
| 25 | `NativeEntry` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4142` | Routeur d'entrée principal (Production vs Démo vs Connecteur développeur + gestion URL `handleIncomingURL`) |
| 26 | `NativeProductionEntry` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4257` | Écran d'accueil de distribution production (`CERTIGO_PRODUCTION_DISTRIBUTION`) |
| 27 | `NativeDeveloperConnector` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4411` | Formulaire de connexion développeur (URL API, jeton Bearer, CIAM MSAL, pilote éditorial) |
| 28 | `NativeDemoRoot` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4596` | Racine complète du mode Démo hors ligne (4 onglets + parcours de démonstration) |
| 29 | `DemoReadingSection` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5340` | Section de lecture propre au mode Démo (doublon de `NativeReadingSection`) |
| 30 | `DemoPracticeTrail` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5353` | Chemin visuel des étapes du mode Démo |
| 31 | `DemoTakeaway` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5381` | Encadré « À retenir » du mode Démo |
| 32 | `DemoResponsibilities` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5399` | Tableau de partage des responsabilités cloud du mode Démo |
| 33 | `DemoPrimaryButton` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5460` | Bouton primaire du mode Démo (doublon de `NativePrimaryButton`) |
| 34 | `NativeAccountDeletionView` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5830` | Feuille de suppression de compte (saisie de `DELETE` + confirmation serveur) |
| 35 | `NativeRoot` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:5990` | Racine de l'application connectée (`TabView` 4 onglets `learn`, `coach`, `social`, `profile`, leçons, quiz, historique, feuilles) |
| 36 | `NativeLessonAudioControls` | `View` | `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:8244` | Contrôles de synthèse vocale (`AVSpeechSynthesizer`) dans la leçon |
| 37 | `CertigoWidgetCardView` | `View` | `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:21` | Carte principale des widgets iOS (`systemSmall`, `systemMedium`) et aperçu in-app |
| 38 | `CertigoWidgetRing` | `View` | `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:237` | Anneau de progression quotidien pour les widgets et l'écran verrouillé |
| 39 | `CertigoWidgetMark` | `View` | `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:263` | Marque/icône d'état du widget (flamme, bouclier, coche) |
| 40 | `NativeEditorialPilotView` | `View` | `apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift:5` | Vue du parcours pilote éditorial *Responsible AI Assistants* |
| 41 | `NativeEditorialPilotLessonView` | `View` | `apps/apple/CertigoNative/Sources/NativeEditorialPilotView.swift:189` | Vue de lecture d'une leçon du pilote éditorial |
| 42 | `NativeWidgetGalleryView` | `View` | `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:9` | Galerie in-app des widgets d'écran d'accueil/verrouillé et sélecteur d'icônes dynamiques |
| — | `CertigoDailyWidget` | `Widget` | `apps/apple/CertigoNative/WidgetExtension/CertigoWidgetExtension.swift:54` | Widget WidgetKit (`@main`) de l'extension `CertigoWidgetExtension` |

*(Total : **38 `struct ... : View`**, dont **32** dans `CertigoNativeApp.swift`, **3** dans `CertigoWidgetPresentation.swift`, **2** dans `NativeEditorialPilotView.swift` et **1** dans `NativeWidgetGalleryView.swift`, auxquels s'ajoutent `CertigoNativeApp: App`, `CertigoDailyWidget: Widget`, `NativeCrestOutline: Shape`, `NativeChoiceButtonStyle: ButtonStyle` et 2 `ViewModifier`).*