// ============================================================================
// Certigo — runners CI à la demande (côté Azure).
//
// Deux Logic Apps (Consumption), chacun avec sa propre identité et son propre rôle :
//
// 1. `logic-certigo-ci-runner-wake` — RÉVEIL. Déclenché par les webhooks `workflow_job` des
//    dépôts versionnés (`capacity-controller.config.json`, `repositories`). Pour un job
//    `queued` ou `waiting` dont les labels désignent un pool, il DÉMARRE toutes les instances
//    non exclues de ce pool qui sont `deallocated` ou `stopped`, en plusieurs passes espacées :
//    une VM dont l'OS était en train de s'arrêter, ou qu'une désallocation concurrente venait de
//    viser, est rattrapée à la passe suivante. Il échoue bruyamment si, à la fin, aucune instance
//    du pool n'est `running`/`starting`. Rôle : lire + démarrer, rien d'autre.
//
// 2. `logic-certigo-ci-runner-idle-deallocation` — DÉSALLOCATION. Toutes les 5 minutes (sauf
//    00:00-01:59 UTC : teardown MCAPS 00:46-00:49 et reprise 01:30), il désalloue les instances
//    non exclues dont le power state est EXACTEMENT `PowerState/stopped`, c'est-à-dire dont l'OS
//    s'est déjà arrêté de lui-même (`infra/ci-runner/idle-shutdown.sh`). Il ne juge JAMAIS
//    qu'une VM est inactive : une VM `running` n'est jamais touchée. Chaque instance est relue
//    juste avant la désallocation. Rôle : lire + désallouer, rien d'autre.
//
// Qui décide de l'inactivité ? La VM elle-même, là où l'état `busy` du runner est exact. Aucun
// credential GitHub (PAT, clé de GitHub App) n'entre dans Azure : GitHub POUSSE un événement,
// Azure ne lit jamais GitHub. Le déclencheur HTTP est authentifié par la signature SAS de son
// URL (jamais versionnée, jamais affichée) et restreint aux plages `hooks` publiées par GitHub.
// Le contenu d'un appel n'est pas une autorité : au pire il choisit quel pool est démarré, dans
// la limite des instances existantes, qui se rééteignent seules. Voir
// docs/adr/ADR-022-runners-ci-a-la-demande.md.
// ============================================================================
targetScope = 'resourceGroup'

@description('Pools de runners : `{ name: <scale set Flexible>, wakeLabels: [<labels runs-on qui réveillent ce pool>] }`.')
@minLength(1)
param pools array

@description('Instances à ne jamais démarrer ni désallouer : retirées, interdites ou externes. Comparaison insensible à la casse.')
param excludedVirtualMachineNames array = []

@description('Dépôts (`owner/name`) dont un webhook `workflow_job` peut réveiller un pool. Comparaison insensible à la casse.')
@minLength(1)
param repositories array

@description('Actions `workflow_job` qui réveillent un pool.')
@minLength(1)
param wakeActions array

@description('Attente, en secondes, après chaque passe de réveil. Une passe = relire le pool et démarrer ce qui est arrêté ; une passe par élément.')
@minLength(2)
param wakePassDelaysSeconds array

@description('Plages IPv4 autorisées à appeler le déclencheur HTTP : plages `hooks` publiées par GitHub.')
@minLength(1)
param allowedCallerAddressRanges array

@description('Heures UTC où la désallocation tourne. 0 et 1 sont exclues : teardown MCAPS 00:46-00:49 UTC et reprise 01:30 UTC, avec lesquels elle ne doit jamais courir.')
@minLength(1)
param deallocationHoursUtc array = range(2, 22)

@description('Minutes de chaque heure où la désallocation tourne.')
@minLength(1)
param deallocationMinutes array = [ 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55 ]

@description('Nom du Logic App de réveil.')
@minLength(1)
param wakeWorkflowName string = 'logic-certigo-ci-runner-wake'

@description('Nom du Logic App de désallocation.')
@minLength(1)
param deallocationWorkflowName string = 'logic-certigo-ci-runner-idle-deallocation'

