import assert from 'node:assert/strict';
import test from 'node:test';
import {
  collectCredentials,
  daysUntil,
  evaluatePosture,
  renderStepOutput,
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

// --- The falling edge -------------------------------------------------------
//
// Until 2026-09-07 this monitor could open its tracking issue and never close it,
// so its state converged on "broken" regardless of the tenant: an instrument whose
// output stopped depending on its input. Closing is now automatic, which introduces
// the opposite hazard — announcing "resolved" because the audit could not look.
//
// The two states below are the real runs of 2026-09-07: 12:47 UTC carried
// BREAK_GLASS_NO_STRONG_METHOD and exited 1; 16:00 UTC, after remediation, reported
// nothing. The close gate must fire on the second and not on the first.

test('the two real 2026-09-07 postures land on opposite sides of the close gate', () => {
  const beforeRemediation = evaluatePosture(healthyInputs({
    breakGlassMethods: [{ '@odata.type': '#microsoft.graph.passwordAuthenticationMethod' }],
  }));
  const afterRemediation = evaluatePosture(healthyInputs({
    breakGlassMethods: [
      { '@odata.type': '#microsoft.graph.passwordAuthenticationMethod' },
      { '@odata.type': '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod' },
    ],
  }));

  assert.deepEqual(codes(beforeRemediation), ['BREAK_GLASS_NO_STRONG_METHOD']);
  assert.equal(beforeRemediation.failed, true, 'the 12:47 run must not be closable');
  assert.deepEqual(afterRemediation.findings, []);
  assert.equal(afterRemediation.failed, false, 'the 16:00 run must be closable');
});

test('a warning-only posture is closable, matching the condition that opens the issue', () => {
  // The issue opens on error severity alone, so it must close on the absence of
  // error severity alone. Any other threshold leaves a band in which the monitor
  // neither opens nor closes, and the issue sticks for a reason nobody can read.
  const result = evaluatePosture(healthyInputs({
    applications: [application({
      passwordCredentials: [{ displayName: 'odd', keyId: 'k1', endDateTime: 'nonsense' }],
    })],
  }));
  assert.deepEqual(codes(result), ['CREDENTIAL_UNPARSEABLE_EXPIRY']);
  assert.equal(result.failed, false);
});

test('a healthy audit publishes the exact string the close gate waits for', () => {
  // Twin of the crash test below. That one proves a broken audit writes nothing;
  // this one proves a healthy audit writes `failed=false` — without it the gate
  // could never fire and the monitor would still have no falling edge, silently.
  const healthy = evaluatePosture(healthyInputs());
  const output = renderStepOutput(healthy);
  assert.ok(
    output.startsWith('failed=false\n'),
    `the close gate compares against 'false'; got: ${output.split('\n')[0]}`,
  );

  const broken = evaluatePosture(healthyInputs({
    breakGlassMethods: [{ '@odata.type': '#microsoft.graph.passwordAuthenticationMethod' }],
  }));
  assert.ok(
    renderStepOutput(broken).startsWith('failed=true\n'),
    'a failing audit must not publish a closable verdict',
  );
});

test('a crashed audit writes no failed output, so it cannot read as an all-clear', async () => {
  // The decisive case. `outcome == 'success'` would be a weak gate because a future
  // refactor that swallowed an error would turn silence into health. `failed` is
  // written only after the script reaches its conclusion, so its absence is the
  // signal. Proven here by crashing the script on purpose: missing configuration.
  const { mkdtempSync, readFileSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join, dirname } = await import('node:path');
  const { fileURLToPath } = await import('node:url');
  const { execFileSync } = await import('node:child_process');

  const script = join(dirname(fileURLToPath(import.meta.url)), 'ciam-posture-report.mjs');
  const dir = mkdtempSync(join(tmpdir(), 'ciam-posture-'));
  const outputPath = join(dir, 'github-output');

  try {
    let exitCode = 0;
    try {
      execFileSync(process.execPath, [script], {
        env: {
          PATH: process.env.PATH,
          GITHUB_OUTPUT: outputPath,
          // AZURE_TENANT_ID deliberately absent.
          AZURE_CLIENT_ID: 'c0ffee00-0000-4000-8000-000000000000',
          CIAM_BREAK_GLASS_UPN: 'breakglass@certigoapp.onmicrosoft.com',
        },
        stdio: 'pipe',
      });
    } catch (error) {
      exitCode = error.status;
    }

    assert.equal(exitCode, 1, 'a missing configuration must fail the step');

    let written = '';
    try {
      written = readFileSync(outputPath, 'utf8');
    } catch {
      written = '';
    }
    assert.equal(written, '', 'a crash must leave GITHUB_OUTPUT untouched');
    assert.ok(!written.includes('failed='), 'a crash must never publish a failed verdict');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('the close gate is wired to the failed output, not merely to step success', async () => {
  // Asserted on the workflow text, following the marker convention used by
  // validate-workflow-security.mjs, so that a later edit cannot quietly loosen the
  // gate to `outcome == 'success'` — which would close the issue on a swallowed error.
  const { readFileSync } = await import('node:fs');
  const { join, dirname } = await import('node:path');
  const { fileURLToPath } = await import('node:url');

  const workflow = readFileSync(
    join(
      dirname(fileURLToPath(import.meta.url)),
      '..',
      'workflows',
      'ciam-posture-monitor.yml',
    ),
    'utf8',
  );

  // Positive control: prove this read can see the gate that has always been there,
  // so that a missing match below means an absent gate and not an unreadable file.
  assert.ok(
    workflow.includes("if: ${{ steps.audit.outcome == 'failure' }}"),
    'expected to still see the open gate; otherwise this assertion proves nothing',
  );

  assert.ok(
    workflow.includes(
      "if: ${{ steps.audit.outcome == 'success' && steps.audit.outputs.failed == 'false' }}",
    ),
    'the close step must require both step success and an explicit failed=false verdict',
  );
  assert.ok(
    workflow.includes("state_reason: 'completed'"),
    'the close step must record why the issue was closed',
  );
  assert.ok(
    !workflow.includes("if: ${{ steps.audit.outcome == 'success' }}"),
    'closing on step success alone would treat a swallowed error as health',
  );
});
