#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
bootstrap="${root}/infra/ci-runner/bootstrap.sh"
health="${root}/infra/ci-runner/health-probe.sh"
pilot_health="${root}/infra/ci-runner/pilot-health.sh"
pilot_preflight="${root}/infra/ci-runner/pilot-preflight.sh"
pilot_register="${root}/infra/ci-runner/pilot-register.sh"
register_pilot="${root}/infra/ci-runner/register-pilot.ps1"
test_health="${root}/infra/ci-runner/test-health-probe.sh"
lifecycle_preflight="${root}/infra/ci-runner/lifecycle-preflight.sh"
capacity_plan="${root}/infra/ci-runner/capacity-plan.sh"
validate="${root}/infra/ci-runner/validate.sh"
runner_bicep="${root}/infra/ci-runner/runner.bicep"
pilot_bicep="${root}/infra/ci-runner/pilot.bicep"
image_dir="${root}/infra/ci-runner/image"

for script in \
  "${bootstrap}" \
  "${health}" \
  "${pilot_health}" \
  "${pilot_preflight}" \
  "${pilot_register}" \
  "${test_health}" \
  "${lifecycle_preflight}" \
  "${capacity_plan}" \
  "${image_dir}/prewarm-toolchain.sh" \
  "${image_dir}/validate-toolchain.sh" \
  "${image_dir}/job-temp.sh" \
  "${image_dir}/inventory-toolchain.sh" \
  "${image_dir}/seal-runner-state.sh" \
  "${image_dir}/measure-cold-start.sh" \
  "${image_dir}/certigo-toolchain-guard-generator" \
  "${validate}"; do
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

declared_pilot_bootstrap_sha="$(
  awk -F"'" '/^var bootstrapSha256 =/ { print $2 }' "${pilot_bicep}"
)"
actual_pilot_bootstrap_sha="$(
  {
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      "export CERTIGO_RUNNER_LABELS='certigo-pr,certigo-pr-pilot'" \
      "export CERTIGO_BLOCK_IMDS='true'"
    cat "${bootstrap}"
  } | sha256sum | awk '{ print $1 }'
)"
if [[ "${declared_pilot_bootstrap_sha}" != "${actual_pilot_bootstrap_sha}" ]]; then
  echo "pilot.bicep bootstrapSha256 does not match the wrapped pilot customData." >&2
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
grep -F 'certigo-block-imds.service' "${bootstrap}" >/dev/null
grep -F '169.254.169.254/32' "${bootstrap}" >/dev/null
grep -F 'BLOCK_IMDS="${CERTIGO_BLOCK_IMDS:-false}"' "${bootstrap}" >/dev/null
grep -F 'DefaultDependencies=no' "${bootstrap}" >/dev/null
grep -F 'Before=network-pre.target' "${bootstrap}" >/dev/null
if sed -n '/^cat > \/etc\/certigo-runner-bootstrap\.env <<EOF$/,/^EOF$/p' "${bootstrap}" |
  grep -Fq "RUNNER_TOKEN"; then
  echo "The registration token must not be persisted in the bootstrap environment file." >&2
  exit 1
fi

for endpoint in api.github.com api.nuget.org pub.dev registry.npmjs.org management.azure.com; do
  grep -F "${endpoint}" "${health}" >/dev/null
done

grep -F "orchestrationMode: 'Flexible'" "${pilot_bicep}" >/dev/null
grep -F "securityType: 'TrustedLaunch'" "${pilot_bicep}" >/dev/null
grep -F "destinationAddressPrefix: 'AzurePlatformIMDS'" "${pilot_bicep}" >/dev/null
grep -F "destinationAddressPrefix: 'VirtualNetwork'" "${pilot_bicep}" >/dev/null
grep -F 'param blockImdsAtNsg bool = true' "${pilot_bicep}" >/dev/null
grep -F "runnerLabels string = 'certigo-pr,certigo-pr-pilot'" "${pilot_bicep}" >/dev/null
grep -F "export CERTIGO_BLOCK_IMDS=\\'true\\'" "${pilot_bicep}" >/dev/null
if grep -Fq 'certigo-trusted' "${pilot_bicep}"; then
  echo "The PR-only pilot must not carry a trusted label." >&2
  exit 1
fi
if grep -Eq '^[[:space:]]*identity:' "${pilot_bicep}"; then
  echo "The PR-only pilot must not declare a managed identity." >&2
  exit 1
fi
if grep -Fq 'publicIPAddressConfiguration' "${pilot_bicep}"; then
  echo "The PR-only pilot NIC must not declare a public IP." >&2
  exit 1
