#!/usr/bin/env bash
set -euo pipefail
set +x

# Keep all downloaded executables and the emulator image immutable. The matching
# repository test verifies these pins and the Bicep customData digest.
RUNNER_VERSION="2.336.0"
RUNNER_SHA256="04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d"
DOCKER_VERSION="29.7.2"
DOCKER_SHA256="803d433f226db4776e1768fd319fc6c6e4935a456acf84fcc0080818b854bc8f"
COSMOS_IMAGE="mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator@sha256:dc583d6e1620c38e13e2d85ade2ea7b693ba8101c90e449b5504c0b3b321669c"

RUNNER_USER="runner"
RUNNER_HOME="/opt/actions-runner"
RUNNER_NAME="$(hostname)"
RUNNER_LABELS="certigo-cosmos-emulator"
GITHUB_URL="https://github.com/gchambaud_microsoft/Certigo"
CACHE_DIR="/var/cache/certigo-cosmos-runner"
STATE_DIR="/var/lib/certigo-cosmos-runner"
BOOTSTRAP_COMPLETE="${STATE_DIR}/bootstrap-complete"
BOOTSTRAP_LOCK="${STATE_DIR}/bootstrap.lock"

registration_mode=""
case "$#" in
  0)
    ;;
  2)
    if [[ "$1" != "--register" || "$2" != "--token-stdin" ]]; then
      echo "Usage: $0 [--register --token-stdin]" >&2
      exit 2
    fi
    registration_mode="stdin"
    ;;
  *)
    echo "Usage: $0 [--register --token-stdin]" >&2
    exit 2
    ;;
esac

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

