// Dev environment parameters. Authority/audience point to the Certigo
// Entra External ID app registration (replace placeholders before deploying).
// Key Vault purge protection is enabled in every environment and is irreversible.
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
param ciDeploymentPrincipalId = '15d2b34a-c0a0-4b5d-8360-b895a8164706'
param vnetAddressPrefix = '10.60.0.0/24'
param functionIntegrationSubnetPrefix = '10.60.0.0/26'
param functionIntegrationSubnetName = 'snet-functions'
param privateEndpointSubnetPrefix = '10.60.0.64/26'
param privateEndpointSubnetName = 'snet-private-endpoints'
param storageBlobPrivateEndpointName = 'pep-stcertigodevbk3j5ja6-blob'
param storageQueuePrivateEndpointName = 'pep-stcertigodevbk3j5ja6-queue'
param storageTablePrivateEndpointName = 'pep-stcertigodevbk3j5ja6-table'
param keyVaultPrivateEndpointName = 'pep-kv-certigo-dev-bk3j5j-vault'
param cosmosPrivateEndpointName = 'pep-cosmos-certigo-dev-bk3j5ja6vw23s-sql'
param storageBlobPrivateLinkConnectionName = 'stcertigodevbk3j5ja6-blob'
param storageQueuePrivateLinkConnectionName = 'stcertigodevbk3j5ja6-queue'
param storageTablePrivateLinkConnectionName = 'stcertigodevbk3j5ja6-table'
param keyVaultPrivateLinkConnectionName = 'kv-certigo-dev-bk3j5j-vault'
param cosmosPrivateLinkConnectionName = 'cosmos-certigo-dev-bk3j5ja6vw23s-sql'

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
param personLinkedIdentityV1 = 'off'

// Public-domain features stay neutral in dev. Hardened environments receive
// these values from their GitHub Environment through the private parameter writer.
param publicWebOrigin = ''
param publicDomainVerified = false
param appleCiamDomainReconfigured = false

// authJwtSigningKey is intentionally omitted in dev. main.bicep derives a stable
// value that is explicitly gated to the non-hardened dev environment.
// Its expiration is fixed and reviewable: deployments do not extend it implicitly.
param authJwtSigningKeyExpiresOn = '2027-08-31T00:00:00Z'

// AI tutor (Azure OpenAI / Microsoft Foundry). DISABLED in dev — this comment
// previously claimed the opposite ("Enabled in dev" / "role is now granted"),
// which was stale and incorrect; corrected here (Phase B tutor-prod review).
//
// Real history: #99 set tutorLlmEnabled=true. #178 added the IaC adoption
// module (infra/modules/openai.bicep, kind=AIServices, grants "Cognitive
// Services OpenAI User" — roleId 5e0bd9bd-7b93-4f28-af87-19fc36ad61bd — to the
// Function App managed identity). #181 then reset this flag to false because
// the dev deployment failed with `DeploymentModelNotSupported` for the
// gpt-5.4-mini model, to unblock an unrelated security fix. The `tutor` module
// is gated on this flag (`if (tutorLlmEnabled)`, main.bicep), so it has NOT
// been deployed since #181 — the RBAC grant AND the model-deployment
// compatibility of the current AIServices-kind module are both UNVERIFIED.
//
// Do not flip this to `true` without first: (1) a human with real Azure
// access running `az deployment sub create --what-if` for this file to
// confirm the model deployment no longer fails, (2) confirming the role
// assignment lands, (3) running the new gated live test described in
// docs/deployment-runbook.md §T0.5 "Chemin 3" (backend/run-tutor-llm-live-gate.ps1,
// CERTIGO_TUTOR_LLM_LIVE_TESTS=1) against the deployed dev endpoint to prove a
// real (non-fallback) LLM response. See docs/adr/ADR-O-01-ai-tutor-prod.md.
// TUTOR_LLM_API_KEY stays empty so the managed identity (Entra) would be used
// for auth once/if this is safely re-enabled.
param tutorLlmEnabled = false
param tutorLlmEndpoint = 'https://certigo-openai.services.ai.azure.com/api/projects/certigo-dev/openai/v1/'
param tutorLlmDeployment = 'gpt-5.4-mini'
param tutorLlmApiSurface = 'v1'

// Private DNS adoption for the AI Services account. Dev is the only environment
// with such an account, so this stays false everywhere else by default.
//
// Note the endpoint configured above resolves under *.services.ai.azure.com, a
// suffix that had NO private DNS zone at all. That is a live latent bug in this
// committed parameter file, not a hypothetical: with the account private, the
// Function App could not resolve its own configured endpoint even from inside
// vnet-certigo-dev. adoptOpenAiPrivateDns creates the missing zones.
param adoptOpenAiPrivateDns = true