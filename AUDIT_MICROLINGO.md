# Audit technique exhaustif — Microlingo

> Audit indépendant, factuel et sans complaisance, réalisé au niveau d'exigence d'une
> grande entreprise technologique. Chaque conclusion est reliée à un élément observable
> dans le dépôt (`fichier:ligne`). Les niveaux de certitude sont explicites :
> **[CERTAIN]** (vérifié dans le code), **[PROBABLE]** (déduit, cohérent mais non exécuté),
> **[INCONNU]** (non vérifiable depuis le dépôt), **[À VÉRIFIER]** (nécessite une validation humaine).
>
> | Repère | Valeur |
> |---|---|
> | Périmètre | Tout le monorepo (mobile, backend, infra, contenu, tools, CI/CD, docs, archives Git) |
> | Commit audité | `9c488c6` (HEAD de la branche d'audit) |
> | Historique | **47 commits, 1 seul auteur, du 2026‑06‑19 au 2026‑06‑23 (5 jours)** |
> | Méthode | Cartographie → lecture directe du code + 5 revues de domaine parallèles → recoupement |
> | Tests recensés | **256 backend** (xUnit, exact) + **~177 Dart** (unit/widget) ≈ **433** |

---

## Sommaire

- [A. Executive summary](#a-executive-summary)
- [B. État actuel du projet](#b-état-actuel-du-projet)
- [C. Ce qui est bien fait](#c-ce-qui-est-bien-fait)
- [D. Problèmes identifiés](#d-problèmes-identifiés)
- [E. Zones d'ombre / incertitudes](#e-zones-dombre--incertitudes--éléments-à-confirmer)
- [F. Dette technique](#f-dette-technique)
- [G. Matrice des risques](#g-matrice-des-risques)
- [H. Recommandations d'amélioration](#h-recommandations-damélioration)
- [I. Améliorations pour rendre l'app meilleure](#i-améliorations-pour-rendre-lapp-meilleure)
- [J. Priorisation](#j-priorisation)
- [K. Roadmap recommandée](#k-roadmap-recommandée)
- [L. Scorecard finale](#l-scorecard-finale)
- [Conclusion franche (7 questions)](#conclusion-franche)

---

## A. Executive summary

**Microlingo est un prototype avancé, exceptionnellement large et bien architecturé pour son
âge, mais qui n'est pas prêt pour la production.** En 5 jours et 47 commits réalisés par un
**unique auteur**, le projet a accouché d'un monorepo cohérent : application Flutter (iOS +
Android), 4 paquets Dart partagés, un backend .NET 8 isolated en Clean Architecture avec ~16
services et ~28 endpoints, 5 référentiels de contenu (60 leçons YAML), de l'IaC Bicep, 9
workflows CI/CD et une documentation soignée. La **discipline d'ingénierie est réelle** :
identités managées, notation des quiz autoritaire côté serveur, stockage sécurisé des jetons,
analyse statique stricte, ~433 tests déterministes.

Mais sous une surface très propre, l'audit révèle des **fragilités structurelles concrètes** :

1. **Intégrité transactionnelle absente** sur l'économie de jeu (gemmes, XP, streak) :
   lectures‑modifications‑écritures sans ETag ni transaction → **double‑crédit et écritures
   perdues** sous concurrence ou rejeu (`Services.cs` `QuizService.SubmitAsync`).
2. **Bypass d'authentification de développement** verrouillé uniquement par une variable de
   configuration (`AUTH_MODE=dev`), sans garde‑fou d'environnement (`Program.cs:48`).
3. **Infrastructure jamais déployée**, sans environnement prod/staging, avec un plan de
   données **public** (Cosmos public, CORS `*`, Key Vault sans purge protection).
4. **Couches critiques non testées** : 0 test sur les Functions HTTP, 0 sur le middleware
   d'auth, couche Cosmos seulement mockée — c'est‑à‑dire précisément là où vivent les bugs
   de concurrence et de sécurité.
5. **Bus‑factor = 1** et **documentation « vivante » déjà périmée** (elle reflète un commit
   d'il y a 4 PR).
6. Plusieurs **promesses produit en avance sur la réalité** : le « Tuteur IA » n'a **aucun
   LLM branché** (adaptateur nul), les moteurs Cortex client/serveur annoncés « identiques au
   byte près » **divergent déjà**, et l'« offline‑first » ne met hors‑ligne qu'**une** leçon.

**Niveau de maturité : prototype avancé / squelette de MVP — pré‑production.**
**Forces principales :** architecture propre, logique métier pure et testée, sécurité par
conception (MI, server‑authoritative, secure storage), moteur offline robuste, contenu réel.
**Risques principaux :** intégrité concurrentielle, sécurité du plan de données et du bypass
dev, absence de déploiement reproductible, trous de tests aux frontières, bus‑factor 1.
**Verdict : Conditional GO pour bêta interne uniquement ; 4 à 6 semaines de durcissement
sont nécessaires avant toute mise à l'échelle.**

---

## B. État actuel du projet

| Dimension | État | Commentaire |
|---|---|---|
| **Maturité** | Prototype avancé | Très complet pour 5 jours, mais jamais déployé ni exécuté E2E sur un vrai tenant. |
| **Stabilité** | Inconnue en réel | ~433 tests verts en logique pure ; aucun test d'intégration, aucune charge réelle, aucune release tagguée (0 tag Git). |
| **Industrialisation** | Partielle | CI riche et signature mobile décrites, mais runner unique self‑hosted (SPOF), infra non provisionnée, pas de prod/staging. |
| **Cohérence** | Bonne, avec dérives | Architecture cohérente ; docs et code divergent sur des chiffres clés et des promesses (cf. §E). |
| **Dettes visibles** | Modérées mais ciblées | God‑file `Services.cs` (96 Ko), duplication client/serveur, absence de concurrence optimiste, trous de tests aux frontières. |
| **Capacité à évoluer** | Élevée | Découpage modulaire, ports/abstractions propres, contenu‑as‑code → la base se prête à grandir. |
| **Robustesse globale** | Inégale | Excellente sur la logique pure et l'offline ; fragile sur la concurrence, le plan de données et l'exploitation. |

**Lecture clé :** le **backend est nettement en avance sur l'UI** (saisons, quêtes, boutique,
amis, examens blancs sont prêts côté serveur mais non branchés en écran — confirmé par
`docs/ETAT_DU_PROJET.md` §4 et l'absence d'écrans correspondants dans `apps/mobile/lib/features`).
L'app est solide mais ne consomme qu'une fraction de la surface API.

---

## C. Ce qui est bien fait

Forces **réelles et vérifiées**, sur lesquelles capitaliser :

1. **[CERTAIN] Architecture en couches propre côté backend.** `Domain` ne dépend de rien ;
   `Infrastructure` implémente les ports de `Application` ; injection correcte dans
   `Program.cs:31-90`. Le sens des dépendances annoncé dans `docs/ARCHITECTURE.md` est respecté.
2. **[CERTAIN] Logique métier pure et richement testée.** FSRS, readiness, XP, ligues,
   notifications, intégrité, examens : 256 tests xUnit déterministes (horloges injectées,
   dates figées). Recensement exact : 170 tests `Domain` + 86 tests `Application`.
3. **[CERTAIN] Notation autoritaire côté serveur.** `QuizService.SubmitAsync` récupère la clé
   de correction serveur (`Services.cs:141`) et recalcule score/XP/maîtrise ; le client ne
   reçoit la bonne réponse que s'il s'est trompé (`Services.cs:176`).
4. **[CERTAIN] Identités managées, zéro secret applicatif.** Cosmos via `DefaultAzureCredential`
   (`Program.cs:31`), accès Key Vault et Cosmos par RBAC. **Aucun secret committé** (recherche
   exhaustive de motifs `AccountKey=`, clés privées, `client_secret`, mots de passe : 0 résultat).
5. **[CERTAIN] Stockage sécurisé des jetons côté mobile.** `flutter_secure_storage` (Keychain
   iOS / Keystore Android, `encryptedSharedPreferences`) — `session_store.dart:22-49`. Pas de
   jeton en clair.
6. **[CERTAIN] Authentification mobile réelle (non simulée).** OIDC + PKCE via `flutter_appauth`
   contre Entra External ID (`auth_gateway.dart:29-138`), refresh silencieux, gestion du 401 →
   re‑auth (`api_client.dart:38-44`).
7. **[CERTAIN] Moteur offline de qualité production.** File idempotente, déduplication par clé,
   backoff exponentiel borné (2 s→5 min, 6 tentatives, dead‑letter), persistance, auto‑pruning
   (`packages/data/lib/src/sync/sync_engine.dart`). Sémantique at‑least‑once réconciliée par
   `clientAttemptId`.
8. **[CERTAIN] Erreurs serveur non divulgantes.** `ExceptionMiddleware` renvoie un
   `ProblemDetails` générique, journalise côté serveur seulement (`ExceptionMiddleware.cs:28-35`).
9. **[CERTAIN] Contenu‑as‑code rigoureux.** Schémas JSON stricts (`additionalProperties:false`,
   poids de domaine ∈ [0,1], `explanation.minLength:10`), 60 leçons cohérentes, séparation
   public / `answerKey` au seed (`tools/seed_content.py`).
10. **[CERTAIN] Gates de qualité bloquantes.** `dotnet build -warnaserror` (`ci-backend.yml:30`),
    `dart format --set-exit-if-changed` + `flutter analyze` + tests (`ci-mobile.yml`), scan CVE
    NuGet en échec dur (`security-scan.yml:38-41`). Analyse statique stricte
    (`analysis_options.yaml` : `strict-casts`, `unawaited_futures: error`, `dead_code: error`).
11. **[CERTAIN] Documentation et onboarding au‑dessus de la moyenne.** README, ARCHITECTURE,
    ETAT_DU_PROJET, RELEASE_MOBILE (420 lignes), diagrammes mermaid, ADR. `infra/ci-runner/README.md`
    explique même les faux positifs `what-if`.
12. **[CERTAIN] Dette de marqueurs faible.** 0 `TODO/FIXME` dans le backend ; un seul significatif
    côté mobile (`bootstrap.dart:25` : crash reporting non câblé).

---

## D. Problèmes identifiés

> Format : **Titre** · *Domaine* · Description · **Preuve** · Impact · **Gravité / Probabilité** ·
> Risque court terme / long terme · **Cause probable** · **Recommandation**.

### D1 — Économie de jeu sans atomicité ni concurrence optimiste · *Backend / Intégrité*
- **Description.** `QuizService.SubmitAsync` lit le profil, le modifie (XP, gemmes, streak,
  succès, mensuel) puis l'`UpsertAsync` **sans ETag**, et enchaîne des écritures séquentielles
  **non transactionnelles** (profil → maîtrise → learner model → leaderboard → tentative →
  événement). La garde d'idempotence lit la tentative **au début** (`Services.cs:135`) mais
  l'enregistrement de la tentative (porteur du `clientAttemptId`) n'est persisté qu'**à la fin**
  (`Services.cs:273`).
- **Preuve.** `Services.cs:135-139` (garde), `:251` (upsert profil sans `IfMatchETag`), `:261`
  (leaderboard), `:273` (`attempts.CreateAsync` en dernier). Schéma identique signalé dans
  `ShopService.PurchaseAsync`, `StreakRepairService`, `LeaderboardRepository.AddXpAsync` [PROBABLE].
- **Impact.** **Double‑crédit de gemmes/XP** sur rejeu (échec partiel entre `:251` et `:273`,
  ou deux soumissions concurrentes du même `clientAttemptId`) ; **écritures perdues** sous
  concurrence (deux appareils, soumissions rapprochées) → solde de gemmes faux. Les gemmes
  étant une monnaie dépensable (boutique), c'est un défaut d'intégrité économique exploitable.
- **Gravité : Critique · Probabilité : Moyenne→Élevée** (toute charge concurrente ou rejeu réseau).
- **CT :** incohérences de solde, rejeux fantômes. **LT :** triche/économie corrompue, support coûteux.
- **Cause.** Méthode d'orchestration « god‑method » écrite en chemin heureux, sans frontière
  transactionnelle ni `IfMatchETag`, sans contrainte d'unicité Cosmos sur `clientAttemptId`.
- **Reco.** (1) Écrire la tentative `clientAttemptId` **en premier** ou via une clé unique
  Cosmos ; (2) ajouter `ItemRequestOptions { IfMatchETag = profile.ETag }` + retry sur 412 ;
  (3) regrouper les écritures d'une même partition utilisateur dans un `TransactionalBatch`.

### D2 — Bypass d'auth « dev » non verrouillé par environnement · *Sécurité*
- **Description.** `DevTokenValidator` traite le **jeton porteur comme l'`userId`** ; il est
  enregistré dès que `AUTH_MODE=dev`, sans aucune assertion d'environnement. Le client a un
  pendant : `AppEnv.devAuthToken` vaut `'dev'` par défaut et est envoyé tant qu'Entra n'est pas
  configuré.
- **Preuve.** `DevTokenValidator.cs:15-17`, `Program.cs:48-59`, `app_env.dart:31-34`.
- **Impact.** Si un déploiement part avec `AUTH_MODE=dev` (ou sans Entra configuré côté app),
  **n'importe qui peut se faire passer pour n'importe quel utilisateur** via
  `Authorization: Bearer <userId>`.
- **Gravité : Critique (si déclenché) · Probabilité : Faible→Moyenne** (dépend de la discipline
  de configuration ; le défaut sûr est Entra, mais rien n'empêche l'erreur).
- **CT :** usurpation totale en environnement mal configuré. **LT :** incident de sécurité majeur.
- **Cause.** Garde par simple chaîne de config, sans fail‑safe `if (!IsDevelopment) throw`.
- **Reco.** Lever une exception au démarrage si `DevTokenValidator` est sélectionné hors
  développement ; bannir `AUTH_MODE=dev` des paramètres prod/staging (validation Bicep) ;
  alerter si le validateur dev est actif.

### D3 — Plan de données public et durcissement cloud incomplet · *Infra / Sécurité cloud*
- **Description.** Function App en **CORS `['*']`**, Cosmos en **accès réseau public**
  (`disableLocalAuth:false`), **Key Vault sans purge protection** (soft delete 7 j seulement),
  Storage en **LRS** sans soft delete/versioning. Aucun endpoint privé.
- **Preuve.** [PROBABLE, cités par la revue infra] `infra/modules/functionApp.bicep` (CORS=['*']),
  `cosmos.bicep` (public), `keyvault.bicep` (pas de `enablePurgeProtection`), `storage.bicep` (LRS).
- **Impact.** Surface d'exposition élevée du plan de données ; CORS `*` autorise tout origine ;
  pas de protection contre la purge accidentelle/malveillante du coffre ; aucune redondance/DR
  du stockage.
- **Gravité : Élevée · Probabilité : Moyenne.**
- **CT :** exposition inutile, risque de fuite si une clé/identité fuit. **LT :** non‑conformité
  (CIS 7.2/9.1), perte de données sans DR.
- **Cause.** IaC dimensionnée pour un dev rapide, paramètres de durcissement non posés.
- **Reco.** Restreindre CORS aux domaines connus ; endpoints privés (Cosmos/Storage/KV) ;
  `enablePurgeProtection:true` + soft delete 90 j ; Storage GRS/GZRS + versioning ;
  `disableLocalAuth:true` sur Cosmos en prod.

### D4 — Frontières critiques non testées (HTTP, middleware, Cosmos) · *Tests*
- **Description.** ~433 tests mais **0 test des Functions HTTP**, **0 test du middleware d'auth**,
  couche **Cosmos uniquement mockée** (`InMemory*Repository`). Les couches non testées sont
  exactement celles qui portent les risques D1/D2.
- **Preuve.** `backend/tests/**` ne contient aucun test de `*Functions.cs` ni de
  `JwtAuthMiddleware.cs`/`ExceptionMiddleware.cs` ; tous les services testés via `Fakes.cs`.
- **Impact.** Aucune garantie automatisée sur : validation du Bearer, endpoints anonymes,
  sérialisation, JSON malformé (→ 500 au lieu de 400), concurrence/ETag/partition Cosmos.
- **Gravité : Élevée · Probabilité : Élevée** (un défaut à ces frontières ne sera pas détecté).
- **CT :** régressions d'auth/contrat non vues. **LT :** confiance illusoire (couverture
  numérique élevée mais aveugle là où ça compte).
- **Cause.** Stratégie de test centrée sur la logique pure (rapide, déterministe), frontières
  laissées de côté.
- **Reco.** Tests d'intégration Functions (test SDK) + middleware ; tests Cosmos via émulateur
  (concurrence, partition keys, ETag) ; quelques tests E2E mobile (`integration_test`).

### D5 — God‑file `Services.cs` (96 Ko, 16 services) · *Architecture / Maintenabilité*
- **Description.** Toute la couche Application tient dans **un seul fichier de 96 807 octets**
  regroupant 16 classes `*Service` (de `UserService` à `NotificationService`).
- **Preuve.** `backend/src/Microlingo.Application/Services/Services.cs` ; classes à
  `:22, 83, 122, 385, 489, 569, 678, 804, 841, 1003, 1063, 1184, 1284, 1600, 1812, 2106`.
- **Impact.** Navigabilité, revue et conflits de merge dégradés ; méthodes d'orchestration très
  longues (`SubmitAsync` ≈ 140 lignes) difficiles à raisonner et à tester exhaustivement.
- **Gravité : Moyenne · Probabilité : Élevée** (gêne croissante avec la taille de l'équipe).
- **Cause.** Vitesse de prototypage ; pas de découpage par service/fichier.
- **Reco.** Éclater en fichiers par service (ou par domaine : Quiz, Gamification, Social, Tutor,
  Notifications), et extraire les orchestrations longues.

### D6 — Duplication Cortex client/serveur déjà en dérive · *Architecture / Cohérence*
- **Description.** L'algorithme Cortex (FSRS/readiness) est dupliqué en Dart et C#, annoncé
  « **identique au byte près** ». Les **constantes coïncident**, mais deux calculs **divergent
  déjà** : `dueAt` (Dart `stability.ceil()` jours entiers vs C# `AddDays(stability)` fractionnaire)
  et `recency` (Dart `inDays` entier vs C# `TotalDays` fractionnaire).
- **Preuve.** `review_scheduler.dart:36` vs `ReviewScheduler.cs:73` ; `readiness_calculator.dart:72`
  vs `ReadinessCalculator.cs:48`. Le commentaire « byte‑for‑byte equivalent » est en
  `review_scheduler.dart:9`.
- **Impact.** La projection optimiste client (date de révision, readiness) diverge légèrement de
  la vérité serveur → micro‑incohérences UX. Surtout : **la promesse d'identité est fausse** et
  **aucun test cross‑langage** ne garde la parité (dérive future silencieuse).
- **Gravité : Faible (fonctionnel) → Moyenne (crédibilité/cohérence) · Probabilité : Certaine** (déjà constaté).
- **Cause.** Deux copies maintenues à la main, sans source unique ni « golden tests » partagés.
- **Reco.** Tests d'or partagés (mêmes vecteurs d'entrée → mêmes sorties dans les deux langages) ;
  aligner `dueAt`/`recency` ; documenter la stratégie de parité (ou générer une copie depuis l'autre).

### D7 — « Tuteur IA » sans IA · *Produit / Documentation*
- **Description.** Le port `ITutorCompletion` est lié à `NullTutorCompletion` qui **retourne
  `null`** ; `TutorService` se rabat alors sur une explication déterministe « ancrée sur le
  contenu ». Il n'y a **aucun LLM branché**.
- **Preuve.** `Program.cs:73`, `NullTutorCompletion.cs:12-13`. README/ETAT marketing : « 🟢 Tuteur IA ».
- **Impact.** Promesse produit surévaluée : ce qui est livré est un **explicateur déterministe
  avec garde‑fous**, pas un tuteur IA. (Côté positif : l'abstraction est propre, prête pour un
  vrai LLM en « one‑line DI change ».)
- **Gravité : Faible→Moyenne (attente vs réalité) · Probabilité : Certaine.**
- **Cause.** Choix assumé (gratuit/offline/CI) mais non reflété dans la communication.
- **Reco.** Clarifier la doc (« moteur déterministe ancré, LLM optionnel ») ; brancher Azure
  OpenAI/Foundry derrière le port quand pertinent ; flag de fonctionnalité.

### D8 — Anti‑triche : détecteurs de débit morts · *Sécurité / Intégrité*
- **Description.** L'évaluateur d'intégrité est bien conçu et testé, mais deux détecteurs
  (`XpRateExceeded`, `AttemptRateExceeded`) ne se déclenchent **jamais** car la fenêtre de débit
  (`RateWindow`) est **toujours `null`** (aucune source type Redis). De plus le système est en
  **mode détection seule** (ne sanctionne pas).
- **Preuve.** [PROBABLE, revue backend] `AttemptIntegrity.cs:223-239` + appels `window: null`
  côté `QuizService`/`ExamService`. Mode shadow confirmé par `AntiCheatWiringTests`.
- **Impact.** L'anti‑triche est plus limité que ne le laisse penser la doc : pas de cap de débit
  effectif, pas de sanction.
- **Gravité : Moyenne · Probabilité : Certaine (état actuel).**
- **Reco.** Brancher une fenêtre glissante (Redis/Cosmos) pour alimenter `RateWindow` ; planifier
  le passage en mode application après calibration.
- **✅ Résolu (ce changement + précédent).** `RateWindow` est désormais alimentée depuis le conteneur
  `attempts` (sur 1 h, sans Redis) dans `QuizService` **et `ExamService`** ; les détecteurs
  `XpRateExceeded`/`AttemptRateExceeded` se déclenchent pour les quiz **comme pour les examens**
  (tests `SubmitAsync_flags_submission_spam_via_the_rate_window`, variantes quiz + examen). Le mode
  reste « détection seule » (shadow) — le passage en mode application après calibration reste à planifier.

### D9 — Builds non reproductibles (lockfiles, canaux flottants) · *CI/CD / Supply chain*
- **Description.** `pubspec.lock` est **gitignoré** (y compris pour l'app), dépendances en `^`
  flottantes ; le job packages CI utilise `dart-lang/setup-dart` en `sdk: stable` (flottant) ;
  `.NET 8.0.x` flottant. Côté positif, Flutter est épinglé `3.24.0` pour l'app et les releases.
- **Preuve.** `.gitignore:36` (`pubspec.lock`), `ci-mobile.yml:30` (`sdk: stable`),
  `ci-backend.yml:24` (`8.0.x`), `pubspec.yaml:37` (épinglage `font_awesome_flutter 10.7.0`
  justifié par « SDK CI = 3.24 »).
- **Impact.** Une CI verte aujourd'hui peut casser demain sans changement de code ; difficulté à
  reproduire un build à l'identique.
- **Gravité : Moyenne · Probabilité : Moyenne.**
- **Reco.** Committer `pubspec.lock` (app) ; épingler le SDK Dart ; figer `.NET` au patch testé.

### D10 — Angle mort SAST : Dart/Flutter non analysé · *Sécurité / CI*
- **Description.** CodeQL ne couvre que `csharp`, `javascript-typescript`, `python`. **Le code
  mobile — la plus grande base, qui manipule jetons OIDC et secure storage — n'a aucun SAST.**
- **Preuve.** `codeql.yml:34-39` + commentaire `codeql.yml:5` (« Dart/Flutter is not supported by
  CodeQL »). `flutter analyze` est un linter, pas un SAST.
- **Impact.** Vulnérabilités mobiles non détectées automatiquement.
- **Gravité : Moyenne→Élevée · Probabilité : Moyenne.**
- **Reco.** Compléter par un linter sécurité Dart / SonarQube / scan de dépendances pub ;
  documenter explicitement la limite.

### D11 — Gating de sécurité incohérent + scans manquants · *CI/CD*
- **Description.** Scan CVE NuGet en **échec dur** (bien), mais Checkov IaC en **`--soft-fail`**
  (non bloquant), et **aucun scan CVE** des dépendances pub (Dart), npm (tooling) ou pip.
- **Preuve.** `security-scan.yml:38-41` (dur) vs `:59` (`--soft-fail`).
- **Impact.** Les mauvaises configurations IaC et les CVE Dart/Node/Python n'empêchent pas la
  fusion.
- **Gravité : Moyenne · Probabilité : Moyenne.**
- **Reco.** Passer Checkov en dur après triage ; ajouter `flutter pub outdated`/audit, `npm audit`,
  `pip check`.

### D12 — Runner CI unique self‑hosted (SPOF) + PR non fiables · *CI/CD / Exploitation*
- **Description.** **Tous** les workflows s'exécutent sur un seul runner `[self-hosted, Linux,
  X64, microlingo-ci]`. Les déclencheurs `pull_request` s'exécutent dessus.
- **Preuve.** `ci-mobile.yml:22`, `ci-backend.yml:19`, `codeql.yml:25`, `security-scan.yml:23,46`.
- **Impact.** Runner indisponible ⇒ **toute la CI bloquée** ; risque d'exécution de code de PR
  non fiable sur l'hôte (si des contributeurs externes sont ajoutés).
- **Gravité : Moyenne→Élevée · Probabilité : Moyenne.**
- **Reco.** Ajouter un runner redondant ; isoler/éphémériser les runners ; exiger une approbation
  pour exécuter les workflows de nouveaux contributeurs.

### D13 — Aucune release jamais produite ; rollback manuel · *Release engineering*
- **Description.** Pipelines de release Android/iOS décrits et soignés, mais **0 tag Git** et
  aucune trace d'exécution ; rollback entièrement manuel ; pas de SBOM ni de provenance ;
  pas d'environnement d'approbation.
- **Preuve.** `git tag` (vide) alors que `release-android.yml` se déclenche sur `v*` ;
  `docs/RELEASE_MOBILE.md` (rollback manuel) ; absence de `environment: production` dans les
  workflows de release.
- **Impact.** La chaîne de release n'a jamais été éprouvée de bout en bout ; réponse incident lente.
- **Gravité : Moyenne · Probabilité : Moyenne.**
- **Reco.** Exécuter un `dry_run` complet ; gates `environment` avec reviewers ; automatiser le
  rollback ; générer un SBOM (CycloneDX) attaché aux artefacts.

### D14 — Documentation « vivante » déjà périmée + contradictions de chiffres · *Documentation / Gouvernance*
- **Description.** `ETAT_DU_PROJET.md` se présente comme « le miroir de la réalité… c'est ce
  document qui fait foi », mais reflète le commit `527b5c5` alors que HEAD est **4 PR plus loin**
  (#47, #48, #44, #49 absents du journal). Chiffres divergents : « 6 workflows » (réellement 9),
  « 43 commits » (réellement 47), conteneurs Cosmos « 8 » (ETAT, correct) vs « 6 » (`ARCHITECTURE.md`,
  périmé) vs 10 repositories enregistrés (`Program.cs`).
- **Preuve.** `ETAT_DU_PROJET.md` en‑tête + §11 ; `git log` (47 commits) ; `.github/workflows/`
  (9 fichiers) ; `CosmosContainers.cs:6-13` (8 conteneurs) ; `ARCHITECTURE.md:133-140` (6).
- **Impact.** Un doc qui « fait foi » mais périmé induit en erreur ; mine la confiance dans
  l'onboarding.
- **Gravité : Faible→Moyenne · Probabilité : Certaine.**
- **Cause.** Mise à jour manuelle du doc « vivant », non automatisée → dérive structurelle.
- **Reco.** Générer les chiffres (tests, endpoints, workflows) en CI ; ou cesser de promettre un
  « miroir » et dater clairement ; réconcilier `ARCHITECTURE.md`.

### D15 — Offline‑first partiel : une seule leçon hors‑ligne · *Produit / UX technique*
- **Description.** L'« offline‑first » robuste concerne la **file de soumissions**. Pour le
  **contenu**, seule une leçon AZ‑900 embarquée (`sample_lesson.dart`) sert de repli ; aucune
  stratégie de pré‑téléchargement/cache du contenu réel n'est visible.
- **Preuve.** `lesson_controller.dart:50-78` (repli sur `sampleLesson` en cas d'échec réseau) ;
  `sample_lesson.dart` (leçon unique embarquée + clé). README : « lecture offline ».
- **Impact.** Hors‑ligne, l'utilisateur ne peut étudier qu'une leçon de démonstration.
- **Gravité : Faible→Moyenne · Probabilité : Certaine.**
- **Reco.** Cache de contenu (téléchargement de tracks pour étude hors‑ligne) ; clarifier la promesse.

### D16 — Observabilité d'exploitation incomplète · *Observabilité*
- **Description.** App Insights et diagnostics câblés, 3 alertes métriques (401/403/5xx). Mais
  **pas de corrélation (correlation IDs)**, **crash reporting mobile non câblé**, **rétention
  logs 30 j**, **pas d'endpoint de santé**, alertes plan de données (Cosmos 429, KV) absentes.
- **Preuve.** `ExceptionMiddleware.cs:21` (log sans trace ID) ; `bootstrap.dart:25` (TODO crash) ;
  [PROBABLE] `diagnostics.bicep` (30 j, 3 alertes).
- **Impact.** Diagnostic d'incident difficile (pas de fil conducteur de requête) ; pannes data‑plane
  silencieuses.
- **Gravité : Moyenne · Probabilité : Moyenne.**
- **Reco.** Middleware de correlation ID propagé ; crash reporting mobile → App Insights ; endpoint
  `/health` (Cosmos/Entra) ; alertes data‑plane ; rétention ≥ 90 j.

### D17 — Validateur de contenu : intégrité des réponses non vérifiée · *Contenu / Qualité*
- **Description.** Le validateur vérifie schéma, intégrité référentielle et Σ poids = 1.0, mais
  **pas** que `correct[]` référence des `options[].id` existants, ni l'unicité des IDs d'items.
- **Preuve.** `tools/validate_content.mjs` (règles présentes) ; absence de contrôle d'intégrité
  des réponses.
- **Impact.** Une coquille (`correct: [z]` sans option `z`) **passe la CI** mais casse la notation.
- **Gravité : Faible→Moyenne · Probabilité : Moyenne.**
- **Reco.** Ajouter contrôle d'intégrité des réponses, unicité des IDs, et idéalement
  distribution de difficulté / `$schema` version.

### D18 — Robustesse opérationnelle manquante (rate limiting, health, validation HTTP) · *Backend / Exploitation*
- **Description.** Pas de **rate limiting** par utilisateur/endpoint, pas d'endpoint **/health**,
  JSON malformé → **500** au lieu de **400**, pas de **versioning d'API**.
- **Preuve.** [PROBABLE, revue backend] absence dans `Program.cs` ; `HttpExtensions.cs` désérialise
  sans validation → exception → 500.
- **Impact.** Surface d'abus (pas de throttling), sondes de readiness impossibles, contrats fragiles.
- **Gravité : Moyenne · Probabilité : Moyenne.**
- **Reco.** Middleware de rate limit (429), endpoint santé, validation d'entrée → 400, préfixe `/v1/`.

---

## E. Zones d'ombre / incertitudes / éléments à confirmer

| # | Élément | Statut | À faire |
|---|---|---|---|
| E1 | **Parité exacte Cortex client/serveur** au‑delà de `dueAt`/`recency` (déjà divergents). | [CERTAIN] dérive constatée ; reste **[À VÉRIFIER]** sur les autres chemins | Golden tests cross‑langage. |
| E2 | **Comportement réel sous charge** (RU Cosmos provisionnés ? contention ? latences ?). | [INCONNU] | Tests de charge (k6/JMeter) + dimensionnement RU. |
| E3 | **Auth E2E sur un vrai tenant Entra External ID** (Microsoft/Google/Apple fédérés). | [À VÉRIFIER] — config présente, jamais validée en réel | Test E2E sur tenant réel. |
| E4 | **Instance « dev éprouvée hors‑repo »** mentionnée dans `ETAT_DU_PROJET.md:255-256`. | [INCONNU] — hors dépôt | Documenter l'état/coûts de cette instance ; confirmer qu'elle n'est pas exposée. |
| E5 | **Anti‑triche en charge réelle** (RateWindow toujours null). | [PROBABLE] détecteurs morts | Brancher la fenêtre de débit, calibrer. |
| E6 | **Repositories ExamAttempt / LearnerModel** : sur quels conteneurs ? (10 repos, 8 conteneurs). | [À VÉRIFIER] | Cartographier repo→conteneur. |
| E7 | **Deep‑linking** (le router a des routes nommées mais aucun setup de deep‑link visible). | [INCONNU] | Vérifier la configuration native iOS/Android. |
| E8 | **IP publique runner `20.86.156.64`** apparemment en dur dans l'IaC. | [À VÉRIFIER] | Confirmer paramétrage vs valeur figée. |
| E9 | **Adéquation des branches `preserved/*` et des ~20 PR Dependabot ouvertes** non fusionnées. | [CERTAIN] présence ; **[À VÉRIFIER]** intention | Décider : fusionner/fermer ; nettoyer. |
| E10 | **Couverture de tests chiffrée** (lcov collecté mais jamais agrégé/gating). | [INCONNU] valeur réelle | Publier la couverture, fixer un seuil. |

---

## F. Dette technique

| Type de dette | Niveau | Éléments concrets |
|---|:---:|---|
| **Structurelle** | 🟠 Moyenne | God‑file `Services.cs` (96 Ko/16 services) ; orchestrations longues ; duplication Cortex sans source unique ; `ARCHITECTURE.md` périmé. |
| **Code** | 🟡 Faible→Moyenne | Idempotence dupliquée 4× (Quiz/Shop/Exam/Streak) ; `context.GetUser()` appelé puis ignoré ; magic numbers (seuils intégrité) ; `LearningEvent.Payload` en `object`. |
| **Tests** | 🟠 Moyenne | 0 test HTTP/middleware ; Cosmos mocké ; pas d'E2E ; pas de tests de concurrence/charge ; pas de golden tests cross‑langage. |
| **Process** | 🟠 Moyenne→Élevée | Bus‑factor 1 ; pas de protection de branche visible ; ~20 PR Dependabot non fusionnées ; doc « vivante » périmée. |
| **CI/CD** | 🟠 Moyenne | Runner unique (SPOF) ; builds non reproductibles (lockfiles/canaux flottants) ; SAST Dart absent ; Checkov soft‑fail ; pas de SBOM ; release jamais exécutée. |
| **Documentation** | 🟡 Faible→Moyenne | Excellente sur le fond, mais chiffres divergents et promesses (« IA », « identique au byte », « offline ») en avance sur la réalité. |
| **Sécurité** | 🟠 Moyenne | Bypass dev non verrouillé ; CORS `*` ; Cosmos public ; KV sans purge protection ; pas de rate limiting ; middleware non testé ; réponses correctes dans le dépôt (mitigé par seed). |
| **Infra / Cloud** | 🟠 Moyenne→Élevée | Jamais déployée ; pas de prod/staging ; pas d'endpoints privés ; LRS sans DR ; coût fixe runner+NAT (~90 $/mois) sur projet pré‑revenu. |

**Impact sur la vitesse de delivery.** À court terme, la base est productive (modularité, lints,
tests rapides). À moyen terme, la dette de **tests aux frontières** et d'**intégrité concurrente**
freinera la mise en prod (re‑tests manuels, incidents), et le **bus‑factor 1** + la **doc périmée**
ralentiront tout onboarding ou montée en équipe.

---

## G. Matrice des risques

| ID | Risque | Catégorie | Gravité | Probabilité | Impact utilisateur | Impact business | Impact engineering | Effort remédiation | Priorité |
|---|---|---|:---:|:---:|---|---|---|:---:|:---:|
| R1 | Double‑crédit / pertes d'écritures (gemmes, XP) | Intégrité/Concurrence | Critique | Moyenne→Élevée | Soldes faux, frustration | Économie corrompue, triche | Debug difficile | Moyen | **P0** |
| R2 | Bypass auth dev en prod mal configurée | Sécurité | Critique | Faible→Moyenne | Usurpation totale | Fuite données, réputation | Faible (garde‑fou) | Faible | **P0** |
| R3 | Plan de données public (CORS *, Cosmos public, KV) | Sécurité cloud | Élevée | Moyenne | Indirect | Exposition, non‑conformité | Moyen (IaC) | Moyen | **P0** |
| R4 | Frontières HTTP/middleware/Cosmos non testées | Tests | Élevée | Élevée | Régressions invisibles | Incidents | Confiance illusoire | Moyen→Élevé | **P1** |
| R5 | Infra jamais déployée, pas de prod/staging/DR | Infra | Élevée | Élevée | Indispo possible | Bloque le lancement | Élevé | Élevé | **P1** |
| R6 | Runner CI unique (SPOF) | Exploitation | Moyenne→Élevée | Moyenne | — | Delivery bloquée | Moyen | Faible→Moyen | **P1** |
| R7 | Builds non reproductibles | CI/CD | Moyenne | Moyenne | — | Casses surprises | Moyen | Faible | **P2** |
| R8 | SAST Dart absent | Sécurité | Moyenne→Élevée | Moyenne | Indirect | Vulns mobiles | Faible | Faible | **P2** |
| R9 | Drift Cortex client/serveur | Cohérence | Faible→Moyenne | Certaine | Micro‑incohérences | Crédibilité | Faible | Faible | **P2** |
| R10 | Anti‑triche : détecteurs de débit morts | Intégrité | Moyenne | Certaine | Triche possible | Économie | Moyen | Moyen | **P2** |
| R11 | « Tuteur IA » sans IA (attente vs réalité) | Produit | Faible→Moyenne | Certaine | Attente déçue | Marketing | Faible | Faible→Élevé | **P3** |
| R12 | Bus‑factor 1 + doc périmée | Gouvernance | Moyenne | Certaine | — | Continuité | Onboarding | Moyen | **P2** |
| R13 | Observabilité incomplète (correlation, crash, health) | Observabilité | Moyenne | Moyenne | Incidents longs | Support | Moyen | Moyen | **P2** |
| R14 | Release jamais éprouvée, rollback manuel | Release | Moyenne | Moyenne | — | Réponse incident lente | Moyen | Moyen | **P2** |

---

## H. Recommandations d'amélioration

> Effort relatif : **F** = faible, **M** = moyen, **É** = élevé. QW = quick win, CS = chantier structurant.

### 1) Corrections indispensables (bloquantes avant prod)

| # | Reco | Pourquoi / risque adressé | Impact attendu | Type | Effort | Dépendances | Ordre |
|---|---|---|---|:---:|:---:|---|:---:|
| H1 | **Concurrence optimiste (ETag) + écriture tentative en premier + `TransactionalBatch`** sur l'économie | R1 — intégrité gemmes/XP | Élimine double‑crédit/pertes | CS | M | — | 1 |
| H2 | **Verrouiller `DevTokenValidator` hors développement** (throw si non‑dev) + interdire `AUTH_MODE=dev` en prod | R2 — usurpation | Ferme un bypass critique | QW | F | — | 2 |
| H3 | **Durcir le plan de données** : CORS restreint, endpoints privés Cosmos/Storage/KV, KV purge protection + soft delete 90 j, `disableLocalAuth:true` | R3 — exposition | Conformité + surface réduite | CS | M | Infra déployée | 3 |
| H4 | **Tests d'intégration HTTP + middleware + Cosmos (émulateur)** | R4 — frontières aveugles | Confiance réelle, anti‑régression auth/contrats | CS | M→É | — | 4 |
| H5 | **Déployer l'infra de façon reproductible** + params **staging/prod** | R5 — jamais déployée | Environnements reproductibles | CS | É | — | 5 |

### 2) Améliorations importantes

| # | Reco | Pourquoi | Impact | Type | Effort | Ordre |
|---|---|---|---|:---:|:---:|:---:|
| H6 | **Runner CI redondant** + isolation/éphémérisation | R6 SPOF | CI résiliente | CS | M | 6 |
| H7 | **Builds reproductibles** : committer `pubspec.lock`, épingler SDK Dart, figer `.NET` patch | R7 | Stabilité CI | QW | F | 7 |
| H8 | **Rate‑window anti‑triche** (Redis/Cosmos) + plan de passage en mode application | R10 | Anti‑triche effectif | CS | M | 8 |
| H9 | **Combler le SAST Dart** (linter sécurité / Sonar) + scans CVE pub/npm/pip + Checkov en dur | R8/R11(CI) | Couverture sécurité complète | QW→CS | F→M | 9 |
| H10 | **Protection de branche `main`** (checks requis, revue) + nettoyer les PR Dependabot | R12 | Qualité de fusion | QW | F | 10 |
| H11 | **Observabilité** : correlation IDs, crash reporting mobile, `/health`, alertes data‑plane, rétention ≥ 90 j | R13 | Diagnostic d'incident | CS | M | 11 |
| H12 | **Éprouver la release** (`dry_run` E2E), gates `environment`, rollback automatisé, SBOM | R14 | Release fiable | CS | M | 12 |

### 3) Améliorations souhaitables

| # | Reco | Pourquoi | Type | Effort |
|---|---|---|:---:|:---:|
| H13 | **Éclater `Services.cs`** par service/domaine + extraire orchestrations | D5 maintenabilité | CS | M |
| H14 | **Factoriser l'idempotence** (un seul `IIdempotencyStore`) | D-DRY | QW | F |
| H15 | **Golden tests Cortex cross‑langage** + aligner `dueAt`/`recency` | D6 dérive | QW | F |
| H16 | **Validateur contenu** : intégrité des réponses, unicité des IDs, `$schema` | D17 | QW | F |
| H17 | **Validation HTTP → 400**, versioning `/v1/`, rate limiting 429 | D18 | CS | M |
| H18 | **Réconcilier la doc** (chiffres générés en CI ; clarifier « IA », « offline », « identique ») | D7/D14/D15 | QW | F |

### 4) Opportunités d'excellence

| # | Reco | Pourquoi | Type | Effort |
|---|---|---|:---:|:---:|
| H19 | **Brancher un vrai LLM** (Azure OpenAI/Foundry) derrière `ITutorCompletion` | Tient la promesse « IA » ; le port est prêt | CS | M |
| H20 | **Cache/pré‑téléchargement de contenu** pour un vrai offline d'étude | D15 | CS | M |
| H21 | **Brancher en UI les moteurs backend** (saisons, quêtes, boutique, amis, examens) | Valorise l'avance backend | CS | É |
| H22 | **Provenance/SLSA, attestations, canary releases** (Play tracks) | Excellence release/compliance | CS | É |
| H23 | **Tests de charge + dimensionnement RU + budget/alerting coût** | Préparation au scale | CS | M |

---

## I. Améliorations pour rendre l'app meilleure

> Distinguer **« ce qu'il faut corriger »** (combler une faiblesse) de **« ce qu'il serait
> intelligent d'ajouter »** (aller au‑delà de l'état actuel).

**À corriger (robustesse / fiabilité) :**
- Intégrité concurrente de l'économie (H1), durcissement données (H3), tests aux frontières (H4),
  reproductibilité (H7), observabilité d'incident (H11) — *ce sont des dettes, pas des features.*

**À ajouter intelligemment (valeur produit / différenciation) :**
- **Qualité perçue & UX :** brancher en UI les features prêtes côté serveur (saisons, quêtes,
  boutique, amis, examens) → l'app exploiterait enfin la richesse du backend ; micro‑interactions
  Prism déjà soignées à généraliser.
- **Vrai tuteur IA** (H19) : la différenciation pédagogique promise, le port est prêt.
- **Offline d'étude réel** (H20) : télécharger un track pour réviser hors‑ligne (avion, métro) —
  cohérent avec un produit de micro‑learning mobile.
- **Fluidité / performance :** tests de charge + RU dimensionnés (H23) ; conserver l'opt‑out blur
  Prism déjà en place.
- **Maintenabilité / vitesse d'itération :** éclatement `Services.cs` (H13), golden tests Cortex
  (H15), source unique de chiffres pour la doc (H18).
- **Sécurité :** SAST Dart (H9), rate limiting (H17), anti‑triche effectif (H8).
- **Fiabilité des releases :** release éprouvée + rollback auto + SBOM (H12, H22).
- **Accessibilité :** Prism respecte déjà *reduced‑motion* ; étendre l'audit a11y (contrastes,
  tailles de police, lecteurs d'écran) serait un plus différenciant.

---

## J. Priorisation

### Top 10 des problèmes les plus critiques
1. **D1/R1** — Économie sans atomicité/ETag (double‑crédit, pertes).
2. **D2/R2** — Bypass auth dev non verrouillé par environnement.
3. **D3/R3** — Plan de données public (CORS *, Cosmos public, KV sans purge protection).
4. **D4/R4** — Frontières HTTP/middleware/Cosmos non testées.
5. **D5** — God‑file `Services.cs` (maintenabilité).
6. **D8/R10** — Anti‑triche : détecteurs de débit morts + mode détection seul.
7. **D12/R6** — Runner CI unique (SPOF).
8. **D16/R13** — Observabilité incomplète (correlation, crash, health).
9. **D6/R9** — Drift Cortex client/serveur (promesse fausse, pas de golden test).
10. **D14/R12** — Doc « vivante » périmée + bus‑factor 1.

### Top 10 des quick wins (effort faible, valeur immédiate)
1. **H2** — Verrouiller `DevTokenValidator` hors dev.
2. **H7** — Committer `pubspec.lock` + épingler SDK Dart.
3. **H10** — Protection de branche `main` + tri des PR Dependabot.
4. **H14** — Factoriser l'idempotence en un seul store.
5. **H15** — Golden tests Cortex + alignement `dueAt`/`recency`.
6. **H16** — Intégrité des réponses dans le validateur de contenu.
7. **H18** — Chiffres de doc générés en CI ; clarifier « IA »/« offline »/« identique ».
8. **H9 (partie)** — Ajouter `pub outdated`/`npm audit`/`pip check` + Checkov en dur.
9. Ajouter `retention-days` aux artefacts de release + validation des inputs de version.
10. Endpoint `/health` minimal (sonde Cosmos/Entra).

### Top 10 des actions à plus forte valeur
1. **H1** — Concurrence optimiste + transaction sur l'économie.
2. **H5** — Déployer l'infra reproductible (staging/prod).
3. **H4** — Tests d'intégration HTTP/middleware/Cosmos.
4. **H3** — Durcir le plan de données (privé, CORS, KV).
5. **H11** — Observabilité d'exploitation.
6. **H21** — Brancher en UI les moteurs backend déjà prêts.
7. **H19** — Vrai LLM derrière le port tuteur.
8. **H8** — Anti‑triche effectif (rate‑window).
9. **H12** — Release éprouvée + rollback auto + SBOM.
10. **H6** — Runner CI redondant.

### Immédiat / Peut attendre / À ne SURTOUT pas faire avant prérequis
- **À faire immédiatement :** H2, H7, H10 (quick wins de sécurité/reproductibilité/gouvernance) ;
  démarrer H1 (intégrité) et H4 (tests frontières).
- **Peut attendre :** H13 (refactor `Services.cs`), H19/H20/H21 (features), H22 (SLSA/canary).
- **À NE PAS faire tant que les prérequis ne sont pas en place :**
  - Ne **pas** déployer en prod ni faire de release publique **avant** H1 (intégrité), H2 (auth),
    H3 (données privées) et H4 (tests frontières).
  - Ne **pas** passer l'anti‑triche en mode *sanction* (H8) **avant** calibration et tests réels.
  - Ne **pas** brancher un LLM (H19) **avant** d'avoir des garde‑fous de coût/observabilité (H11).
  - Ne **pas** ouvrir le dépôt à des contributeurs externes **avant** runners isolés + protection
    de branche (H6/H10).

---

## K. Roadmap recommandée

> Exprimée selon les axes **Stabiliser → Sécuriser → Simplifier → Industrialiser → Optimiser → Faire évoluer.**

### Immédiat (0–1 semaine) — *Stabiliser & Sécuriser (quick wins)*
- H2 (verrou auth dev), H7 (lockfile/SDK), H10 (branch protection + Dependabot), H14 (idempotence),
  H15 (golden Cortex), H16 (validateur réponses), H18 (doc), `/health` minimal, Checkov en dur.

### Court terme (2–4 semaines) — *Stabiliser & Sécuriser (structurant)*
- **H1** — Concurrence optimiste + transaction sur l'économie (priorité absolue).
- **H4** — Tests d'intégration HTTP/middleware/Cosmos.
- **H3** — Durcir le plan de données (privé, CORS, KV).
- **H8** — Rate‑window anti‑triche. **H9** — SAST Dart + scans CVE complets.

### Moyen terme (1–2 mois) — *Industrialiser & Optimiser*
- **H5** — Déployer infra reproductible staging/prod + DR. **H6** — Runner redondant.
- **H11** — Observabilité (correlation, crash, alertes). **H12** — Release éprouvée + rollback + SBOM.
- **H13** — Éclater `Services.cs`. **H17** — Validation HTTP/versioning/rate limit.
- **H23** — Tests de charge + RU + budget/alerting coût.

### Long terme (2–3 mois) — *Faire évoluer*
- **H19** — Vrai LLM tuteur. **H20** — Offline d'étude (cache contenu).
- **H21** — Brancher en UI les moteurs backend. **H22** — Provenance/SLSA + canary.
- Audit a11y complet ; +certifications / +tracks.

---

## L. Scorecard finale

> Note argumentée /10. La moyenne reflète un **prototype de grande qualité d'ingénierie mais
> pré‑production**, pénalisé par l'intégrité concurrente, le durcissement cloud, les trous de
> tests aux frontières et l'absence de déploiement.

| Dimension | Note | Justification (preuves) |
|---|:---:|---|
| **Architecture** | **7/10** | Clean Architecture respectée (`Program.cs`, dépendances `Domain`‑pur) ; feature‑first mobile propre. **−** god‑file `Services.cs`, duplication client/serveur en dérive, pas de versioning d'API. |
| **Qualité du code** | **7/10** | Lints stricts (`analysis_options.yaml`), `-warnaserror`, 0 TODO backend, nommage cohérent. **−** 96 Ko/16 services dans un fichier, idempotence dupliquée 4×, orchestrations longues. |
| **Sécurité** | **6/10** | MI + RBAC, server‑authoritative, secure storage, 0 secret committé, erreurs non divulgantes. **−** bypass dev non verrouillé, CORS *, Cosmos public, KV sans purge protection, pas de rate limiting, middleware non testé. |
| **Tests** | **6/10** | ~433 tests déterministes, logique pure bien couverte. **−** 0 test HTTP/middleware, Cosmos mocké, pas d'E2E ni de tests de concurrence/charge ; couverture jamais agrégée/gating. |
| **CI/CD** | **6/10** | 4 pipelines ciblés + CodeQL + security‑scan + signature mobile + Dependabot ; gates bloquantes. **−** runner unique (SPOF), SAST Dart absent, Checkov soft‑fail, builds non reproductibles, release jamais exécutée, pas de SBOM. |
| **Observabilité** | **5/10** | App Insights + diagnostics + 3 alertes. **−** pas de correlation IDs, crash mobile non câblé, rétention 30 j, pas de `/health`, détecteurs de débit morts. |
| **Documentation** | **7/10** | README/ARCHITECTURE/ETAT/RELEASE riches, mermaid, ADR, onboarding clair. **−** doc « vivante » périmée (−4 PR), chiffres contradictoires, promesses (« IA », « identique », « offline ») en avance. |
| **Performance** | **6/10** | Serverless, lectures Cosmos mono‑partition, moteur offline efficace, opt‑out blur Prism. **−** aucun test de charge, RU non vérifiés, contention concurrente, Storage LRS. |
| **Maintenabilité** | **6/10** | Paquets modulaires, `Result/Failure` typés, dette de marqueurs faible. **−** god‑file, double‑langage non gardé par tests, bus‑factor 1. |
| **Préparation au scale** | **4/10** | Architecture *prête à grandir*. **−** infra jamais déployée, pas de prod/staging, pas d'endpoints privés ni DR, bugs de concurrence, runner unique, pas de rate limiting, auteur unique. |
| **Robustesse produit** | **6/10** | Offline (soumissions) robuste, gamification riche, anti‑triche bien conçu. **−** offline contenu = 1 leçon, features backend non branchées en UI, anti‑triche détection seule + détecteurs morts, « IA » non câblée. |
| **Gouvernance technique globale** | **5/10** | Conventions, Dependabot, SECURITY.md, contenu‑as‑code. **−** bus‑factor 1, doc dérivée, ~20 PR Dependabot non fusionnées, pas de protection de branche, pas d'environnements, 0 release. |
| **Moyenne pondérée** | **≈ 5,9/10** | **Prototype avancé, propre et ambitieux — non prêt pour la production sans durcissement ciblé.** |

---

## Conclusion franche

**1. Quel est l'état réel du projet aujourd'hui ?**
Un **squelette de MVP exceptionnellement large et bien architecturé**, produit en 5 jours par un
**unique auteur** (47 commits). Le **backend est riche** (logique pure testée, ~28 endpoints,
Clean Architecture), le **mobile est solide mais en retard** sur le backend, l'**infra est décrite
mais jamais déployée**, et plusieurs **promesses dépassent la réalité** (« Tuteur IA » sans LLM,
Cortex « identique » qui dérive déjà, « offline » limité à une leçon). Maturité : **prototype
avancé, pré‑production.**

**2. Quels sont les problèmes les plus graves ?**
(a) **Intégrité concurrente de l'économie** (double‑crédit/pertes : pas d'ETag ni de transaction) ;
(b) **bypass d'auth dev** non verrouillé par environnement ; (c) **plan de données public** +
durcissement cloud incomplet ; (d) **frontières critiques non testées** (HTTP, middleware, Cosmos) ;
(e) **bus‑factor 1** et **doc « qui fait foi » déjà périmée**.

**3. Quelles sont les zones d'ombre ?**
Parité exacte Cortex au‑delà des deux dérives constatées ; comportement réel **sous charge** (RU,
contention) ; **auth E2E** sur un vrai tenant Entra ; état/coût de l'**instance dev hors‑repo** ;
anti‑triche en charge (RateWindow null) ; cartographie repo→conteneur ; couverture chiffrée réelle.

**4. Quelles sont les améliorations prioritaires ?**
Concurrence optimiste + transaction sur l'économie ; verrouiller `DevTokenValidator` hors dev ;
durcir le plan de données (privé, CORS, KV) ; tests d'intégration aux frontières ; déployer une
infra reproductible avec staging/prod ; brancher la fenêtre de débit anti‑triche ; combler le
SAST Dart.

**5. Quelles améliorations additionnelles rendraient l'app nettement meilleure ?**
Brancher un **vrai LLM** derrière le port tuteur ; **offline d'étude** (cache contenu) ; **brancher
en UI** les moteurs backend déjà prêts (saisons/quêtes/boutique/amis/examens) ; observabilité
d'exploitation (correlation IDs, crash reporting, health, alertes) ; golden tests Cortex ;
SBOM/provenance et canary releases ; audit a11y.

**6. Le projet est‑il prêt pour une croissance sérieuse / une industrialisation / une montée en
charge ?**
**Non, pas encore.** L'architecture est *prête à grandir*, mais il faut **4 à 6 semaines de
durcissement** (intégrité concurrente, sécurité du plan de données et du bypass dev, déploiement
prod/staging reproductible, tests d'intégration, runner redondant, rate limiting, observabilité)
avant d'envisager une mise à l'échelle ou une ouverture publique.

**7. Si j'étais responsable technique, quel serait mon plan ?**
- **Stabiliser :** transaction + ETag sur l'économie ; tests d'intégration HTTP/middleware/Cosmos ;
  golden tests Cortex.
- **Sécuriser :** verrou auth dev ; plan de données privé + CORS + KV purge protection ; rate
  limiting ; SAST Dart.
- **Simplifier :** éclater `Services.cs` ; factoriser l'idempotence ; source unique pour Cortex et
  pour les chiffres de doc.
- **Industrialiser :** déployer infra reproductible (staging/prod, DR) ; runner redondant ;
  protection de branche ; release éprouvée + rollback auto + SBOM.
- **Optimiser :** tests de charge + RU + budget/alerting coût ; observabilité complète.
- **Faire évoluer :** vrai LLM tuteur ; offline d'étude ; brancher en UI les moteurs prêts ;
  +certifications.

> **Verdict global : base d'ingénierie remarquable pour son âge, mais pré‑production.
> Conditional GO bêta interne ; durcissement ciblé requis avant toute industrialisation.**

---

---

## M. Remédiation appliquée (corrections implémentées)

> Corrections réalisées **dans ce même changement**, validées par build/tests/lint
> exécutés localement (backend .NET 8 SDK installé, Dart 3.12, Node 20, `az bicep`).
> État de validation : ✅ exécuté & vert · 🧪 testé spécifiquement · ⚠️ opérationnel (hors-repo).

| Finding | Correction | Preuve / fichiers | Validation |
|---|---|---|---|
| **D1** Économie sans atomicité/ETag | Concurrence optimiste ETag sur le profil (`OptimisticConcurrency` + retry) ; idempotence **atomique** par id déterministe (`attempt::`, `purchase::`, `examattempt::`) ; ordre create-first (échec sûr = pas de double crédit) | `QuizService.SubmitAsync`, `CosmosUserRepository`, `CosmosAttemptRepository`, `Dtos.cs` (ETag), `OptimisticConcurrency.cs` | 🧪 `SubmitAsync_recovers_the_reward_when_the_profile_write_conflicts_once` + 322 tests ✅ |
| **D2** Bypass auth dev | Garde de production (`AuthValidatorSelection.ShouldUseDevValidator` lève en prod) câblée dans `Program.cs` | `AuthValidatorSelection.cs`, `Program.cs` | 🧪 `AuthValidatorSelectionTests` (dev-en-prod rejeté) ✅ |
| **D3** Plan de données / hardening cloud | Hardening par env : Cosmos RBAC-only, KV purge protection + 90 j, Storage GRS+versioning+soft delete, CORS verrouillé ; **params staging/prod** | `infra/modules/{cosmos,keyvault,storage,functionApp}.bicep`, `main.bicep`, `params/{staging,prod}.bicepparam` | ✅ `az bicep build` + `build-params` verts |
| **D6** Drift Cortex « identique » | Planification jours fractionnaires alignée client↔serveur ; **golden tests partagés** ; commentaire corrigé | `review_scheduler.dart`, `readiness_calculator.dart`, `cortex_golden_test.dart`, `CortexParityTests.cs` | 🧪 golden vectors Dart+C# ✅ |
| **D14/D6** Doc périmée / claims | `ARCHITECTURE.md` : 8 conteneurs (au lieu de 6), parité Cortex + section « Durcissement », ETAT rafraîchi | `docs/ARCHITECTURE.md`, `docs/ETAT_DU_PROJET.md` | ✅ |
| **D16** Observabilité | **Correlation id** (`x-correlation-id`) propagé/journalisé/retourné ; endpoint **`GET /health`** (sonde Cosmos, anonyme) | `ExceptionMiddleware.cs`, `HealthFunctions.cs`, `JwtAuthMiddleware.cs` | ✅ build + 323 tests |
| **D17** Validateur contenu | Intégrité des réponses (`correct` ⊆ options), unicité ids d'items, cohérence `ordering`/`mcq` | `tools/validate_content.mjs` | 🧪 prouvé sur cas cassé + contenu réel ✅ |
| **D18** Robustesse HTTP | JSON malformé → **400** (`BadRequestException`), conflit → **409** | `HttpExtensions.cs`, `ExceptionMiddleware.cs` | ✅ build |
| **D8** Anti-triche détecteurs morts | Fenêtre de débit **réelle** (XP/tentatives sur 1 h, depuis le conteneur `attempts`, sans Redis) câblée dans `QuizService` **et `ExamService`** → les détecteurs `XpRateExceeded`/`AttemptRateExceeded` s'activent pour les quiz **comme pour les examens** | `CoreAbstractions.cs` (`RecentActivity`), `CosmosRepositories.cs`, `QuizService`, `ExamService` | 🧪 `SubmitAsync_flags_submission_spam_via_the_rate_window` (quiz **+ examen**) |
| **D5** God-file `Services.cs` (96 Ko) | **Éclaté** en 11 fichiers par domaine (Quiz, Gamification, Social, Learning, Exam, Tutor, Notification, Leaderboard, User, Content, Misc) via **Roslyn** (réorganisation pure, formatage préservé) | `backend/src/Microlingo.Application/Services/*.cs` | ✅ build + **324 tests** (comportement identique) |
| **D9** Builds reproductibles | SDK Dart épinglé (`3.5.0`), lockfile applicatif suivi (`.gitignore`) | `ci-mobile.yml`, `.gitignore` | ✅ YAML valide |
| **D13** Release / SBOM | **SBOM** CycloneDX (backend), **gate d'approbation** `environment: beta` sur releases mobiles | `ci-backend.yml`, `release-android.yml`, `release-ios.yml` | ✅ YAML valide |

**Suite de tests après remédiation :** backend **325** (Domain 224 + Application 101, dont
les nouveaux tests de concurrence/auth/parité/anti-triche), Dart `cortex` **10** (dont 2 golden),
validateur de contenu vert, `az bicep build` vert sur toute l'infra. `Services.cs` (96 Ko) **éclaté en 11 fichiers** par domaine (build + tests inchangés).

### Restant (volontairement non fait ici — risque/coût vs valeur)
- ~~**D8** Fenêtre de débit anti-triche **côté examens**~~ — ✅ **fait** : `ExamService` injecte
  désormais `IAttemptRepository`, capture la fenêtre de débit **avant** la persistance et la passe à
  `AttemptIntegrityEvaluator.Evaluate(...)`, exactement comme `QuizService` ; couvert par
  `SubmitAsync_flags_submission_spam_via_the_rate_window` (variante examen). Anti-triche quiz **et**
  examen désormais alignés (mode détection/shadow inchangé).
- **D4/D5 (tests)** Tests d'intégration Cosmos : le projet `Microlingo.Infrastructure.Tests`
  est **désormais en place** (6 cas couvrant idempotence/ETag/fenêtre de débit sur un vrai
  conteneur), **gated** par `MICROLINGO_COSMOS_TESTS=1` ; il **compile** et **se skippe
  proprement** hors émulateur. Le **runtime** (émulateur Cosmos) **n'a pas été exécuté ici**.
  Restent à écrire les tests HTTP/middleware de bout en bout (Functions SDK).
- **Mobile (Phase 2)** Écrans de gamification **livrés** : saisons · quêtes · succès · boutique ·
  amis · examens blancs (couche data + providers Riverpod + router/onglets) → 6 écrans + 6 tests
  widget ; suite Dart **185** verte, `flutter analyze` propre. Reste la **validation E2E sur
  appareil** (backend live + auth Entra) et l'écran **partage quotidien** (moteur prêt, UI absente).
- **Opérationnel** : déploiement réel de l'infra, protection de branche, fusion des PR Dependabot,
  endpoints privés (réseau), runner CI redondant — actions hors-dépôt.

---

<sub>Audit grounded sur le commit `9c488c6`. Toute conclusion est reliée à un élément observable
(`fichier:ligne`). Les éléments marqués [PROBABLE]/[À VÉRIFIER]/[INCONNU] nécessitent une
confirmation humaine ou une exécution réelle (charge, déploiement, tenant Entra).</sub>
