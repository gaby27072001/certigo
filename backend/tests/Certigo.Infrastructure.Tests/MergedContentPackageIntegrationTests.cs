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
        "sha256:6094410ae57637d55681fdeec3eae50fbfd69ba953741d069c95a478bee73f7f";

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
        verified.PublicManifest.FileCount.Should().Be(34);
        verified.PrivateManifest.FileCount.Should().Be(5);
        projection.Tracks.Should().HaveCount(5);
        projection.Lessons.Should().HaveCount(5);
        projection.AnswerKeys.Should().HaveCount(5);
        projection.Tracks.Should().Contain(track => track.RuntimeId == "az-900");
        projection.Tracks.Should().Contain(track => track.RuntimeId == "aws.clf-c02.track.main");
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
