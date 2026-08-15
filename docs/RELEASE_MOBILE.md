# Release mobile — Pipeline & runbooks

Documentation opérationnelle pour publier les bêtas Certigo.
**Priorité : Android d'abord, puis iOS.** Pipeline reproductible :
`code → build signée → upload beta store`.

> 🔐 **Aucun secret n'est committé.** Toutes les valeurs sensibles vivent dans
> les secrets GitHub Actions (ou en local dans des fichiers ignorés par git).
> Ce document ne contient que des **noms** de secrets et des **commandes**.

---

## 1. Vue d'ensemble

```
                    ┌─────────────────────────────────────────────────────┐
  git push / tag /  │  GitHub Actions (runner self-hosted Linux)          │
  Run workflow ────▶│  release-android.yml                                │
                    │   1. JDK 17 + SDK Android + Flutter 3.24.0           │
                    │   2. gates BLOQUANTS : flutter analyze + test        │
                    │   3. secrets via Key Vault / GitHub → key.properties │
                    │   4. flutter build appbundle (signé, versionné)      │
                    │   5. upload Google Play (piste internal/closed/…)    │
                    │   6. nettoyage du matériel de signature              │
                    └─────────────────────────────────────────────────────┘
```

| Élément | Valeur |
|---|---|
| App Flutter | `apps/mobile` |
| applicationId Android / bundle id iOS | `com.certigo.mobileapp` (identique sur les deux plateformes) — ⚠️ identifiants store stables |
| Nom affiché | Certigo |
| versionName | lu depuis `apps/mobile/pubspec.yaml` (`version:` → partie avant `+`) |
| versionCode / build number | `github.run_number` (auto-incrémenté), override possible |
| Workflows | `release-android.yml` (actif), `release-ios.yml` + `sync-ios-certs.yml` (legacy, inertes par défaut, opt-in manuel) ; iOS actif géré par Codemagic |
| CI inchangée | `ci-mobile.yml` (format/analyze/test) — aucune régression |

> ⚠️ **`com.certigo.mobileapp` est l'identifiant unifié** (Android `applicationId`
> = iOS bundle id). Il est définitif une fois la première build store uploadée.
> S'il change, mettre à jour : `apps/mobile/android/app/build.gradle`
> (`applicationId` + `namespace`), `PLAY_PACKAGE_NAME` dans `release-android.yml`,
> les `PRODUCT_BUNDLE_IDENTIFIER` de `apps/mobile/ios/Runner.xcodeproj/project.pbxproj`,
> `codemagic.yaml` (`bundle_identifier` + `BUNDLE_ID` + clé `provisioningProfiles`),
> et les fiches store (Play + App Store Connect).

---

## 2. Gestion des secrets

Deux approches, **interchangeables sans modifier les workflows** : si la variable
de dépôt `AZURE_KEYVAULT_NAME` est définie, les workflows lisent les secrets
depuis **Azure Key Vault** (recommandé) ; sinon ils retombent automatiquement sur
les **secrets GitHub**.

### 2.1 Recommandé — Azure Key Vault (zéro secret dans GitHub) ⭐

Les secrets de signature vivent dans le Key Vault `kv-certigo-<env>-<suffixe>`
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
   gh variable set AZURE_KEYVAULT_NAME --body 'kv-certigo-dev-bk3j5j'
   ```
4. **Charger les secrets dans le Key Vault** (une seule commande) :
   ```powershell
   Copy-Item tools/secrets/mobile-secrets.env.example tools/secrets/mobile-secrets.env  # puis renseigne-le
   ./tools/secrets/set-keyvault-secrets.ps1 -VaultName kv-certigo-dev-bk3j5j
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
| URL de base API | `mobile-app-api-base-url` | `vars.MOBILE_API_BASE_URL` | `https://<host>/api` |
| Entra client ID | `mobile-entra-client-id` | `vars.MOBILE_ENTRA_CLIENT_ID` | GUID App Registration mobile |
| Entra authority | `mobile-entra-authority` | `vars.MOBILE_ENTRA_AUTHORITY` | `https://<domain>.ciamlogin.com/<tenant-id>/v2.0` |
| Entra API scope | `mobile-entra-api-scope` | `vars.MOBILE_ENTRA_API_SCOPE` | `api://<backend-client-id>/user_impersonation` |
| Env (flavor) | `mobile-app-env` | `vars.MOBILE_CERTIGO_ENV` | `prod` \| `staging` \| `dev` (défaut : `prod`) |

