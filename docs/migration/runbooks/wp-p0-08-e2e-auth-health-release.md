# Runbook — wp-p0-08-e2e-auth-health-release

> **Lot** : `wp-p0-08-e2e-auth-health-release` (Phase 0, dernier lot — intégration/release E2E)
> **Type** : **lot de CONFIRMATION** (idempotent — déjà remédié sur `main`)
> **Statut registre** : `in_review` (réserves/actions live listées §5 — **pas `done`**)
> **DoD (autorité)** : `docs/migration/work-packages.yaml` → `wp-p0-08-e2e-auth-health-release`
> **Base** : `main` · **PR** : DRAFT, **NON mergée** (décision de merge = Gabriel via orchestrateur)

Ce document est le **livrable versionné** du lot. Il n'invente aucun code : il **audite finding-par-finding** l'état réel de `main`, **chiffre la DoD**, et fournit un **runbook de release E2E** qui **référence** (sans dupliquer) les runbooks opérationnels déjà présents (`docs/deployment-runbook.md`, `docs/RELEASE_MOBILE.md`, `docs/E2E_AUTH_PREREQUIS.md`).

---

## 1. Verdict d'idempotence

`git fetch origin && git diff origin/main...HEAD` → **aucun écart** avant bookkeeping. Les 4 findings du périmètre P0 sont **déjà présents et cohérents sur `main`**. Conformément aux lots p0-01…07, ce lot est un **lot de confirmation** : audit + bookkeeping registre + ce livrable ; **zéro code inventé**.

---

## 2. Audit finding-par-finding (preuves `fichier:ligne` sur `main`)

### (a) E2E auth mobile : OIDC + PKCE → refresh silencieux → 401 déclenche ré-auth — ✅ PRÉSENT

