// ============================================================================
// Certigo — composition de la reprise automatique des runners CI.
//
// Scope subscription : le rôle personnalisé est un objet de subscription, mais
// il n'est ASSIGNABLE qu'au seul `rg-certigo-ci`, et il n'est ASSIGNÉ qu'à ce
// resource group. Aucun droit au scope subscription n'est accordé.
//
// Modèle de privilège — trois actions, chacune justifiée :
//   * `Microsoft.Compute/virtualMachines/read`
//       Résoudre l'instance avant de la démarrer et lister son état. C'est le
//       droit minimal sans lequel aucun appel ARM ciblé n'est possible.
//   * `Microsoft.Compute/virtualMachines/start/action`
//       La seule mutation autorisée. Démarrer est idempotent et sans effet sur
//       une VM déjà sous tension.
//   * `Microsoft.Compute/virtualMachines/instanceView/read`
//       Lire le power state pour VÉRIFIER la reprise. `GET .../instanceView`
//       est autorisé par cette action distincte, pas par le `read` ci-dessus.
//
// Ce qui est délibérément EXCLU, alors que le rôle intégré « Virtual Machine
// Contributor » l'accorderait via `Microsoft.Compute/virtualMachines/*` :
//   `delete`, `deallocate/action`, `reimage/action`, `redeploy/action`,
//   `write`, `capture/action`, et surtout `runCommand/action` — qui donnerait
//   l'exécution de code arbitraire sur les runners trusted, machines qui
//   portent la fédération OIDC vers Azure et la seule accessibilité réseau au
//   stockage à private endpoint. Le rôle intégré est donc trop large : il
//   permettrait à l'identité de reprise de détruire exactement ce qu'elle est
//   censée restaurer.
//
// Aucun credential GitHub n'existe dans cette composition : ni PAT, ni clé de
// GitHub App. L'identité est assignée par le système et ne quitte jamais Azure.
// ============================================================================
targetScope = 'subscription'

@description('Resource group hébergeant les runners CI. Doit préexister.')
@minLength(1)
param resourceGroupName string = 'rg-certigo-ci'

@description('Instances exactes du VMSS Flexible à rallumer chaque matin.')
@minLength(1)
param virtualMachineNames array = [
  'vmss-certigo-runner-zonal_f55d176e'
  'vmss-certigo-runner-zonal_be505fa1'
  'vmss-certigo-pr-pilot-z1_bbf83c5c'
]

@description('Heure UTC du déclenchement. 01:30 UTC laisse ~41 min de marge après la fin de la fenêtre de teardown 00:46-00:49 UTC, sans course avec elle.')
@minValue(0)
@maxValue(23)
param scheduleHourUtc int = 1

@description('Minute UTC du déclenchement.')
@minValue(0)
@maxValue(59)
param scheduleMinuteUtc int = 30

@description('Destinataire des alertes. Injecté au déploiement depuis la variable non secrète ALERT_EMAIL.')
param alertEmail string = ''

@description('Région du Logic App de reprise.')
param location string = 'westeurope'

@description('Applique le verrou CanNotDelete sur le resource group. Contrôle structurel contre un déploiement en mode Complete.')
param deployResourceGroupDeletionLock bool = true

resource runnerResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

// Portée d'assignation réduite au seul resource group des runners : le rôle ne
// peut pas être assigné ailleurs, même par un futur opérateur distrait.
var assignableScopes = [
  subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroupName)
]

resource runnerRecoveryRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, 'certigo-ci-runner-recovery')
  properties: {
    roleName: 'Certigo CI Runner Recovery ${take(uniqueString(subscription().id), 6)}'
    description: 'Demarre et lit les VMs de runner CI de rg-certigo-ci. Aucune suppression, aucune deallocation, aucune execution de commande, aucun droit reseau.'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/start/action'
          'Microsoft.Compute/virtualMachines/instanceView/read'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: assignableScopes
  }
}

module recovery 'modules/runnerAutoRecovery.bicep' = {
  scope: runnerResourceGroup
  name: 'certigo-ci-runner-auto-recovery'
  params: {
    alertEmail: alertEmail
    location: location
    scheduleHourUtc: scheduleHourUtc
    scheduleMinuteUtc: scheduleMinuteUtc
    virtualMachineNames: virtualMachineNames
  }
}

// Primitive RBAC générique déjà utilisée par la gouvernance : dupliquer une
// primitive d'assignation de rôle créerait exactement la dérive que le dépôt
// cherche à supprimer.
module recoveryRoleAssignment '../governance/modules/resourceGroupRoleAssignment.bicep' = {
  scope: runnerResourceGroup
  name: 'certigo-ci-runner-auto-recovery-rbac'
  params: {
    assignmentNameSeed: 'certigo-ci-runner-recovery'
    assignmentDescription: 'Autorise le Logic App de reprise a demarrer et lire uniquement les VMs de runner CI.'
    principalId: recovery.outputs.principalId
    roleDefinitionId: runnerRecoveryRole.id
  }
}

module deletionLock 'modules/resourceGroupDeletionLock.bicep' = if (deployResourceGroupDeletionLock) {
  scope: runnerResourceGroup
  name: 'certigo-ci-deletion-lock'
  params: {}
}

output roleDefinitionId string = runnerRecoveryRole.id
output roleDefinitionName string = runnerRecoveryRole.properties.roleName
output workflowName string = recovery.outputs.workflowName
output workflowResourceId string = recovery.outputs.workflowResourceId
output recoveryPrincipalId string = recovery.outputs.principalId
output alertName string = recovery.outputs.alertName
