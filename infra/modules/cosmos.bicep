// Cosmos DB (Core/SQL API, serverless) + database + the Certigo
// containers with their locked partition keys.
@description('Cosmos DB account name (globally unique).')
param accountName string
param location string
param databaseName string
param tags object = {}

@description('Disable Cosmos key-based (local) auth — RBAC/Entra only. Recommended for staging/prod; the API and seed use managed identity.')
param disableLocalAuth bool = false

@description('Explicit backup mode. Switching an existing account from Periodic to Continuous is irreversible.')
@allowed([ 'Periodic', 'Continuous' ])
param backupMode string

@description('Continuous backup retention tier.')
@allowed([ 'Continuous7Days', 'Continuous30Days' ])
param continuousBackupTier string = 'Continuous7Days'

@description('Periodic backup interval in minutes.')
@minValue(60)
@maxValue(1440)
param periodicBackupIntervalMinutes int = 240

@description('Periodic backup retention in hours.')
@minValue(8)
@maxValue(720)
param periodicBackupRetentionHours int = 8

@description('Periodic backup storage redundancy.')
@allowed([ 'Local', 'Geo', 'Zone' ])
param periodicBackupStorageRedundancy string = 'Geo'

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: accountName
  location: location
  tags: tags
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    // Serverless: pay-per-request — ideal for an early-stage learning app.
    capabilities: [ { name: 'EnableServerless' } ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        // Dev: no Availability-Zone redundancy (avoids AZ-capacity blocks and
        // is unnecessary for a single-region serverless dev account).
        isZoneRedundant: false
      }
    ]
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: 'Disabled'
    minimalTlsVersion: 'Tls12'
    backupPolicy: backupMode == 'Continuous' ? {
      type: 'Continuous'
      continuousModeProperties: {
        tier: continuousBackupTier
      }
    } : {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: periodicBackupIntervalMinutes
        backupRetentionIntervalInHours: periodicBackupRetentionHours
        backupStorageRedundancy: periodicBackupStorageRedundancy
      }
    }
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-11-15' = {
  parent: account
  name: databaseName
  properties: {
    resource: { id: databaseName }
  }
}

// Locked container topology: name -> partition key.
var containers = [
  { name: 'users', pk: '/id' }
  { name: 'content', pk: '/trackId' }
  { name: 'content-public', pk: '/releaseId' }
  { name: 'content-private', pk: '/releaseId' }
  { name: 'content-control', pk: '/scope' }
  { name: 'progress', pk: '/userId' }
  // Existing attempts remain durable because their documents omit "ttl"; issued
  // exam documents opt in with a positive per-item TTL.
  { name: 'attempts', pk: '/userId' }
  { name: 'events', pk: '/userId' }
  { name: 'leaderboard', pk: '/periodLeagueId' }
  { name: 'economy', pk: '/userId' }
  { name: 'friends', pk: '/userId' }
]

resource containerResources 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-11-15' = [
  for c in containers: {
    parent: database
    name: c.name
    properties: {
      resource: union(
        {
          id: c.name
          partitionKey: {
            paths: [ c.pk ]
            kind: 'Hash'
            version: 2
          }
          indexingPolicy: {
            indexingMode: 'consistent'
            automatic: true
            includedPaths: [
              {
                path: '/*'
              }
            ]
            excludedPaths: [
              {
                path: '/"_etag"/?'
              }
            ]
          }
        },
        c.name == 'attempts' ? { defaultTtl: -1 } : {}
      )
    }
  }
]

output endpoint string = account.properties.documentEndpoint
output accountName string = account.name
output backupMode string = backupMode
