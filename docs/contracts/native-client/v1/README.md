# Native active-goal HTTP fixtures

These two synthetic public fixtures describe existing endpoints, not new APIs,
published content or deployed availability. They preserve the exact Git blobs
from `ecbfb054f2474bc430856b72fd55d66a03f6e9fb` consumed by the native client.

| Fixture | Existing route |
| --- | --- |
| `active-track-request.json` | `POST /api/me/active-track` request |
| `profile.json` | `GET /api/me` and the active-track response |

## Active goal and private profile

`GET /api/me` **can provision a profile**; it is not a read-only cloud probe.
`UserService` selects only the authenticated owner's profile. The returned
`activeTrackId` can be null. Viewing catalog/path/old-goal statistics does not
select a goal or create an enrollment.

To select a goal, submit `{ "trackId": "<published runtime track ID>",
"expectedTrackId": "<last observed active track ID, or null>" }`.
Use the runtime track ID returned by discovery, not an invented certification
slug. The service trims/lowercases request IDs, resolves the currently published
track, and uses profile ETag concurrency internally. No client `If-Match` header
is required by this route.

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

The profile fixture matches the existing private HTTP projection, including
nullable optional fields. Internal economy receipts, legacy operation journals
and identity metadata are omitted by `HttpExtensions`, even when present in
storage. It is **not** a public friend profile or permission to share results.

`UserServiceTests` verifies a real write followed by an idempotent retry,
concurrent goal conflicts, reward preservation and owner isolation.
`NativeLearningJourneyContractTests` exercises the real catalog/content/path/
user/quiz services with synthetic in-memory repositories, including selection,
wrong-answer completion, unchanged current goal during an older-goal retry and
owner-scoped feedback with the same client attempt ID in two accounts.
The attempt/event doubles use Cosmos's `(userId, id)` uniqueness boundary.
HTTP fixture/error tests use the real Functions serializer/middleware but fake
services, not a running authenticated host or persistent Cosmos.

## Coach and Social integration boundaries

Keep native Coach/Social shells unavailable until their contracts and safeguards
are approved; no provider, feature flag, endpoint or data retention is changed here.

| Existing implementation | Real boundary | Missing prerequisite for the target |
| --- | --- | --- |
| `TutorFunctions`: `POST /api/tutor/explain`; `TutorExplainRequest(trackId, lessonId, itemId, selected, publicManifestId?)` | `TutorService.ExplainAsync` reads a private key, builds feedback, reads/writes caller-scoped `LearnerModel` and emits `tutor.explained`. Versioned content requires a manifest pin. It does **not** verify a confirmed quiz attempt before reading/composing the explanation. | Separate pre-submission guidance from authorized post-submission feedback. Establish ownership/attempt/pin authorization before using this route for Coach; do not infer authorization from item ID, selected answers or authentication alone. |
| `Program.cs`: `TUTOR_LLM_ENABLED` | False selects `NullTutorCompletion`, not a disabled tutor HTTP surface. Grounded explanation and learner-model writes still run. `TutorPromptBuilder` currently includes solution context. | No LLM enablement or answer-key export. A future provider/context contract must exclude private solution data and define cancellation, partial generations, retries and confirmation before mutations. |
| `ILearnerModelRepository` | Per-owner/per-track concept statistics, not conversation transcripts or explicit saved preferences. | Define history, editable memory and authoritative learning records separately, including retention/deletion without rebuilding deleted memory from history. This requires a reviewed persistence/privacy contract, not guessed routes. |
| `FriendFunctions`: `GET/POST /api/friends`, `DELETE /api/friends/{friendId}`, `GET /api/friends/leaderboard` | `FriendService.AddByHandleAsync` writes both friendship edges immediately; no invitation acceptance. List exposes display name, handle, avatar, level, streak and XP; leaderboard ranks XP. | Consent/invite state, per-field visibility/discoverability, block/report/moderation and removal semantics before connecting the new Social UI. No private readiness, mistakes, results or conversations may be inferred as shareable. |
| `OrganizationFunctions`: `/api/v1/organizations/.../teams` and membership routes | Enterprise organization membership/roles, not informal friend teams. `OrganizationFeatureOptions.HttpSurfaceEnabled` is false in **both** supported `Off` and `Shadow` modes; the functions return feature-disabled 404. | A separate friendly-team authorization/ownership contract, including last-owner departure, or an explicitly approved enterprise-only UI. Do not enable or relabel enterprise authority as ordinary team membership. |

`SocialServices.cs`, `TutorService.cs`, `TutorDtos.cs`, `SocialDtos.cs`,
`OrganizationAbstractions.cs` and the corresponding Functions are the source
references for this boundary. Route presence alone proves neither readiness nor
deployment. No conversation CRUD, clear-memory, friend-invite acceptance,
block/report or informal-team API is supplied by these fixtures. Propose missing
contracts before schema/service/retention changes; do not fill gaps with fake
history or relationships.
