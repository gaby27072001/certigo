#!/usr/bin/env node

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const schemaFile = fileURLToPath(
  new URL('./backend-physical-attestation.schema.json', import.meta.url),
);
const digestPattern = /^[0-9a-f]{64}$/;
const commitPattern = /^[0-9a-f]{40}$/;
const imageVersionPattern =
  /^\/subscriptions\/[^/]+\/resourceGroups\/[^/]+\/providers\/Microsoft\.Compute\/galleries\/[^/]+\/images\/[^/]+\/versions\/[^/]+$/;
const vmssPattern =
  /^\/subscriptions\/[^/]+\/resourceGroups\/[^/]+\/providers\/Microsoft\.Compute\/virtualMachineScaleSets\/[^/]+$/;
const computeScopePattern =
  /^\/subscriptions\/([^/]+)\/resourceGroups\/([^/]+)\/providers\/Microsoft\.Compute\//;
const metrics = [
  'provisioningToOnlineSeconds',
  'queueToStartSeconds',
  'cleanupToDeleteSeconds',
  'replacementReadySeconds',
];
const pools = {
  builder: {
    label: 'certigo-backend-builder',
    imageBinding: 'builderImageVersionResourceId',
    vmssBinding: 'builderVmssResourceId',
  },
  deployer: {
    label: 'certigo-backend-deployer',
    imageBinding: 'deployerImageVersionResourceId',
    vmssBinding: 'deployerVmssResourceId',
  },
};
const requiredEvidenceKinds = new Set([
  'azure-resource-inventory',
  'runner-lifecycle',
  'network-imds-probes',
  'artifact-oidc-ordering',
  'performance-raw',
]);

function fail(message) {
  throw new Error(message);
}

function readJson(file, label) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`Cannot read ${label}: ${error.message}`);
  }
}

function deepEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function compileSchema(schema) {
  const supportedKeywords = new Set([
    '$defs',
    '$id',
    '$ref',
    '$schema',
    'additionalProperties',
    'allOf',
    'const',
    'enum',
    'exclusiveMinimum',
    'format',
    'if',
    'items',
    'maxItems',
    'minItems',
    'minLength',
    'minimum',
    'pattern',
    'properties',
    'required',
    'then',
    'title',
    'type',
  ]);
  const compiledReferences = new Map();

  function inspect(node, pointer) {
    if (!isObject(node)) {
      fail(`Schema node ${pointer} must be an object.`);
    }
    for (const keyword of Object.keys(node)) {
      if (!supportedKeywords.has(keyword)) {
        fail(`Unsupported JSON Schema keyword ${keyword} at ${pointer}.`);
      }
    }
    for (const [name, child] of Object.entries(node.properties ?? {})) {
      inspect(child, `${pointer}/properties/${name}`);
    }
    for (const [name, child] of Object.entries(node.$defs ?? {})) {
      inspect(child, `${pointer}/$defs/${name}`);
    }
    for (const [index, child] of (node.allOf ?? []).entries()) {
      inspect(child, `${pointer}/allOf/${index}`);
    }
    for (const keyword of ['if', 'then', 'items']) {
      if (node[keyword] !== undefined) {
        inspect(node[keyword], `${pointer}/${keyword}`);
      }
    }
  }

  function resolveReference(reference) {
    if (!reference.startsWith('#/')) {
      fail(`Only local JSON Schema references are supported: ${reference}.`);
    }
    let target = schema;
    for (const encodedPart of reference.slice(2).split('/')) {
      const part = encodedPart.replaceAll('~1', '/').replaceAll('~0', '~');
      target = target?.[part];
    }
    if (!isObject(target)) {
      fail(`JSON Schema reference does not resolve: ${reference}.`);
    }
    return target;
  }

  function compile(node, pointer) {
    const propertyValidators = Object.fromEntries(
      Object.entries(node.properties ?? {}).map(([name, child]) => [
        name,
        compile(child, `${pointer}/properties/${name}`),
      ]),
    );
    const itemValidator = node.items
      ? compile(node.items, `${pointer}/items`)
      : undefined;
    const allOfValidators = (node.allOf ?? []).map((child, index) =>
      compile(child, `${pointer}/allOf/${index}`),
    );
    const ifValidator = node.if
      ? compile(node.if, `${pointer}/if`)
      : undefined;
    const thenValidator = node.then
      ? compile(node.then, `${pointer}/then`)
      : undefined;
    const pattern = node.pattern ? new RegExp(node.pattern, 'u') : undefined;

    return (value, instancePath, errors) => {
      if (node.$ref) {
        let validator = compiledReferences.get(node.$ref);
        if (!validator) {
          validator = compile(
            resolveReference(node.$ref),
            `${pointer} -> ${node.$ref}`,
          );
          compiledReferences.set(node.$ref, validator);
        }
        validator(value, instancePath, errors);
      }

      const typeMatches =
        node.type === undefined ||
        (node.type === 'object' && isObject(value)) ||
        (node.type === 'array' && Array.isArray(value)) ||
        (node.type === 'string' && typeof value === 'string') ||
        (node.type === 'number' &&
          typeof value === 'number' &&
          Number.isFinite(value)) ||
        (node.type === 'integer' && Number.isSafeInteger(value)) ||
        (node.type === 'boolean' && typeof value === 'boolean');
      if (!typeMatches) {
        errors.push(`${instancePath} must be ${node.type}.`);
        return;
      }
      if (node.const !== undefined && !deepEqual(value, node.const)) {
        errors.push(`${instancePath} must equal ${JSON.stringify(node.const)}.`);
      }
      if (
        node.enum &&
        !node.enum.some((candidate) => deepEqual(candidate, value))
      ) {
        errors.push(`${instancePath} is not an allowed value.`);
      }

      if (isObject(value)) {
        for (const required of node.required ?? []) {
          if (!Object.hasOwn(value, required)) {
            errors.push(`${instancePath}.${required} is required.`);
          }
        }
        if (node.additionalProperties === false) {
          for (const name of Object.keys(value)) {
            if (!Object.hasOwn(propertyValidators, name)) {
              errors.push(`${instancePath}.${name} is not allowed.`);
            }
          }
        }
        for (const [name, validator] of Object.entries(propertyValidators)) {
          if (Object.hasOwn(value, name)) {
            validator(value[name], `${instancePath}.${name}`, errors);
          }
        }
      }

      if (Array.isArray(value)) {
        if (node.minItems !== undefined && value.length < node.minItems) {
          errors.push(`${instancePath} must contain at least ${node.minItems} items.`);
        }
        if (node.maxItems !== undefined && value.length > node.maxItems) {
          errors.push(`${instancePath} must contain at most ${node.maxItems} items.`);
        }
        if (itemValidator) {
          value.forEach((item, index) =>
            itemValidator(item, `${instancePath}[${index}]`, errors),
          );
        }
      }

      if (typeof value === 'string') {
        if (node.minLength !== undefined && value.length < node.minLength) {
          errors.push(`${instancePath} is shorter than ${node.minLength}.`);
        }
        if (pattern && !pattern.test(value)) {
          errors.push(`${instancePath} does not match ${node.pattern}.`);
        }
        if (
          node.format === 'date-time' &&
          (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/.test(
            value,
          ) ||
            Number.isNaN(Date.parse(value)))
        ) {
          errors.push(`${instancePath} must be an RFC 3339 date-time.`);
        }
      }

      if (typeof value === 'number' && Number.isFinite(value)) {
        if (node.minimum !== undefined && value < node.minimum) {
          errors.push(`${instancePath} must be at least ${node.minimum}.`);
        }
        if (
          node.exclusiveMinimum !== undefined &&
          value <= node.exclusiveMinimum
        ) {
          errors.push(
            `${instancePath} must be greater than ${node.exclusiveMinimum}.`,
          );
        }
      }

      for (const validator of allOfValidators) {
        validator(value, instancePath, errors);
      }
      if (ifValidator && thenValidator) {
        const conditionErrors = [];
        ifValidator(value, instancePath, conditionErrors);
        if (conditionErrors.length === 0) {
          thenValidator(value, instancePath, errors);
        }
      }
    };
  }

  inspect(schema, '#');
  const validator = compile(schema, '#');
  return (value) => {
    const errors = [];
    validator(value, '$', errors);
    return errors;
  };
}

