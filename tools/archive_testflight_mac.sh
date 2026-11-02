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
build=${CERTIGO_DISTRIBUTION_BUILD:-8}
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

printf 'Archiving CertigoNative %s (%s) with Team %s...\n' "$version" "$build" "$team_id"
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
  CERTIGO_DISTRIBUTION_VERSION="$version" \
  CERTIGO_DISTRIBUTION_BUILD="$build"

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
