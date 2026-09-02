import assert from 'node:assert/strict';
import test from 'node:test';

import { findForbiddenDomainReferences } from './validate-domain-policy.mjs';

const unownedDomain = `certigo${'.app'}`;
const legacyIdentifier = `${unownedDomain}-certification-catalog/v2`;

test('allows the documented opaque legacy catalog identifier only in compatibility paths', () => {
  const errors = findForbiddenDomainReferences([
    {
      file: 'backend/src/Certigo.Application/Services/CertificationCatalog.cs',
      content: `const string Legacy = "${legacyIdentifier}";`,
    },
  ]);

  assert.deepEqual(errors, []);
});

test('rejects operational URLs, subdomains and email addresses', () => {
  const errors = findForbiddenDomainReferences([
    {
      file: 'docs/release.md',
      content: [
        `https://${unownedDomain}/privacy-policy/`,
        `https://api.${unownedDomain}/api`,
        `support@${unownedDomain}`,
      ].join('\n'),
    },
  ]);

  assert.equal(errors.length, 3);
});

test('rejects the legacy identifier outside its explicit compatibility allow-list', () => {
  const errors = findForbiddenDomainReferences([
    {
      file: 'apps/mobile/distribution/store-listing.md',
      content: legacyIdentifier,
    },
  ]);

  assert.equal(errors.length, 1);
});
