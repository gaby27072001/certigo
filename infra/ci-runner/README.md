# Runners CI — Infrastructure-as-Code

Ce dossier réconcilie en Bicep la **capacité GitHub Actions auto-hébergée** de Certigo
et son **chemin d'egress (sortie Internet)**. Les instances VM restent hors ownership
IaC tant que leur classification n'est pas prouvée.

## Pourquoi

Les runners hébergés par GitHub sont **désactivés par la politique d'entreprise EMU**.
L'inventaire live consolidé au 4 septembre 2026 montre deux VMSS Flexible :
`vmss-certigo-runner-zonal` et `vmss-certigo-pr-pilot-z1`.
Le runbook de redondance, de moindre privilège et de preuve opérationnelle est dans
[`docs/CI_RUNNER_RESILIENCE.md`](../../docs/CI_RUNNER_RESILIENCE.md).

`f55d176e`/runner 27 (`certigo-trusted`) et `bbf83c5c`/runner 28
(`certigo-pr,certigo-pr-pilot`) sont running/online et ont été redémarrés le
3 septembre. `be505fa1` est restée `deallocated`, sans runner GitHub ni
classification : elle bloque toute automation et n'est ajoutée à aucune allow-list.
Les exclusions historiques du runner 26 et de `4153d1dd` restent des garde-fous,
pas une affirmation de présence live.

> État au 2026-09-23 : `be505fa1`/runner 29 est gérée; le pool PR est porté par
> `5275ea21`, `94bad106`, `1a6deaa2` et `6e3abce4` (runners 31 à 34), et `bbf83c5c` est
> retirée (voir `docs/runbooks/CI_RUNNERS.md` §2 et §11). Depuis le même jour, la reprise
> nocturne énumère les instances des deux scale sets à chaque run : aucune liste d'instances
> n'est plus à tenir à jour pour qu'une instance soit rallumée.

## Egress legacy réconcilié

```
vm-certigo-runner (carte réseau, pas d'IP publique)
        │
        ▼
sous-réseau snet-runners (10.42.1.0/24)
        │   défaut sortant désactivé (defaultOutboundAccess = false)
        ▼
Passerelle NAT nat-vm-certigo-runner-2
        └──────────────────────► IP publique pip-vm-certigo-runner-2-nat
                                 (20.4.178.183)
                                         │
                                         ▼
                                      Internet
```

| Ressource | Type | Rôle |
| --- | --- | --- |
| `pip-vm-certigo-runner-2-nat` | IP publique (Standard, statique, zones 1/2) | Adresse d'egress **stable** présentée à Internet |
| `nat-vm-certigo-runner-2` | Passerelle NAT (Standard) | SNAT sortant déterministe ; **survit à la désallocation** des VM |
| `vnet-certigo-ci` | VNet `existing` (`10.42.0.0/16` live) | Parent référencé sans réécrire ses trois peerings |
| `snet-runners` | Sous-réseau (`10.42.1.0/24`) | La carte réseau du runner s'y rattache ; associé à la Passerelle NAT + NSG |
| `vnet-certigo-ci-snet-runners-nsg-westeurope` | Groupe de sécurité réseau (NSG) | Vide (règles Azure par défaut) ; conservé pour matcher l'état réel |

## Périmètre IaC

Quatre modèles complémentaires sont versionnés :

- `network.bicep` référence l'IP, la NAT, le NSG et le VNet en `existing`,
  applique leurs tags par des extensions `Microsoft.Resources/tags` isolées et
  ne gère que le sous-réseau enfant ;
- `capacity.bicep` référence les deux VMSS en `existing` et gère uniquement
  l'autoscale legacy, avec scale-out CPU mais **aucun scale-in CPU** ;
