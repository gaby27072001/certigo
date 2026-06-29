using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Gamification;
using Certigo.Domain.Notifications;

namespace Certigo.Application.Services;

public interface IShopService
{
    Task<ShopCatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default);
    Task<PurchaseResultDto> PurchaseAsync(PurchaseRequest request, CancellationToken cancellationToken = default);
}

public sealed class ShopService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IPurchaseRepository purchases,
    IEventRepository events,
    IIdempotencyGuard idempotency) : IShopService
{
    public async Task<ShopCatalogDto> GetCatalogAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken);
        var items = ShopCatalog.Items
            .Select(i => new ShopItemDto(i.Id, i.Name, i.Description, i.PriceGems, i.Kind.ToString(), i.Amount))
            .ToArray();
        return new ShopCatalogDto(profile?.Gems ?? 0, items);
    }

    public async Task<PurchaseResultDto> PurchaseAsync(PurchaseRequest request, CancellationToken cancellationToken = default)
    {
        // Only successful (side-effecting) purchases are recorded, so this guard
        // prevents double-charging an idempotent retry without blocking re-tries
        // of a previously failed purchase.
        if (await idempotency.HasBeenProcessedAsync(userContext.UserId, request.ClientPurchaseId, cancellationToken))
        {
            var prior = await purchases.GetByClientPurchaseIdAsync(userContext.UserId, request.ClientPurchaseId, cancellationToken);
            return prior!.Result;
        }

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var item = ShopCatalog.Find(request.ItemId);
        if (item is null)
        {
            return new PurchaseResultDto(false, request.ItemId, 0, profile.Gems, profile.FreezeTokens, "unknownItem");
        }

        var evaluation = ShopEngine.Evaluate(new PurchaseState(profile.Gems, profile.FreezeTokens), item);
        if (!evaluation.Success)
        {
            return new PurchaseResultDto(false, item.Id, 0, profile.Gems, profile.FreezeTokens, ErrorCode(evaluation.Error));
        }

        var updated = profile with
        {
            Gems = evaluation.State.Gems,
            FreezeTokens = evaluation.State.FreezeTokens,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var result = new PurchaseResultDto(true, item.Id, evaluation.GemsSpent, updated.Gems, updated.FreezeTokens, null);
        var now = clock.UtcNow;
        var record = new PurchaseRecord(
            $"purchase::{request.ClientPurchaseId}",
            userContext.UserId,
            request.ClientPurchaseId,
            item.Id,
            evaluation.GemsSpent,
            now,
            result);
        await purchases.CreateAsync(record, cancellationToken);
        await idempotency.MarkAsProcessedAsync(userContext.UserId, request.ClientPurchaseId, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "shop.purchased", now, result), cancellationToken);

        return result;
    }

    private static string ErrorCode(PurchaseError error) => error switch
    {
        PurchaseError.InsufficientGems => "insufficientGems",
        PurchaseError.AlreadyAtMax => "alreadyAtMax",
        PurchaseError.UnknownItem => "unknownItem",
        _ => "unknown",
    };
}
