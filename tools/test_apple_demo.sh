#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
scratch=${1:?Supply the existing Swift package scratch path}
swift build --quiet --package-path "$root/apps/apple/CertigoKit" \
  --scratch-path "$scratch" --jobs 4 -Xswiftc -warnings-as-errors
build=$(swift build --show-bin-path --package-path "$root/apps/apple/CertigoKit" \
  --scratch-path "$scratch")
temporary=$(mktemp -d)
trap 'rm -f -- "$temporary/demo-tests"; rmdir -- "$temporary"' EXIT
objects=()
while IFS= read -r -d '' object; do objects+=("$object"); done \
  < <(find "$build/CertigoDomain.build" -name '*.o' -print0)
swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete \
  -warnings-as-errors -I "$build/Modules" \
  "$root/apps/apple/CertigoNative/Sources/NativeCatalogModels.swift" \
  "$root/apps/apple/CertigoNative/Sources/NativeCopyCatalog.swift" \
  "$root/apps/apple/CertigoNative/Sources/NativeDemoModels.swift" \
  "$root/apps/apple/CertigoNative/Sources/NativeLessonReadingContent.swift" \
  "$root/apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift" \
  "${objects[@]}" -o "$temporary/demo-tests"
"$temporary/demo-tests"
