// Production environment parameters. Hardening is on automatically for any non-dev
// env (Cosmos RBAC-only auth, Key Vault purge protection + 90-day soft delete,
// geo-redundant + versioned storage, CORS locked to []). Fill the Entra values
// from your production app registration and set an on-call alert email.
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

// Microsoft Entra External ID (CIAM) — production tenant/app.
param entraAuthority = 'https://certigo.ciamlogin.com/<tenant-guid>/v2.0'
param entraAudience = 'api://<api-client-id>'

// On-call email notified on 401/403/5xx spikes.
param alertEmail = 'secops@certigo.app'

// Turn on paid Microsoft Defender for Cloud plans in production.
param enableDefenderPlans = true
