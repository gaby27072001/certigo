// Key Vault for API secrets (Cosmos keys, signing secrets, OpenAI keys).
// RBAC-authorization model; the Function App's managed identity is granted
// access from functionApp.bicep.
@description('Key Vault name (3-24 chars).')
param name string
param location string
param tags object = {}

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
  }
}

output name string = vault.name
output uri string = vault.properties.vaultUri
