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

# The Run Command extension rewrites the script it receives: it inserts
# `export arg1=... arg2=...` after the first line (measured on 2026-09-30). The agent therefore
# travels as a base64 payload inside a small POSIX wrapper, so that the file installed on the VM
# is byte-for-byte the versioned agent and its SHA-256 can be verified. LF endings whatever the
# checkout.
$agentBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes(
  [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'idle-shutdown.sh')).Replace("`r`n", "`n"))
$sha = [System.Security.Cryptography.SHA256]::Create()
try { $agentSha256 = (-join ($sha.ComputeHash($agentBytes) | ForEach-Object { $_.ToString('x2') })) }
finally { $sha.Dispose() }
$payload = [Convert]::ToBase64String($agentBytes, [Base64FormattingOptions]::InsertLineBreaks).Replace("`r`n", "`n")
$wrapper = @"
#!/bin/sh
set -eu
agent="`$(mktemp /tmp/certigo-idle-shutdown.XXXXXX)"
trap 'rm -f "`$agent"' EXIT
base64 -d > "`$agent" <<'CERTIGO_AGENT_PAYLOAD'
$payload
CERTIGO_AGENT_PAYLOAD
printf 'payload_sha256=%s\n' "`$(sha256sum "`$agent" | cut -d ' ' -f 1)"
/bin/bash "`$agent" "`$@"
"@
$agentFile = Join-Path ([IO.Path]::GetTempPath()) ("certigo-idle-shutdown-{0}.sh" -f [guid]::NewGuid())
[IO.File]::WriteAllText($agentFile, $wrapper.Replace("`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))

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
    $succeeded = $message.Contains($expected) -and $message.Contains("payload_sha256=$agentSha256")
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
    # PR instances block IMDS: without both boot settings, a wake takes about 6 minutes instead
    # of 45 seconds (cloud-init waits 300 s for IMDS at every boot).
    if ($Action -eq 'install' -and $pool[0].trustClass -eq 'certigo-pr' -and -not (
        $message.Contains('imds_drop_in=present') -and
        $message.Contains('cloud_init_boot_refresh=new-instance-only'))) {
      throw "$name is a PR instance without the IMDS boot settings (is certigo-block-imds.service missing?): the agent is installed, but its wake-up will be slow."
    }
  }
}
finally {
  Remove-Item -LiteralPath $agentFile -Force -ErrorAction SilentlyContinue
  $results | Format-Table -AutoSize | Out-String | Write-Host
}
