using FluentAssertions;
using Microlingo.Domain.Gamification;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class AchievementEngineTests
{
    private static AchievementSnapshot Snapshot(
        int streak = 0, int xp = 0, int level = 1, int lessons = 0, int flawless = 0, int gems = 0)
        => new(streak, xp, level, lessons, flawless, gems);

    [Fact]
    public void NewlyUnlocked_is_empty_for_a_fresh_learner()
    {
        AchievementEngine.NewlyUnlocked(Snapshot(), Array.Empty<string>()).Should().BeEmpty();
    }

    [Fact]
    public void NewlyUnlocked_returns_first_streak_tier_at_threshold()
    {
        var unlocked = AchievementEngine.NewlyUnlocked(Snapshot(streak: 7), Array.Empty<string>());

        unlocked.Should().ContainSingle(t => t.Id == "streak-7");
    }

    [Fact]
    public void NewlyUnlocked_returns_every_crossed_tier_of_a_family_at_once()
    {
        var unlocked = AchievementEngine.NewlyUnlocked(Snapshot(streak: 100), Array.Empty<string>());

        unlocked.Where(t => t.Kind == AchievementKind.Streak).Select(t => t.Id)
            .Should().BeEquivalentTo(new[] { "streak-7", "streak-30", "streak-100" });
    }

    [Fact]
    public void NewlyUnlocked_excludes_already_unlocked_tiers()
    {
        var unlocked = AchievementEngine.NewlyUnlocked(Snapshot(streak: 30), new[] { "streak-7" });

        unlocked.Select(t => t.Id).Should().BeEquivalentTo(new[] { "streak-30" });
    }

    [Fact]
    public void NewlyUnlocked_spans_multiple_families()
    {
        var unlocked = AchievementEngine.NewlyUnlocked(Snapshot(xp: 100, lessons: 10), Array.Empty<string>());

        unlocked.Select(t => t.Id).Should().Contain(new[] { "xp-100", "lessons-10" });
    }

    [Fact]
    public void Earned_reports_all_met_thresholds()
    {
        AchievementEngine.Earned(Snapshot(level: 12))
            .Should().Contain(new[] { "level-5", "level-10" })
            .And.NotContain("level-20");
    }

    [Fact]
    public void Gems_family_never_rewards_gems_to_avoid_a_feedback_loop()
    {
        AchievementEngine.Tiers
            .Where(t => t.Kind == AchievementKind.Gems)
            .Should().OnlyContain(t => t.RewardGems == 0);
    }

    [Fact]
    public void Tier_ids_are_unique_and_findable()
    {
        var ids = AchievementEngine.Tiers.Select(t => t.Id).ToArray();
        ids.Should().OnlyHaveUniqueItems();

        AchievementEngine.Find("flawless-5").Should().NotBeNull();
        AchievementEngine.Find("does-not-exist").Should().BeNull();
    }
}
