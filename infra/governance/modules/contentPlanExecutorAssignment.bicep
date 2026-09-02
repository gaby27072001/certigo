targetScope = 'resourceGroup'

param assignmentNameSeed string
param principalId string
param publisherPrincipalIds array
param publisherRoleDefinitionGuid string
param readerPrincipalId string
param readerRoleDefinitionGuid string
param roleDefinitionId string

var publisherPrincipalIdValues = join(publisherPrincipalIds, ', ')
var roleAssignmentCondition = '((!(ActionMatches{\'Microsoft.Authorization/roleAssignments/write\'})) OR (((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] GuidEquals ${publisherRoleDefinitionGuid}) AND (@Request[Microsoft.Authorization/roleAssignments:PrincipalId] ForAnyOfAnyValues:GuidEquals {${publisherPrincipalIdValues}})) OR ((@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] GuidEquals ${readerRoleDefinitionGuid}) AND (@Request[Microsoft.Authorization/roleAssignments:PrincipalId] GuidEquals ${readerPrincipalId}))) AND (@Request[Microsoft.Authorization/roleAssignments:PrincipalType] StringEqualsIgnoreCase \'ServicePrincipal\'))'

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, assignmentNameSeed, roleDefinitionId)
  properties: {
    condition: roleAssignmentCondition
    conditionVersion: '2.0'
    description: 'Plans the content stack and may assign only approved content roles to service principals.'
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}
