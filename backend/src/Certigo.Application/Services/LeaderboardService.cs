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

public interface ILeaderboardService
{
    Task<LeagueDto> GetMyLeagueAsync(CancellationToken cancellationToken = default);
    Task<LeagueResolutionDto> PreviewResolutionAsync(CancellationToken cancellationToken = default);
}

public sealed class LeaderboardService(
    IUserContext userContext,
    IClock clock,
    ILeaderboardRepository leaderboard) : ILeaderboardService
{
    public async Task<LeagueDto> GetMyLeagueAsync(CancellationToken cancellationToken = default)
    {
        var league = await leaderboard.GetLeagueAsync(userContext.UserId, cancellationToken).ConfigureAwait(false);
        return Enrich(league);
    }

    public async Task<LeagueResolutionDto> PreviewResolutionAsync(CancellationToken cancellationToken = default)
    {
        var league = await leaderboard.GetLeagueAsync(userContext.UserId, cancellationToken).ConfigureAwait(false);
        var tier = LeagueLadder.ById(league.Tier);
        var standings = LeagueStandings.Rank(ToMembers(league.Entries), tier);
        var outcomes = LeagueResolver.ResolveWeek(standings, tier);

        var mapped = new LeagueOutcomeDto[outcomes.Count];
        for (var i = 0; i < outcomes.Count; i++)
        {
            var o = outcomes[i];
            mapped[i] = new LeagueOutcomeDto(
                o.UserId,
                o.DisplayName,
                o.Rank,
                ZoneLabel(o.Zone),
                MovementLabel(o.Movement),
                o.FromTier.Name,
                o.ToTier.Name,
                o.GemReward);
        }

        return new LeagueResolutionDto(league.PeriodLeagueId, tier.Id, mapped);
    }

    // Reclasse la cohorte renvoyée par le dépôt avec le moteur de domaine pur,
    // puis enrichit la vue (échelon, voisins d'échelle, ma position/zone, reset).
    private LeagueDto Enrich(LeagueDto league)
    {
        var tier = LeagueLadder.ById(league.Tier);
        var members = ToMembers(league.Entries);
        var plan = LeagueZones.Plan(members.Length, LeagueLadder.IsTop(tier), LeagueLadder.IsBottom(tier));
        var standings = LeagueStandings.Rank(members, plan);

        var entries = new LeaderboardEntryDto[standings.Count];
        for (var i = 0; i < standings.Count; i++)
        {
            var s = standings[i];
            entries[i] = new LeaderboardEntryDto(s.UserId, s.DisplayName, s.AvatarUrl, s.Rank, s.WeeklyXp, ZoneLabel(s.Zone));
        }

        var me = standings.FirstOrDefault(s => string.Equals(s.UserId, league.MeUserId, StringComparison.Ordinal));
        var resetsInSeconds = (int)Math.Max(0d, Math.Round((league.EndsAt - clock.UtcNow).TotalSeconds));

        return league with
        {
            Entries = entries,
            TierIndex = tier.Index,
            TierName = tier.Name,
            PromoteCount = plan.PromoteCount,
            RelegateCount = plan.RelegateCount,
            NextTier = LeagueLadder.IsTop(tier) ? null : LeagueLadder.Promote(tier).Name,
            PreviousTier = LeagueLadder.IsBottom(tier) ? null : LeagueLadder.Relegate(tier).Name,
            MyRank = me?.Rank ?? 0,
            MyWeeklyXp = me?.WeeklyXp ?? 0,
            MyZone = me is null ? "safe" : ZoneLabel(me.Zone),
            ResetsInSeconds = resetsInSeconds
        };
    }

    private static LeagueMember[] ToMembers(IReadOnlyList<LeaderboardEntryDto> entries)
    {
        var members = new LeagueMember[entries.Count];
        for (var i = 0; i < entries.Count; i++)
        {
            var e = entries[i];
            members[i] = new LeagueMember(e.UserId, e.DisplayName, e.AvatarUrl, e.WeeklyXp);
        }

        return members;
    }

    private static string ZoneLabel(LeagueZone zone) => zone switch
    {
        LeagueZone.Promotion => "promotion",
        LeagueZone.Relegation => "relegation",
        _ => "safe"
    };

    private static string MovementLabel(LeagueMovement movement) => movement switch
    {
        LeagueMovement.Promoted => "promoted",
        LeagueMovement.Relegated => "relegated",
        _ => "held"
    };
}
