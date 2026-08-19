using System.Text;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Infrastructure.ContentContracts;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class ContentContractGoldenTests
{
    private const string PublicManifestId =
        "sha256:e5663734ac88ac916cff3b6e1206dc03bacf7f6d530e8b115e3f198a1e6304ee";
    private const string PrivateManifestId =
        "sha256:1e36233639e4cf7d6dead3fa3c70cb22faa7d02630bbb08333e9b8b5d6187e10";
    private const string ReleaseId =
        "sha256:6094410ae57637d55681fdeec3eae50fbfd69ba953741d069c95a478bee73f7f";

    [Fact]
    public void Merged_release_descriptor_recomputes_the_definitive_golden()
    {
        var verifier = Verifier();
        var json = $$"""
            {
              "schema": "certigo.content.release/v1",
              "algorithm": "sha256",
              "canonicalization": "json-sorted-keys-compact-utf8",
              "publicManifestId": "{{PublicManifestId}}",
              "privateManifestId": "{{PrivateManifestId}}",
              "releaseId": "{{ReleaseId}}"
            }
            """;

        var descriptor = verifier.VerifyDescriptor(Encoding.UTF8.GetBytes(json), ReleaseId);

        descriptor.PublicManifestId.Should().Be(PublicManifestId);
        descriptor.PrivateManifestId.Should().Be(PrivateManifestId);
        descriptor.ReleaseId.Should().Be(ReleaseId);
    }

    [Fact]
    public void Merged_private_v3_manifest_recomputes_the_definitive_golden()
    {
        var verifier = Verifier();
        var json = """
            {
              "schema": "certigo.content.package-manifest/v3",
              "channel": "answerKey",
              "artifact": "private",
              "algorithm": "sha256",
              "serialization": "json-sorted-keys-compact-utf8-lf",
              "fileCount": 5,
              "files": [
                {
                  "id": "aws.clf-c02.domain-1.cloud-value.001",
                  "path": "solutions/aws/clf-c02/aws.clf-c02.domain-1.cloud-value.001.json",
                  "hash": "efe41e1f955541eeb613ff223d1b804178b992b837ad4006f83c38f57c9b4e30",
                  "size": 223,
                  "resourceType": "solution"
                },
                {
                  "id": "microsoft.ai-900.section-1.ai-workloads.001",
                  "path": "solutions/microsoft/ai-900/microsoft.ai-900.section-1.ai-workloads.001.json",
                  "hash": "6a72bcac2c1190638cd82856d8640deeb36ab44671115192f79ade0d9f3a607a",
                  "size": 235,
                  "resourceType": "solution"
                },
                {
                  "id": "microsoft.az-900.section-1.cloud-models.001",
                  "path": "solutions/microsoft/az-900/microsoft.az-900.section-1.cloud-models.001.json",
                  "hash": "08e2bce24fff237ac7a3c0a28c5cf12fa0e8208dd18b9bb7c8a5227815ccaa0d",
                  "size": 259,
                  "resourceType": "solution"
                },
                {
                  "id": "microsoft.dp-900.section-1.data-types.001",
                  "path": "solutions/microsoft/dp-900/microsoft.dp-900.section-1.data-types.001.json",
                  "hash": "4cb4ed2f0c004e4a8db3c7936799e106b0ab8aa148a01a946926634593d85b7c",
                  "size": 234,
                  "resourceType": "solution"
                },
                {
                  "id": "microsoft.sc-900.section-1.identity-concepts.001",
                  "path": "solutions/microsoft/sc-900/microsoft.sc-900.section-1.identity-concepts.001.json",
                  "hash": "fac4f32ede21cfbcb50c81d653cf60f9a250ea63b0a6ea7d2fb3babce90e3af7",
                  "size": 240,
                  "resourceType": "solution"
                }
              ],
              "manifestId": "sha256:1e36233639e4cf7d6dead3fa3c70cb22faa7d02630bbb08333e9b8b5d6187e10",
              "rootHash": "1e36233639e4cf7d6dead3fa3c70cb22faa7d02630bbb08333e9b8b5d6187e10"
            }
            """;

        var manifest = verifier.VerifyStandaloneManifest(
            Encoding.UTF8.GetBytes(json),
            ContentArtifact.Private);

        manifest.ManifestId.Should().Be(PrivateManifestId);
    }

    private static ContentContractVerifier Verifier()
        => new(
            new UnusedSource(),
            new JsonSchemaContentContractValidator(),
            ContentReleaseLimits.Default);

    private sealed class UnusedSource : IContentReleaseSource
    {
        public Task<ContentBlobObject> ReadReleaseAsync(
            string releaseId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ContentBlobObject> ReadManifestAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<ContentBlobObject> ReadFileAsync(
            ContentArtifact artifact,
            string manifestId,
            string path,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();

        public Task<IReadOnlyList<string>> ListFilesAsync(
            ContentArtifact artifact,
            string manifestId,
            CancellationToken cancellationToken = default)
            => throw new NotSupportedException();
    }
}
