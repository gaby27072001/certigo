# Interface language contract

`CertigoDomain.AppLanguage` supports French, English, Hindi, simplified Chinese,
Korean, Spanish, Italian and German. “Indian” is represented by Hindi (`hi`),
not by a claim to support every language spoken in India. Traditional Chinese
is not declared as a supported script.

`AppLanguagePreference` is either `.system` or `.explicit(AppLanguage)`.
Load and save with an injected `UserDefaults` suite; the shared app key is
the concatenation of `certigo` and `.app.interface-language.v1` (a local key,
not a web domain). Missing or unrecognized persisted values
resolve to the system preference. The raw representation is `system` or the
canonical language code and is suitable for an app-owned observable preference.
An explicit choice does not require restarting the process. With `.system`,
resolve against the current preferred language list when the app refreshes its
environment. The first supported language wins, with English as the fallback.

`AppInterfaceCopy(language:)` supplies typed properties for the principal labels
and an exhaustive `Key` subscript for all catalog entries. No external resource
or platform UI framework is required. `localizedDisplayName(in:)` uses Foundation's
language naming data; `nativeDisplayName` is the stable autonym.

The SwiftUI app observes the chosen preference at its root, rebuilds copy and
locale, and exposes the picker on entry and in connected/demo settings. The
typed catalog covers principal navigation and action/status labels as well as
detailed account-deletion, audio, history, configuration and model-error copy.
Adding a key does not itself localize a callsite: the app must resolve it with the
current environment at display time. This contract does not claim exhaustive
localization of every rendered sentence. It does not change
authentication, account identity, scoring, content negotiation or server
contracts. The eight localized content notes explicitly state that interface
translation does not automatically translate the official certification
question text or editorial pilot source text.

## Detailed messages and interpolation

The `error*`, `deletion*`, `audio*`, `history*` and `configuration*` keys cover the
corresponding native source messages inventoried at revision
`13c692d522b2213cd48781be6dbd428d5913ad44`. All have explicit translations in all
eight languages, without a per-key English fallback. Keep stored errors typed
(key plus associated values), not already resolved strings, so changing the
interface language also updates an error already on screen.

Use these complete-sentence formatters rather than joining translated fragments:

```swift
copy.requestRejected(httpStatus: 503)
copy.deletionProgress(completed: 2, total: 7)
copy.historyLoaded(count: 12, hasMore: true)
copy.historyScore(scorePercent: 81, xp: 27, confirmedOnDevice: false)
copy.confirmedScore(81)
copy.coverageCount(completed: 2, total: 7)
copy.questionCount(selected: 2, total: 7)
copy.configurationValue("CERTIGO_CIAM_ISSUER", production: false, missing: true)
```

`confirmedOnDevice` selects the confirmed acknowledgement label instead of the
recorded server-history score label; it does not validate evidence or turn a
pending submission into a result. Callers remain responsible for ownership,
scope and acknowledgement checks. Counts are literal cardinal counts, not claims
about unrequested history pages or all-time coverage. Template placeholders may
change order by language; tests check exact token preservation in every locale.

Configuration names, HTTP status codes, paths and protocol identifiers are
preserved verbatim. Configuration messages remain presentation-only: no sign-in
fallback, validation rule or identity behavior is changed. Source learning text,
demo question fixtures and server-provided explanations are not catalog entries.

Portable coverage: `swift test --filter AppLanguageTests`. This is not an Apple UI,
layout, VoiceOver or linguistic review on device.
