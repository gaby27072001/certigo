using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Application.Dtos;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class LessonFunctionsTests
{
    [Fact]
    public async Task GetLesson_ReturnsLesson_WhenFound()
    {
        var service = new FakeContentService();
        var function = new LessonFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/tracks/track-1/lessons/lesson-1");

        var response = await function.GetLesson(request, "track-1", "lesson-1", context);

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        service.LessonCallCount.Should().Be(1);
        service.LastTrackId.Should().Be("track-1");
        service.LastLessonId.Should().Be("lesson-1");
    }

    [Fact]
    public async Task GetLesson_Returns404_WhenMissing()
    {
        var service = new FakeContentService { LessonResult = null };
        var function = new LessonFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/tracks/track-1/lessons/missing");

        var response = await function.GetLesson(request, "track-1", "missing", context);

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
        service.LessonCallCount.Should().Be(1);
    }

    [Fact]
    public async Task GetLesson_Throws_WhenUnauthenticated()
    {
        var service = new FakeContentService();
        var function = new LessonFunctions(service);
        var context = new TestFunctionContext();
        var request = new TestHttpRequestData(context, "GET", "https://localhost/api/tracks/track-1/lessons/lesson-1");

        var act = () => function.GetLesson(request, "track-1", "lesson-1", context);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(act);
        service.LessonCallCount.Should().Be(0);
    }

    [Fact]
    public async Task GetLesson_ReturnsTheExactPublicManifestIdentity()
    {
        const string manifestId =
            "sha256:e5663734ac88ac916cff3b6e1206dc03bacf7f6d530e8b115e3f198a1e6304ee";
        var service = new FakeContentService { PublicManifestId = manifestId };
        var function = new LessonFunctions(service);
        var context = TestFunctionContext.Authenticated();
        var request = new TestHttpRequestData(
            context,
            "GET",
            "https://localhost/api/tracks/track-1/lessons/lesson-1");

        var response = await function.GetLesson(request, "track-1", "lesson-1", context);

        response.Headers.GetValues("X-Content-Manifest-Id").Should().Equal(manifestId);
        response.Headers.GetValues("ETag").Should().Equal($"\"{manifestId}\"");
    }
}
