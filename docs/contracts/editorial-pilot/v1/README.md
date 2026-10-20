# Editorial pilot API V1

This authenticated contract distributes a versioned public editorial pilot and
stores only owner-scoped lesson access plus an explicit self-declaration that a
lesson was read. It is separate from certification content and quiz submission.
It does not accept or persist free-form answers and does not produce scores,
mastery, readiness, XP, rewards or certifications.

The initial source is the exact public blob
`gaby27072001/certigo-content@c8b13a86fa1cc5917bbfd795f5404727ea732505:editorial/pilots/responsible-ai-assistants.json`.
The backend embeds those source bytes; the response digest is computed from the
bytes served. The native client verifies that digest before decoding or showing
the content. The package remains labelled `draft` and its `asOf` value is the
source review date, not a claim of currentness.

## Operations

| Operation | Route | Effect |
| --- | --- | --- |
| Read pilot | `GET /api/pilots/{pilotId}/content` | Returns exact JSON bytes and `X-Certigo-Pilot-Content-Digest`; does not provision a profile. |
| Read history | `GET /api/me/pilots/{pilotId}/history/{contentDigest}` | Reads only the authenticated owner's history for that exact source version. An empty result is not persisted. |
| Record access | `POST /api/me/pilots/{pilotId}/lessons/{lessonId}/access/{contentDigest}` | Upserts one record per lesson and version; a later open advances last-accessed time but never declares the lesson read. |
| Mark read | `POST /api/me/pilots/{pilotId}/lessons/{lessonId}/read/{contentDigest}` | Explicit, idempotent self-declaration. No free-text response is accepted. |

All operations require a valid bearer token. Every owner comes from that token;
there is no owner, user, person or account identifier in the request. Invalid
pilot IDs, lesson IDs and stale content digests are not recorded. History
documents use the existing `progress` container, owner partition and account
deletion barriers, with a discriminator that excludes them from certification
mastery queries. No Cosmos container, partition key, infrastructure resource or
identity behavior is changed.

History is keyed by the exact content digest. A changed digest yields a new,
unread version and does not rewrite older version records. The UI labels the
read marker as self-declared; opening, reading, practice prompts and feedback
are not evidence of mastery.

`ApiSurfaceContractTests` compares all four routes with the actual Functions.
Focused API, service, source-byte and native transport tests use synthetic
identities and responses only. They do not call a real sign-in flow or a live
`/me` endpoint.
