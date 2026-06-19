// Storage account + Blob service + a private container for lesson media/assets.
@description('Storage account name (3-24 chars, lowercase alphanumeric).')
param accountName string
param location string
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: accountName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storage
  name: 'default'
}

// Media is served via signed URLs / CDN later — keep the container private.
resource assets 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blob
  name: 'lesson-assets'
  properties: {
    publicAccess: 'None'
  }
}

output accountName string = storage.name
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
