# MASTER IMPLEMENTATION PROMPT
## CertiGo Product, UX and UI Transformation

> **Version :** 1.1 — 22/10/2026 (v1.1 : §22A *Official brand iconography* — les vrais symboles des éditeurs — et étape **2B**)
> **Destinataire :** l'agent de développement (vibe coding) qui travaille sur le dépôt CertiGo.
> **Statut :** prompt maître, autonome. Tu n'as **pas** à refaire la recherche : elle est consignée dans `docs/product/01_CERTIGO_TOP-10-WORTHY_REPORT.md` et transformée en décisions dans `docs/product/02_CERTIGO_PRODUCT_EXPERIENCE_BIBLE.md`. Ce document traduit ces décisions en **instructions d'ingénierie**.
> **Précédence en cas de conflit :** (1) instructions explicites du propriétaire dans le chat → (2) Decision Requests approuvées (`docs/transformation/decisions/`) → (3) ce Master Prompt → (4) la Bible → (5) le Rapport. Un conflit non résolu par cette échelle déclenche le **BLOCKED DECISION PROTOCOL** (§37).
> **Mots-clés normatifs (RFC 2119) :** **MUST** = obligatoire ; **MUST NOT** = interdit ; **SHOULD** = recommandé, toute dérogation est justifiée par écrit dans le rapport de phase ; **MAY** = optionnel.

---

## 0. Mode d'emploi

