using FluentAssertions;
using Certigo.Domain.Gamification;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class StreakRepairPolicyTests
{
    private static readonly DateOnly Today = new(2025, 1, 6);

    [Fact]
    public void Active_yesterday_is_intact()
    {
        var a = StreakRepairPolicy.Assess(10, Today.AddDays(-1), Today);

        a.Repairable.Should().BeFalse();
        a.Reason.Should().Be("intact");
    }

    [Fact]
    public void Active_today_is_intact()
    {
        var a = StreakRepairPolicy.Assess(10, Today, Today);

        a.Repairable.Should().BeFalse();
        a.Reason.Should().Be("intact");
    }

    [Fact]
    public void Missed_one_day_is_repairable_and_bridges_to_yesterday()
    {
        var a = StreakRepairPolicy.Assess(10, Today.AddDays(-2), Today);

        a.Repairable.Should().BeTrue();
        a.Reason.Should().BeNull();
        a.CostGems.Should().Be(StreakRepairPolicy.CostGems);
        a.BridgeTo.Should().Be(Today.AddDays(-1));
    }

    [Fact]
    public void Missed_seven_days_is_still_repairable()
    {
        var a = StreakRepairPolicy.Assess(30, Today.AddDays(-8), Today);

        a.Repairable.Should().BeTrue();
    }

    [Fact]
    public void Missed_eight_days_is_expired()
    {
        var a = StreakRepairPolicy.Assess(30, Today.AddDays(-9), Today);

        a.Repairable.Should().BeFalse();
        a.Reason.Should().Be("expired");
    }

    [Fact]
    public void No_streak_is_not_repairable()
    {
        StreakRepairPolicy.Assess(0, Today.AddDays(-2), Today).Reason.Should().Be("noStreak");
        StreakRepairPolicy.Assess(5, null, Today).Reason.Should().Be("noStreak");
    }

    [Fact]
    public void Repairable_gap_publishes_its_last_day_and_the_utc_instant_it_closes()
    {
        // Last active 2025-01-04: repairable while at most MaxGapDays days are missed,
        // i.e. through 2025-01-12, and closed from the first UTC instant of the 13th.
        var a = StreakRepairPolicy.Assess(10, Today.AddDays(-2), Today);

        a.LastRepairableDay.Should().Be(new DateOnly(2025, 1, 12));
        a.ExpiresAt.Should().Be(new DateTimeOffset(2025, 1, 13, 0, 0, 0, TimeSpan.Zero));
    }

    [Theory]
    [InlineData(2)]
    [InlineData(5)]
    [InlineData(8)]
    public void Published_window_agrees_with_the_policy_on_both_sides_of_its_edge(int daysSinceActive)
    {
        // The deadline is only worth publishing if the policy itself honours it: still
        // repairable on the last published day, expired on the day after.
        var last = Today.AddDays(-daysSinceActive);
        var lastDay = StreakRepairPolicy.Assess(10, last, Today).LastRepairableDay!.Value;

        StreakRepairPolicy.Assess(10, last, lastDay).Repairable.Should().BeTrue();
        StreakRepairPolicy.Assess(10, last, lastDay.AddDays(1)).Reason.Should().Be("expired");
    }

    [Theory]
    [InlineData(10, 0, "intact")]
    [InlineData(10, 1, "intact")]
    [InlineData(30, 9, "expired")]
    [InlineData(0, 2, "noStreak")]
    public void A_streak_that_cannot_be_repaired_publishes_no_window(
        int streakDays,
        int daysSinceActive,
        string reason)
    {
        var a = StreakRepairPolicy.Assess(streakDays, Today.AddDays(-daysSinceActive), Today);

        a.Reason.Should().Be(reason);
        a.LastRepairableDay.Should().BeNull();
        a.ExpiresAt.Should().BeNull();
    }
}
