# Certigo — expressive SwiftUI redesign blueprint

**Status:** implementation blueprint for the user's selected direction, not an app patch, visual approval, or claim of production readiness. **Selected direction:** “Brilliant / Duolingo + Apple Fitness+: vibrant cards by learning universe (Azure/GitHub/AWS), mastery rings, an XP/Streak/Quests Bento grid, and a tactile quiz arena.” Keep the Prism identity and Apple-native interaction model; this decision supersedes the earlier *restrained Prism* proposal where visual energy conflicts, but it does **not** supersede its truthfulness, accessibility, or platform constraints.

## Executive decision

The iPhone frames inspected for this handoff show a useful connected/demo slice, not evidence that the current visual system is a final launch design. The developer connector banner appears over user-facing screens; Learn is mostly a sequence of pale text rows; the catalog gives filters more visual weight than certifications; Profile is sparse; Coach and Community clearly state that they are not connected; the editorial pilot has a captured loading state. This is enough to validate that the user's “too basic / without soul” reaction is about the actual visible UI, not a hypothetical direction. It is **not** evidence that all current screens are final, nor that a production backend, Coach, Social, exam mode, or native accessibility has been validated.

Use **confident, vivid learning surfaces over a calm, readable canvas**. Put identity into the goal hero, provider-coded track cards, a clear learning path, a tactile question state, and a purposeful profile Bento. Keep high-chroma color in bounded areas; avoid turning every card into a gradient, every event into confetti, or every metric into a decorative ring. The interface must look more alive while remaining trustworthy when the user's real state is empty, loading, pending, offline, or unavailable.

## Evidence boundary

### Directly inspected in this pass

The evidence is static iPhone imagery supplied in `video-frames-3`, including `sheet_01.jpg` and selected frames `frame_024.jpg`, `frame_045.jpg`, `frame_061.jpg`, `frame_082.jpg`, and `frame_089.jpg`. These frames show:

- Learn with no server-confirmed goal, a purple “find your next goal” card, Explore, and sections awaiting a confirmed plan/review.
- Explore with three stacked filter controls, “7 / 39” catalog count, and certification rows with code/title/summary/availability. The count is visibly a loaded/filtered subset, not proof that all 39 are in memory at once.
- Profile with “XP confirmed 0” and no visible streak/quest data.
- Coach and Community empty/unconnected states, not working AI or social services.
- An editorial pilot showing “Loading…” in one captured frame. This is a state observed, not a measured load duration or a demonstrated hang.
- The “Developer connector” overlay across the app and a Welcome/demo state explicitly labeling demo objectives, answers, and explanations as fictitious.

The supplied parent-session report also described a 43.585-second runtime showing goal selection, a three-option question, selection/pending/fictitious explanation and progress, with no alert in that recording. That is **reported by the parent**, not a video I independently watched in this pass. Neither evidence set establishes real certification scoring, persistent authentication, successful app relaunch, a complete 39-track catalog, Coach generation, community actions, exam validity, VoiceOver behavior, or iPad quality.

### Research reused, not re-audited

Use the retained research dossiers rather than repeating the benchmark: `certigo-art-direction-proposal-2026-10-15.md`, `certigo-education-mobbin-research-2026-10-15.md`, `certigo-motion-interaction-research-2026-10-15.md`, `certigo-four-tab-coverage-2026-10-17.md`, `certigo-four-tab-interactions-2026-10-17.md`, and `certigo-apple-ui-excellence-pass-2026-10-21.md`. Their evidence distinguishes inspected reference pixels/sequences, executed public-web interactions, documentation, and Certigo proposals. Brilliant/Duolingo, Apple Fitness+, Babbel, Drops, Mimo, Quizlet, Coursera and Uxcel are pattern references, not assets to copy. Reuse the earlier UX findings and service-contract gates; no new app-source audit or new benchmark is claimed here.

## 1. Visual system: Prism with purposeful energy

### Tokens and color roles

Implement these as a small extension of existing Prism semantic colors, not a new framework. Values below are **proposed starting tokens**, not official vendor brand specifications. Provider identity must come from an explicit provider field, never a guessed code prefix or title substring. The vivid gradient is an accent surface, not the default background of all content.

| Role | Proposed light | Proposed dark | Use |
|---|---|---|---|
| App canvas | `#F6F5FA` | `#100F18` | Quiet page background; avoid flat system gray everywhere |
| Main surface | `#FFFFFF` | `#1C1A29` | Reading, question and list content |
| Raised surface | `#F0EDFA` | `#262337` | Secondary tile / selected filter, with a clear edge |
| Primary ink | `#171624` | `#F6F3FF` | Titles and body copy |
| Secondary ink | `#5F5B6E` | `#C6C0D3` | Supporting text, never the only state label |
| Prism action | `#4334D1` | `#B7ACFF` | Primary CTA, selected navigation, focus accent |
| Hairline | `#E3E0EA` | `#3A354B` | Separation only when spacing/grouping is insufficient |

Use system-adaptive foregrounds and surfaces in production (`Color(uiColor: .systemBackground)`, existing semantic tokens or equivalents); do not hard-code the light palette into dark appearance. Test Increase Contrast, differentiating status with text/icon/shape as well as color. Normal text on a fill must meet **4.5:1** contrast; large text and graphical boundaries/indicators must meet **3:1** where WCAG criteria apply.

