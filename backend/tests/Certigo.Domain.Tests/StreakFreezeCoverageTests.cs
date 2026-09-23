using FluentAssertions;
using Certigo.Domain.Gamification;
using Xunit;

namespace Certigo.Domain.Tests;

/// <summary>
/// <see cref="StreakService.FreezeCoversGap"/> is published to clients so they can say
/// "your freeze will carry this" instead of selling a repair the learner does not need.
/// It is a separate predicate, so nothing but this parity check stops it from drifting
/// away from the rule that actually spends the token, <see cref="StreakService.UpdateStreak"/>.
/// </summary>
public sealed class StreakFreezeCoverageTests
{
    private static readonly DateOnly Today = new(2025, 1, 6);

    public static TheoryData<int, int> Gaps()
    {
        var data = new TheoryData<int, int>();
        for (var daysSinceActive = 0; daysSinceActive <= 10; daysSinceActive++)
        {
            for (var freezeTokens = 0; freezeTokens <= 2; freezeTokens++)
            {
                data.Add(daysSinceActive, freezeTokens);
            }
        }

        return data;
    }

    [Theory]
    [MemberData(nameof(Gaps))]
    public void Coverage_predicts_exactly_when_the_next_goal_spends_a_freeze(int daysSinceActive, int freezeTokens)
    {
        var last = Today.AddDays(-daysSinceActive);
        var stats = new GamificationStats(
            Xp: 0,
            Level: 1,
            StreakDays: 10,
            LastActiveDate: last,
            FreezeTokens: freezeTokens,
            DailyGoalXp: 50,
            DailyXpEarned: 50);

        var next = StreakService.UpdateStreak(stats, Today, goalMet: true);
        var spentFreeze = next.FreezeTokens == freezeTokens - 1;

        StreakService.FreezeCoversGap(freezeTokens, last, Today).Should().Be(
            spentFreeze,
            $"{daysSinceActive} day(s) since the last active day with {freezeTokens} token(s)");
    }

    [Fact]
    public void A_covered_gap_keeps_the_streak_length_when_the_goal_is_met()
    {
        // Positive control: without it, a predicate that is never true would pass the
        // parity theory for every row where UpdateStreak spends nothing.
        var stats = new GamificationStats(0, 1, 12, Today.AddDays(-2), 1, 50, 50);

        StreakService.FreezeCoversGap(1, Today.AddDays(-2), Today).Should().BeTrue();
        var next = StreakService.UpdateStreak(stats, Today, goalMet: true);
        next.StreakDays.Should().Be(12);
        next.FreezeTokens.Should().Be(0);
    }

    [Fact]
    public void No_recorded_activity_is_never_covered()
    {
        StreakService.FreezeCoversGap(3, null, Today).Should().BeFalse();
    }
}
