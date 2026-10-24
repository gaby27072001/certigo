# Phase 0 — Étape 2 : Baseline technique (Build, Warnings, Tests, Performance, Captures)

> **Branche d'audit :** `transform/phase-0-audit`  
> **Commit HEAD audité :** `778f9c247ceb9c0db29fb931a8573bd328b492ab`  
> **Environnement d'exécution :** Windows 11 ARM64 + WSL2 Ubuntu 24.04 (`aarch64-unknown-linux-gnu`, Swift `6.2.3-RELEASE`, Python `3.12`, .NET SDK `8.0`, Node.js `v24.19.0`)  
> **Taxonomie épistémique :**
> - **VÉRIFIÉ** : exécuté et mesuré directement pendant cet audit Phase 0.
> - **INFÉRÉ** : déduit des configurations et des journaux/preuves datés du dépôt.
> - **NON VÉRIFIABLE / NON EXÉCUTÉ** : requiert macOS + Xcode 26+ + iOS Simulator / appareil physique (commandes exactes fournies en §4).

---

## 1. Synthèse de la Baseline Phase 0

| Domaine | Outil / Cible | Statut d'exécution | Résultat mesuré | Warnings | Durée |
|---|---|---|---|---|---|
| **SwiftPM Tests (`CertigoKitTests`)** | `swift test` (WSL Swift 6.2.3, `-Xswiftc -warnings-as-errors`) | **VÉRIFIÉ** | **187 / 187 réussis** (0 échec, 0 ignoré) | **0 warning Swift** | **2,89 s** |
| **SwiftPM Build Release (`CertigoKit`)** | `swift build -c release` (WSL Swift 6.2.3, `-Xswiftc -warnings-as-errors`) | **VÉRIFIÉ** | **Succès** (`CertigoCortex`, `CertigoDomain`, `CertigoData`) | **0 warning Swift** | **65,95 s** |
| **Harnais `NativeModelTests`** | `bash tools/test_apple_model.sh` (WSL Swift 6.2.3, `-strict-concurrency=complete -warnings-as-errors`) | **VÉRIFIÉ** | **254 / 254 assertions `expect()` réussies** | **0 warning Swift** | **~4,2 s** |
| **Harnais `NativeDemoFlowTests`** | `swiftc` Foundation (`CertigoNativeApp.swift` + `NativeDemoFlowTests.swift`) | **VÉRIFIÉ** | **3 304 / 3 304 vérifications `check()` réussies** | **0 warning Swift** | **~3,8 s** |
| **Tests Python d'architecture & gouvernance** | `python -B -m unittest discover -s tools/tests -v` | **VÉRIFIÉ** | **227 réussis / 240 total** (0 échec, 13 ignorés POSIX) | 0 | **146,98 s** |
| **Intégrité de l'état généré du projet** | `python -B tools/project_state.py --check` | **VÉRIFIÉ** | **`Project state is current.`** (SHA-256 contenu vérifié) | 0 | **< 2 s** |
| **Tests Backend .NET (`Certigo.sln`)** | `dotnet test` (4 projets xUnit : Domain, Application, Infrastructure, Api) | **VÉRIFIÉ** | **1 122 réussis / 1 143 total** (0 échec, 21 ignorés) | 0 | **~35 s** |
| **Validateur du corpus de contenu** | `node tools/validate_content.mjs` (91 pistes, 147 leçons) | **VÉRIFIÉ** | **`✓ All content valid.`** (0 erreur) | 0 | **1,77 s** |
| **Tests Node.js d'outillage (`tools/tests/*.test.mjs`)** | `node --test tools/tests/*.test.mjs` | **VÉRIFIÉ** | **63 réussis / 75 total** (**1 échec**, 11 ignorés POSIX) | 0 | **0,71 s** |
| **Build Xcode (`CertigoNative` + `CertigoWidgetExtension`)** | `xcodebuild` (`Debug`, `Release`, `Distribution` sur simulateur iPhone) | **NON EXÉCUTÉ** *(Windows/WSL sans macOS/Xcode local)* | Réf. équipe du 22/10/2026 post-PR #99 : **0 erreur, 0 warning** | `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` | Voir §3 & §4 |
| **Tests iOS de protection fichier** | `xcodebuild test` (`CertigoProtectionTests` / `CertigoProtectionDeviceTests`) | **NON EXÉCUTÉ** *(Windows/WSL sans macOS/Xcode local)* | 3 tests `RuntimeDiskProtectionTests` sous `#if os(iOS)` | — | Voir §3 & §4 |
| **Performance (Lancement, Mémoire, Taille `.app`/`.ipa`)** | `XCTApplicationLaunchMetric` / Instruments App Launch | **NON EXÉCUTÉ** *(Windows/WSL sans macOS/Xcode local)* | Réf. trace Instruments du 19/10/2026 : **1re frame ~64 ms**, **Foreground-Active ~0,95 s** | — | Voir §3 & §4 |
| **Captures simulateur (`screenshots/`)** | Simulateur iOS (clair, sombre, `AX3`) | **NON EXÉCUTÉ** *(Windows/WSL sans macOS/Xcode local)* | Dossier `docs/transformation/phase-0/screenshots/` créé, en attente d'exécution Mac | — | Voir §4.4 |

