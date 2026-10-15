import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import fs from 'node:fs';
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
import { loadDeploymentState } from './backend-deployment-state.mjs';
import YAML from 'yaml';

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

function stateFixture(t) {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-state-reader-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const file = path.join(root, 'state.json');
  const state = {
    schema: 'certigo.backend.deployment-state/v1',
    environment: 'staging',
    current: {
      commitSha,
      packageSha256: 'a'.repeat(64),
      blobName: `deployments/${commitSha}.zip`,
      sourceRunId: 1234,
      operation: 'promotion',
      deployedAt: '2026-08-15T10:00:00Z',
    },
    previous: null,
  };
  writeFileSync(file, JSON.stringify(state));
  return { root, file, state };
}

test('state reader preserves absent, empty, valid and legacy symlink behavior', (t) => {
  const { root, file, state } = stateFixture(t);
  assert.equal(loadDeploymentState('', 'staging'), null);
  assert.equal(loadDeploymentState(path.join(root, 'missing'), 'staging'), null);
  assert.deepEqual(loadDeploymentState(file, 'staging'), state);
  const link = path.join(root, 'linked.json');
  fs.symlinkSync(file, link);
  assert.deepEqual(loadDeploymentState(link, 'staging'), state);
  writeFileSync(file, '');
  assert.equal(loadDeploymentState(file, 'staging'), null);
});

test('state reader uses the opened object despite a pathname replacement and closes it', (t) => {
  const { file, state } = stateFixture(t);
  const open = fs.openSync;
  let descriptor;
  t.mock.method(fs, 'openSync', (target, ...args) => {
    descriptor = open(target, ...args);
    fs.renameSync(file, `${file}.opened`);
    writeFileSync(file, '{"replacement":true}');
    return descriptor;
  });
  assert.deepEqual(loadDeploymentState(file, 'staging'), state);
  assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
});

test('state reader propagates nonmissing open and read errors and closes on read failure', (t) => {
  const { file } = stateFixture(t);
  const openError = Object.assign(new Error('denied'), { code: 'EACCES' });
  const openMock = t.mock.method(fs, 'openSync', () => { throw openError; });
  assert.throws(() => loadDeploymentState(file, 'staging'), openError);
  openMock.mock.restore();
  const open = fs.openSync;
  let descriptor;
  t.mock.method(fs, 'openSync', (...args) => {
    descriptor = open(...args);
    return descriptor;
  });
  const readError = Object.assign(new Error('read failed'), { code: 'ENOENT' });
  t.mock.method(fs, 'readFileSync', () => { throw readError; });
  assert.throws(() => loadDeploymentState(file, 'staging'), readError);
  assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
});

test('state reader retains JSON, schema, environment and release validation', (t) => {
  const { file, state } = stateFixture(t);
  for (const contents of [
    '{',
    JSON.stringify({ ...state, schema: 'unexpected' }),
    JSON.stringify({ ...state, environment: 'prod' }),
    JSON.stringify({ ...state, current: { ...state.current, commitSha: 'invalid' } }),
    JSON.stringify({ ...state, previous: {} }),
  ]) {
    writeFileSync(file, contents);
    assert.throws(() => loadDeploymentState(file, 'staging'));
  }
});

