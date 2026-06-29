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

// AI tutor (Azure OpenAI / Microsoft Foundry). Left disabled by default.
// The dev resource "microlingo-openai" (deployment gpt-5.4-mini, v1 project-scoped
// endpoint) is provisioned, but real calls require the "Cognitive Services OpenAI User"
// role on that resource for the Function App managed identity. Uncomment once RBAC is
// granted; TUTOR_LLM_API_KEY stays empty so the managed identity (Entra) is used.
// param tutorLlmEnabled = true
// param tutorLlmEndpoint = 'https://microlingo-openai.services.ai.azure.com/api/projects/microlingo-dev/openai/v1/'
// param tutorLlmDeployment = 'gpt-5.4-mini'
// param tutorLlmApiSurface = 'v1'