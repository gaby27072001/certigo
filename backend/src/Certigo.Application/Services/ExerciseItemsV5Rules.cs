using System.Text.Json;
using System.Text.RegularExpressions;

namespace Certigo.Application.Services;

internal static partial class ExerciseItemsV5Rules
{
    private const int ClozeMaxBlanks = 6;

    public static IReadOnlyList<ExerciseItemsV5Violation> Violations(
        JsonElement question,
        JsonElement solution)
        => [.. QuestionViolations(question), .. PairViolations(question, solution)];

    public static IReadOnlyList<ExerciseItemsV5Violation> QuestionViolations(JsonElement question)
    {
        var found = new List<ExerciseItemsV5Violation>();
        var optionIds = IdsOf(question, "options");
        var matchIds = IdsOf(question, "matches");

        var repeatedOptions = Duplicates(optionIds);
        if (repeatedOptions.Count > 0)
        {
            found.Add(Violation("X2", $"ids d'options dupliques: {Join(repeatedOptions)}"));
        }

        var repeatedMatches = Duplicates(matchIds);
        if (repeatedMatches.Count > 0)
        {
            found.Add(Violation("X2", $"ids de matches dupliques: {Join(repeatedMatches)}"));
        }

        var shared = optionIds.Distinct(StringComparer.Ordinal)
            .Where(id => matchIds.Contains(id, StringComparer.Ordinal))
            .ToArray();
        if (shared.Length > 0)
        {
            found.Add(Violation("X2", $"ids communs a options et matches: {Join(shared)}"));
        }

        var itemType = StringProperty(question, "itemType");
        if (itemType == "cloze")
        {
            var blanks = ClozeBlankCount(StringProperty(question, "prompt"));
            if (blanks is < 1 or > ClozeMaxBlanks)
            {
                found.Add(Violation(
                    "X6",
                    $"{blanks} trou(s) dans le prompt, attendu entre 1 et {ClozeMaxBlanks}"));
            }

            if (optionIds.Count < blanks)
            {
                found.Add(Violation("X6", $"banque de {optionIds.Count} mot(s) pour {blanks} trou(s)"));
            }
        }

        if (itemType == "matchPairs" && optionIds.Count != matchIds.Count)
        {
            found.Add(Violation(
                "X7",
                $"options ({optionIds.Count}) et matches ({matchIds.Count}) n'ont pas le meme cardinal"));
        }

        return found;
    }

    public static IReadOnlyList<ExerciseItemsV5Violation> PairViolations(
        JsonElement question,
        JsonElement solution)
    {
        var itemType = StringProperty(question, "itemType");
        var solutionItemType = StringProperty(solution, "itemType");
        if (solutionItemType != itemType)
        {
            return
            [
                Violation(
                    "X1",
                    $"itemType du corrige \"{solutionItemType}\" different de celui de la question \"{itemType}\""),
            ];
        }

        var found = new List<ExerciseItemsV5Violation>();
        var optionIds = IdsOf(question, "options");
        var matchIds = IdsOf(question, "matches");
        var optionSet = optionIds.ToHashSet(StringComparer.Ordinal);
        var correct = StringArray(solution, "correctOptionIds");

        if (itemType != "matchPairs")
        {
            var unknown = correct.Where(id => !optionSet.Contains(id)).ToArray();
            if (unknown.Length > 0)
            {
                found.Add(Violation("X3", $"ids absents des options: {Join(unknown)}"));
            }
        }

        if (itemType == "ordering")
        {
            var isPermutation = correct.Count == optionIds.Count
                                && correct.ToHashSet(StringComparer.Ordinal).Count == correct.Count
                                && optionIds.All(id => correct.Contains(id, StringComparer.Ordinal));
            if (!isPermutation)
            {
                found.Add(Violation(
                    "X4",
                    "correctOptionIds doit etre une permutation de toutes les options"));
            }
        }

        if (itemType == "applied" && (correct.Count < 2 || correct.Count > optionIds.Count))
        {
            found.Add(Violation(
                "X5",
                $"{correct.Count} etape(s) attendue(s), il en faut entre 2 et {optionIds.Count}"));
        }

        if (itemType == "cloze")
        {
            var blanks = ClozeBlankCount(StringProperty(question, "prompt"));
            if (correct.Count != blanks)
            {
                found.Add(Violation("X6", $"{correct.Count} reponse(s) pour {blanks} trou(s)"));
            }
        }

        if (itemType == "matchPairs")
        {
            AddMatchPairViolations(found, optionIds, matchIds, correct);
        }

        if (itemType is "ordering" or "applied")
        {
            var cited = correct.ToHashSet(StringComparer.Ordinal);
            var publishedOrder = optionIds.Where(id => cited.Contains(id)).ToArray();
            if (correct.Count >= 2 && SameSequence(publishedOrder, correct))
            {
                found.Add(Violation("X8", "l'ordre publie des options donne la reponse attendue"));
            }
        }

        return found;
    }

