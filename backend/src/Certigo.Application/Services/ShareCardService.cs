using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Social;

namespace Certigo.Application.Services;

public interface IShareCardService
{
    Task<ShareCardDto> GetDailyAsync(CancellationToken cancellationToken = default);
}

// Builds the server-authoritative payload for the 2-tap daily score share
// (plan §3.10): the numbers a client renders into a story card, plus a stable
// referral code and per-day share id for deep links and K-factor tracking.
public sealed class ShareCardService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IPathService path) : IShareCardService
{
    public async Task<ShareCardDto> GetDailyAsync(CancellationToken cancellationToken = default)
    {
        var profile = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);

        var today = DateOnly.FromDateTime(clock.UtcNow.UtcDateTime);
        var dailyXp = profile.DailyXpDate == today ? profile.DailyXpEarned : 0;
        var goalMet = profile.DailyGoalXp > 0 && dailyXp >= profile.DailyGoalXp;

        var trackId = string.IsNullOrWhiteSpace(profile.ActiveTrackId)
            ? ProfileDefaults.DefaultTrackId
            : profile.ActiveTrackId!;
        var pathDto = await path.GetPathAsync(trackId, cancellationToken);

        var referral = ShareCodec.ReferralCode(profile.Id);
        var shareId = ShareCodec.DailyShareId(profile.Id, today);
        var mascot = goalMet && profile.StreakDays > 0 ? "Nimbus" : "Pip";
        var headline = profile.StreakDays > 0
            ? $"{profile.StreakDays} jours de série 🔥"
            : "Ma préparation a commencé";
        var caption =
            $"J'en suis à {pathDto.ReadinessScore}% de préparation {pathDto.Exam} sur Certigo ! "
            + $"Rejoins-moi avec le code {referral} 🚀";

        return new ShareCardDto(
            shareId,
            profile.DisplayName,
            profile.Handle,
            profile.StreakDays,
            profile.Level,
            dailyXp,
            profile.DailyGoalXp,
            goalMet,
            pathDto.ReadinessScore,
            pathDto.Exam,
            mascot,
            headline,
            caption,
            referral,
            clock.UtcNow);
    }
}
