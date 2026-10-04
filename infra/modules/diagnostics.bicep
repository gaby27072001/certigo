// Cost-bounded operational and security observability for the backend.
//
// Alerts are LOG-SEARCH alerts (Microsoft.Insights/scheduledQueryRules) over the
// workspace-based Application Insights request/exception tables, NOT metric alerts on
// Microsoft.Web/sites. Rationale: the Function App runs on the Flex Consumption
// plan (FC1), which does NOT expose the Http401/Http403/Http5xx platform metrics
// — a metric alert referencing them fails to deploy ("Couldn't find a metric
// named Http401"). Querying AppRequests.ResultCode is plan-portable and works on
// Flex Consumption (App Insights request telemetry is independent of the plan).
@description('Function App name — the auth/request surface (401/403/5xx).')
param functionAppName string

@description('Function App public host name used by the availability/readiness probe.')
param functionAppHostName string

@description('Workspace-based Application Insights component name.')
param appInsightsName string

@description('Cosmos DB account name — data-plane request logs.')
param cosmosAccountName string

@description('Key Vault name — secret AuditEvent logs.')
param keyVaultName string

@description('Storage account name — host and deployment storage logs.')
param storageAccountName string

@description('Log Analytics workspace resource id to send diagnostics to and to scope the log-search alerts on.')
param workspaceId string

@description('Azure region for the log-search alert rules — must match the workspace region (both are created in the same primary location).')
param location string

@description('Required email address notified on security and readiness alerts.')
@minLength(3)
param alertEmail string

@description('When true, each log-search alert gets a system-assigned identity granted the least-privilege Log Analytics Reader role on the workspace (most robust: the rule no longer inherits the last editor\'s permissions). Default false because creating the role assignment requires Microsoft.Authorization/roleAssignments/write at the workspace scope, which the deploying principal may not have — keeping it off guarantees the deployment succeeds. Turn on once the deployer has role-assignment rights.')
param grantAlertReaderRole bool = false

@description('Existing storage-account diagnostic setting name.')
param storageDiagnosticSettingName string = 'security-to-law'

@description('Existing Blob service diagnostic setting name.')
param blobServiceDiagnosticSettingName string = 'security-to-law'

@description('Existing Queue service diagnostic setting name.')
param queueServiceDiagnosticSettingName string = 'security-to-law'

@description('Existing Table service diagnostic setting name.')
param tableServiceDiagnosticSettingName string = 'security-to-law'

@description('Observability cost profile, chosen in infra/main.bicep from env (prod is always production). production keeps every signal at its production cadence. nonProduction (staging) evaluates every log-search alert every 15 minutes over 15 minutes, keeps only deletions in the storage data-plane logs and only the readiness availability test, at the production cadence and locations. See docs/runbooks/OBSERVABILITY.md, "Profil de cout hors production".')
@allowed([
  'production'
  'nonProduction'
])
param costProfile string = 'production'

param tags object = {}

var nonProduction = costProfile == 'nonProduction'

// Storage data-plane logs. Production keeps every category for audit. Outside production only
// deletions are kept: reads and writes are the Functions host's own blob traffic (GetBlob,
// GetBlobProperties, RenewBlobLease, ListContainers), about 2.3 GB per 30 days in staging,
// read by no alert, test, workbook or runbook; deletions are rare and keep the audit trail.
var storageServiceLogs = nonProduction ? [
  { category: 'StorageDelete', enabled: true }
] : [
  { categoryGroup: 'allLogs', enabled: true }
]

resource functionApp 'Microsoft.Web/sites@2023-12-01' existing = {
  name: functionAppName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: cosmosAccountName
}

resource vault 'Microsoft.KeyVault/vaults@2024-04-01-preview' existing = {
  name: keyVaultName
}

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

// The Log Analytics workspace, referenced (not created) so the alerts can scope
// on it and — when enabled — the least-privilege role assignment can target it.
// Name is derived from the resource id; the workspace lives in this module's RG.
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: last(split(workspaceId, '/'))
}

// ---------------------------------------------------------------------------
// Diagnostic settings -> Log Analytics (audit trail for the security surface).
// Uses category GROUPS ('allLogs') and 'AllMetrics' — the portable forms that
// don't hard-code plan-specific category names, so they are safe on Flex
// Consumption (which collects FunctionAppLogs via diagnostic settings).
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

