using System.Net;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosContentReleaseStore(
    CosmosContext context,
    ContentReleaseLimits limits) : IContentReleaseStore
{
    private const string PointerId = "active";
    private static readonly JsonSerializerOptions PayloadJsonOptions = CreatePayloadJsonOptions();

    public async Task<ContentReleaseReceipt?> GetReceiptAsync(
        string releaseId,
        CancellationToken cancellationToken = default)
    {
        var receipt = await context.ContentControl.ReadOrDefaultAsync<ContentControlReceipt>(
            ReceiptId(releaseId),
            ControlPartition,
            cancellationToken);
        return receipt is null ? null : ToReceipt(receipt);
    }

    public async Task<ContentReleaseReceipt> StageAsync(
        ProjectedContentRelease release,
        string actorId,
        DateTimeOffset importedAt,
        CancellationToken cancellationToken = default)
    {
        var descriptor = release.Verified.Descriptor;
        var blobVersionDigest = HashBlobVersions(release.Verified.BlobVersions);
        var controlReceipt = new ContentControlReceipt(
            ReceiptId(descriptor.ReleaseId),
            ContentReleaseContracts.RuntimeScope,
            descriptor.ReleaseId,
            descriptor.PublicManifestId,
            descriptor.PrivateManifestId,
            release.Projection.Tracks.Count,
            release.Projection.Lessons.Count,
            release.Projection.AnswerKeys.Count,
            importedAt,
            actorId,
            release.Verified.BlobVersions.Count,
            blobVersionDigest);
        var existing = await GetReceiptAsync(descriptor.ReleaseId, cancellationToken);
        if (existing is not null)
        {
            EnsureEquivalent(existing, release);
            return existing;
        }

        EnsureProjectedDocumentsFit(release);
        EnsureCosmosItemFits(controlReceipt);
        await EnsurePublicManifestBindingAsync(descriptor, cancellationToken);

        await CreateImmutableAsync(
            context.ContentPublic,
            PublicDocument(
                descriptor.ReleaseId,
                "catalog",
                "catalog",
                "certification-catalog",
                null,
                "certification-catalog",
                null,
                release.Verified.Catalog),
            cancellationToken);
        await CreateImmutableAsync(
            context.ContentPublic,
            PublicDocument(
                descriptor.ReleaseId,
                $"manifest::{descriptor.PublicManifestId}",
                "manifest",
                descriptor.PublicManifestId,
                null,
                descriptor.PublicManifestId,
                null,
                release.Verified.PublicManifest),
            cancellationToken);

        foreach (var track in release.Projection.Tracks)
        {
            await CreateImmutableAsync(
                context.ContentPublic,
                PublicDocument(
                    descriptor.ReleaseId,
                    $"track::{track.RuntimeId}",
                    "track",
                    track.RuntimeId,
                    track.RuntimeId,
                    track.CanonicalId,
                    track.LegacyId,
                    track.Track,
                    track.LifecycleStatus),
                cancellationToken);
        }

        foreach (var lesson in release.Projection.Lessons)
        {
            await CreateImmutableAsync(
                context.ContentPublic,
                PublicDocument(
                    descriptor.ReleaseId,
                    $"lesson::{lesson.RuntimeId}",
                    "lesson",
                    lesson.RuntimeId,
                    lesson.Lesson.TrackId,
                    lesson.CanonicalId,
                    lesson.LegacyId,
                    lesson.Lesson,
                    lesson.LifecycleStatus),
                cancellationToken);
        }

        foreach (var answerKey in release.Projection.AnswerKeys)
        {
            await CreateImmutableAsync(
                context.ContentPrivate,
                PublicDocument(
                    descriptor.ReleaseId,
                    $"answerkey::{answerKey.RuntimeLessonId}",
                    "answerKey",
                    answerKey.RuntimeLessonId,
                    answerKey.AnswerKey.TrackId,
                    answerKey.CanonicalLessonId,
                    answerKey.LegacyLessonId,
                    answerKey.AnswerKey,
                    answerKey.LifecycleStatus),
                cancellationToken);
        }

        try
        {
            await context.ContentControl.CreateItemAsync(
                controlReceipt,
                ControlPartition,
                cancellationToken: cancellationToken);
        }
        catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.Conflict)
        {
            var concurrent = await GetReceiptAsync(descriptor.ReleaseId, cancellationToken)
                ?? throw new ContentReleaseStateException(
                    $"Release '{descriptor.ReleaseId}' conflicted without a readable receipt.");
            EnsureEquivalent(concurrent, release);
            return concurrent;
        }

        return ToReceipt(controlReceipt);
    }

    public Task<ActiveContentPointer?> GetActivePointerAsync(
        CancellationToken cancellationToken = default)
        => context.ContentControl.ReadOrDefaultAsync<ActiveContentPointer>(
            PointerId,
            ControlPartition,
            cancellationToken);

    public async Task<ContentSnapshot?> ResolveSnapshotAsync(
        string publicManifestId,
        CancellationToken cancellationToken = default)
    {
        var binding = await context.ContentControl.ReadOrDefaultAsync<PublicManifestReleaseBinding>(
            BindingId(publicManifestId),
            ControlPartition,
            cancellationToken);
        if (binding is null)
        {
            return null;
        }

        var receipt = await GetReceiptAsync(binding.ReleaseId, cancellationToken);
        var activation = await context.ContentControl.ReadOrDefaultAsync<ContentReleaseActivationRecord>(
            ActivationId(binding.ReleaseId),
            ControlPartition,
            cancellationToken);
        return receipt is null
            || activation is null
            || !string.Equals(receipt.PublicManifestId, binding.PublicManifestId, StringComparison.Ordinal)
            ? null
            : new ContentSnapshot(
                ContentReleaseContracts.VersionedSource,
                binding.ReleaseId,
                binding.PublicManifestId);
    }

    public async Task<ActiveContentPointer> PromoteAsync(
        string releaseId,
        string expectedETag,
        string actorId,
        DateTimeOffset promotedAt,
        CancellationToken cancellationToken = default)
    {
        var receipt = await GetReceiptAsync(releaseId, cancellationToken)
            ?? throw new ContentReleaseNotFoundException(
                $"Release '{releaseId}' has not completed immutable staging.");
        var current = await GetActivePointerAsync(cancellationToken);
        if (current is not null && !string.Equals(current.ETag, expectedETag, StringComparison.Ordinal))
        {
            throw new ContentReleasePreconditionException("The active content pointer ETag is stale.");
        }

        if (current is null && expectedETag != "*")
        {
            throw new ContentReleasePreconditionException(
                "The first content promotion requires If-Match: *.");
        }

        if (current is not null
            && string.Equals(current.ActiveReleaseId, releaseId, StringComparison.Ordinal))
        {
            await EnsureActivationRecordAsync(
                releaseId,
                actorId,
                promotedAt,
                cancellationToken);
            return current;
        }

        var activation = await context.ContentControl.ReadOrDefaultAsync<ContentReleaseActivationRecord>(
            ActivationId(releaseId),
            ControlPartition,
            cancellationToken);
        var replacement = new ActiveContentPointer(
            PointerId,
            ContentReleaseContracts.RuntimeScope,
            receipt.ReleaseId,
            receipt.PublicManifestId,
            current?.ActiveReleaseId,
            current?.ActivePublicManifestId,
            promotedAt,
            actorId);
        var audit = new ContentReleaseAuditRecord(
            $"promotion::{Guid.NewGuid():N}",
            ContentReleaseContracts.RuntimeScope,
            "promotion",
            releaseId,
            current?.ActiveReleaseId,
            actorId,
            promotedAt);
        var batch = context.ContentControl.CreateTransactionalBatch(ControlPartition);
        if (current is null)
        {
            batch.CreateItem(replacement);
        }
        else
        {
            batch.ReplaceItem(
                PointerId,
                replacement,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = expectedETag });
        }

        batch.CreateItem(audit);
        if (activation is null)
        {
            batch.CreateItem(new ContentReleaseActivationRecord(
                ActivationId(releaseId),
                ContentReleaseContracts.RuntimeScope,
                releaseId,
                promotedAt,
                actorId));
        }

        await ExecutePointerBatchAsync(batch, cancellationToken);
        return await GetActivePointerAsync(cancellationToken)
               ?? throw new ContentReleaseStateException("Content pointer disappeared after promotion.");
    }

    public async Task<ActiveContentPointer> RollbackAsync(
        string expectedETag,
        string actorId,
        DateTimeOffset rolledBackAt,
        CancellationToken cancellationToken = default)
    {
        var current = await GetActivePointerAsync(cancellationToken)
            ?? throw new ContentReleaseStateException("No active content release exists.");
        if (!string.Equals(current.ETag, expectedETag, StringComparison.Ordinal))
        {
            throw new ContentReleasePreconditionException("The active content pointer ETag is stale.");
        }

        if (current.PreviousReleaseId is null || current.PreviousPublicManifestId is null)
        {
            throw new ContentReleaseStateException("No N-1 content release is available for rollback.");
        }

        var replacement = new ActiveContentPointer(
            PointerId,
            ContentReleaseContracts.RuntimeScope,
            current.PreviousReleaseId,
            current.PreviousPublicManifestId,
            PreviousReleaseId: null,
            PreviousPublicManifestId: null,
            rolledBackAt,
            actorId);
        var audit = new ContentReleaseAuditRecord(
            $"rollback::{Guid.NewGuid():N}",
            ContentReleaseContracts.RuntimeScope,
            "rollback",
            replacement.ActiveReleaseId,
            current.ActiveReleaseId,
            actorId,
            rolledBackAt);
        var activation = await context.ContentControl.ReadOrDefaultAsync<ContentReleaseActivationRecord>(
            ActivationId(replacement.ActiveReleaseId),
            ControlPartition,
            cancellationToken);
        var batch = context.ContentControl.CreateTransactionalBatch(ControlPartition)
            .ReplaceItem(
                PointerId,
                replacement,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = expectedETag })
            .CreateItem(audit);
        if (activation is null)
        {
            batch.CreateItem(new ContentReleaseActivationRecord(
                ActivationId(replacement.ActiveReleaseId),
                ContentReleaseContracts.RuntimeScope,
                replacement.ActiveReleaseId,
                rolledBackAt,
                actorId));
        }

        await ExecutePointerBatchAsync(batch, cancellationToken);
        return await GetActivePointerAsync(cancellationToken)
               ?? throw new ContentReleaseStateException("Content pointer disappeared after rollback.");
    }

    public async Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
        CancellationToken cancellationToken = default)
    {
        var pointer = await GetActivePointerAsync(cancellationToken);
        if (pointer is null)
        {
            return null;
        }

        var document = await context.ContentPublic.ReadOrDefaultAsync<
            CosmosVersionedContentDocument<ContentPackageManifest>>(
            $"manifest::{pointer.ActivePublicManifestId}",
            new PartitionKey(pointer.ActiveReleaseId),
            cancellationToken);
        return document is null
            ? throw new ContentReleaseStateException(
                $"Active public manifest '{pointer.ActivePublicManifestId}' is missing.")
            : new ActivePublicManifestResult(
                document.Payload,
                pointer.ActiveReleaseId,
                pointer.ActivePublicManifestId);
    }

    private static CosmosVersionedContentDocument<T> PublicDocument<T>(
        string releaseId,
        string id,
        string documentType,
        string runtimeId,
        string? trackId,
        string canonicalId,
        string? legacyId,
        T payload,
        string? lifecycleStatus = null)
        where T : notnull
        => new(
            id,
            releaseId,
            documentType,
            runtimeId,
            trackId,
            canonicalId,
            legacyId,
            lifecycleStatus,
            HashPayload(payload),
            payload);

    private void EnsureProjectedDocumentsFit(ProjectedContentRelease release)
    {
        var descriptor = release.Verified.Descriptor;
        EnsureCosmosItemFits(PublicDocument(
            descriptor.ReleaseId,
            "catalog",
            "catalog",
            "certification-catalog",
            null,
            "certification-catalog",
            null,
            release.Verified.Catalog));
        EnsureCosmosItemFits(PublicDocument(
            descriptor.ReleaseId,
            $"manifest::{descriptor.PublicManifestId}",
            "manifest",
            descriptor.PublicManifestId,
            null,
            descriptor.PublicManifestId,
            null,
            release.Verified.PublicManifest));
        foreach (var track in release.Projection.Tracks)
        {
            EnsureCosmosItemFits(PublicDocument(
                descriptor.ReleaseId,
                $"track::{track.RuntimeId}",
                "track",
                track.RuntimeId,
                track.RuntimeId,
                track.CanonicalId,
                track.LegacyId,
                track.Track,
                track.LifecycleStatus));
        }

        foreach (var lesson in release.Projection.Lessons)
        {
            EnsureCosmosItemFits(PublicDocument(
                descriptor.ReleaseId,
                $"lesson::{lesson.RuntimeId}",
                "lesson",
                lesson.RuntimeId,
                lesson.Lesson.TrackId,
                lesson.CanonicalId,
                lesson.LegacyId,
                lesson.Lesson,
                lesson.LifecycleStatus));
        }

        foreach (var answerKey in release.Projection.AnswerKeys)
        {
            EnsureCosmosItemFits(PublicDocument(
                descriptor.ReleaseId,
                $"answerkey::{answerKey.RuntimeLessonId}",
                "answerKey",
                answerKey.RuntimeLessonId,
                answerKey.AnswerKey.TrackId,
                answerKey.CanonicalLessonId,
                answerKey.LegacyLessonId,
                answerKey.AnswerKey,
                answerKey.LifecycleStatus));
        }
    }

    private void EnsureCosmosItemFits<T>(T document)
    {
        var bytes = JsonSerializer.SerializeToUtf8Bytes(document, PayloadJsonOptions);
        if (bytes.Length > limits.MaxCosmosItemBytes)
        {
            throw new ContentReleaseValidationException(
                $"Projected Cosmos document is {bytes.Length} bytes; "
                + $"limit is {limits.MaxCosmosItemBytes}.");
        }
    }

    private static async Task CreateImmutableAsync<T>(
        Container container,
        CosmosVersionedContentDocument<T> document,
        CancellationToken cancellationToken)
        where T : notnull
    {
        try
        {
            await container.CreateItemAsync(
                document,
                new PartitionKey(document.ReleaseId),
                cancellationToken: cancellationToken);
        }
        catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await container.ReadOrDefaultAsync<CosmosVersionedContentDocument<T>>(
                document.Id,
                new PartitionKey(document.ReleaseId),
                cancellationToken);
            if (existing is null
                || !string.Equals(existing.PayloadHash, document.PayloadHash, StringComparison.Ordinal))
            {
                throw new ContentReleaseStateException(
                    $"Immutable release document '{document.Id}' conflicts with different content.");
            }
        }
    }

    private async Task EnsurePublicManifestBindingAsync(
        ContentReleaseDescriptor descriptor,
        CancellationToken cancellationToken)
    {
        var binding = new PublicManifestReleaseBinding(
            BindingId(descriptor.PublicManifestId),
            ContentReleaseContracts.RuntimeScope,
            descriptor.PublicManifestId,
            descriptor.PrivateManifestId,
            descriptor.ReleaseId);
        try
        {
            await context.ContentControl.CreateItemAsync(
                binding,
                ControlPartition,
                cancellationToken: cancellationToken);
        }
        catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await context.ContentControl.ReadOrDefaultAsync<PublicManifestReleaseBinding>(
                binding.Id,
                ControlPartition,
                cancellationToken);
            if (existing is null
                || !string.Equals(existing.ReleaseId, descriptor.ReleaseId, StringComparison.Ordinal)
                || !string.Equals(
                    existing.PrivateManifestId,
                    descriptor.PrivateManifestId,
                    StringComparison.Ordinal))
            {
                throw new ContentReleaseStateException(
                    $"Public manifest '{descriptor.PublicManifestId}' is permanently bound to another release.");
            }
        }
    }

    private static async Task ExecutePointerBatchAsync(
        TransactionalBatch batch,
        CancellationToken cancellationToken)
    {
        using var response = await batch.ExecuteAsync(cancellationToken);
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        if (response.StatusCode == HttpStatusCode.PreconditionFailed)
        {
            throw new ContentReleasePreconditionException("The active content pointer ETag is stale.");
        }

        if (response.StatusCode == HttpStatusCode.Conflict)
        {
            throw new ContentReleasePreconditionException(
                "The active content pointer changed concurrently.");
        }

        throw new ContentReleaseStateException(
            $"Content pointer transaction failed with HTTP {(int)response.StatusCode}.");
    }

    private async Task EnsureActivationRecordAsync(
        string releaseId,
        string actorId,
        DateTimeOffset activatedAt,
        CancellationToken cancellationToken)
    {
        var activation = new ContentReleaseActivationRecord(
            ActivationId(releaseId),
            ContentReleaseContracts.RuntimeScope,
            releaseId,
            activatedAt,
            actorId);
        try
        {
            await context.ContentControl.CreateItemAsync(
                activation,
                ControlPartition,
                cancellationToken: cancellationToken);
        }
        catch (CosmosException exception) when (exception.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await context.ContentControl.ReadOrDefaultAsync<ContentReleaseActivationRecord>(
                activation.Id,
                ControlPartition,
                cancellationToken);
            if (existing is null
                || !string.Equals(existing.ReleaseId, releaseId, StringComparison.Ordinal))
            {
                throw new ContentReleaseStateException(
                    $"Activation record '{activation.Id}' conflicts with another release.");
            }
        }
    }

    private static string HashPayload<T>(T payload)
        => Convert.ToHexString(SHA256.HashData(
                JsonSerializer.SerializeToUtf8Bytes(payload, PayloadJsonOptions)))
            .ToLowerInvariant();

    private static string HashBlobVersions(IEnumerable<ContentBlobVersion> versions)
    {
        var canonical = string.Join(
            "\n",
            versions
                .OrderBy(version => version.Path, StringComparer.Ordinal)
                .Select(version => $"{version.Path}\0{version.VersionId}\0{version.ETag}"));
        return Convert.ToHexString(SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(canonical)))
            .ToLowerInvariant();
    }

    private static JsonSerializerOptions CreatePayloadJsonOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
        return options;
    }

    private static ContentReleaseReceipt ToReceipt(ContentControlReceipt receipt)
        => new(
            receipt.Id,
            receipt.Scope,
            receipt.ReleaseId,
            receipt.PublicManifestId,
            receipt.PrivateManifestId,
            receipt.TrackCount,
            receipt.LessonCount,
            receipt.AnswerKeyCount,
            receipt.ImportedAt,
            receipt.ImportedBy,
            receipt.BlobVersionCount,
            receipt.BlobVersionDigest);

    private static void EnsureEquivalent(
        ContentReleaseReceipt existing,
        ProjectedContentRelease release)
    {
        if (!string.Equals(existing.PublicManifestId, release.Verified.Descriptor.PublicManifestId, StringComparison.Ordinal)
            || !string.Equals(existing.PrivateManifestId, release.Verified.Descriptor.PrivateManifestId, StringComparison.Ordinal)
            || existing.TrackCount != release.Projection.Tracks.Count
            || existing.LessonCount != release.Projection.Lessons.Count
            || existing.AnswerKeyCount != release.Projection.AnswerKeys.Count)
        {
            throw new ContentReleaseStateException(
                $"Release '{existing.ReleaseId}' already exists with different immutable metadata.");
        }
    }

    private static string ReceiptId(string releaseId) => $"release::{releaseId}";

    private static string BindingId(string publicManifestId) =>
        $"public-manifest::{publicManifestId}";

    private static string ActivationId(string releaseId) => $"activation::{releaseId}";

    private static PartitionKey ControlPartition =>
        new(ContentReleaseContracts.RuntimeScope);
}
