#!/usr/bin/env bash
set -euo pipefail

environment_file="${CERTIGO_RUNNER_ENV_FILE:-/etc/certigo/backend-runner.env}"
runner_version="2.336.0"
node_version="20.20.2"
dotnet_version="8.0.424"
github_cli_version="2.96.0"
mode="${1:-}"
requested_role="${2:-}"

case "${mode}" in
  --image-build)
    [[ $# == 1 ]] || {
      echo "Usage: $0 --image-build | --runtime <builder|deployer>" >&2
      exit 64
    }
    ;;
  --runtime)
    [[ $# == 2 && "${requested_role}" =~ ^(builder|deployer)$ ]] || {
      echo "Usage: $0 --image-build | --runtime <builder|deployer>" >&2
      exit 64
    }
    ;;
  *)
    echo "Usage: $0 --image-build | --runtime <builder|deployer>" >&2
    exit 64
    ;;
esac
[[ -r "${environment_file}" ]] || {
  echo "Backend runner environment contract is missing." >&2
  exit 1
}

# shellcheck disable=SC1090
source "${environment_file}"
: "${CERTIGO_RUNNER_CONFIG_SCHEMA:?}"
: "${CERTIGO_RUNNER_CLASS:?}"
: "${CERTIGO_RUNNER_LABEL:?}"
: "${CERTIGO_SERVICE_USER:?}"
: "${CERTIGO_RUNNER_HOME:?}"
: "${CERTIGO_SERVICE_HOME:?}"
: "${CERTIGO_IMAGE_DEFINITION_NAME:?}"
: "${CERTIGO_IMAGE_VERSION:?}"
: "${CERTIGO_IMAGE_VALIDATION_STAMP:?}"

[[ "${CERTIGO_RUNNER_CONFIG_SCHEMA}" == "certigo.ephemeral-runner/v1" ]]
[[ "$(stat -c '%u:%g:%a' "${environment_file}")" == "0:0:444" ]]

case "${CERTIGO_RUNNER_CLASS}" in
  builder)
    [[ "${CERTIGO_RUNNER_LABEL}" == "certigo-backend-builder" ]]
    [[ "${CERTIGO_SERVICE_USER}" == "certigo-builder" ]]
    ;;
  deployer)
    [[ "${CERTIGO_RUNNER_LABEL}" == "certigo-backend-deployer" ]]
    [[ "${CERTIGO_SERVICE_USER}" == "certigo-deployer" ]]
    ;;
  *)
    echo "Unknown backend runner class." >&2
    exit 1
    ;;
esac
if [[ "${mode}" == "--runtime" && "${requested_role}" != "${CERTIGO_RUNNER_CLASS}" ]]; then
  echo "Runtime validation role does not match the immutable image role." >&2
  exit 1
fi

if [[ "${CERTIGO_RUNNER_LABEL}" == *,* ]]; then
  echo "Backend runners must carry one exclusive label." >&2
  exit 1
fi
if id -nG "${CERTIGO_SERVICE_USER}" | tr ' ' '\n' | grep -Eq '^(sudo|docker)$'; then
  echo "Backend service users must not receive sudo or docker group access." >&2
  exit 1
