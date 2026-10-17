#!/usr/bin/env bash
set -euo pipefail

if [[ ! "${expected_repository_url:-}" =~ ^https://github\.com/[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$ ]]; then
  echo "An explicit canonical GitHub repository URL is required." >&2
  exit 1
fi
if (( $# != 1 )); then
  echo "A single protected registration-token parameter is required." >&2
  exit 64
fi

systemctl is-active --quiet certigo-block-imds.service
if curl --silent --show-error --connect-timeout 2 --max-time 3 \
  http://169.254.169.254/metadata/instance?api-version=2021-02-01 \
  -H Metadata:true --output /dev/null; then
  echo "Refusing registration while Azure IMDS is reachable." >&2
  exit 1
fi

preflight_attestation="/run/certigo-pr-preflight.ok"
if [[ ! -f "${preflight_attestation}" ]] ||
  [[ "$(stat --format='%U:%G:%a' "${preflight_attestation}")" != 'root:root:600' ]]; then
  echo "A root-owned pre-registration preflight attestation is required." >&2
  exit 1
fi
source "${preflight_attestation}"
if [[ "${BOOT_ID:-}" != "$(cat /proc/sys/kernel/random/boot_id)" ]]; then
  echo "The pre-registration preflight must pass during the current boot." >&2
  exit 1
fi
if [[ "${REPOSITORY_URL:-}" != "${expected_repository_url}" ]]; then
  echo "Preflight repository URL differs from the approved token destination." >&2
  exit 1
fi

registration_token="$1"
trap 'unset registration_token' EXIT

source /etc/certigo-runner-bootstrap.env
if [[ "${GITHUB_URL:-}" != "${expected_repository_url}" ]]; then
  echo "Guest repository URL changed after preflight." >&2
  exit 1
fi
[[ "${RUNNER_LABELS}" == 'certigo-pr,certigo-pr-pilot' ]]
[[ "${RUNNER_VERSION}" == '2.336.0' ]]

# register-pilot.ps1 -RebuildDrill rewrites this exact line, and only on the dedicated drill
# resources. A drill runner carries one label that no workflow targets and no default labels,
# so it can never pick up a real job.
registration_mode='production'
case "${registration_mode}" in
  production)
    label_arguments=(--labels "${RUNNER_LABELS}")
    ;;
  rebuild-drill)
    label_arguments=(--no-default-labels --labels 'certigo-rebuild-drill')
    ;;
  *)
    echo "Unknown registration mode." >&2
    exit 64
    ;;
esac

runner_home="/opt/actions-runner"
runner_user="runner"
runner_name="$(hostname)"

if [[ -e "${runner_home}/.runner" ]]; then
  echo "Runner is already registered; refusing replacement." >&2
  exit 1
fi
runner_units="$(systemctl list-unit-files 'actions.runner.*.service' --no-legend)"
if [[ -n "${runner_units}" ]]; then
  echo "Existing runner service or process prevents held registration." >&2
  exit 1
fi
if pgrep -f '/opt/actions-runner/bin/Runner\.(Listener|Worker)' >/dev/null; then
  echo "Existing runner process prevents held registration." >&2
  exit 1
else
  process_status=$?
  if (( process_status != 1 )); then
    echo "Cannot verify absence of runner processes." >&2
    exit 1
  fi
fi

chown -R "${runner_user}:${runner_user}" "${runner_home}"
installed_version="$(
  runuser -u "${runner_user}" -- "${runner_home}/bin/Runner.Listener" --version 2>/dev/null
)"
[[ "${installed_version}" == "${RUNNER_VERSION}" ]]

runuser -u "${runner_user}" -- "${runner_home}/config.sh" \
  --unattended \
  --url "${expected_repository_url}" \
  --token "${registration_token}" \
  --name "${runner_name}" \
  "${label_arguments[@]}" \
  --work "_work" \
  --disableupdate

unset registration_token
trap - EXIT
rm -f "${preflight_attestation}"
echo "Runner ${runner_name} registered and held offline (mode ${registration_mode})."
