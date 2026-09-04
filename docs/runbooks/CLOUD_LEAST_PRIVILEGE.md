# Moindre privilège cloud — migration OIDC, RBAC et runners

## Statut et garde-fous

Ce runbook prépare la migration du déploiement Certigo vers des identités séparées et des
scopes minimaux. **Cette PR ne réalise aucune mutation Azure ou GitHub** : aucun rôle n'est
retiré, aucune ressource n'est supprimée, aucune VM n'est démarrée ou déallouée, aucun secret
n'est modifié et aucun déploiement n'est lancé.

Les commandes d'inventaire et de `what-if` sont read-only :

```bash
export AZURE_SUBSCRIPTION_ID=b8952c8c-8f72-469d-99cd-ac906da4e2fc
bash infra/governance/inventory.sh > inventory.json
bash infra/governance/what-if-phase-a.sh
# Phase B exige ensuite le nom d'un deployment Phase A réussi et approuvé.
bash infra/ci-runner/lifecycle-preflight.sh deallocate
```

La cible **future** exécutable de Phase B est désormais la subscription personnelle
`f434ec55-f342-4948-9298-f99af5216204` dans le tenant
`e9174162-1033-40c0-b0c9-f31825914fbe`. Les snapshots `16b3…/b895…` ci-dessous restent un
historique d'inventaire Non-Production, pas une autorisation d'exécution. Tout manifeste, preuve
Phase A ou binding portant cette ancienne paire est stale et refusé. Aucun identifiant n'est
substitué : il faut régénérer Phase A/A0 et toutes les preuves contre la paire personnelle explicite,
puis confirmer que les RG, identités et scopes attendus y existent. En leur absence, Phase B reste
**NO-GO**; le tooling ne crée ni compte, ni rôle, ni ressource automatiquement.

`lifecycle-preflight.sh` ne possède volontairement aucun chemin `apply`. Il retourne `2` dès
qu'une déallocation serait dangereuse et, dans cette PR, pour toute demande puisque le
feature flag reste `off`.

## Inventaire read-only consolidé au 20 août et revérifié le 4 septembre 2026

Périmètre observé : subscription
`b8952c8c-8f72-469d-99cd-ac906da4e2fc`, groupes `rg-certigo-dev`,
`rg-certigo-staging`, `rg-certigo-prod` et `rg-certigo-ci`.

### Identité de déploiement actuelle

| Élément | État actuel prouvé |
|---|---|
| Application | `microlingo-github-actions`, appId `4bfc43dc-6a25-404e-a6ab-d19784ab0673` |
| Service principal | `15d2b34a-c0a0-4b5d-8360-b895a8164706` |
| Scope abonnement | `Contributor` + `User Access Administrator`, sans condition |
| Dev / staging / prod | `Storage Blob Data Contributor` sur chaque conteneur `app-package` |
| Dev / staging / prod | `Storage Blob Delegator` sur chaque compte Storage |
| Federated credentials | branche `main`, sujet `workflow_dispatch`, puis environnements `dev`, `staging`, `prod` |
| GitHub Environments | `dev`, `staging`, `prod` limités aux branches protégées |
| Secrets Azure | `dev` possède ses `AZURE_*`; staging/prod héritent encore de la configuration dépôt |

Les deux rôles data-plane sont nécessaires au package OneDeploy. Les deux rôles abonnement
sont historiques et constituent le finding à résorber : ils sont remplacés par le JIT humain testé
et les huit attributions temporaires exactes, puis retirés avant Phase B. Ils ne sont jamais
conservés pendant les canaris ou le soak.

### Runners

L'état live ne correspond plus aux anciennes VM autonomes documentées :

| Élément | État observé |
|---|---|
| Compute géré | `f55d176e` dans `vmss-certigo-runner-zonal` zone 2; pilote `bbf83c5c` dans `vmss-certigo-pr-pilot-z1` zone 1 |
| Inventaire Azure courant | `f55d176e` et `bbf83c5c` running; `4153d1dd` externe/deallocated; `22f7fb52` absent; essai `4596a9d5` absent/interdit |
| Autoscale | activé, minimum `2`, défaut `2`, maximum `4` |
| Scale-out | CPU moyenne > 70 % pendant 10 min |
| Scale-in | CPU moyenne < 20 % pendant 45 min — **non conscient des jobs GitHub** |
| Inventaire GitHub | runner `27` `f55d176e-Certigo` offline/non-busy, `certigo-trusted` uniquement; runner `28` `certigo-prIVJAN8` offline/non-busy, `certigo-pr` + `certigo-pr-pilot`; runner `26` `22f7fb52-Certigo` offline/stale et hors scope |
| Cloisonnement | le pilote est sans identité, sur `vnet-certigo-pr-pilot/snet-pr-runners`; `f55d176e` conserve UAMI + `snet-runners`; les labels de confiance sont exclusifs |
| Capacité réellement réconciliée | **2 instances gérées/deallocated** : `f55d176e` et `bbf83c5c`; `4153d1dd` reste externe |

Le premier snapshot avait vu trois VM, avant le scale-in CPU. L'état consolidé prouve qu'un
simple comptage « VM Azure / runners GitHub » est faux. La réconciliation explicite classe
le runner 26 (`22f7fb52-Certigo`) et la VM `4153d1dd` comme **externes**, et les bindings
exacts `f55d176e`/runner `27` et `bbf83c5c`/runner `28` comme **gérés**. Externe ne
signifie ni orphelin ni adoptable : ces ressources sont
exclue de `currentCapacity`, de toute sélection de cible et de toute opération future par
une classification exacte dans `inventory.externalVirtualMachines`. Toute autre VM sans
runner reste `unclassifiedVirtualMachines` et bloque le plan; elle n'est jamais implicitement
considérée externe.

### Baseline capacité et coût sur 30 jours

| Mesure | Valeur |
|---|---:|
| Coût CI dominant | **242,06 USD** |
| Jobs | 413 |
| File P95 | 5 108 s (85,1 min) |
| File P99 | 12 628 s (210,5 min) |
| Runner-heures utiles | 18,84 h |
| CPU moyenne | 3,78 % |

Le signal CPU est décorrélé du besoin : la capacité reste coûteuse et peu utilisée, tandis que
la file est très longue. Augmenter le CPU ou conserver un minimum permanent de deux VM ne traite
donc pas la cause. La cible écoute les événements `workflow_job`, sépare les classes de confiance
et dimensionne sur la file/activité réelle, jamais sur le CPU seul.

### Ressources CI et nettoyage

Les anciens candidats `pip-certigo-test`, `vm-certigo-runnerVNET`,
`vm-certigo-runnerVNET-vm-certigo-runnerSubnet-nsg-westeurope` et
`vm-certigo-runnerNSG` ne sont plus présents dans l'inventaire live. Aucune action n'est requise.

Les ressources suivantes avaient une relation live prouvée au snapshot initial et doivent être
réinventoriées avant toute décision :

- les disques retournés étaient `Attached` à leurs VM ;
- les IP publiques sont liées au Load Balancer ou à la NAT Gateway ;
- la NAT Gateway est liée à `snet-runners` ;
- le NSG est lié à `snet-runners` ;
- le Load Balancer référence les trois NIC de VM ;
- l'UAMI `id-vm-certigo-runner-2-vmss` est liée au VMSS et possède uniquement
  `Key Vault Secrets User` sur `kv-certigo-ci-081423`.

