using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Certigo.Domain.Exam;
using Certigo.Domain.Gamification;
using Certigo.Domain.Integrity;
using Certigo.Domain.Notifications;
using Certigo.Domain.Progress;
using Certigo.Domain.Readiness;
using Certigo.Domain.Recommendation;
using Certigo.Domain.Social;
using Certigo.Domain.Tutor;

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
    IEconomyOperationRepository economyOperations) : IShopService
{
    private static readonly string[] EconomySteps = ["ledger", "profile", "events"];

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
        var operationId = EconomyOperationRecord.IdFor("shop", request.ClientPurchaseId);
        var existingOperation = await economyOperations.GetAsync(
            userContext.UserId,
            operationId,
            cancellationToken);
        if (existingOperation is not null)
        {
            return await ResumePurchaseAsync(existingOperation, cancellationToken);
        }

        var prior = await purchases.GetByClientPurchaseIdAsync(
            userContext.UserId,
            request.ClientPurchaseId,
            cancellationToken);
        if (prior is not null)
        {
            return prior.Result;
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

        var result = new PurchaseResultDto(
            true,
            item.Id,
            evaluation.GemsSpent,
            evaluation.State.Gems,
            evaluation.State.FreezeTokens,
            null);
        var record = new PurchaseRecord(
            $"purchase::{request.ClientPurchaseId}",
            userContext.UserId,
            request.ClientPurchaseId,
            item.Id,
            evaluation.GemsSpent,
            clock.UtcNow,
            result);
        var operation = await StartPurchaseOperationAsync(
            record,
            evaluation.State.FreezeTokens - profile.FreezeTokens,
            cancellationToken);
        return await ResumePurchaseAsync(operation, cancellationToken);
    }

    private Task<EconomyOperationRecord> StartPurchaseOperationAsync(
        PurchaseRecord record,
        int freezeTokensGranted,
        CancellationToken cancellationToken) =>
        DurableEconomy.StartAsync(
            economyOperations,
            userContext.UserId,
            "shop",
            record.ClientPurchaseId,
            new ShopEconomyPayload(record, freezeTokensGranted),
            EconomySteps,
            record.PurchasedAt,
            cancellationToken);

    private async Task<PurchaseResultDto> ResumePurchaseAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken)
    {
        var payload = DurableEconomy.ReadPayload<ShopEconomyPayload>(operation);
        if (operation.Status == EconomyOperationRecord.FailedStatus)
        {
            return await FailedPurchaseAsync(payload, operation.FailureCode, cancellationToken);
        }

        try
        {
            var profileOutcome = await DurableEconomy.ApplyProfileOutcomeStepAsync(
                economyOperations,
                users,
                userContext.UserId,
                userContext.DisplayName,
                operation,
                profile =>
                {
                    if (profile.Gems < payload.Record.GemsSpent)
                    {
                        throw new EconomyOperationRejectedException("insufficientGems");
                    }

                    var updated = profile with
                    {
                        Gems = profile.Gems - payload.Record.GemsSpent,
                        FreezeTokens = profile.FreezeTokens + payload.FreezeTokensGranted,
                    };
                    return (updated, payload.Record.Result with
                    {
                        GemsBalance = updated.Gems,
                        FreezeTokens = updated.FreezeTokens,
                    });
                },
                payload.Record.Result,
                cancellationToken);
            operation = profileOutcome.Operation;
            var result = profileOutcome.Outcome;
            var record = payload.Record with { Result = result };

            operation = await DurableEconomy.RunStepAsync(
                economyOperations,
                operation,
                "ledger",
                async () =>
                {
                    try
                    {
                        await purchases.CreateAsync(record, cancellationToken);
                    }
                    catch (DuplicateRecordException)
                    {
                        var existing = await purchases.GetByClientPurchaseIdAsync(
                            userContext.UserId,
                            record.ClientPurchaseId,
                            cancellationToken);
                        if (existing?.ItemId != record.ItemId)
                        {
                            throw new ConcurrencyConflictException(
                                $"Purchase '{record.ClientPurchaseId}' conflicts with another item.");
                        }
                    }
                },
                cancellationToken);

            await DurableEconomy.RunStepAsync(
                economyOperations,
                operation,
                "events",
                () => events.AddAsync(
                    new LearningEvent(
                        DurableEconomy.EventId(operation.Id, "shop.purchased"),
                        userContext.UserId,
                        "shop.purchased",
                        record.PurchasedAt,
                        result),
                    cancellationToken),
                cancellationToken);
            return result;
        }
        catch (EconomyOperationRejectedException ex)
        {
            operation = await economyOperations.MarkFailedAsync(
                userContext.UserId,
                operation.Id,
                ex.FailureCode,
                cancellationToken);
            return await FailedPurchaseAsync(payload, operation.FailureCode, cancellationToken);
        }
    }

    private async Task<PurchaseResultDto> FailedPurchaseAsync(
        ShopEconomyPayload payload,
        string? failureCode,
        CancellationToken cancellationToken)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        return new PurchaseResultDto(
            false,
            payload.Record.ItemId,
            0,
            profile.Gems,
            profile.FreezeTokens,
            failureCode ?? "conflict");
    }

    private sealed record ShopEconomyPayload(PurchaseRecord Record, int FreezeTokensGranted);

    private static string ErrorCode(PurchaseError error) => error switch
    {
        PurchaseError.InsufficientGems => "insufficientGems",
        PurchaseError.AlreadyAtMax => "alreadyAtMax",
        PurchaseError.UnknownItem => "unknownItem",
        _ => "unknown",
    };
}

