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

if (errors.length > 0) {
  console.error(`\nContent validation failed (${errors.length}):\n${errors.join('\n')}\n`);
  process.exit(1);
}
console.log('✓ All content valid.');
