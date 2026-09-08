targetScope = 'resourceGroup'

@description('Azure region for the dedicated content resources.')
param location string = 'westeurope'

@description('Existing resource group that contains the trusted CI runner VNet and shared private DNS zones.')
param ciVnetResourceGroupName string = 'rg-certigo-ci'

@description('Existing resource group that owns the content publisher and reader user-assigned identities.')
param contentIdentityResourceGroupName string = 'rg-certigo-identities'

@description('Existing trusted CI runner virtual network.')
param ciVnetName string = 'vnet-certigo-ci'

@description('Existing runner subnet. It already has private endpoint network policies disabled.')
param ciRunnerSubnetName string = 'snet-runners'

@description('Container for certigo.content.release/v1 descriptors.')
param descriptorContainerName string = 'content-release-descriptors'

@description('Container for public package manifests and files.')
param publicContainerName string = 'content-public-releases'

@description('Container for private answer-key package manifests and files.')
param privateContainerName string = 'content-private-releases'

@description('Unlocked WORM retention baseline for release descriptors. Review before the separate irreversible lock operation.')
@minValue(1)
param descriptorImmutabilityRetentionDays int

@description('Unlocked WORM retention baseline for public content. Review before the separate irreversible lock operation.')
@minValue(1)
param publicImmutabilityRetentionDays int

@description('Unlocked WORM retention baseline for private content. Review before the separate irreversible lock operation.')
@minValue(1)
param privateImmutabilityRetentionDays int

@description('Move immutable block blobs to the cool tier after this many days. No lifecycle deletion is configured.')
@minValue(1)
param coolTierAfterDays int

@description('Blob and container soft-delete retention in days.')
@minValue(1)
@maxValue(365)
param softDeleteRetentionDays int = 30

@description('Storage SKU for the shared content endpoint consumed by the runtime importer.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
])
param storageSkuName string = 'Standard_GRS'

@description('Existing subscription custom role created by the governance bootstrap.')
param contentPublisherRoleDefinitionGuid string = 'c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de'

var suffix = take(uniqueString(subscription().id, resourceGroup().id), 8)
var storageAccountName = 'stcertigocnt${suffix}'
var descriptorEnvironmentName = 'azure-content-release'
var publicEnvironmentName = 'azure-content-public'
var privateEnvironmentName = 'azure-content-answer-key'
var descriptorPublisherIdentityName = 'id-certigo-content-release'
var publicPublisherIdentityName = 'id-certigo-content-public'
var privatePublisherIdentityName = 'id-certigo-content-answer-key'
var readerIdentityName = 'id-certigo-content-reader'
var storageBlobDataReaderRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
)
var tags = {
  product: 'Certigo'
  workload: 'immutable-content'
  managedBy: 'bicep'
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  scope: resourceGroup(ciVnetResourceGroupName)
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.blob.core.windows.net'
}

var ciRunnerSubnetId = resourceId(
  subscription().subscriptionId,
  ciVnetResourceGroupName,
  'Microsoft.Network/virtualNetworks/subnets',
  ciVnetName,
  ciRunnerSubnetName
)

resource contentPublisherRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: contentPublisherRoleDefinitionGuid
}

resource descriptorPublisherIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  scope: resourceGroup(contentIdentityResourceGroupName)
  name: descriptorPublisherIdentityName
}

resource publicPublisherIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  scope: resourceGroup(contentIdentityResourceGroupName)
  name: publicPublisherIdentityName
}

resource privatePublisherIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  scope: resourceGroup(contentIdentityResourceGroupName)
  name: privatePublisherIdentityName
}

resource contentReaderIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  scope: resourceGroup(contentIdentityResourceGroupName)
  name: readerIdentityName
}

module contentStorage '../modules/contentStorage.bicep' = {
  name: 'content-storage'
  params: {
    accountName: storageAccountName
    coolTierAfterDays: coolTierAfterDays
    descriptorContainerName: descriptorContainerName
    descriptorImmutabilityRetentionDays: descriptorImmutabilityRetentionDays
    descriptorPublisherIdentityResourceId: descriptorPublisherIdentity.id
    descriptorPublisherPrincipalId: descriptorPublisherIdentity.properties.principalId
    location: location
    privateContainerName: privateContainerName
    privateImmutabilityRetentionDays: privateImmutabilityRetentionDays
    privatePublisherIdentityResourceId: privatePublisherIdentity.id
    privatePublisherPrincipalId: privatePublisherIdentity.properties.principalId
    publicContainerName: publicContainerName
    publicImmutabilityRetentionDays: publicImmutabilityRetentionDays
    publicPublisherIdentityResourceId: publicPublisherIdentity.id
    publicPublisherPrincipalId: publicPublisherIdentity.properties.principalId
    publisherRoleDefinitionId: contentPublisherRole.id
    readerIdentityResourceId: contentReaderIdentity.id
    readerPrincipalId: contentReaderIdentity.properties.principalId
    readerRoleDefinitionId: storageBlobDataReaderRoleDefinitionId
    skuName: storageSkuName
    softDeleteRetentionDays: softDeleteRetentionDays
    tags: tags
  }
}

module privateEndpoint '../modules/contentPrivateEndpoints.bicep' = {
  name: 'content-private-endpoint'
  params: {
    blobPrivateDnsZoneId: blobPrivateDnsZone.id
    ciRunnerSubnetId: ciRunnerSubnetId
    location: location
    storageAccountId: contentStorage.outputs.accountId
    storageAccountName: contentStorage.outputs.accountName
    tags: tags
  }
}

output azureTenantId string = tenant().tenantId
output azureSubscriptionId string = subscription().subscriptionId
output azureResourceGroup string = resourceGroup().name
output azureStorageAccount string = contentStorage.outputs.accountName
output azureBlobEndpoint string = contentStorage.outputs.primaryBlobEndpoint
output azureDescriptorContainer string = contentStorage.outputs.descriptorContainerName
output azurePublicContainer string = contentStorage.outputs.publicContainerName
output azurePrivateContainer string = contentStorage.outputs.privateContainerName
output azureDescriptorStorageTarget string = '${contentStorage.outputs.accountName}/${contentStorage.outputs.descriptorContainerName}'
output azurePublicStorageTarget string = '${contentStorage.outputs.accountName}/${contentStorage.outputs.publicContainerName}'
output azurePrivateStorageTarget string = '${contentStorage.outputs.accountName}/${contentStorage.outputs.privateContainerName}'
output azureDescriptorPublisherClientId string = descriptorPublisherIdentity.properties.clientId
output azurePublicPublisherClientId string = publicPublisherIdentity.properties.clientId
output azurePrivatePublisherClientId string = privatePublisherIdentity.properties.clientId
output azureContentReaderClientId string = contentReaderIdentity.properties.clientId
output azureContentReaderPrincipalId string = contentReaderIdentity.properties.principalId
output azureContentReaderResourceId string = contentReaderIdentity.id
output azureDescriptorEnvironment string = descriptorEnvironmentName
output azurePublicEnvironment string = publicEnvironmentName
output azurePrivateEnvironment string = privateEnvironmentName
output descriptorImmutabilityPolicyId string = contentStorage.outputs.descriptorImmutabilityPolicyId
output publicImmutabilityPolicyId string = contentStorage.outputs.publicImmutabilityPolicyId
output privateImmutabilityPolicyId string = contentStorage.outputs.privateImmutabilityPolicyId
output contentPrivateEndpointId string = privateEndpoint.outputs.privateEndpointId
output contentRepositoryModeDefault string = 'legacy'
output contentAllowMutableBlobsDefault string = 'false'
