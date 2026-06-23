namespace Microlingo.Domain.Gamification;

/// La position d'un membre dans sa cohorte hebdomadaire : il monte d'une ligue
/// (zone de promotion), se maintient (zone neutre) ou redescend (zone de
/// relégation). C'est l'équivalent des bandes colorées du classement Duolingo.
public enum LeagueZone
{
    Promotion,
    Safe,
    Relegation
}

/// Le mouvement d'un membre à la clôture de la semaine, dérivé de sa zone.
public enum LeagueMovement
{
    Promoted,
    Held,
    Relegated
}

/// Un échelon de l'échelle des ligues. <see cref="Index"/> ordonne l'échelle
/// (1 = plancher), <see cref="Id"/> est l'identifiant stable et minuscule
/// persisté côté Cosmos (clé de partition <c>periodLeagueId</c>),
/// <see cref="Name"/> est le libellé français affiché et <see cref="Theme"/>
/// rattache l'échelon à un membre de l'Aurora Crew / une couleur de domaine.
public sealed record LeagueTier(int Index, string Id, string Name, string Theme);

/// L'échelle des dix ligues (§3.5 du plan). Source d'autorité unique pour
/// l'ordre des ligues et les transitions montée/descente : aucun code appelant
/// ne doit coder en dur un identifiant ou un voisin d'échelon.
public static class LeagueLadder
{
    /// Les dix échelons, du plancher (Bronze) à l'apex (Obsidienne), dans
    /// l'ordre exact du plan CTO. L'ordre du tableau EST l'autorité ; les
    /// <see cref="LeagueTier.Index"/> sont alignés (1..10) pour les comparaisons.
    public static readonly IReadOnlyList<LeagueTier> Tiers = new[]
    {
        new LeagueTier(1, "bronze", "Bronze", "nimbus"),
        new LeagueTier(2, "silver", "Argent", "nimbus"),
        new LeagueTier(3, "gold", "Or", "volt"),
        new LeagueTier(4, "sapphire", "Saphir", "cosmo"),
        new LeagueTier(5, "ruby", "Rubis", "sentinel"),
        new LeagueTier(6, "emerald", "Émeraude", "bicky"),
        new LeagueTier(7, "amethyst", "Améthyste", "pixel"),
        new LeagueTier(8, "pearl", "Perle", "cosmo"),
        new LeagueTier(9, "diamond", "Diamant", "sentinel"),
        new LeagueTier(10, "obsidian", "Obsidienne", "pixel")
    };

    /// L'échelon plancher (Bronze) — destination par défaut quand un identifiant
    /// est inconnu, et borne basse de la relégation.
    public static LeagueTier Lowest => Tiers[0];

    /// L'échelon apex (Obsidienne) — borne haute de la promotion.
    public static LeagueTier Highest => Tiers[^1];

    /// Résout un échelon par identifiant, insensible à la casse. Accepte
    /// <c>"bronze"</c> pour la rétrocompatibilité avec les documents existants
    /// (pool unique historique) et retombe sur <see cref="Lowest"/> si
    /// l'identifiant est inconnu ou vide — jamais d'exception côté lecture.
    public static LeagueTier ById(string? id)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return Lowest;
        }

        foreach (var tier in Tiers)
        {
            if (string.Equals(tier.Id, id, StringComparison.OrdinalIgnoreCase))
            {
                return tier;
            }
        }

        return Lowest;
    }

    /// Résout un échelon par index (1..10), borné aux extrémités de l'échelle.
    public static LeagueTier ByIndex(int index)
    {
        var clamped = Math.Clamp(index, Lowest.Index, Highest.Index);
        return Tiers[clamped - 1];
    }

    /// Vrai si l'échelon est l'apex (aucune promotion possible au-dessus).
    public static bool IsTop(LeagueTier tier) => tier.Index >= Highest.Index;

    /// Vrai si l'échelon est le plancher (aucune relégation possible en dessous).
    public static bool IsBottom(LeagueTier tier) => tier.Index <= Lowest.Index;

    /// L'échelon supérieur, ou le même au sommet (saturation, jamais d'erreur).
    public static LeagueTier Promote(LeagueTier tier) => IsTop(tier) ? tier : ByIndex(tier.Index + 1);

    /// L'échelon inférieur, ou le même au plancher (saturation, jamais d'erreur).
    public static LeagueTier Relegate(LeagueTier tier) => IsBottom(tier) ? tier : ByIndex(tier.Index - 1);
}

/// Le dimensionnement des zones d'une cohorte : combien de membres montent, se
/// maintiennent ou redescendent. <see cref="ZoneForRank"/> traduit ensuite un
/// rang (1-based) en <see cref="LeagueZone"/>.
public sealed record LeagueZonePlan(int CohortSize, int PromoteCount, int RelegateCount)
{
    /// Le nombre de membres de la bande neutre (ni promus, ni relégués).
    public int SafeCount => Math.Max(0, CohortSize - PromoteCount - RelegateCount);

