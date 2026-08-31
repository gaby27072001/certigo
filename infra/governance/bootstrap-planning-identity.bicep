targetScope = 'subscription'

param location string = 'westeurope'
param identityResourceGroupName string = 'rg-certigo-identities'
param identityName string = 'id-certigo-governance-phase-b1a-plan'
param githubRepositoryOwner string = 'gchambaud_microsoft'
param githubRepositoryName string = 'Certigo'
param githubEnvironmentName string = 'azure-governance-bootstrap-phase-b'

var exactAssignmentScopes = [
  subscriptionResourceId('Microsoft.Resources/resourceGroups', 'rg-certigo-dev')
  subscriptionResourceId('Microsoft.Resources/resourceGroups', 'rg-certigo-staging')
  subscriptionResourceId('Microsoft.Resources/resourceGroups', 'rg-certigo-prod')
  subscriptionResourceId('Microsoft.Resources/resourceGroups', 'rg-certigo-ci')
  subscriptionResourceId('Microsoft.Resources/resourceGroups', 'rg-certigo-content')
]

resource identityResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: identityResourceGroupName
}

resource phaseB1aPlannerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-governance-phase-b1a-planner')
  properties: {
    roleName: 'Certigo Governance Phase B1a Planner ${take(uniqueString(subscription().id), 6)}'
    description: 'Creates only evidence-approved, condition-bound B1a role assignments at five exact resource groups.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Authorization/roleAssignments/read'
          'Microsoft.Authorization/roleAssignments/write'
          'Microsoft.Authorization/roleDefinitions/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: exactAssignmentScopes
  }
}

module planningIdentity 'modules/governancePlanningIdentity.bicep' = {
  scope: identityResourceGroup
  name: 'governance-phase-b1a-planning-identity'
  params: {
    githubEnvironmentName: githubEnvironmentName
    githubRepositoryName: githubRepositoryName
    githubRepositoryOwner: githubRepositoryOwner
    identityName: identityName
    location: location
    tags: {
      product: 'Certigo'
      managedBy: 'bicep'
      purpose: 'governance-b1a-what-if-planning'
    }
  }
}

output governancePlanner object = {
  schemaVersion: 1
  clientId: planningIdentity.outputs.clientId
  identityName: identityName
  principalId: planningIdentity.outputs.principalId
  resourceId: planningIdentity.outputs.resourceId
  roleDefinitionId: phaseB1aPlannerRole.id
  subject: planningIdentity.outputs.subject
  subscriptionDeploymentLauncherRoleDefinitionId: subscriptionResourceId(
    'Microsoft.Authorization/roleDefinitions',
    guid(subscription().id, 'certigo-subscription-deployment-launcher')
  )
  subscriptionId: subscription().subscriptionId
  tenantId: tenant().tenantId
}
