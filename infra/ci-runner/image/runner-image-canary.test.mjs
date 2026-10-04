import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { test } from 'node:test';
import {
  hashAzureEvidence,
  summarizeMeasurements,
  validateCandidateImageId,
  validateReleaseEvidence,
  validateWhatIf,
} from './validate-canary-evidence.mjs';

const imageRoot = new URL('./', import.meta.url);
const repositoryRoot = new URL('../../../', imageRoot);
const read = (relativePath, root = imageRoot) =>
  readFile(new URL(relativePath, root), 'utf8');
const buildContract = JSON.parse(await read('image-build-contract.json'));
const attestationPolicy = JSON.parse(await read('attestation-policy.json'));
const canaryContract = JSON.parse(await read('canary-contract.json'));
const plannedEvidence = JSON.parse(await read('canary-evidence.json'));
const imageBuild = await read('image-build.bicep');
const canary = await read('canary.bicep');
const canaryMain = await read('canary-main.bicep');
const transition = await read('canary-transition.ps1');
const cleanup = await read('canary-cleanup.ps1');
const securityWorkflow = await read(
  '.github/workflows/security-scan.yml',
  repositoryRoot,
);
const disabledWorkflow = await read(
  '.github/workflows-disabled/runner-image-attest.yml',
  repositoryRoot,
);

test('build contract pins original toolchain lineage, image, and every source digest', async () => {
  assert.match(buildContract.contractCommit, /^[0-9a-f]{40}$/);
  assert.equal(
    buildContract.toolchainOriginCommit,
    'f8e23b2952e8ca39c59f30081b8950170abb701a',
  );
  assert.equal(buildContract.baseImage.version, '24.04.202608070');
  assert.match(buildContract.destination.imageVersion, /^\d+\.\d+\.\d+$/);
  assert.equal(buildContract.policy.autoRun, false);
  assert.equal(buildContract.policy.reproducibleInputsReady, false);
  assert.equal(buildContract.reproducibility.status, 'blocked');
  assert.equal(
    buildContract.reproducibility.aptSnapshot,
    'https://snapshot.ubuntu.com/ubuntu/20260807T000000Z/',
  );
  const baseEvidence = await read(buildContract.reproducibility.baseImageInventory.path, repositoryRoot);
  assert.equal(createHash('sha256').update(baseEvidence).digest('hex'),
    buildContract.reproducibility.baseImageInventory.sha256);
  assert.equal(JSON.parse(baseEvidence).snapshot, buildContract.reproducibility.aptSnapshot);
  for (const [field, file] of [
    ['aptPackageLockSha256', 'apt-packages.lock.json'],
    ['flutterEngineArtifactLockSha256', 'flutter-engine-artifacts.lock.json'],
  ]) {
    assert.equal(buildContract.reproducibility[field],
      createHash('sha256').update(await read(file)).digest('hex'), file);
  }
  assert.equal(attestationPolicy.signerDigest, null);
  assert.equal(attestationPolicy.activation.status, 'blocked');
  assert.equal(attestationPolicy.activation.requiresTwoStageMerge, true);
  assert.equal(buildContract.policy.excludeFromLatest, true);
  const canonicalBuildContract = (await read('image-build-contract.json')).replaceAll(
    '\r\n',
    '\n',
  );
  const buildContractSha256 = createHash('sha256')
    .update(canonicalBuildContract)
    .digest('hex');
  assert.match(imageBuild, new RegExp(buildContractSha256));

  for (const input of buildContract.inputs) {
    const content = await read(input.path, repositoryRoot);
    assert.equal(
      createHash('sha256').update(content).digest('hex'),
      input.sha256,
      input.path,
    );
    assert.match(input.sha256, /^[0-9a-f]{64}$/);
  }
});

test('image builder is inert by default and distributes an explicit excluded version', () => {
  assert.match(imageBuild, /param deploymentEnabled bool = false/);
  assert.match(imageBuild, /autoRun:\s*\{\s*state: 'Disabled'/s);
  assert.match(
    imageBuild,
    /reproducibilityReady = contract\.policy\.reproducibleInputsReady && contract\.reproducibility\.status == 'locked' && aptInputsReady && flutterInputsReady/,
  );
  assert.match(imageBuild, /aptPackageLockSha256\)\) == 64/);
  assert.match(imageBuild, /flutterEngineArtifactLockSha256\)\) == 64/);
  assert.match(imageBuild, /effectiveDeploymentEnabled = deploymentEnabled && reproducibilityReady && networkInstallerImplemented/);
  assert.equal(
    (imageBuild.match(/if \(effectiveDeploymentEnabled\)/g) ?? []).length,
    3,
  );
  assert.ok(
    imageBuild.indexOf("name: 'block-imds-before-network'") <
      imageBuild.lastIndexOf('inputCustomizers'),
  );
  assert.match(imageBuild, /iptables -C OUTPUT -d 169\.254\.169\.254\/32 -j REJECT/);
  assert.match(imageBuild, /IMDS remained reachable before image network access/);
  assert.match(imageBuild, /Microsoft\.VirtualMachineImages\/imageTemplates@2025-10-01/);
  assert.match(imageBuild, /galleryImageId: galleryImageVersionId/);
  assert.match(imageBuild, /excludeFromLatest: true/);
  assert.match(imageBuild, /sha256Checksum: input\.sha256/);
  assert.match(imageBuild, /type: 'UserAssigned'/);
  assert.doesNotMatch(imageBuild, /clientSecret|passwordAuthentication|\/latest/i);
});

