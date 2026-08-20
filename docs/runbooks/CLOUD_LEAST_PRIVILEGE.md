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
bash infra/governance/what-if.sh
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
| Inventaire GitHub | runner `27` `f55d176e-Certigo` online/labels doubles; runner `28` `certigo-prIVJAN8` online, PR-only; `22f7fb52-Certigo` offline/stale |
| Cloisonnement | le pilote est sans identité, sur `vnet-certigo-pr-pilot/snet-pr-runners`; `f55d176e` conserve UAMI + `snet-runners` mais ses labels doubles restent **bloquants** |
| Capacité réellement réconciliée | **2 instances gérées/online** : `f55d176e` et `bbf83c5c`; `4153d1dd` reste externe |

Le premier snapshot avait vu trois VM, avant le scale-in CPU. L'état consolidé prouve qu'un
simple comptage « VM Azure / runners GitHub » est faux. La réconciliation explicite classe
`22f7fb52-Certigo` comme **absent**, les bindings exacts `f55d176e`/runner `27` et
`bbf83c5c`/runner `28` comme **gérés**, et `4153d1dd` comme **externe**. Externe ne
signifie ni orpheline ni adoptable : cette VM est
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
| Administration RBAC | PIM JIT pour l'humain; comptes break-glass contrôlés, jamais utilisés par CI |

Le rôle conditionnel peut seulement créer les rôles nécessaires aux modules actuels :
Blob Data Contributor/Owner/Delegator, Queue/Table Data Contributor, Monitoring Metrics
Publisher, Key Vault Secrets User, Cognitive Services OpenAI User et Log Analytics Reader.
Il ne peut ni créer Owner/Contributor/UAA, ni supprimer une attribution.

## Ordre exact de migration

Chaque étape est bloquante. Ne jamais anticiper le retrait de l'ancienne identité.

1. **Geler l'état de rollback.** Exporter l'inventaire, les IDs des attributions actuelles,
   les federated credentials et les métadonnées des GitHub Environments. Ne rien retirer.
2. **Prévol admin.** Un administrateur active via PIM un rôle `Owner` ou l'ensemble minimal
   permettant identités, custom roles, policy et role assignments. Il exécute uniquement
   `infra/governance/what-if.sh` et archive le JSON.
3. **Revue du plan.** Refuser tout `Delete`, tout scope hors des quatre RG Certigo, tout droit
   Compute dans le rôle réseau, tout wildcard ou droit RBAC delete.
4. **Provisionnement gouvernance approuvé.** Dans une fenêtre séparée de cette PR, l'admin
   déploie `infra/governance/main.bicep` en mode incrémentiel. Cela ajoute les trois UAMI,
   custom roles, attributions cibles et la policy en `Audit`; cela ne retire rien.
5. **Configuration GitHub.** Créer les `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` et
   `AZURE_SUBSCRIPTION_ID` au niveau de chaque Environment. Le client ID doit être celui de
   l'UAMI correspondante. Garder la configuration historique disponible pour rollback.
6. **Préparer l'IaC applicative.** Les RG sont désormais `existing`; leur création et MCSB/
   Defender sortent du chemin applicatif. Reporter le principal de la nouvelle UAMI dans
   `ciDeploymentPrincipalId` pour l'environnement canari seulement.
7. **Canari dev.** Avec `dev` approuvé : `what-if` sans suppression, déploiement infra,
   upload/download du package, OneDeploy, `/health/live`, `/health/ready`, puis second
   déploiement no-op. Prouver aussi l'échec d'accès à staging/prod et l'impossibilité
   d'attribuer Contributor/UAA.
8. **Canari staging.** Refaire les mêmes preuves avec approbation et rollback d'artefact.
   Aucun accès dev/prod ne doit être hérité.
9. **Production.** Refaire le cycle après fenêtre de changement et preuve staging du même
   artefact. Conserver l'ancienne identité et ses rôles pendant au moins deux déploiements
   prod réussis et la durée de soak approuvée.
10. **Contenu.** Après merge et preuve séparée de #290, utiliser ses identités public/
    answer-key et son identité de plan. Ne jamais réutiliser une identité applicative.
11. **Retrait data-plane historique.** Un admin PIM retire, environnement par environnement,
    les anciens Blob Data Contributor/Delegator seulement après preuve du nouveau principal.
12. **Retrait abonnement historique.** Quand dev, staging, prod et contenu ont leurs preuves,
    l'admin PIM retire `Contributor` puis `User Access Administrator` du principal
    `15d2...4706`. Vérifier entre les deux opérations que le nouveau chemin reste vert.
13. **Fédération historique.** Après le soak final, retirer les credentials `main`,
    `workflow_dispatch`, puis `dev/staging/prod` de l'ancienne application. Désactiver ou
    supprimer l'application seulement après access review.
14. **Policy.** Résoudre toutes les non-conformités et exemptions approuvées, puis promouvoir
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
4. acquérir un lease Blob dédié avant toute opération, avec un seul contrôleur autorisé ;
5. pour déallouer, exiger une quiet period continue de **5 minutes** avec `busy=false` et
   zéro run `queued/in_progress`; toute activité remet le compteur à zéro ;
6. après ces 5 minutes, exiger deux gardes distinctes sur l'inventaire complet, puis traiter
   **un pool à la fois**; revalider avant le second pool et ne jamais lancer deux
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
  `6 certigo-pr + 2 certigo-trusted`; son état v3 lie les IDs exacts f55/pilote, exclut
  `4153d1dd` et interdit `22f7fb52`/`4596a9d5`, sans règle générique qui masquerait une
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
mais ne l'écrivent jamais. Seule une future PR d'activation pourra définir la persistance,
l'acquittement du réarmement et le chemin mutable. Tant que `enabled=false`,
`lifecycle-preflight.sh` bloque aussi bien `start` que `deallocate` et n'arme aucune action.

La passation opérationnelle externe v3 possède temporairement uniquement les IDs exacts
`f55d176e` et `bbf83c5c`. Elle maintient les deux pendant l'activité, applique une quiet
period coordonnée de 5 minutes resettable, contrôle 2 + garde finale, puis réarme la capacité
exacte supprimée si une course apparaît. Ce processus hors dépôt n'active pas le contrôleur
versionné : `enabled=false` reste le contrat de cette PR.

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
