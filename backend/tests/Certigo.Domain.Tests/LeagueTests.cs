using FluentAssertions;
using Certigo.Domain.Gamification;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class LeagueTests
{
    // --- Ladder --------------------------------------------------------------

    [Fact]
    public void Ladder_has_ten_tiers_in_plan_order()
    {
        LeagueLadder.Tiers.Should().HaveCount(10);
        LeagueLadder.Tiers.Select(t => t.Id).Should().ContainInOrder(
            "bronze", "silver", "gold", "sapphire", "ruby",
            "emerald", "amethyst", "pearl", "diamond", "obsidian");
        LeagueLadder.Tiers.Select(t => t.Index).Should().ContainInOrder(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    }

    [Fact]
    public void Ladder_exposes_french_display_names()
    {
        LeagueLadder.ById("sapphire").Name.Should().Be("Saphir");
        LeagueLadder.ById("emerald").Name.Should().Be("Émeraude");
        LeagueLadder.ById("obsidian").Name.Should().Be("Obsidienne");
    }

    [Theory]
    [InlineData("bronze", 1)]
    [InlineData("BRONZE", 1)]
    [InlineData("Diamond", 9)]
    public void ById_is_case_insensitive_and_keeps_bronze_back_compat(string id, int expectedIndex)
        => LeagueLadder.ById(id).Index.Should().Be(expectedIndex);

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("platinum")]
    public void ById_falls_back_to_bronze_for_unknown_or_empty(string? id)
        => LeagueLadder.ById(id).Should().Be(LeagueLadder.Lowest);

    [Fact]
    public void Promote_and_relegate_move_one_step_and_clamp_at_the_extremes()
    {
        var bronze = LeagueLadder.ById("bronze");
        var gold = LeagueLadder.ById("gold");
        var obsidian = LeagueLadder.ById("obsidian");

        LeagueLadder.Promote(gold).Id.Should().Be("sapphire");
        LeagueLadder.Relegate(gold).Id.Should().Be("silver");

        LeagueLadder.IsBottom(bronze).Should().BeTrue();
        LeagueLadder.Relegate(bronze).Should().Be(bronze, "the floor never relegates further");

        LeagueLadder.IsTop(obsidian).Should().BeTrue();
        LeagueLadder.Promote(obsidian).Should().Be(obsidian, "the apex never promotes further");
    }

    [Fact]
    public void ByIndex_clamps_out_of_range_indices()
    {
        LeagueLadder.ByIndex(0).Should().Be(LeagueLadder.Lowest);
        LeagueLadder.ByIndex(99).Should().Be(LeagueLadder.Highest);
        LeagueLadder.ByIndex(4).Id.Should().Be("sapphire");
    }

    // --- Zones ---------------------------------------------------------------

    [Fact]
    public void Zones_promote_roughly_thirty_and_relegate_roughly_twenty_percent()
    {
        var plan = LeagueZones.Plan(cohortSize: 30, isTopTier: false, isBottomTier: false);

        plan.PromoteCount.Should().Be(9);   // round(30 * 0.30)
        plan.RelegateCount.Should().Be(6);  // round(30 * 0.20)
        plan.SafeCount.Should().Be(15);
    }

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(7)]
    [InlineData(10)]
    [InlineData(30)]
    [InlineData(50)]
    public void Zones_never_overlap_and_fit_the_cohort(int size)
    {
        var plan = LeagueZones.Plan(size, isTopTier: false, isBottomTier: false);

        plan.PromoteCount.Should().BeGreaterThan(0, "any active cohort offers a promotion path");
        (plan.PromoteCount + plan.RelegateCount).Should().BeLessThanOrEqualTo(size);
        plan.SafeCount.Should().BeGreaterThanOrEqualTo(0);

        if (size >= 2)
        {
            plan.RelegateCount.Should().BeGreaterThan(0, "two or more members create a relegation band");
        }

        if (size >= 3)
        {
            plan.SafeCount.Should().BeGreaterThanOrEqualTo(1, "a cohort of 3+ keeps a neutral band");
        }
    }

    [Fact]
    public void Zones_at_top_tier_have_no_promotion()
    {
        var plan = LeagueZones.Plan(20, isTopTier: true, isBottomTier: false);

        plan.PromoteCount.Should().Be(0);
        plan.RelegateCount.Should().BeGreaterThan(0);
    }

    [Fact]
    public void Zones_at_bottom_tier_have_no_relegation()
    {
        var plan = LeagueZones.Plan(20, isTopTier: false, isBottomTier: true);

        plan.RelegateCount.Should().Be(0);
        plan.PromoteCount.Should().BeGreaterThan(0);
    }

    [Fact]
    public void Zones_for_a_lone_active_member_promote_rather_than_relegate()
    {
        var plan = LeagueZones.Plan(1, isTopTier: false, isBottomTier: false);

        plan.PromoteCount.Should().Be(1);
        plan.RelegateCount.Should().Be(0);
    }

    [Fact]
    public void Zones_for_empty_cohort_are_all_zero()
    {
        var plan = LeagueZones.Plan(0, isTopTier: false, isBottomTier: false);

        plan.Should().Be(new LeagueZonePlan(0, 0, 0));
    }

    [Fact]
    public void ZoneForRank_maps_ranks_to_bands()
    {
        var plan = new LeagueZonePlan(CohortSize: 10, PromoteCount: 3, RelegateCount: 2);

        plan.ZoneForRank(1).Should().Be(LeagueZone.Promotion);
        plan.ZoneForRank(3).Should().Be(LeagueZone.Promotion);
        plan.ZoneForRank(4).Should().Be(LeagueZone.Safe);
        plan.ZoneForRank(8).Should().Be(LeagueZone.Safe);
        plan.ZoneForRank(9).Should().Be(LeagueZone.Relegation);
        plan.ZoneForRank(10).Should().Be(LeagueZone.Relegation);
        plan.ZoneForRank(99).Should().Be(LeagueZone.Safe, "out-of-range ranks default to the neutral band");
    }

    // --- Standings -----------------------------------------------------------

    private static IReadOnlyCollection<LeagueMember> Cohort()
        => new[]
        {
            new LeagueMember("u-charlie", "Charlie", null, 120),
            new LeagueMember("u-alice", "Alice", null, 300),
            new LeagueMember("u-bob", "Bob", null, 300),
            new LeagueMember("u-dora", "Dora", null, 50)
        };

    [Fact]
    public void Standings_rank_by_xp_then_break_ties_by_user_id()
    {
        var plan = new LeagueZonePlan(4, 1, 1);

        var standings = LeagueStandings.Rank(Cohort(), plan);

        standings.Select(s => s.UserId).Should().Equal("u-alice", "u-bob", "u-charlie", "u-dora");
        standings.Select(s => s.Rank).Should().Equal(1, 2, 3, 4);
    }

    [Fact]
    public void Standings_are_deterministic_regardless_of_input_order()
    {
        var plan = new LeagueZonePlan(4, 1, 1);
        var reversed = Cohort().Reverse().ToArray();

        var a = LeagueStandings.Rank(Cohort(), plan).Select(s => s.UserId);
        var b = LeagueStandings.Rank(reversed, plan).Select(s => s.UserId);

        a.Should().Equal(b);
    }

    [Fact]
    public void Standings_assign_zones_from_the_plan()
    {
        var plan = new LeagueZonePlan(4, 1, 1);

        var standings = LeagueStandings.Rank(Cohort(), plan);

        standings.Single(s => s.Rank == 1).Zone.Should().Be(LeagueZone.Promotion);
        standings.Single(s => s.Rank == 2).Zone.Should().Be(LeagueZone.Safe);
        standings.Single(s => s.Rank == 4).Zone.Should().Be(LeagueZone.Relegation);
    }

    [Fact]
    public void Standings_overload_computes_the_plan_from_tier_and_size()
    {
        var bronze = LeagueLadder.ById("bronze");

        var standings = LeagueStandings.Rank(Cohort(), bronze);

        // Bronze is the floor → nobody is relegated.
        standings.Should().NotContain(s => s.Zone == LeagueZone.Relegation);
        standings.Should().Contain(s => s.Zone == LeagueZone.Promotion);
    }

    // --- Resolver ------------------------------------------------------------

    [Fact]
    public void Resolver_moves_members_per_zone_and_clamps_tiers()
    {
        var gold = LeagueLadder.ById("gold");
        var plan = new LeagueZonePlan(4, 1, 1);
        var standings = LeagueStandings.Rank(Cohort(), plan);

        var outcomes = LeagueResolver.ResolveWeek(standings, gold);

        var top = outcomes.Single(o => o.Rank == 1);
        top.Movement.Should().Be(LeagueMovement.Promoted);
        top.ToTier.Id.Should().Be("sapphire");

        var middle = outcomes.Single(o => o.Rank == 2);
        middle.Movement.Should().Be(LeagueMovement.Held);
        middle.ToTier.Should().Be(gold);

        var bottom = outcomes.Single(o => o.Rank == 4);
        bottom.Movement.Should().Be(LeagueMovement.Relegated);
        bottom.ToTier.Id.Should().Be("silver");
    }

    [Theory]
    [InlineData(1, 100)]
    [InlineData(2, 60)]
    [InlineData(3, 40)]
    [InlineData(4, 25)]
    public void Resolver_rewards_the_promotion_zone_by_rank(int rank, int expectedGems)
        => LeagueResolver.GemReward(rank, LeagueZone.Promotion).Should().Be(expectedGems);

    [Theory]
    [InlineData(LeagueZone.Safe)]
    [InlineData(LeagueZone.Relegation)]
    public void Resolver_gives_no_gems_outside_promotion(LeagueZone zone)
        => LeagueResolver.GemReward(1, zone).Should().Be(0);

    // --- Period --------------------------------------------------------------

    [Fact]
    public void Period_starts_on_monday_utc_and_composes_the_partition_key()
    {
        // 2026-06-24 is a Wednesday → the week starts Monday 2026-06-22.
        var instant = new DateTimeOffset(2026, 6, 24, 13, 0, 0, TimeSpan.Zero);

        var period = LeaguePeriods.ForInstant(instant);

        period.WeekStart.Should().Be(new DateOnly(2026, 6, 22));
        period.Id.Should().Be("weekly:20260622");
        period.Compose("bronze").Should().Be("weekly:20260622:bronze");
        period.StartsAt.Should().Be(new DateTimeOffset(2026, 6, 22, 0, 0, 0, TimeSpan.Zero));
        period.EndsAt.Should().Be(new DateTimeOffset(2026, 6, 29, 0, 0, 0, TimeSpan.Zero));
    }

    [Fact]
    public void Period_on_a_monday_uses_that_same_day()
    {
        var monday = new DateTimeOffset(2026, 6, 22, 0, 30, 0, TimeSpan.Zero);

        LeaguePeriods.ForInstant(monday).WeekStart.Should().Be(new DateOnly(2026, 6, 22));
    }

    [Fact]
    public void Period_reset_countdown_is_clamped_to_zero()
    {
        var period = new LeaguePeriod(new DateOnly(2026, 6, 22));

        period.ResetsIn(new DateTimeOffset(2026, 6, 25, 0, 0, 0, TimeSpan.Zero))
            .Should().Be(TimeSpan.FromDays(4));
        period.ResetsIn(new DateTimeOffset(2026, 7, 1, 0, 0, 0, TimeSpan.Zero))
            .Should().Be(TimeSpan.Zero, "a finished period never reports negative time");
    }

    [Theory]
    [InlineData("weekly:20260622:bronze", "weekly:20260622", "bronze")]
    [InlineData("weekly:20260622:obsidian", "weekly:20260622", "obsidian")]
    [InlineData("weekly:test:bronze", "weekly:test", "bronze")]
    public void Period_parse_splits_period_from_tier(string input, string expectedPeriod, string expectedTier)
    {
        var (periodId, tierId) = LeaguePeriods.Parse(input);

        periodId.Should().Be(expectedPeriod);
        tierId.Should().Be(expectedTier);
    }

    [Fact]
    public void Period_compose_round_trips_through_parse()
    {
        var period = LeaguePeriods.ForInstant(new DateTimeOffset(2026, 6, 24, 9, 0, 0, TimeSpan.Zero));

        var (periodId, tierId) = LeaguePeriods.Parse(period.Compose("gold"));

        periodId.Should().Be(period.Id);
        tierId.Should().Be("gold");
    }
}