const validateSchema = compileSchema(
  readJson(schemaFile, 'physical attestation schema'),
);

function exactKeys(value, keys, label) {
  if (!isObject(value)) {
    fail(`${label} must be an object.`);
  }
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  if (!deepEqual(actual, expected)) {
    fail(`${label} fields must be exactly ${expected.join(', ')}.`);
  }
}

function nearestRank(values, percentile) {
  const ordered = [...values].sort((left, right) => left - right);
  return ordered[Math.ceil(percentile * ordered.length) - 1];
}

function resourceScope(resourceId) {
  const match = resourceId.match(computeScopePattern);
  if (!match) {
    fail(`Invalid Compute resource ID: ${resourceId}.`);
  }
  return `${match[1]}/${match[2]}`.toLowerCase();
}

function normalizeResourceId(resourceId) {
  return resourceId.toLowerCase();
}

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function isInside(root, candidate) {
  return candidate.startsWith(`${root}${path.sep}`);
}

function validateEvidence(evidence, evidenceRoot) {
  const root = fs.realpathSync(evidenceRoot);
  const paths = new Set();
  const filesByKind = new Map();
  for (const [index, descriptor] of evidence.entries()) {
    const label = `evidence[${index}]`;
    if (
      path.isAbsolute(descriptor.path) ||
      descriptor.path.split(/[\\/]/).includes('..')
    ) {
      fail(`${label}.path must be a safe relative path.`);
    }
    if (paths.has(descriptor.path)) {
      fail(`${label}.path duplicates an earlier evidence path.`);
    }
    paths.add(descriptor.path);
    if (filesByKind.has(descriptor.kind)) {
      fail(`${label}.kind duplicates ${descriptor.kind}.`);
    }

    const candidate = path.resolve(evidenceRoot, descriptor.path);
    if (!isInside(path.resolve(evidenceRoot), candidate)) {
      fail(`${label}.path escapes the evidence root.`);
    }
    let stats;
    try {
      stats = fs.lstatSync(candidate);
    } catch (error) {
      fail(`${label}.path cannot be read: ${error.message}`);
    }
    if (!stats.isFile() || stats.isSymbolicLink()) {
      fail(`${label}.path must identify a regular non-symlink file.`);
    }
    const resolved = fs.realpathSync(candidate);
    if (!isInside(root, resolved)) {
      fail(`${label}.path resolves outside the evidence root.`);
    }
    if (sha256(resolved) !== descriptor.sha256) {
      fail(`${label}.sha256 does not match ${descriptor.path}.`);
    }
    filesByKind.set(descriptor.kind, resolved);
  }
  for (const kind of requiredEvidenceKinds) {
    if (!filesByKind.has(kind)) {
      fail(`Evidence kind ${kind} is required.`);
    }
  }
  return filesByKind;
}

function normalizedSet(values, label) {
  const normalized = values.map((value) => {
    if (typeof value !== 'string' || value.length === 0) {
      fail(`${label} entries must be non-empty strings.`);
    }
    return value.toLowerCase();
  });
  if (new Set(normalized).size !== normalized.length) {
    fail(`${label} entries must be unique.`);
  }
  return new Set(normalized);
}

function sameSet(left, right) {
  return (
    left.size === right.size &&
    [...left].every((candidate) => right.has(candidate))
  );
}

