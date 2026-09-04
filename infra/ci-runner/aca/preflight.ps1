[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $SubscriptionId,

  [string] $ResourceGroupName = 'RG-CERTIGO-CI',
  [string] $Location = 'westeurope',
  [string] $RunnerImage = 'invalid.invalid/certigo/aca-runner@sha256:0000000000000000000000000000000000000000000000000000000000000000',
  [string] $GitHubAppId = '',
  [string] $GitHubAppInstallationId = '',
  [string] $GitHubAppPrivateKeyPath = '',
  [switch] $EnablePilot,
  [string] $EvidenceDirectory = (
    Join-Path $env:TEMP ('certigo-aca-pilot-preflight-{0}' -f [Guid]::NewGuid().ToString('N'))
  )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$template = Join-Path $PSScriptRoot 'main.bicep'
$validator = Join-Path $PSScriptRoot 'validate-what-if.mjs'
$expectedProviders = @('Microsoft.App', 'Microsoft.OperationalInsights', 'Microsoft.Insights')
$allowedImage = '^[a-z0-9.-]+(?:/[a-z0-9._-]+)+@sha256:[0-9a-f]{64}$'
$disabledRunnerImage = 'invalid.invalid/certigo/aca-runner@sha256:0000000000000000000000000000000000000000000000000000000000000000'

foreach ($command in @('az', 'node')) {
  if ($null -eq (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Required command '$command' is not installed."
  }
}

$account = az account show --subscription $SubscriptionId --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $account.id -ne $SubscriptionId) {
  throw 'Azure CLI is not authenticated to the requested subscription.'
}

$resourceGroup = az group show `
  --subscription $SubscriptionId `
  --name $ResourceGroupName `
  --output json | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
  throw "Resource group '$ResourceGroupName' is not readable."
}
if ($resourceGroup.location -ne $Location) {
  throw "Resource group location '$($resourceGroup.location)' does not match '$Location'."
}

foreach ($provider in $expectedProviders) {
  $state = az provider show `
    --subscription $SubscriptionId `
    --namespace $provider `
    --query registrationState `
    --output tsv
  if ($LASTEXITCODE -ne 0 -or $state -ne 'Registered') {
    throw "Provider '$provider' must already be registered; preflight never registers providers."
  }
}

$privateKey = ''
if ($EnablePilot) {
  if ($RunnerImage -eq $disabledRunnerImage -or $RunnerImage -notmatch $allowedImage) {
    throw 'EnablePilot requires a lowercase immutable image reference ending in @sha256:<64 hex>.'
  }
  if ($GitHubAppId -notmatch '^[1-9][0-9]*$' -or $GitHubAppInstallationId -notmatch '^[1-9][0-9]*$') {
    throw 'EnablePilot requires numeric GitHub App and installation IDs.'
  }
  if (
    [string]::IsNullOrWhiteSpace($GitHubAppPrivateKeyPath) -or
    -not (Test-Path -LiteralPath $GitHubAppPrivateKeyPath -PathType Leaf)
  ) {
    throw 'EnablePilot requires a readable GitHub App private key file.'
  }
  $privateKey = Get-Content -LiteralPath $GitHubAppPrivateKeyPath -Raw
  if ($privateKey -notmatch '-----BEGIN (?:RSA )?PRIVATE KEY-----') {
    throw 'The GitHub App private key file is not a PEM private key.'
  }
}

New-Item -ItemType Directory -Force -Path $EvidenceDirectory | Out-Null
$parameterPath = Join-Path $EvidenceDirectory 'parameters.json'
$whatIfPath = Join-Path $EvidenceDirectory 'what-if.json'
$summaryPath = Join-Path $EvidenceDirectory 'summary.json'

try {
  $parameters = @{
    '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
    contentVersion = '1.0.0.0'
    parameters = @{
      pilotEnabled = @{ value = [bool] $EnablePilot }
      location = @{ value = $Location }
      runnerImage = @{ value = $RunnerImage }
      githubAppId = @{ value = $GitHubAppId }
      githubAppInstallationId = @{ value = $GitHubAppInstallationId }
      githubAppPrivateKey = @{ value = $privateKey }
    }
  }
  [IO.File]::WriteAllText(
    $parameterPath,
    ($parameters | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
  )
  if ($IsWindows) {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    & icacls $parameterPath /inheritance:r /grant:r "${currentIdentity}:(F)" | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw 'Failed to restrict the temporary parameter file ACL.'
    }
  }
  else {
    & chmod 600 $parameterPath
    if ($LASTEXITCODE -ne 0) {
      throw 'Failed to restrict the temporary parameter file mode.'
    }
  }

  $validationLevel = 'Provider'
  az bicep build --file $template --stdout | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw 'Bicep syntax validation failed.'
  }

  $arguments = @(
    'deployment', 'group', 'what-if',
    '--subscription', $SubscriptionId,
    '--resource-group', $ResourceGroupName,
    '--name', 'certigo-aca-pilot-preflight',
    '--template-file', $template,
    '--parameters', "@$parameterPath",
    '--validation-level', $validationLevel,
    '--result-format', 'FullResourcePayloads',
    '--no-pretty-print',
    '--output', 'json'
  )
  & az @arguments 1> $whatIfPath 2> (Join-Path $EvidenceDirectory 'what-if.stderr.txt')
  if ($LASTEXITCODE -ne 0) {
    $errorText = Get-Content (Join-Path $EvidenceDirectory 'what-if.stderr.txt') -Raw
    if ($errorText -notmatch 'AuthorizationFailed|does not have authorization') {
      throw "Azure Provider what-if failed. See $EvidenceDirectory."
    }
    $validationLevel = 'ProviderNoRbac'
    $arguments[$arguments.IndexOf('Provider')] = $validationLevel
    & az @arguments 1> $whatIfPath 2> (Join-Path $EvidenceDirectory 'what-if.stderr.txt')
    if ($LASTEXITCODE -ne 0) {
      throw "Azure ProviderNoRbac what-if also failed. See $EvidenceDirectory."
    }
  }

  $pilotState = $EnablePilot ? 'enabled' : 'disabled'
  $validatorOutput = & node $validator $whatIfPath $pilotState $ResourceGroupName
  if ($LASTEXITCODE -ne 0) {
    throw 'The what-if contains a change outside the strict ACA pilot allow-list.'
  }
  $summary = @{
    generatedAt = [DateTimeOffset]::UtcNow.ToString('O')
    subscriptionId = $SubscriptionId
    tenantId = $account.tenantId
    resourceGroup = $ResourceGroupName
    pilotState = $pilotState
    validationLevel = $validationLevel
    permissionValidation = $validationLevel -eq 'Provider'
    whatIf = $validatorOutput | ConvertFrom-Json
  }
  [IO.File]::WriteAllText(
    $summaryPath,
    ($summary | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
  )
  if ($validationLevel -ne 'Provider') {
    throw 'What-if content is safe, but deployment permissions were not proven (ProviderNoRbac fallback).'
  }
  Write-Host "ACA pilot preflight passed. Evidence: $EvidenceDirectory"
}
finally {
  $privateKey = ''
  $parameters = $null
  if (Test-Path -LiteralPath $parameterPath) {
    Remove-Item -LiteralPath $parameterPath -Force
  }
}
