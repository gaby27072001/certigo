# Étape 13 — Registre des Risques et Decision Requests (`DR-001` à `DR-010`)

> **Branche auditée :** `transform/phase-0-audit` (`HEAD` `778f9c247ceb9c0db29fb931a8573bd328b492ab`)
> **Référence normative :** Master Prompt §37 (*Blocked Decision Protocol*) et Partie 2 §4 Étape 13.
> **Règle impérative (§37.4) :** aucune option recommandée ci-dessous **MUST NOT** être implémentée avant que le propriétaire n'ait inscrit le statut `APPROVED` et sa décision signée/datée.

---

## 1. Registre des Risques (Probabilité × Impact, échelle 1–5, Score /25)

| ID | Risque identifié (avec preuve `fichier:ligne`) | Prob. (1–5) | Impact (1–5) | Score (/25) | Phase(s) concernée(s) | Mitigation & Garde-fou |
|---|---|---|---|---|---|---|
| **R-01** | **Violation de marques tierces par les emblèmes et crêtes vectoriels peints à la main (`NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCertificationCrest`)** introduits en PR #97/#98 (`CertigoNativeApp.swift:3284-3729`), qui dessinent le logo 4 couleurs Microsoft, l'Invertocat GitHub, le sourire AWS, le « G » Google et des écussons de certification (§22A.2 Niveau 3 interdit). | 5 | 5 | **25 (Critique)** | Étape 2B, Phase 3 | Trancher **DR-006** et **DR-010** ; retirer `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem` et `NativeCertificationCrest` en Étape 2B ; remplacer par `BrandIcon` / `BrandLabel` (niveau 1) et `BrandFallbackMark` + `RouteBadge` en texte (`.catalog` tant que niveau 2 non autorisé) ; activer `BrandAssetsTests` en CI (§22A.10). |
| **R-02** | **Exposition du Mode Démo (`NativeDemoRoot`) et de la galerie de widgets simulés (`NativeWidgetGalleryView`) dans les builds de production** (`CertigoNativeApp.swift:4264,4324-4334,7172-7180` ; `NativeWidgetGalleryView.swift:18,255-297`), violant le principe 6 (« aucune donnée fictive en production ») et App Store Review 2.1. | 5 | 4 | **20 (Critique)** | Phase 1, Phase 3, Phase 10 | Trancher **DR-009** ; isoler immédiatement le connecteur et les simulateurs dans `D-1` sous `#if DEBUG` en Phase 1 ; basculer l'accueil non connecté sur le Mode Invité adossé au contenu public réel (`onboarding.v2`). |
| **R-03** | **Mécanique culpabilisante d'icône dynamique (`CertigoIconStreakAtRisk`, mode `.automatic` par défaut)** introduite par PR #101 (`CertigoAppIconSelection.swift:48,55-68,135-142`) et affichage d'XP / `streakAtRisk` dans `CertigoWidgetPresentation.swift:45,143,160`, en contradiction avec les §7, §8, §9 et §16 principe 7. | 5 | 3 | **15 (Élevé)** | Phase 1, Phase 7, Phase 10 | Trancher **DR-001** et **DR-005** ; désactiver le basculement automatique vers `streakAtRisk` ; aligner `W-1` et les icônes sur le Rythme hebdomadaire (`rhythm.v1`) sans copie de perte ni XP visible. |
| **R-04** | **Rupture des tests de contrats sources Python (`test_native_prism_presentation.py`, `test_native_source_membership.py`, `test_native_distribution.py`) lors du découpage du monolithe `CertigoNativeApp.swift` (8 565 lignes)**. | 4 | 4 | **16 (Élevé)** | Phase 1 | Suivre le plan chirurgical en 12 fichiers (`12_MIGRATION_PLAN.md` §2) en mettant à jour simultanément `project.pbxproj`, `test_native_source_membership.py:58-110` et le chargeur multi-fichiers de `test_native_prism_presentation.py:16-20` sans supprimer aucune assertion. |
| **R-05** | **Absence de l'entitlement App Group (`group.com.certigo.native`) dans `CertigoNative.entitlements`** (`CertigoNative.entitlements:1-10` ne contient que `applinks:www.certigo-app.com`), ce qui fait échouer `CertigoWidgetStore(sharedContainerOnly: true)` en `.sharedContainerUnavailable` dans `CertigoWidgetExtension.swift:37-45`. | 5 | 3 | **15 (Élevé)** | Phase 3 / Phase 10 | Ajouter `com.apple.security.application-groups` (`group.com.certigo.native`) aux entitlements de l'app et de `CertigoWidgetExtension` lors du provisionnement Apple Developer en Phase 10 (`widgets.v1`). |
| **R-06** | **Blocage des nouveaux formats d'items P1/P2 (`spotTheIssue`, `ordering`, `situation`, etc.) par les gardes strictes `type == "mcq"`** dans `Contracts.swift:258,308`, `LearningServices.swift:96` et `CanonicalQuestionReader.swift:44`. | 4 | 4 | **16 (Élevé)** | Phase 4 | Coordonner l'ouverture additive des types dans `CertigoDomain`/`CertigoData` avec `ExerciseItemsV5Rules.cs` et un repli gracieux `PrismEmptyState` (« Ce format arrive bientôt » + événement `item_format_unsupported`, §6.4). |
| **R-07** | **Latence de notation serveur > 1 s sur réseau mobile dégradé lors de l'action « Vérifier » (`POST /api/quiz/{lessonId}/submit`)**, dégradant le critère bloquant NS-5 (`≤ 1 s perçu p95`). | 3 | 4 | **12 (Moyen)** | Phase 5 | Trancher **DR-004** ; afficher un état de vérification immédiat à `300 ms` (§6.2, §30), optimiser le chemin chaud de `QuizService.SubmitAsync` et pré-chauffer la connexion TLS. |
| **R-08** | **Délai d'obtention des autorisations écrites de Niveau 2 (Microsoft `trademarks@microsoft.com` pour Word/Excel/PowerPoint/Outlook/Teams/Power BI, GitHub Brand Toolkit, AWS hors `.diagram`, CNCF)**. | 4 | 3 | **12 (Moyen)** | Étape 2B → Phase 11 | Architecture `BrandRegistry` + `BrandFallbackMark` conçue pour fonctionner à 100 % en repli dès l'Étape 2B (`status: "pending-permission"` → repli propre sans changement de code, §22A.2). |
| **R-09** | **Incompatibilité d'appareils iOS 17/18 avec les APIs iOS 26+/27 (Liquid Glass `.glassProminent`, `tabViewBottomAccessory`, rôle `.search`, `FoundationModels`)**. | 3 | 3 | **9 (Moyen)** | Phases 1, 3, 9, 10 | Trancher **DR-002** ; tant que `IPHONEOS_DEPLOYMENT_TARGET = 17.0` (`project.pbxproj:297,340,353`), encapsuler chaque appel iOS 26+ dans `if #available(iOS 26.0, *)` avec repli natif testé (ex. `CertigoNativeApp.swift:4075-4079`). |
| **R-10** | **Purge incomplète de `CertigoWidgetStore` / `CertigoAppIconPreferenceStore` lors d'une reprise de suppression de compte à froid** (`NativeModel.swift:898,981-1038` ne liste que `["learning", "activity", "vault", "msal"]` dans `remainingCleanup`). | 2 | 4 | **8 (Moyen)** | Phase 1 / Phase 10 | Ajouter la purge explicite du snapshot widget et de la préférence d'icône dans le flux de nettoyage de suppression de compte et la couvrir dans `AccountDeletionTests` / `NativeModelTests`. |

---

## 2. Decision Requests (`DR-001` à `DR-010`) — Format strict §37

---

### DR-001 — État de la baseline du build (H4 résolue en PR #99) et traitement des ajouts PR #96, #97, #98, #100 et #101

