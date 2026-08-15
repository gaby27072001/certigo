// Key Vault for API secrets (Cosmos keys, signing secrets, OpenAI keys).
// RBAC-authorization model; the Function App's managed identity is granted
// access from functionApp.bicep.
@description('Key Vault name (3-24 chars).')
param name string
param location string
param tags object = {}

@description('Soft-delete retention in days (7-90).')
@minValue(7)
@maxValue(90)
param softDeleteRetentionInDays int = 7

@description('Email/password JWT signing key, stored as a Key Vault secret. The Function App reads it via a KV reference (@Microsoft.KeyVault). @secure: never logged.')
@secure()
param jwtSigningKey string

@description('Absolute ISO 8601 expiration timestamp for the active JWT signing secret.')
param jwtSigningKeyExpiresOn string

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
    enablePurgeProtection: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
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
    contentType: 'application/x-certigo-jwt-signing-key'
    attributes: {
      exp: dateTimeToEpoch(jwtSigningKeyExpiresOn)
    }
  }
}

@description('Version-pinned URI of the active JWT signing secret. A rotation changes the Function App setting and forces immediate refresh.')
output jwtSecretUri string = jwtSecret.properties.secretUriWithVersion
