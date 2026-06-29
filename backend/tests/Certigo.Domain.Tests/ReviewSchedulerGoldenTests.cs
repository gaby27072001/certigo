using FluentAssertions;
using Certigo.Domain.Progress;
using Xunit;

namespace Certigo.Domain.Tests;

/// Cross-language golden tests for the Cortex scheduler.
///
/// These vectors are the canonical source of truth shared between the C# backend
/// (<see cref="ReviewScheduler"/>) and the Dart client (<c>ReviewScheduler</c> in
/// cortex). Any change to one set MUST be mirrored in the other so the client's
/// optimistic projection stays in sync with the server's authoritative result.
///
/// Parity principles:
///   1. Fractional-day scheduling — <c>now.AddDays(stability)</c>, NOT <c>ceil(stability)</c>.
///   2. Stability factor per grade: Again=0.5×, Hard=1.1×, Good=1.6×, Easy=2.1×.
///   3. On Again the floor is max(0.5, stability × 0.4).
public sealed class ReviewSchedulerGoldenTests
{
    private static readonly DateTimeOffset Now = new(2025, 1, 1, 0, 0, 0, TimeSpan.Zero);

    // ── DueAt golden vectors ────────────────────────────────────────────────
    // Each row: (initialStability, grade, expectedStabilityAfter)
    // DueAt must equal Now.AddDays(expectedStabilityAfter) exactly — fractional,
    // not rounded or ceiling.

    [Theory]
    [InlineData(1.0, ReviewGrade.Good,  1.6)]  // fresh × Good factor (1.6)
    [InlineData(1.0, ReviewGrade.Easy,  2.1)]  // fresh × Easy factor (2.1)
    [InlineData(1.0, ReviewGrade.Hard,  1.1)]  // fresh × Hard factor (1.1)
    [InlineData(1.0, ReviewGrade.Again, 0.5)]  // max(0.5, 1.0 × 0.4) = max(0.5, 0.4) = 0.5
    [InlineData(2.0, ReviewGrade.Good,  3.2)]  // 2.0 × 1.6 — verifies non-unit stability
    [InlineData(3.0, ReviewGrade.Easy,  6.3)]  // 3.0 × 2.1 — fractional > 6 days
    [InlineData(0.5, ReviewGrade.Good,  0.8)]  // sub-day stability: 0.5 × 1.6 = 0.8 days
    [InlineData(5.0, ReviewGrade.Again, 2.0)]  // max(0.5, 5.0 × 0.4) = 2.0 — not floored
    [InlineData(4.0, ReviewGrade.Hard,  4.4)]  // 4.0 × 1.1 = 4.4 — fractional < ceil(4.4)=5
    public void DueAt_is_fractional_not_ceiling(double initialStability, ReviewGrade grade, double expectedStability)
    {
        var m = ConceptMastery.New("user-1", "az-900", "concept-1") with { Stability = initialStability };

        var after = ReviewScheduler.Apply(m, grade, Now);

        after.Stability.Should().BeApproximately(expectedStability, 1e-10,
            $"stability after {grade} from {initialStability} should be {expectedStability}");

        // The core invariant: DueAt is derived from the exact computed stability,
        // not from any rounded/ceiling version.
        after.DueAt.Should().Be(Now.AddDays(after.Stability),
            $"DueAt must equal Now + stability ({after.Stability}) days exactly — no rounding");

        // Explicitly verify NOT ceil when the two would differ by more than a millisecond.
        var ceilDays = Math.Ceiling(after.Stability);
        if (ceilDays - after.Stability > 1e-6)
        {
            after.DueAt.Should().NotBe(Now.AddDays(ceilDays),
                $"DueAt must not be ceiled to {ceilDays} days when actual stability is {after.Stability}");
        }
    }

    // ── Mastery score golden vectors ────────────────────────────────────────
    // mastery = 1 − exp(−stability / 20); saturates toward 1.

    [Theory]
    [InlineData(1.6,  1e-12)]  // fresh Good: matches CortexParityTests.cs vector
    [InlineData(3.2,  1e-10)]  // stability 2.0 → Good
    [InlineData(6.3,  1e-10)]  // stability 3.0 → Easy
    [InlineData(0.5,  1e-12)]  // stability clamp (Again from 1.0)
    public void MasteryScore_equals_fsrs_formula(double stability, double tolerance)
    {
        // We instead test by building a mastery record directly with the target stability.
        // Use reviewGrade that gives us exactly this stability from initial=stability/1.6.
        var initialStability = stability / 1.6;
        var seed = ConceptMastery.New("user-1", "az-900", "concept-1") with { Stability = initialStability };

        var after = ReviewScheduler.Apply(seed, ReviewGrade.Good, Now);

        after.Stability.Should().BeApproximately(stability, tolerance);
        after.MasteryScore.Should().BeApproximately(1 - Math.Exp(-stability / 20), tolerance);
    }

    // ── Reps / lapses counters ──────────────────────────────────────────────

    [Fact]
    public void Apply_always_increments_reps()
    {
        var m = ConceptMastery.New("user-1", "az-900", "concept-1") with { Reps = 5 };

        var after = ReviewScheduler.Apply(m, ReviewGrade.Good, Now);

        after.Reps.Should().Be(6);
    }

    [Fact]
    public void Apply_Again_increments_lapses_hard_good_easy_do_not()
    {
        var seed = ConceptMastery.New("user-1", "az-900", "concept-1") with { Lapses = 2 };

        ReviewScheduler.Apply(seed, ReviewGrade.Again, Now).Lapses.Should().Be(3);
        ReviewScheduler.Apply(seed, ReviewGrade.Hard,  Now).Lapses.Should().Be(2);
        ReviewScheduler.Apply(seed, ReviewGrade.Good,  Now).Lapses.Should().Be(2);
        ReviewScheduler.Apply(seed, ReviewGrade.Easy,  Now).Lapses.Should().Be(2);
    }

    // ── Difficulty clamp ────────────────────────────────────────────────────

    [Fact]
    public void Difficulty_stays_within_1_to_10_range()
    {
        var maxDiff = ConceptMastery.New("user-1", "az-900", "concept-1") with { Difficulty = 10.0 };
        var minDiff = ConceptMastery.New("user-1", "az-900", "concept-1") with { Difficulty = 1.0 };

        // Again on max difficulty: 10 + 0.8 = 10.8, clamped to 10.
        ReviewScheduler.Apply(maxDiff, ReviewGrade.Again, Now).Difficulty.Should().Be(10);

        // Good on min difficulty: 1 - 0.15 = 0.85, clamped to 1.
        ReviewScheduler.Apply(minDiff, ReviewGrade.Good, Now).Difficulty.Should().Be(1);
    }
}
