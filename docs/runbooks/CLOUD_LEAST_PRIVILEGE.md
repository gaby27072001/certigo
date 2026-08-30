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

`lifecycle-preflight.sh` ne possède volontairement aucun chemin `apply`. Il retourne `2` dès
qu'une déallocation serait dangereuse et, dans cette PR, pour toute demande puisque le
feature flag reste `off`.

## Inventaire read-only consolidé au 20 août 2026

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
sont historiques et constituent le finding à résorber, mais restent indispensables au rollback
jusqu'à la fin des preuves.

### Runners

L'état live ne correspond plus aux anciennes VM autonomes documentées :

| Élément | État observé |
|---|---|
| Compute géré | `f55d176e` dans `vmss-certigo-runner-zonal` zone 2; pilote `bbf83c5c` dans `vmss-certigo-pr-pilot-z1` zone 1 |
| Inventaire Azure courant | `f55d176e` et `bbf83c5c` running; `4153d1dd` externe/deallocated; `22f7fb52` absent; essai `4596a9d5` absent/interdit |
| Autoscale | activé, minimum `2`, défaut `2`, maximum `4` |
| Scale-out | CPU moyenne > 70 % pendant 10 min |
| Scale-in | CPU moyenne < 20 % pendant 45 min — **non conscient des jobs GitHub** |
| Inventaire GitHub | runner `27` `f55d176e-Certigo` online/labels doubles; runner `28` `certigo-prIVJAN8` online, PR-only; runner `26` `22f7fb52-Certigo` offline/stale et hors scope |
| Cloisonnement | le pilote est sans identité, sur `vnet-certigo-pr-pilot/snet-pr-runners`; `f55d176e` conserve UAMI + `snet-runners` mais ses labels doubles restent **bloquants** |
| Capacité réellement réconciliée | **2 instances gérées/online** : `f55d176e` et `bbf83c5c`; `4153d1dd` reste externe |

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
- **Phase B — `bootstrap-rbac`** : ne crée ni identité, ni rôle, ni policyDefinition. Elle
  consomme les huit UAMI, les six rôles, la policyDefinition et les six RG en `existing`, puis
  crée exactement les 13 attributions internes, les deux attributions externes et l'unique
  policyAssignment en `Audit`.

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

Après archivage et approbation humaine du JSON, l'admin PIM peut exécuter séparément, hors workflow :

```bash
az deployment sub create \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "certigo-governance-bootstrap-identities-<ticket>" \
  --location westeurope \
  --template-file infra/governance/bootstrap-identities.bicep \
  --parameters infra/params/bootstrap-identities.bicepparam

az deployment sub show \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "certigo-governance-bootstrap-identities-<ticket>" \
  --query properties.outputs.phaseA.value \
  --output json > phase-a-output.json
chmod 600 phase-a-output.json
```

Le fichier d'output est un artefact de changement contrôlé, jamais committé.

### What-if Phase B

La Phase B ne peut démarrer qu'avec le nom du deployment Phase A approuvé :

```bash
export AZURE_SUBSCRIPTION_ID='<subscription-uuid>'
export PHASE_A_DEPLOYMENT_NAME='certigo-governance-bootstrap-identities-<ticket>'
bash infra/governance/what-if-phase-b.sh
```

Le script exige `provisioningState=Succeeded`, valide chaque output, relit chaque ressource par son
ID réel, compare `clientId`/`principalId`, puis exige exactement zéro ou une FIC conforme par UAMI.
Toute ressource/output absent ou divergent bloque avant le what-if. Le validateur B accepte
seulement les 15 roleAssignments exacts et `certigo-privileged-ci-rbac` en `Audit`, plus leurs
deployments ARM attendus. Les deux scopes externes sont comparés après normalisation stricte aux
seuls IDs complets :

```text
/subscriptions/<id>/resourceGroups/rg-certigo-ci/providers/Microsoft.Network/virtualNetworks/vnet-certigo-ci/subnets/snet-runners
/subscriptions/<id>/resourceGroups/rg-certigo-ci/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net
```

Un scope RG, un autre subnet/DNS, un préfixe générique ou une expression non matérialisée est
refusé. Un retry B peut contenir `NoChange` seulement pour une attribution ou policyAssignment
dont le payload complet correspond au scope, principal, rôle, condition et effet exacts. Le
mélange `Create`/`NoChange` est accepté quand chaque contrat apparaît une seule fois; tout payload
manquant, doublon ou écart est refusé. La Phase B exige aussi `0 Modify`, `0 Delete`,
`0 Unsupported`.

Les deployments ARM imbriqués ne sont pas une échappatoire à l'allowlist. Chaque nom est lié à
son resource ID complet et sensible à la casse : toutes les identités sous
`rg-certigo-identities`, RBAC environnement sous son RG,
réseau partagé sous `rg-certigo-ci`, exécuteur contenu sous `rg-certigo-content` et joins externes
sous `rg-certigo-ci`. Pour `Ignore` ou `NoChange`, le payload doit contenir le type deployment
exact et un état ARM matérialisé (`provisioningState`, `templateHash` ou `templateLink` non vide).
Les valeurs vides ou composées d'espaces sont également refusées. Un même leaf name sous un autre
RG/subscription, une casse différente ou `properties: {}` est refusé.

