import 'package:data/data.dart';

/// Pure, dependency-free grading for every exercise type.
///
/// All answers travel through one `List<String>` (see [LessonSessionState]);
/// only the *comparison semantics* differ by [ItemType]:
///
/// * **ordering / cloze / applied** — the list order **is** the answer, so we
///   compare element-by-element (a right-set-but-wrong-order answer is wrong).
/// * **matchPairs** — the list is a *set* of `"left:right"` pair tokens, order
///   irrelevant, so we compare as a set.
/// * **mcq / multi / scenario / spotTheIssue / unknown** — an order-independent
///   set of option ids (single- or multi-select).
///
/// Keeping this a free function (no I/O, no Flutter) makes the correctness of
/// the whole engine unit-testable in isolation and lets P0 (offline) and P1
/// (server) grade identically.
bool gradeSelection(ItemType type, List<String> selected, List<String> correct) {
  switch (type) {
    case ItemType.ordering:
    case ItemType.cloze:
    case ItemType.applied:
      return _orderedEquals(selected, correct);
    case ItemType.matchPairs:
    case ItemType.mcq:
    case ItemType.multi:
    case ItemType.scenario:
    case ItemType.spotTheIssue:
    case ItemType.unknown:
      return unorderedEquals(selected, correct);
  }
}

/// The blank marker used inside a `cloze` stem: a run of 4+ underscores
/// (`____`). The number of markers is the number of slots to fill.
final RegExp clozeBlankPattern = RegExp('_{4,}');

/// How many blanks a `cloze` stem exposes (its word-bank slot count).
int clozeBlankCount(String stem) => clozeBlankPattern.allMatches(stem).length;

/// Splits a `cloze` stem into the literal text segments around its blanks.
///
/// For N blanks the result has N+1 segments, so the renderer can interleave
/// `segment, slot, segment, slot, …, segment`.
List<String> clozeSegments(String stem) => stem.split(clozeBlankPattern);

/// Builds the canonical `"left:right"` token for a match pair. Centralised so
/// the controller, the grader and the answer key always agree on the shape.
String matchToken(String leftId, String rightId) => '$leftId:$rightId';

/// Order-sensitive element-by-element equality.
bool _orderedEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Order-independent multiset-free set equality over ids (no duplicates expected).
bool unorderedEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final Set<String> other = b.toSet();
  for (final String id in a) {
    if (!other.contains(id)) return false;
  }
  return true;
}
