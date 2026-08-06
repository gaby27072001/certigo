<div align="center">

# 🟢 Certigo — État vivant du projet

**Le « Duolingo des certifications Microsoft » — apprendre Azure / IA / sécurité par micro‑leçons gamifiées.**

`🟢 Backend riche` · `🟢 Contenu migré (certigo-content)` · `🟢 Gamification` · `🟡 Tuteur IA (LLM réel ⏳ validation live)` · `🟢 Offline‑first` · `🟢 Mobile : écrans branchés` · `🟢 Infra dev/prod/CI` · `🟡 Staging à provisionner`

</div>

> [!NOTE]
> **Ce document est le miroir de la réalité du code à l'instant T.** Il est rafraîchi à chaque évolution
> traitée, dans le même changement. Trois documents complémentaires :
> - **`README.md`** → la **vision** et le pitch produit.
> - **`docs/ARCHITECTURE.md`** → le **design de référence / la cible** technique.
> - **`docs/ETAT_DU_PROJET.md`** (ce fichier) → **ce qui existe vraiment** maintenant. En cas de
>   divergence entre les trois, **c'est ce document qui fait foi.**

| Repère | Valeur |
|---|---|
| 📅 Rafraîchi le | **2026‑08‑06** (réconciliation du registre avec les PR content #7/#8 et les lots actifs) |
| 🔖 Reflète | `origin/main` à **0e30b7a** + les transitions documentaires de la branche `wp-p2-01` ; voir `docs/migration/STATE.md` pour le détail des lots |
| 🌿 Branche du doc | `gchambaud-microsoft-reconcile-migration-docs` |
| 📈 Activité | Phase 1 réconciliée ; `wp-p2-02` et `wp-p2-03` terminés ; `wp-p2-04` bloqué par le runner local avant validation/livraison ; `wp-p2-07` et `wp-p2-09` en cours |
| 🧪 Tests | Suites backend, mobile, contenu, Cortex et infrastructure exécutées par les workflows dédiés ; tests Cosmos émulateur‑gated |
| 🧩 API | **19 groupes** de Functions (+ `GET /health`) · **39 endpoints** HTTP |
| 🗄️ Données | **10 containers Cosmos DB** (serverless ; releases public/privé séparées et profil avec **ETag** concurrence optimiste) |
| 🏗️ Infra | **8 modules Bicep** + params **dev/staging/prod** — `dev`, `prod` et CI déployés ; `staging` reste à provisionner |
| 🤖 CI/CD | **17 workflows** GitHub Actions (15 actifs + 2 legacy iOS manuels inertes par défaut), dont les gates backend, mobile, contenu, registre de migration, Cortex, infra, sécurité, résilience runners et déploiement |
| 🔒 Durcissement | Idempotence atomique · ETag · garde auth dev · `/health` + correlation id · CORS/KV/Storage par env |

---

## 1 · Vue d'ensemble — où en est chaque brique

| Brique | Statut | Où | En clair |
|---|:---:|---|---|
| **API backend** | 🟢 | `backend/src/Certigo.Api` | Azure Functions .NET 8 isolé, **19 groupes / 39 endpoints**. |
| **Moteurs métier** | 🟢 | `backend/src/Certigo.Domain` | Logique **pure & testée** : contenu, progression, gamification, examen, tuteur, reco, notifications, intégrité. |
| **Contenu pédagogique** | 🟢 | [`certigo-content`](https://github.com/gchambaud_microsoft/certigo-content) | Source éditoriale active du corpus migré : contenu public, `answerKey`, schémas et manifeste immuable. `content/` est un instantané historique. |
| **Gamification** | 🟢 | Domain `Gamification/` | XP, streak (+réparation), ligues hebdo, **saisons**, quêtes, succès, boutique, amis. |
| **Tuteur IA** | 🟡 | Domain `Tutor/` + mobile `features/tutor` | Explications ancrées sur le contenu — **branché côté serveur ET mobile** (`tutor_sheet`). LLM réel **Azure OpenAI / Microsoft Foundry** (`AzureOpenAiTutorCompletion`, déploiement `gpt-5.4-mini`, surface API **v1**, auth **Entra ID** clé désactivée) derrière `ITutorCompletion`, activé par `TUTOR_LLM_ENABLED=true` (sinon repli déterministe `NullTutorCompletion`) ; **code prêt, compilé, couvert par `TutorCompletionTests`**. **RBAC à accorder en `dev`** (rôle _Cognitive Services OpenAI User_ sur `certigo-openai`, identité managée de `func-certigo-dev`) et **activé en `dev`** via `infra/params/dev.bicepparam` ; reste à valider **un appel réel** (`POST /tutor/explain` → 200 + explication LLM authentique) avant de basculer en 🟢. Voir H19. |
| **Recommandation + coach** | 🟢 | Domain `Recommendation/` + `home/coach_section` | Moteur « next best » + coach IA sur l'accueil. |
| **Notifications** | 🟢 | Domain `Notifications/` | Planification **serveur‑autoritaire**, estimation de la meilleure heure d'envoi. |
| **Anti‑triche / intégrité** | 🟢 (shadow) | Domain `Integrity/` | Évaluateur déterministe des tentatives — **mode détection** (signale, ne sanctionne pas encore). |
| **Offline‑first** | 🟢 | `packages/data` (sync) + `app/offline` | File de synchro idempotente, backoff, rejouable — **câblée dans l'app**. *(Seule la leçon en cours est disponible hors‑ligne pour l'instant ; la synchronisation complète du catalogue est planifiée — P3.)* |
| **Authentification** | 🟢 | API `Middleware/` + mobile `features/auth` | **Microsoft / Google / Apple** fédérés derrière **Entra External ID**, JWT validé serveur. |
| **Design system (Prism)** | 🟢 | `packages/prism_ui` | **28 composants** + tokens + thèmes (look « néon doux »). |
| **App mobile (Flutter)** | 🟢 | `apps/mobile` | 15 features. Tous les moteurs de gamification (saisons, quêtes, succès, boutique, amis, examens) sont **branchés en écran** + tests widget. Reste la validation E2E sur appareil. |
| **Cortex (algos partagés)** | 🟢 | `packages/cortex` | SRS, scoring, fil pédagogique — partagé client/serveur. |
| **Infrastructure (Bicep)** | 🟢 | `infra/` | 8 modules (Functions, Cosmos, Key Vault, App Insights, **Defender, Policy, Diagnostics**, Storage). **Déployée en `dev`** (`rg-certigo-dev`, westeurope). |
| **CI / qualité** | 🟢 | `.github/workflows` | **17 workflows** (15 actifs + 2 legacy iOS manuels inertes par défaut) : gates backend, mobile, contenu, registre de migration, Cortex, infra, sécurité, dépendances, résilience runners et déploiement. **Checkov hard-fail** (skip justifiés dans `.checkov.yaml`). |

**Légende :** 🟢 opérationnel & testé · 🟡 partiel / en cours · 🔴 absent.

---

## 2 · Carte du monorepo

```mermaid
graph TD
    ROOT["📦 Certigo (monorepo)"]

    ROOT --> BE["⚙️ backend/<br/>Azure Functions .NET 8"]
    ROOT --> APP["📱 apps/mobile/<br/>App Flutter"]
    ROOT --> PKG["🧩 packages/<br/>Paquets Dart partagés"]
    ROOT -.-> CNT["📚 certigo-content<br/>source éditoriale active"]
    ROOT --> HIST["content/<br/>instantané historique"]
    ROOT --> INF["🏗️ infra/<br/>8 modules Bicep"]
    ROOT --> CI[".github/workflows/<br/>17 workflows (15 actifs + 2 legacy opt-in)"]
    ROOT --> DOC["📄 docs/<br/>README · ARCHITECTURE · ÉTAT"]

    BE --> API["Certigo.Api<br/>18 groupes de Functions"]
    BE --> DOM["Certigo.Domain<br/>moteurs métier purs"]
    BE --> TST["Certigo.Tests<br/>unitaires + intégration Cosmos gated"]

    PKG --> CORE["core/ — base commune"]
    PKG --> CORTEX["cortex/ — SRS & scoring"]
    PKG --> DATA["data/ — modèles, réseau, offline, reco, tutor"]
    PKG --> PRISM["prism_ui/ — 28 composants"]

    APP --> FEAT["features/ (15)<br/>auth · home · path · lesson · quiz · tutor · leaderboard · profile · onboarding · seasons · quests · achievements · shop · friends · exam"]
    APP --> OFF["app/offline/<br/>synchro offline-first"]
```

---

## 3 · Architecture — le flux d'un quiz

```mermaid
flowchart LR
    U["📱 Apprenant"] -->|"connexion MS/Google/Apple"| AUTH["features/auth<br/>Entra External ID"]
    AUTH -->|"JWT"| MW["🛡️ JwtAuthMiddleware<br/>valide le porteur"]
    U -->|"répond à une leçon"| MOB["App Flutter"]
    MOB -->|"hors‑ligne ?"| Q["📥 File offline<br/>(rejouable, idempotente)"]
    Q -->|"reconnexion"| FUNC
    MOB -->|"en ligne · Bearer JWT"| FUNC["⚙️ Azure Functions"]
    FUNC --> MW
    MW --> DOM["🧠 Domain<br/>(scoring · XP · streak · ligue · intégrité)"]
    DOM --> INTEG["🔍 AttemptIntegrity<br/>verdict + score de risque"]
    DOM --> COSMOS[("🗄️ Cosmos DB<br/>8 containers")]
    DOM -->|"réponse : score, XP, paliers"| MOB
    MOB -->|"feedback son + haptique"| U
```

> L'app fonctionne **hors‑ligne** : les réponses sont mises en file puis **rejouées à la reconnexion**.
> Chaque tentative passe par l'évaluateur d'**intégrité** (anti‑triche) en mode détection.

---

## 4 · Fonctionnalités livrées (inventaire détaillé)

| Domaine | Backend | Mobile | Détail |
|---|:---:|:---:|---|
| **Profil & progression** | 🟢 | 🟢 | `GET /me`, parcours par certif, leçons paginées. |
| **Catalogue de certifs** | 🟢 | 🟢 | `GET /catalog/tracks` + **sélecteur de certification** (`cert_picker_sheet`). |
| **Leçons & exercices** | 🟢 | 🟢 | Leçon paginée façon Duolingo : QCM, multi‑réponses, scénario, texte à trous, **appariement**, **remise en ordre**, spot‑the‑issue. Son + haptique. |
| **Quiz & scoring** | 🟢 | 🟢 | `POST /quiz/{lessonId}/submit` → score, XP, paliers, feedback. |
| **Parcours « skill‑path »** | 🟢 | 🟢 | Écran vivant façon Duolingo, règles de progression pures. |
| **Streak (série)** | 🟢 | 🟡 | `GET /streak` + `POST /streak/repair` (réparation). |
| **Ligues hebdo** | 🟢 | 🟡 | Tournoi XP hebdomadaire serveur‑autoritaire + `GET /me/league/resolution`. |
| **Saisons** | 🟢 | 🟢 | Défi mensuel thématisé : `GET /season`, `POST /season/claim` — écran `seasons` (thème, paliers, réclamation). |
| **Quêtes & succès** | 🟢 | 🟢 | `GET /quests` + `claim`, `GET /achievements` — écrans `quests` & `achievements`. |
| **Boutique** | 🟢 | 🟢 | `GET /shop` + `POST /shop/purchase` (économie de gemmes) — écran `shop`. |
| **Amis & classement** | 🟢 | 🟢 | Ajouter/retirer un ami, `GET /friends/leaderboard` — écran `friends`. |
| **Partage quotidien** | 🟢 | 🟢 | `GET /share/daily` (carte de partage encodée) — écran `share-daily` (carte du jour + partage natif iOS/Android). |
| **Examens blancs** | 🟢 | 🟢 | Moteur adaptatif : `POST /exam/generate` + `submit` — écran `exam` (génération, soumission, score). |
| **Tuteur IA** | 🟢 | 🟢 | `POST /tutor/explain` — branché dans l'app via `tutor_sheet`. |
| **Recommandation + coach** | 🟢 | 🟢 | `GET /me/recommendations/{trackId}` + coach IA sur l'accueil. |
| **Notifications intelligentes** | 🟢 | 🟡 | `GET /me/notifications/plan` + réglages ; meilleure heure d'envoi estimée. |
| **Anti‑triche / intégrité** | 🟢 | — | Évaluateur déterministe (mode détection, événement `attempt.flagged`). **Fenêtre de cadence** (XP/tentatives sur 1 h, conteneur `attempts`) câblée pour **quiz et examens** → détecteurs de débit actifs. |
| **Offline‑first** | 🟢 | 🟢 | Synchro idempotente rejouable, backoff. |
| **Releases de contenu** | 🟡 | — | Implémentation en branche : import public/privé vérifié, promotion atomique par environnement, historique et rollback N-1 par `manifestId`, aucune route privée mobile. Validation et PR bloquées par le runner local. |
| **Authentification** | 🟢 | 🟢 | Microsoft / Google / Apple via Entra External ID (Android + iOS natifs câblés). |

> **Lecture clé :** l'écart backend ↔ UI est désormais **comblé pour la gamification** : saisons, quêtes,
> succès, boutique, amis et examens disposent d'un **écran mobile + test widget**. Restent à exposer le
> **partage quotidien** et la **validation E2E sur appareil**.

---

## 5 · Contenu pédagogique

```mermaid
graph LR
    E["📚 certigo-content<br/>source éditoriale active"] --> P["Payloads publics"]
    E --> K["answerKey privés"]
    E --> S["Schémas versionnés"]
    E --> M["Manifeste immuable<br/>adressable par hash"]
    H["Certigo/content/<br/>instantané historique"] -. "compatibilité seulement" .-> E
```

Les PR éditoriales, la validation des schémas et la publication du manifeste sont réalisées dans
`gchambaud_microsoft/certigo-content`. Le dossier `content/` de ce monorepo ne doit plus être
présenté ni utilisé comme source éditoriale active.

---

## 6 · Surface API (39 endpoints · 19 groupes)

```mermaid
graph TD
    subgraph Profil & parcours
        A1["GET /me"]
        A2["GET /catalog/tracks"]
        A3["GET /me/paths/{trackId}"]
        A4["GET /tracks/{trackId}/lessons/{lessonId}"]
        A5["GET /me/recommendations/{trackId}"]
    end
    subgraph Apprentissage
        B1["POST /quiz/{lessonId}/submit"]
        B2["POST /exam/generate"]
        B3["POST /exam/submit"]
        B4["POST /tutor/explain"]
    end
    subgraph Gamification
        C1["GET /me/league (+ /resolution)"]
        C2["GET /season · POST /season/claim"]
        C3["GET /quests · POST /quests/claim"]
        C4["GET /achievements"]
        C5["GET /shop · POST /shop/purchase"]
        C6["GET /streak · POST /streak/repair"]
    end
    subgraph Social & rappels
        D1["GET/POST/DELETE /friends ..."]
        D2["GET /friends/leaderboard"]
        D3["GET /share/daily"]
        D4["GET /me/notifications/plan · settings"]
    end
```

Pile : **Azure Functions .NET 8 (worker isolé)**, déclencheurs HTTP, middleware JWT global avec liste
d'exemptions (endpoints anonymes), accès Cosmos via le SDK officiel.

---

## 7 · Cortex — les algorithmes partagés

`packages/cortex` héberge la logique pédagogique **réutilisée côté client et serveur** :

- **SRS (répétition espacée)** — planification des révisions.
- **Scoring & maîtrise** — calcul du niveau de maîtrise par compétence.
- **Fil pédagogique** — ordonnancement « quoi montrer ensuite ».

Doublé d'équivalents côté Domain (`Progress/ReviewScheduler`, `Readiness/ReadinessCalculator`) pour
les décisions serveur‑autoritaires.

---

## 8 · Sécurité & intégrité

| Mécanisme | Où | Comportement |
|---|---|---|
| **Auth multi‑fournisseurs** | mobile `features/auth` | Microsoft · Google · Apple, fédérés derrière **Entra External ID** via `flutter_appauth` ; session persistante (`session_store`). |
| **Validation JWT** | `Api/Middleware/JwtAuthMiddleware` | Vérifie le porteur `Bearer` sur chaque requête, sauf endpoints explicitement anonymes. |
| **Config native Android** | `apps/mobile/android` | Schéma de redirection `certigo://auth` + permission `INTERNET` (#46). |
| **Config native iOS** | `apps/mobile/ios` | URL Scheme `certigo` déclaré dans `Info.plist` pour le callback OIDC `certigo://auth`. |
| **Anti‑triche** | `Domain/Integrity/AttemptIntegrity` | Évaluateur **déterministe & pur** → verdict `Allow / Flag / Reject` + score de risque [0..1] + drapeaux nommés (vitesse surhumaine, soumission avant départ, débit XP excessif…). **Mode détection** d'abord (signale, ne touche pas aux récompenses). **Fenêtre de cadence** (XP + nombre de tentatives sur 1 h, lue du conteneur `attempts`, sans Redis) alimentée côté **`QuizService` et `ExamService`** → détecteurs `XpRateExceeded`/`AttemptRateExceeded` actifs. |
| **Baseline sécurité CI** | `.github/workflows` | **CodeQL** + **security‑scan** + Bicep `Defender` / `Policy` / `Diagnostics`. |

---

## 9 · Données — Cosmos DB (8 containers)

| Container | Clé de partition | Contenu |
|---|---|---|
| `users` | `/id` | Profils & préférences. |
| `content` | `/trackId` | Certifs & leçons publiées. |
| `progress` | `/userId` | Progression, maîtrise, streak. |
| `attempts` | `/userId` | Tentatives de quiz/examen (+ intégrité). |
| `events` | `/userId` | Journal d'événements (`attempt.flagged`, etc.). |
| `leaderboard` | `/periodLeagueId` | Classements ligues / saisons. |
| `economy` | `/userId` | Gemmes, achats boutique. |
| `friends` | `/userId` | Graphe social. |

> Mode **serverless** : on paie à la requête, idéal tant que la charge est faible.

> Les dépôts Cosmos (`users`, `attempts`, `friends`) sont couverts par un **projet de tests
> d'intégration** (`backend/tests/Certigo.Infrastructure.Tests`, 6 cas) exécuté contre l'**émulateur
> Cosmos** — gated par `CERTIGO_COSMOS_TESTS=1`, **skippé proprement** sans émulateur (runtime réel
> non exécuté dans cet environnement).

---

## 10 · Infrastructure (Bicep) — déployée (dev / prod / CI), staging à provisionner

```mermaid
graph TD
    M["infra/main.bicep"] --> F["functionApp<br/>Flex Consumption"]
    M --> C["cosmos<br/>8 containers serverless"]
    M --> K["keyvault<br/>secrets"]
    M --> A["appInsights<br/>télémétrie"]
    M --> S["storage<br/>AzureWebJobs"]
    M --> D["defender<br/>Defender for Cloud"]
    M --> P["policy<br/>gouvernance Azure"]
    M --> G["diagnostics<br/>logs/metrics"]
```

**8 modules** prêts. Les environnements **`dev`**, **`prod`** et **CI** sont déployés sur Azure (subscription MCAPS Hybrid `b8952c8c`) — `rg-certigo-dev`, `rg-certigo-prod` (**entièrement en réseau privé**) et `rg-certigo-ci`. **Seul `staging` n'est pas déployé** (bien que `infra/params/staging.bicepparam` existe).

> ℹ️ État d'infra vérifié le **2026-07-04** — voir [`AUDIT_Certigo.md`](../AUDIT_Certigo.md) (source de vérité de l'état d'infra).

---

## 11 · Qualité & CI

| Workflow | Rôle |
|---|---|
| `ci-backend.yml` | Build + tests xUnit (.NET 8) + intégration Cosmos émulateur‑gated. |
| `ci-mobile.yml` | Analyse + tests Dart unitaires/widget, dont le gate de golden tests Prism. |
| `ci-content.yml` | Validation des leçons/certifs contre les schémas JSON. |
| `ci-migration-registry.yml` | Cohérence des statuts, états et dépendances du registre de migration. |
| `ci-cortex-parity.yml` | Parité des règles Cortex entre Dart et .NET sur vecteurs partagés. |
| `ci-infra.yml` | Lint / what‑if Bicep. |
| `runner-resilience-drill.yml` | Drill manuel de bascule du pool self-hosted ou du repli break-glass autorisé. |
| `cd-backend.yml` | Déploiement backend vers l'environnement cible. |
| `codeql.yml` | Analyse statique de sécurité. |
| `dependency-vuln-scan.yml` | Scan des vulnérabilités de dépendances. |
| `deploy-privacy-policy.yml` | Publication de la politique de confidentialité. |
| `lint-workflows.yml` | Lint des workflows GitHub Actions du dépôt. |
| `promote-backend-staging-prod.yml` | Promotion contrôlée du backend staging → prod. |
| `release-android.yml` | AAB Android signé + publication Google Play. |
| `security-scan.yml` | Scan sécurité complémentaire (NuGet + Bicep). |

> `release-ios.yml` et `sync-ios-certs.yml` sont conservés comme références
> historiques. Ils sont inertes par défaut et exigent l'opt-in manuel
> `enable_legacy_workflow=true` ; la chaîne iOS active est gérée par Codemagic.

> ⚠️ CI exécutée **uniquement sur le runner self‑hosted Azure** (`certigo-ci`) — les runners
> GitHub‑hébergés sont désactivés par la politique d'entreprise. Egress via NAT Gateway `nat-certigo` (RG `rg-certigo-ci`).

> 🛟 **Repli CI backend (audit #1, SPOF runner)** — le job `build-test` de `ci-backend.yml` a un
> repli `ubuntu-latest` **pré‑câblé mais inerte par défaut** (comportement inchangé = self‑hosted).
> Pour l'activer en cas de panne du pool self‑hosted, **deux** prérequis : (1) définir la variable repo
> `BACKEND_CI_FALLBACK = true` (Settings › Actions › Variables) ; (2) un admin doit **réactiver les
> runners GitHub‑hébergés** pour le repo/org (désactivés par défaut ici). Repasser la variable à `false`
> pour revenir au self‑hosted. Runbook détaillé en commentaire au‑dessus du `runs-on:` du job.

---

## 12 · Journal d'évolution

> Du plus récent au plus ancien. Mis à jour à chaque session de travail sur le projet.

| Date | Évolution |
|---|---|
| 2026‑08‑06 | 📦 **Phase 2 avancée** : `wp-p2-02` et `wp-p2-03` sont `done` après fusion des PR `certigo-content` #7/#8 ; `wp-p2-04`, `wp-p2-07` et `wp-p2-09` sont en cours dans leurs sessions dédiées. |
| 2026‑08‑05 | 📚 **Registre de migration réconcilié** : seuls les lots Phase 1 dont la DoD complète est satisfaite sont alignés à `done` dans le manifeste, les états JSON et la vue humaine ; les lots incomplets restent ouverts même si une PR associée a été fusionnée. Démarrage de `wp-p2-01` documentaire ; `wp-p2-02..09` ont alors été enregistrés à `todo`, avant leur exécution dans des sessions distinctes. |
| 2026‑06‑29 | 🧪 **Tests Cosmos exécutés sur émulateur réel** : 6 cas `Certigo.Infrastructure.Tests` lancés (0 ignoré) sur l'émulateur Docker `vnext-preview` (ARM64, HTTPS) → **5/6 verts** ; le 6e (agrégat `GetRecentActivityAsync`) bute sur une limite _vnext-preview_ (`RewrittenAggregateProjections`), pas un bug prod (classic amd64 inutilisable sur ARM64 : `exec format error` / segfault QEMU). ✅ **Couverture HTTP des 15 Functions** restantes ajoutée (faux services + harness) → suite globale **496** verte. |
| 2026‑06‑28 | 🛟 **Repli CI backend (audit #1)** : repli `ubuntu-latest` pré‑câblé (inerte par défaut) sur le job `build-test` de `ci-backend.yml`, piloté par la variable repo `BACKEND_CI_FALLBACK` — comportement self‑hosted inchangé ; activation conditionnée à la réactivation des runners GitHub‑hébergés (cf. §11). |
| 2026‑06‑24 | 📱 **Écrans gamification mobile** : saisons · quêtes · succès · boutique · amis · examens blancs branchés (couche data + providers + router) → 6 écrans + 6 tests widget ; suite Dart **185** verte. 🧪 **Tests d'intégration Cosmos** (`Certigo.Infrastructure.Tests`, 6 cas émulateur‑gated, skippés proprement hors émulateur). |
| 2026‑06‑24 | 🔐 **Connexion sociale iOS** : ajout du callback natif `certigo://auth` dans `Info.plist` + messages d'erreur login plus explicites (redirect/client/provider) côté mobile. |
| 2026‑06‑24 | 🛡️ **Anti‑triche examen** : fenêtre de cadence (XP/tentatives sur 1 h, conteneur `attempts`) câblée dans `ExamService` — miroir de `QuizService` → détecteurs de débit actifs aussi pour les examens blancs ; test dédié `SubmitAsync_flags_submission_spam_via_the_rate_window`. Backend **325** tests verts. |
| 2026‑06‑23 | 🛡️ **Remédiation post‑audit** : intégrité économie (ETag + idempotence atomique), garde auth dev en prod, parité Cortex (golden tests), `/health` + correlation id, 400/409, hardening infra par env + params staging/prod, SBOM + gate de release, validateur de contenu renforcé — voir `AUDIT_CERTIGO.md` §M |
| 2026‑06‑23 | 🔐 **Config Android native** activant la connexion Entra (`certigo://auth` + INTERNET) — #46 |
| 2026‑06‑23 | 🔍 **Anti‑triche** : moteur d'intégrité de tentative + détection « shadow » (quiz/examen) — #43 |
| 2026‑06‑23 | 🪪 **Auth multi‑fournisseurs** Microsoft / Google / Apple + session persistante — #41 |
| 2026‑06‑23 | 🗓️ **Saisons** : moteur de défi mensuel thématisé serveur‑autoritaire — #42 |
| 2026‑06‑23 | 🔔 **Notifications** : planification intelligente serveur‑autoritaire — #40 |
| 2026‑06‑23 | 🎚️ **Sélecteur de certifs** + bandeau de parcours figé + texte enrichi propre — #38 |
| 2026‑06‑23 | 📥 **Offline‑first** : synchro idempotente + câblage app — #39 |
| 2026‑06‑23 | 🏆 **Ligues** : tournoi XP hebdomadaire serveur‑autoritaire — #27 |
| 2026‑06‑23 | 🛠️ **Infra** : alignement réglages Function App ↔ code, RBAC Cosmos, baseline sécurité CI — #8 |
| 2026‑06‑23 | 🎮 **5 types d'exercices** façon Duolingo + son/haptique (iOS + Android) — #15 |
| 2026‑06‑23 | 🧗 **Skill‑path** : écran de parcours vivant + règles de progression pures — #14 |
| 2026‑06‑23 | 🧭 **Reco « next best »** + coach IA sur l'accueil — #13 |
| 2026‑06‑23 | 🤝 **Tuteur IA branché** dans le client Flutter (iOS + Android) — #12 |
| 2026‑06‑23 | 🧠 **Tuteur IA backend** ancré sur le contenu, apprentissage continu — #11 |
| 2026‑06‑22 | 📝 **Examen blanc adaptatif** (génération + scoring) — #10 |
| 2026‑06‑22 | 🏗️ Bascule sur **runner self‑hosted Azure** + egress NAT — #9 |
| 2026‑06‑23 | 📄 **Ce tableau de bord vivant** créé puis tenu à jour. |

---

## 13 · Prochaines étapes & écarts

**Écarts backend ↔ mobile (à brancher en UI) :**
- 🟢 Saisons, quêtes, succès, boutique, amis, examens blancs, partage quotidien : **écrans livrés** (+ tests widget) — reste la **validation E2E sur appareil**.
- 🟡 Streak‑repair, ligues, notifications : partiellement exposés.

**Chantiers techniques :**
- 🏗️ **Provisionner `staging`** par Bicep et valider `/health` ; `dev`, `prod` et CI sont déjà déployés.
- 🔐 **Valider l'auth de bout en bout** sur un vrai tenant Entra External ID (E2E).
- 🔍 **Faire passer l'anti‑triche** du mode détection au mode application des sanctions (lot suivant) — la **fenêtre de cadence** (débit XP/tentatives sur 1 h) est désormais câblée pour **quiz et examens** ; reste la calibration puis la bascule en mode sanction.
- ✅ **Tests d'intégration Cosmos exécutés sur émulateur réel** (le projet `Certigo.Infrastructure.Tests` est gated `CERTIGO_COSMOS_TESTS=1`). Les **6 cas ont tourné** (0 ignoré) contre l'émulateur Docker `mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview` (ARM64, HTTPS) : **5/6 verts**. Le 6e — `Attempt_recent_activity_aggregates_count_and_xp_within_window` (`CosmosAttemptRepository.GetRecentActivityAsync`, agrégat `COUNT(1)`/`SUM` projeté en objet `VALUE { … }`) — échoue **uniquement** sur l'émulateur _vnext-preview_ (back‑end PostgreSQL) avec `RewrittenAggregateProjections was not an array for a value aggregate query`. **Ce n'est pas un bug de production** : la requête est valide contre Cosmos réel et l'émulateur classic ; on **ne réécrit pas** la requête pour contourner une limite de l'émulateur preview. L'émulateur **classic amd64** est **inutilisable sur cet hôte ARM64** (`exec format error` sans QEMU ; `segfault signal 11` même avec QEMU x86_64 binfmt installé), d'où la cible 6/6 hors de portée localement — à confirmer en CI/Cosmos réel.
  - _Relancer la suite_ : `docker run -d --name cosmos-emulator -p 8081:8081 -p 1234:1234 -e PROTOCOL=https mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview` (attendre `PostgreSQL=OK, Gateway=OK, Explorer=OK` dans `docker logs`), puis exporter `CERTIGO_COSMOS_TESTS=1`, `COSMOS_EMULATOR_ENDPOINT=https://localhost:8081`, `COSMOS_EMULATOR_KEY=<clé publique émulateur>` et lancer `dotnet test backend\tests\Certigo.Infrastructure.Tests`.
- ✅ **Couverture HTTP/middleware Functions complétée** : tests ajoutés pour les **15 Functions** jusque‑là non couvertes (User, Tutor, Streak, Shop, ShareCard, Season, Recommendation, Quest, Path, Notification, Lesson, Leaderboard, Friend, Exam, Achievement) via le harness maison (`FunctionTestHost` + faux services dans `Fakes.Functions.cs`) — happy‑path authentifié (200 + service appelé 1×) et garde non‑authentifié. **Suite globale `dotnet test backend\Certigo.sln` : 496 verts, 0 échec** (6 cas Cosmos `Skipped` proprement quand le gate est off).
- 🤖 **Tuteur IA — valider l'appel LLM réel** : le provider Azure OpenAI / Foundry (`gpt-5.4-mini`, surface **v1**, auth **Entra ID**) est **câblé, compilé et couvert par tests unitaires**. **RBAC à accorder en `dev`** (rôle _Cognitive Services OpenAI User_ sur `certigo-openai` pour l'identité managée de `func-certigo-dev`) et **activé en `dev`** (`infra/params/dev.bicepparam` → app settings `TUTOR_LLM_*`, déployés par `cd-backend`). Reste **un appel réel de validation** (register/login → JWT → `POST /api/tutor/explain` → 200 + explication LLM authentique) pour confirmer le chemin live et basculer le statut en 🟢 ; tant que cet appel n'est pas validé, le tuteur garde le repli déterministe en filet.

---

<div align="center">

### 🔄 Comment ce document reste à jour

À chaque évolution traitée dans une session de travail sur Certigo, ce fichier est **rafraîchi dans
le même commit / la même PR** : en‑tête (date + commit reflété), Vue d'ensemble, inventaire des
fonctionnalités, contenu, API, données et **Journal d'évolution**. Pas de workflow autonome —
la mise à jour fait partie du travail.

_Dernier rafraîchissement : 2026‑08‑06 · registre réconcilié avec les PR content #7/#8 et les lots Phase 2 actifs._

</div>