test('canary is a new capacity-one PR-only boundary with no identity or IMDS', () => {
  assert.equal(canaryContract.runner.maximumCapacity, 1);
  assert.deepEqual(canaryContract.runner.labels, ['certigo-pr-image-canary']);
  assert.deepEqual(canaryContract.reserved.githubRunnerIds, [24, 26]);
  assert.deepEqual(canaryContract.reserved.virtualMachineTokens, ['4153d1dd']);
  assert.equal(canaryContract.liveOperationsAuthorized, false);
  assert.match(canary, /param deploymentEnabled bool = false/);
  assert.match(
    canary,
    /reproducibleInputsReady = buildContract\.policy\.reproducibleInputsReady && buildContract\.reproducibility\.status == 'locked' && aptInputsReady && flutterInputsReady/,
  );
  assert.match(canary, /signerReady = attestationPolicy\.activation\.status == 'active'/);
  assert.match(
    canary,
    /effectiveDeploymentEnabled = deploymentEnabled && reproducibleInputsReady && signerReady && networkInstallerImplemented/,
  );
  assert.equal(
    (canary.match(/if \(effectiveDeploymentEnabled\)/g) ?? []).length,
    5,
  );
  assert.match(canary, /capacity: contract\.runner\.maximumCapacity/);
  assert.match(canary, /destinationAddressPrefix: 'AzurePlatformIMDS'/);
  assert.ok(
    canaryContract.runner.bootstrapLines.includes(
      'test ! -e /opt/actions-runner/.runner',
    ),
  );
  assert.match(canary, /contract\.runner\.bootstrapLines/);
  assert.match(canary, /securityType: 'TrustedLaunch'/);
  assert.doesNotMatch(canary, /^\s*identity:/m);
  assert.doesNotMatch(canary, /publicIPAddressConfiguration/);
  assert.match(canaryMain, /targetScope = 'subscription'/);
  assert.match(canaryMain, /Microsoft\.Resources\/resourceGroups@2025-04-01/);
  assert.match(canaryMain, /param deploymentEnabled bool = false/);
  assert.match(
    canaryMain,
    /reproducibleInputsReady = buildContract\.policy\.reproducibleInputsReady && buildContract\.reproducibility\.status == 'locked' && aptInputsReady && flutterInputsReady/,
  );
  assert.match(canaryMain, /signerReady = attestationPolicy\.activation\.status == 'active'/);
  assert.match(
    canaryMain,
    /effectiveDeploymentEnabled = deploymentEnabled && reproducibleInputsReady && signerReady && networkInstallerImplemented/,
  );
  assert.equal(
    (canaryMain.match(/if \(effectiveDeploymentEnabled\)/g) ?? []).length,
    2,
  );
  for (const forbidden of [
    'vmss-certigo-runner-zonal',
    'vmss-certigo-pr-pilot-z1',
    'vmss-certigo-pr-v2-z1',
    '4153d1dd',
    'certigo-trusted',
  ]) {
    assert.doesNotMatch(canary, new RegExp(forbidden, 'i'));
  }
});

