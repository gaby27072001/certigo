[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $SubscriptionId,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $VmName,

  [string] $ResourceGroupName = 'RG-CERTIGO-CI',
  [string] $ScaleSetName = 'vmss-certigo-pr-pilot-z1',
  [string] $NetworkSecurityGroupName = 'nsg-certigo-pr-pilot',
  [string] $Location = 'westeurope',
  [Parameter(Mandatory)]
  [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$')]
  [string] $Repository,

  # Registers the runner of the rebuild drill with the single label certigo-rebuild-drill and
  # no default labels, so that no workflow can target it. Allowed only on the drill resources.
  [switch] $RebuildDrill
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$apiVersion = '2024-11-01'
$armHeaders = $null
$registrationToken = $null
$drillLabel = 'certigo-rebuild-drill'
$registrationModeLine = "registration_mode='production'"
$repositoryUrl = "https://github.com/$Repository"
$repositoryGuard = "expected_repository_url='$repositoryUrl'`n"

$targetsDrillResources = (
  $ResourceGroupName -eq 'rg-certigo-ci-rebuild-drill' -or
  $ScaleSetName -eq 'vmss-certigo-pr-rebuild-drill' -or
  $NetworkSecurityGroupName -eq 'nsg-certigo-pr-rebuild-drill'
)
$allDrillResources = (
  $ResourceGroupName -eq 'rg-certigo-ci-rebuild-drill' -and
  $ScaleSetName -eq 'vmss-certigo-pr-rebuild-drill' -and
  $NetworkSecurityGroupName -eq 'nsg-certigo-pr-rebuild-drill'
)
if ($RebuildDrill -and -not $allDrillResources) {
  throw 'The rebuild drill registers only on rg-certigo-ci-rebuild-drill, vmss-certigo-pr-rebuild-drill and nsg-certigo-pr-rebuild-drill.'
}
if (-not $RebuildDrill -and $targetsDrillResources) {
  throw 'Drill resources must be registered with -RebuildDrill, so that no workflow can target the runner.'
}

function Invoke-NativeText {
  param(
    [Parameter(Mandatory)]
    [string] $FilePath,

    [Parameter(Mandatory)]
    [string[]] $ArgumentList
  )

  $output = & $FilePath @ArgumentList
  if ($LASTEXITCODE -ne 0) {
    throw "$FilePath failed with exit code $LASTEXITCODE."
  }

  return ($output -join "`n").Trim()
}

function Invoke-ManagedRunCommand {
  param(
    [Parameter(Mandatory)]
    [string] $Name,

    [Parameter(Mandatory)]
    [string] $Script,

    [string] $ProtectedValue
  )

  $commandUri = (
    'https://management.azure.com/subscriptions/{0}/resourceGroups/{1}' +
    '/providers/Microsoft.Compute/virtualMachines/{2}/runCommands/{3}?api-version={4}'
  ) -f $SubscriptionId, $ResourceGroupName, $VmName, $Name, $apiVersion

  $properties = @{
    source = @{
      script = $Script.Replace("`r`n", "`n")
    }
    runAsUser = 'root'
    asyncExecution = $false
    timeoutInSeconds = 600
  }
  if ($PSBoundParameters.ContainsKey('ProtectedValue')) {
    $properties.protectedParameters = @(
      @{
        name = ''
        value = $ProtectedValue
      }
    )
  }

  $body = @{
    location = $Location
    properties = $properties
  } | ConvertTo-Json -Depth 8 -Compress

  try {
    $null = Invoke-RestMethod `
      -Uri $commandUri `
      -Method Put `
      -Headers $armHeaders `
      -ContentType 'application/json' `
      -Body $body `
      -TimeoutSec 660

    $deadline = (Get-Date).AddMinutes(12)
    do {
      $result = Invoke-RestMethod `
        -Uri "$commandUri&`$expand=instanceView" `
        -Method Get `
        -Headers $armHeaders `
        -TimeoutSec 30
      $executionState = $result.properties.instanceView.executionState
      if ($executionState -in @('Succeeded', 'Failed')) {
        break
      }
      if ((Get-Date) -ge $deadline) {
        throw "Managed Run Command $Name timed out."
      }
      Start-Sleep -Seconds 3
    } while ($true)

    $instanceView = $result.properties.instanceView
    if ($executionState -ne 'Succeeded' -or $instanceView.exitCode -ne 0) {
      throw "Managed Run Command $Name failed: $($instanceView.error)"
    }

    return $instanceView.output
  }
  finally {
    try {
      $null = Invoke-RestMethod `
        -Uri $commandUri `
        -Method Delete `
        -Headers $armHeaders `
        -TimeoutSec 60
    }
    catch {
      Write-Warning "Delete the Managed Run Command resource '$Name' manually."
    }
  }
}

foreach ($command in @('az', 'gh')) {
  if ($null -eq (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Required command '$command' is not installed."
  }
}

$vm = Invoke-NativeText -FilePath 'az' -ArgumentList @(
  'vm', 'show',
  '--subscription', $SubscriptionId,
  '--resource-group', $ResourceGroupName,
  '--name', $VmName,
  '--show-details',
  '--output', 'json'
) | ConvertFrom-Json

if ($vm.provisioningState -ne 'Succeeded' -or $vm.powerState -ne 'VM running') {
  throw 'The pilot VM must be provisioned and running before registration.'
}
if ($vm.virtualMachineScaleSet.id.Split('/')[-1] -ne $ScaleSetName) {
  throw "The VM is not a member of the expected scale set '$ScaleSetName'."
}
# Sous Set-StrictMode, `$vm.identity` leve quand az omet la propriete, c'est-a-dire
# precisement dans le cas conforme. Le test doit rester faux sans identite et vrai avec.
$identityProperty = $vm.PSObject.Properties['identity']
if ($null -ne $identityProperty -and $null -ne $identityProperty.Value) {
  throw 'The PR-only pilot VM must not have a managed identity.'
}
$osProfileProperty = $vm.PSObject.Properties['osProfile']
if ($null -eq $osProfileProperty -or [string]::IsNullOrWhiteSpace($vm.osProfile.computerName)) {
  throw 'The pilot VM must expose its computer name, which becomes the runner name.'
}

$nicReferences = Invoke-NativeText -FilePath 'az' -ArgumentList @(
  'vm', 'nic', 'list',
  '--subscription', $SubscriptionId,
  '--resource-group', $ResourceGroupName,
  '--vm-name', $VmName,
  '--output', 'json'
) | ConvertFrom-Json
# `az vm nic list` ne rend que des references (id/primary) : sans resolution, la boucle
# ci-dessous n'inspectait jamais aucune ipConfiguration et passait toujours au vert.
$inspectedIpConfigurations = 0
foreach ($nicReference in @($nicReferences)) {
  $nic = Invoke-NativeText -FilePath 'az' -ArgumentList @(
    'network', 'nic', 'show',
    '--subscription', $SubscriptionId,
    '--ids', $nicReference.id,
    '--output', 'json'
  ) | ConvertFrom-Json
  foreach ($ipConfiguration in @($nic.ipConfigurations)) {
    $inspectedIpConfigurations++
    $publicIpProperty = $ipConfiguration.PSObject.Properties['publicIPAddress']
    if ($null -ne $publicIpProperty -and $null -ne $publicIpProperty.Value) {
      throw 'The PR-only pilot VM must not have a public IP configuration.'
    }
  }
}
if ($inspectedIpConfigurations -lt 1) {
  throw 'No IP configuration could be inspected; the public IP assertion would be vacuous.'
}

$imdsRule = Invoke-NativeText -FilePath 'az' -ArgumentList @(
  'network', 'nsg', 'rule', 'show',
  '--subscription', $SubscriptionId,
  '--resource-group', $ResourceGroupName,
  '--nsg-name', $NetworkSecurityGroupName,
  '--name', 'deny-imds-outbound',
  '--output', 'json'
) | ConvertFrom-Json
if (
  $imdsRule.access -ne 'Deny' -or
  $imdsRule.direction -ne 'Outbound' -or
  $imdsRule.destinationAddressPrefix -ne 'AzurePlatformIMDS'
) {
  throw 'The final NSG IMDS deny must be active before registration.'
}

$armAccessToken = Invoke-NativeText -FilePath 'az' -ArgumentList @(
  'account', 'get-access-token',
  '--subscription', $SubscriptionId,
  '--resource', 'https://management.azure.com/',
  '--query', 'accessToken',
  '--output', 'tsv'
)
$armHeaders = @{
  Authorization = "Bearer $armAccessToken"
}
$armAccessToken = $null

$preflightScript = Get-Content `
  -LiteralPath (Join-Path $PSScriptRoot 'pilot-preflight.sh') `
  -Raw
$preflightScript = $repositoryGuard + $preflightScript
$preflightOutput = Invoke-ManagedRunCommand `
  -Name 'certigo-pr-final-preflight' `
  -Script $preflightScript
if ($preflightOutput -notmatch 'pre-registration preflight passed') {
  throw 'The final pre-registration preflight did not produce its success marker.'
}

$runnerIdsBefore = @(
  (
    Invoke-NativeText -FilePath 'gh' -ArgumentList @(
      'api', "repos/$Repository/actions/runners?per_page=100"
    ) | ConvertFrom-Json
  ).runners.id
)

try {
  $registrationToken = Invoke-NativeText -FilePath 'gh' -ArgumentList @(
    'api', '--method', 'POST',
    "repos/$Repository/actions/runners/registration-token",
    '--jq', '.token'
  )
  if ([string]::IsNullOrWhiteSpace($registrationToken)) {
    throw 'GitHub returned an empty repository-scoped registration token.'
  }

  $registerScript = Get-Content `
    -LiteralPath (Join-Path $PSScriptRoot 'pilot-register.sh') `
    -Raw
  $registerScript = $repositoryGuard + $registerScript
  $modeLineCount = [regex]::Matches($registerScript, [regex]::Escape($registrationModeLine)).Count
  if ($modeLineCount -ne 1) {
    throw "pilot-register.sh must contain exactly one line $registrationModeLine (found $modeLineCount)."
  }
  if ($RebuildDrill) {
    $registerScript = $registerScript.Replace($registrationModeLine, "registration_mode='rebuild-drill'")
  }
  $registrationOutput = Invoke-ManagedRunCommand `
    -Name 'certigo-pr-secure-register' `
    -Script $registerScript `
    -ProtectedValue $registrationToken
}
finally {
  $registrationToken = $null
  [GC]::Collect()
}

if ($registrationOutput -notmatch 'registered and held offline') {
  throw 'The registration command did not produce its success marker.'
}

$deadline = (Get-Date).AddMinutes(3)
do {
  $runners = (
    Invoke-NativeText -FilePath 'gh' -ArgumentList @(
      'api', "repos/$Repository/actions/runners?per_page=100"
    ) | ConvertFrom-Json
  ).runners
  $newRunners = @($runners | Where-Object { $_.id -notin $runnerIdsBefore })
  if ($RebuildDrill) {
    # Only the runner of this VM is considered: its name is the VM computer name.
    $ownRunners = @($newRunners | Where-Object { $_.name -eq $vm.osProfile.computerName })
    $pilot = @($ownRunners | Where-Object { (@($_.labels.name) -join ',') -eq $drillLabel })
    $unexpected = @($ownRunners | Where-Object { (@($_.labels.name) -join ',') -ne $drillLabel })
    if ($unexpected.Count -gt 0) {
      # A drill runner with any other label could pick up a real job: remove it before failing.
      foreach ($runner in $unexpected) {
        $null = Invoke-NativeText -FilePath 'gh' -ArgumentList @(
          'api', '--method', 'DELETE', "repos/$Repository/actions/runners/$($runner.id)"
        )
      }
      throw "The drill runner registered with labels other than exactly '$drillLabel'; it was removed."
    }
  }
  else {
    $pilot = @($newRunners | Where-Object { $_.name -eq $vm.osProfile.computerName })
    if ($pilot.Count -eq 1) {
      $actualLabels = @($pilot[0].labels.name | Sort-Object)
      $expectedLabels = @('self-hosted', 'Linux', 'X64', 'certigo-pr', 'certigo-pr-pilot' | Sort-Object)
      if (@(Compare-Object $expectedLabels $actualLabels -CaseSensitive).Count -ne 0) {
        throw 'The held pilot runner has unexpected labels; do not activate it.'
      }
    }
  }
  if ($pilot.Count -eq 1 -and $pilot[0].status -eq 'offline') {
    break
  }
  if ((Get-Date) -ge $deadline) {
    throw 'The newly registered PR-only runner was not verified held offline.'
  }
  Start-Sleep -Seconds 2
} while ($true)

[pscustomobject] @{
  id = $pilot[0].id
  name = $pilot[0].name
  status = $pilot[0].status
  busy = $pilot[0].busy
  labels = @($pilot[0].labels.name)
}
