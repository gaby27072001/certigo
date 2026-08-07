using System.Net;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosContentReleaseRepository(CosmosContext context) : IContentReleaseRepository
{
    public Task<ContentReleaseRecord?> GetReleaseAsync(
        string manifestId,
        CancellationToken cancellationToken = default)
        => context.ContentReleases.ReadOrDefaultAsync<ContentReleaseRecord>(
            ContentReleaseContracts.ReleaseDocumentId(manifestId),
            new PartitionKey(ContentReleaseContracts.ControlScope),
            cancellationToken);

    public Task<ContentReleaseStateRecord?> GetStateAsync(
        ContentReleaseEnvironment environment,
        CancellationToken cancellationToken = default)
        => context.ContentReleases.ReadOrDefaultAsync<ContentReleaseStateRecord>(
            ContentReleaseContracts.StateDocumentId(environment),
            new PartitionKey(ContentReleaseContracts.ControlScope),
            cancellationToken);

    public Task WritePublicPackageAsync(
        ContentPackageDto package,
        CancellationToken cancellationToken = default)
        => WritePackageAsync(
            context.ContentPublic,
            package.Manifest.ManifestId,
            package,
            ContentReleaseContracts.PublicManifestDocumentId,
            "question",
            cancellationToken);

    public Task WritePrivatePackageAsync(
        ContentPackageDto package,
        CancellationToken cancellationToken = default)
        => WritePackageAsync(
            context.ContentPrivate,
            package.Manifest.ManifestId,
            package,
            ContentReleaseContracts.PrivateManifestDocumentId,
            "solution",
            cancellationToken);

    public async Task CommitImportAsync(
        ContentReleaseRecord release,
        ContentReleaseStateRecord stagingState,
        CancellationToken cancellationToken = default)
    {
        var batch = context.ContentReleases
            .CreateTransactionalBatch(new PartitionKey(ContentReleaseContracts.ControlScope))
            .CreateItem(release);

        batch = string.IsNullOrEmpty(stagingState.ETag)
            ? batch.CreateItem(stagingState)
            : batch.ReplaceItem(
                stagingState.Id,
                stagingState,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = stagingState.ETag });

        using var response = await batch.ExecuteAsync(cancellationToken);
        var hasConflict = response.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed
                          || Enumerable.Range(0, response.Count).Any(index =>
                              response[index].StatusCode is
                                  HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed);
        if (hasConflict)
        {
            throw new ConcurrencyConflictException(
                $"Content release '{release.ManifestId}' was imported concurrently.");
        }

        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(
                $"Cosmos content release transaction failed with status {(int)response.StatusCode} " +
                $"({response.StatusCode}): {response.ErrorMessage}");
        }
    }

    public async Task<ContentReleaseStateRecord> UpdateStateAsync(
        ContentReleaseStateRecord state,
        CancellationToken cancellationToken = default)
    {
        try
        {
            ItemResponse<ContentReleaseStateRecord> response;
            if (string.IsNullOrEmpty(state.ETag))
            {
                response = await context.ContentReleases.CreateItemAsync(
                    state,
                    new PartitionKey(ContentReleaseContracts.ControlScope),
                    cancellationToken: cancellationToken);
            }
            else
            {
                response = await context.ContentReleases.ReplaceItemAsync(
                    state,
                    state.Id,
                    new PartitionKey(ContentReleaseContracts.ControlScope),
                    new ItemRequestOptions { IfMatchEtag = state.ETag },
                    cancellationToken);
            }

            return response.Resource;
        }
        catch (CosmosException ex) when (
            ex.StatusCode is HttpStatusCode.Conflict or HttpStatusCode.PreconditionFailed)
        {
            throw new ConcurrencyConflictException(
                $"Content release state '{state.Environment}' was modified concurrently.");
        }
    }

    public async Task<ContentPackageManifestDto?> GetPublicManifestAsync(
        string manifestId,
        CancellationToken cancellationToken = default)
    {
        var stored = await context.ContentPublic.ReadOrDefaultAsync<StoredContentManifestRecord>(
            ContentReleaseContracts.PublicManifestDocumentId,
            new PartitionKey(manifestId),
            cancellationToken);
        return stored?.Manifest;
    }

    private static async Task WritePackageAsync(
        Container container,
        string releaseId,
        ContentPackageDto package,
        string manifestDocumentId,
        string itemType,
        CancellationToken cancellationToken)
    {
        var manifestDocument = new StoredContentManifestRecord(
            manifestDocumentId,
            releaseId,
            "manifest",
            package.Manifest);
        await container.UpsertItemAsync(
            manifestDocument,
            new PartitionKey(releaseId),
            cancellationToken: cancellationToken);

        var entries = package.Manifest.Files.ToDictionary(entry => entry.Path, StringComparer.Ordinal);
        foreach (var file in package.Files)
        {
            var entry = entries[file.Path];
            var document = new StoredContentFileRecord(
                $"{itemType}::{entry.Id}",
                releaseId,
                package.Manifest.ManifestId,
                itemType,
                entry.Path,
                entry.Hash,
                entry.Size,
                file.Content.Clone());
            await container.UpsertItemAsync(
                document,
                new PartitionKey(releaseId),
                cancellationToken: cancellationToken);
        }
    }
}
