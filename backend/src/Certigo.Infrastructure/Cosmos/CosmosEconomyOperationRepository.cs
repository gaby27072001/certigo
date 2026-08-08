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
        try
        {
            var response = await context.Economy.CreateItemAsync(
                operation,
                new PartitionKey(operation.UserId),
                cancellationToken: cancellationToken);
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
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
        return await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var current = await GetAsync(userId, operationId, cancellationToken)
                ?? throw new InvalidOperationException($"Economy operation '{operationId}' was not found.");
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
                var response = await context.Economy.ReplaceItemAsync(
                    updated,
                    operationId,
                    new PartitionKey(userId),
                    new ItemRequestOptions { IfMatchEtag = current.ETag },
                    cancellationToken);
                return response.Resource;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
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
        return await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var current = await GetAsync(userId, operationId, cancellationToken)
                ?? throw new InvalidOperationException($"Economy operation '{operationId}' was not found.");
            if (current.Status == EconomyOperationRecord.FailedStatus)
            {
                return current;
            }

            var failed = current with
            {
                Status = EconomyOperationRecord.FailedStatus,
                FailureCode = failureCode,
                UpdatedAt = DateTimeOffset.UtcNow,
            };
            try
            {
                var response = await context.Economy.ReplaceItemAsync(
                    failed,
                    operationId,
                    new PartitionKey(userId),
                    new ItemRequestOptions { IfMatchEtag = current.ETag },
                    cancellationToken);
                return response.Resource;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                throw new ConcurrencyConflictException(
                    $"Economy operation '{operationId}' was modified concurrently.");
            }
        }, cancellationToken: cancellationToken);
    }
}
