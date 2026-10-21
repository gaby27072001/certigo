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

The production entry offers Microsoft sign-in and a clearly isolated fictional
demo, never a manual-token fallback. The developer connector remains DEBUG-only.
Coach and Social remain explicitly unavailable, not simulated services.

See `NATIVE_UI_BRIEF.md` for the connected acceptance journey and validation limits.
