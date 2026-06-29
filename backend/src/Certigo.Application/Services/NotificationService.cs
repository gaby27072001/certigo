using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;
using Certigo.Domain.Exam;
using Certigo.Domain.Gamification;
using Certigo.Domain.Integrity;
using Certigo.Domain.Notifications;
using Certigo.Domain.Progress;
using Certigo.Domain.Readiness;
using Certigo.Domain.Recommendation;
using Certigo.Domain.Social;
using Certigo.Domain.Tutor;

namespace Certigo.Application.Services;

public interface INotificationService
{
    /// <summary>Calcule le plan de notifications du jour (déjà trié et plafonné) pour l'utilisateur courant.</summary>
    Task<NotificationPlanDto> GetPlanAsync(CancellationToken cancellationToken = default);

    /// <summary>Renvoie les préférences de notification persistées (ou les valeurs par défaut).</summary>
    Task<NotificationSettingsDto> GetSettingsAsync(CancellationToken cancellationToken = default);

    /// <summary>Remplace les préférences de notification, en bornant systématiquement les valeurs.</summary>
    Task<NotificationSettingsDto> UpdateSettingsAsync(
        UpdateNotificationSettingsRequest request,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Service de planification des notifications intelligentes. Il agrège l'état du
/// profil (série, objectif, quêtes, ligue) en signaux, apprend l'heure d'activité
/// préférée de l'apprenant de façon idempotente (un renforcement par jour), puis
/// délègue la décision au moteur de domaine pur <see cref="NotificationScheduler"/>.
/// Aucun transport (push) ici : on ne fait que décider quoi/quand/à qui envoyer.
/// </summary>
public sealed class NotificationService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    ILeaderboardService leaderboard,
    IEventRepository events) : INotificationService
{
    public async Task<NotificationPlanDto> GetPlanAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var now = clock.UtcNow;
        var today = DateOnly.FromDateTime(now.UtcDateTime);

        var state = profile.NotificationState ?? new NotificationStateDto(NotificationSettingsDto.Default);
        var settings = state.Settings;

        var practicedToday = profile.DailyXpDate == today && profile.DailyXpEarned > 0;
        var dailyGoalMet = practicedToday && profile.DailyXpEarned >= profile.DailyGoalXp;

        // Boucle d'apprentissage : quand l'apprenant a pratiqué aujourd'hui et que
        // l'heure n'a pas encore été renforcée pour ce jour, on incrémente
        // l'histogramme horaire (heure locale) puis on persiste. Le garde
        // LastActivityHourDate garantit un seul renforcement par jour, donc un
        // GetPlan rejoué n'introduit aucun biais.
        IReadOnlyList<int>? histogram = state.ActivityHours;
        if (practicedToday && state.LastActivityHourDate != today)
        {
            var offset = TimeSpan.FromMinutes(settings.UtcOffsetMinutes);
            var localHour = now.ToOffset(offset).Hour;
            var reinforced = BestHourEstimator.Reinforce(state.ActivityHours, localHour);

            state = state with { ActivityHours = reinforced.ToList(), LastActivityHourDate = today };
            profile = profile with { NotificationState = state };
            await users.UpsertAsync(profile, cancellationToken);

            await events.AddAsync(new LearningEvent(
                Guid.NewGuid().ToString("n"),
                userContext.UserId,
                "notification.activityObserved",
                now,
                new { hour = localHour }), cancellationToken);

            histogram = reinforced;
        }

        var learnedHour = BestHourEstimator.Estimate(histogram, settings.PreferredHour);

        var (claimable, pending) = QuestProgress(profile, today);
        var league = await ResolveLeagueAsync(cancellationToken);

        var signals = NotificationSignals.Inactive with
        {
            StreakDays = profile.StreakDays,
            LastActiveDate = profile.LastActiveDate,
            HasFreeze = profile.FreezeTokens > 0,
            PracticedToday = practicedToday,
            DailyGoalMet = dailyGoalMet,
            ClaimableQuests = claimable,
            PendingQuests = pending,
            League = league,
        };

        var plan = NotificationScheduler.Plan(signals, ToPreferences(settings), now, learnedHour);

        var items = new ScheduledNotificationDto[plan.Notifications.Count];
        for (var i = 0; i < plan.Notifications.Count; i++)
        {
            items[i] = ToDto(plan.Notifications[i]);
        }

        return new NotificationPlanDto(plan.LocalDate, items);
    }

