using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class EnterpriseLearningMetricsModelsTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 21, 10, 0, 0, TimeSpan.Zero);
    private const string LeaseToken =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    [Fact]
    public void Server_issued_lease_creation_contributes_no_metrics()
    {
        var lease = Lease("person-a");

        lease.LastSequence.Should().Be(0);
        lease.LastRequestHash.Should().BeNull();
        lease.FactWatermark.Should().Be(Now);
        lease.ToString().Should().NotContain("person-a");
    }

    [Fact]
    public void Lease_rejects_wrong_token_duplicate_sequence_and_overstated_time()
    {
        var lease = Lease("person-a");
        var wrongToken = () => lease.PrepareHeartbeat(
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            1,
            "operation-id-000001",
            Now.AddMinutes(1),
            EnterpriseLearningFact.Create(60, 100, 0, null),
            Now.AddMinutes(1));
        var first = lease.PrepareHeartbeat(
            LeaseToken,
            1,
            "operation-id-000001",
            Now.AddMinutes(1),
            EnterpriseLearningFact.Create(60, 100, 0, null),
            Now.AddMinutes(1));
        var advanced = lease.Advance(first, Now.AddMinutes(1));
        var duplicate = () => advanced.PrepareHeartbeat(
            LeaseToken,
            1,
            "operation-id-000002",
            Now.AddMinutes(2),
            EnterpriseLearningFact.Create(60, 100, 0, null),
            Now.AddMinutes(2));
        var overstated = () => advanced.PrepareHeartbeat(
            LeaseToken,
            2,
            "operation-id-000002",
            Now.AddMinutes(2),
            EnterpriseLearningFact.Create(61, 100, 0, null),
            Now.AddMinutes(2));

        wrongToken.Should().Throw<OrganizationAccessDeniedException>();
        duplicate.Should().Throw<EnterpriseLearningSequenceException>();
        overstated.Should().Throw<EnterpriseLearningSequenceException>();
    }

    [Fact]
    public void Receipt_partitions_bound_ten_thousand_learner_daily_budget()
    {
        var partitions = Enumerable.Range(0, 10_000)
            .SelectMany(index =>
            {
                var lease = Lease($"person-{index:D8}");
                return Enumerable.Range(1, 96).Select(sequence =>
                    EnterpriseMetricDocumentIds.ReceiptPartition(
                        lease.OrganizationId,
                        Now,
                        EnterpriseMetricDocumentIds.AggregateShard(lease.MetricSubjectId)));
            })
            .GroupBy(value => value)
            .Select(group => group.Count())
            .ToArray();

        partitions.Should().HaveCount(EnterpriseLearningMetricsPolicy.AggregateShardCount);
        partitions.Max().Should().BeLessThan(10_000);
        (partitions.Max() * 1024L).Should().BeLessThan(10L * 1024 * 1024);
    }

    [Fact]
    public void Twenty_thousand_sessions_reduce_to_at_most_128_active_shards()
    {
        var shards = new Dictionary<int, EnterpriseLearningActiveSubjectShard>();
        for (var index = 0; index < 20_000; index++)
        {
            var lease = Lease($"person-{index:D8}");
            var heartbeat = lease.PrepareHeartbeat(
                LeaseToken,
                1,
                $"operation-{index:D8}",
                Now.AddMinutes(1),
                EnterpriseLearningFact.Create(60, 0, 0, null),
                Now.AddMinutes(1));
            shards[heartbeat.AggregateShard] = EnterpriseLearningActiveSubjectShard.Apply(
                heartbeat,
                shards.GetValueOrDefault(heartbeat.AggregateShard),
                Now.AddMinutes(1));
        }

        shards.Should().HaveCount(EnterpriseLearningMetricsPolicy.AggregateShardCount);
        EnterpriseLearningDailyAggregateShard.CountContributors(
                shards.Values.Select(value => value.ContributorBitmap))
            .Should().BeGreaterThan(EnterpriseLearningMetricsPolicy.MinimumContributors);
    }

    [Fact]
    public void Ten_thousand_subjects_with_two_clients_have_only_ten_thousand_lease_keys()
    {
        var leaseIds = Enumerable.Range(0, 10_000)
            .SelectMany(index =>
            {
                var membership = OrganizationMembership.Create(
                    "organization-a",
                    $"person-{index:D8}",
                    OrganizationRole.Learner,
                    Now);
                return new[]
                {
                    EnterpriseLearningSessionLease.Create(
                        membership,
                        $"server-session-a-{index:D8}",
                        LeaseToken,
                        Now).Id,
                    EnterpriseLearningSessionLease.Create(
                        membership,
                        $"server-session-b-{index:D8}",
                        LeaseToken,
                        Now).Id,
                };
            })
            .Distinct(StringComparer.Ordinal)
            .ToArray();

        leaseIds.Should().HaveCount(10_000);
    }

    [Fact]
    public void Daily_bucket_ttl_is_anchored_to_metric_day()
    {
        var lease = Lease("person-a", Now.AddDays(-30));
        var heartbeat = lease.PrepareHeartbeat(
            LeaseToken,
            1,
            "operation-id-000001",
            Now.AddDays(-30).AddMinutes(1),
            EnterpriseLearningFact.Create(60, 0, 0, null),
            Now);
        var aggregate = EnterpriseLearningDailyAggregateShard.Apply(
            heartbeat,
            null,
            Now);
        var expectedCutoff = DateOnly.FromDateTime(heartbeat.OccurredAt.UtcDateTime)
            .ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc)
            .AddDays(EnterpriseLearningMetricsPolicy.AggregateRetentionDays + 1);

        aggregate.Ttl.Should().Be(
            (int)Math.Ceiling((expectedCutoff - Now.UtcDateTime).TotalSeconds));
    }

    [Fact]
    public void Membership_cycles_produce_unlinkable_metric_subjects()
    {
        var first = Lease("portable-person", cycle: 1);
        var second = Lease("portable-person", cycle: 2);

        first.MetricSubjectId.Should().NotBe(second.MetricSubjectId);
        first.MetricCohortSubjectId.Should().Be(second.MetricCohortSubjectId);
        first.ToString().Should().NotContain("portable-person");
        second.ToString().Should().NotContain("portable-person");
    }

    [Fact]
    public void One_person_across_five_cycles_counts_as_one_privacy_contributor()
    {
        var bitmaps = Enumerable.Range(1, 5)
            .Select(cycle =>
            {
                var lease = Lease("portable-person", cycle: cycle);
                var heartbeat = lease.PrepareHeartbeat(
                    LeaseToken,
                    1,
                    $"operation-id-{cycle:D8}",
                    Now.AddMinutes(1),
                    EnterpriseLearningFact.Create(60, 0, 0, null),
                    Now.AddMinutes(1));
                return EnterpriseLearningDailyAggregateShard.Apply(
                    heartbeat,
                    null,
                    Now.AddMinutes(1)).ContributorBitmap;
            });

        EnterpriseLearningDailyAggregateShard.CountContributors(bitmaps).Should().Be(1);
    }

    [Fact]
    public void Tombstone_receipt_partition_fanout_is_bounded_to_thirty_direct_keys()
    {
        var membership = OrganizationMembership.Create(
            "organization-a",
            "person-a",
            OrganizationRole.Learner,
            Now);

        var tombstone = OrganizationOffboardingTombstone.Create(membership, Now);

        tombstone.ReceiptPartitionKeys.Should().HaveCount(30).And.OnlyHaveUniqueItems();
        tombstone.ReceiptPartitionKeys.Should().OnlyContain(key =>
            key.StartsWith("organization-a|", StringComparison.Ordinal));
    }

    private static EnterpriseLearningSessionLease Lease(
        string personId,
        DateTimeOffset? startedAt = null,
        int cycle = 1)
    {
        var membership = OrganizationMembership.Create(
            "organization-a",
            personId,
            OrganizationRole.Learner,
            startedAt ?? Now,
            cycle);
        return EnterpriseLearningSessionLease.Create(
            membership,
            "server-session-0000000000000001",
            LeaseToken,
            startedAt ?? Now);
    }
}