`4153d1dd` est explicitement externe et gelée. Ne pas la démarrer, déallouer, supprimer,
réenregistrer, relabelliser ou adopter depuis cette PR.

`kv-certigo-ci-pub814` et tout autre artefact sans chaîne d'usage complète restent
**non classés**, jamais « orphelins par intuition ». Une suppression n'est envisageable que si
les quatre preuves suivantes sont archivées :

1. aucune référence ARM entrante, attribution RBAC, diagnostic, lock ou dépendance DNS ;
2. aucun accès utile dans les journaux sur une fenêtre approuvée ;
3. aucun propriétaire/workflow/runbook ne revendique la ressource ;
4. `what-if` et rollback testés, ticket de changement et approbation humaine.

## Matrice cible

| Surface | Cible |
|---|---|
| OIDC application | UAMI `id-certigo-deploy-dev`, `-staging`, `-prod` |
| Fédération | une seule credential par UAMI : `repo:gchambaud_microsoft/Certigo:environment:<env>` |
| Protection GitHub | environment limité à `main`/branche protégée + reviewers pour staging/prod |
| Lancement abonnement | rôle custom `Certigo Subscription Deployment Launcher`: deployment read/write/validate/what-if + lecture RG, sans `resourceGroups/write` |
| Management applicatif | `Contributor` au seul `rg-certigo-<env>` |
| Création RBAC runtime | rôle custom sans `delete`, conditionné aux rôles runtime allow-listés et aux `ServicePrincipal` |
| Réseau partagé | rôle custom sur `rg-certigo-ci`, limité aux deployments, private DNS et peerings; aucun droit Compute/Key Vault |
| Package backend | Blob Data Contributor au conteneur `app-package`; Blob Delegator au compte du même environnement |
| Sécurité abonnement | MCSB/Defender gérés par un admin PIM via `infra/governance`, jamais par l'identité d'environnement |
| Policy | audit des Owner/Contributor/UAA/RBAC Admin attribués à un service principal au scope abonnement; `Deny` seulement après assainissement |
| Contenu #290 | identités distinctes du dépôt `certigo-content`, environnements `azure-content-public` et `azure-content-answer-key` |
| Plan contenu post-#290 | UAMI dédiée `id-certigo-content-infra-plan` dans `rg-certigo-identities`, sujet unique `repo:gchambaud_microsoft/Certigo:environment:azure-content-infra-plan`; exécuteur exact sur `rg-certigo-content` et joins externes aux deux ressources réseau exactes |
| Administration RBAC | PIM JIT pour l'humain; comptes break-glass contrôlés, jamais utilisés par CI |

Le rôle conditionnel peut seulement créer les rôles nécessaires aux modules actuels :
Blob Data Contributor/Owner/Delegator, Queue/Table Data Contributor, Monitoring Metrics
Publisher, Key Vault Secrets User, Cognitive Services OpenAI User et Log Analytics Reader.
Il ne peut ni créer Owner/Contributor/UAA, ni supprimer une attribution.

## Bootstrap gouvernance en deux phases

### A0 humain et planner B1a borné

Toutes les opérations non conditionnables restent humaines PIM : création des UAMI/FIC,
`roleDefinitions`, `policyDefinitions`, et `policyAssignments`. Aucune identité workload ne reçoit
ces actions. `bootstrap-planning-identity.bicep`, exécuté seulement dans A0 humain, précrée
`id-certigo-governance-phase-b1a-plan`, sa FIC exacte
`repo:gchambaud_microsoft/Certigo:environment:azure-governance-bootstrap-phase-b`, et le rôle B1a.
Le template ne crée aucune attribution.

Le rôle B1a contient uniquement `roleAssignments/read`, `roleAssignments/write` et
`roleDefinitions/read`; ses assignable scopes sont les quatre RG exacts dev/staging/prod/CI.
Un admin PIM attribue séparément le rôle deployment-launcher existant au scope subscription, puis
le rôle B1a à chacun des quatre RG. `planner-pim-contract.mjs` génère et valide pour chaque RG la
condition `2.0` qui borne `PrincipalId`, `RoleDefinitionId` et `PrincipalType`. Le scope est borné
structurellement par l'attribution RBAC au RG; Azure n'expose pas d'attribut ABAC `Scope`.
Le launcher conserve pour seul write `Microsoft.Resources/deployments/write`; ses lectures
additionnelles sont bornées aux deployments, RG, role/policy definitions et assignments, UAMI et
FIC nécessaires au binding Phase A live. Il n'accorde aucun autre write ni dataAction.

```bash
# Prévol A0 humain, lecture seule
GOVERNANCE_PLANNER_EVIDENCE_DIR='<private-output-directory>' \
  bash infra/governance/what-if-governance-planner.sh

# Après approbation humaine du manifeste A0, sous activation PIM :
node infra/governance/evidence-files.mjs verify-seal \
  '<private-output-directory>/manifest.json' \
  '<private-output-directory>/manifest.sha256'
node infra/governance/validate-planner-what-if.mjs evidence \
  '<private-output-directory>/manifest.json' \
  '<approved-planner-manifest-sha256>' \
  "$PWD" \
  "$AZURE_SUBSCRIPTION_ID" \
  "$(az account show --query tenantId --output tsv)"
az bicep build \
  --file infra/governance/bootstrap-planning-identity.bicep \
  --stdout > /tmp/governance-planner-template.json
cmp /tmp/governance-planner-template.json \
  '<private-output-directory>/compiled-template.json'
az deployment sub create \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name 'certigo-governance-b1a-planner-bootstrap-<ticket>' \
  --location "${AZURE_LOCATION:-westeurope}" \
  --template-file '<private-output-directory>/compiled-template.json' \
  --parameters '@<private-output-directory>/parameters.json'

# Après Phase A, produire le contrat PIM depuis le deployment A0 relu en direct
# L'outil relit également l'UAMI, toutes ses FIC paginées et le roleDefinition
# live; il exige une seule FIC et refuse tout drift de principal, sujet,
# audience, actions ou scopes.
node infra/governance/planner-pim-contract.mjs \
  '<private-output-directory>/manifest.json' \
  '<approved-planner-manifest-sha256>' \
  'certigo-governance-b1a-planner-bootstrap-<ticket>' \
  b1a-pim-contract.json
```

Le générateur réexécute le binding Phase A complet via `prepare-phase-b.sh` à partir des variables
`PHASE_A_*`; il n'accepte aucun fichier Phase A fourni directement. Il refuse aussi tout accès
RBAC actif, hérité, éligible ou activé déjà présent sur le principal planner. Le contrat doit être
généré avant les cinq attributions PIM décrites, jamais pour légitimer une identité déjà privilégiée.
Toutes les entrées Phase B exigent explicitement `AZURE_TENANT_ID=e9174162-1033-40c0-b0c9-f31825914fbe`
et `AZURE_SUBSCRIPTION_ID=f434ec55-f342-4948-9298-f99af5216204` avant tout appel Azure. Toute autre
paire, notamment le binding professionnel historique, échoue avant login, inventaire, what-if ou
déploiement.