- **Contexte :**
  Le Master Prompt (§4.1 et Partie 2 §3 H4) signalait un échec du build Debug du 22/10/2026 sur `CertigoNativeApp.swift:3683` causé par `@Environment(\.accessibilityContrast)` dans `NativeCertificationCrest`. Entre cet instantané et le `HEAD` audité (`778f9c247ceb9c0db29fb931a8573bd328b492ab`), 6 PRs ont été fusionnées sur `main` :
  - PR #96 (`02a8252f` / `946242b0`) : refonte visuelle `NativePrism`, anneaux `NativeReadinessRing`, tuiles Bento `NativeMetricGrid`.
  - PR #97 (`7b7b08f2`) & PR #98 (`10393f39` / `eb0644dc` / `ade19dbc`) : ajout de `NativeEcosystemArtwork`, `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCertificationCrest` et `NativeShowcaseTile`.
  - PR #99 (`1a025a28` / `f6dd2ea7`) : correction de `CertigoNativeApp.swift:3683` en `@Environment(\.colorSchemeContrast) private var contrast`.
  - PR #100 (`3b07d68d` / `5c940484`) : ajout de `CertigoWidgetExtension`, `CertigoWidgetSnapshot`, `CertigoWidgetStore`, `CertigoWidgetPresentation` et `NativeWidgetGalleryView`.
  - PR #101 (`778f9c24` / `fe708740`) : ajout de `CertigoAppIconSelection`, `CertigoAppIconPreferenceStore`, `NativeAppIconController` et des 3 icônes alternatives (`CertigoIconStreakFire`, `CertigoIconStreakAtRisk`, `CertigoIconMasteryGold`).
- **Problème :**
  1. Le bogue de compilation H4 (`\.accessibilityContrast`) est **déjà corrigé** sur `HEAD` `778f9c24` : aucun correctif de compilation n'est requis pour H4.
  2. En revanche, les PR #97/#98/#100/#101 ont introduit dans le `HEAD` de départ des éléments qui divergent du Master Prompt : (a) logos d'éditeurs peints à la main et crêtes de certification (`CertigoNativeApp.swift:3284-3729`, voir **DR-006** / **DR-010**), (b) galerie de simulation de widgets exposée dans `Profil` en production (`CertigoNativeApp.swift:7172-7180`, voir **DR-009**), et (c) basculement automatique d'icône vers `streakAtRisk` (« Série à préserver », `CertigoAppIconSelection.swift:60`, voir **DR-005**). Il faut décider comment traiter ces ajouts dans la baseline de départ de la Phase 1.
- **Preuves :**
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3683` : `@Environment(\.colorSchemeContrast) private var contrast` (commit `f6dd2ea7085ca2e69d170bfc00d700286d915b8a`).
  - `tools/tests/test_native_prism_presentation.py:362,366` : vérifie la présence de `@Environment(\.colorSchemeContrast)` et l'absence de `@Environment(\.accessibilityContrast)`.
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3284-3760` : `NativeEcosystemArtwork`, `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCertificationCrest`, `NativeShowcaseTile`.
  - `apps/apple/CertigoNative/Sources/NativeWidgetGalleryView.swift:9-604` & `apps/apple/CertigoKit/Sources/CertigoDomain/CertigoAppIconSelection.swift:1-231`.
- **Options :**
  - **Option A (Recommandée) — Accepter `HEAD` `778f9c24` comme baseline technique et absorber/corriger les écarts par phase :**
    - *Avantages :* conserve l'infrastructure saine de PR #100 (`CertigoWidgetStore`, `CertigoWidgetSnapshot`, target `CertigoWidgetExtension` déjà câblée dans `project.pbxproj`) et de PR #96 (`ViewThatFits`, `@ScaledMetric`), évite tout `git revert` conflictuel, et traite chaque écart dans sa phase dédiée (isolation Debug de la galerie en Phase 1, remplacement des crêtes par `BrandLabel` en Étape 2B, neutralisation de `streakAtRisk` en Phase 7).
    - *Inconvénients :* les emblèmes peints à la main restent présents dans le code jusqu'à l'Étape 2B (mais sans nouvelle exposition).
    - *Risques :* faible.
    - *Réversibilité :* totale (tags git par phase).
  - **Option B — Annuler (`git revert`) les PR #97, #98, #100 et #101 avant de démarrer la Phase 1 :**
    - *Avantages :* ramène le dépôt à un état proche de l'instantané antérieur au 22/10/2026 après-midi.
    - *Inconvénients :* détruit l'extension `CertigoWidgetExtension` et `CertigoWidgetStore` (2 087 lignes testées) qu'il faudrait recréer en Phase 3/10, et oblige à réécrire immédiatement `test_native_prism_presentation.py`, `test_native_source_membership.py` et `test_native_distribution.py`.
    - *Risques :* moyen (conflits de revert sur `CertigoNativeApp.swift` et `project.pbxproj`).
    - *Réversibilité :* moyenne.
- **Recommandation :** **Option A** — prendre `HEAD` `778f9c24` tel quel comme tag `transform-baseline`, découper le monolithe en Phase 1 sans changer le comportement, déplacer le simulateur de widgets sous `D-1` (`#if DEBUG`), remplacer `NativeCertificationCrest` / `NativeEcosystemEmblem` en Étape 2B, et aligner le widget et les icônes sur le Rythme en Phase 7 / Phase 10.
- **Impact :** Périmètre : Phase 1, Étape 2B, Phase 7, Phase 10. Délai : 0 jour supplémentaire avec l'Option A. Utilisateurs : aucun impact immédiat.
- **Ce qui est bloqué :** Validation du périmètre exact du Lot 1.1 / Lot 1.3 de la Phase 1.
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : figer 778f9c24 comme baseline et découper le monolithe en Phase 1 (Recommended)` (voir `docs/transformation/decisions/DR-001.md`).

---

### DR-002 — Cible de déploiement iOS (`IPHONEOS_DEPLOYMENT_TARGET` : 17.0 actuel vs 26.0 recommandé)

- **Contexte :**
  Le projet Xcode `CertigoNative.xcodeproj` et le package `CertigoKit/Package.swift` ciblent actuellement **iOS 17.0** (`IPHONEOS_DEPLOYMENT_TARGET = 17.0`, `platforms: [.iOS(.v17), .macOS(.v14)]`), tout en utilisant déjà des APIs iOS 26.0 derrière `#available(iOS 26.0, *)` (ex. `.buttonStyle(.glassProminent)` dans `NativePrimaryButton`). Le Master Prompt (§22, §24, §27) utilise plusieurs capacités natives d'iOS 26+ : Liquid Glass (`glassEffect`, `GlassEffectContainer`), `Tab` avec rôle `.search`, `tabViewBottomAccessory`, animations SF Symbols `.drawOn` et framework `FoundationModels` (`SystemLanguageModel.default`).
- **Problème :**
  Faut-il relever `IPHONEOS_DEPLOYMENT_TARGET` à `26.0` dès la Phase 1, ou conserver `17.0` avec des gardes `#available(iOS 26.0, *)` et des replis explicites jusqu'à la release majeure ?
