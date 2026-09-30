[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $SubscriptionId,

  # One or more exact VM names; -All targets every managed runner of the inventory instead.
  [string[]] $VmName = @(),

  [switch] $All,

  [ValidateSet('install', 'status', 'uninstall')]
  [string] $Action = 'install',

  [string] $ResourceGroupName = 'rg-certigo-ci'
)

# Installe (ou lit, ou retire) l'agent d'extinction locale infra/ci-runner/idle-shutdown.sh sur
# des VM de runner, par Run Command ACTION (`az vm run-command invoke`) : aucune ressource
# enfant n'est créée, donc rien ne s'accumule sous le verrou CanNotDelete de rg-certigo-ci.
# Le script ne transporte aucun secret. La période calme vient de on-demand.config.json, selon le
# scale set de la VM. Voir docs/runbooks/CI_RUNNERS.md section 13.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Az {
  param([Parameter(Mandatory)] [string[]] $Arguments)
  $output = & az @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "az $($Arguments[0..2] -join ' ') failed with exit code $LASTEXITCODE."
  }
  return ($output -join "`n").Trim()
}

$config = Get-Content -Raw -Path (Join-Path $PSScriptRoot 'on-demand.config.json') | ConvertFrom-Json
$inventory = Get-Content -Raw -Path (Join-Path $PSScriptRoot 'capacity-controller.config.json') | ConvertFrom-Json
$excluded = @(
  @($inventory.inventory.forbiddenVirtualMachines) + @($inventory.inventory.externalVirtualMachines) |
    ForEach-Object { $_.ToLowerInvariant() }
)

if ($All) {
  if ($VmName.Count -gt 0) { throw 'Use either -VmName or -All, not both.' }
  $VmName = @($inventory.inventory.managedRunnerBindings | ForEach-Object { $_.virtualMachineName })
}
if ($VmName.Count -eq 0) { throw 'Name at least one VM with -VmName, or use -All.' }

# The agent is sent with LF line endings whatever the checkout, and never modified here.
$agentSource = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'idle-shutdown.sh')).Replace("`r`n", "`n")
$agentFile = Join-Path ([IO.Path]::GetTempPath()) ("certigo-idle-shutdown-{0}.sh" -f [guid]::NewGuid())
[IO.File]::WriteAllText($agentFile, $agentSource, (New-Object System.Text.UTF8Encoding($false)))
$agentSha256 = (Get-FileHash -Algorithm SHA256 -Path $agentFile).Hash.ToLowerInvariant()

$results = @()
try {
  foreach ($name in $VmName) {
    if ($excluded -contains $name.ToLowerInvariant()) {
      throw "$name is listed in forbiddenVirtualMachines or externalVirtualMachines; refusing."
    }
    $vm = Invoke-Az @(
      'vm', 'show', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName,
      '--name', $name, '--query', '{scaleSet: virtualMachineScaleSet.id}', '--output', 'json'
    ) | ConvertFrom-Json
    $scaleSetName = if ($vm.scaleSet) { ($vm.scaleSet -split '/')[-1] } else { '' }
    $pool = @($config.pools | Where-Object { $_.scaleSet -ieq $scaleSetName })
    if ($pool.Count -ne 1) {
      throw "$name belongs to '$scaleSetName', which is not an on-demand pool of on-demand.config.json."
    }
    $power = Invoke-Az @(
      'vm', 'get-instance-view', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName,
      '--name', $name, '--query', "instanceView.statuses[?starts_with(code, 'PowerState/')].code | [0]",
      '--output', 'tsv'
    )
    if ($power -ne 'PowerState/running') {
      throw "$name is $power; a Run Command needs a running VM (start it first, or wait for the next wake)."
    }

    $arguments = if ($Action -eq 'install') { @('install', [string] $pool[0].quietPeriodSeconds) } else { @($Action) }
    $message = Invoke-Az (@(
        'vm', 'run-command', 'invoke', '--subscription', $SubscriptionId, '--resource-group', $ResourceGroupName,
        '--name', $name, '--command-id', 'RunShellScript', '--scripts', "@$agentFile",
        '--parameters') + $arguments + @('--query', 'value[0].message', '--output', 'tsv'))

    $expected = switch ($Action) {
      'install' { 'certigo-idle-shutdown installed' }
      'uninstall' { 'certigo-idle-shutdown uninstalled' }
      'status' { 'script_sha256=' }
    }
    $succeeded = $message.Contains($expected)
    if ($Action -eq 'install') {
      $succeeded = $succeeded -and
        $message.Contains("script_sha256=$agentSha256") -and
        $message.Contains('timer=active') -and
        $message.Contains("config.QUIET_PERIOD_SECONDS=$($pool[0].quietPeriodSeconds)")
    }
    Write-Host "----- $name ($scaleSetName, $Action) -----"
    Write-Host $message
    $results += [pscustomobject]@{
      vm = $name
      pool = $scaleSetName
      action = $Action
      quietPeriodSeconds = $pool[0].quietPeriodSeconds
      agentSha256 = $agentSha256
      succeeded = $succeeded
    }
    if (-not $succeeded) {
      throw "$Action did not report success on $name; see the Run Command output above."
    }
  }
}
finally {
  Remove-Item -LiteralPath $agentFile -Force -ErrorAction SilentlyContinue
  $results | Format-Table -AutoSize | Out-String | Write-Host
}
