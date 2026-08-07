#!/usr/bin/env bash
set -euo pipefail

# Re-runnable bootstrap for the Ubuntu 24.04 Certigo runner image. The GitHub
# registration token is intentionally supplied only at execution time.
RUNNER_VERSION="2.336.0"
RUNNER_SHA256="04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d"
AZURE_CLI_VERSION="2.89.0-1~noble"
MICROSOFT_KEY_FINGERPRINT="BC528686B50D79E339D3721CEB3E94ADBE1229CF"

RUNNER_USER="${RUNNER_USER:-runner}"
RUNNER_HOME="${RUNNER_HOME:-/opt/actions-runner}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-certigo-ci}"
GITHUB_URL="${GITHUB_URL:-https://github.com/gchambaud_microsoft/Certigo}"
CACHE_DIR="${CACHE_DIR:-/var/cache/certigo-runner}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this bootstrap as root." >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Cannot identify the operating system." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "This pinned bootstrap requires Ubuntu 24.04; found ${ID:-unknown} ${VERSION_ID:-unknown}." >&2
  exit 1
fi

install -d -m 0755 "${CACHE_DIR}" /usr/local/sbin
if [[ "$(readlink -f "$0")" != "/usr/local/sbin/certigo-runner-bootstrap" ]]; then
  install -m 0755 "$0" /usr/local/sbin/certigo-runner-bootstrap
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git gnupg jq sudo tar unzip zip xz-utils

install_azure_cli() {
  install -d -m 0755 /etc/apt/keyrings
  local armored_key="${CACHE_DIR}/microsoft.asc"
  local keyring="/etc/apt/keyrings/microsoft.gpg"

  curl --fail --silent --show-error --location --retry 3 \
    https://packages.microsoft.com/keys/microsoft.asc \
    --output "${armored_key}"

  local actual_fingerprint
  actual_fingerprint="$(
    gpg --batch --show-keys --with-colons "${armored_key}" |
      awk -F: '$1 == "fpr" { print $10; exit }'
  )"
  if [[ "${actual_fingerprint}" != "${MICROSOFT_KEY_FINGERPRINT}" ]]; then
    echo "Microsoft package signing key fingerprint mismatch." >&2
    exit 1
  fi

  gpg --batch --yes --dearmor --output "${keyring}" "${armored_key}"
  chmod 0644 "${keyring}"
  cat > /etc/apt/sources.list.d/azure-cli.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: noble
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: ${keyring}
EOF

  apt-get update
  apt-get install -y --allow-downgrades --no-install-recommends \
    "azure-cli=${AZURE_CLI_VERSION}"
  apt-mark hold azure-cli >/dev/null
}

if ! command -v az >/dev/null 2>&1 ||
  [[ "$(az version --query '"azure-cli"' -o tsv 2>/dev/null)" != "2.89.0" ]]; then
  install_azure_cli
fi
apt-mark hold azure-cli >/dev/null

if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${RUNNER_USER}"
fi
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${RUNNER_USER}" > /etc/sudoers.d/certigo-runner
chmod 0440 /etc/sudoers.d/certigo-runner
visudo --check --file /etc/sudoers.d/certigo-runner >/dev/null

install -d -m 0755 -o "${RUNNER_USER}" -g "${RUNNER_USER}" "${RUNNER_HOME}"

installed_runner_version=""
if [[ -x "${RUNNER_HOME}/bin/Runner.Listener" ]]; then
  installed_runner_version="$("${RUNNER_HOME}/bin/Runner.Listener" --version 2>/dev/null || true)"
fi

if [[ "${installed_runner_version}" != "${RUNNER_VERSION}" ]]; then
  archive="${CACHE_DIR}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
  curl --fail --silent --show-error --location --retry 3 \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    --output "${archive}"
  printf '%s  %s\n' "${RUNNER_SHA256}" "${archive}" | sha256sum --check --strict
  if [[ -f "${RUNNER_HOME}/.service" ]]; then
    "${RUNNER_HOME}/svc.sh" stop
  fi
  tar --extract --gzip --file "${archive}" --directory "${RUNNER_HOME}"
  "${RUNNER_HOME}/bin/installdependencies.sh"
  chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}"
fi

cat > /etc/certigo-runner-bootstrap.env <<EOF
RUNNER_VERSION=${RUNNER_VERSION}
RUNNER_SHA256=${RUNNER_SHA256}
AZURE_CLI_VERSION=${AZURE_CLI_VERSION}
GITHUB_URL=${GITHUB_URL}
RUNNER_LABELS=${RUNNER_LABELS}
EOF
chmod 0644 /etc/certigo-runner-bootstrap.env

if [[ -f "${RUNNER_HOME}/.runner" ]]; then
  configured_url="$(jq -r '.gitHubUrl // .serverUrl // empty' "${RUNNER_HOME}/.runner")"
  configured_name="$(jq -r '.agentName // empty' "${RUNNER_HOME}/.runner")"
  if [[ -n "${configured_url}" && "${configured_url%/}" != "${GITHUB_URL%/}" ]]; then
    echo "Runner is already registered to ${configured_url}; refusing implicit reassignment." >&2
    exit 1
  fi
  if [[ -n "${configured_name}" && "${configured_name}" != "${RUNNER_NAME}" ]]; then
    echo "Runner is already registered as ${configured_name}; refusing implicit rename." >&2
    exit 1
  fi
  if [[ ! -f "${RUNNER_HOME}/.service" ]]; then
    "${RUNNER_HOME}/svc.sh" install "${RUNNER_USER}"
  fi
  "${RUNNER_HOME}/svc.sh" start
  echo "Runner ${RUNNER_NAME} is already configured; service start reconciled."
  exit 0
fi

if [[ -z "${RUNNER_TOKEN:-}" ]]; then
  echo "Base image prepared. Re-run with an ephemeral RUNNER_TOKEN to register ${RUNNER_NAME}."
  exit 0
fi

runuser -u "${RUNNER_USER}" -- "${RUNNER_HOME}/config.sh" \
  --unattended \
  --url "${GITHUB_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABELS}" \
  --work "_work" \
  --disableupdate \
  --replace
"${RUNNER_HOME}/svc.sh" install "${RUNNER_USER}"
"${RUNNER_HOME}/svc.sh" start
echo "Runner ${RUNNER_NAME} registered and started."
