import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import {
  assertOsvScannedEveryLockfile,
  buildOsvScanArguments,
  parseOsvPolicyArguments,
} from './run-osv-scan.mjs';

function harness() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-osv-invocation-'));
  fs.writeFileSync(path.join(root, 'package-lock.json'), '{}');
  return root;
}

function contract(sources = ['package-lock.json']) {
  return {
    sources,
    pubManifests: [],
  };
}

test('invokes OSV only for every validated lockfile', () => {
  const root = harness();
  try {
    const args = buildOsvScanArguments(
      contract(),
      root,
      path.join(root, 'results.json'),
      path.join(root, 'osv-scanner.toml'),
    );

    assert.deepEqual(args.slice(0, 6), [
      'scan',
      '--format=json',
      '--no-ignore',
      `--config=${path.join(root, 'osv-scanner.toml')}`,
      '--output-file',
      path.join(root, 'results.json'),
    ]);
    assert.deepEqual(args.slice(6), [`--lockfile=${path.join(root, 'package-lock.json')}`]);
    assert.ok(!args.includes('--recursive'));
    assert.ok(!args.includes('--all-packages'));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('rejects empty, duplicate, escaping, and missing lockfile contracts', () => {
  const root = harness();
  try {
    const build = (sources) => buildOsvScanArguments(
      contract(sources),
      root,
      path.join(root, 'results.json'),
      path.join(root, 'osv-scanner.toml'),
    );

    assert.throws(() => build([]), /at least one lockfile/u);
    assert.throws(
      () => build(['package-lock.json', 'package-lock.json']),
      /duplicate lockfiles/u,
    );
    assert.throws(() => build(['../package-lock.json']), /repository-relative/u);
    assert.throws(() => build(['missing.lock']), /ENOENT/u);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('fails closed unless OSV confirms every explicit lockfile was scanned', () => {
  const args = [
    '--lockfile=/workspace/package-lock.json',
    '--lockfile=/workspace/pubspec.lock',
  ];
  assert.doesNotThrow(() => assertOsvScannedEveryLockfile(
    'Scanned /workspace/package-lock.json file and found 10 packages\n'
      + 'Scanned /workspace/pubspec.lock file and found 20 packages\n',
    args,
  ));
  assert.throws(
    () => assertOsvScannedEveryLockfile(
      'Scanned /workspace/package-lock.json file and found 10 packages\n',
      args,
    ),
    /omitted expected tracked lockfiles.*\/workspace\/pubspec\.lock/u,
  );
});

test('requires active scan policy and forbids recursive all-package discovery', () => {
  const policy = parseOsvPolicyArguments([
    '--format=json',
    '--no-ignore',
    '--forbid-argument=--all-packages',
    '--forbid-argument=--recursive',
    '--config=/workspace/osv-scanner.toml',
    '--output-file',
    '/workspace/results.json',
  ]);
  assert.equal(policy.format, 'json');
  assert.equal(policy.noIgnore, true);
  assert.deepEqual(
    [...policy.forbiddenArguments].sort(),
    ['--all-packages', '--recursive'],
  );
  assert.throws(
    () => parseOsvPolicyArguments([
      '--format=json',
      '--no-ignore',
      '--config=/workspace/osv-scanner.toml',
      '--output-file',
      '/workspace/results.json',
    ]),
    /must forbid --all-packages/u,
  );
});
