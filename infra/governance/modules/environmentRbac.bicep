targetScope = 'resourceGroup'

@description('Deployment identity object id.')
param principalId string

@description('Stable seed used to derive role assignment names before the identity exists.')
param assignmentNameSeed string

@description('Custom role definition that can create only approved runtime role assignments.')
param roleAssignmentWriterRoleDefinitionId string

@description('Built-in role definition GUIDs that the deployment identity may assign.')
param allowedRoleDefinitionIds array

var contributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b24988ac-6180-42a0-ab88-20f7382dd24c'
)

var allowedRoleIds = join(allowedRoleDefinitionIds, ', ')
var roleAssignmentCondition = '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR ((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${allowedRoleIds}}) AND (@Request[Microsoft.Authorization/roleAssignments:PrincipalType] StringEqualsIgnoreCase \'ServicePrincipal\')))'

resource contributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, assignmentNameSeed, contributorRoleDefinitionId)
  properties: {
    description: 'Certigo environment deployment; no role-assignment administration.'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinitionId
  }
}

resource runtimeRoleAssignmentWriter 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, assignmentNameSeed, roleAssignmentWriterRoleDefinitionId)
  properties: {
    condition: roleAssignmentCondition
    conditionVersion: '2.0'
    description: 'May create only approved runtime roles for service principals in this environment.'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleAssignmentWriterRoleDefinitionId
  }
}
