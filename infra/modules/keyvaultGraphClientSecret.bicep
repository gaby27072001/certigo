@description('Existing environment Key Vault name.')
param keyVaultName string

@description('Microsoft Graph confidential-client secret supplied by the protected GitHub Environment.')
@secure()
param graphClientSecret string

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2024-04-01-preview' = {
  parent: vault
  name: 'ENTRA-GRAPH-CLIENT-SECRET'
  properties: {
    value: graphClientSecret
    contentType: 'application/x-certigo-entra-graph-client-secret'
  }
}

@description('Version-pinned URI consumed by the Function App through its managed identity.')
output secretUri string = secret.properties.secretUriWithVersion
