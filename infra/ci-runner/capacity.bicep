// Contrat de capacité observé pour les deux VMSS Flexible de RG-CERTIGO-CI.
// Les VMSS et leurs instances restent existing : ce modèle ne les recrée, ne les
// redimensionne et ne les adopte pas. Seul l'autoscale legacy est mutable.
targetScope = 'resourceGroup'

@description('Région Azure du paramétrage d’autoscale CI.')
param location string = 'westeurope'

@description('VMSS legacy qui porte la capacité trusted observée.')
param legacyVmScaleSetName string = 'vmss-certigo-runner-zonal'

@description('VMSS PR isolé observé.')
param pilotVmScaleSetName string = 'vmss-certigo-pr-pilot-z1'

@description('Taille commune observée sur les VMSS. Utilisée par la détection de drift.')
param vmSize string = 'Standard_D2ads_v6'

@description('Nom du paramétrage d’autoscale legacy existant.')
param autoscaleSettingName string = 'autoscale-vmss-certigo-runner-zonal'

@description('Capacité minimale et par défaut conservée tant que le contrôleur queue-driven est désactivé.')
param legacyMinimumCapacity int = 2

@description('Capacité maximale actuelle du VMSS legacy.')
param legacyMaximumCapacity int = 4

@description('Étiquettes supplémentaires conservées lors de l’application du contrat FinOps.')
param tags object = {}

@description('Équipe ou service propriétaire. Ne jamais utiliser une identité personnelle.')
@minLength(1)
param tagOwner string = 'certigo-platform'

@description('Produit du contrat FinOps.')
@allowed(['Certigo'])
param tagProduct string = 'Certigo'

@description('Environnement du contrat FinOps.')
@allowed(['ci'])
param tagEnvironment string = 'ci'

@description('Outil déclaratif propriétaire de la ressource.')
@allowed(['bicep'])
param tagManagedBy string = 'bicep'

@description('Identifiant non personnel d’allocation des coûts.')
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

resource legacyVmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' existing = {
  name: legacyVmScaleSetName
}

resource pilotVmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' existing = {
  name: pilotVmScaleSetName
}

// Le scale-out CPU live est conservé pour ne pas réduire la capacité disponible.
// Le scale-in CPU est volontairement absent : Azure ne connaît ni GitHub busy ni
// la file workflow_job. Toute réduction reste bloquée par le contrôleur disabled.
resource legacyAutoscale 'Microsoft.Insights/autoscaleSettings@2022-10-01' = {
  name: autoscaleSettingName
  location: location
  tags: effectiveTags
  properties: {
    enabled: true
    name: autoscaleSettingName
    targetResourceUri: legacyVmScaleSet.id
    profiles: [
      {
        name: 'default'
        capacity: {
          minimum: string(legacyMinimumCapacity)
          default: string(legacyMinimumCapacity)
          maximum: string(legacyMaximumCapacity)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: ''
              metricResourceUri: legacyVmScaleSet.id
              operator: 'GreaterThan'
              statistic: 'Average'
              threshold: 70
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT10M'
              dividePerInstance: false
            }
            scaleAction: {
              cooldown: 'PT10M'
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
            }
          }
        ]
      }
    ]
    notifications: [
      {
        operation: 'Scale'
        email: {
          sendToSubscriptionAdministrator: false
          sendToSubscriptionCoAdministrators: false
        }
      }
    ]
    predictiveAutoscalePolicy: {
      scaleMode: 'Disabled'
    }
  }
}

@description('VMSS legacy observé, référencé sans adoption de ses instances.')
output legacyVmScaleSetId string = legacyVmScaleSet.id

@description('VMSS PR observé, référencé sans adoption de ses instances.')
output pilotVmScaleSetId string = pilotVmScaleSet.id

@description('Taille attendue utilisée par la détection de drift read-only.')
output expectedVmSize string = vmSize

@description('Autoscale legacy géré sans règle de scale-in CPU.')
output autoscaleSettingId string = legacyAutoscale.id
