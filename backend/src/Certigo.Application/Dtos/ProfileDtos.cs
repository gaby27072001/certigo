using System.Text.Json.Serialization;
using Certigo.Domain.Identity;

namespace Certigo.Application.Dtos;

public sealed record EconomyProfileReceipt(
    string OperationId,
    DateTimeOffset AppliedAt,
    string OutcomeJson);

public sealed record SetActiveTrackRequest(string TrackId, string? ExpectedTrackId);

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
    List<string>? Achievements = null,
    NotificationStateDto? NotificationState = null,
    DateOnly? MonthlyAnchor = null,
    int MonthlyXpEarned = 0,
    int MonthlyLessonsCompleted = 0,
    int MonthlyPerfectLessons = 0,
    List<string>? SeasonBadges = null,
    // Bounded receipts protect profile mutations from ambiguous cross-container
    // retries. Completed operation journals are retained indefinitely, allowing
    // old receipts to be compacted without losing idempotence.
    List<EconomyProfileReceipt>? EconomyReceipts = null,
    // Read-only migration bridge for profiles written before bounded receipts.
    // New operations never append to this list; matching entries are migrated
    // to EconomyReceipts when their durable journal is resumed.
    List<string>? AppliedEconomyOperations = null,
    PersonIdentityMetadata? IdentityMetadata = null)
{
    /// Cosmos optimistic-concurrency token (the system `_etag`). Null for freshly
    /// constructed or in-memory profiles; populated on read and honoured on write
    /// (If-Match) so concurrent economy mutations never silently lose an update.
    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }
}
