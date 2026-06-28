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
        var service = new StreakRepairService(context, new FakeClock(Now), users, purchases, events);
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
}
