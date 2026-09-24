#!/usr/bin/env bash
set -euo pipefail
set +x

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
image="mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator@sha256:dc583d6e1620c38e13e2d85ade2ea7b693ba8101c90e449b5504c0b3b321669c"
container="certigo-cosmos-account-deletion-${GITHUB_RUN_ID:-local}-$$"
key_file=""
results_dir=""

cleanup_all() {
  mapfile -t containers < <(
    docker ps --all --quiet --filter label=certigo.scope=account-deletion-cosmos
  )
  if (( ${#containers[@]} > 0 )); then
    docker rm --force "${containers[@]}" >/dev/null
  fi
  find /tmp -maxdepth 1 -type f -name 'certigo-cosmos-key.*' -delete
  find /tmp -maxdepth 1 -type d -name 'certigo-cosmos-results.*' \
    -exec rm -rf -- {} +
}

cleanup() {
  set +e
  docker rm --force "${container}" >/dev/null 2>&1
  if [[ -n "${key_file}" && -f "${key_file}" ]]; then
    chmod 0600 "${key_file}"
    printf '' > "${key_file}"
    rm -f -- "${key_file}"
  fi
  if [[ -n "${results_dir}" && -d "${results_dir}" ]]; then
    rm -rf -- "${results_dir}"
  fi
  unset COSMOS_EMULATOR_KEY cosmos_key
}

if [[ "${1:-}" == "--cleanup-only" ]]; then
  if (( $# != 1 )); then
    echo "Usage: $0 [--cleanup-only]" >&2
    exit 2
  fi
  cleanup_all
  exit 0
fi
if (( $# != 0 )); then
  echo "Usage: $0 [--cleanup-only]" >&2
  exit 2
fi

trap cleanup EXIT

for command in curl docker dotnet openssl python3 timeout; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "${command} is required for the local Cosmos emulator gate." >&2
    exit 1
  }
done

for variable in \
  ACTIONS_ID_TOKEN_REQUEST_TOKEN \
  ACTIONS_ID_TOKEN_REQUEST_URL \
  AZURE_CLIENT_ID \
  AZURE_CLIENT_SECRET \
  AZURE_FEDERATED_TOKEN_FILE \
  AZURE_SUBSCRIPTION_ID \
  AZURE_TENANT_ID \
  ARM_CLIENT_ID \
  ARM_CLIENT_SECRET \
  ARM_SUBSCRIPTION_ID \
  ARM_TENANT_ID \
  COSMOS_CONNECTION_STRING \
  COSMOS_EMULATOR_CONNECTION_STRING \
  COSMOS_ENDPOINT \
  COSMOS_KEY \
  IDENTITY_ENDPOINT \
  IMDS_ENDPOINT \
  MSI_ENDPOINT; do
  if [[ -n "${!variable:-}" ]]; then
    echo "Live cloud variable ${variable} must not be present in the emulator job." >&2
    exit 1
  fi
done

unset \
  ALL_PROXY all_proxy \
  COSMOS_EMULATOR_CONNECTION_STRING \
  HTTP_PROXY http_proxy \
  HTTPS_PROXY https_proxy
export NO_PROXY=127.0.0.1,localhost
export no_proxy="${NO_PROXY}"

if curl --noproxy '*' --fail --silent --show-error \
  --connect-timeout 2 --max-time 3 \
  --header 'Metadata: true' \
  'http://169.254.169.254/metadata/instance?api-version=2025-04-07' \
  >/dev/null 2>&1; then
  echo "Azure IMDS is reachable from the runner job; refusing to continue." >&2
  exit 1
fi

docker image inspect "${image}" >/dev/null 2>&1 || {
  echo "The pinned Cosmos emulator image was not preloaded by bootstrap." >&2
  exit 1
}
docker image inspect --format '{{join .RepoDigests "\n"}}' "${image}" |
  grep -Fx "${image}" >/dev/null || {
    echo "The local Cosmos emulator image digest does not match the pin." >&2
    exit 1
  }

umask 077
key_file="$(mktemp /tmp/certigo-cosmos-key.XXXXXX)"
cosmos_key="$(openssl rand -base64 64 | tr -d '\r\n')"
printf '%s' "${cosmos_key}" > "${key_file}"

docker run --detach \
  --pull never \
  --name "${container}" \
  --label certigo.scope=account-deletion-cosmos \
  --publish 127.0.0.1:8080:8080 \
  --publish 127.0.0.1:8081:8081 \
  --mount "type=bind,source=${key_file},target=/run/secrets/cosmos.key,readonly" \
  --env KEY_FILE=/run/secrets/cosmos.key \
  --env PROTOCOL=https \
  --env ENABLE_EXPLORER=false \
  --security-opt no-new-privileges=true \
  --pids-limit 1024 \
  --memory 8g \
  --cpus 3 \
  "${image}" >/dev/null

ready=false
for _ in $(seq 1 120); do
  if curl --noproxy '*' --fail --silent --show-error \
    http://127.0.0.1:8080/ready >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
if [[ "${ready}" != true ]]; then
  echo "Cosmos emulator did not become ready within 240 seconds." >&2
  exit 1
fi

export CERTIGO_COSMOS_TESTS=1
export COSMOS_EMULATOR_ENDPOINT=https://127.0.0.1:8081
export COSMOS_EMULATOR_KEY="${cosmos_key}"

# The gate runs the whole emulator suite, not only account deletion: every test
# marked [CosmosEmulatorFact] must execute and pass. The expected count comes from
# the sources so a test left outside the Category=CosmosEmulator trait, skipped or
# silently dropped fails the gate instead of shrinking it.
test_sources="${root}/backend/tests/Certigo.Infrastructure.Tests"
expected_tests="$(
  {
    grep -rhE --include='*.cs' --exclude-dir=bin --exclude-dir=obj \
      '^[[:space:]]*\[CosmosEmulatorFact([](,]|$)' "${test_sources}" || true
  } | wc -l
)"
if (( expected_tests < 1 )); then
  echo "No [CosmosEmulatorFact] test was found under ${test_sources}." >&2
  exit 1
fi

results_dir="$(mktemp -d /tmp/certigo-cosmos-results.XXXXXX)"
result_file="${results_dir}/cosmos-emulator.trx"
set +e
timeout --signal=TERM --kill-after=30s 1200 dotnet test \
  "${root}/backend/tests/Certigo.Infrastructure.Tests/Certigo.Infrastructure.Tests.csproj" \
  --configuration Release \
  --no-restore \
  --filter 'Category=CosmosEmulator' \
  --logger 'trx;LogFileName=cosmos-emulator.trx' \
  --results-directory "${results_dir}" \
  --verbosity normal
test_exit=$?
set -e

if [[ ! -f "${result_file}" ]]; then
  echo "The Cosmos emulator suite did not produce a TRX result (dotnet exit ${test_exit})." >&2
  exit 1
fi

EXPECTED_TESTS="${expected_tests}" \
REQUIRED_TEST='Certigo.Infrastructure.Tests.CosmosRepositoriesIntegrationTests.Account_deletion_removes_user_partitions_and_keeps_only_pseudonymous_tombstone' \
RESULT_FILE="${result_file}" \
TEST_EXIT="${test_exit}" \
python3 -P - <<'PY'
import os
import sys
import xml.etree.ElementTree as ElementTree

namespace = {"t": "http://microsoft.com/schemas/VisualStudio/TeamTest/2010"}
expected = int(os.environ["EXPECTED_TESTS"])
required = os.environ["REQUIRED_TEST"]
results = [
    (node.get("testName", ""), node.get("outcome", ""), node.get("duration", ""))
    for node in ElementTree.parse(os.environ["RESULT_FILE"]).getroot().iterfind(
        ".//t:UnitTestResult", namespace
    )
]
names = [name for name, _, _ in results]
passed = [name for name, outcome, _ in results if outcome == "Passed"]
errors = []
if len(results) != expected:
    errors.append(
        f"expected {expected} Cosmos emulator results (one per [CosmosEmulatorFact]); "
        f"found {len(results)}"
    )
if len(set(names)) != len(names):
    errors.append("a Cosmos emulator test was reported more than once")
not_passed = [f"{name} ({outcome})" for name, outcome, _ in results if outcome != "Passed"]
if not_passed:
    errors.append("skipped or failed: " + ", ".join(not_passed))
if required not in passed:
    errors.append("the account-deletion test was skipped, renamed, or did not pass")
if os.environ["TEST_EXIT"] != "0":
    errors.append(f"dotnet test exited with {os.environ['TEST_EXIT']}")

lines = [
    "### Cosmos emulator suite",
    "",
    f"**{len(passed)}/{expected}** passed; account deletion "
    + ("**passed**." if required in passed else "**did not pass**."),
    "",
    "| Test | Outcome | Duration |",
    "| --- | --- | --- |",
]
lines += [
    f"| `{name.rsplit('.', 2)[-2]}.{name.rsplit('.', 1)[-1]}` | {outcome} | {duration} |"
    for name, outcome, duration in sorted(results)
]
report = "\n".join(lines) + "\n"
print(report)
summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    with open(summary, "a", encoding="utf-8") as handle:
        handle.write(report + "\n")
if errors:
    for error in errors:
        print(f"Cosmos emulator gate: {error}.", file=sys.stderr)
    sys.exit(1)
PY
