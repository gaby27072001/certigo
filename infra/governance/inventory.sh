#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
subscription_id="${AZURE_SUBSCRIPTION_ID:?Set AZURE_SUBSCRIPTION_ID explicitly.}"
legacy_principal_id="${CERTIGO_LEGACY_PRINCIPAL_ID:-15d2b34a-c0a0-4b5d-8360-b895a8164706}"
legacy_application_id="${CERTIGO_LEGACY_APPLICATION_ID:-4bfc43dc-6a25-404e-a6ab-d19784ab0673}"
repository="${GITHUB_REPOSITORY:-gchambaud_microsoft/Certigo}"
ci_resource_group="${CERTIGO_CI_RESOURCE_GROUP:-rg-certigo-ci}"

work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
chmod 700 "${work_dir}"

az group list \
  --subscription "${subscription_id}" \
  --query "[?starts_with(name, 'rg-certigo')]" \
  --output json > "${work_dir}/groups.json"

az resource list \
  --subscription "${subscription_id}" \
  --query "[?starts_with(resourceGroup, 'rg-certigo')]" \
  --output json > "${work_dir}/resources.json"

az role assignment list \
  --subscription "${subscription_id}" \
  --assignee-object-id "${legacy_principal_id}" \
  --include-inherited \
  --all \
  --output json > "${work_dir}/legacy-rbac.json"

az ad app federated-credential list \
  --id "${legacy_application_id}" \
  --output json > "${work_dir}/legacy-federation.json"

MSYS_NO_PATHCONV=1 az policy assignment list \
  --subscription "${subscription_id}" \
  --scope "/subscriptions/${subscription_id}" \
  --disable-scope-strict-match \
  --output json > "${work_dir}/policies.json"

az vmss list \
  --subscription "${subscription_id}" \
  --resource-group "${ci_resource_group}" \
  --output json > "${work_dir}/vm-scale-sets.json"

az monitor autoscale list \
  --subscription "${subscription_id}" \
  --resource-group "${ci_resource_group}" \
  --output json > "${work_dir}/autoscale-settings.json"

az vm list \
  --subscription "${subscription_id}" \
  --resource-group "${ci_resource_group}" \
  --show-details \
  --output json > "${work_dir}/vms.json"

az network public-ip list \
  --subscription "${subscription_id}" \
  --resource-group "${ci_resource_group}" \
  --output json > "${work_dir}/public-ips.json"

az network nsg list \
  --subscription "${subscription_id}" \
  --resource-group "${ci_resource_group}" \
  --output json > "${work_dir}/nsgs.json"

az disk list \
  --subscription "${subscription_id}" \
  --resource-group "${ci_resource_group}" \
  --output json > "${work_dir}/disks.json"

gh api "repos/${repository}/actions/runners" > "${work_dir}/runners.json"
gh api "repos/${repository}/actions/runs?status=queued&per_page=100" \
  > "${work_dir}/queued-runs.json"
gh api "repos/${repository}/actions/runs?status=in_progress&per_page=100" \
  > "${work_dir}/active-runs.json"

node "${root}/infra/governance/render-inventory.mjs" \
  --directory "${work_dir}" \
  --generated-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --subscription "${subscription_id}"
