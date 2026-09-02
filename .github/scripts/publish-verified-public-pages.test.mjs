import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const workflowPath = new URL('../workflows/publish-verified-public-pages.yml', import.meta.url);
const workflow = await readFile(workflowPath, 'utf8');

test('keeps public Pages publication explicit, main-only and least privilege', () => {
  for (const marker of [
    'repository_dispatch:',
    'types: [publish-verified-public-pages]',
    "github.ref == 'refs/heads/main'",
    'CLIENT_PAYLOAD_JSON: ${{ toJSON(github.event.client_payload) }}',
    'persist-credentials: false',
    'enablement: false',
    'environment: github-pages',
    'pages: write',
    'id-token: write',
  ]) {
    assert.ok(workflow.includes(marker), marker);
  }
  assert.match(workflow, /type == "object" and length == 0/);
  assert.doesNotMatch(workflow, /\bworkflow_dispatch:/);
});

test('requires the exact root origin before generating or uploading anything', () => {
  const gate = workflow.indexOf('public-domain-contract.mjs link-associations');
  const exactOrigin = workflow.indexOf(
    'PAGES_ORIGIN" != "https://certigo-app.com"',
  );
  const emptyBasePath = workflow.indexOf('-n "$PAGES_BASE_PATH"');
  const generator = workflow.indexOf('python -P tools/generate_link_associations.py');
  const builder = workflow.indexOf('node tools/build_public_pages.mjs');
  const upload = workflow.indexOf('actions/upload-pages-artifact@');

  assert.ok(gate >= 0);
  assert.ok(exactOrigin > gate);
  assert.ok(emptyBasePath > exactOrigin);
  assert.ok(generator > emptyBasePath);
  assert.ok(builder > generator);
  assert.ok(upload > builder);
});

test('takes app identifiers only from controlled environment variables', () => {
  for (const marker of [
    'APPLE_TEAM_ID: ${{ vars.APPLE_TEAM_ID }}',
    'MOBILE_APP_ID: ${{ vars.MOBILE_APP_ID }}',
    'ANDROID_SHA256_CERT_FINGERPRINTS: ${{ vars.ANDROID_SHA256_CERT_FINGERPRINTS }}',
    '--apple-team-id "$APPLE_TEAM_ID"',
    '--bundle-id "$MOBILE_APP_ID"',
    'generator+=(--android-sha256 "$fingerprint")',
  ]) {
    assert.ok(workflow.includes(marker), marker);
  }
  assert.doesNotMatch(workflow, /com\.certigo\.mobileapp/);
  assert.doesNotMatch(workflow, /(?:[0-9A-F]{2}:){31}[0-9A-F]{2}/);
  assert.doesNotMatch(workflow, /\$\{\{\s*secrets\./);
});

test('does not interpolate Actions expressions directly into shell programs', () => {
  const runBlocks = workflow.matchAll(/^ {8}run: \|\r?\n((?:^ {10}.*\r?\n?)*)/gm);
  for (const block of runBlocks) {
    assert.doesNotMatch(block[1], /\$\{\{/);
  }
});
