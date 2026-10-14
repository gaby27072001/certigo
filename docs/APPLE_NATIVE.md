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
development redirect against the existing registration before activating the SDK.
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
local SDK account removal; the Apple-only candidate adapter described below is
**not composed into the app**. The SDK must own refresh/cache/account selection and return a redacted
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
specific owner/tenant approval and subsequent SDK/device proof; the owner's
reported consent is conditional: **"Oui, après les vérifications Apple"**.
No registration was changed. Default-format broker compatibility is not proof that broker
authentication is available for this external tenant.

### Official MSAL Apple SDK preparation (not activation)

The development Xcode target pins official **MSAL 2.16.0**, released 2026-09-22,
at revision `8dfe5bf41fe10e6d2afed62a72c4232adbef20f4`, licensed MIT.
The exact [official manifest](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4/Package.swift)
declares a binary `MSAL` product, Swift tools 5.9, iOS 17/macOS 14/visionOS 1,
and archive SHA-256
`3bef53dae500878c2f07fd7493d54063f4fdcb057dfdb3c239256289a349edb8`.
This aligns with this development target's iOS 17 floor, not watchOS/tvOS SDK
support. SwiftPM dependency and binary-checksum resolution passed under WSL;
the first attempt lacked `unzip`, restored only after that actual failure.
That resolution did **not** build MSAL, UIKit or the Apple app.

The workspace's candidate lock is a schema-v2 pin projection of that successful
temporary resolver's three exact revisions, preserving Crypto/ASN.1 pins. It
does not copy the temporary manifest's origin hash or claim an Xcode-generated
resolution. Mac must resolve/verify these pins against the actual project,
without silently choosing newer packages.

`MSALAuthenticationProvider` is Apple-only, `@MainActor`, and uninstantiated.
It supplies the protected API scope to silent/interactive requests, requests
account selection in an attached UIKit presentation controller, and asks the
SDK for an ephemeral authentication session with broker invocation disabled.
It does not choose the first cached account or fabricate refresh/access tokens.
SDK callbacks carry the SDK's `NS_SWIFT_SENDABLE` result to actor-isolated
validation; this annotation and all Swift-imported APIs still require actual
Apple compilation. It retains only an opaque SDK account/cache identifier and
the returned authority for subsequent silent calls, not a backend user ID.

Result admission requires nonempty whitespace-free Bearer token, unexpired
SDK expiry, matching authority host/tenant and the exact protected granted
scope. Live CIAM scope/tenant representations must be checked; absent or
unexpected fields fail closed, not normalized into a successful login. The API
still validates the access token and `/me` establishes the authoritative owner.
No local JWT parsing, nonce generation, browser OAuth implementation or token
insertion replaces SDK-owned PKCE/state/nonce validation. SDK errors expose
only typed categories, never raw descriptions/userInfo/claims/tokens;
SDK logging is disabled. The private SDK Keychain group is the development
bundle identifier, as documented in the exact cache header, **not nil or a
shared Microsoft group**. No Keychain-sharing entitlement was added.

Acquisition overlaps and local account removal during an outstanding SDK
request fail explicitly. Removal is of the selected SDK cache account only,
not remote sign-out, browser-session clearing or app outbox/profile deletion.
Task cancellation suppresses token delivery but does not prove cancellation of
the SDK browser/request or removal of a record the SDK already cached.
Account selection/restoration across app restart and composition with `/me`,
session generations and durable owner-scoped queues remain Apple/auth gates.
The constructor restricts this adapter to the existing development bundle and
its unique callback. `DevelopmentInfo.plist` prepares that DEV scheme only;
the generated/merged built plist and URL delivery remain unverified.
No app callback handler or UI login action is wired.

`CIAMDevelopmentCandidate` records the dated public observation above but
requires supplied registration/scheme/collision evidence. The observed Flutter
redirect list explicitly **fails** native metadata admission. A test's
hypothetical added redirect is not an actual registration or permission.
Four focused portable tests cover categories, cancellation/network precedence,
the unregistered callback and collision rejection; none executes SDK auth.

