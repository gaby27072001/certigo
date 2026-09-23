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

@description('Point-in-time restore retention in days. Requires versioning and strictly longer blob soft-delete retention.')
@minValue(1)
@maxValue(365)
param blobRestoreDays int

@description('Object id of the GitHub Actions OIDC service principal that uploads immutable deployment packages.')
param ciDeploymentPrincipalId string

var effectiveRestoreDays = enableVersioning && blobSoftDeleteDays > blobRestoreDays
  ? blobRestoreDays
  : fail('Blob point-in-time restore requires versioning and blobSoftDeleteDays greater than blobRestoreDays.')

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
    changeFeed: { enabled: true }
    restorePolicy: { enabled: true, days: effectiveRestoreDays }
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

resource deploymentRetention 'Microsoft.Storage/storageAccounts/managementPolicies@2024-01-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'delete-expired-deployment-packages'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 30
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'app-package/deployments/'
              ]
            }
          }
        }
        {
          enabled: true
          name: 'delete-expired-release-bundles'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 90
                }
              }
              version: {
                delete: {
                  daysAfterCreationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                'app-package/releases/'
              ]
            }
          }
        }
      ]
    }
  }
}

var storageBlobDataContributor = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
)

var storageBlobDelegator = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'db58b8e5-c6ad-4a2a-8342-4190687cbf4a'
)

resource ciDeploymentBlobAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appPackage
  name: guid(appPackage.id, ciDeploymentPrincipalId, storageBlobDataContributor)
  properties: {
    principalId: ciDeploymentPrincipalId
    roleDefinitionId: storageBlobDataContributor
    principalType: 'ServicePrincipal'
  }
}

resource ciDeploymentDelegationAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(storage.id, ciDeploymentPrincipalId, storageBlobDelegator)
  properties: {
    principalId: ciDeploymentPrincipalId
    roleDefinitionId: storageBlobDelegator
    principalType: 'ServicePrincipal'
  }
}

output accountName string = storage.name
output deploymentContainerName string = appPackage.name
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
