// ============================================================================
// Grants a principal (e.g. the CI runner's managed identity) read access to
// the secret VALUES of an existing Key Vault, via the built-in
// "Key Vault Secrets User" role (RBAC-authorization model).
//
// Used to let the self-hosted release runner pull mobile signing secrets
// (keystore, passwords, Play service account, Apple cert/profile/API key)
// at build time — so NO signing secret ever lives in GitHub.
// ============================================================================

@description('Name of the existing Key Vault to grant access on.')
param keyVaultName string

@description('Object (principal) id to grant read access to (managed identity / service principal).')
param principalId string

@description('Principal type. Managed identities and service principals use ServicePrincipal.')
@allowed([ 'ServicePrincipal', 'User', 'Group' ])
param principalType string = 'ServicePrincipal'

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

// Built-in role "Key Vault Secrets User" (read secret contents).
var keyVaultSecretsUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, principalId, keyVaultSecretsUserRoleId)
  scope: vault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleId
    principalId: principalId
    principalType: principalType
  }
}
