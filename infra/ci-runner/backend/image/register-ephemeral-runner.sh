#!/usr/bin/env bash
set -euo pipefail

environment_file="${CERTIGO_RUNNER_ENV_FILE:-/etc/certigo/backend-runner.env}"
github_url="${CERTIGO_GITHUB_URL:-https://github.com/gchambaud_microsoft/Certigo}"

if ((EUID != 0)); then
  echo "Ephemeral runner registration must run as root." >&2
  exit 1
fi
if [[ "${CERTIGO_REGISTRATION_AUTHORIZED:-false}" != "true" ]]; then
  echo "Controller authorization is required for runner registration." >&2
  exit 1
fi
for value_name in \
  CERTIGO_CONTROLLER_GENERATION \
  CERTIGO_LEASE_GENERATION \
  CERTIGO_STATE_REVISION; do
  value="${!value_name:-}"
  if [[ ! "${value}" =~ ^[1-9][0-9]*$ ]]; then
    echo "${value_name} must be a positive integer." >&2
    exit 1
  fi
done

[[ -r "${environment_file}" ]] || {
  echo "Backend runner environment contract is missing." >&2
  exit 1
}
# shellcheck disable=SC1090
source "${environment_file}"
: "${CERTIGO_RUNNER_CONFIG_SCHEMA:?}"
: "${CERTIGO_RUNNER_LABEL:?}"
: "${CERTIGO_SERVICE_USER:?}"
: "${CERTIGO_RUNNER_HOME:?}"
: "${CERTIGO_JOB_ROOT:?}"
: "${CERTIGO_IMAGE_DEFINITION_NAME:?}"
: "${CERTIGO_IMAGE_VERSION:?}"
: "${CERTIGO_IMAGE_VALIDATION_STAMP:?}"
: "${CERTIGO_REGISTRATION_STAMP:?}"
: "${CERTIGO_RETIRE_STAMP:?}"

if [[ "${CERTIGO_RUNNER_CONFIG_SCHEMA}" != "certigo.ephemeral-runner/v1" ]]; then
  echo "Runner pool configuration schema is not supported." >&2
  exit 1
fi
if [[ ! "${CERTIGO_RUNNER_LABEL}" =~ ^certigo-[a-z0-9-]+$ ]]; then
  echo "Runner registration requires one immutable certigo-* label." >&2
  exit 1
fi
if [[
  -e "${CERTIGO_RUNNER_HOME}/.runner" ||
  -e "${CERTIGO_REGISTRATION_STAMP}" ||
  -e "${CERTIGO_RETIRE_STAMP}"
]]; then
  echo "A backend instance can register only once." >&2
  exit 1
fi
if [[ "$(stat -c '%u:%g:%a' "${CERTIGO_IMAGE_VALIDATION_STAMP}")" != "0:0:444" ]]; then
  echo "Root-owned runtime image validation is required before registration." >&2
  exit 1
fi
for expected_line in \
  'schema=certigo.backend-image-validation/v1' \
  "runnerClass=${CERTIGO_RUNNER_CLASS}" \
  "runnerLabel=${CERTIGO_RUNNER_LABEL}" \
  "imageDefinitionName=${CERTIGO_IMAGE_DEFINITION_NAME}" \
  "imageVersion=${CERTIGO_IMAGE_VERSION}"; do
  grep -Fx "${expected_line}" "${CERTIGO_IMAGE_VALIDATION_STAMP}" >/dev/null || {
    echo "Runtime image validation stamp does not match the runner contract." >&2
    exit 1
  }
done
: "${CERTIGO_VM_RESOURCE_ID:?}"
: "${CERTIGO_IMAGE_VERSION_RESOURCE_ID:?}"
if [[
  ! "${CERTIGO_VM_RESOURCE_ID}" =~ ^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\.Compute/virtualMachines/[^/]+$ ||
  ! "${CERTIGO_IMAGE_VERSION_RESOURCE_ID,,}" =~ /images/${CERTIGO_IMAGE_DEFINITION_NAME,,}/versions/${CERTIGO_IMAGE_VERSION,,}$
]]; then
  echo "Controller compute bindings do not match the validated image." >&2
  exit 1
fi

