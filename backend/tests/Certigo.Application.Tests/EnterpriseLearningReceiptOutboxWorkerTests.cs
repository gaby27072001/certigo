using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class EnterpriseLearningReceiptOutboxWorkerTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 21, 10, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task Worker_skips_receipt_when_subject_was_revoked_during_processing()
    {
        var fixture = CreateIntent();
        var outbox = new MemoryOutbox(fixture.Intent) { Revoked = true };
        var receipts = new MemoryReceipts();
        var worker = new EnterpriseLearningReceiptOutboxWorker(
            outbox,
            receipts,
            new FakeClock(Now));

        (await worker.RunBatchAsync(10)).Should().Be(1);

        receipts.CreateCount.Should().Be(0);
        outbox.Stored.State.Should().Be(
            EnterpriseLearningReceiptIntentState.SkippedRevoked);
    }

    [Fact]
    public async Task Expired_processing_lease_is_reclaimed_after_worker_crash()
    {
        var fixture = CreateIntent();
        var crashed = fixture.Intent.Claim(
            "crashed-worker",
            Now.AddMinutes(-3),
            TimeSpan.FromMinutes(2)) with { ETag = "\"2\"" };
        var outbox = new MemoryOutbox(crashed);
        var receipts = new MemoryReceipts();
        var worker = new EnterpriseLearningReceiptOutboxWorker(
            outbox,
            receipts,
            new FakeClock(Now));

        (await worker.RunBatchAsync(10)).Should().Be(1);

        receipts.CreateCount.Should().Be(1);
        outbox.Stored.State.Should().Be(EnterpriseLearningReceiptIntentState.Completed);
    }

    [Fact]
    public async Task Concurrent_workers_have_one_cas_claim_winner()
    {
        var fixture = CreateIntent();
        var outbox = new MemoryOutbox(fixture.Intent);
        var receipts = new MemoryReceipts();
        var workers = Enumerable.Range(0, 2)
            .Select(_ => new EnterpriseLearningReceiptOutboxWorker(
                outbox,
                receipts,
                new FakeClock(Now)))
            .ToArray();

        var completed = await Task.WhenAll(
            workers.Select(worker => worker.RunBatchAsync(10)));

        completed.Sum().Should().Be(1);
        receipts.CreateCount.Should().Be(1);
    }

    private static (EnterpriseLearningReceiptIntent Intent, string Subject) CreateIntent()
    {
        var membership = OrganizationMembership.Create(
            "organization-a",
            "person-a",
            OrganizationRole.Learner,
            Now);
        var lease = EnterpriseLearningSessionLease.Create(
            membership,
            "server-session-0000000000000001",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now);
        var heartbeat = lease.PrepareHeartbeat(
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            1,
            "operation-id-000001",
            Now.AddMinutes(1),
            EnterpriseLearningFact.Create(60, 0, 0, null),
            Now.AddMinutes(1));
        var intent = EnterpriseLearningReceiptIntent.From(
            heartbeat,
            Now.AddMinutes(1)) with { ETag = "\"1\"" };
        return (intent, heartbeat.MetricSubjectId);
    }

    private sealed class MemoryOutbox(
        EnterpriseLearningReceiptIntent intent) : IEnterpriseLearningReceiptOutboxRepository
    {
        private readonly object _gate = new();
        public EnterpriseLearningReceiptIntent Stored { get; private set; } = intent;
        public bool Revoked { get; set; }

        public Task<IReadOnlyList<EnterpriseLearningReceiptIntent>> ListClaimableAsync(
            int maximumIntents,
            DateTimeOffset now,
            CancellationToken cancellationToken = default)
        {
            lock (_gate)
            {
                var claimable = Stored.State == EnterpriseLearningReceiptIntentState.Pending
                    || Stored.State == EnterpriseLearningReceiptIntentState.Processing
                        && Stored.ProcessingLeaseUntil <= now;
                return Task.FromResult<IReadOnlyList<EnterpriseLearningReceiptIntent>>(
                    claimable ? [Stored] : []);
            }
        }

        public Task<EnterpriseLearningReceiptIntent?> ClaimAsync(
            EnterpriseLearningReceiptIntent candidate,
            string owner,
            DateTimeOffset now,
            TimeSpan lease,
            CancellationToken cancellationToken = default)
        {
            lock (_gate)
            {
                if (candidate.ETag != Stored.ETag
                    || Stored.State is EnterpriseLearningReceiptIntentState.Completed
                        or EnterpriseLearningReceiptIntentState.SkippedRevoked)
                {
                    return Task.FromResult<EnterpriseLearningReceiptIntent?>(null);
                }
                Stored = Stored.Claim(owner, now, lease) with { ETag = "\"claimed\"" };
                return Task.FromResult<EnterpriseLearningReceiptIntent?>(Stored);
            }
        }

        public Task<bool> IsSubjectDrainedAsync(
            string organizationId,
            string metricSubjectId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(Stored.State is EnterpriseLearningReceiptIntentState.Completed
                or EnterpriseLearningReceiptIntentState.SkippedRevoked);

        public Task<bool> IsSubjectRevokedAsync(
            string organizationId,
            string metricSubjectId,
            CancellationToken cancellationToken = default) => Task.FromResult(Revoked);

        public Task CompleteAsync(
            EnterpriseLearningReceiptIntent claimed,
            string owner,
            DateTimeOffset now,
            bool skippedRevoked,
            CancellationToken cancellationToken = default)
        {
            lock (_gate)
            {
                Stored = Stored.Complete(owner, now, skippedRevoked) with { ETag = "\"done\"" };
            }
            return Task.CompletedTask;
        }
    }

    private sealed class MemoryReceipts : IEnterpriseLearningMetricReceiptRepository
    {
        public int CreateCount { get; private set; }

        public Task<EnterpriseLearningMetricReceipt?> GetAsync(
            string id,
            string partitionKey,
            CancellationToken cancellationToken = default) =>
            Task.FromResult<EnterpriseLearningMetricReceipt?>(null);

        public Task CreateOrVerifyAsync(
            EnterpriseLearningMetricReceipt receipt,
            CancellationToken cancellationToken = default)
        {
            CreateCount++;
            return Task.CompletedTask;
        }

        public Task PurgeSubjectPartitionsAsync(
            IReadOnlyList<string> partitionKeys,
            string metricSubjectId,
            CancellationToken cancellationToken = default) => Task.CompletedTask;
    }
}
