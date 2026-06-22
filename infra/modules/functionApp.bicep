// Azure Functions (Linux consumption, .NET 8 isolated worker) hosting the
// Microlingo API. Uses a system-assigned managed identity for Key Vault and
// Cosmos data-plane access — no secrets in app settings beyond the storage
// connection required by the Functions host.
@description('Function App name (globally unique).')
param functionAppName string
param location string

@description('Storage account (in this RG) used by the Functions runtime.')
param storageAccountName string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Cosmos DB account endpoint.')
param cosmosEndpoint string

@description('Key Vault name for RBAC secret access.')
param keyVaultName string

@description('Cosmos DB account name, for the data-plane (SQL) role assignment.')
param cosmosAccountName string

@description('Authentication mode. "dev" enables the permissive dev token validator for the dev environment only; empty enforces Entra token validation.')
@allowed([ '', 'dev' ])
param authMode string = ''

param authIssuer string
param authAudience string
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'plan-${functionAppName}'
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: { reserved: true } // Linux
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET-ISOLATED|8.0'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      cors: {
        // Mobile clients call directly; tighten/replace with API Management later.
        allowedOrigins: [ '*' ]
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'dotnet-isolated' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        // App config consumed by the API. Keys are FLAT (match Program.cs /
        // local.settings.json.example): COSMOS_ENDPOINT, ENTRA_AUTHORITY, etc.
        { name: 'COSMOS_ENDPOINT', value: cosmosEndpoint }
        { name: 'COSMOS_DATABASE', value: 'microlingo' }
        // "dev" => permissive DevTokenValidator (dev env only); empty => Entra.
        { name: 'AUTH_MODE', value: authMode }
        { name: 'ENTRA_AUTHORITY', value: authIssuer }
        { name: 'ENTRA_AUDIENCE', value: authAudience }
        { name: 'KeyVault__Uri', value: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/' }
      ]
    }
  }
}

// Grant the Function App's managed identity read access to Key Vault secrets.
resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

var keyVaultSecretsUser = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource vaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vault
  name: guid(vault.id, functionApp.id, keyVaultSecretsUser)
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: keyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

// Grant the Function App's managed identity Cosmos DB data-plane access via the
// built-in "Cosmos DB Built-in Data Contributor" SQL role. Required because the
// API authenticates to Cosmos with its managed identity (DefaultAzureCredential),
// not account keys. Without this assignment every Cosmos call returns 403.
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

var cosmosDataContributorRoleId = '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource cosmosDataAccess 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, functionApp.id, '00000000-0000-0000-0000-000000000002')
  properties: {
    roleDefinitionId: cosmosDataContributorRoleId
    principalId: functionApp.identity.principalId
    scope: cosmosAccount.id
  }
}

output functionAppName string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
output principalId string = functionApp.identity.principalId
