using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Certigo.Infrastructure.Cosmos;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class CosmosContentReleaseStoreIntegrationTests(CosmosEmulatorFixture fixture)
    : IClassFixture<CosmosEmulatorFixture>
{
    [CosmosEmulatorFact]
    public async Task Stage_promote_and_rollback_are_idempotent_and_etag_guarded()
    {
        var context = await fixture.GetContextAsync();
        var store = new CosmosContentReleaseStore(context, ContentReleaseLimits.Default);
        var first = Release('a', "track-a");
        var second = Release('b', "track-b");

        var firstReceipt = await store.StageAsync(first, "admin-1", DateTimeOffset.UtcNow);
        var replayed = await store.StageAsync(first, "admin-2", DateTimeOffset.UtcNow);
        replayed.Should().BeEquivalentTo(firstReceipt);
        (await store.ResolveSnapshotAsync(firstReceipt.PublicManifestId)).Should().BeNull();

        var firstPointer = await store.PromoteAsync(
            firstReceipt.ReleaseId,
            "*",
            "admin-1",
            DateTimeOffset.UtcNow);
        firstPointer.ETag.Should().NotBeNullOrWhiteSpace();

        var secondReceipt = await store.StageAsync(second, "admin-1", DateTimeOffset.UtcNow);
        var secondPointer = await store.PromoteAsync(
            secondReceipt.ReleaseId,
            firstPointer.ETag!,
            "admin-1",
            DateTimeOffset.UtcNow);
        secondPointer.ActiveReleaseId.Should().Be(secondReceipt.ReleaseId);
        secondPointer.PreviousReleaseId.Should().Be(firstReceipt.ReleaseId);

        var stalePromotion = () => store.PromoteAsync(
            firstReceipt.ReleaseId,
            firstPointer.ETag!,
            "admin-1",
            DateTimeOffset.UtcNow);
        await stalePromotion.Should().ThrowAsync<ContentReleasePreconditionException>();

        var rolledBack = await store.RollbackAsync(
            secondPointer.ETag!,
            "admin-1",
            DateTimeOffset.UtcNow);
        rolledBack.ActiveReleaseId.Should().Be(firstReceipt.ReleaseId);
        rolledBack.PreviousReleaseId.Should().BeNull();

        var secondRollback = () => store.RollbackAsync(
            rolledBack.ETag!,
            "admin-1",
            DateTimeOffset.UtcNow);
        await secondRollback.Should().ThrowAsync<ContentReleaseStateException>();
    }

    [CosmosEmulatorFact]
    public async Task Versioned_repository_reads_only_the_requested_release_partition()
    {
        var context = await fixture.GetContextAsync();
        var store = new CosmosContentReleaseStore(context, ContentReleaseLimits.Default);
        var first = await store.StageAsync(Release('c', "track-c"), "admin", DateTimeOffset.UtcNow);
        var second = await store.StageAsync(Release('d', "track-d"), "admin", DateTimeOffset.UtcNow);
        var repository = new CosmosVersionedContentRepository(context, store);
        var firstPointer = await store.PromoteAsync(
            first.ReleaseId,
            "*",
            "admin",
            DateTimeOffset.UtcNow);
        await store.PromoteAsync(
            second.ReleaseId,
            firstPointer.ETag!,
            "admin",
            DateTimeOffset.UtcNow);

        var firstSnapshot = await repository.ResolveSnapshotAsync(first.PublicManifestId);
        var secondSnapshot = await repository.ResolveSnapshotAsync(second.PublicManifestId);

        (await repository.ListTracksAsync(firstSnapshot)).Should()
            .ContainSingle(track => track.Id == "track-c");
        (await repository.ListTracksAsync(secondSnapshot)).Should()
            .ContainSingle(track => track.Id == "track-d");
        (await repository.GetTrackAsync(firstSnapshot, "track-d")).Should().BeNull();
    }

    [CosmosEmulatorFact]
    public async Task Public_manifest_is_permanently_bound_to_one_private_release()
    {
        var context = await fixture.GetContextAsync();
        var store = new CosmosContentReleaseStore(context, ContentReleaseLimits.Default);
        var first = Release('e', "track-e");
        var conflicting = Release('f', "track-f");
        conflicting = conflicting with
        {
            Verified = conflicting.Verified with
            {
                Descriptor = conflicting.Verified.Descriptor with
                {
                    PublicManifestId = first.Verified.Descriptor.PublicManifestId,
                },
                PublicManifest = conflicting.Verified.PublicManifest with
                {
                    ManifestId = first.Verified.Descriptor.PublicManifestId,
                    RootHash = first.Verified.Descriptor.PublicManifestId[7..],
                },
            },
        };
        await store.StageAsync(first, "admin", DateTimeOffset.UtcNow);

        var action = () => store.StageAsync(conflicting, "admin", DateTimeOffset.UtcNow);

        await action.Should().ThrowAsync<ContentReleaseStateException>()
            .WithMessage("*permanently bound*");
    }

    [CosmosEmulatorFact]
    public async Task Oversized_projection_is_rejected_before_manifest_binding_mutation()
    {
        var context = await fixture.GetContextAsync();
        var store = new CosmosContentReleaseStore(
            context,
            ContentReleaseLimits.Default with { MaxCosmosItemBytes = 32 });
        var release = Release('9', "track-size");

        var action = () => store.StageAsync(release, "admin", DateTimeOffset.UtcNow);

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*Projected Cosmos document*");
        (await store.ResolveSnapshotAsync(release.Verified.Descriptor.PublicManifestId))
            .Should().BeNull();
    }

    [CosmosEmulatorFact]
    public async Task Planned_content_is_not_accessible_through_point_or_private_reads()
    {
        var context = await fixture.GetContextAsync();
        var store = new CosmosContentReleaseStore(context, ContentReleaseLimits.Default);
        var receipt = await store.StageAsync(
            Release('8', "planned-track", "planned"),
            "admin",
            DateTimeOffset.UtcNow);
        await store.PromoteAsync(
            receipt.ReleaseId,
            "*",
            "admin",
            DateTimeOffset.UtcNow);
        var repository = new CosmosVersionedContentRepository(context, store);
        var snapshot = await repository.ResolveSnapshotAsync(receipt.PublicManifestId);

        (await repository.ListTracksAsync(snapshot)).Should().BeEmpty();
        (await repository.GetTrackAsync(snapshot, "planned-track")).Should().BeNull();
        (await repository.GetLessonAsync(snapshot, "planned-track", "planned-track-lesson"))
            .Should().BeNull();
        (await repository.GetAnswerKeyAsync(snapshot, "planned-track", "planned-track-lesson"))
            .Should().BeNull();
    }

    private static ProjectedContentRelease Release(
        char digestCharacter,
        string trackId,
        string lifecycleStatus = "active")
    {
        var digest = new string(digestCharacter, 64);
        var releaseId = $"sha256:{digest}";
        var publicManifestId = $"sha256:{new string(
            digestCharacter == 'f' ? 'e' : (char)(digestCharacter + 1),
            64)}";
        var privateManifestId = $"sha256:{new string(
            digestCharacter == 'e' ? 'd' : (char)(digestCharacter + 2),
            64)}";
        var manifest = new ContentPackageManifest(
            ContentReleaseContracts.PackageManifestV3,
            "public",
            "public",
            "sha256",
            "json-sorted-keys-compact-utf8-lf",
            0,
            [],
            publicManifestId,
            publicManifestId[7..]);
        var privateManifest = manifest with
        {
            Channel = "answerKey",
            Artifact = "private",
            ManifestId = privateManifestId,
            RootHash = privateManifestId[7..],
        };
        var catalog = new CertificationCatalogDocument(
            CertificationCatalogSchemas.SourceV1,
            new DateOnly(2026, 8, 19),
            new CertificationCatalogFreshness(30, new DateOnly(2026, 9, 18)),
            [],
            []);
        var graph = new CanonicalContentGraph(
            new Dictionary<string, CanonicalCertification>(),
            new Dictionary<string, CanonicalTrackResource>(),
            new Dictionary<string, CanonicalDomainResource>(),
            new Dictionary<string, CanonicalUnitResource>(),
            new Dictionary<string, CanonicalLessonResource>(),
            new Dictionary<string, CanonicalConceptResource>(),
            new Dictionary<string, CanonicalQuestion>(),
            new Dictionary<string, CanonicalSolution>());
        var track = new Track(
            trackId,
            trackId.ToUpperInvariant(),
            trackId,
            "summary",
            [new ExamDomain("domain", "Domain", 1)],
            [new TrackUnit("unit", "domain", "Unit", [$"{trackId}-lesson"])],
            "foundational");
        var lesson = new Lesson(
            $"{trackId}-lesson",
            trackId,
            "unit",
            "domain",
            "Lesson",
            5,
            [
                new LessonBlock(
                    "check",
                    "concept",
                    Check: new LessonCheck(
                        $"{trackId}-item",
                        "concept",
                        ItemType.Mcq,
                        "Prompt",
                        [new CheckOption("a", "A"), new CheckOption("b", "B")])),
            ]);
        var key = new LessonAnswerKey(
            lesson.Id,
            trackId,
            "domain",
            [new AnswerKeyItem($"{trackId}-item", "concept", ItemType.Mcq, 1, ["a"], "Because")]);
        var verified = new VerifiedContentRelease(
            new ContentReleaseDescriptor(
                ContentReleaseContracts.ReleaseV1,
                "sha256",
                "json-sorted-keys-compact-utf8",
                publicManifestId,
                privateManifestId,
                releaseId),
            manifest,
            privateManifest,
            catalog,
            graph,
            new Dictionary<string, System.Text.Json.JsonElement>(),
            new Dictionary<string, System.Text.Json.JsonElement>(),
            []);
        return new ProjectedContentRelease(
            verified,
            new RuntimeContentProjection(
                [new ProjectedTrackDocument(trackId, null, trackId, lifecycleStatus, track)],
                [
                    new ProjectedLessonDocument(
                        lesson.Id,
                        null,
                        lesson.Id,
                        lifecycleStatus,
                        lesson),
                ],
                [
                    new ProjectedAnswerKeyDocument(
                        lesson.Id,
                        null,
                        lesson.Id,
                        lifecycleStatus,
                        key),
                ]));
    }
}
