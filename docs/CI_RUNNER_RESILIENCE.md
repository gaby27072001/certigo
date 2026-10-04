# Résilience des runners GitHub Actions

## Objectif et architecture

Les workflows Linux ciblent deux classes de confiance fixes et jamais un nom de machine :

```json
["self-hosted", "Linux", "X64", "certigo-pr"]
["self-hosted", "Linux", "X64", "certigo-trusted"]
```

La **cible** impose un pool `certigo-pr` sans identité/secrets et un pool
`certigo-trusted` pour les gates agrégées sans source PR et les opérations
release/déploiement. Les labels, frontières d'identité et sous-réseaux doivent être
mutuellement exclusifs :

- les PR de fork ne peuvent pas exécuter de code sur les runners persistants ;
- les PR internes n'obtiennent ni environnement, ni secret, ni identité Azure ;
- les déploiements et releases conservent leurs environnements (`dev`, `staging`,
  `prod`, `beta`, `github-pages`) et leurs approbations ;
- les runners hébergés par GitHub sont durablement indisponibles ; aucun fallback n'est
  configuré ou accepté.

## Capacité et stratégie de cycle de vie

L'inventaire read-only consolidé au **4 septembre 2026** constate deux pools :

| Pool | VMSS | Capacité | Instances | Zone(s) | Runners GitHub | Labels |
|---|---|---|---|---|---|---|
| `certigo-pr` | `vmss-certigo-pr-pilot-z1` | 1 | `bbf83c5c` | 1 | ID 28 `certigo-prIVJAN8` | `certigo-pr`, `certigo-pr-pilot` |
| `certigo-trusted` | `vmss-certigo-runner-zonal` | 2 | `f55d176e`, `be505fa1` | 2 et 1 | ID 27, ID 29 | `certigo-trusted`, `azure`, `vmss`, `zonal`, `certigo` |

**Les labels sont strictement disjoints** : aucun runner ne porte à la fois `certigo-pr`
et `certigo-trusted`. La cible de séparation est donc **atteinte**; l'ancien constat du
20 août 2026 (« labels doubles, migration bloquée ») est caduc. Le scale-in CPU ignore
toujours l'état GitHub `busy`, et le contrôleur versionné reste `enabled=false`.

Les trois instances sont liées explicitement dans
`infra/ci-runner/capacity-controller.config.json`. Le runner 26 (`22f7fb52-Certigo`) et la
VM `4153d1dd` restent **hors scope**; `4596a9d5` reste interdite. Toute VM du VMSS sans
binding est **non classée** et bloque le plan — c'est précisément le contrôle qui manquait
à `be505fa1` avant le 4 septembre 2026.

> 📅 **État au 2026-09-25 — le pool PR ne compte plus que ses quatre instances utiles.**
> Mesuré par `az vm list -g rg-certigo-ci -d` et `gh api .../actions/runners` :
> `5275ea21`/ID 31, `94bad106`/ID 32, `1a6deaa2`/ID 33, `6e3abce4`/ID 34, créées le
> 2026-09-14, liées dans `managedRunnerBindings` avec les deux instances trusted. Les sept
> instances retirées sans runner GitHub (`2c1eeb41`, `3601055e`, `765cf6af`, `7d3001c2`,
> `a14700a3`, `bbf83c5c`, `d8d42366`) ont été **supprimées le 2026-09-25**, avec leurs disques
> et leurs cartes réseau (voir « Suppression des sept instances retirées — 2026-09-25 »). Leurs
> noms restent dans `forbiddenVirtualMachines` : inoffensifs une fois absents, ils empêchent
> qu'une instance du même nom soit un jour reprise sans revue. Le tableau ci-dessus reste
> l'état du 4 septembre. Invalidé par tout ajout, remplacement ou suppression d'instance.

> 🔒 **Le pool trusted n'est pas seulement « celui qui exécute les gates ».**
> `vmss-certigo-runner-zonal` vit dans `vnet-certigo-ci/snet-runners` (10.42.1.0/24), et la
> zone DNS privée `privatelink.blob.core.windows.net` est liée à `vnet-certigo-ci`, `-dev`,
> `-staging` et `-prod` — **mais pas** à `vnet-certigo-pr-pilot`. Le pool PR est donc
> volontairement isolé du stockage à private endpoint. **Le pool trusted est le seul à
> pouvoir joindre les ressources à private endpoint.** Une capacité trusted réduite à un
> seul runner est par conséquent un risque de **disponibilité** pour les opérations
> privilégiées de publication, pas seulement un risque de débit de merge.
>
> Ces mêmes instances portent aussi, sous le label `certigo-ci`, les agents du dépôt
> `certigo-content` : la restauration de la zone 1 a donc rétabli **l'unique chemin réseau
> vers le stockage à private endpoint**, et pas seulement du débit de merge. Voir la note
> sur `certigo-ci` plus bas.

## Contrainte de plateforme : déallocation nocturne non négociable

`MCAPSGovernance-AutomationApp` — appId `a1a9c5b6-7a4f-4288-89ab-6805873f65d1`, objet
`da847d8c-ee71-44de-b462-6775e7d649a7`, tenant propriétaire
`975f013f-7f24-47e8-a7d3-abc4752bf346` — **désalloue toutes les VM de `rg-certigo-ci`
chaque nuit vers 00:46–00:49 UTC**. Le comportement est observé de façon continue dans
l'Activity Log depuis au moins le 30 juin 2026 (un principal antérieur,
`7355f99c-0211-455d-aa02-4a559687ae60`, tenait le même rôle avant fin août).

Ce principal détient **`Owner` au scope du management group
`896a9463-4bb5-462e-b7b5-2e525d3e1a03`**, c'est-à-dire au-dessus de la subscription.

### La déallocation est-elle négociable ? Réponse : non, pas depuis cette subscription

Vérifications effectuées, toutes négatives :

| Piste d'exemption | Résultat |
|---|---|
| Assignation de policy au scope du RG | aucune (`[]`) |
| Assignations de policy au scope subscription | 4, toutes Defender/MCSB — **aucune** liée à l'extinction |
| `Microsoft.Authorization/policyExemptions` | aucune (`[]`) |
| `Microsoft.DevTestLab/schedules` (auto-shutdown) | aucun (`[]`) |
| Deny assignments sur le RG | aucune (`[]`) |
| Tag d'exemption sur RG / VM / VMSS | aucun; le RG n'a **aucun** tag |
| Tags de subscription | `tag1=MCAPS-Hybrid-REQ-150432-2026-gchambaud`, `tag2=Hybrid` — identifiants de requête MCAPS, pas des marqueurs d'exemption |

Preuve décisive : le propriétaire de la subscription **ne peut même pas lire** le
management group qui porte l'attribution :

```text
az account management-group show --name 896a9463-4bb5-462e-b7b5-2e525d3e1a03
→ (AuthorizationFailed) ... does not have authorization to perform action
  'Microsoft.Management/managementGroups/read' over scope
  '/providers/Microsoft.Management/managementGroups/896a9463-...'
```

Le droit qui autorise la déallocation est donc accordé à un scope sur lequel le projet n'a
**ni autorité, ni visibilité**. Conclusion : **gouvernance de plateforme imposée, non
négociable depuis la subscription.**

**Limite honnête de cette conclusion :** elle établit qu'il n'existe **aucun opt-out
technique atteignable depuis cette subscription**. Elle n'exclut pas qu'un processus
d'exemption MCAPS existe **hors bande** (demande organisationnelle, registre d'opt-out
interne). Vérifier cela demande une action humaine auprès de la gouvernance MCAPS et sort
du périmètre outillable. **Dans tous les cas la reprise automatique reste requise** :
dépendre d'une exemption que le projet ne contrôle pas serait fragile.

C'est un **désaccord structurel** entre le modèle de CI et sa plateforme d'hébergement :
Certigo exécute 100 % de sa CI sur des runners self-hosted **persistants** (les runners
GitHub-hosted étant désactivés par politique EMU), hébergés dans une subscription dont la
gouvernance éteint toutes les VMs chaque nuit. La conséquence directe est que **la CI, et
avec elle les 7 checks requis de `main`, sont indisponibles chaque matin** jusqu'à ce que
quelqu'un rallume les VMs.

Toute conception doit donc supposer la déallocation **permanente** et viser la **reprise
vérifiée**, jamais la prévention.

### Conséquence concrète : la fenêtre nocturne peut trancher une opération longue

L'illustration la plus parlante n'est pas « la CI est indisponible chaque matin », mais
qu'il existe désormais une opération privilégiée, longue, que cette fenêtre peut
**interrompre en vol**.

Une publication complète de contenu émet de l'ordre de **10 200 invocations `az` pour
~2 550 fichiers** (quatre appels `az` par fichier dans `publish_blob_artifact.sh`), soit
une durée de l'ordre de **quatre heures**. Combiné à une déallocation à 00:46–00:49 UTC,
cela impose une contrainte opérationnelle dure : **toute publication doit démarrer avec
plusieurs heures de marge avant cette fenêtre**, sous peine d'être tuée en cours
d'exécution — sur le seul pool qui puisse joindre le stockage à private endpoint.

*(Mesure fournie par la chaîne `certigo-content`; la performance de `publish_blob_artifact.sh`
relève de son packager et n'est pas traitée ici — elle est citée comme preuve.)*

Une tâche dont la durée dépasse l'intervalle entre deux teardowns nocturnes est
précisément ce qu'un runner VMSS persistant gère mal, ce qui renforce encore le constat
ci-dessous.

> 📌 **Lien stratégique (constat, pas décision).** Ce résultat constitue une preuve
> indépendante en faveur de la direction explorée par la PR #370 (« pilote ACA Jobs
> réversible ») et l'ADR-018 : une capacité CI **éphémère et scale-to-zero** est
> structurellement immunisée contre une déallocation nocturne de VM, puisqu'il n'existe
> aucune VM persistante à désallouer.
>
> Le point décisif n'est pas seulement que le modèle de CI est **mal aligné** avec sa
> plateforme d'hébergement, mais qu'il est mal aligné avec une **gouvernance que le projet
> n'a aucune autorité pour modifier** (cf. la section négociabilité ci-dessus). *Une
> architecture qui ne peut pas être exemptée doit être conçue en conséquence.* C'est ce qui
> transforme la question « faut-il des runners éphémères ? » d'une préférence en une
> réponse à une contrainte subie. Ce document ne tranche pas cette orientation et n'étend
> pas ce pilote; il en fournit la justification factuelle.

## Incident du 1er septembre 2026 — perte de redondance trusted (résolu le 4 septembre)

**Symptôme.** Un seul runner `certigo-trusted` en ligne (`f55d176e`, zone 2) au lieu de
deux. L'instance zone 1 `be505fa1` était désallouée et n'apparaissait **pas du tout** dans
GitHub — pas même en `offline`.

**Chaîne causale, du déclencheur à la persistance :**

1. **Déclencheur** — la déallocation nocturne MCAPS a éteint `be505fa1` (et `f55d176e`) le
   1er septembre 2026 à 00:46:13 UTC. Rien d'anormal : cela arrive toutes les nuits.
2. **Cause de la persistance** — `be505fa1` ne figurait dans **aucun** artefact versionné :
   ni dans `capacity-controller.config.json`, ni dans l'un des deux runbooks. La routine de
   rallumage de l'opérateur portant sur une liste de noms de VM, elle a rallumé `f55d176e`
   et `bbf83c5c` chaque jour et **sauté `be505fa1` en silence**. *Un inventaire qui peut
   omettre un membre est la véritable cause racine; la déallocation nocturne n'en est que
   le déclencheur.*
