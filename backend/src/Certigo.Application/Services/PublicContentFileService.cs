using System.Security.Cryptography;
using System.Text.RegularExpressions;
using Certigo.Application.Abstractions;

namespace Certigo.Application.Services;

public interface IPublicContentFileService
{
    Task<PublicContentFileResult> GetAsync(
        string releaseId,
        string publicManifestId,
        string hash,
        string path,
        CancellationToken cancellationToken = default);
}

public sealed class DisabledPublicContentFileService : IPublicContentFileService
{
    public Task<PublicContentFileResult> GetAsync(
        string releaseId,
        string publicManifestId,
        string hash,
        string path,
        CancellationToken cancellationToken = default)
        => throw new ContentReleaseNotFoundException("Public content file was not found.");
}

public sealed partial class PublicContentFileService(
    IContentReleaseStore store,
    IContentReleaseSource source,
    ContentContractVerifier verifier,
    PublicContentDeliveryOptions options) : IPublicContentFileService
{
    private const string NotFoundMessage = "Public content file was not found.";

    public async Task<PublicContentFileResult> GetAsync(
        string releaseId,
        string publicManifestId,
        string hash,
        string path,
        CancellationToken cancellationToken = default)
    {
        if (!options.Enabled
            || !DigestIdRegex().IsMatch(releaseId)
            || !DigestIdRegex().IsMatch(publicManifestId)
            || !HexDigestRegex().IsMatch(hash)
            || !IsSafePath(path))
        {
            throw NotFound();
        }

        var receipt = await store.GetReceiptAsync(releaseId, cancellationToken);
        if (receipt is null
            || !string.Equals(receipt.PublicManifestId, publicManifestId, StringComparison.Ordinal))
        {
            throw NotFound();
        }

        ContentPackageManifest manifest;
        try
        {
            var manifestBlob = await source.ReadManifestAsync(
                ContentArtifact.Public,
                publicManifestId,
                cancellationToken);
            if (!manifestBlob.IsImmutable || string.IsNullOrWhiteSpace(manifestBlob.VersionId))
            {
                throw new ContentUnavailableException("Public content is temporarily unavailable.");
            }

            manifest = verifier.VerifyStandaloneManifest(manifestBlob.Content, ContentArtifact.Public);
        }
        catch (ContentReleaseNotFoundException)
        {
            throw NotFound();
        }
        catch (ContentReleaseValidationException)
        {
            throw new ContentUnavailableException("Public content is temporarily unavailable.");
        }

        if (!string.Equals(manifest.ManifestId, publicManifestId, StringComparison.Ordinal)
            || manifest.FileCount != manifest.Files.Count)
        {
            throw new ContentUnavailableException("Public content is temporarily unavailable.");
        }

        var matches = manifest.Files
            .Where(file => string.Equals(file.Path, path, StringComparison.Ordinal))
            .Take(2)
            .ToArray();
        if (matches.Length != 1
            || !string.Equals(matches[0].Hash, hash, StringComparison.Ordinal))
        {
            throw NotFound();
        }

        var declared = matches[0];
        if (declared.Size is <= 0 or > int.MaxValue
            || !string.Equals(Path.GetExtension(declared.Path), ".json", StringComparison.OrdinalIgnoreCase)
            || IsPrivateResource(declared))
        {
            throw new ContentUnavailableException("Public content is temporarily unavailable.");
        }

        ContentBlobObject blob;
        try
        {
            blob = await source.ReadFileAsync(
                ContentArtifact.Public,
                publicManifestId,
                declared.Path,
                cancellationToken);
        }
        catch (ContentReleaseNotFoundException)
        {
            throw NotFound();
        }
        catch (ContentReleaseValidationException)
        {
            throw new ContentUnavailableException("Public content is temporarily unavailable.");
        }

        if (!blob.IsImmutable
            || string.IsNullOrWhiteSpace(blob.VersionId)
            || blob.Content.Length != declared.Size
            || !string.Equals(
                Convert.ToHexString(SHA256.HashData(blob.Content.Span)).ToLowerInvariant(),
                declared.Hash,
                StringComparison.Ordinal))
        {
            throw new ContentUnavailableException("Public content is temporarily unavailable.");
        }

        return new PublicContentFileResult(
            releaseId,
            publicManifestId,
            declared.Path,
            declared.Hash,
            "application/json; charset=utf-8",
            blob.Content);
    }

    private static bool IsSafePath(string path)
        => !string.IsNullOrWhiteSpace(path)
           && path.Length <= 1024
           && !path.StartsWith("/", StringComparison.Ordinal)
           && !path.Contains('\\', StringComparison.Ordinal)
           && !path.Contains('%', StringComparison.Ordinal)
           && !path.Any(char.IsControl)
           && path.Split('/').All(segment => segment is not ("" or "." or ".."));

    private static bool IsPrivateResource(ContentPackageFile file)
        => file.Path.StartsWith("solutions/", StringComparison.OrdinalIgnoreCase)
           || file.ResourceType is not null
           && (file.ResourceType.Equals("solution", StringComparison.OrdinalIgnoreCase)
               || file.ResourceType.Equals("answerKey", StringComparison.OrdinalIgnoreCase));

    private static ContentReleaseNotFoundException NotFound() => new(NotFoundMessage);

    [GeneratedRegex("^sha256:[0-9a-f]{64}$", RegexOptions.CultureInvariant)]
    private static partial Regex DigestIdRegex();

    [GeneratedRegex("^[0-9a-f]{64}$", RegexOptions.CultureInvariant)]
    private static partial Regex HexDigestRegex();
}
