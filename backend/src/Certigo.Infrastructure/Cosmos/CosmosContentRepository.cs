using Microsoft.Azure.Cosmos;
using Certigo.Application.Abstractions;
using Certigo.Domain.Content;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosContentRepository(CosmosContext context) : IContentRepository
{
    public Task<Track?> GetTrackAsync(string trackId, CancellationToken cancellationToken = default)
        => context.Content.ReadOrDefaultAsync<Track>(trackId, new PartitionKey(trackId), cancellationToken);

    public Task<Lesson?> GetLessonAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => context.Content.ReadOrDefaultAsync<Lesson>(lessonId, new PartitionKey(trackId), cancellationToken);

    public Task<LessonAnswerKey?> GetAnswerKeyAsync(string trackId, string lessonId, CancellationToken cancellationToken = default)
        => context.Content.ReadOrDefaultAsync<LessonAnswerKey>($"answerkey::{lessonId}", new PartitionKey(trackId), cancellationToken);

    public async Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(string trackId, CancellationToken cancellationToken = default)
    {
        // Answer-key docs are id="answerkey::{lessonId}", PK=/trackId; STARTSWITH
        // isolates them from the track and lesson documents in the same partition.
        var query = new QueryDefinition("SELECT * FROM c WHERE c.trackId = @trackId AND STARTSWITH(c.id, 'answerkey::')")
            .WithParameter("@trackId", trackId);
        using var iterator = context.Content.GetItemQueryIterator<LessonAnswerKey>(query, requestOptions: new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(trackId)
        });

        var keys = new List<LessonAnswerKey>();
        while (iterator.HasMoreResults)
        {
            keys.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        return keys;
    }

    public async Task<IReadOnlyList<Track>> ListTracksAsync(CancellationToken cancellationToken = default)
    {
        // Track docs are seeded with type="track" (id == trackId), one per
        // /trackId partition, so this is a deliberate cross-partition scan with
        // NO PartitionKey — the catalog spans every track.
        var query = new QueryDefinition("SELECT * FROM c WHERE c.type = 'track'");
        using var iterator = context.Content.GetItemQueryIterator<Track>(query);

        var tracks = new List<Track>();
        while (iterator.HasMoreResults)
        {
            tracks.AddRange(await iterator.ReadNextAsync(cancellationToken));
        }

        return tracks;
    }
}
