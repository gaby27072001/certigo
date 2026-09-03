import fs from 'node:fs';
import process from 'node:process';

const expectedEventType = 'promote-backend';
const sourceRunPattern = /^[1-9][0-9]{0,19}$/;
const loginPattern =
  /^(?=.{1,39}$)(?!.*--)[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:_[A-Za-z0-9]+)?$/;
const allowedTargets = new Set([
  'release:dev',
  'promotion:staging',
  'promotion:prod',
  'rollback:dev',
  'rollback:staging',
  'rollback:prod',
]);

function fail(message) {
  throw new Error(message);
}

function writeOutputs(values) {
  const lines = Object.entries(values)
    .map(([name, value]) => `${name}=${value}\n`)
    .join('');
  if (process.env.GITHUB_OUTPUT) {
    fs.appendFileSync(process.env.GITHUB_OUTPUT, lines, 'utf8');
  } else {
    process.stdout.write(lines);
  }
}

function parsePayload() {
  let payload;
  try {
    payload = JSON.parse(process.env.CLIENT_PAYLOAD_JSON ?? '');
  } catch (error) {
    fail(`client_payload must be valid JSON: ${error.message}`);
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    fail('client_payload must be an object.');
  }
  const actualKeys = Object.keys(payload).sort();
  const expectedKeys = ['environment', 'operation', 'source_run_id'];
  if (JSON.stringify(actualKeys) !== JSON.stringify(expectedKeys)) {
    fail('client_payload fields must be exactly environment, operation, source_run_id.');
  }
  return payload;
}

function parseAuthorizedOperators() {
  let operators;
  try {
    operators = JSON.parse(process.env.AUTHORIZED_OPERATORS_JSON ?? '');
  } catch (error) {
    fail(`BACKEND_DEPLOY_OPERATORS must be a valid JSON array: ${error.message}`);
  }
  if (
    !Array.isArray(operators)
    || operators.length === 0
    || operators.length > 50
  ) {
    fail('BACKEND_DEPLOY_OPERATORS must contain 1-50 human GitHub logins.');
  }
  const normalized = operators.map(normalizeHumanLogin);
  if (normalized.some((operator) => operator === null)) {
    fail('BACKEND_DEPLOY_OPERATORS must contain 1-50 human GitHub logins.');
  }
  if (new Set(normalized).size !== normalized.length) {
    fail('BACKEND_DEPLOY_OPERATORS must not contain duplicate logins.');
  }
  return normalized;
}

function normalizeHumanLogin(value) {
  if (
    typeof value !== 'string'
    || !loginPattern.test(value)
    || /\[bot\]$/i.test(value)
  ) {
    return null;
  }
  return value.toLowerCase();
}

function validateOperator() {
  const senderType = process.env.EVENT_SENDER_TYPE ?? '';
  const senderLogin = normalizeHumanLogin(process.env.EVENT_SENDER_LOGIN ?? '');
  const actor = normalizeHumanLogin(process.env.EVENT_ACTOR ?? '');
  if (
    senderType !== 'User'
    || senderLogin === null
    || actor === null
    || actor !== senderLogin
  ) {
    fail('Backend deployment dispatch must come from the matching human GitHub user.');
  }
  if (!parseAuthorizedOperators().includes(actor)) {
    fail(`GitHub actor ${actor} is not an authorized backend deployment operator.`);
  }
}

