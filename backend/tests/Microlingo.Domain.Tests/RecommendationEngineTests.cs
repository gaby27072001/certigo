using FluentAssertions;
using Microlingo.Domain.Recommendation;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class RecommendationEngineTests
{
    private static readonly DateTimeOffset Now = new(2025, 6, 1, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Recall_probability_decreases_as_time_passes()
    {
        var fresh = Recall.Probability(10, 1);
        var older = Recall.Probability(10, 5);
        var stale = Recall.Probability(10, 25);

        fresh.Should().BeGreaterThan(older);
        older.Should().BeGreaterThan(stale);
        Recall.ForgettingRisk(10, 25).Should().BeApproximately(1 - stale, 1e-9);
    }

    [Fact]
    public void Recall_probability_increases_with_stability()
    {
        Recall.Probability(1, 5).Should().BeLessThan(Recall.Probability(60, 5));
    }

    [Fact]
    public void Recall_never_divides_by_zero_stability()
    {
        var p = Recall.Probability(0, 5);
        p.Should().BeInRange(0, 1);
    }

    [Fact]
    public void Rank_prioritises_active_struggle_as_practice()
    {
        var lessons = new[] { Lesson("l1", "u1", "d1", 0.5, LessonProgress.Available, "c1") };
        var concepts = new[]
        {
            // A hardening misconception: many errors, on a losing streak.
            Signal("c1", "d1", 0.5, mastery: 0.2, stability: 3, dueDays: -2, lastReviewedDaysAgo: 4, errors: 3, consecutiveErrors: 3)
        };

        var ranked = RecommendationEngine.Rank(lessons, concepts, Now);

        ranked.Should().NotBeEmpty();
        ranked[0].Kind.Should().Be(RecommendationKind.Practice);
        ranked[0].ConceptId.Should().Be("c1");
        ranked[0].Priority.Should().BeGreaterThan(90);
    }

    [Fact]
    public void Rank_surfaces_overdue_concept_as_review()
    {
        var lessons = new[] { Lesson("l1", "u1", "d1", 0.6, LessonProgress.Completed, "c1") };
        var concepts = new[]
        {
            Signal("c1", "d1", 0.6, mastery: 0.7, stability: 8, dueDays: -3, lastReviewedDaysAgo: 10, errors: 0, consecutiveErrors: 0)
        };

        var ranked = RecommendationEngine.Rank(lessons, concepts, Now);

        ranked.Should().ContainSingle(r => r.Kind == RecommendationKind.Review && r.ConceptId == "c1");
        ranked.Single(r => r.ConceptId == "c1").ForgettingRisk.Should().BeGreaterThan(0);
    }

    [Fact]
    public void Rank_skips_fresh_low_risk_concept()
    {
        var lessons = new[] { Lesson("l2", "u1", "d1", 0.5, LessonProgress.Available, "c2") };
        var concepts = new[]
        {
            // Reviewed today, very stable, not due → below the review threshold.
            Signal("c1", "d1", 0.5, mastery: 0.95, stability: 90, dueDays: 30, lastReviewedDaysAgo: 0, errors: 0, consecutiveErrors: 0)
        };

        var ranked = RecommendationEngine.Rank(lessons, concepts, Now);

        ranked.Should().NotContain(r => r.ConceptId == "c1");
        ranked.Should().Contain(r => r.Kind == RecommendationKind.Start && r.LessonId == "l2");
    }

    [Fact]
    public void Rank_resumes_in_progress_lesson()
    {
        var lessons = new[] { Lesson("l1", "u1", "d1", 0.5, LessonProgress.InProgress, "c1") };

        var ranked = RecommendationEngine.Rank(lessons, Array.Empty<ConceptSignal>(), Now);

        ranked.Should().ContainSingle(r => r.Kind == RecommendationKind.Resume && r.LessonId == "l1");
    }

    [Fact]
    public void Rank_prefers_uncovered_high_weight_domain_for_start()
    {
        var lessons = new[]
        {
            Lesson("low", "u1", "d-low", 0.2, LessonProgress.Available, "c1"),
            Lesson("high", "u2", "d-high", 0.8, LessonProgress.Available, "c2")
        };

        var ranked = RecommendationEngine.Rank(lessons, Array.Empty<ConceptSignal>(), Now);

        ranked.Should().NotBeEmpty();
        ranked[0].LessonId.Should().Be("high");
    }

    [Fact]
    public void Rank_is_deterministic()
    {
        var lessons = new[]
        {
            Lesson("l1", "u1", "d1", 0.5, LessonProgress.Available, "c1"),
            Lesson("l2", "u1", "d1", 0.5, LessonProgress.InProgress, "c2")
        };
        var concepts = new[]
        {
            Signal("c2", "d1", 0.5, 0.4, 4, -1, 6, 2, 2),
            Signal("c3", "d2", 0.5, 0.6, 6, -2, 8, 0, 0)
        };

        var first = RecommendationEngine.Rank(lessons, concepts, Now);
        var second = RecommendationEngine.Rank(lessons, concepts, Now);

        first.Select(r => (r.Kind, r.LessonId, r.ConceptId, r.Priority))
            .Should().Equal(second.Select(r => (r.Kind, r.LessonId, r.ConceptId, r.Priority)));
    }

    [Fact]
    public void Rank_is_empty_when_no_history_and_no_lessons()
    {
        var ranked = RecommendationEngine.Rank(
            Array.Empty<LessonCandidate>(), Array.Empty<ConceptSignal>(), Now);

        ranked.Should().BeEmpty();
    }

    [Fact]
    public void Rank_falls_back_to_weakest_concept_when_nothing_crosses_threshold()
    {
        // No actionable lessons, and the only concept is fresh + low-risk: the coach
        // must still surface something rather than going silent on an active learner.
        var concepts = new[]
        {
            Signal("c1", "d1", 0.5, 0.9, 80, 30, 0, 0, 0),
            Signal("c2", "d1", 0.5, 0.8, 5, 40, 1, 0, 0)
        };

        var ranked = RecommendationEngine.Rank(Array.Empty<LessonCandidate>(), concepts, Now);

        ranked.Should().HaveCount(1);
        ranked[0].Kind.Should().Be(RecommendationKind.Review);
        // c2 has the lower stability, so the higher forgetting risk → it wins.
        ranked[0].ConceptId.Should().Be("c2");
    }

    [Fact]
    public void Rank_respects_the_max_cap()
    {
        var lessons = Enumerable.Range(0, 8)
            .Select(i => Lesson($"l{i}", "u1", "d1", 0.5, LessonProgress.Available, $"c{i}"))
            .ToArray();

        var ranked = RecommendationEngine.Rank(lessons, Array.Empty<ConceptSignal>(), Now, max: 3);

        ranked.Should().HaveCount(3);
    }

    [Fact]
    public void Rank_struggle_outranks_review_on_a_priority_tie()
    {
        // Engineer equal priorities so only the Kind tiebreak can decide order.
        // Practice: 0.70 + 0.20*esc + 0.10*w ; Review: 0.40 + 0.40*risk + 0.20*w.
        var concepts = new[]
        {
            // Practice: 0.70 + 0.20*0 + 0.10*0 = 0.70.
            Signal("z-practice", "d1", 0d, 0.3, 100, 30, 1, errors: 2, consecutiveErrors: 0),
            // Review: 0.40 + 0.40*0.375 + 0.20*0.75 = 0.70 (risk 0.375 at 47d/stab100, not overdue).
            Signal("a-review", "d1", 0.75, 0.5, 100, 5, 47, errors: 0, consecutiveErrors: 0)
        };

        var ranked = RecommendationEngine.Rank(
            new[] { Lesson("l1", "u1", "d1", 0.5, LessonProgress.Completed, "z-practice") },
            concepts, Now);

        ranked[0].Kind.Should().Be(RecommendationKind.Practice);
    }

    private static LessonCandidate Lesson(
        string lessonId, string unitId, string domainId, double weight, LessonProgress progress, params string[] concepts)
        => new(lessonId, unitId, lessonId, domainId, weight, 5, concepts, progress);

    private static ConceptSignal Signal(
        string conceptId,
        string domainId,
        double weight,
        double mastery,
        double stability,
        double dueDays,
        double lastReviewedDaysAgo,
        int errors,
        int consecutiveErrors)
        => new(
            conceptId,
            domainId,
            weight,
            mastery,
            stability,
            Now.AddDays(dueDays),
            Now.AddDays(-lastReviewedDaysAgo),
            errors,
            consecutiveErrors);
}
