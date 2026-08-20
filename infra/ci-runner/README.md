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
classe `22f7fb52-Certigo` comme absent d'Azure, les bindings exacts f55/runner 27 et
bbf/runner 28 comme gérés (running/online), et `4153d1dd` comme VM externe/deallocated.
Cette dernière n'est ni comptée ni ciblée; toute autre VM non réconciliée bloque le plan.
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

Deux modèles complémentaires sont versionnés :

- `network.bicep` réconcilie l'egress partagé sans toucher aux VM existantes ;
- `runner.bicep` reconstruit une VM, sa NIC privée, son disque et son identité managée.
  Il référence le sous-réseau existant et exécute `bootstrap.sh` au premier démarrage.

`runner.bicep` sert à créer une nouvelle instance ou à reconstruire une instance
préalablement supprimée. **Ne pas l'appliquer au nom d'une VM vivante** : les propriétés
de profil OS d'une VM existante sont immuables. Le runbook de reconstruction, les preuves
et le rollback sont dans
[`docs/CI_RUNNER_RESILIENCE.md`](../../docs/CI_RUNNER_RESILIENCE.md).

> ⚠️ **Ne jamais déployer ce modèle en mode « complet » (Complete)** : il supprimerait
> tout ce qui n'est pas listé (dont la VM, sa carte réseau et son disque).

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

## Capacité et cycle de vie

Le VMSS live est `Standard_D2ads_v6`, autoscale min 2 / défaut 2 / max 4. Son scale-in CPU
est dangereux car il ignore GitHub `busy`, et les runners portent simultanément
`certigo-pr` et `certigo-trusted`. Toute automation mutable est donc bloquée.

Le script `lifecycle-preflight.sh` inventorie sans mutation et refuse une déallocation en
présence d'un label double, d'un job actif/en file, d'un scale-in CPU ou d'un écart entre VM
et runners. La cible sérialisée et son rollback sont dans
[`docs/runbooks/CLOUD_LEAST_PRIVILEGE.md`](../../docs/runbooks/CLOUD_LEAST_PRIVILEGE.md).

Le planificateur `capacity-plan.sh` ajoute une réconciliation de drift et un modèle
queue-driven `workflow_job` avec trois modes par classe (`idle=0+0`, `normal=1+1`,
`boost=6 PR + 2 trusted`). Cette cible est celle d'un pilote ultérieur, pas un plafond
de production final. Le feature flag est **off**; aucun code de mutation n'est présent.
L'état v3 exige power Azure + runner online, conserve le slot exact à réarmer et refuse les
IDs 22f/459. Labels, frontières d'identité et sous-réseaux exclusifs sont des prérequis. Le scale-in
exige une quiet period resettable de 5 minutes, deux gardes, un lease et un réarmement
sur toute activité postérieure. Le baseline 30 jours est
242,06 USD pour 413 jobs, 18,84 runner-heures, 3,78 % CPU moyen, avec une file P95 de
5 108 s et P99 de 12 628 s.

> À noter : le compte **Azure OpenAI** (`certigo-openai`), autre ressource en drift citée
> par le finding G, est lui **réintégré en IaC** dans ce livrable via
> `infra/modules/openai.bicep` (câblé dans `infra/main.bicep`, module `tutor`).

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
