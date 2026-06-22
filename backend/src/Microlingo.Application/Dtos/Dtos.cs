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

// --- Share card (daily score share, 2-tap virality) ------------------------

public sealed record ShareCardDto(
    string ShareId,
    string DisplayName,
    string Handle,
    int StreakDays,
    int Level,
    int DailyXp,
    int DailyGoalXp,
    bool GoalMet,
    int ReadinessScore,
    string TrackCode,
    string Mascot,
    string Headline,
    string Caption,
    string ReferralCode,
    DateTimeOffset GeneratedAt);

// --- Friends / social ------------------------------------------------------

public sealed record FriendDto(
    string UserId,
    string DisplayName,
    string Handle,
    string? AvatarUrl,
    int Level,
    int StreakDays,
    int Xp,
    DateTimeOffset FriendsSince);

public sealed record FriendListDto(int Count, IReadOnlyList<FriendDto> Friends);

public sealed record AddFriendRequest(string Handle);

public sealed record FriendActionResultDto(
    bool Success,
    string? FriendUserId,
    string? Error,
    FriendListDto Friends);

public sealed record FriendLeaderboardDto(
    string MeUserId,
    IReadOnlyList<LeaderboardEntryDto> Entries);

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

// --- Mock exam (adaptive practice exam) ------------------------------------

public sealed record MockExamRequest(string TrackId, int? Length = null);

// Public, answer-free exam item: stem + options come from the lesson's public
// check; the correct answer stays server-side in the answer key.
public sealed record MockExamItemDto(
    string ItemId,
    string LessonId,
    string DomainId,
    ItemType Type,
    string Stem,
    IReadOnlyList<CheckOption> Options);

public sealed record MockExamBlueprintDomainDto(string DomainId, string Name, double Weight, int ItemCount);

public sealed record MockExamDto(
    string ExamId,
    string TrackId,
    string TrackCode,
    string TrackTitle,
    int TimeLimitSeconds,
    int PassingScore,
    IReadOnlyList<MockExamBlueprintDomainDto> Blueprint,
    IReadOnlyList<MockExamItemDto> Items);

public sealed record SubmitMockExamRequest(
    string ClientAttemptId,
    string TrackId,
    string ExamId,
    DateTimeOffset StartedAt,
    List<AnswerDto> Answers);

public sealed record ExamDomainScoreDto(string DomainId, string Name, double Weight, int Correct, int Total, int Pct);

public sealed record MockExamResultDto(
    string AttemptId,
    string ExamId,
    int ScaledScore,
    int Pct,
    bool Passed,
    int PassingScore,
    int Correct,
    int Total,
    IReadOnlyList<ExamDomainScoreDto> Domains,
    List<ItemResultDto> Results,
    RewardsDto Rewards,
    List<string> WeakConcepts);

// "Explain my answer" — the premium AI-tutor entry point. The learner posts the
// item they just answered (and what they chose); the service grounds, personalises
// from their history, optionally upgrades via a guardrailed LLM, and learns from
// the interaction.
public sealed record TutorExplainRequest(
    string TrackId,
    string LessonId,
    string ItemId,
    List<string> Selected);

// What the tutor knows about this learner for the concept under test, surfaced so
// the client can show "you've struggled with this before / great comeback" UX.
public sealed record TutorPersonalizationDto(
    int Attempts,
    int Errors,
    int AccuracyPct,
    bool RecurringStruggle,
    bool MasteredBefore,
    string Trend,
    string? TopConfusedOption);

public sealed record TutorExplanationDto(
    string ItemId,
    string ConceptId,
    bool Correct,
    string Headline,
    IReadOnlyList<string> Points,
    string Encouragement,
    string Recommendation,
    IReadOnlyList<string> CitedConceptIds,
    string Source,
    TutorPersonalizationDto Personalization);
