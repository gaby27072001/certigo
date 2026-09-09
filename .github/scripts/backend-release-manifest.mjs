import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const schema = 'certigo.backend.release/v2';
const shaPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^[0-9a-f]{64}$/;
const runIdPattern = /^[1-9][0-9]{0,19}$/;

function fail(message) {
  throw new Error(message);
}

function parseArguments(argv) {
  const [command, ...tokens] = argv;
  if (!['create', 'verify'].includes(command)) {
    fail('Usage: backend-release-manifest.mjs <create|verify> [--name value ...]');
  }

  const values = {};
  for (let index = 0; index < tokens.length; index += 2) {
    const name = tokens[index];
    const value = tokens[index + 1];
    if (!name?.startsWith('--') || value === undefined) {
      fail(`Invalid argument near ${name ?? '<end>'}.`);
    }
    const key = name.slice(2);
    if (Object.hasOwn(values, key)) {
      fail(`--${key} may only be provided once.`);
    }
    values[key] = value;
  }
  const allowed = command === 'create'
    ? ['output', 'package', 'sbom']
    : [
      'expected-commit',
      'expected-package-sha256',
      'expected-run-attempt',
      'expected-run-id',
      'expected-source-run-id',
      'expected-workflow-sha',
      'manifest',
    ];
  for (const key of Object.keys(values)) {
    if (!allowed.includes(key)) {
      fail(`--${key} is not valid for ${command}.`);
    }
  }
  return { command, values };
}

function requireValue(values, name) {
  const value = values[name];
  if (!value) {
    fail(`--${name} is required.`);
  }
  return value;
}

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function relativeArtifactPath(manifestFile, artifactFile) {
  const relative = path.relative(path.dirname(manifestFile), artifactFile).replaceAll('\\', '/');
  if (!relative || relative.startsWith('../') || path.isAbsolute(relative)) {
    fail(`${artifactFile} must be inside the release directory.`);
  }
  return relative;
}

function fileDescriptor(manifestFile, artifactFile) {
  const stats = fs.statSync(artifactFile);
  if (!stats.isFile()) {
    fail(`${artifactFile} must be a regular file.`);
  }
  return {
    path: relativeArtifactPath(manifestFile, artifactFile),
    sha256: sha256(artifactFile),
    size: stats.size,
  };
}

function exactKeys(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    fail(`${label} fields must be exactly ${wanted.join(', ')}.`);
  }
}

function validateDescriptor(value, label) {
  exactKeys(value, ['path', 'sha256', 'size'], label);
  if (
    typeof value.path !== 'string'
    || value.path.length === 0
    || value.path.startsWith('/')
    || value.path.split('/').includes('..')
  ) {
    fail(`${label}.path must be a safe relative path.`);
  }
  if (typeof value.sha256 !== 'string' || !digestPattern.test(value.sha256)) {
    fail(`${label}.sha256 must be a lowercase SHA-256 digest.`);
  }
  if (!Number.isSafeInteger(value.size) || value.size < 1) {
    fail(`${label}.size must be a positive integer.`);
  }
}

