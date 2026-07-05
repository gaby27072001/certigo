namespace Certigo.Application.Dtos;

// --- Shop / economy --------------------------------------------------------

public sealed record ShopItemDto(
    string Id,
    string Name,
    string Description,
    int PriceGems,
    string Kind,
    int Amount);

public sealed record ShopCatalogDto(
    int Gems,
    IReadOnlyList<ShopItemDto> Items);

public sealed record PurchaseRequest(
    string ItemId,
    string ClientPurchaseId);

public sealed record PurchaseResultDto(
    bool Success,
    string ItemId,
    int GemsSpent,
    int GemsBalance,
    int FreezeTokens,
    string? Error);

// --- Quests ----------------------------------------------------------------

public sealed record QuestDto(
    string Id,
    string Kind,
    string Title,
    int Target,
    int Current,
    int RewardGems,
    bool Completed,
    bool Claimed,
    bool Claimable);

public sealed record QuestBoardDto(
    DateOnly Date,
    int Gems,
    IReadOnlyList<QuestDto> Quests);

public sealed record ClaimQuestRequest(string QuestId);

public sealed record ClaimQuestResultDto(
    bool Success,
    string QuestId,
    int GemsAwarded,
    int GemsBalance,
    bool Claimed,
    string? Error);

// --- Seasons & monthly challenge -------------------------------------------

public sealed record SeasonChallengeDto(
    string Kind,
    string Title,
    int Target,
    int Current,
    int RewardGems,
    bool Completed,
    bool Claimed,
    bool Claimable);

public sealed record SeasonDto(
    string Id,
    int Year,
    int Month,
    string Theme,
    string Tagline,
    string Mascot,
    string Accent,
    string BadgeId,
    string BadgeTitle,
    int Gems,
    int BadgesEarned,
    SeasonChallengeDto Challenge);

public sealed record ClaimSeasonRequest(string SeasonId);

public sealed record ClaimSeasonResultDto(
    bool Success,
    string SeasonId,
    string? BadgeId,
    int GemsAwarded,
    int GemsBalance,
    bool Claimed,
    string? Error);

// --- Achievements / badges -------------------------------------------------

public sealed record AchievementDto(
    string Id,
    string Kind,
    string Name,
    string Description,
    string Tier,
    int Threshold,
    int Progress,
    int RewardGems,
    bool Unlocked);

public sealed record AchievementBoardDto(
    int Unlocked,
    int Total,
    IReadOnlyList<AchievementDto> Achievements);

// --- Streak repair ---------------------------------------------------------

public sealed record StreakStatusDto(
    int StreakDays,
    DateOnly? LastActiveDate,
    int FreezeTokens,
    bool Repairable,
    int RepairCostGems,
    string? Reason);

public sealed record StreakRepairRequest(string ClientRepairId);

public sealed record StreakRepairResultDto(
    bool Success,
    int StreakDays,
    int GemsSpent,
    int GemsBalance,
    DateOnly? LastActiveDate,
    string? Error);
