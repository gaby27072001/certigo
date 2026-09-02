#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
case "${0##*/}" in
  certigo-job-start) action="start" ;;
  certigo-job-complete) action="complete" ;;
esac
mount_path="${CERTIGO_JOB_TEMP_MOUNT:-/mnt/certigo-job}"
resource_mount="${CERTIGO_RESOURCE_DISK_MOUNT:-/mnt}"
runner_work="${CERTIGO_RUNNER_WORK:-${mount_path}/_work}"
configured_work="${CERTIGO_CONFIGURED_WORK:-/opt/actions-runner/_work}"
expected_device="${CERTIGO_JOB_TEMP_DEVICE:-/dev/disk/azure/resource-part1}"

workspace_is_expected_bind() {
  mountpoint -q "${configured_work}" &&
    [[ "$(stat -c '%d:%i' "${configured_work}")" == \
      "$(stat -c '%d:%i' "${runner_work}")" ]]
}

clear_job_state() {
  local directory
  for directory in "${runner_work}" temp nuget npm pub dotnet-home; do
    [[ "${directory}" == /* ]] || directory="${mount_path}/${directory}"
    find "${directory}" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  done
}

if [[ "${mount_path}" != /mnt/certigo-job ]]; then
  echo "The job temp mount must be /mnt/certigo-job." >&2
  exit 1
fi
if [[ "${resource_mount}" != /mnt ]]; then
  echo "The Azure resource disk mount must be /mnt." >&2
  exit 1
fi
mountpoint -q "${resource_mount}" || {
  echo "${resource_mount} is not the Azure resource disk; refusing runner admission." >&2
  exit 1
}
actual_device="$(findmnt -n -o SOURCE --target "${resource_mount}")"
actual_device="${actual_device%%[*}"
[[ -e "${expected_device}" ]] || {
  echo "Expected Azure temporary disk is missing: ${expected_device}" >&2
  exit 1
}
[[ "$(readlink -f "${actual_device}")" == "$(readlink -f "${expected_device}")" ]] || {
  echo "${mount_path} is not backed by the expected Azure temporary disk." >&2
  exit 1
}
if [[ "${action}" == "mount" ]]; then
  ((EUID == 0)) || {
    echo "Mount setup must run as root." >&2
    exit 1
  }
  mount -o remount,nodev,nosuid "${resource_mount}"
fi
mount_options="$(findmnt -n -o OPTIONS --target "${resource_mount}")"
for required_option in nodev nosuid; do
  [[ ",${mount_options}," == *",${required_option},"* ]] || {
    echo "${mount_path} must be mounted with ${required_option}." >&2
    exit 1
  }
done
if [[ "${action}" == "mount" ]]; then
  install -d -m 0755 "${mount_path}"
fi
[[ -d "${mount_path}" ]] || {
  echo "The one-job directory is missing from the Azure resource disk." >&2
  exit 1
}

case "${action}" in
  mount)
    install -d -m 0700 -o runner -g runner \
      "${runner_work}" \
      "${mount_path}/temp" \
      "${mount_path}/nuget" \
      "${mount_path}/npm" \
      "${mount_path}/pub" \
      "${mount_path}/dotnet-home"
    install -d -m 0755 -o runner -g runner "${configured_work}"
    if ! mountpoint -q "${configured_work}"; then
      mount --bind "${runner_work}" "${configured_work}"
    fi
    workspace_is_expected_bind || {
      echo "The existing runner workspace mount is not the expected temporary bind." >&2
      exit 1
    }
    clear_job_state
    ;;
  start)
    /usr/local/sbin/certigo-validate-toolchain --job
    [[ "$(stat -c %U "${runner_work}")" == "$(id -un)" ]] || {
      echo "The runner does not own the temporary workspace." >&2
      exit 1
    }
    workspace_is_expected_bind || {
      echo "The configured runner workspace is not on the temporary disk." >&2
      exit 1
    }
    clear_job_state
    ;;
  complete)
    clear_job_state
    sync
    ;;
  *)
    echo "Usage: $0 {mount|start|complete}" >&2
    exit 64
    ;;
esac
