#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '::error::%s\n' "$1" >&2
  exit 1
}

require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || fail "${name} is required."
}

for name in \
  TRANSPORT_DIRECTORY \
  RELEASE_DIRECTORY \
  MANIFEST_SCRIPT \
  EXPECTED_ARTIFACT_ID \
  EXPECTED_ARTIFACT_DIGEST \
  EXPECTED_BUNDLE_SHA256 \
  EXPECTED_SOURCE_COMMIT \
  EXPECTED_WORKFLOW_SHA \
  EXPECTED_WORKFLOW_RUN_ID \
  EXPECTED_WORKFLOW_RUN_ATTEMPT \
  EXPECTED_BUILD_SOURCE_RUN_ID; do
  require_env "${name}"
done

[[ "${EXPECTED_ARTIFACT_ID}" =~ ^[1-9][0-9]{0,19}$ ]] \
  || fail 'Artifact id must be a positive integer.'
[[ "${EXPECTED_ARTIFACT_DIGEST}" =~ ^[0-9a-f]{64}$ ]] \
  || fail 'Artifact digest must be a lowercase SHA-256 digest.'
[[ "${EXPECTED_BUNDLE_SHA256}" =~ ^[0-9a-f]{64}$ ]] \
  || fail 'Bundle digest must be a lowercase SHA-256 digest.'
[[ "${EXPECTED_ARTIFACT_DIGEST}" == "${EXPECTED_BUNDLE_SHA256}" ]] \
  || fail 'Artifact service digest does not match the sealed bundle digest.'
[[ "${EXPECTED_SOURCE_COMMIT}" =~ ^[0-9a-f]{40}$ ]] \
  || fail 'Source commit must be a lowercase 40-character Git SHA.'
[[ "${EXPECTED_WORKFLOW_SHA}" =~ ^[0-9a-f]{40}$ ]] \
  || fail 'Workflow SHA must be a lowercase 40-character Git SHA.'
for value in \
  "${EXPECTED_WORKFLOW_RUN_ID}" \
  "${EXPECTED_WORKFLOW_RUN_ATTEMPT}" \
  "${EXPECTED_BUILD_SOURCE_RUN_ID}"; do
  [[ "${value}" =~ ^[1-9][0-9]{0,19}$ ]] \
    || fail 'Run ids and attempts must be positive integers.'
done
[[ -d "${TRANSPORT_DIRECTORY}" ]] || fail 'Transport directory is missing.'
[[ ! -e "${RELEASE_DIRECTORY}" ]] || fail 'Release directory must start absent.'
[[ -f "${MANIFEST_SCRIPT}" && ! -L "${MANIFEST_SCRIPT}" ]] \
  || fail 'Trusted manifest verifier must be a regular file.'

mapfile -d '' transport_entries < <(
  find -P "${TRANSPORT_DIRECTORY}" -mindepth 1 -maxdepth 1 -print0
)
[[ "${#transport_entries[@]}" -eq 1 ]] \
  || fail 'Transport must contain exactly one artifact file.'

bundle="${transport_entries[0]}"
[[ "$(basename "${bundle}")" == 'backend-release-bundle.tar' ]] \
  || fail 'Transport artifact name is not canonical.'
[[ -f "${bundle}" && ! -L "${bundle}" ]] \
  || fail 'Transport artifact must be a regular file.'

actual_bundle_sha256="$(sha256sum "${bundle}" | cut -d ' ' -f 1)"
[[ "${actual_bundle_sha256}" == "${EXPECTED_BUNDLE_SHA256}" ]] \
  || fail 'Downloaded bundle digest does not match the builder handoff.'

mapfile -t bundle_entries < <(LC_ALL=C tar --list --file "${bundle}")
expected_entries=(
  'publish.zip'
  'release-manifest.json'
  'sbom/bom.json'
)
[[ "${#bundle_entries[@]}" -eq "${#expected_entries[@]}" ]] \
  || fail 'Release bundle contains an unexpected number of entries.'
for index in "${!expected_entries[@]}"; do
  [[ "${bundle_entries[index]}" == "${expected_entries[index]}" ]] \
    || fail 'Release bundle layout is not canonical.'
done

while IFS= read -r entry; do
  [[ "${entry:0:1}" == '-' ]] \
    || fail 'Release bundle may contain regular files only.'
done < <(LC_ALL=C tar --list --verbose --file "${bundle}")

mkdir --mode=0700 "${RELEASE_DIRECTORY}"
tar \
  --extract \
  --file "${bundle}" \
  --directory "${RELEASE_DIRECTORY}" \
  --no-same-owner \
  --no-same-permissions

mapfile -d '' release_files < <(
  find -P "${RELEASE_DIRECTORY}" -type f -print0 | LC_ALL=C sort -z
)
[[ "${#release_files[@]}" -eq 3 ]] \
  || fail 'Extracted release must contain exactly three regular files.'
if find -P "${RELEASE_DIRECTORY}" -type l -print -quit | grep -q .; then
  fail 'Extracted release must not contain symbolic links.'
fi

node "${MANIFEST_SCRIPT}" verify \
  --manifest "${RELEASE_DIRECTORY}/release-manifest.json" \
  --expected-commit "${EXPECTED_SOURCE_COMMIT}" \
  --expected-workflow-sha "${EXPECTED_WORKFLOW_SHA}" \
  --expected-run-id "${EXPECTED_WORKFLOW_RUN_ID}" \
  --expected-run-attempt "${EXPECTED_WORKFLOW_RUN_ATTEMPT}" \
  --expected-source-run-id "${EXPECTED_BUILD_SOURCE_RUN_ID}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    printf 'artifact-id=%s\n' "${EXPECTED_ARTIFACT_ID}"
    printf 'artifact-digest=%s\n' "${EXPECTED_ARTIFACT_DIGEST}"
    printf 'bundle-sha256=%s\n' "${actual_bundle_sha256}"
    printf 'source-commit=%s\n' "${EXPECTED_SOURCE_COMMIT}"
    printf 'workflow-sha=%s\n' "${EXPECTED_WORKFLOW_SHA}"
    printf 'workflow-run-id=%s\n' "${EXPECTED_WORKFLOW_RUN_ID}"
    printf 'workflow-run-attempt=%s\n' "${EXPECTED_WORKFLOW_RUN_ATTEMPT}"
    printf 'build-source-run-id=%s\n' "${EXPECTED_BUILD_SOURCE_RUN_ID}"
  } >>"${GITHUB_OUTPUT}"
fi

printf 'Verified immutable backend release transport artifact %s.\n' \
  "${EXPECTED_ARTIFACT_ID}"
