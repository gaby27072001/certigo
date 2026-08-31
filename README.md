<div align="center">

# Certigo

**Apprenez, révisez et validez vos certifications cloud — par micro-leçons premium.**

Micro-learning mobile (iOS + Android) pour maîtriser des **concepts techniques & cloud réels**
et atteindre la *readiness* certification sur un catalogue multi-cloud. Les parcours Microsoft
existants restent disponibles ; Certigo adapte le catalogue public canonique de `certigo-content`
avant l'arrivée progressive des contenus AWS et Google Cloud.

`Flutter` · `.NET 8 isolated Functions` · `Cosmos DB` · `Entra External ID` · `Bicep`

</div>

> [!IMPORTANT]
> **Certigo n'est pas une app de langues.** On n'apprend pas du vocabulaire :
> on enseigne des **concepts professionnels** via une boucle pédagogique stricte
> — *concept → exemple appliqué → vérification de compréhension → révision adaptative*.
> Toute la modélisation (contenu, quiz, progression, gamification) sert l'apprentissage
> réel et la préparation à l'examen, jamais la mémorisation creuse.

---

## ✨ Le produit en une phrase

L'utilisateur choisit son **profil** et sa **certification cible** ; Certigo construit un
**parcours personnalisé** de leçons courtes, valide la compréhension par des quiz explicatifs,
révise les concepts faibles au bon moment (spaced repetition) et matérialise la progression par
un **Readiness Score** (0–100, la métrique nord) — porté par une gamification saine.

### Décisions verrouillées

