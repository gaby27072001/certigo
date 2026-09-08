using Certigo.Api.Functions;
using Certigo.Application.Abstractions;
using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Api.Tests;

public sealed class OrganizationShadowObservationFunctionsTests
{
    [Fact]
    public async Task Timer_is_a_strict_no_op_while_feature_is_off()
    {
        var reader = new SpyShadowObservationReader();
        var function = new OrganizationShadowObservationFunctions(
            OrganizationFeatureOptions.Parse(null),
            reader);

        await function.RunAsync(null!, CancellationToken.None);

        reader.ListIncompleteOffboardingsCallCount.Should().Be(0);
        reader.CountTeamMembershipsCallCount.Should().Be(0);
    }

    [Fact]
    public async Task Shadow_mode_observes_through_the_read_only_reader_only()
    {
        var reader = new SpyShadowObservationReader();
        var function = new OrganizationShadowObservationFunctions(
            OrganizationFeatureOptions.Parse("shadow"),
            reader);

        await function.RunAsync(null!, CancellationToken.None);

        reader.ListIncompleteOffboardingsCallCount.Should().Be(1);
        reader.CountTeamMembershipsCallCount.Should().Be(1);
        reader.LastMaximumTombstones.Should().BeInRange(1, 100);
    }

    /// <summary>
    /// Implements ONLY <see cref="IOrganizationShadowObservationReader"/> — the exact same narrow
    /// interface the production Function depends on. There is no create/replace/delete member on
    /// this type to call by mistake, so the "zero mutation" guarantee proven here is structural
    /// (it would fail to compile otherwise), not merely behavioral.
    /// </summary>
    private sealed class SpyShadowObservationReader : IOrganizationShadowObservationReader
    {
        public int ListIncompleteOffboardingsCallCount { get; private set; }
        public int CountTeamMembershipsCallCount { get; private set; }
        public int LastMaximumTombstones { get; private set; }

        public Task<IReadOnlyList<OrganizationOffboardingTombstone>>
            ListIncompleteOffboardingsAsync(
                int maximumTombstones,
                CancellationToken cancellationToken = default)
        {
            ListIncompleteOffboardingsCallCount++;
            LastMaximumTombstones = maximumTombstones;
            return Task.FromResult<IReadOnlyList<OrganizationOffboardingTombstone>>([]);
        }

        public Task<TeamMembershipVolumetryObservation> CountTeamMembershipsAsync(
            CancellationToken cancellationToken = default)
        {
            CountTeamMembershipsCallCount++;
            return Task.FromResult(new TeamMembershipVolumetryObservation(0, Capped: false));
        }
    }
}
