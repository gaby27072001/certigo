using System;
using System.Collections.Generic;
using System.Globalization;

namespace Microlingo.Domain.Notifications;

/// <summary>
/// Catalogue pur du contenu (français) et des règles intrinsèques des notifications :
/// priorité par catégorie, jalons de série, et fabriques de <see cref="NotificationContent"/>.
/// Aucune dépendance externe, entièrement déterministe et testable.
/// </summary>
public static class NotificationCatalog
{
    /// <summary>Jalons de série célébrés (jours consécutifs).</summary>
    public static readonly IReadOnlyList<int> StreakMilestones = new[] { 7, 30, 100, 365 };

    /// <summary>Fenêtre d'anticipation (en jours) pour annoncer un jalon de série imminent.</summary>
    public const int MilestoneWindowDays = 2;

    private const string DeeplinkHome = "microlingo://home";
    private const string DeeplinkLesson = "microlingo://lesson/next";
    private const string DeeplinkQuests = "microlingo://quests";
    private const string DeeplinkLeague = "microlingo://league";

    /// <summary>Priorité intrinsèque d'une catégorie de notification.</summary>
    public static NotificationPriority PriorityOf(NotificationKind kind) => kind switch
    {
        NotificationKind.StreakDanger => NotificationPriority.Critical,
        NotificationKind.Comeback => NotificationPriority.High,
        NotificationKind.DailyReminder => NotificationPriority.Normal,
        NotificationKind.QuestNudge => NotificationPriority.Normal,
        NotificationKind.LeagueNudge => NotificationPriority.Normal,
        NotificationKind.Milestone => NotificationPriority.Low,
        _ => NotificationPriority.Normal
    };

    /// <summary>
    /// Prochain jalon de série strictement supérieur à <paramref name="streakDays"/>,
    /// ou <c>null</c> si aucun jalon n'est devant.
    /// </summary>
    public static int? NextMilestone(int streakDays)
    {
        foreach (var milestone in StreakMilestones)
        {
            if (milestone > streakDays)
            {
                return milestone;
            }
        }

        return null;
    }

    /// <summary>
    /// Alerte « série en danger » (Sentinel). Le ton s'intensifie avec la longueur de la série
    /// et tient compte d'un éventuel gel protecteur. Toujours encourageant, jamais punitif.
    /// </summary>
    public static NotificationContent StreakDanger(int streakDays, bool hasFreeze)
    {
        if (hasFreeze)
        {
            return new NotificationContent(
                NotificationMascot.Sentinel,
                "Ta flamme est protégée 🛡️",
                $"Un gel de série veille sur tes {streakDays} jours. Une leçon de 3 minutes et tu n'auras même pas à l'utiliser.",
                DeeplinkLesson);
        }

        if (streakDays >= 30)
        {
            return new NotificationContent(
                NotificationMascot.Sentinel,
                $"{streakDays} jours en jeu ! 🔥",
                $"Une série de {streakDays} jours mérite d'être défendue. Une leçon maintenant et elle est sauvée.",
                DeeplinkLesson);
        }

        if (streakDays >= 7)
        {
            return new NotificationContent(
                NotificationMascot.Sentinel,
                "Ne casse pas ta série ! 🔥",
                $"{streakDays} jours d'affilée… ce serait dommage de t'arrêter ce soir. Sentinel compte sur toi.",
                DeeplinkLesson);
        }

        return new NotificationContent(
            NotificationMascot.Sentinel,
            "Ta flamme va s'éteindre 🔥",
            $"Ta série de {streakDays} jour(s) s'arrête à minuit. 3 minutes suffisent pour la garder vivante !",
            DeeplinkLesson);
    }

