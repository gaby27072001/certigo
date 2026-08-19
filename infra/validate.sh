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
  grep -F 'param vnetAddressPrefix =' "${params}" >/dev/null
  grep -F 'param functionIntegrationSubnetPrefix =' "${params}" >/dev/null
  grep -F 'param privateEndpointSubnetPrefix =' "${params}" >/dev/null
  grep -F "param ciDeploymentPrincipalId = '15d2b34a-c0a0-4b5d-8360-b895a8164706'" \
    "${params}" >/dev/null
  grep -F 'param cosmosBackupMode =' "${params}" >/dev/null
  grep -F 'param deployMcsbPolicyAssignment =' "${params}" >/dev/null
  grep -F 'param manageDefenderPlans =' "${params}" >/dev/null
done

grep -F "param authJwtSigningKeyExpiresOn = '2027-08-31T00:00:00Z'" \
  "${root}/infra/params/dev.bicepparam" >/dev/null
grep -F 'contentType:' "${root}/infra/modules/keyvault.bicep" >/dev/null
grep -F 'exp: dateTimeToEpoch(jwtSigningKeyExpiresOn)' \
  "${root}/infra/modules/keyvault.bicep" >/dev/null
grep -F 'exp: dateTimeToEpoch(jwtPreviousSigningKeyExpiresOn)' \
  "${root}/infra/modules/keyvaultPreviousJwtSecret.bicep" >/dev/null

for environment in staging prod; do
  params="${root}/infra/params/${environment}.bicepparam"
  if grep -Eq "^param alertEmail = ''$" "${params}"; then
    echo "${environment} must define a non-empty alertEmail." >&2
    exit 1
  fi
  grep -F "param cosmosBackupMode = 'Continuous'" "${params}" >/dev/null
  grep -F 'param grantAlertReaderRole = true' "${params}" >/dev/null
  if grep -Eq \
    '^[[:space:]]*param[[:space:]]+entra(GraphTenantId|GraphClientId|GraphClientSecret|ReauthAudience)[[:space:]]*=' \
    "${params}"; then
    echo "${environment} Graph identity parameters must come from its GitHub Environment." >&2
    exit 1
  fi
done

if grep -R --include='*.bicep' --include='*.bicepparam' -n \
  -E 'enablePrivateNetworking|networkAccessMode|public-rbac' \
  "${root}/infra" >/dev/null; then
  echo "A partial or public networking switch remains in IaC." >&2
  exit 1
fi

for module in storage keyvault cosmos; do
  grep -F "publicNetworkAccess: 'Disabled'" \
    "${root}/infra/modules/${module}.bicep" >/dev/null
done
  grep -F 'enablePurgeProtection: true' "${root}/infra/modules/keyvault.bicep" >/dev/null
grep -F "serviceName: 'Microsoft.App/environments'" \
  "${root}/infra/modules/privateNetwork.bicep" >/dev/null
grep -F "privateEndpointNetworkPolicies: 'Disabled'" \
  "${root}/infra/modules/privateNetwork.bicep" >/dev/null
grep -F "name: 'peer-to-\${ciVnetName}'" \
  "${root}/infra/modules/privateNetwork.bicep" >/dev/null
grep -F "name: 'peer-to-\${appVnetName}'" \
  "${root}/infra/modules/ciVnetPeering.bicep" >/dev/null
grep -F "name: '\${ciVnetName}-link'" \
  "${root}/infra/modules/sharedPrivateDns.bicep" >/dev/null
grep -F "name: '\${appVnetName}-link'" \
  "${root}/infra/modules/privateDnsAppLinks.bicep" >/dev/null
grep -F 'privateDnsZoneId: blobZoneId' \
  "${root}/infra/modules/privateNetwork.bicep" >/dev/null
grep -F 'virtualNetworkSubnetId: functionIntegrationSubnetId' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'vnetRouteAllEnabled: false' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'ENTRA_REAUTH_AUDIENCE: entraReauthAudience' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'ENTRA_GRAPH_TENANT_ID: entraGraphTenantId' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'ENTRA_GRAPH_CLIENT_ID: entraGraphClientId' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'ENTRA_GRAPH_CLIENT_SECRET_SECRET_URI: entraGraphClientSecretSecretUri' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'ACCOUNT_DELETION_ENABLED: string(accountDeletionEnabled)' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'param accountDeletionEnabled bool = false' \
  "${root}/infra/main.bicep" >/dev/null
if grep -F 'ENTRA_GRAPH_CLIENT_SECRET:' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null; then
  echo "The raw Graph client secret must never be emitted as a Function App setting." >&2
  exit 1
fi
grep -F "type: 'UserAssignedIdentity'" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'userAssignedIdentityResourceId:' "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F "b7e6dc6d-f1e8-4753-8033-0f276bb0955b" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F "0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F "ba92f5b4-2d11-453d-a403-e96b0029c9fe" "${root}/infra/modules/storage.bicep" >/dev/null
grep -F "db58b8e5-c6ad-4a2a-8342-4190687cbf4a" "${root}/infra/modules/storage.bicep" >/dev/null
grep -F "'app-package/deployments/'" "${root}/infra/modules/storage.bicep" >/dev/null

echo "Azure IaC validation passed (${index} parameter files)."