resource storageDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storage
  name: storageDiagnosticSettingName
  properties: {
    workspaceId: workspaceId
    metrics: [ { category: 'Transaction', enabled: true } ]
  }
}

resource blobServiceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: blobServiceDiagnosticSettingName
  properties: {
    workspaceId: workspaceId
    logs: storageServiceLogs
    metrics: [ { category: 'Transaction', enabled: true } ]
  }
}

resource queueServiceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: queueService
  name: queueServiceDiagnosticSettingName
  properties: {
    workspaceId: workspaceId
    logs: storageServiceLogs
    metrics: [ { category: 'Transaction', enabled: true } ]
  }
}

resource tableServiceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: tableService
  name: tableServiceDiagnosticSettingName
  properties: {
    workspaceId: workspaceId
    logs: storageServiceLogs
    metrics: [ { category: 'Transaction', enabled: true } ]
  }
}

// ---------------------------------------------------------------------------
// Action group (email) + log-search alerts on authn/authz failure & 5xx spikes
// ---------------------------------------------------------------------------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-certigo-security'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'mlsec'
    enabled: true
    emailReceivers: [
      {
        name: 'secops'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

// Preserve the deployed readiness resource names during incremental deployments;
// only the liveness test and its alert are new. The probes send no headers, body,
// query string or user data. The new liveness test disables retries so its
// execution cost stays strictly bounded.
// Outside production only the readiness test is kept (decided 2026-10-04): the promotion
// monitor needs availability results, not a particular test, and the readiness probe keeps
// its 300-second cadence from both locations. Cadence and locations never depend on the
// profile: a slower or single-location probe can leave the monitor's first window empty.
var availabilityTests = [
  {
    name: 'ready'
    resourceName: 'availability-${functionAppName}'
    alertName: 'alert-certigo-availability'
    path: '/api/health/ready'
    description: 'Certigo backend availability and dependency-readiness probe.'
    alertDescription: 'Readiness failed from both probe locations; inspect the Function App and Cosmos/Storage/Key Vault dependencies.'
    retryEnabled: true
    keptOutsideProduction: true
  }
  {
    name: 'live'
    resourceName: 'availability-${functionAppName}-live'
    alertName: 'alert-certigo-availability-live'
    path: '/api/health/live'
    description: 'Certigo backend process liveness probe.'
    alertDescription: 'Liveness failed from both probe locations; inspect the Function App process.'
    retryEnabled: false
    keptOutsideProduction: false
  }
]

var deployedAvailabilityTests = filter(availabilityTests, test => !nonProduction || test.keptOutsideProduction)

resource availabilityWebTests 'Microsoft.Insights/webtests@2022-06-15' = [for test in deployedAvailabilityTests: {
  name: test.resourceName
  location: location
  kind: 'standard'
  tags: union(tags, {
    'hidden-link:${appInsights.id}': 'Resource'
  })
  properties: {
    Name: test.resourceName
    Description: test.description
    Enabled: true
    Frequency: 300
    Timeout: 30
    Kind: 'standard'
    RetryEnabled: test.retryEnabled
    Locations: [
      { Id: 'emea-nl-ams-azr' }
      { Id: 'us-va-ash-azr' }
    ]
    Request: {
      RequestUrl: 'https://${functionAppHostName}${test.path}'
      HttpVerb: 'GET'
      FollowRedirects: false
      ParseDependentRequests: false
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 14
    }
    SyntheticMonitorId: test.resourceName
  }
}]

resource availabilityAlerts 'Microsoft.Insights/metricAlerts@2018-03-01' = [for (test, i) in deployedAvailabilityTests: {
  name: test.alertName
  location: 'global'
  tags: union(tags, {
    'hidden-link:${appInsights.id}': 'Resource'
    'hidden-link:${availabilityWebTests[i].id}': 'Resource'
  })
  properties: {
    description: test.alertDescription
    severity: 1
    enabled: true
    scopes: [
      availabilityWebTests[i].id
      appInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.WebtestLocationAvailabilityCriteria'
      webTestId: availabilityWebTests[i].id
      componentId: appInsights.id
      failedLocationCount: 2
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}]

// Activity Log alerts are free and catch failures before application telemetry is
// available, including ARM infrastructure deployments and Function OneDeploy.
resource deploymentFailureAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-certigo-deployment-failure'
  location: 'global'
  tags: tags
  properties: {
    description: 'Backend infrastructure deployment or Function OneDeploy failed in this environment.'
    enabled: true
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'status'
          equals: 'Failed'
        }
        {
          field: 'resourceGroup'
          equals: resourceGroup().name
        }
        {
          anyOf: [
            {
              field: 'operationName'
              equals: 'Microsoft.Resources/deployments/write'
            }
            {
              field: 'operationName'
              equals: 'Microsoft.Web/sites/extensions/write'
            }
          ]
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: actionGroup.id
        }
      ]
    }
  }
}

