#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview"
container="certigo-cosmos-account-deletion-${GITHUB_RUN_ID:-local}-$$"
key_file="$(mktemp)"

cleanup() {
  docker rm --force "${container}" >/dev/null 2>&1 || true
  rm -f -- "${key_file}"
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || {
  echo "Docker is required for the local Cosmos emulator gate." >&2
  exit 1
}
command -v openssl >/dev/null 2>&1 || {
  echo "OpenSSL is required to generate the ephemeral emulator key." >&2
  exit 1
}

umask 077
cosmos_key="$(openssl rand -base64 64 | tr -d '\r\n')"
printf '%s' "${cosmos_key}" > "${key_file}"

docker run --detach \
  --name "${container}" \
  --publish 127.0.0.1:8080:8080 \
  --publish 127.0.0.1:8081:8081 \
  --mount "type=bind,source=${key_file},target=/run/secrets/cosmos.key,readonly" \
  --env KEY_FILE=/run/secrets/cosmos.key \
  --env PROTOCOL=https \
  "${image}" >/dev/null

ready=false
for _ in $(seq 1 120); do
  if curl --fail --silent --show-error http://127.0.0.1:8080/ready >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
if [[ "${ready}" != true ]]; then
  echo "Cosmos emulator did not become ready within 240 seconds." >&2
  exit 1
fi

export CERTIGO_COSMOS_TESTS=1
export COSMOS_EMULATOR_ENDPOINT=https://127.0.0.1:8081
export COSMOS_EMULATOR_KEY="${cosmos_key}"

dotnet test \
  "${root}/backend/tests/Certigo.Infrastructure.Tests/Certigo.Infrastructure.Tests.csproj" \
  --configuration Release \
  --filter \
  'FullyQualifiedName~CosmosRepositoriesIntegrationTests.Account_deletion_removes_user_partitions_and_keeps_only_pseudonymous_tombstone' \
  --verbosity normal
