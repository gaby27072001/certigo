import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { writeSecureParameters } from './write-secure-bicep-parameters.mjs';

const expiration = '2027-12-31T00:00:00Z';
const now = new Date('2026-08-14T22:00:00Z');
const accountDeletionIdentityConfiguration = {
  entraGraphTenantId: '11111111-1111-1111-1111-111111111111',
  entraGraphClientId: '22222222-2222-2222-2222-222222222222',
  entraGraphClientSecret: 'test-graph-client-secret',
  entraGraphClientSecretExpiresOn: expiration,
  entraReauthAudience: '44444444-4444-4444-4444-444444444444',
};
const publicDomainConfiguration = {
  publicWebOrigin: 'https://github.com',
  publicDomainVerified: 'true',
  appleCiamDomainReconfigured: 'true',
};
const contentConfiguration = {
  contentBlobEndpoint: 'https://stcertigocontent.blob.core.windows.net/',
  contentReaderClientId: '55555555-5555-5555-5555-555555555555',
  contentReaderResourceId:
    '/subscriptions/66666666-6666-6666-6666-666666666666/resourceGroups/rg-certigo-content/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-certigo-content-reader',
  contentDescriptorContainerName: 'content-release-descriptors',
  contentPublicContainerName: 'content-public-releases',
  contentPrivateContainerName: 'content-private-releases',
};

function outputPath() {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-bicep-params-'));
  return path.join(directory, 'parameters.json');
}

