using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

namespace Microlingo.Domain.Notifications;

/// <summary>
/// Planificateur pur et déterministe des notifications intelligentes. À partir d'une
/// photographie d'engagement (<see cref="NotificationSignals"/>), des préférences de
/// l'apprenant et de l'instant courant, il décide <em>quoi</em> envoyer, <em>quand</em>
/// (heure locale, hors heures silencieuses), avec quelle mascotte et quelle priorité,
/// puis trie et plafonne le tout. Le serveur reste seul juge ; le transport (Azure
/// Notification Hubs, FCM/APNs) ne fait qu'exécuter le plan.
/// </summary>
public static class NotificationScheduler
{
    /// <summary>Heure plancher (locale) pour pousser une alerte de série vers le soir.</summary>
    private const int EveningFloor = 20;

    /// <summary>
    /// Construit le plan de notifications pour la journée locale de <paramref name="nowUtc"/>.
    /// </summary>
    /// <param name="signals">État d'engagement déterministe de l'apprenant.</param>
    /// <param name="preferences">Préférences (normalisées en interne).</param>
    /// <param name="nowUtc">Instant courant, en UTC.</param>
    /// <param name="learnedHour">Heure apprise prioritaire sur l'heure préférée, si fournie.</param>
    public static NotificationPlan Plan(
        NotificationSignals signals,
        NotificationPreferences preferences,
        DateTimeOffset nowUtc,
        int? learnedHour = null)
    {
        var prefs = preferences.Normalized();
        var offset = TimeSpan.FromMinutes(prefs.UtcOffsetMinutes);
        var nowLocal = nowUtc.ToOffset(offset);
        var localDate = DateOnly.FromDateTime(nowLocal.DateTime);

        if (!prefs.Enabled || prefs.MaxPerDay <= 0)
        {
            return NotificationPlan.Empty(localDate);
        }

        var preferredHour = BestHourEstimator.Wrap(learnedHour ?? prefs.PreferredHour);
        int? daysAway = signals.LastActiveDate is { } lastActive
            ? localDate.DayNumber - lastActive.DayNumber
            : null;

        var candidates = new List<Candidate>(6);

        var streakAtRisk = prefs.StreakAlerts
            && signals.StreakDays > 0
            && !signals.PracticedToday
            && daysAway == 1;

        if (streakAtRisk)
        {
            candidates.Add(new Candidate(
                NotificationKind.StreakDanger,
                NotificationCatalog.StreakDanger(signals.StreakDays, signals.HasFreeze),
                Math.Max(preferredHour, EveningFloor),
                PreferEvening: true));
        }
        else if (daysAway is >= 2)
        {
            candidates.Add(new Candidate(
                NotificationKind.Comeback,
                NotificationCatalog.Comeback(daysAway.Value),
                preferredHour,
                PreferEvening: false));
        }

        if (!signals.PracticedToday && !streakAtRisk && daysAway is not >= 2)
        {
            candidates.Add(new Candidate(
                NotificationKind.DailyReminder,
                NotificationCatalog.DailyReminderFresh(signals.StreakDays),
                preferredHour,
                PreferEvening: false));
        }
        else if (signals.PracticedToday && !signals.DailyGoalMet)
        {
            candidates.Add(new Candidate(
                NotificationKind.DailyReminder,
                NotificationCatalog.DailyReminderFinishGoal(),
                preferredHour,
                PreferEvening: false));
        }

        if (prefs.QuestAlerts)
        {
            if (signals.ClaimableQuests > 0)
            {
                candidates.Add(new Candidate(
                    NotificationKind.QuestNudge,
                    NotificationCatalog.QuestClaim(signals.ClaimableQuests),
                    preferredHour,
                    PreferEvening: false));
            }
            else if (signals.PendingQuests > 0 && !signals.PracticedToday)
            {
                candidates.Add(new Candidate(
                    NotificationKind.QuestNudge,
                    NotificationCatalog.QuestPending(signals.PendingQuests),
                    preferredHour,
                    PreferEvening: false));
            }
        }

        if (prefs.LeagueAlerts)
        {
            if (signals.League == LeagueSignal.Promotion)
            {
                candidates.Add(new Candidate(
                    NotificationKind.LeagueNudge,
                    NotificationCatalog.LeaguePromotion(),
                    preferredHour,
                    PreferEvening: false));
            }
            else if (signals.League == LeagueSignal.Relegation)
            {
                candidates.Add(new Candidate(
                    NotificationKind.LeagueNudge,
                    NotificationCatalog.LeagueRelegation(),
                    preferredHour,
                    PreferEvening: false));
            }
        }

        var nextMilestone = NotificationCatalog.NextMilestone(signals.StreakDays);
        if (nextMilestone is { } target)
        {
            var gap = target - signals.StreakDays;
            if (gap >= 1 && gap <= NotificationCatalog.MilestoneWindowDays)
            {
                candidates.Add(new Candidate(
                    NotificationKind.Milestone,
                    NotificationCatalog.MilestoneApproaching(target, gap),
                    preferredHour,
                    PreferEvening: false));
            }
        }

        if (candidates.Count == 0)
        {
            return NotificationPlan.Empty(localDate);
        }

        var scheduled = candidates
            .Select(candidate =>
            {
                var hour = ShiftOutOfQuiet(
                    BestHourEstimator.Wrap(candidate.BaseHour),
                    prefs,
                    candidate.PreferEvening);

                var localStart = new DateTimeOffset(
                    localDate.Year, localDate.Month, localDate.Day, hour, 0, 0, offset);

                return new ScheduledNotification(
                    candidate.Kind,
                    NotificationCatalog.PriorityOf(candidate.Kind),
                    localStart.ToUniversalTime(),
                    hour,
                    candidate.Content,
                    DedupeKey(candidate.Kind, localDate));
            })
            .OrderByDescending(notification => (int)notification.Priority)
            .ThenBy(notification => KindOrder(notification.Kind))
            .Take(prefs.MaxPerDay)
            .ToList();

        return new NotificationPlan(localDate, scheduled);
    }

    /// <summary>
    /// Indique si <paramref name="hour"/> tombe dans la fenêtre silencieuse
    /// [<paramref name="start"/>, <paramref name="end"/>). Fenêtre nulle si start == end.
    /// </summary>
    public static bool IsQuiet(int hour, int start, int end)
    {
        if (start == end)
        {
            return false;
        }

        return start < end
            ? hour >= start && hour < end
            : hour >= start || hour < end;
    }

    private static int ShiftOutOfQuiet(int hour, NotificationPreferences prefs, bool preferEvening)
    {
        if (!IsQuiet(hour, prefs.QuietHoursStart, prefs.QuietHoursEnd))
        {
            return hour;
        }

        return preferEvening
            ? BestHourEstimator.Wrap(prefs.QuietHoursStart - 1)
            : BestHourEstimator.Wrap(prefs.QuietHoursEnd);
    }

    private static string DedupeKey(NotificationKind kind, DateOnly localDate) =>
        string.Create(
            CultureInfo.InvariantCulture,
            $"{kind}:{localDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)}");

    private static int KindOrder(NotificationKind kind) => kind switch
    {
        NotificationKind.StreakDanger => 0,
        NotificationKind.Comeback => 1,
        NotificationKind.LeagueNudge => 2,
        NotificationKind.QuestNudge => 3,
        NotificationKind.DailyReminder => 4,
        NotificationKind.Milestone => 5,
        _ => 6
    };

    private readonly record struct Candidate(
        NotificationKind Kind,
        NotificationContent Content,
        int BaseHour,
        bool PreferEvening);
}
