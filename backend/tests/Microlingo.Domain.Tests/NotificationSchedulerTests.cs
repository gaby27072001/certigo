using FluentAssertions;
using Microlingo.Domain.Notifications;
using Xunit;

namespace Microlingo.Domain.Tests;

public sealed class NotificationSchedulerTests
{
    private static readonly DateOnly Today = new(2025, 1, 6);
    private static readonly DateOnly Yesterday = new(2025, 1, 5);
    private static readonly DateTimeOffset NowUtc = new(2025, 1, 6, 12, 0, 0, TimeSpan.Zero);

    private static NotificationPreferences Prefs => NotificationPreferences.Default;

    [Fact]
    public void Plan_returns_empty_when_disabled()
    {
        var signals = NotificationSignals.Inactive with { StreakDays = 5, LastActiveDate = Yesterday };

        var plan = NotificationScheduler.Plan(signals, Prefs with { Enabled = false }, NowUtc);

        plan.Notifications.Should().BeEmpty();
        plan.LocalDate.Should().Be(Today);
    }

    [Fact]
    public void Plan_returns_empty_when_max_per_day_is_zero()
    {
        var signals = NotificationSignals.Inactive with { StreakDays = 5, LastActiveDate = Yesterday };

        var plan = NotificationScheduler.Plan(signals, Prefs with { MaxPerDay = 0 }, NowUtc);

        plan.Notifications.Should().BeEmpty();
    }

