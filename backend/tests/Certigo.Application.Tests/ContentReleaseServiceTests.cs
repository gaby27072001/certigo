using System.Text.Json;
using System.Text;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class ContentReleaseServiceTests
{
    [Fact]
    public void Canonicalization_sorts_keys_preserves_utf8_and_appends_lf()
    {
        using var document = JsonDocument.Parse("""{"z":"é","a":1}""");

        var canonical = Encoding.UTF8.GetString(
            ContentPackageIntegrity.Canonicalize(document.RootElement));

        canonical.Should().Be("{\"a\":1,\"z\":\"é\"}\n");
    }

    [Fact]
    public async Task Import_is_idempotent_by_public_manifest_id()
    {
        var repository = new InMemoryContentReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var request = ReleaseFixture.Create("one");

        var first = await service.ImportAsync(request);
        var replay = await service.ImportAsync(request);

        first.Imported.Should().BeTrue();
        replay.Imported.Should().BeFalse();
        replay.ManifestId.Should().Be(first.ManifestId);
        repository.ReleaseCount.Should().Be(1);
        repository.PublicWriteCount.Should().Be(1);
        repository.PrivateWriteCount.Should().Be(1);
        repository.PublicDocumentCount.Should().Be(2);
        repository.PrivateDocumentCount.Should().Be(2);
        telemetry.Imports.Should().Equal(
            (first.ManifestId, false),
            (first.ManifestId, true));
    }

    [Fact]
    public async Task Import_rejects_invalid_hash_before_any_mutation()
    {
        var repository = new InMemoryContentReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var valid = ReleaseFixture.Create("bad-hash");
        var badEntry = valid.Public.Manifest.Files[0] with
        {
            Hash = new string('0', 64)
        };
        var request = valid with
        {
            Public = valid.Public with
            {
                Manifest = valid.Public.Manifest with
                {
                    Files = [badEntry]
                }
            }
        };

        var act = () => service.ImportAsync(request);

        await act.Should().ThrowAsync<ContentReleaseValidationException>();
        repository.MutationCount.Should().Be(0);
        telemetry.Rejections.Should().ContainSingle();
    }

    [Fact]
    public async Task Import_rejects_public_answer_material_before_any_mutation()
    {
        var repository = new InMemoryContentReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var request = ReleaseFixture.Create("leak", includePublicLeak: true);

        var act = () => service.ImportAsync(request);

        (await act.Should().ThrowAsync<ContentReleaseValidationException>())
            .WithMessage("*forbidden key*");
        repository.MutationCount.Should().Be(0);
        telemetry.Rejections.Should().ContainSingle();
    }

    [Fact]
    public async Task Promotion_moves_active_staging_release_to_production_and_is_idempotent()
    {
        var repository = new InMemoryContentReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var imported = await service.ImportAsync(ReleaseFixture.Create("promote"));

        var promoted = await service.PromoteAsync(imported.ManifestId);
        var replay = await service.PromoteAsync(imported.ManifestId);

        promoted.Environment.Should().Be(ContentReleaseEnvironment.Prod);
        promoted.ActiveManifestId.Should().Be(imported.ManifestId);
        promoted.PreviousManifestId.Should().BeNull();
        promoted.Changed.Should().BeTrue();
        replay.Changed.Should().BeFalse();
        repository.StateWriteCount.Should().Be(2, "one staging activation and one production promotion");
        telemetry.Promotions.Should().Equal(
            (imported.ManifestId, true),
            (imported.ManifestId, false));
    }

    [Fact]
    public async Task Rollback_restores_exact_N_minus_1_release_in_staging()
    {
        var repository = new InMemoryContentReleaseRepository();
        var telemetry = new SpyContentReleaseTelemetry();
        var service = CreateService(repository, telemetry);
        var first = await service.ImportAsync(ReleaseFixture.Create("v1"));
        var second = await service.ImportAsync(ReleaseFixture.Create("v2"));

        var rolledBack = await service.RollbackAsync(
            first.ManifestId,
            ContentReleaseEnvironment.Staging);

        rolledBack.ActiveManifestId.Should().Be(first.ManifestId);
        rolledBack.PreviousManifestId.Should().Be(second.ManifestId);
        rolledBack.Changed.Should().BeTrue();
        telemetry.Rollbacks.Should().ContainSingle()
            .Which.Should().Be((first.ManifestId, ContentReleaseEnvironment.Staging, true));
    }

    [Fact]
    public async Task Rollback_rejects_a_release_older_than_N_minus_1()
    {
        var repository = new InMemoryContentReleaseRepository();
        var service = CreateService(repository, new SpyContentReleaseTelemetry());
        var first = await service.ImportAsync(ReleaseFixture.Create("v1"));
        await service.ImportAsync(ReleaseFixture.Create("v2"));
        await service.ImportAsync(ReleaseFixture.Create("v3"));

        var act = () => service.RollbackAsync(
            first.ManifestId,
            ContentReleaseEnvironment.Staging);

        (await act.Should().ThrowAsync<ContentReleaseConflictException>())
            .WithMessage("*not the N-1 release*");
    }

    [Fact]
    public async Task Active_manifest_is_the_public_production_manifest_only()
    {
        var repository = new InMemoryContentReleaseRepository();
        var service = CreateService(repository, new SpyContentReleaseTelemetry());
        var imported = await service.ImportAsync(ReleaseFixture.Create("active"));
        await service.PromoteAsync(imported.ManifestId);

        var manifest = await service.GetActivePublicManifestAsync();
        var json = JsonSerializer.Serialize(manifest, new JsonSerializerOptions(JsonSerializerDefaults.Web));

        manifest.ManifestId.Should().Be(imported.ManifestId);
        manifest.Channel.Should().Be("public");
        manifest.Artifact.Should().Be("public");
        var normalized = json.ToLowerInvariant();
        normalized.Should().NotContain("answerkey");
        normalized.Should().NotContain("correct");
        normalized.Should().NotContain("rationale");
    }

    private static ContentReleaseService CreateService(
        InMemoryContentReleaseRepository repository,
        SpyContentReleaseTelemetry telemetry)
        => new(
            repository,
            telemetry,
            new FakeClock(new DateTimeOffset(2026, 8, 6, 10, 0, 0, TimeSpan.Zero)));

    private sealed class InMemoryContentReleaseRepository : IContentReleaseRepository
    {
        private readonly Dictionary<string, ContentReleaseRecord> _releases = new(StringComparer.Ordinal);
        private readonly Dictionary<ContentReleaseEnvironment, ContentReleaseStateRecord> _states = new();
        private readonly Dictionary<string, ContentPackageDto> _public = new(StringComparer.Ordinal);
        private readonly Dictionary<string, ContentPackageDto> _private = new(StringComparer.Ordinal);
        private long _version;

        public int ReleaseCount => _releases.Count;
        public int PublicWriteCount { get; private set; }
        public int PrivateWriteCount { get; private set; }
        public int StateWriteCount { get; private set; }
        public int PublicDocumentCount => _public.Values.Sum(package => package.Files.Count + 1);
        public int PrivateDocumentCount => _private.Values.Sum(package => package.Files.Count + 1);
        public int MutationCount => PublicWriteCount + PrivateWriteCount + StateWriteCount + ReleaseCount;

        public Task<ContentReleaseRecord?> GetReleaseAsync(
            string manifestId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(_releases.GetValueOrDefault(manifestId));

        public Task<ContentReleaseStateRecord?> GetStateAsync(
            ContentReleaseEnvironment environment,
            CancellationToken cancellationToken = default)
            => Task.FromResult(_states.GetValueOrDefault(environment));

        public Task WritePublicPackageAsync(
            ContentPackageDto package,
            CancellationToken cancellationToken = default)
        {
            _public[package.Manifest.ManifestId] = package;
            PublicWriteCount++;
            return Task.CompletedTask;
        }

        public Task WritePrivatePackageAsync(
            ContentPackageDto package,
            CancellationToken cancellationToken = default)
        {
            _private[package.Manifest.ManifestId] = package;
            PrivateWriteCount++;
            return Task.CompletedTask;
        }

        public Task CommitImportAsync(
            ContentReleaseRecord release,
            ContentReleaseStateRecord stagingState,
            CancellationToken cancellationToken = default)
        {
            if (_releases.ContainsKey(release.ManifestId))
            {
                throw new ConcurrencyConflictException("simulated concurrent import");
            }

            if (_states.TryGetValue(stagingState.Environment, out var current)
                && !string.Equals(current.ETag, stagingState.ETag, StringComparison.Ordinal))
            {
                throw new ConcurrencyConflictException("simulated stale state");
            }

            _releases.Add(release.ManifestId, release with { ETag = NextETag() });
            _states[stagingState.Environment] = stagingState with { ETag = NextETag() };
            StateWriteCount++;
            return Task.CompletedTask;
        }

        public Task<ContentReleaseStateRecord> UpdateStateAsync(
            ContentReleaseStateRecord state,
            CancellationToken cancellationToken = default)
        {
            if (_states.TryGetValue(state.Environment, out var current)
                && !string.Equals(current.ETag, state.ETag, StringComparison.Ordinal))
            {
                throw new ConcurrencyConflictException("simulated stale state");
            }

            var saved = state with { ETag = NextETag() };
            _states[state.Environment] = saved;
            StateWriteCount++;
            return Task.FromResult(saved);
        }

        public Task<ContentPackageManifestDto?> GetPublicManifestAsync(
            string manifestId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(_public.TryGetValue(manifestId, out var package)
                ? package.Manifest
                : null);

        private string NextETag() => $"\"{Interlocked.Increment(ref _version)}\"";
    }

    private sealed class SpyContentReleaseTelemetry : IContentReleaseTelemetry
    {
        public List<(string ManifestId, bool Replayed)> Imports { get; } = [];
        public List<(string ManifestId, bool Changed)> Promotions { get; } = [];
        public List<string> Rejections { get; } = [];
        public List<(string ManifestId, ContentReleaseEnvironment Environment, bool Changed)> Rollbacks { get; } = [];

        public void TrackImported(string manifestId, bool replayed) => Imports.Add((manifestId, replayed));
        public void TrackPromoted(string manifestId, bool changed) => Promotions.Add((manifestId, changed));
        public void TrackRejected(string reason) => Rejections.Add(reason);
        public void TrackRolledBack(
            string manifestId,
            ContentReleaseEnvironment environment,
            bool changed)
            => Rollbacks.Add((manifestId, environment, changed));
    }

    private static class ReleaseFixture
    {
        private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

        public static ImportContentReleaseRequest Create(
            string suffix,
            bool includePublicLeak = false)
        {
            var id = $"question-{suffix}";
            var publicPayload = includePublicLeak
                ? JsonSerializer.SerializeToElement(new Dictionary<string, object?>
                {
                    ["correct"] = "a",
                    ["id"] = id,
                    ["prompt"] = "Question publique é"
                })
                : JsonSerializer.SerializeToElement(new Dictionary<string, object?>
                {
                    ["choices"] = new[] { "a", "b" },
                    ["id"] = id,
                    ["kind"] = "mcq",
                    ["prompt"] = "Question publique é",
                    ["schemaVersion"] = 2
                });
            var privatePayload = JsonSerializer.SerializeToElement(new Dictionary<string, object?>
            {
                ["correct"] = new[] { "a" },
                ["id"] = id,
                ["kind"] = "mcq",
                ["rationale"] = "Private explanation",
                ["schemaVersion"] = 2
            });

            return new ImportContentReleaseRequest(
                ContentReleaseContracts.ImportContractVersion,
                BuildPackage("public", "public", $"questions/{id}.json", id, publicPayload),
                BuildPackage("answerKey", "private", $"solutions/{id}.json", id, privatePayload));
        }

        private static ContentPackageDto BuildPackage(
            string channel,
            string artifact,
            string path,
            string id,
            JsonElement payload)
        {
            var bytes = ContentPackageIntegrity.Canonicalize(payload);
            var entry = new ContentManifestFileDto(
                id,
                path,
                ContentPackageIntegrity.ComputeSha256(bytes),
                bytes.LongLength);
            var body = new Dictionary<string, object?>
            {
                ["algorithm"] = ContentReleaseContracts.Algorithm,
                ["artifact"] = artifact,
                ["channel"] = channel,
                ["fileCount"] = 1,
                ["files"] = new[] { entry },
                ["schema"] = ContentReleaseContracts.PackageManifestSchema,
                ["serialization"] = ContentReleaseContracts.Serialization
            };
            var rootHash = ContentPackageIntegrity.ComputeSha256(
                ContentPackageIntegrity.Canonicalize(
                    JsonSerializer.SerializeToElement(body, JsonOptions)));
            var manifest = new ContentPackageManifestDto(
                ContentReleaseContracts.PackageManifestSchema,
                channel,
                artifact,
                ContentReleaseContracts.Algorithm,
                ContentReleaseContracts.Serialization,
                1,
                [entry],
                $"sha256:{rootHash}",
                rootHash);
            return new ContentPackageDto(manifest, [new ContentPackageFileDto(path, payload)]);
        }
    }
}
