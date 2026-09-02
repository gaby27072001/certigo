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

    [Fact]
    public void Enterprise_metrics_split_transactional_state_from_sharded_receipts()
    {
        CosmosContainers.All.Should().ContainSingle(
            item => item.Name == CosmosContainers.Organizations
                && item.PartitionKeyPath == "/organizationId");
        Certigo.Domain.Organizations.EnterpriseLearningMetricsPolicy.LeaseTtlSeconds
            .Should().Be(3_600);
        Certigo.Domain.Organizations.EnterpriseLearningMetricsPolicy.ReplayReceiptTtlSeconds
            .Should().Be(2_592_000);
        Certigo.Domain.Organizations.EnterpriseLearningMetricsPolicy.AggregateRetentionDays
            .Should().Be(400);
        Certigo.Domain.Organizations.EnterpriseLearningMetricsPolicy.AggregateShardCount
            .Should().Be(128);
        Certigo.Domain.Organizations.EnterpriseLearningMetricsPolicy.MinimumContributors
            .Should().Be(5);
        Certigo.Domain.Organizations.EnterpriseLearningMetricsPolicy.MaximumDailySummaryDocuments
            .Should().Be(128);
        CosmosContainers.All.Should().ContainSingle(item =>
            item.Name == CosmosContainers.EnterpriseMetricReceipts
            && item.PartitionKeyPath == "/partitionKey"
            && item.DefaultTimeToLive == -1);
    }
}