function validatePhysicalInventory(
  inventoryFile,
  attestation,
  expectations,
  sampleVmIds,
) {
  const inventory = readJson(inventoryFile, 'signed Azure resource inventory');
  exactKeys(
    inventory,
    [
      'schema',
      'repositoryCommitSha',
      'immutableBindings',
      'pools',
      'networkPeerings',
      'applicationRoutes',
      'runtimeManagedIdentities',
    ],
    'Azure resource inventory',
  );
  if (
    inventory.schema !== 'certigo.backend-runner-physical-inventory/v1' ||
    inventory.repositoryCommitSha !== expectations.repositoryCommitSha
  ) {
    fail('Azure resource inventory schema or repository commit is not trusted.');
  }
  if (
    inventory.networkPeerings.length !== 0 ||
    inventory.applicationRoutes.length !== 0 ||
    inventory.runtimeManagedIdentities.length !== 0
  ) {
    fail('Azure resource inventory contains forbidden connectivity or identity.');
  }
  exactKeys(
    inventory.immutableBindings,
    [
      'builderImageVersionResourceId',
      'deployerImageVersionResourceId',
      'builderVmssResourceId',
      'deployerVmssResourceId',
    ],
    'Azure resource inventory immutableBindings',
  );
  for (const [name, expected] of Object.entries(expectations)) {
    if (
      name !== 'repositoryCommitSha' &&
      normalizeResourceId(inventory.immutableBindings[name]) !==
        normalizeResourceId(expected)
    ) {
      fail(`Azure resource inventory ${name} does not match the expected binding.`);
    }
  }
  exactKeys(inventory.pools, ['builder', 'deployer'], 'Azure resource inventory pools');

  const observedDiskIds = new Set();
  const observedHostIds = new Set();
  const observedNetworkIds = new Set();
  for (const [poolName, pool] of Object.entries(pools)) {
    const inventoryPool = inventory.pools[poolName];
    exactKeys(
      inventoryPool,
      [
        'runnerLabel',
        'imageVersionResourceId',
        'vmssResourceId',
        'vmResourceIds',
        'osDiskResourceIds',
        'computeHostEvidenceIds',
        'serviceUser',
        'virtualNetworkResourceId',
        'subnetResourceId',
        'networkSecurityGroupResourceId',
        'natGatewayResourceId',
        'imdsOsBlocked',
        'imdsNsgBlocked',
      ],
      `Azure resource inventory pools.${poolName}`,
    );
    const expectedImage = expectations[pool.imageBinding];
    const expectedVmss = expectations[pool.vmssBinding];
    if (
      inventoryPool.runnerLabel !== pool.label ||
      normalizeResourceId(inventoryPool.imageVersionResourceId) !==
        normalizeResourceId(expectedImage) ||
      normalizeResourceId(inventoryPool.vmssResourceId) !==
        normalizeResourceId(expectedVmss) ||
      inventoryPool.imdsOsBlocked !== true ||
      inventoryPool.imdsNsgBlocked !== true
    ) {
      fail(`Azure resource inventory ${poolName} boundary does not match.`);
    }
    const expectedServiceUser =
      poolName === 'builder' ? 'certigo-builder' : 'certigo-deployer';
    if (inventoryPool.serviceUser !== expectedServiceUser) {
      fail(`Azure resource inventory ${poolName} service user does not match.`);
    }

    const inventoryVmIds = normalizedSet(
      inventoryPool.vmResourceIds,
      `Azure resource inventory ${poolName} VM IDs`,
    );
    if (!sameSet(inventoryVmIds, sampleVmIds.get(poolName))) {
      fail(`Azure resource inventory ${poolName} VM IDs do not match samples.`);
    }
    for (const [field, globalSet] of [
      ['osDiskResourceIds', observedDiskIds],
      ['computeHostEvidenceIds', observedHostIds],
    ]) {
      if (inventoryPool[field].length !== 40) {
        fail(`Azure resource inventory ${poolName} ${field} must contain 40 entries.`);
      }
      const values = normalizedSet(
        inventoryPool[field],
        `Azure resource inventory ${poolName} ${field}`,
      );
      for (const value of values) {
        if (globalSet.has(value)) {
          fail(`Azure resource inventory reuses ${field} across pools.`);
        }
        globalSet.add(value);
      }
    }

    const scope = resourceScope(expectedVmss);
    const networkPatterns = {
      virtualNetworkResourceId:
        /\/providers\/microsoft\.network\/virtualnetworks\/[^/]+$/,
      subnetResourceId:
        /\/providers\/microsoft\.network\/virtualnetworks\/[^/]+\/subnets\/[^/]+$/,
      networkSecurityGroupResourceId:
        /\/providers\/microsoft\.network\/networksecuritygroups\/[^/]+$/,
      natGatewayResourceId:
        /\/providers\/microsoft\.network\/natgateways\/[^/]+$/,
    };
    for (const [field, pattern] of Object.entries(networkPatterns)) {
      const resourceId = normalizeResourceId(inventoryPool[field]);
      if (
        !resourceId.startsWith(
          `/subscriptions/${scope.split('/')[0]}/resourcegroups/${scope.split('/')[1]}/`,
        ) ||
        !pattern.test(resourceId) ||
        observedNetworkIds.has(resourceId)
      ) {
        fail(`Azure resource inventory ${poolName} ${field} is not isolated.`);
      }
      observedNetworkIds.add(resourceId);
    }
  }
}

