#!/usr/bin/env bash
set -euo pipefail

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

registration_token="$1"
trap 'unset registration_token' EXIT

source /etc/certigo-runner-bootstrap.env
[[ "${RUNNER_LABELS}" == 'certigo-pr,certigo-pr-pilot' ]]
[[ "${RUNNER_VERSION}" == '2.336.0' ]]

runner_home="/opt/actions-runner"
runner_user="runner"
runner_name="$(hostname)"

if [[ -e "${runner_home}/.runner" ]]; then
  echo "Runner is already registered; refusing replacement." >&2
  exit 1
fi

chown -R "${runner_user}:${runner_user}" "${runner_home}"
installed_version="$(
  runuser -u "${runner_user}" -- "${runner_home}/bin/Runner.Listener" --version 2>/dev/null
)"
[[ "${installed_version}" == "${RUNNER_VERSION}" ]]

runuser -u "${runner_user}" -- "${runner_home}/config.sh" \
  --unattended \
  --url "${GITHUB_URL}" \
  --token "${registration_token}" \
  --name "${runner_name}" \
  --labels "${RUNNER_LABELS}" \
  --work "_work" \
  --disableupdate

unset registration_token
trap - EXIT
rm -f "${preflight_attestation}"
(
  cd "${runner_home}"
  ./svc.sh install "${runner_user}"
  ./svc.sh start
)
echo "Runner ${runner_name} registered and started."
