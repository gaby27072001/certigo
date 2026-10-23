# Phase 0 — Étape 8 : Inventaire exhaustif des tests et analyse des trous critiques

> **Branche d'audit :** `transform/phase-0-audit`  
> **Commit HEAD audité :** `778f9c247ceb9c0db29fb931a8573bd328b492ab`  
> **Taxonomie épistémique :**
> - **VÉRIFIÉ** : compté dans les sources (`fichier:ligne`) et/ou exécuté pendant cet audit Phase 0.
> - **INFÉRÉ** : déduit de la structure des cibles et des scripts CI.
> - **NON VÉRIFIABLE / NON EXÉCUTÉ** : requiert macOS / Xcode / iOS Simulator / appareil physique ou un émulateur externe.

---

## 1. Vue d'ensemble par Target et par Stack

**Statut : VÉRIFIÉ**

| Périmètre / Target | Framework de test | Fichiers de test | Nombre de tests / assertions | Exécuté en Phase 0 ? | Résultat observé |
|---|---|---:|---:|---|---|
| **`CertigoKitTests`** (`apps/apple/CertigoKit/Tests/CertigoKitTests`) | `XCTest` *(0 `Swift Testing`)* | 24 fichiers de test (+ 1 helper `OfflinePackFixture.swift`) | **190** fonctions `test*()` (187 multi-plateformes + 3 `#if os(iOS)`) | **Oui** (WSL Swift 6.2.3) | **187 / 187 réussis** sur Linux (0 échec, 2,89 s) ; 3 tests iOS dans `RuntimeDiskProtectionTests` réservés à Xcode |
| **`NativeModelTests`** (`apps/apple/CertigoNative/ModelTests`) | Harnais exécutable `@main` (`#if os(Linux)`) | 1 (`NativeModelTests.swift`, 2 798 lignes) | **254** assertions `try expect(...)` | **Oui** (`tools/test_apple_model.sh`) | **254 / 254 réussies** (0 échec, 0 warning) |
| **`NativeDemoFlowTests`** (`apps/apple/CertigoNative/DemoTests`) | Harnais exécutable `@main` Foundation | 1 (`NativeDemoFlowTests.swift`, 892 lignes) | **132** appels `try check(...)` (**3 304** vérifications dynamiques en boucle) | **Oui** (WSL `swiftc`) | **3 304 / 3 304 réussies** (0 échec, 0 warning) |
| **`CertigoProtectionTests`** (`apps/apple/CertigoProtectionTests`) | `XCTest` (bundle simulateur iOS) | Cible `RuntimeDiskProtectionTests.swift` | **3** fonctions `test*()` | **Non** (requiert macOS/Xcode) | **NON EXÉCUTÉ** (Windows/WSL) |
| **`CertigoProtectionDeviceTests`** (`apps/apple/CertigoProtectionDeviceTests`) | `XCTest` + hôte `CertigoProtectionTestHost.app` | Cible `RuntimeDiskProtectionTests.swift` + `ProtectionTestHostAppDelegate.swift` | **3** fonctions `test*()` | **Non** (requiert macOS + iPhone) | **NON EXÉCUTÉ** (Windows/WSL) |
| **Tests UI natifs (`XCUITest`)** | `XCTest` UI (`XCUIApplication`) | **0** | **0** | — | **ABSENT** (`<Testables>` vide dans `CertigoNative.xcscheme:29-30`) |
| **Tests Python d'outillage & architecture** (`tools/tests/test_*.py`) | Python `unittest` | 19 fichiers | **240** méthodes `def test_*` | **Oui** (`python -B -m unittest`) | **227 réussis**, 0 échec, 13 ignorés (gardes POSIX) |
| **Tests Python Checkov** (`tools/checkov/test_*.py`) | Python `unittest` | 8 fichiers | **101** méthodes `def test_*` | Non (requiert venv Checkov + wheels) | Exécutés en CI par `security-gate.yml` |
| **Tests Node.js d'outillage** (`tools/tests/*.test.mjs`) | `node:test` | 6 fichiers | **52** déclarations `test()` (**75** avec sous-tests) | **Oui** (`node --test`) | **63 réussis**, **1 échec** (`build_public_pages.test.mjs:149`), 11 ignorés |
| **Tests Node.js scripts CI & Infra** (`.github/scripts/*.test.mjs`, `infra/**/*.test.mjs`) | `node:test` | 53 fichiers (34 dans `.github/scripts/`, 19 dans `infra/`) | **476** déclarations `test()` (337 CI + 139 Infra) | Partiel (requiert Bicep CLI / env CI) | Exécutés en CI par `lint-workflows.yml` et `ci-infra.yml` |
| **Backend .NET (`backend/Certigo.sln`)** | `xUnit` (`.NET 8.0`) | 132 fichiers de tests actifs (+ 9 supports/fakes) | **1 143** tests exécutés par xUnit (`[Fact]`, `[Theory]`, `[SkippableFact]`) | **Oui** (`dotnet test`) | **1 122 réussis**, 0 échec, 21 ignorés (Cosmos Emulator / LLM live) |
| **Héritage Flutter / Dart** (`apps/mobile`, `packages/*`) | `flutter_test` / `test` / `integration_test` | 180 fichiers `*_test.dart` | **1 088** blocs `test()` / `testWidgets()` | Non (stack héritage hors périmètre UI) | Exécutés en CI par `ci-mobile.yml` et `ci-cortex-parity.yml` |

---

## 2. Inventaire détaillé des tests Apple natifs (`apps/apple/`)