function validateStatistics(poolName, performance) {
  for (const phase of ['cold', 'warm']) {
    for (const metric of metrics) {
      const values = performance[phase].map((sample) => sample[metric]);
      for (const [name, percentile] of [
        ['p50', 0.5],
        ['p95', 0.95],
      ]) {
        const recomputed = nearestRank(values, percentile);
        const declared = performance.statistics[phase][metric][name];
        if (declared !== recomputed) {
          fail(
            `performance.${poolName}.statistics.${phase}.${metric}.${name} ` +
              `must be ${recomputed}, recomputed by nearest-rank.`,
          );
        }
      }
    }
  }
}

export function validatePhysicalAttestationPayload(
  attestation,
  expectations,
  evidenceRoot,
) {
  const schemaErrors = validateSchema(attestation);
  if (schemaErrors.length > 0) {
    fail(`Physical attestation schema validation failed: ${schemaErrors.join(' ')}`);
  }
  exactKeys(
    expectations,
    [
      'repositoryCommitSha',
      'builderImageVersionResourceId',
      'deployerImageVersionResourceId',
      'builderVmssResourceId',
      'deployerVmssResourceId',
    ],
    'expectations',
  );
  if (!commitPattern.test(expectations.repositoryCommitSha)) {
    fail('Expected repository commit must be a lowercase 40-character Git SHA.');
  }
  for (const name of [
    'builderImageVersionResourceId',
    'deployerImageVersionResourceId',
  ]) {
    if (!imageVersionPattern.test(expectations[name])) {
      fail(`Expected ${name} is not an exact Gallery image version resource ID.`);
    }
  }
  for (const name of ['builderVmssResourceId', 'deployerVmssResourceId']) {
    if (!vmssPattern.test(expectations[name])) {
      fail(`Expected ${name} is not an exact VMSS resource ID.`);
    }
  }
  if (
    normalizeResourceId(expectations.builderImageVersionResourceId) ===
    normalizeResourceId(expectations.deployerImageVersionResourceId)
  ) {
    fail('Builder and deployer image version resource IDs must be distinct.');
  }
  if (
    normalizeResourceId(expectations.builderVmssResourceId) ===
      normalizeResourceId(expectations.deployerVmssResourceId) ||
    resourceScope(expectations.builderVmssResourceId) ===
      resourceScope(expectations.deployerVmssResourceId)
  ) {
    fail('Builder and deployer VMSS must use distinct runtime resource groups.');
  }
  if (attestation.status !== 'approved') {
    fail('Physical attestation status is not approved; activation remains NO-GO.');
  }
  if (
    attestation.repositoryCommitSha !== expectations.repositoryCommitSha ||
    attestation.approval.reviewedCommitSha !== expectations.repositoryCommitSha
  ) {
    fail('Attestation and approval must bind the expected repository commit.');
  }
  if (
    Date.parse(attestation.collector.collectedAtUtc) >
      Date.parse(attestation.observedAtUtc) ||
    Date.parse(attestation.approval.reviewedAtUtc) <
      Date.parse(attestation.observedAtUtc)
  ) {
    fail('Collection, observation, and approval timestamps are inconsistent.');
  }

  for (const [name, expected] of Object.entries(expectations)) {
    if (name === 'repositoryCommitSha') {
      continue;
    }
    if (
      normalizeResourceId(attestation.immutableBindings[name]) !==
      normalizeResourceId(expected)
    ) {
      fail(`immutableBindings.${name} does not match the expected resource ID.`);
    }
  }

  const observedVmIds = new Set();
  const sampleVmIds = new Map();
  let sampleCount = 0;
  for (const [poolName, pool] of Object.entries(pools)) {
    const performance = attestation.performance[poolName];
    const expectedImage = expectations[pool.imageBinding];
    const expectedVmss = expectations[pool.vmssBinding];
    const expectedScope = resourceScope(expectedVmss);
    const poolVmIds = new Set();
    for (const phase of ['cold', 'warm']) {
      for (const [index, sample] of performance[phase].entries()) {
        const samplePath = `performance.${poolName}.${phase}[${index}]`;
        if (
          sample.runnerLabel !== pool.label ||
          normalizeResourceId(sample.imageVersionResourceId) !==
            normalizeResourceId(expectedImage) ||
          normalizeResourceId(sample.vmssResourceId) !==
            normalizeResourceId(expectedVmss)
        ) {
          fail(`${samplePath} does not match its immutable pool bindings.`);
        }
        if (resourceScope(sample.vmResourceId) !== expectedScope) {
          fail(`${samplePath}.vmResourceId is outside the pool runtime scope.`);
        }
        const normalizedVmId = normalizeResourceId(sample.vmResourceId);
        if (observedVmIds.has(normalizedVmId)) {
          fail(
            `${samplePath}.vmResourceId was reused; one-job samples require fresh VMs.`,
          );
        }
        observedVmIds.add(normalizedVmId);
        poolVmIds.add(normalizedVmId);
        sampleCount += 1;
      }
    }
    sampleVmIds.set(poolName, poolVmIds);
    validateStatistics(poolName, performance);
  }
  if (sampleCount !== 80) {
    fail(`Physical attestation must contain exactly 80 samples, found ${sampleCount}.`);
  }

  const evidenceFiles = validateEvidence(attestation.evidence, evidenceRoot);
  validatePhysicalInventory(
    evidenceFiles.get('azure-resource-inventory'),
    attestation,
    expectations,
    sampleVmIds,
  );
  return {
    repositoryCommitSha: attestation.repositoryCommitSha,
    sampleCount,
    evidenceCount: attestation.evidence.length,
  };
}

