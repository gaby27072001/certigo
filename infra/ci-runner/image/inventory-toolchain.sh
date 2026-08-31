#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "Usage: $0 <output-file>" >&2
  exit 64
fi

output="$1"
toolchain_root="${CERTIGO_TOOLCHAIN_ROOT:-/opt/certigo/toolchains}"
runner_home="${CERTIGO_RUNNER_HOME:-/opt/actions-runner}"
azure_cli_root="${CERTIGO_AZURE_CLI_ROOT:-/opt/az}"
roots=("${toolchain_root}" "${runner_home}" "${azure_cli_root}")
entries=(
  /etc/systemd/system/certigo-job-temp-mount.service
  /etc/systemd/system/certigo-toolchain-validate.service
  /usr/bin/az
  /usr/lib/systemd/system-generators/certigo-toolchain-guard
  /usr/local/bin/actionlint
  /usr/local/bin/bicep
  /usr/local/bin/checkov
  /usr/local/bin/dart
  /usr/local/bin/dart-format-3.6.0
  /usr/local/bin/dotnet
  /usr/local/bin/flutter
  /usr/local/bin/node
  /usr/local/bin/npm
  /usr/local/bin/npx
  /usr/local/bin/python3
  /usr/local/sbin/certigo-inventory-toolchain
  /usr/local/sbin/certigo-job-complete
  /usr/local/sbin/certigo-job-start
  /usr/local/sbin/certigo-job-temp
  /usr/local/sbin/certigo-runner-bootstrap
  /usr/local/sbin/certigo-runner-restart
  /usr/local/sbin/certigo-seal-runner-state
  /usr/local/sbin/certigo-validate-toolchain
)
optional_entries=(
  /etc/systemd/system/certigo-block-imds.service
  /usr/local/sbin/certigo-block-imds
)

for root in "${roots[@]}"; do
  [[ -d "${root}" ]] || {
    echo "Inventory root is missing: ${root}" >&2
    exit 1
  }
done

is_mutable_runner_state() {
  local path="$1"
  [[ "${path}" == "${runner_home}/_diag" ||
    "${path}" == "${runner_home}/_diag/"* ||
    "${path}" == "${runner_home}/_work" ||
    "${path}" == "${runner_home}/_work/"* ||
    "${path}" == "${runner_home}/.runner" ||
    "${path}" == "${runner_home}/.credentials" ||
    "${path}" == "${runner_home}/.credentials_rsaparams" ||
    "${path}" == "${runner_home}/.service" ||
    "${path}" == "${runner_home}/.env" ||
    "${path}" == "${runner_home}/.path" ]]
}

emit_entry() {
  local path="$1"
  local type mode owner payload
  is_mutable_runner_state "${path}" && return
  mode="$(stat -c '%a' "${path}")"
  owner="$(stat -c '%u:%g' "${path}")"
  if [[ -L "${path}" ]]; then
    type="l"
    payload="$(readlink "${path}")"
  elif [[ -f "${path}" ]]; then
    type="f"
    payload="$(sha256sum "${path}" | awk '{print $1}')"
  elif [[ -d "${path}" ]]; then
    type="d"
    payload="-"
  else
    echo "Unsupported filesystem entry in immutable toolchain: ${path}" >&2
    exit 1
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "${type}" "${mode}" "${owner}" "${path}" "${payload}"
}

{
  while IFS= read -r -d '' path; do
    emit_entry "${path}"
  done < <(find "${roots[@]}" -xdev -print0 | sort -z)
  for path in "${entries[@]}"; do
    [[ -e "${path}" || -L "${path}" ]] || {
      echo "Expected toolchain link is missing: ${path}" >&2
      exit 1
    }
    emit_entry "${path}"
  done
  for path in "${optional_entries[@]}"; do
    [[ -e "${path}" || -L "${path}" ]] && emit_entry "${path}"
  done
} >"${output}"
