using System;
using System.Collections.Generic;

namespace Certigo.Domain.Notifications;

/// <summary>
/// Estimateur pur de la « meilleure heure » d'apprentissage à partir d'un histogramme
/// d'activité sur 24 heures locales. L'apprentissage est récency-pondéré : chaque
/// observation décroît les anciennes par un facteur déterministe (7/8) avant de
/// renforcer l'heure observée. Aucune dépendance, entièrement testable.
/// </summary>
public static class BestHourEstimator
{
    /// <summary>Heure de repli par défaut (19h locale) quand aucune donnée n'est disponible.</summary>
    public const int DefaultHour = 19;

    /// <summary>Nombre d'heures dans une journée (taille de l'histogramme).</summary>
    public const int HourCount = 24;

    private const int DecayNumerator = 7;
    private const int DecayDenominator = 8;
    private const int ReinforceWeight = 8;

    /// <summary>
    /// Estime l'heure dominante d'un histogramme (argmax). En cas d'égalité, l'heure la
    /// plus proche de <paramref name="fallbackHour"/> (distance circulaire) gagne ; à
    /// distance égale, l'heure d'index le plus petit. Histogramme vide ou nul → repli.
    /// </summary>
    public static int Estimate(IReadOnlyList<int>? histogram, int fallbackHour = DefaultHour)
    {
        var fallback = Wrap(fallbackHour);
        if (histogram is null || histogram.Count == 0)
        {
            return fallback;
        }

        var bestHour = -1;
        var bestCount = 0;
        var bestDistance = int.MaxValue;
        var limit = Math.Min(histogram.Count, HourCount);

        for (var hour = 0; hour < limit; hour++)
        {
            var count = histogram[hour];
            if (count <= 0)
            {
                continue;
            }

            var distance = CircularDistance(hour, fallback);
            if (count > bestCount ||
                (count == bestCount && distance < bestDistance))
            {
                bestHour = hour;
                bestCount = count;
                bestDistance = distance;
            }
        }

        return bestHour < 0 ? fallback : bestHour;
    }

    /// <summary>
    /// Renvoie un nouvel histogramme (24 cases) intégrant une observation d'activité à
    /// <paramref name="activeHour"/> : décroissance exponentielle de l'existant puis
    /// renforcement de l'heure observée. Borné par construction (point fixe ≈ 64).
    /// </summary>
    public static int[] Reinforce(IReadOnlyList<int>? histogram, int activeHour)
    {
        var next = new int[HourCount];
        if (histogram is not null)
        {
            var limit = Math.Min(histogram.Count, HourCount);
            for (var hour = 0; hour < limit; hour++)
            {
                var value = histogram[hour];
                if (value > 0)
                {
                    next[hour] = value * DecayNumerator / DecayDenominator;
                }
            }
        }

        next[Wrap(activeHour)] += ReinforceWeight;
        return next;
    }

    /// <summary>Ramène une heure dans l'intervalle [0, 24).</summary>
    public static int Wrap(int hour) => ((hour % HourCount) + HourCount) % HourCount;

    private static int CircularDistance(int a, int b)
    {
        var diff = Math.Abs(a - b);
        return Math.Min(diff, HourCount - diff);
    }
}
