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
// elle — ÉNUMÈRE à chaque run les instances des scale sets de runners, démarre
// toutes celles qui ne sont pas exclues, puis VÉRIFIE que chacune atteint
// `PowerState/running` et que chaque pool garde son plancher de redondance.
// Au moindre écart, le run se termine en `Failed`, ce qui alimente la métrique
// `RunsFailed` et déclenche l'alerte.
//
// ÉNUMÉRATION DYNAMIQUE — pourquoi aucune liste d'instances n'est figée ici :
// du 2026-09-12 au 2026-09-23, la liste figée visait deux instances mortes et
// ignorait les quatre instances PR de remplacement ; la CI PR restait éteinte
// chaque matin. Une instance est désormais retenue parce qu'elle APPARTIENT à
// un scale set (`properties.virtualMachineScaleSet.id`, filtré côté ARM), pas
// parce qu'un opérateur a pensé à recopier son nom. Seule la liste d'exclusion
// (instances retirées ou externes) reste versionnée : une entrée périmée y est
// inoffensive, et une entrée manquante fait échouer le run bruyamment sans
// empêcher le démarrage des autres instances.
//
// Chaque pool est traité indépendamment jusqu'à la vérification : l'échec de
// l'énumération d'un pool n'empêche pas de rallumer l'autre.
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

@description('Scale sets Flexible dont chaque instance est rallumée, avec le nombre minimal d\'instances `PowerState/running` exigé par pool après la reprise. Entrées : `{ name: string, minimumRunning: int >= 1 }`. En orchestration Flexible chaque instance est adressable comme une VM Microsoft.Compute/virtualMachines à part entière.')
@minLength(1)
param scaleSets array

@description('Instances à ne jamais démarrer ni compter : retirées, interdites ou externes. Comparaison insensible à la casse. Toute autre instance d\'un scale set de `scaleSets` est démarrée.')
param excludedVirtualMachineNames array = []

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
var vmCollectionUri = '${armEndpoint}subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Compute/virtualMachines'
var settleActionName = 'Wait_for_the_power_state_to_settle'
var notRunningAction = 'Select_the_instances_not_running'
var notRunningNamesAction = 'Name_the_instances_not_running'
var excludedNamesParameter = 'excludedVirtualMachineNames'
// Aucun secret : jeton ARM obtenu via l'identité managée assignée par le système.
var managedIdentityAuthentication = {
  type: 'ManagedServiceIdentity'
  audience: armEndpoint
}
var listRetryPolicy = {
  type: 'fixed'
  count: 3
  interval: 'PT30S'
}

// Les noms d'action Logic Apps n'acceptent pas le tiret des noms de scale set.
// Le `$filter` sur `virtualMachineScaleSet/id` est évalué par ARM sans tenir compte de la
// casse (la référence de certaines instances porte `RG-CERTIGO-CI`) ; le nom de propriété
// doit être entre apostrophes, sinon ARM rend `The request URL is not valid`, et
// `$expand=instanceView` n'est accepté qu'avec ce filtre. Un seul appel rend ainsi les
// membres ET leur power state, sous le seul droit `virtualMachines/read`.
var pools = map(scaleSets, scaleSet => {
  name: scaleSet.name
  minimumRunning: scaleSet.minimumRunning
  listAction: 'List_the_instances_of_${replace(scaleSet.name, '-', '_')}'
  selectAction: 'Select_the_instances_to_start_in_${replace(scaleSet.name, '-', '_')}'
  startLoop: 'Start_each_instance_of_${replace(scaleSet.name, '-', '_')}'
  startAction: 'Start_an_instance_of_${replace(scaleSet.name, '-', '_')}'
  relistAction: 'Relist_the_instances_of_${replace(scaleSet.name, '-', '_')}'
  runningAction: 'Select_the_running_instances_of_${replace(scaleSet.name, '-', '_')}'
  listUri: '${vmCollectionUri}?api-version=${computeApiVersion}&$filter=${uriComponent('\'virtualMachineScaleSet/id\' eq \'${resourceId('Microsoft.Compute/virtualMachineScaleSets', scaleSet.name)}\'')}&$expand=instanceView'
})

