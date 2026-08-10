#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bicep_bin="${BICEP_BIN:-bicep}"
output_dir="$(mktemp -d)"
trap 'rm -rf "${output_dir}"' EXIT

command -v "${bicep_bin}" >/dev/null 2>&1 || {
  echo "Bicep CLI is required. Set BICEP_BIN to a pinned executable." >&2
  exit 1
}

index=0
while IFS= read -r -d '' template; do
  index=$((index + 1))
  "${bicep_bin}" build "${template}" --outfile "${output_dir}/template-${index}.json"
done < <(find "${root}/infra" -type f -name '*.bicep' -print0 | sort -z)

index=0
while IFS= read -r -d '' parameters; do
  index=$((index + 1))
  "${bicep_bin}" build-params "${parameters}" --outfile "${output_dir}/params-${index}.json"
done < <(find "${root}/infra/params" -type f -name '*.bicepparam' -print0 | sort -z)

for environment in dev staging prod; do
  params="${root}/infra/params/${environment}.bicepparam"
  grep -F "param networkAccessMode = 'public-rbac'" "${params}" >/dev/null
  grep -F 'param cosmosBackupMode =' "${params}" >/dev/null
  grep -F 'param deployMcsbPolicyAssignment =' "${params}" >/dev/null
  grep -F 'param manageDefenderPlans =' "${params}" >/dev/null
done

for environment in staging prod; do
  params="${root}/infra/params/${environment}.bicepparam"
  if grep -Eq "^param alertEmail = ''$" "${params}"; then
    echo "${environment} must define a non-empty alertEmail." >&2
    exit 1
  fi
  grep -F "param cosmosBackupMode = 'Continuous'" "${params}" >/dev/null
  grep -F 'param grantAlertReaderRole = true' "${params}" >/dev/null
done

if grep -R --include='*.bicep' --include='*.bicepparam' -n 'enablePrivateNetworking' \
  "${root}/infra" >/dev/null; then
  echo "Unsafe enablePrivateNetworking switch remains in IaC." >&2
  exit 1
fi

grep -F "type: 'UserAssignedIdentity'" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'userAssignedIdentityResourceId:' "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F "b7e6dc6d-f1e8-4753-8033-0f276bb0955b" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F "0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3" "${root}/infra/modules/functionApp.bicep" >/dev/null

echo "Azure IaC validation passed (${index} parameter files)."
