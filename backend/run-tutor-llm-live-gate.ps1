param(
    [switch]$RequireLive
)

$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'tests\Certigo.Api.Tests\Certigo.Api.Tests.csproj'

if ($env:CERTIGO_TUTOR_LLM_LIVE_TESTS -ne '1') {
    if ($RequireLive) {
        Write-Error 'Tutor LLM live gate requested but CERTIGO_TUTOR_LLM_LIVE_TESTS is not set to 1.'
        exit 1
    }

    Write-Host 'Tutor LLM live end-to-end test explicitly skipped (this is the safe default).'
    Write-Host 'Set CERTIGO_TUTOR_LLM_LIVE_TESTS=1, CERTIGO_TUTOR_API_BASE_URL, CERTIGO_TUTOR_TEST_TRACK_ID,'
    Write-Host 'CERTIGO_TUTOR_TEST_LESSON_ID and CERTIGO_TUTOR_TEST_ITEM_ID to run it against a deployed'
    Write-Host 'environment where TUTOR_LLM_ENABLED=true is confirmed working end-to-end.'
    Write-Host 'See docs/deployment-runbook.md section T0.5 "Chemin 3".'
    exit 0
}

$required = @(
    'CERTIGO_TUTOR_API_BASE_URL',
    'CERTIGO_TUTOR_TEST_TRACK_ID',
    'CERTIGO_TUTOR_TEST_LESSON_ID',
    'CERTIGO_TUTOR_TEST_ITEM_ID'
)
$missing = $required | Where-Object { [string]::IsNullOrWhiteSpace((Get-Item -Path "Env:$_" -ErrorAction SilentlyContinue).Value) }
if ($missing.Count -gt 0) {
    Write-Error "CERTIGO_TUTOR_LLM_LIVE_TESTS=1 requires: $($missing -join ', ')."
    exit 1
}

dotnet test $project `
    --configuration Release `
    --filter 'FullyQualifiedName~TutorLlmLiveEndToEndTests' `
    --verbosity normal
exit $LASTEXITCODE
