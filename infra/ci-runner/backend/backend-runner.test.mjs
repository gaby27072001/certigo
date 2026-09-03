import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  validateGithubAttestationResults,
  verifyDeploymentBundle,
} from './verify-deployment-bundle.mjs';
import {
  validatePhysicalAttestationPayload,
  validateSignedPhysicalAttestation,
} from './validate-physical-attestation.mjs';

const backendRoot = fileURLToPath(new URL('.', import.meta.url));
const runnerRoot = path.dirname(backendRoot);
const repositoryRoot = path.resolve(runnerRoot, '..', '..');
const bicep = process.env.BICEP_CLI ?? 'bicep';

function readJson(relativePath) {
  return JSON.parse(readFileSync(path.join(backendRoot, relativePath), 'utf8'));
}

function sha256(file) {
  return crypto.createHash('sha256').update(readFileSync(file)).digest('hex');
}

function publicKeyFingerprint(publicKey) {
  return crypto
    .createHash('sha256')
    .update(publicKey.export({ type: 'spki', format: 'der' }))
    .digest('hex');
}

function compile(relativePath) {
  return JSON.parse(
    execFileSync(
      bicep,
      ['build', path.join(backendRoot, relativePath), '--stdout'],
      { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
    ),
  );
}

function resourcesOf(template) {
  const resources = [];
  function visit(candidate) {
    for (const resource of candidate.resources ?? []) {
      resources.push(resource);
      if (resource.properties?.template) {
        visit(resource.properties.template);
      }
    }
  }
  visit(template);
  return resources;
}

function filesNamed(root, name) {
  const matches = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const file = path.join(root, entry.name);
    if (entry.isDirectory()) {
      matches.push(...filesNamed(file, name));
    } else if (entry.name === name) {
      matches.push(file);
    }
  }
  return matches;
}

function toBashPath(file) {
  const normalized = path.resolve(file).replaceAll('\\', '/');
  const drive = normalized.match(/^([A-Za-z]):\/(.*)$/);
  return drive
    ? `/${drive[1].toLowerCase()}/${drive[2]}`
    : normalized;
}

function descriptor(file, bundleRoot) {
  return {
    path: path.relative(bundleRoot, file).replaceAll('\\', '/'),
    sha256: sha256(file),
    size: statSync(file).size,
  };
}

function storedZip(entryName, content) {
  const name = Buffer.from(entryName);
  const data = Buffer.from(content);
  const local = Buffer.alloc(30);
  local.writeUInt32LE(0x04034b50, 0);
  local.writeUInt16LE(20, 4);
  local.writeUInt32LE(data.length, 18);
  local.writeUInt32LE(data.length, 22);
  local.writeUInt16LE(name.length, 26);

  const central = Buffer.alloc(46);
  central.writeUInt32LE(0x02014b50, 0);
  central.writeUInt16LE(0x0314, 4);
  central.writeUInt16LE(20, 6);
  central.writeUInt32LE(data.length, 20);
  central.writeUInt32LE(data.length, 24);
  central.writeUInt16LE(name.length, 28);
  central.writeUInt32LE((0o100644 << 16) >>> 0, 38);

  const directoryOffset = local.length + name.length + data.length;
  const directorySize = central.length + name.length;
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(1, 8);
  end.writeUInt16LE(1, 10);
  end.writeUInt32LE(directorySize, 12);
  end.writeUInt32LE(directoryOffset, 16);
  return Buffer.concat([local, name, data, central, name, end]);
}

const performanceMetrics = [
  'provisioningToOnlineSeconds',
  'queueToStartSeconds',
  'cleanupToDeleteSeconds',
  'replacementReadySeconds',
];

function percentileStatistics(samples) {
  return Object.fromEntries(
    performanceMetrics.map((metric) => {
      const values = samples.map((sample) => sample[metric]).sort((a, b) => a - b);
      return [
        metric,
        {
          p50: values[Math.ceil(values.length * 0.5) - 1],
          p95: values[Math.ceil(values.length * 0.95) - 1],
        },
      ];
    }),
  );
}

function attestationSamples({
  count,
  imageVersionResourceId,
  label,
  offset,
  phase,
  vmssResourceId,
}) {
  const scope = vmssResourceId.slice(0, vmssResourceId.indexOf('/providers/'));
  return Array.from({ length: count }, (_, index) => ({
    runnerLabel: label,
    controllerGeneration: index + 1,
    leaseGeneration: index + 101,
    stateRevision: index + 201,
    imageVersionResourceId,
    vmssResourceId,
    vmResourceId:
      `${scope}/providers/Microsoft.Compute/virtualMachines/` +
      `${label}-${phase}-${index + 1}`,
    provisioningToOnlineSeconds: offset + index + 1,
    queueToStartSeconds: offset + index + 2,
    cleanupToDeleteSeconds: offset + index + 3,
    replacementReadySeconds: offset + index + 4,
  }));
}

