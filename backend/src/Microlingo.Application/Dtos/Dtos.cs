using Microlingo.Domain.Content;

namespace Microlingo.Application.Dtos;

public sealed record UserProfileDto(
    string Id,
    string DisplayName,
    string Handle,
    string? AvatarUrl,
    int Xp,
    int Level,
    int StreakDays,
    int FreezeTokens,
    int DailyGoalXp,
    int DailyXpEarned,
    int Gems,
    string? ActiveTrackId,
    DateOnly? LastActiveDate = null,
    DateOnly? DailyXpDate = null,
    int DailyLessonsCompleted = 0,
    int DailyCorrectAnswers = 0,
    int DailyPerfectLessons = 0,
    List<string>? DailyQuestClaims = null,
    int LifetimeLessonsCompleted = 0,
    int LifetimePerfectLessons = 0,
    List<string>? Achievements = null);

public sealed record SubmitQuizRequest(
    string ClientAttemptId,
    string TrackId,
    DateTimeOffset StartedAt,
    List<AnswerDto> Answers);

public sealed record AnswerDto(
    string ItemId,
    ItemType ItemType,
    List<string> Selected,
    int LatencyMs);

public sealed record SubmitQuizResult(
    string AttemptId,
    int ScorePct,
    List<ItemResultDto> Results,
    RewardsDto Rewards,
    List<string> WeakConcepts,
    DateTimeOffset? NextReviewDueAt);

public sealed record ItemResultDto(
    string ItemId,
    bool Correct,
    string ConceptId,
    List<string>? CorrectAnswer,
    string Explanation,
    double MasteryDelta);

public sealed record RewardsDto(
    int XpEarned,
    int NewXp,
    bool LevelUp,
    bool StreakExtended,
    int GemsEarned,
    List<string> AchievementsUnlocked);

// --- Path (skill-path) -----------------------------------------------------

public sealed record PathDto(
    string TrackId,
    string TrackName,
    string Exam,
    int ReadinessScore,
    int ReadinessTrend7d,
    IReadOnlyList<PathUnitDto> Units,
    IReadOnlyList<DomainProgressDto> Domains);

public sealed record PathUnitDto(
    string Id,
    string Title,
    string DomainId,
    string Status,
    IReadOnlyList<PathLessonDto> Lessons);

public sealed record PathLessonDto(
    string Id,
    string Title,
    string Status,
    int EstMinutes,
    int MasteryPct);

public sealed record DomainProgressDto(
    string Id,
    string Name,
    double Weight,
    int Score);

// --- League / leaderboard --------------------------------------------------

public sealed record LeagueDto(
    string PeriodLeagueId,
    string Tier,
    DateTimeOffset EndsAt,
    int PromoteCount,
    string MeUserId,
    IReadOnlyList<LeaderboardEntryDto> Entries);

public sealed record LeaderboardEntryDto(
    string UserId,
    string DisplayName,
    string? AvatarUrl,
    int Rank,
    int WeeklyXp);

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

// --- Readiness -------------------------------------------------------------

public sealed record ReadinessDto(string TrackId, int Score, int Trend7d, IReadOnlyList<DomainReadinessDto> Domains);

public sealed record DomainReadinessDto(string DomainId, double Weight, double Coverage, double Mastery, int Score);
