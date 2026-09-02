import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import { evaluateOsvJson } from './enforce-osv-json.mjs';

const fixtureRoot = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'fixtures',
);

test('accepts a complete clean OSV JSON fixture', () => {
  assert.deepEqual(evaluateOsvJson(path.join(fixtureRoot, 'osv-clean.json')), {
    resultCount: 0,
    sourceCount: 0,
    packageCount: 0,
    vulnerabilityCount: 0,
    vulnerabilityIds: [],
  });
});

test('accepts a package with a complete package identity', () => {
  assert.deepEqual(
    evaluateOsvJson(path.join(fixtureRoot, 'osv-valid-package.json')),
    {
      resultCount: 1,
      sourceCount: 0,
      packageCount: 1,
      vulnerabilityCount: 0,
      vulnerabilityIds: [],
    },
  );
});

test('rejects a package with an empty ecosystem', () => {
  assert.throws(
    () => evaluateOsvJson(path.join(fixtureRoot, 'osv-empty-ecosystem.json')),
    /package\.ecosystem must be a non-empty string/u,
  );
});

test('counts grouped vulnerabilities from a complete OSV JSON fixture', () => {
  assert.deepEqual(
    evaluateOsvJson(path.join(fixtureRoot, 'osv-vulnerable.json')),
    {
      resultCount: 1,
      sourceCount: 0,
      packageCount: 1,
      vulnerabilityCount: 1,
      vulnerabilityIds: ['GHSA-example-0000-0000'],
    },
  );
});

test('rejects truncated OSV JSON output', () => {
  assert.throws(
    () => evaluateOsvJson(path.join(fixtureRoot, 'osv-truncated.json')),
    /OSV-Scanner produced invalid JSON/,
  );
});

test('rejects vulnerability groups that reference an absent advisory', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-osv-json-'));
  const file = path.join(directory, 'invalid-group.json');
  fs.writeFileSync(
    file,
    JSON.stringify({
      results: [{
        source: { path: '/workspace/package-lock.json', type: 'lockfile' },
        packages: [{
          package: { name: 'package', version: '1', ecosystem: 'npm' },
          vulnerabilities: [{ id: 'GHSA-present' }],
          groups: [{ ids: ['GHSA-absent'] }],
        }],
      }],
    }),
  );
  assert.throws(
    () => evaluateOsvJson(file),
    /references unknown vulnerability/,
  );
});

test('rejects OSV JSON with invalid nested field types', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-osv-json-'));
  const file = path.join(directory, 'invalid-types.json');
  fs.writeFileSync(
    file,
    JSON.stringify({
      results: [{
        source: { path: '/workspace/package-lock.json', type: 'lockfile' },
        packages: [{
          package: { name: 'package', version: 1, ecosystem: 'npm' },
          vulnerabilities: [],
          groups: [],
        }],
      }],
    }),
  );
  assert.throws(
    () => evaluateOsvJson(file),
    /package\.version must be a non-empty string/u,
  );
});

test('accepts only result sources from the validated lockfile contract', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-osv-sources-'));
  const lockfile = path.join(directory, 'package-lock.json');
  const file = path.join(directory, 'all-packages.json');
  fs.writeFileSync(lockfile, '{}');
  fs.writeFileSync(
    file,
    JSON.stringify({
      results: [{
        source: { path: lockfile, type: 'lockfile' },
        packages: [{
          package: { name: 'package', version: '1', ecosystem: 'npm' },
        }],
      }],
    }),
  );
  assert.deepEqual(
    evaluateOsvJson(file, {
      expectedSources: {
        sources: ['package-lock.json'],
        pubManifests: [],
      },
      sourceRoot: directory,
    }),
    {
      resultCount: 1,
      sourceCount: 1,
      packageCount: 1,
      vulnerabilityCount: 0,
      vulnerabilityIds: [],
    },
  );
  assert.throws(() => evaluateOsvJson(file, {
    expectedSources: {
      sources: ['different.lock'],
      pubManifests: [],
    },
    sourceRoot: directory,
  }), /was not present in the validated lockfile contract/u);
});

test('rejects empty versions including NuGet project references', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-osv-project-'));
  const file = path.join(directory, 'project-reference.json');
  fs.writeFileSync(
    file,
    JSON.stringify({
      results: [{
        source: { path: path.join(directory, 'packages.lock.json'), type: 'lockfile' },
        packages: [{
          package: { name: 'Certigo.Domain', version: '', ecosystem: 'NuGet' },
        }],
      }],
    }),
  );
  assert.throws(
    () => evaluateOsvJson(file, {
      expectedSources: {
        sources: ['packages.lock.json'],
        pubManifests: [],
      },
      sourceRoot: directory,
    }),
    /package\.version must be a non-empty string/u,
  );
});

test('accepts no findings when explicit lockfile invocation returns no results', () => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-osv-empty-'));
  assert.deepEqual(
    evaluateOsvJson(path.join(fixtureRoot, 'osv-clean.json'), {
      expectedSources: {
        sources: ['package-lock.json'],
        pubManifests: [],
      },
      sourceRoot: directory,
    }),
    {
      resultCount: 0,
      sourceCount: 0,
      packageCount: 0,
      vulnerabilityCount: 0,
      vulnerabilityIds: [],
    },
  );
});

test('rejects the removed empty-version exception contract', () => {
  assert.throws(
    () => evaluateOsvJson(path.join(fixtureRoot, 'osv-clean.json'), {
      expectedSources: {
        sources: ['package-lock.json'],
        pubManifests: [],
        allowedEmptyNugetPackages: ['ProjectReference'],
      },
    }),
    /allowedEmptyNugetPackages is forbidden/u,
  );
});

test('CLI exit codes distinguish clean, vulnerable, and invalid reports', () => {
  const script = path.join(path.dirname(fileURLToPath(import.meta.url)), 'enforce-osv-json.mjs');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'certigo-osv-cli-'));
  const expectedSources = path.join(directory, 'expected.json');
  fs.writeFileSync(
    expectedSources,
    '{"sources":["workspace/package-lock.json"],"pubManifests":[]}',
  );
  const cases = [
    ['osv-clean.json', 0],
    ['osv-vulnerable.json', 1],
    ['osv-truncated.json', 2],
  ];
  for (const [fixture, expectedStatus] of cases) {
    const result = spawnSync(
      process.execPath,
      [
        script,
        path.join(fixtureRoot, fixture),
        expectedSources,
        path.parse(fixtureRoot).root,
      ],
      { encoding: 'utf8' },
    );
    assert.equal(result.status, expectedStatus, `${fixture}: ${result.stderr}`);
  }
});
