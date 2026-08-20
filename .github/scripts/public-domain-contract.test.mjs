import assert from 'node:assert/strict';
import test from 'node:test';

import { validatePublicDomainConfiguration } from './public-domain-contract.mjs';

const verifiedConfiguration = {
  environment: 'prod',
  feature: 'infrastructure',
  publicWebOrigin: 'https://github.com',
  publicDomainVerified: 'true',
  appleCiamDomainReconfigured: 'true',
};

test('keeps an unconfigured development environment neutral', () => {
  assert.deepEqual(
    validatePublicDomainConfiguration({
      environment: 'dev',
      feature: 'infrastructure',
      publicWebOrigin: '',
      publicDomainVerified: '',
      appleCiamDomainReconfigured: '',
      activationRequested: false,
    }),
    {
      appleCiamDomainReconfigured: false,
      publicDomainVerified: false,
      publicWebOrigin: '',
      ready: false,
    },
  );
});

test('accepts a canonical verified HTTPS origin for app-facing features', () => {
  assert.deepEqual(
    validatePublicDomainConfiguration(verifiedConfiguration),
    {
      appleCiamDomainReconfigured: true,
      publicDomainVerified: true,
      publicWebOrigin: 'https://github.com',
      ready: true,
    },
  );
});

test('legal pages require ownership verification but not Apple reconfiguration', () => {
  assert.equal(
    validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      feature: 'legal-pages',
      appleCiamDomainReconfigured: 'false',
    }).ready,
    true,
  );
});

test('fails closed when the origin or explicit verification is missing', () => {
  assert.throws(
    () => validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      publicWebOrigin: '',
    }),
    /PUBLIC_WEB_ORIGIN is required/,
  );
  assert.throws(
    () => validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      publicDomainVerified: 'false',
    }),
    /PUBLIC_DOMAIN_VERIFIED must be explicitly true/,
  );
  assert.throws(
    () => validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      appleCiamDomainReconfigured: 'false',
    }),
    /APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true/,
  );
});

test('rejects non-canonical, placeholder, IP and unowned legacy origins', () => {
  for (const publicWebOrigin of [
    'http://github.com',
    'https://github.com/',
    'https://github.com/path',
    'https://github.com?query=1',
    'https://github.com:443',
    'https://github.com.',
    'https://127.0.0.1',
    'https://localhost',
    'https://service.invalid',
    'https://example.com',
    `https://${['certigo', 'app'].join('.')}`,
    `https://${['certigo', 'app'].join('.')}.`,
    `https://www.${['certigo', 'app'].join('.')}`,
  ]) {
    assert.throws(
      () => validatePublicDomainConfiguration({
        ...verifiedConfiguration,
        publicWebOrigin,
      }),
      /PUBLIC_WEB_ORIGIN/,
      publicWebOrigin,
    );
  }
});

test('rejects ambiguous boolean values instead of coercing them', () => {
  for (const publicDomainVerified of ['TRUE', '1', 'yes']) {
    assert.throws(
      () => validatePublicDomainConfiguration({
        ...verifiedConfiguration,
        publicDomainVerified,
      }),
      /PUBLIC_DOMAIN_VERIFIED must be explicitly true or false/,
    );
  }
});
