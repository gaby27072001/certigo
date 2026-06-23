using FluentAssertions;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Application.Services;
using Xunit;

namespace Microlingo.Application.Tests;

/// <summary>
/// Vérifie l'enrichissement de la ligue par le service applicatif : il reclasse
/// la cohorte renvoyée par le dépôt avec le moteur de domaine pur, étiquette les
/// zones, expose mon rang/ma zone, les voisins d'échelle (montée/descente) et le
/// compte à rebours de réinitialisation, puis prévisualise la clôture (mouvements
/// + barème de gemmes). Le dépôt est un bouchon contrôlable pour rendre chaque
/// assertion déterministe (notamment <c>ResetsInSeconds</c>, qui dépend de l'horloge).
/// </summary>
public sealed class LeaderboardServiceTests
{
    private const string Me = "u01";
    private static readonly DateTimeOffset Now = new(2026, 1, 5, 9, 0, 0, TimeSpan.Zero); // un lundi

    /// Construit le service avec une horloge figée et un dépôt qui renvoie
    /// exactement la ligue fournie (cohorte, échelon, « moi », fin de période).
    private static LeaderboardService Build(LeagueDto league, DateTimeOffset? now = null)
        => new(new FakeUserContext(Me, "Moi"), new FakeClock(now ?? Now), new StubLeaderboard(league));

    /// Fabrique une ligue de test. L'ordre d'insertion des membres est volontairement
    /// brouillé : le service doit reclasser par XP décroissante, pas faire confiance
    /// au rang d'entrée. Les rangs passés ici ne sont donc que des marque-places.
    private static LeagueDto League(string tier, string meUserId, DateTimeOffset endsAt, params (string Id, int Xp)[] members)
    {
        var entries = members
            .Select((m, i) => new LeaderboardEntryDto(m.Id, m.Id.ToUpperInvariant(), null, i + 1, m.Xp))
            .ToList();
        return new LeagueDto($"weekly:20260105:{tier}", tier, endsAt, 10, meUserId, entries);
    }

    /// Cohorte « pleine » de dix membres à XP distincts (100, 90, … 10) en ordre
    /// d'insertion mélangé, pour prouver le reclassement déterministe du moteur.
    private static (string Id, int Xp)[] FullCohort() => new[]
    {
        ("u05", 60), ("u01", 100), ("u09", 20), ("u03", 80), ("u07", 40),
        ("u02", 90), ("u10", 10), ("u06", 50), ("u04", 70), ("u08", 30)
    };