    /// <summary>
    /// Invitation au retour (Pip), avec une chaleur croissante selon la durée d'absence.
    /// </summary>
    public static NotificationContent Comeback(int daysAway)
    {
        if (daysAway >= 30)
        {
            return new NotificationContent(
                NotificationMascot.Pip,
                "Le grand retour 🚀",
                $"Cela fait un moment ({daysAway} jours). Reprends là où tu t'es arrêté — Pip t'accompagne pas à pas.",
                DeeplinkLesson);
        }

        if (daysAway >= 15)
        {
            return new NotificationContent(
                NotificationMascot.Pip,
                "On repart d'un pas léger 💙",
                $"{daysAway} jours, et alors ? Chaque expert a fait des pauses. Une seule leçon aujourd'hui et la machine est relancée.",
                DeeplinkLesson);
        }

        if (daysAway >= 8)
        {
            return new NotificationContent(
                NotificationMascot.Pip,
                "Azure t'attend toujours",
                $"Cela fait {daysAway} jours. Pas de pression : on redémarre avec une leçon courte et accessible.",
                DeeplinkLesson);
        }

        if (daysAway >= 4)
        {
            return new NotificationContent(
                NotificationMascot.Pip,
                "Reviens quand tu veux 💙",
                $"{daysAway} jours d'absence. Ta place est gardée au chaud : une mini-leçon et tu repars du bon pied.",
                DeeplinkLesson);
        }

        return new NotificationContent(
            NotificationMascot.Pip,
            "Pip t'attend 👋",
            $"Cela fait {daysAway} jours sans révision. Pip s'ennuie un peu — 5 minutes pour relancer ta progression ?",
            DeeplinkLesson);
    }

    /// <summary>Rappel quotidien « commence ta journée » (Nimbus), adapté à la série en cours.</summary>
    public static NotificationContent DailyReminderFresh(int streakDays)
    {
        if (streakDays > 0)
        {
            return new NotificationContent(
                NotificationMascot.Nimbus,
                "Garde le rythme ☁️",
                $"Continue sur ta lancée : une courte leçon pour entretenir tes {streakDays} jours de série.",
                DeeplinkLesson);
        }

        return new NotificationContent(
            NotificationMascot.Nimbus,
            "C'est l'heure d'Azure ☁️",
            "Une première leçon aujourd'hui et ta flamme s'allume. On y va ?",
            DeeplinkLesson);
    }

    /// <summary>Rappel quotidien « termine ton objectif » (Nimbus) lorsque la journée est entamée.</summary>
    public static NotificationContent DailyReminderFinishGoal()
        => new(
            NotificationMascot.Nimbus,
            "Plus que quelques XP 🎯",
            "Tu as commencé aujourd'hui — termine ton objectif du jour pour décrocher tes récompenses !",
            DeeplinkLesson);

    /// <summary>Incitation à réclamer des quêtes terminées (Pixel).</summary>
    public static NotificationContent QuestClaim(int claimable)
        => new(
            NotificationMascot.Pixel,
            "Récompenses à réclamer 💎",
            $"{claimable} quête(s) terminée(s) ! Passe récupérer tes gemmes avant la fin de la journée.",
            DeeplinkQuests);

    /// <summary>Incitation à accomplir des quêtes en attente (Pixel).</summary>
    public static NotificationContent QuestPending(int pending)
        => new(
            NotificationMascot.Pixel,
            "Tes quêtes t'attendent 📋",
            $"Il te reste {pending} quête(s) à accomplir aujourd'hui. Un petit effort pour des gemmes en plus !",
            DeeplinkQuests);

    /// <summary>Rappel de position de promotion en ligue (Cosmo).</summary>
    public static NotificationContent LeaguePromotion()
        => new(
            NotificationMascot.Cosmo,
            "Zone de promotion ! 📈",
            "Tu es en position de monter d'une ligue. Encore un peu d'XP et la promotion est à toi.",
            DeeplinkLeague);

    /// <summary>Alerte de risque de relégation en ligue (Cosmo).</summary>
    public static NotificationContent LeagueRelegation()
        => new(
            NotificationMascot.Cosmo,
            "Attention à la relégation 📉",
            "Tu glisses vers la zone de relégation. Quelques XP suffiraient à conserver ta place.",
            DeeplinkLeague);

    /// <summary>Annonce d'un jalon de série imminent (Nimbus).</summary>
    public static NotificationContent MilestoneApproaching(int target, int daysAway)
        => new(
            NotificationMascot.Nimbus,
            "Un jalon approche 🎉",
            string.Create(
                CultureInfo.InvariantCulture,
                $"Plus que {daysAway} jour(s) avant ton jalon de {target} jours de série ! Nimbus prépare déjà les confettis."),
            DeeplinkHome);
}
