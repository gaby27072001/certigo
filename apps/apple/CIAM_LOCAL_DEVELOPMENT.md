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

For a standard `*.ciamlogin.com` authority, supply either the HTTPS origin or
that origin followed by `/<tenant GUID>` matching `CERTIGO_CIAM_TENANT_ID`.
The MSAL adapter appends the explicit tenant GUID when the configured path is
empty or `/`; existing explicit tenant paths and custom domains are preserved.
This prevents MSAL 2.16.0 from interpreting a GUID host prefix as an
`<GUID>.onmicrosoft.com` tenant during discovery. The issuer remains the separate,
exact tenant-bound `/<tenant GUID>/v2.0` URL. Scope, host and returned tenant
validation are unchanged; no registration or Keychain entitlement change is needed.
See the SDK's
[CIAM authority normalization pinned by MSAL 2.16.0](https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/blob/24941c2102fb2e61734ecf3e0675a5a6f81bf047/IdentityCore/src/validation/MSIDCIAMAuthority.m).

The configured connector signs in explicitly with MSAL and uses the configured
API scope and HTTPS base URL. This development connector does not restore an
account automatically on startup: MSAL account selection is held in memory, so
reopening the connector may require an explicit sign-in again. The API response
remains the source of profile identity, correction, and progress. CIAM
setup/provider failures are displayed without exposing SDK error details or
reverting to manual-token sign-in.

The opt-in is rejected in Release builds. This is development-only plumbing, not
a production sign-in default.

## Optional local scheme helper

Close Xcode before running the helper from the repository root. Put exactly the
ten variables above in a local JSON object whose values are strings, outside
the checkout. Do not include credentials, tokens, or a client secret. This file
contains operator-selected configuration, not proof of identity registration,
SDK compatibility, consent, or the deployed backend configuration.

```sh
python3 tools/native_ciam_scheme.py --config "$HOME/Certigo-ciam-local.json"
```

The helper copies the shared scheme to the current user's ignored
`xcuserdata/<user>.xcuserdatad/xcschemes/CertigoNative Local.xcscheme` and adds
the ten enabled variables only to its Debug Run action. A shared Run configured
as Release is supported: only the new local Run changes to Debug. The shared
scheme remains byte-for-byte unchanged, including its Run and Profile settings;
signing, project file and package pins are not modified. In the local copy,
Test and Profile actions that inherited Run receive its original environment
and arguments explicitly, without the new CIAM variables. Other action settings
and executable references are preserved. Profile may omit the optional
`BlueprintName` only when its target identifier, product and project container
match Run exactly.

The helper refuses unknown,
missing or duplicate keys, whitespace, escaped underscores, Xcode variable
expansion, an unsupported or ambiguous Run action, mismatched executable
references, ambiguous inherited settings, an unignored/tracked destination, or any
existing local scheme. It never overwrites a manually prepared local scheme;
keep using that scheme instead. A complete file is published atomically without
replacing a concurrently created destination. Remove the local JSON yourself
when no longer needed, and do not force-add ignored Xcode user data to Git.

Reopen the same project and select **CertigoNative Local**. No build, network
request, sign-in, account creation, or cloud change is performed by the helper.
Before running on an iPhone, check the target's **Build Settings > Code Signing
Allowed > Debug**, including the resolved value. If it is `NO` or the existing
signature is unavailable, stop; creating this scheme neither enables signing
nor authorizes provisioning, certificate or profile changes. The Run variables
are supplied by Xcode, not embedded as persistent configuration for a later
standalone launch from the app icon.
The app's existing configuration loader remains authoritative for semantic
validation. First open the developer connector without signing in to check
initialization on Apple. An interactive test is separate and uses an authorized
dedicated test identity; its first profile request can provision staging data.

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
