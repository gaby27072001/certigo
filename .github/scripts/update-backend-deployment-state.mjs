import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const schema = 'certigo.backend.deployment-state/v1';
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

function validateRelease(value, label) {
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

function loadPrevious(file, environment) {
  if (!file || !fs.existsSync(file) || fs.statSync(file).size === 0) {
    return null;
  }
  const state = JSON.parse(fs.readFileSync(file, 'utf8'));
  exactKeys(state, ['current', 'environment', 'previous', 'schema'], 'deployment state');
  if (state.schema !== schema || state.environment !== environment) {
    fail('Existing deployment state has an unexpected schema or environment.');
  }
  validateRelease(state.current, 'deployment state.current');
  if (state.previous !== null) {
    validateRelease(state.previous, 'deployment state.previous');
  }
  return state;
}

function requireEnvironment(name, pattern) {
  const value = process.env[name] ?? '';
  if (!pattern.test(value)) {
    fail(`${name} is invalid.`);
  }
  return value;
}

function main() {
  const args = Object.fromEntries(
    process.argv.slice(2).reduce((pairs, token, index, values) => {
      if (index % 2 === 0) {
        pairs.push([token.replace(/^--/, ''), values[index + 1]]);
      }
      return pairs;
    }, []),
  );
  if (!args.output) {
    fail('--output is required.');
  }

  const environment = requireEnvironment('TARGET_ENV', /^(dev|staging|prod)$/);
  const current = {
    commitSha: requireEnvironment('COMMIT_SHA', shaPattern),
    packageSha256: requireEnvironment('PACKAGE_SHA256', digestPattern),
    blobName: requireEnvironment(
      'BLOB_NAME',
      /^deployments\/[0-9a-f]{40}\.zip$/,
    ),
    sourceRunId: Number.parseInt(
      requireEnvironment('SOURCE_RUN_ID', /^[1-9][0-9]{0,19}$/),
      10,
    ),
    operation: requireEnvironment(
      'DEPLOYMENT_OPERATION',
      /^(release|promotion|rollback)$/,
    ),
    deployedAt: requireEnvironment(
      'DEPLOYED_AT',
      /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/,
    ),
  };
  validateRelease(current, 'current release');

  const existing = loadPrevious(args.previous, environment);
  const sameRelease = existing
    && existing.current.commitSha === current.commitSha
    && existing.current.packageSha256 === current.packageSha256;
  const state = {
    schema,
    environment,
    current,
    previous: sameRelease ? existing.previous : existing?.current ?? null,
  };
  fs.writeFileSync(path.resolve(args.output), `${JSON.stringify(state, null, 2)}\n`, {
    encoding: 'utf8',
    flag: 'w',
    mode: 0o600,
  });
}

try {
  main();
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
