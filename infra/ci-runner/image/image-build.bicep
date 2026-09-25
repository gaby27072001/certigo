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
// Hashes cannot authorize the network installer. Removal requires #341 review, CI and approval.
var networkInstallerImplemented = false
var aptInputsReady = !empty(contract.reproducibility.aptSnapshot) && length(string(contract.reproducibility.aptPackageLockSha256)) == 64
var flutterInputsReady = length(string(contract.reproducibility.flutterEngineArtifactLockSha256)) == 64
var pythonInputsReady = length(string(contract.reproducibility.pythonWheelLockSha256)) == 64
var reproducibilityReady = contract.policy.reproducibleInputsReady && contract.reproducibility.status == 'locked' && aptInputsReady && flutterInputsReady && pythonInputsReady
var effectiveDeploymentEnabled = deploymentEnabled && reproducibilityReady && networkInstallerImplemented
var contractSha256 = 'c16c01ffaf8d7184b46c5bde4e1df625d863a3ea6c303168773cc0d4c318ad9c'
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
// (C') The repository is private and AIB File customizers need public or Azure-stored
// sources: every input travels inside this template instead. loadFileAsBase64 is limited
// to 96 KB per file, so the two largest locks travel as `gzip -n -9` derivatives; the
// decompressed bytes are checked against the contract before any use. Each inline line is
// POSIX sh and exits on its own failure: the shell AIB uses for inline commands is not
// documented, and Ubuntu 24.04 dash rejects `set -o pipefail`.
var stageEmbeddedInputs = {
  type: 'Shell'
  name: 'stage-embedded-inputs'
  inline: [
    'set -eu'
    'rm -rf /tmp/certigo-image-staging && mkdir -m 0700 /tmp/certigo-image-staging || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('image-build-contract.json')}\' > /tmp/certigo-image-staging/image-build-contract.json.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('transport/apt-packages.lock.json.gz')}\' > /tmp/certigo-image-staging/apt-packages.lock.json.gz.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('flutter-engine-artifacts.lock.json')}\' > /tmp/certigo-image-staging/flutter-engine-artifacts.lock.json.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('../bootstrap.sh')}\' > /tmp/certigo-image-staging/bootstrap.sh.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('toolchain-manifest.json')}\' > /tmp/certigo-image-staging/toolchain-manifest.json.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('toolchain-sbom.cyclonedx.document')}\' > /tmp/certigo-image-staging/toolchain-sbom.cyclonedx.document.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('transport/toolchain-requirements.lock.gz')}\' > /tmp/certigo-image-staging/toolchain-requirements.lock.gz.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('prewarm-toolchain.sh')}\' > /tmp/certigo-image-staging/prewarm-toolchain.sh.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('validate-toolchain.sh')}\' > /tmp/certigo-image-staging/validate-toolchain.sh.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('inventory-toolchain.sh')}\' > /tmp/certigo-image-staging/inventory-toolchain.sh.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('seal-runner-state.sh')}\' > /tmp/certigo-image-staging/seal-runner-state.sh.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('job-temp.sh')}\' > /tmp/certigo-image-staging/job-temp.sh.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('certigo-toolchain-guard-generator')}\' > /tmp/certigo-image-staging/certigo-toolchain-guard-generator.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('certigo-toolchain-validate.service')}\' > /tmp/certigo-image-staging/certigo-toolchain-validate.service.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('certigo-job-temp-mount.service')}\' > /tmp/certigo-image-staging/certigo-job-temp-mount.service.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('runner-ephemeral.conf')}\' > /tmp/certigo-image-staging/runner-ephemeral.conf.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('python-wheels.lock.json')}\' > /tmp/certigo-image-staging/python-wheels.lock.json.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('install_offline.py')}\' > /tmp/certigo-image-staging/install_offline.py.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('image_artifacts.py')}\' > /tmp/certigo-image-staging/image_artifacts.py.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('lock_flutter.py')}\' > /tmp/certigo-image-staging/lock_flutter.py.b64 || exit 1'
    'printf \'%s\' \'${loadFileAsBase64('lock_inputs.py')}\' > /tmp/certigo-image-staging/lock_inputs.py.b64 || exit 1'
  ]
}
var verifyEmbeddedInputs = {
  type: 'Shell'
  name: 'verify-embedded-inputs'
  inline: [
    'set -eu'
    'cd /tmp/certigo-image-staging && for f in *.b64; do base64 --decode "$f" > "\${f%.b64}" && rm -f "$f" || exit 1; done'
    'cd /tmp/certigo-image-staging && for f in *.gz; do gzip -dc "$f" > "\${f%.gz}" && rm -f "$f" || exit 1; done'
    'cd /tmp/certigo-image-staging && printf \'%s  %s\\n\' ${contractSha256} image-build-contract.json > ../certigo-image-contract.sha256 && sha256sum --check --strict ../certigo-image-contract.sha256 || exit 1'
    'cd /tmp/certigo-image-staging && jq -r \'.inputs[] | "\\(.sha256)  \\(.destination)"\' image-build-contract.json > ../certigo-image-inputs.sha256 && sha256sum --check --strict ../certigo-image-inputs.sha256 || exit 1'
    'cd /tmp/certigo-image-staging && test "$(ls -A | LC_ALL=C sort)" = "$(jq -r \'.inputs[].destination, "image-build-contract.json"\' image-build-contract.json | LC_ALL=C sort)" || exit 1'
    'sudo rm -rf /var/tmp/certigo-image-input && sudo install -d -m 0755 -o root -g root /var/tmp/certigo-image-input && sudo cp -- /tmp/certigo-image-staging/* /var/tmp/certigo-image-input/ && sudo chown -R root:root /var/tmp/certigo-image-input && sudo chmod 0644 /var/tmp/certigo-image-input/* || exit 1'
  ]
}
// The only network step: exact locked URLs, verified bytes, as the unprivileged build user.
var acquireClosedArtifactSet = {
  type: 'Shell'
  name: 'acquire-closed-artifact-set'
  inline: [
    'set -eu'
    'rm -rf /tmp/certigo-image-store && python3 -E -s -B /var/tmp/certigo-image-input/image_artifacts.py acquire --root /var/tmp/certigo-image-input --store /tmp/certigo-image-store || exit 1'
    'sudo rm -rf /var/tmp/certigo-image-store && sudo mv /tmp/certigo-image-store /var/tmp/certigo-image-store && sudo chown -R root:root /var/tmp/certigo-image-store || exit 1'
  ]
}

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
    customize: [
      {
        type: 'Shell'
        name: 'block-imds-before-network'
        inline: [
          'set -eu'
          'sudo /usr/sbin/iptables -I OUTPUT 1 -d 169.254.169.254/32 -j REJECT || exit 1'
          'sudo /usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT || exit 1'
          'if curl --silent --show-error --connect-timeout 2 --max-time 3 http://169.254.169.254/metadata/instance?api-version=2021-02-01 -H Metadata:true --output /dev/null; then echo "IMDS remained reachable before image network access." >&2; exit 1; fi'
        ]
      }
      stageEmbeddedInputs
      verifyEmbeddedInputs
      acquireClosedArtifactSet
      {
        type: 'Shell'
        name: 'install-offline-toolchain'
        inline: [
          'set -eu'
          'echo "Image installation blocked: the offline installer is not admitted until review, CI and explicit approval (#341)." >&2; exit 1'
          'sudo unshare --net -- python3 -E -s -B /var/tmp/certigo-image-input/install_offline.py install --inputs /var/tmp/certigo-image-input --store /var/tmp/certigo-image-store --contract-sha256 ${contractSha256} || exit 1'
          'sudo test ! -e /opt/actions-runner/.runner || exit 1'
          'sudo test ! -e /opt/actions-runner/.credentials || exit 1'
          'sudo test ! -e /opt/actions-runner/.credentials_rsaparams || exit 1'
          'if sudo find /opt/actions-runner /opt/certigo -xdev -type f \\( -name "*.pem" -o -name "*.pfx" -o -name "id_rsa" -o -name "id_ed25519" \\) -print -quit | grep -q .; then echo "Private key material found in image." >&2; exit 1; fi'
          'sudo rm -rf -- /var/cache/certigo-runner/* /var/tmp/certigo-image-input /var/tmp/certigo-image-store /tmp/certigo-image-staging /tmp/certigo-image-contract.sha256 /tmp/certigo-image-inputs.sha256 || exit 1'
        ]
      }
    ]
    validate: {
      continueDistributeOnFailure: false
      sourceValidationOnly: false
      inVMValidations: [
        {
          type: 'Shell'
          name: 'fail-closed-image-validation'
          inline: [
            'set -eu'
            // No network during validation: the validator must be provably offline.
            'sudo unshare --net -- /usr/local/sbin/certigo-validate-toolchain --boot || exit 1'
            'sudo test ! -e /opt/actions-runner/.runner || exit 1'
            'sudo test ! -s /var/cache/certigo-runner/actions-runner-token || exit 1'
            'sudo systemctl is-enabled --quiet certigo-block-imds.service || exit 1'
            'sudo systemctl is-active --quiet certigo-block-imds.service || exit 1'
            'sudo /usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT || exit 1'
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
