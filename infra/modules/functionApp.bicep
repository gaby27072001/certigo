// Azure Functions (Linux Flex Consumption, .NET 8 isolated worker) hosting the
// Certigo API. Uses a system-assigned managed identity for Key Vault, Cosmos
// data-plane, and identity-based storage access — NO account keys anywhere
// (the platform's storage accounts have shared-key auth disabled by policy).
@description('Function App name (globally unique).')
param functionAppName string
param location string

@description('Storage account (in this RG) used by the Functions runtime.')
param storageAccountName string

@description('Blob container (in the storage account) holding the deployment package.')
param deploymentContainerName string = 'app-package'

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Cosmos DB account endpoint.')
param cosmosEndpoint string

@description('Key Vault name for RBAC secret access.')
param keyVaultName string

@description('Cosmos DB account name, for the data-plane (SQL) role assignment.')
param cosmosAccountName string

@description('Authentication mode. "dev" enables the permissive dev token validator (safe default for local/dev); "prod" enforces Entra External ID token validation. Set to "prod" in staging/production once the Entra External ID tenant is configured. Any value other than "dev" also enables Entra validation.')
@allowed([ 'dev', 'prod', '' ])
param authMode string = 'dev'

@description('Entra External ID authority URL. Format: https://<domain>.ciamlogin.com/<tenant-id>/v2.0. Replace with the value from Azure Portal → External ID tenant → Overview. Leave empty until the tenant is created.')
@secure()
param entraAuthority string = ''

@description('Entra External ID application (audience) client ID — the App Registration client ID in the External ID tenant. Replace with the value from Azure Portal → External ID → App registrations → <your-app> → Overview. Leave empty until configured.')
@secure()
param entraAudience string = ''
@description('Feature flag for the optional Azure OpenAI tutor completion. False keeps the deterministic grounded tutor only.')
param tutorLlmEnabled bool = false
@description('Azure OpenAI resource endpoint used by the tutor when the feature flag is enabled. Example: https://<resource>.openai.azure.com/.')
param tutorLlmEndpoint string = ''
@description('Azure OpenAI deployment name used by the tutor when the feature flag is enabled.')
param tutorLlmDeployment string = ''
@description('Tutor LLM API surface: "v1" for the Microsoft Foundry project-scoped v1 endpoint (default), or "classic" for the legacy deployments/.../chat/completions?api-version path.')
@allowed([
  'v1'
  'classic'
])
param tutorLlmApiSurface string = 'v1'
@description('Optional Azure OpenAI API version override. Used only by the "classic" API surface; ignored when tutorLlmApiSurface is "v1".')
param tutorLlmApiVersion string = '2024-10-21'
@description('Optional explicit API key for the tutor LLM. Leave empty to use the Function App managed identity instead.')
@secure()
param tutorLlmApiKey string = ''
@description('Maximum output tokens requested from the tutor LLM.')
param tutorLlmMaxOutputTokens int = 400
param tags object = {}

@description('CORS allowed origins. Native mobile clients are not subject to CORS, so this can be [] (none) for staging/prod; dev passes ["*"] for browser-based tooling.')
param allowedCorsOrigins array = [ '*' ]

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'plan-${functionAppName}'
  location: location
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
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
    // Flex Consumption: runtime + deployment are declared in functionAppConfig.
    // The deployment package is pulled from blob storage using the app's managed
    // identity (no shared key — compatible with allowSharedKeyAccess=false).
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      cors: {
        // Native mobile clients aren't subject to CORS; staging/prod pass [] and
        // tighten via API Management later. Dev allows '*' for browser tooling.
        allowedOrigins: allowedCorsOrigins
      }
      appSettings: [
        // Identity-based AzureWebJobsStorage (no key). The managed identity is
        // granted Blob/Queue data roles on the storage account below.
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        // App config consumed by the API. Keys are FLAT (match Program.cs /
        // local.settings.json.example): COSMOS_ENDPOINT, ENTRA_AUTHORITY, etc.
        { name: 'COSMOS_ENDPOINT', value: cosmosEndpoint }
        { name: 'COSMOS_DATABASE', value: 'certigo' }
        // "dev" => permissive DevTokenValidator (dev env only); "prod" (or any non-"dev" value) => Entra.
        { name: 'AUTH_MODE', value: authMode }
        { name: 'ENTRA_AUTHORITY', value: entraAuthority }
        { name: 'ENTRA_AUDIENCE', value: entraAudience }
        { name: 'TUTOR_LLM_ENABLED', value: string(tutorLlmEnabled) }
        { name: 'TUTOR_LLM_ENDPOINT', value: tutorLlmEndpoint }
        { name: 'TUTOR_LLM_DEPLOYMENT', value: tutorLlmDeployment }
        { name: 'TUTOR_LLM_API_SURFACE', value: tutorLlmApiSurface }
        { name: 'TUTOR_LLM_API_VERSION', value: tutorLlmApiVersion }
        { name: 'TUTOR_LLM_API_KEY', value: tutorLlmApiKey }
        { name: 'TUTOR_LLM_MAX_OUTPUT_TOKENS', value: string(tutorLlmMaxOutputTokens) }
        { name: 'KeyVault__Uri', value: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/' }
      ]
    }
  }
}

// Identity-based storage access for the Functions host (deployment package +
// AzureWebJobsStorage). Required because the storage account has shared-key auth
// disabled — the runtime authenticates with the app's managed identity.
var storageBlobDataOwner = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
)

resource storageBlobAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, functionApp.id, storageBlobDataOwner)
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: storageBlobDataOwner
    principalType: 'ServicePrincipal'
  }
}

var storageQueueDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
)

resource storageQueueAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, functionApp.id, storageQueueDataContributor)
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: storageQueueDataContributor
    principalType: 'ServicePrincipal'
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
