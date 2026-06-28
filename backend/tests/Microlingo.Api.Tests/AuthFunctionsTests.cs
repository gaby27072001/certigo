using System.Net;
using FluentAssertions;
using Microlingo.Api.Functions;
using Microlingo.Api.Http;
using Xunit;

namespace Microlingo.Api.Tests;

/// <summary>
/// Exercises the request→handler boundary of <see cref="AuthFunctions"/>: each anonymous endpoint
/// reads its JSON body from the isolated-worker <c>HttpRequestData</c>, enforces the input rules at
/// the HTTP edge (returning <see cref="BadRequestException"/> before the service is touched), and
/// forwards valid requests to <see cref="IAuthService"/> with the documented status code.
/// </summary>
public sealed class AuthFunctionsTests
{
    [Fact]
    public async Task Register_WithValidInput_ForwardsToService_AndReturns201()
    {
        var auth = new FakeAuthService();
        var function = new AuthFunctions(auth);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/auth/register",
            body: """{"email":"user@example.com","password":"password123","displayName":"User"}""");

        var response = await function.Register(invocation.Request!, invocation.Context);

        auth.RegisterCallCount.Should().Be(1);
        auth.LastRegister.Should().NotBeNull();
        auth.LastRegister!.Email.Should().Be("user@example.com");
        auth.LastRegister.Password.Should().Be("password123");
        auth.LastRegister.DisplayName.Should().Be("User");
        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }

    [Theory]
    [InlineData("not-an-email")]
    [InlineData("missing-domain@")]
    [InlineData("a@b")]
    public async Task Register_WithInvalidEmail_ThrowsBadRequest_AndNeverCallsService(string email)
    {
        var auth = new FakeAuthService();
        var function = new AuthFunctions(auth);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/auth/register",
            body: $$"""{"email":"{{email}}","password":"password123"}""");

        var act = () => function.Register(invocation.Request!, invocation.Context);

        await act.Should().ThrowAsync<BadRequestException>();
        auth.RegisterCallCount.Should().Be(0);
    }

    [Theory]
    [InlineData("short")]
    [InlineData("1234567")]
    [InlineData("")]
    public async Task Register_WithTooShortPassword_ThrowsBadRequest_AndNeverCallsService(string password)
    {
        var auth = new FakeAuthService();
        var function = new AuthFunctions(auth);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/auth/register",
            body: $$"""{"email":"user@example.com","password":"{{password}}"}""");

        var act = () => function.Register(invocation.Request!, invocation.Context);

        await act.Should().ThrowAsync<BadRequestException>();
        auth.RegisterCallCount.Should().Be(0);
    }

    [Fact]
    public async Task Login_WithValidInput_ForwardsToService_AndReturns200()
    {
        var auth = new FakeAuthService();
        var function = new AuthFunctions(auth);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/auth/login",
            body: """{"email":"user@example.com","password":"password123"}""");

        var response = await function.Login(invocation.Request!, invocation.Context);

        auth.LoginCallCount.Should().Be(1);
        auth.LastLogin.Should().NotBeNull();
        auth.LastLogin!.Email.Should().Be("user@example.com");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Theory]
    [InlineData("", "password123")]
    [InlineData("   ", "password123")]
    [InlineData("user@example.com", "")]
    public async Task Login_WithMissingCredential_ThrowsBadRequest_AndNeverCallsService(string email, string password)
    {
        var auth = new FakeAuthService();
        var function = new AuthFunctions(auth);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/auth/login",
            body: $$"""{"email":"{{email}}","password":"{{password}}"}""");

        var act = () => function.Login(invocation.Request!, invocation.Context);

        await act.Should().ThrowAsync<BadRequestException>();
        auth.LoginCallCount.Should().Be(0);
    }

    [Fact]
    public async Task RefreshToken_WithValidToken_ForwardsToService_AndReturns200()
    {
        var auth = new FakeAuthService();
        var function = new AuthFunctions(auth);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/auth/refresh",
            body: """{"refreshToken":"rt-123"}""");

        var response = await function.RefreshToken(invocation.Request!, invocation.Context);

        auth.RefreshCallCount.Should().Be(1);
        auth.LastRefresh.Should().NotBeNull();
        auth.LastRefresh!.RefreshToken.Should().Be("rt-123");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task RefreshToken_WithMissingToken_ThrowsBadRequest_AndNeverCallsService(string token)
    {
        var auth = new FakeAuthService();
        var function = new AuthFunctions(auth);
        var invocation = FunctionTestHarness.CreateHttp(
            path: "/api/auth/refresh",
            body: $$"""{"refreshToken":"{{token}}"}""");

        var act = () => function.RefreshToken(invocation.Request!, invocation.Context);

        await act.Should().ThrowAsync<BadRequestException>();
        auth.RefreshCallCount.Should().Be(0);
    }
}
