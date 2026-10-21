#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bash tools/validate_apple_mac_one_shot.sh [--prepare-archive]

Run in the permanent, clean main checkout on a Mac with Xcode 26+.
Required: CERTIGO_SIMULATOR_ID (an existing iOS Simulator UUID).
For --prepare-archive: CERTIGO_DISTRIBUTION_VERSION and CERTIGO_DISTRIBUTION_BUILD,
previously checked in App Store Connect. Creates an UNSIGNED archive, not an IPA.
Optional: CERTIGO_UI_TEST_PROJECT and CERTIGO_UI_TEST_SCHEME, supplied together
after a real UI-test target is integrated. Relative paths are repository-relative.
Optional: CERTIGO_APPLE_LOG_ROOT (absolute, outside the checkout).

Does not install tools/runtimes, change signing, launch real authentication,
upload a build or modify App Store Connect. Missing UI coverage exits 3 even
when package/protection tests, Simulator build and archive preparation succeed.
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
archive=false
case "${1-}" in
  --help|-h) usage; exit 0 ;;
  --prepare-archive) archive=true; shift ;;
  "") ;;
  *) usage >&2; exit 1 ;;
esac
[[ $# == 0 ]] || fail 'Unexpected arguments.'
[[ $(uname -s) == Darwin ]] || fail 'This command requires macOS and Apple SDKs.'
for tool in git swift xcodebuild xcrun python3 plutil; do
  command -v "$tool" >/dev/null || fail "Missing prerequisite: $tool"
done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
[[ -z $(git status --porcelain --untracked-files=all) ]] \
  || fail 'Checkout has local changes. Preserve them before updating; nothing was pulled.'
[[ $(git branch --show-current) == main ]] || fail 'Use the permanent main checkout.'
[[ $(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}') == origin/main ]] \
  || fail 'main must track origin/main; no branch or upstream is changed automatically.'
simulator=${CERTIGO_SIMULATOR_ID:?Set CERTIGO_SIMULATOR_ID to an existing iOS Simulator UUID}
[[ $simulator =~ ^[0-9A-Fa-f-]{36}$ ]] || fail 'Invalid simulator UUID.'
xcode_major=$(xcodebuild -version | sed -n 's/^Xcode \([0-9]*\).*/\1/p')
[[ $xcode_major =~ ^[0-9]+$ && $xcode_major -ge 26 ]] || fail 'Select full Xcode 26 or newer.'
if $archive; then
  MARKETING_VERSION=${CERTIGO_DISTRIBUTION_VERSION-} \
    CURRENT_PROJECT_VERSION=${CERTIGO_DISTRIBUTION_BUILD-} \
    sh "$root/tools/validate_native_distribution.sh"
fi
ui_project=${CERTIGO_UI_TEST_PROJECT-}
ui_scheme=${CERTIGO_UI_TEST_SCHEME-}
[[ -z $ui_project && -z $ui_scheme || -n $ui_project && -n $ui_scheme ]] \
  || fail 'Supply both UI-test project and scheme, or neither.'
if [[ -n $ui_project ]]; then
  [[ $ui_project == /* ]] || ui_project="$root/$ui_project"
  [[ -d $ui_project ]] || fail 'UI-test project does not exist.'
fi
log_root=${CERTIGO_APPLE_LOG_ROOT:-"$HOME/Library/Logs/Certigo"}
[[ $log_root == /* ]] || fail 'Log root must be absolute.'
mkdir -p "$log_root"
log_root=$(cd "$log_root" && pwd)
case "$log_root/" in "$root/"*) fail 'Keep logs and xcresult outside the checkout.' ;; esac
run=$(mktemp -d "$log_root/mac-validation.XXXXXX")
exec > >(tee "$run/run.log") 2>&1
printf 'Evidence directory: %s\n' "$run"
git rev-parse HEAD > "$run/base-commit.txt"
git pull --ff-only
[[ -z $(git status --porcelain --untracked-files=all) ]] || fail 'Checkout changed during update.'
git rev-parse HEAD > "$run/tested-commit.txt"
xcodebuild -version > "$run/xcode-version.txt"
swift --version > "$run/swift-version.txt"
xcrun simctl list devices available --json > "$run/simulators.json"
python3 - "$run/simulators.json" "$simulator" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
if not any(
    item["udid"].lower() == sys.argv[2].lower() and item.get("isAvailable")
    for runtime, items in data["devices"].items() if ".iOS-" in runtime
    for item in items
):
    raise SystemExit("Requested iOS simulator/runtime is unavailable; nothing is installed automatically")
PY
python3 tools/project_state.py --check
swift test --package-path apps/apple/CertigoKit --scratch-path "$run/SwiftPM" \
  -Xswiftc -warnings-as-errors 2>&1 | tee "$run/package-tests.log"
project="$root/apps/apple/CertigoNative/CertigoNative.xcodeproj"
destination="platform=iOS Simulator,id=$simulator"
common=(-destination "$destination" -clonedSourcePackagesDirPath "$run/SourcePackages"
  -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates)
xcodebuild build -project "$project" -scheme CertigoNative -configuration Debug \
  "${common[@]}" -derivedDataPath "$run/AppDerivedData" \
  -resultBundlePath "$run/SimulatorBuild.xcresult" CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$run/simulator-build.log"
xcodebuild test \
  -project "$root/apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj" \
  -scheme CertigoProtectionTests -configuration Debug "${common[@]}" \
  -derivedDataPath "$run/ProtectionDerivedData" \
  -resultBundlePath "$run/ProtectionTests.xcresult" -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$run/protection-tests.log"

check_tests() {
  local result=$1 minimum=$2
  xcrun xcresulttool get test-results summary --path "$result" > "$result.summary.json"
  python3 - "$result.summary.json" "$minimum" <<'PY'
import json, sys
summary = json.load(open(sys.argv[1]))
counts = [summary.get(key) for key in ("passedTests", "failedTests", "skippedTests")]
if (not all(type(count) is int and count >= 0 for count in counts)
        or summary.get("result") != "Passed"
        or counts[0] < int(sys.argv[2])
        or counts[1] != 0 or counts[2] != 0):
    raise SystemExit("Require executed passing tests, zero failures and zero skipped; inspect xcresult")
PY
}
check_tests "$run/ProtectionTests.xcresult" 3
ui_status='BLOCKED: no native UI test target configured; no UI execution claimed.'
if [[ -n $ui_project ]]; then
  plutil -convert json -o "$run/ui-project.json" "$ui_project/project.pbxproj"
  python3 - "$ui_project" "$ui_scheme" "$run/ui-project.json" > "$run/ui-targets.txt" <<'PY'
import json, pathlib, sys, xml.etree.ElementTree as ET
project, scheme = pathlib.Path(sys.argv[1]), sys.argv[2]
if "/" in scheme or "\\" in scheme:
    raise SystemExit("Invalid scheme name")
objects = json.load(open(sys.argv[3]))["objects"]
tree = ET.parse(project / "xcshareddata/xcschemes" / (scheme + ".xcscheme"))
names = []
for ref in tree.findall(".//TestableReference[@skipped='NO']/BuildableReference"):
    if ref.get("ReferencedContainer") != "container:" + project.name:
        raise SystemExit("UI test references another project; verify that configuration separately")
    target = objects.get(ref.get("BlueprintIdentifier"), {})
    if target.get("productType") == "com.apple.product-type.bundle.ui-testing":
        name = target["name"]
        if "/" in name or "\n" in name or not name:
            raise SystemExit("Invalid UI target name")
        names.append(name)
if not names:
    raise SystemExit("UI scheme has no enabled UI-testing target; unit tests are not UI coverage")
print("\n".join(names))
PY
  ui_only=()
  while IFS= read -r target; do ui_only+=("-only-testing:$target"); done < "$run/ui-targets.txt"
  xcodebuild test -project "$ui_project" -scheme "$ui_scheme" -configuration Debug \
    "${common[@]}" "${ui_only[@]}" -derivedDataPath "$run/UIDerivedData" \
    -resultBundlePath "$run/UITests.xcresult" -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$run/ui-tests.log"
  check_tests "$run/UITests.xcresult" 1
  ui_status='UI test scheme executed; inspect named test coverage in UITests.xcresult.'
fi
if $archive; then
  xcodebuild archive -project "$project" -scheme 'CertigoNative Distribution' \
    -configuration Distribution -destination 'generic/platform=iOS' \
    -clonedSourcePackagesDirPath "$run/SourcePackages" \
    -onlyUsePackageVersionsFromResolvedFile -skipPackageUpdates \
    -derivedDataPath "$run/ArchiveDerivedData" \
    -archivePath "$run/CertigoNative-unsigned.xcarchive" \
    -resultBundlePath "$run/Archive.xcresult" CODE_SIGNING_ALLOWED=NO \
    CERTIGO_DISTRIBUTION_VERSION="$CERTIGO_DISTRIBUTION_VERSION" \
    CERTIGO_DISTRIBUTION_BUILD="$CERTIGO_DISTRIBUTION_BUILD" \
    2>&1 | tee "$run/archive.log"
  [[ -d "$run/CertigoNative-unsigned.xcarchive/Products/Applications/CertigoNative.app" ]] \
    || fail 'Archive command produced no application archive.'
fi
[[ $(git rev-parse HEAD) == "$(cat "$run/tested-commit.txt")" ]] \
  || fail 'HEAD changed during validation; results do not describe the current checkout.'
[[ -z $(git status --porcelain --untracked-files=all) ]] \
  || fail 'Checkout changed during validation; preserve and inspect changes.'
printf '%s\n' "$ui_status" \
  'Package tests, Simulator build and protection tests completed.' \
  'No physical-device, live CIAM, signing, upload or App Review approval is established.' \
  > "$run/summary.txt"
if $archive; then
  printf '%s\n' 'Unsigned Distribution archive prepared; NOT an uploadable TestFlight build.' \
    >> "$run/summary.txt"
fi
cat "$run/summary.txt"
[[ -n $ui_project ]] || exit 3
