# Runners CI — Infrastructure-as-Code

Ce dossier réconcilie en Bicep les **VM GitHub Actions auto-hébergées** de Certigo et
leur **chemin d'egress (sortie Internet)**. Tout y est nommé en français pour rester aligné
avec le reste des livrables ; les noms de ressources Azure reprennent ceux du portail.

## Pourquoi

Les runners hébergés par GitHub sont **désactivés par la politique d'entreprise EMU**.
La CI s'exécute donc sur un pool de machines virtuelles Azure auto-hébergées
(dont `vm-certigo-runner` et `vm-certigo-runner-2`, dans le groupe de ressources
`rg-certigo-ci`). Ces
machines **n'ont aucune IP publique propre** : leur seul accès à Internet passe par une
**Passerelle NAT (NAT Gateway)** attachée à leur sous-réseau. Le runbook de redondance,
de failover et de preuve opérationnelle est dans
[`docs/CI_RUNNER_RESILIENCE.md`](../../docs/CI_RUNNER_RESILIENCE.md).

Ce chemin a d'abord été créé **manuellement** (az CLI) pour débloquer la CI en urgence.
Tant qu'il n'existait que « à la main », un futur redéploiement ou une correction de
dérive pouvait le **détruire silencieusement** et casser la CI de façon permanente.
`network.bicep` le **fige en code** pour empêcher cela.

## Chemin d'egress réconcilié

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

## Périmètre IaC

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

Chaque VM créée par `runner.bicep` est une `Standard_D4s_v5` et exécute un seul job GitHub
Actions à la fois. La capacité nominale du pool Linux est donc **deux jobs concurrents**,
à condition que les deux VMs soient `running`, que les deux runners soient `online` et
qu'ils portent `certigo-ci`. Il n'y a pas d'autoscaling : une file d'attente est un signal
opérationnel de démarrer les deux VMs ou d'ajouter une troisième instance via une
reconstruction planifiée.

Le démarrage et la déallocation sont des opérations humaines décrites dans
[`docs/runbooks/CI_RUNNERS.md`](../../docs/runbooks/CI_RUNNERS.md) ; l'IaC, le bootstrap
et les validations locales ne démarrent, n'arrêtent ni ne suppriment de ressource Azure.
Avant de déallouer une VM, l'opérateur vérifie que son runner est `online` et `busy: false`.
Pendant une session CI, conserver les deux instances disponibles : l'une absorbe la perte
ou la maintenance de l'autre.

> À noter : le compte **Azure OpenAI** (`certigo-openai`), autre ressource en drift citée
> par le finding G, est lui **réintégré en IaC** dans ce livrable via
> `infra/modules/openai.bicep` (câblé dans `infra/main.bicep`, module `tutor`).

## Dérive constatée — candidats au nettoyage (à traiter manuellement)

L'inventaire du groupe `rg-certigo-ci` révèle des ressources **orphelines ou en
double**, vestiges des tâtonnements de mise en place. Elles ne sont **ni importées ni
supprimées automatiquement** ici (suppression = décision humaine), mais documentées :

| Ressource | Constat | Action suggérée |
| --- | --- | --- |
| `pip-certigo-test` (`20.61.109.230`) | IP publique **orpheline** (aucune configuration IP, aucune Passerelle NAT) | Supprimer (fuite de coût) |
| `vm-certigo-runnerVNET` | **Réseau virtuel en double** non utilisé par le runner | Supprimer après vérification |
| `vm-certigo-runnerVNET-vm-certigo-runnerSubnet-nsg-westeurope` | NSG du sous-réseau du VNet en double | Supprimer avec le VNet ci-dessus |
| `vm-certigo-runnerNSG` | NSG par défaut de la VM, non rattaché au chemin d'egress | Vérifier puis supprimer si inutilisé |

## Commandes

Valider sans rien changer — n'affiche que des différences **bénignes** (voir
« Différences résiduelles du what-if » plus bas) ; aucune ne modifie le chemin d'egress :

```bash
az deployment group what-if -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep
```

Déployer (incrémentiel — ne touche que les 5 ressources d'egress) :

```bash
az deployment group create -g rg-certigo-ci \
  --template-file infra/ci-runner/network.bicep
```

### Différences résiduelles du what-if — **bénignes et attendues**

Le what-if affiche encore trois « suppressions » de propriétés, sur deux ressources.
Ce sont des **valeurs par défaut injectées par Azure** que l'API renvoie en lecture mais
que le modèle **ne peut pas** repositionner (propriétés réservées, en lecture seule, ou
absentes du schéma Bicep stable). Un déploiement réel **ne modifie pas** le chemin
d'egress : adresse IP, allocation statique, lien IP↔Passerelle NAT et association
sous-réseau↔NAT↔NSG restent **identiques au bit près**.

| Ressource | Propriété signalée | Pourquoi on ne la fige pas |
| --- | --- | --- |
| `nat-certigo` | `sku.tier` (= `Regional`) | Le type `NatGatewaySku` n'accepte que `name` ; `tier` n'existe pas dans le schéma. |
| `nat-certigo` | `properties.scope` (= `Public`) | Non réglable via modèle ; `Public` est déjà la valeur par défaut d'une Passerelle NAT. |
| `pip-certigo-nat` | `properties.ipTags` (`FirstPartyUsage` / `/Unprivileged`) | Étiquette **première-partie réservée** à Azure ; un déploiement qui tenterait de la poser serait **rejeté**. |

Les fausses différences réglables (`ddosSettings` héritée du VNet sur l'IP publique,
`privateEndpointVNetPolicies` sur le réseau virtuel) ont déjà été **explicitées** dans le
modèle : le réseau virtuel et le NSG ressortent donc en **« aucun changement »**.

La compilation des deux modèles, la syntaxe Bash et les tests du probe sont vérifiés par
`ci-infra`.