function readRegularFile(file, label) {
  const resolved = path.resolve(file);
  const stats = fs.lstatSync(resolved);
  if (!stats.isFile() || stats.isSymbolicLink()) {
    fail(`${label} must identify a regular non-symlink file.`);
  }
  return {
    path: fs.realpathSync(resolved),
    bytes: fs.readFileSync(resolved),
  };
}

function trustedEd25519Key(file, expectedFingerprint, label) {
  if (!digestPattern.test(expectedFingerprint)) {
    fail(`${label} expected key fingerprint must be a lowercase SHA-256.`);
  }
  const input = readRegularFile(file, `${label} public key`);
  let key;
  try {
    key = crypto.createPublicKey(input.bytes);
  } catch (error) {
    fail(`${label} public key is invalid: ${error.message}`);
  }
  if (key.asymmetricKeyType !== 'ed25519') {
    fail(`${label} public key must be Ed25519.`);
  }
  const fingerprint = crypto
    .createHash('sha256')
    .update(key.export({ type: 'spki', format: 'der' }))
    .digest('hex');
  if (fingerprint !== expectedFingerprint) {
    fail(`${label} public key fingerprint is not allowlisted.`);
  }
  return { key, fingerprint };
}

function detachedSignature(file, label) {
  const input = readRegularFile(file, `${label} signature`);
  const encoded = input.bytes.toString('utf8').trim();
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)) {
    fail(`${label} signature must be canonical base64.`);
  }
  const signature = Buffer.from(encoded, 'base64');
  if (signature.length !== 64 || signature.toString('base64') !== encoded) {
    fail(`${label} signature must be a canonical Ed25519 signature.`);
  }
  return signature;
}