| Certigo provider accent (proposed, not official logo colors) | Main saturated fill | Bright supporting accent | Foreground rule |
|---|---|---|---|
| Azure | `#005A9E` | `#0078D4` | White on the main fill; use the bright stop as a glyph/edge or pair it with dark ink after contrast check |
| GitHub Copilot | `#4C3FB4` | `#7047EB` | White on either listed fill; keep the Copilot mark only in an authorized asset |
| Fabric | `#006B50` | `#008A63` | White on `#006B50`; do **not** put small white labels on `#008A63` (4.36:1) |
| AWS | `#8C3A00` | `#B45309` | White on either listed fill; use amber as an identity cue, not an error/success state |

Calculated white-label contrast for the main fills: Azure `#005A9E` **7.10:1**; GitHub `#4C3FB4` **7.84:1**; Fabric `#006B50` **6.52:1**; AWS `#8C3A00` **7.72:1**. White on supporting accents: Azure `#0078D4` **4.53:1**, Copilot `#7047EB` **5.54:1**, Fabric `#008A63` **4.36:1** (fails normal-text AA), AWS `#B45309` **5.02:1**. White on Prism `#4334D1` is **7.92:1**. Proposed neutral pairs: `#171624` on white **17.85:1**; `#5F5B6E` on white **6.55:1**; `#F6F3FF` on `#100F18` **17.38:1**; `#C6C0D3` on `#1C1A29` **9.67:1**. These are pair calculations, not a substitute for testing composited gradients, opacity, selected borders, or actual rendered states.

**Card treatment:** provider-coded gradient appears on a compact hero/header, a narrow leading rail, or a small identity tile. Keep course title, description, readiness, question and explanation on opaque, high-contrast surfaces. Use one bright edge and a restrained tonal tint on secondary surfaces. No full-bleed gradient behind long text; no stacking translucency; no per-provider rainbow in one card. Use gradients for identity, not status: green still means confirmed success, amber a genuine caution, red an error.

### Type, geometry and spacing

- Use system font throughout. Use `.rounded` selectively for the short app/hero heading and large numeric XP/readiness; use standard system design for lesson prose, question stems and explanations. This gives warmth without impairing technical reading or requiring bundled fonts.
- Roles: screen title 30–34 pt bold; hero/title 22–26 pt rounded semibold/bold; section 18–20 pt semibold; question/lesson heading 20–24 pt semibold; body 17 pt; metadata 13–15 pt only when secondary. Let Dynamic Type resize and wrap everything. No fixed card height, text compression, truncation of question text, or use of caption text for a pending/error/privacy explanation.
- Use the shared 8/12/16/24 pt rhythm: 8 label-to-value, 12 sibling rows/options, 16 card internal padding, 24 section separation. Page margins 20–24 pt, aligned with native safe areas. Continuous corners: 24 pt hero, 20 pt standard card, 16 pt compact control, implemented with `RoundedRectangle(cornerRadius:style:.continuous)`. Avoid card-within-card nesting; use whitespace and one subtle inset surface instead.
- Use a small icon vocabulary from SF Symbols, `.symbolRenderingMode(.hierarchical)` only for category/meaning icons. Keep the goal hero and provider identity monochrome/opaque; do not apply palette mode to every symbol. Always pair an icon with a textual status where meaning matters. Do not draw vendor logos from SF Symbols or approximate proprietary marks.

### Chrome, language and developer diagnostics

Keep the four top-level destinations only: **Apprendre / Coach / Communauté / Profil** in French, localized through string resources rather than hard-coded. Preserve content-language labels independently from app-language settings. Native tab bar remains recognizable and persistent; selected state uses the Prism action color, with SF Symbols and visible labels. Preserve each tab’s scroll/filter state when switching. On iPad, adapt to the existing native sidebar/split-view pattern where the current app architecture supports it; do not add a second, nested tab system.

Remove the persistent “Connecteur développeur” bar from the user-facing build. Diagnostics belong in a dedicated developer-only surface or debug menu behind `#if DEBUG`, not an overlay in the main app. Never show raw service names, connector timings, internal model names, “server record” labels or local-cache internals to learners. Translate operational conditions into a clear user message tied to the action, e.g. “Couldn’t refresh your plan. Try again.” Preserve the details in logs, not UI.

### Liquid Glass boundary

Keep readable learning content opaque. Use system Liquid Glass only for system-level navigation or transient chrome when available (iOS 26); preserve the iOS 17+ fallback and existing Reduce Transparency behavior. Do not raise the deployment target. No glass on quiz options, editorial paragraphs, dense catalog cards or a background under text. In iOS 17/18, use familiar native material only for a small transient control when legibility remains stable; otherwise use a solid semantic surface.

## 2. Screen-by-screen SwiftUI specification

### A. Apprendre — `PrismLearnHome`

**First viewport order:** (1) “Apprendre” navigation title, (2) active objective hero or honest no-objective state, (3) one clear primary action, (4) a compact “À suivre” / today plan from real recommendations, (5) lower-page review and recent activity. No banner, multiple giant headings, stacked technical sections, or equally weighted CTAs.