3. **Aggravation irréversible** — restée éteinte au-delà du seuil de garbage collection de
   GitHub (~14 jours sans connexion), l'instance a **perdu son enregistrement runner**. Au
   redémarrage, l'agent démarre, se connecte, reçoit
   `The runner registration has been deleted from the server, please re-configure`, puis
   s'arrête (`no retry needed`). **À partir de ce point, `az vm start` ne restaure plus
   rien** : la VM tourne, aucun runner n'existe.
4. **Pourquoi l'autoscale n'a pas corrigé** — `autoscale-vmss-certigo-runner-zonal` est
   actif (min 2, max 4, défaut 2) mais `sku.capacity` valait **déjà 2** : l'instance
   existait, elle était simplement arrêtée. Il n'y avait donc aucun déficit de capacité à
   corriger. L'Activity Log enregistre de plus un
   `Microsoft.Insights/AutoscaleSettings/MetricFailure` le 1er septembre à 04:59:29 UTC —
   la règle CPU ne pouvait même pas s'évaluer sur des instances désallouées.

**Remise en service (4 septembre 2026).** Les deux agents de `be505fa1` ont été
réenregistrés via une Run Command Azure à paramètre **protégé** (jeton chiffré, jamais
journalisé, ressource supprimée après usage), en réappliquant exactement le jeu de labels
du pool concerné. Vérification côté GitHub :

```text
ID 27  vmss-certigo-runner-zonal_f55d176e-Certigo  online  [... certigo-trusted]  zone 2
ID 29  vmss-certigo-runner-zonal_be505fa1-Certigo  online  [... certigo-trusted]  zone 1
ID 28  certigo-prIVJAN8                            online  [certigo-pr, certigo-pr-pilot]
```

Deux runners `certigo-trusted` en ligne sur deux zones, sans aucun chevauchement de label.

> ✅ **Agent `certigo-ci` — intentionnel et porteur, à ne pas normaliser.** Les mêmes
> instances trusted portent un second agent enregistré dans
> `gchambaud_microsoft/certigo-content` (ID 25 sur `f55d176e`, ID 26 sur `be505fa1`), sous
> les labels `certigo-ci,azure,vmss,zonal,certigo`. `certigo-ci` **est le label que
> sélectionne la chaîne de publication de contenu**, et il est lié à ces instances-là
> précisément parce qu'elles sont **les seules à joindre le compte de stockage de contenu
> immuable via son private endpoint** (`publicNetworkAccess` désactivé,
> `allowSharedKeyAccess` à false, et `vnet-certigo-pr-pilot` sans lien DNS vers
> `privatelink.blob.core.windows.net`).
>
> Supprimer cet agent, renommer ses labels ou les « normaliser » dans la taxonomie
> `certigo-pr`/`certigo-trusted` **casserait la publication de contenu avant sa première
> exécution**. Il est conservé **tel quel**, délibérément.
>
> ⚖️ **Tension de conception assumée, à trancher — pas à résoudre silencieusement.**
> `.github/scripts/validate-workflow-security.mjs` (l. 305) interdit `certigo-ci` dans un
> `runs-on:`, en le qualifiant de « legacy mixed-trust runner label ». Cette règle ne
> s'applique qu'aux workflows **de ce dépôt** ; elle ne gouverne pas ceux de
> `certigo-content`, qui sélectionnent justement ce label. On a donc **les mêmes machines
> physiques servant deux dépôts sous deux taxonomies de labels différentes** : interdit
> ici, requis là-bas. C'est une vraie question de conception qui mérite une décision
> explicite (unifier la taxonomie, ou reconnaître formellement `certigo-ci` comme une
> troisième classe avec sa propre frontière). Ce livrable la **documente** sans la
> trancher.

### Écart résiduel assumé — ce qui est prouvé, et par quoi

Décision explicite : cet écart est **accepté**, pas comblé. Le tableau ci-dessous dit
exactement qui prouve quoi.

| Mécanisme | Ce qu'il prouve | Ce qu'il ne prouve pas |
|---|---|---|
| Reprise Azure (quotidienne, sans surveillance) | que les VMs sont **sous tension** | **rien** sur l'état des runners GitHub || `runner-health.yml` (quotidien) | qu'**au moins un** runner trusted est online — puisqu'il s'y exécute — et que ce runner figure dans l'inventaire versionné | le compte exact de runners online; l'absence de chevauchement de labels |
| Prévol opérateur (`lifecycle-preflight.sh`, à la demande) | **≥ 2 runners trusted online**, zéro chevauchement de label, complétude de l'inventaire | rien **sans surveillance** : il faut qu'un humain le lance |

**Ce que rien ne prouve la nuit :** qu'un agent soit mort alors que sa VM tourne.

**Pourquoi c'est acceptable.** La panne diagnostiquée est désormais **structurellement
empêchée**, pas seulement non détectée : l'enregistrement avait été supprimé parce que la
VM était restée éteinte plus de quatorze jours. Un démarrage quotidien côté Azure supprime
cette précondition. Le résiduel se réduit donc à « une *autre* cause tue l'agent pendant
que la VM tourne, **et** personne ne lance le prévol avant que ça compte » — nettement plus
étroit que la panne réellement survenue.

**Ce qui le comblerait, si la décision changeait :** une GitHub App disposant de
`administration: read`, consommée par la sonde trusted, permettrait d'énumérer les runners
depuis un workflow.

### Options écartées — analyse déjà faite, ne pas la refaire

| Option | Pourquoi écartée |
|---|---|
| **GitHub App `administration: read`** | Comble proprement, mais achète un risque résiduel **étroit** au prix d'un coût **large et permanent** : nouveau matériel de secret, nouvelle charge de rotation, nouveau rayon d'impact. L'audit porte déjà un constat ouvert (R-05) sur trois secrets d'application sans outillage de rotation; en ajouter un quatrième pendant que celui-là n'est pas résolu est un mauvais échange. |
| **Matrice 2 jobs prouvant deux `runner.name` distincts** | Sans credential, mais **instable** : si le second runner est légitimement occupé par un vrai job, les deux branches se sérialisent sur la même machine et l'alerte est fausse. Une alerte instable apprend aux gens à ignorer les alertes, et le problème de fond de ce projet est justement des signaux auxquels personne ne peut se fier. |
| **`Invoke-AzVMRunCommand` depuis le runbook** pour vérifier que les services `actions.runner.*` sont `active` | Techniquement **meilleur** que le power state — cela aurait attrapé exactement la panne observée, puisque l'agent s'était auto-arrêté et que son unité n'aurait pas été `active`. **Écarté sur le privilège** : accorder `runCommand/action` à une identité d'automation lui donne l'**exécution de code arbitraire sur les runners trusted** — les machines qui portent la fédération OIDC vers Azure et la seule accessibilité réseau au stockage à private endpoint. C'est l'une des cibles de plus grande valeur du parc, et un compte d'automation est une cible molle. Échanger une capacité d'exécution distante large contre une amélioration de détection étroite va dans le mauvais sens, et cohabiterait mal avec R-03, ouvert précisément pour ce type de privilège inutile. |

> ⚠️ Là encore : ces mécanismes **signalent**, ils n'**empêchent** pas — sauf la reprise
> Azure, qui empêche bien la précondition de quatorze jours. C'est la seule des trois qui
> soit un contrôle plutôt qu'un rapport.

## Garde-fous versionnés ajoutés

1. **Inventaire complet.** `be505fa1` est désormais lié explicitement dans
   `capacity-controller.config.json`. Une instance du VMSS absente de l'inventaire est
   classée `unclassifiedVirtualMachines` et bloque le plan.
2. **Plancher de redondance.** Le contrôleur de capacité applique
   `minimumOnlineByTrust` (`certigo-pr: 2`, `certigo-trusted: 2`). Un déficit produit un
   blocker explicite. Le décompte utilise la capacité **utilisable** — VM sous tension
   **et** runner GitHub `online` — de sorte que le cas « VM running / runner absent »
   observé ici est bien compté comme un déficit.
3. **Détection d'instance invisible.** `runner-health.yml` exécute
   `.github/scripts/assert-runner-inventoried.mjs` et échoue si le runner qui exécute la
   sonde n'est pas présent dans l'inventaire versionné. Ce contrôle n'exige aucun droit
   d'administration et ferme la classe de défaut à l'origine de l'incident.

> ⚠️ **Ces garde-fous *signalent* un déficit, ils ne l'*empêchent* pas.** C'est la
> différence entre un contrôle et un rapport. Le plancher de redondance s'évalue dans le
> prévol opérateur et la sonde quotidienne : ni l'un ni l'autre ne s'exécute sans
> surveillance pendant la nuit. Ce écart ne se ferme qu'avec la reprise automatique
> côté Azure décrite ci-dessous.

> 🔑 **Pourquoi l'assertion « ≥ 2 runners trusted online » ne peut pas vivre dans un
> workflow.** L'endpoint `GET /repos/{owner}/{repo}/actions/runners` exige un droit
> d'**administration** du dépôt. Or `GITHUB_TOKEN` n'expose pas de permission
> `administration` : elle ne fait pas partie des clés déclarables sous `permissions:`.
> Un workflow ne peut donc pas énumérer les runners self-hosted sans introduire un secret
> supplémentaire (PAT ou GitHub App). C'est pourquoi cette assertion reste dans le prévol
> opérateur, où l'inventaire runners est déjà lu légitimement — et pourquoi tout
> l'outillage embarqué dans les workflows a été conçu **sans droit d'administration**.

### Reprise automatique côté Azure — implémentée

Aucun des garde-fous ci-dessus ne **rallume** les VMs. C'est une limite structurelle et non
un oubli : un workflow GitHub Actions ne peut pas s'auto-réparer ici, puisque les runners
dont il aurait besoin pour s'exécuter sont exactement ceux qui sont désalloués, et qu'aucun
runner GitHub-hosted n'est disponible par politique EMU.

La reprise est donc déclenchée **depuis Azure**, hors des runners. Elle est décrite en
Bicep dans [`infra/ci-runner/auto-recovery.bicep`](../infra/ci-runner/auto-recovery.bicep)
et son module [`modules/runnerAutoRecovery.bicep`](../infra/ci-runner/modules/runnerAutoRecovery.bicep).

| Propriété | Valeur |
|---|---|
| Déclencheur | Logic App (Consumption) `logic-certigo-ci-runner-recovery`, récurrence quotidienne |
| Heure | **01:30 UTC** |
| Action | pour chaque scale set de runners : énumère ses instances, démarre toutes celles qui ne sont pas exclues, attend 30 s, relit, exige `PowerState/running` pour **chacune** et au moins `minimumOnlineByTrust` instances `running` par pool |
| Identité | managée **assignée par le système** — aucun secret, aucun credential |
| Rôle | rôle personnalisé `Certigo CI Runner Recovery`, 3 actions, assignable au seul `rg-certigo-ci` |
| Échec | run `Failed` → métrique `RunsFailed` → alerte `alert-certigo-ci-runner-recovery-failed` (sévérité 1) |

**Pourquoi 01:30 UTC.** La fenêtre de teardown se termine à 00:49 UTC. 01:30 laisse ~41
minutes de marge : la reprise ne court pas contre la déallocation, et une déallocation en
retard ne peut pas annuler un démarrage déjà effectué. Le contrat est verrouillé par un
test (`infra/tests/ci-runner-auto-recovery.test.mjs`) qui refuse toute heure antérieure à
01:00 UTC.

**Privilège accordé — exactement trois actions, et rien d'autre :**

