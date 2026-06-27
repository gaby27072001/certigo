# Runbook de déploiement — Microlingo (Phase 0 : socle de production)

Ce runbook décrit les étapes **humaines** (droits admin Azure AD / GitHub) nécessaires pour
amorcer le **premier déploiement de l'environnement `dev`** et valider l'authentification réelle.

> **Pourquoi ce runbook ?** Le pipeline `.github/workflows/cd-backend.yml` est un pipeline de
> déploiement complet (infra Bicep + code Functions), mais il ne s'exécutait jamais car :
> 1. les deux jobs ciblaient en dur un runner self-hosted non provisionné ;
> 2. les secrets OIDC `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` n'existaient pas.
>
> Le point (1) est désormais débloqué **côté repo** : le runner est rendu configurable
> (`self-hosted` par défaut, `ubuntu-latest` en option) et les jobs sont rattachés à un
> **GitHub Environment**. Les points OIDC + environnements + déclenchement restent des
> **actions humaines** décrites ci-dessous.

---

## Répartition repo vs. actions humaines

| Élément | Statut | Où |
|---|---|---|
| Runner configurable (`runner` input + `runs-on` dynamique) | ✅ Fait (cette PR) | `cd-backend.yml` |
| Jobs rattachés à un `environment:` | ✅ Fait (cette PR) | `cd-backend.yml` |
| Clarification placeholders Entra en dev | ✅ Fait (cette PR) | `infra/params/dev.bicepparam` |
| App registration + federated credentials OIDC | ⛔ **Humain** (admin Azure AD) | §T0.1 |
| 3 secrets GitHub | ⛔ **Humain** (admin repo) | §T0.1 |
| GitHub Environments `dev`/`staging`/`prod` + reviewers | ⛔ **Humain** (admin repo) | §T0.3 |
| Branch protection sur `main` | ⛔ **Humain** (admin repo) | §T0.3 |
| Déploiement infra `dev` | ⛔ **Humain** (ou amorçage local) | §T0.4 |
| Validation auth (200/401) | ⛔ **Humain** | §T0.5 |
| Smoke test | ⛔ **Humain** | §T0.6 |

---

## Variables communes

```bash
GH_ORG="gchambaud_microsoft"
GH_REPO="Microlingo"
APP_NAME="microlingo-github-oidc"

# Détectés dans l'environnement de dev (à confirmer via `az account show`) :
SUBSCRIPTION_ID="b8952c8c-8f72-469d-99cd-ac906da4e2fc"   # MCAPS-Hybrid-REQ-150432-2026
TENANT_ID="16b3c013-d300-468d-ac64-7eda0820b6d3"          # fdpo.onmicrosoft.com
```

Pré-requis CLI : `az` (Azure CLI), `gh` (GitHub CLI) authentifiés avec les droits adéquats.
Vérifier le contexte Azure :

```bash
az account show -o table
```

---

## T0.1 — Identité OIDC + secrets GitHub

**Acteur : admin Azure AD + admin du repo GitHub.**

### Pourquoi Owner (et pas Contributor) ?

`infra/modules/functionApp.bicep` crée **4 attributions de rôle** (Storage Blob Data Owner,
Storage Queue Data Contributor, Key Vault Secrets User, Cosmos SQL Data Contributor). Créer des
role assignments requiert la permission `Microsoft.Authorization/roleAssignments/write`, incluse
dans **Owner** (mais **pas** dans Contributor). L'identité de déploiement doit donc être **Owner**
au scope souscription, sinon `deploy-infra` échoue.

### Sujets OIDC

