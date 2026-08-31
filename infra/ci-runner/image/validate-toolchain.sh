#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:---boot}"
case "${mode}" in
  --boot | --job)
    image_root="${CERTIGO_IMAGE_ROOT:-/opt/certigo/runner-image}"
    manifest="${image_root}/toolchain-manifest.json"
    sbom="${image_root}/toolchain-sbom.cdx.json"
    python_lock="${image_root}/toolchain-requirements.lock"
    toolchain_inventory="${image_root}/toolchain-inventory.tsv"
    attestation="${image_root}/attestation.json"
    ;;
  --contract)
    image_root="${CERTIGO_IMAGE_ROOT:-${script_dir}}"
    manifest="${image_root}/toolchain-manifest.json"
    sbom="${image_root}/toolchain-sbom.cdx.json"
    python_lock="${image_root}/toolchain-requirements.lock"
    attestation=""
    ;;
  *)
    echo "Usage: $0 [--boot|--job|--contract]" >&2
    exit 64
    ;;
esac

fail() {
  rm -f /run/certigo-toolchain.valid 2>/dev/null || true
  echo "Toolchain validation failed: $*" >&2
  exit 1
}

for command in jq sha256sum; do
  command -v "${command}" >/dev/null 2>&1 || fail "${command} is required"
done
for file in "${manifest}" "${sbom}" "${python_lock}"; do
  [[ -r "${file}" ]] || fail "missing ${file}"
done

jq -e '
  .schemaVersion == 1
  and .target == {
    os: "ubuntu",
    osVersion: "24.04",
    architecture: "x86_64",
    pythonVersion: "3.12.3"
  }
  and .policy.exactVersionMatch == true
  and .policy.projectDependencyCachesPersisted == false
  and .policy.dotnetWorkloads == []
  and .contentTools.prewarmedProjectDependencies == []
  and ([.tools[].version] | all(test("^[0-9]+([.][0-9]+)+$")))
  and ([.tools[] | select(.source != null) |
    .source.url | test("^https://") and (contains("/latest/") | not)] | all)
  and ([.tools[] | select(.source != null) |
    .source.digest.algorithm as $algorithm |
    if $algorithm == "sha256" then
      (.source.digest.value | test("^[0-9a-f]{64}$"))
    elif $algorithm == "sha512" then
      (.source.digest.value | test("^[0-9a-f]{128}$"))
    else false end] | all)
' "${manifest}" >/dev/null || fail "manifest policy or digest contract mismatch"

jq -e '
  .bomFormat == "CycloneDX"
  and .specVersion == "1.6"
  and ([.metadata.properties[] |
    select(.name == "certigo:project-dependency-caches-persisted") |
    .value] == ["false"])
' "${sbom}" >/dev/null || fail "CycloneDX SBOM contract mismatch"

while IFS=$'\t' read -r name version; do
  sbom_count="$(
    jq -r --arg name "${name}" --arg version "${version}" \
      '[.components[] | select((.name | ascii_downcase) == ($name | ascii_downcase)
        and .version == $version)] | length' "${sbom}"
  )"
  [[ "${sbom_count}" == "1" ]] || fail "SBOM does not uniquely describe ${name} ${version}"
done < <(
  jq -r '
    (.baseComponents[] | [.id, .version]),
    (.tools[] | select(.id != "dart-formatter") | [.id, .version])
    | @tsv
  ' "${manifest}" |
    sed -e 's/^github-actions-runner/GitHub Actions Runner/' \
      -e 's/^azure-cli/Azure CLI/' \
      -e 's/^dotnet-sdk/.NET SDK/' \
      -e 's/^node/Node.js/' \
      -e 's/^pyyaml/PyYAML/' \
      -e 's/^bicep/Bicep CLI/'
)

expected_lock_sha="$(jq -er '.artifacts.pythonLockSha256' "${manifest}")"
expected_sbom_sha="$(jq -er '.artifacts.sbomSha256' "${manifest}")"
[[ "${expected_lock_sha}" =~ ^[0-9a-f]{64}$ ]] ||
  fail "manifest Python lock hash is not pinned"
[[ "${expected_sbom_sha}" =~ ^[0-9a-f]{64}$ ]] ||
  fail "manifest SBOM hash is not pinned"
[[ "$(sha256sum "${python_lock}" | awk '{print $1}')" == "${expected_lock_sha}" ]] ||
  fail "Python lock hash mismatch"
[[ "$(sha256sum "${sbom}" | awk '{print $1}')" == "${expected_sbom_sha}" ]] ||
  fail "SBOM hash mismatch"

if [[ "${mode}" == "--contract" ]]; then
  content_lock="$(
    realpath "${image_root}/$(jq -er '.contentTools.nodeLockfile' "${manifest}")"
  )"
  expected_content_lock_sha="$(
    jq -er '.contentTools.nodeLockfileSha256' "${manifest}"
  )"
  [[ "$(sha256sum "${content_lock}" | awk '{print $1}')" == "${expected_content_lock_sha}" ]] ||
    fail "content tooling lock hash mismatch"
  echo "Toolchain repository contract valid."
  exit 0
fi

[[ -r "${attestation}" ]] || fail "missing image attestation"
[[ -r "${toolchain_inventory}" ]] || fail "missing complete toolchain inventory"
runner_home="${CERTIGO_RUNNER_HOME:-/opt/actions-runner}"
[[ "$(python3 --version 2>&1)" == "Python $(jq -er '.target.pythonVersion' "${manifest}")" ]] ||
  fail "Python version mismatch"
