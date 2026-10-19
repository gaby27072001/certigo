using System.Net;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosPilotHistoryRepository(CosmosContext context) : IPilotHistoryRepository
{
    private const string RecordKind = "pilot-lesson-history";

    public async Task<IReadOnlyList<PilotLessonHistoryRecord>> ListAsync(
        string userId,
        string pilotId,
        string contentDigest,
        CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition(
                "SELECT c.id, c.userId, c.pilotId, c.contentDigest, c.lessonId, "
                + "c.lastAccessedAt, c.markedReadAt FROM c "
                + "WHERE c.kind = @kind AND c.pilotId = @pilotId "
                + "AND c.contentDigest = @contentDigest")
            .WithParameter("@kind", RecordKind)
            .WithParameter("@pilotId", pilotId)
            .WithParameter("@contentDigest", contentDigest);
        using var iterator = context.Progress.GetItemQueryIterator<PilotHistoryDocument>(
            query,
            requestOptions: new QueryRequestOptions
            {
                PartitionKey = new PartitionKey(userId),
            });
        var records = new List<PilotLessonHistoryRecord>();
        while (iterator.HasMoreResults)
        {
            records.AddRange((await iterator.ReadNextAsync(cancellationToken))
                .Select(ToRecord));
        }

        return records;
    }

    public async Task<PilotLessonHistoryRecord> RecordAsync(
        PilotLessonHistoryRecord activity,
        bool markRead,
        CancellationToken cancellationToken = default)
    {
        await using var writeLease = await context.AcquireAccountWriteLeaseAsync(
            activity.UserId,
            cancellationToken);
        var partitionKey = new PartitionKey(activity.UserId);
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            var existing = await context.Progress.ReadOrDefaultAsync<PilotHistoryDocument>(
                activity.Id,
                partitionKey,
                cancellationToken);
            var merged = activity with
            {
                LastAccessedAt = existing is null
                    ? activity.LastAccessedAt
                    : Max(activity.LastAccessedAt, existing.LastAccessedAt),
                MarkedReadAt = existing?.MarkedReadAt
                    ?? (markRead ? activity.LastAccessedAt : null),
            };
            if (existing is not null
                && merged.LastAccessedAt == existing.LastAccessedAt
                && merged.MarkedReadAt == existing.MarkedReadAt)
            {
                return ToRecord(existing);
            }

            var document = new PilotHistoryDocument(
                merged.Id,
                merged.UserId,
                RecordKind,
                merged.PilotId,
                merged.ContentDigest,
                merged.LessonId,
                merged.LastAccessedAt,
                merged.MarkedReadAt);
            try
            {
                ItemResponse<PilotHistoryDocument> response;
                await writeLease.MarkMutationDispatchedAsync();
                if (existing is null)
                {
                    response = await context.Progress.CreateItemAsync(
                        document,
                        partitionKey,
                        cancellationToken: cancellationToken);
                }
                else
                {
                    response = await context.Progress.ReplaceItemAsync(
                        document,
                        document.Id,
                        partitionKey,
                        new ItemRequestOptions { IfMatchEtag = existing.ETag },
                        cancellationToken);
                }

                await writeLease.CommitAsync(
                    CosmosContainers.Progress,
                    response.Headers.Session,
                    cancellationToken);
                return merged;
            }
            catch (CosmosException ex) when (
                ex.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
            {
                writeLease.MarkDefinitelyNotCommitted();
            }
        }

        throw new ConcurrencyConflictException(
            $"Pilot history '{activity.PilotId}/{activity.LessonId}' was modified concurrently.");
    }

    private static DateTimeOffset Max(DateTimeOffset left, DateTimeOffset right) =>
        left >= right ? left : right;

    private static PilotLessonHistoryRecord ToRecord(PilotHistoryDocument document) =>
        new(
            document.Id,
            document.UserId,
            document.PilotId,
            document.ContentDigest,
            document.LessonId,
            document.LastAccessedAt,
            document.MarkedReadAt);

    private sealed record PilotHistoryDocument(
        string Id,
        string UserId,
        string Kind,
        string PilotId,
        string ContentDigest,
        string LessonId,
        DateTimeOffset LastAccessedAt,
        DateTimeOffset? MarkedReadAt)
    {
        [JsonPropertyName("_etag")]
        public string? ETag { get; init; }
    }
}
