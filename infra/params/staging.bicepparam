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
param vnetAddressPrefix = '10.61.0.0/24'
param functionIntegrationSubnetPrefix = '10.61.0.0/26'
param privateEndpointSubnetPrefix = '10.61.0.64/26'

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

// authJwtSigningKey and authJwtSigningKeyExpiresOn are supplied out-of-band by CD
// from the staging Environment secret/variable pair. main.bicep rejects an omitted
// value or expiration; never commit the key here.

// Mandatory monitored receiver for security and readiness alerts.
param alertEmail = 'secops@certigo.app'

// Paid Defender plans off by default; enable when budget is approved.
param enableDefenderPlans = false
param manageDefenderPlans = false

// Staging validates the same PITR contract as production.
param cosmosBackupMode = 'Continuous'
param cosmosContinuousBackupTier = 'Continuous7Days'

// Audit-only MCSB assignment is explicit and cannot deny staging deployments.
param deployMcsbPolicyAssignment = true
param mcsbEnforcementMode = 'DoNotEnforce'
param grantAlertReaderRole = true
