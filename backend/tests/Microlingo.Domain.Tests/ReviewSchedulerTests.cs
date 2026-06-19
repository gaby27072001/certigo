using FluentAssertions;
using Microlingo.Domain.Progress;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class ReviewSchedulerTests
{
    [Fact]
    public void Apply_again_reduces_stability_and_increments_lapses()
    {
        var now = DateTimeOffset.UtcNow;
        var before = ConceptMastery.New("user-1", "az-900", "identity:entra")
            with { Stability = 10, Lapses = 2 };

        var after = ReviewScheduler.Apply(before, ReviewGrade.Again, now);

        after.Stability.Should().BeLessThan(before.Stability);
        after.Lapses.Should().Be(3);
        after.Reps.Should().Be(before.Reps + 1);
        after.DueAt.Should().BeAfter(now);
    }

    [Fact]
    public void Apply_good_increases_stability_and_sets_due_in_future()
    {
        var now = DateTimeOffset.UtcNow;
        var before = ConceptMastery.New("user-1", "az-900", "compute:vm")
            with { Stability = 4 };

        var after = ReviewScheduler.Apply(before, ReviewGrade.Good, now);

        after.Stability.Should().BeGreaterThan(before.Stability);
        after.DueAt.Should().Be(now.AddDays(after.Stability));
        after.LastReviewedAt.Should().Be(now);
    }
}