La migration réutilise les ressources Phase A live et leurs preuves v2; elle ne les recrée pas.
Avant toute Phase B, le legacy `microlingo-github-actions` ne doit plus avoir `Contributor` ni
`User Access Administrator` au scope abonnement. Leur retrait n'arrive toutefois qu'après création
d'un remplacement humain JIT, deux activations et non-lockout testés, rollback prouvé, puis création
des huit
attributions legacy temporaires exactes décrites plus bas. `prepare-phase-b.sh` exige le contrat
`LEGACY_TRANSITION_FILE`, résout exhaustivement les groupes transitifs du principal legacy, relit
les attributions actives de chaque principal/groupe ainsi que les schedules PIM actifs et éligibles,
et bloque si un accès de groupe ou une éligibilité subsiste, si un rôle large subsiste, si une
attribution temporaire manque, si une attribution non approuvée subsiste ou si l'échéance live d'une
schedule instance diffère du contrat approuvé ou dépasse le soak. Une visibilité Graph ou ARM
incomplète est une erreur bloquante, jamais une preuve d'absence. Le manifeste what-if scelle aussi
le SHA-256 exact du contrat legacy; chaque script de déploiement rematérialise ce contrat depuis la
source approuvée et refuse toute absence, malformation ou substitution post-approbation avant
`az deployment ... create`.

Le workflow `azure-content-infra-plan` ne réutilise aucune identité dev, staging, prod ou
VMSS. Le `what-if` ARM exige les mêmes permissions `write` que le déploiement évalué : le rôle
subscription launcher seul est donc insuffisant et n'est pas attribué à cette UAMI.

Le plan monolithique réel #317 (`37 Create`, `59 Ignore`, `2 Unsupported`, `0 Modify/Delete`)
est refusé : les 13 attributions visant des UAMI futures ne sont pas validables avant création
des principals, et les deux scopes `extensionResourceId` subnet/DNS ne sont pas matérialisables
par le moteur de what-if. Le bootstrap est donc séparé et fail-closed :

- **Phase A — `bootstrap-identities`** : crée ou adopte `rg-certigo-identities` pour les huit
  UAMI et sept FIC exactes, et `rg-certigo-content` pour le futur stack contenu. Elle crée aussi
  les six custom roles et la policyDefinition au scope subscription. Elle ne contient aucun
  `roleAssignment`, aucun `policyAssignment` et ne donne aucune permission effective. Son output
  `phaseA` versionné contient les deux resource group IDs, les `clientId`, `principalId`,
  `resourceId`, les six role definition IDs, le policy definition ID, le tenant et la subscription.
- **Phase B1a automatisable — `bootstrap-rbac`** : consomme les IDs Phase A comme paramètres
  littéraux et planifie six attributions RG sans délégation RBAC : Contributor sur
  dev/staging/prod et réseau partagé sur CI. Elle ne contient ni launcher subscription,
  rôle accordant `roleAssignments/write`, ni policyAssignment.
- **Phase B1b humain PIM — `bootstrap-rbac-admin`** : planifie séparément les trois launchers,
  les trois runtime writers conditionnés, l'exécuteur contenu conditionné et l'unique
  policyAssignment en `Audit`. Aucun workload ne peut créer ces attributions délégatrices.
- **Phase B2 — `contentPlanExternalJoinAssignments`** : cible directement `rg-certigo-ci` et
  planifie séparément les deux attributions externes sur le subnet et la zone DNS exacts.

L'UAMI de plan reçoit seulement en Phase B :

- `Certigo Content Infrastructure Plan Executor` uniquement sur `rg-certigo-content`, avec
  `deployments` read/write/validate/what-if et les read/write explicites nécessaires pour
  Storage, private endpoint/DNS zone group et role assignments du template contenu, plus la
  lecture des UAMI publisher/reader précréées par le bootstrap. L'unique action d'approbation
  est `Microsoft.Storage/storageAccounts/PrivateEndpointConnectionsApproval/action`, nécessaire
  à l'auto-approbation de la connexion privée du compte Storage ;
- `Certigo Content Infrastructure Plan External Join` uniquement sur
  `rg-certigo-ci/vnet-certigo-ci/snet-runners` et la zone
  `rg-certigo-ci/privatelink.blob.core.windows.net`, avec seulement subnet read/join et private
  DNS zone read/join.

La Phase A crée dans `rg-certigo-identities` les trois UAMI de déploiement, l'UAMI de plan, les
trois UAMI publisher avec leur FIC exacte et l'UAMI reader sans fédération. Le template de plan
les traite comme `existing` :
l'identité de plan n'a donc aucun write UAMI/FIC.

Ces rôles n'ont aucun wildcard, aucune action `delete`, aucun data-plane, aucun
`resourceGroups/write`, aucun `roleDefinitions/write`, et ne donnent aucun accès à
dev/staging/prod. Le `roleAssignments/write` est conditionné aux couples exacts : rôle
Immutable Content Publisher vers les trois principal IDs publisher, et Storage Blob Data
Reader vers le seul principal ID reader, tous de type `ServicePrincipal`. Le rôle externe
n'inclut pas
`privateDnsZones/write` : si un what-if Azure
prouve que `join/action` ne suffit pas pour le DNS zone group, le bootstrap doit s'arrêter. Une
permission `Microsoft.Network/privateDnsZones/write` ne pourrait être envisagée que dans une
revue séparée et avec attribution conservée sur cette zone exacte, jamais au scope abonnement
ou `rg-certigo-ci`.

### What-if Phase A

Depuis une session admin/PIM séparée, sans déploiement :

```bash
export AZURE_SUBSCRIPTION_ID='<subscription-uuid>'
bash infra/governance/what-if-phase-a.sh
```

Le script conserve le JSON ARM brut complet (`FullResourcePayloads`) et ne filtre aucun type de
changement. Phase A ne cible aucun module sous `rg-certigo-ci` : elle calcule seulement cet ID pour
les `assignableScopes` réseau, ce qui évite l'énumération de l'inventaire CI sans l'autoriser.
Le validateur exige `status == Succeeded`, `error == null`, aucun diagnostic, aucune
`potentialChanges` et aucun `unsupportedReason`. Il accepte seulement `Create`, `NoChange`, ou un
`Ignore` strictement inerte (`before == after`, `delta == null`) pour un ID exact du contrat.
`NoChange` permet de reprendre après une Phase A partiellement appliquée uniquement si le payload
complet (`id`, `name`, `type`, propriétés) revalide le même rôle/actions, la même UAMI, la même FIC,
la même policyDefinition ou l'un des deux RG. Un payload absent/incomplet, un doublon ou une
divergence est refusé. Il exige `0 Modify`, `0 Delete`, `0 Unsupported`, refuse tout wildcard,
action delete, `dataActions` et toute ressource hors contrat. L'allowlist de création est :

- `rg-certigo-identities` ;
- `rg-certigo-content` ;
- les six custom roles nommés dans `bootstrap-identities.bicep` ;
- `id-certigo-deploy-{dev,staging,prod}`, `id-certigo-content-infra-plan`,
  `id-certigo-content-{release,public,answer-key,reader}` ;
- les sept FIC et sujets GitHub Environment exacts ;
- la policyDefinition `Certigo: restrict privileged CI role assignments at subscription scope`.

Après archivage, l'admin PIM crée un JSON d'approbation Phase A hors dépôt avec
`schemaVersion: 1`, `approved: true`, `phase: "A"`, `manifestSha256`, `planSha256` et
`sourceCommit`. Le deployment utilise uniquement le template ARM compilé et les paramètres
résolus contenus dans l'artifact approuvé :

