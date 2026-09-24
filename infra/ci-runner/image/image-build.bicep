targetScope = 'resourceGroup'

@description('Fail-closed switch. A template deployment does not create or run image resources unless explicitly enabled.')
param deploymentEnabled bool = false

@description('Dedicated user-assigned identity for Azure VM Image Builder. It must have only gallery image-version write permissions.')
@minLength(1)
param imageBuilderIdentityResourceId string

@description('Dedicated staging resource group ID used only by Azure VM Image Builder.')
@minLength(1)
param stagingResourceGroupId string

@description('Build and gallery region.')
param location string = resourceGroup().location

@description('Tags applied only to the new image build resources.')
param tags object = {
  product: 'Certigo'
  workload: 'github-actions-runner-image'
  trustBoundary: 'untrusted-pr'
  lifecycle: 'canary'
  managedBy: 'bicep'
}

var contract = loadJsonContent('image-build-contract.json')
// Hashes cannot authorize the legacy network installer. Removal requires #341 execution proofs.
var networkInstallerImplemented = false
var aptInputsReady = !empty(contract.reproducibility.aptSnapshot) && length(string(contract.reproducibility.aptPackageLockSha256)) == 64
var flutterInputsReady = length(string(contract.reproducibility.flutterEngineArtifactLockSha256)) == 64
var reproducibilityReady = contract.policy.reproducibleInputsReady && contract.reproducibility.status == 'locked' && aptInputsReady && flutterInputsReady
var effectiveDeploymentEnabled = deploymentEnabled && reproducibilityReady && networkInstallerImplemented
var sourceRoot = 'https://raw.githubusercontent.com/${contract.repository}/${contract.contractCommit}/'
var inputRoot = '/var/tmp/certigo-image-input'
var contractSha256 = '08cf81ddfc82a2df5c304d7573af980f169154fdfedaa17d8158706aad8a87c9'
var galleryImageDefinitionId = resourceId(
  'Microsoft.Compute/galleries/images',
  contract.destination.galleryName,
  contract.destination.imageDefinitionName
)
var galleryImageVersionId = '${galleryImageDefinitionId}/versions/${contract.destination.imageVersion}'
var effectiveTags = union(tags, {
  baseImageVersion: contract.baseImage.version
  contractCommit: contract.contractCommit
  contractSha256: contractSha256
  imageVersion: contract.destination.imageVersion
})
var inputCustomizers = [
  for input in contract.inputs: {
    type: 'File'
    name: 'input-${input.id}'
    sourceUri: '${sourceRoot}${input.path}'
    sha256Checksum: input.sha256
    destination: '${inputRoot}/${input.destination}'
  }
]

resource gallery 'Microsoft.Compute/galleries@2024-03-03' = if (effectiveDeploymentEnabled) {
  name: contract.destination.galleryName
  location: location
  tags: effectiveTags
  properties: {
    description: 'Isolated Certigo runner image canary gallery.'
    softDeletePolicy: {
      isSoftDeleteEnabled: true
    }
  }
}

resource imageDefinition 'Microsoft.Compute/galleries/images@2024-03-03' = if (effectiveDeploymentEnabled) {
  parent: gallery
  name: contract.destination.imageDefinitionName
  location: location
  tags: effectiveTags
  properties: {
    architecture: 'x64'
    hyperVGeneration: 'V2'
    identifier: {
      publisher: 'Certigo'
      offer: 'github-actions-runner'
      sku: 'ubuntu-24.04-x64'
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
  name: contract.destination.imageTemplateName
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
    buildTimeoutInMinutes: 120
    errorHandling: {
      onCustomizerError: 'cleanup'
      onValidationError: 'cleanup'
    }
    stagingResourceGroup: stagingResourceGroupId
    source: {
      type: 'PlatformImage'
      publisher: contract.baseImage.publisher
      offer: contract.baseImage.offer
      sku: contract.baseImage.sku
      version: contract.baseImage.version
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
            'if curl --silent --show-error --connect-timeout 2 --max-time 3 http://169.254.169.254/metadata/instance?api-version=2021-02-01 -H Metadata:true --output /dev/null; then echo "IMDS remained reachable before image network access." >&2; exit 1; fi'
          ]
        }
        {
          type: 'Shell'
          name: 'prepare-input-directory'
          inline: [
            'set -euo pipefail'
            'sudo install -d -m 0755 ${inputRoot}'
          ]
        }
      ],
      inputCustomizers,
      [
        {
          type: 'Shell'
          name: 'install-exact-toolchain'
          inline: [
            'set -euo pipefail'
            'echo "Image installation blocked: exhaustive offline network input consumption is not implemented (#341)." >&2; exit 1'
            'cd ${inputRoot}'
            'sudo chmod 0755 bootstrap.sh prewarm-toolchain.sh validate-toolchain.sh inventory-toolchain.sh seal-runner-state.sh job-temp.sh certigo-toolchain-guard-generator'
            'sudo env CERTIGO_RUNNER_LABELS=certigo-pr-image-canary CERTIGO_BLOCK_IMDS=true bash ./bootstrap.sh'
            'sudo bash ./prewarm-toolchain.sh'
            'sudo test ! -e /opt/actions-runner/.runner'
            'sudo test ! -e /opt/actions-runner/.credentials'
            'sudo test ! -e /opt/actions-runner/.credentials_rsaparams'
            'if sudo find /opt/actions-runner /opt/certigo -xdev -type f \\( -name "*.pem" -o -name "*.pfx" -o -name "id_rsa" -o -name "id_ed25519" \\) -print -quit | grep -q .; then echo "Private key material found in image." >&2; exit 1; fi'
            'sudo rm -rf -- /var/cache/certigo-runner/* ${inputRoot}'
          ]
        }
      ]
    )
    validate: {
      continueDistributeOnFailure: false
      sourceValidationOnly: false
      inVMValidations: [
        {
          type: 'Shell'
          name: 'fail-closed-image-validation'
          inline: [
            'set -euo pipefail'
            'sudo /usr/local/sbin/certigo-validate-toolchain --boot'
            'sudo test ! -e /opt/actions-runner/.runner'
            'sudo test ! -s /var/cache/certigo-runner/actions-runner-token'
            'sudo systemctl is-enabled --quiet certigo-block-imds.service'
            'sudo systemctl is-active --quiet certigo-block-imds.service'
            'sudo /usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT'
            'if curl --silent --show-error --connect-timeout 2 --max-time 3 http://169.254.169.254/metadata/instance?api-version=2021-02-01 -H Metadata:true --output /dev/null; then echo "IMDS is reachable in the completed image." >&2; exit 1; fi'
          ]
        }
      ]
    }
    distribute: [
      {
        type: 'SharedImage'
        runOutputName: contract.destination.runOutputName
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
      osDiskSizeGB: 128
      vmSize: 'Standard_D2ads_v6'
    }
  }
}

output deploymentEnabled bool = deploymentEnabled
output effectiveDeploymentEnabled bool = effectiveDeploymentEnabled
output reproducibilityStatus string = contract.reproducibility.status
output imageTemplateId string = resourceId(
  'Microsoft.VirtualMachineImages/imageTemplates',
  contract.destination.imageTemplateName
)
output galleryImageVersionId string = galleryImageVersionId
output contractCommit string = contract.contractCommit
output contractSha256 string = contractSha256
