# Native Apple client foundations

This development client lives alongside Flutter; it does not replace an installed
app, change an App Store record, alter Azure, or enable new server capabilities.
The initial deployment target is **iOS/iPadOS 17**. This is a development
assumption, not an approved decision to drop support on users' devices.

## Current boundary

`apps/apple/CertigoKit` contains Swift 6 package targets:

- `CertigoDomain`: the public API projection, raw quiz submissions, explicit
  malformed/unsupported content errors, and authoritative result models.
- `CertigoData`: HTTPS URLSession transport, existing REST routes, session
  generation isolation, and an atomic, owner/environment-scoped submission store.
- `CertigoCortex`: pure Swift, explicitly timed local learning predictions using
  the existing `1.0.0` algorithm contract. It is not connected to quiz correction
  in the development UI.

`apps/apple/CertigoNative` is an unsigned universal SwiftUI development target,
with an adaptive library, path and MCQ session. Its distinct bundle identifier is
`com.certigo.native.dev`. **Do not replace it with `com.certigo.mobileapp`** until
signature, account and local-data migration evidence has been reviewed.

The development connector accepts an API URL and an access token from a dedicated
test account. It derives ownership from authenticated `/me`, never from a user
field or an unvalidated JWT subject. The token is stored only in a
`WhenUnlockedThisDeviceOnly` Keychain item, not UserDefaults, logs, resources or the
submission archive. No API host, token, identity or staging availability is
assumed by the build. This connector is **not production login**: CIAM OIDC SDK,
PKCE/nonce/state validation, token refresh and interactive reauthentication are
separate, still required work. Do not use a real person's credentials.

## API contract and correction

The client consumes the existing API projection, **not** canonical authored
questions or a private answer-key package:

| Operation | Existing route |
| --- | --- |
| Authenticated owner | `GET /me` |
| Catalog | `GET /catalog/tracks` |
| Track progress | `GET /me/paths/{trackId}` |
| Public lesson | `GET /tracks/{trackId}/lessons/{lessonId}` |
| Server correction | `POST /quiz/{lessonId}/submit` |

Catalog requires the existing app `v2` and source `v1` markers. Lesson options
use **`label`**, not `text`. Unknown lesson blocks and exercise types fail as
unsupported; they are not silently rendered as MCQ. The first native capability
is `mcq`; it does not claim all Flutter exercise types are implemented.

Submission keys and wire fields are unchanged: `clientAttemptId`, `trackId`,
`startedAt`, `answers(itemId,itemType,selected,latencyMs)`, optional
`publicManifestId`. Owner and bearer credentials are never submission fields.
`x-content-manifest-id` is preserved for subsequent submission; a conflicting
body/header pin is rejected. This foundation does not yet implement runtime
manifest/package downloading, activation, cache eviction or content migration.

An attempt is saved atomically **before** its network request. Transient failures
return `pendingCorrection` without score, correctness, XP or readiness claims.
Retry uses the same payload, owner, environment and attempt ID. A persisted
server result is reused instead of posting again. Correct-answer IDs and
explanations in the post-correction response are permitted; a correct item may
have `correctAnswer: null`. The server may omit unknown requested item IDs;
the client never invents missing results. Nonretryable failures remain visible
with their original answers; malformed storage is retained and reported, not
overwritten with an empty successful queue.

Session generation is captured around suspension points. Logout/account change
cannot publish a previous account's response. An in-flight ACK is stored for
its original owner only. A queue from another account or API environment cannot
be replayed with the current credentials. The store is bounded and uses iOS file
protection; it is not claimed to be encrypted by SwiftData. This first
implementation deliberately uses an atomic versioned file for its small outbox.

## Run and validate

### Cortex evidence and limits

`CortexTests` reads the existing single source
`packages/cortex/test/golden/cortex_golden_vectors.json` directly from the checkout;
it does not regenerate or copy expectations. Scheduler float assertions use
`1e-9`, and fractional due dates retain the shared `1ms` tolerance. Time is passed
explicitly, using elapsed seconds rather than calendar days or device timezone.
State validation rejects nonfinite values and mixed-track computations.

Outside these shared vectors, the incumbent Dart and C# implementations already
differ. Swift preserves **authoritative C#** readiness midpoint rounding
(ties-to-even), the `max(1, conceptCount)` denominator and the `0.0001` total-weight
floor. Dart uses away-from-zero rounding and returns zero for an empty authored
domain. C# answer comparison ignores identifier case; Dart does not. Swift matches
the server for ASCII identifiers and explicitly rejects non-ASCII comparison
rather than pretending Unicode locale folding is .NET ordinal comparison.
Local boundary tests pin these differences; the algorithm version and existing
Dart/C# sources are unchanged. Passing the shared vectors is **not complete
three-language parity** for these uncovered cases.

