using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// Exercises the request→handler boundary of <see cref="QuizFunctions.SubmitQuiz"/>: the route
/// parameter (<c>lessonId</c>) and the JSON body are extracted from the isolated-worker
/// <c>HttpRequestData</c>/<c>FunctionContext</c> and forwarded verbatim to the service, the
/// authenticated user is required up front, and the result is serialised back as 200 OK.
/// </summary>
public sealed class QuizFunctionsTests
{
    private const string ValidBody =
        """{"clientAttemptId":"a1","trackId":"track-1","startedAt":"2024-01-01T00:00:00Z","answers":[]}""";

    [Fact]
    public async Task SubmitQuiz_ForwardsRouteParameterAndBody_ToService()
    {
        var quizzes = new FakeQuizService();
        var function = new QuizFunctions(quizzes);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: "/api/quiz/lesson-42/submit",
            body: ValidBody);
        invocation.Context.Items["User"] = TestPrincipal.With(oid: "user-1");

        var response = await function.SubmitQuiz(invocation.Request!, "lesson-42", invocation.Context);

        quizzes.CallCount.Should().Be(1);
        quizzes.LastLessonId.Should().Be("lesson-42");
        quizzes.LastRequest.Should().NotBeNull();
        quizzes.LastRequest!.ClientAttemptId.Should().Be("a1");
        quizzes.LastRequest.TrackId.Should().Be("track-1");
        quizzes.LastRequest.StartedAt.Should().Be(new DateTimeOffset(2024, 1, 1, 0, 0, 0, TimeSpan.Zero));
        quizzes.LastRequest.Answers.Should().BeEmpty();
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task SubmitQuiz_SerialisesServiceResult_AsJsonResponse()
    {
        var quizzes = new FakeQuizService();
        var function = new QuizFunctions(quizzes);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/quiz/lesson-1/submit",
            body: ValidBody);
        invocation.Context.Items["User"] = TestPrincipal.With(oid: "user-1");

        var response = await function.SubmitQuiz(invocation.Request!, "lesson-1", invocation.Context);

        var json = await invocation.ReadBodyAsync(response);
        json.Should().Contain("attempt-1");
        response.Headers.TryGetValues("Content-Type", out var contentType).Should().BeTrue();
        contentType.Should().ContainMatch("application/json*");
    }

    [Fact]
    public async Task SubmitQuiz_WithoutAuthenticatedUser_Throws_AndNeverCallsService()
    {
        var quizzes = new FakeQuizService();
        var function = new QuizFunctions(quizzes);
        var invocation = FunctionTestHarness.CreateHttp(body: ValidBody);

        // No principal placed in context.Items["User"] -> the GetUser() gate runs first.
        var act = () => function.SubmitQuiz(invocation.Request!, "lesson-1", invocation.Context);

        await act.Should().ThrowAsync<UnauthorizedAccessException>();
        quizzes.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task SubmitQuiz_WithEmptyBody_ThrowsBadRequest_AfterAuthGate()
    {
        var quizzes = new FakeQuizService();
        var function = new QuizFunctions(quizzes);
        var invocation = FunctionTestHarness.CreateHttp(body: null);
        invocation.Context.Items["User"] = TestPrincipal.With(oid: "user-1");

        var act = () => function.SubmitQuiz(invocation.Request!, "lesson-1", invocation.Context);

        await act.Should().ThrowAsync<BadRequestException>();
        quizzes.CallCount.Should().Be(0);
    }

    [Theory]
    [InlineData("{this is not valid json}")]
    [InlineData("{\"clientAttemptId\": }")]
    [InlineData("not json at all")]
    public async Task SubmitQuiz_WithMalformedJsonBody_ThrowsBadRequest_NotJsonException(string badBody)
    {
        // Regression guard: HttpExtensions.ReadJsonAsync must convert JsonException → BadRequestException
        // so that ExceptionMiddleware answers 400 rather than letting an unhandled JsonException
        // surface as a generic 500 Internal Server Error.
        var quizzes = new FakeQuizService();
        var function = new QuizFunctions(quizzes);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: "/api/quiz/lesson-1/submit",
            body: badBody);
        invocation.Context.Items["User"] = TestPrincipal.With(oid: "user-1");

        var act = () => function.SubmitQuiz(invocation.Request!, "lesson-1", invocation.Context);

        var ex = await act.Should().ThrowAsync<BadRequestException>();
        ex.Which.Message.Should().Contain("Invalid JSON");
        quizzes.CallCount.Should().Be(0);
    }
}
