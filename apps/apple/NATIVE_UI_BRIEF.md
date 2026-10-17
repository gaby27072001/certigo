# First native practice slice

## Approved product scope

Choose an objective, answer a question, understand its correction, resume the
work. iPhone and iPad. Native SwiftUI affordances, Prism identity, readable
opaque exercises. A question bank is not a promise of guided courses.

The owner selected objective-first composition A, then confirmed four English
destinations on 2026-10-17: Learn / Coach / Social / Profile. This supersedes
the former Objective / Explorer / Follow-up tab arrangement while preserving
the learning flow. The decision schematic is not an Apple render.

## Four-destination implementation

Learn owns My Learning / Explore through a native local menu picker whose
labels remain readable at large text sizes. It retains separate objective and
catalog paths. With no saved goal the preview starts in Explore; a restored
eligible demo route takes precedence. Profile provides a private preview
summary, a pushed Progress & history screen and pushed Settings. History's
resume action returns to Learn / My Learning with the same selection and phase.
Viewing Profile does not choose another goal.

Coach is explicitly not connected: no composer, generated messages, history or
memory controls pretend to work. Social's Friends / Teams selector shows the
same honest unavailable boundary without fictional people, invites or metrics.
Both can return to Learn without changing its current section or activity.
These are internal preview shells, not delivered Coach or Social services.
No new endpoints, permissions, account state or saved preferences are created.

All authored interface labels are English, including the opt-in entry and test
connector. The actual learning fixture text remains French with a visible
language note; API-provided content, errors and resource titles retain their
source language. Interface translation does not publish translated courses.

Demo storage retains the version-one key, schema, goal raw values and existing
route identifiers. Legacy `objective` and `catalog` map to Learn / My Learning
and Learn / Explore; `followUp` maps to Profile. A new optional `learnSection`
field preserves the last Learn section while visiting other destinations.
Missing fields infer the legacy section, not a discarded answer. All four
destinations round trip with both saved learning paths; invalid section/tab
combinations are rejected. This demo migration is separate from NativeModel's
inactive live resume contract and never decodes or writes that bookmark.

## Decision-workshop extension

Visitor mode: **Operate**. The existing Prism world and objective-first layout
remain intact. The 2026-10-17 implementation extends them with the research
recommendation "l'atelier des decisions" as a reviewable proposal, not a final
art-direction approval. A professional preparing a certification should find
one next action and understand the boundary between a choice and a result.

The requested home/course/lesson/result sequence is expressed within the actual
demo capability: objective, invented preparation brief, question, pending
answer, and explicitly fictive explanation. It does not add a canonical course
catalog or integrate the public question bank.

Each existing objective now has its own situation, constraint, explanation and
responsibility breakdown. Discovery delegates the operating system in a PaaS
example; operations retains it in an IaaS example. Neither scenario grades a
selection. The explanation remains the same for every option within that
scenario, with the synthetic-data warning retained.

The moment to review is the handoff from a technical decision to its reason:
constraint, explanation, responsibility by layer, then takeaway. System text
styles, an adaptive horizontal/vertical stage indicator, opaque reading
surfaces, native transitions and the existing glass fallback carry it.
No new motion, dependencies, auth wiring or tracking is introduced.
Catalog and history also retain a bounded reading width on iPad.

## Boundaries

### Authenticated test-connector integration

The explicit active-goal UI is a separate, minimal integration behind the
existing test connector. The path detail shows its relation to the profile's
server-confirmed active goal and an explicit Choose as active goal action.
Browsing still calls only loadPath. During saving, the action is disabled and
the status stays pending; old confirmed context remains visible.
The model's existing alert reports 409 reconciliation and uncertain responses,
with no view-level retry or optimistic profile mutation.

Pure presentation checks cover browsing, saving, confirmation, errors and
duplicate-action prevention. Foundation model/package tests cover the actual
request and reconciliation. Neither is a SwiftUI runtime test. This integration
does not wire the inactive live bookmark or claim unsent-draft restoration.
The synthetic navigation remains separate from real account state.

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
| Preparation | Situation and mission | Open the question | Invented brief, not a canonical lesson |
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

Launch shows `Certigo` with `Explore the demo`. Opening this full-screen demo
does not instantiate NativeModel or touch the developer vault. The explicit
`Open the test API connector` action alone presents the developer model.

Use Learn > Explore > Cloud discovery
> Choose this goal > My Learning. Capture the violet objective plane and resume
action, open "Explore the situation", read the French preparation, then use
"Open the question", select an option, and save the demo answer. Capture
pending before using `Simulate the fictional explanation`. That explicit action
shows a static explanation for the invented scenario, independent of the
selected option; it never grades the answer.

Return to Profile > Progress & history to reopen it; close and reopen the demo
to verify local resume. History explicitly opens the exercise on its owning
Learn / My Learning navigation stack.
It preserves the selected option and pending/reviewed phase. Repeat the flow
with Cloud operations: the system-administration situation and explanation
must differ, without any score or right/wrong verdict.
The selected tab and the active objective/catalog route are restored with the
synthetic answer phase; invalid route/state combinations are rejected. This is
demo-only navigation and does not restore or persist any live answer. Demo options >
Demo settings exposes catalog loading/empty/error and simulated offline. Offline
keeps the answer pending and offers one explicit action to leave that scenario.
The snapshot stores flow and navigation together under the demo-only
`certigo.native-design-demo.v1` key; older flow-only snapshots still restore to
Learn / My Learning when a goal exists, otherwise Explore. Existing version-one
snapshots remain readable; the optional
preparation route round trips in the same demo-only snapshot. Reset requires a
confirmation and clears only this demo key.

Selection is marked with both visual emphasis and the native selected
accessibility trait. Pending is explicitly not confirmed; the reviewed demo
state is labeled as an invented explanation with no verdict. No synthetic
state is connected to the development API connector.

## Review provenance

Historical Apple evidence is bounded in the README's **Observed preview
evidence** section and does not validate this newer workshop extension.
This extension was reviewed and checked at source level on Windows/Linux only.
Native screenshot fidelity, contrast-at-render, SwiftUI type checking, large
Dynamic Type, VoiceOver, iPad layout and interactive navigation remain Apple
follow-up gates, not findings that a source review can close. Review the
proposal before adopting its visual direction.

For the four-tab extension, additionally verify switching through Coach and
Social and back preserves both Learn detail paths, the unavailable labels are
readable, Profile details keep native back behavior, and the English interface
does not obscure the visible French-content provenance. Source tests do not
prove SwiftUI navigation, material rendering or VoiceOver output.
