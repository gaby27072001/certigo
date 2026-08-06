# Pré-requis E2E — Authentification multi-fournisseurs + écrans gamification

> Document de passation : **ce que l'utilisateur doit fournir** pour exécuter la
> validation E2E réelle (vrai tenant Entra External ID + appareils). Le code et les
> tests automatisables sont déjà en place (cf. `apps/mobile/test/auth_controller_test.dart`,
> 18/18 vert). **Rien n'est provisionné ici** : tout ce qui suit est à fournir par
> l'utilisateur. Le plan associé : `plan.md` (Phases 0–4). Référence : `docs/ETAT_DU_PROJET.md` §13.

---

## 1. Ce qui est déjà fait (côté code, aucune action requise)

- Auth multi-fournisseurs câblée : Microsoft / Google / Apple fédérés derrière Entra
  External ID via `flutter_appauth`, + email/mot de passe via backend.
- Deep-link `certigo://auth/` configuré : iOS `Info.plist`, Android `appAuthRedirectScheme`.
- `AppEnv` (`packages/core/lib/src/app_env.dart`) lit tous les dart-defines Entra.
- Tests auth verts : `auth_controller_test.dart` 18/18 (login/refresh/logout/cancel,
  4 providers, persistance, 401→refresh). Mockés, exécutables sans tenant.

## 2. À fournir par l'utilisateur (bloquant E2E réel)

| # | Élément | Détail |
|---|---------|--------|
| 1 | **Tenant Entra External ID (CIAM)** | Domaine `<domain>.ciamlogin.com`, tenant-id. |
| 2 | **App registration mobile** | client_id, redirect URI `certigo://auth/` (slash final requis). |
| 3 | **IdP fédérés** | Microsoft Account, Google, Apple activés dans le tenant. |
| 4 | **API scope** | `api://<client-id>/user_impersonation` exposé. |
| 5 | **Compte de test** | 1 par fournisseur (MS, Google, Apple) + 1 email/pwd si backend. |
| 6 | **Appareil iOS physique** | Apple Sign-In ne marche pas en simulateur. |
| 7 | **Appareil Android physique** | callback `certigo` réel. |
| 8 | **Backend déployé (optionnel)** | requis seulement pour email/pwd + validation aud. |

## 3. Décision préalable : scheme deep-link

Code = `certigo://auth/` (source de vérité, **slash final requis**). Demande
initiale = `microlingo://auth`.
**Recommandé : garder `certigo`.** Sinon modifier iOS `Info.plist`, Android
`build.gradle`, `ENTRA_REDIRECT_URI` + redirect URIs tenant.

> ⚠️ **Slash final obligatoire (`certigo://auth/`).** Le SDK AppAuth iOS valide
> l'URL de redirection avec Azure/CIAM ; **sans** le slash final, le callback
> n'est pas reconnu côté iOS et la connexion **sociale** iOS « hang » (Android et
> e-mail non affectés). Le **schéma** reste `certigo` (seul le chemin gagne un
> slash). Réf. : FAQ officielle `flutter_appauth`. Enregistrez la valeur exacte
> `certigo://auth/` dans l'app registration Entra (plateforme « Applications de
> bureau et mobiles »).

## 4. Matrice dart-define (mobile)

À passer en `--dart-define` (modèle : `tools/secrets/mobile-secrets.env.example`).

| dart-define | Valeur | entraConfigured |
|-------------|--------|:---:|
| `ENTRA_CLIENT_ID` | client_id app reg | ✅ requis |
| `ENTRA_AUTHORITY` | `https://<domain>.ciamlogin.com/<tenant-id>/v2.0` | ✅ requis |
| `ENTRA_REDIRECT_URI` | `certigo://auth/` | défaut |
| `ENTRA_API_SCOPE` | `api://<client-id>/user_impersonation` | – |
| `ENTRA_DOMAIN_HINT_MICROSOFT` | `microsoft.com` | défaut |
| `ENTRA_DOMAIN_HINT_GOOGLE` | `google.com` | défaut |
| `ENTRA_DOMAIN_HINT_APPLE` | `apple.com` | défaut |

`entraConfigured` = client_id + authority non vides. Tant que vide → flux Entra
désactivé, app reste fonctionnelle.

> **Injection au build (CI)** : ces dart-defines sont câblés par
> `.github/workflows/release-android.yml` (étape `appconfig` : Key Vault
> `mobile-app-*`/`mobile-entra-*` → repli variables GitHub `vars.MOBILE_*`) et
> par `codemagic.yaml` (groupe `certigo_mobile_config`). Voir
> `docs/RELEASE_MOBILE.md` §2.3 pour les noms exacts et formats. **Aucune
> valeur réelle n'est committée.**

## 5. ✅ Alignements backend↔mobile (corrigés)

`backend/src/Certigo.Api/local.settings.json.example` est désormais aligné sur le
mobile (évite les **401 systématiques**). À fournir uniquement les vraies valeurs
`<domain>`, `<tenant-id>`, `<client-id>` :

