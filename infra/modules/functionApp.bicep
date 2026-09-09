// Azure Functions (Linux Flex Consumption, .NET 8 isolated worker) hosting the
// Certigo API. Uses a preprovisioned user-assigned identity for FC1 host storage,
// Key Vault references and Application Insights, plus a system-assigned identity
// for Cosmos data-plane access. No storage account keys are used.
@description('Function App name (globally unique).')
param functionAppName string
param location string

@description('Storage account (in this RG) used by the Functions runtime.')
param storageAccountName string

@description('External immutable content Blob endpoint from PR #290.')
param contentBlobEndpoint string = ''

@description('External immutable content reader UAMI client id from PR #290.')
param contentReaderClientId string = ''

@description('External immutable content reader UAMI resource id from PR #290.')
param contentReaderResourceId string = ''

@description('Container holding immutable content release descriptors.')
param contentDescriptorContainerName string

@description('Container holding immutable public content packages.')
param contentPublicContainerName string

@description('Container holding immutable private answer-key packages.')
param contentPrivateContainerName string

@description('Blob container (in the storage account) holding the deployment package.')
param deploymentContainerName string = 'app-package'

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Application Insights component name, used for managed-identity telemetry ingestion.')
param appInsightsName string

@description('Cosmos DB account endpoint.')
param cosmosEndpoint string

@description('Cosmos DB database name.')
param cosmosDatabaseName string

@description('Key Vault name for RBAC secret access.')
param keyVaultName string

@description('Cosmos DB account name, for the data-plane (SQL) role assignment.')
param cosmosAccountName string

@description('Resource ID of the dedicated Flex Consumption virtual network integration subnet.')
param functionIntegrationSubnetId string

@description('Authentication mode. "dev" enables the permissive dev token validator (safe default for local/dev); "prod" enforces Entra External ID token validation. Set to "prod" in staging/production once the Entra External ID tenant is configured. Any value other than "dev" also enables Entra validation.')
@allowed([ 'dev', 'prod', '' ])
param authMode string = 'dev'

@description('Active content repository implementation. Keep legacy until a verified release is promoted.')
@allowed([ 'legacy', 'versioned' ])
param contentRepositoryMode string = 'legacy'

@description('Entra External ID authority URL. Format: https://<domain>.ciamlogin.com/<tenant-id>/v2.0. Replace with the value from Azure Portal → External ID tenant → Overview. Leave empty until the tenant is created.')
@secure()
param entraAuthority string = ''

@description('Entra External ID application (audience) client ID — the App Registration client ID in the External ID tenant. Replace with the value from Azure Portal → External ID → App registrations → <your-app> → Overview. Leave empty until configured.')
@secure()
param entraAudience string = ''
@description('Mobile Entra application client ID expected in fresh OIDC ID-token proofs for sensitive account deletion.')
@secure()
param entraReauthAudience string = ''
@description('External ID tenant ID used by the dedicated Microsoft Graph confidential client.')
@secure()
param entraGraphTenantId string = ''
@description('Application client ID of the dedicated Microsoft Graph confidential client in the External ID tenant.')
@secure()
param entraGraphClientId string = ''
@description('Versioned Azure Key Vault secret URI containing the Microsoft Graph confidential-client secret.')
@secure()
param entraGraphClientSecretSecretUri string = ''
@description('Feature flag for the account-deletion API. Keep false until the destructive Cosmos integration gate passes.')
param accountDeletionEnabled bool = false
@description('Person/LinkedIdentity V1 mode. Only off and additive shadow writes are supported by this runtime.')
@allowed([
  'off'
  'shadow'
])
param personLinkedIdentityV1 string = 'off'
@description('Organization/Membership V1 mode. "off" (default) leaves the V1 HTTP surface at 404 in every environment. "shadow" additionally runs a strictly read-only background observation (incomplete-offboarding count, team membership volumetry) with non-PII telemetry; it adds no reachable route and never creates, updates, or deletes Organization/Membership data. A future read/write mode requires its own ADR.')
@allowed([
  'off'
  'shadow'
])
param organizationMembershipV1 string = 'off'
@description('Feature flag for the optional Azure OpenAI tutor completion. False keeps the deterministic grounded tutor only.')
param tutorLlmEnabled bool = false
@description('Azure OpenAI resource endpoint used by the tutor when the feature flag is enabled. Example: https://<resource>.openai.azure.com/.')
param tutorLlmEndpoint string = ''
@description('Azure OpenAI deployment name used by the tutor when the feature flag is enabled.')
param tutorLlmDeployment string = ''
@description('Tutor LLM API surface: "v1" for the Microsoft Foundry project-scoped v1 endpoint (default), or "classic" for the legacy deployments/.../chat/completions?api-version path.')
@allowed([
  'v1'
  'classic'
])
param tutorLlmApiSurface string = 'v1'
@description('Optional Azure OpenAI API version override. Used only by the "classic" API surface; ignored when tutorLlmApiSurface is "v1".')
param tutorLlmApiVersion string = '2024-10-21'
@description('Optional explicit API key for the tutor LLM. Leave empty to use the Function App managed identity instead.')
@secure()
param tutorLlmApiKey string = ''
@description('Key Vault secret URI holding the JWT signing key. Injected into the AUTH_JWT_SIGNING_KEY app setting as a KV reference, resolved at runtime by the managed identity.')
param authJwtSigningKeySecretUri string
@description('Optional Key Vault secret URI for the previous JWT signing key during a bounded rotation overlap.')
param authJwtPreviousSigningKeySecretUri string = ''
@description('Maximum output tokens requested from the tutor LLM.')
param tutorLlmMaxOutputTokens int = 400
param tags object = {}

