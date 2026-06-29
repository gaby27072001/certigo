using FluentAssertions;
using Certigo.Domain.Progress;
using Certigo.Domain.Readiness;
using Xunit;

namespace Certigo.Domain.Tests;

/// Golden vectors shared with the Flutter client (`cortex_golden_test.dart`). They
/// pin the client/server Cortex parity claimed in the architecture docs: any change
/// here MUST be mirrored there, or the server's authoritative result drifts from the
/// client's optimistic projection.
public sealed class CortexParityTests
{
    private static readonly DateTimeOffset Now = new(2025, 1, 1, 0, 0, 0, TimeSpan.Zero);

    [Fact]
    public void ReviewScheduler_apply_fresh_good_matches_golden_vector()
    {
        var next = ReviewScheduler.Apply(
            ConceptMastery.New("user-1", "az-900", "c"),
            ReviewGrade.Good,
            Now);

        next.Stability.Should().BeApproximately(1.6, 1e-12);
        next.Difficulty.Should().BeApproximately(4.85, 1e-12);
        next.MasteryScore.Should().BeApproximately(1 - Math.Exp(-1.6 / 20), 1e-12);
        next.DueAt.Should().Be(Now.AddDays(1.6)); // fractional, not ceil() = 2 days
    }

    [Fact]
    public void Readiness_recency_uses_fractional_days_golden_vector()
    {
        var weights = new Dictionary<string, double> { ["d"] = 1.0 };
        var counts = new Dictionary<string, int> { ["d"] = 1 };
        var conceptDomains = new Dictionary<string, string> { ["d:c"] = "d" };
        var masteries = new[]
        {
            ConceptMastery.New("user-1", "az-900", "d:c")
                with { MasteryScore = 1.0, LastReviewedAt = Now.AddDays(-2.9) }
        };

        var readiness = ReadinessCalculator.Compute(
            "az-900", weights, counts, masteries, Now, conceptDomains: conceptDomains);

        // Matches the Dart golden vector: round(100 * exp(-2.9/30)^0.3) = 97.
        readiness.Domains.Single().Score.Should().Be(97);
    }
}
