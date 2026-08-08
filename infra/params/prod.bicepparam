// Production environment parameters. Hardening is on automatically for any non-dev
// env (Cosmos RBAC-only auth, Key Vault purge protection + 90-day soft delete,
// geo-redundant + versioned storage, CORS locked to []).
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
param networkAccessMode = 'public-rbac'

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
// mints an access_token whose aud = api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915; the
// backend validates it against this value. This is the BACKEND app registration
// client id (12910b8e-...), NOT the mobile client id (4d1f1075-...), both in the
// same tenant (af721be8-...).
param entraAudience = 'api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915'

// On-call email notified on 401/403/5xx spikes (diagnostics module deploys for
// every non-dev env). Verify this is a real, monitored inbox before go-live.
param alertEmail = 'secops@certigo.app'

// Turn on paid Microsoft Defender for Cloud plans in production.
param enableDefenderPlans = true
param manageDefenderPlans = true

// Production PITR is explicit. Changing an existing Periodic account is irreversible.
param cosmosBackupMode = 'Continuous'
param cosmosContinuousBackupTier = 'Continuous7Days'

// MCSB remains audit-only until remediation identities and exemptions are reviewed.
param deployMcsbPolicyAssignment = true
param mcsbEnforcementMode = 'DoNotEnforce'
param grantAlertReaderRole = true

// AI tutor (Azure OpenAI / Foundry): left DISABLED in prod (main.bicep default is
// false). No prod Azure OpenAI resource is provisioned (dev uses "certigo-openai"
// scoped to the certigo-dev project), so enabling it here without a prod endpoint
// would break the tutor feature. This does NOT block deployment — the backend
// falls back to the deterministic grounded tutor. Provide tutorLlmEnabled = true
// + tutorLlmEndpoint/tutorLlmDeployment when a prod OpenAI resource exists.

// Email/password JWT signing key: intentionally NOT set here. Supply
// authJwtSigningKey out-of-band as a secure deployment parameter. main.bicep rejects
// production deployments when it is omitted; never commit its value in this file.

// ============================================================================
// public-rbac is the only accepted network mode. A private mode is intentionally
// unavailable until VNet integration, private endpoints and private DNS ship together.
// ============================================================================
