# NEXT IMPLEMENTATION PHASE PROMPT
## CertiGo — PHASE 0 : Audit + Baseline (lecture seule)

> **Version :** 1.1 — 22/10/2026 (ajout : inventaire des marques, icônes et logos tiers — H11, Étape 4 bis, DR-010).
> **Destinataire :** l'agent de développement (vibe coding) qui travaille sur le dépôt CertiGo.
> **Pré-requis :** avoir lu **intégralement** `docs/product/03_MASTER_IMPLEMENTATION_PROMPT.md` (ci-après « le Master Prompt »). En cas de conflit entre ce document et le Master Prompt, **le Master Prompt prévaut**, sauf sur un point : **pendant la Phase 0, aucune modification de code n'est autorisée, quelles que soient les autres instructions.**
> **Mots-clés :** MUST / MUST NOT / SHOULD / MAY au sens de la RFC 2119.

---

### 1. Mission de la Phase 0

Établir une **photographie exacte, vérifiée et chiffrée** du dépôt réel, puis produire la **carte Current → Target** et le **plan de migration** des Phases 1 à 11 (étape 2B comprise), **sans rien modifier**.

La Phase 0 répond à cinq questions :
1. **Qu'est-ce qui existe vraiment ?** (écrans, routes, composants, tokens, logique métier, tests)
2. **Dans quel état ?** (build, tests, accessibilité, performance, dette visuelle)
3. **Qu'est-ce qui ne doit surtout pas casser ?** (contrats serveur, logique autoritative, auth, données)
4. **Comment passe-t-on de l'existant à la cible du Master Prompt ?** (mapping + ordre + risques)
5. **Quelles décisions le propriétaire doit-il prendre avant la Phase 1 ?**

**Aucun redesign visuel ne commence pendant cette phase.**

---

### 2. Règles absolues de la Phase 0

- **MUST** travailler sur une branche dédiée : `transform/phase-0-audit`, créée depuis la branche par défaut à jour.
- **MUST NOT** modifier, renommer, déplacer ou supprimer **un seul fichier existant** (code, projet Xcode, `Package.swift`, assets, CI, contenu, docs existantes).
- **MUST NOT** corriger un bug, même trivial, même s'il bloque le build. Le documenter et proposer le correctif dans le rapport.
- **MUST NOT** ajouter de dépendance, de script, de target, de scheme ou de fichier de configuration.
- **MAY** uniquement **créer** des fichiers Markdown (ainsi que des captures PNG et des CSV de mesures) sous `docs/transformation/phase-0/`.
- **MAY** exécuter des commandes de lecture, de build et de test (les artefacts générés hors du dépôt, ex. DerivedData, sont autorisés).
- **MUST** citer chaque constat avec sa **preuve** : chemin de fichier + numéro de ligne, sortie de commande ou capture. Aucun constat sans preuve.
- **MUST** distinguer dans chaque rapport : **VÉRIFIÉ** (observé), **INFÉRÉ** (déduit, avec raisonnement), **NON VÉRIFIABLE** (avec la raison et la commande exacte que le propriétaire doit lancer).
- **MUST** s'arrêter à la fin de la Phase 0 et attendre la validation explicite du propriétaire. **MUST NOT** commencer la Phase 1.
- Si une commande exige un accès indisponible (simulateur, signature, secrets, réseau, Azure) : **MUST** noter `NON EXÉCUTÉ — raison` + la commande exacte, puis continuer le reste de l'audit.

Contrôle final de conformité (à joindre au résumé) : la sortie de `git status --porcelain` et de `git diff --stat <branche-par-défaut>...HEAD` **MUST** ne montrer que des fichiers **ajoutés** sous `docs/transformation/phase-0/`.

---

### 3. Hypothèses de départ à confirmer ou infirmer (ne pas les tenir pour acquises)

Ces éléments proviennent d'observations antérieures (journaux de build Xcode des 14/10 et 22/10/2026, enregistrements d'écran des 19/10 et 22/10/2026, instantané du dépôt du 06/07/2026). **Chacune MUST être confirmée ou infirmée avec preuve** dans `01_REPOSITORY_MAP.md` :

