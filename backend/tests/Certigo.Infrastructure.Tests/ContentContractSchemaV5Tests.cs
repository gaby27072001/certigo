using System.Text.Json;
using System.Text.Json.Nodes;
using Certigo.Application.Abstractions;
using Certigo.Infrastructure.ContentContracts;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class ContentContractSchemaV5Tests
{
    private static readonly string[] ItemTypes =
    [
        "mcq",
        "multi",
        "scenario",
        "spotTheIssue",
        "ordering",
        "applied",
        "cloze",
        "matchPairs",
    ];

    [Fact]
    public void Embedded_schemas_accept_the_eight_canonical_v5_examples()
    {
        var validator = new JsonSchemaContentContractValidator();

        foreach (var itemType in ItemTypes)
        {
            validator.Validate("question.schema.json", ReadElement($"{itemType}.question.json"));
            validator.Validate("solution.schema.json", ReadElement($"{itemType}.solution.json"));
        }
    }

    [Theory]
    [MemberData(nameof(SchemaControls))]
    public void Embedded_schemas_reject_v5_specific_negative_controls(
        string name,
        string itemType,
        string schemaFileName,
        Func<JsonObject, JsonObject, JsonObject> mutate)
    {
        var (question, solution) = Example(itemType);
        var invalid = mutate(question, solution);

        var action = () => new JsonSchemaContentContractValidator()
            .Validate(schemaFileName, Element(invalid));

        action.Should().Throw<ContentReleaseValidationException>(name);
    }

    [Theory]
    [InlineData("ordering")]
    [InlineData("applied")]
    [InlineData("cloze")]
    [InlineData("matchPairs")]
    public void V4_question_contract_stays_closed_to_new_item_types(string itemType)
    {
        var v4 = JsonNode.Parse("""
            {
              "id": "aws.clf-c02.domain-1.cloud-value.001",
              "schemaVersion": "v4",
              "kind": "public",
              "metadata": {
                "provider": "aws",
                "certification": "aws:clf-c02",
                "blueprintVersion": "2026-08-17",
                "objective": "domain-1",
                "domainId": "aws.clf-c02.domain.cloud-concepts",
                "conceptId": "aws.clf-c02.concept.variable-spend"
              },
              "itemType": "mcq",
              "difficulty": 2,
              "prompt": "Which option is correct?",
              "options": [
                { "id": "a", "label": "A" },
                { "id": "b", "label": "B" }
              ]
            }
            """)!.AsObject();
        new JsonSchemaContentContractValidator()
            .Validate("question.schema.json", Element(v4));

        v4["itemType"] = itemType;

        var action = () => new JsonSchemaContentContractValidator()
            .Validate("question.schema.json", Element(v4));

        action.Should().Throw<ContentReleaseValidationException>();
    }

    public static TheoryData<string, string, string, Func<JsonObject, JsonObject, JsonObject>> SchemaControls => new()
    {
        {
            "matches hors matchPairs",
            "mcq",
            "question.schema.json",
            (question, _) =>
            {
                question["matches"] = new JsonArray(
                    new JsonObject { ["id"] = "x", ["label"] = "X" },
                    new JsonObject { ["id"] = "y", ["label"] = "Y" });
                return question;
            }
        },
        {
            "matchPairs sans colonne droite",
            "matchPairs",
            "question.schema.json",
            (question, _) =>
            {
                question.Remove("matches");
                return question;
            }
        },
        {
            "cle pairs dans une question publique",
            "matchPairs",
            "question.schema.json",
            (question, _) =>
            {
                question["pairs"] = new JsonArray("l-owner:r-all");
                return question;
            }
        },
        {
            "corrige sans itemType",
            "mcq",
            "solution.schema.json",
            (_, solution) =>
            {
                solution.Remove("itemType");
                return solution;
            }
        },
        {
            "mcq a deux bonnes reponses",
            "mcq",
            "solution.schema.json",
            (_, solution) =>
            {
                solution["correctOptionIds"] = new JsonArray("a", "b");
                return solution;
            }
        },
        {
            "multi a deux options",
            "multi",
            "question.schema.json",
            (question, _) =>
            {
                var firstTwo = question["options"]!.AsArray().Take(2)
                    .Select(option => option!.DeepClone())
                    .ToArray<JsonNode?>();
                question["options"] = new JsonArray(firstTwo);
                return question;
            }
        },
        {
            "cloze sans trou",
            "cloze",
            "question.schema.json",
            (question, _) =>
            {
                question["prompt"] = question["prompt"]!.GetValue<string>().Replace("____", "...", StringComparison.Ordinal);
                return question;
            }
        },
        {
            "jeton matchPairs sans separateur",
            "matchPairs",
            "solution.schema.json",
            (_, solution) =>
            {
                solution["correctOptionIds"]![0] = "l-owner-r-all";
                return solution;
            }
        },
    };

    private static (JsonObject Question, JsonObject Solution) Example(string itemType)
        => (ReadFixture($"{itemType}.question.json"), ReadFixture($"{itemType}.solution.json"));

    private static JsonElement ReadElement(string fileName)
        => Element(ReadFixture(fileName));

    private static JsonObject ReadFixture(string fileName)
        => JsonNode.Parse(File.ReadAllText(Path.Combine(FixtureRoot().FullName, fileName)))!.AsObject();

    private static JsonElement Element(JsonObject value)
        => JsonDocument.Parse(value.ToJsonString()).RootElement.Clone();

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
