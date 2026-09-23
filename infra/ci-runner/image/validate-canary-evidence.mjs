#!/usr/bin/env node
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { assertNetworkInputsReady } from './validate-network-inputs.mjs';
import { pathToFileURL } from 'node:url';

const moduleRoot = new URL('./', import.meta.url);

function flattenDeltas(deltas, parentPath = '') {
  return (deltas ?? []).flatMap((delta) => {
    const ownPath = String(delta.path ?? '');
    const path =
      !parentPath || ownPath.startsWith(`${parentPath}.`)
        ? ownPath
        : `${parentPath}.${ownPath}`;
    if (Array.isArray(delta.children) && delta.children.length > 0) {
      return flattenDeltas(delta.children, path);
    }
    return [{ ...delta, path }];
  });
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(message);
  }
}

function canonicalize(value) {
  if (Array.isArray(value)) {
    return value.map(canonicalize);
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value)
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, nested]) => [key, canonicalize(nested)]),
    );
  }
  return value;
}

function assertDeepEqual(actual, expected, message) {
  if (JSON.stringify(canonicalize(actual)) !== JSON.stringify(canonicalize(expected))) {
    throw new Error(message);
  }
}

function selectAzureEvidence(kind, resource) {
  if (kind === 'run-output') {
    return {
      id: resource.id,
      properties: {
        artifactId: resource.properties?.artifactId,
        provisioningState: resource.properties?.provisioningState,
      },
      systemData: { createdAt: resource.systemData?.createdAt },
    };
  }
  if (kind === 'image-template') {
    const properties = resource.properties ?? {};
    return {
      id: resource.id,
      identity: resource.identity,
      properties: {
        autoRun: properties.autoRun,
        buildTimeoutInMinutes: properties.buildTimeoutInMinutes,
        customize: properties.customize,
        distribute: properties.distribute,
        errorHandling: properties.errorHandling,
        lastRunStatus: properties.lastRunStatus,
        source: properties.source,
        stagingResourceGroup: properties.stagingResourceGroup,
        validate: properties.validate,
        vmProfile: properties.vmProfile,
      },
    };
  }
  if (kind === 'gallery-version') {
    const properties = resource.properties ?? {};
    return {
      id: resource.id,
      properties: {
        provisioningState: properties.provisioningState,
        publishingProfile: properties.publishingProfile,
        safetyProfile: properties.safetyProfile,
        storageProfile: properties.storageProfile,
      },
      systemData: { createdAt: resource.systemData?.createdAt },
    };
  }
  throw new Error(`Unsupported Azure evidence kind '${kind}'.`);
}

export function hashAzureEvidence(kind, resource) {
  return createHash('sha256')
    .update(JSON.stringify(canonicalize(selectAzureEvidence(kind, resource))))
    .digest('hex');
}

