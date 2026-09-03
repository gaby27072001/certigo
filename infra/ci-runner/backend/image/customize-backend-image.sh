#!/usr/bin/env bash
set -euo pipefail

role="${1:-}"
image_definition_name="${2:-}"
image_version="${3:-}"
input_root="${CERTIGO_IMAGE_INPUT_ROOT:-/var/tmp/certigo-backend-image-input}"
runner_home="/opt/actions-runner"
toolchain_root="/opt/certigo/backend-toolchains"
runner_version="2.336.0"
node_version="20.20.2"
dotnet_version="8.0.424"
github_cli_version="2.96.0"

case "${role}" in
  builder)
    service_user="certigo-builder"
    runner_label="certigo-backend-builder"
    ;;
  deployer)
    service_user="certigo-deployer"
    runner_label="certigo-backend-deployer"
    ;;
  *)
    echo "Role must be builder or deployer." >&2
    exit 64
    ;;
esac
if [[
  ! "${image_definition_name}" =~ ^[a-z0-9][a-z0-9.-]{0,79}$ ||
  ! "${image_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$
]]; then
  echo "Exact image definition and semantic image version are required." >&2
  exit 64
fi

if ((EUID != 0)); then
  echo "Backend image customization must run as root." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "The backend images require the pinned Ubuntu 24.04 base." >&2
  exit 1
fi

for command in curl iptables sha256sum sha512sum systemctl tar useradd; do
  command -v "${command}" >/dev/null 2>&1 || {
    echo "Pinned base image is missing ${command}; package-manager repair is forbidden." >&2
    exit 1
  }
done

for input in \
  actions-runner-linux-x64-${runner_version}.tar.gz \
  register-ephemeral-runner.sh \
  cleanup-backend-runner.sh \
  backend-job-hook.sh \
  validate-backend-image.sh; do
  [[ -f "${input_root}/${input}" ]] || {
    echo "Missing verified image input: ${input}" >&2
    exit 1
  }
done

if [[ "${role}" == "builder" ]]; then
  for input in \
    node-v${node_version}-linux-x64.tar.xz \
    dotnet-sdk-${dotnet_version}-linux-x64.tar.gz; do
    [[ -f "${input_root}/${input}" ]] || {
      echo "Missing verified builder input: ${input}" >&2
      exit 1
    }
  done
else
  for input in \
    gh_${github_cli_version}_linux_amd64.tar.gz \
    verify-deployment-bundle.mjs; do
    [[ -f "${input_root}/${input}" ]] || {
      echo "Missing verified deployer input: ${input}" >&2
      exit 1
    }
  done
fi

if ! id "${service_user}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${service_user}"
fi
if id -nG "${service_user}" | tr ' ' '\n' | grep -Eq '^(sudo|docker)$'; then
  echo "${service_user} must not belong to sudo or docker groups." >&2
  exit 1
fi

install -d -m 0755 \
  "${runner_home}" \
  /opt/certigo \
  /etc/certigo \
  /usr/local/sbin \
  /var/lib/certigo
tar -xzf "${input_root}/actions-runner-linux-x64-${runner_version}.tar.gz" \
  -C "${runner_home}"
chown -R root:root "${runner_home}"
chmod -R go-w "${runner_home}"
install -d -m 0700 -o "${service_user}" -g "${service_user}" \
  "${runner_home}/_diag" \
  "${runner_home}/_work"

actual_runner_version="$(
  runuser -u "${service_user}" -- "${runner_home}/bin/Runner.Listener" --version
)"
if [[ "${actual_runner_version}" != "${runner_version}" ]]; then
  echo "GitHub Actions runner version mismatch." >&2
  exit 1
fi

if [[ "${role}" == "builder" ]]; then
  install -d -m 0755 "${toolchain_root}"
  install -d -m 0755 "${toolchain_root}/node-${node_version}"
  tar -xJf "${input_root}/node-v${node_version}-linux-x64.tar.xz" \
    --strip-components=1 \
    -C "${toolchain_root}/node-${node_version}"
  install -d -m 0755 "${toolchain_root}/dotnet-${dotnet_version}"
  tar -xzf "${input_root}/dotnet-sdk-${dotnet_version}-linux-x64.tar.gz" \
    -C "${toolchain_root}/dotnet-${dotnet_version}"
  chown -R root:root "${toolchain_root}"
  chmod -R a-w "${toolchain_root}"
  ln -sfn "${toolchain_root}/node-${node_version}/bin/node" /usr/local/bin/node
  ln -sfn "${toolchain_root}/node-${node_version}/bin/npm" /usr/local/bin/npm
  ln -sfn "${toolchain_root}/node-${node_version}/bin/npx" /usr/local/bin/npx
  ln -sfn "${toolchain_root}/dotnet-${dotnet_version}/dotnet" /usr/local/bin/dotnet
