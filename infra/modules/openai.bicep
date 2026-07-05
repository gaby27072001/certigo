// Azure AI Services account hosting the LLM tutor (audit finding G: IaC drift).
// The live resource 'certigo-openai' (dev, swedencentral) was created out-of-band;
// this module brings it under IaC. It is an adoption module: on the first apply,
// review the what-if carefully so the existing account is UPDATED, not recreated.
// All divergent properties are exposed as parameters so the template can be aligned
// to the live resource without editing this file.

@description('Cognitive Services account name. Must match the live resource to adopt it (e.g. certigo-openai).')
param accountName string

@description('Account location. Must match the live resource region (e.g. swedencentral).')
param location string

@description('Account SKU. S0 is the standard tier for AIServices accounts.')
param accountSku string = 'S0'

@description('Model deployment name consumed by the Function App (e.g. gpt-5.4-mini).')
param deploymentName string

@description('Deployment model name.')
param modelName string = 'gpt-5.4-mini'

@description('Deployment model version. Leave empty to let the platform pick the default version (recommended when the live version is unknown; confirm via what-if before apply).')
param modelVersion string = ''

@description('Model format. OpenAI for GPT models.')
param modelFormat string = 'OpenAI'

@description('Deployment SKU name (e.g. GlobalStandard, Standard). Confirm against the live deployment before apply.')
param deploymentSkuName string = 'GlobalStandard'

@description('Deployment capacity (tokens-per-minute units). Confirm against the live deployment before apply.')
param deploymentCapacity int = 1

@description('Managed identity principal id of the Function App, granted the Cognitive Services OpenAI User role for keyless access.')
param functionAppPrincipalId string

@description('Resource tags.')
param tags object = {}

// kind=AIServices: the live endpoint is *.services.ai.azure.com (Foundry), not the
// classic *.openai.azure.com (kind=OpenAI). customSubDomainName is required for
// token (AAD) auth and must equal the account name.
resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: accountSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: accountName
    publicNetworkAccess: 'Enabled'
  }
}

// Model deployment. 'version' is omitted when modelVersion is empty so ARM keeps
// the current/default version instead of forcing a downgrade on an existing deployment.
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: account
  name: deploymentName
  sku: {
    name: deploymentSkuName
    capacity: deploymentCapacity
  }
  properties: {
    model: union(
      {
        format: modelFormat
        name: modelName
      },
      empty(modelVersion) ? {} : { version: modelVersion }
    )
  }
}

// Cognitive Services OpenAI User: keyless (managed-identity) inference access for
// the Function App. dev.bicepparam already assumes this grant exists; it is now IaC.
var openAiUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
)

resource openAiUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(account.id, functionAppPrincipalId, openAiUserRoleId)
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: openAiUserRoleId
    principalType: 'ServicePrincipal'
  }
}

output endpoint string = account.properties.endpoint
output accountName string = account.name
