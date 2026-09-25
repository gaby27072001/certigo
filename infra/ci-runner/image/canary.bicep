targetScope = 'resourceGroup'

@description('Fail-closed switch. What-if and deployment must explicitly enable this isolated canary.')
param deploymentEnabled bool = false

@description('Exact Azure Compute Gallery image version resource ID. Definition IDs and latest aliases are rejected.')
@minLength(1)
param galleryImageVersionId string

@description('Exact previous Azure Compute Gallery image version ID used for a reviewed rollback.')
param previousGalleryImageVersionId string = ''

@description('SSH public key for the canary break-glass account.')
@secure()
@minLength(32)
param adminSshPublicKey string

@description('Canary region.')
param location string = resourceGroup().location

@description('Canary expiry timestamp recorded for mandatory cleanup.')
@minLength(20)
param expiresOn string

@description('Break-glass administrator account name.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'runneradmin'

@description('Tags applied only to the new canary resources.')
param tags object = {
  product: 'Certigo'
  workload: 'github-actions-runner'
  trustBoundary: 'untrusted-pr'
  lifecycle: 'image-canary'
  managedBy: 'bicep'
}

var contract = loadJsonContent('canary-contract.json')
// Hashes cannot authorize the legacy network installer. Removal requires #341 execution proofs.
var networkInstallerImplemented = false
var buildContract = loadJsonContent('image-build-contract.json')
var attestationPolicy = loadJsonContent('attestation-policy.json')
var aptInputsReady = !empty(buildContract.reproducibility.aptSnapshot) && length(string(buildContract.reproducibility.aptPackageLockSha256)) == 64
var flutterInputsReady = length(string(buildContract.reproducibility.flutterEngineArtifactLockSha256)) == 64
var pythonInputsReady = length(string(buildContract.reproducibility.pythonWheelLockSha256)) == 64
var reproducibleInputsReady = buildContract.policy.reproducibleInputsReady && buildContract.reproducibility.status == 'locked' && aptInputsReady && flutterInputsReady && pythonInputsReady
var signerReady = attestationPolicy.activation.status == 'active'
var effectiveDeploymentEnabled = deploymentEnabled && reproducibleInputsReady && signerReady && networkInstallerImplemented
var labels = join(contract.runner.labels, ',')
var imageIdLower = toLower(galleryImageVersionId)
var isExactImageVersion = contains(imageIdLower, '/galleries/') && contains(imageIdLower, '/images/') && contains(imageIdLower, '/versions/') && !endsWith(imageIdLower, '/latest')
var exactImageVersionId = isExactImageVersion
  ? galleryImageVersionId
  : 'invalid-gallery-image-version-id'
var effectiveTags = union(tags, {
  canaryCapacity: string(contract.runner.maximumCapacity)
  expiresOn: expiresOn
  imageVersionFingerprint: uniqueString(exactImageVersionId)
  previousImageVersionFingerprint: empty(previousGalleryImageVersionId)
    ? 'not-set'
    : uniqueString(previousGalleryImageVersionId)
  runnerLabels: labels
})
var bootstrapContent = join(contract.runner.bootstrapLines, '\n')

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (effectiveDeploymentEnabled) {
  name: contract.resources.natPublicIp
  location: location
  zones: [
    '1'
  ]
  tags: effectiveTags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
  }
}

resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = if (effectiveDeploymentEnabled) {
  name: contract.resources.natGateway
  location: location
  zones: [
    '1'
  ]
  tags: effectiveTags
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 10
    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = if (effectiveDeploymentEnabled) {
  name: contract.resources.networkSecurityGroup
  location: location
  tags: effectiveTags
  properties: {
    securityRules: [
      {
        name: 'deny-imds-outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzurePlatformIMDS'
        }
      }
      {
        name: 'deny-vnet-outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'deny-vnet-inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = if (effectiveDeploymentEnabled) {
  name: contract.resources.virtualNetwork
  location: location
  tags: effectiveTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.44.0.0/16'
      ]
    }
    subnets: [
      {
        name: contract.resources.subnet
        properties: {
          addressPrefix: '10.44.1.0/24'
          defaultOutboundAccess: false
          natGateway: {
            id: natGateway.id
          }
          networkSecurityGroup: {
            id: nsg.id
          }
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource runnerScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = if (effectiveDeploymentEnabled) {
  name: contract.resources.scaleSet
  location: location
  zones: [
    '1'
  ]
  tags: effectiveTags
  sku: {
    name: 'Standard_D2ads_v6'
    tier: 'Standard'
    capacity: contract.runner.maximumCapacity
  }
  properties: {
    orchestrationMode: 'Flexible'
    platformFaultDomainCount: 1
    singlePlacementGroup: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: 'certigo-img'
        adminUsername: adminUsername
        customData: base64(bootstrapContent)
        allowExtensionOperations: true
        linuxConfiguration: {
          disablePasswordAuthentication: true
          provisionVMAgent: true
          ssh: {
            publicKeys: [
              {
                keyData: adminSshPublicKey
                path: '/home/${adminUsername}/.ssh/authorized_keys'
              }
            ]
          }
        }
      }
      storageProfile: {
        imageReference: {
          id: exactImageVersionId
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          diskSizeGB: 128
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          deleteOption: 'Delete'
        }
      }
      networkProfile: {
        networkApiVersion: '2020-11-01'
        networkInterfaceConfigurations: [
          {
            name: 'nic-pr-image-canary'
            properties: {
              primary: true
              deleteOption: 'Delete'
              enableAcceleratedNetworking: true
              enableIPForwarding: false
              ipConfigurations: [
                {
                  name: 'ipconfig1'
                  properties: {
                    primary: true
                    privateIPAddressVersion: 'IPv4'
                    subnet: {
                      id: vnet!.properties.subnets[0].id
                    }
                  }
                }
              ]
            }
          }
        ]
      }
      securityProfile: {
        encryptionAtHost: true
        securityType: 'TrustedLaunch'
        uefiSettings: {
          secureBootEnabled: true
          vTpmEnabled: true
        }
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: true
        }
      }
    }
  }
}

output deploymentEnabled bool = deploymentEnabled
output effectiveDeploymentEnabled bool = effectiveDeploymentEnabled
output runnerScaleSetId string = resourceId(
  'Microsoft.Compute/virtualMachineScaleSets',
  contract.resources.scaleSet
)
output runnerLabels string = labels
output galleryImageVersionId string = exactImageVersionId
output previousGalleryImageVersionId string = previousGalleryImageVersionId
output maximumCapacity int = contract.runner.maximumCapacity
