# Audit technique exhaustif — Certigo · Document pilote phasé

> **Nature du document.** Ceci est le **document pilote** d'un audit technique neuf (*fresh full
> audit*), factuel et sans complaisance, mené au niveau d'exigence d'une grande entreprise
> technologique, sur **tout le monorepo Certigo** (mobile Flutter/Dart, backend .NET 8 isolated
> Azure Functions, infra Bicep, contenu, tools, CI/CD, docs).
>
> Il est **phasé et reprenable** : l'audit se déroule en 13 phases (P0 → P12), une seule à la fois,
> avec **checkpoint + commit + arrêt** après chaque phase. Ce fichier porte l'état courant, les
> règles de reprise, le journal des phases, les findings (IDs stables), la remédiation appliquée et
> une checklist de reprise. Le **rapport précédent** (ancré sur le commit `9c488c6`) est **archivé
> intégralement** en annexe (fichier séparé, jamais perdu).

> **Convention de certitude** (sur chaque affirmation non triviale) :
> **[CERTAIN]** (vérifié dans le code, `fichier:ligne`) · **[PROBABLE]** (déduit, cohérent, non
> exécuté) · **[À VÉRIFIER]** (nécessite une validation humaine) · **[INCONNU]** (non vérifiable
> depuis le dépôt).
>
> **Convention de validation** : toute validation **réellement exécutée** est reportée avec sa
> commande et son résultat. Toute validation **non exécutée** est marquée **[À EXÉCUTER]** avec la
> **commande exacte** — il est **interdit** de prétendre qu'une validation a tourné si ce n'est pas
> le cas.

