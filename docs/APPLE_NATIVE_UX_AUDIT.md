# Native iOS UX audit and delivery roadmap

Audit date: 20 October 2026. Scope: source review of `apps/apple/CertigoNative`;
no Apple SDK build, simulator run, screenshot, or assistive-technology session
was available for this review. Scores below describe source evidence and
validation coverage, not a visual-quality certification.

## Executive assessment

Certigo already uses native SwiftUI navigation, system controls, semantic
typography and colors, and explicit separation between fictional demonstration
content and server-confirmed learning results. Its real learning path preserves
the server as authority for goals, correction, rewards, and readiness. That is
a strong foundation, but the checked-in app is not yet a release-ready iOS
product: its connected entry is explicitly a developer test connector, Coach
and Social are unavailable, and essential accessibility, device, and network
acceptance has not been demonstrated on Apple hardware.

| Area | Source-review score | Evidence and qualification |
| --- | ---: | --- |
| Native platform fit | 4/5 | `TabView`, `NavigationStack`, `NavigationSplitView`, `List`, `Form`, system symbols, and native controls are used. Runtime behavior is unverified. |
| Accessibility foundations | 3/5 | Headers, selected answer traits, accessible progress labels, minimum-size actions, and explicit audio controls exist. Large-text, VoiceOver, Switch Control, and Voice Control tasks remain untested. |
| Adaptivity | 3/5 | Split navigation, flexible widths, scrolling, and `ViewThatFits` are present. iPad, rotation, and accessibility text sizes have not been exercised. |
| State communication and recovery | 3/5 after this change | The editorial pilot and demo expose explicit states. This change adds path/lesson loading and retry states; real slow/offline behavior still needs Apple validation. |
| Appearance and contrast | 3/5 | System semantic colors and grouped backgrounds are used in most views. No rendered contrast measurement was performed. |
| Product readiness | 2/5 | The native connection screen explicitly says production sign-in is not enabled; Coach and Social are visibly not connected. This is a release gate, not a cosmetic defect. |
| Motion and feedback | 3/5 | Navigation relies on system behavior, with no decorative animation or unsubstantiated haptic layer. Reduced Motion and interaction feel still require device acceptance. |

## Content shape and truthful progress

The content owner's final analysis for this work confirms a bank-first catalog:
33 tracks contain 734 real multiple-choice questions, all at difficulty 2;
there are no canonically authored units or lessons. The 27 complete coverage
references describe blueprint coverage, not complete courses, learner mastery,
or certification readiness. The French guided editorial pilot remains a
separate, explicitly non-certifying fixture. Do not convert question counts,
reference coverage, or fictional demo scores into learner progress; do not
translate bank content just to make it visually uniform.

Question prompts have a median length of 291 characters, a 95th percentile of
650, and a maximum of 1,404. Layout acceptance should use real long prompts and
large text, preserving the entire prompt and available answer actions rather
than imposing an arbitrary rewrite or truncation threshold.

## Journey and state inventory

| Journey | Existing behavior verified in source | Risk or required acceptance |
| --- | --- | --- |
| Entry and connection | `NativeRoot` uses a clearly labelled development connector; token input is secure and marked privacy-sensitive. Restore and operation status are surfaced. | Production onboarding/authentication is not enabled. Do not represent this build as a consumer-ready login flow. Verify restore, sign-out, and error recovery using the separately owned authentication integration. |
| Learn, Explore, and goal choice | Native tabs and navigation; demo goals are labelled fictional. Connected goal changes have explicit pending/server-confirmed status and do not imply that browsing changes the goal. | Verify focus and wayfinding when switching tabs and columns at iPhone/iPad sizes. |
| Certification path | `NavigationSplitView` lists units, lock state, estimated duration, readiness, and a server refresh action. | Previously, a selected path could look like the empty “Choose a certification” state while loading and had no path-level retry affordance. The first UX lot below corrects this. Explain locked-lesson availability when the content contract supplies a reason. |
| Lesson and quiz | Lesson text, code, and questions are separate; answer choices expose selected state; submit is disabled until complete and asks the server for correction. Pending, confirmed correction, and saved answers are distinct. | Previously, loading a selected lesson could show “One session at a time.” The first UX lot replaces this with loading/retry states. Validate selection, submit, correction, and resume with slow network and VoiceOver. |
| Demo exercise and history | The design fixture labels fictional content and outcomes, provides selected-answer state, and does not calculate a score or grade. Demo persistence and simulated offline/error scenarios are explicitly described. | Demo network states are simulations, not evidence of real offline content availability. Keep that distinction visible. |
| Editorial pilot | The French pilot names its non-certifying scope, audience, sources, and reading status. It has loading/error/retry UI. Explicit audio reads the pedagogical allowlist, requires a user-selected voice, and excludes practice prompts and feedback. | Verify French VoiceOver/voice behavior, large text, audio interruption, and content rendering on supported iOS versions. Never infer the content language from the device voice. |
| Profile and settings | Server-confirmed XP/goal and device-saved submissions are distinguished. Settings clearly identify the developer connection. | Saved submissions display their raw `lessonId`; resolve to a human-readable title when the loaded contract can do so, otherwise use a clear generic label rather than expose internal identifiers. |
| Coach and Social | Native destinations explicitly state that the services are not connected and that no relationship is created. | These are intentionally unavailable surfaces, not functional product features. Do not add controls that imply otherwise. |