    public async Task<NotificationSettingsDto> GetSettingsAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        return profile.NotificationState?.Settings ?? NotificationSettingsDto.Default;
    }

    public async Task<NotificationSettingsDto> UpdateSettingsAsync(
        UpdateNotificationSettingsRequest request,
        CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        // On normalise via le moteur de domaine pour borner les heures et le
        // plafond quotidien avant toute persistance.
        var normalized = new NotificationPreferences(
            request.Enabled,
            request.UtcOffsetMinutes,
            request.QuietHoursStart,
            request.QuietHoursEnd,
            request.PreferredHour,
            request.MaxPerDay,
            request.StreakAlerts,
            request.QuestAlerts,
            request.LeagueAlerts).Normalized();

        var settings = ToSettingsDto(normalized);

        // L'histogramme appris et son garde de date sont préservés : changer une
        // préférence ne doit pas effacer l'apprentissage de l'heure d'activité.
        var existing = profile.NotificationState;
        var state = new NotificationStateDto(settings, existing?.ActivityHours, existing?.LastActivityHourDate);

        var updated = profile with { NotificationState = state };
        await users.UpsertAsync(updated, cancellationToken);

        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "notification.settingsUpdated",
            clock.UtcNow,
            settings), cancellationToken);

        return settings;
    }

    private async Task<LeagueSignal> ResolveLeagueAsync(CancellationToken cancellationToken)
    {
        var league = await leaderboard.GetMyLeagueAsync(cancellationToken).ConfigureAwait(false);
        if (league.Entries.Count == 0 || league.MyRank <= 0)
        {
            return LeagueSignal.None;
        }

        return league.MyZone switch
        {
            "promotion" => LeagueSignal.Promotion,
            "relegation" => LeagueSignal.Relegation,
            _ => LeagueSignal.Safe,
        };
    }

    // Reproduit la règle de réinitialisation quotidienne des compteurs (cf.
    // QuestService.DailyState) pour dénombrer les quêtes réclamables et en cours.
    private static (int Claimable, int Pending) QuestProgress(UserProfileDto profile, DateOnly today)
    {
        DailySignals signals;
        IReadOnlyList<string> claims;
        if (profile.DailyXpDate != today)
        {
            signals = DailySignals.Empty;
            claims = Array.Empty<string>();
        }
        else
        {
            signals = new DailySignals(
                profile.DailyXpEarned,
                profile.DailyLessonsCompleted,
                profile.DailyCorrectAnswers,
                profile.DailyPerfectLessons);
            claims = profile.DailyQuestClaims ?? new List<string>();
        }

        var claimable = 0;
        var pending = 0;
        foreach (var template in QuestEngine.DailyQuests(today, profile.Id))
        {
            var status = QuestEngine.Evaluate(template, signals);
            if (status.Completed)
            {
                if (!claims.Contains(template.Id))
                {
                    claimable++;
                }
            }
            else
            {
                pending++;
            }
        }

        return (claimable, pending);
    }

    private static NotificationPreferences ToPreferences(NotificationSettingsDto s)
        => new(
            s.Enabled,
            s.UtcOffsetMinutes,
            s.QuietHoursStart,
            s.QuietHoursEnd,
            s.PreferredHour,
            s.MaxPerDay,
            s.StreakAlerts,
            s.QuestAlerts,
            s.LeagueAlerts);

    private static NotificationSettingsDto ToSettingsDto(NotificationPreferences p)
        => new(
            p.Enabled,
            p.UtcOffsetMinutes,
            p.QuietHoursStart,
            p.QuietHoursEnd,
            p.PreferredHour,
            p.MaxPerDay,
            p.StreakAlerts,
            p.QuestAlerts,
            p.LeagueAlerts);

    private static ScheduledNotificationDto ToDto(ScheduledNotification n)
        => new(
            n.Kind.ToString(),
            n.Priority.ToString(),
            n.ScheduledUtc,
            n.LocalHour,
            n.Content.Mascot.ToString(),
            n.Content.Title,
            n.Content.Body,
            n.Content.Deeplink,
            n.DedupeKey);
}
