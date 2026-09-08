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

// AI tutor infrastructure is managed independently from runtime activation.
// The live read-only audit confirms the private/keyless AIServices account,
// gpt-5.4-mini deployment and existing OpenAI User role assignment. Runtime
// remains disabled because the Foundry private DNS path is incomplete.
// Do not flip this flag until that DNS adoption has its own approved Provider
// what-if and backend/run-tutor-llm-live-gate.ps1 proves a real LLM response.
// See docs/deployment-runbook.md §T0.5 "Chemin 3".
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

// Immutable content supply chain — producer outputs from the content stack.
//
// These three are all-or-nothing by construction: main.bicep fail()s unless all
// three are set or all three are empty ("contentBlobEndpoint,
// contentReaderClientId and contentReaderResourceId must be configured together
// from PR #290 outputs"). Each value below was verified against Azure on
// 2026-09-07, not copied from a brief:
//   - stcertigocntz3wqbdww exists in rg-certigo-content with
//     publicNetworkAccess=Disabled, allowSharedKey=false, and an Approved
//     private endpoint in vnet-certigo-ci/snet-runners. Its private address is
//     deliberately NOT quoted here: private-networking.test.mjs asserts that no
//     environment parameter file mentions the CI runner VNet address range, and
//     that assertion is a raw-text grep which cannot distinguish a declaration
//     from prose describing one;
//   - the reader clientId matches `az identity show -n id-certigo-content-reader`;
//   - that identity holds Storage Blob Data Reader on exactly three containers,
//     whose names match the main.bicep defaults, so the three *ContainerName
//     params are deliberately NOT overridden here.
//
// contentRepositoryMode is deliberately absent: 'legacy' is already the
// main.bicep default, and infra/tests/content-storage.test.mjs asserts that no
// committed environment file declares that parameter at all (the assertion is a
// raw-text grep, so even quoting the declaration here would trip it). The
// versioned flip is therefore a deploy-time parameter, never a committed one.
param contentBlobEndpoint = 'https://stcertigocntz3wqbdww.blob.core.windows.net/'
param contentReaderClientId = 'cabec54e-0536-4c0b-9ddb-f8b951725bcb'
param contentReaderResourceId = '/subscriptions/b8952c8c-8f72-469d-99cd-ac906da4e2fc/resourceGroups/rg-certigo-identities/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-certigo-content-reader'