```bash
PHASE_A_EVIDENCE_DIR='<approved-phase-a-artifact>' \
PHASE_A_APPROVAL_FILE='<approved-phase-a.json>' \
PHASE_A_DEPLOYMENT_NAME='certigo-governance-bootstrap-identities-<ticket>' \
  bash infra/governance/deploy-phase-a.sh

az deployment sub show \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "certigo-governance-bootstrap-identities-<ticket>" \
  --query properties.outputs.phaseA.value \
  --output json > phase-a-output.json
chmod 600 phase-a-output.json
```

Le fichier d'output est un artefact de changement contrôlé, jamais committé.

### Réparation de preuve Phase A

L'artefact original approuvé est obligatoire. Un template recompilé localement, des hashes recalculés
ou un manifeste reconstruit ne constituent jamais une preuve de substitution. Deux cas imposent un
arrêt avant Phase B :

- l'artefact original, son manifeste, son plan, ses paramètres ou son template compilé est absent ou
  contient un symlink ;
- le `templateHash` du deployment live diffère du `armTemplateHash` scellé.

La seule reprise autorisée est un changement de réparation séparé, lié au template courant :

1. ouvrir un ticket de réparation distinct et exécuter un nouveau `what-if-phase-a.sh` ;
2. archiver et faire approuver son nouvel artefact et son hash de manifeste ;
3. déployer exactement ce template compilé sous un nouveau nom de deployment Phase A ;
4. archiver les opérations et outputs de ce deployment, puis utiliser exclusivement son triplet
   `PHASE_A_DEPLOYMENT_NAME`, `PHASE_A_EVIDENCE_DIR` et
   `PHASE_A_EVIDENCE_MANIFEST_SHA256`.

Il est interdit de copier une sortie locale dans l'ancien artefact, de réutiliser l'ancien nom de
deployment ou de présenter le build local comme équivalent au deployment live.

### What-if Phase B

La Phase B ne peut démarrer qu'avec le nom du deployment Phase A approuvé :

```bash
export AZURE_SUBSCRIPTION_ID='<subscription-uuid>'
export PHASE_A_DEPLOYMENT_NAME='certigo-governance-bootstrap-identities-<ticket>'
export PHASE_A_EVIDENCE_DIR='<downloaded-governance-phase-a-evidence>'
export PHASE_A_EVIDENCE_MANIFEST_SHA256='<approved-manifest-sha256>'
export LEGACY_TRANSITION_FILE='<approved-legacy-transition.json>'
export LEGACY_TRANSITION_SHA256='<approved-legacy-transition-sha256>'
export PHASE_B_EVIDENCE_DIR='<private-output-directory>'
bash infra/governance/what-if-phase-b.sh
```

Le dispatch Phase B exécute uniquement B1a. B1b est exécuté localement par l'admin PIM avec
`what-if-phase-b1b.sh`, puis déployé seulement avec `deploy-phase-b1b.sh` et une preuve approuvée.
Après approbation et deployments B1a+B1b, l'admin PIM fournit localement les preuves immuables
Phase A, B1a et B1b à `what-if-phase-b2.sh`. Aucun workflow B2 n'existe tant qu'un canal
d'import de preuve humaine approuvé n'est pas disponible. Le script vérifie les deployments B1a
et B1b `Succeeded` et la transition live complète. B2 n'est jamais planifié ou scellé avant ces
deux étapes. Chaque script exige
`provisioningState=Succeeded`, valide chaque output Phase A, relit chaque ressource par son ID réel,
compare `clientId`/`principalId`, puis exige exactement zéro ou une FIC conforme par UAMI. Toute
ressource/output absent ou divergent bloque avant son what-if. Le manifeste Phase A approuvé lie le
commit source, les hashes des sources/templates/paramètres, le template ARM compilé et le plan brut.
Le prévol compare son hash approuvé au fichier téléchargé, le `templateHash` du deployment live,
toutes les opérations subscription et imbriquées, puis énumère les role/policy assignments des huit
principals. Seul un replay partiel conforme à B1/B2 est accepté; tout assignment supplémentaire
bloque. B1 passe l'objet Phase A validé comme
paramètre littéral : aucun `principalId` d'assignment ne dépend d'un `reference()`. Son manifeste
indépendant B1a couvre les six roleAssignments RG sans délégation. Le manifeste B1b couvre les
trois launchers, les quatre attributions délégatrices conditionnées et
`certigo-privileged-ci-rbac` en `Audit`, sous identité humaine PIM.
Si ARM omet `principalType` (`null`) dans le payload what-if, B1 ne l'infère qu'après avoir prouvé
que la déclaration correspondante du template ARM compilé contient le littéral
`ServicePrincipal` et que le `principalId` littéral correspond exactement à une UAMI Phase A live.
Le plan normalisé et la provenance `compiled-template+live-uami` sont hashés dans le manifeste;
toute autre valeur, expression dynamique, principal non-UAMI ou preuve manquante reste refusée.
B2 reçoit uniquement le principal de plan et le role definition ID externes littéraux; son
manifeste indépendant couvre les deux assignments externes. Les artifacts B1/B2 conservent le plan
brut, les paramètres, le template compilé, la preuve/binding Phase A et un manifest SHA-256 incluant
le contexte GitHub. Leurs scopes sont comparés après
normalisation stricte aux seuls IDs complets :

```text
/subscriptions/<id>/resourceGroups/rg-certigo-ci/providers/Microsoft.Network/virtualNetworks/vnet-certigo-ci/subnets/snet-runners
/subscriptions/<id>/resourceGroups/rg-certigo-ci/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net
```

Un scope RG, un autre subnet/DNS, un préfixe générique ou une expression non matérialisée est
refusé. Un retry B1 ou B2 peut contenir `NoChange` seulement pour une attribution ou policyAssignment
dont le payload complet correspond au scope, principal, rôle, condition et effet exacts. Le
mélange `Create`/`NoChange` est accepté quand chaque contrat apparaît une seule fois; tout payload
manquant, doublon ou écart est refusé. Chaque plan exige aussi `0 Modify`, `0 Delete`,
`0 Unsupported`, aucun diagnostic et aucune expansion incomplète.

Les deployments ARM imbriqués ne sont pas une échappatoire à l'allowlist. Chaque nom est lié à
son resource ID complet et sensible à la casse : toutes les identités sous
`rg-certigo-identities`, RBAC environnement sous son RG,
réseau partagé sous `rg-certigo-ci` et exécuteur contenu sous `rg-certigo-content`. B2 est un
what-if RG séparé sans deployment ARM imbriqué. Pour `Ignore` ou `NoChange`, le payload B1 doit
contenir le type deployment
exact et un état ARM matérialisé (`provisioningState`, `templateHash` ou `templateLink` non vide).
Les valeurs vides ou composées d'espaces sont également refusées. Un même leaf name sous un autre
RG/subscription, une casse différente ou `properties: {}` est refusé.

Après archivage et approbation humaine distincte des manifestes B1a, B1b et B2, l'admin PIM crée pour
chaque phase un JSON d'approbation hors dépôt contenant `schemaVersion: 1`, `approved: true`,
`phase`, `manifestSha256`, `planSha256`, `sourceCommit` et
`phaseAEvidenceManifestSha256`. Les outils revalident l'état Phase A live, HEAD, sources, template
compilé, paramètres, plan et approval avant toute création. L'admin déploie séparément B1a, B1b
puis B2; un GO B1a n'autorise jamais B1b ou B2 implicitement :

