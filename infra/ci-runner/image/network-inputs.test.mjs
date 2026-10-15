import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import {
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import {
  assertNetworkInputsReady,
  installationBlocker,
  verifyNetworkLockDigests,
} from './validate-network-inputs.mjs';
import { reconstructBasePackages, verifyBaseImageEvidence } from './verify-base-image-evidence.mjs';

const root = fileURLToPath(new URL('./', import.meta.url));
const original = JSON.parse(readFileSync(join(root, 'image-build-contract.json'), 'utf8'));
const hash = (bytes) => createHash('sha256').update(bytes).digest('hex');
const lockPaths = [
  'infra/ci-runner/image/apt-packages.lock.json',
  'infra/ci-runner/image/flutter-engine-artifacts.lock.json',
];
const lockNames = lockPaths.map((path) => path.split('/').at(-1));

function commitLocks(repositoryRoot) {
  execFileSync('git', ['-C', repositoryRoot, 'add', '--', ...lockPaths]);
  execFileSync('git', [
    '-C', repositoryRoot, '-c', 'user.name=Certigo test',
    '-c', 'user.email=certigo@example.invalid',
    'commit', '--quiet', '-m', 'Test network lock inputs',
  ]);
  return execFileSync('git', ['-C', repositoryRoot, 'rev-parse', 'HEAD'], {
    encoding: 'utf8',
  }).trim();
}

test('dated base reconstruction replays exactly and covers every package in the snapshot', () => {
  assert.equal(verifyBaseImageEvidence().status, 'reconstructed-not-independent');
});

test('base reconstruction refuses gaps, duplicates, unsupported removals and incomplete states', () => {
  const inventory = 'base\t2\tamd64\tinstalled\nadded\t1\tall\tinstalled\n';
  const log = '2026-09-14 09:26:10 upgrade base:amd64 1 2\n' +
    '2026-09-14 09:26:11 install added:all <none> 1\n';
  assert.deepEqual([...reconstructBasePackages(inventory, log).base], [['base:amd64', '1']]);
  assert.throws(() => reconstructBasePackages(inventory.replace('installed', 'unpacked'), log),
    /Unsupported package state/);
  assert.throws(() => reconstructBasePackages(inventory + 'base\t2\tamd64\tinstalled\n', log),
    /Duplicate package/);
  assert.throws(() => reconstructBasePackages(inventory, log.replace(' 1 2', ' 1 3')),
    /Discontinuous/);
  assert.throws(() => reconstructBasePackages(inventory, log.replace('upgrade', 'remove')),
    /Unsupported dpkg event/);
  assert.throws(() => reconstructBasePackages(inventory, ''), /timestamp/);
  assert.throws(() => reconstructBasePackages(inventory, log.split('\n').slice(0, 2).reverse().join('\n')),
    /Unordered/);
});

function fixture(t) {
  const repositoryRoot = mkdtempSync(join(tmpdir(), 'certigo-network-inputs-'));
  const directory = join(repositoryRoot, 'infra', 'ci-runner', 'image');
  mkdirSync(directory, { recursive: true });
  t.after(() => rmSync(repositoryRoot, { recursive: true, force: true }));
  execFileSync('git', ['-C', repositoryRoot, 'init', '--quiet']);
  execFileSync('git', ['-C', repositoryRoot, 'config', 'core.autocrlf', 'false']);
  const contract = structuredClone(original);
  contract.policy.reproducibleInputsReady = true;
  Object.assign(contract.reproducibility, {
    status: 'locked',
    aptSnapshot: 'https://snapshot.ubuntu.com/ubuntu/20260807T000000Z/',
  });
  // Deliberately NOT complete locks. Correct hashes of arbitrary JSON must
  // never be confused with validated package closure or execution evidence.
  const apt = '{"packages":[{"name":"synthetic-only"}]}\n';
  const flutter = '{"artifacts":[{"url":"https://example.invalid/original"}]}\n';
  writeFileSync(join(directory, 'apt-packages.lock.json'), apt);
  writeFileSync(join(directory, 'flutter-engine-artifacts.lock.json'), flutter);
  contract.contractCommit = commitLocks(repositoryRoot);
  contract.reproducibility.aptPackageLockSha256 = hash(apt);
  contract.reproducibility.flutterEngineArtifactLockSha256 = hash(flutter);
  return { directory, repositoryRoot, contract };
}

test('checked-in contract lock digests match blobs at its declared Git commit', () => {
  assert.doesNotThrow(() => verifyNetworkLockDigests(original));
});

test('real bytes, not hash-shaped strings, are required for both network locks', (t) => {
  const { directory, contract } = fixture(t);
  assert.doesNotThrow(() => verifyNetworkLockDigests(contract, directory));
  assert.throws(() => assertNetworkInputsReady(contract, directory), {
    message: installationBlocker,
  });
  for (const field of ['aptPackageLockSha256', 'flutterEngineArtifactLockSha256']) {
    for (const digest of [null, '', 'x'.repeat(64), 'a'.repeat(64)]) {
      const tampered = structuredClone(contract);
      tampered.reproducibility[field] = digest;
      assert.throws(() => verifyNetworkLockDigests(tampered, directory), /invalid|mismatch/);
    }
  }
});

test('the declared contract SHA must identify a Git commit', (t) => {
  const { directory, repositoryRoot, contract } = fixture(t);
  contract.contractCommit = execFileSync(
    'git',
    ['-C', repositoryRoot, 'rev-parse', `${contract.contractCommit}^{tree}`],
    { encoding: 'utf8' },
  ).trim();
  assert.throws(
    () => verifyNetworkLockDigests(contract, directory),
    /contractCommit must identify a Git commit/,
  );
});

test('worktree lock omission or alteration cannot replace committed lock bytes', (t) => {
  const { directory, contract } = fixture(t);
  for (const name of lockNames) {
    const path = join(directory, name);
    const content = readFileSync(path);
    writeFileSync(path, Buffer.concat([content, Buffer.from(' ')]));
    assert.doesNotThrow(() => verifyNetworkLockDigests(contract, directory));
    rmSync(path);
    assert.doesNotThrow(() => verifyNetworkLockDigests(contract, directory));
  }
});

test('a changed committed lock cannot pass with the original declared digest', (t) => {
  const { directory, repositoryRoot, contract } = fixture(t);
  const lock = join(directory, 'apt-packages.lock.json');
  writeFileSync(lock, `${readFileSync(lock, 'utf8')} `);
  contract.contractCommit = commitLocks(repositoryRoot);
  assert.throws(() => verifyNetworkLockDigests(contract, directory), /digest mismatch/);
});

test('empty, malformed or non-object JSON is not a network lock even with a matching digest', (t) => {
  const { directory, repositoryRoot, contract } = fixture(t);
  for (const contents of ['', '{}', '[]', 'null', 'true', '"locked"']) {
    writeFileSync(join(directory, 'apt-packages.lock.json'), contents);
    contract.contractCommit = commitLocks(repositoryRoot);
    contract.reproducibility.aptPackageLockSha256 = hash(contents);
    assert.throws(() => verifyNetworkLockDigests(contract, directory), /JSON|nonempty/);
  }
});

test('rehashing redirected or unexpected artifact proposals cannot enable the installer', (t) => {
  const { directory, repositoryRoot, contract } = fixture(t);
  for (const artifacts of [
    [{ url: 'https://example.invalid/redirected', sha256: 'a'.repeat(64) }],
    [{ url: 'https://example.invalid/original' }, { url: 'https://example.invalid/unexpected' }],
    [],
  ]) {
    const bytes = JSON.stringify({ artifacts });
    writeFileSync(join(directory, 'flutter-engine-artifacts.lock.json'), bytes);
    contract.contractCommit = commitLocks(repositoryRoot);
    contract.reproducibility.flutterEngineArtifactLockSha256 = hash(bytes);
    assert.throws(() => assertNetworkInputsReady(contract, directory), {
      message: installationBlocker,
    });
  }
});

test('symlink locks and mutable snapshot URLs are rejected', (t) => {
  const { directory, repositoryRoot, contract } = fixture(t);
  for (const snapshot of [
    'https://archive.ubuntu.com/ubuntu/',
    'https://snapshot.ubuntu.com/ubuntu/latest/',
    'https://snapshot.ubuntu.com/ubuntu/20260807T000000Z/?redirect=elsewhere',
  ]) {
    const bad = structuredClone(contract);
    bad.reproducibility.aptSnapshot = snapshot;
    assert.throws(() => assertNetworkInputsReady(bad, directory), /immutable Ubuntu snapshot/);
  }
  const linkBlob = execFileSync(
    'git',
    ['-C', repositoryRoot, 'hash-object', '-w', '--stdin'],
    { input: Buffer.from('elsewhere.json'), encoding: 'utf8' },
  ).trim();
  execFileSync('git', [
    '-C', repositoryRoot, 'update-index', '--cacheinfo',
    `120000,${linkBlob},infra/ci-runner/image/apt-packages.lock.json`,
  ]);
  execFileSync('git', [
    '-C', repositoryRoot, '-c', 'user.name=Certigo test',
    '-c', 'user.email=certigo@example.invalid',
    'commit', '--quiet', '-m', 'Make network lock a symlink',
  ]);
  contract.contractCommit = execFileSync('git', ['-C', repositoryRoot, 'rev-parse', 'HEAD'], {
    encoding: 'utf8',
  }).trim();
  assert.throws(() => verifyNetworkLockDigests(contract, directory), /regular committed file/);
});

test('a symlinked Git-tree ancestor cannot supply a network lock', (t) => {
  const { directory, repositoryRoot, contract } = fixture(t);
  const linkBlob = execFileSync(
    'git',
    ['-C', repositoryRoot, 'hash-object', '-w', '--stdin'],
    { input: Buffer.from('outside-image-directory'), encoding: 'utf8' },
  ).trim();
  execFileSync('git', ['-C', repositoryRoot, 'rm', '--cached', '--quiet', '-r', '--',
    'infra/ci-runner/image']);
  execFileSync('git', ['-C', repositoryRoot, 'update-index', '--add', '--cacheinfo',
    `120000,${linkBlob},infra/ci-runner/image`]);
  execFileSync('git', [
    '-C', repositoryRoot, '-c', 'user.name=Certigo test',
    '-c', 'user.email=certigo@example.invalid',
    'commit', '--quiet', '-m', 'Make image directory a symlink',
  ]);
  contract.contractCommit = execFileSync('git', ['-C', repositoryRoot, 'rev-parse', 'HEAD'], {
    encoding: 'utf8',
  }).trim();
  assert.throws(
    () => verifyNetworkLockDigests(contract, directory),
    /missing from contract commit/,
  );
});

test('the CLI refuses forged readiness with valid committed lock digests', (t) => {
  const { directory, contract } = fixture(t);
  copyFileSync(join(root, 'validate-network-inputs.mjs'), join(directory, 'validate-network-inputs.mjs'));
  writeFileSync(join(directory, 'image-build-contract.json'), JSON.stringify(contract));
  const result = spawnSync(process.execPath, [join(directory, 'validate-network-inputs.mjs')], {
    encoding: 'utf8',
    timeout: 10000,
  });
  assert.equal(result.error, undefined);
  assert.equal(result.status, 1);
  assert.equal(result.stdout, '');
  assert.match(result.stderr, /offline network input consumption is not implemented/);
});

test('network lock verification never opens mutable worktree lock paths', (t) => {
  const { directory, contract } = fixture(t);
  const lock = join(directory, 'apt-packages.lock.json');
  rmSync(lock);
  const open = fs.openSync;
  t.mock.method(fs, 'openSync', (file, ...args) => {
    if (file === lock) {
      throw new Error('mutable lock path must not be opened');
    }
    return open(file, ...args);
  });
  assert.doesNotThrow(() => verifyNetworkLockDigests(contract, directory));
});

test('a FIFO worktree replacement is ignored and never blocks committed lock verification', {
  skip: process.platform === 'win32',
}, (t) => {
  const { directory, contract } = fixture(t);
  const lock = join(directory, 'apt-packages.lock.json');
  rmSync(lock);
  execFileSync('mkfifo', [lock]);
  assert.doesNotThrow(() => verifyNetworkLockDigests(contract, directory));
});

test('direct prewarm refuses before invoking tools, creating paths or consuming a redirect', (t) => {
  const { directory } = fixture(t);
  const marker = join(directory, 'network-called');
  for (const command of ['curl', 'apt-get', 'python3.12', 'flutter', 'node']) {
    writeFileSync(join(directory, command),
      '#!/bin/sh\nprintf "unexpected download or redirect" > "$NETWORK_MARKER"\nexit 1\n',
      { mode: 0o755 });
  }
  const result = spawnSync('bash', [join(root, 'prewarm-toolchain.sh')], {
    encoding: 'utf8',
    timeout: 10000,
    env: {
      ...process.env,
      PATH: `${directory}:${process.env.PATH}`,
      NETWORK_MARKER: marker,
      CERTIGO_IMAGE_ROOT: join(directory, 'image'),
      CERTIGO_TOOLCHAIN_ROOT: join(directory, 'toolchains'),
      CERTIGO_DOWNLOAD_ROOT: join(directory, 'downloads'),
    },
  });
  assert.equal(result.error, undefined);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /offline network input consumption is not implemented/);
  for (const path of [marker, ...['image', 'toolchains', 'downloads'].map((name) => join(directory, name))]) {
    assert.throws(() => readFileSync(path), { code: 'ENOENT' });
  }
});

