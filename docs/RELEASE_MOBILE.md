# Release mobile — Pipeline & runbooks

Documentation opérationnelle pour publier les bêtas Certigo.
**Décision active : Alpha iOS interne uniquement.** Le pipeline cible est :
`code figé → gates → build signée → TestFlight Internal Testers`.

> [!IMPORTANT]
> L'Alpha reste limitée à la boucle coeur existante et au Tuteur IA déterministe.
> Android, les tests externes et toute nouvelle feature sont hors périmètre. Cette
> documentation ne déclenche aucun tag, build, upload ou changement de store.

> 🔐 **Aucun secret n'est committé.** Toutes les valeurs sensibles vivent dans
> Azure Key Vault, GitHub Actions ou les variables sécurisées Codemagic (ou en
> local dans des fichiers ignorés par git). Ce document ne contient que des
> **noms** de secrets et des **commandes**.

---

## 1. Vue d'ensemble

```
                    ┌─────────────────────────────────────────────────────┐
  lancement manuel ▶│  Codemagic (Mac M2) — Alpha iOS                    │
  sur SHA candidat  │  ios-release-dry puis ios-release                  │
                    │   1. Flutter 3.44.4 + analyze + test               │
                    │   2. intégration AppStoreConnect + variables        │
                    │   3. signature + IPA versionnée                     │
                    │   4. dry-run sans upload                            │
                    │   5. upload TestFlight → Internal Testers           │
                    └─────────────────────────────────────────────────────┘
```

| Élément | Valeur |
|---|---|
| App Flutter | `apps/mobile` |
| applicationId Android / bundle id iOS | `com.certigo.mobileapp` (identique sur les deux plateformes) — ⚠️ identifiants store stables |
| Nom affiché | Certigo |
| versionName | lu depuis `apps/mobile/pubspec.yaml` (`version:` → partie avant `+`) |
| versionCode / build number | Android : `github.run_number` ; iOS : `PROJECT_BUILD_NUMBER` Codemagic ; override possible |
| Workflows | `release-android.yml` (techniquement actif, hors Alpha), `release-ios.yml` + `sync-ios-certs.yml` (legacy, opt-in par types `repository_dispatch` dédiés) ; iOS actif géré par Codemagic |
| CI inchangée | `ci-mobile.yml` (format/analyze/test) — aucune régression |

Les workflows GitHub de release n'utilisent aucune action de cache Flutter/Pub. Ils téléchargent
Flutter dans un répertoire neuf, vérifient le SHA-256 figé de l'archive avant exécution, utilisent
un `PUB_CACHE` propre au run et suppriment SDK/cache pendant le nettoyage. Un SDK ou cache produit
par une analyse de PR ne peut donc jamais entrer dans une build signée.

> ⚠️ **`com.certigo.mobileapp` est l'identifiant unifié** (Android `applicationId`
> = iOS bundle id). Il est définitif une fois la première build store uploadée.
> S'il change, mettre à jour : `apps/mobile/android/app/build.gradle`
> (`applicationId` + `namespace`), `PLAY_PACKAGE_NAME` dans `release-android.yml`,
> les `PRODUCT_BUNDLE_IDENTIFIER` de `apps/mobile/ios/Runner.xcodeproj/project.pbxproj`,
> `codemagic.yaml` (`bundle_identifier` + `BUNDLE_ID` + clé `provisioningProfiles`),
> et les fiches store (Play + App Store Connect).

### 1.1 Vérité opérationnelle au 4 septembre 2026

Les statuts ci-dessous séparent strictement :

- **historique prouvé** : un état externe a été observé à une date donnée ;
- **vérifié aujourd'hui** : vérifiable sans secret dans le dépôt ou sur GitHub ;
- **manuel restant** : l'état live doit être revérifié par un opérateur avant l'Alpha.

