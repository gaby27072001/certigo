using System.Net;
using System.Text;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class OfflineContentFunctionsTests
{
    private const string ManifestId =
        "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    private const string PayloadHash =
        "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
    private const string ManifestVersion =
        "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";

    [Fact]
    public async Task Every_offline_endpoint_requires_a_learner_identity()
    {
        var service = new FakeOfflineContentService();
        var function = new OfflineContentFunctions(service);
        var context = new TestFunctionContext();

        var manifest = () => function.GetActiveManifest(
            Request(context, "content/releases/active/offline-manifest"),
            context);
        var catalog = () => function.GetCatalog(
            Request(context, $"content/releases/{ManifestId}/offline/catalog"),
            ManifestId,
            context);
        var lesson = () => function.GetLesson(
            Request(context, $"content/releases/{ManifestId}/offline/tracks/t/lessons/l"),
            ManifestId,
            "t",
            "l",
            context);

        await manifest.Should().ThrowAsync<UnauthorizedAccessException>();
        await catalog.Should().ThrowAsync<UnauthorizedAccessException>();
        await lesson.Should().ThrowAsync<UnauthorizedAccessException>();
        service.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task Pinned_payload_response_preserves_exact_bytes_and_verification_headers()
    {
        var bytes = Encoding.UTF8.GetBytes("""{"id":"lesson-1","title":"é"}""");
        var service = new FakeOfflineContentService
        {
            Lesson = new OfflineContentPayload(ManifestId, PayloadHash, bytes),
        };
        var function = new OfflineContentFunctions(service);
        var context = TestFunctionContext.Authenticated();

        var response = await function.GetLesson(
            Request(
                context,
                $"content/releases/{ManifestId}/offline/tracks/t/lessons/l?sha256={PayloadHash}"),
            ManifestId,
            "t",
            "l",
            context);
        response.Body.Position = 0;
        using var memory = new MemoryStream();
        await response.Body.CopyToAsync(memory);

        memory.ToArray().Should().Equal(bytes);
        response.Headers.GetValues("X-Content-Manifest-Id").Should().Equal(ManifestId);
        response.Headers.GetValues("X-Content-SHA256").Should().Equal(PayloadHash);
        response.Headers.GetValues("Content-Length").Should().Equal(bytes.Length.ToString());
        response.Headers.GetValues("ETag").Should().Equal($"\"sha256:{PayloadHash}\"");
        response.Headers.GetValues("Cache-Control")
            .Should().Equal("max-age=31536000, private, immutable");
    }

    [Fact]
    public async Task Pinned_payload_requires_the_descriptor_hash_in_the_request_uri()
    {
        var function = new OfflineContentFunctions(new FakeOfflineContentService());
        var context = TestFunctionContext.Authenticated();

        var missing = () => function.GetCatalog(
            Request(context, $"content/releases/{ManifestId}/offline/catalog"),
            ManifestId,
            context);
        var changed = () => function.GetCatalog(
            Request(
                context,
                $"content/releases/{ManifestId}/offline/catalog?sha256="
                + "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"),
            ManifestId,
            context);

        await missing.Should().ThrowAsync<BadRequestException>();
        await changed.Should().ThrowAsync<ContentReleaseStateException>();
    }

    [Fact]
    public async Task Missing_pinned_lesson_returns_not_found()
    {
        var service = new FakeOfflineContentService { Lesson = null };
        var function = new OfflineContentFunctions(service);
        var context = TestFunctionContext.Authenticated();

        var response = await function.GetLesson(
            Request(
                context,
                $"content/releases/{ManifestId}/offline/tracks/t/lessons/missing?sha256={PayloadHash}"),
            ManifestId,
            "t",
            "missing",
            context);

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    private static TestHttpRequestData Request(TestFunctionContext context, string path)
        => new(context, "GET", $"https://localhost/api/{path}");

    private sealed class FakeOfflineContentService : IOfflineContentService
    {
        public int CallCount { get; private set; }

        public OfflineContentPayload? Lesson { get; set; } = new(
            ManifestId,
            PayloadHash,
            Encoding.UTF8.GetBytes("{}"));

        public Task<OfflineContentManifest> GetActiveManifestAsync(
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(new OfflineContentManifest(
                ContentReleaseContracts.OfflineManifestV1,
                ManifestId,
                ManifestVersion,
                ContentReleaseContracts.PackageManifestV3,
                0,
                []));
        }

        public Task<OfflineContentPayload> GetCatalogAsync(
            string publicManifestId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(new OfflineContentPayload(
                publicManifestId,
                PayloadHash,
                Encoding.UTF8.GetBytes("{}")));
        }

        public Task<OfflineContentPayload?> GetLessonAsync(
            string publicManifestId,
            string trackId,
            string lessonId,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(Lesson);
        }
    }
}