The session planner has only a Dart twin, not a C# recommendation contract.
Swift follows its lane allocation, deduplication and due/new backfill. Equal sort
keys preserve input order deterministically; the shared vectors do not specify
ties. This is a local prediction, not a guarantee of server recommendation order.
The client never derives correction, rewards or readiness for a pending attempt,
and no private answer bank is bundled.

Run portable tests from the repository root:

```powershell
swift test --package-path apps\apple\CertigoKit
swift build --package-path apps\apple\CertigoKit -Xswiftc -warnings-as-errors
swift format lint --strict --recursive apps\apple\CertigoKit apps\apple\CertigoNative\Sources
```

On a Mac with a supported stable Xcode toolchain, open the shared
`CertigoNative` scheme or run:

```sh
xcodebuild -version
swift test --package-path apps/apple/CertigoKit
xcodebuild \
  -project apps/apple/CertigoNative/CertigoNative.xcodeproj \
  -scheme CertigoNative \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Paths in the Mac commands use that platform's separators. Windows cannot build
SwiftUI, Apple SDKs or run an iOS simulator. Linux/WSL Swift package tests are
useful portable evidence, **not an Xcode or device validation result**. A
repository-governed unsigned Mac CI workflow belongs to the separate access/CI
workstream; do not reuse the signed Flutter release workflows to test this app.

Test fixtures bundled with the XCTest target are explicitly synthetic public
wire projections. The synthetic post-correction response is a test resource,
not an application resource or a private corpus. Shared C# HTTP golden fixtures
and canonical content compatibility vectors remain different contracts.

### Canonical public question vectors and cryptography

The test-only `Fixtures/apple-compat/v1/` tree is an exact copy of
[`certigo-content/test/fixtures/apple-compat/v1/`](https://github.com/gaby27072001/certigo-content/tree/6922952936678c1bc37d8bb0db9e50afbef38a90/test/fixtures/apple-compat/v1)
at data revision `6922952936678c1bc37d8bb0db9e50afbef38a90`. Directory layout,
producer expectations and UTF-8/LF bytes are retained. No answer-key resources or
producer tooling were copied. The upstream README-only revision
`eddc7b7ebf0a1d4608d5d5acdb6212cbc4498615` does not change these data vectors.

`CanonicalQuestionReader` validates the existing v3/v4 public wire shapes,
required fields, nested allowlists and schema patterns. It preserves legacy v3
choices separately from v4 option IDs rather than inventing IDs or translating
the corpus into the HTTP lesson DTO. A schema-valid non-MCQ question decodes,
then fails the explicit `apple-basic-v1` capability gate; malformed known shapes
fail separately. Unimplemented schemas are unsupported, not guessed.

SHA-256 uses Apple's system **CryptoKit** on Apple platforms and the official
[`apple/swift-crypto` 5.0.1 release](https://github.com/apple/swift-crypto/releases/tag/5.0.1)
on Linux, with the target dependency conditional on Linux. This exact release is
Apache-2.0 licensed and requires **Swift 6.2 or newer**; use Xcode 26 or newer for
this lot. `Package.resolved` records the direct revision and the `swift-asn1`
transitive resolution. Swift's package resolution remains relevant on Apple even
though the Linux Crypto implementation is not linked into the Apple client.
No homemade digest or conditional skipped hash test is used.

Tests replay the producer's size/SHA expectations for compact sorted UTF-8 body
bytes **without LF**, and for package payload bytes with **one LF**. They mutate
unknown/answer-bearing properties in memory and check tampering, malformed
numbers, future schemas and unsupported capabilities. Canonical serialization is
limited to the supported question schemas' fixed ASCII keys and small integer
numbers, not a general ECMAScript/JCS canonicalizer.

### Public runtime contract stage

`PublicReleaseContracts` validates public package-manifest/v3 metadata, closed
file entries, optional metadata omission (not null), resource/path consistency,
unique IDs/paths and byte/file/release limits. `rootHash` and `manifestId` are
recomputed from compact sorted body JSON, excluding both identity fields and the
HTTP projection's optional `releaseId`; this is **not** the hash of the serialized
manifest file or the LF-terminated payload files.

The existing authenticated active-manifest endpoint supplies the release binding
in its body and `X-Content-Release-Id`/`X-Content-Manifest-Id`/ETag headers.
`releaseId` is excluded from the manifest digest, so digest agreement alone
cannot authenticate that binding. The separate binding check requires these
values to agree; an authorized HTTPS source remains mandatory.

A pure optional release/v1 descriptor validator excludes only `releaseId` from
its body hash. That contract legitimately includes an opaque `privateManifestId`;
the validated result exposes only the public/release binding. Public manifests
reject `privateManifestId`. **There is no new public descriptor endpoint and no
private package download.** Descriptor parsing is outside the production fetch
path unless an authorized existing source supplies one.

The synthetic `Fixtures/runtime/` metadata references the unchanged producer
question byte digests and follows the current Dart manifest-fixture builder and
C# standalone-manifest/digest contracts. Expected body/release IDs were computed
independently with Node sorted-key JSON and standard SHA-256. The all-zero private
ID is opaque synthetic descriptor metadata, not a private payload. These fixtures
are neither an accessible published release nor proof of the C# HTTP gate.

`PublicReleaseAPI` uses only the existing authenticated active-manifest and public
file routes. The per-request ephemeral transport rejects declared oversized
bodies before buffering, checks each incoming chunk against the quota, denies
redirects and supports cancellation. The source independently checks response
URL, exact cache directives, MIME, identities, ETag, byte count and file SHA.
Transport tests use a per-session synthetic URL protocol, not a global/shared
browser or live content source.

### Durable public runtime engine

`PublicResourceReader` validates the existing closed catalog/v1, coverage/v1
and five runtime-resource/v1 forms against their repository contracts, in
addition to the canonical question profile. Identity and exact byte hash/size
must match the manifest. `questionBank` and `guided` unit requirements are
distinct; checks reference questions instead of carrying correction keys.
Unknown schemas/types and unsupported exercise capabilities fail explicitly.
This is package validation, not a new guided-course editor or renderer, and not
a replacement for the producer/backend's publication and reference-graph gates.
The public anti-leak check never applies to authorized quiz POST feedback.

The opt-in `RuntimeContentStore` uses content-addressed flat filenames, no-follow
directory-relative POSIX handles, regular-file/hard-link checks and a dedicated
process lock. The root must be trusted application storage, separate from the
outbox. Trusted OS path aliases are resolved once; generated cache entries are
never followed through symlinks. Temporary writes are flushed, renamed atomically
and followed by a directory flush. iOS writes request the
complete-until-first-authentication protection class; this Apple-only branch
still requires an Apple SDK/device gate.

One durable state file switches the owner/API-scoped `active` and `previous`
pointers together. Staged files are verified again before publication, reused
after interruption, and never exposed as active while incomplete. Corrupt data,
missing state with existing snapshots, disk failures and capacity failures are
errors, not empty caches or silent legacy/previous fallbacks. Previous recovery
is an explicit operation and revalidates the snapshot first.

`LearningClient.synchronizePublicContent()` obtains the owner from its existing
authenticated `/me` session. It checks both session and sync generation after
every suspension; the final guard and durable activation are synchronous on
the same actor. A persisted revision rejects competing/late activations.
New submissions retain their original manifest pin before enqueue; synchronization
and cleanup import all persisted outbox pins, including other owners and API
environments. Attempts, selected answers and manifest IDs are never rewritten to
the new release, and pending correction still has no local verdict.

Cache accounting includes temporary copies and is capped at 384 MiB.
Explicit cleanup removes at most 32 unreferenced entries per call, retaining
all owners' active/previous/staged manifests, shared blobs and durable outbox
pins. Pins are conservative and never automatically expired, including after an
ACK: a future retention/account-deletion policy must explicitly coordinate them.
If protected data leaves insufficient space, the operation fails rather than
evicting it. This baseline also bounds state to 256 scopes, 1,000 pins and 1 MiB;
quota and full-release I/O performance remain pilot measurement gates.

Synthetic tests cover all public resource forms, tampering, symlink/hard-link
attacks, process-lock contention, actual cleanup thresholds, partial download
restart/reuse, owner changes and overlapping sync generations. The portable
process-death test sends **SIGKILL to its own isolated XCTest subprocess** both
before and after the activation rename/flush, then reopens and resumes the cache.
It is executable on Linux/macOS, not an iOS process-management feature.
This proves the tested Linux filesystem/logic behavior, not physical power-loss
behavior or Apple file-protection semantics.

An independent read-only code review of runtime disk/store, session/outbox
coordination, resource reader and runtime tests found no significant defect on
2026-10-13. It ran no tests and did not independently reproduce the Linux results.
Apple validation must still exercise Darwin's descriptor-relative filesystem
and directory-fsync behavior; the iOS `F_SETPROTECTIONCLASS`/`PROTECTION_CLASS_C`
branch and outbox `completeUntilFirstUserAuthentication` attributes; and the
macOS `xcrun xctest` subprocess/lock/SIGKILL recovery path. No concrete Darwin
incompatibility was identified by the review, but none of these gates is closed.

The runtime engine is not enabled in the development SwiftUI composition.
It requires explicit store configuration and the authenticated connection;
restart tests do not prove a production offline-login lifecycle. No live release,
new endpoint, private payload, auth setting or release/signing workflow was used.

## Remaining gates before a user pilot

No production readiness follows from this foundation alone. Required gates:
actual Xcode simulator build and iPhone/iPad UI tests; supported CIAM SDK and test
account login/refresh/logout; cross-language Cortex vectors; shared backend HTTP
goldens; runtime engine's Apple filesystem/live-contract and app-composition gates; durable in-progress draft
and lesson cache/restart recovery; Flutter-to-Swift Keychain/preferences/outbox
migration; account deletion and consent/notification lifecycle; localization and
VoiceOver/keyboard/Dynamic Type checks; measured startup/input/storage budgets;
approved signing/TestFlight plan and a tested recovery procedure.

Watch/TV, purchases, CloudKit and local generative AI are not enabled.
Progress/readiness remain authoritative on Azure. Do not infer deployment,
signature or account-linking availability from repository configuration.

## Shared backend HTTP vectors

`Fixtures/http-wire/v1/` copies only the six JSON vectors and README from
`docs/contracts/native-client/v1/` at backend revision
`56067f1c4c57a518ff27c2527ca6edd95a1aa589`. Every copied file was checked against
its original Git blob with `hash-object --no-filters`. No backend code or release
workflow was cherry-picked. These public synthetic vectors were exercised by the
backend's real HTTP functions/serializer; Swift tests independently decode the
same bytes and retain null/omitted-field and unsupported-capability distinctions.

The fixture submission's illustrative `demo-client-attempt` is not a UUID:
decoding it does not authorize replay under the current native creation policy.
It is a serializer vector, not proof of successful domain submission or a live
manifest. Matching-question wire data decodes but remains unsupported for the
current UI capability. Nullable/partial API projections are not the closed
canonical corpus schema. Authorized POST feedback is not a public answer bank.

## Next authentication implementation

Microsoft's external-tenant iOS tutorial uses **MSALCIAMAuthority**, not the
workforce/common authority. MSAL supports an exact-version Swift Package
dependency and browser-delegated acquisition/refresh. The next auth lot must
validate the public client ID, CIAM authority, protected API scope and the
development redirect against the existing registration before adding the SDK.
The example redirect convention is `msauth.<bundle-id>://auth`; it must not be
silently substituted for the currently registered Flutter callback.

