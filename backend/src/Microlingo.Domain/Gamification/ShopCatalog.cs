namespace Microlingo.Domain.Gamification;

// The shop is the server-authoritative gem sink: gems are earned in quizzes
// (see QuizService) and can only be spent here, never minted client-side.

public enum ShopItemKind
{
    StreakFreeze,
}

public sealed record ShopItem(
    string Id,
    string Name,
    string Description,
    int PriceGems,
    ShopItemKind Kind,
    int Amount);

public static class ShopCatalog
{
    // Streak freezes are capped so the sink stays meaningful and can't be hoarded.
    public const int MaxFreezeTokens = 3;

    public static IReadOnlyList<ShopItem> Items { get; } =
    [
        new(
            "streak-freeze",
            "Gel de série",
            "Protège ta série pendant un jour d'absence.",
            200,
            ShopItemKind.StreakFreeze,
            1),
        new(
            "streak-freeze-bundle",
            "Gel de série ×2",
            "Deux gels pour voyager l'esprit tranquille.",
            350,
            ShopItemKind.StreakFreeze,
            2),
    ];

    public static ShopItem? Find(string id)
        => Items.FirstOrDefault(i => string.Equals(i.Id, id, StringComparison.OrdinalIgnoreCase));
}

public enum PurchaseError
{
    None,
    UnknownItem,
    InsufficientGems,
    AlreadyAtMax,
}

public sealed record PurchaseState(int Gems, int FreezeTokens);

public sealed record PurchaseEvaluation(
    bool Success,
    PurchaseError Error,
    PurchaseState State,
    int GemsSpent);

public static class ShopEngine
{
    // Pure purchase rules. The caller persists State only when Success is true,
    // so a failed evaluation never mutates the profile.
    public static PurchaseEvaluation Evaluate(PurchaseState state, ShopItem item)
    {
        if (state.Gems < item.PriceGems)
        {
            return new PurchaseEvaluation(false, PurchaseError.InsufficientGems, state, 0);
        }

        switch (item.Kind)
        {
            case ShopItemKind.StreakFreeze:
                if (state.FreezeTokens >= ShopCatalog.MaxFreezeTokens)
                {
                    return new PurchaseEvaluation(false, PurchaseError.AlreadyAtMax, state, 0);
                }

                var newTokens = Math.Min(ShopCatalog.MaxFreezeTokens, state.FreezeTokens + item.Amount);
                var next = state with { Gems = state.Gems - item.PriceGems, FreezeTokens = newTokens };
                return new PurchaseEvaluation(true, PurchaseError.None, next, item.PriceGems);

            default:
                return new PurchaseEvaluation(false, PurchaseError.UnknownItem, state, 0);
        }
    }
}
