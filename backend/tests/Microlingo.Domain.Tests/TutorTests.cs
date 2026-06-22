using FluentAssertions;
using Microlingo.Domain.Content;
using Microlingo.Domain.Tutor;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class TutorTests
{
    private static readonly DateTimeOffset T0 = new(2025, 1, 6, 12, 0, 0, TimeSpan.Zero);

    // --- LearnerModel.Observe ------------------------------------------------

    [Fact]
    public void Observe_from_empty_records_one_correct_attempt()
    {
        var stat = LearnerModel.Observe(null, "c1", correct: true, chosenWrongOptionId: null, T0);

        stat.ConceptId.Should().Be("c1");
        stat.Attempts.Should().Be(1);
        stat.Correct.Should().Be(1);
        stat.Errors.Should().Be(0);
        stat.ConsecutiveErrors.Should().Be(0);
        stat.LastSeen.Should().Be(T0);
        stat.Accuracy.Should().Be(1d);
    }

    [Fact]
    public void Observe_tallies_wrong_option_and_tracks_consecutive_errors()
    {
        var s1 = LearnerModel.Observe(null, "c1", correct: false, "b", T0);
        var s2 = LearnerModel.Observe(s1, "c1", correct: false, "b", T0.AddMinutes(1));

        s2.Attempts.Should().Be(2);
        s2.Errors.Should().Be(2);
        s2.ConsecutiveErrors.Should().Be(2);
        s2.WrongOptionTally["b"].Should().Be(2);
        s2.LastWrongOptionId.Should().Be("b");
    }

    [Fact]
    public void Observe_correct_answer_resets_consecutive_errors_but_keeps_tally()
    {
        var s1 = LearnerModel.Observe(null, "c1", correct: false, "b", T0);
        var s2 = LearnerModel.Observe(s1, "c1", correct: true, null, T0.AddMinutes(1));

        s2.ConsecutiveErrors.Should().Be(0);
        s2.Errors.Should().Be(1);
        s2.Correct.Should().Be(1);
        s2.WrongOptionTally["b"].Should().Be(1);
    }

    // --- Derived signals -----------------------------------------------------

    [Fact]
    public void IsRecurringStruggle_triggers_on_two_total_errors()
    {
        var s = Build(attempts: 4, correct: 2, errors: 2, consecutive: 0);
        LearnerModel.IsRecurringStruggle(s).Should().BeTrue();
    }

    [Fact]
    public void IsRecurringStruggle_is_false_below_threshold()
    {
        var s = Build(attempts: 3, correct: 2, errors: 1, consecutive: 1);
        LearnerModel.IsRecurringStruggle(s).Should().BeFalse();
        LearnerModel.IsRecurringStruggle(null).Should().BeFalse();
    }

    [Fact]
    public void IsMastered_requires_enough_attempts_high_accuracy_and_no_active_streak()
    {
        LearnerModel.IsMastered(Build(attempts: 5, correct: 5, errors: 0, consecutive: 0)).Should().BeTrue();
        LearnerModel.IsMastered(Build(attempts: 2, correct: 2, errors: 0, consecutive: 0)).Should().BeFalse();
        LearnerModel.IsMastered(Build(attempts: 5, correct: 5, errors: 0, consecutive: 1)).Should().BeFalse();
    }

    [Fact]
    public void TopConfusion_returns_most_frequent_wrong_option_with_deterministic_tiebreak()
    {
        var tally = new Dictionary<string, int> { ["b"] = 2, ["c"] = 3, ["d"] = 3 };
        var s = Build(attempts: 8, correct: 0, errors: 8, consecutive: 8, tally: tally);

        // c and d tie at 3 → ordinal tiebreak picks "c".
        LearnerModel.TopConfusion(s).Should().Be("c");
        LearnerModel.TopConfusion(null).Should().BeNull();
    }

    [Fact]
    public void TrendFor_detects_comeback_and_slip()
    {
        var struggling = Build(attempts: 3, correct: 0, errors: 3, consecutive: 3);
        LearnerModel.TrendFor(struggling, correct: true).Should().Be(LearnerTrend.Improving);

        var mastered = Build(attempts: 5, correct: 5, errors: 0, consecutive: 0);
        LearnerModel.TrendFor(mastered, correct: false).Should().Be(LearnerTrend.Slipping);

        LearnerModel.TrendFor(null, correct: true).Should().Be(LearnerTrend.Steady);
    }

    // --- Context factory: signals --------------------------------------------

    [Fact]
    public void Create_with_no_history_yields_neutral_learner_signals()
    {
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" });

        ctx.IsCorrect.Should().BeTrue();
        ctx.Learner.Should().Be(TutorLearnerSignals.None);
    }

    [Fact]
    public void Create_resolves_top_confusion_id_to_human_label_and_flags_struggle()
    {
        var tally = new Dictionary<string, int> { ["b"] = 3 };
        var prior = Build(attempts: 3, correct: 0, errors: 3, consecutive: 3, tally: tally, lastWrong: "b");

        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" }, prior);

        ctx.IsCorrect.Should().BeTrue();
        ctx.Learner.RecurringStruggle.Should().BeTrue();
        ctx.Learner.TopConfusedOptionLabel.Should().Be("Wrong");
        ctx.Learner.Trend.Should().Be(LearnerTrend.Improving);
    }

    // --- Composer: personalised, grounded ------------------------------------

    [Fact]
    public void Compose_correct_no_history_is_positive_and_grounded()
    {
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" });
        var e = TutorComposer.Compose(ctx);

        e.Source.Should().Be("grounded");
        e.Headline.Should().Be("Nice — here's why that's right.");
        e.CitedConceptIds.Should().Contain("c1");
        e.Recommendation.Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public void Compose_incorrect_recurring_struggle_acknowledges_history_and_names_trap()
    {
        var tally = new Dictionary<string, int> { ["b"] = 3 };
        var prior = Build(attempts: 3, correct: 0, errors: 3, consecutive: 3, tally: tally, lastWrong: "b");

        // Learner picks their signature trap "b" again.
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "b" }, prior);
        var e = TutorComposer.Compose(ctx);

        ctx.IsCorrect.Should().BeFalse();
        e.Headline.Should().Be("This one keeps tripping you up — let's lock it in.");
        e.Points.Should().Contain(p => p.Contains("practised this concept"));
        e.Points.Should().Contain(p => p.Contains("same option you tend to fall for"));
        e.Recommendation.Should().Contain("retry this concept");
    }

    [Fact]
    public void Compose_comeback_celebrates_improvement()
    {
        var prior = Build(attempts: 3, correct: 0, errors: 3, consecutive: 3);
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" }, prior);
        var e = TutorComposer.Compose(ctx);

        e.Headline.Should().Be("Big improvement — you turned this one around!");
        e.Points.Should().Contain(p => p.Contains("just got it right"));
        e.Encouragement.Should().Contain("one comeback at a time");
    }

    // --- Guardrails ----------------------------------------------------------

    [Fact]
    public void Guardrails_pass_for_grounded_explanation()
    {
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "b" });
        var e = TutorComposer.Compose(ctx);

        TutorGuardrails.Validate(e, ctx).Ok.Should().BeTrue();
    }

    [Fact]
    public void Guardrails_reject_ungrounded_cited_concept()
    {
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" });
        var bad = new TutorExplanation(
            "ok", new[] { "point" }, "go", new[] { "not-a-real-concept" }, "do this next.", "ai");

        var result = TutorGuardrails.Validate(bad, ctx);
        result.Ok.Should().BeFalse();
        result.Violations.Should().Contain(v => v.StartsWith("cited.ungrounded:"));
    }

    [Fact]
    public void Guardrails_reject_exam_integrity_banned_phrases()
    {
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" });
        var bad = new TutorExplanation(
            "This is a real exam question", new[] { "point" }, "go", new[] { "c1" }, "do this next.", "ai");

        TutorGuardrails.Validate(bad, ctx).Ok.Should().BeFalse();
    }

    [Fact]
    public void Guardrails_reject_missing_recommendation()
    {
        var ctx = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" });
        var bad = new TutorExplanation(
            "ok", new[] { "point" }, "go", new[] { "c1" }, "   ", "ai");

        var result = TutorGuardrails.Validate(bad, ctx);
        result.Ok.Should().BeFalse();
        result.Violations.Should().Contain("recommendation.empty");
    }

    // --- Prompt builder ------------------------------------------------------

    [Fact]
    public void User_prompt_emits_learner_history_only_when_history_exists()
    {
        var withoutHistory = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "a" });
        TutorPromptBuilder.User(withoutHistory).Should().NotContain("Learner history for this concept");

        var tally = new Dictionary<string, int> { ["b"] = 2 };
        var prior = Build(attempts: 3, correct: 1, errors: 2, consecutive: 2, tally: tally, lastWrong: "b");
        var withHistory = TutorContextFactory.Create(Track(), Lesson(), KeyItem(), new[] { "b" }, prior);

        var prompt = TutorPromptBuilder.User(withHistory);
        prompt.Should().Contain("Learner history for this concept");
        prompt.Should().Contain("recurringStruggle=yes");
        prompt.Should().Contain("most common wrong choice here: \"Wrong\"");
    }

    // --- helpers -------------------------------------------------------------

    private static LearnerConceptStat Build(
        int attempts,
        int correct,
        int errors,
        int consecutive,
        IReadOnlyDictionary<string, int>? tally = null,
        string? lastWrong = null)
        => new(
            "c1",
            attempts,
            correct,
            errors,
            consecutive,
            tally ?? new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase),
            lastWrong,
            T0);

    private static Track Track() => new(
        Id: "az-900",
        Code: "AZ-900",
        Title: "Azure Fundamentals",
        Summary: "Foundations.",
        Domains: new[] { new ExamDomain("d1", "Cloud concepts", 1.0) },
        Units: new[] { new TrackUnit("u1", "d1", "Cloud concepts", new[] { "l1" }) });

    private static Lesson Lesson() => new(
        Id: "l1",
        TrackId: "az-900",
        UnitId: "u1",
        DomainId: "d1",
        Title: "CapEx vs OpEx",
        EstMinutes: 4,
        Blocks: new[]
        {
            new LessonBlock("concept", "c1", Title: "CapEx vs OpEx", Body: "OpEx is pay-as-you-go."),
            new LessonBlock("check", "c1", Check: new LessonCheck(
                Id: "l1-i1",
                ConceptId: "c1",
                Type: ItemType.Mcq,
                Stem: "Which is pay-as-you-go?",
                Options: new[]
                {
                    new CheckOption("a", "Correct"),
                    new CheckOption("b", "Wrong")
                }))
        });

    private static AnswerKeyItem KeyItem() =>
        new("l1-i1", "c1", ItemType.Mcq, 1, new[] { "a" }, "Because a is correct.");
}