| Repère | Valeur |
|---|---|
| Périmètre | Tout le monorepo (mobile, backend, infra, contenu, tools, CI/CD, docs, historique Git) |
| Commit d'ancrage (audit neuf) | `cdd8f30` — `cdd8f3055fa78eff1148bb30cc2ef69df77a516b` (HEAD, 2026-07-03) |
| Rapport précédent (archivé) | `9c488c6` — `9c488c6246c5f2f4a5906599480cc90e6b35fbf3` (2026-06-23, PR #49) |
| Méthode | Cartographie → lecture directe du code + revues de domaine → recoupement, phase par phase |
| Cadence | **1 phase à la fois** → mise à jour de ce doc → **commit** → **STOP** → attente feu vert |
| Doc pilote | Ce fichier (`AUDIT_Certigo.md`) |
| Annexe préservée | [`AUDIT_Certigo_annexe_9c488c6.md`](AUDIT_Certigo_annexe_9c488c6.md) (735 lignes / 58 713 octets, intégral) |

---

## Sommaire

1. [État courant de l'audit](#1-état-courant-de-laudit)
2. [Règles de reprise](#2-règles-de-reprise)
3. [Plan de phases 0–12](#3-plan-de-phases-0-12)
4. [Journal des phases](#4-journal-des-phases)
5. [Findings](#5-findings)
6. [Remédiation appliquée](#6-remédiation-appliquée)
7. [Checklist de reprise rapide](#7-checklist-de-reprise-rapide)
8. [Annexe — Rapport précédent (commit 9c488c6)](#8-annexe--rapport-précédent-commit-9c488c6)

---

## 1. État courant de l'audit

| Champ | Valeur |
|---|---|
| **Dernière phase terminée** | **Phase 7 — Flutter mobile** |
| **Phase en cours** | — (en attente de feu vert) |
| **Prochaine phase** | **Phase 8 — Contenu & tooling** |
| Dernière mise à jour | 2026-07-04 04:03 (+01:00) |
| Findings ouverts | **41** — `F-P2-01/02/03/04/06/07/08` (7, CI/CD) + `F-P3-01…10` (10, repro/deps) + `F-P4-01/02/03` (3, backend) + `F-P5-01…09` (9, sécu app) + `F-P6-01…08` (8, Azure/IaC) + `F-P7-02/03/04/05` (4, mobile ; `F-P7-01` = **faux positif retiré**, artefact d'affichage `******`) ; `F-P4-04` **et** `F-P1-01` **clôturés en P4** (non recomptés) ; `F-P2-05` **instruit en P3** (→ `F-P3-01`/`F-P3-04`) ; `F-P2-09` = faux positif P1 infirmé (non compté) ; volet **app** de `F-P4-03` clos en P5 (→ `F-P5-01`), volet **dérivation infra** **clos en P6** (→ `F-P6-01`) |
| Remédiations appliquées | 0 (aucune modification de code en P0–P7 ; correctifs **décrits**, non appliqués) |
| Bloqué / en boucle ? | Non |

> **Statut :** ✅ **Phase 7 terminée.** Audit **mobile Flutter/Dart** (`apps/mobile/**` · `packages/**` ·
> `prism_ui/**`) — archi feature-first, **Riverpod v2** + **go_router**, offline engine, écrans vs API, stockage
> des jetons, a11y, couverture de tests. **4 findings `F-P7-02…05`** (`F-P7-01` **retiré — faux positif** :
> l'octet réel de `packages/data/lib/src/api/api_client.dart:70` = `Bearer $token` **correct**, prouvé par
> **codes-caractères** ; le `'******'` vu en `git show`/`git blame` = **artefact d'affichage** — cf. P5 ; 3 **Faible** :
> drift SDK Flutter `3.24.0` vs `3.27.4` + `pubspec.lock` gitignoré (recoupe `F-P3-03/04/07`), a11y sémantique
> **éparse** (~12/82 écrans), file offline **en clair** `SharedPreferences` (actions de jeu, **pas** de jeton) ;
> 1 **Info** : crash-reporting **non câblé** → **routé P9**). **Positif prouvé** : le jeton OIDC est bien en
> `flutter_secure_storage` (Keychain/Keystore), intercepteur Dio propre. **Validations RÉELLES** : `flutter
> analyze` (apps/mobile) = **PASS** (exit 0, 0 issue) ; `flutter test` = **exit 1 — 113 réussis / 15 échoués**,
> les 15 échecs = **crash de compilation `google_fonts` sous Dart 3.12.2 local** (artefact d'outillage, **pas**
> des défauts de logique) → vrai run `[À EXÉCUTER]` sous SDK épinglé 3.27.4 ; `dart format` = exit 1 (83/214,
> artefact de version, **aucun fichier réécrit**). `[À EXÉCUTER]` : suite mobile sous Flutter 3.27.4 épinglé,
> `melos run analyze`/`test` (melos absent). **Aucun changement de code** (audit only). **Prêt pour la
> Phase 8 — Contenu & tooling** sur feu vert.

---

## 2. Règles de reprise

Ces règles permettent de **reprendre l'audit sans repartir de zéro** et de garder des findings
**stables et traçables** d'une phase à l'autre.

### 2.1 Reprise d'une session

1. Lire la section **[1. État courant](#1-état-courant-de-laudit)** → identifier la **prochaine
   phase** à exécuter.
2. Lire le **[Journal des phases](#4-journal-des-phases)** → comprendre ce qui a déjà été fait et
   les validations `[À EXÉCUTER]` en attente.
3. Exécuter **une seule phase** (celle indiquée comme « prochaine »), en suivant la **discipline par
   phase** (§ 2.4).
4. Mettre à jour ce document (état courant, journal, findings, remédiation, checklist).
5. **Commit** (message clair, trailer `Co-authored-by` obligatoire) puis **STOP** + notification à
   la session créatrice. **Ne jamais enchaîner** sur la phase suivante sans feu vert explicite.

### 2.2 IDs de findings stables

- Format : **`F-P<phase>-<NN>`** où `<phase>` = numéro de la phase où le finding est **d'abord
  levé** (P1…P12) et `<NN>` = séquence à deux chiffres.
  - Exemples : `F-P2-01`, `F-P4-03`, `F-P6-05`.
- Un ID **ne change jamais** une fois attribué (même si le finding est corrigé, requalifié ou
  déplacé). S'il est corrigé, on met à jour son **statut** et sa ligne de **remédiation**, pas son
  ID.
- Les findings du **rapport précédent** utilisaient la série `D1…D18` : elle appartient à
  l'**annexe** et **n'est pas réutilisée** dans l'audit neuf. Si un problème identique est
  re-constaté, il reçoit un **nouvel ID `F-P…`** et peut *référencer* l'ancien `D…` pour mémoire.

### 2.3 Barèmes

- **Gravité** : `Critique` · `Élevée` · `Moyenne` · `Faible` · `Info`.
- **Probabilité** (d'occurrence / d'exploitation) : `Élevée` · `Moyenne` · `Faible`.
- **Statut d'un finding** : `Ouvert` · `En cours` · `Corrigé` · `Atténué` · `Accepté (risque)` ·
  `Faux positif` · `Hors périmètre`.
- **Certitude** : `[CERTAIN]` · `[PROBABLE]` · `[À VÉRIFIER]` · `[INCONNU]`.
- **Validation** : exécutée (commande + résultat) **ou** `[À EXÉCUTER]` (+ commande exacte).

### 2.4 Discipline par phase (à partir de P1)

Annoncer la phase → lister les fichiers ciblés → **rester dans le périmètre** → findings **preuves à
l'appui** (`fichier:ligne`) → correctifs **sûrs et localisés uniquement** → ajouter/mettre à jour les
tests → exécuter/documenter les validations (ou `[À EXÉCUTER]`) → mettre à jour ce doc → **commit +
checkpoint + STOP**.

**Anti-boucle** : si les mêmes fichiers sont revisités sans progrès, **stopper** et journaliser une
entrée « Blocage ou boucle » dans le [Journal des phases](#4-journal-des-phases).

### 2.5 Interdits

Inventer des preuves · changements massifs non demandés · committer des secrets · casser le
comportement existant · prétendre qu'une validation a tourné si elle ne l'a pas été · **faire
confiance aux ✅ antérieurs** sans re-vérifier l'existence réelle du code et le passage réel des
tests.

---

## 3. Plan de phases 0–12

| Phase | Intitulé | Objet | Statut |
|---|---|---|---|
| **P0** | Init & doc pilote | Archivage annexe `9c488c6` + squelette du doc pilote phasé | ✅ **Terminée** |
| **P1** | Cartographie du dépôt | Structure, modules, points d'entrée, **comptages réels**, inventaire des 14 workflows | ✅ **Terminée** |
| **P2** | CI/CD & runners | Workflows, gates bloquantes, runner self-hosted/SPOF, NAT, reproductibilité, signatures mobiles, Dependabot, protections de branche | ✅ **Terminée** |
| **P3** | Dépendances & reproductibilité | Lockfiles, pins SDK, CVE NuGet/pub/npm, SBOM | ✅ **Terminée** |
| **P4** | Backend critique | Auth/middleware, Cosmos (ETag/idempotence/concurrence/transactions), server-authoritative, économie de jeu, anti-triche | ✅ **Terminée** |
| **P5** | Sécurité applicative | Bypass auth dev, secrets, CORS, rate limiting, gestion d'erreurs, surface d'attaque, stockage jetons mobile | ✅ **Terminée** |
| **P6** | Azure / IaC (6A–6F) | Cosmos, Key Vault, Storage, Function App, réseau, observabilité infra ; durcissement data-plane, purge protection, endpoints privés | ✅ **Terminée** |
| **P7** | Flutter mobile | Archi feature-first, Riverpod/go_router, offline engine, écrans vs API, secure storage, a11y, couverture tests | ✅ **Terminée** |
| **P8** | Contenu & tooling | Schémas JSON, validateur contenu, seed, séparation `answerKey` | ⏳ |
| **P9** | Observabilité / ops | App Insights, correlation IDs, `/health`, alertes, crash reporting mobile, rétention, runbooks | ⏳ |
| **P10** | Release engineering | Pipelines release, gates d'approbation, SBOM/provenance, rollback, versioning/tags | ⏳ |
| **P11** | Cohérence documentaire | README/ARCHITECTURE/ETAT vs code réel, chiffres, promesses « IA »/parité Cortex/offline | ⏳ |
| **P12** | Rapport de synthèse final | Executive summary, scorecard, priorisation, roadmap, conclusion franche (7 questions) | ⏳ |

### Commandes de validation de référence (par domaine)

À exécuter **quand disponible** ; sinon marquer `[À EXÉCUTER]` avec la commande.

- **Dart / Flutter** : `dart format --line-length 100 --set-exit-if-changed .` · `melos bootstrap` ·
  `melos run analyze` · `melos run test` · `flutter analyze` · `flutter test`.
- **.NET** : `dotnet restore` · `dotnet build -warnaserror` · `dotnet test`.
- **Node / contenu** : `npm ci` · `npm audit` · `node tools/validate_content.mjs`.
- **IaC** : `az bicep build --file infra/main.bicep` · `checkov --framework bicep --directory infra`.

---

## 4. Journal des phases

> Une entrée horodatée par phase. Les validations réellement exécutées sont distinguées des
> `[À EXÉCUTER]`.

### P0 — Init & document pilote · 2026-07-03 23:51 (+01:00) · commit `90cc431`

**Objet.** Initialiser l'audit neuf : cadrer via les docs principaux, **archiver intégralement** le
rapport précédent, **(re)construire** ce document pilote phasé. **Aucun changement de code.**

**Actions réalisées.**

1. **Cadrage (lecture, sans audit)** — inventaire de la racine et lecture légère des documents de
   cadrage. Constats structurels observés (pour cadrage uniquement, **non audités**, à re-vérifier
   en P1+) :
   - Racine : `apps/`, `backend/`, `content/`, `docs/`, `infra/`, `packages/`, `tools/`,
     `README.md`, `SECURITY.md`, `melos.yaml`, `analysis_options.yaml`, `package.json`,
     `package-lock.json`, `codemagic.yaml`, `.checkov.yaml`. **[CERTAIN]**
   - `docs/` contient : `ARCHITECTURE.md`, `CONFIG_AUTH.md`, `deployment-runbook.md`,
     `E2E_AUTH_PREREQUIS.md`, `ETAT_DU_PROJET.md`, `GUIDE_ACTIVATION_AUTH_ANDROID.md`,
     `RELEASE_MOBILE.md`, `legal/`. **[CERTAIN]**
   - `.github/workflows/` contient **14 fichiers** : `cd-backend.yml`, `ci-backend.yml`,
     `ci-content.yml`, `ci-infra.yml`, `ci-mobile.yml`, `codeql.yml`, `dependency-vuln-scan.yml`,
     `deploy-privacy-policy.yml`, `lint-workflows.yml`, `promote-backend-staging-prod.yml`,
     `release-android.yml`, `release-ios.yml`, `security-scan.yml`, `sync-ios-certs.yml`.
     **[CERTAIN]** *(le README n'en documente que ~9 dans son tableau CI — écart à instruire en
     P2/P11).* **[À VÉRIFIER]**
   - `melos.yaml` : packages `apps/*` + `packages/*` ; scripts `analyze` (`dart analyze
     --fatal-infos`), `test` (`flutter test`), `e2e`, `format`/`format-check` (ligne 100), `gen`
     (`build_runner`). **[CERTAIN]**
   - Le README annonce **89 certifications Microsoft actives**, moteur **Cortex** (FSRS/mastery)
     partagé Dart/.NET, design **Prism**, gamification **Momentum**, contenu **content-as-code**,
     runner **self-hosted** `[self-hosted, Linux, X64, certigo-ci]` + **NAT Gateway** `nat-certigo`.
     *(Toutes ces promesses seront confrontées au code réel en P1–P11.)* **[PROBABLE]**

2. **Archivage du rapport précédent** — copie **byte-for-byte** de l'ancien `AUDIT_Certigo.md` vers
   [`AUDIT_Certigo_annexe_9c488c6.md`](AUDIT_Certigo_annexe_9c488c6.md).
   - Vérifié identique : **58 713 octets** en source comme en copie ; **735 lignes**. **[CERTAIN]**
   - Contenu préservé : sections **A → M**, dont la **Section M « Remédiation appliquée »** avec le
     tableau **D1–D18** et les mentions de tests (« 322/323 tests »). Ancré sur `9c488c6`.
     **[CERTAIN]** *(Ces ✅ antérieurs ne sont **pas** repris pour argent comptant : ils seront
     re-vérifiés à partir de P1.)*

3. **(Re)construction du doc pilote** — ce fichier `AUDIT_Certigo.md` réécrit au format phasé
   (squelette 8 parties : état courant · règles de reprise · plan P0–P12 · journal · findings ·
   remédiation · checklist · annexe). Ancrage de l'audit neuf : `cdd8f30`.

**Findings produits.** Aucun (phase d'initialisation, sans audit).

**Validations.** Aucune commande de build/test/lint requise ni exécutée en P0 (init documentaire).
Les commandes de validation par domaine sont listées au § 3 et seront exécutées **ou** marquées
`[À EXÉCUTER]` dès P1+.

**Écarts notés pour phases ultérieures (à instruire, non conclusifs) :**
- `[À VÉRIFIER]` **14 workflows** présents vs **~9** documentés dans le tableau CI du README → P2 &
  P11.
- `[À VÉRIFIER]` README « 89 certifications actives » vs comptage réel du dossier `content/` → P1 &
  P8 & P11.
- `[À VÉRIFIER]` Réalité du runner self-hosted / NAT Gateway (hors-dépôt, infra) → P2 & P6.

**Résultat.** ✅ Phase 0 terminée. **Prochaine : Phase 1 — Cartographie du dépôt.**

---

### P1 — Cartographie du dépôt · 2026-07-04 00:07 (+01:00) · commit `3b5dd04` · addendum `88ae5aa`

**Objet.** Établir la **carte réelle et chiffrée** du monorepo (inventaire factuel, **PAS** encore
d'audit qualité/sécurité). **Aucun changement de code.** Cartographie effectuée sur l'état du dépôt
à **`90cc431`** (HEAD après P0). **Zéro confiance aux ✅ de l'annexe** : existence du code et
comptages re-vérifiés sur le code réel.

**Méthode & outillage.** `git ls-files` (fichiers suivis) ; comptages LOC via PowerShell
(`Get-Content <fichier> | Measure-Object -Line`) car **`cloc` est absent** de l'environnement
(→ `[À EXÉCUTER]` ci-dessous) ; `git grep -c` / `git ls-files` (tests & contenu) ; `git show
HEAD:<workflow>` (extraction réelle de `runs-on:` et `on:`) ; lecture directe des manifestes et des
points d'entrée.

#### A. Arborescence & fichiers par dossier top-level — **[CERTAIN]**

Racine → `apps/`, `backend/`, `content/`, `docs/`, `infra/`, `packages/`, `tools/`,
`.github/`, `.vscode/` + fichiers racine (`README.md`, `SECURITY.md`, `melos.yaml`,
`analysis_options.yaml`, `package.json`, `package-lock.json`, `codemagic.yaml`, `.checkov.yaml`,
`AUDIT_Certigo.md`, `AUDIT_Certigo_annexe_9c488c6.md`, …).

| Dossier | Fichiers suivis |
|---|---|
| `content/` | 239 |
| `apps/` | 187 |
| `backend/` | 161 |
| `packages/` | 117 |
| `.github/` | 16 |
| `infra/` | 16 |
| `docs/` | 8 |
| `tools/` | 4 |
| `.vscode/` | 2 |
| racine (fichiers) | ~13 |
| **Total (`git ls-files`)** | **763** |

#### B. Modules / packages & manifestes — **[CERTAIN]**

| Module | Techno | Manifeste | Rôle apparent *(à auditer en phases dédiées)* |
|---|---|---|---|
| `apps/mobile` | Flutter/Dart | `pubspec.yaml` (v0.1.0+1) | App mobile : bootstrap Riverpod, go_router, **27 écrans** feature-first, offline sync |
| `packages/prism_ui` | Flutter/Dart | `pubspec.yaml` | Design system « **Prism** » (composants, thème, google_fonts) |
| `packages/core` | Dart pur | `pubspec.yaml` | Primitives `Result`/`Failure`, config d'env (**leaf**, sans dépendance) |
| `packages/cortex` | Dart pur | `pubspec.yaml` | Moteur « **Cortex** » spaced-repetition / readiness (FSRS-inspiré) |
| `packages/data` | Dart | `pubspec.yaml` | Modèles JSON + client **Dio** + repositories (accès API) |
| `backend` | .NET 8 isolated | 8× `*.csproj` | Azure Functions (`Api`) + Clean Arch (`Application`/`Domain`/`Infrastructure`) + 4 projets de test |
| `infra` | Bicep | `main.bicep` + 11 modules | IaC Azure (Cosmos, Key Vault, Storage, Function App, réseau, observabilité) |
| `content` | YAML content-as-code | `schema/*.json` (2 schémas) | **91** certifications (`track.yaml`) + **146** leçons (`*.lesson.yaml`) |
| `tools` | Node + Python + PowerShell | `package.json` (racine) | `validate_content.mjs` (ajv), `seed_content.py`, secrets Key Vault (PS1) |
| `.github/workflows` | GitHub Actions | 14 YAML | CI/CD backend, mobile, contenu, infra, sécurité, releases |
| `docs` | Markdown | — | 8 docs (ARCHITECTURE, ETAT_DU_PROJET, runbooks, guides auth, legal) |

#### C. Comptages réels — fichiers & LOC — **[CERTAIN]** *(cloc absent → PowerShell)*

**Par extension** (top) :

| Ext | Fichiers | LOC |
|---|---:|---:|
| `.dart` | 214 | 26 858 |
| `.cs` | 150 | 17 182 |
| `.yaml` | 248 | 9 288 |
| `.yml` | 15 | 1 450 |
| `.bicep` | 12 | 1 137 |
| `.json` | 11 | 639 |
| `.py` | 1 | 150 |
| `.bicepparam` | 3 | 124 |
| `.mjs` | 1 | 104 |
| `.ps1` | 1 | 91 |
| `.swift` | 2 | 21 |
| `.kt` | 1 | 3 |
| **Σ code/config** | — | **≈ 57 047** |

**Par module** (LOC / taille texte) : `apps` 20 400 / 837 KB · `backend` 17 439 / 774 KB ·
`packages` 11 174 / 397 KB · `content` 8 957 / 335 KB · `docs` 2 030 / 140 KB · `.github` 1 453 /
69 KB · `infra` 1 340 / 66 KB · `tools` 438 / 24 KB.

#### D. Points d'entrée (`fichier:ligne`) — **[CERTAIN]**

| Couche | Élément | `fichier:ligne` |
|---|---|---|
| Mobile — main | `Future<void> main() => bootstrap();` | `apps/mobile/lib/main.dart:5` |
| Mobile — composition root | `bootstrap()` (garde config `AppEnv.validate()` L29-34 ; `ProviderScope`+`OfflineSyncScope`+`CertigoApp` L54-62) | `apps/mobile/lib/bootstrap/bootstrap.dart:20` |
| Mobile — crash handler | `FlutterError.onError` (**TODO** : non relié à App Insights → lead P9) | `apps/mobile/lib/bootstrap/bootstrap.dart:42` |
| Router | `abstract class Routes` L43 · `routerProvider = Provider<GoRouter>` L108 · `GoRouter(` L139 | `apps/mobile/lib/app/router.dart` |
| Backend — host | `new HostBuilder().ConfigureFunctionsWorkerDefaults(...)` L23 · middleware L30-32 (`SecurityHeaders`→`Exception`→`JwtAuth`) · `host.Run()` L203 | `backend/src/Certigo.Api/Program.cs:23` |
| Melos | scripts `analyze`/`test`/`e2e`/`format`/`gen` | `melos.yaml` |
| Tools — contenu | validateur ajv | `tools/validate_content.mjs` |
| Infra | orchestrateur IaC | `infra/main.bicep` |

#### E. Endpoints backend — **34 fonctions HTTP** dans **19 fichiers** `Functions/*.cs` — **[CERTAIN]**

| Fichier `Functions/*.cs` | Endpoints (`nom:ligne`) |
|---|---|
| `AuthFunctions` | Register:15, Login:35, RefreshToken:50, VerifyEmail:65, ResendVerification:84 |
| `AchievementFunctions` | GetAchievements:10 |
| `ExamFunctions` | GenerateMockExam:11, SubmitMockExam:22 |
| `FriendFunctions` | GetFriends:12, AddFriend:22, RemoveFriend:34, GetFriendLeaderboard:45 |
| `HealthFunctions` | Health:16 |
| `CatalogFunctions` | GetCatalog:10 |
| `LeaderboardFunctions` | GetMyLeague:10, GetMyLeagueResolution:20 |
| `NotificationFunctions` | GetNotificationPlan:17, GetNotificationSettings:27, UpdateNotificationSettings:37 |
| `LessonFunctions` | GetLesson:10 |
| `PathFunctions` | GetMyPath:10 |
| `QuestFunctions` | GetQuests:11, ClaimQuest:21 |
| `QuizFunctions` | SubmitQuiz:11 |
| `RecommendationFunctions` | GetNextBest:10 |
| `SeasonFunctions` | GetSeason:11, ClaimSeason:21 |
| `ShareCardFunctions` | GetDailyShareCard:10 |
| `ShopFunctions` | GetShop:11, PurchaseShopItem:21 |
| `StreakFunctions` | GetStreakStatus:12, RepairStreak:22 |
| `UserFunctions` | GetMe:10 |
| `TutorFunctions` | ExplainAnswer:15 |

#### F. Graphe de dépendances inter-modules — **[CERTAIN]** *(d'après manifestes)*

- **Dart** : `core` (**leaf**) ← `cortex`, ← `data` (+ `dio`) ; `prism_ui` indépendant
  (flutter + google_fonts) ; `apps/mobile` → { `prism_ui`, `core`, `data`, `cortex` } +
  riverpod / go_router / appauth / secure_storage.
- **.NET** : `Domain` (**leaf**) ← `Application` ← { `Infrastructure`, `Api` } ; `Domain` ←
  `Infrastructure` ; `Api` → { `Application`, `Infrastructure` }. **Clean Architecture respectée**
  (Domain sans dépendance sortante).

#### G. Frameworks / dépendances majeures (preuve manifestes) — **[CERTAIN]**

- **Dart** (`apps/mobile/pubspec.yaml`) : `flutter_riverpod ^2.5.1` (**providers classiques — 0
  `@riverpod`**), `go_router ^14.2.0`, `flutter_appauth ^8.0.0` (OIDC+PKCE), `flutter_secure_storage
  ^9.2.2`, `dio` (via `data`, `^5.7.0`), `font_awesome_flutter 10.7.0` **épinglé** *(commentaire :
  10.8+ exige Flutter 3.27, CI SDK=3.24)*, shared_preferences, connectivity_plus, confetti,
  share_plus, `flutter_local_notifications ^17.2.0`, timezone.
- **.NET** : `Microsoft.Azure.Functions.Worker 1.24.0` + `Sdk 1.18.1` (Api, isolated `Exe`),
  **`Microsoft.Azure.Cosmos 3.61.0`** (Infrastructure), `Azure.Identity 1.21.0`,
  `Azure.Communication.Email 1.0.1`, `ApplicationInsights 2.23.0`,
  `System.IdentityModel.Tokens.Jwt 8.19.1`, **`Microsoft.Bcl.Memory 10.0.9`** *(pin sécurité —
  commentaire « CVE-2026-26127 » → lead P3)*.
- **Node** (`package.json` racine) : `ajv ^8.20.0`, `ajv-formats ^3.0.1`, `glob ^13.0.6`,
  `yaml ^2.9.0`. ⚠️ `name: "gchambaud-microsoft-improved-guide"` *(nom générique de scaffold, pas
  « certigo »)* + `test` = `echo "Error: no test specified" && exit 1` → lead P11.

#### H. Tests — **[CERTAIN]** *(comptage ; passage réel non exécuté)*

| Stack | Fichiers de test | Cas |
|---|---|---|
| .NET | **63 `*Tests.cs`** (Api.Tests 23, Application.Tests 18, Domain.Tests 18, Infrastructure.Tests 4) + 7 helpers = 70 `.cs` | **430 `[Fact]`/`[Theory]` + 128 `[InlineData]`** |
| Dart | **54 `*_test.dart`** | **310 `test()`/`testWidgets()`** |

Passage réel des tests **non exécuté** en P1 → `[À EXÉCUTER]` (`dotnet test`, `flutter test`).

#### I. Contenu — **[CERTAIN]**

`content/` = un dossier par certification (`track.yaml` + `lessons/*.lesson.yaml`). **91 `track.yaml`**,
**146 `*.lesson.yaml`**, 2 schémas (`content/schema/{lesson,track}.schema.json`). 5 fondamentaux
(dp-900, ai-900, sc-900, az-104, az-900) = 13 fichiers chacun ; la plupart des autres = 2.
⚠️ README « **89 certifications actives** » (`README.md:8` & `:62`) vs **91** `track.yaml` réels →
**écart +2**, lead P8/P11 `[À VÉRIFIER]`.

#### J. Inventaire exhaustif des **14 workflows** `.github/workflows/*` — **[CERTAIN]** (runners) / **[PROBABLE]** (triggers, grep mots-clés)

| Workflow | Octets | Triggers `on:` | Runner `runs-on:` | But apparent |
|---|---:|---|---|---|
| `cd-backend.yml` | 4101 | workflow_call, workflow_dispatch, push | self-hosted `certigo-ci` (via `vars.MAIN_CRITICAL_RUNNER_LABELS`) | Déploiement backend (CD) |
| `ci-backend.yml` | 4995 | push, pull_request, workflow_dispatch | self-hosted `certigo-ci` (**fallback** `ubuntu-latest` via `vars.BACKEND_CI_FALLBACK`) | CI backend .NET |
| `ci-content.yml` | 1925 | push, pull_request, workflow_dispatch | self-hosted `certigo-ci` (`vars.PR_RUNNER_LABELS`) | CI validation contenu YAML |
| `ci-infra.yml` | 2473 | push, pull_request, workflow_dispatch | self-hosted `certigo-ci` | CI infra Bicep |
| `ci-mobile.yml` | 7678 | push, pull_request, workflow_dispatch | self-hosted `certigo-ci` | CI mobile Flutter |
| `codeql.yml` | 1516 | schedule, workflow_dispatch | self-hosted `certigo-ci` | Analyse SAST CodeQL |
| `dependency-vuln-scan.yml` | 7831 | schedule, pull_request, workflow_dispatch | self-hosted `certigo-ci` | Scan vulnérabilités dépendances |
| `deploy-privacy-policy.yml` | 3049 | workflow_dispatch | self-hosted `certigo-ci` | Publication politique de confidentialité |
| `lint-workflows.yml` | 1729 | pull_request | self-hosted `certigo-ci` | Lint des workflows Actions |
| `promote-backend-staging-prod.yml` | 549 | workflow_dispatch | **aucun `runs-on:`** *(reusable/dispatch ? `[À VÉRIFIER]` P2)* | Promotion backend staging→prod |
| `release-android.yml` | 13426 | push, release, workflow_dispatch | **hard-codé** `[self-hosted, Linux, X64, certigo-ci]` | Release Android (build/signature/publication) |
| `release-ios.yml` | 12998 | release, workflow_dispatch | **hard-codé** `[self-hosted, macOS]` | Release iOS |
| `security-scan.yml` | 2956 | schedule, workflow_dispatch | self-hosted `certigo-ci` | Scan sécurité programmé |
| `sync-ios-certs.yml` | 3719 | workflow_dispatch | **hard-codé** `[self-hosted, macOS]` | Synchronisation certificats iOS |

**14 workflows confirmés** ; README documente **~9** → écart de doc, lead P2/P11 `[À VÉRIFIER]`.
**13/14 sur runner self-hosted** (`certigo-ci` Linux ou macOS) → **SPOF / NAT** à auditer en P2/P6.

#### K. Fichiers volumineux notables & **mythe du god-file** — **[CERTAIN]**

Top fichiers source : `profile_screen.dart` 34 582 o · `auth_controller_test.dart` 32 561 o ·
`Tutor.cs` (Domain) 23 477 o · `sign_in_screen.dart` 21 202 o · `exam_screen.dart` 20 537 o ·
`CosmosRepositories.cs` 20 370 o · `quiz_screen.dart` 20 161 o · `path_screen.dart` 19 174 o.

**Top 5 des plus gros fichiers `.cs` du backend** (`chemin | octets | lignes`) — re-mesuré sur
`backend/src` (`Get-ChildItem backend\src -Recurse -Filter *.cs | Sort-Object Length -Descending`) :

| # | Chemin | Octets | Lignes |
|---|---|---|---|
| 1 | `backend/src/Certigo.Domain/Tutor/Tutor.cs` | 23 477 | 550 |
| 2 | `backend/src/Certigo.Infrastructure/Cosmos/CosmosRepositories.cs` | 20 370 | 402 |
| 3 | `backend/src/Certigo.Application/Services/AuthService.cs` | 19 348 | 387 |
| 4 | `backend/src/Certigo.Application/Services/QuizService.cs` | 18 560 | 358 |
| 5 | `backend/src/Certigo.Application/Services/ExamService.cs` | 18 469 | 370 |

*(6–8 : `GamificationServices.cs` 18 070 o / 395 L · `LearningServices.cs` 17 600 o / 401 L ·
`Dtos.cs` 16 125 o / 475 L.)* **[CERTAIN]**

⚠️ **Mythe du god-file `Services.cs` ~96 KB — INFIRMÉ.** **Aucun fichier nommé exactement
`Services.cs`** dans tout `backend/` (vérifié : `Get-ChildItem backend -Recurse -Filter Services.cs`
→ **0 résultat**). Les services applicatifs sont **décomposés en 11 fichiers** dans
`backend/src/Certigo.Application/Services/` : `AuthService` 19 348 o · `QuizService` 18 560 ·
`ExamService` 18 469 · `GamificationServices` 18 070 · `LearningServices` 17 600 ·
`NotificationService` 9 786 · `TutorService` 9 226 · `SocialServices` 8 141 · `LeaderboardService`
4 494 · `ContentService` 2 254 · `UserService` 1 124 (≈ 127 KB au total, bien répartis). *(Ne pas se
fier au ✅ antérieur de l'annexe : re-vérifié sur le code réel.)*

**Finding structurel produit : `F-P1-01`** (ex-god-file éclaté → **à instruire en P4**, cf. § 5). Le
fractionnement est *a priori* un **point positif**, mais reste un **lead `[À VÉRIFIER]`** : il faut
confirmer en P4 que la séparation des responsabilités est réelle (pas de couplage résiduel ni de
dépendances croisées entre services) et que `Tutor.cs` (550 L) et `CosmosRepositories.cs` (402 L) ne
concentrent pas une complexité critique. Les autres écarts restent des **leads non conclusifs** routés
vers les phases dédiées (tableau ci-dessous).

**Validations.**
- **Exécutées [CERTAIN]** : `git ls-files` (763 fichiers) ; comptages LOC PowerShell
  (`Get-Content | Measure-Object -Line`) ; `git grep -c` / `git ls-files` (tests & contenu) ;
  `git show HEAD:<workflow>` (`runs-on:` / `on:`).
- **Non exécutées → `[À EXÉCUTER]`** :
  - `cloc --vcs=git .` *(outil **absent** ; LOC obtenues via PowerShell à la place)*.
  - `dotnet build -warnaserror` · `dotnet test` *(backend — non lancés en P1)*.
  - `flutter analyze` · `flutter test` · `melos run test` *(mobile — non lancés en P1)*.
  - `node tools/validate_content.mjs` *(contenu — non lancé en P1)*.

**Écarts / leads pour phases ultérieures (à instruire, non conclusifs) :**

| Lead | Preuve | Certitude | → Phase |
|---|---|---|---|
| 14 workflows vs ~9 documentés (README) | `.github/workflows/` (14) vs tableau CI README | `[À VÉRIFIER]` | P2 / P11 |
| 13/14 workflows sur runner self-hosted `certigo-ci` (+ macOS) | `runs-on:` extraits (§ J) | `[CERTAIN]` (SPOF à évaluer) | P2 / P6 |
| ~~`promote-backend-staging-prod.yml` sans `runs-on:`~~ **→ INFIRMÉ en P2** (`F-P2-09`) : workflow **appelant** (`uses:`), pas de `runs-on` requis | `promote-backend-staging-prod.yml:17,25` | `[CERTAIN]` | P2 ✅ clos |
| Absence de `global.json` (SDK .NET non épinglé) | racine sans `global.json` | `[À VÉRIFIER]` | P3 |
| Pin `Microsoft.Bcl.Memory 10.0.9` « CVE-2026-26127 » | `Certigo.Infrastructure.csproj` | `[À VÉRIFIER]` | P3 |
| README « 89 certifications » vs 91 `track.yaml` | `README.md:8`,`:62` vs `content/` | `[À VÉRIFIER]` | P8 / P11 |
| `package.json` name générique + `test` factice | `package.json` racine | `[CERTAIN]` (cohérence) | P11 |
| `FlutterError.onError` non relié à App Insights (TODO) | `bootstrap.dart:42` | `[CERTAIN]` (observabilité) | P9 |
| Riverpod « classique » (0 `@riverpod`) | `pubspec.yaml` + code | `[CERTAIN]` (style) | P7 |
| `CosmosRepositories.cs` (ETag / concurrence / idempotence) | `backend/.../CosmosRepositories.cs` | `[À VÉRIFIER]` | P4 |
| `CompositeTokenValidator` (Local + Dev/Entra) — bypass dev ? | `Program.cs:71-110` | `[À VÉRIFIER]` | P5 |

**Résultat.** ✅ Phase 1 terminée. **Prochaine : Phase 2 — CI/CD & runners.**

---

### P2 — CI/CD & runners · 2026-07-04 00:41 (+01:00) · commit `9efd36a`

**Objet.** Audit de fond des **14 workflows** `.github/workflows/` : gates bloquantes réelles,
runners/SPOF, secrets/OIDC, moindre privilège, concurrence/environnements, reproductibilité/supply
chain, scans sécurité (bloquants vs informatifs), `lint-workflows`, cohérence README. **Aucun
changement de code** (findings + correctifs **décrits** uniquement).

**Périmètre lu (14/14, `[CERTAIN]`).** `cd-backend.yml`, `ci-backend.yml`, `ci-content.yml`,
`ci-infra.yml`, `ci-mobile.yml`, `codeql.yml`, `dependency-vuln-scan.yml`, `deploy-privacy-policy.yml`,
`lint-workflows.yml`, `promote-backend-staging-prod.yml`, `release-android.yml`, `release-ios.yml`,
`security-scan.yml`, `sync-ios-certs.yml`.

**Constats par point de périmètre (preuves `fichier:ligne`) :**

1. **Gates de qualité — majoritairement bloquantes ✓.**
   - Backend : `ci-backend.yml:80` `dotnet build … -warnaserror` + `ci-backend.yml:83` `dotnet test` →
     **bloquants** `[CERTAIN]`.
   - Mobile : `ci-mobile.yml:93` `dart analyze --fatal-infos`, `:96` `dart test`, `:157`
     `dart format --set-exit-if-changed`, `:166` `flutter analyze`, `:169` `flutter test --coverage` →
     tous **bloquants** `[CERTAIN]`. **Mais** couverture uploadée `:171` `continue-on-error: true`, **sans
     seuil** → `F-P2-06`.
   - Contenu : `ci-content.yml:40` `node tools/validate_content.mjs` **bloquant** ✓ ; **mais** `:42`
     `npm audit … || true` et `:44` `pip check … || true` **non bloquants**, install `:38`
     `npm install --no-save` (pas `npm ci`) → `F-P2-07`.
   - Infra : `ci-infra.yml:45-53` `bicep build` ×5 **bloquants** (syntaxe seule ; sécurité IaC = Checkov
     dans `security-scan`).
   - Release : `release-android.yml:134` `flutter analyze` + `:138` `flutter test` **avant** signature/
     publication ✓ ; idem `release-ios.yml:194,198` (workflow désactivé).

2. **Runners / SPOF → `F-P2-01` (Élevée).** 13/14 workflows visent `certigo-ci` self-hosted. Motif
   Linux via expression `${{ vars.PR_RUNNER_LABELS && fromJSON(…) || fromJSON('["self-hosted","Linux","X64","certigo-ci"]') }}`.
   `release-android.yml:70` **hardcode** `[self-hosted, Linux, X64, certigo-ci]` (aucun fallback).
   **Seul** `ci-backend.yml:65` a un vrai fallback GitHub-hosted (`vars.BACKEND_CI_FALLBACK == 'true' &&
   'ubuntu-latest'`) → **confirme le lead P1** mais **uniquement pour `ci-backend`**. GitHub-hosted
   **désactivés org-wide** (EMU) : `dependency-vuln-scan.yml:19-21`, `lint-workflows.yml:4`.
   `release-ios.yml:68` + `sync-ios-certs.yml:42` = `[self-hosted, macOS]` (2 workflows **désactivés**).

3. **`promote-backend-staging-prod.yml` sans `runs-on:` → `F-P2-09` (lead P1 INFIRMÉ).** C'est un
   **workflow appelant** : `promote-backend-staging-prod.yml:17,25` `uses: ./.github/workflows/cd-backend.yml`.
   Un job `uses:` **ne porte pas** de `runs-on` (c'est l'appelé qui le définit). **Pas un défaut.**

4. **Secrets & OIDC — bon ✓.** `cd-backend.yml:51,94` `azure/login@v3` avec `client-id`/`tenant-id`/
   `subscription-id` + `id-token: write` (`:43,74`) → **OIDC, pas de secret Azure long-vivant** `[CERTAIN]`.
   **Aucun `pull_request_target`** dans le repo `[CERTAIN]`. Signature mobile : secrets tirés de Key
   Vault (identité managée) avec fallback GH-secret, masqués `::add-mask::` (`release-android.yml:173`,
   `release-ios.yml:136`). Réserve mineure : certains secrets écrits dans `$GITHUB_ENV` (masqués).

5. **Moindre privilège — bon ✓.** La plupart des workflows déclarent `permissions: contents: read` en
   tête. Élévations justifiées : `codeql.yml:22-25` `security-events: write` ; `dependency-vuln-scan.yml:39-41`
   `security-events: write` ; `deploy-privacy-policy.yml:11-14` `pages: write` + `id-token: write`.

6. **Concurrence & environnements → `F-P2-08` (Moyenne, `[À VÉRIFIER]`).** Tous les workflows deploy/CI/
   release ont un bloc `concurrency:` ✓ (release `cancel-in-progress: false` correct). `cd-backend.yml:40,70`
   `environment: ${{ inputs.environment }}` → la **gate d'approbation prod** dépend des *Environment
   protection rules* GitHub **non observables dans le code**. `cd-backend.yml:26-27` `on: push:
   branches:[main]` → auto-deploy **dev** à chaque merge.

7. **Reproductibilité / supply chain → `F-P2-04` (SHA) + `F-P2-05` (toolchain).**
   - Épinglage : seule `dorny/paths-filter` est **SHA-pinned** (`ci-backend.yml:33`, `ci-mobile.yml:37`).
     Toutes les autres sont **tag-pinned**, dont la tierce de publication `r0adkll/upload-google-play@v1`
     (`release-android.yml:254`).
   - Toolchains épinglées : Flutter `3.27.4` (`ci-mobile.yml:19`, `release-android.yml:62`,
     `release-ios.yml:60`), Dart `3.6.0` (`ci-mobile.yml:87`), Bicep `v0.44.1` (`ci-infra.yml:40`), OSV
     `v2.4.0`, actionlint `v1.7.12`. **Mais** : **pas de `global.json`** → SDK .NET flottant `8.0.x` ; et
     **drift Flutter** `security-scan.yml:50` = **3.24.0** vs 3.27.4 ailleurs → `F-P2-05` (routé **P3**).
   - **Note d'honnêteté `[À VÉRIFIER]`** : certains tags d'actions (`actions/checkout@v7`
     `cd-backend.yml:48,77` ; `setup-dotnet@v5` `:80` ; `setup-node@v6` `ci-content.yml:34` ;
     `upload-artifact@v7` ; `codeql-action@v4`) sont **supérieurs aux majeures connues de mon cutoff** ;
     je **ne conclus pas** qu'ils sont cassés (le `main` vert suggère qu'ils résolvent) — à re-vérifier
     en P3 (`gh api repos/actions/checkout/git/refs/tags/v7`).

8. **Scans sécurité → `F-P2-02` (CodeQL) + `F-P2-03` (deps/IaC).**
   - `codeql.yml:9-12` : `schedule` + `workflow_dispatch` **only**, **pas de `pull_request`** → **ne gate
     pas les PR**. Langages `:30-35` csharp/js-ts/python ; **Dart non couvert** (`:5`, → P7).
   - `security-scan.yml:7-10` : `schedule` + `dispatch` only → **non gate PR** ; en interne hard-fail
     NuGet `:36-40` (`exit 1`) + Checkov `:77` (`.checkov.yaml`) ✓.
   - `dependency-vuln-scan.yml:26-31` : OSV `schedule` + **`pull_request`** + dispatch, **mais
     report-only strict** (`continue-on-error` + `if: always()`, ≈ `:63,80,88,100`) → tourne sur PR mais
     **ne la bloque jamais**. Binaire OSV épinglé v2.4.0 + vérif SHA256 (`:66-70`). Dependabot
     verrouillé EMU (HTTP 422) documenté (`:5-9`) ; `.github/dependabot.yml` **existe** (39 L) → inerte
     à confirmer en **P3/P11**.

9. **`lint-workflows` — bloquant ✓.** `lint-workflows.yml:33` actionlint `v1.7.12` (pinné), `:38`
   `actionlint .github/workflows/*.yml`, trigger `:8-11` `pull_request: paths: .github/workflows/**`
   → **gate les PR touchant les workflows** `[CERTAIN]`. Réserve mineure : `paths` couvre
   `.github/workflows/**` mais pas tout `.github/**`.

10. **Cohérence README (→ P11).** README documente **~9** workflows vs **14** réels → écart confirmé,
    **routé P11** (docs) ; ne pas conclure ici.

**Points positifs notables (documentés, non-findings).**
- **Fork-guard fort** : quasi tous les workflows ont `if: github.event.pull_request.head.repo.full_name
  == github.repository` + `environment: pr-ci` → **les forks ne peuvent pas toucher le runner
  self-hosted** `[CERTAIN]`. Posture de sécurité solide.
- **OIDC Azure** (cf. pt 4) : aucun secret Azure long-vivant.
- **Hygiène release** : étapes de nettoyage keychain/secrets `if: always()` (`release-android.yml:287-294`,
  `release-ios.yml:258-266`).

**Validations.**
- **Exécutées [CERTAIN]** : lecture intégrale des 14 workflows (`view`) ; `Get-Command
  actionlint,zizmor,action-validator` → **absents** ; `Test-Path .github/dependabot.yml` → **existe** (39 L).
- **Non exécutées → `[À EXÉCUTER]`** (outils absents / hors code) :
  - `actionlint .github/workflows/*.yml` *(outil **absent**)*.
  - `zizmor .github/workflows` *(outil **absent** ; audit statique OIDC/permissions)*.
  - `npx @action-validator .github/workflows/*.yml` *(non lancé)*.
  - `gh api repos/:owner/:repo/environments/prod` *(vérifier reviewers prod — `F-P2-08`)*.
  - `gh api repos/actions/checkout/git/refs/tags/v7` *(vérifier tags d'actions élevés — pt 7)*.

**Écarts / leads routés :** README ~9 vs 14 workflows → **P11** ; `global.json` absent + drift Flutter
3.24↔3.27 → **P3** (`F-P2-05`) ; Dart non couvert par CodeQL → **P7** ; `dependabot.yml` inerte
(EMU 422) → **P3/P11**.

**Résultat.** ✅ Phase 2 terminée — **8 findings** `F-P2-01…08` + **1 correction** `F-P2-09`.
**Prochaine : Phase 3 — Dépendances & reproductibilité.**

---

### P3 — Dépendances & reproductibilité · 2026-07-04 01:15 (+01:00) · commit `d9c9c6e`

**Objet.** Un checkout propre peut-il **rebuild de façon déterministe** ? Toolchains (.NET / Flutter / Node)
et packages sont-ils épinglés/verrouillés partout ? Périmètre A (.NET), B (Flutter/Dart), C (Node/Python/
tooling), D (Dependabot + tags d'actions).

**Méthode & outils RÉELLEMENT exécutés** (réseau + auth GitHub fonctionnels) :
- `dotnet restore backend/Certigo.sln` → ✅ **succès** (8 projets restaurés, **sans** lockfile).
- `dotnet list package --vulnerable --include-transitive` → ✅ **0 package vulnérable** (8 projets).
  `Bcl.Memory 10.0.9` **non signalé** par l'audit NuGet.
- `dotnet list package --outdated` → ✅ `Certigo.Api` sur **Functions Worker v1** (`Worker 1.24.0→2.52.0`,
  `Worker.Sdk 1.18.1→2.0.7`, `Worker.ApplicationInsights 1.4.0→2.51.0`) ; libs de test en retard
  (`FluentAssertions 6.12.2→8.10.0` [FA8 = licence payante, retrait possiblement délibéré],
  `coverlet.collector→10.0.1`, `Microsoft.NET.Test.Sdk→18.7.0`, `xunit.runner.visualstudio→3.1.5`).
- `flutter pub outdated` (`apps/mobile`) → ✅ deps directes une majeure derrière mais **toutes résolvables** :
  `flutter_riverpod 2.6.1→3.3.2`, `go_router 14.8.1→17.3.0`, `flutter_secure_storage 9.2.4→10.3.1`,
  `flutter_appauth 8.0.3→12.0.2`, `flutter_local_notifications 17.2.4→22.0.1`, `connectivity_plus 6.1.5→7.2.0`,
  `share_plus 10.1.4→13.2.0`, `flutter_lints 4.0.0→6.0.0` ; transitive `js 0.6.7` **discontinued**.
- **Existence des tags d'actions** via `gh api …/git/refs/tags` → ✅ `checkout` v7 **et** v4 existent,
  `setup-dotnet` v5, `setup-node` v6, `upload-artifact` v7, `codeql-action` v4 **et** v3.
  **Hypothèse « tags hallucinés → CI cassée » INFIRMÉE** → le vrai sujet est un **drift** (`F-P3-07`).

**Validations `[À EXÉCUTER]`** (outil/contexte absent — jamais prétendues lancées) :
- `melos bootstrap` / `melos run analyze|test` → **`melos` absent** localement
  (`dart pub global activate melos` requis). `[À EXÉCUTER]`.
- `dart pub outdated` → **échoue dans un package Flutter** (« Flutter SDK is not available ») ; la commande
  **correcte est `flutter pub outdated`**, **réellement exécutée** ci-dessus.
- `dotnet build backend/Certigo.sln -warnaserror` post-`global.json` ; `npm ci` ; `flutter pub get
  --enforce-lockfile` sur runner CI Flutter 3.27.4 ; `gh api repos/gchambaud_microsoft/Certigo/dependabot/alerts`
  (`F-P3-09`). Toutes `[À EXÉCUTER]`.

**Caveat de représentativité.** Local **Flutter 3.44.4 / Dart 3.12.2** > plancher app (`>=3.22`) et > CI
(3.27.4) → la résolution locale **n'est pas** celle de la CI. `[CERTAIN]`.

**Constats clés (preuves).**
- **.NET** : directs **exactement épinglés** (`Certigo.Api.csproj:12-19`, `Certigo.Infrastructure.csproj:13-21`)
  mais **aucun `global.json`**, **aucun `packages.lock.json`**, **aucun CPM** (`Directory.Packages.props`) →
  transitives non verrouillées (`F-P3-01`, `F-P3-02`).
- **Flutter** : `apps/mobile/pubspec.lock` **gitignoré** (`.gitignore:37-42`) → app livrée non verrouillée
  (`F-P3-03`, **Élevée**) ; SDK Flutter **sans source unique**, drift 3.24/3.27/3.44 (`F-P3-04`, consolide
  `F-P2-05`) ; **4** locks de packages seulement suivis (`git ls-files '**/pubspec.lock'`).
- **Node** : `package-lock.json` présent mais **contourné** par `ci-content.yml:38 npm install --no-save`
  (`F-P3-05`) ; `package.json` identité générique + test factice (`F-P3-06`).
- **Supply-chain** : drift des majeures d'actions, **aucune** épingle SHA (`F-P3-07`) ; Dependabot suspecté
  inerte (`F-P3-09`).
- **Python** : `[INCONNU]` — aucun `requirements.txt` trouvé (`git ls-files | grep requirements.txt` = vide)
  → pas d'écosystème Python à verrouiller dans `tools/`.

**Findings produits.** `F-P3-01 … F-P3-10` (§ 5). Répartition : **2 `Élevée`** (`F-P3-03`, `F-P3-04`),
**6 `Moyenne`** (`F-P3-01/02/05/07/08/09`), **2 `Faible`** (`F-P3-06`, `F-P3-10`). `F-P2-05` **instruit et
scindé** ici (→ `F-P3-01` + `F-P3-04`), **non recompté**.

**Leads routés.** Riverpod **v2** (pas v3) + go_router **14** (pas 17) + `flutter_secure_storage` majeure de
retard → **P7** (mobile) ; migration **Functions Worker v1→v2** → **P4/P9** ; CVE-2026-26127 à sourcer → **P5** ;
Dependabot inerte + écart README → **P11**.

**Résultat.** ✅ Phase 3 terminée — **10 findings** `F-P3-01…10` + `F-P2-05` instruit/scindé.
**Aucun code appliqué** (audit only). **Prochaine : Phase 4 — Backend critique.**

---

### P4 — Backend critique · 2026-07-04 01:52 (+01:00) · commit `3704c56`

**Objet.** Audit de fond du **backend .NET 8 isolated** uniquement (périmètre A–E) : (A) auth & middleware — `CompositeTokenValidator`, `JwtAuthMiddleware`, autorisation par endpoint, IDOR ; (B) persistance Cosmos — ETag/concurrence optimiste, idempotence, transactions, clés de partition, gestion 409/412/429 ; (C) logique **server-authoritative** & anti-triche — XP/gems/score/streak/leaderboard, `answerKey`, replay/forge ; (D) cohésion & complexité — clôture `F-P1-01` ; (E) impact du **Worker isolated v1** (`F-P3-08`). Transverse : validation d'entrée, surface d'erreur.

**Méthode & outils RÉELLEMENT exécutés.**
- Lecture intégrale des cœurs : `Program.cs` (282 L), `JwtAuthMiddleware`, `LocalJwtTokenValidator`, `EntraTokenValidator`, `CompositeTokenValidator`, `JwtSigningKeyGuard.cs`, `AuthValidatorSelection`, `ExceptionMiddleware.cs`, `HttpExtensions`, les 19 fichiers `Certigo.Api/Functions/*.cs` (34 endpoints), les 11 services `Certigo.Application/Services/*.cs`, `AttemptIntegrity.cs` (273 L), `Tutor.cs` (550 L), `CosmosRepositories.cs` (463 L), `Dtos.cs`, `CosmosExtensions.cs`.
- **`dotnet build backend\Certigo.sln -warnaserror`** → **✅ 0 warning / 0 erreur** (exit 0, 10 projets). `[CERTAIN]`
- **`dotnet test backend\Certigo.sln --no-build`** → **✅ 525 réussis / 0 échec / 6 ignorés** (exit 0). Détail : Domain.Tests 224✓ ; Infrastructure.Tests 23✓ / **6 ignorés** ; Api.Tests 124✓ ; Application.Tests 154✓. `[CERTAIN]`
- `grep "userId|UserId"` sur tous les `Functions/*.cs` → **0 occurrence** (preuve IDOR-safe : l'identité vient de `IUserContext.UserId`, jamais de la route/body).

**Validations `[À EXÉCUTER]`.** Les **6 tests ignorés** = intégration Cosmos (`CosmosRepositoriesIntegrationTests`), désactivés par `CosmosEmulatorSupport.cs` tant que `CERTIGO_COSMOS_TESTS≠1`. Émulateur Cosmos **absent** de l'environnement → non exécutés (aucune prétention). Commande exacte :
`$env:CERTIGO_COSMOS_TESTS="1"; $env:COSMOS_EMULATOR_ENDPOINT="https://localhost:8081"; $env:COSMOS_EMULATOR_KEY="<clé primaire émulateur>"; dotnet test "backend\Certigo.sln" --filter "FullyQualifiedName~CosmosRepositoriesIntegrationTests"` (requiert l'émulateur Cosmos en écoute ; clé bien connue publiée par Microsoft).

**Constats clés (preuves).**
- **Anti-triche serveur-autoritatif — SOLIDE ✓.** `AttemptIntegrity.cs` (273 L) : moteur **pur/déterministe**, rejet dur si `wallMs<0` (`:167-173`), contrôles de vitesse si `itemCount≥3` (`:183`), plafonds anti-farming XP sur fenêtre (`:231-248`, adossés Cosmos). Un rejet **efface toutes les récompenses**. `answerKey` **jamais expédiée au client** (`QuizService.cs:41,374-379` ; `ExamService.cs:83-84,417-422`). XP/gems/score/prix **calculés serveur** ; le client n'envoie que réponses + latence + IDs.
- **Double-dépense — INFIRMÉE ✓.** `UserProfileDto.ETag` (`Dtos.cs:38-39`, `[JsonPropertyName("_etag")]`) peuplé via `ReadOrDefaultAsync` (`CosmosExtensions.cs:16-17`), écritures conditionnelles `IfMatchEtag` (`CosmosUserRepository.UpsertAsync:37-54`) ; conflit → `ExceptionMiddleware.cs:47-52` → **HTTP 409** (échec sûr). `LeaderboardRepository.AddXpAsync:306-350` boucle de retry ETag (×3) ; `ProgressRepository.UpsertMasteryBatchAsync:142-160` **TransactionalBatch** intra-partition ; idempotence par **create atomique** (`AttemptRepository:189-202`, `ExamAttemptRepository:259-269`, `PurchaseRepository:381-393`).
- **Identité IDOR-safe ✓** (`HttpExtensions.GetUser:61-64` + DI `IUserContext` `Program.cs:154` ; 0 `userId` de requête dans les endpoints).
- **Surface d'erreur assainie ✓** (`ExceptionMiddleware` : typé→statut ; générique `:65-72`→500 **sans fuite de stack**, message neutre ; correlation-id honoré/minté `:16-21,76-90`).
- **Bypass dev NEUTRALISÉ en prod ✓** (`main.bicep:79` force `authMode` non-dev ; `AuthValidatorSelection.ShouldUseDevValidator` lève en Prod si `AUTH_MODE=dev` sauf `AUTH_ALLOW_DEV=true` ; `functionApp.bicep:147` ne pose `AUTH_ALLOW_DEV='true'` que si `authMode=='dev'`).
- **Failles instruites** : (1) résilience concurrence **incohérente** entre services d'économie → `F-P4-01` ; (2) écriture **multi-conteneurs non atomique** dans le chemin monnaie (`ShopService`/`StreakRepairService`) → `F-P4-02` ; (3) **`LocalJwtTokenValidator` (HS256) actif en prod** + clé de signature **dérivée par `guid()`** non imposée + **garde d'entropie absente** → `F-P4-03` ; (4) cohésion → `F-P4-04`.
- **`F-P1-01` — INFIRMÉ.** Aucun god-file/god-classe : `Tutor.cs` = **module de domaine cohésif** (records + moteurs statiques `TutorContextFactory/Composer/Guardrails/PromptBuilder`, sans effet de bord, testables). Reste un **détail d'organisation** (quelques fichiers regroupent plusieurs classes cohésives) → `F-P4-04` (Faible) **supersède et clôt `F-P1-01`**.
- **Worker v1 (E).** `Certigo.Api.csproj:13` = `Microsoft.Azure.Functions.Worker 1.24.0` (isolated **v1**). Impact = **cycle de vie/maintenance** (v1 en maintenance, v2 = voie d'avenir), **pas** un défaut de sécurité. Note brève ; migration = `F-P3-08` (routée P9).

**Findings produits.** `F-P4-01` (Moyenne, concurrence économie), `F-P4-02` (Moyenne, idempotence multi-conteneurs monnaie), `F-P4-03` (Élevée `[À VÉRIFIER]`, clé de signature JWT dérivée + garde faible + validateur local actif prod ; volet dérivation infra **croisé P6**), `F-P4-04` (Faible, cohésion — **clôt `F-P1-01`**).

**Leads routés.** Dérivation `guid()` de la clé de signature + `prod.bicepparam` clé vide non imposée + `enablePrivateNetworking=false` → **P6** (Azure/IaC) ; commentaire « Redis en production » (`AttemptIntegrity`) = scalabilité de la fenêtre anti-farming → **P9** ; `flutter_secure_storage` majeure de retard / Riverpod v2 / go_router 14 → **P5/P7** ; migration Worker v1→v2 → **P9**.

**Résultat.** ✅ Phase 4 terminée — **4 findings** `F-P4-01…04` + **`F-P1-01` clôturé** (superseded par `F-P4-04`). Validations **réelles** : build `-warnaserror` **PASS 0/0**, tests **525/0/6** (6 Cosmos → `[À EXÉCUTER]`). **Aucun code appliqué** (audit only). **Prochaine : Phase 5 — Sécurité applicative.**

---

### P5 — Sécurité applicative · 2026-07-04 02:46 (+01:00) · commit `b796cf5`

**Objet.** Audit de fond de la **sécurité applicative** (périmètre 1–8) : (1) auth app — flux `AUTH_JWT_SIGNING_KEY`, HS256 symétrique, `Pbkdf2PasswordHasher`, validation tokens (algo épinglé, issuer/audience/expiry), flux vérif. email ; (2) secrets committés — scan repo (code + workflows + `*.bicepparam` + `appsettings*`/`local.settings`) ; (3) CORS ; (4) rate limiting / anti-abus (login, register, submit, purchase, resend) ; (5) validation d'entrée (désérialisation, injection NoSQL, DTO/`[FromBody]`/null) ; (6) gestion d'erreurs / hygiène des logs (ni secret ni token ni bearer) ; (7) stockage jetons mobile (angle sécu repos/transit) ; (8) en-têtes de sécurité HTTP. **Périmètre strict app** (dérivation infra → P6).

**Méthode & outils RÉELLEMENT exécutés.**
- Lecture intégrale des cœurs sécu : `AuthService.cs` (453 L), `Pbkdf2PasswordHasher.cs`, `JwtTokenIssuer.cs`, `LocalJwtTokenValidator.cs`, `EntraTokenValidator.cs`, `JwtSigningKeyGuard.cs`, `AuthValidatorSelection.cs`, `SecurityHeadersMiddleware.cs`, `ExceptionMiddleware.cs`, `HttpExtensions.cs`, `AuthAbstractions.cs` ; côté infra pour tracer la clé : `functionApp.bicep`, `main.bicep`, `params/prod.bicepparam` ; côté mobile : `api_client.dart` (166 L), `session_store.dart`.
- **`git grep`** motifs secrets (clé/pwd/connection string/`AccountKey`/`BEGIN … PRIVATE KEY`) sur tout le dépôt → **aucun secret committé** ; `local.settings.json` **untracked + gitignore** confirmé ; les 3 `.bicepparam` **ne portent aucune valeur secrète** (clé prod **intentionnellement vide**). `[CERTAIN]`
- **Preuve anti-caviardage (codes-caractères PowerShell).** L'outillage **caviarde `******`** les valeurs de type bearer **à l'affichage** ; vérifié que `api_client.dart:70` = littéralement `Bearer $token` (émission de codes-caractères seulement, aucune corruption réelle). Recherche brute `-match '\*\*\*\*\*\*'` → **False** partout. **Faux positif « corruption mobile `******` » ÉCARTÉ** (artefact d'outillage, **pas** un finding).
- Requêtes Cosmos : revue de tous les `Container.GetItemQueryIterator` / `QueryDefinition` → **100 % paramétrées** (`.WithParameter(...)`), **aucune** concaténation → **injection NoSQL NÉANT**. `[CERTAIN]`

**Validations `[À EXÉCUTER]`.** Scanners de secrets **absents** de l'environnement (aucune prétention) :
- `gitleaks detect --source . --no-git` (scan arbre de travail).
- `gitleaks detect --source .` (scan historique git).
- `trufflehog filesystem .` (entropie + détecteurs vérifiés).
Build/tests .NET **non re-relancés en P5** (aucun code touché) ; résultats P4 (`-warnaserror` 0/0, tests 525/0/6) restent valides.

**Constats clés (preuves).**
- **Secrets Function App en CLAIR ✓→finding.** `functionApp.bicep:148` `AUTH_JWT_SIGNING_KEY`, `:156` `TUTOR_LLM_API_KEY`, `:164` `ACS_EMAIL_CONNECTION_STRING` injectés en `value: <param>` brut ; **0** référence `@Microsoft.KeyVault(...)` (bien que `KeyVault__Uri` posé `:158`). **Clôt le volet APP de `F-P4-03`** (la clé arrive en clair dans les app settings) → `F-P5-01` ; **remédiation = réf. Key Vault, croisée P6**.
- **Throttle par compte SEULEMENT ✓→finding.** Lockout adossé au compte (`AuthService.cs:95-98,184-220`) ; **aucun** throttle IP/global : (a) *credential stuffing* multi-comptes non freiné ; (b) `register` sans limite → inscription de masse ; (c) `ResendAsync:301-323` ré-émet jeton + envoie email **sans cooldown** → email-bombing + amplification coût ACS → `F-P5-02`.
- **Énumération inscription + timing login ✓→finding.** `register` fuit l'existence via `DuplicateRecordException` « adresse déjà utilisée » (`AuthService.cs:124,:151`) ; login : email inconnu lève **avant** PBKDF2 (`:177-180`) vs email connu = hash complet → **canal temporel** `[PROBABLE]` → `F-P5-03`. *(Message login énum-résistant `:179` + resend générique = POSITIFS.)*
- **PBKDF2 100 k itérations ✓→finding.** `Pbkdf2PasswordHasher.cs:15` = 100 000 (sous les 600 000 OWASP-2023 pour PBKDF2-HMAC-SHA256) ; sel 16 o / clé 32 o (`:13-14`) ; comparaison **temps-constant** (`:56`) → `F-P5-04`.
- **JWT sans `ValidAlgorithms` épinglé ✓→finding.** `LocalJwtTokenValidator.cs:38-48` + `EntraTokenValidator.cs:43-53` valident Issuer/Audience/SigningKey/Lifetime, `ClockSkew=2 min`, `RequireSignedTokens`, mais **n'épinglent pas** `ValidAlgorithms` (atténué : symétrique seul) → `F-P5-05` `[PROBABLE]` non exploitable en l'état.
- **Durée de vie jeton + non-révocation ✓→finding.** access **1 j** / refresh **90 j** (`JwtTokenIssuer.cs:50-51`), HS256 (`:118`), **pas de liste de révocation** → `F-P5-06`.
- **En-têtes : CSP & `no-store` absents ✓→finding.** `SecurityHeadersMiddleware.cs:18-24` pose `X-Content-Type-Options:nosniff`, HSTS `max-age=63072000; includeSubDomains`, `X-Frame-Options:DENY`, `Referrer-Policy:no-referrer` — mais **ni CSP** ni `Cache-Control:no-store` sur réponses d'auth → `F-P5-07`.
- **Cap de taille de corps non explicite ✓→finding.** `HttpExtensions.cs:43-56` `ReadJsonAsync<T>` `MaxDepth=64` (bombe de profondeur bornée) mais **aucun cap applicatif** de taille de corps (atténué par limites plateforme Flex Consumption) ; null→`BadRequestException`, JSON malformé→400 → `F-P5-08`.
- **CORS `*` dev-only ✓→finding (Info).** `main.bicep:205-206` `env=='dev' ? ['*'] : []` ; prod/staging `[]`. Mobile natif non soumis au CORS navigateur → `F-P5-09`.
- **POSITIFS prouvés** : jeton mobile **sécurisé** (`session_store.dart:22-32` Keychain/Keystore) ; en-tête `Authorization` **correct** (`api_client.dart:70` = `Bearer $token`, prouvé par codes-caractères) ; hygiène logs mobile **propre** (`:39-63` : méthode/chemin/statut/ms/erreur seulement) ; **aucun secret committé** ; injection **NoSQL NÉANT** ; erreurs **assainies** ; garde dev **dure en prod** (`AuthValidatorSelection.cs:23-30`) ; email-verif **robuste** (`AuthService.cs:261-371`).

**Findings produits.** `F-P5-01` (Moyenne, secrets Function App en clair — **clôt volet app `F-P4-03`**), `F-P5-02` (Moyenne, throttle par compte seulement), `F-P5-03` (Faible, énum. inscription + timing login), `F-P5-04` (Faible, PBKDF2 100 k), `F-P5-05` (Faible, JWT sans `ValidAlgorithms`), `F-P5-06` (Faible, durée de vie + non-révocation), `F-P5-07` (Faible/Info, ni CSP ni `no-store`), `F-P5-08` (Faible/Info, cap corps non explicite), `F-P5-09` (Faible/Info, CORS `*` dev-only).

**Leads routés.** **Remédiation `F-P5-01` = réf. Key Vault** (`@Microsoft.KeyVault(...)`) + **volet dérivation infra de `F-P4-03`** (`main.bicep:82` `guid()` + `prod.bicepparam:64-68` clé vide) + `enablePrivateNetworking` + purge protection Key Vault → **P6 (Azure/IaC)**. Upgrade `flutter_secure_storage` 9→10 (angle repro) → **P3/P7** (pas de double-comptage). Absence de scanners de secrets en CI → recoupe **P2** (`security-scan`).

**Résultat.** ✅ Phase 5 terminée — **9 findings** `F-P5-01…09` + **volet app `F-P4-03` clos** (secrets en clair confirmés). Faux positif corruption `******` **écarté** (artefact d'outillage). Validations **réelles** : `git grep` secrets **propre**, requêtes Cosmos **paramétrées**, preuve codes-caractères. `[À EXÉCUTER]` : `gitleaks`/`trufflehog` (absents). **Aucun code appliqué** (audit only). **Prochaine : Phase 6 — Azure / IaC (6A–6F).**

### P6 — Azure / IaC (6A–6F) · 2026-07-04 03:19 (+01:00) · commit `5e43e4e`

**Objet.** Audit de fond de l'**infrastructure Azure (Bicep)** sur les 6 sous-domaines : **6A** Cosmos (mode d'accès data-plane, TLS, pare-feu, backup, redondance), **6B** Key Vault (remédiation `F-P5-01` : secrets en clair → réf KV ; purge protection, RBAC, réseau), **6C** Storage (host Functions : identity-based, shared-key, TLS, accès public), **6D** Function App / réseau (`enablePrivateNetworking`, PE/VNet, httpsOnly, TLS, ftps, CORS, MI), **6E** dérivation infra de `F-P4-03` (clé JWT `guid()`), **6F** observabilité infra (App Insights, diagnostics, alertes, rétention). Périmètre strict IaC (crash-reporting mobile & corrélation applicative → P9).

**Méthode & outils RÉELLEMENT exécutés.**
- Lecture intégrale des **14 fichiers** `infra/**` : `main.bicep` (263 L) ; modules `functionApp.bicep` (247 L), `cosmos.bicep` (86 L), `keyvault.bicep` (45 L), `storage.bicep` (79 L), `appInsights.bicep` (33 L), `diagnostics.bicep` (208 L), `defender.bicep` (28 L), `policy.bicep` (32 L), `communicationEmail.bicep` (70 L), `keyVaultSecretsAccess.bicep` (40 L) ; `ci-runner/network.bicep` (155 L) ; params `dev`/`staging`/`prod.bicepparam`. Numéros de ligne vérifiés.
- **`az bicep build --file infra/main.bicep` RÉELLEMENT EXÉCUTÉE → PASS** (compilation ARM propre : **76 976 o**, **0 erreur / 0 warning**, exit 0). Contournement d'un bug d'encodage console Windows : `$env:PYTHONUTF8='1'` + `$env:PYTHONIOENCODING='utf-8'` + `--outfile` (le `--stdout` plantait sur un `→` dans une description — **pas** une erreur de syntaxe Bicep).
- Recherche exhaustive `@Microsoft.KeyVault` dans `infra/**` → **0 occurrence** (confirme les secrets en clair).

**Validations `[À EXÉCUTER]`.** Outils/accès absents (aucune prétention de les avoir lancés) :
- `checkov -d infra` (scanner IaC absent).
- `az deployment sub what-if --location <loc> --template-file infra/main.bicep --parameters infra/params/prod.bicepparam` (nécessite `az login` + réseau).
- Commandes data-plane par finding (`az cosmosdb show`, `az functionapp config appsettings list`, `az network private-endpoint list`, `az monitor …`) — cf. fiches F-P6.

**Constats clés (preuves).**
- **6E — clé JWT dérivable (le point saillant).** `main.bicep:82` `guid(subscription().id, appName, env, 'auth-jwt-signing-key')` en fallback quand la clé est vide ; `prod.bicepparam:64-68` la laisse **vide** (commentaire l'admet) → clé **recalculable** → jetons HS256 **forgeables** en prod → `F-P6-01` (**clôt le volet INFRA de `F-P4-03`**).
- **6B — secrets en clair confirmés.** `functionApp.bicep:148/156/164` = 3 secrets en `value` brut ; `keyvault.bicep` **sans** ressource `secrets` ; **0** réf `@Microsoft.KeyVault` → `F-P6-02` (**clôt la remédiation INFRA de `F-P5-01`**).
- **6A — Cosmos public sans pare-feu** (`cosmos.bicep:38` + props `:20-40`) → `F-P6-03` ; **sans `backupPolicy`/PITR** + `isZoneRedundant:false` + mono-région (`:22`/`:34`) → `F-P6-04`.
- **6D — aucun endpoint privé** (flag `enablePrivateNetworking` non fonctionnel sans PE, `main.bicep:71-72` + `prod.bicepparam:74-78`) → `F-P6-05`.
- **6F — rétention App Insights 30 j** (`appInsights.bicep:14`) → `F-P6-06` ; **diag/alertes `if(env!='dev')`** (`main.bicep:212`) + `alertEmail=''` staging (`staging.bicepparam:21`) → `F-P6-07`.
- **CI-runner — NSG vide** (`ci-runner/network.bicep:109`) → `F-P6-08` (recoupe `F-P2-01`, pas de double-comptage).
- **POSITIFS prouvés** : **Storage** durci (`storage.bicep` : `allowBlobPublicAccess:false:35`, `allowSharedKeyAccess:false:36`, `minimumTlsVersion:'TLS1_2':37`, `supportsHttpsTrafficOnly:true:38`, conteneurs `None`) ; **Function App** (`identity:SystemAssigned:98`, `httpsOnly:true:101`, `minTlsVersion:'1.2':125`, `ftpsState:'Disabled':126`, storage **identity-based** `:135`, RBAC `:179-242`) ; **Key Vault** (`enableRbacAuthorization:true:30`, `enableSoftDelete:true:31`, `enablePurgeProtection` si durci `:34`) ; **Cosmos** (`disableLocalAuth` prod `:37`, TLS 1.2 `:39`) ; **CORS `[]`** prod/staging (`main.bicep:205-206`, recoupe `F-P5-09`) ; **alertes 401/403/5xx** robustes + groupe email (`diagnostics.bicep:96-185`) ; **MCSB** en mode audit (`policy.bicep:27` `DoNotEnforce`) ; **Defender** CSPM gratuit + plans payants en prod (`defender.bicep` + `prod.bicepparam:55`) ; **`az bicep build` compile propre**.

**Findings produits.** `F-P6-01` (Élevée, clé JWT `guid()` — **clôt volet infra `F-P4-03`**), `F-P6-02` (Moyenne, 3 secrets en clair — **clôt remédiation infra `F-P5-01`**), `F-P6-03` (Moyenne, Cosmos public sans pare-feu), `F-P6-04` (Faible, Cosmos sans PITR/mono-région), `F-P6-05` (Faible, aucun endpoint privé), `F-P6-06` (Faible, rétention AI 30 j), `F-P6-07` (Faible/Info, diag/alertes dev + email staging), `F-P6-08` (Info, NSG runner vide — recoupe `F-P2-01`).

**Leads routés.** Rétention/alerting **applicatif** & crash-reporting mobile → **P9** ; chantier **réseau privé** (PE/VNet) transverse → suivi ops ultérieur ; architecture Flutter, secure storage, offline → **P7**.

**Résultat.** ✅ Phase 6 terminée — **8 findings** `F-P6-01…08` (1 Élevée, 2 Moyenne, 4 Faible, 1 Info) + **volet infra `F-P4-03` clos** (`F-P6-01`) + **remédiation infra `F-P5-01` cadrée** (`F-P6-02`). Validation **réelle** : `az bicep build` **PASS** (ARM 76 976 o, 0/0). `[À EXÉCUTER]` : `checkov -d infra`, `az deployment … what-if`. **Aucun code appliqué** (audit only). **Prochaine : Phase 7 — Flutter mobile.**

### P7 — Flutter mobile · 2026-07-04 04:03 (+01:00) · commit `ed3d921`

> **Correction (revue inter-phase, 2026-07-04) — commit `⟨backfill P8⟩`.** Retrait de `F-P7-01` (**faux positif**, artefact d'affichage `******` ; octet réel `api_client.dart:70` = `Bearer $token`, prouvé **codes-caractères**). Détail dans les constats ci-dessous.

**Objet.** Audit du **mobile Flutter/Dart** (`apps/mobile/**`, `packages/**`, `prism_ui/**`) : architecture **feature-first** (cohérence des couches présentation/domaine/données), gestion d'état & navigation (**Riverpod v2** — confirmé P3, pas v3 — + **go_router**), **offline engine** (file d'attente/sync, source-of-truth locale vs back server-authoritative — recoupe P4), **écrans vs API** (endpoints réels/existants, contrats DTO), **stockage des jetons** (`flutter_secure_storage` vs `SharedPreferences` — approfondit `F-P5-06`), **reproductibilité/SDK** (drift Flutter — recoupe `F-P3-03/04/07`), **couverture de tests** (chiffres réels), **accessibilité**. Crash-reporting/télémétrie mobile → **routé P9** (hors périmètre P7).

**Méthode & outils RÉELLEMENT exécutés.**
- Cartographie de l'arbre mobile : **106 fichiers Dart** (dont **82** sous `apps/mobile/lib`) ; lecture de 12+ fichiers critiques (`api_client.dart`, `prefs_sync_store.dart`, `bootstrap.dart`, `session_store.dart`, providers Riverpod, routeur go_router, repos/écrans). Numéros de ligne vérifiés au HEAD courant (`5e43e4e`).
- **`F-P7-01` RETIRÉ — faux positif (artefact d'affichage).** Vérif **codes-caractères** sur `git show ed3d921:packages/data/lib/src/api/api_client.dart` l.70 → octets réels = `options.headers['Authorization'] = 'Bearer $token';` (queue : `39 66 101 97 114 101 114 32 36 116 111 107 101 110 39 59` = `'Bearer $token';`). Le `'******'` vu en `git show`/`git blame` **brut** = **rédacteur d'affichage** de l'outillage (masque les chaînes de type `Bearer`), **jamais** un octet réel — **même artefact déjà écarté en P5**. **NOTE MÉTHODE** : protocole **codes-caractères OBLIGATOIRE** pour toute valeur `Authorization`/`Bearer` ; `******` = artefact d'affichage, jamais un octet réel. Piège rencontré **et corrigé** en P7.
- Comptage réel des fichiers de test : **24** (`apps/mobile`) + **29** (`packages`).
- **`flutter analyze` (apps/mobile) RÉELLEMENT EXÉCUTÉE → PASS** (exit 0, « No issues found! », ~182 s).
- **`flutter test` (apps/mobile) RÉELLEMENT EXÉCUTÉE → exit 1 : 113 réussis / 15 échoués.** Les **15 échecs** = **crash de compilation** de `google_fonts-6.2.1` (`google_fonts_variant.dart:153`) sous **Dart 3.12.2 local** (SDK trop récent) — **artefacts d'outillage, PAS des défauts de logique** ; sous SDK épinglé (Flutter 3.27.4 ≈ Dart 3.6) ils compileraient → **renforce `F-P7-02` + `F-P3-03/04`**. (Ne pas revendiquer les tests comme « réussis » : le run a **échoué**.)
- **`dart format --output=none --set-exit-if-changed --line-length 100 .` (racine) → exit 1 (83/214 fichiers).** **Dart 3.12.2 local ≫ 3.27.4 épinglé** → style « tall » divergent = **artefact de version** ; `--output=none` → **aucun fichier réécrit** (arbre propre). `[À VÉRIFIER]`, **pas** un défaut prouvé.

**Validations `[À EXÉCUTER]`.** (aucune prétention de les avoir lancées) :
- Suite mobile sous **SDK épinglé** : `cd apps/mobile && flutter test` avec Flutter **3.27.4** (lève l'artefact `google_fonts`).
- `melos run analyze` / `melos run test` (melos **absent** localement ; commandes sous-jacentes `dart analyze`/`flutter test`/`dart format` exécutées directement).
- _(sans objet)_ — le test widget ciblant l'en-tête `Authorization` visait `F-P7-01`, **retiré (faux positif)**.

**Constats clés (preuves).**
- **F-P7-01 — RETIRÉ (faux positif).** L'hypothèse « `api_client.dart:70` écrase le bearer par `'******'` » est **réfutée** par codes-caractères — l.70 réelle = `options.headers['Authorization'] = 'Bearer $token';`. **POSITIF prouvé** : l'en-tête `Authorization` est **correct** (`Bearer $token`), cohérent avec la preuve codes-caractères de **P5**. Aucun jeton factice ; aucune ligne à corriger.
- **F-P7-02 (Faible/Moyenne).** `.github/workflows/security-scan.yml:50` `flutter-version: "3.24.0"` vs `3.27.4` en CI + `pubspec.lock` **gitignoré** → build mobile **non reproductible** (recoupe `F-P3-03/04/07`).
- **F-P7-03 (Faible/Moyenne).** Étiquetage sémantique a11y **épars** (~12/82 écrans référencent `Semantics`/`semanticLabel`) + **aucun** test a11y. `[PROBABLE]`.
- **F-P7-04 (Faible/Faible).** File offline persistée **en clair** dans `SharedPreferences` — `apps/mobile/lib/app/offline/prefs_sync_store.dart:6` clé `certigo.sync.queue.v1` (**actions de jeu**, **pas** de jeton). **Positif** : le jeton OIDC est en `flutter_secure_storage`.
- **F-P7-05 (Info → P9).** Crash-reporting **non câblé** — `apps/mobile/lib/bootstrap/bootstrap.dart:42-45` (TODO). **Routé P9** (observabilité).
- **POSITIFS prouvés** : jeton OIDC en **`flutter_secure_storage`** (Keychain/Keystore) ; intercepteur **Dio** propre (`api_client.dart:39-63`) ; archi **feature-first** cohérente ; écrans consommant des **repos réels** ; **Riverpod v2** + **go_router** avec gardes de route.

**Findings produits.** `F-P7-01` **RETIRÉ — faux positif** (artefact d'affichage `******` ; octets réels `api_client.dart:70` = `Bearer $token`, prouvé codes-caractères, cohérent P5), `F-P7-02` (Faible, drift SDK + lock gitignoré — recoupe `F-P3-03/04/07`), `F-P7-03` (Faible, a11y éparse), `F-P7-04` (Faible, file offline en clair), `F-P7-05` (Info, crash-reporting non câblé — **routé P9**).

**Leads routés.** Crash-reporting/télémétrie mobile → **P9** ; durée de vie/révocation du jeton côté client (approfondit `F-P5-06`) → suivi sécu ; reproductibilité SDK (`F-P3-03/04/07`) **confirmée** par l'échec `flutter test` sous SDK non épinglé ; économie de jeu server-authoritative (`F-P4`) vs file offline (`F-P7-04`) → recoupé P4.

**Résultat.** ✅ Phase 7 terminée — **4 findings** `F-P7-02…05` (3 Faible, 1 Info) ; **`F-P7-01` retiré — faux positif** (artefact d'affichage `******` ; l.70 réelle = `Bearer $token`, prouvé codes-caractères, cohérent P5). Validations **réelles** : `flutter analyze` **PASS** (exit 0) ; `flutter test` **exit 1 — 113 réussis / 15 échoués** (échecs = artefact `google_fonts`×Dart 3.12.2, **pas** de la logique) ; `dart format` exit 1 (83/214, artefact de version, aucun fichier réécrit). `[À EXÉCUTER]` : suite mobile sous SDK épinglé 3.27.4, `melos run analyze`/`test`. **Aucun code appliqué** (audit only). **Prochaine : Phase 8 — Contenu & tooling.**

---

> Registre central des findings de l'**audit neuf** (IDs `F-P…` stables, cf. § 2.2). **Vide à l'issue
> de P0.** Les findings du rapport précédent (série `D1–D18`) restent consultables dans
> l'[annexe](#8-annexe--rapport-précédent-commit-9c488c6) mais ne sont **pas** repris ici tant qu'ils
> n'ont pas été **re-dérivés** depuis le code aux phases concernées.

> **P0** = initialisation (aucun finding). **P1** = cartographie factuelle (inventaire) : **un seul
> finding structurel** (`F-P1-01`, *Info* / `[À VÉRIFIER]`, routé **P4**) ; tous les autres écarts sont
> des **leads** non conclusifs routés vers les phases dédiées (cf. journal § 4, entrée P1 : « Écarts /
> leads pour phases ultérieures »).

> **P2** = audit CI/CD & runners : **8 findings** (`F-P2-01…08`) + **1 correction** (`F-P2-09`, lead P1
> `promote` sans `runs-on` **infirmé** — faux positif). Les correctifs P2 sont **décrits** (diff/patch
> proposé, fichiers cibles) mais **non appliqués** : la phase reste en périmètre d'audit (aucun code
> touché, cf. § 6). Répartition : 1 `Élevée` (F-P2-01), 5 `Moyenne`, 2 `Faible` ; F-P2-05 est **routé et
> instruit en P3** (reproductibilité).

> **P3** = dépendances & reproductibilité : **10 findings** (`F-P3-01…10`) — 2 `Élevée`
> (`F-P3-03` lock mobile gitignoré, `F-P3-04` drift SDK Flutter), 6 `Moyenne`, 2 `Faible`. Scans **réels**
> exécutés (`dotnet restore` ✅, `dotnet list --vulnerable` = 0, `--outdated`, `flutter pub outdated`,
> existence des tags d'actions via `gh api`) ; le reste `[À EXÉCUTER]` (cf. § 4). `F-P2-05` **scindé** ici
> (→ `F-P3-01` + `F-P3-04`, non recompté). Aucun code appliqué (audit only).

> **P4** = backend critique (.NET, **périmètre backend seul**) : **4 findings** (`F-P4-01…04`) — 1 `Élevée`
> (`F-P4-03` dérivation de la clé JWT + validateur HS256 local actif en prod), 2 `Moyenne` (`F-P4-01`
> résilience concurrence hétérogène, `F-P4-02` idempotence multi-conteneurs non atomique), 1 `Faible`
> (`F-P4-04` cohésion — **clôt `F-P1-01`**). Validations **réelles exécutées** : `dotnet build -warnaserror`
> = **0 warning / 0 erreur**, `dotnet test` = **525 réussis / 0 échec / 6 ignorés** (6 = tests Cosmos
> émulateur → `[À EXÉCUTER]`, cf. § 4). Points positifs **confirmés sur code réel** : anti-triche
> déterministe (`AttemptIntegrity.cs`), `answerKey` **jamais expédiée au client**, **double-dépense
> infirmée** (ETag/If-Match), **IDOR-safe** (identité dérivée du claim, jamais de la route), surface
> d'erreur assainie, **bypass dev neutralisé en prod**. Aucun code appliqué (audit only).

> **P5** = sécurité applicative : **9 findings** (`F-P5-01…09`) — **2 `Moyenne`** (`F-P5-01` trois
> secrets injectés **en clair** dans les app settings Function App → **clôt le volet APP de `F-P4-03`** ;
> `F-P5-02` absence de throttling IP/global, `resend`/`register` non limités), **7 `Faible`/Info**
> (`F-P5-03` énumération register + canal temporel login, `F-P5-04` PBKDF2 100k < 600k OWASP, `F-P5-05`
> `ValidAlgorithms` JWT non épinglé, `F-P5-06` jetons 1j/90j sans révocation, `F-P5-07` CSP/`no-store`
> absents, `F-P5-08` pas de plafond applicatif de corps, `F-P5-09` CORS `*` en dev seulement).
> **Aucune validation build/test relancée** (aucun code touché en P5) ; scans secrets `gitleaks`/`trufflehog`
> **absents** → `[À EXÉCUTER]` (cf. § 4). Points positifs **confirmés sur code réel** : **aucun secret
> committé**, `local.settings.json` non suivi + gitignoré, requêtes Cosmos **entièrement paramétrées**
> (pas d'injection NoSQL), **en-tête `Bearer` mobile correct** (`api_client.dart:70`, prouvé par codes de
> caractères — l'affichage `******` est un **artefact de rédaction de l'outillage**, pas une corruption du
> dépôt), **stockage jeton mobile sécurisé** (Keychain/Keystore), hygiène de logs backend + mobile propre,
> vérification e-mail robuste, erreurs assainies. **Volet INFRA de `F-P4-03`** (dérivation `guid()`,
> références Key Vault) → **croisé P6**. Aucun code appliqué (audit only).

> **P6** = Azure / IaC (6A–6F). 8 findings `F-P6-01…08` re-dérivés des **14 fichiers `infra/**`** :
> **6E** clé de signature JWT dérivable par `guid()` déterministe quand vide, laissée vide en prod (`main.bicep:82` + `prod.bicepparam:64-68` + `functionApp.bicep:57→148`) → jetons HS256 forgeables → `F-P6-01` **clôt le volet INFRA de `F-P4-03`** ;
> **6B** 3 secrets Function App en **clair** (`functionApp.bicep:148/156/164`), aucune ressource `secrets` dans `keyvault.bicep`, **0** réf `@Microsoft.KeyVault` → `F-P6-02` **clôt la remédiation INFRA de `F-P5-01`** ;
> **6A** Cosmos `publicNetworkAccess` Enabled sans pare-feu IP/VNet (`F-P6-03`), sans `backupPolicy`/PITR + mono-région (`F-P6-04`) ;
> **6D** aucun endpoint privé / intégration VNet (`F-P6-05`) ;
> **6F** rétention App Insights 30 j (`F-P6-06`), diag/alertes absents en dev + `alertEmail` staging vide (`F-P6-07`) ;
> **CI** NSG du runner vide (`F-P6-08`, recoupe `F-P2-01`).
> **Positifs prouvés** : Storage durci, Function App (MI + httpsOnly + TLS 1.2 + ftps off + storage identity-based), Key Vault (RBAC + soft-delete + purge en prod), Cosmos (`disableLocalAuth` + TLS 1.2), CORS `[]` prod/staging, alertes 401/403/5xx + groupe email, MCSB audit, Defender payant en prod. **`az bicep build` RÉELLEMENT exécutée → PASS** (ARM 76 976 o, 0/0). `checkov`/`what-if` = `[À EXÉCUTER]`. Aucun code appliqué (audit only).

### `F-P1-01` — Ex-god-file applicatif éclaté en 11 services · *Backend / Architecture*
- **Preuve** : **aucun fichier `Services.cs`** dans `backend/` (`Get-ChildItem backend -Recurse -Filter
  Services.cs` → **0 résultat**) ; les services sont répartis en **11 fichiers** sous
  `backend/src/Certigo.Application/Services/` (≈ 127 KB cumulés) — `backend/src/Certigo.Application/Services/AuthService.cs:1`,
  `.../QuizService.cs:1`, `.../ExamService.cs:1`, etc. Fichiers `.cs` les plus volumineux du backend :
  `backend/src/Certigo.Domain/Tutor/Tutor.cs:1` (23 477 o / 550 L) et
  `backend/src/Certigo.Infrastructure/Cosmos/CosmosRepositories.cs:1` (20 370 o / 402 L). Certitude : `[À VÉRIFIER]`
- **Risque réel** : le fractionnement est *a priori* sain, mais **la séparation des responsabilités
  reste à prouver** — un éclatement purement mécanique peut masquer un couplage résiduel (dépendances
  croisées entre services, logique métier concentrée dans `Tutor.cs` / `CosmosRepositories.cs`).
- **Gravité** : `Info` · **Probabilité** : `Faible`.
- **Correctif proposé** : **aucun en P1** (inventaire seul). À instruire en **P4** : graphe de
  dépendances inter-services, mesure de cohésion/couplage, revue de `Tutor.cs` et `CosmosRepositories.cs`.
- **Fichiers modifiés** : aucun (finding d'inventaire, pas de correctif).
- **Validation** : `Get-ChildItem backend -Recurse -Filter Services.cs` → 0 résultat **[CERTAIN]** ;
  mesures de tailles/lignes via `Get-ChildItem` + `Measure-Object -Line` **[CERTAIN]**. Analyse de
  cohésion/couplage **exécutée en P4** (lecture intégrale de `Tutor.cs`, `CosmosRepositories.cs`, des 11
  services + `dotnet build`/`dotnet test`).
- **Statut** : `Clôturé` — **instruit et largement infirmé en P4**. Verdict de cohésion : modules **purs et
  cohérents** (`Tutor.cs` = records + moteurs statiques de domaine ; pas de god-file de 96 KB ni de god-class).
  Le seul reliquat est un **regroupement multi-classes par fichier** (nit d'organisation, `Faible`).
  **Supersédé par `F-P4-04`** (voir fiche P4 ci-dessous). Aucun correctif code.

---

### `F-P2-01` — SPOF runner self-hosted `certigo-ci` (fallback quasi absent) · *CI-CD / Disponibilité*
- **Preuve** : 11 workflows Linux actifs ciblent `certigo-ci` via l'expression
  `${{ vars.PR_RUNNER_LABELS && fromJSON(…) || fromJSON('["self-hosted","Linux","X64","certigo-ci"]') }}` ;
  `release-android.yml:70` **hardcode** `[self-hosted, Linux, X64, certigo-ci]` (aucune expression/fallback) ;
  **seul** `ci-backend.yml:65` porte un vrai fallback GitHub-hosted (`vars.BACKEND_CI_FALLBACK == 'true' &&
  'ubuntu-latest'`) ; GitHub-hosted **désactivés org-wide** (EMU) attesté `dependency-vuln-scan.yml:19-21`,
  `lint-workflows.yml:4` ; runners macOS `release-ios.yml:68` + `sync-ios-certs.yml:42` (2 workflows
  désactivés). Certitude : `[CERTAIN]` (topologie du pool `[À VÉRIFIER]`).
- **Risque réel** : point unique de défaillance — si le pool `certigo-ci` tombe (ou est saturé/en
  maintenance), **toute la CI/CD s'arrête** (build, test, deploy, release) sans bascule GitHub-hosted
  possible (EMU). Pas d'autoscale ; secrets/état sur machine persistante = surface de maintenance.
- **Gravité** : `Élevée` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : (a) documenter la topologie/redondance du pool (nb de runners, HA) ;
  (b) généraliser le motif de fallback `BACKEND_CI_FALLBACK` aux workflows critiques (au moins CI) ;
  (c) corriger `release-android.yml:70` pour utiliser l'expression paramétrable au lieu du hardcode.
- **Fichiers à modifier** : `.github/workflows/release-android.yml`, `ci-mobile.yml`, `ci-content.yml`,
  `ci-infra.yml` (harmonisation label + fallback) ; doc runbook infra.
- **Validation** : revue manuelle `[CERTAIN]` ; test de bascule fallback `[À EXÉCUTER]`
  (`gh workflow run ci-backend.yml` avec `BACKEND_CI_FALLBACK=true`).
- **Statut** : `Ouvert`.

---

### `F-P2-02` — CodeQL (SAST) ne gate pas les Pull Requests · *CI-CD / Sécurité*
- **Preuve** : `codeql.yml:9-12` déclencheurs = `schedule` + `workflow_dispatch` **uniquement** (aucun
  `pull_request`) ; langages analysés `codeql.yml:30-35` = `csharp`, `javascript-typescript`, `python` ;
  **Dart non couvert** (commentaire `codeql.yml:5`). Certitude : `[CERTAIN]`.
- **Risque réel** : une vulnérabilité introduite par une PR (injection, désérialisation, secrets, etc.)
  **n'est pas détectée avant merge** ; elle ne remontera qu'au prochain scan planifié (fenêtre de plusieurs
  jours). SAST purement rétroactif.
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : ajouter `pull_request: { branches: [main] }` au bloc `on:` de `codeql.yml`
  (au moins pour csharp/js-ts), en gardant le `schedule` pour l'analyse complète.
- **Fichiers à modifier** : `.github/workflows/codeql.yml`.
- **Validation** : `[À EXÉCUTER]` — ouvrir une PR de test et vérifier le check CodeQL requis
  (`gh pr checks`).
- **Statut** : `Ouvert`.

---

### `F-P2-03` — Scans dépendances/IaC non bloquants sur PR · *CI-CD / Sécurité*
- **Preuve** : `security-scan.yml:7-10` = `schedule` + `dispatch` only → **ne tourne pas sur PR** (bien
  qu'en interne il hard-fail NuGet `:36-40` et Checkov `:77`) ; `dependency-vuln-scan.yml:26-31` (OSV)
  tourne **sur PR** mais en **report-only strict** (`continue-on-error` + `if: always()`, ≈ `:63,80,88,100`)
  → **ne bloque jamais** ; binaire OSV épinglé v2.4.0 + vérif SHA256 `:66-70` ✓ ; Dependabot verrouillé
  EMU (HTTP 422) `:5-9`. `.github/dependabot.yml` existe (39 L) mais **inerte** → P3/P11. Certitude :
  `[CERTAIN]`.
- **Risque réel** : une dépendance vulnérable (NuGet/pub/npm) ou une mauvaise config IaC peut **passer en
  PR sans blocage** ; la détection est différée au scan planifié. Couplé à Dependabot inerte, la chaîne
  d'alerte supply-chain est **passive**.
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : (a) ajouter un déclencheur `pull_request` (paths deps) à `security-scan.yml`
  avec au moins le check NuGet/Checkov bloquant ; (b) retirer `continue-on-error` du gate OSV dans
  `dependency-vuln-scan.yml` (garder informatif pour les autres écosystèmes si besoin).
- **Fichiers à modifier** : `.github/workflows/security-scan.yml`,
  `.github/workflows/dependency-vuln-scan.yml`.
- **Validation** : `[À EXÉCUTER]` — PR introduisant une dépendance CVE connue → vérifier l'échec.
- **Statut** : `Ouvert`.

---

### `F-P2-04` — Actions tierces non épinglées par SHA (dont publish Google Play) · *CI-CD / Supply-chain*
- **Preuve** : seule `dorny/paths-filter` est **SHA-pinned** (`ci-backend.yml:33`, `ci-mobile.yml:37`) ;
  toutes les autres actions sont **tag-pinned** (`@v3`/`@v4`/…), y compris la tierce de publication
  `r0adkll/upload-google-play@v1` (`release-android.yml:254`) et les officielles `actions/*`,
  `azure/login@v3`. Certitude : `[CERTAIN]`.
- **Risque réel** : un tag mutable peut être **re-pointé** (compromission de l'action amont ou du mainteneur)
  → exécution de code arbitraire dans un pipeline qui **signe/publie l'app** et détient des secrets Play/
  Azure. Surface supply-chain réelle sur la tierce non-officielle.
- **Gravité** : `Moyenne` · **Probabilité** : `Faible`.
- **Correctif proposé** : épingler par **SHA** au minimum les actions **tierces non-officielles**
  (`r0adkll/upload-google-play`) et, idéalement, l'ensemble ; ajouter Dependabot `package-ecosystem:
  github-actions` (une fois EMU débloqué) pour maintenir les SHA.
- **Fichiers à modifier** : `.github/workflows/release-android.yml` (+ autres au durcissement),
  `.github/dependabot.yml`.
- **Validation** : `[À EXÉCUTER]` — `zizmor .github/workflows` (outil **absent**) ; ou revue diff après
  pin.
- **Statut** : `Ouvert`.

---

### `F-P2-05` — Pas de `global.json` + SDK .NET flottant + drift Flutter · *CI-CD / Reproductibilité* (routé P3)
- **Preuve** : **aucun `global.json`** à la racine → le SDK .NET est résolu en `8.0.x` **flottant**
  (`ci-backend.yml` `setup-dotnet` `dotnet-version: "8.0.x"`) ; **drift Flutter** : `security-scan.yml:50`
  = **3.24.0** contre **3.27.4** dans `ci-mobile.yml:19`, `release-android.yml:62`, `release-ios.yml:60` ;
  Dart `3.6.0` `ci-mobile.yml:87`. Certitude : `[CERTAIN]`.
- **Risque réel** : builds **non déterministes** — un correctif de SDK .NET publié peut changer le
  comportement/les warnings (`-warnaserror`) sans modification de code ; le drift Flutter signifie que le
  scan sécurité analyse une **autre version** que celle buildée/publiée. Repro et forensic dégradés.
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : (a) ajouter un `global.json` racine épinglant la version SDK .NET (ex.
  `rollForward: latestFeature`) ; (b) **unifier** la version Flutter (aligner `security-scan.yml:50` sur
  3.27.4, idéalement via une variable partagée / var d'org). **Instruit en P3** (scindé → `F-P3-01`
  pour le SDK .NET + `F-P3-04` pour le drift Flutter ; aucun code appliqué).
- **Fichiers à modifier** : `global.json` (nouveau), `.github/workflows/security-scan.yml`.
- **Validation** : `[À EXÉCUTER]` en P3 — `dotnet --version` post-`global.json` ; grep versions Flutter.
- **Statut** : `Instruit en P3` (scindé → `F-P3-01` + `F-P3-04` ; non recompté pour éviter le double comptage).

---

### `F-P2-06` — Couverture mobile mesurée mais non seuillée · *CI-CD / Qualité*
- **Preuve** : `ci-mobile.yml:169` `flutter test --coverage` génère la couverture ; l'upload `:171` est
  `continue-on-error: true` et **aucun seuil minimal** n'est vérifié (pas de gate `lcov`/`--fail-under`).
  Certitude : `[CERTAIN]`.
- **Risque réel** : la couverture peut **régresser** silencieusement ; la métrique est décorative, elle
  ne protège pas contre l'ajout de code non testé.
- **Gravité** : `Faible` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : ajouter une étape de seuil (ex. parse `coverage/lcov.info` avec un minimum, ou
  action de type coverage-gate) qui **fait échouer** le job sous le seuil.
- **Fichiers à modifier** : `.github/workflows/ci-mobile.yml`.
- **Validation** : `[À EXÉCUTER]` — PR baissant la couverture sous le seuil → vérifier l'échec.
- **Statut** : `Ouvert`.

---

### `F-P2-07` — `ci-content` : audit npm/pip non bloquant + `npm install` · *CI-CD / Reproductibilité*
- **Preuve** : `ci-content.yml:40` `node tools/validate_content.mjs` **bloquant** ✓ ; **mais** `:42`
  `npm audit … || true` et `:44` `pip check … || true` → **jamais bloquants** ; install `:38`
  `npm install --no-save` (pas `npm ci`, donc **ne respecte pas strictement le lockfile**). Certitude :
  `[CERTAIN]`.
- **Risque réel** : dérive de dépendances tooling (install non déterministe) et vulnérabilités
  npm/pip **ignorées** ; faible car périmètre = outils de contenu, pas runtime prod.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : remplacer `npm install --no-save` par `npm ci` (nécessite `package-lock.json` —
  à confirmer P3) ; décider si `npm audit`/`pip check` doivent gater (au moins `--audit-level=high`).
- **Fichiers à modifier** : `.github/workflows/ci-content.yml`.
- **Validation** : `[À EXÉCUTER]` — `npm ci` local dans `tools/` ; `npm audit --audit-level=high`.
- **Statut** : `Ouvert`.

---

### `F-P2-08` — Protection prod (reviewers/approvals) non vérifiable dans le code · *CI-CD / Gouvernance*
- **Preuve** : `cd-backend.yml:40,70` `environment: ${{ inputs.environment }}` ;
  `promote-backend-staging-prod.yml:17,25` appelle `cd-backend` pour **staging puis prod**, avec
  `deploy-prod` `needs: deploy-staging` (`:24`) → séquencement OK ; **mais** l'exigence d'**approbation
  humaine sur prod** dépend des *Environment protection rules* GitHub (reviewers, wait timer)
  **non présentes dans le repo**. `cd-backend.yml:26-27` `on: push: branches:[main]` → **auto-deploy dev**
  à chaque merge sans approbation. Certitude : `[À VÉRIFIER]`.
- **Risque réel** : si l'environnement `prod` n'a **pas** de reviewers configurés côté GitHub, une
  promotion prod peut partir **sans approbation** ; impossible à garantir par lecture du code seul.
- **Gravité** : `Moyenne` · **Probabilité** : `Faible`.
- **Correctif proposé** : documenter/versionner l'exigence (au minimum un runbook) ; vérifier et, si
  besoin, configurer les *required reviewers* sur l'environnement `prod`.
- **Fichiers à modifier** : configuration GitHub Environments (hors repo) ; doc.
- **Validation** : `[À EXÉCUTER]` — `gh api repos/:owner/:repo/environments/prod` (inspecter
  `protection_rules`).
- **Statut** : `Ouvert`.

---

### `F-P2-09` — [Correction P1] `promote-backend-staging-prod` sans `runs-on` = **normal** (workflow appelant) · *CI-CD / Cartographie*
- **Preuve** : `promote-backend-staging-prod.yml:17,25` `uses: ./.github/workflows/cd-backend.yml` → les
  jobs sont des **appels de workflow réutilisable** (*reusable workflow caller*), qui **ne portent jamais**
  de `runs-on` (le `runs-on` est défini par l'appelé `cd-backend.yml`). Certitude : `[CERTAIN]`.
- **Risque réel** : **aucun.** Le lead P1 « `promote` sans `runs-on` → job casserait au runtime » est un
  **faux positif** : c'est la syntaxe attendue d'un caller. Aucune correction de code.
- **Gravité** : `Info` · **Probabilité** : `—`.
- **Correctif proposé** : néant (lead **infirmé**). Corrige rétroactivement la note P1 (§4).
- **Fichiers à modifier** : aucun.
- **Validation** : lecture `promote-backend-staging-prod.yml:1-30` `[CERTAIN]`.
- **Statut** : `Infirmé`.

---

### `F-P3-01` — Pas de `global.json` → version du SDK .NET flottante · *Reproductibilité / .NET*
- **Preuve** : aucun `global.json` à la racine ni dans `backend/` (`git ls-files | grep global.json` = vide,
  `[CERTAIN]`). Les workflows installent `dotnet-version: "8.0.x"` (`ci-backend.yml`, `cd-backend.yml:80`) →
  **feature-band non figée**. Certitude : `[CERTAIN]`.
- **Risque réel** : deux machines (ou deux dates) résolvent des SDK 8.0.x **différents** ; avec
  `-warnaserror` (F-P2 gates), un nouveau SDK peut introduire des warnings/analyzers qui **cassent un build
  jusque-là vert** sans aucun changement de code. Repro/forensic dégradés. Reprend F-P2-05 (volet a).
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : ajouter un `global.json` racine épinglant `sdk.version` (ex. la 8.0.4xx utilisée
  localement) + `rollForward: latestFeature` (ou `disable` pour un lock strict).
- **Fichiers à modifier** : `global.json` (nouveau).
- **Validation** : `[À EXÉCUTER]` — `dotnet --version` avant/après `global.json` ; `dotnet build -warnaserror`.
- **Statut** : `Ouvert`.

---

### `F-P3-02` — Pas de lockfile NuGet ni CPM → transitives non reproductibles · *Reproductibilité / .NET*
- **Preuve** : aucun `packages.lock.json` committé (`git ls-files | grep packages.lock.json` = vide,
  `[CERTAIN]`) ; aucun `Directory.Packages.props` (Central Package Management absent) → versions
  `PackageReference` **dispersées** dans les 8 `.csproj`. Le `dotnet restore` réel exécuté n'utilise **pas**
  `--locked-mode` (aucun lockfile à verrouiller). Certitude : `[CERTAIN]`.
- **Risque réel** : les **dépendances transitives** ne sont pas figées → un restore ultérieur peut tirer des
  versions transitives différentes (surface CVE/comportement mouvant), sans trace dans le repo. Le pinning
  exact des références directes (constaté) atténue mais **ne couvre pas** le graphe transitif.
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : activer les lockfiles (`RestorePackagesWithLockFile=true`) et committer les
  `packages.lock.json` ; passer la CI en `dotnet restore --locked-mode`. Optionnel : adopter CPM
  (`Directory.Packages.props`) pour centraliser les versions.
- **Fichiers à modifier** : `Directory.Build.props`/`Directory.Packages.props` (nouveaux), 8 `.csproj`,
  workflows `ci-backend.yml`/`cd-backend.yml`.
- **Validation** : `[À EXÉCUTER]` — `dotnet restore --use-lock-file` puis `dotnet restore --locked-mode`.
- **Statut** : `Ouvert`.

---

### `F-P3-03` — `pubspec.lock` mobile **gitignoré** → app livrée non verrouillée · *Reproductibilité / Flutter*
- **Preuve** : `.gitignore:37-42` exclut explicitement `apps/mobile/pubspec.lock` (avec un commentaire
  admettant le drift) → le lockfile de l'**application publiée** n'est **pas** versionné (`git check-ignore
  apps/mobile/pubspec.lock` confirme, `[CERTAIN]`). Les pipelines release exécutent `flutter pub get`
  (`release-android.yml:130`, `release-ios.yml:190`) → **résolution fraîche** au moment du build. Certitude :
  `[CERTAIN]`.
- **Risque réel** : deux builds release de la **même** révision Git peuvent embarquer des versions de
  packages différentes (y compris transitives) selon la date de résolution → **binaire non reproductible**,
  régression/CVE possible entre deux releases identiques côté source, forensic impossible. C'est le finding
  repro le plus impactant de la phase (chaîne de livraison mobile).
- **Gravité** : `Élevée` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : **committer** `apps/mobile/pubspec.lock` (retirer les lignes `.gitignore:37-42`) et
  utiliser `flutter pub get --enforce-lockfile` dans les pipelines release.
- **Fichiers à modifier** : `.gitignore`, `apps/mobile/pubspec.lock` (à committer),
  `.github/workflows/release-android.yml`, `.github/workflows/release-ios.yml`.
- **Validation** : `[À EXÉCUTER]` — `flutter pub get --enforce-lockfile` sur checkout propre.
- **Statut** : `Ouvert`.

---

### `F-P3-04` — Version du SDK Flutter sans source unique + drift 3.24.0/3.27.4/local · *Reproductibilité / Flutter*
- **Preuve** : aucun `.fvmrc` / `fvm` ni pin unique (`git ls-files | grep -i fvm` = vide, `[CERTAIN]`) ; la
  version est **répétée en dur** dans plusieurs workflows et **diverge** : `security-scan.yml:50` = **3.24.0**
  contre **3.27.4** (`ci-mobile.yml:19`, `release-android.yml:62`, `release-ios.yml:60`) ; le poste local
  tourne en **3.44.4** (encore plus récent). Certitude : `[CERTAIN]`. Consolide F-P2-05 (volet b).
- **Risque réel** : le scan sécurité analyse une **autre** version SDK que celle buildée/publiée ; pas de
  garantie que dev/CI/release partagent la même toolchain → repro et parité analyse/livraison rompues.
- **Gravité** : `Élevée` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : source de vérité unique (`.fvmrc` ou variable d'org) référencée par **tous** les
  jobs ; aligner `security-scan.yml:50` sur la version de build ; envisager `fvm` pour figer localement.
- **Fichiers à modifier** : `.fvmrc` (nouveau) ; workflows `security-scan.yml`, `ci-mobile.yml`,
  `release-android.yml`, `release-ios.yml`.
- **Validation** : `[À EXÉCUTER]` — `grep -rn "flutter-version" .github/workflows` ; `fvm use <ver>`.
- **Statut** : `Ouvert`.

---

### `F-P3-05` — `ci-content` : `npm install --no-save` contourne le lockfile · *Reproductibilité / Node*
- **Preuve** : `ci-content.yml:38` `npm install --no-save` alors qu'un `package-lock.json` **existe** à la
  racine (`[CERTAIN]`) → l'install **ne respecte pas strictement** le lock (contrairement à `npm ci`).
  Certitude : `[CERTAIN]`. Recoupe F-P2-07.
- **Risque réel** : dérive des dépendances de tooling contenu (install non déterministe) ; le lock committé
  devient décoratif. Impact limité (outillage de contenu, pas runtime prod).
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : remplacer par `npm ci` (respecte le lock, échoue si dérive).
- **Fichiers à modifier** : `.github/workflows/ci-content.yml`.
- **Validation** : `[À EXÉCUTER]` — `npm ci` sur checkout propre à la racine.
- **Statut** : `Ouvert`.

---

### `F-P3-06` — `package.json` racine : nom générique, description parasite, test factice · *Hygiène / Node*
- **Preuve** : `package.json:2` `"name": "gchambaud-microsoft-improved-guide"` (nom généré, sans rapport
  avec Certigo) ; `:4` description parasite ; `:10` `"test": "echo \"Error: no test specified\" && exit 1"`
  (script test **factice**). Certitude : `[CERTAIN]`.
- **Risque réel** : faible en soi, mais trompe l'outillage/lecteur (nom de projet incohérent) et un `npm test`
  échouerait volontairement — signal de maturité tooling faible ; à surveiller si un job venait à l'invoquer.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : renommer (`certigo-content-tools` ou similaire), corriger la description, et soit
  retirer le script `test`, soit le pointer sur `node tools/validate_content.mjs`.
- **Fichiers à modifier** : `package.json`.
- **Validation** : `[À EXÉCUTER]` — `npm run test` (doit exécuter une vraie validation).
- **Statut** : `Ouvert`.

---

### `F-P3-07` — Drift des versions d'actions (tags **existants**, aucun pin par SHA) · *Supply-chain / CI*
- **Preuve** : vérifié **en direct** via `gh api` — les majors « suspects » du lead P2 **existent bien**
  (`checkout@v7.0.0`, `setup-dotnet@v5.4.0`, `setup-node@v6.4.0`, `upload-artifact@v7.0.1`,
  `codeql-action` a `v4` **et** `v3`). Le vrai problème est un **drift non maîtrisé** : `cd-backend.yml`
  (`checkout@v7` :48,77 ; `setup-dotnet@v5` :80) et `ci-content.yml:34` (`setup-node@v6`) sont sur les
  **majors les plus récents** tandis que ~12 autres workflows épinglent des `checkout@v4`/`setup-dotnet@v4`
  **plus anciens** ; `codeql.yml:40,47` (`@v4`) diverge de `dependency-vuln-scan.yml:101` (`@v3`). **Aucune
  action tierce n'est épinglée par SHA.** Certitude : `[CERTAIN]`. Recoupe F-P2-04.
- **Risque réel** : le lead « tags hallucinés → CI cassée » est **infirmé** (aucune rupture). Reste :
  incohérence de comportement entre workflows et **absence de pin SHA** → une action mutée derrière un tag
  mobile (`@vX`) peut altérer la CI (supply-chain), et le mélange de majors complique la maintenance.
- **Gravité** : `Moyenne` · **Probabilité** : `Faible`.
- **Correctif proposé** : uniformiser les majors d'actions sur l'ensemble des 14 workflows ; **épingler par
  SHA** (avec commentaire `# vX.Y.Z`) les actions tierces ; laisser Dependabot (cf. F-P3-09) gérer les bumps.
- **Fichiers à modifier** : les 14 `.github/workflows/*.yml` (uniformisation).
- **Validation** : `[À EXÉCUTER]` — `actionlint` ; `gh api repos/<owner>/<action>/git/ref/tags/<tag>`.
- **Statut** : `Ouvert`.

---

### `F-P3-08` — Scan `--vulnerable` = 0, mais currency v1→v2 (Functions Worker) ; CVE Bcl.Memory non tranchée · *Sécurité / .NET*
- **Preuve** : `dotnet list package --vulnerable --include-transitive` **réellement exécuté** → **0 package
  vulnérable** signalé (`Bcl.Memory 10.0.9`, `Certigo.Infrastructure.csproj:18`, **n'est pas** flaggé). Le
  commentaire `:17` évoque un patch « CVE-2026-26127 » : cette CVE est **au-dessus de mon cutoff** →
  statut `[À VÉRIFIER]`. `dotnet list package --outdated` : `Certigo.Api` est sur **Functions Worker v1**
  (`Certigo.Api.csproj:12-19`) — `Worker 1.24.0→2.52.0`, `Worker.Sdk 1.18.1→2.0.7`,
  `Worker.ApplicationInsights 1.4.0→2.51.0`, `ApplicationInsights.WorkerService 2.23.0→3.1.2`. Certitude :
  `[CERTAIN]` (scans) / `[À VÉRIFIER]` (CVE).
- **Risque réel** : pas de vulnérabilité **connue de l'outil** aujourd'hui, mais **retard d'un major** sur la
  stack Functions Worker → dette (fonctionnalités/sécurité) et fenêtre de correctifs manquée ; le claim CVE
  du commentaire n'est **pas** confirmable ici.
- **Gravité** : `Moyenne` · **Probabilité** : `Faible`.
- **Correctif proposé** : planifier la montée Functions Worker v1→v2 (hors P3, changement de code) ; **vérifier
  la CVE** Bcl.Memory sur un flux d'avis à jour ; brancher un scan `--vulnerable` **bloquant** en CI.
- **Fichiers à modifier** : `Certigo.Api.csproj` (bump, hors P3) ; CI (ajout gate vuln).
- **Validation** : `[À EXÉCUTER]` — re-run `dotnet list package --vulnerable --include-transitive` en CI ;
  `gh api …/dependabot/alerts` ; consulter l'avis CVE-2026-26127.
- **Statut** : `Ouvert`.

---

### `F-P3-09` — `dependabot.yml` bien formé mais **probablement inerte** (EMU) → fausse sécurité · *Supply-chain / Automatisation*
- **Preuve** : `.github/dependabot.yml` existe et est bien structuré (`[CERTAIN]` sur la présence/forme), mais
  l'exécution effective des mises à jour dépend de l'activation Dependabot côté organisation (contexte EMU) —
  **non vérifiable par le seul code**. Certitude : `[À VÉRIFIER]` ; **probabilité inerte** : `[INCONNU]`.
- **Risque réel** : si Dependabot ne tourne pas, le fichier donne une **fausse impression** de mises à jour
  auto (sécurité/patchs) alors qu'aucune PR n'est ouverte → dérive silencieuse des dépendances non corrigées.
- **Gravité** : `Moyenne` · **Probabilité** : `[INCONNU]`.
- **Correctif proposé** : confirmer l'état réel côté GitHub ; si inerte, activer Dependabot (ou documenter un
  process de bump manuel) et vérifier l'ouverture effective de PR.
- **Fichiers à modifier** : configuration org GitHub (hors repo) ; doc.
- **Validation** : `[À EXÉCUTER]` — `gh api repos/<owner>/Certigo/dependabot/alerts` ; observer les PR
  Dependabot sur une fenêtre.
- **Statut** : `Ouvert`.

---

### `F-P3-10` — Drift `flutter_lints` entre packages (^6.0.0 vs ^4.0.0) · *Hygiène / Flutter*
- **Preuve** : `packages/prism_ui/pubspec.yaml:18` `flutter_lints: ^6.0.0` contre `apps/mobile/pubspec.yaml:54`
  `flutter_lints: ^4.0.0` → deux jeux de règles lint **différents** dans le même monorepo. Certitude :
  `[CERTAIN]`.
- **Risque réel** : incohérence des règles d'analyse selon le package (un code accepté ici est refusé
  ailleurs) ; friction de maintenance, faible impact fonctionnel.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : aligner `flutter_lints` sur une version unique pour tous les packages Dart
  (idéalement centralisée), harmoniser les `analysis_options.yaml`.
- **Fichiers à modifier** : `apps/mobile/pubspec.yaml`, `packages/*/pubspec.yaml`.
- **Validation** : `[À EXÉCUTER]` — `flutter analyze` / `melos run analyze` après alignement.
- **Statut** : `Ouvert`.

---

### `F-P4-01` — Résilience concurrence incohérente entre services d'économie · *Backend / Cosmos / Intégrité*
- **Preuve** : seul `QuizService` protège le crédit du profil par un retry de concurrence optimiste —
  `backend/src/Certigo.Application/Services/QuizService.cs:276` (`OptimisticConcurrency.ExecuteAsync(...)`).
  Les autres services d'économie créditent/débitent le profil via un simple `UpsertAsync` conditionnel
  **sans retry** : `ExamService.cs:356`, `GamificationServices.cs:70` (`ShopService.PurchaseAsync`),
  `GamificationServices.cs:158` (`QuestService.ClaimAsync`), `GamificationServices.cs:~269` (`SeasonService`),
  `GamificationServices.cs:~435` (`StreakRepairService`). Certitude : `[À VÉRIFIER]` (comportement runtime
  sous contention non rejoué — émulateur Cosmos absent).
- **Risque réel** : pour les services « attempt-first » (l'attempt/idempotence est écrit **avant** le crédit),
  un conflit 412/ETag au moment du crédit **après** l'enregistrement de l'attempt provoque, au rejeu, le
  retour du résultat déjà stocké → **la récompense est rapportée au client mais jamais persistée**
  (récompense silencieusement perdue). Pas de double-dépense (l'ETag est honoré) : le risque est une
  **perte**, pas un gain indu.
- **Gravité** : `Moyenne` · **Probabilité** : `Faible-Moyenne`.
- **Correctif proposé** : encapsuler les étapes de crédit/débit de profil des services d'économie dans le
  même helper `OptimisticConcurrency.ExecuteAsync` que `QuizService` (relire le profil + réappliquer le
  delta sur conflit), ou factoriser un `CreditProfileWithRetryAsync` partagé.
- **Fichiers à modifier** : `backend/src/Certigo.Application/Services/ExamService.cs`,
  `backend/src/Certigo.Application/Services/GamificationServices.cs` (Shop/Quest/Season/StreakRepair).
- **Validation** : `[À EXÉCUTER]` — tests d'intégration sous contention (émulateur Cosmos) :
  `$env:CERTIGO_COSMOS_TESTS="1"; $env:COSMOS_EMULATOR_ENDPOINT="https://localhost:8081"; $env:COSMOS_EMULATOR_KEY="<clé primaire émulateur>"; dotnet test "backend\Certigo.sln" --filter "FullyQualifiedName~CosmosRepositoriesIntegrationTests"`.
- **Statut** : `Ouvert`.

---

### `F-P4-02` — Idempotence multi-conteneurs non atomique (ordre à risque) dans le chemin monétaire · *Backend / Cosmos / Intégrité*
- **Preuve** : `ShopService.PurchaseAsync` **débite le profil puis accorde l'item** (`GamificationServices.cs:70`,
  conteneur Users) **AVANT** d'écrire le marqueur d'idempotence `purchases.CreateAsync` (`GamificationServices.cs:82`,
  conteneur Economy). Un crash / 429 entre les deux + rejeu client avec le même `ClientPurchaseId` → marqueur
  absent → **re-débit + re-attribution** (idempotence rompue sur le chemin monétaire). `StreakRepairService`
  partage le **même ordre non sûr** (`GamificationServices.cs:~435`→`~447` ; commentaire `~400-401` « mirrors
  ShopService »). À l'inverse, `QuizService` écrit l'attempt **d'abord** (`QuizService.cs:236-241`) = ordre sûr.
  `QuestService` (idempotence single-doc) et `SeasonService` **non affectés**. Certitude : `[À VÉRIFIER]`.
- **Risque réel** : sur les écritures **cross-conteneur / cross-partition** (Users vs Economy), Cosmos
  n'offre pas de `TransactionalBatch` atomique → une interruption entre mutation et marqueur casse
  l'idempotence → **double-débit / double-attribution** possible au rejeu réseau. Impact = intégrité
  économique (monnaie / inventaire).
- **Gravité** : `Moyenne` · **Probabilité** : `Faible-Moyenne`.
- **Correctif proposé** : inverser l'ordre → **marqueur d'idempotence d'abord** (`CreateAsync`
  « create-before-mutate » : le 409 sur le marqueur court-circuite le rejeu), puis mutation du profil ;
  ajouter une compensation/nettoyage si la mutation échoue après création du marqueur. `TransactionalBatch`
  **non applicable** (conteneurs/partitions distincts).
- **Fichiers à modifier** : `backend/src/Certigo.Application/Services/GamificationServices.cs`
  (`ShopService.PurchaseAsync`, `StreakRepairService`).
- **Validation** : `[À EXÉCUTER]` — test de rejeu avec injection de panne entre mutation et marqueur
  (émulateur Cosmos, même commande que `F-P4-01`).
- **Statut** : `Ouvert`.

---

### `F-P4-03` — Clé de signature JWT dérivable + validateur HS256 local actif en prod · *Backend / Sécurité / Auth*
- **Preuve** : (a) `backend/src/Certigo.Api/Program.cs:78` ajoute `LocalJwtTokenValidator` (HS256)
  **inconditionnellement et en PREMIER** dans `CompositeTokenValidator`, **tous environnements y compris prod**
  → un jeton HS256 émis localement est accepté en prod si la clé est connue/dérivable. (b) `infra/main.bicep:82`
  `effectiveAuthJwtSigningKey = empty(authJwtSigningKey) ? guid(subscription().id, appName, env, 'auth-jwt-signing-key') : authJwtSigningKey`
  et `infra/params/prod.bicepparam:64-68` laisse la clé **vide** sans rien qui force l'injection → clé prod par
  défaut = `guid()` déterministe d'entrées **semi-publiques** → **recalculable → jetons prod forgeables pour
  n'importe quel `userId`**. (c) `backend/src/Certigo.Application/Abstractions/JwtSigningKeyGuard.cs:23-44` :
  `hardened = isProduction || AUTH_MODE=prod` ; `isStrongKey = !blank && != littéral DevelopmentSigningKey` ; ne
  lève **que** si `hardened && !isStrongKey`, sinon renvoie la clé **verbatim** → **aucun contrôle d'entropie /
  longueur / dérivation** → un GUID de 36 caractères passe pour « forte ». Certitude : `[À VÉRIFIER]` (exploit
  réel non tenté ; dépend du déploiement effectif).
- **Risque réel** : compromission d'authentification — si la clé prod est la valeur `guid()` par défaut (aucune
  injection Key Vault effective), un attaquant connaissant subscriptionId / appName / env peut **forger un jeton
  valide** pour n'importe quel utilisateur. Le validateur local HS256 étant **toujours essayé en premier**, la
  porte reste ouverte même en prod.
- **Gravité** : `Élevée` · **Probabilité** : `Faible-Moyenne`.
- **Correctif proposé** : (1) **conditionner** l'ajout de `LocalJwtTokenValidator` aux environnements non-prod
  (ou le retirer du composite en prod) ; (2) durcir `JwtSigningKeyGuard` : exiger longueur/entropie minimales et
  **rejeter toute clé dérivable** (interdire le fallback `guid()` en mode durci) ; (3) **infra (cross-ref P6)** :
  imposer l'injection de la clé depuis Key Vault en prod (échec de déploiement si vide), supprimer le fallback
  `guid()` pour les environnements durcis.
- **Fichiers à modifier** : `backend/src/Certigo.Api/Program.cs`,
  `backend/src/Certigo.Application/Abstractions/JwtSigningKeyGuard.cs` ; **infra** `infra/main.bicep`,
  `infra/params/prod.bicepparam` (**instruit en P6**).
- **Validation** : `[À EXÉCUTER]` — (a) test unitaire : `JwtSigningKeyGuard` doit lever sur une clé de type
  `guid()` en mode durci ; (b) revue déploiement prod pour confirmer la source réelle de la clé
  (`az functionapp config appsettings list` / inspection Key Vault) — **non tenté** (pas d'accès Azure).
- **Note positive** : le **bypass dev est neutralisé en prod** — `infra/main.bicep:79` force un `authMode`
  non-dev, `AuthValidatorSelection` lève si `AUTH_MODE=dev` en Prod sauf `AUTH_ALLOW_DEV=true`, et
  `infra/modules/functionApp.bicep:147` ne pose `AUTH_ALLOW_DEV` que si `authMode=='dev'`. Ce finding porte sur
  la **clé** + le **validateur local**, pas sur un mode dev accessible.
- **Statut** : `Ouvert`.

---

### `F-P4-04` — Verdict cohésion `F-P1-01` : god-file largement infirmé (nit d'organisation) · *Backend / Architecture*
- **Preuve** : lecture intégrale de `backend/src/Certigo.Domain/Tutor/Tutor.cs:1` (550 L) = **domaine pur et
  cohérent** (records + moteurs statiques : `TutorContextFactory:171`, `TutorComposer:284`,
  `TutorGuardrails:442`, `TutorPromptBuilder:550`) — **aucun** monolithe de 96 KB, **aucune** god-class. Les 11
  services sous `backend/src/Certigo.Application/Services/` ont des responsabilités distinctes ; `dotnet build`
  (0/0) et `dotnet test` (525/0/6) passent. Reliquat : quelques fichiers **regroupent plusieurs classes** —
  `backend/src/Certigo.Infrastructure/Cosmos/CosmosRepositories.cs:1` (463 L),
  `backend/src/Certigo.Application/Services/GamificationServices.cs:1` (453 L), `Tutor.cs` (plusieurs types
  domaine). Certitude : `[CERTAIN]` sur la lecture ; `[PROBABLE]` sur l'absence de couplage résiduel problématique.
- **Risque réel** : **négligeable** — friction de navigation/maintenance (plusieurs classes par fichier),
  aucune conséquence de sécurité / intégrité / disponibilité. **Clôt et remplace `F-P1-01`** (hypothèse god-file
  **infirmée** sur code réel).
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : **optionnel** — scinder les fichiers multi-classes en un type par fichier
  (`CosmosRepositories.cs`, `GamificationServices.cs`, `Tutor.cs`) pour l'hygiène. **Aucun correctif code requis**.
- **Fichiers à modifier** : *(optionnel)* `backend/src/Certigo.Infrastructure/Cosmos/CosmosRepositories.cs`,
  `backend/src/Certigo.Application/Services/GamificationServices.cs`, `backend/src/Certigo.Domain/Tutor/Tutor.cs`.
- **Validation** : `dotnet build backend\Certigo.sln -warnaserror` = **0 warning / 0 erreur** **[CERTAIN]** ;
  `dotnet test backend\Certigo.sln` = **525 réussis / 0 échec / 6 ignorés** **[CERTAIN]**.
- **Statut** : `Clôturé` (supersède `F-P1-01`).

---

### `F-P5-01` — Secrets applicatifs injectés en clair dans les app settings Function App · *Sécurité / Infra-App / Secrets*
- **Preuve** : `infra/modules/functionApp.bicep:148` pose `AUTH_JWT_SIGNING_KEY` avec `value: authJwtSigningKey`
  (valeur en clair), `:156` `TUTOR_LLM_API_KEY` = `value: tutorLlmApiKey`, `:164` `ACS_EMAIL_CONNECTION_STRING`
  = `value: acsEmailConnectionString` — **aucune** référence `@Microsoft.KeyVault(SecretUri=...)` dans le fichier
  (0 occurrence), bien que `KeyVault__Uri` soit renseigné `:158`. Certitude : `[CERTAIN]`.
- **Risque réel** : les trois secrets (clé de signature JWT, clé API LLM, chaîne de connexion e-mail ACS) sont
  stockés en clair dans la configuration de la Function App → lisibles par tout principal disposant de
  `Microsoft.Web/sites/config/list/action` (Reader+ sur l'app, Contributor, identités CI/CD), présents dans les
  exports ARM et `az functionapp config appsettings list`, non rotables centralement. **Clôt le volet APP de
  `F-P4-03`** : la question `[À VÉRIFIER]` « clé en clair ou référence Key Vault ? » est tranchée → **clair**. La
  **dérivation `guid()`** de la clé (`main.bicep:82`) reste instruite en **P6 (infra)**.
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : externaliser les trois secrets dans Key Vault et les référencer via
  `@Microsoft.KeyVault(SecretUri=https://<kv>/secrets/<name>)` dans les app settings (l'URI KV est déjà disponible
  `:158`) ; activer l'identité managée de la Function App + RBAC `Key Vault Secrets User` ; supprimer les `value:`
  en clair.
- **Fichiers à modifier** : `infra/modules/functionApp.bicep` (lignes 148/156/164), `infra/main.bicep`
  (branchement des SecretUri), `infra/params/*.bicepparam`.
- **Validation** : `[À EXÉCUTER]` — `az functionapp config appsettings list -g <rg> -n <app> --query "[?name=='AUTH_JWT_SIGNING_KEY']"`
  doit renvoyer une valeur de forme `@Microsoft.KeyVault(...)` (non tenté : pas d'accès Azure) ; `bicep build infra/main.bicep`
  pour valider la syntaxe des références.
- **Statut** : `Ouvert`.

---

### `F-P5-02` — Absence de throttling IP/global (lockout par compte uniquement) · *Sécurité / Anti-abus*
- **Preuve** : le seul garde-fou est un **lockout par compte** — `backend/src/Certigo.Application/Services/AuthService.cs:95-98`
  (`MaxFailedAttempts=5`, `LockoutDuration=15min`), vérifié avant le mot de passe `:184-188` et réinitialisé au
  succès `:197-201`. **Aucun** throttle par IP/global : (a) le credential-stuffing réparti sur de **nombreux
  comptes** n'est pas ralenti ; (b) `register` n'a **aucune** limite → inscriptions de masse ; (c) `ResendAsync`
  (`:301-323`) ré-émet un jeton + envoie un e-mail **à chaque appel sans cooldown** → e-mail-bombing + coût ACS.
  Certitude : `[CERTAIN]` (sur l'absence dans le code applicatif).
- **Risque réel** : brute-force distribué, bourrage d'identifiants multi-comptes, inscriptions abusives,
  bombardement e-mail d'une victime et coût ACS non maîtrisé. `[À VÉRIFIER]` : une protection au niveau
  plateforme (Front Door/APIM/WAF) n'est pas présente dans l'IaC audité.
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : ajouter un rate-limiting par IP (+ par compte) sur `login`, `register`,
  `resend-verification`, `purchase`, `submit-attempt` (middleware de throttling ou WAF/Front Door en amont) ;
  imposer un **cooldown** sur `ResendAsync` (ex. 1 renvoi / 60 s / compte) ; envisager un challenge (captcha) sur
  `register`.
- **Fichiers à modifier** : `backend/src/Certigo.Application/Services/AuthService.cs` (cooldown `ResendAsync`),
  middleware/couche d'entrée pour le throttle IP ; option infra Front Door/WAF (cross-ref P6).
- **Validation** : `[À EXÉCUTER]` — test d'intégration : N tentatives de login sur M comptes depuis une IP → doit
  être throttlé ; test `resend` en rafale → 2e appel refusé avant cooldown.
- **Statut** : `Ouvert`.

---

### `F-P5-03` — Énumération de comptes (register) + canal temporel au login · *Sécurité / Auth / Énumération*
- **Preuve** : (a) `register` divulgue l'existence d'une adresse — `AuthService.cs:124` / `:151` lèvent
  `DuplicateRecordException` (« adresse e-mail déjà utilisée ») → énumération directe. (b) Canal temporel au
  login : une adresse **inconnue** lève immédiatement `:177-180` **sans** exécuter la vérification PBKDF2, alors
  qu'une adresse **connue** subit le hachage complet (100k itérations) → différence de latence mesurable →
  énumération. Certitude : `[CERTAIN]` sur (a), `[PROBABLE]` sur (b).
- **Risque réel** : un attaquant peut cartographier les adresses enregistrées (via `register` ou par timing),
  préalable au phishing ciblé et au credential-stuffing. Impact limité (adresse e-mail, pas de credential).
- **Gravité** : `Faible` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : pour `register`, renvoyer une réponse générique (« si cette adresse peut être utilisée,
  un e-mail de vérification a été envoyé ») sans révéler le doublon ; pour le login, exécuter un hachage PBKDF2
  « factice » à coût constant sur adresse inconnue afin d'égaliser le temps de réponse.
- **Fichiers à modifier** : `backend/src/Certigo.Application/Services/AuthService.cs` (`RegisterAsync`, `LoginAsync`).
- **Validation** : `[À EXÉCUTER]` — test comparant la latence login adresse connue vs inconnue (< seuil) ; test
  `register` sur doublon → message générique.
- **Note positive** : le **message de login est déjà résistant à l'énumération** (`:179`, message générique
  identique quel que soit le motif) et `ResendVerification` renvoie **toujours** une réponse générique — bonnes
  pratiques déjà en place.
- **Statut** : `Ouvert`.

---

### `F-P5-04` — PBKDF2 à 100 000 itérations (sous le repère OWASP 2023) · *Sécurité / Cryptographie*
- **Preuve** : `backend/src/Certigo.Infrastructure/Identity/Pbkdf2PasswordHasher.cs:15` fixe **100 000 itérations**
  PBKDF2-HMAC-SHA256, avec sel de **16 octets** et clé dérivée de **32 octets** (`:13-14`) et comparaison **à temps
  constant** (`:56`). Le repère OWASP 2023 pour PBKDF2-HMAC-SHA256 est **600 000** itérations. Certitude : `[CERTAIN]`.
- **Risque réel** : en cas de fuite de la base, le coût de crackage hors-ligne est ~6× inférieur au repère courant.
  Impact modéré (sel unique + longueur correcte réduisent déjà rainbow/brute-force), mais marge de sécurité en deçà
  de l'état de l'art.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : porter les itérations à ≥ 600 000 (PBKDF2-HMAC-SHA256) **ou** migrer vers Argon2id/scrypt ;
  prévoir une **remontée transparente** du facteur de coût au prochain login réussi (re-hash).
- **Fichiers à modifier** : `backend/src/Certigo.Infrastructure/Identity/Pbkdf2PasswordHasher.cs`.
- **Validation** : `[À EXÉCUTER]` — `dotnet test` du hasher (round-trip + itérations attendues) ; mesure du temps
  de hachage cible (~≥ 250 ms sur le SKU de prod).
- **Note positive** : sel aléatoire par mot de passe, longueur de clé correcte et **comparaison à temps constant**
  déjà présents.
- **Statut** : `Ouvert`.

---

### `F-P5-05` — Algorithmes JWT non épinglés (`ValidAlgorithms` absent) · *Sécurité / Auth / JWT*
- **Preuve** : `backend/src/Certigo.Infrastructure/Identity/LocalJwtTokenValidator.cs:38-48` et
  `.../EntraTokenValidator.cs:43-53` valident **issuer, audience, clé de signature et durée de vie**
  (`ClockSkew=2min`, `RequireSignedTokens=true`), mais **aucun** des deux ne renseigne
  `TokenValidationParameters.ValidAlgorithms` → l'algorithme accepté n'est pas explicitement épinglé.
  Certitude : `[PROBABLE]` (non exploitable en l'état).
- **Risque réel** : confusion d'algorithme / `alg=none` en théorie. **Atténué** ici : le validateur local est
  **symétrique (HS256)** avec `RequireSignedTokens`, et Entra utilise des clés asymétriques via metadata — pas de
  mélange clé publique/HMAC exploitable dans la configuration actuelle. Reste un durcissement défensif recommandé.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : renseigner explicitement `ValidAlgorithms = ["HS256"]` (validateur local) et la liste
  asymétrique attendue (`["RS256"]`/Entra) dans chaque `TokenValidationParameters`.
- **Fichiers à modifier** : `backend/src/Certigo.Infrastructure/Identity/LocalJwtTokenValidator.cs`,
  `.../EntraTokenValidator.cs`.
- **Validation** : `[À EXÉCUTER]` — test unitaire : un jeton signé avec un `alg` inattendu doit être **rejeté**.
- **Note positive** : `RequireSignedTokens`, `ClockSkew` borné et validation issuer/audience déjà correctement
  configurés.
- **Statut** : `Ouvert`.

---

### `F-P5-06` — Durée de vie des jetons longue + absence de révocation · *Sécurité / Auth / Session*
- **Preuve** : `backend/src/Certigo.Infrastructure/Identity/JwtTokenIssuer.cs:50-51` fixe un **access token = 1 jour**
  et un **refresh token = 90 jours** ; signature **HS256** (`:118`). Aucun mécanisme de **révocation** (liste de
  rejet / rotation de `jti` / versionnage) n'est présent. Certitude : `[CERTAIN]`.
- **Risque réel** : un access token volé reste valide jusqu'à **24 h** sans révocation immédiate ; un refresh token
  compromis ouvre une fenêtre de **90 j**. Impact modéré (mobile natif + stockage sécurisé côté client), mais
  fenêtre d'abus large.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : réduire l'access token (ex. 15–60 min), implémenter une **rotation** des refresh tokens
  avec détection de réutilisation, et une **liste de révocation** (ou `tokenVersion` par utilisateur invalidant les
  jetons au changement de mot de passe / logout).
- **Fichiers à modifier** : `backend/src/Certigo.Infrastructure/Identity/JwtTokenIssuer.cs` + service de
  refresh/`AuthService`.
- **Validation** : `[À EXÉCUTER]` — test : après logout / reset password, un ancien jeton doit être **refusé**.
- **Statut** : `Ouvert`.

---

### `F-P5-07` — En-têtes de sécurité HTTP incomplets (CSP + `Cache-Control` absents) · *Sécurité / En-têtes HTTP*
- **Preuve** : `backend/src/Certigo.Api/Middleware/SecurityHeadersMiddleware.cs:18-24` pose
  `X-Content-Type-Options: nosniff`, `Strict-Transport-Security: max-age=63072000; includeSubDomains`,
  `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` — mais **aucune** `Content-Security-Policy` ni
  `Cache-Control: no-store` sur les réponses d'authentification. Certitude : `[CERTAIN]`.
- **Risque réel** : faible pour une API JSON native (pas de rendu HTML), mais la page privacy-policy et
  d'éventuelles réponses navigateur ne bénéficient pas de CSP ; les réponses contenant des jetons pourraient être
  mises en cache sans `no-store`. Défense en profondeur incomplète.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : ajouter une `Content-Security-Policy` (au minimum `default-src 'none'; frame-ancestors 'none'`
  pour les endpoints API, politique adaptée pour la page HTML) et `Cache-Control: no-store` sur les réponses
  d'auth/jetons.
- **Fichiers à modifier** : `backend/src/Certigo.Api/Middleware/SecurityHeadersMiddleware.cs`.
- **Validation** : `[À EXÉCUTER]` — `curl -I` sur un endpoint → présence de `Content-Security-Policy` et
  `Cache-Control: no-store`.
- **Note positive** : HSTS (2 ans + `includeSubDomains`), `nosniff`, `X-Frame-Options: DENY` et
  `Referrer-Policy: no-referrer` déjà correctement posés pour toutes les réponses.
- **Statut** : `Ouvert`.

---

### `F-P5-08` — Pas de plafond applicatif explicite sur la taille du corps de requête · *Sécurité / Validation d'entrée*
- **Preuve** : `backend/src/Certigo.Api/Http/HttpExtensions.cs:43-56` (`ReadJsonAsync<T>`) fixe
  `JsonSerializerOptions.MaxDepth = 64` (bombe de profondeur **bornée**) mais **aucun** plafond applicatif sur la
  **taille** du corps ; un corps `null` lève `BadRequestException`, un JSON malformé → 400. Certitude : `[CERTAIN]`.
- **Risque réel** : envoi d'un corps très volumineux → consommation mémoire/CPU. **Atténué** par les limites
  plateforme (Flex Consumption borne la taille des requêtes) mais non maîtrisé au niveau applicatif. Impact faible.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : imposer une taille maximale de corps (lecture bornée / `MaxRequestBodySize` ou vérification
  `Content-Length`) proportionnée aux plus gros DTO légitimes, avec rejet 413 au-delà.
- **Fichiers à modifier** : `backend/src/Certigo.Api/Http/HttpExtensions.cs` (+ configuration host si nécessaire).
- **Validation** : `[À EXÉCUTER]` — test : corps > seuil → rejeté (413/400) sans OOM.
- **Note positive** : `MaxDepth=64` protège déjà contre les bombes de profondeur JSON ; désérialisation stricte
  (null/malformé → 400).
- **Statut** : `Ouvert`.

---

### `F-P5-09` — CORS `*` limité au seul environnement `dev` · *Sécurité / CORS*
- **Preuve** : `infra/main.bicep:205-206` définit les origins autorisés par `env == 'dev' ? ['*'] : []` →
  **wildcard uniquement en dev**, liste **vide** en staging/prod. Certitude : `[CERTAIN]`.
- **Risque réel** : **négligeable en prod** (aucune origine navigateur autorisée ; le client mobile natif n'est pas
  soumis au CORS navigateur). Le `*` dev n'expose pas d'environnement de production. Consigné pour complétude et
  vigilance (ne pas étendre le `*` au-delà de dev).
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : conserver la liste vide en prod/staging ; si un front web est ajouté, énumérer
  explicitement les origines de confiance (jamais `*` avec `AllowCredentials`).
- **Fichiers à modifier** : `infra/main.bicep` *(aucune action requise en l'état ; garde-fou documentaire)*.
- **Validation** : `[À EXÉCUTER]` — `az functionapp cors show -g <rg> -n <app>` en prod → liste vide (non tenté :
  pas d'accès Azure).
- **Note positive** : la restriction `dev`-only est un choix **sain** ; prod/staging sans wildcard.
- **Statut** : `Ouvert`.

---

### `F-P6-01` — Clé de signature JWT dérivable par `guid()` déterministe (prod) · *Azure / IaC — 6E*
- **Preuve** : `infra/main.bicep:82` `var effectiveAuthJwtSigningKey = empty(authJwtSigningKey) ? guid(subscription().id, appName, env, 'auth-jwt-signing-key') : authJwtSigningKey` ; `infra/params/prod.bicepparam:64-68` laisse `authJwtSigningKey` **vide** (commentaire l'admet) ; propagation `main.bicep:189` → `functionApp.bicep:57` (`@secure`) → app setting `functionApp.bicep:148` (`AUTH_JWT_SIGNING_KEY`). Côté app, `Program.cs:76-81` place `LocalJwtTokenValidator` en 1er inconditionnel (cf. `F-P4-03`). Certitude : `[CERTAIN]` (chaîne infra + param) / `[PROBABLE]` (exploitabilité : `guid()` Bicep = hash déterministe de ses entrées ; seule entrée « secrète » = `subscription().id`, un GUID **découvrable**).
- **Risque réel** : en prod la clé HS256 n'est pas un secret aléatoire mais une valeur **recalculable** par quiconque connaît `appName`, `env='prod'`, le littéral `'auth-jwt-signing-key'` (tous dans le repo) et l'ID d'abonnement → **forge de jetons** arbitraires (usurpation d'identité, escalade). **Volet INFRA de `F-P4-03`**.
- **Gravité** : `Élevée` · **Probabilité** : `Moyenne` (dépend de la connaissance de `subscription().id`).
- **Correctif proposé** : **imposer** une vraie clé aléatoire (≥ 32 o) hors dépôt — générée et stockée en Key Vault, injectée par **référence** `@Microsoft.KeyVault(SecretUri=...)` (cf. `F-P6-02`) ; **interdire** le fallback `guid()` (échec de déploiement si vide en prod, ex. `assert`/validation param) ; rotation documentée.
- **Fichiers à modifier** : `infra/main.bicep` (supprimer/verrouiller le fallback), `infra/params/prod.bicepparam` (référencer un secret KV), `infra/modules/functionApp.bicep` (injecter la réf KV), `infra/modules/keyvault.bicep` (provisionner le secret).
- **Validation** : `az bicep build --file infra/main.bicep` **RÉELLEMENT EXÉCUTÉE → PASS** (0/0) — compile mais ne juge pas la sécu. `[À EXÉCUTER]` — `az functionapp config appsettings list -g <rg> -n <app> --query "[?name=='AUTH_JWT_SIGNING_KEY']"` (vérifier réf KV vs clair) ; `checkov -d infra`.
- **Note positive** : le paramètre est bien typé `@secure()` ; l'intention Key Vault existe (`KeyVault__Uri` + rôle Secrets User) mais n'est pas câblée pour ce secret.
- **Statut** : `Ouvert` (clôt le volet **infra** de `F-P4-03`).

---

### `F-P6-02` — 3 secrets Function App injectés en clair, aucune ressource / référence Key Vault · *Azure / IaC — 6B*
- **Preuve** : `infra/modules/functionApp.bicep:148` (`AUTH_JWT_SIGNING_KEY`), `:156` (`TUTOR_LLM_API_KEY`), `:164` (`ACS_EMAIL_CONNECTION_STRING`) = app settings en `value` brut ; `infra/modules/keyvault.bicep` (45 L) **ne provisionne aucune** ressource `Microsoft.KeyVault/vaults/secrets` ; recherche `@Microsoft.KeyVault` sur `infra/**` → **0 occurrence**. Certitude : `[CERTAIN]`.
- **Risque réel** : les 3 secrets transitent en clair dans le template ARM, l'historique de déploiement et la config App Service (lisibles par tout rôle ayant accès à la config) → surface d'exposition élargie, rotation manuelle. **Remédiation INFRA de `F-P5-01`.**
- **Gravité** : `Moyenne` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : créer les secrets dans `keyvault.bicep` (`Microsoft.KeyVault/vaults/secrets`) et remplacer les 3 `value` par des références `@Microsoft.KeyVault(SecretUri=https://<kv>.vault.azure.net/secrets/<name>)` ; la MI système + le rôle **Key Vault Secrets User** (déjà présents `functionApp.bicep:214-222`) permettent la résolution runtime.
- **Fichiers à modifier** : `infra/modules/keyvault.bicep`, `infra/modules/functionApp.bicep:148/156/164`, chaîne de passage des paramètres (`main.bicep`).
- **Validation** : `az bicep build` **PASS** (déjà exécutée). `[À EXÉCUTER]` — `az functionapp config appsettings list -g <rg> -n <app>` (confirmer les 3 en réf KV) ; `checkov -d infra` (règle « secrets in app settings »).
- **Note positive** : `KeyVault__Uri` (`functionApp.bicep:158`) et le rôle Secrets User sont déjà en place → migration à faible friction.
- **Statut** : `Ouvert` (cadre la remédiation **infra** de `F-P5-01`).

---

### `F-P6-03` — Cosmos DB `publicNetworkAccess` Enabled sans pare-feu IP / VNet · *Azure / IaC — 6A*
- **Preuve** : `infra/modules/cosmos.bicep:38` `publicNetworkAccess` = `'Enabled'` (défaut) ; propriétés `:20-40` **sans** `ipRules`, `virtualNetworkRules`, ni `isVirtualNetworkFilterEnabled`. Certitude : `[CERTAIN]`.
- **Risque réel** : le compte Cosmos est joignable depuis tout Internet au niveau réseau ; la seule barrière est l'authz data-plane (`disableLocalAuth` en prod, `:37`). Défense en profondeur absente → surface d'attaque réseau + risque d'exfiltration si une identité/clé fuit (les clés restent actives en `dev`).
- **Gravité** : `Moyenne` · **Probabilité** : `Faible` (atténuée par `disableLocalAuth` en prod).
- **Correctif proposé** : passer `publicNetworkAccess:'Disabled'` avec **private endpoint** (cf. `F-P6-05`), ou a minima `ipRules`/`virtualNetworkRules` restreignant aux egress connus (NAT runner `20.86.156.64`, VNet Function App).
- **Fichiers à modifier** : `infra/modules/cosmos.bicep:20-40`, `infra/main.bicep` (paramétrer les plages).
- **Validation** : `az bicep build` **PASS**. `[À EXÉCUTER]` — `az cosmosdb show -g <rg> -n <acct> --query "{pna:publicNetworkAccess, ip:ipRules, vnet:virtualNetworkRules}"` ; `checkov -d infra`.
- **Note positive** : `disableLocalAuth` (prod) + TLS 1.2 minimum (`:39`) déjà en place.
- **Statut** : `Ouvert`.

---

### `F-P6-04` — Cosmos DB sans `backupPolicy`/PITR explicite, mono-région, non zone-redondant · *Azure / IaC — 6A*
- **Preuve** : `infra/modules/cosmos.bicep` — **aucune** propriété `backupPolicy` (→ défaut *Periodic*, pas de restauration ponctuelle/PITR) ; `:34` `isZoneRedundant:false` (y compris prod) ; `:22` `enableAutomaticFailover:false` + `locations` mono-région. Certitude : `[CERTAIN]` (absence de `backupPolicy` observée) / `[À VÉRIFIER]` (comportement exact du défaut Periodic selon l'API).
- **Risque réel** : RPO/RTO dégradés — pas de restauration continue en cas de corruption logique ou de suppression accidentelle ; pas de résilience zone/région → perte de disponibilité/données sur incident d'infrastructure.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : déclarer `backupPolicy` type `Continuous` (PITR 7/30 j) ; activer `isZoneRedundant:true` en prod ; évaluer une 2ᵉ région + `enableAutomaticFailover:true` selon le SLA visé.
- **Fichiers à modifier** : `infra/modules/cosmos.bicep`, params prod.
- **Validation** : `az bicep build` **PASS**. `[À EXÉCUTER]` — `az cosmosdb show -g <rg> -n <acct> --query "{bp:backupPolicy, zr:locations[0].isZoneRedundant, af:enableAutomaticFailover}"`.
- **Statut** : `Ouvert`.

---

### `F-P6-05` — Aucun endpoint privé / intégration VNet (Function App, Cosmos, KV, Storage) · *Azure / IaC — 6D*
- **Preuve** : recherche `privateEndpoint`/`Microsoft.Network/privateEndpoints` sur `infra/**` → **0** ressource ; le flag `enablePrivateNetworking` (`main.bicep:71-72`, défaut `false`) ne fait que **basculer le `publicNetworkAccess`** des ressources data — sans PE, l'activer met le backend hors ligne (avertissement `prod.bicepparam:74-78`). Toutes les ressources conservent un accès réseau public. Certitude : `[CERTAIN]`.
- **Risque réel** : aucune isolation réseau ; toute la surface data-plane (Cosmos, KV, Storage) et le plan Function App restent exposés au réseau public, protégés uniquement par identité/RBAC.
- **Gravité** : `Faible` · **Probabilité** : `Faible` (RBAC + `disableLocalAuth`/`allowSharedKeyAccess:false` atténuent).
- **Correctif proposé** : introduire un module `privateEndpoint.bicep` (Cosmos, KV, Storage, Function App via Flex/Elastic si supporté) + zones DNS privées + intégration VNet, puis activer `enablePrivateNetworking` de façon cohérente. Chantier transverse (cross-réf `F-P6-03`).
- **Fichiers à modifier** : nouveau `infra/modules/privateEndpoint.bicep`, `infra/main.bicep`, params.
- **Validation** : `az bicep build` **PASS**. `[À EXÉCUTER]` — `az network private-endpoint list -g <rg>` ; `checkov -d infra` (règles PE).
- **Note positive** : la posture RBAC/identity-based (Storage/Cosmos/KV) réduit fortement l'impact en l'absence de PE.
- **Statut** : `Ouvert`.

---

### `F-P6-06` — Rétention App Insights 30 jours (courte pour forensic sécurité) · *Azure / IaC — 6F*
- **Preuve** : `infra/modules/appInsights.bicep:14` `retentionInDays` = `30`. Certitude : `[CERTAIN]`.
- **Risque réel** : fenêtre d'investigation limitée à 30 j — insuffisante pour détecter/analyser des incidents de sécurité à cinétique lente ou des exigences de conformité (souvent 90 j+).
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Correctif proposé** : porter la rétention à 90 j (ou aligner sur la politique de conformité) ; envisager l'export continu vers Storage/LA pour l'archivage long terme.
- **Fichiers à modifier** : `infra/modules/appInsights.bicep:14` (paramétrable par env).
- **Validation** : `az bicep build` **PASS**. `[À EXÉCUTER]` — `az monitor app-insights component show -g <rg> --app <name> --query retentionInDays`.
- **Note positive** : App Insights **workspace-based** adossé à un Log Analytics (bonne base) ; alertes sécurité robustes (cf. positifs P6).
- **Statut** : `Ouvert` (rétention/alerting **applicatif** → complément P9).

---

### `F-P6-07` — Diagnostics/alertes désactivés en dev + `alertEmail` staging vide · *Azure / IaC — 6F*
- **Preuve** : `infra/main.bicep:212` le module `diagnostics` s'exécute `if (env != 'dev')` → **dev sans** diagnostic settings ni alertes ; `infra/params/staging.bicepparam:21` `alertEmail=''` → les alertes staging **ne notifient personne** (le groupe d'action email n'a pas de destinataire) ; prod OK (`prod.bicepparam:52` `alertEmail='secops@certigo.app'`). Certitude : `[CERTAIN]`.
- **Risque réel** : angle mort d'observabilité en dev ; en staging, les alertes 401/403/5xx se déclenchent mais **sans notification** → incidents non vus avant la prod.
- **Gravité** : `Faible` (dev) / `Info` · **Probabilité** : `Faible`.
- **Correctif proposé** : renseigner un `alertEmail` staging (DL secops/eng) ; activer a minima les diagnostic settings (sans forcément les alertes) en dev, ou documenter explicitement l'exclusion comme choix assumé.
- **Fichiers à modifier** : `infra/params/staging.bicepparam:21`, éventuellement `infra/main.bicep:212` (diag en dev).
- **Validation** : `az bicep build` **PASS**. `[À EXÉCUTER]` — `az monitor diagnostic-settings list --resource <id>` ; `az monitor action-group show -g <rg> -n <ag> --query emailReceivers`.
- **Note positive** : en prod, alertes log-search 401/403/5xx (seuil 25/15 min) + groupe d'action email **bien câblés** (`diagnostics.bicep:96-185`).
- **Statut** : `Ouvert`.

---

### `F-P6-08` — NSG du runner CI sans règles (`securityRules:[]`) · *Azure / IaC — CI (recoupe F-P2-01)*
- **Preuve** : `infra/ci-runner/network.bicep:109` `securityRules: []` (NSG créé mais vide) ; `:134` `defaultOutboundAccess:false` ; IP publique statique `20.86.156.64` (`:9`) + NAT Gateway pour l'egress du runner self-hosted. Certitude : `[CERTAIN]`.
- **Risque réel** : le NSG n'ajoute aucune restriction explicite (seules les règles par défaut Azure s'appliquent) → durcissement réseau minimal du subnet du runner. **Angle réseau uniquement** — la criticité SPOF/self-hosted du runner est traitée en `F-P2-01` (pas de double-comptage).
- **Gravité** : `Info` · **Probabilité** : `Faible`.
- **Correctif proposé** : ajouter des `securityRules` explicites (deny inbound par défaut, allow egress ciblé vers Azure DevOps/GitHub + Cosmos/KV/Storage) ; documenter la posture.
- **Fichiers à modifier** : `infra/ci-runner/network.bicep:109`.
- **Validation** : `az bicep build --file infra/ci-runner/network.bicep` `[À EXÉCUTER]` ; `az network nsg show -g <rg> -n <nsg> --query securityRules`.
- **Note positive** : `defaultOutboundAccess:false` + NAT Gateway avec IP statique = egress maîtrisé/traçable.
- **Statut** : `Ouvert` (recoupe `F-P2-01`, sans double-comptage).

---

<!-- ===================== PHASE 7 — Flutter mobile ===================== -->

### `F-P7-01` — ~~Jeton d'auth écrasé par un littéral `'******'`~~ · **RETIRÉ — FAUX POSITIF** · *Mobile / Auth*
- **Statut** : **RETIRÉ — FAUX POSITIF** (ID conservé, jamais réattribué). Certitude : [CERTAIN].
- **Constat** : les octets réels de `packages/data/lib/src/api/api_client.dart:70` sont `options.headers['Authorization'] = 'Bearer $token';` — prouvé par la méthode codes-caractères (fin de ligne = `39 66 101 97 114 101 114 32 36 116 111 107 101 110 39 59` = `'Bearer $token';`, longueur 63). Le `'******'` vu en `git show` brut ET en `git blame` est l'**artefact d'affichage** du redacteur de l'outillage (masquage des chaînes de type Bearer), jamais un octet réel. La provenance `75e52af` / `'******'` invoquée en première rédaction P7 était une **lecture corrompue par l'artefact**.
- **Cohérence P5** : c'est exactement l'artefact déjà identifié et écarté en Phase 5 ; P5 avait raison. En P7 le piège a été rejoué puis corrigé (revue inter-phase).
- **Reclassé POSITIF prouvé** : en-tête `Authorization` correct = `Bearer $token` (`api_client.dart:70`), cohérent avec la preuve codes-caractères de P5. Aucun jeton factice, aucun bearer cassé.
- **Gravité / Probabilité** : `N/A (retiré)`.
- **Correctif** : *aucun* (rien à corriger ; le code est correct).
- **Fichiers** : *aucun*.
- **Validation** : `flutter analyze` (apps/mobile) = PASS ; protocole codes-caractères obligatoire pour toute valeur `Authorization`/Bearer (`******` = artefact d'affichage, jamais un octet réel).

---

### `F-P7-02` — Drift SDK Flutter dans le scan sécurité (« app livrée » ≠ app scannée) · *Mobile / Repro (recoupe F-P3-04/F-P3-07)*
- **Preuve** : `.github/workflows/security-scan.yml:50` `flutter-version: "3.24.0"` vs `3.27.4` utilisé par le CI principal ; aggravé par `pubspec.lock` mobile **gitignoré** (`F-P3-03`). Certitude : `[CERTAIN]`.
- **Risque réel** : l'app scannée/analysée (SDK/toolchain 3.24.0) peut différer de l'app **livrée** (3.27.4) → faux négatifs de sécurité, non-reproductibilité de la chaîne mobile. Certitude : `[PROBABLE]`.
- **Gravité** : `Faible` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : aligner sur une **source unique** de version Flutter (ex. `.flutter-version`/`global`), committer les lockfiles.
- **Fichiers à modifier** : `.github/workflows/security-scan.yml:50`.
- **Validation** : `[À EXÉCUTER]` `grep -R "flutter-version" .github/workflows`.
- **Statut** : `Ouvert` (recoupe `F-P3-04`/`F-P3-07`, sans double-comptage — **angle « app mobile livrée »**).

---

### `F-P7-03` — Accessibilité : étiquetage sémantique clairsemé, aucun test a11y · *Mobile / A11y*
- **Preuve** : `~12/82` fichiers de `apps/mobile/lib` référencent `Semantics`/`semanticLabel` (grep) ; les contrôles à **icône seule** sont probablement non étiquetés ; aucun test d'accessibilité (`androidTapTargetGuideline`/`textContrastGuideline`) trouvé dans `apps/mobile/test`. Certitude : `[PROBABLE]` (échantillon grep, non exhaustif écran par écran).
- **Risque réel** : lecteurs d'écran (TalkBack/VoiceOver) dégradés, cibles tactiles < 48 dp possibles → exclusion d'utilisateurs, risque de conformité. Certitude : `[PROBABLE]`.
- **Gravité** : `Faible` · **Probabilité** : `Moyenne`.
- **Correctif proposé** : ajouter `Semantics`/`semanticLabel` sur les contrôles à icône, garantir des cibles ≥ 48 dp, ajouter des golden tests a11y.
- **Fichiers à modifier** : écrans de `apps/mobile/lib/features/**/presentation/`.
- **Validation** : `[À EXÉCUTER]` `flutter test` avec `meetsGuideline(androidTapTargetGuideline)` / `textContrastGuideline`.
- **Statut** : `Ouvert`.

---

### `F-P7-04` — File de synchro offline persistée en clair (SharedPreferences) · *Mobile / Données*
- **Preuve** : `apps/mobile/lib/app/offline/prefs_sync_store.dart:6` clé `certigo.sync.queue.v1` ; l.16-21 `getString`/`setString` (JSON en clair). Charges = **actions de jeu** (submit-attempt/purchase), **PAS** de jetons. Certitude : `[CERTAIN]` (observable).
- **Risque réel** : sur device compromis/rooté, lecture/altération de la file de synchro (métadonnées de jeu). Impact **limité** : le back reste **server-authoritative** (P4) et aucun secret n'y transite. Certitude : `[PROBABLE]`.
- **Gravité** : `Faible` · **Probabilité** : `Faible`.
- **Note positive** : le jeton OIDC est bien stocké en `flutter_secure_storage` (Keychain/Keystore, cf. `F-P5-06`), **pas** ici.
- **Correctif proposé** (optionnel) : chiffrer la file au repos si les métadonnées sont jugées sensibles.
- **Fichiers à modifier** : `apps/mobile/lib/app/offline/prefs_sync_store.dart`.
- **Validation** : `[À EXÉCUTER]` `adb shell run-as <pkg> cat shared_prefs/*.xml`.
- **Statut** : `Ouvert`.

---

### `F-P7-05` — Crash-reporting mobile non câblé (TODO observabilité) · *Mobile / Observabilité — routé P9*
- **Preuve** : `apps/mobile/lib/bootstrap/bootstrap.dart:42-45` — `FlutterError.onError` porte `TODO(observability): forward to Application Insights via a Crash service.` (aucun envoi effectif). Certitude : `[CERTAIN]`.
- **Risque réel** : crashes mobiles non collectés → cécité opérationnelle. Certitude : `[PROBABLE]`.
- **Gravité** : `Info` (ici) — **remédiation routée en Phase 9** (observabilité/ops), non traitée en P7 (pas de débordement de périmètre).
- **Correctif proposé** : câbler un service crash → App Insights (P9).
- **Fichiers à modifier** : `apps/mobile/lib/bootstrap/bootstrap.dart` (P9).
- **Validation** : `[À EXÉCUTER]` (P9) provoquer un crash de test + vérifier l'ingestion App Insights.
- **Statut** : `Ouvert` (lead routé P9).

---

**Points positifs prouvés (P7) — non scorés :**
- `flutter analyze` (apps/mobile) = **PASS réel** (« No issues found! », 181,9 s, exit 0).
- Jeton OIDC en `flutter_secure_storage` (`SecureSessionStore`) — approfondit `F-P5-06` (positif).
- Auth **OIDC Authorization Code + PKCE** (`features/auth/application/auth_gateway.dart`).
- **Aucun** jeton/secret dans les logs Dio : l'intercepteur debug (`api_client.dart:39-63`) journalise méthode/URL/statut, pas les en-têtes.
- `SyncEngine` de **haute qualité** : idempotence, dead-letter, backoff, coalescing, prune, horloge injectée (offline engine robuste).
- Archi **feature-first** propre ; le package `data` est **Flutter/auth-free** (bonne séparation des couches).
- Gardes de route **testables** ; les écrans sont pilotés par de **vrais repositories** avec grading **server-authoritative** (`features/quiz/presentation/quiz_screen.dart:52-56` — corrobore P4).
- **Comptages de tests réels** : `apps/mobile/test` = **24** `*_test.dart` ; `packages/**` = **29** (couverture % non calculée — nécessiterait `flutter test --coverage`, `[À EXÉCUTER]`).

---

**Modèle de fiche (à utiliser dès P1) :**

> ### `F-P<phase>-<NN>` — Titre court · *Domaine*
> - **Preuve** : `chemin/fichier:ligne` (extrait ou description précise). Certitude : `[CERTAIN|PROBABLE|À VÉRIFIER|INCONNU]`
> - **Risque réel** : conséquence concrète (sécurité, intégrité, disponibilité, coût, conformité…).
> - **Gravité** : `Critique|Élevée|Moyenne|Faible|Info` · **Probabilité** : `Élevée|Moyenne|Faible`.
> - **Correctif proposé** : description localisée et sûre.
> - **Fichiers modifiés** : (si correctif appliqué) liste.
> - **Validation** : commande + résultat **ou** `[À EXÉCUTER]` + commande exacte.
> - **Statut** : `Ouvert|En cours|Corrigé|Atténué|Accepté|Faux positif|Hors périmètre`.

### Tableau de synthèse des findings

| ID | Titre | Domaine | Gravité | Probabilité | Statut | Phase |
|---|---|---|---|---|---|---|
| `F-P1-01` | Ex-god-file éclaté en 11 services — cohésion **confirmée** (hypothèse infirmée) | Backend / Archi | Faible | Faible | Clôturé (→F-P4-04) | P4 |
| `F-P2-01` | SPOF runner self-hosted `certigo-ci` (fallback quasi absent) | CI-CD / Dispo | Élevée | Moyenne | Ouvert | P2 |
| `F-P2-02` | CodeQL (SAST) ne gate pas les PR (schedule-only) | CI-CD / Sécu | Moyenne | Moyenne | Ouvert | P2 |
| `F-P2-03` | Scans deps/IaC non bloquants sur PR | CI-CD / Sécu | Moyenne | Moyenne | Ouvert | P2 |
| `F-P2-04` | Actions non épinglées SHA (dont publish Google Play) | CI-CD / Supply-chain | Moyenne | Faible | Ouvert | P2 |
| `F-P2-05` | Pas de `global.json` + SDK flottant + drift Flutter | CI-CD / Repro | Moyenne | Moyenne | Instruit→P3 | P3 |
| `F-P2-06` | Couverture mobile mesurée non seuillée | CI-CD / Qualité | Faible | Moyenne | Ouvert | P2 |
| `F-P2-07` | `ci-content` audit npm/pip non bloquant + `npm install` | CI-CD / Repro | Faible | Faible | Ouvert | P2 |
| `F-P2-08` | Protection prod (reviewers) non vérifiable dans le code | CI-CD / Gouvernance | Moyenne | Faible | Ouvert | P2 |
| `F-P2-09` | [Correction] `promote` sans `runs-on` = normal (caller) | CI-CD / Cartographie | Info | — | Infirmé | P2 |
| `F-P3-01` | Pas de `global.json` → SDK .NET flottant | Repro / .NET | Moyenne | Moyenne | Ouvert | P3 |
| `F-P3-02` | Pas de lockfile NuGet ni CPM → transitives non repro | Repro / .NET | Moyenne | Moyenne | Ouvert | P3 |
| `F-P3-03` | `pubspec.lock` mobile gitignoré → app livrée non verrouillée | Repro / Flutter | Élevée | Moyenne | Ouvert | P3 |
| `F-P3-04` | SDK Flutter sans source unique + drift 3.24/3.27/local | Repro / Flutter | Élevée | Moyenne | Ouvert | P3 |
| `F-P3-05` | `npm install --no-save` contourne le lockfile | Repro / Node | Faible | Faible | Ouvert | P3 |
| `F-P3-06` | `package.json` racine : nom générique + test factice | Hygiène / Node | Faible | Faible | Ouvert | P3 |
| `F-P3-07` | Drift versions d'actions (tags existants, aucun pin SHA) | Supply-chain / CI | Moyenne | Faible | Ouvert | P3 |
| `F-P3-08` | Currency Functions Worker v1→v2 ; CVE Bcl.Memory non tranchée | Sécu / .NET | Moyenne | Faible | Ouvert | P3 |
| `F-P3-09` | `dependabot.yml` probablement inerte (EMU) → fausse sécu | Supply-chain / Auto | Moyenne | `[INCONNU]` | Ouvert | P3 |
| `F-P3-10` | Drift `flutter_lints` ^6.0.0 vs ^4.0.0 entre packages | Hygiène / Flutter | Faible | Faible | Ouvert | P3 |
| `F-P4-01` | Résilience concurrence hétérogène (récompense perdue au rejeu) | Backend / Cosmos | Moyenne | Faible-Moyenne | Ouvert | P4 |
| `F-P4-02` | Idempotence multi-conteneurs non atomique (chemin monétaire) | Backend / Cosmos | Moyenne | Faible-Moyenne | Ouvert | P4 |
| `F-P4-03` | Clé JWT dérivable + validateur HS256 local actif en prod | Backend / Sécu | Élevée | Faible-Moyenne | Ouvert | P4 |
| `F-P4-04` | Verdict cohésion F-P1-01 : god-file infirmé (nit) | Backend / Archi | Faible | Faible | Clôturé | P4 |
| `F-P5-01` | Secrets applicatifs injectés en clair dans les app settings | Sécurité / Infra-App | Moyenne | Moyenne | Ouvert | P5 |
| `F-P5-02` | Absence de throttling IP/global (lockout par compte seul) | Sécurité / Anti-abus | Moyenne | Moyenne | Ouvert | P5 |
| `F-P5-03` | Énumération de comptes (register + canal temporel login) | Sécurité / Auth | Faible | Moyenne | Ouvert | P5 |
| `F-P5-04` | PBKDF2 100k itérations (< 600k OWASP 2023) | Sécurité / Crypto | Faible | Faible | Ouvert | P5 |
| `F-P5-05` | Algorithmes JWT non épinglés (`ValidAlgorithms`) | Sécurité / JWT | Faible | Faible | Ouvert | P5 |
| `F-P5-06` | Jetons 1j/90j sans révocation | Sécurité / Session | Faible | Faible | Ouvert | P5 |
| `F-P5-07` | En-têtes HTTP incomplets (CSP + `no-store`) | Sécurité / En-têtes | Faible | Faible | Ouvert | P5 |
| `F-P5-08` | Pas de plafond applicatif de taille de corps | Sécurité / Validation | Faible | Faible | Ouvert | P5 |
| `F-P5-09` | CORS `*` limité au dev | Sécurité / CORS | Faible | Faible | Ouvert | P5 |
| `F-P6-01` | Clé JWT dérivable `guid()` déterministe (prod) | Azure / IaC — 6E | Élevée | Moyenne | Ouvert | P6 |
| `F-P6-02` | 3 secrets Function App en clair, 0 réf Key Vault | Azure / IaC — 6B | Moyenne | Moyenne | Ouvert | P6 |
| `F-P6-03` | Cosmos `publicNetworkAccess` sans pare-feu IP/VNet | Azure / IaC — 6A | Moyenne | Faible | Ouvert | P6 |
| `F-P6-04` | Cosmos sans `backupPolicy`/PITR, mono-région | Azure / IaC — 6A | Faible | Faible | Ouvert | P6 |
| `F-P6-05` | Aucun endpoint privé / intégration VNet | Azure / IaC — 6D | Faible | Faible | Ouvert | P6 |
| `F-P6-06` | Rétention App Insights 30 j | Azure / IaC — 6F | Faible | Faible | Ouvert | P6 |
| `F-P6-07` | Diag/alertes off en dev + `alertEmail` staging vide | Azure / IaC — 6F | Faible | Faible | Ouvert | P6 |
| `F-P6-08` | NSG runner CI vide (recoupe F-P2-01) | Azure / IaC — CI | Info | Faible | Ouvert | P6 |
| `F-P7-01` | ~~Jeton d'auth écrasé~~ **RETIRÉ — faux positif** (artefact `******` ; l.70 = `Bearer $token`) | Mobile / Auth | — | — | **Retiré** | P7 |
| `F-P7-02` | Drift SDK Flutter dans security-scan (« app livrée ») | Mobile / Repro | Faible | Moyenne | Ouvert | P7 |
| `F-P7-03` | A11y : étiquetage sémantique clairsemé, aucun test | Mobile / A11y | Faible | Moyenne | Ouvert | P7 |
| `F-P7-04` | File offline persistée en clair (SharedPreferences) | Mobile / Données | Faible | Faible | Ouvert | P7 |
| `F-P7-05` | Crash-reporting mobile non câblé (routé P9) | Mobile / Observabilité | Info | — | Ouvert (→P9) | P7 |

---

## 6. Remédiation appliquée

> Correctifs **réellement implémentés** au cours de l'audit neuf, regroupés par phase, avec fichiers
> touchés et validation. **Vide à l'issue de P0** (aucune modification de code).

> **P1 → P4** : aucune remédiation de code appliquée. En **P2** (CI/CD & runners) et **P3** (dépendances &
> reproductibilité), les correctifs des findings `F-P2-01…08` et `F-P3-01…10` sont **décrits** dans leurs
> fiches (§ 5 : patch proposé + fichiers cibles + validation `[À EXÉCUTER]`) conformément à la discipline
> « audit only » des phases ; ils seront implémentés lors des phases de remédiation dédiées. En **P3**,
> `F-P2-05` a été **instruit et scindé** (→ `F-P3-01` SDK .NET + `F-P3-04` drift Flutter), sans code.
> `F-P2-09` est une **correction de cartographie** (lead P1 infirmé), sans code. En **P4** (backend
> critique), audit **sans aucun correctif de code** : les findings `F-P4-01…03` sont **décrits** (patch
> proposé + fichiers + validation) ; `F-P4-04` clôt `F-P1-01` (hypothèse god-file **infirmée** — aucune
> action requise, simple nit facultatif). Les **deux validations** de P4 (`dotnet build -warnaserror`
> 0/0 · `dotnet test` 525/0/6) ont été **réellement exécutées** (§ 4 journal P4). En **P5** (sécurité
> applicative), audit **sans aucun correctif de code** : les 9 findings `F-P5-01…09` sont **décrits** (patch
> proposé + fichiers + validation). Le volet **APP** de `F-P4-03` est **clos** en P5 (`F-P5-01` prouve
> l'injection de `AUTH_JWT_SIGNING_KEY` en **clair** dans les app settings, sans référence Key Vault) ; le
> volet **dérivation infra** (`main.bicep:82` `guid(...)`) reste **croisé P6**. Aucun `build`/`test` .NET
> **re-exécuté** en P5 (aucun code touché) ; validations P5 réelles = `git grep` motifs de secrets (propre) +
> revue paramétrage requêtes Cosmos (aucune injection NoSQL) + vérification char-codes (artefact `******` =
> **rédaction de l'outillage**, pas le dépôt) ; `gitleaks`/`trufflehog` restent `[À EXÉCUTER]` (outils absents).

> **P6** (Azure / IaC) : audit **sans aucun correctif de code (Bicep)** ; les 8 findings `F-P6-01…08` sont
> **décrits** (correctif documenté + fichiers cibles + validation). Deux **clôtures de leads** : `F-P6-01`
> clôt le **volet infra** de `F-P4-03` (chaîne prouvée `main.bicep:82` `guid(...)` déterministe → `prod.bicepparam:64-68`
> clé vide → `functionApp.bicep:148` app setting `AUTH_JWT_SIGNING_KEY` → jetons prod HS256 **forgeables**) ; `F-P6-02`
> clôt la **remédiation infra** de `F-P5-01` (3 secrets en clair `functionApp.bicep:148/156/164`, **0** référence
> `@Microsoft.KeyVault`, aucune ressource secret dans `keyvault.bicep` → migration `SecretUri` documentée). Validation
> **réellement exécutée** en P6 : `az bicep build --file infra/main.bicep` → **compile propre** (exit 0, ≈ 77 ko ARM,
> 0 erreur/0 warning ; contournement encodage Windows `PYTHONUTF8=1` + `--outfile`). Restent `[À EXÉCUTER]` :
> `checkov -d infra` (outil absent) et `az deployment sub what-if` (nécessite `az login` + réseau).

> **P7** (Flutter mobile) : audit **sans aucun correctif de code (Dart)** ; **4 findings** `F-P7-02…05`
> **décrits** (correctif documenté + fichiers cibles + validation). **`F-P7-01` RETIRÉ — faux positif** :
> `packages/data/lib/src/api/api_client.dart:70` = `Bearer $token` **correct** (prouvé **codes-caractères** :
> `66 101 97 114 101 114 32 36 116 111 107 101 110`) ; le `'******'` vu en `git show`/`git blame` **brut** =
> **artefact d'affichage** de l'outillage (masque les chaînes `Bearer`), **pas** un octet réel — **même
> artefact écarté en P5** (aucun jeton factice). `F-P7-05` (crash-reporting non câblé) **routé P9**. Validations
> **réellement exécutées** en P7 : `flutter analyze` (apps/mobile) → **PASS** (exit 0) ; `flutter test`
> (apps/mobile) → **exit 1 — 113 réussis / 15 échoués** (les 15 = crash de compilation `google_fonts-6.2.1`
> sous **Dart 3.12.2 local**, artefact d'outillage **pas** de la logique → renforce `F-P7-02`/`F-P3-03/04`) ;
> `dart format --output=none --set-exit-if-changed --line-length 100 .` → exit 1 (83/214, **artefact de version**
> SDK, **aucun** fichier réécrit). Restent `[À EXÉCUTER]` : suite mobile sous **SDK épinglé 3.27.4**,
> `melos run analyze`/`test` (melos absent), test widget ciblant l'en-tête `Authorization`.

_Aucune remédiation de code appliquée à ce stade (P0 → P7 = audit ; correctifs P2 → P7 décrits, non
implémentés)._

| Phase | Finding | Correctif | Fichiers | Validation |
|---|---|---|---|---|
| _(vide)_ | — | — | — | — |

---

## 7. Checklist de reprise rapide

- [x] **P0** — Init & doc pilote (archivage annexe `9c488c6` + squelette phasé) · commit `cdd8f30`+
- [x] **P1** — Cartographie du dépôt (763 fichiers · ≈ 57 k LOC · 34 endpoints · 14 workflows) · état `90cc431`
- [x] **P2** — CI/CD & runners (14 workflows · 9 findings ouverts + `F-P2-09` infirmé) · état `9efd36a`
- [x] **P3** — Dépendances & reproductibilité (10 findings `F-P3-01…10` · scans réels .NET/Flutter) · état `d9c9c6e`
- [x] **P4** — Backend critique (3 findings ouverts `F-P4-01…03` + `F-P4-04` clôturant `F-P1-01` · build 0/0 + tests 525/0/6 réels)
- [x] **P5** — Sécurité applicative (9 findings `F-P5-01…09` : 2 Moyenne + 7 Faible/Info · volet APP de `F-P4-03` clos · `git grep` propre + Cosmos paramétré + char-codes `[CERTAIN]` · `gitleaks`/`trufflehog` `[À EXÉCUTER]`) · commit `b796cf5`
- [x] **P6** — Azure / IaC (6A–6F) (8 findings `F-P6-01…08` : 1 Élevée + 2 Moyenne + 4 Faible + 1 Info · volet **infra** de `F-P4-03` clos par `F-P6-01` · remédiation **infra** de `F-P5-01` close par `F-P6-02` · `az bicep build` **réellement exécuté = compile propre** · `checkov`/`what-if` `[À EXÉCUTER]`) · commit `5e43e4e`
- [x] **P7** — Flutter mobile (4 findings `F-P7-02…05` : 3 Faible + 1 Info · `F-P7-01` **retiré — faux positif** artefact d'affichage `******` ; `api_client.dart:70` = `Bearer $token` prouvé codes-caractères, cohérent P5 · `F-P7-05` crash-reporting **routé P9** · `flutter analyze` **PASS** · `flutter test` **exit 1 — 113/15** artefact `google_fonts`×Dart 3.12.2 · `dart format` exit 1 83/214 artefact version · SDK épinglé/melos `[À EXÉCUTER]`) · commit `ed3d921` · **correction (retrait F-P7-01)** commit `⟨backfill P8⟩`
- [ ] **P8** — Contenu & tooling
- [ ] **P9** — Observabilité / ops
- [ ] **P10** — Release engineering
- [ ] **P11** — Cohérence documentaire
- [ ] **P12** — Rapport de synthèse final

**Pour reprendre maintenant :** exécuter la **Phase 8 — Contenu & tooling** (schémas JSON du contenu,
validateur de contenu, seed, séparation `answerKey`/données publiques), en croisant les leads déjà routés :
`F-P4` (économie server-authoritative vs contenu de jeu) et la cohérence contenu ↔ back. Backfill du hash **P7**
en tête de l'entrée journal P7 (§ 4) et dans la checklist P7 (§ 7) — l'entrée P7 porte le placeholder honnête
`⟨backfill P8⟩` (un commit ne peut pas contenir son propre hash). Puis mettre à jour ce doc, committer et **STOP**.

---

## 8. Annexe — Rapport précédent (commit 9c488c6)

Le rapport d'audit précédent est **archivé intégralement, sans perte**, dans un fichier séparé :

➡️ **[`AUDIT_Certigo_annexe_9c488c6.md`](AUDIT_Certigo_annexe_9c488c6.md)**

| Attribut | Valeur |
|---|---|
| Commit d'ancrage | `9c488c6` — `9c488c6246c5f2f4a5906599480cc90e6b35fbf3` (2026-06-23, PR #49) |
| Taille | 58 713 octets (~57 KB) · 735 lignes |
| Contenu | Sections **A → M** : executive summary, état, points forts, problèmes `D1–D18`, zones d'ombre, dette, matrice des risques, recommandations `H…`, priorisation, roadmap, scorecard, conclusion (7 questions), et **Section M** « Remédiation appliquée » (D1–D18) |
| Statut vis-à-vis de l'audit neuf | **Référence historique**. Ses conclusions et ses ✅ **ne sont pas** repris tels quels : chaque point sera **re-dérivé depuis le code** aux phases P1–P12. |

> ⚠️ **Rappel de méthode.** L'audit neuf ne fait **aucune confiance** aux ✅ de l'annexe. Toute
> assertion de l'annexe (existence de code à un emplacement, passage de tests, remédiation « faite »)
> devra être **re-vérifiée** et re-sourcée dans le nouveau registre des findings.

---

<sub>Document pilote de l'audit neuf, ancré sur le commit `cdd8f30`. Chaque conclusion future sera
reliée à un élément observable (`fichier:ligne`). Les validations non exécutées sont marquées
`[À EXÉCUTER]` avec leur commande exacte. Rapport précédent (`9c488c6`) préservé intégralement en
annexe.</sub>