function validateCreatePayload(change, resourceName, contract, options) {
  const after = change.after;
  if (!after || typeof after !== 'object') {
    throw new Error(`Create payload is missing for ${change.resourceId}.`);
  }
  const properties = after.properties ?? {};
  const tags = after.tags ?? {};
  const serialized = JSON.stringify(after).toLowerCase();
  if (
    serialized.includes('"identity"') ||
    serialized.includes('publicipaddressconfiguration') ||
    serialized.includes('certigo-trusted') ||
    serialized.includes('"certigo-pr"')
  ) {
    throw new Error(`Create payload violates the canary trust boundary: ${change.resourceId}`);
  }

  if (resourceName === contract.resourceGroups.runtime.toLowerCase()) {
    assertEqual(after.location, options.location, 'Runtime group location is not exact.');
    assertEqual(
      JSON.stringify(Object.keys(tags).sort()),
      JSON.stringify(
        ['expiresOn', 'lifecycle', 'managedBy', 'product', 'trustBoundary', 'workload'].sort(),
      ),
      'Runtime group tags are not exact.',
    );
    assertEqual(tags.product, 'Certigo', 'Runtime group product tag is not exact.');
    assertEqual(tags.workload, 'github-actions-runner', 'Runtime group workload tag is not exact.');
    assertEqual(tags.lifecycle, 'image-canary', 'Runtime group lifecycle tag is not exact.');
    assertEqual(tags.trustBoundary, 'untrusted-pr', 'Runtime group trust tag is not exact.');
    assertEqual(tags.managedBy, 'bicep', 'Runtime group ownership tag is not exact.');
    assertEqual(tags.expiresOn, options.expiresOn, 'Runtime group expiry tag is not exact.');
    return;
  }
  const expectedTagKeys = [
    'canaryCapacity',
    'expiresOn',
    'imageVersionFingerprint',
    'lifecycle',
    'managedBy',
    'previousImageVersionFingerprint',
    'product',
    'runnerLabels',
    'trustBoundary',
    'workload',
  ].sort();
  assertEqual(
    JSON.stringify(Object.keys(tags).sort()),
    JSON.stringify(expectedTagKeys),
    `Canary resource tags are not exact for ${change.resourceId}.`,
  );
  assertEqual(tags.product, 'Certigo', 'Canary product tag is not exact.');
  assertEqual(tags.workload, 'github-actions-runner', 'Canary workload tag is not exact.');
  assertEqual(tags.trustBoundary, 'untrusted-pr', 'Canary trust tag is not exact.');
  assertEqual(tags.lifecycle, 'image-canary', 'Canary lifecycle tag is not exact.');
  assertEqual(tags.managedBy, 'bicep', 'Canary ownership tag is not exact.');
  assertEqual(tags.canaryCapacity, '1', 'Canary capacity tag is not exact.');
  assertEqual(tags.expiresOn, options.expiresOn, 'Canary expiry tag is not exact.');
  assertEqual(
    tags.runnerLabels,
    contract.runner.labels.join(','),
    'Canary runner label tag is not exact.',
  );
  if (
    !/^[a-z0-9]{13}$/.test(tags.imageVersionFingerprint ?? '') ||
    !/^(?:not-set|[a-z0-9]{13})$/.test(tags.previousImageVersionFingerprint ?? '')
  ) {
    throw new Error(`Canary image fingerprint tags are invalid for ${change.resourceId}.`);
  }
  assertEqual(after.location, options.location, `Canary location is not exact for ${change.resourceId}.`);

  const runtimeBase =
    `/subscriptions/${options.subscriptionId}/resourceGroups/${contract.resourceGroups.runtime}`;
  const expectedSubnetId =
    `${runtimeBase}/providers/Microsoft.Network/virtualNetworks/` +
    `${contract.resources.virtualNetwork}/subnets/${contract.resources.subnet}`;
  const expectedNsgId =
    `${runtimeBase}/providers/Microsoft.Network/networkSecurityGroups/` +
    contract.resources.networkSecurityGroup;
  const expectedNatId =
    `${runtimeBase}/providers/Microsoft.Network/natGateways/` +
    contract.resources.natGateway;
  const expectedPublicIpId =
    `${runtimeBase}/providers/Microsoft.Network/publicIPAddresses/` +
    contract.resources.natPublicIp;

  if (resourceName === contract.resources.scaleSet.toLowerCase()) {
    const bootstrapContent = contract.runner.bootstrapLines.join('\n');
    const expectedProperties = {
      orchestrationMode: 'Flexible',
      platformFaultDomainCount: 1,
      singlePlacementGroup: false,
      upgradePolicy: { mode: 'Manual' },
      virtualMachineProfile: {
        osProfile: {
          computerNamePrefix: 'certigo-img',
          adminUsername: 'runneradmin',
          customData: Buffer.from(bootstrapContent).toString('base64'),
          allowExtensionOperations: true,
          linuxConfiguration: {
            disablePasswordAuthentication: true,
            provisionVMAgent: true,
            ssh: {
              publicKeys: [{
                keyData: options.adminSshPublicKey,
                path: '/home/runneradmin/.ssh/authorized_keys',
              }],
            },
          },
        },
        storageProfile: {
          imageReference: { id: options.targetImageId },
          osDisk: {
            createOption: 'FromImage',
            caching: 'ReadWrite',
            diskSizeGB: 128,
            managedDisk: { storageAccountType: 'Premium_LRS' },
            deleteOption: 'Delete',
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
                  subnet: { id: expectedSubnetId },
                },
              }],
            },
          }],
        },
        securityProfile: {
          encryptionAtHost: true,
          securityType: 'TrustedLaunch',
          uefiSettings: {
            secureBootEnabled: true,
            vTpmEnabled: true,
          },
        },
        diagnosticsProfile: {
          bootDiagnostics: { enabled: true },
        },
      },
    };
    assertDeepEqual(
      { zones: after.zones, sku: after.sku, properties },
      {
        zones: ['1'],
        sku: { name: 'Standard_D2ads_v6', tier: 'Standard', capacity: 1 },
        properties: expectedProperties,
      },
      'Canary VMSS Create payload is not the complete exact model.',
    );
    return;
  }
  if (resourceName === contract.resources.networkSecurityGroup.toLowerCase()) {
    const rule = (name, priority, direction, source, destination) => ({
      name,
      properties: {
        priority,
        direction,
        access: 'Deny',
        protocol: '*',
        sourcePortRange: '*',
        destinationPortRange: '*',
        sourceAddressPrefix: source,
        destinationAddressPrefix: destination,
      },
    });
    assertDeepEqual(
      properties,
      {
        securityRules: [
          rule('deny-imds-outbound', 100, 'Outbound', '*', 'AzurePlatformIMDS'),
          rule('deny-vnet-outbound', 110, 'Outbound', '*', 'VirtualNetwork'),
          rule('deny-vnet-inbound', 100, 'Inbound', 'VirtualNetwork', '*'),
        ],
      },
      'Canary NSG create payload is not the exact deny-only policy.',
    );
    return;
  }
  if (resourceName === contract.resources.virtualNetwork.toLowerCase()) {
    assertDeepEqual(
      properties,
      {
        addressSpace: { addressPrefixes: ['10.44.0.0/16'] },
        subnets: [{
          name: contract.resources.subnet,
          properties: {
            addressPrefix: '10.44.1.0/24',
            defaultOutboundAccess: false,
            natGateway: { id: expectedNatId },
            networkSecurityGroup: { id: expectedNsgId },
            privateEndpointNetworkPolicies: 'Enabled',
            privateLinkServiceNetworkPolicies: 'Enabled',
          },
        }],
        virtualNetworkPeerings: [],
      },
      'Canary VNet create payload escapes the isolated network contract.',
    );
    return;
  }
  if (resourceName === contract.resources.natGateway.toLowerCase()) {
    assertDeepEqual(
      { zones: after.zones, sku: after.sku, properties },
      {
        zones: ['1'],
        sku: { name: 'Standard' },
        properties: {
          idleTimeoutInMinutes: 10,
          publicIpAddresses: [{ id: expectedPublicIpId }],
        },
      },
      'Canary NAT create payload does not use the dedicated public IP.',
    );
    return;
  }
  if (resourceName === contract.resources.natPublicIp.toLowerCase()) {
    assertDeepEqual(
      { zones: after.zones, sku: after.sku, properties },
      {
        zones: ['1'],
        sku: { name: 'Standard', tier: 'Regional' },
        properties: {
          publicIPAllocationMethod: 'Static',
          publicIPAddressVersion: 'IPv4',
          idleTimeoutInMinutes: 4,
        },
      },
      'Canary NAT public IP Create payload is not exact.',
    );
    return;
  }
  throw new Error(`Create payload is not supported for ${change.resourceId}.`);
}

