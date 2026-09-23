targetScope = 'subscription'

@description('Fail-closed switch. No runtime resource group or canary resource is created by default.')
param deploymentEnabled bool = false

@description('Deployment and canary region.')
param location string

@description('Exact candidate Azure Compute Gallery image version resource ID.')
param galleryImageVersionId string

@description('Exact previous Azure Compute Gallery image version resource ID.')
param previousGalleryImageVersionId string

@description('SSH public key for the isolated canary break-glass account.')
@secure()
param adminSshPublicKey string

@description('Canary expiry timestamp used by the mandatory cleanup guard.')
param expiresOn string

var contract = loadJsonContent('canary-contract.json')
// Hashes cannot authorize the legacy network installer. Removal requires #341 execution proofs.
var networkInstallerImplemented = false
var buildContract = loadJsonContent('image-build-contract.json')
var attestationPolicy = loadJsonContent('attestation-policy.json')
var aptInputsReady = !empty(buildContract.reproducibility.aptSnapshot) && length(string(buildContract.reproducibility.aptPackageLockSha256)) == 64
var flutterInputsReady = length(string(buildContract.reproducibility.flutterEngineArtifactLockSha256)) == 64
var reproducibleInputsReady = buildContract.policy.reproducibleInputsReady && buildContract.reproducibility.status == 'locked' && aptInputsReady && flutterInputsReady
var signerReady = attestationPolicy.activation.status == 'active'
var effectiveDeploymentEnabled = deploymentEnabled && reproducibleInputsReady && signerReady && networkInstallerImplemented
var runtimeTags = {
  product: 'Certigo'
  workload: 'github-actions-runner'
  trustBoundary: 'untrusted-pr'
  lifecycle: 'image-canary'
  managedBy: 'bicep'
  expiresOn: expiresOn
}

resource runtimeGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = if (effectiveDeploymentEnabled) {
  name: contract.resourceGroups.runtime
  location: location
  tags: runtimeTags
}

module canary 'canary.bicep' = if (effectiveDeploymentEnabled) {
  name: 'certigo-runner-image-canary'
  scope: runtimeGroup
  params: {
    deploymentEnabled: true
    galleryImageVersionId: galleryImageVersionId
    previousGalleryImageVersionId: previousGalleryImageVersionId
    adminSshPublicKey: adminSshPublicKey
    location: location
    expiresOn: expiresOn
    tags: runtimeTags
  }
}

output deploymentEnabled bool = deploymentEnabled
output effectiveDeploymentEnabled bool = effectiveDeploymentEnabled
output runtimeResourceGroupId string = subscriptionResourceId(
  'Microsoft.Resources/resourceGroups',
  contract.resourceGroups.runtime
)
output runnerScaleSetId string = '${subscription().id}/resourceGroups/${contract.resourceGroups.runtime}/providers/Microsoft.Compute/virtualMachineScaleSets/${contract.resources.scaleSet}'
