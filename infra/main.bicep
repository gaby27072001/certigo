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

@description('Entra External ID authority URL. Format: https://<domain>.ciamlogin.com/<tenant-id>/v2.0. Replace with the value from Azure Portal -> External ID tenant -> Overview. Leave empty until the tenant is created.')
@secure()
param entraAuthority string = ''

@description('Entra External ID application (audience) client ID — the App Registration client ID. Replace with the value from Azure Portal -> External ID -> App registrations -> <your-app> -> Overview. Leave empty until configured.')
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
@description('Signing key for email/password JWTs. Dev may derive a stable non-production value. Staging/prod must receive a non-empty secret through a secure deployment parameter.')
@secure()
param authJwtSigningKey string = ''
@description('Absolute ISO 8601 expiration of the active JWT signing key. This value is explicit so repeated deployments cannot silently extend the secret lifetime.')
param authJwtSigningKeyExpiresOn string = ''
@description('Previous JWT signing key accepted only during a planned rotation overlap. Leave empty outside a rotation window.')
@secure()
param authJwtPreviousSigningKey string = ''
@description('Absolute ISO 8601 expiration of the previous JWT signing key. Must be supplied together with authJwtPreviousSigningKey.')
param authJwtPreviousSigningKeyExpiresOn string = ''
@description('Maximum output tokens requested from the tutor LLM.')
param tutorLlmMaxOutputTokens int = 400

@description('Email notified on security and readiness alerts. Required outside dev.')
param alertEmail string = ''

@description('Data residency for the Azure Communication Services Email resource (e.g. Europe, United States).')
param emailDataLocation string = 'Europe'

@description('Enable paid Microsoft Defender for Cloud plans (per-resource cost). Default false — only free CSPM stays on.')
param enableDefenderPlans bool = false

@description('Manage subscription-wide Defender pricing. Requires Security Admin or equivalent and must have one IaC owner per subscription.')
param manageDefenderPlans bool = false

@description('Deploy the subscription-scoped MCSB policy assignment.')
param deployMcsbPolicyAssignment bool = false

@description('MCSB policy enforcement mode. Only audit-only DoNotEnforce is supported until remediation identities and exemptions are designed.')
@allowed([ 'DoNotEnforce' ])
param mcsbEnforcementMode string = 'DoNotEnforce'

@description('Object (principal) id of the CI release runner managed identity. When set, it is granted read access (Key Vault Secrets User) to the Key Vault so the mobile release workflows can pull signing secrets — no signing secret in GitHub. Empty = skip (needs role-assignment rights to set).')
param ciRunnerPrincipalId string = ''

@description('Object id of the GitHub Actions OIDC service principal granted container-scoped deployment upload and account-scoped user-delegation rights.')
param ciDeploymentPrincipalId string

@description('Resource group containing the trusted CI runner virtual network.')
param ciVnetResourceGroupName string = 'rg-certigo-ci'

@description('Trusted CI runner virtual network peered to each application environment.')
param ciVnetName string = 'vnet-certigo-ci'

@description('When true, the security log-search alerts get a system-assigned identity + least-privilege Log Analytics Reader role on the workspace (most robust). Default false: creating that role assignment needs Microsoft.Authorization/roleAssignments/write at the workspace scope, which the deployer may lack — off keeps the deployment guaranteed to succeed. Turn on once the deployer has role-assignment rights.')
param grantAlertReaderRole bool = false

@description('Environment virtual network address space. Keep environment ranges non-overlapping to allow future peering.')
param vnetAddressPrefix string

@description('Dedicated Flex Consumption integration subnet. /27 is the supported minimum; /26 is used for capacity.')
param functionIntegrationSubnetPrefix string

@description('Dedicated subnet for private endpoints.')
param privateEndpointSubnetPrefix string

@description('Explicit Cosmos backup mode.')
@allowed([ 'Periodic', 'Continuous' ])
param cosmosBackupMode string

@description('Cosmos continuous backup retention tier.')
@allowed([ 'Continuous7Days', 'Continuous30Days' ])
param cosmosContinuousBackupTier string = 'Continuous7Days'

@description('Cosmos periodic backup interval in minutes.')
@minValue(60)
@maxValue(1440)
param cosmosPeriodicBackupIntervalMinutes int = 240

@description('Cosmos periodic backup retention in hours.')
@minValue(8)
@maxValue(720)
param cosmosPeriodicBackupRetentionHours int = 8

@description('Cosmos periodic backup storage redundancy.')
@allowed([ 'Local', 'Geo', 'Zone' ])
param cosmosPeriodicBackupStorageRedundancy string = 'Geo'