// Log-search alert definitions. Each `query` returns one row per matching
// request; the alert fires when the COUNT over the rule's window exceeds the
// threshold. Readiness requires repeated failures, not one recovered retry.
// ResultCode is a STRING in the Log Analytics schema, so we match on
// string values / a strict 5xx regex — no bare toint() that could throw on an
// empty or non-numeric ResultCode.
var logAlerts = [
  {
    name: 'http401-spike'
    // 401 Unauthorized spike — possible credential probing / token abuse.
    query: 'AppRequests | where ResultCode == "401"'
    threshold: 25
    severity: 2
    desc: 'Spike of 401 Unauthorized responses — possible credential probing / token abuse.'
  }
  {
    name: 'readiness-failure'
    query: replace(loadTextContent('../queries/readiness-failures.kql'), '__APP_INSIGHTS_RESOURCE_ID__', appInsights.id)
    threshold: 1
    severity: 1
    desc: 'At least two readiness requests failed within ${nonProduction ? 15 : 10} minutes. Repeated or partial failure, not necessarily a continuous outage; inspect Cosmos, Storage and Key Vault. See docs/runbooks/OBSERVABILITY.md.'
  }
  {
    name: 'http403-spike'
    // 403 Forbidden spike — possible authorization abuse / scope escalation.
    query: 'AppRequests | where ResultCode == "403"'
    threshold: 25
    severity: 2
    desc: 'Spike of 403 Forbidden responses — possible authorization abuse / scope escalation attempts.'
  }
  {
    name: 'http5xx-spike'
    // Preserve the rule/identity and group both signals into one stateful incident.
    // No operation-name allowlist: new learner routes must be covered by default.
    query: replace(loadTextContent('../queries/critical-failures.kql'), '__APP_INSIGHTS_RESOURCE_ID__', appInsights.id)
    threshold: 0
    severity: 1
    desc: 'A non-health API request returned 5xx or an Error/Critical or unhandled exception was recorded. Investigate even if the alert resolves: no traffic is not proof of recovery. See docs/runbooks/OBSERVABILITY.md.'
  }
  {
    name: 'telemetry-absent'
    // The synthetic probes guarantee requests in every healthy 15-minute window.
    // summarize returns one row only when the request count is zero.
    query: 'AppRequests | summarize RequestCount = count() | where RequestCount == 0'
    threshold: 0
    severity: 1
    desc: 'No request telemetry arrived in 15 minutes despite the scheduled availability probes.'
  }
]

