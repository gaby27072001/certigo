import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const manifestScript = path.join(
  repositoryRoot,
  '.github',
  'scripts',
  'backend-release-manifest.mjs',
);
const resolverScript = path.join(
  repositoryRoot,
  '.github',
  'scripts',
  'resolve-backend-release.mjs',
);
const deploymentStateScript = path.join(
  repositoryRoot,
  '.github',
  'scripts',
  'update-backend-deployment-state.mjs',
);
const deploymentStateVerificationScript = path.join(
  repositoryRoot,
  '.github',
  'scripts',
  'verify-backend-deployment-state.mjs',
);
const releaseTransferScript = path.join(
  repositoryRoot,
  '.github',
  'scripts',
  'transfer-backend-release.sh',
);
const commitSha = '0123456789abcdef0123456789abcdef01234567';

function createRelease() {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-backend-release-'));
  const release = path.join(root, 'release');
  const sbom = path.join(release, 'sbom');
  mkdirSync(sbom, { recursive: true });
  writeFileSync(path.join(release, 'publish.zip'), 'deterministic package', 'utf8');
  writeFileSync(path.join(sbom, 'bom.json'), '{"bomFormat":"CycloneDX"}\n', 'utf8');
  const output = path.join(release, 'release-manifest.json');
  const result = spawnSync(
    process.execPath,
    [
      manifestScript,
      'create',
      '--package',
      path.join(release, 'publish.zip'),
      '--sbom',
      path.join(sbom, 'bom.json'),
      '--output',
      output,
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        GITHUB_OUTPUT: '',
        GITHUB_SHA: commitSha,
        GITHUB_REPOSITORY: 'gchambaud_microsoft/Certigo',
        GITHUB_WORKFLOW_REF:
          'gchambaud_microsoft/Certigo/.github/workflows/cd-backend.yml@refs/heads/main',
        GITHUB_RUN_ID: '1234',
        GITHUB_RUN_ATTEMPT: '1',
        GITHUB_REF: 'refs/heads/main',
        GITHUB_EVENT_NAME: 'push',
        SOURCE_DATE_EPOCH: '1700000000',
      },
    },
  );
  assert.equal(result.status, 0, result.stderr);
  return { release, output };
}

test('release manifest records and verifies package, SBOM and provenance', () => {
  const { output } = createRelease();
  const manifest = JSON.parse(readFileSync(output, 'utf8'));
  assert.equal(manifest.schema, 'certigo.backend.release/v1');
  assert.equal(manifest.commitSha, commitSha);
  assert.equal(manifest.package.path, 'publish.zip');
  assert.equal(manifest.sbom.path, 'sbom/bom.json');
  assert.equal(manifest.provenance.runId, 1234);

  const result = spawnSync(
    process.execPath,
    [
      manifestScript,
      'verify',
      '--manifest',
      output,
      '--expected-commit',
      commitSha,
      '--expected-run-id',
      '1234',
      '--expected-package-sha256',
      manifest.package.sha256,
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        GITHUB_REPOSITORY: 'gchambaud_microsoft/Certigo',
      },
    },
  );
  assert.equal(result.status, 0, result.stderr);
});

test('release verification rejects changed package bytes', () => {
  const { release, output } = createRelease();
  const manifest = JSON.parse(readFileSync(output, 'utf8'));
  writeFileSync(path.join(release, 'publish.zip'), 'tampered package', 'utf8');
  const result = spawnSync(
    process.execPath,
    [
      manifestScript,
      'verify',
      '--manifest',
      output,
      '--expected-commit',
      commitSha,
      '--expected-run-id',
      '1234',
      '--expected-package-sha256',
      manifest.package.sha256,
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        GITHUB_REPOSITORY: 'gchambaud_microsoft/Certigo',
      },
    },
  );
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /package does not match/i);
});

test('release verification rejects a different source run', () => {
  const { output } = createRelease();
  const manifest = JSON.parse(readFileSync(output, 'utf8'));
  const result = spawnSync(
    process.execPath,
    [
      manifestScript,
      'verify',
      '--manifest',
      output,
      '--expected-commit',
      commitSha,
      '--expected-run-id',
      '9999',
      '--expected-package-sha256',
      manifest.package.sha256,
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        GITHUB_REPOSITORY: 'gchambaud_microsoft/Certigo',
      },
    },
  );
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /does not match expected run/i);
});

test('release verification rejects a package digest absent from the source run', () => {
  const { output } = createRelease();
  const result = spawnSync(
    process.execPath,
    [
      manifestScript,
      'verify',
      '--manifest',
      output,
      '--expected-commit',
      commitSha,
      '--expected-run-id',
      '1234',
      '--expected-package-sha256',
      'c'.repeat(64),
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        GITHUB_REPOSITORY: 'gchambaud_microsoft/Certigo',
      },
    },
  );
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /trusted source-run digest/i);
});

