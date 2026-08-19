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
let cosmosTemplate;

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

test('compiled Cosmos ARM emits TTL only for attempts', () => {
  const template = compileCosmosTemplate();
  const containerResource = template.resources.find(
    (resource) =>
      resource.type ===
      'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers',
  );
  assert.ok(containerResource);

  const containers = template.variables.containers;
  assert.deepEqual(containers, [
    { name: 'users', pk: '/id' },
    { name: 'content', pk: '/trackId' },
    { name: 'content-public', pk: '/releaseId' },
    { name: 'content-private', pk: '/releaseId' },
    { name: 'content-control', pk: '/scope' },
    { name: 'progress', pk: '/userId' },
    { name: 'attempts', pk: '/userId' },
    { name: 'events', pk: '/userId' },
    { name: 'leaderboard', pk: '/periodLeagueId' },
    { name: 'economy', pk: '/userId' },
    { name: 'friends', pk: '/userId' },
  ]);

  const compiledResource = containerResource.properties.resource;
  assert.equal(typeof compiledResource, 'string');
  const ttlCondition =
    "if(equals(variables('containers')[copyIndex()].name, 'attempts'), " +
    "createObject('defaultTtl', -1), createObject())";
  assert.ok(compiledResource.endsWith(`${ttlCondition})]`));
  assert.equal(compiledResource.match(/defaultTtl/g)?.length, 1);
  assert.doesNotMatch(JSON.stringify(template), /"defaultTtl":null/);
});
