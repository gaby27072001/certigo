import assert from 'node:assert/strict';
import test from 'node:test';
import {
  collectCredentials,
  daysUntil,
  evaluatePosture,
  renderSummary,
  requestAllPages,
} from './ciam-posture-report.mjs';

const NOW = new Date('2026-09-04T00:00:00Z');

function application(overrides = {}) {
  return {
    appId: 'df42c145-6dfc-4820-a79d-740acf27b565',
    displayName: 'Certigo MSA Login',
    passwordCredentials: [
      { displayName: 'certigo-ciam-oidc-2026-07', keyId: 'k1', endDateTime: '2027-07-01T00:00:00Z' },
    ],
    keyCredentials: [],
    ...overrides,
  };
}

function healthyInputs(overrides = {}) {
  return {
    applications: [application()],
    securityDefaults: { isEnabled: true },
    breakGlassMethods: [{ '@odata.type': '#microsoft.graph.fido2AuthenticationMethod' }],
    breakGlassUpn: 'breakglass@certigoapp.onmicrosoft.com',
    thresholdDays: 90,
    now: NOW,
    ...overrides,
  };
}

function codes(result) {
  return result.findings.map((finding) => finding.code);
}

test('daysUntil floors the remaining whole days', () => {
  assert.equal(daysUntil('2026-09-14T00:00:00Z', NOW), 10);
  assert.equal(daysUntil('2026-08-25T00:00:00Z', NOW), -10);
  assert.equal(daysUntil('not-a-date', NOW), null);
});

test('collectCredentials flattens secrets and certificates', () => {
  const rows = collectCredentials([
    application({
      keyCredentials: [{ displayName: 'cert', keyId: 'k2', endDateTime: '2027-01-01T00:00:00Z' }],
    }),
  ]);
  assert.equal(rows.length, 2);
  assert.deepEqual(rows.map((row) => row.kind), ['secret', 'certificate']);
});

test('a healthy tenant produces no findings', () => {
  const result = evaluatePosture(healthyInputs());
  assert.deepEqual(result.findings, []);
  assert.equal(result.failed, false);
});

test('a credential inside the threshold fails the run', () => {
  const result = evaluatePosture(healthyInputs({
    applications: [application({
      passwordCredentials: [
        { displayName: 'soon', keyId: 'k1', endDateTime: '2026-10-01T00:00:00Z' },
      ],
    })],
  }));
  assert.deepEqual(codes(result), ['CREDENTIAL_EXPIRING']);
  assert.equal(result.failed, true);
});

test('a credential outside the threshold does not fire', () => {
  const result = evaluatePosture(healthyInputs({ thresholdDays: 30 }));
  assert.deepEqual(result.findings, []);
});

test('an already expired credential is reported distinctly', () => {
  const result = evaluatePosture(healthyInputs({
    applications: [application({
      passwordCredentials: [
        { displayName: 'stale', keyId: 'k1', endDateTime: '2026-08-01T00:00:00Z' },
      ],
    })],
  }));
  assert.deepEqual(codes(result), ['CREDENTIAL_EXPIRED']);
});

test('disabled security defaults are an error because nothing else enforces admin MFA', () => {
  const result = evaluatePosture(healthyInputs({ securityDefaults: { isEnabled: false } }));
  assert.deepEqual(codes(result), ['SECURITY_DEFAULTS_DISABLED']);
  assert.equal(result.failed, true);
});

test('an unreadable security defaults policy fails closed', () => {
  const result = evaluatePosture(healthyInputs({ securityDefaults: null }));
  assert.deepEqual(codes(result), ['SECURITY_DEFAULTS_UNREADABLE']);
});

test('a password-only break-glass account is reported as unusable', () => {
  const result = evaluatePosture(healthyInputs({
    breakGlassMethods: [{ '@odata.type': '#microsoft.graph.passwordAuthenticationMethod' }],
  }));
  assert.deepEqual(codes(result), ['BREAK_GLASS_NO_STRONG_METHOD']);
  assert.equal(result.failed, true);
});

