---
name: Certigo Apple
description: Expressive Prism learning studio with native Apple interaction
colors:
  prism-violet: "#3B35F2"
  prism-dark-tint: "#8097F8"
typography:
  display:
    fontFamily: "Apple system"
  body:
    fontFamily: "Apple system"
---

# Design System: Certigo Apple

## Direction

**Prism learning studio: Brilliant / Duolingo + Apple Fitness+.** This is the
user-selected replacement for the former restrained, text-row-led presentation.
Vibrant goal planes, code-colored certification identities, tactile answer options
and evidence-backed activity tiles express the learning loop. System navigation,
opaque reading surfaces and product truth remain authoritative. This document
describes source implementation, not a validated Apple render or an award claim.

## Color and contrast

`NativePrism` takes its six ink/glow bands directly from
`packages/prism_ui/lib/src/tokens/prism_colors.dart`. Foregrounds use ink in light
appearance and glow in dark appearance; Increase Contrast moves these foregrounds
toward black or white. Goal planes use adjacent dark Prism ink stops with white text, including in dark
appearance. AWS's amber plane ends in rose rather than success green. Brighter
foreground colors are never used as fills beneath white body text. Presentation
tests sample every hero gradient against white text at the normal-text 4.5:1 floor;
these calculations do not replace inspection of composited Apple rendering.

`NativeTrackTheme` is a code-derived display hint, not a provider field. AZ codes
use ocean blue, GH and AI indigo/violet, DP/Fabric emerald, AWS amber/rose, and
SC/security plum. Remaining recognized namespaces reuse the existing Radar
category spectrum. Blue reuses Prism `info` / `infoGlow`
(`#1562AA` / `#52A2F8`), not an official vendor palette. Unknown codes retain the
neutral Prism identity without acquiring guessed provider metadata, a logo,
availability, or a claim of partnership. Existing catalog families and filter
semantics are unchanged.
Track names, codes and availability remain visible; color never carries identity alone.

### Vector vendor emblems and preparation crests

`NativeEcosystemEmblem` ports the stylised vector `Canvas` primitives from
`packages/prism_ui/lib/src/components/vendor_brand.dart` into SwiftUI `Canvas`:
Microsoft tracks (`az-*`, `ai-*`, `dp-*`, `sc-*`, `ms-*`, `pl-*`) display the
four-colour 2×2 Microsoft vendor badge (`#F25022`, `#7FBA00`, `#00A4EF`, `#FFB900`)
alongside an Azure prism, Fabric diamond or Security shield; GitHub tracks (`gh-*`)
pair the stylised mascot silhouette (`#24292F`) with a Copilot halo (`#8534F3`,
`#BF3989`, `#2DA44E`); AWS tracks (`aws:*`) draw the `#FF9900` upward arrow arc on a
Squid Ink (`#232F3E`) ground; and Google Cloud tracks (`gcp:*` / `google`) draw the
four-colour ring and horizontal crossbar (`#4285F4`, `#EA4335`, `#FBBC05`, `#34A853`).
Other ecosystems fall back to Certigo facets, curved ribbons or a five-node
constellation. `NativeCertificationCrest` frames that artwork with a two-line
pennant, hexagon or octagon and the exact loaded exam code. They remain preparation
identifiers, **not evidence of an earned qualification**. The accessible label uses
the localized learning-path label and exact code, never a claimed level or award.
Numeric code suffixes do not assign Fundamentals/Associate/Expert or stars.

The same source component appears on catalog cards, the confirmed learning goal,
track detail, quiz, mock exam, contextual Coach and profile. Only a loaded Track
or exam contract supplies a certification code. A missing code uses abstract
Certigo artwork, not a guessed vendor. Colored motifs are decorative; labels use
adaptive high-contrast Prism ink on opaque semantic surfaces. Crest geometry
scales with Dynamic Type (decorative mark capped at 112 points to preserve reading
width) and the code wraps instead of being truncated. Goal, quiz, exam and active
path headers use a compact horizontal version; no new full-height badge is placed
above the primary learning action.
Artwork is bundled as Swift source, has no network request, binary asset,
added dependency or project-file change.

Canvas, reading surfaces, body/secondary text and borders use adaptive UIKit
semantic roles. Borders use the label role at increased contrast. Success and
pending use green and amber foreground roles with an accompanying symbol and text.
This does not import Flutter's handmade glass, shadows or its entire theme engine.

## Type and layout

