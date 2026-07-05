namespace Certigo.Application.Dtos;

// --- League / leaderboard --------------------------------------------------

/// <summary>
/// Vue d'une ligue pour un apprenant. Les six premiers champs sont historiques
/// (produits par le dépôt) ; les suivants sont enrichis par le service à partir
/// du moteur de domaine <c>Certigo.Domain.Gamification</c> et restent
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
