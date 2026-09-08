using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosVersionedContentRepository(
    CosmosContext context,
    IContentReleaseStore releases) : IContentRepository
{
    public async Task<ContentSnapshot> ResolveActiveSnapshotAsync(
        CancellationToken cancellationToken = default)
    {
        var pointer = await releases.GetActivePointerAsync(cancellationToken)
            ?? throw new ContentUnavailableException("No active versioned content release exists.");
        return new ContentSnapshot(
            ContentReleaseContracts.VersionedSource,
            pointer.ActiveReleaseId,
            pointer.ActivePublicManifestId);
    }

    public async Task<ContentSnapshot> ResolveSnapshotAsync(
        string publicManifestId,
        CancellationToken cancellationToken = default)
        => await releases.ResolveSnapshotAsync(publicManifestId, cancellationToken)
           ?? throw new ContentReleaseNotFoundException(
               $"Public content manifest '{publicManifestId}' is not imported.");

    public async Task<CertificationCatalogDocument?> GetCertificationCatalogAsync(
        ContentSnapshot snapshot,
        CancellationToken cancellationToken = default)
    {
        var releaseId = RequireRelease(snapshot);
        var document = await context.ContentPublic.ReadOrDefaultAsync<
            CosmosVersionedContentDocument<CertificationCatalogDocument>>(
            "catalog",
            new PartitionKey(releaseId),
            cancellationToken);
        return document?.Payload;
    }

    public async Task<Track?> GetTrackAsync(
        ContentSnapshot snapshot,
        string trackId,
        CancellationToken cancellationToken = default)
    {
        var document = await context.ContentPublic.ReadOrDefaultAsync<
            CosmosVersionedContentDocument<Track>>(
            $"track::{trackId}",
            new PartitionKey(RequireRelease(snapshot)),
            cancellationToken);
        return document is not null && IsDistributable(document.LifecycleStatus)
            ? document.Payload
            : null;
    }

    public async Task<Lesson?> GetLessonAsync(
        ContentSnapshot snapshot,
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
    {
        var document = await context.ContentPublic.ReadOrDefaultAsync<
            CosmosVersionedContentDocument<Lesson>>(
            $"lesson::{lessonId}",
            new PartitionKey(RequireRelease(snapshot)),
            cancellationToken);
        return document is not null
               && IsDistributable(document.LifecycleStatus)
               && string.Equals(document.Payload.TrackId, trackId, StringComparison.OrdinalIgnoreCase)
            ? document.Payload
            : null;
    }

    public async Task<LessonAnswerKey?> GetAnswerKeyAsync(
        ContentSnapshot snapshot,
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
    {
        var document = await context.ContentPrivate.ReadOrDefaultAsync<
            CosmosVersionedContentDocument<LessonAnswerKey>>(
            $"answerkey::{lessonId}",
            new PartitionKey(RequireRelease(snapshot)),
            cancellationToken);
        return document is not null
               && IsDistributable(document.LifecycleStatus)
               && string.Equals(document.Payload.TrackId, trackId, StringComparison.OrdinalIgnoreCase)
            ? document.Payload
            : null;
    }

    public async Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(
        ContentSnapshot snapshot,
        string trackId,
        CancellationToken cancellationToken = default)
    {
        var releaseId = RequireRelease(snapshot);
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.releaseId = @releaseId "
                + "AND c.documentType = 'answerKey' AND c.trackId = @trackId "
                + "AND (c.lifecycleStatus = 'active' OR c.lifecycleStatus = 'retiring')")
            .WithParameter("@releaseId", releaseId)
            .WithParameter("@trackId", trackId);
        using var iterator = context.ContentPrivate.GetItemQueryIterator<
            CosmosVersionedContentDocument<LessonAnswerKey>>(
            query,
            requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(releaseId) });
        var values = new List<LessonAnswerKey>();
        while (iterator.HasMoreResults)
        {
            values.AddRange((await iterator.ReadNextAsync(cancellationToken)).Select(item => item.Payload));
        }

        return values;
    }

    public async Task<IReadOnlyList<Track>> ListTracksAsync(
        ContentSnapshot snapshot,
        CancellationToken cancellationToken = default)
    {
        var releaseId = RequireRelease(snapshot);
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.releaseId = @releaseId AND c.documentType = 'track' "
                + "AND (c.lifecycleStatus = 'active' OR c.lifecycleStatus = 'retiring')")
            .WithParameter("@releaseId", releaseId);
        using var iterator = context.ContentPublic.GetItemQueryIterator<
            CosmosVersionedContentDocument<Track>>(
            query,
            requestOptions: new QueryRequestOptions { PartitionKey = new PartitionKey(releaseId) });
        var values = new List<Track>();
        while (iterator.HasMoreResults)
        {
            values.AddRange((await iterator.ReadNextAsync(cancellationToken)).Select(item => item.Payload));
        }

        return values;
    }

    public async Task<Track?> GetTrackAsync(
        string trackId,
        CancellationToken cancellationToken = default)
        => await GetTrackAsync(await ResolveActiveSnapshotAsync(cancellationToken), trackId, cancellationToken);

    public async Task<Lesson?> GetLessonAsync(
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
        => await GetLessonAsync(
            await ResolveActiveSnapshotAsync(cancellationToken),
            trackId,
            lessonId,
            cancellationToken);

    public async Task<LessonAnswerKey?> GetAnswerKeyAsync(
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
        => await GetAnswerKeyAsync(
            await ResolveActiveSnapshotAsync(cancellationToken),
            trackId,
            lessonId,
            cancellationToken);

    public async Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(
        string trackId,
        CancellationToken cancellationToken = default)
        => await ListAnswerKeysAsync(
            await ResolveActiveSnapshotAsync(cancellationToken),
            trackId,
            cancellationToken);

    public async Task<IReadOnlyList<Track>> ListTracksAsync(
        CancellationToken cancellationToken = default)
        => await ListTracksAsync(await ResolveActiveSnapshotAsync(cancellationToken), cancellationToken);

    private static string RequireRelease(ContentSnapshot snapshot)
        => !snapshot.IsLegacy && !string.IsNullOrWhiteSpace(snapshot.ReleaseId)
            ? snapshot.ReleaseId
            : throw new ContentReleaseStateException("A versioned content snapshot is required.");

    private static bool IsDistributable(string? lifecycleStatus)
        => lifecycleStatus is "active" or "retiring";
}
