using FluentAssertions;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Readiness;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class ReadinessCalculatorTests
{
    [Fact]
    public void Compute_is_monotonic_when_coverage_and_mastery_improve()
    {
        var now = DateTimeOffset.UtcNow;
        var weights = new Dictionary<string, double> { ["identity"] = 0.5, ["compute"] = 0.5 };
        var counts = new Dictionary<string, int> { ["identity"] = 2, ["compute"] = 2 };
        var low = new[]
        {
            ConceptMastery.New("user-1", "az-900", "identity:entra") with { MasteryScore = 0.3, LastReviewedAt = now }
        };
        var high = new[]
        {
            ConceptMastery.New("user-1", "az-900", "identity:entra") with { MasteryScore = 0.8, LastReviewedAt = now },
            ConceptMastery.New("user-1", "az-900", "identity:rbac") with { MasteryScore = 0.8, LastReviewedAt = now },
            ConceptMastery.New("user-1", "az-900", "compute:vm") with { MasteryScore = 0.8, LastReviewedAt = now }
        };

        var lowScore = ReadinessCalculator.Compute("az-900", weights, counts, low, now).Score;
        var highScore = ReadinessCalculator.Compute("az-900", weights, counts, high, now).Score;

        highScore.Should().BeGreaterThan(lowScore);
    }
}
