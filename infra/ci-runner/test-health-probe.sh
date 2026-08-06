#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work_dir="${repo_root}/infra/ci-runner/.test-work"
bin_dir="${work_dir}/bin"
summary="${work_dir}/summary.md"
trap 'rm -rf "${work_dir}"' EXIT
rm -rf "${work_dir}"
mkdir -p "${bin_dir}"

cat > "${bin_dir}/curl" <<'EOF'
#!/usr/bin/env bash
if [[ "${FAKE_CURL_FAIL:-0}" == "1" ]]; then
  exit 22
fi
exit 0
EOF
cat > "${bin_dir}/git" <<'EOF'
#!/usr/bin/env bash
echo "git test"
EOF
cat > "${bin_dir}/df" <<'EOF'
#!/usr/bin/env bash
echo "Filesystem 1024-blocks Used Available Capacity Mounted on"
echo "fake 41943040 0 ${FAKE_DF_KB:-20971520} 0% /"
EOF
chmod +x "${bin_dir}/curl" "${bin_dir}/git" "${bin_dir}/df"

PATH="${bin_dir}:${PATH}" \
  REQUIRED_TOOLS="git curl" \
  PROBE_ENDPOINTS="GitHub|https://example.invalid/github
NuGet|https://example.invalid/nuget
pub.dev|https://example.invalid/pub
npm|https://example.invalid/npm
Azure|https://example.invalid/azure" \
  GITHUB_STEP_SUMMARY="${summary}" \
  bash "${repo_root}/infra/ci-runner/health-probe.sh"

grep -F "| GitHub | PASS |" "${summary}" >/dev/null
grep -F "| NuGet | PASS |" "${summary}" >/dev/null
grep -F "| pub.dev | PASS |" "${summary}" >/dev/null
grep -F "| npm | PASS |" "${summary}" >/dev/null
grep -F "| Azure | PASS |" "${summary}" >/dev/null
grep -F "| free disk | PASS |" "${summary}" >/dev/null

if PATH="${bin_dir}:${PATH}" \
  FAKE_DF_KB=1024 \
  REQUIRED_TOOLS="git curl" \
  PROBE_ENDPOINTS="GitHub|https://example.invalid/github" \
  bash "${repo_root}/infra/ci-runner/health-probe.sh" >/dev/null 2>&1; then
  echo "Expected the low-disk probe to fail." >&2
  exit 1
fi

if PATH="${bin_dir}:${PATH}" \
  FAKE_CURL_FAIL=1 \
  REQUIRED_TOOLS="git curl" \
  PROBE_ENDPOINTS="npm|https://example.invalid/npm" \
  bash "${repo_root}/infra/ci-runner/health-probe.sh" >/dev/null 2>&1; then
  echo "Expected the failed endpoint probe to fail." >&2
  exit 1
fi

if PATH="${bin_dir}:${PATH}" \
  MIN_FREE_GB=invalid \
  REQUIRED_TOOLS="git curl" \
  PROBE_ENDPOINTS="" \
  bash "${repo_root}/infra/ci-runner/health-probe.sh" >/dev/null 2>&1; then
  echo "Expected an invalid disk threshold to fail." >&2
  exit 1
fi

if PATH="${bin_dir}:${PATH}" \
  REQUIRED_TOOLS="certigo-tool-that-does-not-exist" \
  PROBE_ENDPOINTS="GitHub|https://example.invalid/github" \
  bash "${repo_root}/infra/ci-runner/health-probe.sh" >/dev/null 2>&1; then
  echo "Expected a missing required tool to fail." >&2
  exit 1
fi

echo "health-probe tests passed"