@description('Action group existant qui reçoit les alertes (celui de la reprise automatique).')
@minLength(1)
param actionGroupName string = 'ag-certigo-ci-recovery'

@description('Région Azure des Logic Apps.')
param location string = resourceGroup().location

@description('Version d\'API du plan de contrôle Compute utilisée par les appels ARM des workflows.')
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

var armEndpoint = environment().resourceManager
var vmCollectionUri = '${armEndpoint}subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/virtualMachines'
// Aucun secret : jeton ARM obtenu via l'identité managée assignée par le système.
var managedIdentityAuthentication = {
  type: 'ManagedServiceIdentity'
  audience: armEndpoint
}
var readRetryPolicy = {
  type: 'fixed'
  count: 3
  interval: 'PT15S'
}
var excludedNamesParameter = 'excludedVirtualMachineNames'
var triggerName = 'GitHub_workflow_job_webhook'
var requestedLabelsAction = 'Select_the_requested_labels'
// Tableau vide littéral : `createArray()` sans argument est refusé par le moteur Logic Apps
// (mesuré sur la reprise le 2026-09-23, voir runnerAutoRecovery.bicep).
var emptyArray = 'json(\'[]\')'
var statusesOfItem = 'string(coalesce(item()?[\'properties\']?[\'instanceView\']?[\'statuses\'], ${emptyArray}))'
var isNotExcluded = 'not(contains(parameters(\'${excludedNamesParameter}\'), toLower(item()?[\'name\'])))'
// Aucun code de power state n'est le préfixe d'un autre (`stopped`/`stopping`,
// `deallocated`/`deallocating`, `running`, `starting`) : la recherche de sous-chaîne est exacte.
var isPoweredOff = 'or(contains(${statusesOfItem}, \'PowerState/deallocated\'), contains(${statusesOfItem}, \'PowerState/stopped\'))'
var isAwake = 'or(contains(${statusesOfItem}, \'PowerState/running\'), contains(${statusesOfItem}, \'PowerState/starting\'))'
var isOsStopped = 'contains(${statusesOfItem}, \'PowerState/stopped\')'

// Le `$filter` sur `virtualMachineScaleSet/id` et `$expand=instanceView` sont ceux de la reprise :
// un seul appel rend les membres ET leur power state, sous le seul droit `virtualMachines/read`.
var poolDefinitions = map(pools, pool => {
  name: pool.name
  key: replace(pool.name, '-', '_')
  wakeLabels: map(pool.wakeLabels, label => toLower(string(label)))
  listUri: '${vmCollectionUri}?api-version=${computeApiVersion}&$filter=${uriComponent('\'virtualMachineScaleSet/id\' eq \'${resourceId('Microsoft.Compute/virtualMachineScaleSets', pool.name)}\'')}&$expand=instanceView'
})
var passNumbers = range(1, length(wakePassDelaysSeconds))

// ---------------------------------------------------------------------------
// Réveil
// ---------------------------------------------------------------------------
// Seule une livraison `workflow_job` porte `workflow_job.labels` : le `ping` de création du
// webhook, ou tout autre corps, ne désigne aucun pool. L'en-tête `X-GitHub-Event` n'est pas lu :
// sa casse, une fois reçu par Logic Apps, n'est pas une garantie sur laquelle faire reposer le réveil.
var deliveredAction = '@contains(parameters(\'wakeActions\'), toLower(string(coalesce(triggerBody()?[\'action\'], \'\'))))'
var deliveredRepository = '@contains(parameters(\'repositories\'), toLower(string(coalesce(triggerBody()?[\'repository\']?[\'full_name\'], \'\'))))'