function physicalAttestationFixture(evidenceRoot) {
  const subscription = '00000000-0000-0000-0000-000000000000';
  const galleryRoot =
    `/subscriptions/${subscription}/resourceGroups/rg-certigo-runner-images/` +
    'providers/Microsoft.Compute/galleries/galcertigocirunners/images';
  const expectations = {
    repositoryCommitSha: 'b'.repeat(40),
    builderImageVersionResourceId:
      `${galleryRoot}/certigo-backend-builder-ubuntu-2404/versions/2026.09.02`,
    deployerImageVersionResourceId:
      `${galleryRoot}/certigo-backend-deployer-ubuntu-2404/versions/2026.09.02`,
    builderVmssResourceId:
      `/subscriptions/${subscription}/resourceGroups/` +
      'rg-certigo-backend-builder-runtime/providers/Microsoft.Compute/' +
      'virtualMachineScaleSets/vmss-certigo-backend-builder',
    deployerVmssResourceId:
      `/subscriptions/${subscription}/resourceGroups/` +
      'rg-certigo-backend-deployer-runtime/providers/Microsoft.Compute/' +
      'virtualMachineScaleSets/vmss-certigo-backend-deployer',
  };
  const createPerformance = (pool, label, offset) => {
    const imageVersionResourceId =
      expectations[`${pool}ImageVersionResourceId`];
    const vmssResourceId = expectations[`${pool}VmssResourceId`];
    const cold = attestationSamples({
      count: 20,
      imageVersionResourceId,
      label,
      offset,
      phase: 'cold',
      vmssResourceId,
    });
    const warm = attestationSamples({
      count: 20,
      imageVersionResourceId,
      label,
      offset: offset + 100,
      phase: 'warm',
      vmssResourceId,
    });
    return {
      cold,
      warm,
      statistics: {
        cold: percentileStatistics(cold),
        warm: percentileStatistics(warm),
      },
      accepted: true,
    };
  };
  const controls = Object.fromEntries(
    [
      'distinctHosts',
      'distinctDisks',
      'distinctServiceUsers',
      'distinctNetworks',
      'networkPeeringAbsent',
      'runtimeManagedIdentityAbsent',
      'imdsBlockedByOs',
      'imdsBlockedByNsg',
      'exclusiveLabels',
      'ephemeralOneJob',
      'deleteOrReimageAfterJob',
      'workspaceCleaned',
      'processesCleaned',
      'projectCachesCleaned',
      'dockerStateAbsent',
      'builderAzureIdentityAbsent',
      'deployerSourceCheckoutAbsent',
      'deployerBuildToolsAbsent',
      'artifactVerifiedBeforeOidc',
      'packageNotExecutedBeforeDeploy',
    ].map((name) => [name, true]),
  );
  const performance = {
    percentileMethod: 'nearest-rank',
    builder: createPerformance(
      'builder',
      'certigo-backend-builder',
      10,
    ),
    deployer: createPerformance(
      'deployer',
      'certigo-backend-deployer',
      20,
    ),
  };
  const immutableBindings = {
    builderImageVersionResourceId:
      expectations.builderImageVersionResourceId,
    deployerImageVersionResourceId:
      expectations.deployerImageVersionResourceId,
    builderVmssResourceId: expectations.builderVmssResourceId,
    deployerVmssResourceId: expectations.deployerVmssResourceId,
  };
  const inventoryPool = (pool, label, serviceUser) => {
    const samples = [
      ...performance[pool].cold,
      ...performance[pool].warm,
    ];
    const vmssResourceId = expectations[`${pool}VmssResourceId`];
    const scope = vmssResourceId.slice(0, vmssResourceId.indexOf('/providers/'));
    return {
      runnerLabel: label,
      imageVersionResourceId:
        expectations[`${pool}ImageVersionResourceId`],
      vmssResourceId,
      vmResourceIds: samples.map((sample) => sample.vmResourceId),
      osDiskResourceIds: samples.map(
        (_, index) =>
          `${scope}/providers/Microsoft.Compute/disks/${pool}-${index + 1}`,
      ),
      computeHostEvidenceIds: samples.map(
        (_, index) => `physical-host-evidence:${pool}:${index + 1}`,
      ),
      serviceUser,
      virtualNetworkResourceId:
        `${scope}/providers/Microsoft.Network/virtualNetworks/` +
        `vnet-certigo-backend-${pool}`,
      subnetResourceId:
        `${scope}/providers/Microsoft.Network/virtualNetworks/` +
        `vnet-certigo-backend-${pool}/subnets/snet-certigo-backend-${pool}`,
      networkSecurityGroupResourceId:
        `${scope}/providers/Microsoft.Network/networkSecurityGroups/` +
        `nsg-certigo-backend-${pool}`,
      natGatewayResourceId:
        `${scope}/providers/Microsoft.Network/natGateways/` +
        `nat-certigo-backend-${pool}`,
      imdsOsBlocked: true,
      imdsNsgBlocked: true,
    };
  };
  const evidenceDirectory = path.join(evidenceRoot, 'evidence');
  mkdirSync(evidenceDirectory);
  const evidenceInputs = [
    {
      kind: 'azure-resource-inventory',
      content: {
        schema: 'certigo.backend-runner-physical-inventory/v1',
        repositoryCommitSha: expectations.repositoryCommitSha,
        immutableBindings,
        pools: {
          builder: inventoryPool(
            'builder',
            'certigo-backend-builder',
            'certigo-builder',
          ),
          deployer: inventoryPool(
            'deployer',
            'certigo-backend-deployer',
            'certigo-deployer',
          ),
        },
        networkPeerings: [],
        applicationRoutes: [],
        runtimeManagedIdentities: [],
      },
    },
    ...[
      'runner-lifecycle',
      'network-imds-probes',
      'artifact-oidc-ordering',
      'performance-raw',
    ].map((kind) => ({
      kind,
      content: {
        schema: 'certigo.backend-runner-evidence/v1',
        kind,
        repositoryCommitSha: expectations.repositoryCommitSha,
      },
    })),
  ];
  const evidence = evidenceInputs.map(({ kind, content }) => {
    const file = path.join(evidenceDirectory, `${kind}.json`);
    writeFileSync(file, `${JSON.stringify(content)}\n`);
    return {
      kind,
      path: path.relative(evidenceRoot, file).replaceAll('\\', '/'),
      mediaType: 'application/json',
      sha256: sha256(file),
    };
  });
  return {
    expectations,
    evidenceFiles: evidence.map((item) => path.join(evidenceRoot, item.path)),
    attestation: {
      schema: 'certigo.backend-runner-physical-attestation/v1',
      status: 'approved',
      observedAtUtc: '2026-09-03T12:00:00Z',
      repositoryCommitSha: expectations.repositoryCommitSha,
      collector: {
        id: 'certigo-physical-evidence-collector',
        collectedAtUtc: '2026-09-03T11:55:00Z',
      },
      immutableBindings,
      controls,
      performance,
      evidence,
      approval: {
        approved: true,
        reviewedCommitSha: expectations.repositoryCommitSha,
        reviewer: 'independent-security-reviewer',
        independentFromImplementer: true,
        reviewedAtUtc: '2026-09-03T13:00:00Z',
      },
    },
  };
}