| Maillon | Preuve |
|---|---|
| OIDC + PKCE (authorization code flow) | `apps/mobile/lib/features/auth/application/auth_gateway.dart` — génération `code_verifier`/`code_challenge` (PKCE) + échange de code |
| Refresh silencieux | `auth_gateway.dart` — rafraîchissement de token via refresh_token ; `auth_controller.dart` — `_tryRefresh()` / `handleUnauthorized()` |
| 401 → ré-auth | `packages/data/lib/src/api/api_client.dart` — Bearer injecté (~l.65-73), `401 → onUnauthorized()` (~l.74-79), `AuthFailure` sur 401/403 (~l.153) |
| Tests | `auth_controller_test.dart` (suite d'unités auth), `app_smoke_test.dart` (parcours E2E mobile) |

**Chaîne complète vérifiée** : login PKCE → session persistée → appel API porteur Bearer → expiration → refresh silencieux → si refresh échoue/401 persistant → invalidation session → ré-authentification.

### (b) GET `/health` interroge Cosmos et renvoie vert + correlation id — ✅ PRÉSENT

- `backend/src/Certigo.Api/Functions/HealthFunctions.cs`
  - Route `health`, **`AuthorizationLevel.Anonymous`** (allow-listée dans `JwtAuthMiddleware`, pollable sans token) — l.16-19
  - **Sonde Cosmos réelle** : `await probe.CheckAsync(...)` — l.23
  - Vert : `{ status = "healthy", checks = { cosmos = "ok" } }` (200) — l.24-26
  - Rouge : `{ status = "unhealthy", checks = { cosmos = "error" } }` (**503 ServiceUnavailable**) — l.31-34
- `backend/src/Certigo.Api/Functions/HealthProbe.cs`
  - `CosmosHealthProbe` — l.10 ; `CheckAsync → cosmos.Users.ReadContainerAsync(...)` — l.13 (touche réellement Cosmos DB)

### (c) Correlation id propagé de bout en bout — ✅ PRÉSENT

- `backend/src/Certigo.Api/Middleware/ExceptionMiddleware.cs`
  - `ResolveCorrelationIdAsync()` — l.76 : **honore un `x-correlation-id` entrant** (`request.Headers.TryGetValues("x-correlation-id", …)` — l.80) sinon **en génère un**
  - Attaché au scope de log : `logger.BeginScope({ ["CorrelationId"] = … })` — l.21
  - **Renvoyé au client** : `response.Headers.Add("x-correlation-id", correlationId)` — l.106
  - Exposé dans la réponse ProblemDetails : `Extensions["correlationId"]` — l.112

### (d) Première release E2E taguée (backend + gate mobile `beta`) — ✅ PRÉSENT

- **Tags Git** (local **et** `origin`) : `v1.0.0`, `v1.0.1`, `v1.0.2`, `build-aab-latest`
- **Pipeline backend** : `.github/workflows/cd-backend.yml` — dispatch opérateur `promote-backend` strict, déploiement OIDC sous Environment, Bicep `infra/main.bicep` + code .NET 8, RG `rg-certigo-$ENV` (westeurope), retry 5×45 s
- **Pipeline mobile Android** : `.github/workflows/release-android.yml` — AAB signé → Google Play, **gates bloquants** `flutter analyze` + `flutter test`, **`environment: beta`** (= gate d'approbation *required reviewers*), package `com.certigo.mobileapp`, Flutter 3.27.4
- **Pipeline mobile iOS** : `.github/workflows/release-ios.yml` — IPA TestFlight, `environment: beta`, runner self-hosted macOS
- **Promotion** : `.github/workflows/cd-backend.yml` — `promote-backend` explicite avec run de release immuable ; le workflow legacy échoue fermé

---

## 3. DoD machine-vérifiable (résultats réels)

| Contrôle | Commande | Résultat |
|---|---|---|
| Build Release | `dotnet build backend/Certigo.sln -c Release` | ✅ **0 warning / 0 erreur** |
| Tests | `dotnet test` | ✅ **531 réussis / 0 échec / 6 ignorés** (Cosmos, sans émulateur) |
| — Domain | | 224 réussis |
| — Application | | 160 réussis |
| — Infrastructure | | 23 réussis + 6 ignorés (Cosmos) |
| — Api | | 124 réussis |
| IaC Bicep | `az bicep build infra/main.bicep` | ⏭️ **SKIP** — IaC non touché par ce lot |
| Flutter | `flutter analyze` / tests UI | ⏭️ **SKIP local** — mobile non touché ; gates exécutés en CI (`release-android.yml`) |
| Secrets en clair | `grep` motifs de secrets | ✅ **aucun** dans les livrables |
| Registre YAML | `python -c "import yaml; …"` | ✅ parse |
| Registre JSON | `python -c "import json,glob; …"` | ✅ parse |
| Registre JSONL | `python -c "import json; …"` | ✅ parse |

---

## 4. Runbook — release E2E (référence, ne pas ré-exécuter à l'aveugle)

> But : documenter la séquence de la **première release E2E** (déjà taguée `v1.0.x`). Toute nouvelle release suit cet ordre. Les détails d'environnement/secrets sont dans les runbooks existants — **liens ci-dessous**, non dupliqués.

### 4.1 Pré-requis (une seule fois)
Voir **`docs/E2E_AUTH_PREREQUIS.md`** (tenant Entra External ID, app registration, IdPs, appareils physiques) et **`docs/deployment-runbook.md`** §OIDC/environments (federated credentials GitHub↔Entra, secrets d'environnement).

### 4.2 Backend — déploiement + validation santé
1. Merger sur `main` (via PR approuvée) et attendre la CI ; ce merge ne déclenche aucun déploiement backend.
2. Après la réactivation contrôlée et le GO décrits dans `docs/deployment-runbook.md`,
   un opérateur envoie le dispatch strict `promote-backend` pour `release:dev`.
3. Le pipeline provisionne l'infra (`infra/main.bicep`) puis déploie le code .NET 8 sur la Function App du RG `rg-certigo-<env>`.
4. **Validation santé** (sonde Cosmos verte) :
   ```bash
   curl -i https://<function-app>.azurewebsites.net/api/health
   # Attendu : HTTP/1.1 200 OK
   #           { "status":"healthy", "checks":{ "cosmos":"ok" } }
   #           header: x-correlation-id: <guid>
   ```
   Si `503 { "cosmos":"error" }` → voir `docs/deployment-runbook.md` §Validation (RBAC managed identity / endpoint Cosmos / egress réseau).
5. **Validation auth** (200 avec token valide, 401 sans) : `docs/deployment-runbook.md` §Validation auth (smoke test 200/401).

### 4.3 Mobile — release gated `beta`
1. Déclencher `release-android.yml` (et/ou `release-ios.yml`).
2. **Gates bloquants** exécutés automatiquement : `flutter analyze` + `flutter test` — un échec **stoppe** la release.
3. **Gate `environment: beta`** : la job de publication attend l'**approbation d'un *required reviewer*** (configuration GitHub Environments — **action humaine**, cf. §5.4).
4. Après approbation : AAB signé → Google Play (piste `beta`) ; IPA → TestFlight.

### 4.4 Tag de release
Les tags `v1.0.0…v1.0.2` + `build-aab-latest` **existent déjà** (local + origin). **Aucun tag à pousser dans le cadre de ce lot** — pour une future version :
```bash
git tag -a vX.Y.Z -m "Certigo vX.Y.Z"
git push origin vX.Y.Z
```

### 4.5 Corrélation E2E (diagnostic)
Un client peut fixer `x-correlation-id: <guid>` sur sa requête ; le backend l'honore, le journalise (scope de log) et le renvoie (header + `problem.correlationId`). Utiliser ce guid pour tracer une requête bout-en-bout dans les logs.

---

## 5. Réserves / actions live (→ le lot reste `in_review`, PAS `done`)

Conformément à la règle de blocage (préférence de Gabriel) : les points suivants exigent une **action humaine/live** ou dépendent d'autres lots non finalisés. **Aucun n'est bloquant pour la PR de confirmation**, mais tous doivent être **traités hors de cette PR draft**.

1. **Dépendances non mergées** — `depends_on: [wp-p0-01-jwt-key-vault, wp-p0-07-github-branch-protection-release]` sont encore `todo` sur `main` (leurs PR draft ne sont pas mergées). Ce lot **confirme** l'état E2E ; sa clôture (`done`) devrait suivre celle de ses dépendances via l'orchestrateur.
2. **Tags release** — `v1.0.0…v1.0.2` existent déjà → **aucun tag live à pousser ici**. Le §4.4 est documentaire.
3. **Correlation id côté mobile** — le backend est le **point de propagation autoritaire** (honore l'entrant, sinon génère, renvoie). Le client mobile **n'émet pas** de `x-correlation-id` propre. Nuance mineure, **pas un défaut de DoD** (la DoD porte sur `/health` + propagation backend). Amélioration éventuelle : faire émettre un guid par requête côté `api_client.dart` (hors périmètre de ce lot).
4. **Gate mobile `beta`** — `environment: beta` avec *required reviewers* est une **configuration GitHub Environments** (Settings → Environments → `beta` → Required reviewers). C'est une **action admin GitHub**, à valider/maintenir hors PR :
   - Vérifier : `Settings → Environments → beta → Deployment protection rules → Required reviewers` non vide.
   - Rollback : retirer le reviewer requis rétablit une publication non gated (déconseillé).
5. **Merge** — cette PR est **DRAFT et ne doit jamais être mergée** par l'agent (ni admin, ni auto). La décision appartient à **Gabriel via l'orchestrateur**.

---

## 6. Rollback

Aucun changement de code/IaC n'est introduit par ce lot. Rollback = **`git revert` du commit de bookkeeping** (registre) sans impact runtime. Détail (autorité) : `work-packages.yaml` → `wp-p0-08-e2e-auth-health-release.rollback`.

---

## 7. Traçabilité registre

- `docs/migration/state/wp-p0-08-e2e-auth-health-release.json` — statut `in_review`, `session_id`, `branch`, `pr`, `checkpoint`.
- `docs/migration/log.jsonl` — transitions `todo → in_progress → in_review` (append-only).
- `docs/migration/STATE.md` — ligne du lot mise à jour (statut + lien PR).
- `docs/migration/work-packages.yaml` — `status: in_review`.