test('any strong method clears the break-glass check', () => {
  for (const type of [
    '#microsoft.graph.fido2AuthenticationMethod',
    '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod',
    '#microsoft.graph.softwareOathAuthenticationMethod',
    '#microsoft.graph.temporaryAccessPassAuthenticationMethod',
  ]) {
    const result = evaluatePosture(healthyInputs({
      breakGlassMethods: [
        { '@odata.type': '#microsoft.graph.passwordAuthenticationMethod' },
        { '@odata.type': type },
      ],
    }));
    assert.deepEqual(result.findings, [], `expected ${type} to satisfy the check`);
  }
});

test('an unparseable expiry warns without failing the run', () => {
  const result = evaluatePosture(healthyInputs({
    applications: [application({
      passwordCredentials: [{ displayName: 'odd', keyId: 'k1', endDateTime: 'nonsense' }],
    })],
  }));
  assert.deepEqual(codes(result), ['CREDENTIAL_UNPARSEABLE_EXPIRY']);
  assert.equal(result.failed, false);
});

test('renderSummary lists credentials soonest first', () => {
  const result = evaluatePosture(healthyInputs({
    applications: [application({
      passwordCredentials: [
        { displayName: 'later', keyId: 'k1', endDateTime: '2027-07-01T00:00:00Z' },
        { displayName: 'sooner', keyId: 'k2', endDateTime: '2026-12-01T00:00:00Z' },
      ],
    })],
  }));
  const summary = renderSummary({ ...result, thresholdDays: 90 });
  assert.ok(summary.indexOf('sooner') < summary.indexOf('later'));
  assert.match(summary, /Alert threshold: \*\*90 days\*\*/u);
});

// An empty collection and a healthy tenant produce the same visible output, so the
// monitor must not let a read that returned nothing pass as "nothing to report".
test('an empty application list fails instead of reporting no expiring secrets', () => {
  const result = evaluatePosture(healthyInputs({ applications: [] }));
  assert.deepEqual(codes(result), ['APPLICATION_LIST_EMPTY']);
  assert.equal(result.failed, true);
});

test('a populated application list does not raise the empty-read finding', () => {
  const result = evaluatePosture(healthyInputs());
  assert.ok(!codes(result).includes('APPLICATION_LIST_EMPTY'));
});

test('requestAllPages follows every nextLink', async () => {
  const pages = {
    'https://graph/p1': { value: [1, 2], '@odata.nextLink': 'https://graph/p2' },
    'https://graph/p2': { value: [3], '@odata.nextLink': 'https://graph/p3' },
    'https://graph/p3': { value: [4] },
  };
  const seen = [];
  const items = await requestAllPages('https://graph/p1', 'tok', async (url) => {
    seen.push(url);
    return pages[url];
  });
  assert.deepEqual(items, [1, 2, 3, 4]);
  assert.deepEqual(seen, ['https://graph/p1', 'https://graph/p2', 'https://graph/p3']);
});

test('requestAllPages propagates a mid-walk failure instead of returning a partial list', async () => {
  await assert.rejects(
    requestAllPages('https://graph/p1', 'tok', async (url) => {
      if (url.endsWith('p1')) {
        return { value: [1], '@odata.nextLink': 'https://graph/p2' };
      }
      throw new Error('HTTP 503');
    }),
    /HTTP 503/u,
  );
});

test('requestAllPages rejects a response without a value collection', async () => {
  await assert.rejects(
    requestAllPages('https://graph/p1', 'tok', async () => ({ error: 'nope' })),
    /has no value collection/u,
  );
});

test('requestAllPages refuses to loop forever on a self-referential nextLink', async () => {
  await assert.rejects(
    requestAllPages('https://graph/loop', 'tok', async () => ({
      value: [1],
      '@odata.nextLink': 'https://graph/loop',
    })),
    /exceeded 100 pages/u,
  );
});
