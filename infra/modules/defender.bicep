// Microsoft Defender for Cloud plan configuration (subscription-scoped).
//
// Foundational Cloud Security Posture Management (CSPM) is free and always on —
// it already gives secure-score, recommendations and the regulatory-compliance
// dashboard. The *paid* Defender plans below add workload threat protection but
// bill per resource/hour, so they are OFF by default to avoid surprise cost.
// Flip enablePaidPlans to true (typically for prod only) to switch them to
// Standard. The setting is subscription-wide for each resource type.
targetScope = 'subscription'

@description('Enable paid Microsoft Defender for Cloud plans. Default false: only the free foundational CSPM stays on.')
param enablePaidPlans bool = false

@description('Manage Defender pricing at subscription scope. Keep false unless this deployment owns the subscription-wide setting.')
param managePlans bool = false

@description('Defender plan names switched to Standard when enablePaidPlans is true.')
param plans array = [
  'AppServices'
  'StorageAccounts'
  'KeyVaults'
  'CosmosDbs'
]

resource defenderPlans 'Microsoft.Security/pricings@2024-01-01' = [ for plan in plans: if (managePlans) {
  name: plan
  properties: {
    pricingTier: enablePaidPlans ? 'Standard' : 'Free'
  }
}]

output managed bool = managePlans
output pricingTier string = enablePaidPlans ? 'Standard' : 'Free'