Use SF through SwiftUI semantic styles and Dynamic Type, not custom font files,
fixed-point text or tracked labels. This intentionally translates the Archivo
hierarchy rather than reproducing its glyphs.

The learning goal is a vibrant 28-point rounded plane with a readiness ring only
when the loaded path belongs to the confirmed goal and provides a valid percentage.
A compact XP/streak strip precedes it; the full profile Bento never precedes the
next learning action. Rounded SF appears in short headings and numeric values,
not long reading text. Supporting content stays quieter. Reading and account/history pages
are centered and bounded at 700 points; answer choices have 16-point corners.
Use opaque cards for a correction, a saved attempt, a metric or a worked example,
not a card for every paragraph. Code can scroll horizontally without widening the reading
column. The editorial catalog does not truncate lesson objectives.
Principal interface labels, discovery filters, learning/Coach/account sections
and editorial controls use typed eight-language copy. Editorial lesson text and source
descriptions retain their original French with an explicit language/provenance
notice; interface language is not a content translation claim.

`NavigationSplitView` and its selected-track/lesson bindings remain authoritative
for connected learning, including compact-column resume. Its native selectable
lists retain system selection and back behavior. Course rows use symbol medallions,
readable code capsules and complete titles. Category chips mutate the same local
filter state, and cards precede device-restore and editorial utilities. It is not replaced by a custom
navigation shell. iPhone, iPad and multitasking must still be checked on Apple.

## Controls and material

`NativePrimaryButton` uses system `glassProminent` on iOS 26, otherwise
`borderedProminent`; Reduce Transparency also selects the opaque fallback.
Questions, explanations and text-heavy reading never use glass. Answer choices
combine a rounded border, check icon, selected accessibility trait and readable
state value. Pressed choices receive a semantic system fill.

Answer selection and changed readiness use the shared Prism 240 ms standard
feedback curve; Reduce Motion removes that interpolation. No blur, confetti,
decorative haptics or custom navigation transition is added. Native signing, launch,
archive and MSAL configuration gates are unchanged.

## Product truth

Server-confirmed goal, last-loaded readiness, pending local answers and confirmed
results remain distinct. History never invents counters or progress. Names are
resolved from already loaded catalog/path/offline data; unknown IDs remain visible
rather than being replaced by guessed titles. Audio is available through an
expandable control group. Account deletion remains a separate destructive flow.

## Interface language

The app resolves a system preference or an explicit eight-language choice once
at its shared SwiftUI root, persists user selection immediately, and supplies
Foundation locale and typed `AppInterfaceCopy` to connected learning, the
fictional demo, and the editorial pilot. Both the arrival surface and Settings
show native autonyms alongside localized language names. This changes interface
chrome only: certification questions and French editorial source text remain
unaltered and carry an explicit source-language disclosure. See
`NATIVE_UI_BRIEF.md` for the application-chrome catalog coverage and its source-content
boundary. Secondary history, deletion, audio, configuration and demo messages use
the same eight-language contract; stored notices resolve in the current language,
not the language selected when an error occurred. This is source-wiring coverage,
not a claim of linguist-reviewed translations or verified Apple-device layout.

The production entry offers Microsoft sign-in and a clearly isolated fictional
demo, never a manual-token fallback. The developer connector remains DEBUG-only.
Coach accepts explicit requests about a confirmed answer; Social remains
unavailable, not a simulated service. Coach has no free-text composer or chat memory.

## Research translated to structure

The research's Speak/Babbel separation is visible as one **Next session** action,
then compact review/focus shortcuts, **Learning plan** and **Goal overview**.
A loaded active path supplies the next available node;
otherwise the named goal is opened to load it. Review recommendations are not
invented. Mimo/Coursera's unit structure uses real node states and remaining
activity counts; a lock explains that the server has not supplied its reason.

Quizlet/Coursera/Uxcel discovery uses native search, a code-family menu, category
chips and an availability filter. Only categories present in loaded entries are
offered; alias namespaces share a family while Microsoft subject families remain
distinct. Filters intersect and clear together. Prism code badges are quiet, continuous capsules, with
readable summaries and explicit counts. An unavailable item can be inspected,
but cannot start practice. There is no guessed provider, content language, format
facet, lesson volume or download size. Filters are retained local view state.

