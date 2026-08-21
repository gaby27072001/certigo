using System.Net;
using Certigo.Api.Middleware;
using Certigo.Application.Abstractions;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class PortableAchievementFeatureMiddlewareTests
{
    [Theory]
    [InlineData("POST", "/api/me/portable-achievements")]
    [InlineData("GET", "/api/me/portable-achievements/proof-1")]
    [InlineData("POST", "/api/portable-achievements/verify")]
    public async Task Disabled_routes_return_404_before_authentication_or_body_parsing(
        string method,
        string path)
    {
        var middleware = new PortableAchievementFeatureMiddleware(
            PortableAchievementOptions.Disabled);
        var invocation = FunctionTestHarness.CreateHttp(
            method,
            path,
            body: "{malformed-json");
        var nextCalled = false;

        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeFalse();
        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.NotFound);
        (await invocation.ReadBodyAsync()).Should().Be("Not Found");
    }

    [Fact]
    public async Task Enabled_route_continues_to_authentication_pipeline()
    {
        var middleware = new PortableAchievementFeatureMiddleware(
            new PortableAchievementOptions(true, "certigo"));
        var invocation = FunctionTestHarness.CreateHttp(
            "POST",
            "/api/me/portable-achievements",
            body: "{malformed-json");
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
    public async Task Similar_non_feature_path_is_not_hidden()
    {
        var middleware = new PortableAchievementFeatureMiddleware(
            PortableAchievementOptions.Disabled);
        var invocation = FunctionTestHarness.CreateHttp(
            "GET",
            "/api/me/portable-achievements-legacy");
        var nextCalled = false;

        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
    }
}