| Action | Pourquoi elle est nécessaire |
|---|---|
| `Microsoft.Compute/virtualMachines/read` | énumérer les instances de chaque scale set **et** lire leur power state en un seul appel (liste filtrée `$expand=instanceView`, au scope du RG) |
| `Microsoft.Compute/virtualMachines/start/action` | la **seule** mutation autorisée; idempotente sur une VM déjà allumée |
| `Microsoft.Compute/virtualMachines/instanceView/read` | lire le power state d'une instance nommée (`GET .../instanceView`). **N'est plus appelée par le workflow depuis le 2026-09-23** : conservée pour ne pas changer le rôle dans le même déploiement ; son retrait est une mesure séparée à faire (retirer, attendre la propagation, relancer un run, vérifier) |

Le rôle intégré **« Virtual Machine Contributor » a été écarté comme trop large** : via
`Microsoft.Compute/virtualMachines/*` il accorderait aussi `delete`, `deallocate/action`,
`reimage/action` et `runCommand/action`. Il permettrait donc à l'identité de reprise de
détruire précisément ce qu'elle est censée restaurer. Sur `runCommand`, voir « Options
écartées » ci-dessus : la décision est déjà prise et n'est pas rouverte ici.

> ⚠️ **La reprise n'est pas l'immunité.** Rallumer les VMs chaque matin ne rend **pas** sûres
> les opérations privilégiées longues. Une publication de contenu complète dure environ
> **quatre heures** (~10 200 invocations `az` pour ~2 550 fichiers). Démarrée trop tard dans
> la journée, elle est **tranchée à 00:46 UTC** quoi qu'il soit rallumé ensuite. La reprise
> raccourcit l'indisponibilité du matin; elle n'allonge pas la fenêtre utile de la nuit.

> ⚠️ **« VM running » n'est pas « runner online ».** Ce mécanisme prouve **uniquement** le
> power state Azure. La panne du 1er septembre s'est présentée comme une VM sous tension
> dont l'enregistrement runner avait été collecté par GitHub : l'agent démarrait, était
> rejeté, et s'arrêtait de lui-même. Un contrôle de power state **n'aurait pas vu** cette
> panne et ne la verrait pas davantage aujourd'hui. C'est un choix délibéré : vérifier
> l'état `online` exigerait un credential GitHub (PAT ou clé de GitHub App) **dans Azure**,
> ce que ce livrable refuse d'introduire. La preuve côté GitHub reste dans
> `runner-health.yml` et le prévol opérateur.

**Ce que la reprise ferme réellement.** L'enregistrement runner avait été supprimé parce que
la VM était restée éteinte **plus de quatorze jours**. Un démarrage quotidien supprime cette
précondition : c'est le seul des trois mécanismes du tableau « Écart résiduel assumé » qui
soit un **contrôle** et non un rapport.

**Comment on sait qu'elle a échoué.** Deux signaux complémentaires, et il faut les deux :

1. **Elle a tourné et a échoué** → alerte `alert-certigo-ci-runner-recovery-failed`
   (`RunsFailed > 0`, sévérité 1, action group `ag-certigo-ci-recovery`).
2. **Elle n'a pas tourné du tout** → l'alerte métrique ne se déclenche pas, par construction.
   Le filet est alors `runner-health.yml` : cette sonde quotidienne **s'exécute sur un runner
   trusted**, donc son échec à trouver un runner est en soi la preuve que la reprise n'a pas
   eu lieu. Aucun des deux ne couvre l'autre; ensemble ils couvrent les deux cas.

> 📌 **Le premier run après un déploiement neuf échoue, et c'est normal.** Le déclencheur
> `Recurrence` d'un Logic App se déclenche **immédiatement à la création**, avant que
> l'assignation de rôle ne se soit propagée. Ce run initial échoue en `ActionFailed` et lève
> l'alerte. Rejouer le déclencheur manuellement une minute plus tard doit réussir; c'est la
> vérification de bon fonctionnement (voir [`runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md) §11).

Le mode dégradé manuel reste valable et documenté dans
[`docs/runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md) §4.

### Runners à la demande — depuis le 2026-09-30

Décision : [`docs/adr/ADR-022-runners-ci-a-la-demande.md`](./adr/ADR-022-runners-ci-a-la-demande.md) ;
exploitation : [`runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md) §13. Chaque VM de runner
s'éteint seule après une période calme sans job, `logic-certigo-ci-runner-idle-deallocation`
désalloue les VM dont l'OS est arrêté, `logic-certigo-ci-runner-wake` les redémarre sur webhook
`workflow_job`. Ce que cela change pour la résilience décrite ici :

- **La disponibilité du matin ne dépend plus de la reprise.** Le premier job qui attend réveille
  son pool, à toute heure. La reprise de 01:30 UTC reste active et inchangée : elle rallume encore
  toutes les instances (qui se rééteignent après leur période calme), ce qui garde chaque
  enregistrement runner connecté au moins une fois par jour et bien en deçà des quatorze jours de
  la panne du 1er septembre. L'agent n'éteint jamais une VM entre 01:15 et 01:50 UTC, et la
  désallocation ne tourne pas de 00:00 à 01:59 UTC : ni l'un ni l'autre ne peut fausser la
  vérification de power state de la reprise.
- **Le plancher de redondance vaut pour un pool réveillé.** Un pool au repos est à zéro par
  construction (mode `idle` du contrôleur, `0 PR + 0 trusted`) ; un job en file réveille
  **toutes** les instances de son pool, donc les deux zones trusted. La reprise continue
  d'exiger `minimumOnlineByTrust` instances `running` par pool chaque nuit.
- **`runner-health.yml` ne prouve plus que la reprise a tourné** : son job réveille désormais
  lui-même le pool trusted. L'échec de la reprise reste signalé par son alerte ; son absence n'a
  plus d'effet immédiat sur la disponibilité, mais au-delà de 14 jours sans reprise, un pool resté
  sans job perdrait ses enregistrements runner (voir le premier point).
- **Un job long n'est jamais coupé par l'extinction locale** : le worker du vrai listener du
  service runner est une activité, quelle que soit la durée de la publication. Seul le teardown MCAPS de 00:46 UTC peut
  encore l'interrompre, comme avant.
- **Une instance sans agent reste allumée** : c'est l'état antérieur (coût), pas une panne.
  Toute instance ajoutée ou reconstruite doit recevoir l'agent (`install-idle-shutdown.ps1`).

#### Historique : la liste d'instances figée (jusqu'au 2026-09-23)

> Section historique. Depuis le 2026-09-23 la reprise n'a plus de liste d'instances : voir
> « Énumération dynamique — en service depuis le 2026-09-23 » ci-dessous.

`virtualMachineNames` était écrit **deux fois** : comme défaut dans `auto-recovery.bicep` et
comme valeur dans `infra/params/ci-runner-auto-recovery.bicepparam`. Aucun workflow ne peut
déployer cette pile — un workflow porteur de credentials Azure est interdit par le scellé du
dépôt — donc **le seul déployeur possible est un opérateur humain**, et un `--parameters`
oublié appliquait le défaut. Les deux copies étaient donc opérationnelles, pas l'une
principale et l'autre décorative.

Elles ont divergé : le 2026-09-07 la PR #402 a porté le pool PR à deux instances et ajouté
`a14700a3` au bicepparam **sans l'ajouter au défaut**, qui est resté à trois. Le test
« every managed runner is restarted after the nightly teardown » ne lisait que le bicepparam
et n'a rien vu ; un second test épinglait même le défaut à `assert.equal(recovered.length, 3)`,
c'est-à-dire qu'il **certifiait le défaut**. Les tests ont ensuite exigé l'égalité
ensembliste entre le défaut, le bicepparam et `inventory.managedRunnerBindings`.

**Limite démontrée le 2026-09-23 : cohérentes entre elles ne veut pas dire fraîches.** Les
trois listes étaient égales, et toutes pointaient vers `bbf83c5c` et `a14700a3`, deux
instances en `provisioningState: Failed` depuis le 2026-09-12. Leur démarrage rendait
`InternalServerError`, donc **les 12 runs du 2026-09-12 au 2026-09-23 ont fini `Failed`**,
pendant que les quatre instances PR de remplacement (créées le 2026-09-14) n'étaient jamais
rallumées : la CI PR était morte chaque matin jusqu'à un `az vm start` manuel. L'alerte
`RunsFailed` existait mais n'avait aucun destinataire. #508 a corrigé les trois listes le
2026-09-23 ; aucun test hors ligne ne pouvant prouver qu'une liste figée suit Azure, la liste
a été supprimée le même jour au profit de l'énumération dynamique.

#### Énumération dynamique — en service depuis le 2026-09-23

Mesurée faisable le 2026-09-09 puis ajournée au nom de la lisibilité d'un graphe déplié, elle
a été mise en service le 2026-09-23 (#503) : l'incident du 2026-09-12 au 2026-09-23 a montré
qu'une liste lisible mais périmée coûte plus cher qu'un graphe à boucle. La lisibilité est
reportée ailleurs : la règle (deux scale sets, liste d'exclusion versionnée) se relit dans le
dépôt, et chaque run rend visibles les instances réellement démarrées (répétitions de
`Start_an_instance_of_<pool>`, voir [`runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md) §11).

- **Aucun nouveau droit.** `checkAccess` sur le principal de la Logic App
  (`logic-certigo-ci-runner-recovery`) au scope `rg-certigo-ci` rendait `Allowed` pour
  `virtualMachines/read`, `start/action` et `instanceView/read`, et `NotAllowed` pour
  `virtualMachineScaleSets/read`, `deallocate/action`, `runCommand/action` et `delete`
  (2026-09-09). L'énumération passe par les VM, jamais par l'API du scale set. Le
  2026-09-23, les runs réels ont confirmé que l'identité managée liste les instances avec ce
  seul rôle.
- **Un seul appel par pool rend membres et power state** :
  `GET .../virtualMachines?$filter='virtualMachineScaleSet/id' eq '{id}'&$expand=instanceView`.
  Le nom de propriété doit être **quoté** : sans les apostrophes, ARM rend
  `The request URL is not valid`. `$expand=instanceView` sans ce `$filter` est refusé
  (`Expand Instance View is only supported when Virtual Machine Scale Set resource filter is
  applied`). Le `$filter` est insensible à la casse côté ARM (mesuré : il rend aussi les
  instances dont la référence porte `RG-CERTIGO-CI`).
- **Exclusions et planchers ne sont pas recopiés** : `auto-recovery.bicep` lit
  `inventory.forbiddenVirtualMachines`, `inventory.externalVirtualMachines` et
  `minimumOnlineByTrust` dans `capacity-controller.config.json` (`loadJsonContent`). Une
  exclusion périmée est inoffensive ; une exclusion manquante fait échouer le run en nommant
  l'instance, sans empêcher les autres de démarrer.
- **Pas d'assertion vide.** Trois échecs explicites au niveau supérieur :
  `RunnerEnumerationIncomplete` (pagination), `RunnerPowerStateNotRunning` (instance non
  exclue sans `PowerState/running`, nommée), `RunnerPoolBelowRedundancyFloor` (moins de
  `minimumOnlineByTrust` instances `running` dans un pool). Le plancher empêche qu'une liste
  d'exclusion trop large ou un scale set vide rendent la vérification vraie par vacuité.
- **`Terminate` reste au niveau supérieur** : les démarrages sont dans un `Foreach` par pool,
  les assertions agrègent la re-lecture hors boucle.
- **Piège Logic Apps mesuré.** `createArray()` sans argument est refusé à l'exécution
  (`InvalidTemplate ... 'createArray' expects a comma separated list of parameters`), mais
  seulement quand il est réellement évalué : caché derrière un `coalesce` dont le premier
  argument est non nul, il passe inaperçu. Le premier déploiement du 2026-09-23 (18:19Z) a
  échoué ainsi (run `08584114192689525938465393788CU124`, après avoir tout de même démarré
  les six instances) ; le littéral est désormais `json('[]')`.
