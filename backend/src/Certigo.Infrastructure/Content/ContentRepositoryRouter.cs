using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Certigo.Infrastructure.Cosmos;

namespace Certigo.Infrastructure.Content;

public sealed class ContentRepositoryRouter : IContentRepository
{
    private readonly CosmosContentRepository _legacy;
    private readonly CosmosVersionedContentRepository _versioned;
    private readonly string _mode;

    public ContentRepositoryRouter(
        CosmosContentRepository legacy,
        CosmosVersionedContentRepository versioned,
        string mode)
    {
        if (mode is not ("legacy" or "versioned"))
        {
            throw new InvalidOperationException(
                "CONTENT_REPOSITORY_MODE must be either 'legacy' or 'versioned'.");
        }

        _legacy = legacy;
        _versioned = versioned;
        _mode = mode;
    }

    public Task<ContentSnapshot> ResolveActiveSnapshotAsync(
        CancellationToken cancellationToken = default)
        => _mode == "legacy"
            ? Task.FromResult(ContentSnapshot.Legacy)
            : _versioned.ResolveActiveSnapshotAsync(cancellationToken);

    public Task<ContentSnapshot> ResolveSnapshotAsync(
        string publicManifestId,
        CancellationToken cancellationToken = default)
        => _versioned.ResolveSnapshotAsync(publicManifestId, cancellationToken);

    public Task<CertificationCatalogDocument?> GetCertificationCatalogAsync(
        ContentSnapshot snapshot,
        CancellationToken cancellationToken = default)
        => snapshot.IsLegacy
            ? Task.FromResult<CertificationCatalogDocument?>(null)
            : _versioned.GetCertificationCatalogAsync(snapshot, cancellationToken);

    public Task<Track?> GetTrackAsync(
        ContentSnapshot snapshot,
        string trackId,
        CancellationToken cancellationToken = default)
        => snapshot.IsLegacy
            ? _legacy.GetTrackAsync(trackId, cancellationToken)
            : _versioned.GetTrackAsync(snapshot, trackId, cancellationToken);

    public Task<Lesson?> GetLessonAsync(
        ContentSnapshot snapshot,
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
        => snapshot.IsLegacy
            ? _legacy.GetLessonAsync(trackId, lessonId, cancellationToken)
            : _versioned.GetLessonAsync(snapshot, trackId, lessonId, cancellationToken);

    public Task<LessonAnswerKey?> GetAnswerKeyAsync(
        ContentSnapshot snapshot,
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
        => snapshot.IsLegacy
            ? _legacy.GetAnswerKeyAsync(trackId, lessonId, cancellationToken)
            : _versioned.GetAnswerKeyAsync(snapshot, trackId, lessonId, cancellationToken);

    public Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(
        ContentSnapshot snapshot,
        string trackId,
        CancellationToken cancellationToken = default)
        => snapshot.IsLegacy
            ? _legacy.ListAnswerKeysAsync(trackId, cancellationToken)
            : _versioned.ListAnswerKeysAsync(snapshot, trackId, cancellationToken);

    public Task<IReadOnlyList<Track>> ListTracksAsync(
        ContentSnapshot snapshot,
        CancellationToken cancellationToken = default)
        => snapshot.IsLegacy
            ? _legacy.ListTracksAsync(cancellationToken)
            : _versioned.ListTracksAsync(snapshot, cancellationToken);

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
}
