// Detection for finding R-05 (secret expiry) and the security posture invariants
// confirmed on 2026-09-04: security defaults enforce administrator MFA in the CIAM
// tenant, and security defaults accept no exclusions, so the break-glass account must
// keep a usable strong authentication method registered at all times.

const GRAPH = 'https://graph.microsoft.com/v1.0';
const TOKEN_HOST = 'https://login.microsoftonline.com';

// Password-only accounts cannot satisfy the administrator MFA that security defaults
// impose, so they are deliberately absent from this list.
const STRONG_METHOD_TYPES = new Set([
  '#microsoft.graph.fido2AuthenticationMethod',
  '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod',
  '#microsoft.graph.softwareOathAuthenticationMethod',
  '#microsoft.graph.phoneAuthenticationMethod',
  '#microsoft.graph.temporaryAccessPassAuthenticationMethod',
  '#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod',
]);

export function daysUntil(expiry, now) {
  const end = Date.parse(expiry);
  if (Number.isNaN(end)) {
    return null;
  }
  return Math.floor((end - now.getTime()) / 86_400_000);
}

export function collectCredentials(applications) {
  const rows = [];
  for (const app of applications ?? []) {
    for (const [kind, list] of [
      ['secret', app.passwordCredentials ?? []],
      ['certificate', app.keyCredentials ?? []],
    ]) {
      for (const credential of list) {
        rows.push({
          application: app.displayName ?? '(unnamed)',
          appId: app.appId ?? '(unknown)',
          kind,
          name: credential.displayName ?? '(unnamed)',
          keyId: credential.keyId ?? '(unknown)',
          endDateTime: credential.endDateTime ?? null,
        });
      }
    }
  }
  return rows;
}

export function evaluatePosture({
  applications = [],
  securityDefaults = null,
  breakGlassMethods = null,
  breakGlassUpn = '(unset)',
  thresholdDays = 90,
  now = new Date(),
}) {
  const findings = [];
  const credentials = collectCredentials(applications).map((credential) => ({
    ...credential,
    daysRemaining: credential.endDateTime
      ? daysUntil(credential.endDateTime, now)
      : null,
  }));

  // An empty application list and a tenant with nothing to report are
  // indistinguishable in the output, so absence is treated as a failed read rather
  // than a clean result. A directory always holds at least one application, so zero
  // means the query did not really answer -- a silently narrowed permission, a
  // filtered response, or the wrong tenant.
  if (applications.length === 0) {
    findings.push({
      severity: 'error',
      code: 'APPLICATION_LIST_EMPTY',
      message:
        'Microsoft Graph returned zero applications. That is not a credible tenant ' +
        'state, so it is treated as a failed read rather than "no expiring secrets".',
    });
  }

  for (const credential of credentials) {
    if (credential.daysRemaining === null) {
      findings.push({
        severity: 'warning',
        code: 'CREDENTIAL_UNPARSEABLE_EXPIRY',
        message:
          `${credential.application} / ${credential.name} (${credential.kind}) has no readable expiry`,
      });
      continue;
    }
    if (credential.daysRemaining < 0) {
      findings.push({
        severity: 'error',
        code: 'CREDENTIAL_EXPIRED',
        message:
          `${credential.application} / ${credential.name} EXPIRED ` +
          `${Math.abs(credential.daysRemaining)} day(s) ago (${credential.endDateTime})`,
      });
    } else if (credential.daysRemaining <= thresholdDays) {
      findings.push({
        severity: 'error',
        code: 'CREDENTIAL_EXPIRING',
        message:
          `${credential.application} / ${credential.name} expires in ` +
          `${credential.daysRemaining} day(s) (${credential.endDateTime}) — run runbook R-05`,
      });
    }
  }

  // Security defaults are the only mechanism enforcing administrator MFA in this
  // tenant. Silent deactivation would remove that enforcement without any other
  // control taking over, so drift is treated as an error rather than a warning.
  if (securityDefaults === null) {
    findings.push({
      severity: 'error',
      code: 'SECURITY_DEFAULTS_UNREADABLE',
      message: 'Could not read identitySecurityDefaultsEnforcementPolicy',
    });
  } else if (securityDefaults.isEnabled !== true) {
    findings.push({
      severity: 'error',
      code: 'SECURITY_DEFAULTS_DISABLED',
      message:
        'Security defaults are DISABLED — administrator MFA is no longer enforced. ' +
        'Either re-enable them or introduce Conditional Access with a break-glass exclusion.',
    });
  }

  if (breakGlassMethods === null) {
    findings.push({
      severity: 'error',
      code: 'BREAK_GLASS_UNREADABLE',
      message: `Could not read authentication methods for ${breakGlassUpn}`,
    });
  } else {
    const strong = breakGlassMethods.filter((method) =>
      STRONG_METHOD_TYPES.has(method['@odata.type']),
    );
    if (strong.length === 0) {
      findings.push({
        severity: 'error',
        code: 'BREAK_GLASS_NO_STRONG_METHOD',
        message:
          `${breakGlassUpn} has no strong authentication method registered. ` +
          'Security defaults require administrator MFA and accept no exclusions, so this ' +
          'account cannot be relied on in an emergency. See runbook R-04.',
      });
    }
  }

  return {
    findings,
    credentials,
    failed: findings.some((finding) => finding.severity === 'error'),
  };
}

