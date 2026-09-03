targetScope = 'resourceGroup'

@description('Fail-closed switch inherited from the workload-specific image wrapper.')
param deploymentEnabled bool = false

@description('Independent activation gate owned by the workload-specific reviewed contract.')
param activationReady bool = false

@description('True only when every image input is immutable and locally validated.')
param reproducibleInputsReady bool = false

@description('Build-plane-only Azure VM Image Builder identity. It is never assigned to runtime hosts.')
@minLength(1)
param imageBuilderIdentityResourceId string

@description('Dedicated Azure VM Image Builder staging resource group ID.')
@minLength(1)
param stagingResourceGroupId string

@description('Reviewed image definition, source, destination, label, and role.')
param imageProfile object

@description('Remote files with mandatory lowercase SHA-256 checksums.')
param fileInputs array

@description('Base64 file contents embedded by the workload wrapper with mandatory lowercase SHA-256 checksums.')
param materializedInputs array

@description('Fail-fast root commands that install and seal the role-specific image.')
param customizationCommands array

@description('Fail-fast root commands that validate the completed image.')
param validationCommands array

@description('Image build and gallery region.')
param location string = resourceGroup().location

@description('Tags applied only to this image definition and template.')
param tags object = {}

var imageId = resourceId(
  'Microsoft.Compute/galleries/images',
  imageProfile.galleryName,
  imageProfile.imageDefinitionName
)
var galleryImageVersionId = '${imageId}/versions/${imageProfile.imageVersion}'
var fileInputsLocked = length(fileInputs) > 0 && length(filter(fileInputs, input => length(string(input.sha256)) != 64 || !startsWith(input.destination, '/var/tmp/'))) == 0
var materializedInputsLocked = length(materializedInputs) > 0 && length(filter(materializedInputs, input => length(string(input.sha256)) != 64 || !startsWith(input.destination, '/var/tmp/'))) == 0
var profileReady = startsWith(imageProfile.runnerLabel, 'certigo-') && !contains(imageProfile.runnerLabel, ',') && !contains(imageProfile.runnerLabel, ' ') && !empty(imageProfile.imageDefinitionName) && !empty(imageProfile.imageTemplateName) && !empty(imageProfile.imageVersion) && imageProfile.autoRunState == 'Disabled'
var commandsReady = length(customizationCommands) > 0 && length(validationCommands) > 0
var effectiveDeploymentEnabled = deploymentEnabled && activationReady && reproducibleInputsReady && fileInputsLocked && materializedInputsLocked && profileReady && commandsReady
var effectiveTags = union(tags, {
  product: 'Certigo'
  workload: 'github-actions-isolated-runner-image'
  runnerLabel: imageProfile.runnerLabel
  runnerRole: imageProfile.roleName
  baseImageVersion: imageProfile.baseImage.version
  imageVersion: imageProfile.imageVersion
  lifecycle: 'ephemeral-one-job'
  managedBy: 'bicep'
})
var materializeCommands = [
  for input in materializedInputs: 'printf %s ${input.base64} | base64 --decode | sudo tee ${input.destination} >/dev/null && echo ${input.sha256}  ${input.destination} | sha256sum --check --strict && sudo chmod 0700 ${input.destination}'
]
var fileCustomizers = [
  for input in fileInputs: {
    type: 'File'
    name: input.name
    sourceUri: input.sourceUri
    sha256Checksum: input.sha256
    destination: input.destination
  }
]

resource gallery 'Microsoft.Compute/galleries@2024-03-03' existing = {
  name: imageProfile.galleryName
}

resource imageDefinition 'Microsoft.Compute/galleries/images@2024-03-03' = if (effectiveDeploymentEnabled) {
  parent: gallery
  name: imageProfile.imageDefinitionName
  location: location
  tags: effectiveTags
  properties: {
    architecture: 'x64'
    hyperVGeneration: 'V2'
    identifier: {
      publisher: imageProfile.identifier.publisher
      offer: imageProfile.identifier.offer
      sku: imageProfile.identifier.sku
    }
    osState: 'Generalized'
    osType: 'Linux'
    features: [
      {
        name: 'SecurityType'
        value: 'TrustedLaunchSupported'
      }
    ]
  }
}

resource imageTemplate 'Microsoft.VirtualMachineImages/imageTemplates@2025-10-01' = if (effectiveDeploymentEnabled) {
  name: imageProfile.imageTemplateName
  location: location
  tags: effectiveTags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${imageBuilderIdentityResourceId}': {}
    }
  }
  properties: {
    autoRun: {
      state: 'Disabled'
    }
    buildTimeoutInMinutes: imageProfile.buildTimeoutInMinutes
    errorHandling: {
      onCustomizerError: 'cleanup'
      onValidationError: 'cleanup'
    }
    stagingResourceGroup: stagingResourceGroupId
    source: {
      type: 'PlatformImage'
      publisher: imageProfile.baseImage.publisher
      offer: imageProfile.baseImage.offer
      sku: imageProfile.baseImage.sku
      version: imageProfile.baseImage.version
    }
    customize: concat(
      [
        {
          type: 'Shell'
          name: 'block-imds-before-network'
          inline: [
            'set -euo pipefail'
            'sudo /usr/sbin/iptables -I OUTPUT 1 -d 169.254.169.254/32 -j REJECT'
            'sudo /usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT'
            'if curl --silent --show-error --connect-timeout 2 --max-time 3 http://169.254.169.254/metadata/instance?api-version=2021-02-01 -H Metadata:true --output /dev/null; then echo "IMDS remained reachable before image customization." >&2; exit 1; fi'
          ]
        }
        {
          type: 'Shell'
          name: 'materialize-locked-inputs'
          inline: concat(
            [
              'set -euo pipefail'
              'sudo install -d -m 0700 ${imageProfile.inputRoot}'
            ],
            materializeCommands
          )
        }
      ],
      fileCustomizers,
      [
        {
          type: 'Shell'
          name: 'install-${imageProfile.roleName}'
          inline: concat(
            [
              'set -euo pipefail'
            ],
            customizationCommands
          )
        }
      ]
    )
    validate: {
      continueDistributeOnFailure: false
      sourceValidationOnly: false
      inVMValidations: [
        {
          type: 'Shell'
          name: 'fail-closed-${imageProfile.roleName}-validation'
          inline: concat(
            [
              'set -euo pipefail'
            ],
            validationCommands
          )
        }
      ]
    }
    distribute: [
      {
        type: 'SharedImage'
        runOutputName: imageProfile.runOutputName
        galleryImageId: galleryImageVersionId
        excludeFromLatest: true
        targetRegions: [
          {
            name: location
            replicaCount: 1
            storageAccountType: 'Standard_LRS'
          }
        ]
        artifactTags: effectiveTags
      }
    ]
    vmProfile: {
      osDiskSizeGB: imageProfile.osDiskSizeGB
      vmSize: imageProfile.vmSize
    }
  }
}

output deploymentEnabled bool = deploymentEnabled
output effectiveDeploymentEnabled bool = effectiveDeploymentEnabled
output imageTemplateId string = resourceId(
  'Microsoft.VirtualMachineImages/imageTemplates',
  imageProfile.imageTemplateName
)
output galleryImageVersionId string = galleryImageVersionId
output runnerLabel string = imageProfile.runnerLabel
