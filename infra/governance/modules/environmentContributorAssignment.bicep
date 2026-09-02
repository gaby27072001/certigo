targetScope = 'resourceGroup'

param assignmentNameSeed string
param principalId string

var contributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
)

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, assignmentNameSeed, contributorRoleDefinitionId)
  properties: {
    description: 'Certigo environment deployment; no role-assignment administration.'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinitionId
  }
}