**Objective hero:** use a provider accent, but cap the vivid region to roughly the top third/identity band; put the title, certification code/provider, actual status, one sentence of context and a single action in a readable composition. If a goal is confirmed, primary CTA is **Reprendre** only if a resumable checkpoint exists; otherwise **Continuer** / **Commencer** according to the real service state. Put Switch objective in a quiet menu/button. If no confirmed goal, present a designed “Choisir mon objectif” card with a visually clear Explore CTA; do not show an empty ring, zero mastery, or a dummy course.

**Readiness ring:** the current capture and earlier source review identify a server readiness scalar, not a proven mastery percentage or pass probability. Therefore implement the ring as **Préparation** and bind it only to the exact authoritative readiness value and semantics. Show `value / 100` only if that is the actual contract; include freshness or source context accessibly, not debug language. Do not rename it “Maîtrise”, infer probability of passing, invent a numerator/denominator, or animate an optimistic local increase after answering. If the server score is missing/stale/insufficient, replace the ring with an explicit neutral state such as “Préparation indisponible” or the actual source status; do not render `0%` as a substitute. A true mastery ring is a separate follow-up only after a mastery definition and source are confirmed.

**Today’s plan / quests:** render one “À suivre” card from existing plan/review recommendations. A Quests tile may appear only once the product has real quest IDs, criteria, period/timezone, state and update authority. Until then, call it “Plan du jour” (if genuinely available), not “Quête”, and do not fabricate progress bars or streaks. Streak is shown only from a defined authoritative streak field; a confirmed zero is fine, unknown is hidden/labelled unavailable.

**Plan list:** visually connect units with a thin spine and small step/status marks; each row is an actual server/content item with title and accessible availability. Use a compact status label as well as a distinct icon. The proposed progression language is `À découvrir → En cours → Réussi → Maîtrisé`, but display only the states present in the contract; “Réussi” requires a confirmed result, and “Maîtrisé” requires an actual mastery rule. Never fill a progress rail from merely opened lessons.

### B. Certification detail and learning path — `PrismTrackDetail`

Use a coherent course header (provider color, official title, exam code pill, optional level/duration only if catalog metadata supplies them) and one contextual CTA. Then a clear outline: units, lesson/question counts only if real, prerequisites and available exercise status. The path line helps orientation, not simulated completion. At large Dynamic Type it becomes a vertical list; no horizontal-only timeline. Keep the back path and selected objective explicit; viewing another certification must not silently replace the active objective.

### C. Explorer — `PrismExploreCatalog`

The screenshot shows three vertically stacked filter controls and a **7 / 39** loaded result count above the actual catalog. Rebalance: search first, one horizontally scrollable chip row for common filters, a visible result summary, then visual certification cards. Put rare/long filter options in a native filter sheet. Chips wrap or move to an accessible sheet on large text; don't hide filters in color-only pills.

**Card hierarchy:** small provider identity/icon + exact exam code pill (e.g. `AI-901`, `AZ-900`, `DP-900`, `SC-900`, `AI-103`, `AZ-104`, `DP-600` as seen in the capture); large title; short catalog summary; any real level/duration; clear access/exercise availability; one disclosure/CTA. The code examples are observed in the supplied frames, not an exhaustive list of all 39. Keep card height content-driven. Use accent on a narrow header or background mark, and an opaque title field. Do not invent official logos, exam duration, level, publisher, course count or availability.

When the source supports the counts, phrase the counter as **“7 certifications correspondant aux filtres · 39 au catalogue”**, not an ambiguous fraction. The count is filtered matches vs total published and authorized catalog, not loaded list length, unless the service literally means loaded. Empty filter results show “Aucun résultat” plus a one-tap clear/reset. Loading retains query and filters, uses a short non-blocking status (no perpetual shimmer); failure distinguishes “catalog unavailable” from “no matches”. Offline may show an authorized cached list with a freshness label, otherwise explain that refresh is needed.

### D. Question / practice arena — `PrismQuizArena`

Use a focused session canvas, not a row buried in the learning dashboard: top close/back, `Question 3 sur 10` when the known session total supports it, a modest progress rail, question stem, answer options and one bottom action. Never use a fake percentage or countdown. A timer exists only for a qualified, server-defined timed mode and must show its policy.

**Answer option component states:** `idle`, `pressed`, `selectedLocal`, `submitting`, `confirmedCorrect`, `confirmedIncorrect`, `disabled`. On press, highlight immediately and reveal a restrained selection marker; this is not correctness. The selection remains changeable until actual submit. During submission, show “Envoi…” and prevent accidental duplicate taps, preserving the idempotency contract. Only after authoritative response show right/wrong, explanation if authorized, and next action. Do not flash success, update readiness locally, or mark a mastery badge before confirmation. If delivery is uncertain, reconcile attempt status before retrying; do not create a duplicate attempt.

For correction, keep the question/selected answer stable and reveal one opaque explanation panel below it. Distinguish correct answer, rationale and source/reference only when the source contract supplies them. A failed request preserves the selected answer and labels correction as pending/failed; it must not show the fictitious explanation from demo mode as real. Use one light success/error haptic only on confirmed result, and respect system haptic/reduced motion settings.

