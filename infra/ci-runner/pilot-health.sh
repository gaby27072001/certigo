#!/usr/bin/env bash
set -euo pipefail

source /etc/certigo-runner-bootstrap.env

[[ "${RUNNER_LABELS}" == 'certigo-pr,certigo-pr-pilot' ]]
[[ "${RUNNER_VERSION}" == '2.336.0' ]]
systemctl is-active --quiet certigo-block-imds.service

if curl --silent --show-error --connect-timeout 2 --max-time 3 \
  http://169.254.169.254/metadata/instance?api-version=2021-02-01 \
  -H Metadata:true --output /dev/null; then
  echo "Azure IMDS must not be reachable from the PR runner." >&2
  exit 1
fi

mapfile -t runner_services < <(
  systemctl list-unit-files --type=service --no-legend 'actions.runner.*' |
    awk '$2 != "masked" { print $1 }'
)
if (( ${#runner_services[@]} != 1 )); then
  echo "Expected exactly one GitHub runner service; found ${#runner_services[@]}." >&2
  exit 1
fi
systemctl is-active --quiet "${runner_services[0]}"

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

echo "PR-only pilot health passed."
