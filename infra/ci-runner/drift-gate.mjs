#!/usr/bin/env node
// Turns a reconcile-drift.mjs report into a pass/fail verdict.
//
// reconcile-drift.mjs deliberately never exits non-zero: it prints a report and
// stops. Wiring it to a scheduled workflow therefore needs something that reads
// the report and decides. That decision lives here, and not in the detector,
// because changing a finding's severity would change the detector's contract and
// the tests that pin it.
import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

function requireText(value, field, index) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(
      `drift-gate policy entry ${index}: ${field} must be a non-empty string`,
    );
  }
  return value;
}

export function readPolicy(policy) {
  const entries = policy?.acknowledgedFindings;
  if (!Array.isArray(entries)) {
    throw new Error('drift-gate policy must declare acknowledgedFindings');
  }
  const byCode = new Map();
  entries.forEach((entry, index) => {
    const code = requireText(entry?.code, 'code', index);
    // A tolerated finding without a written reason reads as an arbitrary
    // dispensation and gets deleted by whoever finds it next; one without an
    // invalidation condition can never become false again.
    requireText(entry?.reason, 'reason', index);
    requireText(entry?.invalidatedWhen, 'invalidatedWhen', index);
    if (byCode.has(code)) {
      throw new Error(`drift-gate policy: duplicate acknowledgement ${code}`);
    }
    byCode.set(code, entry);
  });
  return byCode;
}

export function evaluateDriftGate(report, policy) {
  const acknowledgedByCode = readPolicy(policy);
  const findings = Array.isArray(report?.findings) ? report.findings : [];
  const blockingFindings = findings.filter(
    (finding) => finding?.severity === 'blocking',
  );
  const blocking = blockingFindings.filter(
    (finding) => !acknowledgedByCode.has(finding.code),
  );
  const acknowledged = blockingFindings.filter((finding) =>
    acknowledgedByCode.has(finding.code),
  );
  const informational = findings.filter(
    (finding) => finding?.severity !== 'blocking',
  );
  const reportedCodes = new Set(findings.map((finding) => finding?.code));
  const stale = [...acknowledgedByCode.values()].filter(
    (entry) => !reportedCodes.has(entry.code),
  );

  return {
    blocking,
    acknowledged,
    informational,
    stale,
    ok: blocking.length === 0 && stale.length === 0,
  };
}

function parseArguments(argv) {
  const result = {};
  for (let index = 0; index < argv.length; index += 2) {
    result[argv[index]] = argv[index + 1];
  }
  return result;
}

function render(verdict, acknowledgedByCode) {
  const lines = [];
  for (const finding of verdict.blocking) {
    lines.push(`BLOCKING ${finding.code}: ${finding.detail}`);
  }
  for (const entry of verdict.stale) {
    lines.push(
      `STALE ACKNOWLEDGEMENT ${entry.code}: the detector no longer reports it. ` +
        `Remove the entry from drift-gate.policy.json. Condition on file: ${entry.invalidatedWhen}`,
    );
  }
  for (const finding of verdict.acknowledged) {
    const entry = acknowledgedByCode.get(finding.code);
    lines.push(
      `acknowledged ${finding.code}: ${finding.detail} -- tolerated because ${entry.reason}`,
    );
  }
  for (const finding of verdict.informational) {
    lines.push(`informational ${finding.code}: ${finding.detail}`);
  }
  return lines;
}

const isMain =
  process.argv[1] &&
  import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href;

if (isMain) {
  const args = parseArguments(process.argv.slice(2));
  for (const argument of ['--report', '--policy']) {
    if (!args[argument]) {
      throw new Error(`Missing ${argument}`);
    }
  }
  const report = JSON.parse(fs.readFileSync(args['--report'], 'utf8'));
  const policy = JSON.parse(fs.readFileSync(args['--policy'], 'utf8'));
  const verdict = evaluateDriftGate(report, policy);
  for (const line of render(verdict, readPolicy(policy))) {
    process.stdout.write(`${line}\n`);
  }
  process.stdout.write(
    `drift gate: ${verdict.blocking.length} blocking, ${verdict.stale.length} stale, ` +
      `${verdict.acknowledged.length} acknowledged, ${verdict.informational.length} informational\n`,
  );
  process.exitCode = verdict.ok ? 0 : 1;
}
