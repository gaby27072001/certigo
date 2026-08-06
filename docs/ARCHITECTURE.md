# Architecture — Certigo

Ce document décrit l'architecture de référence du monorepo : frontend Flutter, backend
.NET 8 Azure Functions, moteur pédagogique Cortex, contenu *as-code* et flux de données.

> Rappel produit : Certigo enseigne des **concepts techniques réels** et prépare aux
> certifications Microsoft (AZ-900, AZ-104, AI-900, DP-900). Ce **n'est pas** une app de langues.

---

## 1. Principes directeurs

1. **Feature-first** côté mobile, **Clean Architecture** côté backend — la logique métier ne
   dépend jamais d'un framework ou d'une base.
2. **Le domaine est roi.** Les règles (readiness, FSRS, XP) vivent dans des unités pures,
   testables sans I/O, dupliquées à l'identique client/serveur.
3. **Le serveur est l'autorité.** La notation des quiz, le calcul du Readiness Score et
   l'attribution d'XP sont recalculés côté API ; le client n'en fait qu'une projection optimiste.
4. **Le contenu est du code.** Le dépôt
   [`certigo-content`](https://github.com/gchambaud_microsoft/certigo-content) est la source
   éditoriale active : contenu public, clés de correction, schémas et manifeste y sont versionnés
   et validés avant publication. Le dossier `content/` de ce monorepo est historique.
5. **Le design est un package.** Prism est isolé (`packages/prism_ui`) et réutilisable.

---

## 2. Vue d'ensemble

```
┌───────────────────────────── apps/mobile (Flutter) ─────────────────────────────┐
│  features/*  ── presentation (écrans, widgets)                                   │
│      │           state: Riverpod providers                                       │
│      ▼                                                                            │
│  packages/data  ── models · api_client (Dio-like) · repositories                 │
│  packages/cortex ── FSRS · mastery · readiness  (projection client)              │
│  packages/core   ── env · Result · Failures                                      │
│  packages/prism_ui ── design system (tokens · thème · composants)                │
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                     │ HTTPS + JWT (Entra External ID)
                                     ▼
┌──────────────────────── backend (.NET 8 isolated Functions) ─────────────────────┐
│  Certigo.Api            HTTP triggers · JwtAuthMiddleware · ExceptionMiddleware │
│      │                                                                            │
│      ▼                                                                            │
│  Certigo.Application    services métier · DTO · abstractions (ports)           │
│      │                                                                            │
│      ▼                                                                            │
│  Certigo.Domain         readiness · FSRS · XP · modèles (AUCUNE dépendance)     │
│      ▲                                                                            │
│  Certigo.Infrastructure Cosmos repositories · Entra token validator (adapters) │
└───────────────────────────────────┬──────────────────────────────────────────────┘
                                     ▼
                Azure Cosmos DB · Blob Storage · Key Vault · App Insights
```

Le **sens des dépendances** backend : `Api → Application → Domain ← Infrastructure`.
`Domain` ne référence personne ; `Infrastructure` implémente les ports déclarés par
`Application`. C'est l'inversion de dépendance classique de la Clean Architecture.

---

## 3. Frontend Flutter

### 3.1 Découpage

- **`apps/mobile`** — la coquille applicative : bootstrap, providers, routing, shell de
  navigation et les `features/` (chacune avec sa couche `presentation`).
- **`packages/prism_ui`** — design system Prism. Tokens (`prism_colors`, `prism_spacing`,
  `prism_radii`, `prism_elevation`, `prism_motion`, `prism_typography`), thème
  (`PrismTheme.light()/.dark()` + `PrismColorScheme` exposé en `ThemeExtension`, accès
  ergonomique `context.prism`) et composants : surfaces (`GlassSurface`,
  `AuroraBackground`), actions (`PrismButton`), progression (`PrismProgressBar`,
  `ReadinessGauge`), gamification (`StreakBadge`, `XpChip`, `StatPill`), apprentissage
  (`LessonTile`, `QuizOptionTile`).
- **`packages/data`** — modèles (miroir camelCase des DTO backend, `fromJson` manuel),
  `api_client` et `repositories`.
- **`packages/cortex`** — moteur FSRS / mastery / readiness en Dart pur (testé).
- **`packages/core`** — `AppEnv`, `Result<T>`, `Failure`.

### 3.2 État & navigation

- **Riverpod** (providers simples, sans codegen) : `tokenProvider`, `apiClientProvider`, les
  repositories, et `themeModeProvider` (`StateProvider`) pour le light/dark.
- **go_router** via `routerProvider` : `StatefulShellRoute.indexedStack` pour les 4 onglets
  (home · path · leaderboard · profile) plus deux routes plein écran (`/lesson/...`,
  `/quiz/...`). Les constantes vivent dans `Routes`.

### 3.3 Note d'implémentation

Le code est volontairement **sans génération de code** (pas de freezed / build_runner /
json_serializable) : `fromJson` manuels, providers simples. Cela garde chaque fichier
auto-suffisant et compilable sans étape de codegen — un compromis assumé pour la robustesse du
squelette. La migration vers freezed reste possible (les `*.g.dart`/`*.freezed.dart` sont déjà
gitignorés).

---

## 4. Backend .NET 8

### 4.1 Projets

| Projet | Responsabilité |
|---|---|
| `Certigo.Domain` | Modèles + règles pures : `ReadinessCalculator`, `ReviewScheduler` (FSRS), XP, gamification, contenu. Zéro dépendance externe. |
| `Certigo.Application` | Services d'orchestration, DTO (`Dtos.cs`), abstractions/ports (`CoreAbstractions.cs`). |
| `Certigo.Infrastructure` | Adapters Cosmos (`CosmosContext`, repositories, sérialiseur System.Text.Json), validation token Entra. |
| `Certigo.Api` | HTTP triggers (`*Functions.cs`), `JwtAuthMiddleware`, `ExceptionMiddleware`, `FunctionUserContext`. |
| `Certigo.Domain.Tests` | xUnit — couvre FSRS, readiness, XP. |

### 4.2 Endpoints

| Méthode | Route | Fonction |
|---|---|---|
| `GET`  | `/me` | `UserFunctions` |
| `GET`  | `/me/paths/{trackId}` | `PathFunctions` |
| `GET`  | `/tracks/{trackId}/lessons/{lessonId}` | `LessonFunctions` |
| `POST` | `/quiz/{lessonId}/submit` | `QuizFunctions` |
| `GET`  | `/me/league` | `LeaderboardFunctions` |

**Règles transverses** : `userId` est extrait du JWT (`FunctionUserContext`), jamais du corps.
Les soumissions de quiz sont **idempotentes** via `clientAttemptId`. Les `QuizItem` envoyés au
client n'embarquent pas la réponse correcte (notation serveur).

### 4.3 Configuration consommée

`Cosmos__Endpoint`, `Cosmos__Database`, `KeyVault__Uri`, `Auth__Issuer`, `Auth__Audience`.
En local : `local.settings.json` (gabarit `.example` fourni, fichier réel gitignoré).

---

## 5. Données — Cosmos DB

Base `certigo`, mode **serverless**. Huit containers, partitionnés pour la localité des accès :

| Container | Partition key | Contenu |
|---|---|---|
| `users` | `/id` | profil, stats lifetime (avec ETag pour la concurrence optimiste) |
| `content` | `/trackId` | tracks, leçons publiques, clés de réponse |
| `progress` | `/userId` | maîtrise par concept, état FSRS |
| `attempts` | `/userId` | tentatives de quiz/examen (id déterministe `attempt::{clientAttemptId}` → idempotence atomique) |
| `events` | `/userId` | événements analytics |
| `leaderboard` | `/periodLeagueId` | classements hebdomadaires |
| `economy` | `/userId` | gemmes, achats boutique (id déterministe `purchase::{clientPurchaseId}`) |
| `friends` | `/userId` | graphe social (deux arêtes dirigées par amitié) |

La partition par `/userId` garde toutes les lectures d'un utilisateur dans une seule
partition logique (progression, tentatives, événements) — requêtes mono-partition, coût maîtrisé.

---

## 6. Cortex — moteur pédagogique

Cortex est **dupliqué à l'identique** en Dart (`packages/cortex`) et en C#
(`Certigo.Domain`). Mêmes constantes, mêmes formules, **même planification en
jours fractionnaires** — la parité est verrouillée par des **golden tests partagés**
(`cortex_golden_test.dart` ↔ `CortexParityTests.cs`). Le client anticipe, le serveur tranche.
*(Des divergences mineures subsistent sur les champs `dueAt` et `recency` entre les deux implémentations ; elles feront l'objet de golden tests dédiés.)*

- **Grades de révision** : `again=1`, `hard=2`, `good=3`, `easy=4`.
- **Dérivation depuis une réponse** : faux → `again` ; <4 s → `easy` ; <9 s → `good` ; sinon `hard`.
- **Readiness par domaine** : `100 · couverture^0.5 · maîtrise^1.0 · récence^0.3`,
  avec `récence = exp(-jours/30)`.
- **Readiness track** : somme pondérée par les poids d'examen des domaines (Σ poids = 1.0).

Exemple AZ-900 — poids des domaines : `cloud-concepts 0.28`, `architecture-services 0.38`,
`management-governance 0.34`.

---

## 7. Contenu *as-code*

```
certigo-content/             # dépôt éditorial actif
├─ content/public/questions/ # payloads publics, sans réponses
├─ content/answerKey/solutions/ # clés de correction privées
├─ schemas/                  # contrats versionnés
└─ tools/                    # validation et génération du manifeste immuable

Certigo/content/             # instantané historique, non éditorial
```

- **Source de vérité** : toute évolution éditoriale passe par une PR dans `certigo-content`.
- **Séparation public/privé** : les payloads servis au client ne contiennent aucune réponse ;
  les `answerKey` restent côté serveur.
- **Validation et publication** : la CI du dépôt éditorial valide les schémas et l'intégrité,
  puis produit un manifeste immuable adressable par hash.
- **Compatibilité** : `Certigo/content/` et ses outils de seed historiques restent disponibles
  pendant la transition, sans constituer une source éditoriale concurrente.

---

## 8. Flux d'une soumission de quiz

```
1. Le client affiche un QuizItem (sans la bonne réponse).
2. L'utilisateur répond ; Cortex (client) projette XP/streak pour un retour immédiat.
3. POST /quiz/{lessonId}/submit  { clientAttemptId, trackId, startedAt, answers }
4. JwtAuthMiddleware → userId.  Si clientAttemptId déjà vu → renvoie le résultat mémorisé.
5. Le serveur corrige via la clé answerKey, recalcule la maîtrise (FSRS), l'XP et le Readiness.
6. Réponse : { scorePct, results[], rewards, weakConcepts[], nextReviewDueAt }.
7. Le client réconcilie sa projection avec la vérité serveur.
```

---

## 9. Infrastructure (Bicep)

`infra/main.bicep` est *subscription-scoped* : il crée le resource group puis compose les
modules. `params/dev.bicepparam` porte les valeurs d'environnement.

| Module | Crée |
|---|---|
| `cosmos.bicep` | compte Cosmos serverless + **8 containers** (PK verrouillées) |
| `storage.bicep` | StorageV2 + container `lesson-assets` |
| `appInsights.bicep` | Application Insights *workspace-based* |
| `keyvault.bicep` | Key Vault (modèle RBAC) |
| `functionApp.bicep` | plan Y1 Linux, `dotnet-isolated` 8.0, *managed identity*, rôle *Key Vault Secrets User*, app settings |

---

## 10. CI/CD

17 workflows au total (15 actifs, 2 legacy iOS manuels et inertes par défaut) ciblés par chemin ou par événement (voir `.github/workflows/`) :
`ci-mobile`, `ci-backend`, `ci-content`, `ci-cortex-parity`, `ci-infra`,
`ci-migration-registry`, `cd-backend`, `codeql`, `dependency-vuln-scan`,
`deploy-privacy-policy`, `lint-workflows`, `release-android`, `security-scan`,
`promote-backend-staging-prod`, `runner-resilience-drill`. Les workflows iOS GitHub Actions
`release-ios` et `sync-ios-certs` sont conservés comme historique ; ils exigent
l'opt-in manuel `enable_legacy_workflow=true`. La chaîne iOS active passe par Codemagic.

---

## 11. Décisions d'architecture (résumé)

| # | Décision | Raison |
|---|---|---|
| ADR-01 | Azure Functions isolated plutôt qu'un service hébergé permanent | coût serverless, scaling à zéro, alignement « jobs » |
| ADR-02 | Cosmos DB plutôt que SQL relationnel | données documentaires (leçons/progression), partition par utilisateur, latence faible |
| ADR-03 | Cortex dupliqué client/serveur | UX optimiste sans sacrifier l'autorité serveur |
| ADR-04 | Contenu *as-code* dans `certigo-content` | source éditoriale dédiée, revue par PR, validation CI, pas de CMS à maintenir |
| ADR-05 | Pas de codegen Dart au départ | fichiers auto-suffisants, squelette robuste ; migration freezed possible plus tard |
| ADR-06 | Pas de cœurs / vies dans la gamification | éviter la frustration ; motiver la régularité, pas la punition |
| ADR-011 | Intégrité serveur-autoritatif : `userId` **toujours** issu du JWT (jamais du corps de requête) + idempotence par `clientAttemptId` et ids déterministes sur récompenses/achats | empêcher l'usurpation d'identité côté client et le double-crédit sur rejeu réseau (voir §12.1) |
| ADR-012 | Intégrité de la gamification : **ETag sur toutes les écritures d'économie**, progression multi-document **atomique** (`TransactionalBatch`), et **plafonds anti-abus `RateWindow` en enforcement** (XP/tentatives sur 1 h, lus du conteneur réel) | rendre les plafonds de cadence effectifs (plus dormants) et confirmer la non-régression du durcissement économie/gamification (voir §12.2) |

---

## 12. Durcissement & intégrité (remédiation post-audit)

Garanties ajoutées à l'issue de l'audit technique (voir `AUDIT_CERTIGO.md`) :

| Domaine | Garantie |
|---|---|
| **Intégrité de l'économie** | Profil utilisateur protégé par **concurrence optimiste (ETag `_etag`)** + retry (`OptimisticConcurrency`) → plus d'écritures perdues. Tentatives/achats/examens à **id déterministe** (`attempt::`, `purchase::`, `examattempt::`) → idempotence **atomique** (création qui échoue sur doublon), sens d'échec sûr (au pire récompense rejouable, jamais de double crédit). |
| **Sécurité auth** | `DevTokenValidator` **verrouillé hors développement** (`AuthValidatorSelection`, garde de production explicite ; `AUTH_MODE=dev` rejeté en prod sauf override non-prod). |
| **Parité Cortex** | Planification en **jours fractionnaires** alignée client/serveur, garantie par des **golden tests partagés**. |
| **Frontière HTTP** | JSON malformé → **400** ; conflit de concurrence → **409** ; **correlation id** (`x-correlation-id`) propagé/journalisé/retourné ; endpoint **`GET /health`** (sonde Cosmos, anonyme). |
| **Anti-triche** | Détecteurs de cadence **activés** : `QuizService` alimente l'évaluateur d'intégrité avec une **fenêtre de débit réelle** (XP + tentatives sur 1 h, depuis le conteneur `attempts`) → `XpRateExceeded`/`AttemptRateExceeded` ne sont plus dormants (mode détection). |
| **Contenu** | Le validateur vérifie l'**intégrité des réponses** (chaque `correct` référence une option réelle), l'**unicité** des ids d'items, et la cohérence `ordering`/`mcq`. |
| **Cloud** | Hardening **par environnement** (`var hardened = env != 'dev'`) : Cosmos RBAC-only, Key Vault purge protection + soft delete 90 j, Storage GRS + versioning + soft delete, CORS verrouillé ; **params `staging`/`prod`** ajoutés. |
| **CI/CD** | SDK Dart épinglé, lockfile applicatif suivi, **SBOM** (CycloneDX) backend, **gate d'approbation** (`environment: beta`) sur les releases mobiles. |

### 12.1 ADR-011 — Intégrité serveur-autoritatif (économie / quiz)

**Décision.** Sur **tous** les endpoints économie et quiz, l'identité de l'appelant et la sûreté
des écritures sont **autoritatives côté serveur**. Confirmé par l'audit du lot
`wp-p0-06-server-authoritative-integrity` : le backend était **déjà conforme** ; ce lot **consigne**
la décision et **verrouille** la non-régression par les tests anti-rejeu.

**Identité (`userId`) — exclusivement issue du JWT.**

- `JwtAuthMiddleware` valide le Bearer et publie le `ClaimsPrincipal` dans
  `context.Items["User"]` + `FunctionUserContext.Current`.
- `HttpExtensions.GetUser()` lit ce principal (401 si absent) ; `FunctionUserContext.UserId`
  mappe les claims `oid` → `NameIdentifier` → `sub`.
- Tous les services consomment `IUserContext.UserId`. **Aucun DTO** économie/quiz ne transporte de
  `userId` fourni par le client : l'identité ne peut pas être usurpée via le corps de requête.

**Idempotence — clé cliente + ids déterministes (sens d'échec sûr).**

| Domaine | Clé d'idempotence | Id déterministe |
|---|---|---|
| Quiz | `ClientAttemptId` | `attempt::{ClientAttemptId}` |
| Examen | `ClientAttemptId` | `examattempt::{ClientAttemptId}` |
| Boutique | `ClientPurchaseId` | `purchase::{ClientPurchaseId}` |
| Réparation de série | `ClientRepairId` | `streakrepair::{ClientRepairId}` (réutilise le ledger d'achat) |
| Quête quotidienne | flag profil | `DailyQuestClaims` |
| Saison | flag profil | `SeasonBadges` |

- **Réserver-avant-créditer** : garde `GetByClient*IdAsync` (court-circuit de rejeu renvoyant le
  résultat antérieur) → `CreateAsync` sur l'id déterministe → sur `DuplicateRecordException`,
  relecture du gagnant et renvoi de **son** résultat. Au pire une récompense est *rejouable*,
  **jamais** double-créditée.
- **Concurrence optimiste** : les mutations passent par `OptimisticConcurrency.ExecuteAsync`
  (ETag `_etag`) → sur 412, relecture du profil et **ré-évaluation** de la règle métier
  (garde de débit conditionnel re-vérifiée).
- **Cosmos** : `Conflict` → `DuplicateRecordException` ; ETag `PreconditionFailed` →
  `ConcurrencyConflictException` ; progression via `TransactionalBatch`.

**Tests anti-rejeu (garde de non-régression).** `QuizServiceTests` /
`ExamServiceTests.SubmitAsync_is_idempotent_per_client_attempt_id`,
`ShopServiceTests.PurchaseAsync_is_idempotent_per_client_purchase_id`,
`QuestServiceTests` / `SeasonServiceTests.ClaimAsync_is_idempotent`,
`StreakRepairServiceTests.RepairAsync_bridges_gap_charges_gems_and_is_idempotent`.

**Hors périmètre (différé Phase 1+).** La réserve du lot `wp-p0-02` sur
`NotificationService.UpsertAsync` (honore l'ETag **sans retry** → `ConcurrencyConflictException`
propre, pas de lost update silencieux) **n'entre pas** dans le DoD de ce lot, strictement limité aux
écritures **économie/quiz**. Le retry des notifications est **différé** en Phase 1+ et **non**
implémenté ici.

### 12.2 ADR-012 — Intégrité de la gamification (plafonds & rejeu, confirmation `wp-p1-15`)

**Décision.** L'intégrité de l'économie et de la gamification (XP, gemmes, série, quêtes,
saison, boutique) repose sur trois garanties **serveur-autoritatives** : (1) toute écriture de
profil passe par la **concurrence optimiste ETag** (`OptimisticConcurrency`), (2) la progression
multi-document est **atomique** (`TransactionalBatch` mono-partition), (3) les **plafonds de
cadence** (`RateWindow`) sont **appliqués** (enforcement), alimentés par une fenêtre **réelle**
lue du conteneur `attempts`. Confirmé par l'audit du lot `wp-p1-15-gamification-integrity` : le
backend était **déjà conforme** (dépendances `wp-p0-02` ETag et `wp-p0-06` server-authoritative
**mergées**). Ce lot **consigne** la preuve fichier:ligne et **n'introduit aucun code** ; il
complète l'ADR-011 (§12.1) sur l'axe **plafonds anti-abus**.

**1. ETag sur toutes les écritures d'économie.** Chaque mutation de profil est encapsulée dans
`OptimisticConcurrency.ExecuteAsync` (relit le profil et **ré-évalue** la règle métier sur 412) :

| Écriture | Site |
|---|---|
| Boutique (`PurchaseAsync`) | `GamificationServices.cs:47` |
| Quête quotidienne (`ClaimAsync`) | `GamificationServices.cs:139` |
| Saison (`ClaimBadgeAsync`) | `GamificationServices.cs:253` |
| Réparation de série (`RepairAsync`) | `GamificationServices.cs:428` |
| Scoring quiz (crédit profil) | `QuizService.cs` (voir §12.1) |

**2. `TransactionalBatch` multi-document.** La progression de leçon écrit *profil + tentative +
événements* dans **un seul batch** transactionnel, sur la partition `userId` :
`CosmosProgressRepository.cs:50` — `context.Progress.CreateTransactionalBatch(new PartitionKey(userId))`.
Aucune écriture partielle possible (tout ou rien).

**3. Plafonds `RateWindow` — enforcement (pas shadow).** La fenêtre de cadence est **lue du
conteneur réel** (`attempts`), pas un stub dormant :

- `QuizService.cs:172` et `ExamService.cs:299` appellent `BuildRateWindowAsync`, défini en
  `QuizService.cs:368` / `ExamService.cs:426` : `attempts.GetRecentActivityAsync(userContext.UserId,
  now - RateWindowDuration, …)` avec `RateWindowDuration = 1 h` (`QuizService.cs:366`,
  `ExamService.cs:424`). Implémentation réelle : `CosmosAttemptRepository.cs:44`.
- Politique par défaut (`AttemptIntegrity.cs`) : record `RateWindow` (`:79`) ; champs
  `MaxXpPerWindow` (`:95`) / `MaxAttemptsPerWindow` (`:96`) ; `IntegrityPolicy.Default`
  = **600 XP** (`:121`) et **40 tentatives** (`:122`) par heure.
- Application dans `Evaluate` : dépassement XP → `flags.Add(IntegrityFlag.XpRateExceeded)`
  (`AttemptIntegrity.cs:236`, gardé par le `if` L234) ; dépassement tentatives →
  `IntegrityFlag.AttemptRateExceeded` (`AttemptIntegrity.cs:244`, gardé L242). Ces flags alimentent
  le score de risque et peuvent **rejeter** l'attribution des récompenses.

**4. `userId` exclusivement issu du JWT.** Confirmé §12.1 pour l'identité. Les fenêtres de cadence
elles-mêmes emploient `userContext.UserId` (`QuizService.cs:370`, `ExamService.cs:428`) : aucun DTO
gamification ne transporte de `userId` client — impossible de plafonner « l'identité d'un autre ».

**5. Idempotence récompenses & achats (ids déterministes).** Confirmé §12.1 (réserver-avant-créditer,
sens d'échec sûr). Ancres propres à ce lot : boutique — garde `GetByClientPurchaseIdAsync`
(`GamificationServices.cs:52`) → id `purchase::{ClientPurchaseId}` (`GamificationServices.cs:83`) →
`CreateAsync` (`:90`) ; réparation de série — garde (`:432`) → `CreateAsync` (`:477`) ; scoring quiz —
garde amont `prior.Result` (`QuizService.cs:35`/`:38`), id `attempt::{ClientAttemptId}` (`:243`),
`DuplicateRecordException` → relecture du gagnant (`:255`/`:257`), sinon `ConcurrencyConflictException`
(`:263`). Au pire une récompense est *rejouable*, **jamais** double-créditée.

**Tests anti-régression.** Couverts par les suites listées en §12.1 (`QuizServiceTests`,
`ExamServiceTests`, `ShopServiceTests`, `QuestServiceTests`, `SeasonServiceTests`,
`StreakRepairServiceTests` : idempotence par clé cliente) ; les plafonds de cadence sont vérifiés par
`AttemptIntegrityEvaluatorTests` (dépassement XP/tentatives → flags `IntegrityFlag.*RateExceeded`).

**Hors périmètre.** `cortex` (`wp-p1-09`) et le renderer contenu (`wp-p1-01`) ne sont **pas** touchés ;
la réserve `wp-p0-02` sur `NotificationService.UpsertAsync` reste **différée** (cf. §12.1). Ce lot est
strictement **backend économie/gamification** et **sans changement de code** (`git diff origin/main`
limité au registre de migration et à ce document).
