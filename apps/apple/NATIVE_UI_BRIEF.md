# First native practice slice

## Approved product scope

Choose an objective, answer a question, understand its correction, resume the
work. iPhone and iPad. Native SwiftUI affordances, Prism identity, readable
opaque exercises. A question bank is not a promise of guided courses.

The owner selected A through the coordinating chat: objective first, quick
resume, catalog and follow-up tabs. The decision schematic is a session
artifact, not an Apple render.

## Boundaries

UI owns `CertigoNative/Sources/CertigoNativeApp.swift` and scoped design files.
Do not change NativeModel, CredentialVault, auth providers, CertigoKit public
interfaces, Xcode project/schemes, probes, shared tools, or APPLE_NATIVE.md.
The developer connector must remain available and must not be presented as
production sign-in. A demo is opt-in, synthetic, and never sends requests.

## States to cover

| Surface | State | User action | Truth boundary |
|---|---|---|---|
| Objective | No objective | Explore and select | Demo objective, no account |
| Objective | Selected objective | Start or resume | Demo state only |
| Catalog | Loading / empty / error | Retry or reset preview | Scenario controls, not a server outage |
| Exercise | Unselected / selected | Choose and submit | No local live verdict |
| Submission | Offline / pending | Resume or advance the explicit simulation | Pending is not correct or incorrect |
| Explanation | Mock response | Read and return | Explicit simulation, no rewards or readiness |
| Follow-up | Pending / reviewed | Reopen work | No server-confirmed progress claim |
| Resume | Stored demo flow and tab route | Continue or reset | Separate demo-only persistence keys |

## Validation contract

Linux can check Foundation demo transitions, Codable round trips, Swift syntax,
and formatting. It cannot type-check SwiftUI, prove availability signatures,
render Liquid Glass, inspect VoiceOver, or demonstrate Apple runtime navigation.
Existing Cortex/model tests do not validate the new views.

The Apple follow-up needs Xcode 26 or newer for iOS 26 APIs, unsigned simulator
builds and actual captures at iPhone and iPad sizes. Verify iOS 17 native
fallback, iOS 26 glass, light/dark, accessibility text sizes, Reduce Motion,
Reduce Transparency, compact iPad multitasking, edge back, and sheet dismissal.
Screenshots show appearance at the captured configuration; they do not prove
auth, real API correction, offline content cache, or production progression.

An automated UI flow would need a UI-test target/scheme not currently provided
by this slice. No project wiring is added without coordination.

## Implemented entry and capture journey

Launch shows `Certigo` with `Découvrir la démo`. Opening this full-screen demo
does not instantiate NativeModel or touch the developer vault. The explicit
`Ouvrir le connecteur API de test` action alone presents the developer model.

Capture the empty objective, then Explorer > Cloud découverte > Choisir cet
objectif > Objectif. Capture the violet objective plane and resume action,
open the exercise, select an option, and record the fictive answer. Capture
pending before using `Simuler l'explication fictive`. That explicit action
shows a static explanation for the invented scenario, independent of the
selected option; it never grades the answer.

Return to Suivi to reopen it; close and reopen the demo to verify local resume.
The selected tab and the active objective/catalog route are restored with the
synthetic answer phase; invalid route/state combinations are rejected. This is
demo-only navigation and does not restore or persist any live answer. Options >
Scénarios exposes catalog loading/empty/error and simulated offline. Offline
keeps the answer pending and offers one explicit action to leave that scenario.
The snapshot stores flow and navigation together under the demo-only
`certigo.native-design-demo.v1` key; older flow-only snapshots still restore to
the objective tab. Reset requires a confirmation and clears only this demo key.

Selection is marked with both visual emphasis and the native selected
accessibility trait. Pending is explicitly not confirmed; the reviewed demo
state is labeled as an invented explanation with no verdict. No synthetic
state is connected to the development API connector.

## Review provenance

The source-only finishing review found stale approval wording, corrected here
and in PRODUCT.md. It found no high-confidence code/truth defect in that pass.
This substitutes only for source review: no screenshot fidelity, material,
contrast-at-render, or Apple type-check verdict has been obtained.
