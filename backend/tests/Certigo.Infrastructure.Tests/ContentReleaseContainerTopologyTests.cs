using Certigo.Infrastructure.Cosmos;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class ContentReleaseContainerTopologyTests
{
    [Fact]
    public void Public_private_and_control_content_use_distinct_containers()
    {
        CosmosContainers.ContentPublic.Should().NotBe(CosmosContainers.ContentPrivate);
        CosmosContainers.ContentPublic.Should().NotBe(CosmosContainers.ContentReleases);
        CosmosContainers.ContentPrivate.Should().NotBe(CosmosContainers.ContentReleases);

        CosmosContainers.All.Should().Contain(new CosmosContainerDefinition(
            CosmosContainers.ContentPublic,
            "/releaseId"));
        CosmosContainers.All.Should().Contain(new CosmosContainerDefinition(
            CosmosContainers.ContentPrivate,
            "/releaseId"));
        CosmosContainers.All.Should().Contain(new CosmosContainerDefinition(
            CosmosContainers.ContentReleases,
            "/scope"));
    }
}
