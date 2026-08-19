using System.Net;
using Certigo.Api.Auth;
using Certigo.Api.Functions;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using FluentAssertions;
using Microsoft.Azure.Functions.Worker.Http;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class ContentReleaseFunctionsTests
{
    private const string ReleaseId =
        "sha256:6094410ae57637d55681fdeec3eae50fbfd69ba953741d069c95a478bee73f7f";
    private const string PublicManifestId =
        "sha256:e5663734ac88ac916cff3b6e1206dc03bacf7f6d530e8b115e3f198a1e6304ee";

    [Fact]
    public async Task Import_requires_the_exact_admin_app_role()
    {
        var function = CreateFunction(new FakeContentReleaseService());
        var context = TestFunctionContext.Authenticated();
        var request = Request(context, "POST", $"/api/admin/content/releases/{ReleaseId}/import");

        var action = () => function.Import(request, ReleaseId, context);

        await action.Should().ThrowAsync<ContentAccessForbiddenException>();
    }

    [Fact]
    public async Task Import_with_admin_role_returns_created_and_never_accepts_package_body()
    {
        var service = new FakeContentReleaseService();
        var function = CreateFunction(service);
        var context = TestFunctionContext.Authenticated(role: "Content.Release.Admin");
        var request = Request(context, "POST", $"/api/admin/content/releases/{ReleaseId}/import");

        var response = await function.Import(request, ReleaseId, context);

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        service.ImportedReleaseId.Should().Be(ReleaseId);
        service.ActorId.Should().Be("user-1");
    }

    [Fact]
    public async Task Promotion_without_if_match_fails_closed()
    {
        var function = CreateFunction(new FakeContentReleaseService());
        var context = TestFunctionContext.Authenticated(role: "Content.Release.Admin");
        var request = Request(context, "POST", $"/api/admin/content/releases/{ReleaseId}/promote");

        var action = () => function.Promote(request, ReleaseId, context);

        await action.Should().ThrowAsync<ContentReleasePreconditionRequiredException>();
    }

    [Fact]
    public async Task Active_manifest_serialization_contains_only_public_contract_fields()
    {
        var function = CreateFunction(new FakeContentReleaseService());
        var context = TestFunctionContext.Authenticated();
        var request = Request(context, "GET", "/api/content/releases/active/manifest");

        var response = await function.GetActivePublicManifest(request, context);
        var body = await response.ReadBodyAsStringAsync();

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Headers.GetValues("ETag").Should().Equal($"\"{PublicManifestId}\"");
        body.Should().Contain(PublicManifestId);
        body.Should().NotContain("privateManifestId");
        body.Should().NotContain("releaseId");
        body.Should().NotContain("correctOptionIds");
        body.Should().NotContain("rationale");
        body.Should().NotContain("answerKey");
    }

    [Fact]
    public async Task Active_manifest_honors_if_none_match()
    {
        var function = CreateFunction(new FakeContentReleaseService());
        var context = TestFunctionContext.Authenticated();
        var headers = new HttpHeadersCollection();
        headers.Add("If-None-Match", $"\"{PublicManifestId}\"");
        var request = Request(
            context,
            "GET",
            "/api/content/releases/active/manifest",
            headers);

        var response = await function.GetActivePublicManifest(request, context);

        response.StatusCode.Should().Be(HttpStatusCode.NotModified);
        (await response.ReadBodyAsStringAsync()).Should().BeEmpty();
    }

    private static ContentReleaseFunctions CreateFunction(IContentReleaseService service)
        => new(service, new ContentAdminAuthorization("Content.Release.Admin", allowDevIdentity: false));

    private static TestHttpRequestData Request(
        TestFunctionContext context,
        string method,
        string path,
        HttpHeadersCollection? headers = null)
        => new(
            context,
            method,
            $"https://localhost{path}",
            headers: headers);

    private sealed class FakeContentReleaseService : IContentReleaseService
    {
        public string? ImportedReleaseId { get; private set; }
        public string? ActorId { get; private set; }

        public Task<ContentImportResult> ImportAsync(
            string releaseId,
            string actorId,
            CancellationToken cancellationToken = default)
        {
            ImportedReleaseId = releaseId;
            ActorId = actorId;
            return Task.FromResult(new ContentImportResult(
                Receipt(releaseId),
                AlreadyImported: false));
        }

        public Task<ActiveContentPointer?> GetPointerAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult<ActiveContentPointer?>(Pointer());

        public Task<ActiveContentPointer> PromoteAsync(
            string releaseId,
            string expectedETag,
            string actorId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(Pointer());

        public Task<ActiveContentPointer> RollbackAsync(
            string expectedETag,
            string actorId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(Pointer());

        public Task<ActivePublicManifestResult?> GetActivePublicManifestAsync(
            CancellationToken cancellationToken = default)
            => Task.FromResult<ActivePublicManifestResult?>(new ActivePublicManifestResult(
                new ContentPackageManifest(
                    ContentReleaseContracts.PackageManifestV3,
                    "public",
                    "public",
                    "sha256",
                    "json-sorted-keys-compact-utf8-lf",
                    1,
                    [
                        new ContentPackageFile(
                            "certification-catalog",
                            "catalog/certifications.json",
                            "certificationCatalog",
                            new string('a', 64),
                            123),
                    ],
                    PublicManifestId,
                    PublicManifestId[7..]),
                PublicManifestId));

        private static ContentReleaseReceipt Receipt(string releaseId)
            => new(
                $"release::{releaseId}",
                ContentReleaseContracts.RuntimeScope,
                releaseId,
                PublicManifestId,
                "sha256:1e36233639e4cf7d6dead3fa3c70cb22faa7d02630bbb08333e9b8b5d6187e10",
                1,
                1,
                1,
                new DateTimeOffset(2026, 8, 19, 12, 0, 0, TimeSpan.Zero),
                "user-1",
                0,
                new string('0', 64));

        private static ActiveContentPointer Pointer()
            => new(
                "active",
                ContentReleaseContracts.RuntimeScope,
                ReleaseId,
                PublicManifestId,
                null,
                null,
                new DateTimeOffset(2026, 8, 19, 12, 0, 0, TimeSpan.Zero),
                "user-1")
            {
                ETag = "\"pointer-etag\"",
            };
    }
}
