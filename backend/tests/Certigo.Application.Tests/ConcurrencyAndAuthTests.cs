using FluentAssertions;
using Certigo.Application.Abstractions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class AuthValidatorSelectionTests
{
    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("entra")]
    [InlineData("Entra")]
    public void Non_dev_modes_select_the_entra_validator(string? mode)
        => AuthValidatorSelection.ShouldUseDevValidator(mode, isProduction: false, allowDevOverride: null)
            .Should().BeFalse();

    [Theory]
    [InlineData("dev")]
    [InlineData("DEV")]
    public void Dev_mode_is_allowed_outside_production(string mode)
        => AuthValidatorSelection.ShouldUseDevValidator(mode, isProduction: false, allowDevOverride: null)
            .Should().BeTrue();

    [Fact]
    public void Dev_mode_in_production_is_rejected_hard()
    {
        var act = () => AuthValidatorSelection.ShouldUseDevValidator("dev", isProduction: true, allowDevOverride: null);
        act.Should().Throw<InvalidOperationException>().WithMessage("*forbidden in a Production*");
    }

    [Fact]
    public void Dev_mode_in_production_requires_an_explicit_override()
        => AuthValidatorSelection.ShouldUseDevValidator("dev", isProduction: true, allowDevOverride: "true")
            .Should().BeTrue();
}

public sealed class JwtSigningKeyGuardTests
{
    private const string StrongKey = "a-strong-32-byte-production-secret-value";

    [Fact]
    public void Production_with_a_strong_key_returns_it_unchanged()
        => JwtSigningKeyGuard.ResolveSigningSecret(StrongKey, isProduction: true, authMode: "prod")
            .Should().Be(StrongKey);

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public void Production_without_a_key_fails_fast(string? configured)
    {
        var act = () => JwtSigningKeyGuard.ResolveSigningSecret(configured, isProduction: true, authMode: "prod");
        act.Should().Throw<InvalidOperationException>().WithMessage("*AUTH_JWT_SIGNING_KEY*");
    }

    [Theory]
    [InlineData(JwtSigningKeyGuard.DevelopmentSigningKey)]
    [InlineData("  " + JwtSigningKeyGuard.DevelopmentSigningKey + "  ")]
    public void Production_with_the_default_dev_key_is_rejected(string configured)
    {
        var act = () => JwtSigningKeyGuard.ResolveSigningSecret(configured, isProduction: true, authMode: null);
        act.Should().Throw<InvalidOperationException>().WithMessage("*development key is forbidden*");
    }

    [Fact]
    public void AuthMode_prod_hardens_even_when_the_host_is_not_production()
    {
        var act = () => JwtSigningKeyGuard.ResolveSigningSecret(null, isProduction: false, authMode: "prod");
        act.Should().Throw<InvalidOperationException>();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    public void Development_without_a_key_falls_back_to_the_dev_placeholder(string? configured)
        => JwtSigningKeyGuard.ResolveSigningSecret(configured, isProduction: false, authMode: "dev")
            .Should().Be(JwtSigningKeyGuard.DevelopmentSigningKey);

    [Fact]
    public void Development_honours_an_explicitly_configured_key()
        => JwtSigningKeyGuard.ResolveSigningSecret(StrongKey, isProduction: false, authMode: null)
            .Should().Be(StrongKey);
}

public sealed class OptimisticConcurrencyTests
{
    [Fact]
    public async Task Retries_until_the_write_lands_then_returns_the_value()
    {
        var attempts = 0;
        var result = await OptimisticConcurrency.ExecuteAsync(() =>
        {
            attempts++;
            if (attempts < 3)
            {
                throw new ConcurrencyConflictException("conflict");
            }

            return Task.FromResult(attempts);
        });

        result.Should().Be(3);
        attempts.Should().Be(3);
    }

    [Fact]
    public async Task Surfaces_the_conflict_after_exhausting_attempts()
    {
        var act = async () => await OptimisticConcurrency.ExecuteAsync<int>(
            () => throw new ConcurrencyConflictException("conflict"),
            maxAttempts: 3);

        await act.Should().ThrowAsync<ConcurrencyConflictException>();
    }
}
