import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

import {
  deploymentStateSchema,
  loadDeploymentState,
  validateDeploymentRelease,
} from './backend-deployment-state.mjs';

const shaPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^[0-9a-f]{64}$/;

function fail(message) {
  throw new Error(message);
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
  validateDeploymentRelease(current, 'current release');

  const existing = loadDeploymentState(args.previous, environment);
  const sameRelease = existing
    && existing.current.commitSha === current.commitSha
    && existing.current.packageSha256 === current.packageSha256;
  const state = {
    schema: deploymentStateSchema,
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
