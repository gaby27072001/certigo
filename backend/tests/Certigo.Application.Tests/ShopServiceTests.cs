using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class ShopServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryPurchaseRepository Purchases { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public InMemoryEconomyOperationRepository EconomyOperations { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public ShopService Build()
        => new(
            new FakeUserContext(UserId, "Tester"),
            Clock,
            Users,
            Purchases,
            Events,
            EconomyOperations);

    public UserProfileDto SeedProfile(int gems, int freezeTokens)
    {
        var profile = TestContent.NewProfile(UserId) with { Gems = gems, FreezeTokens = freezeTokens };
        Users.Seed(profile);
        return profile;
    }
}

public sealed class ShopServiceTests
{
    [Fact]
    public async Task PurchaseAsync_success_deducts_gems_persists_and_records()
    {
        var h = new ShopServiceHarness();
        h.SeedProfile(gems: 300, freezeTokens: 0);
        var service = h.Build();

        var result = await service.PurchaseAsync(new PurchaseRequest("streak-freeze", "p1"));

        result.Success.Should().BeTrue();
        result.GemsSpent.Should().Be(200);
        result.GemsBalance.Should().Be(100);
        result.FreezeTokens.Should().Be(1);
        result.Error.Should().BeNull();

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(100);
        profile.FreezeTokens.Should().Be(1);
        h.Purchases.CreateCount.Should().Be(1);
        h.Events.Events.Should().ContainSingle(e => e.Type == "shop.purchased");
    }

    [Fact]
    public async Task PurchaseAsync_is_idempotent_per_client_purchase_id()
    {
        var h = new ShopServiceHarness();
        h.SeedProfile(gems: 300, freezeTokens: 0);
        var service = h.Build();

        var first = await service.PurchaseAsync(new PurchaseRequest("streak-freeze", "p1"));
        var second = await service.PurchaseAsync(new PurchaseRequest("streak-freeze", "p1"));

        second.Should().BeEquivalentTo(first);
        h.Purchases.CreateCount.Should().Be(1);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(100); // charged only once
    }

    [Fact]
    public async Task PurchaseAsync_returns_legacy_ledger_without_debiting_again()
    {
        var h = new ShopServiceHarness();
        h.SeedProfile(gems: 100, freezeTokens: 1);
        var result = new PurchaseResultDto(true, "streak-freeze", 200, 100, 1, null);
        await h.Purchases.CreateAsync(new PurchaseRecord(
            "purchase::legacy",
            h.UserId,
            "legacy",
            "streak-freeze",
            200,
            h.Clock.UtcNow,
            result));

        var replay = await h.Build().PurchaseAsync(new PurchaseRequest("streak-freeze", "legacy"));

        replay.Should().BeEquivalentTo(result);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(100);
        profile.FreezeTokens.Should().Be(1);
        (await h.EconomyOperations.GetAsync(
            h.UserId,
            EconomyOperationRecord.IdFor("shop", "legacy"))).Should().BeNull();
    }

    [Fact]
    public async Task PurchaseAsync_charges_exactly_once_when_the_profile_write_conflicts_once()
    {
        // Concurrence optimiste (R-01) : un writer concurrent distinct bouscule le profil
        // entre notre lecture et notre écriture, donc le premier upsert lève un conflit 412.
        // Le retry doit relire, ré-évaluer la garde de solde, puis débiter EXACTEMENT une fois
        // — jamais deux fois, jamais un 409 spurious propagé à l'appelant.
        var inner = new InMemoryUserRepository();
        inner.Seed(TestContent.NewProfile("user-1") with { Gems = 300, FreezeTokens = 0 });
        var users = new ConflictOnceUserRepository(inner);
        var clock = new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var purchases = new InMemoryPurchaseRepository();
        var events = new InMemoryEventRepository();
        var service = new ShopService(
            new FakeUserContext("user-1", "Tester"),
            clock,
            users,
            purchases,
            events,
            new InMemoryEconomyOperationRepository());

        var result = await service.PurchaseAsync(new PurchaseRequest("streak-freeze", "p1"));

        result.Success.Should().BeTrue();
        result.Error.Should().BeNull();
        users.UpsertCalls.Should().BeGreaterThanOrEqualTo(2); // conflicted once, then re-applied
        var profile = await inner.GetAsync("user-1");
        profile!.Gems.Should().Be(100); // debited exactly once, not doubled
        profile.FreezeTokens.Should().Be(1);
        purchases.CreateCount.Should().Be(1); // ledger written once
        events.Events.Count(e => e.Type == "shop.purchased").Should().Be(1);
    }

    [Fact]
    public async Task PurchaseAsync_reconciles_event_failure_without_double_debit()
    {
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile("user-1") with { Gems = 300 });
        var purchases = new InMemoryPurchaseRepository();
        var events = new InMemoryEventRepository();
        var service = new ShopService(
            new FakeUserContext("user-1", "Tester"),
            new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero)),
            users,
            purchases,
            new FailOnceEventRepository(events),
            new InMemoryEconomyOperationRepository());
        var request = new PurchaseRequest("streak-freeze", "event-retry");

        var first = () => service.PurchaseAsync(request);
        await first.Should().ThrowAsync<InvalidOperationException>();
        var afterFailure = await users.GetAsync("user-1");
        var result = await service.PurchaseAsync(request);
        var afterRetry = await users.GetAsync("user-1");

        result.Success.Should().BeTrue();
        afterRetry!.Gems.Should().Be(afterFailure!.Gems);
        afterRetry.FreezeTokens.Should().Be(afterFailure.FreezeTokens);
        purchases.CreateCount.Should().Be(1);
        events.Events.Count(e => e.Type == "shop.purchased").Should().Be(1);
    }

    [Fact]
    public async Task PurchaseAsync_rejects_a_stale_concurrent_debit_without_later_reapplying_it()
    {
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile("user-1") with { Gems = 300 });
        var operations = new InMemoryEconomyOperationRepository();
        var purchases = new InMemoryPurchaseRepository();
        var service = new ShopService(
            new FakeUserContext("user-1", "Tester"),
            new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero)),
            users,
            purchases,
            new InMemoryEventRepository(),
            new MutateOnceOnEconomyCreateRepository(
                operations,
                () => users.ForceConcurrentWrite("user-1", profile => profile with { Gems = 100 })));
        var request = new PurchaseRequest("streak-freeze", "stale-debit");

        var first = await service.PurchaseAsync(request);
        users.ForceConcurrentWrite("user-1", profile => profile with { Gems = 500 });
        var retry = await service.PurchaseAsync(request);

        first.Success.Should().BeFalse();
        first.Error.Should().Be("insufficientGems");
        retry.Should().BeEquivalentTo(first, options => options.Excluding(result => result.GemsBalance));
        (await users.GetAsync("user-1"))!.Gems.Should().Be(500);
        purchases.CreateCount.Should().Be(0);
        var operation = await operations.GetAsync(
            "user-1",
            EconomyOperationRecord.IdFor("shop", "stale-debit"));
        operation!.Status.Should().Be(EconomyOperationRecord.FailedStatus);
    }

    [Fact]
    public async Task PurchaseAsync_insufficient_gems_fails_without_side_effects()
    {
        var h = new ShopServiceHarness();
        h.SeedProfile(gems: 50, freezeTokens: 0);
        var service = h.Build();

        var result = await service.PurchaseAsync(new PurchaseRequest("streak-freeze", "p1"));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("insufficientGems");
        h.Purchases.CreateCount.Should().Be(0);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(50);
        profile.FreezeTokens.Should().Be(0);
    }

    [Fact]
    public async Task PurchaseAsync_unknown_item_fails()
    {
        var h = new ShopServiceHarness();
        h.SeedProfile(gems: 300, freezeTokens: 0);
        var service = h.Build();

        var result = await service.PurchaseAsync(new PurchaseRequest("does-not-exist", "p1"));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("unknownItem");
        h.Purchases.CreateCount.Should().Be(0);
    }

    [Fact]
    public async Task GetCatalogAsync_returns_items_and_current_balance()
    {
        var h = new ShopServiceHarness();
        h.SeedProfile(gems: 220, freezeTokens: 1);
        var service = h.Build();

        var catalog = await service.GetCatalogAsync();

        catalog.Gems.Should().Be(220);
        catalog.Items.Should().Contain(i => i.Id == "streak-freeze");
        catalog.Items.Should().OnlyContain(i => i.PriceGems > 0);
    }
}
