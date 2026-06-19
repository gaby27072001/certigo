// Validates Microlingo content-as-code against the JSON schemas.
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

  // Load lessons and index by id.
  const lessonsById = new Map();
  for (const lf of globSync('lessons/*.lesson.yaml', { cwd: trackDir, absolute: true })) {
    const lesson = readYaml(lf);
    if (!validateLesson(lesson)) {
      for (const e of validateLesson.errors) fail(lf, `${e.instancePath} ${e.message}`);
      continue;
    }
    if (lesson.trackId !== track.id) fail(lf, `trackId "${lesson.trackId}" != "${track.id}"`);
    if (!domainIds.has(lesson.domainId)) fail(lf, `unknown domainId "${lesson.domainId}"`);
    lessonsById.set(lesson.id, lesson);
  }

  // Every lesson referenced by a unit must exist and map to the unit's domain.
  for (const unit of track.units) {
    if (!domainIds.has(unit.domainId)) fail(trackFile, `unit ${unit.id}: unknown domainId`);
    for (const lessonId of unit.lessons) {
      const lesson = lessonsById.get(lessonId);
      if (!lesson) {
        fail(trackFile, `unit ${unit.id} references missing lesson "${lessonId}"`);
      } else if (lesson.unitId !== unit.id) {
        fail(trackFile, `lesson ${lessonId}.unitId "${lesson.unitId}" != unit "${unit.id}"`);
      }
    }
  }
}

if (errors.length > 0) {
  console.error(`\nContent validation failed (${errors.length}):\n${errors.join('\n')}\n`);
  process.exit(1);
}
console.log('✓ All content valid.');