| # | Hypothèse | Comment vérifier |
|---|---|---|
| H1 | Le client cible est l'app **SwiftUI native** `apps/apple/CertigoNative` + le package SPM `apps/apple/CertigoKit` (modules `CertigoDomain`, `CertigoData`, `CertigoAppleFileIO`). | Arborescence, `.xcodeproj`, `Package.swift`, schemes. |
| H2 | L'app Flutter `apps/mobile` (+ `packages/prism_ui`, `cortex`, `data`, `core`) est un **héritage** : référence fonctionnelle, plus le client livré. | Historique git récent, CI active, `codemagic.yaml`, README / `docs/ETAT_DU_PROJET.md`. |
| H3 | `CertigoNativeApp.swift` est un fichier monolithique (≥ 3 600 lignes) contenant la majorité des vues. | `wc -l`, liste des `struct … : View`. |
| H4 | Le build Debug du 22/10/2026 échouait sur `CertigoNativeApp.swift:3683` : `@Environment(\.accessibilityContrast)` (clé inexistante ; la clé SwiftUI est `\.colorSchemeContrast`). | Build propre. **Ne pas corriger.** |
| H5 | Cible de déploiement iOS **17.0**, Swift **6**, dépendance **MSAL**. | Build settings, `Package.resolved`. |
| H6 | 4 onglets : `Apprendre`, `Coach`, `Communauté`, `Profil` ; un mode **Démo** (données fictives) et un **connecteur API de test** sont exposés dans l'UI. | Code de la `TabView`, conditions de compilation, flags. |
| H7 | 8 langues d'interface (fr, en, hi, zh-Hans, ko, es, it, de) via catalogue de chaînes ; le contenu pédagogique n'est pas traduit. | `.xcstrings` / `Localizable`, `AppLanguage.swift`. |
| H8 | Notation, XP, streak, readiness, ligues et achats sont **autoritatifs côté serveur** (backend .NET `backend/`) ; la clé de correction n'est jamais envoyée au client. | `CertigoAPI.swift`, `SubmissionStore.swift`, contrats, endpoints backend. |
| H9 | Il n'existe **pas encore** de design system natif (« Prism » n'existe qu'en Flutter). | Recherche de tokens / styles partagés côté Swift. |
| H10 | Aucune extension iOS (widgets, Live Activities, App Intents, notifications enrichies) n'est encore présente. | Targets d'extension, `AppIntent`, `WidgetKit`, `ActivityKit`. |
| H11 | Le dépôt contient des visuels de marque tiers sans provenance ni conditions documentées (mascottes dérivées d'icônes Azure côté Flutter ; visuels de certification ad hoc tels que `NativeCertificationCrest` côté natif) et n'utilise **aucune** icône officielle d'éditeur de façon tracée. | Recherche des images (`.xcassets`, `.svg`, `.pdf`, `.png`), des usages `Image(…)` / `Image(systemName:)` associés à un produit, de `NativeCertificationCrest`, des dossiers de mascottes. |

---

### 4. Travaux à réaliser (dans cet ordre)

**Étape 1 — Carte du dépôt.** Arborescence commentée (niveau 3), targets, schemes, configurations (Debug / Release / « Certigo Dev »), packages, dépendances résolues avec versions, réglages (deployment target, version de Swift, strict concurrency), CI (workflows actifs, Codemagic), commandes de build et de test **qui fonctionnent réellement**.

**Étape 2 — Baseline technique.**
- Build propre Debug et Release (simulateur iPhone de dernière génération) : résultat, erreurs, **nombre de warnings** par catégorie.
- Tests : exécuter toutes les suites Swift (Swift Testing + XCTest) et, si l'environnement le permet, le backend (`dotnet test`) et le contenu (`node tools/validate_content.mjs`). Pour chaque suite : total / réussis / échoués / ignorés / durée.
- Performance : temps de lancement (XCTApplicationLaunchMetric ou Instruments App Launch si disponible), taille de l'app (.app et IPA si possible), mémoire au repos sur l'écran d'accueil.
- **MUST NOT** corriger quoi que ce soit pour faire passer le build : si le build échoue, la baseline visuelle et d'accessibilité est marquée `BLOQUÉE PAR BUILD` et le correctif minimal est proposé dans `13_RISKS_AND_DECISIONS.md` sous forme de **Decision Request**.

**Étape 3 — Inventaire des écrans et des routes.** Pour chaque écran / vue de premier niveau : nom du type Swift, fichier:ligne, point d'entrée (onglet, push, sheet, fullScreenCover, alert, confirmationDialog, menu), données affichées, actions, états gérés (chargement, vide, erreur, hors ligne, démo), chaînes visibles principales, présence en mode Démo. Produire le **graphe de navigation** (Mermaid) : onglets → piles → feuilles ; deep links / URL schemes (`certigo://…`) ; callbacks d'authentification.

**Étape 4 — Inventaire Prism / design.**
- Natif : tout ce qui joue le rôle de tokens (extensions `Color`, `Font`, constantes d'espacement, `ViewModifier`, `ButtonStyle`, `LabelStyle`, styles de cartes) et **toute vue réutilisée** (≥ 2 usages). Pour chaque composant : fichier:ligne, usages, variantes, accessibilité.
- Flutter (référence uniquement) : tokens et composants de `packages/prism_ui` utiles comme mémoire de conception (**ne pas porter**).
- Liste des **composants visuels ponctuels** (one-off) qui devront être absorbés par Prism.

**Étape 4 bis — Marques, icônes et logos tiers** (prépare l'étape 2B du Master Prompt, §22A *Official brand iconography*).
- **Actifs présents** (natif, Flutter, backend, contenu, métadonnées de store si elles sont dans le dépôt) — une ligne par fichier ou par usage : `fichier | type (icône de produit · icône d'application · logo d'entreprise · badge de certification · visuel dérivé / modifié · imitation · SF Symbol ou emoji utilisé pour représenter un produit) | éditeur | produit | écran(s) où il s'affiche | modifié ? (oui / non / inconnu) | source et conditions connues ? | conforme au §22A ? (oui / non / à vérifier)`.
- **Produits cités** : extraire de `content/` (parcours, leçons, items, sources) et des chaînes de l'app chaque produit ou service tiers nommé → `brand_references.csv` : `éditeur | nom officiel | variantes trouvées | occurrences | parcours et leçons concernés | kit officiel pressenti (Master Prompt §22A.3) | niveau d'autorisation pressenti (1 / 2 / 3, §22A.2) | contextes d'affichage prévus (§22A.5) | statut (couvert / autorisation à demander / repli)`.
- **Couverture attendue** : par éditeur et par kit, nombre de produits cités, nombre couvrables par un kit officiel (niveau 1), nombre exigeant une autorisation écrite (niveau 2, ex. icônes Word / Excel / Teams des parcours *Microsoft Office Specialist*), nombre en repli ; liste des autorisations à demander, par éditeur ; liste des **noms obsolètes** rencontrés (ex. *Azure Active Directory*) avec le nom officiel actuel.
- **Visuels à retirer ou à remplacer** : mascottes dérivées, crêtes ou médailles qui imitent un badge de certification, icônes approximatives d'un produit réel.
- **MUST NOT** télécharger un kit, ajouter une icône ou créer le registre pendant la Phase 0. Si un accès web est disponible, **MAY** vérifier que les URL officielles du Master Prompt §22A.3 répondent et relever la version affichée ; sinon noter `NON VÉRIFIÉ`.

**Étape 5 — Inventaire des valeurs codées en dur** (code natif uniquement), avec comptage et fichier:ligne :
- couleurs brutes (`Color(red:…)`, hex, `UIColor(…)`, littéraux `.indigo` / `.blue` / `.purple`… utilisés comme couleur de marque, opacités magiques) ;
- typographie brute (`.font(.system(size:))`, tailles fixes, `minimumScaleFactor`, `lineLimit(1)` sur du texte long) ;
- espacements / tailles / rayons arbitraires (`.padding(13)`, `.frame(width: 327)`, `cornerRadius(…)`) ;
- durées et courbes d'animation littérales ;
- chaînes d'interface non localisées.

Fournir un **top 20 des fichiers les plus « endettés »** et un CSV `hardcoded_values.csv` (fichier, ligne, catégorie, valeur, extrait).

**Étape 6 — Animations, haptique, son.** Inventaire de `withAnimation`, `.animation`, `.transition`, `matchedGeometryEffect`, `PhaseAnimator`, `KeyframeAnimator`, `symbolEffect`, `sensoryFeedback`, `UIFeedbackGenerator`, Core Haptics, sons. Pour chacun : but, durée, respect de **Reduce Motion** (oui / non / partiel).

**Étape 7 — Accessibilité.** Pour chaque écran inventorié :
- Dynamic Type : rendu à la taille par défaut et à **AX3 (accessibilityExtraExtraExtraLarge)** ; troncatures, chevauchements, texte non adaptatif.
- VoiceOver : libellés, traits, ordre de lecture, éléments décoratifs non masqués, actions personnalisées manquantes.
- Contraste (clair / sombre, Increase Contrast), information portée **uniquement par la couleur**, cibles tactiles < 44×44 pt, Reduce Transparency, Bold Text.
- Si possible, exécuter `XCUIApplication().performAccessibilityAudit()` sur chaque écran atteignable et joindre les résultats.

**Étape 8 — Tests.** Inventaire par target : unitaires, UI, snapshot, intégration, protection des données ; couverture si mesurable ; tests instables ; **trous critiques** (soumission de réponse, file hors ligne, changement d'objectif, suppression de compte, authentification).

**Étape 9 — Duplications et code mort.** Vues, styles et logiques dupliqués ; branches Démo / Dev mélangées au code de production ; logique métier dupliquée entre client natif, Flutter et backend ; code inatteignable.

**Étape 10 — Logique métier et contrats à préserver.** Liste exhaustive de ce qui **MUST NOT break** : endpoints utilisés par le client natif (méthode, chemin, DTO), logique autoritative serveur, file de soumission et idempotence, packs hors ligne, protection des fichiers (`FileProtectionPolicy`), Keychain (`CredentialVault`), MSAL / CIAM, suppression de compte, langue, préférences du plan d'étude. Pour chacun : fichier:ligne, tests existants, risque si modifié.

**Étape 11 — Mapping Current → Target.** Tableau exhaustif, une ligne par écran / fonctionnalité existant et par élément cible du Master Prompt (sections INFORMATION ARCHITECTURE, SCREEN INVENTORY, OFFICIAL BRAND ICONOGRAPHY, PRESERVE / IMPROVE / REMOVE / ADD) :
`Élément actuel | Fichier(s) | Cible | Décision (PRESERVE / IMPROVE / REMOVE / ADD / DEFER) | Phase cible | Dépendances | Risque (faible / moyen / élevé) | Preuve`.
Tout élément actuel **sans correspondance** dans la cible MUST être signalé.

**Étape 12 — Plan de migration.** Pour les Phases 1 à 11 du Master Prompt (étape 2B comprise), adapter le plan à la réalité observée : lots de travail (≤ 1 journée d'agent chacun), ordre, prérequis, flags de fonctionnalité, tests à écrire **avant** de modifier, critères d'acceptation, points de contrôle (tags git), estimation S / M / L. Identifier explicitement le **découpage du monolithe** `CertigoNativeApp.swift` en fichiers par fonctionnalité **sans changement de comportement** (à exécuter en Phase 1, après validation).

**Étape 13 — Risques et décisions.** Registre des risques (probabilité × impact, mitigation) et **Decision Requests** au format du Master Prompt (section BLOCKED DECISION PROTOCOL). Au minimum, instruire avec preuves et recommandation :
- DR-001 Correctif de baseline du build (si H4 est confirmée).
- DR-002 Cible de déploiement iOS (17 actuelle → 26 recommandée) : impacts API, part d'appareils, Foundation Models, Liquid Glass.
- DR-003 Sort de l'app Flutter et de `packages/prism_ui` (gel, archive, suppression différée).
- DR-004 Politique de latence du feedback (notation serveur ≤ 1 s en ligne ; feedback hors ligne provisoire ou non).
- DR-005 Retrait côté UI des gemmes, de la boutique, de la réparation payante de série et des ligues XP publiques (le backend reste intact tant que non décidé).
- DR-006 Retrait des mascottes dérivées d'icônes Azure et de tout visuel qui **modifie ou imite** une marque tierce (crêtes de certification, icônes redessinées) ; remplacement par les icônes officielles non modifiées (DR-010).
- DR-007 Outil de tests visuels (snapshot) et de linting des tokens (dépendance éventuelle).
- DR-008 Outil d'analytics produit et politique de consentement.
- DR-009 Sortie du mode Démo et du connecteur de test hors des builds de production.
- DR-010 Programme d'icônes officielles des éditeurs (Master Prompt §22A, étape 2B) : kits par éditeur et contextes autorisés (niveau 1) ; autorisations écrites à demander (niveau 2 : icônes d'applications Microsoft 365, logos GitHub, usages hors contenu pédagogique) avec textes de demande prêts ; interdits confirmés (niveau 3 : badges de certification, logos d'entreprise, App Store) ; budget de taille ; mentions légales et non-affiliation ; repli ; fondée sur `14_BRAND_ASSETS_AUDIT.md`.

---

### 5. Livrables (fichiers à créer, et rien d'autre)

Tous sous `docs/transformation/phase-0/` :

| Fichier | Contenu |
|---|---|
| `00_SUMMARY.md` | Résumé d'une page : état global, chiffres clés, top 10 constats, top 5 risques, décisions requises, **recommandation GO / NO-GO pour la Phase 1**. Joindre le contrôle `git status` / `git diff --stat`. |
| `01_REPOSITORY_MAP.md` | Étape 1 + statut H1–H11 (VÉRIFIÉ / INFIRMÉ / NON VÉRIFIABLE + preuve). |
| `02_BASELINE.md` | Étape 2 (build, warnings, tests, performance) + captures de référence de chaque écran atteignable (clair, sombre, AX3) dans `docs/transformation/phase-0/screenshots/`. |
| `03_SCREENS_AND_ROUTES.md` | Étape 3 + graphe Mermaid. |
| `04_PRISM_TOKENS_COMPONENTS.md` | Étape 4. |
| `05_HARDCODED_VALUES.md` + `hardcoded_values.csv` | Étape 5. |
| `06_MOTION_HAPTICS.md` | Étape 6. |
| `07_ACCESSIBILITY.md` | Étape 7. |
| `08_TESTS.md` | Étape 8. |
| `09_DUPLICATIONS.md` | Étape 9. |
| `10_BUSINESS_LOGIC_CONTRACTS.md` | Étape 10 (liste « MUST NOT BREAK »). |
| `11_CURRENT_TO_TARGET_MAP.md` | Étape 11. |
| `12_MIGRATION_PLAN.md` | Étape 12. |
| `13_RISKS_AND_DECISIONS.md` | Étape 13. |
| `14_BRAND_ASSETS_AUDIT.md` + `brand_references.csv` | Étape 4 bis (actifs de marque présents, produits cités, couverture attendue par kit officiel, visuels à retirer). |

Format : Markdown, titres stables, tableaux, chemins relatifs cliquables, aucune donnée personnelle, aucun secret (masquer toute valeur de clé, jeton, identifiant de locataire ou endpoint privé).

---

### 6. Critères d'acceptation de la Phase 0

La Phase 0 est terminée **uniquement** si :
1. Les fichiers ci-dessus existent, sont non vides et suivent les formats demandés.
2. H1–H11 ont chacune un statut avec preuve.
3. 100 % des écrans atteignables depuis l'UI sont inventoriés (comparaison avec le graphe de navigation).
4. Le CSV des valeurs codées en dur couvre l'ensemble du code Swift de l'app et de `CertigoKit` (préciser le nombre de fichiers analysés) ; `brand_references.csv` couvre 100 % des parcours de `content/` et les chaînes de l'app.
5. Chaque élément actuel apparaît dans le mapping Current → Target (aucun orphelin non signalé).
6. Le plan de migration couvre les Phases 1 à 11 (étape 2B comprise) avec critères d'acceptation et points de contrôle.
7. Les Decision Requests DR-001 à DR-010 sont rédigées (statut, options, recommandation, impact).
8. Le contrôle git prouve qu'**aucun fichier existant n'a été modifié**.
9. Le résumé se termine par la phrase exacte : `PHASE 0 TERMINÉE — EN ATTENTE DE VALIDATION. AUCUNE MODIFICATION DE CODE EFFECTUÉE.`

---

### 7. Format du compte rendu final (dans le chat)

1. Lien vers `00_SUMMARY.md`.
2. Recommandation GO / NO-GO pour la Phase 1 et ses conditions.
3. Liste des Decision Requests à trancher par le propriétaire, triées par urgence.
4. Ce qui n'a pas pu être vérifié, avec la commande exacte à lancer.
5. La phrase de clôture exacte ci-dessus. Puis **s'arrêter**.
