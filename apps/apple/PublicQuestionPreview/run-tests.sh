#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
# External Crypto objects are read-only; never build into another worktree's scratch.
crypto_build=${1:?Supply an existing Swift 6.2.3 Crypto build directory containing Modules}
temporary=$(mktemp -d)
trap 'rm -f -- "$temporary/preview-tests"; rmdir -- "$temporary"' EXIT
objects=()
for module in Crypto CryptoBoringWrapper CCryptoBoringSSL CXKCP CXKCPShims; do
  while IFS= read -r -d '' object; do objects+=("$object"); done \
    < <(find "$crypto_build/$module.build" -name '*.o' -print0)
done
swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete \
  -warnings-as-errors -I "$crypto_build/Modules" \
  "$root/apps/apple/CertigoKit/Sources/CertigoData/CanonicalQuestionReader.swift" \
  "$root/apps/apple/CertigoKit/Sources/CertigoData/PublicReleaseContracts.swift" \
  "$root/apps/apple/CertigoKit/Sources/CertigoData/PublicResourceReader.swift" \
  "$root/apps/apple/PublicQuestionPreview/PublicQuestionPreview.swift" \
  "$root/apps/apple/PublicQuestionPreview/Tests.swift" \
  "${objects[@]}" -lstdc++ -o "$temporary/preview-tests"
"$temporary/preview-tests" "$root/apps/apple/PublicQuestionPreview/Fixtures"
