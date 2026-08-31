targetScope = 'subscription'

param phaseA object
param location string = 'westeurope'

@allowed([
  'Audit'
])
param privilegedAssignmentPolicyEffect string = 'Audit'

var environments = [
  {
    name: 'dev'
    identity: phaseA.identities.deployDev
  }
  {
    name: 'staging'
    identity: phaseA.identities.deployStaging
  }
  {
    name: 'prod'
    identity: phaseA.identities.deployProd
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

output assignmentCount int = 4
