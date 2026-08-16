import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { writeSecureParameters } from './write-secure-bicep-parameters.mjs';

const expiration = '2027-12-31T00:00:00Z';
const now = new Date('2026-08-14T22:00:00Z');

function outputPath() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-bicep-params-'));
  return path.join(directory, 'parameters.json');
}

function compiledParameters() {
  const file = outputPath();
  fs.writeFileSync(
    file,
    JSON.stringify({
      $schema:
        'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#',
      contentVersion: '1.0.0.0',
      parameters: {
        env: { value: 'dev' },
        authJwtSigningKeyExpiresOn: { value: '2027-08-31T00:00:00Z' },
      },
    }),
  );
  return file;
}

function write(overrides = {}) {
  const outputFile = outputPath();
  const result = writeSecureParameters({
    environment: 'dev',
    alertEmail: '',
    jwtSigningKey: '',
    jwtSigningKeyExpiresOn: '',
    jwtPreviousSigningKey: '',
    jwtPreviousSigningKeyExpiresOn: '',
    inputFile: compiledParameters(),
    outputFile,
    now,
    ...overrides,
  });
  return { outputFile, result };
}

test('preserves the explicit stable dev expiration without injecting a secret', () => {
  const { outputFile, result } = write();
  const parameters = JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters;

  assert.deepEqual(result, { hasActiveKey: false, hasPreviousKey: false });
  assert.deepEqual(
    parameters.authJwtSigningKeyExpiresOn,
    { value: '2027-08-31T00:00:00Z' },
  );
  assert.equal(parameters.authJwtSigningKey, undefined);
});

test('requires the active key and expiration together outside dev', () => {
  for (const environment of ['staging', 'prod']) {
    assert.throws(
      () => write({ environment, alertEmail: 'alerts@example.invalid' }),
      /are required for staging and production/,
    );
    assert.throws(
      () => write({
        environment,
        alertEmail: 'alerts@example.invalid',
        jwtSigningKey: 'test-secret',
      }),
      /must be configured together/,
    );
  }
});

test('injects active and previous rotation pairs into a private parameter document', () => {
  const { outputFile, result } = write({
    environment: 'prod',
    alertEmail: 'alerts@example.invalid',
    jwtSigningKey: 'new-test-secret',
    jwtSigningKeyExpiresOn: expiration,
    jwtPreviousSigningKey: 'old-test-secret',
    jwtPreviousSigningKeyExpiresOn: expiration,
  });
  const parameters = JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters;

  assert.deepEqual(result, { hasActiveKey: true, hasPreviousKey: true });
  assert.deepEqual(parameters.authJwtSigningKey, { value: 'new-test-secret' });
  assert.deepEqual(parameters.authJwtSigningKeyExpiresOn, { value: expiration });
  assert.deepEqual(parameters.alertEmail, { value: 'alerts@example.invalid' });
  assert.deepEqual(
    parameters.authJwtPreviousSigningKey,
    { value: 'old-test-secret' },
  );
  assert.deepEqual(
    parameters.authJwtPreviousSigningKeyExpiresOn,
    { value: expiration },
  );
});

test('requires a valid environment alert receiver outside dev', () => {
  const requiredParameters = {
    environment: 'prod',
    jwtSigningKey: 'new-test-secret',
    jwtSigningKeyExpiresOn: expiration,
  };
  assert.throws(
    () => write(requiredParameters),
    /ALERT_EMAIL is required for staging and production/,
  );
  for (const alertEmail of [
    ' alerts@example.invalid',
    'alerts@example.invalid\nsecond@example.invalid',
    'alerts@localhost',
    'alerts..ops@example.invalid',
  ]) {
    assert.throws(
      () => write({ ...requiredParameters, alertEmail }),
      /ALERT_EMAIL must be a valid email address/,
    );
  }
});

test('rejects incomplete previous-key rotation and non-UTC expiration', () => {
  assert.throws(
    () => write({ jwtPreviousSigningKey: 'old-test-secret' }),
    /AUTH_JWT_PREVIOUS_SIGNING_KEY.*must be configured together/,
  );
  assert.throws(
    () => write({
      jwtSigningKey: 'new-test-secret',
      jwtSigningKeyExpiresOn: '2027-12-31',
    }),
    /absolute UTC timestamp/,
  );
  assert.throws(
    () => write({
      jwtSigningKey: 'same-test-secret',
      jwtSigningKeyExpiresOn: expiration,
      jwtPreviousSigningKey: 'same-test-secret',
      jwtPreviousSigningKeyExpiresOn: expiration,
    }),
    /must differ/,
  );
});

test('rejects active or previous expiration shorter than refresh-token overlap', () => {
  const tooSoon = '2026-11-12T22:01:59Z';
  assert.throws(
    () => write({
      jwtSigningKey: 'new-test-secret',
      jwtSigningKeyExpiresOn: tooSoon,
    }),
    /90-day refresh lifetime/,
  );
  assert.throws(
    () => write({
      jwtSigningKey: 'new-test-secret',
      jwtSigningKeyExpiresOn: expiration,
      jwtPreviousSigningKey: 'old-test-secret',
      jwtPreviousSigningKeyExpiresOn: tooSoon,
    }),
    /90-day refresh lifetime/,
  );
});

test('refuses to overwrite an existing parameter file', () => {
  const outputFile = outputPath();
  fs.writeFileSync(outputFile, 'existing');

  assert.throws(
    () => writeSecureParameters({
      environment: 'dev',
      alertEmail: '',
      jwtSigningKey: '',
      jwtSigningKeyExpiresOn: '',
      jwtPreviousSigningKey: '',
      jwtPreviousSigningKeyExpiresOn: '',
      inputFile: compiledParameters(),
      outputFile,
      now,
    }),
    /EEXIST/,
  );
});

test('rejects a malformed compiled parameter document', () => {
  const inputFile = outputPath();
  fs.writeFileSync(inputFile, JSON.stringify({ parameters: [] }));

  assert.throws(
    () => writeSecureParameters({
      environment: 'dev',
      alertEmail: '',
      jwtSigningKey: '',
      jwtSigningKeyExpiresOn: '',
      jwtPreviousSigningKey: '',
      jwtPreviousSigningKeyExpiresOn: '',
      inputFile,
      outputFile: outputPath(),
      now,
    }),
    /compiled Bicep parameter document is invalid/,
  );
});
