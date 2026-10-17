# First native practice slice

## Approved product scope

Choose an objective, answer a question, understand its correction, resume the
work. iPhone and iPad. Native SwiftUI affordances, Prism identity, readable
opaque exercises. A question bank is not a promise of guided courses.

The owner selected A through the coordinating chat: objective first, quick
resume, catalog and follow-up tabs. The decision schematic is a session
artifact, not an Apple render.

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
Catalog and follow-up also retain a bounded reading width on iPad.

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

Launch shows `Certigo` with `Découvrir la démo`. Opening this full-screen demo
does not instantiate NativeModel or touch the developer vault. The explicit
`Ouvrir le connecteur API de test` action alone presents the developer model.

Capture the empty objective, then Explorer > Cloud découverte > Choisir cet
objectif > Objectif. Capture the violet objective plane and resume action,
open "Decouvrir la situation", read the preparation, then use "Passer a la
question", select an option, and record the fictive answer. Capture
pending before using `Simuler l'explication fictive`. That explicit action
shows a static explanation for the invented scenario, independent of the
selected option; it never grades the answer.

Return to Suivi to reopen it; close and reopen the demo to verify local resume.
Follow-up explicitly opens the exercise on its owning Objective navigation
stack instead of pushing a value without a destination in the Follow-up stack.
It preserves the selected option and pending/reviewed phase. Repeat the flow
with Cloud exploitation: the system-administration situation and explanation
must differ, without any score or right/wrong verdict.
The selected tab and the active objective/catalog route are restored with the
synthetic answer phase; invalid route/state combinations are rejected. This is
demo-only navigation and does not restore or persist any live answer. Options >
Scénarios exposes catalog loading/empty/error and simulated offline. Offline
keeps the answer pending and offers one explicit action to leave that scenario.
The snapshot stores flow and navigation together under the demo-only
`certigo.native-design-demo.v1` key; older flow-only snapshots still restore to
the objective tab. Existing version-one snapshots remain readable; the optional
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
