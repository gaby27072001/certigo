using '../content/main.bicep'

param location = 'westeurope'
param contentResourceGroupName = 'rg-certigo-content'
param ciVnetResourceGroupName = 'rg-certigo-ci'
param ciVnetName = 'vnet-certigo-ci'
param ciRunnerSubnetName = 'snet-runners'
param githubRepositoryOwner = 'gchambaud_microsoft'
param githubRepositoryName = 'certigo-content'
param descriptorContainerName = 'content-release-descriptors'
param publicContainerName = 'content-public-releases'
param privateContainerName = 'content-private-releases'

// Planning baselines only. OPS/compliance must approve these values before the
// separate irreversible policy-lock operation.
param descriptorImmutabilityRetentionDays = 90
param publicImmutabilityRetentionDays = 30
param privateImmutabilityRetentionDays = 90
param coolTierAfterDays = 30
param softDeleteRetentionDays = 30
param storageSkuName = 'Standard_GRS'
