// Security observability: routes the security-relevant logs/metrics from the
// core resources to Log Analytics, and raises log-search alerts on authentication /
// authorization failure and server-error spikes. All resources here are cheap
// (alert rules ~€0.10/mo each; cost is Log Analytics ingestion only).
//
// Alerts are LOG-SEARCH alerts (Microsoft.Insights/scheduledQueryRules) over the
// workspace-based Application Insights `AppRequests` table, NOT metric alerts on
// Microsoft.Web/sites. Rationale: the Function App runs on the Flex Consumption
// plan (FC1), which does NOT expose the Http401/Http403/Http5xx platform metrics
// — a metric alert referencing them fails to deploy ("Couldn't find a metric
// named Http401"). Querying AppRequests.ResultCode is plan-portable and works on
// Flex Consumption (App Insights request telemetry is independent of the plan).
@description('Function App name — the auth/request surface (401/403/5xx).')
param functionAppName string

@description('Cosmos DB account name — data-plane request logs.')
param cosmosAccountName string

@description('Key Vault name — secret AuditEvent logs.')
param keyVaultName string

@description('Log Analytics workspace resource id to send diagnostics to and to scope the log-search alerts on.')
param workspaceId string

@description('Azure region for the log-search alert rules — must match the workspace region (both are created in the same primary location).')
param location string

@description('Optional email address notified on security alerts. Empty disables the receiver AND leaves the alerts action-less (still no deployment failure).')
param alertEmail string = ''

@description('When true, each log-search alert gets a system-assigned identity granted the least-privilege Log Analytics Reader role on the workspace (most robust: the rule no longer inherits the last editor\'s permissions). Default false because creating the role assignment requires Microsoft.Authorization/roleAssignments/write at the workspace scope, which the deploying principal may not have — keeping it off guarantees the deployment succeeds. Turn on once the deployer has role-assignment rights.')
param grantAlertReaderRole bool = false

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

// ---------------------------------------------------------------------------
// Action group (email) + log-search alerts on authn/authz failure & 5xx spikes
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

// Log-search alert definitions. Each `query` returns one row per matching
// request; the alert fires when the COUNT over the 15-min window exceeds the
// threshold. ResultCode is a STRING in the Log Analytics schema, so we match on
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
    name: 'http403-spike'
    // 403 Forbidden spike — possible authorization abuse / scope escalation.
    query: 'AppRequests | where ResultCode == "403"'
    threshold: 25
    severity: 2
    desc: 'Spike of 403 Forbidden responses — possible authorization abuse / scope escalation attempts.'
  }
  {
    name: 'http5xx-spike'
    // 5xx server errors — API instability or active attack. Strict regex on the
    // string ResultCode avoids toint() failures on empty/non-numeric values.
    query: 'AppRequests | where ResultCode matches regex "^5[0-9][0-9]$"'
    threshold: 25
    severity: 2
    desc: 'Spike of 5xx server errors — API instability or active attack.'
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
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
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
    // Attach the email action group only when an email is configured; otherwise
    // no action (the rule still evaluates, it just notifies nobody). Either way
    // the deployment never fails on an empty alertEmail.
    actions: {
      actionGroups: hasEmail ? [ actionGroup.id ] : []
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

output actionGroupId string = actionGroup.id
