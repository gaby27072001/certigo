# Native Apple privacy release acceptance

## Scope and evidence

Source review on 2026-10-20 at `bc6d058114a608752b4dbcee8aba59f072a30ad5`.
This document is a release checklist, not an assertion of an uploaded binary,
an App Store Connect submission, live policy publication, or Apple acceptance.
Recheck it whenever the candidate, SDK resolution, backend retention settings,
public policy or App Store answers change.

The Distribution target is **CertigoNative**, bundle `com.certigo.mobileapp`,
with Microsoft callback `msauth.com.certigo.mobileapp://auth`. Debug and ordinary
Release are separate development configurations, not the production candidate.
The Flutter release/crash runbooks do not prove native Apple privacy behavior.

## Source-to-disclosure mapping

| Surface | Evidence and disclosure | Acceptance still required |
| --- | --- | --- |
| Microsoft authentication | `apps/apple/CertigoNative/Sources/MSALAuthenticationProvider.swift`, `CredentialVault.swift`, `DistributionInfo.plist`; Entra CIAM/MSAL and system Keychain, not a manual production token flow | Check actual resolved MSAL archive and authentication on the signed candidate |
| Confirmed results and progression | Backend is authoritative; account identity comes from the verified JWT | Integrate and verify `GET /api/me/history` from the history increment; do not label local drafts as multi-device history |
| Offline work | `NativeModel.swift` (`NativeActivityStore`), `SubmissionStore.swift` (`OfflineSubmissionOutbox`), `RuntimeContentStore.swift`; voluntary public packs, local drafts and queued submissions scoped by owner/API | Verify owner changes, offline retry and no private correction keys in downloaded packs on device |
| File protection | `FileProtectionPolicy.swift`, `RuntimeDisk.swift`, `SubmissionStore.swift`, `NativeModel.swift` use `completeUntilFirstUserAuthentication` | Inspect attributes on device; this is **not** `NSFileProtectionComplete`, and allows access after first unlock even when relocked |
| Preferences and metadata | `apps/apple/CertigoNative/Resources/PrivacyInfo.xcprivacy`: UserDefaults `CA92.1`, file timestamps `C617.1` | Inspect final aggregated privacy report; required-reason APIs are not collection declarations |
| Diagnostics | No Sentry or advertising/tracking SDK reference in the native target/package; backend Application Insights remains a distinct service | Reconcile the final dependency tree, SDK manifests and actual backend logging with App Store answers |
| Account deletion | `AccountDeletionFunctions.cs`: authenticated `GET/POST /api/account/deletion`; `AccountDeletionService.cs` verifies recent authentication within ten minutes | Native account-deletion increment is a dependency: interactive MSAL proof, two-step destructive confirmation, status/error handling and owner/API-local purge after server completion |

The public French sources are `docs/legal/privacy-policy.md` and
`docs/legal/account-deletion.md`. `tools/build_public_pages.mjs` reads those
files and produces French pages; there is no English privacy source or English
route in this builder. Do not claim an English policy was updated or published.
See [legal publication procedure](legal/README.md): merging source does not
publish the Azure Static Web Apps site. Do not change sealed scripts/workflows
or deploy as part of this documentation task.

## Store disclosure and SDK boundary

The first-party manifest declares required-reason APIs, not a complete inventory
of server collection. Absence of `NSPrivacyCollectedDataTypes` in that manifest
does **not** mean "Data Not Collected" in App Store Connect.

The detailed upstream MSAL declaration and archive-verification caveats remain
in `apps/apple/PRIVACY_MANIFEST.md`. MSAL's source manifest has its own collection
categories; do not copy them mechanically into Certigo's first-party manifest,
infer that all are used, or ignore them because Sentry is absent.

Read-only portal evidence supplied by the coordinator on 2026-10-20:
`apple-portal-inspection-20261019.json` and
`apple-metadata-draft-20261019.json` (session artifacts; not shipped).
For App Store Connect app `6786861081`, version `1.1`, the inspection displayed
these seven identity-linked types, with app-functionality, personalization and
analytics purposes and no advertising tracking:

| Declared type | Native reconciliation |
| --- | --- |
| Name | Account/profile and identity-provider data actually used |
| Email | Account/contact and identity-provider data actually used |
| User ID | Authenticated owner of server profile, results and progression |
| Product interaction | Submitted learning activity and service events; not unsent local drafts |
| Crash | Review backend diagnostics and resolved SDK behavior; Flutter/Sentry is not a native collector |
| Performance | Review backend telemetry and resolved SDK behavior |
| Other diagnostics | Review backend error/correlation data and resolved SDK behavior |

These are **observed declarations inherited from the Flutter-era configuration**,
not seven verified native collection paths. The Publish button was visible and
was not pressed; the evidence does not establish a published privacy label.
The later metadata artifact confirms the privacy URL
`https://www.certigo-app.com/privacy-policy/` was saved and re-read; the earlier
inspection had shown it missing. Re-evaluate all answers against the same final
native candidate and actual backend configuration before publication. Never
switch to "no collection" merely because the old Flutter crash SDK is absent,
and do not retain a category solely to match historical answers.

## Deletion and retention gate

`GET /api/account/deletion` reads status; `POST` requests/resumes deletion.
The server owns identity and completion. The recent-authentication gate uses
verified `auth_time`, not a client timestamp or the token's expiry alone.
The native implementation must preserve explicit demo/DEV behavior and must
not equate sign-out with deletion.

After server **completion**, purge credentials and the selected owner's
activity, drafts, outbox and user/API-scoped content state; do not purge an
unrelated account or declare success while the request is merely accepted.
Confirm the actual scope and error behavior with the native implementation
owner before closing this gate.

Residual retention follows [account deletion](legal/account-deletion.md):
pseudonymized deletion tombstone/receipt and residual backups up to 30 days;
identity-free deletion/security audit records 90 days. Entra soft-deleted
customer identities have their own documented 30-day recovery window.
No restore may silently reactivate deleted data. These are retention contracts,
not proof of the current deployed backup configuration.

## Exit evidence

- Candidate SHA and final archive's aggregated privacy report, including MSAL.
- Exact App Store Connect disclosures reconciled with the native binary and
  backend; no advertising/tracking SDK claim based solely on a source grep.
- Public policy rendered from the approved sources, published separately and
  checked for drift, with correct language links.
- Device evidence for Microsoft authentication, owner isolation, file protection,
  offline work, server history and deletion completion/purge/failure handling.
- Retention configuration and deletion audit reviewed without exposing identity,
  tokens or credentials in evidence.

Portable source/page tests do not replace any Apple/device or external-service
acceptance item above.
