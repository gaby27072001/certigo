using System.Text.Json;
using System.Text.Json.Nodes;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class ExerciseItemsV5RulesTests
{
    public static TheoryData<string> ItemTypes => new()
    {
        "mcq",
        "multi",
        "scenario",
        "spotTheIssue",
        "ordering",
        "applied",
        "cloze",
        "matchPairs",
    };

    [Theory]
    [MemberData(nameof(ItemTypes))]
    public void Valid_examples_satisfy_v5_cross_rules(string itemType)
    {
        var (question, solution) = Example(itemType);

        ExerciseItemsV5Rules.Violations(Element(question), Element(solution))
            .Should().BeEmpty(itemType);
    }

    [Fact]
    public void Cloze_blanks_are_maximal_runs_of_at_least_four_underscores()
    {
        ExerciseItemsV5Rules.ClozeBlankCount("Un verrou ____ et un verrou ________.").Should().Be(2);
        ExerciseItemsV5Rules.ClozeBlankCount("Trois soulignes ___ ne font pas un trou.").Should().Be(0);
        ExerciseItemsV5Rules.ClozeBlankCount((string)Example("cloze").Question["prompt"]!).Should().Be(2);
    }

    [Theory]
    [MemberData(nameof(CrossRuleControls))]
    public void Invalid_pairs_report_the_expected_v5_rule_only(
        string rule,
        string itemType,
        Action<JsonObject, JsonObject> change)
    {
        var (question, solution) = Example(itemType);
        change(question, solution);

        RulesOf(ExerciseItemsV5Rules.Violations(Element(question), Element(solution)))
            .Should().Equal(rule);
    }

    [Fact]
    public void X7_checks_matchpairs_cardinality_and_bijection()
    {
        var unbalanced = Example("matchPairs");
        unbalanced.Question["matches"]!.AsArray().Add(new JsonObject
        {
            ["id"] = "r-none",
            ["label"] = "Rien",
        });

        RulesOf(ExerciseItemsV5Rules.QuestionViolations(Element(unbalanced.Question)))
            .Should().Equal("X7");

        var notBijective = Example("matchPairs");
        notBijective.Solution["correctOptionIds"] = new JsonArray(
            "l-owner:r-all",
            "l-contributor:r-all",
            "l-reader:r-read");

        RulesOf(ExerciseItemsV5Rules.PairViolations(
                Element(notBijective.Question),
                Element(notBijective.Solution)))
            .Should().Equal("X7");
    }

    [Fact]
    public void X8_rejects_applied_when_distractors_still_reveal_the_order()
    {
        var revealed = Example("applied");
        revealed.Question["options"] = OptionsById(
            revealed.Question,
            ["p-locate", "p-readonly", "p-remove", "p-delete"]);

        RulesOf(ExerciseItemsV5Rules.PairViolations(Element(revealed.Question), Element(revealed.Solution)))
            .Should().Equal("X8");
    }

    public static TheoryData<string, string, Action<JsonObject, JsonObject>> CrossRuleControls => new()
    {
        {
            "X1",
            "scenario",
            (_, solution) => solution["itemType"] = "mcq"
        },
        {
            "X2",
            "mcq",
            (question, _) => question["options"]![2]!["id"] = question["options"]![1]!["id"]!.GetValue<string>()
        },
        {
            "X3",
            "mcq",
            (_, solution) => solution["correctOptionIds"] = new JsonArray("z")
        },
        {
            "X4",
            "ordering",
            (_, solution) => solution["correctOptionIds"] = new JsonArray("s-mg", "s-sub", "s-rg")
        },
        {
            "X5",
            "applied",
            (_, solution) => solution["correctOptionIds"] = new JsonArray("p-locate")
        },
        {
            "X6",
            "cloze",
            (_, solution) => solution["correctOptionIds"] = new JsonArray("o-cannotdelete")
        },
        {
            "X7",
            "matchPairs",
            (_, solution) => solution["correctOptionIds"] = new JsonArray(
                "l-owner:r-unknown",
                "l-contributor:r-resources",
                "l-reader:r-read")
        },
        {
            "X8",
            "ordering",
            (question, solution) => question["options"] = OptionsById(
                question,
                solution["correctOptionIds"]!.AsArray().Select(id => id!.GetValue<string>()).ToArray())
        },
        {
            "X9",
            "matchPairs",
            (question, solution) =>
            {
                var matches = question["matches"]!.AsArray()
                    .Select(match => match!.DeepClone().AsObject())
                    .ToDictionary(match => match["id"]!.GetValue<string>(), StringComparer.Ordinal);
                question["matches"] = new JsonArray(question["options"]!.AsArray()
                    .Select(option =>
                    {
                        var optionId = option!["id"]!.GetValue<string>();
                        var token = solution["correctOptionIds"]!.AsArray()
                            .Select(entry => entry!.GetValue<string>())
                            .Single(entry => entry.StartsWith($"{optionId}:", StringComparison.Ordinal));
                        return matches[token.Split(':')[1]].DeepClone();
                    })
                    .ToArray<JsonNode?>());
            }
        },
    };

    private static (JsonObject Question, JsonObject Solution) Example(string itemType)
        => (ReadFixture($"{itemType}.question.json"), ReadFixture($"{itemType}.solution.json"));

    private static JsonObject ReadFixture(string fileName)
        => JsonNode.Parse(File.ReadAllText(FixtureRoot().Combine(fileName)))!.AsObject();

    private static JsonElement Element(JsonObject value)
        => JsonDocument.Parse(value.ToJsonString()).RootElement.Clone();

    private static IReadOnlyList<string> RulesOf(IEnumerable<ExerciseItemsV5Violation> violations)
        => violations.Select(violation => violation.Rule).Distinct().Order(StringComparer.Ordinal).ToArray();

    private static JsonArray OptionsById(JsonObject question, IReadOnlyList<string> ids)
    {
        var byId = question["options"]!.AsArray()
            .Select(option => option!.DeepClone().AsObject())
            .ToDictionary(option => option["id"]!.GetValue<string>(), StringComparer.Ordinal);
        return new JsonArray(ids.Select(id => byId[id].DeepClone()).ToArray<JsonNode?>());
    }

    private static DirectoryInfo FixtureRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Certigo.sln")))
        {
            directory = directory.Parent;
        }

        directory.Should().NotBeNull("les tests doivent retrouver backend\\Certigo.sln");
        return new DirectoryInfo(Path.Combine(
            directory!.FullName,
            "tests",
            "Certigo.Application.Tests",
            "Fixtures",
            "exercise-items-v5"));
    }
}

internal static class PathTestExtensions
{
    public static string Combine(this DirectoryInfo directory, string fileName)
        => Path.Combine(directory.FullName, fileName);
}
