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

## Launch profiling

The shared `CertigoNative` scheme's Profile action runs the app target in Release.
Select the intended device and use Product > Profile; no executable selection
should be needed in a fresh checkout. Keep signing and local scheme edits intact
when updating an existing Mac checkout.

Distinguish build duration, debugger overhead, simulator loader time and time to
first rendered frame. Compare the same Release build outside the debugger before
attributing startup delays to app code. A trace stopped by the user may contain
an unfinished loader interval; its total duration is not a launch measurement.
If a lifecycle export contains no rows, it does not establish time to first
frame. Do not sum nested loader intervals or overlapping time-profile tables.
A simulator result does not establish physical-device launch performance.

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

After a confirmed correction, initial submission and explicit retry reload the
authenticated profile from `/me`; displayed XP is the returned server total,
never the previous total plus a locally applied reward. Pending correction does
not refresh or award XP. If profile refresh fails, the existing error feedback
is shown and the last confirmed profile remains unchanged, while the durable
quiz correction stays available. Retrying an already corrected entry can refresh
the profile without submitting or crediting the quiz again. Session-generation
and owner checks prevent a late profile from replacing a signed-out or different
account.

The outbox remains authoritative for persisted attempts, owner/API scope,
`clientAttemptId`, original answers and release pin. Pending correction has no
local verdict. Authorized server feedback can include explanations and corrected
answer IDs; this does not permit shipping a private answer-key bank.

A cancelled submission or retry propagates the cancellation error and leaves its
outbox entry pending: cancellation is not proof that the server rejected or did
not receive the request. After reopening, an explicit retry sends the same
`clientAttemptId` and original payload for server reconciliation. Cancellation
does not become an automatic retry or a local correction.

`SubmissionStore` uses Foundation path-based access, an actor-local cache and
atomic file replacement. It does **not** inherit `RuntimeDisk` cross-process
locking, symlink/hard-link hardening or power-loss guarantees. Runtime activation
process-death tests must not be presented as outbox durability evidence.

## Activity restoration

The connected native model saves one active activity in
`Application Support/CertigoNative/activity-v1.json`, separately from the submission
outbox. The bounded, closed schema-1 snapshot contains schema-2 `NativeResumeState`
navigation, the opened track, and an optional unsent draft: selected option IDs,
completed answer latencies, attempt UUID and start date. A digest of the exact
public lesson projection binds even unpinned lessons to their original content.
No token, private answer key or local grading result is stored there.

Selections and navigation changes replace the file atomically. Write failures are
visible; a failed pre-submission save prevents sending the request. Like the outbox,
this Foundation path-based store does not provide cross-process locking,
`RuntimeDisk` link hardening or power-loss guarantees. Unselected elapsed reading
time is not reconstructed after termination; already recorded latencies and the
original attempt start remain intact.

After a successful connection, restoration checks the authenticated `/me` owner
and normalized API scope, reloads the current catalog/path/lesson, and requires an
available track, an openable lesson, the original manifest and exact lesson digest
for a draft. Empty and partially answered lessons can reopen without submitting.
The UI restores the top-level tab and selected track/lesson, opening the activity
detail when appropriate. Browsing a path retains the active activity; reopening
prefers that activity's path over a different last-browsed track. Opening another
lesson explicitly replaces the single active draft. Demo navigation, editorial
reading position, social subsection, speech playback and scroll offsets are not
part of this connected activity snapshot.

A submitting marker is not evidence that the outbox committed an attempt or
received a server ACK. Reconciliation checks owner, API scope, lesson, attempt and
original manifest pin against the outbox; pending, corrected and failed attempts
remain non-editable and are never automatically resent. An unresolved in-flight
marker is rejected rather than converted into a fresh draft or a success.
Unknown fields, unsupported schemas, incompatible selections, missing/locked
content and changed owner/scope/content clear the activity with a visible message,
without changing submitted responses. Transient verification failures preserve
the file without displaying it; reconnecting retries verification. Explicit
sign-out removes the activity, reports removal failure and blocks automatic
connection restoration. Generation guards discard late restoration responses
after sign-out or account replacement.

## Development connector support and recovery

Retry failures reconcile the displayed saved-answer queue with the durable
outbox before the operation finishes. A terminal rejection clears the current
activity's pending indicator, not its saved answers, and does not enable another
submission of that attempt. Reopening must show the same durable status.

