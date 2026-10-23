using System.Security.Claims;
using Certigo.Api.Auth;
using Certigo.Application.Abstractions;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class TokenValidatorConfigurationTests
{
    private const string Authority = "https://example.ciamlogin.com/tenant/v2.0";
    private const string Audience = "api://12910b8e-6c75-4d51-91d8-4d5fb8a6e915";

    [Fact]
    public async Task ConfiguredEntraPreservesValidatedClaimsBeforeDevFallback()
    {
        var identity = new ClaimsIdentity([new Claim("oid", "validated-owner")], "Entra");
        var principal = new ClaimsPrincipal(identity);
        var local = new StubValidator(new TokenValidationResult(false, null, null));
        var entra = new StubValidator(new TokenValidationResult(true, principal, "validated-owner"));
        var chain = TokenValidatorConfiguration.Create(local, Authority, Audience, true, (_, _) => entra);

        var result = await chain.TryValidateAsync("signed-ciam-token");

        local.Calls.Should().Be(1);
        entra.Calls.Should().Be(1);
        result.UserId.Should().Be("validated-owner");
        result.Principal.Should().BeSameAs(principal);
        result.Principal!.Identity!.AuthenticationType.Should().Be("Entra");
    }

    [Fact]
    public async Task DevFallbackRunsOnlyAfterConfiguredEntraRejectsToken()
    {
        var rejected = new TokenValidationResult(false, null, null);
        var entra = new StubValidator(rejected);
        var chain = TokenValidatorConfiguration.Create(
            new StubValidator(rejected), Authority, Audience, true, (_, _) => entra);

        var result = await chain.TryValidateAsync("dev-smoke-owner");

        entra.Calls.Should().Be(1);
        result.UserId.Should().Be("dev-smoke-owner");
        result.Principal!.Identity!.AuthenticationType.Should().Be("dev");
    }

    [Fact]
    public async Task DevDisabledDoesNotAcceptRejectedToken()
    {
        var rejected = new TokenValidationResult(false, null, null);
        var chain = TokenValidatorConfiguration.Create(
            new StubValidator(rejected), Authority, Audience, false, (_, _) => new StubValidator(rejected));

        (await chain.TryValidateAsync("not-a-valid-jwt")).Succeeded.Should().BeFalse();
    }

    [Theory]
    [InlineData(null, Audience)]
    [InlineData(Authority, "")]
    [InlineData(" ", Audience)]
    [InlineData("https://example/00000000-0000-0000-0000-000000000000/v2.0", Audience)]
    [InlineData(Authority, "00000000-0000-0000-0000-000000000000")]
    [InlineData(Authority, "api://00000000-0000-0000-0000-000000000000")]
    public async Task MissingOrPlaceholderEntraConfigurationKeepsLocalDevUsable(string? authority, string? audience)
    {
        var chain = TokenValidatorConfiguration.Create(
            new StubValidator(new TokenValidationResult(false, null, null)),
            authority, audience, true,
            (_, _) => throw new InvalidOperationException("Entra must not be constructed."));

        var result = await chain.TryValidateAsync("dev-smoke-owner");

        result.UserId.Should().Be("dev-smoke-owner");
    }

    [Fact]
    public async Task LocalSuccessStillPrecedesConfiguredEntraAndDev()
    {
        var localPrincipal = new ClaimsPrincipal(new ClaimsIdentity("local"));
        var entra = new StubValidator(new TokenValidationResult(false, null, null));
        var chain = TokenValidatorConfiguration.Create(
            new StubValidator(new TokenValidationResult(true, localPrincipal, "local-owner")),
            Authority, Audience, true, (_, _) => entra);

        var result = await chain.TryValidateAsync("local-token");

        result.Principal.Should().BeSameAs(localPrincipal);
        entra.Calls.Should().Be(0);
    }

    private sealed class StubValidator(TokenValidationResult result) : ITokenValidator
    {
        public int Calls { get; private set; }

        public Task<TokenValidationResult> TryValidateAsync(
            string token, CancellationToken cancellationToken = default)
        {
            Calls++;
            return Task.FromResult(result);
        }
    }
}
