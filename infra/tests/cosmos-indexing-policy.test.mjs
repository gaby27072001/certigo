import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);

function collectIndexingPolicies(value, policies = []) {
  if (value === null || typeof value !== 'object') {
    return policies;
  }
  if (Object.hasOwn(value, 'indexingPolicy')) {
    policies.push(value.indexingPolicy);
  }
  for (const child of Object.values(value)) {
    collectIndexingPolicies(child, policies);
  }
  return policies;
}

test('Cosmos containers preserve the live default indexing policy', () => {
  const bicep = process.env.BICEP_CLI || 'bicep';
  const template = JSON.parse(
    execFileSync(
      bicep,
      ['build', path.join(repositoryRoot, 'infra', 'main.bicep'), '--stdout'],
      { encoding: 'utf8' },
    ),
  );

  assert.deepEqual(collectIndexingPolicies(template), [
    {
      indexingMode: 'consistent',
      automatic: true,
      includedPaths: [{ path: '/*' }],
      excludedPaths: [{ path: '/"_etag"/?' }],
    },
  ]);
});
