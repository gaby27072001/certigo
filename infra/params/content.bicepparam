using '../content/main.bicep'

param location = 'westeurope'
param ciVnetResourceGroupName = 'rg-certigo-ci'
param ciVnetName = 'vnet-certigo-ci'
param ciRunnerSubnetName = 'snet-runners'
param contentIdentityResourceGroupName = 'rg-certigo-identities'
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
// MCAPS LRS accepted 2026-09-25: docs/migration/evidence/2026-09-25-content-lrs.json.
// WORM/versioning do not replace geo-redundancy during a regional loss.
param storageSkuName = 'Standard_LRS'
param contentPublisherRoleDefinitionGuid = 'c8a9d1bb-39d7-4f4f-9a4c-17b4c81aa5de'
