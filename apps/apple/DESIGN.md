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

The catalog has no visual domain index. Certification-code prefixes select stable
display bands: AZ/unknown violet, AI magenta, PL rose, MS amber, DP green and SC cyan.
This is a presentation convention, not invented domain metadata. Track names and
codes remain visible, so color never carries identity alone.

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
Authored interface labels are English, including the editorial pilot's controls,
reading status, errors and section headings. Editorial lesson text and source
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
`NATIVE_UI_BRIEF.md` for the exact copy-catalog coverage and remaining English
explanatory labels; this is not a claim of complete translation of every sentence.

The production entry offers Microsoft sign-in and a clearly isolated fictional
demo, never a manual-token fallback. The developer connector remains DEBUG-only.
Coach and Social remain explicitly unavailable, not simulated services.

## Research translated to structure

The research's Speak/Babbel separation is visible as one **Next session** action,
then **Learning plan**, **Review & Practice** and **Goal overview**, not a field
of equal statistic cards. A loaded active path supplies the next available node;
otherwise the named goal is opened to load it. Review recommendations are not
invented. Mimo/Coursera's unit structure uses real node states and remaining
activity counts; a lock explains that the server has not supplied its reason.

Quizlet/Coursera/Uxcel discovery uses native search, a code-family menu and
availability filter. Prism code badges are quiet, continuous capsules, with
readable summaries and explicit counts. An unavailable item can be inspected,
but cannot start practice. There is no guessed provider, content language, format
facet, lesson volume or download size. Filters are retained local view state.

Brilliant's selection/action coherence is a value, not a delayed animation:
named action and lesson identity derive together from the current activity.
Imprint's reading hierarchy retains the question alongside explanation.
**Read again** scrolls the existing text; **Practice again** explicitly loads
the same available activity for fresh selections after server confirmation.
The editorial pilot separates re-reading from revisiting its ungraded formative
exercise; neither action submits a quiz or silently marks it read.

Drops/Babbel follow-up distinguishes loaded activity/unit coverage, current-lesson
local answer selection, paged confirmed sessions and last-loaded readiness.
Unknown data is not zero; completed activity is not exam competence. Coach and
Social explain context and future privacy boundaries as prose rather than
nonfunctional input fields, toggles, chat bubbles or people.

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
