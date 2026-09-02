import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
let cosmosTemplate;
const cosmosContract = JSON.parse(
  readFileSync(
    path.join(repositoryRoot, 'contracts', 'cosmos-containers.json'),
    'utf8',
  ),
);

function compileCosmosTemplate() {
  if (cosmosTemplate) {
    return cosmosTemplate;
  }
  const bicep = process.env.BICEP_CLI || 'bicep';
  cosmosTemplate = JSON.parse(
    execFileSync(
      bicep,
      [
        'build',
        path.join(repositoryRoot, 'infra', 'modules', 'cosmos.bicep'),
        '--stdout',
      ],
      { encoding: 'utf8' },
    ),
  );
  return cosmosTemplate;
}

test('Cosmos containers preserve the live default indexing policy', () => {
  const template = compileCosmosTemplate();
  const containerResource = template.resources.find(
    (resource) =>
      resource.type ===
      'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers',
  );
  assert.ok(containerResource);

  const compiledResource = containerResource.properties.resource;
  const indexingPolicy =
    "'indexingPolicy', createObject('indexingMode', 'consistent', " +
    "'automatic', true(), 'includedPaths', " +
    "createArray(createObject('path', '/*')), 'excludedPaths', " +
    "createArray(createObject('path', '/\"_etag\"/?')))";
  assert.ok(compiledResource.includes(indexingPolicy));
});

test('compiled Cosmos ARM preserves container topology and TTL scope', () => {
  const template = compileCosmosTemplate();
  const containerResource = template.resources.find(
    (resource) =>
      resource.type ===
      'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers',
  );
  assert.ok(containerResource);

  const embeddedContract = Object.values(template.variables).find(
    (value) => value?.schema === cosmosContract.schema,
  );
  assert.ok(embeddedContract);
  assert.deepEqual(embeddedContract, cosmosContract);
  assert.match(
    template.variables.containers,
    /^\[variables\('[^']+'\)\.containers\]$/,
  );

  const compiledResource = containerResource.properties.resource;
  assert.equal(typeof compiledResource, 'string');
  assert.match(
    compiledResource,
    /defaultTimeToLive.*createObject\('defaultTtl'.*defaultTimeToLive/,
  );
  assert.equal(compiledResource.match(/defaultTtl/g)?.length, 1);
  assert.doesNotMatch(JSON.stringify(template), /"defaultTtl":null/);
});
