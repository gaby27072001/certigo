using System.Net;
using FluentAssertions;
using Certigo.Api.Middleware;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class CorrelationMiddlewareTests
{
    private static CorrelationMiddleware CreateMiddleware()
        => new(NullLogger<CorrelationMiddleware>.Instance);

    [Fact]
    public async Task InboundCorrelationId_IsHonouredAndStoredInContextItems()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp(
            headers: new Dictionary<string, string> { ["x-correlation-id"] = "inbound-id-abc" });

        await middleware.Invoke(invocation.Context, _ => Task.CompletedTask);

        invocation.Context.Items["CorrelationId"].Should().Be("inbound-id-abc");
    }

    [Fact]
    public async Task MissingCorrelationIdHeader_GeneratesNewGuid()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp();

        await middleware.Invoke(invocation.Context, _ => Task.CompletedTask);

        invocation.Context.Items["CorrelationId"].Should().BeOfType<string>()
            .Which.Should().MatchRegex("^[0-9a-f]{32}$");
    }

    [Fact]
    public async Task CorrelationId_IsEchoedOnSuccessResponse()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp(
            headers: new Dictionary<string, string> { ["x-correlation-id"] = "echo-test-42" });

        // The inner handler writes a response (simulates a function returning 200).
        await middleware.Invoke(invocation.Context, ctx =>
        {
            var response = invocation.Request!.CreateResponse();
            ctx.GetInvocationResult().Value = response;
            return Task.CompletedTask;
        });

        invocation.CorrelationId.Should().Be("echo-test-42");
    }

    [Fact]
    public async Task CorrelationId_NotDuplicated_WhenAlreadySetOnErrorResponse()
    {
        // Simulates ExceptionMiddleware already adding the header on an error response;
        // CorrelationMiddleware must not add a second copy.
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateHttp(
            headers: new Dictionary<string, string> { ["x-correlation-id"] = "trace-xyz" });

        await middleware.Invoke(invocation.Context, ctx =>
        {
            var response = invocation.Request!.CreateResponse();
            response.StatusCode = HttpStatusCode.BadRequest;
            response.Headers.Add("x-correlation-id", "trace-xyz"); // already stamped
            ctx.GetInvocationResult().Value = response;
            return Task.CompletedTask;
        });

        // Should appear exactly once.
        invocation.Response!.Headers.TryGetValues("x-correlation-id", out var values).Should().BeTrue();
        values!.Should().ContainSingle().Which.Should().Be("trace-xyz");
    }

    [Fact]
    public async Task NonHttpTrigger_NextIsCalledWithoutError()
    {
        var middleware = CreateMiddleware();
        var invocation = FunctionTestHarness.CreateNonHttp();

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
    }

    [Fact]
    public async Task CorrelationMiddlewareThenExceptionMiddleware_ExceptionMiddlewareReadsPreResolvedId()
    {
        // Verifies that when both middlewares run in order, ExceptionMiddleware reuses
        // the correlation id already placed in context.Items by CorrelationMiddleware.
        var correlation = CreateMiddleware();
        var exception = new ExceptionMiddleware(NullLogger<ExceptionMiddleware>.Instance);

        var invocation = FunctionTestHarness.CreateHttp(
            headers: new Dictionary<string, string> { ["x-correlation-id"] = "composed-trace" });

        await correlation.Invoke(
            invocation.Context,
            ctx => exception.Invoke(ctx, _ => throw new Certigo.Api.Http.BadRequestException("bad")));

        invocation.CorrelationId.Should().Be("composed-trace");
        invocation.Context.Items["CorrelationId"].Should().Be("composed-trace");
    }
}
