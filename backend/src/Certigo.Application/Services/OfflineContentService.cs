using System.Security.Cryptography;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Content;

namespace Certigo.Application.Services;

public interface IOfflineContentService
{
    Task<OfflineContentManifest> GetActiveManifestAsync(
        CancellationToken cancellationToken = default);

    Task<OfflineContentPayload> GetCatalogAsync(
        string publicManifestId,
        CancellationToken cancellationToken = default);

    Task<OfflineContentPayload?> GetLessonAsync(
        string publicManifestId,
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default);
}

public sealed class OfflineContentService(
    IContentRepository content,
    IContentService contentService,
    IContentReleaseService releases,
    IContentPayloadSerializer serializer) : IOfflineContentService
{
    public async Task<OfflineContentManifest> GetActiveManifestAsync(
        CancellationToken cancellationToken = default)
    {
        var active = await releases.GetActivePublicManifestAsync(cancellationToken)
            ?? throw new ContentUnavailableException("No active public content manifest exists.");
        var publicManifestId = active.Manifest.ManifestId;
        var snapshot = await ResolveSnapshotAsync(publicManifestId, cancellationToken);
        var descriptors = new List<OfflineContentResourceDescriptor>();

        var catalog = await contentService.GetCatalogAsync(snapshot, cancellationToken);
        descriptors.Add(Describe(
            "catalog",
            "catalog/tracks.json",
            "catalog",
            catalog));

        var tracks = await content.ListTracksAsync(snapshot, cancellationToken);
        var lessons = tracks
            .SelectMany(track => track.Units.SelectMany(unit =>
                unit.Lessons.Select(lessonId => (TrackId: track.Id, LessonId: lessonId))))
            .Distinct()
            .OrderBy(item => item.TrackId, StringComparer.Ordinal)
            .ThenBy(item => item.LessonId, StringComparer.Ordinal);

        foreach (var (trackId, lessonId) in lessons)
        {
            var lesson = await content.GetLessonAsync(
                snapshot,
                trackId,
                lessonId,
                cancellationToken)
                ?? throw new ContentReleaseStateException(
                    $"Public lesson '{trackId}/{lessonId}' is missing from manifest '{publicManifestId}'.");
            descriptors.Add(Describe(
                lessonId,
                LessonPath(trackId, lessonId),
                "lesson",
                lesson,
                trackId));
        }

        return new OfflineContentManifest(
            ContentReleaseContracts.OfflineManifestV1,
            publicManifestId,
            active.Manifest.Schema,
            descriptors.Count,
            descriptors);
    }

    public async Task<OfflineContentPayload> GetCatalogAsync(
        string publicManifestId,
        CancellationToken cancellationToken = default)
    {
        var snapshot = await ResolveSnapshotAsync(publicManifestId, cancellationToken);
        var catalog = await contentService.GetCatalogAsync(snapshot, cancellationToken);
        return ToPayload(publicManifestId, catalog);
    }

    public async Task<OfflineContentPayload?> GetLessonAsync(
        string publicManifestId,
        string trackId,
        string lessonId,
        CancellationToken cancellationToken = default)
    {
        var snapshot = await ResolveSnapshotAsync(publicManifestId, cancellationToken);
        var lesson = await content.GetLessonAsync(
            snapshot,
            trackId,
            lessonId,
            cancellationToken);
        return lesson is null ? null : ToPayload(publicManifestId, lesson);
    }

    private async Task<ContentSnapshot> ResolveSnapshotAsync(
        string publicManifestId,
        CancellationToken cancellationToken)
    {
        ContentReleaseContracts.RequireDigestId(publicManifestId, "publicManifestId");
        var snapshot = await content.ResolveSnapshotAsync(publicManifestId, cancellationToken);
        return snapshot.IsLegacy
            ? throw new ContentReleaseStateException(
                "Offline content requires an imported and activated versioned snapshot.")
            : snapshot;
    }

    private OfflineContentResourceDescriptor Describe<T>(
        string id,
        string path,
        string resourceType,
        T value,
        string? trackId = null)
    {
        var bytes = serializer.Serialize(value);
        return new OfflineContentResourceDescriptor(
            id,
            path,
            resourceType,
            Hash(bytes),
            bytes.LongLength,
            trackId);
    }

    private OfflineContentPayload ToPayload<T>(string publicManifestId, T value)
    {
        var bytes = serializer.Serialize(value);
        return new OfflineContentPayload(publicManifestId, Hash(bytes), bytes);
    }

    private static string Hash(ReadOnlySpan<byte> content)
        => Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant();

    private static string LessonPath(string trackId, string lessonId)
        => $"tracks/{Uri.EscapeDataString(trackId)}/lessons/{Uri.EscapeDataString(lessonId)}.json";
}
