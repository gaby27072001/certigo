# Runbook de déploiement — Microlingo (Phase 0 : socle de production)

Ce runbook décrit les étapes **humaines** (droits admin Azure AD / GitHub) nécessaires pour
amorcer le **premier déploiement de l'environnement `dev`** et valider l'authentification réelle.

> **Pourquoi ce runbook ?** Le pipeline `.github/workflows/cd-backend.yml` est un pipeline de
> déploiement complet (infra Bicep + code Functions). Le chemin critique est désormais
> **compatible EMU (self-hosted obligatoire)** :
> 1. les jobs critiques backend restent sur self-hosted (GitHub-hosted est bloqué par policy EMU) ;
> 2. les workflows critiques ciblent le label historique `law-microlingo`, désormais présent sur les runners actifs ;
> 3. l'auth Azure reste via OIDC (`azure/login@v2`) avec permissions minimales.
>
> Les actions humaines restantes concernent surtout la gouvernance (OIDC Azure AD, environments,
> branch protection), pas l'édition des workflows runners.

---

## Répartition repo vs. actions humaines

| Élément | Statut | Où |
|---|---|---|
| Chemin critique backend self-hosted (`law-microlingo`) | ✅ Fait (main + PR recalée docs) | `cd-backend.yml`, `ci-backend.yml` |
| Jobs rattachés à un `environment:` | ✅ Fait (cette PR) | `cd-backend.yml` |
| Clarification placeholders Entra en dev | ✅ Fait (cette PR) | `infra/params/dev.bicepparam` |
| App registration + federated credentials OIDC | ✅ **Fait (session)** — app `microlingo-github-actions` déjà existante + 3 FC `environment:<env>` ajoutées | §T0.1 |
| 3 secrets GitHub | ✅ **Fait (session)** — déjà positionnés | §T0.1 |
| `publicNetworkAccess` storage épinglé `Enabled` (anti-dérive) | ✅ Fait (cette PR) | `infra/modules/storage.bicep` + `infra/main.bicep` |
| GitHub Environments `dev`/`staging`/`prod` | ✅ **Fait (session)** — créés ; ⚠️ reviewers `prod` bloqués (billing 422) | §T0.3 |
| Branch protection sur `main` | ⛔ **Humain** (admin repo) | §T0.3 |
| Déploiement infra `dev` | ✅ **Fait (session)** — amorçage local réel | §T0.4 |
| Validation auth (200/401) | ⛔ **Bloqué** — Functions n'indexent pas (échec plateforme Flex) | §T0.5 + §Statut réel |
| Smoke test | ⛔ **Bloqué** — idem | §T0.6 + §Statut réel |

### Check-list d'exploitation (utilisateur non-admin)

1. Déclencher `cd-backend.yml` avec `environment=dev|staging|prod` (aucun paramètre runner à fournir).
2. Vérifier que les jobs `deploy-infra` puis `deploy-backend` démarrent sur un runner portant `law-microlingo`.
3. En cas d'échec Azure login, contrôler uniquement les 3 secrets repo : `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
4. Pour une promotion, lancer `promote-backend-staging-prod.yml` (enchaînement staging puis prod).

### Pourquoi Azure-first (long terme)

Le workflow GitHub reste un **orchestrateur** (dispatch, ordering, traçabilité), mais la
vérité opérationnelle est portée par Azure pour limiter la dépendance aux droits admin GitHub.

| Domaine | Source de vérité | Pourquoi c'est durable pour un non-admin GitHub |
|---|---|---|
| Authentification de déploiement | Entra ID + OIDC federated credentials | Plus de secret long-lived à tourner côté runner ; contrôle d'accès piloté par Azure RBAC. |
| Autorisations d'exécution | RBAC Azure (scope subscription/resource group) | Les droits de déploiement ne dépendent pas de la gestion des runners/labels GitHub. |
| État de l'infra | Bicep + Azure Resource Manager (`az deployment`) | Déploiement idempotent et audit Azure centralisé, indépendamment du type de runner. |
| Configuration runtime app | Azure Functions/App Service settings + ressources Azure | Les changements d'exploitation sont opérables dans Azure même si GitHub admin est indisponible. |
| Gouvernance production | GitHub environments (approvals) + garde-fous Azure | Le gate GitHub reste utile, mais la sécurité critique est déjà enforce côté Azure. |

Limites connues : ce modèle suppose des permissions Azure correctement déléguées (OIDC + RBAC),
et la disponibilité d'au moins un runner self-hosted online avec le label `law-microlingo`.

### Réconciliation des labels runners