test('versioned contracts preserve the design input without claiming attestation', () => {
  const contract = readJson('backend-runner-contract.json');
  assert.equal(contract.designInput.fileName, 'backend-runner-capacity-contract-final-20260902T1445Z.json');
  assert.equal(
    contract.designInput.sha256,
    '179931e8129ea4d70494a02215288d91525af454907846d205eadedebbda4085',
  );
  assert.equal(contract.designInput.signed, false);
  assert.equal(contract.designInput.immutable, false);
  assert.equal(contract.designInput.physicalAttestation, false);
  assert.equal(contract.designInput.approval, false);
  assert.equal(contract.attestation.activationDecision, 'unknown-no-go');
  assert.equal(contract.attestation.independentApprovalRequired, true);
  assert.equal(
    contract.attestation.validator.path,
    'validate-physical-attestation.mjs',
  );
  assert.equal(contract.attestation.validator.requiresApprovedStatus, true);
  assert.equal(
    contract.attestation.validator.recomputesNearestRankPercentiles,
    true,
  );
  assert.equal(contract.attestation.validator.requiresFreshVmPerSample, true);
  assert.equal(contract.controller.builderLifecycle, 'ephemeral-delete');
  assert.equal(contract.controller.deployerLifecycle, 'ephemeral-delete');
  assert.equal(contract.controller.restartOrDeallocateAllowed, false);
  assert.equal(contract.mutationAuthorization.deploymentEnabled, false);
  assert.equal(contract.mutationAuthorization.runnerMutationAuthorized, false);
  assert.equal(contract.mutationAuthorization.workflowMutationAuthorized, false);
  assert.equal(contract.mutationAuthorization.azureMutationAuthorized, false);
});

test('backend pools have exact labels, zero idle capacity, and no physical cohabitation', () => {
  const contract = readJson('backend-runner-contract.json');
  const builder = contract.pools.builder;
  const deployer = contract.pools.deployer;
  assert.deepEqual(contract.routing.authoritativeLabels, [
    'certigo-backend-builder',
    'certigo-backend-deployer',
  ]);
  assert.equal(contract.routing.fallbackAllowed, false);
  assert.equal(contract.routing.dualLabelAllowed, false);
  assert.equal(contract.routing.trustedFallbackAllowed, false);
  assert.deepEqual(contract.routing.oldRunnerIdsDenied, [24, 25, 26, 27]);
  for (const pool of [builder, deployer]) {
    assert.equal(pool.idleCapacity, 0);
    assert.equal(pool.maximumCapacity, 1);
    assert.equal(pool.managedIdentity, 'none');
    assert.equal(pool.imdsOsBlockRequired, true);
    assert.equal(pool.imdsNsgBlockRequired, true);
    assert.equal(pool.projectCachePersistenceAllowed, false);
    assert.equal(pool.dockerAllowed, false);
  }
  for (const field of [
    'runtimeResourceGroup',
    'virtualMachineScaleSet',
    'virtualNetwork',
    'subnet',
    'networkSecurityGroup',
    'natGateway',
    'natPublicIp',
    'addressSpace',
    'zone',
    'imageDefinitionName',
  ]) {
    assert.notEqual(builder[field], deployer[field], `${field} must be distinct`);
  }
  assert.equal(builder.azureCredentialsAllowed, false);
  assert.equal(builder.azureOidcAllowed, false);
  assert.equal(deployer.sourceCheckoutAllowed, false);
  assert.equal(deployer.projectBuildAllowed, false);
});

test('artifact contract keeps verification and OIDC ordering fail-closed', () => {
  const contract = readJson('backend-artifact-contract.json');
  assert.deepEqual(contract.verificationOrder, [
    'download-bundle-without-source-checkout',
    'reject-unsafe-archive-entries',
    'verify-canonical-manifest-attestation-cryptographically',
    'verify-manifest-package-and-sbom-digests',
    'verify-cyclonedx-sbom',
    'verify-signed-slsa-provenance-identity-constraints',
    'mark-artifact-verified',
    'request-github-oidc',
    'deploy-package-without-executing-it',
  ]);
  assert.equal(contract.deployer.sourceCheckoutAllowed, false);
  assert.equal(contract.deployer.packageExecutionBeforeDeploymentAllowed, false);
  assert.equal(contract.activation.workflowIntegrationReviewed, false);
  assert.equal(contract.activation.environmentProtectionReviewed, false);
});