1. Lis ce document **en entier** avant toute action. Puis lis la Bible (sections citées ici) au moment où une phase en a besoin.
2. Tu exécutes **une seule phase à la fois**, dans l'ordre du §34, et tu t'arrêtes à la fin de chaque phase pour validation par le propriétaire.
3. Chaque phase se termine par les **7 portes** : BUILD → TEST → VISUAL VALIDATION → ACCESSIBILITY VALIDATION → PERFORMANCE CHECK → REPORT → SAFE CHECKPOINT (§34.2).
4. Tout ce qui n'est pas spécifié ici ou dans la Bible **n'est pas autorisé par défaut** : tu ouvres une Decision Request (§37).
5. Tu ne déclares jamais un travail terminé sans **preuve de test** (sortie de commande, capture, rapport d'audit).

---

## 1. ROLE

Tu es **l'ingénieur iOS principal et le gardien du design system** de CertiGo. Tu combines :
- la rigueur d'un **ingénieur SwiftUI senior** (Swift 6, concurrence stricte, architecture testable, performance) ;
- l'exigence d'un **designer d'interaction Apple** (Human Interface Guidelines, Liquid Glass, Dynamic Type, VoiceOver, haptique) ;
- la discipline d'un **mainteneur de design system** (aucun composant ponctuel, aucune valeur brute) ;
- la prudence d'un **ingénieur de migration** (pas de big bang, flags, points de contrôle, rollback).

Tu n'es **pas** un designer libre : tu n'inventes ni style, ni écran, ni mécanique. Tu implémentes la Bible avec exactitude et tu signales ce qui est ambigu.

---

## 2. MISSION

Transformer l'app iOS native CertiGo **existante** en l'expérience cible décrite dans la Bible — **« Progresser en tech, chaque jour »** — **sans casser ce qui fonctionne** (contrats serveur, logique autoritative, authentification, données, tests).

La transformation est **progressive** (Phases 0 → 11, plus l'étape 2B), **réversible** (flags + tags), **mesurée** (baselines, budgets) et **documentée** (un rapport par phase).

Résultat attendu à la fin de la Phase 11 :
- une app organisée autour de **Aujourd'hui · Atlas · Ensemble · Profil** ;
- une **Séance adaptative** (Express 5 min · Séance 15 min · Plongée 30–45 min) composée à partir d'atomes d'apprentissage ;
- des **formats d'exercice natifs de la tech** (artefacts : code, logs, configs, commandes, schémas) ;
- la **Situation du jour**, l'**Atlas** des connaissances, la **Préparation** honnête, le **Rythme** hebdomadaire, les **Squads** ;
- une IA **contextuelle et ancrée** (pas un onglet de chat) ;
- le design system natif **Prism** comme unique source de style ;
- un niveau d'accessibilité, de performance et d'intégration iOS digne d'une app de référence de l'App Store.

---

## 3. PRODUCT NORTH STAR

- **Mission produit :** *Become better at technology, every day.* — « Progresser en tech, chaque jour. »
- **Promesse de marque (à conserver) :** « Une question. Une idée plus claire. »
- **Thèse :** l'unité d'apprentissage de CertiGo n'est pas le mot ni la fiche, c'est la **situation** : un mini-cas réel, un artefact technique, une décision, une explication qui fait « déclic », puis une révision espacée qui l'ancre.
- **Métrique North Star :** **Apprenants à apprentissage durable hebdomadaire (WDL — Weekly Durable Learners)** = nombre d'utilisateurs qui, sur 7 jours glissants, ont réussi **≥ 3 rappels différés** (concept revu ≥ 72 h après la dernière exposition, réponse correcte au premier essai) **ou** fait passer **≥ 1 concept** à l'état *Ancré*. Elle mesure « apprend grâce à CertiGo », pas « utilise beaucoup CertiGo ». Définition complète et métriques garde-fous : Bible §2 et §31 ci-dessous.
- **Règle de décision transverse :** une fonctionnalité, une animation ou une mécanique qui n'améliore ni l'apprentissage durable, ni la régularité saine, ni la clarté **MUST NOT** être ajoutée.

---

## 4. VERIFIED CURRENT STATE

> **Statut de ce paragraphe :** état observé par l'équipe produit à partir de preuves datées (journaux de build Xcode des 14/10 et 22/10/2026, enregistrements d'écran des 19/10 et 22/10/2026, trace Instruments du 19/10/2026, instantané du dépôt du 06/07/2026). **Tu MUST re-vérifier chaque point en Phase 0** (hypothèses H1–H11 du prompt de Phase 0) et **MUST NOT** le tenir pour acquis. Si la réalité diffère, la Phase 0 l'emporte et tu ouvres une Decision Request pour adapter le plan.

### 4.1 Client iOS natif (cible de la transformation)
- App SwiftUI `apps/apple/CertigoNative` (Swift 6, cible de déploiement iOS 17.0) dépendant du package SPM `apps/apple/CertigoKit` : `CertigoDomain` (AppLanguage, CertigoStudyPlanPreference, Contracts, EditorialPilotLessonLink, LearningServices, SmartReviewAdvisor), `CertigoData` (CertigoAPI, LearningClient, SubmissionStore, OfflineQuestionPack, RuntimeContentStore, RuntimeDisk, FileProtectionPolicy, PublicReleaseAPI/Contracts, PublicResourceReader, CanonicalQuestionReader, LearningHistoryPresentation, AccountDeletion, BoundedHTTPTransport, CIAM*), `CertigoAppleFileIO` ; dépendance `MSAL`.
- Fichiers de l'app : `CertigoNativeApp.swift` (**monolithe ≥ 3 683 lignes**), `NativeModel.swift`, `CredentialVault.swift`, `MSALAuthenticationProvider.swift`, `NativeEditorialPilotView.swift`.
- **Build Debug du 22/10/2026 en échec** : `CertigoNativeApp.swift:3683` `@Environment(\.accessibilityContrast)` dans `NativeCertificationCrest` (clé inexistante ; la clé SwiftUI est `\.colorSchemeContrast`).
- Lancement (simulateur, Release) : première frame rendue en ~64 ms ; état *Foreground-Active* atteint ~0,95 s après le début de la trace → **base saine à ne pas dégrader**.
- UI : 4 onglets `Apprendre` (menu `Mon apprentissage | Explorer`), `Coach`, `Communauté`, `Profil` ; tab bar Liquid Glass ; grands titres ; listes groupées système ; un accent indigo saturé (cartes héros et boutons pleine largeur) ; très forte densité de texte ; pas de mouvement ni de gamification visibles.
- Mode **Démo** omniprésent (« données et résultats fictifs », « aucun verdict ni score », « pas un corrigé publié ») et section **Développement / connecteur API de test** visible dans l'UI.
- **Atelier de décision** : `Situation · Décision · Explication` → choix → « Envoyer la réponse » → « En attente » → « Simuler l'explication » → tableau « Qui gère quoi ? » → « À retenir ». **Format à conserver et à faire évoluer** (devient le format *Situation*).
- Catalogue **Explorer** (39 certifications, filtres famille / catégorie / exercices disponibles), objectif actif confirmé par le serveur, Plan de préparation, Évaluation finale, Révision recommandée, packs de questions hors ligne, restauration de l'activité, Lecture guidée (pilote éditorial « Assistants IA responsables », ~18 min, sources vérifiées et datées).
- Réglages : 8 langues d'interface (fr, en, hi, zh-Hans, ko, es, it, de), notifications, compte, **suppression du compte**, lecture et accessibilité (« suivent les réglages système »), données et confidentialité.
- Icône : « C » hexagonal en verre indigo-violet avec étincelle centrale (Icon Composer, variantes sombre / teintée).

### 4.2 Backend, contenu, héritage (référence, hors périmètre UI)
- Backend **.NET 8 Azure Functions** (`backend/`), ~29 endpoints, Cosmos DB (8 conteneurs : users, content, progress, attempts, events, leaderboard, economy, friends), notation **autoritative serveur** (clé de correction jamais exposée), anti-triche (Allow / Flag / Reject), file de soumission idempotente, notifications planifiées côté serveur, Entra External ID (Microsoft / Google / Apple), > 400 tests.
- Contenu **as code** (`content/`, YAML + schémas JSON + validateur CI) : 146 leçons ; 5 parcours de 12 leçons (AZ-900, AZ-104, AI-900, DP-900, SC-900) + 84 parcours amorcés à 1 leçon ; formats prévus par le schéma (mcq, multi, scenario, cloze, ordering, matchPairs, spotTheIssue, applied) mais **145 items sur 146 sont des QCM** ; 1 question par leçon.
- App **Flutter** héritée (`apps/mobile`, `packages/prism_ui`, `cortex`, `data`, `core`) : gamification complète (XP, niveaux, série + réparation, gemmes, boutique, 10 ligues, quêtes, succès, saisons, amis, partage), onboarding de 23 écrans avec paywall avant la première leçon, 7 mascottes dérivées d'icônes Azure. **Référence fonctionnelle uniquement : tu MUST NOT porter son UI.**
- Moteurs à réutiliser via le backend : FSRS / révision espacée, maîtrise par concept, readiness par domaine d'examen (formule heuristique non calibrée), recommandation « next best », mémoire des fausses idées par concept (mauvaises options récurrentes), tuteur ancré sur des extraits validés avec repli déterministe.

---
## 5. TARGET PRODUCT EXPERIENCE

En une phrase : **chaque jour, en un tap, l'apprenant pratique une vraie situation technique, comprend pourquoi, voit sa connaissance grandir sur son Atlas, et revient parce qu'il veut continuer — jamais par peur de perdre.** (Bible §1–§4.)

L'expérience cible MUST réunir :
1. **Aujourd'hui** — un plan du jour avec une seule action principale (Bible §10).
2. **La Séance** — Express (~5 min), Séance (~15 min), Plongée (30–45 min), composée par le serveur (Bible §7.5).
3. **Les formats natifs de la tech** — artefacts (code, log, config, commande, schéma) et décisions (Bible §7.3).
4. **Le Déclic** — feedback explicatif immédiat, fausses idées nommées, célébrations proportionnées (Bible §7.6, §13).
5. **La Situation du jour** — rituel commun, distribution communautaire après réponse, partage sans spoiler (Bible §9.5).
6. **L'Atlas** — Profondeur × Mémoire par concept ; routes de certification (Bible §7.4, §16 NS-8).
7. **La Préparation** — honnête, avec incertitude, probabilité masquée jusqu'à calibration (Bible §7.7).
8. **Le Rythme** — hebdomadaire, avec repos et retour célébré (Bible §6.3).
9. **Ensemble** — Squads coopératives, encouragements, défis justes ; privé par défaut (Bible §6.4–6.5, §11).
10. **L'IA contextuelle** — aux moments utiles, ancrée, à contrat d'effort, avec repli (Bible §6.6, §12).
11. **iOS natif et accessible** — widgets, Live Activities, App Intents, Dynamic Type AX5, VoiceOver complet (Bible §14).
12. **Cœur calme, expression méritée** — Prism comme langage unique (Bible §15, §18).

---

## 6. LEARNING MODEL (règles d'ingénierie)

### 6.1 Répartition des responsabilités
| Calcul | Où | Règle |
|---|---|---|
| Notation d'un item | **Serveur** | MUST rester serveur (clé jamais envoyée), sauf politique DR-004 approuvée |
| États de concept (*Découvert / En pratique / Ancré / Maîtrisé*), échelon, rétention prédite, fausses idées actives | **Serveur** (`Certigo.Domain`) | Le client affiche, ne calcule pas |
| Composition de séance (Express / Séance / Plongée) | **Serveur** (extension du moteur de recommandation) | Le client demande `SessionPlan(length)` et le rend |
| Préparation (bandes, incertitude, couverture par objectif) | **Serveur** | MUST NOT afficher la formule heuristique comme un pourcentage |
| Rythme hebdomadaire, jours de repos, rattrapage | **Serveur** | Fuseau horaire de l'utilisateur, idempotent |
| Distribution communautaire de la Situation du jour | **Serveur** (agrégats anonymes) | Visible uniquement après réponse |
| Mise en forme, animation, accessibilité, cache | **Client** | — |

Si un champ nécessaire n'existe pas côté serveur : tu MAY l'ajouter **de façon additive** dans `backend/` (nouvel endpoint ou champ optionnel, tests xUnit, contrat documenté dans `docs/transformation/contracts/`), **MUST NOT** changer la sémantique d'un champ existant, et ouvres une Decision Request si la logique métier est nouvelle. En attendant, le client MAY utiliser des fixtures **uniquement en Debug** derrière flag.

### 6.2 Règles de rendu (client)
- **Question avant options :** pour les items marqués `revealOptionsDelayMs` (défaut serveur 0–1 500 ms), l'énoncé s'affiche seul, puis les options (animation `quick`, Reduce Motion = apparition directe). Bouton « Voir les options » pour passer.
- **Confiance :** pour les items marqués `captureConfidence = true`, afficher `ConfidencePicker` (Sûr / Plutôt / Au hasard) **avant** Vérifier ; valeur par défaut aucune ; facultatif sauf en examen blanc.
- **Feedback :** immédiat en pratique (≤ 1 s perçu p95 en ligne ; indicateur de vérification au-delà de 300 ms) ; **aucun** feedback pendant un examen blanc.
- **Explications par option :** afficher l'explication de l'option choisie + la bonne réponse ; la liste complète des options est dépliable.
- **Erreur avec certitude :** variante dédiée du `FeedbackPanel` (copie Bible §7.6).
- **Test de saut :** sur une carte d'exemple travaillé marquée `skippable`, bouton « Je connais déjà » qui déclenche l'item de vérification fourni par le serveur.
- **Fin de séance :** le serveur fournit l'ordre ; le client ne réordonne pas.
- **Reprise :** la position (carte, réponse en cours) est persistée localement à chaque carte ; « Reprendre » valable 24 h (Plongée : jusqu'à 7 jours).
- **Hors ligne :** rendu des 2 séances pré-composées en cache ; réponses mises en file (`SubmissionStore`, idempotence existante) ; affichage « Réponse enregistrée — résultat à la synchronisation » sauf si DR-004 autorise un feedback provisoire.

### 6.3 Formats (contrats de rendu)
Chaque format est un composant Prism (§19) piloté par un `ItemPayload` versionné. Formats **P1** (Phase 4) : `choice` (single / multi + confiance), `situation` (contexte + artefact + 1–3 décisions), `predict`, `spotTheIssue` (sélection de ligne(s) dans un artefact), `ordering` (Parsons 1D/2D, ordres équivalents acceptés côté serveur), `commandComposer` (jetons). **P2** : `readLog`, `diagnose` (arbre de triage à étapes), `diagramCompletion`, `tradeOff`, `explain` (texte / voix, formatif), `classify`. **P3** : `estimate`, `miniCase`, `docsSprint`, `labHandoff`.
Règles : tap > saisie > glisser ; tout glisser a une alternative tap et une action VoiceOver ; artefacts ≤ 25 lignes (au-delà : repli / pagination fournie par le contenu) ; saisie libre ≤ 1 ligne sauf `explain`.

### 6.4 Contenu
- Extensions du schéma `content/schema/lesson.schema.json` et du validateur **additives** (nouveaux `type`, champs optionnels `artifact`, `revealOptionsDelayMs`, `captureConfidence`, `misconceptionTags`, `rung`, `sources[].verifiedAt`), avec tests du validateur.
- Le client MUST rendre gracieusement un format inconnu (« Ce format arrive bientôt » + passage à l'item suivant, événement `item_format_unsupported`).

---

## 7. DAILY LOOP
- *Aujourd'hui* MUST proposer **une** action principale : Commencer / Reprendre la séance (§14 S-10).
- Durée par défaut proposée par le serveur (`suggestedLength`) ; modifiable en 1 tap.
- Un jour de Rythme est validé côté serveur dès **une séance Express terminée** (ou une Situation du jour + 3 rappels).
- Après la séance : Résultats (S-25) → retour à Aujourd'hui avec le Rythme mis à jour et l'aperçu de demain.
- Rappels : ≤ 1 / jour, heure et contexte choisis, niveaux d'interruption corrects (§27), arrêt silencieux après 3 rappels ignorés (logique serveur existante à adapter).
- **MUST NOT :** compte à rebours, message de perte, badge rouge sur l'icône pour inciter, notification la nuit.

---

## 8. PROGRESSION MODEL
- Afficher par concept : **état** (glyphe + libellé), **échelon** (`DepthLadderView`, 5 échelons + « Pratiquer » hors téléphone), **mémoire** (rétention prédite en mots : « solide », « à raviver bientôt », « s'estompe »), **fausse idée** active.
- Agrégations : territoire (anneau), région (concepts ancrés / maîtrisés, profondeur moyenne), route (Préparation), personne (Passeport).
- **Préparation** : bandes `insufficientEvidence | notYet | onTrack | readyToTry | veryReady`, barre d'incertitude, nombre de preuves, couverture par objectif officiel, « 3 actions », fourchette de date si ≥ 3 semaines d'historique ; **probabilité** affichée seulement si le serveur renvoie `calibrated = true`.
- **MUST NOT** : XP visible, niveaux génériques, pourcentage de réussite non calibré, « couronnes ».

---

## 9. GAMIFICATION MODEL
Chaque mécanique MUST citer la règle d'apprentissage qu'elle sert dans son fichier de spécification (`docs/transformation/specs/`). Cible (Bible §6.2) :
| Mécanique | Implémentation | Flag |
|---|---|---|
| Rythme hebdomadaire | `RhythmWeekView` ; objectif 3–6 j/sem choisi ; 2 jours de repos ; pause jusqu'à 4 semaines ; meilleur rythme ; rattrapage gratuit (3 rappels) | `rhythm.v1` |
| Série quotidienne | Optionnelle, désactivée par défaut, visible dans Profil uniquement | `rhythm.dailyStreakOptIn` |
| Jalons de maîtrise | 1er *Maîtrisé*, territoire complet, examen blanc ≥ 80 %, 10 fausses idées corrigées, passage au lab | `celebrations.v1` |
| Missions | ≤ 3 par semaine, liées à une compétence, dont 1 coopérative (Squad) | `missions.v1` |
| Célébrations | `PrismCelebration` niveaux 0–3 + variantes Reduce Motion / silencieuse / Mode Calme | `celebrations.v1` |
| Temps forts | ≤ 4 par an, coopératifs, sans battle pass | `events.v1` |
**À retirer de l'UI (DR-005) :** gemmes, boutique, gel / réparation payants, ligues XP à 10 paliers, XP / niveaux affichés, succès de volume, saisons mensuelles. Les endpoints backend correspondants restent en place et inutilisés jusqu'à décision.

---

## 10. SOCIAL MODEL
- **Privé par défaut** ; pseudonyme ; visibilité granulaire (Rythme, jalons, Situations, Passeport) ; découverte par lien / code / QR ; **aucun import de contacts** par défaut.
- **Squads** (3–8) : création, invitation par lien, appariement optionnel par route et mois d'examen, objectif hebdomadaire commun calculé côté serveur, contributions anonymisées par défaut, encouragements prédéfinis (1 tap).
- **Défis** asynchrones : même jeu de 5 items, appariés par cote, score = justesse × calibration, **sans chronomètre**.
- **Ligues de progression** (opt-in) : appariées par cote Glicko-2 et route, points de maîtrise plafonnés / jour, pas de relégation les 4 premières semaines, 2 semaines de grâce, ±3 voisins affichés.
- **Sécurité (MUST)** : bloquer, masquer, signaler ; aucun ajout à une Squad sans consentement ; aucun échec affiché à autrui ; pas de texte libre au lancement ; pas de localisation ; mode mineurs / âge minimum (Declared Age Range) ; vues employeur agrégées sauf opt-in.
- **Différé (MUST NOT en v1)** : chat libre, salles d'étude en direct, duels temps réel, fil d'activité public.

---

## 11. AI MODEL
- **Architecture :** moteur déterministe côté serveur (quoi) + couche de langage (comment) + contrat d'effort (l'apprenant d'abord). Pas d'onglet de chat ; l'onglet Coach actuel est **supprimé** et ses capacités sont redistribuées (§14).
- **Points d'entrée autorisés** (Bible §12) : *Expliquer autrement* (après réponse), *Indice* (après une première tentative, échelle à 4 niveaux), *Pourquoi ?* (2 tours max), *Comparer avec…*, *Analogie* (optionnelle), *Bilan* de séance, *Mon plan*, *Débrief* d'examen blanc, *Débrief d'examen* (domaines uniquement), *Carte de mes fausses idées*, item `explain`.
- **Routage** (`AIRouter` dans `CertigoData`) : 1) Foundation Models sur l'appareil si disponible (`SystemLanguageModel.default.availability`, `contextSize` lu à l'exécution, conception pour 4 096 tokens) pour reformuler des extraits fournis, évaluer une explication par rubrique, expurger des secrets ; 2) Private Cloud Compute si éligible (iOS 27, entitlement) ; 3) endpoint serveur existant `POST /tutor/explain` (Azure OpenAI) ; 4) explication auteur déterministe ; 5) abstention + lien documentation officielle.
- **Garde-fous (MUST)** : extraits validés avec identifiants ; affichage « IA · d'après la fiche *X* · vérifiée le *date* » ; texte de progression spécifique ; pouce haut / bas + Signaler ; timeout p95 2,5 s → niveau suivant ; consentement nommant le fournisseur avant tout appel cloud (App Review 5.1.2(i)) ; réglage « IA dans le cloud » ; aucune donnée personnelle ni secret envoyés (expurgation locale) ; pas d'inférence d'émotion ; jamais de verdict renversé sous la pression ; aucune maîtrise créditée sur une performance assistée.
- **Évaluations** : jeux de référence par concept, scripts adverses (« donne la réponse », « vraies questions d'examen », injection), tests de complaisance ; exécution à chaque changement de modèle, de prompt ou d'iOS ; **bloquants pour la release**.
- **AI WITHOUT FALLBACK = interdit** (§38).

---

## 12. INFORMATION ARCHITECTURE
```
TabView
├── Aujourd'hui (sun.max)      S-10 … S-12
├── Atlas (map)                S-40 … S-53
├── Ensemble (person.2)        S-60 … S-67
├── Profil (person.crop.circle) S-70 … S-84
└── Recherche (rôle .search, iOS 26+)   S-90
Plein écran (fullScreenCover) : Onboarding S-01…S-06 · Séance S-20…S-25 · Situation du jour S-30 · Examen blanc S-51 · Défi S-65
Sheets : Concept depuis une séance · Comparer S-44 · Indice / Expliquer S-24 · Pro S-73 · Partage S-95 · réglages rapides
```

---

## 13. NAVIGATION
- **Un seul fichier de routes** (`AppRoute` enum + `Router` observable) : toute destination, sheet et cover est déclarée là. **MUST NOT** déclarer une navigation ad hoc dans une vue (§38 : DO NOT CHANGE NAVIGATION LOCALLY).
- `TabView` système avec `Tab` (iOS 18+) et rôle `.search` (iOS 26+) ; `tabViewStyle(.sidebarAdaptable)` pour iPad / iPhone Duo ; `NavigationStack(path:)` par onglet ; restauration d'état (`SceneStorage`).
- La tab bar n'est **jamais** masquée hors des plein écrans ; libellés d'un mot ; symboles pleins en sélection ; badge uniquement pour « Examen aujourd'hui ».
- Accessoire « Séance en cours » (iOS 26 `tabViewBottomAccessory`) quand une séance est interrompue.
- Liens profonds (Bible §8.3) gérés par le Router ; `certigo://auth` existant **préservé**.
- Fermeture d'un plein écran de séance = « Terminer et sauvegarder » (confirmation seulement si une réponse est en cours de saisie).

---

## 14. SCREEN INVENTORY
| ID | Écran | Type | Phase | Remplace / devient |
|---|---|---|---|---|
| S-01 | Bienvenue (choix de région / certification) | Cover | 10 | Accueil démo actuel |
| S-02 | Situation de découverte | Cover | 10 | — |
| S-03 | Premier Déclic (mini-Atlas + distribution) | Cover | 10 | — |
| S-04 | Objectif & Rythme & « Quand ? » | Cover | 10 | Onboarding Flutter (référence) |
| S-05 | Sauvegarder (Sign in with Apple / passkey / Microsoft / Google) | Cover | 10 | Connexion existante (MSAL / CIAM préservés) |
| S-06 | Autorisation notifications (après 1re séance) | Sheet | 10 | — |
| S-10 | Aujourd'hui | Onglet | 3 | `Apprendre › Mon apprentissage` |
| S-11 | Mémoire (détail) | Push | 6 | « Révision recommandée » |
| S-12 | Bon retour (variante d'Aujourd'hui) | État | 7 | — |
| S-20 | Lecteur de séance | Cover | 4 | Atelier / exercice démo |
| S-21 | Carte d'apprentissage (question d'ouverture, explication, exemple travaillé, schéma) | Carte | 4 | Blocs hook / concept / example |
| S-22 | Item (un sous-écran par format §6.3) | Carte | 4 (P1), 5+ (P2) | `check` QCM |
| S-23 | Feedback | Panneau | 5 | « En attente » + « Simuler l'explication » |
| S-24 | Indice / Expliquer autrement / Pourquoi ? | Sheet | 9 | Tutor sheet (Flutter, référence) |
| S-25 | Résultats de séance | Carte | 5 | — |
| S-30 | Situation du jour | Cover | 5 | — |
| S-31 | Historique des Situations | Push | 8 | — |
| S-40 | Atlas (Carte / Liste, filtres) | Onglet | 6 (Liste en 3) | `Apprendre › Explorer` |
| S-41 / S-42 | Région / Territoire | Push | 6 | Familles / catégories |
| S-43 | Concept | Push / Sheet | 6 | — |
| S-44 | Comparer | Sheet | 9 | — |
| S-45 | Carte de mes fausses idées | Push | 9 | — |
| S-46 | Explorer (catalogue des routes) | Push | 3 | Catalogue 39 certifications |
| S-47 | Route / Objectif | Push | 6 | « Choisir comme objectif actif » (confirmation serveur préservée) |
| S-48 | Objectif d'examen (détail) | Push | 6 | — |
| S-49 | Préparation (détail) | Push | 6 | Readiness |
| S-50 / S-51 / S-52 | Examen blanc : intro / lecteur / débrief | Cover | 5 | « Évaluation finale » |
| S-53 | Déclarer mon résultat d'examen | Sheet | 6 | — |
| S-60 | Ensemble | Onglet | 8 (squelette en 3) | `Communauté` |
| S-61 / S-62 | Squad / Créer-Rejoindre | Push / Sheet | 8 | — |
| S-63 / S-64 | Amis / Profil ami | Push | 8 | Amis (backend existant) |
| S-65 | Défi | Cover | 8 | — |
| S-66 | Ligues de progression (opt-in) | Push | 8 | Ligue (Flutter) |
| S-67 | Inviter | Sheet | 8 | — |
| S-70 | Profil | Onglet | 3 (squelette) | `Profil` |
| S-71 | Passeport | Push | 6 | « Progression & historique » |
| S-72 | Historique & calibration | Push | 6 | — |
| S-73 | CertiGo Pro | Sheet | 10 | Paywall Flutter (référence) |
| S-74 | Réglages | Push | 3 | Réglages existants |
| S-75 … S-84 | Rythme & rappels · Langue · Lecture & accessibilité (Mode Calme, sons, haptique) · Confidentialité & visibilité · IA · Données hors ligne · Compte · **Suppression du compte** · À propos des données & méthode · Aide & signaler | Push | 3 → 10 | Réglages existants (préservés) |
| S-90 | Recherche | Onglet (rôle) | 6 | — |
| W-1 / W-2 / W-3 | Widgets Aujourd'hui / Situation du jour / Carte de révision | Extension | 10 (W-1 MAY en 3) | — |
| LA-1 / LA-2 / LA-3 | Live Activities examen blanc / Plongée / jour J | Extension | 10 | — |
| CC-1 | Contrôle « Express 5 min » | Extension | 10 | — |
| AI-1 | App Intents + entités Spotlight | Extension | 10 | — |
| S-95 | Cartes de partage | Rendu | 5 / 8 | Partage quotidien (Flutter) |
| D-1 | Galerie Prism + flags (Debug uniquement) | Debug | 1 | Connecteur de test (retiré de la prod) |
**Supprimés :** onglet Coach ; section Développement en production ; écrans gemmes / boutique / ligue XP / saisons / quêtes (héritage Flutter, non portés).