Les deux runners existants (`vm-microlingo-runner`, `vm-microlingo-runner-2`) portent désormais
les labels custom **`law-microlingo`** et **`microlingo-ci`** en plus des labels système
(`self-hosted`, `Linux`, `X64`).  
Le label a été ajouté via l'API GitHub :
`POST /repos/{owner}/{repo}/actions/runners/{id}/labels`.

Conséquence : les workflows de `main` qui exigent `law-microlingo` matchent sans édition de
workflow, y compris après redémarrage/offline-online du runner.

### Risque / rollback (chemin critique EMU)

- **Risque principal** : aucun runner self-hosted online avec le label `law-microlingo`.
- **Rollback repo** : aucun requis (les workflows `main` sont déjà cohérents avec les labels runner réconciliés).
- **Rollback opérationnel** : démarrer/maintenir online la VM runner Azure (ou activer un auto-start), puis redéclencher le workflow.

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

> ✅ **Déjà réalisé dans ce tenant (session Phase 0).** L'identité OIDC existe déjà :
> app registration **`microlingo-github-actions`** (`appId 4bfc43dc-6a25-404e-a6ab-d19784ab0673`,
> SP objectId `15d2b34a-c0a0-4b5d-8360-b895a8164706`). Les **3 secrets repo**
> (`AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID`) sont **déjà positionnés**, et
> les 3 federated credentials `github-env-dev` / `github-env-staging` / `github-env-prod`
> (sujet `repo:…:environment:<env>`) ont été **ajoutées cette session**. Les commandes ci-dessous
> sont la **recette de référence/reproduction** (par ex. pour un nouveau tenant) — ne pas
> recréer une seconde app `microlingo-github-oidc` sous peine de doublon. Pour réutiliser
> l'existant, faire `APP_ID=4bfc43dc-6a25-404e-a6ab-d19784ab0673`.

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

**Côté repo :**
- les jobs critiques de `cd-backend.yml` (`deploy-infra`, `deploy-backend`) ciblent
  `runs-on: [self-hosted, Linux, X64, law-microlingo]` ;
- `ci-backend.yml` conserve le même label cible côté self-hosted ;
- le chemin critique reste compatible avec la contrainte EMU (self-hosted obligatoire).

### Isolement des dépendances runner

Le blocage ne vient pas du YAML mais de la disponibilité runner : sous EMU, l'exécution critique
reste self-hosted. La durabilité non-admin passe donc par l'exploitation Azure de la VM runner
(`rg-microlingo-ci`, tenant Microsoft Non-Production), pas par une migration vers hosted.

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

### ⚠️ Limitation GitHub billing observée (session Phase 0)

Sur ce dépôt (privé, détenu par un **compte User**), l'ajout de **required reviewers** à un
environnement renvoie **HTTP 422** : la fonctionnalité « environment protection rules » (reviewers
requis, wait timer, branch policy) n'est disponible que pour les **dépôts publics** ou sous un plan
payant **GitHub Pro / Team / Enterprise**. Conséquence cette session : les environnements
`dev` / `staging` / `prod` ont bien été **créés**, mais le **gate reviewer sur `prod` n'a pas pu
être posé**. Résiduel admin : passer le repo sous un plan payant (ou le déplacer sous une org
éligible), puis ré-exécuter le bloc `prod` ci-dessus.

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
  -f environment=dev