var wakePools = map(poolDefinitions, pool => {
  name: pool.name
  key: pool.key
  wakeLabels: pool.wakeLabels
  gate: 'Wake_${pool.key}_when_requested'
  relist: 'Relist_the_instances_of_${pool.key}_after_waking'
  awake: 'Select_the_awake_instances_of_${pool.key}'
  assertion: 'Assert_${pool.key}_has_an_awake_instance'
  passes: map(passNumbers, pass => {
    number: pass
    list: 'List_the_instances_of_${pool.key}_pass_${pass}'
    select: 'Select_the_instances_to_wake_in_${pool.key}_pass_${pass}'
    loop: 'Start_the_instances_of_${pool.key}_pass_${pass}'
    start: 'Start_an_instance_of_${pool.key}_pass_${pass}'
    wait: 'Wait_after_pass_${pass}_of_${pool.key}'
    delaySeconds: wakePassDelaysSeconds[pass - 1]
    previousWait: pass == 1 ? '' : 'Wait_after_pass_${pass - 1}_of_${pool.key}'
  })
  lastWait: 'Wait_after_pass_${length(wakePassDelaysSeconds)}_of_${pool.key}'
  listUri: pool.listUri
})

// Chaque passe est tolérante : une liste ou un démarrage en échec n'arrête pas les passes
// suivantes. Seul le constat final décide du succès du run.
var passActionsByPool = map(wakePools, pool => reduce(pool.passes, {}, (actions, pass) => union(actions, {
  '${pass.list}': {
    type: 'Http'
    runAfter: pass.number == 1 ? {} : {
      '${pass.previousWait}': [ 'Succeeded' ]
    }
    inputs: {
      method: 'GET'
      uri: pool.listUri
      authentication: managedIdentityAuthentication
      retryPolicy: readRetryPolicy
    }
  }
  '${pass.select}': {
    type: 'Query'
    runAfter: {
      '${pass.list}': [ 'Succeeded' ]
    }
    inputs: {
      from: '@coalesce(body(\'${pass.list}\')?[\'value\'], ${emptyArray})'
      where: '@and(${isNotExcluded}, ${isPoweredOff})'
    }
  }
  '${pass.loop}': {
    type: 'Foreach'
    foreach: '@body(\'${pass.select}\')'
    runAfter: {
      '${pass.select}': [ 'Succeeded' ]
    }
    runtimeConfiguration: {
      concurrency: {
        repetitions: 20
      }
    }
    actions: {
      '${pass.start}': {
        type: 'Http'
        runAfter: {}
        // `start` rend 202 puis continue côté Azure : attendre ici retarderait les passes
        // suivantes sans rien prouver, puisque le constat final relit le power state.
        operationOptions: 'DisableAsyncPattern'
        inputs: {
          method: 'POST'
          uri: '${vmCollectionUri}/@{encodeUriComponent(items(\'${pass.loop}\')?[\'name\'])}/start?api-version=${computeApiVersion}'
          authentication: managedIdentityAuthentication
          retryPolicy: {
            type: 'fixed'
            count: 2
            interval: 'PT15S'
          }
        }
      }
    }
  }
  '${pass.wait}': {
    type: 'Wait'
    runAfter: {
      '${pass.loop}': [ 'Succeeded', 'Failed', 'TimedOut', 'Skipped' ]
    }
    inputs: {
      interval: {
        count: pass.delaySeconds
        unit: 'Second'
      }
    }
  }
})))

var wakeGates = toObject(
  range(0, length(wakePools)),
  index => wakePools[index].gate,
  index => {
    type: 'If'
    runAfter: {
      '${requestedLabelsAction}': [ 'Succeeded' ]
    }
    expression: {
      and: [
        {
          equals: [
            deliveredAction
            true
          ]
        }
        {
          equals: [
            deliveredRepository
            true
          ]
        }
        {
          greater: [
            '@length(intersection(body(\'${requestedLabelsAction}\'), parameters(\'wakeLabelsByPool\')?[\'${wakePools[index].name}\']))'
            0
          ]
        }
      ]
    }
    actions: union(passActionsByPool[index], {
      '${wakePools[index].relist}': {
        type: 'Http'
        runAfter: {
          '${wakePools[index].lastWait}': [ 'Succeeded' ]
        }
        inputs: {
          method: 'GET'
          uri: wakePools[index].listUri
          authentication: managedIdentityAuthentication
          retryPolicy: readRetryPolicy
        }
      }
      '${wakePools[index].awake}': {
        type: 'Query'
        runAfter: {
          '${wakePools[index].relist}': [ 'Succeeded' ]
        }
        inputs: {
          from: '@coalesce(body(\'${wakePools[index].relist}\')?[\'value\'], ${emptyArray})'
          where: '@and(${isNotExcluded}, ${isAwake})'
        }
      }
      '${wakePools[index].assertion}': {
        type: 'If'
        runAfter: {
          '${wakePools[index].awake}': [ 'Succeeded' ]
        }
        expression: {
          and: [
            {
              greaterOrEquals: [
                '@length(body(\'${wakePools[index].awake}\'))'
                1
              ]
            }
          ]
        }
        actions: {}
        else: {
          actions: {
            'Fail_the_run_when_${wakePools[index].key}_stays_asleep': {
              type: 'Terminate'
              runAfter: {}
              inputs: {
                runStatus: 'Failed'
                runError: {
                  code: 'RunnerWakeFailed'
                  message: 'Aucune instance non exclue de ${wakePools[index].name} n\'est running ou starting apres les passes de reveil : le job en file attendra le prochain evenement ou la reprise de 01:30 UTC. Voir docs/runbooks/CI_RUNNERS.md section 13.'
                }
              }
            }
          }
        }
      }
    })
    else: {
      actions: {}
    }
  }
)