test('what-if validation accepts only the complete isolated resource set', () => {
  const subscription = '00000000-0000-0000-0000-000000000001';
  const runtimeGroup = canaryContract.resourceGroups.runtime;
  const base = `/subscriptions/${subscription}/resourceGroups/${runtimeGroup}`;
  const expiresOn = '2026-09-03T00:00:00.0000000+00:00';
  const location = 'westeurope';
  const adminSshPublicKey = `ssh-ed25519 ${'A'.repeat(48)} canary`;
  const resourceTags = {
    product: 'Certigo',
    workload: 'github-actions-runner',
    trustBoundary: 'untrusted-pr',
    lifecycle: 'image-canary',
    managedBy: 'bicep',
    canaryCapacity: '1',
    expiresOn,
    imageVersionFingerprint: 'abcdefghijklm',
    previousImageVersionFingerprint: 'nopqrstuvwxyz',
    runnerLabels: 'certigo-pr-image-canary',
  };
  const safeChanges = [
    {
      changeType: 'Create',
      resourceId: base,
      after: {
        location,
        tags: {
          product: 'Certigo',
          workload: 'github-actions-runner',
          lifecycle: 'image-canary',
          trustBoundary: 'untrusted-pr',
          managedBy: 'bicep',
          expiresOn,
        },
      },
    },
    {
      changeType: 'Create',
      resourceId: `${base}/providers/Microsoft.Compute/virtualMachineScaleSets/${canaryContract.resources.scaleSet}`,
      after: {
        location,
        zones: ['1'],
        tags: structuredClone(resourceTags),
        sku: { name: 'Standard_D2ads_v6', tier: 'Standard', capacity: 1 },
        properties: {
          orchestrationMode: 'Flexible',
          platformFaultDomainCount: 1,
          singlePlacementGroup: false,
          upgradePolicy: { mode: 'Manual' },
          virtualMachineProfile: {
            osProfile: {
              computerNamePrefix: 'certigo-img',
              adminUsername: 'runneradmin',
              customData: Buffer.from(
                canaryContract.runner.bootstrapLines.join('\n'),
              ).toString('base64'),
              allowExtensionOperations: true,
              linuxConfiguration: {
                disablePasswordAuthentication: true,
                provisionVMAgent: true,
                ssh: {
                  publicKeys: [{
                    keyData: adminSshPublicKey,
                    path: '/home/runneradmin/.ssh/authorized_keys',
                  }],
                },
              },
            },
            storageProfile: {
              imageReference: { id: '/subscriptions/image/version' },
              osDisk: {
                createOption: 'FromImage',
                caching: 'ReadWrite',
                diskSizeGB: 128,
                managedDisk: { storageAccountType: 'Premium_LRS' },
                deleteOption: 'Delete',
              },
            },
            securityProfile: {
              securityType: 'TrustedLaunch',
              encryptionAtHost: true,
              uefiSettings: {
                secureBootEnabled: true,
                vTpmEnabled: true,
              },
            },
            networkProfile: {
              networkApiVersion: '2020-11-01',
              networkInterfaceConfigurations: [{
                name: 'nic-pr-image-canary',
                properties: {
                  primary: true,
                  deleteOption: 'Delete',
                  enableAcceleratedNetworking: true,
                  enableIPForwarding: false,
                  ipConfigurations: [{
                    name: 'ipconfig1',
                    properties: {
                      primary: true,
                      privateIPAddressVersion: 'IPv4',
                      subnet: {
                        id:
                          `${base}/providers/Microsoft.Network/virtualNetworks/` +
                          `${canaryContract.resources.virtualNetwork}/subnets/` +
                          canaryContract.resources.subnet,
                      },
                    },
                  }],
                },
              }],
            },
            diagnosticsProfile: {
              bootDiagnostics: { enabled: true },
            },
          },
        },
      },
    },
    {
      changeType: 'Create',
      resourceId: `${base}/providers/Microsoft.Network/virtualNetworks/${canaryContract.resources.virtualNetwork}`,
      after: {
        location,
        tags: structuredClone(resourceTags),
        properties: {
          addressSpace: { addressPrefixes: ['10.44.0.0/16'] },
          subnets: [{
            name: canaryContract.resources.subnet,
            properties: {
              addressPrefix: '10.44.1.0/24',
              defaultOutboundAccess: false,
              natGateway: {
                id: `${base}/providers/Microsoft.Network/natGateways/${canaryContract.resources.natGateway}`,
              },
              networkSecurityGroup: {
                id: `${base}/providers/Microsoft.Network/networkSecurityGroups/${canaryContract.resources.networkSecurityGroup}`,
              },
              privateEndpointNetworkPolicies: 'Enabled',
              privateLinkServiceNetworkPolicies: 'Enabled',
            },
          }],
          virtualNetworkPeerings: [],
        },
      },
    },
    {
      changeType: 'Create',
      resourceId: `${base}/providers/Microsoft.Network/networkSecurityGroups/${canaryContract.resources.networkSecurityGroup}`,
      after: {
        location,
        tags: structuredClone(resourceTags),
        properties: {
          securityRules: [
            {
              name: 'deny-imds-outbound',
              properties: {
                priority: 100,
                access: 'Deny',
                direction: 'Outbound',
                protocol: '*',
                sourcePortRange: '*',
                destinationPortRange: '*',
                sourceAddressPrefix: '*',
                destinationAddressPrefix: 'AzurePlatformIMDS',
              },
            },
            {
              name: 'deny-vnet-outbound',
              properties: {
                priority: 110,
                access: 'Deny',
                direction: 'Outbound',
                protocol: '*',
                sourcePortRange: '*',
                destinationPortRange: '*',
                sourceAddressPrefix: '*',
                destinationAddressPrefix: 'VirtualNetwork',
              },
            },
            {
              name: 'deny-vnet-inbound',
              properties: {
                priority: 100,
                access: 'Deny',
                direction: 'Inbound',
                protocol: '*',
                sourcePortRange: '*',
                destinationPortRange: '*',
                sourceAddressPrefix: 'VirtualNetwork',
                destinationAddressPrefix: '*',
              },
            },
          ],
        },
      },
    },
    {
      changeType: 'Create',
      resourceId: `${base}/providers/Microsoft.Network/natGateways/${canaryContract.resources.natGateway}`,
      after: {
        location,
        zones: ['1'],
        tags: structuredClone(resourceTags),
        sku: { name: 'Standard' },
        properties: {
          idleTimeoutInMinutes: 10,
          publicIpAddresses: [{
            id: `${base}/providers/Microsoft.Network/publicIPAddresses/${canaryContract.resources.natPublicIp}`,
          }],
        },
      },
    },
    {
      changeType: 'Create',
      resourceId: `${base}/providers/Microsoft.Network/publicIPAddresses/${canaryContract.resources.natPublicIp}`,
      after: {
        location,
        zones: ['1'],
        tags: structuredClone(resourceTags),
        sku: { name: 'Standard', tier: 'Regional' },
        properties: {
          publicIPAllocationMethod: 'Static',
          publicIPAddressVersion: 'IPv4',
          idleTimeoutInMinutes: 4,
        },
      },
    },
  ];
  assert.equal(
    validateWhatIf(
      { changes: safeChanges },
      canaryContract,
      {
        direction: 'Promote',
        expiresOn,
        location,
        adminSshPublicKey,
        subscriptionId: subscription,
        targetImageId: '/subscriptions/image/version',
      },
    ),
    safeChanges.length,
  );
  const unsafeIdentity = structuredClone(safeChanges);
  unsafeIdentity[1].after.identity = { type: 'SystemAssigned' };
  assert.throws(
    () =>
      validateWhatIf(
        { changes: unsafeIdentity },
        canaryContract,
        {
          direction: 'Promote',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
        },
      ),
    /trust boundary/,
  );
  const unsafeSubnet = structuredClone(safeChanges);
  unsafeSubnet[1].after.properties.virtualMachineProfile.networkProfile
    .networkInterfaceConfigurations[0].properties.ipConfigurations[0]
    .properties.subnet.id =
      `${base}/providers/Microsoft.Network/virtualNetworks/shared/subnets/internal`;
  assert.throws(
    () =>
      validateWhatIf(
        { changes: unsafeSubnet },
        canaryContract,
        {
          direction: 'Promote',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
        },
      ),
    /VMSS Create payload/,
  );
  const unexpectedVmssProperty = structuredClone(safeChanges);
  unexpectedVmssProperty[1].after.properties.overprovision = true;
  assert.throws(
    () =>
      validateWhatIf(
        { changes: unexpectedVmssProperty },
        canaryContract,
        {
          direction: 'Promote',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
        },
      ),
    /VMSS Create payload/,
  );
  const unexpectedNsgRule = structuredClone(safeChanges);
  unexpectedNsgRule[3].after.properties.securityRules.push({
    name: 'allow-ssh-inbound',
    properties: {
      priority: 120,
      access: 'Allow',
      direction: 'Inbound',
      protocol: 'Tcp',
      sourcePortRange: '*',
      destinationPortRange: '22',
      sourceAddressPrefix: '*',
      destinationAddressPrefix: '*',
    },
  });
  assert.throws(
    () =>
      validateWhatIf(
        { changes: unexpectedNsgRule },
        canaryContract,
        {
          direction: 'Promote',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
        },
      ),
    /deny-only policy/,
  );
  assert.throws(
    () =>
      validateWhatIf(
        { changes: safeChanges.slice(0, -1) },
        canaryContract,
        {
          direction: 'Promote',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
        },
      ),
    /missing required canary resource/,
  );
  const mixedCreate = structuredClone(safeChanges);
  mixedCreate.push({
    changeType: 'Modify',
    resourceId:
      `${base}/providers/Microsoft.Compute/virtualMachineScaleSets/` +
      canaryContract.resources.scaleSet,
    delta: [{
      path: 'properties.virtualMachineProfile.storageProfile.imageReference.id',
      before: '/subscriptions/image/previous',
      after: '/subscriptions/image/version',
    }],
  });
  assert.throws(
    () =>
      validateWhatIf(
        { changes: mixedCreate },
        canaryContract,
        {
          direction: 'Promote',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
          previousImageId: '/subscriptions/image/previous',
        },
      ),
    /cannot mix Create and Modify/,
  );
  assert.throws(
    () =>
      validateWhatIf(
        { changes: safeChanges },
        canaryContract,
        {
          direction: 'Rollback',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
        },
      ),
    /Only Promote may create/,
  );
  assert.throws(
    () =>
      validateWhatIf(
        {
          changes: [
            {
              changeType: 'Modify',
              resourceId:
                '/subscriptions/current/resourceGroups/RG-CERTIGO-CI/providers/' +
                'Microsoft.Compute/virtualMachineScaleSets/vmss-certigo-runner-zonal',
            },
          ],
        },
        canaryContract,
        { subscriptionId: subscription },
      ),
    /reserved resource/,
  );
  assert.throws(
    () =>
      validateWhatIf(
        {
          changes: [{
            changeType: 'Create',
            resourceId: `${base}/providers/Microsoft.Storage/storageAccounts/${canaryContract.resources.natGateway}`,
          }],
        },
        canaryContract,
        { subscriptionId: subscription },
      ),
    /resource type/,
  );
  const nestedDeployment = structuredClone(safeChanges);
  nestedDeployment.push({
    changeType: 'NoChange',
    resourceId:
      `${base}/providers/Microsoft.Resources/deployments/` +
      'certigo-runner-image-canary',
  });
  assert.throws(
    () =>
      validateWhatIf(
        { changes: nestedDeployment },
        canaryContract,
        {
          direction: 'Promote',
          expiresOn,
          location,
          adminSshPublicKey,
          subscriptionId: subscription,
          targetImageId: '/subscriptions/image/version',
        },
      ),
    /unexpected resource/,
  );
});

