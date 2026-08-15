targetScope = 'resourceGroup'

@description('Application virtual network resource id.')
param appVnetId string

@description('Application virtual network name.')
param appVnetName string

param tags object = {}

resource blobZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.blob.core.windows.net'
}

resource queueZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.queue.core.windows.net'
}

resource tableZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.table.core.windows.net'
}

resource vaultZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.vaultcore.azure.net'
}

resource cosmosZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.documents.azure.com'
}

resource blobAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: blobZone
  name: '${appVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}

resource queueAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: queueZone
  name: '${appVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}

resource tableAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: tableZone
  name: '${appVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}

resource vaultAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: vaultZone
  name: '${appVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}

resource cosmosAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cosmosZone
  name: '${appVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}
