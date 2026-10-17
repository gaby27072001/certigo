#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=${1:?Supply the existing Swift package scratch path}
if [[ $(uname -s) != Linux ]]; then
  printf '%s\n' 'This harness validates model coordination on Linux, not Apple SDKs.' >&2
  exit 1
fi
swift build --quiet --package-path "$root/apps/apple/CertigoKit" \
  --scratch-path "$scratch" --jobs 4 -Xswiftc -warnings-as-errors
build=$(swift build --show-bin-path --package-path "$root/apps/apple/CertigoKit" \
  --scratch-path "$scratch")
temporary=$(mktemp -d)
trap 'rm -f -- "$temporary/model-tests"; rmdir -- "$temporary"' EXIT
objects=()
for module in CertigoDomain CertigoData Crypto CryptoBoringWrapper CCryptoBoringSSL CXKCP CXKCPShims; do
  while IFS= read -r -d '' object; do objects+=("$object"); done \
    < <(find "$build/$module.build" -name '*.o' -print0)
done
swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete \
  -warnings-as-errors -I "$build/Modules" \
  "$root/apps/apple/CertigoNative/Sources/NativeModel.swift" \
  "$root/apps/apple/CertigoNative/ModelTests/NativeModelTests.swift" \
  "${objects[@]}" -lstdc++ -o "$temporary/model-tests"
"$temporary/model-tests" "$root/apps/apple/CertigoKit/Tests/CertigoKitTests/Fixtures"
