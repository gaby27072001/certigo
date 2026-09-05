using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Certigo.Infrastructure.ContentContracts;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class MergedContentPackageIntegrationTests
{
    public const string RootVariable = "CERTIGO_CONTENT_GOLDEN_ROOT";
    private const string ReleaseId =
        "sha256:c8769090e3e265af9fb1ee95ae460751be4d4cfc30066a868aa966b6ca1dc597";
    private const string PublicManifestId =
        "sha256:dd95aafc2ac3e7859df31cb4e7aee271cf2c25cdcfee1fa23ac3eab8ca7ced79";
    private const string PrivateManifestId =
        "sha256:65b1914f4cbeb87d7be9cd939a7cd3d03deb344b408b6ef6de91e0346410f793";

    [MergedContentGoldenFact]
    public async Task Merged_v3_package_verifies_and_projects_the_definitive_runtime_graph()
    {
        var root = Environment.GetEnvironmentVariable(RootVariable)!;
        var verifier = new ContentContractVerifier(
            new FileReleaseSource(root),
            new JsonSchemaContentContractValidator(),
            ContentReleaseLimits.Default);

        var verified = await verifier.VerifyReleaseAsync(ReleaseId);
        var projection = new RuntimeContentProjector().Project(verified.Graph);
        verifier.VerifyProjectedPublic(projection);

        verified.Descriptor.ReleaseId.Should().Be(ReleaseId);
        verified.PublicManifest.ManifestId.Should().Be(PublicManifestId);
        verified.PrivateManifest.ManifestId.Should().Be(PrivateManifestId);
        projection.Tracks.Should().HaveCount(31);
        projection.Tracks.Should().Contain(track => track.RuntimeId == "microsoft.az-900.track.main");
        projection.Tracks.Should().Contain(track => track.RuntimeId == "aws.clf-c02.track.main");
        projection.Tracks.Should().NotContain(track => track.RuntimeId == "microsoft.ai-900.track.main");
        projection.Tracks.Should().OnlyContain(
            track => track.LifecycleStatus == "active" || track.LifecycleStatus == "retiring");
    }

    private sealed class FileReleaseSource(string root) : IContentReleaseSource
    {
        public Task<ContentBlobObject> ReadReleaseAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
            => Read("release.json");

        public Task<ContentBlobObject> ReadManifestAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => Read(Path.Combine(DirectoryName(artifact), "manifest.json"));

        public Task<ContentBlobObject> ReadFileAsync(
            ContentArtifact artifact,
            string manifestId,
            string path,
            CancellationToken cancellationToken = default)
            => Read(Path.Combine(DirectoryName(artifact), path.Replace('/', Path.DirectorySeparatorChar)));

        public Task<IReadOnlyList<string>> ListFilesAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
        {
            var directory = Path.Combine(root, DirectoryName(artifact));
            IReadOnlyList<string> files = Directory
                .EnumerateFiles(directory, "*.json", SearchOption.AllDirectories)
                .Select(path => Path.GetRelativePath(directory, path).Replace('\\', '/'))
                .Where(path => path != "manifest.json")
                .OrderBy(path => path, StringComparer.Ordinal)
                .ToArray();
            return Task.FromResult(files);
        }

        private Task<ContentBlobObject> Read(string relativePath)
        {
            var path = Path.Combine(root, relativePath);
            return Task.FromResult(new ContentBlobObject(
                relativePath.Replace('\\', '/'),
                "fixture-version",
                "\"fixture-etag\"",
                true,
                File.ReadAllBytes(path)));
        }

        private static string DirectoryName(ContentArtifact artifact)
            => artifact == ContentArtifact.Public ? "public" : "private";
    }
}

public sealed class MergedContentGoldenFactAttribute : FactAttribute
{
    public MergedContentGoldenFactAttribute()
    {
        var root = Environment.GetEnvironmentVariable(
            MergedContentPackageIntegrationTests.RootVariable);
        if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
        {
            Skip =
                $"Set {MergedContentPackageIntegrationTests.RootVariable} to the merged certigo-content v3 dist root.";
        }
    }
}
