using System.Text.Json.Serialization;
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
    List<string>? Achievements = null,
    NotificationStateDto? NotificationState = null,
    DateOnly? MonthlyAnchor = null,
    int MonthlyXpEarned = 0,
    int MonthlyLessonsCompleted = 0,
    int MonthlyPerfectLessons = 0,
    List<string>? SeasonBadges = null)
{
    /// Cosmos optimistic-concurrency token (the system `_etag`). Null for freshly
    /// constructed or in-memory profiles; populated on read and honoured on write
    /// (If-Match) so concurrent economy mutations never silently lose an update.
    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }
}

// --- Email/password authentication -----------------------------------------

public sealed record RegisterRequest(string Email, string Password, string? DisplayName = null);

public sealed record LoginRequest(string Email, string Password);

public sealed record RefreshTokenRequest(string RefreshToken);

/// The payload returned by register/login/refresh: the freshly-minted token pair
/// plus the learner's (provisioned) profile so the client can render the home
/// screen without a second round-trip.
public sealed record AuthResultDto(
    string AccessToken,
    string RefreshToken,
    DateTimeOffset AccessTokenExpiresAt,
    UserProfileDto Profile);

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

// Charge utile de l'événement `attempt.flagged` émis par l'anti-triche en mode
// détection. Schéma stable et typé (plutôt qu'anonyme) pour être sérialisable,
// testable et exploitable par l'observabilité. `ReferenceId` = lessonId (quiz)
// ou examId (examen). Aucune récompense n'est modifiée à l'émission.
public sealed record AttemptIntegritySignal(
    string Kind,
    string ReferenceId,
    string AttemptId,
    string Decision,
    double RiskScore,
    List<string> Flags);

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

// --- Catalog (certification picker) ---------------------------------------

public sealed record TrackSummaryDto(
    string Id,
    string Code,
    string Title,
    string Level,
    string Summary,
    int UnitCount,
    int LessonCount);

public sealed record CatalogDto(IReadOnlyList<TrackSummaryDto> Tracks);

// --- League / leaderboard --------------------------------------------------

/// <summary>
/// Vue d'une ligue pour un apprenant. Les six premiers champs sont historiques
/// (produits par le dépôt) ; les suivants sont enrichis par le service à partir
/// du moteur de domaine <c>Microlingo.Domain.Gamification</c> et restent
/// optionnels pour préserver la compatibilité ascendante des appelants.
/// </summary>
public sealed record LeagueDto(
    string PeriodLeagueId,
    string Tier,
    DateTimeOffset EndsAt,
    int PromoteCount,
    string MeUserId,
    IReadOnlyList<LeaderboardEntryDto> Entries,
    int TierIndex = 1,
    string TierName = "Bronze",
    int RelegateCount = 0,
    string? NextTier = null,
    string? PreviousTier = null,
    int MyRank = 0,
    int MyWeeklyXp = 0,
    string MyZone = "safe",
    int ResetsInSeconds = 0);

public sealed record LeaderboardEntryDto(
    string UserId,
    string DisplayName,
    string? AvatarUrl,
    int Rank,
    int WeeklyXp,
    string Zone = "safe");

/// <summary>Aperçu de la résolution de fin de ligue (mouvements + récompenses).</summary>
public sealed record LeagueResolutionDto(
    string PeriodLeagueId,
    string Tier,
    IReadOnlyList<LeagueOutcomeDto> Outcomes);

public sealed record LeagueOutcomeDto(
    string UserId,
    string DisplayName,
    int Rank,
    string Zone,
    string Movement,
    string FromTier,
    string ToTier,
    int GemReward);

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

// The "next best action" coach. The client renders Items as a ranked list of cards
// on the home/path screen; the top item is what we believe the learner should do
// right now to raise readiness while honouring forgetting risk and active struggles.
public sealed record NextBestDto(
    string TrackId,
    DateTimeOffset GeneratedAt,
    IReadOnlyList<RecommendationItemDto> Items);

// One coach card. Kind is the wire-friendly action ("practice" | "review" | "resume"
// | "start"); Reason is a short, localized (French) sentence; Priority/MasteryPct/
// ForgettingRiskPct are 0-100 integers so the UI can show urgency without re-deriving.
public sealed record RecommendationItemDto(
    string Kind,
    string? LessonId,
    string? UnitId,
    string? ConceptId,
    string Title,
    string DomainId,
    string DomainName,
    string Reason,
    int EstMinutes,
    int Priority,
    int MasteryPct,
    int ForgettingRiskPct);

// --- Notifications intelligentes (§3.13) -----------------------------------

/// <summary>
/// Préférences de notification telles qu'exposées au client. Reflète
/// <c>Microlingo.Domain.Notifications.NotificationPreferences</c> ; le serveur
/// borne systématiquement les valeurs avant de planifier.
/// </summary>
public sealed record NotificationSettingsDto(
    bool Enabled,
    int UtcOffsetMinutes,
    int QuietHoursStart,
    int QuietHoursEnd,
    int PreferredHour,
    int MaxPerDay,
    bool StreakAlerts,
    bool QuestAlerts,
    bool LeagueAlerts)
{
    /// <summary>Réglages par défaut : actifs, UTC, silence 22h→7h, rappel 19h, 3/jour, toutes alertes.</summary>
    public static NotificationSettingsDto Default { get; } =
        new(true, 0, 22, 7, 19, 3, true, true, true);
}

/// <summary>Requête de mise à jour (remplacement intégral) des préférences de notification.</summary>
public sealed record UpdateNotificationSettingsRequest(
    bool Enabled,
    int UtcOffsetMinutes,
    int QuietHoursStart,
    int QuietHoursEnd,
    int PreferredHour,
    int MaxPerDay,
    bool StreakAlerts,
    bool QuestAlerts,
    bool LeagueAlerts);

/// <summary>
/// État de notification persisté dans le profil : préférences + histogramme
/// d'activité horaire appris (24 compartiments) et date du dernier renforcement,
/// garantissant l'idempotence journalière de l'apprentissage de l'heure préférée.
/// </summary>
public sealed record NotificationStateDto(
    NotificationSettingsDto Settings,
    List<int>? ActivityHours = null,
    DateOnly? LastActivityHourDate = null);

/// <summary>Une notification planifiée, projetée pour le client (énumérations en chaînes).</summary>
public sealed record ScheduledNotificationDto(
    string Kind,
    string Priority,
    DateTimeOffset ScheduledUtc,
    int LocalHour,
    string Mascot,
    string Title,
    string Body,
    string Deeplink,
    string DedupeKey);

/// <summary>Plan de notifications d'une journée locale, déjà trié et plafonné par le serveur.</summary>
public sealed record NotificationPlanDto(
    DateOnly LocalDate,
    IReadOnlyList<ScheduledNotificationDto> Notifications);
