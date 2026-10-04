// Development observability, cost-bounded (decided 2026-10-04).
//
// The diagnostics module is not deployed in dev (infra/main.bicep). Before this module, dev's
// three HTTP log alerts and its storage diagnostic settings were created by hand on 2026-08-15
// (tag managedBy: manual-hardening). This module adopts them under the same names, keeps their
// queries, thresholds, severity and their absence of action group (they notify nobody and are
// read in the portal), and only lowers their cost:
// - every rule runs every 15 minutes over the last 15 minutes (a third of the 5-minute price);
// - the storage data-plane logs keep deletions only. Reads and writes are the Functions host's
//   own blob traffic (GetBlob, GetBlobProperties, RenewBlobLease, ListContainers), measured at
//   about 2.2 GB per 30 days and read by no alert, test, workbook or runbook.
// See docs/runbooks/OBSERVABILITY.md, "Profil de cout hors production".

@description('Dev storage account whose Blob, Queue and Table data-plane logs are configured.')
param storageAccountName string

@description('Dev Log Analytics workspace resource id: diagnostics destination and alert scope.')
param workspaceId string

@description('Region of the log-search alert rules; must match the workspace region.')
param location string

param tags object = {}

// Adopts the settings created by hand under this name; the account-level setting is unchanged.
var diagnosticSettingName = 'diag-to-log-analytics'

var storageServiceLogs = [
  { category: 'StorageDelete', enabled: true }
]

var storageServiceMetrics = [
  { category: 'Capacity', enabled: true }
  { category: 'Transaction', enabled: true }
]

resource storage 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' existing = {
  parent: storage
  name: 'default'
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' existing = {
  parent: storage
  name: 'default'
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' existing = {
  parent: storage
  name: 'default'
}

resource blobServiceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: diagnosticSettingName
  properties: {
    workspaceId: workspaceId
    logs: storageServiceLogs
    metrics: storageServiceMetrics
  }
}

resource queueServiceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: queueService
  name: diagnosticSettingName
  properties: {
    workspaceId: workspaceId
    logs: storageServiceLogs
    metrics: storageServiceMetrics
  }
}

resource tableServiceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: tableService
  name: diagnosticSettingName
  properties: {
    workspaceId: workspaceId
    logs: storageServiceLogs
    metrics: storageServiceMetrics
  }
}

// The definitions deployed by hand on 2026-08-15, unchanged except for the cadence.
var logAlerts = [
  {
    name: 'http401-spike'
    query: 'AppRequests | where ResultCode == "401"'
    desc: 'Spike of 401 authentication failures - possible auth issue or credential probing.'
  }
  {
    name: 'http403-spike'
    query: 'AppRequests | where ResultCode == "403"'
    desc: 'Spike of 403 authorization failures - possible permission issue or access probing.'
  }
  {
    name: 'http5xx-spike'
    query: 'AppRequests | where ResultCode matches regex "^5[0-9][0-9]$"'
    desc: 'Spike of 5xx server errors - API instability or active attack.'
  }
]

resource httpAlerts 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = [for a in logAlerts: {
  name: 'alert-certigo-${a.name}'
  location: location
  tags: tags
  kind: 'LogAlert'
  properties: {
    displayName: 'certigo-${a.name}'
    description: a.desc
    severity: 2
    enabled: true
    scopes: [ workspaceId ]
    evaluationFrequency: 'PT15M'
    windowSize: 'PT15M'
    autoMitigate: true
    criteria: {
      allOf: [
        {
          query: a.query
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 25
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
  }
}]
