namespace Certigo.Domain.Gamification;

/// The measurable behaviours a season-long challenge can track. Each maps to a
/// per-month signal the server accumulates from the quiz flow, so challenge
/// progress is always recomputable and never trusted from the client.
public enum SeasonGoalKind
{
    EarnXp,
    CompleteLessons,
    PerfectLessons
}

/// A learner's accumulated activity within a single calendar month, used to
/// evaluate the season challenge.
public sealed record SeasonSignals(int XpEarned, int LessonsCompleted, int PerfectLessons)
{
    public static readonly SeasonSignals Empty = new(0, 0, 0);
}

/// The cumulative monthly goal that, once met, awards a collectible season badge.
public sealed record SeasonChallenge(
    SeasonGoalKind Kind,
    string Title,
    int Target,
    int RewardGems,
    string BadgeId,
    string BadgeTitle);

/// A themed, month-long season — Certigo's Azure-flavoured analogue of
/// Duolingo's seasonal events — fronted by an Aurora Crew mascot and carrying a
/// single season challenge.
public sealed record Season(
    string Id,
    int Year,
    int Month,
    string Theme,
    string Tagline,
    string Mascot,
    string Accent,
    SeasonChallenge Challenge);

public sealed record SeasonStatus(Season Season, int Current, bool Completed);

/// Pure, deterministic season rules. Every learner sees the same themed season
/// for a given calendar month (so the board is stable and shareable), and
/// challenge progress is derived purely from <see cref="SeasonSignals"/>.
public static class SeasonEngine
{
    private sealed record SeasonTheme(
        string Slug,
        string Name,
        string Tagline,
        string Mascot,
        string Accent,
        SeasonGoalKind Kind,
        int Target,
        int RewardGems,
        string BadgeTitle);

    // One fixed theme per month-of-year (1 = janvier … 12 = décembre). Themes map
    // to Azure exam domains and rotate the Aurora Crew so a returning learner
    // collects a distinct badge every month.
    private static readonly IReadOnlyList<SeasonTheme> Themes = new[]
    {
        new SeasonTheme("renouveau-cloud", "Renouveau Cloud", "Lance ton année dans le nuage", "Nimbus", "#4F8BFF", SeasonGoalKind.EarnXp, 1200, 120, "Pionnier du Cloud"),
        new SeasonTheme("festival-ia", "Festival de l'IA", "Un mois pour dompter l'intelligence artificielle", "Pixel", "#A569FF", SeasonGoalKind.CompleteLessons, 40, 120, "Visionnaire IA"),
        new SeasonTheme("sprint-gouvernance", "Sprint Gouvernance", "Maîtrise la conformité et la gouvernance", "Sentinel", "#2FB48B", SeasonGoalKind.PerfectLessons, 15, 130, "Gardien de la Gouvernance"),
        new SeasonTheme("marathon-donnees", "Marathon des Données", "Cours après chaque octet", "Cosmo", "#3DC2C2", SeasonGoalKind.EarnXp, 1300, 130, "Maître des Données"),
        new SeasonTheme("forge-architecture", "Forge de l'Architecture", "Bâtis des architectures solides", "Bicky", "#F2A93B", SeasonGoalKind.CompleteLessons, 45, 130, "Architecte Émérite"),
        new SeasonTheme("eclairs-serverless", "Éclairs du Serverless", "Va à la vitesse de l'éclair", "Volt", "#FFC83D", SeasonGoalKind.EarnXp, 1400, 140, "Foudre du Serverless"),
        new SeasonTheme("odyssee-reseau", "Odyssée Réseau", "Traverse les réseaux Azure", "Nimbus", "#4F8BFF", SeasonGoalKind.CompleteLessons, 45, 130, "Navigateur Réseau"),
        new SeasonTheme("bouclier-securite", "Bouclier Sécurité", "Dresse tes défenses", "Sentinel", "#2FB48B", SeasonGoalKind.PerfectLessons, 18, 150, "Rempart Azure"),
        new SeasonTheme("rentree-certif", "Rentrée Certif", "Reprends le rythme des révisions", "Pip", "#FF8A5C", SeasonGoalKind.EarnXp, 1300, 130, "Élève Modèle"),
        new SeasonTheme("chasse-couts", "Chasse aux Coûts", "Optimise chaque dépense cloud", "Bicky", "#F2A93B", SeasonGoalKind.CompleteLessons, 45, 130, "Optimiseur FinOps"),
        new SeasonTheme("tempete-revisions", "Tempête de Révisions", "Affronte la tempête des concepts", "Cosmo", "#3DC2C2", SeasonGoalKind.PerfectLessons, 18, 150, "Sage de la Révision"),
        new SeasonTheme("grand-final", "Grand Final", "Termine l'année en légende", "Nimbus", "#4F8BFF", SeasonGoalKind.EarnXp, 1500, 160, "Légende de l'Année"),
    };

    private static readonly string[] MonthNamesFr =
    {
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre"
    };

    /// Builds the themed season for the given calendar month. Deterministic: the
    /// same year/month always yields the same season, theme, challenge and badge.
    public static Season ForMonth(int year, int month)
    {
        if (month is < 1 or > 12)
        {
            throw new ArgumentOutOfRangeException(nameof(month), month, "Month must be between 1 and 12.");
        }

        var theme = Themes[month - 1];
        var monthName = MonthNamesFr[month - 1];
        var challenge = new SeasonChallenge(
            theme.Kind,
            ChallengeTitle(theme.Kind, theme.Target, monthName),
            theme.Target,
            theme.RewardGems,
            $"season-{theme.Slug}",
            theme.BadgeTitle);

        return new Season($"{year:D4}-{month:D2}", year, month, theme.Name, theme.Tagline, theme.Mascot, theme.Accent, challenge);
    }

    /// Convenience overload resolving the season that owns a calendar date.
    public static Season ForDate(DateOnly date) => ForMonth(date.Year, date.Month);

    public static SeasonStatus Evaluate(Season season, SeasonSignals signals)
    {
        var raw = Progress(season.Challenge.Kind, signals);
        return new SeasonStatus(season, Math.Min(raw, season.Challenge.Target), raw >= season.Challenge.Target);
    }

    public static int Progress(SeasonGoalKind kind, SeasonSignals signals) => kind switch
    {
        SeasonGoalKind.EarnXp => signals.XpEarned,
        SeasonGoalKind.CompleteLessons => signals.LessonsCompleted,
        SeasonGoalKind.PerfectLessons => signals.PerfectLessons,
        _ => 0
    };

    private static string ChallengeTitle(SeasonGoalKind kind, int target, string monthName) => kind switch
    {
        SeasonGoalKind.EarnXp => $"Gagne {target} XP en {monthName}",
        SeasonGoalKind.CompleteLessons => $"Termine {target} leçons en {monthName}",
        SeasonGoalKind.PerfectLessons => $"Réussis {target} leçons sans faute en {monthName}",
        _ => $"Relève le défi de {monthName}"
    };
}
