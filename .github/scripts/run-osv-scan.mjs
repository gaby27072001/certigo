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

export function assertOsvScannedEveryLockfile(output, args) {
  const missing = args
    .filter((argument) => argument.startsWith('--lockfile='))
    .map((argument) => argument.slice('--lockfile='.length))
    .filter((source) => !output.includes(`Scanned ${source} file and found`));
  if (missing.length > 0) {
    throw new Error(
      `OSV-Scanner did not confirm scanning lockfiles: ${missing.join(', ')}.`,
    );
  }
}

function main() {
  const scanner = process.argv[2];
  const contractFile = process.argv[3];
  const sourceRoot = process.argv[4];
  const outputFile = process.argv[5];
  const configFile = process.argv[6];
  if (!scanner || !contractFile || !sourceRoot || !outputFile || !configFile) {
    console.error(
      'Usage: run-osv-scan.mjs <scanner> <expected-sources-json> '
      + '<source-root> <output-file> <config-file>',
    );
    process.exitCode = 2;
    return;
  }

  try {
    const contract = JSON.parse(fs.readFileSync(contractFile, 'utf8'));
    const args = buildOsvScanArguments(contract, sourceRoot, outputFile, configFile);
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
