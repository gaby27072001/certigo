using System.Net;
using System.Text;
using Certigo.Api.Functions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class PilotLearningFunctionsTests
{
    private const string PilotId = "responsible-ai-assistants";
    private const string LessonId = "verify-claims";
    private static readonly string Digest = "sha256:" + new string('a', 64);

    [Fact]
    public async Task GetContent_Returns_exact_public_bytes_and_version_digest()
    {
        var bytes = Encoding.UTF8.GetBytes("{\"schema\":\"certigo.editorial.pilot/v1\"}");
        var service = new FakePilotLearningService
        {
            Content = new PilotContentPackage(
                PilotId,
                Digest,
                bytes,
                new HashSet<string>([LessonId], StringComparer.Ordinal)),
        };
        var function = new PilotLearningFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/pilots/responsible-ai-assistants/content");

        var response = await function.GetContent(request, PilotId, context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        response.Headers.GetValues("X-Certigo-Pilot-Content-Digest").Should().Equal(Digest);
        response.Headers.GetValues("ETag").Should().Equal($"\"{Digest}\"");
        response.Headers.GetValues("Cache-Control").Should().Equal("no-store");
        response.Body.Position = 0;
        using var copied = new MemoryStream();
        await response.Body.CopyToAsync(copied);
        copied.ToArray().Should().Equal(bytes);
    }

    [Fact]
    public async Task Activity_functions_require_identity_and_mark_read_only_on_explicit_action()
    {
        var service = new FakePilotLearningService();
        var function = new PilotLearningFunctions(service);
        var context = TestFunctionContext.Authenticated("synthetic-owner");
        var accessRequest = new TestHttpRequestData(
            context,
            "POST",
            $"https://localhost/api/me/pilots/{PilotId}/lessons/{LessonId}/access/{Digest}");

        var accessed = await function.RecordAccess(
            accessRequest, PilotId, LessonId, Digest, context);
        var accessResult = await accessed.ReadJsonAsync<PilotLessonProgressDto>();

        accessed.StatusCode.Should().Be(HttpStatusCode.OK);
        service.LastMarkRead.Should().BeFalse();
        accessResult.MarkedReadAt.Should().BeNull();

        var readRequest = new TestHttpRequestData(
            context,
            "POST",
            $"https://localhost/api/me/pilots/{PilotId}/lessons/{LessonId}/read/{Digest}");
        var marked = await function.MarkRead(readRequest, PilotId, LessonId, Digest, context);
        var readResult = await marked.ReadJsonAsync<PilotLessonProgressDto>();

        marked.StatusCode.Should().Be(HttpStatusCode.OK);
        service.LastMarkRead.Should().BeTrue();
        readResult.MarkedReadAt.Should().NotBeNull();
    }

    [Fact]
    public async Task GetContent_does_not_invoke_service_without_authenticated_identity()
    {
        var service = new FakePilotLearningService();
        var function = new PilotLearningFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/pilots/responsible-ai-assistants/content");

        var act = () => function.GetContent(request, PilotId, context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.ContentCallCount.Should().Be(0);
    }

    private sealed class FakePilotLearningService : IPilotLearningService
    {
        public PilotContentPackage? Content { get; init; }
        public int ContentCallCount { get; private set; }
        public bool? LastMarkRead { get; private set; }

        public Task<PilotContentPackage?> GetContentAsync(
            string pilotId,
            CancellationToken cancellationToken = default)
        {
            ContentCallCount++;
            return Task.FromResult(
                Content?.PilotId == pilotId ? Content : null);
        }

        public Task<PilotHistoryDto?> GetHistoryAsync(
            string pilotId,
            string contentDigest,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<PilotHistoryDto?>(new(pilotId, contentDigest, null, []));

        public Task<PilotLessonProgressDto?> RecordAccessAsync(
            string pilotId,
            string lessonId,
            string contentDigest,
            bool markRead,
            CancellationToken cancellationToken = default)
        {
            LastMarkRead = markRead;
            return Task.FromResult<PilotLessonProgressDto?>(
                new(lessonId, DateTimeOffset.UtcNow, markRead ? DateTimeOffset.UtcNow : null));
        }
    }
}
