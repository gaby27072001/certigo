import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';

import { evaluateSarif } from './enforce-codeql-sarif.mjs';

function fixture(results, rules = []) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-codeql-sarif-'));
  fs.writeFileSync(
    path.join(directory, 'results.sarif'),
    JSON.stringify({
      version: '2.1.0',
      runs: [
        {
          tool: { driver: { name: 'CodeQL', rules } },
          results: results.map((result) => ({
            message: { text: 'Finding' },
            ...result,
          })),
        },
      ],
    }),
  );
  return directory;
}

test('blocks high and critical security findings', () => {
  const directory = fixture(
    [{ ruleId: 'high', message: { text: 'High finding' } }],
    [{ id: 'high', properties: { 'security-severity': '8.1' } }],
  );
  assert.equal(evaluateSarif(directory, 7).findings[0].blocking, true);
});

test('retains but does not block medium security findings', () => {
  const directory = fixture(
    [{ ruleId: 'medium', message: { text: 'Medium finding' } }],
    [{ id: 'medium', properties: { 'security-severity': '6.9' } }],
  );
  const finding = evaluateSarif(directory, 7).findings[0];
  assert.equal(finding.blocking, false);
  assert.equal(finding.message, 'Medium finding');
});

test('blocks SARIF errors without a numeric security severity', () => {
  const directory = fixture([{ ruleId: 'error', level: 'error' }]);
  assert.equal(evaluateSarif(directory, 7).findings[0].blocking, true);
});

test('fails closed when no SARIF is available', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-codeql-empty-'));
  assert.throws(() => evaluateSarif(directory, 7), /No SARIF files found/);
});

test('rejects malformed severity metadata', () => {
  const directory = fixture(
    [{ ruleId: 'invalid' }],
    [{ id: 'invalid', properties: { 'security-severity': 'urgent' } }],
  );
  assert.throws(() => evaluateSarif(directory, 7), /Invalid security-severity/);
});

test('rejects empty severity metadata instead of treating it as zero', () => {
  for (const severity of ['', '   ']) {
    const directory = fixture(
      [{ ruleId: 'invalid', level: 'error' }],
      [{ id: 'invalid', properties: { 'security-severity': severity } }],
    );
    assert.throws(() => evaluateSarif(directory, 7), /Invalid security-severity/);
  }
});

test('rejects structurally invalid SARIF runs', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-codeql-invalid-'));
  fs.writeFileSync(
    path.join(directory, 'results.sarif'),
    JSON.stringify({
      version: '2.1.0',
      runs: [{ results: [] }],
    }),
  );
  assert.throws(() => evaluateSarif(directory, 7), /missing tool\.driver\.name/);
});

test('rejects invalid result level values and types', () => {
  for (const level of ['fatal', '', 3, { value: 'error' }]) {
    const directory = fixture([{ ruleId: 'invalid-level', level }]);
    assert.throws(() => evaluateSarif(directory, 7), /SARIF level .* is invalid/);
  }
});

test('rejects an invalid default rule level', () => {
  const directory = fixture(
    [{ ruleId: 'invalid-default-level' }],
    [
      {
        id: 'invalid-default-level',
        defaultConfiguration: { level: 'fatal' },
      },
    ],
  );
  assert.throws(() => evaluateSarif(directory, 7), /SARIF level 'fatal' is invalid/);
});
