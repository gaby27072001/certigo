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

> **Statut vérifié le 2026-09-03** (consolidation documentaire) :
> - **Lot 1** (`wp-p1-04-certigo-content-repo`) — ✅ **FAIT**. Le dépôt
>   [`gchambaud_microsoft/certigo-content`](https://github.com/gchambaud_microsoft/certigo-content)
>   existe, avec arborescence `content/public`/`content/answerKey`, gouvernance et pipeline CI
>   opérationnels (`work-packages.yaml`/`STATE.md` : `done`). Rien à rejouer.
> - **Lot 2** (`wp-p1-11-ci-spof-runners`) — ⚠️ **encore ouvert, mais partiellement recoupé
>   par `wp-p2-07`** (PR [#250](https://github.com/gchambaud_microsoft/Certigo/pull/250) et
>   [#253](https://github.com/gchambaud_microsoft/Certigo/pull/253), fusionnées) qui a livré le
>   **failover** sur un pool Azure ≥2 instances. La séparation stricte des labels
>   `certigo-pr` / `certigo-trusted` a été revérifiée le 4 septembre 2026. La DoD du lot
>   reste ouverte tant que le scale-in CPU non conscient de GitHub et les preuves lifecycle
>   fail-closed ne sont pas résolus. Ne pas considérer ce lot comme fait sans revérifier
>   `CI_RUNNERS.md`.
> - **Lots 3 et 4** (`wp-p1-12-iac-drift-import`, `wp-p1-13-staging-environment`) — toujours
>   ouverts (`todo` dans le registre), inchangés depuis la dernière vérification.

---

## Résumé — les 4 actions dans l'ordre

| # | Action | Lot | Surface | Durée | Débloque |
| --- | --- | --- | --- | --- | --- |
| 1 | **Créer le dépôt `certigo-content`** (arborescence + gouvernance + séparation public/answerKey) | `wp-p1-04-certigo-content-repo` | GitHub (org) | ~45 min | p1-05, p1-06 → p1-07 → p1-08 |
| 2 | **Résilience CI** : supprimer le SPOF runner (pool Azure ≥2 instances) | `wp-p1-11-ci-spof-runners` | Azure + GitHub Actions | ~2–4 h | Stabilité CI de toute la Phase 1+ |
| 3 | **Import du drift IaC** : Azure OpenAI + réseau CI en Bicep (what-if → apply) | `wp-p1-12-iac-drift-import` | Azure (abonnement live) | ~2–3 h | p1-13 |
| 4 | **Environnement de staging** : pré-prod isolée, provisionnée par IaC (O-04) | `wp-p1-13-staging-environment` | Azure (abonnement live) | ~1–2 h | Recette pré-prod P1+ |

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

**Finding G (audit).** Deux dérives principales, **déjà scaffoldées en code sur `main`** ;
il reste à **jouer les déploiements d'adoption côté live** (voie ops, non faisable par l'agent) :
1. **Compte Azure OpenAI `certigo-openai`** (région **swedencentral**, dev) créé hors-bande →
   module d'**adoption** `infra/modules/openai.bicep` (câblé dans `infra/main.bicep`, module
   `tutor`, encore gated dev-only).
2. **Chemin d'egress réseau du runner CI** (5 ressources : `pip-certigo-nat`, `nat-certigo`,
   `vnet-certigo-ci`, `snet-runners`, NSG) dans `rg-certigo-ci` → figé par
   `infra/ci-runner/network.bicep`. Les **VMs runners restent hors IaC** (report Phase 2,
   choix assumé — voir `infra/ci-runner/README.md`).

**Pré-requis.**
- `az login` ; `az account set --subscription <SUBSCRIPTION_ID>`.
- Droits **Contributor** (a minima) sur `rg-certigo-ci` et le RG hôte de `certigo-openai`.
- Précondition idempotente : si un `what-if` sur les deux périmètres ne montre **aucun** drift,
  le lot est **fait**.

**Étapes (what-if AVANT tout apply — c'est un import d'adoption, jamais un recreate).**

```bash
# 1. Réseau CI : valider sans rien changer (n'affiche que des diffs bénignes documentées).
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep
# -> attendu : aucun changement sur le chemin d'egress (IP/NAT/subnet identiques).
#    Seules subsistent les 3 diffs "bénignes" listées dans infra/ci-runner/README.md.

# 2. Déployer le réseau CI en INCRÉMENTIEL (ne touche que les 5 ressources d'egress).
#    ⚠️ NE JAMAIS déployer en mode "Complete" : cela supprimerait la VM runner et son disque.
az deployment group create -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep

# 3. Azure OpenAI : adopter le compte existant. Confirmer d'abord les valeurs live
#    (nom, région, déploiement, version de modèle) puis passer le what-if global.
az cognitiveservices account show -n certigo-openai -g <OPENAI_RG> \
  --query "{name:name,location:location,sku:sku.name}" -o json
az deployment sub what-if \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/dev.bicepparam
# -> attendu : le compte certigo-openai ressort en UPDATE (adopté), PAS en Create/Delete.
#    Aligner les paramètres du module openai sur le live tant que le what-if montre du drift.
```

**Procédure de détection de drift (à documenter/planifier — livrable du DoD).** Exécuter
périodiquement (ou en CI `ci-infra`) un `what-if` sur chaque périmètre ; toute diff non
listée comme « bénigne » est un drift à traiter.

**Placeholders.** `<SUBSCRIPTION_ID>`, `<OPENAI_RG>` (RG hôte du compte `certigo-openai`).

**Vérification.**

```bash
az deployment group what-if -g rg-certigo-ci --template-file infra/ci-runner/network.bicep \
  | Select-String -Pattern "Modify|Delete|Create"
# -> attendu : aucune ligne, hormis les diffs bénignes connues (sku.tier, scope, ipTags).
```

Côté CI : le pipeline `ci-infra` compile déjà les modèles (`az bicep build`) — le job doit
rester **vert** sur `main`.

**Rollback.** Abandon de la branche ; l'import étant **descriptif** (incrémentiel, jamais
Complete), **aucune** ressource live n'est modifiée en cas d'abandon. Ne **jamais** lancer un
déploiement Complete sur `rg-certigo-ci`.

