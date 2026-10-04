// ============================================================================
// Certigo — composition des runners CI à la demande (réveil + désallocation).
//
// Scope subscription : les deux rôles personnalisés sont des objets de subscription, mais
// ils ne sont ASSIGNABLES qu'au seul `rg-certigo-ci`, et ils n'y sont ASSIGNÉS qu'à
// l'identité système de leur propre Logic App. Aucun droit au scope subscription.
//
// Deux identités, deux rôles, jamais mélangés :
//   * réveil        : `virtualMachines/read` + `virtualMachines/start/action` ;
//   * désallocation : `virtualMachines/read` + `virtualMachines/deallocate/action`.
// Exclus délibérément des deux : `delete`, `write`, `powerOff`, `restart`, `redeploy`,
// `reimage`, `capture` et surtout `runCommand/action` (exécution de code sur les runners
// trusted). L'identité de reprise existante (`auto-recovery.bicep`) n'est pas modifiée et ne
// reçoit toujours pas `deallocate`.
//
// Le côté VM (qui décide de l'inactivité et arrête l'OS) est `infra/ci-runner/idle-shutdown.sh`,
// installé par `infra/ci-runner/install-idle-shutdown.ps1`. Les webhooks GitHub sont posés par
// `infra/ci-runner/register-wake-webhooks.ps1`. Voir docs/adr/ADR-022-runners-ci-a-la-demande.md.
// ============================================================================
targetScope = 'subscription'

@description('Resource group hébergeant les runners CI et l\'action group de la reprise. Doit préexister.')
@minLength(1)
param resourceGroupName string = 'rg-certigo-ci'

@description('Région des Logic Apps.')
param location string = 'westeurope'

resource runnerResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

// Unique source des pools, des labels de réveil et des périodes calmes (lues aussi par
// install-idle-shutdown.ps1) ; les exclusions et les dépôts viennent de l'inventaire.
var onDemandPools = loadJsonContent('on-demand.config.json', '$.pools')
var wakeActions = loadJsonContent('on-demand.config.json', '$.wakeActions')
var wakePassDelaysSeconds = loadJsonContent('on-demand.config.json', '$.wakePassDelaysSeconds')
var allowedCallerAddressRanges = loadJsonContent('on-demand.config.json', '$.githubHookSourceRanges.addressRanges')
var repositories = loadJsonContent('capacity-controller.config.json', '$.repositories')
var forbiddenVirtualMachines = loadJsonContent('capacity-controller.config.json', '$.inventory.forbiddenVirtualMachines')
var externalVirtualMachines = loadJsonContent('capacity-controller.config.json', '$.inventory.externalVirtualMachines')
var excludedVirtualMachineNames = union(forbiddenVirtualMachines, externalVirtualMachines)
var pools = map(onDemandPools, pool => {
  name: pool.scaleSet
  wakeLabels: pool.wakeLabels
})

var assignableScopes = [
  subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroupName)
]
var roleSuffix = take(uniqueString(subscription().id), 6)

resource wakeRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-ci-runner-wake')
  properties: {
    roleName: 'Certigo CI Runner Wake ${roleSuffix}'
    description: 'Lit et demarre les VMs de runner CI de rg-certigo-ci sur webhook workflow_job. Aucune desallocation, suppression, ecriture ni execution de commande.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/start/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: assignableScopes
  }
}

resource deallocationRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-ci-runner-idle-deallocation')
  properties: {
    roleName: 'Certigo CI Runner Idle Deallocation ${roleSuffix}'
    description: 'Lit et desalloue les VMs de runner CI de rg-certigo-ci dont l OS est deja arrete. Aucun demarrage, suppression, ecriture ni execution de commande.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/deallocate/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: assignableScopes
  }
}

module onDemand 'modules/runnerOnDemand.bicep' = {
  scope: runnerResourceGroup
  name: 'certigo-ci-runner-on-demand'
  params: {
    location: location
    pools: pools
    excludedVirtualMachineNames: excludedVirtualMachineNames
    repositories: repositories
    wakeActions: wakeActions
    wakePassDelaysSeconds: wakePassDelaysSeconds
    allowedCallerAddressRanges: allowedCallerAddressRanges
  }
}

module wakeRoleAssignment '../governance/modules/resourceGroupRoleAssignment.bicep' = {
  scope: runnerResourceGroup
  name: 'certigo-ci-runner-wake-rbac'
  params: {
    assignmentNameSeed: 'certigo-ci-runner-wake'
    assignmentDescription: 'Autorise le Logic App de reveil a lire et demarrer uniquement les VMs de runner CI.'
    principalId: onDemand.outputs.wakePrincipalId
    roleDefinitionId: wakeRole.id
  }
}

module deallocationRoleAssignment '../governance/modules/resourceGroupRoleAssignment.bicep' = {
  scope: runnerResourceGroup
  name: 'certigo-ci-runner-idle-deallocation-rbac'
  params: {
    assignmentNameSeed: 'certigo-ci-runner-idle-deallocation'
    assignmentDescription: 'Autorise le Logic App de desallocation a lire et desallouer uniquement les VMs de runner CI dont l OS est arrete.'
    principalId: onDemand.outputs.deallocationPrincipalId
    roleDefinitionId: deallocationRole.id
  }
}

output wakeRoleDefinitionId string = wakeRole.id
output deallocationRoleDefinitionId string = deallocationRole.id
output wakeWorkflowName string = onDemand.outputs.wakeWorkflowName
output wakeWorkflowResourceId string = onDemand.outputs.wakeWorkflowResourceId
output wakeTriggerName string = onDemand.outputs.wakeTriggerName
output deallocationWorkflowName string = onDemand.outputs.deallocationWorkflowName
output deallocationWorkflowResourceId string = onDemand.outputs.deallocationWorkflowResourceId
output pools array = pools
output excludedVirtualMachineNames array = excludedVirtualMachineNames
