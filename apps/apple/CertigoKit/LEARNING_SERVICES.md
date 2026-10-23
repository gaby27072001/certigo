# Native learning services

The package exposes the existing authenticated backend contracts; it does not
create a new service or change scoring, rewards, scheduling or identity rules.
`LearningClient` is an actor. Every new method captures its credentials and rejects
a response if the active session generation changed while awaiting it.

| Client method | Backend route |
| --- | --- |
| `explainAnswer(_:)` | `POST /api/tutor/explain` |
| `nextBestRecommendations(trackId:)` | `GET /api/me/recommendations/{trackId}` |
| `generateMockExam(_:)` | `POST /api/exam/generate` |
| `submitMockExam(_:)` | `POST /api/exam/submit` |
| `achievements()` | `GET /api/achievements` |
| `quests()` | `GET /api/quests` |
| `notificationPlan()` | `GET /api/me/notifications/plan` |
| `notificationSettings()` | `GET /api/me/notifications/settings` |
| `updateNotificationSettings(_:)` | `POST /api/me/notifications/settings` |

`CertigoAPI` supplies corresponding methods with an explicit `credentials:`
argument. All require an `/api` base URL, not `/api/v1`. DTOs follow
`TutorDtos.cs`, `ExamDtos.cs`, `RecommendationDtos.cs`, `GamificationDtos.cs` and
`NotificationDtos.cs`. Backend `DateOnly` values stay ISO calendar date strings;
`DateTimeOffset` values use the existing API date codec. Nullable fields remain
optional. Backend text, including recommendation reasons and tutor prose, is not
translated by the interface catalog.

Tutor calls preserve the public content manifest pin when supplied; the backend
requires it for versioned content. This endpoint updates the learner model and
records an event. It is not a side-effect-free preview or a generic free-form chat,
and has no client-generated idempotency key. Do not automatically replay it as if
it were an offline quiz submission. Exam submissions carry the caller's stable
`clientAttemptId`; preserve the same request on an ambiguous retry. Exam requests
are not added to the lesson submission outbox by this package. An empty exam is a
valid backend response and should be shown as unavailable, not started with a
fabricated timer. Unsupported question types are rejected explicitly because
the current native renderer supports MCQ only.

Notification settings are full replacements and the server remains authoritative
for normalization and scheduling. Reading a plan does not authorize local delivery.
The package does not request OS permissions, subscribe the user, schedule local
notifications, claim rewards or perform purchases.

## Local review and focus evidence

`SmartReviewAdvisor.recommend(path:history:localResults:)` uses the caller's current
owner/track-scoped confirmed history. It ignores foreign tracks, locked lessons
and zero-answer attempts. It deduplicates attempts and uses the latest dated
result per lesson, not a lifetime worst result. Two distinct most-recent imperfect
attempts prioritize recurring errors; otherwise it selects the lowest current
imperfect score, an in-progress unit, then an available unattempted lesson's unit.
Ties retain path order. This is a local navigation hint, not a replacement for
server recommendations, mastery scoring or FSRS due dates.

`SmartReviewLocalResult` admits only validated, acknowledged corrections. Its
caller must filter owner, API scope and track first. It has no invented timestamp
and never supersedes dated server evidence for the same lesson or establishes
recurrence. Pending/failed submissions are not grades.

`SkillBand` uses the requested boundaries: strong at 80-100, developing at 55-79,
weak at 0-54. `MasteryStage` is a conservative display projection of supplied
normalized evidence: all zero means not started; incomplete coverage means
learning; full coverage with incomplete mastery means practicing; full coverage
and mastery means mastered, and only an additional score of 100 yields exam ready.
These are presentation labels, not a new readiness formula or a prediction of
passing a real certification. They must not be inferred from completion alone.
Invalid/non-finite inputs throw rather than becoming a reassuring default.

`FocusArea` accepts explicit domain coverage/mastery/score evidence and server
recommendations with matching track identity. It chooses the lowest domain score
(then mastery, then ID) and an explicitly mapped unlocked recommendation. Duration
comes only from that recommendation. If no mapping exists, unit and duration stay
unavailable. `ReadinessSnapshot` and `DomainReadinessSummary` can hold supplied
evidence; they are not backed by an invented HTTP readiness endpoint.

The actual path DTO exposes domain scores, unit domain/status and lesson mastery,
but no domain coverage/mastery fractions. These additive fields, profile
level/streak/daily goals, and catalog-declared languages are optional to preserve
older fixtures and distinguish missing evidence from zero. A domain score or
catalog language list is not proof of lesson completion, exam readiness or the
language of every individual question.

## Study plan and interface copy

`CertigoStudyPlanPreference` persists target date, initial level and a positive
daily minute goal through injected `UserDefaults`. Its default key is device-wide.
For a certification-specific plan, supply `key:` scoped to owner, API and track;
remove that key when purging the corresponding account. Missing state returns
nil; corrupt storage throws. This is a local preference, not cloud sync or a
preparation-time prediction.

`AppInterfaceCopy.Key` includes the secondary radar, content-language, review,
coach, mastery, focus, onboarding and notification labels in all eight supported
languages. Rendering and reactive language selection remain the app's job.
Translated chrome does not translate source course/question text or server prose.

Portable tests cover codecs, route/method/body contracts, session-generation
races, recommendation evidence and boundaries, scoped preference persistence and
all translation keys. They do not prove Apple SDK compilation, device behavior,
notification delivery, live backend availability or a professional linguistic
review.
