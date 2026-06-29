using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Gamification;
using Certigo.Domain.Notifications;

namespace Certigo.Application.Services;

public interface IStreakRepairService
{
    Task<StreakStatusDto> GetStatusAsync(CancellationToken cancellationToken = default);
    Task<StreakRepairResultDto> RepairAsync(StreakRepairRequest request, CancellationToken cancellationToken = default);
}

public sealed class StreakRepairService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IPurchaseRepository purchases,
    IEventRepository events,
    IIdempotencyGuard idempotency) : IStreakRepairService
{
    public async Task<StreakStatusDto> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var assessment = StreakRepairPolicy.Assess(profile.StreakDays, profile.LastActiveDate, today);
        return new StreakStatusDto(
            profile.StreakDays,
            profile.LastActiveDate,
            profile.FreezeTokens,
            assessment.Repairable,
            assessment.CostGems,
            assessment.Reason);
    }

    public async Task<StreakRepairResultDto> RepairAsync(StreakRepairRequest request, CancellationToken cancellationToken = default)
    {
        // Reuse the purchase ledger for idempotency so a double-tap repairs and
        // charges exactly once (mirrors ShopService.PurchaseAsync).
        if (await idempotency.HasBeenProcessedAsync(userContext.UserId, request.ClientRepairId, cancellationToken))
        {
            var prior = await purchases.GetByClientPurchaseIdAsync(userContext.UserId, request.ClientRepairId, cancellationToken);
            var existing = await users.GetAsync(userContext.UserId, cancellationToken);
            return new StreakRepairResultDto(
                true,
                existing?.StreakDays ?? 0,
                prior!.GemsSpent,
                prior.Result.GemsBalance,
                existing?.LastActiveDate,
                null);
        }

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var assessment = StreakRepairPolicy.Assess(profile.StreakDays, profile.LastActiveDate, today);

        if (!assessment.Repairable)
        {
            return new StreakRepairResultDto(false, profile.StreakDays, 0, profile.Gems, profile.LastActiveDate, assessment.Reason);
        }

        if (profile.Gems < assessment.CostGems)
        {
            return new StreakRepairResultDto(false, profile.StreakDays, 0, profile.Gems, profile.LastActiveDate, "insufficientGems");
        }

        var updated = profile with
        {
            Gems = profile.Gems - assessment.CostGems,
            LastActiveDate = assessment.BridgeTo,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var now = clock.UtcNow;
        var result = new StreakRepairResultDto(true, updated.StreakDays, assessment.CostGems, updated.Gems, updated.LastActiveDate, null);
        var record = new PurchaseRecord(
            $"streakrepair::{request.ClientRepairId}",
            userContext.UserId,
            request.ClientRepairId,
            "streak-repair",
            assessment.CostGems,
            now,
            new PurchaseResultDto(true, "streak-repair", assessment.CostGems, updated.Gems, updated.FreezeTokens, null));
        await purchases.CreateAsync(record, cancellationToken);
        await idempotency.MarkAsProcessedAsync(userContext.UserId, request.ClientRepairId, cancellationToken);
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "streak.repaired", now, result), cancellationToken);

        return result;
    }
}
