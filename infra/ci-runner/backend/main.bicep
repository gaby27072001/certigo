targetScope = 'subscription'

@description('Fail-closed switch. No resource group or runtime resource is created by default.')
param deploymentEnabled bool = false

@description('Runtime and image region. Zone support must be attested before activation.')
param location string

@description('Exact builder Azure Compute Gallery image version resource ID.')
@minLength(1)
param builderGalleryImageVersionId string

@description('Exact deployer Azure Compute Gallery image version resource ID.')
@minLength(1)
param deployerGalleryImageVersionId string

@description('SSH public key for the break-glass administrator. No private material may be stored in the repository.')
@secure()
@minLength(32)
param adminSshPublicKey string

var contract = loadJsonContent('backend-runner-contract.json')
var builder = contract.pools.builder
var deployer = contract.pools.deployer
var physicalIsolationReady = builder.runtimeResourceGroup != deployer.runtimeResourceGroup && builder.virtualMachineScaleSet != deployer.virtualMachineScaleSet && builder.virtualNetwork != deployer.virtualNetwork && builder.subnet != deployer.subnet && builder.networkSecurityGroup != deployer.networkSecurityGroup && builder.natGateway != deployer.natGateway && builder.natPublicIp != deployer.natPublicIp && builder.addressSpace != deployer.addressSpace && builder.zone != deployer.zone && !contract.physicalIsolation.networkPeeringAllowed && !contract.physicalIsolation.applicationRoutesAllowed
var capacityReady = builder.idleCapacity == 0 && builder.maximumCapacity == 1 && deployer.idleCapacity == 0 && deployer.maximumCapacity == 1 && !contract.controller.capacityEnabled
var identityReady = builder.managedIdentity == 'none' && deployer.managedIdentity == 'none' && !builder.azureCredentialsAllowed && !builder.azureOidcAllowed && !deployer.azureCredentialsAllowed && deployer.azureOidcAllowed
var routingReady = builder.label == 'certigo-backend-builder' && deployer.label == 'certigo-backend-deployer' && !contract.routing.fallbackAllowed && !contract.routing.dualLabelAllowed && !contract.routing.trustedFallbackAllowed
var imageBindingsReady = !empty(builder.attestedImageVersionResourceId) && !empty(deployer.attestedImageVersionResourceId) && toLower(builderGalleryImageVersionId) == toLower(builder.attestedImageVersionResourceId) && toLower(deployerGalleryImageVersionId) == toLower(deployer.attestedImageVersionResourceId) && toLower(builder.attestedImageVersionResourceId) != toLower(deployer.attestedImageVersionResourceId)
var activationReady = contract.activation.designReviewed && contract.activation.securityReviewApproved && contract.activation.artifactFlowIntegrated && contract.activation.githubEnvironmentApproved && contract.activation.coldWarmAttestationApproved
var mutationAuthorized = contract.mutationAuthorization.deploymentEnabled && contract.mutationAuthorization.azureMutationAuthorized && contract.mutationAuthorization.runnerMutationAuthorized && contract.mutationAuthorization.workflowMutationAuthorized
var effectiveDeploymentEnabled = deploymentEnabled && mutationAuthorized && activationReady && physicalIsolationReady && capacityReady && identityReady && routingReady && imageBindingsReady
var commonTags = {
  product: 'Certigo'
  workload: 'github-actions-backend-runner'
  lifecycle: 'ephemeral-one-job'
  managedBy: 'bicep'
  activationStatus: effectiveDeploymentEnabled ? 'enabled' : 'blocked'
}

resource builderRuntimeGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = if (effectiveDeploymentEnabled) {
  name: builder.runtimeResourceGroup
  location: location
  tags: union(commonTags, {
    runnerLabel: builder.label
    runnerRole: 'builder'
    trustBoundary: 'trusted-build-no-azure-identity'
  })
}

resource deployerRuntimeGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = if (effectiveDeploymentEnabled) {
  name: deployer.runtimeResourceGroup
  location: location
  tags: union(commonTags, {
    runnerLabel: deployer.label
    runnerRole: 'deployer'
    trustBoundary: 'artifact-only-azure-oidc'
  })
}

module builderPool 'pool.bicep' = if (effectiveDeploymentEnabled) {
  name: 'certigo-backend-builder-runtime'
  scope: builderRuntimeGroup
  params: {
    deploymentEnabled: true
    poolRole: 'builder'
    galleryImageVersionId: builderGalleryImageVersionId
    adminSshPublicKey: adminSshPublicKey
    location: location
    tags: union(commonTags, {
      runnerLabel: builder.label
      runnerRole: 'builder'
      trustBoundary: 'trusted-build-no-azure-identity'
    })
  }
}

module deployerPool 'pool.bicep' = if (effectiveDeploymentEnabled) {
  name: 'certigo-backend-deployer-runtime'
  scope: deployerRuntimeGroup
  params: {
    deploymentEnabled: true
    poolRole: 'deployer'
    galleryImageVersionId: deployerGalleryImageVersionId
    adminSshPublicKey: adminSshPublicKey
    location: location
    tags: union(commonTags, {
      runnerLabel: deployer.label
      runnerRole: 'deployer'
      trustBoundary: 'artifact-only-azure-oidc'
    })
  }
}

output deploymentEnabled bool = deploymentEnabled
output effectiveDeploymentEnabled bool = effectiveDeploymentEnabled
output activationReady bool = activationReady
output physicalIsolationReady bool = physicalIsolationReady
output capacityReady bool = capacityReady
output imageBindingsReady bool = imageBindingsReady
output builderRuntimeResourceGroupId string = subscriptionResourceId(
  'Microsoft.Resources/resourceGroups',
  builder.runtimeResourceGroup
)
output deployerRuntimeResourceGroupId string = subscriptionResourceId(
  'Microsoft.Resources/resourceGroups',
  deployer.runtimeResourceGroup
)
output builderRunnerLabel string = builder.label
output deployerRunnerLabel string = deployer.label
