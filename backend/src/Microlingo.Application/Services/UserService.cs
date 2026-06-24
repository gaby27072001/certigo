using System.Text.Json;
using Microlingo.Application.Abstractions;
using Microlingo.Application.Dtos;
using Microlingo.Domain.Content;
using Microlingo.Domain.Exam;
using Microlingo.Domain.Gamification;
using Microlingo.Domain.Integrity;
using Microlingo.Domain.Notifications;
using Microlingo.Domain.Progress;
using Microlingo.Domain.Readiness;
using Microlingo.Domain.Recommendation;
using Microlingo.Domain.Social;
using Microlingo.Domain.Tutor;

namespace Microlingo.Application.Services;

public interface IUserService
{
    Task<UserProfileDto> GetOrProvisionAsync(CancellationToken cancellationToken = default);
}

public sealed class UserService(IUserContext userContext, IUserRepository users) : IUserService
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
}