---

## 15. NORTH STAR SCREENS
Spécifications complètes : **Bible §16 (NS-1 à NS-14)**. Pour chacun, tu MUST implémenter : anatomie dans l'ordre indiqué, interactions, tous les états, exigences d'accessibilité, événements analytics, critères Given / When / Then listés. Rappel des critères bloquants :
- **NS-1 Premier lancement :** 1re décision en ≤ 2 écrans ; aucun champ texte ; jouable hors ligne (Situation embarquée).
- **NS-2 Aujourd'hui :** 1 tap = séance ; AX5 sans troncature ; résumé VoiceOver par carte.
- **NS-4 Trouver l'erreur :** rotor « Lignes », action « Sélectionner cette ligne », aucun glisser requis.
- **NS-5 Feedback :** ≤ 1 s perçu (p95) ; explication de l'option choisie.
- **NS-7 Situation du jour :** aucune statistique avant réponse ; carte de partage sans question ni réponse.
- **NS-8 Atlas :** la Liste est l'équivalent complet de la Carte et le mode par défaut sous VoiceOver ; 60 i/s avec ≤ 500 nœuds.
- **NS-10 Préparation :** « Preuves insuffisantes » sans aucun pourcentage tant que le serveur ne l'autorise pas.
- **NS-11 Examen blanc :** option temps majoré / sans limite.
- **NS-12 Ensemble :** profil privé et ligues désactivées par défaut.
- **NS-14 Widget carte de révision :** réponse mise en file sans ouvrir l'app.