public interface IQuestService
{
    Task<QuestBoardDto> GetTodayAsync(CancellationToken cancellationToken = default);
    Task<ClaimQuestResultDto> ClaimAsync(ClaimQuestRequest request, CancellationToken cancellationToken = default);
}

public sealed class QuestService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IEventRepository events,
    IEconomyOperationRepository economyOperations) : IQuestService
{
    private static readonly string[] EconomySteps = ["profile", "events"];

    public async Task<QuestBoardDto> GetTodayAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var (signals, claims) = DailyState(profile, today);

        var quests = QuestEngine.DailyQuests(today, userContext.UserId)
            .Select(t => ToDto(t, signals, claims))
            .ToArray();

        return new QuestBoardDto(today, profile.Gems, quests);
    }

    public async Task<ClaimQuestResultDto> ClaimAsync(ClaimQuestRequest request, CancellationToken cancellationToken = default)
    {
        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var operationKey = $"{today:yyyyMMdd}:{request.QuestId}";
        var operationId = EconomyOperationRecord.IdFor("quest", operationKey);
        var existingOperation = await economyOperations.GetAsync(
            userContext.UserId,
            operationId,
            cancellationToken);
        if (existingOperation is not null)
        {
            var resumed = await ResumeClaimAsync(existingOperation, cancellationToken);
            if (existingOperation.Status == EconomyOperationRecord.CompletedStatus)
            {
                var current = await users.GetAsync(userContext.UserId, cancellationToken);
                return resumed with
                {
                    GemsAwarded = 0,
                    GemsBalance = current?.Gems ?? resumed.GemsBalance,
                };
            }

            return resumed;
        }

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var (signals, claims) = DailyState(profile, today);
        var template = QuestEngine.DailyQuests(today, userContext.UserId)
            .FirstOrDefault(t => t.Id == request.QuestId);
        if (template is null)
        {
            return new ClaimQuestResultDto(false, request.QuestId, 0, profile.Gems, false, "unknownQuest");
        }

        if (claims.Contains(template.Id))
        {
            return new ClaimQuestResultDto(true, template.Id, 0, profile.Gems, true, null);
        }

        var status = QuestEngine.Evaluate(template, signals);
        if (!status.Completed)
        {
            return new ClaimQuestResultDto(false, template.Id, 0, profile.Gems, false, "notCompleted");
        }

        var result = new ClaimQuestResultDto(
            true,
            template.Id,
            template.RewardGems,
            profile.Gems + template.RewardGems,
            true,
            null);
        var operation = await DurableEconomy.StartAsync(
            economyOperations,
            userContext.UserId,
            "quest",
            operationKey,
            new QuestEconomyPayload(today, template.Id, template.RewardGems, result),
            EconomySteps,
            clock.UtcNow,
            cancellationToken);
        return await ResumeClaimAsync(operation, cancellationToken);
    }

    private async Task<ClaimQuestResultDto> ResumeClaimAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken)
    {
        var payload = DurableEconomy.ReadPayload<QuestEconomyPayload>(operation);
        var profileOutcome = await DurableEconomy.ApplyProfileOutcomeStepAsync(
            economyOperations,
            users,
            userContext.UserId,
            userContext.DisplayName,
            operation,
            profile =>
            {
                var claims = profile.DailyXpDate == payload.Date
                    ? new List<string>(profile.DailyQuestClaims ?? [])
                    : null;
                if (claims is not null
                    && !claims.Contains(payload.QuestId, StringComparer.Ordinal))
                {
                    claims.Add(payload.QuestId);
                }

                var updated = profile with
                {
                    Gems = profile.Gems + payload.RewardGems,
                    DailyXpDate = claims is null ? profile.DailyXpDate : payload.Date,
                    DailyQuestClaims = claims ?? profile.DailyQuestClaims,
                };
                return (updated, payload.Result with { GemsBalance = updated.Gems });
            },
            payload.Result,
            cancellationToken);
        operation = profileOutcome.Operation;
        var result = profileOutcome.Outcome;

        await DurableEconomy.RunStepAsync(
            economyOperations,
            operation,
            "events",
            () => events.AddAsync(
                new LearningEvent(
                    DurableEconomy.EventId(operation.Id, "quest.claimed"),
                    userContext.UserId,
                    "quest.claimed",
                    operation.CreatedAt,
                    result),
                cancellationToken),
            cancellationToken);
        return result;
    }

    private sealed record QuestEconomyPayload(
        DateOnly Date,
        string QuestId,
        int RewardGems,
        ClaimQuestResultDto Result);

    // Daily counters reset at the day boundary. When the profile's recorded day
    // is not today the learner has no activity yet, so signals and claims are
    // empty (stale values from a previous day are ignored).
    private static (DailySignals Signals, IReadOnlyList<string> Claims) DailyState(UserProfileDto profile, DateOnly today)
    {
        if (profile.DailyXpDate != today)
        {
            return (DailySignals.Empty, Array.Empty<string>());
        }

        var signals = new DailySignals(
            profile.DailyXpEarned,
            profile.DailyLessonsCompleted,
            profile.DailyCorrectAnswers,
            profile.DailyPerfectLessons);
        return (signals, profile.DailyQuestClaims ?? new List<string>());
    }

    private static QuestDto ToDto(QuestTemplate template, DailySignals signals, IReadOnlyList<string> claims)
    {
        var status = QuestEngine.Evaluate(template, signals);
        var claimed = claims.Contains(template.Id);
        return new QuestDto(
            template.Id,
            template.Kind.ToString(),
            template.Title,
            template.Target,
            status.Current,
            template.RewardGems,
            status.Completed,
            claimed,
            status.Completed && !claimed);
    }
}

