# Runbook de déploiement — Certigo (Phase 0 : socle de production)

Ce runbook décrit les étapes **humaines** (droits admin Azure AD / GitHub) nécessaires pour
amorcer le **premier déploiement de l'environnement `dev`** et valider l'authentification réelle.

> **Pourquoi ce runbook ?** Le pipeline `.github/workflows/cd-backend.yml` est un pipeline de
> déploiement complet (infra Bicep + code Functions). Le chemin critique est désormais
> **compatible EMU (self-hosted obligatoire)** :
> 1. les jobs critiques backend restent sur le runner Azure `certigo-trusted` ;
> 2. toute source PR reste confinée au runner sans identité `certigo-pr` ;
> 3. l'auth Azure reste via OIDC (`azure/login@v2`) avec permissions minimales.
>
> Les actions humaines restantes concernent surtout la gouvernance (OIDC Azure AD, environments,
> branch protection), pas l'édition des workflows runners.
>
> **Supersession sécurité (août 2026).** Les recettes historiques T0.1 qui créent des
> identités ou attribuent `Owner` ne sont plus autorisées pour Certigo. Pour toute opération
> OIDC/RBAC ou runner, appliquer uniquement
> [`CLOUD_LEAST_PRIVILEGE.md`](./runbooks/CLOUD_LEAST_PRIVILEGE.md); cette PR n'exécute
> aucune mutation live.

---

## Répartition repo vs. actions humaines

| Élément | Statut | Où |
|---|---|---|
| Chemin critique backend self-hosted (`certigo-trusted`) | ✅ Fait | `cd-backend.yml` |
| Jobs rattachés à un `environment:` | ✅ Fait (cette PR) | `cd-backend.yml` |
| Clarification placeholders Entra en dev | ✅ Fait (cette PR) | `infra/params/dev.bicepparam` |
| App registration + federated credentials OIDC | ✅ **Fait (session)** — app `microlingo-github-actions` déjà existante + 3 FC `environment:<env>` ajoutées | §T0.1 |
| Configuration GitHub OIDC | ✅ Opérationnelle aux scopes existants ; ne pas déplacer sans audit | §T0.1 |
| Clé JWT + expiration par Environment | ⛔ **Humain** — obligatoire avant staging/prod | §T0.4 |
| Permissions Graph app-only minimales | ✅ Configurées et consenties ; `User.Read` non configurée/non utilisée, nettoyage séparé | §T0.1 |
| Identité Graph de suppression + audience de preuve | ✅ Secret + 3 variables configurés dans `staging`/`prod` ; Key Vault et app settings automatisés | §T0.1 |
| Fédération Sign in with Apple | ✅ App ID, Service ID, domaine/return URL et `susi_certigo` configurés ; bouton visible | §T0.1 |
| Révocation Apple après suppression | ⛔ **Post-déploiement** — test réel avec compte sacrifiable, puis contrôle de disparition/révocation de l’association | §T0.1 |
| Destinataire `ALERT_EMAIL` par Environment | ✅ Configuré dans `staging`/`prod`, valeur non divulguée et hors dépôt | §T0.4 |
| Réseau privé atomique Storage / Key Vault / Cosmos + peering CI | ✅ IaC + hotfix OneDeploy | `infra/modules/privateNetwork.bicep` |
| GitHub Environments `dev`/`staging`/`prod` | ✅ Créés ; staging/prod limités aux branches protégées et configurés JWT | §T0.3 |
| Branch protection sur `main` | ⛔ **Humain** (admin repo) | §T0.3 |
| Déploiement infra `dev` | ✅ **Fait (session)** — amorçage local réel | §T0.4 |
| Validation auth (200/401) | ⛔ **À rejouer après déploiement privé** | §T0.5 + §Statut réel |
| Smoke test live + ready | ✅ Automatique et bloquant après OneDeploy | `deploy-flex-onedeploy.sh` |
| ZIP/manifest/SBOM de release | ✅ Build unique, hashes revérifiés à chaque environnement | `cd-backend.yml` |
| Rollback applicatif | ✅ Dispatch protégé vers un run `main` antérieur, sans Bicep | §Release récupérable |

### Réactivation contrôlée après l'incident de déploiement

Le workflow `cd-backend` est volontairement dans l'état GitHub
`disabled_manually`. Un merge ou un push sur `main` ne constitue plus une
autorisation de déploiement et ne déclenche aucun job de ce workflow.

Conserver cet état jusqu'à ce que toutes les conditions suivantes soient réunies :

1. le correctif fail-closed est fusionné sur `main` et son SHA de merge est relevé ;
2. les checks obligatoires de ce SHA sont verts, notamment actionlint, la politique
   de sécurité des workflows et project-state ;
3. une rerevue indépendante confirme que `cd-backend.yml` n'expose que
   `repository_dispatch: promote-backend`, que le payload est strict et que tous les
   jobs Azure dépendent du gate et d'un GitHub Environment ;
4. les protections et reviewers des Environments `dev`, `staging` et `prod` sont
   audités sans les modifier depuis le pipeline ;
5. un opérateur habilité consigne un **GO explicite** puis réactive uniquement
   `cd-backend` depuis l'interface GitHub Actions.

La réactivation ne doit être effectuée ni par cette PR, ni par un workflow, ni
avant le GO. Elle ne lance aucun déploiement à elle seule : une seconde action
opérateur, le dispatch strict décrit ci-dessous, reste obligatoire.

