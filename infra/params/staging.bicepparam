// Staging environment parameters. Mirrors prod hardening (Cosmos RBAC-only,
// Key Vault purge protection, geo-redundant storage, locked CORS) but is a safe
// pre-production target. Fill the Entra values from your staging app registration.
//
// Deploy:
//   az deployment sub create \
//     --location westeurope \
//     --template-file infra/main.bicep \
//     --parameters infra/params/staging.bicepparam
using '../main.bicep'

param env = 'staging'
param location = 'westeurope'
param appName = 'microlingo'

// Microsoft Entra External ID (CIAM) — staging tenant/app.
param entraAuthority = 'https://microlingo.ciamlogin.com/<tenant-guid>/v2.0'
param entraAudience = '<api-client-id>'

// Email notified on 401/403/5xx spikes (optional but recommended pre-prod).
param alertEmail = ''

// Paid Defender plans off by default; enable when budget is approved.
param enableDefenderPlans = false
