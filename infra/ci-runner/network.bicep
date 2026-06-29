// Réseau d'egress du runner CI — réconcilie en Infrastructure-as-Code l'IP
// publique + la Passerelle NAT (NAT Gateway) + le Réseau virtuel (VNet) / sous-réseau
// qui donnent l'accès Internet sortant au runner GitHub Actions auto-hébergé.
//
// POURQUOI CE FICHIER EXISTE
// La machine virtuelle du runner (vm-certigo-runner, dans law-microlingo-ci) n'a
// aucune IP publique propre ; son unique chemin vers Internet est :
//   carte réseau (NIC) → sous-réseau snet-runners → Passerelle NAT law-microlingo
//   → IP publique pip-certigo-nat (20.86.156.64).
// Cet egress a été créé de façon impérative (az CLI) pour débloquer l'intégration
// continue après la désactivation des runners hébergés par GitHub (politique
// d'entreprise EMU). Le capturer ici garantit qu'un futur redéploiement ou une
// correction de dérive ne pourra JAMAIS le détruire silencieusement et casser la
// CI de façon permanente.
//
// PÉRIMÈTRE : groupe de ressources law-microlingo-ci. La machine virtuelle, sa carte
// réseau et son disque OS sont gérés séparément et ne sont volontairement PAS
// déclarés ici — un déploiement de groupe de ressources est INCRÉMENTIEL, donc ces
// ressources non déclarées restent intactes. Ne jamais déployer ce modèle en mode
// « complet » (Complete), qui supprimerait tout ce qui n'est pas listé.
//
// Déployer :
//   az deployment group create -g law-microlingo-ci \
//     --template-file infra/ci-runner/network.bicep
// Valider sans rien changer (n'affiche que des différences bénignes — valeurs par
// défaut Azure non réglables ; voir la section dédiée du README) :
//   az deployment group what-if -g law-microlingo-ci \
//     --template-file infra/ci-runner/network.bicep
targetScope = 'resourceGroup'

@description('Région Azure de toutes les ressources d\'egress CI.')
param location string = 'westeurope'

@description('IP publique en façade de la Passerelle NAT (adresse d\'egress du runner).')
param publicIpName string = 'pip-certigo-nat'

@description('Passerelle NAT fournissant la traduction sortante (SNAT) du sous-réseau runner.')
param natGatewayName string = 'law-microlingo'

@description('Réseau virtuel hébergeant le sous-réseau du runner.')
param vnetName string = 'law-microlingo-ci'

@description('Sous-réseau auquel la carte réseau de la machine virtuelle runner est rattachée.')
param subnetName string = 'snet-runners'

@description('Groupe de sécurité réseau (NSG) du sous-réseau runner (aucune règle personnalisée — règles Azure par défaut uniquement).')
param nsgName string = 'law-microlingo-ci-snet-runners-nsg-westeurope'

@description('Espace d\'adressage du Réseau virtuel.')
param vnetAddressPrefix string = '10.42.0.0/16'

@description('Plage d\'adresses du sous-réseau runner.')
param subnetAddressPrefix string = '10.42.1.0/24'

@description('Étiquettes de ressources (les ressources existantes ne sont actuellement pas étiquetées).')
param tags object = {}

// IP publique Standard, statique, régionale — l'adresse d'egress stable que le
// trafic CI présente à Internet (les listes d'autorisation en dépendent : elle ne
// doit pas changer).
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    // Valeur par défaut héritée du Réseau virtuel — déclarée explicitement pour
    // qu'un what-if ne signale pas de fausse suppression.
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
}

// Passerelle NAT : donne à chaque machine virtuelle du sous-réseau une sortie SNAT
// déterministe via l'IP publique ci-dessus. Survit à la désallocation de la machine
// virtuelle, donc l'egress CI est durable.
resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: natGatewayName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: publicIp.id
      }
    ]
  }
}

// NSG vide (règles Azure par défaut uniquement), conservé pour que l'association du
// sous-réseau corresponde exactement à l'état réel ; durcir avec des règles
// explicites plus tard si besoin.
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// Réseau virtuel + l'unique sous-réseau runner. Le sous-réseau est déclaré EN LIGNE
// (et non comme ressource enfant) et spécifie entièrement les associations Passerelle
// NAT et NSG afin qu'un déploiement incrémentiel reproduise le câblage réel au lieu
// de détacher le runner.
resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    // Valeur par défaut explicitée pour neutraliser une fausse différence what-if.
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
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
    ]
  }
}

@description('IP d\'egress statique que la CI présente à Internet.')
output egressPublicIp string = publicIp.properties.ipAddress
@description('Identifiant de ressource de l\'IP publique d\'egress.')
output egressPublicIpId string = publicIp.id
@description('Identifiant de ressource du sous-réseau runner (la carte réseau s\'y rattache).')
output runnerSubnetId string = '${vnet.id}/subnets/${subnetName}'
