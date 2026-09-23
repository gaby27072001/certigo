using System.Text;
using System.Text.Json;
using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

/// Replays docs/contracts/learning-journey/v1/answer-grading.vectors.json, also read
/// by apps/mobile/test/answer_grading_vectors_test.dart: server and client must grade
/// every shared case identically.
public sealed class AnswerGradingVectorTests
{
    [Fact]
    public void Server_grading_matches_every_shared_vector()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(VectorsPath(), new UTF8Encoding(false)));
        document.RootElement.GetProperty("schema").GetString()
            .Should().Be("certigo.answer-grading-vectors/v1");
        var vectors = document.RootElement.GetProperty("vectors").EnumerateArray().ToArray();
        vectors.Should().NotBeEmpty();

        foreach (var vector in vectors)
        {
            var name = vector.GetProperty("name").GetString();
            var type = Enum.Parse<ItemType>(vector.GetProperty("type").GetString()!, ignoreCase: true);
            var correct = Strings(vector.GetProperty("correct"));
            var selected = Strings(vector.GetProperty("selected"));

            AnswerGrading.IsCorrect(type, correct, selected)
                .Should().Be(vector.GetProperty("expected").GetBoolean(), name);
        }
    }

    [Fact]
    public void Shared_vectors_cover_every_item_type()
    {
        using var document = JsonDocument.Parse(File.ReadAllText(VectorsPath(), new UTF8Encoding(false)));
        var covered = document.RootElement.GetProperty("vectors").EnumerateArray()
            .Select(vector => Enum.Parse<ItemType>(vector.GetProperty("type").GetString()!, ignoreCase: true))
            .ToHashSet();

        covered.Should().BeEquivalentTo(Enum.GetValues<ItemType>());
    }

    private static string[] Strings(JsonElement array)
        => array.EnumerateArray().Select(item => item.GetString()!).ToArray();

    private static string VectorsPath()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            var candidate = Path.Combine(
                directory.FullName,
                "docs",
                "contracts",
                "learning-journey",
                "v1",
                "answer-grading.vectors.json");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            directory = directory.Parent;
        }

        throw new FileNotFoundException("answer-grading.vectors.json not found above the test output.");
    }
}
