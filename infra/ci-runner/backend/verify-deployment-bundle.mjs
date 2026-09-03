#!/opt/actions-runner/externals/node20/bin/node

import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { pathToFileURL } from 'node:url';

const manifestSchema = 'certigo.backend.deployment-bundle/v1';
const provenancePredicateType = 'https://slsa.dev/provenance/v1';
const builderLabel = 'certigo-backend-builder';
const shaPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^[0-9a-f]{64}$/;
const workflowPattern =
  /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+\/\.github\/workflows\/[A-Za-z0-9_.-]+\.ya?ml$/;

function fail(message) {
  throw new Error(message);
}

function parseArguments(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    const value = argv[index + 1];
    if (!name?.startsWith('--') || value === undefined) {
      fail(`Invalid argument near ${name ?? '<end>'}.`);
    }
    values[name.slice(2)] = value;
  }
  return values;
}

function requireValue(values, name) {
  const value = values[name];
  if (!value) {
    fail(`--${name} is required.`);
  }
  return value;
}

function exactKeys(value, keys, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  if (
    JSON.stringify(Object.keys(value).sort()) !==
    JSON.stringify([...keys].sort())
  ) {
    fail(`${label} fields must be exactly ${[...keys].sort().join(', ')}.`);
  }
}

function readJson(file, label) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    fail(`Cannot read ${label}: ${error.message}`);
  }
}

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function validateZipEntries(file) {
  const archive = fs.readFileSync(file);
  const endMinimum = 22;
  const endSearchStart = Math.max(0, archive.length - 65_557);
  let endOffset = -1;
  for (let offset = archive.length - endMinimum; offset >= endSearchStart; offset -= 1) {
    if (archive.readUInt32LE(offset) === 0x06054b50) {
      endOffset = offset;
      break;
    }
  }
  if (endOffset < 0) {
    fail('deployment package must be a structurally valid ZIP archive.');
  }
  const diskNumber = archive.readUInt16LE(endOffset + 4);
  const directoryDisk = archive.readUInt16LE(endOffset + 6);
  const entriesOnDisk = archive.readUInt16LE(endOffset + 8);
  const entryCount = archive.readUInt16LE(endOffset + 10);
  const directorySize = archive.readUInt32LE(endOffset + 12);
  const directoryOffset = archive.readUInt32LE(endOffset + 16);
  if (
    diskNumber !== 0 ||
    directoryDisk !== 0 ||
    entriesOnDisk !== entryCount ||
    entryCount === 0 ||
    entryCount === 0xffff ||
    directorySize === 0xffffffff ||
    directoryOffset === 0xffffffff ||
    directoryOffset + directorySize > endOffset
  ) {
    fail('deployment package ZIP layout is unsupported or multi-disk.');
  }

  let offset = directoryOffset;
  const names = new Set();
  for (let index = 0; index < entryCount; index += 1) {
    if (offset + 46 > archive.length || archive.readUInt32LE(offset) !== 0x02014b50) {
      fail('deployment package ZIP central directory is invalid.');
    }
    const flags = archive.readUInt16LE(offset + 8);
    const nameLength = archive.readUInt16LE(offset + 28);
    const extraLength = archive.readUInt16LE(offset + 30);
    const commentLength = archive.readUInt16LE(offset + 32);
    const externalAttributes = archive.readUInt32LE(offset + 38);
    const localOffset = archive.readUInt32LE(offset + 42);
    const entryEnd = offset + 46 + nameLength + extraLength + commentLength;
    if (
      flags & 0x1 ||
      nameLength === 0 ||
      entryEnd > archive.length ||
      localOffset + 30 > archive.length ||
      archive.readUInt32LE(localOffset) !== 0x04034b50
    ) {
      fail('deployment package ZIP entry is encrypted or malformed.');
    }
    const nameBuffer = archive.subarray(offset + 46, offset + 46 + nameLength);
    if (nameBuffer.includes(0)) {
      fail('deployment package ZIP entry contains a NUL byte.');
    }
    const name = nameBuffer.toString('utf8');
    const normalized = name.replaceAll('\\', '/');
    if (
      name.includes('\uFFFD') ||
      normalized.startsWith('/') ||
      /^[A-Za-z]:\//.test(normalized) ||
      normalized.split('/').includes('..') ||
      names.has(normalized)
    ) {
      fail(`deployment package contains unsafe ZIP entry ${JSON.stringify(name)}.`);
    }
    const unixMode = externalAttributes >>> 16;
    if ((unixMode & 0o170000) === 0o120000) {
      fail(`deployment package contains symbolic-link ZIP entry ${JSON.stringify(name)}.`);
    }
    const localNameLength = archive.readUInt16LE(localOffset + 26);
    const localExtraLength = archive.readUInt16LE(localOffset + 28);
    const localNameEnd = localOffset + 30 + localNameLength;
    if (
      localNameEnd + localExtraLength > archive.length ||
      !archive
        .subarray(localOffset + 30, localNameEnd)
        .equals(nameBuffer)
    ) {
      fail('deployment package ZIP local and central entry names differ.');
    }
    names.add(normalized);
    offset = entryEnd;
  }
  if (offset !== directoryOffset + directorySize) {
    fail('deployment package ZIP central directory size does not match.');
  }
  return entryCount;
}

