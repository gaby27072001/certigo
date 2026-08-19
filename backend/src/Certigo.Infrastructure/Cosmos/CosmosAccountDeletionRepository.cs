using System.Net;
using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosAccountDeletionRepository(CosmosContext context)
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
            var response = await context.Attempts.CreateItemAsync(
                record,
                new PartitionKey(record.UserId),
                cancellationToken: cancellationToken);
            return response.Resource;
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

    public Task<AccountDeletionRecord> MarkCompletedAsync(
        string subjectHash,
        DateTimeOffset completedAt,
        int retentionSeconds,
        CancellationToken cancellationToken = default)
        => UpdateStateAsync(
            subjectHash,
            current => current.Status == AccountDeletionRecordStatus.Completed
                ? current
                : current with
                {
                    SubjectUserId = null,
                    Status = AccountDeletionRecordStatus.Completed,
                    UpdatedAt = completedAt,
                    CompletedAt = completedAt,
                    FailureCode = null,
                    NextRetryAt = null,
                    Ttl = retentionSeconds,
                },
            cancellationToken);

    public async Task DeleteSocialDataAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await DeleteFriendsAsync(subjectUserId, cancellationToken);
            await DeleteLeaderboardEntriesAsync(subjectUserId, cancellationToken);
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
            await DeletePartitionAsync(context.Progress, subjectUserId, cancellationToken);
            await DeletePartitionAsync(context.Attempts, subjectUserId, cancellationToken);
            await DeletePartitionAsync(context.Events, subjectUserId, cancellationToken);
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
            await DeletePartitionAsync(context.Economy, subjectUserId, cancellationToken);
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
            await DeleteIfExistsAsync(
                context.Users,
                subjectUserId,
                new PartitionKey(subjectUserId),
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
            var query = new QueryDefinition(
                    "SELECT c.id FROM c WHERE c.type = 'credential' AND c.userId = @userId")
                .WithParameter("@userId", subjectUserId);
            using var iterator = context.Users.GetItemQueryIterator<PartitionedDocument>(query);
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
                    cancellationToken);
            }
        }
        catch (CosmosException ex)
        {
            throw new AccountDeletionStepException("credential-delete-failed", ex);
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
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT c.id, c.userId FROM c WHERE c.userId = @userId OR c.friendUserId = @userId")
            .WithParameter("@userId", subjectUserId);
        using var iterator = context.Friends.GetItemQueryIterator<PartitionedDocument>(query);
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
                cancellationToken);
        }
    }

    private async Task DeleteLeaderboardEntriesAsync(
        string subjectUserId,
        CancellationToken cancellationToken)
    {
        var query = new QueryDefinition(
                "SELECT c.id, c.periodLeagueId FROM c WHERE c.userId = @userId")
            .WithParameter("@userId", subjectUserId);
        using var iterator = context.Leaderboard.GetItemQueryIterator<LeaderboardDocument>(query);
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
                cancellationToken);
        }
    }

    private static async Task DeletePartitionAsync(
        Container container,
        string subjectUserId,
        CancellationToken cancellationToken)
    {
        var partitionKey = new PartitionKey(subjectUserId);
        using var iterator = container.GetItemQueryIterator<string>(
            new QueryDefinition("SELECT VALUE c.id FROM c"),
            requestOptions: new QueryRequestOptions { PartitionKey = partitionKey });
        var ids = new List<string>();
        while (iterator.HasMoreResults)
        {
            ids.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        foreach (var id in ids)
        {
            await DeleteIfExistsAsync(container, id, partitionKey, cancellationToken);
        }
    }

    private static async Task DeleteIfExistsAsync(
        Container container,
        string id,
        PartitionKey partitionKey,
        CancellationToken cancellationToken)
    {
        try
        {
            await container.DeleteItemAsync<object>(
                id,
                partitionKey,
                cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
        {
            // Every deletion step is replay-safe.
        }
    }

    private sealed record PartitionedDocument(string Id, string UserId);
    private sealed record LeaderboardDocument(string Id, string PeriodLeagueId);
}