- **Via Key Vault (recommandé)** : renseigner `API_BASE_URL`, `CERTIGO_ENV`,
  `ENTRA_CLIENT_ID`, `ENTRA_AUTHORITY`, `ENTRA_API_SCOPE` dans
  `tools/secrets/mobile-secrets.env` puis lancer `set-keyvault-secrets.ps1`
  (§2.1). Le script crée les secrets `mobile-app-*` / `mobile-entra-*`.
- **Via variables GitHub (repli)** : `Settings → Secrets and variables →
  Actions → Variables → New repository variable` pour chaque `MOBILE_*`
  ci-dessus. (Onglet **Variables**, pas **Secrets**.)

> 🔒 **Gate bloquant de publication** : pour toute exécution non `dry_run`, les
> cinq valeurs sont obligatoires et validées strictement (URL API HTTPS en
> `/api`, GUID client, authority External ID, scope `api://...`, environnement
> `dev|staging|prod`). Un dry-run invalide reste autorisé avec configuration
> neutralisée et ne peut pas publier. La piste `production` exige en plus
> `MOBILE_CERTIGO_ENV=prod`.

**iOS — groupe de variables Codemagic `certigo_mobile_config`**

Codemagic n'a pas accès au Key Vault : créer dans le dashboard Codemagic
(**Settings → Environment variables**) un **groupe** nommé `certigo_mobile_config`
contenant `PROD_API_BASE_URL`, `ENTRA_CLIENT_ID`, `ENTRA_AUTHORITY`,
`ENTRA_API_SCOPE` (mêmes formats que le tableau ci-dessus). `codemagic.yaml`
référence ce groupe et injecte les `--dart-define` ; `CERTIGO_ENV` est fixé
inline (`prod` pour `ios-release`, `dev` pour `ios-release-dry`).

---

## 3. Android

### 3.1 Pré-requis du runner self-hosted

Le runner `certigo-trusted` (Linux X64) doit disposer de Flutter/Dart (déjà requis
par la CI). Le workflow installe lui-même **JDK 17** et le **SDK Android**
(`android-actions/setup-android` + `sdkmanager`), donc aucune action manuelle
supplémentaire n'est nécessaire. L'egress internet passe par la NAT Gateway
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

### 3.4 Configurer Google Play (one-time)

1. **Créer l'application** dans la [Google Play Console](https://play.google.com/console)
   avec le package `com.certigo.mobileapp`.
2. **Activer Play App Signing** (proposé au 1er upload).
3. **Compte de service** : dans Google Cloud, créez un compte de service, générez
   une **clé JSON**. Dans la Play Console → *Configuration → accès à l'API* →
   liez le compte de service et accordez-lui au minimum le rôle permettant de
   *gérer les versions de test* (Release manager).
4. Enregistrer la clé JSON en secret :
   ```bash
   gh secret set PLAY_SERVICE_ACCOUNT_JSON < service-account.json
   ```
5. **Créer la piste "Test interne"** et y ajouter au moins une fois une release
   (la première peut devoir être faite manuellement depuis la console selon
   l'état d'enrôlement ; les suivantes passent par le workflow).

### 3.5 Runbook — Lancer une beta Android (manuel) ✅

1. Onglet **Actions** → workflow **release-android** → **Run workflow**.
2. Renseigner :
   - **track** : `internal` (puis `beta`/closed plus tard),
   - **version_name** : vide (= pubspec) ou ex. `0.1.0`,
   - **build_number** : vide (= numéro de run, auto-incrémenté),
   - **dry_run** : `false` (mettre `true` pour builder sans publier).
3. Le workflow exécute les **gates** (`analyze` + `test`), construit l'**AAB
   signé**, l'**uploade** sur la piste choisie, puis nettoie les secrets.
   `version_name` doit être un SemVer strict, `build_number` un entier positif
   ≤ 2 100 000 000 et `track` l'une de `internal|alpha|beta|production`.
4. Dans la Play Console, ajouter les testeurs (e-mails ou liste) et partager le
   **lien d'opt-in** de la piste de test interne.
5. Les testeurs acceptent l'invitation puis installent depuis le lien.

### 3.6 Runbook — Release par tag

