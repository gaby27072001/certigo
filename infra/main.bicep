// ============================================================================
// Certigo — root infrastructure (Bicep)
// Subscription-scoped: creates the resource group, then composes all modules.
// Backend stack: Azure Functions (isolated .NET 8) + Cosmos DB (serverless) +
// Blob Storage + Application Insights + Key Vault. Identity is Microsoft Entra
// External ID (configured out-of-band; client/tenant ids passed as params).
// ============================================================================
targetScope = 'subscription'

@description('Short environment name: dev | staging | prod.')
@allowed([ 'dev', 'staging', 'prod' ])
param env string

@description('Primary Azure region for all resources.')
param location string = 'westeurope'

@description('Region for Cosmos DB. Empty = same as location. Override when the primary region lacks Cosmos capacity (e.g. AZ-capacity blocks in West Europe).')
param cosmosLocation string = ''

@description('Base name used to derive resource names. Lowercase, no spaces.')
param appName string = 'certigo'

@description('Entra External ID authority URL. Format: https://<domain>.ciamlogin.com/<tenant-id>/v2.0. Replace with the value from Azure Portal → External ID tenant → Overview. Leave empty until the tenant is created.')
@secure()
param entraAuthority string = ''

@description('Entra External ID application (audience) client ID — the App Registration client ID. Replace with the value from Azure Portal → External ID → App registrations → <your-app> → Overview. Leave empty until configured.')
@secure()
param entraAudience string = ''
@description('Feature flag for the optional Azure OpenAI tutor completion. False keeps the deterministic grounded tutor only.')
param tutorLlmEnabled bool = false
@description('Azure OpenAI resource endpoint used by the tutor when enabled. Example: https://<resource>.openai.azure.com/.')
param tutorLlmEndpoint string = ''
@description('Azure OpenAI deployment name used by the tutor when enabled.')
param tutorLlmDeployment string = ''
@description('Tutor LLM API surface: "v1" for the Microsoft Foundry project-scoped v1 endpoint (default), or "classic" for the legacy deployments/.../chat/completions?api-version path.')
@allowed([
  'v1'
  'classic'
])
param tutorLlmApiSurface string = 'v1'
@description('Optional Azure OpenAI API version override for the tutor. Used only by the "classic" API surface.')
param tutorLlmApiVersion string = '2024-10-21'
@description('Optional explicit Azure OpenAI API key for the tutor. Leave empty to use the Function App managed identity instead.')
@secure()
param tutorLlmApiKey string = ''
@description('Signing key for email/password JWTs. Empty in dev/staging => a deterministic guid() is derived (stable across redeploys, not stored in the repo). Provide a real secret in prod to override.')
@secure()
param authJwtSigningKey string = ''
@description('Maximum output tokens requested from the tutor LLM.')
param tutorLlmMaxOutputTokens int = 400

@description('Optional email notified on security alerts (401/403/5xx spikes). Empty = no receiver.')
param alertEmail string = ''

@description('Enable paid Microsoft Defender for Cloud plans (per-resource cost). Default false — only free CSPM stays on.')
param enableDefenderPlans bool = false

@description('Force-assign the subscription-scoped MCSB policy even in dev (needs Owner / role-assignment rights at subscription scope). Default false; staging/prod assign it automatically.')
param forcePolicyAssignment bool = false

@description('Object (principal) id of the CI release runner managed identity. When set, it is granted read access (Key Vault Secrets User) to the Key Vault so the mobile release workflows can pull signing secrets — no signing secret in GitHub. Empty = skip (needs role-assignment rights to set).')
param ciRunnerPrincipalId string = ''

