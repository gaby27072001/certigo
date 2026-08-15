using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

internal static class SubmissionValidation
{
    public static void EnsureDistinctItemIds(IReadOnlyList<AnswerDto> answers)
    {
        var duplicates = answers
            .GroupBy(answer => answer.ItemId, StringComparer.OrdinalIgnoreCase)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .OrderBy(itemId => itemId, StringComparer.OrdinalIgnoreCase)
            .ToArray();

        if (duplicates.Length > 0)
        {
            throw new RequestValidationException(
                $"Duplicate item id(s) are not allowed: {string.Join(", ", duplicates)}.");
        }
    }
}
