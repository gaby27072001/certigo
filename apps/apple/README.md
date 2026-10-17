# Native Apple visual slice

The SwiftUI demonstration is opt-in from **Explore the demo** on launch.
It implements the owner-approved objective-first journey with local synthetic
state. It does not sign in, instantiate NativeModel, access the developer vault,
or contact an API. Only opening the separate developer connector creates that
model; the existing development-only connector is retained.

The demo includes objective selection, a preparation brief, MCQ choice, pending
submission, an explicit static mock explanation, follow-up, and persisted
resume. Each of the two objectives has a distinct invented situation and
explanation, separate from the canonical public question bank.
There is no local grade, readiness, reward, or production progression.

The reviewable "decision workshop" extension presents situation, decision and
explanation as reading stages, not mastery or completion metrics. Explanations
separate the decisive constraint, service responsibilities and takeaway.
History reopens the exercise in the Learn / My Learning navigation stack.

The approved English navigation now uses **Learn / Coach / Social / Profile**.
Learn groups **My Learning / Explore**; Profile owns **Progress & history**
and **Settings**. Existing demo snapshots preserve their goals, answers and
routes through this relocation. Coach and Social are explicitly unavailable
preview destinations, not working services; they create no messages,
relationships, memory or shared data. Learning fixtures remain in French and
are labeled as such. Authored interface copy is English; API content is not
silently translated.

## Explicit active goal in the test connector

The separate authenticated test connector now offers **Choose as active goal**
in the browsed learning path. Browsing and loading a path remain read-only.
The button calls the existing `NativeModel.chooseActiveTrack` wrapper only on
an explicit tap. Saving is shown as pending, with the previous server-confirmed
goal still visible; only `profile.activeTrackId` establishes confirmation.
The existing model error alert exposes conflicts and uncertain outcomes.
There is no automatic retry or client-side goal overwrite.

The authenticated root also uses **Learn / Coach / Social / Profile**.
Learn keeps the existing catalog/path/session split view, with My Learning
showing the confirmed goal plus any already open path, and Explore showing
the catalog. Changing a tab
or local section does not load a path, change the active goal, or clear an
answer. Resume reveals the current model activity without loading it again.
Profile shows only the returned identity, XP, active goal, last loaded path
readiness and device submission history. Its Settings owns Disconnect.
Coach and Social remain explicitly unavailable, without live legacy calls.
Navigation is in memory only and resets on account change; no new bookmark
or unsent-answer storage is introduced.

This integration preserves the model's current activity, saved attempt and
outbox. It does not persist an unsent draft or connect the real model to the
synthetic demo state. It does not enable production sign-in, Coach or Social.
The source dependency was integrated explicitly from foundation commits
`0bedcb9b` and `3339685c`; their model/transport implementation is not duplicated
in the view. Native build, accessibility and runtime validation are still
required for this new UI.

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

The Foundation harness validates demo transitions, stored-state invariants and
active-goal presentation rules. SwiftUI blocks are excluded from Linux compilation. Syntax parsing
and formatting do not prove SwiftUI type correctness or Apple appearance.
The existing Linux linker can emit an RWX-segment warning independently of
Swift's warnings-as-errors; do not report this as a warning-free Apple build.

## Apple validation

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

### Observed preview evidence

On 2026-10-15, the owner's Mac build receipt confirmed an unsigned arm64
simulator build of `5eca31de8067772586c3b6c8ff92a84de4f76026`, the bundled MSAL
binary, its simulator platform, the Frameworks runpath, installation, and a
launch PID. A subsequent owner photo, relayed by the coordinating session at
13:28 local time, showed Certigo's entry screen in Device Hub on iPhone 17 /
iOS 27, without a crash alert at that instant. The source association comes
from the preceding build and launch receipt, not a SHA visible in the photo.
Private receipts and the photo are retained in the owner's session, not copied
into this repository.

This confirms entry-screen rendering for that observed run only. It does not
validate the demo journey, sustained runtime, authentication, XCTest UI,
VoiceOver, iPad, or the accessibility and appearance matrix above. A different
source revision, build configuration, dependencies, device, or runtime requires
new evidence; do not transfer this result to a newer build.

The coordinator subsequently reported a 43.585-second owner video from the same
preview run showing Objective / Explorer / Follow-up, objective switching, a
three-option question, selection, pending and fictive explanation, without an
observed alert. This is the coordinator's video observation, not a new build
receipt or this implementation session's independent video review. It extends
the observed demo journey, not authentication, relaunch persistence, VoiceOver,
iPad or long-term stability. The newer decision-workshop source is not covered
by that historical video.

### Xcode 27 display host

Xcode 27 exposes simulated devices through **Device Hub**. Open it with
**Xcode > Open Developer Tool > Device Hub**, then select the existing simulator
in its sidebar to view the screen. Do not infer a broken Xcode installation
from an absent legacy `Simulator.app` path. See Apple's
[Device Hub documentation](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub).

Continue preview work in the already chosen Mac project and directory. Update
that checkout only when clean; preserve local changes and reuse its existing
package cache and DerivedData rather than creating another preview copy.
Opening Device Hub does not require another build or an authentication action.
Keep the developer connector closed during synthetic demo observation.

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
