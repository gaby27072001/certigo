using System.Net;
using FluentAssertions;
using Certigo.Api.Http;
using Certigo.Api.Middleware;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// Verifies <see cref="SecurityHeadersMiddleware"/> stamps the defensive headers on
/// every HTTP response, never overwrites a header a handler already set, and is a
/// no-op for non-HTTP triggers. Also checks it cooperates with the real pipeline so
/// error and 401 responses are covered too.
/// </summary>
public sealed class SecurityHeadersMiddlewareTests
{
    private static readonly (string Name, string ExpectedValue)[] Expected =
    {
        ("X-Content-Type-Options", "nosniff"),
        ("Strict-Transport-Security", "max-age=63072000; includeSubDomains"),
        ("X-Frame-Options", "DENY"),
        ("Referrer-Policy", "no-referrer"),
    };

    private static void AssertAllHeadersPresent(HttpResponseData response)
    {
        foreach (var (name, expectedValue) in Expected)
        {
            response.Headers.TryGetValues(name, out var values).Should().BeTrue($"'{name}' should be stamped");
            values!.Single().Should().Be(expectedValue);
        }
    }

    [Fact]
    public async Task StampsAllSecurityHeaders_OnASuccessfulHttpResponse()
    {
        var middleware = new SecurityHeadersMiddleware();
        var invocation = FunctionTestHarness.CreateHttp(method: "GET", path: "/api/health");

        await middleware.Invoke(invocation.Context, ctx =>
        {
            var response = invocation.Request!.CreateResponse(HttpStatusCode.OK);
            ctx.GetInvocationResult().Value = response;
            return Task.CompletedTask;
        });

        invocation.Response.Should().NotBeNull();
        AssertAllHeadersPresent(invocation.Response!);
    }

    [Fact]
    public async Task DoesNotOverwrite_AHeaderTheHandlerAlreadySet()
    {
        var middleware = new SecurityHeadersMiddleware();
        var invocation = FunctionTestHarness.CreateHttp(method: "GET", path: "/api/health");

        await middleware.Invoke(invocation.Context, ctx =>
        {
            var response = invocation.Request!.CreateResponse(HttpStatusCode.OK);
            response.Headers.Add("X-Frame-Options", "SAMEORIGIN");
            ctx.GetInvocationResult().Value = response;
            return Task.CompletedTask;
        });

        // The handler's value wins and is not duplicated.
        invocation.Response!.Headers.TryGetValues("X-Frame-Options", out var frame).Should().BeTrue();
        frame!.Single().Should().Be("SAMEORIGIN");
        // The remaining headers are still stamped.
        invocation.Response!.Headers.TryGetValues("X-Content-Type-Options", out var nosniff).Should().BeTrue();
        nosniff!.Single().Should().Be("nosniff");
    }

    [Fact]
    public async Task NonHttpTrigger_IsANoOp_AndCallsNext()
    {
        var middleware = new SecurityHeadersMiddleware();
        var invocation = FunctionTestHarness.CreateNonHttp();

        var nextCalled = false;
        var act = () => middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        await act.Should().NotThrowAsync();
        nextCalled.Should().BeTrue();
        invocation.Response.Should().BeNull();
    }

    [Fact]
    public async Task Outermost_StampsHeaders_OnDownstreamProblemDetailsErrorResponse()
    {
        // SecurityHeaders (outer) -> Exception -> handler that throws. The error
        // ProblemDetails written by ExceptionMiddleware must still carry the headers
        // and keep its correlation id.
        var security = new SecurityHeadersMiddleware();
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: "/api/quiz/lesson-1/submit");

        await security.Invoke(invocation.Context, ctx =>
            exception.Invoke(ctx, _ => throw new BadRequestException("bad input")));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        AssertAllHeadersPresent(invocation.Response!);
        invocation.CorrelationId.Should().NotBeNullOrWhiteSpace();
    }

    [Fact]
    public async Task Outermost_StampsHeaders_OnJwtAuth401ShortCircuit()
    {
        // A missing token makes JwtAuth short-circuit with a 401; the outermost
        // SecurityHeaders middleware must still stamp the headers on it.
        var security = new SecurityHeadersMiddleware();
        var jwt = new JwtAuthMiddleware(FakeTokenValidator.Failing());
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: "/api/quiz/lesson-1/submit");

        await security.Invoke(invocation.Context, ctx => jwt.Invoke(ctx, _ => Task.CompletedTask));

        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        AssertAllHeadersPresent(invocation.Response!);
    }
}
