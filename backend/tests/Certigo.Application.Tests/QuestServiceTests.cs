using FluentAssertions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class QuestServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public DateOnly Today => DateOnly.FromDateTime(Clock.UtcNow.UtcDateTime);

    public QuestService Build()
        => new(new FakeUserContext(UserId, "Tester"), Clock, Users, Events);

    public void SeedAllQuestsCompleted(int gems = 0)
    {
        var profile = TestContent.NewProfile(UserId) with
        {
            Gems = gems,
            DailyXpDate = Today,
            DailyXpEarned = 999,
            DailyLessonsCompleted = 99,
            DailyCorrectAnswers = 99,
            DailyPerfectLessons = 9,
        };
        Users.Seed(profile);
    }

    public void SeedNoActivity(int gems = 0)
    {
        var profile = TestContent.NewProfile(UserId) with { Gems = gems, DailyXpDate = Today };
        Users.Seed(profile);
    }
}

public sealed class QuestServiceTests
{
    [Fact]
    public async Task GetTodayAsync_returns_three_quests_with_balance()
    {
        var h = new QuestServiceHarness();
        h.SeedNoActivity(gems: 40);
        var service = h.Build();

        var board = await service.GetTodayAsync();

        board.Date.Should().Be(h.Today);
        board.Gems.Should().Be(40);
        board.Quests.Should().HaveCount(3);
        board.Quests.Should().OnlyContain(q => !q.Completed && !q.Claimable);
    }

    [Fact]
    public async Task GetTodayAsync_marks_completed_quests_claimable()
    {
        var h = new QuestServiceHarness();
        h.SeedAllQuestsCompleted();
        var service = h.Build();

        var board = await service.GetTodayAsync();

        board.Quests.Should().OnlyContain(q => q.Completed && q.Claimable && !q.Claimed);
    }

    [Fact]
    public async Task ClaimAsync_awards_gems_persists_and_emits_event()
    {
        var h = new QuestServiceHarness();
        h.SeedAllQuestsCompleted(gems: 100);
        var service = h.Build();

        var quest = (await service.GetTodayAsync()).Quests[0];
        var result = await service.ClaimAsync(new ClaimQuestRequest(quest.Id));

        result.Success.Should().BeTrue();
        result.GemsAwarded.Should().Be(quest.RewardGems);
        result.GemsBalance.Should().Be(100 + quest.RewardGems);
        result.Claimed.Should().BeTrue();

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(100 + quest.RewardGems);
        profile.DailyQuestClaims.Should().Contain(quest.Id);
        h.Events.Events.Should().ContainSingle(e => e.Type == "quest.claimed");
    }

    [Fact]
    public async Task ClaimAsync_is_idempotent()
    {
        var h = new QuestServiceHarness();
        h.SeedAllQuestsCompleted(gems: 0);
        var service = h.Build();

        var quest = (await service.GetTodayAsync()).Quests[0];
        var first = await service.ClaimAsync(new ClaimQuestRequest(quest.Id));
        var second = await service.ClaimAsync(new ClaimQuestRequest(quest.Id));

        first.GemsAwarded.Should().Be(quest.RewardGems);
        second.Success.Should().BeTrue();
        second.GemsAwarded.Should().Be(0);
        second.Claimed.Should().BeTrue();

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(quest.RewardGems); // awarded exactly once
    }

    [Fact]
    public async Task ClaimAsync_rejects_incomplete_quest_without_side_effects()
    {
        var h = new QuestServiceHarness();
        h.SeedNoActivity(gems: 10);
        var service = h.Build();

        var quest = (await service.GetTodayAsync()).Quests[0];
        var result = await service.ClaimAsync(new ClaimQuestRequest(quest.Id));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("notCompleted");
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(10);
    }

    [Fact]
    public async Task ClaimAsync_rejects_unknown_quest()
    {
        var h = new QuestServiceHarness();
        h.SeedAllQuestsCompleted();
        var service = h.Build();

        var result = await service.ClaimAsync(new ClaimQuestRequest("does-not-exist"));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("unknownQuest");
    }
}