- **Tests hors ligne.** `infra/tests/ci-runner-auto-recovery-simulation.test.mjs` développe le
  template ARM compilé puis exécute la définition Logic Apps contre un ARM simulé : topologie
  live du 2026-09-23, instance de remplacement absente de toute liste, instance cassée,
  plancher, pagination, 403 sur un pool, casse, et deux contrôles de mutation qui prouvent
  que les assertions mordent.
- **⚠️ Ne jamais discriminer par tag.** Les tags sont asymétriques : les instances
  `pr-pilot` portent `workload=github-actions-runner` et `trustBoundary`, les instances
  `runner-zonal` ne portent que `VirtualMachineProfileTimeCreated`. Un filtre sur
  `workload` **perdrait les deux runners trusted**. Le seul discriminant fiable est
  `properties.virtualMachineScaleSet.id`.

**Preuves live du 2026-09-23.** Déploiement `certigo-ci-runner-auto-recovery-20260923182604`
(`Succeeded`, what-if sans création ni suppression). Run manuel
`08584114187060282646156606064CU126` : `Succeeded`, six démarrages (`be505fa1`, `f55d176e`,
`1a6deaa2`, `5275ea21`, `6e3abce4`, `94bad106`), aucune des sept instances retirées touchée,
2/2 et 4/4 `running`, les trois `Fail_*` en `Skipped`. Run
`08584114180865363275771379711CU123` pendant le drill (section « Drill de perte d'un
runner ») : une instance désallouée, absente de toute liste, rallumée et vérifiée.

**Premier run automatique — 2026-09-24.** Après la désallocation MCAPS de 00:48:32 à
00:48:41Z (6 VM), le run automatique `08584113934257882646280971546CU126` (01:30:59Z →
01:40:03Z) est `Succeeded` : mêmes six démarrages, aucune instance retirée touchée, trusted
rallumés en 1 min 25 s et PR en 8 min 31 s, les trois `Fail_*` en `Skipped`. À 09:39Z, les
6 runners sont online. C'est le premier succès automatique depuis le 2026-09-11 (12 échecs du
2026-09-12 au 2026-09-23).

#### Cause racine des instances PR mortes — mesurée le 2026-09-23

> Mesuré le 2026-09-23 dans l'Activity Log de `rg-certigo-ci` (fenêtre 2026-09-10 → 2026-09-23)
> et par `GET` ARM sur les deux scale sets. Invalidé par une modification du modèle du pilote PR
> (`pilot.bicep`), de la règle NSG `deny-imds-outbound` ou du verrou `certigo-ci-cannot-delete`.

L'issue #503 attribuait la panne à un modèle « sans customData ni extension » dont le scale
set aurait recréé des instances « de sa propre initiative ». Les deux points sont réfutés par
la mesure, et deux mécanismes précis les remplacent :

1. **Le scale set ne crée jamais d'instance seul.** Les sept créations du 2026-09-11 et du
   2026-09-14 suivent chacune un `virtualMachineScaleSets/write` d'un opérateur
   (`az vmss scale`), exécuté ensuite par le principal d'orchestration Flexible
   `bb5a6d41-d40e-4a32-8eb3-d68e8c8b12ab`. Le scale set n'a ni autoscale, ni
   `automaticRepairsPolicy`. Et le `customData` n'est pas absent : il est **write-only**,
   donc `az vmss show` rend `False` même quand `pilot.bicep` le fournit (voir
   `infra/ci-runner/README.md`, « Séquence de provisionnement »). Le bootstrap prépare le runner
   mais ne l'enregistre jamais, par conception : aucun jeton dans l'IaC.
2. **Aucune des cinq créations faites avec `deny-imds-outbound` actif n'a donné d'instance
   utilisable.** `d8d42366` (créée à 15:59:32Z le 2026-09-11) finit en
   `OSProvisioningInternalError` à 16:05:22Z ; `2c1eeb41` et `3601055e` (08:05:58Z le
   2026-09-14) échouent à 08:12:00Z ; `765cf6af` et `7d3001c2` (16:13:02Z le 2026-09-11)
   aboutissent en 6 min puis échouent au redémarrage suivant (constat de #503 du 2026-09-14 :
   `OSProvisioningClientError ... non-recoverable`, ou retour en `Failed`). Le 2026-09-14, la
   règle a été **neutralisée** de 09:24:53Z à 09:27:01Z (2 min 08 s) : sa destination a été
   remplacée par l'adresse de documentation `192.0.2.1/32`. Deux créations lancées à 09:21:58Z
   ont abouti 3 et 9 s après cette neutralisation ; deux autres, lancées à 09:25:12Z, ont
   abouti en 41 s. La règle a été rétablie vers `AzurePlatformIMDS` à 09:27:01Z. Avant cela,
   Azure a refusé les trois variantes plus fines (Activity Log, corps des requêtes) : la
   suppression (`ScopeLocked`, verrou), une règle `Allow` (`SecurityRuleInvalidAccessType :
   Allowed values: Deny`) et une restriction de source (`InvalidDNSExfilSourceTag : ... must
   have "*" as a sourceaddressPrefix`). **La balise `AzurePlatformIMDS` ne peut donc être ni
   autorisée ni restreinte à quelques sources** : au niveau NSG, le blocage vaut pour tout le
   sous-réseau ou pour rien.
3. **Les deux scale-in tentés sous le verrou `CanNotDelete` ont laissé les instances saines
   visées en `Failed`.** Le 2026-09-11 à 16:09:36Z et 16:14:57Z, deux scale-in ont tenté de
   supprimer trois instances : `bbf83c5c`, `a14700a3` (saines, runners 28 et 30, rallumées avec
   succès par la reprise du matin même) et `d8d42366` (déjà en échec de provisionnement) ;
   chaque suppression a été refusée (`ScopeLocked`). Le 2026-09-12 à 00:48:33Z, la
   désallocation MCAPS de `bbf83c5c` et `a14700a3` a échoué en `InternalExecutionError`, et
   chaque `start` ensuite aussi. Le mécanisme exact n'est pas documenté par Microsoft ; la
   séquence, elle, est mesurée, et la règle de prudence s'impose : ne jamais réduire la
   capacité sous le verrou. Le 2026-09-23, le scale set affiche `sku.capacity = 8` pour 11
   instances, soit 11 − 3 : cohérent avec les trois suppressions refusées. La règle
   d'autoscale trusted « CPU < 20 % → −1 » armait le même piège sur le pool trusted : elle a
   été retirée du live le 2026-09-23 à 18:01Z (application de `capacity.bicep`, déploiement
   `certigo-ci-capacity-20260923180037`).

**Conséquence sur le modèle.** Une reconstruction depuis la définition versionnée est
possible, à deux conditions opérationnelles qui ne sont pas des faiblesses de sécurité des
jobs : retirer la règle NSG IMDS pendant le seul provisionnement (aucun runner n'est enregistré
à ce moment, donc aucun code de PR ne s'exécute ; le VMSS n'a pas d'identité, donc l'IMDS ne
délivre aucun jeton ; `pilot-register.sh` refuse l'enregistrement tant que l'IMDS répond), et
enregistrer le runner par `register-pilot.ps1` avec un jeton éphémère. Elle a été **prouvée**
le 2026-09-25 pour le `pilot.bicep` de `main`, dans une pile réseau neuve, sans toucher au pool
en service (voir « Drill du 2026-09-25 — reconstruction depuis la définition versionnée »). La
reconstruction réelle précédente (2026-09-14) était partie du modèle live, qui a dérivé
(paragraphe suivant). Ce qui reste non résolu par conception : une
instance neuve ne s'enregistre pas seule, faute de credential GitHub dans Azure (option écartée
plus haut). La cible durable est l'image immuable préchauffée (`infra/ci-runner/image/`, #341).

**Le modèle live a dérivé de `pilot.bicep` — mesuré par what-if le 2026-09-23 à ~19:45Z**
(lecture seule, `imageVersion=24.04.202608070`, clé publique lue sur le modèle live,
`blockImdsAtNsg=true`) : un déploiement complet sur le VMSS existant, avec l'ancien défaut
`capacity: 2`, aurait fait passer `sku.capacity` de 8 à 2 (scale-in, donc le piège du point 3)
et `bootstrapSha256` de `a590730b…` (live) à `6e798d4e…` (dépôt), c'est-à-dire réécrit le
`customData`. Le reste du what-if n'est que du bruit connu (valeurs injectées par Azure sur
NAT, IP et VNet, tags). Depuis, `capacity` est un paramètre **obligatoire, sans défaut**, de
`pilot.bicep` (test « the PR pilot template cannot scale in the live pool by default ») :
l'opérateur doit lire et passer la capacité live. La reconstruction documentée passe par un
**nom de VMSS neuf** (voir `infra/ci-runner/README.md`, « Séquence de provisionnement ») ; ce
nom doit alors rejoindre `scaleSets` de la reprise et `capacity.bicep`.

**Les runners PR exécutent un bootstrap jamais revu — mesuré le 2026-09-23.** Sur
`vmss-certigo-pr-pilot-z1_6e3abce4` (runner 34, Run Command en lecture seule, instance
inoccupée, 21:10:48Z), le `user-data` réellement reçu a pour SHA-256 `f5ce4b89…`. C'est
exactement l'emballage de `pilot.bicep` (`#!/usr/bin/env bash`, puis
`export CERTIGO_RUNNER_LABELS='certigo-pr,certigo-pr-pilot'`, sans `CERTIGO_BLOCK_IMDS`)
suivi du blob Git `da050d7e` de `bootstrap.sh`, dont le SHA-256 brut est `a590730b…`, la
valeur du tag live. Dans ce dépôt, ce blob n'apparaît que dans 18 commits de checkpoint locaux
d'une session Copilot (du 2026-08-19 17:35Z au 2026-08-20 06:46Z), absents de toutes les
branches d'`origin` : il n'est ni sur `main`, ni dans #309. Le VMSS a été créé depuis cet état
le 2026-08-20 à 06:03 UTC, avant la fusion de #309 (19:50 UTC). Écarts avec le `bootstrap.sh`
de `main` (blob `43686478`, +38/−16 lignes) :
- le blocage IMDS y est inconditionnel, alors que `main` le conditionne à
  `CERTIGO_BLOCK_IMDS=true` ;
- `certigo-block-imds.service` y est ordonné `Before=network-online.target`, alors que
  `main` le place avant `network-pre.target`, donc avant toute configuration réseau ;
- `Runner.Listener --version` y tourne en root (`main` : utilisateur `runner`), `svc.sh` y
  est appelé par chemin absolu sans `cd` dans son répertoire, et `chown -R` n'y est fait qu'à
  l'installation du runner.

Sur cette instance à cet instant, le durcissement attendu est présent :
- `certigo-block-imds.service` est actif ;
- la règle `iptables ... 169.254.169.254/32 -j REJECT` est présente ;
- l'IMDS est injoignable (HTTP `000`) ;
- `/etc/sudoers.d/certigo-runner` est en `440 root`, avec les mêmes règles que le bootstrap
  de `main`.

