---
name: Certigo Apple
description: Prism identity shared by connected learning and the isolated demonstration
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

**Prism, native to Apple.** This is a native translation of the root `DESIGN.md`,
not a pixel copy of Flutter. The connected experience and isolated demonstration
share the same identity. This document describes source implementation, not a
validated Apple render.

## Color and contrast

`NativePrism` takes its six ink/glow bands directly from
`packages/prism_ui/lib/src/tokens/prism_colors.dart`. Foregrounds use ink in light
appearance and glow in dark appearance; Increase Contrast moves these foregrounds
toward black or white. The main objective plane remains solid violet `#3B35F2`
with white text, including in dark appearance. Brighter foreground colors are
never used as fills beneath white body text.

The catalog has no visual domain index. Recognized code namespaces use the seven
Radar display categories: cloud violet, AI magenta, Apple/mobile rose, data green,
DevOps amber, security cyan and enterprise blue. Blue reuses Prism `info` /
`infoGlow` (`#1562AA` / `#52A2F8`), not a new vendor-brand palette. Existing
Microsoft subject accents remain unchanged: AZ violet, AI magenta, PL rose,
MS amber, DP green and SC cyan. Unknown codes keep violet without acquiring a
guessed provider or category. These are explicitly code-derived display hints,
not authoritative server metadata or a claim of a vendor partnership.
Track names, codes and availability remain visible; color never carries identity alone.

Canvas, reading surfaces, body/secondary text and borders use adaptive UIKit
semantic roles. Borders use the label role at increased contrast. Success and
pending use green and amber foreground roles with an accompanying symbol and text.
This does not import Flutter's handmade glass, shadows or its entire theme engine.

## Type and layout

Use SF through SwiftUI semantic styles and Dynamic Type, not custom font files,
fixed-point text or tracked labels. This intentionally translates the Archivo
hierarchy rather than reproducing its glyphs.

The main learning goal is one violet 24-point rounded plane, followed by the real
next action. Supporting content stays quieter. Reading and account/history pages
are centered and bounded at 700 points; answer choices have 16-point corners.
Use opaque cards for a correction, a saved attempt or a worked example, not a card
for every paragraph. Code can scroll horizontally without widening the reading
column. The editorial catalog does not truncate lesson objectives.
Principal interface labels, discovery filters, learning/Coach/account sections
and editorial controls use typed eight-language copy. Editorial lesson text and source
descriptions retain their original French with an explicit language/provenance
notice; interface language is not a content translation claim.

`NavigationSplitView` and its selected-track/lesson bindings remain authoritative
for connected learning, including compact-column resume. Its native selectable
lists retain system selection and back behavior; the sidebar now includes the
objective-first composition and track accents. It is not replaced by a custom
navigation shell. iPhone, iPad and multitasking must still be checked on Apple.

## Controls and material

`NativePrimaryButton` uses system `glassProminent` on iOS 26, otherwise
`borderedProminent`; Reduce Transparency also selects the opaque fallback.
Questions, explanations and text-heavy reading never use glass. Answer choices
combine a rounded border, check icon, selected accessibility trait and readable
state value. Pressed choices receive a semantic system fill.

No custom animation, blur or decorative haptics is added. System navigation and
controls own transitions, depth and motion preferences. Native signing, launch,
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
then **Learning plan**, **Review & Practice** and **Goal overview**, not a field
of equal statistic cards. A loaded active path supplies the next available node;
otherwise the named goal is opened to load it. Review recommendations are not
invented. Mimo/Coursera's unit structure uses real node states and remaining
activity counts; a lock explains that the server has not supplied its reason.

Quizlet/Coursera/Uxcel discovery uses native search, code-family and code-category
menus and an availability filter. Only categories present in loaded entries are
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
