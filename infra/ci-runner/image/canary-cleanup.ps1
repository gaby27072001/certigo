[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $SubscriptionId,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $Authorization,

  [switch] $Apply,

  [string] $ResourceGroupName = 'rg-certigo-runner-image-runtime-canary'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Authorization -ne 'CERTIGO-RUNNER-CANARY-CLEANUP-AUTHORIZED') {
  throw 'Explicit cleanup authorization is required before any Azure call.'
}

$contract = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'canary-contract.json') -Raw |
  ConvertFrom-Json
if ($ResourceGroupName -ne $contract.resourceGroups.runtime) {
  throw "Cleanup is restricted to '$($contract.resourceGroups.runtime)'."
}

$group = az group show `
  --subscription $SubscriptionId `
  --name $ResourceGroupName `
  --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to read the dedicated canary resource group.'
}
if (
  $group.tags.lifecycle -ne 'image-canary' -or
  $group.tags.trustBoundary -ne 'untrusted-pr' -or
  $group.tags.managedBy -ne 'bicep'
) {
  throw 'The runtime resource group does not carry the exact canary ownership tags.'
}

$resources = @(
  az resource list `
    --subscription $SubscriptionId `
    --resource-group $ResourceGroupName `
    --output json | ConvertFrom-Json
)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to inventory the dedicated canary resource group.'
}

$reserved = @(
  $contract.reserved.virtualMachineTokens +
  $contract.reserved.existingScaleSets
)
foreach ($resource in $resources) {
  foreach ($token in $reserved) {
    if ($resource.id.Contains($token, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Cleanup inventory contains reserved resource '$($resource.id)'."
    }
  }
  if ($resource.tags.lifecycle -ne 'image-canary') {
    throw "Cleanup inventory contains an unowned resource '$($resource.id)'."
  }
}

$expiresOn = [DateTimeOffset]::Parse($group.tags.expiresOn)
if ($expiresOn -gt [DateTimeOffset]::UtcNow) {
  throw "Canary cleanup is blocked until expiry $expiresOn."
}

if (-not $Apply) {
  [pscustomobject] @{
    apply = $false
    resourceGroup = $ResourceGroupName
    resourceCount = $resources.Count
    expiresOn = $expiresOn
  }
  return
}

az group delete `
  --subscription $SubscriptionId `
  --name $ResourceGroupName `
  --yes
if ($LASTEXITCODE -ne 0) {
  throw 'Dedicated canary resource-group cleanup failed.'
}
