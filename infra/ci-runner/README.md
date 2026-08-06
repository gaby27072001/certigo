# Egress réseau du runner CI — Infrastructure-as-Code

Ce dossier réconcilie en Bicep le **chemin d'egress (sortie Internet) du runner GitHub
Actions auto-hébergé** de Certigo. Tout y est nommé en français pour rester aligné
avec le reste des livrables ; les noms de ressources Azure reprennent ceux du portail.

## Pourquoi

Les runners hébergés par GitHub sont **désactivés par la politique d'entreprise EMU**.
La CI s'exécute donc sur un pool de machines virtuelles Azure auto-hébergées
(dont `vm-certigo-runner`, dans le groupe de ressources `rg-certigo-ci`). Ces
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

## Ce qui n'est **pas** géré ici (volontairement)

Un déploiement de **groupe de ressources** est **incrémentiel** : les ressources non
déclarées ne sont **jamais** touchées. Sont donc laissées à leur gestion propre :
la machine virtuelle `vm-certigo-runner`, sa carte réseau, son disque OS.

> ⚠️ **Ne jamais déployer ce modèle en mode « complet » (Complete)** : il supprimerait
> tout ce qui n'est pas listé (dont la VM, sa carte réseau et son disque).

## Drift IaC — finding G de l'audit

L'audit de sécurité (finding **G**) relève que l'infrastructure CI est déployée **hors
IaC**. Cette réconciliation ne couvre volontairement que le **chemin d'egress réseau**
(les 5 ressources du tableau ci-dessus) ; les **machines virtuelles runners** restent
gérées à la main. Ce périmètre est un choix assumé :

- **Réseau en IaC** (`network.bicep`) : figé en code, car sa destruction accidentelle
  casserait la CI de façon permanente. C'est le risque prioritaire.
- **VMs runners hors IaC** (drift **documenté, non résolu ici**) : les capturer en Bicep
  sans leur configuration vivante (image, taille, cloud-init, enregistrement du runner
  GitHub, secrets d'inscription) produirait une IaC **inexacte** — plus risqué que le
  drift actuel. Réconciliation reportée en **Phase 2** (module VM dédié + `what-if`).
- **Écart d'inventaire** : le finding mentionne « **2 VMs** » alors que ce README ne
  décrit qu'un seul runner (`vm-certigo-runner`). À lever avant tout module VM :
  inventorier le groupe (`az vm list -g rg-certigo-ci -o table`) pour confirmer le nombre
  réel de runners et rapprocher la liste des candidats au nettoyage (section « Dérive
  constatée » ci-dessous).

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

La compilation est aussi vérifiée automatiquement en CI par le pipeline `ci-infra`
(`az bicep build --file infra/ci-runner/network.bicep`).