test('backend-only image lock is complete without changing the blocked canary lock', () => {
  const contract = readJson('backend-image-build-contract.json');
  const canaryContract = JSON.parse(
    readFileSync(path.join(runnerRoot, 'image', 'image-build-contract.json'), 'utf8'),
  );
  assert.equal(contract.policy.reproducibleInputsReady, true);
  assert.equal(contract.policy.packageManagerMutationAllowed, false);
  assert.equal(contract.policy.flutterInstalled, false);
  assert.equal(contract.policy.imageTemplateAutoRunEnabled, false);
  assert.equal(contract.policy.imageBuildExecutionAuthorized, false);
  assert.equal(canaryContract.policy.reproducibleInputsReady, false);
  assert.equal(contract.baseImage.version, '24.04.202608070');
  assert.equal(
    contract.directArtifacts.actionsRunner.sha256,
    '04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d',
  );
  assert.equal(
    contract.directArtifacts.node.sha256,
    'df770b2a6f130ed8627c9782c988fda9669fa23898329a61a871e32f965e007d',
  );
  assert.equal(contract.directArtifacts.dotnetSdk.sha512.length, 128);
  assert.equal(contract.directArtifacts.githubCli.version, '2.96.0');
  assert.equal(
    contract.directArtifacts.githubCli.sha256,
    '83d5c2ccad5498f58bf6368acb1ab32588cf43ab3a4b1c301bf36328b1c8bd60',
  );
  assert.equal(
    filesNamed(path.join(repositoryRoot, 'backend'), 'packages.lock.json').length,
    contract.repositoryLocks.backendNugetLockFiles,
  );
  for (const input of Object.values(contract.scripts)) {
    assert.equal(sha256(path.join(backendRoot, input.path)), input.sha256);
  }
});

test('physical attestation schema is fail-closed and requires 20 cold and warm samples per pool', () => {
  const schema = readJson('backend-physical-attestation.schema.json');
  assert.deepEqual(schema.properties.status.enum, ['approved', 'no-go']);
  assert.equal(schema.$defs.builderSamples.minItems, 20);
  assert.equal(schema.$defs.builderSamples.maxItems, 20);
  assert.equal(schema.$defs.deployerSamples.minItems, 20);
  assert.equal(schema.$defs.deployerSamples.maxItems, 20);
  assert.equal(
    schema.$defs.builderSamples.items.allOf[1].properties.runnerLabel.const,
    'certigo-backend-builder',
  );
  assert.equal(
    schema.$defs.deployerSamples.items.allOf[1].properties.runnerLabel.const,
    'certigo-backend-deployer',
  );
  assert.equal(schema.properties.performance.properties.percentileMethod.const, 'nearest-rank');
  const approvedGate = schema.allOf[0].then.properties;
  assert.equal(approvedGate.approval.properties.approved.const, true);
  assert.equal(
    approvedGate.approval.properties.independentFromImplementer.const,
    true,
  );
  assert.equal(
    approvedGate.controls.properties.artifactVerifiedBeforeOidc.const,
    true,
  );
  assert.equal(approvedGate.performance.properties.builder.properties.accepted.const, true);
  assert.equal(approvedGate.performance.properties.deployer.properties.accepted.const, true);
  assert.equal(
    schema.allOf[1].then.properties.approval.properties.approved.const,
    false,
  );
});

test('physical attestation validator binds resources, evidence, fresh VMs, and percentiles', () => {
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'certigo-attestation-'));
  try {
    const { attestation, evidenceFiles, expectations } =
      physicalAttestationFixture(fixture);
    const attestationFile = path.join(fixture, 'attestation.json');
    writeFileSync(attestationFile, `${JSON.stringify(attestation)}\n`);
    const collector = crypto.generateKeyPairSync('ed25519');
    const reviewer = crypto.generateKeyPairSync('ed25519');
    const collectorPublicKeyFile = path.join(fixture, 'collector-public.pem');
    const reviewerPublicKeyFile = path.join(fixture, 'reviewer-public.pem');
    const collectorSignatureFile = path.join(fixture, 'collector.sig');
    const reviewerSignatureFile = path.join(fixture, 'reviewer.sig');
    writeFileSync(
      collectorPublicKeyFile,
      collector.publicKey.export({ type: 'spki', format: 'pem' }),
    );
    writeFileSync(
      reviewerPublicKeyFile,
      reviewer.publicKey.export({ type: 'spki', format: 'pem' }),
    );
    const attestationBytes = readFileSync(attestationFile);
    writeFileSync(
      collectorSignatureFile,
      `${crypto.sign(null, attestationBytes, collector.privateKey).toString('base64')}\n`,
    );
    writeFileSync(
      reviewerSignatureFile,
      `${crypto.sign(null, attestationBytes, reviewer.privateKey).toString('base64')}\n`,
    );
    const signedExpectations = {
      ...expectations,
      collectorId: 'certigo-physical-evidence-collector',
      reviewerId: 'independent-security-reviewer',
      collectorKeySha256: publicKeyFingerprint(collector.publicKey),
      reviewerKeySha256: publicKeyFingerprint(reviewer.publicKey),
    };
    const signedResult = validateSignedPhysicalAttestation({
      attestationFile,
      collectorPublicKeyFile,
      collectorSignatureFile,
      reviewerPublicKeyFile,
      reviewerSignatureFile,
      expectations: signedExpectations,
    });
    assert.equal(signedResult.repositoryCommitSha, expectations.repositoryCommitSha);
    assert.equal(signedResult.sampleCount, 80);
    assert.equal(signedResult.evidenceCount, 5);
    assert.equal(
      signedResult.collectorKeySha256,
      signedExpectations.collectorKeySha256,
    );

    const invalidPercentile = structuredClone(attestation);
    invalidPercentile.performance.builder.statistics.cold
      .queueToStartSeconds.p95 += 1;
    assert.throws(
      () =>
        validatePhysicalAttestationPayload(
          invalidPercentile,
          expectations,
          fixture,
        ),
      /recomputed by nearest-rank/,
    );

    const reusedVm = structuredClone(attestation);
    reusedVm.performance.builder.warm[0].vmResourceId =
      reusedVm.performance.builder.cold[0].vmResourceId;
    assert.throws(
      () =>
        validatePhysicalAttestationPayload(reusedVm, expectations, fixture),
      /one-job samples require fresh VMs/,
    );

    const wrongBinding = structuredClone(attestation);
    wrongBinding.performance.deployer.cold[0].imageVersionResourceId =
      expectations.builderImageVersionResourceId;
    assert.throws(
      () =>
        validatePhysicalAttestationPayload(wrongBinding, expectations, fixture),
      /does not match its immutable pool bindings/,
    );

    const staleApproval = structuredClone(attestation);
    staleApproval.approval.reviewedCommitSha = 'c'.repeat(40);
    assert.throws(
      () =>
        validatePhysicalAttestationPayload(staleApproval, expectations, fixture),
      /must bind the expected repository commit/,
    );

    const caseVariantCollision = {
      ...expectations,
      deployerVmssResourceId: expectations.builderVmssResourceId.replace(
        'vmss-certigo-backend-builder',
        'VMSS-CERTIGO-BACKEND-BUILDER',
      ),
    };
    assert.throws(
      () =>
        validatePhysicalAttestationPayload(
          attestation,
          caseVariantCollision,
          fixture,
        ),
      /distinct runtime resource groups/,
    );

    writeFileSync(collectorSignatureFile, `${Buffer.alloc(64).toString('base64')}\n`);
    assert.throws(
      () =>
        validateSignedPhysicalAttestation({
          attestationFile,
          collectorPublicKeyFile,
          collectorSignatureFile,
          reviewerPublicKeyFile,
          reviewerSignatureFile,
          expectations: signedExpectations,
        }),
      /collector signature does not authenticate/,
    );

    writeFileSync(evidenceFiles[1], '{"controls":"tampered"}\n');
    assert.throws(
      () =>
        validatePhysicalAttestationPayload(attestation, expectations, fixture),
      /sha256 does not match/,
    );
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});