Comme les jobs portent désormais `environment: <env>`, le **sujet** du token OIDC émis par GitHub
devient `repo:<org>/<repo>:environment:<env>`. On crée donc **une federated credential par
environnement** (dev/staging/prod). Une FC supplémentaire pour `push` sur `main` est optionnelle
(le push déclenche l'environnement `dev`, déjà couvert par la FC `dev`).

### Commandes

```bash
# 1) App registration + service principal
APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
az ad sp create --id "$APP_ID"

# 2) Federated credentials — une par environnement
for ENVNAME in dev staging prod; do
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"github-env-$ENVNAME\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GH_ORG/$GH_REPO:environment:$ENVNAME\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
done

# (Optionnel) FC pour les push directs sur main sans environnement explicite.
# Inutile si les push passent par l'environnement dev (cas par défaut).
# az ad app federated-credential create --id "$APP_ID" --parameters "{
#   \"name\": \"github-branch-main\",
#   \"issuer\": \"https://token.actions.githubusercontent.com\",
#   \"subject\": \"repo:$GH_ORG/$GH_REPO:ref:refs/heads/main\",
#   \"audiences\": [\"api://AzureADTokenExchange\"]
# }"

# 3) Rôle Owner au scope souscription
az role assignment create --assignee "$APP_ID" --role "Owner" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 4) Secrets GitHub (niveau repo)
gh secret set AZURE_CLIENT_ID       --repo "$GH_ORG/$GH_REPO" --body "$APP_ID"
gh secret set AZURE_TENANT_ID       --repo "$GH_ORG/$GH_REPO" --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --repo "$GH_ORG/$GH_REPO" --body "$SUBSCRIPTION_ID"
```

> 💡 Si la politique de l'org restreint la création d'app registrations, faire exécuter ces
> commandes par un administrateur du tenant `fdpo.onmicrosoft.com`.

---

## T0.2 — Débloquer le runner (déjà fait côté repo) + amorçage

**Côté repo (fait dans cette PR) :** `cd-backend.yml` expose un input `runner`
(`self-hosted` par défaut, `ubuntu-latest` en option) ; le `runs-on` des deux jobs est désormais :

```yaml
runs-on: ${{ inputs.runner == 'ubuntu-latest' && fromJSON('["ubuntu-latest"]') || fromJSON('["self-hosted","Linux","X64","microlingo-ci"]') }}
```

Les deux branches du ternaire renvoient un **tableau** ; un `push` (sans input) retombe sur
self-hosted, ce qui **préserve le comportement actuel**.

### ⚠️ Risque EMU (à arbitrer avant de choisir `ubuntu-latest`)

D'après `infra/ci-runner/README.md`, **les runners GitHub-hosted sont bloqués par la politique
EMU** de l'entreprise — c'est la raison d'être du runner self-hosted (egress NAT stable
`20.86.156.64`). Choisir `ubuntu-latest` **peut donc être refusé par l'org** : le job ne
démarrerait pas. Trois chemins d'amorçage, par ordre de préférence :

1. **Dispatch `runner=ubuntu-latest`** — le plus simple **si** l'org l'autorise (à tester).
2. **Déploiement manuel local** (§T0.4 option A) depuis une machine dev déjà authentifiée Owner —
   contourne entièrement le problème runner/EMU pour le tout premier déploiement.
3. **Provisionner le runner self-hosted** (`infra/ci-runner/network.bicep`) — tâche **P1**.

---

## T0.3 — GitHub Environments + branch protection

**Acteur : admin du repo.**

Créer les trois environnements (les noms doivent correspondre à `TARGET_ENV` et aux
`*.bicepparam`). `prod` reçoit des **reviewers requis** + restriction de branche.

```bash
# dev et staging : pas de reviewer requis
gh api -X PUT "repos/$GH_ORG/$GH_REPO/environments/dev"
gh api -X PUT "repos/$GH_ORG/$GH_REPO/environments/staging"

# Récupérer l'ID numérique du/des reviewer(s) (User ou Team)
REVIEWER_ID=$(gh api "users/<github-username>" --jq '.id')

# prod : reviewers requis + déploiement limité aux branches protégées
gh api -X PUT "repos/$GH_ORG/$GH_REPO/environments/prod" \
  -F "reviewers[][type]=User" \
  -F "reviewers[][id]=$REVIEWER_ID" \
  -F "deployment_branch_policy[protected_branches]=true" \
  -F "deployment_branch_policy[custom_branch_policies]=false"
```

### Branch protection sur `main`

Via **Settings → Branches → Add rule** (ou `gh api`), exiger PR + au moins 1 review avant merge :

```bash
gh api -X PUT "repos/$GH_ORG/$GH_REPO/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  -F "required_pull_request_reviews[required_approving_review_count]=1" \
  -F "enforce_admins=true" \
  -F "required_status_checks=null" \
  -F "restrictions=null"
```

> Adapter le nombre de reviewers et l'application aux admins selon la politique de l'équipe.

---

## T0.4 — Déployer l'infra `dev`

**Acteur : humain (ou amorçage local).** L'infra crée : RG `rg-microlingo-dev`, Application
Insights, Cosmos DB, Storage, Key Vault, Function App (sans diagnostics durcis en dev).

### Étape 1 — What-if (lecture seule, recommandé d'abord)

```bash
az deployment sub what-if \
  --name microlingo-dev \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam
```

### Étape 2 — Déploiement réel

**Option A — amorçage manuel local** (contourne le runner/EMU pour le 1er déploiement) :

```bash
az deployment sub create \
  --name microlingo-dev \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam \
  --query 'properties.outputs.functionAppName.value' -o tsv
```

