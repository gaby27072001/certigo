using FluentAssertions;
using Microlingo.Application.Abstractions;
using Xunit;

namespace Microlingo.Application.Tests;

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
