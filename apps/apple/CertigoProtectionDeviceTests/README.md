# Physical-device XCTest host preparation

This project is separate from the simulator-only `CertigoProtectionTests`
project. It uses a minimal UIKit application solely as the host for the same
three existing tests, referenced in place from
`CertigoKit/Tests/CertigoKitTests/RuntimeDiskProtectionTests.swift`. The app
does not import Certigo, start authentication, contact a service, or implement
product behavior. The test target links the real local `CertigoData` package.

The shared scheme selects only:

- `testFoundationProtectionSetterReadsBackExactPolicyOnEmptyFile`
- `testProtectionAttributeRepresentationsFailClosed`
- `testProtectedDescriptorWriteRetainsFirstUnlockPolicyAndRemovesEmptyWitness`

## Device-capable configuration

The host and test targets support `iphoneos` and `iphonesimulator`, use the
iPhoneOS SDK setting, and specify no architecture slice. Xcode resolves the
appropriate device or simulator platform and architecture. The test bundle
depends on the host target and uses `TEST_HOST`/`BUNDLE_LOADER`; the scheme's
test action expands the host app. This is an app-hosted XCTest configuration,
not a hostless logic-test bundle.

Automatic signing style is available as a project configuration choice, but
this source does **not** select a development team, signing identity,
provisioning profile, device identifier, entitlement, or signing certificate.
No signing has been activated. Before a physical-device test can be built or
run, the device must be paired and trusted in Xcode, an authorized person must
choose the appropriate team/signing setup and unique bundle IDs in Xcode, and
Xcode may require Developer Mode and a provisioning profile. Those steps can
register the device, change its settings, or use an account; they are not
authorized or performed by this preparation.

## Scope and evidence limit

This is project-source preparation only. No Xcode project-load check, Apple
SDK build, signature, install, app launch, test execution, or physical-device
file-protection observation was performed. A later authorized device test must
report all three original methods as executed, with exact Xcode/iOS/device
context and its result bundle. It must preserve any failure; these tests must
not be skipped, substituted, weakened, or treated as passing merely because
the app-hosted scheme is configured.

Even a passing XCTest run does not by itself demonstrate lock/reboot protected
data lifecycle. This harness does not exercise Keychain, authentication,
content activation, or production app startup.

Apple references:

- [Adding tests to your Xcode project](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)
- [Running your app on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Managing devices in Device Hub](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
