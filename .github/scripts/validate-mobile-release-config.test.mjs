import assert from 'node:assert/strict';
import test from 'node:test';

import {
  isPinnedNamedAuthority,
  pinnedCiamTenantId,
  pinnedNamedAuthority,
  validateMobileReleaseConfig,
} from './validate-mobile-release-config.mjs';

const validConfig = {
  apiBaseUrl: 'https://func-certigo-prod-izfhvvxjdxc2k.azurewebsites.net/api',
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

test('rejects the uncontrolled legacy vanity host', () => {
  const errors = validateMobileReleaseConfig({
    ...validConfig,
    apiBaseUrl: `https://api.${'certigo' + '.app'}/api`,
  });

  assert.deepEqual(errors, [
    'MOBILE_API_BASE_URL must identify the production Certigo backend.',
  ]);
});

const certigoTenant = 'af721be8-5901-422a-b299-b9c57847b968';
const authorityError = 'MOBILE_ENTRA_AUTHORITY must use the matching canonical tenant GUID in '
  + 'its host and path, or be exactly '
  + 'https://certigoapp.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0.';

test('the pinned named authority is written out and bound to the Certigo CIAM tenant', () => {
  assert.equal(
    pinnedNamedAuthority,
    'https://certigoapp.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0',
  );
  assert.equal(pinnedCiamTenantId, certigoTenant);
});

test('accepts exactly the pinned named authority', () => {
  assert.deepEqual(
    validateMobileReleaseConfig({
      ...validConfig,
      entraAuthority: 'https://certigoapp.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0',
    }),
    [],
  );
});

test('still accepts the tenant GUID form, including for the Certigo tenant', () => {
  for (const entraAuthority of [
    validConfig.entraAuthority,
    `https://${certigoTenant}.ciamlogin.com/${certigoTenant}/v2.0`,
  ]) {
    assert.deepEqual(
      validateMobileReleaseConfig({ ...validConfig, entraAuthority }),
      [],
      entraAuthority,
    );
  }
});

test('rejects every near miss of the pinned named authority', () => {
  const nearMisses = {
    'another ciamlogin.com subdomain': `https://certigo.ciamlogin.com/${certigoTenant}/v2.0`,
    'a tenant-name prefix of the pinned host': `https://app.ciamlogin.com/${certigoTenant}/v2.0`,
    'the pinned host with another tenant GUID':
      'https://certigoapp.ciamlogin.com/22222222-2222-4222-8222-222222222222/v2.0',
    'the pinned host with an upper-case tenant GUID':
      `https://certigoapp.ciamlogin.com/${certigoTenant.toUpperCase()}/v2.0`,
    'a look-alike suffix': `https://certigoapp.ciamlogin.com.evil.example/${certigoTenant}/v2.0`,
    'a look-alike prefix': `https://evil-certigoapp.ciamlogin.com/${certigoTenant}/v2.0`,
    'a hyphenated look-alike': `https://certigoapp-ciamlogin.com/${certigoTenant}/v2.0`,
    'a Cyrillic homoglyph': `https://certigo\u0430pp.ciamlogin.com/${certigoTenant}/v2.0`,
    'its punycode form': `https://xn--certigopp-6yh.ciamlogin.com/${certigoTenant}/v2.0`,
    'a trailing-dot host': `https://certigoapp.ciamlogin.com./${certigoTenant}/v2.0`,
    'an upper-case host spelling': `https://CERTIGOAPP.CIAMLOGIN.COM/${certigoTenant}/v2.0`,
    'plain http': `http://certigoapp.ciamlogin.com/${certigoTenant}/v2.0`,
    'the default port written out': `https://certigoapp.ciamlogin.com:443/${certigoTenant}/v2.0`,
    'another port': `https://certigoapp.ciamlogin.com:8443/${certigoTenant}/v2.0`,
    'user information': `https://user@certigoapp.ciamlogin.com/${certigoTenant}/v2.0`,
    'empty user information': `https://@certigoapp.ciamlogin.com/${certigoTenant}/v2.0`,
    'empty credentials': `https://:@certigoapp.ciamlogin.com/${certigoTenant}/v2.0`,
    'the pinned host as user information':
      `https://certigoapp.ciamlogin.com@evil.example/${certigoTenant}/v2.0`,
    'an extra trailing segment': `https://certigoapp.ciamlogin.com/${certigoTenant}/v2.0/extra`,
    'an extra leading segment': `https://certigoapp.ciamlogin.com/x/${certigoTenant}/v2.0`,
    'a trailing slash': `https://certigoapp.ciamlogin.com/${certigoTenant}/v2.0/`,
    'dot segments': `https://certigoapp.ciamlogin.com/x/../${certigoTenant}/v2.0`,
    'encoded dot segments': `https://certigoapp.ciamlogin.com/x/%2e%2e/${certigoTenant}/v2.0`,
    'a query': `https://certigoapp.ciamlogin.com/${certigoTenant}/v2.0?p=1`,
    'an empty query marker': `https://certigoapp.ciamlogin.com/${certigoTenant}/v2.0?`,
    'a fragment': `https://certigoapp.ciamlogin.com/${certigoTenant}/v2.0#x`,
    'an empty fragment marker': `https://certigoapp.ciamlogin.com/${certigoTenant}/v2.0#`,
    'surrounding whitespace': ` https://certigoapp.ciamlogin.com/${certigoTenant}/v2.0\n`,
    backslashes: `https:\\\\certigoapp.ciamlogin.com\\${certigoTenant}\\v2.0`,
  };

  for (const [label, entraAuthority] of Object.entries(nearMisses)) {
    assert.equal(isPinnedNamedAuthority(entraAuthority), false, label);
    const errors = validateMobileReleaseConfig({ ...validConfig, entraAuthority });
    assert.equal(errors.length, 1, label);
    assert.ok(
      errors[0] === authorityError
        || errors[0]
          === 'MOBILE_ENTRA_AUTHORITY must be a plain HTTPS URL without credentials, query or fragment.',
      `${label}: ${errors[0]}`,
    );
  }
});

test('the pinned named authority can never come from a value other than itself', () => {
  assert.equal(isPinnedNamedAuthority(pinnedNamedAuthority), true);
  for (const value of [undefined, null, '', 42, { toString: () => pinnedNamedAuthority }]) {
    assert.equal(isPinnedNamedAuthority(value), false, String(value));
  }
});
