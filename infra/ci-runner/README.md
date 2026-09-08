# Runners CI — Infrastructure-as-Code

Ce dossier réconcilie en Bicep les **VM GitHub Actions auto-hébergées** de Certigo et
leur **chemin d'egress (sortie Internet)**. Tout y est nommé en français pour rester aligné
avec le reste des livrables ; les noms de ressources Azure reprennent ceux du portail.

## Pourquoi

Les runners hébergés par GitHub sont **désactivés par la politique d'entreprise EMU**.
L'inventaire live consolidé au 20 août 2026 montre désormais un VMSS flexible
`vmss-certigo-runner-zonal` et non les deux VM autonomes historiques. Le dossier reste une
référence de reconstruction; il ne doit pas être appliqué à ce VMSS sans migration approuvée.
Le runbook de redondance, de moindre privilège et de preuve opérationnelle est dans
[`docs/CI_RUNNER_RESILIENCE.md`](../../docs/CI_RUNNER_RESILIENCE.md).

Le live comporte une NAT Gateway, un Load Balancer et un autoscale CPU. La réconciliation
classe le runner historique 26 (`22f7fb52-Certigo`) et la VM `4153d1dd` hors scope, les
bindings exacts f55/runner 27 et bbf/runner 28 comme gérés (running/online).
Ces entrées externes ne sont ni comptées ni ciblées; toute autre VM non réconciliée bloque le plan.
`network.bicep`
décrit l'ancienne réconciliation et son déploiement est suspendu; seul son `what-if`
read-only est autorisé.

## Modèle historique versionné (pas l'état live)

```
vm-certigo-runner (carte réseau, pas d'IP publique)
        │
        ▼
sous-réseau snet-runners (10.42.1.0/24)
        │   défaut sortant désactivé (defaultOutboundAccess = false)
        ▼
Passerelle NAT nat-certigo  ──►  IP publique pip-certigo-nat (20.86.156.64)
                                         │
                                         ▼
                                      Internet
```

| Ressource | Type | Rôle |
| --- | --- | --- |
| `pip-certigo-nat` | IP publique (Standard, statique, régionale) | Adresse d'egress **stable** présentée à Internet (à mettre en liste d'autorisation) |
| `nat-certigo` | Passerelle NAT (Standard) | SNAT sortant déterministe ; **survit à la désallocation** de la VM |
| `vnet-certigo-ci` | Réseau virtuel (`10.42.0.0/16`) | Héberge le sous-réseau runner |
| `snet-runners` | Sous-réseau (`10.42.1.0/24`) | La carte réseau du runner s'y rattache ; associé à la Passerelle NAT + NSG |
| `vnet-certigo-ci-snet-runners-nsg-westeurope` | Groupe de sécurité réseau (NSG) | Vide (règles Azure par défaut) ; conservé pour matcher l'état réel |

Le schéma et les noms ci-dessous décrivent `network.bicep`. Ils ne correspondent plus au
VMSS/NAT/LB live et ne constituent pas une autorisation de déploiement.

## Périmètre IaC historique

Trois modèles complémentaires sont versionnés :

- `network.bicep` réconcilie l'egress partagé sans toucher aux VM existantes ;
- `runner.bicep` reconstruit une VM, sa NIC privée, son disque et son identité managée.
  Il référence le sous-réseau existant et exécute `bootstrap.sh` au premier démarrage.
- `pilot.bicep` crée un VMSS Flexible PR-only dans un VNet dédié non appairé, avec son
  propre NAT/NSG. Il n'accorde aucune identité, IP publique, route privée applicative ou
  label trusted.

`runner.bicep` sert à créer une nouvelle instance ou à reconstruire une instance
préalablement supprimée. **Ne pas l'appliquer au nom d'une VM vivante** : les propriétés
de profil OS d'une VM existante sont immuables. Le runbook de reconstruction, les preuves
et le rollback sont dans
[`docs/CI_RUNNER_RESILIENCE.md`](../../docs/CI_RUNNER_RESILIENCE.md).

