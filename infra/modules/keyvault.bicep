// Key Vault for API secrets (Cosmos keys, signing secrets, OpenAI keys).
// RBAC-authorization model; the Function App's managed identity is granted
// access from functionApp.bicep.
@description('Key Vault name (3-24 chars).')
param name string
param location string
param tags object = {}

@description('Permanently protect the vault/secrets against purge. Recommended for staging/prod (cannot be disabled once enabled).')
param enablePurgeProtection bool = false

@description('Soft-delete retention in days (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

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
    softDeleteRetentionInDays: softDeleteRetentionInDays
    // Null (not false) when disabled: ARM rejects an explicit `false`.
    enablePurgeProtection: enablePurgeProtection ? true : null
    publicNetworkAccess: 'Enabled'
  }
}

output name string = vault.name
output uri string = vault.properties.vaultUri
