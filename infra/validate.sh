#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bicep_bin="${BICEP_BIN:-bicep}"
output_dir="$(mktemp -d)"
trap 'rm -rf "${output_dir}"' EXIT

ensure_node() {
  if command -v node >/dev/null 2>&1; then
    return
  fi
  if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
    echo "Node.js is required; automatic bootstrap supports Linux x64 only." >&2
    exit 1
  fi

  local version="20.20.2"
  local archive_name="node-v${version}-linux-x64.tar.xz"
  local expected_sha="df770b2a6f130ed8627c9782c988fda9669fa23898329a61a871e32f965e007d"
  local install_root="${RUNNER_TEMP:?RUNNER_TEMP is required to bootstrap Node.js.}"
  local archive="${install_root}/${archive_name}"
  local node_home="${install_root}/node-v${version}-linux-x64"

  if [[ ! -x "${node_home}/bin/node" ]]; then
    curl --fail --silent --show-error --location --retry 3 \
      --output "${archive}" \
      "https://nodejs.org/dist/v${version}/${archive_name}"
    echo "${expected_sha}  ${archive}" | sha256sum --check --strict
    tar -xJf "${archive}" -C "${install_root}"
    rm -f -- "${archive}"
  fi

  export PATH="${node_home}/bin:${PATH}"
  if [[ -n "${GITHUB_PATH:-}" ]]; then
    printf '%s\n' "${node_home}/bin" >> "${GITHUB_PATH}"
  fi
  [[ "$(node --version)" == "v${version}" ]]
}

command -v "${bicep_bin}" >/dev/null 2>&1 || {
  echo "Bicep CLI is required. Set BICEP_BIN to a pinned executable." >&2
  exit 1
}
ensure_node

for script in \
  "${root}/infra/governance/deploy-phase-a.sh" \
  "${root}/infra/governance/deploy-phase-b1.sh" \
  "${root}/infra/governance/deploy-phase-b2.sh" \
  "${root}/infra/governance/deploy-phase-b1b.sh" \
  "${root}/infra/governance/inventory.sh" \
  "${root}/infra/governance/prepare-phase-b.sh" \
  "${root}/infra/governance/what-if-governance-planner.sh" \
  "${root}/infra/governance/what-if-phase-a.sh" \
  "${root}/infra/governance/what-if-phase-b.sh" \
  "${root}/infra/governance/what-if-phase-b1.sh" \
  "${root}/infra/governance/what-if-phase-b1b.sh" \
  "${root}/infra/governance/what-if-phase-b2.sh"; do
  bash -n "${script}"
done
node --check "${root}/infra/governance/render-inventory.mjs"
node --check "${root}/infra/governance/bicep-parameters.mjs"
node --check "${root}/infra/governance/collect-role-assignment-schedules.mjs"
node --check "${root}/infra/governance/collect-transitive-groups.mjs"
node --check "${root}/infra/governance/evidence-files.mjs"
node --check "${root}/infra/governance/legacy-transition-contract.mjs"
node --check "${root}/infra/governance/phase-b-target.mjs"
node --check "${root}/infra/governance/planner-pim-contract.mjs"
node --check "${root}/infra/governance/validate-planner-what-if.mjs"
node --check "${root}/infra/governance/normalize-principal-types.mjs"
node --check "${root}/infra/governance/validate-what-if.mjs"
node --check "${root}/infra/governance/validate-evidence.mjs"
node --check "${root}/infra/governance/write-what-if-manifest.mjs"

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

BICEP_CLI="${bicep_bin}" node --test "${root}/infra/tests/azure-tag-contract.test.mjs"
BICEP_CLI="${bicep_bin}" node --test "${root}/infra/tests/critical-failures.test.mjs"
node --test "${root}/infra/tests/alert-receivers.test.mjs"
BICEP_CLI="${bicep_bin}" node --test \
  "${root}/infra/tests/governance-evidence.test.mjs"
