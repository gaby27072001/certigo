using System.Security.Cryptography;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Organizations;

namespace Certigo.Application.Services;

public sealed class CryptographicEnterpriseLearningLeaseGenerator
    : IEnterpriseLearningLeaseGenerator
{
    public string NewSessionId() => NewOpaqueValue();
    public string NewLeaseToken() => NewOpaqueValue();

    private static string NewOpaqueValue() =>
        Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
}

public sealed class UnavailableEnterpriseLearningFactSource : IEnterpriseLearningFactSource
{
    public Task<EnterpriseLearningFact> GetDeltaAsync(
        string organizationId,
        string personId,
        DateTimeOffset fromExclusive,
        DateTimeOffset toInclusive,
        CancellationToken cancellationToken = default) =>
        throw new InvalidOperationException(
            "No authoritative enterprise learning fact source is wired while the feature is off.");
}

public sealed class EnterpriseLearningMetricsService(
    IOrganizationAuthorizationHandler authorization,
    IEnterpriseLearningMetricsRepository metrics,
    IEnterpriseLearningFactSource facts,
    IEnterpriseLearningLeaseGenerator leaseGenerator,
    IClock clock) : IEnterpriseLearningMetricsService
{
    public async Task<EnterpriseLearningSessionDto> StartSessionAsync(
        string organizationId,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.RecordEnterpriseMetrics,
            cancellationToken: cancellationToken);
        var now = clock.UtcNow;
        var token = leaseGenerator.NewLeaseToken();
        var candidate = EnterpriseLearningSessionLease.Create(
            context.Membership,
            leaseGenerator.NewSessionId(),
            token,
            now);
        var lease = await metrics.StartLeaseAsync(
            context.Membership,
            candidate,
            now,
            cancellationToken);
        return new EnterpriseLearningSessionDto(
            lease.SessionId,
            token,
            now.AddSeconds(EnterpriseLearningMetricsPolicy.LeaseTtlSeconds));
    }

    public async Task<EnterpriseLearningHeartbeatDto> RecordHeartbeatAsync(
        string organizationId,
        EnterpriseLearningHeartbeatRequest request,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.RecordEnterpriseMetrics,
            cancellationToken: cancellationToken);
        var replay = await metrics.GetReplayAsync(
            context.Membership,
            request.SessionId,
            request.Sequence,
            request.OperationId,
            request.OccurredAt,
            cancellationToken);
        if (replay is not null)
        {
            return new EnterpriseLearningHeartbeatDto(
                replay.SessionId,
                replay.AcceptedAt,
                Replayed: true);
        }
        var lease = await metrics.GetLeaseAsync(context.Membership, cancellationToken);
        if (!string.Equals(lease.SessionId, request.SessionId, StringComparison.Ordinal))
        {
            throw new OrganizationNotFoundException();
        }
        var now = clock.UtcNow;
        _ = lease.ValidateHeartbeatRequest(
            request.LeaseToken,
            request.Sequence,
            request.OperationId,
            request.OccurredAt,
            now);
        var fact = await facts.GetDeltaAsync(
            organizationId,
            context.PersonId,
            lease.FactWatermark,
            request.OccurredAt,
            cancellationToken);
        var heartbeat = lease.PrepareHeartbeat(
            request.LeaseToken,
            request.Sequence,
            request.OperationId,
            request.OccurredAt,
            fact,
            now);
        var result = await metrics.RecordHeartbeatAsync(
            context.Membership,
            lease,
            heartbeat,
            now,
            cancellationToken);
        return new EnterpriseLearningHeartbeatDto(
            result.Lease.SessionId,
            result.Lease.LastHeartbeatAt,
            result.Status == EnterpriseLearningMetricWriteStatus.Replayed);
    }

    public async Task<EnterpriseLearningDailySummaryDto> GetDailySummaryAsync(
        string organizationId,
        DateOnly day,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ViewEnterpriseMetrics,
            cancellationToken: cancellationToken);
        var result = await metrics.GetDailySummaryAsync(
            context.Membership,
            day,
            cancellationToken);
        return new EnterpriseLearningDailySummaryDto(
            result.OrganizationId,
            result.Day,
            result.Suppressed,
            result.LearningSeconds,
            result.ProgressBasisPoints,
            result.CompletionCount,
            result.ReadinessSampleCount == 0
                ? null
                : result.ReadinessBasisPoints / (double)result.ReadinessSampleCount / 100d,
            result.HeartbeatCount);
    }

    public async Task<EnterpriseLearningActiveSummaryDto> GetActiveSummaryAsync(
        string organizationId,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ViewEnterpriseMetrics,
            cancellationToken: cancellationToken);
        var bucket = EnterpriseMetricDocumentIds.ActiveBucket(clock.UtcNow);
        var result = await metrics.GetActiveSummaryAsync(
            context.Membership,
            bucket,
            cancellationToken);
        return new EnterpriseLearningActiveSummaryDto(
            result.OrganizationId,
            result.BucketStartedAt,
            result.Suppressed,
            result.Suppressed ? 0 : result.ActiveContributorCountLowerBound);
    }
}