function resolveDescriptor(bundleRoot, descriptor, label) {
  exactKeys(descriptor, ['path', 'sha256', 'size'], label);
  if (
    typeof descriptor.path !== 'string' ||
    descriptor.path.length === 0 ||
    path.isAbsolute(descriptor.path) ||
    descriptor.path.split(/[\\/]/).includes('..')
  ) {
    fail(`${label}.path must be a safe relative path.`);
  }
  if (!digestPattern.test(descriptor.sha256)) {
    fail(`${label}.sha256 must be a lowercase SHA-256 digest.`);
  }
  if (!Number.isSafeInteger(descriptor.size) || descriptor.size < 1) {
    fail(`${label}.size must be a positive integer.`);
  }

  const file = path.resolve(bundleRoot, descriptor.path);
  if (!file.startsWith(`${bundleRoot}${path.sep}`)) {
    fail(`${label}.path escapes the deployment bundle.`);
  }
  const stats = fs.lstatSync(file);
  if (!stats.isFile() || stats.isSymbolicLink()) {
    fail(`${label}.path must resolve to a regular non-symlink file.`);
  }
  const resolvedFile = fs.realpathSync(file);
  if (!resolvedFile.startsWith(`${bundleRoot}${path.sep}`)) {
    fail(`${label}.path resolves outside the deployment bundle.`);
  }
  if (
    stats.size !== descriptor.size ||
    sha256(resolvedFile) !== descriptor.sha256
  ) {
    fail(`${label} does not match its size and digest.`);
  }
  return resolvedFile;
}

export function validateGithubAttestationResults(results, attestedFile) {
  if (!Array.isArray(results) || results.length === 0) {
    fail('GitHub artifact attestation verification returned no result.');
  }
  const attestedDigest = sha256(attestedFile);
  const verified = results.filter((result) => {
    const verification = result?.verificationResult;
    const subjects = verification?.statement?.subject;
    const certificate = verification?.signature?.certificate;
    return (
      verification?.statement?.predicateType === provenancePredicateType &&
      Array.isArray(subjects) &&
      subjects.some(
        (subject) =>
          subject?.digest?.sha256 === attestedDigest &&
          path.basename(subject.name ?? '') === path.basename(attestedFile),
      ) &&
      certificate !== null &&
      typeof certificate === 'object' &&
      !Array.isArray(certificate) &&
      Array.isArray(verification?.verifiedTimestamps) &&
      verification.verifiedTimestamps.length > 0
    );
  });
  if (verified.length === 0) {
    fail(
      'GitHub artifact attestation result does not bind the canonical manifest.',
    );
  }
  return {
    count: verified.length,
    predicateType: provenancePredicateType,
  };
}

