# Configuration & télémétrie de l'authentification mobile

> Source unique de vérité pour la config d'auth (`--dart-define`) et la
> télémétrie. Le code de validation vit dans
> `packages/core/lib/src/app_env.dart` (`AppEnv.validate` /
> `AppEnv.validateConfig`), le garde-fou de démarrage dans
> `apps/mobile/lib/bootstrap/bootstrap.dart`, la télémétrie dans
> `apps/mobile/lib/features/auth/application/auth_telemetry.dart`.

---

## 1. Garde-fou de configuration (fail-fast)

Au démarrage, `bootstrap()` appelle `AppEnv.validate()` :

- **prod / staging (flavors « stricts »)** : toute **erreur** bloque le lancement
  et affiche `ConfigErrorApp` (écran rouge listant les problèmes). Aucun login ne
  peut échouer silencieusement sur une config invalide.
- **dev** : les manques d'Entra deviennent des **avertissements** (journalisés
  `[config] …`, `assert` en debug) — le flux de développement e-mail/dev reste
  fonctionnel.

`CERTIGO_ENV` détermine le flavor (`prod` | `staging` | `dev`, défaut `dev`).

## 2. Variables `--dart-define`

| Variable | Rôle | Requis | Exemple valide | Invalide → symptôme |
|---|---|---|---|---|
| `CERTIGO_ENV` | Flavor de build | Non (défaut `dev`) | `prod` | valeur inconnue → traité comme `dev` (analytics off) |
| `API_BASE_URL` | Base de l'API backend | **Oui** (tous flavors) | `https://api.certigo.app/api` | vide → login e-mail « Pas de connexion » ; URL **dev** en prod → **erreur bloquante** ; `http://` en prod → erreur |
| `ENTRA_CLIENT_ID` | Client id app reg Entra | **Oui en prod/staging** (sauf `ENTRA_OPTIONAL`) | `00000000-0000-0000-0000-000000000000` | vide en prod → **erreur** (social désactivé) ; renseigné sans autorité → **erreur** (config partielle) |
| `ENTRA_AUTHORITY` | Autorité CIAM | **Oui en prod/staging** | `https://tenant.ciamlogin.com/<tid>/v2.0` | vide alors que client id présent → **erreur** |
| `ENTRA_REDIRECT_URI` | URI de redirection OIDC | Défaut `certigo://auth/` | `certigo://auth/` | schéma ≠ `certigo` → **erreur** (callback ne revient jamais) |
| `ENTRA_API_SCOPE` | Scope d'API protégée | Recommandé si Entra actif | `api://<client-id>/user_impersonation` | vide avec Entra actif → **avertissement** (risque 401) |
| `ENTRA_DOMAIN_HINT_MICROSOFT` | `domain_hint` Microsoft | Non | `microsoft.com` | vide → écran CIAM générique |
| `ENTRA_DOMAIN_HINT_GOOGLE` | `domain_hint` Google | Non | `google.com` | vide → écran CIAM générique |
| `ENTRA_DOMAIN_HINT_APPLE` | `domain_hint` Apple | Non | `apple.com` | vide → écran CIAM générique |
| `ENTRA_OPTIONAL` | Assume un build **e-mail uniquement** | Non (défaut `false`) | `true` | permet un build prod sans Entra (social désactivé) sans erreur bloquante |
| `DEV_AUTH_TOKEN` | Jeton dev (backend dev) | Non | `dev` | — (jamais utilisé en prod) |
| `FORCE_AUTH_UI` | Force l'écran de connexion en dev | Non | `true` | — |

### Règles de validation (`AppEnv.validateConfig`)