else
  rm -rf -- "${toolchain_root}"
  install -d -m 0755 /opt/certigo/github-cli /usr/local/libexec/certigo
  tar -xzf "${input_root}/gh_${github_cli_version}_linux_amd64.tar.gz" \
    --strip-components=1 \
    -C /opt/certigo/github-cli
  chown -R root:root /opt/certigo/github-cli
  chmod -R a-w /opt/certigo/github-cli
  ln -sfn /opt/certigo/github-cli/bin/gh /usr/local/bin/gh
  install -o root -g root -m 0555 \
    "${input_root}/verify-deployment-bundle.mjs" \
    /usr/local/libexec/certigo/verify-deployment-bundle.mjs
fi

install -m 0755 "${input_root}/register-ephemeral-runner.sh" \
  /usr/local/sbin/certigo-register-ephemeral-runner
install -m 0755 "${input_root}/cleanup-backend-runner.sh" \
  /usr/local/sbin/certigo-cleanup-backend-runner
install -m 0755 "${input_root}/backend-job-hook.sh" \
  /usr/local/sbin/certigo-backend-job-hook
install -m 0755 "${input_root}/validate-backend-image.sh" \
  /usr/local/sbin/certigo-validate-backend-image
ln -sfn /usr/local/sbin/certigo-backend-job-hook \
  /usr/local/sbin/certigo-backend-job-started
ln -sfn /usr/local/sbin/certigo-backend-job-hook \
  /usr/local/sbin/certigo-backend-job-completed
chown root:root /usr/local/sbin/certigo-*
chmod go-w /usr/local/sbin/certigo-*

cat > /usr/local/sbin/certigo-block-imds <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! /usr/sbin/iptables -C OUTPUT -d 169.254.169.254/32 -j REJECT 2>/dev/null; then
  /usr/sbin/iptables -I OUTPUT 1 -d 169.254.169.254/32 -j REJECT
fi
EOF
chown root:root /usr/local/sbin/certigo-block-imds
chmod 0755 /usr/local/sbin/certigo-block-imds

cat > /etc/systemd/system/certigo-block-imds.service <<'EOF'
[Unit]
Description=Block Azure IMDS for isolated backend runners
DefaultDependencies=no
After=local-fs.target
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/certigo-block-imds
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/certigo/backend-runner.env <<EOF
CERTIGO_RUNNER_CONFIG_SCHEMA=certigo.ephemeral-runner/v1
CERTIGO_RUNNER_CLASS=${role}
CERTIGO_RUNNER_LABEL=${runner_label}
CERTIGO_SERVICE_USER=${service_user}
CERTIGO_RUNNER_HOME=${runner_home}
CERTIGO_SERVICE_HOME=/home/${service_user}
CERTIGO_JOB_ROOT=/mnt/certigo-job/${role}
CERTIGO_IMAGE_DEFINITION_NAME=${image_definition_name}
CERTIGO_IMAGE_VERSION=${image_version}
CERTIGO_IMAGE_VALIDATION_STAMP=/var/lib/certigo/backend-image-validated
CERTIGO_REGISTRATION_STAMP=/var/lib/certigo/backend-runner-registration-consumed
CERTIGO_RETIRE_STAMP=/var/lib/certigo/backend-runner-retired
EOF
chown root:root /etc/certigo/backend-runner.env
chmod 0444 /etc/certigo/backend-runner.env

install -d -m 0700 -o "${service_user}" -g "${service_user}" \
  "/mnt/certigo-job/${role}"
rm -f -- \
  /root/.bash_history \
  "/home/${service_user}/.bash_history"
find "/home/${service_user}" -mindepth 1 -maxdepth 1 \
  \( -name '.cache' -o -name '.npm' -o -name '.nuget' -o -name '.azure' \
     -o -name '.docker' \) \
  -exec rm -rf -- {} +

systemctl daemon-reload
systemctl enable --now certigo-block-imds.service

/usr/local/sbin/certigo-validate-backend-image --image-build
rm -rf -- "${input_root}"
echo "Locked ${role} backend runner image prepared."
