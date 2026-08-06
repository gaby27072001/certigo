using System.Net;
using System.Security.Claims;
using System.Text;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ContentReleaseFunctionsTests
{
    private static readonly string ManifestId = $"sha256:{new string('a', 64)}";

    [Fact]
    public async Task Active_manifest_HTTP_shape_never_serializes_private_metadata()
    {
        var service = new FakeReleaseService
        {
            Manifest = new ActiveContentManifestDto(
                ManifestId,
                ContentReleaseOptions.PackageManifestSchema,
                "public",
                "public",
                ContentReleaseOptions.HashAlgorithm,
                ContentReleaseOptions.Serialization,
                1,
                new string('b', 64),
                [new ContentArtifactFile(
                    "question-set",
                    "questions/questions.json",
                    new string('b', 64),
                    12)])
        };
        var function = new ContentReleaseFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/content/releases/active/public");

        var response = await function.GetActiveManifest(request, context);
        var json = await response.ReadBodyAsStringAsync();

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        json.Should().Contain(ManifestId);
        var lowerJson = json.ToLowerInvariant();
        lowerJson.Should().NotContain("private");
        lowerJson.Should().NotContain("answerkey");
        lowerJson.Should().NotContain("\"correct\"");
        lowerJson.Should().NotContain("rationale");
    }

    [Fact]
    public async Task Active_file_returns_only_bytes_supplied_by_public_service_path()
    {
        var service = new FakeReleaseService
        {
            File = new ContentReleaseFileDto(
                "questions/questions.json",
                Encoding.UTF8.GetBytes("""{"id":"q1"}"""))
        };
        var function = new ContentReleaseFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/content/releases/active/public/files/questions/questions.json");

        var response = await function.GetActiveFile(
            request,
            "questions/questions.json",
            context);
        var body = await response.ReadBodyAsStringAsync();

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        body.Should().Be("""{"id":"q1"}""");
        service.LastPath.Should().Be("questions/questions.json");
    }

    [Fact]
    public async Task Operations_require_an_authenticated_principal_in_addition_to_function_key()
    {
        var service = new FakeReleaseService();
        var function = new ContentReleaseFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "POST",
            $"https://localhost/api/ops/content/releases/{ManifestId}/promote");

        var act = () => function.Promote(request, ManifestId, context);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        service.PromoteCalls.Should().Be(0);
    }

    [Fact]
    public async Task Operations_require_the_content_release_operator_role()
    {
        var service = new FakeReleaseService();
        var function = new ContentReleaseFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "POST",
            $"https://localhost/api/ops/content/releases/{ManifestId}/promote");

        var act = () => function.Promote(request, ManifestId, context);

        await act.Should().ThrowAsync<ForbiddenException>();
        service.PromoteCalls.Should().Be(0);
    }

    [Fact]
    public async Task Operator_can_promote_an_imported_release()
    {
        var service = new FakeReleaseService();
        var function = new ContentReleaseFunctions(service);
        var context = TestFunctionContext.Authenticated(
            roles: [ContentReleaseFunctions.OperatorRole]);
        var request = new TestHttpRequestData(
            context,
            "POST",
            $"https://localhost/api/ops/content/releases/{ManifestId}/promote");

        var response = await function.Promote(request, ManifestId, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.PromoteCalls.Should().Be(1);
    }

    [Fact]
    public async Task Raw_Entra_roles_claim_authorizes_an_operator()
    {
        var service = new FakeReleaseService();
        var function = new ContentReleaseFunctions(service);
        var context = new TestFunctionContext();
        context.Items["User"] = new ClaimsPrincipal(new ClaimsIdentity(
            [new Claim("roles", ContentReleaseFunctions.OperatorRole)],
            authenticationType: "test"));
        var request = new TestHttpRequestData(
            context,
            "POST",
            $"https://localhost/api/ops/content/releases/{ManifestId}/promote");

        var response = await function.Promote(request, ManifestId, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.PromoteCalls.Should().Be(1);
    }

    private sealed class FakeReleaseService : IContentReleaseService
    {
        public ActiveContentManifestDto? Manifest { get; init; }
        public ContentReleaseFileDto? File { get; init; }
        public string? LastPath { get; private set; }
        public int PromoteCalls { get; private set; }

        public Task<ContentReleaseImportResultDto> ImportAsync(
            ContentReleaseImportRequest request,
            CancellationToken cancellationToken = default)
            => Task.FromResult(new ContentReleaseImportResultDto(
                ManifestId,
                ManifestId,
                false,
                1,
                1));

        public Task<ContentReleaseStateDto> PromoteAsync(
            string manifestId,
            CancellationToken cancellationToken = default)
        {
            PromoteCalls++;
            return Task.FromResult(new ContentReleaseStateDto(
                "staging",
                manifestId,
                null,
                DateTimeOffset.UnixEpoch,
                "promote"));
        }

        public Task<ContentReleaseStateDto> RollbackAsync(
            string manifestId,
            CancellationToken cancellationToken = default)
            => PromoteAsync(manifestId, cancellationToken);

        public Task<ActiveContentManifestDto?> GetActiveManifestAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult(Manifest);

        public Task<ContentReleaseFileDto?> GetActivePublicFileAsync(
            string path,
            CancellationToken cancellationToken = default)
        {
            LastPath = path;
            return Task.FromResult(File);
        }
    }
}