| Observed state | Recovery and evidence boundary |
| --- | --- |
| Pending correction, offline, timeout, throttling or server outage | Keep the saved attempt. Retry correction explicitly after connectivity/service recovery; the original attempt ID, answers and release pin must not change. No local verdict is available. |
| Cancelled request | Acceptance is unknown. Keep the pending attempt; explicit retry reconciles it with the server. Cancellation does not justify creating another attempt. |
| HTTP 401 | The connection is not authorized; reconnect the same authorized test account. Sign-out clears the activity snapshot, not the durable submission outbox. Do not paste a token into a support report. |
| Terminal rejection or incompatible response/content | Review the failure before another attempt. The existing failed row is not retryable; do not edit its archive/status, remove its pin or relabel it pending to force a resend. |
| Confirmed correction, failed profile refresh | The correction remains confirmed; profile XP can still be the previous server total. Rechecking the corrected saved entry refreshes the profile without another quiz POST or local reward credit. |
| Unreadable/full storage or failed activity save | Saving is not confirmed. Preserve the existing files; do not reset the outbox as troubleshooting. Resolve device storage or obtain a scoped recovery decision. |
| Restoration cannot verify account/content | Do not submit automatically or display an unverified draft. A transient failure keeps the snapshot for reconnect; incompatible activity is cleared explicitly without changing saved submissions. |

For support, record only the app version/build, operation name (connect, load,
submit, retry, refresh or restore), approximate time, displayed category/HTTP
status and whether the row is pending, failed or corrected. Do not attach the
local Xcode scheme, credentials, API URL, request/response body, answer selections,
account identifiers or raw outbox/activity files. No automatic support export,
analytics pipeline or production observability is enabled by this client.
`NativeModel` uses fixed error messages; API errors carry status/numeric transport
codes rather than server response text, and the MSAL adapter disables SDK logging
and classifies errors instead of displaying SDK diagnostics.

An API `x-correlation-id` is generated per request, but the native client does not
retain or expose it for support. Do not claim end-to-end request tracing from
these messages alone. The connected model does not currently wire the runtime
content store: reopening a draft needs profile/catalogue and path/lesson
verification over the network. The outbox is not full offline learning or a
cross-device history. Keep release/manifest identity with each saved submission;
a newer catalogue or a separate guided pilot is not evidence that an old
attempt can be regraded against different content. The synthetic demonstration
does not prove any connected recovery or published curriculum.

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
sign-in; Release rejects the opt-in. Startup restoration uses only an existing
local connection or silent acquisition; it never starts interactive sign-in.
See [local CIAM development](../apps/apple/CIAM_LOCAL_DEVELOPMENT.md)
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

## Native learning services

See [CertigoKit learning contracts](../apps/apple/CertigoKit/LEARNING_SERVICES.md)
for the existing backend routes and evidence limits. NativeModel coordinates the
Coach, recommendations, assessment, reward boards and notification preferences
without changing authentication, scoring or release/signing configuration.

Coach requests require a confirmed result and its original submitted selection
and manifest pin. Requests are explicit: the tutor POST changes server learner
signals and must never be automatically replayed. Duplicate in-flight requests
are blocked; responses/errors are discarded after owner, connection, lesson,
attempt or deletion context changes. Changing tabs does not submit a question.
The returned source distinguishes grounded fallback from AI output. There is no
conversation memory or alternate-style request parameter.

Smart Review combines server history with locally stored server acknowledgements
for the same owner/API/track. Pending answers never become recommendation scores.
Study Plan injects a hashed owner/API/track preferences key instead of the Kit's
device-wide default; invalid stored data is a visible failure. Account deletion
removes only that owner's matching preference prefix and assessment snapshot.
Signing out preserves protected drafts for explicit same-owner recovery.

Assessment generation and submission use the real server APIs. The protected
owner/API-scoped JSON snapshot is bounded to 1 MiB and stores the generated exam,
selections, start time and client attempt ID. Before POST, it also stores the
immutable request. Restart and explicit retry reuse that request; they do not
mint another attempt after an ambiguous response. Draft/result identity and
response shape are validated on restoration. Other item types fail closed,
and an empty generated exam is not submittable. Discard requires a native
confirmation and removes only the local snapshot, not a remote result.

Server notification preferences and plan are distinct from OS push permissions.
Saving is explicit and owner-guarded; canonical server settings replace the form
and invalidate the older plan. No APNs registration, system permission request,
notification delivery or background scheduling is implemented here.

The path contract supplies domain scores, not full domain coverage/mastery.
Consequently no mastered-domain count, remaining exam-preparation prediction or
probabilistic "you're ready" promise is synthesized. Only loaded activity minutes,
server readiness/recommendations and confirmed simulation outcomes are presented.
Apple SDK compilation and device behavior still require the acceptance below.

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

