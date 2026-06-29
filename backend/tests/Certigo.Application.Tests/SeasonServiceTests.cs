using FluentAssertions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class SeasonServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryEventRepository Events { get; } = new();

    // 6 January 2025 → active season "2025-01" (Renouveau Cloud, EarnXp 1200).
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";
    public string CurrentSeasonId { get; } = "2025-01";

    public DateOnly Today => DateOnly.FromDateTime(Clock.UtcNow.UtcDateTime);

    public SeasonService Build()
        => new(new FakeUserContext(UserId, "Tester"), Clock, Users, Events);

    public void SeedNoActivity(int gems = 0)
    {
        var profile = TestContent.NewProfile(UserId) with { Gems = gems };
        Users.Seed(profile);
    }

    public void SeedSeasonCompleted(int gems = 0)
    {
        var profile = TestContent.NewProfile(UserId) with
        {
            Gems = gems,
            MonthlyAnchor = new DateOnly(2025, 1, 1),
            MonthlyXpEarned = 5000,
            MonthlyLessonsCompleted = 50,
            MonthlyPerfectLessons = 30,
        };
        Users.Seed(profile);
    }
}

public sealed class SeasonServiceTests
{
    [Fact]
    public async Task GetCurrentAsync_returns_active_season_metadata_and_balance()
    {
        var h = new SeasonServiceHarness();
        h.SeedNoActivity(gems: 40);
        var service = h.Build();

        var season = await service.GetCurrentAsync();

        season.Id.Should().Be(h.CurrentSeasonId);
        season.Theme.Should().Be("Renouveau Cloud");
        season.BadgeId.Should().Be("season-renouveau-cloud");
        season.Gems.Should().Be(40);
        season.Challenge.Target.Should().Be(1200);
        season.Challenge.Current.Should().Be(0);
        season.Challenge.Completed.Should().BeFalse();
        season.Challenge.Claimable.Should().BeFalse();
        season.Challenge.Claimed.Should().BeFalse();
    }

    [Fact]
    public async Task GetCurrentAsync_marks_challenge_claimable_when_monthly_signals_meet_target()
    {
        var h = new SeasonServiceHarness();
        h.SeedSeasonCompleted(gems: 10);
        var service = h.Build();

        var season = await service.GetCurrentAsync();

        season.Challenge.Current.Should().Be(1200); // capped at target
        season.Challenge.Completed.Should().BeTrue();
        season.Challenge.Claimable.Should().BeTrue();
        season.Challenge.Claimed.Should().BeFalse();
    }

    [Fact]
    public async Task ClaimAsync_awards_gems_grants_badge_and_emits_event()
    {
        var h = new SeasonServiceHarness();
        h.SeedSeasonCompleted(gems: 100);
        var service = h.Build();

        var result = await service.ClaimAsync(new ClaimSeasonRequest(h.CurrentSeasonId));

        result.Success.Should().BeTrue();
        result.SeasonId.Should().Be(h.CurrentSeasonId);
        result.BadgeId.Should().Be("season-renouveau-cloud");
        result.GemsAwarded.Should().Be(120);
        result.GemsBalance.Should().Be(220);
        result.Claimed.Should().BeTrue();

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(220);
        profile.SeasonBadges.Should().Contain("season-renouveau-cloud");
        h.Events.Events.Should().ContainSingle(e => e.Type == "season.claimed");
    }

    [Fact]
    public async Task ClaimAsync_is_idempotent()
    {
        var h = new SeasonServiceHarness();
        h.SeedSeasonCompleted(gems: 0);
        var service = h.Build();

        var first = await service.ClaimAsync(new ClaimSeasonRequest(h.CurrentSeasonId));
        var second = await service.ClaimAsync(new ClaimSeasonRequest(h.CurrentSeasonId));

        first.GemsAwarded.Should().Be(120);
        second.Success.Should().BeTrue();
        second.GemsAwarded.Should().Be(0);
        second.Claimed.Should().BeTrue();

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(120); // awarded exactly once
        h.Events.Events.Should().ContainSingle(e => e.Type == "season.claimed");
    }

    [Fact]
    public async Task ClaimAsync_rejects_incomplete_challenge_without_side_effects()
    {
        var h = new SeasonServiceHarness();
        h.SeedNoActivity(gems: 10);
        var service = h.Build();

        var result = await service.ClaimAsync(new ClaimSeasonRequest(h.CurrentSeasonId));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("notCompleted");
        result.GemsBalance.Should().Be(10);

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(10);
        (profile.SeasonBadges ?? new List<string>()).Should().BeEmpty();
        h.Events.Events.Should().BeEmpty();
    }

    [Fact]
    public async Task ClaimAsync_rejects_a_season_that_is_not_the_active_one()
    {
        var h = new SeasonServiceHarness();
        h.SeedSeasonCompleted(gems: 50);
        var service = h.Build();

        var result = await service.ClaimAsync(new ClaimSeasonRequest("1999-01"));

        result.Success.Should().BeFalse();
        result.Error.Should().Be("wrongSeason");
        result.SeasonId.Should().Be("1999-01");
        result.GemsBalance.Should().Be(50);

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Gems.Should().Be(50);
        h.Events.Events.Should().BeEmpty();
    }

    [Fact]
    public async Task Monthly_signals_from_a_previous_month_do_not_count_toward_the_current_season()
    {
        var h = new SeasonServiceHarness();
        // Large counters, but anchored to December 2024 — stale for the January season.
        var profile = TestContent.NewProfile(h.UserId) with
        {
            Gems = 0,
            MonthlyAnchor = new DateOnly(2024, 12, 1),
            MonthlyXpEarned = 9000,
            MonthlyLessonsCompleted = 90,
            MonthlyPerfectLessons = 90,
        };
        h.Users.Seed(profile);
        var service = h.Build();

        var season = await service.GetCurrentAsync();
        season.Challenge.Current.Should().Be(0);
        season.Challenge.Claimable.Should().BeFalse();

        var result = await service.ClaimAsync(new ClaimSeasonRequest(h.CurrentSeasonId));
        result.Success.Should().BeFalse();
        result.Error.Should().Be("notCompleted");
    }
}