**Exam practice:** reuse this arena only when the exam mode, item set, timer/pause/recovery, result calculation and official/unofficial labeling are qualified. Until then, do not expose a seemingly functioning “Examen blanc” CTA. If a safe informational destination exists, explain what is not yet available and offer real practice. No simulated score, pass probability, time remaining or certification-like result.

### E. Coach — `PrismCoach`

Visually, the active state may be a calm conversational workspace: concise contextual header (current goal/question only with consent/authorized context), readable messages, streaming status, source chips/cards with actual provenance, Stop while a stream is active, Retry after a real failure, and a composer pinned above keyboard without stealing scroll. Preserve the user's reading position; auto-scroll only if already at the bottom or on explicit send. Long answers wrap at a readable width and support text selection/accessibility. Coach answers must not silently grade or alter an attempt.

**Current evidence is unconnected, not an empty functional AI service.** Until generation, cancellation, sources, privacy and failure states are available, do not draw a fake chat history or enable a composer that cannot send. Show one honest, polished empty/unavailable card with the next available learning action; no “AI is thinking” loop or made-up citations. Once service is real, clearly label partial vs complete output, make Stop actually cancel, and ensure references are tappable and authorized. Memory controls, if later introduced, need separate controls for saved memory and chat history with actual deletion semantics; never imply clearing one clears the other.

### F. Communauté — `PrismCommunity`

Keep Friends / Teams as local content categories inside the one Community destination only when those service surfaces exist. For actual membership, use compact friend/team cards, privacy audience and action-specific pending/accepted states; show invitation action only when authorized. Provide explicit visibility, block/report, leave and invite revocation behavior before broad release. Never expose private scores or readiness by default; team membership does not imply sharing learning history.

**Current evidence is explicitly “not connected.”** Show a confident empty state with a human explanation, not sample names, fake avatars, placeholder activity or dead invitation buttons. When unavailable, direct the learner back to a real learning action. Empty and service-failed states must look different. Invitation/join must remain pending until server confirmation; no success animation on tap alone.

### G. Profil — `PrismProfileBento`

Create a 2-column Bento only for confirmed data, with content-driven height and a one-column Dynamic Type/iPad-narrow fallback. Candidate tiles:

- **XP** — the captured Profile shows confirmed XP `0`; show the exact confirmed value and label. Distinguish confirmed from pending/unsynced if both exist.
- **Streak** — only when a real streak contract defines day boundaries/time zone and update rules; otherwise omit the tile, not `0`.
- **Badges** — only earned server-backed achievements; no decorative empty badges interpreted as earned. An explicit empty state may explain how awards work after criteria are defined.
- **Progress** — link to the existing progression/history source, preserving period, denominator and data freshness. Do not synthesize a graph from unrelated counts.
- **Quests** — only with actual quest criteria/period/state; otherwise use no Bento tile or the real plan card.

Promote one value per tile with rounded numerals, standard label, and small hierarchical symbol. Each tile is a button only if it opens a real destination. Settings, privacy and accessibility remain a readable conventional list below the Bento, not an unlabeled grid of actions.

## 3. SwiftUI component map and implementation shape

Keep this inside the existing native app composition and existing tokens; do not add dependencies, a new design-system package, or an independent quiz/AI/scoring engine. Prefer the current service/view-model types; adapt names to actual types rather than creating duplicate DTOs.

| Component | Owns | Does not own |
|---|---|---|
| `PrismProviderStyle` | Explicit provider ID → semantic accent, icon, gradient | Guessing brand from `examCode`/title; official logo recreation |
| `PrismCard` / `PrismAccentHeader` | Continuous geometry, surface, optional accent band | State/business logic, universal gradient |
| `PrismReadinessRing` | Rendering/accessibility of optional, named readiness value | Score calculation, mastery inference, optimistic update |
| `PrismTrackCard` | Layout of actual track fields and availability | New catalog fields, fake duration/level/count |
| `PrismProgressStep` | Rendering actual item status, text and accessibility | Marking completion on view/open |
| `PrismAnswerOption` | Tactile visual state for one option | Submission, correctness or grading authority |
| `PrismCoachMessage` | Message layout, streaming/partial/source presentation | Generation, citation invention, retention policy |
| `PrismStatTile` | One actual value + explicit label, empty/loading variant | Computing XP/streak/achievement from UI events |

Example implementation contract (illustrative SwiftUI, adapt actual model types and existing theme API):

