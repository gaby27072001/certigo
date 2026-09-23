#!/usr/bin/env bash
set -euo pipefail

# Hashes alone cannot confine the legacy bootstrap, APT, pip or Flutter.
# Keep direct invocation inert until the offline installer is implemented.
echo "Image installation blocked: exhaustive offline network input consumption is not implemented (#341)." >&2
exit 1

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest="${CERTIGO_TOOLCHAIN_MANIFEST:-${script_dir}/toolchain-manifest.json}"
sbom="${script_dir}/toolchain-sbom.cyclonedx.document"
python_lock="${script_dir}/toolchain-requirements.lock"
image_root="${CERTIGO_IMAGE_ROOT:-/opt/certigo/runner-image}"
toolchain_root="${CERTIGO_TOOLCHAIN_ROOT:-/opt/certigo/toolchains}"
download_root="${CERTIGO_DOWNLOAD_ROOT:-/var/tmp/certigo-image-build}"
timings_file="${download_root}/install-timings.tsv"

if ((EUID != 0)); then
  echo "Run the immutable image prewarm as root." >&2
  exit 1
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "The pinned runner image supports x86_64 only." >&2
  exit 1
fi
# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "The pinned runner image requires Ubuntu 24.04." >&2
  exit 1
fi

for file in "${manifest}" "${sbom}" "${python_lock}"; do
  [[ -f "${file}" ]] || {
    echo "Required image input is missing: ${file}" >&2
    exit 1
  }
done

install -d -m 0755 "${image_root}" "${toolchain_root}" "${download_root}"
: >"${timings_file}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl jq libicu74 libssl3 python3.12 python3.12-venv tar unzip xz-utils

version_of() {
  jq -er --arg id "$1" '.tools[] | select(.id == $id) | .version' "${manifest}"
}

field_of() {
  local id="$1"
  local field="$2"
  jq -er --arg id "${id}" --arg field "${field}" \
    '.tools[] | select(.id == $id) | getpath($field | split("."))' "${manifest}"
}

record_timing() {
  printf '%s\t%s\n' "$1" "$2" >>"${timings_file}"
}

download_verified() {
  local id="$1"
  local output="$2"
  local url algorithm expected actual started
  url="$(field_of "${id}" "source.url")"
  algorithm="$(field_of "${id}" "source.digest.algorithm")"
  expected="$(field_of "${id}" "source.digest.value")"
  started="$(date +%s)"
  curl --fail --silent --show-error --location --retry 3 \
    --output "${output}" "${url}"
  case "${algorithm}" in
    sha256) actual="$(sha256sum "${output}" | awk '{print $1}')" ;;
    sha512) actual="$(sha512sum "${output}" | awk '{print $1}')" ;;
    *)
      echo "Unsupported digest algorithm for ${id}: ${algorithm}" >&2
      exit 1
      ;;
  esac
  if [[ "${actual}" != "${expected}" ]]; then
    echo "${id} ${algorithm} mismatch." >&2
    exit 1
  fi
  record_timing "${id}.download_verify" "$(($(date +%s) - started))"
}

replace_directory() {
  local path="$1"
  rm -rf -- "${path}"
  install -d -m 0755 "${path}"
}

install_node() {
  local version target archive started
  version="$(version_of node)"
  target="${toolchain_root}/node-${version}"
  archive="${download_root}/node.tar.xz"
  download_verified node "${archive}"
  started="$(date +%s)"
  replace_directory "${target}"
  tar -xJf "${archive}" --strip-components=1 -C "${target}"
  record_timing "node.extract" "$(($(date +%s) - started))"
}

install_dotnet() {
  local version target archive started
  version="$(version_of dotnet-sdk)"
  target="${toolchain_root}/dotnet-${version}"
  archive="${download_root}/dotnet.tar.gz"
  download_verified dotnet-sdk "${archive}"
  started="$(date +%s)"
  replace_directory "${target}"
  tar -xzf "${archive}" -C "${target}"
  record_timing "dotnet-sdk.extract" "$(($(date +%s) - started))"
}

install_flutter() {
  local version target archive started
  version="$(version_of flutter)"
  target="${toolchain_root}/flutter-${version}"
  archive="${download_root}/flutter.tar.xz"
  download_verified flutter "${archive}"
  started="$(date +%s)"
  replace_directory "${target}"
  tar -xJf "${archive}" -C "${target}"
  "${target}/flutter/bin/flutter" config --no-analytics >/dev/null
  "${target}/flutter/bin/flutter" precache --linux
  record_timing "flutter.extract_precache" "$(($(date +%s) - started))"
}