1. `API_BASE_URL` vide → erreur (tous flavors).
2. prod/staging + `API_BASE_URL` == URL dev par défaut → erreur.
3. prod/staging + `API_BASE_URL` non `https://` → erreur.
4. `ENTRA_CLIENT_ID` et `ENTRA_AUTHORITY` : l'un sans l'autre → erreur (config partielle).
5. Les deux vides : prod/staging (hors `ENTRA_OPTIONAL`) → erreur ; sinon avertissement.
6. `ENTRA_REDIRECT_URI` de schéma ≠ `certigo` → erreur si Entra (partiellement) configuré ou strict.
7. Entra configuré + `ENTRA_API_SCOPE` vide → avertissement (401 possible).

Le schéma natif `certigo` est déclaré dans `ios/Runner/Info.plist`
(`CFBundleURLSchemes`) et `android/app/build.gradle`
(`manifestPlaceholders.appAuthRedirectScheme`). Le test
`apps/mobile/test/deep_link_config_test.dart` garde ces déclarations.

> ⚠️ **Slash final obligatoire (`certigo://auth/`).** Le SDK AppAuth iOS valide
> l'URL de redirection avant de traiter le callback ; avec Azure/CIAM (Entra
> External ID) un redirect **sans** slash final n'est pas reconnu côté iOS → la
> connexion **sociale** iOS « hang » (le navigateur se ferme après la page de
> confirmation CIAM mais `authorize()` ne reçoit jamais le code). Android et le
> login e-mail ne sont pas affectés. Le **schéma** reste `certigo` (seul le
> chemin gagne un slash), donc les déclarations natives restent valables.
> Réf. : FAQ officielle `flutter_appauth`. Enregistrez la valeur **exacte**
> `certigo://auth/` dans l'app registration Entra (plateforme « Applications de
> bureau et mobiles »).

## 3. Injection au build (CI)

- **GitHub Actions** : `.github/workflows/release-android.yml` (étape `appconfig`)
  — Key Vault `mobile-app-*` / `mobile-entra-*`, repli `vars.MOBILE_*`.
- **Codemagic** : `codemagic.yaml`, groupe de variables `certigo_mobile_config`.
- **Modèle local** : `tools/secrets/mobile-secrets.env.example` → `set-keyvault-secrets.ps1`.

Aucune valeur réelle n'est committée. Un build prod avec des valeurs manquantes
**échoue au démarrage** (garde-fou) plutôt qu'en production silencieuse.

---

## 4. Télémétrie d'authentification

Interface `AuthTelemetry` (events **sans donnée sensible** : jamais de jeton,
mot de passe ou e-mail). Trois événements + une **cause normalisée** et un
**timing bout-en-bout** :

| Événement | Émis quand | Données |
|---|---|---|
| `auth_start` | Début d'une tentative (login/register/restore/social) | `method` |
| `auth_success` | Session obtenue | `method`, `durationMs` |
| `auth_failure` | Échec | `method`, `cause`, `durationMs` |

`method` ∈ { `email`, `register`, `microsoft`, `google`, `apple`, `restore`, `refresh` }.

`cause` (`AuthFailureCause`, source unique côté e-mail **et** social) :
`cancelled`, `timeout`, `network`, `provider_error`, `invalid_credentials`,
`config_error`, `unknown`.

Sinks : `NoopAuthTelemetry` (défaut release, aucune fuite) et
`DebugAuthTelemetry` (défaut debug, remplace l'ancien `[LOGIN-DBG]`). Un vrai
puits (Application Insights) implémentera `AuthTelemetry` sans toucher au code
d'auth — **branchement externe** (connection string requise).

### KPI minimaux (à surveiller)

| KPI | Définition | Cible |
|---|---|---|
| Taux de succès login / provider | `auth_success / auth_start` par `method` | **≥ 98 %** |
| Latence médiane de connexion | médiane des `durationMs` de `auth_success` (login/social) | **≤ 3 s** |
| Taux d'abandon | `failure(cause=cancelled) / auth_start` | à suivre (baseline) |
| Répartition des échecs | `auth_failure` groupé par `cause` | `config_error` ≈ 0 attendu |
| Seuil rollback release | taux d'échec auth (hors `cancelled`) sur fenêtre glissante | voir `docs/RELEASE_MOBILE.md` |