// Les exclusions sont comparées en minuscules des deux côtés.
var isNotExcluded = 'not(contains(parameters(\'${excludedNamesParameter}\'), toLower(item()?[\'name\'])))'
// Tableau vide littéral. `createArray()` sans argument est REFUSÉ par le moteur Logic Apps
// (`InvalidTemplate ... 'createArray' expects a comma separated list of parameters`), mais
// seulement quand il est réellement évalué : caché derrière un `coalesce` dont le premier
// argument est non nul, il passe inaperçu. Mesuré sur le run
// 08584114192689525938465393788CU124 du 2026-09-23.
var emptyArray = 'json(\'[]\')'
// `PowerState/running` n'est le préfixe d'aucun autre code de power state
// (`starting`, `stopped`, `deallocated`) : la recherche de sous-chaîne est donc
// non ambiguë.
var isRunning = 'contains(string(coalesce(item()?[\'properties\']?[\'instanceView\']?[\'statuses\'], ${emptyArray})), \'PowerState/running\')'

var listActions = toObject(
  pools,
  pool => pool.listAction,
  pool => {
    type: 'Http'
    runAfter: {}
    inputs: {
      method: 'GET'
      uri: pool.listUri
      authentication: managedIdentityAuthentication
      retryPolicy: listRetryPolicy
    }
  }
)

var selectActions = toObject(
  pools,
  pool => pool.selectAction,
  pool => {
    type: 'Query'
    runAfter: {
      '${pool.listAction}': [ 'Succeeded' ]
    }
    inputs: {
      from: '@coalesce(body(\'${pool.listAction}\')?[\'value\'], ${emptyArray})'
      where: '@${isNotExcluded}'
    }
  }
)

// Démarrer est idempotent et sans effet sur une VM déjà sous tension. Les itérations
// sont indépendantes : une instance cassée n'empêche pas les autres de démarrer.
// `Terminate` n'est jamais placé dans une boucle : il reste au niveau supérieur, où il
// est sans ambiguïté supporté.
var startLoops = toObject(
  pools,
  pool => pool.startLoop,
  pool => {
    type: 'Foreach'
    foreach: '@body(\'${pool.selectAction}\')'
    runAfter: {
      '${pool.selectAction}': [ 'Succeeded' ]
    }
    runtimeConfiguration: {
      concurrency: {
        repetitions: 20
      }
    }
    actions: {
      '${pool.startAction}': {
        type: 'Http'
        runAfter: {}
        inputs: {
          method: 'POST'
          uri: '${vmCollectionUri}/@{encodeUriComponent(items(\'${pool.startLoop}\')?[\'name\'])}/start?api-version=${computeApiVersion}'
          authentication: managedIdentityAuthentication
          retryPolicy: {
            type: 'fixed'
            count: 3
            interval: 'PT1M'
          }
        }
      }
    }
  }
)

// Un démarrage en échec, ou un pool dont l'énumération a échoué, ne doit pas empêcher de
// vérifier les autres pools : leur échec est rattrapé plus bas, par la re-lecture, le
// power state et le plancher par pool, qui terminent alors le run en `Failed`.
var settleRunAfter = toObject(
  pools,
  pool => pool.startLoop,
  pool => [ 'Succeeded', 'Failed', 'TimedOut', 'Skipped' ]
)

var relistActions = toObject(
  pools,
  pool => pool.relistAction,
  pool => {
    type: 'Http'
    runAfter: {
      '${settleActionName}': [ 'Succeeded' ]
    }
    inputs: {
      method: 'GET'
      uri: pool.listUri
      authentication: managedIdentityAuthentication
      retryPolicy: listRetryPolicy
    }
  }
)

var runningActions = toObject(
  pools,
  pool => pool.runningAction,
  pool => {
    type: 'Query'
    runAfter: {
      '${pool.relistAction}': [ 'Succeeded' ]
    }
    inputs: {
      from: '@coalesce(body(\'${pool.relistAction}\')?[\'value\'], ${emptyArray})'
      where: '@and(${isNotExcluded}, ${isRunning})'
    }
  }
)

// `union` exige au moins deux collections : le tableau vide final couvre le cas d'un
// scale set unique.
var relistedInstances = '@union(${join(map(pools, pool => 'coalesce(body(\'${pool.relistAction}\')?[\'value\'], ${emptyArray})'), ', ')}, ${emptyArray})'

