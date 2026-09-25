import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkAlertReceivers } from '../check-alert-receivers.mjs';

const receiver = {
  name: 'secops', emailAddress: 'alerts@example.test', status: 'Enabled', verificationStatus: 'Verified',
};
const group = (receivers = [receiver], enabled = true) => ({
  properties: { enabled, emailReceivers: receivers },
});

test('enabled and verified required receiver passes without sending a message', () => {
  assert.doesNotThrow(() => checkAlertReceivers(group()));
});

for (const state of ['VerificationPending', 'NotVerified', 'Unknown', undefined]) {
  test(`receiver verification ${state} fails closed, even when Enabled`, () => {
    assert.throws(() => checkAlertReceivers(group([{ ...receiver, verificationStatus: state }])), /OTP/);
  });
}

test('missing configuration, disabled group, and absent secops fail', () => {
  for (const value of [null, {}, group([], true), group([receiver], false),
    group([{ ...receiver, name: 'another-receiver' }])]) {
    assert.throws(() => checkAlertReceivers(value));
  }
});

test('unsubscribe, missing address, and partially invalid recipient sets fail', () => {
  assert.throws(() => checkAlertReceivers(group([{ ...receiver, status: 'Disabled' }])));
  assert.throws(() => checkAlertReceivers(group([{ ...receiver, emailAddress: '' }])));
  assert.throws(() => checkAlertReceivers(group([receiver, null])));
  assert.throws(() => checkAlertReceivers(group([
    receiver, { ...receiver, name: 'second', verificationStatus: 'VerificationPending' },
  ])));
});

test('CLI has nonzero exit on invalid JSON or OTP pending and never prints the address', () => {
  const folder = mkdtempSync(path.join(tmpdir(), 'certigo-alert-receivers-'));
  const file = path.join(folder, 'group.json');
  const script = fileURLToPath(new URL('../check-alert-receivers.mjs', import.meta.url));
  try {
    for (const [contents, expected] of [
      [JSON.stringify(group()), 0],
      ['{invalid alerts@example.test', 1],
      [JSON.stringify(group([{ ...receiver, verificationStatus: 'VerificationPending' }])), 1],
    ]) {
      writeFileSync(file, contents);
      const result = spawnSync(process.execPath, [script, file], { encoding: 'utf8', timeout: 10_000 });
      assert.equal(result.status, expected);
      assert.doesNotMatch(result.stdout + result.stderr, /alerts@example\.test/);
    }
    assert.equal(spawnSync(process.execPath, [script], { timeout: 10_000 }).status, 1);
  } finally {
    rmSync(folder, { recursive: true });
  }
});
