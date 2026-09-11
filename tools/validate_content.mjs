// Validates Certigo content-as-code against the JSON schemas.
//
//   node tools/validate_content.mjs
//
// Walks content/<track>/track.yaml and content/<track>/lessons/*.lesson.yaml,
// validates each against content/schema/*.schema.json, and cross-checks
// referential integrity (every lesson referenced by a track exists, domain ids
// match, domain weights sum to 1.0). Exits non-zero on any problem so CI fails.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import Ajv from 'ajv';
import addFormats from 'ajv-formats';
import { parse } from 'yaml';
import { globSync } from 'glob';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const readJson = (p) => JSON.parse(readFileSync(path.join(root, p), 'utf8'));
const readYaml = (p) => parse(readFileSync(p, 'utf8'));

const ajv = new Ajv({ allErrors: true, strict: false });
addFormats(ajv);
const validateTrack = ajv.compile(readJson('content/schema/track.schema.json'));
const validateLesson = ajv.compile(readJson('content/schema/lesson.schema.json'));

const errors = [];
const fail = (file, msg) => errors.push(`✗ ${path.relative(root, file)}: ${msg}`);
const catalog = [];

/// Every exercise type actually exercised by an authored item, filled as the
/// corpus is walked and compared to the schema enum by the diversity ratchet.
const usedItemTypes = new Set();

export function validateCatalogMembership(entries) {
  const integrityErrors = [];
  const lessonOwners = new Map();
  const itemOwners = new Map();
  const add = (file, message) => integrityErrors.push({ file, message });

  for (const { trackFile, track, lessons } of entries) {
    const lessonsById = new Map();
    for (const { file, lesson } of lessons) {
      const lessonKey = lesson.id.toLowerCase();
      const priorLesson = lessonOwners.get(lessonKey);
      if (priorLesson) {
        add(file, `DUPLICATE_LESSON_ID: lesson "${lesson.id}" is also declared in ${priorLesson}`);
      } else {
        lessonOwners.set(lessonKey, file);
      }
      if (lessonsById.has(lessonKey)) {
        add(file, `DUPLICATE_LESSON_ID: lesson "${lesson.id}" is declared more than once in track "${track.id}"`);
      } else {
        lessonsById.set(lessonKey, { file, lesson });
      }

      for (const block of lesson.blocks) {
        const item = block.check;
        if (!item) continue;
        const itemKey = item.id.toLowerCase();
        const priorItem = itemOwners.get(itemKey);
        if (priorItem) {
          add(file, `DUPLICATE_ITEM_ID: item "${item.id}" is also declared in ${priorItem}`);
        } else {
          itemOwners.set(itemKey, file);
        }
      }
    }

    const references = new Map();
    for (const unit of track.units) {
      for (const lessonId of unit.lessons) {
        const lessonKey = lessonId.toLowerCase();
        references.set(lessonKey, (references.get(lessonKey) ?? 0) + 1);
        const entry = lessonsById.get(lessonKey);
        if (!entry) {
          add(trackFile, `unit ${unit.id} references missing lesson "${lessonId}"`);
          continue;
        }
        if (entry.lesson.id !== lessonId) {
          add(trackFile, `unit ${unit.id} must reference lesson id "${entry.lesson.id}" with exact casing`);
        }
        if (entry.lesson.unitId !== unit.id) {
          add(trackFile, `lesson ${lessonId}.unitId "${entry.lesson.unitId}" != unit "${unit.id}"`);
        }
        if (entry.lesson.domainId !== unit.domainId) {
          add(trackFile, `lesson ${lessonId}.domainId "${entry.lesson.domainId}" != unit domain "${unit.domainId}"`);
        }
      }
    }

    for (const [lessonKey, entry] of lessonsById) {
      const count = references.get(lessonKey) ?? 0;
      if (count !== 1) {
        add(
          entry.file,
          `lesson "${entry.lesson.id}" must belong to exactly one track unit (found ${count} references)`,
        );
      }
    }
  }

  return integrityErrors;
}

/// Exercise types that the engine implements but the corpus does not yet use.
///
/// This is a **ratchet, not a target**. The repository's recurring failure mode
/// is building a mechanism and never wiring it: eight exercise types are
/// implemented client-side, and for a long time the corpus used exactly one of
/// them. An unused type is invisible — nobody notices it rot.
///
/// Pinning the gap makes every move deliberate:
///   * start using a pinned type  -> red, remove it from the pin (the gap shrinks);
///   * delete the last lesson using a type -> red, a regression is caught;
///   * declare a new type in the schema without content -> red, add it knowingly.
///
/// `matchPairs` is pinned because it is **not expressible** in this corpus, not
/// because nobody bothered: the renderer needs a right-hand column (`matches`),
/// which `lesson.schema.json` forbids (`additionalProperties: false`), which
/// `LessonCheck` has no field for, and which `seed_content.py` does not emit.
/// Its answer key is also a list of `"left:right"` tokens, which cannot satisfy
/// the INVALID_CORRECT_REF rule below. Unpinning it requires those four changes.
export const UNUSED_ITEM_TYPES_PIN = Object.freeze(['matchPairs']);

