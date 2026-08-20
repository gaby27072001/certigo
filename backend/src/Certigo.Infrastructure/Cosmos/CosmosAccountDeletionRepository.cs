using System.Net;
using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;
using Certigo.Domain.Identity;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosAccountDeletionRepository(
    CosmosContext context,
    IPersonLinkedIdentityRepository personIdentities)
    : IAccountDeletionRepository
{
    private const int MaximumStateWriteAttempts = 5;

    public Task<AccountDeletionRecord?> GetAsync(
        string subjectHash,
        CancellationToken cancellationToken = default)
        => context.Attempts.ReadOrDefaultAsync<AccountDeletionRecord>(
            AccountDeletionRecord.RecordId,
            new PartitionKey(subjectHash),
            cancellationToken);

    public async Task<AccountDeletionRecord> GetOrCreateAsync(
        AccountDeletionRecord record,
        CancellationToken cancellationToken = default)
    {
        try
        {
            return await context.StartAccountDeletionAsync(record, cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            return await GetAsync(record.UserId, cancellationToken)
                ?? throw new ConcurrencyConflictException(
                    "The account deletion request was created concurrently but could not be reloaded.");
        }
    }

    public async Task<AccountIdentityKind> ResolveIdentityKindAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition(
                "SELECT TOP 1 VALUE c.id FROM c WHERE c.type = 'credential' AND c.userId = @userId")
            .WithParameter("@userId", subjectUserId);
        using var iterator = context.Users.GetItemQueryIterator<string>(query);
        while (iterator.HasMoreResults)
        {
            var page = await iterator.ReadNextAsync(cancellationToken);
            if (page.Any())
            {
                return AccountIdentityKind.Local;
            }
        }

        // Absence of a Certigo-managed credential means the account is brokered
        // by Entra. Never infer "development" from the identifier shape: doing so
        // could silently skip identity deletion for a valid non-GUID subject.
        return AccountIdentityKind.External;
    }

    public Task<AccountDeletionRecord> MarkStepCompletedAsync(
        string subjectHash,
        string step,
        DateTimeOffset updatedAt,
        CancellationToken cancellationToken = default)
        => UpdateStateAsync(
            subjectHash,
            current =>
            {
                if (current.Status == AccountDeletionRecordStatus.Completed)
                {
                    return current;
                }

                if (current.HasCompleted(step))
                {
                    return current;
                }

                return current with
                {
                    CompletedSteps = current.CompletedSteps.Append(step).ToArray(),
                    UpdatedAt = updatedAt,
                    FailureCode = null,
                    NextRetryAt = null,
                };
            },
            cancellationToken);

    public Task<AccountDeletionRecord> MarkFailureAsync(
        string subjectHash,
        string failureCode,
        DateTimeOffset updatedAt,
        DateTimeOffset nextRetryAt,
        CancellationToken cancellationToken = default)
        => UpdateStateAsync(
            subjectHash,
            current => current.Status == AccountDeletionRecordStatus.Completed
                ? current
                : current with
                {
                    UpdatedAt = updatedAt,
                    FailureCode = failureCode,
                    AttemptCount = current.AttemptCount + 1,
                    NextRetryAt = nextRetryAt,
                },
            cancellationToken);

    public async Task<AccountDeletionRecord> MarkCompletedAsync(
        string subjectHash,
        DateTimeOffset completedAt,
        int retentionSeconds,
        CancellationToken cancellationToken = default)
        => await context.CompleteAccountDeletionAsync(
            subjectHash,
            completedAt,
            retentionSeconds,
            cancellationToken);

    public async Task ReconcileDataAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        var subjectHash = AccountDeletionSubject.Hash(subjectUserId);
        if (await context.HasActiveAccountWriteLeasesAsync(subjectHash, cancellationToken))
        {
            throw new AccountDeletionStepException(
                "account-mutations-draining",
                new InvalidOperationException(
                    "Account deletion is waiting for admitted mutations to finish."));
        }

        try
        {
            var barriers = await context.GetAccountWriteBarriersAsync(
                subjectHash,
                cancellationToken);
            foreach (var sessionToken in SessionTokens(
                         barriers,
                         CosmosContainers.Friends))
            {
                await DeleteFriendsAsync(subjectUserId, sessionToken, cancellationToken);
            }
            foreach (var sessionToken in SessionTokens(
                         barriers,
                         CosmosContainers.Leaderboard))
            {
                await DeleteLeaderboardEntriesAsync(
                    subjectUserId,
                    sessionToken,
                    cancellationToken);
            }
            foreach (var sessionToken in SessionTokens(
                         barriers,
                         CosmosContainers.Progress))
            {
                await DeletePartitionAsync(
                    context.Progress,
                    subjectUserId,
                    sessionToken,
                    cancellationToken);
            }
            foreach (var sessionToken in SessionTokens(
                         barriers,
                         CosmosContainers.Attempts))
            {
                await DeletePartitionAsync(
                    context.Attempts,
                    subjectUserId,
                    sessionToken,
                    cancellationToken);
            }
            foreach (var sessionToken in SessionTokens(
                         barriers,
                         CosmosContainers.Events))
            {
                await DeletePartitionAsync(
                    context.Events,
                    subjectUserId,
                    sessionToken,
                    cancellationToken);
            }
            foreach (var sessionToken in SessionTokens(
                         barriers,
                         CosmosContainers.Economy))
            {
                await DeletePartitionAsync(
                    context.Economy,
                    subjectUserId,
                    sessionToken,
                    cancellationToken);
            }
            foreach (var sessionToken in SessionTokens(
                         barriers,
                         CosmosContainers.Users))
            {
                await DeleteProfileWithSessionAsync(
                    subjectUserId,
                    sessionToken,
                    cancellationToken);
                await DeleteCredentialsWithSessionAsync(
                    subjectUserId,
                    sessionToken,
                    cancellationToken);
            }
        }
        catch (CosmosException ex)
        {
            throw new AccountDeletionStepException("reconciliation-delete-failed", ex);
        }
    }

    public async Task DeleteSocialDataAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await DeleteFriendsAsync(
                subjectUserId,
                sessionToken: null,
                cancellationToken);
            await DeleteLeaderboardEntriesAsync(
                subjectUserId,
                sessionToken: null,
                cancellationToken);
        }
        catch (CosmosException ex)
        {
            throw new AccountDeletionStepException("social-data-delete-failed", ex);
        }
    }

    public async Task DeleteLearningDataAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await DeletePartitionAsync(
                context.Progress,
                subjectUserId,
                sessionToken: null,
                cancellationToken);
            await DeletePartitionAsync(
                context.Attempts,
                subjectUserId,
                sessionToken: null,
                cancellationToken);
            await DeletePartitionAsync(
                context.Events,
                subjectUserId,
                sessionToken: null,
                cancellationToken);
        }
        catch (CosmosException ex)
        {
            throw new AccountDeletionStepException("learning-data-delete-failed", ex);
        }
    }

    public async Task DeleteEconomyDataAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await DeletePartitionAsync(
                context.Economy,
                subjectUserId,
                sessionToken: null,
                cancellationToken);
        }
        catch (CosmosException ex)
        {
            throw new AccountDeletionStepException("economy-data-delete-failed", ex);
        }
    }

    public async Task DeleteProfileAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await DeleteProfileWithSessionAsync(
                subjectUserId,
                sessionToken: null,
                cancellationToken);
        }
        catch (CosmosException ex)
        {
            throw new AccountDeletionStepException("profile-delete-failed", ex);
        }
    }

    public async Task DeleteCredentialsAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await DeleteCredentialsWithSessionAsync(
                subjectUserId,
                sessionToken: null,
                cancellationToken);
        }
        catch (CosmosException ex)
        {
            throw new AccountDeletionStepException("credential-delete-failed", ex);
        }
    }

    public async Task DeleteLinkedIdentityDataAsync(
        string subjectUserId,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await personIdentities.CleanupForAccountDeletionAsync(
                subjectUserId,
                revokedAt,
                cancellationToken);
        }
        catch (Exception ex) when (
            ex is CosmosException
                or ConcurrencyConflictException
                or PersonIdentityIntegrityException
                or IdentityHashCollisionException
                or InvalidIdentityLocatorException)
        {
            throw new AccountDeletionStepException(
                "linked-identity-delete-failed",
                ex);
        }
    }

    private async Task<AccountDeletionRecord> UpdateStateAsync(
        string subjectHash,
        Func<AccountDeletionRecord, AccountDeletionRecord> update,
        CancellationToken cancellationToken)
    {
        var partitionKey = new PartitionKey(subjectHash);
        for (var attempt = 1; attempt <= MaximumStateWriteAttempts; attempt++)
        {
            var current = await GetAsync(subjectHash, cancellationToken)
                ?? throw new InvalidOperationException("The account deletion state no longer exists.");
            var candidate = update(current);
            if (ReferenceEquals(candidate, current))
            {
                return current;
            }

            try
            {
                var response = await context.Attempts.ReplaceItemAsync(
                    candidate,
                    AccountDeletionRecord.RecordId,
                    partitionKey,
                    new ItemRequestOptions { IfMatchEtag = current.ETag },
                    cancellationToken);
                return response.Resource;
            }
            catch (CosmosException ex) when (
                attempt < MaximumStateWriteAttempts
                && ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                // A concurrent retry advanced the state; re-read and re-apply.
            }
        }

        throw new ConcurrencyConflictException(
            "The account deletion state changed repeatedly; retry the request.");
    }

    private async Task DeleteFriendsAsync(
        string subjectUserId,
        string? sessionToken,
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT c.id, c.userId FROM c WHERE c.userId = @userId OR c.friendUserId = @userId")
            .WithParameter("@userId", subjectUserId);
        using var iterator = context.Friends.GetItemQueryIterator<PartitionedDocument>(
            query,
            requestOptions: new QueryRequestOptions { SessionToken = sessionToken });
        var documents = new List<PartitionedDocument>();
        while (iterator.HasMoreResults)
        {
            documents.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        foreach (var document in documents)
        {
            await DeleteIfExistsAsync(
                context.Friends,
                document.Id,
                new PartitionKey(document.UserId),
                sessionToken,
                cancellationToken);
        }
    }

    private async Task DeleteLeaderboardEntriesAsync(
        string subjectUserId,
        string? sessionToken,
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT c.id, c.periodLeagueId FROM c WHERE c.userId = @userId")
            .WithParameter("@userId", subjectUserId);
        using var iterator = context.Leaderboard.GetItemQueryIterator<LeaderboardDocument>(
            query,
            requestOptions: new QueryRequestOptions { SessionToken = sessionToken });
        var documents = new List<LeaderboardDocument>();
        while (iterator.HasMoreResults)
        {
            documents.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        foreach (var document in documents)
        {
            await DeleteIfExistsAsync(
                context.Leaderboard,
                document.Id,
                new PartitionKey(document.PeriodLeagueId),
                sessionToken,
                cancellationToken);
        }
    }

    private static async Task DeletePartitionAsync(
        Container container,
        string subjectUserId,
        string? sessionToken,
        CancellationToken cancellationToken)
    {
        var partitionKey = new PartitionKey(subjectUserId);
        using var iterator = container.GetItemQueryIterator<string>(
            new QueryDefinition("SELECT VALUE c.id FROM c"),
            requestOptions: new QueryRequestOptions
            {
                PartitionKey = partitionKey,
                SessionToken = sessionToken,
            });
        var ids = new List<string>();
        while (iterator.HasMoreResults)
        {
            ids.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        foreach (var id in ids)
        {
            await DeleteIfExistsAsync(
                container,
                id,
                partitionKey,
                sessionToken,
                cancellationToken);
        }
    }

    private static async Task DeleteIfExistsAsync(
        Container container,
        string id,
        PartitionKey partitionKey,
        string? sessionToken,
        CancellationToken cancellationToken)
    {
        try
        {
            await container.DeleteItemAsync<object>(
                id,
                partitionKey,
                new ItemRequestOptions { SessionToken = sessionToken },
                cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            // Every deletion step is replay-safe.
        }
    }

    private async Task DeleteProfileWithSessionAsync(
        string subjectUserId,
        string? sessionToken,
        CancellationToken cancellationToken)
        => await DeleteIfExistsAsync(
            context.Users,
            subjectUserId,
            new PartitionKey(subjectUserId),
            sessionToken,
            cancellationToken);

    private async Task DeleteCredentialsWithSessionAsync(
        string subjectUserId,
        string? sessionToken,
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT c.id FROM c WHERE c.type = 'credential' AND c.userId = @userId")
            .WithParameter("@userId", subjectUserId);
        using var iterator = context.Users.GetItemQueryIterator<PartitionedDocument>(
            query,
            requestOptions: new QueryRequestOptions { SessionToken = sessionToken });
        var documents = new List<PartitionedDocument>();
        while (iterator.HasMoreResults)
        {
            documents.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        foreach (var document in documents)
        {
            await DeleteIfExistsAsync(
                context.Users,
                document.Id,
                new PartitionKey(document.Id),
                sessionToken,
                cancellationToken);
        }
    }

    private static IEnumerable<string?> SessionTokens(
        IReadOnlyList<CosmosContext.AccountWriteBarrier> barriers,
        string containerName)
        => new string?[] { null }.Concat(
            barriers
                .Where(barrier => string.Equals(
                    barrier.ContainerName,
                    containerName,
                    StringComparison.Ordinal))
                .Select(barrier => barrier.SessionToken)
                .Distinct(StringComparer.Ordinal));

    private sealed record PartitionedDocument(string Id, string UserId);
    private sealed record LeaderboardDocument(string Id, string PeriodLeagueId);
}
