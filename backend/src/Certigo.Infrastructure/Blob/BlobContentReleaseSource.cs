using System.Net;
using Azure;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Blob;

public sealed record BlobContentReleaseOptions(
    string DescriptorContainer,
    string PublicContainer,
    string PrivateContainer,
    int MaxBlobBytes,
    bool AllowMutableBlobsForDevelopment = false);

public sealed class BlobContentReleaseSource(
    BlobServiceClient serviceClient,
    BlobContentReleaseOptions options) : IContentReleaseSource
{
    public Task<ContentBlobObject> ReadReleaseAsync(
        string releaseId,
        CancellationToken cancellationToken = default)
        => ReadAsync(
            options.DescriptorContainer,
            $"releases/{releaseId}/release.json",
            cancellationToken);

    public Task<ContentBlobObject> ReadManifestAsync(
        ContentArtifact artifact,
        string manifestId,
        CancellationToken cancellationToken = default)
        => ReadAsync(
            ContainerName(artifact),
            $"manifests/{manifestId}/manifest.json",
            cancellationToken);

    public Task<ContentBlobObject> ReadFileAsync(
        ContentArtifact artifact,
        string manifestId,
        string path,
        CancellationToken cancellationToken = default)
        => ReadAsync(
            ContainerName(artifact),
            $"manifests/{manifestId}/{path}",
            cancellationToken);

    public async Task<IReadOnlyList<string>> ListFilesAsync(
        ContentArtifact artifact,
        string manifestId,
        CancellationToken cancellationToken = default)
    {
        var container = serviceClient.GetBlobContainerClient(ContainerName(artifact));
        var prefix = $"manifests/{manifestId}/";
        var paths = new List<string>();
        try
        {
            await foreach (var blob in container.GetBlobsAsync(
                               BlobTraits.None,
                               BlobStates.None,
                               prefix,
                               cancellationToken))
            {
                var relative = blob.Name[prefix.Length..];
                if (!string.Equals(relative, "manifest.json", StringComparison.Ordinal))
                {
                    paths.Add(relative);
                }
            }
        }
        catch (RequestFailedException exception) when (exception.Status == (int)HttpStatusCode.NotFound)
        {
            throw new ContentReleaseNotFoundException(
                $"{artifact} content manifest '{manifestId}' was not found.");
        }

        return paths;
    }

    private async Task<ContentBlobObject> ReadAsync(
        string containerName,
        string path,
        CancellationToken cancellationToken)
    {
        var client = serviceClient.GetBlobContainerClient(containerName).GetBlobClient(path);
        try
        {
            var properties = (await client.GetPropertiesAsync(cancellationToken: cancellationToken)).Value;
            if (properties.ContentLength is <= 0 or > int.MaxValue
                || properties.ContentLength > options.MaxBlobBytes)
            {
                throw new ContentReleaseValidationException(
                    $"Blob '{path}' has invalid or excessive size {properties.ContentLength}.");
            }

            var versionId = properties.VersionId ?? string.Empty;
            var isImmutable = options.AllowMutableBlobsForDevelopment
                || properties.HasLegalHold
                || properties.ImmutabilityPolicy?.ExpiresOn > DateTimeOffset.UtcNow;
            var pinnedClient = string.IsNullOrWhiteSpace(versionId)
                ? client
                : client.WithVersion(versionId);
            var download = (await pinnedClient.DownloadStreamingAsync(
                cancellationToken: cancellationToken)).Value;
            await using var content = download.Content;
            using var buffer = new MemoryStream((int)properties.ContentLength);
            await content.CopyToAsync(buffer, cancellationToken);
            if (buffer.Length != properties.ContentLength)
            {
                throw new ContentReleaseValidationException(
                    $"Blob '{path}' changed or was truncated while being read.");
            }

            return new ContentBlobObject(
                path,
                versionId,
                properties.ETag.ToString(),
                isImmutable,
                buffer.ToArray());
        }
        catch (RequestFailedException exception) when (exception.Status == (int)HttpStatusCode.NotFound)
        {
            throw new ContentReleaseNotFoundException($"Content blob '{path}' was not found.");
        }
    }

    private string ContainerName(ContentArtifact artifact)
        => artifact == ContentArtifact.Public
            ? options.PublicContainer
            : options.PrivateContainer;
}
