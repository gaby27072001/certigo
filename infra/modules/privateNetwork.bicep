@description('Virtual network name.')
param vnetName string

param location string

@description('Address space for the environment virtual network.')
param vnetAddressPrefix string

@description('Dedicated Flex Consumption integration subnet prefix. Use /27 minimum; /26 is recommended for additional capacity.')
param functionIntegrationSubnetPrefix string

@description('Existing dedicated Flex Consumption integration subnet name.')
param functionIntegrationSubnetName string

@description('Dedicated private endpoint subnet prefix.')
param privateEndpointSubnetPrefix string

@description('Existing dedicated private endpoint subnet name.')
param privateEndpointSubnetName string

@description('Storage account protected by blob, queue, and table private endpoints.')
param storageAccountName string

@description('Key Vault protected by a vault private endpoint.')
param keyVaultName string

@description('Cosmos DB for NoSQL account protected by a Sql private endpoint.')
param cosmosAccountName string

@description('Existing Blob private endpoint name.')
param storageBlobPrivateEndpointName string

@description('Existing Queue private endpoint name.')
param storageQueuePrivateEndpointName string

@description('Existing Table private endpoint name.')
param storageTablePrivateEndpointName string

@description('Existing Key Vault private endpoint name.')
param keyVaultPrivateEndpointName string

@description('Existing Cosmos DB private endpoint name.')
param cosmosPrivateEndpointName string

@description('Existing Blob private DNS zone group name.')
param storageBlobPrivateDnsZoneGroupName string = 'default'

@description('Existing Queue private DNS zone group name.')
param storageQueuePrivateDnsZoneGroupName string = 'default'

@description('Existing Table private DNS zone group name.')
param storageTablePrivateDnsZoneGroupName string = 'default'

@description('Existing Key Vault private DNS zone group name.')
param keyVaultPrivateDnsZoneGroupName string = 'default'

@description('Existing Cosmos DB private DNS zone group name.')
param cosmosPrivateDnsZoneGroupName string = 'default'

@description('Resource group containing the trusted CI runner virtual network.')
param ciVnetResourceGroupName string

@description('Trusted CI runner virtual network name.')
param ciVnetName string

param blobZoneId string
param queueZoneId string
param tableZoneId string
param vaultZoneId string
param cosmosZoneId string

param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

resource ciVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  scope: resourceGroup(ciVnetResourceGroupName)
  name: ciVnetName
}

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
    subnets: [
      {
        name: functionIntegrationSubnetName
        properties: {
          addressPrefix: functionIntegrationSubnetPrefix
          delegations: [
            {
              name: 'flex-consumption'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: privateEndpointSubnetName
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource appToCiPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: vnet
  name: 'peer-to-${ciVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: ciVnet.id
    }
  }
}

resource storageBlobEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: storageBlobPrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${privateEndpointSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-blob'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource storageQueueEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: storageQueuePrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${privateEndpointSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-queue'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }
}

resource storageTableEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: storageTablePrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${privateEndpointSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-table'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
}

resource vaultEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: keyVaultPrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${privateEndpointSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-vault'
        properties: {
          privateLinkServiceId: vault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource cosmosEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: cosmosPrivateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: '${vnet.id}/subnets/${privateEndpointSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: '${cosmosAccountName}-sql'
        properties: {
          privateLinkServiceId: cosmos.id
          groupIds: [
            'Sql'
          ]
        }
      }
    ]
  }
}

resource storageBlobZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: storageBlobEndpoint
  name: storageBlobPrivateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: blobZoneId
        }
      }
    ]
  }
}

resource storageQueueZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: storageQueueEndpoint
  name: storageQueuePrivateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'queue'
        properties: {
          privateDnsZoneId: queueZoneId
        }
      }
    ]
  }
}

resource storageTableZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: storageTableEndpoint
  name: storageTablePrivateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'table'
        properties: {
          privateDnsZoneId: tableZoneId
        }
      }
    ]
  }
}

resource vaultZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: vaultEndpoint
  name: keyVaultPrivateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: {
          privateDnsZoneId: vaultZoneId
        }
      }
    ]
  }
}

resource cosmosZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: cosmosEndpoint
  name: cosmosPrivateDnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sql'
        properties: {
          privateDnsZoneId: cosmosZoneId
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output functionIntegrationSubnetId string = '${vnet.id}/subnets/${functionIntegrationSubnetName}'
output functionIntegrationSubnetName string = functionIntegrationSubnetName
output privateEndpointSubnetId string = '${vnet.id}/subnets/${privateEndpointSubnetName}'
