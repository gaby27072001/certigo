targetScope = 'resourceGroup'

@description('Fail-closed switch. No image resource is created or run by default.')
param deploymentEnabled bool = false

@description('Dedicated Azure VM Image Builder identity. It is build-plane only and is never assigned to a runner VMSS.')
@minLength(1)
param imageBuilderIdentityResourceId string

@description('Dedicated staging resource group ID used only by Azure VM Image Builder.')
@minLength(1)
param stagingResourceGroupId string

@description('Image build and gallery region.')
param location string = resourceGroup().location

@description('Tags applied only to backend runner image resources.')
param tags object = {
  product: 'Certigo'
  workload: 'github-actions-backend-runner-image'
  lifecycle: 'review-required'
  managedBy: 'bicep'
}

var contract = loadJsonContent('backend-image-build-contract.json')
var inputRoot = '/var/tmp/certigo-backend-image-input'
var scriptsLocked = length(items(contract.scripts)) == 6 && length(filter(items(contract.scripts), script => length(string(script.value.sha256)) != 64)) == 0
var reproducibilityReady = contract.status == 'locked-activation-blocked' && contract.policy.reproducibleInputsReady && !contract.policy.packageManagerMutationAllowed && !contract.policy.flutterInstalled && !contract.policy.imageTemplateAutoRunEnabled && !contract.policy.imageBuildExecutionAuthorized && scriptsLocked && length(string(contract.directArtifacts.actionsRunner.sha256)) == 64 && length(string(contract.directArtifacts.node.sha256)) == 64 && length(string(contract.directArtifacts.dotnetSdk.sha512)) == 128 && length(string(contract.directArtifacts.githubCli.sha256)) == 64 && contract.repositoryLocks.restoreLockedModeRequired
var activationReady = contract.activation.designReviewed && contract.activation.securityReviewApproved && contract.activation.offlineTemplateValidationPassed
var effectiveDeploymentEnabled = deploymentEnabled && reproducibilityReady && activationReady
var effectiveTags = union(tags, {
  baseImageVersion: contract.baseImage.version
  imageContractFingerprint: uniqueString(loadTextContent('backend-image-build-contract.json'))
  activationStatus: effectiveDeploymentEnabled ? 'enabled' : 'blocked'
})
var materializedInputs = [
  {
    name: 'customize-backend-image'
    base64: loadFileAsBase64('image/customize-backend-image.sh')
    sha256: contract.scripts.customize.sha256
    destination: '${inputRoot}/customize-backend-image.sh'
  }
  {
    name: 'validate-backend-image'
    base64: loadFileAsBase64('image/validate-backend-image.sh')
    sha256: contract.scripts.validate.sha256
    destination: '${inputRoot}/validate-backend-image.sh'
  }
  {
    name: 'register-ephemeral-runner'
    base64: loadFileAsBase64('image/register-ephemeral-runner.sh')
    sha256: contract.scripts.register.sha256
    destination: '${inputRoot}/register-ephemeral-runner.sh'
  }
  {
    name: 'backend-job-hook'
    base64: loadFileAsBase64('image/backend-job-hook.sh')
    sha256: contract.scripts.jobHook.sha256
    destination: '${inputRoot}/backend-job-hook.sh'
  }
  {
    name: 'cleanup-backend-runner'
    base64: loadFileAsBase64('image/cleanup-backend-runner.sh')
    sha256: contract.scripts.cleanup.sha256
    destination: '${inputRoot}/cleanup-backend-runner.sh'
  }
  {
    name: 'verify-deployment-bundle'
    base64: loadFileAsBase64('verify-deployment-bundle.mjs')
    sha256: contract.scripts.artifactVerifier.sha256
    destination: '${inputRoot}/verify-deployment-bundle.mjs'
  }
]
var runnerInput = {
  name: 'actions-runner'
  sourceUri: contract.directArtifacts.actionsRunner.uri
  sha256: contract.directArtifacts.actionsRunner.sha256
  destination: '${inputRoot}/actions-runner-linux-x64-${contract.directArtifacts.actionsRunner.version}.tar.gz'
}
var nodeInput = {
  name: 'node'
  sourceUri: contract.directArtifacts.node.uri
  sha256: contract.directArtifacts.node.sha256
  destination: '${inputRoot}/node-v${contract.directArtifacts.node.version}-linux-x64.tar.xz'
}
var githubCliInput = {
  name: 'github-cli'
  sourceUri: contract.directArtifacts.githubCli.uri
  sha256: contract.directArtifacts.githubCli.sha256
  destination: '${inputRoot}/gh_${contract.directArtifacts.githubCli.version}_linux_amd64.tar.gz'
}
var commonValidationCommands = [
  'sudo /usr/local/sbin/certigo-validate-backend-image --image-build'
  'sudo systemctl is-enabled --quiet certigo-block-imds.service'
  'sudo systemctl is-active --quiet certigo-block-imds.service'
  'sudo /usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT'
  'sudo test ! -e /opt/actions-runner/.runner'
  'sudo test ! -e /opt/actions-runner/.credentials'
  'sudo test ! -e /opt/actions-runner/.credentials_rsaparams'
]
var roleProfiles = [
  {
    roleName: 'backend-builder'
    role: 'builder'
    runnerLabel: 'certigo-backend-builder'
    imageDefinitionName: contract.destination.builder.imageDefinitionName
    imageTemplateName: contract.destination.builder.imageTemplateName
    runOutputName: contract.destination.builder.runOutputName
    fileInputs: [
      runnerInput
      nodeInput
    ]
    customizationCommands: [
      'curl --fail --location --proto =https --tlsv1.2 ${contract.directArtifacts.dotnetSdk.uri} --output ${inputRoot}/dotnet-sdk-${contract.directArtifacts.dotnetSdk.version}-linux-x64.tar.gz'
      'echo ${contract.directArtifacts.dotnetSdk.sha512}  ${inputRoot}/dotnet-sdk-${contract.directArtifacts.dotnetSdk.version}-linux-x64.tar.gz | sha512sum --check --strict'
      'sudo env CERTIGO_IMAGE_INPUT_ROOT=${inputRoot} bash ${inputRoot}/customize-backend-image.sh builder ${contract.destination.builder.imageDefinitionName} ${contract.destination.imageVersion}'
    ]
  }
  {
    roleName: 'backend-deployer'
    role: 'deployer'
    runnerLabel: 'certigo-backend-deployer'
    imageDefinitionName: contract.destination.deployer.imageDefinitionName
    imageTemplateName: contract.destination.deployer.imageTemplateName
    runOutputName: contract.destination.deployer.runOutputName
    fileInputs: [
      runnerInput
      githubCliInput
    ]
    customizationCommands: [
      'sudo env CERTIGO_IMAGE_INPUT_ROOT=${inputRoot} bash ${inputRoot}/customize-backend-image.sh deployer ${contract.destination.deployer.imageDefinitionName} ${contract.destination.imageVersion}'
    ]
  }
]

