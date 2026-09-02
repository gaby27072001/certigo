targetScope = 'resourceGroup'

@description('Storage account name (3-24 lowercase alphanumeric characters).')
param accountName string
param location string
param descriptorContainerName string
param publicContainerName string
param privateContainerName string
param descriptorPublisherIdentityResourceId string
param descriptorPublisherPrincipalId string
param publicPublisherIdentityResourceId string
param publicPublisherPrincipalId string
param privatePublisherIdentityResourceId string
param privatePublisherPrincipalId string
param readerIdentityResourceId string
param readerPrincipalId string
param publisherRoleDefinitionId string
param readerRoleDefinitionId string
param descriptorImmutabilityRetentionDays int
param publicImmutabilityRetentionDays int
param privateImmutabilityRetentionDays int
param coolTierAfterDays int
param softDeleteRetentionDays int
param skuName string = 'Standard_GRS'
param tags object = {}

resource storage 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: accountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: skuName
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    isHnsEnabled: false
    isLocalUserEnabled: false
    isNfsV3Enabled: false
    isSftpEnabled: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: true
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    routingPreference: {
      publishInternetEndpoints: false
      publishMicrosoftEndpoints: false
      routingChoice: 'MicrosoftRouting'
    }
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  parent: storage
  name: 'default'
  properties: {
    changeFeed: {
      enabled: false
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: softDeleteRetentionDays
    }
    deleteRetentionPolicy: {
      enabled: true
      days: softDeleteRetentionDays
    }
    isVersioningEnabled: true
    restorePolicy: {
      enabled: false
    }
  }
}

resource descriptorContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: descriptorContainerName
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: true
    immutableStorageWithVersioning: {
      enabled: true
    }
    publicAccess: 'None'
  }
}

resource publicContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: publicContainerName
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: true
    immutableStorageWithVersioning: {
      enabled: true
    }
    publicAccess: 'None'
  }
}

resource privateContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobService
  name: privateContainerName
  properties: {
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: true
    immutableStorageWithVersioning: {
      enabled: true
    }
    publicAccess: 'None'
  }
}

// ARM creates these policies unlocked. Locking is a separate irreversible
// operator action after staging rollback evidence and retention approval.
resource descriptorImmutabilityPolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2025-06-01' = {
  parent: descriptorContainer
  name: 'default'
  properties: {
    allowProtectedAppendWrites: false
    allowProtectedAppendWritesAll: false
    immutabilityPeriodSinceCreationInDays: descriptorImmutabilityRetentionDays
  }
}

resource publicImmutabilityPolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2025-06-01' = {
  parent: publicContainer
  name: 'default'
  properties: {
    allowProtectedAppendWrites: false
    allowProtectedAppendWritesAll: false
    immutabilityPeriodSinceCreationInDays: publicImmutabilityRetentionDays
  }
}

resource privateImmutabilityPolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2025-06-01' = {
  parent: privateContainer
  name: 'default'
  properties: {
    allowProtectedAppendWrites: false
    allowProtectedAppendWritesAll: false
    immutabilityPeriodSinceCreationInDays: privateImmutabilityRetentionDays
  }
}

resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2025-06-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'tier-content-manifests-to-cool'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterCreationGreaterThan: coolTierAfterDays
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                '${publicContainerName}/manifests/'
                '${privateContainerName}/manifests/'
              ]
            }
          }
        }
        {
          enabled: true
          name: 'tier-release-descriptors-to-cool'
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterCreationGreaterThan: coolTierAfterDays
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                '${descriptorContainerName}/releases/'
              ]
            }
          }
        }
      ]
    }
  }
}

resource descriptorPublisherAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: descriptorContainer
  name: guid(descriptorContainer.id, descriptorPublisherIdentityResourceId, publisherRoleDefinitionId)
  properties: {
    principalId: descriptorPublisherPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: publisherRoleDefinitionId
  }
}

resource publicPublisherAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: publicContainer
  name: guid(publicContainer.id, publicPublisherIdentityResourceId, publisherRoleDefinitionId)
  properties: {
    principalId: publicPublisherPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: publisherRoleDefinitionId
  }
}

resource privatePublisherAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: privateContainer
  name: guid(privateContainer.id, privatePublisherIdentityResourceId, publisherRoleDefinitionId)
  properties: {
    principalId: privatePublisherPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: publisherRoleDefinitionId
  }
}

resource descriptorReaderAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: descriptorContainer
  name: guid(descriptorContainer.id, readerIdentityResourceId, readerRoleDefinitionId)
  properties: {
    principalId: readerPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: readerRoleDefinitionId
  }
}

resource publicReaderAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: publicContainer
  name: guid(publicContainer.id, readerIdentityResourceId, readerRoleDefinitionId)
  properties: {
    principalId: readerPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: readerRoleDefinitionId
  }
}

resource privateReaderAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: privateContainer
  name: guid(privateContainer.id, readerIdentityResourceId, readerRoleDefinitionId)
  properties: {
    principalId: readerPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: readerRoleDefinitionId
  }
}

output accountId string = storage.id
output accountName string = storage.name
output descriptorContainerId string = descriptorContainer.id
output descriptorContainerName string = descriptorContainer.name
output descriptorImmutabilityPolicyId string = descriptorImmutabilityPolicy.id
output primaryBlobEndpoint string = storage.properties.primaryEndpoints.blob
output privateContainerId string = privateContainer.id
output privateContainerName string = privateContainer.name
output privateImmutabilityPolicyId string = privateImmutabilityPolicy.id
output publicContainerId string = publicContainer.id
output publicContainerName string = publicContainer.name
output publicImmutabilityPolicyId string = publicImmutabilityPolicy.id