test('compiled runtime ARM contains two inert identity-free VMSS and isolated networks', () => {
  const template = compile('main.bicep');
  const resources = resourcesOf(template);
  const byType = (type) => resources.filter((resource) => resource.type === type);
  assert.equal(template.parameters.deploymentEnabled.defaultValue, false);
  assert.equal(byType('Microsoft.Resources/resourceGroups').length, 2);
  assert.equal(byType('Microsoft.Compute/virtualMachineScaleSets').length, 2);
  assert.equal(byType('Microsoft.Network/virtualNetworks').length, 2);
  assert.equal(byType('Microsoft.Network/networkSecurityGroups').length, 2);
  assert.equal(byType('Microsoft.Network/natGateways').length, 2);
  assert.equal(byType('Microsoft.Network/publicIPAddresses').length, 2);
  assert.equal(byType('Microsoft.Network/virtualNetworkPeerings').length, 0);
  for (const scaleSet of byType('Microsoft.Compute/virtualMachineScaleSets')) {
    assert.ok(scaleSet.condition, 'runtime resources must have a false-by-default gate');
    assert.equal(scaleSet.identity, undefined);
    assert.equal(scaleSet.properties.orchestrationMode, 'Flexible');
    assert.equal(scaleSet.properties.overprovision, false);
    assert.equal(scaleSet.sku.capacity, "[parameters('poolProfile').idleCapacity]");
    assert.equal(
      scaleSet.properties.virtualMachineProfile.osProfile.allowExtensionOperations,
      false,
    );
    assert.equal(
      scaleSet.properties.virtualMachineProfile.storageProfile.osDisk.deleteOption,
      'Delete',
    );
  }
  for (const nsg of byType('Microsoft.Network/networkSecurityGroups')) {
    const rules = nsg.properties.securityRules;
    assert.ok(
      rules.some(
        (rule) =>
          rule.name === 'deny-imds-outbound' &&
          rule.properties.access === 'Deny' &&
          rule.properties.destinationAddressPrefix === 'AzurePlatformIMDS',
      ),
    );
  }
});

