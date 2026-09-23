namespace Certigo.Domain.Content;

/// <summary>
/// Authoritative comparison of a submitted answer with its answer key, per item type.
/// It mirrors the client's <c>gradeSelection</c>
/// (<c>apps/mobile/lib/features/lesson/application/answer_grading.dart</c>): for ordered
/// types the list order is the answer; every other type is compared as a multiset.
/// </summary>
public static class AnswerGrading
{
    /// <summary>True when the position of each selected id is part of the answer.</summary>
    public static bool IsOrdered(ItemType type) =>
        type is ItemType.Ordering or ItemType.Cloze or ItemType.Applied;

    public static bool IsCorrect(
        ItemType type,
        IReadOnlyList<string> correct,
        IReadOnlyList<string>? selected)
    {
        ArgumentNullException.ThrowIfNull(correct);
        if (selected is null || selected.Count != correct.Count)
        {
            return false;
        }

        if (IsOrdered(type))
        {
            return correct.SequenceEqual(selected, StringComparer.OrdinalIgnoreCase);
        }

        return correct.OrderBy(id => id, StringComparer.OrdinalIgnoreCase)
            .SequenceEqual(
                selected.OrderBy(id => id, StringComparer.OrdinalIgnoreCase),
                StringComparer.OrdinalIgnoreCase);
    }
}
