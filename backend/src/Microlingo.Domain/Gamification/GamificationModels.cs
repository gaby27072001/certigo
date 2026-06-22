using Microlingo.Domain.Content;
using Microlingo.Domain.Progress;

namespace Microlingo.Domain.Gamification;

public sealed record GamificationStats(
    int Xp,
    int Level,
    int StreakDays,
    DateOnly LastActiveDate,
    int FreezeTokens,
    int DailyGoalXp,
    int DailyXpEarned);

public static class XpEngine
{
    public static int ForQuizItem(ItemType itemType, int difficulty, bool correct, ConceptMastery before, ConceptMastery after)
    {
        if (!correct)
        {
            return 0;
        }

        // Authored difficulty is 1 (recall) · 2 (apply) · 3 (analyze). Normalize to
        // 0..1 so the XP curve below stays continuous and tunable.
        var d = Math.Clamp((difficulty - 1) / 2.0, 0, 1);
        var now = DateTimeOffset.UtcNow;
        var isApplied = itemType is ItemType.Scenario or ItemType.Applied;
        var xp = isApplied ? 10 : 6;

        if (before.MasteryScore < 0.5 && after.MasteryScore >= 0.5)
        {
            xp += 25;
        }

        if (before.DueAt <= now)
        {
            xp += 15;
        }

        if (before.MasteryScore > 0.85 && d < 0.4)
        {
            return 1;
        }

        return (int)Math.Round(xp * (0.8 + d), MidpointRounding.AwayFromZero);
    }

    public static int SoftCap(int dailyXp, int goal)
    {
        if (goal <= 0 || dailyXp <= goal * 2)
        {
            return dailyXp;
        }

        var excess = dailyXp - goal * 2;
        return goal * 2 + (int)Math.Round(Math.Sqrt(excess));
    }

    public static double StreakMultiplier(int streakDays) => Math.Min(1.2, 1 + 0.02 * (streakDays / 7.0));

    public static int LevelFromXp(int totalXp)
    {
        var level = 1;
        while (totalXp >= XpForLevel(level + 1))
        {
            level++;
        }

        return level;
    }

    private static int XpForLevel(int level) => (int)Math.Round(100 * Math.Pow(level, 1.5));
}

public static class StreakService
{
    public static GamificationStats UpdateStreak(GamificationStats stats, DateOnly today, bool goalMet)
    {
        if (!goalMet || stats.LastActiveDate == today)
        {
            return stats;
        }

        var yesterday = today.AddDays(-1);
        if (stats.LastActiveDate == yesterday)
        {
            return stats with { StreakDays = stats.StreakDays + 1, LastActiveDate = today };
        }

        if (stats.FreezeTokens > 0 && stats.LastActiveDate >= today.AddDays(-2))
        {
            return stats with { FreezeTokens = stats.FreezeTokens - 1, LastActiveDate = today };
        }

        return stats with { StreakDays = 1, LastActiveDate = today };
    }
}
