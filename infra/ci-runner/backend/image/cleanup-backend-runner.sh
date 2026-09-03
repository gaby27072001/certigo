#!/usr/bin/env bash
set -euo pipefail

test_mode="${CERTIGO_CLEANUP_TEST_MODE:-false}"
environment_file="${CERTIGO_RUNNER_ENV_FILE:-/etc/certigo/backend-runner.env}"

if [[ "${test_mode}" != "true" && EUID -ne 0 ]]; then
  echo "Backend runner retirement cleanup must run as root." >&2
  exit 1
fi
[[ -r "${environment_file}" ]] || {
  echo "Backend runner environment contract is missing." >&2
  exit 1
}
# shellcheck disable=SC1090
source "${environment_file}"
: "${CERTIGO_SERVICE_USER:?}"
: "${CERTIGO_RUNNER_HOME:?}"
: "${CERTIGO_SERVICE_HOME:?}"
: "${CERTIGO_JOB_ROOT:?}"

docker_root="${CERTIGO_DOCKER_ROOT:-/var/lib/docker}"
containerd_root="${CERTIGO_CONTAINERD_ROOT:-/var/lib/containerd}"
retire_stamp="${CERTIGO_RETIRE_STAMP:-/var/lib/certigo/backend-runner-retired}"

power_off() {
  if [[ "${test_mode}" != "true" ]]; then
    systemctl poweroff --no-block || true
  fi
}
trap power_off EXIT

clear_directory() {
  local directory="$1"
  case "${directory}" in
    ''|/|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
      echo "Refusing unsafe cleanup path ${directory:-<empty>}." >&2
      exit 1
      ;;
  esac
  [[ -d "${directory}" ]] || return 0
  find "${directory}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

if [[ "${test_mode}" == "true" ]]; then
  install -d -m 0755 "$(dirname "${retire_stamp}")"
else
  install -d -m 0755 -o root -g root "$(dirname "${retire_stamp}")"
fi
retire_tmp="${retire_stamp}.tmp.$$"
{
  printf 'schema=certigo.backend-runner-retirement/v1\n'
  printf 'retiredAt=%s\n' "$(date --utc +%Y-%m-%dT%H:%M:%SZ)"
  if [[ -r /run/certigo-backend-runner-lease ]]; then
    cat /run/certigo-backend-runner-lease
  fi
} > "${retire_tmp}"
chmod 0444 "${retire_tmp}"
mv -f -- "${retire_tmp}" "${retire_stamp}"

if [[ "${test_mode}" != "true" ]]; then
  if command -v docker >/dev/null 2>&1; then
    docker ps -aq | xargs -r docker rm -f
    docker image ls -aq | xargs -r docker image rm -f
    docker volume ls -q | xargs -r docker volume rm -f
  fi
  systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true
  pkill -KILL -u "${CERTIGO_SERVICE_USER}" 2>/dev/null || true
  if pgrep -u "${CERTIGO_SERVICE_USER}" >/dev/null 2>&1; then
    echo "Service-user processes survived retirement cleanup." >&2
    exit 1
  fi
fi

clear_directory "${CERTIGO_RUNNER_HOME}/_work"
clear_directory "${CERTIGO_JOB_ROOT}"
for cache in \
  "${CERTIGO_SERVICE_HOME}/.cache" \
  "${CERTIGO_SERVICE_HOME}/.npm" \
  "${CERTIGO_SERVICE_HOME}/.nuget" \
  "${CERTIGO_SERVICE_HOME}/.dotnet" \
  "${CERTIGO_SERVICE_HOME}/.local/share/NuGet" \
  "${CERTIGO_SERVICE_HOME}/.azure" \
  "${CERTIGO_SERVICE_HOME}/.docker"; do
  clear_directory "${cache}"
done
clear_directory "${docker_root}"
clear_directory "${containerd_root}"
clear_directory "${CERTIGO_RUNTIME_ROOT:-/run/certigo-backend}"

rm -f -- \
  "${CERTIGO_RUNNER_HOME}/.runner" \
  "${CERTIGO_RUNNER_HOME}/.credentials" \
  "${CERTIGO_RUNNER_HOME}/.credentials_rsaparams" \
  "${CERTIGO_RUNNER_HOME}/.service" \
  "${CERTIGO_RUNNER_HOME}/.env"

if "${CERTIGO_RUNNER_HOME}/bin/Runner.Listener" --version >/dev/null 2>&1 &&
  [[ ! -e "${CERTIGO_RUNNER_HOME}/.runner" ]] &&
  [[ "${test_mode}" == "true" ]]; then
  echo "Backend runner cleanup fixture passed."
fi
