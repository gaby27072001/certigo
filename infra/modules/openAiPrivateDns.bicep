// Private DNS adoption for the dev Azure AI Services account ('certigo-openai').
//
// The account is reachable only through its private endpoint
// (publicNetworkAccess = Disabled). A kind=AIServices account answers on THREE
// public suffixes, and each needs its own private DNS zone:
//   cognitiveservices.azure.com -> privatelink.cognitiveservices.azure.com
//   openai.azure.com            -> privatelink.openai.azure.com
//   services.ai.azure.com       -> privatelink.services.ai.azure.com
// Only the middle zone was created out-of-band, so the other two suffixes cannot
// resolve privately from anywhere -- including from the app VNet itself.
//
// ⚠️ ORDERING HAZARD -- read before editing.
// A private DNS zone linked to a VNet is AUTHORITATIVE for its namespace. An empty
// linked zone therefore answers NXDOMAIN instead of letting the query fall through
// to public DNS. Creating a zone and its VNet link WITHOUT the matching private
// endpoint DNS zone group entry (which is what writes the A record) makes
// resolution strictly worse: it turns "resolves publicly, then gets refused by the
// firewall" into "does not resolve at all", with a symptom that looks unrelated to
// the change. Zones, VNet links and zone-group entries must land together. This
// module deliberately owns all three so they cannot be split by accident.

targetScope = 'resourceGroup'

@description('Application virtual network resource id (the VNet hosting the private endpoint).')
param appVnetId string

@description('Application virtual network name.')
param appVnetName string

@description('Trusted CI runner virtual network resource id. Peered to the app VNet, but it cannot resolve the private endpoint until it is linked to these zones.')
param ciVnetId string

@description('Trusted CI runner virtual network name.')
param ciVnetName string

@description('Existing private endpoint fronting the AI Services account. Created out-of-band; adopted read-only here so only its DNS zone group is managed.')
param privateEndpointName string

@description('Name of the private endpoint DNS zone group. Must match the live group so the deployment updates it instead of creating a second one.')
param dnsZoneGroupName string = 'default'

@description('Existing app-VNet link on the OpenAI zone. Adopted by name because Azure rejects linking the same VNet to one zone twice.')
param existingOpenAiAppLinkName string = 'vnet-certigo-dev-openai-link'

param tags object = {}

resource openAiZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.openai.azure.com'
}

resource cognitiveServicesZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  #disable-next-line no-hardcoded-env-urls
  name: 'privatelink.cognitiveservices.azure.com'
  location: 'global'
  tags: tags
}

resource servicesAiZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.services.ai.azure.com'
  location: 'global'
  tags: tags
}

// The OpenAI zone already carries an app-VNet link created out-of-band. Reuse its
// exact name so this deployment adopts it rather than attempting a duplicate link,
// mirroring how sharedPrivateDns.bicep adopts the pre-existing CI Key Vault link.
resource openAiAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: openAiZone
  name: existingOpenAiAppLinkName
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}

resource cognitiveServicesAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cognitiveServicesZone
  name: '${appVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}

resource servicesAiAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: servicesAiZone
  name: '${appVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: appVnetId
    }
  }
}

// CI links. The CI VNet is already peered to the app VNet, so packets route today;
// only name resolution is missing. Resolution-only: registrationEnabled stays false.
resource openAiCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: openAiZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

resource cognitiveServicesCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: cognitiveServicesZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

resource servicesAiCiLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: servicesAiZone
  name: '${ciVnetName}-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ciVnetId
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' existing = {
  name: privateEndpointName
}

// Writes the A records into all three zones. Without this the new zones would be
// empty and authoritative -- see the ordering hazard at the top of this file. The
// existing openai config is restated with its live name and zone id so the update
// is additive and does not churn the record that already works.
resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: dnsZoneGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: openAiZone.name
        properties: {
          privateDnsZoneId: openAiZone.id
        }
      }
      {
        name: cognitiveServicesZone.name
        properties: {
          privateDnsZoneId: cognitiveServicesZone.id
        }
      }
      {
        name: servicesAiZone.name
        properties: {
          privateDnsZoneId: servicesAiZone.id
        }
      }
    ]
  }
  dependsOn: [
    openAiAppLink
    cognitiveServicesAppLink
    servicesAiAppLink
    openAiCiLink
    cognitiveServicesCiLink
    servicesAiCiLink
  ]
}

output openAiZoneId string = openAiZone.id
output cognitiveServicesZoneId string = cognitiveServicesZone.id
output servicesAiZoneId string = servicesAiZone.id
output dnsZoneGroupId string = dnsZoneGroup.id
