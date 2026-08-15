#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: install-verified-flutter.sh <version> <install-directory>" >&2
  exit 2
fi

version="$1"
install_dir="$2"
platform="$(uname -s)"
architecture="$(uname -m)"

if [ "$version" != "3.44.4" ]; then
  echo "Unsupported Flutter version: $version" >&2
  exit 1
fi

case "$install_dir" in
  "$RUNNER_TEMP"/certigo-flutter-* | "$GITHUB_WORKSPACE"/.scanner-state/flutter-sdk) ;;
  *)
    echo "Flutter install directory must be isolated under RUNNER_TEMP or .scanner-state." >&2
    exit 1
    ;;
esac

case "$platform:$architecture" in
  Linux:x86_64)
    archive="stable/linux/flutter_linux_3.44.4-stable.tar.xz"
    sha256="c853cda0312a162854c481fe6a1bc286d84fbb74bfab7037c39750061dc9b466"
    archive_type="tar"
    ;;
  Darwin:x86_64)
    archive="stable/macos/flutter_macos_3.44.4-stable.zip"
    sha256="32bca4386121042e827ff2d90edbd7c7fb47c514fc04d5a87db6e3202dafde5d"
    archive_type="zip"
    ;;
  Darwin:arm64)
    archive="stable/macos/flutter_macos_arm64_3.44.4-stable.zip"
    sha256="eac833fe956c670d1f27946f25de8bc4fe4fb86146d5ef8d53e79a971a3ba042"
    archive_type="zip"
    ;;
  *)
    echo "Unsupported Flutter platform: $platform/$architecture" >&2
    exit 1
    ;;
esac

archive_file="${install_dir}.archive"
rm -rf -- "$install_dir"
rm -f -- "$archive_file"
mkdir -p -- "$install_dir"
trap 'rm -f -- "$archive_file"' EXIT

curl --fail --silent --show-error --location --retry 3 \
  --output "$archive_file" \
  "https://storage.googleapis.com/flutter_infra_release/releases/$archive"

if command -v sha256sum >/dev/null 2>&1; then
  echo "$sha256  $archive_file" | sha256sum --check --strict
else
  actual_sha256="$(shasum -a 256 "$archive_file" | awk '{print $1}')"
  if [ "$actual_sha256" != "$sha256" ]; then
    echo "Flutter archive SHA-256 mismatch." >&2
    exit 1
  fi
fi

case "$archive_type" in
  tar) tar -xJf "$archive_file" -C "$install_dir" ;;
  zip) ditto -x -k "$archive_file" "$install_dir" ;;
esac
rm -f -- "$archive_file"
trap - EXIT

flutter_executable="$install_dir/flutter/bin/flutter"
if [ ! -x "$flutter_executable" ]; then
  echo "Verified Flutter archive did not contain the expected executable." >&2
  exit 1
fi

echo "$install_dir/flutter/bin" >> "$GITHUB_PATH"
"$flutter_executable" --disable-analytics >/dev/null
"$flutter_executable" --version