install_formatter() {
  local version target archive started
  version="$(version_of dart-formatter)"
  target="${toolchain_root}/dart-${version}"
  archive="${download_root}/dart.zip"
  download_verified dart-formatter "${archive}"
  started="$(date +%s)"
  replace_directory "${target}"
  unzip -q "${archive}" -d "${target}"
  record_timing "dart-formatter.extract" "$(($(date +%s) - started))"
}

install_bicep() {
  local version target binary
  version="$(version_of bicep)"
  target="${toolchain_root}/bicep-${version}"
  binary="${target}/bicep"
  replace_directory "${target}"
  download_verified bicep "${binary}"
  chmod 0755 "${binary}"
}

install_actionlint() {
  local version target archive started
  version="$(version_of actionlint)"
  target="${toolchain_root}/actionlint-${version}"
  archive="${download_root}/actionlint.tar.gz"
  download_verified actionlint "${archive}"
  started="$(date +%s)"
  replace_directory "${target}"
  tar -xzf "${archive}" -C "${target}" actionlint
  chmod 0755 "${target}/actionlint"
  record_timing "actionlint.extract" "$(($(date +%s) - started))"
}

install_python_tools() {
  local python_version target started
  python_version="$(jq -er '.target.pythonVersion' "${manifest}")"
  if [[ "$(python3.12 --version | awk '{print $2}')" != "${python_version}" ]]; then
    echo "Ubuntu Python does not match the immutable manifest." >&2
    exit 1
  fi
  target="${toolchain_root}/python-${python_version}"
  rm -rf -- "${target}"
  started="$(date +%s)"
  python3.12 -m venv "${target}"
  "${target}/bin/python" -m pip install \
    --disable-pip-version-check --no-deps --require-hashes \
    -r "${python_lock}"
  record_timing "python-tools.install" "$(($(date +%s) - started))"
}

install_node
install_dotnet
install_flutter
install_formatter
install_bicep
install_actionlint
install_python_tools

node_version="$(version_of node)"
dotnet_version="$(version_of dotnet-sdk)"
flutter_version="$(version_of flutter)"
formatter_version="$(version_of dart-formatter)"
bicep_version="$(version_of bicep)"
actionlint_version="$(version_of actionlint)"
python_version="$(jq -er '.target.pythonVersion' "${manifest}")"

ln -sfn "${toolchain_root}/node-${node_version}/bin/node" /usr/local/bin/node
ln -sfn "${toolchain_root}/node-${node_version}/bin/npm" /usr/local/bin/npm
ln -sfn "${toolchain_root}/node-${node_version}/bin/npx" /usr/local/bin/npx
ln -sfn "${toolchain_root}/dotnet-${dotnet_version}/dotnet" /usr/local/bin/dotnet
ln -sfn "${toolchain_root}/flutter-${flutter_version}/flutter/bin/flutter" /usr/local/bin/flutter
ln -sfn "${toolchain_root}/flutter-${flutter_version}/flutter/bin/dart" /usr/local/bin/dart
ln -sfn "${toolchain_root}/dart-${formatter_version}/dart-sdk/bin/dart" \
  /usr/local/bin/dart-format-3.6.0
ln -sfn "${toolchain_root}/bicep-${bicep_version}/bicep" /usr/local/bin/bicep
ln -sfn "${toolchain_root}/actionlint-${actionlint_version}/actionlint" \
  /usr/local/bin/actionlint
ln -sfn "${toolchain_root}/python-${python_version}/bin/checkov" /usr/local/bin/checkov
ln -sfn "${toolchain_root}/python-${python_version}/bin/python" /usr/local/bin/python3

install -m 0644 "${manifest}" "${image_root}/toolchain-manifest.json"
install -m 0644 "${sbom}" "${image_root}/toolchain-sbom.cyclonedx.document"
install -m 0644 "${python_lock}" "${image_root}/toolchain-requirements.lock"
install -m 0755 "${script_dir}/validate-toolchain.sh" \
  /usr/local/sbin/certigo-validate-toolchain