---
## 16. DESIGN PRINCIPLES (règles opposables)
1. **L'apprentissage d'abord** — une mécanique sans règle d'apprentissage citée MUST NOT être implémentée.
2. **Un tap vers le progrès** — depuis l'ouverture, la meilleure activité MUST être lançable en 1 geste.
3. **L'effort avant l'aide** — indices et IA MUST apparaître après une tentative.
4. **Cœur calme, expression méritée** — aucun mouvement non sollicité sur un écran d'étude ; célébrations selon l'échelle 0–3.
5. **Le contenu est le héros** — énoncés et artefacts ont la priorité d'espace et de contraste.
6. **Honnête par construction** — aucune donnée fictive en production, aucune probabilité non calibrée, IA étiquetée.
7. **Respect de la personne** — aucune copie de perte, de culpabilité, de compte à rebours (sauf minuteur d'examen blanc optionnel).
8. **Célébrer la maîtrise, pas l'activité.**
9. **Natif et inclusif** — composants système, Dynamic Type AX5, VoiceOver, Reduce Motion = critères d'acceptation.
10. **Un seul système** — tout visuel passe par Prism.

---

## 17. VISUAL LANGUAGE
« Cœur calme, expression méritée » (Bible §5.3, §15). Résumé normatif :
- **Fond** : neutres système ; **accent** Indigo CertiGo sur ~10 % de la surface (actions, sélection, progression) ; **couleurs de région** pour la connaissance (puces, glyphes, Atlas, halos) ; **jamais** de bleu #0078D4 ; pas de dégradé sur les écrans d'étude.
- **Typographie** : système (SF Pro, New York pour l'éditorial, SF Mono pour le code), Dynamic Type partout.
- **Symboles** : SF Symbols + glyphes CertiGo **pour l'interface** ; **icônes officielles des éditeurs** (non modifiées, toujours avec le nom du produit) pour représenter les produits réels dans le contenu (§22A).
- **Surfaces** : opaques pour le contenu ; Liquid Glass pour la navigation et les contrôles.
- **Mouvement** : explique d'abord, célèbre ensuite ; une animation à la fois.
- **Signature** : *Réfraction* (visuel), motif *Déclic* (son), haptique *Déclic*.
- **Aucun personnage** (le glyphe compagnon *Facette* n'est implémenté que si une Decision Request dédiée est approuvée après le test V8 de la Bible).

---

## 18. PRISM TOKENS
Module `apps/apple/CertigoKit/Sources/Prism` (produit SPM `Prism`), ressources dans `Prism/Resources/Prism.xcassets` (couleurs avec variantes **Any / Dark / High Contrast / Dark High Contrast**). Les écrans importent `Prism` et n'utilisent **que** ces jetons.

```swift
// Signatures attendues (noms normatifs ; implémentation libre)
public enum PrismSpacing { public static let xxs: CGFloat = 2, xs = 4, s = 8, m = 12, l = 16, xl = 20, xxl = 24, xxxl = 32, huge = 48, giant = 64 }
public enum PrismRadius  { public static let s: CGFloat = 8, m = 12, l = 16, xl = 24 }        // + .capsule ; coins continus
public enum PrismSize    { public static let minTouch: CGFloat = 44, primaryButtonHeight = 50, readableWidth = 672 }
public enum PrismColorRole { canvas, surface, surfaceRaised, surfaceArtifact, textPrimary, textSecondary, textTertiary,
                             separator, accent, accentFill, onAccent, positive, negative, caution }
public enum PrismRegion  { cloud, ai, data, security, network, devops, code, systems }   // + .soft variant
public enum PrismSyntax  { plain, keyword, string, comment, number, type, flaggedLineBackground }
public enum PrismTextStyle { display, title1, title2, title3, headline, body, editorial, callout, subheadline, footnote, caption, code, codeSmall, numeric }
public enum PrismMotionToken { quick, snappy, smooth, expressive }   // résolus selon accessibilityReduceMotion
public enum PrismHapticToken { selection, correct, incorrectSoft, warning, declic }
public enum PrismSoundToken  { answer, declic, milestone }
public enum PrismMaterialRole { navigationGlass, floatingControlGlass }   // jamais pour du contenu
public enum PrismCelebrationLevel: Int { tick = 0, pulse = 1, refraction = 2, milestone = 3 }
```
Règles : un token = un rôle (jamais `blue500`) ; les neutres sont mappés sur les couleurs système (`systemGroupedBackground`, `secondarySystemGroupedBackground`, `tertiarySystemGroupedBackground`, `label`, `secondaryLabel`, `tertiaryLabel`, `separator`) ; toute variante (sombre, contraste, Reduce Motion, Reduce Transparency, Dynamic Type) est résolue **dans Prism**.

---

## 19. PRISM COMPONENTS
Liste normative (Bible §18.2). Chaque composant MUST avoir : API documentée, `#Preview` (nominal, vide, chargement, erreur, AX3, sombre), snapshot, test d'accessibilité, entrée dans la galerie Debug.
| Famille | Composants | Phase |
|---|---|---|
| Foundation | `PrismText`, `PrismIcon` (SF Symbols + glyphes), `PrismButtonStyle` (primary / secondary / tertiary / destructive / inline, état chargement), `PrismCard` (standard / héros / artefact / feedback / situation), `PrismSection`, `PrismRow`, `PrismChip`, `PrismBadge`, `PrismProgressBar`, `PrismProgressRing`, `PrismSegmentedControl` | 2 |
| Learning | `SessionProgressHeader`, `SessionLengthPicker`, `QuestionCard`, `ExplanationCard`, `WorkedExampleView` (sous-objectifs), `DiagramView` (spécification de données → formes natives + description structurée), `ArtifactView` (numéros, coloration, zoom, retour à la ligne, sélection de ligne, rotor), `ChoiceList`, `ConfidencePicker`, `TokenComposer`, `OrderList`, `SlotBoard`, `EstimateSlider`, `ExplainInput` (texte / dictée), `FeedbackPanel`, `ResponsibilityMatrix` (« Qui gère quoi ? »), `TakeawayLine`, `HintLadderView` | 2 (P1), 4–5 (P2) |
| Progress | `MasteryGlyph`, `DepthLadderView`, `MemoryForecastChart` (Swift Charts), `ReadinessBandView`, `ObjectiveCoverageList`, `RhythmWeekView`, `AtlasCanvas`, `AtlasList`, `RegionChip`, `RouteBadge`, `PassportCard` | 2–6 |
| Social | `AvatarMonogram`, `KudosButton`, `SquadGoalView`, `ChallengeCard`, `CommunityDistributionChart` | 8 |
| States | `PrismEmptyState` (sur `ContentUnavailableView`), `PrismErrorState`, `PrismOfflineBanner`, `PrismSkeleton`, `PrismToast`, `PrismCelebration`, `ShareCardRenderer` (`ImageRenderer`) | 2 |
| Accessibility | Bascule de disposition AX (`ViewThatFits` / `AnyLayout`), rotors personnalisés, actions personnalisées, annonces | 2 |
| Brand | `BrandIcon` (icône officielle non modifiée, contexte obligatoire), `BrandLabel` (icône + nom officiel), `BrandFallbackMark`, `BrandNoticesView` — données : module `BrandAssets` (§22A) | 2B |
`NativeCertificationCrest` et toute vue stylée existante sont **absorbées** par ces composants (Phase 1–3), sans changement de comportement ; un visuel qui imite un badge de certification est remplacé par `BrandLabel` + code d'examen en texte (§22A.2).

---

## 20. TYPOGRAPHY
| Style | Implémentation | Usage |
|---|---|---|
| `display` | SF Pro Bold, taille de base 40 via `@ScaledMetric(relativeTo: .largeTitle)` | Chiffres héros, titres de célébration |
| `title1/2/3`, `headline`, `body`, `callout`, `subheadline`, `footnote`, `caption` | `Font.TextStyle` système | Interface |
| `editorial` | `.system(.body, design: .serif)` | Lecture en Plongée (derrière flag jusqu'au test de préférence) |
| `code` / `codeSmall` | `.system(.body / .callout, design: .monospaced)` + chiffres tabulaires | Artefacts |
| `numeric` | `.monospacedDigit()` | Compteurs, minuteurs |
MUST : Dynamic Type jusqu'à `accessibility5` ; aucune taille fixe (`.font(.system(size:))` interdit hors Prism) ; aucune graisse < Regular ; Bold Text respecté ; aux tailles AX, piles horizontales → verticales ; énoncés jamais tronqués ; artefacts avec retour à la ligne activable + défilement horizontal ; texte minimum 11 pt à la taille par défaut.

---

## 21. COLORS
Valeurs normatives (vérifiées par calcul WCAG ; à encoder dans l'asset catalog) :
| Rôle | Clair | Sombre | Contraste élevé clair | Contraste élevé sombre |
|---|---|---|---|---|
| `accent` | #4338CA | #8E8CFF | #4338CA | #B4B2FF |
| `accentFill` (texte blanc) | #4338CA | #5B52F0 | #3A30B5 | #5B52F0 |
| `positive` | #1A7F37 | #3FB950 | #135D28 | #6BCD79 |
| `negative` | #B42318 | #FF7B72 | #9D1F15 | #FF9F98 |
| `caution` | #8A5A00 | #E3B341 | #704900 | #E3B341 |
| `region.cloud` | #0A5FC2 | #5AA9FF | #0850A2 | #80BDFF |
| `region.ai` | #7A35E8 | #B996FF | #6319D9 | #C7AAFF |
| `region.data` | #0B6E87 | #3DD5F3 | #09596D | #3DD5F3 |
| `region.security` | #C0263D | #FF7A8A | #9C1F32 | #FF9EA9 |
| `region.network` | #0B7268 | #3FD9C4 | #095B53 | #3FD9C4 |
| `region.devops` | #B8430B | #FF9F5A | #8F3409 | #FFA25F |
| `region.code` | #8F5A00 | #F5C64A | #734800 | #F5C64A |
| `region.systems` | #167A3B | #5BDB8A | #115E2D | #5BDB8A |
| `surfaceArtifact` | #F5F6F8 | #151517 | #EEF0F3 | #0E0E10 |
| `syntax.plain / keyword / string / comment / number / type` | #1D1D1F / #A0287A / #1F7A1F / #5E6470 / #9A4D00 / #0B5FA8 | #E6E6EA / #FF7AC6 / #7EE787 / #9AA3AF / #FFB86B / #79C0FF | (assombrir jusqu'à ≥ 7:1) | (éclaircir jusqu'à ≥ 7:1) |
| `syntax.flaggedLineBackground` | #FDE7E9 | #4A1D22 | idem | idem |
Variantes `soft` : 12 % d'opacité (clair), 20 % (sombre).
MUST : un test unitaire calcule le ratio WCAG de chaque paire texte / fond utilisée (clair, sombre, contraste élevé) et échoue sous **4,5:1** (texte) ou **3:1** (éléments non textuels) ; la couleur n'est jamais le seul porteur d'information (symbole + mot obligatoires pour correct / incorrect / état de concept).

---

## 22. SYMBOLS
- SF Symbols exclusivement pour l'interface ; variantes `.fill` pour la sélection d'onglet ; tailles via Dynamic Type (`imageScale`, `font`).
- Glyphes CertiGo à créer comme **symboles personnalisés** (`.symbolset` dans `Prism.xcassets`) : 8 régions, 5 états de concept, fausse idée, Déclic, route — graisses alignées sur SF Symbols, libellés d'accessibilité obligatoires.
- Animations de symboles (iOS 26+, `#available` ; les noms d'API exacts MUST être vérifiés dans le SDK installé) : `.symbolEffect(.drawOn)` jour de Rythme, `.symbolEffect(.variableColor)` / Variable Draw pour la profondeur, `contentTransition(.symbolEffect(.replace))` pour les changements d'état ; toutes neutralisées sous Reduce Motion.
- MUST NOT : représenter un produit réel par un SF Symbol générique, un dessin maison ou un emoji quand une icône officielle approuvée existe (§22A) ; utiliser une icône d'éditeur comme élément d'interface (bouton, onglet, état) ; emoji comme iconographie d'interface.

---

## 22A. OFFICIAL BRAND ICONOGRAPHY — icônes, symboles et logos officiels des éditeurs

> **Décision du propriétaire (22/10/2026 — Bible ADR-016) :** quand CertiGo parle d'un produit réel — un service Azure, un outil Power Platform, une fonctionnalité GitHub, un service AWS, Kubernetes… — l'apprenant voit **le vrai symbole**, celui qu'il retrouvera dans le portail, la console, la documentation et les schémas d'architecture officiels. **Jamais une imitation, jamais une approximation.** Cette section dit comment le faire **partout où l'éditeur le permet**, et proprement là où il ne le permet pas encore.
> **Mise en œuvre :** étape **2B** du §34.1 ; inventaire préalable en Phase 0 (`14_BRAND_ASSETS_AUDIT.md`) ; politique confirmée par **DR-010** avant tout import. Recherche détaillée et sources : annexes R8a / R8b du Rapport. *Ce qui suit est une politique de conformité prudente, pas un avis juridique.*

### 22A.1 Sept principes (MUST)
1. **Le vrai symbole désigne le produit, jamais CertiGo.** Une icône d'éditeur identifie *son* produit dans le contenu ; elle n'est jamais la marque, la mascotte, la récompense, l'illustration ou la décoration de CertiGo.
2. **Telle que fournie.** Exactement comme dans le kit officiel : mêmes formes, mêmes couleurs, mêmes proportions, aucun effet ajouté.
3. **Toujours avec son nom.** Le **nom officiel complet** du produit est visible à côté de l'icône ; l'icône ne le remplace jamais.
4. **Uniquement le produit pour lequel elle a été dessinée.** L'icône *Azure Virtual Machines* représente Azure Virtual Machines — pas « un serveur » ni « le cloud » en général.
5. **Dans le périmètre autorisé par l'éditeur.** Chaque kit a ses conditions ; le code les applique automatiquement par contexte (§22A.5). Ce qui n'est pas autorisé tombe sur un repli propre (§22A.11).
6. **Jamais dominante.** Une icône d'éditeur n'est jamais l'élément visuel principal d'un écran ; le contenu et la marque CertiGo restent plus visibles.
7. **Traçable et réversible.** Chaque fichier a une source officielle, une version, une date, des conditions archivées, une empreinte SHA-256 ; chaque éditeur peut être basculé en repli à distance.

### 22A.2 Trois niveaux d'autorisation
| Niveau | Quoi | Où | Statut par défaut |
|---|---|---|---|
| **1 — Autorisé sous conditions** | Icônes de produits et services issues des **kits d'architecture officiels** (Microsoft : Azure, Power Platform, Dynamics 365, Fabric, Entra ; autres éditeurs selon le §22A.3) ; icônes non-logo publiées sous licence libre (ex. **Octicons** de GitHub, MIT) | Contenu pédagogique : schémas, cartes *Apprendre*, *Situations*, explications, page *Concept*, glossaire | `approved` après DR-010 ; confirmation écrite de l'éditeur recommandée avant le lancement public |
| **2 — Sur autorisation écrite** | **Icônes d'applications Microsoft 365** (Word, Excel, PowerPoint, Outlook, Teams, SharePoint, OneDrive, Exchange, Access, Defender, Copilot) ; symbole Windows ; logos GitHub (Invertocat, lockups produits) ; toute icône de niveau 1 **hors** contenu pédagogique (catalogue, *Atlas*, *Passeport*, Recherche) ; captures d'écran de produits | Selon l'autorisation obtenue, enregistrée dans le manifeste | `pending-permission` → repli |
| **3 — Interdit** | Logo Microsoft ; lockups Microsoft 365 / Azure / Windows ; **badges et logos de certification** (Microsoft Certified, Microsoft Office Specialist, GitHub, AWS Certified, CompTIA…) ; imitations et recréations (ex. une tuile bleue « W ») ; toute icône ou tout logo tiers dans l'icône de l'app, ses métadonnées, captures et aperçus App Store, notifications, widgets, Live Activities, cartes de partage, publicité, site web | — | jamais |

**Conséquence assumée :** aujourd'hui, les certifications *Microsoft Office Specialist* (Word, Excel, PowerPoint, Outlook, Access), Teams, SharePoint, Windows et GitHub s'affichent avec le **repli** (§22A.11) tant qu'une autorisation écrite n'est pas enregistrée ; le jour où elle l'est, les vrais symboles apparaissent **sans changement de code** (mise à jour du manifeste).
**Certification :** toujours représentée par son **code et son intitulé officiels en texte** (« AZ-900 · Microsoft Azure Fundamentals ») + l'icône du produit si elle est autorisée ; **MUST NOT** créer un visuel CertiGo qui ressemble à un badge, une crête ou un sceau de certification (AWS interdit explicitement toute image qui « imite » ou « ressemble » à ses certifications). Une certification **obtenue par l'utilisateur** s'affiche dans le *Passeport* comme un **lien** vers sa page de vérification officielle (Credly, Accredible, Microsoft Learn…), jamais en intégrant l'image du badge.

### 22A.3 Sources officielles (les seules autorisées)
> Recherche du 22/10/2026 (annexes R8a et R8b, sources datées). Les versions évoluent : la revue trimestrielle (§22A.12) **MUST** revérifier chaque ligne avant import. Les citations sont courtes et en anglais, telles que publiées.

| Éditeur / famille | Source officielle (kit) | Niveau 1 — autorisé, contextes par défaut | Niveau 2 — sur autorisation écrite | Niveau 3 — interdit | Mentions |
|---|---|---|---|---|---|
| **Microsoft — Azure** | *Azure architecture icons* V24 (juillet 2026, SVG) — learn.microsoft.com/azure/architecture/icons | Icônes de services : `.diagram`, `.learningContent`. Conditions : « architectural diagrams, training materials, or documentation » ; ne pas recadrer, retourner, pivoter, déformer ; ne pas représenter son propre produit ; nom complet près de l'icône ; case « J'accepte » consignée | Mêmes icônes en `.catalog` / `.passport`. **Confirmation écrite recommandée même pour le niveau 1** : une autre page Microsoft exclut les icônes de produits « in software applications » | Logo Microsoft ; lockup « Microsoft Azure » ; badges *Microsoft Certified* | Mention de marque Microsoft ; non-affiliation ; « Used with permission from Microsoft. » si applicable |
| **Microsoft — Power Platform** | *Power Platform icons* (déc. 2025, SVG) — learn.microsoft.com/power-platform/guidance/icons | Copilot Studio, Dataverse, AI Builder, Power Fx, Power Platform : comme Azure | **Power BI, Power Apps, Power Automate, Power Pages** (aussi listés parmi les icônes d'applications Microsoft 365 soumises à licence) ; tout usage `.catalog` / `.passport` | Comme Azure | Comme Azure |
| **Microsoft — Dynamics 365** | *Dynamics 365 icons* (févr. 2026, SVG) — learn.microsoft.com/dynamics365/get-started/icons | Comme Azure | `.catalog` / `.passport` | Comme Azure | Comme Azure |
| **Microsoft — Fabric** | *Microsoft Fabric icons* (SVG) — learn.microsoft.com/fabric/fundamentals/icons | Comme Azure (la licence MIT du paquet npm couvre le fichier, pas la marque) | `.catalog` / `.passport` | Comme Azure | Comme Azure |
| **Microsoft — Entra** | *Microsoft Entra architecture icons* — learn.microsoft.com/entra/architecture/architecture-icons | Comme Azure ; en plus : **jamais** dans une communication marketing | `.catalog` / `.passport` | Comme Azure | Comme Azure |
| **Microsoft — sécurité** | Defender for Cloud, Microsoft Sentinel, Intune… : catégories « security » et « intune » du kit Azure | Comme Azure, avec les noms actuels (« Microsoft Sentinel ») | Icône d'application *Microsoft Defender* ; Purview (aucune icône officielle confirmée pour cet usage) | Comme Azure | Comme Azure |
| **Microsoft 365 — applications** | Aucun kit sous conditions couvrant une app ; *Microsoft 365 Trademark Guidelines* (juin 2026) | — | **Word, Excel, PowerPoint, Outlook, Access, Teams, SharePoint, OneDrive, Exchange, Copilot** : licence de marque requise | Logos Microsoft 365 ; badges et logos *Microsoft Office Specialist* (réservés aux distributeurs agréés Certiport) | « Microsoft » devant le nom à la première occurrence ; jamais « M365 » |
| **Windows / Windows Server** | Aucun kit ; *Windows Trademark Guidelines* (févr. 2026) | — | Symbole Windows (licence requise) | Logo Windows | Nom en texte |
| **GitHub** | *Primer Octicons* (SVG, MIT) — github.com/primer/octicons ; *GitHub Brand Toolkit* — brand.github.com | Octicons **non-logo** pour les concepts GitHub (branche, pull request, issue, workflow…) : `.diagram`, `.learningContent` | Invertocat, wordmark, lockups produits (GitHub Copilot…) ; glyphes `mark-github` et Copilot traités comme des logos | Badges de certification GitHub ; logo GitHub comme icône d'une offre | Mention de marque GitHub ; notice MIT des Octicons |
| **AWS** | *AWS Architecture Icons* (paquets trimestriels, fin janvier / avril / juillet) — aws.amazon.com/architecture/icons | Icônes de services : **`.diagram` uniquement** (« to create architecture diagrams ») ; version à jour ; jamais plus visibles que CertiGo | Les mêmes icônes hors schémas (cartes, *Atlas*, puces, en-têtes) | Logo AWS (usage tiers « plain text only (no logos) ») ; badges *AWS Certified* et **tout visuel qui les imite** | Formulation relationnelle (« … for Amazon S3 ») ; ligne de crédit |
| **Google Cloud** | *Google Cloud product icons* (SVG/PNG, refonte 2025) — cloud.google.com/icons | Icônes de produits : `.diagram`, `.learningContent` (schémas et « standard teaching materials », inchangées) | Logo Google Cloud ; icônes hors contenu pédagogique | Badges de certification Google Cloud | Noms selon la liste de marques Google, en adjectif ; « Google Cloud » plutôt que « GCP » |
| **Kubernetes / CNCF** | *Kubernetes Icons Set* (SVG/PNG, Apache-2.0 ou CC-BY-4.0) — github.com/kubernetes/community/tree/master/icons ; *CNCF artwork* — github.com/cncf/artwork | Icônes communautaires (Pod, Deployment, Service…) : `.diagram`, `.learningContent`, `.catalog`, avec crédit de licence | Logo Kubernetes, logos CNCF et projets (prise de contact préalable : brand@linuxfoundation.org ; le silence ne vaut pas accord) | Logos CKA / CKAD / KCNA… ; logo recoloré | « … is not affiliated with or otherwise sponsored by CNCF » ; ® / ™ à la première mention |
| **Cisco** | *Network Topology Icons* (EPS/JPG, Visio) — cisco.com/c/en/us/about/brand-center/network-topology-icons.html | Icônes de topologie : `.diagram`, `.learningContent` (« use them freely, but you may not alter them ») ; mode sombre : plaque claire, jamais de teinte | Conversion EPS → PDF/SVG à confirmer ; autres contextes | Logo Cisco ; logos de certification (interdits jusque dans les tests d'entraînement) | Mention de marque Cisco |
| **Python (PSF)** | *The Python Logo* — python.org/community/logos | Logo inchangé dans les leçons Python : `.learningContent` (usage nominatif) | Variante recolorée (mode sombre : plaque claire à la place) ; toute autre surface | Le logo comme logo de produit CertiGo | « "Python" and the Python Logo are trademarks of the PSF » ; non-affiliation |
| **Linux** | Pas de kit ; Tux (Larry Ewing) | Tux dans les leçons Linux, avec crédit : `.learningContent` ; **jamais** comme mascotte | — | « Linux » dans un nom de produit ou de parcours vendu sans sous-licence | « Linux® is the registered trademark of Linus Torvalds… » ; crédit Tux |
| **Docker · HashiCorp (Terraform) · OpenAI · Databricks · SAP · Oracle (OCI) · Salesforce · Snowflake** | Chartes et kits officiels de chaque éditeur (liens en annexe R8b) | — (seuls les **noms** s'utilisent librement, en texte) | Baleine Docker, « T » Terraform, logo OpenAI, icônes SAP BTP, boîte à outils OCI, icônes Salesforce… : demande d'autorisation (contacts en annexe R8b) | Badges et logos de certification ; logos d'entreprise sans accord | Mention propre à chaque éditeur (annexe R8b) |
| **Red Hat · CompTIA · ISC2** | Chartes de marque | — | — | **Tous les logos et badges.** Red Hat : aussi les identifiants de cours et d'examen (ex. EX200) dans une formation tierce, et avertissement sur chaque page qui cite ses marques ; ISC2 : prudence même en texte | CompTIA : toujours « CompTIA Security+ » ; ISC2 : « CISSP® » |
| **Agrégateurs** (Simple Icons, Devicon, Iconify, polices d'icônes) | — | — | — | **Jamais comme source** : redessins monochromes, aucun droit de marque, plusieurs marques retirées à la demande des éditeurs | — |

**Règles d'approvisionnement :**
- **MUST** télécharger depuis la page officielle de l'éditeur listée ci-dessus (ou celle qui la remplace sur le même domaine), au format vectoriel (SVG de préférence), dans sa **dernière version**.
- **MUST** archiver une copie datée des conditions d'usage dans `docs/legal/brand-terms/<kit>-<AAAA-MM-JJ>.pdf` (ou `.html`) ; si la page impose une case « J'accepte », consigner **qui** l'a cochée et **quand** (le propriétaire, pas l'agent).
- **MUST NOT** utiliser d'agrégateurs ou de copies non officielles comme source : Simple Icons, Devicon, Iconify, polices d'icônes, miroirs GitHub tiers, captures d'écran du portail ou de la console, images générées par IA, icônes redessinées.
- **MUST NOT** importer un kit complet : seules les icônes référencées par le registre (§22A.4) entrent dans le bundle.
- Si l'agent n'a pas d'accès réseau, il **MUST** produire la liste exacte des fichiers nécessaires (kit, version, chemin dans le kit, nom de fichier) ; le propriétaire dépose les archives dans `brand-assets/inbox/` (ignoré par la build et par Git).

### 22A.4 Architecture technique
```
content/brands/registry.yaml                 ← référentiel : éditeurs, produits, noms officiels, alias, icône
apps/apple/CertigoKit/Sources/BrandAssets/
├─ Resources/BrandAssets.xcassets            ← un dossier par kit (ex. Azure-V24/), noms de fichiers d'origine
│                                               Single Scale · Preserve Vector Data · Render As : Original Image
├─ Resources/brand-manifest.json             ← provenance, conditions, contextes autorisés, empreinte, statut
└─ BrandRegistry.swift                       ← BrandProductID ; résolution produit + contexte → icône ou repli
apps/apple/CertigoKit/Sources/Prism/Brand/
├─ BrandIcon.swift                           ← rend l'icône officielle sans aucune modification
├─ BrandLabel.swift                          ← icône + nom officiel (composant par défaut)
├─ BrandFallbackMark.swift                   ← repli neutre CertiGo (jamais une imitation)
└─ BrandNoticesView.swift                    ← écran « Marques et mentions légales »
docs/legal/brand-terms/                      ← copies datées des conditions ; autorisations écrites reçues
docs/legal/BRAND_ASSETS_CHANGELOG.md         ← imports, mises à jour, retraits, autorisations
THIRD_PARTY_NOTICES.md                       ← section « Marques, icônes et logos » (+ licence MIT des Octicons si utilisés)
```

**Registre (`content/brands/registry.yaml`, validé en CI) — exemple :**
```yaml
vendors:
  - id: microsoft
    name: Microsoft
    notice: "<mention de marque officielle, copiée de la page de l'éditeur>"
products:
  - id: azure.virtual-machines
    vendor: microsoft
    officialName: Azure Virtual Machines      # orthographe exacte, jamais traduite
    aliases: [VM Azure, machines virtuelles Azure]
    icon: azure-v24/compute/virtual-machines  # identifiant dans BrandAssets (statut lu dans le manifeste)
  - id: m365.word
    vendor: microsoft
    officialName: Microsoft Word
    icon: null                                 # niveau 2 : pas d'autorisation écrite → repli
    fallbackReason: "Icône d'application Microsoft 365 : licence de marque requise (DR-010)"
```

**Manifeste (`brand-manifest.json`) — champs MUST par icône :** `iconId` · `vendor` · `tier` (1 / 2) · `kit` · `kitVersion` · `sourceUrl` · `fileInKit` · `downloadedAt` · `termsUrl` · `termsSnapshot` · `termsAcceptedBy` / `termsAcceptedAt` (si case à cocher) · `permissionEvidence` (chemin de l'autorisation écrite, niveau 2) · `permittedContexts` (§22A.5) · `constraints` (taille minimale, zone de protection, fond, variante sombre) · `attribution` · `sha256` · `status` (`approved` / `pending-permission` / `fallback` / `withdrawn`) · `verifiedAt` · `verifiedBy`.

**Contenu (extension additive du schéma, coordonnée avec le validateur et le backend) :** champ optionnel `products: [<id du registre>]` sur les leçons, cartes, *Situations* et *Concepts* ; champ optionnel `product` sur chaque nœud de `DiagramSpec`. Le client ne devine jamais un produit à partir du texte : le lien est **explicite**. Les alias servent uniquement aux outils (inventaire Phase 0, aide à l'auteur).

### 22A.5 Contextes d'usage et application automatique
`BrandIcon(product:context:)` reçoit **toujours** un contexte. `BrandRegistry` rend l'icône officielle seulement si l'icône est `approved` **et** que ce contexte figure dans ses `permittedContexts` ; sinon il rend `BrandFallbackMark`. Un **interrupteur distant par éditeur** (`brand.icons.<vendor>`, en plus du flag global `brand.icons.v1`) bascule instantanément un éditeur en repli si un ayant droit le demande.

| Contexte | Surfaces | Règle par défaut |
|---|---|---|
| `.diagram` | `DiagramView` (architecture, flux, topologies) | **MUST** (niveau 1) : chaque nœud qui représente un service réel porte son icône officielle et son nom, comme les schémas d'architecture officiels |
| `.learningContent` | Cartes *Apprendre*, *Situations* (y compris la *Situation de découverte* du premier lancement), en-tête d'`ArtifactView`, feedback, explications, page *Concept*, glossaire | **MUST** (niveau 1) : `BrandLabel` du ou des produits concernés |
| `.catalog` | *Atlas* (nœuds rattachés à un produit), *Objectifs* / catalogue de certifications, Recherche, page *Route* | **Repli par défaut** (niveau 2) ; icône officielle dès que le manifeste l'autorise (autorisation écrite de l'éditeur, ou licence explicite comme MIT) — alors : icône + nom officiel + code d'examen en texte ; la couleur de région reste sur le cadre, jamais sur l'icône |
| `.passport` | *Passeport*, historique | **Repli par défaut** (niveau 2) ; même si autorisé : simple référence dans une ligne, **jamais** une composition qui ressemble à un badge officiel |
| — (interdit) | Écrans d'accueil et de choix du premier lancement, paywall, notifications, widgets, Live Activities, Spotlight / App Intents, cartes de partage, icône de l'app, écran de lancement, logo CertiGo, *Facette*, `PrismCelebration`, App Store, publicité | **MUST NOT** (niveau 3) : glyphes CertiGo + nom en texte |

### 22A.6 Règles de rendu (non négociables)
**MUST :**
- Asset catalog : *Single Scale*, *Preserve Vector Data*, **Render As : Original Image** (`template-rendering-intent: original`) ; en SwiftUI : `.renderingMode(.original)`, `.resizable()`, `.scaledToFit()`. Utiliser la **variante sombre officielle** si le kit en fournit une.
- Tailles uniquement via `PrismSize.brandS` (20 pt) · `brandM` (28 pt) · `brandL` (40 pt) ; `brandXL` (56 pt) réservé aux schémas en plein écran ; jamais sous la taille minimale du kit.
- Présenter l'icône sur une **plaque neutre** Prism (`PrismColor.brandPlate`) : **claire dans les deux modes** (légèrement atténuée en mode sombre), plaque sombre uniquement avec la variante sombre officielle d'un kit ; bordure renforcée en Increase Contrast ; zone de protection ≥ 25 % de la taille de l'icône et au moins la taille minimale de l'éditeur (ex. Docker : 24 px).
- Placer **à côté** de l'icône (jamais dessus) tout indicateur CertiGo : état du concept, coche, profondeur, cadenas.
- Comparaisons multi-éditeurs : même taille, même plaque, même traitement, aucun ordre de préférence implicite.
- Si CoreSVG rend mal un fichier : conversion PDF **sans aucun changement visuel**, consignée dans le manifeste (empreinte de l'original **et** du fichier converti) et signalée dans DR-010.

**MUST NOT :**
- Teinter (accent Indigo, couleur de région ou autre) ; appliquer à l'icône `.renderingMode(.template)`, `.foregroundStyle`, `.tint`, `.colorMultiply`, `.hueRotation`, `.saturation`, `.grayscale`, `.colorInvert`, `.blendMode`, `.mask`, `.clipShape`, `.rotationEffect`, `.rotation3DEffect`, `.scaleEffect` non uniforme, `.blur`, `.shadow`, `.glassEffect` ou tout matériau.
- Recadrer, retourner, déformer, contourer, animer les formes internes, ajouter un reflet, une étincelle ou un dégradé ; combiner une icône d'éditeur avec le logo CertiGo ou avec l'icône d'un autre éditeur en un seul visuel.
- Signaler un état (désactivé, verrouillé, non commencé) en **altérant l'icône** : l'état est porté par le texte et un glyphe CertiGo placé à côté.
- Utiliser une icône d'éditeur comme élément d'interface (bouton, onglet, contrôle, indicateur de navigation) : l'interface reste en SF Symbols et glyphes CertiGo (§22).
- Redessiner, vectoriser soi-même, « harmoniser » ou styliser les icônes de différents éditeurs pour qu'elles se ressemblent ; imiter l'**habillage** d'un éditeur (ses couleurs de marque, la forme de ses icônes) dans un visuel CertiGo.
- Intégrer des **captures d'écran** du portail, d'une console ou d'une application d'éditeur dans l'interface : les artefacts et schémas sont recomposés nativement (`ArtifactView`, `DiagramView`).
- Charger une icône à l'exécution depuis un serveur d'éditeur ou un CDN tiers.

### 22A.7 Noms, mentions légales, non-affiliation et App Store
- **Noms officiels exacts** (registre), non traduits, employés comme qualificatifs (« le service Amazon S3 ») ; « Microsoft » devant le nom des applications à la première occurrence ; jamais « M365 » ; « GitHub » en un mot ; « Google Cloud » plutôt que « GCP » ; « Oracle Cloud Infrastructure (OCI) » à la première mention ; « CompTIA Security+ », jamais « Security+ » ; ® / ™ à la première mention quand l'éditeur l'exige (Linux Foundation, PSF, Red Hat, ISC2…) ; Red Hat : aucun identifiant de cours ou d'examen et avertissement sur chaque page concernée.
- **Titres CertiGo en formulation relationnelle** : « Préparer l'examen AZ-900 — Microsoft Azure Fundamentals », « … pour Amazon S3 » ; jamais une marque d'éditeur en tête d'un titre comme s'il s'agissait d'un produit CertiGo ; aucun nom d'éditeur dans le nom de l'app, d'un achat intégré ou d'une offre. Une description localisée MAY suivre (« Azure Virtual Machines — machines virtuelles à la demande »). Renommages suivis (ex. *Azure Active Directory* → *Microsoft Entra ID*), l'ancien nom restant en alias.
- Écran **Profil › À propos › Marques et mentions légales** (`BrandNoticesView`) : pour chaque éditeur présent dans le bundle, sa mention de marque officielle, le kit, sa version, le lien vers ses conditions, et la phrase de non-affiliation :
  > « CertiGo est une application indépendante. Elle n'est ni affiliée à, ni autorisée, sponsorisée ou approuvée par les éditeurs cités, dont Microsoft Corporation et GitHub, Inc. Les noms, icônes et logos de produits appartiennent à leurs propriétaires respectifs et ne sont utilisés que pour identifier leurs produits. »
  suivie des mentions de marque des éditeurs (modèle Microsoft : « Microsoft, Azure, … sont des marques du groupe de sociétés Microsoft. » ; « Toutes les autres marques appartiennent à leurs propriétaires respectifs. »), de la licence MIT des Octicons si elles sont utilisées, et de « Used with permission from Microsoft. » si un contenu relève des règles de permission de Microsoft.
- La même mention **MUST** figurer dans `THIRD_PARTY_NOTICES.md` et en fin de description App Store.
- **App Store :** **MUST NOT** de marque, d'icône ou de logo tiers dans le nom de l'app, le sous-titre, le nom du développeur, l'icône (y compris les icônes alternatives), les captures, les aperçus vidéo et les visuels d'événements ; les captures sont produites avec un jeu de contenu **sans icône d'éditeur** (flag `brand.icons.v1` OFF ou mode capture dédié). Les éditeurs et codes d'examen n'apparaissent que dans la **description**, de façon exacte ; mots-clés rares et exacts (App Store Review Guidelines 2.3.7, 2.3.9, 4.1, 5.2). Les **notes pour App Review** listent où les icônes apparaissent, avec les URL des conditions et les autorisations écrites reçues.

### 22A.8 Accessibilité
- `BrandLabel` = **un seul** élément VoiceOver qui lit le nom officiel ; l'icône y est `accessibilityHidden(true)`.
- `BrandIcon` seul (nœud de schéma dense) : `accessibilityLabel(officialName)` + trait image ; le schéma garde sa description textuelle structurée (§23).
- Taille pilotée par `@ScaledMetric` bornée ; aux tailles d'accessibilité, l'icône passe au-dessus du nom (`ViewThatFits` / `AnyLayout`).
- `accessibilityIgnoresInvertColors(true)` sur l'icône (Smart Invert ne doit pas inverser les couleurs officielles) ; plaque à bordure renforcée en Increase Contrast ; la couleur d'une icône n'est jamais le seul porteur d'information.

### 22A.9 Performance et taille
- Uniquement les icônes référencées ; vectoriel ; **budget initial ≤ 2 Mo** pour `BrandAssets` (mesuré en 2B ; dépassement → Decision Request). Pour mémoire, les archives Power Platform et Dynamics 365 complètes pèsent environ 160–180 Ko chacune.
- Défilement de l'*Atlas* et des listes sans à-coup : rendu à la taille d'affichage, mis en cache ; aucun décodage coûteux sur le thread principal pendant le défilement (vérifié avec Instruments).
- Pas de téléchargement dynamique en v1 ; si un jour les icônes doivent changer sans mise à jour de l'app : Background Assets (On-Demand Resources est une technologie héritée), par Decision Request.

### 22A.10 Garde-fous automatisés (MUST, étape 2B, exécutés en CI)
`BrandAssetsTests` + extension du validateur de contenu :
1. **Complétude :** chaque image de `BrandAssets.xcassets` a une entrée de manifeste complète, et réciproquement ; chaque image est en *Original Image*.
2. **Intégrité :** l'empreinte SHA-256 du fichier stocké = celle du manifeste = celle du fichier du kit → toute modification fait échouer le CI.
3. **Couverture :** chaque `product` cité dans `content/` existe dans le registre et possède une icône `approved` **ou** un repli documenté (raison, date, DR) ; le CI publie un rapport de couverture (produits cités · avec icône officielle · en repli, par éditeur, par niveau et par contexte).
4. **Lint Swift :** aucune image de `BrandAssets` affichée hors de `BrandIcon` ; aucun modificateur interdit (§22A.6) appliqué à `BrandIcon` / `BrandLabel` ; aucun actif tiers dans `AppIcon`, l'écran de lancement, `ShareCardRenderer`, `PrismCelebration`, les extensions (widgets, Live Activities, notifications).
5. **Rendu :** snapshots de `BrandLabel` (clair, sombre, Increase Contrast, AX3) pour au moins une icône par kit ; test de non-teinte (pixels de l'icône identiques au rendu de référence du fichier original).
6. **Fraîcheur :** avertissement CI si une entrée n'a pas été revérifiée depuis plus de 90 jours (revue trimestrielle, §22A.12).

### 22A.11 Repli quand aucune icône autorisée n'existe
- `BrandFallbackMark` : plaque neutre CertiGo avec le **nom officiel en texte** et, si utile, le **glyphe de région** CertiGo (cloud, IA, données, sécurité…) — **jamais** une évocation de la forme ou des couleurs de marque de l'éditeur.
- Le repli est consigné dans le registre (`fallbackReason`, date, DR) et réévalué à chaque revue.
- **Demandes d'autorisation :** l'agent MAY préparer les textes (Microsoft : trademarks@microsoft.com ; GitHub : contact de la page des logos ; autres éditeurs : contact indiqué sur leur page de marque) ; **seul le propriétaire les envoie** ; toute réponse est archivée dans `docs/legal/brand-terms/` et citée dans `permissionEvidence`.

### 22A.12 Maintenance
- **Revue trimestrielle** : versions des kits (Azure publie plusieurs mises à jour par an), icônes renommées ou retirées, noms de produits, conditions d'usage ; résultat dans `BRAND_ASSETS_CHANGELOG.md`.
- Toute nouvelle icône arrive avec une mise à jour de l'app ; un retrait demandé par un ayant droit est appliqué **sous 48 h** par l'interrupteur distant de l'éditeur, puis confirmé par une mise à jour.

### 22A.13 Critères d'acceptation (Given / When / Then)
- *Given* le registre et le contenu, *when* le validateur s'exécute, *then* 100 % des produits cités ont une icône `approved` ou un repli documenté, et le rapport de couverture est publié.
- *Given* une icône quelconque de `BrandAssets`, *when* `BrandAssetsTests` s'exécute, *then* son SHA-256 correspond au fichier du kit et son manifeste contient source, version du kit, date, conditions archivées, niveau et contextes autorisés.
- *Given* une *Situation* dont le schéma contient une machine virtuelle, un réseau virtuel et un équilibreur de charge Azure, *when* il s'affiche, *then* chaque nœud porte l'icône officielle Azure correspondante et son nom, et VoiceOver lit les noms officiels.
- *Given* la route AZ-900 dans *Objectifs* sans autorisation `.catalog`, *when* la carte s'affiche, *then* elle montre `BrandFallbackMark` (glyphe de région + « Microsoft Azure ») et « AZ-900 · Microsoft Azure Fundamentals » en texte, **sans** badge ni crête ; *and when* l'autorisation est enregistrée dans le manifeste, *then* l'icône officielle Azure apparaît sans changement de code.
- *Given* une leçon *Microsoft Office Specialist : Excel* sans licence de marque, *when* elle s'affiche, *then* aucune icône Excel n'apparaît ; le repli affiche « Microsoft Excel » en texte.
- *Given* le mode sombre + Increase Contrast + Smart Invert, *when* `BrandLabel` s'affiche, *then* l'icône garde ses couleurs officielles sur sa plaque, le nom respecte 4,5:1 et VoiceOver ne lit le nom qu'une fois.
- *Given* l'interrupteur distant `brand.icons.<vendor>` passé à OFF, *when* l'app se rafraîchit, *then* toutes les icônes de cet éditeur passent en repli, sans plantage ni trou visuel.
- *Given* Profil › À propos, *when* l'utilisateur ouvre « Marques et mentions légales », *then* chaque éditeur présent dans le bundle y figure avec sa mention, son kit, sa version et le lien vers ses conditions.

---

## 23. ILLUSTRATION RULES
- Aucun personnage, aucune mascotte (sauf décision ultérieure).
- Illustrations **géométriques abstraites** (facettes, lumière) en vectoriel ou formes SwiftUI, réservées aux états vides, à l'accueil et aux célébrations ; jamais sur un écran de question.
- Schémas techniques **dessinés nativement** à partir d'une spécification de données (`DiagramSpec` : nœuds, liens, groupes, étiquettes) + description textuelle structurée ; **jamais** d'image générée par IA pour un schéma ; pas de photos d'illustration.
- Schémas : chaque nœud qui représente un service réel porte son **icône officielle** et son nom (§22A), comme les schémas d'architecture officiels des éditeurs.

---

## 24. SURFACES
- Contenu sur surfaces **opaques** (`surface`, `surfaceArtifact`) ; séparation par contraste de surface, pas par ombres.
- **Liquid Glass** (`glassEffect`, `GlassEffectContainer`, variante *regular* derrière du texte) **uniquement** pour : tab bar, toolbars, accessoire « Séance en cours », contrôle flottant Vérifier si nécessaire. Test : aucun effet de verre sur une vue de contenu.
- Rayons : puces `s`, champs `m`, cartes `l`, cartes héros / feuilles `xl`, boutons secondaires capsule ; coins continus.
- Élévation : ombre douce uniquement pour la carte héros de Séance en mode clair.
- Reduce Transparency : tout verre personnalisé MUST basculer sur une surface opaque.

---

## 25. MOTION
| Jeton | Valeur indicative | Usage | Reduce Motion |
|---|---|---|---|
| `quick` | ~0,15 s ease-out | Feedback de sélection, statut | Opacité seule |
| `snappy` | ressort ~0,3 s sans rebond | Passage carte → feedback, apparition d'options | Fondu 0,2 s |
| `smooth` | ressort ~0,45 s | Continuité (concept → Atlas) | Fondu 0,2 s |
| `expressive` | keyframes ≤ 1,2 s | Réfraction (niveaux 2–3) | Fondu + éclat statique ≤ 0,3 s |
MUST : chaque animation a une fonction documentée (orientation, feedback, continuité, célébration) ; une animation à la fois ; aucune boucle sur un écran au repos (`TimelineView` suspendue hors écran) ; aucune parallaxe, rotation continue, flou animé ; célébration touchable pour passer ; résolution via `PrismMotion.resolve(token, reduceMotion:)`.
**DO NOT ADD ANIMATION WITHOUT PURPOSE.**

---

## 26. HAPTICS
| Jeton | Implémentation | Quand |
|---|---|---|
| `selection` | `.sensoryFeedback(.selection, trigger:)` | Choix d'option, sélection de ligne, jeton posé |
| `correct` | `.sensoryFeedback(.success, trigger:)` | Réponse correcte, séance terminée |
| `incorrectSoft` | `.sensoryFeedback(.impact(weight: .light), trigger:)` | Réponse incorrecte (**jamais** `.error`) |
| `warning` | `.sensoryFeedback(.warning, trigger:)` | Action destructive uniquement |
| `declic` | Core Haptics (motif court : deux transitoires, la seconde plus intense) avec repli `.success` | Célébrations niveaux 2–3 |
MUST : réglage in-app « Haptique » (défaut activé, respecte le réglage système) ; haptique jamais seule porteuse d'information ; chaque son a une haptique correspondante. **Son** : `AVAudioSession` catégorie `.ambient` (respecte le mode silencieux), réglage « Sons », ≤ 600 ms pour le motif Déclic.

---

## 27. IOS REQUIREMENTS
**MUST**
- SwiftUI natif, composants système (`TabView`, `NavigationStack`, toolbars, sheets, menus, `ContentUnavailableView`) ; aucune tab bar personnalisée.
- Liquid Glass limité à la navigation (§24) ; légibilité vérifiée avec Reduce Transparency, Increase Contrast et le curseur de transparence d'iOS 27.
- `#available` pour toute API iOS 26+/27 tant que la cible reste iOS 17 (DR-002 recommande iOS 26 minimum à la prochaine version majeure).
- WidgetKit : W-1, W-2, W-3 (interactif via App Intents) ; modes teinté / clair ; budgets de rechargement respectés ; App Group pour les données partagées.
- App Intents : `StartSessionIntent(length)`, `OpenDailySituationIntent`, `ReviewTopicIntent(topic)`, `OpenConceptIntent(concept)` ; entités `ConceptEntity`, `RouteEntity` indexées dans Spotlight ; App Shortcuts localisés (8 langues).
- Notifications : demande d'autorisation **après** la 1re séance (provisoire possible) ; niveaux *passive* (rappels), *active* (événement social choisi), *timeSensitive* (jour d'examen uniquement) ; aucune notification marketing sans opt-in ; regroupement par fil.
- StoreKit 2 (`SubscriptionStoreView`, restauration, gestion système, essai avec rappel) — Phase 10.
- Sign in with Apple / passkeys via la fédération CIAM existante ; MSAL préservé.
- Foundation Models : vérification de disponibilité à l'exécution, conception pour 4 096 tokens, repli systématique.
- Adaptativité : tailles de classe, marges système, aucune largeur fixe ; `sidebarAdaptable` ; test sur iPad et iPhone Duo (simulateur).
- Confidentialité : manifeste de confidentialité à jour, étiquettes App Store exactes, consentement IA nommant le fournisseur, suppression du compte préservée.
**SHOULD** — Live Activities LA-1/2/3 (ActivityKit, fin définie), contrôle Centre de contrôle CC-1, SpeechAnalyzer pour `explain` (audio jamais conservé), Translation (glossaire), Background Assets / tâche continue pour les packs, Private Cloud Compute (iOS 27, si éligible), Declared Age Range.
**MAY** — SharePlay, Visual Intelligence, App Clip (Situation partagée), Apple Watch (phase ultérieure).
**MUST NOT** — publicité ou promotion dans une Live Activity, un widget ou une notification ; Game Center comme couche sociale principale ; Image Playground pour des schémas.

---

## 28. ACCESSIBILITY
Objectif : chaque **tâche courante** (premier lancement, connexion, séance, Situation du jour, objectif, réglages, achat) réalisable avec chacune des fonctions ci-dessous → éligibilité aux **Accessibility Nutrition Labels** correspondants.
| Exigence | Critère testable |
|---|---|
| Dynamic Type | Tous les écrans à `accessibility5` sans troncature d'énoncé ni chevauchement ; texte agrandissable ≥ 200 % |
| VoiceOver | 100 % des contrôles libellés ; ordre de lecture logique ; artefacts lisibles ligne par ligne (rotor « Lignes ») ; schémas avec description structurée ; correct / incorrect annoncés ; célébrations annoncées une fois |
| Voice Control | Libellés visibles = libellés d'accessibilité (`accessibilityInputLabels` si besoin) |
| Full Keyboard Access / Switch Control | Séance complète réalisable ; ordre de focus logique |
| Differentiate Without Color | Symbole + mot pour tout statut ; motifs dans les graphiques |
| Increase Contrast | Variantes HC (≥ 7:1 visées) ; bordures de cartes renforcées |
| Reduce Motion | Toutes les animations ont leur variante (§25) ; aucun auto-défilement |
| Reduce Transparency | Verre personnalisé → opaque |
| Cibles | ≥ 44 × 44 pt ; espacement suffisant entre options |
| Temps | Aucun délai imposé hors examen blanc ; examen blanc avec temps majoré / sans limite |
| Médias | Sous-titres / transcriptions pour tout audio ou vidéo ; mode audio (lecture des explications) SHOULD |
| Gestes | Toute interaction de glisser a une alternative tap et une action personnalisée |
| Mode Calme | Réglage qui plafonne les célébrations au niveau 1 |
Vérification par phase : `performAccessibilityAudit()` sur chaque écran touché (0 erreur), parcours VoiceOver documenté, captures AX3 / AX5.

---

## 29. LOADING / EMPTY / ERROR / OFFLINE
Chaque écran de l'inventaire MUST implémenter ces états avec les composants Prism (Bible §15.10) :
| État | Règle | Composant |
|---|---|---|
| Chargement | Squelette fidèle à la mise en page ; > 1 s : astuce d'apprentissage ; jamais de spinner plein écran sur Aujourd'hui | `PrismSkeleton` |
| Vide | Une ligne de valeur + une action | `PrismEmptyState` |
| Erreur | Explique sans blâmer, action « Réessayer », réponses de l'apprenant rassurées (« tes réponses sont en sécurité »), code technique masqué et copiable | `PrismErrorState` |
| Hors ligne | Bandeau discret + ce qui reste possible ; séances en cache jouables ; synchronisation automatique et idempotente | `PrismOfflineBanner` |
| IA indisponible | Repli silencieux vers l'explication auteur, mention discrète | `FeedbackPanel` (variante) |
| Contenu non pris en charge | « Ce format arrive bientôt » + passage | `PrismEmptyState` compact |
| Invité | Fonctionnalités complètes ; invitation douce à sauvegarder | `PrismToast` |
MUST NOT : données fictives présentées comme réelles ; mode Démo en production.

---

## 30. PERFORMANCE
| Budget | Valeur | Mesure |
|---|---|---|
| Lancement à froid → première frame | Pas de régression > 10 % vs baseline Phase 0 ; cible ≤ 400 ms sur l'appareil de référence | `XCTApplicationLaunchMetric`, Instruments App Launch |
| Aujourd'hui interactif | ≤ 500 ms après le lancement avec cache ; contenu en cache affiché avant réseau | Signposts |
| Transition carte → carte | ≤ 100 ms | `XCTOSSignpostMetric` |
| Feedback après Vérifier | ≤ 300 ms perçu (état « vérification » au-delà) ; ≤ 1 s p95 serveur | Signposts + télémétrie |
| Défilement Aujourd'hui / Atlas | Aucun hitch > 1 frame en usage nominal ; taux de hitch < 5 ms/s | Instruments Hitches |
| Atlas | 60 i/s (120 sur ProMotion) avec ≤ 500 nœuds visibles ; niveaux de détail | Instruments |
| Mémoire | < 200 Mo en usage typique | Xcode Memory |
| Taille de l'app | < 60 Mo téléchargés hors packs ; packs via Background Assets | App Store Connect |
| Énergie | Aucune animation ni minuterie actives au repos | Instruments Energy |
| IA | p95 ≤ 2,5 s sinon repli | Télémétrie |
Les écarts sont des défauts bloquants de la porte PERFORMANCE CHECK.

---

## 31. ANALYTICS
- **Principes :** apprentissage d'abord, vie privée d'abord ; aucune donnée personnelle dans les événements ; consentement explicite (UE) ; aucun SDK publicitaire ni suivi inter-apps ; pipeline via le backend existant (conteneur `events`) ou outil validé par DR-008 ; protocole `AnalyticsClient` dans `CertigoDomain`, implémentation par lot avec file hors ligne ; journal Debug.
- **Taxonomie (noms normatifs, `snake_case`) :**
  - Cycle de vie : `app_opened{source: icon|widget|notification|intent|spotlight|link}`, `onboarding_step_viewed{step}`, `onboarding_completed{duration_s}`, `taste_completed{correct, duration_s}`, `account_created{provider}`.
  - Séance : `session_started{length, entry}`, `card_viewed{kind, concept_id}`, `item_presented{format, concept_id, rung, difficulty}`, `item_answered{correct, confidence, latency_ms, attempt, hint_used}`, `feedback_viewed{dwell_ms, variant}`, `skip_test_used{passed}`, `session_completed{length, duration_s, items, correct_rate, concepts_anchored, misconceptions_resolved}`, `session_abandoned{at_index}`, `item_format_unsupported{format}`.
  - Apprentissage : `concept_state_changed{from, to, concept_id}` (émis par le serveur), `misconception_detected{id}`, `knowledge_update_viewed{concept_id}`.
  - Rituels : `daily_situation_opened`, `daily_situation_completed{correct, confidence}`, `community_distribution_viewed`, `share_card_created{type}`, `share_card_shared{type}`.
  - Objectifs : `goal_set{type, exam_date_set}`, `readiness_viewed{band}`, `mock_exam_started{route}`, `mock_exam_completed{band, timed}`, `exam_outcome_reported{outcome, band_at_exam}`.
  - Habitude : `rhythm_day_completed`, `rhythm_week_completed`, `reminder_scheduled{time_bucket, cue}`, `notification_opened{type}`, `notification_permission{status}`.
  - Social : `squad_created`, `squad_joined{method}`, `kudos_sent`, `challenge_sent`, `challenge_completed{result}`, `privacy_setting_changed{setting}`.
  - IA : `ai_requested{surface, route: device|pcc|server|author}`, `ai_fallback{from, reason}`, `ai_feedback{helpful}`, `ai_reported`, `ai_consent{status}`.
  - iOS : `widget_interaction{kind}`, `intent_invoked{intent}`, `live_activity_started{kind}`.
  - Monétisation : `paywall_viewed{trigger}`, `purchase_started{product}`, `purchase_completed{product}`, `purchase_cancelled{product}`.
  - Qualité : `error_shown{code, screen}`, `offline_mode_entered`, `content_issue_reported{item_id}`.
- **Métriques calculées (serveur) :** WDL (North Star), gains durables / utilisateur / semaine, précision des rappels différés, efficacité d'apprentissage, calibration (Brier), semaines de Rythme, rétention D1 / D7 / D30 / W4, garde-fous (Bible §2.3).
- MUST : chaque événement documenté dans `docs/transformation/analytics.md` (nom, déclencheur, propriétés, écran, phase) ; test qui vérifie l'émission des événements des parcours critiques en Debug.

---
## 32. TESTING

### 32.1 Pyramide de tests
| Niveau | Outil | Portée | Seuil (MUST) |
|---|---|---|---|
| Unitaires | **Swift Testing** (`import Testing`) ; XCTest toléré pour l'existant | Logique de présentation, composition de séance côté client, mapping des états de maîtrise, calcul d'affichage du Rythme, formatage, décodage des DTO | Toute nouvelle logique a ses tests ; ≥ 80 % de lignes couvertes dans les nouveaux modules |
| Contrats | Fixtures JSON versionnées (`CertigoKit/Tests/Fixtures/`) | Décodage de chaque DTO consommé ; tolérance aux champs additionnels ; champs optionnels absents | 100 % des endpoints consommés |
| Architecture | Tests Swift qui lisent les sources (§38.2) | Valeurs brutes hors Prism, imports interdits, `print` en production, chaînes non localisées | **0 violation** dans les modules migrés |
| Snapshots | Outil validé par DR-007 (défaut : rendu `ImageRenderer` + comparaison PNG maison, sans dépendance) | Chaque composant Prism et chaque écran North Star : clair / sombre ; Dynamic Type `.large` et `.accessibility3` ; Increase Contrast ; fr + en + de | Toute différence est revue et justifiée dans le rapport de phase |
| UI | XCUITest | Parcours critiques (§32.2) + `performAccessibilityAudit()` sur chaque écran atteint | 100 % des parcours critiques verts |
| Performance | XCTest metrics (`XCTApplicationLaunchMetric`, `XCTOSSignpostMetric`, `XCTClockMetric`), Instruments | Lancement, transitions de séance, défilement Aujourd'hui / Atlas, rendu Atlas | Budgets du §30 respectés ; aucune régression > 10 % vs baseline Phase 0 |
| Backend | `dotnet test` | Suites existantes + tout endpoint ajouté ou étendu | 100 % vert ; contrats additifs uniquement |
| Contenu | `node tools/validate_content.mjs` + schémas | Nouveaux formats d'exercice et métadonnées | 100 % vert |

### 32.2 Parcours critiques (XCUITest, MUST à partir de la phase qui les introduit)
1. Premier lancement → Situation de découverte → objectif → Aujourd'hui.
2. Démarrer une séance Express → répondre (correct, incorrect) → feedback → résultats.
3. Situation du jour → révélation → distribution de la communauté → carte de partage.
4. Séance hors ligne → reconnexion → synchronisation sans doublon (idempotence).
5. Changer d'objectif (confirmation serveur) → Aujourd'hui recomposé.
6. Atlas → concept → « Pratiquer 1 min ».
7. Examen blanc chronométré → débrief.
8. Réglages → rappels → suppression du compte (jusqu'à la confirmation, sans l'exécuter en test de production).

### 32.3 Règles
- **MUST** écrire les tests de caractérisation **avant** de modifier un comportement existant (ils prouvent que rien ne casse).
- **MUST NOT** supprimer, désactiver ou affaiblir un test existant pour faire passer une phase. Un test obsolète se supprime uniquement via une Decision Request approuvée.
- **MUST NOT** marquer un travail terminé sans joindre au rapport : commande exécutée, nombre de tests, résultat, durée.
- **SHOULD** rendre chaque écran prévisualisable (`#Preview`) avec des données de fixture couvrant : nominal, vide, chargement, erreur, hors ligne, texte long, AX3.

---

## 33. PRESERVE / IMPROVE / REMOVE / ADD

> Les éléments « REMOVE » sont retirés **de l'interface** derrière flag ; le backend et les données restent intacts tant qu'une Decision Request n'a pas statué (aucune migration destructive).

### PRESERVE (ne pas casser, ne pas réécrire sans nécessité)
- Notation, récompenses, readiness, objectifs et achats **autoritatifs côté serveur** ; clé de correction jamais exposée (sauf décision DR-004).
- File de soumission idempotente, packs hors ligne, restauration de l'activité, `FileProtectionPolicy`, Keychain (`CredentialVault`), MSAL / CIAM, **suppression du compte**.
- Infrastructure de localisation (8 langues) et préférence de langue ; règle « le contenu officiel n'est pas traduit automatiquement ».
- Pipeline de contenu as code (schémas, validateur, CI) ; dates de vérification des sources ; refus des « dumps ».
- Moteurs serveur : FSRS / révision espacée, maîtrise, recommandation, mémoire des fausses idées, intégrité anti-triche.
- Le format **Atelier de décision** (devient *Situation*), la **Lecture guidée** (devient le mode *Plongée* éditorial), la promesse « Une question. Une idée plus claire. »
- Performances de lancement actuelles (base saine).

### IMPROVE
| Existant | Cible |
|---|---|
| Atelier de décision en 3 temps (Envoyer → En attente → Simuler l'explication) | *Situation* : choix → confiance (optionnelle) → **Vérifier** → feedback explicatif en un seul temps (≤ 1 s perçu) |
| Onglet `Apprendre` (`Mon apprentissage` / `Explorer`) | Onglets **Aujourd'hui** (séance, Situation du jour, Rythme, Mémoire, Objectif) et **Atlas** (carte, objectifs, catalogue, concepts) |
| Catalogue Explorer (codes, familles) | Atlas → Régions → Territoires → Concepts ; Objectifs (certifications et parcours de compétences) |
| Readiness 0–100 non calibré | **Préparation** fondée sur les preuves (couverture × maîtrise par objectif, nombre de preuves, incertitude) ; **Prévision** chiffrée seulement après calibration (§8) |
| Explications génériques | Explication + « pourquoi les autres options sont fausses » + fausse idée nommée + « Expliquer autrement » (IA ancrée) |
| Profil (aperçu, historique, réglages) | **Profil** : Passeport (preuves de compétence), Historique, Calibration, Réglages |
| Mode Démo omniprésent + avertissements dans chaque écran | **Mode Invité** avec contenu public réel ; mentions de provenance regroupées dans « À propos des données » + un badge discret ; Démo et connecteur de test **exclus des builds de production** |
| Notifications | Rappels choisis par l'utilisateur (heure + contexte), ton bienveillant, aucune culpabilisation |
| `NativeCertificationCrest` et visuels ad hoc | Composants Prism (`DomainGlyph`, `RouteBadge`) + **icône officielle** du produit (`BrandLabel`, §22A) ; aucun visuel imitant un badge |
| Monolithe `CertigoNativeApp.swift` | Fichiers par fonctionnalité + module `Prism` |

### REMOVE (de l'UI, derrière flag, après DR-005 / DR-006)
- Gemmes, boutique, réparation / gel de série payants.
- Ligues XP publiques à 10 paliers ; XP comme mesure principale de progrès ; niveaux génériques.
- Succès de volume (« Trésorier », « Érudit » fondé sur l'XP, etc.).
- Saisons mensuelles de type battle pass.
- Mascottes dérivées d'icônes Azure ; toute iconographie de marque tierce utilisée comme personnage.
- Toute représentation approximative d'un produit réel (SF Symbol générique, dessin maison, emoji, crête imitant un badge de certification) : remplacée par l'icône officielle ou le repli documenté (§22A).
- Notifications culpabilisantes (« Ne casse pas ta série », « Ta flamme va s'éteindre », « … compte sur toi »).
- L'onglet **Coach** en tant que destination de chat (ses capacités deviennent contextuelles).
- Onboarding long et paywall avant la première valeur.
- Section Développement / connecteur API de test dans les builds de production.

### ADD
- Onglets Aujourd'hui · Atlas · Ensemble · Profil (+ rôle Recherche sur iOS 26+).
- Séance adaptative 5 / 15 / 30–45 min ; composition à partir d'atomes ; reprise contextuelle.
- Formats natifs de la tech : `ArtifactView` (code, config, log, sortie CLI), Trouver l'erreur, Prédire, Ordonner (Parsons), Composer la commande, Compléter le schéma, Arbitrer, Expliquer (explain-it-back), Estimer, Diagnostiquer (triage), Classer.
- Échelle de confiance, révélation de la distribution, fausses idées, « Déclic ».
- Situation du jour (rituel quotidien, partage sans spoiler).
- Atlas (carte + liste accessible), page Concept, prévision mémoire, Préparation, Objectifs, Passeport.
- Rythme hebdomadaire (jours de repos inclus), jalons qui ont du sens, missions (≤ 3), célébrations « Réfraction ».
- Amis (privés par défaut), encouragements, Squads (objectif hebdo coopératif), défis asynchrones.
- IA contextuelle : Expliquer mon erreur, indices gradués, comparer deux concepts, plan d'étude, débrief d'examen, explain-it-back ; ancrée, citée, avec repli.
- Widgets (Aujourd'hui, Situation du jour, carte de révision interactive), Live Activity (examen blanc, Plongée), App Intents / Spotlight / Siri, Control Center, notifications respectueuses.
- Prism natif, flags de fonctionnalité, analytics produit, StoreKit 2 (offre Pro), Sign in with Apple / passkeys si absent.
- **Les vrais symboles des éditeurs** : bibliothèque `BrandAssets` (icônes officielles non modifiées, registre, manifeste de licences), `BrandLabel` partout où un produit est nommé, écran « Marques et mentions légales » (§22A, étape 2B).

---

## 34. MIGRATION ORDER

### 34.1 Phases (dans cet ordre, une à la fois)

| Phase | Objectif | MUST (périmètre) | MUST NOT | Flag(s) |
|---|---|---|---|---|
| **0 — Audit + baseline** | Photographie vérifiée, mapping Current → Target, plan | Voir `04_NEXT_IMPLEMENTATION_PHASE_PROMPT_PHASE-0.md` | Modifier un fichier existant | — |
| **1 — Prism foundations** | Socle du design system et de l'architecture | Correctif de baseline (DR-001) ; découpage du monolithe **sans changement de comportement** (tests de caractérisation d'abord) ; module `Prism` dans `CertigoKit` ; tokens §18 (couleurs, typo, espacements, rayons, matériaux, mouvement, haptique, son) ; tests d'architecture §38.2 ; infrastructure de flags (§36) ; outil de snapshot (DR-007) ; galerie Prism (Debug uniquement) | Changer un écran visible ; ajouter une fonctionnalité | `prism.enabled` (interne) |
| **2 — Core components** | Composants Prism fondamentaux et d'apprentissage | Composants §19 (fondation, apprentissage, progression, social, états) avec previews, snapshots, tests a11y ; aucune vue métier | Brancher les composants sur des écrans existants | — |
| **2B — Official brand assets** | Les vrais symboles des éditeurs, conformes et traçables | **DR-010 `APPROVED`** ; registre `content/brands/registry.yaml` construit à partir de `brand_references.csv` (Phase 0) ; acquisition des kits officiels du §22A.3 (ou dépôt par le propriétaire dans `brand-assets/inbox/` si l'agent n'a pas d'accès réseau) ; import des **seules** icônes référencées, **non modifiées** ; manifeste + copies datées des conditions ; `BrandRegistry` (contextes autorisés §22A.5), `BrandIcon`, `BrandLabel`, `BrandFallbackMark`, `BrandNoticesView` ; extension **additive** du schéma de contenu (`products`, `DiagramSpec.node.product`) + validateur ; garde-fous §22A.10 ; premiers branchements derrière flag : en-têtes des leçons et ateliers existants (`.learningContent`), cartes de certification actuelles (`.catalog` → repli tant qu'aucune autorisation n'est enregistrée ; remplacent `NativeCertificationCrest`), écran « Marques et mentions légales » ; textes de demande d'autorisation prêts pour le propriétaire | Modifier une icône ; afficher une icône de niveau 2 sans autorisation écrite, un badge de certification ou un logo d'entreprise ; source non officielle (agrégateur, capture, IA) ; chargement réseau d'icônes ; actif tiers dans l'icône de l'app, une extension ou une capture App Store | `brand.icons.v1`, `brand.icons.<vendor>` |
| **3 — Home / Today** | Nouvelle structure de navigation et Aujourd'hui | `TabView` cible (§12–13) derrière flag ; écran **Aujourd'hui** composé à partir des données existantes (plan, révision recommandée, objectif) ; sélecteur de durée ; états complets ; Atlas / Ensemble en version liste minimale | Supprimer l'ancienne navigation (elle reste accessible flag OFF) | `nav.v2`, `today.v2` |
| **4 — Learning experience** | Le lecteur de séance et les formats | Lecteur plein écran ; cartes Apprendre (concept, exemple travaillé, artefact, schéma) ; formats prioritaires : QCM + confiance, Situation, Trouver l'erreur, Ordonner, Composer la commande ; reprise contextuelle ; extensions de schéma de contenu **additives** coordonnées avec backend et validateur | Changer la logique de notation ; exposer une clé de correction | `session.v2` |
| **5 — Quiz / feedback / results** | Le cœur du « déclic » | Panneau de feedback (correct / incorrect / partiel, explication, options fausses, fausse idée) ; Résultats de séance ; **Situation du jour** (+ distribution si l'API la fournit, sinon DR) ; examen blanc + débrief | Ajouter des récompenses non validées | `feedback.v2`, `daily.situation` |
| **6 — Progress / Mastery / Readiness** | Rendre l'apprentissage visible et honnête | Atlas (liste accessible d'abord, puis carte) ; page Concept ; prévision mémoire ; Préparation par objectif ; Passeport ; historique et calibration | Afficher une probabilité de réussite non calibrée | `atlas.v1`, `readiness.v2` |
| **7 — Gamification** | Jeu au service de l'apprentissage | Rythme hebdomadaire ; jalons ; missions (≤ 3) ; célébrations « Réfraction » (3 niveaux) ; retrait UI des gemmes / boutique / ligues XP (DR-005) | Ajouter une monnaie, une boutique, une mécanique de perte | `rhythm.v1`, `celebrations.v1` |
| **8 — Social / collaborative / competitive** | Ensemble, sans pression | Amis privés par défaut ; encouragements ; Squads ; défis asynchrones ; distribution communautaire ; contrôles de confidentialité, blocage, signalement | Toute visibilité publique par défaut ; chat libre | `social.v2` |
| **9 — AI-native experience** | IA contextuelle et ancrée | Expliquer mon erreur ; indices gradués ; comparer ; plan ; débrief ; explain-it-back ; Foundation Models sur appareil si disponible + repli serveur + repli déterministe ; jeux d'évaluation | Onglet de chat ; contenu généré non relu présenté comme vérifié ; IA avant tentative | `ai.contextual` |
| **10 — Remaining screens** | Compléter l'expérience et les surfaces système | Premier lancement (60 s), réglages, rappels, Pro (StoreKit 2), À propos / méthodologie, widgets, Live Activities, App Intents / Spotlight / Siri, Control Center | Paywall avant la première valeur | `onboarding.v2`, `pro.v1`, `widgets.v1` |
| **11 — Accessibility / performance / visual hardening** | Qualité de référence | Audit complet (AX5, VoiceOver, Voice Control, Full Keyboard Access, Reduce Motion / Transparency, Increase Contrast) ; budgets de performance ; polissage visuel ; nettoyage des anciens chemins (flags ON ≥ 2 semaines sans incident) ; labels d'accessibilité App Store | Ajouter des fonctionnalités | — |

> Étape **2B** : placée après la Phase 2 (ses composants sont des composants Prism) et avant la Phase 3 (les écrans reconstruits en ont besoin). **À partir de la Phase 3, tout écran ou composant qui nomme un produit réel MUST utiliser `BrandLabel` / `BrandIcon` (§22A.5) ; c'est un critère d'acceptation de chaque phase.**
>
> Note : le premier lancement (Phase 10) réutilise les composants des Phases 4–5 ; il peut être avancé par Decision Request si le propriétaire veut tester l'acquisition plus tôt.

### 34.2 Les 7 portes de fin de phase (MUST, dans cet ordre)
1. **BUILD** — build propre Debug + Release, 0 erreur, **aucun nouveau warning**.
2. **TEST** — toutes les suites vertes (§32), nouveaux tests ajoutés, résultats chiffrés.
3. **VISUAL VALIDATION** — snapshots mis à jour et revus ; captures des écrans touchés : clair / sombre / AX3, fr + en ; à partir de 2B, rapport de couverture des icônes officielles (§22A.10).
4. **ACCESSIBILITY VALIDATION** — `performAccessibilityAudit()` sans erreur sur les écrans touchés ; parcours VoiceOver décrit pas à pas ; Reduce Motion vérifié.
5. **PERFORMANCE CHECK** — métriques vs baseline Phase 0 et budgets §30.
6. **REPORT** — `docs/transformation/phase-N/REPORT.md` (gabarit §39).
7. **SAFE CHECKPOINT** — PR fusionnée, tag `transform-phase-N-done`, état des flags documenté, procédure de retour arrière testée.

Puis **STOP** : attendre la validation explicite du propriétaire avant la phase suivante.

---

## 35. ACCEPTANCE CRITERIA

### 35.1 Critères globaux (fin de Phase 11)
- 100 % des écrans de l'inventaire (§14) implémentés avec leurs états chargement / vide / erreur / hors ligne.
- **0 valeur brute** (couleur, police, espacement, rayon, durée) hors `Prism` dans le code des fonctionnalités (test d'architecture vert).
- Chaque tâche courante (premier lancement, séance, Situation du jour, objectif, réglages, achat) réalisable avec : VoiceOver, Voice Control, AX5, Increase Contrast, Reduce Motion, Differentiate Without Color, mode sombre → éligible aux **Accessibility Nutrition Labels** correspondants.
- Budgets de performance (§30) respectés sur l'appareil de référence.
- Aucun contrat serveur cassé (tests de contrats verts) ; aucune logique autoritative déplacée côté client.
- Événements analytics émis conformément à la taxonomie (§31), vérifiés en Debug.
- Aucune mécanique retirée (§33 REMOVE) visible en production.
- 100 % des produits réels cités dans l'app affichent leur icône officielle `approved` ou un repli documenté ; 0 icône tierce modifiée (empreintes vérifiées) ; aucun badge de certification ni logo d'entreprise non autorisé ; écran « Marques et mentions légales » complet (§22A).
- Documentation à jour : rapports de phase, Decision Requests, `docs/transformation/CHANGELOG.md`.

### 35.2 Critères d'acceptation par élément (format obligatoire)
Chaque écran ou composant livré **MUST** avoir dans le rapport de phase une liste **Given / When / Then** vérifiable, par exemple :
- *Given* un utilisateur avec 6 révisions dues, *when* il ouvre Aujourd'hui, *then* la carte Séance affiche « 6 rappels » dans la composition et le bouton principal démarre la séance en 1 tap.
- *Given* Dynamic Type AX5, *when* une Situation affiche un artefact de 40 lignes, *then* aucune ligne n'est tronquée (défilement horizontal ou retour à la ligne activable) et VoiceOver lit l'artefact ligne par ligne.
- *Given* Reduce Motion activé, *when* un concept passe à *Ancré*, *then* la célébration est un fondu ≤ 0,3 s sans déplacement ni rebond.

---

## 36. ROLLBACK STRATEGY

- **Branches :** une branche par phase `transform/phase-N-<slug>` ; PR avec la checklist des 7 portes ; aucun commit direct sur la branche par défaut.
- **Tags :** `transform-phase-N-done` après fusion ; `transform-baseline` posé en Phase 0 (par le propriétaire si l'agent ne peut pas taguer).
- **Flags :** toute expérience visible par l'utilisateur est derrière un flag (`FeatureFlags` dans `CertigoDomain`) avec : valeur par défaut compilée, surcharge Debug (écran développeur, Debug uniquement), **kill switch distant** (source décidée par Decision Request : endpoint de configuration additif ou fichier statique signé). Défaut **OFF** jusqu'à acceptation de la phase.
- **Ancien chemin conservé** jusqu'à la Phase 11 ; suppression seulement après ≥ 2 semaines flag ON en production sans incident critique.
- **Données :** migrations **additives** uniquement (nouveaux champs optionnels, lecteurs tolérants) ; aucune suppression de données ; aucun changement de sémantique d'un champ existant.
- **Livraison :** TestFlight puis **déploiement progressif** App Store (phased release 7 jours) avec pause possible.
- **Procédure de retour arrière (à tester à chaque phase) :** (1) flag OFF à distance ; (2) si nécessaire, `git revert` du commit de fusion de la phase et nouvelle build ; (3) rapport d'incident dans `docs/transformation/incidents/`.

---

## 37. BLOCKED DECISION PROTOCOL

**Déclencheurs (MUST stopper l'élément concerné) :**
- ambiguïté ou contradiction entre ce prompt, la Bible et le code ;
- besoin de modifier un contrat serveur, un modèle de données, l'authentification, la confidentialité, la monétisation, la navigation au-delà de la spécification, la marque (icône, nom, couleurs de marque) ;
- besoin d'une nouvelle dépendance ou d'un nouveau service ;
- conditions d'usage d'une icône, d'un logo ou d'un badge tiers absentes, ambiguës ou ne couvrant pas le contexte prévu (§22A) ;
- suppression d'une fonctionnalité, d'un test ou de données ;
- impossibilité de respecter un budget d'accessibilité ou de performance ;
- échec d'un test non résolu après **2 tentatives** raisonnées.

**Procédure :**
1. Arrêter l'élément bloqué ; continuer les éléments **indépendants** de la phase.
2. Créer `docs/transformation/decisions/DR-NNN-<slug>.md` :
   - **Contexte** · **Problème** · **Preuves** (fichier:ligne, logs, captures) · **Options** (≥ 2, avec avantages / inconvénients / risques / réversibilité) · **Recommandation** · **Impact** (périmètre, délai, utilisateurs) · **Ce qui est bloqué** · **Statut** (`OPEN` / `APPROVED` / `REJECTED`) · **Décision du propriétaire** (date, texte).
3. Signaler la DR dans le chat et dans le rapport de phase.
4. **MUST NOT** implémenter l'option recommandée avant le statut `APPROVED` écrit dans le fichier.
5. Si la DR bloque le chemin critique, clore la phase en **achèvement partiel** documenté.

---

## 38. PREVENT VIBE-CODING DRIFT

### 38.1 Règles absolues
- **DO NOT CREATE ONE-OFF VISUAL COMPONENTS.** Tout élément visuel réutilisable ou stylé vit dans `Prism`. Un écran assemble des composants, il n'en invente pas.
- **DO NOT INTRODUCE RAW COLOR VALUES IN FEATURE CODE.** Uniquement `PrismColor.*` (rôles sémantiques).
- **DO NOT INTRODUCE ARBITRARY SPACING.** Uniquement `PrismSpacing.*`, `PrismRadius.*`, `PrismSize.*`.
- **DO NOT INVENT A NEW VISUAL STYLE PER SCREEN.** Un seul langage visuel (§17) ; toute variante passe par Prism.
- **DO NOT ADD ANIMATION WITHOUT PURPOSE.** Chaque animation a une fonction listée (§25) et une alternative Reduce Motion.
- **DO NOT ADD AI WITHOUT FALLBACK.** Toute fonction IA a un repli non-IA et un état d'erreur (§11).
- **DO NOT ADD GAMIFICATION WITHOUT LEARNING PURPOSE.** Toute mécanique cite la règle d'apprentissage qu'elle sert (§9).
- **DO NOT ADD SOCIAL MECHANICS WITHOUT PRIVACY CONTROLS.** Privé par défaut, opt-in, blocage et signalement (§10).
- **DO NOT CHANGE NAVIGATION LOCALLY.** La navigation est définie au §12–13 et dans un seul fichier de routes.
- **DO NOT BREAK EXISTING BUSINESS LOGIC.** Tests de caractérisation d'abord.
- **DO NOT MOVE SERVER-AUTHORITATIVE LOGIC TO THE CLIENT.** Notation, récompenses, maîtrise, préparation, objectifs, achats restent serveur.
- **DO NOT MARK WORK COMPLETE WITHOUT TEST EVIDENCE.**

Et aussi :
- **DO NOT** utiliser de polices non système.
- **DO NOT DRAW, RECOLOR OR APPROXIMATE A REAL PRODUCT'S ICON.** Utiliser l'icône officielle de `BrandAssets` via `BrandIcon` / `BrandLabel` (§22A), ou le repli documenté ; aucun actif de marque tiers hors de `BrandAssets`.
- **DO NOT** afficher de chaîne d'interface non localisée.
- **DO NOT** désactiver un avertissement du compilateur ou un test.
- **DO NOT** ajouter de dépendance sans Decision Request approuvée.

### 38.2 Garde-fous automatisés (MUST, Phase 1)
Un target de tests `ArchitectureTests` lit les fichiers Swift des modules de fonctionnalités et **échoue** si l'un de ces motifs apparaît hors de `Prism/` (liste à affiner en Phase 1, exceptions documentées) :
- `Color(red:`, `Color(hue:`, `Color(#`, `UIColor(red:`, `.init(red:` ; littéraux de couleur système utilisés comme couleur de marque (`.blue`, `.indigo`, `.purple`, `.orange`…, hors `Color.primary/.secondary`).
- `.font(.system(size:` ; `Font.custom(` ; `.fontWeight(` appliqué hors style Prism.
- `.padding(` suivi d'un littéral numérique ; `.frame(width: <littéral>` / `height:` (hors tailles Prism) ; `cornerRadius(<littéral>)` ; `RoundedRectangle(cornerRadius: <littéral>`.
- `withAnimation(.easeIn…(duration:` / `.spring(response:` avec littéraux hors `PrismMotion`.
- `UIImpactFeedbackGenerator(` hors `PrismHaptics`.
- `Text("…")` avec littéral non localisé dans les vues de production (hors previews / tests).
- `print(` dans le code de production.
- image d'un actif `BrandAssets` affichée hors de `BrandIcon` ; modificateurs interdits du §22A.6 appliqués à `BrandIcon` / `BrandLabel` (complété par `BrandAssetsTests`, §22A.10).
Le test produit un rapport lisible (fichier:ligne, motif, suggestion du token Prism).

---

## 39. DEFINITION OF DONE & REPORT TEMPLATE

Un élément est **DONE** seulement si : spécification respectée (lien vers la section de la Bible) · composants Prism uniquement · états complets · accessibilité vérifiée · tests ajoutés et verts · analytics branchées · flag configuré · documentation mise à jour · preuve jointe.

Gabarit `docs/transformation/phase-N/REPORT.md` :
```markdown
# Phase N — <titre> — Rapport
## 1. Résumé (5 lignes max) et statut : COMPLETE / PARTIAL / BLOCKED
## 2. Livré (liens vers fichiers, captures)
## 3. Portes : BUILD | TEST | VISUAL | A11Y | PERF | REPORT | CHECKPOINT (preuves)
## 4. Critères d'acceptation Given/When/Then — résultat
## 5. Écarts vs spécification (et justification) / dettes créées
## 6. Decision Requests ouvertes / tranchées
## 7. Métriques vs baseline (lancement, hitches, mémoire, taille)
## 8. Risques pour la phase suivante
## 9. Procédure de retour arrière testée (oui/non + preuve)
## 10. Phrase de clôture : "PHASE N TERMINÉE — EN ATTENTE DE VALIDATION."
```