- **Preuves :**
  - `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:297,340,353,431,456,480` : `IPHONEOS_DEPLOYMENT_TARGET = 17.0;`.
  - `apps/apple/CertigoKit/Package.swift:7` : `platforms: [.iOS(.v17), .macOS(.v14)]`.
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4075-4079` : `if #available(iOS 26.0, *), !reduceTransparency { button.buttonStyle(.glassProminent) } else { button.buttonStyle(.borderedProminent) }`.
- **Options :**
  - **Option A (Recommandée) — Maintenir `IPHONEOS_DEPLOYMENT_TARGET = 17.0` pendant la migration avec `#available(iOS 18.0 / 26.0, *)` et replis propres dans `Prism`, puis basculer à `26.0` uniquement sur décision de release majeure :**
    - *Avantages :* préserve la compatibilité avec 100 % du parc iOS 17/18/26 et tous les simulateurs CI existants ; isole toute la logique `#available` à l'intérieur du module `Prism` et de `AIRouter` (conformément au §27 : « `#available` pour toute API iOS 26+/27 tant que la cible reste iOS 17 »).
    - *Inconvénients :* nécessite des branches `#available` dans `PrismMaterialRole`, `PrismIcon`, `Router` (`tabViewBottomAccessory`) et `AIRouter` (`FoundationModels`).
    - *Risques :* faible.
    - *Réversibilité :* totale (relever la cible plus tard consiste uniquement à supprimer les branches `else`).
  - **Option B — Relever immédiatement `IPHONEOS_DEPLOYMENT_TARGET` à `26.0` en Phase 1 :**
    - *Avantages :* code SwiftUI légèrement plus concis (pas de `#available(iOS 26.0, *)` pour Liquid Glass, `Tab`, `FoundationModels`).
    - *Inconvénients :* exclut tous les appareils sous iOS 17 et iOS 18 (ex. iPhone XS/XR bloqués sur iOS 18) et exige que tous les runners CI macOS disposent du SDK iOS 26+.
    - *Risques :* moyen (parc d'appareils et runners CI).
    - *Réversibilité :* faible (réintroduire les `#available` après coup est coûteux).
- **Recommandation :** **Option A** — conserver `iOS 17.0` comme cible minimale compilée en encapsulant systématiquement les APIs iOS 26+ dans `Prism` et `AIRouter` avec repli vérifié.
- **Impact :** Périmètre : `Prism` (Phases 1–2), Navigation (Phase 3), IA sur appareil (Phase 9).
- **Ce qui est bloqué :** Règles d'écriture des composants `Prism` en Phase 1–2 (avec ou sans `#available`).
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option B approuvée** : `Passer immédiatement la cible minimale à iOS 26.0` (voir `docs/transformation/decisions/DR-002.md`).
---

### DR-003 — Sort de l'application Flutter (`apps/mobile`) et des packages Dart (`packages/prism_ui`, `cortex`, `data`, `core`)

- **Contexte :**
  Le dépôt contient l'application Flutter historique (`apps/mobile`, 114 fichiers Dart) et le design system Dart (`packages/prism_ui`, 62 fichiers Dart). Le client livré sur iOS est désormais l'app SwiftUI native `apps/apple/CertigoNative`. Cependant, l'audit de Phase 0 a révélé qu'un test Python de la suite native (`tools/tests/test_native_prism_presentation.py:21-35`) lit directement `packages/prism_ui/lib/src/tokens/prism_colors.dart` pour comparer les valeurs hexadécimales de `NativePrism.ink` et `NativePrism.glow`.
- **Problème :**
  Quel est le statut officiel de `apps/mobile` et `packages/*` pendant et après les Phases 1 à 11 (gel en lecture seule, archivage hors CI active, ou suppression différée), et faut-il découpler immédiatement les tests natifs de `packages/prism_ui` ?
- **Preuves :**
  - `apps/mobile/lib/` (114 fichiers Dart) & `packages/prism_ui/lib/` (62 fichiers Dart).
  - `tools/tests/test_native_prism_presentation.py:22-24` : `flutter = (ROOT / "packages/prism_ui/lib/src/tokens/prism_colors.dart").read_text(encoding="utf-8")`.
  - `apps/apple/CertigoKit/Tests/CertigoKitTests/CortexTests.swift:8-110` : partage les vecteurs JSON de parité avec Cortex, mais sans dépendre du code Dart de `prism_ui`.
- **Options :**
  - **Option A (Recommandée) — Gel immédiat en lecture seule (`DEPRECATED / REFERENCE ONLY`), découplage du test Python natif en Phase 1, et suppression/archivage après la Phase 11 :**
    - *Avantages :* conserve la mémoire fonctionnelle (formats d'exercices v5, flux de défis/amis) pendant la migration tout en supprimant tout couplage entre les tests natifs Swift/Python et les fichiers Dart ; aucun risque de suppression prématurée de vecteurs utiles.
    - *Inconvénients :* les fichiers Dart restent présents dans l'arbre Git jusqu'à la Phase 11.
    - *Risques :* très faible.
    - *Réversibilité :* totale.
  - **Option B — Suppression immédiate de `apps/mobile` et `packages/prism_ui` dès la Phase 1 :**
    - *Avantages :* allège immédiatement le dépôt et les scanners SAST Dart.
    - *Inconvénients :* casse les workflows CI Dart encore actifs s'ils ne sont pas retirés simultanément, et oblige à consulter l'historique Git pour lire les implémentations de référence.
    - *Risques :* moyen (impact CI).
    - *Réversibilité :* via `git revert`.
- **Recommandation :** **Option A** — geler `apps/mobile` et `packages/prism_ui` en lecture seule, découpler `test_native_prism_presentation.py:21-35` en Phase 1 pour qu'il valide les couleurs normatives du Master Prompt §21 dans `Prism`, et planifier la dépose finale de l'arbre Flutter après validation de la Phase 11.
- **Impact :** Périmètre : Phase 1 (`test_native_prism_presentation.py`) et Phase 11 (nettoyage).
- **Ce qui est bloqué :** Modification de la palette `NativePrism` / `PrismColorRole` en Phase 1 tant que `test_native_prism_presentation.py:21-35` impose l'égalité avec `prism_colors.dart`.
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : geler Flutter en lecture seule et supprimer après Phase 11 (Recommended)` (voir `docs/transformation/decisions/DR-003.md`).

---

### DR-004 — Politique de latence du feedback (`≤ 1 s` perçu en ligne) et comportement hors ligne

- **Contexte :**
  Le Master Prompt (§6.1, §6.2, §15 NS-5, §30) exige simultanément :
  1. Que la notation d'un item reste **autoritative côté serveur** (la clé de correction n'est jamais envoyée dans le package public `PublicResourceReader.swift:12-15`).
  2. Que le feedback après « Vérifier » s'affiche en **≤ 1 s perçu (p95) en ligne**, avec un indicateur de vérification au-delà de `300 ms`.
  3. Qu'en mode hors ligne, les réponses soient mises en file dans `SubmissionStore` avec affichage « Réponse enregistrée — résultat à la synchronisation », sauf si DR-004 autorise un mécanisme différent.
- **Problème :**
  Actuellement, `NativeModel.submit()` (`NativeModel.swift:1883-1939`) soumet l'ensemble de la leçon en fin de lecture (`POST /api/quiz/{lessonId}/submit`), suivi d'un appel séquentiel `refreshConfirmedProfile` (`GET /api/me`). Pour obtenir un feedback item par item en ≤ 1 s perçu pendant une Séance (Phase 4–5) sans exposer la clé de correction dans le manifeste public, il faut choisir l'architecture de vérification en ligne et la politique hors ligne.
- **Preuves :**
  - `apps/apple/CertigoKit/Sources/CertigoData/PublicResourceReader.swift:12-15,242-253` : rejet strict de `answerkey`, `correct`, `correctoptionids`, `explanation`, `solution`.
  - `apps/apple/CertigoNative/Sources/NativeModel.swift:1912-1921` : `client.submit(lessonId:submission:)` suivi de `refreshConfirmedProfile`.
  - `backend/src/Certigo.Application/Services/QuizService.cs:37-294` : `SubmitAsync` exécute 6 étapes Cosmos DB (`profile`, `attempt`, `progress`, `learnerModel`, `leaderboard`, `events`).
- **Options :**
  - **Option A (Recommandée) — Maintien strict de la clé 100 % serveur + vérification en ligne item/étape optimisée (indicateur à 300 ms, profil retourné ou rafraîchi en tâche de fond) + hors ligne honnête sans clé locale (« Réponse enregistrée — résultat à la synchronisation ») :**
    - *Avantages :* respecte à 100 % l'invariant de sécurité fondamental du dépôt (`PublicResourceReader.swift:12-15`, zéro clé de correction sur l'appareil), évite l'aller-retour bloquant `GET /api/me` avant d'afficher `FeedbackPanel`, et garantit une honnêteté totale hors ligne.
    - *Inconvénients :* hors ligne, l'apprenant ne voit le corrigé détaillé qu'à la reconnexion (sauf pour la *Situation de découverte* S-02 du 1er lancement qui est un cas pédagogique d'onboarding dédié).
    - *Risques :* faible.
    - *Réversibilité :* totale.
  - **Option B — Jeton de vérification chiffré/haché par séance pré-composée pour un feedback provisoire hors ligne, confirmé par le serveur à la reconnexion :**
    - *Avantages :* permet d'afficher l'explication hors ligne sur les 2 séances pré-composées en cache.
    - *Inconvénients :* tout secret ou condensat permettant de révéler l'explication hors ligne sur le client peut être extrait ou bruteforcé sur les QCM à 4 choix, affaiblissant l'invariant « clé jamais envoyée au client ».
    - *Risques :* élevé (sécurité / anti-triche).
    - *Réversibilité :* moyenne.
- **Recommandation :** **Option A** — conserver 100 % des clés de correction exclusivement sur le serveur (hors de l'appareil), découpler l'affichage immédiat de `FeedbackPanel` du rafraîchissement de profil en arrière-plan (pour tenir ≤ 1 s p95 en ligne avec indicateur dès 300 ms), et conserver le statut hors ligne honnête « Réponse enregistrée — résultat à la synchronisation » via `SubmissionStore`.
- **Impact :** Périmètre : Phase 4 (`session.v2`) et Phase 5 (`feedback.v2`).
- **Ce qui est bloqué :** Conception du flux « Vérifier » de `FeedbackPanel` en Phase 5.
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : notation 100 % serveur + file hors ligne sans clé exposée (Recommended)` (voir `docs/transformation/decisions/DR-004.md`).

---

### DR-005 — Retrait côté UI des gemmes, boutique, réparation payante de série, ligues XP publiques, XP/niveaux visibles et icône automatique `streakAtRisk`

- **Contexte :**
  Le Master Prompt (§7, §8, §9, §33 REMOVE) demande de retirer de l'interface :
  - les gemmes, la boutique et la réparation/gel de série payants ;
  - les ligues XP publiques à 10 paliers, l'XP comme mesure principale de progrès et les niveaux génériques ;
  - les succès de volume et les saisons mensuelles ;
  - tout message de perte, compte à rebours ou badge/icône culpabilisant.
  Sur `HEAD` `778f9c24`, le client natif `CertigoNative` n'expose ni boutique ni achat en gemmes, mais :
  1. Il affiche l'XP confirmé (`confirmedXP`), le niveau (`profile.level`), la série quotidienne (`profile.streakDays`), l'objectif d'XP quotidien (`dailyGoalXp`), les quêtes (`questCards`) et les succès (`achievementBoard`) dans `Mon apprentissage` et `Profil` (`CertigoNativeApp.swift:2889-2890,6462-6465,7279-7395`).
  2. Le widget `CertigoDailyWidget` affiche `totalXP`, `earned / goal XP` et la phase `streakAtRisk` en orange (`CertigoWidgetPresentation.swift:45,143,160`).
  3. La PR #101 (`fe708740`) a ajouté `CertigoAppIconSelection` dont le mode `.automatic` (par défaut) remplace automatiquement l'icône de l'app par `CertigoIconStreakAtRisk` (« Série à préserver ») lorsque `phase == .streakAtRisk` (`CertigoAppIconSelection.swift:60,135-142`).
- **Problème :**
  Confirmer le retrait UI de ces éléments derrière les flags `rhythm.v1` / `celebrations.v1` / `missions.v1` / `widgets.v1` tout en gardant les DTO et endpoints backend intacts (`Profile.xp`, `QuizRewards.gemsEarned`, `/quests`, `/achievements`, `/shop`, `/streak`, `/me/league`).
- **Preuves :**
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:7279-7395` : `rewards`, `questCards`, `activityMetrics`, `activityStrip`.
  - `apps/apple/CertigoNative/Sources/CertigoWidgetPresentation.swift:45,143,160` : `case .streakAtRisk`, `Text("\(snapshot.totalXP) XP")`, `Text("\(earned) / \(goal) XP")`.
  - `apps/apple/CertigoKit/Sources/CertigoDomain/CertigoAppIconSelection.swift:48,55-68,135-142` : `mode: .automatic`, `if phase == .streakAtRisk { return .streakAtRisk }`.
  - `tools/tests/test_native_prism_presentation.py:268-285` : vérifie actuellement la présence de `profile.streakDays`, `profile.level`, `profile.dailyGoalXp`, `questCards(board)` dans `NativeRoot`.
- **Options :**
  - **Option A (Recommandée) — Retrait complet côté UI en Phase 7 (`rhythm.v1`) et Phase 10 (`widgets.v1`), conservation intacte des contrats DTO/backend, et passage du sélecteur d'icône en mode manuel sans basculement `streakAtRisk` :**
    - *Avantages :* aligne intégralement l'expérience sur la Bible (§6.2, §7, §8, §9 : Rythme hebdomadaire avec 2 jours de repos, série quotidienne uniquement en opt-in sous `rhythm.dailyStreakOptIn`, aucune culpabilisation), ne casse aucun endpoint ni décodage JSON dans `CertigoDomain`, et conserve la possibilité pour l'utilisateur de choisir manuellement une icône esthétique CertiGo.
    - *Inconvénients :* nécessite de mettre à jour `test_native_prism_presentation.py:268-285` et `AppIconSelectionTests.swift` en Phase 7.
    - *Risques :* faible.
    - *Réversibilité :* totale via les flags `rhythm.v1` et `rhythm.dailyStreakOptIn`.
  - **Option B — Conserver l'affichage de l'XP et le changement automatique d'icône `streakAtRisk` en parallèle du Rythme hebdomadaire :**
    - *Avantages :* aucune modification des tests de présentation existants.
    - *Inconvénients :* viole directement les règles MUST NOT des §7, §8, §9 et §33 REMOVE du Master Prompt.
    - *Risques :* élevé (incohérence produit et rejet aux portes de validation des Phases 7 et 11).
    - *Réversibilité :* s/o.
- **Recommandation :** **Option A** — retirer l'XP/niveaux/succès de volume de l'UI sous `rhythm.v1`, désactiver tout changement automatique d'icône vers `streakAtRisk`, rendre la série quotidienne strictement opt-in (`rhythm.dailyStreakOptIn` dans `Profil` uniquement), et laisser le backend et les DTO de `Contracts.swift` intacts.
- **Impact :** Périmètre : Phase 7 (`rhythm.v1`, `celebrations.v1`, `missions.v1`) et Phase 10 (`widgets.v1`). Backend : 0 modification destructive.
- **Ce qui est bloqué :** Phase 7 (Gamification) et mise à jour finale du widget `W-1`.
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option B approuvée** : `Conserver la série quotidienne et l'icône Série en danger par défaut` (voir `docs/transformation/decisions/DR-005.md`).

---

### DR-006 — Retrait des mascottes dérivées d'icônes Azure et de tout visuel qui modifie ou imite une marque tierce (`NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCertificationCrest`)

- **Contexte :**
  Le Master Prompt (§19, §22, §22A.2, §22A.6, §33 REMOVE, §38.1) interdit formellement :
  1. Les mascottes dérivées d'icônes Azure (`packages/prism_ui/lib/src/components/aurora_mascot.dart`, `mascot_assets.dart`).
  2. Tout dessin maison, recoloration ou approximation de l'icône ou du logo d'un produit réel (`DO NOT DRAW, RECOLOR OR APPROXIMATE A REAL PRODUCT'S ICON`).
  3. Tout visuel CertiGo qui ressemble à un badge, une crête ou un sceau de certification (`MUST NOT créer un visuel CertiGo qui ressemble à un badge, une crête ou un sceau de certification`).
  4. Le logo d'entreprise Microsoft (4 carrés colorés), le logo AWS, le logo Google et l'Invertocat GitHub sans licence écrite.
- **Problème :**
  Les commits `7b7b08f2` (PR #97) et `ade19dbc` (PR #98) ont ajouté dans `CertigoNativeApp.swift:3284-3729` :
  - `NativeMicrosoftVendorBadge` (`:3291-3293,3367-3383,3432-3447`), qui dessine les 4 tuiles rouge/vert/bleu/jaune du logo d'entreprise Microsoft (`0xF25022, 0x7FBA00, 0x00A4EF, 0xFFB900`) ;
  - `NativeEcosystemEmblem` (`:3449-3679`), qui dessine en `Canvas` un « A » Azure + logo Microsoft (`:3461-3479`), les losanges Fabric + logo Microsoft (`:3480-3513`), le bouclier Security + logo Microsoft (`:3514-3536`), la silhouette de chat à oreilles/yeux Invertocat GitHub (`:3537-3582`), le sourire fléché orange AWS sur fond sombre (`:3583-3601`) et le « G » 4 couleurs Google (`:3602-3624`) ;
  - `NativeCertificationCrest` (`:3681-3729`), qui entoure ces emblèmes d'un fanion/hexagone/octogone (`NativeCrestOutline`) avec le code d'examen et `NativeMicrosoftVendorBadge`.
- **Preuves :**
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3291-3293` : `static let microsoftTileColors = Self.colors([0xF25022, 0x7FBA00, 0x00A4EF, 0xFFB900])`.
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3461-3624` : tracés `Canvas` `.microsoftAzure`, `.microsoftFabric`, `.microsoftSecurity`, `.github`, `.aws`, `.google`.
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3681-3729` : `struct NativeCertificationCrest`.
  - `tools/tests/test_native_prism_presentation.py:346-377,457-480` : `test_preparation_artwork_is_original_vector_art_not_an_earned_badge` et `test_crests_bind_exact_loaded_codes_across_real_surfaces`.
- **Options :**
  - **Option A (Recommandée) — Retirer intégralement `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCrestOutline` et `NativeCertificationCrest` en Étape 2B, les remplacer par `BrandIcon` / `BrandLabel` (niveau 1) et `BrandFallbackMark` + `RouteBadge` en texte (`.catalog`), et remplacer les 2 tests Python correspondants par `BrandAssetsTests` (§22A.10) :**
    - *Avantages :* élimine 100 % du risque juridique de contrefaçon/imitation de marques (Microsoft Corporate Logo, GitHub Invertocat, AWS Smile, Google G, badges de certification) et applique exactement l'ADR-016 / §22A du Master Prompt.
    - *Inconvénients :* nécessite de mettre à jour `test_native_prism_presentation.py:346-377,457-480` en Étape 2B.
    - *Risques :* nul sur la logique métier ; élimine un risque juridique critique (R-01).
    - *Réversibilité :* totale via Git et `brand.icons.v1`.
  - **Option B — Conserver les crêtes géométriques génériques (`facets`, `constellation`, `ribbons`) sans les logos d'éditeurs :**
    - *Avantages :* conserve une forme de blason décoratif.
    - *Inconvénients :* reste contraire au §22A.2 (« MUST NOT créer un visuel CertiGo qui ressemble à un badge, une crête ou un sceau de certification » — AWS interdit toute image qui ressemble à un badge de certification).
    - *Risques :* élevé (rejet App Review 5.2 / chartes éditeurs).
    - *Réversibilité :* faible.
- **Recommandation :** **Option A** — retirer complètement `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCrestOutline` et `NativeCertificationCrest` en Étape 2B et les remplacer par `BrandLabel` / `BrandFallbackMark` + `RouteBadge` en texte.
- **Impact :** Périmètre : Étape 2B (`CertigoNative/Sources/`, `Prism/Brand/`, `test_native_prism_presentation.py`).
- **Ce qui est bloqué :** Étape 2B et Phase 3 (aucun écran de la Phase 3 ne peut être validé tant qu'il affiche `NativeCertificationCrest`).
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : remplacer les blasons/logos maison par BrandLabel / BrandFallbackMark en étape 2B (Recommended)` (voir `docs/transformation/decisions/DR-006.md`).
---

### DR-007 — Outil de tests visuels (Snapshots) et de linting des tokens (`ArchitectureTests`)

- **Contexte :**
  Le Master Prompt (§19, §32.1, §34.1 Phase 1, §38.2) exige dès la Phase 1 :
  1. Un outil de tests de snapshots couvrant chaque composant Prism et chaque écran North Star (Clair, Sombre, Dynamic Type `.large` et `.accessibility3`, Increase Contrast, `fr` + `en` + `de`).
  2. Un target `ArchitectureTests` vérifiant par lecture des sources Swift l'absence de valeurs brutes hors `Prism/` et de modificateurs interdits sur `BrandIcon`/`BrandLabel`.
  Le §36.1 et le §38.1 interdisent d'ajouter une dépendance tierce dans `Package.swift` ou `project.pbxproj` sans Decision Request approuvée.
- **Problème :**
  Faut-il utiliser un harnais de snapshots 100 % natif fondé sur `ImageRenderer` (iOS 16+ / SwiftUI natif) sans aucune dépendance externe (recommandé par défaut au §32.1), ou ajouter la dépendance tierce `pointfreeco/swift-snapshot-testing` ?
- **Preuves :**
  - `apps/apple/CertigoKit/Package.swift:13-15` : seule dépendance actuelle = `apple/swift-crypto` (`5.0.1`, conditionnée à `.linux`).
  - `apps/apple/CertigoNative/CertigoNative.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved:1-32` : uniquement `MSAL` (`2.16.0`), `swift-asn1` (`1.7.3`) et `swift-crypto` (`5.0.1`).
  - Master Prompt §32.1 ligne 715 : « *Outil validé par DR-007 (défaut : rendu `ImageRenderer` + comparaison PNG maison, sans dépendance)* ».
- **Options :**
  - **Option A (Recommandée) — Harnais natif `ImageRenderer` + `UIHostingController` (traitOverrides Clair/Sombre/HC/AX3) + comparaison PNG déterministe en Swift pur + `ArchitectureTests` en Swift Testing sans aucune dépendance externe :**
    - *Avantages :* zéro dépendance tierce supplémentaire (surface d'attaque supply-chain nulle, `Package.resolved` inchangé), contrôle total des `UITraitCollection` (contraste élevé, taille d'accessibilité AX3/AX5, locale), exécution rapide en CI.
    - *Inconvénients :* ~150 lignes de code d'infrastructure à écrire dans `CertigoKitTests` en Phase 1.
    - *Risques :* très faible.
    - *Réversibilité :* totale.
  - **Option B — Ajouter `pointfreeco/swift-snapshot-testing` dans `CertigoKit/Package.swift` :**
    - *Avantages :* bibliothèque connue avec diff d'images intégré.
    - *Inconvénients :* ajoute une dépendance externe non officielle Apple dans `Package.resolved`, soumise aux mises à jour de Xcode/Swift 6 strict concurrency.
    - *Risques :* faible à moyen (compatibilité Swift 6 strict concurrency).
    - *Réversibilité :* moyenne.
- **Recommandation :** **Option A** — implémenter le harnais de snapshots natif (`ImageRenderer` / `UIHostingController`) et `ArchitectureTests` sans aucune dépendance externe.
- **Impact :** Périmètre : Phase 1 (Lot 1.4) et toutes les portes `VISUAL VALIDATION` des Phases 2 à 11.
- **Ce qui est bloqué :** Lot 1.4 de la Phase 1.
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : ImageRenderer natif sans dépendance + ArchitectureTests (Recommended)` (voir `docs/transformation/decisions/DR-007.md`).

---

### DR-008 — Outil d'analytics produit et politique de consentement

- **Contexte :**
  Le Master Prompt (§31) définit une taxonomie normative d'événements en `snake_case` (cycle de vie, séance, apprentissage, rituels, objectifs, habitude, social, IA, iOS, monétisation, qualité) et impose : « *aucune donnée personnelle dans les événements ; consentement explicite (UE) ; aucun SDK publicitaire ni suivi inter-apps ; pipeline via le backend existant (conteneur `events`) ou outil validé par DR-008 ; protocole `AnalyticsClient` dans `CertigoDomain`, implémentation par lot avec file hors ligne* ».
- **Problème :**
  Quel pipeline d'ingestion utiliser pour `AnalyticsClient` (pipeline first-party vers le backend Azure Functions / Cosmos DB `events` existant vs SDK tiers), et comment gouverner le consentement utilisateur ?
- **Preuves :**
  - `backend/src/Certigo.Application/Services/QuizService.cs:28,456-487` : `IEventRepository events` persiste déjà des `LearningEvent` dans le conteneur Cosmos DB `events`.
  - `apps/apple/CertigoNative/Resources/PrivacyInfo.xcprivacy:1-25` : manifeste de confidentialité Apple existant (`NSPrivacyTracking = false`, aucun domaine de tracking).
- **Options :**
  - **Option A (Recommandée) — Pipeline 100 % first-party via `AnalyticsClient` (`CertigoDomain` / `CertigoData`) envoyant des lots JSON anonymisés vers un endpoint additif `POST /api/events/batch` du backend CertiGo (conteneur Cosmos DB `events`), avec file locale bornée protégée par `completeUntilFirstUserAuthentication` et réglage explicite de consentement dans `S-78` (`Confidentialité`) :**
    - *Avantages :* aucun SDK tiers dans l'app iOS, `NSPrivacyTracking` reste `false` sans bandeau ATT requis, conformité RGPD maximale (données hébergées dans l'infrastructure Azure existante, purgées automatiquement par `AccountDeletionService`), et corrélation directe avec la North Star WDL calculée côté serveur (§3, §31).
    - *Inconvénients :* nécessite un endpoint additif léger `POST /api/events/batch` côté `backend/`.
    - *Risques :* très faible.
    - *Réversibilité :* totale (protocole `AnalyticsClient` injectable).
  - **Option B — Intégrer un SDK d'analytics tiers (ex. PostHog, TelemetryDeck ou Application Insights iOS SDK) :**
    - *Avantages :* tableaux de bord externes prêts à l'emploi.
    - *Inconvénients :* nouvelle dépendance externe (DR requise), sous-traitant RGPD supplémentaire à déclarer, mise à jour de `PrivacyInfo.xcprivacy` et des étiquettes App Store, et séparation entre les événements UI et le calcul serveur de la North Star WDL.
    - *Risques :* moyen (confidentialité et dépendance).
    - *Réversibilité :* moyenne.
- **Recommandation :** **Option A** — utiliser exclusivement le pipeline first-party via `AnalyticsClient` et le conteneur `events` du backend existant, avec opt-in/opt-out granulaire dans `S-78`.
- **Impact :** Périmètre : Phase 1 (protocole + journal Debug) et Phases 3 à 10 (émission des événements).
- **Ce qui est bloqué :** Branchement réseau de `AnalyticsClient` au-delà du journal Debug local.
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : pipeline interne CertiGo sans SDK tiers + consentement explicite (Recommended)` (voir `docs/transformation/decisions/DR-008.md`).

---

### DR-009 — Sortie du mode Démo (`NativeDemoRoot`), du simulateur de widgets et du connecteur de test hors des builds de production

- **Contexte :**
  Le Master Prompt (§14, §16 principe 6, §29, §33 IMPROVE/REMOVE) exige :
  - « *Honnête par construction — aucune donnée fictive en production* » ;
  - « *Mode Invité avec contenu public réel ; Démo et connecteur de test exclus des builds de production* ».
  L'audit de Phase 0 sur `HEAD` `778f9c24` a établi trois faits vérifiés :
  1. Dans `NativeProductionEntry` (`#if CERTIGO_PRODUCTION_DISTRIBUTION`, `CertigoNativeApp.swift:4255-4407`), le bouton `Button(copy.exploreDemo, systemImage: "play.circle") { showDemo = true }` (`:4324-4328`) et `.fullScreenCover(isPresented: $showDemo) { NativeDemoRoot() }` (`:4334`) sont **actifs dans le build de production App Store**.
  2. Dans `NativeRoot.profile` (`CertigoNativeApp.swift:7172-7180,6201-6209`), le bouton ouvrant `NativeWidgetGalleryView` est **actif en production** et affiche par défaut un mode `Simulé` avec `activeTrackCode: "DEMO"` et `totalXP: 240` (`NativeWidgetGalleryView.swift:18,255-297`).
  3. Dans `NativeRoot` (`CertigoNativeApp.swift:6038-6040,7414-7456`), la vue `connection` (saisie manuelle `baseURL` + `token`) est compilée sans garde `#if DEBUG`.
- **Problème :**
  Quand et comment retirer `NativeDemoRoot`, le mode simulé de `NativeWidgetGalleryView` et `NativeRoot.connection` des builds hors `DEBUG` sans laisser un écran d'accueil non connecté sans issue avant la livraison de l'onboarding `S-01`…`S-06` ?
- **Preuves :**
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4264,4324-4334` : `showDemo` dans `NativeProductionEntry`.
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:4584-5827` : `NativeDemoRoot` et `NativeDemoFlow` compilés sans `#if DEBUG`.
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:6201-6209,7172-7180` : `NativeWidgetGalleryView` présentée depuis `NativeRoot.profile`.
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:7414-7456` : `private var connection: some View` compilée sans `#if DEBUG`.
- **Options :**
  - **Option A (Recommandée) — Sécurisation en 2 étapes : (1) dès la Phase 1, placer `NativeDeveloperConnector`, `NativeRoot.connection` et le simulateur de widgets dans `D-1` sous `#if DEBUG` ; (2) dès que le Mode Invité sur contenu public réel est actif (`onboarding.v2`), placer `NativeDemoRoot` sous `#if DEBUG` et retirer le bouton `exploreDemo` de `NativeProductionEntry` :**
    - *Avantages :* supprime immédiatement les surfaces de test développeur et le simulateur de widgets des builds `Release`/`Distribution` dès la Phase 1, tout en garantissant qu'App Review dispose toujours d'un parcours d'exploration sans compte (Mode Démo remplacé sans trou fonctionnel par le Mode Invité sur contenu public réel).
    - *Inconvénients :* nécessite d'adapter les assertions de `test_native_prism_presentation.py` lors de la bascule de `NativeDemoRoot` vers `#if DEBUG`.
    - *Risques :* faible.
    - *Réversibilité :* totale.
  - **Option B — Supprimer `NativeDemoRoot` de `NativeProductionEntry` dès la Phase 1 avant d'avoir implémenté le Mode Invité :**
    - *Avantages :* retire immédiatement toute donnée de démonstration du build `Distribution`.
    - *Inconvénients :* jusqu'à la Phase 10 (ou l'avancement du Mode Invité), l'écran `NativeProductionEntry` n'offrirait plus aucun aperçu avant la connexion Microsoft (contraire à App Store Review Guideline 5.1.1 sur l'accès sans compte préalable).
    - *Risques :* élevé (rejet App Review si soumis avant Phase 10).
    - *Réversibilité :* totale.
- **Recommandation :** **Option A** (et, si une soumission App Store est prévue avant la Phase 10, avancer le Mode Invité / `S-01..S-05` comme le permet la note du §34.1 ligne 816).
- **Impact :** Périmètre : Phase 1 (`D-1` `#if DEBUG`) et Phase 10 (`onboarding.v2`).
- **Ce qui est bloqué :** Clôture de la porte de mise en production finale.
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : Démo et connecteur réservés à #if DEBUG, Mode Invité réel en prod (Recommended)` (voir `docs/transformation/decisions/DR-009.md`).
---

### DR-010 — Programme d'icônes officielles des éditeurs (Master Prompt §22A, Étape 2B)

- **Contexte :**
  Par décision du 22/10/2026 (Bible ADR-016 / Master Prompt §22A), lorsque CertiGo mentionne un produit ou service technologique réel dans son contenu pédagogique, l'apprenant doit voir **le vrai symbole officiel non modifié** (accompagné du nom officiel complet du produit), là où l'éditeur l'autorise (Niveau 1), et un **repli neutre CertiGo (`BrandFallbackMark`)** partout où une autorisation écrite préalable est exigée (Niveau 2) ou l'usage interdit (Niveau 3).
- **Problème :**
  L'audit des 91 parcours de `content/` (`az-900`, `az-104`, `ai-900`, `dp-900`, `sc-900`, `ms-900`, `pl-900`, `fabric-*`, `d365-*`, `power-platform-*`, `github-*`, `mos-*`, `windows-server-*`, etc.) et du catalogue de 39 certifications montre que :
  1. Les services d'architecture **Azure (V24)**, **Power Platform** (Copilot Studio, Dataverse, AI Builder, Power Fx), **Dynamics 365**, **Microsoft Fabric**, **Microsoft Entra**, **Google Cloud**, **Cisco Network Topology**, **Kubernetes Community Icons** et **GitHub Primer Octicons (MIT)** relèvent du **Niveau 1** en contextes `.diagram` et `.learningContent` (`.diagram` uniquement pour **AWS Architecture Icons**).
  2. En revanche, **23 parcours `mos-*` / `microsoft-office-specialist-*` et `m365-*`** portent sur les applications **Microsoft 365** (Word, Excel, PowerPoint, Outlook, Access, Teams, SharePoint, OneDrive, Exchange, Copilot), **Power BI / Power Apps / Power Automate / Power Pages**, **Windows / Windows Server**, les **logos et lockups GitHub** (Invertocat, GitHub Copilot), les icônes **AWS hors schémas** (`.learningContent` / `.catalog`), le **logo officiel Kubernetes / CNCF** et tout affichage en contexte **`.catalog` / `.passport`**, qui relèvent tous du **Niveau 2 (autorisation écrite requise, statut par défaut `pending-permission` → `BrandFallbackMark`)**.
  3. Les logos d'entreprise (quadricolore Microsoft, AWS, Google, Cisco, Red Hat, CompTIA, ISC2) et **tous les badges de certification** relèvent du **Niveau 3 (strictement interdit)**.
- **Preuves :**
  - `content/` : 91 répertoires de parcours (dont 20 répertoires `mos-*` + 3 `microsoft-office-specialist-*` + 3 `m365-*` + 5 `github-*` + 12 `d365-*` + 6 `power-*`/`pl-900` + 2 `fabric-*` + `windows-server-hybrid-administrator`).
  - `apps/apple/CertigoNative/Sources/CertigoNativeApp.swift:3284-3729` : `NativeEcosystemArtwork`, `NativeMicrosoftVendorBadge`, `NativeEcosystemEmblem`, `NativeCertificationCrest` (à remplacer en Étape 2B, voir **DR-006**).
  - `docs/transformation/phase-0/14_BRAND_ASSETS_AUDIT.md` & `docs/transformation/phase-0/brand_references.csv`.
- **Options :**
  - **Option A (Recommandée) — Déployer l'architecture `BrandAssets` + `BrandRegistry` en Étape 2B avec activation immédiate du Niveau 1 dans `.diagram` / `.learningContent` (budget ≤ 2 Mo), repli automatique `BrandFallbackMark` pour 100 % du Niveau 2 (`pending-permission`) et pour `.catalog`/`.passport`, interdiction stricte du Niveau 3, et envoi par le propriétaire des 4 demandes d'autorisation écrite ci-dessous :**
    - *Avantages :* débloque immédiatement l'Étape 2B et la Phase 3 en conformité juridique stricte ; dès qu'un éditeur accorde une permission écrite (archivée dans `docs/legal/brand-terms/`), le passage de `pending-permission` à `approved` dans `brand-manifest.json` active les icônes sans modifier une seule ligne de code Swift (§22A.2).
    - *Inconvénients :* les parcours MOS (Word, Excel, PowerPoint, Outlook, Access), GitHub (hors Octicons MIT) et le catalogue `.catalog` affichent `BrandFallbackMark` tant que les réponses écrites ne sont pas reçues.
    - *Risques :* très faible (politique la plus prudente).
    - *Réversibilité :* instantanée à distance par éditeur via `brand.icons.<vendor>` et globalement via `brand.icons.v1` (§22A.5, §22A.12).
  - **Option B — Attendre toutes les autorisations écrites de Niveau 2 avant d'importer le moindre kit de Niveau 1 :**
    - *Avantages :* aucun import partiel.
    - *Inconvénients :* bloque l'affichage des icônes d'architecture Azure, Fabric, Entra, Power Platform, Dynamics 365 et Octicons MIT pendant plusieurs semaines.
    - *Risques :* retard sur le rendu cible des schémas et Situations.
    - *Réversibilité :* totale.
- **Recommandation :** **Option A** — approuver la politique à 3 niveaux, le budget initial `≤ 2 Mo` pour `BrandAssets.xcassets`, le texte de non-affiliation de `BrandNoticesView` / `THIRD_PARTY_NOTICES.md` (§22A.7), et l'envoi par le propriétaire des 4 courriels de demande d'autorisation prêts ci-dessous.
- **Impact :** Périmètre : Étape 2B (`content/brands/registry.yaml`, `CertigoKit/Sources/BrandAssets`, `CertigoKit/Sources/Prism/Brand`, `docs/legal/brand-terms/`, `THIRD_PARTY_NOTICES.md`) et tous les écrans des Phases 3 à 11.
- **Ce qui est bloqué :** Démarrage de l'Étape 2B (§34.1 : exige `DR-010 APPROVED`).
- **Statut :** `APPROVED`
- **Décision du propriétaire :** `2026-10-22` — **Option A approuvée** : `Approuver : importer le Niveau 1 en étape 2B et utiliser BrandFallbackMark pour le Niveau 2 (Recommended)` + confirmation « J'accepte » pour les kits officiels de Niveau 1 en étape 2B (voir `docs/transformation/decisions/DR-010.md`).

---

## 3. Textes prêts à envoyer par le propriétaire pour les demandes d'autorisation écrite de Niveau 2 (Annexe DR-010, §22A.11)

> **Règle §22A.11 :** seul le propriétaire envoie ces demandes ; chaque réponse reçue sera archivée dans `docs/legal/brand-terms/<editeur>-permission-<AAAA-MM-JJ>.pdf` et référencée dans le champ `permissionEvidence` de `brand-manifest.json`.

### 3.1 Demande n° 1 — Microsoft Corporation (`trademarks@microsoft.com` / portail Microsoft Brand & Trademark)
- **Destinataire :** `trademarks@microsoft.com`
- **Objet :** `Trademark & Product Icon Permission Request — CertiGo Independent Educational iOS App (Microsoft 365, Power Platform, Azure & Entra Icons)`
- **Corps du message prêt à envoyer :**
```text
Dear Microsoft Trademark & Brand Licensing Team,

I am writing to request written permission for the nominative, educational use of specific Microsoft product icons within CertiGo (bundle identifier: com.certigo.mobileapp), an independent iOS training application that helps IT professionals and students learn cloud, data, security, and productivity concepts.

1. Applicant & Product Overview
- Application name: CertiGo (independent iOS application; no Microsoft mark appears in the app name, developer name, app icon, or subscription tiers).
- Purpose: interactive technical scenarios, architecture diagrams, and concept sheets aligned with official public documentation.
- Clear non-affiliation notice displayed in-app (Profile > About > Trademarks & Legal Notices) and in the App Store description:
  "CertiGo is an independent application and is not affiliated with, authorized, sponsored, or approved by Microsoft Corporation. Microsoft, Azure, Microsoft 365, Microsoft Entra, Microsoft Fabric, Dynamics 365, Power Platform, and Windows are trademarks of the Microsoft group of companies. Used with permission from Microsoft."

2. Scope of Requested Permission
(a) Confirmation of use inside an educational mobile software application for the official architecture icon sets (Azure Architecture Icons V24, Microsoft Entra Architecture Icons, Microsoft Fabric Icons, Microsoft Power Platform Icons, Dynamics 365 Icons) to identify the corresponding real services in architecture diagrams, lesson headers, and study catalog cards, unmodified and always paired with their full official product name.
(b) Written permission to display the official product/application icons for Microsoft Word, Microsoft Excel, Microsoft PowerPoint, Microsoft Outlook, Microsoft Access, Microsoft Teams, Microsoft SharePoint, Microsoft OneDrive, Microsoft Exchange, Microsoft Copilot, Microsoft Defender, Microsoft Power BI, Microsoft Power Apps, Microsoft Power Automate, Microsoft Power Pages, and Windows Server solely as nominative identifiers alongside their full official names ("Microsoft Excel", etc.) in our educational lessons and study catalog.

3. Strict Compliance Commitments
- We never use the Microsoft corporate logo, Microsoft 365/Azure lockups, or any Microsoft Certified / Microsoft Office Specialist certification badges.
- Icons are rendered strictly as provided in official vector kits (no recoloring, cropping, tinting, badges overlaid, or dark-mode inversion; displayed on a neutral plate with >= 25% clear space).
- No Microsoft icon or mark is used in the CertiGo app icon, App Store screenshots, widgets, notifications, or marketing materials.
- Our app includes a remote per-vendor kill switch capable of reverting all Microsoft icons to plain text within 48 hours upon request.

Please let us know if you can grant written confirmation for uses (a) and (b), or if any additional agreement is required.

Sincerely,
[Owner Name]
[Company / Legal Entity]
[Contact Email & Address]
```

### 3.2 Demande n° 2 — GitHub, Inc. (`brand.github.com` / `trademarks@github.com`)
- **Destinataire :** Équipe Marque / Trademarks GitHub (`trademarks@github.com`)
- **Objet :** `Brand Permission Request — Nominative Educational Use of GitHub Product Marks in CertiGo iOS App`
- **Corps du message prêt à envoyer :**
```text
Hello GitHub Brand & Trademark Team,

We are developing CertiGo, an independent iOS learning application teaching software engineering, CI/CD, security, and AI workflows. We already use non-logo Primer Octicons under the MIT License for generic concepts (pull requests, branches, workflows).

We request written permission to display the official GitHub mark (Invertocat) and product lockups/icons for GitHub Actions, GitHub Advanced Security, GitHub Copilot, and GitHub Administration strictly as nominative product identifiers alongside their full official names in our educational lesson cards and study track catalog.

Our commitments:
- We never use GitHub certification badges or imply endorsement or partnership.
- The GitHub mark is never used in our app icon, App Store screenshots, notifications, widgets, or promotional material, and is never modified, recolored, or animated.
- We include the official GitHub trademark notice, the MIT license notice for Primer Octicons, and an explicit non-affiliation disclaimer in-app and in our documentation.
- A remote kill switch allows disabling the icons within 48 hours if requested.

Could you please confirm whether this nominative educational usage is permitted in writing?

Best regards,
[Owner Name]
[Company / Legal Entity]
[Contact Email]
```

### 3.3 Demande n° 3 — Amazon Web Services (`trademarks@amazon.com` / Formulaire AWS Trademark Use Request)
- **Destinataire :** AWS Trademark Team (`https://aws.amazon.com/trademark-guidelines/`)
- **Objet :** `AWS Architecture Icons — Permission Request for Educational Concept Cards & Catalog in CertiGo iOS App`
- **Corps du message prêt à envoyer :**
```text
Hello AWS Trademark Team,

We publish CertiGo, an independent iOS educational application for cloud architecture and engineering. We use the latest quarterly AWS Architecture Icons package to render native architecture diagrams in accordance with the AWS Architecture Icons guidelines.

Because the standard AWS Architecture Icons guidance specifies "to create architecture diagrams", we are requesting written permission to also display individual AWS service icons (e.g., Amazon S3, Amazon EC2, AWS Lambda, Amazon VPC, AWS IAM) unmodified alongside their full official names ("Amazon S3", etc.) on educational concept cards, technical scenario headers, and study track catalog rows within the app.

Our commitments:
- We never use the AWS corporate logo, never use AWS Certified badges, and never use any custom crest or emblem that imitates an AWS certification badge.
- All titles use relational phrasing (e.g., "Exam preparation for AWS Certified Cloud Practitioner (CLF-C02)", "Configuring bucket policies for Amazon S3").
- Icons are never altered, never more prominent than CertiGo's own branding, and never used in the app icon, App Store screenshots, widgets, or advertising.

Thank you for considering this educational use request.

Sincerely,
[Owner Name]
[Company / Legal Entity]
[Contact Email]
```

### 3.4 Demande n° 4 — Cloud Native Computing Foundation / The Linux Foundation (`brand@linuxfoundation.org`)
- **Destinataire :** `brand@linuxfoundation.org`
- **Objet :** `Nominative Educational Use of Kubernetes® / CNCF Project Icons in CertiGo iOS App`
- **Corps du message prêt à envoyer :**
```text
Dear Linux Foundation / CNCF Brand Team,

We are building CertiGo, an independent iOS learning application covering cloud-native engineering and container orchestration. For internal Kubernetes workload resources (Pod, Deployment, Service, Ingress), we use the Kubernetes Community Icons Set under Apache-2.0 / CC-BY-4.0 with full attribution.

In accordance with the CNCF Artwork and Linux Foundation Trademark Usage Guidelines, we are writing to request prior written permission to display the unmodified Kubernetes® wheel mark (and relevant CNCF graduated project icons such as Prometheus® and Helm®) strictly as nominative identifiers alongside their official names in our educational lessons and study catalog.

Our commitments:
- We never use CKA®, CKAD®, CKS®, or KCNA® certification logos or badges.
- We include the required attribution and non-affiliation statement in-app and in our legal notices:
  "Kubernetes® is a registered trademark of The Linux Foundation in the United States and other countries. CertiGo is an independent application and is not affiliated with or otherwise sponsored by CNCF or The Linux Foundation."
- Marks are never altered, recolored, or used in our app icon, App Store screenshots, or marketing materials.

Thank you for your guidance and review.

Best regards,
[Owner Name]
[Company / Legal Entity]
[Contact Email]
```