test('release evidence requires cold/warm samples, attestations, and exact rollback', async () => {
  const subscription = '00000000-0000-0000-0000-000000000001';
  const cold = Array.from({ length: 20 }, (_, index) => 1000 + index * 10);
  const warm = Array.from({ length: 20 }, (_, index) => 200 + index * 5);
  assert.deepEqual(summarizeMeasurements({
    coldBootMilliseconds: cold,
    warmJobMilliseconds: warm,
  }, canaryContract), {
    coldBootP50Milliseconds: 1090,
    coldBootP95Milliseconds: 1180,
    warmJobP50Milliseconds: 245,
    warmJobP95Milliseconds: 290,
  });

  const evidence = structuredClone(plannedEvidence);
  const releaseBuildContract = structuredClone(buildContract);
  const releaseAttestationPolicy = structuredClone(attestationPolicy);
  releaseBuildContract.policy.reproducibleInputsReady = true;
  releaseBuildContract.reproducibility.status = 'locked';
  releaseAttestationPolicy.activation.status = 'active';
  releaseAttestationPolicy.signerDigest = 'a'.repeat(40);
  evidence.status = 'validated';
  evidence.liveOperationsAuthorized = true;
  const imagePrefix =
    `/subscriptions/${subscription}/resourceGroups/${canaryContract.resourceGroups.imageBuild}` +
    `/providers/Microsoft.Compute/galleries/${buildContract.destination.galleryName}` +
    `/images/${buildContract.destination.imageDefinitionName}/versions/`;
  evidence.imageBuild.galleryImageVersionId = `${imagePrefix}1.0.337`;
  evidence.imageBuild.runOutputResourceId =
    `/subscriptions/${subscription}/resourceGroups/${canaryContract.resourceGroups.imageBuild}` +
    `/providers/Microsoft.VirtualMachineImages/imageTemplates/` +
    `${buildContract.destination.imageTemplateName}/runOutputs/` +
    buildContract.destination.runOutputName;
  evidence.imageBuild.provenanceAttestationUrl =
    'https://github.com/gchambaud_microsoft/Certigo/attestations/1';
  evidence.imageBuild.sbomAttestationUrl =
    'https://github.com/gchambaud_microsoft/Certigo/attestations/2';
  evidence.rollback.previousGalleryImageVersionId =
    `${imagePrefix}1.0.336`;
  evidence.rollback.validated = true;
  evidence.whatIf.validated = true;
  evidence.whatIf.capturedAt = '2026-08-31T00:20:00Z';
  evidence.cleanup.expiresOn = '2026-09-03T00:20:00Z';
  evidence.measurements.coldBootMilliseconds = cold;
  evidence.measurements.warmJobMilliseconds = warm;
  Object.assign(evidence.measurements, summarizeMeasurements(evidence.measurements, canaryContract));
  const whatIf = {
    changes: [
      {
        changeType: 'Modify',
        resourceId:
          `/subscriptions/${subscription}/resourceGroups/${canaryContract.resourceGroups.runtime}` +
          `/providers/Microsoft.Compute/virtualMachineScaleSets/${canaryContract.resources.scaleSet}`,
        delta: [{
          path: 'properties.virtualMachineProfile.storageProfile.imageReference.id',
          before: evidence.rollback.previousGalleryImageVersionId,
          after: evidence.imageBuild.galleryImageVersionId,
        }],
      },
    ],
  };
  const descriptor = {
    schemaVersion: 2,
    contractCommit: buildContract.contractCommit,
    galleryImageVersionId: evidence.imageBuild.galleryImageVersionId,
    runOutputResourceId: evidence.imageBuild.runOutputResourceId,
    buildContractSha256: createHash('sha256')
      .update(await read('image-build-contract.json'))
      .digest('hex'),
    toolchainManifestSha256:
      buildContract.inputs.find((input) => input.id === 'toolchain-manifest').sha256,
    toolchainSbomSha256:
      buildContract.inputs.find((input) => input.id === 'toolchain-sbom').sha256,
    galleryProvisioningState: 'Succeeded',
    runOutputProvisioningState: 'Succeeded',
    immutableBuildEvidence: {
      schemaVersion: 1,
      artifactId: '456',
      artifactDigest: `sha256:${'b'.repeat(64)}`,
      artifactUrl:
        'https://github.com/gchambaud_microsoft/Certigo/actions/runs/123/artifacts/456',
      workflowRunId: '123',
      workflowRunAttempt: 1,
      deploymentId:
        `/subscriptions/${subscription}/resourceGroups/${canaryContract.resourceGroups.imageBuild}` +
        `/providers/Microsoft.Resources/deployments/${buildContract.destination.deploymentName}`,
      deploymentCorrelationId: '11111111-2222-3333-4444-555555555555',
      deploymentTimestamp: '2026-08-30T23:30:00Z',
      runStartedAt: '2026-08-30T23:40:00Z',
      runOutputCreatedAt: '2026-08-31T00:00:00Z',
      galleryVersionCreatedAt: '2026-08-31T00:01:00Z',
      galleryWriteTimestamp: '2026-08-31T00:01:00Z',
      runEndedAt: '2026-08-31T00:10:00Z',
      imageBuilderPrincipalId: 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
      galleryWriteCorrelationId: '99999999-8888-7777-6666-555555555555',
      compiledTemplateSha256: 'c'.repeat(64),
      deploymentParametersSha256: 'd'.repeat(64),
      deploymentEvidenceSha256: 'e'.repeat(64),
      activityLogSha256: 'f'.repeat(64),
      runOutputSha256: '0'.repeat(64),
      imageTemplateSha256: '1'.repeat(64),
      galleryVersionSha256: '2'.repeat(64),
      evidenceCapturedAt: '2026-08-31T00:15:00Z',
      imageTemplateId: evidence.imageBuild.runOutputResourceId.replace(
        `/runOutputs/${buildContract.destination.runOutputName}`,
        '',
      ),
      runOutputResourceId: evidence.imageBuild.runOutputResourceId,
      galleryImageVersionId: evidence.imageBuild.galleryImageVersionId,
      sourceRepository: buildContract.repository,
      sourceRef: releaseAttestationPolicy.sourceRef,
      sourceCommit: releaseAttestationPolicy.signerDigest,
    },
  };
  const rawWhatIf = JSON.stringify(whatIf);
  const rawDescriptor = JSON.stringify(descriptor);
  const rawBuildContract = await read('image-build-contract.json');
  const rawCanaryTemplate = await read('canary-main.bicep');
  evidence.whatIf.resultSha256 = createHash('sha256').update(rawWhatIf).digest('hex');
  evidence.imageBuild.descriptorSha256 =
    createHash('sha256').update(rawDescriptor).digest('hex');
  evidence.whatIf.provenance = {
    subscriptionId: subscription,
    templateSha256: createHash('sha256')
      .update(rawCanaryTemplate)
      .digest('hex'),
    buildContractSha256: createHash('sha256').update(rawBuildContract).digest('hex'),
    descriptorSha256: evidence.imageBuild.descriptorSha256,
    direction: 'Promote',
    targetImageVersionId: evidence.imageBuild.galleryImageVersionId,
    previousImageVersionId: evidence.rollback.previousGalleryImageVersionId,
  };
  assert.doesNotThrow(() =>
    validateCandidateImageId(
      evidence.imageBuild.galleryImageVersionId,
      subscription,
      canaryContract,
      releaseBuildContract,
    ));
  assert.throws(
    () => validateReleaseEvidence(
      evidence,
      canaryContract,
      releaseBuildContract,
      releaseAttestationPolicy,
      whatIf,
      descriptor,
      rawWhatIf,
      rawDescriptor,
      rawBuildContract,
      rawCanaryTemplate,
      {
        subscriptionId: subscription,
        direction: 'Promote',
        targetImageId: evidence.imageBuild.galleryImageVersionId,
      },
    ),
    /exhaustive offline network input consumption is not implemented/,
  );
  const tampered = structuredClone(whatIf);
  tampered.changes[0].delta[0].after = `${imagePrefix}9.9.9`;
  assert.throws(
    () =>
      validateWhatIf(tampered, canaryContract, {
        subscriptionId: subscription,
        targetImageId: evidence.imageBuild.galleryImageVersionId,
        previousImageId: evidence.rollback.previousGalleryImageVersionId,
      }),
    /before\/after/,
  );
  const nested = structuredClone(whatIf);
  nested.changes[0].delta = [{
    path: 'properties',
    children: [{
      path: 'virtualMachineProfile',
      children: [{
        path: 'storageProfile',
        children: [{
          path: 'imageReference',
          children: [{
            path: 'id',
            before: evidence.rollback.previousGalleryImageVersionId,
            after: evidence.imageBuild.galleryImageVersionId,
          }],
        }],
      }],
    }],
  }];
  assert.equal(
    validateWhatIf(nested, canaryContract, {
      subscriptionId: subscription,
      targetImageId: evidence.imageBuild.galleryImageVersionId,
      previousImageId: evidence.rollback.previousGalleryImageVersionId,
    }),
    1,
  );
  nested.changes[0].delta[0].children[0].children[0].children.push({
    path: 'osDisk.diskSizeGB',
    before: 128,
    after: 256,
  });
  assert.throws(
    () =>
      validateWhatIf(nested, canaryContract, {
        subscriptionId: subscription,
        targetImageId: evidence.imageBuild.galleryImageVersionId,
        previousImageId: evidence.rollback.previousGalleryImageVersionId,
      }),
    /forbidden path/,
  );
  const staleProvenance = structuredClone(evidence);
  staleProvenance.whatIf.provenance.targetImageVersionId = `${imagePrefix}9.9.9`;
  assert.throws(
    () =>
      validateReleaseEvidence(
        staleProvenance,
        canaryContract,
        releaseBuildContract,
        releaseAttestationPolicy,
        whatIf,
        descriptor,
        rawWhatIf,
        rawDescriptor,
        rawBuildContract,
        rawCanaryTemplate,
        {
          subscriptionId: subscription,
          direction: 'Promote',
          targetImageId: evidence.imageBuild.galleryImageVersionId,
        },
      ),
    /atomically bound/,
  );
  for (const [field, value, expectedError] of [
    ['artifactDigest', 'tampered', /immutable image-build deployment evidence/],
    ['sourceCommit', 'b'.repeat(40), /immutable image-build deployment evidence/],
    [
      'deploymentId',
      `${descriptor.immutableBuildEvidence.deploymentId}-replay`,
      /immutable image-build deployment evidence/,
    ],
    ['runStartedAt', '2026-08-30T20:00:00Z', /immutable image-build deployment evidence/],
    ['evidenceCapturedAt', '2026-09-01T01:00:00Z', /stale or postdates/],
  ]) {
    const tamperedDescriptor = structuredClone(descriptor);
    tamperedDescriptor.immutableBuildEvidence[field] = value;
    const rawTamperedDescriptor = JSON.stringify(tamperedDescriptor);
    const tamperedEvidence = structuredClone(evidence);
    tamperedEvidence.imageBuild.descriptorSha256 = createHash('sha256')
      .update(rawTamperedDescriptor)
      .digest('hex');
    tamperedEvidence.whatIf.provenance.descriptorSha256 =
      tamperedEvidence.imageBuild.descriptorSha256;
    assert.throws(
      () =>
        validateReleaseEvidence(
          tamperedEvidence,
          canaryContract,
          releaseBuildContract,
          releaseAttestationPolicy,
          whatIf,
          tamperedDescriptor,
          rawWhatIf,
          rawTamperedDescriptor,
          rawBuildContract,
          rawCanaryTemplate,
          {
            subscriptionId: subscription,
            direction: 'Promote',
            targetImageId: evidence.imageBuild.galleryImageVersionId,
          },
        ),
      expectedError,
      field,
    );
  }
});