| Pilier | Décision |
|---|---|
| Métrique nord | **Readiness Score** (préparation par certification, 0–100) |
| Moteur pédagogique | **Cortex** — *mastery-based* + **FSRS** (répétition espacée), code Dart **et** .NET identiques *(partagent la même logique ; des divergences mineures sur `dueAt`/`recency` feront l'objet de golden tests dédiés)* |
| Design system | **Prism** — *Liquid-Glass-inspired* : translucidité, profondeur, matériaux lumineux |
| Gamification | **Momentum** — XP, niveaux, streak, ligues, badges. **Pas de cœurs / vies** |
| Contenu | **Content-as-code** — [`certigo-content`](https://github.com/gchambaud_microsoft/certigo-content) est la source éditoriale active ; schémas, validation et manifeste y sont versionnés |

---

## 🗺️ Monorepo

```
certigo/
├─ apps/
│  └─ mobile/              # App Flutter (iOS + Android) — feature-first + Riverpod + go_router
├─ packages/
│  ├─ prism_ui/            # Design system Prism (tokens, thème, composants glass)
│  ├─ core/                # Socle : env, Result, Failures, utils transverses
│  ├─ cortex/              # Moteur FSRS / mastery / readiness (Dart pur, testable)
│  └─ data/               # Modèles, API client, repositories (miroir des DTO backend)
├─ backend/                # .NET 8 isolated Azure Functions — Clean Architecture
│  ├─ src/
│  │  ├─ Certigo.Api/            # HTTP triggers, middleware auth/erreurs
│  │  ├─ Certigo.Application/    # Services métier, DTO, abstractions
│  │  ├─ Certigo.Domain/         # Modèles + règles (readiness, FSRS, XP) — sans dépendance
│  │  └─ Certigo.Infrastructure/ # Cosmos DB, validation token Entra
│  └─ tests/               # Tests de domaine (xUnit)
├─ infra/                  # Infrastructure as Code (Bicep) : Cosmos, Storage, Functions, KV, AI
├─ content/                # Instantané historique du corpus monorepo (lecture/compatibilité uniquement)
├─ tools/                  # Outils historiques de validation/seed + validateur du registre
├─ docs/                   # Architecture & ADRs
└─ .github/workflows/      # CI : mobile · backend · content · infra
```

Détail complet : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

> [!TIP]
> 🧭 **Pour voir l'état réel et à jour du projet** (ce qui est *réellement* construit, fonctionnalité
> par fonctionnalité), consultez le tableau de bord vivant : [`docs/ETAT_DU_PROJET.md`](docs/ETAT_DU_PROJET.md).

Les faits techniques observables (versions, workflows, tests, corpus historique, types
pédagogiques, référence Git analysée et packages actifs de `certigo-content`) y sont générés
depuis le dépôt :

```bash
# Après avoir commité les sources observables :
python tools/generated_contracts.py --refresh
python tools/project_state.py --refresh-reference
python tools/generated_contracts.py --check
python tools/project_state.py --check   # contrôle local identique à la gate CI
python -m unittest discover -s tools/tests -p "test_*.py" -v
```

La régénération suit volontairement deux commits : le premier contient les sources observables,
le second la référence exacte et le bloc généré. La référence conserve le commit et la date
capturés, puis lie les sources par un SHA-256 déterministe des noms de chemins triés et des octets
exacts. Elle ne dépend donc ni de l'existence locale de l'objet Git ni de son ascendance après un
squash équivalent, tout en évitant qu'un document tente de référencer son propre commit.

Le reste du document est narratif : toute affirmation « opérationnelle » doit pointer vers un
workflow automatisé, un test, un runbook ou un audit daté ; sinon elle est étiquetée
**non vérifiée / manuelle**.

---

## 🧱 Stack technique

| Couche | Technologie |
|---|---|
| Mobile | Flutter / Dart, Riverpod, go_router, monorepo **Melos** |
| Design | Prism (Material 3 sous-jacent, `BackdropFilter`, gradients, `CustomPaint`) |
| API | **Azure Functions .NET 8 isolated**, HTTP triggers, Clean Architecture |
| Données | **Azure Cosmos DB** (serverless) |
| Médias | **Azure Blob Storage** (`lesson-assets`) |
| Identité | **Microsoft Entra External ID** (JWT validé côté Functions) |
| Secrets | **Azure Key Vault** (accès via *managed identity*) |
| Observabilité | **Application Insights** (workspace-based) |
| IaC | **Bicep** (subscription-scoped, modules composables) |
| CI/CD | **GitHub Actions** (pipelines ciblés par dossier) |

---

## 🚀 Démarrage rapide

### Pré-requis

| Outil | Version | Usage |
|---|---|---|
| Flutter SDK | **3.44.4** | app mobile, packages et goldens ; pin CI/release aligné |
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
cp src/Certigo.Api/local.settings.json.example src/Certigo.Api/local.settings.json
# LLM tutor (optionnel) : laissez TUTOR_LLM_ENABLED=false par défaut ; pour l'activer,
# renseignez TUTOR_LLM_ENDPOINT + TUTOR_LLM_DEPLOYMENT (+ TUTOR_LLM_API_SURFACE=v1 pour
# la surface Microsoft Foundry v1, défaut), et soit TUTOR_LLM_API_KEY, soit une identité
# Azure capable d'appeler Azure OpenAI (rôle « Cognitive Services OpenAI User »).
cd src/Certigo.Api && func start
```

### 3) Contenu

Le corpus migré est édité et publié depuis
[`gchambaud_microsoft/certigo-content`](https://github.com/gchambaud_microsoft/certigo-content).
Le dossier local `content/` est un instantané historique conservé pour compatibilité ; il ne doit
plus recevoir de changements éditoriaux.

La révision active est épinglée dans
[`docs/active-content-reference.json`](docs/active-content-reference.json) et vérifiée sur chaque
PR ainsi que quotidiennement. À la référence du **2026-08-06** :

| Package actif | Fichiers | Manifest ID |
|---|---:|---|
| Public (`public/public`) | **146** | `sha256:335fb7c1538739cf2a1f2ac9629ed3d355dca851215fed61d60a28c166807dff` |
| Privé (`answerKey/private`) | **146** | `sha256:6e0ce2ef6ac799e3298e7e78ce23ad181a94961c979bef305e384898196f023b` |

Ces valeurs décrivent les packages actifs du commit
`470acdbf100e7f7faf9911015662bee6118b8bf5`. Les compteurs issus de `content/` restent
explicitement **historiques**.

```bash
# Dans un clone de certigo-content, suivre son README et ses gates CI.
# Contrôle ponctuel de l'instantané historique de ce monorepo :
npm install --no-save ajv ajv-formats yaml glob
node tools/validate_content.mjs
```

> Dans `certigo-content`, les payloads publics sont séparés des `answerKey` privés : la notation
> des quiz reste autoritative côté API.

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
- Reprise durable des effets économie/gamification via un état d'opération Cosmos ; aucune
  transaction cross-container n'est supposée.
- Le moteur **Cortex** existe en double (client pour l'UX optimiste, serveur pour la vérité).

API principale :

| Méthode | Route | Rôle |
|---|---|---|
| `GET`  | `/me` | profil + stats lifetime |
| `POST` | `/me/active-track` | persiste la certification active validée par le catalogue |
| `GET`  | `/me/paths/{trackId}` | parcours + progression |
| `GET`  | `/tracks/{trackId}/lessons/{lessonId}` | leçon (sans réponses) |
| `POST` | `/quiz/{lessonId}/submit` | notation serveur + feedback + récompenses |
| `GET`  | `/me/league` | classement hebdomadaire |
| `GET`  | `/achievements` | succès & badges débloqués |
| `GET`  | `/shop` · `POST` `/shop/purchase` | boutique gems + achat |
| `GET`  | `/quests` · `POST` `/quests/claim` | quêtes du jour + récompense |
| `GET`  | `/friends` · `POST` `/friends` · `DELETE` `/friends/{id}` | graphe social |
| `GET`  | `/friends/leaderboard` | classement entre amis |
| `GET`  | `/streak` · `POST` `/streak/repair` | statut streak + réparation (gems) |
| `GET`  | `/share/daily` | carte de partage quotidienne |

---

## ✅ Intégration continue

| Workflow | Déclencheur | Vérifie |
|---|---|---|
| `ci-mobile`  | `apps/**`, `packages/**` | `dart format`, `flutter analyze`, `flutter test` |
| `ci-backend` | `backend/**` | `dotnet build -warnaserror`, `dotnet test` |
| `ci-content` | instantané historique `content/**` | schémas + intégrité + somme des poids = 1.0 |
| `ci-migration-registry` | `docs/migration/**`, validateur Python | statuts, états, dépendances et absence de cycle |
| `ci-project-state` | chaque PR, `main`, quotidien | état généré identique, référence active `certigo-content` et manifestes public/privé exacts |
| `ci-infra`   | `infra/**` | compilation Bicep + contrats réseau/contenu immuable |
| `content-infra-what-if` | push `main` | plan Azure read-only de `main` via Environment `azure-content-infra-plan`, hors dev/staging/prod |
| `cd-backend` | push / workflow manuel | déploiement backend vers l'environnement cible |
| `codeql` | schedule / push | analyse statique de sécurité |
| `lint-workflows` | `.github/workflows/**` | lint des workflows GitHub Actions |
| `release-android` | manuel / tag `v*` | **AAB signé** + publication Google Play (gates `analyze`/`test`) |
| `security-scan` | schedule / push | scan sécurité complémentaire (NuGet + Bicep) |

> `release-ios.yml` et `sync-ios-certs.yml` sont des workflows legacy, inertes par
> défaut et exécutables uniquement par opt-in manuel `enable_legacy_workflow=true`.
> La chaîne iOS active passe par Codemagic.

La gate Cosmos locale sans secret de dépôt exécute toujours les contrats de sérialisation/ETag/TTL :

```powershell
.\backend\run-cosmos-gate.ps1
```

Pour ajouter les intégrations réelles, démarrer l'émulateur puis définir
`CERTIGO_COSMOS_TESTS=1` et une connexion locale via
`COSMOS_EMULATOR_CONNECTION_STRING` ou `COSMOS_EMULATOR_KEY`. Utiliser
`-RequireEmulator` pour faire échouer explicitement la gate si l'émulateur n'est pas configuré.

> Publication des bêtas mobiles (signature, secrets, runbooks Android & iOS,
> rollback, checklist) : voir [`docs/RELEASE_MOBILE.md`](docs/RELEASE_MOBILE.md).

> [!NOTE]
> Les workflows applicatifs utilisent un runner **self-hosted** avec labels
> `[self-hosted, Linux, X64, certigo-ci]` (les runners hébergés par GitHub sont
> désactivés par la politique d'entreprise EMU sur ce dépôt).
> La gate obligatoire `ci-project-state` utilise explicitement le pool Azure
> `[self-hosted, Linux, X64, certigo-ci]` pour chaque PR interne.
>
> Ces labels doivent désigner un pool d'au moins deux runners Azure. Le routage et le
> drill de panne sans fallback hébergé sont détaillés dans
> [`docs/CI_RUNNER_RESILIENCE.md`](docs/CI_RUNNER_RESILIENCE.md).
>
>  
> Sur la VM Azure du runner, installez au minimum : Flutter/Dart, .NET 8 SDK, Node 20, Azure CLI (Bicep), puis enregistrez le runner GitHub avec le label `certigo-ci`.

> [!IMPORTANT]
> **Accès sortant internet du runner.** Depuis le retrait de l'accès sortant par
> défaut d'Azure (septembre 2025), une VM sans IP publique explicite n'a **aucune
> connectivité sortante** — le runner ne peut alors ni joindre GitHub ni restaurer
> les paquets NuGet/pub.dev, et tous les jobs échouent. La connectivité est assurée
> par une **NAT Gateway** (`nat-certigo`) associée au sous-réseau `snet-runners`,
> avec une IP publique Standard dédiée. Si l'egress retombe, vérifier :
> ```bash
> az network nat gateway show -g rg-certigo-ci -n nat-certigo
> az network vnet subnet show -g rg-certigo-ci --vnet-name vnet-certigo-ci \
>   -n snet-runners --query natGateway.id
> ```
> La fonctionnalité `Microsoft.Network/AllowBringYourOwnPublicIpAddress` doit être
> enregistrée sur la souscription (self-service via `az feature register`).

---

## 🛣️ Roadmap

- **P0 — Fondations** ✅ monorepo, design system Prism, backend skeleton, IaC, CI, 1ʳᵉ unité AZ-900.
- **P1 — MVP** : auth Entra de bout en bout, learn + quiz + FSRS live, streak/XP, lecture offline.
- **P2 — Adaptatif+** : Cortex complet, Readiness Score serveur, leaderboard, +tracks, notifications.
- **P3 — Premium** : offline complet, polish glass/motion, A/B testing, abonnement, +certifications.

---

## 📄 Licence & marques

Projet original. Microsoft, Azure, AWS, Google Cloud et les codes de certification cités sont des
marques de leurs détenteurs respectifs. Certigo n'est affilié ni approuvé par aucun fournisseur.
Aucun contenu d'examen réel n'est reproduit — toutes les leçons et tous les items sont
**originaux**.
