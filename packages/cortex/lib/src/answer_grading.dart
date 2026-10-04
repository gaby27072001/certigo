/// Answer grading — the client twin of the server's authoritative
/// `Certigo.Domain.Content.AnswerGrading`.
///
/// Every exercise answer travels as one `List<String>`; only the comparison
/// differs by item type (the wire name, e.g. `ordering`):
///
/// * `ordering`, `cloze`, `applied` — the list order **is** the answer, so the
///   lists are compared element by element;
/// * every other type (`mcq`, `multi`, `scenario`, `spotTheIssue`, and the
///   `"left:right"` tokens of `matchPairs`) — the same ids with the same counts,
///   order irrelevant (a duplicated id never stands in for a missing one).
///
/// Parity with .NET is enforced by the shared golden vectors
/// (`test/golden/cortex_golden_vectors.json`, `parity.answerGrading`), replayed on
/// both sides by the `ci-cortex-parity` workflow.
library;

/// Item types whose answer is a sequence.
const Set<String> orderedItemTypes = <String>{'ordering', 'cloze', 'applied'};

/// Whether the position of each selected id is part of the answer for [itemType].
bool isOrderedItemType(String itemType) => orderedItemTypes.contains(itemType);

/// Whether [selected] answers an item of [itemType] whose key is [correct].
bool isAnswerCorrect(String itemType, List<String> correct, List<String> selected) =>
    isOrderedItemType(itemType) ? sameSequence(correct, selected) : sameMultiset(correct, selected);

/// Order-sensitive element-by-element equality.
bool sameSequence(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Order-independent multiset equality: the same ids with the same counts.
bool sameMultiset(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  final Map<String, int> remaining = <String, int>{};
  for (final String id in b) {
    remaining[id] = (remaining[id] ?? 0) + 1;
  }
  for (final String id in a) {
    final int count = remaining[id] ?? 0;
    if (count == 0) return false;
    remaining[id] = count - 1;
  }
  return true;
}
