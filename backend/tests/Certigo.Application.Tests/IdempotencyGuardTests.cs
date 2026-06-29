using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

/// Unit tests for the <see cref="IIdempotencyGuard"/> contract and its integration
/// with the four services that use it (QuizService, ShopService, ExamService,
/// StreakRepairService). Tests use the in-memory fake to verify the guard's
/// semantics independently of any Cosmos infrastructure.
public sealed class IdempotencyGuardTests
{
    private static readonly string UserId = "user-idempotency";
    private static readonly string Key = "op-key-1";

    [Fact]
    public async Task HasBeenProcessed_returns_false_before_any_mark()
    {
        var guard = new InMemoryIdempotencyGuard();

        var result = await guard.HasBeenProcessedAsync(UserId, Key);

        result.Should().BeFalse();
    }

    [Fact]
    public async Task MarkAsProcessed_then_HasBeenProcessed_returns_true()
    {
        var guard = new InMemoryIdempotencyGuard();

        await guard.MarkAsProcessedAsync(UserId, Key);
        var result = await guard.HasBeenProcessedAsync(UserId, Key);

        result.Should().BeTrue();
    }

    [Fact]
    public async Task MarkAsProcessed_is_idempotent_successive_marks_return_true()
    {
        var guard = new InMemoryIdempotencyGuard();

        await guard.MarkAsProcessedAsync(UserId, Key);
        await guard.MarkAsProcessedAsync(UserId, Key); // second mark must not throw

        (await guard.HasBeenProcessedAsync(UserId, Key)).Should().BeTrue();
    }

    [Fact]
    public async Task Different_keys_are_independent()
    {
        var guard = new InMemoryIdempotencyGuard();
        const string keyA = "key-a";
        const string keyB = "key-b";

        await guard.MarkAsProcessedAsync(UserId, keyA);

        (await guard.HasBeenProcessedAsync(UserId, keyA)).Should().BeTrue();
        (await guard.HasBeenProcessedAsync(UserId, keyB)).Should().BeFalse();
    }

    [Fact]
    public async Task Different_partition_keys_are_independent()
    {
        var guard = new InMemoryIdempotencyGuard();
        const string userA = "user-a";
        const string userB = "user-b";

        await guard.MarkAsProcessedAsync(userA, Key);

        (await guard.HasBeenProcessedAsync(userA, Key)).Should().BeTrue();
        (await guard.HasBeenProcessedAsync(userB, Key)).Should().BeFalse();
    }

    [Fact]
    public async Task ShopService_PurchaseAsync_charges_only_once_on_replay()
    {
        var users = new InMemoryUserRepository();
        var purchases = new InMemoryPurchaseRepository();
        var events = new InMemoryEventRepository();
        var clock = new FakeClock(DateTimeOffset.UtcNow);
        var idempotency = new InMemoryIdempotencyGuard();
        var profile = TestContent.NewProfile(UserId) with { Gems = 500, FreezeTokens = 0 };
        users.Seed(profile);

        var service = new ShopService(new FakeUserContext(UserId, "Test"), clock, users, purchases, events, idempotency);
        var request = new PurchaseRequest("streak-freeze", "purchase-key-1");

        var first = await service.PurchaseAsync(request);
        var second = await service.PurchaseAsync(request); // replay

        first.Success.Should().BeTrue();
        second.Success.Should().BeTrue();
        second.GemsBalance.Should().Be(first.GemsBalance);

        // The guard must have recorded the processing.
        (await idempotency.HasBeenProcessedAsync(UserId, "purchase-key-1")).Should().BeTrue();

        // Gems charged exactly once.
        var storedProfile = await users.GetAsync(UserId);
        storedProfile!.Gems.Should().Be(500 - first.GemsSpent);

        // Purchase record written exactly once.
        purchases.CreateCount.Should().Be(1);
    }

    [Fact]
    public async Task StreakRepairService_RepairAsync_repairs_once_on_replay()
    {
        var users = new InMemoryUserRepository();
        var purchases = new InMemoryPurchaseRepository();
        var events = new InMemoryEventRepository();
        var clock = new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var idempotency = new InMemoryIdempotencyGuard();

        users.Seed(TestContent.NewProfile(UserId) with
        {
            StreakDays = 10,
            LastActiveDate = today.AddDays(-2),
            Gems = 200
        });

        var service = new StreakRepairService(new FakeUserContext(UserId, "Test"), clock, users, purchases, events, idempotency);

        var first = await service.RepairAsync(new StreakRepairRequest("repair-key-1"));
        var second = await service.RepairAsync(new StreakRepairRequest("repair-key-1")); // replay

        first.Success.Should().BeTrue();
        second.GemsBalance.Should().Be(first.GemsBalance);

        (await idempotency.HasBeenProcessedAsync(UserId, "repair-key-1")).Should().BeTrue();
        purchases.CreateCount.Should().Be(1);
    }
}
