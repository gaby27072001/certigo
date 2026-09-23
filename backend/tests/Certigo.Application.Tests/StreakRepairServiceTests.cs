using FluentAssertions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class StreakRepairServiceTests
{
    private const string UserId = "user-1";
    private static readonly DateTimeOffset Now = new(2025, 1, 6, 12, 0, 0, TimeSpan.Zero);
    private static readonly DateOnly Today = new(2025, 1, 6);

    private static (StreakRepairService Service, InMemoryUserRepository Users, InMemoryPurchaseRepository Purchases, InMemoryEventRepository Events) Build()
    {
        var users = new InMemoryUserRepository();
        var purchases = new InMemoryPurchaseRepository();
        var events = new InMemoryEventRepository();
        var context = new FakeUserContext(UserId, "Tester");
        var service = new StreakRepairService(
            context,
            new FakeClock(Now),
            users,
            purchases,
            events,
            new InMemoryEconomyOperationRepository());
        return (service, users, purchases, events);
    }

    private static UserProfileDto Profile(int streakDays, DateOnly? lastActive, int gems)
        => TestContent.NewProfile(UserId) with { StreakDays = streakDays, LastActiveDate = lastActive, Gems = gems };

    [Fact]
    public async Task RepairAsync_bridges_gap_charges_gems_and_is_idempotent()
    {
        var (service, users, purchases, events) = Build();
        users.Seed(Profile(10, Today.AddDays(-2), gems: 100));

        var result = await service.RepairAsync(new StreakRepairRequest("r1"));

        result.Success.Should().BeTrue();
        result.GemsSpent.Should().Be(50);
        result.GemsBalance.Should().Be(50);
        result.StreakDays.Should().Be(10);
        result.LastActiveDate.Should().Be(Today.AddDays(-1));

        var stored = await users.GetAsync(UserId);
        stored!.Gems.Should().Be(50);
        stored.LastActiveDate.Should().Be(Today.AddDays(-1));
        events.Events.Should().ContainSingle(e => e.Type == "streak.repaired");

        var replay = await service.RepairAsync(new StreakRepairRequest("r1"));
        replay.Success.Should().BeTrue();
        replay.GemsBalance.Should().Be(50);
        (await users.GetAsync(UserId))!.Gems.Should().Be(50);
        purchases.CreateCount.Should().Be(1);
        events.Events.Count(e => e.Type == "streak.repaired").Should().Be(1);
    }

    [Fact]
    public async Task RepairAsync_charges_exactly_once_when_the_profile_write_conflicts_once()
    {
        // Concurrence optimiste (R-01) : un writer distinct commit entre notre lecture et
        // notre écriture → le premier upsert lève un conflit 412. Le retry relit le profil,
        // re-vérifie le solde et l'idempotence, puis débite EXACTEMENT une fois.
        var inner = new InMemoryUserRepository();
        inner.Seed(Profile(10, Today.AddDays(-2), gems: 100));
        var users = new ConflictOnceUserRepository(inner);
        var purchases = new InMemoryPurchaseRepository();
        var events = new InMemoryEventRepository();
        var service = new StreakRepairService(
            new FakeUserContext(UserId, "Tester"),
            new FakeClock(Now),
            users,
            purchases,
            events,
            new InMemoryEconomyOperationRepository());

        var result = await service.RepairAsync(new StreakRepairRequest("r1"));

        result.Success.Should().BeTrue();
        users.UpsertCalls.Should().BeGreaterThanOrEqualTo(2); // conflicted once, then re-applied
        var profile = await inner.GetAsync(UserId);
        profile!.Gems.Should().Be(50); // debited exactly once (100 - 50)
        profile.LastActiveDate.Should().Be(Today.AddDays(-1)); // bridged
        result.GemsBalance.Should().Be(profile.Gems);
        result.LastActiveDate.Should().Be(profile.LastActiveDate);
        purchases.CreateCount.Should().Be(1); // ledger written once
        (await purchases.GetByClientPurchaseIdAsync(UserId, "r1"))!.Result.GemsBalance
            .Should().Be(result.GemsBalance);
        events.Events.Count(e => e.Type == "streak.repaired").Should().Be(1);
        events.Events.Single(e => e.Type == "streak.repaired").Payload
            .Should().BeEquivalentTo(result);
    }

    [Fact]
    public async Task RepairAsync_when_streak_intact_fails()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(10, Today.AddDays(-1), gems: 100));

        var result = await service.RepairAsync(new StreakRepairRequest("r1"));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("intact");
        (await users.GetAsync(UserId))!.Gems.Should().Be(100);
    }

    [Fact]
    public async Task RepairAsync_with_insufficient_gems_fails()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(10, Today.AddDays(-2), gems: 10));

        var result = await service.RepairAsync(new StreakRepairRequest("r1"));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("insufficientGems");
        (await users.GetAsync(UserId))!.LastActiveDate.Should().Be(Today.AddDays(-2));
    }

    [Fact]
    public async Task GetStatusAsync_reports_repairable_state()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(5, Today.AddDays(-3), gems: 100));

        var status = await service.GetStatusAsync();

        status.Repairable.Should().BeTrue();
        status.RepairCostGems.Should().Be(50);
        status.StreakDays.Should().Be(5);
        status.Reason.Should().BeNull();
    }

    [Fact]
    public async Task GetStatusAsync_publishes_the_balance_and_the_instant_the_window_closes()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(5, Today.AddDays(-3), gems: 120));

        var status = await service.GetStatusAsync();

        // Last active 2025-01-03: repairable through the 11th, closed from 2025-01-12T00:00Z.
        status.Gems.Should().Be(120);
        status.RepairExpiresAt.Should().Be(new DateTimeOffset(2025, 1, 12, 0, 0, 0, TimeSpan.Zero));
        status.CoveredByFreeze.Should().BeFalse("two missed days are beyond what one token absorbs");
    }

    [Fact]
    public async Task GetStatusAsync_says_when_a_freeze_token_already_covers_the_missed_day()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(5, Today.AddDays(-2), gems: 120) with { FreezeTokens = 1 });

        var status = await service.GetStatusAsync();

        // The paid repair stays available — it keeps the token and adds the day — but the
        // learner must be told that doing nothing already saves the streak.
        status.Repairable.Should().BeTrue();
        status.CoveredByFreeze.Should().BeTrue();
    }

    [Fact]
    public async Task GetStatusAsync_publishes_no_window_and_no_coverage_for_an_intact_streak()
    {
        var (service, users, _, _) = Build();
        users.Seed(Profile(5, Today.AddDays(-1), gems: 120) with { FreezeTokens = 1 });

        var status = await service.GetStatusAsync();

        status.Repairable.Should().BeFalse();
        status.Reason.Should().Be("intact");
        status.RepairExpiresAt.Should().BeNull();
        status.CoveredByFreeze.Should().BeFalse();
        status.Gems.Should().Be(120);
    }
}
