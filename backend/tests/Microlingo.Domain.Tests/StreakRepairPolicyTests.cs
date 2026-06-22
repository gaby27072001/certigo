using FluentAssertions;
using Microlingo.Domain.Gamification;
using Xunit;

namespace Microlingo.Domain.Tests;

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
}
