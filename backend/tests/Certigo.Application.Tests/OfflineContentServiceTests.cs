using System.Text.Json;
using System.Text.Json.Serialization;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class OfflineContentServiceTests
{
    private const string CurrentManifestId =
        "sha256:1111111111111111111111111111111111111111111111111111111111111111";
    private const string PreviousManifestId =
        "sha256:2222222222222222222222222222222222222222222222222222222222222222";

    [Fact]
    public async Task Manifest_is_public_deterministic_and_matches_pinned_payload_bytes()
    {
        var fixture = CreateFixture();

        var first = await fixture.Offline.GetActiveManifestAsync();
        var second = await fixture.Offline.GetActiveManifestAsync();

        first.Should().BeEquivalentTo(second, options => options.WithStrictOrdering());
        first.Schema.Should().Be(ContentReleaseContracts.OfflineManifestV1);
        first.ManifestId.Should().Be(CurrentManifestId);
        first.Version.Should().MatchRegex("^sha256:[0-9a-f]{64}$");
        first.SourceSchema.Should().Be(ContentReleaseContracts.PackageManifestV3);
        first.FileCount.Should().Be(3);
        first.Files.Select(resource => resource.ResourceType)
            .Should().Equal("catalog", "lesson", "lesson");
        first.Files.Select(resource => resource.Id)
            .Should().Equal("catalog", "lesson-a", "lesson-b");
        first.Files.Select(resource => resource.Path)
            .Should().Equal(
                "catalog/tracks.json",
                "tracks/track-a/lessons/lesson-a.json",
                "tracks/track-b/lessons/lesson-b.json");

        foreach (var descriptor in first.Files)
        {
            var payload = descriptor.ResourceType == "catalog"
                ? await fixture.Offline.GetCatalogAsync(CurrentManifestId)
                : await fixture.Offline.GetLessonAsync(
                    CurrentManifestId,
                    descriptor.TrackId!,
                    descriptor.Id);
            payload.Should().NotBeNull();
            payload!.Sha256.Should().Be(descriptor.Hash);
            descriptor.Size.Should().Be(payload.Content.Length);
            descriptor.Hash.Should().MatchRegex("^[0-9a-f]{64}$");
            var payloadJson = System.Text.Encoding.UTF8
                .GetString(payload.Content.Span)
                .ToLowerInvariant();
            payloadJson.Should().NotContain("answerkey");
            payloadJson.Should().NotContain("correct");
            payloadJson.Should().NotContain("rationale");
            payloadJson.Should().NotContain("explanation");
            payloadJson.Should().NotContain("solution");
        }

        var serializedManifest = JsonSerializer.Serialize(first, TestSerializer.Options);
        using var manifestDocument = JsonDocument.Parse(serializedManifest);
        manifestDocument.RootElement.EnumerateObject().Select(property => property.Name)
            .Should().Equal(
                "schema",
                "manifestId",
                "version",
                "sourceSchema",
                "fileCount",
                "files");
        var allowedFileFields = new HashSet<string>(
            ["id", "path", "resourceType", "hash", "size", "trackId"],
            StringComparer.Ordinal);
        foreach (var file in manifestDocument.RootElement.GetProperty("files").EnumerateArray())
        {
            file.EnumerateObject().Should().OnlyContain(property =>
                allowedFileFields.Contains(property.Name));
        }
        manifestDocument.RootElement.GetProperty("files")[0]
            .TryGetProperty("trackId", out _)
            .Should().BeFalse();

        var manifestJson = serializedManifest.ToLowerInvariant();
        manifestJson.Should().NotContain("releaseid");
        manifestJson.Should().NotContain("privatemanifestid");
        manifestJson.Should().NotContain("answerkey");
        manifestJson.Should().NotContain("correct");
        manifestJson.Should().NotContain("rationale");
        manifestJson.Should().NotContain("explanation");
        manifestJson.Should().NotContain("solution");
    }

    [Fact]
    public async Task Pinned_lesson_can_resolve_a_previously_activated_manifest()
    {
        var fixture = CreateFixture();

        var payload = await fixture.Offline.GetLessonAsync(
            PreviousManifestId,
            "track-a",
            "lesson-a");

        payload.Should().NotBeNull();
        var lesson = JsonSerializer.Deserialize<Lesson>(payload!.Content.Span, TestSerializer.Options);
        lesson!.Title.Should().Be("Previous lesson");
        payload.PublicManifestId.Should().Be(PreviousManifestId);
    }

    [Fact]
    public async Task Missing_or_invalid_manifest_fails_closed_without_using_active_content()
    {
        var fixture = CreateFixture();
        var missing =
            "sha256:3333333333333333333333333333333333333333333333333333333333333333";

        var invalidAction = () => fixture.Offline.GetCatalogAsync("not-a-manifest");
        var missingAction = () => fixture.Offline.GetCatalogAsync(missing);

        await invalidAction.Should().ThrowAsync<ContentReleaseValidationException>();
        await missingAction.Should().ThrowAsync<ContentReleaseNotFoundException>();
        fixture.Repository.ActiveResolutionCount.Should().Be(0);
    }

    private static Fixture CreateFixture()
    {
        var repository = new VersionedRepository();
        repository.Add(
            CurrentManifestId,
            TrackWithLesson("track-b", "lesson-b"),
            LessonPayload("lesson-b", "track-b", "Current B"));
        repository.Add(
            CurrentManifestId,
            TrackWithLesson("track-a", "lesson-a"),
            LessonPayload("lesson-a", "track-a", "Current A"));
        repository.Add(
            PreviousManifestId,
            TrackWithLesson("track-a", "lesson-a"),
            LessonPayload("lesson-a", "track-a", "Previous lesson"));
        var serializer = new TestSerializer();
        var contentService = new ContentService(repository);
        var releaseService = new ActiveReleaseService(CurrentManifestId);
        return new Fixture(
            new OfflineContentService(repository, contentService, releaseService, serializer),
            repository);
    }

    private static Track TrackWithLesson(string trackId, string lessonId)
        => new(
            trackId,
            trackId.ToUpperInvariant(),
            trackId,
            "Summary",
            [new ExamDomain("domain-1", "Domain", 1)],
            [new TrackUnit("unit-1", "domain-1", "Unit", [lessonId])],
            "associate");

    private static Lesson LessonPayload(string lessonId, string trackId, string title)
        => new(
            lessonId,
            trackId,
            "unit-1",
            "domain-1",
            title,
            5,
            [
                new LessonBlock(
                    "check",
                    "concept-1",
                    Check: new LessonCheck(
                        "question-1",
                        "concept-1",
                        ItemType.Mcq,
                        "Public stem",
                        [new CheckOption("option-1", "Public option")])),
            ]);

    private sealed record Fixture(
        OfflineContentService Offline,
        VersionedRepository Repository);

    private sealed class TestSerializer : IContentPayloadSerializer
    {
        public static JsonSerializerOptions Options { get; } = CreateOptions();

        public byte[] Serialize<T>(T value) => JsonSerializer.SerializeToUtf8Bytes(value, Options);

        private static JsonSerializerOptions CreateOptions()
        {
            var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
            options.Converters.Add(new JsonStringEnumConverter(JsonNamingPolicy.CamelCase));
            return options;
        }
    }

    private sealed class ActiveReleaseService(string publicManifestId) : IContentReleaseService
    {
        public Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult<ActivePublicManifestResult?>(new(
                new ContentPackageManifest(
                    ContentReleaseContracts.PackageManifestV3,
                    "public",
                    "public",
                    "sha256",
                    "json-sorted-keys-compact-utf8-lf",
                    0,
                    [],
                    publicManifestId,
                    publicManifestId[7..]),
                publicManifestId));

        public Task<ContentImportResult> ImportAsync(
            string releaseId,
            string actorId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer?> GetPointerAsync(
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer> PromoteAsync(
            string releaseId,
            string expectedETag,
            string actorId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer> RollbackAsync(
            string expectedETag,
            string actorId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();
    }

    private sealed class VersionedRepository : IContentRepository
    {
        private readonly Dictionary<string, List<Track>> _tracks = new(StringComparer.Ordinal);
        private readonly Dictionary<(string ManifestId, string LessonId), Lesson> _lessons = new();

        public int ActiveResolutionCount { get; private set; }

        public void Add(string manifestId, Track track, Lesson lesson)
        {
            if (!_tracks.TryGetValue(manifestId, out var tracks))
            {
                tracks = [];
                _tracks[manifestId] = tracks;
            }

            tracks.Add(track);
            _lessons[(manifestId, lesson.Id)] = lesson;
        }

        public Task<ContentSnapshot> ResolveActiveSnapshotAsync(
            CancellationToken cancellationToken = default)
        {
            ActiveResolutionCount++;
            return Task.FromResult(Snapshot(CurrentManifestId));
        }

        public Task<ContentSnapshot> ResolveSnapshotAsync(
            string publicManifestId,
            CancellationToken cancellationToken = default)
            => _tracks.ContainsKey(publicManifestId)
                ? Task.FromResult(Snapshot(publicManifestId))
                : throw new ContentReleaseNotFoundException(
                    $"Public content manifest '{publicManifestId}' is not imported.");

        public Task<CertificationCatalogDocument?> GetCertificationCatalogAsync(
            ContentSnapshot snapshot,
            CancellationToken cancellationToken = default)
            => Task.FromResult<CertificationCatalogDocument?>(null);

        public Task<Lesson?> GetLessonAsync(
            ContentSnapshot snapshot,
            string trackId,
            string lessonId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(
                _lessons.GetValueOrDefault((snapshot.PublicManifestId!, lessonId)) is { } lesson
                && lesson.TrackId == trackId
                    ? lesson
                    : null);

        public Task<IReadOnlyList<Track>> ListTracksAsync(
            ContentSnapshot snapshot,
            CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<Track>>(_tracks[snapshot.PublicManifestId!]);

        public Task<Track?> GetTrackAsync(
            string trackId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<Lesson?> GetLessonAsync(
            string trackId,
            string lessonId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<LessonAnswerKey?> GetAnswerKeyAsync(
            string trackId,
            string lessonId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<IReadOnlyList<LessonAnswerKey>> ListAnswerKeysAsync(
            string trackId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<IReadOnlyList<Track>> ListTracksAsync(
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        private static ContentSnapshot Snapshot(string manifestId)
            => new(ContentReleaseContracts.VersionedSource, $"release::{manifestId}", manifestId);
    }
}
