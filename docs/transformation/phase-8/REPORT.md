# Phase 8 — Social, Collaborative & Competitive (`social.v2`) — Rapport de fin de phase (§39)

- **Date :** 2026-10-23
- **Branche :** `transform/phase-8-social-collaborative`
- **Tag cible après fusion :** `transform-phase-8-done`
- **Feature flags associés :** `social.v2` (`FeatureFlag.socialV2`)

---

## Livrables réalisés (§10, §14, §15 NS-12, §22A.5, §34.1)

1. **Modèle de confidentialité granulaire, sécurité et modération (`SocialPrivacySettingsModel`, `SocialModerationState`, `SocialDeferredFeaturesPolicy`)** :
   - **Privé par défaut (`NS-12`)** : pseudonyme (`Apprenant-Az7`), visibilité granulaire (`Rythme`, `Jalons`, `Situations`, `Passeport`) désactivée par défaut, ligues désactivées par défaut (`progressionLeaguesOptIn = false`).
   - **Invariants de sécurité (§10)** : aucun import de carnet d'adresses (`allowsContactImport == false`), aucune localisation (`sharesLocation == false`), aucun échec affiché à autrui (`exposesFailuresToOthers == false`), aucun texte libre au lancement (`allowsFreeTextChat == false`), consentement explicite obligatoire avant d'intégrer une Squad (`requiresExplicitSquadConsent == true`).
   - **Mode mineur (`Declared Age Range`)** : désactive automatiquement le partage de liens externes, l'opt-in aux ligues de progression, le partage employeur et toute exposition de visibilité.
   - **Modération en 1 geste** : bloquer (`blockPeer`), masquer (`hidePeer`) et signaler (`reportPeer` avec motif prédéfini `SocialReportReason`) filtrent immédiatement le pair hors des listes d'amis et d'activités.
   - **Garde-fou v1 (`SocialDeferredFeaturesPolicy`)** : bloque explicitement le chat libre, les salles d'étude en direct, les duels temps réel et le fil d'activité public.
2. **Historique des Situations du jour (`S-31` — `DailySituationHistoryEntry` & `DailySituationHistoryScreen`)** :
   - Affiche chaque situation passée avec `BrandLabel` officiel (§22A.5), statut de réponse et `CommunityDistributionChart` (verrouillé tant que non répondu, visible après réponse).
   - Permet de générer la carte de partage sans divulgâcher (`S-95` `PrismShareCardPayload`, sans icône ni marque tierce conformément à §22A.7).
3. **Squads coopératives 3 à 8 (`S-61` `SquadDetailScreen` & `S-62` `CreateOrJoinSquadSheetScreen`)** :
   - Objectif hebdomadaire commun calculé côté serveur, contributions anonymisées par défaut (initiales `AvatarMonogram`), appariement optionnel par route (`BrandLabel`) et mois d'examen.
   - Encouragements prédéfinis en 1 tap (`PrismKudosPreset` : *Rythme solide*, *Bel ancrage*, *Raisonnement clair*, *Continue ainsi*) sans texte libre et sans jamais exposer les échecs individuels.
4. **Amis, Profil ami & Invitation privée (`S-63` `FriendsListScreen`, `S-64` `FriendProfileScreen`, `S-67` `InviteFriendSheetScreen`)** :
   - Découverte par lien (`certigo://ensemble/invite/<code>`), code court ou QR (`FriendInvitePayload`), sans aucun import de contacts.
   - `FriendProfileScreen` affiche uniquement les sections explicitement partagées par l'ami (`0 échec exposé`), permet de lancer un défi asynchrone (`S-65`) et intègre les contrôles *Masquer / Bloquer / Signaler*.
5. **Défi asynchrone 5 situations sans chronomètre (`S-65` — `AsyncChallengeStateMachine` & `AsyncChallengeCoverScreen`)** :
   - Même jeu de 5 situations appariées par cote Glicko-2, **sans chronomètre** (`hasTimer == false`), score = `justesse × calibration`, sans exposer les erreurs par item de l'adversaire.
6. **Ligues de progression Glicko-2 opt-in (`S-66` — `ProgressionLeagueModel` & `ProgressionLeaguesScreen`)** :
   - Désactivées par défaut (`NS-12`), appariées par cote Glicko-2 et route (`BrandLabel`), plafond quotidien de points de maîtrise (`120 pts/jour`), **aucune relégation les 4 premières semaines** (`noDemotionProtectedWeeks = 4`), **2 semaines de grâce** (`maxGraceWeeks = 2`) et affichage limité à **±3 voisins** autour de l'apprenant (`<= 7` lignes).
7. **Hub complet Ensemble (`S-60` — `EnsembleCompleteScreen`) & Galerie Debug (`D-1`)** :
   - Assemble l'état de confidentialité `NS-12`, la Squad coopérative, les défis 5 situations, la liste d'amis, les ligues Glicko-2 opt-in et l'historique des Situations `S-31`.

---

## Les 7 portes de fin de phase (§34.2)

### 1. BUILD
- `swift test --package-path apps/apple/CertigoKit -Xswiftc -warnings-as-errors` : **0 erreur, 0 warning**.

### 2. TEST
- Suites Swift (`CertigoKitTests` + `ArchitectureTests` + `BrandAssetsTests`) : **230 / 230 tests verts** (`187` XCTest + `43` Swift Testing dont `9` nouveaux tests dans `Phase8SocialAndCollaborativeTests`).
- Suites Python (`tools/tests`) : **100 % vert** (incluant `test_phase8_social_collaborative.py` et `test_native_extraction.py`).

### 3. VISUAL VALIDATION
- Tous les écrans Phase 8 (`S-31`, `S-60`..`S-67`) utilisent exclusivement les tokens `PrismColor`, `PrismSpacing`, `PrismCard`, `PrismBadge`, `PrismSection` et `BrandLabel` (§22A.5).
- Les cartes de partage `S-95` issues de `S-31` respectent §22A.7 (`spoilerViolations.isEmpty == true`, aucune icône ni marque tierce exportée).

### 4. ACCESSIBILITY VALIDATION
- `BrandLabel` combine l'icône officielle et le nom complet en un seul élément VoiceOver (§22A.8).
- Les états `NS-12` (privé par défaut, ligues désactivées, contributions anonymisées) et les contrôles de modération (*Masquer / Bloquer / Signaler*) sont exposés sous forme de boutons système accessibles au clavier et à VoiceOver, sans geste complexe ni chronomètre (`hasTimer == false`).

### 5. PERFORMANCE CHECK
- `ProgressionLeagueModel.visibleNeighborStandings` borne la vue à `<= 7` entrées (`±3` voisins), évitant tout rendu de liste longue.
- Aucun SDK tiers ajouté ; budget binaire et mémoire inchangé.

### 6. ANALYTICS & FEATURE FLAGS
- Protégé derrière `FeatureFlag.socialV2` (`social.v2`), activable/désactivable à chaud dans `PrismDebugGalleryView` (`D-1`).

### 7. SELF-REVIEW
- `ArchitectureTests` : **0 violation** sur l'ensemble des sources migrées (`LegacyExceptions.json` inchangé).
- `test_native_extraction.py` : **OK** (aucun fichier de `EXTRACTED_FILES` modifié).
