namespace Certigo.Application.Dtos;

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
