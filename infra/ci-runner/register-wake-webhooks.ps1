[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $SubscriptionId,

  [string] $ResourceGroupName = 'rg-certigo-ci',
  [string] $WorkflowName = 'logic-certigo-ci-runner-wake',
  [string] $TriggerName = 'GitHub_workflow_job_webhook',

  # Removes the wake webhooks instead of creating or updating them (rollback).
  [switch] $Remove
)

# Pose (ou met à jour, ou retire) sur chaque dépôt de capacity-controller.config.json le webhook
# `workflow_job` qui réveille les runners CI. L'URL signée du déclencheur est un secret porteur :
# elle est lue depuis ARM, gardée en mémoire, transmise à GitHub par l'entrée standard de `gh api`
# et JAMAIS affichée, journalisée, écrite sur disque ni versionnée. Seuls l'identifiant du webhook
# et l'hôte de l'endpoint sont affichés. Voir docs/runbooks/CI_RUNNERS.md section 13.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Native {
  param(
    [Parameter(Mandatory)] [string] $FilePath,
    [Parameter(Mandatory)] [string[]] $Arguments,
    [string] $InputText
  )
  if ($PSBoundParameters.ContainsKey('InputText')) {
    $output = $InputText | & $FilePath @Arguments
  }
  else {
    $output = & $FilePath @Arguments
  }
  if ($LASTEXITCODE -ne 0) {
    throw "$FilePath $($Arguments[0..1] -join ' ') failed with exit code $LASTEXITCODE."
  }
  return ($output -join "`n").Trim()
}

$inventory = Get-Content -Raw -Path (Join-Path $PSScriptRoot 'capacity-controller.config.json') | ConvertFrom-Json
$repositories = @($inventory.repositories)
if ($repositories.Count -eq 0) { throw 'capacity-controller.config.json lists no repository.' }

$workflowId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Logic/workflows/$WorkflowName"
$callbackUrl = Invoke-Native -FilePath 'az' -Arguments @(
  'rest', '--method', 'post', '--subscription', $SubscriptionId,
  '--uri', "https://management.azure.com$workflowId/triggers/$TriggerName/listCallbackUrl?api-version=2019-05-01",
  '--query', 'value', '--output', 'tsv'
)
$endpoint = [uri] $callbackUrl
if ($endpoint.Scheme -ne 'https' -or -not $endpoint.Host.EndsWith('.logic.azure.com') -or $endpoint.Query -notmatch '[?&]sig=') {
  throw 'The trigger callback is not a signed https Logic Apps endpoint; refusing to register it.'
}
# The trigger admits only the IPv4 `hooks` ranges of on-demand.config.json. An endpoint reachable
# over IPv6 could receive deliveries from GitHub's IPv6 ranges, which would all be refused.
$ipv6 = @([System.Net.Dns]::GetHostAddresses($endpoint.Host) | Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6 })
if ($ipv6.Count -gt 0) {
  throw "$($endpoint.Host) resolves over IPv6; extend the trigger allow-list before registering the webhook."
}
$endpointWithoutSignature = $endpoint.GetLeftPart([UriPartial]::Path)

foreach ($repository in $repositories) {
  $hooks = Invoke-Native -FilePath 'gh' -Arguments @('api', "repos/$repository/hooks", '--paginate') | ConvertFrom-Json
  $matching = @($hooks | Where-Object {
      $_.config.PSObject.Properties.Name -contains 'url' -and
      ([uri] $_.config.url).GetLeftPart([UriPartial]::Path) -eq $endpointWithoutSignature
    })
  if ($matching.Count -gt 1) {
    throw "$repository has $($matching.Count) webhooks for the wake endpoint; remove the duplicates by hand."
  }

  if ($Remove) {
    foreach ($hook in $matching) {
      $null = Invoke-Native -FilePath 'gh' -Arguments @('api', '--method', 'DELETE', "repos/$repository/hooks/$($hook.id)")
      Write-Host "$repository : wake webhook $($hook.id) removed"
    }
    continue
  }

  $body = @{
    name = 'web'
    active = $true
    events = @('workflow_job')
    config = @{
      url = $callbackUrl
      content_type = 'json'
      insecure_ssl = '0'
    }
  }
  if ($matching.Count -eq 1) {
    $body.Remove('name')
    $path = "repos/$repository/hooks/$($matching[0].id)"
    $method = 'PATCH'
  }
  else {
    $path = "repos/$repository/hooks"
    $method = 'POST'
  }
  # The response echoes the signed URL: only the id, events and state are kept.
  $hookId = Invoke-Native -FilePath 'gh' -Arguments @(
    'api', '--method', $method, $path, '--input', '-', '--jq', '.id'
  ) -InputText ($body | ConvertTo-Json -Depth 5 -Compress)
  $check = Invoke-Native -FilePath 'gh' -Arguments @(
    'api', "repos/$repository/hooks/$hookId", '--jq', '{active: .active, events: .events, content_type: .config.content_type, insecure_ssl: .config.insecure_ssl}'
  ) | ConvertFrom-Json
  if (-not $check.active -or (@($check.events) -join ',') -ne 'workflow_job' -or $check.content_type -ne 'json' -or $check.insecure_ssl -ne '0') {
    throw "$repository : webhook $hookId was not stored as requested."
  }
  $null = Invoke-Native -FilePath 'gh' -Arguments @('api', '--method', 'POST', "repos/$repository/hooks/$hookId/pings")
  Write-Host "$repository : wake webhook $hookId $($method -eq 'POST' ? 'created' : 'updated') -> $($endpoint.Host) (workflow_job, json, TLS verified); ping sent"
}

if (-not $Remove) {
  Write-Host 'Check the ping deliveries (expected status_code 202):'
  foreach ($repository in $repositories) {
    Write-Host "  gh api repos/$repository/hooks/<id>/deliveries --jq '.[0:3][] | {event, status_code, delivered_at}'"
  }
}
