// ============================================================================
// Microlingo — root infrastructure (Bicep)
// Subscription-scoped: creates the resource group, then composes all modules.
// Backend stack: Azure Functions (isolated .NET 8) + Cosmos DB (serverless) +
// Blob Storage + Application Insights + Key Vault. Identity is Microsoft Entra
// External ID (configured out-of-band; client/tenant ids passed as params).
// ============================================================================
targetScope = 'subscription'

@description('Short environment name: dev | staging | prod.')
@allowed([ 'dev', 'staging', 'prod' ])
param env string

@description('Primary Azure region for all resources.')
param location string = 'westeurope'

@description('Base name used to derive resource names. Lowercase, no spaces.')
param appName string = 'microlingo'

@description('Entra External ID tenant (issuer) authority URL for token validation.')
param authIssuer string

@description('Entra External ID application (audience) client id the API validates.')
param authAudience string

// Deterministic, collision-resistant suffix per environment/subscription.
var suffix = uniqueString(subscription().id, appName, env)
var rgName = 'rg-${appName}-${env}'
// Dev token bypass is allowed ONLY in the dev environment; staging/prod enforce
// Entra token validation.
var authMode = env == 'dev' ? 'dev' : ''
var tags = {
  product: 'Microlingo'
  env: env
  managedBy: 'bicep'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

module monitoring 'modules/appInsights.bicep' = {
  scope: rg
  name: 'monitoring'
  params: {
    name: 'appi-${appName}-${env}'
    location: location
    tags: tags
  }
}

module data 'modules/cosmos.bicep' = {
  scope: rg
  name: 'cosmos'
  params: {
    accountName: 'cosmos-${appName}-${env}-${suffix}'
    location: location
    databaseName: 'microlingo'
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage'
  params: {
    // Storage account names: 3-24 chars, lowercase alphanumeric only.
    accountName: toLower('st${appName}${env}${take(suffix, 8)}')
    location: location
    tags: tags
  }
}

module vault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: {
    name: 'kv-${appName}-${env}-${take(suffix, 6)}'
    location: location
    tags: tags
  }
}

module api 'modules/functionApp.bicep' = {
  scope: rg
  name: 'functionApp'
  params: {
    functionAppName: 'func-${appName}-${env}-${suffix}'
    location: location
    storageAccountName: storage.outputs.accountName
    appInsightsConnectionString: monitoring.outputs.connectionString
    cosmosEndpoint: data.outputs.endpoint
    cosmosAccountName: data.outputs.accountName
    keyVaultName: vault.outputs.name
    authMode: authMode
    authIssuer: authIssuer
    authAudience: authAudience
    tags: tags
  }
}

output resourceGroup string = rg.name
output functionAppName string = api.outputs.functionAppName
output functionAppHostName string = api.outputs.defaultHostName
output cosmosEndpoint string = data.outputs.endpoint
output storageAccount string = storage.outputs.accountName
output keyVaultName string = vault.outputs.name