    [Fact]
    public void Plan_emits_critical_streak_danger_in_the_evening()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 10,
            LastActiveDate = Yesterday,
            PracticedToday = false
        };

        var plan = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        plan.Notifications.Should().ContainSingle();
        var notification = plan.Notifications[0];
        notification.Kind.Should().Be(NotificationKind.StreakDanger);
        notification.Priority.Should().Be(NotificationPriority.Critical);
        notification.LocalHour.Should().Be(20);
        notification.Content.Mascot.Should().Be(NotificationMascot.Sentinel);
        notification.DedupeKey.Should().Be("StreakDanger:2025-01-06");
    }

    [Fact]
    public void Plan_emits_comeback_when_away_two_or_more_days()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 4,
            LastActiveDate = new DateOnly(2025, 1, 1)
        };

        var plan = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].Kind.Should().Be(NotificationKind.Comeback);
        plan.Notifications[0].Priority.Should().Be(NotificationPriority.High);
        plan.Notifications[0].Content.Mascot.Should().Be(NotificationMascot.Pip);
    }

    [Fact]
    public void Plan_falls_back_to_daily_reminder_when_streak_alerts_disabled()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 10,
            LastActiveDate = Yesterday,
            PracticedToday = false
        };

        var plan = NotificationScheduler.Plan(signals, Prefs with { StreakAlerts = false }, NowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].Kind.Should().Be(NotificationKind.DailyReminder);
        plan.Notifications[0].Content.Mascot.Should().Be(NotificationMascot.Nimbus);
        plan.Notifications[0].Content.Body.Should().Contain("10");
    }

    [Fact]
    public void Plan_emits_finish_goal_reminder_when_practiced_but_goal_unmet()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 3,
            LastActiveDate = Today,
            PracticedToday = true,
            DailyGoalMet = false
        };

        var plan = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].Kind.Should().Be(NotificationKind.DailyReminder);
        plan.Notifications[0].Content.Body.Should().Contain("objectif");
    }

    [Fact]
    public void Plan_shifts_non_evening_notification_out_of_quiet_hours_to_end()
    {
        var signals = NotificationSignals.Inactive with { PracticedToday = false };

        var plan = NotificationScheduler.Plan(signals, Prefs with { PreferredHour = 2 }, NowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].Kind.Should().Be(NotificationKind.DailyReminder);
        plan.Notifications[0].LocalHour.Should().Be(7);
    }

    [Fact]
    public void Plan_shifts_evening_streak_danger_to_just_before_quiet_start()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 10,
            LastActiveDate = Yesterday,
            PracticedToday = false
        };

        var plan = NotificationScheduler.Plan(signals, Prefs with { PreferredHour = 23 }, NowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].LocalHour.Should().Be(21);
    }

    [Fact]
    public void Plan_caps_to_max_per_day_keeping_highest_priority_and_order()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 6,
            LastActiveDate = null,
            PracticedToday = false,
            ClaimableQuests = 2,
            League = LeagueSignal.Promotion
        };

        var plan = NotificationScheduler.Plan(signals, Prefs with { MaxPerDay = 2 }, NowUtc);

        plan.Notifications.Should().HaveCount(2);
        plan.Notifications.Select(n => n.Kind).Should()
            .Equal(NotificationKind.LeagueNudge, NotificationKind.QuestNudge);
    }

    [Fact]
    public void Plan_orders_streak_danger_before_lower_priority_candidates()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 10,
            LastActiveDate = Yesterday,
            PracticedToday = false,
            ClaimableQuests = 2,
            League = LeagueSignal.Promotion
        };

        var plan = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        plan.Notifications.Select(n => n.Kind).Should().Equal(
            NotificationKind.StreakDanger,
            NotificationKind.LeagueNudge,
            NotificationKind.QuestNudge);
    }

    [Fact]
    public void Plan_converts_local_hour_to_utc_using_offset()
    {
        var signals = NotificationSignals.Inactive with { PracticedToday = false };
        var nowUtc = new DateTimeOffset(2025, 1, 6, 10, 0, 0, TimeSpan.Zero);

        var plan = NotificationScheduler.Plan(signals, Prefs with { UtcOffsetMinutes = 120 }, nowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].LocalHour.Should().Be(19);
        plan.Notifications[0].ScheduledUtc.Should()
            .Be(new DateTimeOffset(2025, 1, 6, 17, 0, 0, TimeSpan.Zero));
    }

    [Fact]
    public void Plan_is_deterministic_for_identical_inputs()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 10,
            LastActiveDate = Yesterday,
            PracticedToday = false,
            ClaimableQuests = 2,
            League = LeagueSignal.Promotion
        };

        var first = NotificationScheduler.Plan(signals, Prefs, NowUtc);
        var second = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        first.Notifications.Should().Equal(second.Notifications);
    }

    [Fact]
    public void Plan_is_empty_when_learner_is_fully_satisfied()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 50,
            LastActiveDate = Today,
            PracticedToday = true,
            DailyGoalMet = true,
            League = LeagueSignal.Safe
        };

        var plan = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        plan.Notifications.Should().BeEmpty();
    }

    [Fact]
    public void Plan_emits_milestone_when_within_window()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 6,
            LastActiveDate = Today,
            PracticedToday = true,
            DailyGoalMet = true
        };

        var plan = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].Kind.Should().Be(NotificationKind.Milestone);
        plan.Notifications[0].Priority.Should().Be(NotificationPriority.Low);
        plan.Notifications[0].Content.Body.Should().Contain("7");
    }

    [Fact]
    public void Plan_emits_league_relegation_alert()
    {
        var signals = NotificationSignals.Inactive with
        {
            StreakDays = 50,
            LastActiveDate = Today,
            PracticedToday = true,
            DailyGoalMet = true,
            League = LeagueSignal.Relegation
        };

        var plan = NotificationScheduler.Plan(signals, Prefs, NowUtc);

        plan.Notifications.Should().ContainSingle();
        plan.Notifications[0].Kind.Should().Be(NotificationKind.LeagueNudge);
        plan.Notifications[0].Content.Mascot.Should().Be(NotificationMascot.Cosmo);
        plan.Notifications[0].Content.Title.Should().Contain("relégation");
    }

    [Theory]
    [InlineData(5, 9, 9, false)]
    [InlineData(10, 9, 17, true)]
    [InlineData(8, 9, 17, false)]
    [InlineData(17, 9, 17, false)]
    [InlineData(23, 22, 7, true)]
    [InlineData(3, 22, 7, true)]
    [InlineData(7, 22, 7, false)]
    [InlineData(12, 22, 7, false)]
    [InlineData(22, 22, 7, true)]
    public void IsQuiet_handles_intraday_and_wrap_windows(int hour, int start, int end, bool expected)
    {
        NotificationScheduler.IsQuiet(hour, start, end).Should().Be(expected);
    }
}
