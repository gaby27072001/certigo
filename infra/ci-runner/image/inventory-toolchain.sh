#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

roots_only=false
if (($# == 2)) && [[ "$1" == "--roots-only" ]]; then
  roots_only=true
  shift
fi
if (($# != 1)); then
  echo "Usage: $0 [--roots-only] <output-file>" >&2
  exit 64
fi

output="$1"
toolchain_root="${CERTIGO_TOOLCHAIN_ROOT:-/opt/certigo/toolchains}"
runner_home="${CERTIGO_RUNNER_HOME:-/opt/actions-runner}"
azure_cli_root="${CERTIGO_AZURE_CLI_ROOT:-/opt/az}"
# Whole trees, so any added APT source, preference, apt.conf fragment or
# cloud-init override is seen, not only the files written by the installer.
apt_root="${CERTIGO_APT_ROOT:-/etc/apt}"
cloud_config_root="${CERTIGO_CLOUD_CONFIG_ROOT:-/etc/cloud/cloud.cfg.d}"
roots=("${toolchain_root}" "${runner_home}" "${azure_cli_root}" "${apt_root}" "${cloud_config_root}")
entries=(
  /etc/gitconfig
  /etc/systemd/system/apt-daily-upgrade.service
  /etc/systemd/system/apt-daily-upgrade.timer
  /etc/systemd/system/apt-daily.service
  /etc/systemd/system/apt-daily.timer
  /etc/systemd/system/certigo-job-temp-mount.service
  /etc/systemd/system/certigo-toolchain-validate.service
  /etc/systemd/system/snapd.snap-repair.service
  /etc/systemd/system/snapd.snap-repair.timer
  /etc/systemd/system/unattended-upgrades.service
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
# Mutable registration state is sealed separately by certigo-seal-runner-state.
excluded_state=(.runner .credentials .credentials_rsaparams .service .env .path)

for root in "${roots[@]}"; do
  [[ -d "${root}" ]] || {
    echo "Inventory root is missing: ${root}" >&2
    exit 1
  }
done

emit_entry() {
  local path="$1"
  local type mode owner payload
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

# The same selection feeds metadata and hashing: runner _diag/_work subtrees
# and registration state are never part of the immutable inventory.
select_paths() {
  local exclusions=(-path "${runner_home}/_diag" -o -path "${runner_home}/_work")
  local name
  for name in "${excluded_state[@]}"; do
    exclusions+=(-o -path "${runner_home}/${name}")
  done
  find "${roots[@]}" -xdev \( "${exclusions[@]}" \) -prune -o "$@"
}

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

# Records are tab separated: a tab or newline in a name would be ambiguous.
unsafe="$(select_paths \( -name $'*\t*' -o -name $'*\n*' -o -lname $'*\t*' \
  -o -lname $'*\n*' \) -print -quit)"
[[ -z "${unsafe}" ]] || {
  echo "Unsupported file name in immutable toolchain: ${unsafe}" >&2
  exit 1
}
unsupported="$(select_paths ! \( -type f -o -type d -o -type l \) -print -quit)"
[[ -z "${unsupported}" ]] || {
  echo "Unsupported filesystem entry in immutable toolchain: ${unsupported}" >&2
  exit 1
}

# One metadata pass and one batched hashing pass instead of several processes
# per file: the toolchains hold tens of thousands of files.
select_paths -printf '%p\t%y\t%m\t%U:%G\t%l\n' | sort -t $'\t' -k1,1 >"${work}/records"
select_paths -type f -print0 | xargs -0 -r sha256sum --zero -- | tr '\0' '\n' |
  sed -E 's/^([0-9a-f]{64})  /\1\t/' >"${work}/hashes"

{
  awk -F '\t' -v OFS='\t' '
    FNR == NR { hash[$2] = $1; next }
    $2 == "f" {
      if (!($1 in hash)) { print "Unhashed file: " $1 > "/dev/stderr"; exit 1 }
      print "f", $3, $4, $1, hash[$1]; next
    }
    $2 == "l" { print "l", $3, $4, $1, $5; next }
    $2 == "d" { print "d", $3, $4, $1, "-"; next }
    { print "Unsupported filesystem entry in immutable toolchain: " $1 > "/dev/stderr"; exit 1 }
  ' "${work}/hashes" "${work}/records"
  if [[ "${roots_only}" == false ]]; then
    for path in "${entries[@]}"; do
      [[ -e "${path}" || -L "${path}" ]] || {
        echo "Expected toolchain link is missing: ${path}" >&2
        exit 1
      }
      emit_entry "${path}"
    done
    for path in "${optional_entries[@]}"; do
      if [[ -e "${path}" || -L "${path}" ]]; then
        emit_entry "${path}"
      fi
    done
  fi
} >"${output}"
[[ "$(wc -l <"${work}/hashes")" == "$(awk -F '\t' '$2 == "f"' "${work}/records" | wc -l)" ]] || {
  echo "Hashed file count differs from the inventoried file count." >&2
  exit 1
}