- `runner.bicep` reconstruit une VM, sa NIC privée, son disque et son identité managée.
  C'est un modèle historique de reconstruction, pas le modèle du compute live ;
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
| VMSS | `vmss-certigo-pr-pilot-z1`, Flexible, zone 1 ; capacité : paramètre obligatoire `capacity`, sans défaut (voir « Vérifier aussi la capacité ») |
| Taille / disque | `Standard_D2ads_v6` / Premium SSD LRS 128 Gio demandé ; en service : `Standard_LRS`, rétrogradé par l'automate MCAPS le 2026-09-15 (voir `docs/CI_RUNNER_RESILIENCE.md`) |
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
> complet réécrit le `customData` **du modèle du VMSS**. Le VMSS PR est en
> orchestration `Flexible` avec `upgradePolicy: Manual` (mesuré le 2026-09-24).
> D'après la [documentation Azure](https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-upgrade-policy#manual-upgrade-policy-mode),
> *« nothing happens automatically to the existing virtual machines when changes
> occur to the scale set model »* ; seules les instances créées ensuite reçoivent
> le nouveau script. Si le bootstrap du dépôt a changé depuis
> le dernier déploiement, le pool mélange alors deux bootstraps selon la date de
> création des instances, ce qui est une dérive pour des runners censés être
> interchangeables.
>
> `customData` est **write-only** : `az vmss show` rend `False`, ce qui n'est pas
> une absence mais une impossibilité de lecture. La dérive se révèle par le
> `what-if`, en comparant le `bootstrapSha256` déployé à celui du dépôt :
>
> ```bash
> LIVE_CAPACITY="$(az vmss show --subscription <SUBSCRIPTION_ID> \
>   --resource-group RG-CERTIGO-CI --name vmss-certigo-pr-pilot-z1 \
>   --query sku.capacity --output tsv)"
> az deployment group what-if \
>   --subscription <SUBSCRIPTION_ID> \
>   --resource-group RG-CERTIGO-CI \
>   --template-file infra/ci-runner/pilot.bicep \
>   --parameters imageVersion="$IMAGE_VERSION" \
>                adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
>                runnerScaleSetName=vmss-certigo-pr-pilot-z1 \
>                capacity="$LIVE_CAPACITY" \
>                blockImdsAtNsg=true \
>   | grep -A2 -E 'bootstrapSha256|sku.capacity'
> ```
>
> Si les deux empreintes diffèrent, **ne pas déployer le modèle complet** :
> traiter la dérive séparément, ou opérer de façon ciblée (`az vmss scale`
> **vers le haut uniquement**, mise à jour d'une seule ressource). Une dérive était
> présente au moment de l'ajout de la deuxième instance PR ; c'est pourquoi ce
> scale-out n'a pas emprunté la voie documentée ci-dessous.
>
> **Vérifier aussi la capacité.** Depuis le 2026-09-23, `capacity` n'a plus de valeur
> par défaut : sur le VMSS existant, lui passer la valeur live (`LIVE_CAPACITY`
> ci-dessus). Le what-if du 2026-09-23, fait avec l'ancien défaut `capacity: 2`
> alors que le live affichait `sku.capacity = 8`, montrait un passage de 8 à 2 :
> un scale-in. Sous le verrou `CanNotDelete`, les suppressions refusées du
> 2026-09-11 ont laissé les deux instances saines visées en `Failed` (voir « Cause
> racine des instances PR mortes » dans `docs/CI_RUNNER_RESILIENCE.md`). Le what-if
> doit montrer `sku.capacity` inchangé avant tout déploiement.

Toujours utiliser un nom de VMSS neuf et le mode incrémentiel. Le premier déploiement
laisse temporairement la règle NSG IMDS absente pour que l'agent Azure et cloud-init
terminent ; il ne contient aucun jeton et le bootstrap installe immédiatement le bloc OS.

> 🔁 **Un nom de VMSS neuf doit rejoindre la reprise nocturne.** La reprise énumère les
> membres des seuls scale sets déclarés dans `scaleSets` (`infra/ci-runner/auto-recovery.bicep`),
> qui doivent rester égaux aux deux scale sets de `infra/ci-runner/capacity.bicep` (test
> « the recovery scope is declared once and follows the inventory »). Un nouveau VMSS sans
> ces deux mises à jour — puis un redéploiement de la reprise (`docs/runbooks/CI_RUNNERS.md`
> §11) — aurait des instances jamais rallumées après la désallocation nocturne. Avec les
> noms réseau par défaut, le même déploiement réutilise le VNet, le NSG et la NAT du pool en
> service : la règle IMDS retirée pour le provisionnement l'est donc aussi pour les runners PR
> déjà en service. Soit opérer sans job PR en cours, soit — sans ce compromis — passer des
> noms réseau et des plages d'adresses neufs (voir « Drill de perte d'un runner » dans
> `docs/CI_RUNNER_RESILIENCE.md`).