Audio controls, playback status and safe errors resolve through the selected
eight-language interface catalog; voice names and spoken educational content keep
their source text. Changing interface language updates stored error keys without
starting playback. Model, deletion and configuration errors follow the same
locale-reactive presentation rule, with typed HTTP/configuration templates rather
than raw SDK errors or English sentence concatenation.

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

### Native distribution identity preparation

The separate **CertigoNative Distribution** scheme archives the **Distribution**
configuration for the existing App Store app identity `com.certigo.mobileapp`.
Debug and Release remain `com.certigo.native.dev`; the development scheme, local
CIAM callback and opt-in stay unchanged. Distribution has no development callback,
no `DEBUG` condition, and uses `-O`. This is source configuration preparation, not
a signed archive, processed TestFlight build or authorization to upload.

Before a future archive, the owner must confirm the marketing version and unused,
increasing build number in App Store Connect. Pass both as explicit Xcode build
settings: `CERTIGO_DISTRIBUTION_VERSION` (numeric `major.minor.patch`, each
component up to four digits) and `CERTIGO_DISTRIBUTION_BUILD` (integer 1-9999).
There are no default or reserved numbers. `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` must resolve to these values without separate overrides.
The archive pre-action validates them before the archive build; an always-running
target phase also fails closed for direct Distribution builds. Local validation
checks syntax and consistency only, not availability or monotonicity on Apple.
Missing values are intentional errors, not permission to reuse development `0.1.0 (1)`.

`CODE_SIGNING_ALLOWED=NO` remains explicit. No team, identity, profile or
entitlement is added. Signing, archive validation and upload require a separate
authorized Apple step; do not enable automatic provisioning to bypass this gate.
The current first-party manifest and pinned MSAL dependency are unchanged;
inspect the final aggregated archive privacy report before distribution.

Debug and ordinary Release builds keep the current fictional demonstration.
The manual test-token connector is compiled only into Debug, and the local CIAM
opt-in remains development-only. Only the explicit `Distribution` Xcode
configuration defines `CERTIGO_PRODUCTION_DISTRIBUTION` and routes to the
Microsoft production sign-in entry for bundle `com.certigo.mobileapp`. It never
offers the manual-token connector as a fallback. Missing or invalid
Distribution metadata blocks sign-in explicitly. This code path is not yet a
configured or verified production identity.

The Distribution Info.plist declares the local callback
`msauth.com.certigo.mobileapp://auth` and requires these public Xcode build
settings to be supplied from an owner-verified production configuration:
`CERTIGO_PRODUCTION_CIAM_CLIENT_ID`, `CERTIGO_PRODUCTION_CIAM_TENANT_ID`,
`CERTIGO_PRODUCTION_CIAM_AUTHORITY`, `CERTIGO_PRODUCTION_CIAM_ISSUER`,
`CERTIGO_PRODUCTION_CIAM_AUTHORITY_KIND`, `CERTIGO_PRODUCTION_CIAM_API_BASE_URL`,
`CERTIGO_PRODUCTION_CIAM_API_SCOPE` and
`CERTIGO_PRODUCTION_CIAM_API_AUDIENCE`. They have no development or staging
defaults. An unresolved Xcode substitution, wrong bundle, invalid authority,
scope, audience, endpoint or local callback declaration fails closed before
provider construction. The plist declaration does not prove that the callback
is registered in Entra, that the app identity and API permission are correct,
or that consent/backend audience validation is configured. Those require
separate owner verification and Apple/provider validation; no cloud registration
or permission was changed for this source preparation.

The provider's account selection is held in memory. After app relaunch, the
user must explicitly sign in again; silent account restoration is not claimed.
The test connector's device-only vault remains unchanged, with no migration or
access to the legacy Flutter app's credential cache. Read-only quiz history and
account deletion use the separate workflows below;
its source implementation does not establish live service availability.

### Downloaded public question packs

In an authenticated session, Learn offers an explicit download confirmation.
The current download granularity is the **whole public release**, not one
certification. The dialogue discloses that scope before network access. It
reuses the bounded manifest/file downloader, digest and public-resource
validators, and atomic active/previous snapshot activation. No private
solution, answer key, explanation or correction is part of the downloaded pack.
The current corpus is bank-first: locally projected practice sessions are
question packs, not authored courses or certification-readiness evidence.

Downloaded practice is resolved locally from the verified track/domain/question
graph (or authored unit/lesson blocks when present). Legacy question and concept
aliases, v3 option IDs and question-bank session IDs match the existing backend
projection. Cached reading never invents progression, readiness, correction or
XP; those remain server-confirmed. Unknown resources, unsupported question types,
incomplete graphs and damaged bytes fail closed with recovery feedback.

