using System.Net;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosContext(CosmosClient client, string? databaseName = null)
{
    private const string WriteGuardId = "account-write-guard";
    private const string WriteGuardType = "account-write-guard";
    private const string WriteLeaseType = "account-write-lease";
    private const string ActiveState = "active";
    private const string DeletingState = "deleting";
    private const string CompletedState = "completed";
    private const string CommittedLeaseState = "committed";
    private const int MaximumLifecycleAttempts = 5;
    private const int AcquiredWriteLeaseTtlSeconds = 3_600;
    private const int DispatchedWriteLeaseTtlSeconds = -1;
    private const int CommittedWriteLeaseTtlSeconds = 2_592_000;

    private readonly Database _database = client.GetDatabase(string.IsNullOrWhiteSpace(databaseName)
        ? CosmosContainers.DatabaseName
        : databaseName);

    public Container Users => _database.GetContainer(CosmosContainers.Users);
    public Container Content => _database.GetContainer(CosmosContainers.Content);
    public Container ContentPublic => _database.GetContainer(CosmosContainers.ContentPublic);
    public Container ContentPrivate => _database.GetContainer(CosmosContainers.ContentPrivate);
    public Container ContentControl => _database.GetContainer(CosmosContainers.ContentControl);
    public Container Progress => _database.GetContainer(CosmosContainers.Progress);
    public Container Attempts => _database.GetContainer(CosmosContainers.Attempts);
    public Container Events => _database.GetContainer(CosmosContainers.Events);
    public Container Leaderboard => _database.GetContainer(CosmosContainers.Leaderboard);
    public Container Economy => _database.GetContainer(CosmosContainers.Economy);
    public Container Friends => _database.GetContainer(CosmosContainers.Friends);
    public Container Organizations => _database.GetContainer(CosmosContainers.Organizations);
    public Container EnterpriseMetricReceipts =>
        _database.GetContainer(CosmosContainers.EnterpriseMetricReceipts);

    internal async Task<AccountWriteLease> AcquireAccountWriteLeaseAsync(
        string userId,
        CancellationToken cancellationToken = default)
    {
        var subjectHash = AccountDeletionSubject.Hash(userId);
        var partitionKey = new PartitionKey(subjectHash);
        for (var attempt = 1; attempt <= MaximumLifecycleAttempts; attempt++)
        {
            var guard = await Attempts.ReadOrDefaultAsync<AccountWriteGuardRecord>(
                WriteGuardId,
                partitionKey,
                cancellationToken);
            if (guard is not null && guard.State != ActiveState)
            {
                throw new AccountDeletionInProgressException();
            }

            var now = DateTimeOffset.UtcNow;
            var lease = new AccountWriteLeaseRecord(
                $"account-write-lease::{Guid.NewGuid():N}",
                subjectHash,
                WriteLeaseType,
                ActiveState,
                now,
                null,
                null,
                AcquiredWriteLeaseTtlSeconds);
            var batch = Attempts.CreateTransactionalBatch(partitionKey);
            if (guard is null)
            {
                batch.CreateItem(new AccountWriteGuardRecord(
                    WriteGuardId,
                    subjectHash,
                    WriteGuardType,
                    ActiveState,
                    now,
                    -1));
            }
            else
            {
                batch.ReplaceItem(
                    WriteGuardId,
                    guard with { UpdatedAt = now },
                    new TransactionalBatchItemRequestOptions { IfMatchEtag = guard.ETag });
            }
            batch.CreateItem(lease);

            using var response = await batch.ExecuteAsync(cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                return new AccountWriteLease(Attempts, lease, partitionKey);
            }
            if (response.StatusCode is not (
                    HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
                || attempt == MaximumLifecycleAttempts)
            {
                throw new CosmosException(
                    "Could not acquire the account write lease.",
                    response.StatusCode,
                    0,
                    response.ActivityId,
                    response.RequestCharge);
            }
        }

        throw new ConcurrencyConflictException("Could not acquire the account write lease.");
    }

    internal async Task<AccountDeletionRecord> StartAccountDeletionAsync(
        AccountDeletionRecord record,
        CancellationToken cancellationToken = default)
    {
        var subjectHash = record.UserId;
        var partitionKey = new PartitionKey(subjectHash);
        for (var attempt = 1; attempt <= MaximumLifecycleAttempts; attempt++)
        {
            var existingDeletion = await Attempts.ReadOrDefaultAsync<AccountDeletionRecord>(
                AccountDeletionRecord.RecordId,
                partitionKey,
                cancellationToken);
            if (existingDeletion is not null)
            {
                return existingDeletion;
            }

            var guard = await Attempts.ReadOrDefaultAsync<AccountWriteGuardRecord>(
                WriteGuardId,
                partitionKey,
                cancellationToken);
            if (guard?.State == CompletedState)
            {
                throw new AccountDeletionInProgressException();
            }

            var now = DateTimeOffset.UtcNow;
            var batch = Attempts.CreateTransactionalBatch(partitionKey);
            if (guard is null)
            {
                batch.CreateItem(new AccountWriteGuardRecord(
                    WriteGuardId,
                    subjectHash,
                    WriteGuardType,
                    DeletingState,
                    now,
                    -1));
            }
            else
            {
                batch.ReplaceItem(
                    WriteGuardId,
                    guard with { State = DeletingState, UpdatedAt = now },
                    new TransactionalBatchItemRequestOptions { IfMatchEtag = guard.ETag });
            }
            batch.CreateItem(record);

            using var response = await batch.ExecuteAsync(cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                return await Attempts.ReadOrDefaultAsync<AccountDeletionRecord>(
                    AccountDeletionRecord.RecordId,
                    partitionKey,
                    cancellationToken)
                    ?? throw new InvalidOperationException(
                        "The account deletion state was committed but could not be reloaded.");
            }
            if (response.StatusCode is not (
                    HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
                || attempt == MaximumLifecycleAttempts)
            {
                throw new CosmosException(
                    "Could not start account deletion.",
                    response.StatusCode,
                    0,
                    response.ActivityId,
                    response.RequestCharge);
            }
        }

        throw new ConcurrencyConflictException("Could not start account deletion.");
    }

    internal async Task<bool> HasActiveAccountWriteLeasesAsync(
        string subjectHash,
        CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition(
                "SELECT TOP 1 VALUE c.id FROM c WHERE c.type = @type AND c.state = @state")
            .WithParameter("@type", WriteLeaseType)
            .WithParameter("@state", ActiveState);
        using var iterator = Attempts.GetItemQueryIterator<string>(
            query,
            requestOptions: new QueryRequestOptions
            {
                PartitionKey = new PartitionKey(subjectHash),
                MaxItemCount = 1,
            });
        while (iterator.HasMoreResults)
        {
            if ((await iterator.ReadNextAsync(cancellationToken)).Any())
            {
                return true;
            }
        }
        return false;
    }

    internal async Task<IReadOnlyList<AccountWriteBarrier>> GetAccountWriteBarriersAsync(
        string subjectHash,
        CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition(
                "SELECT c.containerName, c.sessionToken FROM c "
                + "WHERE c.type = @type AND c.state = @state")
            .WithParameter("@type", WriteLeaseType)
            .WithParameter("@state", CommittedLeaseState);
        using var iterator = Attempts.GetItemQueryIterator<AccountWriteBarrier>(
            query,
            requestOptions: new QueryRequestOptions
            {
                PartitionKey = new PartitionKey(subjectHash),
            });
        var barriers = new List<AccountWriteBarrier>();
        while (iterator.HasMoreResults)
        {
            barriers.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }
        return barriers;
    }

    internal async Task<AccountDeletionRecord> CompleteAccountDeletionAsync(
        string subjectHash,
        DateTimeOffset completedAt,
        int retentionSeconds,
        CancellationToken cancellationToken = default)
    {
        var partitionKey = new PartitionKey(subjectHash);
        for (var attempt = 1; attempt <= MaximumLifecycleAttempts; attempt++)
        {
            var guard = await Attempts.ReadOrDefaultAsync<AccountWriteGuardRecord>(
                WriteGuardId,
                partitionKey,
                cancellationToken)
                ?? throw new InvalidOperationException("The account write guard was not found.");
            var deletion = await Attempts.ReadOrDefaultAsync<AccountDeletionRecord>(
                AccountDeletionRecord.RecordId,
                partitionKey,
                cancellationToken)
                ?? throw new InvalidOperationException("The account deletion state was not found.");
            if (deletion.Status == AccountDeletionRecordStatus.Completed
                && guard.State == CompletedState)
            {
                return deletion;
            }

            var completedDeletion = deletion with
            {
                SubjectUserId = null,
                Status = AccountDeletionRecordStatus.Completed,
                UpdatedAt = completedAt,
                CompletedAt = completedAt,
                FailureCode = null,
                NextRetryAt = null,
                Ttl = retentionSeconds,
            };
            var completedGuard = guard with
            {
                State = CompletedState,
                UpdatedAt = completedAt,
                Ttl = retentionSeconds,
            };
            var batch = Attempts.CreateTransactionalBatch(partitionKey)
                .ReplaceItem(
                    AccountDeletionRecord.RecordId,
                    completedDeletion,
                    new TransactionalBatchItemRequestOptions
                    {
                        IfMatchEtag = deletion.ETag,
                    })
                .ReplaceItem(
                    WriteGuardId,
                    completedGuard,
                    new TransactionalBatchItemRequestOptions
                    {
                        IfMatchEtag = guard.ETag,
                    });
            using var response = await batch.ExecuteAsync(cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                return await Attempts.ReadOrDefaultAsync<AccountDeletionRecord>(
                    AccountDeletionRecord.RecordId,
                    partitionKey,
                    cancellationToken)
                    ?? throw new InvalidOperationException(
                        "The completed account deletion state could not be reloaded.");
            }
            if (response.StatusCode is not (
                    HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
                || attempt == MaximumLifecycleAttempts)
            {
                throw new CosmosException(
                    "Could not atomically complete account deletion.",
                    response.StatusCode,
                    0,
                    response.ActivityId,
                    response.RequestCharge);
            }
        }

        throw new ConcurrencyConflictException("Could not atomically complete account deletion.");
    }

    internal sealed class AccountWriteLease : IAsyncDisposable
    {
        private readonly Func<string, string, CancellationToken, Task> _persistBarrier;
        private readonly Func<Task> _markDispatched;
        private readonly Func<Task> _release;
        private bool _committed;
        private bool _mutationMayHaveCommitted;

        internal AccountWriteLease(
            Container lifecycleContainer,
            AccountWriteLeaseRecord lease,
            PartitionKey partitionKey)
        {
            _persistBarrier = async (containerName, sessionToken, cancellationToken) =>
            {
                await lifecycleContainer.UpsertItemAsync(
                    lease with
                    {
                        State = CommittedLeaseState,
                        ContainerName = containerName,
                        SessionToken = sessionToken,
                        Ttl = CommittedWriteLeaseTtlSeconds,
                    },
                    partitionKey,
                    cancellationToken: cancellationToken);
            };
            _markDispatched = async () =>
            {
                await lifecycleContainer.ReplaceItemAsync(
                    lease with { Ttl = DispatchedWriteLeaseTtlSeconds },
                    lease.Id,
                    partitionKey,
                    cancellationToken: CancellationToken.None);
            };
            _release = async () =>
            {
                try
                {
                    await lifecycleContainer.DeleteItemAsync<AccountWriteLeaseRecord>(
                        lease.Id,
                        partitionKey);
                }
                catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
                {
                    // TTL or a previous cleanup already released the lease.
                }
            };
        }

        internal AccountWriteLease(
            Func<string, string, CancellationToken, Task> persistBarrier,
            Func<Task> release,
            Func<Task>? markDispatched = null)
        {
            _persistBarrier = persistBarrier;
            _release = release;
            _markDispatched = markDispatched ?? (() => Task.CompletedTask);
        }

        public async Task MarkMutationDispatchedAsync()
        {
            await _markDispatched();
            _mutationMayHaveCommitted = true;
        }

        public void MarkDefinitelyNotCommitted()
        {
            if (!_committed)
            {
                _mutationMayHaveCommitted = false;
            }
        }

        public async Task CommitAsync(
            string containerName,
            string? sessionToken,
            CancellationToken cancellationToken = default)
        {
            if (string.IsNullOrWhiteSpace(containerName)
                || string.IsNullOrWhiteSpace(sessionToken))
            {
                throw new InvalidOperationException(
                    "A committed account mutation requires its Cosmos session token.");
            }

            // The user-data write has already succeeded. From this point the
            // lease must never be deleted on cancellation or journal failure:
            // retaining it blocks deletion until an operator can reconcile.
            _mutationMayHaveCommitted = true;
            await _persistBarrier(
                containerName,
                sessionToken,
                CancellationToken.None);
            _committed = true;
        }

        public async ValueTask DisposeAsync()
        {
            if (_committed || _mutationMayHaveCommitted)
            {
                return;
            }
            await _release();
        }
    }

    private sealed record AccountWriteGuardRecord(
        string Id,
        string UserId,
        string Type,
        string State,
        DateTimeOffset UpdatedAt,
        int Ttl)
    {
        [JsonPropertyName("_etag")]
        public string? ETag { get; init; }
    }

    internal sealed record AccountWriteLeaseRecord(
        string Id,
        string UserId,
        string Type,
        string State,
        DateTimeOffset AcquiredAt,
        string? ContainerName,
        string? SessionToken,
        int Ttl);

    internal sealed record AccountWriteBarrier(
        string ContainerName,
        string SessionToken);
}