install -d -m 0755 -o root -g root "$(dirname "${CERTIGO_REGISTRATION_STAMP}")"
registration_tmp="${CERTIGO_REGISTRATION_STAMP}.tmp.$$"
trap 'rm -f -- "${registration_tmp:-}"' EXIT
{
  printf 'schema=certigo.backend-runner-registration/v1\n'
  printf 'vmResourceId=%s\n' "${CERTIGO_VM_RESOURCE_ID}"
  printf 'imageVersionResourceId=%s\n' "${CERTIGO_IMAGE_VERSION_RESOURCE_ID}"
} > "${registration_tmp}"
chown root:root "${registration_tmp}"
chmod 0444 "${registration_tmp}"
if ! ln -- "${registration_tmp}" "${CERTIGO_REGISTRATION_STAMP}"; then
  echo "Backend instance registration was already consumed." >&2
  exit 1
fi
rm -f -- "${registration_tmp}"
trap - EXIT

IFS= read -r registration_token || true
if [[ -z "${registration_token}" ]]; then
  echo "A short-lived GitHub registration token is required on standard input." >&2
  exit 1
fi
trap 'unset registration_token' EXIT

runner_name="${CERTIGO_RUNNER_LABEL}-$(hostname)"
(
  cd "${CERTIGO_RUNNER_HOME}"
  export RUNNER_ALLOW_RUNASROOT=1
  ./config.sh \
    --unattended \
    --ephemeral \
    --no-default-labels \
    --disableupdate \
    --url "${github_url}" \
    --token "${registration_token}" \
    --name "${runner_name}" \
    --labels "${CERTIGO_RUNNER_LABEL}" \
    --work '_work'
)
unset registration_token
trap - EXIT

cat >> "${CERTIGO_RUNNER_HOME}/.env" <<EOF
ACTIONS_RUNNER_HOOK_JOB_STARTED=/usr/local/sbin/certigo-backend-job-started
ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/usr/local/sbin/certigo-backend-job-completed
RUNNER_TEMP=${CERTIGO_JOB_ROOT}/temp
NUGET_PACKAGES=${CERTIGO_JOB_ROOT}/nuget
npm_config_cache=${CERTIGO_JOB_ROOT}/npm
DOTNET_CLI_HOME=${CERTIGO_JOB_ROOT}/dotnet-home
EOF
for state_file in .runner .credentials .credentials_rsaparams .env; do
  if [[ -e "${CERTIGO_RUNNER_HOME}/${state_file}" ]]; then
    chown "root:${CERTIGO_SERVICE_USER}" "${CERTIGO_RUNNER_HOME}/${state_file}"
    chmod 0640 "${CERTIGO_RUNNER_HOME}/${state_file}"
  fi
done
install -d -m 0700 -o "${CERTIGO_SERVICE_USER}" -g "${CERTIGO_SERVICE_USER}" \
  "${CERTIGO_RUNNER_HOME}/_diag" \
  "${CERTIGO_RUNNER_HOME}/_work"

cat > /run/certigo-backend-runner-lease <<EOF
controllerGeneration=${CERTIGO_CONTROLLER_GENERATION}
leaseGeneration=${CERTIGO_LEASE_GENERATION}
stateRevision=${CERTIGO_STATE_REVISION}
runnerClass=${CERTIGO_RUNNER_CLASS}
runnerLabel=${CERTIGO_RUNNER_LABEL}
vmResourceId=${CERTIGO_VM_RESOURCE_ID}
imageVersionResourceId=${CERTIGO_IMAGE_VERSION_RESOURCE_ID}
EOF
chown root:root /run/certigo-backend-runner-lease
chmod 0444 /run/certigo-backend-runner-lease

cat > /etc/systemd/system/certigo-backend-runner.service <<EOF
[Unit]
Description=One-job ${CERTIGO_RUNNER_LABEL} GitHub Actions runner
Requires=certigo-block-imds.service
After=network-online.target certigo-block-imds.service
Wants=network-online.target

[Service]
Type=simple
User=${CERTIGO_SERVICE_USER}
Group=${CERTIGO_SERVICE_USER}
RuntimeDirectory=certigo-backend
RuntimeDirectoryMode=0700
UMask=0077
WorkingDirectory=${CERTIGO_RUNNER_HOME}
ExecStart=${CERTIGO_RUNNER_HOME}/run.sh
ExecStopPost=+/usr/local/sbin/certigo-cleanup-backend-runner
Restart=no
KillMode=mixed
TimeoutStopSec=120
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=${CERTIGO_RUNNER_HOME}/_diag ${CERTIGO_RUNNER_HOME}/_work ${CERTIGO_JOB_ROOT} /run/certigo-backend /var/lib/certigo

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now certigo-backend-runner.service
echo "Registered one-job runner ${runner_name} with ${CERTIGO_RUNNER_LABEL}."
