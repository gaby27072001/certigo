#!/usr/bin/env bash
set -euo pipefail

runner_home="${CERTIGO_RUNNER_HOME:-/opt/actions-runner}"
runner_group="${CERTIGO_RUNNER_GROUP:-runner}"
mode="${1:-seal}"
environment_source="${
  CERTIGO_RUNNER_ENVIRONMENT_SOURCE:-/opt/certigo/runner-image/runner-ephemeral.conf
}"
state_seal="/etc/certigo-runner-state.sha256"
state_files=(
  .runner
  .credentials
  .credentials_rsaparams
  .service
  .env
  .path
)

((EUID == 0)) || {
  echo "Run the runner-state seal as root after registration and before service start." >&2
  exit 1
}
case "${mode}" in
  prepare)
    [[ ! -e "${runner_home}/.runner" ]] || {
      echo "Runner is already registered; refusing to reopen its home." >&2
      exit 1
    }
    chown "runner:${runner_group}" "${runner_home}"
    chmod 0755 "${runner_home}"
    echo "Runner home prepared for one registration."
    exit 0
    ;;
  seal) ;;
  *)
    echo "Usage: $0 [prepare|seal]" >&2
    exit 64
    ;;
esac
[[ -r "${environment_source}" ]] || {
  echo "Runner environment contract is missing." >&2
  exit 1
}
if systemctl is-active --quiet 'actions.runner.*'; then
  echo "Refusing to seal a running GitHub Actions service." >&2
  exit 1
fi
for relative in "${state_files[@]}"; do
  [[ -f "${runner_home}/${relative}" ]] || {
    echo "Runner registration state is incomplete: ${relative}" >&2
    exit 1
  }
done

environment_tmp="$(mktemp)"
trap 'rm -f "${environment_tmp}"' EXIT
cp "${runner_home}/.env" "${environment_tmp}"
while IFS='=' read -r name _; do
  [[ -n "${name}" ]] || continue
  sed -i "/^${name}=/d" "${environment_tmp}"
done <"${environment_source}"
cat "${environment_source}" >>"${environment_tmp}"
install -m 0440 -o root -g "${runner_group}" \
  "${environment_tmp}" "${runner_home}/.env"
rm -f "${environment_tmp}"
trap - EXIT

for relative in "${state_files[@]}"; do
  chown "root:${runner_group}" "${runner_home}/${relative}"
  chmod 0440 "${runner_home}/${relative}"
done
chown root:root "${runner_home}"
chmod 0755 "${runner_home}"
sha256sum "${state_files[@]/#/${runner_home}/}" >"${state_seal}"
chown root:root "${state_seal}"
chmod 0444 "${state_seal}"
systemctl daemon-reload
systemctl restart certigo-toolchain-validate.service
echo "Registered runner state sealed."
