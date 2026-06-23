namespace Microlingo.Domain.Recommendation;

/// The kind of next-best action the coach can recommend. The integer order is the
/// interrupt-priority used to break ties: a behavioural struggle outranks a memory
/// review, which outranks resuming, which outranks starting something new.
public enum RecommendationKind
{
    Practice,
    Review,
    Resume,
    Start
}

/// Where a lesson sits on the skill-path, mirroring the statuses the path computes.
public enum LessonProgress
{
    Locked,
    Available,
    InProgress,
    Completed,
    Mastered
}

/// A lesson as the recommender sees it: its place on the path, its size, and the
/// concepts it teaches. Built by the application layer from content + progress.
public sealed record LessonCandidate(
    string LessonId,
    string UnitId,
    string Title,
    string DomainId,
    double DomainWeight,
    int EstMinutes,
    IReadOnlyList<string> ConceptIds,
    LessonProgress Progress);

/// One concept fused from FSRS memory state (mastery, stability, due date) and the
/// behavioural learner model (errors, consecutive errors). This is the single unit
/// the engine reasons over when deciding what is worth reviewing or practising.
public sealed record ConceptSignal(
    string ConceptId,
    string DomainId,
    double DomainWeight,
    double MasteryScore,
    double Stability,
    DateTimeOffset DueAt,
    DateTimeOffset LastReviewedAt,
    int Errors,
    int ConsecutiveErrors);

/// A scored next-best action. The application layer turns this into a localized,
/// user-facing card; the engine only decides what and how urgent.
public sealed record RecommendationCandidate(
    RecommendationKind Kind,
    string? LessonId,
    string? UnitId,
    string? ConceptId,
    string DomainId,
    double Priority,
    double MasteryScore,
    double ForgettingRisk,
    int EstMinutes);

/// FSRS-style memory decay: the same exponential-over-stability form the scheduler
/// and readiness calculator already use, exposed as an explicit recall probability.
public static class Recall
{
    /// Probability the learner still recalls a concept after <paramref name="elapsedDays"/>.
    public static double Probability(double stability, double elapsedDays)
    {
        var s = Math.Max(0.1, stability);
        var d = Math.Max(0, elapsedDays);
        return Math.Exp(-d / s);
    }

    /// 1 - recall: how likely the concept has been forgotten. Rises with time.
    public static double ForgettingRisk(double stability, double elapsedDays)
        => 1 - Probability(stability, elapsedDays);
}

/// Pure "next best action" engine. Given the learner's path and per-concept memory
/// signals, it ranks what to do right now to maximise readiness while honouring
/// forgetting risk and active struggles. Deterministic and side-effect free, so the
/// coach's judgement is fully unit-testable without any store.
public static class RecommendationEngine
{
    /// Errors (or consecutive errors) at or above this count mark a concept as an
    /// active struggle worth interrupting for, matching the tutor's threshold.
    public const int StruggleErrorThreshold = 2;

    /// A not-yet-overdue concept is only surfaced for review once its forgetting
    /// risk crosses this, so the coach nudges before the memory is fully gone.
    public const double ReviewRiskThreshold = 0.3d;