export function validateSignedPhysicalAttestation({
  attestationFile,
  collectorPublicKeyFile,
  collectorSignatureFile,
  reviewerPublicKeyFile,
  reviewerSignatureFile,
  expectations,
}) {
  exactKeys(
    expectations,
    [
      'repositoryCommitSha',
      'builderImageVersionResourceId',
      'deployerImageVersionResourceId',
      'builderVmssResourceId',
      'deployerVmssResourceId',
      'collectorId',
      'reviewerId',
      'collectorKeySha256',
      'reviewerKeySha256',
    ],
    'signed attestation expectations',
  );
  const collectorKey = trustedEd25519Key(
    collectorPublicKeyFile,
    expectations.collectorKeySha256,
    'collector',
  );
  const reviewerKey = trustedEd25519Key(
    reviewerPublicKeyFile,
    expectations.reviewerKeySha256,
    'reviewer',
  );
  if (collectorKey.fingerprint === reviewerKey.fingerprint) {
    fail('Collector and independent reviewer must use distinct trusted keys.');
  }

  const attestationInput = readRegularFile(
    attestationFile,
    'physical attestation',
  );
  for (const [label, key, signatureFile] of [
    ['collector', collectorKey.key, collectorSignatureFile],
    ['reviewer', reviewerKey.key, reviewerSignatureFile],
  ]) {
    const signature = detachedSignature(signatureFile, label);
    if (!crypto.verify(null, attestationInput.bytes, key, signature)) {
      fail(`${label} signature does not authenticate the physical attestation.`);
    }
  }

  let attestation;
  try {
    attestation = JSON.parse(attestationInput.bytes.toString('utf8'));
  } catch (error) {
    fail(`Physical attestation JSON is invalid: ${error.message}`);
  }
  if (
    attestation.collector?.id !== expectations.collectorId ||
    attestation.approval?.reviewer !== expectations.reviewerId
  ) {
    fail('Signed collector or reviewer identity is not allowlisted.');
  }
  const result = validatePhysicalAttestationPayload(
    attestation,
    {
      repositoryCommitSha: expectations.repositoryCommitSha,
      builderImageVersionResourceId:
        expectations.builderImageVersionResourceId,
      deployerImageVersionResourceId:
        expectations.deployerImageVersionResourceId,
      builderVmssResourceId: expectations.builderVmssResourceId,
      deployerVmssResourceId: expectations.deployerVmssResourceId,
    },
    path.dirname(attestationInput.path),
  );
  return {
    ...result,
    collectorKeySha256: collectorKey.fingerprint,
    reviewerKeySha256: reviewerKey.fingerprint,
  };
}

function parseArguments(argv) {
  if (argv.length % 2 !== 0) {
    fail('Every command-line option requires a value.');
  }
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const option = argv[index];
    if (!option.startsWith('--')) {
      fail(`Invalid command-line option ${option}.`);
    }
    const name = option.slice(2);
    if (Object.hasOwn(values, name)) {
      fail(`Duplicate command-line option --${name}.`);
    }
    values[name] = argv[index + 1];
  }
  exactKeys(
    values,
    [
      'attestation',
      'expected-commit',
      'expected-builder-image-version-resource-id',
      'expected-deployer-image-version-resource-id',
      'expected-builder-vmss-resource-id',
      'expected-deployer-vmss-resource-id',
      'collector-public-key',
      'collector-signature',
      'reviewer-public-key',
      'reviewer-signature',
      'expected-collector-id',
      'expected-reviewer-id',
      'expected-collector-key-sha256',
      'expected-reviewer-key-sha256',
    ],
    'command-line options',
  );
  return values;
}

function validateFromCommandLine(argv) {
  const values = parseArguments(argv);
  const result = validateSignedPhysicalAttestation({
    attestationFile: values.attestation,
    collectorPublicKeyFile: values['collector-public-key'],
    collectorSignatureFile: values['collector-signature'],
    reviewerPublicKeyFile: values['reviewer-public-key'],
    reviewerSignatureFile: values['reviewer-signature'],
    expectations: {
      repositoryCommitSha: values['expected-commit'],
      builderImageVersionResourceId:
        values['expected-builder-image-version-resource-id'],
      deployerImageVersionResourceId:
        values['expected-deployer-image-version-resource-id'],
      builderVmssResourceId: values['expected-builder-vmss-resource-id'],
      deployerVmssResourceId: values['expected-deployer-vmss-resource-id'],
      collectorId: values['expected-collector-id'],
      reviewerId: values['expected-reviewer-id'],
      collectorKeySha256: values['expected-collector-key-sha256'],
      reviewerKeySha256: values['expected-reviewer-key-sha256'],
    },
  });
  console.log(
    `Physical attestation approved for ${result.repositoryCommitSha} ` +
      `(${result.sampleCount} one-job samples, ${result.evidenceCount} evidence files).`,
  );
}

const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  try {
    validateFromCommandLine(process.argv.slice(2));
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  }
}
