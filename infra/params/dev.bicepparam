// Dev environment parameters. Authority/audience point to the Certigo
// Entra External ID app registration (replace placeholders before deploying).
// NOTE on Entra placeholders: in dev, main.bicep sets authMode='dev', so the API uses
// DevTokenValidator and Entra External ID is NOT enforced. The entraAuthority/entraAudience
// placeholders below are therefore safe to deploy as-is for dev. Provide real CIAM values
// for staging/prod (where authMode='prod' and EntraTokenValidator is active).
//
// Deploy:
//   az deployment sub create \
//     --location westeurope \
//     --template-file infra/main.bicep \
//     --parameters infra/params/dev.bicepparam
using '../main.bicep'

param env = 'dev'
param location = 'westeurope'
param appName = 'certigo'

// Cosmos DB deployed in northeurope — westeurope has AZ-capacity limits.
param cosmosLocation = 'northeurope'

// Microsoft Entra External ID (CIAM) — fill from your tenant.
param entraAuthority = 'https://certigo.ciamlogin.com/00000000-0000-0000-0000-000000000000/v2.0'
param entraAudience = '00000000-0000-0000-0000-000000000000'

// AI tutor (Azure OpenAI / Microsoft Foundry). Enabled in dev.
// The dev resource "microlingo-openai" (deployment gpt-5.4-mini, v1 project-scoped
// endpoint) is provisioned, and the "Cognitive Services OpenAI User" role is now granted
// on that resource to the Function App managed identity
// (func-microlingo-dev MI principal ec39dfb2-cb12-4279-9830-ce5d95ebce6b).
// TUTOR_LLM_API_KEY stays empty so the managed identity (Entra) is used for auth.
param tutorLlmEnabled = true
param tutorLlmEndpoint = 'https://microlingo-openai.services.ai.azure.com/api/projects/microlingo-dev/openai/v1/'
param tutorLlmDeployment = 'gpt-5.4-mini'
param tutorLlmApiSurface = 'v1'

// RBAC: grant the Function App managed identity the "Cognitive Services OpenAI User"
// role on the Azure OpenAI account so identity-based (keyless) auth works for the tutor.
// The OpenAI account lives in rg-microlingo-dev (separate from the Function App's rg-certigo-dev).
param tutorOpenAiAccountResourceId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/rg-microlingo-dev/providers/Microsoft.CognitiveServices/accounts/microlingo-openai'
param openAiRbacEnabled = true
