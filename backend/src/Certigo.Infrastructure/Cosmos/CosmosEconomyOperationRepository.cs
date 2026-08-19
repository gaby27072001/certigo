using System.Net;
using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosEconomyOperationRepository(CosmosContext context) : IEconomyOperationRepository
{
    public Task<EconomyOperationRecord?> GetAsync(
        string userId,
        string operationId,
        CancellationToken cancellationToken = default) =>
        context.Economy.ReadOrDefaultAsync<EconomyOperationRecord>(
            operationId,
            new PartitionKey(userId),
            cancellationToken);

    public async Task<EconomyOperationRecord> GetOrCreateAsync(
        EconomyOperationRecord operation,
        CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            operation.UserId,
            cancellationToken);
        await writeLease.MarkMutationDispatchedAsync();
        try
        {
            var response = await context.Economy.CreateItemAsync(
                operation,
                new PartitionKey(operation.UserId),
                cancellationToken: cancellationToken);
            await writeLease.CommitAsync(
                CosmosContainers.Economy,
                response.Headers.Session,
                cancellationToken);
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            writeLease.MarkDefinitelyNotCommitted();
            return await GetAsync(operation.UserId, operation.Id, cancellationToken)
                ?? throw new ConcurrencyConflictException(
                    $"Economy operation '{operation.Id}' conflicted but could not be re-read.");
        }
    }

    public async Task<EconomyOperationRecord> MarkStepCompletedAsync(
        string userId,
        string operationId,
        string step,
        CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            userId,
            cancellationToken);
        return await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var current = await GetAsync(userId, operationId, cancellationToken)
                ?? throw new InvalidOperationException($"Economy operation '{operationId}' was not found.");
            if (current.Status == EconomyOperationRecord.FailedStatus)
            {
                throw new ConcurrencyConflictException(
                    $"Failed economy operation '{operationId}' cannot complete step '{step}'.");
            }

            if (current.HasCompleted(step))
            {
                return current;
            }

            var completedSteps = current.CompletedSteps.Append(step).ToArray();
            var completed = current.RequiredSteps.All(
                required => completedSteps.Contains(required, StringComparer.Ordinal));
            var updated = current with
            {
                CompletedSteps = completedSteps,
                Status = completed
                    ? EconomyOperationRecord.CompletedStatus
                    : EconomyOperationRecord.PendingStatus,
                UpdatedAt = DateTimeOffset.UtcNow,
            };

            try
            {
                await writeLease.MarkMutationDispatchedAsync();
                var response = await context.Economy.ReplaceItemAsync(
                    updated,
                    operationId,
                    new PartitionKey(userId),
                    new ItemRequestOptions { IfMatchEtag = current.ETag },
                    cancellationToken);
                await writeLease.CommitAsync(
                    CosmosContainers.Economy,
                    response.Headers.Session,
                    cancellationToken);
                return response.Resource;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                writeLease.MarkDefinitelyNotCommitted();
                throw new ConcurrencyConflictException(
                    $"Economy operation '{operationId}' was modified concurrently.");
            }
        }, cancellationToken: cancellationToken);
    }

    public async Task<EconomyOperationRecord> MarkFailedAsync(
        string userId,
        string operationId,
        string failureCode,
        CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            userId,
            cancellationToken);
        return await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var current = await GetAsync(userId, operationId, cancellationToken)
                ?? throw new InvalidOperationException($"Economy operation '{operationId}' was not found.");
            if (current.Status == EconomyOperationRecord.FailedStatus)
            {
                return current;
            }

            if (current.Status == EconomyOperationRecord.CompletedStatus
                || current.OutcomeJson is not null)
            {
                throw new ConcurrencyConflictException(
                    $"Economy operation '{operationId}' already committed a successful outcome.");
            }

            var failed = current with
            {
                Status = EconomyOperationRecord.FailedStatus,
                FailureCode = failureCode,
                UpdatedAt = DateTimeOffset.UtcNow,
            };
            try
            {
                await writeLease.MarkMutationDispatchedAsync();
                var response = await context.Economy.ReplaceItemAsync(
                    failed,
                    operationId,
                    new PartitionKey(userId),
                    new ItemRequestOptions { IfMatchEtag = current.ETag },
                    cancellationToken);
                await writeLease.CommitAsync(
                    CosmosContainers.Economy,
                    response.Headers.Session,
                    cancellationToken);
                return response.Resource;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                writeLease.MarkDefinitelyNotCommitted();
                throw new ConcurrencyConflictException(
                    $"Economy operation '{operationId}' was modified concurrently.");
            }
        }, cancellationToken: cancellationToken);
    }

    public async Task<EconomyOperationRecord> SetOutcomeAsync(
        string userId,
        string operationId,
        string outcomeJson,
        CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            userId,
            cancellationToken);
        return await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var current = await GetAsync(userId, operationId, cancellationToken)
                ?? throw new InvalidOperationException($"Economy operation '{operationId}' was not found.");
            if (current.Status == EconomyOperationRecord.FailedStatus)
            {
                throw new ConcurrencyConflictException(
                    $"Failed economy operation '{operationId}' cannot commit an outcome.");
            }

            if (current.OutcomeJson is not null)
            {
                if (!string.Equals(current.OutcomeJson, outcomeJson, StringComparison.Ordinal))
                {
                    throw new ConcurrencyConflictException(
                        $"Economy operation '{operationId}' already has a different outcome.");
                }

                return current;
            }

            var updated = current with
            {
                OutcomeJson = outcomeJson,
                UpdatedAt = DateTimeOffset.UtcNow,
            };
            try
            {
                await writeLease.MarkMutationDispatchedAsync();
                var response = await context.Economy.ReplaceItemAsync(
                    updated,
                    operationId,
                    new PartitionKey(userId),
                    new ItemRequestOptions { IfMatchEtag = current.ETag },
                    cancellationToken);
                await writeLease.CommitAsync(
                    CosmosContainers.Economy,
                    response.Headers.Session,
                    cancellationToken);
                return response.Resource;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                writeLease.MarkDefinitelyNotCommitted();
                throw new ConcurrencyConflictException(
                    $"Economy operation '{operationId}' was modified concurrently.");
            }
        }, cancellationToken: cancellationToken);
    }
}
