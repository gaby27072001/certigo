// Staging environment parameters. Mirrors prod hardening (Cosmos RBAC-only,
// Key Vault purge protection + 90-day soft delete, geo-redundant + versioned
// storage, locked CORS) but is a safe pre-production target. Hardening turns on
// automatically for any non-dev env (main.bicep), so staging is hardened by default.
//
// Deploy (ready to run once the two Entra values below are filled):
//   az deployment sub create \
//     --location westeurope \
//     --template-file infra/main.bicep \
//     --parameters infra/params/staging.bicepparam
using '../main.bicep'

param env = 'staging'
param location = 'westeurope'
param appName = 'certigo'
param ciDeploymentPrincipalId = '15d2b34a-c0a0-4b5d-8360-b895a8164706'
// Adopt the live network rather than replacing in-use subnets.
param vnetAddressPrefix = '10.80.0.0/16'
param functionIntegrationSubnetPrefix = '10.80.1.0/24'
param functionIntegrationSubnetName = 'snet-func-flex'
param privateEndpointSubnetPrefix = '10.80.2.0/24'
param privateEndpointSubnetName = 'snet-kv-private-endpoint'
param storageBlobPrivateEndpointName = 'pe-st-certigo-staging-blob'
param storageQueuePrivateEndpointName = 'pe-st-certigo-staging-queue'
param storageTablePrivateEndpointName = 'pe-st-certigo-staging-table'
param keyVaultPrivateEndpointName = 'pe-kv-certigo-staging'
param cosmosPrivateEndpointName = 'pe-cosmos-certigo-staging'
param storageBlobPrivateLinkConnectionName = 'conn-pe-st-certigo-staging-blob'
param storageQueuePrivateLinkConnectionName = 'conn-pe-st-certigo-staging-queue'
param storageTablePrivateLinkConnectionName = 'pe-st-certigo-staging-table-conn'
param keyVaultPrivateLinkConnectionName = 'conn-pe-kv-certigo-staging'
param cosmosPrivateLinkConnectionName = 'conn-pe-cosmos-certigo-staging'
param storageBlobPrivateDnsZoneGroupName = 'pdzg-st-certigo-staging-blob'
param storageQueuePrivateDnsZoneGroupName = 'default'
param storageTablePrivateDnsZoneGroupName = 'default'
param keyVaultPrivateDnsZoneGroupName = 'pdzg-kv-certigo-staging'
param cosmosPrivateDnsZoneGroupName = 'default'
param storageDiagnosticSettingName = 'diag-to-log-analytics'
param blobServiceDiagnosticSettingName = 'diag-to-log-analytics'
param queueServiceDiagnosticSettingName = 'diag-to-log-analytics'
param tableServiceDiagnosticSettingName = 'diag-to-log-analytics'

// Cosmos DB region. West Europe has AZ-capacity limits for Cosmos (the reason dev
// and prod both deploy Cosmos in North Europe). We pin staging to North Europe too
// so the deploy does not fail on capacity; cross-region Functions -> Cosmos is fine.
param cosmosLocation = 'northeurope'

// ============================================================================
// Microsoft Entra External ID (CIAM) — STAGING.
// authMode is 'prod' for any non-dev env (main.bicep), so the backend runs the
// real EntraTokenValidator against these values: the unauthenticated dev bypass
// (AUTH_ALLOW_DEV) is NOT available here. The two placeholders below are therefore
// the ONLY blockers before staging can be deployed — every social/Entra login is
// rejected (401 aud/issuer mismatch) until they are set. Do NOT invent GUIDs: fill
// them from a dedicated staging app registration (preferred), or temporarily reuse
// the prod values (see prod.bicepparam) knowing that staging logins then
// authenticate against the production tenant.
// Use the tenant-GUID subdomain (<tenant-guid>.ciamlogin.com), NOT a vanity domain:
// flutter_appauth validates the issuer strictly against the OIDC discovery document.
// ============================================================================
param entraAuthority = 'https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0'
// Audience = Application ID URI of the staging backend app registration.
param entraAudience = 'api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915'
param personLinkedIdentityV1 = 'off'

// authJwtSigningKey and authJwtSigningKeyExpiresOn are supplied out-of-band by CD
// from the staging Environment secret/variable pair. main.bicep rejects an omitted
// value or expiration; never commit the key here.

// alertEmail is injected by CD from the non-secret ALERT_EMAIL variable on the
// staging GitHub Environment. Never commit an operator address here.
// PUBLIC_WEB_ORIGIN, PUBLIC_DOMAIN_VERIFIED and
// APPLE_CIAM_DOMAIN_RECONFIGURED are also injected from this GitHub Environment.
// They remain empty/false until a controlled public domain is verified.

// Paid Defender plans off by default; enable when budget is approved.
param enableDefenderPlans = false
param manageDefenderPlans = false

// Staging validates the same PITR contract as production.
param cosmosBackupMode = 'Continuous'
param cosmosContinuousBackupTier = 'Continuous7Days'

// Subscription security controls are owned by the PIM-approved governance stack.
param deployMcsbPolicyAssignment = false
param mcsbEnforcementMode = 'DoNotEnforce'
param grantAlertReaderRole = true
