// Production environment parameters. Hardening is on automatically for any non-dev
// env (Cosmos RBAC-only auth, Key Vault purge protection + 90-day soft delete,
// MCAPS LRS + versioned storage, CORS locked to []).
//
// Entra is wired to the certigoapp CIAM tenant (authority) and the backend
// "Certigo API" app registration (audience). No placeholder left to fill.
//
// Deploy:
//   az deployment sub create \
//     --location westeurope \
//     --template-file infra/main.bicep \
//     --parameters infra/params/prod.bicepparam
using '../main.bicep'

param env = 'prod'
param location = 'westeurope'
param appName = 'certigo'
param ciDeploymentPrincipalId = '15d2b34a-c0a0-4b5d-8360-b895a8164706'
// Adopt the live network rather than replacing in-use subnets.
param vnetAddressPrefix = '10.100.0.0/16'
param functionIntegrationSubnetPrefix = '10.100.1.0/24'
param functionIntegrationSubnetName = 'snet-func-flex'
param functionIntegrationSubnetNsgName = 'vnet-certigo-prod-snet-func-flex-nsg-westeurope'
param privateEndpointSubnetPrefix = '10.100.2.0/24'
param privateEndpointSubnetName = 'snet-private-endpoints'
param privateEndpointSubnetNsgName = 'vnet-certigo-prod-snet-private-endpoints-nsg-westeurope'
param storageBlobPrivateEndpointName = 'pe-st-certigo-prod-blob'
param storageQueuePrivateEndpointName = 'pe-st-certigo-prod-queue'
param storageTablePrivateEndpointName = 'pe-st-certigo-prod-table'
param keyVaultPrivateEndpointName = 'pe-kv-certigo-prod'
param cosmosPrivateEndpointName = 'pe-cosmos-certigo-prod-sql'
param storageBlobPrivateLinkConnectionName = 'pe-st-certigo-prod-blob-conn'
param storageQueuePrivateLinkConnectionName = 'pe-st-certigo-prod-queue-conn'
param storageTablePrivateLinkConnectionName = 'pe-st-certigo-prod-table-conn'
param keyVaultPrivateLinkConnectionName = 'pe-kv-certigo-prod-conn'
param cosmosPrivateLinkConnectionName = 'pe-cosmos-certigo-prod-sql-conn'
param storageDiagnosticSettingName = 'diag-to-log-analytics'
param blobServiceDiagnosticSettingName = 'diag-to-log-appi-certigo-prod'
param queueServiceDiagnosticSettingName = 'diag-to-log-appi-certigo-prod'
param tableServiceDiagnosticSettingName = 'diag-to-log-appi-certigo-prod'

// Cosmos DB region. West Europe has AZ-capacity limits for Cosmos (the reason dev
// deploys Cosmos in North Europe). We pin prod to North Europe too so the deploy
// does not fail on capacity; cross-region Functions -> Cosmos is fine (see main.bicep).
param cosmosLocation = 'northeurope'

// ============================================================================
// Microsoft Entra External ID (CIAM) — PRODUCTION.
// authMode is 'prod' for any non-dev env (main.bicep), so the backend runs the
// real EntraTokenValidator: these values MUST match the certigoapp CIAM tenant,
// otherwise every social/Entra login is rejected (401 aud/issuer mismatch).
// ============================================================================

// Authority of the certigoapp CIAM tenant (same tenant the mobile app targets:
// client id 4d1f1075-7bc5-4764-947b-701435a85f8c, redirect certigo://auth).
// ⚠️ Use the tenant-GUID subdomain (af721be8-….ciamlogin.com), NOT the vanity
// certigoapp.ciamlogin.com domain: the OIDC discovery document returns the GUID
// subdomain as the canonical issuer, and flutter_appauth validates the issuer
// strictly — a mismatch makes the token exchange fail silently (infinite spinner
// on social login). This value MUST match the app's ENTRA_AUTHORITY (Codemagic).
// CRITICAL: the next `cd-backend prod` overwrites the live app setting from here,
// so the wrong value here re-breaks login on every redeploy.
param entraAuthority = 'https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0'

// Audience = Application ID URI of the backend "Certigo API" app registration.
// The mobile ENTRA_API_SCOPE (api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915/user_impersonation)
// requests an access token for this API. "Certigo API" issues v2 access tokens
// (requestedAccessTokenVersion = 2), whose aud is ALWAYS the bare client id
// 12910b8e-6c75-4d51-91d8-4d5fb8a6e915; only v1 tokens carry aud = api://12910b8e-….
// EntraTokenValidator therefore accepts both spellings of this same app (measured on
// staging 2026-09-23: a v2 token with aud = client id was rejected with 401 before that).
// This is the BACKEND app registration client id (12910b8e-...), NOT the mobile client
// id (4d1f1075-...), both in the same tenant (af721be8-...).
param entraAudience = 'api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915'
param personLinkedIdentityV1 = 'off'

// alertEmail is injected by CD from the non-secret ALERT_EMAIL variable on the
// prod GitHub Environment. Never commit an operator address here.
// PUBLIC_WEB_ORIGIN, PUBLIC_DOMAIN_VERIFIED and
// APPLE_CIAM_DOMAIN_RECONFIGURED are also injected from this GitHub Environment.
// They remain empty/false until a controlled public domain is verified.

// Existing paid plans are retained live. Future reconciliation is owned by the
// PIM-approved governance stack, never by an environment deployment identity.
param enableDefenderPlans = false
param manageDefenderPlans = false

// Production PITR is explicit. Changing an existing Periodic account is irreversible.
param cosmosBackupMode = 'Continuous'
// Preserve the live 30-day PITR retention; production deployments must never
// silently downgrade the established recovery window.
param cosmosContinuousBackupTier = 'Continuous30Days'

// MCSB remains live and moves to the PIM-approved governance stack.
param deployMcsbPolicyAssignment = false
param mcsbEnforcementMode = 'DoNotEnforce'
param grantAlertReaderRole = true

// AI tutor (Azure OpenAI / Foundry): left DISABLED in prod (main.bicep default is
// false). No prod Azure OpenAI resource is provisioned (dev uses "certigo-openai"
// scoped to the certigo-dev project), so enabling it here without a prod endpoint
// would break the tutor feature. This does NOT block deployment — the backend
// falls back to the deterministic grounded tutor. Provide tutorLlmEnabled = true
// + tutorLlmEndpoint/tutorLlmDeployment when a prod OpenAI resource exists.

// Email/password JWT signing key: intentionally NOT set here. CD supplies
// authJwtSigningKey and authJwtSigningKeyExpiresOn out-of-band from the production
// Environment secret/variable pair. main.bicep rejects either value when omitted;
// never commit the key in this file.
