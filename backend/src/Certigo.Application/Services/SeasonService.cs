using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Gamification;
using Certigo.Domain.Notifications;

namespace Certigo.Application.Services;

public interface ISeasonService
{
    Task<SeasonDto> GetCurrentAsync(CancellationToken cancellationToken = default);
    Task<ClaimSeasonResultDto> ClaimAsync(ClaimSeasonRequest request, CancellationToken cancellationToken = default);
}

public sealed class SeasonService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IEventRepository events) : ISeasonService
{
    public async Task<SeasonDto> GetCurrentAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var season = SeasonEngine.ForDate(today);
        var signals = MonthlySignalsFor(profile, today);
        var badges = profile.SeasonBadges ?? new List<string>();

        return ToDto(season, signals, profile.Gems, badges);
    }

    public async Task<ClaimSeasonResultDto> ClaimAsync(ClaimSeasonRequest request, CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var season = SeasonEngine.ForDate(today);
        var badgeId = season.Challenge.BadgeId;
        var badges = profile.SeasonBadges ?? new List<string>();

        // A learner can only claim the season the request actually targets, and
        // only while it is the current month. Claiming a past or future season is
        // rejected rather than silently redirected to the active one.
        if (!string.Equals(request.SeasonId, season.Id, StringComparison.Ordinal))
        {
            return new ClaimSeasonResultDto(false, request.SeasonId, null, 0, profile.Gems, false, "wrongSeason");
        }

        // Already earned this season's badge: idempotent no-op so a retried claim
        // never double-awards gems.
        if (badges.Contains(badgeId))
        {
            return new ClaimSeasonResultDto(true, season.Id, badgeId, 0, profile.Gems, true, null);
        }

        var signals = MonthlySignalsFor(profile, today);
        var status = SeasonEngine.Evaluate(season, signals);
        if (!status.Completed)
        {
            return new ClaimSeasonResultDto(false, season.Id, null, 0, profile.Gems, false, "notCompleted");
        }

        var updatedBadges = new List<string>(badges) { badgeId };
        var updated = profile with
        {
            Gems = profile.Gems + season.Challenge.RewardGems,
            SeasonBadges = updatedBadges,
        };
        await users.UpsertAsync(updated, cancellationToken);

        var result = new ClaimSeasonResultDto(true, season.Id, badgeId, season.Challenge.RewardGems, updated.Gems, true, null);
        await events.AddAsync(new LearningEvent(
            Guid.NewGuid().ToString("n"),
            userContext.UserId,
            "season.claimed",
            clock.UtcNow,
            result), cancellationToken);

        return result;
    }

    // Monthly counters reset at the month boundary. When the profile's recorded
    // month anchor is not the current month the learner has no activity yet, so
    // signals are empty (stale values from a previous month are ignored).
    private static SeasonSignals MonthlySignalsFor(UserProfileDto profile, DateOnly today)
    {
        var anchor = new DateOnly(today.Year, today.Month, 1);
        if (profile.MonthlyAnchor != anchor)
        {
            return SeasonSignals.Empty;
        }

        return new SeasonSignals(
            profile.MonthlyXpEarned,
            profile.MonthlyLessonsCompleted,
            profile.MonthlyPerfectLessons);
    }

    private static SeasonDto ToDto(Season season, SeasonSignals signals, int gems, IReadOnlyList<string> badges)
    {
        var status = SeasonEngine.Evaluate(season, signals);
        var claimed = badges.Contains(season.Challenge.BadgeId);
        return new SeasonDto(
            season.Id,
            season.Year,
            season.Month,
            season.Theme,
            season.Tagline,
            season.Mascot,
            season.Accent,
            season.Challenge.BadgeId,
            season.Challenge.BadgeTitle,
            gems,
            badges.Count,
            new SeasonChallengeDto(
                season.Challenge.Kind.ToString(),
                season.Challenge.Title,
                season.Challenge.Target,
                status.Current,
                season.Challenge.RewardGems,
                status.Completed,
                claimed,
                status.Completed && !claimed));
    }
}
