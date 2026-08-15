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
  const shellPollState = `${shellState}.poll`;
  const shellNumericState = `${shellState}.numeric`;
  const packagePath = path.join(root, 'publish.zip');
  writeFileSync(packagePath, 'deterministic-package', 'utf8');

  writeExecutable(
    path.join(bin, 'az'),
    `#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  "storage account show"*)
    printf 'Disabled\\nfalse\\n'
    ;;
  "resource show"*)
    printf 'UserAssignedIdentity\\nhttps://stcertigodev.blob.core.windows.net/app-package\\n/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-certigo-dev/providers/Microsoft.Network/virtualNetworks/vnet-certigo-dev/subnets/snet-functions\\n'
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
  "account get-access-token"*)
    [[ "$*" == *"--resource https://management.azure.com/"* ]]
    printf 'masked-arm-token\\n'
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
set -euo pipefail
original_args="$*"
method='GET'
auth_config=''
data_file=''
headers_file=''
output_file=''
url=''

while (( $# > 0 )); do
  case "$1" in
    --request)
      method="$2"
      shift 2
      ;;
    --config)
      auth_config="$2"
      shift 2
      ;;
    --data-binary)
      data_file="\${2#@}"
      shift 2
      ;;
    --dump-header)
      headers_file="$2"
      shift 2
      ;;
    --output)
      output_file="$2"
      shift 2
      ;;
    --header|--write-out|--max-time)
      shift 2
      ;;
    --fail|--silent|--show-error)
      shift
      ;;
    https://*)
      url="$1"
      shift
      ;;
    *)
      echo "unexpected curl argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "$url" == *"/api/health/live" || "$url" == *"/api/health/ready" ]]; then
  exit 0
fi

[[ -n "$auth_config" && -f "$auth_config" ]]
[[ "$(stat -c '%a' "$auth_config")" == '600' ]]
grep -Fx 'header = "Authorization: Bearer masked-arm-token"' "$auth_config" >/dev/null
[[ "$original_args" != *"masked-arm-token"* ]]
[[ "$original_args" != *"masked-test-token"* ]]

if [[ "$method" == 'PUT' ]]; then
  [[ "$url" == 'https://management.azure.com/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-certigo-dev/providers/Microsoft.Web/sites/func-certigo-dev-test/extensions/onedeploy?api-version=2024-04-01' ]]
  [[ -n "$data_file" && -f "$data_file" ]]
  [[ "$(stat -c '%a' "$data_file")" == '600' ]]
  grep -F '"packageUri":"https://stcertigodev.blob.core.windows.net/app-package/deployments/0123456789abcdef0123456789abcdef01234567.zip?sv=mock&spr=https&sp=r&sig=masked-test-token"' "$data_file" >/dev/null
  grep -F '"type":"zip"' "$data_file" >/dev/null
  grep -F '"async":true' "$data_file" >/dev/null
  grep -F '"restart":true' "$data_file" >/dev/null
  grep -F '"clean":true' "$data_file" >/dev/null

  printf '{"id":null,"status":"InProgress"}\\n' >"$output_file"
  if [[ "\${MOCK_DEPLOY_FAILURE:-false}" == 'true' ]]; then
    printf '{"error":{"message":"failed to fetch ?sv=mock&sig=masked-test-token"}}\\n' >"$output_file"
    printf 'HTTP/1.1 400 Bad Request\\r\\n\\r\\n' >"$headers_file"
    printf '400'
    exit 0
  fi
  if [[ "\${MOCK_MISSING_OPERATION_HEADER:-false}" == 'true' ]]; then
    printf 'HTTP/1.1 202 Accepted\\r\\n\\r\\n' >"$headers_file"
  elif [[ "\${MOCK_INVALID_OPERATION_HEADER:-false}" == 'true' ]]; then
    printf 'HTTP/1.1 202 Accepted\\r\\nAzure-AsyncOperation: https://example.invalid/steal\\r\\n\\r\\n' >"$headers_file"
  elif [[ "\${MOCK_LOCATION_HEADER:-false}" == 'true' ]]; then
    printf 'HTTP/1.1 202 Accepted\\r\\nLocation: https://management.azure.com/subscriptions/test/operations/mock-operation?api-version=2024-04-01\\r\\n\\r\\n' >"$headers_file"
  else
    printf 'HTTP/1.1 202 Accepted\\r\\nAzure-AsyncOperation: https://management.azure.com/subscriptions/test/operations/mock-operation?api-version=2024-04-01\\r\\n\\r\\n' >"$headers_file"
  fi
  touch "${shellState}"
  printf '202'
  exit 0
fi

[[ "$method" == 'GET' ]]
[[ "$url" == 'https://management.azure.com/subscriptions/test/operations/mock-operation?api-version=2024-04-01' ]]
if [[ "\${MOCK_LOCATION_EMPTY_202:-false}" == 'true' && ! -f "${shellPollState}" ]]; then
  touch "${shellPollState}"
  : >"$output_file"
  printf '202'
  exit 0
fi
if [[ "\${MOCK_NUMERIC_OPERATION_STATUS:-false}" == 'true' ]]; then
  if [[ -f "${shellNumericState}" ]]; then
    printf '{"status":4}\\n' >"$output_file"
  else
    touch "${shellNumericState}"
    printf '{"status":2}\\n' >"$output_file"
  fi
  printf '200'
  exit 0
fi
case "\${MOCK_OPERATION_STATUS:-Succeeded}" in
  Timeout)
    printf '{"status":"InProgress"}\\n' >"$output_file"
    ;;
  *)
    printf '{"status":"%s"}\\n' "\${MOCK_OPERATION_STATUS:-Succeeded}" >"$output_file"
    ;;
esac
printf '200'
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
      SUBSCRIPTION_ID: '11111111-1111-1111-1111-111111111111',
      FUNCTION_APP_NAME: 'func-certigo-dev-test',
      FUNCTION_INTEGRATION_SUBNET_ID:
        '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-certigo-dev/providers/Microsoft.Network/virtualNetworks/vnet-certigo-dev/subnets/snet-functions',
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

test('deploy script polls the exact ARM operation returned with an id-null response', () => {
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

test('deploy script fails when the Function App uses an unexpected integration subnet', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      FUNCTION_INTEGRATION_SUBNET_ID:
        '/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-certigo-dev/providers/Microsoft.Network/virtualNetworks/vnet-certigo-dev/subnets/other-subnet',
    },
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(
    result.stdout + result.stderr,
    /not connected to the expected private integration subnet/,
  );
});

test('deploy script does not disclose the signed package URL from ARM errors', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      MOCK_DEPLOY_FAILURE: 'true',
    },
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stdout + result.stderr, /returned HTTP 400/);
  assert.doesNotMatch(
    result.stdout + result.stderr,
    /masked-arm-token|masked-test-token|\?sv=mock/,
  );
});

test('deploy script accepts a valid Location fallback header', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      MOCK_LOCATION_HEADER: 'true',
    },
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
});

test('deploy script accepts an empty 202 while polling a Location fallback', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      MOCK_LOCATION_HEADER: 'true',
      MOCK_LOCATION_EMPTY_202: 'true',
    },
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.doesNotMatch(
    result.stdout + result.stderr,
    /masked-arm-token|masked-test-token|\?sv=mock/,
  );
});

test('deploy script accepts numeric Kudu deployment statuses', () => {
  const harness = createHarness();
  const result = spawnSync('bash', [bashPath(deployScript)], {
    env: {
      ...harness.env,
      MOCK_NUMERIC_OPERATION_STATUS: 'true',
    },
    encoding: 'utf8',
  });

  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /passed liveness and readiness checks/);
});

for (const [name, environment, expected] of [
  [
    'missing asynchronous operation header',
    { MOCK_MISSING_OPERATION_HEADER: 'true' },
    /did not return exactly one asynchronous operation header/,
  ],
  [
    'invalid asynchronous operation URL',
    { MOCK_INVALID_OPERATION_HEADER: 'true' },
    /invalid asynchronous operation URL/,
  ],
  [
    'failed asynchronous operation',
    { MOCK_OPERATION_STATUS: 'Failed' },
    /asynchronous operation failed/,
  ],
  [
    'asynchronous operation timeout',
    { MOCK_OPERATION_STATUS: 'Timeout', DEPLOYMENT_TIMEOUT_SECONDS: '2' },
    /did not succeed before timeout/,
  ],
]) {
  test(`deploy script fails closed on ${name}`, () => {
    const harness = createHarness();
    const result = spawnSync('bash', [bashPath(deployScript)], {
      env: {
        ...harness.env,
        ...environment,
      },
      encoding: 'utf8',
    });

    assert.notEqual(result.status, 0);
    assert.match(result.stdout + result.stderr, expected);
    assert.doesNotMatch(
      result.stdout + result.stderr,
      /masked-arm-token|masked-test-token|\?sv=mock/,
    );
  });
}

test('deploy script uses only direct ARM OneDeploy and user delegation', () => {
  const script = readFileSync(deployScript, 'utf8');
  assert.doesNotMatch(
    script,
    /config-zip|--account-key|--sas-token|az webapp deploy|webapp log deployment/i,
  );
  assert.match(script, /az account get-access-token/);
  assert.match(script, /extensions\/onedeploy\?api-version=2024-04-01/);
  assert.match(script, /Azure-AsyncOperation/);
  assert.match(script, /Location/);
  assert.match(script, /--dump-header/);
  assert.match(script, /--config "\$auth_config_file"/);
  assert.match(script, /--as-user/);
  assert.match(script, /--overwrite false/);
  assert.match(script, /umask 077/);
  assert.doesNotMatch(script, /storage blob delete/);
});
