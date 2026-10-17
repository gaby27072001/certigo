# Native Apple model boundary

## Imported foundations

`apps/apple/CertigoKit` provides portable Swift domain contracts, Cortex predictions,
HTTPS transport, verified public-release readers, an owner/API-scoped submission
outbox and runtime content storage. The staged package declares iOS 17 and macOS 14;
these declarations are not Apple build or device evidence.

`apps/apple/CertigoNative/Sources/NativeModel.swift` is an isolated model source,
not a delivered SwiftUI app or an Xcode target. This layer does not import an
application project, UI, signing configuration, provider SDK, native registration
candidate or entitlement. It does not replace Flutter or an installed app.

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

## Inactive authentication and storage adapters

`CIAMConfiguration` validates supplied public metadata: authority versus issuer,
tenant/audience identity, protected API scope, HTTPS URL, exact registered callback
and scheme collision. Validation does not establish registration, consent, grants,
SDK initialization, token issuance or a working native login. The failure
classifier exposes categories instead of provider diagnostic strings.

`CredentialVault.swift` contains an Apple Security implementation using
`WhenUnlockedThisDeviceOnly`. It is not compiled or exercised by the Linux model
harness. Real Keychain lifecycle, SDK cache ownership, callback handling,
PKCE/nonce/state and interactive authentication require separate Apple/provider
integration evidence. No credentials belong in resources, defaults or logs.

## Local validation and its limits

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
does not compile SwiftUI, Security, UIKit or MSAL, or prove Apple Keychain/file
protection, a runtime content graph, provider activation or live service behavior.
The package's three iOS-only protection tests require an Apple SDK test run.
