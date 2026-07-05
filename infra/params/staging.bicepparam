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
param entraAuthority = 'https://certigo.ciamlogin.com/<tenant-guid>/v2.0'
// Audience = Application ID URI of the staging backend app registration.
param entraAudience = 'api://<api-client-id>'

// Email notified on 401/403/5xx spikes (optional but recommended pre-prod).
param alertEmail = ''

// Paid Defender plans off by default; enable when budget is approved.
param enableDefenderPlans = false

// ============================================================================
// Network posture (public network access) — mirrors the prod beta trade-off.
// enablePrivateNetworking is intentionally LEFT AT false: the data resources
// (Storage, Cosmos DB, Key Vault) keep their PUBLIC network endpoints Enabled.
// This is required today because the Flex Consumption (FC1) Function App has NO
// private endpoints / VNet integration, so it must reach Storage (deployment
// package pull), Key Vault (secrets at startup) and Cosmos over the public endpoint
// via its managed identity. Setting enablePrivateNetworking = true WITHOUT first
// provisioning those private endpoints takes the backend fully offline (503/timeout).
// Security is NOT relaxed by this flag: access stays RBAC-only (Cosmos
// disableLocalAuth=true, Storage allowSharedKeyAccess=false, Key Vault RBAC) — only
// the public NETWORK filter is left open. Same posture as prod for the beta.
// Phase 2: provision private endpoints + VNet integration for the Function App, then
// flip the line below to true to close the public endpoints.
param enablePrivateNetworking = false
