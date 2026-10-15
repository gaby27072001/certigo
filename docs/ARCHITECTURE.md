# Architecture — Certigo

Ce document décrit l'architecture de référence du monorepo : client Flutter existant,
cible native Swift/SwiftUI iPhone/iPad, backend .NET 10 Azure Functions, moteur pédagogique
Cortex, contenu *as-code* et flux de données. La cible Apple réutilise les contrats HTTP ;
elle ne nécessite ni backend Swift ni deuxième source de progression.

> Rappel produit : Certigo enseigne des **concepts techniques réels** et prépare à des
> certifications cloud multi-fournisseurs. Le catalogue canonique (`content/public/catalog/certifications.json`
> dans `certigo-content`) fait foi pour les certifications et leur disponibilité.
> Ce **n'est pas** une app de langues.

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

Le schéma détaille le client Flutter conservé pendant la migration. La tranche native
choisir certification → questions → correction → progression/reprise utilise la même API.
Le contrat [native-client/v1](./contracts/native-client/v1/README.md) précise découverte des
lessons, pins et rejeu ; ses tests locaux ne prouvent ni activation de release ni santé live.
Les parcours guidés nécessitent un corpus publié : ne pas les déduire des question banks.

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
┌──────────────────────── backend (.NET 10 isolated Functions) ────────────────────┐
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

## 3. Frontend Flutter existant

### 3.1 Découpage

- **`apps/mobile`** — la coquille applicative : bootstrap, providers, routing, shell de
  navigation et les `features/` (chacune avec sa couche `presentation`).