function verifyGithubAttestation({
  expectedCommit,
  expectedRepository,
  expectedWorkflow,
  attestedFile,
}) {
  const args = [
    'attestation',
    'verify',
    attestedFile,
    '--repo',
    expectedRepository,
    '--signer-workflow',
    expectedWorkflow,
    '--signer-digest',
    expectedCommit,
    '--source-ref',
    'refs/heads/main',
    '--source-digest',
    expectedCommit,
    '--predicate-type',
    provenancePredicateType,
    '--format',
    'json',
  ];
  let output;
  try {
    output = execFileSync('/usr/local/bin/gh', args, {
      encoding: 'utf8',
      maxBuffer: 16 * 1024 * 1024,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  } catch (error) {
    const detail = String(error.stderr ?? error.message).trim();
    fail(`GitHub artifact attestation verification failed: ${detail}`);
  }

  let results;
  try {
    results = JSON.parse(output);
  } catch (error) {
    fail(`GitHub artifact attestation output is invalid: ${error.message}`);
  }
  return validateGithubAttestationResults(results, attestedFile);
}

export function verifyDeploymentBundle(
  values,
  attestationVerifier = verifyGithubAttestation,
) {
  const expectedCommit = requireValue(values, 'expected-commit');
  const expectedRepository = requireValue(values, 'expected-repository');
  const expectedWorkflow = requireValue(values, 'expected-workflow');
  const expectedRunId = requireValue(values, 'expected-run-id');
  const expectedPackageSha256 = requireValue(
    values,
    'expected-package-sha256',
  );
  if (!shaPattern.test(expectedCommit)) {
    fail('--expected-commit must be a lowercase 40-character Git SHA.');
  }
  if (!/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(expectedRepository)) {
    fail('--expected-repository must be an owner/repository pair.');
  }
  if (
    !workflowPattern.test(expectedWorkflow) ||
    !expectedWorkflow.startsWith(`${expectedRepository}/.github/workflows/`)
  ) {
    fail('--expected-workflow must be a workflow in the expected repository.');
  }
  if (!/^[1-9][0-9]{0,19}$/.test(expectedRunId)) {
    fail('--expected-run-id must be a positive GitHub Actions run id.');
  }
  if (!digestPattern.test(expectedPackageSha256)) {
    fail('--expected-package-sha256 must be a lowercase SHA-256 digest.');
  }

  const requestedManifestFile = path.resolve(requireValue(values, 'manifest'));
  const manifestStats = fs.lstatSync(requestedManifestFile);
  if (!manifestStats.isFile() || manifestStats.isSymbolicLink()) {
    fail('deployment manifest must be a regular non-symlink file.');
  }
  const manifestFile = fs.realpathSync(requestedManifestFile);
  const bundleRoot = path.dirname(manifestFile);
  const manifest = readJson(manifestFile, 'deployment manifest');
  exactKeys(
    manifest,
    ['schema', 'commitSha', 'source', 'artifacts'],
    'manifest',
  );
  if (manifest.schema !== manifestSchema || manifest.commitSha !== expectedCommit) {
    fail('deployment manifest schema or commit is not trusted.');
  }
  exactKeys(
    manifest.source,
    [
      'repository',
      'ref',
      'event',
      'workflowRef',
      'runId',
      'runAttempt',
      'builderLabel',
      'azureIdentityUsed',
    ],
    'manifest.source',
  );
  if (
    manifest.source.repository !== expectedRepository ||
    manifest.source.ref !== 'refs/heads/main' ||
    manifest.source.event !== 'push' ||
    String(manifest.source.runId) !== expectedRunId ||
    !Number.isSafeInteger(manifest.source.runAttempt) ||
    manifest.source.runAttempt < 1 ||
    manifest.source.builderLabel !== builderLabel ||
    manifest.source.azureIdentityUsed !== false ||
    manifest.source.workflowRef !== `${expectedWorkflow}@refs/heads/main`
  ) {
    fail('deployment manifest source provenance is not trusted.');
  }
  exactKeys(
    manifest.artifacts,
    ['package', 'sbom'],
    'manifest.artifacts',
  );

  const packageFile = resolveDescriptor(
    bundleRoot,
    manifest.artifacts.package,
    'manifest.artifacts.package',
  );
  const sbomFile = resolveDescriptor(
    bundleRoot,
    manifest.artifacts.sbom,
    'manifest.artifacts.sbom',
  );
  if (manifest.artifacts.package.sha256 !== expectedPackageSha256) {
    fail('package digest does not match the trusted source-run digest.');
  }
  const packageEntryCount = validateZipEntries(packageFile);
  const attestation = attestationVerifier({
    expectedCommit,
    expectedRepository,
    expectedWorkflow,
    attestedFile: manifestFile,
  });
  if (
    !attestation ||
    !Number.isSafeInteger(attestation.count) ||
    attestation.count < 1 ||
    attestation.predicateType !== provenancePredicateType
  ) {
    fail('GitHub artifact attestation verifier returned an invalid result.');
  }

  const sbom = readJson(sbomFile, 'CycloneDX SBOM');
  if (sbom.bomFormat !== 'CycloneDX' || typeof sbom.specVersion !== 'string') {
    fail('SBOM must be CycloneDX JSON.');
  }

  const marker = path.resolve(requireValue(values, 'verification-marker'));
  if (!marker.startsWith(`${bundleRoot}${path.sep}`)) {
    fail('verification marker must stay inside the deployment bundle.');
  }
  const markerParent = fs.realpathSync(path.dirname(marker));
  if (markerParent !== bundleRoot && !markerParent.startsWith(`${bundleRoot}${path.sep}`)) {
    fail('verification marker parent resolves outside the deployment bundle.');
  }
  fs.writeFileSync(
    marker,
    `${JSON.stringify({
      schema: 'certigo.backend-artifact-verified/v1',
      commitSha: expectedCommit,
      manifestSha256: sha256(manifestFile),
      packageSha256: expectedPackageSha256,
      packageEntryCount,
      sbomSha256: manifest.artifacts.sbom.sha256,
      sourceRunId: expectedRunId,
      githubAttestationVerified: true,
      githubAttestationCount: attestation.count,
      githubProvenancePredicateType: attestation.predicateType,
      signerWorkflow: expectedWorkflow,
      sourceRef: 'refs/heads/main',
      sourceDigest: expectedCommit,
    })}\n`,
    { encoding: 'utf8', flag: 'wx', mode: 0o600 },
  );
}

const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  try {
    verifyDeploymentBundle(parseArguments(process.argv.slice(2)));
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  }
}
