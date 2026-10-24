import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import YAML from 'yaml';

const repository = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const workflow = YAML.parse(
  readFileSync(path.join(repository, '.github', 'workflows', 'security-scan.yml'), 'utf8'),
);
const scan = workflow.jobs['iac-scan'].steps.find(
  (step) => step.name === 'Run Checkov on infra/',
).run;

test('Checkov JSON and tests run only from immutable trusted controls', () => {
  assert.ok(scan.includes('--config-file "$TRUSTED_CONTROL_DIR/.checkov.yaml"'));
  assert.ok(scan.includes('python "$TRUSTED_CONTROL_DIR/.github/scripts/checkov_report_gate.py"'));
  assert.ok(scan.includes('--output cli --output json'));
  assert.ok(scan.includes('--output-file-path "console,$CHECKOV_SCAN_LOG.json"'));
  assert.doesNotMatch(scan, /(?:^|\s)(?:--quiet|-q)(?=\s|$)/m);
  assert.ok(workflow.jobs['iac-scan'].steps.some((step) => (
    step.run === 'python "$TRUSTED_CONTROL_DIR/.github/scripts/test_checkov_report_gate.py"'
  )));
  assert.ok(scan.indexOf('rm -f -- "$CHECKOV_SCAN_LOG" "$CHECKOV_SCAN_LOG.json"')
    < scan.indexOf('checkov --directory'));
  assert.ok(scan.includes('set -uo pipefail'));
});

test('actual workflow scan step rejects partial and empty scans', {
  skip: process.platform === 'win32' ? 'workflow is Linux Bash; exercised on Linux' : false,
}, () => {
  const directory = mkdtempSync(path.join(os.tmpdir(), 'certigo-checkov-gate-'));
  try {
    const bin = path.join(directory, 'bin');
    mkdirSync(bin);
    const runner = path.join(directory, 'run.sh');
    const fixture = path.join(directory, 'fixture.json');
    writeFileSync(runner, scan);
    const python = spawnSync('python3', ['--version'], { encoding: 'utf8' });
    assert.equal(python.status, 0, python.stderr);
    writeFileSync(path.join(bin, 'python'), '#!/bin/sh\nexec python3 "$@"\n', { mode: 0o755 });
    writeFileSync(path.join(bin, 'checkov'), `#!/bin/sh
set -eu
quiet=false
while [ "$#" -gt 0 ]; do
  if [ "$1" = "--quiet" ] || [ "$1" = "-q" ]; then
    quiet=true
  fi
  if [ "$1" = "--output-file-path" ]; then
    shift
    report="\${1#console,}"
  fi
  shift
done
if [ "$MOCK_JSON" != "missing" ]; then
  if [ "$quiet" = "true" ]; then
    python3 -c 'import json,sys; r=json.load(open(sys.argv[1])); r["results"]={"failed_checks":r["results"]["failed_checks"]}; json.dump(r,open(sys.argv[2],"w"))' "$MOCK_FIXTURE" "$report"
  else
    cp "$MOCK_FIXTURE" "$report"
  fi
fi
printf '%s\\n' "$MOCK_CLI"
exit "$MOCK_STATUS"
`, { mode: 0o755 });
    const record = { check_id: 'CKV_AZURE_3', file_path: '/fixture.bicep', resource: 'storage' };
    for (const scenario of [
      { name: 'complete', expected: 0 },
      { name: 'parse errors despite exit zero', errors: 22, expected: 1 },
      { name: 'zero resources', resources: 0, expected: 1 },
      { name: 'nonzero scanner', status: 2, expected: 1 },
      { name: 'failed checks despite exit zero', failed: 1, expected: 1 },
      { name: 'missing JSON despite prior successful report', json: 'missing', expected: 1 },
      { name: 'malformed JSON', json: 'malformed', expected: 1 },
      { name: 'inconsistent JSON summary', mismatch: true, expected: 1 },
      { name: 'missing CLI summary', cli: 'no summary', expected: 1 },
    ]) {
      const summary = {
        passed: 1,
        failed: scenario.failed ?? 0,
        skipped: 0,
        parsing_errors: scenario.errors ?? 0,
        resource_count: scenario.resources ?? 1,
        checkov_version: '3.2.495',
      };
      const report = {
        check_type: 'bicep',
        summary,
        results: {
          passed_checks: scenario.mismatch ? [] : [record],
          failed_checks: scenario.failed ? [record] : [],
          skipped_checks: [],
          parsing_errors: Array.from(
            { length: summary.parsing_errors }, (_, index) => `/broken-${index}.bicep`,
          ),
        },
      };
      writeFileSync(fixture, scenario.json === 'malformed' ? 'not JSON' : JSON.stringify(report));
      const log = path.join(directory, 'state', 'checkov.log');
      mkdirSync(path.dirname(log), { recursive: true });
      writeFileSync(`${log}.json`, JSON.stringify({ ...report, results: { ...report.results } }));
      const result = spawnSync('bash', [runner], {
        encoding: 'utf8',
        env: {
          ...process.env,
          PATH: `${bin}:${process.env.PATH}`,
          TRUSTED_CONTROL_DIR: repository,
          UNTRUSTED_SOURCE_DIR: path.join(directory, 'untrusted'),
          CHECKOV_SCAN_LOG: log,
          GITHUB_STEP_SUMMARY: path.join(directory, 'summary.md'),
          MOCK_FIXTURE: fixture,
          MOCK_JSON: scenario.json ?? 'valid',
          MOCK_STATUS: String(scenario.status ?? 0),
          MOCK_CLI: scenario.cli ?? (
            `Passed checks: 1, Failed checks: ${summary.failed}, Skipped checks: 0, `
            + `Parsing errors: ${summary.parsing_errors}`
          ),
        },
      });
      assert.equal(result.status, scenario.expected, `${scenario.name}\n${result.stdout}\n${result.stderr}`);
    }
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
