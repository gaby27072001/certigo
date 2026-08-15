param(
    [switch]$RequireEmulator
)

$ErrorActionPreference = 'Stop'
$project = Join-Path $PSScriptRoot 'tests\Certigo.Infrastructure.Tests\Certigo.Infrastructure.Tests.csproj'

dotnet test $project `
    --configuration Release `
    --filter 'FullyQualifiedName~CosmosSerializationTests' `
    --verbosity minimal
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($env:CERTIGO_COSMOS_TESTS -ne '1') {
    if ($RequireEmulator) {
        Write-Error 'Cosmos emulator gate requested but CERTIGO_COSMOS_TESTS is not set to 1.'
        exit 1
    }

    Write-Host 'Cosmos wire-contract gate passed; emulator integration tests were explicitly skipped.'
    Write-Host 'Set CERTIGO_COSMOS_TESTS=1 and COSMOS_EMULATOR_CONNECTION_STRING or COSMOS_EMULATOR_KEY to run them.'
    exit 0
}

if ([string]::IsNullOrWhiteSpace($env:COSMOS_EMULATOR_CONNECTION_STRING) `
    -and [string]::IsNullOrWhiteSpace($env:COSMOS_EMULATOR_KEY)) {
    Write-Error 'CERTIGO_COSMOS_TESTS=1 requires a local emulator connection string or key.'
    exit 1
}

dotnet test $project `
    --configuration Release `
    --filter 'FullyQualifiedName~CosmosRepositoriesIntegrationTests' `
    --verbosity normal
exit $LASTEXITCODE