fi
grep -F 'pre-registration preflight passed' "${pilot_preflight}" >/dev/null
grep -F 'Refusing registration while Azure IMDS is reachable.' "${pilot_register}" >/dev/null
grep -F '/run/certigo-pr-preflight.ok' "${pilot_preflight}" >/dev/null
grep -F '/run/certigo-pr-preflight.ok' "${pilot_register}" >/dev/null
grep -F 'protectedParameters' "${register_pilot}" >/dev/null
grep -F "'certigo-pr-final-preflight'" "${register_pilot}" >/dev/null
grep -F "'certigo-pr-secure-register'" "${register_pilot}" >/dev/null
if grep -Eq -- '--token([ =]|$)' "${register_pilot}"; then
  echo "The repository-scoped registration token must not appear in process arguments." >&2
  exit 1
fi

preflight_cloud_init_line="$(grep -nF 'cloud-init status --wait' "${pilot_preflight}" | cut -d: -f1)"
preflight_imds_line="$(grep -nF 'http://169.254.169.254/metadata/instance' "${pilot_preflight}" | cut -d: -f1)"
preflight_health_line="$(grep -nF 'https://api.github.com/meta' "${pilot_preflight}" | cut -d: -f1)"
preflight_attestation_line="$(grep -nF 'cat > /run/certigo-pr-preflight.ok' "${pilot_preflight}" | cut -d: -f1)"
register_imds_line="$(grep -nF 'http://169.254.169.254/metadata/instance' "${pilot_register}" | cut -d: -f1)"
register_attestation_line="$(grep -nF 'preflight_attestation="/run/certigo-pr-preflight.ok"' "${pilot_register}" | cut -d: -f1)"
register_token_line="$(grep -nF 'registration_token="$1"' "${pilot_register}" | cut -d: -f1)"
operator_preflight_line="$(grep -nF "\$preflightOutput = Invoke-ManagedRunCommand" "${register_pilot}" | cut -d: -f1)"
operator_token_line="$(grep -nF "\$registrationToken = Invoke-NativeText" "${register_pilot}" | cut -d: -f1)"
operator_registration_line="$(grep -nF "\$registrationOutput = Invoke-ManagedRunCommand" "${register_pilot}" | cut -d: -f1)"
if ! (( preflight_cloud_init_line < preflight_imds_line &&
  preflight_imds_line < preflight_health_line &&
  preflight_health_line < preflight_attestation_line &&
  register_imds_line < register_attestation_line &&
  register_attestation_line < register_token_line &&
  operator_preflight_line < operator_token_line &&
  operator_token_line < operator_registration_line )); then
  echo "Pilot ordering must remain provisioning -> IMDS hardening -> health -> token -> registration." >&2
  exit 1
fi

bash "${test_health}"
node --test "${root}/infra/ci-runner/evaluate-lifecycle.test.mjs"
node --test "${root}/infra/ci-runner/capacity-controller.test.mjs"
node --check "${root}/infra/ci-runner/scale-in-safety.mjs"
node "${image_dir}/generate-toolchain-sbom.mjs" --check
bash "${image_dir}/validate-toolchain.sh" --contract
node --test "${image_dir}/toolchain-contract.test.mjs"

contract_fixture="$(mktemp -d)"
generator_fixture="$(mktemp -d)"
trap 'rm -rf "${contract_fixture}" "${generator_fixture}"' EXIT
cp \
  "${image_dir}/toolchain-manifest.json" \
  "${image_dir}/toolchain-sbom.cdx.json" \
  "${image_dir}/toolchain-requirements.lock" \
  "${contract_fixture}/"
printf ' ' >>"${contract_fixture}/toolchain-sbom.cdx.json"
if CERTIGO_IMAGE_ROOT="${contract_fixture}" \
  bash "${image_dir}/validate-toolchain.sh" --contract >/dev/null 2>&1; then
  echo "Toolchain contract must fail closed when the SBOM hash changes." >&2
  exit 1
fi

mkdir -p "${generator_fixture}/units" "${generator_fixture}/generated"
touch "${generator_fixture}/units/actions.runner.Certigo.test.service"
CERTIGO_SYSTEMD_UNIT_DIR="${generator_fixture}/units" \
  bash "${image_dir}/certigo-toolchain-guard-generator" \
  "${generator_fixture}/generated" \
  "${generator_fixture}/early" \
  "${generator_fixture}/late"
generated_guard="$(
  find "${generator_fixture}/generated" -type f -name '50-certigo-toolchain-guard.conf'
)"
[[ -n "${generated_guard}" ]]
grep -F 'Requires=certigo-toolchain-validate.service' "${generated_guard}" >/dev/null
grep -F 'Requires=certigo-job-temp-mount.service' "${generated_guard}" >/dev/null
rm -rf "${contract_fixture}" "${generator_fixture}"
trap - EXIT
echo "ci-runner validation passed"
