using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class EnterpriseLearningMetricsServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 21, 10, 0, 0, TimeSpan.Zero);
    private const string LeaseToken =
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    [Fact]
    public async Task Fresh_session_abuse_is_blocked_by_subject_wide_active_lease()
    {
        var fixture = CreateFixture();
        await fixture.Service.StartSessionAsync(fixture.OrganizationId);

        var action = () => fixture.Service.StartSessionAsync(fixture.OrganizationId);

        await action.Should().ThrowAsync<EnterpriseLearningLeaseConflictException>();
        fixture.Metrics.LeaseCreateCount.Should().Be(1);
        fixture.Metrics.HeartbeatCount.Should().Be(0);
    }

    [Fact]
    public async Task Heartbeat_uses_only_server_authoritative_facts()
    {
        var fixture = CreateFixture();
        await fixture.Service.StartSessionAsync(fixture.OrganizationId);

        await fixture.Service.RecordHeartbeatAsync(
            fixture.OrganizationId,
            Request(1, Now.AddMinutes(1)));

        fixture.Facts.CallCount.Should().Be(1);
        fixture.Metrics.LearningSeconds.Should().Be(60);
        typeof(EnterpriseLearningHeartbeatRequest).GetProperties()
            .Select(property => property.Name)
            .Should().NotContain([
                "LearningSeconds",
                "ProgressBasisPoints",
                "CompletionCount",
                "ReadinessBasisPoints",
            ]);
    }

    [Fact]
    public async Task Invalid_lease_is_rejected_before_authoritative_fact_read()
    {
        var fixture = CreateFixture();
        await fixture.Service.StartSessionAsync(fixture.OrganizationId);
        var request = Request(1, Now.AddMinutes(1)) with
        {
            LeaseToken = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        };

        var action = () => fixture.Service.RecordHeartbeatAsync(
            fixture.OrganizationId,
            request);

        await action.Should().ThrowAsync<OrganizationAccessDeniedException>();
        fixture.Facts.CallCount.Should().Be(0);
    }

    [Fact]
    public async Task Concurrent_replay_is_counted_once()
    {
        var fixture = CreateFixture();
        await fixture.Service.StartSessionAsync(fixture.OrganizationId);
        var request = Request(1, Now.AddMinutes(1));

        var results = await Task.WhenAll(
            fixture.Service.RecordHeartbeatAsync(fixture.OrganizationId, request),
            fixture.Service.RecordHeartbeatAsync(fixture.OrganizationId, request));

        results.Count(result => !result.Replayed).Should().Be(1);
        results.Count(result => result.Replayed).Should().Be(1);
        fixture.Metrics.HeartbeatCount.Should().Be(1);
    }

    [Fact]
    public async Task Historical_replay_returns_before_current_lease_and_fact_source()
    {
        var fixture = CreateFixture();
        await fixture.Service.StartSessionAsync(fixture.OrganizationId);
        var request = Request(1, Now.AddMinutes(1));
        await fixture.Service.RecordHeartbeatAsync(fixture.OrganizationId, request);
        fixture.Metrics.RemoveLease();
        var factsBeforeReplay = fixture.Facts.CallCount;

        var replay = await fixture.Service.RecordHeartbeatAsync(
            fixture.OrganizationId,
            request);

        replay.Replayed.Should().BeTrue();
        fixture.Facts.CallCount.Should().Be(factsBeforeReplay);
    }

    [Fact]
    public async Task Historical_replay_hash_mismatch_fails_before_fact_source()
    {
        var fixture = CreateFixture();
        await fixture.Service.StartSessionAsync(fixture.OrganizationId);
        var request = Request(1, Now.AddMinutes(1));
        await fixture.Service.RecordHeartbeatAsync(fixture.OrganizationId, request);
        fixture.Metrics.RemoveLease();
        var factsBeforeReplay = fixture.Facts.CallCount;

        var action = () => fixture.Service.RecordHeartbeatAsync(
            fixture.OrganizationId,
            request with { OperationId = "different-operation-0001" });

        await action.Should().ThrowAsync<OrganizationIdempotencyConflictException>();
        fixture.Facts.CallCount.Should().Be(factsBeforeReplay);
    }

    [Fact]
    public async Task Daily_summary_is_fixed_and_suppressed_below_threshold()
    {
        var fixture = CreateFixture();
        fixture.Metrics.ContributorCount =
            EnterpriseLearningMetricsPolicy.MinimumContributors - 1;

        var result = await fixture.Service.GetDailySummaryAsync(
            fixture.OrganizationId,
            DateOnly.FromDateTime(Now.UtcDateTime));

        result.Suppressed.Should().BeTrue();
        result.LearningSeconds.Should().Be(0);
        result.AverageReadinessPercent.Should().BeNull();
        typeof(IEnterpriseLearningMetricsService).GetMethods()
            .Select(method => method.Name)
            .Should().NotContain("GetSummaryAsync");
        typeof(EnterpriseLearningDailySummaryDto).GetProperties()
            .Select(property => property.Name)
            .Should().Contain("Day")
            .And.NotContain(["From", "To"]);
    }

    [Fact]
    public async Task Active_summary_uses_preaggregated_bucket_and_suppresses_small_population()
    {
        var fixture = CreateFixture();
        fixture.Metrics.ContributorCount = 1;

        var result = await fixture.Service.GetActiveSummaryAsync(fixture.OrganizationId);

        result.Suppressed.Should().BeTrue();
        result.ActiveContributorCountLowerBound.Should().Be(0);
        fixture.Metrics.ActiveSummaryReads.Should().Be(1);
    }

    [Fact]
    public async Task Cross_tenant_actor_cannot_start_or_read_metrics()
    {
        var fixture = CreateFixture();
        const string foreign = "organization::v1::foreign";

        var start = () => fixture.Service.StartSessionAsync(foreign);
        var read = () => fixture.Service.GetDailySummaryAsync(
            foreign,
            DateOnly.FromDateTime(Now.UtcDateTime));

        await start.Should().ThrowAsync<OrganizationMembershipNotFoundException>();
        await read.Should().ThrowAsync<OrganizationMembershipNotFoundException>();
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("shadow")]
    [InlineData("enabled")]
    public void Feature_mode_is_strictly_off(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            EnterpriseLearningMetricsFeatureOptions.Parse(value).Mode.Should()
                .Be(EnterpriseLearningMetricsFeatureMode.Off);
            return;
        }
        var action = () => EnterpriseLearningMetricsFeatureOptions.Parse(value);
        action.Should().Throw<InvalidOperationException>();
    }

    private static EnterpriseLearningHeartbeatRequest Request(
        long sequence,
        DateTimeOffset occurredAt) =>
        new(
            "server-session-0000000000000001",
            LeaseToken,
            $"operation-id-{sequence:D8}",
            sequence,
            occurredAt);

    private static Fixture CreateFixture()
    {
        const string organizationId = "organization::v1::contoso";
        const string personId = "person-a";
        var organizations = new MemoryMembershipRepository();
        organizations.Seed(OrganizationMembership.Create(
            organizationId,
            personId,
            OrganizationRole.Manager,
            Now) with { ETag = "\"1\"" });
        var person = new StubPersonResolver(personId);
        var membershipResolver = new OrganizationMembershipResolver(organizations);
        var authorization = new OrganizationAuthorizationHandler(person, membershipResolver);
        var metrics = new MemoryMetricsRepository(organizations);
        var facts = new FakeFactSource();
        var service = new EnterpriseLearningMetricsService(
            authorization,
            metrics,
            facts,
            new FixedLeaseGenerator(),
            new FakeClock(Now));
        return new Fixture(organizationId, service, organizations, metrics, facts);
    }

    private sealed record Fixture(
        string OrganizationId,
        EnterpriseLearningMetricsService Service,
        MemoryMembershipRepository Organizations,
        MemoryMetricsRepository Metrics,
        FakeFactSource Facts);

    private sealed class FixedLeaseGenerator : IEnterpriseLearningLeaseGenerator
    {
        public string NewSessionId() => "server-session-0000000000000001";
        public string NewLeaseToken() => LeaseToken;
    }

    private sealed class FakeFactSource : IEnterpriseLearningFactSource
    {
        public int CallCount { get; private set; }

        public Task<EnterpriseLearningFact> GetDeltaAsync(
            string organizationId,
            string personId,
            DateTimeOffset fromExclusive,
            DateTimeOffset toInclusive,
            CancellationToken cancellationToken = default)
        {
            CallCount++;
            return Task.FromResult(EnterpriseLearningFact.Create(60, 250, 1, 8_000));
        }
    }

    private sealed class StubPersonResolver(string personId) : IOrganizationPersonResolver
    {
        public Task<string> ResolveAsync(CancellationToken cancellationToken = default) =>
            Task.FromResult(personId);
    }

    private sealed class MemoryMembershipRepository : IOrganizationRepository
    {
        private readonly Dictionary<(string, string), OrganizationMembership> _memberships = [];

        public void Seed(OrganizationMembership membership) =>
            _memberships[(membership.OrganizationId, membership.PersonId)] = membership;

        public bool IsCurrent(OrganizationMembership membership) =>
            _memberships.TryGetValue(
                (membership.OrganizationId, membership.PersonId),
                out var current)
            && current.ETag == membership.ETag;

        public Task<OrganizationMembership?> GetMembershipAsync(
            string organizationId,
            string personId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_memberships.GetValueOrDefault((organizationId, personId)));

        public Task<OrganizationOffboardingTombstone?> GetLatestOffboardingAsync(
            string organizationId,
            string personId,
            CancellationToken cancellationToken = default) => Task.FromResult<
                OrganizationOffboardingTombstone?>(null);
        public Task<IReadOnlyList<OrganizationOffboardingTombstone>>
            ListIncompleteOffboardingsAsync(
                int maximumTombstones,
                CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<OrganizationOffboardingTombstone>>([]);
        public Task<TeamMembershipVolumetryObservation> CountTeamMembershipsAsync(
            CancellationToken cancellationToken = default) =>
            Task.FromResult(new TeamMembershipVolumetryObservation(0, Capped: false));
        public Task<OrganizationCreateResult> CreateOrganizationAsync(
            Organization organization,
            OrganizationMembership ownerMembership,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<Organization?> GetOrganizationAsync(
            string organizationId,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<OrganizationInvitationCreateResult> CreateInvitationAsync(
            OrganizationMembership actor,
            OrganizationInvitation invitation,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<OrganizationMembership> AcceptInvitationAsync(
            OrganizationMembership issuer,
            OrganizationInvitation invitation,
            OrganizationMembership membership,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<OrganizationTeamCreateResult> CreateTeamAsync(
            OrganizationMembership actor,
            OrganizationTeam team,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<OrganizationTeam?> GetTeamAsync(
            string organizationId,
            string teamId,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task AddTeamMemberAsync(
            OrganizationMembership actor,
            OrganizationMembership target,
            OrganizationTeamMembership teamMembership,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task OffboardAsync(
            OrganizationMembership actor,
            OrganizationMembership target,
            DateTimeOffset revokedAt,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task PurgeOffboardingAsync(
            string organizationId,
            string tombstoneId,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
        public Task<OrganizationInvitation?> GetInvitationAsync(
            string organizationId,
            string invitationId,
            CancellationToken cancellationToken = default) => throw new NotSupportedException();
    }

    private sealed class MemoryMetricsRepository(
        MemoryMembershipRepository memberships) : IEnterpriseLearningMetricsRepository
    {
        private readonly object _gate = new();
        private EnterpriseLearningSessionLease? _lease;
        private readonly Dictionary<string, (string Hash, EnterpriseLearningReplayResult Result)>
            _replays = [];

        public int LeaseCreateCount { get; private set; }
        public long HeartbeatCount { get; private set; }
        public long LearningSeconds { get; private set; }
        public int ContributorCount { get; set; } =
            EnterpriseLearningMetricsPolicy.MinimumContributors;
        public int ActiveSummaryReads { get; private set; }

        public Task<EnterpriseLearningReplayResult?> GetReplayAsync(
            OrganizationMembership actor,
            string sessionId,
            long sequence,
            string operationId,
            DateTimeOffset occurredAt,
            CancellationToken cancellationToken = default)
        {
            var id = EnterpriseMetricDocumentIds.ReceiptIntent(
                actor.OrganizationId,
                sessionId,
                sequence);
            if (!_replays.TryGetValue(id, out var replay))
            {
                return Task.FromResult<EnterpriseLearningReplayResult?>(null);
            }
            var hash = EnterpriseMetricDocumentIds.RequestHash(
                sessionId,
                operationId,
                sequence,
                occurredAt);
            if (hash != replay.Hash)
            {
                throw new OrganizationIdempotencyConflictException();
            }
            return Task.FromResult<EnterpriseLearningReplayResult?>(replay.Result);
        }

        public Task<EnterpriseLearningSessionLease> StartLeaseAsync(
            OrganizationMembership actor,
            EnterpriseLearningSessionLease candidate,
            DateTimeOffset acceptedAt,
            CancellationToken cancellationToken = default)
        {
            lock (_gate)
            {
                if (_lease is not null)
                {
                    throw new EnterpriseLearningLeaseConflictException();
                }
                LeaseCreateCount++;
                _lease = candidate with { ETag = "\"lease-1\"" };
                return Task.FromResult(_lease);
            }
        }

        public Task<EnterpriseLearningSessionLease> GetLeaseAsync(
            OrganizationMembership actor,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_lease ?? throw new OrganizationNotFoundException());

        public Task<EnterpriseLearningMetricWriteResult> RecordHeartbeatAsync(
            OrganizationMembership actor,
            EnterpriseLearningSessionLease lease,
            EnterpriseLearningHeartbeat heartbeat,
            DateTimeOffset acceptedAt,
            CancellationToken cancellationToken = default)
        {
            lock (_gate)
            {
                if (!memberships.IsCurrent(actor))
                {
                    throw new ConcurrencyConflictException("Membership changed.");
                }
                if (_lease!.LastSequence == heartbeat.Sequence)
                {
                    if (_lease.LastRequestHash != heartbeat.RequestHash)
                    {
                        throw new OrganizationIdempotencyConflictException();
                    }
                    return Task.FromResult(new EnterpriseLearningMetricWriteResult(
                        EnterpriseLearningMetricWriteStatus.Replayed,
                        _lease));
                }
                _lease = _lease.Advance(heartbeat, acceptedAt) with { ETag = "\"lease-next\"" };
                _replays[EnterpriseMetricDocumentIds.ReceiptIntent(
                    heartbeat.OrganizationId,
                    heartbeat.SessionId,
                    heartbeat.Sequence)] = (
                    heartbeat.RequestHash,
                    new EnterpriseLearningReplayResult(heartbeat.SessionId, acceptedAt));
                HeartbeatCount++;
                LearningSeconds += heartbeat.Fact.LearningSeconds;
                return Task.FromResult(new EnterpriseLearningMetricWriteResult(
                    EnterpriseLearningMetricWriteStatus.Created,
                    _lease));
            }

        }

        public void RemoveLease() => _lease = null;

        public Task<EnterpriseLearningDailySummary> GetDailySummaryAsync(
            OrganizationMembership actor,
            DateOnly day,
            CancellationToken cancellationToken = default)
        {
            var suppressed = ContributorCount < EnterpriseLearningMetricsPolicy.MinimumContributors;
            return Task.FromResult(new EnterpriseLearningDailySummary(
                actor.OrganizationId,
                day,
                suppressed,
                ContributorCount,
                suppressed ? 0 : LearningSeconds,
                0,
                0,
                0,
                0,
                suppressed ? 0 : HeartbeatCount));
        }

        public Task<EnterpriseLearningActiveSummary> GetActiveSummaryAsync(
            OrganizationMembership actor,
            DateTimeOffset bucketStartedAt,
            CancellationToken cancellationToken = default)
        {
            ActiveSummaryReads++;
            return Task.FromResult(new EnterpriseLearningActiveSummary(
                actor.OrganizationId,
                bucketStartedAt,
                ContributorCount < EnterpriseLearningMetricsPolicy.MinimumContributors,
                ContributorCount));
        }
    }
}
