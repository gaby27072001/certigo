import test from 'node:test';
import assert from 'node:assert/strict';
import { validateCatalogMembership } from '../validate_content.mjs';

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
