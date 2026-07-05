using Microsoft.Azure.Cosmos;
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
        var doc = new LearnerModelDocument(Id(model.TrackId), model.UserId, model.TrackId, model);
        await context.Progress.UpsertItemAsync(doc, new PartitionKey(model.UserId), cancellationToken: cancellationToken);
    }

    private static string Id(string trackId) => $"learnermodel::{trackId}";

    private sealed record LearnerModelDocument(string Id, string UserId, string Track, LearnerModelRecord Model);
}
