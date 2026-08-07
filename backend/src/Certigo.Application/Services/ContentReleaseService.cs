using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

public interface IContentReleaseService
{
    Task<ContentReleaseImportResultDto> ImportAsync(
        ImportContentReleaseRequest request,
        CancellationToken cancellationToken = default);

    Task<ContentReleaseOperationResultDto> PromoteAsync(
        string manifestId,
        CancellationToken cancellationToken = default);

    Task<ContentReleaseOperationResultDto> RollbackAsync(
        string manifestId,
        ContentReleaseEnvironment environment,
        CancellationToken cancellationToken = default);

    Task<ContentPackageManifestDto> GetActivePublicManifestAsync(
        CancellationToken cancellationToken = default);
}

public sealed class ContentReleaseService(
    IContentReleaseRepository releases,
    IContentReleaseTelemetry telemetry,
    IClock clock) : IContentReleaseService
{
    public async Task<ContentReleaseImportResultDto> ImportAsync(
        ImportContentReleaseRequest request,
        CancellationToken cancellationToken = default)
    {
        try
        {
            ContentPackageIntegrity.Validate(request);
        }
        catch (ContentReleaseValidationException ex)
        {
            telemetry.TrackRejected(ex.Message);
            throw;
        }

        var manifestId = request.Public.Manifest.ManifestId;
        var privateManifestId = request.Private.Manifest.ManifestId;
        var existing = await releases.GetReleaseAsync(manifestId, cancellationToken);
        if (existing is not null)
        {
            EnsureSameRelease(existing, privateManifestId);
            var existingStaging = await RequireStateAsync(
                ContentReleaseEnvironment.Staging,
                cancellationToken);
            telemetry.TrackImported(manifestId, replayed: true);
            return ImportResult(existing, imported: false, existingStaging);
        }

        // All integrity checks complete before the first mutation. Private data is
        // written first so a partial infrastructure failure can never expose a
        // public package without its server-only correction set.
        await releases.WritePrivatePackageAsync(request.Private, cancellationToken);
        await releases.WritePublicPackageAsync(request.Public, cancellationToken);

        var imported = await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var concurrentExisting = await releases.GetReleaseAsync(manifestId, cancellationToken);
            if (concurrentExisting is not null)
            {
                EnsureSameRelease(concurrentExisting, privateManifestId);
                return false;
            }

            var staging = await releases.GetStateAsync(ContentReleaseEnvironment.Staging, cancellationToken);
            var nextStaging = NewState(
                ContentReleaseEnvironment.Staging,
                manifestId,
                staging?.ActiveManifestId,
                staging?.ETag);
            var release = new ContentReleaseRecord(
                ContentReleaseContracts.ReleaseDocumentId(manifestId),
                ContentReleaseContracts.ControlScope,
                manifestId,
                privateManifestId,
                clock.UtcNow);
            await releases.CommitImportAsync(release, nextStaging, cancellationToken);
            return true;
        }, cancellationToken: cancellationToken);

        var finalRelease = await releases.GetReleaseAsync(manifestId, cancellationToken)
            ?? throw new InvalidOperationException($"Imported release '{manifestId}' was not persisted.");
        var finalStaging = await RequireStateAsync(ContentReleaseEnvironment.Staging, cancellationToken);
        telemetry.TrackImported(manifestId, replayed: !imported);
        return ImportResult(finalRelease, imported, finalStaging);
    }

    public async Task<ContentReleaseOperationResultDto> PromoteAsync(
        string manifestId,
        CancellationToken cancellationToken = default)
    {
        EnsureManifestId(manifestId);
        await RequireReleaseAsync(manifestId, cancellationToken);
        var result = await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var staging = await RequireStateAsync(ContentReleaseEnvironment.Staging, cancellationToken);
            if (!string.Equals(staging.ActiveManifestId, manifestId, StringComparison.Ordinal))
            {
                throw new ContentReleaseConflictException(
                    $"Release '{manifestId}' is not the active staging release.");
            }

            var production = await releases.GetStateAsync(ContentReleaseEnvironment.Prod, cancellationToken);
            if (string.Equals(production?.ActiveManifestId, manifestId, StringComparison.Ordinal))
            {
                return OperationResult(production!, changed: false);
            }

            var nextProduction = NewState(
                ContentReleaseEnvironment.Prod,
                manifestId,
                production?.ActiveManifestId,
                production?.ETag);
            var saved = await releases.UpdateStateAsync(nextProduction, cancellationToken);
            return OperationResult(saved, changed: true);
        }, cancellationToken: cancellationToken);

        telemetry.TrackPromoted(manifestId, result.Changed);
        return result;
    }

    public async Task<ContentReleaseOperationResultDto> RollbackAsync(
        string manifestId,
        ContentReleaseEnvironment environment,
        CancellationToken cancellationToken = default)
    {
        EnsureManifestId(manifestId);
        if (!Enum.IsDefined(environment))
        {
            throw new ContentReleaseValidationException(
                $"Unsupported content release environment '{environment}'.");
        }

        await RequireReleaseAsync(manifestId, cancellationToken);
        var result = await OptimisticConcurrency.ExecuteAsync(async () =>
        {
            var current = await RequireStateAsync(environment, cancellationToken);
            if (string.Equals(current.ActiveManifestId, manifestId, StringComparison.Ordinal))
            {
                return OperationResult(current, changed: false);
            }

            if (!string.Equals(current.PreviousManifestId, manifestId, StringComparison.Ordinal))
            {
                throw new ContentReleaseConflictException(
                    $"Release '{manifestId}' is not the N-1 release for {environment}.");
            }

            var rolledBack = NewState(
                environment,
                manifestId,
                current.ActiveManifestId,
                current.ETag);
            var saved = await releases.UpdateStateAsync(rolledBack, cancellationToken);
            return OperationResult(saved, changed: true);
        }, cancellationToken: cancellationToken);

        telemetry.TrackRolledBack(manifestId, environment, result.Changed);
        return result;
    }

    public async Task<ContentPackageManifestDto> GetActivePublicManifestAsync(
        CancellationToken cancellationToken = default)
    {
        var production = await releases.GetStateAsync(ContentReleaseEnvironment.Prod, cancellationToken)
            ?? throw new ActiveContentManifestUnavailableException();
        return await releases.GetPublicManifestAsync(production.ActiveManifestId, cancellationToken)
            ?? throw new ActiveContentManifestUnavailableException();
    }

    private async Task<ContentReleaseRecord> RequireReleaseAsync(
        string manifestId,
        CancellationToken cancellationToken)
        => await releases.GetReleaseAsync(manifestId, cancellationToken)
           ?? throw new ContentReleaseNotFoundException(manifestId);

    private static void EnsureManifestId(string manifestId)
    {
        const string prefix = "sha256:";
        if (manifestId is null
            || !manifestId.StartsWith(prefix, StringComparison.Ordinal)
            || manifestId.Length != prefix.Length + 64
            || !manifestId[prefix.Length..].All(character =>
                character is >= '0' and <= '9' or >= 'a' and <= 'f'))
        {
            throw new ContentReleaseValidationException(
                $"Invalid content release manifestId '{manifestId}'.");
        }
    }

    private async Task<ContentReleaseStateRecord> RequireStateAsync(
        ContentReleaseEnvironment environment,
        CancellationToken cancellationToken)
        => await releases.GetStateAsync(environment, cancellationToken)
           ?? throw new ActiveContentManifestUnavailableException(environment);

    private static void EnsureSameRelease(ContentReleaseRecord existing, string privateManifestId)
    {
        if (!string.Equals(existing.PrivateManifestId, privateManifestId, StringComparison.Ordinal))
        {
            throw new ContentReleaseConflictException(
                $"Public manifest '{existing.ManifestId}' is already paired with a different private manifest.");
        }
    }

    private ContentReleaseStateRecord NewState(
        ContentReleaseEnvironment environment,
        string activeManifestId,
        string? previousManifestId,
        string? etag)
        => new(
            ContentReleaseContracts.StateDocumentId(environment),
            ContentReleaseContracts.ControlScope,
            environment,
            activeManifestId,
            previousManifestId,
            clock.UtcNow)
        {
            ETag = etag
        };

    private static ContentReleaseImportResultDto ImportResult(
        ContentReleaseRecord release,
        bool imported,
        ContentReleaseStateRecord staging)
        => new(
            release.ManifestId,
            release.PrivateManifestId,
            imported,
            StateDto(staging));

    private static ContentReleaseOperationResultDto OperationResult(
        ContentReleaseStateRecord state,
        bool changed)
        => new(
            state.Environment,
            state.ActiveManifestId,
            state.PreviousManifestId,
            changed);

    private static ContentReleaseStateDto StateDto(ContentReleaseStateRecord state)
        => new(state.Environment, state.ActiveManifestId, state.PreviousManifestId);
}