### Check-list d'exploitation (utilisateur non-admin)

1. Après la réactivation contrôlée, choisir un run `ci-backend` réussi, issu d'un
   push `main`, dont le commit est celui à livrer.
2. Pour `dev`, envoyer `promote-backend` avec exactement
   `operation=release`, `environment=dev` et le `source_run_id` du run CI choisi.
   Tout champ absent, supplémentaire ou mal typé est rejeté avant l'accès Azure.
3. Après succès, noter l'identifiant du run `cd-backend` de release. Pour
   `staging` puis `prod`, envoyer séparément `promote-backend` avec
   `operation=promotion`, l'environnement cible et cet identifiant de release.
4. Vérifier que les jobs `deploy-infra` puis `deploy-backend` démarrent sur un runner portant `certigo-trusted`.
5. En cas d'échec Azure login, contrôler la présence de `AZURE_CLIENT_ID`,
   `AZURE_TENANT_ID` et `AZURE_SUBSCRIPTION_ID` dans leurs scopes GitHub
   opérationnels actuels. Ne pas les recréer ou les déplacer sans preuve du scope
   effectivement consommé.
6. En cas d'échec du prévol JWT staging/prod, contrôler la paire Environment
   `AUTH_JWT_SIGNING_KEY` / `AUTH_JWT_SIGNING_KEY_EXPIRES_ON`, sans afficher sa valeur.
7. En cas d'échec du prévol de suppression de compte, contrôler le jeu complet
   du secret `ENTRA_GRAPH_CLIENT_SECRET` et des variables
   `ENTRA_GRAPH_TENANT_ID`, `ENTRA_GRAPH_CLIENT_ID` et
   `ENTRA_REAUTH_AUDIENCE`. Ne jamais afficher le secret.
8. Contrôler que la variable non secrète `ALERT_EMAIL` de chaque Environment
   `staging`/`prod` désigne une boîte réellement supervisée ; aucune valeur par
   défaut n'est committée.
9. Pour un rollback, relever le `sourceRunId` de `previous` dans l'état de
   déploiement et utiliser `promote-backend` avec `operation=rollback`. Le chemin
   rollback refuse tout autre artefact et ne redéploie pas Bicep.

### Release récupérable

Le workflow sépare strictement l'autorisation, la construction et la promotion :

1. un push `main` exécute uniquement la CI locale et ne déclenche pas `cd-backend` ;
2. un dispatch `promote-backend` `release:dev` sélectionne un run `ci-backend`
   réussi de `main`, construit exactement son commit puis retient le bundle sous
   l'identifiant du run `cd-backend` explicite ;
3. le bundle contient `publish.zip`, `release-manifest.json` et le SBOM CycloneDX ;
4. le manifeste lie le commit, le run de release et les SHA-256 du ZIP et du SBOM ;
5. `dev`, `staging` et `prod` téléchargent et revérifient le même artefact ;
   `prod` exige qu'il soit déjà le `current` sain de staging ;
6. OneDeploy conserve le ZIP immuable sous `deployments/<commit>.zip` et ne met à
   jour `state/backend-release.json` qu'après succès de `health/live` et
   `health/ready`.

Le bundle source est conservé 90 jours sous
`app-package/releases/<source_run_id>/` dans le Storage privé `dev`, via OIDC et
sans dépendance au quota GitHub Actions Artifact. La politique Storage conserve
les packages déployés 30 jours ; le pointeur minuscule
`state/backend-release.json`, non soumis à cette expiration, référence `current`
et `previous`. Le SHA-256 du ZIP publié dans les logs immuables du job source est
comparé au manifeste et aux octets téléchargés ; la promotion échoue fermée si
les logs ou le bundle ne sont plus disponibles. Pour une récupération opérateur :

```bash
# Utiliser exclusivement le sourceRunId du champ previous de l'environnement.
PREVIOUS_RUN_ID="<state/backend-release.json.previous.sourceRunId>"
printf '%s' \
  "{\"event_type\":\"promote-backend\",\"client_payload\":{\"environment\":\"prod\",\"operation\":\"rollback\",\"source_run_id\":\"$PREVIOUS_RUN_ID\"}}" |
  gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input -
```

Le rollback reste soumis à l'environnement GitHub ciblé, réutilise OIDC et les
secrets isolés de cet environnement, exige le commit, le hash et le run source
enregistrés dans `previous`, puis exécute les deux smoke tests. En cas d'échec, le
pointeur `current` n'est pas modifié et le workflow échoue fermé.

### Alertes opérables

Staging et production utilisent l'Action Group email existant. Les règles sont
limitées aux signaux qu'une personne seule peut traiter :

- disponibilité et dépendances : un test standard toutes les 5 minutes sur
  `/api/health/ready`, depuis deux emplacements ; l'alerte exige l'échec des deux ;
- readiness/Cosmos : la règle Log Analytics existante garde le détail du retour
  non-200 (Cosmos, Storage ou Key Vault) ;
- stabilité : la règle 5xx existante alerte sur un pic de réponses serveur ;
- déploiement : une Activity Log Alert gratuite couvre les échecs ARM et
  OneDeploy dans le resource group de l'environnement.

Les alertes 5xx/readiness déjà présentes ne sont pas dupliquées. Aucun rôle Azure
supplémentaire ni changement DNS n'est requis.

