using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class ContentReleaseServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 6, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Import_is_idempotent_by_composite_release_manifest_id()
    {
        var repository = new InMemoryReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var request = Package("""{"id":"question-1","stem":"Safe"}""");

        var first = await service.ImportAsync(request);
        var replay = await service.ImportAsync(request);

        first.AlreadyImported.Should().BeFalse();
        replay.AlreadyImported.Should().BeTrue();
        first.ManifestId.Should().Be(replay.ManifestId);
        first.PublicManifestId.Should().Be(request.Public.Manifest.ManifestId);
        repository.CommitCount.Should().Be(1);
        telemetry.Imports.Should().Equal(false, true);
    }

    [Fact]
    public async Task Import_accepts_a_manifest_vector_generated_by_the_real_publisher()
    {
        const string publicManifestId =
            "sha256:7e02f5a9e769ea9e95770b5fb106e457810f5352aed4395e9a44ed598567b252";
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var request = Package("""{"id":"placeholder"}""");
        var publicBytes = Encoding.UTF8.GetBytes("{\"id\":\"publisher-vector\"}\n");
        var descriptor = new ContentArtifactFile(
            "publisher-vector",
            "questions/publisher-vector.json",
            "cb9aed12e4e3fb5dd78a5ae9a016ef62981bcb760c1109f7d5a9a82a4084a08e",
            26);
        request = request with
        {
            Public = new ContentArtifactPackage(
                new ContentArtifactManifest(
                    ContentReleaseOptions.PackageManifestSchema,
                    "public",
                    "public",
                    ContentReleaseOptions.HashAlgorithm,
                    ContentReleaseOptions.Serialization,
                    1,
                    [descriptor],
                    publicManifestId,
                    publicManifestId[7..]),
                [new ContentArtifactPayload(
                    descriptor.Path,
                    Convert.ToBase64String(publicBytes))])
        };

        var imported = await service.ImportAsync(request);

        imported.PublicManifestId.Should().Be(publicManifestId);
        repository.CommitCount.Should().Be(1);
    }

    [Fact]
    public async Task Private_only_update_creates_a_distinct_release_without_collision()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var firstPackage = Package("""{"id":"q1"}""");
        var secondPackage = Package(
            """{"id":"q1"}""",
            """{"answerKey":{"itemId":"q1","correct":["b"],"rationale":"Updated"}}""");

        var first = await service.ImportAsync(firstPackage);
        var second = await service.ImportAsync(secondPackage);
        var firstPromotion = await service.PromoteAsync(first.ManifestId);
        var secondPromotion = await service.PromoteAsync(second.ManifestId);

        first.PublicManifestId.Should().Be(second.PublicManifestId);
        first.ManifestId.Should().NotBe(second.ManifestId);
        repository.CommitCount.Should().Be(2);
        firstPromotion.ActiveManifestId.Should().Be(first.ManifestId);
        secondPromotion.ActiveManifestId.Should().Be(second.ManifestId);
        secondPromotion.PreviousManifestId.Should().Be(first.ManifestId);
    }

    [Fact]
    public async Task Import_rejects_bad_hash_before_any_repository_mutation()
    {
        var repository = new InMemoryReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var request = Package("""{"id":"question-1","stem":"Safe"}""");
        request = request with
        {
            Public = request.Public with
            {
                Files =
                [
                    request.Public.Files[0] with
                    {
                        ContentBase64 = Convert.ToBase64String(
                            Encoding.UTF8.GetBytes("""{"id":"question-2","stem":"Safe"}"""))
                    }
                ]
            }
        };

        var act = () => service.ImportAsync(request);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*public_hash_mismatch*");
        repository.CommitCount.Should().Be(0);
        telemetry.Rejections.Should().ContainSingle("public_hash_mismatch");
    }

    [Theory]
    [InlineData("""{"answerKey":{"correct":["a"]}}""")]
    [InlineData("""{"question":{"correct":["a"]}}""")]
    [InlineData("""{"question":{"rationale":"secret"}}""")]
    public async Task Import_rejects_private_fields_in_public_artifact(string publicJson)
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);

        var act = () => service.ImportAsync(Package(publicJson));

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*public_private_key*");
        repository.CommitCount.Should().Be(0);
    }

    [Fact]
    public async Task Import_rejects_null_base64_as_validation_error_before_mutation()
    {
        var repository = new InMemoryReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var request = Package("""{"id":"q1"}""");
        request = request with
        {
            Public = request.Public with
            {
                Files =
                [
                    request.Public.Files[0] with { ContentBase64 = null! }
                ]
            }
        };

        var act = () => service.ImportAsync(request);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*public_invalid_base64*");
        repository.CommitCount.Should().Be(0);
        telemetry.Rejections.Should().ContainSingle("public_invalid_base64");
    }

    [Fact]
    public async Task Import_requires_the_published_package_manifest_schema()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var request = Package("""{"id":"q1"}""");
        request = request with
        {
            Private = request.Private with
            {
                Manifest = request.Private.Manifest with { Schema = "unsupported/v1" }
            }
        };

        var act = () => service.ImportAsync(request);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*private_manifest_schema_mismatch*");
        repository.CommitCount.Should().Be(0);
    }

    [Fact]
    public async Task Import_rejects_malformed_public_json_before_any_mutation()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);

        var act = () => service.ImportAsync(Package("""{"id":"""));

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*public_invalid_json*");
        repository.CommitCount.Should().Be(0);
    }

    [Fact]
    public async Task Import_rejects_non_canonical_manifest_id_before_any_mutation()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var request = Package("""{"id":"q1"}""");
        request = request with
        {
            Public = request.Public with
            {
                Manifest = request.Public.Manifest with
                {
                    ManifestId =
                        $"sha256:{request.Public.Manifest.ManifestId[7..].ToUpperInvariant()}"
                }
            }
        };

        var act = () => service.ImportAsync(request);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*public_non_canonical_hash_format*");
        repository.CommitCount.Should().Be(0);
    }

    [Fact]
    public async Task Import_rejects_non_canonical_file_hash_before_any_mutation()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var request = Package("""{"id":"q1"}""");
        var nonCanonicalDescriptor = request.Public.Manifest.Files[0] with
        {
            Hash = request.Public.Manifest.Files[0].Hash.ToUpperInvariant()
        };
        request = request with
        {
            Public = request.Public with
            {
                Manifest = Manifest("public", "public", [nonCanonicalDescriptor])
            }
        };

        var act = () => service.ImportAsync(request);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*public_non_canonical_file_hash*");
        repository.CommitCount.Should().Be(0);
    }

    [Fact]
    public async Task Import_rejects_file_count_mismatch_before_any_mutation()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var request = Package("""{"id":"q1"}""");
        request = request with
        {
            Public = request.Public with
            {
                Manifest = request.Public.Manifest with
                {
                    FileCount = request.Public.Manifest.FileCount + 1
                }
            }
        };

        var act = () => service.ImportAsync(request);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*public_file_count_mismatch*");
        repository.CommitCount.Should().Be(0);
    }

    [Fact]
    public async Task Promotion_and_rollback_swap_the_active_manifest_and_preserve_history()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var first = Package("""{"id":"q1"}""");
        var second = Package("""{"id":"q2"}""");
        var firstId = (await service.ImportAsync(first)).ManifestId;
        var secondId = (await service.ImportAsync(second)).ManifestId;

        var promotedFirst = await service.PromoteAsync(firstId);
        var promotedSecond = await service.PromoteAsync(secondId);
        var rolledBack = await service.RollbackAsync(firstId);

        promotedFirst.PreviousManifestId.Should().BeNull();
        promotedSecond.PreviousManifestId.Should().Be(firstId);
        rolledBack.ActiveManifestId.Should().Be(firstId);
        rolledBack.PreviousManifestId.Should().Be(secondId);
        rolledBack.Operation.Should().Be("rollback");
        repository.State!.History.Select(x => x.Operation)
            .Should().Equal(
                ContentReleaseOperation.Promote,
                ContentReleaseOperation.Promote,
                ContentReleaseOperation.Rollback);
    }

    [Fact]
    public async Task Rollback_rejects_a_manifest_that_is_not_N_minus_one()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var first = Package("""{"id":"q1"}""");
        var second = Package("""{"id":"q2"}""");
        var firstId = (await service.ImportAsync(first)).ManifestId;
        var secondId = (await service.ImportAsync(second)).ManifestId;
        await service.PromoteAsync(firstId);

        var act = () => service.RollbackAsync(secondId);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*rollback_target_is_not_previous*");
    }

    [Fact]
    public async Task No_op_promotion_does_not_append_history_or_emit_a_second_promotion()
    {
        var repository = new InMemoryReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var package = Package("""{"id":"q1"}""");
        var imported = await service.ImportAsync(package);

        await service.PromoteAsync(imported.ManifestId);
        await service.PromoteAsync(imported.ManifestId);

        repository.State!.History.Should().ContainSingle();
        telemetry.Promotions.Should().ContainSingle();
    }

    [Fact]
    public async Task Rollback_to_the_active_manifest_is_rejected_and_not_emitted()
    {
        var repository = new InMemoryReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var package = Package("""{"id":"q1"}""");
        var imported = await service.ImportAsync(package);
        await service.PromoteAsync(imported.ManifestId);

        var act = () => service.RollbackAsync(imported.ManifestId);

        await act.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("*rollback_target_is_not_previous*");
        telemetry.Rollbacks.Should().BeEmpty();
    }

    [Fact]
    public async Task Public_reads_expose_only_the_active_public_manifest_and_files()
    {
        var repository = new InMemoryReleaseRepository();
        var service = CreateService(repository);
        var package = Package("""{"id":"q1","stem":"Safe"}""");
        var imported = await service.ImportAsync(package);
        await service.PromoteAsync(imported.ManifestId);

        var manifest = await service.GetActiveManifestAsync();
        var publicFile = await service.GetActivePublicFileAsync("questions/questions.json");
        var privateFile = await service.GetActivePublicFileAsync("solutions/answers.json");

        manifest!.ManifestId.Should().Be(package.Public.Manifest.ManifestId);
        manifest.Files.Should().ContainSingle(x => x.Path == "questions/questions.json");
        Encoding.UTF8.GetString(publicFile!.Content).Should().NotContain("correct");
        privateFile.Should().BeNull();
    }

    private static ContentReleaseService CreateService(
        InMemoryReleaseRepository repository,
        SpyContentReleaseTelemetry? telemetry = null)
        => new(
            repository,
            repository,
            telemetry ?? new SpyContentReleaseTelemetry(),
            new FakeClock(Now),
            new ContentReleaseOptions("staging"));

    private static ContentReleaseImportRequest Package(
        string publicJson,
        string privateJson =
            """{"answerKey":{"itemId":"q1","correct":["a"],"rationale":"Because"}}""")
    {
        var publicBytes = Encoding.UTF8.GetBytes(publicJson);
        var privateBytes = Encoding.UTF8.GetBytes(privateJson);
        var publicDescriptor = Descriptor("question-set", "questions/questions.json", publicBytes);
        var privateDescriptor = Descriptor("solution-set", "solutions/answers.json", privateBytes);
        return new ContentReleaseImportRequest(
            ContentReleaseOptions.ContractVersion,
            new ContentArtifactPackage(
                Manifest("public", "public", [publicDescriptor]),
                [new ContentArtifactPayload(publicDescriptor.Path, Convert.ToBase64String(publicBytes))]),
            new ContentArtifactPackage(
                Manifest("answerKey", "private", [privateDescriptor]),
                [new ContentArtifactPayload(privateDescriptor.Path, Convert.ToBase64String(privateBytes))]));
    }

    private static ContentArtifactFile Descriptor(string id, string path, byte[] content)
        => new(
            id,
            path,
            Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant(),
            content.LongLength);

    private static ContentArtifactManifest Manifest(
        string channel,
        string artifact,
        IReadOnlyList<ContentArtifactFile> files)
    {
        var body = new
        {
            Schema = ContentReleaseOptions.PackageManifestSchema,
            Channel = channel,
            Artifact = artifact,
            Algorithm = ContentReleaseOptions.HashAlgorithm,
            Serialization = ContentReleaseOptions.Serialization,
            FileCount = files.Count,
            Files = files
        };
        var rootHash = Convert.ToHexString(SHA256.HashData(Canonicalize(body)))
            .ToLowerInvariant();
        return new ContentArtifactManifest(
            ContentReleaseOptions.PackageManifestSchema,
            channel,
            artifact,
            ContentReleaseOptions.HashAlgorithm,
            ContentReleaseOptions.Serialization,
            files.Count,
            files,
            $"sha256:{rootHash}",
            rootHash);
    }

    private static byte[] Canonicalize<T>(T value)
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web)
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        };
        var element = JsonSerializer.SerializeToElement(value, options);
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, new JsonWriterOptions
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        }))
        {
            WriteCanonical(writer, element);
            writer.Flush();
        }
        return stream.ToArray();
    }

    private static void WriteCanonical(Utf8JsonWriter writer, JsonElement element)
    {
        if (element.ValueKind == JsonValueKind.Object)
        {
            writer.WriteStartObject();
            foreach (var property in element.EnumerateObject()
                         .OrderBy(x => x.Name, StringComparer.Ordinal))
            {
                writer.WritePropertyName(property.Name);
                WriteCanonical(writer, property.Value);
            }
            writer.WriteEndObject();
        }
        else if (element.ValueKind == JsonValueKind.Array)
        {
            writer.WriteStartArray();
            foreach (var item in element.EnumerateArray())
            {
                WriteCanonical(writer, item);
            }
            writer.WriteEndArray();
        }
        else
        {
            element.WriteTo(writer);
        }
    }

    private sealed class InMemoryReleaseRepository :
        IContentReleaseRepository,
        IPublicContentReleaseRepository,
        IPrivateContentReleaseRepository
    {
        private readonly Dictionary<string, ContentReleaseReceipt> _receipts = new(StringComparer.Ordinal);
        private readonly Dictionary<string, VerifiedContentReleaseFile> _files = new(StringComparer.Ordinal);

        public int CommitCount { get; private set; }
        public ContentReleaseState? State { get; private set; }

        public Task<ContentReleaseReceipt?> GetReceiptAsync(
            string manifestId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(_receipts.GetValueOrDefault(manifestId));

        public Task<bool> ImportAsync(
            VerifiedContentRelease release,
            CancellationToken cancellationToken = default)
        {
            if (_receipts.TryGetValue(release.ManifestId, out var existing))
            {
                if (existing.Fingerprint != release.Fingerprint)
                {
                    throw new ContentReleaseValidationException(
                        "Content release rejected: manifest_id_collision.");
                }

                return Task.FromResult(true);
            }

            foreach (var file in release.Files)
            {
                _files[$"{release.ManifestId}|{file.Channel}|{file.Path}"] = file;
            }

            _receipts[release.ManifestId] = new ContentReleaseReceipt(
                release.ManifestId,
                release.PublicManifestId,
                release.Fingerprint,
                release.PublicManifest,
                release.ImportedAt);
            CommitCount++;
            return Task.FromResult(false);
        }

        public Task<ContentReleaseState?> GetStateAsync(
            string environment,
            CancellationToken cancellationToken = default)
            => Task.FromResult(State);

        public Task<ContentReleasePromotionResult> PromoteAsync(
            string environment,
            string manifestId,
            ContentReleaseOperation operation,
            DateTimeOffset changedAt,
            CancellationToken cancellationToken = default)
        {
            if (!_receipts.ContainsKey(manifestId))
            {
                throw new ContentReleaseNotFoundException(manifestId);
            }

            if (State?.ActiveManifestId == manifestId)
            {
                if (operation == ContentReleaseOperation.Rollback)
                {
                    throw new ContentReleaseValidationException(
                        "Content release rejected: rollback_target_is_not_previous.");
                }
                return Task.FromResult(new ContentReleasePromotionResult(State, false));
            }

            if (operation == ContentReleaseOperation.Rollback
                && State?.PreviousManifestId != manifestId)
            {
                throw new ContentReleaseValidationException(
                    "Content release rejected: rollback_target_is_not_previous.");
            }

            var history = State?.History.ToList() ?? [];
            history.Add(new ContentReleaseHistoryEntry(manifestId, operation, changedAt));
            State = new ContentReleaseState(
                environment,
                manifestId,
                State?.ActiveManifestId,
                changedAt,
                operation,
                history);
            return Task.FromResult(new ContentReleasePromotionResult(State, true));
        }

        public Task<StoredContentReleaseFile?> GetActivePublicFileAsync(
            string environment,
            string path,
            CancellationToken cancellationToken = default)
        {
            if (State is null
                || !_files.TryGetValue($"{State.ActiveManifestId}|public|{path}", out var file))
            {
                return Task.FromResult<StoredContentReleaseFile?>(null);
            }

            return Task.FromResult<StoredContentReleaseFile?>(
                new StoredContentReleaseFile(file.Path, file.Content));
        }

        public Task<StoredContentReleaseFile?> GetActivePrivateFileAsync(
            string environment,
            string path,
            CancellationToken cancellationToken = default)
        {
            if (State is null
                || !_files.TryGetValue($"{State.ActiveManifestId}|answerKey|{path}", out var file))
            {
                return Task.FromResult<StoredContentReleaseFile?>(null);
            }

            return Task.FromResult<StoredContentReleaseFile?>(
                new StoredContentReleaseFile(file.Path, file.Content));
        }
    }

    private sealed class SpyContentReleaseTelemetry : IContentReleaseTelemetry
    {
        public List<bool> Imports { get; } = [];
        public List<string> Rejections { get; } = [];
        public List<string> Promotions { get; } = [];
        public List<string> Rollbacks { get; } = [];

        public void TrackImported(
            string manifestId,
            bool alreadyImported,
            int publicFiles,
            int privateFiles)
            => Imports.Add(alreadyImported);

        public void TrackPromoted(string environment, string manifestId)
            => Promotions.Add(manifestId);
        public void TrackRolledBack(string environment, string manifestId)
            => Rollbacks.Add(manifestId);
        public void TrackRejected(string reason) => Rejections.Add(reason);
    }
}