- **`packages/prism_ui`** — design system Prism. Tokens (`prism_colors`, `prism_spacing`,
  `prism_radii`, `prism_elevation`, `prism_motion`, `prism_typography`), thème
  (`PrismTheme.light()/.dark()` + `PrismColorScheme` exposé en `ThemeExtension`, accès
  ergonomique `context.prism`) et composants : surfaces (`GlassSurface`,
  `AuroraBackground`, `PrismContentFrame`), actions (`PrismButton`, `PrismPressable`),
  composition (`PrismSectionHeader`, `PrismReveal`), états (`PrismLoadingView`,
  `PrismStatusView`), progression (`PrismProgressBar`,
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

## 4. Backend .NET 10

### 4.1 Projets

| Projet | Responsabilité |
|---|---|
| `Certigo.Domain` | Modèles + règles pures : `ReadinessCalculator`, `ReviewScheduler` (FSRS), XP, gamification, contenu. Zéro dépendance externe. |
| `Certigo.Application` | Services d'orchestration, DTO (`Dtos.cs`), abstractions/ports (`CoreAbstractions.cs`). |
| `Certigo.Infrastructure` | Adapters Cosmos (`CosmosContext`, repositories, sérialiseur System.Text.Json), validation token Entra. |
| `Certigo.Api` | HTTP triggers (`*Functions.cs`), `JwtAuthMiddleware`, `ExceptionMiddleware`, `FunctionUserContext`. |

Quatre projets de tests xUnit, un par couche : `Certigo.Domain.Tests` (FSRS, readiness, XP),
`Certigo.Application.Tests`, `Certigo.Infrastructure.Tests` et `Certigo.Api.Tests`.

### 4.2 Endpoints

Les fichiers `*Functions.cs` sous `backend/src/Certigo.Api` portent les triggers ;
`EnterpriseLearningRecoveryFunctions` est notamment un `TimerTrigger` sans route HTTP.

| Fonction | Routes |
|---|---|
| `UserFunctions` | `me`, `me/active-track` |
| `PathFunctions` | `me/paths/{trackId}` |
| `LessonFunctions` | `tracks/{trackId}/lessons/{lessonId}` |
| `QuizFunctions` | `quiz/{lessonId}/submit` |
| `ExamFunctions` | `exam/generate`, `exam/submit` |
| `CatalogFunctions` | `catalog/tracks` |
| `RecommendationFunctions` | `me/recommendations/{trackId}` |
| `TutorFunctions` | `tutor/explain` |
| `AuthFunctions` | `auth/register`, `auth/login`, `auth/refresh`, `auth/verify-email`, `auth/resend-verification` |
| `AccountDeletionFunctions` | `account/deletion` |
| `LeaderboardFunctions` | `me/league`, `me/league/resolution` |
| `FriendFunctions` | `friends`, `friends/{friendId}`, `friends/leaderboard` |
| `AchievementFunctions` | `achievements` |
| `QuestFunctions` | `quests`, `quests/claim` |
| `SeasonFunctions` | `season`, `season/claim` |
| `StreakFunctions` | `streak`, `streak/repair` |
| `ShopFunctions` | `shop`, `shop/purchase` |
| `ShareCardFunctions` | `share/daily` |
| `NotificationFunctions` | `me/notifications/plan`, `me/notifications/settings` |
| `HealthFunctions` | `health`, `health/live`, `health/ready` |
| `OrganizationFunctions` | `v1/organizations…`, invitations, teams, memberships |
| `EnterpriseIdentityFunctions` | `v1/enterprise-identity/metadata`, domaines, fédération, jetons SCIM, `v1/organizations/{organizationId}/scim/v2/…` |
| `EnterpriseLearningMetricsFunctions` | `v1/organizations/{organizationId}/learning-metrics/…` |
| `EnterpriseLearningRecoveryFunctions` | *(TimerTrigger, pas de route)* |

**Règles transverses** : `userId` est extrait du JWT (`FunctionUserContext`), jamais du corps.
Avec `PERSON_LINKED_IDENTITY_V1=shadow`, ce même `userId` reste autoritaire et devient
`personId` par égalité stricte ; le runtime écrit seulement l'overlay et le miroir
LinkedIdentity additifs.
Les soumissions de quiz sont **idempotentes** via `clientAttemptId`. Les `QuizItem` envoyés au
client n'embarquent pas la réponse correcte (notation serveur).

### 4.3 Configuration consommée

`COSMOS_ENDPOINT`, `COSMOS_DATABASE`, `KeyVault__Uri` et les paramètres d'authentification.
Drapeaux de fonctionnalité consommés par le backend (liste non exhaustive, vérifiée dans
`backend/src`) : `PERSON_LINKED_IDENTITY_V1` (`off` par défaut, `shadow` seul autre état accepté),
`ORGANIZATION_MEMBERSHIP_V1`, `ENTERPRISE_LEARNING_METRICS_V1` et `TUTOR_LLM_ENABLED`.
En local : `local.settings.json` (gabarit `.example` fourni, fichier réel gitignoré).

---

## 5. Données — Cosmos DB

Base `certigo`, mode **serverless**. La topologie canonique est
`contracts/cosmos-containers.json`, partagée par Bicep et `CosmosContainers.cs` :

| Container | Partition key | Contenu |
|---|---|---|
| `users` | `/id` | profil/overlay Person, credentials et LinkedIdentity additifs (ETag, ids déterministes) |
| `content` | `/trackId` | tracks, leçons publiques, clés de réponse |
| `content-public` | `/releaseId` | projection publique immuable d'une release |
| `content-private` | `/releaseId` | clés de correction privées d'une release |
| `content-control` | `/scope` | receipts d'import et pointeur active/previous sous ETag |
| `progress` | `/userId` | maîtrise par concept, état FSRS |
| `attempts` | `/userId` | tentatives de quiz/examen (id déterministe `attempt::{clientAttemptId}` → idempotence atomique) |
| `events` | `/userId` | événements analytics |
| `leaderboard` | `/periodLeagueId` | classements hebdomadaires |
| `economy` | `/userId` | gemmes, achats boutique (id déterministe `purchase::{clientPurchaseId}`) |
| `friends` | `/userId` | graphe social (deux arêtes dirigées par amitié) |
| `organizations` | `/organizationId` | organisations, équipes, adhésions et invitations entreprise |
| `enterpriseMetricReceipts` | `/partitionKey` | reçus d'idempotence des métriques d'apprentissage entreprise |

La partition par `/userId` permet des requêtes mono-partition **dans chaque container**.
Une même valeur de clé dans `progress`, `attempts` et `events` ne crée pas une transaction
inter-containers. Les journaux et reçus idempotents permettent la reprise des opérations ;
un `TransactionalBatch` reste limité à un container et une partition logique.

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
- **Métadonnées d'examen consommées par l'app** : le catalogue API superpose aux tracks les
  titres, domaines pondérés, prérequis, liens Microsoft Learn, date de blueprint et statut de
  cycle de vie maintenus dans `OfficialCertificationCatalog`. Cette couche factuelle ne contient
  ni leçons ni questions et ne transforme pas l'instantané `Certigo/content/` en source éditoriale.
- **Remplacement d'un examen** : un examen retiré reste visible pour sa progression historique,
  mais son track est exclu de la projection active (AI-900). Son successeur actif peut apparaître
  comme entrée informative non navigable (AI-901) jusqu'à publication de son contenu, sans
  migration destructive de l'historique AI-900.

### 7.1 Releases runtime immuables

Le contrat runtime final fusionné dans `certigo-content` au SHA
`07ab6b0453a49c7ac5800837851ae83edf159768` lie un package public et un package
privé via `certigo.content.release/v1`. Le backend lit les versions Blob WORM
depuis un compte dédié et vérifie descriptor, manifestes, chemins, schémas,
hashes, tailles, graphe et anti-fuite avant la première écriture.

La projection canonique produit des `Track`/`Lesson` publics et des
`LessonAnswerKey` privés. Les parcours guided ne dupliquent pas les questions;
les question banks synthétisent une lesson de pratique par domaine. Les
documents sont create-only dans `content-public` et `content-private`, avec
`content-control` pour les receipts et le pointeur active/previous sous ETag.

Une requête métier résout un `ContentSnapshot` une fois, afin qu'une promotion
concurrente ne mélange jamais deux releases. Quiz, examens et tuteur épinglent
les opérations par `publicManifestId`/`releaseId`. Le container `content`
historique reste disponible via `CONTENT_REPOSITORY_MODE=legacy`.

### 7.2 Catalogue canonique de certifications multi-cloud

Le catalogue public `content/public/catalog/certifications.json` de `certigo-content`, défini par
l'ADR-0004 de ce dépôt éditorial et le schéma `certigo.certification-catalog/v1`, est l'unique
inventaire canonique multi-cloud. Certigo ne conserve aucun snapshot éditorial concurrent :
`CertificationCatalogParser` valide le contrat source et `CertificationCatalogAdapter` le projette
vers les DTO applicatifs sans modifier les identifiants `<provider>:<slug>`, les niveaux, les
statuts, les objectifs, le cycle de vie ni la provenance.

L'importeur de package `certigo-content` reste la frontière d'injection prévue. Tant qu'il n'est pas
raccordé, la production injecte explicitement `EmptyCertificationRegistry` plutôt que des données
de test ou une copie locale. `ContentService` continue alors d'exposer les tracks publiés et la
surcouche Microsoft `OfficialCertificationCatalog`, notamment AI-900 retiré, visible pour
l'historique mais exclu de la projection active, et AI-901 actif, planifié et non sélectionnable.

Quand une source canonique est injectée, `ContentService` l'adapte ainsi :

- une certification sans track reçoit `contentStatus: planned` et `learningAvailable: false`,
  deux champs dérivés par l'application et absents du contrat éditorial ;
- un track de même ID fournit les compteurs et passe à `available` ;
- les statuts `retired` et `replaced` sans contenu publié sont masqués, tandis que
  `active-retiring` reste actif ;
- l'API annonce explicitement `certigo.app-certification-catalog/v2` et
  `sourceSchema: certigo.certification-catalog/v1` ; le mobile refuse tout schéma inconnu ;
- les segments de route utilisent un encodage URI afin de préserver les identifiants canoniques.

La décision DVA au 18 août 2026 est explicite : `aws:dva-c02` reste l'entrée active et son guide est
`https://docs.aws.amazon.com/aws-certification/latest/developer-associate-02/developer-associate-02.html`.
`aws:dva-c03` peut être référencé comme successeur annoncé pour une inscription à compter du
1er décembre 2026, mais n'est pas une entrée de production active.

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
modules. `params/dev.bicepparam` porte les valeurs d'environnement. Les principaux :

| Module | Crée |
|---|---|
| `cosmos.bicep` | compte Cosmos serverless + containers du contrat canonique (PK verrouillées) |
| `storage.bicep` | StorageV2 + container `lesson-assets` |
| `appInsights.bicep` | Application Insights *workspace-based* |
| `keyvault.bicep` | Key Vault (modèle RBAC) |
| `privateNetwork.bicep` | VNet `/24`, subnet FC1 `/26`, subnet private endpoint, 5 zones DNS/liens et endpoints privés Storage/KV/Cosmos |
| `functionApp.bicep` | plan FC1 Linux, `dotnet-isolated` 10.0, intégration VNet privée sans route-all, identité système Cosmos et identité utilisateur préprovisionnée pour stockage/KV/App Insights |
| `openai.bicep` | déploiement Azure OpenAI du tuteur |
| `communicationEmail.bicep` | Azure Communication Services (e-mails transactionnels) |
| `defender.bicep`, `policy.bicep`, `diagnostics.bicep` | posture de sécurité, Azure Policy et journalisation |
| `contentStorage.bicep`, `contentIdentity.bicep`, `contentReaderIdentity.bicep`, `contentPrivateEndpoints.bicep` | chaîne de contenu immuable (ADR-020) |
| `keyvaultGraphClientSecret.bicep`, `keyvaultPreviousJwtSecret.bicep`, `keyVaultSecretsAccess.bicep` | secrets Key Vault et accès |
| `ciVnetPeering.bicep`, `sharedPrivateDns.bicep`, `privateDnsAppLinks.bicep` | réseau CI, DNS privé partagé et liens |

### 9.1 Prévol local .NET et limites de preuve

Le runtime déclaré dans `infra/modules/functionApp.bicep` est `dotnet-isolated` **10.0**,
comme les projets backend `net10.0`. Cela ne prouve pas une migration déployée.
Le commentaire d'en-tête `.NET 8` de `infra/main.bicep` est obsolète, non fonctionnel ;
sa correction reste séparée pour ne pas modifier les entrées du gate infra scellé.
Le schéma `host.json` reste **2.0** : ce n'est pas la version de .NET.

`tools/validate_backend_readiness.py` vérifie hors ligne le SDK sélectionné, les projets,
les versions SDK/Worker attendues, le runtime Bicep littéral et les gabarits Functions.
Il n'évalue pas MSBuild ni Bicep et ne lit jamais le vrai `local.settings.json`.
L'option `--publish-dir` contrôle la structure d'un répertoire **déjà publié** :
DLL non vide, host/runtimeconfig/deps/worker, absence de paramètres locaux. Avec le SDK
Functions actuel, l'indexation est faite par le worker ; `functions.metadata` statique
n'est pas requis. Un SDK absent, ancien ou preview échoue ; aucun outil n'est installé.

```powershell
# Depuis la racine, avec un SDK .NET 10 stable déjà disponible.
python tools\validate_backend_readiness.py --dotnet "<chemin-dotnet-existant>"
python -m unittest discover -s tools\tests -p test_validate_backend_readiness.py
# Après le publish local normal ; ce contrôle ne construit ni ne déploie le package.
python tools\validate_backend_readiness.py --dotnet "<chemin-dotnet-existant>" --publish-dir "<repertoire-publish>"
```

Sans `--publish-dir`, le résultat annonce explicitement `publish=NOT CHECKED`.
Même avec cette option, le résultat n'atteste **ni** provenance/hash/signature,
exécution Linux, dépendances natives, état Azure, identité, réseau, restauration ou
autorisation de déployer. Conserver les gates build/test, compilation Bicep et
vérification ZIP/manifeste/SBOM existants dans `backend-release-manifest.mjs`.
Ne pas confondre une validation locale et les checks GitHub de la révision livrée.

### 9.2 Compatibilité et trois récupérations distinctes

Les anciens clients et le client Apple partagent les routes existantes : catalogue,
path, lesson, submit. Découvrir `lessonId` dans le path, sans fabriquer d'identifiant.
Le pin de lecture versionnée est dans `X-Content-Manifest-Id` et l'ETag ; la soumission
porte `publicManifestId`. Une réponse de correction autorisée après soumission n'est
pas une publication de la banque privée. Une reprise hors ligne conserve owner,
scope, payload, pin et `clientAttemptId` ; une issue réseau incertaine rejoue exactement
la même tentative, sans produire de nouveau crédit. Il n'existe pas de route
`latestAttempt` à inventer pour la reprise.

| Opération | Retour contrôlé | Preuve avant exécution |
|---|---|---|
| Code Functions Flex | Redéployer l'artefact compatible `previous` via le chemin protégé existant, sans reconstruire ni redéployer Bicep | Provenance, hashes, rétention réelle du bundle, compatibilité avec configuration/données/contenu présents, puis sondes live/ready et parcours avec compte de test autorisé |
| Contenu | Promotion séparée du pointeur vers une release antérieure importée, avec ETag/CAS et rôle administrateur | Descriptor/manifests et clés historiques conservés, intégrité des packages, ETag courant ; conflit CAS = relire et décider, pas écraser |
| Données Cosmos | Restaurer vers une **cible isolée**, réconcilier et tester avant toute décision de bascule | Mode/rétention effectivement configurés, point de reprise disponible, dépendances et IAM de cible, preuve de reprise des journaux sans double récompense, RPO/RTO mesurés |

Flex Consumption ne propose pas de slots : pas de « swap » ni bouton d'annulation
supposé. `RollingUpdate` est une option distincte, pas activée par ce document ;
la coexistence de versions exige quand même une compatibilité ascendante/descendante.
Un échec après installation du code peut laisser le pointeur de livraison inchangé
**sans** avoir automatiquement restauré le code servi : constater l'état réel avant retry.
Un rollback de code n'annule ni activation éditoriale, ni écritures de progression,
ni changement de runtime/configuration. Ne pas viser un ancien binaire incompatible
avec le runtime configuré. Ne pas supprimer les pins, objets immuables ou protections
de rétention pour rendre un rollback possible.

Les tests `NativeLearningJourneyContractTests`, `NativeClientWireFixtureTests` et
`RuntimeContentProjectorTests` couvrent le parcours contractuel et les clés historiques.
Ils ne remplacent pas une restauration Cosmos ni une interruption/reprise réelle.
La procédure de contenu demeure [CONTENT_RELEASES](./runbooks/CONTENT_RELEASES.md) ;
le chemin d'artefacts/code reste décrit dans [deployment-runbook](./deployment-runbook.md).
Aucune restauration destructive ou bascule automatique n'est ajoutée.

### 9.3 Gates de lancement et objectif Advisor

Avant toute promotion : une décision explicite doit autoriser la reprise CI, avec
capacité PR **et** trusted séparées. Un runner PR seul ne satisfait pas les gates
security/CodeQL/release/deploy. Un checkpoint local de politique/proposition CI n'est
ni une activation ni une preuve GitHub actuelle. Préserver workflows, seals et IAM.
Vérifier ensuite la correspondance exacte dépôt/environment/sujet OIDC et les droits
minimaux ; ne jamais remplacer un ancien sujet avant preuve additive et plan de retour.
La conformité de l'abonnement d'hébergement à un produit personnel en production,
la séparation non-production/production, puis une preuve de restauration restent des
décisions/gates distinctes. Ce document ne choisit ni nouvel abonnement ni région.
Toute opération live requiert une autorisation séparée et le préflight approprié.

L'objectif est de se rapprocher de 100 % **mesurés** dans Azure Advisor en corrigeant
les recommandations applicables, pas en les masquant. Garder la baseline datée et les
ressources concernées dans un rapport privé, puis remesurer après changement autorisé.
Le score couvre les workloads évalués de l'abonnement, pas seulement Certigo.
Un score absent est inconnu ; un score ancien n'est pas une posture actuelle.
L'ordre privilégie sécurité, fiabilité et échéances de support avant le gain de points.
Ne pas activer des services payants, retirer une politique imposée ou modifier les
exclusions/pondérations pour améliorer artificiellement le résultat. Une recommandation
peut nécessiter une exception motivée, sans suppression automatique de sa visibilité.
Advisor, conformité Azure Policy et Defender Secure Score sont des mesures distinctes
(même si la catégorie Security d'Advisor utilise le modèle Secure Score).

Références Microsoft consultées le 14 octobre 2026 :
[support .NET](https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core)
(.NET 8 : fin le 10 novembre 2026 ; .NET 10 LTS : 14 novembre 2028),
[Flex](https://learn.microsoft.com/azure/azure-functions/flex-consumption-plan),
[mises à jour Flex](https://learn.microsoft.com/azure/azure-functions/flex-consumption-site-updates),
[restauration Cosmos](https://learn.microsoft.com/azure/cosmos-db/continuous-backup-restore-introduction),
[calcul Advisor](https://learn.microsoft.com/azure/advisor/advisor-score).

---

## 10. CI/CD

**28 workflows** sous `.github/workflows/` (dont 2 workflows iOS legacy, manuels et inertes par
défaut), ciblés par chemin ou par événement. Sept contextes sont requis sur `main` : `Build & test`,
`Flutter app + UI packages`, `Generated state equals committed state`, `Validate workflow YAML`,
`CodeQL / Security gate`, `Security / Required gate` et `Fork PR policy / Required gate`.

Le workflow `promote-backend-staging-prod` est conservé
temporairement comme garde de compatibilité et échoue explicitement en invitant à utiliser
le dispatch `promote-backend`. Les workflows iOS GitHub Actions
`release-ios` et `sync-ios-certs` sont conservés comme historique ; ils exigent
l'opt-in manuel `enable_legacy_workflow=true`. La chaîne iOS active passe par Codemagic.

`ci-content-drift.yml` détecte la dérive entre `docs/active-content-reference.json` et la release
de contenu publiée. Il ne tourne **jamais** sur PR et reste sur `certigo-trusted` : le compte de
stockage de contenu est privé (private endpoint lié à `vnet-certigo-ci`), donc sur `certigo-pr` il
échouerait sur le DNS et non sur l'autorisation.

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
| ADR-018 | VMSS comme socle CI et ACA Jobs en complément éphémère PR-only | conserver la compatibilité et la frontière trusted, tout en pilotant une capacité stateless scale-to-zero sur des validateurs sans secret |

---

## 12. Durcissement & intégrité (remédiation post-audit)

Garanties ajoutées à l'issue de l'audit technique (voir `AUDIT_CERTIGO.md`) :

| Domaine | Garantie |
|---|---|
| **Intégrité de l'économie** | Profil utilisateur protégé par **concurrence optimiste (ETag `_etag`)** + retry (`OptimisticConcurrency`) → plus d'écritures perdues. Tentatives/achats/examens à **id déterministe** (`attempt::`, `purchase::`, `examattempt::`) → idempotence **atomique** (création qui échoue sur doublon), sens d'échec sûr (au pire récompense rejouable, jamais de double crédit). |
| **Sécurité auth** | `DevTokenValidator` **verrouillé hors développement** (`AuthValidatorSelection`, garde de production explicite ; `AUTH_MODE=dev` rejeté en prod sauf override non-prod). |
| **Parité Cortex** | Planification en **jours fractionnaires** alignée client/serveur, garantie par des **golden tests partagés**. |
| **Frontière HTTP** | JSON malformé → **400** ; conflit de concurrence → **409** ; **correlation id** (`x-correlation-id`) propagé/journalisé/retourné ; endpoint **`GET /health`** (sonde Cosmos, anonyme). |
| **Anti-triche** | Détecteurs de cadence **activés** : `QuizService`/`ExamService` alimentent l'évaluateur d'intégrité avec une **fenêtre de débit réelle** (XP + tentatives sur 1 h, depuis le conteneur `attempts`). Signaux durs (horloge falsifiée, vitesse) **sanctionnent** (`Reject` → 0 récompense) ; `XpRateExceeded`/`AttemptRateExceeded` restent **détection pure par construction** (contribution de risque plafonnée sous le seuil de `Reject`, seule ou combinée). |
| **Contenu** | Le validateur vérifie l'**intégrité des réponses** (chaque `correct` référence une option réelle), l'**unicité** des ids d'items, et la cohérence `ordering`/`mcq`. |
| **Cloud** | Key Vault purge protection est activée dans tous les environnements. Le hardening **par environnement** (`var hardened = env != 'dev'`) conserve Cosmos RBAC-only, soft delete Key Vault 90 j, Storage GRS + versioning + soft delete et CORS verrouillé pour staging/prod. |
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
- Le mode Person/LinkedIdentity livré est limité à `off|shadow`. `shadow` compare le locator
  validé au propriétaire legacy, mais ne remplace jamais `IUserContext.UserId`, ne fusionne
  jamais par e-mail et n'expose aucun endpoint/UI de liaison.

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
`DurableEconomy.ApplyProfileOnceAsync`, qui relit le profil, vérifie le reçu d'opération borné,
puis réessaie l'écriture conditionnelle sur 412 :

| Écriture | Site |
|---|---|
| Boutique (`PurchaseAsync`) | `GamificationServices.cs:47` |
| Quête quotidienne (`ClaimAsync`) | `GamificationServices.cs:139` |
| Saison (`ClaimBadgeAsync`) | `GamificationServices.cs:253` |
| Réparation de série (`RepairAsync`) | `GamificationServices.cs:428` |
| Scoring quiz (crédit profil) | `QuizService.cs` (voir §12.1) |

**2. État durable, sans fausse transaction cross-container.** Chaque quiz, examen et mutation de
gamification crée un `EconomyOperationRecord` déterministe dans le conteneur `economy`. Le record
conserve le payload immuable, l'issue réconciliée, les étapes requises et les étapes terminées.
Les journaux ont `ttl = -1` et sont donc retenus : une reprise relit l'issue durable et rejoue
uniquement les projections manquantes :

- profil : reçu `{ operationId, appliedAt, outcomeJson }` écrit avec la mutation sous ETag ;
- classement : XP + marqueur écrits ensemble sous ETag dans l'entrée hebdomadaire ;
- événements : ids déterministes, un conflit Cosmos 409 signifie que la projection existe déjà ;
- tentative/ledger/progression : créations ou upserts idempotents, puis étape acquittée.

Les reçus profil sont limités à 128 et à 256 Kio sérialisés. Ils ne conservent que l'issue minimale
nécessaire à la reprise (par exemple `RewardsDto`, jamais les réponses ou explications d'examen).
Avant d'en ajouter un, les plus anciens ne sont compactés que si leur journal durable est terminal
(`completed` ou `failed`). Un journal non terminal n'est jamais compacté ; si les limites sont
atteintes uniquement par des opérations non terminales, la mutation échoue explicitement et doit
être réconciliée. Ces reçus et les marqueurs de migration sont filtrés des réponses HTTP. Pour quiz
et examen, tentative persistée, profil,
classement, réponse et événements utilisent tous la même issue réconciliée stockée dans le journal.
Les soldes réconciliés de boutique, quêtes, saisons et réparation de série suivent la même règle
pour le ledger, la réponse et les événements. Les anciens marqueurs
`AppliedEconomyOperations` restent lisibles uniquement comme pont de migration : ils ne sont plus
alimentés et sont convertis en reçus sans réappliquer la mutation lors de la reprise du journal.

Il ne s'agit **pas** d'une transaction cross-container. Une panne peut laisser une opération
`pending`, mais le retry la réconcilie sans double crédit. Le seul `TransactionalBatch` est celui de
`CosmosProgressRepository`, limité aux documents de progression d'une même partition `/userId`.

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
  `IntegrityFlag.AttemptRateExceeded` (`AttemptIntegrity.cs:244`, gardé L242). Ces flags
  alimentent le score de risque commun ; leur contribution individuelle est plafonnée
  (`AttemptIntegrityEvaluator.CadenceContributionCeiling`, 0.54) si bien que la cadence —
  seule ou les deux signaux de cadence combinés entre eux — ne peut jamais franchir le
  seuil de `Reject`. Seule une combinaison avec un signal dur (horloge falsifiée, vitesse)
  peut faire basculer la tentative en `Reject`.

**4. `userId` exclusivement issu du JWT.** Confirmé §12.1 pour l'identité. Les fenêtres de cadence
elles-mêmes emploient `userContext.UserId` (`QuizService.cs:370`, `ExamService.cs:428`) : aucun DTO
gamification ne transporte de `userId` client — impossible de plafonner « l'identité d'un autre ».

**5. Idempotence récompenses & achats (ids déterministes).** L'id
`operation::{kind}::{operationKey}` est la réservation globale. Le premier `CreateItem` gagne ; les
appels concurrents relisent son payload et participent à la même reprise. Les tests injectent des
pannes après le crédit profil et avant le classement ou l'événement, puis prouvent qu'un retry
termine l'opération sans doubler XP, gems, achat, tentative ou événement.

**Tests anti-régression.** Couverts par les suites listées en §12.1 (`QuizServiceTests`,
`ExamServiceTests`, `ShopServiceTests`, `QuestServiceTests`, `SeasonServiceTests`,
`StreakRepairServiceTests` : idempotence par clé cliente) ; les plafonds de cadence sont vérifiés par
`AttemptIntegrityEvaluatorTests` (dépassement XP/tentatives → flags `IntegrityFlag.*RateExceeded`).

**Hors périmètre.** `cortex` (`wp-p1-09`), le mobile et le renderer contenu (`wp-p1-01`) ne sont pas
touchés ; la réserve `wp-p0-02` sur `NotificationService.UpsertAsync` reste différée.
