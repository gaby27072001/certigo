#!/usr/bin/env bash
set -euo pipefail

MIN_FREE_GB="${MIN_FREE_GB:-10}"
DISK_PATH="${DISK_PATH:-${GITHUB_WORKSPACE:-/}}"
REQUIRED_TOOLS="${REQUIRED_TOOLS:-git curl jq tar unzip zip xz node npm dotnet dart flutter java az bicep}"
PROBE_ENDPOINTS="${PROBE_ENDPOINTS:-GitHub|https://api.github.com/meta
NuGet|https://api.nuget.org/v3/index.json
pub.dev|https://pub.dev/api/packages/http
npm|https://registry.npmjs.org/-/ping
Azure|https://management.azure.com/metadata/endpoints?api-version=2020-06-01}"

failures=0
report=""

if [[ ! "${MIN_FREE_GB}" =~ ^[0-9]+$ ]]; then
  echo "MIN_FREE_GB must be a non-negative integer." >&2
  exit 2
fi

record() {
  local component="$1"
  local result="$2"
  local detail="$3"
  report+="| ${component} | ${result} | ${detail//$'\n'/ } |"$'\n'
  if [[ "${result}" == "FAIL" ]]; then
    failures=$((failures + 1))
  fi
}

record "runner" "PASS" "${RUNNER_NAME:-unknown} / ${RUNNER_OS:-unknown} / ${RUNNER_ARCH:-unknown}"

while IFS='|' read -r name url; do
  [[ -z "${name}" ]] && continue
  if curl --fail --silent --show-error --location --retry 2 \
    --connect-timeout 10 --max-time 30 --output /dev/null "${url}"; then
    record "${name}" "PASS" "${url}"
  else
    record "${name}" "FAIL" "${url}"
  fi
done <<< "${PROBE_ENDPOINTS}"

for tool in ${REQUIRED_TOOLS}; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    record "${tool}" "FAIL" "not found"
    continue
  fi

  case "${tool}" in
    java) version_command=("${tool}" -version) ;;
    az) version_command=("${tool}" version --query '"azure-cli"' -o tsv) ;;
    unzip | zip) version_command=("${tool}" -v) ;;
    *) version_command=("${tool}" --version) ;;
  esac
  if version_output="$("${version_command[@]}" 2>&1)"; then
    version="${version_output%%$'\n'*}"
    record "${tool}" "PASS" "${version:-version command succeeded}"
  else
    version="${version_output%%$'\n'*}"
    record "${tool}" "FAIL" "${version:-version command failed}"
  fi
done

if available_kb="$(LC_ALL=C df -Pk -- "${DISK_PATH}" | awk 'NR == 2 { print $4 }')" &&
  [[ "${available_kb}" =~ ^[0-9]+$ ]]; then
  required_kb=$((MIN_FREE_GB * 1024 * 1024))
  available_gb=$((available_kb / 1024 / 1024))
  if ((available_kb >= required_kb)); then
    record "free disk" "PASS" "${available_gb} GiB available at ${DISK_PATH} (minimum ${MIN_FREE_GB} GiB)"
  else
    record "free disk" "FAIL" "${available_gb} GiB available at ${DISK_PATH} (minimum ${MIN_FREE_GB} GiB)"
  fi
else
  record "free disk" "FAIL" "unable to read available space at ${DISK_PATH}"
fi

{
  echo "### Certigo runner health"
  echo
  echo "| Component | Result | Detail |"
  echo "|---|---|---|"
  printf '%s' "${report}"
}

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Certigo runner health"
    echo
    echo "| Component | Result | Detail |"
    echo "|---|---|---|"
    printf '%s' "${report}"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

if ((failures > 0)); then
  echo "${failures} runner health check(s) failed." >&2
  exit 1
fi
