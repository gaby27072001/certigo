targetScope = 'subscription'

@description('Verified output object from a successful Phase A deployment.')
param phaseA object

@description('Existing resource group that owns shared CI networking.')
param ciResourceGroupName string = 'rg-certigo-ci'

var environments = [
  {
    name: 'dev'
    resourceGroupName: 'rg-certigo-dev'
    identity: phaseA.identities.deployDev
  }
  {
    name: 'staging'
    resourceGroupName: 'rg-certigo-staging'
    identity: phaseA.identities.deployStaging
  }
  {
    name: 'prod'
    resourceGroupName: 'rg-certigo-prod'
    identity: phaseA.identities.deployProd
  }
]

resource ciResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: ciResourceGroupName
}

resource environmentResourceGroups 'Microsoft.Resources/resourceGroups@2024-03-01' existing = [
  for environment in environments: {
    name: environment.resourceGroupName
  }
]

module environmentContributor 'modules/environmentContributorAssignment.bicep' = [
  for (environment, index) in environments: {
    scope: environmentResourceGroups[index]
    name: 'contributor-rbac-${environment.name}'
    params: {
      assignmentNameSeed: environment.identity.name
      principalId: environment.identity.principalId
    }
  }
]

module sharedNetworkAssignments 'modules/resourceGroupRoleAssignment.bicep' = [
  for (environment, index) in environments: {
    scope: ciResourceGroup
    name: 'shared-network-rbac-${environment.name}'
    params: {
      assignmentDescription: 'Allows ${environment.name} to reconcile only shared DNS links and VNet peerings.'
      assignmentNameSeed: environment.identity.name
      principalId: environment.identity.principalId
      roleDefinitionId: phaseA.roleDefinitionIds.sharedNetworkDeployment
    }
  }
]

output assignmentCount int = 6
