using System.Net;
using FluentAssertions;
using Certigo.Api.Functions;
using Certigo.Api.Http;
using Certigo.Api.Middleware;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// End-to-end boundary tests proving that a malformed JSON body on any protected endpoint
/// surfaces as HTTP 400 ProblemDetails — not a generic 500 Internal Server Error.
///
/// Risk R4 from audit D4: the deserialization layer in <see cref="HttpExtensions.ReadJsonAsync"/>
/// must catch <see cref="System.Text.Json.JsonException"/> and re-throw it as
/// <see cref="BadRequestException"/> so that <see cref="ExceptionMiddleware"/> maps it to 400.
/// If that conversion is ever removed the unhandled exception falls through to the generic 500
/// handler instead, leaking an error message about the request body to the caller.
/// </summary>
public sealed class JsonBodyValidationTests
{
    private static ExceptionMiddleware Middleware() =>
        new(NullLogger<ExceptionMiddleware>.Instance);

    /// <summary>
    /// Sends syntactically invalid JSON to the quiz submit endpoint through the full
    /// ExceptionMiddleware pipeline and asserts the response is 400 ProblemDetails with
    /// a safe, sanitised detail string — not 500 and not a raw exception dump.
    /// </summary>
    [Theory]
    [InlineData("{this is not valid json}")]
    [InlineData("{\"answers\": [}")]
    [InlineData("not-json-at-all")]
    public async Task MalformedJsonBody_ThroughExceptionMiddleware_Returns400_NotInternalServerError(string badBody)
    {
        var quizzes = new FakeQuizService();
        var function = new QuizFunctions(quizzes);
        var middleware = Middleware();
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: "/api/quiz/lesson-1/submit",
            body: badBody);

        // Authenticate the context so the request reaches the JSON parsing layer
        // (auth is purposely bypassed here; we are testing the deserialization boundary).
        invocation.Context.Items["User"] = TestPrincipal.With(oid: "user-1");

        await middleware.Invoke(invocation.Context, async _ =>
        {
            var response = await function.SubmitQuiz(invocation.Request!, "lesson-1", invocation.Context);
            invocation.Bindings.InvocationResult = response;
        });

        invocation.Response.Should().NotBeNull("ExceptionMiddleware must write an error response");
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.BadRequest,
            "a malformed JSON body is a client error — HTTP 400, not HTTP 500");

        var problem = await invocation.ReadProblemAsync();
        problem.Should().NotBeNull();
        problem!.Status.Should().Be(400);
        problem.Title.Should().Be("Invalid request");
        problem.Detail.Should().Contain("Invalid JSON",
            "the user deserves to know the body could not be parsed, but not the internals");

        // Safety assertions: no internal detail must leak back to the caller.
        problem.Detail.Should().NotContain("JsonException");
        problem.Detail.Should().NotContain("System.Text.Json");
        problem.Detail.Should().NotContain("stack");
        quizzes.CallCount.Should().Be(0, "the service must never be reached with an invalid body");
    }

    /// <summary>
    /// Verifies that a structurally valid JSON payload that cannot be deserialised into the
    /// expected DTO (wrong type for a required field) is also rejected as 400 rather than 500.
    /// </summary>
    [Fact]
    public async Task TypeMismatchInJsonBody_ThroughExceptionMiddleware_Returns400()
    {
        // "answers" is expected to be an array; supplying a string triggers a JsonException.
        const string wrongTypesBody =
            """{"clientAttemptId":"a","trackId":"t","startedAt":"2024-01-01T00:00:00Z","answers":"not-an-array"}""";

        var quizzes = new FakeQuizService();
        var function = new QuizFunctions(quizzes);
        var middleware = Middleware();
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: "/api/quiz/lesson-1/submit",
            body: wrongTypesBody);
        invocation.Context.Items["User"] = TestPrincipal.With(oid: "user-1");

        await middleware.Invoke(invocation.Context, async _ =>
        {
            var response = await function.SubmitQuiz(invocation.Request!, "lesson-1", invocation.Context);
            invocation.Bindings.InvocationResult = response;
        });

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var problem = await invocation.ReadProblemAsync();
        problem!.Status.Should().Be(400);
        problem.Detail.Should().Contain("Invalid JSON");
    }
}
