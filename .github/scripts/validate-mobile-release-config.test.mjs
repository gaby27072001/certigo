import assert from 'node:assert/strict';
import test from 'node:test';

import { validateMobileReleaseConfig } from './validate-mobile-release-config.mjs';

const validConfig = {
  apiBaseUrl: 'https://func-certigo-prod-bk3j5ja6vw23s.azurewebsites.net/api',
  entraClientId: '11111111-1111-4111-8111-111111111111',
  entraAuthority:
    'https://22222222-2222-4222-8222-222222222222.ciamlogin.com/22222222-2222-4222-8222-222222222222/v2.0',
  entraApiScope:
    'api://33333333-3333-4333-8333-333333333333/user_impersonation',
  certigoEnv: 'prod',
};

test('accepts a complete production mobile release configuration', () => {
  assert.deepEqual(validateMobileReleaseConfig(validConfig), []);
});

test('rejects dev, legacy, vanity and placeholder release values', () => {
  const errors = validateMobileReleaseConfig({
    apiBaseUrl: 'https://func-microlingo-dev.azurewebsites.net/api',
    entraClientId: '00000000-0000-0000-0000-000000000000',
    entraAuthority:
      'https://certigo.ciamlogin.com/00000000-0000-0000-0000-000000000000/v2.0',
    entraApiScope:
      'api://00000000-0000-0000-0000-000000000000/placeholder',
    certigoEnv: 'dev',
  });

  assert.equal(errors.length, 5);
  assert.match(errors.join('\n'), /production Certigo backend/);
  assert.match(errors.join('\n'), /canonical tenant GUID/);
});

test('rejects a production-looking API URL with query parameters', () => {
  const errors = validateMobileReleaseConfig({
    ...validConfig,
    apiBaseUrl: `${validConfig.apiBaseUrl}?legacy=true`,
  });

  assert.deepEqual(errors, [
    'MOBILE_API_BASE_URL must be a plain HTTPS URL without credentials, query or fragment.',
  ]);
});

test('rejects staging API hosts and non-canonical scope names', () => {
  const errors = validateMobileReleaseConfig({
    ...validConfig,
    apiBaseUrl: 'https://func-certigo-staging-bk3j5ja6vw23s.azurewebsites.net/api',
    entraApiScope:
      'api://33333333-3333-4333-8333-333333333333/access_as_user',
  });

  assert.equal(errors.length, 2);
  assert.match(errors.join('\n'), /production Certigo backend/);
  assert.match(errors.join('\n'), /user_impersonation/);
});

test('rejects an arbitrary HTTPS API host', () => {
  const errors = validateMobileReleaseConfig({
    ...validConfig,
    apiBaseUrl: 'https://api.example.org/api',
  });

  assert.deepEqual(errors, [
    'MOBILE_API_BASE_URL must identify the production Certigo backend.',
  ]);
});
