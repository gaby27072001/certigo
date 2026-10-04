import test from 'node:test';
import assert from 'node:assert/strict';
import {
  UNUSED_ITEM_TYPES_PIN,
  validateCatalogMembership,
  validateExerciseDiversity,
  validateItemTypeShape,
} from '../validate_content.mjs';

const lesson = (id, unitId, domainId, itemId = `${id}-item`) => ({
  id,
  unitId,
  domainId,
  blocks: [{ check: { id: itemId } }],
});

const entry = (trackId, units, lessons) => ({
  trackFile: `content/${trackId}/track.yaml`,
  track: { id: trackId, units },
  lessons: lessons.map((value) => ({
    file: `content/${trackId}/lessons/${value.id}.lesson.yaml`,
    lesson: value,
  })),
});

test('lesson and item ids are globally unique across tracks', () => {
  const errors = validateCatalogMembership([
    entry('track-a', [{ id: 'unit-a', domainId: 'domain-a', lessons: ['shared'] }], [
      lesson('shared', 'unit-a', 'domain-a', 'shared-item'),
    ]),
    entry('track-b', [{ id: 'unit-b', domainId: 'domain-b', lessons: ['shared'] }], [
      lesson('shared', 'unit-b', 'domain-b', 'shared-item'),
    ]),
  ]);

  assert.ok(errors.some(({ message }) => message.startsWith('DUPLICATE_LESSON_ID')));
  assert.ok(errors.some(({ message }) => message.startsWith('DUPLICATE_ITEM_ID')));
});

test('every lesson belongs to exactly one unit', () => {
  const errors = validateCatalogMembership([
    entry(
      'track-a',
      [
        { id: 'unit-a', domainId: 'domain-a', lessons: ['lesson-a'] },
        { id: 'unit-b', domainId: 'domain-a', lessons: ['lesson-a'] },
      ],
      [
        lesson('lesson-a', 'unit-a', 'domain-a'),
        lesson('orphan', 'unit-a', 'domain-a'),
      ],
    ),
  ]);

  assert.ok(errors.some(({ message }) => message.includes('found 2 references')));
  assert.ok(errors.some(({ message }) => message.includes('found 0 references')));
});

test('unit references must match lesson id casing, unit, and domain exactly', () => {
  const errors = validateCatalogMembership([
    entry(
      'track-a',
      [{ id: 'unit-a', domainId: 'domain-a', lessons: ['LESSON-A'] }],
      [lesson('lesson-a', 'wrong-unit', 'wrong-domain')],
    ),
  ]);

  assert.ok(errors.some(({ message }) => message.includes('exact casing')));
  assert.ok(errors.some(({ message }) => message.includes('.unitId')));
  assert.ok(errors.some(({ message }) => message.includes('.domainId')));
});

// ---------------------------------------------------------------------------
// Corpus/engine diversity ratchet.
//
// The failure this guards against is silence: a type implemented on both sides
// and used by nothing at all. Each test below states the move that should turn
// the gate red, so the ratchet cannot quietly stop measuring.
// ---------------------------------------------------------------------------

const DECLARED = [
  'mcq',
  'multi',
  'scenario',
  'cloze',
  'ordering',
  'matchPairs',
  'spotTheIssue',
  'applied',
];
const USED_TODAY = DECLARED.filter((type) => !UNUSED_ITEM_TYPES_PIN.includes(type));

test('the pinned gap is the accepted state — no error when the corpus matches it', () => {
  assert.deepEqual(validateExerciseDiversity(DECLARED, USED_TODAY), []);
});

test('losing the last lesson of a type turns the ratchet red', () => {
  const errors = validateExerciseDiversity(
    DECLARED,
    USED_TODAY.filter((type) => type !== 'ordering'),
  );

  assert.ok(errors.some(({ message }) => message.startsWith('ITEM_TYPE_COVERAGE_CHANGED')));
  assert.ok(errors.some(({ message }) => message.includes('ordering')));
});

test('starting to use a pinned type turns the ratchet red so the pin shrinks', () => {
  const errors = validateExerciseDiversity(DECLARED, [...USED_TODAY, 'matchPairs']);

  assert.ok(errors.some(({ message }) => message.includes('the pin says [matchPairs]')));
});

test('declaring a ninth type with no content turns the ratchet red', () => {
  const errors = validateExerciseDiversity([...DECLARED, 'dragDrop'], USED_TODAY);

  assert.ok(errors.some(({ message }) => message.includes('dragDrop')));
});