resource httpAlerts 'Microsoft.Insights/scheduledQueryRules@2023-12-01' = [ for a in logAlerts: {
  name: 'alert-certigo-${a.name}'
  location: location
  tags: tags
  kind: 'LogAlert'
  // Opt-in least-privilege identity (see grantAlertReaderRole). When off, the
  // rule inherits the deploying principal's permissions to read the workspace.
  identity: grantAlertReaderRole ? { type: 'SystemAssigned' } : { type: 'None' }
  properties: {
    displayName: 'certigo-${a.name}'
    description: a.desc
    severity: a.severity
    enabled: true
    // Scope on the workspace (App Insights is workspace-based -> AppRequests).
    scopes: [ workspaceId ]
    // Production: readiness every minute over 10 minutes, the others every 5 minutes over 15.
    // Outside production every rule runs every 15 minutes over the last 15 minutes: contiguous
    // windows, unchanged thresholds, a third of the 5-minute price.
    evaluationFrequency: nonProduction ? 'PT15M' : (a.name == 'readiness-failure' ? 'PT1M' : 'PT5M')
    windowSize: nonProduction ? 'PT15M' : (a.name == 'readiness-failure' ? 'PT10M' : 'PT15M')
    autoMitigate: true
    criteria: {
      allOf: [
        {
          query: a.query
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: a.threshold
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    actions: {
      actionGroups: [ actionGroup.id ]
    }
  }
}]

// Optional least-privilege grant: Log Analytics Reader on the workspace for each
// alert's system-assigned identity. Gated on grantAlertReaderRole so the default
// deployment needs no role-assignment rights. Deterministic guid() names ->
// idempotent / re-deployable. principalType 'ServicePrincipal' avoids the
// transient "principal not found" replication error.
var logAnalyticsReaderRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '73c42c96-874c-492b-b04d-ab87d138a893'
)

resource alertReaderGrants 'Microsoft.Authorization/roleAssignments@2022-04-01' = [ for (a, i) in logAlerts: if (grantAlertReaderRole) {
  name: guid(workspace.id, a.name, 'la-reader')
  scope: workspace
  properties: {
    principalId: httpAlerts[i].identity.principalId
    roleDefinitionId: logAnalyticsReaderRoleId
    principalType: 'ServicePrincipal'
  }
}]

// Aggregated-only workbook: no request URLs, operation ids, partition keys,
// payloads or identities are rendered.
var workbookDefinition = {
  version: 'Notebook/1.0'
  items: [
    {
      type: 1
      content: {
        json: '# Certigo minimal observability\nAggregated Functions, Cosmos DB and Storage signals. No user-level fields are displayed.'
      }
      name: 'overview'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        title: 'Functions requests, 5xx and P95 latency'
        query: 'AppRequests | summarize Requests=count(), Failures=countif(ResultCode matches regex "^5[0-9][0-9]$"), P95DurationMs=round(percentile(DurationMs, 95), 1) by bin(TimeGenerated, 1h) | order by TimeGenerated asc'
        size: 0
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'functions-requests'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        title: 'Functions cold starts'
        query: 'AppMetrics | where Name == "functions.cold_start" | summarize ColdStarts=sum(Sum) by bin(TimeGenerated, 1h) | order by TimeGenerated asc'
        size: 0
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'functions-cold-starts'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        title: 'Cosmos requests, throttles and RU'
        query: 'CDBDataPlaneRequests | summarize Requests=count(), Throttles=countif(tostring(StatusCode) == "429"), RequestUnits=sum(todouble(RequestCharge)) by bin(TimeGenerated, 1h) | order by TimeGenerated asc'
        size: 0
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'cosmos-requests'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        title: 'Cosmos partition RU distribution (no partition keys)'
        query: 'CDBPartitionKeyRUConsumption | extend RU=todouble(column_ifexists("RequestCharge", 0.0)), Partition=tostring(column_ifexists("PartitionKey", "")) | summarize P95RU=percentile(RU, 95), MaxRU=max(RU), PartitionCount=dcount(Partition) by DatabaseName, CollectionName, bin(TimeGenerated, 1h)'
        size: 0
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'cosmos-partition-ru'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        title: 'Cosmos partition storage distribution (no partition keys)'
        query: 'CDBPartitionKeyStatistics | extend SizeKB=todouble(column_ifexists("SizeKb", 0.0)), Partition=tostring(column_ifexists("PartitionKey", "")) | summarize TotalStorageKB=sum(SizeKB), MaxPartitionKB=max(SizeKB), PartitionCount=dcount(Partition) by DatabaseName, CollectionName'
        size: 0
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'cosmos-partition-storage'
    }
    {
      type: 3
      content: {
        version: 'KqlItem/1.0'
        title: 'Storage availability, transactions and latency'
        query: 'AzureMetrics | where toupper(ResourceProvider) == "MICROSOFT.STORAGE" | where MetricName in ("Transactions", "Availability", "SuccessE2ELatency", "SuccessServerLatency") | summarize AverageValue=avg(Average), TotalValue=sum(Total) by MetricName, bin(TimeGenerated, 1h) | order by TimeGenerated asc'
        size: 0
        timeContext: {
          durationMs: 86400000
        }
        queryType: 0
        resourceType: 'microsoft.operationalinsights/workspaces'
      }
      name: 'storage-platform'
    }
  ]
  fallbackResourceIds: [
    workspaceId
  ]
}

resource observabilityWorkbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid(resourceGroup().id, 'certigo-minimal-observability')
  location: location
  kind: 'shared'
  tags: tags
  properties: {
    displayName: 'Certigo - Functions, Cosmos and Storage'
    serializedData: string(workbookDefinition)
    version: 'Notebook/1.0'
    sourceId: workspaceId
    category: 'workbook'
    description: 'Cost-bounded operational view with aggregate-only signals.'
  }
}

output actionGroupId string = actionGroup.id
