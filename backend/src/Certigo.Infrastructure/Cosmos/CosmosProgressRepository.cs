using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;
using Certigo.Domain.Progress;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosProgressRepository(CosmosContext context) : IProgressRepository
{
    public async Task<ConceptMastery?> GetMasteryAsync(string userId, string trackId, string conceptId, CancellationToken cancellationToken = default)
    {
        var doc = await context.Progress.ReadOrDefaultAsync<ConceptMasteryDocument>(
            Id(trackId, conceptId),
            new PartitionKey(userId),
            cancellationToken);
        return doc?.Mastery;
    }

    public async Task<IReadOnlyList<ConceptMastery>> ListMasteriesAsync(string userId, string trackId, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.userId = @userId AND c.trackId = @trackId")
            .WithParameter("@userId", userId)
            .WithParameter("@trackId", trackId);
        using var iterator = context.Progress.GetItemQueryIterator<ConceptMasteryDocument>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(userId)
        });

        var masteries = new List<ConceptMastery>();
        while (iterator.HasMoreResults)
        {
            foreach (var doc in await iterator.ReadNextAsync(cancellationToken))
            {
                if (doc.Mastery is not null)
                {
                    masteries.Add(doc.Mastery);
                }
            }
        }

        return masteries;
    }

    public async Task UpsertMasteryBatchAsync(string userId, IReadOnlyList<ConceptMastery> masteries, CancellationToken cancellationToken = default)
    {
        if (masteries.Count == 0)
        {
            return;
        }

        var batch = context.Progress.CreateTransactionalBatch(new PartitionKey(userId));
        foreach (var mastery in masteries)
        {
            batch.UpsertItem(new ConceptMasteryDocument(Id(mastery.TrackId, mastery.ConceptId), userId, mastery.TrackId, mastery.ConceptId, mastery));
        }

        using var response = await batch.ExecuteAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            throw new CosmosException($"Progress batch failed: {response.StatusCode}", response.StatusCode, 0, response.ActivityId, response.RequestCharge);
        }
    }

    private static string Id(string trackId, string conceptId) => $"{trackId}:{conceptId}";

    private sealed record ConceptMasteryDocument(string Id, string UserId, string TrackId, string ConceptId, ConceptMastery Mastery);
}
