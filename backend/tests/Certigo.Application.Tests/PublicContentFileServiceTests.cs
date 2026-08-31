using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class PublicContentFileServiceTests
{
    private const string ReleaseId =
        "sha256:6094410ae57637d55681fdeec3eae50fbfd69ba953741d069c95a478bee73f7f";
    private const string Path = "questions/microsoft.az-900.question-1.json";
    private static readonly byte[] FileBytes = Encoding.UTF8.GetBytes("""{"id":"question-1"}""");
    private static readonly string FileHash = Sha256(FileBytes);

    [Fact]
    public async Task Versioned_delivery_returns_only_the_exact_public_manifest_entry()
    {
        var fixture = CreateFixture();

        var result = await fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            Path);

        result.ReleaseId.Should().Be(ReleaseId);
        result.PublicManifestId.Should().Be(fixture.ManifestId);
        result.Hash.Should().Be(FileHash);
        result.Content.ToArray().Should().Equal(FileBytes);
        fixture.Source.Artifacts.Should().OnlyContain(artifact => artifact == ContentArtifact.Public);
    }

    [Fact]
    public async Task Legacy_mode_returns_not_found_without_touching_storage()
    {
        var fixture = CreateFixture(enabled: false);

        var action = () => fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            Path);

        await action.Should().ThrowAsync<ContentReleaseNotFoundException>()
            .WithMessage("Public content file was not found.");
        fixture.Store.ReadCount.Should().Be(0);
        fixture.Source.ReadCount.Should().Be(0);
    }

    [Theory]
    [InlineData("sha256:invalid",
        "valid", "valid", "questions/microsoft.az-900.question-1.json")]
    [InlineData("valid", "sha256:invalid",
        "valid", "questions/microsoft.az-900.question-1.json")]
    [InlineData("valid", "valid", "invalid",
        "questions/microsoft.az-900.question-1.json")]
    [InlineData("valid", "valid", "valid", "../private/answer-key.json")]
    [InlineData("valid", "valid", "valid", "questions%2f..%2fprivate.json")]
    public async Task Wrong_pins_and_unsafe_paths_share_the_same_not_found_response(
        string releaseId,
        string publicManifestId,
        string hash,
        string path)
    {
        var fixture = CreateFixture();
        releaseId = releaseId == "valid" ? ReleaseId : releaseId;
        publicManifestId = publicManifestId == "valid"
            ? fixture.ManifestId
            : publicManifestId;
        hash = hash == "valid" ? FileHash : hash;

        var action = () => fixture.Service.GetAsync(
            releaseId,
            publicManifestId,
            hash,
            path);

        await action.Should().ThrowAsync<ContentReleaseNotFoundException>()
            .WithMessage("Public content file was not found.");
        fixture.Store.ReadCount.Should().Be(0);
        fixture.Source.ReadCount.Should().Be(0);
    }

    [Theory]
    [InlineData("unknown-release", 0)]
    [InlineData("unknown-manifest", 0)]
    [InlineData("unknown-hash", 1)]
    public async Task Well_formed_unknown_bindings_share_the_same_not_found_response(
        string unknownBinding,
        int expectedSourceReads)
    {
        var fixture = CreateFixture();
        var releaseId = unknownBinding == "unknown-release"
            ? "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            : ReleaseId;
        var publicManifestId = unknownBinding == "unknown-manifest"
            ? "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
            : fixture.ManifestId;
        var hash = unknownBinding == "unknown-hash"
            ? "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
            : FileHash;

        var action = () => fixture.Service.GetAsync(
            releaseId,
            publicManifestId,
            hash,
            Path);

        await action.Should().ThrowAsync<ContentReleaseNotFoundException>()
            .WithMessage("Public content file was not found.");
        fixture.Store.ReadCount.Should().Be(1);
        fixture.Source.ReadCount.Should().Be(expectedSourceReads);
        fixture.Source.FileReadCount.Should().Be(0);
    }

    [Fact]
    public async Task Unknown_manifest_file_and_hash_are_not_distinguishable()
    {
        var fixture = CreateFixture();
        var unknownManifest =
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        fixture.Store.Receipt = fixture.Store.Receipt! with { PublicManifestId = unknownManifest };

        var wrongManifest = () => fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            Path);
        var wrongPath = () => fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            "questions/unknown.json");

        (await wrongManifest.Should().ThrowAsync<ContentReleaseNotFoundException>())
            .Which.Message.Should().Be("Public content file was not found.");
        fixture.Source.ReadCount.Should().Be(0);
        fixture.Store.Receipt = fixture.Store.Receipt! with
        {
            PublicManifestId = fixture.ManifestId,
        };
        (await wrongPath.Should().ThrowAsync<ContentReleaseNotFoundException>())
            .Which.Message.Should().Be("Public content file was not found.");
        fixture.Source.ReadCount.Should().Be(1);
    }

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    public async Task Corrupt_or_mutable_public_bytes_fail_as_unavailable(
        bool corruptBytes,
        bool mutable)
    {
        var fixture = CreateFixture();
        fixture.Source.FileBytes = corruptBytes
            ? Encoding.UTF8.GetBytes("""{"id":"tampered"}""")
            : FileBytes;
        fixture.Source.FileImmutable = !mutable;

        var action = () => fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            Path);

        await action.Should().ThrowAsync<ContentUnavailableException>()
            .WithMessage("Public content is temporarily unavailable.");
    }

    [Fact]
    public async Task Missing_public_blob_uses_the_generic_not_found_response()
    {
        var fixture = CreateFixture();
        fixture.Source.FileMissing = true;

        var action = () => fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            Path);

        await action.Should().ThrowAsync<ContentReleaseNotFoundException>()
            .WithMessage("Public content file was not found.");
    }

    [Fact]
    public async Task Invalid_public_blob_read_fails_as_unavailable()
    {
        var fixture = CreateFixture();
        fixture.Source.FileValidationFailure = true;

        var action = () => fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            Path);

        await action.Should().ThrowAsync<ContentUnavailableException>()
            .WithMessage("Public content is temporarily unavailable.");
    }

    [Fact]
    public async Task Answer_key_shaped_entries_are_never_read()
    {
        var fixture = CreateFixture(
            path: "solutions/microsoft.az-900.answer.json",
            resourceType: "solution");

        var action = () => fixture.Service.GetAsync(
            ReleaseId,
            fixture.ManifestId,
            FileHash,
            "solutions/microsoft.az-900.answer.json");

        await action.Should().ThrowAsync<ContentUnavailableException>();
        fixture.Source.FileReadCount.Should().Be(0);
    }

    private static Fixture CreateFixture(
        bool enabled = true,
        string path = Path,
        string resourceType = "question")
    {
        var manifestBytes = CreateManifest(path, resourceType);
        using var manifestJson = JsonDocument.Parse(manifestBytes);
        var manifestId = manifestJson.RootElement.GetProperty("manifestId").GetString()!;
        var store = new FakeStore
        {
            Receipt = new ContentReleaseReceipt(
                $"release::{ReleaseId}",
                ContentReleaseContracts.RuntimeScope,
                ReleaseId,
                manifestId,
                "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                1,
                1,
                1,
                DateTimeOffset.UnixEpoch,
                "admin",
                3,
                new string('c', 64)),
        };
        var source = new FakeSource(manifestBytes) { FileBytes = FileBytes };
        var verifier = new ContentContractVerifier(
            source,
            new AcceptingSchemaValidator(),
            ContentReleaseLimits.Default);
        return new Fixture(
            new PublicContentFileService(
                store,
                source,
                verifier,
                new PublicContentDeliveryOptions(enabled)),
            store,
            source,
            manifestId);
    }

    private static byte[] CreateManifest(string path, string resourceType)
    {
        var canonical =
            $$"""{"algorithm":"sha256","artifact":"public","channel":"public","fileCount":1,"files":[{"hash":"{{FileHash}}","id":"question-1","path":"{{path}}","resourceType":"{{resourceType}}","size":{{FileBytes.Length}}}],"schema":"certigo.content.package-manifest/v3","serialization":"json-sorted-keys-compact-utf8-lf"}""";
        var digest = Sha256(Encoding.UTF8.GetBytes(canonical));
        return Encoding.UTF8.GetBytes($$"""
            {
              "schema": "certigo.content.package-manifest/v3",
              "channel": "public",
              "artifact": "public",
              "algorithm": "sha256",
              "serialization": "json-sorted-keys-compact-utf8-lf",
              "fileCount": 1,
              "files": [{
                "id": "question-1",
                "path": "{{path}}",
                "resourceType": "{{resourceType}}",
                "hash": "{{FileHash}}",
                "size": {{FileBytes.Length}}
              }],
              "manifestId": "sha256:{{digest}}",
              "rootHash": "{{digest}}"
            }
            """);
    }

    private static string Sha256(ReadOnlySpan<byte> bytes)
        => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    private sealed record Fixture(
        PublicContentFileService Service,
        FakeStore Store,
        FakeSource Source,
        string ManifestId);

    private sealed class AcceptingSchemaValidator : IContentSchemaValidator
    {
        public void Validate(string schemaFileName, JsonElement value)
        {
        }
    }

    private sealed class FakeSource(byte[] manifestBytes) : IContentReleaseSource
    {
        public byte[] FileBytes { get; set; } = [];
        public bool FileImmutable { get; set; } = true;
        public bool FileMissing { get; set; }
        public bool FileValidationFailure { get; set; }
        public int ReadCount { get; private set; }
        public int FileReadCount { get; private set; }
        public List<ContentArtifact> Artifacts { get; } = [];

        public Task<ContentBlobObject> ReadManifestAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
        {
            ReadCount++;
            Artifacts.Add(artifact);
            return Task.FromResult(Blob("manifest.json", manifestBytes, immutable: true));
        }

        public Task<ContentBlobObject> ReadFileAsync(
            ContentArtifact artifact,
            string manifestId,
            string path,
            CancellationToken cancellationToken = default)
        {
            ReadCount++;
            FileReadCount++;
            Artifacts.Add(artifact);
            if (FileMissing)
            {
                throw new ContentReleaseNotFoundException("Sensitive blob coordinates.");
            }
            if (FileValidationFailure)
            {
                throw new ContentReleaseValidationException("Sensitive blob validation details.");
            }

            return Task.FromResult(Blob(path, FileBytes, FileImmutable));
        }

        public Task<ContentBlobObject> ReadReleaseAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<IReadOnlyList<string>> ListFilesAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        private static ContentBlobObject Blob(string path, byte[] bytes, bool immutable)
            => new(path, "version-1", "\"blob-etag\"", immutable, bytes);
    }

    private sealed class FakeStore : IContentReleaseStore
    {
        public ContentReleaseReceipt? Receipt { get; set; }
        public int ReadCount { get; private set; }

        public Task<ContentReleaseReceipt?> GetReceiptAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
        {
            ReadCount++;
            return Task.FromResult(
                string.Equals(Receipt?.ReleaseId, releaseId, StringComparison.Ordinal)
                    ? Receipt
                    : null);
        }

        public Task<ContentReleaseReceipt> StageAsync(
            ProjectedContentRelease release,
            string actorId,
            DateTimeOffset importedAt,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ActiveContentPointer?> GetActivePointerAsync(
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ContentSnapshot?> ResolveSnapshotAsync(
            string publicManifestId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

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
            => throw new NotSupportedException();
    }
}
