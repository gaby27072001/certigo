#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bootstrap="${root}/infra/ci-runner/bootstrap.sh"
health="${root}/infra/ci-runner/health-probe.sh"
test_health="${root}/infra/ci-runner/test-health-probe.sh"
validate="${root}/infra/ci-runner/validate.sh"
runner_bicep="${root}/infra/ci-runner/runner.bicep"

for script in "${bootstrap}" "${health}" "${test_health}" "${validate}"; do
  bash -n "${script}"
done

runner_sha="$(awk -F'"' '/^RUNNER_SHA256=/ { print $2 }' "${bootstrap}")"
if [[ ! "${runner_sha}" =~ ^[0-9a-f]{64}$ ]]; then
  echo "RUNNER_SHA256 must be a lowercase SHA-256." >&2
  exit 1
fi

actual_bootstrap_sha="$(sha256sum "${bootstrap}" | awk '{ print $1 }')"
declared_bootstrap_sha="$(
  awk -F"'" '/^var bootstrapSha256 =/ { print $2 }' "${runner_bicep}"
)"
if [[ "${declared_bootstrap_sha}" != "${actual_bootstrap_sha}" ]]; then
  echo "runner.bicep bootstrapSha256 does not match bootstrap.sh." >&2
  exit 1
fi

grep -F "toLower(imageVersion) == 'latest'" "${runner_bicep}" >/dev/null

for endpoint in api.github.com api.nuget.org pub.dev registry.npmjs.org management.azure.com; do
  grep -F "${endpoint}" "${health}" >/dev/null
done

bash "${test_health}"
echo "ci-runner validation passed"
