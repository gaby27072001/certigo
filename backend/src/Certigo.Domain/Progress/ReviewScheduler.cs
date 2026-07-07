namespace Certigo.Domain.Progress;

public sealed record ConceptMastery(
    string UserId,
    string TrackId,
    string ConceptId,
    double MasteryScore,
    double Stability,
    double Difficulty,
    DateTimeOffset DueAt,
    int Reps,
    int Lapses,
    DateTimeOffset LastReviewedAt)
{
    public static ConceptMastery New(string userId, string trackId, string conceptId)
    {
        var now = DateTimeOffset.UtcNow;
        return new ConceptMastery(userId, trackId, conceptId, 0, 1, 5, now, 0, 0, now);
    }

    /// <summary>
    /// A concept is "weak" once it has been reviewed at least once yet its mastery
    /// is still below 0.5. Mirrors the Dart <c>ConceptMastery.isWeak</c> getter and
    /// is asserted by the shared weakness golden vectors.
    /// </summary>
    public bool IsWeak => Reps > 0 && MasteryScore < 0.5;
}

public enum ReviewGrade
{
    Again = 1,
    Hard = 2,
    Good = 3,
    Easy = 4
}

public static class ReviewScheduler
{
    public static ReviewGrade GradeFrom(bool correct, int latencyMs)
    {
        if (!correct)
        {
            return ReviewGrade.Again;
        }

        return latencyMs switch
        {
            < 4_000 => ReviewGrade.Easy,
            < 9_000 => ReviewGrade.Good,
            _ => ReviewGrade.Hard
        };
    }

    public static ConceptMastery Apply(ConceptMastery m, ReviewGrade g, DateTimeOffset now)
    {
        var difficulty = Clamp(m.Difficulty + (g == ReviewGrade.Again ? 0.8 : -0.15), 1, 10);
        var factor = g switch
        {
            ReviewGrade.Again => 0.5,
            ReviewGrade.Hard => 1.1,
            ReviewGrade.Good => 1.6,
            ReviewGrade.Easy => 2.1,
            _ => 1
        };

        var stability = g == ReviewGrade.Again
            ? Math.Max(0.5, m.Stability * 0.4)
            : m.Stability * factor;

        var mastery = Clamp(1 - Math.Exp(-stability / 20), 0, 1);

        return m with
        {
            Difficulty = difficulty,
            Stability = stability,
            MasteryScore = mastery,
            Reps = m.Reps + 1,
            Lapses = m.Lapses + (g == ReviewGrade.Again ? 1 : 0),
            LastReviewedAt = now,
            DueAt = now.AddDays(stability)
        };
    }

    private static double Clamp(double value, double min, double max) => Math.Min(max, Math.Max(min, value));
}