test('checked-in evidence never claims uncollected live results', () => {
  assert.equal(plannedEvidence.status, 'planned');
  assert.equal(plannedEvidence.liveOperationsAuthorized, false);
  assert.equal(plannedEvidence.whatIf.validated, false);
  assert.deepEqual(plannedEvidence.measurements.coldBootMilliseconds, []);
  assert.deepEqual(plannedEvidence.measurements.warmJobMilliseconds, []);
  assert.equal(plannedEvidence.cleanup.estimatedMaximumSpendUsd, 15);
});

test('Azure evidence hashes bind immutable state and never rely on mutable tags', () => {
  const runOutput = {
    id: '/subscriptions/test/runOutputs/exact',
    tags: { mutable: 'one' },
    properties: {
      artifactId: '/subscriptions/test/versions/1.0.337',
      provisioningState: 'Succeeded',
    },
    systemData: { createdAt: '2026-08-31T00:00:00Z' },
  };
  const baseline = hashAzureEvidence('run-output', runOutput);
  const retagged = structuredClone(runOutput);
  retagged.tags.mutable = 'two';
  assert.equal(hashAzureEvidence('run-output', retagged), baseline);
  const tampered = structuredClone(runOutput);
  tampered.properties.artifactId = '/subscriptions/test/versions/9.9.9';
  assert.notEqual(hashAzureEvidence('run-output', tampered), baseline);
});

