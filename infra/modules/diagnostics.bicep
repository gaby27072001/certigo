// Security observability: routes the security-relevant logs/metrics from the
// core resources to Log Analytics, and raises metric alerts on authentication /
// authorization failure and server-error spikes. All resources here are cheap
// (alert rules ~€0.10/mo each; cost is Log Analytics ingestion only).
@description('Function App name — the auth/request surface (401/403/5xx).')
param functionAppName string

@description('Cosmos DB account name — data-plane request logs.')
param cosmosAccountName string

@description('Key Vault name — secret AuditEvent logs.')
param keyVaultName string

@description('Log Analytics workspace resource id to send diagnostics to.')
param workspaceId string

@description('Optional email address notified on security alerts. Empty disables the receiver.')
param alertEmail string = ''

param tags object = {}

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: functionAppName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

// ---------------------------------------------------------------------------
// Diagnostic settings -> Log Analytics (audit trail for the security surface)
// ---------------------------------------------------------------------------
resource funcDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: 'security-to-law'
  properties: {
    workspaceId: workspaceId
    logs: [ { categoryGroup: 'allLogs', enabled: true } ]
    metrics: [ { category: 'AllMetrics', enabled: true } ]
  }
}

resource cosmosDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cosmos
  name: 'security-to-law'
  properties: {
    workspaceId: workspaceId
    logs: [ { categoryGroup: 'allLogs', enabled: true } ]
    metrics: [ { category: 'Requests', enabled: true } ]
  }
}

resource vaultDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vault
  name: 'security-to-law'
  properties: {
    workspaceId: workspaceId
    logs: [ { categoryGroup: 'allLogs', enabled: true } ]
    metrics: [ { category: 'AllMetrics', enabled: true } ]
  }
}

// ---------------------------------------------------------------------------
// Action group + metric alerts on authn/authz failure and server-error spikes
// ---------------------------------------------------------------------------
var hasEmail = !empty(alertEmail)

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-certigo-security'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'mlsec'
    enabled: true
    emailReceivers: hasEmail ? [
      {
        name: 'secops'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ] : []
  }
}

var siteMetricAlerts = [
  {
    name: 'http401-spike'
    metric: 'Http401'
    threshold: 25
    desc: 'Spike of 401 Unauthorized responses — possible credential probing / token abuse.'
  }
  {
    name: 'http403-spike'
    metric: 'Http403'
    threshold: 25
    desc: 'Spike of 403 Forbidden responses — possible authorization abuse / scope escalation attempts.'
  }
  {
    name: 'http5xx-spike'
    metric: 'Http5xx'
    threshold: 25
    desc: 'Spike of 5xx server errors — API instability or active attack.'
  }
]

resource httpAlerts 'Microsoft.Insights/metricAlerts@2018-03-01' = [ for a in siteMetricAlerts: {
  name: 'alert-certigo-${a.name}'
  location: 'global'
  tags: tags
  properties: {
    description: a.desc
    severity: 2
    enabled: true
    scopes: [ functionApp.id ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    autoMitigate: true
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'metric1'
          metricNamespace: 'Microsoft.Web/sites'
          metricName: a.metric
          operator: 'GreaterThan'
          threshold: a.threshold
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      { actionGroupId: actionGroup.id }
    ]
  }
}]

output actionGroupId string = actionGroup.id
