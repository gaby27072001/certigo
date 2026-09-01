#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

function requiredString(value, source) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`${source} must be a non-empty string.`);
  }
  return value;
}

const legacyEmptyVersionField = 'allowedEmptyNugetPackages';
const legacyEmptyVersionPolicy = 'may be empty only for a validated NuGet project reference';

export function evaluateOsvJson(file, options = {}) {
  let descriptor;
  let report;
  try {
    descriptor = fs.openSync(file, 'r');
    if (fs.fstatSync(descriptor).size === 0) {
      throw new Error('OSV-Scanner did not produce JSON output.');
    }
    report = JSON.parse(fs.readFileSync(descriptor, 'utf8'));
  } catch (error) {
    if (error instanceof Error && error.message === 'OSV-Scanner did not produce JSON output.') {
      throw error;
    }
    throw new Error(
      `OSV-Scanner produced invalid JSON: ${error instanceof Error ? error.message : String(error)}`,
    );
  } finally {
    if (descriptor !== undefined) {
      fs.closeSync(descriptor);
    }
  }
  if (
    typeof report !== 'object'
    || report === null
    || Array.isArray(report)
    || !Array.isArray(report.results)
  ) {
    throw new Error('OSV-Scanner JSON must contain a results array.');
  }
  let sourceContract;
  const expectedSources = new Set();
  if (options.expectedSources !== undefined) {
    sourceContract = options.expectedSources;
    if (
      typeof sourceContract === 'object'
      && sourceContract !== null
      && Object.hasOwn(sourceContract, legacyEmptyVersionField)
    ) {
      throw new Error(
        `${legacyEmptyVersionField} is forbidden: the legacy rule that a package version `
        + `${legacyEmptyVersionPolicy} has been removed; every reported package must have a version.`,
      );
    }
    if (
      typeof sourceContract !== 'object'
      || sourceContract === null
      || Array.isArray(sourceContract)
      || !Array.isArray(sourceContract.sources)
      || !Array.isArray(sourceContract.pubManifests)
      || Object.keys(sourceContract).some(
        (key) => !['sources', 'pubManifests'].includes(key),
      )
    ) {
      throw new Error(
        'Expected OSV source contract must contain sources and pubManifests arrays only.',
      );
    }
    for (const [index, value] of sourceContract.sources.entries()) {
      const expected = requiredString(value, `expectedSources.sources[${index}]`);
      if (path.isAbsolute(expected) || expected.split(/[\\/]/u).includes('..')) {
        throw new Error(`expectedSources.sources[${index}] must be repository-relative.`);
      }
      expectedSources.add(expected.replaceAll('\\', '/'));
    }
  }

  let packageCount = 0;
  let vulnerabilityCount = 0;
  const vulnerabilityIds = new Set();
  const scannedSources = new Set();
  for (const [resultIndex, result] of report.results.entries()) {
    const source = `results[${resultIndex}]`;
    if (
      typeof result !== 'object'
      || result === null
      || Array.isArray(result)
      || typeof result.source !== 'object'
      || result.source === null
      || Array.isArray(result.source)
      || !Array.isArray(result.packages)
    ) {
      throw new Error(`${source} must contain a source object and packages array.`);
    }
    requiredString(result.source.path, `${source}.source.path`);
    requiredString(result.source.type, `${source}.source.type`);
    if (options.sourceRoot) {
      const sourceRoot = path.resolve(options.sourceRoot);
      const sourcePath = path.isAbsolute(result.source.path)
        ? path.resolve(result.source.path)
        : path.resolve(sourceRoot, result.source.path);
      const relative = path.relative(sourceRoot, sourcePath);
      if (relative.startsWith('..') || path.isAbsolute(relative)) {
        throw new Error(`${source}.source.path escapes the scanned repository.`);
      }
      const normalizedSource = relative.split(path.sep).join('/');
      if (sourceContract !== undefined && !expectedSources.has(normalizedSource)) {
        throw new Error(
          `${source}.source.path was not present in the validated lockfile contract; `
          + 'result-source mismatches can indicate omitted expected tracked lockfiles.',
        );
      }
      scannedSources.add(normalizedSource);
    }

    for (const [packageIndex, packageResult] of result.packages.entries()) {
      const packageSource = `${source}.packages[${packageIndex}]`;
      if (
        typeof packageResult !== 'object'
        || packageResult === null
        || Array.isArray(packageResult)
        || typeof packageResult.package !== 'object'
        || packageResult.package === null
        || Array.isArray(packageResult.package)
        || (
          packageResult.vulnerabilities !== undefined
          && !Array.isArray(packageResult.vulnerabilities)
        )
        || (packageResult.groups !== undefined && !Array.isArray(packageResult.groups))
      ) {
        throw new Error(
          `${packageSource} must contain a package and valid vulnerability/group arrays.`,
        );
      }
      requiredString(
        packageResult.package.name,
        `${packageSource}.package.name`,
      );
      requiredString(
        packageResult.package.version,
        `${packageSource}.package.version`,
      );
      requiredString(
        packageResult.package.ecosystem,
        `${packageSource}.package.ecosystem`,
      );

      const packageVulnerabilityIds = new Set();
      const vulnerabilities = packageResult.vulnerabilities ?? [];
      const groups = packageResult.groups ?? [];
      for (const [vulnerabilityIndex, vulnerability] of vulnerabilities.entries()) {
        if (
          typeof vulnerability !== 'object'
          || vulnerability === null
          || Array.isArray(vulnerability)
        ) {
          throw new Error(
            `${packageSource}.vulnerabilities[${vulnerabilityIndex}] must be an object.`,
          );
        }
        packageVulnerabilityIds.add(
          requiredString(
            vulnerability.id,
            `${packageSource}.vulnerabilities[${vulnerabilityIndex}].id`,
          ),
        );
      }
      for (const [groupIndex, group] of groups.entries()) {
        if (
          typeof group !== 'object'
          || group === null
          || Array.isArray(group)
          || !Array.isArray(group.ids)
          || group.ids.length === 0
        ) {
          throw new Error(`${packageSource}.groups[${groupIndex}].ids must be non-empty.`);
        }
        for (const [idIndex, id] of group.ids.entries()) {
          const vulnerabilityId = requiredString(
            id,
            `${packageSource}.groups[${groupIndex}].ids[${idIndex}]`,
          );
          if (!packageVulnerabilityIds.has(vulnerabilityId)) {
            throw new Error(
              `${packageSource}.groups[${groupIndex}] references unknown vulnerability ${vulnerabilityId}.`,
            );
          }
          vulnerabilityIds.add(vulnerabilityId);
        }
      }
      if (
        vulnerabilities.length > 0
        && groups.length === 0
      ) {
        throw new Error(`${packageSource} contains ungrouped vulnerabilities.`);
      }
      packageCount += 1;
      vulnerabilityCount += groups.length;
    }
  }
  return {
    resultCount: report.results.length,
    sourceCount: scannedSources.size,
    packageCount,
    vulnerabilityCount,
    vulnerabilityIds: [...vulnerabilityIds].sort(),
  };
}

function main() {
  const file = process.argv[2];
  const expectedSourcesFile = process.argv[3];
  const sourceRoot = process.argv[4];
  if (!file || !expectedSourcesFile || !sourceRoot) {
    console.error(
      'Usage: enforce-osv-json.mjs <osv-json-file> <expected-sources-json> <source-root>',
    );
    process.exitCode = 2;
    return;
  }
  try {
    const expectedSources = JSON.parse(fs.readFileSync(expectedSourcesFile, 'utf8'));
    const evaluation = evaluateOsvJson(file, { expectedSources, sourceRoot });
    console.log(JSON.stringify(evaluation));
    if (evaluation.vulnerabilityCount > 0) {
      console.error(
        `${evaluation.vulnerabilityCount} OSV vulnerability group(s) were detected.`,
      );
      process.exitCode = 1;
    }
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 2;
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main();
}
