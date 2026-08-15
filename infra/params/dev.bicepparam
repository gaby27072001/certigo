// Dev environment parameters. Authority/audience point to the Certigo
// Entra External ID app registration (replace placeholders before deploying).
// NOTE on Entra placeholders (audit finding F-02): the entraAuthority/entraAudience
// values below are the all-zeros tenant placeholder (00000000-...). This is INTENTIONAL
// and safe for dev, because dev runs on an explicit auth bypass — it never validates
// Entra tokens at runtime:
//   * main.bicep sets authMode='dev' for env=='dev', which becomes AUTH_MODE=dev on the
//     Function App, and functionApp.bicep derives AUTH_ALLOW_DEV=true from it.
//   * With AUTH_MODE=dev + AUTH_ALLOW_DEV=true the API selects the permissive
//     DevTokenValidator; the EntraTokenValidator (which would consume these values) is
//     never activated, so ENTRA_AUTHORITY / ENTRA_AUDIENCE are inert.
// => Do NOT waste effort wiring a real CIAM tenant for dev. Real Entra External ID values
//    are only required for staging/prod, where authMode='prod' and EntraTokenValidator is
//    active (see prod.bicepparam / staging.bicepparam).
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
param networkAccessMode = 'public-rbac'

// Explicit periodic backup for disposable development data.
param cosmosBackupMode = 'Periodic'
param cosmosPeriodicBackupIntervalMinutes = 240
param cosmosPeriodicBackupRetentionHours = 8
param cosmosPeriodicBackupStorageRedundancy = 'Local'

// Subscription-wide controls are owned by the production deployment.
param deployMcsbPolicyAssignment = false
param mcsbEnforcementMode = 'DoNotEnforce'
param manageDefenderPlans = false
param enableDefenderPlans = false

// Cosmos DB deployed in northeurope — westeurope has AZ-capacity limits.
param cosmosLocation = 'northeurope'

// Microsoft Entra External ID (CIAM) — placeholder tenant, deliberately inert in dev
// (see the F-02 note at the top of this file). Leave as-is unless testing Entra locally.
param entraAuthority = 'https://certigo.ciamlogin.com/00000000-0000-0000-0000-000000000000/v2.0'
param entraAudience = '00000000-0000-0000-0000-000000000000'

// authJwtSigningKey is intentionally omitted in dev. main.bicep derives a stable
// value that is explicitly gated to the non-hardened dev environment.
// Its expiration is fixed and reviewable: deployments do not extend it implicitly.
param authJwtSigningKeyExpiresOn = '2027-08-31T00:00:00Z'

// AI tutor (Azure OpenAI / Microsoft Foundry). Enabled in dev.
// The dev resource "certigo-openai" (deployment gpt-5.4-mini, v1 project-scoped
// endpoint) is provisioned, and the "Cognitive Services OpenAI User" role is now granted
// on that resource to the Function App managed identity.
// TUTOR_LLM_API_KEY stays empty so the managed identity (Entra) is used for auth.
param tutorLlmEnabled = false
param tutorLlmEndpoint = 'https://certigo-openai.services.ai.azure.com/api/projects/certigo-dev/openai/v1/'
param tutorLlmDeployment = 'gpt-5.4-mini'
param tutorLlmApiSurface = 'v1'