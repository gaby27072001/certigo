targetScope = 'resourceGroup'

@description('Unique name of the one-shot VM and GitHub runner registration.')
@minLength(1)
@maxLength(64)
param runnerName string

@description('Exact Ubuntu Marketplace image version. Mutable values such as "latest" are rejected.')
@minLength(1)
param imageVersion string

@description('Disabled local administrator account. Registration uses protected Managed Run Command parameters, not interactive login.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'runneradmin'

@description('Azure region for the isolated one-shot runner resources.')
param location string = resourceGroup().location

@description('Availability zone used by the VM and its explicit outbound resources.')
@allowed([
  '1'
  '2'
  '3'
])
param availabilityZone string = '1'

@description('VM size. The Cosmos emulator (3 vCPU, 8 GiB cap) and the .NET tests run concurrently. Standard_D4s_v5 is NotAvailableForSubscription in westeurope (measured 2026-09-25); Dadsv6 is the family of the existing runner pool.')
param vmSize string = 'Standard_D4ads_v6'

@description('Dedicated VNet address space. The template creates no peering or private endpoint.')
param vnetAddressPrefix string = '10.43.0.0/28'

@description('Dedicated runner subnet.')
param subnetAddressPrefix string = '10.43.0.0/28'

@description('OS disk size for the pinned tools, emulator image, source, and build outputs.')
@minValue(64)
param osDiskSizeGiB int = 64

@description('Resource tags.')
param tags object = {
  product: 'Certigo'
  workload: 'cosmos-emulator-validation'
  runnerClass: 'certigo-cosmos-emulator'
  trustBoundary: 'merged-main-only'
  lifecycle: 'one-shot'
  managedIdentity: 'none'
  registrationChannel: 'protected-managed-run-command'
  managedBy: 'bicep'
}

var bootstrapContent = loadTextContent('bootstrap.sh')
// infra/ci-runner/cosmos-emulator/validate.test.mjs keeps this immutable value
// synchronized with the exact customData payload.
var bootstrapSha256 = '3fdf60eb6c075025cf99a8fc27bba6f53904103fa89e7e4cc385ad899835eb63'
var pinnedImageVersion = toLower(imageVersion) == 'latest'
  ? 'mutable-latest-is-not-allowed'
  : imageVersion
var effectiveTags = union(tags, {
  imageVersion: pinnedImageVersion
  bootstrapSha256: bootstrapSha256
})
var vnetName = '${runnerName}-vnet'
var subnetName = 'snet-cosmos-emulator'
var nsgName = '${runnerName}-nsg'
var natGatewayName = '${runnerName}-nat'
var publicIpName = '${runnerName}-egress-pip'
// Azure requires an OS-profile credential even though this VM has no inbound
// management path. The private half of this generated key was destroyed before
// commit; the NSG also denies all inbound traffic.
var disabledAdminSshPublicKey = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGw/KsqXRsTwkhv5hoRqdnYryZCwvSbW/lQP1CBrzhsc certigo-no-interactive-login'

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-07-01' = {
  name: publicIpName
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
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: publicIp.id
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: nsgName
  location: location
  tags: effectiveTags
  properties: {
    // No AzurePlatformIMDS deny at creation: Azure provisioning needs IMDS, and five
    // runner creations out of five failed with that rule active (docs/CI_RUNNER_RESILIENCE.md,
    // measured 2026-09-11/14). The bootstrap blocks IMDS on the host before any job, and
    // the runbook adds the NSG deny after registration, before the single dispatch.
    securityRules: [
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 100
          access: 'Deny'
          direction: 'Inbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'DenyVirtualNetworkOutbound'
        properties: {
          priority: 110
          access: 'Deny'
          direction: 'Outbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AllowHttpsInternetOutbound'
        properties: {
          priority: 200
          access: 'Allow'
          direction: 'Outbound'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '443'
        }
      }
      {
        name: 'DenyOtherInternetOutbound'
        properties: {
          priority: 210
          access: 'Deny'
          direction: 'Outbound'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '*'
        }
      }
    ]
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

resource nic 'Microsoft.Network/networkInterfaces@2024-07-01' = {
  name: '${runnerName}-nic'
  location: location
  tags: effectiveTags
  properties: {
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-11-01' = {
  name: runnerName
  location: location
  zones: [
    availabilityZone
  ]
  tags: effectiveTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: runnerName
      adminUsername: adminUsername
      customData: base64(bootstrapContent)
      allowExtensionOperations: true
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        ssh: {
          publicKeys: [
            {
              keyData: disabledAdminSshPublicKey
              path: '/home/${adminUsername}/.ssh/authorized_keys'
            }
          ]
        }
      }
    }
    storageProfile: {
      diskControllerType: 'NVMe'
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: pinnedImageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        diskSizeGB: osDiskSizeGiB
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
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
        enabled: false
      }
    }
  }
}

output runnerName string = vm.name
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output egressPublicIp string = publicIp.properties.ipAddress
output bootstrapSha256 string = bootstrapSha256
output managedIdentityEnabled bool = false
output runnerLabel string = 'certigo-cosmos-emulator'
