import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const predicateType = 'https://certigo.dev/attestations/backend-release/v1';
const statementType = 'https://in-toto.io/Statement/v1';
const artifactName = 'backend-release-bundle.tar';
const producerJob = 'build-release';
const attesterJob = 'attest-release';
const canonicalRepository = 'gchambaud_microsoft/Certigo';
const canonicalWorkflowRef =
  `${canonicalRepository}/.github/workflows/cd-backend.yml@refs/heads/main`;
const shaPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^[0-9a-f]{64}$/;
const runIdPattern = /^[1-9][0-9]{0,19}$/;

const predicateKeys = [
  'artifactDigest',
  'artifactId',
  'attesterJob',
  'buildSourceRunId',
  'bundleSha256',
  'packageSha256',
  'producerJob',
  'repository',
  'runAttempt',
  'runId',
  'sbomSha256',
  'sourceCommit',
  'workflowRef',
  'workflowSha',
];

function fail(message) {
  throw new Error(message);
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

function requireEnv(name) {
  const value = process.env[name] ?? '';
  if (!value) {
    fail(`${name} is required.`);
  }
  return value;
}

function expectedPredicate() {
  const predicate = {
    artifactId: requireEnv('ARTIFACT_ID'),
    artifactDigest: requireEnv('ARTIFACT_DIGEST'),
    bundleSha256: requireEnv('BUNDLE_SHA256'),
    repository: requireEnv('GITHUB_REPOSITORY'),
    workflowRef: requireEnv('GITHUB_WORKFLOW_REF'),
    workflowSha: requireEnv('WORKFLOW_SHA'),
    runId: requireEnv('WORKFLOW_RUN_ID'),
    runAttempt: requireEnv('WORKFLOW_RUN_ATTEMPT'),
    producerJob,
    attesterJob,
    sourceCommit: requireEnv('SOURCE_COMMIT'),
    buildSourceRunId: requireEnv('BUILD_SOURCE_RUN_ID'),
    packageSha256: requireEnv('PACKAGE_SHA256'),
    sbomSha256: requireEnv('SBOM_SHA256'),
  };

  if (!runIdPattern.test(predicate.artifactId)) {
    fail('ARTIFACT_ID must be a positive integer.');
  }
  for (const name of ['runId', 'runAttempt', 'buildSourceRunId']) {
    if (!runIdPattern.test(predicate[name])) {
      fail(`${name} must be a positive integer.`);
    }
  }
  if (
    predicate.repository !== canonicalRepository
    || predicate.workflowRef !== canonicalWorkflowRef
  ) {
    fail('Attestation repository and workflow must be canonical.');
  }
  for (const name of ['workflowSha', 'sourceCommit']) {
    if (!shaPattern.test(predicate[name])) {
      fail(`${name} must be a lowercase 40-character Git SHA.`);
    }
  }
  for (const name of [
    'artifactDigest',
    'bundleSha256',
    'packageSha256',
    'sbomSha256',
  ]) {
    if (!digestPattern.test(predicate[name])) {
      fail(`${name} must be a lowercase SHA-256 digest.`);
    }
  }
  if (
    predicate.artifactDigest !== predicate.bundleSha256
  ) {
    fail('Artifact service and release bundle digests must match.');
  }
  return predicate;
}

function writePredicate(outputFile) {
  if (process.env.GITHUB_JOB !== attesterJob) {
    fail(`Attestation predicate may only be created by ${attesterJob}.`);
  }
  const predicate = expectedPredicate();
  fs.writeFileSync(
    outputFile,
    `${JSON.stringify(predicate, null, 2)}\n`,
    { encoding: 'utf8', flag: 'wx', mode: 0o600 },
  );
}

function verifyAttestation(attestationFile) {
  const expected = expectedPredicate();
  let results;
  try {
    results = JSON.parse(fs.readFileSync(attestationFile, 'utf8'));
  } catch (error) {
    fail(`Cannot read verified attestation JSON: ${error.message}`);
  }
  if (!Array.isArray(results) || results.length !== 1) {
    fail('Exactly one signed backend release attestation must verify.');
  }

  const statement = results[0]?.verificationResult?.statement;
  exactKeys(statement, ['_type', 'predicate', 'predicateType', 'subject'], 'statement');
  if (statement._type !== statementType || statement.predicateType !== predicateType) {
    fail('Attestation statement type or predicate type is not canonical.');
  }
  if (!Array.isArray(statement.subject) || statement.subject.length !== 1) {
    fail('Attestation must identify exactly one subject.');
  }
  exactKeys(statement.subject[0], ['digest', 'name'], 'statement.subject[0]');
  exactKeys(statement.subject[0].digest, ['sha256'], 'statement.subject[0].digest');
  if (
    statement.subject[0].name !== artifactName
    || statement.subject[0].digest.sha256 !== expected.bundleSha256
  ) {
    fail('Attestation subject does not match the verified release bundle.');
  }

  exactKeys(statement.predicate, predicateKeys, 'statement.predicate');
  for (const name of predicateKeys) {
    if (statement.predicate[name] !== expected[name]) {
      fail(`Attestation predicate ${name} does not match the verified handoff.`);
    }
  }
}

function parseArguments(argv) {
  const [command, file, ...extra] = argv;
  if (
    !['create', 'verify'].includes(command)
    || !file
    || extra.length !== 0
  ) {
    fail(
      'Usage: backend-release-attestation.mjs <create|verify> <predicate-or-attestation-file>',
    );
  }
  return { command, file: path.resolve(file) };
}

try {
  const { command, file } = parseArguments(process.argv.slice(2));
  if (command === 'create') {
    writePredicate(file);
  } else {
    verifyAttestation(file);
  }
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
