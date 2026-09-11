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

### L'ampleur de cette divergence — mesurée

La note ci-dessus dit que la divergence est délibérée, ce qui reste vrai. Elle
n'en donnait pas la taille, et la taille change ce qu'on en fait. Mesuré sur cet
arbre, en croisant `CanonicalBlockType.values` et
`standardRendererRegistry().registeredTypes` :

| | |
| --- | --- |
| types canoniques | **13** |
| types réellement peints | **6** |
| intersection | **2** (`concept`, `example`) |
| canoniques sans renderer | **11** |
| peints hors catalogue | **4** |

La divergence va dans les **deux sens**, et chacun a une conséquence visible :

- **11 types canoniques n'ont aucun renderer.** Un contenu valide au regard de
  `block.schema.json` se peint en `PrismBlockFallback(unknownType)` : il passe
  la validation et n'apparaît pas.
- **4 types peints ne sont pas canoniques.** Ils s'affichent correctement mais
  `ContentBlockValidator` les rejette en `unknownType` : un pipeline
  d'ingestion qui validerait le contenu supprimerait des blocs que
  l'application sait pourtant peindre.

`standardRendererRegistry()` est l'unique registre de production — référencé par
`apps/mobile/lib/features/lesson/application/lesson_renderer.dart`.

### La garde à cliquet

`packages/prism_ui/test/rendering/content_render_coverage_test.dart` épingle ces
cinq ensembles. Il ne corrige rien : câbler les 11 types manquants est un
travail de rendu, avec ses goldens. Il rend l'écart **visible et ratché**.

Ajouter un type canonique sans renderer fait rougir ; ajouter un renderer fait
rougir aussi, et l'auteur met à jour l'épingle en réduisant l'écart. Dans les
deux cas la divergence devient un acte délibéré, jamais un silence.

C'est ce qui manquait entre les deux briques portables : chacune décrit sa
moitié du contrat de contenu, et rien ne vérifiait qu'elles parlent du même
objet.

### Ce qui reste à faire pour un rendu natif fidèle

Le schéma décrit la **validité** d'un payload, pas son **rendu**. Pour qu'une
app native peigne un bloc comme Flutter le peint, trois choses manquent encore,
par difficulté croissante :

1. **Le socle** : 11 types sur 13 n'ont pas de rendu de référence, même en
   Dart. Il n'y a donc rien à porter — c'est du rendu à concevoir, pas à
   traduire.
2. **La correspondance type → traitement visuel.** Pour les 6 types peints,
   elle n'existe que comme code exécutable (`standard_renderers.dart`) et comme
   images (`test/rendering/goldens/*.png`). Un PNG n'est pas portable : il
   atteste un résultat sans énoncer la règle. Un `callout` de sorte `warning`
   emprunte le rôle `warning` du thème, mais rien ne l'écrit hors du Dart.
3. **La normalisation des valeurs libres.** `_calloutKind` accepte
   `warning|warn|pitfall|danger` pour une même sorte. Cette tolérance vit
   uniquement dans le renderer ; une plateforme native qui ne la reproduit pas
   affichera un `pitfall` en `info`. Le schéma ne contraint pas `kind`.


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