Availability badges use neutral opaque surfaces and a book symbol, not a success
check or a promise of imminent publication. The same eight-language
`practiceAvailable` / `practiceUnavailable` copy appears in Explore and the track
overview; unavailable entries show a source-honest explanatory note. The goal
plane and session pane never offer playable practice for an explicitly unavailable
catalog entry, even if an older path remains loaded. Saved work is not deleted.

The Radar registry is an editorial discovery source, not an OTA catalog:
`gaby27072001/certigo-content` commit
`e90948c8d47b274bb6a5797b84f77abf48b20e87`,
`config/content-radar-sources.json` and `docs/CONTENT_RADAR.md`.
Its `announced` review drafts are not valid catalog/v1 entries. The current app
contract exposes only `learningAvailable`, not provider/category, announced/planned
status, or release date. This native presentation does not publish drafts, add
tracks or connect Radar to the backend. Those require a separately approved
end-to-end contract and release.

Brilliant's selection/action coherence is a value, not a delayed animation:
named action and lesson identity derive together from the current activity.
Imprint's reading hierarchy retains the question alongside explanation.
**Read again** scrolls the existing text; **Practice again** explicitly loads
the same available activity for fresh selections after server confirmation.
The editorial pilot separates re-reading from revisiting its ungraded formative
exercise; neither action submits a quiz or silently marks it read.

Drops/Babbel follow-up distinguishes loaded activity/unit coverage, current-lesson
local answer selection, paged confirmed sessions and last-loaded readiness.
Unknown data is not zero; completed activity is not exam competence. Coach presents
the server's explanation and evidence only after an explicit request. Social
explains future privacy boundaries as prose rather than
nonfunctional input fields, toggles, chat bubbles or people.

Profile metrics and quest/achievement boards use an adaptive two-column grid,
falling back to one column at accessibility sizes. Missing streak, level, daily
goal or board fields do not become zeros, fake earned badges, or synthetic quests.
Quest progress uses its supplied current/target, not an invented XP reward (the
contract supplies gems). Unit bars count completed/mastered activities; lesson
rings use only supplied mastery percentages. Readiness remains preparation,
not mastery or a pass probability. The quiz rail counts selected answers, not
correct answers; only confirmed results acquire score rings. The submit action
is in the native bottom safe-area inset; pending answers never receive success styling.

Study Plan is a short native sheet with optional target date, initial level and
daily minutes, stored separately for each account/API/goal. The learning dashboard
uses real domain scores and server recommendations without inventing domain
coverage or a mastered-domain count. Five mastery symbols are a reference:
server lesson states assign only supported stages; no exam-ready stage is inferred.
The assessment page is a resumable server-graded MCQ simulation, not an official
exam or pass guarantee. Notification settings are server preferences, not an iOS
push authorization. Rewards remain confirmed, read-only server values.

Shared rounded surfaces use continuous Apple corners and 8/12/16/24-point internal
rhythms. Hierarchical symbols are limited to category labels on semantic surfaces;
white-on-violet hero symbols remain opaque monochrome. The busy inset has a solid
semantic fallback under Reduce Transparency. Self-check criteria are numbered
neutrally, never shown as earned success checks. The objective action sits adjacent
to the violet identity plane, not violet-on-violet inside it.
Native controls and opaque reading surfaces
retain precedence over decoration. `NATIVE_UI_BRIEF.md` maps all U01–U12 patterns
and distinguishes source coverage, deferred service contracts and Apple-only
acceptance. This is not a claim that every research capability is shipped.
The follow-on `certigo-apple-ui-excellence-pass-2026-10-21.md` is applied
semantically, not copied as a file replacement or treated as native render proof.

See `NATIVE_UI_BRIEF.md` for the connected acceptance journey and validation limits.

Explorer opens with a horizontal ecosystem showcase. Counts are calculated from
the loaded catalog, with practice availability separate from the collection count.
Tapping a universe replaces local filters; tapping it again or clearing filters
restores the collection. Account changes clear this selection too. These are
code-family display groupings, not additional issuer metadata.

Unit lessons form numbered stepping stones with colored connectors and explicit
mastery-stage pills. Only supplied mastery percentages fill the node rings;
sequence numbers never imply completion. Each row retains its single real
navigation action and availability guard. The development welcome uses original
ecosystem artwork without catalog counts or achievement claims. Its demo remains
explicitly fictional. Developer dismissal now lives in native navigation toolbars
instead of reserving another top banner; swipe dismissal stays disabled.
Apple compilation and device rendering remain separate acceptance gates.
