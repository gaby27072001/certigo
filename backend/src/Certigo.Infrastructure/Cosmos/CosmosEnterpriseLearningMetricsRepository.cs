using System.Net;
using Certigo.Application.Abstractions;
using Certigo.Domain.Organizations;
using Microsoft.Azure.Cosmos;

namespace Certigo.Infrastructure.Cosmos;

public sealed class CosmosEnterpriseLearningMetricReceiptRepository(
    CosmosContext context) : IEnterpriseLearningMetricReceiptRepository
{
    private const int PurgePageSize = 50;
    public Task<EnterpriseLearningMetricReceipt?> GetAsync(
        string id,
        string partitionKey,
        CancellationToken cancellationToken = default) =>
        context.EnterpriseMetricReceipts.ReadOrDefaultAsync<EnterpriseLearningMetricReceipt>(
            id,
            new PartitionKey(partitionKey),
            cancellationToken);

    public async Task CreateOrVerifyAsync(
        EnterpriseLearningMetricReceipt receipt,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await context.EnterpriseMetricReceipts.CreateItemAsync(
                receipt,
                new PartitionKey(receipt.PartitionKey),
                cancellationToken: cancellationToken);
        }
        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
        {
            var existing = await GetAsync(
                receipt.Id,
                receipt.PartitionKey,
                cancellationToken);
            if (existing is null
                || !string.Equals(
                    existing.RequestHash,
                    receipt.RequestHash,
                    StringComparison.Ordinal))
            {
                throw new OrganizationIdempotencyConflictException();
            }
        }
    }

    public async Task PurgeSubjectPartitionsAsync(
            IReadOnlyList<string> partitionKeys,
            string metricSubjectId,
            CancellationToken cancellationToken = default)
        {
            foreach (var partitionKey in partitionKeys)
            {
                var query = new QueryDefinition(
                    "SELECT TOP 50 c.id, c.partitionKey FROM c "
                        + "WHERE c.metricSubjectId = @metricSubjectId")
                    .WithParameter("@metricSubjectId", metricSubjectId);
                while (true)
                {
                    using var iterator = context.EnterpriseMetricReceipts
                        .GetItemQueryIterator<ReceiptAddress>(
                            query,
                            requestOptions: new QueryRequestOptions
                            {
                                PartitionKey = new PartitionKey(partitionKey),
                                MaxItemCount = PurgePageSize,
                            });
                    var page = iterator.HasMoreResults
                        ? (await iterator.ReadNextAsync(cancellationToken)).ToArray()
                        : [];
                    if (page.Length == 0)
                    {
                        break;
                    }
                    foreach (var receipt in page)
                    {
                        try
                        {
                            await context.EnterpriseMetricReceipts.DeleteItemAsync<object>(
                                receipt.Id,
                                new PartitionKey(receipt.PartitionKey),
                                cancellationToken: cancellationToken);
                        }
                        catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.NotFound)
                        {
                            // A previous recovery attempt already removed this immutable receipt.
                        }
                    }
                }
            }
        }

    private sealed record ReceiptAddress(string Id, string PartitionKey);
}

