# Certigo content block schemas — v2

Canonical, versioned **JSON Schema (draft 2020-12 / AJV-compatible)** for lesson
content blocks. This is the portable, language-neutral source of truth for the
canonical block catalogue delivered by work-package **wp-p1-02**.

## Files

- [`block.schema.json`](./block.schema.json) — one consolidated schema. The
  envelope requires `type` + `data`; a `oneOf` dispatch on the `type` const
  selects the per-type `data` shape (declared under `$defs/data_*`).

## Versioning (two axes)

- **`x-contentSchemaVersion: 2`** — the *content-schema generation* (this folder
  is `v2`).
- **`schemaVersion`** (a.k.a. `schema` / `version`) — the *renderer contract*
  version a block targets, coherent with the wp-p1-01 `RendererSchema`
  (`packages/prism_ui/lib/src/rendering/content_block.dart`). Accepted forms:
  a positive integer, a bare integer string (`"1"`), or the wire tag
  `renderer/N` (e.g. `renderer/1`).

## Canonical block types (13)

`hero`, `concept`, `example`, `diagram`, `quiz.multipleChoice`,
`quiz.trueFalse`, `quiz.matching`, `scenario`, `caseStudy`, `labStep`,
`aiTutorPrompt`, `examQuestion`, `summary`.

`quiz.*` is expanded into three canonical sub-types
(`multipleChoice`, `trueFalse`, `matching`).

> The canonical **schema** names intentionally diverge from the renderer keys
> currently wired in `standard_renderers.dart` (`hook`, `concept`, `example`,
> `code`, `recap`, `callout`). This work-package defines the canonical content
> *schemas*, not a renderer rewiring.

## Reserved: `tenantId` (Partie 28 — future B2B boundary)

The envelope reserves an optional `tenantId` string. It is **reserved, not
implemented**: renderer v2 accepts but does **not** consume it. No B2B logic is
introduced here — the field only reserves the name for a future multi-tenant
boundary.

## Dart mirror & drift protection

The dependency-free Dart catalogue + validator lives in
`packages/prism_ui/lib/src/rendering/content_schema.dart` and mirrors this file.
A hermetic coherence test
(`packages/prism_ui/test/rendering/content_schema_test.dart`) loads this JSON and
asserts, per type, that the `data.required` arrays match the Dart catalogue, that
`oneOf` covers all 13 types, and that `tenantId` stays reserved — keeping the two
representations in lock-step.

## Intended use

This JSON artifact is kept portable for AJV-based validation in future CI
(wp-p1-06). It is **not** registered as a Flutter asset; the coherence test reads
it from disk via `dart:io`.
