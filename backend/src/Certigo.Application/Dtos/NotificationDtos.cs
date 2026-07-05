namespace Certigo.Application.Dtos;

// --- Notifications intelligentes (§3.13) -----------------------------------

/// <summary>
/// Préférences de notification telles qu'exposées au client. Reflète
/// <c>Certigo.Domain.Notifications.NotificationPreferences</c> ; le serveur
/// borne systématiquement les valeurs avant de planifier.
/// </summary>
public sealed record NotificationSettingsDto(
    bool Enabled,
    int UtcOffsetMinutes,
    int QuietHoursStart,
    int QuietHoursEnd,
    int PreferredHour,
    int MaxPerDay,
    bool StreakAlerts,
    bool QuestAlerts,
    bool LeagueAlerts)
{
    /// <summary>Réglages par défaut : actifs, UTC, silence 22h→7h, rappel 19h, 3/jour, toutes alertes.</summary>
    public static NotificationSettingsDto Default { get; } =
        new(true, 0, 22, 7, 19, 3, true, true, true);
}

/// <summary>Requête de mise à jour (remplacement intégral) des préférences de notification.</summary>
public sealed record UpdateNotificationSettingsRequest(
    bool Enabled,
    int UtcOffsetMinutes,
    int QuietHoursStart,
    int QuietHoursEnd,
    int PreferredHour,
    int MaxPerDay,
    bool StreakAlerts,
    bool QuestAlerts,
    bool LeagueAlerts);

/// <summary>
/// État de notification persisté dans le profil : préférences + histogramme
/// d'activité horaire appris (24 compartiments) et date du dernier renforcement,
/// garantissant l'idempotence journalière de l'apprentissage de l'heure préférée.
/// </summary>
public sealed record NotificationStateDto(
    NotificationSettingsDto Settings,
    List<int>? ActivityHours = null,
    DateOnly? LastActivityHourDate = null);

/// <summary>Une notification planifiée, projetée pour le client (énumérations en chaînes).</summary>
public sealed record ScheduledNotificationDto(
    string Kind,
    string Priority,
    DateTimeOffset ScheduledUtc,
    int LocalHour,
    string Mascot,
    string Title,
    string Body,
    string Deeplink,
    string DedupeKey);

/// <summary>Plan de notifications d'une journée locale, déjà trié et plafonné par le serveur.</summary>
public sealed record NotificationPlanDto(
    DateOnly LocalDate,
    IReadOnlyList<ScheduledNotificationDto> Notifications);
