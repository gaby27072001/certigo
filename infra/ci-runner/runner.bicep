targetScope = 'resourceGroup'

@description('Name of the runner VM and its GitHub runner registration.')
@minLength(1)
@maxLength(64)
param runnerName string

@description('Exact Ubuntu Marketplace image version. Resolve and record a concrete version; "latest" is rejected operationally.')
@minLength(1)
param imageVersion string

@description('SSH public key for the break-glass administrator. No private material is stored in the deployment.')
@secure()
@minLength(32)
param adminSshPublicKey string

@description('Break-glass administrator account name.')
@minLength(1)
@maxLength(32)
param adminUsername string = 'runneradmin'

@description('Azure region of the existing runner network.')
param location string = resourceGroup().location

@description('Existing runner VNet.')
param vnetName string = 'vnet-certigo-ci'

@description('Existing private subnet associated with the Certigo NAT gateway.')
param subnetName string = 'snet-runners'

@description('VM size for CI workloads.')
param vmSize string = 'Standard_D4s_v5'

@description('Availability zone. Place redundant runners in different zones.')
@allowed([
  '1'
  '2'
  '3'
])
param availabilityZone string = '1'

@description('OS disk size. The daily health gate requires at least 10 GiB free.')
@minValue(64)
param osDiskSizeGiB int = 128

@description('Resource tags.')
param tags object = {
  product: 'Certigo'
  workload: 'github-actions-runner'
  managedBy: 'bicep'
}

var bootstrapContent = loadTextContent('bootstrap.sh')
// Bicep cannot compute a cryptographic digest. The repository validator keeps this
// immutable tag value synchronized with the exact file embedded in customData.
var bootstrapSha256 = '526d63afa5c5da4657c6df57873dfa0c5d161400fc5d48e5f713861cd44fbd74'
// Azure accepts "latest", so turn that mutable value into a deliberately invalid
// Marketplace version while keeping the template compatible with stable Bicep.
var pinnedImageVersion = toLower(imageVersion) == 'latest' ? 'mutable-latest-is-not-allowed' : imageVersion
var effectiveTags = union(tags, {
  imageVersion: pinnedImageVersion
  bootstrapSha256: bootstrapSha256
})

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: subnetName
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${runnerName}-nic'
  location: location
  tags: effectiveTags
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: runnerName
  location: location
  tags: effectiveTags
  identity: {
    type: 'SystemAssigned'
  }
  zones: [
    availabilityZone
  ]
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
          }
        }
      ]
    }
    osProfile: {
      computerName: runnerName
      adminUsername: adminUsername
      customData: base64(bootstrapContent)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          patchMode: 'AutomaticByPlatform'
        }
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
        diskSizeGB: osDiskSizeGiB
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
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
        enabled: true
      }
    }
  }
}

output runnerName string = vm.name
output principalId string = vm.identity.principalId
output nicId string = nic.id
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output bootstrapSha256 string = bootstrapSha256