function readManifest(manifestFile) {
  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestFile, 'utf8'));
  } catch (error) {
    fail(`Cannot read release manifest: ${error.message}`);
  }

  exactKeys(manifest, ['schema', 'commitSha', 'package', 'sbom', 'provenance'], 'manifest');
  if (manifest.schema !== schema) {
    fail(`Unsupported release manifest schema ${manifest.schema}.`);
  }
  if (typeof manifest.commitSha !== 'string' || !shaPattern.test(manifest.commitSha)) {
    fail('manifest.commitSha must be a lowercase 40-character Git SHA.');
  }
  validateDescriptor(manifest.package, 'manifest.package');
  exactKeys(manifest.sbom, ['format', 'path', 'sha256', 'size'], 'manifest.sbom');
  if (manifest.sbom.format !== 'CycloneDX JSON') {
    fail('manifest.sbom.format must be CycloneDX JSON.');
  }
  validateDescriptor(
    {
      path: manifest.sbom.path,
      sha256: manifest.sbom.sha256,
      size: manifest.sbom.size,
    },
    'manifest.sbom',
  );
  exactKeys(
    manifest.provenance,
    [
      'event',
      'producerJob',
      'ref',
      'repository',
      'runAttempt',
      'runId',
      'sourceRunId',
      'sourceDateEpoch',
      'workflowRef',
      'workflowSha',
    ],
    'manifest.provenance',
  );
  if (
    typeof manifest.provenance.repository !== 'string'
    || !/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(manifest.provenance.repository)
  ) {
    fail('manifest.provenance.repository is invalid.');
  }
  if (
    typeof manifest.provenance.workflowRef !== 'string'
    || !manifest.provenance.workflowRef.includes('/.github/workflows/cd-backend.yml@')
  ) {
    fail('manifest.provenance.workflowRef must identify cd-backend.yml.');
  }
  if (
    typeof manifest.provenance.workflowSha !== 'string'
    || !shaPattern.test(manifest.provenance.workflowSha)
  ) {
    fail('manifest.provenance.workflowSha must be a lowercase 40-character Git SHA.');
  }
  if (manifest.provenance.producerJob !== 'build-release') {
    fail('manifest.provenance.producerJob must be build-release.');
  }
  for (const name of ['runId', 'runAttempt', 'sourceRunId', 'sourceDateEpoch']) {
    if (!Number.isSafeInteger(manifest.provenance[name]) || manifest.provenance[name] < 1) {
      fail(`manifest.provenance.${name} must be a positive integer.`);
    }
  }
  if (
    manifest.provenance.event !== 'repository_dispatch'
    || manifest.provenance.ref !== 'refs/heads/main'
  ) {
    fail('Release provenance must come from repository_dispatch on refs/heads/main.');
  }
  return manifest;
}

function writeOutputs(values) {
  if (!process.env.GITHUB_OUTPUT) {
    return;
  }
  fs.appendFileSync(
    process.env.GITHUB_OUTPUT,
    Object.entries(values).map(([name, value]) => `${name}=${value}\n`).join(''),
    'utf8',
  );
}