```bash
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

→ déclenche `release-android` sur la piste **internal** (versionName = `0.1.0`
déduit du tag), après approbation de l'environnement `beta`. Le workflow vérifie
que le tag correspond exactement à `v<SemVer>` et pointe sur un commit de `main`.

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

### 4.0 Codemagic — Setup initial (one-time)

> 🔄 **Repartir de zéro** (app Codemagic supprimée / clé ASC révoquée) : suivre
> ces étapes dans l'ordre. Le pipeline vit dans `codemagic.yaml` à la racine.

1. Créer/reconnecter un compte sur <https://codemagic.io> et **connecter le repo
   GitHub** `gchambaud_microsoft/Certigo` (installer l'app GitHub Codemagic).
2. **Intégration App Store Connect** : dashboard → **Teams > Integrations > App
   Store Connect** → **Add integration** → saisir **Key ID**, **Issuer ID**,
   uploader le **`.p8`** (nouvelle clé API, rôle App Manager) → nommer
   l'intégration **exactement `AppStoreConnect`** (le `codemagic.yaml` la
   référence sous ce nom).
3. **Signature (pilotée par `codemagic.yaml`, aucune action UI)** : la signature
   est entièrement définie dans `codemagic.yaml`. À chaque build, l'étape « Set up
   code signing » exécute, via l'intégration `AppStoreConnect` :
   `app-store-connect fetch-signing-files "$BUNDLE_ID" --type IOS_APP_STORE --create --certificate-key @env:CERTIFICATE_PRIVATE_KEY`
   → **crée** le certificat de distribution + le profil App Store au **1er build**
   (puis les réutilise, idempotent), suivi de `keychain add-certificates` +
   `xcode-project use-profiles`. ⚠️ La création du certificat exige une **clé privée**
   (compte Apple neuf, aucun certificat existant) : elle est fournie via la variable
   sécurisée **`CERTIFICATE_PRIVATE_KEY`** (§4, ci-dessous) — Codemagic ne la
   fournit **pas** automatiquement pour un compte from-scratch. Plus de fastlane
   match, de `.p12` ni de profil manuel à uploader. ⚠️ Ne PAS activer « App > Code
   signing → Automatic » dans l'UI : inutile (et sans effet) pour un build piloté
   par `codemagic.yaml`.
4. **Groupe de variables `certigo_mobile_config`** : dashboard → **App >
   Environment variables** → créer le groupe **`certigo_mobile_config`** et y
   poser ces **4 variables NON secrètes** (injectées en `--dart-define`) **+ 1
   variable SÉCURISÉE** (signature, jamais un `--dart-define`) :

   | Variable | Valeur | Secure ? | Utilisée par |
   |---|---|---|---|
   | `PROD_API_BASE_URL` | `https://<prod-func-app>.azurewebsites.net/api` (sortie du déploiement backend prod, cf. PR #158 → `functionAppName`) | non | `ios-release` |
   | `ENTRA_CLIENT_ID` | `4d1f1075-7bc5-4764-947b-701435a85f8c` | non | `ios-release` + `ios-release-dry` |
   | `ENTRA_AUTHORITY` | `https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0` | non | idem |
   | `ENTRA_API_SCOPE` | `api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915/user_impersonation` | non | idem |
   | `CERTIFICATE_PRIVATE_KEY` | clé privée **RSA 2048 PEM non chiffrée** (`openssl genrsa 2048`), sans passphrase. Sert à créer le certificat de distribution iOS au 1er build. | **OUI (Secure)** | les 3 workflows iOS |

   > Sans les 4 premières : boutons sociaux masqués et/ou login e-mail cassé. Mêmes
   > valeurs que côté Android (Key Vault `mobile-*` / `vars.MOBILE_*`). Le
   > `PROD_API_BASE_URL` provient du **backend prod** déployé via `cd-backend`
   > (`environment=prod`, params `infra/params/prod.bicepparam` — voir §backend).
   > Sans `CERTIFICATE_PRIVATE_KEY` : le build échoue en signature avec
   > « Cannot save Signing Certificates without certificate private key ». La clé
   > n'a **pas** de passphrase → aucun `--certificate-key-password` requis. Cochez
   > **Secure** pour cette variable (elle est masquée dans les logs).

### 4.1 Pré-requis Apple (one-time)

1. Compte **Apple Developer Program** (payant) pour l'équipe.
2. **App ID** `com.certigo.mobileapp` (portail Apple Developer ou App Store Connect).
3. **App** créée dans **App Store Connect** : bundle id **`com.certigo.mobileapp`**,
   nom **Certigo**.
4. **Certificat de distribution** (Apple Distribution) + **profil d'approvisionnement
   App Store** pour `com.certigo.mobileapp` (gérés automatiquement par Codemagic
   une fois l'intégration en place ; le nom de profil attendu par
   `codemagic.yaml` est **`Certigo AppStore`**).
5. **Clé API App Store Connect** (rôle App Manager) : Key ID, Issuer ID, fichier `.p8`.