function compiledParameters(accountDeletionEnabled = true) {
  const file = outputPath();
  fs.writeFileSync(
    file,
    JSON.stringify({
      $schema:
        'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#',
      contentVersion: '1.0.0.0',
      parameters: {
        env: { value: 'dev' },
        accountDeletionEnabled: { value: accountDeletionEnabled },
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
    entraGraphTenantId: '',
    entraGraphClientId: '',
    entraGraphClientSecret: '',
    entraGraphClientSecretExpiresOn: '',
    entraReauthAudience: '',
    ...publicDomainConfiguration,
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
        ...accountDeletionIdentityConfiguration,
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
    ...accountDeletionIdentityConfiguration,
  });

  const parameters = JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters;

  assert.deepEqual(result, { hasActiveKey: true, hasPreviousKey: true });
  assert.deepEqual(parameters.authJwtSigningKey, { value: 'new-test-secret' });
  assert.deepEqual(parameters.authJwtSigningKeyExpiresOn, { value: expiration });
  assert.deepEqual(parameters.alertEmail, { value: 'alerts@example.invalid' });
  assert.deepEqual(
    parameters.entraGraphClientSecret,
    { value: accountDeletionIdentityConfiguration.entraGraphClientSecret },
  );
  assert.deepEqual(
    parameters.entraReauthAudience,
    { value: accountDeletionIdentityConfiguration.entraReauthAudience },
  );
  assert.deepEqual(
    parameters.entraGraphClientSecretExpiresOn,
    { value: expiration },
  );
  assert.deepEqual(
    parameters.authJwtPreviousSigningKey,
    { value: 'old-test-secret' },
  );
  assert.deepEqual(
    parameters.authJwtPreviousSigningKeyExpiresOn,
    { value: expiration },
  );
});

test('injects the complete PR 290 content outputs and rejects partial wiring', () => {
  const { outputFile } = write({
    ...contentConfiguration,
    contentRepositoryMode: 'versioned',
  });
  const parameters = JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters;
  for (const [name, value] of Object.entries(contentConfiguration)) {
    assert.deepEqual(parameters[name], { value });
  }
  assert.deepEqual(parameters.contentRepositoryMode, { value: 'versioned' });

  assert.throws(
    () => write({ contentBlobEndpoint: contentConfiguration.contentBlobEndpoint }),
    /All immutable content outputs from PR #290 must be configured together/,
  );
  assert.throws(
    () => write({
      ...contentConfiguration,
      contentReaderResourceId: '/subscriptions/not-an-identity',
    }),
    /must identify a user-assigned managed identity/,
  );
  assert.throws(
    () => write({ contentRepositoryMode: 'versioned' }),
    /requires the complete PR #290 outputs/,
  );
  assert.throws(
    () => write({ ...contentConfiguration, contentRepositoryMode: 'invalid' }),
    /must be legacy or versioned/,
  );
});

test('requires a valid environment alert receiver outside dev', () => {
  const requiredParameters = {
    environment: 'prod',
    jwtSigningKey: 'new-test-secret',
    jwtSigningKeyExpiresOn: expiration,
    ...accountDeletionIdentityConfiguration,
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

test('requires complete account deletion identity configuration outside dev', () => {
  const requiredParameters = {
    environment: 'prod',
    alertEmail: 'alerts@example.invalid',
    jwtSigningKey: 'new-test-secret',
    jwtSigningKeyExpiresOn: expiration,
  };
  assert.throws(
    () => write(requiredParameters),
    /ENTRA_GRAPH_TENANT_ID.*are required for staging and production/,
  );
  assert.throws(
    () => write({
      ...requiredParameters,
      entraGraphTenantId: accountDeletionIdentityConfiguration.entraGraphTenantId,
    }),
    /required for staging and production/,
  );
});

test('feature-off hardened deployment still requires the verified public domain', () => {
  const inputFile = compiledParameters(false);
  assert.throws(
    () => write({
      environment: 'prod',
      alertEmail: 'alerts@example.invalid',
      jwtSigningKey: 'new-test-secret',
      jwtSigningKeyExpiresOn: expiration,
      publicWebOrigin: '',
      publicDomainVerified: '',
      appleCiamDomainReconfigured: '',
      inputFile,
    }),
    /PUBLIC_WEB_ORIGIN is required/,
  );
  const { outputFile } = write({
    environment: 'prod',
    alertEmail: 'alerts@example.invalid',
    jwtSigningKey: 'new-test-secret',
    jwtSigningKeyExpiresOn: expiration,
    inputFile,
  });
  const parameters = JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters;

  assert.equal(parameters.entraGraphTenantId, undefined);
  assert.equal(parameters.entraGraphClientId, undefined);
  assert.equal(parameters.entraGraphClientSecret, undefined);
  assert.equal(parameters.entraGraphClientSecretExpiresOn, undefined);
  assert.equal(parameters.entraReauthAudience, undefined);
  assert.deepEqual(parameters.publicWebOrigin, { value: 'https://github.com' });
  assert.deepEqual(parameters.publicDomainVerified, { value: true });
  assert.deepEqual(parameters.appleCiamDomainReconfigured, { value: true });
});

test('requires the verified public-domain contract before hardened activation', () => {
  const requiredParameters = {
    environment: 'prod',
    alertEmail: 'alerts@example.invalid',
    jwtSigningKey: 'new-test-secret',
    jwtSigningKeyExpiresOn: expiration,
    ...accountDeletionIdentityConfiguration,
  };
  assert.throws(
    () => write({ ...requiredParameters, publicWebOrigin: '' }),
    /PUBLIC_WEB_ORIGIN is required/,
  );
  assert.throws(
    () => write({ ...requiredParameters, publicDomainVerified: 'false' }),
    /PUBLIC_DOMAIN_VERIFIED must be explicitly true/,
  );
  assert.throws(
    () => write({ ...requiredParameters, appleCiamDomainReconfigured: 'false' }),
    /APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true/,
  );
});

test('requires canonical Entra identifiers', () => {
  assert.throws(
    () => write({
      environment: 'prod',
      alertEmail: 'alerts@example.invalid',
      jwtSigningKey: 'new-test-secret',
      jwtSigningKeyExpiresOn: expiration,
      ...accountDeletionIdentityConfiguration,
      entraGraphClientId: 'not-a-guid',
    }),
    /ENTRA_GRAPH_CLIENT_ID must be a canonical Entra GUID/,
  );
});

test('dev omits incomplete Graph configuration instead of persisting a partial secret', () => {
  const { outputFile } = write({
    entraGraphTenantId: accountDeletionIdentityConfiguration.entraGraphTenantId,
  });
  const parameters = JSON.parse(fs.readFileSync(outputFile, 'utf8')).parameters;
  assert.equal(parameters.entraGraphTenantId, undefined);
  assert.equal(parameters.entraGraphClientSecret, undefined);
});

test('returns no Graph secret material after writing secure parameters', () => {
  const { result } = write({
    environment: 'prod',
    alertEmail: 'alerts@example.invalid',
    jwtSigningKey: 'new-test-secret',
    jwtSigningKeyExpiresOn: expiration,
    ...accountDeletionIdentityConfiguration,
  });
  assert.doesNotMatch(
    JSON.stringify(result),
    new RegExp(accountDeletionIdentityConfiguration.entraGraphClientSecret),
  );
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
      entraGraphTenantId: '',
      entraGraphClientId: '',
      entraGraphClientSecret: '',
      entraGraphClientSecretExpiresOn: '',
      entraReauthAudience: '',
      publicWebOrigin: '',
      publicDomainVerified: '',
      appleCiamDomainReconfigured: '',
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
      entraGraphTenantId: '',
      entraGraphClientId: '',
      entraGraphClientSecret: '',
      entraGraphClientSecretExpiresOn: '',
      entraReauthAudience: '',
      publicWebOrigin: '',
      publicDomainVerified: '',
      appleCiamDomainReconfigured: '',
      inputFile,
      outputFile: outputPath(),
      now,
    }),
    /compiled Bicep parameter document is invalid/,
  );
});