/// Pins the corpus/engine diversity gap. See [UNUSED_ITEM_TYPES_PIN].
export function validateExerciseDiversity(declaredTypes, usedTypes, pin = UNUSED_ITEM_TYPES_PIN) {
  const diversityErrors = [];
  const add = (message) => diversityErrors.push({ file: 'content/schema/lesson.schema.json', message });

  const declared = new Set(declaredTypes);
  const used = new Set(usedTypes);

  // A witness that must vary with the corpus. Without it, an instrument that
  // silently reads nothing would report "no gap" instead of failing.
  if (declared.size === 0) {
    add('EMPTY_TYPE_CATALOG: the schema declares no exercise type — the diversity ratchet is blind.');
    return diversityErrors;
  }
  if (used.size === 0) {
    add('EMPTY_TYPE_USAGE: no lesson uses any exercise type — the diversity ratchet is blind.');
    return diversityErrors;
  }

  const painted = [...used].filter((type) => !declared.has(type)).sort();
  if (painted.length > 0) {
    add(
      `UNDECLARED_ITEM_TYPE: the corpus uses ${painted.map((t) => `"${t}"`).join(', ')} ` +
        'which the schema does not declare. The schema enum is the contract — add the type there, ' +
        'and to ItemType in ContentModels.cs and lesson.dart, or stop using it.',
    );
  }

  const unused = [...declared].filter((type) => !used.has(type)).sort();
  const expected = [...pin].sort();
  if (unused.join('|') !== expected.join('|')) {
    add(
      `ITEM_TYPE_COVERAGE_CHANGED: exercise types implemented but never used are now ` +
        `[${unused.join(', ') || '—'}], the pin says [${expected.join(', ') || '—'}].\n` +
        '  · The gap shrank (a type is now used)? Remove it from UNUSED_ITEM_TYPES_PIN — thank you.\n' +
        '  · The gap grew? The last lesson using that type just disappeared, or a type was ' +
        'declared with no content. Author content for it, or update the pin knowingly.',
    );
  }

  return diversityErrors;
}

/// Per-type authoring rules the JSON schema cannot express.
///
/// The schema gives every item the same shape (`options` + `correct`), so an
/// item can be perfectly valid and still be **impossible to answer** in the app:
/// the submit button is gated per type by `canSubmitCurrent`, and grading is
/// order-sensitive for some types and not others. These checks close that gap at
/// authoring time instead of at runtime.
export function validateItemTypeShape(file, item, optionIds) {
  const shapeErrors = [];
  const add = (message) => shapeErrors.push({ file, message });
  const correctCount = item.correct.length;

  switch (item.type) {
    case 'matchPairs':
      // Pinned as unusable — fail with the reason rather than a cryptic ref error.
      add(
        `UNSUPPORTED_ITEM_TYPE: item "${item.id}" uses "matchPairs", which this corpus cannot ` +
          'express. The renderer pairs `options` with a right-hand `matches` column that the ' +
          'schema forbids, the server `LessonCheck` has no field for, and seed_content.py does ' +
          'not publish. See UNUSED_ITEM_TYPES_PIN.',
      );
      break;

    case 'cloze': {
      // The renderer interleaves one slot per `____` run and grades slot by slot;
      // a mismatch yields a check the learner can never submit.
      const blanks = (item.stem.match(/_{4,}/g) ?? []).length;
      if (blanks === 0) {
        add(`item "${item.id}": cloze stem has no "____" blank — nothing to fill.`);
      } else if (blanks !== correctCount) {
        add(
          `item "${item.id}": cloze has ${blanks} blank(s) but ${correctCount} correct answer(s). ` +
            'The learner can never submit: the submit button needs exactly one word per blank.',
        );
      }
      if (optionIds.length < blanks) {
        add(`item "${item.id}": cloze word bank (${optionIds.length}) is smaller than its ${blanks} blank(s).`);
      }
      break;
    }

    case 'applied':
      // Graded order-sensitively client-side: a single answer has no order.
      if (correctCount < 2) {
        add(
          `item "${item.id}": applied is graded as an ordered sequence, so it needs at least ` +
            `2 correct ids (got ${correctCount}). Use "mcq" or "scenario" for a single answer.`,
        );
      }
      break;

    case 'multi':
      // Only `multi` renders a multi-select; one answer means it should be an mcq.
      if (correctCount < 2) {
        add(
          `item "${item.id}": multi is the only multi-select type, so it needs at least ` +
            `2 correct ids (got ${correctCount}). Use "mcq" for a single answer.`,
        );
      }
      break;

    case 'spotTheIssue':
      // Rendered single-select: two correct ids would be unreachable.
      if (correctCount !== 1) {
        add(
          `item "${item.id}": spotTheIssue renders as single-select, so it must have exactly ` +
            `1 correct option (got ${correctCount}).`,
        );
      }
      break;

    default:
      break;
  }

  return shapeErrors;
}