**Bornes** : une instance, un instant ; les trois autres runners PR n'ont pas été lus. Le
`customData` du modèle est en écriture seule, donc illisible. Le runner 34 en est issu (créé
le 2026-09-14 à 09:21:59Z) et la seule écriture du modèle journalisée depuis est le scale-out
de 09:25:12Z. Déduction : une instance que `az vmss scale` créerait aujourd'hui exécuterait ce
même script non revu. Invalidé par tout remplacement de l'instance, toute modification de son
OS ou du modèle du VMSS. Détail des relevés :
[commentaire du 2026-09-23 sur #341](https://github.com/gchambaud_microsoft/Certigo/issues/341#issuecomment-5803012081).

**Le patching invité Azure modifie les runners — mesuré le 2026-09-23.** Le 2026-09-19,
entre 12:53:07 et 12:53:11Z, `apt-get install ubuntu-advantage-tools -y` a été exécuté hors
bootstrap sur les runners 31 et 34 : même transaction, même version `37.2ubuntu~24.04.1`,
sans `Requested-By`. **Auteur** : l'extension Azure `LinuxPatchExtension`, démarrée à
12:53:06Z pour une opération `ConfigurePatching` (début 12:52:41Z). Son client Ubuntu Pro
exécute exactement cette commande (`UbuntuProClient.install_or_update_pro`,
[source, lignes 28 à 40](https://github.com/Azure/LinuxPatchExtension/blob/119f1101f927096e5c25ed3b4463ac8306fdd0a3/src/core/src/package_managers/UbuntuProClient.py#L28-L40) ;
version déployée sur la VM non relevée). Un job PR ne pouvait pas l'exécuter (sudoers
ci-dessus), et l'Activity Log ne montre aucun Run Command ce jour-là.

**Qui a activé ce patching : l'automate de gouvernance MCAPS — mesuré le 2026-09-24.**
- Le modèle du VMSS PR déclare `patchMode` et `assessmentMode` à `ImageDefault`, et les
  instances en ont hérité à leur création, le 2026-09-14.
- L'historique des changements de propriétés d'Azure Resource Graph (`resourcechanges`,
  conservé 14 jours) montre leur passage à `AutomaticByPlatform`, avec
  `bypassPlatformSafetyChecksOnUserSchedule: true`, le **2026-09-15 à 08:06:24Z**. L'auteur
  est une écriture PowerShell de **MCAPSGovernance-AutomationApp** (appid
  `a1a9c5b6-7a4f-4288-89ab-6805873f65d1`, délégation Lighthouse). C'est le même automate qui
  désalloue les VM chaque nuit et remet les comptes de stockage en LRS.
- D'après l'Activity Log (écritures `virtualMachines/write` réussies depuis le 2026-09-14 à
  09:00Z), c'est la seule écriture hors plateforme sur les instances PR. Elle a touché les 6
  instances PR créées le 2026-09-14, dont 2 des instances retirées, entre 08:06:25 et
  08:06:27Z.
- Le `ConfigurePatching` du 2026-09-19 (12:52:41Z) suit de 46 s un démarrage manuel de la VM
  (12:51:55Z).
- Sur les instances **trusted**, la même écriture a **échoué** le 2026-09-19 à 08:05Z :
  `PropertyChangeNotAllowed`, « Changing property 'osProfile' is not allowed ». Une image de
  galerie spécialisée n'a pas d'`osProfile` modifiable. Le pool trusted n'a ni
  `patchSettings`, ni évaluation de correctifs.

**Conséquences** :
1. une évaluation des correctifs tourne chaque jour sur les runners PR : le 2026-09-24,
   entre 05:48:51 et 05:50:55Z sur les 4 instances. Elle commence par `sudo apt-get -q update`
   ([`AptitudePackageManager.py` ligne 51](https://github.com/Azure/LinuxPatchExtension/blob/119f1101f927096e5c25ed3b4463ac8306fdd0a3/src/core/src/package_managers/AptitudePackageManager.py#L51),
   appelée par [`PatchAssessor.py` ligne 64](https://github.com/Azure/LinuxPatchExtension/blob/119f1101f927096e5c25ed3b4463ac8306fdd0a3/src/core/src/core_logic/PatchAssessor.py#L64)).
   Un job qui lance `sudo apt-get update` ou `install` au même instant peut échouer sur un
   verrou APT ou dpkg. C'est un risque déduit : aucune occurrence n'a été observée. Mesuré le
   2026-09-24 : les seuls appels apt des jobs sont les étapes « Ensure CI prerequisites »
   (`ci-mobile.yml` ×3, `ci-cortex-parity.yml` ×1). Elles ne lancent apt que si `unzip`,
   `zip`, `jq` ou `xz` manque. Sur les runs 35983554193 et 35920190487, les 10 étapes ont
   affiché « All prerequisites already present. », sans aucune sortie apt. Le risque ne
   concerne donc qu'un runner auquel il manquerait un outil. Recommandation et extrait prêt
   à l'emploi dans `runbooks/CI_RUNNERS.md` §7 ;
2. aucune installation automatique n'a été observée à ce jour. Aucune configuration de
   maintenance n'est assignée. Le 2026-09-24, l'évaluation comptait encore, selon
   l'instance, 35 ou 99 correctifs critiques ou de sécurité en attente. Les journaux APT
   relevés le 2026-09-23 sur le runner 31 ne contiennent, après le bootstrap, que la
   transaction du 19/09 (oracle de #533) ;
3. remettre `ImageDefault` dans nos templates ne protégerait pas durablement : l'automate
   agit sur les instances après leur création, et on ne connaît pas sa fréquence ;
4. une image immuable « sans artefact non listé » devra soit neutraliser ce patching invité
   sur les VM runners, soit le vérifier au boot (#341). Une image **spécialisée** y échappe
   (mesuré sur le pool trusted). Une image **généralisée**, comme celle que produit Azure
   Image Builder, a un `osProfile` et subira cette écriture.

> ⏱️ **Durée mesurée d'un démarrage PR.** Un `start` depuis `deallocated` dure ~1 min pour
> une instance trusted et **~7 min 30 s pour une instance PR** (2026-09-11 : 7 min 32 s et
> 8 min 01 s ; 2026-09-23 : 7 min 32 s). Hypothèse cohérente mais non prouvée : l'agent invité
> attend l'IMDS, bloqué sur le sous-réseau PR, avant de signaler l'état prêt. Le type de
> disque n'explique pas l'écart : le 2026-09-24, les 6 disques OS en service, PR comme
> trusted, sont en `Standard_LRS` à 60 Mo/s. `pilot.bicep` demande `Premium_LRS`, mais
> l'automate MCAPS a rétrogradé les 6 disques PR créés le 2026-09-14 (les 4 en service et
> 2 des instances retirées). Resource Graph date ce changement du 2026-09-15, entre
> 00:56:04 et 01:06:09Z. La reprise en
> tient compte (aucun délai de vérification n'est déclenché avant la fin des démarrages).

### Verrou de suppression sur `rg-certigo-ci`

Plusieurs templates distincts ciblent ce resource group : `network.bicep`, `runner.bicep`,
`pilot.bicep`, le module `sharedPrivateDns.bicep` déployé par `infra/main.bicep`, et
désormais `auto-recovery.bicep`. **Un déploiement en mode `Complete` lancé depuis n'importe
lequel supprimerait tout ce que les autres ont créé.**

Le rayon d'impact a été mesuré, pas supposé. La zone privée
`privatelink.blob.core.windows.net` réside dans `rg-certigo-ci` et porte **quatre**
enregistrements A : `dev` (10.60.0.69), `staging` (10.80.2.5), `prod` (10.100.2.7) et
`content` (10.42.1.5). Détruire la zone casse la résolution privée de **dev, staging et prod
simultanément** — pas seulement la chaîne de contenu.

Deux précisions factuelles, vérifiées dans Azure :

- Le private endpoint blob `pe-stcertigocntz3wqbdww-blob` réside dans **`rg-certigo-content`**,
  pas ici; il ne fait que **joindre** un sous-réseau de `vnet-certigo-ci`. Un déploiement
  `Complete` ciblant `rg-certigo-ci` ne pouvait donc pas le supprimer.
- L'enregistrement `stcertigocntz3wqbdww` est **géré par Azure** via le `dnsZoneGroup` de ce
  private endpoint. C'est bien la **zone** qui est exposée, pas l'enregistrement isolément.

La règle « jamais de mode `Complete` ici » ne vivait que dans un runbook. Un runbook
*signale*, il n'*empêche* pas. Elle est donc désormais un **contrôle** :
[`modules/resourceGroupDeletionLock.bicep`](../infra/ci-runner/modules/resourceGroupDeletionLock.bicep)
pose un verrou `CanNotDelete` au scope du resource group. Il protège aussi les instances
`be505fa1` et `f55d176e`, dont les enregistrements runner ont été restaurés à la main.

> ⚠️ **Effet de bord assumé et validé.** Les verrous sont hérités par les ressources enfants.
> Supprimer le private endpoint de contenu entraînerait la suppression de son enregistrement A
> dans la zone verrouillée et **échouera** tant que le verrou est en place. C'est la propriété
> recherchée : une suppression délibérée doit passer par une levée délibérée. Procédure de
> levée et de remise en place : [`runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md) §11.

#### Suppression des sept instances retirées — 2026-09-25

Accord explicite de Gabriel, relayé par l'orchestrateur, exécuté après la fin de la promotion
prod, sans autre déploiement sur le groupe pendant la fenêtre. Script à deux modes
(`DryRun` puis `Execute`), testé d'abord hors ligne avec de faux `az` et `gh` sur quatre
scénarios : succès, échec d'une suppression, remise du verrou refusée deux fois, verrou absent
au départ. Le verrou est remis dans un bloc `finally`, avec plusieurs essais et une vérification
du niveau et des notes. Relevé Activity Log et `az` du 2026-09-25 :

| Heure (UTC) | Événement |
|---|---|
| 08:48:16 | préconditions OK : 7 cibles présentes, aucune ne porte de runner GitHub (nom d'hôte absent de l'API), `deleteOption: Delete` sur chaque disque et chaque carte réseau, aucun disque de données, aucun déploiement en cours, 6 runners online, verrou `CanNotDelete` |
| 08:48:22 | `locks/delete` `certigo-ci-cannot-delete` |
| 08:48:22 → 08:49:57 | `az vm delete` des sept VM, une par une ; Azure supprime ensuite chaque disque OS et chaque carte réseau (`disks/delete`, `networkInterfaces/delete` Succeeded, une ligne par ressource) |
| 08:50:03 | `locks/write` : verrou remis, **même niveau, mêmes notes** ; levé pendant 1 min 42 s |
| 08:52:35 | relevé final : les 7 VM, leurs 7 disques et leurs 7 cartes réseau sont introuvables ; les 6 instances gérées sont inchangées (`Succeeded`, `running`) ; le Logic App de reprise n'a pas changé (même `changedTime`, même empreinte de définition) ; les empreintes des enregistrements et des liens des 5 zones DNS privées sont identiques ; capacité trusted inchangée (2) |

Constats :
- `sku.capacity` du VMSS PR est passé de 8 à **4**, égal au nombre réel d'instances. C'est
  cohérent avec l'hypothèse du point 3 de « Cause racine des instances PR mortes » : les trois
  instances visées par les scale-in refusés du 2026-09-11 n'étaient déjà plus comptées. La
  valeur a été notée, jamais « corrigée » par un scale ;
- le prévol `evaluate-lifecycle.mjs`, rejoué vers 08:55Z avec les données live, ne garde plus
  qu'une raison : « capacity controller feature flag is off », qui est voulue ;
- économie : 7 disques `Standard_LRS` de 128 Gio (S10), à 5,888 USD/mois chacun au tarif
  retail West Europe relu le 2026-09-25, soit **41,22 USD/mois**.

La release Android reste volontairement sur `certigo-trusted`. Elle peut
utiliser l'identité managée Azure du runner pour lire Key Vault.

Toute automation mutable reste bloquée. Le prévol
`infra/ci-runner/lifecycle-preflight.sh` est read-only et doit refuser un état non
conforme. La séparation en pools, le lease anti-concurrence, l'ordre start/deallocate et le
rollback sont dans [`CLOUD_LEAST_PRIVILEGE.md`](./runbooks/CLOUD_LEAST_PRIVILEGE.md).

Le contrôleur versionné reste `enabled=false`. Son état v3 lie les trois couples exacts et
considère une capacité utilisable seulement si la VM est powered **et** le runner online.
La cible d'un pilote ultérieur est limitée à
**6 runners `certigo-pr` + 2 runners `certigo-trusted`**, avec un incrément par plan.
Cette limite de pilote n'est pas un plafond de production final. Tout scale-in exige 5 minutes continues sans activité, remises à zéro par tout job
`queued/in_progress` ou runner `busy`, puis deux gardes distinctes et une garde finale.
Chaque plan mutable porte la génération du lease et la révision d'état à comparer
atomiquement; un watcher en retard ne peut donc pas réutiliser un quiet obsolète. Le pilote
PR est désalloué avant le primaire trusted. Une activité post-scale-in conserve et restaure
tous les slots exacts supprimés, même si la flotte restante dépasse encore le mode normal.

## Politique des pull requests

Les workflows PR sont chargés depuis `main` avec `pull_request_target`. Pour une PR
interne, ils vérifient `head.repo.full_name == github.repository`, puis checkoutent
explicitement le SHA de tête avant toute exécution. Une PR de fork n'est pas supportée :
`fork-pr-policy.yml`, lui aussi chargé depuis `main`, n'effectue aucun checkout et fait
échouer `Fork PR policy / Required gate`. Ce contexte requis empêche tout faux vert lié
aux autres jobs non applicables, sans exécuter une seule instruction du fork.

Chaque workflow PR possède un groupe de concurrence stable `workflow + numéro de PR`.
Seuls le premier essai de `opened` et les premiers essais de `synchronize` portant
un numéro de PR valide rejoignent ce groupe. Un ancien rerun, un événement `reopened`
ou un contexte PR incomplet reçoit un groupe unique `event + run_id + run_attempt` :
il ne peut donc ni annuler un run actif, ni évincer le run `pending` de la tête courante
(GitHub remplace toujours le run en attente d'un même groupe, indépendamment de
`cancel-in-progress`). Seul `synchronize`, avec son SHA GitHub `after` non vide, peut
demander l'annulation du run précédent de cette PR. Les événements `push`, `schedule`,
`workflow_dispatch`, `repository_dispatch` et `merge_group` utilisent un groupe unique
par `run_id`; les workflows de gouvernance, déploiement et publication n'annulent jamais
un run en cours. Le préfixe propre au workflow empêche aussi toute collision avec une
autre PR ou avec les runs dynamiques Dependabot.

Une réponse positive de l'API d'annulation GitHub **n'est pas un état terminal** : un run
encore `queued` peut malgré tout être assigné à un runner après cette réponse ; le cas
observé a même laissé deux jobs backend finir en succès avant la conclusion finale de
l'annulation. Aucun contrôleur de cycle de vie ne doit donc déduire une capacité libre ou
l'absence d'exécution de la seule acceptation de l'annulation. Le job réutilisable
`pr-head-freshness.yml`, chargé depuis `main`, relit
le SHA courant via l'API GitHub avant de rendre les jobs coûteux éligibles. Comme la tête
peut encore changer pendant l'attente en file, chaque job qui consomme le checkout PR
répète ce contrôle immédiatement après son assignation et avant le checkout. Si le SHA
de l'événement est obsolète ou absent, le travail coûteux ne démarre pas ; une erreur API
fait échouer le check requis au lieu de le convertir en succès `skipped`.

## Actions d'infrastructure externes

Ces opérations modifient Azure ou GitHub et ne peuvent pas être prouvées par un commit :

1. Inventorier les runners et les VM :

   ```bash
   az vm list -g rg-certigo-ci -o table
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '.runners[] | {name,status,busy,labels:[.labels[].name]}'
   ```

2. Conserver au moins un pool sain par classe dans deux sous-réseaux distincts; ne pas
   appliquer `runner.bicep` au VMSS flexible live.
3. Enregistrer le pool PR avec `certigo-pr` seulement et le pool opérations avec
   `certigo-trusted` seulement; n'accorder les droits minimaux qu'au second.
4. Vérifier qu'un runner en ligne existe dans chaque classe, et que la classe trusted en
   compte **au moins deux** :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '[.runners[] | {name,status,labels:[.labels[].name]} | select(.status == "online") | select(any(.labels[]; . == "certigo-pr") or any(.labels[]; . == "certigo-trusted"))]'
   ```

   Attendu : **un** runner `certigo-pr` et **deux** runners `certigo-trusted`, chacun avec
   un seul label de rôle et aucun chevauchement.

Conserver comme preuve la sortie des deux inventaires, les noms des runners, leurs
labels, la date et l'URL du drill décrit ci-dessous.

## Bootstrap idempotent des runners

Le dépôt versionne le modèle de reconstruction et le bootstrap, mais ne réconcilie jamais
une VM runner active : le bootstrap reste donc une procédure opérateur. Pour éviter les
dérives, appliquer toujours le bootstrap de façon **idempotente** sur chaque instance des
pools (`vmss-certigo-runner-zonal_*`, `vmss-certigo-pr-pilot-z1_*`) :

1. installer ou vérifier le socle versionné (`git`, `curl`, `jq`, `zip`, `unzip`, `xz`,
   `sudo`, le binaire GitHub runner et Azure CLI) ; les SDK de workload (Node, .NET,
   Flutter/Dart, Java/Android, Bicep) sont épinglés et provisionnés par les workflows ;
2. vérifier que le service `actions.runner.*` existe et redémarre automatiquement ;
3. réappliquer exactement un label de rôle, `certigo-pr` ou `certigo-trusted`
   (GitHub ajoute `self-hosted`, `Linux` et `X64`) ;
4. tester la connectivité sortante via la NAT Gateway avant d'approuver une PR.

Le compte de service `runner` n'a pas de privilège administrateur général. Son allow-list
`sudo` est limitée à `apt-get update`, à l'installation exacte de `unzip zip jq xz-utils`
requise par les workflows, et au redémarrage sans argument de son unique service runner.
Toute installation hors liste, modification système ou réenregistrement est réalisée par le
compte administrateur break-glass.

Les commandes exactes de cycle de vie et de dépannage restent dans
[`docs/runbooks/CI_RUNNERS.md`](./runbooks/CI_RUNNERS.md).

## Sonde quotidienne de santé du pool

En plus du drill manuel, conserver une **sonde quotidienne** légère exécutée par
l'opérateur (ou par une automation externe) pour détecter tôt un runner cassé :

```bash
gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | {name,status,busy,labels:[.labels[].name]}'
az vm list -g RG-CERTIGO-CI --show-details \
  --query "[].{Nom:name, Etat:powerState}" -o table
az network nat gateway show -g rg-certigo-ci -n nat-vm-certigo-runner-2
az network vnet subnet show -g rg-certigo-ci --vnet-name vnet-certigo-ci \
  -n snet-runners --query natGateway.id -o tsv
df -h
```

Points à vérifier :

- **un** runner `certigo-pr` et **deux** runners `certigo-trusted` en ligne ; le décompte
  se fait côté **GitHub**, jamais sur le seul power state Azure ;
- trois VMs `VM running` avant usage ou `VM deallocated` hors session ;
- NAT Gateway et association du sous-réseau intactes ;
- espace disque suffisant sur chaque runner (conserver une marge opérationnelle pour
  Flutter, .NET, Android SDK et artefacts de build).

> ⚠️ Une VM `VM running` dont le runner est absent de GitHub est une panne **réelle** et
> silencieuse : c'est exactement la forme qu'a prise l'incident du 1er septembre 2026.
> Une sonde qui n'interroge que Azure ne la détecte pas.

La sonde `infra/ci-runner/health-probe.sh` est non destructive : elle teste les endpoints,
les versions des commandes et l'espace disque, affiche son résumé, puis l'ajoute à
`GITHUB_STEP_SUMMARY` lorsque cette variable est fournie. Elle retourne non-zéro en cas
d'échec. La lancer avec `bash infra/ci-runner/health-probe.sh` depuis le runner après
provisioning de ses SDK ; les tests locaux `test-health-probe.sh` emploient des commandes
factices et n'appellent aucun service live.

## Vérification de checksum et de provenance

Toute installation ou rotation d'outillage runner doit **vérifier la provenance** des
binaires téléchargés :

- **actionlint** : version épinglée dans `lint-workflows.yml` ;
- **Bicep CLI** : version épinglée dans `ci-infra.yml` ;
- **OSV-Scanner** : version + SHA256 officiel déjà vérifiés dans
  `dependency-vuln-scan.yml`.

Pour tout nouvel outil ajouté au bootstrap runner, documenter la source officielle, le
checksum attendu et la commande de vérification avant mise en service.

## État versionné et preuve opérationnelle existante

Le code fournit désormais :

- `infra/ci-runner/network.bicep` pour l'egress legacy, avec IP, NAT, NSG et
  VNet `existing`, tags isolés et seul sous-réseau enfant mutable ;
- `infra/ci-runner/capacity.bicep` pour référencer les deux VMSS `existing` et
  retirer uniquement le scale-in CPU de l'autoscale legacy ;
- `infra/ci-runner/runner.bicep` comme modèle historique de reconstruction
  d'une nouvelle VM/NIC/disque/identité, jamais comme représentation du VMSS live ;
- `infra/ci-runner/bootstrap.sh` pour installer et enregistrer le runner de manière
  idempotente, avec version et SHA-256 épinglés ;
- `.github/workflows/runner-health.yml` pour le probe quotidien ;
- `.github/scripts/assert-runner-inventoried.mjs` pour interdire qu'une instance exécute
  un job trusted sans figurer dans l'inventaire versionné ;
- `infra/ci-runner/capacity-controller.config.json` comme **inventaire de référence** :
  les quatre instances live y sont liées explicitement, et `minimumOnlineByTrust` y fixe le
  plancher de redondance.

Preuve **historique** à conserver sans la réinterpréter comme l'état live actuel : le drill
[31090379901](https://github.com/gchambaud_microsoft/Certigo/actions/runs/31090379901)
a été réalisé avec `vm-certigo-runner` hors ligne ; `vm-certigo-runner-2` a pris le job,
puis les deux runners ont été remis en ligne. Le disque primaire a aussi été nettoyé à
**12 GB libres**. Le probe quotidien impose un plancher de 10 Gio.

Un complément historique du 2026-08-06 confirme aussi que l'identité système de
`vm-certigo-runner-2` (`principalId`
`2c3a78ab-3c16-4eef-9cfb-f763d0fc699c`) a reçu uniquement le rôle
`Key Vault Secrets User` au scope exact de `kv-certigo-dev-bk3j5j`. Cette identité n'est
plus celle du VMSS live; la procédure ci-dessous reste une référence de migration, pas une
commande applicable au pool actuel.

## Reconstruction reproductible d'un runner

Ces opérations Azure/GitHub sont externes au commit. Toujours garder l'autre runner
`online` pendant la reconstruction.

1. Capturer l'inventaire et une version d'image immuable :

   ```bash
   az vm list -g rg-certigo-ci -d -o table
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '.runners[] | {id,name,status,busy,labels:[.labels[].name]}'
   IMAGE_VERSION="$(az vm image list -l westeurope \
     --publisher Canonical --offer ubuntu-24_04-lts --sku server \
     --all --query '[-1].version' -o tsv)"
   printf 'Pinned image: %s\n' "$IMAGE_VERSION"
   ```

2. Pour une **nouvelle** instance, ou après suppression explicite de l'ancienne VM,
   vérifier puis appliquer l'IaC. Ne jamais cibler le nom d'une VM vivante :

   ```bash
   RUNNER_NAME=vm-certigo-runner-3
   SSH_KEY="$HOME/.ssh/${RUNNER_NAME}-$(date +%Y%m%d)"
   ssh-keygen -t ed25519 -f "$SSH_KEY" -C "${RUNNER_NAME}-break-glass"
   az deployment group what-if -g rg-certigo-ci \
     --template-file infra/ci-runner/runner.bicep \
     --parameters runnerName="$RUNNER_NAME" imageVersion="$IMAGE_VERSION" \
                  availabilityZone=3 \
                  adminSshPublicKey="$(cat "$SSH_KEY.pub")"
   az deployment group create -g rg-certigo-ci \
     --template-file infra/ci-runner/runner.bicep \
     --parameters runnerName="$RUNNER_NAME" imageVersion="$IMAGE_VERSION" \
                  availabilityZone=3 \
                  adminSshPublicKey="$(cat "$SSH_KEY.pub")"
   ```

   Critère : uniquement la VM, `${RUNNER_NAME}-nic`, le disque OS géré et l'identité
   système associée sont créés ; aucune IP publique, la sortie `principalId` est non vide
   et `bootstrapSha256` correspond au tag de la VM. Les extensions VM sont désactivées
   (`allowExtensionOperations=false`) : toute évolution passe par une reconstruction avec
   le bootstrap versionné. `network.bicep` doit rester `NoChange`.

3. Attendre `Provisioning succeeded`, ouvrir une session privée (Bastion/VPN), attendre
   explicitement la fin de cloud-init, puis générer un jeton d'enregistrement valable une
   heure. Le flux ci-dessous le transmet par entrée standard : il ne l'écrit ni dans un
   fichier, ni dans une variable d'environnement, ni dans l'historique de commandes.
   Désactiver tout `set -x` avant de l'exécuter :

   ```bash
   sudo cloud-init status --wait
   sudo test -x /usr/local/sbin/certigo-runner-bootstrap

   # Depuis le poste opérateur, via Bastion/VPN vers l'adresse privée de la VM :
   gh api --method POST \
     repos/gchambaud_microsoft/Certigo/actions/runners/registration-token \
     --jq .token |
     ssh <BREAK_GLASS_ADMIN>@<PRIVATE_VM_ADDRESS> \
       'sudo /usr/local/sbin/certigo-runner-bootstrap --register --token-stdin'
   ```

   Le bootstrap lit le jeton une seule fois, le transmet à `config.sh`, puis l'efface de
   son environnement. Ne pas employer `RUNNER_TOKEN=...`, `--token ...`, `tee`, un
   redirecteur, un copier-coller dans un ticket ou un journal. Conserver la clé SSH privée
   dans le coffre break-glass approuvé pendant la vie du runner, puis la détruire lors de
   sa suppression ou la renouveler immédiatement en cas de compromission.

4. Vérifier la configuration, puis lancer les probes :

   ```bash
   gh api repos/gchambaud_microsoft/Certigo/actions/runners \
     --jq '.runners[] | select(.name == "'"$RUNNER_NAME"'") | {status,busy,labels:[.labels[].name]}'
   gh api --method POST repos/gchambaud_microsoft/Certigo/dispatches \
     -f event_type=runner-health
   gh run list --workflow runner-health.yml --limit 1
   ```

   Critères : `online`, label de rôle exact, santé verte pour GitHub, NuGet, pub.dev,
   npm, Azure, au moins 10 Gio libres et tous les SDK/outils. Exécuter ensuite le drill
   de perte de l'autre runner.

### Rollback de reconstruction

Si le nouveau runner échoue, conserver l'ancien runner en ligne, supprimer
l'enregistrement GitHub du nouveau puis seulement ses ressources. Si un rôle Azure lui a
déjà été accordé, appliquer d'abord le rollback d'identité ci-dessous :

```bash
RUNNER_ID="$(gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | select(.name == "'"$RUNNER_NAME"'") | .id')"
gh api --method DELETE \
  "repos/gchambaud_microsoft/Certigo/actions/runners/$RUNNER_ID"
az vm delete -g rg-certigo-ci -n "$RUNNER_NAME" --yes
az network nic delete -g rg-certigo-ci -n "${RUNNER_NAME}-nic"
```

Le rollback est réussi quand l'ancien pool traite de nouveau un dispatch et que
`network.bicep` ne montre aucune modification.

## Rotation, révocation et compromission

### Rotation planifiée

1. Ajouter/reconstruire un runner avec une nouvelle `imageVersion` et les nouvelles
   versions/SHA-256 vérifiées.
2. Prouver santé et respect du label de confiance.
3. Mettre l'ancien runner hors ligne, confirmer qu'aucun job n'est `busy`, révoquer ses
   attributions Azure, supprimer son enregistrement GitHub, puis sa VM/NIC/disque et sa
   clé SSH break-glass.
4. Ne jamais descendre sous deux runners `online` hors de la fenêtre contrôlée.

Pour mettre à jour le binaire, relever le champ `digest` de l'asset officiel, modifier
ensemble `RUNNER_VERSION` et `RUNNER_SHA256`, puis exécuter :

```bash
gh api repos/actions/runner/releases/tags/v<VERSION> \
  --jq '.assets[] | select(.name == "actions-runner-linux-x64-<VERSION>.tar.gz") | {url:.browser_download_url,digest}'
bash infra/ci-runner/validate.sh
```

Appliquer la même règle aux binaires Bicep/actionlint et aux actions : relever le
`digest` de l'asset ou le SHA du tag officiel, vérifier la signature GitHub du commit,
puis épingler la valeur complète dans le workflow :

```bash
gh api repos/Azure/bicep/releases/tags/v<VERSION> \
  --jq '.assets[] | select(.name == "bicep-linux-x64") | {url:.browser_download_url,digest}'
gh api repos/rhysd/actionlint/releases/tags/v<VERSION> \
  --jq '.assets[] | select(.name == "actionlint_<VERSION>_linux_amd64.tar.gz") | {url:.browser_download_url,digest}'
ACTION_SHA="$(gh api repos/actions/checkout/git/ref/tags/v4 --jq .object.sha)"
gh api "repos/actions/checkout/commits/$ACTION_SHA" \
  --jq '{sha,verified:.commit.verification.verified,reason:.commit.verification.reason}'
```

Le commit n'est accepté que si `verified` vaut `true`. Ne jamais remplacer un SHA
complet ou un digest versionné par un tag flottant.

### Révocation d'urgence

En cas de compromission, empêcher d'abord tout nouveau job :

```bash
RUNNER_ID="$(gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | select(.name == "'"$RUNNER_NAME"'") | .id')"
gh api --method DELETE \
  "repos/gchambaud_microsoft/Certigo/actions/runners/$RUNNER_ID"
az vm deallocate -g rg-certigo-ci -n "$RUNNER_NAME"
```

Révoquer ensuite les attributions de l'identité, renouveler toute clé SSH et tous les
secrets Key Vault auxquels la machine avait accès, examiner les journaux GitHub/Azure,
puis reconstruire depuis l'IaC. Ne jamais réutiliser le disque compromis. Le rollback
d'une révocation consiste à reconstruire et **réenregistrer** une VM saine, jamais à
réactiver l'enregistrement compromis.

## Identité managée pour la release Android (action externe)

`runner.bicep` crée une identité système mais n'accorde aucun droit. Après validation de
chaque nouveau runner, un opérateur autorisé doit accorder uniquement
`Key Vault Secrets User` sur le coffre mobile :

```bash
PRINCIPAL_ID="$(az vm identity show -g rg-certigo-ci -n "$RUNNER_NAME" \
  --query principalId -o tsv)"
KV_ID="$(az keyvault show -g rg-certigo-prod -n <VAULT_NAME> --query id -o tsv)"
az role assignment create --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Key Vault Secrets User" --scope "$KV_ID"
az role assignment list --assignee "$PRINCIPAL_ID" --scope "$KV_ID" \
  --include-inherited -o table
# Sur la VM, ne demander que l'identifiant, jamais la valeur du secret :
az login --identity --output none
az keyvault secret show --vault-name <VAULT_NAME> \
  --name <AUTHORIZED_TEST_SECRET> --query id -o tsv
```

Critères : une seule attribution au scope du coffre attendu ; `az login --identity`
réussit sur la VM et la lecture d'un secret de test autorisé réussit, sans afficher sa
valeur. Cette action et une vraie reconstruction ne sont pas réalisables dans une PR.

Rollback/révocation :

```bash
az role assignment delete --assignee "$PRINCIPAL_ID" \
  --role "Key Vault Secrets User" --scope "$KV_ID"
az role assignment list --assignee "$PRINCIPAL_ID" --scope "$KV_ID" -o table
```

Le second résultat doit être vide avant suppression d'une VM compromise.

## Drill de perte d'un runner

Ne pas reprendre les anciennes commandes `vm-certigo-runner` / `vm-certigo-runner-2` : elles
ne représentent plus le live. Préconditions d'un drill, et leur état mesuré le 2026-09-23 :

| # | Précondition | État au 2026-09-23 |
|---|---|---|
| 1 | le what-if puis l'application approuvée de `capacity.bicep` ont retiré le scale-in CPU | ✅ appliqué à 18:01:06Z (`certigo-ci-capacity-20260923180037`, what-if : 1 `Modify`, 0 création/suppression) |
| 2 | `be505fa1` possède une classification et une décision de lifecycle documentées | ✅ liée dans `managedRunnerBindings` depuis le 2026-09-04 |
| 3 | `lifecycle-preflight.sh` est vert tout en gardant le contrôleur `enabled=false` | ⚠️ impossible au sens strict : `evaluate-lifecycle.mjs` ajoute toujours la raison « capacity controller feature flag is off » quand `enabled=false`. Hors cette raison, une seule restait à 19:05Z : « forbidden Azure VMs are present » (les sept instances PR retirées). Elle a disparu le 2026-09-25 après leur suppression (voir « Suppression des sept instances retirées — 2026-09-25 »). Tout le reste est conforme : 0 runner double label, 0 VM non classée, 0 binding incohérent, capacité utilisable 4 PR + 2 trusted. |

Le ticket de drill doit ensuite nommer l'ID ARM exact de l'instance PR, prouver
`busy=false` et zéro job en file, définir la fenêtre et le rollback, puis recevoir
une approbation opérateur. Le workflow `Runner resilience drill` reste la preuve
GitHub, mais ce document n'autorise aucun arrêt ou redémarrage Azure.

### Drill du 2026-09-23 — arrêt, bascule, remise en ligne (instance PR)

Approuvé par l'orchestrateur par délégation de Gabriel, avec trois conditions : aucun job en
cours sur l'instance arrêtée, au moins deux autres runners PR en ligne pendant l'exercice,
instance remise en ligne à la fin. Instance :
`/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/RG-CERTIGO-CI/providers/Microsoft.Compute/virtualMachines/vmss-certigo-pr-pilot-z1_6e3abce4`
(runner 34 `certigo-prUL1UCK`).

| Heure (UTC) | Événement |
|---|---|
| 18:34:16 | prévol : runner 34 `online`, `busy=false` ; 0 run en file, 0 en cours ; 3 autres runners PR `online` |
| 18:34:19 → 18:34:59 | `az vm deallocate` (40 s) → `PowerState/deallocated` |
| 18:35:17 | runner 34 `offline` côté GitHub (premier sondage) |
| 18:35:16 → 18:47:14 | **bascule** : 68 jobs `certigo-pr` exécutés par les trois autres runners (`certigo-pr7BZU76` 35, `certigo-prMVOC2P` 20, `certigo-prTRHQEY` 13), dont toute la CI de #513 ; 15 jobs trusted sur `f55d176e`/`be505fa1` |
| 18:36:18 → 18:36:23 | `Runner resilience drill` (run `35903619428`, `expected_offline_runner=certigo-prUL1UCK`) : `success` sur `vmss-certigo-runner-zonal_be505fa1-Certigo` |
| 18:39:58 | reprise déclenchée à la main (même déclencheur que 01:30 UTC), run `08584114180865363275771379711CU123` |
| 18:39:59 → 18:47:31 | `start` de `6e3abce4` par la reprise dynamique (7 min 32 s) ; les cinq autres instances déjà allumées : 12 s |
| 18:46:21 | premier job repris par le runner 34 (`Select CodeQL languages`, run `35904765960`) |
| 18:48:03 | run de reprise `Succeeded`, trois `Fail_*` en `Skipped` ; runner 34 `online`, `busy=false` à 18:48:12 |

Durées : indisponibilité du runner 34 ≈ 12 min (dont 5 min d'attente volontaire avant la
reprise) ; reprise complète 8 min 05 s ; **aucune gate bloquée** : la file PR n'a jamais
attendu, trois runners de la classe restant disponibles. Permissions, fork guards et
environnements n'ont pas été modifiés.

> ⚖️ **Reconstruction depuis zéro : le compromis, dit franchement.** Recréer une instance PR
> depuis `pilot.bicep` exige que l'IMDS soit joignable pendant le provisionnement (section
> « Cause racine des instances PR mortes », point 2). Or la balise `AzurePlatformIMDS` ne peut
> être ni autorisée ni restreinte à quelques sources (refus Azure mesurés le 2026-09-14) :
> réutiliser le réseau du pool en service, c'est lever le blocage NSG pour **tout** le
> sous-réseau. Pendant cette fenêtre (2 min 08 s le 2026-09-14), les runners PR déjà en service
> ne gardent que la couche OS (`certigo-block-imds.service`, iptables), que le compte `runner`
> ne peut pas retirer (sudo limité). Aucun jeton n'est exposable : le VMSS PR n'a pas
> d'identité managée (mesuré le 2026-09-23) ; l'IMDS ne livrerait que des métadonnées.
>
> Deux façons de reconstruire :
> - **sans compromis (recommandée ; exécutée le 2026-09-25, voir la section suivante)** :
>   déployer le nouveau VMSS dans une
>   **pile réseau neuve**. `pilot.bicep` paramètre déjà `vnetName`, `subnetName`, `nsgName`,
>   `natGatewayName`, `natPublicIpName` et les plages d'adresses : la nouvelle instance a
>   donc son propre NSG, levé puis reposé sans jamais toucher la règle du pool en service.
>   Coût : une NAT et une IP publique de plus pendant la cohabitation (~36,50 USD/mois selon
>   l'estimation du 2026-08-20 dans `infra/ci-runner/README.md`). Ne pas réutiliser le VNet
>   existant avec un autre sous-réseau : son tableau `subnets` inline demanderait la
>   suppression du sous-réseau en service ;
> - **avec compromis borné** : réutiliser le réseau existant, seulement sans job PR en cours
>   (drainage ou fenêtre creuse), la règle neutralisée le moins longtemps possible.
>
> Dans les deux cas, `register-pilot.ps1` refuse de demander un jeton tant que la règle
> `deny-imds-outbound` ne vise pas `AzurePlatformIMDS` en `Deny`, puis `pilot-register.sh`
> refuse tant que l'IMDS répond depuis l'instance. Ce drill n'a exécuté aucune
> reconstruction : la dernière réelle date du 2026-09-14 (quatre instances, Activity Log, avec
> le compromis) ; celle du 2026-08-06 (run `31090379901`) visait les anciennes VM.

### Drill du 2026-09-25 — reconstruction depuis la définition versionnée

Accordé par l'orchestrateur par délégation de Gabriel le 2026-09-24, exécuté après la fin de la
promotion prod et après la suppression des sept instances retirées. Conditions : le runner
temporaire ne doit pouvoir prendre aucun job réel ; il est retiré côté GitHub et le groupe dédié
est supprimé à la fin, avec preuves ; durée d'au plus 4 h et coût inférieur à 1 USD.

**Entrées.**
- `infra/ci-runner/pilot.bicep` et `bootstrap.sh` de `main` (`4d9db321` ; `bootstrap.sh` =
  blob `43686478`, SHA-256 `16e12b8b…` ; tag `bootstrapSha256` `6e798d4e…`). Une enveloppe
  d'abonnement, non versionnée, crée uniquement le groupe `rg-certigo-ci-rebuild-drill` et y
  déploie ce module tel quel.
- VMSS `vmss-certigo-pr-rebuild-drill` : capacité 1, zone 1, `Standard_D2ads_v6`, image
  `24.04.202608070`.
- **Pile réseau neuve** `10.44.0.0/16` : VNet, NSG, NAT et IP dédiés, aucun peering. Le pool
  en service et sa règle IMDS n'ont jamais été touchés.
- Clé SSH : la clé publique déjà présente dans le modèle live, donc aucun nouveau credential ;
  SSH n'a jamais été utilisé.

| Heure (UTC) | Événement |
|---|---|
| 08:57:30 → 08:57:49 | what-if d'abonnement avec `blockImdsAtNsg=false` : exactement 6 `Create` (groupe, VMSS, NAT, NSG, IP, VNet), aucun `Modify` ni `Delete`, rien hors du groupe dédié |
| 08:57:49 → 08:59:01 | déploiement `certigo-rebuild-drill-20260925085730` `Succeeded` en 1 min 04 s ; instance `vmss-certigo-pr-rebuild-drill_92b77e8a` (`certigo-prUBLL6E`) créée à 08:58:24, `provisioningState: Succeeded` |
| 09:42:15 | contrôles : aucune identité, aucune IP publique, Trusted Launch, aucun peering, aucun verrou ; NSG encore sans règle IMDS (attendu à ce stade) |
| 09:42:39 → 09:43:12 | `pilot-preflight.sh` par Run Command, sans jeton : marqueur `pre-registration preflight passed` |
| 09:43:31 → 09:43:50 | what-if avec `blockImdsAtNsg=true` : seul vrai changement, la création de `deny-imds-outbound` ; le reste est le bruit connu (valeurs injectées par Azure, expressions que le what-if n'évalue pas) |
| 09:44:17 → 09:44:53 | déploiement : `deny-imds-outbound` en `Deny`, `Outbound`, `AzurePlatformIMDS`, source `*`, priorité 100 ; VMSS resté en `Manual`, capacité 1 |
| 09:44:59 → 09:45:31 | preflight rejoué : vert |
| 09:45:55 | preuve de non-ciblage : sur 649 refs (toutes les branches d'origin et tous les `refs/pull/*/head`), 0 workflow cite `certigo-rebuild-drill` ; les 4 `runs-on` de `main` exigent tous `self-hosted` ; aucun `runs-on` dynamique |
| 09:46:13 → 09:46:59 | `register-pilot.ps1 -RebuildDrill` : runner **35** `certigo-prUBLL6E` online, avec un **seul label**, `certigo-rebuild-drill` (type `custom`). GitHub affiche `os=unknown` faute de labels par défaut. Aucune ressource Run Command résiduelle |
| 09:47:19 → 09:47:52 | `pilot-health.sh` vert : un seul service runner, actif ; IMDS injoignable ; outils et egress GitHub, NuGet, pub.dev et npm OK |
| 09:48:17 → 10:03:30 | observation : runner 35 `online`, `busy=false` aux 15 sondages, pendant que les 4 runners `certigo-pr`, puis aussi un runner trusted, exécutaient de vrais jobs |
| 10:05:07 | bilan : 47 runs et 133 jobs créés depuis l'enregistrement dans les deux dépôts ; 94 jobs affectés, tous aux 6 runners habituels, **0 au runner 35**. 9 jobs `certigo-pr` attendaient en file alors que le runner 35 était libre |
| 10:05:29 | runner 35 supprimé côté GitHub ; `GET .../runners/35` rend 404 |
| 10:05:53 → 10:13:30 | contrôle du groupe (tag `purpose=wp-p2-07-rebuild-drill`, 8 ressources, toutes du drill, aucun verrou), puis `az group delete` en 7 min 38 s ; `az group show` rend `ResourceGroupNotFound` ; les 6 runners d'origine sont toujours online |

**Résultat.** Une instance PR neuve, construite uniquement depuis la définition versionnée
de `main`, a passé le preflight et la santé, puis s'est enregistrée. Elle respectait
l'isolation attendue : pas d'identité, pas d'IP publique, IMDS bloqué par l'OS puis par le
NSG, pile réseau non appairée. La reconstruction depuis la définition versionnée est donc
**prouvée**, sans compromis sur le pool en service.

**Coût et durée.** Les ressources ont existé environ 1 h 16 min, pour **au plus 0,28 USD**.
Tarifs retail West Europe relus le 2026-09-25 : VM D2ads v6 à 0,138 USD/h, IP à 0,005 USD/h,
disque P10 à 21,68 USD/mois. Le NAT Gateway n'est pas rendu par l'API : majorant retenu de
0,05 USD/h. Les opérations mesurées (déploiement, preflights, règle NSG, enregistrement)
totalisent environ 3 min 30 s.

**Bornes.**
- La durée du bootstrap n'est pas mesurée : le premier preflight a été lancé 43 min après la
  création de l'instance, à cause d'une interruption de session, et cloud-init était terminé
  depuis longtemps.
- Une instance, une zone, une image, un instant.
- Par condition, le runner n'a exécuté aucun job. L'exécution de jobs réels reste prouvée par
  le pool en service, qui exécute un autre bootstrap (voir « Les runners PR exécutent un
  bootstrap jamais revu »).
- Le pool PR en service n'a pas été remplacé. Le reconstruire sous un nom neuf, depuis cette
  définition, demande une décision séparée.
- L'enregistrement reste manuel, par conception : aucun credential GitHub dans Azure.
- Les deux déploiements d'abonnement `certigo-rebuild-drill-*` restent dans l'historique
  comme trace ; ils ne coûtent rien.

## Résilience exclusivement Azure

Les runners hébergés par GitHub sont durablement indisponibles et aucun chemin de
break-glass ne doit les cibler. Les deux runners Azure ne sont pas interchangeables : `certigo-pr` absorbe tout code ou
donnée PR, `certigo-trusted` les opérations et gates sans source PR. Un job reste bloqué
jusqu'à restauration d'une VM saine de sa propre classe ; aucun fallback de classe n'existe.

## Reconstruction, rotation et révocation

- **Reconstruction** : si une VM runner devient irrécupérable, reprovisionner une VM
  Linux dans `RG-CERTIGO-CI`, la raccorder au sous-réseau exclusif de sa classe,
  réappliquer le bootstrap idempotent, puis réenregistrer le runner GitHub avec son
  unique label de rôle `certigo-pr` ou `certigo-trusted`.
- **Rotation** : lors de la rotation d'un outil, d'un certificat ou d'un accès
  managé, mettre à jour la documentation opérateur correspondante puis valider la VM
  reconstruite avec la sonde quotidienne et le drill manuel.
- **Révocation** : supprimer immédiatement l'enregistrement GitHub d'un runner
  compromis, révoquer les accès Azure associés (identité managée / rôles) puis
  reconstruire une VM propre avant réintégration au pool.

## Rollback

Réactiver ou reconstruire le runner Azure avec son label de rôle fixe. Ne jamais
réaffecter temporairement le label de l'autre classe pour contourner une indisponibilité.
