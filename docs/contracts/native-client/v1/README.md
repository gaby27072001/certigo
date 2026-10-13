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
