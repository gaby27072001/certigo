# Native Apple model boundary

For the delivery sequence, Mac-versus-portable validation gates, accessibility
acceptance and conditional Apple integrations, see [the delivery plan](APPLE_DELIVERY_PLAN.md).

## Imported foundations

`apps/apple/CertigoKit` provides portable Swift domain contracts, Cortex predictions,
HTTPS transport, verified public-release readers, an owner/API-scoped submission
outbox and runtime content storage. The staged package declares iOS 17 and macOS 14;
these declarations are not Apple build or device evidence.

`apps/apple/CertigoNative` includes a SwiftUI development UI and a main-only
Xcode project alongside the model. Its unsigned development bundle is
`com.certigo.native.dev`, not the installed Flutter identity. No NoAuth test
target, protection probe or private probe tool is included. The project now
declares a source-only Associated Domains entitlement for
`applinks:www.certigo-app.com`; it is not enabled in the Apple portal, signed,
or associated by the production AASA. Its App ID prefix is not inferred.
Importing the project does not establish that it loads, builds, links, embeds
frameworks or runs with an Apple SDK. It does not replace Flutter or an installed
app.

The editorial pilot accepts validated lesson links at
`https://www.certigo-app.com/learn/responsible-ai-assistants/{lessonId}/`.
The route is retained only in memory and requires explicit user actions to
continue and open the lesson. Receiving a link does not authenticate or write
history; after the authenticated lesson view is displayed, the existing V1
access operation records the consultation. Marking the lesson read remains
explicit. The public fallback is generated from the same editorial fixture.
The static site builder emits the AASA for `FFQPC7NC68.com.certigo.mobileapp` only when
`APPLE_UNIVERSAL_LINKS_COMPATIBLE_BUILD_VERIFIED=true` is explicitly supplied
after that production bundle has a compatible, verified route implementation.
The current Flutter production target does not yet have this native pilot route,
so the gate must remain closed. No deployment, portal capability change, App ID
creation, signing or profile operation is part of this source change.

The UI source uses SDK 26 glass APIs with availability fallbacks to iOS 17.
Actual Apple validation needs Xcode/SDK 26 or newer and a Swift 6.2-compatible
toolchain. Linux Foundation demo/navigation checks and syntax parsing do not
typecheck or render the SwiftUI branch.

## Session and correction authority

The `@MainActor` model receives its client, credential vault and optional
authentication provider through injection. Its generation checks prevent a late
response from publishing into another session. Ownership comes from authenticated
`/me`, not from an entered owner ID or decoded JWT claims. Tests use synthetic
transports and identities; this layer does not initiate a real sign-in.

Browsing a track does not select it as an active goal. Explicit goal selection
uses the server-authoritative profile and an expected previous goal. An uncertain
response retains the original decision for retry; a conflict reloads the profile
rather than silently overwriting a concurrent choice.

The outbox remains authoritative for persisted attempts, owner/API scope,
`clientAttemptId`, original answers and release pin. Pending correction has no
local verdict. Authorized server feedback can include explanations and corrected
answer IDs; this does not permit shipping a private answer-key bank.

`SubmissionStore` uses Foundation path-based access, an actor-local cache and
atomic file replacement. It does **not** inherit `RuntimeDisk` cross-process
locking, symlink/hard-link hardening or power-loss guarantees. Runtime activation
process-death tests must not be presented as outbox durability evidence.

## Inactive resume-state contract

`NativeResumeState` is a bounded, closed schema-2 navigation value. It is not wired
to UI persistence or an automatic restore lifecycle in this layer. A submitting
marker is not evidence that the outbox committed an attempt or received a server
ACK. Reconciliation checks owner, API scope, lesson, attempt and original manifest
pin against the existing outbox. Unknown fields, unsupported schemas, ambiguous
attempts and mismatched identities fail closed without fabricating a new attempt.

## Opt-in development authentication and storage adapters

`CIAMConfiguration` validates supplied public metadata: authority versus issuer,
tenant/audience identity, protected API scope, HTTPS URL, exact registered callback
and scheme collision. Validation does not establish registration, consent, grants,
SDK initialization, token issuance or a working native login. The failure
classifier exposes categories instead of provider diagnostic strings.

The project references the official MSAL package at exactly 2.16.0
(`8dfe5bf41fe10e6d2afed62a72c4232adbef20f4`). Its workspace lock contains
only that dependency and the unchanged Crypto/ASN.1 pins. No SDK binary is
downloaded or resolved by this layer's Linux checks; its upstream checksum is
declared, not independently verified here. Preserve the upstream Microsoft MIT
notice when distributing MSAL.

The developer connector defaults to manual test-token sign-in. In Debug, a valid
local opt-in constructs `MSALAuthenticationProvider`, injects it into `NativeModel`
and routes callbacks through `.onOpenURL`. Invalid or incomplete opt-in
configuration fails closed with a setup error instead of falling back to manual
sign-in; Release rejects the opt-in. There is no automatic account restore on
startup. See [local CIAM development](../apps/apple/CIAM_LOCAL_DEVELOPMENT.md)
for the unshared Xcode scheme configuration and its limits.
`CIAMDevelopmentCandidate` records dated public metadata, not active registration
or endpoint health. The plist's callback scheme is only a declaration, not
permission to sign in or modify cloud registrations. This source wiring does not
prove an Apple build, provider initialization on Apple or live authentication.

