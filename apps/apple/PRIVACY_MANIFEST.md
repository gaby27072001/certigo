# Native app privacy manifest

`CertigoNative/Resources/PrivacyInfo.xcprivacy` declares the required-reason APIs
used by the native app and its linked first-party `CertigoKit` code:

| API category | Reason | Code path and purpose |
| --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | `CertigoNative/Sources/CertigoNativeApp.swift` (`@AppStorage`) and `NativeModel.swift` (default `UserDefaults`) keep demo and sign-out state app-only. |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | `CertigoKit/Sources/CertigoData/RuntimeDisk.swift` and `SubmissionStore.swift` inspect file size, type, identity, and link metadata in app-managed storage. |

The manifest is included in the `CertigoNative` app target's resources. It
intentionally omits data-collection and tracking declarations; this change does
not establish a complete privacy report or App Store compliance.

`C617.1` applies to metadata accessed inside the app's own container. The
current `SubmissionStore` path is under Application Support. `RuntimeDisk`
accepts a caller-provided root, so re-evaluate this reason if a future caller
uses a user-granted location outside the app container.

The project pins MSAL `2.16.0`, but its resolved package source and bundled
manifest were not available for inspection in this checkout. This app manifest
does not declare required-reason API use on behalf of MSAL. Verify the pinned
SDK's own privacy manifest and bundled resources before distribution; do not
edit the SDK or change its pin as part of this work.

Reason definitions and manifest requirements are from Apple's [required reason
API guidance](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api),
[API category and reason values](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype),
and [privacy manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

Run the focused static coverage check from the repository root:

```powershell
python -m unittest tools.tests.test_native_privacy_manifest
```

This check validates the property list, declared reasons, source evidence, and
Xcode resource references. It does not replace an Xcode archive/privacy report
or review of resolved third-party SDK bundles on macOS.
