using Microsoft.Azure.Cosmos;
using System.Net;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosUserRepository(CosmosContext context) : IUserRepository
{
    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
        => context.Users.ReadOrDefaultAsync<UserProfileDto>(userId, new PartitionKey(userId), cancellationToken);

    public async Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default)
    {
        // Cross-partition lookup; rare (only on a friend-add) so the fan-out cost
        // is acceptable. Handles are slugified at provisioning time.
        var query = new QueryDefinition("SELECT TOP 1 * FROM c WHERE c.handle = @handle")
            .WithParameter("@handle", handle);
        using var iterator = context.Users.GetItemQueryIterator<UserProfileDto>(query);
        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            var match = page.FirstOrDefault();
            if (match is not null)
            {
                return match;
            }
        }

        return null;
    }

    public async Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default)
    {
        // Honour the optimistic-concurrency token when present so two concurrent
        // economy mutations (e.g. a quiz submit and a shop purchase) can't clobber
        // each other; a 412 surfaces as a domain-level ConcurrencyConflictException.
        try
        {
            var response = string.IsNullOrEmpty(profile.ETag)
                ? await context.Users.CreateItemAsync(
                    profile,
                    new PartitionKey(profile.Id),
                    cancellationToken: cancellationToken)
                : await context.Users.ReplaceItemAsync(
                    profile,
                    profile.Id,
                    new PartitionKey(profile.Id),
                    new ItemRequestOptions { IfMatchEtag = profile.ETag },
                    cancellationToken);
            return response.Resource;
        }
        catch (CosmosException ex) when (
            ex.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException($"User profile '{profile.Id}' was modified concurrently.");
        }
        catch (CosmosException ex) when (
            ex.StatusCode is HttpStatusCode.BadRequest
                or HttpStatusCode.Unauthorized
                or HttpStatusCode.Forbidden
                or HttpStatusCode.RequestEntityTooLarge)
        {
            throw new DefinitivePersistenceException(
                $"User profile '{profile.Id}' was rejected before commit.",
                ex);
        }
    }
}