`CredentialVault.swift` contains an Apple Security implementation using
`WhenUnlockedThisDeviceOnly`. It is not compiled or exercised by the Linux model
harness. Real Keychain lifecycle, SDK cache ownership, callback handling,
PKCE/nonce/state and interactive authentication require separate Apple/provider
integration evidence. No credentials belong in resources, defaults or logs.

## Non-certifying editorial pilot

The Learn sidebar includes the original French `responsible-ai-assistants` pilot
as a separate reading path, not as a certification track. The backend embeds the
exact source bytes from `gaby27072001/certigo-content` commit
`c8b13a86fa1cc5917bbfd795f5404727ea732505`; its authenticated content response
is digest-checked by the native client before decoding. The UI preserves the
source's `draft` status, French text, estimated durations, review date, source
links and stated limitations.

The new [editorial-pilot API contract](contracts/editorial-pilot/v1/README.md)
stores only owner-scoped last access and a voluntary, explicit “mark as read”
declaration in the existing `progress` container. Records are keyed by the
exact content digest, excluded from mastery queries, and removed by the existing
account-deletion partition cleanup. No free-text answer is collected or
persisted. Opening a lesson does not mark it read; neither the marker nor the
practice prompt is a score, mastery claim, readiness value, XP, reward or
certification. A new digest starts with no read marker while prior-version
records remain separate.

The native API transport and backend behavior tests use synthetic tokens,
identities and responses. They do not perform CIAM sign-in, create test accounts
or call a live `/me` endpoint. Linux Swift validation covers Foundation code
only; it does not typecheck or render the SwiftUI screen on Apple platforms or
prove a staging deployment.

## Local validation and its limits

### Optional lesson reading

The connected lesson UI source prepares explicit lesson reading using
`AVSpeechSynthesizer`; its Apple compilation and runtime acceptance are separate.
It selects the loaded lesson title, then the titles and bodies of hook, concept,
example and recap blocks in order. Code/check/unknown blocks, questions, answers
and corrections are excluded. Apple Foundation's `AttributedString(markdown:)`
extracts body text with inline syntax and preserved whitespace, matching the
existing `Text(.init(body))` presentation rather than introducing a new full-block
Markdown interpretation. Formatting and link destinations are not spoken; link
labels and paragraph breaks remain. Literal titles are not interpreted as Markdown.
Parser errors abort preparation of the entire reading and produce a visible error;
there is no silent paragraph skip or raw-Markdown fallback. CommonMark accepts many
unmatched delimiters as literal text, so these are not necessarily parser errors.

The French editorial pilot uses the same controls and speech controller. Its
allowlist is the displayed lesson title, objective, hook, key ideas, worked-example
situation/numbered steps/decision, and recap, in screen order. These contract
fields are plain text in the UI and are passed through without Markdown
interpretation. Practice prompts, success criteria, feedback, sources, progress
metadata and history are excluded; reading does not mark a lesson as read.

There is no preselected voice or automatic playback. The user chooses a voice
from the system's available voices; that choice is not a claim about the content's
language. Voice and speed are in-memory only. No voice download, microphone,
permission, audio-session category, background audio or account setting is added.
Pause, resume and stop are explicit controls; speed changes apply to the next
reading. Reading stops on view disappearance, lesson/text or owner change, and
when the scene becomes inactive. When VoiceOver is active, optional speech stays
stopped and the UI explains that VoiceOver can read the accessible content.
Enabling VoiceOver also stops any current optional reading.

Portable Foundation checks cover block selection, title/body ordering, editorial
allowlist and ordering, paragraph boundaries, empty inputs, original text and
propagation of a renderer failure.
The injected identity/failing renderers in those tests are not Markdown conversion
evidence. Darwin-conditional checks in `DemoTests/NativeDemoFlowTests.swift` exercise
the real Apple Markdown conversion and link-label/paragraph behavior, but must be
executed on Apple. Neither harness exercises the synthesizer or lifecycle hooks.
Before Apple acceptance, compile with the documented SDK and verify voice
availability, completion/cancellation callbacks, pause/resume, unavailable-voice
errors, VoiceOver coexistence, scene/tab/lesson/account changes and dismissal.
Also check the controls at accessibility text sizes on iPhone and iPad.

### Existing portable checks

Use an existing Swift 6.2-compatible toolchain. The package lock pins
`swift-crypto` 5.0.1 and `swift-asn1` 1.7.3; do not upgrade them as a validation
side effect.

```bash
swift test --package-path apps/apple/CertigoKit --scratch-path <scratch> \
  --force-resolved-versions --jobs 4 -Xswiftc -warnings-as-errors
bash tools/test_apple_model.sh <scratch>
swift build --package-path apps/apple/CertigoKit --scratch-path <scratch> \
  --force-resolved-versions --jobs 4 -c release -Xswiftc -warnings-as-errors
```

The Linux harness compiles the actual model with strict concurrency and
warnings-as-errors, a memory vault, synthetic provider/HTTP responses and a
throw-only stand-in for the default Security vault. It checks coordination,
journeys, stale responses, uncertain goal retry and resume-state rejection. It
also rejects a retained track selection if silent authentication refresh changes
the account: the old selection must not send a path request as the new owner,
and the model surfaces a stale-session error instead. It does not compile
SwiftUI, Security, UIKit or MSAL, or prove Apple Keychain/file
protection, a runtime content graph, provider activation or live service behavior.
The package's three iOS-only protection tests require an Apple SDK test run.
The main app scheme has no testables; this is not evidence of an Apple test pass.
