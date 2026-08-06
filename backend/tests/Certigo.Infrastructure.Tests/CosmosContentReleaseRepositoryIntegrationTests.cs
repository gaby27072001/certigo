using System.Security.Cryptography;
using System.Text;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Infrastructure.Cosmos;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class CosmosContentReleaseRepositoryIntegrationTests(CosmosEmulatorFixture fixture)
    : IClassFixture<CosmosEmulatorFixture>
{
    [CosmosEmulatorFact]
    public async Task Import_promote_and_rollback_are_idempotent_and_keep_private_files_off_public_reads()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosContentReleaseRepository(context);
        var first = Release('a', 'b', "q1");
        var second = Release('c', 'd', "q2");

        (await repository.ImportAsync(first)).Should().BeFalse();
        (await repository.ImportAsync(first)).Should().BeTrue();
        await repository.ImportAsync(second);

        var firstPromotion = await repository.PromoteAsync(
            "staging",
            first.ManifestId,
            ContentReleaseOperation.Promote,
            DateTimeOffset.UtcNow);
        var secondPromotion = await repository.PromoteAsync(
            "staging",
            second.ManifestId,
            ContentReleaseOperation.Promote,
            DateTimeOffset.UtcNow.AddSeconds(1));
        var rollbackPromotion = await repository.PromoteAsync(
            "staging",
            first.ManifestId,
            ContentReleaseOperation.Rollback,
            DateTimeOffset.UtcNow.AddSeconds(2));
        var firstState = firstPromotion.State;
        var secondState = secondPromotion.State;
        var rollback = rollbackPromotion.State;

        firstPromotion.Changed.Should().BeTrue();
        secondPromotion.Changed.Should().BeTrue();
        rollbackPromotion.Changed.Should().BeTrue();
        firstState.PreviousManifestId.Should().BeNull();
        secondState.PreviousManifestId.Should().Be(first.ManifestId);
        rollback.ActiveManifestId.Should().Be(first.ManifestId);
        rollback.History.Should().HaveCount(3);
        (await repository.GetActivePublicFileAsync("staging", "questions/questions.json"))
            .Should().NotBeNull();
        (await repository.GetActivePublicFileAsync("staging", "solutions/answers.json"))
            .Should().BeNull();
        (await repository.GetActivePrivateFileAsync("staging", "solutions/answers.json"))
            .Should().NotBeNull("the server-only grading seam can read the private channel");
    }

    private static VerifiedContentRelease Release(char publicId, char privateId, string questionId)
    {
        var publicManifestId = $"sha256:{new string(publicId, 64)}";
        var privateManifestId = $"sha256:{new string(privateId, 64)}";
        var manifestId = CompositeManifestId(publicManifestId, privateManifestId);
        var publicBytes = Encoding.UTF8.GetBytes($$"""{"id":"{{questionId}}"}""");
        var privateBytes = Encoding.UTF8.GetBytes(
            $$"""{"itemId":"{{questionId}}","correct":["a"]}""");
        var publicFile = File("public", "question-set", "questions/questions.json", publicBytes);
        var privateFile = File("answerKey", "solution-set", "solutions/answers.json", privateBytes);
        var publicManifest = new ContentArtifactManifest(
            ContentReleaseOptions.PackageManifestSchema,
            "public",
            "public",
            ContentReleaseOptions.HashAlgorithm,
            ContentReleaseOptions.Serialization,
            1,
            [new ContentArtifactFile(publicFile.Id, publicFile.Path, publicFile.Hash, publicFile.Size)],
            publicManifestId,
            new string(publicId, 64));
        var privateManifest = new ContentArtifactManifest(
            ContentReleaseOptions.PackageManifestSchema,
            "answerKey",
            "private",
            ContentReleaseOptions.HashAlgorithm,
            ContentReleaseOptions.Serialization,
            1,
            [new ContentArtifactFile(privateFile.Id, privateFile.Path, privateFile.Hash, privateFile.Size)],
            privateManifestId,
            new string(privateId, 64));
        return new VerifiedContentRelease(
            manifestId,
            publicManifestId,
            new string(publicId, 64),
            publicManifest,
            privateManifest,
            [publicFile, privateFile],
            DateTimeOffset.UtcNow);
    }

    private static string CompositeManifestId(
        string publicManifestId,
        string privateManifestId)
        => $"sha256:{Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(
            $"{publicManifestId}\n{privateManifestId}\n"))).ToLowerInvariant()}";

    private static VerifiedContentReleaseFile File(
        string channel,
        string id,
        string path,
        byte[] content)
        => new(
            channel,
            id,
            path,
            Convert.ToHexString(SHA256.HashData(content)).ToLowerInvariant(),
            content.LongLength,
            content);
}
