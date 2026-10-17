# Isolated iOS runtime protection tests

This simulator-only, hostless XCTest project references the existing
`CertigoKit/Tests/CertigoKitTests/RuntimeDiskProtectionTests.swift` directly.
It does not copy or replace that test source. Its only linked package product
is `CertigoData`, from the sibling local `CertigoKit` package.

The simulator SDK makes `#if os(iOS)` true in the test and production sources.
The Debug test action enables testability for `@testable import CertigoData`
and uses the real iOS-conditional `CertigoAppleFileIO` dependency. No stub,
application host, MSAL dependency, login, entitlement or signing identity is
introduced. The existing app project and its empty Testables remain unchanged.

The shared scheme selects exactly:

- `testFoundationProtectionSetterReadsBackExactPolicyOnEmptyFile`
- `testProtectionAttributeRepresentationsFailClosed`
- `testProtectedDescriptorWriteRetainsFirstUnlockPolicyAndRemovesEmptyWitness`

## Simulator architecture alignment

The prior Apple run reported `CertigoData.swiftmodule/arm64-apple-ios-simulator`
while the test target's Swift driver was compiling `CertigoProtectionTests` for
`x86_64`. That is the observed incompatibility; the available output does not
establish which setting or invocation caused Xcode to select those different
architectures.

The Debug project configuration now sets `ONLY_ACTIVE_ARCH = YES`, leaving Xcode
to select the active architecture from the requested simulator destination.
This follows the destination on Apple Silicon (`arm64`) and Intel (`x86_64`)
instead of hard-coding one simulator architecture. The setting is limited to
the Debug project configuration used by this scheme; Release and device builds
are unchanged. The retry must confirm the test target and `CertigoData` use the
same simulator architecture. On the provided Apple Silicon iPhone simulator
that should be `arm64`; if the mismatch remains, stop and retain the log rather
than adding architecture exclusions or forcing a different slice.

## Deferred, grouped Mac execution

These commands are preparation, not evidence of an Apple build or test run.
Run only within the separately authorized grouped Mac validation, from the new
isolated correction checkout at the exact reviewed commit. Use the existing
Xcode/SDK 27.1 and Apple Silicon simulator; do not update the original
`$RUN/source` checkout or install tools.

Reuse the existing Xcode SourcePackages cache at
`$HOME/Developer/Certigo-preview-c8f0a74f.lZNx2H/SourcePackages`, containing the
exact Crypto 5.0.1 and ASN.1 1.7.3 revisions from the lock. No MSAL binary is
required. The retry creates a fresh, uniquely named harness DerivedData
directory under `$RUN` so the failed architecture product cannot be reused,
while leaving the shared package cache unchanged. It uses a new result bundle
and log; it must not overwrite `$RUN/ProtectionTests.xcresult` or its prior log.
If the exact package sources are absent, stop for authorization instead of
downloading, upgrading packages or removing the resolution guards.

```bash
set -euo pipefail
RUN=/Users/gabrielchambaud/Developer/Certigo-final-validation.miqgke
FIX_COMMIT='636cca591d278efd23432e051ca2a10b4fc0a56d'
SOURCE="$RUN/source-arch-fix"
PACKAGES="$HOME/Developer/Certigo-preview-c8f0a74f.lZNx2H/SourcePackages"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
RESULT="$RUN/ProtectionTests-arch-retry-$STAMP.xcresult"
LOG="$RUN/ProtectionTests-arch-retry-$STAMP.log"

test ! -e "$SOURCE"
git init "$SOURCE"
git -C "$SOURCE" fetch --no-tags \
  https://github.com/gaby27072001/certigo.git \
  refs/heads/fix/ios-protection-test-arch
git -C "$SOURCE" checkout --detach "$FIX_COMMIT"
test "$(git -C "$SOURCE" rev-parse HEAD)" = "$FIX_COMMIT"
test -d "$PACKAGES"
test ! -e "$RESULT"
test ! -e "$LOG"
DERIVED="$(mktemp -d "$RUN/HarnessDerivedData-arch-$STAMP.XXXXXX")"

if xcodebuild test -verbose \
  -project "$SOURCE/apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj" \
  -scheme CertigoProtectionTests \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,id=CED0443A-E78E-405C-AB02-80FADB495EC6' \
  -derivedDataPath "$DERIVED" \
  -resultBundlePath "$RESULT" \
  -clonedSourcePackagesDirPath "$PACKAGES" \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  -skipPackageUpdates \
  -parallel-testing-enabled NO \
  -only-testing:CertigoProtectionTests/RuntimeDiskProtectionTests \
  CODE_SIGNING_ALLOWED=NO >"$LOG" 2>&1; then
  printf 'Xcode command succeeded. Inspect architecture and test totals in %s\n' "$LOG"
else
  status=$?
  printf 'Xcode failed (exit %s); preserve and inspect %s\n' "$status" "$LOG" >&2
  exit "$status"
fi
```

The destination is the previously identified DeviceHub iPhone 17 simulator;
its availability and installed runtime must be confirmed in the grouped Mac
inventory. No simulator creation, runtime installation, physical-device run or
application launch is authorized by this document.

The acceptance evidence must name the exact source commit, Xcode/SDK, destination
and xcresult. Require **three executed tests, zero failures and zero skipped**;
a successful build, zero discovered tests or the unrelated app scheme is not
a pass. Preserve an Xcode loading, cache, linking or test discovery failure as a
blocker. Confirm the verbose log shows the XCTest target and `CertigoData` built
for the same active simulator architecture before interpreting the test result.
The lock retains existing versions; it is not proof that Xcode has accepted the
new project or cached dependency graph.

## Proof limits

Linux can check source identity, syntax and project/scheme structure; it cannot
execute these iOS-conditional tests or establish that Xcode loads and links this
new harness. An actual simulator test run remains required.

The tests check policy representations, Foundation attribute read-back and the
runtime descriptor write/witness cleanup. Even a simulator pass does not prove
physical-device protected-data lifecycle across lock/unlock/reboot, Keychain,
outbox hardening, cross-process or power-loss guarantees for `SubmissionStore`,
provider authentication or runtime content graph closure. No extra Foundation
outbox test or historical NoAuth/ProtectionProbe tooling is included.
