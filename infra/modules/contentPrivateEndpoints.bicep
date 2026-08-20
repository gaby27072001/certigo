targetScope = 'resourceGroup'

param location string
param ciRunnerSubnetId string
param blobPrivateDnsZoneId string
param storageAccountId string
param storageAccountName string
param tags object = {}

resource endpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${storageAccountName}-blob'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: ciRunnerSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-blob'
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: storageAccountId
        }
      }
    ]
  }
}

resource zoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: endpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: {
          privateDnsZoneId: blobPrivateDnsZoneId
        }
      }
    ]
  }
}

output privateEndpointId string = endpoint.id
