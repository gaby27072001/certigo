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

auth_config_file=''
request_body_file=''
request_headers_file=''
response_body_file=''
operation_body_file=''
curl_error_file=''
cleanup() {
  local file
  for file in \
    "$auth_config_file" \
    "$request_body_file" \
    "$request_headers_file" \
    "$response_body_file" \
    "$operation_body_file" \
    "$curl_error_file"; do
    if [[ -n "$file" ]]; then
      rm -f -- "$file"
    fi
  done
  unset arm_access_token package_url sas_token
}
trap cleanup EXIT

required_variables=(
  SUBSCRIPTION_ID
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
if [[ ! "$SUBSCRIPTION_ID" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
  echo "::error::SUBSCRIPTION_ID must be an Azure subscription GUID."
  exit 1
fi
if [[ ! "$RESOURCE_GROUP" =~ ^[A-Za-z0-9._()-]{1,90}$ ]]; then
  echo "::error::RESOURCE_GROUP is not a valid Azure resource group name."
  exit 1
fi
if [[ ! "$FUNCTION_APP_NAME" =~ ^[A-Za-z0-9-]{2,60}$ ]]; then
  echo "::error::FUNCTION_APP_NAME is not a valid Azure Function App name."
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

arm_access_token="$(
  az account get-access-token \
    --resource 'https://management.azure.com/' \
    --query accessToken \
    --output tsv \
    --only-show-errors
)"
if [[ -z "$arm_access_token" ]]; then
  echo "::error::Azure CLI returned an empty ARM access token."
  exit 1
fi
mask_secret "$arm_access_token"

umask 077
auth_config_file="$(mktemp)"
request_body_file="$(mktemp)"
request_headers_file="$(mktemp)"
response_body_file="$(mktemp)"
operation_body_file="$(mktemp)"
curl_error_file="$(mktemp)"

printf 'header = "Authorization: Bearer %s"\n' "$arm_access_token" >"$auth_config_file"
printf \
  '{"properties":{"packageUri":"%s","type":"zip","async":true,"restart":true,"clean":true}}\n' \
  "$package_url" >"$request_body_file"

arm_endpoint="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Web/sites/${FUNCTION_APP_NAME}/extensions/onedeploy?api-version=2024-04-01"
mask_secret "$arm_endpoint"
if ! request_status="$(
  curl \
    --config "$auth_config_file" \
    --request PUT \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data-binary "@${request_body_file}" \
    --dump-header "$request_headers_file" \
    --output "$response_body_file" \
    --write-out '%{http_code}' \
    --silent \
    --show-error \
    "$arm_endpoint" 2>"$curl_error_file"
)"; then
  echo "::error::OneDeploy ARM request could not be completed."
  exit 1
fi
if [[ "$request_status" != '200' && "$request_status" != '202' ]]; then
  echo "::error::OneDeploy ARM request returned HTTP ${request_status}."
  exit 1
fi

header_values() {
  local header_name="$1"
  local headers_file="$2"
  awk -v target="${header_name,,}" '
    {
      line = $0
      sub(/\r$/, "", line)
      separator = index(line, ":")
      if (separator > 0 && tolower(substr(line, 1, separator - 1)) == target) {
        value = substr(line, separator + 1)
        sub(/^[ \t]+/, "", value)
        if (length(value) > 0) {
          print value
        }
      }
    }
  ' "$headers_file"
}

mapfile -t operation_headers < <(header_values 'Azure-AsyncOperation' "$request_headers_file")
if (( ${#operation_headers[@]} == 0 )); then
  mapfile -t operation_headers < <(header_values 'Location' "$request_headers_file")
fi
if (( ${#operation_headers[@]} != 1 )); then
  echo "::error::OneDeploy ARM response did not return exactly one asynchronous operation header."
  exit 1
fi
operation_url="${operation_headers[0]}"
if [[ ! "$operation_url" =~ ^https://management\.azure\.com/[^[:space:]]+$ ]]; then
  echo "::error::OneDeploy ARM response returned an invalid asynchronous operation URL."
  exit 1
fi
mask_secret "$operation_url"

operation_status=''
operation_started_at="$SECONDS"
while (( SECONDS - operation_started_at < DEPLOYMENT_TIMEOUT_SECONDS )); do
  if ! poll_status="$(
    curl \
      --config "$auth_config_file" \
      --request GET \
      --header 'Accept: application/json' \
      --output "$operation_body_file" \
      --write-out '%{http_code}' \
      --silent \
      --show-error \
      "$operation_url" 2>"$curl_error_file"
  )"; then
    echo "::error::OneDeploy asynchronous operation poll could not be completed."
    exit 1
  fi
  if [[ "$poll_status" != '200' && "$poll_status" != '202' ]]; then
    echo "::error::OneDeploy asynchronous operation returned HTTP ${poll_status}."
    exit 1
  fi
  if [[ "$poll_status" == '202' && ! -s "$operation_body_file" ]]; then
    sleep "$POLL_INTERVAL_SECONDS"
    continue
  fi
  if ! operation_status="$(
    "${NODE_BIN:-node}" -e '
      const fs = require("node:fs");
      const payload = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      const status = payload.status
        ?? payload.properties?.status
        ?? payload.properties?.provisioningState;
      if (typeof status !== "string" || status.length === 0) process.exit(2);
      process.stdout.write(status);
    ' "$operation_body_file" 2>/dev/null
  )"; then
    echo "::error::OneDeploy asynchronous operation returned an invalid status payload."
    exit 1
  fi

  case "${operation_status,,}" in
    succeeded)
      break
      ;;
    failed|canceled|cancelled)
      echo "::error::OneDeploy asynchronous operation failed."
      exit 1
      ;;
    accepted|inprogress|running)
      sleep "$POLL_INTERVAL_SECONDS"
      ;;
    *)
      echo "::error::OneDeploy asynchronous operation returned an unknown status."
      exit 1
      ;;
  esac
done
if [[ "${operation_status,,}" != 'succeeded' ]]; then
  echo "::error::OneDeploy asynchronous operation did not succeed before timeout."
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