function createManifest(values) {
  const manifestFile = path.resolve(requireValue(values, 'output'));
  const packageFile = path.resolve(requireValue(values, 'package'));
  const sbomFile = path.resolve(requireValue(values, 'sbom'));
  const commitSha = process.env.RELEASE_COMMIT_SHA ?? process.env.GITHUB_SHA ?? '';
  const workflowSha = process.env.GITHUB_SHA ?? '';
  if (!shaPattern.test(commitSha)) {
    fail('RELEASE_COMMIT_SHA must be a lowercase 40-character Git SHA.');
  }
  if (!shaPattern.test(workflowSha)) {
    fail('GITHUB_SHA must be a lowercase 40-character Git SHA.');
  }

  const positiveInteger = (name) => {
    const raw = process.env[name] ?? '';
    if (!runIdPattern.test(raw)) {
      fail(`${name} must be a positive integer.`);
    }
    const parsed = Number(raw);
    if (!Number.isSafeInteger(parsed) || parsed < 1) {
      fail(`${name} must be a positive integer.`);
    }
    return parsed;
  };

  const manifest = {
    schema,
    commitSha,
    package: fileDescriptor(manifestFile, packageFile),
    sbom: {
      format: 'CycloneDX JSON',
      ...fileDescriptor(manifestFile, sbomFile),
    },
    provenance: {
      repository: process.env.GITHUB_REPOSITORY ?? '',
      workflowRef: process.env.GITHUB_WORKFLOW_REF ?? '',
      workflowSha,
      runId: positiveInteger('GITHUB_RUN_ID'),
      runAttempt: positiveInteger('GITHUB_RUN_ATTEMPT'),
      sourceRunId: positiveInteger('SOURCE_RUN_ID'),
      producerJob: process.env.PRODUCER_JOB ?? '',
      ref: process.env.GITHUB_REF ?? '',
      event: process.env.GITHUB_EVENT_NAME ?? '',
      sourceDateEpoch: positiveInteger('SOURCE_DATE_EPOCH'),
    },
  };

  fs.mkdirSync(path.dirname(manifestFile), { recursive: true });
  fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`, {
    encoding: 'utf8',
    flag: 'wx',
    mode: 0o600,
  });
  readManifest(manifestFile);
  writeOutputs({
    'commit-sha': manifest.commitSha,
    'package-sha256': manifest.package.sha256,
  });
}

function verifyManifest(values) {
  const manifestFile = path.resolve(requireValue(values, 'manifest'));
  const expectedCommit = values['expected-commit'] ?? '';
  const expectedWorkflowSha = requireValue(values, 'expected-workflow-sha');
  const expectedRunId = requireValue(values, 'expected-run-id');
  const expectedRunAttempt = requireValue(values, 'expected-run-attempt');
  const expectedSourceRunId = values['expected-source-run-id'] ?? '';
  const expectedPackageSha256 = values['expected-package-sha256'] ?? '';
  if (expectedCommit && !shaPattern.test(expectedCommit)) {
    fail('--expected-commit must be a lowercase 40-character Git SHA.');
  }
  if (!shaPattern.test(expectedWorkflowSha)) {
    fail('--expected-workflow-sha must be a lowercase 40-character Git SHA.');
  }
  if (!runIdPattern.test(expectedRunId)) {
    fail('--expected-run-id must be a positive GitHub Actions run id.');
  }
  if (!runIdPattern.test(expectedRunAttempt)) {
    fail('--expected-run-attempt must be a positive GitHub Actions run attempt.');
  }
  if (expectedSourceRunId && !runIdPattern.test(expectedSourceRunId)) {
    fail('--expected-source-run-id must be a positive GitHub Actions run id.');
  }
  if (expectedPackageSha256 && !digestPattern.test(expectedPackageSha256)) {
    fail('--expected-package-sha256 must be a lowercase SHA-256 digest.');
  }

  const manifest = readManifest(manifestFile);
  if (expectedCommit && manifest.commitSha !== expectedCommit) {
    fail(`Release commit ${manifest.commitSha} does not match expected commit ${expectedCommit}.`);
  }
  if (manifest.provenance.workflowSha !== expectedWorkflowSha) {
    fail(
      `Release workflow ${manifest.provenance.workflowSha} does not match expected workflow ${expectedWorkflowSha}.`,
    );
  }
  if (String(manifest.provenance.runId) !== expectedRunId) {
    fail(
      `Release run ${manifest.provenance.runId} does not match expected run ${expectedRunId}.`,
    );
  }
  if (String(manifest.provenance.runAttempt) !== expectedRunAttempt) {
    fail(
      `Release run attempt ${manifest.provenance.runAttempt} does not match expected attempt ${expectedRunAttempt}.`,
    );
  }
  if (
    expectedSourceRunId
    && String(manifest.provenance.sourceRunId) !== expectedSourceRunId
  ) {
    fail(
      `Release source run ${manifest.provenance.sourceRunId} does not match expected source run ${expectedSourceRunId}.`,
    );
  }
  if (
    expectedPackageSha256
    && manifest.package.sha256 !== expectedPackageSha256
  ) {
    fail('Release package does not match the trusted source-run digest.');
  }
  const expectedRepository = process.env.GITHUB_REPOSITORY ?? '';
  const expectedWorkflowRef =
    `${expectedRepository}/.github/workflows/cd-backend.yml@refs/heads/main`;
  if (
    manifest.provenance.repository !== expectedRepository
    || manifest.provenance.workflowRef !== expectedWorkflowRef
  ) {
    fail('Release provenance does not match the current repository workflow.');
  }

  const verifiedDigests = {};
  for (const [name, label, descriptor] of [
    ['package-sha256', 'package', manifest.package],
    ['sbom-sha256', 'SBOM', manifest.sbom],
  ]) {
    const artifactFile = path.resolve(path.dirname(manifestFile), descriptor.path);
    if (!artifactFile.startsWith(`${path.dirname(manifestFile)}${path.sep}`)) {
      fail(`${label} path escapes the release directory.`);
    }
    const stats = fs.statSync(artifactFile);
    const actualSha256 = sha256(artifactFile);
    if (stats.size !== descriptor.size || actualSha256 !== descriptor.sha256) {
      fail(`${label} does not match the release manifest.`);
    }
    verifiedDigests[name] = actualSha256;
  }

  writeOutputs({
    'commit-sha': manifest.commitSha,
    ...verifiedDigests,
    'source-run-id': manifest.provenance.runId,
    'source-run-attempt': manifest.provenance.runAttempt,
    'build-source-run-id': manifest.provenance.sourceRunId,
    'workflow-sha': manifest.provenance.workflowSha,
  });
}

const { command, values } = parseArguments(process.argv.slice(2));
try {
  if (command === 'create') {
    createManifest(values);
  } else {
    verifyManifest(values);
  }
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