```

> Le job `deploy-infra` capture l'output `functionAppName`, réutilisé par `deploy-backend`
> pour le zip-deploy (avec boucle de retry × 5 contre la latence de propagation RBAC).

### Cohérence des paramètres `dev`

- `env='dev'`, `location='westeurope'`, `appName='microlingo'`.
- `cosmosLocation='northeurope'` (westeurope a des limites de capacité AZ).
- `entraAuthority` / `entraAudience` = **placeholders** : **OK en dev** car `authMode='dev'`
  ⇒ `DevTokenValidator` (Entra non appliqué). Renseigner les vraies valeurs pour staging/prod.

### Storage `publicNetworkAccess` — dérive réconciliée (cette PR)

Le module `infra/modules/storage.bicep` ne fixait **pas** `publicNetworkAccess` ; le compte de
stockage `dev` live avait dérivé vers `Disabled`. En **Flex Consumption**, la plateforme **tire le
package applicatif via l'endpoint public** du Storage : avec `Disabled` et **sans private endpoint**,
le déploiement échoue (observé cette session : `403 InaccessibleStorageException` au config-zip).
Le paramètre est désormais **explicite, défaut `Enabled`**, et câblé `Enabled` depuis `main.bicep`
(le durcissement par private endpoints est une tâche **P1**). Le `what-if` prouve que c'est un
**no-op non destructif** (le storage passe de `modify` à `no change`).

> ⚠️ **Flags policy-enforced — ne pas « corriger ».** `allowSharedKeyAccess: false` et
> `allowBlobPublicAccess: false` sont **imposés au niveau org** par des Azure Policy
> (`StorageAccount_DisableLocalAuth_Modify`, `StorageAccount_BlobAnonymousAccess_Modify`). Le
> `what-if` peut les afficher en `modify` : c'est attendu et **aucune** policy n'impose
> `publicNetworkAccess`. L'accès au blob se fait via **identité managée** (RBAC `Storage Blob Data
> Owner`), pas par clé partagée.

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

## Statut réel d'exécution (session Phase 0) + résiduels stricts

Cette section consigne ce qui a été **réellement exécuté** durant la session (au-delà de la
documentation), et le **résiduel strict** qui nécessite une action hors périmètre repo.

### Ce qui est effectivement configuré

- **T0.1 — OIDC : ✅ COMPLET.** App `microlingo-github-actions` (`appId 4bfc43dc-…`) + SP +
  3 secrets repo déjà en place ; 3 federated credentials `github-env-dev/staging/prod` ajoutées.
- **T0.3 — Environments : ✅ PARTIEL.** `dev` / `staging` / `prod` créés. **Reviewer gate `prod`
  non posé** (billing GitHub 422, voir §T0.3). Branch protection `main` = résiduel admin.
- **T0.2 — Runner : ✅ prémisse hosted réfutée en live.** Le run `28381092423` a été rejeté
  immédiatement avec l'annotation GitHub :
  "GitHub Actions hosted runners are disabled for this repository. For more information please contact your GitHub Enterprise Administrator."
  ⇒ **GitHub-hosted bloqué par policy EMU**. Le chemin critique reste self-hosted (`law-microlingo`).

### Ce qui est effectivement déployé

- **T0.4 — Infra `dev` : ✅ DÉPLOYÉE (amorçage local réel).** `az deployment sub create` exécuté
  avec succès (Owner sur la souscription). `AUTH_MODE=dev` actif. Ressources avec suffixe
  `a2msquxibzvcu` (Function App `func-microlingo-dev-a2msquxibzvcu`, Cosmos, Key Vault, App
  Insights, Storage). Dérive `publicNetworkAccess` du Storage réconciliée (désormais IaC).

### ⛔ Blocage plateforme Flex — Functions n'indexent jamais (T0.5 / T0.6 bloqués)

Malgré un déploiement de package **réussi** (`az functionapp deployment source config-zip` → 202,
SCM `Success`, sync triggers OK), **aucune des 32 functions de l'app ne s'indexe** :

- `GET /api/health` → **404** (et un `503` transitoire par cold start) ; racine `/` → **200**.
- ARM `admin/functions` ne liste qu'**1** function : le placeholder plateforme `WarmUp`.
- ARM `deploymentStatus/latest` reste figé sur **`RuntimeStarting`** avec
  **0 instance** (`inProgress=0`, `successful=0`, `failed=0`, `errors=null`, `failedInstancesLogs=null`).

**Diagnostic (définitif) :** le cycle de vie Flex est `Build → RuntimeStarting → RuntimeSuccessful`.
Rester sur `RuntimeStarting` avec **0 instance allouée** et **aucune erreur/log d'échec** signifie que
**la plateforme n'a jamais alloué de worker** pour spécialiser notre app. Un défaut de code/package
afficherait `failed > 0` **avec** des logs. `0/0/0` = **défaillance d'allocation/spécialisation côté
plateforme**, pas une erreur applicative.

**Couches explicitement exonérées** (toutes vérifiées non coupables) : package (zip valide, 99
fichiers, ~13 Mo), code, `functionAppConfig` + runtime, app settings (8 clés correctes), identité
managée, **RBAC** (la MI a Storage Blob Data Owner + Storage Queue Data Contributor + Key Vault
Secrets User), blob du package (présent + frais), manifeste, réseau Storage (Enabled + Allow).

**Remédiations tentées sans succès :** redéploiement One Deploy ×4-5 ; **suppression + recréation
complète de la Function App** ; nettoyage de 5 role assignments périmées ; **restart explicite**.
Aucune n'a fait indexer les functions.

> 🔧 **Gotcha recreate-in-place (à connaître).** `functionApp.bicep` nomme ses role assignments
> `guid(scope.id, functionApp.id, roleDefId)`. Après une recréation **au même nom**, le
> `functionApp.id` est **identique** → les noms de role assignments ne changent pas, mais le
> `principalId` de la **nouvelle** identité managée diffère → ARM rejette
> (`RoleAssignmentUpdateNotPermitted`, et `BadRequest` côté Cosmos SQL role). **Correctif qui
> fonctionne :** supprimer les anciennes attributions par leur id au scope, puis relancer le
> déploiement.

### Chemins de déploiement Flex (pièges rencontrés — à retenir)

- **Utiliser `az functionapp deployment source config-zip`** (front-end One Deploy de Flex). Le
  zip-deploy Kudu **brut** échoue (`403 InaccessibleStorageException`) si le Storage est verrouillé.
- **`func` Core Tools cassé sur win-arm64** — l'éviter ; tout piloter via `az` / ARM.
- **SCM basic auth désactivée** (AAD-only). Pour interroger le hostruntime, passer par le proxy ARM
  `…/hostruntime/admin/...` avec un token `az account get-access-token --resource
  https://management.azure.com` (construire l'URI par concaténation : PowerShell mange `?api-version`).
