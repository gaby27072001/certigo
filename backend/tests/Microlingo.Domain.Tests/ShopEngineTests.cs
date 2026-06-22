using FluentAssertions;
using Microlingo.Domain.Gamification;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class ShopEngineTests
{
    private static ShopItem Freeze => ShopCatalog.Find("streak-freeze")!;

    [Fact]
    public void Evaluate_streak_freeze_deducts_gems_and_adds_token()
    {
        var result = ShopEngine.Evaluate(new PurchaseState(Gems: 300, FreezeTokens: 0), Freeze);

        result.Success.Should().BeTrue();
        result.Error.Should().Be(PurchaseError.None);
        result.GemsSpent.Should().Be(Freeze.PriceGems);
        result.State.Gems.Should().Be(300 - Freeze.PriceGems);
        result.State.FreezeTokens.Should().Be(1);
    }

    [Fact]
    public void Evaluate_insufficient_gems_fails_without_mutation()
    {
        var state = new PurchaseState(Gems: 50, FreezeTokens: 0);

        var result = ShopEngine.Evaluate(state, Freeze);

        result.Success.Should().BeFalse();
        result.Error.Should().Be(PurchaseError.InsufficientGems);
        result.GemsSpent.Should().Be(0);
        result.State.Should().Be(state);
    }

    [Fact]
    public void Evaluate_at_max_tokens_fails()
    {
        var state = new PurchaseState(Gems: 1000, FreezeTokens: ShopCatalog.MaxFreezeTokens);

        var result = ShopEngine.Evaluate(state, Freeze);

        result.Success.Should().BeFalse();
        result.Error.Should().Be(PurchaseError.AlreadyAtMax);
        result.State.Should().Be(state);
    }

    [Fact]
    public void Evaluate_bundle_caps_tokens_at_maximum()
    {
        var bundle = ShopCatalog.Find("streak-freeze-bundle")!;

        var result = ShopEngine.Evaluate(new PurchaseState(Gems: 1000, FreezeTokens: 2), bundle);

        result.Success.Should().BeTrue();
        result.State.FreezeTokens.Should().Be(ShopCatalog.MaxFreezeTokens);
    }
}
