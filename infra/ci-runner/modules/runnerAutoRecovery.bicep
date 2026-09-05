// ============================================================================
// Certigo — reprise automatique des runners CI (côté Azure)
//
// `MCAPSGovernance-AutomationApp` désalloue toutes les VMs de `rg-certigo-ci`
// chaque nuit vers 00:46–00:49 UTC depuis un management group sur lequel le
// projet n'a ni autorité ni visibilité. La déallocation est donc traitée comme
// PERMANENTE : ce module construit une REPRISE, jamais une prévention.
//
// Un Logic App (Consumption) déclenché quotidiennement à 01:30 UTC — soit
// ~41 minutes après la fin de la fenêtre de teardown, donc sans course avec
// elle — démarre les instances énumérées puis VÉRIFIE que chacune atteint
// `PowerState/running`. Si une seule ne l'atteint pas, le run se termine en
// `Failed`, ce qui alimente la métrique `RunsFailed` et déclenche l'alerte.
//
// PÉRIMÈTRE DE PREUVE — limite volontaire et documentée :
// ce module prouve UNIQUEMENT le power state Azure. Il ne prouve RIEN sur
// l'état `online` des runners GitHub. La panne du 1er septembre 2026 s'est
// justement présentée comme « VM running / runner absent ». La vérification
// côté GitHub reste dans `runner-health.yml` et le prévol opérateur, par
// décision explicite : aucun credential GitHub (PAT ou clé de GitHub App)
// n'est introduit dans Azure.
//
// La définition du workflow est intégralement inline : l'IaC est la source de
// vérité, sans artefact de code hébergé hors du dépôt.
// ============================================================================
targetScope = 'resourceGroup'

@description('Instances exactes du VMSS Flexible à rallumer. En orchestration Flexible chaque instance est adressable comme une VM Microsoft.Compute/virtualMachines à part entière.')
@minLength(1)
param virtualMachineNames array

@description('Heure UTC du déclenchement quotidien. Doit rester strictement postérieure à la fenêtre de teardown 00:46-00:49 UTC.')
@minValue(0)
@maxValue(23)
param scheduleHourUtc int = 1

@description('Minute UTC du déclenchement quotidien.')
@minValue(0)
@maxValue(59)
param scheduleMinuteUtc int = 30

@description('Délai laissé au plan de contrôle Compute pour publier le power state définitif avant vérification.')
@minValue(15)
@maxValue(300)
param powerStateSettleSeconds int = 30

@description('Nom du Logic App de reprise.')
@minLength(1)
param workflowName string = 'logic-certigo-ci-runner-recovery'

@description('Destinataire des alertes d\'échec de reprise. Vide = aucun destinataire e-mail, l\'alerte restant visible dans Azure Monitor. Injecté au déploiement depuis la variable non secrète ALERT_EMAIL, comme les autres alertes du dépôt.')
param alertEmail string = ''

@description('Région Azure du Logic App.')
param location string = resourceGroup().location

@description('Version d\'API du plan de contrôle Compute utilisée par les appels ARM du workflow.')
@minLength(1)
param computeApiVersion string = '2024-07-01'

@description('Tags additionnels préservés lors de l\'application du contrat FinOps obligatoire.')
param tags object = {}

@description('Équipe ou service propriétaire. Jamais une identité personnelle.')
@minLength(1)
param tagOwner string = 'certigo-platform'

@description('Produit dans le contrat FinOps.')
@allowed([ 'Certigo' ])
param tagProduct string = 'Certigo'

@description('Environnement dans le contrat FinOps.')
@allowed([ 'ci' ])
param tagEnvironment string = 'ci'

@description('Propriétaire déclaratif de la ressource.')
@allowed([ 'bicep' ])
param tagManagedBy string = 'bicep'

@description('Identifiant d\'allocation de coût non personnel.')
@minLength(1)
param tagCostCenter string = 'engineering'

var requiredTags = {
  owner: tagOwner
  product: tagProduct
  env: tagEnvironment
  managedBy: tagManagedBy
  costCenter: tagCostCenter
}
var effectiveTags = union(tags, requiredTags)

// `environment()` évite de coder en dur l'endpoint d'un cloud souverain.
var armEndpoint = environment().resourceManager
var vmResourcePrefix = '${armEndpoint}subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/virtualMachines'
var settleActionName = 'Wait_for_the_power_state_to_settle'

// Les noms d'action Logic Apps n'acceptent pas le tiret des noms d'instance VMSS.
// Aucune boucle Foreach/Until n'est utilisée : le graphe est déplié, donc un
// relecteur voit exactement quelles ressources sont touchées, et `Terminate`
// reste au niveau supérieur où il est sans ambiguïté supporté.
var startActions = toObject(
  virtualMachineNames,
  name => 'Start_${replace(name, '-', '_')}',
  name => {
    type: 'Http'
    runAfter: {}
    inputs: {
      method: 'POST'
      uri: '${vmResourcePrefix}/${name}/start?api-version=${computeApiVersion}'
      // Aucun secret : jeton ARM obtenu via l'identité managée assignée par le système.
      authentication: {
        type: 'ManagedServiceIdentity'
        audience: armEndpoint
      }
      retryPolicy: {
        type: 'fixed'
        count: 3
        interval: 'PT1M'
      }
    }
  }
)