async function loadEnvironment(environment) {
  const token = process.env.GITHUB_TOKEN;
  const apiUrl = process.env.GITHUB_API_URL;
  const repository = process.env.GITHUB_REPOSITORY;
  if (
    !token
    || apiUrl !== 'https://api.github.com'
    || repository !== 'gchambaud_microsoft/Certigo'
  ) {
    fail('Canonical GITHUB_TOKEN, GITHUB_API_URL and GITHUB_REPOSITORY are required.');
  }
  const response = await fetch(
    `${apiUrl}/repos/${repository}/environments/${encodeURIComponent(environment)}`,
    {
      headers: {
        Accept: 'application/vnd.github+json',
        Authorization: ['Bearer', token].join(' '),
        'X-GitHub-Api-Version': '2022-11-28',
      },
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (!response.ok) {
    fail(
      `Cannot verify GitHub Environment ${environment}: GitHub returned ${response.status}.`,
    );
  }
  return response.json();
}

function validateEnvironmentProtection(metadata, environment, actor) {
  if (metadata?.name !== environment || !Array.isArray(metadata.protection_rules)) {
    fail(`GitHub Environment ${environment} metadata is invalid.`);
  }
  const reviewerRules = metadata.protection_rules.filter(
    (rule) => rule?.type === 'required_reviewers',
  );
  if (reviewerRules.length !== 1) {
    fail(`GitHub Environment ${environment} must have one unambiguous required-reviewer rule.`);
  }
  if (reviewerRules.some((rule) => rule.prevent_self_review !== true)) {
    fail(`GitHub Environment ${environment} must prevent self-review.`);
  }
  const reviewers = reviewerRules.flatMap((rule) =>
    Array.isArray(rule.reviewers) ? rule.reviewers : [null],
  );
  const reviewerKeys = new Set();
  let hasIndependentReviewer = false;
  for (const entry of reviewers) {
    const id = entry?.reviewer?.id;
    const type = entry?.type;
    const userLogin = entry?.reviewer?.login;
    const teamSlug = entry?.reviewer?.slug;
    const validUser =
      type === 'User'
      && typeof userLogin === 'string'
      && loginPattern.test(userLogin)
      && !userLogin.includes('--')
      && !/\[bot\]$/i.test(userLogin);
    const validTeam =
      type === 'Team'
      && typeof teamSlug === 'string'
      && /^[a-z0-9](?:[a-z0-9-]{0,98}[a-z0-9])?$/.test(teamSlug);
    if (
      !Number.isSafeInteger(id)
      || id < 1
      || (!validUser && !validTeam)
    ) {
      fail(`GitHub Environment ${environment} has a malformed required reviewer.`);
    }
    const key = `${type}:${id}`;
    if (reviewerKeys.has(key)) {
      fail(`GitHub Environment ${environment} has duplicate required reviewers.`);
    }
    reviewerKeys.add(key);
    if (validTeam || userLogin.toLowerCase() !== actor.toLowerCase()) {
      hasIndependentReviewer = true;
    }
  }
  if (!hasIndependentReviewer) {
    fail(`GitHub Environment ${environment} requires a reviewer distinct from the operator.`);
  }
}

async function main() {
  if (process.env.EVENT_NAME !== 'repository_dispatch') {
    fail('Backend deployment requires repository_dispatch.');
  }
  if (process.env.EVENT_ACTION !== expectedEventType) {
    fail(`Backend deployment requires event type ${expectedEventType}.`);
  }
  if (process.env.GITHUB_REF !== 'refs/heads/main') {
    fail('Backend deployment must load the workflow from refs/heads/main.');
  }

  const payload = parsePayload();
  if (
    typeof payload.environment !== 'string'
    || typeof payload.operation !== 'string'
    || typeof payload.source_run_id !== 'string'
  ) {
    fail('environment, operation and source_run_id must all be strings.');
  }
  if (!sourceRunPattern.test(payload.source_run_id)) {
    fail('source_run_id must be a positive GitHub Actions run id.');
  }
  if (!allowedTargets.has(`${payload.operation}:${payload.environment}`)) {
    fail(
      'Allowed targets are release:dev, promotion:staging/prod and rollback:dev/staging/prod.',
    );
  }

  validateOperator();
  validateEnvironmentProtection(
    await loadEnvironment(payload.environment),
    payload.environment,
    process.env.EVENT_ACTOR ?? '',
  );

  const currentRunId = process.env.GITHUB_RUN_ID ?? '';
  if (payload.operation === 'release' && !sourceRunPattern.test(currentRunId)) {
    fail('GITHUB_RUN_ID must be a positive GitHub Actions run id for a release.');
  }
  writeOutputs({
    environment: payload.environment,
    operation: payload.operation,
    'requested-source-run-id': payload.source_run_id,
    'source-run-id':
      payload.operation === 'release' ? currentRunId : payload.source_run_id,
  });
}

try {
  await main();
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
