# Opt-in CIAM sign-in for the native development connector

The native app keeps its existing manual test-token connector when
`CERTIGO_CIAM_ENABLED` is absent or exactly `false`. Set it to exactly `true` in
the **local, unshared Xcode Run scheme** to opt in to CIAM. Once opted in, an
invalid or incomplete value is shown as a setup error; the connector does not
fall back to manual-token sign-in.

Supply these values as local Xcode scheme environment variables. No values are
committed in the repository:

| Variable | Required value |
| --- | --- |
| `CERTIGO_CIAM_ENABLED` | `true` to opt in; `false` to leave the manual connector unchanged |
| `CERTIGO_CIAM_CLIENT_ID` | Existing public-client application ID |
| `CERTIGO_CIAM_TENANT_ID` | Existing CIAM tenant ID |
| `CERTIGO_CIAM_AUTHORITY` | Existing HTTPS CIAM authority |
| `CERTIGO_CIAM_ISSUER` | The issuer URL for that tenant |
| `CERTIGO_CIAM_AUTHORITY_KIND` | `standard` or `customDomain`, matching the authority |
| `CERTIGO_CIAM_API_BASE_URL` | Existing HTTPS backend base URL, including `/api` |
| `CERTIGO_CIAM_API_SCOPE` | One delegated scope for the configured API audience |
| `CERTIGO_CIAM_API_AUDIENCE` | Existing API application ID |
| `CERTIGO_CIAM_REDIRECT_URI` | The app-derived callback URI that an operator has verified is registered for this app |

For the current app target, the redirect must be
`msauth.<app bundle identifier>://auth`, and its scheme must already appear in
the app's `CFBundleURLTypes` exactly once. The loader reads the callback schemes
from the built app's Info.plist and rejects a missing or duplicated declaration.
This local check does **not** verify the redirect URI or delegated permission in
the identity provider, nor callback-scheme conflicts with other installed apps;
an operator must confirm those in the existing app registration before opting
in. No environment variable is treated as proof of that external registration.
Never add a client secret, access token, or credential to the scheme, source,
logs, or a shared scheme file.

The configured connector signs in explicitly with MSAL and uses the configured
API scope and HTTPS base URL. This development connector does not restore an
account automatically on startup: MSAL account selection is held in memory, so
reopening the connector may require an explicit sign-in again. The API response
remains the source of profile identity, correction, and progress. CIAM
setup/provider failures are displayed without exposing SDK error details or
reverting to manual-token sign-in.

The opt-in is rejected in Release builds. This is development-only plumbing, not
a production sign-in default.
The synthetic Foundation configuration tests do not compile the iOS app or
MSAL/UIKit adapter and do not prove an identity registration, endpoint, account,
or live sign-in. Apple-platform build, callback, keychain, and dedicated
test-account validation remain separate requirements.

## Debug simulator builds

The project-level Debug configuration uses `ONLY_ACTIVE_ARCH = YES`; the app
target inherits it. This keeps an Xcode Run build aligned with the selected
simulator and its Swift package modules, rather than also requesting an Intel
slice when the packages were built only for the active Apple Silicon simulator.
No architecture is hardcoded or excluded: an Intel destination can still select
its own active architecture. Release settings are unchanged. A successful
generic simulator build is not proof that Xcode Run compiled and launched the
app for the selected destination; verify that separately without changing
package pins, signing, or clearing caches.
