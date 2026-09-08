# Actions manuelles P1 — Runbook opérateur consolidé (Certigo)

> **Statut de ce document.** Ceci est un **GUIDE OPÉRATEUR**, pas un livrable exécutable
> par l'agent. Les actions ci-dessous touchent des **surfaces LIVE/OPS** (création de dépôt
> GitHub, provisionnement de runners, déploiements Azure) qui exigent des **identifiants
> vivants** (compte GitHub avec droits admin sur l'organisation, `az login` sur
> l'abonnement de prod). L'agent **ne peut pas** et **ne doit pas** les exécuter : elles sont
> destinées à être jouées **à la main par Gabriel**. Ce fichier est **additif** (docs-only) :
> il n'ajoute ni ne modifie aucun code, aucune infra.
>
> **Source de vérité.** Chaque lot renvoie à sa fiche dans
> [`work-packages.yaml`](./work-packages.yaml) (id / précondition / DoD / rollback). Les noms
> de ressources cités (`rg-certigo-ci`, `certigo-openai`, `rg-certigo-staging`, …) sont ceux
> **déjà publiés sur `main`** dans `infra/` — ils ne sont **pas inventés**. Toute valeur
> secrète ou propre à un tenant (id d'abonnement, GUID de tenant, org GitHub, handles de
> reviewers) reste un **placeholder `<...>`** à remplir au moment de l'exécution.
>
> **Destinataire.** Gabriel (opérateur). **Chaque lot est idempotent** : si la précondition
> révèle que la cible existe déjà et est conforme, le lot est **déjà fait** — ne rien
> réappliquer.

> **Statut vérifié le 2026-09-04** (inventaire Azure/GitHub read-only) :
> - **Lot 1** (`wp-p1-04-certigo-content-repo`) — ✅ **FAIT**. Le dépôt
>   [`gchambaud_microsoft/certigo-content`](https://github.com/gchambaud_microsoft/certigo-content)
>   existe, avec arborescence `content/public`/`content/answerKey`, gouvernance et pipeline CI
>   opérationnels (`work-packages.yaml`/`STATE.md` : `done`). Rien à rejouer.
> - **Lot 2** (`wp-p1-11-ci-spof-runners`) — ⚠️ **encore ouvert, mais partiellement recoupé
>   par `wp-p2-07`** (PR [#250](https://github.com/gchambaud_microsoft/Certigo/pull/250) et
>   [#253](https://github.com/gchambaud_microsoft/Certigo/pull/253), fusionnées) qui a livré le
>   **failover**. Les labels live sont désormais exclusifs, mais le contrôleur reste
>   désactivé, le scale-in CPU est encore présent et une VM deallocated est non classifiée.
> - **Lot 3** (`wp-p1-12-iac-drift-import`) — correction IaC minimale en revue :
>   réseau borné, deux VMSS `existing`, autoscale sans scale-in CPU, OpenAI privé/keyless.
> - **Lot 4** (`wp-p1-13-staging-environment`) — staging existe déjà et est healthy.
>   Le déploiement Bicep subscription `certigo-staging` a réussi le 2026-08-16.
>   Ne jamais recréer ou supprimer ce RG pour rejouer ce runbook.

---

## Résumé — les 4 actions dans l'ordre

| # | Action | Lot | Surface | Durée | Débloque |
| --- | --- | --- | --- | --- | --- |
| 1 | **Créer le dépôt `certigo-content`** (arborescence + gouvernance + séparation public/answerKey) | `wp-p1-04-certigo-content-repo` | GitHub (org) | ~45 min | p1-05, p1-06 → p1-07 → p1-08 |
| 2 | **Résilience CI** : supprimer le SPOF runner (pool Azure ≥2 instances) | `wp-p1-11-ci-spof-runners` | Azure + GitHub Actions | ~2–4 h | Stabilité CI de toute la Phase 1+ |
| 3 | **Réconcilier le drift IaC** : OpenAI + réseau/capacité CI (syntaxe + permissions + what-if) | `wp-p1-12-iac-drift-import` | Azure (lecture seule avant changement approuvé) | ~2–3 h | p1-13 |
| 4 | **Maintenir staging** : pré-prod live, isolée et déjà provisionnée par IaC | `wp-p1-13-staging-environment` | Azure (réconciliation) | ~1 h | Recette pré-prod P1+ |

> **Ordre imposé — `wp-p1-04` est la clé de voûte, à faire EN PREMIER.** Le dépôt
> `certigo-content` conditionne toute la chaîne contenu de la Phase 1 : p1-05 (migration du
> contenu) **et** p1-06 (pipeline `ci-content`) en dépendent directement, et p1-06 débloque à
> son tour p1-07 (manifeste immuable) → p1-08 (cache offline). Tant que le dépôt n'existe pas
> avec sa structure et sa gouvernance, **4 lots restent bloqués**. Les lots 2–4 (ops/live) sont
> indépendants entre eux **sauf** p1-13 qui dépend de p1-12 (le staging s'appuie sur une IaC
> réconciliée) : jouer **3 avant 4**.

**Légende des placeholders.** Remplacer avant exécution — ne jamais committer de valeur réelle :

| Placeholder | Signification |
| --- | --- |
| `<ORG>` | Organisation GitHub hôte (ex. l'org actuelle du dépôt Certigo) |
| `<SME_HANDLE>` / `<EDITOR_HANDLE>` | Handles GitHub du relecteur métier (SME) et de l'éditeur de contenu |
| `<SUBSCRIPTION_ID>` | Id de l'abonnement Azure ciblé |
| `<TENANT_GUID>` | GUID du tenant Entra External ID (CIAM) de staging |
| `<API_CLIENT_ID>` | Application ID URI de l'app registration backend de staging |
| `<...>` | Toute autre valeur propre à l'environnement, à confirmer avant apply |

---

### 1. Créer le dépôt `certigo-content` — clé de voûte (wp-p1-04-certigo-content-repo)

**Objectif (DoD).** Un dépôt **`certigo-content`** dédié, séparé de l'app, existe avec :
arborescence de contenu, `CODEOWNERS`, `README` de contribution, contenu de démonstration
validable, **et** une gouvernance (branch protection + revue SME/Éditeur). Séparation nette
**public** (énoncés, exposés au client) / **answerKey** (corrigés, sensibles).

**Pré-requis.**
- `gh` authentifié avec des droits **admin sur `<ORG>`** (`gh auth status`).
- Décision confirmée : dépôt **privé** (les corrigés `answerKey` ne doivent jamais fuiter).
- Précondition idempotente : `gh repo view <ORG>/certigo-content` — s'il existe **déjà** avec
  la structure ci-dessous, le lot est **fait**, s'arrêter.

**Commandes exactes (copier-coller).**

```bash
# 1. Créer le dépôt (privé — les corrigés answerKey sont sensibles)
gh repo create <ORG>/certigo-content \
  --private \
  --description "Contenu pédagogique Certigo (énoncés publics + corrigés answerKey), séparé de l'app" \
  --clone
cd certigo-content

# 2. Arborescence de contenu — séparation public / answerKey stricte
mkdir -p content/public/questions \
         content/public/exams \
         content/answerKey/solutions \
         schemas \
         .github
touch content/public/.gitkeep content/answerKey/.gitkeep

# 3. Contenu de démonstration minimal (validable par le futur pipeline p1-06)
cat > content/public/questions/demo-0001.json <<'JSON'
{ "id": "demo-0001", "schemaVersion": "v2", "kind": "public",
  "prompt": "Question de démonstration — remplacer par du contenu migré (p1-05).",
  "choices": ["A", "B", "C", "D"] }
JSON
cat > content/answerKey/solutions/demo-0001.json <<'JSON'
{ "id": "demo-0001", "schemaVersion": "v2", "kind": "answerKey",
  "correct": "A", "rationale": "Corrigé de démonstration — NE PAS exposer côté public." }
JSON
```

**Gouvernance — `CODEOWNERS` (revue SME/Éditeur imposée).**

```bash
cat > .github/CODEOWNERS <<'OWNERS'
# Revue métier obligatoire sur tout le contenu.
# Éditeur = structure/qualité rédactionnelle ; SME = exactitude métier.
/content/public/     @<EDITOR_HANDLE> @<SME_HANDLE>
# Les corrigés exigent au minimum la validation de l'expert métier.
/content/answerKey/  @<SME_HANDLE>
/schemas/            @<EDITOR_HANDLE>
OWNERS

cat > README.md <<'MD'
# certigo-content

Contenu pédagogique de Certigo, **séparé du code applicatif**.

## Arborescence
- `content/public/`    — énoncés exposés au client (questions, examens).
- `content/answerKey/` — corrigés **sensibles** (ne jamais exposer côté public).
- `schemas/`           — schémas de validation v2 (référence : wp-p1-02).

## Contribuer
1. Brancher depuis `main`, éditer sous `content/`.
2. Ouvrir une PR : la validation de schéma (pipeline `ci-content`, wp-p1-06) doit être verte.
3. Revue obligatoire via CODEOWNERS (Éditeur + SME) avant merge.
MD

git add -A
git commit -m "chore: arborescence, CODEOWNERS et contenu de démonstration certigo-content"
git push -u origin main
```

**Gouvernance — branch protection sur `main` (revue + gate CODEOWNERS).**

```bash
# Exiger 1 approbation, la revue des CODEOWNERS, et bloquer les push directs.
# NB : "required_status_checks" est laissé vide ici ; le gate ci-content (p1-06)
# sera ajouté à cette liste une fois le pipeline en place.
gh api -X PUT repos/<ORG>/certigo-content/branches/main/protection \
  --input - <<'JSON'
{
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "require_code_owner_reviews": true
  },
  "required_status_checks": null,
  "enforce_admins": true,
  "restrictions": null
}
JSON
```

**Placeholders.** `<ORG>`, `<SME_HANDLE>`, `<EDITOR_HANDLE>`.

**Vérification (comment savoir que c'est fait).**

```bash
gh repo view <ORG>/certigo-content --json visibility,defaultBranchRef
# -> attendu : "visibility":"PRIVATE", defaultBranchRef.name = "main"

gh api repos/<ORG>/certigo-content/branches/main/protection \
  --jq '.required_pull_request_reviews.require_code_owner_reviews'
# -> attendu : true

gh api repos/<ORG>/certigo-content/contents/content/answerKey/solutions/demo-0001.json --jq '.name'
# -> attendu : demo-0001.json  (la séparation public/answerKey est en place)
```

Test de bout en bout de la gouvernance : ouvrir une PR de contenu et vérifier qu'elle
**exige** l'approbation d'un CODEOWNER avant de pouvoir être fusionnée.

**Rollback.** `gh repo delete <ORG>/certigo-content` (ou passer le dépôt en archive). Aucun
autre système n'y référence encore — la suppression est sans effet de bord tant que p1-05/06
n'ont pas démarré. Voir aussi le rollback de la fiche : « abandon de la branche ; le dépôt de
contenu reste isolé et non référencé ».

**Durée estimée.** ~45 min. **Ordre / dépendances.** **EN PREMIER** — clé de voûte.
Débloque `wp-p1-05` (migration contenu, dépend aussi de p1-02) et `wp-p1-06` (pipeline
`ci-content`) → `wp-p1-07` (manifeste immuable) → `wp-p1-08` (cache offline).

---

### 2. Résilience CI — supprimer le SPOF des runners (wp-p1-11-ci-spof-runners)

**Objectif (DoD).** Les jobs CI critiques n'ont **plus de dépendance à un runner unique** :
ils ciblent le label commun d'un pool d'au moins deux runners Azure self-hosted.
Une simulation d'indisponibilité d'une instance **ne bloque plus** la CI.

**Finding opérationnel.** La CI Certigo tourne aujourd'hui sur **un seul** runner
auto-hébergé (`vm-certigo-runner`, groupe `rg-certigo-ci`). Une panne de ce pool a déjà
**bloqué la CI ~6 h** — d'où la priorité. ⚠️ **Contrainte EMU** : les runners **hébergés par
GitHub sont désactivés durablement par la politique d'entreprise**
(voir `infra/ci-runner/README.md`). La résilience repose exclusivement sur plusieurs
instances Azure séparées par les labels `certigo-pr` et `certigo-trusted`.

**Pré-requis.**
- `az login` + abonnement sélectionné (`az account set --subscription <SUBSCRIPTION_ID>`).
- Droits d'admin sur les runners de l'org/dépôt GitHub (pour l'enregistrement).
- Précondition idempotente : auditer les workflows — si les jobs ciblent déjà un pool
  Azure isolé par les labels `certigo-pr`/`certigo-trusted`, le lot est **fait**.

**Étapes (intention + commande type — provisionnement live).**

```bash
# 1. Inventorier l'existant : combien de runners réels dans le pool ?
az vm list -g rg-certigo-ci -o table
gh api repos/<ORG>/<REPO>/actions/runners --jq '.runners[] | {name,status,busy}'
# -> objectif : confirmer qu'il n'existe qu'UN runner actif (le SPOF à corriger).

# 2a. OPTION A (recommandée) — 2e+ runner(s) self-hosted via VMSS/ARC.
#     Provisionner un 2e VM/scale set homogène au premier, puis l'enregistrer avec
#     le MÊME label que le premier pour former un pool (les jobs ciblent le label,
#     pas la machine). Exemple type (VMSS) :
az vmss create -g rg-certigo-ci -n vmss-certigo-runners \
  --image <IMAGE> --instance-count 2 --vnet-name vnet-certigo-ci --subnet snet-runners \
  --assign-identity <IDENTITY> --tags product=Certigo role=ci-runner
#     Puis, sur chaque instance, installer + enregistrer le runner GitHub Actions
#     (script actions-runner config.sh) avec un label commun, ex. "self-hosted,certigo".

# 2b. OPTION B — ARC (Actions Runner Controller) sur Kubernetes : déployer un
#     RunnerScaleSet ciblant le même label, min replicas >= 2.
```

**Rendre les jobs tolérants à la panne (côté workflow — hors périmètre docs, à faire en code
lors du lot réel).** Principe à appliquer dans les `.github/workflows/*` :

```yaml
# Le label commun route vers une instance disponible du pool Azure.
runs-on: [self-hosted, Linux, X64, certigo-trusted]
# Conserver au moins deux runners Azure homogènes dans ce pool.
```

**Placeholders.** `<SUBSCRIPTION_ID>`, `<ORG>`, `<REPO>`, `<IMAGE>`, `<IDENTITY>`.

**Vérification.**

```bash
gh api repos/<ORG>/<REPO>/actions/runners --jq '[.runners[] | select(.status=="online")] | length'
# -> attendu : >= 2 runners en ligne partageant le même label.
```

Test réel : **désactiver un runner** (arrêter une instance), relancer un workflow critique et
constater qu'il **s'exécute quand même** sur une autre instance (pas de blocage de la CI).

**Rollback.** Abandon de la branche de workflow ; **désallouer** les runners ajoutés
(`az vmss delete` / retrait de l'enregistrement GitHub). Les workflows précédents restent en
place (cf. fiche). Aucune donnée applicative touchée.

**Durée estimée.** ~2–4 h (provisionnement + enregistrement + test de bascule).
**Ordre / dépendances.** Indépendant ; peut être joué en parallèle des lots 3–4. Priorité
opérationnelle haute (stabilité de toute la CI Phase 1+).

---

### 3. Import du drift IaC — Azure OpenAI + réseau CI en Bicep (wp-p1-12-iac-drift-import)

**Objectif (DoD).** Les ressources Azure **créées hors-Bicep** sont **importées/décrites** en
IaC ; un **`what-if` Bicep ne montre aucun drift non intentionnel** ; la **procédure de
détection de drift** est documentée et exécutable. Import **descriptif uniquement** — aucune
modification appliquée aux ressources live sans revue du what-if.

**Constat live du 4 septembre.**

1. **Azure OpenAI `certigo-openai`** (`AIServices`, `swedencentral`, S0) est
   privé (`publicNetworkAccess=Disabled`), keyless (`disableLocalAuth=true`),
   avec projet `certigo-dev`, private endpoint approuvé et déploiement
   `gpt-5.4-mini` version `2026-03-17`, `GlobalStandard`, capacité 1. Le module
   gère le compte/modèle/RBAC indépendamment du feature flag runtime; projet et
   private endpoint restent `existing`. La zone live
   `privatelink.openai.azure.com` ne couvre pas le hostname Foundry
   `*.services.ai.azure.com`; aucune zone DNS n'est donc revendiquée par ce lot
   et l'activation runtime reste bloquée.
2. **Réseau CI** : les noms live sont `pip-vm-certigo-runner-2-nat` et
   `nat-vm-certigo-runner-2`. Le VNet a trois peerings; `network.bicep` le
   référence donc `existing` et gère seulement le sous-réseau enfant.
3. **Capacité CI** : les deux VMSS Flexible sont `existing`. `capacity.bicep`
   conserve min/default/max 2/2/4 et le scale-out CPU, mais retire le scale-in
   CPU qui ignore GitHub `busy`. Il ne déclare aucune instance VM.
4. **Frontière bloquante** : `be505fa1`, deallocated et sans runner, reste
   volontairement non classifiée. Ne pas l'ajouter à une liste pour obtenir un
   plan vert. Le contrôleur reste `enabled=false`.

**Pré-requis.**
- `az login` ; `az account set --subscription <SUBSCRIPTION_ID>`.
- Droits permettant la validation `Provider` sur `rg-certigo-ci` et `rg-certigo-dev`.
- Précondition idempotente : si les what-if montrent uniquement les changements
  intentionnels documentés,
  le lot est **fait**.

**Étapes (aucun apply implicite).**

```bash
# 1. Compiler tous les contrats ciblés.
bicep build infra/ci-runner/network.bicep --stdout >/dev/null
bicep build infra/ci-runner/capacity.bicep --stdout >/dev/null
bicep build infra/modules/openai.bicep --stdout >/dev/null

# 2. Vérifier les permissions effectives, puis le réseau et la capacité.
az account show --query "{subscription:id,tenantId:tenantId,user:user.name}" -o json
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep \
  --validation-level Provider
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/capacity.bicep \
  --validation-level Provider

# 3. OpenAI : le principal est lu, jamais fourni par un payload utilisateur.
FUNC="$(az functionapp list -g rg-certigo-dev --query '[0].name' -o tsv)"
PRINCIPAL="$(az functionapp identity show -g rg-certigo-dev -n "$FUNC" \
  --query principalId -o tsv)"
az deployment group what-if -g rg-certigo-dev \
  --template-file infra/modules/openai.bicep \
  --parameters accountName=certigo-openai location=swedencentral \
               deploymentName=gpt-5.4-mini functionAppPrincipalId="$PRINCIPAL" \
  --validation-level Provider
```

Le fallback `ProviderNoRbac` sert uniquement à diagnostiquer un manque de droits;
il ne permet pas d'appliquer. Une suppression, une création d'une ressource déjà
live, un changement de VMSS/VM/VNet parent, ou l'ouverture réseau d'OpenAI bloque.
Les changements intentionnels sont bornés : tags FinOps réseau/autoscale, retrait
de la seule règle CPU `Decrease`, gestion privée/keyless du compte OpenAI.

**Placeholders.** `<SUBSCRIPTION_ID>`, `<OPENAI_RG>` (RG hôte du compte `certigo-openai`).

**Vérification.** Conserver les sorties Provider complètes dans le ticket et
générer `preflight-report.md`. `bash infra/ci-runner/capacity-plan.sh` doit rester
read-only et signaler `be505fa1` tant qu'elle n'est pas classifiée. La gate
`ci-infra` doit rester verte.

**Rollback.** Avant apply : abandon de la branche, aucune ressource live modifiée.
Après une application approuvée : restaurer la version précédente de la seule
surface concernée en mode incrémentiel et refaire un what-if. Ne jamais utiliser
`Complete`, supprimer une VM/VMSS ou réintroduire le scale-in CPU comme rollback.

**Durée estimée.** ~2–3 h (revue what-if + apply prudents). **Ordre / dépendances.** À jouer
**avant le lot 4** : le staging s'appuie sur une IaC réconciliée et sans drift.

---

### 4. Environnement de staging — pré-prod isolée par IaC (wp-p1-13-staging-environment)

**Objectif (DoD).** Un environnement **staging** est **provisionnable par IaC** (paramètres
dédiés) et **isolé de la prod** ; un déploiement staging **réussit** et **`/health` est vert**.
Répond à la reco **O-04** (environnement de recette réel).

**État actuel.** `rg-certigo-staging` existe, est peuplé et porte
`managedBy=bicep`. Le déploiement subscription `certigo-staging` a réussi le
2026-08-16 en mode Incremental. Storage, Cosmos Continuous7Days, Key Vault,
Function App, VNet, private endpoints approuvés et alertes sont présents.
`/api/health/live`, `/api/health/ready` et `/api/health` répondent 200.

**Pré-requis.**
- `az login` ; `az account set --subscription <SUBSCRIPTION_ID>`.
- Droits de validation `Provider` au scope abonnement/RG.
- Paramètres sécurisés JWT et alerte fournis hors dépôt.
- Précondition idempotente déjà satisfaite : staging existe et provient de Bicep.

**Étapes.**

```bash
# Valider le déploiement existant; toute Create/Delete inattendue est bloquante.
az deployment sub what-if \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters @<SECURE_STAGING_PARAMETERS_JSON> \
  --validation-level Provider
```

**Placeholders.** `<SUBSCRIPTION_ID>`, `<TENANT_GUID>`, `<API_CLIENT_ID>`.

**Vérification.**

```bash
az group show -n rg-certigo-staging --query "properties.provisioningState" -o tsv
# -> attendu : Succeeded (RG staging isolé, distinct de rg-certigo-prod)

# /health du backend staging vert :
curl -fsS https://<STAGING_FUNCTION_HOST>/api/health
# -> attendu : HTTP 200 + statut sain. (Host = sortie du déploiement, functionApp module.)
```

Vérifier l'**isolation** : les ressources staging portent le suffixe `staging` et vivent dans
`rg-certigo-staging` — **aucune** ne partage d'état avec `rg-certigo-prod`.

**Rollback.** Abandonner la modification IaC avant apply. Après un changement
approuvé, revenir au template/paramètres précédents en mode Incremental. **Ne
jamais supprimer `rg-certigo-staging` comme rollback générique** : il contient un
environnement actif.

**Durée estimée.** ~1–2 h (après obtention des valeurs Entra). **Ordre / dépendances.**
**Après le lot 3** (`wp-p1-12`) : le staging suppose une IaC réconciliée et sans drift.

---

## Checklist cochable finale

**Lot 1 — `wp-p1-04-certigo-content-repo` (clé de voûte, EN PREMIER)** — ✅ fait (voir bandeau de statut en tête de document)
- [x] `certigo-content` créé en **privé** sur `<ORG>`
- [x] Arborescence en place : `content/public/` **et** `content/answerKey/` (séparation stricte)
- [x] `.github/CODEOWNERS` impose la revue **SME + Éditeur** ; `README` de contribution présent
- [x] Contenu de démonstration validable committé
- [x] Branch protection sur `main` : 1 approbation + **revue CODEOWNERS** + `enforce_admins`
- [x] Vérif : PR de test **exige** l'approbation d'un CODEOWNER avant merge

**Lot 2 — `wp-p1-11-ci-spof-runners`**
- [ ] **1 runner `certigo-pr` + 1 runner `certigo-trusted`** en ligne, sans label commun
- [ ] Aucun label GitHub-hosted ni fallback configurable dans les workflows
- [ ] Simulation d'indisponibilité d'un runner : la CI **ne bloque pas**

**Lot 3 — `wp-p1-12-iac-drift-import`**
- [ ] Syntaxe, permissions et trois what-if Provider archivés
- [ ] Aucun Create/Delete, aucun PUT VM/VMSS/VNet parent
- [ ] Scale-in CPU absent du contrat; contrôleur toujours désactivé
- [ ] `certigo-openai` reste privé/keyless et n'est ni recréé ni supprimé
- [ ] `be505fa1` reste bloquante jusqu'à classification indépendante
- [ ] Procédure de détection de drift documentée + `ci-infra` vert sur `main`

**Lot 4 — `wp-p1-13-staging-environment`**
- [x] Déploiement subscription `certigo-staging` **Succeeded** le 2026-08-16
- [x] `/health/live`, `/health/ready` et `/health` **verts**
- [x] RG et ressources principales tagués `managedBy=bicep`
- [x] Isolation RG/réseau confirmée; aucun partage d'état avec la prod

---

> **Note d'orchestration.** Après une preuve live, mettre à jour
> `docs/migration/state/<id>.json` et **append** une ligne dans
> [`log.jsonl`](./log.jsonl) (append-only, UNION, 0 suppression). Une PR IaC ne
> doit jamais appliquer ni merger automatiquement un changement live. Ordre de
> décision recommandé : **1 (keystone) → 2 → revue 3 → maintien 4**.