```bash
PHASE_A_EVIDENCE_DIR='<approved-phase-a-artifact>' \
PHASE_A_EVIDENCE_MANIFEST_SHA256='<approved-phase-a-manifest-sha256>' \
PHASE_A_DEPLOYMENT_NAME='<phase-a-deployment>' \
PHASE_B1_EVIDENCE_DIR='<approved-b1-artifact>' \
PHASE_B1_APPROVAL_FILE='<approved-b1.json>' \
PHASE_B1_DEPLOYMENT_NAME='certigo-governance-bootstrap-rbac-<ticket>' \
  bash infra/governance/deploy-phase-b1.sh

# B1b est exclusivement humain PIM.
export PHASE_A_EVIDENCE_DIR='<approved-phase-a-artifact>'
export PHASE_A_EVIDENCE_MANIFEST_SHA256='<approved-phase-a-manifest-sha256>'
export PHASE_A_DEPLOYMENT_NAME='<phase-a-deployment>'
export PHASE_B1B_EVIDENCE_DIR='<private-b1b-evidence>'
bash infra/governance/what-if-phase-b1b.sh

PHASE_B1B_APPROVAL_FILE='<approved-b1b.json>' \
PHASE_B1B_DEPLOYMENT_NAME='certigo-governance-bootstrap-rbac-admin-<ticket>' \
  bash infra/governance/deploy-phase-b1b.sh

# Conserver exactement ces outputs non secrets pour le what-if B2 local :
export PHASE_B1_EVIDENCE_DIR='<approved-b1-artifact>'
export PHASE_B1_EVIDENCE_MANIFEST_SHA256='<approved-b1-manifest-sha256>'
export PHASE_B1_DEPLOYMENT_NAME='certigo-governance-bootstrap-rbac-<ticket>'
export PHASE_B1B_EVIDENCE_DIR='<approved-b1b-artifact>'
export PHASE_B1B_EVIDENCE_MANIFEST_SHA256='<approved-b1b-manifest-sha256>'
export PHASE_B1B_DEPLOYMENT_NAME='certigo-governance-bootstrap-rbac-admin-<ticket>'

PHASE_A_EVIDENCE_DIR='<approved-phase-a-artifact>' \
PHASE_A_EVIDENCE_MANIFEST_SHA256='<approved-phase-a-manifest-sha256>' \
PHASE_A_DEPLOYMENT_NAME='<phase-a-deployment>' \
PHASE_B1_EVIDENCE_DIR="$PHASE_B1_EVIDENCE_DIR" \
PHASE_B1_EVIDENCE_MANIFEST_SHA256="$PHASE_B1_EVIDENCE_MANIFEST_SHA256" \
PHASE_B1_DEPLOYMENT_NAME="$PHASE_B1_DEPLOYMENT_NAME" \
PHASE_B2_EVIDENCE_DIR='<approved-b2-artifact>' \
PHASE_B1B_EVIDENCE_DIR="$PHASE_B1B_EVIDENCE_DIR" \
PHASE_B1B_EVIDENCE_MANIFEST_SHA256="$PHASE_B1B_EVIDENCE_MANIFEST_SHA256" \
PHASE_B1B_DEPLOYMENT_NAME="$PHASE_B1B_DEPLOYMENT_NAME" \
  bash infra/governance/what-if-phase-b2.sh

PHASE_B2_APPROVAL_FILE='<approved-b2.json>' \
PHASE_B2_DEPLOYMENT_NAME='certigo-governance-bootstrap-rbac-external-<ticket>' \
PHASE_A_EVIDENCE_DIR='<approved-phase-a-artifact>' \
PHASE_A_EVIDENCE_MANIFEST_SHA256='<approved-phase-a-manifest-sha256>' \
PHASE_A_DEPLOYMENT_NAME='<phase-a-deployment>' \
PHASE_B1_EVIDENCE_DIR="$PHASE_B1_EVIDENCE_DIR" \
PHASE_B1_EVIDENCE_MANIFEST_SHA256="$PHASE_B1_EVIDENCE_MANIFEST_SHA256" \
PHASE_B1_DEPLOYMENT_NAME="$PHASE_B1_DEPLOYMENT_NAME" \
PHASE_B1B_EVIDENCE_DIR="$PHASE_B1B_EVIDENCE_DIR" \
PHASE_B1B_EVIDENCE_MANIFEST_SHA256="$PHASE_B1B_EVIDENCE_MANIFEST_SHA256" \
PHASE_B1B_DEPLOYMENT_NAME="$PHASE_B1B_DEPLOYMENT_NAME" \
PHASE_B2_EVIDENCE_DIR='<approved-b2-artifact>' \
  bash infra/governance/deploy-phase-b2.sh
```

Les workflows `governance-bootstrap-phase-{a,b}-what-if.yml` utilisent chacun un
`repository_dispatch` dédié, un payload exact et `refs/heads/main`. Ils n'appellent jamais
`deployment create` et échouent tant qu'un admin n'a pas configuré séparément leurs variables
d'Environment. **Cette PR ne configure aucune variable GitHub.** Le workflow contenu reste un
`deployment group what-if`, inchangé.

Déclenchements opérateur après revue PIM :

```bash
gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches \
  -f event_type=governance-bootstrap-phase-a-what-if

jq -c . '<approved-legacy-transition.json>' | tr -d '\n' > transition.payload.json
transition_sha="$(
  node infra/governance/evidence-files.mjs hash transition.payload.json
)"
jq -n \
  --rawfile transition transition.payload.json \
  --arg transitionSha "$transition_sha" \
  --arg deployment 'certigo-governance-bootstrap-identities-<ticket>' \
  --arg manifestSha '<approved-manifest-sha256>' \
  --argjson runId '<phase-a-workflow-run-id>' \
  '{
    event_type: "governance-bootstrap-phase-b-what-if",
    client_payload: {
      legacy_transition_json: $transition,
      legacy_transition_sha256: $transitionSha,
      phase_a_deployment_name: $deployment,
      phase_a_evidence_run_id: $runId,
      phase_a_evidence_manifest_sha256: $manifestSha
    }
  }' |
  gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches --input -
rm transition.payload.json

# B1b et B2 n'ont volontairement aucun workflow workload.
```

Après les deux phases :

1. **Variables GitHub non secrètes.** Reporter les outputs du plan contenu dans
   `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` et `AZURE_SUBSCRIPTION_ID` de l'Environment
   `azure-content-infra-plan`. Aucun secret client n'est créé ou stocké.
2. **Protection de l'Environment.** Limiter
   `azure-content-infra-plan` à la branche `main` et exiger un reviewer. Cette configuration
   GitHub est une opération séparée, non réalisée par la PR.

Après ce bootstrap, `infra/content/main.bicep` s'exécute au scope resource group. Le workflow
utilise exclusivement `az deployment group what-if --resource-group rg-certigo-content` et
refuse toute ressource hors de ce RG. Son plan durable ne crée plus le RG ni le roleDefinition
publisher ; il ne contient que Storage, identités contenu, FIC, private endpoint/DNS zone group
et attributions runtime du stack dédié.

## Ordre exact de migration

Chaque étape est bloquante. Ne jamais retirer un accès avant que son remplacement JIT soit créé,
activé et testé deux fois avec non-lockout. Chaque mutation d'assignment est sérialisée : une seule
assignment à la fois, avec un principal emergency distinct et un principal d'administration de
sécurité maintenus pendant toute la transition. Un second principal contrôlé par le même propriétaire
ne constitue pas un administrateur humain indépendant : il faut soit un tiers/MSP temporaire réellement
indépendant, soit une approbation scellée d'une procédure solo à contrôles compensatoires. Sans l'un de
ces deux contrats, la Phase B reste **NO-GO**. Les rôles larges legacy disparaissent avant Phase B;
seuls les rôles de rollback exacts et expirables peuvent survivre pendant les canaris.

