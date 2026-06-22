<div align="center">

# Microlingo

**Apprenez, révisez et validez vos certifications Microsoft — par micro-leçons premium.**

Micro-learning mobile (iOS + Android) pour maîtriser des **concepts techniques & cloud réels**
et atteindre la *readiness* certification : AZ-900 · AZ-104 · AI-900 · DP-900.

`Flutter` · `.NET 8 isolated Functions` · `Cosmos DB` · `Entra External ID` · `Bicep`

</div>

> [!IMPORTANT]
> **Microlingo n'est pas une app de langues.** On n'apprend pas du vocabulaire :
> on enseigne des **concepts professionnels** via une boucle pédagogique stricte
> — *concept → exemple appliqué → vérification de compréhension → révision adaptative*.
> Toute la modélisation (contenu, quiz, progression, gamification) sert l'apprentissage
> réel et la préparation à l'examen, jamais la mémorisation creuse.

---

## ✨ Le produit en une phrase

L'utilisateur choisit son **profil** et sa **certification cible** ; Microlingo construit un
**parcours personnalisé** de leçons courtes, valide la compréhension par des quiz explicatifs,
révise les concepts faibles au bon moment (spaced repetition) et matérialise la progression par
un **Readiness Score** (0–100, la métrique nord) — porté par une gamification saine.

### Décisions verrouillées

| Pilier | Décision |
|---|---|
| Métrique nord | **Readiness Score** (préparation par certification, 0–100) |
| Moteur pédagogique | **Cortex** — *mastery-based* + **FSRS** (répétition espacée), code Dart **et** .NET identiques |
| Design system | **Prism** — *Liquid-Glass-inspired* : translucidité, profondeur, matériaux lumineux |
| Gamification | **Momentum** — XP, niveaux, streak, ligues, badges. **Pas de cœurs / vies** |
| Contenu | **Content-as-code** — YAML versionné + schéma JSON + validation CI |

---

## 🗺️ Monorepo

```
microlingo/
├─ apps/
│  └─ mobile/              # App Flutter (iOS + Android) — feature-first + Riverpod + go_router
├─ packages/
│  ├─ prism_ui/            # Design system Prism (tokens, thème, composants glass)
│  ├─ core/                # Socle : env, Result, Failures, utils transverses
│  ├─ cortex/              # Moteur FSRS / mastery / readiness (Dart pur, testable)
│  └─ data/               # Modèles, API client, repositories (miroir des DTO backend)
├─ backend/                # .NET 8 isolated Azure Functions — Clean Architecture
│  ├─ src/
│  │  ├─ Microlingo.Api/            # HTTP triggers, middleware auth/erreurs
│  │  ├─ Microlingo.Application/    # Services métier, DTO, abstractions
│  │  ├─ Microlingo.Domain/         # Modèles + règles (readiness, FSRS, XP) — sans dépendance
│  │  └─ Microlingo.Infrastructure/ # Cosmos DB, validation token Entra
│  └─ tests/               # Tests de domaine (xUnit)
├─ infra/                  # Infrastructure as Code (Bicep) : Cosmos, Storage, Functions, KV, AI
├─ content/                # Tracks & leçons en YAML + schémas + (AZ-900 amorcé)
├─ tools/                  # Validateur de contenu (Node) + seed Cosmos (Python)
├─ docs/                   # Architecture & ADRs
└─ .github/workflows/      # CI : mobile · backend · content · infra
```

Détail complet : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## 🧱 Stack technique

| Couche | Technologie |
|---|---|
| Mobile | Flutter / Dart, Riverpod, go_router, monorepo **Melos** |
| Design | Prism (Material 3 sous-jacent, `BackdropFilter`, gradients, `CustomPaint`) |
| API | **Azure Functions .NET 8 isolated**, HTTP triggers, Clean Architecture |
| Données | **Azure Cosmos DB** (serverless, 6 containers) |
| Médias | **Azure Blob Storage** (`lesson-assets`) |
| Identité | **Microsoft Entra External ID** (JWT validé côté Functions) |
| Secrets | **Azure Key Vault** (accès via *managed identity*) |
| Observabilité | **Application Insights** (workspace-based) |
| IaC | **Bicep** (subscription-scoped, modules composables) |
| CI/CD | **GitHub Actions** (4 pipelines ciblés par dossier) |

---

## 🚀 Démarrage rapide

### Pré-requis