public interface ISeasonService
{
    Task<SeasonDto> GetCurrentAsync(CancellationToken cancellationToken = default);
    Task<ClaimSeasonResultDto> ClaimAsync(ClaimSeasonRequest request, CancellationToken cancellationToken = default);
}

public sealed class SeasonService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IEventRepository events,
    IEconomyOperationRepository economyOperations) : ISeasonService
{
    private static readonly string[] EconomySteps = ["profile", "events"];

    public async Task<SeasonDto> GetCurrentAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var season = SeasonEngine.ForDate(today);
        var signals = MonthlySignalsFor(profile, today);
        var badges = profile.SeasonBadges ?? new List<string>();

        return ToDto(season, signals, profile.Gems, badges);
    }

    public async Task<ClaimSeasonResultDto> ClaimAsync(ClaimSeasonRequest request, CancellationToken cancellationToken = default)
    {
        var operationId = EconomyOperationRecord.IdFor("season", request.SeasonId);
        var existingOperation = await economyOperations.GetAsync(
            userContext.UserId,
            operationId,
            cancellationToken);
        if (existingOperation is not null)
        {
            var resumed = await ResumeClaimAsync(existingOperation, cancellationToken);
            if (existingOperation.Status == EconomyOperationRecord.CompletedStatus)
            {
                var current = await users.GetAsync(userContext.UserId, cancellationToken);
                return resumed with
                {
                    GemsAwarded = 0,
                    GemsBalance = current?.Gems ?? resumed.GemsBalance,
                };
            }

            return resumed;
        }

        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var season = SeasonEngine.ForDate(today);
        var badgeId = season.Challenge.BadgeId;
        var badges = profile.SeasonBadges ?? new List<string>();
        if (!string.Equals(request.SeasonId, season.Id, StringComparison.Ordinal))
        {
            return new ClaimSeasonResultDto(false, request.SeasonId, null, 0, profile.Gems, false, "wrongSeason");
        }

        if (badges.Contains(badgeId))
        {
            return new ClaimSeasonResultDto(true, season.Id, badgeId, 0, profile.Gems, true, null);
        }

        var signals = MonthlySignalsFor(profile, today);
        var status = SeasonEngine.Evaluate(season, signals);
        if (!status.Completed)
        {
            return new ClaimSeasonResultDto(false, season.Id, null, 0, profile.Gems, false, "notCompleted");
        }

        var result = new ClaimSeasonResultDto(
            true,
            season.Id,
            badgeId,
            season.Challenge.RewardGems,
            profile.Gems + season.Challenge.RewardGems,
            true,
            null);
        var operation = await DurableEconomy.StartAsync(
            economyOperations,
            userContext.UserId,
            "season",
            request.SeasonId,
            new SeasonEconomyPayload(
                badgeId,
                season.Challenge.RewardGems,
                result),
            EconomySteps,
            clock.UtcNow,
            cancellationToken);
        return await ResumeClaimAsync(operation, cancellationToken);
    }

    private async Task<ClaimSeasonResultDto> ResumeClaimAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken)
    {
        var payload = DurableEconomy.ReadPayload<SeasonEconomyPayload>(operation);
        var profileOutcome = await DurableEconomy.ApplyProfileOutcomeStepAsync(
            economyOperations,
            users,
            userContext.UserId,
            userContext.DisplayName,
            operation,
            profile =>
            {
                var badges = profile.SeasonBadges is null
                    ? new List<string>()
                    : new List<string>(profile.SeasonBadges);
                if (!badges.Contains(payload.BadgeId, StringComparer.Ordinal))
                {
                    badges.Add(payload.BadgeId);
                }

                var updated = profile with
                {
                    Gems = profile.Gems + payload.RewardGems,
                    SeasonBadges = badges,
                };
                return (updated, payload.Result with { GemsBalance = updated.Gems });
            },
            payload.Result,
            cancellationToken);
        operation = profileOutcome.Operation;
        var result = profileOutcome.Outcome;

        await DurableEconomy.RunStepAsync(
            economyOperations,
            operation,
            "events",
            () => events.AddAsync(
                new LearningEvent(
                    DurableEconomy.EventId(operation.Id, "season.claimed"),
                    userContext.UserId,
                    "season.claimed",
                    operation.CreatedAt,
                    result),
                cancellationToken),
            cancellationToken);
        return result;
    }

    private sealed record SeasonEconomyPayload(
        string BadgeId,
        int RewardGems,
        ClaimSeasonResultDto Result);

    // Monthly counters reset at the month boundary. When the profile's recorded
    // month anchor is not the current month the learner has no activity yet, so
    // signals are empty (stale values from a previous month are ignored).
    private static SeasonSignals MonthlySignalsFor(UserProfileDto profile, DateOnly today)
    {
        var anchor = new DateOnly(today.Year, today.Month, 1);
        if (profile.MonthlyAnchor != anchor)
        {
            return SeasonSignals.Empty;
        }

        return new SeasonSignals(
            profile.MonthlyXpEarned,
            profile.MonthlyLessonsCompleted,
            profile.MonthlyPerfectLessons);
    }

    private static SeasonDto ToDto(Season season, SeasonSignals signals, int gems, IReadOnlyList<string> badges)
    {
        var status = SeasonEngine.Evaluate(season, signals);
        var claimed = badges.Contains(season.Challenge.BadgeId);
        return new SeasonDto(
            season.Id,
            season.Year,
            season.Month,
            season.Theme,
            season.Tagline,
            season.Mascot,
            season.Accent,
            season.Challenge.BadgeId,
            season.Challenge.BadgeTitle,
            gems,
            badges.Count,
            new SeasonChallengeDto(
                season.Challenge.Kind.ToString(),
                season.Challenge.Title,
                season.Challenge.Target,
                status.Current,
                season.Challenge.RewardGems,
                status.Completed,
                claimed,
                status.Completed && !claimed));
    }
}

