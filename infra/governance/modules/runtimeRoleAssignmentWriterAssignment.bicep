targetScope = 'resourceGroup'

param allowedRoleDefinitionIds array
param assignmentNameSeed string
param principalId string
param roleDefinitionId string

var allowedRoleIds = join(allowedRoleDefinitionIds, ', ')
var roleAssignmentCondition = '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR ((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${allowedRoleIds}}) AND (@Request[Microsoft.Authorization/roleAssignments:PrincipalType] StringEqualsIgnoreCase \'ServicePrincipal\')))'

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, assignmentNameSeed, roleDefinitionId)
  properties: {
    condition: roleAssignmentCondition
    conditionVersion: '2.0'
    description: 'May create only approved runtime roles for service principals in this environment.'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}
