using System.Text;
using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class ContentReleaseServiceTests
{
    private const string ReleaseId =
        "sha256:0000000000000000000000000000000000000000000000000000000000000000";

    [Fact]
    public async Task Rejected_release_never_mutates_the_store()
    {
        var source = new InvalidReleaseSource();
        var store = new RecordingReleaseStore();
        var telemetry = new RecordingTelemetry();
        var service = new ContentReleaseService(
            new ContentContractVerifier(
                source,
                new AcceptingSchemaValidator(),
                ContentReleaseLimits.Default),
            new RuntimeContentProjector(),
            store,
            telemetry,
            new FixedClock());

        var action = () => service.ImportAsync(ReleaseId, "admin");

        await action.Should().ThrowAsync<ContentReleaseValidationException>();
        store.StageCalls.Should().Be(0);
        telemetry.Rejections.Should().Be(1);
    }

    [Fact]
    public async Task Existing_receipt_returns_idempotently_without_reading_blob()
    {
        var receipt = new ContentReleaseReceipt(
            $"release::{ReleaseId}",
            ContentReleaseContracts.RuntimeScope,
            ReleaseId,
            ReleaseId,
            ReleaseId,
            1,
            1,
            1,
            FixedClock.Now,
            "first-admin",
            0,
            new string('0', 64));
        var store = new RecordingReleaseStore { ExistingReceipt = receipt };
        var telemetry = new RecordingTelemetry();
        var service = new ContentReleaseService(
            new ContentContractVerifier(
                new ThrowingReleaseSource(),
                new AcceptingSchemaValidator(),
                ContentReleaseLimits.Default),
            new RuntimeContentProjector(),
            store,
            telemetry,
            new FixedClock());

        var result = await service.ImportAsync(ReleaseId, "second-admin");

        result.AlreadyImported.Should().BeTrue();
        result.Receipt.Should().Be(receipt);
        store.StageCalls.Should().Be(0);
        telemetry.Imports.Should().ContainSingle(value => value);
    }

    [Fact]
    public void Projected_ids_and_answer_items_must_be_unique_before_staging()
    {
        var verifier = new ContentContractVerifier(
            new ThrowingReleaseSource(),
            new AcceptingSchemaValidator(),
            ContentReleaseLimits.Default);
        var lesson = new Lesson("lesson", "track", "unit", "domain", "Lesson", 1, []);
        var duplicate = new RuntimeContentProjection(
            [],
            [
                new ProjectedLessonDocument("canonical-1", null, "lesson", "active", lesson),
                new ProjectedLessonDocument("canonical-2", null, "lesson", "active", lesson),
            ],
            []);

        var action = () => verifier.VerifyProjectedPublic(duplicate);

        action.Should().Throw<ContentReleaseValidationException>()
            .WithMessage("*Duplicate projected lesson runtime id*");
    }

    private sealed class InvalidReleaseSource : IContentReleaseSource
    {
        public Task<ContentBlobObject> ReadReleaseAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
        {
            var json = JsonSerializer.Serialize(new
            {
                schema = ContentReleaseContracts.ReleaseV1,
                algorithm = "sha256",
                canonicalization = "json-sorted-keys-compact-utf8",
                publicManifestId = ReleaseId,
                privateManifestId = ReleaseId,
                releaseId = ReleaseId,
            });
            return Task.FromResult(new ContentBlobObject(
                $"releases/{releaseId}/release.json",
                "version-1",
                "\"etag\"",
                true,
                Encoding.UTF8.GetBytes(json)));
        }

        public Task<ContentBlobObject> ReadManifestAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException("Manifest must not be read after invalid release.");

        public Task<ContentBlobObject> ReadFileAsync(
            ContentArtifact artifact,
            string manifestId,
            string path,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException();

        public Task<IReadOnlyList<string>> ListFilesAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException();
    }

    private sealed class ThrowingReleaseSource : IContentReleaseSource
    {
        public Task<ContentBlobObject> ReadReleaseAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException("Blob source must not be called for an imported release.");

        public Task<ContentBlobObject> ReadManifestAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException();

        public Task<ContentBlobObject> ReadFileAsync(
            ContentArtifact artifact,
            string manifestId,
            string path,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException();

        public Task<IReadOnlyList<string>> ListFilesAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => throw new InvalidOperationException();
    }

    private sealed class AcceptingSchemaValidator : IContentSchemaValidator
    {
        public void Validate(string schemaFileName, JsonElement value)
        {
        }
    }

    private sealed class RecordingReleaseStore : IContentReleaseStore
    {
        public ContentReleaseReceipt? ExistingReceipt { get; init; }
        public int StageCalls { get; private set; }

        public Task<ContentReleaseReceipt?> GetReceiptAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(ExistingReceipt);

        public Task<ContentReleaseReceipt> StageAsync(
            ProjectedContentRelease release,
            string actorId,
            DateTimeOffset importedAt,
            CancellationToken cancellationToken = default)
        {
            StageCalls++;
            throw new InvalidOperationException("Not expected.");
        }

        public Task<ActiveContentPointer?> GetActivePointerAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult<ActiveContentPointer?>(null);

        public Task<ContentSnapshot?> ResolveSnapshotAsync(
            string publicManifestId,
            CancellationToken cancellationToken = default)
            => Task.FromResult<ContentSnapshot?>(null);

        public Task<ActiveContentPointer> PromoteAsync(
            string releaseId,
            string expectedETag,
            string actorId,
            DateTimeOffset promotedAt,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer> RollbackAsync(
            string expectedETag,
            string actorId,
            DateTimeOffset rolledBackAt,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult<ActivePublicManifestResult?>(null);
    }

    private sealed class RecordingTelemetry : IContentReleaseTelemetry
    {
        public List<bool> Imports { get; } = [];
        public int Rejections { get; private set; }

        public void TrackImport(string releaseId, bool alreadyImported, TimeSpan duration)
            => Imports.Add(alreadyImported);

        public void TrackRejection(string releaseId, string reason, TimeSpan duration)
            => Rejections++;

        public void TrackPromotion(string releaseId, string? previousReleaseId)
        {
        }

        public void TrackRollback(string releaseId, string rolledBackFromReleaseId)
        {
        }
    }

    private sealed class FixedClock : IClock
    {
        public static DateTimeOffset Now { get; } =
            new(2026, 8, 19, 12, 0, 0, TimeSpan.Zero);

        public DateTimeOffset UtcNow => Now;
    }
}
