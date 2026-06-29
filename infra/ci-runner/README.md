# Egress réseau du runner CI — Infrastructure-as-Code

Ce dossier réconcilie en Bicep le **chemin d'egress (sortie Internet) du runner GitHub
Actions auto-hébergé** de Certigo. Tout y est nommé en français pour rester aligné
avec le reste des livrables ; les noms de ressources Azure reprennent ceux du portail.

## Pourquoi

Les runners hébergés par GitHub sont **désactivés par la politique d'entreprise EMU**.
La CI s'exécute donc sur une machine virtuelle Azure auto-hébergée
(`vm-certigo-runner`, dans le groupe de ressources `law-certigo-ci`). Cette
machine **n'a aucune IP publique propre** : son seul accès à Internet passe par une
**Passerelle NAT (NAT Gateway)** attachée à son sous-réseau.

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
Passerelle NAT law-certigo  ──►  IP publique pip-certigo-nat (20.86.156.64)
                                         │
                                         ▼
                                      Internet
```

| Ressource | Type | Rôle |
| --- | --- | --- |
| `pip-certigo-nat` | IP publique (Standard, statique, régionale) | Adresse d'egress **stable** présentée à Internet (à mettre en liste d'autorisation) |
| `law-certigo` | Passerelle NAT (Standard) | SNAT sortant déterministe ; **survit à la désallocation** de la VM |
| `law-certigo-ci` | Réseau virtuel (`10.42.0.0/16`) | Héberge le sous-réseau runner |
| `snet-runners` | Sous-réseau (`10.42.1.0/24`) | La carte réseau du runner s'y rattache ; associé à la Passerelle NAT + NSG |
| `law-certigo-ci-snet-runners-nsg-westeurope` | Groupe de sécurité réseau (NSG) | Vide (règles Azure par défaut) ; conservé pour matcher l'état réel |

## Ce qui n'est **pas** géré ici (volontairement)

Un déploiement de **groupe de ressources** est **incrémentiel** : les ressources non
déclarées ne sont **jamais** touchées. Sont donc laissées à leur gestion propre :
la machine virtuelle `vm-certigo-runner`, sa carte réseau, son disque OS.

> ⚠️ **Ne jamais déployer ce modèle en mode « complet » (Complete)** : il supprimerait
> tout ce qui n'est pas listé (dont la VM, sa carte réseau et son disque).

## Dérive constatée — candidats au nettoyage (à traiter manuellement)

L'inventaire du groupe `law-certigo-ci` révèle des ressources **orphelines ou en
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
az deployment group what-if -g law-certigo-ci \
  --template-file infra/ci-runner/network.bicep
```

Déployer (incrémentiel — ne touche que les 5 ressources d'egress) :

```bash
az deployment group create -g law-certigo-ci \
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
| `law-certigo` | `sku.tier` (= `Regional`) | Le type `NatGatewaySku` n'accepte que `name` ; `tier` n'existe pas dans le schéma. |
| `law-certigo` | `properties.scope` (= `Public`) | Non réglable via modèle ; `Public` est déjà la valeur par défaut d'une Passerelle NAT. |
| `pip-certigo-nat` | `properties.ipTags` (`FirstPartyUsage` / `/Unprivileged`) | Étiquette **première-partie réservée** à Azure ; un déploiement qui tenterait de la poser serait **rejeté**. |

Les fausses différences réglables (`ddosSettings` héritée du VNet sur l'IP publique,
`privateEndpointVNetPolicies` sur le réseau virtuel) ont déjà été **explicitées** dans le
modèle : le réseau virtuel et le NSG ressortent donc en **« aucun changement »**.

La compilation est aussi vérifiée automatiquement en CI par le pipeline `ci-infra`
(`az bicep build --file infra/ci-runner/network.bicep`).