**Option B — via le pipeline** (une fois T0.1 + T0.3 prêts) :

```bash
gh workflow run cd-backend.yml --repo "$GH_ORG/$GH_REPO" \
  -f environment=dev -f runner=ubuntu-latest    # ou -f runner=self-hosted
```

> Le job `deploy-infra` capture l'output `functionAppName`, réutilisé par `deploy-backend`
> pour le zip-deploy (avec boucle de retry × 5 contre la latence de propagation RBAC).

### Cohérence des paramètres `dev`

- `env='dev'`, `location='westeurope'`, `appName='microlingo'`.
- `cosmosLocation='northeurope'` (westeurope a des limites de capacité AZ).
- `entraAuthority` / `entraAudience` = **placeholders** : **OK en dev** car `authMode='dev'`
  ⇒ `DevTokenValidator` (Entra non appliqué). Renseigner les vraies valeurs pour staging/prod.

---

## T0.5 — Valider l'authentification (Entra External ID)

`Program.cs:61` enregistre un `CompositeTokenValidator` :
`LocalJwtTokenValidator` (toujours) → puis `DevTokenValidator` (si `AUTH_MODE=dev`) **ou**
`EntraTokenValidator` (si `ENTRA_AUTHORITY` + `ENTRA_AUDIENCE` fournis). Garde-fou :
`AUTH_MODE=dev` est interdit en Production sauf `AUTH_ALLOW_DEV=true`.

Le middleware `JwtAuthMiddleware` exige `Authorization: Bearer …` **sauf** sur
`/api/health`, `/api/auth/register`, `/api/auth/login`, `/api/auth/refresh`.

### Chemin 1 — Login local JWT (auto-suffisant, sans Entra) — recommandé pour valider `dev`

```bash
APP_HOST="https://<functionAppName>.azurewebsites.net"

# 1) S'enregistrer (anonyme)
curl -s -X POST "$APP_HOST/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke@microlingo.test","password":"P@ssw0rd!"}'

# 2) Se connecter (anonyme) → récupérer le JWT
TOKEN=$(curl -s -X POST "$APP_HOST/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke@microlingo.test","password":"P@ssw0rd!"}' | jq -r '.accessToken')

# 3) Sans token → 401
curl -s -o /dev/null -w "sans token: %{http_code}\n" "$APP_HOST/api/catalog/tracks"

# 4) Avec token → 200
curl -s -o /dev/null -w "avec token: %{http_code}\n" \
  "$APP_HOST/api/catalog/tracks" -H "Authorization: Bearer $TOKEN"
```

> Adapter le nom du champ token (`accessToken`) au contrat réel d'`AuthFunctions` si nécessaire.

### Chemin 2 — Entra External ID (CIAM réel) — pour staging/prod

Nécessite un environnement avec `authMode='prod'` et de **vraies** valeurs
`ENTRA_AUTHORITY` / `ENTRA_AUDIENCE`, puis un token obtenu du tenant CIAM Microlingo. En `dev`,
Entra n'est **pas** appliqué (`DevTokenValidator`), donc tout bearer non vide est accepté.

---

## T0.6 — Smoke test

```bash
APP_HOST="https://<functionAppName>.azurewebsites.net"

# /health (anonyme) — vérifie l'accès Cosmos. 200 {status:healthy} / 503 {status:unhealthy}
curl -s "$APP_HOST/api/health"

# endpoint contenu (token requis) — 401 sans token
curl -s -o /dev/null -w "tracks sans token: %{http_code}\n" "$APP_HOST/api/catalog/tracks"

# endpoint contenu — 200 avec token (en dev, tout bearer non vide suffit)
curl -s -o /dev/null -w "tracks avec token: %{http_code}\n" \
  "$APP_HOST/api/catalog/tracks" -H "Authorization: Bearer devtoken"

# endpoint quiz (token requis)
curl -s -X POST "$APP_HOST/api/quiz/<lessonId>/submit" \
  -H "Authorization: Bearer devtoken" \
  -H "Content-Type: application/json" \
  -d '{}'
```

Critères de succès : `/api/health` → `200 {status:healthy}` ; `/api/catalog/tracks` → `401`
sans token et `200` avec ; `/api/quiz/<lessonId>/submit` répond (selon payload).

---

## Hors-scope Phase 0 (P1, sessions ultérieures)

- Provisionner le runner self-hosted (`infra/ci-runner/network.bicep`).
- Vraies valeurs Entra CIAM + déploiements `staging` / `prod`.
- Diagnostics / politiques durcis (déjà conditionnés `env != dev` dans le Bicep).
