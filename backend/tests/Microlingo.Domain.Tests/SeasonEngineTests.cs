using FluentAssertions;
using Microlingo.Domain.Gamification;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class SeasonEngineTests
{
    [Fact]
    public void ForMonth_is_deterministic_for_same_year_and_month()
    {
        var first = SeasonEngine.ForMonth(2025, 1);
        var second = SeasonEngine.ForMonth(2025, 1);

        second.Should().Be(first);
    }

    [Fact]
    public void ForMonth_builds_a_stable_id_and_carries_year_and_month()
    {
        SeasonEngine.ForMonth(2025, 1).Id.Should().Be("2025-01");
        SeasonEngine.ForMonth(2025, 12).Id.Should().Be("2025-12");

        var season = SeasonEngine.ForMonth(2026, 7);
        season.Year.Should().Be(2026);
        season.Month.Should().Be(7);
        season.Id.Should().Be("2026-07");
    }

    [Theory]
    [InlineData(0)]
    [InlineData(13)]
    [InlineData(-1)]
    public void ForMonth_rejects_out_of_range_months(int month)
    {
        var act = () => SeasonEngine.ForMonth(2025, month);

        act.Should().Throw<ArgumentOutOfRangeException>();
    }

    [Fact]
    public void Every_month_of_the_year_yields_a_distinct_theme_and_badge()
    {
        var seasons = Enumerable.Range(1, 12)
            .Select(m => SeasonEngine.ForMonth(2025, m))
            .ToArray();

        seasons.Should().HaveCount(12);
        seasons.Select(s => s.Theme).Should().OnlyHaveUniqueItems();
        seasons.Select(s => s.Challenge.BadgeId).Should().OnlyHaveUniqueItems();
        seasons.Select(s => s.Challenge.BadgeTitle).Should().OnlyHaveUniqueItems();
    }

    [Fact]
    public void ForDate_resolves_the_season_that_owns_the_date()
    {
        var fromDate = SeasonEngine.ForDate(new DateOnly(2025, 3, 18));
        var fromMonth = SeasonEngine.ForMonth(2025, 3);

        fromDate.Should().Be(fromMonth);
    }

    [Fact]
    public void January_season_is_the_cloud_renewal_theme_with_an_xp_goal()
    {
        var season = SeasonEngine.ForMonth(2025, 1);

        season.Theme.Should().Be("Renouveau Cloud");
        season.Tagline.Should().Be("Lance ton année dans le nuage");
        season.Mascot.Should().Be("Nimbus");
        season.Accent.Should().Be("#4F8BFF");
        season.Challenge.Kind.Should().Be(SeasonGoalKind.EarnXp);
        season.Challenge.Target.Should().Be(1200);
        season.Challenge.RewardGems.Should().Be(120);
        season.Challenge.BadgeId.Should().Be("season-renouveau-cloud");
        season.Challenge.BadgeTitle.Should().Be("Pionnier du Cloud");
        season.Challenge.Title.Should().Be("Gagne 1200 XP en janvier");
    }

    [Fact]
    public void March_season_is_the_governance_sprint_with_a_perfect_lessons_goal()
    {
        var season = SeasonEngine.ForMonth(2025, 3);

        season.Theme.Should().Be("Sprint Gouvernance");
        season.Mascot.Should().Be("Sentinel");
        season.Challenge.Kind.Should().Be(SeasonGoalKind.PerfectLessons);
        season.Challenge.Target.Should().Be(15);
        season.Challenge.BadgeId.Should().Be("season-sprint-gouvernance");
        season.Challenge.Title.Should().Be("Réussis 15 leçons sans faute en mars");
    }

    [Fact]
    public void Evaluate_caps_current_at_target_and_flags_completion()
    {
        var season = SeasonEngine.ForMonth(2025, 1); // EarnXp 1200

        var met = SeasonEngine.Evaluate(season, new SeasonSignals(XpEarned: 1500, LessonsCompleted: 0, PerfectLessons: 0));
        met.Completed.Should().BeTrue();
        met.Current.Should().Be(1200); // capped at target

        var exact = SeasonEngine.Evaluate(season, new SeasonSignals(XpEarned: 1200, LessonsCompleted: 0, PerfectLessons: 0));
        exact.Completed.Should().BeTrue();
        exact.Current.Should().Be(1200);

        var partial = SeasonEngine.Evaluate(season, new SeasonSignals(XpEarned: 800, LessonsCompleted: 0, PerfectLessons: 0));
        partial.Completed.Should().BeFalse();
        partial.Current.Should().Be(800);
    }

    [Fact]
    public void Evaluate_of_empty_signals_is_never_complete()
    {
        var season = SeasonEngine.ForMonth(2025, 1);

        var status = SeasonEngine.Evaluate(season, SeasonSignals.Empty);

        status.Current.Should().Be(0);
        status.Completed.Should().BeFalse();
    }

    [Theory]
    [InlineData(SeasonGoalKind.EarnXp, 1200)]
    [InlineData(SeasonGoalKind.CompleteLessons, 40)]
    [InlineData(SeasonGoalKind.PerfectLessons, 12)]
    public void Progress_reads_the_matching_signal(SeasonGoalKind kind, int expected)
    {
        var signals = new SeasonSignals(XpEarned: 1200, LessonsCompleted: 40, PerfectLessons: 12);

        SeasonEngine.Progress(kind, signals).Should().Be(expected);
    }
}