Exact-version API references:
[result and Sendable annotation](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4/MSAL/src/public/MSALResult.h),
[token parameters/returned authority](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4/MSAL/src/public/MSALTokenParameters.h),
[private cache option](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4/MSAL/src/public/configuration/publicClientApplication/cache/MSALCacheConfig.h),
[error values](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4/MSAL/src/public/MSALError.h),
[logger settings](https://github.com/AzureAD/microsoft-authentication-library-for-objc/blob/8dfe5bf41fe10e6d2afed62a72c4232adbef20f4/MSAL/src/public/configuration/global/MSALLoggerConfig.h).

Physical Mac/Xcode availability was reported on 2026-10-13; versions,
connectivity and actual build results are not established by that report.
The **first** unsigned Mac validation remains exact
`bbd58c899d269484740d8766a4e6ef378b8621ea`, scheme `CertigoNative`.
This SDK lot is a separate later candidate, never an automatic replacement
for that initial checkout. After the initial gate, the later exact SHA needs
toolchain/SDK discovery, locked package resolution, package tests including
Darwin subprocess/protection checks, and generic-simulator build with
`CODE_SIGNING_ALLOWED=NO`. Then inspect its built DEV bundle/plist, SDK
initialization, callback collision and private-cache behavior before owner
review can satisfy conditional callback permission. Token/login/logout,
isolated test accounts/browsers and runtime activation remain separate gates;
no successful Linux test or syntax parse closes them.

### First actual Mac results and bounded path correction

Access workstream `d3c9449b-220b-437d-8a21-4f7722c4faf4` supplied actual
2026-10-13 logs, directly inspected in its `files/apple-first-mac.log`:
macOS 27.0.1, Xcode 27.0 build 27A266a, Apple Swift 6.4 and simulator SDK 27.0.
The exact initial `bbd58c899d269484740d8766a4e6ef378b8621ea` passed 17
XCTest tests and the generic iOS simulator build with
`CODE_SIGNING_ALLOWED=NO`. No simulator boot, SDK authentication or signing
is implied. An App Intents metadata-extraction warning was nonblocking.

The separate `ba7cfbce6efbee7bc8a3effba83f42507abeac09` attempt is **not
green**: `files/apple-sdk-mac.log` reports 112 tests with 35 failures,
17 unexpected, and exit 1. Runtime tests could not access/remove their
requested temporary roots (Cocoa 260/4). The fail-closed wrapper stopped before
Xcode package resolution, MSAL compilation and built-plist inspection.
The earlier portable results did not detect this Apple path behavior.

The bounded correction replaces whole-missing-URL Foundation symlink resolution
in `RuntimeDisk` with POSIX `realpath` of the nearest **existing** ancestor,
then appends the exact missing suffix for descriptor-relative no-follow
creation. Only `ENOENT` permits ancestor ascent; other errors remain explicit.
Absolute paths reject NUL/dot/parent components; final-root symlinks still
fail admission, and missing suffixes encountering a dangling link fail closed.
No test precreates its runtime root to hide the failure and no cleanup error
is ignored.

Two focused regressions check actual blob access at the requested nested root
through an existing alias, absence at the ancestor's wrong location, and
rejection of final/dangling links without destination creation. A synthetic
boolean diagnostic compares Foundation's pre/post-creation resolution without
logging filesystem paths. This narrows the suspected Darwin missing-suffix
rewrite; actual confirmation of the mechanism and correction still requires
an explicitly approved later Mac SHA. No remote arbitrary probe or allowlist
change was performed by this workstream, and no MSAL/callback readiness is
claimed from this correction.

### Confirmed path correction; next iOS protection compilation gate

The approved exact `3801da48daf0e26a2ed9910dc02c8d60d111af73` Mac retry
passed **114 XCTest tests, zero failures/skips**. Its preserved access-session
`files/apple-corrected-sdk-mac.log` confirms
`Foundation preserved missing alias suffix: false`: the earlier missing-path
rewrite is now demonstrated on Darwin, and the corrected requested-root
regressions pass there. This is actual package evidence, not iOS protection
execution.

Xcode resolved MSAL 2.16.0, Crypto 5.0.1 and ASN.1 1.7.3, then failed the
unsigned simulator build with `PROTECTION_CLASS_C` unavailable in Swift scope
at `RuntimeDisk.swift`. Build exit 65 is not MSAL adapter compilation or a
built-plist proof. Apple's public
[fcntl interface](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/fcntl.h)
exposes descriptor protection get/set operations but does not expose that
class constant to this Swift build. No private header/shim or numeric class
guess is adopted.

The bounded candidate uses the existing public Foundation
[`FileProtectionType.completeUntilFirstUserAuthentication`](https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication)
policy to determine the class from an **empty witness** in dedicated trusted
storage. The witness is opened relative to the anchored directory with
exclusive creation, no-follow, mode 0600 and a fresh generated name.
`F_GETPATH` supplies the directory path only for the empty witness's Foundation
attribute operation; device/inode identity is checked before and after it.
The public attribute is set/read back, then its class obtained from the opened
descriptor. That class is applied and read back on the actual payload
descriptor **before any payload bytes are written**. Payload writes/rename
remain descriptor-relative; no user data enters the path-based witness.
Witness deletion errors propagate on both success and failure; no default,
numeric fallback or simulator-only bypass exists.

A separately invoked read-only targeted reviewer found no significant helper/
lifecycle issues, not Apple execution proof. An iOS-only focused test checks
the written blob's first-unlock attribute, bytes and absence of witness files;
it is deliberately not counted in Linux/macOS tests and was unexecuted
at this source milestone (see the later isolated harness result below).
Actual iOS compile/protection semantics, including lock/reboot/device behavior,
still require the next approved exact candidate and real Apple tests.

The subsequent approved exact `0bb286f4a01ca8989b9815e5f2fd07f1f972054e`
again passed 114 Darwin tests, but the unsigned build failed on Swift's
unavailable variadic `fcntl` overload for the `F_GETPATH` pointer argument
(`files/apple-public-protection-sdk-mac.log`, access session). The class
constant error disappeared; iOS execution and completed MSAL compilation
still did not occur.

The next bounded candidate adds a tiny internal C target,
`CertigoAppleFileIO`, with typed wrappers for all three public fcntl operations
used by this protection trace: path, get-class and set-class. The path wrapper
checks nonnull buffer/capacity against the public `MAXPATHLEN`; other operations
preserve the syscall return value and errno. No casted variadic function,
dynamic symbol lookup, private API or guessed constant is used.
`CertigoData` depends on it only for iOS, and the C implementation is
Apple-conditional: Linux has no fake-success protection implementation.
Protection/witness lifecycle, inode validation and fail-closed policy are
unchanged. This is repository-owned interop code, not a new external dependency.
Apple compiler/runtime evidence for these wrappers is still required.

The approved `ba5d1ea8c04e78f0224e32288fc5c7dd97034e82` actual Mac attempt
passed 114 Darwin tests and compiled the C interop/iOS RuntimeDisk branch.
It then failed on actual MSAL 2.16.0 Swift-imported method shapes:
`account(forIdentifier:)` is a throwing **nonoptional** account return, and
`remove(_:)` is throwing **Void**, not a Bool success indicator. These errors
appeared for both simulator architectures in
`files/apple-c-interop-sdk-mac.log` of the access workstream.
The adapter correction consumes those imported shapes directly and preserves
typed error propagation; it does not invent an optional result, return false,
ignore removal errors or change account/session ownership.
Successful compilation of earlier objects is not protection execution,
successful complete MSAL app build or a login proof. The corrected adapter
still requires its own approved exact-SHA build.

The exact public `MSALPublicClientApplication.h` declares nullable
`accountForIdentifier:error:` and BOOL `removeAccount:error:`; Swift's NSError
importer transforms these into throwing nonoptional-account and Void methods.
The actual SDK compiler diagnostics, rather than a header-only guess, establish
these imported shapes. Thrown account/removal errors still pass through the
redacted typed mapping. The same log exposed a Swift 6.4 C-array string
deprecation in the protection helper; the correction explicitly requires a
NUL terminator and valid UTF-8 instead of repairing malformed path bytes.

### Completed bounded Apple compilation milestone

The approved exact **`a32fe16d76f44cf26678070c652f26ed40854685`** succeeded
on the same actual Mac toolchain: **114 Darwin XCTest tests, zero failures/
skips, and generic iOS simulator `CertigoNative` BUILD SUCCEEDED with
`CODE_SIGNING_ALLOWED=NO`**, exit 0. The access workstream preserved
`files/apple-msal-corrected-mac.log`; its candidate assertion, XCTest summaries
and build-success line were directly checked on 2026-10-13.
The actual MSAL adapter and iOS C interop now compile in the complete app.
An App Intents metadata warning remains nonblocking. The initial `bbd58...`
proof remains a separate historical candidate, not replaced by this result.

This closes the bounded source/Apple-compilation correction lot only.
It does **not** establish SDK initialization/private-cache behavior,
built-plist/lock-byte inspection, callback delivery/collision, sign-in,
consent, token acceptance or refresh/logout. The iOS-only protection test was
not executed by macOS package tests or a generic simulator build; device
lock/reboot semantics remain open. No simulator was booted, no login/runtime
composition activated and no Graph registration/signing changed.
Conditional DEV callback consent remains unconsumed until the remaining
Apple/bundle/collision checks and owner review actually pass.

### Source-only unhosted no-auth test preparation

`CertigoNoAuthTests` is a distinct unhosted XCTest target and shared scheme in
the existing Xcode project, reusing the exact MSAL/CertigoData products.
Its source test bundle identifier is `com.certigo.native.noauth-tests`;
it has no `TEST_HOST`, `BUNDLE_LOADER`, callback declaration or added
entitlement, and signing remains disabled. The DEV application target/scheme,
bundle and entitlements are not changed. Actual generated XCTest runner
identity and test execution still need new explicitly scoped Mac permission.
An unhosted test bundle identity does **not** establish signed runner identity,
Keychain isolation or permission.

The harness tests pure metadata rejection of unregistered redirects/collisions
and its own test bundle identifier. The existing iOS-only descriptor-protection
test is moved, without changing assertions, to one shared source file compiled
by both this target and SwiftPM tests. It uses a fresh temporary directory and
synthetic single-byte payload; verifies actual first-unlock protection,
payload and absence of witnesses; removes only that generated directory.
No tests construct MSAL, enumerate/read/clear its cache, acquire/remove accounts,
visit an authority or simulate successful authentication. Linking/importing MSAL
only is not SDK initialization. Initialization/private-cache probes are
deliberately deferred: choosing a unique client UUID does not isolate the
runner's default Keychain group, and construction may touch that cache before
isolation is proved. A distinct signed host/entitlement policy needs a later
owner decision, not an implicit test capability addition.

`python tools/validate_apple_noauth.py` checks bounded repository configuration:
test identity/unhosted/no-entitlement policy, source DEV callback declarations,
source Flutter/native scheme separation, and all three exact source lock pins
including upstream locations. `python -m unittest discover -s tools -p
'test_validate_apple_noauth.py'` covers synthetic accepted/rejected public
metadata. No installed apps or caches are searched.
Explicit `--built-dev-plist`, `--built-test-plist` and `--resolved-lock` file
arguments can check later **supplied** artifacts; no artifact auto-discovery
or source-equals-built proof is implied. These semantic pin checks do not
claim byte equality of Xcode's lock with the source lock.

Future commands, only after exact-SHA access/execution permission, are
`xcodebuild -project apps/apple/CertigoNative/CertigoNative.xcodeproj
-scheme CertigoNoAuthTests -destination 'generic/platform=iOS Simulator'
CODE_SIGNING_ALLOWED=NO build-for-testing`, followed separately by an
explicitly approved **isolated** simulator destination with `test`. A generic
build does not run tests. If Xcode requires signing, a host or entitlements,
stop and report the gate; do not add those or skip failures into success.
Built-plist inspection, simulator creation/boot/install/execution and cleanup
are separate permission scopes. The temporary access from the prior lot was
removed; this source preparation does not reuse it.

### Later retained artifact and isolated harness evidence (2026-10-13)

The preserved access log `files/apple-noauth-evidence-corrected.log` attributes
the retained artifact to exact `a32fe16d76f44cf26678070c652f26ed40854685`.
The built DEV bundle identifier is `com.certigo.native.dev`, with exactly the
singleton callback scheme `msauth.com.certigo.native.dev`. All three pinned
dependencies passed identity, URL, version and revision checks. The source
lock at a32 and retained lock are byte-identical, both SHA-256
`bdd47caeafeeaece3a223b7e70a9a77cd1598fb5240322f4847469e2d3ff13e4`.
MSAL framework presence is confirmed; artifact metadata is absent and a
Mac ZIP checksum is **not proved**. A framework hash is not a ZIP checksum.
These reads do not prove installed callback ownership/delivery or live
registration, nor SDK construction/cache behavior.

The approved `1272233cb85b6bebefe95597fb7f7f8aae5041f4` harness actually
built unsigned (`TEST BUILD SUCCEEDED`), produced the distinct no-auth bundle
with no callbacks, and ran on a newly created isolated simulator. Its three
metadata tests passed; the protection test **failed** with `unsafeDiskEntry`
re-thrown at the witness helper's catch site. The preserved
`files/apple-noauth-runtime.log` does not distinguish the inode and attribute
guards, so the precise failing guard is not claimed from that line alone.
The final result was four tests, one failure, `xcodebuild` exit 65.
Access confirmed deletion/absence of the sole newly owned simulator UUID
`F990D430-691D-4306-90A0-197DFA8D627F`, removal of the authorized key,
authentication denial (255), deletion of local keys and cleared automation.
That access scope is consumed, not reusable for a correction SHA.

The bounded next correction addresses an actual representation assumption:
`FileManager`'s `[FileAttributeKey: Any]` dictionary can supply the Objective-C
extensible string enum as String/NSString, not a Swift `FileProtectionType`
struct. The shared policy check accepts the typed first-unlock policy or
**exactly its public raw string value**; it rejects absent/nonstring values,
other/weaker policies and trailing bytes. iOS compares against the public
`FileProtectionType` raw value, never a numeric class guess.
The protection test uses that same strict semantic readback rather than an
unconditional struct cast. A portable regression checks NSString/String
bridging and rejected alternatives; the iOS typed-policy regression remains
platform-specific.

Distinct typed errors now identify attribute-policy versus witness-identity
rejection without paths, values, credentials or ignored failures. The original
setter, inode checks, descriptor class get/set/readback and explicit cleanup
are unchanged. Simulator correctness of this correction and the original
failure's exact guard still require an approved later retry; no test is skipped
or transformed into success.
Portable validation of this correction passed 115 Linux XCTest tests, strict
Swift formatting and release build with warnings as errors, plus the existing
five Python validator tests and source metadata check. The seven HTTP fixture
blobs remain identical to their original source. Direct bounded review checked
exact enum/string matching, unchanged no-follow/inode/descriptor-before-write
ordering and witness cleanup; it is not Apple compilation or execution evidence.
The new iOS representation regression is in the already shared
`RuntimeDiskProtectionTests` source, so it requires no new target/project wiring.

The later approved exact correction
`92829d9dff848fb5d2bfcc7825652c4ebc9adcd6` also built unsigned successfully
and ran five tests on a new isolated simulator. The three metadata tests and
`testProtectionAttributeRepresentationsFailClosed` passed on Apple; the
descriptor-write test **still failed**, now with `protectionAttributeMismatch`
re-thrown at line 252 (`xcodebuild` exit 65). The preserved access log
`files/apple-protection-runtime.log` was read directly. This localizes the
rejection to Foundation attribute readback after the setter and before the
descriptor class operations/payload write. It does not distinguish a missing
attribute, unexpected representation or different policy: those values were
not recorded. The representation regression passes, but the source correction
does not establish working iOS protection. No guard is weakened or skipped.
Access reported deletion/absence of its newly owned simulator
`C57A0F1E-9098-4D97-84BC-08D09927D580` and removal of the temporary remote key
and marker; the final authentication-denial receipt was still pending when this
result was received. Further Mac execution requires a new authorized scope.

### Public setter contract correction and bounded diagnostics

Official Foundation documentation inspected on 2026-10-13 states that
[`FileAttributeKey.protectionKey`](https://developer.apple.com/documentation/foundation/fileattributekey/protectionkey)
has a corresponding **NSString** value.
[`FileManager.setAttributes(_:ofItemAtPath:)`](https://developer.apple.com/documentation/foundation/filemanager/setattributes(_:ofitematpath:))
“ignores any rejection of an attempted modification.” Therefore a nonthrowing
setter cannot substitute for exact policy readback.
The helper's setter now explicitly supplies the public first-unlock
`rawValue as NSString`, rather than boxing the Swift struct into `Any`.
This aligns the input with the documented Objective-C value contract; it does
not yet prove that this input was the cause of the Apple runtime failure.

Strict readback now throws one of four internal typed categories:
`missingAttribute`, `nonstringAttribute`, `differentKnownPolicy`,
`unrecognizedPolicy`. It records no raw string, type description or path,
does not normalize returned values and accepts no alternative policy.
The existing shared iOS test source adds exactly one independent
Foundation setter/readback test on a fresh empty temporary file, using the
same documented NSString input but no RuntimeDisk/descriptor helper.
It retains strict expected-policy and empty-content checks and deletes only
its generated directory. Paired with the descriptor-write test, this isolates
whether the direct public API readback also fails in the approved runtime;
neither outcome is inferred in advance.
The harness now has **six tests**: three metadata, representation/category
regression, direct Foundation empty-file readback and descriptor-write
protection. No MSAL construction, cache or network work is added.
Descriptor class GET/SET/exact readback before bytes, witness inode checks and
explicit cleanup remain intact.
This setter/diagnostic source lot passed 116 Linux XCTest tests, strict format,
release warnings-as-errors and the five Python validator tests/source check.
The seven original HTTP fixture blobs are unchanged. Neither the new direct
Foundation test nor changed iOS setter has yet compiled/executed on Apple;
the prior Apple result applies only to exact 92829, not this correction.

### Paired result and platform evidence boundary (2026-10-13)

The approved exact `5a80231c05803501e4b89c5e7e4672bd87b667f0` built unsigned
successfully, with built no-auth identity/no callbacks confirmed. Its six
tests produced **four passes, two failures, zero skips**, `xcodebuild` exit 65.
The metadata and representation tests passed. Both
`testFoundationProtectionSetterReadsBackExactPolicyOnEmptyFile` and
`testProtectedDescriptorWriteRetainsFirstUnlockPolicyAndRemovesEmptyWitness`
threw `missingAttribute`, not a different-policy or nonstring rejection.
The access log `files/apple-foundation-runtime.log` was read directly.
This proves absence of the Foundation protection attribute in both tested
paths in that execution environment, not lack of protection everywhere,
unsupported iOS 27 Simulator as a general rule, or successful descriptor
class application. No payload bytes are admitted by the failing helper.
Access confirmed removal/absence of its sole new simulator UUID
`4F18F2AB-7413-48AD-932E-3C9CE2FAB908`, key withdrawal, authentication
denial (255), local-copy deletion and cleared automation.

Directly inspected official sources bound the next decision:

- [Xcode: running on simulated or physical devices](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
  states that simulators do not replicate physical-device features and that
  hardware-specific features must be tested on physical devices. This is
  general guidance, not a specific guarantee about protection attribute
  reporting in the tested Simulator release.
- [UIKit: encrypting your app's files](https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files)
  describes passcode-enabled, hardware-accelerated Data Protection and
  first-unlock behavior. Its documented existing-file example uses
  `NSURL.setResourceValue(_:forKey:)` with a `URLFileProtection` value and
  `.fileProtectionKey`. That supplies a possible separate public-API
  comparison, not evidence that changing the current setter would fix this
  environment.
- [Data Protection entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.default-data-protection)
  describes the default protection level and capability. It does not establish
  that this entitlement is required to explicitly set an individual file's
  policy, or that adding it would fix the Simulator result.
- Apple's public [XNU fcntl header](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/sys/fcntl.h)
  describes protection-class GET as returning an integer and SET as requiring
  an integer. It does not establish filesystem support in this execution
  environment. No numeric constant or private implementation is imported from
  that reference.

The archived Simulator guide is retired for Xcode 9 and later and did not
provide the sought specific Data Protection limitation. Suggested DTS forum
references could not be directly verified due to the site's verification
barrier; no claimed quote or categorical unsupported-Simulator conclusion is
used as evidence. The observed cause remains **missing attribute in the
paired execution**, with platform/filesystem/API support not yet determined.

Do not repeat the same simulator test without a new testable hypothesis.
The smallest proposed device proof is the existing direct/readback and
descriptor-write pair, unchanged and fail-closed, on a user-approved physical
device with a passcode and a separately approved signed isolated no-auth
host/effective bundle identity. Signing, provisioning, host changes and device
operations are outside this lot and are not performed automatically.
Success must include exact first-unlock readback, descriptor class GET/SET
equality before payload bytes, expected payload and no witness leftovers.
Physical lock/reboot behavior is a separate explicit test step, not implied by
that success. No MSAL, Keychain, account or network operation is needed.
If a narrowly approved environment diagnosis is chosen instead, compare only
fresh empty files through the documented URL-resource API and public
filesystem-protection support reporting; preserve the paired failures and
strict policy requirement rather than declaring a bypass or successful
protection. No additional diagnostic code, entitlement or retry is added here.

For a proposed physical-device lot, first obtain only device availability
(iPhone/iPad usable for isolated testing), not account details or a scan of
personal device data. Then choose the effective no-auth host/test identity
and signing team explicitly. A distinct test bundle alone does not isolate
the runner; review the eventual host, signed entitlements and provisioning
before executing. Use only generated files in that host's sandbox, no DEV app
host, existing SDK/user cache, cloud access or account calls. Start with the
two existing paired protection tests at the approved exact source; retain
failures and stop if the expected policy is absent. Only after those pass
consider separately authorized lock/reboot verification. Delete only the
named harness and generated artifacts under its agreed cleanup scope, never
personal apps/data.

Apple's [developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account)
confirms free Personal Team device installation/testing with an Apple Account
in Xcode; profiles expire after seven days and limits apply. It does not
guarantee that every capability needed by an eventual harness is available
to that team. Apple's [program enrollment guidance](https://developer.apple.com/help/account/membership/program-enrollment)
states that paid membership is not required merely to install an app on a
personal device; the annual Developer Program fee is USD 99, with regional
currency/pricing differences. An existing authorized team may suffice; do
not buy membership or promise a free entitlement path before the chosen
capabilities/provisioning are verified. Account sign-in, developer agreement,
device pairing/trust/developer mode, signing/provisioning and any paid
enrollment require their own user decisions and are not performed in this
documentation-only lot.

### Dedicated physical-test host source preparation (historical source 25e736)

The fixed identities and remote command templates from this initial source
candidate are superseded by **Direct Xcode private-lot preparation** below.
Approval of source `25e736` does not authorize the new source or a new lot.

`CertigoProtectionProbe` is a new minimal SwiftUI application target, separate
from DEV and the unhosted simulator harness. It displays an inert test-host
label, with no package products, authentication composition or network work.
`CertigoProtectionProbeTests` depends on this host and only the existing local
`CertigoData` product. It compiles the unchanged shared protection-test source;
the separate scheme selects exactly the existing Foundation empty-file and
descriptor-write tests. MSAL remains a dependency of other project targets
but is not a linked product/source dependency of either probe target. Project
package resolution may still resolve public dependencies; that is not SDK
construction or auth-cache access.

Proposed source identities are `com.certigo.protection-probe` and
`com.certigo.protection-probe.tests`. Live App ID availability is unproved.
Both Debug/Release configurations default to `CODE_SIGNING_ALLOWED=NO`, with
no team, profile, entitlement, callback or shared-group declaration.
The test `TEST_HOST` points only to
`$(BUILT_PRODUCTS_DIR)/CertigoProtectionProbe.app/CertigoProtectionProbe`;
`BUNDLE_LOADER=$(TEST_HOST)` and the explicit target dependency bind the
dedicated host. DEV and the original unhosted target configurations, source
memberships and schemes are unchanged. No production signing policy changes.

`validate_apple_noauth.py` checks these source bindings/identities, unsigned
defaults, selected-test pair and no-MSAL host dependency boundaries. Explicit
`--built-probe-plist`/`--built-probe-test-plist` paths can validate later supplied
artifact identities and absence of callback registrations; they do not
discover device apps/accounts or establish effective signed entitlements.
Source checks and Swift syntax parsing on Linux are not Xcode project loading,
Apple typechecking, signed hosting, installation or physical execution proof.

The old project/scheme remote execution templates are retired, not performed.
Automatic provisioning can include App ID/device registration and signing
certificate/profile creation by Xcode; these effects require the new exact-lot
consent. No Personal Team/free/paid status is inferred from the selected team.
USB pairing/trust, Developer Mode, passcode entry/reboot and account operations
remain user-controlled separate manual steps. Test cleanup removes only each
generated temporary root; separately authorized device cleanup must remove
only the newly installed named probe/test products, never personal/DEV apps,
shared Keychain items or global signing credentials/profiles.
No lock/reboot protection proof, MSAL initialization or personal-cache isolation
claim follows from adding this source target.
This source lot passed 116 portable XCTest tests, strict Swift formatting,
release warnings-as-errors, seven Python validator tests and source checks.
All pre-existing target/configuration/build-phase objects were compared with
the prior revision and are unchanged; project object references are resolved
and unique, and scheme XML/selectors validate. The new host syntax parses on
Linux, not an Apple typecheck. Shared paired-test bytes and seven original
HTTP fixture blobs remain unchanged. Direct bounded review of host binding,
dependencies and default signing restrictions is source evidence only.

The later bounded artifact checker accepts only explicitly supplied decoded
entitlement/profile plists and selected team, App ID prefix and device.
Following Apple's [TN2415 entitlement troubleshooting](https://developer.apple.com/library/archive/technotes/tn2415/_index.html),
signed application identifiers are exact while a profile may grant its
selected prefix wildcard. Team and App ID prefix are separate explicit
inputs, not assumed identical. The checker requires the expected probe
application ID, team, development debugging permission, optional sole default
Keychain group matching that application ID, provisioned selected device,
current profile validity interval and development-certificate metadata.
Unexpected signed/profile permissions, shared groups, wrong identities,
invalid/expired profiles and all-device profiles stop for manual review.
No policy entitlement is added to make the test pass.

Future invocation, only on artifact files from the approved build:

```sh
python3 -B tools/validate_apple_noauth.py \
  --built-probe-plist "$HOST/Info.plist" \
  --built-probe-test-plist "$TEST_BUNDLE/Info.plist" \
  --probe-entitlements "$B/host-entitlements.plist" \
  --probe-profile "$B/host-profile.plist" \
  --probe-test-entitlements "$B/test-entitlements.plist" \
  --probe-lot-suffix "$APPROVED_LOT_SUFFIX" \
  --expected-team "$APPROVED_TEAM" \
  --expected-app-id-prefix "$APPROVED_APP_ID_PREFIX" \
  --expected-device "$APPROVED_DEVICE_ID"
```

Each file is an explicit input, not a directory search. The entitlement
inputs are prior `codesign` readbacks of the specific built products; the
decoded profile is the specific built host's embedded profile, not a global
profile/account lookup. The optional `--probe-test-profile` checks a separate
profile only if the actual hosted test product embeds one; none is invented.
If the hosted test's actual entitlement layout lacks the expected identity
keys or otherwise differs, the checker stops for manual artifact review;
it does not assume that this conservative allowlist is a proven Xcode 27
hosted-test signing schema.

**Metadata checks are not cryptographic signature/CMS verification**, proof
of certificate ownership, runner identity, installed absence or successful
physical hosting. Use standard Xcode signing and iOS runtime enforcement;
decoding a profile is not offline CMS authentication. The additional offline
CMS-authentication gate is not part of the selected direct-Xcode route.
Synthetic unit fixtures
deliberately use noncertificate bytes to keep that boundary explicit.
No team/device/account/profile data is committed or printed by successful
validation. Existing exact-SHA execution approval is not automatically
retargeted to a later validator commit. The application/test sources remain
unchanged from the approved source candidate.
The artifact-checker lot passed eleven hermetic Python tests and the bounded
source validator; the application/package/project/scheme diff against exact
25e736 is empty. These tests validate metadata rejection rules only, not
real signed artifacts or execution. No Apple/device command was run.

### Direct Xcode private-lot preparation

**Physical result reported on 2026-10-14:** the coordinating session reviewed
four user screenshots of source
`27b8831e471ca841fb5a522b4b94dee1bde79711`, the approved private lot, its
successful build guard and successful signed host/test build. The reported
device was iPhone 17 / iOS 27.0.1. The test summary shows **two executed tests,
one pass and one failure**. The descriptor-write test failed with
`unsafeDiskEntry`, attributed to `RuntimeDisk.swift:87`. Given the unchanged
two-test scheme, the summary implies the direct Foundation test passed; its
individual result and an exported `.xcresult` have not yet been reviewed here.
This is screenshot evidence reported by the coordinator, not an independently
reviewed full log, result-bundle provenance or cryptographic artifact proof.
It supersedes the earlier no-physical-execution status **for this exact
source/lot only**, not the outstanding protection gate.

Line 87 in that source rethrows an initialization error. Within its catch,
`unsafeDiskEntry` can originate from directory-component `openat`, lock-file
`openat`, or the combined lock `fstat`/regular-file/single-link guard.
Initialization has therefore not completed at the reported failure: it is
before the descriptor write, protection witness, class readback and payload
bytes. The catch line does not identify the failed syscall or prove a
hard-link, symlink, inode or protection-policy problem. Sandbox/path traversal
restrictions are a hypothesis, not an established cause. No guard relaxation
or speculative functional fix follows from this result.

The diagnostic source following that result distinguishes internal
`RuntimeDisk.InitializationFailure.directoryOpen(errno)`, `lockOpen(errno)`,
`lockStat(errno)`, `lockNotRegular` and `lockUnexpectedLinkCount`. Failed
syscall `errno` is copied before cleanup/another syscall; successful `fstat`
structural rejection never reports stale `errno`. Errors contain no path,
raw stat value, account/device identifier or file contents. The same
no-follow/directory/regular/single-link requirements still fail closed,
with the same descriptor cleanup, canonicalization and protection-before-bytes
sequence. The public `RuntimeStoreError` declaration remains unchanged.
Real-filesystem portable regressions cover a dangling directory ancestor,
lock symlink, directory, FIFO and hard link without following, removing or
changing their target entries. A deterministic post-open `fstat` failure is
not fabricated with a race or injected syscall layer.
This adds attribution, **not a fix or reproduction of the physical failure**;
it requires its own reviewed SHA and execution lot. The two physical tests
and their scheme selectors remain unchanged.

This supersedes the fixed-ID/remote route, not the strict file-protection
checks. No SSH, devicectl presence assertion, app inventory or remote controller
is required. The previous physical lot stopped before build/sign/provision/
install/test/uninstall. The Simulator `missingAttribute` failures remain
unresolved; source preparation is not physical-device protection evidence.

Only the two probe targets inherit `ProtectionProbe/ProbeLot.xcconfig`.
Without a local lot it supplies **empty bundle identities and signing NO**.
There is no usable fallback ID. The tool generates `secrets.token_hex(16)`
once, then derives exactly:

```text
com.certigo.protection-probe.lot-<32 lowercase hex characters>
com.certigo.protection-probe.lot-<same suffix>.tests
```

The suffix is not a proof of absence or mathematical uniqueness: collision
risk is negligible, not zero. A prior same-ID installation is not authorized
for replacement. Stop on ID/provisioning conflicts, replacement warnings,
unrelated data, unexpected permissions, paid capabilities or a separate
runner. Do not regenerate/retry another lot automatically.

**Short procedure for the user, later on the Mac, not instructions to execute
now:**

1. In a checkout of the separately reviewed exact source SHA, run the following
   from the repository root. Python 3 and Git must already be available; no
   installation/download is implicit. Enter only the already selected team's
   identifier and intended iPhone identifier privately; never a password.
   The script does not discover accounts/devices, contact Apple or build.

   ```sh
   python3 -B tools/prepare_apple_probe.py prepare --source-sha <REVIEWED_SOURCE_SHA>
   ```

2. Keep the resulting manifest/hash for approval of **this exact source, lot,
   team, device and two tests**. Local files are in the ignored, private
   `apps/apple/CertigoNative/ProtectionProbe/LocalLot` directory; do not commit
   or publish them. On macOS the directory/files are owner-only. The manifest
   binds source SHA, suffix, both IDs, private selections, exact selectors and
   configuration hashes. A second prepare refuses even an incomplete existing
   lot. Files are never overwritten; SHA checks detect changes, not malicious
   control of the user's checkout. Save the reviewed manifest hash separately.
   Preparation alone leaves signing NO and is not execution consent.

3. Only after new exact-lot permission for signing/provisioning, installation,
   both tests and scoped cleanup, enable the configuration using that separately
   approved hash, then verify it. This writes only local configuration; it
   neither signs nor installs. Enabling also records the approved hash, and
   refuses a second enable rather than replacing anything.

   ```sh
   python3 -B tools/prepare_apple_probe.py enable --approved-manifest-sha256 <APPROVED_HASH> --accept-standard-ios-and-collision-risk
   python3 -B tools/prepare_apple_probe.py verify
   ```

4. Open `apps/apple/CertigoNative/CertigoNative.xcodeproj` in Xcode. Select
   **CertigoProtectionProbe**, Debug and the already chosen iPhone; privately
   compare destination/team/IDs with the manifest. Reconfirm current USB
   connection and destination, without broad inventory. Trust was previously
   handled manually, not proved current here; effective Developer Mode is
   unproved. Any OS trust/Developer Mode/reboot action remains a separate user
   step. Stop rather than implicitly downloading SDK/device-support/runtime
   components. Do not change DEV, sign in again, add capabilities or change the
   project/team in the editor. Standard Xcode/iOS enforcement replaces the
   additional offline CMS gate, not platform warnings. After consent, **Product
   > Test (Command-U)** builds/signs/provisions as needed and installs/runs the
   host with its embedded tests. In Edit Scheme > Test, the only enabled tests
   must still be:

   ```text
   RuntimeDiskProtectionTests/testFoundationProtectionSetterReadsBackExactPolicyOnEmptyFile()
   RuntimeDiskProtectionTests/testProtectedDescriptorWriteRetainsFirstUnlockPolicyAndRemovesEmptyWitness()
   ```

5. Export this run's `.xcresult` from Xcode's Report navigator to private
   storage. Record the source, approved manifest hash, installed host ID,
   selected destination, installation observation and exported result together
   as the ownership receipt. Require **both tests actually executed**, zero
   skips and no platform/signature/profile/auth warnings before claiming a
   physical result. A launched host alone proves neither test success nor
   protection. If a test fails, preserve its result and stop; do not change the
   expected policy. Only after the receipt establishes this lot's installation,
   the user may remove **that exact host bundle ID** in Xcode's device view.
   Its embedded test bundle goes with it; no guessed runner/unrelated app or
   global certificate/profile/device registration is removed. If installation
   ownership is unclear, do not uninstall. The tests clean only their own
   generated synthetic roots.

The build guard runs on both probe targets and checks the exact clean source,
manifest/configuration hashes, reviewed approval hash and effective suffix,
bundle ID and team. It needs repository read access, so script sandboxing is
disabled **only for these two probe targets**. This guard is defense against
stale/modified local input, not a pre-provisioning scheduling guarantee:
Xcode may resolve signing before build phases. For that reason identity
validation and exact-lot consent happen **before enabling/opening for Test**;
without them no Test action is allowed. No claim of validated Xcode 27 project
loading or signed host compatibility follows from portable tests.

`validate_apple_noauth.py` now requires an explicit `--probe-lot-suffix` for
supplied probe artifacts/signing metadata and derives both expected identities
from it; old fixed IDs and another lot cannot pass. The source/scheme still
bind the unchanged shared tests, TEST_HOST/BUNDLE_LOADER, products and no-MSAL
dependencies. DEV/unhosted configurations, package pins, file-descriptor
invariants and protection failure behavior remain unchanged. No real lot,
account/device data, signature or installation is created by source validation.

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

The independent targeted dry-run review identified one real classification bug:
ICU `$` can match before a final line terminator, admitting equally malformed
pins. Pins now require exact UTF-8 length/prefix/hex bytes and timestamps use
absolute string anchors. Tests cover matching pins and UTC dates with LF/CRLF/CR
terminators. The reviewer read only the dry-run source/tests and underlying Dart
queue formats and ran an ICU probe, not the Swift suite or Apple SDK.

### Source-only storage/bundle evidence

Observation on 2026-10-13, bounded to the repository sources and these exact
locked package archives; re-evaluate after bundle, plugin, build-config or storage
changes. The published archive SHA-256 values were downloaded and matched to
`apps/mobile/pubspec.lock`; no plugin was installed, executed or copied into
application code:

| Package | Locked version | Archive SHA-256 | Lock reference |
|---|---|---|---|
| `shared_preferences` | 2.5.5 | `c3025c5534b01739267eb7d76959bbc25a6d10f6988e1c2a3036940133dd10bf` | `pubspec.lock:707-714` |
| `shared_preferences_foundation` | 2.5.6 | `4e7eaffc2b17ba398759f1151415869a34771ba11ebbccd1b0145472a619a64f` | `pubspec.lock:723-730` |
| `flutter_secure_storage` | 9.2.4 | `9cad52d75ebc511adfae3d447d5d13da15a55a92c9410e50f67335b6d21d16ea` | `pubspec.lock:272-279` |

Published version/source references:
[preferences 2.5.5](https://pub.dev/api/packages/shared_preferences/versions/2.5.5),
[foundation 2.5.6](https://pub.dev/api/packages/shared_preferences_foundation/versions/2.5.6),
[secure storage 9.2.4](https://pub.dev/api/packages/flutter_secure_storage/versions/9.2.4).
Each response supplies the verified archive URL/hash; the member paths/line
references below refer to those exact archives, not an unpinned current branch.

**Preferences.** Bootstrap uses legacy `SharedPreferences.getInstance`
(`apps/mobile/lib/bootstrap/bootstrap.dart:78,109`) and the repo contains no
`setPrefix` override. The locked Dart implementation's
`lib/src/shared_preferences_legacy.dart:22,172-186,259-264` applies/strips
`flutter.`. Therefore the source-derived physical queue key is
`flutter.certigo.sync.queue.v1`, and quarantine keys are prefixed similarly.
The foundation member
`darwin/shared_preferences_foundation/Sources/shared_preferences_foundation/SharedPreferencesPlugin.swift:40-45,58-64,87-107,149-169`
uses standard defaults for legacy writes and, for enumeration, the main bundle's
persistent domain with default (nil-suite) options. This is **not** the new
`SharedPreferencesAsync` or app-group suite path.

**Bundle boundary.** Flutter's checked-in Debug/Profile/Release identifiers are
`com.certigo.mobileapp`
(`apps/mobile/ios/Runner.xcodeproj/project.pbxproj:375,554,576`); its Info.plist
derives `CFBundleIdentifier` from that build setting and declares the `certigo`
callback (`apps/mobile/ios/Runner/Info.plist:12,29-32`). The unsigned native
development project instead uses `com.certigo.native.dev`
(`apps/apple/CertigoNative/CertigoNative.xcodeproj/project.pbxproj:131,151`).
Neither tree has a checked-in entitlements file or a `CODE_SIGN_ENTITLEMENTS`
setting in the inspected projects. This does not prove deployed entitlements,
Team ID, access groups, an App Store identity or a build-time override.
The development bundle does not gain access to the Flutter default domain merely
by naming it. Same-bundle replacement and sandbox/update continuity remain
unproven until actual Apple update-build/device tests; do not change identities to
manufacture access.

**Keychain.** `apps/mobile/lib/features/auth/application/session_store.dart:23-62`
sets only `first_unlock_this_device`, stores `certigo.session.v1`, and reads
`certigo.session.signed_out.v1` **first**, treating exact `true` as a tombstone.
Clear writes that tombstone before attempting deletion; a retained old session
must not be resurrected if deletion failed. The locked plugin's
`lib/options/apple_options.dart:27-37,60-67` and `ios_options.dart:5-15`
default the confusingly named `accountName` option to **service**
`flutter_secure_storage_service`, `groupId` to nil and synchronizable to false.
Actual `ios/Classes/SwiftFlutterSecureStoragePlugin.swift:84-92,173-191`
passes those options to the storage manager;
`ios/Classes/FlutterSecureStorage.swift:11-54` maps the storage key to
`kSecAttrAccount`, option accountName to `kSecAttrService`, and an explicitly
provided groupId to `kSecAttrAccessGroup`. Accessibility is
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. No explicit group means
default **signed** access, not an empty group or proven cross-bundle access.
The plugin read path considers synchronizable variants (`:118-141`); do not
assume a future bridge should read only one variant based on the write default.

Native `CredentialVault.swift:17-20,36-41` uses a completely different development
service/account (`com.certigo.native.dev.session` / `developer-connection`) and
`WhenUnlockedThisDeviceOnly`. It is not a legacy session bridge or MSAL cache.
The old `AuthSession` JSON includes tokens and display claims; source decoding
can derive a user identifier from unvalidated token claims
(`auth_state.dart:146-202`). A bridge must not promote those claims to authoritative
owner mapping: validate through the API and honor the tombstone before any token
handling. No actual session item or credential was read.

**API provenance.** `packages/core/lib/src/app_env.dart:14-38` chooses flavor and
API URL through compile-time defines with a development default. The queue
`sync_action.dart:135-166` does not record an API URL; current build config,
installed bundle or a decoded token cannot establish every retained entry's
historical environment. Do not invent per-entry evidence from those defaults.
Runtime cache/draft migration, signed entitlement inspection and synthetic
Flutter-install-to-native-update persistence tests remain separate future gates.
