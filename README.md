<div align="center">

# Certigo

**Apprenez, révisez et validez vos certifications cloud & IA — par micro-leçons premium.**

Expérience **CertiGo Natif Apple (iOS 18+ / SwiftUI / Prism)** et socle multi-plateforme pour maîtriser
des **concepts techniques, d'architecture cloud et d'IA réels** et atteindre la *readiness* certification
(échelle officielle `/1000` Pearson VUE & Readiness Score `0–100`) sur un catalogue multi-cloud en
expansion continue (**Microsoft Azure, AWS, Google Cloud, GitHub, Cisco, Kubernetes/CNCF, HashiCorp &
Grands Acteurs de l'IA** : Anthropic Claude, OpenAI ChatGPT, Google Gemini, Microsoft Copilot).

`SwiftUI (iOS 18+)` · `Prism Design System` · `Flutter` · `.NET 8 isolated Functions` · `Cosmos DB` · `Entra External ID` · `Bicep`

</div>

> [!IMPORTANT]
> **Certigo n'est pas une app de langues.** On n'apprend pas du vocabulaire :
> on enseigne des **concepts professionnels d'architecture et d'ingénierie** via une boucle pédagogique
> stricte — *concept → exemple appliqué → vérification de compréhension (10 formats interactifs) →
> révision adaptative FSRS & calibration de confiance (Brier)*.
> Toute la modélisation (contenu, quiz, simulation Pearson VUE, progression, gamification bienveillante)
> sert l'apprentissage réel et la réussite à l'examen, jamais la mémorisation creuse.

---

## ✨ Le produit en une phrase

L'utilisateur choisit ses **certifications cibles en parallèle** et ses **cours de veille IA** ;
CertiGo construit un **parcours personnalisé** d'îlots 3D et de micro-leçons (20 s), valide la
compréhension par **10 formats d'exercices techniques** accompagnés d'un **Hub IA multimodal (écrit +
vocal live Nova)**, entraîne sur des **examens blancs chronométrés Pearson VUE (`/1000`)**, révise les
concepts faibles au bon moment (**FSRS**) et matérialise la progression par un **Readiness Score** —
porté par la mascotte officielle **`Blason 1A`** et une gamification **zéro culpabilité (sans cœurs ni
vies)**.

### Décisions verrouillées

| Pilier | Décision |
|---|---|
| Métrique nord | **Readiness Score** (`0–100`) & **Baromètre Pearson VUE** (`/1000`, seuil officiel `700/1000`) |
| Moteur pédagogique | **Cortex** — *mastery-based* + **FSRS** (répétition espacée) + calibration de Brier, partagé entre **Swift (`CertigoCortex`)**, **Dart (`packages/cortex`)** et **.NET (`Certigo.Domain`)** |
| Application Native Apple | **CertiGo Natif Apple (`apps/apple/`)** — **iOS 18+ / SwiftUI / Prism**, fidélité 1-pour-1 avec le Fichier Maître Figma Pro (`13 Pages · 53 Écrans/Surfaces · 123 Hotspots Spring`) |
| Design system | **Prism** — clarté constante OKLCH, coussins tactiles 3D, feuilles flottantes style Apple Pay, matériaux système iOS 18+ et respect strict de `Reduce Motion` / `Dynamic Type` (`AX5`) |
| Gamification | **Momentum Zéro Culpabilité** — XP, séries bienveillantes, podium 3D hebdomadaire, vrais blasons officiels. **Aucun système punitif de cœurs / vies** |
| Contenu | **Content-as-code** — [`certigo-content`](https://github.com/gchambaud_microsoft/certigo-content) est la source éditoriale active ; schémas, validation et manifestes public/privé y sont versionnés |

---

## 🎨 CertiGo Natif Apple (iOS 18+ / SwiftUI / Prism) & Fichier Maître Figma Pro

L'application native Apple (`apps/apple/CertigoNative` & package Swift modulaire `apps/apple/CertigoKit`)
implémente avec une fidélité géométrique et fonctionnelle 1-pour-1 le **Fichier Maître Figma Pro**
(`13 Pages · 53 Écrans/Surfaces · 123 Hotspots Spring`, vérifiés par `CertiGoMasterScreenCatalog` et
`PrismSnapshotHarness`).

### Chapitre 1 — Onboarding Complet (11 Écrans `OB-01` à `OB-08B` · `Page 07`)

- **Ouverture Arche 4 Marques & Mascotte (`OB-01`, `OB-02`)** : Arche de **4 coussins 3D** (**Google**, **Microsoft**, **vrai logo officiel AWS**, **GitHub**) entourant la mascotte officielle **`Blason 1A`**, suivie de la présentation des objectifs de certifications cloud et de veille sur les grands acteurs de l'IA.
- **Sélection Multi-Certifications en Parallèle (`OB-03A`)** : Sélection simultanée de plusieurs parcours de certification (`AZ-104`, `AI-102`, `SAA-C03`, `ACE`, `GH-300`, etc.) persistée en temps réel via `CertigoParallelTracksPreferenceStore` et synchronisée avec le Popover d'accueil.
- **Veille Grands Acteurs de l'IA & Catalogue en Expansion Continue (`OB-03B`)** : Abonnement aux pistes de veille technologique (**Anthropic Claude**, **OpenAI ChatGPT**, **Google Gemini**, **Microsoft Copilot / Foundry**) et aux nouveaux parcours ajoutés en continu.
- **Calibrage, Rythme & Double Courbe de Progression (`OB-04`, `OB-06A`, `OB-07`)** : Calibrage du niveau initial et de l'échéance d'examen, choix du rythme quotidien (`19:30`), et graphique comparatif à **double courbe** (**`Avec CertiGo 845/1000`** vs **`Sans CertiGo 580/1000`** sur `OB-07`).
- **Création de Profil 1-Tap & 3 Pop-ups Système Natifs iOS (`OB-06B`, `OB-06C`, `OB-08A`, `OB-08B`)** : Création de profil 1-Tap épurée sans bandeau supérieur superflu (`OB-08A`) et intégration des **3 Pop-ups Système Natifs iOS** :
  1. **`OB-06B`** : Autorisation système des **Notifications Push** iOS ;
  2. **`OB-06C`** : Ajout du **Widget Écran d'Accueil iOS 18** ;
  3. **`OB-08B`** : Feuille système native **Connexion avec Apple / Face ID**.

### Chapitre 2 — Accueil Waymo, Rail Mimo, Popover Marques & Fiche Mémo (`Écrans 01, 02, 03, 14` · `Page 01`)

- **Accueil Îlots 3D Waymo & Rail Mimo (`Écran 01`)** : Chemin sinueux d'îlots tactiles 3D guidé par **1 seule mascotte en vue 3/4 gauche (`.angle34LeftPath`)** pointant directement vers l'étape active (`Rôles RBAC & PIM`), surmonté du rail horizontal Mimo multi-parcours.
- **Popover Flottant des Marques (`Écran 02`)** : Sélecteur rapide de certifications et de fournisseurs affichant le **vrai logo officiel AWS**, Microsoft Azure, Google Cloud, GitHub et les pistes IA actives.
- **Feuille d'Aperçu d'Étape à 3 Actions (`Écran 03`)** : Carte contextuelle proposant les **3 boutons d'action immédiate** **`[ 📖 Mémo | COMMENCER | ✦ IA ]`**.
- **Fiche Mémo Dépliée Style Apple Pay (`Écran 14`)** : Synthèse structurée d'architecture (tableaux comparatifs, limites de service, commandes clés et pièges d'examen) présentée dans une feuille dépliée style Apple Pay avec la mascotte `.poseReaderMemo`.

### Chapitre 3 — Moteur d'Exercices, Bulles Mascottes 3/4 (`15pt Bold ◀`) & les 10 Formats (`Q_TYPE_01` à `Q_TYPE_10`, `Écrans 04, 05, 15..20` · `Pages 01 & 06`)

- **Disposition Empilée Duolingo & Spécialiste 3/4 Droite (`Écran 04`)** : Chaque exercice affiche la **mascotte spécialiste du domaine en posture 3/4 droite** accompagnée d'une **bulle de question empilée (`15pt Bold` avec flèche latérale `◀`)**.
- **Les 10 Formats Interactifs de Questions (`Q_TYPE_01` à `Q_TYPE_10` · `Page 06`)** :
  1. **`Q_TYPE_01`** : QCM Scénario d'Architecture Classique & Pilule Bleu Ciel ;
  2. **`Q_TYPE_02` / `Écran 16`** : Sélection visuelle de symboles de services officiels en **Grille 2×2** ;
  3. **`Q_TYPE_03`** : Schéma d'architecture interactif à compléter (`[ ? ]`) ;
  4. **`Q_TYPE_04`** : Saisie directe au clavier iOS (paramètre, zone DNS privée, commande) ;
  5. **`Q_TYPE_05` / `Écran 17`** : Assemblage de briques CLI / PowerShell / Bicep (*Word Bank* interactif) ;
  6. **`Q_TYPE_06`** : Paires à relier (Symboles officiels ↔ Rôles exacts) ;
  7. **`Q_TYPE_07`** : Diagnostic d'anomalie dans une règle `JSON` / `YAML` / `Bicep` ;
  8. **`Q_TYPE_08`** : Classement dans l'ordre hiérarchique de portée (`1 ➔ 4`) ;
  9. **`Q_TYPE_09`** : Verdict rapide d'architecture (*Autorisé* vs *Bloqué*) ;
  10. **`Q_TYPE_10`** : Multi-sélection normée à cases à cocher (*Exactement 2 réponses*).
- **Boucle de Feedback & Micro-Leçons (`Écrans 05, 15, 18, 19, 20`)** : Feuille flottante d'**explication d'erreur IA (`05`)** sur arrière-plan assombri à **`62 %`**, carte **Déclic visuelle 20 s (`15`)**, validation réussie avec bouton **`[✦ EXPLIQUER MA RÉPONSE]` (`18`)**, **comparateur technique côte-à-côte sans mascotte (`20`)** et **célébration finale de fin d'étape (`19`)** avec `Blason 1A` de face.

### Chapitre 4 — Hub IA Complet 4 Écrans (`06A` à `06D`) & Routeur Souverain (`Page 01`)

- **`06A` · Accueil du Hub IA Style Gemini** : Suggestions contextuelles liées à l'étape active, raccourcis de révision et entrée directe écrite ou vocale.
- **`06B` · Réponse Écrite Structurée** : Explication pédagogique structurée avec **schéma d'architecture ASCII/vectoriel** et encadré **Astuce Examen**.
- **`06C` · Conversation Vocale Live `Nova 1,0×`** : Mode vocal temps réel avec indicateur d'onde central animé, contrôle de cadence (`Nova 1,0×`) et **continuité audio en arrière-plan (écran verrouillé / Dynamic Island)**.
- **`06D` · Tiroir d'Historique Push `85 %` Style Claude** : Tiroir latéral poussant la scène principale à `85 %` pour retrouver et reprendre instantanément toutes les sessions d'étude IA.
- **Gouvernance & Sécurité IA (`AIRouter` & `AISecretRedactor`)** : Routeur IA déterministe à **5 niveaux** (*Indice léger → Explication ciblée → Comparaison d'architecture → Diagnostic d'erreur → Simulation orale*) couplé à l'expurgation locale systématique des secrets, clés, jetons et identifiants (`AISecretRedactor`) avant tout appel réseau.

### Chapitre 5 — Onglet Examens & Simulation Officielle Pearson VUE (`Écrans 21, 22, 23, 24` · `Pages 01 & 09`)

- **`Écran 21` · Onglet Examens (Variante C Centrée)** : Vue d'ensemble centrée présentant la jauge de préparation et les **5 domaines officiels pondérés** de la certification cible.
- **`Écran 22` · Feuille Flottante Apple Pay de Lancement** : Feuille modale superposée à l'écran `21` assombri, affichant le **vrai blason officiel `Microsoft Certified Associate (AZ-104)`**, le format officiel (`50 items · 90 min · Seuil 700/1000`) et la confirmation en 1 Tap.
- **`Écran 23` · Cockpit d'Examen Chronométré Pearson VUE** : Interface d'examen blanc sans distraction avec compte à rebours, **navigateur d'items (`12 ✓ · 13 🏳 · [14/50]`)** et **marquage de questions pour révision (`🏳`)**.
- **`Écran 24` · Rapport de Score `/1000` & Carrousel Baromètre Pearson VUE (`● ○ ○`)** : Score officiel sur `1000` par rapport au seuil `700/1000`, accompagné du **Carrousel Baromètre Pearson VUE à 3 cartes (`● ○ ○`)** détaillant le score global, la répartition par domaine pondéré et les cibles de remédiation prioritaires.

### Chapitre 6 — Social, Onglet Moi, Statistiques Pro en 2 Volets, `CertiGo PRO` & Paramètres (`Écrans 07A, 08, 08B-1, 08B-2, 25..28`)

- **Social & Amis (`Écrans 07A & 25`)** : **Podium 3D de la semaine (`2e · 1er · 3e`)** avec zone de promotion Top 5 (`07A`), vue **Mes Amis (`25`)**, ajout par code/QR et encouragement **`👏 Saluer` en 1 Tap**.
- **Onglet Moi & Vrais Blasons Officiels (`Écrans 08 & 26`)** : Profil avec édition photo, vitrine des **vrais blasons de certification officiels** et vue détaillée de certificat professionnel vérifiable (`26`).
- **Dashboard Statistiques Pro en 2 Volets (`08B-1` & `08B-2`)** :
  - **Volet Haut (`08B-1`)** : Indice de préparation global (`84 %`), **Radar à 5 axes** par domaine de compétence et **Heatmap d'assiduité sur 56 jours** ;
  - **Volet Bas (`08B-2`)** : **3 Anneaux d'activité style Apple Fitness+**, courbe d'évolution `/1000` et analyse **Forces / Cibles**.
- **Offre `CertiGo PRO` (`Écran 27` · Variante `27-A`)** : Tableau comparatif clair **Gratuit vs PRO** (sessions illimitées, examens blancs Pearson VUE complets, Hub IA vocal `Nova` et packs hors-ligne).
- **Paramètres Complets Style ChatGPT iOS 2026 (`Écran 28`)** : Minimalisme chirurgical regroupant objectifs actifs, voix IA, rappels, accessibilité, stockage hors-ligne et confidentialité.

### Chapitre 7 — Bibliothèque Officielle des 24 Poses de la Mascotte `Blason 1A` (`Page 08` · `CertiGoMascotPose`)

| Planche Figma (`Page 08`) | Poses officielles (`24` assets vectoriels haute définition) |
|---|---|
| **1. Angles de Vue (`6`)** | `.angle34RightQuiz` (3/4 droite quiz) · `.angle34LeftPath` (3/4 gauche parcours) · `.angleFrontCelebration` (face célébration) · `.angleSprintRight` (course) · `.angleLookupPodium` (regard podium) · `.angleThinking34` (réflexion 3/4) |
| **2. Postures & Gestes (`6`)** | `.posePresenter` (présentateur) · `.poseVictoryJump` (saut de victoire) · `.poseCrossedArms` (bras croisés) · `.poseReaderMemo` (lecteur fiche mémo) · `.poseCLICoder` (ingénieur lab CLI) · `.poseAnalyst` (analyste pensif) |
| **3. Expressions Émotionnelles (`6`)** | `.emotionStarryEyes` (étoiles dans les yeux) · `.emotionOnFire` (série en feu) · `.emotionAhaIdea` (déclic Aha !) · `.emotionOopsCaring` (bienveillant / oups) · `.emotionBossCrown` (boss certifié 810+) · `.emotionDetermined` (ultra-déterminé) |
| **4. Spécialistes de Domaine 3/4 Droite (`6`)** | `.specialistCloudAzure` (Cloud Azure) · `.specialistSecurityEntra` (Sécurité Entra) · `.specialistNetworkVNet` (Réseau VNet) · `.specialistCLIContainers` (CLI & Conteneurs) · `.specialistDataSQL` (Data & SQL) · `.specialistAICoach` (Coach IA) |

### Chapitre 8 — Catalogue Officiel des 900 Assets (`Page 10` & `Prism.xcassets` · `CertiGoOfficialAssetCatalog`)

| Famille d'assets (`Prism.xcassets` / `BrandAssets.xcassets`) | Volume | Contenu & Couverture |
|---|---:|---|
| **Badges de Certifications Officiels** | **52** | Blasons officiels **Microsoft Learn** (Fundamentals, Associate, Expert, Specialty) & **Credly** (AWS, Google Cloud, GitHub, Cisco CCNA, CNCF CKA/CKAD/CKS, HashiCorp Terraform/Vault, Anthropic CCA-F) |
| **Services Microsoft Azure (SVG)** | **291** | Icônes d'architecture officielles Azure, Entra ID, Microsoft Fabric, Foundry & Security |
| **Services AWS (SVG)** | **293** | Icônes d'architecture officielles Amazon Web Services (Compute, IAM, VPC, S3, Bedrock, EKS…) |
| **Services Google Cloud (SVG)** | **214** | Icônes d'architecture officielles GCP (GKE, BigQuery, Vertex AI, Cloud Run, IAM…) |
| **Logos de Marques & Grands Acteurs de l'IA** | **32** | Vrai logo officiel AWS, Microsoft, Azure, Google Cloud, GitHub, Copilot, OpenAI/ChatGPT, Anthropic/Claude, Gemini, Meta AI, Mistral, Kubernetes, Terraform, Cisco… |
| **Mascottes `Blason 1A`** | **24** | Les 4 planches officielles de `Blason 1A` (6 angles, 6 postures, 6 émotions, 6 spécialistes 3/4 droite) |

### Chapitre 9 — Surfaces Système iOS 18 (`Page 11`), États de Résilience (`Page 12`) & Animations Spring (`Page 13`)

- **Surfaces Système iOS 18 (`Page 11` · `SYS-01` & `SYS-02`)** :
  - **Widgets Écran d'Accueil (`W-1` à `W-3` & `W-Radar`)** : Petit widget Série & Readiness (`W-1`), moyen **Radar IA Live (`W-Radar`)**, moyen Progression multi-pistes (`W-2`) et grand **Widget Interactif Flashcard Quotidienne (`W-3` / `NS-14`)** via `AppIntent` iOS 18 ;
  - **Dynamic Island & Live Activities (`LA-1` à `LA-3`)** : Suivi en direct d'une séance ou d'un examen blanc Pearson VUE (états compact, minimal et étendu) et continuité vocale `Nova` ;
  - **Control Center (`CC-1`)** : Commande rapide iOS 18 (`ControlWidget`) pour lancer une séance express ou le Hub IA vocal en 1 Tap.
- **États de Résilience Hors-Ligne & Zéro Culpabilité (`Page 12` · `RES-01` & `RES-02`)** :
  - **`RES-01` · Mode Hors-Ligne Train / Avion (`142 Mo`)** : Téléchargement de packs de certifications vérifiés par SHA-256 (`142 Mo`) et file d'attente locale persistante (`DR-004`) synchronisée dès le retour du réseau ;
  - **`RES-02` · Reprise Bienveillante Zéro Culpabilité** : Écran d'accueil chaleureux après une pause, proposant une **Séance Express de 5 min** sans perte punitive ni culpabilisation.
- **Système d'Animations & Transitions Spring (`Page 13` · `ANIM-01` à `ANIM-08`)** :
  - **`ANIM-01`** : Pression physique des coussins 3D (`CUSTOM_SPRING`, `stiffness: 600, damping: 28, 120 ms`, offset `6px ➔ 1px`) ;
  - **`ANIM-02`** : Montée de feuille flottante Apple Pay & voile assombri (`MOVE_IN BOTTOM`, `stiffness: 340, damping: 26, 380 ms`) ;
  - **`ANIM-03`** : Entrée synchronisée de la mascotte 3/4 droite et de la bulle de question (`SMART_ANIMATE`, `stiffness: 380, damping: 24, 320 ms`) ;
  - **`ANIM-04`** : Tiroir d'historique IA Push `85 %` style Claude (`PUSH RIGHT`, `stiffness: 360, damping: 28, 360 ms`) ;
  - **`ANIM-05`** : Pulsation concentrique du halo vocal live `Nova` (`KEYFRAMES / SMART_ANIMATE`, `stiffness: 220, damping: 18, 650 ms`) ;
  - **`ANIM-06`** : Remplissage progressif du Baromètre Pearson VUE `/1000` (`SMART_ANIMATE`, `stiffness: 280, damping: 22, 480 ms`) ;
  - **`ANIM-07`** : Tracé de la double courbe `Avec CertiGo (845/1000)` vs `Sans CertiGo (580/1000)` (`SMART_ANIMATE`, `stiffness: 260, damping: 24, 520 ms`) ;
  - **`ANIM-08`** : Saut de célébration de `Blason 1A` en fin d'étape (`BOUNCY SPRING`, `stiffness: 280, damping: 16, 480 ms`) — toutes résolues via `PrismMotion` avec repli instantané lorsque `UIAccessibility.isReduceMotionEnabled` est actif.

---

## 🗺️ Monorepo

```
certigo/
├─ apps/
│  ├─ apple/               # CertiGo Natif Apple (iOS 18+ / SwiftUI / WidgetKit / ActivityKit)
│  │  ├─ CertigoNative/    # App hôte iOS, WidgetExtension (W-1..W-3, LA-1..LA-3, CC-1), Debug Gallery
│  │  └─ CertigoKit/       # Package Swift modulaire :
│  │     ├─ BrandAssets/          # Icônes officielles Tier-1 & catalogue d'assets
│  │     ├─ CertigoDomain/        # Modèles métier, contrats de contenu & règles pures
│  │     ├─ CertigoCortex/        # Moteur FSRS, mastery, calibration de Brier & readiness (Swift pur)
│  │     ├─ CertigoData/          # Client API résilient, cache local SHA-256, file offline (DR-004), AIRouter
│  │     ├─ CertigoAppleFileIO/   # Persistance atomique & écriture disque sécurisée
│  │     └─ Prism/                # Design system Prism SwiftUI, 53 écrans Figma Pro, 900 assets, animations Spring
│  └─ mobile/              # App Flutter multi-plateforme (iOS + Android) — Riverpod + go_router
├─ packages/
│  ├─ prism_ui/            # Design system Prism Flutter (tokens, thème, composants glass, goldens)
│  ├─ core/                # Socle Dart : env, Result, Failures, utils transverses
│  ├─ cortex/              # Moteur FSRS / mastery / readiness / notation par type (Dart pur)
│  └─ data/                # DTO, API client, repositories, cache & sync offline
├─ backend/                # .NET 8 isolated Azure Functions — Clean Architecture
│  ├─ src/
│  │  ├─ Certigo.Api/            # HTTP triggers, middleware auth/erreurs
│  │  ├─ Certigo.Application/    # Services métier, DTO, abstractions
│  │  ├─ Certigo.Domain/         # Modèles + règles (readiness, FSRS, XP) — sans dépendance
│  │  └─ Certigo.Infrastructure/ # Cosmos DB, validation token Entra, Microsoft Foundry Tutor LLM
│  └─ tests/               # Tests unitaires, d'architecture et d'intégration (xUnit)
├─ infra/                  # Infrastructure as Code (Bicep) : Cosmos, Storage, Functions, KV, AI
├─ contracts/              # Contrats JSON partagés (packages de contenu v2/v3, conteneurs Cosmos)
├─ content/                # Instantané historique du corpus monorepo (lecture/compatibilité uniquement)
├─ tools/                  # Validateurs d'état, de gouvernance, d'assets, d'architecture Swift & seed
├─ docs/                   # Architecture, état généré, ADRs, runbooks & rapports de phases
└─ .github/workflows/      # CI/CD : Apple, mobile, backend, contenu, infra, sécurité & gouvernance
```

Détail complet : [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) et [`apps/apple/DESIGN.md`](apps/apple/DESIGN.md).

> [!TIP]
> 🧭 **Pour voir l'état réel et à jour du projet** (ce qui est *réellement* construit, fonctionnalité
> par fonctionnalité), consultez le tableau de bord vivant : [`docs/ETAT_DU_PROJET.md`](docs/ETAT_DU_PROJET.md).
> Ce document est aussi, depuis le 2026-09-03, le **registre canonique unique** des risques de
> sécurité/fiabilité (§14) et du plan de migration restant (§15).