Opening cached practice pins its exact manifest for the current owner and API
scope before saving a local draft. Draft restoration uses that snapshot, not
the newest release, and checks the original lesson digest and attempt identity.
It does not require a path/lesson HTTP refetch when the pinned pack is present.
Learn also has an explicit local restoration action. If a pack is unavailable,
this action preserves the saved activity and reports the failure rather than
silently substituting another release. Normal connected restoration may still
validate an online-only activity against its original digest. Downloaded content
and drafts are not exposed to another signed-in owner or another API scope.

Selecting answers, downloading, opening and restoring never submit implicitly.
Submit still writes the existing durable outbox before requesting correction;
a network failure leaves it pending. Reconnect does not automatically replay it:
the learner explicitly retries the same attempt and bytes. Only a server ACK
exposes feedback and rewards, followed by the existing authoritative profile
refresh. Drafts stay device-local and are not multi-device history.
The activity directory and atomically written activity file explicitly use the
same iOS `completeUntilFirstUserAuthentication` policy as the outbox.

This is **not offline identity restoration**: a cold app launch still needs the
existing verified sign-in/profile and catalog bootstrap. Cached learning works
without path/lesson HTTP in an already-established account session, including
restoring its local draft. No cached token/profile is treated as a newly
authenticated identity. Apple acceptance must separately verify compilation of
SwiftUI/UIKit/MSAL, effective file protection, airplane-mode reading and explicit
queue/retry behavior on iPhone/iPad, owner switching, navigation and VoiceOver.
Linux model/package tests do not establish those Apple runtime properties.

### Account deletion and recovery

Connected Profile > Settings has a separate Delete account destination, not a
replacement for Disconnect. The first Form explains irreversible deletion and
residual retention. Continue only verifies identity; the subsequent destructive
system alert is the only action that submits a first deletion request. The demo
and manual DEV connector cannot perform recent Microsoft authentication and do
not offer executable deletion. Cancel, backgrounding or a different returned
account discards the memory-only proof without submitting or removing drafts.

The dedicated MSAL operation uses `.login`, `max_age=0`, an ephemeral
authentication session, and the captured SDK account. It checks that account
before accepting a result and requires a nonempty ID token. Local proof checks
reject stale/missing `auth_time`, wrong native audience and expired credentials;
they do not replace server signature/issuer/subject/freshness validation. The
POST keeps the original session bearer and supplies the ID token only in
`X-Certigo-Reauthentication`. It never persists proof tokens or displays raw
SDK errors, response bodies or endpoint URLs.

GET and bodyless POST target exactly `/api/account/deletion` on a configured
`/api` base; a versioned base fails closed. `202/pending` freezes learning but
retains credentials, drafts, outbox and downloads. Server step counts are
displayed as counts, not elapsed-time estimates. GET checks status only;
explicit Retry deletion advances unfinished steps after the server's bounded
retry delay. A lost POST response or a later 401 is unconfirmed, not completed.
There is no cancellation endpoint once the request has been recorded.

A bounded, atomically written protected receipt contains only local
owner/scope/SDK-account binding and workflow/cleanup state. Pending restart
obtains credentials for the same SDK account and uses deletion GET without
requiring `/me`, catalog or learning restoration; these can already return 423.
A first sign-in encountering `/me` 423 also enters deletion-only recovery.
If that device has no verified backend-owner binding, status is available but
local owner-scoped cleanup remains unconfirmed and requests support rather
than deriving an owner from email, JWT payload or the opaque SDK account ID.

Only validated server `completed` creates the durable cleanup receipt.
Generation invalidation and the outbox's suspended-scope barrier prevent late
enqueue/ACK/download writes. Cleanup removes this owner/scope's outbox records,
runtime references/pins/capsules and unshared blobs, matching activity, the
owned Certigo DEV vault entry and the exact saved MSAL account. Other owners,
API scopes and their shared public bytes remain. Local targets acknowledge
individually in the receipt: failure leaves learning closed and exposes Retry
local cleanup, including after restart, without repeating POST or reauth.
The completed surface remains visible until explicit acknowledgement.

