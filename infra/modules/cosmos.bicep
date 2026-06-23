// Cosmos DB (Core/SQL API, serverless) + database + the Microlingo
// containers with their locked partition keys.
@description('Cosmos DB account name (globally unique).')
param accountName string
param location string
param databaseName string
param tags object = {}

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
    disableLocalAuth: false
    minimalTlsVersion: 'Tls12'
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
  { name: 'progress', pk: '/userId' }
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
      resource: {
        id: c.name
        partitionKey: {
          paths: [ c.pk ]
          kind: 'Hash'
          version: 2
        }
        indexingPolicy: {
          indexingMode: 'consistent'
          automatic: true
        }
      }
    }
  }
]

output endpoint string = account.properties.documentEndpoint
output accountName string = account.name
