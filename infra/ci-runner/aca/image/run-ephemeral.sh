#!/usr/bin/env bash
set -euo pipefail

jit_path="${JIT_CONFIG_PATH:-/var/run/certigo-runner/jitconfig}"
runner_home="${RUNNER_HOME:-/home/runner/actions-runner}"
expected_label="${EXPECTED_RUNNER_LABEL:-}"

[[ "${expected_label}" == "certigo-pr-aca" ]] || {
  echo "The runner label must be exactly certigo-pr-aca." >&2
  exit 1
}
[[ -s "${jit_path}" ]] || {
  echo "The one-time JIT configuration is missing." >&2
  exit 1
}

for forbidden in \
  GITHUB_APP_PRIVATE_KEY \
  GITHUB_APP_ID \
  GITHUB_APP_INSTALLATION_ID \
  IDENTITY_ENDPOINT \
  IDENTITY_HEADER \
  MSI_ENDPOINT \
  MSI_SECRET; do
  if [[ -n "${!forbidden:-}" ]]; then
    echo "Forbidden control-plane or Azure identity variable reached the runner: ${forbidden}" >&2
    exit 1
  fi
done

imds_status="$(
  curl --silent --output /dev/null --write-out '%{http_code}' \
    --connect-timeout 1 --max-time 2 \
    --header 'Metadata: true' \
    'http://169.254.169.254/metadata/instance?api-version=2025-04-07' || true
)"
if [[ "${imds_status}" != "000" ]]; then
  echo "Azure IMDS is reachable from the identity-free PR runner (HTTP ${imds_status})." >&2
  exit 1
fi

cleanup() {
  rm -f -- "${jit_path}"
  rm -rf -- "${runner_home}/_work"
}
trap cleanup EXIT INT TERM

jit_config="$(<"${jit_path}")"
rm -f -- "${jit_path}"
export RUNNER_LOG_TO_STDOUT=1
export ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

printf '{"event":"runner_start","label":"certigo-pr-aca","timestamp":"%s"}\n' \
  "$(date --utc +%Y-%m-%dT%H:%M:%SZ)"

set +e
(
  cd "${runner_home}"
  ./run.sh --jitconfig "${jit_config}"
)
runner_status=$?
set -e
jit_config=''

disk_used_percent="$(df --output=pcent "${runner_home}" | tail -n 1 | tr -cd '0-9')"
printf '{"event":"runner_exit","label":"certigo-pr-aca","status":%d,"diskUsedPercent":%d,"timestamp":"%s"}\n' \
  "${runner_status}" "${disk_used_percent:-0}" "$(date --utc +%Y-%m-%dT%H:%M:%SZ)"
exit "${runner_status}"
