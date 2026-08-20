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

public interface IUserService
{
    Task<UserProfileDto> GetOrProvisionAsync(CancellationToken cancellationToken = default);
    Task<UserProfileDto> SetActiveTrackAsync(
        string trackId,
        string? expectedTrackId,
        CancellationToken cancellationToken = default);
}

public sealed class UserService(
    IUserContext userContext,
    IUserRepository users,
    IContentRepository content) : IUserService
{
    public async Task<UserProfileDto> GetOrProvisionAsync(CancellationToken cancellationToken = default)
    {
        var existing = await users.GetAsync(userContext.UserId, cancellationToken);
        if (existing is not null)
        {
            return existing;
        }

        var profile = ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
        return await users.UpsertAsync(profile, cancellationToken);
    }

    public async Task<UserProfileDto> SetActiveTrackAsync(
        string trackId,
        string? expectedTrackId,
        CancellationToken cancellationToken = default)
    {
        var normalized = trackId.Trim().ToLowerInvariant();
        var expected = string.IsNullOrWhiteSpace(expectedTrackId)
            ? null
            : expectedTrackId.Trim().ToLowerInvariant();
        var track = await content.GetTrackAsync(normalized, cancellationToken)
            ?? throw new TrackNotFoundException(normalized);

        return await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var profile = await users.GetAsync(userContext.UserId, cancellationToken)
                ?? ProfileDefaults.New(userContext.UserId, userContext.DisplayName);
            if (string.Equals(profile.ActiveTrackId, track.Id, StringComparison.OrdinalIgnoreCase))
            {
                return profile;
            }
            if (!string.Equals(profile.ActiveTrackId, expected, StringComparison.OrdinalIgnoreCase))
            {
                throw new ActiveTrackConflictException();
            }
            return await users.UpsertAsync(
                profile with { ActiveTrackId = track.Id },
                cancellationToken);
        }, cancellationToken: cancellationToken);
    }
}