install -m 0755 "${script_dir}/inventory-toolchain.sh" \
  /usr/local/sbin/certigo-inventory-toolchain
install -m 0755 "${script_dir}/seal-runner-state.sh" \
  /usr/local/sbin/certigo-seal-runner-state
install -m 0755 "${script_dir}/job-temp.sh" /usr/local/sbin/certigo-job-temp
ln -sfn /usr/local/sbin/certigo-job-temp /usr/local/sbin/certigo-job-start
ln -sfn /usr/local/sbin/certigo-job-temp /usr/local/sbin/certigo-job-complete
install -m 0755 "${script_dir}/certigo-toolchain-guard-generator" \
  /usr/lib/systemd/system-generators/certigo-toolchain-guard
install -m 0644 "${script_dir}/certigo-toolchain-validate.service" \
  /etc/systemd/system/certigo-toolchain-validate.service
install -m 0644 "${script_dir}/certigo-job-temp-mount.service" \
  /etc/systemd/system/certigo-job-temp-mount.service
install -m 0644 "${script_dir}/runner-ephemeral.conf" \
  "${image_root}/runner-ephemeral.conf"

chown -R root:root "${toolchain_root}" "${RUNNER_HOME:-/opt/actions-runner}"
chmod -R a-w "${toolchain_root}" "${RUNNER_HOME:-/opt/actions-runner}"
chmod 0755 "${RUNNER_HOME:-/opt/actions-runner}"
/usr/local/sbin/certigo-inventory-toolchain \
  "${image_root}/toolchain-inventory.tsv"
manifest_sha="$(sha256sum "${image_root}/toolchain-manifest.json" | awk '{print $1}')"
sbom_sha="$(sha256sum "${image_root}/toolchain-sbom.cyclonedx.document" | awk '{print $1}')"
lock_sha="$(sha256sum "${image_root}/toolchain-requirements.lock" | awk '{print $1}')"
toolchain_inventory_sha="$(
  sha256sum "${image_root}/toolchain-inventory.tsv" | awk '{print $1}'
)"
timings_json="$(
  jq -Rn '[inputs | split("\t") | {step: .[0], seconds: (.[1] | tonumber)}]' \
    <"${timings_file}"
)"
binary_hashes="$(
  jq -n \
    --arg node "$(sha256sum /usr/local/bin/node | awk '{print $1}')" \
    --arg dotnet "$(sha256sum /usr/local/bin/dotnet | awk '{print $1}')" \
    --arg flutter "$(sha256sum /usr/local/bin/flutter | awk '{print $1}')" \
    --arg dart "$(sha256sum /usr/local/bin/dart | awk '{print $1}')" \
    --arg bicep "$(sha256sum /usr/local/bin/bicep | awk '{print $1}')" \
    --arg actionlint "$(sha256sum /usr/local/bin/actionlint | awk '{print $1}')" \
    '{node: $node, dotnet: $dotnet, flutter: $flutter, dart: $dart,
      bicep: $bicep, actionlint: $actionlint}'
)"
jq -n \
  --arg schemaVersion "1" \
  --arg builtAt "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" \
  --arg manifestSha256 "${manifest_sha}" \
  --arg sbomSha256 "${sbom_sha}" \
  --arg pythonLockSha256 "${lock_sha}" \
  --arg toolchainInventorySha256 "${toolchain_inventory_sha}" \
  --arg pythonPackageVersion "$(dpkg-query -W -f='${Version}' python3.12)" \
  --argjson timings "${timings_json}" \
  --argjson binaryHashes "${binary_hashes}" \
  '{
    schemaVersion: ($schemaVersion | tonumber),
    builtAt: $builtAt,
    manifestSha256: $manifestSha256,
    sbomSha256: $sbomSha256,
    pythonLockSha256: $pythonLockSha256,
    toolchainInventorySha256: $toolchainInventorySha256,
    pythonPackageVersion: $pythonPackageVersion,
    installTimings: $timings,
    binarySha256: $binaryHashes
  }' >"${image_root}/attestation.json"
chmod -R a-w "${image_root}"

systemctl daemon-reload
systemctl enable certigo-toolchain-validate.service certigo-job-temp-mount.service
/usr/local/sbin/certigo-validate-toolchain --boot
rm -rf -- "${download_root}"
echo "Immutable Certigo toolchain prewarm completed."