```swift
struct PrismReadinessRing: View {
    let value: Int?                 // Authoritative 0...100 readiness, not mastery.
    let label: LocalizedStringKey   // “Préparation” while that is the real metric.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let value {
                ZStack {
                    Circle().stroke(.primary.opacity(0.10), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(value) / 100)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(value, format: .number).font(.system(.title2, design: .rounded).weight(.bold))
                        Text("/ 100").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(label))
                .accessibilityValue(Text("\(value) sur 100"))
            } else {
                Label("Préparation indisponible", systemImage: "chart.donut")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

Do not reuse the example's literal 0...100 unless the existing service contract confirms that exact scale. The outer caller should provide the right localized label, freshness and availability state. Add Reduce Motion-aware interpolation only when the actual value changes; never animate on view appearance as if progress had occurred.

Suggested provider card contract:

```swift
PrismTrackCard(
    title: track.title,
    code: track.examCode,
    summary: track.summary,
    provider: track.provider,           // Optional explicit field; fallback Prism if absent.
    availability: track.availability,  // Existing entitlement/exercise state.
    metadata: track.publishedMetadata, // Render only supplied level/duration/language.
    action: { openTrack(track.id) }
)
```

A provider field or published metadata not present in the current model is a **data dependency**, not permission to derive it from the display title. Where provider is unknown, use neutral Prism styling. Avoid new global state; keep local view state for selection/animation, server state for confirmed outcomes, and existing app state for routing/query/session.

## 4. Motion and interaction budget

These are **proposed tuning ranges**, not measurements of the current app or references. Use the existing Prism motion tokens where available; avoid duplicate duration constants. Use iOS-native animation APIs and keep interactions interruptible. No looping motion, parallax, confetti by default, or spring bounce on ordinary taps.

| Moment | State change and visual response | Accessibility / fallback |
|---|---|---|
| Card/button press | Immediate tint/overlay plus scale to `0.985`; settle in about 120–160 ms | Full hit target, visible focus; no scale if Reduce Motion |
| Filter chip | Selected outline/fill and checkmark around 140–180 ms; update results only after local filter state is committed | Label includes selected state; Dynamic Type can wrap; no color-only semantics |
| Tab change | Native system transition; preserve per-tab scroll/filter | System tab semantics, VoiceOver selected trait |
| Readiness/confirmed progress | Animate only from old server-confirmed value to new confirmed value, 220–300 ms, no overshoot | Reduce Motion: update text/value with no sweep; expose one value announcement, not each frame |
| Answer selection | Immediate selected border/check indicator; no correctness color | “Selected, not submitted” accessible state; selection remains reversible until submit |
| Pending response | Small inline progress beside Submit; content stays stable; do not dim the whole screen | Announce once “Sending answer”; can still leave/recover only as session contract permits |
| Confirmed answer | Reveal correct/incorrect explanation with 180–240 ms opacity/short vertical placement only after server response | Reduce Motion: immediate reveal; haptic only after confirmed outcome |
| Sheet/filters | Standard native sheet from invoking control, reversible, 250–320 ms proposal | Reduce Motion uses native fade/no travel; focus returns to trigger |
| Coach generation | Inline “Coach is responding”; Stop is present only if real cancellation; no auto-scroll away from older content | Announce status sparingly; cancellation acknowledged; screen reader retains reading position |
| Invitation/team join | Pending status; confirmed membership state only after response, no celebratory transition before acknowledgement | Speak pending/result once; error preserves form for retry/reconcile |

Keep the page static while reading. Use content transitions only when they explain a real state change. At low power/Reduce Motion, keep shape/color/status cues but remove travel, scale and animated progress. For Reduce Transparency, replace glass with opaque semantic surfaces. Test text in motion and performance on supported iOS 17 devices; no frame-rate claim is made here.

## 5. States and copy rules

For every screen, design distinct `loading`, `loaded`, `empty`, `error`, `offline/stale`, `pending`, `confirmed`, `unavailable/access denied` states. Loading must not look like empty; zero is displayed only when zero is authoritative; unavailable is not zero. Retain search/filter and safe form input on failures. Keep cached private content only under existing account/authorization rules; never claim offline submit, sync or AI.

User-facing status copy names the learner's task and next safe action, not the implementation. Examples: “Votre objectif n’a pas encore été confirmé.”; “Impossible d’actualiser le catalogue. Réessayer.”; “Réponse envoyée — correction en attente.” Use the precise sentence only if the underlying state exists. Keep demo mode unmistakably labeled and ensure demo results never flow into real XP/readiness/history.

## 6. Build order and acceptance gate

1. **Shell clean-up:** remove persistent developer overlay from user builds; retain diagnostics only in a debug-only route. Set tab labels/icons, semantic colors and native safe-area behavior. Acceptance: no developer/connector jargon visible on Welcome, Learn, Coach, Community or Profile in release configuration.
2. **Shared Prism components:** type/spacing/continuous shape/provider style, opaque readable surfaces, light/dark/high-contrast. Acceptance: same component states render consistently; provider unknown uses neutral style; no text is placed on unchecked gradient stops.
3. **Learn + Explore:** objective hero, real empty state, search/filter hierarchy, count semantics and track cards. Acceptance: one primary action in first viewport; filters do not push the first result below an unnecessary stack; exact result/total labels; long titles wrap; no invented metadata.
4. **Detail + quiz arena:** use the existing path, question, attempt ID/idempotency and server correction flow. Acceptance: selected/pending/correct/incorrect/error are distinguishable; no confirmed style or XP/readiness mutation before authoritative response; duplicate-submit recovery tested.
5. **Profile Bento:** XP tile from confirmed field, only include streak/badges/quests when their service contracts exist. Acceptance: each metric has label, unit/period/denominator as relevant, source freshness, accessible value; unknown values are not rendered as zero.
6. **Coach and Community:** layout may be prepared, but interactive controls are gated by real service capability, privacy, cancellation/moderation and server authorization. Acceptance: current unconnected states remain honest; no simulated conversation, contact, invite, team or score.
7. **Exam practice:** separately qualify mode/timer/result contracts before enabling. Do not deliver a decorative “exam” shell that implies certification validity.

### Visual and usability checks before calling this launch-ready

- Inspect iPhone compact/large devices and iPad portrait/landscape; verify no clipped cards, nested tab bars or unreachable bottom actions.
- Check default and largest accessibility Dynamic Type, VoiceOver order/labels/selected/pending states, Increase Contrast, Reduce Motion, Reduce Transparency, light/dark, and keyboard/sheet focus return.
- Contrast-test actual rendered combinations including gradient endpoints, disabled states and translucent material; meet 4.5:1 normal text / 3:1 large text and UI boundaries as applicable.
- Run a short usability check with at least 5 learners across new/returning and beginner/experienced profiles: (a) start or resume a real goal, (b) find a named exam, (c) answer and understand one question's status, (d) locate progress/privacy. Target ≥4/5 correct first action without help; 0 participants should mistake a local selection for a submitted/graded answer; 0 should interpret unavailable metrics as zero. Treat these as proposed release gates, not observed results.
- Compare screenshot sets at a fixed device/OS/content state. Review motion frame-by-frame for status timing, layout jumps, VoiceOver and Reduce Motion. A static screenshot or parse build alone does not validate native interactions.

## 7. Decision log

| Decision | Status | Rule |
|---|---|---|
| Brilliant/Duolingo interaction + Fitness+ metric clarity | **Adopted by user** | Use as visual language, not as permission to copy brand assets or mechanics |
| Bright provider-coded accent cards | **Adopt as proposal** | Explicit provider metadata only; opaque text surfaces; contrast gate |
| Readiness ring | **Conditional** | Label/read exact authoritative readiness; do not call it mastery or pass chance |
| Mastery rings/badges by lesson | **Conditional** | Requires explicit per-unit mastery semantics and confirmed source |
| XP tile | **Supported by captured Profile** | Show the exact confirmed value, including real zero |
| Streak / Quests / achievement Bento tiles | **Conditional** | Omit until field, period, criteria and authority are real |
| Coach chat and citations | **Conditional** | No fake messages; requires generation, cancel/error/source/privacy contracts |
| Friends/Teams/invites | **Conditional** | No fake identities; require privacy, moderation and server-enforced membership |
| Exam arena as qualified mock exam | **Conditional / not established by evidence** | Requires valid mode, timer/recovery, scoring and clear official status |
| Persistent connector banner, raw technical copy, fictional progress, automatic confetti, glass on reading surfaces | **Avoid** | These obscure the learner's task or misrepresent capability |

## Source trail

- Retained Certigo research and evidence dossiers named above; use `certigo-four-tab-sources-2026-10-17.md` for the source register and `certigo-education-mobbin-research-2026-10-15.md` / `certigo-motion-interaction-research-2026-10-15.md` for the specific visual and motion evidence. Mobbin media are analytical references only; do not reuse its app assets.
- Apple Human Interface Guidelines: [Color](https://developer.apple.com/design/human-interface-guidelines/color), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Progress indicators](https://developer.apple.com/design/human-interface-guidelines/progress-indicators), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility). Use current guidance alongside the app’s iOS 17 minimum; do not assume iOS 26-only glass exists on older devices.
- This blueprint contains **recommendations and proposed values**, not a native render, implementation, accessibility audit, build, or usability result. Current service/data contracts remain the gate for all conditional surfaces.

## 8. Official provider marks and certification badges (research addendum, 22 October 2026)

This addendum answers the request for recognizable provider imagery while correcting a key design/legal distinction: **a provider logo identifies the source of a learning resource; a certification badge is evidence of a credential earned by a person.** The latter must never be used as decoration on a course card or as a proxy for course level.

### Verified brand and badge rules

| Ecosystem | Officially verified evidence | Certigo rule |
|---|---|---|
| Microsoft / Azure / Fabric / Security | Microsoft states its logos, product icons and designs are proprietary, and many uses require a license. The public trademark page does not establish that bundling Microsoft/Azure/Fabric product marks in a third-party education app is automatically licensed. Microsoft Learn says certificates/badges are proof of accomplishments and are retrieved/shared from the learner's credential dashboard. | Use plain text provider naming by default. Use a product logo only after confirming the exact asset and product-UI permission; don't trace Azure, Fabric, Security or Microsoft marks from screenshots. Display an issued Microsoft credential badge only for a verified earned credential, unchanged. |
| GitHub / Copilot | GitHub's current Brand Toolkit says the Invertocat and wordmark are available only in specified contexts, prohibits altering marks, and states no adaptation/use of its registered marks or site contents without express written permission. Its current Copilot guidance says the standalone Copilot-icon logo was deprecated in 2025; current product lockups should be used instead. The current Copilot palette includes Purple `#8534F3`, Purple 1 `#C898FD`, Purple 2 `#B870FF`, Purple 4 `#43179E`, Purple 5 `#26115F`, Purple 6 `#160048`, and Orange 1–6 `#F4A876`, `#F08A3A`, `#FE4C25`, `#C53211`, `#801E0F`, `#500A00`. | Do not draw the Octocat/Invertocat, Copilot visor or branch glyph with `Path`; do not recolor a mark with Primer tokens or use a made-up GitHub certification octagon. Use the current official lockup only after written-permission/product-use review. Identify a course with text (`GitHub`, exact exam code) meanwhile. A GitHub credential badge belongs only to its verified earner. |
| AWS | AWS's official trademark terms grant a narrow “Powered by AWS” mark license to eligible current customers to identify qualifying content/services, and impose limitations on modifying/composing marks and implying endorsement. AWS Certification describes its digital badges as a way to showcase certification achievement and links to its digital-badge program. The public pages consulted do **not** publish an authorization for an unrelated learning app to redraw an AWS Certified badge or use it as an exam decoration. | Do not draw the Smile, AWS mark or AWS Certified hex badge. The supplied `#232F3E`, `#FF9900`, `#0073BB` are not verified here as an official complete app/icon palette; don't apply them to the mark. Use the exact authorized artwork only if permission covers this product surface; show an earned badge only for a verified credential. |
| Google Cloud | The official Google Cloud product-icon library supplies current SVG/PNG assets and says the library is for diagrams and technical documentation. The page notes a product-icon system update in early 2025. It does not by itself grant use in an unrelated commercial application UI. | Do not reconstruct the four-color cloud/hexagon. Use the current official product icon only if the applicable brand permission covers in-app course identification; otherwise show `Google Cloud` as text and an original Certigo motif. Treat `#4285F4`, `#EA4335`, `#FBBC04`, `#34A853` as values to verify against the exact authorized asset, not as permission to recolor it. |
| Kubernetes / CNCF | CNCF publishes project artwork in official SVG/PNG variants and requires marks to remain unchanged, with clear space and no misleading implication of sponsorship. Its brand guide says product/website/commercial logo use should be checked with CNCF; it lists CNCF blue `#0086FF` for the CNCF brand, not as a universal Kubernetes logo recolor. | Fetch the official Kubernetes project asset only after the use case is checked against CNCF/Linux Foundation policy. Do not draw the 7-spoke helm symbol or recolor it `#326CE5` from memory. Use a text label if permission is unclear. |
| HashiCorp | The official brand site returned HTTP 429 in this bounded review, so asset-specific permission, palette, current Terraform/Vault marks and usage constraints were not verified. | No logo or hand-traced mark in this tranche. Use factual provider text until the official current guide and product-app permission are reviewed. |
| CompTIA | The candidate official logo-usage URL returned 404 and no current official policy was verified in the bounded review. | No logo or certification badge until an accessible official policy/asset is confirmed; use plain text. |
| ISC2 | ISC2's official copyright page says marks and website contents may not be copied/reproduced without permission, and says its named certification marks/logos are authorized for certified individuals only, subject to its Logo Usage Guidelines. Its digital-badges page describes the badge program. | Do not use ISC2/CISSP or other certification-logo/badge art as course decoration. Use text for the catalog; display a learner's actual badge only after credential ownership and the official asset are verified. |

