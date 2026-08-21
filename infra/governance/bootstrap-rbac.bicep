targetScope = 'subscription'

@description('Verified output object from a successful Phase A deployment.')
param phaseA object

@description('Azure region for the audit policy assignment.')
param location string = 'westeurope'

@description('Existing resource group that owns shared CI identities and networking.')
param identityResourceGroupName string = 'rg-certigo-ci'

@description('Existing dedicated immutable-content resource group.')
param contentResourceGroupName string = 'rg-certigo-content'

@description('Existing trusted CI virtual network.')
param ciVnetName string = 'vnet-certigo-ci'

@description('Existing trusted runner subnet.')
param ciRunnerSubnetName string = 'snet-runners'

@description('Existing shared Blob private DNS zone.')
#disable-next-line no-hardcoded-env-urls
param blobPrivateDnsZoneName string = 'privatelink.blob.core.windows.net'

@description('Policy effect. Keep Audit until a separately approved promotion.')
@allowed([
  'Audit'
])
param privilegedAssignmentPolicyEffect string = 'Audit'

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

var allowedRuntimeRoleDefinitionIds = [
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  'db58b8e5-c6ad-4a2a-8342-4190687cbf4a'
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  '3913510d-42f4-4e42-8a64-420c390055eb'
  '4633458b-17de-408a-b874-0445c86b69e6'
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  '73c42c96-874c-492b-b04d-ab87d138a893'
]

resource identityResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: identityResourceGroupName
}

resource contentResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: contentResourceGroupName
}

resource environmentResourceGroups 'Microsoft.Resources/resourceGroups@2024-03-01' existing = [
  for environment in environments: {
    name: environment.resourceGroupName
  }
]

resource deploymentIdentities 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = [
  for environment in environments: {
    scope: identityResourceGroup
    name: environment.identity.name
  }
]

resource contentInfrastructurePlanIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  scope: identityResourceGroup
  name: phaseA.identities.contentInfrastructurePlan.name
}

resource contentIdentities 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = [
  for identity in [
    phaseA.identities.contentRelease
    phaseA.identities.contentPublic
    phaseA.identities.contentAnswerKey
    phaseA.identities.contentReader
  ]: {
    scope: contentResourceGroup
    name: identity.name
  }
]

resource subscriptionDeploymentLauncher 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: last(split(phaseA.roleDefinitionIds.subscriptionDeploymentLauncher, '/'))
}

resource runtimeRoleAssignmentWriter 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: last(split(phaseA.roleDefinitionIds.runtimeRoleAssignmentWriter, '/'))
}

resource sharedNetworkDeploymentRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: last(split(phaseA.roleDefinitionIds.sharedNetworkDeployment, '/'))
}

resource contentPublisherRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: last(split(phaseA.roleDefinitionIds.contentPublisher, '/'))
}

resource contentInfrastructurePlanExecutorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: last(split(phaseA.roleDefinitionIds.contentInfrastructurePlanExecutor, '/'))
}

resource contentInfrastructurePlanExternalJoinRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: last(split(phaseA.roleDefinitionIds.contentInfrastructurePlanExternalJoin, '/'))
}

resource privilegedCiAssignmentPolicy 'Microsoft.Authorization/policyDefinitions@2023-04-01' existing = {
  name: last(split(phaseA.policyDefinitionId, '/'))
}

resource subscriptionLauncherAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (environment, index) in environments: {
    name: guid(subscription().id, environment.identity.name, subscriptionDeploymentLauncher.id)
    properties: {
      description: 'Launches the ${environment.name} subscription deployment without general subscription access.'
      principalId: deploymentIdentities[index].properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionDeploymentLauncher.id
    }
  }
]

module environmentRbac 'modules/environmentRbac.bicep' = [
  for (environment, index) in environments: {
    scope: environmentResourceGroups[index]
    name: 'rbac-${environment.name}'
    params: {
      allowedRoleDefinitionIds: allowedRuntimeRoleDefinitionIds
      assignmentNameSeed: environment.identity.name
      principalId: deploymentIdentities[index].properties.principalId
      roleAssignmentWriterRoleDefinitionId: runtimeRoleAssignmentWriter.id
    }
  }
]

module sharedNetworkAssignments 'modules/resourceGroupRoleAssignment.bicep' = [
  for (environment, index) in environments: {
    scope: identityResourceGroup
    name: 'shared-network-rbac-${environment.name}'
    params: {
      assignmentDescription: 'Allows ${environment.name} to reconcile only shared DNS links and VNet peerings.'
      assignmentNameSeed: environment.identity.name
      principalId: deploymentIdentities[index].properties.principalId
      roleDefinitionId: sharedNetworkDeploymentRole.id
    }
  }
]

module contentInfrastructurePlanExecutorAssignment 'modules/contentPlanExecutorAssignment.bicep' = {
  scope: contentResourceGroup
  name: 'content-infra-plan-executor-rbac'
  params: {
    assignmentNameSeed: phaseA.identities.contentInfrastructurePlan.name
    principalId: contentInfrastructurePlanIdentity.properties.principalId
    publisherPrincipalIds: [
      contentIdentities[0].properties.principalId
      contentIdentities[1].properties.principalId
      contentIdentities[2].properties.principalId
    ]
    publisherRoleDefinitionGuid: contentPublisherRole.name
    readerPrincipalId: contentIdentities[3].properties.principalId
    readerRoleDefinitionGuid: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    roleDefinitionId: contentInfrastructurePlanExecutorRole.id
  }
}

module contentInfrastructurePlanExternalJoinAssignments 'modules/contentPlanExternalJoinAssignments.bicep' = {
  scope: identityResourceGroup
  name: 'content-infra-plan-external-join-rbac'
  params: {
    blobPrivateDnsZoneName: blobPrivateDnsZoneName
    ciRunnerSubnetName: ciRunnerSubnetName
    ciVnetName: ciVnetName
    principalId: contentInfrastructurePlanIdentity.properties.principalId
    roleDefinitionId: contentInfrastructurePlanExternalJoinRole.id
  }
}

resource privilegedCiAssignmentPolicyAssignment 'Microsoft.Authorization/policyAssignments@2024-05-01' = {
  name: 'certigo-privileged-ci-rbac'
  location: location
  properties: {
    description: 'Starts in Audit. Promotion to Deny is a separate PIM-approved change after compliance evidence.'
    displayName: 'Certigo privileged CI role assignments'
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: privilegedAssignmentPolicyEffect
      }
    }
    policyDefinitionId: privilegedCiAssignmentPolicy.id
  }
}

output assignmentCount int = 16
