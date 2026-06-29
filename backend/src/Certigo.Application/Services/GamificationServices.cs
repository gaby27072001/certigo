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
    IEventRepository events) : IShopService
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
        var prior = await purchases.GetByClientPurchaseIdAsync(userContext.UserId, request.ClientPurchaseId, cancellationToken);
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

public interface IQuestService
{
    Task<QuestBoardDto> GetTodayAsync(CancellationToken cancellationToken = default);
    Task<ClaimQuestResultDto> ClaimAsync(ClaimQuestRequest request, CancellationToken cancellationToken = default);
}

public sealed class QuestService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IEventRepository events) : IQuestService
{
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
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var (signals, claims) = DailyState(profile, today);

        var template = QuestEngine.DailyQuests(today, userContext.UserId).FirstOrDefault(t => t.Id == request.QuestId);
        if (template is null)
        {
            return new ClaimQuestResultDto(false, request.QuestId, 0, profile.Gems, false, "unknownQuest");
        }

        // Already claimed today: idempotent no-op so a retried claim never
        // double-awards gems.
        if (claims.Contains(template.Id))
        {
            return new ClaimQuestResultDto(true, template.Id, 0, profile.Gems, true, null);
        }

        var status = QuestEngine.Evaluate(template, signals);
        if (!status.Completed)
        {
            return new ClaimQuestResultDto(false, template.Id, 0, profile.Gems, false, "notCompleted");
        }

        var updatedClaims = new List<string>(claims) { template.Id };
        var updated = profile with
        {
            Gems = profile.Gems + template.RewardGems,
            DailyXpDate = today,
            DailyQuestClaims = updatedClaims,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var result = new ClaimQuestResultDto(true, template.Id, template.RewardGems, updated.Gems, true, null);
        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "quest.claimed",
            clock.UtcNow,
            result), cancellationToken);

        return result;
    }

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
    IEventRepository events) : ISeasonService
{
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
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var season = SeasonEngine.ForDate(today);
        var badgeId = season.Challenge.BadgeId;
        var badges = profile.SeasonBadges ?? new List<string>();

        // A learner can only claim the season the request actually targets, and
        // only while it is the current month. Claiming a past or future season is
        // rejected rather than silently redirected to the active one.
        if (!string.Equals(request.SeasonId, season.Id, StringComparison.Ordinal))
        {
            return new ClaimSeasonResultDto(false, request.SeasonId, null, 0, profile.Gems, false, "wrongSeason");
        }

        // Already earned this season's badge: idempotent no-op so a retried claim
        // never double-awards gems.
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

        var updatedBadges = new List<string>(badges) { badgeId };
        var updated = profile with
        {
            Gems = profile.Gems + season.Challenge.RewardGems,
            SeasonBadges = updatedBadges,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var result = new ClaimSeasonResultDto(true, season.Id, badgeId, season.Challenge.RewardGems, updated.Gems, true, null);
        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "season.claimed",
            clock.UtcNow,
            result), cancellationToken);

        return result;
    }

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
    IEventRepository events) : IStreakRepairService
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
        var prior = await purchases.GetByClientPurchaseIdAsync(userContext.UserId, request.ClientRepairId, cancellationToken);
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
        await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "streak.repaired", now, result), cancellationToken);

        return result;
    }
}
