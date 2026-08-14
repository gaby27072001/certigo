using System.Security.Claims;
using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Infrastructure.Identity;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class Pbkdf2PasswordHasherTests
{
    [Fact]
    public void Hash_then_verify_round_trips()
    {
        var hasher = new Pbkdf2PasswordHasher();
        var hash = hasher.Hash("correct horse battery staple");

        hash.Should().StartWith("pbkdf2.");
        hasher.Verify("correct horse battery staple", hash).Should().BeTrue();
    }

    [Fact]
    public void Verify_rejects_a_wrong_password()
    {
        var hasher = new Pbkdf2PasswordHasher();
        var hash = hasher.Hash("password123");

        hasher.Verify("password124", hash).Should().BeFalse();
    }

    [Fact]
    public void Hash_is_salted_so_repeated_hashes_differ()
    {
        var hasher = new Pbkdf2PasswordHasher();

        hasher.Hash("password123").Should().NotBe(hasher.Hash("password123"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("not-a-valid-hash")]
    [InlineData("pbkdf2.notanumber.salt.key")]
    [InlineData("pbkdf2.100000.@@@.@@@")]
    public void Verify_is_false_for_malformed_hashes(string hash)
        => new Pbkdf2PasswordHasher().Verify("password123", hash).Should().BeFalse();
}

public sealed class JwtTokenIssuerTests
{
    private const string Secret = "test-signing-secret";
    private const string Issuer = "certigo";
    private const string Audience = "certigo";

    private static JwtTokenIssuer NewIssuer() => new(Secret, Issuer, Audience);
    private static LocalJwtTokenValidator NewValidator() => new(Secret, Issuer, Audience);

    [Fact]
    public async Task Access_token_validates_and_carries_identity_claims()
    {
        var tokens = NewIssuer().Issue("user-1", "Alice", "alice@example.com");

        var result = await NewValidator().TryValidateAsync(tokens.AccessToken);

        result.Succeeded.Should().BeTrue();
        result.UserId.Should().Be("user-1");
        result.Principal!.FindFirst("name")!.Value.Should().Be("Alice");
        result.Principal!.FindFirst("email")!.Value.Should().Be("alice@example.com");
    }

    [Fact]
    public async Task Refresh_token_cannot_be_used_as_an_access_token()
    {
        var tokens = NewIssuer().Issue("user-1", "Alice", "alice@example.com");

        var result = await NewValidator().TryValidateAsync(tokens.RefreshToken);

        result.Succeeded.Should().BeFalse();
    }

    [Fact]
    public void ValidateRefreshToken_accepts_refresh_and_rejects_access()
    {
        var issuer = NewIssuer();
        var tokens = issuer.Issue("user-1", "Alice", "alice@example.com");

        var principal = issuer.ValidateRefreshToken(tokens.RefreshToken);

        principal.Should().NotBeNull();
        principal!.UserId.Should().Be("user-1");
        principal.Email.Should().Be("alice@example.com");
        issuer.ValidateRefreshToken(tokens.AccessToken).Should().BeNull();
    }

    [Fact]
    public async Task Token_signed_with_a_different_secret_fails_validation()
    {
        var tokens = new JwtTokenIssuer("a-different-secret", Issuer, Audience)
            .Issue("user-1", "Alice", "alice@example.com");

        var result = await NewValidator().TryValidateAsync(tokens.AccessToken);

        result.Succeeded.Should().BeFalse();
    }

    [Fact]
    public async Task Token_for_a_different_audience_fails_validation()
    {
        var tokens = new JwtTokenIssuer(Secret, Issuer, "someone-else")
            .Issue("user-1", "Alice", "alice@example.com");

        var result = await NewValidator().TryValidateAsync(tokens.AccessToken);

        result.Succeeded.Should().BeFalse();
    }

    [Fact]
    public async Task Previous_key_access_token_remains_valid_during_rotation()
    {
        const string previousSecret = "previous-signing-secret";
        var previousTokens = new JwtTokenIssuer(previousSecret, Issuer, Audience)
            .Issue("user-1", "Alice", "alice@example.com");
        var validator = new LocalJwtTokenValidator(
            Secret,
            Issuer,
            Audience,
            previousSigningSecret: previousSecret);

        var result = await validator.TryValidateAsync(previousTokens.AccessToken);

        result.Succeeded.Should().BeTrue();
        result.UserId.Should().Be("user-1");
    }

    [Fact]
    public void Previous_key_refresh_token_remains_valid_during_rotation()
    {
        const string previousSecret = "previous-signing-secret";
        var previousTokens = new JwtTokenIssuer(previousSecret, Issuer, Audience)
            .Issue("user-1", "Alice", "alice@example.com");
        var rotatingIssuer = new JwtTokenIssuer(
            Secret,
            Issuer,
            Audience,
            previousSigningSecret: previousSecret);

        rotatingIssuer.ValidateRefreshToken(previousTokens.RefreshToken)
            .Should().NotBeNull();
    }

    [Fact]
    public async Task Rotated_tokens_are_signed_only_with_the_active_key()
    {
        const string previousSecret = "previous-signing-secret";
        var rotatingIssuer = new JwtTokenIssuer(
            Secret,
            Issuer,
            Audience,
            previousSigningSecret: previousSecret);
        var tokens = rotatingIssuer.Issue("user-1", "Alice", "alice@example.com");

        var previousOnlyResult = await new LocalJwtTokenValidator(
            previousSecret,
            Issuer,
            Audience).TryValidateAsync(tokens.AccessToken);

        previousOnlyResult.Succeeded.Should().BeFalse();
        (await NewValidator().TryValidateAsync(tokens.AccessToken)).Succeeded.Should().BeTrue();
    }
}

public sealed class CompositeTokenValidatorTests
{
    private sealed class StubValidator(bool succeeds, string? userId) : ITokenValidator
    {
        public int Calls { get; private set; }

        public Task<TokenValidationResult> TryValidateAsync(string token, CancellationToken cancellationToken = default)
        {
            Calls++;
            var principal = new ClaimsPrincipal(new ClaimsIdentity("stub"));
            return Task.FromResult(succeeds
                ? new TokenValidationResult(true, principal, userId)
                : new TokenValidationResult(false, null, null));
        }
    }

    [Fact]
    public async Task Returns_the_first_success_and_short_circuits()
    {
        var first = new StubValidator(true, "u1");
        var second = new StubValidator(true, "u2");
        var composite = new CompositeTokenValidator(new ITokenValidator[] { first, second });

        var result = await composite.TryValidateAsync("token");

        result.UserId.Should().Be("u1");
        second.Calls.Should().Be(0);
    }

    [Fact]
    public async Task Falls_through_to_the_next_validator_on_failure()
    {
        var first = new StubValidator(false, null);
        var second = new StubValidator(true, "u2");
        var composite = new CompositeTokenValidator(new ITokenValidator[] { first, second });

        var result = await composite.TryValidateAsync("token");

        result.UserId.Should().Be("u2");
        first.Calls.Should().Be(1);
        second.Calls.Should().Be(1);
    }

    [Fact]
    public async Task Reports_failure_when_no_validator_succeeds()
    {
        var composite = new CompositeTokenValidator(new ITokenValidator[] { new StubValidator(false, null) });

        (await composite.TryValidateAsync("token")).Succeeded.Should().BeFalse();
    }
}
