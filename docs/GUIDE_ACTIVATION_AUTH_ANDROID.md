# Guide d'activation de l'authentification — App Certigo Android

> **Pour qui ?** Vous, même si vous n'êtes pas à l'aise avec Azure. Ce guide vous
> fait réaliser **pas à pas** les réglages **manuels** qui rendront la connexion
> fonctionnelle dans l'app Android : **login e‑mail** + affichage des **boutons
> Google / Apple / Microsoft**.
>
> **Durée** : ~45–90 min la première fois. Vous pouvez vous arrêter et reprendre.

---

## 0. Ce que ce guide résout (et ne résout pas)

**Le problème, en une phrase** : aujourd'hui l'app Android est construite **sans
sa configuration** (URL du backend + identifiants Entra). Résultat :
- le **login e‑mail** échoue avec « Pas de connexion… » (l'app pointe vers une
  URL par défaut qui n'existe pas) ;
- les **3 boutons sociaux sont masqués** (l'app les cache tant qu'elle n'a pas
  d'identifiant Entra — c'est volontaire, voir `packages/core/lib/src/app_env.dart`).

**Ce guide couvre le côté « humain / infrastructure »** :
- **A.** Le tenant **Entra External ID (CIAM)** : applications, redirect URI,
  fournisseurs Microsoft/Google/Apple, et récupération des valeurs.
- **B.** Le **backend** (déploiement / vérification via Bicep) et son URL.
- **C.** Le **stockage des vraies valeurs** de config (secrets **Key Vault** ou
  variables **GitHub**) que le correctif d'intégration continue (CI) va consommer.
- **D.** Le **déclenchement d'une release** et la **vérification** finale.

**Ce guide NE touche PAS** au correctif du workflow de build
(`.github/workflows/release-android.yml` / `codemagic.yaml`). Cette partie est
traitée par une autre tâche (« Fix CI Android auth »). Ici, on prépare **tout ce
que ce correctif aura besoin de lire**.

> ⚠️ **Vous exécutez, ce guide explique.** Aucune ressource Azure n'est créée
> automatiquement : les commandes vous sont fournies, **c'est vous qui les lancez**
> dans **votre** abonnement / **votre** tenant.

---

## 1. Prérequis outils (à installer une fois)

| Outil | Pourquoi | Vérifier |
|---|---|---|
| **Azure CLI** (`az`) | déployer le backend, écrire dans Key Vault | `az version` |
| **GitHub CLI** (`gh`) | poser les variables/secrets du repo, lancer la release | `gh --version` |
| **Un navigateur** + accès au **portail Entra** | créer les app registrations, activer les fournisseurs | portail [entra.microsoft.com](https://entra.microsoft.com) |
| **PowerShell** | lancer le script d'aide fourni | `\$PSVersionTable.PSVersion` |

Connexions :
```powershell
az login                 # ouvre le navigateur ; choisissez le bon tenant/abonnement
gh auth login            # authentifie la CLI GitHub sur le repo gchambaud_microsoft/Certigo
```

**Droits nécessaires** :
- Sur **Azure** : pouvoir créer un groupe de ressources / déployer (rôle *Contributor*
  sur l'abonnement) **et** le rôle **« Key Vault Secrets Officer »** sur le Key Vault.
- Sur **Entra** : pouvoir créer des *App registrations* et configurer les
  fournisseurs d'identité (rôle *Application Administrator* ou équivalent).
- Sur **GitHub** : être *admin* du repo (pour poser variables/secrets et lancer le workflow).

---

## 2. Tableau des valeurs à produire

À la fin, vous aurez **5 valeurs** (les optionnelles ont déjà un défaut correct) :

| Clé (dart‑define) | Exemple / Format | D'où elle vient |
|---|---|---|
| `CERTIGO_ENV` | `prod` (ou `staging` / `dev`) | Votre choix d'environnement (§ 3) |
| `API_BASE_URL` | `https://func-certigo-<env>-XXXX.azurewebsites.net/api` | Sortie du déploiement backend (**B**) |
| `ENTRA_CLIENT_ID` | GUID `00000000-0000-0000-0000-000000000000` | App registration **MOBILE** (**A**) |
| `ENTRA_AUTHORITY` | `https://<domaine>.ciamlogin.com/<tenant-id>/v2.0` | Domaine + tenant‑id du tenant CIAM (**A**) |
| `ENTRA_API_SCOPE` | `api://<backend-client-id>/user_impersonation` | App registration **BACKEND** (**A**) |

Optionnelles (laisser vide = défaut app) :
`ENTRA_REDIRECT_URI=certigo://auth/`, `ENTRA_DOMAIN_HINT_MICROSOFT=microsoft.com`,
`ENTRA_DOMAIN_HINT_GOOGLE=google.com`, `ENTRA_DOMAIN_HINT_APPLE=apple.com`.

> 💡 Gardez un bloc‑notes ouvert : à chaque étape A/B, vous y collerez la valeur
> obtenue. En section **C**, vous les reporterez d'un coup.

---

## 3. Choisir l'environnement cible

- **`dev`** — le plus simple pour un premier test. Le backend est **déjà déployé**
  (`https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api`) et l'auth Entra
  n'est **pas obligatoire** côté serveur (`authMode='dev'`). Idéal pour valider le
  **login e‑mail** rapidement. Les boutons sociaux s'afficheront quand même si vous
  renseignez un `ENTRA_CLIENT_ID`.
- **`staging`** / **`prod`** — nécessitent de **déployer** le backend et de fournir
  les **vraies** valeurs CIAM (le serveur valide réellement les jetons, `authMode='prod'`).

👉 **On confirmera votre choix en interactif avant de continuer.**

---

## A. Entra External ID (CIAM)

Objectif : obtenir `ENTRA_CLIENT_ID`, `ENTRA_AUTHORITY`, `ENTRA_API_SCOPE`, et
activer les fournisseurs sociaux.

### A.0 — Vérifier / créer le tenant External ID
1. Portail [entra.microsoft.com](https://entra.microsoft.com) → en haut à droite,
   vérifiez le **répertoire** actif. Un tenant **External ID (CIAM)** est distinct
   de votre tenant d'entreprise habituel.
2. S'il n'existe pas encore : **Entra ID → Overview → Manage tenants → Create → External**,
   puis suivez l'assistant (nom, domaine initial, région).
3. Notez deux choses depuis **Overview** du tenant :
   - **Tenant ID** (Directory ID) — un GUID.
   - **Domaine principal** — ex. `certigo.onmicrosoft.com` → le **préfixe** est `certigo`.

> Ces deux éléments servent à construire `ENTRA_AUTHORITY` (voir A.6).

### A.1 — App registration **MOBILE**
1. **Entra ID → App registrations → New registration**.
2. Nom : `Certigo Mobile` (par ex.). *Supported account types* : laissez le défaut
   proposé pour External ID (comptes clients).
3. **Register**.
4. Onglet **Overview** → copiez **Application (client) ID** → c'est votre
   **`ENTRA_CLIENT_ID`**.

### A.2 — Redirect URI mobile
1. Dans l'app **MOBILE** → **Authentication → Add a platform → Mobile and desktop applications**.
2. Ajoutez le **Redirect URI** exact (**avec le slash final**) :
   ```
   certigo://auth/
   ```
3. **Save**. (C'est la valeur par défaut `ENTRA_REDIRECT_URI` de l'app ; ne pas la changer.)

   > ⚠️ **Le slash final est obligatoire.** Le SDK AppAuth iOS valide l'URL de
   > redirection avec Azure/CIAM ; sans le slash final, le callback n'est pas
   > reconnu côté iOS et la connexion **sociale** iOS « hang » (Android + e-mail
   > non affectés). Le schéma reste `certigo`. Réf. : FAQ officielle
   > `flutter_appauth`. Enregistrez la valeur **exacte** `certigo://auth/`.

### A.3 — App registration **BACKEND** (l'API)
1. Refaites **New registration** → nom `Certigo API` (par ex.) → **Register**.
2. Copiez son **Application (client) ID** (= *backend‑client‑id*).
3. Onglet **Expose an API** :
   - **Application ID URI** : cliquez **Add**, acceptez `api://<backend-client-id>`.
   - **Add a scope** : nom du scope **`user_impersonation`**, *Who can consent* =
     *Admins and users*, remplissez les libellés → **Add scope**.
4. Vous obtenez ainsi **`ENTRA_API_SCOPE`** :
   ```
   api://<backend-client-id>/user_impersonation
   ```

### A.4 — Autoriser le MOBILE à appeler l'API (permission)
1. Retour dans l'app **MOBILE** → **API permissions → Add a permission → My APIs →
   Certigo API** → cochez **user_impersonation** → **Add permissions**.
2. Si un bouton **Grant admin consent** est proposé, cliquez‑le.

> 💡 **Astuce** : si l'onglet **My APIs** est vide, cherchez votre API sous
> **APIs my organization uses** (« API utilisées par mon organisation »), tapez
> `Certigo API`, sélectionnez‑la puis cochez `user_impersonation`.

### A.5 — Activer les fournisseurs Microsoft / Google / Apple
Deux familles de fournisseurs coexistent dans External ID :
- **Intégrés (built‑in)** : **Google** et **Apple**. Entra fabrique lui‑même le
  jeton secret ; vous ne fournissez que des identifiants (Client ID, clés).
- **OIDC personnalisé** : utilisé ici pour **Microsoft (comptes personnels MSA)**,
  déclaré comme fournisseur OpenID Connect sur mesure.

Emplacement : tenant External ID → **External Identities → All identity providers**.
👉 La configuration **détaillée et vécue** (URI, clés, pièges) est en **Annexe 4**.

Puis rattachez les fournisseurs au **user flow** de connexion :
**External Identities → User flows → `susi_certigo` → Identity providers** → cochez
**Email**, **Google**, **Microsoft**, **Apple** → **Save**. Vérifiez aussi, sous
**Applications** du même user flow, que l'app **Certigo Mobile** y est rattachée.

> ℹ️ L'app affiche un bouton dès lors que `ENTRA_CLIENT_ID` + `ENTRA_AUTHORITY` sont
> renseignés ; le fournisseur doit toutefois être **activé côté Entra** (déclaré
> **et** coché dans le user flow) pour que le bouton aboutisse à une connexion.

### A.6 — Construire les deux formules
```
ENTRA_AUTHORITY = https://<domaine>.ciamlogin.com/<tenant-id>/v2.0
ENTRA_API_SCOPE = api://<backend-client-id>/user_impersonation
```
Exemple **réel Certigo** (tenant `certigoapp`) :
```
ENTRA_CLIENT_ID = 4d1f1075-7bc5-4764-947b-701435a85f8c
ENTRA_AUTHORITY = https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0
ENTRA_API_SCOPE = api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915/user_impersonation
```

> ⚠️ Utilisez le sous-domaine = GUID du tenant (issuer canonique retourné par le document de découverte OIDC), PAS le domaine vanity certigoapp.ciamlogin.com — flutter_appauth valide strictement l'issuer et un mismatch fait échouer silencieusement l'échange de jetons (spinner infini).

✅ **Fin de A**, vous avez : `ENTRA_CLIENT_ID`, `ENTRA_AUTHORITY`, `ENTRA_API_SCOPE`.

### A.7 — (dev) Aligner le backend sur le CIAM
En **dev**, l'API ne force pas la validation Entra (`authMode=dev`), mais pour un test
E2E réaliste on aligne ses réglages sur le tenant CIAM :
```powershell
az functionapp config appsettings set -g rg-certigo-dev -n func-certigo-dev-bk3j5ja6vw23s --settings `
  ENTRA_AUDIENCE="12910b8e-6c75-4d51-91d8-4d5fb8a6e915" `
  ENTRA_AUTHORITY="https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0"
az functionapp restart -g rg-certigo-dev -n func-certigo-dev-bk3j5ja6vw23s
```
> En **staging/prod**, ces valeurs viennent de `infra/params/<env>.bicepparam`
> (`entraAudience`, `entraAuthority`) — corrigez‑les là‑bas puis redéployez (voir B).

---

## B. Backend (déployer / vérifier) → obtenir `API_BASE_URL`

Le backend est un **Azure Function App** décrit dans `infra/`. On le déploie au
**niveau abonnement** ; le modèle crée le groupe de ressources `rg-certigo-<env>`,
le Function App et le Key Vault.

### B.1 — Cas `dev` : déjà déployé (juste vérifier)
```powershell
# Vérifier que le backend DEV répond :
curl.exe -i https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api/health
```
→ Votre `API_BASE_URL` (dev) :
```
https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api
```
Key Vault DEV correspondant : **`kv-certigo-dev-bk3j5j`**.

> Si l'endpoint `/health` n'existe pas, testez la racine du domaine ; l'important
> est d'obtenir une réponse HTTP (même 401/404) prouvant que l'hôte existe.

### B.2 — Cas `staging` / `prod` : déployer
1. Ouvrez le fichier de paramètres de l'environnement visé et **renseignez les
   vraies valeurs Entra** (elles y sont en placeholders) :
   - `infra/params/staging.bicepparam` **ou** `infra/params/prod.bicepparam`
   - Champs à remplir : `entraAuthority='https://<domaine>.ciamlogin.com/<tenant-id>/v2.0'`
     et `entraAudience='api://<backend-client-id>'`.
2. Déployez :
   ```powershell
   az deployment sub create `
     --location westeurope `
     --template-file infra/main.bicep `
     --parameters infra/params/<env>.bicepparam
   ```
   (remplacez `<env>` par `staging` ou `prod`.)
3. Récupérez les **sorties** du déploiement :
   ```powershell
   az deployment sub show --name main -o json `
     --query "properties.outputs.{func:functionAppHostName.value, kv:keyVaultName.value}"
   ```
   → `API_BASE_URL = https://<functionAppHostName>/api`, et notez **`keyVaultName`**
   (vous en aurez besoin en section **C**).

✅ **Fin de B**, vous avez : `API_BASE_URL` (+ le nom du Key Vault cible).

---

## C. Renseigner la config (Key Vault **ou** variables GitHub)

C'est ici que vous **déposez les 5 valeurs** pour que le build les récupère.
Deux options — **choisissez‑en une** (Key Vault recommandé, cohérent avec la
signature déjà gérée par le workflow) :

> ✅ **Noms FIGÉS** : les noms ci‑dessous sont ceux exactement lus par le correctif
> CI (« Fix CI Android auth », plan approuvé). Ne les renommez pas.
>
> **Sélecteur** : la variable GitHub **`AZURE_KEYVAULT_NAME`** décide quelle source
> la CI utilise — si elle est **définie**, la CI lit les **secrets Key Vault**
> (Option 1) ; si elle est **absente**, la CI lit les **variables GitHub `MOBILE_*`**
> (Option 2). C'est le même mécanisme que l'étape de signature.

### Option 1 — Secrets **Key Vault** (recommandé)

Noms de secrets **figés** (même préfixe `mobile-` que les `mobile-android-*` de
signature) :

| Valeur | Nom de secret Key Vault |
|---|---|
| `API_BASE_URL` | `mobile-app-api-base-url` |
| `ENTRA_CLIENT_ID` | `mobile-entra-client-id` |
| `ENTRA_AUTHORITY` | `mobile-entra-authority` |
| `ENTRA_API_SCOPE` | `mobile-entra-api-scope` |
| `CERTIGO_ENV` | `mobile-app-env` |

**Script d'aide** — c'est le **même** script `set-keyvault-secrets.ps1` que celui qui
charge déjà les secrets de **signature** ; le correctif CI « Fix CI Android auth » y
ajoute le mapping de ces 5 clés de config (`mobile-app-*` / `mobile-entra-*`) :
```powershell
cd tools/secrets
Copy-Item mobile-secrets.env.example mobile-secrets.env
# → éditez mobile-secrets.env : renseignez API_BASE_URL, ENTRA_CLIENT_ID,
#   ENTRA_AUTHORITY, ENTRA_API_SCOPE, CERTIGO_ENV (laissez le reste tel quel).

# Aperçu sans rien écrire :
./set-keyvault-secrets.ps1 -VaultName <votre-key-vault> -DryRun

# Écriture réelle :
./set-keyvault-secrets.ps1 -VaultName <votre-key-vault>
```
- `<votre-key-vault>` = `kv-certigo-dev-bk3j5j` (dev) **ou** la sortie `keyVaultName`
  du déploiement staging/prod (section B).
- Pré‑requis : rôle **« Key Vault Secrets Officer »** sur ce Key Vault.
- **Repli sûr (robuste à l'ordre de merge)** — une fois la **PR #149** « Fix CI Android auth »
  fusionnée, `set-keyvault-secrets.ps1` mappe ces 5 clés automatiquement. En attendant — ou
  simplement pour vérifier — écrivez-les à la main avec les **mêmes noms figés** ; c'est
  idempotent, donc sans risque même après le merge :
  ```powershell
  az keyvault secret set --vault-name <votre-key-vault> --name mobile-app-api-base-url --value "https://func-certigo-...azurewebsites.net/api"
  az keyvault secret set --vault-name <votre-key-vault> --name mobile-entra-client-id --value "<guid-app-mobile>"
  az keyvault secret set --vault-name <votre-key-vault> --name mobile-entra-authority --value "https://<domain>.ciamlogin.com/<tenant-id>/v2.0"
  az keyvault secret set --vault-name <votre-key-vault> --name mobile-entra-api-scope --value "api://<backend-client-id>/user_impersonation"
  az keyvault secret set --vault-name <votre-key-vault> --name mobile-app-env --value "prod"
  ```
- **Indispensable** : dites à la CI d'utiliser ce Key Vault en posant la variable
  GitHub `AZURE_KEYVAULT_NAME` :
  ```powershell
  gh variable set AZURE_KEYVAULT_NAME --body "<votre-key-vault>"
  ```

### Option 2 — Variables **GitHub** du repo (repli)

À utiliser **seulement si vous ne définissez pas** `AZURE_KEYVAULT_NAME`. Posez les
5 variables (noms **figés** `MOBILE_*`) directement :
```powershell
gh variable set MOBILE_CERTIGO_ENV      --body "prod"
gh variable set MOBILE_API_BASE_URL     --body "https://func-certigo-...azurewebsites.net/api"
gh variable set MOBILE_ENTRA_CLIENT_ID  --body "00000000-0000-0000-0000-000000000000"
gh variable set MOBILE_ENTRA_AUTHORITY  --body "https://certigo.ciamlogin.com/<tenant-id>/v2.0"
gh variable set MOBILE_ENTRA_API_SCOPE  --body "api://<backend-client-id>/user_impersonation"
```
> ⚠️ Dans cette voie, **ne définissez pas** `AZURE_KEYVAULT_NAME` (sinon la CI ira
> chercher les secrets Key Vault au lieu de ces variables).

✅ **Fin de C** : les 5 valeurs sont stockées (KV ou variables GitHub).

---

## D. Déclencher la release et vérifier

> ⚠️ Le build ne saura injecter ces valeurs **qu'une fois le correctif CI en place**
> (tâche « Fix CI Android auth »). Attendez sa fusion, ou coordonnez le timing.

1. **Lancer la release** depuis le workflow de la branche par défaut :
   ```powershell
   gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches `
     -f event_type=release-android `
     -f "client_payload[track]=internal" `
     -f "client_payload[version_name]=0.1.0" `
     -F "client_payload[dry_run]=false"
   ```
   Un tag peut être créé séparément pour la traçabilité, mais il ne déclenche
   aucun workflow privilégié.
2. **Suivre le run** :
   ```powershell
   gh run list --workflow release-android.yml -L 3
   gh run watch   # sélectionnez le run en cours
   ```
3. **Récupérer l'AAB** (artefact du run) et l'installer sur un appareil/emulateur :
   ```powershell
   gh run download <run-id>            # télécharge l'app bundle
   # Convertir l'AAB en APK installable (bundletool) puis :
   #   adb install app.apks   (ou installez l'AAB via Play Console/Internal testing)
   ```
4. **Vérifier dans l'app** :
   - Les **3 boutons** Google / Apple / Microsoft sont **visibles** sur l'écran de
     connexion → preuve que `ENTRA_CLIENT_ID` + `ENTRA_AUTHORITY` sont bien injectés.
   - Le **login e‑mail** fonctionne (plus de « Pas de connexion… ») → preuve que
     `API_BASE_URL` pointe vers un backend **déployé et joignable**.
   - Un **bouton social** aboutit à une connexion → preuve que le fournisseur est
     **activé** côté Entra (A.5).

✅ **Fin de D** : authentification opérationnelle.

---

## Annexe 1 — Rappel des formules

```
API_BASE_URL      = https://<functionAppHostName>/api
ENTRA_AUTHORITY   = https://<domaine>.ciamlogin.com/<tenant-id>/v2.0
ENTRA_API_SCOPE   = api://<backend-client-id>/user_impersonation
ENTRA_REDIRECT_URI= certigo://auth/       (plateforme « Mobile and desktop applications », slash final requis)
Audience backend  = api://<backend-client-id>
```

## Annexe 2 — Dépannage

| Symptôme | Cause probable | Action |
|---|---|---|
| Boutons sociaux **absents** | `ENTRA_CLIENT_ID`/`ENTRA_AUTHORITY` vides à la construction | Vérifier C (KV/variables) **et** que le correctif CI injecte bien ces `--dart-define` |
| Bouton social visible mais **échoue** | fournisseur non activé côté Entra | Refaire A.5 (Google/Apple : Client ID/secret, clé `.p8`) |
| Login e‑mail « **Pas de connexion…** » | `API_BASE_URL` pointe vers un hôte inexistant | Vérifier B (déploiement) et tester l'URL avec `curl` |
| `401`/jeton refusé en staging/prod | `entraAuthority`/`entraAudience` du `.bicepparam` incorrects | Corriger `infra/params/<env>.bicepparam` et redéployer |
| Écriture Key Vault refusée | rôle manquant | Obtenir **Key Vault Secrets Officer** sur le Key Vault |

## Annexe 3 — Références repo

- `packages/core/lib/src/app_env.dart` — clés de config + logique `entraConfigured`.
- `docs/E2E_AUTH_PREREQUIS.md` — détails formats/valeurs (§2, §4, §5).
- `tools/secrets/mobile-secrets.env.example` — modèle d'entrée (config + signature).
- `tools/secrets/set-keyvault-secrets.ps1` — chargement des secrets vers Key Vault.
- `docs/RELEASE_MOBILE.md` — procédure de release mobile + mise en place des 5 secrets/variables (PR #149).
- `docs/E2E_AUTH_PREREQUIS.md` — prérequis E2E (formats des valeurs, matrice dart-define).
- `infra/main.bicep`, `infra/params/*.bicepparam` — déploiement backend.

## Annexe 4 — Fournisseurs sociaux : configuration détaillée (vécu Certigo)

Valeurs réelles obtenues pour le tenant `certigoapp`. Les **secrets** (client secret,
contenu `.p8`) ne sont **pas** reproduits ici — conservez‑les dans un gestionnaire
de secrets, jamais dans le dépôt.

### Google (fournisseur intégré)
1. **Google Cloud Console** → un projet → **APIs & Services → Credentials →
   Create credentials → OAuth client ID → Web application**.
2. **Authorized redirect URIs** : ajoutez les URI de redirection du tenant CIAM
   (pour Certigo, les **7** URI `.../federation/...` du tenant ont été ajoutés).
3. Copiez le **Client ID** (`...apps.googleusercontent.com`) + le **Client secret**.
4. Entra → **All identity providers → Google** → collez Client ID + secret → **Save**.
5. Cochez **Google** dans le user flow `susi_certigo`.
> ⚠️ Si l'écran de consentement OAuth Google est en mode **Test**, seuls les
> **utilisateurs de test** déclarés peuvent se connecter. Passez en **Production**
> pour ouvrir la connexion à tous les comptes Google.

- Client ID Certigo : `858370449088-l34uene14i45lc9pla0t1mbarsqc6hoq.apps.googleusercontent.com`

### Microsoft — comptes personnels (OIDC personnalisé)
Les comptes Microsoft **personnels** (MSA) passent par un fournisseur **OpenID
Connect sur mesure** (et non le bouton Microsoft intégré) :
1. Tenant Entra classique : **App registrations → New registration** → *Accounts in
   any org directory and personal Microsoft accounts* → nom `Certigo MSA Login`.
2. **Authentication** → 2 redirect URIs Web se terminant par `.../federation/oauth2`.
3. **Certificates & secrets → New client secret** → copiez la **Value** (secret).
4. Entra External ID → **All identity providers → Custom → New OpenID Connect** →
   Client ID + secret + autorité `https://login.microsoftonline.com/...`,
   scope `openid profile email`, mappings (sub / email / name) → **Save**.
5. Cochez **Microsoft** dans le user flow `susi_certigo`.
> ⚠️ Un **client secret** expire : notez sa date d'échéance et renouvelez‑le avant,
> sinon le bouton Microsoft cessera de fonctionner.

- Client ID Certigo (MSA) : `df42c145-6dfc-4820-a79d-740acf27b565`

### Apple (fournisseur intégré)
Apple est **intégré** : Entra fabrique le JWT secret à partir de la clé `.p8`, du
Key ID, du Team ID et du Services ID.
1. **Apple Developer → Certificates, Identifiers & Profiles → Identifiers** :
   - **App ID** avec *Sign in with Apple* activé → notez le **Team ID**.
   - **Services ID** (= *Client ID* Apple), ex. `com.certigo.ciam.service` :
     - **Domains** : mettez **uniquement** `certigoapp.ciamlogin.com`
       (le sous‑domaine avec GUID est rejeté par le validateur Apple).
     - **Return URLs** : **une seule** →
       `https://certigoapp.ciamlogin.com/<tenant-id>/federation/oauth2`
       (le champ Apple est « comma delimited » et plante avec plusieurs lignes).
2. **Keys → New key** → activez *Sign in with Apple* → créez → **téléchargez le
   fichier `.p8`** (téléchargeable **une seule fois**) et notez le **Key ID**.
3. Entra → **All identity providers → Apple** → renseignez :
   - **Client ID** = le Services ID (`com.certigo.ciam.service`)
   - **Team ID** (`FFQPC7NC68`) · **Key ID** (`Z476P2APZV`)
   - **Client secret** = collez le contenu **texte** du fichier `.p8` → **Save**.
4. Cochez **Apple** dans le user flow `susi_certigo`.
> ⚠️ Apple impose une **durée de vie** au secret : prévoyez une **rotation ~6 mois**
> de la clé `.p8` (posez un rappel), sinon la connexion Apple cassera.

- Team ID : `FFQPC7NC68` · Services ID : `com.certigo.ciam.service` · Key ID : `Z476P2APZV`

---

*Ce document couvre le périmètre humain/infra. Le câblage du build (injection des
`--dart-define`) relève de la tâche « Fix CI Android auth » et n'est pas modifié ici.*
