#!/usr/bin/env bash
set -euo pipefail

: "${RELEASE_ACTION:?RELEASE_ACTION is required}"
: "${SOURCE_RUN_ID:?SOURCE_RUN_ID is required}"

if [[ "$RELEASE_ACTION" != "upload" && "$RELEASE_ACTION" != "download" ]]; then
  echo "::error::RELEASE_ACTION must be upload or download."
  exit 1
fi
if [[ ! "$SOURCE_RUN_ID" =~ ^[1-9][0-9]{0,19}$ ]]; then
  echo "::error::SOURCE_RUN_ID must be a positive GitHub Actions run id."
  exit 1
fi

RELEASE_DIRECTORY="${RELEASE_DIRECTORY:-release}"
RELEASE_CONTAINER='app-package'
RELEASE_PREFIX="releases/${SOURCE_RUN_ID}"

mapfile -t STORAGE_ACCOUNTS < <(
  az storage account list \
    --resource-group rg-certigo-dev \
    --query "[?tags.product=='Certigo' && tags.env=='dev'].name" \
    --output tsv
)
if (( ${#STORAGE_ACCOUNTS[@]} != 1 )); then
  echo "::error::Release transfer requires exactly one tagged dev storage account."
  exit 1
fi
RELEASE_STORAGE_ACCOUNT="${STORAGE_ACCOUNTS[0]}"
if [[ ! "$RELEASE_STORAGE_ACCOUNT" =~ ^[a-z0-9]{3,24}$ ]]; then
  echo "::error::Azure returned an invalid release storage account."
  exit 1
fi

release_files=(
  'publish.zip'
  'sbom/bom.json'
  'release-manifest.json'
)

remote_digest() {
  local blob_name="$1"
  az storage blob show \
    --account-name "$RELEASE_STORAGE_ACCOUNT" \
    --container-name "$RELEASE_CONTAINER" \
    --name "$blob_name" \
    --auth-mode login \
    --query metadata.sha256 \
    --output tsv \
    --only-show-errors
}

upload_release() {
  local relative_path local_file blob_name digest exists stored_digest
  local manifest_blob="${RELEASE_PREFIX}/release-manifest.json"
  local manifest_exists
  manifest_exists="$(
    az storage blob exists \
      --account-name "$RELEASE_STORAGE_ACCOUNT" \
      --container-name "$RELEASE_CONTAINER" \
      --name "$manifest_blob" \
      --auth-mode login \
      --query exists \
      --output tsv \
      --only-show-errors
  )"
  if [[ "$manifest_exists" == "true" ]]; then
    digest="$(sha256sum "${RELEASE_DIRECTORY}/publish.zip" | awk '{print $1}')"
    stored_digest="$(remote_digest "${RELEASE_PREFIX}/publish.zip")"
    if [[ "$stored_digest" != "$digest" ]]; then
      echo "::error::Canonical release ${SOURCE_RUN_ID} has a different package digest."
      exit 1
    fi
    echo "Reused canonical backend release ${SOURCE_RUN_ID} from private dev storage."
    return
  fi

  for relative_path in "${release_files[@]}"; do
    local_file="${RELEASE_DIRECTORY}/${relative_path}"
    blob_name="${RELEASE_PREFIX}/${relative_path}"
    if [[ ! -f "$local_file" ]]; then
      echo "::error::Release file ${relative_path} is missing."
      exit 1
    fi
    digest="$(sha256sum "$local_file" | awk '{print $1}')"
    exists="$(
      az storage blob exists \
        --account-name "$RELEASE_STORAGE_ACCOUNT" \
        --container-name "$RELEASE_CONTAINER" \
        --name "$blob_name" \
        --auth-mode login \
        --query exists \
        --output tsv \
        --only-show-errors
    )"
    if [[ "$exists" == "true" ]]; then
      stored_digest="$(remote_digest "$blob_name")"
      if [[ "$stored_digest" != "$digest" ]]; then
        echo "::error::Immutable release file ${relative_path} already exists with different bytes."
        exit 1
      fi
      continue
    fi
    if ! az storage blob upload \
      --account-name "$RELEASE_STORAGE_ACCOUNT" \
      --container-name "$RELEASE_CONTAINER" \
      --name "$blob_name" \
      --file "$local_file" \
      --auth-mode login \
      --overwrite false \
      --metadata "sha256=${digest}" \
      --output none \
      --only-show-errors; then
      stored_digest="$(remote_digest "$blob_name" 2>/dev/null || true)"
      if [[ "$stored_digest" != "$digest" ]]; then
        echo "::error::Could not retain immutable release file ${relative_path}."
        exit 1
      fi
    fi
  done
  echo "Retained immutable backend release ${SOURCE_RUN_ID} in private dev storage."
}

download_release() {
  local relative_path local_file blob_name
  if [[ -e "$RELEASE_DIRECTORY" ]]; then
    echo "::error::Release download directory already exists."
    exit 1
  fi
  mkdir -p "${RELEASE_DIRECTORY}/sbom"
  cleanup_partial_download() {
    rm -f -- \
      "${RELEASE_DIRECTORY}/publish.zip" \
      "${RELEASE_DIRECTORY}/release-manifest.json" \
      "${RELEASE_DIRECTORY}/sbom/bom.json"
    rmdir -- "${RELEASE_DIRECTORY}/sbom" "$RELEASE_DIRECTORY" 2>/dev/null || true
  }
  trap cleanup_partial_download ERR
  for relative_path in "${release_files[@]}"; do
    local_file="${RELEASE_DIRECTORY}/${relative_path}"
    blob_name="${RELEASE_PREFIX}/${relative_path}"
    az storage blob download \
      --account-name "$RELEASE_STORAGE_ACCOUNT" \
      --container-name "$RELEASE_CONTAINER" \
      --name "$blob_name" \
      --file "$local_file" \
      --auth-mode login \
      --overwrite true \
      --output none \
      --only-show-errors
  done
  trap - ERR
  echo "Downloaded immutable backend release ${SOURCE_RUN_ID} from private dev storage."
}

if [[ "$RELEASE_ACTION" == "upload" ]]; then
  upload_release
else
  download_release
fi
