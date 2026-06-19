// Dev environment parameters. Authority/audience point to the Microlingo
// Entra External ID app registration (replace placeholders before deploying).
//
// Deploy:
//   az deployment sub create \
//     --location westeurope \
//     --template-file infra/main.bicep \
//     --parameters infra/params/dev.bicepparam
using '../main.bicep'

param env = 'dev'
param location = 'westeurope'
param appName = 'microlingo'

// Microsoft Entra External ID (CIAM) — fill from your tenant.
param authIssuer = 'https://microlingo.ciamlogin.com/<tenant-guid>/v2.0'
param authAudience = '<api-client-id>'
