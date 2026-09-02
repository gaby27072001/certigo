[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $SubscriptionId,

  [Parameter(Mandatory)]
  [ValidateSet('Promote', 'Rollback')]
  [string] $Direction,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $CandidateGalleryImageVersionId,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $PreviousGalleryImageVersionId,

  [Parameter(Mandatory)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string] $AdminSshPublicKeyPath,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $ExpiresOn,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string] $Authorization,

  [Parameter(Mandatory)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string] $ReleaseEvidencePath,

  [Parameter(Mandatory)]
  [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
  [string] $ImageDescriptorPath,

  [switch] $Apply,

  [string] $ResourceGroupName = 'rg-certigo-runner-image-runtime-canary',
  [string] $Location = 'westeurope',
  [string] $EvidenceDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Authorization -ne 'CERTIGO-RUNNER-CANARY-LIVE-AUTHORIZED') {
  throw 'Explicit later authorization is required before any Azure or what-if call.'
}

$scriptRoot = $PSScriptRoot
$contract = Get-Content -LiteralPath (Join-Path $scriptRoot 'canary-contract.json') -Raw |
  ConvertFrom-Json
$buildContract = Get-Content `
  -LiteralPath (Join-Path $scriptRoot 'image-build-contract.json') `
  -Raw | ConvertFrom-Json
$attestationPolicy = Get-Content `
  -LiteralPath (Join-Path $scriptRoot 'attestation-policy.json') `
  -Raw | ConvertFrom-Json
if ($contract.liveOperationsAuthorized -ne $false) {
  throw 'The checked-in contract must remain fail-closed.'
}
if (
  $buildContract.policy.reproducibleInputsReady -ne $true -or
  $buildContract.reproducibility.status -ne 'locked' -or
  [string]::IsNullOrWhiteSpace($buildContract.reproducibility.aptSnapshot) -or
  $buildContract.reproducibility.aptPackageLockSha256 -notmatch '^[0-9a-f]{64}$' -or
  $buildContract.reproducibility.flutterEngineArtifactLockSha256 -notmatch '^[0-9a-f]{64}$'
) {
  throw 'Image transition is blocked until APT and Flutter network artifacts are fully locked.'
}
if (
  $attestationPolicy.activation.status -ne 'active' -or
  $attestationPolicy.signerDigest -notmatch '^[0-9a-f]{40}$'
) {
  throw 'Image transition is blocked until the exact attestation signer digest is pinned.'
}
if ($ResourceGroupName -ne $contract.resourceGroups.runtime) {
  throw "Runtime operations are restricted to '$($contract.resourceGroups.runtime)'."
}

$versionPattern =
  '^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.Compute/' +
  'galleries/[^/]+/images/[^/]+/versions/[0-9]+\.[0-9]+\.[0-9]+$'