BICEP_CLI="${bicep_bin}" node --test \
  "${root}/infra/tests/governance-planner.test.mjs"
BICEP_CLI="${bicep_bin}" node --test \
  "${root}/infra/tests/ci-runner-auto-recovery.test.mjs" \
  "${root}/infra/tests/ci-runner-auto-recovery-simulation.test.mjs"
node --test "${root}/infra/tests/governance-tooling.test.mjs"

for environment in dev staging prod; do
  params="${root}/infra/params/${environment}.bicepparam"
  grep -F 'param vnetAddressPrefix =' "${params}" >/dev/null
  grep -F 'param functionIntegrationSubnetPrefix =' "${params}" >/dev/null
  grep -F 'param privateEndpointSubnetPrefix =' "${params}" >/dev/null
  grep -Eq "^param ciDeploymentPrincipalId = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'$" \
    "${params}"
  grep -F 'param cosmosBackupMode =' "${params}" >/dev/null
  grep -F 'param deployMcsbPolicyAssignment =' "${params}" >/dev/null
  grep -F 'param manageDefenderPlans =' "${params}" >/dev/null
done

if grep -R --include='bootstrap-identities.bicep' -n \
  -E "^resource .*'Microsoft\.Authorization/(roleAssignments|policyAssignments)@" \
  "${root}/infra/governance" >/dev/null; then
  echo "Phase A must not declare role or policy assignments." >&2
  exit 1
fi

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
  if grep -Eq \
    '^[[:space:]]*param[[:space:]]+(publicWebOrigin|publicDomainVerified|appleCiamDomainReconfigured)[[:space:]]*=' \
    "${params}"; then
    echo "${environment} public-domain parameters must come from its GitHub Environment." >&2
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
grep -F 'param publicWebOrigin string = '\'''\''' \
  "${root}/infra/main.bicep" >/dev/null
grep -F 'param publicDomainVerified bool = false' \
  "${root}/infra/main.bicep" >/dev/null
grep -F 'param appleCiamDomainReconfigured bool = false' \
  "${root}/infra/main.bicep" >/dev/null
if grep -F 'ENTRA_GRAPH_CLIENT_SECRET:' \
  "${root}/infra/modules/functionApp.bicep" >/dev/null; then
  echo "The raw Graph client secret must never be emitted as a Function App setting." >&2
  exit 1
fi
grep -F "name: 'ENTRA-GRAPH-CLIENT-SECRET'" \
  "${root}/infra/modules/keyvaultGraphClientSecret.bicep" >/dev/null
grep -F 'exp: dateTimeToEpoch(graphClientSecretExpiresOn)' \
  "${root}/infra/modules/keyvaultGraphClientSecret.bicep" >/dev/null
grep -F 'secretUriWithVersion' \
  "${root}/infra/modules/keyvaultGraphClientSecret.bicep" >/dev/null
grep -F "type: 'UserAssignedIdentity'" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F 'userAssignedIdentityResourceId:' "${root}/infra/modules/functionApp.bicep" >/dev/null
if grep -F "b7e6dc6d-f1e8-4753-8033-0f276bb0955b" \
  "${root}/infra/modules/functionApp.bicep" >/dev/null; then
  echo "Storage Blob Data Owner must not be assigned to the Function App host identity (least privilege — see AUDIT_Certigo.md R-03)." >&2
  exit 1
fi
grep -F "ba92f5b4-2d11-453d-a403-e96b0029c9fe" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F "0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3" "${root}/infra/modules/functionApp.bicep" >/dev/null
grep -F "ba92f5b4-2d11-453d-a403-e96b0029c9fe" "${root}/infra/modules/storage.bicep" >/dev/null
grep -F "db58b8e5-c6ad-4a2a-8342-4190687cbf4a" "${root}/infra/modules/storage.bicep" >/dev/null
grep -F "'app-package/deployments/'" "${root}/infra/modules/storage.bicep" >/dev/null

echo "Azure IaC validation passed (${index} parameter files)."