Le destinataire vient exclusivement de la variable non secrète `ALERT_EMAIL` du
GitHub Environment ciblé (`staging` ou `prod`). Le workflow refuse une valeur vide,
avec caractères de contrôle ou hors d'un format email raisonnable, puis l'injecte
dans le fichier de paramètres Bicep temporaire protégé. Ne versionner aucune adresse
personnelle. La configuration DNS et les nameservers ne font pas partie de ce flux.

#### Test post-déploiement du routage d'alerte

Après fusion de cette PR et premier déploiement réussi de chaque environnement,
envoyer une notification de test Azure Monitor à l'Action Group existant. Cette
commande n'affiche ni ne demande l'adresse configurée et ne provoque pas d'échec
applicatif ou de déploiement :

```bash
ENVIRONMENT=staging # puis prod après validation staging
az monitor action-group test-notifications create \
  --resource-group "rg-certigo-$ENVIRONMENT" \
  --action-group-name ag-certigo-security \
  --alert-type webtestalert \
  --output none
```

Confirmer hors des logs que la boîte supervisée reçoit la notification de test. Si
Azure demande la validation initiale du destinataire, terminer la vérification OTP
depuis cette boîte puis relancer le test. Ne jamais déclencher volontairement une
erreur ARM/OneDeploy en production pour tester l'Activity Log Alert. Procédure Azure
officielle : [tester un Action Group](https://learn.microsoft.com/azure/azure-monitor/alerts/action-groups#test-an-action-group-in-the-azure-portal).

La publication GitHub Pages des pages légales (politique de confidentialité
`/privacy-policy/` et demande de suppression `/account-deletion/`) est
fail-closed. Le GitHub Environment `github-pages` doit fournir une
`PUBLIC_WEB_ORIGIN` HTTPS canonique et `PUBLIC_DOMAIN_VERIFIED=true`; sinon le
builder échoue avant la création de l'artefact. Ne déclencher le dispatch
qu'après avoir suivi [`PUBLIC_DOMAIN_MIGRATION.md`](./PUBLIC_DOMAIN_MIGRATION.md) :

```bash
gh api --method POST "repos/$GH_ORG/$GH_REPO/dispatches" \
  -f event_type=publish-verified-public-pages
```

Le dispatch historique `deploy-privacy-policy` reste neutralisé et ne doit pas
être utilisé comme chemin d'activation.

Staging et production reçoivent en plus
`APPLE_CIAM_DOMAIN_RECONFIGURED=true` depuis leur GitHub Environment avant toute
opération de déploiement ou rollback. L'Environment `beta` et le groupe
Codemagic `certigo_mobile_config` fournissent le même triplet avant toute release
mobile. Les fichiers de paramètres versionnés conservent les valeurs
vides/fausses.

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
et la disponibilité du runner self-hosted online avec le label `certigo-trusted`.

### Réconciliation des labels runners

Les deux runners existants (`vm-certigo-runner`) portent les labels
custom mutuellement exclusif **`certigo-pr`** ou **`certigo-trusted`**, en plus
des labels système
(`self-hosted`, `Linux`, `X64`).  
Le label a été ajouté via l'API GitHub :
`POST /repos/{owner}/{repo}/actions/runners/{id}/labels`.

Conséquence : les workflows critiques `main` ciblent `certigo-trusted` et les workflows PR
ciblent `certigo-pr`, ce qui isole la confiance sans éditer les YAML à chaque
ajustement.

### Sélection immuable des runners

Les workflows Linux ciblent directement les labels
`[self-hosted, Linux, X64, certigo-trusted]`. Aucune variable de sélection ni aucun fallback
hébergé n'est accepté : la résilience repose exclusivement sur plusieurs runners Azure
portant le même jeu de labels.

### Politique scans lourds (CodeQL / security-scan)

`codeql.yml` et `security-gate.yml` exécutent les analyses pertinentes sur les PR
internes et les push `main`, avec sélection par chemins, puis un scan complet
planifié. Ils n'exposent aucun déclenchement manuel privilégié.

### Risque / rollback (chemin critique EMU)

- **Risque principal** : runner `certigo-trusted` indisponible pour déploiements/gates.
- **Rollback repo** : restaurer le dernier YAML validé sans modifier les labels de sécurité.
- **Rollback opérationnel** : démarrer/maintenir online la VM runner Azure (ou activer un auto-start), puis redéclencher le workflow.

---

## Variables communes

```bash
GH_ORG="gchambaud_microsoft"
GH_REPO="Certigo"
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
> SP objectId `15d2b34a-c0a0-4b5d-8360-b895a8164706`). La configuration
> `AZURE_CLIENT_ID` / `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` est déjà
> opérationnelle aux scopes GitHub existants, et
> les 3 federated credentials `github-env-dev` / `github-env-staging` / `github-env-prod`
> (sujet `repo:…:environment:<env>`) ont été **ajoutées cette session**. Les valeurs
> `AZURE_*` sont déjà consommées par les déploiements ; leur scope ne doit pas être
> recréé ou déplacé sans audit. Les commandes ci-dessous
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

Comme tous les jobs Azure portent `environment: <env>`, le **sujet** du token OIDC émis par GitHub
devient `repo:<org>/<repo>:environment:<env>`. On crée donc **une federated credential par
environnement** (dev/staging/prod). Aucune fédération OIDC de branche pour un simple push `main`
n'est requise ni autorisée par `cd-backend`.

### Secret de signature JWT par environnement

Créer `AUTH_JWT_SIGNING_KEY` comme **secret d'environnement** dans `staging` et
`prod`, avec une valeur aléatoire durable et différente par environnement. Ne pas
le créer au niveau dépôt et ne pas le passer depuis le workflow appelant :
`cd-backend.yml` le lit après l'entrée dans l'environnement protégé. `dev` n'exige
pas ce secret et conserve sa dérivation non-production déterministe.

Le workflow compile d'abord le `.bicepparam`, fusionne la valeur dans un unique
fichier ARM temporaire en permissions `0600`, ne place jamais la valeur dans les
arguments `az` ou les logs, puis supprime les fichiers temporaires à la fin du
déploiement.

Ordre de mise en service inter-branches :

1. déployer d'abord la version de `cd-backend.yml` qui injecte le paramètre sécurisé ;
2. créer les secrets d'environnement `staging` et `prod` ;
3. fusionner puis déployer le durcissement Bicep qui rend
   `authJwtSigningKey` obligatoire hors `dev`.

Cet ordre est compatible avec le template actuel, où le paramètre existe déjà mais
reste facultatif, et avec le template durci de la PR #263.

### Identité Graph de suppression de compte

Le client confidentiel Graph dédié est créé. Les permissions d’application
Microsoft Graph minimales `User.RevokeSessions.All` et `User.ReadWrite.All`
sont consenties par un administrateur. `User.Read`, visible uniquement sous
« Autres autorisations accordées », n’est ni configurée ni utilisée par Certigo ;
son nettoyage est une tâche distincte.

Les GitHub Environments `staging` et `prod` contiennent :

- le **secret GitHub Environment** `ENTRA_GRAPH_CLIENT_SECRET` ;
- `ENTRA_GRAPH_TENANT_ID` : Directory/Tenant ID du tenant External ID ;
- `ENTRA_GRAPH_CLIENT_ID` : Application/Client ID du client Graph dédié ;
- `ENTRA_REAUTH_AUDIENCE` : client ID de l’application mobile qui reçoit l’ID
  token OIDC de ré-authentification.

`cd-backend.yml` lit ces valeurs uniquement après l’entrée dans le GitHub
Environment ciblé, les valide avec les autres paramètres de déploiement, puis les
écrit dans le fichier ARM temporaire `0600`. Le secret reste un paramètre Bicep
`@secure`; `keyvaultGraphClientSecret.bicep` crée ou rotationne sa version dans
le Key Vault Certigo et retourne son URI versionnée. `functionApp.bicep`
maintient les quatre app settings, dont
`ENTRA_GRAPH_CLIENT_SECRET_SECRET_URI`, à chaque déploiement. Aucune commande
`az keyvault secret set`, `az functionapp config appsettings set` ni saisie
portail post-déploiement n’est nécessaire.

En `dev`, le writer ignore explicitement ces entrées, le module Key Vault n’est
pas déployé et l’identité externe reste indisponible plutôt qu’émulée avec une
identité réelle.

### Sign in with Apple

La configuration externe est accomplie : Sign in with Apple est activé sur
l’App ID mobile, le Service ID Certigo CIAM est associé au domaine et à la
return URL, Apple est activé dans `susi_certigo` et le bouton est visible.

Après le déploiement de cette PR, la seule validation Apple restante consiste à
utiliser un compte sacrifiable pour un parcours réel connexion → suppression,
puis à vérifier la disparition ou la révocation de l’association Apple.

### Gate de suppression de compte

`ACCOUNT_DELETION_ENABLED` reste `false` par défaut. Avant toute activation,
le gate historique sur `certigo-trusted` reste retiré de `.github/workflows/`.
Activer séparément le workflow one-shot décrit dans
`docs/runbooks/COSMOS_EMULATOR_RUNNER.md`, puis exécuter un unique
`workflow_dispatch` depuis `main` sur une VM jetable sans identité managée et
portant seulement le label `certigo-cosmos-emulator`. La variable
`CERTIGO_COSMOS_EMULATOR_ENABLED` reste `false` hors de cette fenêtre. Un test
skippé, absent, non unique ou non réussi ne permet jamais d’activer la feature.

### Gate Person / LinkedIdentity

`PERSON_LINKED_IDENTITY_V1` est explicitement `off` dans `dev`, `staging` et
`prod`. Le runtime courant n'accepte que `off|shadow`. `shadow` conserve le
`userId` legacy comme autorité et ajoute uniquement des overlays/mirrors
idempotents ; il n'active aucun endpoint ni UI de liaison. Toute activation
requiert d'abord le gate backend/Cosmos de la PR runtime puis une décision
opérationnelle séparée. Les valeurs futures `resolve` et `link` échouent au
démarrage dans cette version.

### Prévol read-only

```bash
export AZURE_SUBSCRIPTION_ID="<SUBSCRIPTION_ID>"
bash infra/governance/inventory.sh > inventory.json
bash infra/governance/what-if-phase-a.sh
# Après deployment Phase A approuvé et réussi :
PHASE_A_DEPLOYMENT_NAME='<deployment-phase-a>' \
  bash infra/governance/what-if-phase-b.sh
```

Toute création d'identité/rôle/policy et toute modification de GitHub Environment sont des
actions humaines PIM hors de cette PR.

---

## T0.2 — Débloquer le runner (déjà fait côté repo) + amorçage

**Côté repo :**
- les jobs critiques de `cd-backend.yml` (`deploy-infra`, `deploy-backend`) ciblent
  `[self-hosted, Linux, X64, certigo-trusted]` ;
- `ci-backend.yml` cible le même pool Azure pour `main` et les PR internes ;
- le chemin critique reste compatible avec la contrainte EMU (self-hosted obligatoire).

### Isolement des dépendances runner

Le blocage ne vient pas du YAML mais de la disponibilité runner : sous EMU, l'exécution critique
reste self-hosted. La durabilité non-admin passe donc par l'exploitation Azure de la VM runner
(`rg-certigo-ci`, tenant Microsoft Non-Production), pas par une migration vers hosted.

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
GitHub payant compatible. Conséquence cette session : les environnements
`dev` / `staging` / `prod` ont bien été **créés**, mais le **gate reviewer sur `prod` n'a pas pu
être posé**. Résiduel admin : passer le repo sous un plan payant (ou le déplacer sous une org
éligible), puis ré-exécuter le bloc `prod` ci-dessus. Les restrictions de branche
sur `staging` et `prod` sont, elles, actives et doivent rester inchangées.

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

**Acteur : humain (ou amorçage local).** L'infra crée : RG `rg-certigo-dev`, Application
Insights, Cosmos DB, Storage, Key Vault, Function App (sans diagnostics durcis en dev).

### Étape 1 — What-if (lecture seule, recommandé d'abord)

```bash
az deployment sub what-if \
  --name certigo-dev \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam
```

### Étape 2 — Déploiement réel

**Option A — amorçage manuel local** (contourne le runner/EMU pour le 1er déploiement) :

```bash
az deployment sub create \
  --name certigo-dev \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam \
  --query 'properties.outputs.functionAppName.value' -o tsv
```

### Clé de signature JWT en staging/prod

`infra/main.bicep` autorise le mécanisme déterministe uniquement en `dev`. Pour
`staging` et `prod`, le déploiement échoue si `authJwtSigningKey` n'est pas fourni
via un paramètre sécurisé externe. L'expiration `authJwtSigningKeyExpiresOn` est un
timestamp ISO 8601 absolu obligatoire. Elle n'est jamais calculée avec `utcNow()` :
un redéploiement identique ne prolonge donc pas silencieusement la durée de vie du
secret.

Conserver dans chaque GitHub Environment `staging`/`prod` :

- le secret `AUTH_JWT_SIGNING_KEY` ;
- la variable non secrète `AUTH_JWT_SIGNING_KEY_EXPIRES_ON` ;
- le secret et les trois variables de l’identité Graph décrits en §T0.1, déjà
  configurés ;
- la variable non secrète `ALERT_EMAIL`, pointant vers une boîte réellement
  supervisée et capable de recevoir du courrier.

Ne jamais placer la clé dans un fichier `.bicepparam` versionné, une sortie de
commande ou les logs du pipeline. Le workflow refuse une clé sans expiration (et
inversement). Le secret Key Vault reçoit aussi un `contentType` explicite et une URI
épinglée sur sa version, afin que la Function App recharge immédiatement une
rotation au lieu d'attendre le cache d'une référence versionless.

Le déploiement transmet uniquement cette URI versionnée à la Function App. Le
worker Flex Consumption lit ensuite la valeur via son identité managée et le point
de terminaison privé Key Vault; la clé elle-même n'est jamais stockée dans les app
settings.

Le CD compile d'abord le `.bicepparam` sans secret, injecte les valeurs en mémoire
dans un JSON temporaire créé avec le mode `0600`, puis transmet uniquement
`@<chemin-du-fichier>` à Azure CLI. Un `trap` supprime les deux fichiers temporaires
à la sortie. Les valeurs JWT n'apparaissent donc jamais dans les arguments de
processus.

#### Rotation sans interruption

Les refresh tokens locaux vivent 90 jours. Une rotation est donc un chevauchement
explicite de deux clés, jamais un remplacement monoclè :

1. Déployer une première fois cette version du backend sans changer la clé active,
   pour activer la validation de la clé précédente.
2. Dans le même GitHub Environment, copier la clé active actuelle vers le secret
   `AUTH_JWT_PREVIOUS_SIGNING_KEY` et définir
   `AUTH_JWT_PREVIOUS_SIGNING_KEY_EXPIRES_ON` à au moins 90 jours et 2 minutes après
   le début de la rotation.
3. Remplacer `AUTH_JWT_SIGNING_KEY` par une nouvelle valeur aléatoire forte et
   fixer une nouvelle expiration absolue dans `AUTH_JWT_SIGNING_KEY_EXPIRES_ON`.
   Le prévol refuse une clé précédente identique à la nouvelle clé active.
4. Exécuter le CD puis vérifier login, refresh et `/health/ready`. Les nouveaux
   jetons sont signés uniquement par la nouvelle clé ; les jetons non expirés de
   l'ancienne clé restent acceptés pendant le chevauchement.
5. Après la fenêtre de 90 jours et 2 minutes, supprimer les deux configurations
   `AUTH_JWT_PREVIOUS_*` et redéployer. L'ancienne version Key Vault reste soumise à
   son expiration et à la rétention du coffre.

Ne jamais avancer uniquement l'expiration avec la même valeur : toute nouvelle
expiration doit correspondre à une rotation de clé approuvée. Si l'expiration
approche sans fenêtre de rotation disponible, suspendre le déploiement et planifier
le chevauchement ; ne pas générer une date glissante.

Déployer l'infrastructure avant le backend qui persiste les examens : le conteneur
Cosmos `attempts` doit d'abord être configuré avec `defaultTtl: -1` pour que le TTL
par examen soit actif sans expirer les tentatives existantes.

**Option B — via le pipeline** (une fois T0.1 + T0.3 prêts) :

```bash
# Après réactivation contrôlée et GO explicite : release dev depuis un run CI main réussi.
SOURCE_CI_RUN_ID="<run ci-backend push main réussi du commit à livrer>"
printf '%s' \
  "{\"event_type\":\"promote-backend\",\"client_payload\":{\"environment\":\"dev\",\"operation\":\"release\",\"source_run_id\":\"$SOURCE_CI_RUN_ID\"}}" |
  gh api --method POST "repos/$GH_ORG/$GH_REPO/dispatches" --input -

# Après succès dev, utiliser l'identifiant du run cd-backend explicite.
RELEASE_RUN_ID="<run cd-backend release dev réussi>"
printf '%s' \
  "{\"event_type\":\"promote-backend\",\"client_payload\":{\"environment\":\"staging\",\"operation\":\"promotion\",\"source_run_id\":\"$RELEASE_RUN_ID\"}}" |
  gh api --method POST "repos/$GH_ORG/$GH_REPO/dispatches" --input -
```

> Le job `deploy-infra` capture les outputs Azure. `deploy-backend` télécharge
> l'artefact retenu, revérifie son manifeste, lance OneDeploy puis les probes live/ready.

### Cohérence des paramètres `dev`

- `env='dev'`, `location='westeurope'`, `appName='certigo'`.
- `cosmosLocation='northeurope'` (westeurope a des limites de capacité AZ).
- `entraAuthority` / `entraAudience` = **placeholders** : **OK en dev** car `authMode='dev'`
  ⇒ `DevTokenValidator` (Entra non appliqué). Renseigner les vraies valeurs pour staging/prod.

### Storage FC1 et posture réseau

La posture est privée et sans commutateur partiel :

- VNet `/24` propre à chaque environnement ;
- subnet FC1 `/26` `snet-functions`, exclusivement délégué à
  `Microsoft.App/environments` ;
- subnet `/26` `snet-private-endpoints`, distinct, avec les network policies de private endpoint
  désactivées ;
- private endpoints Storage `blob`, `queue`, `table`, Key Vault `vault` et Cosmos DB for NoSQL
  `Sql` ;
- zones `privatelink.blob.core.windows.net`, `privatelink.queue.core.windows.net`,
  `privatelink.table.core.windows.net`, `privatelink.vaultcore.azure.net` et
  `privatelink.documents.azure.com`, toutes liées au VNet ;
- `publicNetworkAccess='Disabled'` sur Storage, Key Vault et Cosmos.

Le plan Flex Consumption exige un subnet d'intégration d'au moins `/27`, délégué à
`Microsoft.App/environments`, inutilisable par les private endpoints et situé dans la même région
que l'application. Certigo utilise `/26` pour conserver de la capacité. Voir la documentation
Microsoft [Create and manage function apps in the Flex Consumption
plan](https://learn.microsoft.com/azure/azure-functions/flex-consumption-how-to#configure-virtual-network-integration).
Les noms de zones et groupIds suivent la table officielle [Azure Private Endpoint private DNS zone
values](https://learn.microsoft.com/azure/private-link/private-endpoint-dns).

Le package FC1 et `AzureWebJobsStorage` utilisent une identité managée **utilisateur** créée avant
la Function App. Ses rôles Blob Owner/Contributor, Queue Contributor et Table Contributor sont
provisionnés avant l'application. Le module `functionApp` dépend en plus du déploiement imbriqué
`privateNetwork` complet : les private endpoints, zone groups et liens DNS sont donc terminés avant
la validation du deployment storage FC1. `virtualNetworkSubnetId` pointe vers `snet-functions`.
`vnetRouteAllEnabled=false` est volontaire : les endpoints privés résolvent vers les adresses
RFC1918 `10.60/61/62.*` et empruntent l'intégration VNet, tandis que les dépendances publiques
(Entra, Application Insights, ACS et Azure OpenAI) conservent l'egress plateforme. Microsoft
précise que, pour Flex Consumption, Route All n'est pas requis ; il ne doit être activé qu'avec un
egress explicite (NAT Gateway ou firewall). Voir [Azure Functions networking
options](https://learn.microsoft.com/azure/azure-functions/functions-networking-options?tabs=azure-portal#regional-virtual-network-integration).
Cette séquence suit les modèles de [secured deployments Azure
Functions](https://learn.microsoft.com/azure/azure-functions/functions-infrastructure-as-code?tabs=bicep&pivots=flex-consumption-plan#secured-deployments).

> ⚠️ **Flags policy-enforced — ne pas contourner.** `publicNetworkAccess: Disabled`,
> `allowSharedKeyAccess: false` et
> `allowBlobPublicAccess: false` sont **imposés au niveau org** par des Azure Policy
> (`StorageAccount_PublicNetwork_Modify`, `StorageAccount_DisableLocalAuth_Modify`,
> `StorageAccount_BlobAnonymousAccess_Modify`). L'accès se fait via private endpoint, identité
> managée et RBAC, jamais par clé partagée ni exception publique.

---

## T0.5 — Valider l'authentification (Entra External ID)

`Program.cs:61` enregistre un `CompositeTokenValidator` :
`LocalJwtTokenValidator` (toujours) → puis `DevTokenValidator` (si `AUTH_MODE=dev`) **ou**
`EntraTokenValidator` (si `ENTRA_AUTHORITY` + `ENTRA_AUDIENCE` fournis). Garde-fou :
`AUTH_MODE=dev` est interdit en Production sauf `AUTH_ALLOW_DEV=true`.

Le middleware `JwtAuthMiddleware` exige `Authorization: Bearer …` **sauf** sur
`/api/health`, `/api/health/live`, `/api/health/ready`, `/api/auth/register`,
`/api/auth/login`, `/api/auth/refresh`.

### Chemin 1 — Login local JWT (auto-suffisant, sans Entra) — recommandé pour valider `dev`

```bash
APP_HOST="https://<functionAppName>.azurewebsites.net"

# 1) S'enregistrer (anonyme)
curl -s -X POST "$APP_HOST/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke@certigo.test","password":"P@ssw0rd!"}'