Les faits techniques observables (versions, workflows, tests, corpus historique, types
pédagogiques, référence Git analysée et packages actifs de `certigo-content`) y sont générés
depuis le dépôt :

```bash
# Après avoir commité les sources observables :
python tools/generated_contracts.py --refresh
python tools/project_state.py --refresh-reference
python tools/generated_contracts.py --check
python tools/project_state.py --check   # contrôle local identique à la gate CI
python -P -m unittest discover -s tools/tests -p "test_*.py" -v
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
| Natif Apple (iOS 18+) | **Swift 6 / SwiftUI**, `CertigoKit` SPM, **WidgetKit** (`AppIntent`), **ActivityKit** (Dynamic Island / Live Activities), **MSAL** (Entra CIAM) |
| Design System | **Prism** (`apps/apple/CertigoKit/Sources/Prism` & `packages/prism_ui`) — spectre OKLCH à clarté constante, 53 écrans Figma Pro, 900 assets officiels, 8 ressorts `PrismMotion` |
| Mobile Cross-Platform | Flutter / Dart, Riverpod, go_router, monorepo **Melos** |
| API | **Azure Functions .NET 8 isolated**, HTTP triggers, Clean Architecture |
| IA & Coaching | **Routeur IA 5 niveaux (`AIRouter`)**, `AISecretRedactor` local, Microsoft Foundry / Azure OpenAI (écrit structuré & vocal live `Nova`) |
| Données | **Azure Cosmos DB** (serverless) |
| Médias & Packages | **Azure Blob Storage** (`lesson-assets` & packages de contenu signés SHA-256) |
| Identité | **Microsoft Entra External ID** (MSAL natif / Connexion avec Apple + JWT validé côté Functions) |
| Secrets | **Azure Key Vault** (accès via *managed identity*) |
| Observabilité | **Application Insights** (workspace-based) |
| IaC | **Bicep** (subscription-scoped, modules composables) |
| CI/CD | **GitHub Actions** (pipelines ciblés par dossier) & **Codemagic** (chaîne iOS) |

---

## 🚀 Démarrage rapide

### Pré-requis

| Outil | Version | Usage |
|---|---|---|
| Xcode / Swift | **Xcode 16+ / Swift 6** | app native iOS 18+ (`apps/apple/CertigoNative`) et package `CertigoKit` |
| Flutter SDK | **3.44.4** | app mobile, packages et goldens ; pin CI/release aligné |
| Melos | `dart pub global activate melos` | orchestration monorepo Dart |
| .NET SDK | **8.0** | backend Functions |
| Azure Functions Core Tools | v4 | exécution locale des Functions |
| Node.js | ≥ 20 | validation de contenu |
| Python | ≥ 3.10 | validation d'état, tests d'architecture (`tools/tests`) et seed Cosmos |
| Azure CLI + Bicep | récent | déploiement infra |

### 1) CertiGo Natif Apple (iOS 18+ / SwiftUI / Prism)

```bash
# Tests unitaires, d'architecture et du registre des 53 écrans Figma Pro :
cd apps/apple/CertigoKit
swift test -Xswiftc -warnings-as-errors