Approve only the required callback/Keychain capabilities and SDK version, capture
the package resolution, handle the callback once per scene, retain ephemeral
browser isolation for tests and the established provider-selection behavior, and
test refresh/logout/reauthentication with dedicated accounts. Do not adopt the
tutorial's token logging, broad common authority, new registration instructions
or shared-account browser session as application policy.

Official references consulted on 2026-10-13:

- [Prepare iOS authentication (external tenant section)](https://learn.microsoft.com/en-us/entra/identity-platform/tutorial-mobile-app-ios-swift-prepare-app).
- [Sign in iOS users (external tenant section)](https://learn.microsoft.com/en-us/entra/identity-platform/tutorial-mobile-app-ios-swift-sign-in).
- [MSAL Swift Package installation and configuration](https://learn.microsoft.com/en-us/entra/msal/objc/install-and-configure-msal).

This preparation is not evidence that the registration, device callback, SDK
entitlements or CIAM federation have passed a live test.

### Offline authentication boundary

`CIAMConfiguration` only validates supplied **public metadata**: identifier
shape, distinct authority/issuer tenant binding, protected API audience/scope,
HTTPS origin restrictions, exact registered callback, declared scheme and
known other-app scheme collisions. Standard CIAM authority candidates use the
documented root host; explicitly supplied custom-domain candidates use the
documented tenant path. Neither variant has been initialized in MSAL here.
Universal-link redirects are deliberately outside this baseline, not unsupported
by MSAL itself. Registration strings are never silently rewritten, including
the Flutter trailing slash; matching callback schemes for collision detection
is case-insensitive.

The `@MainActor` provider protocol defines silent/interactive acquisition and
local SDK account removal; there is **no provider implementation** or composition
change. The SDK must own refresh/cache/account selection and return a redacted
token wrapper, never a guessed backend owner ID. `/me` remains authoritative for
owner binding. Metadata validation is not account permission, SDK compatibility,
consent, token acceptance or a working login. All tests use synthetic configuration
only; the SDK, entitlements, callback handler and live authentication remain gates.

Cloud's read-only ARM/Graph/OIDC observation on 2026-10-13 supplies these bounded
facts (workstream `7b055adb-fb93-4b7a-8d50-439593835e40`, sent to the parent):

- Staging host: `func-certigo-staging-hwbsyiwa7tqnw.azurewebsites.net`;
  ARM `Running` does not establish HTTP health or the runtime API configuration.
- Public client: `4d1f1075-7bc5-4764-947b-701435a85f8c`; registered callbacks
  were only `certigo://auth` and `certigo://auth/`.
- CIAM tenant: `af721be8-5901-422a-b299-b9c57847b968`; discovery issuer
  `https://af721be8-5901-422a-b299-b9c57847b968.ciamlogin.com/af721be8-5901-422a-b299-b9c57847b968/v2.0`.
  This issuer is **not** blindly passed as the MSAL authority URL.
- API v2 audience: `12910b8e-6c75-4d51-91d8-4d5fb8a6e915`; delegated scope:
  `api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915/user_impersonation`.

These facts must be rechecked before SDK/staging activation or after registration/
environment changes. No secret, app setting, account sign-in or consent was read.
The external CIAM identity directory is distinct from the permitted Azure
infrastructure tenant; do not substitute the latter for the former.

[Microsoft's redirect documentation](https://learn.microsoft.com/en-us/entra/msal/objc/redirect-uris-ios)
allows explicitly configured custom `<scheme>://host` callbacks, but the shared
`certigo` scheme can collide when Flutter and native development apps coexist.
AppAuth's slash behavior proves nothing about MSAL. The preferred proposal is to
add **only** `msauth.com.certigo.native.dev://auth` to the existing public client's
callback list, preserving both Flutter entries and concurrent edits. This needs
specific owner/tenant approval and subsequent SDK/device proof; no registration
was changed. Default-format broker compatibility is not proof that broker
authentication is available for this external tenant.

## Non-destructive Flutter queue inspection

`FlutterQueueReader` is a **dry-run inspector**, not an importer or a preferences/
Keychain bridge. The real Flutter store persists a plain JSON list under
`certigo.sync.queue.v1` (`prefs_sync_store.dart`, `sync_queue_store.dart`);
`SyncAction.toJson` emits distinct entry `id` and server `idempotencyKey`, original
owner, UTC timestamps, raw intent, status and optional content pin. The quiz
decorator captures `/quiz/{encoded-lesson}/submit` and uses `clientAttemptId`
as its idempotency key. No per-entry API environment is stored in that format.

Inspection retains the **entire exact source Data** and its official SHA-256
fingerprint; it never serializes a decoded payload, truncates timestamp precision,
replaces a non-UUID legacy attempt, invents an owner or converts a terminal
action to pending. It bounds input to 2 MiB and 1,000 entries. Duplicate JSON
keys (including escaped spellings), invalid roots and syntax are visible
document-quarantine diagnostics. Duplicate queue/attempt identities, unknown
fields/kinds/statuses, impossible/non-UTC dates, unsafe routes, fractional/bool
retry counts, mismatched pins/idempotency keys and missing owners are held.
Only the current emitted format is inspected: legacy parser defaults are not
silently applied.

Source API provenance must be supplied **per entry**, with an evidence identifier
and validated HTTPS API URL. Neither the current API nor a current account is
accepted as implicit historical provenance. Missing pins remain held rather than
silently using a current release. Done/dead records remain original diagnostics,
not replay candidates. Quarantine here means in-memory classification with raw
source retained; nothing is written, moved, deleted or quarantined in the user's
actual preferences.

An empty issue list is not migration eligibility: full payload/server-capability
admission, actual source-provenance proof, authenticated owner mapping, release
availability/pins and exact raw-intent replay still require a separately validated
bridge. Current typed native submissions require UUIDs and normalize newly
created dates; they are **not used** to re-encode this legacy data. Real iOS
SharedPreferences prefix/domain, same-bundle access, Keychain access group,
SDK/account changes and restart/rollback tests require Apple/bundle evidence.
No existing account or real preference data was accessed by these synthetic tests.