// Deterministic, collision-resistant suffix per environment/subscription.
var suffix = uniqueString(subscription().id, appName, env)
var rgName = 'rg-${appName}-${env}'
// Dev token bypass is allowed ONLY in the dev environment; staging/prod enforce
// Entra token validation ("prod" signals to the backend that Entra is required).
var authMode = env == 'dev' ? 'dev' : 'prod'
// Email/password JWT signing key. When not supplied, derive a deterministic value so
// tokens stay valid across redeploys without storing a secret in the repo or Key Vault.
var effectiveAuthJwtSigningKey = empty(authJwtSigningKey) ? guid(subscription().id, appName, env, 'auth-jwt-signing-key') : authJwtSigningKey
// Production-grade hardening is on for every non-dev environment: Cosmos RBAC-only
// auth, Key Vault purge protection + 90-day soft delete, geo-redundant + versioned
// storage, and a locked-down CORS origin set.
var hardened = env != 'dev'
// Subscription-scoped MCSB policy needs Owner-level rights; skip it in dev so a
// Contributor can run the dev smoke-test deploy without friction.
var assignPolicy = forcePolicyAssignment || env != 'dev'
// Cosmos may live in a different region than the rest when the primary region
// is capacity-constrained for Cosmos (cross-region Functions->Cosmos is fine).
var cosmosRegion = empty(cosmosLocation) ? location : cosmosLocation
var tags = {
  product: 'Certigo'
  env: env
  managedBy: 'bicep'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

module monitoring 'modules/appInsights.bicep' = {
  scope: rg
  name: 'monitoring'
  params: {
    name: 'appi-${appName}-${env}'
    location: location
    tags: tags
  }
}

module data 'modules/cosmos.bicep' = {
  scope: rg
  name: 'cosmos'
  params: {
    accountName: 'cosmos-${appName}-${env}-${suffix}'
    location: cosmosRegion
    databaseName: 'certigo'
    disableLocalAuth: hardened
    tags: tags
  }
}

module storage 'modules/storage.bicep' = {
  scope: rg
  name: 'storage'
  params: {
    // Storage account names: 3-24 chars, lowercase alphanumeric only.
    accountName: toLower('st${appName}${env}${take(suffix, 8)}')
    location: location
    skuName: hardened ? 'Standard_GRS' : 'Standard_LRS'
    enableVersioning: hardened
    blobSoftDeleteDays: hardened ? 30 : 7
    containerSoftDeleteDays: hardened ? 30 : 7
    // Keep public network access enabled across all envs: the Flex Consumption Function App
    // pulls its deployment package (app-package container) over the public endpoint via its
    // managed identity. Locking this down requires private endpoints (P1 hardening for
    // staging/prod). Set explicitly to prevent drift to Disabled (which caused a 403 on the
    // package pull in dev).
    publicNetworkAccess: 'Enabled'
    tags: tags
  }
}

module vault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: {
    name: 'kv-${appName}-${env}-${take(suffix, 6)}'
    location: location
    enablePurgeProtection: hardened
    softDeleteRetentionInDays: hardened ? 90 : 7
    tags: tags
  }
}

module api 'modules/functionApp.bicep' = {
  scope: rg
  name: 'functionApp'
  params: {
    functionAppName: 'func-${appName}-${env}-${suffix}'
    location: location
    storageAccountName: storage.outputs.accountName
    deploymentContainerName: storage.outputs.deploymentContainerName
    appInsightsConnectionString: monitoring.outputs.connectionString
    cosmosEndpoint: data.outputs.endpoint
    cosmosAccountName: data.outputs.accountName
    keyVaultName: vault.outputs.name
    authMode: authMode
    authJwtSigningKey: effectiveAuthJwtSigningKey
    entraAuthority: entraAuthority
    entraAudience: entraAudience
    tutorLlmEnabled: tutorLlmEnabled
    tutorLlmEndpoint: tutorLlmEndpoint
    tutorLlmDeployment: tutorLlmDeployment
    tutorLlmApiSurface: tutorLlmApiSurface
    tutorLlmApiVersion: tutorLlmApiVersion
    tutorLlmApiKey: tutorLlmApiKey
    tutorLlmMaxOutputTokens: tutorLlmMaxOutputTokens
    // Native mobile clients aren't subject to CORS; only dev keeps '*' (browser tooling).
    allowedCorsOrigins: env == 'dev' ? [ '*' ] : []
    tags: tags
  }
}

// Security observability: diagnostics -> Log Analytics + 401/403/5xx alerts.
module diagnostics 'modules/diagnostics.bicep' = if (env != 'dev') {
  scope: rg
  name: 'diagnostics'
  params: {
    functionAppName: api.outputs.functionAppName
    cosmosAccountName: data.outputs.accountName
    keyVaultName: vault.outputs.name
    workspaceId: monitoring.outputs.workspaceId
    alertEmail: alertEmail
    tags: tags
  }
}

// Microsoft Defender for Cloud (subscription scope). Free CSPM stays on; paid
// plans are gated behind enableDefenderPlans (default false).
module defender 'modules/defender.bicep' = {
  name: 'defender'
  params: {
    enablePaidPlans: enableDefenderPlans
  }
}

// Continuous compliance: MCSB initiative in audit-only mode (subscription scope).
module policy 'modules/policy.bicep' = if (assignPolicy) {
  name: 'policy'
  params: {
    assignmentLocation: location
  }
}

// Optional: grant the CI release runner's managed identity read access to the
// Key Vault, so the mobile release workflows pull signing secrets from KV
// (no signing secret stored in GitHub). Opt-in: skipped when the principal id
// is empty (and requires role-assignment rights at the Key Vault scope).
module ciMobileSecretsAccess 'modules/keyVaultSecretsAccess.bicep' = if (!empty(ciRunnerPrincipalId)) {
  scope: rg
  name: 'ciMobileSecretsAccess'
  params: {
    keyVaultName: vault.outputs.name
    principalId: ciRunnerPrincipalId
  }
}

output resourceGroup string = rg.name
output functionAppName string = api.outputs.functionAppName
output functionAppHostName string = api.outputs.defaultHostName
output cosmosEndpoint string = data.outputs.endpoint
output storageAccount string = storage.outputs.accountName
output keyVaultName string = vault.outputs.name