test('transition and cleanup require explicit authorization and exact isolated scope', () => {
  assert.match(transition, /CERTIGO-RUNNER-CANARY-LIVE-AUTHORIZED/);
  assert.ok(
    transition.indexOf('reproducibleInputsReady -ne $true') <
      transition.indexOf('deployment sub what-if'),
  );
  assert.ok(
    transition.indexOf('validate-network-inputs.mjs') > 0 &&
    transition.indexOf('validate-network-inputs.mjs') <
      transition.indexOf('& gh attestation verify'),
  );
  assert.match(transition, /deployment sub what-if/);
  assert.match(transition, /--result-format FullResourcePayloads/);
  assert.match(transition, /validate-canary-evidence\.mjs'\)[\s\S]+--release/);
  assert.match(transition, /Direction -eq 'Rollback'/);
  assert.match(transition, /observed-current-image\.json/);
  assert.match(transition, /transitionKind -eq 'initial-create'/);
  assert.match(transition, /Direction -ne 'Promote' -or \$runtimeGroupExists -ne 'false'/);
  assert.match(transition, /complete validated Create set/);
  assert.match(transition, /az group exists/);
  assert.match(transition, /pre-apply\.what-if\.json/);
  assert.match(transition, /Azure state drifted after the validated what-if/);
  assert.match(transition, /Assert-CurrentImageBuildEvidence -Phase 'pre-what-if'/);
  assert.match(transition, /Assert-CurrentImageBuildEvidence -Phase 'pre-apply'/);
  assert.match(transition, /--hash-azure-evidence \$check\.Kind/);
  assert.match(transition, /\$rawEvidence\.cleanup\.expiresOn = \$normalizedExpiry/);
  assert.match(transition, /gh attestation verify/);
  assert.match(transition, /--signer-workflow/);
  assert.match(transition, /--signer-digest/);
  assert.match(transition, /--signer-repo/);
  assert.match(transition, /--source-ref/);
  assert.match(transition, /--source-digest/);
  assert.match(transition, /release-evidence\.json/);
  assert.match(transition, /compiled-arm\.json/);
  assert.match(transition, /Compiled ARM changed after its validated what-if/);
  assert.match(transition, /vmss update-instances/);
  assert.doesNotMatch(transition, /vmss-certigo-runner-zonal|4153d1dd/);
  assert.match(cleanup, /CERTIGO-RUNNER-CANARY-CLEANUP-AUTHORIZED/);
  assert.match(cleanup, /group\.tags\.trustBoundary -ne 'untrusted-pr'/);
  assert.match(cleanup, /tags\.lifecycle -ne 'image-canary'/);
  assert.match(cleanup, /group delete/);
  assert.doesNotMatch(cleanup, /--no-wait/);
});

test('Checkov exception is local and preserves exact attested image upgrades', () => {
  assert.match(securityWorkflow, /--framework arm/);
  assert.match(securityWorkflow, /- CKV_AZURE_95/);
  assert.match(securityWorkflow, /runner-image-checkov\.yaml/);
  assert.match(securityWorkflow, /Exact attested Gallery versions/);
  assert.doesNotMatch(
    securityWorkflow,
    /- CKV_AZURE_(?:10|49|97|149|160)/,
  );
});

test('disabled attestation workflow derives and attests the Azure-observed descriptor', () => {
  assert.match(disabledWorkflow, /actions\/attest@1e69f48acb82d1966a394da916b4c1698aa569d6/);
  assert.match(disabledWorkflow, /azure\/login@f5d393ae46f8fde4be8b75f32e3fc50e654ad0ca/);
  assert.match(disabledWorkflow, /az resource show/);
  assert.match(
    disabledWorkflow,
    /expected_run_output="\$\{expected_template\}\/runOutputs\/certigo-pr-f8e23b2-1-0-337"/,
  );
  assert.match(
    disabledWorkflow,
    /\[\[ "\$\{RUN_OUTPUT_RESOURCE_ID,,\}" == "\$\{expected_run_output,,\}" \]\]/,
  );
  assert.match(
    disabledWorkflow,
    /expected_image="\/subscriptions\/\$\{AZURE_SUBSCRIPTION_ID\}\//,
  );
  assert.doesNotMatch(
    disabledWorkflow,
    /RUN_OUTPUT_RESOURCE_ID,,\}" == \*"\$\{expected_run_output,,\}/,
  );
  assert.match(disabledWorkflow, /az deployment group export/);
  assert.match(disabledWorkflow, /compiled-image-build-arm\.canonical\.json/);
  assert.match(disabledWorkflow, /deployment-parameters\.canonical\.json/);
  assert.match(disabledWorkflow, /image-template-activity\.canonical\.json/);
  assert.match(disabledWorkflow, /gallery-version-activity\.canonical\.json/);
  assert.match(disabledWorkflow, /image_builder_principal_id/);
  assert.match(disabledWorkflow, /run_started_epoch <= gallery_write_epoch/);
  assert.match(disabledWorkflow, /deploymentCorrelationId/);
  assert.match(disabledWorkflow, /immutableBuildEvidence/);
  assert.match(disabledWorkflow, /steps\.build_evidence\.outputs\.artifact-digest/);
  assert.match(disabledWorkflow, /runner-image-build-evidence-\$\{\{ github\.run_id \}\}/);
  assert.match(
    disabledWorkflow,
    /sha256sum "\$manifest_path".*== "\$manifest_sha256"/,
  );
  assert.match(disabledWorkflow, /sha256sum "\$sbom_path".*== "\$sbom_sha256"/);
  assert.match(disabledWorkflow, /toolchain-sbom\.cyclonedx\.document/);
  assert.doesNotMatch(disabledWorkflow, /toolchain-sbom\.cdx\.json/);
  assert.match(disabledWorkflow, /\[\[ "\$GITHUB_REF" == "refs\/heads\/main" \]\]/);
  assert.match(disabledWorkflow, /--arg sourceCommit "\$GITHUB_SHA"/);
  assert.match(disabledWorkflow, /--hash-azure-evidence/);
  assert.match(disabledWorkflow, /runOutputSha256/);
  assert.match(disabledWorkflow, /evidenceCapturedAt/);
  assert.match(disabledWorkflow, /subject-path: image-descriptor\.json/);
  assert.match(disabledWorkflow, /predicate-type: 'https:\/\/slsa\.dev\/provenance\/v1'/);
  assert.match(disabledWorkflow, /predicate-type: 'https:\/\/cyclonedx\.org\/bom'/);
  assert.match(disabledWorkflow, /environment: runner-image-canary-attestation/);
  assert.match(disabledWorkflow, /certigo-image-attestation-canary/);
  assert.doesNotMatch(disabledWorkflow, /runs-on:.*certigo-(?:trusted|pr)/);
  assert.doesNotMatch(disabledWorkflow, /subject_sha256|subject_name/);
  assert.doesNotMatch(disabledWorkflow, /\.tags\.(?:contractCommit|contractSha256)/);
  assert.doesNotMatch(disabledWorkflow, /expected_(?:run_output|image),,"\}" == \*/);
  assert.doesNotMatch(disabledWorkflow, /client-secret|AZURE_CREDENTIALS/i);
});

test('dedicated canary labels cannot be routed by active workflows', async () => {
  const workflowRoot = new URL('../../../.github/workflows/', imageRoot);
  const workflowFiles = (await readdir(workflowRoot)).filter((name) =>
    /\.ya?ml$/.test(name),
  );
  const activeWorkflows = await Promise.all(
    workflowFiles.map((name) => readFile(new URL(name, workflowRoot), 'utf8')),
  );
  for (const workflow of activeWorkflows) {
    assert.doesNotMatch(workflow, /certigo-pr-image-canary/);
    assert.doesNotMatch(workflow, /certigo-image-attestation-canary/);
  }
});