var wakeActionsDefinition = union(wakeGates, {
  '${requestedLabelsAction}': {
    type: 'Select'
    runAfter: {}
    inputs: {
      from: '@coalesce(triggerBody()?[\'workflow_job\']?[\'labels\'], ${emptyArray})'
      select: '@toLower(string(item()))'
    }
  }
})

resource wakeWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: wakeWorkflowName
  location: location
  tags: effectiveTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    accessControl: {
      triggers: {
        allowedCallerIpAddresses: map(allowedCallerAddressRanges, range => {
          addressRange: range
        })
      }
    }
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '${excludedNamesParameter}': {
          type: 'Array'
          defaultValue: map(excludedVirtualMachineNames, name => toLower(string(name)))
        }
        repositories: {
          type: 'Array'
          defaultValue: map(repositories, repository => toLower(string(repository)))
        }
        wakeActions: {
          type: 'Array'
          defaultValue: map(wakeActions, action => toLower(string(action)))
        }
        wakeLabelsByPool: {
          type: 'Object'
          defaultValue: toObject(poolDefinitions, pool => pool.name, pool => pool.wakeLabels)
        }
      }
      triggers: {
        '${triggerName}': {
          type: 'Request'
          kind: 'Http'
          inputs: {
            method: 'POST'
          }
        }
      }
      actions: wakeActionsDefinition
      outputs: {}
    }
  }
}

// ---------------------------------------------------------------------------
// Désallocation des VM dont l'OS s'est arrêté
// ---------------------------------------------------------------------------
var deallocationPools = map(poolDefinitions, pool => {
  name: pool.name
  listUri: pool.listUri
  list: 'List_the_instances_of_${pool.key}'
  select: 'Select_the_stopped_instances_of_${pool.key}'
  loop: 'Deallocate_the_stopped_instances_of_${pool.key}'
  reread: 'Reread_a_stopped_instance_of_${pool.key}'
  gate: 'Deallocate_if_the_instance_of_${pool.key}_is_still_stopped'
  deallocate: 'Deallocate_an_instance_of_${pool.key}'
})

