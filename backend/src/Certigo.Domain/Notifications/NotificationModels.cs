using System;
using System.Collections.Generic;

namespace Certigo.Domain.Notifications;

/// <summary>
/// Catégorie d'une notification intelligente. Chaque catégorie porte une intention
/// pédagogique distincte (rétention, retour, régularité, gemmes, ligue, jalon).
/// Les identifiants restent en anglais ; le texte affiché (en français) vit dans
/// <see cref="NotificationCatalog"/>.
/// </summary>
public enum NotificationKind
{
    /// <summary>La série de l'apprenant s'éteint à minuit s'il ne révise pas.</summary>
    StreakDanger,

    /// <summary>L'apprenant est absent depuis au moins deux jours : on l'invite à revenir.</summary>
    Comeback,

    /// <summary>Rappel d'apprentissage quotidien à l'heure préférée (ou apprise).</summary>
    DailyReminder,

    /// <summary>Des quêtes sont réclamables ou en attente d'accomplissement.</summary>
    QuestNudge,

    /// <summary>Position de promotion ou de relégation dans la ligue hebdomadaire.</summary>
    LeagueNudge,

    /// <summary>Un jalon de série (7/30/100/365 jours) est sur le point d'être atteint.</summary>
    Milestone
}

/// <summary>
/// Priorité intrinsèque d'une notification, utilisée pour trier et plafonner
/// l'envoi quotidien lorsque plusieurs candidates sont éligibles le même jour.
/// </summary>
public enum NotificationPriority
{
    /// <summary>Informative, sacrifiable en premier si le quota est atteint.</summary>
    Low = 0,

    /// <summary>Engagement standard (rappel, quête, ligue).</summary>
    Normal = 1,

    /// <summary>Retour après absence, valeur de rétention élevée.</summary>
    High = 2,

    /// <summary>Série en danger : à ne jamais sacrifier.</summary>
    Critical = 3
}

/// <summary>
/// Signal de ligue propre au moteur de notifications. Indépendant de l'énumération
/// <c>LeagueZone</c> du domaine Gamification afin d'éviter tout couplage entre moteurs.
/// </summary>
public enum LeagueSignal
{
    /// <summary>Pas de ligue active ou apprenant hors cohorte.</summary>
    None,

    /// <summary>Position stable, ni promotion ni relégation.</summary>
    Safe,

    /// <summary>Zone de promotion : l'apprenant peut monter d'une ligue.</summary>
    Promotion,

    /// <summary>Zone de relégation : l'apprenant risque de descendre.</summary>
    Relegation
}

/// <summary>
/// Mascotte de l'« Aurora Crew » associée à une notification. Chaque mascotte porte
/// une personnalité et un domaine (cf. plan produit §2).
/// </summary>
public enum NotificationMascot
{
    /// <summary>Le guide nuage, bienveillant : onboarding, célébrations, rappels.</summary>
    Nimbus,

    /// <summary>Sprite éclair (serverless), vif : énergie et urgence ludique.</summary>
    Volt,

    /// <summary>Gardien des données (Cosmos DB), calme et structuré.</summary>
    Cosmo,

    /// <summary>Bouclier de sécurité (Entra/Defender), sérieux : alertes de série.</summary>
    Sentinel,

    /// <summary>Petit robot constructeur (IaC/Bicep), méthodique.</summary>
    Bicky,

    /// <summary>Œil curieux (IA/Foundry), espiègle : quêtes et créativité.</summary>
    Pixel,

    /// <summary>L'apprenant débutant, miroir émotionnel : retours après absence.</summary>
    Pip
}

/// <summary>
/// Photographie déterministe de l'état d'engagement d'un apprenant à un instant donné.
/// Toutes les valeurs sont calculées côté serveur ; le moteur n'observe jamais le réseau.
/// </summary>
/// <param name="StreakDays">Longueur de la série en cours (jours consécutifs).</param>
/// <param name="LastActiveDate">Dernière date locale d'activité, ou <c>null</c> si jamais actif.</param>
/// <param name="HasFreeze">Indique qu'un gel de série protège la flamme.</param>
/// <param name="PracticedToday">L'apprenant a déjà gagné de l'XP aujourd'hui.</param>
/// <param name="DailyGoalMet">L'objectif quotidien d'XP est atteint.</param>
/// <param name="ClaimableQuests">Nombre de quêtes terminées et réclamables.</param>
/// <param name="PendingQuests">Nombre de quêtes encore à accomplir.</param>
/// <param name="League">Signal de ligue hebdomadaire courant.</param>
public sealed record NotificationSignals(
    int StreakDays,
    DateOnly? LastActiveDate,
    bool HasFreeze,
    bool PracticedToday,
    bool DailyGoalMet,
    int ClaimableQuests,
    int PendingQuests,
    LeagueSignal League)
{
    /// <summary>Apprenant inactif : aucune série, jamais actif, aucun signal positif.</summary>
    public static NotificationSignals Inactive { get; } =
        new(0, null, false, false, false, 0, 0, LeagueSignal.None);
}