1. **Geler l'état de rollback.** Exporter l'inventaire, les IDs des attributions actuelles,
   les federated credentials et les métadonnées des GitHub Environments. Ne rien retirer.
2. **Créer le remplacement humain JIT.** Créer les eligibilities PIM minimales et bornées au ticket,
   sans modifier encore l'accès legacy.
3. **Tester deux activations et le rollback JIT.** Activer deux fois séparément sous
   MFA/approbation, prouver à chaque fois les opérations administratives attendues et le non-lockout,
   puis tester le rollback. Archiver les deux expirations, conserver le tiers/MSP indépendant ou
   l'approbation scellée du mode solo compensatoire, ainsi qu'un principal emergency distinct, et
   n'appliquer qu'une mutation d'assignment à la fois.
4. **A0 humain.** Exécuter le what-if A0, approuver son manifeste, déployer le template exact et
   archiver ses outputs.
5. **Prévol admin Phase A.** Exécuter `what-if-phase-a.sh`, archiver et approuver le JSON.
6. **Provisionnement Phase A.** Déployer `bootstrap-identities.bicep` en incrémentiel; archiver
   l'output `phaseA`. Vérifier explicitement qu'aucune attribution effective n'existe.
7. **Access review intermédiaire.** Un second reviewer compare les huit principal/client/resource
   IDs, les sept FIC, les six rôles et la policyDefinition à l'output.
8. **Créer le rollback legacy borné.** Avant tout retrait large, créer exactement huit attributions
   temporaires au principal legacy : launcher au scope abonnement; Contributor et runtime writer
   conditionné sur chacun des RG dev/staging/prod; shared-network deployment sur `rg-certigo-ci`.
   Toutes portent un `scheduleInstanceId`, une échéance, un owner et une procédure de rollback
   explicites, au plus tard à la fin du soak approuvé. Les rôles data-plane historiques doivent être
   migrés vers les nouvelles identités ou retirés avant l'étape suivante.
9. **Retirer les rôles larges avant Phase B et tout accès non temporaire.** Retirer les deux assignment IDs inventoriés
   une assignment à la fois : d'abord `User Access Administrator` permanent, puis `Contributor`
   permanent seulement après vérification de ses huit remplacements exact-scope. Retirer aussi tout
   ancien rôle data-plane, relire l'état live, prouver les huit remplacements et valider
   `legacy-transition-contract.mjs`. Si l'activation JIT ou le rollback n'est pas encore prouvé, le
   retrait est interdit. Toute neuvième attribution ou schedule instance bloque.
10. **Prévol B1a.** Exécuter `what-if-phase-b.sh` avec le deployment A et le contrat de transition
   approuvés. Refuser tout rôle large live ou remplacement temporaire manquant.
11. **Provisionnement B1a.** Déployer B1a avec `deploy-phase-b1.sh` après approbation hashée.
12. **Prévol/provisionnement B1b humain.** Exécuter puis approuver `what-if-phase-b1b.sh`; déployer
   `deploy-phase-b1b.sh` sous PIM humain. Aucun workload n'obtient `policyAssignments/write`.
13. **Prévol admin B2.** Sur l'état post-B1a+B1b, exécuter `what-if-phase-b2.sh` et approuver son
   nouveau manifeste séparément.
14. **Provisionnement B2.** Déployer B2 avec `deploy-phase-b2.sh`, puis archiver les 16 assignment
   IDs. Aucun plan B2 antérieur à B1a+B1b n'est réutilisable.
15. **Configuration GitHub.** Créer les variables non secrètes de chaque Environment avec le client
   ID de l'UAMI correspondante.
16. **Préparer l'IaC applicative.** Reporter le principal de la nouvelle UAMI dans
   `ciDeploymentPrincipalId` pour l'environnement canari seulement.
17. **Canari dev.** Prouver what-if sans suppression, déploiement, package, health, no-op, isolation
   staging/prod et impossibilité d'attribuer Contributor/UAA.
18. **Canari staging.** Refaire les mêmes preuves avec approbation et rollback d'artefact.
19. **Production.** Refaire le cycle après preuve staging. Les huit attributions temporaires legacy
   restent bornées par `soakEndsAt`; aucun rôle large ne revient et aucune attribution sans échéance
   n'est conservée.
20. **Migration corrective contenu après #290.** Utiliser uniquement les identités dédiées.
21. **Contrôle data-plane historique.** Confirmer que l'inventaire du principal legacy reste vide de
   tout rôle data-plane; toute réapparition bloque le soak.
22. **Fin du soak.** Retirer toutes les attributions legacy temporaires au plus tard à `soakEndsAt`,
   archiver l'inventaire vide correspondant et ne jamais prolonger implicitement l'échéance.
23. **Fédération historique.** Retirer les credentials historiques, puis désactiver l'application
   seulement après access review.
24. **Policy.** Promouvoir `Audit` vers `Deny` dans une PR et une fenêtre distinctes.

Le fichier de transition est un JSON strict v1 : inventaire scellé, deux assignment IDs larges,
deux tests d'activation JIT séparés avec `nonLockoutVerified: true`, preuve de rollback, horodatages
distincts du retrait UAA puis Contributor, et `changeControl.assignmentChangesSerialized: true`.
`changeControl.administrationMode` vaut `independent-third-party` avec un
`independentAdminOwner` distinct de `operatorOwner`, une éligibilité UAA bornée par
`independentAdminExpiresAt`, ou `approved-solo-compensating-controls` avec un objet
`soloModeControls` complet. Un deuxième principal du même owner ne satisfait jamais le premier mode.
`safetyAdminPrincipalId` et les deux `emergencyPrincipalIds` restent distincts du principal legacy.
Les huit attributions
temporaires portent `scheduleInstanceId`, `createdAt`, `expiresAt`, `owner`,
`rollbackProcedure`, `soakEndsAt` et les hashes de preuve. Les champs absents ou supplémentaires sont
refusés. Le SHA-256 approuvé porte sur les octets exacts du JSON, sans newline ajouté;
`LEGACY_TRANSITION_SHA256` est vérifié avant copie. Le prévol interroge
ensuite les cinq scopes via `roleAssignmentScheduleInstances`, compare IDs, contrats, fenêtres live,
statuts, échéances et chaque `originRoleAssignmentId`, et exige exactement huit attributions liées
aux huit schedule instances sans accès supplémentaire ou permanent. Validation locale du schéma,
sans mutation :