1. **Authority** : backend = `https://<domain>.ciamlogin.com/<tenant-id>/v2.0` (CIAM),
   identique au mobile. ✅
2. **Audience** : `ENTRA_AUDIENCE` = `api://<client-id>` — le scope
   `api://<client-id>/user_impersonation` produit aud = `api://<client-id>`. ✅

L'infra (`infra/params/*.bicepparam` → `functionApp.bicep`) câble déjà
`ENTRA_AUTHORITY` / `ENTRA_AUDIENCE` sur les mêmes valeurs CIAM.

## 6. Tests automatisables (sans tenant, déjà OK)

- `melos run mobile-test` → `auth_controller_test.dart` (18/18).
- Pas de réseau, pas de tenant. C'est la preuve de la logique d'auth.

## 7. ⛔ Stop autopilot

Tout E2E ci-dessous **nécessite un vrai tenant + appareils** → non exécuté ici :
config tenant (Phase 1), login/refresh/logout réels (Phase 2), deep-link natif
(Phase 3), gamification on-device (Phase 4). À lancer après fourniture §2.

## 8. Checklist E2E exacte (à exécuter après déblocage §2)

Pré-requis : build strict qui **démarre** (le garde-fou `AppEnv.validate` échoue
au lancement si la config est incomplète — voir `docs/CONFIG_AUTH.md`).

Pour **chaque plateforme (iOS physique + Android physique)** et **chaque méthode
(e-mail, Microsoft, Google, Apple)** :

1. **Inscription (compte neuf)** — e-mail : créer un compte ; social : premier
   consentement IdP. → attendu : arrivée sur onboarding puis accueil.
2. **Connexion (compte existant)** → attendu : accueil ; médiane ≤ 3 s.
3. **Auto-connexion (relaunch)** — tuer/relancer l'app → attendu : accueil sans
   ressaisie (session restaurée).
4. **Callback deep-link** — vérifier le retour dans l'app après le navigateur
   système (schéma `certigo://auth/`).
5. **Annulation** — fermer le navigateur / bouton retour → attendu : message
   « Connexion annulée. », boutons **réarmés**, pas de spinner figé.
6. **Réseau lent / hors-ligne** — activer un réseau dégradé ou le mode avion →
   attendu : message réseau clair, réarmement ; en social, expiration au bout du
   filet de sécurité (120 s) → « La connexion a expiré. Réessayez. »
7. **Identifiants invalides** (e-mail) → « E-mail ou mot de passe incorrect. »
8. **Token expiré** — attendre/forcer l'expiration puis appeler l'API →
   rafraîchissement silencieux (200) ou, si échec, redirection connexion (401).
9. **Déconnexion** → retour écran de connexion ; relaunch → écran de connexion.
10. **Double-clic** — taps rapides sur un bouton → une seule tentative.

Notes : Apple Sign-In **exige un iPhone physique** (KO simulateur). Prévoir
1 compte neuf **et** 1 compte existant par fournisseur.

## 9. Matrice de résultats (à remplir lors de l'exécution)

| Méthode | Plateforme | Inscription | Connexion | Auto-connexion | Annulation | Réseau lent/offline | Token expiré | Déconnexion | Médiane (s) |
|---|---|---|---|---|---|---|---|---|---|
| E-mail | iOS | ☐ | ☐ | ☐ | n/a | ☐ | ☐ | ☐ | |
| E-mail | Android | ☐ | ☐ | ☐ | n/a | ☐ | ☐ | ☐ | |
| Microsoft | iOS | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Microsoft | Android | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Google | iOS | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Google | Android | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Apple | iOS | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | |
| Apple | Android | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | |

DoD : succès ≥ 98 %/provider, médiane ≤ 3 s, aucun blocage silencieux.

## 10. Ce qui est automatisé (sans tenant ni appareil)

Tests **verts** exécutables via `flutter test` dans `apps/mobile` +
`dart test` dans `packages/core` :

- `auth_controller_test.dart` — login/register/refresh/logout, 4 fournisseurs
  (fake), 401→refresh, **timeout social**, **annulation**, **erreur réseau**,
  causes normalisées + télémétrie.
- `router_redirect_test.dart` — **non-régression #154** (garde de redirection,
  pas de piège `/splash`, pas de boucle).
- `deep_link_config_test.dart` — garde des déclarations natives `certigo`
  (Info.plist + build.gradle) + cohérence `ENTRA_REDIRECT_URI`.
- `core_test.dart` — `AppEnv.validateConfig` (prod/dev, Entra manquant/partiel,
  URL dev en prod, schéma de redirection…).

**Blocage historique résolu par le sous-lot #155** : les tests widget échouaient
sous Flutter 3.44.x à cause de `font_awesome_flutter 10.7.0` (`IconData final`)
et `google_fonts 6.2.1` (`FontWeight` sans opérateur primitif). Prism embarque
désormais les trois familles typographiques et la seule police de marques
nécessaire, avec licences et checksums. Les écrans d'auth ne dépendent donc plus
de ces deux packages et restent compilables sur les SDK app et Prism.