    public static IReadOnlyList<RecommendationCandidate> Rank(
        IReadOnlyList<LessonCandidate> lessons,
        IReadOnlyList<ConceptSignal> concepts,
        DateTimeOffset now,
        int max = 5)
    {
        var conceptHome = BuildConceptHome(lessons);
        var candidates = new List<RecommendationCandidate>();

        foreach (var c in concepts)
        {
            var risk = Recall.ForgettingRisk(c.Stability, ElapsedDays(c, now));
            conceptHome.TryGetValue(c.ConceptId, out var home);

            if (IsStruggle(c))
            {
                // Behavioural: the learner keeps missing this. Escalate with the
                // current losing streak so a hardening misconception jumps the queue.
                var escalation = Math.Min(1d, c.ConsecutiveErrors / 3d);
                var priority = Clamp01(0.70 + (0.20 * escalation) + (0.10 * c.DomainWeight)) * 100;
                candidates.Add(new RecommendationCandidate(
                    RecommendationKind.Practice, home?.LessonId, home?.UnitId, c.ConceptId,
                    c.DomainId, priority, c.MasteryScore, risk, home?.EstMinutes ?? 0));
                continue;
            }

            // Memory: FSRS says this is fading. Reviewing a once-strong concept is
            // worth more (preserve the investment) and high-weight domains matter more.
            var overdue = now >= c.DueAt;
            if (!overdue && risk < ReviewRiskThreshold)
            {
                continue;
            }

            var reviewPriority = Clamp01(0.40 + (0.40 * risk) + (0.20 * c.DomainWeight)) * 100;
            if (overdue)
            {
                reviewPriority = Math.Min(100, reviewPriority + 5);
            }

            candidates.Add(new RecommendationCandidate(
                RecommendationKind.Review, home?.LessonId, home?.UnitId, c.ConceptId,
                c.DomainId, reviewPriority, c.MasteryScore, risk, home?.EstMinutes ?? 0));
        }

        foreach (var l in lessons)
        {
            if (l.Progress == LessonProgress.InProgress)
            {
                var priority = Clamp01(0.62 + (0.20 * l.DomainWeight)) * 100;
                candidates.Add(new RecommendationCandidate(
                    RecommendationKind.Resume, l.LessonId, l.UnitId, null, l.DomainId,
                    priority, LessonMastery(l, concepts), 0, l.EstMinutes));
            }
        }

        // Breadth-first like readiness: a fresh, high-weight domain is the biggest
        // readiness lever, so an available lesson there outranks one in a covered area.
        var coverageByDomain = CoverageByDomain(lessons);
        foreach (var l in lessons)
        {
            if (l.Progress == LessonProgress.Available)
            {
                var gap = 1 - coverageByDomain.GetValueOrDefault(l.DomainId, 0d);
                var priority = Clamp01(0.45 + (0.30 * l.DomainWeight) + (0.15 * gap)) * 100;
                candidates.Add(new RecommendationCandidate(
                    RecommendationKind.Start, l.LessonId, l.UnitId, null, l.DomainId,
                    priority, LessonMastery(l, concepts), 0, l.EstMinutes));
            }
        }

        // Never leave the coach empty when there is history: if nothing crossed a
        // threshold, surface the single most-at-risk concept as a gentle review.
        if (candidates.Count == 0 && concepts.Count > 0)
        {
            var weakest = concepts
                .OrderByDescending(c => Recall.ForgettingRisk(c.Stability, ElapsedDays(c, now)))
                .ThenBy(c => c.ConceptId, StringComparer.Ordinal)
                .First();
            var risk = Recall.ForgettingRisk(weakest.Stability, ElapsedDays(weakest, now));
            conceptHome.TryGetValue(weakest.ConceptId, out var home);
            candidates.Add(new RecommendationCandidate(
                RecommendationKind.Review, home?.LessonId, home?.UnitId, weakest.ConceptId,
                weakest.DomainId, Clamp01(0.30 + (0.30 * risk)) * 100, weakest.MasteryScore, risk,
                home?.EstMinutes ?? 0));
        }

        return candidates
            .OrderByDescending(c => c.Priority)
            .ThenBy(c => (int)c.Kind)
            .ThenBy(c => c.ConceptId ?? c.LessonId ?? string.Empty, StringComparer.Ordinal)
            .Take(Math.Max(1, max))
            .ToArray();
    }

    private static bool IsStruggle(ConceptSignal c)
        => c.Errors >= StruggleErrorThreshold || c.ConsecutiveErrors >= StruggleErrorThreshold;

    private static double ElapsedDays(ConceptSignal c, DateTimeOffset now)
        => Math.Max(0, (now - c.LastReviewedAt).TotalDays);

    private static Dictionary<string, LessonCandidate> BuildConceptHome(IReadOnlyList<LessonCandidate> lessons)
    {
        // The "home" of a concept is the first lesson that teaches it, so reviewing
        // it opens a concrete, openable lesson rather than a bare concept id.
        var home = new Dictionary<string, LessonCandidate>(StringComparer.OrdinalIgnoreCase);
        foreach (var lesson in lessons)
        {
            foreach (var conceptId in lesson.ConceptIds)
            {
                if (!home.ContainsKey(conceptId))
                {
                    home[conceptId] = lesson;
                }
            }
        }

        return home;
    }

    private static Dictionary<string, double> CoverageByDomain(IReadOnlyList<LessonCandidate> lessons)
    {
        return lessons
            .GroupBy(l => l.DomainId, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(
                g => g.Key,
                g => g.Count(l => l.Progress is LessonProgress.Completed or LessonProgress.Mastered)
                    / (double)Math.Max(1, g.Count()),
                StringComparer.OrdinalIgnoreCase);
    }

    private static double LessonMastery(LessonCandidate lesson, IReadOnlyList<ConceptSignal> concepts)
    {
        if (lesson.ConceptIds.Count == 0)
        {
            return 0d;
        }

        var byConcept = concepts.ToDictionary(c => c.ConceptId, c => c.MasteryScore, StringComparer.OrdinalIgnoreCase);
        return lesson.ConceptIds.Average(id => byConcept.GetValueOrDefault(id, 0d));
    }

    private static double Clamp01(double value) => Math.Min(1d, Math.Max(0d, value));
}
