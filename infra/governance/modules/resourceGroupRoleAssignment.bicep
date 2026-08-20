targetScope = 'resourceGroup'

@description('Stable seed used to derive the role assignment name without runtime identity values.')
param assignmentNameSeed string

@description('Role assignment description.')
param assignmentDescription string

@description('Service principal object id.')
param principalId string

@description('Role definition resource id.')
param roleDefinitionId string

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, assignmentNameSeed, roleDefinitionId)
  properties: {
    description: assignmentDescription
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}