// Un `nextLink` signifierait des instances hors de la première page, donc ni démarrées ni
// vérifiées : le run échoue plutôt que de conclure sur une liste tronquée. Le `coalesce`
// vers une chaîne vide évite de dépendre du traitement de `empty(null)`.
var enumerationCompleteConditions = flatten(map(pools, pool => [
  {
    equals: [
      '@empty(coalesce(body(\'${pool.listAction}\')?[\'nextLink\'], \'\'))'
      true
    ]
  }
  {
    equals: [
      '@empty(coalesce(body(\'${pool.relistAction}\')?[\'nextLink\'], \'\'))'
      true
    ]
  }
]))

// Sans plancher, une liste d'exclusion trop large ou un scale set vide rendraient la
// vérification vide, donc vraie : c'est l'échec silencieux que ce module existe pour empêcher.
var floorConditions = map(pools, pool => {
  greaterOrEquals: [
    '@length(body(\'${pool.runningAction}\'))'
    pool.minimumRunning
  ]
})

var floorReport = join(
  map(
    pools,
    pool => '\'${pool.name} : \', string(length(body(\'${pool.runningAction}\'))), \' running pour un minimum de ${pool.minimumRunning}. \''
  ),
  ', '
)

var assertionRunAfter = union(
  toObject(pools, pool => pool.runningAction, pool => [ 'Succeeded' ]),
  {
    '${notRunningNamesAction}': [ 'Succeeded' ]
  }
)

var workflowActions = union(listActions, selectActions, startLoops, relistActions, runningActions, {
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
  '${notRunningAction}': {
    type: 'Query'
    runAfter: toObject(pools, pool => pool.relistAction, pool => [ 'Succeeded' ])
    inputs: {
      from: relistedInstances
      where: '@and(${isNotExcluded}, not(${isRunning}))'
    }
  }
  '${notRunningNamesAction}': {
    type: 'Select'
    runAfter: {
      '${notRunningAction}': [ 'Succeeded' ]
    }
    inputs: {
      from: '@body(\'${notRunningAction}\')'
      select: '@item()?[\'name\']'
    }
  }
  Assert_the_enumeration_is_complete: {
    type: 'If'
    runAfter: assertionRunAfter
    expression: {
      and: enumerationCompleteConditions
    }
    actions: {}
    else: {
      actions: {
        Fail_the_run_when_the_enumeration_is_incomplete: {
          type: 'Terminate'
          runAfter: {}
          inputs: {
            runStatus: 'Failed'
            runError: {
              code: 'RunnerEnumerationIncomplete'
              message: 'ARM a pagine la liste des instances d\'un scale set de runners : les instances hors de la premiere page n\'ont ete ni demarrees ni verifiees. Voir docs/runbooks/CI_RUNNERS.md section 11.'
            }
          }
        }
      }
    }
  }
  Assert_every_runner_reached_a_running_power_state: {
    type: 'If'
    runAfter: {
      Assert_the_enumeration_is_complete: [ 'Succeeded' ]
    }
    expression: {
      and: [
        {
          equals: [
            '@length(body(\'${notRunningAction}\'))'
            0
          ]
        }
      ]
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
              message: '@{concat(\'Instances de runner CI sans PowerState/running apres la reprise quotidienne : \', join(body(\'${notRunningNamesAction}\'), \', \'), \'. Une instance retiree doit figurer dans inventory.forbiddenVirtualMachines. Voir docs/runbooks/CI_RUNNERS.md sections 7 et 11.\')}'
            }
          }
        }
      }
    }
  }
  Assert_each_pool_kept_its_redundancy_floor: {
    type: 'If'
    runAfter: {
      Assert_every_runner_reached_a_running_power_state: [ 'Succeeded' ]
    }
    expression: {
      and: floorConditions
    }
    actions: {}
    else: {
      actions: {
        Fail_the_run_when_a_pool_is_below_its_floor: {
          type: 'Terminate'
          runAfter: {}
          inputs: {
            runStatus: 'Failed'
            runError: {
              code: 'RunnerPoolBelowRedundancyFloor'
              message: '@{concat(${floorReport}, \'Voir docs/runbooks/CI_RUNNERS.md section 11.\')}'
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
      parameters: {
        // Versionnée dans `capacity-controller.config.json` (forbidden + external),
        // lisible telle quelle dans la définition déployée et dans chaque run.
        '${excludedNamesParameter}': {
          type: 'Array'
          defaultValue: map(excludedVirtualMachineNames, name => toLower(string(name)))
        }
      }
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
