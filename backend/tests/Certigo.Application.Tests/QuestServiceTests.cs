using FluentAssertions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class QuestServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public InMemoryEconomyOperationRepository EconomyOperations { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public DateOnly Today => DateOnly.FromDateTime(Clock.UtcNow.UtcDateTime);

    public QuestService Build()
        => new(new FakeUserContext(UserId, "Tester"), Clock, Users, Events, EconomyOperations);

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
    public async Task ClaimAsync_awards_exactly_once_when_the_profile_write_conflicts_once()
    {
        // Concurrence optimiste (R-01) : un writer distinct commit entre notre lecture et
        // notre écriture → le premier upsert lève un conflit 412. Le retry relit le profil,
        // re-vérifie l'idempotence de la réclamation, puis crédite EXACTEMENT une fois.
        var inner = new InMemoryUserRepository();
        inner.Seed(TestContent.NewProfile("user-1") with
        {
            Gems = 100,
            DailyXpDate = new DateOnly(2025, 1, 6),
            DailyXpEarned = 999,
            DailyLessonsCompleted = 99,
            DailyCorrectAnswers = 99,
            DailyPerfectLessons = 9,
        });
        var users = new ConflictOnceUserRepository(inner);
        var clock = new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var events = new InMemoryEventRepository();
        var service = new QuestService(
            new FakeUserContext("user-1", "Tester"),
            clock,
            users,
            events,
            new InMemoryEconomyOperationRepository());

        var quest = (await service.GetTodayAsync()).Quests[0];
        var result = await service.ClaimAsync(new ClaimQuestRequest(quest.Id));

        result.Success.Should().BeTrue();
        result.Claimed.Should().BeTrue();
        users.UpsertCalls.Should().BeGreaterThanOrEqualTo(2); // conflicted once, then re-applied
        var profile = await inner.GetAsync("user-1");
        profile!.Gems.Should().Be(100 + quest.RewardGems); // credited exactly once
        result.GemsBalance.Should().Be(profile.Gems);
        events.Events.Single(e => e.Type == "quest.claimed").Payload
            .Should().BeEquivalentTo(result);
        profile.DailyQuestClaims!.Count(id => id == quest.Id).Should().Be(1); // claim recorded once
        events.Events.Count(e => e.Type == "quest.claimed").Should().Be(1);
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
