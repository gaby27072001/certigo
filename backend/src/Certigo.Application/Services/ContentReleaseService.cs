using System.Diagnostics;
using Certigo.Application.Abstractions;
using Certigo.Domain.Content;

namespace Certigo.Application.Services;

public interface IContentReleaseService
{
    Task<ContentImportResult> ImportAsync(
        string releaseId,
        string actorId,
        CancellationToken cancellationToken = default);

    Task<ActiveContentPointer?> GetPointerAsync(CancellationToken cancellationToken = default);

    Task<ActiveContentPointer> PromoteAsync(
        string releaseId,
        string expectedETag,
        string actorId,
        CancellationToken cancellationToken = default);

    Task<ActiveContentPointer> RollbackAsync(
        string expectedETag,
        string actorId,
        CancellationToken cancellationToken = default);

    Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
        CancellationToken cancellationToken = default);
}

public sealed class ContentReleaseService(
    ContentContractVerifier verifier,
    RuntimeContentProjector projector,
    IContentReleaseStore store,
    IContentReleaseTelemetry telemetry,
    IClock clock) : IContentReleaseService
{
    public async Task<ContentImportResult> ImportAsync(
        string releaseId,
        string actorId,
        CancellationToken cancellationToken = default)
    {
        var elapsed = Stopwatch.StartNew();
        var existing = await store.GetReceiptAsync(releaseId, cancellationToken);
        if (existing is not null)
        {
            telemetry.TrackImport(releaseId, alreadyImported: true, elapsed.Elapsed);
            return new ContentImportResult(existing, AlreadyImported: true);
        }

        try
        {
            var verified = await verifier.VerifyReleaseAsync(releaseId, cancellationToken);
            var projection = projector.Project(verified.Graph);
            verifier.VerifyProjectedPublic(projection);
            var receipt = await store.StageAsync(
                new ProjectedContentRelease(verified, projection),
                actorId,
                clock.UtcNow,
                cancellationToken);
            telemetry.TrackImport(releaseId, alreadyImported: false, elapsed.Elapsed);
            return new ContentImportResult(receipt, AlreadyImported: false);
        }
        catch (ContentReleaseValidationException)
        {
            telemetry.TrackRejection(releaseId, "validation", elapsed.Elapsed);
            throw;
        }
        catch (ContentProjectionException exception)
        {
            telemetry.TrackRejection(releaseId, "projection", elapsed.Elapsed);
            throw new ContentReleaseValidationException(
                "The verified canonical graph could not be projected to runtime content.",
                exception);
        }
    }

    public Task<ActiveContentPointer?> GetPointerAsync(CancellationToken cancellationToken = default)
        => store.GetActivePointerAsync(cancellationToken);

    public async Task<ActiveContentPointer> PromoteAsync(
        string releaseId,
        string expectedETag,
        string actorId,
        CancellationToken cancellationToken = default)
    {
        var previous = await store.GetActivePointerAsync(cancellationToken);
        var pointer = await store.PromoteAsync(
            releaseId,
            expectedETag,
            actorId,
            clock.UtcNow,
            cancellationToken);
        telemetry.TrackPromotion(releaseId, previous?.ActiveReleaseId);
        return pointer;
    }

    public async Task<ActiveContentPointer> RollbackAsync(
        string expectedETag,
        string actorId,
        CancellationToken cancellationToken = default)
    {
        var previous = await store.GetActivePointerAsync(cancellationToken)
            ?? throw new ContentReleaseStateException("No active content release exists.");
        var pointer = await store.RollbackAsync(
            expectedETag,
            actorId,
            clock.UtcNow,
            cancellationToken);
        telemetry.TrackRollback(pointer.ActiveReleaseId, previous.ActiveReleaseId);
        return pointer;
    }

    public Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
        CancellationToken cancellationToken = default)
        => store.GetActivePublicManifestAsync(cancellationToken);
}
