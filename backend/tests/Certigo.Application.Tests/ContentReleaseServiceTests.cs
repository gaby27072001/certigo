using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
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
    public async Task Invalid_release_id_is_rejected_before_receipt_lookup()
    {
        var store = new RecordingReleaseStore();
        var service = new ContentReleaseService(
            new ContentContractVerifier(
                new ThrowingReleaseSource(),
                new AcceptingSchemaValidator(),
                ContentReleaseLimits.Default),
            new RuntimeContentProjector(),
            store,
            new RecordingTelemetry(),
            new FixedClock());

        var action = () => service.ImportAsync("not-a-release-id", "admin");

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("releaseId must be a lowercase sha256 content identity.");
        store.GetReceiptCalls.Should().Be(0);
    }

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

    [Theory]
    [InlineData("questions/question%25.json")]
    [InlineData("questions/question\u001f.json")]
    public async Task Import_rejects_paths_that_public_delivery_cannot_address(string path)
    {
        var source = new UnsafePathReleaseSource(path);
        var verifier = new ContentContractVerifier(
            source,
            new AcceptingSchemaValidator(),
            ContentReleaseLimits.Default);

        var action = () => verifier.VerifyReleaseAsync(source.ReleaseId);

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*unsafe or non-canonical*");
    }

    [Fact]
    public async Task Import_rejects_paths_longer_than_the_public_delivery_limit()
    {
        var source = new UnsafePathReleaseSource($"questions/{new string('a', 1010)}.json");
        var verifier = new ContentContractVerifier(
            source,
            new AcceptingSchemaValidator(),
            ContentReleaseLimits.Default);

        var action = () => verifier.VerifyReleaseAsync(source.ReleaseId);

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*unsafe or non-canonical*");
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

    [Fact]
    public async Task V5_cross_rule_violation_is_rejected_before_staging()
    {
        var source = V5ReleaseSource.WithOrderingX8Violation();
        var store = new RecordingReleaseStore();
        var service = new ContentReleaseService(
            new ContentContractVerifier(
                source,
                new AcceptingSchemaValidator(),
                ContentReleaseLimits.Default),
            new RuntimeContentProjector(),
            store,
            new RecordingTelemetry(),
            new FixedClock());

        var action = () => service.ImportAsync(source.ReleaseId, "admin");

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*[v5:X8]*");
        store.StageCalls.Should().Be(0);
    }

    [Fact]
    public async Task Public_pairs_key_is_rejected_before_staging()
    {
        var source = V5ReleaseSource.WithPublicPairsLeak();
        var store = new RecordingReleaseStore();
        var service = new ContentReleaseService(
            new ContentContractVerifier(
                source,
                new AcceptingSchemaValidator(),
                ContentReleaseLimits.Default),
            new RuntimeContentProjector(),
            store,
            new RecordingTelemetry(),
            new FixedClock());

        var action = () => service.ImportAsync(source.ReleaseId, "admin");

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*forbidden key*pairs*");
        store.StageCalls.Should().Be(0);
    }

    [Fact]
    public void Projected_answer_item_ids_must_be_globally_unique_before_staging()
    {
        var verifier = new ContentContractVerifier(
            new ThrowingReleaseSource(),
            new AcceptingSchemaValidator(),
            ContentReleaseLimits.Default);
        var item = new AnswerKeyItem(
            "shared-item",
            "concept",
            ItemType.Mcq,
            2,
            ["correct"],
            "Explanation");
        var projection = new RuntimeContentProjection(
            [],
            [],
            [
                new ProjectedAnswerKeyDocument(
                    "canonical-1",
                    null,
                    "lesson-1",
                    "active",
                    new LessonAnswerKey("lesson-1", "track", "domain", [item])),
                new ProjectedAnswerKeyDocument(
                    "canonical-2",
                    null,
                    "lesson-2",
                    "active",
                    new LessonAnswerKey("lesson-2", "track", "domain", [item])),
            ]);

        var action = () => verifier.VerifyProjectedPublic(projection);

        action.Should().Throw<ContentReleaseValidationException>()
            .WithMessage("*Duplicate projected answer item id 'shared-item'*");
    }

    private sealed class V5ReleaseSource : IContentReleaseSource
    {
        private readonly Dictionary<string, byte[]> _publicFiles;
        private readonly Dictionary<string, byte[]> _privateFiles;
        private readonly byte[] _releaseBytes;
        private readonly byte[] _publicManifestBytes;
        private readonly byte[] _privateManifestBytes;

        private V5ReleaseSource(string questionJson, string solutionJson)
        {
            _publicFiles = new Dictionary<string, byte[]>(StringComparer.Ordinal)
            {
                ["catalog/certifications.json"] = Encoding.UTF8.GetBytes(ReadCatalog()),
                ["questions/microsoft/az-104/v5-ordering.json"] = Encoding.UTF8.GetBytes(questionJson),
            };
            _privateFiles = new Dictionary<string, byte[]>(StringComparer.Ordinal)
            {
                ["solutions/microsoft/az-104/v5-ordering.json"] = Encoding.UTF8.GetBytes(solutionJson),
            };
            var publicCanonical = ManifestCanonical("public", "public", _publicFiles, ContentArtifact.Public);
            var privateCanonical = ManifestCanonical("answerKey", "private", _privateFiles, ContentArtifact.Private);
            var publicManifestHash = Sha256(publicCanonical);
            var privateManifestHash = Sha256(privateCanonical);
            PublicManifestId = $"sha256:{publicManifestHash}";
            PrivateManifestId = $"sha256:{privateManifestHash}";
            _publicManifestBytes = Encoding.UTF8.GetBytes(ManifestPayload(
                "public",
                "public",
                _publicFiles,
                ContentArtifact.Public,
                PublicManifestId,
                publicManifestHash));
            _privateManifestBytes = Encoding.UTF8.GetBytes(ManifestPayload(
                "answerKey",
                "private",
                _privateFiles,
                ContentArtifact.Private,
                PrivateManifestId,
                privateManifestHash));
            var releaseCanonical =
                $$"""{"algorithm":"sha256","canonicalization":"json-sorted-keys-compact-utf8","privateManifestId":"{{PrivateManifestId}}","publicManifestId":"{{PublicManifestId}}","schema":"certigo.content.release/v1"}""";
            ReleaseId = $"sha256:{Sha256(releaseCanonical)}";
            _releaseBytes = Encoding.UTF8.GetBytes(
                $$"""{"schema":"certigo.content.release/v1","algorithm":"sha256","canonicalization":"json-sorted-keys-compact-utf8","publicManifestId":"{{PublicManifestId}}","privateManifestId":"{{PrivateManifestId}}","releaseId":"{{ReleaseId}}"}""");
        }

        public string ReleaseId { get; }
        private string PublicManifestId { get; }
        private string PrivateManifestId { get; }

        public static V5ReleaseSource WithOrderingX8Violation()
        {
            var question = ReadV5Fixture("ordering.question.json");
            var solution = ReadV5Fixture("ordering.solution.json");
            question["options"] = OptionsById(
                question,
                solution["correctOptionIds"]!.AsArray().Select(id => id!.GetValue<string>()).ToArray());
            return new V5ReleaseSource(question.ToJsonString(), solution.ToJsonString());
        }

        public static V5ReleaseSource WithPublicPairsLeak()
        {
            var question = ReadV5Fixture("ordering.question.json");
            var solution = ReadV5Fixture("ordering.solution.json");
            question["pairs"] = new JsonArray("s-mg:s-sub");
            return new V5ReleaseSource(question.ToJsonString(), solution.ToJsonString());
        }

        public Task<ContentBlobObject> ReadReleaseAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(Blob("release.json", _releaseBytes));

        public Task<ContentBlobObject> ReadManifestAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(Blob("manifest.json", artifact == ContentArtifact.Public
                ? _publicManifestBytes
                : _privateManifestBytes));

        public Task<ContentBlobObject> ReadFileAsync(
            ContentArtifact artifact,
            string manifestId,
            string path,
            CancellationToken cancellationToken = default)
            => Task.FromResult(Blob(path, Files(artifact)[path]));

        public Task<IReadOnlyList<string>> ListFilesAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => Task.FromResult<IReadOnlyList<string>>(Files(artifact).Keys.Order(StringComparer.Ordinal).ToArray());

        private Dictionary<string, byte[]> Files(ContentArtifact artifact)
            => artifact == ContentArtifact.Public ? _publicFiles : _privateFiles;

        private static ContentBlobObject Blob(string path, byte[] bytes)
            => new(path, "version-1", "\"etag\"", true, bytes);

        private static string ManifestCanonical(
            string channel,
            string artifact,
            IReadOnlyDictionary<string, byte[]> files,
            ContentArtifact contentArtifact)
            => $$"""{"algorithm":"sha256","artifact":"{{artifact}}","channel":"{{channel}}","fileCount":{{files.Count}},"files":[{{string.Join(",", FileEntries(files, contentArtifact))}}],"schema":"certigo.content.package-manifest/v3","serialization":"json-sorted-keys-compact-utf8-lf"}""";

        private static string ManifestPayload(
            string channel,
            string artifact,
            IReadOnlyDictionary<string, byte[]> files,
            ContentArtifact contentArtifact,
            string manifestId,
            string rootHash)
            => $$"""{"schema":"certigo.content.package-manifest/v3","channel":"{{channel}}","artifact":"{{artifact}}","algorithm":"sha256","serialization":"json-sorted-keys-compact-utf8-lf","fileCount":{{files.Count}},"files":[{{string.Join(",", FileEntries(files, contentArtifact))}}],"manifestId":"{{manifestId}}","rootHash":"{{rootHash}}"}""";

        private static IEnumerable<string> FileEntries(
            IReadOnlyDictionary<string, byte[]> files,
            ContentArtifact artifact)
            => files.OrderBy(entry => entry.Key, StringComparer.Ordinal).Select(entry =>
            {
                var id = entry.Key == "catalog/certifications.json"
                    ? "certification-catalog"
                    : JsonNode.Parse(Encoding.UTF8.GetString(entry.Value))!["id"]!.GetValue<string>();
                var resourceType = artifact == ContentArtifact.Private
                    ? "solution"
                    : entry.Key == "catalog/certifications.json" ? "certificationCatalog" : "question";
                return $$"""{"hash":"{{Sha256(entry.Value)}}","id":"{{id}}","path":"{{entry.Key}}","resourceType":"{{resourceType}}","size":{{entry.Value.Length}}}""";
            });

        private static JsonArray OptionsById(JsonObject question, IReadOnlyList<string> ids)
        {
            var byId = question["options"]!.AsArray()
                .Select(option => option!.DeepClone().AsObject())
                .ToDictionary(option => option["id"]!.GetValue<string>(), StringComparer.Ordinal);
            return new JsonArray(ids.Select(id => byId[id].DeepClone()).ToArray<JsonNode?>());
        }

        private static JsonObject ReadV5Fixture(string fileName)
            => JsonNode.Parse(File.ReadAllText(Path.Combine(FixtureRoot(), fileName)))!.AsObject();

        private static string ReadCatalog()
            => File.ReadAllText(Path.Combine(BackendRoot(), "tests", "Certigo.Application.Tests", "Fixtures", "canonical-certification-catalog-v1.json"));

        private static string FixtureRoot()
            => Path.Combine(BackendRoot(), "tests", "Certigo.Application.Tests", "Fixtures", "exercise-items-v5");

        private static string BackendRoot()
        {
            var directory = new DirectoryInfo(AppContext.BaseDirectory);
            while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Certigo.sln")))
            {
                directory = directory.Parent;
            }

            return directory?.FullName ?? throw new InvalidOperationException("backend root not found");
        }

        private static string Sha256(string value)
            => Sha256(Encoding.UTF8.GetBytes(value));

        private static string Sha256(byte[] bytes)
            => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
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

    private sealed class UnsafePathReleaseSource : IContentReleaseSource
    {
            private readonly byte[] _releaseBytes;
            private readonly byte[] _manifestBytes;

            public UnsafePathReleaseSource(string path)
            {
                var fileHash = new string('a', 64);
                var pathJson = JsonSerializer.Serialize(path);
                var canonicalManifest =
                    $$"""{"algorithm":"sha256","artifact":"public","channel":"public","fileCount":1,"files":[{"hash":"{{fileHash}}","id":"question-1","path":{{pathJson}},"resourceType":"question","size":1}],"schema":"certigo.content.package-manifest/v3","serialization":"json-sorted-keys-compact-utf8-lf"}""";
                var manifestDigest = Sha256(canonicalManifest);
                var publicManifestId = $"sha256:{manifestDigest}";
                var privateManifestId = $"sha256:{new string('b', 64)}";
                var canonicalRelease =
                    $$"""{"algorithm":"sha256","canonicalization":"json-sorted-keys-compact-utf8","privateManifestId":"{{privateManifestId}}","publicManifestId":"{{publicManifestId}}","schema":"certigo.content.release/v1"}""";
                ReleaseId = $"sha256:{Sha256(canonicalRelease)}";
                _releaseBytes = Encoding.UTF8.GetBytes($$"""
                    {
                      "schema": "certigo.content.release/v1",
                      "algorithm": "sha256",
                      "canonicalization": "json-sorted-keys-compact-utf8",
                      "publicManifestId": "{{publicManifestId}}",
                      "privateManifestId": "{{privateManifestId}}",
                      "releaseId": "{{ReleaseId}}"
                    }
                    """);
                _manifestBytes = Encoding.UTF8.GetBytes($$"""
                    {
                      "schema": "certigo.content.package-manifest/v3",
                      "channel": "public",
                      "artifact": "public",
                      "algorithm": "sha256",
                      "serialization": "json-sorted-keys-compact-utf8-lf",
                      "fileCount": 1,
                      "files": [{
                        "id": "question-1",
                        "path": {{pathJson}},
                        "resourceType": "question",
                        "hash": "{{fileHash}}",
                        "size": 1
                      }],
                      "manifestId": "{{publicManifestId}}",
                      "rootHash": "{{manifestDigest}}"
                    }
                    """);
            }

            public string ReleaseId { get; }

            public Task<ContentBlobObject> ReadReleaseAsync(
                string releaseId,
                CancellationToken cancellationToken = default)
                => Task.FromResult(Blob("release.json", _releaseBytes));

            public Task<ContentBlobObject> ReadManifestAsync(
                ContentArtifact artifact,
                string manifestId,
                CancellationToken cancellationToken = default)
                => artifact == ContentArtifact.Public
                    ? Task.FromResult(Blob("manifest.json", _manifestBytes))
                    : throw new InvalidOperationException("Private manifest must not be read.");

            public Task<ContentBlobObject> ReadFileAsync(
                ContentArtifact artifact,
                string manifestId,
                string path,
                CancellationToken cancellationToken = default)
                => throw new InvalidOperationException("Unsafe manifest files must not be read.");

            public Task<IReadOnlyList<string>> ListFilesAsync(
                ContentArtifact artifact,
                string manifestId,
                CancellationToken cancellationToken = default)
                => throw new InvalidOperationException("Unsafe manifests must not be listed.");

            private static ContentBlobObject Blob(string path, byte[] bytes)
                => new(path, "version-1", "\"etag\"", true, bytes);

            private static string Sha256(string value)
                => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)))
                    .ToLowerInvariant();
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
        public int GetReceiptCalls { get; private set; }
        public int StageCalls { get; private set; }

        public Task<ContentReleaseReceipt?> GetReceiptAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
        {
            GetReceiptCalls++;
            return Task.FromResult(ExistingReceipt);
        }

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
