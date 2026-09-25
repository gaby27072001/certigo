import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { copyFileSync, cpSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
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
  const directory = mkdtempSync(join(tmpdir(), 'certigo-network-inputs-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
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
  const wheels = '{"wheels":[{"name":"synthetic-only"}]}\n';
  writeFileSync(join(directory, 'apt-packages.lock.json'), apt);
  writeFileSync(join(directory, 'flutter-engine-artifacts.lock.json'), flutter);
  writeFileSync(join(directory, 'python-wheels.lock.json'), wheels);
  contract.reproducibility.aptPackageLockSha256 = hash(apt);
  contract.reproducibility.flutterEngineArtifactLockSha256 = hash(flutter);
  contract.reproducibility.pythonWheelLockSha256 = hash(wheels);
  return { directory, contract };
}

test('real bytes, not hash-shaped strings, are required for every network lock', (t) => {
  const { directory, contract } = fixture(t);
  assert.doesNotThrow(() => verifyNetworkLockDigests(contract, directory));
  assert.throws(() => assertNetworkInputsReady(contract, directory), {
    message: installationBlocker,
  });
  for (const field of ['aptPackageLockSha256', 'flutterEngineArtifactLockSha256',
    'pythonWheelLockSha256']) {
    for (const digest of [null, '', 'x'.repeat(64), 'a'.repeat(64)]) {
      const tampered = structuredClone(contract);
      tampered.reproducibility[field] = digest;
      assert.throws(() => verifyNetworkLockDigests(tampered, directory), /invalid|mismatch/);
    }
  }
});

test('the committed contract pins every committed network lock', () => {
  assert.doesNotThrow(() => verifyNetworkLockDigests(original));
  assert.throws(() => assertNetworkInputsReady(original), /fully locked/);
});

test('any omitted or altered lock fails before readiness can be authorized', (t) => {
  const { directory, contract } = fixture(t);
  for (const name of ['apt-packages.lock.json', 'flutter-engine-artifacts.lock.json',
    'python-wheels.lock.json']) {
    const path = join(directory, name);
    const content = readFileSync(path);
    writeFileSync(path, Buffer.concat([content, Buffer.from(' ')]));
    assert.throws(() => assertNetworkInputsReady(contract, directory), /digest mismatch/);
    rmSync(path);
    assert.throws(() => assertNetworkInputsReady(contract, directory), { code: 'ENOENT' });
    writeFileSync(path, content);
  }
});

test('empty, malformed or non-object JSON is not a network lock even with a matching digest', (t) => {
  const { directory, contract } = fixture(t);
  for (const contents of ['', '{}', '[]', 'null', 'true', '"locked"']) {
    writeFileSync(join(directory, 'apt-packages.lock.json'), contents);
    contract.reproducibility.aptPackageLockSha256 = hash(contents);
    assert.throws(() => verifyNetworkLockDigests(contract, directory), /JSON|nonempty/);
  }
});

test('rehashing redirected or unexpected artifact proposals cannot enable the installer', (t) => {
  const { directory, contract } = fixture(t);
  for (const artifacts of [
    [{ url: 'https://example.invalid/redirected', sha256: 'a'.repeat(64) }],
    [{ url: 'https://example.invalid/original' }, { url: 'https://example.invalid/unexpected' }],
    [],
  ]) {
    const bytes = JSON.stringify({ artifacts });
    writeFileSync(join(directory, 'flutter-engine-artifacts.lock.json'), bytes);
    contract.reproducibility.flutterEngineArtifactLockSha256 = hash(bytes);
    assert.throws(() => assertNetworkInputsReady(contract, directory), {
      message: installationBlocker,
    });
  }
});

test('symlink locks and mutable snapshot URLs are rejected', (t) => {
  const { directory, contract } = fixture(t);
  for (const snapshot of [
    'https://archive.ubuntu.com/ubuntu/',
    'https://snapshot.ubuntu.com/ubuntu/latest/',
    'https://snapshot.ubuntu.com/ubuntu/20260807T000000Z/?redirect=elsewhere',
  ]) {
    const bad = structuredClone(contract);
    bad.reproducibility.aptSnapshot = snapshot;
    assert.throws(() => assertNetworkInputsReady(bad, directory), /immutable Ubuntu snapshot/);
  }
  const lock = join(directory, 'apt-packages.lock.json');
  copyFileSync(lock, join(directory, 'elsewhere.json'));
  rmSync(lock);
  symlinkSync(join(directory, 'elsewhere.json'), lock);
  assert.throws(() => verifyNetworkLockDigests(contract, directory), /regular file/);
});

test('the CLI refuses forged readiness with valid on-disk digests', (t) => {
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
  assert.match(result.stderr, /the offline installer is not admitted until review, CI and explicit approval/);
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
  const { contract } = fixture(t);
  // The image template embeds its inputs: compile a full copy, then forge the flags.
  const workspace = mkdtempSync(join(tmpdir(), 'certigo-forged-arm-'));
  t.after(() => rmSync(workspace, { recursive: true, force: true }));
  const directory = join(workspace, 'image');
  cpSync(root, directory, { recursive: true });
  copyFileSync(join(root, '..', 'bootstrap.sh'), join(workspace, 'bootstrap.sh'));
  const templates = ['image-build', 'canary', 'canary-main'];
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
