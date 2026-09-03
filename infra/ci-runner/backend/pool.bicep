targetScope = 'resourceGroup'

@description('Fail-closed switch inherited from the backend subscription entry point.')
param deploymentEnabled bool = false

@allowed([
  'builder'
  'deployer'
])
@description('Backend runner role.')
param poolRole string

@description('Exact Azure Compute Gallery image version resource ID.')
@minLength(1)
param galleryImageVersionId string

@description('SSH public key for the break-glass administrator.')
@secure()
@minLength(32)
param adminSshPublicKey string

@description('Runtime region.')
param location string = resourceGroup().location

@description('Tags applied only to this isolated backend runtime pool.')
param tags object = {}

var contract = loadJsonContent('backend-runner-contract.json')
var pool = contract.pools[poolRole]
var activationReady = contract.activation.designReviewed && contract.activation.securityReviewApproved && contract.activation.artifactFlowIntegrated && contract.activation.githubEnvironmentApproved && contract.activation.coldWarmAttestationApproved
var mutationAuthorized = contract.mutationAuthorization.deploymentEnabled && contract.mutationAuthorization.azureMutationAuthorized && contract.mutationAuthorization.runnerMutationAuthorized && contract.mutationAuthorization.workflowMutationAuthorized
var routeReady = !contract.routing.fallbackAllowed && !contract.routing.dualLabelAllowed && !contract.routing.defaultLabelsAllowed && !contract.routing.trustedFallbackAllowed
var effectiveDeploymentEnabled = deploymentEnabled && mutationAuthorized && activationReady && routeReady
var poolProfile = {
  roleName: 'backend-${poolRole}'
  runnerLabel: pool.label
  computerNamePrefix: poolRole == 'builder' ? 'certigo-bld' : 'certigo-dpl'
  imageDefinitionName: pool.imageDefinitionName
  virtualMachineScaleSet: pool.virtualMachineScaleSet
  virtualNetwork: pool.virtualNetwork
  subnet: pool.subnet
  networkSecurityGroup: pool.networkSecurityGroup
  natGateway: pool.natGateway
  natPublicIp: pool.natPublicIp
  addressSpace: pool.addressSpace
  subnetPrefix: pool.subnetPrefix
  zone: pool.zone
  idleCapacity: pool.idleCapacity
  maximumCapacity: pool.maximumCapacity
  managedIdentity: pool.managedIdentity
  imdsOsBlockRequired: pool.imdsOsBlockRequired
  imdsNsgBlockRequired: pool.imdsNsgBlockRequired
  networkPeeringAllowed: contract.physicalIsolation.networkPeeringAllowed
  applicationRoutesAllowed: contract.physicalIsolation.applicationRoutesAllowed
  registrationMode: contract.lifecycle.registrationMode
  runnerEphemeralFlagRequired: contract.lifecycle.runnerEphemeralFlagRequired
  oneJobGuardRequired: contract.lifecycle.oneJobGuardRequired
  retireAfterJobRequired: contract.lifecycle.retireAfterJobRequired
  deleteOrReimageAfterJobRequired: contract.lifecycle.deleteOrReimageAfterJobRequired
}

module isolatedPool '../modules/isolated-ephemeral-pool.bicep' = {
  name: 'certigo-isolated-backend-${poolRole}'
  params: {
    deploymentEnabled: effectiveDeploymentEnabled
    activationReady: activationReady
    poolProfile: poolProfile
    galleryImageVersionId: galleryImageVersionId
    attestedGalleryImageVersionId: pool.attestedImageVersionResourceId
    imageValidatorPath: '/usr/local/sbin/certigo-validate-backend-image'
    imageValidationProfile: poolRole
    adminSshPublicKey: adminSshPublicKey
    location: location
    tags: tags
  }
}

output deploymentEnabled bool = deploymentEnabled
output effectiveDeploymentEnabled bool = isolatedPool.outputs.effectiveDeploymentEnabled
output activationReady bool = activationReady
output runnerLabel string = isolatedPool.outputs.runnerLabel
output runnerScaleSetId string = isolatedPool.outputs.runnerScaleSetId
output runtimeCapacity int = isolatedPool.outputs.runtimeCapacity
output maximumCapacity int = isolatedPool.outputs.maximumCapacity
output managedIdentity string = isolatedPool.outputs.managedIdentity
