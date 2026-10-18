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

The host adopts the UIKit scene-based life cycle. Both host configurations
generate the scene manifest, and the app delegate supplies a `UIWindowScene`
configuration with `ProtectionTestHostSceneDelegate`. The scene delegate retains
a window with an empty root view controller; it starts no product behavior.
These APIs are available at the existing iOS 17 deployment target. The test
target, selectors, package pins and signing identities are unchanged.

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

On 2026-10-18, the user reported a physical-device attempt with iOS 27.0.1 and
Xcode 27.1 that reached build/sign/install but failed host launch with
`UIScene life cycle is required for apps built with this SDK`. No test executed
in that attempt. Apple's transition documentation requires scene adoption for
apps built with the latest SDK on iOS 27; the previous host had neither a scene
manifest nor a scene configuration callback.

The scene-lifecycle correction has only source/static validation here, not an
Apple SDK build, generated-plist inspection, launch or physical test result.
A later authorized device test must
report all three original methods as executed, with exact Xcode/iOS/device
context and its result bundle. It must preserve any failure; these tests must
not be skipped, substituted, weakened, or treated as passing merely because
the app-hosted scheme is configured.

Even a passing XCTest run does not by itself demonstrate lock/reboot protected
data lifecycle. This harness does not exercise Keychain, authentication,
content activation, or production app startup.

Apple references:

- [Transitioning to the UIKit scene-based life cycle](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)
- [Adding tests to your Xcode project](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)
- [Running your app on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Managing devices in Device Hub](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