test('generic modules stay fail-closed and expose single-pool interfaces', () => {
  const runtimeTemplate = JSON.parse(
    execFileSync(
      bicep,
      [
        'build',
        path.join(runnerRoot, 'modules', 'isolated-ephemeral-pool.bicep'),
        '--stdout',
      ],
      { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 },
    ),
  );
  const imageTemplate = JSON.parse(
    execFileSync(
      bicep,
      [
        'build',
        path.join(runnerRoot, 'modules', 'locked-runner-image.bicep'),
        '--stdout',
      ],
      { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 },
    ),
  );
  assert.equal(runtimeTemplate.parameters.deploymentEnabled.defaultValue, false);
  assert.equal(runtimeTemplate.parameters.activationReady.defaultValue, false);
  assert.equal(imageTemplate.parameters.deploymentEnabled.defaultValue, false);
  assert.equal(imageTemplate.parameters.activationReady.defaultValue, false);
  assert.equal(
    imageTemplate.parameters.reproducibleInputsReady.defaultValue,
    false,
  );
  const aib = imageTemplate.resources.find(
    (resource) =>
      resource.type === 'Microsoft.VirtualMachineImages/imageTemplates',
  );
  assert.equal(aib.properties.autoRun.state, 'Disabled');
  assert.ok(aib.condition);
  assert.equal(
    aib.properties.source.version,
    "[parameters('imageProfile').baseImage.version]",
  );
  const interfaceContract = JSON.parse(
    readFileSync(
      path.join(runnerRoot, 'modules', 'isolated-runner-interface.json'),
      'utf8',
    ),
  );
  assert.equal(interfaceContract.runtimeModule.idleCapacity, 0);
  assert.equal(interfaceContract.runtimeModule.maximumCapacity, 1);
  assert.equal(interfaceContract.runtimeModule.hostManagedIdentity, 'none');
  assert.equal(interfaceContract.runtimeModule.vmExtensionOperationsAllowed, false);
  assert.equal(interfaceContract.controller.classOrderIsConfigurationDriven, true);
  assert.equal(interfaceContract.controller.ephemeralClassLifecycleRequired, true);
  const bootstrapInterface = interfaceContract.futureProfiles.legacyTrustedBootstrap;
  const bootstrapContractFile = path.join(
    runnerRoot,
    'modules',
    bootstrapInterface.contractPath,
  );
  const bootstrapContract = JSON.parse(
    readFileSync(bootstrapContractFile, 'utf8'),
  );
  assert.equal(bootstrapInterface.status, 'interface-only-disabled-no-go');
  assert.equal(bootstrapInterface.contractSha256, sha256(bootstrapContractFile));
  assert.equal(bootstrapInterface.imageModuleCompatible, true);
  assert.equal(bootstrapInterface.runtimeModuleCompatible, true);
  assert.equal(bootstrapInterface.sharedFourClassCapacityControllerAllowed, false);
  assert.equal(bootstrapContract.moduleBinding.deploymentEnabled, false);
  assert.equal(bootstrapContract.moduleBinding.activationReady, false);
  assert.equal(bootstrapContract.moduleBinding.reproducibleInputsReady, false);
  assert.equal(
    bootstrapContract.moduleBinding.attestedGalleryImageVersionResourceId,
    '',
  );
  assert.equal(bootstrapContract.moduleBinding.backendWrapperReuseAllowed, false);
  assert.equal(
    bootstrapContract.moduleBinding.runtimeProfile.runnerLabel,
    'certigo-trusted',
  );
  assert.equal(
    bootstrapContract.moduleBinding.runtimeProfile.roleName,
    'legacy-trusted-bootstrap',
  );
  assert.equal(bootstrapContract.moduleBinding.runtimeProfile.idleCapacity, 0);
  assert.equal(bootstrapContract.moduleBinding.runtimeProfile.maximumCapacity, 1);
  assert.equal(
    bootstrapContract.queueAdmission.sharedFourClassCapacityControllerAllowed,
    false,
  );
  assert.equal(bootstrapContract.queueAdmission.pullRequestNumber, 356);
  assert.equal(
    bootstrapContract.queueAdmission.headSha,
    '447a18de80bedba494f8a94c2a8f05e2af29f7f9',
  );
  assert.deepEqual(bootstrapContract.queueAdmission.allowedWorkflowJobs, [
    {
      workflowPath: '.github/workflows/ci-project-state.yml',
      jobId: 'validate',
      requiredCheckName: 'Generated state equals committed state',
    },
    {
      workflowPath: '.github/workflows/codeql.yml',
      jobId: 'security-gate',
      requiredCheckName: 'CodeQL / Security gate',
    },
    {
      workflowPath: '.github/workflows/security-gate.yml',
      jobId: 'security-gate',
      requiredCheckName: 'Security / Required gate',
    },
  ]);
  assert.equal(
    bootstrapContract.queueAdmission.queuedContextPullRequest354Admitted,
    false,
  );
  assert.equal(
    bootstrapContract.queueAdmission.allNonAllowlistedTrustedJobsAbsentRequired,
    true,
  );
  assert.equal(
    bootstrapContract.queueAdmission.noOtherMatchingRunnerOnlineRequired,
    true,
  );
  assert.equal(
    bootstrapContract.queueAdmission.atomicAdmissionLeaseRequired,
    true,
  );
  assert.equal(
    bootstrapContract.queueAdmission
      .queueSnapshotRecheckedImmediatelyBeforeRegistration,
    true,
  );
  assert.equal(
    bootstrapContract.queueAdmission.destroyWithoutRegistrationOnQueueDrift,
    true,
  );
  assert.equal(bootstrapContract.security.backendBuilderRoleAllowed, false);
  assert.equal(bootstrapContract.security.backendDeployerRoleAllowed, false);
  assert.equal(bootstrapContract.security.jobSecretsAllowed, false);
  assert.equal(bootstrapContract.security.oidcAllowed, false);
  assert.equal(bootstrapContract.security.azureOperationsAllowed, false);
  assert.equal(
    bootstrapContract.lifecycle.destroyImmediatelyAfterJobRequired,
    true,
  );
  assert.equal(bootstrapContract.evidence.currentlyAvailable, false);
  assert.equal(bootstrapContract.evidence.activationDecision, 'UNKNOWN/NO-GO');

  const profileKeys = (moduleFile, profileName) =>
    [
      ...new Set(
        [
          ...readFileSync(moduleFile, 'utf8').matchAll(
            new RegExp(`\\b${profileName}\\.([A-Za-z][A-Za-z0-9]*)`, 'g'),
          ),
        ].map((match) => match[1]),
      ),
    ].sort();
  assert.deepEqual(
    Object.keys(bootstrapContract.moduleBinding.runtimeProfile).sort(),
    profileKeys(
      path.join(runnerRoot, 'modules', 'isolated-ephemeral-pool.bicep'),
      'poolProfile',
    ),
  );
  assert.deepEqual(
    Object.keys(bootstrapContract.moduleBinding.imageProfile).sort(),
    profileKeys(
      path.join(runnerRoot, 'modules', 'locked-runner-image.bicep'),
      'imageProfile',
    ),
  );
  assert.deepEqual(bootstrapContract.moduleBinding.imageProfile.baseImage, {
    publisher: 'Canonical',
    offer: 'ubuntu-24_04-lts',
    sku: 'server',
    version: '24.04.202608070',
  });
  assert.deepEqual(bootstrapContract.moduleBinding.imageProfile.identifier, {
    publisher: 'Certigo',
    offer: 'github-actions',
    sku: 'legacy-trusted-bootstrap',
  });
  assert.equal(interfaceContract.isolation.crossRepositoryColocationAllowed, false);
  assert.equal(interfaceContract.designInputs[0].physicalAttestation, false);
});