export function percentile(values, requestedPercentile) {
  if (!Array.isArray(values) || values.length === 0) {
    throw new Error('A percentile requires at least one measurement.');
  }
  const sorted = values.map(Number).sort((left, right) => left - right);
  if (sorted.some((value) => !Number.isFinite(value) || value <= 0)) {
    throw new Error('Measurements must be positive finite numbers.');
  }
  const index = Math.ceil((requestedPercentile / 100) * sorted.length) - 1;
  return sorted[Math.max(0, index)];
}

export function validateWhatIf(payload, contract, options = {}) {
  const changes = payload.changes ?? payload.properties?.changes;
  if (!Array.isArray(changes)) {
    throw new Error('The what-if payload does not contain a changes array.');
  }

  const reservedTokens = [
    ...contract.reserved.virtualMachineTokens,
    ...contract.reserved.existingScaleSets,
  ].map((value) => value.toLowerCase());
  const allowedNames = new Set(
    [
      contract.resourceGroups.runtime,
      ...Object.values(contract.resources),
    ].map((value) => value.toLowerCase()),
  );
  const expectedSuffixByName = new Map([
    [
      contract.resourceGroups.runtime.toLowerCase(),
      `/resourcegroups/${contract.resourceGroups.runtime.toLowerCase()}`,
    ],
    [
      contract.resources.scaleSet.toLowerCase(),
      `/providers/microsoft.compute/virtualmachinescalesets/` +
        contract.resources.scaleSet.toLowerCase(),
    ],
    [
      contract.resources.virtualNetwork.toLowerCase(),
      `/providers/microsoft.network/virtualnetworks/` +
        contract.resources.virtualNetwork.toLowerCase(),
    ],
    [
      contract.resources.subnet.toLowerCase(),
      `/virtualnetworks/${contract.resources.virtualNetwork.toLowerCase()}/subnets/` +
        contract.resources.subnet.toLowerCase(),
    ],
    [
      contract.resources.networkSecurityGroup.toLowerCase(),
      `/providers/microsoft.network/networksecuritygroups/` +
        contract.resources.networkSecurityGroup.toLowerCase(),
    ],
    [
      contract.resources.natGateway.toLowerCase(),
      `/providers/microsoft.network/natgateways/` +
        contract.resources.natGateway.toLowerCase(),
    ],
    [
      contract.resources.natPublicIp.toLowerCase(),
      `/providers/microsoft.network/publicipaddresses/` +
        contract.resources.natPublicIp.toLowerCase(),
    ],
  ]);
  const runtimeScope = `/resourcegroups/${contract.resourceGroups.runtime.toLowerCase()}/`;
  const expectedCreates = new Set([
    contract.resourceGroups.runtime,
    contract.resources.scaleSet,
    contract.resources.virtualNetwork,
    contract.resources.networkSecurityGroup,
    contract.resources.natGateway,
    contract.resources.natPublicIp,
  ].map((value) => value.toLowerCase()));
  const observedCreates = new Set();
  let observedModifyCount = 0;
  const subscriptionId =
    options.subscriptionId ??
    /^\/subscriptions\/([^/]+)/i.exec(options.targetImageId ?? '')?.[1];
  if (!subscriptionId) {
    throw new Error('What-if validation requires an exact subscription ID.');
  }
  const subscriptionScope = `/subscriptions/${subscriptionId.toLowerCase()}/`;

  for (const change of changes) {
    const resourceId = String(change.resourceId ?? '').toLowerCase();
    const resourceName = resourceId.split('/').at(-1);
    if (!resourceId || !resourceName) {
      throw new Error('Every what-if change must expose a resourceId.');
    }
    if (reservedTokens.some((token) => resourceId.includes(token))) {
      throw new Error(`What-if touches a reserved resource: ${change.resourceId}`);
    }
    if (!resourceId.startsWith(subscriptionScope)) {
      throw new Error(`What-if escapes subscription ${subscriptionId}: ${change.resourceId}`);
    }
    const isRuntimeGroup =
      resourceId.endsWith(`/resourcegroups/${contract.resourceGroups.runtime.toLowerCase()}`);
    if (!isRuntimeGroup && !resourceId.includes(runtimeScope)) {
      throw new Error(`What-if escapes the dedicated runtime scope: ${change.resourceId}`);
    }
    if (!allowedNames.has(resourceName)) {
      throw new Error(`What-if contains an unexpected resource: ${change.resourceId}`);
    }
    if (!resourceId.endsWith(expectedSuffixByName.get(resourceName))) {
      throw new Error(`What-if resource type is unexpected: ${change.resourceId}`);
    }
    if (change.changeType === 'Create') {
      validateCreatePayload(change, resourceName, contract, options);
      observedCreates.add(resourceName);
      continue;
    }
    if (change.changeType === 'NoChange') {
      continue;
    }
    const isScaleSet = resourceName === contract.resources.scaleSet.toLowerCase();
    if (
      change.changeType !== 'Modify' ||
      !isScaleSet ||
      !options.targetImageId ||
      !options.previousImageId
    ) {
      throw new Error(
        `What-if change type ${change.changeType} is not safe for ${change.resourceId}.`,
      );
    }
    const allowedDeltaPaths = new Set([
      'properties.virtualMachineProfile.storageProfile.imageReference.id',
      'tags.imageVersionFingerprint',
      'tags.previousImageVersionFingerprint',
    ]);
    const flattenedDeltas = flattenDeltas(change.delta);
    for (const delta of flattenedDeltas) {
      if (!allowedDeltaPaths.has(delta.path)) {
        throw new Error(`VMSS what-if modifies forbidden path ${delta.path}.`);
      }
      if (
        delta.path === 'properties.virtualMachineProfile.storageProfile.imageReference.id' &&
        (delta.before !== options.previousImageId || delta.after !== options.targetImageId)
      ) {
        throw new Error('VMSS image delta does not match the exact before/after versions.');
      }
    }
    const imageDelta = flattenedDeltas.find(
      (delta) =>
        delta.path === 'properties.virtualMachineProfile.storageProfile.imageReference.id',
    );
    if (!imageDelta) {
      throw new Error('VMSS modification omits the exact image-reference delta.');
    }
    observedModifyCount += 1;
  }
  if (observedCreates.size > 0) {
    if (options.direction !== 'Promote') {
      throw new Error('Only Promote may create the initial isolated canary.');
    }
    if (observedModifyCount > 0) {
      throw new Error('Initial canary creation cannot mix Create and Modify changes.');
    }
    for (const expected of expectedCreates) {
      if (!observedCreates.has(expected)) {
        throw new Error(`Initial what-if is missing required canary resource ${expected}.`);
      }
    }
  }
  if (changes.length === 0) {
    throw new Error('A transition what-if must contain at least one scoped change.');
  }
  return changes.length;
}

