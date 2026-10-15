import fs from 'node:fs';

export const deploymentStateSchema = 'certigo.backend.deployment-state/v1';

const shaPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^[0-9a-f]{64}$/;

function fail(message) {
  throw new Error(message);
}

function exactKeys(value, expected, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    fail(`${label} must be an object.`);
  }
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
    fail(`${label} fields must be exactly ${wanted.join(', ')}.`);
  }
}

export function validateDeploymentRelease(value, label) {
  exactKeys(
    value,
    ['blobName', 'commitSha', 'deployedAt', 'operation', 'packageSha256', 'sourceRunId'],
    label,
  );
  if (!shaPattern.test(value.commitSha ?? '')) {
    fail(`${label}.commitSha is invalid.`);
  }
  if (!digestPattern.test(value.packageSha256 ?? '')) {
    fail(`${label}.packageSha256 is invalid.`);
  }
  if (value.blobName !== `deployments/${value.commitSha}.zip`) {
    fail(`${label}.blobName does not match its commit.`);
  }
  if (!/^[1-9][0-9]{0,19}$/.test(String(value.sourceRunId ?? ''))) {
    fail(`${label}.sourceRunId is invalid.`);
  }
  if (!['release', 'promotion', 'rollback'].includes(value.operation)) {
    fail(`${label}.operation is invalid.`);
  }
  if (
    typeof value.deployedAt !== 'string'
    || Number.isNaN(Date.parse(value.deployedAt))
  ) {
    fail(`${label}.deployedAt is invalid.`);
  }
}

export function loadDeploymentState(file, environment) {
  if (!file) {
    return null;
  }
  let descriptor;
  try {
    descriptor = fs.openSync(file, 'r');
  } catch (error) {
    if (error.code === 'ENOENT') {
      return null;
    }
    throw error;
  }
  let contents;
  try {
    contents = fs.readFileSync(descriptor, 'utf8');
  } finally {
    fs.closeSync(descriptor);
  }
  if (contents.length === 0) {
    return null;
  }
  const state = JSON.parse(contents);
  exactKeys(state, ['current', 'environment', 'previous', 'schema'], 'deployment state');
  if (state.schema !== deploymentStateSchema || state.environment !== environment) {
    fail('Existing deployment state has an unexpected schema or environment.');
  }
  validateDeploymentRelease(state.current, 'deployment state.current');
  if (state.previous !== null) {
    validateDeploymentRelease(state.previous, 'deployment state.previous');
  }
  return state;
}