test('release storage transfer is immutable, private and run-scoped', () => {
  const script = readFileSync(releaseTransferScript, 'utf8');
  for (const marker of [
    'RELEASE_PREFIX="releases/${SOURCE_RUN_ID}"',
    '--auth-mode login',
    '--overwrite false',
    '--metadata "sha256=${digest}"',
    'Reused canonical backend release',
    "'publish.zip'",
    "'release-manifest.json'",
    "'sbom/bom.json'",
  ]) {
    assert.match(script, new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
  assert.doesNotMatch(script, /generate-sas|account-key|connection-string/);
});

test('release resolver accepts only a successful main push from cd-backend', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-source-run-'));
  const metadata = path.join(root, 'run.json');
  writeFileSync(
    metadata,
    JSON.stringify({
      repository: { full_name: 'gchambaud_microsoft/Certigo' },
      path: '.github/workflows/cd-backend.yml',
      event: 'push',
      head_branch: 'main',
      conclusion: 'success',
      head_sha: commitSha,
    }),
    'utf8',
  );
  const result = spawnSync(process.execPath, [resolverScript], {
    encoding: 'utf8',
    env: {
      ...process.env,
      GITHUB_OUTPUT: '',
      SOURCE_RUN_ID: '1234',
      SOURCE_RUN_METADATA_FILE: metadata,
      GITHUB_REPOSITORY: 'gchambaud_microsoft/Certigo',
    },
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, new RegExp(`commit-sha=${commitSha}`));
});

test('release resolver rejects non-push workflow provenance', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-source-run-'));
  const metadata = path.join(root, 'run.json');
  writeFileSync(
    metadata,
    JSON.stringify({
      repository: { full_name: 'gchambaud_microsoft/Certigo' },
      path: '.github/workflows/cd-backend.yml',
      event: 'repository_dispatch',
      head_branch: 'main',
      conclusion: 'success',
      head_sha: commitSha,
    }),
    'utf8',
  );
  const result = spawnSync(process.execPath, [resolverScript], {
    encoding: 'utf8',
    env: {
      ...process.env,
      GITHUB_OUTPUT: '',
      SOURCE_RUN_ID: '1234',
      SOURCE_RUN_METADATA_FILE: metadata,
      GITHUB_REPOSITORY: 'gchambaud_microsoft/Certigo',
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /main push provenance/);
});

test('deployment state preserves the previously healthy release', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-deployment-state-'));
  const previousFile = path.join(root, 'previous.json');
  const outputFile = path.join(root, 'next.json');
  writeFileSync(
    previousFile,
    JSON.stringify({
      schema: 'certigo.backend.deployment-state/v1',
      environment: 'staging',
      current: {
        commitSha: '1111111111111111111111111111111111111111',
        packageSha256: 'a'.repeat(64),
        blobName: 'deployments/1111111111111111111111111111111111111111.zip',
        sourceRunId: 100,
        operation: 'promotion',
        deployedAt: '2026-08-15T10:00:00Z',
      },
      previous: null,
    }),
    'utf8',
  );
  const result = spawnSync(
    process.execPath,
    [
      deploymentStateScript,
      '--previous',
      previousFile,
      '--output',
      outputFile,
    ],
    {
      encoding: 'utf8',
      env: {
        ...process.env,
        TARGET_ENV: 'staging',
        COMMIT_SHA: commitSha,
        PACKAGE_SHA256: 'b'.repeat(64),
        BLOB_NAME: `deployments/${commitSha}.zip`,
        SOURCE_RUN_ID: '1234',
        DEPLOYMENT_OPERATION: 'rollback',
        DEPLOYED_AT: '2026-08-16T14:00:00Z',
      },
    },
  );
  assert.equal(result.status, 0, result.stderr);
  const state = JSON.parse(readFileSync(outputFile, 'utf8'));
  assert.equal(state.current.commitSha, commitSha);
  assert.equal(
    state.previous.commitSha,
    '1111111111111111111111111111111111111111',
  );
});

test('deployment lineage accepts only the recorded current or previous release', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-deployment-lineage-'));
  const stateFile = path.join(root, 'state.json');
  const previousCommit = '1111111111111111111111111111111111111111';
  writeFileSync(
    stateFile,
    JSON.stringify({
      schema: 'certigo.backend.deployment-state/v1',
      environment: 'prod',
      current: {
        commitSha,
        packageSha256: 'b'.repeat(64),
        blobName: `deployments/${commitSha}.zip`,
        sourceRunId: 1234,
        operation: 'promotion',
        deployedAt: '2026-08-16T14:00:00Z',
      },
      previous: {
        commitSha: previousCommit,
        packageSha256: 'a'.repeat(64),
        blobName: `deployments/${previousCommit}.zip`,
        sourceRunId: 100,
        operation: 'release',
        deployedAt: '2026-08-15T10:00:00Z',
      },
    }),
    'utf8',
  );

  const verify = (slot, expectedCommit, expectedDigest, expectedRunId) =>
    spawnSync(
      process.execPath,
      [
        deploymentStateVerificationScript,
        '--state',
        stateFile,
        '--environment',
        'prod',
        '--slot',
        slot,
      ],
      {
        encoding: 'utf8',
        env: {
          ...process.env,
          EXPECTED_COMMIT_SHA: expectedCommit,
          EXPECTED_PACKAGE_SHA256: expectedDigest,
          EXPECTED_SOURCE_RUN_ID: expectedRunId,
        },
      },
    );

  const current = verify('current', commitSha, 'b'.repeat(64), '1234');
  assert.equal(current.status, 0, current.stderr);
  const previous = verify('previous', previousCommit, 'a'.repeat(64), '100');
  assert.equal(previous.status, 0, previous.stderr);
  const mismatch = verify('previous', commitSha, 'b'.repeat(64), '1234');
  assert.notEqual(mismatch.status, 0);
  assert.match(mismatch.stderr, /does not match the previous prod release/);
});
