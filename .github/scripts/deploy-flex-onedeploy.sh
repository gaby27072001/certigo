#!/usr/bin/env bash
set -euo pipefail

az() {
  command "${AZURE_CLI:-az}" "$@"
}

curl() {
  command "${CURL_BIN:-curl}" "$@"
}

getent() {
  command "${GETENT_BIN:-getent}" "$@"
}

deploy_output_file=''
deploy_error_file=''
cleanup() {
  if [[ -n "$deploy_output_file" ]]; then
    rm -f -- "$deploy_output_file"
  fi
  if [[ -n "$deploy_error_file" ]]; then
    rm -f -- "$deploy_error_file"
  fi
  unset package_url sas_token
}
trap cleanup EXIT

required_variables=(
  RESOURCE_GROUP
  FUNCTION_APP_NAME
  STORAGE_ACCOUNT
  STORAGE_BLOB_ENDPOINT
  PACKAGE_PATH
  COMMIT_SHA
)

for variable in "${required_variables[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "::error::${variable} is required."
    exit 1
  fi
done

if [[ ! "$COMMIT_SHA" =~ ^[0-9a-f]{40}$ ]]; then
  echo "::error::COMMIT_SHA must be a lowercase 40-character Git commit SHA."
  exit 1
fi
if [[ ! -f "$PACKAGE_PATH" ]]; then
  echo "::error::Deployment package does not exist."
  exit 1
fi
if [[ ! "$STORAGE_BLOB_ENDPOINT" =~ ^https://[a-z0-9]+\.blob\.core\.windows\.net/$ ]]; then
  echo "::error::Storage blob endpoint is not an expected Azure HTTPS endpoint."
  exit 1
fi

DEPLOYMENT_CONTAINER="${DEPLOYMENT_CONTAINER:-app-package}"
DEPLOYMENT_TIMEOUT_SECONDS="${DEPLOYMENT_TIMEOUT_SECONDS:-840}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-300}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-10}"
RBAC_RETRY_ATTEMPTS="${RBAC_RETRY_ATTEMPTS:-40}"
RBAC_RETRY_INTERVAL_SECONDS="${RBAC_RETRY_INTERVAL_SECONDS:-15}"
BLOB_NAME="deployments/${COMMIT_SHA}.zip"
BLOB_HOST="${STORAGE_ACCOUNT}.blob.core.windows.net"
PACKAGE_SHA256="$(sha256sum "$PACKAGE_PATH" | awk '{print $1}')"

if ((
  DEPLOYMENT_TIMEOUT_SECONDS < 1 ||
    HEALTH_TIMEOUT_SECONDS < 1 ||
    POLL_INTERVAL_SECONDS < 1 ||
    RBAC_RETRY_ATTEMPTS < 1 ||
    RBAC_RETRY_INTERVAL_SECONDS < 1
)); then
  echo "::error::Deployment and health timeouts must be positive."
  exit 1
fi

mask_secret() {
  if [[ "${GITHUB_ACTIONS:-false}" == 'true' ]]; then
    printf '::add-mask::%s\n' "$1"
  fi
}

read -r public_network_access shared_key_access < <(
  az storage account show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$STORAGE_ACCOUNT" \
    --query '[publicNetworkAccess,allowSharedKeyAccess]' \
    --output tsv \
    --only-show-errors
)
if [[ "${public_network_access,,}" != 'disabled' || "${shared_key_access,,}" != 'false' ]]; then
  echo "::error::Deployment storage must disable public network and shared-key access."
  exit 1
fi

read -r deployment_auth_type deployment_storage integration_subnet < <(
  az resource show \
    --resource-group "$RESOURCE_GROUP" \
    --resource-type Microsoft.Web/sites \
    --name "$FUNCTION_APP_NAME" \
    --api-version 2024-04-01 \
    --query '[properties.functionAppConfig.deployment.storage.authentication.type,properties.functionAppConfig.deployment.storage.value,properties.virtualNetworkSubnetId]' \
    --output tsv \
    --only-show-errors
)
if [[ "$deployment_auth_type" != 'UserAssignedIdentity' ]]; then
  echo "::error::Flex deployment storage must use the app user-assigned identity."
  exit 1
fi
if [[ "$deployment_storage" != "${STORAGE_BLOB_ENDPOINT}${DEPLOYMENT_CONTAINER}" ]]; then
  echo "::error::Flex deployment storage does not match the private package container."
  exit 1
fi
if [[ "$integration_subnet" != */subnets/snet-functions ]]; then
  echo "::error::Function App is not connected to the private integration subnet."
  exit 1
fi

private_endpoint_nic="$(
  az network private-endpoint show \
    --resource-group "$RESOURCE_GROUP" \
    --name "pep-${STORAGE_ACCOUNT}-blob" \
    --query 'networkInterfaces[0].id' \
    --output tsv \
    --only-show-errors
)"
private_endpoint_ip="$(
  az network nic show \
    --ids "$private_endpoint_nic" \
    --query 'ipConfigurations[0].privateIPAddress' \
    --output tsv \
    --only-show-errors
)"
if [[ -z "$private_endpoint_ip" ]]; then
  echo "::error::Blob private endpoint has no private IP."
  exit 1
fi
if ! getent ahostsv4 "$BLOB_HOST" | awk '{print $1}' | grep -Fxq "$private_endpoint_ip"; then
  echo "::error::Trusted runner does not resolve the storage endpoint to its private endpoint."
  exit 1
