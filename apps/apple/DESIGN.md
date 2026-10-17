---
name: Certigo Apple
description: Prism identity expressed through native Apple controls
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

## Overview

**Creative North Star: "Prism, native to Apple."**

This scoped record describes the SwiftUI source, not a validated Apple render.
It inherits the root Prism identity without changing the Flutter design system.
The approved objective-first composition is documented in NATIVE_UI_BRIEF.md.

## Colors

Prism violet carries the objective plane with white text. Interactive tint
uses the light violet in light appearance and the existing Prism glow in dark
appearance. Body text, secondary text, separators, and exercise surfaces use
semantic system roles, not fixed light/dark palettes.

## Typography

System Large Title, Title 2, Headline, Body, and Subheadline styles retain
Dynamic Type. No custom font files, fixed-point type ramp, or tracked labels.
The SF implementation is a deliberate native translation, not a claim to
reproduce Flutter Archivo glyphs.

## Layout

TabView owns Learn, Coach, Social, and Profile. NavigationStack carries
details with native back affordances. Learn retains separate My Learning and
Explore paths behind an accessible native menu picker; Social uses the same
local picker vocabulary for Friends / Teams. Profile opens a summary with
pushed history and settings, not another tab strip. Reading regions are centered and
bounded at 680 points, with flexible width and scrolling for compact iPad
multitasking. The objective region owns emphasis; supporting content stays
quiet rather than becoming competing metric cards.

## Elevation & Depth

System navigation and controls own depth. DemoPrimaryButton uses native
glassProminent on iOS 26, with borderedProminent on older systems or when
Reduce Transparency is enabled. These signatures require an Apple SDK that
contains the iOS 26 APIs; runtime availability does not provide that SDK.
Questions and explanations remain opaque. No custom blur, sheen, shadow,
parallax, or continuous decorative animation is introduced.

## Shapes

The objective plane has 24-point rounded corners; answer choices have
16-point corners. System components choose their own geometry. Choice
selection combines a check symbol and border treatment, not color alone.

## Components

DemoPrimaryButton uses an SF Symbol plus a wrapping label and at least a
44-point content height. Lists carry catalog and follow-up information.
Native sheets carry scenario settings; a full-screen demo isolates the
synthetic journey from the explicit development connector.

Interface labels are English, including the isolated entry and developer
connector. Published API content is not translated by the interface. The
French synthetic learning examples are identified by a visible language note.
Coach and Social show availability boundaries, not fake conversations, people
or teams. Their presence in this internal preview is not a delivered service.

The static explanation is not a locally scored correction. Pending,
selected, and mock explanation are separate demo states. The developer
connector's existing API-backed behavior is retained.

## Do's and Don'ts

- Do use semantic surfaces and Apple text styles.
- Do retain the visible synthetic-data notice throughout the demo.
- Do honor system motion/accessibility preferences; this slice adds no custom motion.
- Don't paint glass beneath text-heavy exercises.
- Don't interpret mock explanation, demo follow-up, or a schematic as real progress.
- Don't claim Apple rendering or accessibility validation from Linux tests.