internal static class AchievementSnapshots
{
    public static AchievementSnapshot From(UserProfileDto p)
        => new(p.StreakDays, p.Xp, p.Level, p.LifetimeLessonsCompleted, p.LifetimePerfectLessons, p.Gems);
}

public interface IAchievementService
{
    Task<AchievementBoardDto> GetAllAsync(CancellationToken cancellationToken = default);
}

public sealed class AchievementService(IUserContext userContext, IUserRepository users) : IAchievementService
{
    public async Task<AchievementBoardDto> GetAllAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var snapshot = AchievementSnapshots.From(profile);
        var unlocked = new HashSet<string>(profile.Achievements ?? new List<string>(), StringComparer.OrdinalIgnoreCase);

        var dtos = AchievementEngine.Tiers.Select(t =>
        {
            var value = snapshot.ValueFor(t.Kind);
            // Treat a tier as unlocked if it was persisted OR the threshold is now
            // met (so the board is correct even before the next quiz persists it).
            var isUnlocked = unlocked.Contains(t.Id) || value >= t.Threshold;
            return new AchievementDto(
                t.Id,
                t.Kind.ToString(),
                t.Name,
                t.Description,
                t.Tier,
                t.Threshold,
                Math.Min(value, t.Threshold),
                t.RewardGems,
                isUnlocked);
        }).ToArray();