test('shell contracts require ephemeral one-job registration and pass syntax checks', () => {
  const scripts = [
    'backend-job-hook.sh',
    'cleanup-backend-runner.sh',
    'customize-backend-image.sh',
    'register-ephemeral-runner.sh',
    'validate-backend-image.sh',
  ];
  for (const script of scripts) {
    execFileSync('bash', ['-n', toBashPath(path.join(backendRoot, 'image', script))]);
  }
  const registration = readFileSync(
    path.join(backendRoot, 'image', 'register-ephemeral-runner.sh'),
    'utf8',
  );
  for (const required of [
    '--ephemeral',
    '--no-default-labels',
    '--disableupdate',
    'CERTIGO_CONTROLLER_GENERATION',
    'CERTIGO_LEASE_GENERATION',
    'CERTIGO_STATE_REVISION',
    'RuntimeDirectory=certigo-backend',
    'ExecStopPost=+/usr/local/sbin/certigo-cleanup-backend-runner',
    'CERTIGO_IMAGE_VALIDATION_STAMP',
    'CERTIGO_REGISTRATION_STAMP',
    'CERTIGO_RETIRE_STAMP',
    'CERTIGO_VM_RESOURCE_ID',
    'CERTIGO_IMAGE_VERSION_RESOURCE_ID',
    'ln -- "${registration_tmp}" "${CERTIGO_REGISTRATION_STAMP}"',
  ]) {
    assert.ok(registration.includes(required));
  }
  assert.equal(registration.includes('certigo-trusted'), false);
  assert.equal(
    registration.includes(
      'ReadWritePaths=${CERTIGO_RUNNER_HOME} ${CERTIGO_JOB_ROOT}',
    ),
    false,
  );
  const customization = readFileSync(
    path.join(backendRoot, 'image', 'customize-backend-image.sh'),
    'utf8',
  );
  assert.equal(/\bapt(?:-get)?\b/.test(customization), false);
  assert.ok(customization.includes('certigo.ephemeral-runner/v1'));
  assert.ok(customization.includes('chown -R root:root "${runner_home}"'));
  const cleanup = readFileSync(
    path.join(backendRoot, 'image', 'cleanup-backend-runner.sh'),
    'utf8',
  );
  assert.ok(cleanup.includes('/var/lib/certigo/backend-runner-retired'));
  assert.ok(cleanup.includes('trap power_off EXIT'));
  const verifier = readFileSync(
    path.join(backendRoot, 'verify-deployment-bundle.mjs'),
    'utf8',
  );
  for (const required of [
    "execFileSync('/usr/local/bin/gh'",
    "'--signer-workflow'",
    "'--signer-digest'",
    "'--source-ref'",
    "'--source-digest'",
    "'--predicate-type'",
  ]) {
    assert.ok(verifier.includes(required));
  }
  assert.equal(verifier.includes('attestation-verified'), false);
  execFileSync('node', [
    '--check',
    path.join(backendRoot, 'validate-physical-attestation.mjs'),
  ]);
});

