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

// Cosmos DB deployed in northeurope — westeurope has AZ-capacity limits.
param cosmosLocation = 'northeurope'

// Microsoft Entra External ID (CIAM) — fill from your tenant.
param authIssuer = 'https://microlingo.ciamlogin.com/00000000-0000-0000-0000-000000000000/v2.0'
param authAudience = '00000000-0000-0000-0000-000000000000'
