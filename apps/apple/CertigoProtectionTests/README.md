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

## Deferred, grouped Mac execution

These commands are preparation, not evidence of an Apple build or test run.
Run only within the separately authorized grouped Mac validation, from a clean
isolated checkout at the reviewed harness commit. Use an existing Xcode/SDK 26+
and Swift 6.2-compatible installation. Do not update a historical preview
checkout or install tools.

Set `PACKAGES` to an already approved, populated Xcode SourcePackages cache
containing the exact Crypto 5.0.1 and ASN.1 1.7.3 revisions in the copied lock.
No MSAL binary is required. `DERIVED` and `RESULT` must be dedicated paths outside
the checkout; `RESULT` must not already exist. Inspect the cache before running;
if an exact package is absent, stop for authorization instead of downloading,
upgrading packages or removing the resolution guards.

```bash
set -euo pipefail
: "${PACKAGES:?Set the approved existing Xcode SourcePackages cache}"
: "${DERIVED:?Set an isolated harness DerivedData path}"
: "${RESULT:?Set a new harness xcresult path}"
test -d "$PACKAGES"
test ! -e "$RESULT"

xcodebuild test \
  -project apps/apple/CertigoProtectionTests/CertigoProtectionTests.xcodeproj \
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
  CODE_SIGNING_ALLOWED=NO
```

The destination is the previously identified DeviceHub iPhone 17 simulator;
its availability and installed runtime must be confirmed in the grouped Mac
inventory. No simulator creation, runtime installation, physical-device run or
application launch is authorized by this document.

The acceptance evidence must name the exact source commit, Xcode/SDK, destination
and xcresult. Require **three executed tests, zero failures and zero skipped**;
a successful build, zero discovered tests or the unrelated app scheme is not
a pass. Preserve an Xcode loading, cache, linking or test discovery failure as a
blocker. The lock retains existing versions; it is not proof that Xcode has
accepted the new project or cached dependency graph.

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