fi
if [[ "$(
  runuser -u "${CERTIGO_SERVICE_USER}" -- \
    "${CERTIGO_RUNNER_HOME}/bin/Runner.Listener" --version
)" != "${runner_version}" ]]; then
  echo "GitHub Actions runner version mismatch." >&2
  exit 1
fi
for root_owned_path in \
  "${CERTIGO_RUNNER_HOME}" \
  "${CERTIGO_RUNNER_HOME}/run.sh" \
  "${CERTIGO_RUNNER_HOME}/bin/Runner.Listener" \
  "${CERTIGO_RUNNER_HOME}/externals/node20/bin/node"; do
  ownership="$(stat -c '%u:%g' "${root_owned_path}")"
  permissions="$(stat -c '%A' "${root_owned_path}")"
  if [[
    "${ownership}" != "0:0" ||
    "${permissions:5:1}" == "w" ||
    "${permissions:8:1}" == "w"
  ]]; then
    echo "Runner executable path is not root-owned and read-only: ${root_owned_path}." >&2
    exit 1
  fi
done

systemctl is-enabled --quiet certigo-block-imds.service
systemctl is-active --quiet certigo-block-imds.service
/usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT
if curl --silent --show-error --connect-timeout 2 --max-time 3 \
  'http://169.254.169.254/metadata/instance?api-version=2021-02-01' \
  -H 'Metadata:true' \
  --output /dev/null; then
  echo "Azure IMDS is reachable from an isolated backend image." >&2
  exit 1
fi

for state_file in .runner .credentials .credentials_rsaparams .service; do
  if [[ -e "${CERTIGO_RUNNER_HOME}/${state_file}" ]]; then
    echo "Runner registration state must not be captured in the image." >&2
    exit 1
  fi
done
if find "${CERTIGO_RUNNER_HOME}" /opt/certigo \
  -xdev -type f \
  \( -name '*.pem' -o -name '*.pfx' -o -name 'id_rsa' -o -name 'id_ed25519' \) \
  -print -quit | grep -q .; then
  echo "Credential-like material was found in the backend image." >&2
  exit 1
fi

if command -v az >/dev/null 2>&1; then
  echo "Azure CLI is forbidden in both backend runner images." >&2
  exit 1
fi
if command -v docker >/dev/null 2>&1 || [[ -S /var/run/docker.sock ]]; then
  echo "Docker must not be present in the locked backend images." >&2
  exit 1
fi

if [[ "${CERTIGO_RUNNER_CLASS}" == "builder" ]]; then
  [[ "$(node --version)" == "v${node_version}" ]]
  [[ "$(dotnet --version)" == "${dotnet_version}" ]]
  [[ "$(npm --version)" == "10.8.2" ]]
else
  for forbidden in dotnet node npm npx gcc g++ cc c++ make cmake; do
    if command -v "${forbidden}" >/dev/null 2>&1; then
      echo "Deployer image contains forbidden build tool ${forbidden}." >&2
      exit 1
    fi
  done
  [[ ! -e /opt/certigo/backend-toolchains ]]
  [[ "$(/usr/local/bin/gh --version | head -n 1)" == "gh version ${github_cli_version} "* ]]
  [[ "$(stat -c '%u:%g:%a' /usr/local/libexec/certigo/verify-deployment-bundle.mjs)" == "0:0:555" ]]
  [[ "$(head -n 1 /usr/local/libexec/certigo/verify-deployment-bundle.mjs)" == '#!/opt/actions-runner/externals/node20/bin/node' ]]
  [[ -x /opt/actions-runner/externals/node20/bin/node ]]
fi

if find "${CERTIGO_SERVICE_HOME}" \
  -mindepth 1 \
  \( -name '.git' -o -name '*.sln' -o -name '*.csproj' -o -name 'packages.lock.json' \
     -o -name '.nuget' -o -name '.npm' -o -name '.azure' -o -name '.docker' \) \
  -print -quit | grep -q .; then
  echo "Project source or cache state was captured in the backend image." >&2
  exit 1
fi
if find /usr/local/sbin \
  -maxdepth 1 -type f -name 'certigo-*' -perm /022 \
  -print -quit | grep -q .; then
  echo "A root-owned backend guard is writable by the runner account." >&2
  exit 1
fi

if [[ "${mode}" == "--runtime" ]]; then
  install -d -m 0755 -o root -g root "$(dirname "${CERTIGO_IMAGE_VALIDATION_STAMP}")"
  validation_tmp="${CERTIGO_IMAGE_VALIDATION_STAMP}.tmp.$$"
  trap 'rm -f -- "${validation_tmp:-}"' EXIT
  {
    printf 'schema=certigo.backend-image-validation/v1\n'
    printf 'runnerClass=%s\n' "${CERTIGO_RUNNER_CLASS}"
    printf 'runnerLabel=%s\n' "${CERTIGO_RUNNER_LABEL}"
    printf 'imageDefinitionName=%s\n' "${CERTIGO_IMAGE_DEFINITION_NAME}"
    printf 'imageVersion=%s\n' "${CERTIGO_IMAGE_VERSION}"
  } > "${validation_tmp}"
  chown root:root "${validation_tmp}"
  chmod 0444 "${validation_tmp}"
  mv -f -- "${validation_tmp}" "${CERTIGO_IMAGE_VALIDATION_STAMP}"
  trap - EXIT
fi

echo "Locked ${CERTIGO_RUNNER_CLASS} image contract validated."
