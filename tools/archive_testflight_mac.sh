#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash tools/archive_testflight_mac.sh [--team-id TEAM_ID] [--version X.Y.Z] [--build N] [--open-xcode]

Options:
  --team-id TEAM_ID   Apple Developer Team ID (10 characters, e.g. A1B2C3D4E5).
                      If omitted, auto-detected from local Apple signing certificates.
  --version X.Y.Z     Marketing version for App Store Connect (default: 1.0.0).
  --build N           Build number for App Store Connect (default: 1).
  --open-xcode        Open CertigoNative.xcodeproj in Xcode with version/build exported
                      so Product > Archive works directly from the Xcode menu.
EOF
}

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ $(uname -s) == Darwin ]] || fail 'Run this script on your Mac (macOS).'

team_id=${CERTIGO_APPLE_TEAM_ID:-FFQPC7NC68}
version=${CERTIGO_DISTRIBUTION_VERSION:-1.1.0}
build=${CERTIGO_DISTRIBUTION_BUILD:-13}
open_xcode=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id) team_id=${2:?Missing value for --team-id}; shift 2 ;;
    --version) version=${2:?Missing value for --version}; shift 2 ;;
    --build) build=${2:?Missing value for --build}; shift 2 ;;
    --open-xcode) open_xcode=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
project="$root/apps/apple/CertigoNative/CertigoNative.xcodeproj"

export CERTIGO_DISTRIBUTION_VERSION="$version"
export CERTIGO_DISTRIBUTION_BUILD="$build"
MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build" \
  sh "$root/tools/validate_native_distribution.sh"

if $open_xcode; then
  launchctl setenv CERTIGO_DISTRIBUTION_VERSION "$version" 2>/dev/null || true
  launchctl setenv CERTIGO_DISTRIBUTION_BUILD "$build" 2>/dev/null || true
  printf 'Opening CertigoNative in Xcode with version %s (%s)...\n' "$version" "$build"
  open -a Xcode "$project"
  exit 0
fi

if [[ -z $team_id ]]; then
  team_id=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*(\([A-Z0-9]\{10\}\)).*/\1/p' | head -n 1 || true)
fi
[[ $team_id =~ ^[A-Z0-9]{10}$ ]] \
  || fail 'Could not auto-detect Apple Team ID. Connect your Apple ID in Xcode > Settings > Accounts or pass --team-id YOUR_TEAM_ID.'

date_dir=$(date +%Y-%m-%d)
archive_dir="$HOME/Library/Developer/Xcode/Archives/$date_dir"
mkdir -p "$archive_dir"
archive_path="$archive_dir/CertigoNative-${version}-build${build}-$(date +%H%M%S).xcarchive"

app_swift="$root/apps/apple/CertigoNative/Sources/CertigoNativeApp.swift"
pbxproj_file="$project/project.pbxproj"
app_swift_backup=$(mktemp "${TMPDIR:-/tmp}/CertigoNativeApp.swift.XXXXXX")
pbxproj_backup=$(mktemp "${TMPDIR:-/tmp}/project.pbxproj.XXXXXX")
cp "$app_swift" "$app_swift_backup"
cp "$pbxproj_file" "$pbxproj_backup"
restore_app_swift() {
  if [[ -f "$app_swift_backup" ]]; then
    cp "$app_swift_backup" "$app_swift"
    rm -f "$app_swift_backup"
  fi
  if [[ -f "$pbxproj_backup" ]]; then
    cp "$pbxproj_backup" "$pbxproj_file"
    rm -f "$pbxproj_backup"
  fi
}
trap restore_app_swift EXIT INT TERM

python3 - "$app_swift" "$pbxproj_file" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
pbx = pathlib.Path(sys.argv[2])
pbx_text = pbx.read_text(encoding="utf-8")
target_marker = '000000000000000000000085 /* Distribution */ = {\n\t\t\tisa = XCBuildConfiguration;\n\t\t\tbuildSettings = {'
if target_marker in pbx_text:
    pbx_text = pbx_text.replace(
        target_marker,
        target_marker + '\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = CertigoNative.entitlements;',
        1,
    )
    pbx.write_text(pbx_text, encoding="utf-8")
text = path.read_text(encoding="utf-8")
text = text.replace(
    "    import CertigoDomain\n",
    "    import CertigoDomain\n    import Prism\n",
    1,
)
text = text.replace(
    "                NativeLanguageRoot()\n"
    "                    #if DEBUG\n"
    "                        .modifier(PrismDebugGalleryLauncher())\n"
    "                    #endif\n",
    "                NativeLanguageRoot()\n"
    "                    .modifier(PrismProductionShellLauncher())\n",
    1,
)
launcher = """
    private struct PrismProductionShellLauncher: ViewModifier {
        func body(content: Content) -> some View {
            PrismAppShellView()
        }
    }
"""
text = text.replace(
    "    private struct NativeLanguagePreferenceKey: EnvironmentKey {\n",
    launcher + "\n    private struct NativeLanguagePreferenceKey: EnvironmentKey {\n",
    1,
)
path.write_text(text, encoding="utf-8")
PY

printf 'Archiving CertiGo %s (%s) with Team %s...\n' "$version" "$build" "$team_id"
xcodebuild archive \
  -project "$project" \
  -scheme 'CertigoNative Distribution' \
  -configuration Distribution \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive_path" \
  -allowProvisioningUpdates \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$team_id" \
  DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
  INFOPLIST_KEY_CFBundleDisplayName=CertiGo \
  CERTIGO_DISTRIBUTION_VERSION="$version" \
  CERTIGO_DISTRIBUTION_BUILD="$build" \
  CERTIGO_PRODUCTION_CIAM_CLIENT_ID="4d1f1075-7bc5-4764-947b-701435a85f8c" \
  CERTIGO_PRODUCTION_CIAM_TENANT_ID="af721be8-5901-422a-b299-b9c57847b968" \
  CERTIGO_PRODUCTION_CIAM_AUTHORITY="https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968" \
  CERTIGO_PRODUCTION_CIAM_ISSUER="https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0" \
  CERTIGO_PRODUCTION_CIAM_AUTHORITY_KIND="standard" \
  CERTIGO_PRODUCTION_CIAM_API_BASE_URL="https://func-certigo-dev-bk3j5ja6vw23s.azurewebsites.net/api" \
  CERTIGO_PRODUCTION_CIAM_API_SCOPE="api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915/user_impersonation" \
  CERTIGO_PRODUCTION_CIAM_API_AUDIENCE="12910b8e-6c75-4d51-91d8-4d5fb8a6e915"

restore_app_swift

[[ -d "$archive_path/Products/Applications/CertigoNative.app" ]] \
  || fail 'Archive did not produce CertigoNative.app.'

mkdir -p "$archive_path/dSYMs"
for fw_bin in "$archive_path/Products/Applications/CertigoNative.app/Frameworks/"*.framework/*; do
  [[ -f "$fw_bin" && -x "$fw_bin" ]] || continue
  fw_name=$(basename "$(dirname "$fw_bin")")
  if [[ ! -d "$archive_path/dSYMs/${fw_name}.dSYM" ]]; then
    xcrun dsymutil "$fw_bin" -o "$archive_path/dSYMs/${fw_name}.dSYM" 2>/dev/null || true
  fi
done

printf 'Archive created: %s\nOpening Xcode Organizer — click "Distribute App" -> "TestFlight & App Store" -> "Upload".\n' "$archive_path"
open "$archive_path"
