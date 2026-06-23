using FluentAssertions;
using Microlingo.Application.Services;
using Microlingo.Domain.Gamification;
using Xunit;

namespace Microlingo.Application.Tests;

public sealed class AchievementServiceTests
{
    private const string UserId = "user-1";

    private static AchievementService Build(InMemoryUserRepository users)
        => new(new FakeUserContext(UserId, "Tester"), users);

    [Fact]
    public async Task GetAllAsync_lists_every_tier_with_none_unlocked_for_a_fresh_profile()
    {
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile(UserId));

        var board = await Build(users).GetAllAsync();

        board.Total.Should().Be(AchievementEngine.Tiers.Count);
        board.Unlocked.Should().Be(0);
        board.Achievements.Should().OnlyContain(a => !a.Unlocked);
    }

    [Fact]
    public async Task GetAllAsync_marks_tiers_unlocked_when_threshold_is_met()
    {
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile(UserId) with { StreakDays = 30 });

        var board = await Build(users).GetAllAsync();

        var streakSeven = board.Achievements.Single(a => a.Id == "streak-7");
        var streakThirty = board.Achievements.Single(a => a.Id == "streak-30");
        var streakHundred = board.Achievements.Single(a => a.Id == "streak-100");

        streakSeven.Unlocked.Should().BeTrue();
        streakThirty.Unlocked.Should().BeTrue();
        streakThirty.Progress.Should().Be(30); // capped at threshold
        streakHundred.Unlocked.Should().BeFalse();
        streakHundred.Progress.Should().Be(30); // partial progress toward 100
    }

    [Fact]
    public async Task GetAllAsync_honours_persisted_unlocks_even_below_threshold()
    {
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile(UserId) with { Achievements = new List<string> { "gems-100" } });

        var board = await Build(users).GetAllAsync();

        board.Achievements.Single(a => a.Id == "gems-100").Unlocked.Should().BeTrue();
        board.Unlocked.Should().Be(1);
    }
}
