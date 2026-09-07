targetScope = 'resourceGroup'

@description('Dedicated Flexible VM Scale Set for the isolated PR-only pilot.')
@minLength(1)
@maxLength(64)
param runnerScaleSetName string = 'vmss-certigo-pr-pilot-z1'

@description('Exact Ubuntu Marketplace image version. Mutable values such as "latest" are rejected.')
@minLength(1)
param imageVersion string

@description('SSH public key for the break-glass administrator. No private material is stored in Azure.')
@secure()
@minLength(32)
param adminSshPublicKey string

@description('Break-glass administrator account name.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'runneradmin'

@description('Azure region for the isolated pilot.')
param location string = resourceGroup().location

@description('VM size matching the current managed runner fleet.')
param vmSize string = 'Standard_D2ads_v6'

@description('Availability zone. The draining f55d176e instance is in zone 2.')
@allowed([
  '1'
  '3'
])
param availabilityZone string = '1'

@description('Pinned, mutually exclusive labels for the untrusted PR runner.')
@allowed([
  'certigo-pr,certigo-pr-pilot'
])
param runnerLabels string = 'certigo-pr,certigo-pr-pilot'

@description('Block IMDS at the NSG after cloud-init has installed and verified the persistent OS firewall gate.')
param blockImdsAtNsg bool = true

@description('OS disk size. CI health requires at least 10 GiB free.')
@minValue(64)
param osDiskSizeGiB int = 128

@description('Dedicated, unpeered virtual network for the PR-only runner.')
param vnetName string = 'vnet-certigo-pr-pilot'

@description('Dedicated private runner subnet.')
param subnetName string = 'snet-pr-runners'

@description('Dedicated NAT gateway used only for public egress.')
param natGatewayName string = 'nat-certigo-pr-pilot'

@description('Public IP used by the NAT gateway. The VM and its NIC have no public IP.')
param natPublicIpName string = 'pip-certigo-pr-pilot-nat'

@description('NSG that blocks VNet/private and IMDS access while permitting required public egress.')
param nsgName string = 'nsg-certigo-pr-pilot'

@description('Address space of the dedicated, unpeered VNet.')
param vnetAddressPrefix string = '10.43.0.0/16'

@description('Address range of the dedicated runner subnet.')
param subnetAddressPrefix string = '10.43.1.0/24'

@description('Resource tags.')
param tags object = {
  product: 'Certigo'
  workload: 'github-actions-runner'
  trustBoundary: 'untrusted-pr'
  lifecycle: 'pilot'
  managedBy: 'bicep'
}

var bootstrapSource = loadTextContent('bootstrap.sh')
var bootstrapContent = '#!/usr/bin/env bash\nexport CERTIGO_RUNNER_LABELS=\'${runnerLabels}\'\nexport CERTIGO_BLOCK_IMDS=\'true\'\n${bootstrapSource}'
// The repository validator keeps this value synchronized with bootstrap.sh.
// Il peut en revanche differer de la valeur *deployee* : un deploiement du modele
// complet reecrit alors `customData` sur les instances en service, pas seulement sur
// une nouvelle. `customData` etant write-only, la comparaison passe obligatoirement par
// un what-if. Voir « Avant tout redeploiement complet » dans README.md.
var bootstrapSha256 = '6e798d4eeddc032eb948336cf17aef3539a91b8a33097b3cb877c4f3019c844c'
var runnerVersion = '2.336.0'
var pinnedImageVersion = toLower(imageVersion) == 'latest' ? 'mutable-latest-is-not-allowed' : imageVersion
var effectiveTags = union(tags, {
  availabilityZone: availabilityZone
  bootstrapSha256: bootstrapSha256
  imageVersion: pinnedImageVersion
  runnerLabels: runnerLabels
  runnerVersion: runnerVersion
})

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: natPublicIpName
  location: location
  zones: [
    availabilityZone
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

resource natGateway 'Microsoft.Network/natGateways@2024-07-01' = {
  name: natGatewayName
  location: location
  zones: [
    availabilityZone
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

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: nsgName
  location: location
  tags: effectiveTags
  properties: {
    securityRules: concat(
      blockImdsAtNsg ? [
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
      ] : [],
      [
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
    )
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  tags: effectiveTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
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

resource runnerScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = {
  name: runnerScaleSetName
  location: location
  zones: [
    availabilityZone
  ]
  tags: effectiveTags
  sku: {
    name: vmSize
    tier: 'Standard'
    // Toute instance supplémentaire doit être créée avec blockImdsAtNsg=false, puis
    // durcie à nouveau à true : l'agent Azure interroge IMDS pendant le provisionnement
    // de l'OS et échoue en OSProvisioningInternalError si deny-imds-outbound est déjà
    // actif. Mesuré : ~30 min d'échec avec la règle, `Succeeded` en 1,1 min sans elle.
    // La défense en profondeur reste assurée par certigo-block-imds.service au niveau
    // de l'OS (voir infra/ci-runner/pilot-preflight.sh).
    capacity: 2
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
        computerNamePrefix: 'certigo-pr'
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
          publisher: 'Canonical'
          offer: 'ubuntu-24_04-lts'
          sku: 'server'
          version: pinnedImageVersion
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          diskSizeGB: osDiskSizeGiB
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
            name: 'nic-pr-runner'
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
                      id: vnet.properties.subnets[0].id
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

output runnerScaleSetId string = runnerScaleSet.id
output runnerScaleSetName string = runnerScaleSet.name
output runnerLabels string = runnerLabels
output availabilityZone string = availabilityZone
output bootstrapSha256 string = bootstrapSha256
output imageVersion string = pinnedImageVersion
output natEgressPublicIp string = natPublicIp.properties.ipAddress
output subnetId string = vnet.properties.subnets[0].id
