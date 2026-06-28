# Architecture — Microlingo

Ce document décrit l'architecture de référence du monorepo : frontend Flutter, backend
.NET 8 Azure Functions, moteur pédagogique Cortex, contenu *as-code* et flux de données.

> Rappel produit : Microlingo enseigne des **concepts techniques réels** et prépare aux
> certifications Microsoft (AZ-900, AZ-104, AI-900, DP-900). Ce **n'est pas** une app de langues.

---

## 1. Principes directeurs

1. **Feature-first** côté mobile, **Clean Architecture** côté backend — la logique métier ne
   dépend jamais d'un framework ou d'une base.
2. **Le domaine est roi.** Les règles (readiness, FSRS, XP) vivent dans des unités pures,
   testables sans I/O, dupliquées à l'identique client/serveur.
3. **Le serveur est l'autorité.** La notation des quiz, le calcul du Readiness Score et
   l'attribution d'XP sont recalculés côté API ; le client n'en fait qu'une projection optimiste.
4. **Le contenu est du code.** Tracks et leçons sont du YAML versionné, validé en CI, compilé
   vers Cosmos par un pipeline de seed.
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
│  Microlingo.Api            HTTP triggers · JwtAuthMiddleware · ExceptionMiddleware │
│      │                                                                            │
│      ▼                                                                            │
│  Microlingo.Application    services métier · DTO · abstractions (ports)           │
│      │                                                                            │
│      ▼                                                                            │
│  Microlingo.Domain         readiness · FSRS · XP · modèles (AUCUNE dépendance)     │
│      ▲                                                                            │
│  Microlingo.Infrastructure Cosmos repositories · Entra token validator (adapters) │
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
| `Microlingo.Domain` | Modèles + règles pures : `ReadinessCalculator`, `ReviewScheduler` (FSRS), XP, gamification, contenu. Zéro dépendance externe. |
| `Microlingo.Application` | Services d'orchestration, DTO (`Dtos.cs`), abstractions/ports (`CoreAbstractions.cs`). |
| `Microlingo.Infrastructure` | Adapters Cosmos (`CosmosContext`, repositories, sérialiseur System.Text.Json), validation token Entra. |
| `Microlingo.Api` | HTTP triggers (`*Functions.cs`), `JwtAuthMiddleware`, `ExceptionMiddleware`, `FunctionUserContext`. |
| `Microlingo.Domain.Tests` | xUnit — couvre FSRS, readiness, XP. |

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

Base `microlingo`, mode **serverless**. Huit containers, partitionnés pour la localité des accès :

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
(`Microlingo.Domain`). Mêmes constantes, mêmes formules, **même planification en
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
content/
├─ schema/
│  ├─ track.schema.json     # structure d'un track (domaines pondérés, unités, leçons)
│  └─ lesson.schema.json    # structure d'une leçon (blocs typés + checks)
└─ az-900/
   ├─ track.yaml
   └─ lessons/
      ├─ capex-opex.lesson.yaml
      ├─ shared-responsibility.lesson.yaml
      └─ cloud-models.lesson.yaml
```

- **Blocs de leçon typés** : `hook → concept → example → code → check → recap` — la boucle
  pédagogique matérialisée dans la donnée.
- **Validation CI** (`tools/validate_content.mjs`, ajv) : conformité aux schémas, intégrité
  référentielle (chaque leçon citée existe), et **somme des poids de domaine = 1.0**.
- **Pipeline de seed** (`tools/seed_content.py`) : compile le YAML en documents Cosmos et
  **sépare la clé de réponse** dans un document `answerKey` côté serveur. Le document `lesson`
  livré au client est dépouillé de `correct`/`explanation`.

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
| `cosmos.bicep` | compte Cosmos serverless + 6 containers (PK verrouillées) |
| `storage.bicep` | StorageV2 + container `lesson-assets` |
| `appInsights.bicep` | Application Insights *workspace-based* |
| `keyvault.bicep` | Key Vault (modèle RBAC) |
| `functionApp.bicep` | plan Y1 Linux, `dotnet-isolated` 8.0, *managed identity*, rôle *Key Vault Secrets User*, app settings |

---

## 10. CI/CD

Neuf workflows actifs ciblés par chemin ou par événement (voir `.github/workflows/`) :
`ci-mobile`, `ci-backend`, `ci-content`, `ci-infra`, `cd-backend`, `codeql`,
`lint-workflows`, `release-android`, `security-scan`. Les workflows iOS GitHub Actions
`release-ios` et `sync-ios-certs` sont désactivés et conservés comme historique ; la
chaîne iOS active passe par Codemagic.

---

## 11. Décisions d'architecture (résumé)

| # | Décision | Raison |
|---|---|---|
| ADR-01 | Azure Functions isolated plutôt qu'un service hébergé permanent | coût serverless, scaling à zéro, alignement « jobs » |
| ADR-02 | Cosmos DB plutôt que SQL relationnel | données documentaires (leçons/progression), partition par utilisateur, latence faible |
| ADR-03 | Cortex dupliqué client/serveur | UX optimiste sans sacrifier l'autorité serveur |
| ADR-04 | Contenu *as-code* YAML | revue par PR, validation CI, pas de CMS à maintenir au départ |
| ADR-05 | Pas de codegen Dart au départ | fichiers auto-suffisants, squelette robuste ; migration freezed possible plus tard |
| ADR-06 | Pas de cœurs / vies dans la gamification | éviter la frustration ; motiver la régularité, pas la punition |

---

## 12. Durcissement & intégrité (remédiation post-audit)

Garanties ajoutées à l'issue de l'audit technique (voir `AUDIT_MICROLINGO.md`) :

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