| Outil | Version | Usage |
|---|---|---|
| Flutter SDK | ≥ 3.22 (Dart ≥ 3.4) | app mobile + packages |
| Melos | `dart pub global activate melos` | orchestration monorepo Dart |
| .NET SDK | **8.0** | backend Functions |
| Azure Functions Core Tools | v4 | exécution locale des Functions |
| Node.js | ≥ 20 | validation de contenu |
| Python | ≥ 3.10 | seed du contenu vers Cosmos |
| Azure CLI + Bicep | récent | déploiement infra |

### 1) Mobile

```bash
dart pub global activate melos
melos bootstrap          # résout les dépendances de tous les packages Dart
melos run analyze        # analyse statique
melos run test           # tests unitaires + widgets
cd apps/mobile && flutter run
```

### 2) Backend

```bash
cd backend
dotnet restore
dotnet build -warnaserror
dotnet test                         # tests de domaine (FSRS, readiness, XP)
# Exécution locale (Functions Core Tools) :
cp src/Microlingo.Api/local.settings.json.example src/Microlingo.Api/local.settings.json
cd src/Microlingo.Api && func start
```

### 3) Contenu

```bash
npm install --no-save ajv ajv-formats yaml glob
node tools/validate_content.mjs     # valide tracks + leçons vs schémas + intégrité référentielle
python tools/seed_content.py        # compile YAML → documents Cosmos dans tools/seed_output/
python tools/seed_content.py --cosmos   # + upsert dans Cosmos (COSMOS_ENDPOINT / COSMOS_KEY)
```

> Le seed sépare le **payload public** (sans réponse) de la **clé de correction**
> (document `answerKey` côté serveur) : la notation des quiz reste autoritative côté API.

### 4) Infra

```bash
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam
```

---

## 🔁 Flux de bout en bout

```
Mobile (Flutter)  ──JWT Entra──▶  Azure Functions (.NET 8)  ──▶  Cosmos DB
   Prism UI                          Clean Architecture            users · content
   Cortex (client)                   Cortex (serveur, autoritatif) progress · attempts
                                      App Insights                  events · leaderboard
```

- **`userId` provient TOUJOURS du JWT**, jamais du corps de requête.
- Idempotence des soumissions de quiz via `clientAttemptId`.
- Le moteur **Cortex** existe en double (client pour l'UX optimiste, serveur pour la vérité).

API principale :

| Méthode | Route | Rôle |
|---|---|---|
| `GET`  | `/me` | profil + stats lifetime |
| `GET`  | `/me/paths/{trackId}` | parcours + progression |
| `GET`  | `/tracks/{trackId}/lessons/{lessonId}` | leçon (sans réponses) |
| `POST` | `/quiz/{lessonId}/submit` | notation serveur + feedback + récompenses |
| `GET`  | `/me/league` | classement hebdomadaire |

---

## ✅ Intégration continue

| Workflow | Déclencheur | Vérifie |
|---|---|---|
| `ci-mobile`  | `apps/**`, `packages/**` | `dart format`, `flutter analyze`, `flutter test` |
| `ci-backend` | `backend/**` | `dotnet build -warnaserror`, `dotnet test` |
| `ci-content` | `content/**`, `tools/validate_content.mjs` | schémas + intégrité + somme des poids = 1.0 |
| `ci-infra`   | `infra/**` | `az bicep build` (lint des templates) |

> [!NOTE]
> Les workflows utilisent un runner **self-hosted** avec labels
> `[self-hosted, Linux, X64, microlingo-ci]`.
>  
> Sur la VM Azure du runner, installez au minimum : Flutter/Dart, .NET 8 SDK, Node 20, Azure CLI (Bicep), puis enregistrez le runner GitHub avec le label `microlingo-ci`.

---

## 🛣️ Roadmap

- **P0 — Fondations** ✅ monorepo, design system Prism, backend skeleton, IaC, CI, 1ʳᵉ unité AZ-900.
- **P1 — MVP** : auth Entra de bout en bout, learn + quiz + FSRS live, streak/XP, lecture offline.
- **P2 — Adaptatif+** : Cortex complet, Readiness Score serveur, leaderboard, +tracks, notifications.
- **P3 — Premium** : offline complet, polish glass/motion, A/B testing, abonnement, +certifications.

---

## 📄 Licence & marques

Projet original. Microsoft, Azure et les codes de certification cités sont des marques de
Microsoft ; Microlingo n'est ni affilié, ni approuvé par Microsoft. Aucun contenu d'examen réel
n'est reproduit — toutes les leçons et tous les items sont **originaux**.