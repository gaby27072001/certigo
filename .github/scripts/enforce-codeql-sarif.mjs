#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

function sarifFiles(root) {
  if (!fs.existsSync(root)) {
    return [];
  }
  const pending = [root];
  const files = [];
  while (pending.length > 0) {
    const current = pending.pop();
    const stat = fs.statSync(current);
    if (stat.isDirectory()) {
      for (const entry of fs.readdirSync(current)) {
        pending.push(path.join(current, entry));
      }
    } else if (current.endsWith('.sarif')) {
      files.push(current);
    }
  }
  return files.sort();
}

function rulesById(run) {
  const rules = [
    ...(run.tool?.driver?.rules ?? []),
    ...(run.tool?.extensions ?? []).flatMap((extension) => extension.rules ?? []),
  ];
  return new Map(rules.filter((rule) => rule.id).map((rule) => [rule.id, rule]));
}

function numericSeverity(result, rule) {
  const raw =
    result.properties?.['security-severity'] ?? rule?.properties?.['security-severity'];
  if (raw === undefined) {
    return null;
  }
  if (
    (typeof raw === 'string' && !/^(?:10(?:\.0+)?|[0-9](?:\.[0-9]+)?)$/.test(raw)) ||
    (typeof raw !== 'string' && typeof raw !== 'number')
  ) {
    throw new Error(`Invalid security-severity '${raw}' for rule ${result.ruleId ?? 'unknown'}.`);
  }
  const value = Number(raw);
  if (!Number.isFinite(value) || value < 0 || value > 10) {
    throw new Error(`Invalid security-severity '${raw}' for rule ${result.ruleId ?? 'unknown'}.`);
  }
  return value;
}

function messageText(message) {
  if (typeof message === 'string') {
    return message;
  }
  return message?.text ?? message?.markdown ?? '';
}

function resultLocation(result) {
  const location = result.locations?.[0]?.physicalLocation;
  return {
    path: location?.artifactLocation?.uri ?? '',
    line: location?.region?.startLine ?? null,
  };
}

export function evaluateSarif(directory, threshold) {
  if (!Number.isFinite(threshold) || threshold < 0 || threshold > 10) {
    throw new Error('The blocking threshold must be a number between 0 and 10.');
  }

  const files = sarifFiles(directory);
  if (files.length === 0) {
    throw new Error(`No SARIF files found under ${directory}.`);
  }

  const findings = [];
  for (const file of files) {
    const sarif = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (
      sarif.version !== '2.1.0' ||
      !Array.isArray(sarif.runs) ||
      sarif.runs.length === 0
    ) {
      throw new Error(`${file} is not a supported SARIF 2.1.0 document.`);
    }
    for (const run of sarif.runs) {
      if (
        typeof run.tool?.driver?.name !== 'string' ||
        run.tool.driver.name.length === 0
      ) {
        throw new Error(`${file}: SARIF run is missing tool.driver.name.`);
      }
      if (run.results !== undefined && !Array.isArray(run.results)) {
        throw new Error(`${file}: SARIF run results must be an array.`);
      }
      for (const result of run.results ?? []) {
        if (
          typeof result.message !== 'object' ||
          result.message === null ||
          (typeof result.message.text !== 'string' &&
            typeof result.message.markdown !== 'string')
        ) {
          throw new Error(`${file}: SARIF result is missing a valid message.`);
        }
      }
      const rules = rulesById(run);
      for (const result of run.results ?? []) {
        const rule = rules.get(result.ruleId);
        const securitySeverity = numericSeverity(result, rule);
        const level = result.level ?? rule?.defaultConfiguration?.level ?? 'warning';
        const location = resultLocation(result);
        findings.push({
          blocking:
            securitySeverity !== null ? securitySeverity >= threshold : level === 'error',
          level,
          securitySeverity,
          ruleId: result.ruleId ?? rule?.id ?? 'unknown',
          message: messageText(result.message),
          path: location.path,
          line: location.line,
          sarif: path.relative(directory, file),
        });
      }
    }
  }
  return { files, findings };
}

function main() {
  const directory = process.argv[2];
  if (!directory) {
    console.error('Usage: enforce-codeql-sarif.mjs <sarif-directory>');
    process.exitCode = 2;
    return;
  }

  const threshold = Number(process.env.CODEQL_BLOCKING_SECURITY_SEVERITY ?? '7.0');
  try {
    const evaluation = evaluateSarif(directory, threshold);
    const blocking = evaluation.findings.filter((finding) => finding.blocking);
    console.log(
      `Evaluated ${evaluation.findings.length} CodeQL finding(s) from ` +
        `${evaluation.files.length} SARIF file(s); blocking threshold=${threshold}.`,
    );
    for (const finding of evaluation.findings) {
      console.log(JSON.stringify(finding));
    }
    if (blocking.length > 0) {
      console.error(
        `${blocking.length} CodeQL finding(s) meet the blocking severity threshold.`,
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
