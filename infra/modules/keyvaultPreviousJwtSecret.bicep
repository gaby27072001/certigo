@description('Existing Key Vault that receives the previous JWT signing key during rotation.')
param keyVaultName string

@description('Previous JWT signing key retained only for the bounded rotation overlap.')
@secure()
param jwtPreviousSigningKey string

@description('Absolute ISO 8601 expiration timestamp for the previous signing secret.')
param jwtPreviousSigningKeyExpiresOn string

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource jwtPreviousSecret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: vault
  name: 'AUTH-JWT-PREVIOUS-SIGNING-KEY'
  properties: {
    value: jwtPreviousSigningKey
    contentType: 'application/x-certigo-jwt-signing-key'
    attributes: {
      exp: dateTimeToEpoch(jwtPreviousSigningKeyExpiresOn)
    }
  }
}

@description('Version-pinned URI of the previous JWT signing secret.')
output jwtSecretUri string = jwtPreviousSecret.properties.secretUriWithVersion