public sealed class CosmosEnterpriseLearningMetricsRepository(
    CosmosContext context,
    IEnterpriseLearningMetricReceiptRepository receipts)
    : IEnterpriseLearningMetricsRepository, IEnterpriseLearningReceiptOutboxRepository
{
    private const int MaximumWriteAttempts = 8;
    private const int MaximumReadThrottleRetries = 5;
    private const int QueryPageSize = 128;

    public async Task<EnterpriseLearningReplayResult?> GetReplayAsync(
        OrganizationMembership actor,
        string sessionId,
        long sequence,
        string operationId,
        DateTimeOffset occurredAt,
        CancellationToken cancellationToken = default)
    {
        var intent = await context.Organizations
            .ReadOrDefaultAsync<EnterpriseLearningReceiptIntent>(
                EnterpriseMetricDocumentIds.ReceiptIntent(
                    actor.OrganizationId,
                    sessionId,
                    sequence),
                new PartitionKey(actor.OrganizationId),
                cancellationToken);
        if (intent is null)
        {
            var cohortSubject = EnterpriseMetricDocumentIds.CohortSubject(
                actor.OrganizationId,
                actor.PersonId);
            var receiptShard = EnterpriseMetricDocumentIds.AggregateShard(cohortSubject);
            var partitionKey = EnterpriseMetricDocumentIds.ReceiptPartition(
                actor.OrganizationId,
                occurredAt,
                receiptShard);
            var receipt = await receipts.GetAsync(
                EnterpriseMetricDocumentIds.Receipt(
                    actor.OrganizationId,
                    sessionId,
                    sequence),
                partitionKey,
                cancellationToken);
            if (receipt is null)
            {
                return null;
            }
            var historicalHash = EnterpriseMetricDocumentIds.RequestHash(
                sessionId,
                operationId,
                sequence,
                occurredAt);
            if (!string.Equals(receipt.RequestHash, historicalHash, StringComparison.Ordinal))
            {
                throw new OrganizationIdempotencyConflictException();
            }
            return new EnterpriseLearningReplayResult(sessionId, receipt.AcceptedAt);
        }
        var requestHash = EnterpriseMetricDocumentIds.RequestHash(
            sessionId,
            operationId,
            sequence,
            occurredAt);
        if (!string.Equals(intent.RequestHash, requestHash, StringComparison.Ordinal))
        {
            throw new OrganizationIdempotencyConflictException();
        }
        return new EnterpriseLearningReplayResult(sessionId, intent.CreatedAt);
    }

    public async Task<EnterpriseLearningSessionLease> StartLeaseAsync(
        OrganizationMembership actor,
        EnterpriseLearningSessionLease candidate,
        DateTimeOffset acceptedAt,
        CancellationToken cancellationToken = default)
    {
        EnsureActor(actor, candidate.OrganizationId, OrganizationOperation.RecordEnterpriseMetrics);
        var partitionKey = new PartitionKey(candidate.OrganizationId);
        for (var attempt = 1; attempt <= MaximumWriteAttempts; attempt++)
        {
            var currentActor = await ReadCurrentActorAsync(
                actor,
                OrganizationOperation.RecordEnterpriseMetrics,
                cancellationToken);
            var existing = await context.Organizations
                .ReadOrDefaultAsync<EnterpriseLearningSessionLease>(
                    candidate.Id,
                    partitionKey,
                    cancellationToken);
            if (existing is not null
                && existing.LastHeartbeatAt.AddSeconds(
                    EnterpriseLearningMetricsPolicy.LeaseTtlSeconds) > acceptedAt)
            {
                throw new EnterpriseLearningLeaseConflictException();
            }
            var batch = context.Organizations.CreateTransactionalBatch(partitionKey)
                .ReplaceItem(
                    currentActor.Id,
                    currentActor,
                    new TransactionalBatchItemRequestOptions
                    {
                        IfMatchEtag = currentActor.ETag,
                    });
            if (existing is null)
            {
                batch.CreateItem(candidate);
            }
            else
            {
                batch.ReplaceItem(
                    candidate.Id,
                    candidate,
                    new TransactionalBatchItemRequestOptions
                    {
                        IfMatchEtag = existing.ETag,
                    });
            }
            using var response = await batch.ExecuteAsync(cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                return response.GetOperationResultAtIndex<EnterpriseLearningSessionLease>(1)
                    .Resource;
            }
            await HandleWriteConflictAsync(
                response,
                attempt,
                "Could not create the enterprise learning lease.",
                cancellationToken);
        }
        throw new ConcurrencyConflictException("Could not create the enterprise learning lease.");
    }

    public async Task<EnterpriseLearningSessionLease> GetLeaseAsync(
        OrganizationMembership actor,
        CancellationToken cancellationToken = default)
    {
        var currentActor = await ReadCurrentActorAsync(
            actor,
            OrganizationOperation.RecordEnterpriseMetrics,
            cancellationToken);
        var subject = EnterpriseMetricDocumentIds.Subject(
            actor.OrganizationId,
            actor.PersonId,
            actor.Cycle);
        var lease = await context.Organizations.ReadOrDefaultAsync<EnterpriseLearningSessionLease>(
            EnterpriseMetricDocumentIds.Lease(actor.OrganizationId, subject),
            new PartitionKey(actor.OrganizationId),
            cancellationToken)
            ?? throw new OrganizationNotFoundException();
        if (lease.MembershipCycle != currentActor.Cycle
            || !string.Equals(lease.MetricSubjectId, subject, StringComparison.Ordinal))
        {
            throw new OrganizationNotFoundException();
        }
        return lease;
    }

    public async Task<EnterpriseLearningMetricWriteResult> RecordHeartbeatAsync(
        OrganizationMembership actor,
        EnterpriseLearningSessionLease lease,
        EnterpriseLearningHeartbeat heartbeat,
        DateTimeOffset acceptedAt,
        CancellationToken cancellationToken = default)
    {
        EnsureActor(actor, heartbeat.OrganizationId, OrganizationOperation.RecordEnterpriseMetrics);
        var partitionKey = new PartitionKey(heartbeat.OrganizationId);
        for (var attempt = 1; attempt <= MaximumWriteAttempts; attempt++)
        {
            var currentActor = await ReadCurrentActorAsync(
                actor,
                OrganizationOperation.RecordEnterpriseMetrics,
                cancellationToken);
            var currentLease = await context.Organizations
                .ReadOrDefaultAsync<EnterpriseLearningSessionLease>(
                    lease.Id,
                    partitionKey,
                    cancellationToken)
                ?? throw new OrganizationNotFoundException();
            if (heartbeat.Sequence <= currentLease.LastSequence)
            {
                if (heartbeat.Sequence == currentLease.LastSequence
                    && string.Equals(
                        heartbeat.RequestHash,
                        currentLease.LastRequestHash,
                        StringComparison.Ordinal))
                {
                    return new EnterpriseLearningMetricWriteResult(
                        EnterpriseLearningMetricWriteStatus.Replayed,
                        currentLease);
                }
                var oldReceipt = await receipts.GetAsync(
                    heartbeat.ReceiptId,
                    heartbeat.ReceiptPartitionKey,
                    cancellationToken);
                if (oldReceipt is not null
                    && string.Equals(
                        oldReceipt.RequestHash,
                        heartbeat.RequestHash,
                        StringComparison.Ordinal))
                {
                    return new EnterpriseLearningMetricWriteResult(
                        EnterpriseLearningMetricWriteStatus.Replayed,
                        currentLease);
                }
                throw new OrganizationIdempotencyConflictException();
            }
            if (heartbeat.Sequence != currentLease.LastSequence + 1
                || !string.Equals(
                    currentLease.LeaseTokenHash,
                    lease.LeaseTokenHash,
                    StringComparison.Ordinal))
            {
                throw new EnterpriseLearningSequenceException();
            }

            var advancedLease = currentLease.Advance(heartbeat, acceptedAt);
            var day = DateOnly.FromDateTime(heartbeat.OccurredAt.UtcDateTime);
            var aggregateId = EnterpriseMetricDocumentIds.Aggregate(
                heartbeat.OrganizationId,
                day,
                heartbeat.AggregateShard);
            var existingAggregate = await context.Organizations
                .ReadOrDefaultAsync<EnterpriseLearningDailyAggregateShard>(
                    aggregateId,
                    partitionKey,
                    cancellationToken);
            var aggregate = EnterpriseLearningDailyAggregateShard.Apply(
                heartbeat,
                existingAggregate,
                acceptedAt);
            var activeBucket = EnterpriseMetricDocumentIds.ActiveBucket(acceptedAt);
            var activeId = EnterpriseMetricDocumentIds.Active(
                heartbeat.OrganizationId,
                activeBucket,
                heartbeat.AggregateShard);
            var existingActive = await context.Organizations
                .ReadOrDefaultAsync<EnterpriseLearningActiveSubjectShard>(
                    activeId,
                    partitionKey,
                    cancellationToken);
            var active = EnterpriseLearningActiveSubjectShard.Apply(
                heartbeat,
                existingActive,
                acceptedAt);
            var intent = EnterpriseLearningReceiptIntent.From(heartbeat, acceptedAt);
            var batch = context.Organizations.CreateTransactionalBatch(partitionKey)
                .ReplaceItem(
                    currentActor.Id,
                    currentActor,
                    new TransactionalBatchItemRequestOptions
                    {
                        IfMatchEtag = currentActor.ETag,
                    })
                .ReplaceItem(
                    advancedLease.Id,
                    advancedLease,
                    new TransactionalBatchItemRequestOptions
                    {
                        IfMatchEtag = currentLease.ETag,
                    });
            AddUpsert(batch, aggregate.Id, aggregate, existingAggregate?.ETag);
            AddUpsert(batch, active.Id, active, existingActive?.ETag);
            batch.CreateItem(intent);

            using var response = await batch.ExecuteAsync(cancellationToken);
            if (response.IsSuccessStatusCode)
            {
                var storedLease = response
                    .GetOperationResultAtIndex<EnterpriseLearningSessionLease>(1)
                    .Resource;
                return new EnterpriseLearningMetricWriteResult(
                    EnterpriseLearningMetricWriteStatus.Created,
                    storedLease);
            }

            await HandleWriteConflictAsync(
                response,
                attempt,
                "Could not record enterprise learning metrics.",
                cancellationToken);
        }
        throw new ConcurrencyConflictException(
            "Enterprise metrics changed concurrently; retry the heartbeat.");
    }

    public async Task<IReadOnlyList<EnterpriseLearningReceiptIntent>> ListClaimableAsync(
            int maximumIntents,
            DateTimeOffset now,
            CancellationToken cancellationToken = default)
        {
            var query = new QueryDefinition(
                    "SELECT TOP @maximum * FROM c WHERE c.documentType = @type "
                    + "AND (c.state = @pending OR "
                    + "(c.state = @processing AND c.processingLeaseUntil <= @now))")
                .WithParameter("@maximum", maximumIntents)
                .WithParameter("@type", EnterpriseLearningReceiptIntent.Type)
                .WithParameter("@pending", "pending")
                .WithParameter("@processing", "processing")
                .WithParameter("@now", now);
            using var iterator = context.Organizations
                .GetItemQueryIterator<EnterpriseLearningReceiptIntent>(
                    query,
                    requestOptions: new QueryRequestOptions { MaxItemCount = maximumIntents });
            return iterator.HasMoreResults
                ? (await iterator.ReadNextAsync(cancellationToken)).ToArray()
                : [];
        }

    public async Task<EnterpriseLearningReceiptIntent?> ClaimAsync(
            EnterpriseLearningReceiptIntent intent,
            string owner,
            DateTimeOffset now,
            TimeSpan lease,
            CancellationToken cancellationToken = default)
        {
            var claimed = intent.Claim(owner, now, lease);
            if (claimed.State is EnterpriseLearningReceiptIntentState.Completed
                or EnterpriseLearningReceiptIntentState.SkippedRevoked)
            {
                return null;
            }
            try
            {
                var response = await context.Organizations.ReplaceItemAsync(
                    claimed,
                    claimed.Id,
                    new PartitionKey(claimed.OrganizationId),
                    new ItemRequestOptions { IfMatchEtag = intent.ETag },
                    cancellationToken);
                return response.Resource;
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                return null;
            }
        }

    public async Task<bool> IsSubjectDrainedAsync(
            string organizationId,
            string metricSubjectId,
            CancellationToken cancellationToken = default)
        {
            var query = new QueryDefinition(
                    "SELECT VALUE COUNT(1) FROM c WHERE c.documentType = @type "
                    + "AND c.metricSubjectId = @subject "
                    + "AND (c.state = @pending OR c.state = @processing)")
                .WithParameter("@type", EnterpriseLearningReceiptIntent.Type)
                .WithParameter("@subject", metricSubjectId)
                .WithParameter("@pending", "pending")
                .WithParameter("@processing", "processing");
            using var iterator = context.Organizations.GetItemQueryIterator<long>(
                query,
                requestOptions: new QueryRequestOptions
                {
                    PartitionKey = new PartitionKey(organizationId),
                    MaxItemCount = 1,
                });
            return !iterator.HasMoreResults
                || (await iterator.ReadNextAsync(cancellationToken)).Single() == 0;
        }

    public async Task<bool> IsSubjectRevokedAsync(
            string organizationId,
            string metricSubjectId,
            CancellationToken cancellationToken = default)
        {
            var query = new QueryDefinition(
                    "SELECT TOP 1 VALUE c.id FROM c WHERE c.documentType = @type "
                    + "AND c.metricSubjectId = @subject")
                .WithParameter("@type", OrganizationOffboardingTombstone.Type)
                .WithParameter("@subject", metricSubjectId);
            using var iterator = context.Organizations.GetItemQueryIterator<string>(
                query,
                requestOptions: new QueryRequestOptions
                {
                    PartitionKey = new PartitionKey(organizationId),
                    MaxItemCount = 1,
                });
            return iterator.HasMoreResults
                && (await iterator.ReadNextAsync(cancellationToken)).Any();
        }

    public async Task CompleteAsync(
            EnterpriseLearningReceiptIntent intent,
            string owner,
            DateTimeOffset now,
            bool skippedRevoked,
            CancellationToken cancellationToken = default)
        {
            var completed = intent.Complete(owner, now, skippedRevoked);
            try
            {
                await context.Organizations.ReplaceItemAsync(
                    completed,
                    completed.Id,
                    new PartitionKey(completed.OrganizationId),
                    new ItemRequestOptions { IfMatchEtag = intent.ETag },
                    cancellationToken);
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.PreconditionFailed)
            {
                // A reclaimed processing lease owns completion; continue this bounded batch.
            }
        }
    public async Task<EnterpriseLearningDailySummary> GetDailySummaryAsync(
        OrganizationMembership actor,
        DateOnly day,
        CancellationToken cancellationToken = default)
    {
        var currentActor = await ReadCurrentActorAsync(
            actor,
            OrganizationOperation.ViewEnterpriseMetrics,
            cancellationToken);
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.documentType = @type AND c.day = @day")
            .WithParameter("@type", EnterpriseLearningDailyAggregateShard.Type)
            .WithParameter("@day", day.ToString("yyyy-MM-dd"));
        var aggregates = await ReadBoundedAsync<EnterpriseLearningDailyAggregateShard>(
            query,
            new PartitionKey(actor.OrganizationId),
            EnterpriseLearningMetricsPolicy.MaximumDailySummaryDocuments,
            cancellationToken);
        var contributors = EnterpriseLearningDailyAggregateShard.CountContributors(
            aggregates.Select(item => item.ContributorBitmap));
        var suppressed = contributors < EnterpriseLearningMetricsPolicy.MinimumContributors;
        await VerifyActorUnchangedAsync(currentActor, cancellationToken);
        return new EnterpriseLearningDailySummary(
            actor.OrganizationId,
            day,
            suppressed,
            contributors,
            suppressed ? 0 : aggregates.Sum(item => item.LearningSeconds),
            suppressed ? 0 : aggregates.Sum(item => item.ProgressBasisPoints),
            suppressed ? 0 : aggregates.Sum(item => item.CompletionCount),
            suppressed ? 0 : aggregates.Sum(item => item.ReadinessBasisPoints),
            suppressed ? 0 : aggregates.Sum(item => item.ReadinessSampleCount),
            suppressed ? 0 : aggregates.Sum(item => item.HeartbeatCount));
    }

    public async Task<EnterpriseLearningActiveSummary> GetActiveSummaryAsync(
        OrganizationMembership actor,
        DateTimeOffset bucketStartedAt,
        CancellationToken cancellationToken = default)
    {
        var currentActor = await ReadCurrentActorAsync(
            actor,
            OrganizationOperation.ViewEnterpriseMetrics,
            cancellationToken);
        var query = new QueryDefinition(
                "SELECT * FROM c WHERE c.documentType = @type AND c.bucketStartedAt = @bucket")
            .WithParameter("@type", EnterpriseLearningActiveSubjectShard.Type)
            .WithParameter("@bucket", bucketStartedAt);
        var shards = await ReadBoundedAsync<EnterpriseLearningActiveSubjectShard>(
            query,
            new PartitionKey(actor.OrganizationId),
            EnterpriseLearningMetricsPolicy.MaximumActiveSummaryDocuments,
            cancellationToken);
        var contributors = EnterpriseLearningDailyAggregateShard.CountContributors(
            shards.Select(item => item.ContributorBitmap));
        await VerifyActorUnchangedAsync(currentActor, cancellationToken);
        return new EnterpriseLearningActiveSummary(
            actor.OrganizationId,
            bucketStartedAt,
            contributors < EnterpriseLearningMetricsPolicy.MinimumContributors,
            contributors);
    }

    private static void AddUpsert<T>(
        TransactionalBatch batch,
        string id,
        T value,
        string? etag)
    {
        if (etag is null)
        {
            batch.CreateItem(value);
        }
        else
        {
            batch.ReplaceItem(
                id,
                value,
                new TransactionalBatchItemRequestOptions { IfMatchEtag = etag });
        }
    }

    private async Task HandleWriteConflictAsync(
        TransactionalBatchResponse response,
        int attempt,
        string message,
        CancellationToken cancellationToken)
    {
        if (response.StatusCode is HttpStatusCode.Conflict
            or HttpStatusCode.PreconditionFailed
            or HttpStatusCode.NotFound)
        {
            if (attempt < MaximumWriteAttempts)
            {
                await BackoffAsync(attempt, null, cancellationToken);
                return;
            }
            throw new ConcurrencyConflictException(message);
        }
        throw CreateBatchException(message, response);
    }

    private async Task<IReadOnlyList<T>> ReadBoundedAsync<T>(
        QueryDefinition query,
        PartitionKey partitionKey,
        int maximumDocuments,
        CancellationToken cancellationToken)
    {
        using var iterator = context.Organizations.GetItemQueryIterator<T>(
            query,
            requestOptions: new QueryRequestOptions
            {
                PartitionKey = partitionKey,
                MaxItemCount = QueryPageSize,
            });
        var results = new List<T>();
        var throttleAttempts = 0;
        while (iterator.HasMoreResults)
        {
            try
            {
                results.AddRange(await iterator.ReadNextAsync(cancellationToken));
                throttleAttempts = 0;
            }
            catch (CosmosException ex) when (
                ex.StatusCode == HttpStatusCode.TooManyRequests
                && throttleAttempts < MaximumReadThrottleRetries)
            {
                throttleAttempts++;
                await BackoffAsync(throttleAttempts, ex.RetryAfter, cancellationToken);
            }
            if (results.Count > maximumDocuments)
            {
                throw new ConcurrencyConflictException(
                    "Enterprise metrics consolidation exceeded its bounded read budget.");
            }
        }
        return results;
    }

    private async Task<OrganizationMembership> ReadCurrentActorAsync(
        OrganizationMembership actor,
        OrganizationOperation operation,
        CancellationToken cancellationToken)
    {
        var current = await context.Organizations.ReadOrDefaultAsync<OrganizationMembership>(
            actor.Id,
            new PartitionKey(actor.OrganizationId),
            cancellationToken)
            ?? throw new OrganizationMembershipNotFoundException();
        EnsureActor(current, actor.OrganizationId, operation);
        return current;
    }

    private async Task VerifyActorUnchangedAsync(
        OrganizationMembership actor,
        CancellationToken cancellationToken)
    {
        var verified = await ReadCurrentActorAsync(
            actor,
            OrganizationOperation.ViewEnterpriseMetrics,
            cancellationToken);
        if (!string.Equals(verified.ETag, actor.ETag, StringComparison.Ordinal))
        {
            throw new ConcurrencyConflictException(
                "The organization membership changed while metrics were read.");
        }
    }

    private static void EnsureActor(
        OrganizationMembership actor,
        string organizationId,
        OrganizationOperation operation)
    {
        if (!string.Equals(actor.OrganizationId, organizationId, StringComparison.Ordinal)
            || string.IsNullOrWhiteSpace(actor.ETag))
        {
            throw new OrganizationMembershipNotFoundException();
        }
        if (!OrganizationAuthorization.CanPerform(actor.Role, operation))
        {
            throw new OrganizationAccessDeniedException();
        }
    }

    private static Task BackoffAsync(
        int attempt,
        TimeSpan? retryAfter,
        CancellationToken cancellationToken)
    {
        var exponential = TimeSpan.FromMilliseconds(Math.Min(1_000, 25 * (1 << attempt)));
        var delay = retryAfter is { } serverDelay && serverDelay > exponential
            ? serverDelay
            : exponential;
        return Task.Delay(delay, cancellationToken);
    }

    private static CosmosException CreateBatchException(
        string message,
        TransactionalBatchResponse response) =>
        new(
            message,
            response.StatusCode,
            0,
            response.ActivityId,
            response.RequestCharge);
}
