using Microsoft.Azure.Cosmos;
using System.Net;
using System.Text.Json.Serialization;
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

        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            userId,
            cancellationToken);
        var partitionKey = new PartitionKey(userId);
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            var writes = new List<(ConceptMastery Mastery, ConceptMasteryDocument? Existing)>();
            foreach (var mastery in masteries)
            {
                var existing = await context.Progress.ReadOrDefaultAsync<ConceptMasteryDocument>(
                    Id(mastery.TrackId, mastery.ConceptId),
                    partitionKey,
                    cancellationToken);
                if (existing is null
                    || mastery.LastReviewedAt > existing.Mastery.LastReviewedAt
                    || mastery.LastReviewedAt == existing.Mastery.LastReviewedAt
                        && mastery.Reps > existing.Mastery.Reps)
                {
                    writes.Add((mastery, existing));
                }
            }

            if (writes.Count == 0)
            {
                return;
            }

            var batch = context.Progress.CreateTransactionalBatch(partitionKey);
            foreach (var (mastery, existing) in writes)
            {
                var document = new ConceptMasteryDocument(
                    Id(mastery.TrackId, mastery.ConceptId),
                    userId,
                    mastery.TrackId,
                    mastery.ConceptId,
                    mastery);
                if (existing is null)
                {
                    batch.CreateItem(document);
                }
                else
                {
                    batch.ReplaceItem(
                        document.Id,
                        document,
                        new TransactionalBatchItemRequestOptions
                        {
                            IfMatchEtag = existing.ETag,
                        });
                }
            }

            await writeLease.MarkMutationDispatchedAsync();
            using var response = await batch.ExecuteAsync(cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                await writeLease.CommitAsync(
                    CosmosContainers.Progress,
                    response.Headers.Session,
                    cancellationToken);
                return;
            }

            writeLease.MarkDefinitelyNotCommitted();
            if (attempt == 3
                || response.StatusCode is not (HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed))
            {
                throw new CosmosException(
                    $"Progress batch failed: {response.StatusCode}",
                    response.StatusCode,
                    0,
                    response.ActivityId,
                    response.RequestCharge);
            }
        }
    }

    private static string Id(string trackId, string conceptId) => $"{trackId}:{conceptId}";

    private sealed record ConceptMasteryDocument(
        string Id,
        string UserId,
        string TrackId,
        string ConceptId,
        ConceptMastery Mastery)
    {
        [JsonPropertyName("_etag")]
        public string? ETag { get; init; }
    }
}
