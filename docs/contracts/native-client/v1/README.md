# Native client HTTP fixtures

These synthetic public fixtures describe **existing** HTTP contracts, not new
endpoints, published content, certification claims, or a staging configuration.
`NativeClientWireFixtureTests` compares them with the real C# HTTP functions and
serializer. Swift tests should consume these same files rather than copy their
contents. Formatting and object property order are not part of this fixture
contract; JSON values, omitted keys, dates, enums and nulls are.

| Fixture | Existing route |
| --- | --- |
| `active-track-request.json` | `POST /api/me/active-track` request |
| `profile.json` | `GET /api/me` and the active-track response |
| `catalog.json` | `GET /api/catalog/tracks` |
| `path.json` | `GET /api/me/paths/demo-track` |
| `lesson.json` | `GET /api/tracks/demo-track/lessons/demo-lesson` |
| `quiz-submit-request.json` | `POST /api/quiz/demo-lesson/submit` request |
| `quiz-submit-result.json` | The same submission's response |
| `quiz-submit-correct-result.json` | A successful correction with nullable feedback |

All these routes require a validated learner bearer. Responses use
`application/json; charset=utf-8`. The synthetic versioned lesson has
`X-Content-Manifest-Id` and a quoted `ETag` equal to the request fixture's
`publicManifestId`. That all-zero digest is a test identifier, **not a downloadable
release**. It must never be used to activate or submit real content.

`matches` is omitted for the MCQ check and present for the matching check.
Other optional lesson-block fields are explicitly null. The catalog's
`sourceAsOf` and `freshness` are distinct; neither implies automatic expiration.
Status strings must be rendered according to the client's existing domain rules,
not treated as a complete enumeration inferred from one sample.

The lesson is answer-free. `correctAnswer` in the POST response is authorized
post-submission feedback, not a distributable answer-key bank. These fixtures do
not permit offline grading or optimistic XP/readiness awards. Preserve
`clientAttemptId` and `publicManifestId` on retries.

For a correctly graded item, `correctAnswer` is null. `nextReviewDueAt` may also
be null. The fixture tests exercise the HTTP shape, not a new scoring formula.
The request sample and the two response samples are independent serializer
vectors; do not use the alternative result to grade the sample's selections.
The current quiz service skips unknown submitted item IDs, so clients must not
invent a verdict for an answer absent from `results`.

Authentication, live issuer/audience/redirect URIs and staging availability need
their own evidence and approval. Do not infer them from these samples or run a
login against a shared browser/profile.

## Existing discovery, submission and resume

Select the catalog track's `id`, then discover lesson IDs from
`GET /api/me/paths/{trackId}` and fetch the exact returned lesson route.
`learningAvailable` is an availability summary, not proof that a particular
release is deployed or that a raw public question-bank file is submittable.

For imported versioned `questionBank` tracks, the production
`RuntimeContentProjector` creates one practice lesson per domain objective.
Its runtime track ID uses `legacyId` when present, otherwise the canonical ID;
the generated lesson is `{runtimeTrackId}.lesson.{objectiveId}.practice`.
Question/check and concept IDs likewise preserve their legacy ID when present,
otherwise their canonical ID; option IDs remain unchanged. These are server
projection rules, not permission for the client to fabricate lesson IDs.
Discover the projected path from the API. Public v3 choice text must first pass
the producer/backend schema adapter; it is not an alternative `AnswerDto`
encoding. Submit exact check IDs and selected option IDs from the served lesson.

The lesson response carries the version pin in `X-Content-Manifest-Id`/`ETag`,
not a `publicManifestId` body property. Copy that header into the submission's
`publicManifestId`; legacy lessons have no such pin. Historical pins resolve
the matching imported private answer key even if the active release changes.
This source contract does not establish any live import, flag or activation.

After submission, re-read the path for server-owned concept progress.
`completed` means all gradable concepts have a recorded review, not a perfect
score; an incorrect answer can complete a lesson while leaving low mastery.
The path contains no latest-attempt ID, selections or feedback, and there is
no latest-quiz-attempt GET route in this contract. An unfinished session is
restored from the client's owner-scoped local state. A submitted-but-unconfirmed
session retries the original payload/clientAttemptId/pin to recover the stored
result without crediting rewards again; do not submit a new attempt merely to
refresh progress. Cross-device restoration of unsubmitted local answers is
not provided by these routes.

`NativeLearningJourneyContractTests` exercises the real catalog/content/path/
quiz services with synthetic in-memory storage, including wrong-answer
completion, owner-isolated progress, idempotent retries and historical pinning.
`RuntimeContentProjectorTests` separately checks question-bank IDs/options and
public/private mapping. Neither is a live Cosmos/import/authentication test or
proof of persistent-store durability across process restarts.

## Active goal and private profile

The existing `UserFunctions` exposes `GET /api/me` and
`POST /api/me/active-track`. The GET **can provision a profile**; it is not a
read-only cloud probe. `UserService` selects only the authenticated owner's
profile. The returned `activeTrackId` can be null. Viewing catalog/path/old-goal
statistics does not select a goal or create an enrollment.