test('compiled ARM remains inert even after all JSON readiness and signer flags are forged', (t) => {
  const { directory, contract } = fixture(t);
  const templates = ['image-build', 'canary', 'canary-main'];
  for (const file of [...templates.map((name) => `${name}.bicep`),
    'canary-contract.json', 'attestation-policy.json']) {
    copyFileSync(join(root, file), join(directory, file));
  }
  writeFileSync(join(directory, 'image-build-contract.json'), JSON.stringify(contract));
  const policy = JSON.parse(readFileSync(join(directory, 'attestation-policy.json'), 'utf8'));
  policy.activation.status = 'active';
  policy.signerDigest = 'a'.repeat(40);
  writeFileSync(join(directory, 'attestation-policy.json'), JSON.stringify(policy));
  const expectedCounts = { 'image-build': 3, canary: 5, 'canary-main': 2 };
  for (const name of templates) {
    const arm = JSON.parse(execFileSync(process.env.BICEP_CLI || 'bicep',
      ['build', join(directory, `${name}.bicep`), '--stdout'],
      { encoding: 'utf8', timeout: 60000 }));
    assert.equal(arm.variables.networkInstallerImplemented, false, name);
    assert.match(arm.variables.effectiveDeploymentEnabled,
      /^\[and\(.+, variables\('networkInstallerImplemented'\)\)\]$/);
    const resources = Object.values(arm.resources);
    assert.equal(resources.length, expectedCounts[name], name);
    for (const resource of resources) {
      assert.equal(resource.condition, "[variables('effectiveDeploymentEnabled')]", resource.type);
    }
  }
});