export function renderSummary({ findings, credentials, thresholdDays }) {
  const sorted = [...credentials].sort(
    (a, b) => (a.daysRemaining ?? Infinity) - (b.daysRemaining ?? Infinity),
  );
  const credentialRows = sorted.length === 0
    ? '| _none_ | | | |\n'
    : sorted
      .map((credential) =>
        `| \`${credential.application}\` | ${credential.name} | ${credential.kind} | ` +
        `${credential.daysRemaining ?? 'unknown'} |`)
      .join('\n') + '\n';
  const findingRows = findings.length === 0
    ? '| _none_ | | |\n'
    : findings
      .map((finding) =>
        `| ${finding.severity} | \`${finding.code}\` | ${finding.message} |`)
      .join('\n') + '\n';

  return (
    '## CIAM posture monitor\n\n' +
    `Alert threshold: **${thresholdDays} days**.\n\n` +
    '### Credentials\n\n' +
    '| Application | Credential | Kind | Days remaining |\n|---|---|---|---|\n' +
    credentialRows +
    '\n### Findings\n\n' +
    '| Severity | Code | Detail |\n|---|---|---|\n' +
    findingRows
  );
}

async function requestJson(url, token) {
  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}`, Accept: 'application/json' },
  });
  if (!response.ok) {
    throw new Error(`${url} -> HTTP ${response.status}`);
  }
  return response.json();
}

// Microsoft Graph paginates collections. Reading only the first page would leave
// later credentials unexamined while still reporting success, so every page is
// followed and any failure mid-walk propagates instead of returning a partial list.
export async function requestAllPages(url, token, fetchPage = requestJson) {
  const items = [];
  let next = url;
  let guard = 0;
  while (next) {
    if (++guard > 100) {
      throw new Error(`Graph pagination exceeded 100 pages for ${url}`);
    }
    const page = await fetchPage(next, token);
    if (!Array.isArray(page?.value)) {
      throw new Error(`Graph response for ${next} has no value collection`);
    }
    items.push(...page.value);
    next = page['@odata.nextLink'] ?? null;
  }
  return items;
}

async function acquireGraphToken({ tenantId, clientId }) {
  const requestUrl = process.env.ACTIONS_ID_TOKEN_REQUEST_URL;
  const requestToken = process.env.ACTIONS_ID_TOKEN_REQUEST_TOKEN;
  if (!requestUrl || !requestToken) {
    throw new Error('GitHub OIDC is unavailable; the job needs id-token: write');
  }
  const oidcResponse = await fetch(
    `${requestUrl}&audience=${encodeURIComponent('api://AzureADTokenExchange')}`,
    { headers: { Authorization: `Bearer ${requestToken}` } },
  );
  if (!oidcResponse.ok) {
    throw new Error(`GitHub OIDC request failed: HTTP ${oidcResponse.status}`);
  }
  const assertion = (await oidcResponse.json()).value;

  // Federated credentials carry no stored secret, so nothing here can silently expire
  // the way the app-registration secrets tracked by this job do.
  const tokenResponse = await fetch(`${TOKEN_HOST}/${tenantId}/oauth2/v2.0/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      scope: 'https://graph.microsoft.com/.default',
      grant_type: 'client_credentials',
      client_assertion_type:
        'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
      client_assertion: assertion,
    }),
  });
  if (!tokenResponse.ok) {
    throw new Error(`Graph token exchange failed: HTTP ${tokenResponse.status}`);
  }
  return (await tokenResponse.json()).access_token;
}

async function main() {
  const tenantId = process.env.AZURE_TENANT_ID;
  const clientId = process.env.AZURE_CLIENT_ID;
  const breakGlassUpn = process.env.CIAM_BREAK_GLASS_UPN;
  const thresholdDays = Number.parseInt(process.env.THRESHOLD_DAYS ?? '90', 10);
  for (const [name, value] of Object.entries({
    AZURE_TENANT_ID: tenantId,
    AZURE_CLIENT_ID: clientId,
    CIAM_BREAK_GLASS_UPN: breakGlassUpn,
  })) {
    if (!value) {
      throw new Error(`Missing required configuration ${name}`);
    }
  }
  if (!Number.isInteger(thresholdDays) || thresholdDays <= 0) {
    throw new Error('THRESHOLD_DAYS must be a positive integer');
  }

  const token = await acquireGraphToken({ tenantId, clientId });
  const applications = await requestAllPages(
    `${GRAPH}/applications?$select=appId,displayName,passwordCredentials,keyCredentials`,
    token,
  );

  let securityDefaults = null;
  try {
    securityDefaults = await requestJson(
      `${GRAPH}/policies/identitySecurityDefaultsEnforcementPolicy`,
      token,
    );
  } catch (error) {
    console.error(`security defaults read failed: ${error.message}`);
  }

  let breakGlassMethods = null;
  try {
    breakGlassMethods = await requestAllPages(
      `${GRAPH}/users/${encodeURIComponent(breakGlassUpn)}/authentication/methods`,
      token,
    );
  } catch (error) {
    console.error(`break-glass methods read failed: ${error.message}`);
  }

  const result = evaluatePosture({
    applications,
    securityDefaults,
    breakGlassMethods,
    breakGlassUpn,
    thresholdDays,
  });
  const summary = renderSummary({ ...result, thresholdDays });
  console.log(summary);
  if (process.env.GITHUB_STEP_SUMMARY) {
    const { appendFileSync } = await import('node:fs');
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, summary);
  }
  if (process.env.GITHUB_OUTPUT) {
    const { appendFileSync } = await import('node:fs');
    const body = result.findings
      .map((finding) => `- **${finding.severity}** \`${finding.code}\` — ${finding.message}`)
      .join('\n');
    appendFileSync(
      process.env.GITHUB_OUTPUT,
      `failed=${result.failed}\nfindings<<CERTIGO_EOF\n${body}\nCERTIGO_EOF\n`,
    );
  }
  if (result.failed) {
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === `file://${process.argv[1].replace(/\\/gu, '/')}`) {
  main().catch((error) => {
    console.error(`::error::${error.message}`);
    process.exitCode = 1;
  });
}
