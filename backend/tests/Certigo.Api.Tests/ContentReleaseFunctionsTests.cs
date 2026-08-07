using System.Net;
using System.Text.Json;
using Certigo.Api.Functions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ContentReleaseFunctionsTests
{
    [Fact]
    public async Task GetActiveManifest_requires_authenticated_learner()
    {
        var function = new ContentReleaseFunctions(new FakeContentReleaseService());
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/content/manifest");

        var act = () => function.GetActiveManifest(request, context);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
    }

    [Fact]
    public async Task Every_content_release_endpoint_response_excludes_private_answer_fields()
    {
        var service = new FakeContentReleaseService();
        var function = new ContentReleaseFunctions(service);
        var adminContext = new TestFunctionContext();
        var learnerContext = TestFunctionContext.Authenticated();

        var importResponse = await function.Import(
            new TestHttpRequestData(
                adminContext,
                "POST",
                "https://localhost/api/admin/content/releases/import",
                service.ImportRequest),
            adminContext);
        var promoteResponse = await function.Promote(
            new TestHttpRequestData(
                adminContext,
                "POST",
                $"https://localhost/api/admin/content/releases/{service.Manifest.ManifestId}/promote"),
            service.Manifest.ManifestId,
            adminContext);
        var rollbackResponse = await function.Rollback(
            new TestHttpRequestData(
                adminContext,
                "POST",
                $"https://localhost/api/admin/content/releases/{service.Manifest.ManifestId}/rollback",
                new RollbackContentReleaseRequest(ContentReleaseEnvironment.Staging)),
            service.Manifest.ManifestId,
            adminContext);
        var manifestResponse = await function.GetActiveManifest(
            new TestHttpRequestData(
                learnerContext,
                "GET",
                "https://localhost/api/content/manifest"),
            learnerContext);

        importResponse.StatusCode.Should().Be(HttpStatusCode.Created);
        foreach (var response in new[]
                 {
                     importResponse,
                     promoteResponse,
                     rollbackResponse,
                     manifestResponse
                 })
        {
            var json = await response.ReadBodyAsStringAsync();
            var normalized = json.ToLowerInvariant();
            normalized.Should().NotContain("answerkey");
            normalized.Should().NotContain("\"correct\"");
            normalized.Should().NotContain("\"rationale\"");
        }
    }

    private sealed class FakeContentReleaseService : IContentReleaseService
    {
        public ContentPackageManifestDto Manifest { get; } = new(
            ContentReleaseContracts.PackageManifestSchema,
            "public",
            "public",
            ContentReleaseContracts.Algorithm,
            ContentReleaseContracts.Serialization,
            1,
            [new ContentManifestFileDto("q-1", "questions/q-1.json", new string('a', 64), 42)],
            $"sha256:{new string('b', 64)}",
            new string('b', 64));

        public ImportContentReleaseRequest ImportRequest
        {
            get
            {
                var publicContent = JsonSerializer.SerializeToElement(new { id = "q-1", prompt = "Question" });
                var privateContent = JsonSerializer.SerializeToElement(new
                {
                    id = "q-1",
                    correct = new[] { "a" },
                    rationale = "Private"
                });
                return new ImportContentReleaseRequest(
                    ContentReleaseContracts.ImportContractVersion,
                    new ContentPackageDto(
                        Manifest,
                        [new ContentPackageFileDto("questions/q-1.json", publicContent)]),
                    new ContentPackageDto(
                        Manifest with
                        {
                            Channel = "answerKey",
                            Artifact = "private",
                            ManifestId = $"sha256:{new string('c', 64)}",
                            RootHash = new string('c', 64),
                            Files =
                            [
                                new ContentManifestFileDto(
                                    "q-1",
                                    "solutions/q-1.json",
                                    new string('d', 64),
                                    55)
                            ]
                        },
                        [new ContentPackageFileDto("solutions/q-1.json", privateContent)]));
            }
        }

        public Task<ContentReleaseImportResultDto> ImportAsync(
            ImportContentReleaseRequest request,
            CancellationToken cancellationToken = default)
            => Task.FromResult(new ContentReleaseImportResultDto(
                Manifest.ManifestId,
                request.Private.Manifest.ManifestId,
                true,
                new ContentReleaseStateDto(
                    ContentReleaseEnvironment.Staging,
                    Manifest.ManifestId,
                    null)));

        public Task<ContentReleaseOperationResultDto> PromoteAsync(
            string manifestId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(new ContentReleaseOperationResultDto(
                ContentReleaseEnvironment.Prod,
                manifestId,
                null,
                true));

        public Task<ContentReleaseOperationResultDto> RollbackAsync(
            string manifestId,
            ContentReleaseEnvironment environment,
            CancellationToken cancellationToken = default)
            => Task.FromResult(new ContentReleaseOperationResultDto(
                environment,
                manifestId,
                $"sha256:{new string('e', 64)}",
                true));

        public Task<ContentPackageManifestDto> GetActivePublicManifestAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult(Manifest);
    }
}