To select a goal, submit `{ "trackId": "<published runtime track ID>",
"expectedTrackId": "<last observed active track ID, or null>" }`.
Do not substitute a certification slug for the runtime track ID from discovery.
The service trims/lowercases request IDs, resolves the currently published
track, and uses profile ETag concurrency:

| Condition | Existing behavior |
| --- | --- |
| Target track is absent | 404 `Track not found`; no profile selection |
| Current goal already equals target | 200 profile, no write, even if expected goal is stale |
| Current goal equals expected | Persist selection and return 200 profile |
| Current goal differs from both target and expected | 409 `Active track conflict`; do not overwrite another device's choice |
| Concurrent unrelated profile update | Re-read and retry while preserving the other update |

After an uncertain response, retry the **same selection and expected goal**.
After a real 409, re-read the profile and let the learner decide; do not silently
replace `expectedTrackId` to force a switch. This is conditional selection, not
a new `clientAttemptId` API or a saved multi-goal enrollment list.
Progress remains keyed by owner and track independently of the active goal.
Retrying an older track's pending quiz may update that track's progress, but
does not change the selected goal.

`active-track-request.json` and `profile.json` are additional synthetic serializer
vectors; the existing learning fixtures remain unchanged. The profile matches
the existing private wire projection, including nullable optional fields.
Internal economy receipts, legacy operation journals and identity metadata are
omitted by `HttpExtensions`, even when present in storage. It is **not** a public
friend profile or permission to share the learner's results.
`UserServiceTests` verifies a real write followed by an idempotent retry,
concurrent goal conflicts, reward preservation and owner isolation.
`NativeLearningJourneyContractTests` connects selection to the existing loop and
checks owner-scoped feedback even when two accounts use the same client attempt ID.
HTTP fixture/error tests use the real Functions serializer/middleware but fake
services, not a running authenticated host or persistent Cosmos.

## Coach and Social integration boundaries

These source surfaces are not substitutes for the new four-tab product contracts.
Keep native Coach/Social shells unavailable until their contracts and safeguards
are approved; no provider, feature flag, endpoint or data retention is changed here.

| Existing implementation | Real boundary | Missing prerequisite for the target |
| --- | --- | --- |
| `TutorFunctions`: `POST /api/tutor/explain`; `TutorExplainRequest(trackId, lessonId, itemId, selected, publicManifestId?)` | `TutorService.ExplainAsync` reads a private key, builds feedback, reads/writes caller-scoped `LearnerModel` and emits `tutor.explained`. Versioned content requires a manifest pin. It does **not** verify a confirmed quiz attempt before reading/composing the explanation. | Separate pre-submission guidance from authorized post-submission feedback. Establish ownership/attempt/pin authorization before using this route for Coach; do not infer authorization from item ID, selected answers or authentication alone. |
| `Program.cs`: `TUTOR_LLM_ENABLED` | False selects `NullTutorCompletion`, not a disabled tutor HTTP surface. Grounded explanation and learner-model writes still run. `TutorPromptBuilder` currently includes solution context. | No LLM enablement or answer-key export. A future provider/context contract must exclude private solution data and define cancellation, partial generations, retries and confirmation before mutations. |
| `ILearnerModelRepository` | Per-owner/per-track concept statistics, not conversation transcripts or explicit saved preferences. | Define history, editable memory and authoritative learning records separately, including retention/deletion without rebuilding deleted memory from history. This requires a reviewed persistence/privacy contract, not additional guessed routes. |
| `FriendFunctions`: `GET/POST /api/friends`, `DELETE /api/friends/{friendId}`, `GET /api/friends/leaderboard` | `FriendService.AddByHandleAsync` writes both friendship edges immediately; no invitation acceptance. List exposes display name, handle, avatar, level, streak and XP; leaderboard ranks XP. | Consent/invite state, per-field visibility/discoverability, block/report/moderation and removal semantics before connecting the new Social UI. No private readiness, mistakes, results or conversations may be inferred as shareable. |
| `OrganizationFunctions`: `/api/v1/organizations/.../teams` and membership routes | Enterprise organization membership/roles, not informal friend teams. `OrganizationFeatureOptions.HttpSurfaceEnabled` is false in **both** supported `Off` and `Shadow` modes; the functions return feature-disabled 404. | A separate friendly-team authorization/ownership contract, including last-owner departure, or an explicitly approved enterprise-only UI. Do not enable or relabel enterprise authority as ordinary team membership. |

`SocialServices.cs`, `TutorService.cs`, `TutorDtos.cs`, `SocialDtos.cs`,
`OrganizationAbstractions.cs` and the corresponding Functions are the source
references for this boundary. Route presence alone proves neither product
readiness nor deployed availability. No conversation CRUD, clear-memory,
friend-invite acceptance, block/report or informal-team API is supplied by
these fixtures. Missing contracts must be proposed before schema/service/
retention changes, not filled with synthetic user history or fake relationships.
