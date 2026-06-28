using FluentAssertions;
using Certigo.Domain.Notifications;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class NotificationCatalogTests
{
    [Theory]
    [InlineData(NotificationKind.StreakDanger, NotificationPriority.Critical)]
    [InlineData(NotificationKind.Comeback, NotificationPriority.High)]
    [InlineData(NotificationKind.DailyReminder, NotificationPriority.Normal)]
    [InlineData(NotificationKind.QuestNudge, NotificationPriority.Normal)]
    [InlineData(NotificationKind.LeagueNudge, NotificationPriority.Normal)]
    [InlineData(NotificationKind.Milestone, NotificationPriority.Low)]
    public void PriorityOf_maps_each_kind(NotificationKind kind, NotificationPriority expected)
    {
        NotificationCatalog.PriorityOf(kind).Should().Be(expected);
    }

    [Theory]
    [InlineData(0, 7)]
    [InlineData(6, 7)]
    [InlineData(7, 30)]
    [InlineData(29, 30)]
    [InlineData(30, 100)]
    [InlineData(100, 365)]
    public void NextMilestone_returns_next_target(int streak, int expected)
    {
        NotificationCatalog.NextMilestone(streak).Should().Be(expected);
    }

    [Theory]
    [InlineData(365)]
    [InlineData(400)]
    public void NextMilestone_returns_null_past_last(int streak)
    {
        NotificationCatalog.NextMilestone(streak).Should().BeNull();
    }

    [Fact]
    public void StreakDanger_with_freeze_reassures_and_uses_sentinel()
    {
        var content = NotificationCatalog.StreakDanger(12, hasFreeze: true);

        content.Mascot.Should().Be(NotificationMascot.Sentinel);
        content.Title.Should().Contain("protégée");
        content.Body.Should().Contain("12");
        content.Deeplink.Should().Be("certigo://lesson/next");
    }

    [Theory]
    [InlineData(3)]
    [InlineData(12)]
    [InlineData(60)]
    public void StreakDanger_escalates_by_length_with_sentinel(int streak)
    {
        var content = NotificationCatalog.StreakDanger(streak, hasFreeze: false);

        content.Mascot.Should().Be(NotificationMascot.Sentinel);
        content.Body.Should().Contain(streak.ToString());
        content.Deeplink.Should().Be("certigo://lesson/next");
    }

    [Fact]
    public void StreakDanger_titles_differ_across_tiers()
    {
        var small = NotificationCatalog.StreakDanger(3, false).Title;
        var medium = NotificationCatalog.StreakDanger(12, false).Title;
        var large = NotificationCatalog.StreakDanger(60, false).Title;

        new[] { small, medium, large }.Should().OnlyHaveUniqueItems();
    }

    [Theory]
    [InlineData(2)]
    [InlineData(5)]
    [InlineData(10)]
    [InlineData(20)]
    [InlineData(40)]
    public void Comeback_is_warm_and_includes_days_with_pip(int daysAway)
    {
        var content = NotificationCatalog.Comeback(daysAway);

        content.Mascot.Should().Be(NotificationMascot.Pip);
        content.Body.Should().Contain(daysAway.ToString());
        content.Deeplink.Should().Be("certigo://lesson/next");
    }

    [Fact]
    public void Comeback_titles_differ_across_buckets()
    {
        var titles = new[] { 2, 5, 10, 20, 40 }
            .Select(d => NotificationCatalog.Comeback(d).Title)
            .ToArray();

        titles.Should().OnlyHaveUniqueItems();
    }

    [Fact]
    public void DailyReminderFresh_differs_for_zero_and_active_streak()
    {
        var fresh = NotificationCatalog.DailyReminderFresh(0);
        var ongoing = NotificationCatalog.DailyReminderFresh(5);

        fresh.Mascot.Should().Be(NotificationMascot.Nimbus);
        ongoing.Mascot.Should().Be(NotificationMascot.Nimbus);
        fresh.Body.Should().NotBe(ongoing.Body);
        ongoing.Body.Should().Contain("5");
    }

    [Fact]
    public void DailyReminderFinishGoal_uses_nimbus_and_lesson_deeplink()
    {
        var content = NotificationCatalog.DailyReminderFinishGoal();

        content.Mascot.Should().Be(NotificationMascot.Nimbus);
        content.Body.Should().Contain("objectif");
        content.Deeplink.Should().Be("certigo://lesson/next");
    }

    [Fact]
    public void Quest_contents_use_pixel_and_quests_deeplink()
    {
        var claim = NotificationCatalog.QuestClaim(2);
        var pending = NotificationCatalog.QuestPending(3);

        claim.Mascot.Should().Be(NotificationMascot.Pixel);
        claim.Body.Should().Contain("2");
        claim.Deeplink.Should().Be("certigo://quests");
        pending.Mascot.Should().Be(NotificationMascot.Pixel);
        pending.Body.Should().Contain("3");
        pending.Deeplink.Should().Be("certigo://quests");
    }

    [Fact]
    public void League_contents_use_cosmo_and_league_deeplink()
    {
        var promotion = NotificationCatalog.LeaguePromotion();
        var relegation = NotificationCatalog.LeagueRelegation();

        promotion.Mascot.Should().Be(NotificationMascot.Cosmo);
        promotion.Deeplink.Should().Be("certigo://league");
        relegation.Mascot.Should().Be(NotificationMascot.Cosmo);
        relegation.Deeplink.Should().Be("certigo://league");
        promotion.Title.Should().NotBe(relegation.Title);
    }

    [Fact]
    public void MilestoneApproaching_mentions_target_and_days()
    {
        var content = NotificationCatalog.MilestoneApproaching(7, 2);

        content.Mascot.Should().Be(NotificationMascot.Nimbus);
        content.Body.Should().Contain("7");
        content.Body.Should().Contain("2");
        content.Deeplink.Should().Be("certigo://home");
    }
}