Pour Certigo en contexte unipersonnel, l'acceptation explicite du risque résiduel du mode solo a été
enregistrée le 2026-09-01; elle satisfait uniquement le prérequis de décision. Elle ne fournit aucune
indépendance humaine et ne vaut pas GO opérationnel. `soloModeControls` doit encore prouver, avant
Phase B, une acceptation datée, scopée à l'abonnement/Phase B et non expirée, la séparation des
comptes quotidien/admin, et deux comptes emergency-access cloud-only de type `Member`, Global
Administrator actifs en permanence. Les domaines UPN secondaires `*.onmicrosoft.com` sont admis :
la gate découvre le domaine issuer du tenant et exige pour chaque compte `accountEnabled: true`,
`creationType` différent de `Invitation`, `onPremisesSyncEnabled` différent de `true` et un issuer
identique à celui du tenant. Une présence, un UPN secondaire ou `userType: Member` seuls ne prouvent
pas la qualification cloud-native. Chaque preuve scelle séparément `tenantId` et `objectId`,
réconcilie l'issuer/sign-in identifier, confirme l'accès management et refuse de traiter un object ID
comme tenant ID. Les deux comptes doivent appartenir au tenant management exact de la subscription;
un Global Administrator d'un tenant CIAM distinct ne prouve jamais le non-lockout RBAC/PIM de la
subscription. L'observation read-only corrigée confirme un compte CIAM Member actif sur un domaine
UPN secondaire, mais avec zéro authentication method/default/preferred MFA : il est présent, pas
qualifié ni testé pour Phase B. Les recherches partielles dans l'ancien tenant management ne
prouvent pas l'absence de comptes lorsque la visibilité Entra est incomplète : leur état est
`UNKNOWN/BLOCKED`, jamais « absent ». Cette ancienne dépendance à un Global Administrator
professionnel est interdite pour la cible exécutable. Deux comptes qualifiés dans le tenant
personnel explicitement sélectionné restent obligatoires, sans création ou enrôlement automatique. Un
utilisateur guest interne ou externe, notamment un compte B2B `#EXT#`, ne peut pas
enregistrer de passkey FIDO2 et n'est jamais une voie admissible pour ces comptes; un échec
Authenticator/My Security Info sur ce parcours guest ne doit pas conduire à affaiblir la gate. Ces
comptes recovery restent séparés du compte admin mais sont explicitement
contrôlés par le même humain : ils ne créent ni indépendance humaine ni second approbateur.
Deux credentials distincts et testés sont obligatoires : deux FIDO2/CBA, ou deux passkeys
Authenticator device-bound avec attestations/AAGUID distincts sur deux appareils distincts. Un
téléphone unique est refusé. WHfB ne compte qu'après preuve d'admissibilité policy et test réel.
Les méthodes de récupération sont stockées séparément; les exclusions Conditional Access sont
bloquantes et tout usage déclenche une alerte.
Un drill de récupération et les tests non-lockout/rollback sont renouvelés au plus tard tous les
90 jours. Chaque contrôle a une preuve SHA-256 immuable. Tant qu'un seul contrôle ou test manque,
la Phase B reste **NO-GO**.

```bash
node infra/governance/legacy-transition-contract.mjs \
  '<approved-legacy-transition.json>' '<phase-a-output.json>'
```

## Preuves minimales avant retrait des rôles abonnement

Pour chaque environnement :

- SHA du commit et run GitHub approuvé ;
- clientId/principalId réellement connecté, lu via `az account show` sans jeton ;
- `what-if` archivé sans suppression ;
- deployment ARM réussi avec le nouveau principal ;
- attributions data-plane au scope exact ;
- upload et lecture du package privés ;
- smoke tests live/readiness ;
- second déploiement no-op ;
- test négatif sur un autre RG ;
- test négatif d'une attribution privilégiée ;
- procédure de rollback exécutée au moins en dev puis staging.

Sans les dix preuves pour prod, la migration s'arrête. Elle ne réintroduit jamais les rôles larges
abonnement; le rollback reste limité aux huit attributions temporaires avec échéance approuvée.

## PIM et break-glass

- Les rôles capables de gérer `roleAssignments` sont **éligibles**, pas permanents, avec MFA,
  justification, durée courte, approbation et alerte PIM.
- Deux comptes break-glass cloud-only sont conservés hors usage quotidien, avec authentification
  résistante au phishing, surveillance et test périodique. Ils ne sont jamais une identité CI.
- L'identité OIDC ne reçoit ni Owner, ni UAA, ni RBAC Admin sans condition.
- Toute modification d'attribution se fait sous ticket, avec export avant/après et journal PIM.

## Runners : automatisation sûre

L'automatisation de puissance est **bloquée dans l'état actuel**. Avant de lui donner un chemin
mutable :

1. séparer les pools/VMSS `certigo-pr` et `certigo-trusted`, avec labels, frontières
   d'identité et sous-réseaux mutuellement exclusifs ;
2. supprimer le scale-in CPU, qui ne connaît pas l'état `busy` GitHub ;
3. utiliser une identité d'automatisation avec uniquement `read`, `start/action`,
   `deallocate/action` aux scopes exacts des deux pools ;
4. acquérir un lease Blob dédié avant toute opération, avec un seul contrôleur autorisé,
   une génération de fencing positive et une écriture d'état compare-and-swap ;
5. pour déallouer, exiger une quiet period continue de **5 minutes** avec `busy=false` et
   zéro run `queued/in_progress`; toute activité remet le compteur à zéro ;
6. après ces 5 minutes, exiger deux gardes distinctes sur l'inventaire complet, puis une garde
   finale `busy=false`, zéro job actif/en file et révision d'état inchangée; désallouer le
   pilote PR avant le primaire trusted, **un pool à la fois**, et ne jamais lancer deux
   déallocations concurrentes ;
7. au démarrage, attendre l'état Azure `running`, l'enregistrement GitHub `online`, puis
   restaurer le label exclusif ;
8. armer le réallumage après chaque scale-in : toute nouvelle activité avant stabilisation
   demande le redémarrage de la seule capacité gérée affectée; conserver un timeout qui
   relâche le lease et ne force jamais la déallocation.

Les éléments versionnés restent tous read-only :

- `reconcile-drift.mjs` compare le VMSS/SKU/autoscale/labels live au modèle du dépôt ;
- `capacity-controller.config.json` fixe `enabled=false`, le trigger `workflow_job`, la
  quiet period de 300 s, les deux gardes et la cible de pilote ultérieur
  `6 certigo-pr + 2 certigo-trusted`; son état v3 lie les IDs exacts f55/pilote, garde le
  runner 26 et la VM `4153d1dd` hors scope et interdit les VMs `22f7fb52`/`4596a9d5`,
  sans règle générique qui masquerait une
  nouvelle VM non réconciliée ;
- `capacity-controller.mjs` réduit un snapshot d'événements et produit uniquement le
  prochain plan ;
- `capacity-plan.sh` collecte l'inventaire, affiche le drift puis le plan, sans appeler
  `start`, `deallocate`, `update`, `create` ou `delete` ;
- `lifecycle-preflight.sh` encode les bloqueurs de sécurité du pool actuel.

Le listener `workflow_job` final doit être un webhook/GitHub App vers un contrôleur Azure
externe. Il ne doit pas être un workflow auto-déclenché par `workflow_job`, afin d'éviter
qu'un job du contrôleur génère lui-même une nouvelle boucle d'événements.

| Mode | Condition | Capacité agrégée cible |
|---|---|---:|
| `idle` | file vide, zéro actif, aucun runner `busy` | 0 PR + 0 trusted |
| `normal` | demande présente sous les seuils boost | 1 PR + 1 trusted |
| `boost` | file ≥ 2, attente la plus ancienne ≥ 300 s, ou slots normaux occupés + file | 6 PR + 2 trusted |

