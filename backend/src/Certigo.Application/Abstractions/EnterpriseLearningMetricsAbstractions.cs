using Certigo.Application.Dtos;
using Certigo.Domain.Organizations;

namespace Certigo.Application.Abstractions;

public enum EnterpriseLearningMetricsFeatureMode
{
    Off,
}

public sealed record EnterpriseLearningMetricsFeatureOptions(
    EnterpriseLearningMetricsFeatureMode Mode)
{
    public static EnterpriseLearningMetricsFeatureOptions Parse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)
            || string.Equals(value.Trim(), "off", StringComparison.OrdinalIgnoreCase))
        {
            return new EnterpriseLearningMetricsFeatureOptions(
                EnterpriseLearningMetricsFeatureMode.Off);
        }
        throw new InvalidOperationException(
            "ENTERPRISE_LEARNING_METRICS_V1 only supports 'off' in this contract increment.");
    }
}

public enum EnterpriseLearningMetricWriteStatus
{
    Created,
    Replayed,
}

public sealed record EnterpriseLearningMetricWriteResult(
    EnterpriseLearningMetricWriteStatus Status,
    EnterpriseLearningSessionLease Lease);

public sealed record EnterpriseLearningReplayResult(
    string SessionId,
    DateTimeOffset AcceptedAt);

public sealed record EnterpriseLearningDailySummary(
    string OrganizationId,
    DateOnly Day,
    bool Suppressed,
    int ContributorCountLowerBound,
    long LearningSeconds,
    long ProgressBasisPoints,
    long CompletionCount,
    long ReadinessBasisPoints,
    long ReadinessSampleCount,
    long HeartbeatCount);

public sealed record EnterpriseLearningActiveSummary(
    string OrganizationId,
    DateTimeOffset BucketStartedAt,
    bool Suppressed,
    int ActiveContributorCountLowerBound);

public interface IEnterpriseLearningMetricsRepository
{
    Task<EnterpriseLearningReplayResult?> GetReplayAsync(
        OrganizationMembership actor,
        string sessionId,
        long sequence,
        string operationId,
        DateTimeOffset occurredAt,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningSessionLease> StartLeaseAsync(
        OrganizationMembership actor,
        EnterpriseLearningSessionLease candidate,
        DateTimeOffset acceptedAt,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningSessionLease> GetLeaseAsync(
        OrganizationMembership actor,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningMetricWriteResult> RecordHeartbeatAsync(
        OrganizationMembership actor,
        EnterpriseLearningSessionLease lease,
        EnterpriseLearningHeartbeat heartbeat,
        DateTimeOffset acceptedAt,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningDailySummary> GetDailySummaryAsync(
        OrganizationMembership actor,
        DateOnly day,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningActiveSummary> GetActiveSummaryAsync(
        OrganizationMembership actor,
        DateTimeOffset bucketStartedAt,
        CancellationToken cancellationToken = default);
}

public interface IEnterpriseLearningMetricReceiptRepository
{
    Task<EnterpriseLearningMetricReceipt?> GetAsync(
        string id,
        string partitionKey,
        CancellationToken cancellationToken = default);

    Task CreateOrVerifyAsync(
        EnterpriseLearningMetricReceipt receipt,
        CancellationToken cancellationToken = default);

    Task PurgeSubjectPartitionsAsync(
        IReadOnlyList<string> partitionKeys,
        string metricSubjectId,
        CancellationToken cancellationToken = default);
}

public interface IEnterpriseLearningReceiptOutboxRepository
{
    Task<IReadOnlyList<EnterpriseLearningReceiptIntent>> ListClaimableAsync(
        int maximumIntents,
        DateTimeOffset now,
        CancellationToken cancellationToken = default);
    Task<EnterpriseLearningReceiptIntent?> ClaimAsync(
        EnterpriseLearningReceiptIntent intent,
        string owner,
        DateTimeOffset now,
        TimeSpan lease,
        CancellationToken cancellationToken = default);
    Task<bool> IsSubjectDrainedAsync(
        string organizationId,
        string metricSubjectId,
        CancellationToken cancellationToken = default);
    Task<bool> IsSubjectRevokedAsync(
        string organizationId,
        string metricSubjectId,
        CancellationToken cancellationToken = default);
    Task CompleteAsync(
        EnterpriseLearningReceiptIntent intent,
        string owner,
        DateTimeOffset now,
        bool skippedRevoked,
        CancellationToken cancellationToken = default);
}

public interface IEnterpriseLearningReceiptOutboxWorker
{
    Task<int> RunBatchAsync(
        int maximumIntents,
        CancellationToken cancellationToken = default);
}

public interface IEnterpriseLearningFactSource
{
    Task<EnterpriseLearningFact> GetDeltaAsync(
        string organizationId,
        string personId,
        DateTimeOffset fromExclusive,
        DateTimeOffset toInclusive,
        CancellationToken cancellationToken = default);
}

public interface IEnterpriseLearningLeaseGenerator
{
    string NewSessionId();
    string NewLeaseToken();
}

public interface IEnterpriseLearningMetricsService
{
    Task<EnterpriseLearningSessionDto> StartSessionAsync(
        string organizationId,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningHeartbeatDto> RecordHeartbeatAsync(
        string organizationId,
        EnterpriseLearningHeartbeatRequest request,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningDailySummaryDto> GetDailySummaryAsync(
        string organizationId,
        DateOnly day,
        CancellationToken cancellationToken = default);

    Task<EnterpriseLearningActiveSummaryDto> GetActiveSummaryAsync(
        string organizationId,
        CancellationToken cancellationToken = default);
}

public interface IOrganizationOffboardingRecoveryWorker
{
    Task<int> RunBatchAsync(
        int maximumTombstones,
        CancellationToken cancellationToken = default);
}

public sealed class EnterpriseLearningMetricsFeatureDisabledException()
    : Exception("The enterprise learning metrics V1 surface is disabled.");
