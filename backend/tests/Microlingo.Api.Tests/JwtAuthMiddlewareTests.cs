using System.Net;
using System.Security.Claims;
using FluentAssertions;
using Microlingo.Api.Auth;
using Microlingo.Api.Middleware;
using Microsoft.Azure.Functions.Worker;
using Xunit;

namespace Microlingo.Api.Tests;

public sealed class JwtAuthMiddlewareTests
{
    private const string ProtectedPath = "/api/quiz/lesson-1/submit";

    [Theory]
    [InlineData("/api/health")]
    [InlineData("/api/auth/register")]
    [InlineData("/api/auth/login")]
    [InlineData("/api/auth/refresh")]
    public async Task AnonymousPath_CallsNext_WithoutAuthenticating(string path)
    {
        var validator = FakeTokenValidator.Failing();
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: path);

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
        validator.CallCount.Should().Be(0);
        invocation.Response.Should().BeNull();
        invocation.Context.Items.Should().NotContainKey("User");
    }

    [Fact]
    public async Task AnonymousPath_WithTrailingSlash_IsStillAnonymous()
    {
        var validator = FakeTokenValidator.Failing();
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: "/api/auth/login/");

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
        validator.CallCount.Should().Be(0);
        invocation.Response.Should().BeNull();
    }

    [Fact]
    public async Task NonHttpTrigger_CallsNext_WithoutAuthenticating()
    {
        var validator = FakeTokenValidator.Failing();
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateNonHttp();

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeTrue();
        validator.CallCount.Should().Be(0);
        invocation.Response.Should().BeNull();
    }

    [Fact]
    public async Task MissingAuthorizationHeader_Returns401_AndDoesNotCallNext()
    {
        var validator = FakeTokenValidator.Failing();
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(method: "POST", path: ProtectedPath);

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeFalse();
        validator.CallCount.Should().Be(0);
        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
        (await invocation.ReadBodyAsync()).Should().Be("Unauthorized");
    }

    [Theory]
    [InlineData("Basic dXNlcjpwYXNz")]
    [InlineData("token-without-scheme")]
    [InlineData("Bearer")]
    public async Task NonBearerAuthorizationHeader_Returns401(string headerValue)
    {
        var validator = FakeTokenValidator.Failing();
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            headers: new Dictionary<string, string> { ["Authorization"] = headerValue });

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeFalse();
        validator.CallCount.Should().Be(0);
        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task RejectedToken_Returns401_AndDoesNotCallNext()
    {
        var validator = FakeTokenValidator.Failing();
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer rejected-token" });

        var nextCalled = false;
        await middleware.Invoke(invocation.Context, _ =>
        {
            nextCalled = true;
            return Task.CompletedTask;
        });

        nextCalled.Should().BeFalse();
        validator.CallCount.Should().Be(1);
        validator.LastToken.Should().Be("rejected-token");
        invocation.Response.Should().NotBeNull();
        invocation.Response!.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task ValidToken_TrimsBearerPrefix_BeforeValidating()
    {
        var principal = TestPrincipal.With(oid: "jwt-user-1");
        var validator = FakeTokenValidator.Succeeding(principal);
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer   spaced-token  " });

        await middleware.Invoke(invocation.Context, _ => Task.CompletedTask);

        validator.CallCount.Should().Be(1);
        validator.LastToken.Should().Be("spaced-token");
    }

    [Fact]
    public async Task ValidToken_PopulatesUserContext_ForDownstreamHandler()
    {
        var principal = TestPrincipal.With(oid: "jwt-user-42", name: "JWT User");
        var validator = FakeTokenValidator.Succeeding(principal);
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer good-token" });

        ClaimsPrincipal? itemsUserDuringNext = null;
        string? userIdDuringNext = null;
        string? displayNameDuringNext = null;
        await middleware.Invoke(invocation.Context, ctx =>
        {
            itemsUserDuringNext = ctx.Items.TryGetValue("User", out var u) ? u as ClaimsPrincipal : null;
            var userContext = new FunctionUserContext();
            userIdDuringNext = userContext.UserId;
            displayNameDuringNext = userContext.DisplayName;
            return Task.CompletedTask;
        });

        itemsUserDuringNext.Should().BeSameAs(principal);
        userIdDuringNext.Should().Be("jwt-user-42");
        displayNameDuringNext.Should().Be("JWT User");

        // Items["User"] persists on the context after the pipeline completes.
        invocation.Context.Items["User"].Should().BeSameAs(principal);
        invocation.Response.Should().BeNull();
    }

    [Fact]
    public async Task UserId_AlwaysComesFromJwt_NeverFromRequestBody()
    {
        // Anti-spoofing guarantee: even when the request body carries a forged userId,
        // the authenticated identity is derived purely from the validated JWT principal.
        const string spoofedBody = """{"userId":"attacker-999","clientAttemptId":"a","trackId":"t"}""";
        var principal = TestPrincipal.With(oid: "legit-jwt-7");
        var validator = FakeTokenValidator.Succeeding(principal, userId: "legit-jwt-7");
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            body: spoofedBody,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer good-token" });

        string? resolvedUserId = null;
        await middleware.Invoke(invocation.Context, _ =>
        {
            resolvedUserId = new FunctionUserContext().UserId;
            return Task.CompletedTask;
        });

        resolvedUserId.Should().Be("legit-jwt-7");
        resolvedUserId.Should().NotBe("attacker-999");
    }

    [Fact]
    public async Task UserId_FallsBackThroughClaimPriority_OidThenNameIdentifierThenSub()
    {
        // No oid claim: FunctionUserContext should fall back to NameIdentifier, then sub.
        var principal = TestPrincipal.With(sub: "sub-only-user");
        var validator = FakeTokenValidator.Succeeding(principal);
        var middleware = new JwtAuthMiddleware(validator);
        var invocation = FunctionTestHarness.CreateHttp(
            method: "POST",
            path: ProtectedPath,
            headers: new Dictionary<string, string> { ["Authorization"] = "Bearer good-token" });

        string? resolvedUserId = null;
        await middleware.Invoke(invocation.Context, _ =>
        {
            resolvedUserId = new FunctionUserContext().UserId;
            return Task.CompletedTask;
        });

        resolvedUserId.Should().Be("sub-only-user");
    }
}
