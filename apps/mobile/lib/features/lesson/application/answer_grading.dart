import 'package:cortex/cortex.dart' as cortex;
import 'package:data/data.dart';

/// Grading for every exercise type, delegated to `package:cortex`.
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
/// The comparison itself lives in `package:cortex` ([cortex.isAnswerCorrect]),
/// the pure-Dart twin of the server's `AnswerGrading`: the `ci-cortex-parity`
/// workflow replays the same golden vectors (`parity.answerGrading`) on both.
bool gradeSelection(ItemType type, List<String> selected, List<String> correct) =>
    cortex.isAnswerCorrect(itemTypeToWire(type), correct, selected);

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

/// Order-independent multiset equality over ids: the same ids with the same
/// counts, exactly like the server's `AnswerGrading` (a duplicated id never
/// stands in for a missing one).
bool unorderedEquals(List<String> a, List<String> b) => cortex.sameMultiset(a, b);
