using System.Net;
using FluentAssertions;
using Certigo.Api.Http;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

/// <summary>
/// Verifies the middleware registration order declared in <c>Program.cs</c>
/// (ExceptionMiddleware first, then JwtAuthMiddleware) actually nests the way the
/// production pipeline does: ExceptionMiddleware must wrap JwtAuthMiddleware so that
/// any exception surfacing from the authenticated handler is mapped to ProblemDetails,
/// while JwtAuthMiddleware's own 401 short-circuit flows back out untouched.
/// </summary>
public sealed class MiddlewareOrderingTests
{
    private const string ProtectedPath = "/api/quiz/lesson-1/submit";

    private static (ExceptionMiddleware Exception, JwtAuthMiddleware Jwt) BuildPipeline(FakeTokenValidator validator)
    {
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);
        var jwt = new JwtAuthMiddleware(validator);
        return (exception, jwt);
    }

    [Fact]
    public async Task ExceptionMiddleware_WrapsJwtAuth_AndMapsDownstreamBadRequestTo400()
    {
        // A valid token lets JwtAuthMiddleware pass control to its inner handler, which then
        // throws. Because ExceptionMiddleware was registered first, it sits outside JwtAuth and
        // must catch that exception and emit a 400 ProblemDetails.
        var principal = TestPrincipal.With(oid: "jwt-user-1");
        var validator = FakeTokenValidator.Succeeding(principal);
        var (exception, jwt) = BuildPipeline(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer good-token" });

        var handlerReached = false;
        await exception.Invoke(invocation.Context, ctx => jwt.Invoke(ctx, _ =>
        {
            handlerReached = true;
            throw new BadRequestException("downstream failure");
        }));

        handlerReached.Should().BeTrue();
        validator.CallCount.Should().Be(1);
        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.BadRequest);

        var problem = await invocation.ReadProblemAsync();
        problem.Should().NotBeNull();
        problem!.Status.Should().Be(400);
        problem.Title.Should().Be("Invalid request");
        problem.Detail.Should().Be("downstream failure");
    }

    [Fact]
    public async Task OrderedPipeline_AuthenticatesThenMapsRateLimitedTo429()
    {
        // Demonstrates both middlewares cooperating through the composed pipeline: JwtAuth
        // authenticates the caller (so the handler is reached), and a RateLimitedException
        // raised by that handler is still mapped to 429 by the outer ExceptionMiddleware.
        var principal = TestPrincipal.With(oid: "jwt-user-2");
        var validator = FakeTokenValidator.Succeeding(principal);
        var (exception, jwt) = BuildPipeline(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer good-token" });

        await exception.Invoke(invocation.Context, ctx => jwt.Invoke(ctx, _ =>
            throw new RateLimitedException("slow down")));

        validator.CallCount.Should().Be(1);
        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.TooManyRequests);

        var problem = await invocation.ReadProblemAsync();
        problem.Should().NotBeNull();
        problem!.Status.Should().Be(429);
        problem.Title.Should().Be("Too Many Requests");
    }

    [Fact]
    public async Task JwtAuthShortCircuit401_FlowsThroughExceptionMiddleware_WithoutReachingHandler()
    {
        // When JwtAuth rejects the request (missing token) it writes a 401 and never calls its
        // inner delegate. ExceptionMiddleware observes no exception, so it leaves that 401
        // response untouched and the protected handler is never reached.
        var validator = FakeTokenValidator.Failing();
        var (exception, jwt) = BuildPipeline(validator);
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);

        var handlerReached = false;
        await exception.Invoke(invocation.Context, ctx => jwt.Invoke(ctx, _ =>
        {
            handlerReached = true;
            return Task.CompletedTask;
        }));

        handlerReached.Should().BeFalse();
        validator.CallCount.Should().Be(0);
        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        (await invocation.ReadBodyAsync()).Should().Be("Unauthorized");
    }
}
