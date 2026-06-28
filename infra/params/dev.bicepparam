// Dev environment parameters.
//
// NOTE on Entra placeholders: in dev, main.bicep sets authMode='dev', so the API uses
// DevTokenValidator and Entra External ID is NOT enforced. The entraAuthority/entraAudience
// placeholders below are therefore safe to deploy as-is for dev. Provide real CIAM values
// for staging/prod (where authMode='prod' and EntraTokenValidator is active).
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

// Microsoft Entra External ID (CIAM) — placeholders, unused in dev (see note above).
// Replace with real tenant values for staging/prod.
param entraAuthority = 'https://microlingo.ciamlogin.com/00000000-0000-0000-0000-000000000000/v2.0'
param entraAudience = '00000000-0000-0000-0000-000000000000'