// Un démarrage en échec laisse l'action en `Failed`, donc le run échoue de
// lui-même sans dépendre de la vérification de power state qui suit.
var settleRunAfter = toObject(
  virtualMachineNames,
  name => 'Start_${replace(name, '-', '_')}',
  name => [ 'Succeeded' ]
)

var verifyActions = toObject(
  virtualMachineNames,
  name => 'Verify_${replace(name, '-', '_')}',
  name => {
    type: 'Http'
    runAfter: {
      '${settleActionName}': [ 'Succeeded' ]
    }
    inputs: {
      method: 'GET'
      uri: '${vmResourcePrefix}/${name}/instanceView?api-version=${computeApiVersion}'
      authentication: {
        type: 'ManagedServiceIdentity'
        audience: armEndpoint
      }
      retryPolicy: {
        type: 'fixed'
        count: 3
        interval: 'PT30S'
      }
    }
  }
)

var assertRunAfter = toObject(
  virtualMachineNames,
  name => 'Verify_${replace(name, '-', '_')}',
  name => [ 'Succeeded' ]
)

// `PowerState/running` n'est le préfixe d'aucun autre code de power state
// (`starting`, `stopped`, `deallocated`) : la recherche de sous-chaîne est donc
// non ambiguë.
var runningConditions = map(
  virtualMachineNames,
  name => {
    equals: [
      '@contains(string(coalesce(body(\'Verify_${replace(name, '-', '_')}\')?[\'statuses\'], createArray())), \'PowerState/running\')'
      true
    ]
  }
)

var workflowActions = union(startActions, verifyActions, {
  '${settleActionName}': {
    type: 'Wait'
    runAfter: settleRunAfter
    inputs: {
      interval: {
        count: powerStateSettleSeconds
        unit: 'Second'
      }
    }
  }
  Assert_every_runner_reached_a_running_power_state: {
    type: 'If'
    runAfter: assertRunAfter
    expression: {
      and: runningConditions
    }
    actions: {}
    else: {
      actions: {
        Fail_the_run_when_a_runner_is_not_running: {
          type: 'Terminate'
          runAfter: {}
          inputs: {
            runStatus: 'Failed'
            runError: {
              code: 'RunnerPowerStateNotRunning'
              message: 'Au moins une instance de runner CI n\'a pas atteint PowerState/running apres la reprise quotidienne. Consulter l\'historique du Logic App puis docs/runbooks/CI_RUNNERS.md section 7.'
            }
          }
        }
      }
    }
  }
})

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: workflowName
  location: location
  tags: effectiveTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        Daily_after_the_governance_teardown_window: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Day'
            interval: 1
            timeZone: 'UTC'
            schedule: {
              hours: [ string(scheduleHourUtc) ]
              minutes: [ scheduleMinuteUtc ]
            }
          }
        }
      }
      actions: workflowActions
      outputs: {}
    }
  }
}

// ---------------------------------------------------------------------------
// Visibilité de l'échec. Une reprise non surveillée n'est pas une reprise :
// l'échec doit atterrir là où un humain le voit, pas seulement dans un
// historique de run que personne n'ouvre.
// ---------------------------------------------------------------------------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-certigo-ci-recovery'
  location: 'global'
  tags: effectiveTags
  properties: {
    groupShortName: 'ciRecovery'
    enabled: true
    emailReceivers: empty(alertEmail) ? [] : [
      {
        name: 'ciops'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource recoveryFailureAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-certigo-ci-runner-recovery-failed'
  location: 'global'
  tags: effectiveTags
  properties: {
    description: 'La reprise automatique des runners CI a echoue : demarrage refuse, ou au moins une instance n\'a pas atteint un power state running.'
    severity: 1
    enabled: true
    scopes: [
      workflow.id
    ]
    targetResourceType: 'Microsoft.Logic/workflows'
    targetResourceRegion: location
    evaluationFrequency: 'PT15M'
    windowSize: 'PT1H'
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'RunsFailed'
          criterionType: 'StaticThresholdCriterion'
          metricNamespace: 'Microsoft.Logic/workflows'
          metricName: 'RunsFailed'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Total'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

output workflowName string = workflow.name
output workflowResourceId string = workflow.id
@description('Identité managée assignée par le système : c\'est elle qui reçoit le rôle personnalisé restreint, jamais un credential.')
output principalId string = workflow.identity.principalId
output actionGroupId string = actionGroup.id
output alertName string = recoveryFailureAlert.name