test('retirement cleanup removes workspace, caches, credentials, and Docker state', () => {
  const fixture = mkdtempSync(path.join(os.tmpdir(), 'certigo-cleanup-'));
  try {
    const directories = {
      runner: path.join(fixture, 'runner'),
      serviceHome: path.join(fixture, 'home'),
      job: path.join(fixture, 'job'),
      docker: path.join(fixture, 'docker'),
      containerd: path.join(fixture, 'containerd'),
      runtime: path.join(fixture, 'runtime'),
    };
    for (const directory of [
      directories.job,
      directories.docker,
      directories.containerd,
      directories.runtime,
    ]) {
      const child = path.join(directory, 'fixture');
      mkdirSync(child, { recursive: true });
      writeFileSync(path.join(child, 'state'), 'sensitive');
    }
    const runnerWork = path.join(directories.runner, '_work', 'fixture');
    mkdirSync(runnerWork, { recursive: true });
    writeFileSync(path.join(runnerWork, 'state'), 'sensitive');
    for (const cache of ['.cache', '.npm', '.nuget', '.dotnet', '.azure', '.docker']) {
      const cacheRoot = path.join(directories.serviceHome, cache);
      mkdirSync(cacheRoot, { recursive: true });
      writeFileSync(path.join(cacheRoot, 'state'), 'sensitive');
    }
    for (const state of [
      '.runner',
      '.credentials',
      '.credentials_rsaparams',
      '.service',
      '.env',
    ]) {
      writeFileSync(path.join(directories.runner, state), 'sensitive');
    }
    const environmentFile = path.join(fixture, 'runner.env');
    writeFileSync(
      environmentFile,
      [
        'CERTIGO_SERVICE_USER=fixture',
        `CERTIGO_RUNNER_HOME=${toBashPath(directories.runner)}`,
        `CERTIGO_SERVICE_HOME=${toBashPath(directories.serviceHome)}`,
        `CERTIGO_JOB_ROOT=${toBashPath(directories.job)}`,
        '',
      ].join('\n'),
    );
    const retireStamp = path.join(fixture, 'retired');
    execFileSync(
      'bash',
      [toBashPath(path.join(backendRoot, 'image', 'cleanup-backend-runner.sh'))],
      {
        env: {
          ...process.env,
          CERTIGO_CLEANUP_TEST_MODE: 'true',
          CERTIGO_RUNNER_ENV_FILE: toBashPath(environmentFile),
          CERTIGO_DOCKER_ROOT: toBashPath(directories.docker),
          CERTIGO_CONTAINERD_ROOT: toBashPath(directories.containerd),
          CERTIGO_RUNTIME_ROOT: toBashPath(directories.runtime),
          CERTIGO_RETIRE_STAMP: toBashPath(retireStamp),
        },
      },
    );
    for (const directory of [
      directories.job,
      directories.docker,
      directories.containerd,
      directories.runtime,
      path.join(directories.runner, '_work'),
    ]) {
      assert.deepEqual(readdirSync(directory), []);
    }
    for (const cache of ['.cache', '.npm', '.nuget', '.dotnet', '.azure', '.docker']) {
      assert.deepEqual(readdirSync(path.join(directories.serviceHome, cache)), []);
    }
    for (const state of [
      '.runner',
      '.credentials',
      '.credentials_rsaparams',
      '.service',
      '.env',
    ]) {
      assert.equal(existsSync(path.join(directories.runner, state)), false);
    }
    assert.equal(existsSync(retireStamp), true);
    assert.equal(lstatSync(retireStamp).isFile(), true);
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
});

test('bundle verification gates OIDC on an attested manifest, package, and SBOM', () => {
  const bundle = mkdtempSync(path.join(os.tmpdir(), 'certigo-bundle-'));
  const repository = 'gchambaud_microsoft/Certigo';
  const commit = 'a'.repeat(40);
  const runId = '351';
  try {
    const packageFile = path.join(bundle, 'backend-package.zip');
    const sbomFile = path.join(bundle, 'backend-sbom.cdx.json');
    const manifestFile = path.join(bundle, 'backend-manifest.json');
    writeFileSync(packageFile, storedZip('backend-package.bin', 'immutable'));
    writeFileSync(
      sbomFile,
      `${JSON.stringify({ bomFormat: 'CycloneDX', specVersion: '1.6' })}\n`,
    );
    const workflowRef =
      `${repository}/.github/workflows/backend-build.yml@refs/heads/main`;
    const expectedWorkflow =
      `${repository}/.github/workflows/backend-build.yml`;
    writeFileSync(
      manifestFile,
      `${JSON.stringify({
        schema: 'certigo.backend.deployment-bundle/v1',
        commitSha: commit,
        source: {
          repository,
          ref: 'refs/heads/main',
          event: 'push',
          workflowRef,
          runId: Number(runId),
          runAttempt: 1,
          builderLabel: 'certigo-backend-builder',
          azureIdentityUsed: false,
        },
        artifacts: {
          package: descriptor(packageFile, bundle),
          sbom: descriptor(sbomFile, bundle),
        },
      })}\n`,
    );
    const marker = path.join(bundle, 'artifact-verified.json');
    const attestationResults = [
      {
        verificationResult: {
          statement: {
            subject: [
              {
                name: path.basename(manifestFile),
                digest: { sha256: sha256(manifestFile) },
              },
            ],
            predicateType: 'https://slsa.dev/provenance/v1',
          },
          signature: { certificate: { subjectAlternativeName: expectedWorkflow } },
          verifiedTimestamps: [{ type: 'tlog' }],
        },
      },
    ];
    assert.deepEqual(
      validateGithubAttestationResults(attestationResults, manifestFile),
      {
        count: 1,
        predicateType: 'https://slsa.dev/provenance/v1',
      },
    );
    const nullCertificateResults = structuredClone(attestationResults);
    nullCertificateResults[0].verificationResult.signature.certificate = null;
    assert.throws(
      () =>
        validateGithubAttestationResults(nullCertificateResults, manifestFile),
      /does not bind the canonical manifest/,
    );
    let attestationRequest;
    const values = {
      manifest: manifestFile,
      'expected-commit': commit,
      'expected-repository': repository,
      'expected-workflow': expectedWorkflow,
      'expected-run-id': runId,
      'expected-package-sha256': sha256(packageFile),
      'verification-marker': marker,
    };
    verifyDeploymentBundle(values, (request) => {
      attestationRequest = request;
      return validateGithubAttestationResults(attestationResults, manifestFile);
    });
    assert.deepEqual(attestationRequest, {
      expectedCommit: commit,
      expectedRepository: repository,
      expectedWorkflow,
      attestedFile: manifestFile,
    });
    const verificationMarker = readJsonFromFile(marker);
    assert.equal(verificationMarker.githubAttestationVerified, true);
    assert.equal(verificationMarker.githubAttestationCount, 1);
    assert.equal(verificationMarker.packageEntryCount, 1);
    assert.equal(verificationMarker.signerWorkflow, expectedWorkflow);
    assert.equal(verificationMarker.manifestSha256, sha256(manifestFile));
    assert.equal(verificationMarker.sbomSha256, sha256(sbomFile));
    assert.equal(
      verificationMarker.githubProvenancePredicateType,
      'https://slsa.dev/provenance/v1',
    );

    writeFileSync(packageFile, 'tampered package');
    assert.throws(
      () =>
        verifyDeploymentBundle(
          {
            ...values,
            'verification-marker': path.join(bundle, 'must-not-exist.json'),
          },
          () => {
            throw new Error('attestation rejected');
          },
        ),
      /does not match its size and digest/,
    );
    assert.equal(existsSync(path.join(bundle, 'must-not-exist.json')), false);
    writeFileSync(packageFile, storedZip('../escape', 'unsafe'));
    const unsafeManifest = JSON.parse(readFileSync(manifestFile, 'utf8'));
    unsafeManifest.artifacts.package = descriptor(packageFile, bundle);
    writeFileSync(manifestFile, `${JSON.stringify(unsafeManifest)}\n`);
    assert.throws(
      () =>
        verifyDeploymentBundle(
          {
            ...values,
            'expected-package-sha256': sha256(packageFile),
            'verification-marker': path.join(bundle, 'unsafe-must-not-exist.json'),
          },
          () => ({
            count: 1,
            predicateType: 'https://slsa.dev/provenance/v1',
          }),
        ),
      /unsafe ZIP entry/,
    );
    assert.throws(
      () => validateGithubAttestationResults([], manifestFile),
      /returned no result/,
    );
  } finally {
    rmSync(bundle, { recursive: true, force: true });
  }
});

function readJsonFromFile(file) {
  return JSON.parse(readFileSync(file, 'utf8'));
}
