#!/usr/bin/env node

import process from 'node:process';

import { loadDeploymentState } from './backend-deployment-state.mjs';

const shaPattern = /^[0-9a-f]{40}$/;
const digestPattern = /^[0-9a-f]{64}$/;

function fail(message) {
  throw new Error(message);
}

function readArguments(argv) {
  const values = new Map();
  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    const value = argv[index + 1];
    if (!name?.startsWith('--') || value === undefined) {
      fail('Expected named arguments with values.');
    }
    values.set(name.slice(2), value);
  }
  return values;
}

function requireEnvironment(name, pattern) {
  const value = process.env[name] ?? '';
  if (!pattern.test(value)) {
    fail(`${name} is invalid.`);
  }
  return value;
}

function main() {
  const args = readArguments(process.argv.slice(2));
  const file = args.get('state') ?? '';
  const environment = args.get('environment') ?? '';
  const slot = args.get('slot') ?? '';
  if (!/^(dev|staging|prod)$/.test(environment)) {
    fail('--environment must be dev, staging or prod.');
  }
  if (!/^(current|previous)$/.test(slot)) {
    fail('--slot must be current or previous.');
  }

  const state = loadDeploymentState(file, environment);
  if (!state) {
    fail(`No deployment state exists for ${environment}.`);
  }
  const release = state[slot];
  if (!release) {
    fail(`Deployment state has no ${slot} release.`);
  }

  const expectedCommit = requireEnvironment('EXPECTED_COMMIT_SHA', shaPattern);
  const expectedDigest = requireEnvironment('EXPECTED_PACKAGE_SHA256', digestPattern);
  const expectedRunId = requireEnvironment('EXPECTED_SOURCE_RUN_ID', /^[1-9][0-9]{0,19}$/);
  if (
    release.commitSha !== expectedCommit
    || release.packageSha256 !== expectedDigest
    || String(release.sourceRunId) !== expectedRunId
  ) {
    fail(`Requested release does not match the ${slot} ${environment} release.`);
  }
  console.log(`Verified ${slot} release lineage for ${environment}.`);
}

try {
  main();
} catch (error) {
  console.error(`::error::${error.message}`);
  process.exitCode = 1;
}