export function classifyWhatIf(payload) {
  const changes = payload.changes ?? payload.properties?.changes;
  if (!Array.isArray(changes)) {
    throw new Error('The what-if payload does not contain a changes array.');
  }
  return changes.some((change) => change.changeType === 'Create')
    ? 'initial-create'
    : 'image-update';
}

export function summarizeMeasurements(measurements, contract) {
  const cold = measurements.coldBootMilliseconds;
  const warm = measurements.warmJobMilliseconds;
  if (cold.length < contract.measurements.minimumColdBootSamples) {
    throw new Error('At least 20 cold boot samples are required.');
  }
  if (warm.length < contract.measurements.minimumWarmJobSamples) {
    throw new Error('At least 20 warm job samples are required.');
  }
  return {
    coldBootP50Milliseconds: percentile(cold, 50),
    coldBootP95Milliseconds: percentile(cold, 95),
    warmJobP50Milliseconds: percentile(warm, 50),
    warmJobP95Milliseconds: percentile(warm, 95),
  };
}

export function validateCandidateImageId(imageId, subscriptionId, contract, buildContract) {
  const pattern = new RegExp(
    '^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.Compute/' +
      'galleries/([^/]+)/images/([^/]+)/versions/(\\d+\\.\\d+\\.\\d+)$',
    'i',
  );
  const match = pattern.exec(imageId);
  if (!match) {
    throw new Error('Candidate image must be an exact gallery version ID.');
  }
  const [, subscription, resourceGroup, gallery, definition, version] = match;
  if (
    subscription.toLowerCase() !== subscriptionId.toLowerCase() ||
    resourceGroup.toLowerCase() !== contract.resourceGroups.imageBuild.toLowerCase() ||
    gallery.toLowerCase() !== buildContract.destination.galleryName.toLowerCase() ||
    definition.toLowerCase() !== buildContract.destination.imageDefinitionName.toLowerCase() ||
    version !== buildContract.destination.imageVersion
  ) {
    throw new Error('Candidate image is not the contract-pinned AIB output.');
  }
}

