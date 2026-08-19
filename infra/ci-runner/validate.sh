#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bootstrap="${root}/infra/ci-runner/bootstrap.sh"
health="${root}/infra/ci-runner/health-probe.sh"
test_health="${root}/infra/ci-runner/test-health-probe.sh"
lifecycle_preflight="${root}/infra/ci-runner/lifecycle-preflight.sh"
capacity_plan="${root}/infra/ci-runner/capacity-plan.sh"
validate="${root}/infra/ci-runner/validate.sh"
runner_bicep="${root}/infra/ci-runner/runner.bicep"

for script in "${bootstrap}" "${health}" "${test_health}" "${lifecycle_preflight}" "${capacity_plan}" "${validate}"; do
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
grep -F "type: 'SystemAssigned'" "${runner_bicep}" >/dev/null
grep -F "disablePasswordAuthentication: true" "${runner_bicep}" >/dev/null
grep -F "allowExtensionOperations: false" "${runner_bicep}" >/dev/null
if grep -Fq "publicIPAddress" "${runner_bicep}"; then
  echo "A runner NIC must not declare a public IP address." >&2
  exit 1
fi

if grep -Fq "NOPASSWD:ALL" "${bootstrap}"; then
  echo "The runner account must not receive unrestricted passwordless sudo." >&2
  exit 1
fi
grep -F 'NOPASSWD: /usr/local/sbin/certigo-runner-restart' "${bootstrap}" >/dev/null
grep -F '/usr/bin/apt-get update' "${bootstrap}" >/dev/null
grep -F '/usr/bin/apt-get install -y unzip zip jq xz-utils' "${bootstrap}" >/dev/null
grep -F 'env_keep += "DEBIAN_FRONTEND"' "${bootstrap}" >/dev/null
grep -F 'read -r -s -p "Ephemeral GitHub runner registration token: " RUNNER_TOKEN' "${bootstrap}" >/dev/null
grep -F '"--register" || "$2" != "--token-stdin"' "${bootstrap}" >/dev/null
grep -F 'trap '\''unset RUNNER_TOKEN'\'' EXIT' "${bootstrap}" >/dev/null
if sed -n '/^cat > \/etc\/certigo-runner-bootstrap\.env <<EOF$/,/^EOF$/p' "${bootstrap}" |
  grep -Fq "RUNNER_TOKEN"; then
  echo "The registration token must not be persisted in the bootstrap environment file." >&2
  exit 1
fi

for endpoint in api.github.com api.nuget.org pub.dev registry.npmjs.org management.azure.com; do
  grep -F "${endpoint}" "${health}" >/dev/null
done

bash "${test_health}"
node --test "${root}/infra/ci-runner/evaluate-lifecycle.test.mjs"
node --test "${root}/infra/ci-runner/capacity-controller.test.mjs"
echo "ci-runner validation passed"
