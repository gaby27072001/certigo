using Certigo.Infrastructure.Cosmos;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class OrganizationCosmosContractTests
{
    [Fact]
    public void Organization_container_is_additive_partition_local_and_ttl_enabled()
    {
        var definition = CosmosContainers.All.Single(
            item => item.Name == CosmosContainers.Organizations);

        definition.PartitionKeyPath.Should().Be("/organizationId");
        definition.DefaultTimeToLive.Should().Be(-1);
        CosmosContainers.All.Select(item => item.Name).Should().OnlyHaveUniqueItems();
    }
}