    /// La zone d'un rang donné (1 = meilleur). Les rangs hors cohorte sont
    /// rabattus dans la bande neutre pour rester défensifs.
    public LeagueZone ZoneForRank(int rank)
    {
        if (rank < 1 || rank > CohortSize)
        {
            return LeagueZone.Safe;
        }

        if (rank <= PromoteCount)
        {
            return LeagueZone.Promotion;
        }

        if (rank > CohortSize - RelegateCount)
        {
            return LeagueZone.Relegation;
        }

        return LeagueZone.Safe;
    }
}

/// Calcule, pour une cohorte, la taille des zones de promotion et de relégation.
/// Vise ≈ 30 % de promus (carotte généreuse façon Duolingo) et ≈ 20 % de
/// relégués, en garantissant : aucune zone vide injustifiée, aucun chevauchement,
/// et une bande neutre dès que la cohorte est assez grande (≥ 3).
public static class LeagueZones
{
    public const double PromoteRatio = 0.30;
    public const double RelegateRatio = 0.20;

    /// Construit le plan de zones d'une cohorte. <paramref name="isTopTier"/>
    /// force zéro promotion (apex), <paramref name="isBottomTier"/> force zéro
    /// relégation (plancher).
    public static LeagueZonePlan Plan(int cohortSize, bool isTopTier, bool isBottomTier)
    {
        if (cohortSize <= 0)
        {
            return new LeagueZonePlan(0, 0, 0);
        }

        var promote = isTopTier ? 0 : Math.Clamp(Round(cohortSize * PromoteRatio), 1, cohortSize);
        var relegate = isBottomTier ? 0 : Math.Clamp(Round(cohortSize * RelegateRatio), 1, cohortSize);

        // Réserve au moins un membre en bande neutre dès que la cohorte le permet,
        // puis résorbe tout chevauchement en rognant d'abord la relégation (moins
        // punitif), la promotion restant la récompense mise en avant.
        var maxMovers = cohortSize >= 3 ? cohortSize - 1 : cohortSize;
        while (promote + relegate > maxMovers)
        {
            if (relegate >= promote && relegate > 0)
            {
                relegate--;
            }
            else if (promote > 0)
            {
                promote--;
            }
            else
            {
                break;
            }
        }

        return new LeagueZonePlan(cohortSize, promote, relegate);
    }

    private static int Round(double value) => (int)Math.Round(value, MidpointRounding.AwayFromZero);
}

/// Une ligne de classement classée : rang, identité, XP de la semaine et zone.
public sealed record LeagueStanding(
    int Rank,
    string UserId,
    string DisplayName,
    string? AvatarUrl,
    int WeeklyXp,
    LeagueZone Zone);

/// La donnée brute d'un membre avant classement (l'XP hebdomadaire fait foi).
public readonly record struct LeagueMember(string UserId, string DisplayName, string? AvatarUrl, int WeeklyXp);

/// Classe une cohorte de façon déterministe et serveur-autoritaire. Le tri est
/// <b>XP décroissant, puis UserId ordinal croissant</b> : un départage stable
/// indépendant de l'ordre d'arrivée des données, indispensable pour que deux
/// recalculs (client/serveur, ou deux requêtes) produisent un classement
/// identique. Le rang est une « competition rank » 1-based ; la zone découle du
/// plan fourni.
public static class LeagueStandings
{
    /// Classe les membres selon un plan de zones déjà calculé.
    public static IReadOnlyList<LeagueStanding> Rank(IEnumerable<LeagueMember> members, LeagueZonePlan plan)
    {
        ArgumentNullException.ThrowIfNull(members);
        ArgumentNullException.ThrowIfNull(plan);

        var ordered = members
            .OrderByDescending(m => m.WeeklyXp)
            .ThenBy(m => m.UserId, StringComparer.Ordinal)
            .ToArray();

        var standings = new LeagueStanding[ordered.Length];
        for (var i = 0; i < ordered.Length; i++)
        {
            var rank = i + 1;
            var m = ordered[i];
            standings[i] = new LeagueStanding(rank, m.UserId, m.DisplayName, m.AvatarUrl, m.WeeklyXp, plan.ZoneForRank(rank));
        }

        return standings;
    }

    /// Classe les membres en calculant d'abord le plan de zones à partir de la
    /// taille de cohorte observée et de la position de l'échelon sur l'échelle.
    public static IReadOnlyList<LeagueStanding> Rank(IReadOnlyCollection<LeagueMember> members, LeagueTier tier)
    {
        ArgumentNullException.ThrowIfNull(members);
        ArgumentNullException.ThrowIfNull(tier);

        var plan = LeagueZones.Plan(members.Count, LeagueLadder.IsTop(tier), LeagueLadder.IsBottom(tier));
        return Rank(members, plan);
    }
}

