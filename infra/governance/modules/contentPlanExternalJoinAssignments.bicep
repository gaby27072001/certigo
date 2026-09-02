targetScope = 'resourceGroup'

param ciVnetName string
param ciRunnerSubnetName string
param blobPrivateDnsZoneName string
param principalId string
param roleDefinitionId string

resource ciVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: ciVnetName
}

resource ciRunnerSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: ciVnet
  name: ciRunnerSubnetName
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: blobPrivateDnsZoneName
}

resource subnetJoinAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: ciRunnerSubnet
  name: guid(ciRunnerSubnet.id, principalId, roleDefinitionId)
  properties: {
    description: 'Allows the content plan to read and join only the trusted CI runner subnet.'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}

resource dnsJoinAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: blobPrivateDnsZone
  name: guid(blobPrivateDnsZone.id, principalId, roleDefinitionId)
  properties: {
    description: 'Allows the content plan to read and join only the shared Blob private DNS zone.'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}