# 2) Se connecter (anonyme) → récupérer le JWT
TOKEN=$(curl -s -X POST "$APP_HOST/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"smoke@certigo.test","password":"P@ssw0rd!"}' | jq -r '.accessToken')

# 3) Sans token → 401
curl -s -o /dev/null -w "sans token: %{http_code}\n" "$APP_HOST/api/catalog/tracks"

# 4) Avec token → 200
curl -s -o /dev/null -w "avec token: %{http_code}\n" \
  "$APP_HOST/api/catalog/tracks" -H "Authorization: Bearer $TOKEN"
```

> Adapter le nom du champ token (`accessToken`) au contrat réel d'`AuthFunctions` si nécessaire.

### Chemin 2 — Entra External ID (CIAM réel) — pour staging/prod

Nécessite un environnement avec `authMode='prod'` et de **vraies** valeurs
`ENTRA_AUTHORITY` / `ENTRA_AUDIENCE`, puis un token obtenu du tenant CIAM Certigo. En `dev`,
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
  configuration `AZURE_*` opérationnelle ; 3 federated credentials
  `github-env-dev/staging/prod` ajoutées.
- **T0.3 — Environments : ✅ PARTIEL.** `dev` / `staging` / `prod` créés ;
  `staging`/`prod` limités aux branches protégées. **Reviewer gate `prod` non
  posé** (billing GitHub 422, voir §T0.3). `ALERT_EMAIL` est configuré dans
  `staging` et `prod` sans valeur divulguée. Branch protection `main` = résiduel admin.
- **T0.2 — Runner : ✅ prémisse hosted réfutée en live.** Le run `28381092423` a été rejeté
  immédiatement car les runners GitHub-hosted sont désactivés pour ce dépôt.
  Aucune validation Enterprise ne sera sollicitée : le chemin critique reste le pool Azure
  self-hosted (`certigo-trusted`).

### État live avant cette modification

Le VNet applicatif, les private endpoints et les zones DNS privées sont déployés. Le chemin
`config-zip` reste néanmoins bloqué : Kudu reçoit le zip local puis tente de le transférer vers le
conteneur de déploiement protégé, mais le service de plateforme n'a pas le chemin réseau nécessaire.
Le contrôle `StorageAccessibleCheck` renvoie donc `403` même si l'identité FC1 peut lire le
conteneur depuis le VNet applicatif.

Le hotfix ne réactive aucun accès public. Il relie `vnet-certigo-ci` (`10.42.0.0/16`) au VNet de
chaque environnement dans les deux sens. Un seul jeu de cinq zones DNS privées, détenu par le hub
`rg-certigo-ci`, est lié au VNet CI et à chaque VNet applicatif. Le runner de confiance écrit le
package par le chemin Blob privé. **Cette PR ne déploie aucune ressource Azure.**

### Migration DNS privée unique (première application par environnement)

Les cinq zones actuellement déployées dans chacun de `rg-certigo-dev`,
`rg-certigo-staging` et `rg-certigo-prod` ne peuvent pas coexister avec les
mêmes namespaces dans `rg-certigo-ci` lorsqu'elles sont liées au VNet de
l'environnement. Cette migration se fait séparément, juste avant la première
application de chaque environnement, avec une courte interruption DNS privée.

1. Faire approuver la fenêtre de changement, conserver le résultat du `what-if` et suspendre les
   déploiements backend.
2. Dans le groupe de l'environnement, lister puis supprimer l'unique zone group
   de chacun des cinq private endpoints (`blob`, `queue`, `table`, `vault`,
   `Sql`), quel que soit son nom, puis supprimer uniquement les cinq zones
   correspondantes. Ne supprimer ni private endpoint, ni VNet, ni la zone
   OpenAI de dev.
3. Appliquer immédiatement `infra/main.bicep` pour cet environnement. Le
   module adopte les VNets, subnets et private endpoints live, crée ou réutilise
   les zones dans `rg-certigo-ci`, puis rattache les liens et zone groups.
4. Vérifier la résolution privée depuis le runner et l'application, les cinq
   liens CI, les cinq liens applicatifs et les cinq connexions privées avant de
   passer à l'environnement suivant. Ne jamais supprimer la zone Vault
   préexistante du hub ni son lien `vnet-certigo-ci-kv-dnslink`.

Avant toute application, exécuter le `what-if` et vérifier que l'ordre ARM est :

1. Storage / Key Vault / Cosmos avec accès public désactivé ;
2. jeu unique de cinq zones privées et liens CI dans `rg-certigo-ci` ;
3. VNet, subnets, private endpoints, zone groups, peerings applicatif ↔ CI et liens DNS applicatifs ;
4. rôles data-plane de l'identité utilisateur, Blob Data Contributor du principal OIDC CI limité au
   conteneur `app-package`, et Storage Blob Delegator limité au compte ;
5. Function App FC1 avec intégration VNet privée et egress public plateforme ;
6. seulement après succès du job infra, publication URL-based du zip.

### Chemins de déploiement Flex (pièges rencontrés — à retenir)

- **Ne pas utiliser `config-zip`** avec le conteneur de déploiement privé : Kudu échoue au
  `StorageAccessibleCheck` avant OneDeploy.
- Le runner `certigo-trusted` charge `deployments/<commit-sha>.zip` avec
  `az storage blob upload --auth-mode login --overwrite false`. Le principal OIDC
  `15d2b34a-c0a0-4b5d-8360-b895a8164706` reçoit `Storage Blob Data Contributor` uniquement sur le
  conteneur `app-package` et `Storage Blob Delegator` sur le compte, nécessaire à la clé de
  délégation utilisateur. Il n'a aucun accès à `lesson-assets` et aucune clé de compte n'est
  autorisée.
- Le runner crée ensuite un SAS **user delegation**, HTTPS, lecture seule, valable 14 minutes,
  masque immédiatement le token et l'URL, puis appelle directement l'extension ARM
  `Microsoft.Web/sites/extensions/onedeploy` avec `packageUri`, `type=zip`, `async=true`,
  `restart=true` et `clean=true`. Le SAS autorise la lecture du blob mais ne contourne pas
  `publicNetworkAccess=Disabled` : OneDeploy doit toujours résoudre et joindre le private endpoint
  via le VNet applicatif.
- `.github/scripts/deploy-flex-onedeploy.sh` refuse toute résolution DNS publique, vérifie
  l'identité utilisateur du deployment storage, obtient un jeton ARM court via Azure CLI et envoie
  le PUT avec `curl`. Le bearer, le SAS, le corps et les réponses restent dans des fichiers
  temporaires mode `0600`, supprimés par `trap`. La réponse asynchrone peut contenir `id: null` :
  seule l'URL `Azure-AsyncOperation` (ou `Location`) de cette requête exacte est acceptée, après
  validation du host `management.azure.com`. Si l'en-tête est absent/invalide, le statut est inconnu,
  l'opération échoue ou le délai est dépassé, le déploiement échoue fermé. Le script exige ensuite
  `/api/health/live` et `/api/health/ready`. Le blob source immuable n'est pas supprimé par le
  script : la policy Storage supprime uniquement `app-package/deployments/` après 30 jours, sans
  supposer que OneDeploy l'a copié.
- La purge protection Key Vault est activée dans tous les environnements, y compris `dev`. Cette
  protection est irréversible ; aucune procédure Certigo ne dépend de la purge d'un vault.
- **`func` Core Tools cassé sur win-arm64** — l'éviter ; tout piloter via `az` / ARM.
- **SCM basic auth désactivée** (AAD-only). Pour interroger le hostruntime, passer par le proxy ARM
  `…/hostruntime/admin/...` avec un token `az account get-access-token --resource
  https://management.azure.com` (construire l'URI par concaténation : PowerShell mange `?api-version`).
- **EMU bloque les runners hébergés** — CI/CD cible `certigo-pr` ou `certigo-trusted` selon la confiance.

### Résiduel strict (hors périmètre repo)

1. **Opérateur Azure** — exécuter la migration DNS environnement par
   environnement ci-dessus, examiner le `what-if` des peerings, liens DNS et
   attributions Blob, puis déployer dans une fenêtre autorisée.
2. **Validation post-déploiement** — confirmer les deux peerings `Connected`, les cinq liens CI et
   cinq liens applicatifs, l'absence d'accès public/clé partagée, puis rejouer auth 200/401 et le
   smoke test. Le workflow traite déjà les deux sondes santé comme des gates bloquants.
3. **GitHub plan payant** — poser le reviewer gate `prod` (limitation billing 422).
4. **Exploitation runner Azure** — maintenir online la VM runner self-hosted sous EMU.

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
  `https://certigo-openai.services.ai.azure.com/api/projects/certigo-dev/openai/v1/`
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
ressource `certigo-openai`. Sans ce rôle, l'appel renvoie **401/403** même si la config est
correcte.

> ✅ **`dev` : rôle accordé.** Le rôle `Cognitive Services OpenAI User` est attribué à l'identité
> managée de `func-certigo-dev-bk3j5ja6vw23s` (principal `ec39dfb2-cb12-4279-9830-ce5d95ebce6b`)
> sur `certigo-openai`. Reste à exécuter **un appel réel de validation** (voir ci-dessous).
> `staging`/`prod` devront recevoir la même attribution lors de leur déploiement.

```bash
# Identité managée de la Function App (system-assigned)
PRINCIPAL_ID=$(az functionapp identity show \
  --name func-certigo-dev-bk3j5ja6vw23s --resource-group "$RG" \
  --query principalId -o tsv)

OPENAI_ID=$(az resource show \
  --name certigo-openai --resource-group "$RG" \
  --resource-type Microsoft.CognitiveServices/accounts --query id -o tsv)

az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal \
  --role "Cognitive Services OpenAI User" --scope "$OPENAI_ID"
```

> **État actuel (mise à jour).** **RBAC accordé en `dev`** (rôle `Cognitive Services OpenAI User`
> sur `certigo-openai` pour l'identité managée de `func-certigo-dev`) et **tuteur activé en
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
BASE="https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api"

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