@description('CORS allowed origins. Native mobile clients are not subject to CORS, so this can be [] (none) for staging/prod; dev passes ["*"] for browser-based tooling.')
param allowedCorsOrigins array = [ '*' ]

@description('Azure Communication Services Email data-plane endpoint. Empty disables managed-identity email sending (the API then uses a logging no-op, so sign-up still works).')
param acsEmailEndpoint string = ''

@description('ACS Email sender address, e.g. DoNotReply@<azure-managed-domain>. Empty disables real email sending.')
param acsEmailSender string = ''

@description('ACS Email connection string. Optional; when provided the API uses it instead of the managed identity.')
@secure()
param acsEmailConnectionString string = ''

@description('Public base URL of the GET email-verification endpoint, used to build the confirmation link in the email.')
param emailVerifyBaseUrl string = ''

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

// A user-assigned identity breaks the FC1 deployment bootstrap cycle: it and its
// data-plane roles exist before the Function App tries to read the package.
resource hostStorageIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${functionAppName}-host'
  location: location
  tags: tags
}

var storageBlobDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)
var storageQueueDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
)
var storageTableDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
)
var monitoringMetricsPublisher = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '3913510d-42f4-4e42-8a64-420c390055eb'
)
var keyVaultSecretsUser = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

resource deploymentBlobAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, hostStorageIdentity.id, storageBlobDataContributor)
  properties: {
    principalId: hostStorageIdentity.properties.principalId
    roleDefinitionId: storageBlobDataContributor
    principalType: 'ServicePrincipal'
  }
}

resource hostQueueAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, hostStorageIdentity.id, storageQueueDataContributor)
  properties: {
    principalId: hostStorageIdentity.properties.principalId
    roleDefinitionId: storageQueueDataContributor
    principalType: 'ServicePrincipal'
  }
}

resource hostTableAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, hostStorageIdentity.id, storageTableDataContributor)
  properties: {
    principalId: hostStorageIdentity.properties.principalId
    roleDefinitionId: storageTableDataContributor
    principalType: 'ServicePrincipal'
  }
}

resource appInsightsPublisherAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appInsights
  name: guid(appInsights.id, hostStorageIdentity.id, monitoringMetricsPublisher)
  properties: {
    principalId: hostStorageIdentity.properties.principalId
    roleDefinitionId: monitoringMetricsPublisher
    principalType: 'ServicePrincipal'
  }
}

