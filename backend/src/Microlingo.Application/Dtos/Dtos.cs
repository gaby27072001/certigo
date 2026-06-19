using Microlingo.Domain.Content;

namespace Microlingo.Application.Dtos;

public sealed record UserProfileDto(
    string Id,
    string DisplayName,
    int Xp,
    int Level,
    int StreakDays,
    int FreezeTokens,
    int DailyGoalXp,
    int DailyXpEarned);

public sealed record LessonDto(
    string Id,
    string TrackId,
    string UnitId,
    string DomainId,
    int Order,
    string Title,
    int EstMinutes,
    IReadOnlyList<LessonBlock> Blocks,
    IReadOnlyList<QuizItemDto> Items);

public sealed record QuizItemDto(
    string Id,
    string TrackId,
    string ConceptId,
    string DomainId,
    ItemType ItemType,
    string Bloom,
    double Difficulty,
    string Stem,
    IReadOnlyList<Option> Options);

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
    List<string> AchievementsUnlocked);

public sealed record PathDto(string TrackId, string Title, int ReadinessScore, IReadOnlyList<string> RecommendedConceptIds);

public sealed record LeagueDto(string PeriodLeagueId, string Name, IReadOnlyList<LeaderboardEntryDto> Entries);

public sealed record LeaderboardEntryDto(string UserId, string DisplayName, int Xp, int Rank);

public sealed record ReadinessDto(string TrackId, int Score, int Trend7d, IReadOnlyList<DomainReadinessDto> Domains);

public sealed record DomainReadinessDto(string DomainId, double Weight, double Coverage, double Mastery, int Score);