> ⚠️ **Ne jamais déployer ce modèle en mode « complet » (Complete)** : il supprimerait
> tout ce qui n'est pas listé (dont la VM, sa carte réseau et son disque).

## Pilote PR-only isolé

Le pilote transitoire absorbe la file `certigo-pr` sans étendre la frontière de confiance.
Il reste persistant pour être piloté par le contrôleur de drain global ; la cible durable
reste un pool éphémère. Un même runner ne doit jamais porter à la fois `certigo-pr` et
`certigo-trusted`.

| Propriété | Valeur épinglée |
| --- | --- |
| VMSS | `vmss-certigo-pr-pilot-z1`, Flexible, capacité 1, zone 1 |
| Taille / disque | `Standard_D2ads_v6` / Premium SSD LRS 128 Gio |
| Image | `Canonical:ubuntu-24_04-lts:server:24.04.202608070` |
| Sécurité | Trusted Launch, Secure Boot, vTPM, chiffrement hôte |
| Réseau | `10.43.0.0/16`, sous-réseau privé `10.43.1.0/24`, NAT dédié, aucun peering |
| Identité / métadonnées | aucune identité ; IMDS bloqué par iptables persistant puis NSG |
| Runner | `2.336.0`, SHA-256 `04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d` |
| Labels | `certigo-pr,certigo-pr-pilot` exclusivement |
| Bootstrap désiré | SHA-256 `6e798d4eeddc032eb948336cf17aef3539a91b8a33097b3cb877c4f3019c844c` du `customData` enveloppé |

Le bootstrap partagé ne bloque IMDS que lorsque `pilot.bicep` positionne explicitement
`CERTIGO_BLOCK_IMDS=true`. Une reconstruction trusted conserve ainsi son accès à
l'identité prévue par `runner.bicep`, tandis que le pilote PR échoue fermé.

### Séquence de provisionnement et d'enregistrement

