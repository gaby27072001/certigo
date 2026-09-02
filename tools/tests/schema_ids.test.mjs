import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const schemas = new Map([
  ['content/schema/track.schema.json', 'urn:certigo:schema:track:v1'],
  ['content/schema/lesson.schema.json', 'urn:certigo:schema:lesson:v1'],
  [
    'docs/contracts/person-linked-identity/v1/cosmos.schema.json',
    'urn:certigo:contract:person-linked-identity:cosmos:v1',
  ],
]);

test('repository schemas use stable DNS-independent identifiers', async () => {
  for (const [path, expectedId] of schemas) {
    const schema = JSON.parse(await readFile(path, 'utf8'));
    assert.equal(schema.$id, expectedId, path);
  }
});