foreach ($imageId in @($CandidateGalleryImageVersionId, $PreviousGalleryImageVersionId)) {
  if ($imageId -notmatch $versionPattern -or $imageId -match '/latest$') {
    throw "Image '$imageId' is not an exact Azure Compute Gallery version ID."
  }
  foreach ($reserved in @(
      $contract.reserved.virtualMachineTokens +
      $contract.reserved.existingScaleSets
    )) {
    if ($imageId.Contains($reserved, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Image ID contains reserved token '$reserved'."
    }
  }
}
if ($CandidateGalleryImageVersionId -eq $PreviousGalleryImageVersionId) {
  throw 'Candidate and previous image versions must be distinct.'
}
$expectedCandidateSuffix = (
  "/resourceGroups/$($contract.resourceGroups.imageBuild)/providers/Microsoft.Compute/" +
  "galleries/$($buildContract.destination.galleryName)/images/" +
  "$($buildContract.destination.imageDefinitionName)/versions/" +
  "$($buildContract.destination.imageVersion)"
)
if (
  -not $CandidateGalleryImageVersionId.StartsWith(
    "/subscriptions/$SubscriptionId",
    [StringComparison]::OrdinalIgnoreCase
  ) -or
  -not $CandidateGalleryImageVersionId.EndsWith(
    $expectedCandidateSuffix,
    [StringComparison]::OrdinalIgnoreCase
  )
) {
  throw 'Candidate image is not the exact contract-pinned AIB output.'
}
$expectedPreviousPrefix = (
  "/subscriptions/$SubscriptionId/resourceGroups/$($contract.resourceGroups.imageBuild)/" +
  "providers/Microsoft.Compute/galleries/$($buildContract.destination.galleryName)/images/" +
  "$($buildContract.destination.imageDefinitionName)/versions/"
)
if (
  -not $PreviousGalleryImageVersionId.StartsWith(
    $expectedPreviousPrefix,
    [StringComparison]::OrdinalIgnoreCase
  )
) {
  throw 'Previous image must be an exact version from the contracted gallery.'
}

$expiry = [DateTimeOffset]::Parse($ExpiresOn)
$maximumExpiry = [DateTimeOffset]::UtcNow.AddHours(
  [double] $contract.budget.maximumLifetimeHours
)
if ($expiry -le [DateTimeOffset]::UtcNow -or $expiry -gt $maximumExpiry) {
  throw "expiresOn must be within $($contract.budget.maximumLifetimeHours) hours."
}

foreach ($command in @('az', 'gh', 'node')) {
  if ($null -eq (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "Required command '$command' is not installed."
  }
}
foreach ($predicateType in @('https://slsa.dev/provenance/v1', 'https://cyclonedx.org/bom')) {
  & gh attestation verify $ImageDescriptorPath `
    --repo $buildContract.repository `
    --predicate-type $predicateType `
    --signer-repo $buildContract.repository `
    --signer-workflow $attestationPolicy.signerWorkflow `
    --signer-digest $attestationPolicy.signerDigest `
    --source-ref $attestationPolicy.sourceRef `
    --source-digest $attestationPolicy.signerDigest
  if ($LASTEXITCODE -ne 0) {
    throw "Missing or invalid GitHub attestation '$predicateType'."
  }
}

$targetImageId = if ($Direction -eq 'Rollback') {
  $PreviousGalleryImageVersionId
}
else {
  $CandidateGalleryImageVersionId
}
$rollbackImageId = if ($Direction -eq 'Rollback') {
  $CandidateGalleryImageVersionId
}
else {
  $PreviousGalleryImageVersionId
}

if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  $EvidenceDirectory = Join-Path $scriptRoot 'evidence'
}
$null = New-Item -ItemType Directory -Path $EvidenceDirectory -Force
$timestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$descriptor = Get-Content -LiteralPath $ImageDescriptorPath -Raw | ConvertFrom-Json
$expectedImageTemplateId = (
  "/subscriptions/$SubscriptionId/resourceGroups/$($contract.resourceGroups.imageBuild)/" +
  "providers/Microsoft.VirtualMachineImages/imageTemplates/" +
  $buildContract.destination.imageTemplateName
)
$expectedRunOutputId = (
  "$expectedImageTemplateId/runOutputs/$($buildContract.destination.runOutputName)"
)
if (
  $descriptor.galleryImageVersionId -ne $CandidateGalleryImageVersionId -or
  $descriptor.runOutputResourceId -ne $expectedRunOutputId -or
  $descriptor.immutableBuildEvidence.imageTemplateId -ne $expectedImageTemplateId -or
  $descriptor.immutableBuildEvidence.runOutputResourceId -ne $expectedRunOutputId -or
  $descriptor.immutableBuildEvidence.galleryImageVersionId -ne $CandidateGalleryImageVersionId
) {
  throw 'Attested descriptor does not name the exact contracted AIB output and image version.'
}

function Assert-CurrentImageBuildEvidence {
  param([Parameter(Mandatory)][string] $Phase)

  $checks = @(
    @{
      Kind = 'run-output'
      Id = $expectedRunOutputId
      ApiVersion = '2025-10-01'
      Expected = $descriptor.immutableBuildEvidence.runOutputSha256
    },
    @{
      Kind = 'image-template'
      Id = $expectedImageTemplateId
      ApiVersion = '2025-10-01'
      Expected = $descriptor.immutableBuildEvidence.imageTemplateSha256
    },
    @{
      Kind = 'gallery-version'
      Id = $CandidateGalleryImageVersionId
      ApiVersion = '2024-03-03'
      Expected = $descriptor.immutableBuildEvidence.galleryVersionSha256
    }
  )
  foreach ($check in $checks) {
    if ($check.Expected -notmatch '^[0-9a-f]{64}$') {
      throw "Attested $($check.Kind) hash is missing or invalid."
    }
    $path = Join-Path $EvidenceDirectory "$($check.Kind)-$timestamp-$Phase.json"
    $resourceJson = & az resource show `
      --ids $check.Id `
      --api-version $check.ApiVersion `
      --output json
    if ($LASTEXITCODE -ne 0) {
      throw "Could not read current Azure $($check.Kind) evidence."
    }
    $resourceJson | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    $actual = & node (Join-Path $scriptRoot 'validate-canary-evidence.mjs') `
      --hash-azure-evidence $check.Kind $path
    if ($LASTEXITCODE -ne 0 -or $actual.Trim() -ne $check.Expected) {
      throw "Current Azure $($check.Kind) state does not match the attested immutable evidence."
    }
  }

  $runOutput = Get-Content `
    -LiteralPath (Join-Path $EvidenceDirectory "run-output-$timestamp-$Phase.json") `
    -Raw | ConvertFrom-Json
  if (
    $runOutput.properties.provisioningState -ne 'Succeeded' -or
    $runOutput.properties.artifactId -ne $CandidateGalleryImageVersionId
  ) {
    throw 'Current AIB run output no longer resolves to the exact candidate image version.'
  }
}

Assert-CurrentImageBuildEvidence -Phase 'pre-what-if'
$whatIfPath = Join-Path $EvidenceDirectory "$($Direction.ToLowerInvariant())-$timestamp.what-if.json"
$compiledTemplatePath = Join-Path `
  $EvidenceDirectory `
  "$($Direction.ToLowerInvariant())-$timestamp.compiled-arm.json"
$deploymentName = "certigo-runner-image-$($Direction.ToLowerInvariant())-$timestamp"
$sshPublicKey = (Get-Content -LiteralPath $AdminSshPublicKeyPath -Raw).Trim()
if ($sshPublicKey -notmatch '^ssh-(rsa|ed25519) ') {
  throw 'The break-glass key must be an OpenSSH RSA or Ed25519 public key.'
}
& az bicep build `
  --file (Join-Path $scriptRoot 'canary-main.bicep') `
  --outfile $compiledTemplatePath
if ($LASTEXITCODE -ne 0) {
  throw 'Canary ARM compilation failed.'
}
$compiledTemplateSha256 = (
  Get-FileHash -LiteralPath $compiledTemplatePath -Algorithm SHA256
).Hash.ToLowerInvariant()

$commonArguments = @(
  '--subscription', $SubscriptionId,
  '--name', $deploymentName,
  '--location', $Location,
  '--template-file', $compiledTemplatePath,
  '--parameters',
  'deploymentEnabled=true',
  "galleryImageVersionId=$targetImageId",
  "previousGalleryImageVersionId=$rollbackImageId",
  "adminSshPublicKey=$sshPublicKey",
  "location=$Location",
  "expiresOn=$($expiry.ToString('o'))"
)

$whatIf = & az deployment sub what-if @commonArguments `
  --result-format FullResourcePayloads `
  --output json
if ($LASTEXITCODE -ne 0) {
  throw 'Azure what-if failed.'
}
$whatIf | Set-Content -LiteralPath $whatIfPath -Encoding utf8NoBOM
$rawEvidence = Get-Content -LiteralPath $ReleaseEvidencePath -Raw | ConvertFrom-Json
$normalizedExpiry = $expiry.ToString('o')
$rawEvidence.cleanup.expiresOn = $normalizedExpiry
$rawEvidence.whatIf.capturedAt = [DateTimeOffset]::UtcNow.ToString('o')
$rawEvidence.whatIf.resultSha256 = (
  Get-FileHash -LiteralPath $whatIfPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$rawEvidence.whatIf.validated = $true
$rawEvidence.imageBuild.descriptorSha256 = (
  Get-FileHash -LiteralPath $ImageDescriptorPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$rawEvidence.whatIf.provenance.subscriptionId = $SubscriptionId
$rawEvidence.whatIf.provenance.templateSha256 = $compiledTemplateSha256
$rawEvidence.whatIf.provenance.buildContractSha256 = (
  Get-FileHash `
    -LiteralPath (Join-Path $scriptRoot 'image-build-contract.json') `
    -Algorithm SHA256
).Hash.ToLowerInvariant()
$rawEvidence.whatIf.provenance.descriptorSha256 =
  $rawEvidence.imageBuild.descriptorSha256
$rawEvidence.whatIf.provenance.direction = $Direction
$rawEvidence.whatIf.provenance.targetImageVersionId = $targetImageId
$rawEvidence.whatIf.provenance.previousImageVersionId = $rollbackImageId
$workingEvidencePath = Join-Path `
  $EvidenceDirectory `
  "$($Direction.ToLowerInvariant())-$timestamp.release-evidence.json"
$rawEvidence | ConvertTo-Json -Depth 20 |
  Set-Content -LiteralPath $workingEvidencePath -Encoding utf8NoBOM
$validationOutput = & node (Join-Path $scriptRoot 'validate-canary-evidence.mjs') `
  --release `
  $workingEvidencePath `
  $whatIfPath `
  $ImageDescriptorPath `
  $compiledTemplatePath `
  $SubscriptionId `
  $Direction `
  $targetImageId `
  $Location `
  $sshPublicKey
if ($LASTEXITCODE -ne 0) {
  throw 'Canary release evidence or what-if validation failed closed.'
}
$validationResult = $validationOutput | ConvertFrom-Json
if ($validationResult.transitionKind -notin @('initial-create', 'image-update')) {
  throw 'Canary release validation did not return an exact transition kind.'
}

if (-not $Apply) {
  [pscustomobject] @{
    direction = $Direction
    apply = $false
    targetImageVersionId = $targetImageId
    rollbackImageVersionId = $rollbackImageId
    whatIfEvidence = $whatIfPath
  }
  return
}

$expectedCurrentImageId = if ($Direction -eq 'Rollback') {
  $CandidateGalleryImageVersionId
}
else {
  $PreviousGalleryImageVersionId
}
if ($validationResult.transitionKind -eq 'initial-create') {
  $runtimeGroupExists = & az group exists `
    --subscription $SubscriptionId `
    --name $ResourceGroupName `
    --output tsv
  if ($LASTEXITCODE -ne 0 -or $runtimeGroupExists -notin @('true', 'false')) {
    throw 'Could not prove whether the isolated runtime group exists.'
  }
  if ($Direction -ne 'Promote' -or $runtimeGroupExists -ne 'false') {
    throw 'Initial Promote requires an absent runtime group and the complete validated Create set.'
  }
  $currentImageId = $null
}
else {
  $currentImageId = & az vmss show `
    --subscription $SubscriptionId `
    --resource-group $ResourceGroupName `
    --name $contract.resources.scaleSet `
    --query 'virtualMachineProfile.storageProfile.imageReference.id' `
    --output tsv
  if ($LASTEXITCODE -ne 0 -or $currentImageId -ne $expectedCurrentImageId) {
    throw "Transition refused: the observed current image is not '$expectedCurrentImageId'."
  }
}
$observedStatePath = Join-Path `
  $EvidenceDirectory `
  "$($Direction.ToLowerInvariant())-$timestamp.observed-current-image.json"
[pscustomobject] @{
  capturedAt = [DateTimeOffset]::UtcNow.ToString('o')
  scaleSet = $contract.resources.scaleSet
  transitionKind = $validationResult.transitionKind
  observedImageVersionId = $currentImageId
  expectedImageVersionId = $expectedCurrentImageId
} | ConvertTo-Json | Set-Content -LiteralPath $observedStatePath -Encoding utf8NoBOM

try {
  Assert-CurrentImageBuildEvidence -Phase 'pre-apply'
  $currentCompiledTemplateSha256 = (
    Get-FileHash -LiteralPath $compiledTemplatePath -Algorithm SHA256
  ).Hash.ToLowerInvariant()
  if ($currentCompiledTemplateSha256 -ne $compiledTemplateSha256) {
    throw 'Compiled ARM changed after its validated what-if.'
  }
  $preApplyWhatIfPath = Join-Path `
    $EvidenceDirectory `
    "$($Direction.ToLowerInvariant())-$timestamp.pre-apply.what-if.json"
  $preApplyWhatIf = & az deployment sub what-if @commonArguments `
    --result-format FullResourcePayloads `
    --output json
  if ($LASTEXITCODE -ne 0) {
    throw 'Pre-apply Azure what-if failed.'
  }
  $preApplyWhatIf | Set-Content -LiteralPath $preApplyWhatIfPath -Encoding utf8NoBOM
  $preApplyWhatIfSha256 = (
    Get-FileHash -LiteralPath $preApplyWhatIfPath -Algorithm SHA256
  ).Hash.ToLowerInvariant()
  if ($preApplyWhatIfSha256 -ne $rawEvidence.whatIf.resultSha256) {
    throw 'Azure state drifted after the validated what-if.'
  }
  & node (Join-Path $scriptRoot 'validate-canary-evidence.mjs') `
    --what-if `
    $preApplyWhatIfPath `
    $Direction `
    $targetImageId `
    $rollbackImageId `
    $SubscriptionId `
    $normalizedExpiry `
    $Location `
    $sshPublicKey
  if ($LASTEXITCODE -ne 0) {
    throw 'Pre-apply what-if no longer matches the exact transition contract.'
  }
  $deployment = & az deployment sub create @commonArguments --output json
  if ($LASTEXITCODE -ne 0) {
    throw 'Canary image deployment failed.'
  }
  $deployment | Set-Content `
    -LiteralPath (Join-Path $EvidenceDirectory "$deploymentName.deployment.json") `
    -Encoding utf8NoBOM

  & az vmss update-instances `
    --subscription $SubscriptionId `
    --resource-group $ResourceGroupName `
    --name $contract.resources.scaleSet `
    --instance-ids '*' `
    --output none
  if ($LASTEXITCODE -ne 0) {
    throw 'The capacity-one canary instance did not adopt the exact image model.'
  }
}
catch {
  if ($Direction -eq 'Rollback') {
    Write-Error 'Rollback failed after its clean what-if; the isolated canary must remain unrouted.'
  }
  throw
}

$appliedImageId = & az vmss show `
  --subscription $SubscriptionId `
  --resource-group $ResourceGroupName `
  --name $contract.resources.scaleSet `
  --query 'virtualMachineProfile.storageProfile.imageReference.id' `
  --output tsv
if ($LASTEXITCODE -ne 0 -or $appliedImageId -ne $targetImageId) {
  throw 'The VMSS model does not reference the requested exact image after deployment.'
}

[pscustomobject] @{
  direction = $Direction
  apply = $true
  targetImageVersionId = $targetImageId
  rollbackImageVersionId = $rollbackImageId
  whatIfEvidence = $whatIfPath
  observedCurrentImageEvidence = $observedStatePath
  deploymentName = $deploymentName
}
