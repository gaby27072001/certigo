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
metrics=""
probe_started_ms="$(date +%s%3N)"

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

record_metric() {
  local name="$1"
  local value="$2"
  local unit="$3"
  metrics+="| ${name} | ${value} | ${unit} |"$'\n'
}

record "runner" "PASS" "${RUNNER_NAME:-unknown} / ${RUNNER_OS:-unknown} / ${RUNNER_ARCH:-unknown}"
record_metric "runner.lifecycle.active" "1" "count"

if [[ -n "${RUN_QUEUE_WAIT_SECONDS:-}" ]]; then
  if [[ ! "${RUN_QUEUE_WAIT_SECONDS}" =~ ^[0-9]+$ ]]; then
    echo "RUN_QUEUE_WAIT_SECONDS must be a non-negative integer." >&2
    exit 2
  fi
  record_metric "runner.queue.wait" "${RUN_QUEUE_WAIT_SECONDS}" "seconds"
fi

while IFS='|' read -r name url; do
  [[ -z "${name}" ]] && continue
  request_started_ms="$(date +%s%3N)"
  if curl --fail --silent --show-error --location --retry 2 \
    --connect-timeout 10 --max-time 30 --output /dev/null "${url}"; then
    record "${name}" "PASS" "${url}"
  else
    record "${name}" "FAIL" "${url}"
  fi
  request_finished_ms="$(date +%s%3N)"
  case "${name}" in
    NuGet | pub.dev | npm)
      metric_name="$(tr '[:upper:].' '[:lower:]_' <<< "${name}")"
      record_metric "runner.package.${metric_name}.latency" \
        "$((request_finished_ms - request_started_ms))" "milliseconds"
      ;;
  esac
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

cache_kb=0
IFS=':' read -r -a cache_paths <<< "${CACHE_PATHS:-${HOME}/.nuget/packages:${HOME}/.npm:${PUB_CACHE:-}}"
for cache_path in "${cache_paths[@]}"; do
  [[ -z "${cache_path}" || ! -d "${cache_path}" ]] && continue
  current_cache_kb="$(du -sk -- "${cache_path}" | awk '{ print $1 }')"
  if [[ "${current_cache_kb}" =~ ^[0-9]+$ ]]; then
    cache_kb=$((cache_kb + current_cache_kb))
  fi
done
record_metric "runner.cache.local" "$((cache_kb * 1024))" "bytes"
record_metric "runner.probe.duration" "$(( $(date +%s%3N) - probe_started_ms ))" "milliseconds"

{
  echo "### Certigo runner health"
  echo
  echo "| Component | Result | Detail |"
  echo "|---|---|---|"
  printf '%s' "${report}"
  echo
  echo "### Certigo runner metrics"
  echo
  echo "| Metric | Value | Unit |"
  echo "|---|---:|---|"
  printf '%s' "${metrics}"
}

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "### Certigo runner health"
    echo
    echo "| Component | Result | Detail |"
    echo "|---|---|---|"
    printf '%s' "${report}"
    echo
    echo "### Certigo runner metrics"
    echo
    echo "| Metric | Value | Unit |"
    echo "|---|---:|---|"
    printf '%s' "${metrics}"
  } >> "${GITHUB_STEP_SUMMARY}"
fi

if ((failures > 0)); then
  echo "${failures} runner health check(s) failed." >&2
  exit 1
fi