```bash
IMAGE_VERSION=24.04.202608070
# Nom NEUF : le VMSS vmss-certigo-pr-pilot-z1 existe déjà et ne doit pas être redéployé ici.
PILOT_VMSS=<NOUVEAU_NOM_VMSS>
PILOT_CAPACITY=<NOMBRE_D_INSTANCES_VOULU>

bicep build infra/ci-runner/pilot.bicep --stdout >/dev/null
az deployment group what-if \
  --subscription <SUBSCRIPTION_ID> \
  --resource-group RG-CERTIGO-CI \
  --template-file infra/ci-runner/pilot.bicep \
  --parameters imageVersion="$IMAGE_VERSION" \
               adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
               runnerScaleSetName="$PILOT_VMSS" \
               capacity="$PILOT_CAPACITY" \
               blockImdsAtNsg=false
az deployment group create \
  --subscription <SUBSCRIPTION_ID> \
  --resource-group RG-CERTIGO-CI \
  --mode Incremental \
  --template-file infra/ci-runner/pilot.bicep \
  --parameters imageVersion="$IMAGE_VERSION" \
               adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
               runnerScaleSetName="$PILOT_VMSS" \
               capacity="$PILOT_CAPACITY" \
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
               runnerScaleSetName="$PILOT_VMSS" \
               capacity="$PILOT_CAPACITY" \
               blockImdsAtNsg=true
az deployment group create \
  --subscription <SUBSCRIPTION_ID> \
  --resource-group RG-CERTIGO-CI \
  --mode Incremental \
  --template-file infra/ci-runner/pilot.bicep \
  --parameters imageVersion="$IMAGE_VERSION" \
               adminSshPublicKey="$(cat <BREAK_GLASS_PUBLIC_KEY>)" \
               runnerScaleSetName="$PILOT_VMSS" \
               capacity="$PILOT_CAPACITY" \
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

> 🧪 **Drill de reconstruction : un runner qui ne peut prendre aucun job réel.** Pour prouver
> la reconstruction sans exposer de vraie PR, déployer `pilot.bicep` dans le groupe dédié
> `rg-certigo-ci-rebuild-drill`, avec `runnerScaleSetName=vmss-certigo-pr-rebuild-drill`,
> `nsgName=nsg-certigo-pr-rebuild-drill` et des noms et plages réseau neufs. Puis enregistrer
> avec `-RebuildDrill` :
>
> ```powershell
> .\infra\ci-runner\register-pilot.ps1 `
>   -SubscriptionId <SUBSCRIPTION_ID> -VmName <DRILL_VM_NAME> -RebuildDrill `
>   -ResourceGroupName rg-certigo-ci-rebuild-drill `
>   -ScaleSetName vmss-certigo-pr-rebuild-drill `
>   -NetworkSecurityGroupName nsg-certigo-pr-rebuild-drill
> ```
>
> Le script remplace l'unique ligne `registration_mode='production'` de `pilot-register.sh`.
> Le runner s'enregistre alors avec `--no-default-labels --labels certigo-rebuild-drill` :
> un seul label, qu'aucun workflow ne cible (garde de `validate.sh`), sans `self-hosted`,
> `Linux` ni `X64`. Garde-fous :
> - `-RebuildDrill` est refusé hors de ces trois noms ;
> - sans `-RebuildDrill`, ces noms sont refusés ;
> - si le runner de la VM (nom = `computerName`) apparaît avec d'autres labels, il est
>   supprimé côté GitHub avant l'échec.
>
> Fin du drill : supprimer le runner (`gh api -X DELETE .../actions/runners/<ID>`), puis le
> groupe de ressources, et prouver l'absence des deux. Exécuté le 2026-09-25 : voir « Drill du
> 2026-09-25 — reconstruction depuis la définition versionnée » dans
> `docs/CI_RUNNER_RESILIENCE.md`.

La sortie structurée de `register-pilot.ps1` fournit l'`id` et le `name` GitHub. Avant toute
activation future du contrôleur, reporter ces deux valeurs avec le nom et l'ID ARM exacts de
la nouvelle VM dans `inventory.managedRunnerBindings` et `inventory.observedRunnerBindings`,
inscrire l'instance remplacée dans `inventory.forbiddenVirtualMachines`, puis mettre à jour
les assertions de `infra/tests/least-privilege.test.mjs` et l'inventaire
`docs/runbooks/CLOUD_LEAST_PRIVILEGE.md`, et redéployer le Logic App de reprise
(`docs/runbooks/CI_RUNNERS.md` §11) pour qu'il cesse de tenter l'instance retirée. La
nouvelle instance, elle, est rallumée chaque nuit sans autre action : la reprise énumère les
membres du scale set depuis le 2026-09-23. Un nom de runner Flexible diffère du nom de VM :
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

Les deux VMSS live sont `Standard_D2ads_v6`. L'autoscale legacy est min 2 /
défaut 2 / max 4. Son scale-out CPU (`> 70 %` pendant 10 minutes) est conservé
dans `capacity.bicep`; son scale-in CPU (`< 20 %` pendant 45 minutes) est retiré
du contrat car il ignore GitHub `busy`, et parce qu'un scale-in sous le verrou
`CanNotDelete` laisse l'instance visée en `Failed` (mesuré, voir « Cause racine des
instances PR mortes » dans `docs/CI_RUNNER_RESILIENCE.md`). Ce retrait est appliqué en
live depuis le 2026-09-23 à 18:01Z (déploiement `certigo-ci-capacity-20260923180037`).

Le script `lifecycle-preflight.sh` inventorie sans mutation les dépôts Certigo et
certigo-content et refuse une déallocation en présence d'un label double, d'un job actif/en
file, d'un scale-in CPU ou d'un écart entre VM et runners. Un run système Dependabot n'est
ignoré qu'après inspection de ses jobs, s'ils n'ont aucun runner et portent exclusivement le
label `dependabot`; toute information manquante ou cible self-hosted reste bloquante. Si toutes
les VM gérées exactes sont déjà explicitement `deallocated`, les trois registrations observées
sont non-busy et la file valide est vide, le résultat est terminal-safe et ne demande aucun
changement Azure, sans redémarrage artificiel ni quiet period rétroactive. Les autres dérives
restent rapportées et bloquent toute future mutation. La cible sérialisée et son rollback sont dans
[`docs/runbooks/CLOUD_LEAST_PRIVILEGE.md`](../../docs/runbooks/CLOUD_LEAST_PRIVILEGE.md).

Le planificateur `capacity-plan.sh` compare désormais le live à `capacity.bicep`,
puis ajoute une réconciliation de drift et un modèle
queue-driven `workflow_job` avec trois modes par classe (`idle=0+0`, `normal=1+1`,
`boost=6 PR + 2 trusted`). Cette cible est celle d'un pilote ultérieur, pas un plafond
de production final. Le feature flag est **off**; aucun code de mutation n'est présent.
L'état v3 exige power Azure + runner online, conserve le slot exact à réarmer, garde le runner
26 et la VM 415 hors scope et refuse les VMs 22f/459. La VM `be505fa1` n'est
volontairement dans aucune liste : son apparition reste bloquante. Labels, frontières d'identité et
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

> **« Retirée » ne veut pas dire supprimée.** Sous le verrou `CanNotDelete`, la
> suppression de la règle est refusée (`ScopeLocked`, 2026-09-14 à 09:21:49Z), et
> Azure refuse aussi de la passer en `Allow` ou de restreindre sa source. Le
> 2026-09-14, elle a été **neutralisée** en remplaçant sa destination par l'adresse de
> documentation `192.0.2.1/32` (09:24:52Z), puis rétablie vers `AzurePlatformIMDS`
> (09:27:01Z) : 2 min 08 s sans blocage IMDS au niveau NSG, pour tout le sous-réseau.

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
> plus, absente de l'inventaire. Depuis le 2026-09-23 elle serait en outre rallumée
> chaque nuit par la reprise (qui énumère le scale set) et facturée sans runner,
> jusqu'à son inscription dans `inventory.forbiddenVirtualMachines`. Toujours
> relire `sku.capacity` et `az vm list` avant toute relance.

> 🧟 **Ne jamais utiliser `az vmss scale` pour RÉDUIRE la capacité.** Sous le verrou
> `CanNotDelete`, chaque suppression demandée par le scale set est refusée
> (`ScopeLocked`) et l'instance visée finit en `provisioningState: Failed` à l'opération
> suivante : c'est ainsi que `bbf83c5c`, `a14700a3` et `d8d42366` sont mortes les
> 11-12 septembre 2026 (preuves : « Cause racine des instances PR mortes » dans
> `docs/CI_RUNNER_RESILIENCE.md`). Retirer une instance = supprimer la VM exacte dans une
> levée de verrou explicite (`docs/runbooks/CI_RUNNERS.md` §12).

**Dette de conception, à ne pas entreprendre dans une opération de capacité.**
Restreindre la règle pour laisser passer l'agent invité pendant la seule phase de
provisionnement est **impossible au niveau NSG** : mesuré le 2026-09-14 dans l'Activity
Log, Azure refuse pour la balise `AzurePlatformIMDS` toute règle `Allow`
(`SecurityRuleInvalidAccessType`) et toute source autre que `*`
(`InvalidDNSExfilSourceTag`). La seule voie sans affaiblir le pool en service est de
provisionner le nouveau VMSS dans une pile réseau neuve (VNet, NSG, NAT et IP de noms
neufs, tous paramètres de `pilot.bicep`), voir « Drill de perte d'un runner » dans
`docs/CI_RUNNER_RESILIENCE.md`.

> À noter : le compte **Azure OpenAI** (`certigo-openai`), autre ressource en drift citée
> par le finding G, est lui **réintégré en IaC** dans ce livrable via
> `infra/modules/openai.bicep` (câblé dans `infra/main.bicep`, module `tutor`).

> À noter : le compte **Azure OpenAI** (`certigo-openai`) est géré en dev
> indépendamment du feature flag runtime. Le compte et son modèle sont déclarés ;
> le projet Foundry et le private endpoint sont seulement référencés `existing`
> jusqu'à preuve d'ownership complète. L'endpoint Foundry
> `*.services.ai.azure.com` annonce `10.60.0.76` sur le private endpoint, mais
> seule la zone `privatelink.openai.azure.com` existe et aucun zone group n'est
> attaché. Le module ne revendique donc aucune zone DNS et l'activation runtime
> reste bloquée jusqu'à adoption séparée de `privatelink.services.ai.azure.com`,
> de son enregistrement, de son lien VNet et de son zone group.

## Nettoyage

Les disques, NIC, IP, NAT, NSG et backends LB actuels ont des attachements
prouvés. Aucune suppression n'est planifiée. `be505fa1` reste non classifiée tant
que ses références ARM, RBAC, journaux, propriétaire et rollback ne sont pas établis.

## Commande read-only

Valider sans rien changer. Le résultat doit être traité comme une preuve de drift; il n'est
plus présumé bénin :

```bash
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep \
  --validation-level Provider
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/capacity.bicep \
  --validation-level Provider
