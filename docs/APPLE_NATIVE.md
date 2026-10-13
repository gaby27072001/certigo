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

This is a **payload reader and digest check**, not a downloaded package release
verifier. Manifest-derived IDs/root hashes, release descriptors, safe paths,
runtime track/lesson resources, staging/atomic activation, previous-release
fallback and submission pin retention across updates remain a distinct gate.
Do not activate untrusted files merely because a payload digest matches.

## Remaining gates before a user pilot

No production readiness follows from this foundation alone. Required gates:
actual Xcode simulator build and iPhone/iPad UI tests; supported CIAM SDK and test
account login/refresh/logout; cross-language Cortex vectors; shared backend HTTP
goldens; runtime public content validation/activation; durable in-progress draft
and lesson cache/restart recovery; Flutter-to-Swift Keychain/preferences/outbox
migration; account deletion and consent/notification lifecycle; localization and
VoiceOver/keyboard/Dynamic Type checks; measured startup/input/storage budgets;
approved signing/TestFlight plan and a tested recovery procedure.

Watch/TV, purchases, CloudKit and local generative AI are not enabled.
Progress/readiness remain authoritative on Azure. Do not infer deployment,
signature or account-linking availability from repository configuration.

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