| Surface | Historique prouvé | Vérifié le 2026-09-04 | Manuel restant / décision |
|---|---|---|---|
| App iOS | App Certigo existante dans App Store Connect, bundle `com.certigo.mobileapp` | Bundle toujours aligné dans le projet Xcode et `codemagic.yaml` ; tag [`v1.0.1`](https://github.com/gchambaud_microsoft/Certigo/commit/38132bda3e60f54bb4cb2c12542accb364792e74) présent | Ouvrir **l'app existante** et confirmer contrats/accès ; ne pas recréer l'app |
| TestFlight | Capture opérateur du 2026-08-17 : groupe `Internal Testers`, build `1.0.1 (8)` du 2026-07-03 traité, au moins une installation et cinq sessions | Le workflow versionné publie toujours vers `Internal Testers` | Un nouveau build candidat doit être traité puis installé ; l'ancien build n'est pas le candidat Alpha |
| Codemagic + ASC | Les builds ont réellement atteint successivement la signature puis l'upload Apple : [#161](https://github.com/gchambaud_microsoft/Certigo/pull/161), [#163](https://github.com/gchambaud_microsoft/Certigo/pull/163), puis build TestFlight traité | `codemagic.yaml` référence encore l'intégration `AppStoreConnect` et le groupe `certigo_mobile_config` | Confirmer dans le dashboard que l'app, la clé ASC et le groupe existent encore et sont valides ; ne pas les recréer/faire tourner par défaut |
| Google Play | Preuve opérateur du 2026-08-17 : app encore en brouillon et liste `Certigo - Test interne` créée/sélectionnée avec des testeurs | Workflow Android et package toujours présents dans le dépôt | **Hors Alpha.** Aucun AAB final ni release interne n'est prouvé ; ne pas présenter Google Play comme publié ou entièrement opérationnel |
| Crash mobile | Capture locale des erreurs livrée par [#213](https://github.com/gchambaud_microsoft/Certigo/pull/213) | `LoggingCrashReporter` utilise encore `debugPrint` ; aucun sink distant ni upload de symboles dans les pipelines | **Bloquant Alpha** : sink distant, symboles et crash de test visible dans le dashboard |

La capture App Store Connect et les confirmations Google Play sont des attestations
opérateur datées conservées dans l'historique de travail. Elles prouvent un usage
antérieur, pas la validité actuelle des credentials, contrats ou intégrations. Les
PR #161/#163 documentent les erreurs renvoyées par de vrais runs Codemagic ; le build
TestFlight traité établit que la chaîne Codemagic → App Store Connect a ensuite
fonctionné. Aucune de ces preuves historiques ne ferme une gate live de l'Alpha.

### 1.2 Scope gelé de l'Alpha iOS

**Inclus :**

- iOS via **TestFlight interne** uniquement, sur l'identifiant existant
  `com.certigo.mobileapp` ;
- boucle coeur déjà implémentée : authentification, catalogue/parcours, leçon,
  quiz, score/progression et retour d'explication ;
- Tuteur IA en mode **déterministe** : `TUTOR_LLM_ENABLED=false`, donc
  `NullTutorCompletion` et réponses ancrées sur le contenu existant ;
- correctifs strictement nécessaires pour fermer une gate de qualité, crash,
  release ou authentification.

**Exclus jusqu'à la clôture de l'Alpha :**

- Android/Google Play, TestFlight externe et publication App Store publique ;
- Azure OpenAI/Foundry live pour le Tuteur, nouvelle feature, nouveau type de
  contenu, extension de la gamification ou refonte UI ;
- création d'une nouvelle app Codemagic, App Store Connect ou Play Console,
  rotation préventive de clés et changement de bundle/package.

### 1.3 Gates bloquantes — ordre de fermeture

Toutes les gates doivent porter une preuve datée sur le **même commit candidat**.
Une preuve de juillet/août ne peut pas remplacer une exécution actuelle.

| Gate | Critère de sortie | Preuve à consigner |
|---|---|---|
| G0 — Scope et CI | Diff candidat sans nouvelle feature ; `ci-mobile` vert | SHA candidat + URL du run |
| G1 — Crash distant | Exceptions Flutter/moteur/zone envoyées vers un sink distant ; symboles dSYM uploadés ; crash de test lisible | URL/ID du dashboard, horodatage UTC, stack symboliquée |
| G2 — Intégrations live | App Codemagic existante connectée au repo ; intégration `AppStoreConnect`, clé ASC, groupe `certigo_mobile_config`, contrat de domaine public, app ASC et `Internal Testers` valides | Contrôle opérateur daté, sans valeur secrète |
| G3 — Dry-run | `ios-release-dry` réussit depuis le SHA candidat, produit une IPA signée et n'uploade rien | URL/ID du build Codemagic + SHA |
| G4 — Build TestFlight | `ios-release` produit un nouveau build traité et affecté à `Internal Testers` | URL/ID Codemagic + version/build ASC |
| G5 — Auth/E2E appareil | Build G4 installé sur iPhone physique ; auth réelle puis catalogue → leçon → quiz → progression → Tuteur déterministe ; crash distant vérifié | Appareil/iOS, testeur, date UTC, résultats et IDs de corrélation non sensibles |
| G6 — Go/No-Go | G0 à G5 closes, aucun crash bloquant, rollback identifié | Décision humaine datée |

Pour cette PR documentaire : **ne créer aucun tag, ne démarrer aucun workflow de
release/dry-run, ne faire aucun upload et ne modifier aucun store**.

---

## 2. Gestion des secrets

Deux approches, **interchangeables sans modifier les workflows** : si la variable
de dépôt `AZURE_KEYVAULT_NAME` est définie, les workflows lisent les secrets
depuis **Azure Key Vault** (recommandé) ; sinon ils retombent automatiquement sur
les **secrets GitHub**.

### 2.1 Recommandé — Azure Key Vault (zéro secret dans GitHub) ⭐

Les secrets de signature vivent dans le Key Vault `kv-certigo-prod-<suffixe>`
(déjà déployé par `infra/`), lus à la volée par l'**identité managée du runner**.
Rien n'est stocké dans GitHub ; la rotation se fait en un seul endroit.

**Mise en place (une fois)**

1. **Identité managée du runner** : active une identité (system-assigned) sur la
   VM du runner et récupère son `principalId` :
   ```bash
   az vm identity assign -g rg-certigo-ci -n <vm-runner>
   az vm show -g rg-certigo-ci -n <vm-runner> --query identity.principalId -o tsv
   ```
2. **Droit de lecture sur le Key Vault** — au choix :
   - via Bicep (IaC) : redéploie `infra/main.bicep` avec
     `--parameters ciRunnerPrincipalId=<principalId>` *(nécessite des droits
     d'attribution de rôle au scope du Key Vault)* ; ou
   - en direct :
     ```bash
     az role assignment create --assignee <principalId> \
       --role "Key Vault Secrets User" \
       --scope $(az keyvault show -n <kv-name> --query id -o tsv)
     ```
3. **Variable de dépôt** (non sensible) désignant le vault à utiliser :
   ```bash
   gh variable set AZURE_KEYVAULT_NAME --body 'kv-certigo-prod-<suffixe>'
   ```
4. **Charger les secrets dans le Key Vault** (une seule commande) :
   ```powershell
   Copy-Item tools/secrets/mobile-secrets.env.example tools/secrets/mobile-secrets.env  # puis renseigne-le
   ./tools/secrets/set-keyvault-secrets.ps1 -VaultName kv-certigo-prod-<suffixe>
   ```
   *(`mobile-secrets.env` est gitignoré ; le script encode keystore / certificat /
   profil / clé en base64 et pousse chaque valeur. `-DryRun` pour prévisualiser.)*

**Noms des secrets dans le Key Vault**

| Secret Key Vault | Plateforme | Contenu |
|---|---|---|
| `mobile-android-keystore-base64` | Android | Keystore upload (.jks) base64 |
| `mobile-android-keystore-password` | Android | Mot de passe du keystore |
| `mobile-android-key-alias` | Android | Alias de la clé |
| `mobile-android-key-password` | Android | Mot de passe de la clé |
| `mobile-play-service-account-json` | Android | JSON du compte de service Play |
| `mobile-ios-dist-cert-p12-base64` | iOS | Certificat distribution (.p12) base64 |
| `mobile-ios-dist-cert-password` | iOS | Mot de passe du .p12 |
| `mobile-ios-provisioning-profile-base64` | iOS | Profil (.mobileprovision) base64 |
| `mobile-ios-provisioning-profile-name` | iOS | Nom exact du profil |
| `mobile-ios-team-id` | iOS | Team ID Apple |
| `mobile-asc-key-id` | iOS | App Store Connect Key ID |
| `mobile-asc-issuer-id` | iOS | App Store Connect Issuer ID |
| `mobile-asc-key-p8-base64` | iOS | Clé API (.p8) base64 |
| `mobile-ios-match-password` | iOS | Passphrase fastlane match (si match utilisé) |
| `mobile-ios-match-git-auth` | iOS | Auth git base64 du repo de certs match (si match utilisé) |

> 🔐 Rotation = changer **une** valeur dans le Key Vault, rien côté GitHub. Accès
> en lecture seule (rôle *Key Vault Secrets User*), tracé dans les logs du Key
> Vault → Application Insights. Le runner doit avoir **Azure CLI** installé.

### 2.2 Repli — Secrets GitHub Actions

Utilisé automatiquement si `AZURE_KEYVAULT_NAME` n'est **pas** définie.
`Settings → Secrets and variables → Actions → New repository secret`.

| Secret | Plateforme | Usage |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Android | Keystore upload (.jks) encodé base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Android | Mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | Android | Alias de la clé (ex : `upload`) |
| `ANDROID_KEY_PASSWORD` | Android | Mot de passe de la clé |
| `PLAY_SERVICE_ACCOUNT_JSON` | Android | JSON du compte de service Google Play |
| `IOS_DIST_CERTIFICATE_P12_BASE64` | iOS | Certificat de distribution (.p12) en base64 |
| `IOS_DIST_CERTIFICATE_PASSWORD` | iOS | Mot de passe du .p12 |
| `IOS_PROVISIONING_PROFILE_BASE64` | iOS | Profil d'approvisionnement App Store (.mobileprovision) base64 |
| `IOS_PROVISIONING_PROFILE_NAME` | iOS | Nom EXACT du profil (ex : `Certigo Beta App Store`) |
| `IOS_TEAM_ID` | iOS | Team ID Apple Developer (10 caractères) |
| `ASC_KEY_ID` | iOS | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | iOS | App Store Connect Issuer ID |
| `ASC_KEY_P8_BASE64` | iOS | Clé API App Store Connect (.p8) en base64 |

> `PLAY_SERVICE_ACCOUNT_JSON` est obligatoire pour toute exécution non
> `dry_run`. Son absence fait échouer le workflow avant publication. Un dry-run
> peut construire l'AAB sans ce compte de service.

### 2.3 Configuration app (dart-define) — social login & API ⚙️

> ⚠️ **Sans cette configuration, l'app buildée est dégradée** : les boutons de
> connexion Google / Apple / Microsoft n'apparaissent pas (`entraConfigured ==
> false`) et le login e-mail échoue avec « Pas de connexion… » (l'app retombe
> sur l'URL d'API par défaut, non déployée). Ces valeurs sont **injectées au
> build** via `--dart-define` par `release-android.yml` (étape `appconfig`) et
> `codemagic.yaml`.

Ces valeurs **ne sont pas des secrets cryptographiques** : elles finissent dans
le **binaire public** de l'app. On les stocke donc comme **variables** GitHub
(`vars.*`), pas comme secrets — Key Vault reste la source prioritaire (même
motif que la signature). **Aucune valeur réelle n'est committée** ; seuls des
noms sont référencés dans le code.

**Android — Key Vault (prioritaire) → repli variable GitHub `vars.*`**

| Valeur | Secret Key Vault | Repli variable GitHub | Format / exemple |
|---|---|---|---|
| URL de base API | `mobile-app-api-base-url` | `vars.MOBILE_API_BASE_URL` | `https://func-certigo-prod-izfhvvxjdxc2k.azurewebsites.net/api` |
| Entra client ID | `mobile-entra-client-id` | `vars.MOBILE_ENTRA_CLIENT_ID` | GUID App Registration mobile |
| Entra authority | `mobile-entra-authority` | `vars.MOBILE_ENTRA_AUTHORITY` | `https://<tenant-guid>.ciamlogin.com/<tenant-guid>/v2.0` |
| Entra API scope | `mobile-entra-api-scope` | `vars.MOBILE_ENTRA_API_SCOPE` | `api://<backend-client-id>/user_impersonation` |
| Env (flavor) | `mobile-app-env` | `vars.MOBILE_CERTIGO_ENV` | `prod` uniquement |

- **Via Key Vault (recommandé)** : renseigner `API_BASE_URL`, `CERTIGO_ENV`,
  `ENTRA_CLIENT_ID`, `ENTRA_AUTHORITY`, `ENTRA_API_SCOPE` dans
  `tools/secrets/mobile-secrets.env` puis lancer `set-keyvault-secrets.ps1`
  (§2.1). Le script crée les secrets `mobile-app-*` / `mobile-entra-*`.
- **Via variables GitHub (repli)** : `Settings → Secrets and variables →
  Actions → Variables → New repository variable` pour chaque `MOBILE_*`
  ci-dessus. (Onglet **Variables**, pas **Secrets**.)

> 🔒 **Gate bloquant de build** : pour toute exécution, y compris `dry_run`, les
> cinq valeurs sont obligatoires et validées strictement. La configuration doit
> cibler la production : URL API Certigo HTTPS en `/api`, GUID client non
> placeholder, authority External ID canonique dont l'hôte GUID correspond au
> tenant GUID du chemin, scope `api://...` non placeholder et
> `MOBILE_CERTIGO_ENV=prod`. La source est le Key Vault désigné par
> `AZURE_KEYVAULT_NAME`, sinon les variables `MOBILE_*` au scope environnement ou
> dépôt. La variable legacy `API_BASE_URL` et les anciennes valeurs Microlingo ne
> sont jamais lues. Les valeurs live sont corrigées hors de cette PR.

**iOS — groupe de variables Codemagic `certigo_mobile_config`**

Codemagic n'a pas accès au Key Vault : créer dans le dashboard Codemagic
(**Settings → Environment variables**) un **groupe** nommé `certigo_mobile_config`
contenant `PROD_API_BASE_URL`, `ENTRA_CLIENT_ID`, `ENTRA_AUTHORITY`,
`ENTRA_API_SCOPE`, `SENTRY_DSN`, `SENTRY_ORG`, `SENTRY_PROJECT`,
`SENTRY_AUTH_TOKEN` et `CERTIFICATE_PRIVATE_KEY`. `codemagic.yaml` référence ce
groupe et injecte uniquement les valeurs publiques utiles à l'app en
`--dart-define` ; `CERTIGO_ENV` est fixé inline (`prod` pour `ios-release`,
`dev` pour `ios-release-dry`, `staging` pour `ios-crash-smoke`). Le token Sentry
et la clé privée de signature ne sont jamais injectés dans le binaire.

---

## 3. Android

### 3.1 Pré-requis du runner self-hosted

Le runner `certigo-trusted` (Linux X64) ne réutilise aucun Flutter/Dart préinstallé : le workflow
installe un SDK Flutter neuf dont l'archive est contrôlée par SHA-256. Il installe aussi
**JDK 17** et le **SDK Android** (`android-actions/setup-android` + `sdkmanager`), donc aucune
action manuelle supplémentaire n'est nécessaire. L'egress internet passe par la NAT Gateway
`certigo-trusted` (voir le runbook CI).

### 3.2 Générer le keystore upload (one-time, en local)

Le keystore **upload** signe l'AAB ; Google Play le re-signe ensuite avec la clé
d'application (Play App Signing). **Sauvegardez ce keystore et ses mots de passe
en lieu sûr** (sa perte est irréversible).

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

### 3.3 Encoder et enregistrer les secrets Android

> 💡 Avec **Key Vault** (§2.1, recommandé), saute cette étape : charge tout via
> `set-keyvault-secrets.ps1`. Les commandes ci-dessous concernent le **repli
> secrets GitHub**.

Encoder le keystore en base64 :

```bash
# Linux / macOS
base64 -w0 upload-keystore.jks > keystore.b64
```
```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Out-File keystore.b64 -NoNewline -Encoding ascii
```

Créer les secrets (via l'UI GitHub, ou `gh`) :

```bash
gh secret set ANDROID_KEYSTORE_BASE64   < keystore.b64
gh secret set ANDROID_KEYSTORE_PASSWORD --body '<mot_de_passe_keystore>'
gh secret set ANDROID_KEY_ALIAS         --body 'upload'
gh secret set ANDROID_KEY_PASSWORD      --body '<mot_de_passe_cle>'
```

> Supprimez ensuite `keystore.b64` du disque. Ne committez jamais le `.jks`
> (déjà couvert par `.gitignore`).

### 3.4 Réconcilier Google Play existant (hors Alpha iOS)

> [!NOTE]
> État historique prouvé le 2026-08-17 : l'app existait encore en brouillon et la
> liste `Certigo - Test interne` était créée/sélectionnée. Aucune preuve ne ferme
> aujourd'hui Play App Signing, le compte de service ou une première release AAB.
> Ne pas créer de doublon ; ouvrir l'app existante et reprendre au premier contrôle
> manquant uniquement lors d'une future release Android.

1. **Ouvrir l'application existante** dans la
   [Google Play Console](https://play.google.com/console) et confirmer le package
   `com.certigo.mobileapp`. Si elle est introuvable, arrêter et faire réconcilier
   le compte propriétaire au lieu d'en créer une autre.
2. **Vérifier Play App Signing** (à activer au 1er upload seulement si la console
   confirme qu'il ne l'est pas).
3. **Compte de service** : dans Google Cloud, créez un compte de service, générez
   une **clé JSON**. Dans la Play Console → *Configuration → accès à l'API* →
   liez le compte de service et accordez-lui au minimum le rôle permettant de
   *gérer les versions de test* (Release manager).
4. Enregistrer la clé JSON en secret :
   ```bash
   gh secret set PLAY_SERVICE_ACCOUNT_JSON < service-account.json
   ```
5. **Réutiliser la liste "Certigo - Test interne"** et vérifier la piste. La
   première release n'est pas prouvée et peut devoir être ajoutée manuellement
   selon l'état d'enrôlement ; les suivantes passent par le workflow.

### 3.5 Runbook — Lancer une beta Android (manuel) ✅

1. Depuis un compte autorisé en écriture, envoyer le dispatch chargé depuis la
   branche par défaut :
   ```bash
   gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input - <<'JSON'
   {
     "event_type": "release-android",
     "client_payload": {
       "track": "internal",
       "version_name": "0.1.0",
       "dry_run": false
     }
   }
   JSON
   ```
2. `track` et le booléen JSON `dry_run` sont obligatoires. `version_name` peut
   être omis (= pubspec) et `build_number` peut être omis (= numéro de run).
   Tout champ supplémentaire ou type incorrect fait échouer le run.
3. Le workflow exécute les **gates** (`analyze` + `test`), construit l'**AAB
   signé**, l'**uploade** sur la piste choisie, puis nettoie les secrets.
   `version_name` doit être un SemVer strict, `build_number` un entier positif
   ≤ 2 100 000 000 et `track` l'une de `internal|alpha|beta|production`.
4. Dans la Play Console, ajouter les testeurs (e-mails ou liste) et partager le
   **lien d'opt-in** de la piste de test interne.
5. Les testeurs acceptent l'invitation puis installent depuis le lien.

### 3.6 Point de version par tag, puis dispatch

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Le tag reste une preuve de version et ne déclenche aucun job privilégié. Envoyer
ensuite le dispatch §3.5 avec `version_name=0.1.0`. GitHub charge alors
`release-android.yml` depuis `main`, puis l'environnement `beta` impose son
approbation et sa restriction à `main`.

### 3.7 Promouvoir Internal → Closed testing (beta)

- Soit relancer le workflow avec **track=`beta`** (closed),
- soit, dans la Play Console, **promouvoir** la release de la piste interne vers
  la piste fermée (recommandé pour réutiliser le même artefact validé).

---

## 4. iOS

> ✅ **Les builds iOS sont gérés par [Codemagic](https://codemagic.io).**
> Les runners macOS GitHub sont désactivés par la politique EMU ; Codemagic
> fournit des instances Mac M2 hébergées avec Xcode, CocoaPods et la signature
> automatique via l'API App Store Connect. Voir `codemagic.yaml` à la racine
> du repo.

### 4.0 Codemagic — réconcilier l'installation existante

> [!IMPORTANT]
> Codemagic, l'intégration App Store Connect et le groupe de variables ont déjà
> servi à produire un build TestFlight. L'objectif est de **vérifier et réutiliser**
> ces objets, pas de repartir de zéro. Une recréation/rotation n'est autorisée
> qu'après preuve explicite que l'objet est absent ou révoqué, hors de cette PR.

1. Ouvrir l'app Certigo existante sur <https://codemagic.io> et vérifier qu'elle
   pointe toujours vers `gchambaud_microsoft/Certigo`.
2. **Intégration App Store Connect** : dashboard → **Teams > Integrations > App
   Store Connect** → ouvrir **`AppStoreConnect`** et lancer le contrôle de
   validité disponible. Ne créer une nouvelle clé API (rôle App Manager) que si
   l'intégration existante est explicitement invalide/révoquée.
3. **Signature (pilotée par `codemagic.yaml`, aucune action UI)** : la signature
   est entièrement définie dans `codemagic.yaml`. À chaque build, l'étape « Set up
   code signing » exécute, via l'intégration `AppStoreConnect` :
   `app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create --certificate-key @env:CERTIFICATE_PRIVATE_KEY`
   → **crée uniquement s'ils manquent** le certificat de distribution + le profil
   App Store (puis les réutilise, idempotent), suivi de `keychain add-certificates` +
   `xcode-project use-profiles`. ⚠️ La création du certificat exige une **clé privée**
   et sa reconstruction de signature la réutilise : elle est fournie via la variable
   sécurisée **`CERTIFICATE_PRIVATE_KEY`** (§4, ci-dessous) — Codemagic ne la
   fournit **pas** automatiquement. Plus de fastlane
   match, de `.p12` ni de profil manuel à uploader. ⚠️ Ne PAS activer « App > Code
   signing → Automatic » dans l'UI : inutile (et sans effet) pour un build piloté
   par `codemagic.yaml`.
4. **Groupe de variables `certigo_mobile_config`** : dashboard → **App >
   Environment variables** → ouvrir le groupe existant
   **`certigo_mobile_config`** (ou le créer s'il n'existe pas) et vérifier ces
   **11 variables NON secrètes + 2 variables SÉCURISÉES**. Certaines valeurs
   sont injectées en
   `--dart-define`; les variables de domaine public alimentent la gate
   fail-closed avant le build. Seuls les champs marqués Secure contiennent un
   secret ; le DSN Sentry est public mais reste configurable et non commité :

   | Variable | Valeur | Secure ? | Utilisée par |
   |---|---|---|---|
   | `PROD_API_BASE_URL` | `https://<prod-func-app>.azurewebsites.net/api` (sortie du déploiement backend prod, cf. PR #158 → `functionAppName`) | non | `ios-release` |
   | `ENTRA_CLIENT_ID` | `4d1f1075-7bc5-4764-947b-701435a85f8c` | non | `ios-release` + `ios-release-dry` |
   | `ENTRA_AUTHORITY` | `https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0` | non | idem |
   | `ENTRA_API_SCOPE` | `api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915/user_impersonation` | non | idem |
   | `SENTRY_DSN` | DSN HTTPS public du projet Flutter Sentry | non | binaire des 3 workflows IPA |
   | `SENTRY_ORG` | slug d'organisation Sentry | non | upload dSYM Codemagic |
   | `SENTRY_PROJECT` | slug du projet Sentry | non | upload dSYM Codemagic |
   | `SENTRY_AUTH_TOKEN` | token dédié, moindre privilège, pour upload de debug files/releases | **OUI (Secure)** | Codemagic uniquement, jamais `--dart-define` |
   | `ACCOUNT_DELETION_ENABLED` | `false` tant que la gate destructive Cosmos n'est pas close | non | `ios-release` + `ios-release-dry` |
   | `PUBLIC_WEB_ORIGIN` | origine HTTPS canonique d'un domaine Certigo possédé et vérifié | non | gate `ios-release` |
   | `PUBLIC_DOMAIN_VERIFIED` | `true` uniquement après vérification humaine du domaine public | non | gate `ios-release` |
   | `APPLE_CIAM_DOMAIN_RECONFIGURED` | `true` uniquement après reconfiguration Apple/CIAM vérifiée | non | gate `ios-release` |
   | `CERTIFICATE_PRIVATE_KEY` | clé privée **RSA 2048 PEM non chiffrée** (`openssl genrsa 2048`), sans passphrase. Sert à créer le certificat de distribution iOS au 1er build. | **OUI (Secure)** | les 4 workflows iOS |

   > Sans les 4 premières : boutons sociaux masqués et/ou login e-mail cassé. Mêmes
   > valeurs que côté Android (Key Vault `mobile-*` / `vars.MOBILE_*`). Le
   > `PROD_API_BASE_URL` provient du **backend prod** déployé via `cd-backend`
   > (`environment=prod`, params `infra/params/prod.bicepparam` — voir §backend).
   > Sans `CERTIFICATE_PRIVATE_KEY` : le build échoue en signature avec
   > « Cannot save Signing Certificates without certificate private key ». La clé
   > n'a **pas** de passphrase → aucun `--certificate-key-password` requis. Cochez
   > **Secure** pour cette variable (elle est masquée dans les logs).
   > Sans l'une des quatre variables Sentry, sans dSYM ou si l'upload est refusé,
   > les workflows IPA échouent avant publication. Le setup confidentialité,
   > quotas et smoke test est détaillé dans
   > [`runbooks/MOBILE_CRASH_REPORTING.md`](./runbooks/MOBILE_CRASH_REPORTING.md).
   >
   > Les trois variables `PUBLIC_*`/`APPLE_CIAM_*` ne sont pas présentes dans le
   > scope GitHub `beta` observé le 2026-09-04, et ce scope ne prouve de toute
   > façon pas le contenu du dashboard Codemagic. Elles restent donc une **gate
   > humaine live**, pas un setup à recréer. Ne pas inventer de domaine ni passer
   > les booléens à `true` pour débloquer un build : en leur absence, conserver G2
   > ouverte et laisser `ios-release` échouer fermé.

### 4.1 Inventaire Apple à vérifier live

1. Adhésion **Apple Developer Program** toujours active pour l'équipe.
2. **App ID existant** `com.certigo.mobileapp` dans le portail Apple Developer.
3. **App existante** dans **App Store Connect** : bundle id
   **`com.certigo.mobileapp`**, nom **Certigo**.
4. **Certificat de distribution** (Apple Distribution) + **profil
   d'approvisionnement App Store** pour `com.certigo.mobileapp`, récupérables par
   Codemagic ; le nom de profil attendu est **`Certigo AppStore`**.
5. **Clé API App Store Connect** de l'intégration `AppStoreConnect` toujours
   valide avec le rôle App Manager.

### 4.2 (Legacy) Secrets iOS GitHub Actions — NON requis avec Codemagic

> ⛔ **Obsolète.** Cette section décrivait l'ancien pipeline iOS sur GitHub
> Actions (fastlane match + `.p12`/profil encodés en secrets). Avec la
> **signature automatique Codemagic** (§4.0), **aucun** de ces secrets n'est
> nécessaire : Codemagic gère certificats et profils via l'API App Store
> Connect. Conservé uniquement à titre historique pour les workflows
> `release-ios.yml` / `sync-ios-certs.yml` (types `repository_dispatch`
> `release-ios-legacy` et `sync-ios-certs-legacy`, chargés depuis `main`).
> **Ne pas créer ces secrets pour une release Codemagic.**
> Une exception legacy explicitement approuvée se déclenche uniquement ainsi :
> `gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches -f
> event_type=sync-ios-certs-legacy`, ou avec un corps JSON
> `{"event_type":"release-ios-legacy","client_payload":{"external":false,
> "dry_run":true}}` pour une build iOS. Tout champ ou type inattendu est rejeté.

<details>
<summary>Ancienne procédure (GitHub Actions iOS, dépréciée)</summary>

```bash
base64 -i dist.p12                 > cert.b64       # -> IOS_DIST_CERTIFICATE_P12_BASE64
base64 -i profile.mobileprovision  > profile.b64    # -> IOS_PROVISIONING_PROFILE_BASE64
base64 -i AuthKey_XXXX.p8          > authkey.b64    # -> ASC_KEY_P8_BASE64
```
```bash
gh secret set IOS_DIST_CERTIFICATE_P12_BASE64 < cert.b64
gh secret set IOS_DIST_CERTIFICATE_PASSWORD   --body '<mdp_du_p12>'
gh secret set IOS_PROVISIONING_PROFILE_BASE64 < profile.b64
gh secret set IOS_PROVISIONING_PROFILE_NAME   --body 'Certigo Beta App Store'
gh secret set IOS_TEAM_ID                     --body '<TEAM_ID>'
gh secret set ASC_KEY_ID                      --body '<KEY_ID>'
gh secret set ASC_ISSUER_ID                   --body '<ISSUER_ID>'
gh secret set ASC_KEY_P8_BASE64               < authkey.b64
```
</details>

### 4.3 Runbook — Lancer une beta iOS (TestFlight) ✅

> 📍 Les builds iOS sont désormais lancés depuis le **dashboard Codemagic**
> (plus depuis GitHub Actions).

1. Se connecter sur <https://codemagic.io> → sélectionner le repo Certigo.
2. Cliquer **Start new build** → choisir le workflow **`ios-release`**.
   - Pour un dry run (IPA sans upload) : choisir **`ios-release-dry`**.
   - Pour la validation destructive du crash reporting : choisir
     **`ios-crash-smoke`** (TestFlight interne uniquement).
   - Hors Alpha seulement : pour distribuer aux testeurs **externes**, ajouter
     un bloc `external_groups:` (et non `beta_groups:`) sous
     `publishing.app_store_connect` dans `codemagic.yaml`, puis lancer une
     build de la même façon. Cette distribution requiert au préalable la
     **revue bêta Apple** — cf. §4.5.
     `beta_groups:` a été retiré de `codemagic.yaml` (PR #432) : cette clé
     désigne des groupes **internes**, qui reçoivent automatiquement chaque
     build via `submit_to_testflight: true`. L'API App Store Connect refuse
     toute assignation explicite d'un groupe interne
     (`Cannot add internal group to a build`), et l'échec survenait **après**
     un upload TestFlight réussi — transformant une publication réussie en
     build rouge, incitant à relancer une opération déjà aboutie.
3. Ou pousser un **tag git `v*`** (ex: `git tag -a v1.2.3 -m "Release v1.2.3" && git push --tags`) ;
   cela déclenche automatiquement `ios-release`.
4. Le workflow : `analyze`/`test` → signature automatique via App Store Connect
   API → gate Sentry → `flutter build ipa` → vérification/upload bloquant des
   dSYM → upload TestFlight.
5. Dans **App Store Connect → TestFlight**, la build apparaît après traitement
   Apple (quelques minutes).

### 4.4 Crash reporting et symbolication iOS

Les builds IPA imposent `CRASH_REPORTING_REQUIRED=true`. La release Sentry est
stable (`com.certigo.mobileapp@<version>+<build>`), la distribution est le numéro
de build Codemagic et l'environnement suit `CERTIGO_ENV`. Le pipeline archive
les dSYM et exécute un upload Sentry direct avec `--wait`; aucun symbole n'est
uploadé par la CI de pull request.

Avant l'Alpha, exécuter l'action manuelle de setup et les deux crashs volontaires
Dart/natif du runbook
[`runbooks/MOBILE_CRASH_REPORTING.md`](./runbooks/MOBILE_CRASH_REPORTING.md).
Après le crash natif, relancer impérativement la build afin que Sentry Cocoa
rejoue l'enveloppe persistée, puis vérifier les frames symboliquées.

Xcode Organizer reste un complément TestFlight opt-in dépendant du partage des
diagnostics Apple ; Sentry est le système principal et bloquant.

### 4.5 TestFlight interne puis externe

État historique : `Internal Testers` existait et le build `1.0.1 (8)` avait été
traité et installé au moins une fois. Pour l'Alpha, réutiliser ce groupe avec un
**nouveau** build candidat ; ne pas créer de groupe externe.

- **Interne** (immédiat, ≤ 100 testeurs internes) : ajouter les testeurs internes
  dans App Store Connect ; ils reçoivent la build dès la fin du traitement
  (aucune revue Apple).
- **Externe — post-Alpha uniquement** (≤ 10 000) : créer un **groupe externe**,
  soumettre la **première** build à la **revue bêta Apple**, puis distribuer.

### 4.6 Détails de signature

- **Signature Codemagic** : `fetch-signing-files` récupère le certificat et le
  profil via l'intégration `AppStoreConnect`, puis les importe dans un
  **keychain temporaire**. `xcode-project use-profiles` applique le profil et
  produit l'`export_options.plist` consommé par `flutter build ipa`.
- **Authentification upload** : clé **API App Store Connect** (`.p8`) → pas
  d'Apple ID ni de 2FA en CI.

### 4.7 ~~fastlane match~~ — Remplacé par Codemagic automatic signing

> ⛔ **fastlane match n'est plus utilisé.** Codemagic gère les certificats et
> profils iOS nativement via l'**App Store Connect API** (signature automatique).
> Les secrets `IOS_MATCH_GIT_URL`, `IOS_MATCH_PASSWORD`, `IOS_MATCH_GIT_AUTH`
> et les workflows `release-ios` / `sync-ios-certs` GitHub Actions sont
> legacy, inertes par défaut et exécutables uniquement par opt-in manuel
> `enable_legacy_workflow=true`.

**Pourquoi Codemagic remplace match :**
- Pas de repo de certificats à maintenir.
- Pas de `.p12` ni de profil à exporter/encoder en base64.
- Renouvellement automatique : Codemagic recrée les certificats expirés avant
  chaque build.
- Un seul endroit de configuration : le dashboard Codemagic (§4.0).

**Refresh manuel des profils** (si nécessaire après ajout d'appareil, révocation,
etc.) : utiliser le workflow Codemagic **`ios-refresh-signing`** (dashboard →
Start new build → `ios-refresh-signing`). Ce workflow ré-exécute la même recette
idempotente que les builds (`app-store-connect fetch-signing-files "$BUNDLE_ID"
--type IOS_APP_STORE --create` + `keychain add-certificates` +
`xcode-project use-profiles`) pour (re)créer ou rafraîchir le certificat et le
profil App Store.

---

## 5. Versioning

| Champ | Source | Règle |
|---|---|---|
| versionName | `pubspec.yaml`, payload Android ou tag/entrée Codemagic | Sémantique (`MAJEUR.MINEUR.CORRECTIF`) |
| versionCode (Android) | `github.run_number` ou input | **Strictement croissant** (exigé par Play) |
| build number (iOS) | `PROJECT_BUILD_NUMBER` Codemagic ou suffixe `+N` du tag | **Strictement croissant** (exigé par ASC) |

- Pour une nouvelle version publique, bumper `version:` dans
  `apps/mobile/pubspec.yaml` (ex. `0.1.0+1` → `0.2.0+1`).
- Le `build_number` réel en CI vient du run GitHub : il est **monotone** et évite
  les collisions de versionCode entre deux releases.

---

## 6. Rollback

### Android

Le versionCode étant strictement croissant, on ne « réinstalle » pas un ancien
code : on **arrête** la diffusion fautive et on **republie** une build saine.

1. **Stopper la diffusion** : Play Console → piste concernée → *Arrêter le
   déploiement* de la release problématique (la build précédente reste celle
   servie aux testeurs).
2. **Republier une version saine** : se placer sur le commit/tag connu-bon et
   relancer `release-android` (le `build_number` issu du run sera supérieur, donc
   accepté), ou promouvoir une release antérieure valide.
3. **Communiquer** aux testeurs si l'app était déjà installée.

> Astuce : conserver la correspondance `versionCode ↔ commit` via les artefacts
> du run et les release notes (`whatsnew`).

### iOS

1. **TestFlight** : dans App Store Connect, **expirer** la build fautive
   (TestFlight → build → *Expirer*) pour qu'elle ne soit plus distribuée ; la
   build précédente reste disponible aux testeurs.
2. **Republier** une version saine : relancer `ios-release` depuis le commit/tag
   connu-bon avec un `PROJECT_BUILD_NUMBER` supérieur — exigé par App Store
   Connect.
3. Si un groupe **externe** était concerné, vérifier l'état de la revue Apple
   avant de redistribuer.

---

## 7. Erreurs de build fréquentes (Android)

### 7.1 `Dependency ':flutter_local_notifications' requires core library desugaring`

**Symptôme** : le build Gradle échoue avec :
```
Dependency ':flutter_local_notifications' requires core library desugaring
to be enabled for :app, current configuration is unsupported.
```

**Cause** : `flutter_local_notifications` utilise des API `java.time` (Android 26+)
qui doivent être rétro-portées via la bibliothèque AGP de desugaring pour cibler
des API Android < 26. Sans le flag, Gradle rejette la dépendance.

**Solution** (déjà appliquée dans `apps/mobile/android/app/build.gradle`) :

```groovy
// dans android > compileOptions
coreLibraryDesugaringEnabled = true

// dans le bloc dependencies
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

**Si ça revient** : vérifier que les deux lignes sont présentes. Une mise à jour
AGP ou une migration de `build.gradle` peut les effacer. Aussi s'assurer que
`minSdk` est bien < 26 (sinon le flag est inutile mais n'est pas nuisible).

---

### 7.2 Warning NDK version — plugins exigent 26.x, Flutter fournit 23.x

**Symptôme** : avertissement Gradle (parfois erreur de build) :
```
Your project is configured with Android NDK 23.1.7779620, but plugins require
Android NDK 26.1.10909125
```

**Cause** : `flutter.ndkVersion` se résout à la version embarquée dans le SDK
Flutter utilisé (23.x pour Flutter 3.24) alors que `flutter_local_notifications`,
`flutter_appauth` et d'autres plugins natifs exigent NDK ≥ 26.

**Solution** (déjà appliquée dans `apps/mobile/android/app/build.gradle`) :

```groovy
// Épingler explicitement dans android { }
ndkVersion = "26.1.10909125"
```

**Mise à jour** : quand Flutter bundle un NDK ≥ 26 par défaut, supprimer la valeur
fixe et revenir à `flutter.ndkVersion` (vérifier avec `flutter doctor -v`).

---

## 8. Checklist de preuve pré-Alpha iOS

- [x] Scope gelé : iOS interne, boucle coeur existante, Tuteur déterministe,
      aucune nouvelle feature.
- [ ] SHA candidat identifié et `ci-mobile` vert.
- [ ] Toute modification du cache ou du contrat de contenu runtime a passé
      `flutter test integration_test -d <device>` sur un appareil ou émulateur
      **Android**, puis sur un simulateur ou appareil **iOS**. Un device web ou
      desktop ne remplace pas cette preuve. Si l'un des deux environnements
      physiques manque, conserver la PR en draft et enregistrer ce blocker ;
      ne pas installer un émulateur lourd uniquement pour contourner ce gate.
- [ ] Sink de crash distant actif, dSYM uploadés et crash de test symboliqué.
- [ ] App Codemagic existante et repo vérifiés.
- [ ] Intégration `AppStoreConnect` et clé ASC vérifiées live.
- [ ] Groupe `certigo_mobile_config` existant et complet, sans exposer ses valeurs.
- [ ] Contrat de domaine public vérifié live (`PUBLIC_WEB_ORIGIN`,
      `PUBLIC_DOMAIN_VERIFIED`, `APPLE_CIAM_DOMAIN_RECONFIGURED`) ; aucune valeur
      déduite du scope GitHub `beta`.
- [ ] App ASC `com.certigo.mobileapp` et groupe `Internal Testers` vérifiés live.
- [ ] `ios-release-dry` vert sur le SHA candidat, IPA signée, aucun upload.
- [ ] Nouveau build `ios-release` traité dans TestFlight et affecté au groupe interne.
- [ ] Build installé sur iPhone physique ; auth + E2E boucle coeur verts.
- [ ] Tuteur confirmé déterministe (`TUTOR_LLM_ENABLED=false`).
- [ ] Décision Go/No-Go et preuves datées consignées.

---

## Déploiement progressif post-Alpha & rollback auth

Objectif : détecter une régression d'authentification (échec de login, boucle,
config invalide) **avant** qu'elle n'atteigne 100 % des utilisateurs.

> [!NOTE]
> Cette section décrit l'après-Alpha. Elle n'autorise ni Android, ni TestFlight
> externe, ni publication publique pendant le scope gelé.

### Rollout progressif futur (Android → iOS)

| Étape | Piste | Audience | Durée d'observation | Passage à l'étape suivante |
|---|---|---|---|---|
| 1 | `internal` (staging) | équipe interne | tests E2E `docs/E2E_AUTH_PREREQUIS.md` verts | manuel |
| 2 | `closed`/`production` **staged 5 %** | ~5 % prod | ≥ 24 h de trafic réel | KPI auth sous seuils ci-dessous |
| 3 | `production` **staged 20 %** | ~20 % | ≥ 24 h | KPI stables |
| 4 | `production` **100 %** | tous | — | — |

iOS : équivalent via App Store Connect (TestFlight → phased release 7 jours).

### Seuils de rollback automatique

Sur la fenêtre glissante d'une étape (source : KPI télémétrie, cf.
`docs/CONFIG_AUTH.md`) :

| Signal | Seuil d'alerte | Action |
|---|---|---|
| Taux de succès login (par provider) | < **98 %** | halt rollout ; investiguer |
| Taux d'échec `cause=config_error` | > **0,5 %** | **rollback immédiat** (config build cassée) |
| Taux d'échec `cause=timeout`+`network` | > **3 %** | halt ; vérifier backend / Entra |
| Latence médiane connexion | > **3 s** | halt ; investiguer |
| Crash-free sessions (Play/ASC) | < **99 %** | rollback |

Rollback = **halt staged rollout** (Play Console / ASC) sur la version fautive et
promotion de la précédente version stable. La config étant compile-time, un
`config_error` implique un **rebuild** avec les bons `--dart-define` (le garde-fou
`AppEnv.validate` aurait dû bloquer le build fautif : vérifier la CI d'abord).

### Runbook incident auth

1. **Constat** — pic d'`auth_failure` / signalements « impossible de se connecter ».
2. **Trier par cause** (télémétrie) :
   - `config_error` → build mal configuré : comparer les `--dart-define` du build
     (Key Vault `mobile-app-*`/`mobile-entra-*`, `vars.MOBILE_*`) au tableau
     `docs/CONFIG_AUTH.md` §2 ; **halt rollout** ; rebuild.
   - `timeout`/`network` → backend `API_BASE_URL` ou tenant Entra injoignable :
     vérifier santé backend + statut Entra External ID.
   - `provider_error` → fédération IdP (Microsoft/Google/Apple) cassée côté CIAM :
     vérifier les IdP et `domain_hint`.
   - `invalid_credentials` élevé mais isolé → probable côté utilisateur, pas une régression.
3. **Vérifier le deep-link** si social casse après un changement natif : le test
   `deep_link_config_test.dart` doit être vert (schéma `certigo`).
4. **Décision** — sous seuil → rollback (halt staged rollout) ; sinon correctif +
   nouveau build passant CI (`ci-mobile` : format/analyze/test) + garde-fou config.
5. **Post-mortem** — ajouter un test de non-régression pour la cause racine.
