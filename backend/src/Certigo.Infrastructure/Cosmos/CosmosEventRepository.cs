using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosEventRepository(CosmosContext context) : IEventRepository
{
    public async Task AddAsync(LearningEvent learningEvent, CancellationToken cancellationToken = default)
        => await context.Events.CreateItemAsync(learningEvent, new PartitionKey(learningEvent.UserId), cancellationToken: cancellationToken);
}
