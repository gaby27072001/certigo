// Azure AI Services account hosting the LLM tutor (audit finding G: IaC drift).
// The live resource 'certigo-openai' (dev, swedencentral) was created out-of-band.
// The account, model deployment and RBAC are managed; the Foundry project and private
// endpoint are existing boundaries until their ownership is proven independently.
// Private DNS is not claimed here: the live zone covers *.openai.azure.com, while the
// configured Foundry endpoint resolves through *.privatelink.services.ai.azure.com.

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

@description('Deployment model version observed in the live account.')
param modelVersion string = '2026-03-17'

@description('Model format. OpenAI for GPT models.')
param modelFormat string = 'OpenAI'

@description('Deployment SKU name (e.g. GlobalStandard, Standard). Confirm against the live deployment before apply.')
param deploymentSkuName string = 'GlobalStandard'

@description('Deployment capacity (tokens-per-minute units). Confirm against the live deployment before apply.')
param deploymentCapacity int = 1

@description('Managed identity principal id of the Function App, granted the Cognitive Services OpenAI User role for keyless access.')
param functionAppPrincipalId string

@description('Existing Foundry project consumed by the v1 tutor endpoint.')
param projectName string = 'certigo-dev'

@description('Existing private endpoint that keeps the account off the public network.')
param privateEndpointName string = 'pep-certigo-openai-account'

@description('Existing OpenAI User role assignment name for the Function App identity.')
param openAiUserRoleAssignmentName string = 'f2f408f8-6106-4435-980c-a4d178e67fd2'

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
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
  }
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: account
  name: deploymentName
  sku: {
    name: deploymentSkuName
    capacity: deploymentCapacity
  }
  properties: {
    model: {
      format: modelFormat
      name: modelName
      version: modelVersion
    }
    raiPolicyName: 'Microsoft.DefaultV2'
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' existing = {
  parent: account
  name: projectName
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' existing = {
  name: privateEndpointName
}

// Cognitive Services OpenAI User: keyless (managed-identity) inference access for
// the Function App. dev.bicepparam already assumes this grant exists; it is now IaC.
var openAiUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
)

resource openAiUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: openAiUserRoleAssignmentName
  properties: {
    principalId: functionAppPrincipalId
    roleDefinitionId: openAiUserRoleId
    principalType: 'ServicePrincipal'
  }
}

output endpoint string = account.properties.endpoint
output accountName string = account.name
output projectId string = project.id
output privateEndpointId string = privateEndpoint.id
