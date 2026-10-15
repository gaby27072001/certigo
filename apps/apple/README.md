# Native Apple visual slice

The first SwiftUI demonstration is opt-in from **Decouvrir la demo** on launch.
It implements the owner-approved objective-first journey with local synthetic
state. It does not sign in, instantiate NativeModel, access the developer vault,
or contact an API. Only opening the separate developer connector creates that
model; the existing development-only connector is retained.

The demo includes objective selection, MCQ choice, pending submission, an
explicit static mock explanation, follow-up, and persisted resume. Its question
and explanation are invented, separate from the canonical public question bank.
There is no local grade, readiness, reward, or production progression.

See [NATIVE_UI_BRIEF.md](NATIVE_UI_BRIEF.md) for the capture journey and states,
[PRODUCT.md](PRODUCT.md) for truth boundaries, and [DESIGN.md](DESIGN.md) for
the scoped native translation of Prism.

## Linux source checks

Use the existing Swift 6 toolchain; no new dependencies are needed. From the
repository root in Linux, with Swift already on PATH:

```bash
swift format lint --configuration apps/apple/.swift-format --strict \
  apps/apple/CertigoNative/Sources/CertigoNativeApp.swift \
  apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift
swiftc -frontend -parse apps/apple/CertigoNative/Sources/CertigoNativeApp.swift
swiftc -parse-as-library -swift-version 6 -strict-concurrency=complete \
  -warnings-as-errors \
  apps/apple/CertigoNative/Sources/CertigoNativeApp.swift \
  apps/apple/CertigoNative/DemoTests/NativeDemoFlowTests.swift \
  -o /tmp/certigo-native-demo-tests
/tmp/certigo-native-demo-tests
rm -f /tmp/certigo-native-demo-tests
```

The Foundation harness validates only demo transitions and stored-state
invariants. SwiftUI blocks are excluded from Linux compilation. Syntax parsing
and formatting do not prove SwiftUI type correctness or Apple appearance.
The existing Linux linker can emit an RWX-segment warning independently of
Swift's warnings-as-errors; do not report this as a warning-free Apple build.

## Apple validation still required

No Apple build, XCTest UI run, or rendered capture is supplied by this slice.
`#Preview` is a source preview entry, not evidence that a preview rendered.
Use the existing main target with Xcode 26 or newer for the iOS 26 system
glass API and an unsigned simulator build. The deployment target stays iOS 17;
DemoPrimaryButton falls back to native borderedProminent there and when
Reduce Transparency is enabled. Native tab/navigation bars use system behavior.

An authorized Apple pass must inspect iPhone and iPad, light/dark, large
Dynamic Type, Reduce Motion/Transparency, selection, pending/offline/retry,
back navigation, close/reopen resume, and reset. No target/scheme/probe, signing,
SDK installation, account, or CI runner policy is changed here. Existing
NoAuth protection tests are not claimed as a UI gate.

## MSAL runtime packaging

The app links the pinned MSAL binary package. Xcode's SwiftPM integration copies
the selected XCFramework library into the app's Frameworks directory; do not add
a copy phase referencing the package product, which resolves to the non-file
aggregate `MSAL-product`. Debug and Release preserve inherited runpaths and
search `@executable_path/Frameworks`. This is required even when only the
synthetic demo is opened: dyld loads linked libraries before SwiftUI.
Unsigned simulator builds remain unsigned; this does not grant device signing
or change any authentication configuration.

The source regression check is part of
`python -m unittest discover -s tools -p test_validate_apple_noauth.py`.
An Apple build must additionally verify `Frameworks/MSAL.framework/MSAL`,
its simulator architecture and load commands, then actually launch the app.
Static project checks alone do not prove packaging or runtime success.
