targetScope = 'resourceGroup'

@description('Deploy the event-driven runner job. False creates only the isolated observability plane.')
param pilotEnabled bool = false

@description('Azure region for the ACA pilot.')
param location string = resourceGroup().location

@description('Immutable public runner image. The preflight requires an amd64 @sha256 digest.')
param runnerImage string = 'invalid.invalid/certigo/aca-runner@sha256:0000000000000000000000000000000000000000000000000000000000000000'

@description('GitHub App numeric application ID. Required only when pilotEnabled is true.')
param githubAppId string = ''

@description('GitHub App numeric installation ID. Required only when pilotEnabled is true.')
param githubAppInstallationId string = ''

@secure()
@description('GitHub App private key. It is exposed only to the KEDA scaler and JIT init container.')
param githubAppPrivateKey string = ''

@description('Repository owner monitored by the dedicated GitHub App.')
param githubOwner string = 'gchambaud_microsoft'

@description('Single repository monitored by the pilot.')
param githubRepository string = 'Certigo'

@allowed([
  'certigo-pr-aca'
])
@description('Exclusive runner label for the ephemeral, untrusted PR pilot.')
param runnerLabel string = 'certigo-pr-aca'

@minValue(1)
@description('Repository runner group ID used by the GitHub JIT configuration endpoint.')
param runnerGroupId int = 1

@minValue(30)
@maxValue(30)
@description('KEDA polling interval pinned by ADR-018.')
param pollingIntervalSeconds int = 30

@minValue(1)
@maxValue(2)
@description('Hard ceiling for concurrent ACA job executions.')
param maxExecutions int = 2

@minValue(300)
@maxValue(1800)
@description('One-job execution timeout. The initial pilot is capped at 30 minutes.')
param replicaTimeoutSeconds int = 1800

@description('Dedicated Log Analytics workspace name.')
param logAnalyticsWorkspaceName string = 'log-certigo-aca-pilot'

@description('Dedicated Container Apps environment name.')
param managedEnvironmentName string = 'cae-certigo-ci-aca-pilot'

@description('Event-driven Container Apps job name.')
param jobName string = 'job-certigo-pr-aca'

@description('Required FinOps and ownership tags.')
param tags object = {
  owner: 'certigo'
  product: 'Certigo'
  env: 'ci-pilot'
  managedBy: 'bicep'
  costCenter: 'certigo-ci'
  workload: 'github-actions-runner'
  trustBoundary: 'untrusted-pr'
  lifecycle: 'ephemeral'
}

var immutableImage = contains(toLower(runnerImage), '@sha256:')
var effectiveRunnerImage = immutableImage
  ? runnerImage
  : 'invalid.invalid/certigo/rejected-mutable-image@sha256:0000000000000000000000000000000000000000000000000000000000000000'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  tags: tags
  properties: {
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: managedEnvironmentName
  location: location
  tags: tags
  identity: {
    type: 'None'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'azure-monitor'
    }
    zoneRedundant: false
  }
}

resource managedEnvironmentDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'certigo-aca-pilot-logs'
  scope: managedEnvironment
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource runnerJob 'Microsoft.App/jobs@2025-01-01' = if (pilotEnabled) {
  name: jobName
  location: location
  tags: tags
  identity: {
    type: 'None'
  }
  properties: {
    environmentId: managedEnvironment.id
    configuration: {
      triggerType: 'Event'
      replicaTimeout: replicaTimeoutSeconds
      replicaRetryLimit: 0
      secrets: [
        {
          name: 'github-app-key'
          value: githubAppPrivateKey
        }
      ]
      eventTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
        scale: {
          minExecutions: 0
          maxExecutions: maxExecutions
          pollingInterval: pollingIntervalSeconds
          rules: [
            {
              name: 'github-runner'
              type: 'github-runner'
              metadata: {
                githubAPIURL: 'https://api.github.com'
                owner: githubOwner
                runnerScope: 'repo'
                repos: githubRepository
                labels: runnerLabel
                noDefaultLabels: 'false'
                enableEtags: 'true'
                targetWorkflowQueueLength: '1'
                applicationID: githubAppId
                installationID: githubAppInstallationId
              }
              auth: [
                {
                  secretRef: 'github-app-key'
                  triggerParameter: 'appKey'
                }
              ]
            }
          ]
        }
      }
    }
    template: {
      initContainers: [
        {
          name: 'jit-config'
          image: effectiveRunnerImage
          command: [
            'node'
          ]
          args: [
            '/opt/certigo/prepare-jit.mjs'
          ]
          env: [
            {
              name: 'GITHUB_API_URL'
              value: 'https://api.github.com'
            }
            {
              name: 'GITHUB_OWNER'
              value: githubOwner
            }
            {
              name: 'GITHUB_REPOSITORY'
              value: githubRepository
            }
            {
              name: 'GITHUB_APP_ID'
              value: githubAppId
            }
            {
              name: 'GITHUB_APP_INSTALLATION_ID'
              value: githubAppInstallationId
            }
            {
              name: 'GITHUB_APP_PRIVATE_KEY'
              secretRef: 'github-app-key'
            }
            {
              name: 'RUNNER_GROUP_ID'
              value: string(runnerGroupId)
            }
            {
              name: 'RUNNER_LABEL'
              value: runnerLabel
            }
            {
              name: 'JIT_CONFIG_PATH'
              value: '/var/run/certigo-runner/jitconfig'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          volumeMounts: [
            {
              volumeName: 'runner-jit'
              mountPath: '/var/run/certigo-runner'
            }
          ]
        }
      ]
      containers: [
        {
          name: 'runner'
          image: effectiveRunnerImage
          command: [
            '/opt/certigo/run-ephemeral.sh'
          ]
          env: [
            {
              name: 'EXPECTED_RUNNER_LABEL'
              value: runnerLabel
            }
            {
              name: 'JIT_CONFIG_PATH'
              value: '/var/run/certigo-runner/jitconfig'
            }
            {
              name: 'RUNNER_LOG_TO_STDOUT'
              value: '1'
            }
            {
              name: 'ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT'
              value: '1'
            }
          ]
          resources: {
            cpu: json('2.0')
            memory: '4Gi'
          }
          volumeMounts: [
            {
              volumeName: 'runner-jit'
              mountPath: '/var/run/certigo-runner'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'runner-jit'
          storageType: 'EmptyDir'
        }
      ]
    }
  }
}

output pilotEnabled bool = pilotEnabled
output immutableImage bool = immutableImage
output managedEnvironmentId string = managedEnvironment.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output runnerLabel string = runnerLabel
output maxExecutions int = maxExecutions
