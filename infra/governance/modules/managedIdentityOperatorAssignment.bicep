@description('Existing user-assigned identity that the deployment principal may attach.')
param identityName string

@description('Stable seed for the role assignment GUID.')
param assignmentNameSeed string

@description('Exact audited description for this environment assignment.')
param readerAssignmentDescription string

@description('Deployment service principal receiving the scoped assignment.')
param principalId string

@description('Managed Identity Operator role definition resource ID.')
param roleDefinitionId string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: identityName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(identity.id, assignmentNameSeed, roleDefinitionId)
  scope: identity
  properties: {
    description: readerAssignmentDescription
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}