**Durée estimée.** ~2–3 h (revue what-if + apply prudents). **Ordre / dépendances.** À jouer
**avant le lot 4** : le staging s'appuie sur une IaC réconciliée et sans drift.

---

### 4. Environnement de staging — pré-prod isolée par IaC (wp-p1-13-staging-environment)

**Objectif (DoD).** Un environnement **staging** est **provisionnable par IaC** (paramètres
dédiés) et **isolé de la prod** ; un déploiement staging **réussit** et **`/health` est vert**.
Répond à la reco **O-04** (environnement de recette réel).

**État actuel.** Le fichier de paramètres **`infra/params/staging.bicepparam` existe déjà** sur
`main` : durcissement calqué sur la prod (Cosmos RBAC-only, Key Vault purge protection, storage
géo-redondant), `env='staging'`, `location='westeurope'`, Cosmos épinglé `northeurope`. Le RG
cible est **`rg-certigo-staging`** (patron `rg-${appName}-${env}` de `infra/main.bicep`).
**Seuls 2 blocages** subsistent : les **valeurs Entra External ID** (CIAM) de staging.

**Pré-requis.**
- `az login` ; `az account set --subscription <SUBSCRIPTION_ID>`.
- Droits de créer un RG + déployer au **scope abonnement** (`az deployment sub create`).
- App registration backend **dédiée staging** (préférable) pour obtenir `<TENANT_GUID>` et
  `<API_CLIENT_ID>` — **NE PAS inventer de GUID** (à défaut, réutiliser temporairement les
  valeurs prod en connaissance de cause, cf. commentaires du `staging.bicepparam`).
- Précondition idempotente : si un staging isolé provisionné par IaC existe **déjà**, lot fait.

**Étapes.**

```bash
# 1. Renseigner les 2 paramètres Entra dans infra/params/staging.bicepparam
#    (SEULS blocages avant déploiement — sinon tout login est rejeté 401 aud/issuer) :
#      param entraAuthority = 'https://certigo.ciamlogin.com/<TENANT_GUID>/v2.0'
#      param entraAudience  = 'api://<API_CLIENT_ID>'
#    Utiliser le sous-domaine GUID de tenant (<TENANT_GUID>.ciamlogin.com), pas un vanity domain.

# 2. Déployer le staging au scope abonnement (crée le RG rg-certigo-staging + la stack).
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/params/staging.bicepparam
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

**Rollback.** Abandon de la branche ; **supprimer l'environnement** de staging le cas échéant
(`az group delete -n rg-certigo-staging`) — la **prod reste inchangée** (RG distinct).

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
- [ ] `what-if` réseau CI : aucune diff hors « bénignes » documentées
- [ ] Déploiement réseau CI en **incrémentiel** (jamais Complete)
- [ ] `certigo-openai` ressort en **UPDATE** (adopté), pas Create/Delete, au what-if
- [ ] Procédure de détection de drift documentée + `ci-infra` vert sur `main`

**Lot 4 — `wp-p1-13-staging-environment`**
- [ ] Valeurs Entra staging (`<TENANT_GUID>`, `<API_CLIENT_ID>`) renseignées (pas de GUID inventé)
- [ ] `az deployment sub create` staging **réussi** (`rg-certigo-staging` = Succeeded)
- [ ] `/health` du backend staging **vert**
- [ ] Isolation confirmée (aucun partage d'état avec la prod)

---

> **Note d'orchestration.** Ce runbook est **docs-only**. Après exécution réelle d'un lot par
> Gabriel, mettre à jour l'état dans le registre : `docs/migration/state/<id>.json`
> (`todo → in_progress → done`) et **append** une ligne dans
> [`log.jsonl`](./log.jsonl) (append-only, UNION, 0 suppression). La PR qui porte ce document
> reste en **draft** et ne doit être ni fusionnée ni sortie du draft par l'agent : elle sert de
> support de revue au guide opérateur. Ordre de jeu recommandé : **1 (keystone) → 2 → 3 → 4**.