var deallocationActions = reduce(deallocationPools, {}, (actions, pool) => union(actions, {
  '${pool.list}': {
    type: 'Http'
    runAfter: {}
    inputs: {
      method: 'GET'
      uri: pool.listUri
      authentication: managedIdentityAuthentication
      retryPolicy: readRetryPolicy
    }
  }
  '${pool.select}': {
    type: 'Query'
    runAfter: {
      '${pool.list}': [ 'Succeeded' ]
    }
    inputs: {
      from: '@coalesce(body(\'${pool.list}\')?[\'value\'], ${emptyArray})'
      where: '@and(${isNotExcluded}, ${isOsStopped})'
    }
  }
  '${pool.loop}': {
    type: 'Foreach'
    foreach: '@body(\'${pool.select}\')'
    runAfter: {
      '${pool.select}': [ 'Succeeded' ]
    }
    runtimeConfiguration: {
      concurrency: {
        repetitions: 5
      }
    }
    actions: {
      // Relecture immédiate : une instance qu'un réveil vient de démarrer n'est plus `stopped`.
      '${pool.reread}': {
        type: 'Http'
        runAfter: {}
        inputs: {
          method: 'GET'
          uri: '${vmCollectionUri}/@{encodeUriComponent(items(\'${pool.loop}\')?[\'name\'])}?api-version=${computeApiVersion}&$expand=instanceView'
          authentication: managedIdentityAuthentication
          retryPolicy: readRetryPolicy
        }
      }
      '${pool.gate}': {
        type: 'If'
        runAfter: {
          '${pool.reread}': [ 'Succeeded' ]
        }
        expression: {
          and: [
            {
              equals: [
                '@contains(string(coalesce(body(\'${pool.reread}\')?[\'properties\']?[\'instanceView\']?[\'statuses\'], ${emptyArray})), \'PowerState/stopped\')'
                true
              ]
            }
          ]
        }
        actions: {
          '${pool.deallocate}': {
            type: 'Http'
            runAfter: {}
            inputs: {
              method: 'POST'
              uri: '${vmCollectionUri}/@{encodeUriComponent(items(\'${pool.loop}\')?[\'name\'])}/deallocate?api-version=${computeApiVersion}'
              authentication: managedIdentityAuthentication
            }
          }
        }
        else: {
          actions: {}
        }
      }
    }
  }
}))

resource deallocationWorkflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: deallocationWorkflowName
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
      parameters: {
        '${excludedNamesParameter}': {
          type: 'Array'
          defaultValue: map(excludedVirtualMachineNames, name => toLower(string(name)))
        }
      }
      triggers: {
        Every_five_minutes_outside_the_nightly_windows: {
          type: 'Recurrence'
          recurrence: {
            frequency: 'Day'
            interval: 1
            timeZone: 'UTC'
            schedule: {
              hours: deallocationHoursUtc
              minutes: deallocationMinutes
            }
          }
          runtimeConfiguration: {
            concurrency: {
              runs: 1
            }
          }
        }
      }
      actions: deallocationActions
      outputs: {}
    }
  }
}

// ---------------------------------------------------------------------------
// Visibilité des échecs : mêmes destinataires que la reprise automatique.
// ---------------------------------------------------------------------------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' existing = {
  name: actionGroupName
}

resource wakeFailureAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-certigo-ci-runner-wake-failed'
  location: 'global'
  tags: effectiveTags
  properties: {
    description: 'Le reveil a la demande des runners CI a echoue : un job en file peut attendre le prochain evenement ou la reprise de 01:30 UTC.'
    severity: 1
    enabled: true
    scopes: [
      wakeWorkflow.id
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

// Seuil 3 sur une heure (12 runs) : une course isolée avec un réveil (409 sur une instance
// que le réveil démarre au même instant) ne doit pas alerter ; une désallocation durablement
// refusée, elle, échoue à chaque run où une VM est arrêtée.
resource deallocationFailureAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-certigo-ci-runner-idle-deallocation-failed'
  location: 'global'
  tags: effectiveTags
  properties: {
    description: 'La desallocation des runners CI arretes echoue de facon repetee : des VM arretees restent allouees et facturees.'
    severity: 2
    enabled: true
    scopes: [
      deallocationWorkflow.id
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
          threshold: 3
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

output wakeWorkflowName string = wakeWorkflow.name
output wakeWorkflowResourceId string = wakeWorkflow.id
output wakeTriggerName string = triggerName
@description('Identité du réveil : reçoit le rôle lire + démarrer, jamais un credential.')
output wakePrincipalId string = wakeWorkflow.identity.principalId
output deallocationWorkflowName string = deallocationWorkflow.name
output deallocationWorkflowResourceId string = deallocationWorkflow.id
@description('Identité de la désallocation : reçoit le rôle lire + désallouer, jamais un credential.')
output deallocationPrincipalId string = deallocationWorkflow.identity.principalId
output alertNames array = [
  wakeFailureAlert.name
  deallocationFailureAlert.name
]
