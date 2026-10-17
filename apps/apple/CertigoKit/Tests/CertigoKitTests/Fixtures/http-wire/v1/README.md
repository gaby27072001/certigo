# Native client HTTP fixtures

These synthetic public fixtures describe **existing** HTTP contracts, not new
endpoints, published content, certification claims, or a staging configuration.
`NativeClientWireFixtureTests` compares them with the real C# HTTP functions and
serializer. Swift tests should consume these same files rather than copy their
contents. Formatting and object property order are not part of this fixture
contract; JSON values, omitted keys, dates, enums and nulls are.

| Fixture | Existing route |
| --- | --- |
| `catalog.json` | `GET /api/catalog/tracks` |
| `path.json` | `GET /api/me/paths/demo-track` |
| `lesson.json` | `GET /api/tracks/demo-track/lessons/demo-lesson` |
| `quiz-submit-request.json` | `POST /api/quiz/demo-lesson/submit` request |
| `quiz-submit-result.json` | The same submission's response |
| `quiz-submit-correct-result.json` | A successful correction with nullable feedback |
| `active-track-request.json` | Explicit `POST /api/me/active-track` request |
| `profile.json` | Authoritative profile from `GET /api/me` or active-track selection |

## Backend parity evidence

At Certigo `main` base `3b305a4093fdaba8f8cc4595ac78810c58ae38f9`,
`NativeClientWireFixtureTests` (blob `39b1730bc0002899a95e372291d2c03bb02af0d8`)
invokes the real active-track and profile functions and compares only
`active-track-request.json` and `profile.json` with their serialized responses.
Those two fixture bytes match the backend-owned contract files at
`ecbfb054f2474bc430856b72fd55d66a03f6e9fb`.

The other six files are historical synthetic Swift wire-shape vectors from
native source commit `3339685c1ea571971875041ddbcf3d23471b3c76`. Their Git blob
SHA-1s identify the exact historical bytes; they are decoded by Swift tests but
are not compared with real C# function output by the backend fixture test at
that base:

| Fixture | Historical Git blob SHA-1 |
| --- | --- |
| `catalog.json` | `0860553b5a2a145c3b74b712d274d2fcd87c89fc` |
| `path.json` | `bc1efaf3fcfbd60c8b0d137f4c316e0324067996` |
| `lesson.json` | `319765ebe944cdb2b44e3e5bddcab02421ffaa33` |
| `quiz-submit-request.json` | `ca93fa499a46c9606ba9555155b29fcdfd5c3ae3` |
| `quiz-submit-result.json` | `d728c9f655fa8ab166d0ca984f777f2c97833abb` |
| `quiz-submit-correct-result.json` | `8385c88f8db355a7ca1c0915d01c42fecb78c599` |

Do not describe those six vectors as current backend parity or as exercised by
the current C# fixture test. Their historical blob identity proves which bytes
were reviewed, not which server implementation produced them.

The two active-goal vectors are pinned to backend revision
`ecbfb054f2474bc430856b72fd55d66a03f6e9fb`. Selection sends `trackId` and nullable
`expectedTrackId`; no client ETag/If-Match is required. A 409 requires reloading
the profile before a new explicit decision, not rewriting the expected goal and
automatically forcing the request. An uncertain retry keeps the original body:
the server succeeds idempotently if that goal is already current. Browsing a
path does not choose a goal. `GET /api/me` can provision a profile and is not a
read-only live probe; these fixtures authorize no real request.

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
