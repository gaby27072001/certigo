using System.Text.RegularExpressions;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

/// <summary>
/// Structural guard on the shape of Cosmos SQL emitted by the infrastructure layer.
///
/// Azure Cosmos DB projects aggregates flat — one aggregate per SELECT list item.
/// Composing them inside an object literal (<c>SELECT VALUE { "a": COUNT(1) }</c>)
/// parses fine in C# but is rejected by the service at runtime with
/// "Compositions of aggregates and other expressions are not allowed", surfacing as
/// HTTP 500.
///
/// This class exists because the behaviour it protects cannot be caught by the
/// tests that actually run: <see cref="CosmosRepositoriesIntegrationTests"/> needs a
/// Cosmos emulator and is skipped by default, and an in-memory fake never parses SQL.
/// A source-level assertion is the only guard that executes on every build.
/// </summary>
public sealed class CosmosQueryShapeTests
{
    private static readonly string[] Aggregates = ["COUNT(", "SUM(", "AVG(", "MIN(", "MAX("];

    [Fact]
    public void No_cosmos_query_composes_aggregates_inside_an_object_literal()
    {
        var sourceRoot = Path.Combine(FindRepositoryRoot(), "backend", "src", "Certigo.Infrastructure");
        Directory.Exists(sourceRoot).Should().BeTrue($"'{sourceRoot}' must exist for this guard to mean anything");

        var offenders = new List<string>();
        foreach (var file in Directory.EnumerateFiles(sourceRoot, "*.cs", SearchOption.AllDirectories))
        {
            // Only string literals are scanned. Comments legitimately spell the
            // forbidden shape out to explain it, and a comment emits no query.
            // Literals are joined in file order so a query split across
            // concatenated literals is still seen as one statement.
            var emitted = string.Join(
                ' ',
                Regex.Matches(File.ReadAllText(file), "\"(?:[^\"\\\\\r\n]|\\\\.)*\"")
                    .Select(literal => literal.Value));

            foreach (Match match in Regex.Matches(emitted, @"SELECT\s+VALUE\s*\{", RegexOptions.IgnoreCase))
            {
                var window = emitted.Substring(
                    match.Index,
                    Math.Min(400, emitted.Length - match.Index));
                if (Aggregates.Any(aggregate => window.Contains(aggregate, StringComparison.OrdinalIgnoreCase)))
                {
                    offenders.Add($"{Path.GetFileName(file)}: {window[..Math.Min(120, window.Length)]}");
                }
            }
        }

        offenders.Should().BeEmpty(
            "Cosmos rejects aggregates composed inside an object literal at runtime; "
            + "project them flat instead (SELECT COUNT(1) AS attempts, SUM(c.x) AS xp FROM c)");
    }

    [Fact]
    public void Recent_activity_query_projects_its_aggregates_flat()
    {
        var file = Path.Combine(
            FindRepositoryRoot(),
            "backend", "src", "Certigo.Infrastructure", "Cosmos", "CosmosAttemptRepository.cs");
        var text = File.ReadAllText(file);

        // This is the rate-limit guard read by both quiz submission and exam
        // generation: when it throws, neither can complete.
        text.Should().Contain("SELECT COUNT(1) AS attempts, SUM(c.result.rewards.xpEarned) AS xp");
        text.Should().NotContain("SELECT VALUE { \\\"attempts\\\"");
    }

    private static string FindRepositoryRoot()
    {
        var current = new DirectoryInfo(AppContext.BaseDirectory);
        while (current is not null && !Directory.Exists(Path.Combine(current.FullName, "docs")))
        {
            current = current.Parent;
        }
        return current?.FullName
            ?? throw new InvalidOperationException("Repository root was not found.");
    }
}
