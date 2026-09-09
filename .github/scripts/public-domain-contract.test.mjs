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

test('an unconfigured hardened environment deploys with every feature disabled', () => {
  // An empty origin means no activation was asked for. The deployment must proceed with
  // every public-domain feature disabled instead of being refused: the guard exists to
  // refuse activation without proof, not to refuse deployment.
  assert.deepEqual(
    validatePublicDomainConfiguration({
      environment: 'prod',
      feature: 'infrastructure',
      publicWebOrigin: '',
      publicDomainVerified: '',
      appleCiamDomainReconfigured: '',
    }),
    {
      appleCiamDomainReconfigured: false,
      publicDomainVerified: false,
      publicWebOrigin: '',
      ready: false,
    },
  );
});

test('refuses a proof posted without an origin', () => {
  // Optional hardening, isolated so it can be dropped on its own.
  for (const half of [
    { publicDomainVerified: 'true', appleCiamDomainReconfigured: 'false' },
    { publicDomainVerified: 'false', appleCiamDomainReconfigured: 'true' },
  ]) {
    assert.throws(
      () => validatePublicDomainConfiguration({
        environment: 'prod',
        feature: 'infrastructure',
        publicWebOrigin: '',
        ...half,
      }),
      /PUBLIC_WEB_ORIGIN is required when/,
    );
  }
});

test('an explicit caller opt-out keeps a configured origin inert', () => {
  assert.equal(
    validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      activationRequested: false,
    }).ready,
    false,
  );
});

test('a caller that publishes the domain makes activation mandatory', () => {
  // tools/build_public_pages.mjs writes the domain's own pages: an unconfigured origin
  // must stop it, where a deployment would simply leave the feature disabled.
  assert.throws(
    () => validatePublicDomainConfiguration({
      environment: 'prod',
      feature: 'legal-pages',
      publicWebOrigin: '',
      publicDomainVerified: 'false',
      appleCiamDomainReconfigured: 'false',
      activationRequested: true,
    }),
    /PUBLIC_WEB_ORIGIN is required before public-domain activation/,
  );
  assert.equal(
    validatePublicDomainConfiguration({
      environment: 'prod',
      feature: 'legal-pages',
      publicWebOrigin: '',
      publicDomainVerified: 'false',
      appleCiamDomainReconfigured: 'false',
    }).ready,
    false,
  );
});

test('fails closed when explicit verification is missing', () => {
  assert.throws(
    () => validatePublicDomainConfiguration({
    ...verifiedConfiguration,
    publicDomainVerified: 'false',
    }),
    /PUBLIC_DOMAIN_VERIFIED must be explicitly true/,
  );
});

test('enabling account deletion re-arms the Apple requirement for infrastructure', () => {
  // The infrastructure deployment publishes no Apple artifact until it activates an
  // app-facing URL. Both directions are asserted: the requirement must be absent while
  // account deletion is off, and must bite on its own as soon as it is on.
  assert.equal(
    validatePublicDomainConfiguration({
    ...verifiedConfiguration,
    appleCiamDomainReconfigured: 'false',
    accountDeletionEnabled: 'false',
    }).ready,
    true,
  );
  assert.throws(
    () => validatePublicDomainConfiguration({
    ...verifiedConfiguration,
    appleCiamDomainReconfigured: 'false',
    accountDeletionEnabled: 'true',
    }),
    /APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true/,
  );
});

test('keeps the Apple requirement unconditional for every app-facing feature', () => {
  for (const feature of [
    'account-deletion-url',
    'apple-ciam',
    'link-associations',
    'redirects',
  ]) {
    assert.throws(
    () => validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      feature,
      appleCiamDomainReconfigured: 'false',
      accountDeletionEnabled: 'false',
    }),
    /APPLE_CIAM_DOMAIN_RECONFIGURED must be explicitly true/,
    feature,
    );
  }
});

test('rejects an ambiguous account-deletion signal instead of coercing it', () => {
  for (const accountDeletionEnabled of ['TRUE', '1', 'yes']) {
    assert.throws(
    () => validatePublicDomainConfiguration({
      ...verifiedConfiguration,
      accountDeletionEnabled,
    }),
    /ACCOUNT_DELETION_ENABLED must be explicitly true or false/,
    );
  }
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