Après archivage et approbation humaine du second JSON, l'admin PIM peut déployer séparément :

```bash
az deployment sub create \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "certigo-governance-bootstrap-rbac-<ticket>" \
  --location westeurope \
  --template-file infra/governance/bootstrap-rbac.bicep \
  --parameters phaseA=@phase-a-output.json
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

gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches \
  -f event_type=governance-bootstrap-phase-b-what-if \
  -F 'client_payload[phase_a_deployment_name]=certigo-governance-bootstrap-identities-<ticket>'
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

Chaque étape est bloquante. Ne jamais anticiper le retrait de l'ancienne identité.

1. **Geler l'état de rollback.** Exporter l'inventaire, les IDs des attributions actuelles,
   les federated credentials et les métadonnées des GitHub Environments. Ne rien retirer.
2. **Prévol admin Phase A.** Activer via PIM l'ensemble minimal permettant RG, UAMI/FIC,
   custom roles et policyDefinition. Exécuter `what-if-phase-a.sh`, archiver et approuver le JSON.
3. **Provisionnement Phase A.** Déployer `bootstrap-identities.bicep` en incrémentiel; archiver
   l'output `phaseA`. Vérifier explicitement qu'aucune attribution effective n'existe.
4. **Access review intermédiaire.** Un second reviewer compare les huit principal/client/resource
   IDs, les sept FIC, les six rôles et la policyDefinition à l'output. Il confirme que la Phase A
   n'accorde aucun accès.
5. **Prévol admin Phase B.** Exécuter `what-if-phase-b.sh` avec le deployment A approuvé. Refuser
   tout `Modify/Delete/Unsupported`, scope générique ou principal/role/condition divergent.
6. **Provisionnement Phase B.** Déployer `bootstrap-rbac.bicep` en incrémentiel seulement après
   approbation distincte du plan B. Archiver les 16 assignment IDs créés.
7. **Configuration GitHub.** Créer les `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` et
   `AZURE_SUBSCRIPTION_ID` au niveau de chaque Environment. Le client ID doit être celui de
   l'UAMI correspondante. Garder la configuration historique disponible pour rollback.
8. **Préparer l'IaC applicative.** Les RG sont désormais `existing`; leur création et MCSB/
   Defender sortent du chemin applicatif. Reporter le principal de la nouvelle UAMI dans
   `ciDeploymentPrincipalId` pour l'environnement canari seulement.
9. **Canari dev.** Avec `dev` approuvé : `what-if` sans suppression, déploiement infra,
   upload/download du package, OneDeploy, `/health/live`, `/health/ready`, puis second
   déploiement no-op. Prouver aussi l'échec d'accès à staging/prod et l'impossibilité
   d'attribuer Contributor/UAA.
10. **Canari staging.** Refaire les mêmes preuves avec approbation et rollback d'artefact.
   Aucun accès dev/prod ne doit être hérité.
11. **Production.** Refaire le cycle après fenêtre de changement et preuve staging du même
   artefact. Conserver l'ancienne identité et ses rôles pendant au moins deux déploiements
   prod réussis et la durée de soak approuvée.
12. **Migration corrective contenu après #290.** Bootstrapper d'abord la gouvernance et les
    protections de l'Environment, puis exécuter le what-if resource-group. Utiliser les identités
    public/answer-key et l'identité de plan dédiées; ne jamais réutiliser une identité applicative.
13. **Retrait data-plane historique.** Un admin PIM retire, environnement par environnement,
    les anciens Blob Data Contributor/Delegator seulement après preuve du nouveau principal.
14. **Retrait abonnement historique.** Quand dev, staging, prod et contenu ont leurs preuves,
    l'admin PIM retire `Contributor` puis `User Access Administrator` du principal
    `15d2...4706`. Vérifier entre les deux opérations que le nouveau chemin reste vert.
15. **Fédération historique.** Après le soak final, retirer les credentials `main`,
    `workflow_dispatch`, puis `dev/staging/prod` de l'ancienne application. Désactiver ou
    supprimer l'application seulement après access review.
16. **Policy.** Résoudre toutes les non-conformités et exemptions approuvées, puis promouvoir
    `Audit` vers `Deny` dans une PR et une fenêtre distinctes.

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

Sans les dix preuves pour prod, les rôles abonnement historiques restent en place.

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

Le rollback ne réintroduit jamais automatiquement Owner, Contributor abonnement ou UAA. Les accès
historiques restent inchangés jusqu'aux canaris et au soak décrits ci-dessous.

## Rollback OIDC/RBAC

### Avant retrait de l'ancienne identité

1. restaurer les `AZURE_*` de l'ancienne application dans l'Environment concerné ;
2. restaurer son `ciDeploymentPrincipalId` ;
3. relancer `what-if`, puis le dernier artefact connu sain ;
4. conserver les nouvelles UAMI pour investigation; ne rien supprimer.

Ce rollback est immédiat parce que les rôles historiques n'ont pas encore été retirés.

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
