import 'package:data/data.dart';
import 'package:flutter_test/flutter_test.dart' hide unorderedEquals;
import 'package:certigo/features/lesson/application/answer_grading.dart';

/// Unit tests for the pure grading core (`answer_grading.dart`).
///
/// This is the single comparison authority shared by P0 (offline) and P1
/// (server), so its order-sensitivity contract per [ItemType] is pinned here
/// in isolation — no Flutter, no controller, no I/O.
void main() {
  group('gradeSelection — order-sensitive types (the order IS the answer)', () {
    test('ordering: right ids in right order are correct', () {
      expect(
        gradeSelection(ItemType.ordering, <String>['s1', 's2', 's3'], <String>['s1', 's2', 's3']),
        isTrue,
      );
    });

    test('ordering: right ids in the wrong order are incorrect', () {
      expect(
        gradeSelection(ItemType.ordering, <String>['s2', 's1', 's3'], <String>['s1', 's2', 's3']),
        isFalse,
      );
    });

    test('ordering: a wrong element is incorrect', () {
      expect(
        gradeSelection(ItemType.ordering, <String>['s1', 's2', 'sX'], <String>['s1', 's2', 's3']),
        isFalse,
      );
    });

    test('ordering: a length mismatch is incorrect', () {
      expect(
        gradeSelection(ItemType.ordering, <String>['s1', 's2'], <String>['s1', 's2', 's3']),
        isFalse,
      );
    });

    test('cloze: positional blanks are graded by order', () {
      expect(
        gradeSelection(ItemType.cloze, <String>['w-iaas', 'w-paas'], <String>['w-iaas', 'w-paas']),
        isTrue,
      );
      expect(
        gradeSelection(ItemType.cloze, <String>['w-paas', 'w-iaas'], <String>['w-iaas', 'w-paas']),
        isFalse,
      );
    });

    test('applied: behaves like ordering (order-sensitive)', () {
      expect(
        gradeSelection(ItemType.applied, <String>['a', 'b'], <String>['a', 'b']),
        isTrue,
      );
      expect(
        gradeSelection(ItemType.applied, <String>['b', 'a'], <String>['a', 'b']),
        isFalse,
      );
    });
  });

  group('gradeSelection — set types (order is irrelevant)', () {
    test('matchPairs: the same pairs in any order are correct', () {
      expect(
        gradeSelection(
          ItemType.matchPairs,
          <String>['l3:r3', 'l1:r1', 'l2:r2'],
          <String>['l1:r1', 'l2:r2', 'l3:r3'],
        ),
        isTrue,
      );
    });

    test('matchPairs: a single mis-paired token is incorrect', () {
      expect(
        gradeSelection(
          ItemType.matchPairs,
          <String>['l1:r2', 'l2:r1', 'l3:r3'],
          <String>['l1:r1', 'l2:r2', 'l3:r3'],
        ),
        isFalse,
      );
    });

    test('mcq: a single right pick is correct, a wrong pick is not', () {
      expect(gradeSelection(ItemType.mcq, <String>['a'], <String>['a']), isTrue);
      expect(gradeSelection(ItemType.mcq, <String>['b'], <String>['a']), isFalse);
    });

    test('multi: any order of the full set is correct', () {
      expect(gradeSelection(ItemType.multi, <String>['b', 'a'], <String>['a', 'b']), isTrue);
    });

    test('multi: a partial answer (subset) is incorrect', () {
      expect(gradeSelection(ItemType.multi, <String>['a'], <String>['a', 'b']), isFalse);
    });

    test('multi: an over-answer (superset) is incorrect', () {
      expect(gradeSelection(ItemType.multi, <String>['a', 'b', 'c'], <String>['a', 'b']), isFalse);
    });

    test('scenario / spotTheIssue / unknown: graded as a set', () {
      expect(gradeSelection(ItemType.scenario, <String>['a'], <String>['a']), isTrue);
      expect(gradeSelection(ItemType.spotTheIssue, <String>['a'], <String>['a']), isTrue);
      expect(gradeSelection(ItemType.unknown, <String>['x'], <String>['x']), isTrue);
      expect(gradeSelection(ItemType.scenario, <String>['b'], <String>['a']), isFalse);
    });

    test('empty-vs-empty is vacuously correct', () {
      expect(gradeSelection(ItemType.multi, <String>[], <String>[]), isTrue);
    });
  });

  group('cloze blank parsing', () {
    test('clozeBlankCount counts each run of 4+ underscores once', () {
      expect(clozeBlankCount('En ____ vous gérez'), 1);
      expect(clozeBlankCount('En ____ et ____ fin'), 2);
      expect(clozeBlankCount('aucun trou ici'), 0);
    });

    test('clozeBlankCount ignores runs shorter than 4 underscores', () {
      expect(clozeBlankCount('trois ___ underscores'), 0);
    });

    test('clozeBlankCount treats a longer run as a single blank', () {
      expect(clozeBlankCount('long ________ trou'), 1);
    });

    test('clozeSegments returns N+1 literal segments around the blanks', () {
      final List<String> segs = clozeSegments('En ____ et ____ fin');
      expect(segs.length, 3);
      expect(segs.first, 'En ');
      expect(segs[1], ' et ');
      expect(segs.last, ' fin');
    });

    test('clozeSegments yields a trailing empty segment for a stem ending on a blank', () {
      final List<String> segs = clozeSegments('Choisis ____');
      expect(segs.length, 2);
      expect(segs.first, 'Choisis ');
      expect(segs.last, '');
    });

    test('clozeBlankPattern matches 4+ underscores only', () {
      expect(clozeBlankPattern.hasMatch('____'), isTrue);
      expect(clozeBlankPattern.hasMatch('___'), isFalse);
    });
  });

  group('match token + set equality helpers', () {
    test('matchToken builds the canonical "left:right" shape', () {
      expect(matchToken('l1', 'r1'), 'l1:r1');
    });

    test('unorderedEquals is true for a permutation', () {
      expect(unorderedEquals(<String>['a', 'b', 'c'], <String>['c', 'a', 'b']), isTrue);
    });

    test('unorderedEquals is false for a different set or length', () {
      expect(unorderedEquals(<String>['a', 'b'], <String>['a', 'c']), isFalse);
      expect(unorderedEquals(<String>['a'], <String>['a', 'b']), isFalse);
    });

    test('unorderedEquals is true for two empty sets', () {
      expect(unorderedEquals(<String>[], <String>[]), isTrue);
    });
  });
}
