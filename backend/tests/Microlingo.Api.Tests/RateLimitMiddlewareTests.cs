using System.Net;
using System.Security.Claims;
using FluentAssertions;
using Certigo.Api.Middleware;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class RateLimitMiddlewareTests
{
    private const string ProtectedPath = "/api/quiz/lesson-1/submit";

    private static RateLimitMiddleware CreateEnabled(int limitRpm = 60)
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["RATE_LIMIT_ENABLED"] = "true",
                ["RATE_LIMIT_RPM"] = limitRpm.ToString()
            })
            .Build();
        return new RateLimitMiddleware(config, NullLogger<RateLimitMiddleware>.Instance);
    }

    private static RateLimitMiddleware CreateDisabled()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["RATE_LIMIT_ENABLED"] = "false"
            })
            .Build();
        return new RateLimitMiddleware(config, NullLogger<RateLimitMiddleware>.Instance);
    }

    private static FunctionTestHarnessWrapper CreateAuthenticatedInvocation(
        string userId = "user-1",
        string path = ProtectedPath)
    {
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: path);
        var principal = TestPrincipal.With(oid: userId);
        invocation.Context.Items["User"] = principal;
        return new FunctionTestHarnessWrapper(invocation, principal);
    }

    [Fact]
    public async Task WhenDisabled_RequestPassesThrough()
    {
        var middleware = CreateDisabled();
        var wrapper = CreateAuthenticatedInvocation();

        var nextCalled = false;
        await middleware.Invoke(wrapper.Invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
        wrapper.Invocation.Response.Should().BeNull();
    }

    [Fact]
    public async Task UnauthenticatedRequest_PassesThroughWithoutRateLimiting()
    {
        var middleware = CreateEnabled(limitRpm: 1);
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);
        // No User in context.Items

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
        invocation.Response.Should().BeNull();
    }

    [Fact]
    public async Task HealthPath_IsExemptFromRateLimiting()
    {
        var middleware = CreateEnabled(limitRpm: 1);
        var wrapper = CreateAuthenticatedInvocation(path: "/api/health");

        // First request — would normally consume the single-request limit.
        var nextCalled = false;
        await middleware.Invoke(wrapper.Invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
        wrapper.Invocation.Response.Should().BeNull();
    }

    [Fact]
    public async Task RequestsWithinLimit_PassThrough()
    {
        var middleware = CreateEnabled(limitRpm: 5);
        var wrapper = CreateAuthenticatedInvocation();

        for (var i = 0; i < 5; i++)
        {
            var nextCalled = false;
            await middleware.Invoke(wrapper.Invocation.Context, _ =>
            {
                nextCalled = true;
                return Task.CompletedTask;
            });
            nextCalled.Should().BeTrue($"request {i + 1} of 5 should be within the limit");
        }
    }

    [Fact]
    public async Task ExceedingLimit_Returns429WithRetryAfterHeader()
    {
        var middleware = CreateEnabled(limitRpm: 2);
        var invocation1 = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);
        invocation1.Context.Items["User"] = TestPrincipal.With(oid: "rate-limit-user");
        var invocation2 = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);
        invocation2.Context.Items["User"] = TestPrincipal.With(oid: "rate-limit-user");
        var invocation3 = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);
        invocation3.Context.Items["User"] = TestPrincipal.With(oid: "rate-limit-user");

        await middleware.Invoke(invocation1.Context, _ => Task.CompletedTask);
        await middleware.Invoke(invocation2.Context, _ => Task.CompletedTask);
        await middleware.Invoke(invocation3.Context, _ => Task.CompletedTask);

        // Only the third request (over the limit of 2) should be rejected.
        invocation1.Response.Should().BeNull("first request is within limit");
        invocation2.Response.Should().BeNull("second request is within limit");
        invocation3.Response.Should().NotBeNull("third request exceeds the limit of 2");
        invocation3.Response!.StatusCode.Should().Be(HttpStatusCode.TooManyRequests);
        invocation3.Response.Headers.TryGetValues("Retry-After", out var retryAfter).Should().BeTrue();
        retryAfter!.First().Should().Be("60");
    }

    [Fact]
    public async Task DifferentUsers_HaveIndependentLimits()
    {
        var middleware = CreateEnabled(limitRpm: 1);

        var invocationA = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);
        invocationA.Context.Items["User"] = TestPrincipal.With(oid: "user-A");
        var invocationB = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);
        invocationB.Context.Items["User"] = TestPrincipal.With(oid: "user-B");

        var nextCalledA = false;
        await middleware.Invoke(invocationA.Context, _ =>
        {
            nextCalledA = true;
            return Task.CompletedTask;
        });

        var nextCalledB = false;
        await middleware.Invoke(invocationB.Context, _ =>
        {
            nextCalledB = true;
            return Task.CompletedTask;
        });

        nextCalledA.Should().BeTrue("user A's first request is within their limit");
        nextCalledB.Should().BeTrue("user B's first request is within their separate limit");
    }

    /// <summary>Wraps a <see cref="HarnessInvocation"/> with its associated principal for convenience.</summary>
    private sealed record FunctionTestHarnessWrapper(HarnessInvocation Invocation, ClaimsPrincipal Principal);
}
