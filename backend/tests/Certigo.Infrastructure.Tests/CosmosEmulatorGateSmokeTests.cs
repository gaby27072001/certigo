using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

/// <summary>
/// Plain [Fact] tests (always run, never skipped) that verify the Cosmos emulator
/// gating mechanism works correctly — especially important to confirm in CI that the
/// six <see cref="CosmosRepositoriesIntegrationTests"/> are reported as *skipped*
/// (not failed) when no emulator is available.
/// </summary>
public sealed class CosmosEmulatorGateSmokeTests
{
    [Fact]
    public void CosmosEmulatorFactAttribute_skip_message_is_populated_when_flag_is_unset()
    {
        // Arrange: simulate the attribute being constructed with the flag unset.
        // We read the real env to decide which branch to assert.
        var attribute = new CosmosEmulatorFactAttribute();

        if (!CosmosEmulatorFixture.Enabled)
        {
            // The xUnit runner honours FactAttribute.Skip: a non-null, non-empty value
            // causes the test to be reported as skipped rather than executed. Verify
            // that the gate correctly sets it so the Cosmos suite never crashes CI.
            attribute.Skip.Should().NotBeNullOrEmpty(
                because: $"when {CosmosEmulatorFixture.EnableFlag} != '1' every " +
                         "[CosmosEmulatorFact] must be reported as skipped, not failed");
        }
        else
        {
            // Flag is set — tests should run, so Skip must be null/empty.
            attribute.Skip.Should().BeNullOrEmpty(
                because: $"when {CosmosEmulatorFixture.EnableFlag}=1 the emulator " +
                         "tests are expected to run (Skip should be null)");
        }
    }

    [Fact]
    public void CosmosEmulatorFixture_Enabled_reflects_the_environment_variable()
    {
        var envValue = Environment.GetEnvironmentVariable(CosmosEmulatorFixture.EnableFlag);
        var expected = string.Equals(envValue, "1", StringComparison.Ordinal);

        CosmosEmulatorFixture.Enabled.Should().Be(expected,
            because: $"Enabled must return true only when {CosmosEmulatorFixture.EnableFlag}=1");
    }
}