// Deterministic, collision-resistant suffix per environment/subscription.
var suffix = uniqueString(subscription().id, appName, env)
// Key Vault max name length is 24. Reserve the fixed prefix 'kv-${appName}-${env}-'
// and cap the unique suffix at 6, shrinking it only when the prefix leaves less room
// (staging => 5). dev/prod prefixes are short enough that this still yields 6.
var kvSuffixLen = min(6, 24 - length('kv-${appName}-${env}-'))
var rgName = 'rg-${appName}-${env}'
// Dev token bypass is allowed ONLY in the dev environment; staging/prod enforce
// Entra token validation ("prod" signals to the backend that Entra is required).
var authMode = env == 'dev' ? 'dev' : 'prod'
// Production-grade hardening is on for every non-dev environment: Cosmos RBAC-only
// auth, Key Vault purge protection + 90-day soft delete, geo-redundant + versioned
// storage, and a locked-down CORS origin set.
var hardened = env != 'dev'
// The deterministic fallback is intentionally restricted to dev. fail() stops
// staging/prod deployment evaluation with a clear error before any derivable key
// can be provisioned.
var effectiveAuthJwtSigningKey = empty(authJwtSigningKey)
  ? (hardened
    ? fail('authJwtSigningKey must be supplied securely for staging and production deployments.')
    : guid(subscription().id, appName, env, 'auth-jwt-signing-key'))
  : authJwtSigningKey
var effectiveAuthJwtSigningKeyExpiresOn = empty(authJwtSigningKeyExpiresOn)
  ? fail('authJwtSigningKeyExpiresOn must be an explicit absolute ISO 8601 timestamp.')
  : authJwtSigningKeyExpiresOn
var hasPreviousJwtSigningKey = !empty(authJwtPreviousSigningKey)
var hasPreviousJwtSigningKeyExpiration = !empty(authJwtPreviousSigningKeyExpiresOn)
var usePreviousJwtSigningKey = hasPreviousJwtSigningKey == hasPreviousJwtSigningKeyExpiration
  ? hasPreviousJwtSigningKey
  : fail('authJwtPreviousSigningKey and authJwtPreviousSigningKeyExpiresOn must be supplied together.')
var effectiveAlertEmail = env != 'dev' && empty(alertEmail)
  ? fail('alertEmail is required for staging and production deployments.')
  : alertEmail
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
    retentionInDays: hardened ? 90 : 30
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
    backupMode: cosmosBackupMode
    continuousBackupTier: cosmosContinuousBackupTier
    periodicBackupIntervalMinutes: cosmosPeriodicBackupIntervalMinutes
    periodicBackupRetentionHours: cosmosPeriodicBackupRetentionHours
    periodicBackupStorageRedundancy: cosmosPeriodicBackupStorageRedundancy
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
    ciDeploymentPrincipalId: ciDeploymentPrincipalId
    tags: tags
  }
}

module vault 'modules/keyvault.bicep' = {
  scope: rg
  name: 'keyvault'
  params: {
    // Key Vault names are capped at 24 chars. 'kv-${appName}-${env}-' is 12+len(env)
    // chars, so a fixed 6-char suffix overflows for longer env names (staging => 25).
    // Adapt the suffix length so staging fits in 24 while dev/prod stay byte-identical
    // (both already resolve to 6, so their live vault names are unchanged).
    name: 'kv-${appName}-${env}-${take(suffix, kvSuffixLen)}'
    location: location
    softDeleteRetentionInDays: hardened ? 90 : 7
    jwtSigningKey: effectiveAuthJwtSigningKey
    jwtSigningKeyExpiresOn: effectiveAuthJwtSigningKeyExpiresOn
    tags: tags
  }
}

// One zone set in the CI hub is shared by all environments. Azure forbids
// linking one VNet to duplicate private DNS namespaces.
module sharedPrivateDns 'modules/sharedPrivateDns.bicep' = {
  scope: resourceGroup(ciVnetResourceGroupName)
  name: 'privateDns-${appName}-hub'
  params: {
    ciVnetId: resourceId(ciVnetResourceGroupName, 'Microsoft.Network/virtualNetworks', ciVnetName)
    ciVnetName: ciVnetName
    tags: {
      product: 'Certigo'
      managedBy: 'bicep'
      scope: 'shared'
    }
  }
}

// Private endpoints consume the existing hub-zone ids directly. Per-environment
// app VNet links are deployed separately in the hub resource group.
module privateNetwork 'modules/privateNetwork.bicep' = {
  scope: rg
  name: 'privateNetwork'
  params: {
    vnetName: 'vnet-${appName}-${env}'
    location: location
    vnetAddressPrefix: vnetAddressPrefix
    functionIntegrationSubnetPrefix: functionIntegrationSubnetPrefix
    privateEndpointSubnetPrefix: privateEndpointSubnetPrefix
    storageAccountName: storage.outputs.accountName
    keyVaultName: vault.outputs.name
    cosmosAccountName: data.outputs.accountName
    ciVnetResourceGroupName: ciVnetResourceGroupName
    ciVnetName: ciVnetName
    blobZoneId: sharedPrivateDns.outputs.blobZoneId
    queueZoneId: sharedPrivateDns.outputs.queueZoneId
    tableZoneId: sharedPrivateDns.outputs.tableZoneId
    vaultZoneId: sharedPrivateDns.outputs.vaultZoneId
    cosmosZoneId: sharedPrivateDns.outputs.cosmosZoneId
    tags: tags
  }
}