```

Attendu avant application : aucune création d'infrastructure ni suppression,
aucune écriture du VNet parent, de l'IP, de la NAT, du NSG ou des VMSS. Les
seuls changements admis sont les extensions de tags FinOps sur IP/NAT/NSG, les
tags de l'autoscale et la suppression de la règle de scale-in CPU.

### Valeurs injectées par Azure

Avant la migration VMSS, le what-if affichait trois « suppressions » de propriétés.
Ce sont des **valeurs par défaut injectées par Azure** que l'API renvoie en lecture mais
que le modèle **ne peut pas** repositionner (propriétés réservées, en lecture seule, ou
absentes du schéma Bicep stable). Ces observations historiques ne permettent plus de
conclure sur le live actuel. Ne pas exécuter `az deployment group create`.

| Ressource | Propriété signalée | Pourquoi on ne la fige pas |
| --- | --- | --- |
| `nat-vm-certigo-runner-2` | `sku.tier` (= `Regional`) | Le type `NatGatewaySku` n'accepte que `name` ; `tier` n'existe pas dans le schéma. |
| `nat-vm-certigo-runner-2` | `properties.scope` (= `Public`) | Non réglable via modèle ; `Public` est déjà la valeur par défaut d'une Passerelle NAT. |
| `pip-vm-certigo-runner-2-nat` | `properties.ipTags` (`FirstPartyUsage` / `/Unprivileged`) | Étiquette **première-partie réservée** à Azure ; un déploiement qui tenterait de la poser serait **rejeté**. |

L'IP, la NAT, le NSG et le VNet parent ne sont plus émis en écriture par le
modèle. Le plan ne porte donc ni leurs propriétés provider-owned, ni les règles
NSG, ni les trois peerings.

La compilation des deux modèles, le contrat de tags, la syntaxe Bash et les tests du probe
sont vérifiés par `infra/validate.sh` et la gate `ci-infra`.
