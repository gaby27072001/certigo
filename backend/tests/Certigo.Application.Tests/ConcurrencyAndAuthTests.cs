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
        => AuthValidatorSelection.ShouldUseDevValidator(mode, isDevelopment: false, allowDevOverride: null)
            .Should().BeFalse();

    [Theory]
    [InlineData("dev")]
    [InlineData("DEV")]
    public void Dev_mode_is_allowed_in_Development(string mode)
        => AuthValidatorSelection.ShouldUseDevValidator(mode, isDevelopment: true, allowDevOverride: null)
            .Should().BeTrue();

    [Fact]
    public void Dev_mode_outside_Development_is_rejected_hard()
    {
        var act = () => AuthValidatorSelection.ShouldUseDevValidator("dev", isDevelopment: false, allowDevOverride: null);
        act.Should().Throw<InvalidOperationException>().WithMessage("*outside Development environment*");
    }

    [Fact]
    public void Dev_mode_in_staging_is_rejected_hard()
    {
        // Regression guard: staging is not Development, so the dev validator must be blocked
        // even though IsProduction() returns false for a staging host.
        var act = () => AuthValidatorSelection.ShouldUseDevValidator("dev", isDevelopment: false, allowDevOverride: null);
        act.Should().Throw<InvalidOperationException>().WithMessage("*outside Development environment*");
    }

    [Fact]
    public void Dev_mode_outside_Development_requires_explicit_override()
        => AuthValidatorSelection.ShouldUseDevValidator("dev", isDevelopment: false, allowDevOverride: "true")
            .Should().BeTrue();
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
