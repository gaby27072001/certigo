#!/usr/bin/env bash
set -euo pipefail

environment_file="${CERTIGO_RUNNER_ENV_FILE:-/etc/certigo/backend-runner.env}"
hook_name="$(basename "$0")"
runtime_root="${CERTIGO_RUNTIME_ROOT:-/run/certigo-backend}"

[[ -r "${environment_file}" ]] || {
  echo "Backend runner environment contract is missing." >&2
  exit 1
}
# shellcheck disable=SC1090
source "${environment_file}"
: "${CERTIGO_JOB_ROOT:?}"
: "${CERTIGO_RUNNER_HOME:?}"

clear_directory() {
  local directory="$1"
  [[ -d "${directory}" ]] || return 0
  find "${directory}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

case "${hook_name}" in
  certigo-backend-job-started)
    if [[ -e "${runtime_root}/job-started" ]]; then
      echo "A second job cannot start on an ephemeral backend runner." >&2
      exit 1
    fi
    if [[ -S /var/run/docker.sock ]] || command -v docker >/dev/null 2>&1; then
      echo "Docker is forbidden on isolated backend runners." >&2
      exit 1
    fi
    install -d -m 0700 \
      "${CERTIGO_JOB_ROOT}/temp" \
      "${CERTIGO_JOB_ROOT}/nuget" \
      "${CERTIGO_JOB_ROOT}/npm" \
      "${CERTIGO_JOB_ROOT}/dotnet-home"
    [[ -d "${runtime_root}" && -w "${runtime_root}" ]] || {
      echo "Runner runtime directory is not writable." >&2
      exit 1
    }
    touch "${runtime_root}/job-started"
    ;;
  certigo-backend-job-completed)
    [[ -e "${runtime_root}/job-started" ]] || {
      echo "Completion hook ran without a matching start hook." >&2
      exit 1
    }
    clear_directory "${CERTIGO_JOB_ROOT}/nuget"
    clear_directory "${CERTIGO_JOB_ROOT}/npm"
    clear_directory "${CERTIGO_JOB_ROOT}/dotnet-home"
    clear_directory "${CERTIGO_JOB_ROOT}/temp"
    touch "${runtime_root}/job-completed"
    ;;
  *)
    echo "Invoke this hook through its started or completed link." >&2
    exit 64
    ;;
esac
