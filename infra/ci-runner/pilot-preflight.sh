#!/usr/bin/env bash
set -euo pipefail

cloud-init status --wait >/dev/null
source /etc/certigo-runner-bootstrap.env

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
EOF
chown root:root /run/certigo-pr-preflight.ok

echo "PR-only pilot pre-registration preflight passed."
