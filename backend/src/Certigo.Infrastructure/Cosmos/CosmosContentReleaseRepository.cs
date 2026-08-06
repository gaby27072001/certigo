using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

/// <summary>
/// Commits release metadata and public files to the public release container,
/// while answer keys are stored in a distinct private container. The receipt is
/// written last and is the only commit marker used by promotion and reads.
/// </summary>
public sealed class CosmosContentReleaseRepository(CosmosContext context) :
    IContentReleaseRepository,
    IPublicContentReleaseRepository,
    IPrivateContentReleaseRepository
{
    private const string StatePartition = "__content_releases";
    private const int MaxStateHistoryEntries = 100;

    public async Task<ContentReleaseReceipt?> GetReceiptAsync(
        string manifestId,
        CancellationToken cancellationToken = default)
    {
        var document = await context.PublicContentReleases
            .ReadOrDefaultAsync<ReleaseReceiptDocument>(
                ReceiptId(manifestId),
                new PartitionKey(ReleasePartition(manifestId)),
                cancellationToken);
        return document?.ToModel();
    }

    public async Task<bool> ImportAsync(
        VerifiedContentRelease release,
        CancellationToken cancellationToken = default)
    {
        var existing = await GetReceiptAsync(release.ManifestId, cancellationToken);
        if (existing is not null)
        {
            EnsureSameRelease(existing, release);
            return true;
        }

        await CreateImmutablePrivateManifestAsync(release, cancellationToken);
        foreach (var file in release.Files)
        {
            var partition = ReleasePartition(release.ManifestId);
            var document = new ReleaseFileDocument(
                FileId(release.ManifestId, file.Path),
                partition,
                release.ManifestId,
                file.Channel,
                file.Id,
                file.Path,
                file.Hash,
                file.Size,
                Convert.ToBase64String(file.Content));
            var container = file.Channel switch
            {
                "public" => context.PublicContentReleases,
                "answerKey" => context.PrivateContentReleases,
                _ => throw new ContentReleaseValidationException(
                    "Content release rejected: unsupported_verified_channel.")
            };
            await CreateImmutableAsync(container, document, partition, file, cancellationToken);
        }

        var receiptPartition = ReleasePartition(release.ManifestId);
        var receipt = new ReleaseReceiptDocument(
            ReceiptId(release.ManifestId),
            receiptPartition,
            release.ManifestId,
            release.PublicManifestId,
            release.Fingerprint,
            release.PublicManifest,
            release.ImportedAt);
        try
        {
            await context.PublicContentReleases.CreateItemAsync(
                receipt,
                new PartitionKey(receiptPartition),
                cancellationToken: cancellationToken);
            return false;
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            var winner = await GetReceiptAsync(release.ManifestId, cancellationToken)
                ?? throw new ConcurrencyConflictException(
                    $"Content release '{release.ManifestId}' was imported concurrently.");
            EnsureSameRelease(winner, release);
            return true;
        }
    }

    public async Task<ContentReleaseState?> GetStateAsync(
        string environment,
        CancellationToken cancellationToken = default)
    {
        var document = await ReadStateAsync(environment, cancellationToken);
        return document?.ToModel();
    }

    public async Task<ContentReleasePromotionResult> PromoteAsync(
        string environment,
        string manifestId,
        ContentReleaseOperation operation,
        DateTimeOffset changedAt,
        CancellationToken cancellationToken = default)
    {
        var receipt = await GetReceiptAsync(manifestId, cancellationToken);
        if (receipt is null)
        {
            throw new ContentReleaseNotFoundException(manifestId);
        }

        var current = await ReadStateAsync(environment, cancellationToken);
        if (operation == ContentReleaseOperation.Rollback
            && (current is null
                || !string.Equals(current.PreviousManifestId, manifestId, StringComparison.Ordinal)))
        {
            throw new ContentReleaseValidationException(
                "Content release rejected: rollback_target_is_not_previous.");
        }

        if (current is not null
            && string.Equals(current.ActiveManifestId, manifestId, StringComparison.Ordinal))
        {
            return new ContentReleasePromotionResult(current.ToModel(), false);
        }

        var history = current?.History.ToList() ?? [];
        history.Add(new ContentReleaseHistoryEntry(manifestId, operation, changedAt));
        if (history.Count > MaxStateHistoryEntries)
        {
            history = history.GetRange(
                history.Count - MaxStateHistoryEntries,
                MaxStateHistoryEntries);
        }

        var next = new ReleaseStateDocument(
            StateId(environment),
            StatePartition,
            environment,
            manifestId,
            current?.ActiveManifestId,
            changedAt,
            operation,
            history,
            current?.ETag);

        try
        {
            if (current is null)
            {
                var response = await context.PublicContentReleases.CreateItemAsync(
                    next,
                    new PartitionKey(StatePartition),
                    new ItemRequestOptions { IfNoneMatchEtag = "*" },
                    cancellationToken);
                return new ContentReleasePromotionResult(response.Resource.ToModel(), true);
            }

            var replaced = await context.PublicContentReleases.ReplaceItemAsync(
                next,
                next.Id,
                new PartitionKey(StatePartition),
                new ItemRequestOptions { IfMatchEtag = current.ETag },
                cancellationToken);
            return new ContentReleasePromotionResult(replaced.Resource.ToModel(), true);
        }
        catch (CosmosException ex) when (
            ex.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException(
                $"Content environment '{environment}' was promoted concurrently.");
        }
    }

    public Task<StoredContentReleaseFile?> GetActivePublicFileAsync(
        string environment,
        string path,
        CancellationToken cancellationToken = default)
        => GetActiveFileAsync(
            context.PublicContentReleases,
            environment,
            "public",
            path,
            static (receipt, _) => Task.FromResult(receipt.PublicManifest),
            cancellationToken);

    public Task<StoredContentReleaseFile?> GetActivePrivateFileAsync(
        string environment,
        string path,
        CancellationToken cancellationToken = default)
        => GetActiveFileAsync(
            context.PrivateContentReleases,
            environment,
            "answerKey",
            path,
            GetPrivateManifestAsync,
            cancellationToken);

    private async Task<StoredContentReleaseFile?> GetActiveFileAsync(
        Container container,
        string environment,
        string channel,
        string path,
        Func<ContentReleaseReceipt, CancellationToken, Task<ContentArtifactManifest>> selectManifest,
        CancellationToken cancellationToken)
    {
        var state = await ReadStateAsync(environment, cancellationToken);
        if (state is null)
        {
            return null;
        }

        var receipt = await GetReceiptAsync(state.ActiveManifestId, cancellationToken);
        if (receipt is null)
        {
            throw new ContentReleaseValidationException(
                "Content release rejected: committed_receipt_missing_or_inconsistent.");
        }

        var manifest = await selectManifest(receipt, cancellationToken);
        var descriptor = manifest.Files.SingleOrDefault(
            candidate => string.Equals(candidate.Path, path, StringComparison.Ordinal));
        if (descriptor is null)
        {
            return null;
        }

        var document = await container.ReadOrDefaultAsync<ReleaseFileDocument>(
            FileId(state.ActiveManifestId, path),
            new PartitionKey(ReleasePartition(state.ActiveManifestId)),
            cancellationToken);
        if (document is null)
        {
            throw PersistedIntegrityFailure();
        }

        var expectedHash = NormalizeHash(descriptor.Hash);
        if (!string.Equals(document.ManifestId, state.ActiveManifestId, StringComparison.Ordinal)
            || !string.Equals(document.Channel, channel, StringComparison.Ordinal)
            || !string.Equals(document.ArtifactFileId, descriptor.Id, StringComparison.Ordinal)
            || !string.Equals(document.Path, descriptor.Path, StringComparison.Ordinal)
            || !string.Equals(document.Hash, expectedHash, StringComparison.Ordinal)
            || document.Size != descriptor.Size)
        {
            throw PersistedIntegrityFailure();
        }

        byte[] content;
        try
        {
            content = Convert.FromBase64String(document.ContentBase64);
        }
        catch (FormatException)
        {
            throw PersistedIntegrityFailure();
        }

        var actualHash = Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant();
        if (content.LongLength != descriptor.Size
            || !CryptographicOperations.FixedTimeEquals(
                Encoding.ASCII.GetBytes(actualHash),
                Encoding.ASCII.GetBytes(expectedHash)))
        {
            throw PersistedIntegrityFailure();
        }

        return new StoredContentReleaseFile(document.Path, content);
    }

    private async Task<ReleaseStateDocument?> ReadStateAsync(
        string environment,
        CancellationToken cancellationToken)
        => await context.PublicContentReleases.ReadOrDefaultAsync<ReleaseStateDocument>(
            StateId(environment),
            new PartitionKey(StatePartition),
            cancellationToken);

    private async Task<ContentArtifactManifest> GetPrivateManifestAsync(
        ContentReleaseReceipt receipt,
        CancellationToken cancellationToken)
    {
        var document = await context.PrivateContentReleases
            .ReadOrDefaultAsync<PrivateReleaseManifestDocument>(
               PrivateManifestId(receipt.ManifestId),
               new PartitionKey(ReleasePartition(receipt.ManifestId)),
               cancellationToken);
        if (document is null
            || !string.Equals(document.ManifestId, receipt.ManifestId, StringComparison.Ordinal)
            || !string.Equals(document.Fingerprint, receipt.Fingerprint, StringComparison.Ordinal)
            || !string.Equals(
               CompositeManifestId(
                   receipt.PublicManifestId,
                   document.PrivateManifest.ManifestId),
               receipt.ManifestId,
               StringComparison.Ordinal))
        {
            throw PersistedIntegrityFailure();
        }

        return document.PrivateManifest;
    }

    private async Task CreateImmutablePrivateManifestAsync(
        VerifiedContentRelease release,
        CancellationToken cancellationToken)
    {
        var partition = ReleasePartition(release.ManifestId);
        var document = new PrivateReleaseManifestDocument(
            PrivateManifestId(release.ManifestId),
            partition,
            release.ManifestId,
            release.Fingerprint,
            release.PrivateManifest);
        try
        {
            await context.PrivateContentReleases.CreateItemAsync(
               document,
               new PartitionKey(partition),
               cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await context.PrivateContentReleases
               .ReadOrDefaultAsync<PrivateReleaseManifestDocument>(
                   document.Id,
                   new PartitionKey(partition),
                   cancellationToken);
            if (existing is null
               || !string.Equals(
                   existing.ManifestId,
                   release.ManifestId,
                   StringComparison.Ordinal)
               || !string.Equals(
                   existing.Fingerprint,
                   release.Fingerprint,
                   StringComparison.Ordinal)
               || !string.Equals(
                   existing.PrivateManifest.ManifestId,
                   release.PrivateManifest.ManifestId,
                   StringComparison.Ordinal))
            {
                throw new ContentReleaseValidationException(
                    "Content release rejected: immutable_private_manifest_collision.");
            }
        }
    }

    private static async Task CreateImmutableAsync(
        Container container,
        ReleaseFileDocument document,
        string partition,
        VerifiedContentReleaseFile expected,
        CancellationToken cancellationToken)
    {
        try
        {
            await container.CreateItemAsync(
                document,
                new PartitionKey(partition),
                cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await container.ReadOrDefaultAsync<ReleaseFileDocument>(
                document.Id,
                new PartitionKey(partition),
                cancellationToken);
            if (existing is null
                || !string.Equals(existing.ManifestId, document.ManifestId, StringComparison.Ordinal)
                || !string.Equals(existing.Channel, expected.Channel, StringComparison.Ordinal)
                || !string.Equals(existing.ArtifactFileId, expected.Id, StringComparison.Ordinal)
                || !string.Equals(existing.Path, expected.Path, StringComparison.Ordinal)
                || !string.Equals(existing.Hash, expected.Hash, StringComparison.Ordinal)
                || existing.Size != expected.Size
                || !string.Equals(
                    existing.ContentBase64,
                    Convert.ToBase64String(expected.Content),
                    StringComparison.Ordinal))
            {
                throw new ContentReleaseValidationException(
                    "Content release rejected: immutable_file_collision.");
            }
        }
    }

    private static void EnsureSameRelease(
        ContentReleaseReceipt existing,
        VerifiedContentRelease requested)
    {
        if (!string.Equals(existing.Fingerprint, requested.Fingerprint, StringComparison.Ordinal)
            || !string.Equals(existing.ManifestId, requested.ManifestId, StringComparison.Ordinal)
            || !string.Equals(
                existing.PublicManifestId,
                requested.PublicManifestId,
                StringComparison.Ordinal))
        {
            throw new ContentReleaseValidationException(
                "Content release rejected: manifest_id_collision.");
        }
    }

    private static ContentReleaseValidationException PersistedIntegrityFailure()
        => new("Content release rejected: persisted_file_integrity_failure.");

    private static string NormalizeHash(string hash)
        => hash.StartsWith("sha256:", StringComparison.OrdinalIgnoreCase)
            ? hash[7..].ToLowerInvariant()
            : hash.ToLowerInvariant();

    private static string ReleasePartition(string manifestId) => $"release::{manifestId}";
    private static string ReceiptId(string manifestId) => $"release::{manifestId}";
    private static string PrivateManifestId(string manifestId)
        => $"release-private-manifest::{manifestId}";
    private static string StateId(string environment) => $"release-state::{environment}";

    private static string CompositeManifestId(
        string publicManifestId,
        string privateManifestId)
        => $"sha256:{Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            $"{publicManifestId}\n{privateManifestId}\n"))).ToLowerInvariant()}";

    private static string FileId(string manifestId, string path)
    {
        var pathHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(path)))
            .ToLowerInvariant();
        return $"release-file::{manifestId}::{pathHash}";
    }

    private sealed record ReleaseReceiptDocument(
        string Id,
        string PartitionKey,
        string ManifestId,
        string PublicManifestId,
        string Fingerprint,
        ContentArtifactManifest PublicManifest,
        DateTimeOffset ImportedAt)
    {
        public string Type => "contentRelease";

        public ContentReleaseReceipt ToModel()
            => new(
                ManifestId,
                PublicManifestId,
                Fingerprint,
                PublicManifest,
                ImportedAt);
    }

    private sealed record PrivateReleaseManifestDocument(
        string Id,
        string PartitionKey,
        string ManifestId,
        string Fingerprint,
        ContentArtifactManifest PrivateManifest)
    {
        public string Type => "contentReleasePrivateManifest";
    }

    private sealed record ReleaseFileDocument(
        string Id,
        string PartitionKey,
        string ManifestId,
        string Channel,
        string ArtifactFileId,
        string Path,
        string Hash,
        long Size,
        string ContentBase64)
    {
        public string Type => "contentReleaseFile";
    }

    private sealed record ReleaseStateDocument(
        string Id,
        string PartitionKey,
        string Environment,
        string ActiveManifestId,
        string? PreviousManifestId,
        DateTimeOffset ChangedAt,
        ContentReleaseOperation Operation,
        IReadOnlyList<ContentReleaseHistoryEntry> History,
        [property: JsonPropertyName("_etag")] string? ETag)
    {
        public string Type => "contentReleaseState";

        public ContentReleaseState ToModel()
            => new(
                Environment,
                ActiveManifestId,
                PreviousManifestId,
                ChangedAt,
                Operation,
                History);
    }
}