    public static int ClozeBlankCount(string? prompt)
        => string.IsNullOrEmpty(prompt) ? 0 : ClozeBlankRegex().Matches(prompt).Count;

    private static void AddMatchPairViolations(
        ICollection<ExerciseItemsV5Violation> found,
        IReadOnlyList<string> optionIds,
        IReadOnlyList<string> matchIds,
        IReadOnlyList<string> correct)
    {
        var optionSet = optionIds.ToHashSet(StringComparer.Ordinal);
        var matchSet = matchIds.ToHashSet(StringComparer.Ordinal);
        var lefts = new List<string>();
        var rights = new List<string>();

        foreach (var token in correct)
        {
            var separator = token.IndexOf(':', StringComparison.Ordinal);
            if (separator <= 0 || separator == token.Length - 1)
            {
                found.Add(Violation("X7", $"jeton \"{token}\" hors format \"gauche:droite\""));
                continue;
            }

            var left = token[..separator];
            var right = token[(separator + 1)..];
            if (!optionSet.Contains(left))
            {
                found.Add(Violation("X7", $"jeton \"{token}\": \"{left}\" absent des options"));
            }

            if (!matchSet.Contains(right))
            {
                found.Add(Violation("X7", $"jeton \"{token}\": \"{right}\" absent des matches"));
            }

            lefts.Add(left);
            rights.Add(right);
        }

        var repeatedLefts = Duplicates(lefts);
        var repeatedRights = Duplicates(rights);
        if (repeatedLefts.Count > 0 || repeatedRights.Count > 0)
        {
            found.Add(Violation(
                "X7",
                $"association non bijective: {Join([.. repeatedLefts, .. repeatedRights])} apparait plusieurs fois"));
        }

        if (correct.Count != optionIds.Count)
        {
            found.Add(Violation("X7", $"{correct.Count} jeton(s) pour {optionIds.Count} option(s) de gauche"));
        }

        var aligned = optionIds.Count > 0 && optionIds.Select((left, index) =>
                index < matchIds.Count && correct.Contains($"{left}:{matchIds[index]}", StringComparer.Ordinal))
            .All(value => value);
        if (aligned)
        {
            found.Add(Violation(
                "X9",
                "l'ordre publie donne les paires : chaque option est face a son match"));
        }
    }

    private static IReadOnlyList<string> IdsOf(JsonElement value, string propertyName)
    {
        if (!value.TryGetProperty(propertyName, out var list) || list.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return list.EnumerateArray()
            .Select(entry => entry.ValueKind == JsonValueKind.Object
                             && entry.TryGetProperty("id", out var id)
                             && id.ValueKind == JsonValueKind.String
                ? id.GetString() ?? string.Empty
                : string.Empty)
            .ToArray();
    }

    private static IReadOnlyList<string> StringArray(JsonElement value, string propertyName)
    {
        if (!value.TryGetProperty(propertyName, out var list) || list.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return list.EnumerateArray()
            .Select(entry => entry.ValueKind == JsonValueKind.String ? entry.GetString() ?? string.Empty : string.Empty)
            .ToArray();
    }

    private static string? StringProperty(JsonElement value, string propertyName)
        => value.TryGetProperty(propertyName, out var property) && property.ValueKind == JsonValueKind.String
            ? property.GetString()
            : null;

    private static IReadOnlyList<string> Duplicates(IEnumerable<string> values)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var repeated = new HashSet<string>(StringComparer.Ordinal);
        foreach (var value in values)
        {
            if (!seen.Add(value))
            {
                repeated.Add(value);
            }
        }

        return repeated.ToArray();
    }

    private static bool SameSequence(IReadOnlyList<string> left, IReadOnlyList<string> right)
        => left.Count == right.Count && left.SequenceEqual(right, StringComparer.Ordinal);

    private static ExerciseItemsV5Violation Violation(string rule, string message)
        => new(rule, message);

    private static string Join(IEnumerable<string> values)
        => string.Join(", ", values);

    [GeneratedRegex("_{4,}", RegexOptions.CultureInvariant)]
    private static partial Regex ClozeBlankRegex();
}

internal sealed record ExerciseItemsV5Violation(string Rule, string Message);