        return new AchievementBoardDto(dtos.Count(d => d.Unlocked), dtos.Length, dtos);
    }
}

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
    IEconomyOperationRepository economyOperations) : IStreakRepairService
{
    private static readonly string[] EconomySteps = ["ledger", "profile", "events"];

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
        var operationId = EconomyOperationRecord.IdFor("streakRepair", request.ClientRepairId);
        var existingOperation = await economyOperations.GetAsync(
            userContext.UserId,
            operationId,
            cancellationToken);
        if (existingOperation is not null)
        {
            return await ResumeRepairAsync(existingOperation, cancellationToken);
        }

        var prior = await purchases.GetByClientPurchaseIdAsync(
            userContext.UserId,
            request.ClientRepairId,
            cancellationToken);
        if (prior is not null)
        {
            var existing = await users.GetAsync(userContext.UserId, cancellationToken);
            return new StreakRepairResultDto(
                true,
                existing?.StreakDays ?? 0,
                prior.GemsSpent,
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
            return new StreakRepairResultDto(
                false,
                profile.StreakDays,
                0,
                profile.Gems,
                profile.LastActiveDate,
                assessment.Reason);
        }

        if (profile.Gems < assessment.CostGems)
        {
            return new StreakRepairResultDto(
                false,
                profile.StreakDays,
                0,
                profile.Gems,
                profile.LastActiveDate,
                "insufficientGems");
        }

        var now = clock.UtcNow;
        var result = new StreakRepairResultDto(
            true,
            profile.StreakDays,
            assessment.CostGems,
            profile.Gems - assessment.CostGems,
            assessment.BridgeTo,
            null);
        var record = new PurchaseRecord(
            $"streakrepair::{request.ClientRepairId}",
            userContext.UserId,
            request.ClientRepairId,
            "streak-repair",
            assessment.CostGems,
            now,
            new PurchaseResultDto(
                true,
                "streak-repair",
                assessment.CostGems,
                result.GemsBalance,
                profile.FreezeTokens,
                null));
        var operation = await DurableEconomy.StartAsync(
            economyOperations,
            userContext.UserId,
            "streakRepair",
            request.ClientRepairId,
            new StreakRepairEconomyPayload(record, assessment.BridgeTo, result),
            EconomySteps,
            now,
            cancellationToken);
        return await ResumeRepairAsync(operation, cancellationToken);
    }

    private async Task<StreakRepairResultDto> ResumeRepairAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken)
    {
        var payload = DurableEconomy.ReadPayload<StreakRepairEconomyPayload>(operation);
        if (operation.Status == EconomyOperationRecord.FailedStatus)
        {
            return await FailedRepairAsync(payload, operation.FailureCode, cancellationToken);
        }

        try
        {
            var profileOutcome = await DurableEconomy.ApplyProfileOutcomeStepAsync(
                economyOperations,
                users,
                userContext.UserId,
                userContext.DisplayName,
                operation,
                profile =>
                {
                    if (profile.Gems < payload.Record.GemsSpent)
                    {
                        throw new EconomyOperationRejectedException("insufficientGems");
                    }

                    if (profile.LastActiveDate is { } lastActive
                        && lastActive >= payload.BridgeTo)
                    {
                        throw new EconomyOperationRejectedException("noLongerRepairable");
                    }

                    var updated = profile with
                    {
                        Gems = profile.Gems - payload.Record.GemsSpent,
                        LastActiveDate = payload.BridgeTo,
                    };
                    return (updated, payload.Result with
                    {
                        GemsBalance = updated.Gems,
                        LastActiveDate = updated.LastActiveDate,
                    });
                },
                payload.Result,
                cancellationToken);
            operation = profileOutcome.Operation;
            var result = profileOutcome.Outcome;
            var record = payload.Record with
            {
                Result = payload.Record.Result with
                {
                    GemsBalance = result.GemsBalance,
                },
            };

            operation = await DurableEconomy.RunStepAsync(
                economyOperations,
                operation,
                "ledger",
                async () =>
                {
                    try
                    {
                        await purchases.CreateAsync(record, cancellationToken);
                    }
                    catch (DuplicateRecordException)
                    {
                        var existing = await purchases.GetByClientPurchaseIdAsync(
                            userContext.UserId,
                            record.ClientPurchaseId,
                            cancellationToken);
                        if (existing?.ItemId != "streak-repair")
                        {
                            throw new ConcurrencyConflictException(
                                $"Streak repair '{record.ClientPurchaseId}' conflicts with another purchase.");
                        }
                    }
                },
                cancellationToken);

            await DurableEconomy.RunStepAsync(
                economyOperations,
                operation,
                "events",
                () => events.AddAsync(
                    new LearningEvent(
                        DurableEconomy.EventId(operation.Id, "streak.repaired"),
                        userContext.UserId,
                        "streak.repaired",
                        record.PurchasedAt,
                        result),
                    cancellationToken),
                cancellationToken);
            return result;
        }
        catch (EconomyOperationRejectedException ex)
        {
            operation = await economyOperations.MarkFailedAsync(
                userContext.UserId,
                operation.Id,
                ex.FailureCode,
                cancellationToken);
            return await FailedRepairAsync(payload, operation.FailureCode, cancellationToken);
        }
    }

    private async Task<StreakRepairResultDto> FailedRepairAsync(
        StreakRepairEconomyPayload payload,
        string? failureCode,
        CancellationToken cancellationToken)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        return new StreakRepairResultDto(
            false,
            profile.StreakDays,
            0,
            profile.Gems,
            profile.LastActiveDate,
            failureCode ?? "conflict");
    }

    private sealed record StreakRepairEconomyPayload(
        PurchaseRecord Record,
        DateOnly BridgeTo,
        StreakRepairResultDto Result);
}