resource hostVaultAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: vault
  name: guid(vault.id, hostStorageIdentity.id, keyVaultSecretsUser)
  properties: {
    principalId: hostStorageIdentity.properties.principalId
    roleDefinitionId: keyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

var contentReaderIdentityAssignment = empty(contentReaderResourceId) ? {} : {
  '${contentReaderResourceId}': {}
}

resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'plan-${functionAppName}'
  location: location
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: { reserved: true } // Linux
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: union({
      '${hostStorageIdentity.id}': {}
    }, contentReaderIdentityAssignment)
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    keyVaultReferenceIdentity: hostStorageIdentity.id
    virtualNetworkSubnetId: functionIntegrationSubnetId
    // Flex Consumption: runtime + deployment are declared in functionAppConfig.
    // The deployment package is pulled from blob storage using the app's managed
    // identity (no shared key — compatible with allowSharedKeyAccess=false).
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentContainerName}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: hostStorageIdentity.id
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 40
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'dotnet-isolated'
        version: '8.0'
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      // Flex VNet integration reaches RFC1918 private endpoints without Route All.
      // Keep public dependencies on platform egress unless a NAT/firewall is added.
      vnetRouteAllEnabled: false
      cors: {
        // Native mobile clients aren't subject to CORS; staging/prod pass [] and
        // tighten via API Management later. Dev allows '*' for browser tooling.
        allowedOrigins: allowedCorsOrigins
      }
    }
  }
  dependsOn: [
    deploymentBlobAccess
    hostQueueAccess
    hostTableAccess
    appInsightsPublisherAccess
    hostVaultAccess
  ]
}

// Apply app settings after the site, its managed identity, and data-plane access
// exist. Flex Consumption workers read private Key Vault secrets through the SDK;
// only the versioned, non-secret URI is passed in application configuration.
var accountDeletionGraphSettings = accountDeletionEnabled ? {
  ENTRA_REAUTH_AUDIENCE: entraReauthAudience
  ENTRA_GRAPH_TENANT_ID: entraGraphTenantId
  ENTRA_GRAPH_CLIENT_ID: entraGraphClientId
  ENTRA_GRAPH_CLIENT_SECRET_SECRET_URI: entraGraphClientSecretSecretUri
} : {}
var contentRuntimeSettings = empty(contentBlobEndpoint) ? {} : {
  CONTENT_BLOB_ENDPOINT: contentBlobEndpoint
  CONTENT_STORAGE_CLIENT_ID: contentReaderClientId
}