# Suite Python de validation des contrats, des phases 1..11 et de l'état du projet :
cd ../../..
python -P -m unittest discover -s tools/tests -p "test_*.py" -v
```

Pour lancer l'application native dans Xcode sur macOS, ouvrir
`apps/apple/CertigoNative/CertigoNative.xcodeproj` (schéma `CertigoNative`).

### 2) Mobile Flutter

```bash
dart pub global activate melos
melos bootstrap          # résout les dépendances de tous les packages Dart
melos run analyze        # analyse statique
melos run test           # tests unitaires + widgets
cd apps/mobile && flutter run
```

### 3) Backend (.NET 8 Isolated Azure Functions)

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

### 4) Contenu (`certigo-content`)

Le corpus migré est édité et publié depuis
[`gchambaud_microsoft/certigo-content`](https://github.com/gchambaud_microsoft/certigo-content).
Le dossier local `content/` est un instantané historique conservé pour compatibilité ; il ne doit
plus recevoir de changements éditoriaux.

La révision active est épinglée dans
[`docs/active-content-reference.json`](docs/active-content-reference.json) et vérifiée sur chaque
PR ainsi que quotidiennement. À la référence du **2026-09-23** :

| Package actif | Fichiers | Manifest ID |
|---|---:|---|
| Public (`public/public`) | **1622** | `sha256:11b297c76d95fedf1e83284acbcb3398333761fe23cad14520b4f8eada9393bb` |
| Privé (`answerKey/private`) | **714** | `sha256:7781a6d36add31223ea234c60808ded367d283c0d1f4a9a042cb1cdad71f9055` |

Ces valeurs décrivent les packages actifs du commit
`a433518a649a74a33ecdc8874a99685fc125b9ea`. Les compteurs issus de `content/` restent
explicitement **historiques**.

```bash
# Dans un clone de certigo-content, suivre son README et ses gates CI.
# Contrôle ponctuel de l'instantané historique de ce monorepo :
npm install --no-save ajv ajv-formats yaml glob
node tools/validate_content.mjs
```

> Dans `certigo-content`, les payloads publics sont séparés des `answerKey` privés : la notation
> des quiz reste autoritative côté API.

### 5) Infra

```bash
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam
```

---

## 🔁 Flux de bout en bout

```
Clients (Natif iOS SwiftUI / Flutter)  ──JWT Entra──▶  Azure Functions (.NET 8)  ──▶  Cosmos DB
   Prism UI (53 écrans · 900 assets)                     Clean Architecture            users · content
   Cortex (client, offline DR-004)                       Cortex (serveur, autoritatif) progress · attempts
   AIRouter + AISecretRedactor                           App Insights + Foundry LLM    events · leaderboard
