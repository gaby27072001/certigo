using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Tests;

/// <summary>
/// Reads a certigo-content <c>dist</c> root (<c>release.json</c>, <c>public/</c>,
/// <c>private/</c>) as if it were the immutable Blob release source.
/// </summary>
internal sealed class FileContentReleaseSource(string root) : IContentReleaseSource
{
    public Task<ContentBlobObject> ReadReleaseAsync(
        string releaseId,
        CancellationToken cancellationToken = default)
        => Read("release.json");

    public Task<ContentBlobObject> ReadManifestAsync(
        ContentArtifact artifact,
        string manifestId,
        CancellationToken cancellationToken = default)
        => Read(Path.Combine(DirectoryName(artifact), "manifest.json"));

    public Task<ContentBlobObject> ReadFileAsync(
        ContentArtifact artifact,
        string manifestId,
        string path,
        CancellationToken cancellationToken = default)
        => Read(Path.Combine(DirectoryName(artifact), path.Replace('/', Path.DirectorySeparatorChar)));

    public Task<IReadOnlyList<string>> ListFilesAsync(
        ContentArtifact artifact,
        string manifestId,
        CancellationToken cancellationToken = default)
    {
        var directory = Path.Combine(root, DirectoryName(artifact));
        IReadOnlyList<string> files = Directory
            .EnumerateFiles(directory, "*.json", SearchOption.AllDirectories)
            .Select(path => Path.GetRelativePath(directory, path).Replace('\\', '/'))
            .Where(path => path != "manifest.json")
            .OrderBy(path => path, StringComparer.Ordinal)
            .ToArray();
        return Task.FromResult(files);
    }

    private Task<ContentBlobObject> Read(string relativePath)
    {
        var path = Path.Combine(root, relativePath);
        return Task.FromResult(new ContentBlobObject(
            relativePath.Replace('\\', '/'),
            "fixture-version",
            "\"fixture-etag\"",
            true,
            File.ReadAllBytes(path)));
    }

    private static string DirectoryName(ContentArtifact artifact)
        => artifact == ContentArtifact.Public ? "public" : "private";
}