resource gallery 'Microsoft.Compute/galleries@2024-03-03' = if (effectiveDeploymentEnabled) {
  name: contract.destination.galleryName
  location: location
  tags: effectiveTags
  properties: {
    description: 'Physically isolated Certigo backend runner images.'
    softDeletePolicy: {
      isSoftDeleteEnabled: true
    }
  }
}

module roleImages '../modules/locked-runner-image.bicep' = [
  for roleProfile in roleProfiles: if (effectiveDeploymentEnabled) {
    name: 'certigo-${roleProfile.roleName}-image'
    params: {
      deploymentEnabled: true
      activationReady: true
      reproducibleInputsReady: reproducibilityReady
      imageBuilderIdentityResourceId: imageBuilderIdentityResourceId
      stagingResourceGroupId: stagingResourceGroupId
      imageProfile: {
        galleryName: contract.destination.galleryName
        roleName: roleProfile.roleName
        runnerLabel: roleProfile.runnerLabel
        inputRoot: inputRoot
        baseImage: contract.baseImage
        imageDefinitionName: roleProfile.imageDefinitionName
        imageTemplateName: roleProfile.imageTemplateName
        imageVersion: contract.destination.imageVersion
        runOutputName: roleProfile.runOutputName
        identifier: {
          publisher: 'Certigo'
          offer: 'github-actions-backend-runner'
          sku: 'ubuntu-24.04-${roleProfile.role}'
        }
        autoRunState: 'Disabled'
        buildTimeoutInMinutes: 90
        osDiskSizeGB: 64
        vmSize: 'Standard_D2ads_v6'
      }
      fileInputs: roleProfile.fileInputs
      materializedInputs: materializedInputs
      customizationCommands: roleProfile.customizationCommands
      validationCommands: commonValidationCommands
      location: location
      tags: union(effectiveTags, {
        runnerLabel: roleProfile.runnerLabel
        runnerRole: roleProfile.roleName
      })
    }
    dependsOn: [
      gallery
    ]
  }
]

output deploymentEnabled bool = deploymentEnabled
output effectiveDeploymentEnabled bool = effectiveDeploymentEnabled
output reproducibleInputsReady bool = reproducibilityReady
output activationReady bool = activationReady
output imageTemplateIds array = [
  for roleProfile in roleProfiles: resourceId(
    'Microsoft.VirtualMachineImages/imageTemplates',
    roleProfile.imageTemplateName
  )
]
output galleryImageVersionIds array = [
  for roleProfile in roleProfiles: resourceId(
    'Microsoft.Compute/galleries/images/versions',
    contract.destination.galleryName,
    roleProfile.imageDefinitionName,
    contract.destination.imageVersion
  )
]
