namespace Microlingo.Domain.Gamification;

public enum AchievementKind
{
    Streak,
    TotalXp,
    Level,
    LessonsCompleted,
    FlawlessLessons,
    Gems,
}

// A single milestone tier within an achievement family (e.g. "Série · Or").
public sealed record AchievementTier(
    string Id,
    AchievementKind Kind,
    string Name,
    string Description,
    string Tier,
    int Threshold,
    int RewardGems);

// The lifetime stats an achievement is evaluated against. Kept separate from the
// persisted profile so the rules stay a pure, testable function of plain numbers.
public sealed record AchievementSnapshot(
    int StreakDays,
    int TotalXp,
    int Level,
    int LessonsCompleted,
    int FlawlessLessons,
    int Gems)
{
    public int ValueFor(AchievementKind kind) => kind switch
    {
        AchievementKind.Streak => StreakDays,
        AchievementKind.TotalXp => TotalXp,
        AchievementKind.Level => Level,
        AchievementKind.LessonsCompleted => LessonsCompleted,
        AchievementKind.FlawlessLessons => FlawlessLessons,
        AchievementKind.Gems => Gems,
        _ => 0,
    };
}

public static class AchievementEngine
{
    public static readonly IReadOnlyList<AchievementTier> Tiers = Build();

    // Returns the tiers whose threshold is met by the snapshot but that the user
    // has not already unlocked. Gem rewards on the Gems family are intentionally
    // zero so awarding gems can never recursively unlock more gem achievements.
    public static IReadOnlyList<AchievementTier> NewlyUnlocked(AchievementSnapshot snapshot, IEnumerable<string> alreadyUnlocked)
    {
        var have = new HashSet<string>(alreadyUnlocked, StringComparer.OrdinalIgnoreCase);
        return Tiers
            .Where(t => !have.Contains(t.Id) && snapshot.ValueFor(t.Kind) >= t.Threshold)
            .ToArray();
    }

    public static IReadOnlyList<string> Earned(AchievementSnapshot snapshot)
        => Tiers.Where(t => snapshot.ValueFor(t.Kind) >= t.Threshold).Select(t => t.Id).ToArray();

    public static AchievementTier? Find(string id)
        => Tiers.FirstOrDefault(t => string.Equals(t.Id, id, StringComparison.OrdinalIgnoreCase));

    private static IReadOnlyList<AchievementTier> Build()
    {
        var list = new List<AchievementTier>();

        void Family(AchievementKind kind, string family, string description, (string Label, int Threshold, int Gems)[] tiers)
        {
            foreach (var (label, threshold, gems) in tiers)
            {
                list.Add(new AchievementTier(
                    Id: $"{Slug(kind)}-{threshold}",
                    Kind: kind,
                    Name: $"{family} · {label}",
                    Description: string.Format(description, threshold),
                    Tier: label,
                    Threshold: threshold,
                    RewardGems: gems));
            }
        }

        Family(AchievementKind.Streak, "Série", "Maintenir une série de {0} jours.",
            new[] { ("Bronze", 7, 20), ("Argent", 30, 50), ("Or", 100, 150), ("Diamant", 365, 500) });
        Family(AchievementKind.TotalXp, "Érudit", "Cumuler {0} XP.",
            new[] { ("Bronze", 100, 10), ("Argent", 500, 30), ("Or", 2000, 100), ("Diamant", 10000, 300) });
        Family(AchievementKind.Level, "Ascension", "Atteindre le niveau {0}.",
            new[] { ("Bronze", 5, 15), ("Argent", 10, 40), ("Or", 20, 120), ("Diamant", 35, 350) });
        Family(AchievementKind.LessonsCompleted, "Assidu", "Terminer {0} leçons.",
            new[] { ("Bronze", 10, 15), ("Argent", 50, 50), ("Or", 150, 150), ("Diamant", 400, 400) });
        Family(AchievementKind.FlawlessLessons, "Sans-faute", "Réussir {0} leçons parfaites.",
            new[] { ("Bronze", 5, 20), ("Argent", 25, 60), ("Or", 100, 200) });
        Family(AchievementKind.Gems, "Trésorier", "Gagner {0} gemmes au total.",
            new[] { ("Bronze", 100, 0), ("Argent", 500, 0), ("Or", 2000, 0) });

        return list;
    }

    private static string Slug(AchievementKind kind) => kind switch
    {
        AchievementKind.Streak => "streak",
        AchievementKind.TotalXp => "xp",
        AchievementKind.Level => "level",
        AchievementKind.LessonsCompleted => "lessons",
        AchievementKind.FlawlessLessons => "flawless",
        AchievementKind.Gems => "gems",
        _ => "misc",
    };
}
