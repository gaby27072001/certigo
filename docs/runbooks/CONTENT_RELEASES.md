# Backend content releases

The backend imports the two immutable artifacts produced by `certigo-content` without
mixing their access boundaries:

| Package | Required manifest channel/artifact | Cosmos container |
|---|---|---|
| Public questions | `public` / `public` | `content-public` |
| Private solutions | `answerKey` / `private` | `content-private` |

Release metadata and the `staging` / `prod` pointers live in `content-releases`. The
public manifest ID is the release ID; its record also binds the corresponding private
manifest ID. Each package is partitioned by its own manifest ID, so concurrent imports
cannot overwrite a differently hashed private package. Retries upsert the same
hash-addressed IDs, while promotion only changes a small pointer document.

## Import contract v1

`POST /api/admin/content/releases/import` uses Azure Functions
`AuthorizationLevel.Function` and therefore requires a function key. Its body is:

```json
{
  "contractVersion": "certigo.backend.content-release-import/v1",
  "public": {
    "manifest": {},
    "files": [{ "path": "questions/example.json", "content": {} }]
  },
  "private": {
    "manifest": {},
    "files": [{ "path": "solutions/example.json", "content": {} }]
  }
}
```

Each manifest must use `certigo.content.package-manifest/v1`, `sha256`, and
`json-sorted-keys-compact-utf8-lf`. Before the first Cosmos write, the backend:

1. Recomputes each canonical payload's SHA-256 and byte size.
2. Recomputes the manifest root hash without `manifestId` and `rootHash`.
3. Rejects missing, extra, duplicate, unsafe, or mismatched files and item IDs.
4. Requires the public and private item ID sets to match.
5. Recursively rejects `answerKey`, `correct`, and `rationale` from public JSON.

A successful new import activates the release in `staging`, preserving the prior
staging ID as N-1. Re-importing the same public/private manifest pair is a no-op.

## Promotion and rollback

Promote the exact active staging release to production:

```http
POST /api/admin/content/releases/{publicManifestId}/promote
x-functions-key: <deployment secret>
```

Rollback an environment to its exact N-1 release:

```http
POST /api/admin/content/releases/{publicManifestId}/rollback
x-functions-key: <deployment secret>
Content-Type: application/json

{"environment":"staging"}
```

`environment` accepts `staging` or `prod`. Rollback swaps active and previous IDs;
it never deletes imported artifacts. Requests for any release other than N-1 return
`409 Conflict`.

Learner clients authenticate normally and can read only the active production public
manifest:

```http
GET /api/content/manifest
Authorization: Bearer <learner token>
```

No private package endpoint exists. Import, promotion, rejection, and rollback emit
the Application Insights events `content.release.import`,
`content.release.promotion`, `content.release.rejection`, and
`content.release.rollback`.

## Deployment handoff

Deploy the updated Bicep before invoking the importer so the three release containers
exist. The publishing automation must download the exact immutable artifacts named
`certigo-content-public-sha256-<rootHash>` and
`certigo-content-private-sha256-<rootHash>`, build the v1 request above, and keep the
private artifact unavailable to every mobile job.