test('using a type the schema never declared is reported against the schema', () => {
  const errors = validateExerciseDiversity(DECLARED, [...USED_TODAY, 'freeText']);

  assert.ok(errors.some(({ message }) => message.startsWith('UNDECLARED_ITEM_TYPE')));
});

test('a mute instrument fails instead of reporting "no gap"', () => {
  // Both halves must be able to fail loudly: an empty catalogue or an empty
  // corpus would otherwise make every comparison above trivially pass.
  assert.ok(
    validateExerciseDiversity([], USED_TODAY).some(({ message }) =>
      message.startsWith('EMPTY_TYPE_CATALOG'),
    ),
  );
  assert.ok(
    validateExerciseDiversity(DECLARED, []).some(({ message }) =>
      message.startsWith('EMPTY_TYPE_USAGE'),
    ),
  );
});

// ---------------------------------------------------------------------------
// Per-type authoring rules the JSON schema cannot express.
// ---------------------------------------------------------------------------

const item = (overrides) => ({
  id: 'item-1',
  type: 'mcq',
  stem: 'Question ?',
  correct: ['a'],
  ...overrides,
});

test('matchPairs is rejected with the reason it cannot be authored', () => {
  const errors = validateItemTypeShape('f.yaml', item({ type: 'matchPairs' }), ['a', 'b']);

  assert.ok(errors.some(({ message }) => message.startsWith('UNSUPPORTED_ITEM_TYPE')));
  assert.ok(errors.some(({ message }) => message.includes('matches')));
});

test('a cloze whose blanks and answers disagree can never be submitted', () => {
  const twoBlanksOneAnswer = item({
    type: 'cloze',
    stem: 'Un verrou ____ puis un verrou ____.',
    correct: ['a'],
  });

  assert.ok(
    validateItemTypeShape('f.yaml', twoBlanksOneAnswer, ['a', 'b']).some(({ message }) =>
      message.includes('2 blank(s) but 1 correct answer(s)'),
    ),
  );
  assert.deepEqual(
    validateItemTypeShape('f.yaml', { ...twoBlanksOneAnswer, correct: ['a', 'b'] }, ['a', 'b']),
    [],
  );
});

test('a cloze with no blank at all is rejected', () => {
  const errors = validateItemTypeShape('f.yaml', item({ type: 'cloze', stem: 'Sans trou.' }), ['a']);

  assert.ok(errors.some(({ message }) => message.includes('no "____" blank')));
});

test('ordered types need an order, single-select types need a single answer', () => {
  // `applied` is graded element-by-element: one id has no order to check.
  assert.ok(
    validateItemTypeShape('f.yaml', item({ type: 'applied' }), ['a', 'b']).some(({ message }) =>
      message.includes('ordered sequence'),
    ),
  );
  // `multi` is the only multi-select widget.
  assert.ok(
    validateItemTypeShape('f.yaml', item({ type: 'multi' }), ['a', 'b']).some(({ message }) =>
      message.includes('at least 2 correct ids'),
    ),
  );
  // `spotTheIssue` renders single-select: a second answer would be unreachable.
  assert.ok(
    validateItemTypeShape('f.yaml', item({ type: 'spotTheIssue', correct: ['a', 'b'] }), [
      'a',
      'b',
    ]).some(({ message }) => message.includes('exactly 1 correct option')),
  );
  // And each of them passes once well formed.
  assert.deepEqual(validateItemTypeShape('f.yaml', item({ type: 'applied', correct: ['a', 'b'] }), ['a', 'b']), []);
  assert.deepEqual(validateItemTypeShape('f.yaml', item({ type: 'multi', correct: ['a', 'b'] }), ['a', 'b']), []);
  assert.deepEqual(validateItemTypeShape('f.yaml', item({ type: 'spotTheIssue' }), ['a', 'b']), []);
});

test('applied with distractors is held back until the app can submit a partial selection', () => {
  const withDistractor = item({ type: 'applied', correct: ['a', 'b'] });

  assert.ok(
    validateItemTypeShape('f.yaml', withDistractor, ['a', 'b', 'c']).some(({ message }) =>
      message.startsWith('APPLIED_DISTRACTORS_NOT_YET_SUPPORTED'),
    ),
  );
  assert.deepEqual(validateItemTypeShape('f.yaml', withDistractor, ['a', 'b']), []);
});