test('state reader preserves size-zero FIFO null without blocking, consuming bytes or leaking descriptors', (t) => {
  const { root } = stateFixture(t);
  const fifo = path.join(root, 'state.fifo');
  execFileSync('mkfifo', [fifo]);
  const script = `
    import assert from 'node:assert/strict';
    import fs from 'node:fs';
    import { loadDeploymentState } from ${JSON.stringify(new URL('./backend-deployment-state.mjs', import.meta.url).href)};
    const fifo = ${JSON.stringify(fifo)};
    const open = fs.openSync;
    let descriptor;
    fs.openSync = (...args) => {
      descriptor = open(...args);
      return descriptor;
    };
    assert.equal(loadDeploymentState(fifo, 'staging'), null);
    assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
    const writer = open(fifo, fs.constants.O_RDWR | fs.constants.O_NONBLOCK);
    try {
      fs.writeSync(writer, 'unconsumed');
      assert.equal(loadDeploymentState(fifo, 'staging'), null);
      assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
      const buffer = Buffer.alloc(10);
      assert.equal(fs.readSync(writer, buffer), 10);
      assert.equal(buffer.toString(), 'unconsumed');
    } finally {
      fs.closeSync(writer);
    }
    assert.equal(loadDeploymentState(fifo, 'staging'), null);
    assert.throws(() => fs.fstatSync(descriptor), { code: 'EBADF' });
  `;
  const result = spawnSync(process.execPath, ['--input-type=module', '--eval', script], {
    encoding: 'utf8',
    timeout: 10000,
    killSignal: 'SIGKILL',
  });
  assert.equal(result.error, undefined);
  assert.equal(result.status, 0, result.stderr);
});

test('state reader closes on fstat failure and does not read size-zero opened objects', (t) => {
  const { file } = stateFixture(t);
  const open = fs.openSync;
  const inspect = fs.fstatSync;
  let descriptor;
  t.mock.method(fs, 'openSync', (...args) => {
    descriptor = open(...args);
    return descriptor;
  });
  const failure = Object.assign(new Error('stat failed'), { code: 'EIO' });
  const inspectMock = t.mock.method(fs, 'fstatSync', () => { throw failure; });
  assert.throws(() => loadDeploymentState(file, 'staging'), failure);
  assert.throws(() => inspect(descriptor), { code: 'EBADF' });
  inspectMock.mock.restore();
  t.mock.method(fs, 'fstatSync', () => ({ size: 0 }));
  t.mock.method(fs, 'readFileSync', () => { throw new Error('unexpected read of size-zero object'); });
  assert.equal(loadDeploymentState(file, 'staging'), null);
  assert.throws(() => inspect(descriptor), { code: 'EBADF' });
});

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

test('iOS keychain arguments preserve multiple paths, spaces, order and an empty list', () => {
  const workflow = YAML.parse(readFileSync(
    path.join(repositoryRoot, '.github', 'workflows', 'release-ios.yml'), 'utf8',
  ));
  const signing = Object.values(workflow.jobs)
    .flatMap((job) => job.steps ?? []).find((step) => step.id === 'signing').run;
  const start = signing.indexOf('EXISTING_KEYCHAINS=("$KEYCHAIN")');
  const end = signing.indexOf('\n', signing.indexOf(
    'security list-keychains -d user -s "${EXISTING_KEYCHAINS[@]}"', start,
  ));
  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  const script = [
    'set -euo pipefail',
    'security() {',
    '  if [ "$#" -eq 3 ]; then',
    '    printf "%s" "$MOCK_KEYCHAINS"',
    '  else',
    '    printf "<%s>\\n" "$@"',
    '  fi',
    '}',
    signing.slice(start, end),
  ].join('\n');
  for (const existing of [
    [],
    ['/Users/test/Library/Keychains/login.keychain-db'],
    ['/Users/test/Library/Keychains/login.keychain-db', '/Library/Keychains/System.keychain'],
    ['/Users/test user/login keychain-db', '/Library/Keychains/System.keychain'],
    ['/Users/test/[literal]*.keychain', '/Users/test/back\\slash.keychain'],
  ]) {
    for (const trailingNewline of ['', '\n']) {
      const result = spawnSync('bash', ['-c', script], {
        encoding: 'utf8',
        env: {
          ...process.env,
          KEYCHAIN: '/tmp/signing keychain-db',
          MOCK_KEYCHAINS: existing.map((file) => `    "${file}"`).join('\n') + trailingNewline,
        },
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(
        result.stdout,
        ['list-keychains', '-d', 'user', '-s', '/tmp/signing keychain-db', ...existing]
          .map((argument) => `<${argument}>\n`).join(''),
      );
    }
  }
});

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