export function validatePreviousImageId(imageId, subscriptionId, contract, buildContract) {
  const expectedPrefix =
    `/subscriptions/${subscriptionId}/resourceGroups/${contract.resourceGroups.imageBuild}` +
    `/providers/Microsoft.Compute/galleries/${buildContract.destination.galleryName}` +
    `/images/${buildContract.destination.imageDefinitionName}/versions/`;
  if (
    !imageId.toLowerCase().startsWith(expectedPrefix.toLowerCase()) ||
    !/\d+\.\d+\.\d+$/.test(imageId)
  ) {
    throw new Error('Previous image must be an exact version from the contracted gallery.');
  }
}

export function validateReleaseEvidence(
  evidence,
  contract,
  buildContract,
  attestationPolicy,
  whatIfPayload,
  descriptor,
  rawWhatIf,
  rawDescriptor,
  rawBuildContract,
  rawCanaryTemplate,
  options,
) {
  if (!evidence.liveOperationsAuthorized) {
    throw new Error('Release evidence must record explicit live authorization.');
  }
  const versionPattern = /\/galleries\/[^/]+\/images\/[^/]+\/versions\/\d+\.\d+\.\d+$/i;
  const active = evidence.imageBuild.galleryImageVersionId;
  const previous = evidence.rollback.previousGalleryImageVersionId;
  if (!versionPattern.test(active) || !versionPattern.test(previous) || active === previous) {
    throw new Error('Active and previous images must be distinct exact gallery versions.');
  }
  validateCandidateImageId(active, options.subscriptionId, contract, buildContract);
  validatePreviousImageId(previous, options.subscriptionId, contract, buildContract);
  validateWhatIf(whatIfPayload, contract, {
    direction: options.direction,
    expiresOn: evidence.cleanup.expiresOn,
    subscriptionId: options.subscriptionId,
    targetImageId: options.direction === 'Rollback' ? previous : active,
    previousImageId: options.direction === 'Rollback' ? active : previous,
    adminSshPublicKey: options.adminSshPublicKey,
    location: options.location,
  });
  const transitionKind = classifyWhatIf(whatIfPayload);
  const isInitialCreate = transitionKind === 'initial-create';
  if (
    buildContract.policy.reproducibleInputsReady !== true ||
    buildContract.reproducibility.status !== 'locked' ||
    !buildContract.reproducibility.aptSnapshot ||
    !/^[0-9a-f]{64}$/.test(buildContract.reproducibility.aptPackageLockSha256 ?? '') ||
    !/^[0-9a-f]{64}$/.test(
      buildContract.reproducibility.flutterEngineArtifactLockSha256 ?? '',
    ) ||
    attestationPolicy.activation.status !== 'active' ||
    !/^[0-9a-f]{40}$/.test(attestationPolicy.signerDigest ?? '') ||
    !Number.isInteger(attestationPolicy.maximumEvidenceAgeHours) ||
    attestationPolicy.maximumEvidenceAgeHours <= 0
  ) {
    throw new Error('Release is blocked until network inputs and signer digest are locked.');
  }
  const expectedRunOutput =
    `/subscriptions/${options.subscriptionId}/resourceGroups/${contract.resourceGroups.imageBuild}` +
    `/providers/Microsoft.VirtualMachineImages/imageTemplates/` +
    `${buildContract.destination.imageTemplateName}/runOutputs/` +
    buildContract.destination.runOutputName;
  const expectedImageTemplate = expectedRunOutput.replace(
    `/runOutputs/${buildContract.destination.runOutputName}`,
    '',
  );
  const expectedDeployment =
    `/subscriptions/${options.subscriptionId}/resourceGroups/${contract.resourceGroups.imageBuild}` +
    `/providers/Microsoft.Resources/deployments/${buildContract.destination.deploymentName}`;
  if (
    evidence.status !== (isInitialCreate ? 'provision-authorized' : 'validated') ||
    evidence.imageBuild.runOutputResourceId.toLowerCase() !== expectedRunOutput.toLowerCase()
  ) {
    throw new Error('Release evidence does not identify the exact successful AIB run output.');
  }
  if (
    !String(evidence.imageBuild.provenanceAttestationUrl).startsWith(
      'https://github.com/gchambaud_microsoft/Certigo/attestations/',
    ) ||
    !String(evidence.imageBuild.sbomAttestationUrl).startsWith(
      'https://github.com/gchambaud_microsoft/Certigo/attestations/',
    )
  ) {
    throw new Error('Provenance and SBOM attestations are required.');
  }
  if (!evidence.whatIf.validated || (!isInitialCreate && !evidence.rollback.validated)) {
    throw new Error('Required rollback and what-if evidence is not validated.');
  }
  if (
    descriptor.contractCommit !== buildContract.contractCommit ||
    descriptor.schemaVersion !== 2 ||
    descriptor.galleryImageVersionId !== active ||
    descriptor.runOutputResourceId !== evidence.imageBuild.runOutputResourceId ||
    descriptor.buildContractSha256 !==
      createHash('sha256').update(rawBuildContract).digest('hex') ||
    descriptor.toolchainManifestSha256 !==
      buildContract.inputs.find((input) => input.id === 'toolchain-manifest').sha256 ||
    descriptor.toolchainSbomSha256 !==
      buildContract.inputs.find((input) => input.id === 'toolchain-sbom').sha256 ||
    descriptor.galleryProvisioningState !== 'Succeeded' ||
    descriptor.runOutputProvisioningState !== 'Succeeded'
  ) {
    throw new Error('Image descriptor is not bound to the successful contracted AIB output.');
  }
  const immutableEvidence = descriptor.immutableBuildEvidence;
  const artifactId = String(immutableEvidence?.artifactId ?? '');
  const workflowRunId = String(immutableEvidence?.workflowRunId ?? '');
  const expectedArtifactUrl =
    `https://github.com/${buildContract.repository}/actions/runs/${workflowRunId}` +
    `/artifacts/${artifactId}`;
  const deploymentTimestamp = Date.parse(immutableEvidence?.deploymentTimestamp ?? '');
  const runStartedAt = Date.parse(immutableEvidence?.runStartedAt ?? '');
  const runEndedAt = Date.parse(immutableEvidence?.runEndedAt ?? '');
  const runOutputCreatedAt = Date.parse(immutableEvidence?.runOutputCreatedAt ?? '');
  const galleryVersionCreatedAt = Date.parse(
    immutableEvidence?.galleryVersionCreatedAt ?? '',
  );
  const galleryWriteTimestamp = Date.parse(
    immutableEvidence?.galleryWriteTimestamp ?? '',
  );
  const buildEvidenceCapturedAt = Date.parse(
    immutableEvidence?.evidenceCapturedAt ?? '',
  );
  const orderedBuildTimestamps =
    [deploymentTimestamp, runStartedAt, runEndedAt, runOutputCreatedAt,
      galleryVersionCreatedAt, galleryWriteTimestamp, buildEvidenceCapturedAt]
      .every(Number.isFinite) &&
    deploymentTimestamp <= runStartedAt &&
    runStartedAt <= runOutputCreatedAt &&
    runOutputCreatedAt <= runEndedAt &&
    runStartedAt <= galleryVersionCreatedAt &&
    galleryVersionCreatedAt <= runEndedAt &&
    runStartedAt <= galleryWriteTimestamp &&
    galleryWriteTimestamp <= runEndedAt &&
    runEndedAt <= buildEvidenceCapturedAt;
  if (
    immutableEvidence?.schemaVersion !== 1 ||
    immutableEvidence?.deploymentId?.toLowerCase() !== expectedDeployment.toLowerCase() ||
    immutableEvidence?.imageTemplateId?.toLowerCase() !== expectedImageTemplate.toLowerCase() ||
    immutableEvidence?.runOutputResourceId?.toLowerCase() !== expectedRunOutput.toLowerCase() ||
    immutableEvidence?.galleryImageVersionId?.toLowerCase() !== active.toLowerCase() ||
    immutableEvidence?.sourceRepository !== buildContract.repository ||
    immutableEvidence?.sourceRef !== attestationPolicy.sourceRef ||
    immutableEvidence?.sourceCommit !== attestationPolicy.signerDigest ||
    !/^[1-9]\d*$/.test(artifactId) ||
    !/^[1-9]\d*$/.test(workflowRunId) ||
    !/^[1-9]\d*$/.test(String(immutableEvidence?.workflowRunAttempt ?? '')) ||
    immutableEvidence?.artifactUrl !== expectedArtifactUrl ||
    !/^(?:sha256:)?[0-9a-f]{64}$/.test(immutableEvidence?.artifactDigest ?? '') ||
    !/^[0-9a-f]{64}$/.test(immutableEvidence?.compiledTemplateSha256 ?? '') ||
    !/^[0-9a-f]{64}$/.test(immutableEvidence?.deploymentParametersSha256 ?? '') ||
    !/^[0-9a-f]{64}$/.test(immutableEvidence?.deploymentEvidenceSha256 ?? '') ||
    !/^[0-9a-f]{64}$/.test(immutableEvidence?.activityLogSha256 ?? '') ||
    !/^[0-9a-f]{64}$/.test(immutableEvidence?.runOutputSha256 ?? '') ||
    !/^[0-9a-f]{64}$/.test(immutableEvidence?.imageTemplateSha256 ?? '') ||
    !/^[0-9a-f]{64}$/.test(immutableEvidence?.galleryVersionSha256 ?? '') ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(
      immutableEvidence?.deploymentCorrelationId ?? '',
    ) ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      immutableEvidence?.imageBuilderPrincipalId ?? '',
    ) ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
      immutableEvidence?.galleryWriteCorrelationId ?? '',
    ) ||
    !orderedBuildTimestamps
  ) {
    throw new Error('Descriptor lacks exact immutable image-build deployment evidence.');
  }
  const descriptorDigest = createHash('sha256').update(rawDescriptor).digest('hex');
  if (descriptorDigest !== evidence.imageBuild.descriptorSha256) {
    throw new Error('Image descriptor digest does not match release evidence.');
  }
  const whatIfDigest = createHash('sha256').update(rawWhatIf).digest('hex');
  if (whatIfDigest !== evidence.whatIf.resultSha256) {
    throw new Error('What-if digest does not match release evidence.');
  }
  const provenance = evidence.whatIf.provenance;
  const expectedBuildContractDigest =
    createHash('sha256').update(rawBuildContract).digest('hex');
  const expectedDescriptorDigest =
    createHash('sha256').update(rawDescriptor).digest('hex');
  const expectedTemplateDigest =
    createHash('sha256').update(rawCanaryTemplate).digest('hex');
  const previousImageId =
    options.direction === 'Rollback' ? active : previous;
  const targetImageId =
    options.direction === 'Rollback' ? previous : active;
  if (
    provenance.subscriptionId !== options.subscriptionId ||
    provenance.templateSha256 !== expectedTemplateDigest ||
    provenance.buildContractSha256 !== expectedBuildContractDigest ||
    provenance.descriptorSha256 !== expectedDescriptorDigest ||
    provenance.direction !== options.direction ||
    provenance.targetImageVersionId !== targetImageId ||
    provenance.previousImageVersionId !== previousImageId
  ) {
    throw new Error('What-if provenance is not atomically bound to exact transition inputs.');
  }
  const capturedAt = Date.parse(evidence.whatIf.capturedAt);
  const expiresOn = Date.parse(evidence.cleanup.expiresOn);
  if (!Number.isFinite(capturedAt) || !Number.isFinite(expiresOn) || expiresOn <= capturedAt) {
    throw new Error('Evidence timestamps or cleanup expiry are invalid.');
  }
  if (
    capturedAt < buildEvidenceCapturedAt ||
    capturedAt - buildEvidenceCapturedAt >
      attestationPolicy.maximumEvidenceAgeHours * 60 * 60 * 1000
  ) {
    throw new Error('Immutable image-build evidence is stale or postdates the what-if.');
  }
  if (
    expiresOn - capturedAt >
    contract.budget.maximumLifetimeHours * 60 * 60 * 1000
  ) {
    throw new Error('Cleanup expiry exceeds the canary lifetime budget.');
  }
  if (evidence.cleanup.estimatedMaximumSpendUsd > contract.budget.maximumCanarySpendUsd) {
    throw new Error('Estimated spend exceeds the canary budget.');
  }
  let summary = {};
  if (isInitialCreate) {
    const measurementValues = [
      ...(evidence.measurements.coldBootMilliseconds ?? []),
      ...(evidence.measurements.warmJobMilliseconds ?? []),
    ];
    if (
      measurementValues.length !== 0 ||
      evidence.rollback.validated ||
      ['coldBootP50Milliseconds', 'coldBootP95Milliseconds',
        'warmJobP50Milliseconds', 'warmJobP95Milliseconds']
        .some((key) => evidence.measurements[key] !== null)
    ) {
      throw new Error('Initial provisioning must not claim post-deployment measurements.');
    }
  }
  else {
    summary = summarizeMeasurements(evidence.measurements, contract);
    for (const [key, value] of Object.entries(summary)) {
      if (evidence.measurements[key] !== value) {
        throw new Error(`Recorded measurement summary ${key} does not match raw samples.`);
      }
    }
  }
  if (options.targetImageId !== targetImageId) {
    throw new Error('Requested transition target does not match release evidence.');
  }
  assertNetworkInputsReady(buildContract);
  return {
    ...summary,
    transitionKind,
  };
}