/// Le sort d'un membre à la clôture de la semaine : son mouvement, l'échelon
/// d'arrivée et la récompense en gemmes.
public sealed record LeagueOutcome(
    string UserId,
    string DisplayName,
    int Rank,
    LeagueZone Zone,
    LeagueMovement Movement,
    LeagueTier FromTier,
    LeagueTier ToTier,
    int GemReward);

/// Résout une semaine de ligue : transforme un classement final en mouvements
/// (montée/maintien/descente) et récompenses. Pur et déterministe — c'est la
/// brique qu'un futur job planifié (change feed / timer) rejouera pour mettre à
/// jour l'échelon persisté de chaque apprenant et créditer les gemmes.
public static class LeagueResolver
{
    /// Le barème de gemmes de fin de ligue. Seule la zone de promotion est
    /// récompensée (logique de tournoi) ; le podium est nettement valorisé.
    public static int GemReward(int rank, LeagueZone zone) => zone switch
    {
        LeagueZone.Promotion => rank switch
        {
            1 => 100,
            2 => 60,
            3 => 40,
            _ => 25
        },
        _ => 0
    };

    /// Résout chaque membre du classement final pour l'échelon courant.
    public static IReadOnlyList<LeagueOutcome> ResolveWeek(IReadOnlyList<LeagueStanding> standings, LeagueTier currentTier)
    {
        ArgumentNullException.ThrowIfNull(standings);
        ArgumentNullException.ThrowIfNull(currentTier);

        var outcomes = new LeagueOutcome[standings.Count];
        for (var i = 0; i < standings.Count; i++)
        {
            var s = standings[i];
            var movement = s.Zone switch
            {
                LeagueZone.Promotion => LeagueMovement.Promoted,
                LeagueZone.Relegation => LeagueMovement.Relegated,
                _ => LeagueMovement.Held
            };

            var toTier = movement switch
            {
                LeagueMovement.Promoted => LeagueLadder.Promote(currentTier),
                LeagueMovement.Relegated => LeagueLadder.Relegate(currentTier),
                _ => currentTier
            };

            outcomes[i] = new LeagueOutcome(
                s.UserId,
                s.DisplayName,
                s.Rank,
                s.Zone,
                movement,
                currentTier,
                toTier,
                GemReward(s.Rank, s.Zone));
        }

        return outcomes;
    }
}

/// Une période hebdomadaire de ligue, identifiée par son lundi (UTC). Centralise
/// la fabrication des clés <c>periodLeagueId</c> (<c>weekly:yyyyMMdd:tier</c>)
/// jusqu'ici dupliquée dans le dépôt Cosmos, pour que le domaine soit l'unique
/// source de vérité de la temporalité des ligues.
public sealed record LeaguePeriod(DateOnly WeekStart)
{
    /// L'identifiant de période sans échelon (ex. <c>weekly:20260622</c>).
    public string Id => $"weekly:{WeekStart:yyyyMMdd}";

    /// Le début de la semaine (lundi 00:00 UTC).
    public DateTimeOffset StartsAt => new(WeekStart.ToDateTime(TimeOnly.MinValue), TimeSpan.Zero);

    /// La fin de la semaine (lundi suivant 00:00 UTC), date de remise à zéro.
    public DateTimeOffset EndsAt => StartsAt.AddDays(7);

    /// La clé de partition complète d'une cohorte (ex. <c>weekly:20260622:bronze</c>).
    public string Compose(string tierId) => $"{Id}:{tierId}";

    /// Le temps restant avant la clôture, borné à zéro (jamais négatif).
    public TimeSpan ResetsIn(DateTimeOffset now)
    {
        var remaining = EndsAt - now;
        return remaining > TimeSpan.Zero ? remaining : TimeSpan.Zero;
    }
}

/// Fabriques et analyse des périodes hebdomadaires de ligue (pures).
public static class LeaguePeriods
{
    /// La période contenant un instant donné (semaine débutant le lundi UTC).
    public static LeaguePeriod ForInstant(DateTimeOffset instant)
    {
        var date = instant.UtcDateTime.Date;
        var offset = ((int)date.DayOfWeek + 6) % 7; // lundi = 0
        return new LeaguePeriod(DateOnly.FromDateTime(date.AddDays(-offset)));
    }

    /// Décompose un <c>periodLeagueId</c> en (identifiant de période, échelon).
    /// L'échelon est le dernier segment ; la période est tout ce qui précède.
    /// Robuste aux identifiants de test (ex. <c>weekly:test:bronze</c>).
    public static (string PeriodId, string TierId) Parse(string periodLeagueId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(periodLeagueId);

        var lastSeparator = periodLeagueId.LastIndexOf(':');
        if (lastSeparator <= 0 || lastSeparator == periodLeagueId.Length - 1)
        {
            return (periodLeagueId, LeagueLadder.Lowest.Id);
        }

        var periodId = periodLeagueId[..lastSeparator];
        var tierId = periodLeagueId[(lastSeparator + 1)..];
        return (periodId, tierId);
    }
}