### 2.1 Package SPM `CertigoKitTests` (`apps/apple/CertigoKit/Tests/CertigoKitTests/*.swift`)

**Statut : VÉRIFIÉ** — Tous les fichiers utilisent `XCTest` (`import XCTest`). Aucun fichier n'utilise encore le framework `Swift Testing` (`import Testing` / `@Test`).

| Fichier (`apps/apple/CertigoKit/Tests/CertigoKitTests/`) | Lignes | Nb tests (`func test*`) | Framework | Statut WSL | Couverture qualitative vérifiée |
|---|---:|---:|---|---|---|
| [`AccountDeletionTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/AccountDeletionTests.swift) | 231 | **6** | `XCTest` | 6/6 OK | Machine à états de suppression de compte (`idle`, `requesting`, `pendingServerConfirmation`, `completed`), purge locale (`SubmissionStore` + `RuntimeContentStore`), gestion HTTP `423 Locked`. |
| [`AppIconSelectionTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/AppIconSelectionTests.swift) | 75 | **4** | `XCTest` | 4/4 OK | Sélection d'icône d'application (`standard`, `streakFire`, `streakAtRisk`, `masteryGold`), recommandation automatique selon le streak/readiness et persistance `CertigoAppIconPreferenceStore`. |
| [`AppLanguageTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/AppLanguageTests.swift) | 257 | **8** | `XCTest` | 8/8 OK | Résolution des 8 langues (`fr`, `en`, `hi`, `zh-Hans`, `ko`, `es`, `it`, `de`), refus d'assimiler `zh-Hant`/`zh-TW`/`zh-HK` à `zh-Hans`, complétude de toutes les clés `AppInterfaceCopy`. |
| [`CIAMConfigurationTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/CIAMConfigurationTests.swift) | 589 | **27** | `XCTest` | 27/27 OK | Validation stricte de `CIAMConfiguration` et `CIAMConfigurationEnvironment` : autorité HTTPS `.ciamlogin.com`, UUID tenant/client, redirect URI `msauth.com.certigo.*://auth`, rejet des placeholders et secrets. |
| [`CIAMProviderPolicyTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/CIAMProviderPolicyTests.swift) | 41 | **2** | `XCTest` | 2/2 OK | Politique fail-closed des fournisseurs d'identité CIAM. |
| [`CanonicalContentTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/CanonicalContentTests.swift) | 211 | **6** | `XCTest` | 6/6 OK | Lecture des questions canoniques v3/v4 (`CanonicalQuestionReader`), rejet anti-fuite si `correctOptionIds` ou `answerKey` est présent dans un payload public. |
| [`CertigoWidgetTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/CertigoWidgetTests.swift) | 290 | **8** | `XCTest` | 8/8 OK | Construction de `CertigoWidgetSnapshot` (états `notConnected`, `goalNeeded`, `readyToPractice`, `streakAtRisk`, `dailyGoalComplete`, `offlinePending`), sérialisation atomique `CertigoWidgetStore` et deep links `certigo://widget/...`. |
| [`ContractTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/ContractTests.swift) | 187 | **11** | `XCTest` | 11/11 OK | Décodage JSON des DTO domaine (`Profile`, `Track`, `LearningPath`, `Lesson`, `QuizResult`, `SubmitQuizRequest`) et validation des invariants (UUID, bornes numériques). |
| [`CortexTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/CortexTests.swift) | 312 | **12** | `XCTest` | 12/12 OK | Algorithme `CertigoCortex` : planification de révision espacée, calcul de faiblesse par compétence, score de readiness pondéré et stades de maîtrise (`MasteryStage`). |
| [`EditorialPilotAPITests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/EditorialPilotAPITests.swift) | 191 | **2** | `XCTest` | 2/2 OK | Appels API du pilote éditorial (`editorialPilot`, `pilotHistory`, `recordPilotLessonAccess`, `markPilotLessonRead`). |
| [`EditorialPilotLessonLinkTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/EditorialPilotLessonLinkTests.swift) | 46 | **2** | `XCTest` | 2/2 OK | Parsing et validation des Universal Links / deep links du pilote éditorial (`EditorialPilotLessonLink`). |
| [`FileProtectionPolicyTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/FileProtectionPolicyTests.swift) | 38 | **2** | `XCTest` | 2/2 OK | Vérification portable de la politique `FileProtectionPolicy` (`completeUntilFirstUserAuthentication`). |
| [`LearningHistoryTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/LearningHistoryTests.swift) | 302 | **6** | `XCTest` | 6/6 OK | Fusion paginée de l'historique serveur (`/me/attempts`) avec la file locale (`SubmissionStore`), détection des conflits et des boucles de curseur. |
| [`LearningServiceTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/LearningServiceTests.swift) | 414 | **10** | `XCTest` | 10/10 OK | Contrats et transport HTTP des services d'apprentissage : recommandations (`next-best`), examens blancs (`generate`/`submit`), tuteur IA (`explain`), succès, quêtes, notifications. |
| [`OfflineLearningTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/OfflineLearningTests.swift) | 149 | **4** | `XCTest` | 4/4 OK | Décodage, intégrité SHA-256 et lecture hors ligne des packs de questions (`OfflineQuestionPack`). |
| [`OfflinePackFixture.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/OfflinePackFixture.swift) | 129 | **0** *(helper)* | Support | — | Générateur de fixtures de packs hors ligne signés/hachés partagé avec `NativeModelTests`. |
| [`PublicReleaseAPITests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/PublicReleaseAPITests.swift) | 288 | **8** | `XCTest` | 8/8 OK | Téléchargement borné des descripteurs de release et manifestes publics (`PublicReleaseAPI`, `BoundedHTTPTransport`). |
| [`PublicReleaseContractTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/PublicReleaseContractTests.swift) | 198 | **9** | `XCTest` | 9/9 OK | Validation cryptographique SHA-256 et canonique des descripteurs `certigo.content.release/v1` et manifestes `v3`. |
| [`PublicResourceTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/PublicResourceTests.swift) | 216 | **6** | `XCTest` | 6/6 OK | Lecture vérifiée des ressources publiques de contenu (`PublicResourceReader`), rejet des fuites de réponses. |
| [`RuntimeClientTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/RuntimeClientTests.swift) | 555 | **11** | `XCTest` | 11/11 OK | Orchestration `LearningClient` : staging/activation de release, épinglage des manifestes pour tentatives en attente, isolation par propriétaire (`ownerId`). |
| [`RuntimeDiskProtectionTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/RuntimeDiskProtectionTests.swift) | 70 | **3** *(`#if os(iOS)`)* | `XCTest` | 0 sur Linux *(3 sur iOS)* | Vérification `NSFileProtectionCompleteUntilFirstUserAuthentication` et `fcntl(F_GETPROTECTIONCLASS)` sur descripteur ouvert iOS. |
| [`RuntimeStoreTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/RuntimeStoreTests.swift) | 552 | **19** | `XCTest` | 19/19 OK | Stockage atomique `RuntimeContentStore` / `RuntimeDisk` : verrous `.lock`, résistance aux symlinks/hardlinks/FIFO, nettoyage borné à 32 fichiers, survie au crash. |
| [`SharedHTTPWireTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/SharedHTTPWireTests.swift) | 159 | **7** | `XCTest` | 7/7 OK | Conformité aux vecteurs filaires JSON partagés avec le backend (`Fixtures/http-wire/v1/`). |
| [`SmartReviewAdvisorTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/SmartReviewAdvisorTests.swift) | 208 | **8** | `XCTest` | 8/8 OK | Logique déterministe de recommandation locale (`SmartReviewAdvisor`) : domaine le plus faible, erreurs récurrentes, persistance `CertigoStudyPlanPreference`. |
| [`SubmissionTests.swift`](../../../apps/apple/CertigoKit/Tests/CertigoKitTests/SubmissionTests.swift) | 305 | **9** | `XCTest` | 9/9 OK | File `SubmissionStore` : idempotence d'`attemptId`, survie au redémarrage, non-réattribution entre comptes, conservation en `.pending` sur erreur réseau/annulation. |
| **Total `CertigoKitTests`** | **5 613** | **190** *(187 Linux + 3 iOS)* | `XCTest` | **187/187 OK** | Couverture solide de la couche `CertigoDomain` / `CertigoData` / `CertigoCortex`. |

### 2.2 Harnais et projets de tests de `apps/apple/CertigoNative` et `CertigoProtection*`

**Statut : VÉRIFIÉ**

| Fichier / Projet | Lignes | Assertions / Tests | Mode d'exécution | Couverture qualitative |
|---|---:|---:|---|---|
| [`apps/apple/CertigoNative/ModelTests/NativeModelTests.swift`](../../../apps/apple/CertigoNative/ModelTests/NativeModelTests.swift) | 2 798 | **254** appels `try expect(...)` | `bash tools/test_apple_model.sh <scratch>` (Linux `swiftc`) | Teste `NativeModel` (`@MainActor`) avec `MemoryVault` et serveur HTTP synthétique : connexion, changement d'objectif, chargement parcours/leçon, soumission quiz, reprise d'activité après fermeture (`NativeResumeState`), pagination d'historique, examen blanc, tuteur, suppression de compte, courses entre propriétaires. **Ne compile ni SwiftUI, ni UIKit, ni Security Keychain, ni MSAL.** |
| [`apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift`](../../../apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift) | 892 | **132** sites `try check(...)` (**3 304** exécutions dynamiques) | Compilation `swiftc` avec `CertigoNativeApp.swift` (`#if !canImport(SwiftUI)`) | Teste les structures Foundation déclarées en tête et en fin de `CertigoNativeApp.swift` : `NativeTrackAppearance`, `NativeCatalogFilter`, `NativeShowcaseUniverse`, `NativePathCoverage`, `NativeDeclaredContentLanguage`, `NativeLearningDuration`, `NativeDemoFlow`, `NativeDemoPersistedSnapshot`, `NativeLessonReadingContent`, et la présence des traductions dans les 8 langues. **Ne compile ni ne rend aucune vue SwiftUI.** |
| [`apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj`](../../../apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj/project.pbxproj) | 183 | **3** tests (`RuntimeDiskProtectionTests`) | `xcodebuild test -scheme CertigoProtectionTests` (macOS Simulator) | Exécute les 3 tests `#if os(iOS)` de `RuntimeDiskProtectionTests.swift` sur simulateur iOS. |
| [`apps/apple/CertigoProtectionDeviceTests/CertigoProtectionDeviceTests.xcodeproj`](../../../apps/apple/CertigoProtectionDeviceTests/CertigoProtectionDeviceTests.xcodeproj/project.pbxproj) | 328 | **3** tests (`RuntimeDiskProtectionTests`) | `xcodebuild test -scheme CertigoProtectionDeviceTests` (iPhone physique) | Exécute les 3 mêmes tests dans une application hôte signée (`CertigoProtectionTestHost.app`) sur iPhone physique pour vérifier l'application réelle de `F_SETPROTECTIONCLASS` par le noyau Darwin/SEP. |

---

## 3. Inventaire des tests d'outillage Python et Node.js (`tools/`, `.github/scripts/`, `infra/`)

### 3.1 Tests Python d'architecture et de gouvernance (`tools/tests/test_*.py`)

**Statut : VÉRIFIÉ** (exécutés via `python -B -m unittest discover -s tools/tests -v` : **240 tests, 227 réussis, 13 ignorés, 0 échec**).

| Fichier (`tools/tests/`) | Lignes | Nb tests (`def test_*`) | Couverture qualitative |
|---|---:|---:|---|
| `test_apple_submission_kit.py` | 316 | **13** | Métadonnées App Store Connect dans les 8 locales et orchestration `validate_apple_mac_one_shot.sh`. |
| `test_check_active_content_age.py` | 145 | **12** | Budget de fraîcheur de `docs/active-content-reference.json`. |
| `test_check_published_content_release.py` | 103 | **8** | Détection de dérive entre release de contenu publiée et référence épinglée. |
| `test_content_release_drill.py` | 239 | **8** | Exercice de promotion et rollback N-1 des releases de contenu. |
| `test_generated_contracts.py` | 216 | **10** | Génération déterministe des contrats C#/Swift/JSON depuis `contracts/*.json`. |
| `test_native_ciam_scheme.py` | 319 | **16** | Génération sécurisée du scheme local ignoré `CertigoNative Local CIAM.xcscheme`. |
| `test_native_debug_architecture.py` | 52 | **3** | Vérifie `ONLY_ACTIVE_ARCH = YES` en Debug dans `CertigoNative.xcodeproj`. |
| `test_native_distribution.py` | 214 | **6** | Vérifie la configuration `Distribution`, les icônes alternatives dans `CertigoAssets.xcassets` et `validate_native_distribution.sh`. |
| `test_native_prism_presentation.py` | 718 | **38** | Analyse statique par expressions régulières de `CertigoNativeApp.swift` (vérifie la présence de `NativePrism`, `NativeTrackTheme`, `@Environment(\.colorSchemeContrast)`, etc.). |
| `test_native_privacy_manifest.py` | 75 | **3** | Conformité de `apps/apple/CertigoNative/Resources/PrivacyInfo.xcprivacy`. |
| `test_native_source_membership.py` | 159 | **3** | Cohérence entre les fichiers de `apps/apple/CertigoNative` et les phases `Sources` de `project.pbxproj` (`CertigoNative` et `CertigoWidgetExtension`). |
| `test_project_state.py` | 1 213 | **40** | Générateur `tools/project_state.py` et synchronisation de `docs/ETAT_DU_PROJET.md`. |
| `test_promotion_tools.py` | 752 | **48** | Outillage de preflight, release et monitoring de promotion backend (`tools/promotion/`). |
| `test_public_domain_project_state.py` | 87 | **1** | Contrat fail-closed du domaine web public et AASA. |
| `test_seed_content_anti_leak.py` | 127 | **5** | Garantit qu'aucune leçon publique compilée par `seed_content.py` ne contient de clé de correction (`answerKey`). |
| `test_sweep_answer_grading.py` | 69 | **8** | Cohérence des clés de correction sur l'ensemble du corpus `content/`. |
| `test_validate_dependency_locks.py` | 186 | **7** | Couverture des fichiers lock (`package-lock.json`, `pubspec.lock`, `Package.resolved`). |
| `test_validate_nuget_locks.py` | 241 | **8** | Validation des `packages.lock.json` NuGet du backend .NET. |
| `test_verify_pub_locks.py` | 134 | **3** | Intégrité des `pubspec.lock` Dart/Flutter. |
| **Total `tools/tests/test_*.py`** | **5 165** | **240** | — |

### 3.2 Tests Python Checkov (`tools/checkov/test_*.py`) et Tests Node.js (`tools/tests/*.test.mjs`, `.github/scripts/*.test.mjs`, `infra/**/*.test.mjs`)

**Statut : VÉRIFIÉ**
- **Checkov (`tools/checkov/test_*.py`)** : **8 fichiers**, **101 méthodes `def test_*`** (`test_bicep_ingress_candidate.py` [51], `test_resource_rule_fixes.py` [12], `test_arm_composition.py` [9], `test_appsettings_applicability.py` [8], `test_conditional_adapter.py` [8], `test_parser_compat.py` [7], `test_checkov_wheel.py` [3], `test_parser_wheel.py` [3]).
- **Outillage Node.js (`tools/tests/*.test.mjs`)** : **6 fichiers**, **52 blocs `test()`** (**75** avec sous-tests) :
  - `b2b_compliance_contract.test.mjs` (128 lignes, **4 tests**) — OK
  - `build_public_pages.test.mjs` (534 lignes, **15 tests** + 16 sous-tests) — **1 échec à la ligne 149** (`assert.match(nativeApp, /Button\("Continue to linked lesson"/)` devenu obsolète après localisation dans `CertigoNativeApp.swift:4196`)
  - `check_public_pages_drift.test.mjs` (114 lignes, **5 tests**) — OK
  - `contrast.test.mjs` (154 lignes, **13 tests**) — OK
  - `schema_ids.test.mjs` (19 lignes, **1 test**) — OK
  - `validate_content.test.mjs` (218 lignes, **14 tests**) — OK
- **Garde-fous CI (`.github/scripts/*.test.mjs`)** : **34 fichiers**, **337 blocs `test()`**.
- **Tests Infrastructure Bicep/Runners (`infra/tests/*.test.mjs` + `infra/ci-runner/*.test.mjs`)** : **19 fichiers**, **139 blocs `test()`**.
---

## 4. Inventaire des tests Backend .NET (`backend/tests/**`)

**Statut : VÉRIFIÉ** (exécutés via `dotnet test Certigo.sln` : **1 143 tests xUnit au total : 1 122 réussis, 21 ignorés, 0 échec**).

### 4.1 `backend/tests/Certigo.Domain.Tests` (26 fichiers — **340 tests xUnit exécutés, 340 réussis**)

| Fichier (`backend/tests/Certigo.Domain.Tests/`) | Lignes | Attributs `[Fact]`/`[Theory]` | `[InlineData]` |
|---|---:|---:|---:|
| `AchievementEngineTests.cs` | 77 | 8 | 0 |
| `AnswerGradingTests.cs` | 63 | 6 | 8 |
| `AttemptIntegrityEvaluatorTests.cs` | 285 | 21 | 0 |
| `BestHourEstimatorTests.cs` | 134 | 13 | 5 |
| `CortexParityTests.cs` | 200 | 6 | 0 |
| `EnterpriseIdentityModelsTests.cs` | 251 | 10 | 2 |
| `EnterpriseLearningMetricsModelsTests.cs` | 234 | 9 | 0 |
| `LeagueTests.cs` | 310 | 25 | 22 |
| `MockExamTests.cs` | 214 | 12 | 0 |
| `NotificationCatalogTests.cs` | 159 | 13 | 22 |
| `NotificationSchedulerTests.cs` | 279 | 16 | 9 |
| `OrganizationModelsTests.cs` | 202 | 10 | 8 |
| `PersonLinkedIdentityTests.cs` | 83 | 4 | 4 |
| `QuestEngineTests.cs` | 65 | 5 | 4 |
| `ReadinessCalculatorTests.cs` | 32 | 1 | 0 |
| `RecommendationEngineTests.cs` | 215 | 13 | 0 |
| `ReviewSchedulerTests.cs` | 37 | 2 | 0 |
| `RuntimeContentProjectorTests.cs` | 338 | 8 | 4 |
| `SeasonEngineTests.cs` | 132 | 10 | 6 |
| `ShareCodecTests.cs` | 53 | 4 | 0 |
| `ShopEngineTests.cs` | 58 | 4 | 0 |
| `StreakFreezeCoverageTests.cs` | 71 | 3 | 0 |
| `StreakRepairPolicyTests.cs` | 106 | 9 | 7 |
| `TutorTests.cs` | 283 | 18 | 0 |
| `XpEngineTests.cs` | 33 | 2 | 0 |

### 4.2 `backend/tests/Certigo.Application.Tests` (39 fichiers — **417 tests xUnit exécutés, 417 réussis**)

| Fichier (`backend/tests/Certigo.Application.Tests/`) | Lignes | Attributs `[Fact]`/`[Theory]` | `[InlineData]` |
|---|---:|---:|---:|
| `AccountDeletionServiceTests.cs` | 295 | 6 | 0 |
| `AchievementServiceTests.cs` | 58 | 3 | 0 |
| `AntiCheatWiringTests.cs` | 115 | 4 | 0 |
| `AttemptHistoryServiceTests.cs` | 175 | 4 | 0 |
| `AuthServiceShadowIdentityTests.cs` | 66 | 1 | 0 |
| `AuthServiceTests.cs` | 1 255 | 42 | 24 |
| `CertificationCatalogTests.cs` | 143 | 6 | 2 |
| `ConcurrencyAndAuthTests.cs` | 190 | 18 | 18 |
| `ContentContractVerifierValidationTests.cs` | 291 | 5 | 0 |
| `ContentReleaseServiceTests.cs` | 772 | 10 | 2 |
| `ContentServiceTests.cs` | 201 | 5 | 0 |
| `EnterpriseLearningMetricsServiceTests.cs` | 474 | 10 | 4 |
| `EnterpriseLearningReceiptOutboxWorkerTests.cs` | 190 | 3 | 0 |
| `ExamServiceTests.cs` | 547 | 16 | 0 |
| `ExerciseItemsV5RulesTests.cs` | 203 | 5 | 0 |
| `FriendServiceTests.cs` | 162 | 7 | 0 |
| `LeaderboardServiceTests.cs` | 234 | 12 | 0 |
| `NativeLearningJourneyContractTests.cs` | 134 | 3 | 2 |
| `NotificationServiceTests.cs` | 236 | 10 | 3 |
| `OrganizationFeatureOptionsTests.cs` | 43 | 3 | 12 |
| `OrganizationMembershipContractTests.cs` | 79 | 2 | 0 |
| `OrganizationServiceTests.cs` | 855 | 19 | 9 |
| `PathServiceTests.cs` | 73 | 2 | 0 |
| `PersonLinkedIdentityContractTests.cs` | 1 402 | 21 | 0 |
| `PersonLinkedIdentityShadowServiceTests.cs` | 658 | 12 | 7 |
| `PilotLearningServiceTests.cs` | 170 | 3 | 0 |
| `PublicContentFileServiceTests.cs` | 444 | 10 | 10 |
| `QuestServiceTests.cs` | 181 | 7 | 0 |
| `QuizServiceTests.cs` | 825 | 22 | 6 |
| `RecommendationServiceTests.cs` | 117 | 5 | 0 |
| `RuntimeContentApiContractTests.cs` | 117 | 1 | 0 |
| `SeasonServiceTests.cs` | 224 | 8 | 0 |
| `ShareCardServiceTests.cs` | 109 | 4 | 0 |
| `ShopServiceTests.cs` | 246 | 9 | 0 |
| `StreakRepairServiceTests.cs` | 178 | 8 | 0 |
| `TutorServiceTests.cs` | 189 | 9 | 0 |
| `UserServiceTests.cs` | 151 | 9 | 0 |
| `VivaLearningContractTests.cs` | 154 | 6 | 4 |
| *(Supports : `Fakes.cs` [746 l.], `TestContent.cs` [118 l.])* | 864 | 0 | 0 |

### 4.3 `backend/tests/Certigo.Infrastructure.Tests` (23 fichiers — **115 tests xUnit : 95 réussis, 20 ignorés**)

| Fichier (`backend/tests/Certigo.Infrastructure.Tests/`) | Lignes | Attributs `[Fact]`/`[Theory]`/`[SkippableFact]` | `[InlineData]` |
|---|---:|---:|---:|
| `ApplicationInsightsOrganizationTelemetryTests.cs` | 120 | 3 | 0 |
| `ApplicationInsightsPersonLinkedIdentityTelemetryTests.cs` | 99 | 2 | 0 |
| `ApplicationInsightsTutorLlmTelemetryTests.cs` | 93 | 3 | 0 |
| `AuthIdentityTests.cs` | 240 | 16 | 4 |
| `CandidateContentPackageTests.cs` *(Skippable)* | 53 | 1 | 0 |
| `ContentContractSchemaV5Tests.cs` | 210 | 3 | 4 |
| `CosmosContentReleaseStoreIntegrationTests.cs` *(5 Skippable)* | 291 | 5 | 0 |
| `CosmosEmulatorSuiteContractTests.cs` | 61 | 2 | 0 |
| `CosmosLifecycleLeaseTests.cs` | 136 | 6 | 0 |
| `CosmosQueryShapeTests.cs` | 84 | 2 | 0 |
| `CosmosRepositoriesIntegrationTests.cs` *(13 Skippable)* | 612 | 13 | 0 |
| `CosmosSerializationTests.cs` | 327 | 9 | 0 |
| `EmbeddedCertificationCatalogSchemaTests.cs` | 78 | 4 | 2 |
| `EmbeddedPilotContentCatalogTests.cs` | 37 | 1 | 0 |
| `EntraTokenValidatorTests.cs` | 131 | 7 | 9 |
| `GraphExternalIdentityDeletionTests.cs` | 126 | 5 | 0 |
| `LoggingEmailSenderTests.cs` | 30 | 1 | 0 |
| `MergedContentPackageIntegrationTests.cs` *(1 Skippable)* | 57 | 1 | 0 |
| `OrganizationCosmosContractTests.cs` | 43 | 2 | 0 |
| `TutorCompletionTests.cs` | 197 | 6 | 2 |
| `VivaLearningFixtureCatalogTests.cs` | 22 | 1 | 0 |
| *(Supports : `CapturingLogger.cs`, `CosmosEmulatorSupport.cs`, `FileContentReleaseSource.cs`)* | 272 | 0 | 0 |

### 4.4 `backend/tests/Certigo.Api.Tests` (53 fichiers — **271 tests xUnit : 270 réussis, 1 ignoré**)

| Fichier (`backend/tests/Certigo.Api.Tests/`) | Lignes | Attributs `[Fact]`/`[Theory]`/`[SkippableFact]` | `[InlineData]` |
|---|---:|---:|---:|
| `AccountDeletionEndToEndTests.cs` | 244 | 1 | 0 |
| `AccountDeletionFunctionsTests.cs` | 110 | 3 | 0 |
| `AchievementFunctionsTests.cs` | 41 | 2 | 0 |
| `ActiveManifestCanonicalDigestTests.cs` | 261 | 3 | 0 |
| `ApiSurfaceContractTests.cs` | 451 | 6 | 0 |
| `AuthFunctionsTests.cs` | 140 | 7 | 11 |
| `BuildIdentityBuildTests.cs` | 176 | 7 | 3 |
| `BuildIdentityTests.cs` | 103 | 6 | 11 |
| `ColdStartTelemetryServiceTests.cs` | 57 | 1 | 0 |
| `ConfigurationKeysTests.cs` | 74 | 3 | 6 |
| `ContentReleaseFunctionsTests.cs` | 413 | 11 | 7 |
| `CriticalHttpFunctionsTests.cs` | 283 | 7 | 0 |
| `EnterpriseIdentityFeatureTests.cs` | 72 | 3 | 8 |
| `EnterpriseLearningMetricsFunctionsTests.cs` | 99 | 2 | 0 |
| `EnterpriseLearningRecoveryFunctionsTests.cs` | 51 | 1 | 0 |
| `ExamFunctionsTests.cs` | 101 | 6 | 0 |
| `ExceptionMiddlewareTests.cs` | 476 | 19 | 11 |
| `FriendFunctionsTests.cs` | 159 | 10 | 0 |
| `FunctionLegacyIdentityObservationSourceTests.cs` | 105 | 3 | 0 |
| `HealthFunctionsTests.cs` | 131 | 4 | 0 |
| `HttpRouteReservationTests.cs` | 74 | 1 | 0 |
| `JwtAuthMiddlewareTests.cs` | 412 | 14 | 9 |
| `KeyVaultSecretValueResolverTests.cs` | 106 | 3 | 0 |
| `LeaderboardFunctionsTests.cs` | 66 | 4 | 0 |
| `LearningFunctionsTests.cs` | 146 | 4 | 4 |
| `LessonFunctionsTests.cs` | 76 | 4 | 0 |
| `MiddlewareOrderingTests.cs` | 113 | 3 | 0 |
| `NativeClientWireFixtureTests.cs` | 92 | 2 | 2 |
| `NotificationFunctionsTests.cs` | 111 | 7 | 0 |
| `OrganizationFunctionsTests.cs` | 132 | 2 | 4 |
| `OrganizationShadowObservationFunctionsTests.cs` | 69 | 2 | 0 |
| `PathFunctionsTests.cs` | 42 | 2 | 0 |
| `PilotLearningFunctionsTests.cs` | 130 | 3 | 0 |
| `PublicManifestGoldenVectorTests.cs` | 66 | 2 | 0 |
| `QuestFunctionsTests.cs` | 83 | 5 | 0 |
| `QuizFunctionsTests.cs` | 88 | 4 | 0 |
| `RecommendationFunctionsTests.cs` | 42 | 2 | 0 |
| `SeasonFunctionsTests.cs` | 83 | 5 | 0 |
| `SecurityHeadersMiddlewareTests.cs` | 128 | 5 | 0 |
| `ShareCardFunctionsTests.cs` | 39 | 2 | 0 |
| `ShopFunctionsTests.cs` | 83 | 5 | 0 |
| `StreakContractGoldenVectorTests.cs` | 144 | 4 | 0 |
| `StreakFunctionsTests.cs` | 101 | 6 | 0 |
| `TokenValidatorConfigurationTests.cs` | 102 | 5 | 6 |
| `TutorFunctionsTests.cs` | 56 | 3 | 0 |
| `TutorLlmLiveEndToEndTests.cs` *(1 Skippable)* | 91 | 1 | 0 |
| `UserFunctionsTests.cs` | 100 | 5 | 0 |
| `VivaLearningFunctionsTests.cs` | 75 | 2 | 0 |
| *(Supports : `Fakes.cs`, `Fakes.Functions.cs`, `FunctionTestHost.cs`, `TutorLlmLiveEndToEndSupport.cs`, `Harness/FunctionTestHarness.cs`)* | 1 345 | 0 | 0 |

---

## 5. Inventaire des tests Flutter / Dart héritage (`apps/mobile/` et `packages/*`)

**Statut : VÉRIFIÉ** (180 fichiers `*_test.dart` totalisant **1 088** blocs `test()` / `testWidgets()`).

| Racine Dart / Flutter | Fichiers `*_test.dart` | Blocs `test` / `testWidgets` | Détail par sous-ensemble |
|---|---:|---:|---|
| **`apps/mobile/test/`** | **105** | **629** | 92 fichiers unitaires/widgets à la racine (`auth_controller_test.dart` [34], `router_redirect_test.dart` [28], `streak_screen_test.dart` [26], `exercise_grading_test.dart` [24], `active_track_test.dart` [18], `streak_copy_test.dart` [17], `lesson_engine_test.dart` [16], `notifications_screen_test.dart` [14], `sign_in_screen_test.dart` [14], `account_deletion_test.dart` [12], `exercise_controller_test.dart` [12], `path_rules_test.dart` [12], `haptics_discipline_test.dart` [11], `sentry_crash_reporting_test.dart` [11], `streak_repair_controller_test.dart` [11], etc.) + 12 fichiers sous `test/structural/` + 1 fichier sous `test/tools/magic_number_guard_test.dart`. |
| **`apps/mobile/integration_test/`** | **2** | **3** | `app_smoke_test.dart` (41 l., 2 tests), `runtime_content_sync_test.dart` (131 l., 1 test). |
| **`packages/core/test/`** | **1** | **31** | `core_test.dart` (281 l., 31 tests). |
| **`packages/cortex/test/`** | **2** | **15** | `cortex_golden_test.dart` (221 l., 7 tests de parité sur `cortex_golden_vectors.json`), `cortex_test.dart` (120 l., 8 tests). |
| **`packages/data/test/`** | **27** | **178** | `sync_engine_test.dart` (19), `runtime_content_sync_test.dart` (16), `streak_repository_test.dart` (13), `streak_test.dart` (12), `correlation_interceptor_test.dart` (11), `file_runtime_content_store_test.dart` (10), `api_path_segments_test.dart` (9), `notification_repository_test.dart` (8), `runtime_content_manifest_test.dart` (8), `sync_dispatcher_test.dart` (7), `track_summary_test.dart` (7), etc. |
| **`packages/prism_ui/test/`** | **43** | **232** | - `test/components/` (16 fichiers, 64 tests : `certification_card_test.dart`, `glass_surface_test.dart`, `onboarding_kit_test.dart`, `prism_button_test.dart`, `tap_target_size_test.dart`, `vendor_tile_test.dart`, etc.)<br>- `test/rendering/` (6 fichiers, 57 tests dont **14 golden tests visuels** dans `renderer_golden_test.dart` [11] et `design_system_golden_test.dart` [3])<br>- `test/theme/` (7 fichiers, 48 tests dont `prism_contrast_contract_test.dart` [20] et `prism_voiceover_contract_test.dart` [5])<br>- `test/tokens/` (9 fichiers, 74 tests dont `prism_colors_test.dart` [26], `prism_tabular_figures_test.dart` [12], `prism_typography_test.dart` [12], `prism_brand_icons_test.dart` [1]). |

---

## 6. Trous critiques de couverture côté client iOS natif (`apps/apple/`)

**Statut : VÉRIFIÉ** (par croisement entre l'inventaire réel §2 et les exigences du Master Prompt §32.1–§32.3).

| # | Trou critique identifié | Preuve dans le dépôt | Impact / Risque pour les Phases 1–11 | Action requise (Phases 1–2) |
|---:|---|---|---|---|
| **1** | **Absence totale de target et de suite `XCUITest`** | `apps/apple/CertigoNative/CertigoNative.xcodeproj/xcshareddata/xcschemes/CertigoNative.xcscheme:29-30` a une balise `<Testables>` vide ; `project.pbxproj` ne contient aucun target `com.apple.product-type.bundle.ui-testing` ; `tools/validate_apple_mac_one_shot.sh:146` et `:206` retourne le code `3` (`BLOCKED: no native UI test target configured`). | **Critique** : aucun des 8 parcours critiques du Master Prompt §32.2 (lancement → Aujourd'hui, séance 1 question + feedback serveur, soumission hors ligne + reprise après kill, changement d'objectif, recherche Bibliothèque, reprise d'erreur, suppression de compte, mode Démo) n'est vérifié dans une vraie hiérarchie SwiftUI/UIKit. | Créer un target `CertigoNativeUITests` dès la Phase 1 avant tout découpage ou refonte d'écran. |
| **2** | **Absence totale d'audit d'accessibilité automatisé (`performAccessibilityAudit()`)** | `0` occurrence de `performAccessibilityAudit` dans tout le dépôt (`apps/apple/**`). | **Élevé** : les régressions de contraste, de cibles tactiles `< 44×44 pt`, de troncature `AX3` ou de libellés VoiceOver dans les 38 vues SwiftUI ne sont détectées par aucun test automatisé. | Intégrer `try app.performAccessibilityAudit()` dans les tests `XCUITest` sur chaque écran de niveau 1 (Master Prompt §28 & §32.1). |
| **3** | **Absence totale de tests de snapshots visuels natifs SwiftUI** | Contrairement à `packages/prism_ui/test/rendering/renderer_golden_test.dart` côté Flutter, il n'existe aucun test de snapshot ou d'instantané d'image des composants SwiftUI (`NativeGoalHero`, `NativeCertificationCard`, `CertigoWidgetCardView`, etc.) en clair / sombre / `AX3` / Increase Contrast. | **Élevé** : dérive visuelle silencieuse lors de l'extraction du module `Prism` (Phase 2) et de la refonte des écrans (Phases 3–9). | Trancher **DR-007** (outil de snapshot testing SwiftUI ou `XCUIScreenshot` de référence) et couvrir chaque composant `Prism` en Phase 2. |
| **4** | **Absence de tests de métriques de performance (`XCTMetric`)** | `0` occurrence de `XCTApplicationLaunchMetric`, `XCTOSSignpostMetric`, `XCTClockMetric` ou `XCTMemoryMetric` dans `apps/apple/`. | **Moyen** : impossible de vérifier automatiquement en CI/Mac la porte 5 (`PERFORMANCE CHECK`, non-régression > 10 % sur le lancement ≤ 400 ms et mémoire ≤ 120 Mo). | Ajouter un test de lancement `measure(metrics: [XCTApplicationLaunchMetric()])` dans `CertigoNativeUITests`. |
| **5** | **Vues SwiftUI, `CredentialVault` (Keychain) et `MSALAuthenticationProvider` jamais compilés par les tests Linux** | `NativeModelTests.swift:1` indique explicitement : `// Linux-only source harness: the real Security vault, UIKit and MSAL are not linked or executed.` ; `NativeDemoFlowTests.swift:890` affiche `no Apple UI was compiled or rendered.` | **Élevé** : une modification de vue SwiftUI dans `CertigoNativeApp.swift`, `NativeWidgetGalleryView.swift` ou `NativeEditorialPilotView.swift` peut casser la compilation iOS sans faire échouer `swift test` ni `tools/test_apple_model.sh` sous Linux. | Rattacher un target `CertigoNativeTests` (hôte `CertigoNative.app`) au scheme `CertigoNative` pour compiler et tester les vues, `CredentialVault` et le câblage `MSALAuthenticationProvider` sur simulateur iOS. |
| **6** | **Tests de garde-fous d'architecture basés sur des regex fragiles sur le monolithe** | `tools/tests/test_native_prism_presentation.py` (718 lignes) et `tools/tests/build_public_pages.test.mjs:136-152` inspectent `CertigoNativeApp.swift` par sous-chaînes/regex ; `build_public_pages.test.mjs:149` échoue déjà suite à la localisation d'un bouton. | **Moyen** : le découpage du monolithe `CertigoNativeApp.swift` en Phase 1 fera échouer ces tests s'ils cherchent toujours tout le code dans un seul fichier. | Adapter les garde-fous pour scanner le dossier `apps/apple/CertigoNative/Sources/**/*.swift` et le module `Prism` plutôt qu'un fichier monolithique unique. |
| **7** | **Framework `Swift Testing` (`@Test`) non encore utilisé** | `swift test` rapporte `Test run with 0 tests in 0 suites passed` pour `Swift Testing` ; les 190 tests de `CertigoKitTests` sont 100 % en `XCTest`. | **Faible** : `XCTest` et `Swift Testing` cohabitent sans conflit dans Swift 6.2, mais la convention du Master Prompt §32.1 (« *Swift Testing (`@Test`) pour le nouveau, XCTest maintenu pour l'existant* ») doit être amorcée dès la Phase 1/2. | Écrire les nouveaux tests unitaires `Prism` et `BrandAssets` avec `import Testing` (`@Test`, `#expect`). |