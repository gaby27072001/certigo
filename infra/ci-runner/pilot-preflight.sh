#!/usr/bin/env bash
set -euo pipefail

if [[ ! "${expected_repository_url:-}" =~ ^https://github\.com/[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$ ]]; then
  echo "An explicit canonical GitHub repository URL is required." >&2
  exit 1
fi
rm -f /run/certigo-pr-preflight.ok
cloud-init status --wait >/dev/null
source /etc/certigo-runner-bootstrap.env

if [[ "${GITHUB_URL:-}" != "${expected_repository_url}" ]]; then
  echo "Guest repository URL differs from the approved token destination." >&2
  exit 1
fi
[[ "${RUNNER_LABELS}" == 'certigo-pr,certigo-pr-pilot' ]]
[[ "${RUNNER_VERSION}" == '2.336.0' ]]
systemctl is-enabled --quiet certigo-block-imds.service
systemctl is-active --quiet certigo-block-imds.service

if curl --silent --show-error --connect-timeout 2 --max-time 3 \
  http://169.254.169.254/metadata/instance?api-version=2021-02-01 \
  -H Metadata:true --output /dev/null; then
  echo "Azure IMDS must be unreachable before a registration token is requested." >&2
  exit 1
fi

if [[ -e /opt/actions-runner/.runner ]]; then
  echo "Runner is already registered; refusing a pre-registration preflight." >&2
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

for tool in git curl jq tar unzip zip xz az; do
  command -v "${tool}" >/dev/null
done

for endpoint in \
  https://api.github.com/meta \
  https://api.nuget.org/v3/index.json \
  https://pub.dev/api/packages/http \
  https://registry.npmjs.org/-/ping; do
  curl --fail --silent --show-error --location --retry 2 \
    --connect-timeout 10 --max-time 30 --output /dev/null "${endpoint}"
done

umask 077
cat > /run/certigo-pr-preflight.ok <<EOF
BOOT_ID=$(cat /proc/sys/kernel/random/boot_id)
REPOSITORY_URL=${expected_repository_url}
EOF
chown root:root /run/certigo-pr-preflight.ok

echo "PR-only pilot pre-registration preflight passed."
