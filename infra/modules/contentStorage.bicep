@description('Dedicated immutable content storage account name.')
param accountName string

param location string
param tags object = {}

@description('Optional publisher service-principal object id. Empty leaves publication RBAC to the content pipeline deployment.')
param contentPublisherPrincipalId string = ''

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: accountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_GRS'
  }
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
    isVersioningEnabled: true
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource descriptors 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blob
  name: 'content-release-descriptors'
  properties: {
    publicAccess: 'None'
    immutableStorageWithVersioning: {
      enabled: true
    }
  }
}

resource publicReleases 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blob
  name: 'content-public-releases'
  properties: {
    publicAccess: 'None'
    immutableStorageWithVersioning: {
      enabled: true
    }
  }
}

resource privateReleases 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blob
  name: 'content-private-releases'
  properties: {
    publicAccess: 'None'
    immutableStorageWithVersioning: {
      enabled: true
    }
  }
}

var storageBlobDataOwner = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
)

resource publisherDescriptorAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(contentPublisherPrincipalId)) {
  scope: descriptors
  name: guid(descriptors.id, contentPublisherPrincipalId, storageBlobDataOwner)
  properties: {
    principalId: contentPublisherPrincipalId
    roleDefinitionId: storageBlobDataOwner
    principalType: 'ServicePrincipal'
  }
}

resource publisherPublicAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(contentPublisherPrincipalId)) {
  scope: publicReleases
  name: guid(publicReleases.id, contentPublisherPrincipalId, storageBlobDataOwner)
  properties: {
    principalId: contentPublisherPrincipalId
    roleDefinitionId: storageBlobDataOwner
    principalType: 'ServicePrincipal'
  }
}

resource publisherPrivateAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(contentPublisherPrincipalId)) {
  scope: privateReleases
  name: guid(privateReleases.id, contentPublisherPrincipalId, storageBlobDataOwner)
  properties: {
    principalId: contentPublisherPrincipalId
    roleDefinitionId: storageBlobDataOwner
    principalType: 'ServicePrincipal'
  }
}

output accountName string = storage.name
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
output descriptorContainerName string = descriptors.name
output publicContainerName string = publicReleases.name
output privateContainerName string = privateReleases.name
