// Storage account + Blob service + a private container for lesson media/assets.
@description('Storage account name (3-24 chars, lowercase alphanumeric).')
param accountName string
param location string
param tags object = {}

@description('Storage SKU. Use a geo-redundant SKU (Standard_GRS/GZRS) for prod durability; Standard_LRS for dev.')
param skuName string = 'Standard_LRS'

@description('Blob soft-delete retention in days (0 disables).')
param blobSoftDeleteDays int = 7

@description('Container soft-delete retention in days (0 disables).')
param containerSoftDeleteDays int = 7

@description('Enable blob versioning (recommended for prod).')
param enableVersioning bool = false

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: accountName
  location: location
  tags: tags
  sku: { name: skuName }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: enableVersioning
    deleteRetentionPolicy: blobSoftDeleteDays > 0 ? { enabled: true, days: blobSoftDeleteDays } : { enabled: false }
    containerDeleteRetentionPolicy: containerSoftDeleteDays > 0 ? { enabled: true, days: containerSoftDeleteDays } : { enabled: false }
  }
}

// Media is served via signed URLs / CDN later — keep the container private.
resource assets 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blob
  name: 'lesson-assets'
  properties: {
    publicAccess: 'None'
  }
}

// Deployment package container for the Flex Consumption Function App. The app's
// managed identity reads its zip from here (identity-based, no shared key).
resource appPackage 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blob
  name: 'app-package'
  properties: {
    publicAccess: 'None'
  }
}

output accountName string = storage.name
output deploymentContainerName string = appPackage.name
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
