using System.Net;
using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosEventRepository(CosmosContext context) : IEventRepository
{
    public async Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            learningEvent.UserId,
            cancellationToken);
        await writeLease.MarkMutationDispatchedAsync();
        try
        {
            var response = await context.Events.CreateItemAsync(
                learningEvent,
                new PartitionKey(learningEvent.UserId),
                cancellationToken: cancellationToken);
            await writeLease.CommitAsync(
                CosmosContainers.Events,
                response.Headers.Session,
                cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            writeLease.MarkDefinitelyNotCommitted();
            // Deterministic event ids turn the events container into an idempotent
            // outbox projection. The existing event is the successful result.
        }
    }
}