APT_SOURCE_FILES=(
  /etc/apt/sources.list
  /etc/apt/sources.list.d/*.list
  /etc/apt/sources.list.d/*.sources
)

# The NSG permits only HTTPS egress, and the Azure mirror configured by the image
# (azure.archive.ubuntu.com) does not serve HTTPS: measured 2026-09-25, TCP 443
# times out while archive.ubuntu.com and security.ubuntu.com answer 200 over HTTPS.
normalize_apt_sources() {
  local sources
  for sources in "$@"; do
    [[ -f "${sources}" ]] || continue
    sed -i -E \
      -e 's#http://([a-z0-9-]+\.)*archive\.ubuntu\.com/ubuntu(/?)([[:space:]]|$)#https://archive.ubuntu.com/ubuntu/\3#g' \
      -e 's#http://security\.ubuntu\.com/ubuntu(/?)([[:space:]]|$)#https://security.ubuntu.com/ubuntu/\2#g' \
      "${sources}"
  done
}

# Fail closed instead of letting apt time out on a clear-text source.
assert_https_apt_sources() {
  local sources
  for sources in "$@"; do
    [[ -f "${sources}" ]] || continue
    if grep -qE '^[[:space:]]*(URIs:|deb|deb-src)[[:space:]].*http://' "${sources}"; then
      echo "${sources} still uses a clear-text HTTP apt source; the NSG allows only HTTPS." >&2
      return 1
    fi
  done
}

# Bounded retries cover a concurrent apt run holding the locks and transient
# mirror errors: at most 8 attempts of up to 60 s lock wait plus 15 s pause.
apt_get() {
  local attempt
  for attempt in 1 2 3 4 5 6 7 8; do
    if apt-get -o DPkg::Lock::Timeout=60 -o Acquire::Retries=3 "$@"; then
      return 0
    fi
    echo "apt-get $* failed (attempt ${attempt}/8); retrying in 15 seconds." >&2
    sleep 15
  done
  return 1
}

prepare_host() {
install -d -m 0755 "${CACHE_DIR}" /usr/local/sbin
if [[ "$(readlink -f "$0")" != "/usr/local/sbin/certigo-cosmos-runner-bootstrap" ]]; then
  install -m 0755 "$0" /usr/local/sbin/certigo-cosmos-runner-bootstrap
fi

# This VM lives for one job: background package maintenance must not race the
# bootstrap for the apt and dpkg locks. Running units are left to finish; apt_get
# waits for their locks instead of interrupting dpkg.
systemctl disable --now apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true

normalize_apt_sources "${APT_SOURCE_FILES[@]}"
assert_https_apt_sources "${APT_SOURCE_FILES[@]}"

export DEBIAN_FRONTEND=noninteractive
apt_get update
apt_get install -y --no-install-recommends \
  ca-certificates curl git iptables openssl python3 tar

if ! id "${RUNNER_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${RUNNER_USER}"
fi
if ! getent group docker >/dev/null 2>&1; then
  groupadd --system docker
fi
usermod --append --groups docker "${RUNNER_USER}"

installed_docker_version="$(docker version --format '{{.Client.Version}}' 2>/dev/null || true)"
if [[ "${installed_docker_version}" != "${DOCKER_VERSION}" ]]; then
  docker_archive="${CACHE_DIR}/docker-${DOCKER_VERSION}.tgz"
  docker_extract="$(mktemp -d)"
  curl --fail --silent --show-error --location --retry 3 \
    "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" \
    --output "${docker_archive}"
  printf '%s  %s\n' "${DOCKER_SHA256}" "${docker_archive}" |
    sha256sum --check --strict
  tar --extract --gzip --file "${docker_archive}" --directory "${docker_extract}"
  find "${docker_extract}/docker" -maxdepth 1 -type f -exec \
    install -m 0755 -o root -g root {} /usr/local/bin/ \;
  rm -rf -- "${docker_extract}"
fi

install -d -m 0755 /etc/docker
cat > /etc/docker/daemon.json <<'EOF'
{
  "bip": "172.31.0.1/24",
  "default-address-pools": [
    {
      "base": "172.30.0.0/16",
      "size": 24
    }
  ],
  "icc": false,
  "iptables": true,
  "live-restore": false,
  "log-driver": "local",
  "log-opts": {
    "max-file": "2",
    "max-size": "20m"
  },
  "no-new-privileges": true,
  "userland-proxy": false
}
EOF

cat > /etc/systemd/system/containerd.service <<'EOF'
[Unit]
Description=containerd container runtime
After=network.target

[Service]
ExecStart=/usr/local/bin/containerd
Delegate=yes
KillMode=process
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/docker.service <<'EOF'
[Unit]
Description=Docker Application Container Engine
After=network-online.target containerd.service
Wants=network-online.target
Requires=containerd.service

[Service]
Type=notify
ExecStart=/usr/local/bin/dockerd --host=unix:///var/run/docker.sock --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
Delegate=yes
KillMode=process
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Restart=on-failure
RestartSec=5
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/sbin/certigo-block-imds <<EOF
#!/usr/bin/env bash
set -euo pipefail

/usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT 2>/dev/null ||
  /usr/sbin/iptables -I OUTPUT 1 -d 169.254.169.254/32 -j REJECT
/usr/sbin/iptables -C DOCKER-USER -d 169.254.169.254/32 -j REJECT 2>/dev/null ||
  /usr/sbin/iptables -I DOCKER-USER 1 -d 169.254.169.254/32 -j REJECT
EOF
chmod 0755 /usr/local/sbin/certigo-block-imds

cat > /etc/systemd/system/certigo-block-imds.service <<'EOF'
[Unit]
Description=Block Azure IMDS from the runner user and Docker bridge
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/certigo-block-imds
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now docker.service certigo-block-imds.service
systemctl is-active --quiet docker.service
if [[ "$(docker info --format '{{.ServerVersion}}')" != "${DOCKER_VERSION}" ]]; then
  echo "The Docker daemon version does not match the pinned client." >&2
  exit 1
fi

docker pull "${COSMOS_IMAGE}" >/dev/null
if ! docker image inspect --format '{{join .RepoDigests "\n"}}' "${COSMOS_IMAGE}" |
  grep -Fx "${COSMOS_IMAGE}" >/dev/null; then
  echo "The preloaded Cosmos emulator image digest does not match the pin." >&2
  exit 1
fi

install -d -m 0755 -o "${RUNNER_USER}" -g "${RUNNER_USER}" "${RUNNER_HOME}"
installed_runner_version=""
if [[ -x "${RUNNER_HOME}/bin/Runner.Listener" ]]; then
  installed_runner_version="$("${RUNNER_HOME}/bin/Runner.Listener" --version 2>/dev/null || true)"
fi

if [[ "${installed_runner_version}" != "${RUNNER_VERSION}" ]]; then
  runner_archive="${CACHE_DIR}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
  curl --fail --silent --show-error --location --retry 3 \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    --output "${runner_archive}"
  printf '%s  %s\n' "${RUNNER_SHA256}" "${runner_archive}" |
    sha256sum --check --strict
  tar --extract --gzip --file "${runner_archive}" --directory "${RUNNER_HOME}"
  # installdependencies.sh calls apt itself, without lock waits: retry it.
  for attempt in 1 2 3 4 5 6; do
    if "${RUNNER_HOME}/bin/installdependencies.sh"; then
      break
    fi
    if (( attempt == 6 )); then
      echo "The runner dependency installer failed 6 times." >&2
      exit 1
    fi
    sleep 20
  done
  chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}"
fi

cat > /etc/certigo-cosmos-runner.env <<EOF
RUNNER_VERSION=${RUNNER_VERSION}
RUNNER_SHA256=${RUNNER_SHA256}
DOCKER_VERSION=${DOCKER_VERSION}
DOCKER_SHA256=${DOCKER_SHA256}
COSMOS_IMAGE=${COSMOS_IMAGE}
GITHUB_URL=${GITHUB_URL}
RUNNER_LABELS=${RUNNER_LABELS}
EOF
chmod 0644 /etc/certigo-cosmos-runner.env

cat > /usr/local/sbin/certigo-cosmos-runner-finalize <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mapfile -t containers < <(
  /usr/local/bin/docker ps --all --quiet \
    --filter label=certigo.scope=account-deletion-cosmos
)
if (( ${#containers[@]} > 0 )); then
  /usr/local/bin/docker rm --force "${containers[@]}" >/dev/null
fi
find /tmp -maxdepth 1 -type f -name 'certigo-cosmos-key.*' -delete
find /tmp -maxdepth 1 -type d -name 'certigo-cosmos-results.*' \
  -exec rm -rf -- {} +
if [[ -d /opt/actions-runner/_work ]]; then
  find /opt/actions-runner/_work -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
fi
install -d -m 0755 /var/lib/certigo-cosmos-runner
date --utc --iso-8601=seconds > /var/lib/certigo-cosmos-runner/listener-stopped-at
EOF
chmod 0755 /usr/local/sbin/certigo-cosmos-runner-finalize
}

if [[ -z "${registration_mode}" ]]; then
  command -v flock >/dev/null 2>&1 || {
    echo "flock is required to serialize the one-shot bootstrap." >&2
    exit 1
  }
  install -d -m 0755 "${STATE_DIR}"
  exec 9>"${BOOTSTRAP_LOCK}"
  if ! flock -n 9; then
    echo "Another one-shot bootstrap is already running." >&2
    exit 1
  fi
  prepare_host
  completed_tmp="${BOOTSTRAP_COMPLETE}.$$"
  date --utc --iso-8601=seconds > "${completed_tmp}"
  chmod 0444 "${completed_tmp}"
  mv -f -- "${completed_tmp}" "${BOOTSTRAP_COMPLETE}"
  echo "Base image prepared. Register once through the approved protected Run Command."
  exit 0
fi

for _ in $(seq 1 240); do
  if [[ -f "${BOOTSTRAP_COMPLETE}" ]]; then
    break
  fi
  sleep 5
done
if [[ ! -f "${BOOTSTRAP_COMPLETE}" ]]; then
  echo "Base bootstrap did not complete within 20 minutes; destroy the VM." >&2
  exit 1
fi

if [[ -f "${RUNNER_HOME}/.runner" ]]; then
  echo "This one-shot VM is already registered. Destroy it instead of reusing it." >&2
  exit 1
fi

IFS= read -r RUNNER_TOKEN || true
if [[ -z "${RUNNER_TOKEN}" ]]; then
  echo "A non-empty ephemeral GitHub runner registration token is required on stdin." >&2
  exit 2
fi
trap 'unset RUNNER_TOKEN' EXIT

runuser -u "${RUNNER_USER}" -- "${RUNNER_HOME}/config.sh" \
  --unattended \
  --ephemeral \
  --url "${GITHUB_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABELS}" \
  --work "_work" \
  --disableupdate
unset RUNNER_TOKEN
trap - EXIT

cat > /etc/systemd/system/certigo-cosmos-runner.service <<EOF
[Unit]
Description=One-shot GitHub Actions runner for the local Cosmos emulator
After=network-online.target docker.service certigo-block-imds.service
Wants=network-online.target
Requires=docker.service certigo-block-imds.service

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_USER}
SupplementaryGroups=docker
WorkingDirectory=${RUNNER_HOME}
Environment=HOME=${RUNNER_HOME}
Environment=DOTNET_CLI_HOME=${RUNNER_HOME}/.dotnet
Environment=NUGET_PACKAGES=${RUNNER_HOME}/.nuget/packages
ExecStart=${RUNNER_HOME}/run.sh
ExecStopPost=+/usr/local/sbin/certigo-cosmos-runner-finalize
ExecStopPost=+/usr/bin/systemctl poweroff --no-block
Restart=no
RuntimeMaxSec=2700
KillMode=control-group
TimeoutStopSec=120
UMask=0077
NoNewPrivileges=true
PrivateTmp=false
ProtectHome=true
ProtectSystem=full
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now certigo-cosmos-runner.service
echo "Ephemeral runner ${RUNNER_NAME} registered and started for exactly one job."