    [Fact]
    public async Task GetMyLeagueAsync_reclasse_la_cohorte_par_xp_decroissante()
    {
        var service = Build(League("gold", Me, Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.Entries.Should().HaveCount(10);
        league.Entries.Select(e => e.UserId).Should()
            .ContainInOrder("u01", "u02", "u03", "u04", "u05", "u06", "u07", "u08", "u09", "u10");
        league.Entries.Select(e => e.Rank).Should().ContainInOrder(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
        league.Entries[0].WeeklyXp.Should().Be(100);
        league.Entries[9].WeeklyXp.Should().Be(10);
    }

    [Fact]
    public async Task GetMyLeagueAsync_etiquette_les_zones_promotion_neutre_relegation()
    {
        // Échelon intermédiaire (Or) : promotion ET relégation existent.
        // 10 membres → promote = round(10·0,30) = 3 ; relegate = round(10·0,20) = 2 ; neutre = 5.
        var service = Build(League("gold", Me, Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.PromoteCount.Should().Be(3);
        league.RelegateCount.Should().Be(2);
        league.Entries.Where(e => e.Zone == "promotion").Select(e => e.Rank).Should().Equal(1, 2, 3);
        league.Entries.Where(e => e.Zone == "safe").Select(e => e.Rank).Should().Equal(4, 5, 6, 7, 8);
        league.Entries.Where(e => e.Zone == "relegation").Select(e => e.Rank).Should().Equal(9, 10);
    }

    [Fact]
    public async Task GetMyLeagueAsync_expose_mon_rang_ma_zone_et_les_voisins_dechelle()
    {
        var service = Build(League("gold", Me, Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.Tier.Should().Be("gold");
        league.TierIndex.Should().Be(3);
        league.TierName.Should().Be("Or");
        league.NextTier.Should().Be("Saphir");
        league.PreviousTier.Should().Be("Argent");
        league.MyRank.Should().Be(1);
        league.MyWeeklyXp.Should().Be(100);
        league.MyZone.Should().Be("promotion");
    }

    [Fact]
    public async Task GetMyLeagueAsync_pour_un_membre_en_bas_de_cohorte_signale_la_relegation()
    {
        var service = Build(League("gold", "u10", Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.MyRank.Should().Be(10);
        league.MyWeeklyXp.Should().Be(10);
        league.MyZone.Should().Be("relegation");
    }

    [Fact]
    public async Task GetMyLeagueAsync_au_plancher_bronze_na_pas_de_predecesseur_ni_de_zone_de_relegation()
    {
        var service = Build(League("bronze", "u10", Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.TierName.Should().Be("Bronze");
        league.PreviousTier.Should().BeNull();
        league.NextTier.Should().Be("Argent");
        league.RelegateCount.Should().Be(0);
        league.Entries.Should().NotContain(e => e.Zone == "relegation");
        league.MyZone.Should().NotBe("relegation");
    }

    [Fact]
    public async Task GetMyLeagueAsync_a_lapex_obsidienne_na_pas_de_successeur()
    {
        var service = Build(League("obsidian", Me, Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.TierName.Should().Be("Obsidienne");
        league.TierIndex.Should().Be(10);
        league.NextTier.Should().BeNull();
        league.PreviousTier.Should().Be("Diamant");
        league.Entries.Should().NotContain(e => e.Zone == "promotion");
    }

    [Fact]
    public async Task GetMyLeagueAsync_quand_je_ne_suis_pas_dans_la_cohorte_renvoie_des_valeurs_neutres()
    {
        var service = Build(League("gold", "absent", Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.MyRank.Should().Be(0);
        league.MyWeeklyXp.Should().Be(0);
        league.MyZone.Should().Be("safe");
    }

    [Fact]
    public async Task GetMyLeagueAsync_calcule_le_compte_a_rebours_de_reinitialisation()
    {
        var service = Build(League("gold", Me, Now.AddDays(3), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.ResetsInSeconds.Should().Be(3 * 24 * 60 * 60);
    }

    [Fact]
    public async Task GetMyLeagueAsync_borne_le_compte_a_rebours_a_zero_si_la_periode_est_close()
    {
        var service = Build(League("gold", Me, Now.AddHours(-1), FullCohort()));

        var league = await service.GetMyLeagueAsync();

        league.ResetsInSeconds.Should().Be(0);
    }

    [Fact]
    public async Task PreviewResolutionAsync_renvoie_les_mouvements_et_le_bareme_de_gemmes()
    {
        var service = Build(League("gold", Me, Now.AddDays(3), FullCohort()));

        var resolution = await service.PreviewResolutionAsync();

        resolution.PeriodLeagueId.Should().Be("weekly:20260105:gold");
        resolution.Tier.Should().Be("gold");
        resolution.Outcomes.Should().HaveCount(10);

        var first = resolution.Outcomes.Single(o => o.Rank == 1);
        first.UserId.Should().Be("u01");
        first.Zone.Should().Be("promotion");
        first.Movement.Should().Be("promoted");
        first.FromTier.Should().Be("Or");
        first.ToTier.Should().Be("Saphir");
        first.GemReward.Should().Be(100);

        resolution.Outcomes.Single(o => o.Rank == 2).GemReward.Should().Be(60);
        resolution.Outcomes.Single(o => o.Rank == 3).GemReward.Should().Be(40);
    }

    [Fact]
    public async Task PreviewResolutionAsync_maintient_la_zone_neutre_sans_gemme()
    {
        var service = Build(League("gold", Me, Now.AddDays(3), FullCohort()));

        var resolution = await service.PreviewResolutionAsync();

        var held = resolution.Outcomes.Single(o => o.Rank == 5);
        held.Zone.Should().Be("safe");
        held.Movement.Should().Be("held");
        held.FromTier.Should().Be("Or");
        held.ToTier.Should().Be("Or");
        held.GemReward.Should().Be(0);
    }

    [Fact]
    public async Task PreviewResolutionAsync_relegue_les_derniers_vers_lechelon_inferieur()
    {
        var service = Build(League("gold", Me, Now.AddDays(3), FullCohort()));

        var resolution = await service.PreviewResolutionAsync();

        var relegated = resolution.Outcomes.Single(o => o.Rank == 10);
        relegated.Zone.Should().Be("relegation");
        relegated.Movement.Should().Be("relegated");
        relegated.FromTier.Should().Be("Or");
        relegated.ToTier.Should().Be("Argent");
        relegated.GemReward.Should().Be(0);
    }

    /// Dépôt bouchon : renvoie toujours la ligue fournie, ignore les écritures XP.
    private sealed class StubLeaderboard(LeagueDto league) : ILeaderboardRepository
    {
        public Task<LeagueDto> GetLeagueAsync(string userId, CancellationToken cancellationToken = default)
            => Task.FromResult(league);

        public Task AddXpAsync(string userId, int xp, CancellationToken cancellationToken = default)
            => Task.CompletedTask;
    }
}
