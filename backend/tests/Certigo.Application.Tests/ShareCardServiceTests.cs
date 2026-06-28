using FluentAssertions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Progress;
using Certigo.Domain.Social;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class ShareCardServiceTests
{
    private const string UserId = "user-1";
    private static readonly DateTimeOffset Now = new(2025, 1, 6, 12, 0, 0, TimeSpan.Zero);
    private static readonly DateOnly Today = DateOnly.FromDateTime(Now.UtcDateTime);

    private static ShareCardService Build(UserProfileDto profile, InMemoryProgressRepository? progress = null)
    {
        var users = new InMemoryUserRepository();
        users.Seed(profile);
        var content = TestContent.Build();
        progress ??= new InMemoryProgressRepository();
        var context = new FakeUserContext(UserId, "Tester");
        var clock = new FakeClock(Now);
        var path = new PathService(context, content, progress, clock);
        return new ShareCardService(context, clock, users, path);
    }

    [Fact]
    public async Task GetDailyAsync_when_goal_met_celebrates_with_nimbus()
    {
        var profile = TestContent.NewProfile(UserId) with
        {
            StreakDays = 10,
            Level = 3,
            DailyXpEarned = 60,
            DailyXpDate = Today,
            DailyGoalXp = 50
        };

        var card = await Build(profile).GetDailyAsync();

        card.DailyXp.Should().Be(60);
        card.GoalMet.Should().BeTrue();
        card.Mascot.Should().Be("Nimbus");
        card.StreakDays.Should().Be(10);
        card.Level.Should().Be(3);
        card.Headline.Should().Contain("10");
        card.TrackCode.Should().Be("AZ-900");
        card.ReferralCode.Should().Be(ShareCodec.ReferralCode(UserId));
        card.ShareId.Should().Be(ShareCodec.DailyShareId(UserId, Today));
        card.Caption.Should().Contain(card.ReferralCode);
        card.Caption.Should().Contain("AZ-900");
        card.GeneratedAt.Should().Be(Now);
    }

    [Fact]
    public async Task GetDailyAsync_with_no_activity_nudges_with_pip()
    {
        var card = await Build(TestContent.NewProfile(UserId)).GetDailyAsync();

        card.DailyXp.Should().Be(0);
        card.GoalMet.Should().BeFalse();
        card.Mascot.Should().Be("Pip");
        card.StreakDays.Should().Be(0);
        card.Headline.Should().Be("Ma préparation a commencé");
    }

    [Fact]
    public async Task GetDailyAsync_ignores_stale_daily_xp_from_a_previous_day()
    {
        var profile = TestContent.NewProfile(UserId) with
        {
            StreakDays = 5,
            DailyXpEarned = 80,
            DailyXpDate = Today.AddDays(-1),
            DailyGoalXp = 50
        };

        var card = await Build(profile).GetDailyAsync();

        card.DailyXp.Should().Be(0);
        card.GoalMet.Should().BeFalse();
        card.Mascot.Should().Be("Pip");
        card.Headline.Should().Contain("5");
    }

    [Fact]
    public async Task GetDailyAsync_reflects_server_computed_readiness()
    {
        var progress = new InMemoryProgressRepository();
        progress.Seed(UserId, Mastered("c1"));
        progress.Seed(UserId, Mastered("c2"));
        var profile = TestContent.NewProfile(UserId) with { StreakDays = 3 };

        var card = await Build(profile, progress).GetDailyAsync();

        card.ReadinessScore.Should().BeGreaterThan(0);
        card.Caption.Should().Contain(card.ReadinessScore.ToString());
    }

    private static ConceptMastery Mastered(string conceptId)
        => ConceptMastery.New(UserId, TestContent.TrackId, conceptId) with
        {
            MasteryScore = 0.9,
            Stability = 60,
            LastReviewedAt = Now,
            DueAt = Now.AddDays(30)
        };
}
