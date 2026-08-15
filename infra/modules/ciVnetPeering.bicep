targetScope = 'resourceGroup'

@description('Existing trusted CI runner virtual network.')
param ciVnetName string

@description('Resource id of the application virtual network.')
param appVnetId string

@description('Name of the application virtual network.')
param appVnetName string

resource ciVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: ciVnetName
}

resource ciToAppPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: ciVnet
  name: 'peer-to-${appVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: appVnetId
    }
  }
}