**Important palette correction:** the colors listed in the earlier visual-system tables are Certigo **proposed UI accent values**, not licenses or official logo palettes. In particular, the earlier `#4C3FB4` / `#7047EB` values are not the current GitHub Copilot palette published in its Brand Toolkit. Never apply Certigo gradients, shadow, tint, hierarchical symbol treatment or dark-mode recoloring to a third-party mark.

### SwiftUI vector pipeline: use official assets, do not trace logos

The request asked for exact `Path` coordinates for Microsoft four-square/Azure prism/Fabric ribbon/Security shield, GitHub/Copilot/branch marks, AWS smile/badge, Google Cloud, Kubernetes, HashiCorp, CompTIA and ISC2. **No vendor logo path coordinates are specified here on purpose.** The current authoritative sources supply (or direct to) official logo/icon assets and usage rules, not a reusable third-party SwiftUI-path license. Redrawing a path from a screenshot or approximating its silhouette would risk a visually inaccurate, unauthorized derivative and may suggest endorsement. The right way to be pixel-faithful is to use the exact authorized vector asset unchanged, not to invent coordinates.

Implementation handoff for each proposed asset:

1. Record the official asset's canonical URL, retrieval date, asset/version name, checksum, licensing/permission basis, allowed context, required attribution and clear-space rule in an asset manifest. A publicly downloadable SVG is **not automatically approved for third-party product UI**.
2. Use a provider-supplied SVG/approved vector variant, retaining its exact `viewBox`, geometry, brand colors and clear space. Add it as a non-template vector asset to the iOS asset catalog only after permission is confirmed. In SwiftUI render it with `Image("ProviderAssetName").resizable().scaledToFit()`; do not set `.template`, `foregroundStyle`, `.symbolRenderingMode`, opacity, blend modes, gradients, masks or shadows on the official artwork. If the provider only gives a specific PNG or badge image, display that supplied version unchanged at a legible size.
3. Keep the mark separate from Certigo branding: provider mark identifies a content issuer; Certigo remains the app/product identity. Do not create lockups by placing the two logos together unless an applicable co-branding guideline explicitly permits it.
4. If the exact asset, permission, clear-space, or appearance constraints cannot be documented, render the provider's **plain text name** and a Certigo-owned generic category shape. Do not substitute a traced logo or an SF Symbol that imitates it.

