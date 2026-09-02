import assert from 'node:assert/strict';
import test from 'node:test';

import { validatePublicDomainConfiguration } from './public-domain-contract.mjs';

const verifiedConfiguration = {
  environment: 'prod',
  feature: 'infrastructure',
  publicWebOrigin: 'https://certigo-app.com',
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
      publicWebOrigin: 'https://certigo-app.com',
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
    'http://certigo-app.com',
    'https://certigo-app.com/',
    'https://certigo-app.com/Certigo',
    'https://certigo-app.com?query=1',
    'https://certigo-app.com#fragment',
    'https://certigo-app.com:443',
    'https://certigo-app.com:444',
    'https://certigo-app.com.',
    'https://user@certigo-app.com',
    ' https://certigo-app.com',
    'https://127.0.0.1',
    'https://localhost',
    'https://service.invalid',
    'https://example.com',
    'https://github.com',
    'https://gchambaud_microsoft.github.io',
    `https://${['certigo', 'app'].join('.')}`,
    `https://${['certigo', 'app'].join('.')}.`,
    `https://www.${['certigo', 'app'].join('.')}`,
    'https://www.certigo-app.com',
    'https://links.certigo-app.com',
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

test('association publication requires every activation proof', () => {
  assert.throws(
    () => validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      feature: 'link-associations',
      appleCiamDomainReconfigured: 'false',
    }),
    /APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true/,
  );
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
