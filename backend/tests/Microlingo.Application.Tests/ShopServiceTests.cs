using FluentAssertions;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;
using Xunit;

namespace Microlingo.Application.Tests;

internal sealed class ShopServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryPurchaseRepository Purchases { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";

    public ShopService Build()
        => new(new FakeUserContext(UserId, "Tester"), Clock, Users, Purchases, Events);

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