**External gates remain:** production native identity/configuration, native
ID-token audience accepted by `ENTRA_REAUTH_AUDIENCE`, live `auth_time`,
and the existing backend deletion activation/Cosmos gate. No SDK dependency,
Graph grant, flag, app registration, cloud resource or signing setting is
changed by this source work. MSAL 2.16.0 public headers at the pinned revision
confirm `promptType`, `extraQueryParameters`, `idToken`, account enumeration
and scoped removal; they do not prove Apple compilation or forced reauth.
Apple acceptance must separately verify SwiftUI/UIKit/MSAL typechecking,
Keychain removal, pending restart and account selection, interrupted cleanup,
Dynamic Type/VoiceOver focus, and iPhone/iPad confirmation presentation with
sacrificial accounts. No live destructive request is part of portable tests.

### Confirmed quiz history across devices

Profile > Progress & history reads the paginated `/api/me/history` lesson-quiz
summary contract. It sends only `limit` (default 20, range 1...50) and an opaque,
bounded continuation cursor with the existing bearer/correlation headers.
The response is decoded into dedicated, closed summary/page DTOs, never
`QuizResult`. Unknown/private fields, invalid identifiers, score/count/reward
ranges, unsupported kinds, malformed manifests/cursors and inconsistent
duplicate summaries fail explicitly. The endpoint is `/api`, not `/api/v1`.
The client does not read or repair economy journals or infer confirmation from
stored attempt rows; the backend owns those confirmation semantics.

"Confirmed across your devices" uses server submission dates, recorded scores
and earned XP, not current names from a different content release. Refresh
starts a replacement traversal; Load more appears for any non-null cursor,
including an empty continuing page. Identical repeated summaries collapse by
client attempt identity (canonical UUIDs, opaque IDs otherwise unchanged).
Track, lesson, manifest when both known, and full local correction identity
must agree. Conflicts preserve the previous verified page and report an error,
not last-writer wins. A cursor that does not advance is rejected.

A matching server summary takes presentation precedence over pending/failed
local state without mutating the outbox, manufacturing correction details,
unpinning content or awarding XP. Pending attempts can explicitly retrieve
their full correction using the existing same-ID idempotent retry. A failed
local record is not silently re-enabled for submission by viewing a summary.
Local full server ACKs absent from the loaded pages stay visible as
"Confirmed on this device"; absence from partial pages does not imply deletion.
Unmatched pending/failed records and the current activity remain explicitly
device-local. Their dates are local activity starts, not fabricated server
submission times. Viewing history never uploads drafts or retries submissions.
Current progress stays a separately labeled last-loaded profile/path reading;
paginated rewards are never summed into XP balance or readiness.

History is held only in memory, with no new personal-data cache. Account/API
changes synchronously clear rows and cursors. Independent request generations
discard old refresh/load-more responses; double load-more is serialized.
Offline and HTTP errors retain verified rows with an explicit stale/unavailable
message. A fresh offline session does not claim empty remote history. A 401
requests explicit sign-in; a 423 freezes learning and enters the existing
deletion-status recovery without sending a deletion POST. Cancellation does not
erase previously verified rows.

Portable tests cover the wire allowlist/query, invalid fields, scoped merge,
pending/server precedence without outbox changes, local ACKs outside loaded
pages, tied/repeated/conflicting rows, empty continuing pages, cursor loops,
offline/401/423 errors and late account/refresh/load-more responses. This is
source integration against the backend contract, not evidence that the history
endpoint or its Cosmos query/index requirements are deployed. Apple acceptance
still requires SwiftUI typechecking/build, long identifiers/Dynamic Type,
VoiceOver, iPhone/iPad navigation, offline presentation and explicit retry.
Exam and editorial-pilot history remain outside this lesson-quiz summary.

The existing Flutter TestFlight build is not this native candidate. Do not claim
production login, live account deletion, validated accessibility, App Review
acceptance or a privacy label from this configuration alone.

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
journeys, stale responses, uncertain goal retry and resume-state rejection. Its
activity tests reopen fresh model/client/store instances against an actual
temporary snapshot file: empty/partial/full drafts, tab/path/lesson selection,
stable attempt/timing/answer identity, pending/corrected/failed outbox authority,
account/scope/content invalidation, transient failures, interrupted restoration,
storage failures and sign-out removal. These deterministic Foundation checks are
not an Apple process-kill/relaunch or SwiftUI navigation test. On Mac/iPhone,
separately verify selecting answers, closing/relaunching, re-opening the correct
detail/tab and submitting only after an explicit action. It
also rejects a retained track selection if silent authentication refresh changes
the account: the old selection must not send a path request as the new owner,
and the model surfaces a stale-session error instead. It does not compile
SwiftUI, Security, UIKit or MSAL, or prove Apple Keychain/file
protection, a runtime content graph, provider activation or live service behavior.
The package's three iOS-only protection tests require an Apple SDK test run.
The main app scheme has no testables; this is not evidence of an Apple test pass.
