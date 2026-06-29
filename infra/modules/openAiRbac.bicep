// Octroie le rôle Cognitive Services OpenAI User à une managed identity sur un compte Azure OpenAI.
// Ce module est déployé à la portée du resource group du compte OpenAI (passée par l'appelant via
// scope: resourceGroup(...)), ce qui lui permet de référencer des ressources cross-resource-group :
// la Function App (rg-certigo-*) et le compte OpenAI (rg-microlingo-dev) peuvent être dans des
// resource groups différents au sein du même abonnement.

@description('Full Azure resource ID of the Azure OpenAI account (/subscriptions/.../providers/Microsoft.CognitiveServices/accounts/...).')
param openAiAccountResourceId string

@description('Object (principal) ID of the managed identity to grant the role to.')
param principalId string

param principalType string = 'ServicePrincipal'

var cognitiveServicesOpenAiUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

// The module is called with scope: resourceGroup(<openAiRG>) from main.bicep, so this existing
// reference is in the correct resource group without needing an explicit scope override.
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: last(split(openAiAccountResourceId, '/'))
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, principalId, cognitiveServicesOpenAiUserRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAiUserRoleId)
    principalId: principalId
    principalType: principalType
  }
}