async function loadJson(path) {
  return JSON.parse(await readFile(path, 'utf8'));
}

async function main() {
  const mode = process.argv[2] ?? '--plan';
  if (mode === '--hash-azure-evidence' && process.argv.length === 5) {
    const resource = await loadJson(process.argv[4]);
    process.stdout.write(`${hashAzureEvidence(process.argv[3], resource)}\n`);
    return;
  }
  const contract = await loadJson(new URL('canary-contract.json', moduleRoot));
  const buildContract = await loadJson(new URL('image-build-contract.json', moduleRoot));
  const attestationPolicy = await loadJson(new URL('attestation-policy.json', moduleRoot));
  const rawBuildContract = await readFile(
    new URL('image-build-contract.json', moduleRoot),
    'utf8',
  );
  const evidence = await loadJson(new URL('canary-evidence.json', moduleRoot));

  if (mode === '--plan') {
    if (contract.liveOperationsAuthorized || evidence.liveOperationsAuthorized) {
      throw new Error('Checked-in canary state must not authorize live operations.');
    }
    if (evidence.status !== 'planned' || evidence.whatIf.validated) {
      throw new Error('Checked-in evidence must remain explicitly uncollected.');
    }
    if (
      buildContract.policy.reproducibleInputsReady ||
      buildContract.reproducibility.status !== 'blocked'
    ) {
      throw new Error('PR2 must remain blocked until all network artifacts are locked.');
    }
    const estimatedVmSpend =
      contract.budget.linuxVmHourlyUsd * contract.budget.maximumLifetimeHours;
    if (estimatedVmSpend >= contract.budget.maximumCanarySpendUsd) {
      throw new Error('The budget ceiling must leave room for network and image storage.');
    }
    process.stdout.write(
      `${JSON.stringify({
        status: evidence.status,
        estimatedVmSpendUsd: Number(estimatedVmSpend.toFixed(2)),
        maximumCanarySpendUsd: contract.budget.maximumCanarySpendUsd,
      })}\n`,
    );
    return;
  }

  if (mode === '--what-if' && process.argv.length === 11) {
    const rawWhatIf = await readFile(process.argv[3], 'utf8');
    const whatIfPayload = JSON.parse(rawWhatIf);
    const changeCount = validateWhatIf(whatIfPayload, contract, {
      direction: process.argv[4],
      targetImageId: process.argv[5],
      previousImageId: process.argv[6],
      subscriptionId: process.argv[7],
      expiresOn: process.argv[8],
      location: process.argv[9],
      adminSshPublicKey: process.argv[10],
    });
    process.stdout.write(`${JSON.stringify({ validated: true, changeCount })}\n`);
    return;
  }

  if (mode !== '--release' || process.argv.length !== 12) {
    throw new Error(
      'Usage: validate-canary-evidence.mjs [--plan | ' +
        '--hash-azure-evidence <run-output|image-template|gallery-version> <json> | ' +
        '--what-if <what-if.json> <Promote|Rollback> <target-image-id> ' +
        '<previous-image-id> <subscription-id> <expires-on> <location> <ssh-public-key> | ' +
        '--release <evidence.json> <what-if.json> <descriptor.json> <compiled-arm.json> ' +
        '<subscription-id> <Promote|Rollback> <target-image-id> <location> <ssh-public-key>]',
    );
  }
  const [rawEvidence, rawWhatIf, rawDescriptor, rawCanaryTemplate] = await Promise.all([
    readFile(process.argv[3], 'utf8'),
    readFile(process.argv[4], 'utf8'),
    readFile(process.argv[5], 'utf8'),
    readFile(process.argv[6], 'utf8'),
  ]);
  const releaseEvidence = JSON.parse(rawEvidence);
  const whatIfPayload = JSON.parse(rawWhatIf);
  const descriptor = JSON.parse(rawDescriptor);
  const summary = validateReleaseEvidence(
    releaseEvidence,
    contract,
    buildContract,
    attestationPolicy,
    whatIfPayload,
    descriptor,
    rawWhatIf,
    rawDescriptor,
    rawBuildContract,
    rawCanaryTemplate,
    {
      subscriptionId: process.argv[7],
      direction: process.argv[8],
      targetImageId: process.argv[9],
      location: process.argv[10],
      adminSshPublicKey: process.argv[11],
    },
  );
  const digest = createHash('sha256')
    .update(JSON.stringify(releaseEvidence))
    .digest('hex');
  process.stdout.write(`${JSON.stringify({ digest, ...summary })}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
