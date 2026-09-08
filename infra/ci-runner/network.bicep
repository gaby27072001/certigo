// Réseau d'egress du runner CI. Les ressources live sont référencées comme
// existing afin que la réconciliation ne réécrive ni propriétés provider-owned,
// ni peerings. Seuls le sous-réseau et les tags FinOps isolés sont mutables.
//
// POURQUOI CE FICHIER EXISTE
// Les VMSS n'ont aucune IP publique propre ; leur chemin legacy vers Internet est :
//   NIC → snet-runners → nat-vm-certigo-runner-2
//   → pip-vm-certigo-runner-2-nat (adresse statique allouée par Azure).
//
// PÉRIMÈTRE : groupe de ressources rg-certigo-ci. VMSS, VM, NIC, disques, Load
// Balancer, peerings et routes restent hors de ce modèle. Ne jamais le déployer en
// mode Complete.
//
// Valider sans rien changer :
//   az deployment group what-if -g rg-certigo-ci \
//     --template-file infra/ci-runner/network.bicep --validation-level Provider
targetScope = 'resourceGroup'

@description('IP publique en façade de la Passerelle NAT (adresse d\'egress du runner).')
param publicIpName string = 'pip-vm-certigo-runner-2-nat'

@description('Passerelle NAT fournissant la traduction sortante (SNAT) du sous-réseau runner.')
param natGatewayName string = 'nat-vm-certigo-runner-2'

@description('Réseau virtuel hébergeant le sous-réseau du runner.')
param vnetName string = 'vnet-certigo-ci'

@description('Sous-réseau auquel la carte réseau de la machine virtuelle runner est rattachée.')
param subnetName string = 'snet-runners'

@description('Groupe de sécurité réseau (NSG) du sous-réseau runner (aucune règle personnalisée — règles Azure par défaut uniquement).')
param nsgName string = 'vnet-certigo-ci-snet-runners-nsg-westeurope'

@description('Plage d\'adresses du sous-réseau runner.')
param subnetAddressPrefix string = '10.42.1.0/24'

@description('Étiquettes supplémentaires conservées lors de l’application du contrat FinOps.')
param tags object = {}

@description('Équipe ou service propriétaire. Ne jamais utiliser une identité personnelle.')
@minLength(1)
param tagOwner string = 'certigo-platform'

@description('Produit du contrat FinOps.')
@allowed(['Certigo'])
param tagProduct string = 'Certigo'

@description('Environnement du contrat FinOps.')
@allowed(['ci'])
param tagEnvironment string = 'ci'

@description('Outil déclaratif propriétaire de la ressource.')
@allowed(['bicep'])
param tagManagedBy string = 'bicep'

@description('Identifiant non personnel d’allocation des coûts.')
@minLength(1)
param tagCostCenter string = 'engineering'

var requiredTags = {
  owner: tagOwner
  product: tagProduct
  env: tagEnvironment
  managedBy: tagManagedBy
  costCenter: tagCostCenter
}
var effectiveTags = union(tags, requiredTags)

// Référence à l'adresse d'egress live. Son SKU, ses zones et ses ipTags gérés par
// Azure ne sont volontairement pas réémis par ce modèle.
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' existing = {
  name: publicIpName
}

// Référence à la passerelle NAT live. Le modèle ne réémet pas ses propriétés
// provider-owned `scope` et `sku.tier`.
resource natGateway 'Microsoft.Network/natGateways@2024-05-01' existing = {
  name: natGatewayName
}

// Référence au NSG live, sans adopter sa collection de règles.
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' existing = {
  name: nsgName
}

resource publicIpTags 'Microsoft.Resources/tags@2022-09-01' = {
  name: 'default'
  scope: publicIp
  properties: {
    tags: effectiveTags
  }
}

resource natGatewayTags 'Microsoft.Resources/tags@2022-09-01' = {
  name: 'default'
  scope: natGateway
  properties: {
    tags: effectiveTags
  }
}

resource nsgTags 'Microsoft.Resources/tags@2022-09-01' = {
  name: 'default'
  scope: nsg
  properties: {
    tags: effectiveTags
  }
}

// Le VNet live porte plusieurs peerings applicatifs. Une déclaration complète ferait
// autorité sur leur collection et pourrait les retirer. Seul le sous-réseau enfant
// nécessaire à l'egress legacy est donc géré.
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource runnerSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    defaultOutboundAccess: false
    natGateway: {
      id: natGateway.id
    }
    networkSecurityGroup: {
      id: nsg.id
    }
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

@description('IP d\'egress statique que la CI présente à Internet.')
output egressPublicIp string = publicIp.properties.ipAddress
@description('Identifiant de ressource de l\'IP publique d\'egress.')
output egressPublicIpId string = publicIp.id
@description('Identifiant de ressource du sous-réseau runner (la carte réseau s\'y rattache).')
output runnerSubnetId string = runnerSubnet.id