> **Avant tout redéploiement complet : vérifier la dérive du bootstrap.**
>
> `pilot.bicep` livre le bootstrap via `customData`. Un déploiement du modèle
> complet le réécrit donc **sur les instances existantes**, pas seulement sur la
> nouvelle. Si le bootstrap du dépôt a changé depuis le dernier déploiement, la
> procédure ci-dessous — pourtant correcte — reconstruit les runners en service.
>
> `customData` est **write-only** : `az vmss show` rend `False`, ce qui n'est pas
> une absence mais une impossibilité de lecture. La dérive se révèle par le
> `what-if`, en comparant le `bootstrapSha256` déployé à celui du dépôt :
>
> ```bash
> az deployment group what-if \
>   --subscription <SUBSCRIPTION_ID> \
>   --resource-group RG-CERTIGO-CI \
>   --template-file infra/ci-runner/pilot.bicep \
>   --parameters imageVersion="$IMAGE_VERSION" \
>                adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
>                blockImdsAtNsg=true \
>   | grep -A2 bootstrapSha256
> ```
>
> Si les deux empreintes diffèrent, **ne pas déployer le modèle complet** :
> traiter la dérive séparément, ou opérer de façon ciblée (`az vmss scale`,
> mise à jour d'une seule ressource). Une dérive était présente au moment de
> l'ajout de la deuxième instance PR ; c'est pourquoi ce scale-out n'a pas
> emprunté la voie documentée ci-dessous.

Toujours utiliser un nom de VMSS neuf et le mode incrémentiel. Le premier déploiement
laisse temporairement la règle NSG IMDS absente pour que l'agent Azure et cloud-init
terminent ; il ne contient aucun jeton et le bootstrap installe immédiatement le bloc OS.

```bash
IMAGE_VERSION=24.04.202608070
PILOT_VMSS=vmss-certigo-pr-pilot-z1

bicep build infra/ci-runner/pilot.bicep --stdout >/dev/null
az deployment group what-if \
  --subscription <SUBSCRIPTION_ID> \
  --resource-group RG-CERTIGO-CI \
  --template-file infra/ci-runner/pilot.bicep \
  --parameters imageVersion="$IMAGE_VERSION" \
               adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
               blockImdsAtNsg=false
az deployment group create \
  --subscription <SUBSCRIPTION_ID> \
  --resource-group RG-CERTIGO-CI \
  --mode Incremental \
  --template-file infra/ci-runner/pilot.bicep \
  --parameters imageVersion="$IMAGE_VERSION" \
               adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
               blockImdsAtNsg=false
```

Après `Provisioning succeeded`, exécuter `pilot-preflight.sh` comme Managed Run Command
sans paramètre protégé. Son succès prouve dans cet ordre : cloud-init terminé, service
iptables actif, IMDS inaccessible, outils/egress publics sains et absence de `.runner`.
Ne demander aucun token avant ce marqueur.

Appliquer ensuite le deny NSG final, après un second `what-if` qui ne doit modifier que
`nsg-certigo-pr-pilot`, puis réexécuter le preflight :

```bash
az deployment group what-if \
  --subscription <SUBSCRIPTION_ID> \
  --resource-group RG-CERTIGO-CI \
  --template-file infra/ci-runner/pilot.bicep \
  --parameters imageVersion="$IMAGE_VERSION" \
               adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
               blockImdsAtNsg=true
az deployment group create \
  --subscription <SUBSCRIPTION_ID> \
  --resource-group RG-CERTIGO-CI \
  --mode Incremental \
  --template-file infra/ci-runner/pilot.bicep \
  --parameters imageVersion="$IMAGE_VERSION" \
               adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
               blockImdsAtNsg=true
```

`register-pilot.ps1` vérifie alors VMSS, power state, absence d'identité/IP publique et
deny NSG ; il relance le preflight **avant** de demander le token repo-scoped. Le token
reste en mémoire dans le processus PowerShell, passe à ARM comme `protectedParameter`
sans nom (argument positionnel `$1` côté Linux), puis la ressource Run Command est
supprimée. Ne jamais ajouter le token à une ligne de commande, un fichier, `customData`,
une variable d'environnement ou un journal.

Le verrou `CanNotDelete` posé sur `rg-certigo-ci` bloque cette suppression comme il bloque
le scale-in : sa portée est toute opération `delete` du groupe, pas seulement les VM. Le
script le signale et poursuit ; les ressources Run Command résiduelles s'accumulent alors
silencieusement et doivent être supprimées dans une levée de verrou explicite.

```powershell
.\infra\ci-runner\register-pilot.ps1 `
  -SubscriptionId <SUBSCRIPTION_ID> `
  -VmName <NEW_FLEX_VM_NAME>
```

Terminer avec `pilot-health.sh` comme Managed Run Command sans secret et vérifier via
l'API GitHub : runner `online`, labels exacts, service actif, IMDS inaccessible et egress
GitHub/NuGet/pub.dev/npm fonctionnel. Le pilote ne crée volontairement aucun runner dans
`certigo-content`.

La sortie structurée de `register-pilot.ps1` fournit l'`id` et le `name` GitHub. Avant toute
activation future du contrôleur, reporter ces deux valeurs avec le nom et l'ID ARM exacts de
la nouvelle VM dans `inventory.managedRunnerBindings`, puis mettre à jour les assertions de
`infra/tests/least-privilege.test.mjs` et l'inventaire
`docs/runbooks/CLOUD_LEAST_PRIVILEGE.md`. Un nom de runner Flexible diffère du nom de VM :
sans binding explicite, le contrôleur doit rester bloqué. Ne jamais réutiliser le binding d'une
instance pilote remplacée ni retirer les exclusions du runner 26 et de la VM `4153d1dd`.

### Coût retail estimé

Estimation Azure Retail Prices du 2026-08-20, West Europe, Linux PAYG, 730 h/mois,
hors taxes, remises, Savings Plan et transfert sortant :

| Poste | Prix unitaire USD | Estimation mensuelle USD |
| --- | ---: | ---: |
| `Standard_D2ads_v6` | 0,138/h | 100,74 |
| Premium SSD P10 LRS 128 Gio | 21,68/mois | 21,68 |
| NAT Gateway Standard | 0,045/h | 32,85 |
| IP publique Standard IPv4 | 0,005/h | 3,65 |
| **Total allumé 730 h** |  | **158,92** |

Ajouter `0,045 USD/Go` traité par le NAT et le transfert Internet sortant. Quand la VM
est désallouée par le contrôleur après quiet period, le compute s'arrête mais disque,
NAT et IP persistent : socle estimé **58,18 USD/mois**, puis `0,138 USD` par heure de VM.

### Rollback ciblé

Ne jamais lancer le rollback pendant qu'un job est `busy`. Après accord du propriétaire
du lifecycle, supprimer d'abord uniquement l'enregistrement GitHub du pilote, puis la VM
Flexible exacte, son VMSS et son réseau dédié. Ne jamais cibler `f55d176e` ni
`4153d1dd`.

```bash
RUNNER_ID="$(gh api repos/gchambaud_microsoft/Certigo/actions/runners \
  --jq '.runners[] | select(.labels[].name == "certigo-pr-pilot") | .id')"
gh api --method DELETE \
  "repos/gchambaud_microsoft/Certigo/actions/runners/$RUNNER_ID"

az vm delete -g RG-CERTIGO-CI -n <EXACT_NEW_FLEX_VM_NAME>
az vmss delete -g RG-CERTIGO-CI -n vmss-certigo-pr-pilot-z1
az network vnet delete -g RG-CERTIGO-CI -n vnet-certigo-pr-pilot
az network nsg delete -g RG-CERTIGO-CI -n nsg-certigo-pr-pilot
az network nat gateway delete -g RG-CERTIGO-CI -n nat-certigo-pr-pilot
az network public-ip delete -g RG-CERTIGO-CI -n pip-certigo-pr-pilot-nat
```

Confirmer ensuite `ResourceNotFound` pour chaque ID pilote et relire les états Azure et
GitHub de `f55d176e`/`4153d1dd`. La clé break-glass privée est détruite hors dépôt.

## Configuration reproductible et provenance

La reconstruction n'utilise ni image mutable implicite, ni jeton dans l'IaC :

- `imageVersion` est obligatoire et doit être une version Marketplace exacte ;
- les tags et sorties Azure enregistrent la version d'image et le SHA-256 du bootstrap
  réellement incorporé ;
- les tags supplémentaires sont conservés, puis le contrat canonique
  `owner/product/env/managedBy/costCenter` de `infra/finops/scopes.json` prévaut
  sur toute collision avec des valeurs CI non personnelles ;
- Ubuntu 24.04, Trusted Launch, Secure Boot, vTPM et un disque Premium de 128 Gio sont
  déclarés ;
- `allowExtensionOperations: false` interdit l'installation d'extensions VM ; le bootstrap
  cloud-init versionné reste l'unique mécanisme de configuration de l'instance ;
- `availabilityZone` permet de répartir les instances redondantes entre zones ;
- le runner GitHub `2.336.0` est téléchargé depuis la release officielle et vérifié avec
  son SHA-256 publié dans l'API GitHub ; la mise à jour automatique est désactivée et une
  nouvelle version épinglée est réconciliée lors de la réexécution du bootstrap ;
- Azure CLI `2.89.0` vient du dépôt APT Microsoft signé ; la clé initiale est refusée si
  son empreinte ne correspond pas à l'empreinte versionnée ;
- les téléchargements directs de Bicep et d'actionlint dans les workflows sont eux aussi
  refusés si leur SHA-256 officiel ne correspond pas ;
- les actions tierces du probe quotidien et les checkouts des workflows modifiés sont
  épinglés à leur SHA de commit complet, avec le tag majeur conservé en commentaire ;
- le jeton d'enregistrement GitHub, éphémère, n'entre jamais dans Bicep, `customData`, un
  fichier, l'environnement du service ou l'historique de commande ; il est lu au moment de
  l'enregistrement depuis le terminal ou l'entrée standard et détruit dès que `config.sh`
  termine ;
- le bootstrap est idempotent : paquets, binaire, configuration et service sont
  réconciliés, tandis qu'un changement implicite de dépôt ou de nom est refusé ;
- l'utilisateur de service ne dispose d'aucun accès administrateur général. Sa seule
  allow-list `sudo` sans mot de passe contient `apt-get update`, l'installation exacte de
  `unzip zip jq xz-utils` requise par les jobs existants (avec uniquement
  `DEBIAN_FRONTEND` conservé), et `/usr/local/sbin/certigo-runner-restart`, un programme
  root-owned sans argument qui ne redémarre que l'unique service `actions.runner.*`.
  Les installations de paquets hors cette liste et les enregistrements sont réservés au
  compte administrateur break-glass ; le fork-guard et l'approbation `pr-ci` restent des
  contrôles obligatoires avant toute exécution de code de PR.

Les SDK de workload restent épinglés par les actions de setup de chaque workflow. Le
workflow quotidien `runner-health.yml` les installe puis vérifie GitHub, NuGet, pub.dev,
npm, Azure, l'espace disque et les commandes nécessaires.

Le livrable PR1 de préchauffage immuable est isolé sous
[`image/`](./image/README.md). Il ajoute manifest, SBOM, lock Python, attestation,
validation boot fail-closed, hooks de disque temporaire one-job et mesures, mais
ne câble aucune image dans `runner.bicep`, `pilot.bicep` ou le VMSS live. La
création Azure Compute Gallery, le `what-if` relu et le canari appartiennent
explicitement à une PR2 séparée.

## Capacité et cycle de vie

Le VMSS live est `Standard_D2ads_v6`, autoscale min 2 / défaut 2 / max 4. Son scale-in CPU
est dangereux car il ignore GitHub `busy`, et les runners portent simultanément
`certigo-pr` et `certigo-trusted`. Toute automation mutable est donc bloquée.

Le script `lifecycle-preflight.sh` inventorie sans mutation et refuse une déallocation en
présence d'un label double, d'un job actif/en file, d'un scale-in CPU ou d'un écart entre VM
et runners. La cible sérialisée et son rollback sont dans
[`docs/runbooks/CLOUD_LEAST_PRIVILEGE.md`](../../docs/runbooks/CLOUD_LEAST_PRIVILEGE.md).

> **Dette nommée : ce garde n'est appelé par rien, et ce qui le compense est accidentel.**
> Aucun workflow n'invoque `lifecycle-preflight.sh` ; la boucle de validation ne fait qu'un
> `bash -n` dessus, qui établit que le fichier se lit et jamais qu'il s'exécute. Le risque est
> aujourd'hui neutralisé non par ce garde mais par le verrou `CanNotDelete` posé sur le groupe
> de ressources, qui rend tout scale-in impossible. Les deux protections sont donc
> **couplées par accident et non par conception** : le jour où quelqu'un lèvera le verrou pour
> une opération légitime, il retirera du même geste la seule chose qui compense l'absence de ce
> garde, et le scale-in redeviendra possible sans qu'aucun contrôle ne relise `busy`.
> **Condition de sortie de la dette :** avant toute levée du verrou, `lifecycle-preflight.sh`
> doit avoir été exécuté au moins une fois pour de vrai, puis câblé en amont de la déallocation.

Le planificateur `capacity-plan.sh` ajoute une réconciliation de drift et un modèle
queue-driven `workflow_job` avec trois modes par classe (`idle=0+0`, `normal=1+1`,
`boost=6 PR + 2 trusted`). Cette cible est celle d'un pilote ultérieur, pas un plafond
de production final. Le feature flag est **off**; aucun code de mutation n'est présent.
L'état v3 exige power Azure + runner online, conserve le slot exact à réarmer, garde le runner
26 et la VM 415 hors scope et refuse les VMs 22f/459. Labels, frontières d'identité et
sous-réseaux exclusifs sont des prérequis. Le scale-in exige une quiet period resettable de
5 minutes, deux gardes, un lease à génération stable et un compare-and-swap de révision.
La garde finale relit `busy` et les jobs; le pilote PR est désalloué avant le primaire trusted.
Le réarmement de tous les slots supprimés ne devient obligatoire qu'à la première activité
postérieure. Le baseline 30 jours est
242,06 USD pour 413 jobs, 18,84 runner-heures, 3,78 % CPU moyen, avec une file P95 de
5 108 s et P99 de 12 628 s.

### Ajouter une instance au pilote PR

> **Prérequis : la règle NSG `deny-imds-outbound` doit être retirée pendant le
> provisionnement, puis reposée.** Ce n'est pas un détail d'exécution — sans ce
> retrait, l'opération échoue par `OSProvisioningInternalError` après une
> trentaine de minutes, et le symptôme ne nomme jamais l'IMDS. L'opérateur qui
> l'ignore conclut que le VMSS est cassé.

La cause est que l'agent invité Azure interroge l'IMDS pour terminer le
provisionnement. La règle fait donc exactement ce qu'elle annonce, y compris
contre l'agent. Le contraste a été mesuré dans les deux sens sur ce VMSS : avec
la règle, échec ; sans la règle, `Succeeded` en une poignée de secondes.

Le blocage OS installé par `bootstrap.sh` (`certigo-block-imds.service`,
`iptables -j REJECT` sur `169.254.169.254/32`) ne couvre pas ce moment : il est
posé *par* le bootstrap, donc après que le réseau du premier démarrage est déjà
monté. C'est précisément le trou que la règle NSG existe pour couvrir, et c'est
celui qu'on rouvre en la retirant.

Ce que l'exposition ne peut pas atteindre, et qu'il faut vérifier avant d'ouvrir
la fenêtre plutôt que de le supposer :

- le VMSS pilote **ne déclare aucune identité gérée**, donc l'IMDS n'y délivre
  aucun jeton — le contrôle est `az vmss list ... --query "[].identity.type"`,
  à lire face au pool trusted qui, lui, en déclare une ; deux valeurs
  différentes dans la même sortie prouvent que la requête discrimine ;
- aucun runner n'est encore enregistré sur l'instance neuve, donc aucun code de
  PR ne s'exécute pendant la fenêtre ;
- `pilot-register.sh` refuse l'enregistrement tant que l'IMDS répond, donc la
  règle reposée est une condition d'entrée et pas une formalité de sortie.

Mesurer la fenêtre réelle après coup, plutôt que l'estimer, en lisant le journal
d'activité — la durée d'une commande `az` n'est **pas** la durée d'absence de la
règle, les deux se lisent différemment :

```bash
az monitor activity-log list \
  --subscription <SUBSCRIPTION_ID> \
  --start-time <ISO8601> --end-time <ISO8601> \
  --max-events 1000 -o json |
  jq -r '.[] | select(.operationName.value | test("securityRules"))
         | [.eventTimestamp, .status.value, .operationName.value] | @tsv'
```

Ne pas passer `--offset` avec `--start-time` : la plage est alors annulée et la
commande rend zéro événement pour toute requête, ce qui se lit comme une absence.

> **`az vmss scale` peut sortir en échec alors que l'instance a été créée et
> qu'elle est facturée.** Relancer sans vérifier crée une instance fantôme de
> plus, absente de l'inventaire et de la liste de rallumage nocturne. Toujours
> relire `sku.capacity` et `az vm list` avant toute relance.

**Dette de conception, à ne pas entreprendre dans une opération de capacité.**
Le correctif propre n'est pas de lever la règle à chaque ajout, mais de la
restreindre pour laisser passer l'agent invité pendant la seule phase de
provisionnement. C'est un chantier de conception réseau — portée, source
autorisée, durée — pas une correction ponctuelle.

> À noter : le compte **Azure OpenAI** (`certigo-openai`), autre ressource en drift citée
> par le finding G, est lui **réintégré en IaC** dans ce livrable via
> `infra/modules/openai.bicep` (câblé dans `infra/main.bicep`, module `tutor`).

## Détection de dérive planifiée

`.github/workflows/runner-drift.yml` exécute chaque jour à 06:53 UTC, sur `certigo-trusted`
uniquement, la chaîne `inventory.sh` → `reconcile-drift.mjs` → `drift-gate.mjs`. Le détecteur
n'a jamais décidé de rien — `reconcile-drift.mjs` écrit son rapport et sort toujours `0` — donc
la décision vit dans `drift-gate.mjs`, à l'extérieur, sans toucher au contrat de sévérité que
les tests épinglent.

La gate est **fail-closed** : toute constatation de sévérité `blocking` fait échouer le
workflow, **sauf** celles nommées dans [`drift-gate.policy.json`](drift-gate.policy.json). Ce
fichier est la seule liste de tolérance, et chaque entrée y porte obligatoirement sa `reason`
et son `invalidatedWhen` — `readPolicy()` refuse à l'exécution une entrée à laquelle il manque
l'une ou l'autre. Une exception sans condition de sortie est une exception éternelle ; ici elle
ne peut pas être écrite.

Symétriquement, un acquittement **périmé** fait aussi passer la gate au rouge : si un code
toléré cesse d'être rapporté, le workflow échoue en demandant de retirer l'entrée devenue
sans objet. C'est ce qui empêche la liste de survivre à sa propre raison d'être.

> **Ce que la gate ne voit pas.** `reconcile-drift.mjs` ne lit ni `customData`, ni
> `osProfile`, ni `bootstrapSha256` — la dérive du script d'amorçage lui est structurellement
> invisible et aucune tolérance ne la masque. Voir le bloc dérive bootstrap plus haut.

## Nettoyage

Les quatre anciens candidats documentés ne sont plus présents dans l'inventaire live. Les
disques, NIC, IP, NAT, NSG et backends LB actuels ont des attachements prouvés. Aucune
suppression n'est planifiée. Une ressource sans preuve d'usage reste `non classée` tant que
les références ARM, RBAC, logs, propriétaires et rollback ne sont pas établis.

## Commande read-only

Valider sans rien changer. Le résultat doit être traité comme une preuve de drift; il n'est
plus présumé bénin :

```bash
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep
```

### Anciennes différences résiduelles

Avant la migration VMSS, le what-if affichait trois « suppressions » de propriétés.
Ce sont des **valeurs par défaut injectées par Azure** que l'API renvoie en lecture mais
que le modèle **ne peut pas** repositionner (propriétés réservées, en lecture seule, ou
absentes du schéma Bicep stable). Ces observations historiques ne permettent plus de
conclure sur le live actuel. Ne pas exécuter `az deployment group create`.

| Ressource | Propriété signalée | Pourquoi on ne la fige pas |
| --- | --- | --- |
| `nat-certigo` | `sku.tier` (= `Regional`) | Le type `NatGatewaySku` n'accepte que `name` ; `tier` n'existe pas dans le schéma. |
| `nat-certigo` | `properties.scope` (= `Public`) | Non réglable via modèle ; `Public` est déjà la valeur par défaut d'une Passerelle NAT. |
| `pip-certigo-nat` | `properties.ipTags` (`FirstPartyUsage` / `/Unprivileged`) | Étiquette **première-partie réservée** à Azure ; un déploiement qui tenterait de la poser serait **rejeté**. |

Les fausses différences réglables (`ddosSettings` héritée du VNet sur l'IP publique,
`privateEndpointVNetPolicies` sur le réseau virtuel) ont déjà été **explicitées** dans le
modèle : le réseau virtuel et le NSG ressortent donc en **« aucun changement »**.

La compilation des deux modèles, le contrat de tags, la syntaxe Bash et les tests du probe
sont vérifiés par `infra/validate.sh` et la gate `ci-infra`.
