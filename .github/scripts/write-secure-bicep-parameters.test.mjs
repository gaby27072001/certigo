import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { writeSecureParameters } from './write-secure-bicep-parameters.mjs';

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
      },
    }),
  );
  return file;
}

test('does not require or inject a signing key for dev', () => {
  const outputFile = outputPath();
  assert.equal(
    writeSecureParameters({
      environment: 'dev',
      jwtSigningKey: '',
      inputFile: compiledParameters(),
      outputFile,
    }),
    false,
  );
  const parameters = JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters;
  assert.deepEqual(parameters.env, { value: 'dev' });
  assert.equal(parameters.authJwtSigningKey, undefined);
});

test('rejects missing and whitespace-only keys outside dev', () => {
  for (const environment of ['staging', 'prod']) {
    for (const jwtSigningKey of ['', '   ', undefined]) {
      assert.throws(
        () =>
          writeSecureParameters({
            environment,
            jwtSigningKey,
            inputFile: compiledParameters(),
            outputFile: outputPath(),
          }),
        /AUTH_JWT_SIGNING_KEY is required/,
      );
    }
  }
});

test('writes the secure ARM parameter without logging or argument serialization', () => {
  const outputFile = outputPath();
  assert.equal(
    writeSecureParameters({
      environment: 'staging',
      jwtSigningKey: 'test-secret-value',
      inputFile: compiledParameters(),
      outputFile,
    }),
    true,
  );
  assert.deepEqual(
    JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters.authJwtSigningKey,
    {
      value: 'test-secret-value',
    },
  );
});

test('refuses to overwrite an existing parameter file', () => {
  const outputFile = outputPath();
  fs.writeFileSync(outputFile, 'existing');
  assert.throws(
    () =>
      writeSecureParameters({
        environment: 'prod',
        jwtSigningKey: 'test-secret-value',
        inputFile: compiledParameters(),
        outputFile,
      }),
    /EEXIST/,
  );
});

test('rejects a malformed compiled parameter document', () => {
  const inputFile = outputPath();
  fs.writeFileSync(inputFile, JSON.stringify({ parameters: [] }));
  assert.throws(
    () =>
      writeSecureParameters({
        environment: 'staging',
        jwtSigningKey: 'test-secret-value',
        inputFile,
        outputFile: outputPath(),
      }),
    /compiled Bicep parameter document is invalid/,
  );
});
