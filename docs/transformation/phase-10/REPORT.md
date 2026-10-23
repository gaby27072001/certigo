# Phase 10 — Remaining Screens & iOS System Surfaces (`onboarding.v2`, `pro.v1`, `widgets.v1`) — Rapport de fin de phase (§39)

- **Date :** 2026-10-23
- **Branche :** `transform/phase-10-remaining-screens-ios`
- **Tag cible après fusion :** `transform-phase-10-done`
- **Feature flags associés :** `onboarding.v2`, `pro.v1`, `widgets.v1`

---

## Livrables réalisés (§14, §15 NS-1 & NS-14, §22A.7, §34.1)

1. **Premier lancement 60 s (`S-01`..`S-06`, `NS-1` — `OnboardingFlowStateMachine` & `OnboardingFlowCoverScreen`)** :
   - `S-01` Bienvenue & choix de route avec `BrandLabel` officiel (§22A.5).
   - `S-02` Situation de découverte embarquée jouable **100 % hors ligne**, atteignant la **1re décision en `<= 2` écrans** (`screensBeforeFirstDecision == 2`) et **sans aucun champ texte** (`usesFreeTextFields == false`).
   - `S-03` Premier Déclic (mini-Atlas + distribution communautaire).
   - `S-04` Objectif, Rythme hebdomadaire (3–6 j/sem) et horizon d'examen.
   - `S-05` Sauvegarder ma progression (Sign in with Apple / Passkey / Microsoft Entra CIAM / Google fédéré, préservant MSAL/CIAM).
   - `S-06` Autorisation des notifications demandée **uniquement après la 1re séance complétée** (`canPromptForNotifications`).
2. **CertiGo Pro StoreKit 2 (`S-73`, `pro.v1` — `CertigoProPaywallModel` & `CertigoProSheetScreen`)** :
   - Strictement bloqué tant que l'apprenant n'a pas vécu la première valeur d'apprentissage (`showsPaywallBeforeFirstValue == false`, `canPresentPaywall`).
   - Cycles mensuel / annuel transparents, restauration des achats StoreKit 2, aucun compte à rebours artificiel (`hasManipulativeCountdownTimer == false`) et aucune vente de gel de série ni de gemmes (`DR-005`).
3. **Réglages complets (`S-74`..`S-84` — `CompleteSettingsScreen`) & Suppression du compte (`S-82` — `AccountDeletionConfirmationModel`)** :
   - Couvre les 10 sections (`S-75` Rythme & rappels, `S-76` Langue FR/EN, `S-77` Mode Calme/sons/haptique, `S-78` Confidentialité `NS-12`, `S-79` IA & consentement cloud, `S-80` Données hors ligne, `S-81` Compte, `S-82` Suppression du compte, `S-83` À propos des données/méthode/licences `BrandNoticesView`, `S-84` Aide & signaler).
   - `S-82` exige une confirmation explicite avant d'appeler la suppression serveur et de purger immédiatement Keychain, cache hors ligne et snapshots WidgetKit.
4. **Surfaces système iOS (`W-1`..`W-3`, `NS-14`, `LA-1`..`LA-3`, `CC-1`, `AI-1` — `SystemSurfacesPreviewScreen`)** :
   - **Widgets (`W-1` Aujourd'hui, `W-2` Situation du jour, `W-3` Carte de révision `NS-14`)** : `ReviewCardWidgetQueueModel` met la réponse en file sans ouvrir l'app (`queuesResponseWithoutOpeningApp == true`), sans stocker de corrigé dans le conteneur widget (`DR-004`) et sans icône de marque tierce dans l'extension widget (§22A.7).
   - **Live Activities (`LA-1` Examen blanc, `LA-2` Plongée, `LA-3` Jour J)** : `CertigoLiveActivityState` avec mode sans limite (`NS-11`) et zéro logo tiers sur l'écran verrouillé / Dynamic Island (§22A.7).
   - **Control Center (`CC-1`)** : contrôle `Express 5 min` (`certigo://session/express?duration=5`).
   - **App Intents & Spotlight (`AI-1`)** : 4 intents système (`CertigoAppIntentKind`) et entités Spotlight (`CertigoSpotlightConceptEntity`).

---

## Les 7 portes de fin de phase (§34.2)

### 1. BUILD
- `swift test --package-path apps/apple/CertigoKit -Xswiftc -warnings-as-errors` : **0 erreur, 0 warning**.

### 2. TEST
- Suites Swift (`CertigoKitTests` + `ArchitectureTests` + `BrandAssetsTests`) : **241 / 241 tests verts** (`187` XCTest + `54` Swift Testing dont `5` nouveaux tests dans `Phase10OnboardingAndSystemSurfacesTests`).
- Suites Python (`tools/tests`) : **100 % vert** (incluant `test_phase10_onboarding_and_system_surfaces.py` et `test_native_extraction.py`).

### 3. VISUAL VALIDATION
- Tous les écrans Phase 10 utilisent exclusivement `PrismColor`, `PrismSpacing`, `PrismCard`, `PrismBadge`, `PrismSection`, `RegionChip` et `BrandLabel` (§22A.5 / §22A.7).

### 4. ACCESSIBILITY VALIDATION
- Parcours d'onboarding `NS-1` sans saisie clavier obligatoire (boutons larges `>= 44x44 pt`, `PrismAdaptiveStack` pour Dynamic Type AX5).

### 5. PERFORMANCE CHECK
- Situation de découverte `S-02` et file `NS-14` opèrent localement en `O(1)` sans latence réseau bloquante.

### 6. ANALYTICS & FEATURE FLAGS
- Protégé derrière `onboarding.v2`, `pro.v1` et `widgets.v1`, configurables dans `PrismDebugGalleryView` (`D-1`).

### 7. SELF-REVIEW
- `ArchitectureTests` : **0 violation** sur l'ensemble des sources migrées.
- `test_native_extraction.py` : **OK**.
