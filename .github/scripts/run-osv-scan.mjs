#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

function requiredString(value, source) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`${source} must be a non-empty string.`);
  }
  return value;
}

export function buildOsvScanArguments(contract, sourceRoot, outputFile, configFile) {
  if (
    typeof contract !== 'object'
    || contract === null
    || Array.isArray(contract)
    || !Array.isArray(contract.sources)
    || !Array.isArray(contract.pubManifests)
    || Object.keys(contract).some(
      (key) => !['sources', 'pubManifests'].includes(key),
    )
  ) {
    throw new Error(
      'Expected OSV source contract must contain sources and pubManifests arrays only.',
    );
  }
  if (contract.sources.length === 0) {
    throw new Error('Expected OSV source contract must contain at least one lockfile.');
  }

  const canonicalRoot = fs.realpathSync(sourceRoot);
  const lockfileArguments = contract.sources.map((value, index) => {
    const relativeSource = requiredString(value, `expectedSources.sources[${index}]`);
    if (path.isAbsolute(relativeSource) || relativeSource.split(/[\\/]/u).includes('..')) {
      throw new Error(`expectedSources.sources[${index}] must be repository-relative.`);
    }

    const source = path.resolve(canonicalRoot, relativeSource);
    const relative = path.relative(canonicalRoot, source);
    if (relative.startsWith('..') || path.isAbsolute(relative)) {
      throw new Error(`expectedSources.sources[${index}] escapes the scanned repository.`);
    }
    if (fs.lstatSync(source).isSymbolicLink() || !fs.statSync(source).isFile()) {
      throw new Error(`expectedSources.sources[${index}] must reference a regular lockfile.`);
    }
    const canonicalSource = fs.realpathSync(source);
    const canonicalRelative = path.relative(canonicalRoot, canonicalSource);
    if (canonicalRelative.startsWith('..') || path.isAbsolute(canonicalRelative)) {
      throw new Error(`expectedSources.sources[${index}] escapes the scanned repository.`);
    }
    return `--lockfile=${canonicalSource}`;
  });
  if (new Set(lockfileArguments).size !== lockfileArguments.length) {
    throw new Error('Expected OSV source contract contains duplicate lockfiles.');
  }

  return [
    'scan',
    '--format=json',
    '--no-ignore',
    `--config=${path.resolve(configFile)}`,
    '--output-file',
    path.resolve(outputFile),
    ...lockfileArguments,
  ];
}

export function parseOsvPolicyArguments(args) {
  const policy = {
    format: undefined,
    noIgnore: false,
    forbiddenArguments: new Set(),
    configFile: undefined,
    outputFile: undefined,
  };
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === '--format=json') {
      policy.format = 'json';
    } else if (argument === '--no-ignore') {
      policy.noIgnore = true;
    } else if (argument.startsWith('--forbid-argument=')) {
      policy.forbiddenArguments.add(argument.slice('--forbid-argument='.length));
    } else if (argument.startsWith('--config=')) {
      policy.configFile = argument.slice('--config='.length);
    } else if (argument === '--output-file') {
      index += 1;
      policy.outputFile = args[index];
    } else if (argument.startsWith('--output-file=')) {
      policy.outputFile = argument.slice('--output-file='.length);
    } else {
      throw new Error(`Unsupported OSV policy argument: ${argument}.`);
    }
  }
  if (policy.format !== 'json' || !policy.noIgnore) {
    throw new Error('OSV policy must require JSON output and --no-ignore.');
  }
  for (const forbidden of ['--all-packages', '--recursive']) {
    if (!policy.forbiddenArguments.has(forbidden)) {
      throw new Error(`OSV policy must forbid ${forbidden}.`);
    }
  }
  requiredString(policy.configFile, '--config');
  requiredString(policy.outputFile, '--output-file');
  return policy;
}

export function assertOsvScannedEveryLockfile(output, args) {
  const missing = args
    .filter((argument) => argument.startsWith('--lockfile='))
    .map((argument) => argument.slice('--lockfile='.length))
    .filter((source) => !output.includes(`Scanned ${source} file and found`));
  if (missing.length > 0) {
    throw new Error(
      'OSV-Scanner did not confirm scanning lockfiles and omitted expected tracked lockfiles '
      + 'from its scan confirmations: '
      + `${missing.join(', ')}.`,
    );
  }
}

function main() {
  const scanner = process.argv[2];
  const contractFile = process.argv[3];
  const sourceRoot = process.argv[4];
  if (!scanner || !contractFile || !sourceRoot) {
    console.error(
      'Usage: run-osv-scan.mjs <scanner> <expected-sources-json> '
      + '<source-root> --format=json --no-ignore '
      + '--forbid-argument=--all-packages --forbid-argument=--recursive '
      + '--config=<config-file> --output-file=<output-file>',
    );
    process.exitCode = 2;
    return;
  }

  try {
    const policy = parseOsvPolicyArguments(process.argv.slice(5));
    const contract = JSON.parse(fs.readFileSync(contractFile, 'utf8'));
    const args = buildOsvScanArguments(
      contract,
      sourceRoot,
      policy.outputFile,
      policy.configFile,
    );
    const result = spawnSync(scanner, args, {
      encoding: 'utf8',
      maxBuffer: 16 * 1024 * 1024,
    });
    process.stdout.write(result.stdout ?? '');
    process.stderr.write(result.stderr ?? '');
    if (result.error) {
      throw result.error;
    }
    if (result.status === null) {
      throw new Error(`OSV-Scanner terminated by signal ${result.signal ?? 'unknown'}.`);
    }
    if (result.status <= 1) {
      assertOsvScannedEveryLockfile(
        `${result.stdout ?? ''}\n${result.stderr ?? ''}`,
        args,
      );
    }
    process.exitCode = result.status;
  } catch (error) {
    console.error(
      `OSV-Scanner invocation rejected: ${error instanceof Error ? error.message : String(error)}`,
    );
    process.exitCode = 2;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
