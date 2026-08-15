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

export function evaluateOsvJson(file) {
  if (!fs.existsSync(file) || fs.statSync(file).size === 0) {
    throw new Error('OSV-Scanner did not produce JSON output.');
  }

  let report;
  try {
    report = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    throw new Error(
      `OSV-Scanner produced invalid JSON: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
  if (
    typeof report !== 'object'
    || report === null
    || Array.isArray(report)
    || !Array.isArray(report.results)
  ) {
    throw new Error('OSV-Scanner JSON must contain a results array.');
  }

  let packageCount = 0;
  let vulnerabilityCount = 0;
  const vulnerabilityIds = new Set();
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

    for (const [packageIndex, packageResult] of result.packages.entries()) {
      const packageSource = `${source}.packages[${packageIndex}]`;
      if (
        typeof packageResult !== 'object'
        || packageResult === null
        || Array.isArray(packageResult)
        || typeof packageResult.package !== 'object'
        || packageResult.package === null
        || Array.isArray(packageResult.package)
        || !Array.isArray(packageResult.vulnerabilities)
        || !Array.isArray(packageResult.groups)
      ) {
        throw new Error(
          `${packageSource} must contain package, vulnerabilities, and groups fields.`,
        );
      }
      requiredString(packageResult.package.name, `${packageSource}.package.name`);
      requiredString(packageResult.package.version, `${packageSource}.package.version`);
      requiredString(packageResult.package.ecosystem, `${packageSource}.package.ecosystem`);

      const packageVulnerabilityIds = new Set();
      for (const [vulnerabilityIndex, vulnerability] of
        packageResult.vulnerabilities.entries()) {
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
      for (const [groupIndex, group] of packageResult.groups.entries()) {
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
        packageResult.vulnerabilities.length > 0
        && packageResult.groups.length === 0
      ) {
        throw new Error(`${packageSource} contains ungrouped vulnerabilities.`);
      }
      packageCount += 1;
      vulnerabilityCount += packageResult.groups.length;
    }
  }

  return {
    resultCount: report.results.length,
    packageCount,
    vulnerabilityCount,
    vulnerabilityIds: [...vulnerabilityIds].sort(),
  };
}

function main() {
  const file = process.argv[2];
  if (!file) {
    console.error('Usage: enforce-osv-json.mjs <osv-json-file>');
    process.exitCode = 2;
    return;
  }
  try {
    const evaluation = evaluateOsvJson(file);
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
