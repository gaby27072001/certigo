targetScope = 'resourceGroup'

@description('Fail-closed switch inherited from the workload-specific wrapper.')
param deploymentEnabled bool = false

@description('Reviewed pool definition. One workload wrapper owns the values and activation gates.')
param poolProfile object

@description('Independent activation gate. Workload-specific review and attestation must set this explicitly.')
param activationReady bool = false

@description('Root-owned image validator path baked into the exact image.')
@minLength(1)
param imageValidatorPath string

@description('Single validator profile passed to the image validator.')
@minLength(1)
param imageValidationProfile string

@description('Exact Azure Compute Gallery image version resource ID. Definition IDs and latest aliases are rejected.')
@minLength(1)
param galleryImageVersionId string

@description('Exact image version ID from the independently approved immutable attestation.')
param attestedGalleryImageVersionId string = ''

@description('SSH public key for the break-glass administrator. It is not exposed to the runner service account.')
@secure()
@minLength(32)
param adminSshPublicKey string

@description('Break-glass administrator account name.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'runneradmin'

@description('Runtime region.')
param location string = resourceGroup().location

@description('Tags applied only to this isolated runtime pool.')
param tags object = {}

var imageIdLower = toLower(galleryImageVersionId)
var attestedImageIdLower = toLower(attestedGalleryImageVersionId)
var expectedImageSegment = '/images/${toLower(poolProfile.imageDefinitionName)}/versions/'
var exactImageReady = !empty(attestedImageIdLower) && imageIdLower == attestedImageIdLower && contains(imageIdLower, '/galleries/') && contains(imageIdLower, expectedImageSegment) && !endsWith(imageIdLower, '/latest')
var capacityReady = poolProfile.idleCapacity == 0 && poolProfile.maximumCapacity == 1
var identityReady = poolProfile.managedIdentity == 'none'
var routeReady = !poolProfile.networkPeeringAllowed && !poolProfile.applicationRoutesAllowed
var labelReady = startsWith(poolProfile.runnerLabel, 'certigo-') && !contains(poolProfile.runnerLabel, ',') && !contains(poolProfile.runnerLabel, ' ')
var lifecycleReady = poolProfile.registrationMode == 'ephemeral-one-job' && poolProfile.runnerEphemeralFlagRequired && poolProfile.oneJobGuardRequired && poolProfile.retireAfterJobRequired && poolProfile.deleteOrReimageAfterJobRequired
var imdsReady = poolProfile.imdsOsBlockRequired && poolProfile.imdsNsgBlockRequired
var validatorReady = startsWith(imageValidatorPath, '/usr/local/sbin/') && !contains(imageValidatorPath, ' ') && !contains(imageValidationProfile, ' ')
var effectiveDeploymentEnabled = deploymentEnabled && activationReady && exactImageReady && capacityReady && identityReady && routeReady && labelReady && lifecycleReady && imdsReady && validatorReady
var effectiveTags = union(tags, {
  product: 'Certigo'
  workload: 'github-actions-isolated-runner'
  runnerLabel: poolProfile.runnerLabel
  runnerRole: poolProfile.roleName
  capacityIdle: string(poolProfile.idleCapacity)
  capacityMaximum: string(poolProfile.maximumCapacity)
  managedIdentity: 'none'
  lifecycle: 'ephemeral-one-job'
  managedBy: 'bicep'
})
var cloudInit = join([
  '#cloud-config'
  'runcmd:'
  '  - [ /bin/systemctl, enable, --now, certigo-block-imds.service ]'
  '  - [ ${imageValidatorPath}, --runtime, ${imageValidationProfile} ]'
], '\n')

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = if (effectiveDeploymentEnabled) {
  name: poolProfile.natPublicIp
  location: location
  zones: [
    poolProfile.zone
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
  name: poolProfile.natGateway
  location: location
  zones: [
    poolProfile.zone
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
  name: poolProfile.networkSecurityGroup
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
  name: poolProfile.virtualNetwork
  location: location
  tags: effectiveTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        poolProfile.addressSpace
      ]
    }
    subnets: [
      {
        name: poolProfile.subnet
        properties: {
          addressPrefix: poolProfile.subnetPrefix
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
  name: poolProfile.virtualMachineScaleSet
  location: location
  zones: [
    poolProfile.zone
  ]
  tags: effectiveTags
  sku: {
    name: 'Standard_D2ads_v6'
    tier: 'Standard'
    capacity: poolProfile.idleCapacity
  }
  properties: {
    orchestrationMode: 'Flexible'
    overprovision: false
    platformFaultDomainCount: 1
    singlePlacementGroup: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: poolProfile.computerNamePrefix
        adminUsername: adminUsername
        customData: base64(cloudInit)
        allowExtensionOperations: false
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
          id: galleryImageVersionId
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadOnly'
          diskSizeGB: 64
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
            name: 'nic-${poolProfile.roleName}'
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
output activationReady bool = activationReady
output runnerLabel string = poolProfile.runnerLabel
output runnerScaleSetId string = resourceId(
  'Microsoft.Compute/virtualMachineScaleSets',
  poolProfile.virtualMachineScaleSet
)
output runtimeCapacity int = poolProfile.idleCapacity
output maximumCapacity int = poolProfile.maximumCapacity
output managedIdentity string = poolProfile.managedIdentity
