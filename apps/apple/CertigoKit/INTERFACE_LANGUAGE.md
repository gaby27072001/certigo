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
typed catalog covers principal navigation and action/status labels; labels for
which no catalog key exists remain in their authored language, so this contract
does not claim exhaustive localization of every sentence. It does not change
authentication, account identity, scoring, content negotiation or server
contracts. The eight localized content notes explicitly state that interface
translation does not automatically translate the official certification
question text or editorial pilot source text.

Portable coverage: `swift test --filter AppLanguageTests`. This is not an Apple UI,
layout, VoiceOver or linguistic review on device.