const trackFiles = globSync('content/*/track.yaml', { cwd: root, absolute: true });
if (trackFiles.length === 0) fail('content', 'no track.yaml found');


for (const trackFile of trackFiles) {
  const trackDir = path.dirname(trackFile);
  const track = readYaml(trackFile);

  if (!validateTrack(track)) {
    for (const e of validateTrack.errors) fail(trackFile, `${e.instancePath} ${e.message}`);
    continue;
  }

  // Domain weights must sum to ~1.0.
  const sum = track.domains.reduce((acc, d) => acc + d.weight, 0);
  if (Math.abs(sum - 1) > 0.001) fail(trackFile, `domain weights sum to ${sum.toFixed(3)}, expected 1.0`);

  const domainIds = new Set(track.domains.map((d) => d.id));

  const lessons = [];
  for (const lf of globSync('lessons/*.lesson.yaml', { cwd: trackDir, absolute: true })) {
    const lesson = readYaml(lf);
    if (!validateLesson(lesson)) {
      for (const e of validateLesson.errors) fail(lf, `${e.instancePath} ${e.message}`);
      continue;
    }
    if (lesson.trackId !== track.id) fail(lf, `trackId "${lesson.trackId}" != "${track.id}"`);
    if (!domainIds.has(lesson.domainId)) fail(lf, `unknown domainId "${lesson.domainId}"`);
    lessons.push({ file: lf, lesson });

    // Quiz-item integrity. The schema checks shape; these checks catch authoring
    // mistakes the schema can't — a `correct` answer that points at a non-existent
    // option, duplicate option/item ids, or an incomplete `ordering` — all of which
    // would silently break server-side grading.
    for (const block of lesson.blocks) {
      const item = block.check;
      if (!item) continue;
      const optionIds = item.options.map((o) => o.id);
      const optionIdSet = new Set(optionIds);
      if (optionIdSet.size !== optionIds.length) {
        fail(lf, `item "${item.id}": duplicate option ids`);
      }
      if (item.correct.length === 0) {
        fail(lf, `item "${item.id}": correct[] must not be empty`);
      }
      for (const c of item.correct) {
        if (!optionIdSet.has(c)) {
          fail(lf, `INVALID_CORRECT_REF: question ${item.id} has correct answer '${c}' that does not match any option id`);
        }
      }
      if (new Set(item.correct).size !== item.correct.length) {
        fail(lf, `item "${item.id}": duplicate ids in "correct"`);
      }
      // Ordering enumerates the full sequence; one-answer types (mcq/scenario)
      // must name exactly one correct option.
      if (item.type === 'ordering' && item.correct.length !== optionIds.length) {
        fail(lf, `item "${item.id}": ordering must list all ${optionIds.length} options in order (got ${item.correct.length})`);
      }
      if ((item.type === 'mcq' || item.type === 'scenario') && item.correct.length !== 1) {
        fail(lf, `item "${item.id}": ${item.type} must have exactly one correct option (got ${item.correct.length})`);
      }
      usedItemTypes.add(item.type);
      for (const shapeError of validateItemTypeShape(lf, item, optionIds)) {
        fail(shapeError.file, shapeError.message);
      }
    }
  }

  for (const unit of track.units) {
    if (!domainIds.has(unit.domainId)) fail(trackFile, `unit ${unit.id}: unknown domainId`);
  }

  catalog.push({ trackFile, track, lessons });
}

for (const integrityError of validateCatalogMembership(catalog)) {
  fail(integrityError.file, integrityError.message);
}

// Corpus/engine diversity ratchet — the schema enum is the declared catalogue of
// exercise types; `usedItemTypes` is what the corpus actually exercises.
const declaredItemTypes =
  readJson('content/schema/lesson.schema.json')?.$defs?.item?.properties?.type?.enum ?? [];
for (const diversityError of validateExerciseDiversity(declaredItemTypes, usedItemTypes)) {
  fail(path.join(root, diversityError.file), diversityError.message);
}

if (errors.length > 0) {
  console.error(`\nContent validation failed (${errors.length}):\n${errors.join('\n')}\n`);
  process.exit(1);
}
console.log('✓ All content valid.');