Un événement `workflow_job: waiting` (approbation d'Environment) est mémorisé mais ne
consomme pas de runner et ne déclenche donc pas de boost.

`6 + 2` est une **limite de pilote ultérieur**, pas un maximum de production définitif.
Chaque plan ne propose qu'un incrément de `1` dans une seule classe et ne peut pas dépasser
la cible de pilote de cette classe. Un scale-in reste impossible tant que la quiet period
resettable de 5 minutes et les deux gardes ne sont pas terminées, que les deux pools
exclusifs ne sont pas prouvés ou que le lease distribué n'est pas détenu. La séparation
des labels, des frontières d'identité **et des sous-réseaux** est un prérequis, jamais une
action implicite du contrôleur.

Le contrôleur découvre à chaque plan les VM et runners réels et les réconcilie par nom. Il
ne suppose jamais deux IDs fixes. `physicalManagedCapacity` compte seulement les paires
gérées, `currentCapacity` seulement ces paires alimentées, et `usableCapacity` uniquement
les paires alimentées dont le runner est `online`. Les sorties distinguent explicitement
`absentRunners`, `managedMachineNames` et `externalVirtualMachines`; un runner stale et une
VM externe ne s'annulent donc pas.

Les fichiers d'état référencés par `CAPACITY_STATE_FILE` ou `LIFECYCLE_STATE_FILE` sont des
snapshots read-only fournis par un orchestrateur externe. Les scripts affichent `nextState`
mais ne l'écrivent jamais. Avant toute mutation future, l'orchestrateur devra persister ce
`nextState` par compare-and-swap sur `mutationFence.requiredStateRevision`, sous la même
`mutationFence.leaseGeneration`; un échec CAS, un lease renouvelé ou une révision plus récente
impose une nouvelle quiet period complète. Seule une future PR d'activation pourra définir
la persistance, l'acquittement du réarmement et le chemin mutable. Tant que `enabled=false`,
`lifecycle-preflight.sh` bloque aussi bien `start` que `deallocate` et n'arme aucune action.

La passation opérationnelle externe v3 possède temporairement uniquement les IDs exacts
`f55d176e` et `bbf83c5c`; le runner 26 et la VM 415 restent hors scope. Elle maintient les
deux pendant l'activité, applique une quiet period coordonnée de 5 minutes resettable,
contrôle 2 + garde finale sous la même génération de lease, désalloue le pilote puis le
primaire et réarme les capacités exactes supprimées si une activité apparaît. Ce processus
hors dépôt n'active pas le contrôleur versionné : `enabled=false` reste le contrat de cette PR.

### Reconstruction de redondance avant activation

1. conserver `enabled=false` et suspendre tout scale-in CPU ;
2. archiver les inventaires Azure, VMSS, GitHub, disques/NIC et l'erreur
   `ResourceNotFound` de `22f7fb52` ;
3. ne supprimer ni le runner stale `22f7fb52-Certigo`, ni la VM intacte `4153d1dd` pendant
   l'analyse de cause et la décision d'adoption/reconstruction ;
4. faire approuver le modèle cible : deux pools/VMSS, frontières d'identité distinctes,
   sous-réseaux distincts, un label exclusif par pool et au moins deux zones ;
5. reconstruire ou adopter une seconde instance via une fenêtre opérateur, puis
   l'enregistrer avec son identité et son label exclusifs ;
6. prouver deux paires VM↔runner `online`, les probes de santé, la file drainée et un drill
   de perte d'un pool ;
7. retirer l'enregistrement stale seulement après cette preuve et approbation ;
8. activer le contrôleur dans une PR/fenêtre séparée; le présent livrable reste `off`.

Prévisualisation sans mutation :

```bash
export AZURE_SUBSCRIPTION_ID=b8952c8c-8f72-469d-99cd-ac906da4e2fc
bash infra/ci-runner/capacity-plan.sh
```

### Rollback runner

Si une opération future échoue :

1. ne pas poursuivre vers le second pool ;
2. démarrer le pool déjà affecté, attendre `running` puis `online` ;
3. restaurer son unique label de confiance ;
4. remettre la configuration autoscale précédente seulement si elle ne contient aucun
   scale-in non conscient des jobs ;
5. relâcher le lease et archiver les états Azure/GitHub ;
6. déclencher un probe de santé et le drill de résilience avant de reprendre.

## Rollback et access review du bootstrap

- **Échec/rejet Phase A** : ne jamais lancer B. Conserver les UAMI/rôles sans attribution pour
  investigation; ils n'accordent aucun accès. Corriger en avant et refaire le what-if A. Toute
  suppression éventuelle est une opération admin séparée, inventoriée et approuvée.
- **Échec/rejet Phase B avant deployment** : aucune mutation n'a eu lieu. Rejeter le plan, corriger
  en avant et refaire la preuve live Phase A.
- **Rollback après Phase B** : exporter d'abord les 16 assignment IDs et l'inventaire d'accès.
  Un admin PIM retire uniquement ces IDs, en ordre inverse (policyAssignment, joins externes,
  exécuteur contenu, réseau partagé, writers/contributors environnement, launchers). Ne pas
  supprimer les identités/rôles tant que les attributions ne sont pas prouvées absentes.
- **Access review** : deux reviewers comparent après A les huit identities et sept FIC aux outputs,
  puis après B les 15 roleAssignments (scope, principal, role, condition) et la policyAssignment.
  Archiver les exports avant/après, le ticket, les approbations PIM et les deux JSON what-if.

Le rollback ne réintroduit jamais automatiquement Owner, Contributor abonnement ou UAA. Avant
Phase B, les accès larges historiques sont déjà retirés; seuls les huit accès exacts, scellés et
expirables restent disponibles jusqu'au terme approuvé du soak.

## Rollback OIDC/RBAC

### Avant retrait de l'ancienne identité

1. restaurer les `AZURE_*` de l'ancienne application dans l'Environment concerné ;
2. restaurer son `ciDeploymentPrincipalId` ;
3. relancer `what-if`, puis le dernier artefact connu sain ;
4. conserver les nouvelles UAMI pour investigation; ne rien supprimer.

Ce rollback reste possible uniquement grâce aux attributions temporaires exactes encore valides et
au remplacement humain JIT testé; il ne dépend d'aucun rôle large abonnement.

### Après retrait

Le rollback automatique vers des rôles abonnement larges est interdit. Un admin PIM décide :

- correction en avant de la nouvelle identité, option préférée ;
- attribution temporaire et étroitement scopée sous ticket ;
- break-glass seulement si PIM est indisponible et l'impact production l'exige.

Toute attribution temporaire possède une échéance, une preuve de retrait et une revue d'incident.

## Compatibilité des PR et du contenu

| Surface | Verdict |
|---|---|
| #290 stockage contenu | Compatible : stack et RG dédiés, deux identités publisher propres, rôles conteneur custom. La policy ne vise que les rôles privilégiés built-in au scope abonnement. |
| #296 suppression de compte | Compatible : ses secrets Graph restent dans Key Vault; `Key Vault Secrets User` est dans l'allow-list du writer conditionnel. |
| #297 onboarding | Aucun fichier infra, workflow cloud ou contenu en recouvrement. |
| Catalogue `content/` | Aucun fichier modifié; validation de contenu inchangée et obligatoire. |
| `ci-infra` | Ajoute un step dédié au moindre privilège. Les steps `content-storage` de #290 et account-deletion de #296 restent indépendants. |

Les merges restent indépendants. En cas de résolution manuelle sur `ci-infra`, conserver les
trois steps dédiés ajoutés par #290, #296 et cette PR.

## Références

- [Azure RBAC best practices](https://learn.microsoft.com/azure/role-based-access-control/best-practices)
- [Conditions on role assignments in ARM/Bicep](https://learn.microsoft.com/azure/role-based-access-control/conditions-role-assignments-template)
- [Workload identity federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/actions/concepts/security/openid-connect)