module privateDnsAppLinks 'modules/privateDnsAppLinks.bicep' = {
  scope: resourceGroup(ciVnetResourceGroupName)
  name: 'privateDnsLinks-${appName}-${env}'
  params: {
    appVnetId: privateNetwork.outputs.vnetId
    appVnetName: privateNetwork.outputs.vnetName
    tags: tags
  }
}

module ciVnetPeering 'modules/ciVnetPeering.bicep' = {
  scope: resourceGroup(ciVnetResourceGroupName)
  name: 'peer-${appName}-${env}'
  params: {
    ciVnetName: ciVnetName
    appVnetId: privateNetwork.outputs.vnetId
    appVnetName: privateNetwork.outputs.vnetName
  }
}

module previousJwtSecret 'modules/keyvaultPreviousJwtSecret.bicep' = if (usePreviousJwtSigningKey) {
  scope: rg
  name: 'keyvaultPreviousJwtSecret'
  params: {
    keyVaultName: vault.outputs.name
    jwtPreviousSigningKey: authJwtPreviousSigningKey
    jwtPreviousSigningKeyExpiresOn: authJwtPreviousSigningKeyExpiresOn
  }
}

// Azure Communication Services Email — transactional sender for the
// email/password verification message. Global resource with an Azure-managed
// domain (no DNS setup). Its outputs feed the Function App app settings below.
module email 'modules/communicationEmail.bicep' = {
  scope: rg
  name: 'communicationEmail'
  params: {
    name: '${appName}-${env}-${take(suffix, 8)}'
    dataLocation: emailDataLocation
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
    appInsightsName: monitoring.outputs.name
    cosmosEndpoint: data.outputs.endpoint
    cosmosAccountName: data.outputs.accountName
    keyVaultName: vault.outputs.name
    functionIntegrationSubnetId: privateNetwork.outputs.functionIntegrationSubnetId
    authMode: authMode
    authJwtSigningKeySecretUri: vault.outputs.jwtSecretUri
    authJwtPreviousSigningKeySecretUri: previousJwtSecret.?outputs.?jwtSecretUri ?? ''
    entraAuthority: entraAuthority
    entraAudience: entraAudience
    tutorLlmEnabled: tutorLlmEnabled
    tutorLlmEndpoint: tutorLlmEndpoint
    tutorLlmDeployment: tutorLlmDeployment
    tutorLlmApiSurface: tutorLlmApiSurface
    tutorLlmApiVersion: tutorLlmApiVersion
    tutorLlmApiKey: tutorLlmApiKey
    tutorLlmMaxOutputTokens: tutorLlmMaxOutputTokens
    // Email verification wiring. The verify base URL is derived from the (known,
    // deterministic) Function App name to avoid a self-reference on its hostname.
    acsEmailEndpoint: email.outputs.endpoint
    acsEmailSender: email.outputs.senderAddress
    acsEmailConnectionString: email.outputs.connectionString
    emailVerifyBaseUrl: 'https://func-${appName}-${env}-${suffix}.azurewebsites.net/api/auth/verify-email'
    // Native mobile clients aren't subject to CORS; only dev keeps '*' (browser tooling).
    allowedCorsOrigins: env == 'dev' ? [ '*' ] : []
    tags: tags
  }
  dependsOn: [
    privateDnsAppLinks
  ]
}

// Azure AI Services account for the LLM tutor. Brought under IaC to remove the
// drift documented in audit finding G (the 'certigo-openai' account was created
// out-of-band). Gated on tutorLlmEnabled (dev only today). accountName/location
// target the existing dev resource: on the first apply, review the what-if so the
// account is adopted/updated, not recreated. Deployed after 'api' because it needs
// the Function App managed-identity principal id for the OpenAI User role grant.
module tutor 'modules/openai.bicep' = if (tutorLlmEnabled) {
  scope: rg
  name: 'openai'
  params: {
    accountName: 'certigo-openai'
    location: 'swedencentral'
    deploymentName: tutorLlmDeployment
    functionAppPrincipalId: api.outputs.principalId
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
    storageAccountName: storage.outputs.accountName
    workspaceId: monitoring.outputs.workspaceId
    location: location
    alertEmail: effectiveAlertEmail
    grantAlertReaderRole: grantAlertReaderRole
    tags: tags
  }
}

// Microsoft Defender for Cloud (subscription scope). Free CSPM stays on; paid
// plans are gated behind enableDefenderPlans (default false).
module defender 'modules/defender.bicep' = {
  name: 'defender'
  params: {
    enablePaidPlans: enableDefenderPlans
    managePlans: manageDefenderPlans
  }
}

// Continuous compliance: MCSB initiative in audit-only mode (subscription scope).
module policy 'modules/policy.bicep' = if (deployMcsbPolicyAssignment) {
  name: 'policy'
  params: {
    assignmentLocation: location
    enforcementMode: mcsbEnforcementMode
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
output deploymentContainerName string = storage.outputs.deploymentContainerName
output storageBlobEndpoint string = storage.outputs.primaryBlobEndpoint
output privateDnsResourceGroup string = ciVnetResourceGroupName
output keyVaultName string = vault.outputs.name
output virtualNetworkId string = privateNetwork.outputs.vnetId
output cosmosBackupMode string = cosmosBackupMode
