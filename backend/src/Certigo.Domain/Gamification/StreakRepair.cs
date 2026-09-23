namespace Certigo.Domain.Gamification;

public readonly record struct StreakRepairAssessment(
    bool Repairable,
    int CostGems,
    DateOnly BridgeTo,
    string? Reason,
    DateOnly? LastRepairableDay = null)
{
    // Callers derive `today` from the UTC clock, so every day here is a UTC calendar
    // day and the offer closes at the first UTC instant after LastRepairableDay.
    // Publishing that instant lets a client state the window without re-deriving
    // MaxGapDays, and stay correct in any time zone.
    public DateTimeOffset? ExpiresAt => LastRepairableDay is { } day
        ? new DateTimeOffset(day.AddDays(1).ToDateTime(TimeOnly.MinValue), TimeSpan.Zero)
        : null;
}

// Pure policy for the paid streak-repair gem sink (plan §3.4). A repair bridges
// a recent gap by moving the last-active marker to yesterday, so the next
// goal-met day continues the streak instead of resetting it. Repair is only
// offered for short, recent gaps — a long-abandoned streak is truly lost.
public static class StreakRepairPolicy
{
    public const int CostGems = 50;
    public const int MaxGapDays = 7;

    public static StreakRepairAssessment Assess(int streakDays, DateOnly? lastActiveDate, DateOnly today)
    {
        var bridgeTo = today.AddDays(-1);

        if (streakDays <= 0 || lastActiveDate is null)
        {
            return new StreakRepairAssessment(false, CostGems, bridgeTo, "noStreak");
        }

        var last = lastActiveDate.Value;

        // Active today or yesterday → the streak is intact, nothing to repair.
        if (last >= bridgeTo)
        {
            return new StreakRepairAssessment(false, CostGems, bridgeTo, "intact");
        }

        var missedDays = today.DayNumber - last.DayNumber - 1;
        if (missedDays > MaxGapDays)
        {
            return new StreakRepairAssessment(false, CostGems, bridgeTo, "expired");
        }

        // Still repairable while missedDays <= MaxGapDays, i.e. through last + MaxGapDays + 1.
        return new StreakRepairAssessment(true, CostGems, bridgeTo, null, last.AddDays(MaxGapDays + 1));
    }
}