## Prioritized work

### P0 — Required before a public product release

| Work | Acceptance criterion | Dependency and validation |
| --- | --- | --- |
| Replace the development-only entry with the approved production sign-in/onboarding path. | A new user can understand the supported account path; restore, sign-out, expiry, and account isolation work without exposing tokens or creating an unintended identity. | Authentication owner and product-approved identity flow. Apple SDK build and real-device authentication acceptance required; this UX patch does not change authentication. |
| Complete the connected learning loop against real content. | A person can choose an available certification, open a real lesson, submit answers, receive only server-confirmed correction/progression, and resume safely. | Stable API/content availability and test account. Exercise success, pending, error, and account-change cases on Apple. |
| Align the real catalog journey with bank-first content. | A learner can reach real questions without implying that a blueprint coverage reference is a course, that 734 questions are authored lessons, or that the fixed difficulty implies mastery/readiness. | Product/content/API contract decision. Keep this separate from the guided editorial pilot and from this UI-only patch; validate actual question-bank entry and server-confirmed outcomes before describing the loop as delivered. |

### P1 — Inclusion and essential recovery

| Work | Acceptance criterion | Dependency and validation |
| --- | --- | --- |
| Make loading/failure/retry states specific to selected paths and lessons. | Selection immediately communicates loading; a failed load shows a relevant unavailable state and a retry for the same selected item; success shows the requested item, never stale content. | Implemented in this first UX lot at source level. Validate slow responses, forced failures, retry, VoiceOver announcements, and iPhone/iPad rendering on Apple. |
| Complete accessibility acceptance across the core journey. | At the largest supported Dynamic Type size (at least 200%), no question—including real prompts up to 1,404 characters—answer, explanation, or action is clipped or hidden; VoiceOver exposes hierarchy, selection, correction state, and recovery; all actions remain operable without precise gestures. | Source preparation can be mac-free; compilation and task-based VoiceOver, Switch Control, and Voice Control checks require Apple devices. |
| Make network recovery actionable wherever a real operation can fail. | Each failure preserves safe user work, explains what did not complete, and names the valid next action; retry does not duplicate submission or imply an unconfirmed result. | Depends on existing outbox/idempotency and API error contracts; verify against real network interruption and server outcomes. |
| Verify contrast, appearance, and motion preferences. | Light/dark and increased contrast retain readable text and non-color state cues; Reduce Motion and Reduce Transparency remain usable without losing feedback. | Source review plus rendered Apple acceptance; do not add decorative blur or custom motion to meet a checklist. |

### P2 — Comprehension, adaptivity, and polish

| Work | Acceptance criterion | Dependency and validation |
| --- | --- | --- |
| Improve progress-history labels. | Saved submissions show a lesson title when the loaded path identifies it; an unknown ID is never shown as a raw implementation identifier. | May require loading more metadata; do not add an API contract solely for display. |
| Explain locked learning items. | A locked row communicates why it is unavailable and what unlocks it, but only when the server provides that fact. | Content/API contract; never infer an unlock condition. |
| Review editorial catalog summaries at large text sizes. | Objectives remain discoverable at accessibility sizes; the row is clearly actionable and full content remains available on the lesson screen. | Current catalog intentionally previews objectives to three lines; confirm with device layout and accessibility testing before changing that trade-off. |
| Validate iPad and localization behavior. | Sidebar/detail navigation, long lesson text, dates, numbers, and French editorial content remain understandable in supported locales and orientations. | Apple device/layout testing; localization target languages require product confirmation. |

### P3 — Optional interaction enhancements

| Work | Acceptance criterion | Dependency and validation |
| --- | --- | --- |
| Consider selective haptic confirmation. | At most a subtle, causally timed cue follows a genuinely server-confirmed milestone; no cue implies a pending or fictional result, and VoiceOver/Reduce Motion users retain equivalent status feedback. | Product/design review and real-device testing; no haptic is required merely for novelty. |
| Tune system-native transitions only where they improve wayfinding. | Navigation remains interruptible, uses system behavior, and preserves Reduce Motion. | Requires on-device interaction review; avoid adding glass or motion as decoration. |

## First UX lot implemented

`NativeRoot` now distinguishes a selected path or lesson from the previously
loaded item. While the requested item is loading, the detail pane shows a
specific progress indicator. If loading fails, the same selection remains
visible with a direct retry action. The implementation reuses existing model
operations and does not alter persistence, authentication, API contracts,
submission behavior, or server authority.

Source-level acceptance for the Apple follow-up:

- Select a different certification while delaying the API: show “Loading
  learning path…” and never show a lesson from the previously selected track
  until the requested path arrives.
- Fail that request: show “Learning path unavailable”; retry loads the same
  certification and success replaces the state with its path.
- Select an open lesson while delaying the API: show “Loading lesson…” rather
  than “One session at a time.”
- Fail that request: show “Lesson unavailable”; retry loads the same lesson.
- Repeat at compact iPhone and iPad split-view sizes, with VoiceOver and large
  text; confirm the progress and retry controls are announced and reachable.

The source change can be reviewed and syntax-checked without a Mac. SwiftUI
type-checking, rendering, assistive-technology behavior, and network-driven
interaction remain Apple validation gates.
