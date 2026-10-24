# Native app privacy manifest

`CertigoNative/Resources/PrivacyInfo.xcprivacy` declares the required-reason APIs
used by the native app and its linked first-party `CertigoKit` code:

| API category | Reason | Code path and purpose |
| --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | `CertigoNative/Sources/CertigoNativeApp.swift` (`@AppStorage`) and `NativeModel.swift` (default `UserDefaults`) keep demo and sign-out state app-only. |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | `CertigoKit/Sources/CertigoData/RuntimeDisk.swift`, `SubmissionStore.swift`, and `CertigoNative/Sources/NativeModel.swift` inspect file size, type, identity, and link metadata in app-managed storage. The native activity snapshot uses only file size. |

The manifest is included in the `CertigoNative` app target's resources. It
intentionally omits data-collection and tracking declarations; this change does
not establish a complete privacy report or App Store compliance.

`C617.1` applies to metadata accessed inside the app's own container. The
current `SubmissionStore` path is under Application Support. `RuntimeDisk`
accepts a caller-provided root, so re-evaluate this reason if a future caller
uses a user-granted location outside the app container.

The project pins MSAL `2.16.0` as a Swift Package Manager binary target. At
upstream commit
[`8dfe5bf41fe10e6d2afed62a72c4232adbef20f4`](https://github.com/AzureAD/microsoft-authentication-library-for-objc/tree/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4),
`Package.swift` (blob
`229d03c01d1f42b48f21a6ce3b64d40f1bbea46a`) declares the release `2.16.0/MSAL.zip`
binary target and checksum
`3bef53dae500878c2f07fd7493d54063f4fdcb057dfdb3c239256289a349edb8`. The same
source tree contains [`MSAL/PrivacyInfo.xcprivacy`](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4/MSAL/PrivacyInfo.xcprivacy)
(blob `265db1451895df461a550c6debdc613e3f20425c`), which declares UserDefaults
reasons `1C8F.1` and `CA92.1` and eight collected-data categories: name, email
address, other user contact information, customer support, user ID, device ID,
diagnostic data, and phone number. Those are the upstream SDK's declarations;
this source-file inspection does not independently verify what the release
archive contains or establish which data the integrated app actually collects.

The app manifest therefore does not copy SDK declarations or claim to speak for
MSAL. Apple requires an SDK to report its own API and data practices in its own
bundle manifest. Confirm that the pinned archive includes this manifest and
inspect the archived app's aggregated privacy report before distribution; do
not edit the SDK or change its pin as part of this work.

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