### Original Certigo learning token: normalized geometry, not an issuer mark

For the catalog, create a clearly Certigo-owned topic marker instead of fake vendor emblems or certification badges. This is the only vector geometry in this addendum. It is a generic six-sided learning tile with an open Prism diamond; it must be labelled by nearby provider/course text, must not contain “Certified”, an issuer logo, a star/rank, or an exam code on a medal/ribbon, and must not be presented as a credential.

Normalized source coordinates are in a `100 × 100` design box; map them proportionally into the destination rect. Outer polygon: `(50,4) → (90,27) → (90,72) → (50,96) → (10,72) → (10,27) → close`. Inner diamond: `(50,28) → (66,50) → (50,72) → (34,50) → close`; leave it unfilled/outlined so the motif reads as Certigo's own learning token, not a vendor icon. Keep the exam code in an independent text pill below/alongside the tile.

```swift
struct CertigoLearningToken: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + side * x / 100,
                    y: origin.y + side * y / 100)
        }

        return Path { path in
            path.move(to: point(50, 4))
            path.addLines([
                point(90, 27), point(90, 72), point(50, 96),
                point(10, 72), point(10, 27)
            ])
            path.closeSubpath()

            path.move(to: point(50, 28))
            path.addLines([point(66, 50), point(50, 72), point(34, 50)])
            path.closeSubpath()
        }
    }
}
```

