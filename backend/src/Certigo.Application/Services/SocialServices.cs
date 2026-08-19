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
            ? throw new ActiveTrackRequiredException()
            : profile.ActiveTrackId;
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

public interface IFriendService
{
    Task<FriendListDto> ListAsync(CancellationToken cancellationToken = default);
    Task<FriendActionResultDto> AddByHandleAsync(string handle, CancellationToken cancellationToken = default);
    Task<FriendActionResultDto> RemoveAsync(string friendUserId, CancellationToken cancellationToken = default);
    Task<FriendLeaderboardDto> LeaderboardAsync(CancellationToken cancellationToken = default);
}

// Social graph + friend leaderboard (plan §3.8) — the core virality loop.
// Friendships are mutual: adding writes both directed edges so each side can
// list from its own partition. Adds are idempotent.
public sealed class FriendService(
    IUserContext userContext,
    IClock clock,
    IUserRepository users,
    IFriendRepository friends,
    IEventRepository events,
    IAccountDeletionAccessGuard accountDeletionGuard) : IFriendService
{
    public async Task<FriendListDto> ListAsync(CancellationToken cancellationToken = default)
    {
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        return await BuildListAsync(edges, cancellationToken);
    }

    public async Task<FriendActionResultDto> AddByHandleAsync(string handle, CancellationToken cancellationToken = default)
    {
        var normalized = (handle ?? string.Empty).Trim().TrimStart('@').ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return await FailAsync("invalid_handle", cancellationToken);
        }

        var target = await users.FindByHandleAsync(normalized, cancellationToken);
        if (target is null)
        {
            return await FailAsync("not_found", cancellationToken);
        }

        if (string.Equals(target.Id, userContext.UserId, StringComparison.Ordinal))
        {
            return await FailAsync("self", cancellationToken);
        }

        if (await accountDeletionGuard.IsBlockedAsync(target.Id, cancellationToken))
        {
            return await FailAsync("account_unavailable", cancellationToken);
        }

        var now = clock.UtcNow;
        var existing = await friends.GetAsync(userContext.UserId, target.Id, cancellationToken);
        if (existing is null)
        {
            if (await accountDeletionGuard.IsBlockedAsync(target.Id, cancellationToken))
            {
                return await FailAsync("account_unavailable", cancellationToken);
            }

            await friends.UpsertAsync(new FriendEdge($"{userContext.UserId}:{target.Id}", userContext.UserId, target.Id, now), cancellationToken);
            await friends.UpsertAsync(new FriendEdge($"{target.Id}:{userContext.UserId}", target.Id, userContext.UserId, now), cancellationToken);
            await events.AddAsync(new LearningEvent(Guid.NewGuid().ToString("n"), userContext.UserId, "friend.added", now, new { friendUserId = target.Id }), cancellationToken);
        }

        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        var list = await BuildListAsync(edges, cancellationToken);
        return new FriendActionResultDto(true, target.Id, null, list);
    }

    public async Task<FriendActionResultDto> RemoveAsync(string friendUserId, CancellationToken cancellationToken = default)
    {
        await friends.RemoveAsync(userContext.UserId, friendUserId, cancellationToken);
        await friends.RemoveAsync(friendUserId, userContext.UserId, cancellationToken);
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        var list = await BuildListAsync(edges, cancellationToken);
        return new FriendActionResultDto(true, friendUserId, null, list);
    }

    public async Task<FriendLeaderboardDto> LeaderboardAsync(CancellationToken cancellationToken = default)
    {
        var me = await users.GetAsync(userContext.UserId, cancellationToken)
            ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);

        var profiles = new List<UserProfileDto> { me };
        foreach (var edge in edges)
        {
            var friend = await users.GetAsync(edge.FriendUserId, cancellationToken);
            if (friend is not null)
            {
                profiles.Add(friend);
            }
        }

        var entries = profiles
            .GroupBy(p => p.Id, StringComparer.Ordinal)
            .Select(g => g.First())
            .OrderByDescending(p => p.Xp)
            .ThenBy(p => p.DisplayName, StringComparer.OrdinalIgnoreCase)
            .Select((p, i) => new LeaderboardEntryDto(p.Id, p.DisplayName, p.AvatarUrl, i + 1, p.Xp))
            .ToArray();

        return new FriendLeaderboardDto(userContext.UserId, entries);
    }

    private async Task<FriendListDto> BuildListAsync(IReadOnlyList<FriendEdge> edges, CancellationToken cancellationToken)
    {
        var result = new List<FriendDto>();
        foreach (var edge in edges.OrderBy(e => e.CreatedAt))
        {
            var profile = await users.GetAsync(edge.FriendUserId, cancellationToken);
            if (profile is null)
            {
                continue;
            }

            result.Add(new FriendDto(
                profile.Id,
                profile.DisplayName,
                profile.Handle,
                profile.AvatarUrl,
                profile.Level,
                profile.StreakDays,
                profile.Xp,
                edge.CreatedAt));
        }

        return new FriendListDto(result.Count, result);
    }

    private async Task<FriendActionResultDto> FailAsync(string error, CancellationToken cancellationToken)
    {
        var edges = await friends.ListAsync(userContext.UserId, cancellationToken);
        var list = await BuildListAsync(edges, cancellationToken);
        return new FriendActionResultDto(false, null, error, list);
    }
}
