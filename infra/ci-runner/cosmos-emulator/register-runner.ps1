[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9_.()-]+$')]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9_.-]+$')]
    [string]$VmName,

    [Parameter(Mandatory)]
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repository = 'gchambaud_microsoft/Certigo'
$runCommandName = 'register-ephemeral-github-runner'
$apiVersion = '2024-11-01'
$registrationToken = $null
$requestBody = $null
$runCommandRequested = $false

if (-not $Apply) {
    throw 'Registration is live. Re-run with -Apply only in the approved post-merge window.'
}
if ($DebugPreference -ne 'SilentlyContinue') {
    throw 'Disable PowerShell debug tracing before handling a GitHub registration token.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI is required and must already be authenticated.'
}
if (-not (Get-Command Invoke-AzRestMethod -ErrorAction SilentlyContinue)) {
    throw 'Az.Accounts with Invoke-AzRestMethod is required and must already be authenticated.'
}

function Get-RestStatusCode {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    if ($null -eq $ErrorRecord.Exception.Response) {
        return $null
    }

    return [int]$ErrorRecord.Exception.Response.StatusCode
}

function Assert-RestSuccess {
    param(
        [Parameter(Mandatory)]
        $Response,

        [Parameter(Mandatory)]
        [string]$Operation
    )

    $statusCode = [int]$Response.StatusCode
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        throw "$Operation failed with HTTP status $statusCode."
    }
}

function Test-RunCommandAbsent {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    try {
        $response = Invoke-AzRestMethod -Method GET -Path $Path
        if ([int]$response.StatusCode -eq 404) {
            return $true
        }
        Assert-RestSuccess -Response $response -Operation 'Managed Run Command deletion check'
        return $false
    }
    catch {
        if ((Get-RestStatusCode -ErrorRecord $_) -eq 404) {
            return $true
        }
        throw
    }
}

$context = Get-AzContext
if (-not $context -or -not $context.Subscription.Id) {
    throw 'No active Azure PowerShell subscription context.'
}

$subscriptionId = $context.Subscription.Id
$vmPath = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Compute/virtualMachines/$VmName"
$runCommandPath = "$vmPath/runCommands/$runCommandName"

if (-not $PSCmdlet.ShouldProcess(
        "$ResourceGroupName/$VmName",
        'Register one ephemeral repository runner through a protected Managed Run Command'
    )) {
    return
}

try {
    $vmResponse = Invoke-AzRestMethod `
        -Method GET `
        -Path "$vmPath`?api-version=$apiVersion"
    Assert-RestSuccess -Response $vmResponse -Operation 'Target VM lookup'
    $vm = $vmResponse.Content | ConvertFrom-Json -Depth 10
    if ($vm.identity) {
        throw 'The one-shot Cosmos runner must not have a managed identity.'
    }
    if ($vm.tags.runnerClass -ne 'certigo-cosmos-emulator' -or
        $vm.tags.lifecycle -ne 'one-shot' -or
        $vm.tags.trustBoundary -ne 'merged-main-only' -or
        $vm.tags.managedIdentity -ne 'none' -or
        $vm.tags.registrationChannel -ne 'protected-managed-run-command') {
        throw 'The target VM is not tagged as the disposable Cosmos emulator runner.'
    }

    $registrationToken = ((& gh api `
            --method POST `
            "repos/$repository/actions/runners/registration-token" `
            --jq .token | Out-String).Trim())
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($registrationToken)) {
        throw 'GitHub did not return an ephemeral repository registration token.'
    }

    $remoteScript = @'
set -euo pipefail
set +x
if [[ -z "${RUNNER_TOKEN:-}" ]]; then
  echo "Protected RUNNER_TOKEN is missing." >&2
  exit 2
fi
registration_token="${RUNNER_TOKEN}"
unset RUNNER_TOKEN
trap 'unset registration_token RUNNER_TOKEN' EXIT
for _ in $(seq 1 120); do
  if [[ -x /usr/local/sbin/certigo-cosmos-runner-bootstrap ]]; then
    break
  fi
  sleep 5
done
if [[ ! -x /usr/local/sbin/certigo-cosmos-runner-bootstrap ]]; then
  echo "Base bootstrap did not install the registration entry point within 10 minutes." >&2
  exit 1
fi
printf '%s\n' "${registration_token}" |
  env -u RUNNER_TOKEN \
    /usr/local/sbin/certigo-cosmos-runner-bootstrap --register --token-stdin
unset registration_token
trap - EXIT
'@

    $requestBody = @{
        location = $vm.location
        properties = @{
            source = @{
                script = $remoteScript
            }
            protectedParameters = @(
                @{
                    name = 'RUNNER_TOKEN'
                    value = $registrationToken
                }
            )
            timeoutInSeconds = 2100
            treatFailureAsDeploymentFailure = $true
        }
    } | ConvertTo-Json -Depth 10 -Compress

    $runCommandRequested = $true
    $putResponse = Invoke-AzRestMethod `
        -Method PUT `
        -Path "$runCommandPath`?api-version=$apiVersion" `
        -Payload $requestBody
    Assert-RestSuccess -Response $putResponse -Operation 'Managed Run Command creation'

    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(36)
    do {
        Start-Sleep -Seconds 5
        $statusResponse = Invoke-AzRestMethod `
            -Method GET `
            -Path "$runCommandPath`?api-version=$apiVersion&`$expand=instanceView"
        Assert-RestSuccess -Response $statusResponse -Operation 'Managed Run Command status check'
        $status = $statusResponse.Content | ConvertFrom-Json -Depth 20
        $provisioningState = $status.properties.provisioningState
        $executionState = $status.properties.instanceView.executionState
        if ($provisioningState -eq 'Failed' -or
            $executionState -in @('Failed', 'TimedOut', 'Canceled')) {
            throw "Protected registration Run Command failed: $executionState."
        }
    } while (
        $executionState -ne 'Succeeded' -and
        [DateTimeOffset]::UtcNow -lt $deadline
    )

    if ($executionState -ne 'Succeeded') {
        throw 'Protected registration Run Command timed out.'
    }

    Write-Host "Ephemeral runner $VmName registered. The protected Run Command will now be removed."
}
finally {
    $registrationToken = $null
    $requestBody = $null
    [GC]::Collect()
    if ($runCommandRequested) {
        $runCommandRequestPath = "$runCommandPath`?api-version=$apiVersion"
        try {
            $deleteResponse = Invoke-AzRestMethod `
                -Method DELETE `
                -Path $runCommandRequestPath
            if ([int]$deleteResponse.StatusCode -ne 404) {
                Assert-RestSuccess `
                    -Response $deleteResponse `
                    -Operation 'Managed Run Command deletion'
            }
        }
        catch {
            if ((Get-RestStatusCode -ErrorRecord $_) -ne 404) {
                throw
            }
        }

        $deletionDeadline = [DateTimeOffset]::UtcNow.AddMinutes(3)
        while (-not (Test-RunCommandAbsent -Path $runCommandRequestPath)) {
            if ([DateTimeOffset]::UtcNow -ge $deletionDeadline) {
                throw 'Timed out while confirming Managed Run Command deletion.'
            }
            Start-Sleep -Seconds 2
        }
    }
}
