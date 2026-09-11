<#
.SYNOPSIS
    Launch the Certigo mobile app in a browser against the development backend.

.DESCRIPTION
    Wraps `flutter run -d web-server` with the one step that is easy to skip and
    expensive to diagnose: warming the development Function App first.

    Measured on 2026-09-10: the Dio client aborts a connection after 12 s
    (`connectionTimeout`), while a cold start of the dev Function App exceeds
    that. Registration then fails with `cause=timeout` and the app silently
    returns to the same form — it looks like a broken account flow, not a cold
    start. Once warm the same endpoints answer in 170-1700 ms.

    No credential is needed and none is accepted: the app's compile-time default
    for API_BASE_URL already points at the dev backend, and the dev backend runs
    with AUTH_MODE=dev.

.PARAMETER Port
    Port to serve the web app on. Defaults to 8080.

.PARAMETER ApiBase
    Development API base URL. Defaults to the app's own compile-time fallback.

.PARAMETER SkipWarmup
    Skip the warm-up probes. Only useful when the backend is known to be warm.

.EXAMPLE
    pwsh tools/run_dev_web.ps1

.EXAMPLE
    pwsh tools/run_dev_web.ps1 -Port 8090
#>
[CmdletBinding()]
param(
    [int]$Port = 8080,
    [string]$ApiBase = 'https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api',
    [switch]$SkipWarmup
)

$ErrorActionPreference = 'Stop'

if ($ApiBase -match 'prod|staging') {
    throw "Refusing to target '$ApiBase': this launcher is development-only."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $repoRoot 'apps/mobile'
if (-not (Test-Path (Join-Path $mobile 'pubspec.yaml'))) {
    throw "Could not find apps/mobile under '$repoRoot'."
}

if (-not $SkipWarmup) {
    Write-Host 'Warming the dev backend (a cold start outlasts the app''s 12s timeout)...'
    $warm = $false
    foreach ($attempt in 1..5) {
        $elapsed = [Diagnostics.Stopwatch]::StartNew()
        try {
            $response = Invoke-WebRequest -Uri "$ApiBase/health" -TimeoutSec 90 -SkipHttpErrorCheck
            $elapsed.Stop()
            Write-Host ("  probe {0}: HTTP {1} in {2} ms" -f $attempt, $response.StatusCode, $elapsed.ElapsedMilliseconds)
            # Two consecutive fast answers mean the worker is up, not just reachable.
            if ($response.StatusCode -eq 200 -and $elapsed.ElapsedMilliseconds -lt 3000) {
                $warm = $true
                break
            }
        }
        catch {
            $elapsed.Stop()
            Write-Host ("  probe {0}: failed after {1} ms ({2})" -f $attempt, $elapsed.ElapsedMilliseconds, $_.Exception.Message)
        }
    }
    if (-not $warm) {
        Write-Warning 'Backend never answered quickly. Registration may still time out client-side.'
    }
}

Write-Host ''
Write-Host "Serving the app on http://127.0.0.1:$Port (API: $ApiBase)"
Write-Host "Sign up with any e-mail; the dev backend accepts throwaway addresses."
Write-Host "To seed a learner with progression instead, set `$env:CERTIGO_DEV_SEED_PASSWORD then run:"
Write-Host '  python tools/seed_dev_demo_account.py'
Write-Host ''

Push-Location $mobile
try {
    & flutter run -d web-server --web-port=$Port --web-hostname=127.0.0.1 `
        --dart-define=API_BASE_URL=$ApiBase
}
finally {
    Pop-Location
}