---

## 2. Résultats détaillés des vérifications exécutées (VÉRIFIÉ)

### 2.1 Package Swift `apps/apple/CertigoKit` et harnais Foundation (`WSL Swift 6.2.3`)

#### A. Exécution de `swift test`

**Commande exécutée :**
```bash
wsl.exe -e bash -lc 'export PATH="/opt/certigo-swift-2a7c23af/swift-6.2.3-RELEASE-ubuntu24.04-aarch64/usr/bin:$PATH"; export LD_LIBRARY_PATH="/opt/certigo-swift-2a7c23af/runtime/usr/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}"; swift test --package-path /mnt/c/Users/gchambaud/.copilot/repos/copilot-worktrees/gaby27072001_certigo/gaby27072001-urban-umbrella/apps/apple/CertigoKit --scratch-path /tmp/certigo-phase0-swift -Xswiftc -warnings-as-errors'
```

**Résultat observé (**VÉRIFIÉ**) :**
- Compilation avec `-Xswiftc -warnings-as-errors` : **0 erreur, 0 warning de compilation Swift**.
  *(Note : l'éditeur de liens système GNU `ld.bfd` sur Ubuntu 24.04 aarch64 émet un avertissement bénin de plateforme `warning: .../CertigoKitPackageTests.xctest has a LOAD segment with RWX permissions` propre au runtime XCTest ELF sous Linux).*
- Exécution `XCTest` (`debug.xctest`) : **187 tests exécutés, 187 réussis, 0 échec, 0 ignoré** en **2,89 secondes**.
- Exécution `Swift Testing` : **`Test run with 0 tests in 0 suites passed after 0.001 seconds`** (toutes les suites actuelles utilisent `XCTest`).

| Suite `XCTestCase` (`apps/apple/CertigoKit/Tests/CertigoKitTests/`) | Tests exécutés | Réussis | Échoués | Durée (s) |
|---|---:|---:|---:|---:|
| `AccountDeletionTests` | 6 | 6 | 0 | 0,173 |
| `AppIconSelectionTests` | 4 | 4 | 0 | 0,009 |
| `AppLanguageTests` | 8 | 8 | 0 | 0,133 |
| `CIAMConfigurationTests` | 27 | 27 | 0 | 0,112 |
| `CIAMProviderPolicyTests` | 2 | 2 | 0 | 0,001 |
| `CanonicalContentTests` | 6 | 6 | 0 | 0,230 |
| `CertigoWidgetTests` | 8 | 8 | 0 | 0,022 |
| `ContractTests` | 11 | 11 | 0 | 0,212 |
| `CortexTests` | 12 | 12 | 0 | 0,352 |
| `EditorialPilotAPITests` | 2 | 2 | 0 | 0,006 |
| `EditorialPilotLessonLinkTests` | 2 | 2 | 0 | 0,001 |
| `FileProtectionPolicyTests` | 2 | 2 | 0 | 0,000 |
| `LearningHistoryTests` | 6 | 6 | 0 | 0,122 |
| `LearningServiceTests` | 10 | 10 | 0 | 0,021 |
| `OfflineLearningTests` | 4 | 4 | 0 | 0,074 |
| `PublicReleaseAPITests` | 8 | 8 | 0 | 0,151 |
| `PublicReleaseContractTests` | 9 | 9 | 0 | 0,039 |
| `PublicResourceTests` | 6 | 6 | 0 | 0,112 |
| `RuntimeClientTests` | 11 | 11 | 0 | 0,289 |
| `RuntimeStoreTests` | 19 | 19 | 0 | 0,791 |
| `SharedHTTPWireTests` | 7 | 7 | 0 | 0,006 |
| `SmartReviewAdvisorTests` | 8 | 8 | 0 | 0,015 |
| `SubmissionTests` | 9 | 9 | 0 | 0,018 |
| `RuntimeDiskProtectionTests` *(compilé uniquement sous `#if os(iOS)`)* | 0 *(sur Linux ; 3 sur iOS)* | — | — | — |
| **Total `CertigoKitTests` (Linux/WSL)** | **187** | **187** | **0** | **2,890** |

#### B. Harnais de coordination `NativeModelTests` (`tools/test_apple_model.sh`)

- Compile `apps/apple/CertigoNative/Sources/NativeModel.swift` + `apps/apple/CertigoNative/ModelTests/NativeModelTests.swift` + `OfflinePackFixture.swift` avec `-swift-version 6 -strict-concurrency=complete -warnings-as-errors`.
- Résultat (**VÉRIFIÉ**) : **254 assertions `try expect(...)` exécutées et réussies**, **0 échec**, **0 warning Swift**.
- Sortie : `NativeModel: history pagination/merge/errors/deletion recovery/owner races and existing coordination/journey/restoration checks passed.`

#### C. Harnais Foundation `NativeDemoFlowTests`

- Compile les sections portables (`#if !canImport(SwiftUI)`) de `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift` avec `apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift` en Swift 6 (`-strict-concurrency=complete -warnings-as-errors`).
- Résultat (**VÉRIFIÉ**) : **3 304 vérifications dynamiques `check(...)` réussies** (couvrant les 8 langues, le filtrage catalogue, la migration d'état Démo et l'assemblage audio), **0 échec**, **0 warning Swift**.

---

### 2.2 Tests Python d'architecture et d'état du projet (`tools/tests/*.py` et `tools/project_state.py`)

**Commandes exécutées (avec `-B` pour n'écrire aucun `__pycache__`) :**
```powershell
python -B -m unittest discover -s tools/tests -v
python -B tools/project_state.py --check
```

**Résultats observés (**VÉRIFIÉ**) :**
- `unittest discover -s tools/tests` :
  - **Total :** **240 tests** répartis dans 19 fichiers `test_*.py` (dont `test_native_prism_presentation.py` [38 tests], `test_native_distribution.py` [6 tests], `test_native_source_membership.py` [3 tests], `test_native_privacy_manifest.py` [3 tests], `test_native_debug_architecture.py` [3 tests], `test_native_ciam_scheme.py` [16 tests], `test_apple_submission_kit.py` [13 tests]).
  - **Réussis :** **227**
  - **Échoués :** **0**
  - **Ignorés (`skipped`) :** **13** (11 dans `test_apple_submission_kit.py`, 1 dans `test_native_ciam_scheme.py`, 1 dans `test_validate_dependency_locks.py` — tests d'orchestration shell POSIX ou de création de liens symboliques Unix non applicables sous Windows sans privilège élevé).
  - **Durée :** **146,975 s**.
- `python -B tools/project_state.py --check` :
  - Sortie :
    ```text
    Pinned content reference matches the newest published release sha256:95c69c30daf77df89f4438d8d662203ef5bf9f2d5eac9eabac139e495627a946.
    Project state is current.
    ```

---

### 2.3 Tests Backend .NET (`backend/Certigo.sln`)

**Commande exécutée** (lancée dans le worktree frère `certigo-native-widgets\backend` partageant exactement le même arbre `backend/` afin de respecter l'interdiction absolue de créer `bin/` ou `obj/` dans `gaby27072001-urban-umbrella`) :
```powershell
dotnet test Certigo.sln --nologo
```

**Résultats observés (**VÉRIFIÉ**) :**

| Projet de test xUnit (`.NET 8.0`) | Total | Réussis | Échoués | Ignorés (`[SkippableFact]`) | Durée |
|---|---:|---:|---:|---:|---:|
| `Certigo.Domain.Tests` | 340 | 340 | 0 | 0 | 2,00 s |
| `Certigo.Application.Tests` | 417 | 417 | 0 | 0 | 0,41 s |
| `Certigo.Infrastructure.Tests` | 115 | 95 | 0 | 20 | 1,00 s |
| `Certigo.Api.Tests` | 271 | 270 | 0 | 1 | 31,00 s |
| **Total `backend/Certigo.sln`** | **1 143** | **1 122** | **0** | **21** | **~34,41 s** |

- Les **20 tests ignorés** dans `Certigo.Infrastructure.Tests` correspondent aux tests d'intégration Cosmos DB Emulator (`CosmosRepositoriesIntegrationTests`, `CosmosContentReleaseStoreIntegrationTests`) et de packages de contenu externes (`CandidateContentPackageTests`, `MergedContentPackageIntegrationTests`) lorsque l'émulateur Cosmos n'est pas démarré localement.
- L'**unique test ignoré** dans `Certigo.Api.Tests` est `TutorLlmLiveEndToEndTests.ExplainAnswer_ReturnsRealLlmExplanation_AgainstDeployedEnvironment` (requiert un environnement Azure OpenAI déployé).

---

### 2.4 Validateur de contenu (`tools/validate_content.mjs`) et tests Node.js (`tools/tests/*.test.mjs`)

**Résultats observés (**VÉRIFIÉ**) :**
1. **Validateur du corpus (`node tools/validate_content.mjs`)** :
   - **Statut :** **RÉUSSI** (`✓ All content valid.`, code de retour `0`).
   - **Périmètre validé :** **91 pistes** (`content/*/track.yaml`) et **147 leçons** (`content/*/lessons/*.lesson.yaml`) validées par rapport à `content/schema/track.schema.json` et `content/schema/lesson.schema.json`, y compris l'intégrité référentielle des unités/domaines, la somme des poids de domaines (`1.0`), et le cliquet de diversité des types d'exercices (`UNUSED_ITEM_TYPES_PIN = ['matchPairs']`).
   - **Durée :** **1 767 ms** (1,77 s).
2. **Tests unitaires Node.js (`node --test tools/tests/*.test.mjs`)** :
   - **Total :** **75 tests** (incluant les sous-tests de `build_public_pages.test.mjs`) répartis sur 6 fichiers (`b2b_compliance_contract.test.mjs`, `build_public_pages.test.mjs`, `check_public_pages_drift.test.mjs`, `contrast.test.mjs`, `schema_ids.test.mjs`, `validate_content.test.mjs`).
   - **Réussis :** **63** | **Ignorés :** **11** (symlinks sur Windows) | **Échoué :** **1** | **Durée :** **711,3 ms**.
   - **Anomalie préexistante détectée (documentée sans modification conformément aux règles de la Phase 0) :**
     - Fichier : [`tools/tests/build_public_pages.test.mjs:149`](../../../tools/tests/build_public_pages.test.mjs)
     - Test : `URL receipt only stages a link; access and read operations stay at their V1 boundary`
     - Cause : `assert.match(nativeApp, /Button\("Continue to linked lesson"/)` et `assert.match(nativeApp, /Button\("Open linked lesson"/)` cherchent encore les chaînes anglaises codées en dur dans `CertigoNativeApp.swift`, alors que `CertigoNativeApp.swift:4196` et `:6576` utilisent désormais l'accesseur localisé `copy.native(.openLinkedLesson)`.

---

## 3. Éléments `NON EXÉCUTÉ — environnement Windows/WSL sans macOS/Xcode local` et Mesures de Référence Connues

### 3.1 Build Xcode (`Debug`, `Release`, `Distribution`) sur simulateur iPhone

- **Statut dans cet audit :** **`NON EXÉCUTÉ — environnement Windows/WSL sans macOS/Xcode local`**.
- **État du code source vérifié statiquement (**VÉRIFIÉ**) :**
  - Le bloqueur de build **H4** du 22/10/2026 (`@Environment(\.accessibilityContrast)` dans `NativeCertificationCrest`) a déjà été **corrigé sur `main` par la PR #99 (`1a025a28` / `f6dd2ea7`)** : `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3683` utilise désormais `@Environment(\.colorSchemeContrast) private var contrast`.
  - La cohérence du graphe OpenStep `project.pbxproj`, l'appartenance des 7 fichiers sources à `CertigoNative` et des 2 fichiers sources à `CertigoWidgetExtension`, ainsi que la présence des icônes alternatives dans `CertigoAssets.xcassets`, sont validées par `tools/tests/test_native_source_membership.py`, `test_native_distribution.py` et `test_native_prism_presentation.py` (**227/227 tests Python exécutables passent**).
- **Mesure de référence connue (équipe produit) :**
  - Journal de build Xcode sur iPhone physique du **22/10/2026 post-PR #99** : **compilation réussie avec 0 erreur et 0 warning** (`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`).

### 3.2 Performance (`XCTApplicationLaunchMetric`, Instruments, Mémoire, Taille `.app`/`.ipa`)

- **Statut dans cet audit :** **`NON EXÉCUTÉ — environnement Windows/WSL sans macOS/Xcode local`**.
- **Constat structurel sur les tests de performance (**VÉRIFIÉ**) :**
  - Aucun test utilisant `XCTApplicationLaunchMetric`, `XCTOSSignpostMetric`, `XCTClockMetric` ou `XCTMemoryMetric` n'existe actuellement dans `apps/apple/`.
- **Mesures de référence connues (trace Instruments App Launch du 19/10/2026 documentée dans le Master Prompt §4.1 & §30) :**
  - **Lancement à froid → première frame :** **~64 ms** (largement sous le budget cible du Master Prompt §30 fixé à **≤ 400 ms**).
  - **Transition vers `Foreground — Active` :** **~0,95 s** (195 échantillons CPU sur `Main Thread` pendant le démarrage).
  - **Mémoire au repos sur l'écran d'accueil (`Aujourd'hui`) :** non relevée dans ce worktree Windows/WSL (budget cible Master Prompt §30 : **≤ 120 Mo**).
  - **Taille `.app` et `.ipa` compressée :** non mesurable sans `xcodebuild archive` sur macOS (budget cible Master Prompt §30 : **≤ 35 Mo compressé** hors packs hors ligne téléchargés à la demande).

---

## 4. Commandes exactes à exécuter par le propriétaire sur son Mac

Pour compléter les mesures macOS/Xcode et les captures de référence sur le checkout permanent du Mac (Xcode 26+) :

### 4.1 Validation one-shot officielle (Build Debug simulateur + `CertigoKitTests` + `CertigoProtectionTests` + Archive `Distribution` non signée)

```bash
# 1. Identifier l'UDID d'un simulateur iPhone disponible (ex. iPhone 16 Pro / iPhone 17 Pro)
xcrun simctl list devices available

# 2. Lancer le script officiel de validation macOS (écrit hors du dépôt dans ~/Library/Logs/Certigo)
CERTIGO_SIMULATOR_ID="<UDID-SIMULATEUR>" \
CERTIGO_DISTRIBUTION_VERSION="0.1.0" \
CERTIGO_DISTRIBUTION_BUILD="1" \
bash tools/validate_apple_mac_one_shot.sh --prepare-archive
```

### 4.2 Build propre `Debug` et `Release` sur simulateur iPhone (hors dépôt)

```bash
SIM_ID="<UDID-SIMULATEUR>"
LOG_DIR="$HOME/Library/Logs/Certigo/phase-0-baseline"
mkdir -p "$LOG_DIR"

# Build Debug (CertigoNative + CertigoWidgetExtension)
xcodebuild clean build \
  -project apps/apple/CertigoNative/CertigoNative.xcodeproj \
  -scheme CertigoNative \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath "$LOG_DIR/DerivedData-Debug" \
  -clonedSourcePackagesDirPath "$LOG_DIR/SourcePackages" \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$LOG_DIR/xcodebuild-debug.log"

# Build Release (CertigoNative + CertigoWidgetExtension) + mesure de la taille du .app
xcodebuild clean build \
  -project apps/apple/CertigoNative/CertigoNative.xcodeproj \
  -scheme CertigoNative \
  -configuration Release \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath "$LOG_DIR/DerivedData-Release" \
  -clonedSourcePackagesDirPath "$LOG_DIR/SourcePackages" \
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$LOG_DIR/xcodebuild-release.log"

du -sh "$LOG_DIR/DerivedData-Release/Build/Products/Release-iphonesimulator/CertigoNative.app"
```

### 4.3 Profilage Instruments (App Launch & Allocations mémoire au repos)

```bash
# Enregistrer une trace App Launch de 10 secondes sur le simulateur ou l'iPhone physique :
xcrun xctrace record \
  --template 'App Launch' \
  --device "$SIM_ID" \
  --time-limit 10s \
  --output "$LOG_DIR/AppLaunch-Phase0.trace" \
  --launch -- "$LOG_DIR/DerivedData-Release/Build/Products/Release-iphonesimulator/CertigoNative.app"
```

### 4.4 Captures d'écran de référence (`docs/transformation/phase-0/screenshots/`) en modes Clair, Sombre et `AX3`

```bash
xcrun simctl boot "$SIM_ID" || true
xcrun simctl install "$SIM_ID" "$LOG_DIR/DerivedData-Debug/Build/Products/Debug-iphonesimulator/CertigoNative.app"
xcrun simctl status_bar "$SIM_ID" override --time "09:41" --batteryState charged --batteryLevel 100

# Mode Clair (Light)
xcrun simctl ui "$SIM_ID" appearance light
xcrun simctl launch "$SIM_ID" com.certigo.native.dev
sleep 2
xcrun simctl io "$SIM_ID" screenshot docs/transformation/phase-0/screenshots/entry-light.png

# Mode Sombre (Dark)
xcrun simctl ui "$SIM_ID" appearance dark
sleep 1
xcrun simctl io "$SIM_ID" screenshot docs/transformation/phase-0/screenshots/entry-dark.png

# Taille Dynamic Type AX3 (accessibilityExtraExtraExtraLarge)
xcrun simctl ui "$SIM_ID" content_size extra-extra-extra-large-accessibility
sleep 1
xcrun simctl io "$SIM_ID" screenshot docs/transformation/phase-0/screenshots/entry-ax3.png
xcrun simctl ui "$SIM_ID" content_size large
```