/// <summary>
/// Préférences de notification de l'apprenant. Le serveur les normalise systématiquement
/// avant usage (<see cref="Normalized"/>) afin de rester robuste à des entrées clientes invalides.
/// </summary>
/// <param name="Enabled">Notifications activées globalement.</param>
/// <param name="UtcOffsetMinutes">Décalage local par rapport à UTC, en minutes.</param>
/// <param name="QuietHoursStart">Heure locale de début des heures silencieuses [0..24).</param>
/// <param name="QuietHoursEnd">Heure locale de fin des heures silencieuses [0..24).</param>
/// <param name="PreferredHour">Heure locale préférée pour les rappels [0..24).</param>
/// <param name="MaxPerDay">Plafond de notifications par jour.</param>
/// <param name="StreakAlerts">Autorise les alertes de série en danger.</param>
/// <param name="QuestAlerts">Autorise les rappels de quêtes.</param>
/// <param name="LeagueAlerts">Autorise les rappels de ligue.</param>
public sealed record NotificationPreferences(
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
    /// <summary>Préférences par défaut : actif, UTC, silence 22h→7h, rappel à 19h, 3/jour, toutes alertes.</summary>
    public static NotificationPreferences Default { get; } =
        new(true, 0, 22, 7, 19, 3, true, true, true);

    /// <summary>
    /// Renvoie une copie bornée : décalage UTC clampé à [-720, 840] minutes, heures ramenées
    /// modulo 24, plafond quotidien clampé à [0, 10].
    /// </summary>
    public NotificationPreferences Normalized() => this with
    {
        UtcOffsetMinutes = Math.Clamp(UtcOffsetMinutes, -720, 840),
        QuietHoursStart = WrapHour(QuietHoursStart),
        QuietHoursEnd = WrapHour(QuietHoursEnd),
        PreferredHour = WrapHour(PreferredHour),
        MaxPerDay = Math.Clamp(MaxPerDay, 0, 10)
    };

    private static int WrapHour(int hour) => ((hour % 24) + 24) % 24;
}

/// <summary>
/// Contenu localisé (français) d'une notification : mascotte, titre, corps et lien profond.
/// </summary>
/// <param name="Mascot">Mascotte expressive associée.</param>
/// <param name="Title">Titre court de la notification.</param>
/// <param name="Body">Corps du message, ton positif (jamais punitif).</param>
/// <param name="Deeplink">Lien profond ouvrant l'écran pertinent dans l'application.</param>
public sealed record NotificationContent(
    NotificationMascot Mascot,
    string Title,
    string Body,
    string Deeplink);

/// <summary>
/// Notification planifiée et prête à être remise par le transport (Azure Notification Hubs,
/// FCM/APNs). Le moteur calcule l'instant d'envoi en UTC à partir de l'heure locale visée.
/// </summary>
/// <param name="Kind">Catégorie de la notification.</param>
/// <param name="Priority">Priorité intrinsèque.</param>
/// <param name="ScheduledUtc">Instant d'envoi visé, en UTC.</param>
/// <param name="LocalHour">Heure locale visée [0..24).</param>
/// <param name="Content">Contenu localisé.</param>
/// <param name="DedupeKey">Clé d'idempotence (catégorie + date locale) évitant les doublons.</param>
public sealed record ScheduledNotification(
    NotificationKind Kind,
    NotificationPriority Priority,
    DateTimeOffset ScheduledUtc,
    int LocalHour,
    NotificationContent Content,
    string DedupeKey);

/// <summary>
/// Plan de notifications d'une journée locale donnée, déjà trié et plafonné.
/// </summary>
/// <param name="LocalDate">Journée locale couverte par le plan.</param>
/// <param name="Notifications">Notifications planifiées, ordre de remise déterministe.</param>
public sealed record NotificationPlan(
    DateOnly LocalDate,
    IReadOnlyList<ScheduledNotification> Notifications)
{
    /// <summary>Plan vide pour une journée (apprenant désinscrit ou aucune candidate éligible).</summary>
    public static NotificationPlan Empty(DateOnly localDate) =>
        new(localDate, Array.Empty<ScheduledNotification>());
}
