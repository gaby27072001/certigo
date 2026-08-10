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

@description('Network posture. Only public-rbac is supported until VNet integration, private endpoints and private DNS are deployed together.')
@allowed([ 'public-rbac' ])
param networkAccessMode string = 'public-rbac'

@description('Email/password JWT signing key, stored as a Key Vault secret. The Function App reads it via a KV reference (@Microsoft.KeyVault). @secure: never logged.')
@secure()
param jwtSigningKey string

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
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

output name string = vault.name
output uri string = vault.properties.vaultUri

// AUTH_JWT_SIGNING_KEY secret (audit finding F-01). Dashes: KV secret names
// cannot contain underscores. The Function App consumes jwtSecretUri below as a
// KV reference so the signing key never sits in plain text in the app settings.
resource jwtSecret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: vault
  name: 'AUTH-JWT-SIGNING-KEY'
  properties: {
    value: jwtSigningKey
  }
}

@description('Versionless URI of the JWT signing secret, for the Function App KV reference.')
output jwtSecretUri string = jwtSecret.properties.secretUri
output networkAccessMode string = networkAccessMode