resource functionAppSettings 'Microsoft.Web/sites/config@2024-04-01' = {
  parent: functionApp
  name: 'appsettings'
  properties: union({
    // Identity-based AzureWebJobsStorage (no key). The managed identity is
    // granted Blob/Queue data roles on the storage account above.
    AzureWebJobsStorage__accountName: storage.name
    AzureWebJobsStorage__credential: 'managedidentity'
    AzureWebJobsStorage__clientId: hostStorageIdentity.properties.clientId
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
    APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'ClientId=${hostStorageIdentity.properties.clientId};Authorization=AAD'
    COSMOS_ENDPOINT: cosmosEndpoint
    COSMOS_DATABASE: cosmosDatabaseName
    BLOB_ENDPOINT: storage.properties.primaryEndpoints.blob
    DEPLOYMENT_CONTAINER_NAME: deploymentContainerName
    CONTENT_DESCRIPTOR_CONTAINER: contentDescriptorContainerName
    CONTENT_PUBLIC_CONTAINER: contentPublicContainerName
    CONTENT_PRIVATE_CONTAINER: contentPrivateContainerName
    CONTENT_REPOSITORY_MODE: contentRepositoryMode
    CONTENT_ADMIN_ROLE: 'Content.Release.Admin'
    CONTENT_ADMIN_ALLOW_DEV: authMode == 'dev' ? 'true' : 'false'
    CONTENT_ALLOW_MUTABLE_BLOBS: 'false'
    CONTENT_IMPORT_MAX_FILES: '10000'
    CONTENT_IMPORT_MAX_FILE_BYTES: '2097152'
    CONTENT_IMPORT_MAX_RELEASE_BYTES: '134217728'
    CONTENT_IMPORT_MAX_COSMOS_ITEM_BYTES: '1900000'
    HEALTH_PROBE_TIMEOUT_SECONDS: '5'
    HEALTH_PLATFORM_CLIENT_ID: hostStorageIdentity.properties.clientId
    KeyVault__HealthSecretName: 'AUTH-JWT-SIGNING-KEY'
    AUTH_MODE: authMode
    AUTH_ALLOW_DEV: authMode == 'dev' ? 'true' : 'false'
    AUTH_JWT_SIGNING_KEY_SECRET_URI: authJwtSigningKeySecretUri
    AUTH_JWT_PREVIOUS_SIGNING_KEY_SECRET_URI: authJwtPreviousSigningKeySecretUri
    ENTRA_AUTHORITY: entraAuthority
    ENTRA_AUDIENCE: entraAudience
    ACCOUNT_DELETION_ENABLED: string(accountDeletionEnabled)
    PERSON_LINKED_IDENTITY_V1: personLinkedIdentityV1
    ORGANIZATION_MEMBERSHIP_V1: organizationMembershipV1
    // Cadence d'échantillonnage de deux lectures Cosmos (ObserveOrganizationMembershipShadowV1).
    // Aucune borne fonctionnelle : contrairement au recovery ci-dessous, l'espacer ne dégrade
    // qu'une résolution d'observation. Alignée sur ENTERPRISE_LEARNING_RECOVERY_SCHEDULE parce
    // que les deux timers partagent le même hôte Functions : la cadence effective des réveils
    // est le PGCD des deux, donc espacer une seule des deux ne réduit rien.
    ORGANIZATION_SHADOW_OBSERVATION_SCHEDULE: '0 */15 * * * *'
    ENTERPRISE_LEARNING_METRICS_V1: 'off'
    // CONTRAINTE — ne pas espacer au-delà de 15 min sans relire ADR-016.
    // ADR-016 (« Cosmos et exactly-once ») borne cette cadence par deux durées :
    //   * lease de claim d'un intent outbox : 2 min  -> borne BASSE (en deçà, les tentatives
    //     se chevauchent sans pouvoir claim, sans bénéfice) ;
    //   * expiration d'un intent après matérialisation : 1 h -> borne HAUTE STRICTE. Un intent
    //     laissé par un worker crashé doit être re-claimé APRÈS l'expiration du lease et AVANT
    //     l'expiration de l'intent, sinon la reprise est définitivement perdue.
    // 15 min laisse 4 tentatives dans la fenêtre d'1 h. Une cadence horaire tombe pile sur la
    // borne (0 tentative garantie) et une cadence quotidienne la dépasse : les deux CASSENT la
    // garantie de reprise SANS AUCUNE ERREUR VISIBLE, et seulement une fois
    // ENTERPRISE_LEARNING_METRICS_V1 activé — c'est-à-dire jamais pendant les tests.
    // La fonction sort immédiatement tant que le mode vaut 'off' : la justesse de cette valeur
    // n'est donc vérifiable par aucune exécution réelle avant l'activation.
    ENTERPRISE_LEARNING_RECOVERY_SCHEDULE: '0 */15 * * * *'
    TUTOR_LLM_ENABLED: string(tutorLlmEnabled)
    TUTOR_LLM_ENDPOINT: tutorLlmEndpoint
    TUTOR_LLM_DEPLOYMENT: tutorLlmDeployment
    TUTOR_LLM_API_SURFACE: tutorLlmApiSurface
    TUTOR_LLM_API_VERSION: tutorLlmApiVersion
    TUTOR_LLM_API_KEY: tutorLlmApiKey
    TUTOR_LLM_MAX_OUTPUT_TOKENS: string(tutorLlmMaxOutputTokens)
    KeyVault__Uri: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
    ACS_EMAIL_ENDPOINT: acsEmailEndpoint
    ACS_EMAIL_SENDER: acsEmailSender
    ACS_EMAIL_CONNECTION_STRING: acsEmailConnectionString
    EMAIL_VERIFY_BASE_URL: emailVerifyBaseUrl
  }, accountDeletionGraphSettings, contentRuntimeSettings)
}

// Grant the Function App's managed identity Cosmos DB data-plane access via the
// built-in "Cosmos DB Built-in Data Contributor" SQL role. Required because the
// API authenticates to Cosmos with its managed identity (DefaultAzureCredential),
// not account keys. Without this assignment every Cosmos call returns 403.
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

var cosmosDataContributorRoleId = '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'

resource cosmosDataAccess 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-11-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, functionApp.id, '00000000-0000-0000-0000-000000000002')
  properties: {
    roleDefinitionId: cosmosDataContributorRoleId
    principalId: functionApp.identity.principalId
    scope: cosmosAccount.id
  }
}

output functionAppName string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
output principalId string = functionApp.identity.principalId
output hostStoragePrincipalId string = hostStorageIdentity.properties.principalId