### 4.2 (Legacy) Secrets iOS GitHub Actions — NON requis avec Codemagic

> ⛔ **Obsolète.** Cette section décrivait l'ancien pipeline iOS sur GitHub
> Actions (fastlane match + `.p12`/profil encodés en secrets). Avec la
> **signature automatique Codemagic** (§4.0), **aucun** de ces secrets n'est
> nécessaire : Codemagic gère certificats et profils via l'API App Store
> Connect. Conservé uniquement à titre historique pour les workflows
> `release-ios.yml` / `sync-ios-certs.yml` (`workflow_dispatch` avec opt-in
> `enable_legacy_workflow=true`).
> **Ne pas créer ces secrets pour une release Codemagic.**

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
   - Pour distribuer aux testeurs externes : modifier `beta_groups` dans
     `codemagic.yaml` avant de lancer.
3. Ou pousser un **tag git `v*`** (ex: `git tag -a v1.2.3 -m "Release v1.2.3" && git push --tags`) ;
   cela déclenche automatiquement `ios-release`.
4. Le workflow : `analyze`/`test` → signature automatique via App Store Connect
   API → `flutter build ipa` → upload TestFlight.
5. Dans **App Store Connect → TestFlight**, la build apparaît après traitement
   Apple (quelques minutes).

### 4.4 TestFlight interne puis externe

- **Interne** (immédiat, ≤ 100 testeurs internes) : ajouter les testeurs internes
  dans App Store Connect ; ils reçoivent la build dès la fin du traitement
  (aucune revue Apple).
- **Externe** (≤ 10 000) : créer un **groupe externe**, soumettre la **première**
  build à la **revue bêta Apple**, puis distribuer. Relancer le workflow avec
  **external=`true`** (et définir le secret/variable `TF_EXTERNAL_GROUP` si le
  groupe ne s'appelle pas « Beta »).

### 4.5 Détails de signature

- **Signature manuelle** : le certificat de distribution et le profil
  d'approvisionnement sont injectés via secrets, importés dans un **keychain
  temporaire** détruit en fin de job. `fastlane build_app` force
  `CODE_SIGN_STYLE=Manual`, `DEVELOPMENT_TEAM` et `PROVISIONING_PROFILE_SPECIFIER`.
- **Authentification upload** : clé **API App Store Connect** (`.p8`) → pas
  d'Apple ID ni de 2FA en CI.

### 4.6 ~~fastlane match~~ — Remplacé par Codemagic automatic signing

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
| versionName | `pubspec.yaml` ou input/tag | Sémantique (`MAJEUR.MINEUR.CORRECTIF`) |
| versionCode (Android) | `github.run_number` ou input | **Strictement croissant** (exigé par Play) |

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
2. **Republier** une version saine : relancer `release-ios` depuis le commit/tag
   connu-bon (le `build_number` issu du run sera supérieur — exigé par App Store
   Connect).
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

## 8. Checklist pré-release

- [ ] `ci-mobile` au vert sur la branche à publier (format/analyze/test).
- [ ] `version:` de `pubspec.yaml` à jour si nouvelle version publique.
- [ ] Notes de version `apps/mobile/distribution/android/whatsnew/*` actualisées.
- [ ] Secrets présents : `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`,
      `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`.
- [ ] **Config app (§2.3)** : `API_BASE_URL`, `ENTRA_CLIENT_ID`, `ENTRA_AUTHORITY`,
      `ENTRA_API_SCOPE`, `CERTIGO_ENV` renseignés — via Key Vault (`mobile-app-*` /
      `mobile-entra-*`) ou variables GitHub `vars.MOBILE_*` — sinon social/login KO.
- [ ] (1ère fois) App créée dans Play Console + piste de test interne existante.
- [ ] identifiant `com.certigo.mobileapp` **confirmé** (Android + iOS, définitif après 1er upload).
- [ ] Run de validation `dry_run=true` réussi (AAB/IPA signé produit).
- [ ] **iOS** : intégration Codemagic configurée (§4.0) ; clé API App Store Connect
      ajoutée dans le dashboard Codemagic (intégration `AppStoreConnect`) ; code
      signing automatique activé ; app créée dans App Store Connect.
- [ ] `docs/RELEASE_MOBILE.md` à jour.

---

## Déploiement progressif & rollback auth

Objectif : détecter une régression d'authentification (échec de login, boucle,
config invalide) **avant** qu'elle n'atteigne 100 % des utilisateurs.

### Rollout progressif (Android → iOS)

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
