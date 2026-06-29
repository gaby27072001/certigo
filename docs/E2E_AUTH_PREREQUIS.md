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
- Deep-link `certigo://auth` configuré : iOS `Info.plist`, Android `appAuthRedirectScheme`.
- `AppEnv` (`packages/core/lib/src/app_env.dart`) lit tous les dart-defines Entra.
- Tests auth verts : `auth_controller_test.dart` 18/18 (login/refresh/logout/cancel,
  4 providers, persistance, 401→refresh). Mockés, exécutables sans tenant.

## 2. À fournir par l'utilisateur (bloquant E2E réel)

| # | Élément | Détail |
|---|---------|--------|
| 1 | **Tenant Entra External ID (CIAM)** | Domaine `<domain>.ciamlogin.com`, tenant-id. |
| 2 | **App registration mobile** | client_id, redirect URI `certigo://auth`. |
| 3 | **IdP fédérés** | Microsoft Account, Google, Apple activés dans le tenant. |
| 4 | **API scope** | `api://<client-id>/user_impersonation` exposé. |
| 5 | **Compte de test** | 1 par fournisseur (MS, Google, Apple) + 1 email/pwd si backend. |
| 6 | **Appareil iOS physique** | Apple Sign-In ne marche pas en simulateur. |
| 7 | **Appareil Android physique** | callback `certigo` réel. |
| 8 | **Backend déployé (optionnel)** | requis seulement pour email/pwd + validation aud. |

## 3. Décision préalable : scheme deep-link

Code = `certigo://auth` (source de vérité pour le callback OAuth).
**Recommandé : garder `certigo`.** Sinon modifier iOS `Info.plist`, Android
`build.gradle`, `ENTRA_REDIRECT_URI` + redirect URIs tenant.

## 4. Matrice dart-define (mobile)

À passer en `--dart-define` (modèle : `tools/secrets/mobile-secrets.env.example`).

| dart-define | Valeur | entraConfigured |
|-------------|--------|:---:|
| `ENTRA_CLIENT_ID` | client_id app reg | ✅ requis |
| `ENTRA_AUTHORITY` | `https://<domain>.ciamlogin.com/<tenant-id>/v2.0` | ✅ requis |
| `ENTRA_REDIRECT_URI` | `certigo://auth` | défaut |
| `ENTRA_API_SCOPE` | `api://<client-id>/user_impersonation` | – |
| `ENTRA_DOMAIN_HINT_MICROSOFT` | `microsoft.com` | défaut |
| `ENTRA_DOMAIN_HINT_GOOGLE` | `google.com` | défaut |
| `ENTRA_DOMAIN_HINT_APPLE` | `apple.com` | défaut |

`entraConfigured` = client_id + authority non vides. Tant que vide → flux Entra
désactivé, app reste fonctionnelle.

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
