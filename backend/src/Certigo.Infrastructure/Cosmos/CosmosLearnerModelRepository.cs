using Microsoft.Azure.Cosmos;
using System.Net;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Cosmos;

// The tutor's per-(user, track) memory. Reuses the progress container (PK =
// /userId) under a "learnermodel::{trackId}" id, so it adds no container and no
// Bicep change. The track is stored as "track" (not "trackId") so the concept-
// mastery query in CosmosProgressRepository never picks these documents up.
public sealed class CosmosLearnerModelRepository(CosmosContext context) : ILearnerModelRepository
{
    public async Task<LearnerModelRecord?> GetAsync(string userId, string trackId, CancellationToken cancellationToken = default)
    {
        var doc = await context.Progress.ReadOrDefaultAsync<LearnerModelDocument>(
            Id(trackId), new PartitionKey(userId), cancellationToken);
        return doc?.Model;
    }

    public async Task UpsertAsync(LearnerModelRecord model, CancellationToken cancellationToken = default)
    {
        var id = Id(model.TrackId);
        var partitionKey = new PartitionKey(model.UserId);
        for (var attempt = 1; attempt <= 3; attempt++)
        {
            var existing = await context.Progress.ReadOrDefaultAsync<LearnerModelDocument>(
                id,
                partitionKey,
                cancellationToken);
            var existingAttempts = existing?.Model.Concepts.Sum(concept => concept.Attempts) ?? -1;
            var incomingAttempts = model.Concepts.Sum(concept => concept.Attempts);
            if (existing is not null
                && (existing.Model.UpdatedAt > model.UpdatedAt
                    || existing.Model.UpdatedAt == model.UpdatedAt
                        && existingAttempts >= incomingAttempts))
            {
                return;
            }

            var document = new LearnerModelDocument(id, model.UserId, model.TrackId, model);
            try
            {
                if (existing is null)
                {
                    await context.Progress.CreateItemAsync(
                        document,
                        partitionKey,
                        cancellationToken: cancellationToken);
                }
                else
                {
                    await context.Progress.ReplaceItemAsync(
                        document,
                        id,
                        partitionKey,
                        new ItemRequestOptions { IfMatchEtag = existing.ETag },
                        cancellationToken);
                }

                return;
            }
            catch (CosmosException ex) when (
                attempt < 3
                && ex.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
            {
                // Re-read a concurrent projection and retain whichever is newer.
            }
        }

        throw new ConcurrencyConflictException(
            $"Learner model '{model.UserId}/{model.TrackId}' was modified concurrently.");
    }

    private static string Id(string trackId) => $"learnermodel::{trackId}";

    private sealed record LearnerModelDocument(
        string Id,
        string UserId,
        string Track,
        LearnerModelRecord Model)
    {
        [JsonPropertyName("_etag")]
        public string? ETag { get; init; }
    }
}
