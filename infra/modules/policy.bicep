// Continuous compliance posture (subscription-scoped).
//
// Assigns the built-in "Microsoft cloud security benchmark" (MCSB) initiative so
// the subscription is continuously assessed against Microsoft's security
// baseline and shows up in the Defender for Cloud regulatory-compliance
// dashboard. Enforcement is DISABLED (DoNotEnforce): the assignment never denies
// deployments and never auto-remediates — it is audit/visibility only, so it is
// safe and free to keep on permanently.
targetScope = 'subscription'

@description('Region for the policy assignment managed identity.')
param assignmentLocation string = 'westeurope'

@description('Policy enforcement mode. Only audit-only DoNotEnforce is supported until remediation identities and exemptions are designed.')
@allowed([ 'DoNotEnforce' ])
param enforcementMode string = 'DoNotEnforce'

// Built-in MCSB initiative (tenant-level definition id).
var mcsbInitiativeId = '/providers/Microsoft.Authorization/policySetDefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8'

resource mcsb 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
  name: 'certigo-mcsb'
  location: assignmentLocation
  properties: {
    displayName: 'Microsoft Cloud Security Benchmark — Certigo'
    description: 'Continuous, audit-only compliance assessment. Enforcement disabled (no Deny, no auto-remediation).'
    policyDefinitionId: mcsbInitiativeId
    enforcementMode: enforcementMode
  }
}

output assignmentName string = mcsb.name
output enforcementMode string = enforcementMode
