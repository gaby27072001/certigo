using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using Certigo.Infrastructure.Identity;
using FluentAssertions;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Microsoft.IdentityModel.Tokens;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class EntraTokenValidatorTests : IDisposable
{
    private const string TenantId = "af721be8-5901-422a-b299-b9c57847b968";
    private const string AppId = "12910b8e-6c75-4d51-91d8-4d5fb8a6e915";
    private const string OtherAppId = "4d1f1075-7bc5-4764-947b-701435a85f8c";
    private const string ConfiguredAudience = $"api://{AppId}";
    private const string Authority = $"https://{TenantId}.ciamlogin.com/{TenantId}/v2.0";

    private readonly RSA _rsa = RSA.Create(2048);
    private readonly RsaSecurityKey _signingKey;
    private readonly EntraTokenValidator _validator;

    public EntraTokenValidatorTests()
    {
        _signingKey = new RsaSecurityKey(_rsa) { KeyId = "ciam-test-key" };
        var configuration = new OpenIdConnectConfiguration { Issuer = Authority };
        configuration.SigningKeys.Add(_signingKey);
        _validator = new EntraTokenValidator(
            Authority,
            ConfiguredAudience,
            new StaticConfigurationManager<OpenIdConnectConfiguration>(configuration));
    }

    public void Dispose() => _rsa.Dispose();

    // A v2 access token always carries the API client id as aud, even when the scope
    // was requested through api://<client id>: before accepting both spellings, the
    // backend rejected every such token with 401 (measured on staging 2026-09-23).
    [Fact]
    public async Task V2_access_token_whose_audience_is_the_client_id_is_accepted()
    {
        var result = await _validator.TryValidateAsync(Token(audience: AppId));

        result.Succeeded.Should().BeTrue();
        // Inbound claim mapping renames oid, so the identity resolves from sub
        // (NameIdentifier): this pins the user-id derivation used in production.
        result.UserId.Should().Be("operator-sub");
    }

    [Fact]
    public async Task V1_access_token_whose_audience_is_the_application_id_uri_is_still_accepted()
    {
        var result = await _validator.TryValidateAsync(Token(audience: ConfiguredAudience));

        result.Succeeded.Should().BeTrue();
    }

    [Theory]
    [InlineData(OtherAppId)]
    [InlineData($"api://{OtherAppId}")]
    [InlineData("api://other")]
    [InlineData($"https://{AppId}")]
    public async Task Token_for_any_other_audience_is_rejected(string audience)
    {
        var result = await _validator.TryValidateAsync(Token(audience: audience));

        result.Succeeded.Should().BeFalse();
    }

    [Fact]
    public async Task Token_from_another_issuer_is_rejected_even_with_the_client_id_audience()
    {
        var result = await _validator.TryValidateAsync(Token(
            audience: AppId,
            issuer: "https://00000000-0000-0000-0000-000000000000.ciamlogin.com/00000000-0000-0000-0000-000000000000/v2.0"));

        result.Succeeded.Should().BeFalse();
    }

    [Fact]
    public async Task Token_signed_with_an_unknown_key_is_rejected()
    {
        using var otherRsa = RSA.Create(2048);
        var otherKey = new RsaSecurityKey(otherRsa) { KeyId = "ciam-test-key" };

        var result = await _validator.TryValidateAsync(Token(audience: AppId, signingKey: otherKey));

        result.Succeeded.Should().BeFalse();
    }

    [Fact]
    public async Task Expired_token_is_rejected()
    {
        var result = await _validator.TryValidateAsync(Token(
            audience: AppId,
            expires: DateTime.UtcNow.AddMinutes(-10)));

        result.Succeeded.Should().BeFalse();
    }

    [Theory]
    [InlineData(ConfiguredAudience, new[] { ConfiguredAudience, AppId })]
    [InlineData(AppId, new[] { AppId, ConfiguredAudience })]
    [InlineData("api://12910B8E-6C75-4D51-91D8-4D5FB8A6E915", new[] { "api://12910B8E-6C75-4D51-91D8-4D5FB8A6E915", AppId })]
    [InlineData("api://certigo-api", new[] { "api://certigo-api" })]
    [InlineData("certigo", new[] { "certigo" })]
    public void Accepted_audiences_are_only_the_two_spellings_of_the_configured_app(
        string configured,
        string[] expected)
        => EntraTokenValidator.AcceptedAudiences(configured).Should().Equal(expected);

    private string Token(
        string audience,
        string issuer = Authority,
        SecurityKey? signingKey = null,
        DateTime? expires = null)
    {
        var now = DateTime.UtcNow;
        var notBefore = (expires ?? now.AddMinutes(30)) < now ? now.AddMinutes(-30) : now.AddMinutes(-1);
        return new JwtSecurityTokenHandler().CreateEncodedJwt(
            issuer,
            audience,
            new ClaimsIdentity([new Claim("sub", "operator-sub"), new Claim("oid", "operator-oid"), new Claim("ver", "2.0")]),
            notBefore,
            expires ?? now.AddMinutes(30),
            notBefore,
            new SigningCredentials(signingKey ?? _signingKey, SecurityAlgorithms.RsaSha256));
    }
}
