targetScope = 'resourceGroup'

@description('Trusted CI runner virtual network resource id.')
param ciVnetId string

@description('Trusted CI runner virtual network name.')
param ciVnetName string

param tags object = {}

resource blobZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  tags: tags
}

resource queueZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.queue.core.windows.net'
  location: 'global'
  tags: tags
}

resource tableZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.table.core.windows.net'
  location: 'global'
  tags: tags
}

resource vaultZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource cosmosZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.documents.azure.com'
  location: 'global'
  tags: tags
}

resource blobCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: blobZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

resource queueCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: queueZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

resource tableCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: tableZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

resource vaultCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: vaultZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

resource cosmosCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cosmosZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

output blobZoneId string = blobZone.id
output queueZoneId string = queueZone.id
output tableZoneId string = tableZone.id
output vaultZoneId string = vaultZone.id
output cosmosZoneId string = cosmosZone.id