fi

uploaded=false
for attempt in $(seq 1 "$RBAC_RETRY_ATTEMPTS"); do
  if az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$DEPLOYMENT_CONTAINER" \
    --name "$BLOB_NAME" \
    --file "$PACKAGE_PATH" \
    --auth-mode login \
    --overwrite false \
    --metadata "commitSha=${COMMIT_SHA}" "packageSha256=${PACKAGE_SHA256}" \
    --output none \
    --only-show-errors; then
    uploaded=true
    break
  fi

  if remote_sha="$(
    az storage blob show \
      --account-name "$STORAGE_ACCOUNT" \
      --container-name "$DEPLOYMENT_CONTAINER" \
      --name "$BLOB_NAME" \
      --auth-mode login \
      --query 'metadata.packageSha256' \
      --output tsv \
      --only-show-errors
  )"; then
    if [[ "$remote_sha" == "$PACKAGE_SHA256" ]]; then
      uploaded=true
      break
    fi
    echo "::error::Immutable deployment blob already exists with different content."
    exit 1
  fi
  if (( attempt < RBAC_RETRY_ATTEMPTS )); then
    sleep "$RBAC_RETRY_INTERVAL_SECONDS"
  fi
done
if [[ "$uploaded" != 'true' ]]; then
  echo "::error::Unable to upload deployment package with the OIDC identity."
  exit 1
fi

sas_expiry="$(date -u -d '+14 minutes' '+%Y-%m-%dT%H:%MZ')"
sas_token="$(
  az storage blob generate-sas \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$DEPLOYMENT_CONTAINER" \
    --name "$BLOB_NAME" \
    --permissions r \
    --expiry "$sas_expiry" \
    --auth-mode login \
    --as-user \
    --https-only \
    --output tsv \
    --only-show-errors
)"
if [[ -z "$sas_token" ]]; then
  echo "::error::User-delegation SAS generation returned an empty token."
  exit 1
fi
mask_secret "$sas_token"
package_url="${STORAGE_BLOB_ENDPOINT}${DEPLOYMENT_CONTAINER}/${BLOB_NAME}?${sas_token}"
mask_secret "$package_url"

deploy_output_file="$(mktemp)"
deploy_error_file="$(mktemp)"
if ! az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$FUNCTION_APP_NAME" \
  --src-url "$package_url" \
  --type zip \
  --async true \
  --track-status false \
  --enable-kudu-warmup false \
  --query id \
  --output tsv \
  --only-show-errors >"$deploy_output_file" 2>"$deploy_error_file"; then
  deploy_error="$(<"$deploy_error_file")"
  deploy_error="${deploy_error//$package_url/<masked-package-url>}"
  deploy_error="${deploy_error//$sas_token/<masked-sas>}"
  printf '%s\n' "$deploy_error" >&2
  echo "::error::OneDeploy request failed."
  exit 1
fi
deployment_id="$(tr -d '\r\n' <"$deploy_output_file")"
if [[ ! "$deployment_id" =~ ^[A-Za-z0-9-]+$ ]]; then
  echo "::error::OneDeploy did not return a valid deployment id."
  exit 1
fi
rm -f -- "$deploy_output_file"
rm -f -- "$deploy_error_file"
deploy_output_file=''
deploy_error_file=''

deployment_started_at="$SECONDS"
while (( SECONDS - deployment_started_at < DEPLOYMENT_TIMEOUT_SECONDS )); do
  deployment_row="$(
    az webapp log deployment list \
      --resource-group "$RESOURCE_GROUP" \
      --name "$FUNCTION_APP_NAME" \
      --query "[?id=='${deployment_id}'] | [0].[id,status,complete]" \
      --output tsv \
      --only-show-errors
  )"
  IFS=$'\t' read -r current_id current_status current_complete <<< "$deployment_row"
  if [[ "$current_id" == "$deployment_id" ]]; then
    case "$current_status" in
      4)
        if [[ "${current_complete,,}" == 'true' ]]; then
          break
        fi
        ;;
      -1|3|5|6)
        echo "::error::OneDeploy failed with status ${current_status}."
        exit 1
        ;;
      ''|0|1|2) ;;
      *)
        echo "::error::OneDeploy returned unknown status ${current_status}."
        exit 1
        ;;
    esac
  fi
  sleep "$POLL_INTERVAL_SECONDS"
done
if [[ -z "$deployment_id" || "${current_status:-}" != '4' || "${current_complete,,}" != 'true' ]]; then
  echo "::error::OneDeploy did not complete successfully before timeout."
  exit 1
fi

health_check() {
  local path="$1"
  local started_at="$SECONDS"
  while (( SECONDS - started_at < HEALTH_TIMEOUT_SECONDS )); do
    if curl \
      --fail \
      --silent \
      --show-error \
      --max-time 15 \
      --output /dev/null \
      "https://${FUNCTION_APP_NAME}.azurewebsites.net/api/${path}"; then
      return 0
    fi
    sleep "$POLL_INTERVAL_SECONDS"
  done
  echo "::error::Function App ${path} probe did not become healthy."
  return 1
}

health_check 'health/live'
health_check 'health/ready'

echo "OneDeploy completed and the Function App passed liveness and readiness checks; the immutable source package is retained for lifecycle cleanup."