- **EMU bloque `ubuntu-latest`** (cf. ci-dessus) — le CI/CD critique doit cibler self-hosted `law-microlingo`.

### Résiduel strict (hors périmètre repo)

1. **Azure-support** — escalade de la **défaillance de spécialisation Flex** (worker jamais alloué ;
   `RuntimeStarting` 0 instance). C'est le **seul** blocage empêchant T0.5/T0.6. Sans functions
   indexées, impossible de valider auth 200/401 ni le smoke test.
2. **GitHub plan payant** — pour poser le reviewer gate `prod` (limitation billing 422).
3. **Exploitation runner Azure** — maintenir online la VM runner self-hosted pour exécuter le CI sous EMU.

> Dès que les functions s'indexent (post-remédiation plateforme), **T0.5 et T0.6 sont prêts à
> jouer** : voir les commandes en §T0.5 / §T0.6 (host
> `https://func-microlingo-dev-a2msquxibzvcu.azurewebsites.net`).

---

## Hors-scope Phase 0 (P1, sessions ultérieures)

- Industrialiser l'auto-start/auto-heal de la VM runner Azure.
- Vraies valeurs Entra CIAM + déploiements `staging` / `prod`.
- Diagnostics / politiques durcis (déjà conditionnés `env != dev` dans le Bicep).

---

## Tuteur IA — activation du LLM réel (Azure OpenAI / Microsoft Foundry)

Le tuteur IA fonctionne par défaut avec un **moteur déterministe ancré** (repli
`NullTutorCompletion`). Pour activer un **vrai LLM**, on câble `AzureOpenAiTutorCompletion`
derrière `ITutorCompletion` via les app settings `TUTOR_LLM_*`.

### Ressource cible (dev)

- **Type** : Azure OpenAI exposé en **Microsoft Foundry** (surface API **v1**, scopée projet).
- **Déploiement** : `gpt-5.4-mini` (famille **GPT‑5**).
- **Endpoint (base v1, sans `/responses`, slash final requis)** :
  `https://microlingo-openai.services.ai.azure.com/api/projects/microlingo-dev/openai/v1/`
- **Auth** : **clé API désactivée** sur la ressource → **Entra ID / identité managée
  obligatoire**. On laisse `TUTOR_LLM_API_KEY` **vide** : le code passe alors par
  `TokenCredential` (`DefaultAzureCredential`, scope `https://cognitiveservices.azure.com/.default`).

### App settings à poser sur la Function App

| Clé | Valeur (dev) |
| --- | --- |
| `TUTOR_LLM_ENABLED` | `true` |
| `TUTOR_LLM_ENDPOINT` | base v1 ci-dessus (avec slash final) |
| `TUTOR_LLM_API_SURFACE` | `v1` (Foundry) — `classic` pour l'ancien chemin `deployments/.../chat/completions?api-version=` |
| `TUTOR_LLM_DEPLOYMENT` | `gpt-5.4-mini` (envoyé comme champ `model` du corps) |
| `TUTOR_LLM_MAX_OUTPUT_TOKENS` | `400` (mappé sur `max_completion_tokens`) |
| `TUTOR_LLM_API_KEY` | **vide** (⇒ Bearer AAD) |
| `TUTOR_LLM_API_VERSION` | inutilisé en surface `v1` (uniquement requis en `classic`) |

