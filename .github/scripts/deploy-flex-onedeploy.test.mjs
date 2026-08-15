import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  chmodSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '..',
  '..',
);
const deployScript = path.join(
  repositoryRoot,
  '.github',
  'scripts',
  'deploy-flex-onedeploy.sh',
);

function writeExecutable(file, content) {
  writeFileSync(file, content, 'utf8');
  chmodSync(file, 0o755);
}

function bashPath(file) {
  return file.replaceAll('\\', '/');
}

function createHarness() {
  const root = mkdtempSync(path.join(tmpdir(), 'certigo-onedeploy-'));
  const bin = path.join(root, 'bin');
  mkdirSync(bin);
  const state = path.join(root, 'state');
  const shellState = bashPath(state);
  const packagePath = path.join(root, 'publish.zip');
  writeFileSync(packagePath, 'deterministic-package', 'utf8');

  writeExecutable(
    path.join(bin, 'az'),
    `#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  "storage account show"*)
    printf 'Disabled\\tfalse\\n'
    ;;
  "resource show"*)
    printf 'UserAssignedIdentity\\thttps://stcertigodev.blob.core.windows.net/app-package\\t/subscriptions/test/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-functions\\n'
    ;;
  "network private-endpoint show"*)
    printf '/subscriptions/test/resourceGroups/rg/providers/Microsoft.Network/networkInterfaces/blob-nic\\n'
    ;;
  "network nic show"*)
    printf '10.60.0.68\\n'
    ;;
  "storage blob upload"*)
    [[ "$*" == *"--auth-mode login"* ]]
    [[ "$*" == *"--overwrite false"* ]]
    [[ "$*" == *"deployments/0123456789abcdef0123456789abcdef01234567.zip"* ]]
    ;;
  "storage blob generate-sas"*)
    [[ "$*" == *"--as-user"* ]]
    [[ "$*" == *"--permissions r"* ]]
    [[ "$*" == *"--https-only"* ]]
    printf 'sv=mock&spr=https&sp=r&sig=masked-test-token\\n'
    ;;
  "webapp log deployment list"*)
    if [[ ! -f "${shellState}" ]]; then
      printf 'baseline-deployment\\n'
    elif [[ "$*" == *"id=='new-deployment'"* ]]; then
      printf 'new-deployment\\t4\\ttrue\\n'
    elif [[ "\${MOCK_AMBIGUOUS_DEPLOYMENTS:-false}" == 'true' ]]; then
      printf 'new-deployment-a\\t0\\tfalse\\nnew-deployment-b\\t0\\tfalse\\n'
    else
      printf 'baseline-deployment\\t4\\ttrue\\nnew-deployment\\t0\\tfalse\\n'
    fi
    ;;
  "webapp deploy"*)
    [[ "$*" == *"--src-url https://stcertigodev.blob.core.windows.net/app-package/deployments/0123456789abcdef0123456789abcdef01234567.zip?sv=mock&spr=https&sp=r&sig=masked-test-token"* ]]
    [[ "$*" == *"--async true"* ]]
    [[ "$*" == *"--track-status false"* ]]
    if [[ "\${MOCK_DEPLOY_FAILURE:-false}" == 'true' ]]; then
      echo "failed to fetch https://stcertigodev.blob.core.windows.net/app-package/deployments/0123456789abcdef0123456789abcdef01234567.zip?sv=mock&spr=https&sp=r&sig=masked-test-token" >&2
      exit 1
    fi
    touch "${shellState}"
    printf '{"id":null,"status":"InProgress"}\\n'
    ;;
  *)
    echo "unexpected az command: $*" >&2
    exit 1
    ;;
esac
`,
  );
  writeExecutable(
    path.join(bin, 'getent'),
    `#!/usr/bin/env bash
printf '%s STREAM mock\\n' "\${MOCK_DNS_IP:-10.60.0.68}"
`,
  );
  writeExecutable(
    path.join(bin, 'curl'),
    `#!/usr/bin/env bash
[[ "$*" == *"/api/health/live"* || "$*" == *"/api/health/ready"* ]]
`,
  );

  return {
    root,
    state,
    packagePath,
    env: {
      ...process.env,
      PATH: `${bin}${path.delimiter}${process.env.PATH}`,
      AZURE_CLI: bashPath(path.join(bin, 'az')),
      CURL_BIN: bashPath(path.join(bin, 'curl')),
      GETENT_BIN: bashPath(path.join(bin, 'getent')),
      RESOURCE_GROUP: 'rg-certigo-dev',
      FUNCTION_APP_NAME: 'func-certigo-dev-test',
      STORAGE_ACCOUNT: 'stcertigodev',
      STORAGE_BLOB_ENDPOINT: 'https://stcertigodev.blob.core.windows.net/',
      PACKAGE_PATH: bashPath(packagePath),
      COMMIT_SHA: '0123456789abcdef0123456789abcdef01234567',
      POLL_INTERVAL_SECONDS: '1',
      DEPLOYMENT_TIMEOUT_SECONDS: '5',
      HEALTH_TIMEOUT_SECONDS: '5',
      GITHUB_ACTIONS: 'false',
    },
  };
}

test('deploy script uses private URL-based OneDeploy and retains the immutable source blob', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: harness.env,
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /passed liveness and readiness checks/);
  assert.match(result.stdout, /retained for lifecycle cleanup/);
  assert.doesNotMatch(result.stdout + result.stderr, /masked-test-token/);
  assert.equal(readFileSync(harness.state, 'utf8'), '');
});

test('deploy script fails before upload when blob DNS is not private', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      MOCK_DNS_IP: '20.42.1.10',
    },
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /does not resolve.*private endpoint/);
});

test('deploy script redacts the signed package URL from OneDeploy errors', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      MOCK_DEPLOY_FAILURE: 'true',
    },
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /<masked-package-url>/);
  assert.doesNotMatch(result.stdout + result.stderr, /masked-test-token|\?sv=mock/);
});

test('deploy script fails closed when multiple new deployments make correlation ambiguous', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      MOCK_AMBIGUOUS_DEPLOYMENTS: 'true',
    },
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /correlation is ambiguous/);
  assert.doesNotMatch(result.stdout + result.stderr, /masked-test-token|\?sv=mock/);
});

test('deploy script forbids config-zip and key-based authentication', () => {
  const script = readFileSync(deployScript, 'utf8');
  assert.doesNotMatch(script, /config-zip|--account-key|--sas-token/i);
  assert.match(script, /az webapp deploy/);
  assert.match(script, /--src-url/);
  assert.match(script, /--as-user/);
  assert.match(script, /--overwrite false/);
  assert.match(script, /baseline_deployment_id/);
  assert.match(script, /sort_by\(\[\?id != null\], &received_time\)/);
  assert.doesNotMatch(script, /storage blob delete/);
});
