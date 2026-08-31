targetScope = 'subscription'

@description('Verified output object from a successful Phase A deployment.')
param phaseA object

@description('Azure region for the audit policy assignment.')
param location string = 'westeurope'

@description('Existing resource group that owns shared CI networking.')
param ciResourceGroupName string = 'rg-certigo-ci'

@description('Existing dedicated immutable-content resource group.')
param contentResourceGroupName string = 'rg-certigo-content'

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

resource ciResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: ciResourceGroupName
}

resource contentResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: contentResourceGroupName
}

resource environmentResourceGroups 'Microsoft.Resources/resourceGroups@2024-03-01' existing = [
  for environment in environments: {
    name: environment.resourceGroupName
  }
]

resource subscriptionLauncherAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for environment in environments: {
    name: guid(
      subscription().id,
      environment.identity.name,
      phaseA.roleDefinitionIds.subscriptionDeploymentLauncher
    )
    properties: {
      description: 'Launches the ${environment.name} subscription deployment without general subscription access.'
      principalId: environment.identity.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: phaseA.roleDefinitionIds.subscriptionDeploymentLauncher
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
      principalId: environment.identity.principalId
      roleAssignmentWriterRoleDefinitionId: phaseA.roleDefinitionIds.runtimeRoleAssignmentWriter
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

module contentInfrastructurePlanExecutorAssignment 'modules/contentPlanExecutorAssignment.bicep' = {
  scope: contentResourceGroup
  name: 'content-infra-plan-executor-rbac'
  params: {
    assignmentNameSeed: phaseA.identities.contentInfrastructurePlan.name
    principalId: phaseA.identities.contentInfrastructurePlan.principalId
    publisherPrincipalIds: [
      phaseA.identities.contentRelease.principalId
      phaseA.identities.contentPublic.principalId
      phaseA.identities.contentAnswerKey.principalId
    ]
    publisherRoleDefinitionGuid: last(split(phaseA.roleDefinitionIds.contentPublisher, '/'))
    readerPrincipalId: phaseA.identities.contentReader.principalId
    readerRoleDefinitionGuid: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
    roleDefinitionId: phaseA.roleDefinitionIds.contentInfrastructurePlanExecutor
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
    policyDefinitionId: phaseA.policyDefinitionId
  }
}

output assignmentCount int = 14