[[ -x "${runner_home}/bin/Runner.Listener" ]] || fail "GitHub Actions runner is missing"
expected_runner_version="$(
  jq -er '.baseComponents[] | select(.id == "github-actions-runner") | .version' "${manifest}"
)"
[[ "$("${runner_home}/bin/Runner.Listener" --version)" == "${expected_runner_version}" ]] ||
  fail "GitHub Actions runner version mismatch"
expected_az_version="$(
  jq -er '.baseComponents[] | select(.id == "azure-cli") | .version' "${manifest}"
)"
[[ "$(az version --query '"azure-cli"' -o tsv 2>/dev/null)" == "${expected_az_version}" ]] ||
  fail "Azure CLI version mismatch"

for field in manifestSha256 sbomSha256 pythonLockSha256 toolchainInventorySha256; do
  expected="$(jq -er --arg field "${field}" '.[$field]' "${attestation}")"
  case "${field}" in
    manifestSha256) file="${manifest}" ;;
    sbomSha256) file="${sbom}" ;;
    pythonLockSha256) file="${python_lock}" ;;
    toolchainInventorySha256) file="${toolchain_inventory}" ;;
  esac
  [[ "$(sha256sum "${file}" | awk '{print $1}')" == "${expected}" ]] ||
    fail "${field} attestation mismatch"
done
current_inventory="$(mktemp)"
trap 'rm -f "${current_inventory}"' EXIT
/usr/local/sbin/certigo-inventory-toolchain "${current_inventory}" ||
  fail "cannot inventory the installed toolchain"
cmp --silent "${toolchain_inventory}" "${current_inventory}" ||
  fail "complete toolchain inventory mismatch"
rm -f "${current_inventory}"
trap - EXIT

if [[ -f "${runner_home}/.runner" ]]; then
  state_seal="/etc/certigo-runner-state.sha256"
  [[ -r "${state_seal}" ]] || fail "registered runner state is not sealed"
  (cd / && sha256sum --check --strict "${state_seal}" >/dev/null) ||
    fail "registered runner state hash mismatch"
  [[ "$(stat -c '%U:%G:%a' "${runner_home}")" == "root:root:755" ]] ||
    fail "registered runner home is not sealed"
fi

while IFS=$'\t' read -r binary expected_hash; do
  binary_path="$(command -v "${binary}")" || fail "${binary} is not installed"
  [[ "$(sha256sum "${binary_path}" | awk '{print $1}')" == "${expected_hash}" ]] ||
    fail "${binary} binary hash mismatch"
done < <(jq -r '.binarySha256 | to_entries[] | [.key, .value] | @tsv' "${attestation}")

while IFS=$'\t' read -r id command expected contains json_field; do
  command_name="${command%% *}"
  command -v "${command_name}" >/dev/null 2>&1 || fail "${id} is not installed"
  output="$(
    LC_ALL=C \
      DOTNET_CLI_HOME=/run/certigo-dotnet \
      DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
      FLUTTER_ALREADY_LOCKED=true \
      bash -c "${command}" 2>&1
  )" || fail "${id} probe failed"
  if [[ -n "${json_field}" ]]; then
    output="$(jq -er --arg field "${json_field}" '.[$field]' <<<"${output}")" ||
      fail "${id} probe returned invalid JSON"
  fi
  if [[ -n "${expected}" && "${output}" != "${expected}"* ]]; then
    fail "${id} expected ${expected}; found ${output%%$'\n'*}"
  fi
  if [[ -n "${contains}" && "${output}" != *"${contains}"* ]]; then
    fail "${id} output does not contain ${contains}"
  fi
done < <(
  jq -r '.tools[] |
    [.id, .probe.command, (.probe.expected // ""), (.probe.contains // ""),
      (.probe.jsonField // "")] | @tsv' "${manifest}"
)

export DOTNET_CLI_UI_LANGUAGE=en
if dotnet workload list | awk '
  /^Installed Workload Id/ {list = 1; next}
  list && /^-+$/ {next}
  list && NF {found = 1}
  END {exit found ? 0 : 1}
'; then
  fail "unexpected .NET workload installed"
fi

for cache_path in \
  /home/runner/.nuget/packages \
  /home/runner/.npm/_cacache \
  /home/runner/.pub-cache \
  /opt/actions-runner/_work/_tool; do
  if [[ -d "${cache_path}" ]] &&
    find "${cache_path}" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    fail "persistent project/tool cache is not empty: ${cache_path}"
  fi
done

if find "${image_root}" "${CERTIGO_TOOLCHAIN_ROOT:-/opt/certigo/toolchains}" \
  -xdev \( -type f -o -type d \) -perm /022 -print -quit | grep -q .; then
  fail "immutable image artifacts are group- or world-writable"
fi

install -d -m 0755 /run
if [[ "${mode}" == "--job" ]]; then
  echo "Immutable Certigo toolchain valid for job admission."
  exit 0
fi
printf '%s\n' "$(sha256sum "${manifest}" | awk '{print $1}')" \
  >/run/certigo-toolchain.valid
chmod 0444 /run/certigo-toolchain.valid
echo "Immutable Certigo toolchain valid."