```

- **`userId` provient TOUJOURS du JWT**, jamais du corps de requête.
- **Expurgation locale (`AISecretRedactor`)** : aucun secret ou jeton n'est transmis au Hub IA.
- Idempotence des soumissions de quiz et des synchronisations hors-ligne (`DR-004`) via `clientAttemptId`.
- Reprise durable des effets économie/gamification via un état d'opération Cosmos ; aucune
  transaction cross-container n'est supposée.
- Le moteur **Cortex** est aligné entre le client (UX réactive et packs hors-ligne `142 Mo`) et le serveur (vérité autoritative).

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
| `ci-cortex-parity` | `packages/cortex/**`, `backend/**` | parité comportementale FSRS / readiness / notation entre client et serveur |
| `ci-migration-registry` | `docs/migration/**`, validateur Python | statuts, états, dépendances et absence de cycle |
| `ci-project-state` | chaque PR, `main`, quotidien | état généré identique, référence active `certigo-content`, 274 tests Python et manifestes public/privé exacts |
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
> Sur la VM Azure du runner, installez au minimum : Flutter/Dart, .NET 8 SDK, Node 20, Azure CLI (Bicep), puis enregistrez le runner GitHub avec le label `certigo-ci`.

> [!IMPORTANT]
> **Accès sortant internet du runner.** Depuis le retrait de l'accès sortant par
> défaut d'Azure (septembre 2025), une VM sans IP publique explicite n'a **aucune
> connectivité sortante** — le runner ne peut alors ni joindre GitHub ni restaurer
> les paquets NuGet/pub.dev, et tous les jobs échouent. La connectivité est assurée
> par une **NAT Gateway** (`nat-vm-certigo-runner-2`) associée au sous-réseau `snet-runners`,
> avec une IP publique Standard dédiée. Si l'egress retombe, vérifier :
> ```bash
> az network nat gateway show -g rg-certigo-ci -n nat-vm-certigo-runner-2
> az network vnet subnet show -g rg-certigo-ci --vnet-name vnet-certigo-ci \
>   -n snet-runners --query natGateway.id
> ```
> La fonctionnalité `Microsoft.Network/AllowBringYourOwnPublicIpAddress` doit être
> enregistrée sur la souscription (self-service via `az feature register`).

---

## 🛣️ Roadmap & Lots livrés

- **P0 — Fondations** ✅ Monorepo, design system Prism, backend Clean Architecture (.NET 8), IaC Bicep, CI/CD, séparation `public` / `answerKey`.
- **P1 — Socle Natif Apple & Moteur Cortex** ✅ Extraction `CertigoKit` (`CertigoDomain`, `CertigoCortex`, `CertigoData`, `BrandAssets`, `Prism`), authentification Entra CIAM / Connexion avec Apple, notation serveur autoritative.
- **P2 — Fichier Maître Figma Pro V5 (`13 Pages · 53 Écrans/Surfaces · 123 Hotspots Spring`)** ✅
  - Onboarding complet 11 écrans (`OB-01` à `OB-08B`), sélection multi-certifications en parallèle (`OB-03A`), veille Grands Acteurs IA (`OB-03B`) & 3 pop-ups système iOS natifs ;
  - Accueil îlots 3D Waymo (`01`), Popover marques avec vrai logo officiel AWS (`02`), aperçu `[ 📖 Mémo | COMMENCER | ✦ IA ]` (`03`) & Fiche Mémo Apple Pay (`14`) ;
  - Moteur d'exercices à **10 formats (`Q_TYPE_01` à `Q_TYPE_10`)**, bulles mascottes 3/4 droite (`15pt Bold ◀`), explication d'erreur IA sur fond assombri `62 %` (`05`), Déclic 20 s (`15`) & comparateur côte-à-côte (`20`) ;
  - Hub IA 4 écrans (`06A` Accueil Gemini, `06B` Écrit + Schéma ASCII & Astuce Examen, `06C` Vocal Live `Nova 1,0×` en arrière-plan, `06D` Tiroir Push `85 %` style Claude) + `AIRouter` & `AISecretRedactor` ;
  - Simulation officielle Pearson VUE (`21` Variante C 5 domaines, `22` feuille Apple Pay avec vrai blason `AZ-104`, `23` cockpit chronométré `12 ✓ · 13 🏳 · [14/50]`, `24` carrousel Baromètre Pearson VUE `● ○ ○`) ;
  - Podium 3D (`07A`), Mes Amis & `👏 Saluer` (`25`), Moi & vrais blasons (`08/26`), Dashboard Statistiques Pro en 2 volets (`08B-1` & `08B-2`), offre `CertiGo PRO` (`27-A`) & Paramètres style ChatGPT iOS 2026 (`28`) ;
  - Bibliothèque des **24 poses de `Blason 1A` (`Page 08`)**, catalogue des **900 assets officiels (`Page 10` & `Prism.xcassets`)**, surfaces système **iOS 18 (`Page 11` : Widgets `W-1..W-3`, `Radar IA Live`, `Dynamic Island LA-1..LA-3`, `Control Center CC-1`)**, résilience **Hors-Ligne `142 Mo` & Reprise Zéro Culpabilité (`Page 12` : `RES-01`, `RES-02`)** et système d'animations **Spring (`Page 13` : `ANIM-01` à `ANIM-08`)**.

---

## 📄 Licence & marques

Projet original. Microsoft, Azure, AWS, Google Cloud, GitHub, Cisco, Kubernetes/CNCF, HashiCorp,
OpenAI, Anthropic et les codes de certification cités sont des marques de leurs détenteurs
respectifs. Certigo n'est affilié ni approuvé par aucun fournisseur. Aucun contenu d'examen réel
n'est reproduit — toutes les leçons et tous les items sont **originaux**.
