# Runtime public content API v1

This contract exposes the active public package manifest and immutable files to
authenticated learners. The active response adds `releaseId` as API metadata;
it does not alter the canonical package-manifest hash inputs.

File downloads are pinned by `releaseId`, `publicManifestId`, declared SHA-256
and canonical relative path. The backend reads only the public Blob container
through the existing external reader UAMI. It never resolves private manifests,
solutions or answer keys.

`CONTENT_REPOSITORY_MODE=legacy` remains the default. In that mode the new file
route returns the same generic 404 used for invalid bindings and performs no
content-storage read or release-service activation. Range requests are
explicitly refused with a non-cacheable 416. Conditional requests accept weak,
wildcard and comma-separated `If-None-Match` validators and preserve the pinned
identity headers on 304 responses.
