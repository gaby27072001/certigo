# Public question preview preparation

This independent source lot prepares three real, read-only public samples.
It is **not wired into the app**, an Xcode target, or CertigoKit. The app source
at `a1e654702720832d4c37e0d3376d4f097a58ee62` is unchanged while the owner
collects logs for the unknown GUI Run failure. A reported successful simulator
build is not evidence of a successful launch or rendered UI.

## Provenance and bytes

The small `Fixtures` suite was copied as exact Git blobs from
`gaby27072001/certigo-content`, revision
`222a00f95ef679ac9705c8b8484fad73739e5bb1`,
`test/fixtures/apple-ui/v1/`. Its editorial source is
`e60aba76b5b84677c4f891fb8dd660cdf8d3202c`.
The upstream README and index are preserved, not rewritten.

Each of the Microsoft AZ-104, AWS AIP-C01, and Google Cloud Machine Learning
Engineer samples contains its question, public compiler check, and track,
domain, and concept resources. The index records exact LF package-file bytes,
SHA-256 and size, plus the canonical body without the final LF. No corpus copy,
answer keys, private corrections, score, or feedback was imported.

This suite's index is fixture provenance, **not** an active release manifest.
Its practice-lesson mapping is observed compiler output, **not** live backend
discovery. No client derives question, option, concept, lesson, or session IDs.

## Read-only projection

`PublicQuestionPreview.decode` reuses the existing CanonicalQuestionReader
for canonical schema/capability validation. It closes the compiler-check
shape, rejects unknown/private fields and unsupported capabilities, preserves
the full prompt and labels byte-for-byte, and checks option uniqueness.
Compiler option IDs are opaque: real GCP output includes consecutive hyphens;
the canonical v4 option-slug rule cannot be imposed on a v3 compiler projection.
The fixture index/hash checks anchor their exact values.

The projection has no selections, submit method, correction, readiness, reward,
progression, API call, account, cache, or persistence. Resource validation
reuses PublicResourceReader without changing package interfaces.

## Console validation

Use the existing Swift 6.2.3 Linux toolchain and an already built external
Swift Crypto directory (containing `Modules` and Crypto object subdirectories):

```bash
swift format lint --configuration apps/apple/.swift-format --strict \
  apps/apple/PublicQuestionPreview/PublicQuestionPreview.swift \
  apps/apple/PublicQuestionPreview/Tests.swift
bash apps/apple/PublicQuestionPreview/run-tests.sh /absolute/path/to/existing/crypto/debug
```

The runner compiles the repository's existing readers with this isolated
console harness. It only **reads** external Crypto modules/objects; it does
not run SwiftPM or mutate another worktree's scratch. The temporary executable
is deleted after the run. The existing Linux linker may report an RWX segment
warning; Swift compiler warnings are treated as errors.

Coverage includes all 15 payload file/body hashes and LF, public-resource
validation, exact IDs/prompts/labels, AWS stem over 1,000 characters and long
options, French diacritics, malformed/unknown/private projection fields,
unsupported capability/schema, duplicate options and altered prompt/labels.
This is not an Apple build, XCTest, runtime, screenshot, or overflow proof.

## Next boundary

After diagnosing the GUI Run error, a separately coordinated UI change can
render these samples read-only with wrapping text, Dynamic Type, and semantic
opaque surfaces. It must keep this public-content view distinct from the
synthetic question/mock explanation journey. Wiring resources or a new source
requires Xcode inclusion coordination; nothing is silently added here.