Use the outer outline as a single small taxonomy accent, not as an earned award. For this original Certigo shape, provider tones can fill the background while the inner diamond stays a contrast-checked stroke; that coloration is an app-created category cue and is **not** to be called an official provider icon. Accessibility label/value comes from the adjacent actual content, e.g. “Azure AI Fundamentals, AI-901”; the shape itself is decorative (`accessibilityHidden(true)`).

### Credential, level, exam code: three separate semantics

- **Provider mark:** identifies who authored/offers the content. It is not an award and is not proof of affiliation. Gate any actual mark on permission; text name is the safe fallback.
- **Exam code pill:** plain typography (e.g. `AZ-900`, `AI-103`, `DP-600`, `GH-300`, `CLF-C02`, `SAA-C03`, `AIF-C01`) in a neutral pill. Render only codes present in the actual catalog; code examples do not establish that a track is available or that Certigo is endorsed by the issuer.
- **Learning level:** use a factual text value such as `Fundamentals`, `Associate`, `Expert` or `Specialty` only when that exact level is provider-authored catalog metadata. Do not infer three star tiers (`★`/`★★`/`★★★`) or a hierarchy shared across vendors: the credential systems are not semantically equivalent.
- **Certigo practice milestone:** if real mastery/achievement criteria are later implemented, create a distinct Certigo-owned progress mark. Label its state (`En cours`, `Terminé`, etc.) and define the criteria. Never call it an official certification, use an issuer badge silhouette, or imply the learner passed an external exam.
- **Official earned credential:** only display the original badge/artwork actually issued for the signed-in learner, after verifying the credential record and any current validity/expiry. Do not recolor, crop, add a Certigo ribbon, add stars, replace its link or regenerate its artwork. If the service cannot prove ownership, omit it. Link to the issuer/badge verification page when the credential provides one.

### References verified on 22 October 2026

- Microsoft [Trademark and Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks); Microsoft Learn [Access certificates, badges and transcript](https://learn.microsoft.com/en-us/credentials/certifications/access-certificates-badges-transcript).
- GitHub [Brand Toolkit: Logo](https://brand.github.com/foundations/logo); [GitHub Copilot brand guidance and palette](https://brand.github.com/brand-identity/copilot); [About GitHub Certifications](https://docs.github.com/en/get-started/showcase-your-expertise-with-github-certifications/about-github-certifications).
- AWS [Trademark Guidelines](https://aws.amazon.com/trademark-guidelines/); [AWS Certification Benefits and Digital Badges](https://aws.amazon.com/certification/benefits/).
- Google Cloud [official product icon library](https://cloud.google.com/icons) (official assets are for the documented purposes on that page; it is not a product-UI license).
- CNCF [Brand Guidelines](https://www.cncf.io/brand-guidelines/) and [official project artwork repository](https://github.com/cncf/artwork).
- ISC2 [Copyright Information and mark permissions](https://www.isc2.org/Policies-Procedures/Copyright-Information); [Digital Badges](https://www.isc2.org/certifications/digital-badges).
- HashiCorp and CompTIA official-logo permission details were **not verified** in this bounded pass (429/404 responses respectively); no asset is recommended for either until official guidance is accessible.

This is a bounded visual/permission review, not legal advice or a permission grant. Before shipping third-party marks inside Certigo, obtain and retain the applicable written permission/license or documented guideline allowing that exact use in a third-party mobile learning product.
