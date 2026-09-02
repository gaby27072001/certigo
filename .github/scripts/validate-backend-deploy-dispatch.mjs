import fs from 'node:fs';
import process from 'node:process';

const expectedEventType = 'promote-backend';
const sourceRunPattern = /^[1-9][0-9]{0,19}$/;
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

function main() {
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
  main();
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