> Surface **v1** : corps `{ model, messages, max_completion_tokens, response_format: { type: "json_object" } }`
> envoyé sur `…/openai/v1/chat/completions` (**sans** `api-version`). La famille GPT‑5 **rejette**
> `temperature ≠ 1` et `max_tokens` → on n'envoie ni l'un ni l'autre. Le parseur de réponse reste
> `choices[0].message.content`.

### ⛔ Prérequis RBAC (bloquant pour l'appel **live**)

L'identité qui exécute l'API (identité managée de la Function App en `dev`/`staging`/`prod`, ou
le principal `az login` en local) doit avoir le rôle **`Cognitive Services OpenAI User`** sur la
ressource `microlingo-openai`. Sans ce rôle, l'appel renvoie **401/403** même si la config est
correcte.

> ✅ **`dev` : rôle accordé.** Le rôle `Cognitive Services OpenAI User` est attribué à l'identité
> managée de `func-microlingo-dev-a2msquxibzvcu` (principal `ec39dfb2-cb12-4279-9830-ce5d95ebce6b`)
> sur `microlingo-openai`. Reste à exécuter **un appel réel de validation** (voir ci-dessous).
> `staging`/`prod` devront recevoir la même attribution lors de leur déploiement.

```bash
# Identité managée de la Function App (system-assigned)
PRINCIPAL_ID=$(az functionapp identity show \
  --name func-microlingo-dev-a2msquxibzvcu --resource-group "$RG" \
  --query principalId -o tsv)

OPENAI_ID=$(az resource show \
  --name microlingo-openai --resource-group "$RG" \
  --resource-type Microsoft.CognitiveServices/accounts --query id -o tsv)

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services OpenAI User" --scope "$OPENAI_ID"
```

> **État actuel (mise à jour).** **RBAC accordé en `dev`** (rôle `Cognitive Services OpenAI User`
> sur `microlingo-openai` pour l'identité managée de `func-microlingo-dev`) et **tuteur activé en
> `dev`** : les app settings `TUTOR_LLM_*` sont décommentés dans `infra/params/dev.bicepparam` et
> déployés par `cd-backend`. Code Foundry v1 / GPT‑5 compilé et **couvert par tests unitaires**
> (Infra + Application verts). **Résiduel : un seul appel réel de validation** (voir §
> « Validation live » ci-dessous) doit renvoyer **200 + une explication LLM authentique** avant de
> basculer le statut du tuteur en 🟢 (cf. `docs/ETAT_DU_PROJET.md` §13).

### Validation live (1 appel réel)

Une fois le déploiement `cd-backend` réussi pour le commit d'activation et l'app de retour à
`200` sur `/api/health`, exécuter **un** appel de bout en bout. En `dev` l'auth est en mode
permissif (`AUTH_MODE=dev`, `DevTokenValidator`) ; on bootstrappe un JWT applicatif via les
endpoints anonymes `auth/register` puis `auth/login`, puis on appelle `tutor/explain` :

```bash
BASE="https://func-microlingo-dev-a2msquxibzvcu.azurewebsites.net/api"

# 1) Santé (doit répondre 200 après le redéploiement)
curl -fsS "$BASE/health"

# 2) Compte de test + JWT applicatif (endpoints anonymes)
curl -fsS -X POST "$BASE/auth/register" -H 'Content-Type: application/json' \
  -d '{"email":"tutor-smoke@example.com","password":"Passw0rd!smoke"}'
TOKEN=$(curl -fsS -X POST "$BASE/auth/login" -H 'Content-Type: application/json' \
  -d '{"email":"tutor-smoke@example.com","password":"Passw0rd!smoke"}' | jq -r '.accessToken')

# 3) Appel tuteur réel — IDs de contenu réels (parcours « ai-transformation-leader »,
#    leçon l-core-d5ed414f, contrôle …-check-1 ; bonne réponse = "a").
RESP=$(curl -fsS -X POST "$BASE/tutor/explain" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"trackId":"ai-transformation-leader","lessonId":"l-core-d5ed414f","itemId":"l-core-d5ed414f-check-1","selected":["a"]}')
echo "$RESP" | jq .
echo "source = $(echo "$RESP" | jq -r '.source')"   # "ai" = vrai LLM ; "grounded" = repli déterministe
```

Critère de réussite : **HTTP 200 ET `source == "ai"`** (le repli déterministe renvoie aussi 200
mais `source == "grounded"`). Un `source:"ai"` confirme le chemin live (LLM Foundry, guardrails
passés) → basculer alors le badge tuteur en 🟢 dans `docs/ETAT_DU_PROJET.md` §13 et ce runbook.
