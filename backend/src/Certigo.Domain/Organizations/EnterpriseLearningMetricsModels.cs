using System.Globalization;
using System.Numerics;
using System.Security.Cryptography;
using System.Text.Json.Serialization;

namespace Certigo.Domain.Organizations;

public static class EnterpriseLearningMetricsPolicy
{
    public const int ActiveWindowSeconds = 300;
    public const int MaximumHeartbeatGapSeconds = 900;
    public const int LeaseTtlSeconds = 3_600;
    public const int ReplayReceiptTtlSeconds = 2_592_000;
    public const int AggregateRetentionDays = 400;
    public const int AggregateShardCount = 128;
    public const int ContributorBitmapBits = 2_048;
    public const int MinimumContributors = 5;
    public const int MaximumDailySummaryDocuments = 128;
    public const int MaximumActiveSummaryDocuments = 128;
    public static readonly TimeSpan MaximumOfflineAge = TimeSpan.FromDays(30);
}

public sealed record EnterpriseLearningFact(
    int LearningSeconds,
    int ProgressBasisPoints,
    int CompletionCount,
    int? ReadinessBasisPoints)
{
    public static EnterpriseLearningFact Create(
        int learningSeconds,
        int progressBasisPoints,
        int completionCount,
        int? readinessBasisPoints)
    {
        if (learningSeconds is < 0 or > EnterpriseLearningMetricsPolicy.MaximumHeartbeatGapSeconds
            || progressBasisPoints is < 0 or > 10_000
            || completionCount is < 0 or > 100
            || readinessBasisPoints is < 0 or > 10_000)
        {
            throw new OrganizationValidationException(
                "The authoritative learning fact is outside its bounded contract.");
        }
        return new EnterpriseLearningFact(
            learningSeconds,
            progressBasisPoints,
            completionCount,
            readinessBasisPoints);
    }
}

public sealed record EnterpriseLearningSessionLease(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string MetricSubjectId,
    string MetricCohortSubjectId,
    string SessionId,
    string LeaseTokenHash,
    int MembershipCycle,
    DateTimeOffset StartedAt,
    DateTimeOffset LastOccurredAt,
    DateTimeOffset LastHeartbeatAt,
    long LastSequence,
    string? LastRequestHash,
    DateTimeOffset FactWatermark,
    int Ttl)
{
    public const int CurrentSchemaVersion = 3;
    public const string Type = "enterpriseLearningSessionLease";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static EnterpriseLearningSessionLease Create(
        OrganizationMembership membership,
        string sessionId,
        string leaseToken,
        DateTimeOffset createdAt)
    {
        EnsureOpaqueValue(sessionId, nameof(sessionId));
        EnsureOpaqueValue(leaseToken, nameof(leaseToken));
        var subject = EnterpriseMetricDocumentIds.Subject(
            membership.OrganizationId,
            membership.PersonId,
            membership.Cycle);
        var cohortSubject = EnterpriseMetricDocumentIds.CohortSubject(
            membership.OrganizationId,
            membership.PersonId);
        return new EnterpriseLearningSessionLease(
            EnterpriseMetricDocumentIds.Lease(membership.OrganizationId, subject),
            membership.OrganizationId,
            CurrentSchemaVersion,
            Type,
            subject,
            cohortSubject,
            sessionId,
            HashLeaseToken(leaseToken),
            membership.Cycle,
            createdAt,
            createdAt,
            createdAt,
            0,
            null,
            createdAt,
            EnterpriseLearningMetricsPolicy.LeaseTtlSeconds);
    }

    public EnterpriseLearningHeartbeat PrepareHeartbeat(
        string leaseToken,
        long sequence,
        string operationId,
        DateTimeOffset occurredAt,
        EnterpriseLearningFact fact,
        DateTimeOffset acceptedAt)
    {
        var requestHash = ValidateHeartbeatRequest(
            leaseToken,
            sequence,
            operationId,
            occurredAt,
            acceptedAt);
        if (sequence == LastSequence)
        {
            return CreateHeartbeat(sequence, requestHash, occurredAt, fact);
        }
        var elapsedSeconds = (occurredAt - LastOccurredAt).TotalSeconds;
        if (fact.LearningSeconds > Math.Floor(elapsedSeconds))
        {
            throw new EnterpriseLearningSequenceException();
        }
        return CreateHeartbeat(sequence, requestHash, occurredAt, fact);
    }

    public string ValidateHeartbeatRequest(
        string leaseToken,
        long sequence,
        string operationId,
        DateTimeOffset occurredAt,
        DateTimeOffset acceptedAt)
    {
        EnsureOpaqueValue(leaseToken, nameof(leaseToken));
        EnsureOpaqueValue(operationId, nameof(operationId));
        var presented = Convert.FromHexString(HashLeaseToken(leaseToken));
        if (!CryptographicOperations.FixedTimeEquals(
                presented,
                Convert.FromHexString(LeaseTokenHash)))
        {
            throw new OrganizationAccessDeniedException();
        }
        if (occurredAt < acceptedAt.Subtract(EnterpriseLearningMetricsPolicy.MaximumOfflineAge)
            || occurredAt > acceptedAt.AddMinutes(5))
        {
            throw new EnterpriseLearningSequenceException();
        }
        var requestHash = EnterpriseMetricDocumentIds.RequestHash(
            SessionId,
            operationId,
            sequence,
            occurredAt);
        if (sequence == LastSequence
            && string.Equals(requestHash, LastRequestHash, StringComparison.Ordinal))
        {
            return requestHash;
        }
        if (sequence != LastSequence + 1 || occurredAt <= LastOccurredAt)
        {
            throw new EnterpriseLearningSequenceException();
        }
        var elapsedSeconds = (occurredAt - LastOccurredAt).TotalSeconds;
        if (elapsedSeconds > EnterpriseLearningMetricsPolicy.MaximumHeartbeatGapSeconds)
        {
            throw new EnterpriseLearningSequenceException();
        }
        return requestHash;
    }

    private EnterpriseLearningHeartbeat CreateHeartbeat(
        long sequence,
        string requestHash,
        DateTimeOffset occurredAt,
        EnterpriseLearningFact fact)
    {
        var shard = EnterpriseMetricDocumentIds.AggregateShard(MetricCohortSubjectId);
        return new EnterpriseLearningHeartbeat(
            OrganizationId,
            MetricSubjectId,
            MetricCohortSubjectId,
            SessionId,
            EnterpriseMetricDocumentIds.Receipt(OrganizationId, SessionId, sequence),
            EnterpriseMetricDocumentIds.ReceiptPartition(
                OrganizationId,
                occurredAt,
                shard),
            sequence,
            requestHash,
            occurredAt.ToUniversalTime(),
            fact,
            shard);
    }

    public EnterpriseLearningSessionLease Advance(
        EnterpriseLearningHeartbeat heartbeat,
        DateTimeOffset acceptedAt)
    {
        if (!string.Equals(heartbeat.SessionId, SessionId, StringComparison.Ordinal)
            || heartbeat.Sequence != LastSequence + 1)
        {
            throw new EnterpriseLearningSequenceException();
        }
        return this with
        {
            LastOccurredAt = heartbeat.OccurredAt,
            LastHeartbeatAt = acceptedAt,
            LastSequence = heartbeat.Sequence,
            LastRequestHash = heartbeat.RequestHash,
            FactWatermark = heartbeat.OccurredAt,
            Ttl = EnterpriseLearningMetricsPolicy.LeaseTtlSeconds,
        };
    }

    private static string HashLeaseToken(string leaseToken) =>
        OrganizationDocumentIds.Hash("certigo-enterprise-metric-lease-token:v1", leaseToken);

    private static void EnsureOpaqueValue(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value)
            || value.Length is < 16 or > 200
            || value != value.Trim()
            || value.Any(char.IsControl))
        {
            throw new OrganizationValidationException(
                $"{parameterName} must contain between 16 and 200 safe characters.");
        }
    }
}

public sealed record EnterpriseLearningHeartbeat(
    string OrganizationId,
    string MetricSubjectId,
    string MetricCohortSubjectId,
    string SessionId,
    string ReceiptId,
    string ReceiptPartitionKey,
    long Sequence,
    string RequestHash,
    DateTimeOffset OccurredAt,
    EnterpriseLearningFact Fact,
    int AggregateShard);

public sealed record EnterpriseLearningMetricReceipt(
    string Id,
    string PartitionKey,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string MetricSubjectId,
    string SessionId,
    long Sequence,
    string RequestHash,
    DateTimeOffset AcceptedAt,
    int Ttl)
{
    public const int CurrentSchemaVersion = 3;
    public const string Type = "enterpriseLearningMetricReceipt";

    public static EnterpriseLearningMetricReceipt From(
        EnterpriseLearningHeartbeat heartbeat,
        DateTimeOffset acceptedAt) =>
        new(
            heartbeat.ReceiptId,
            heartbeat.ReceiptPartitionKey,
            heartbeat.OrganizationId,
            CurrentSchemaVersion,
            Type,
            heartbeat.MetricSubjectId,
            heartbeat.SessionId,
            heartbeat.Sequence,
            heartbeat.RequestHash,
            acceptedAt,
            EnterpriseLearningMetricsPolicy.ReplayReceiptTtlSeconds);
}

public enum EnterpriseLearningReceiptIntentState
{
    Pending,
    Processing,
    Completed,
    SkippedRevoked,
}

public sealed record EnterpriseLearningReceiptIntent(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string MetricSubjectId,
    string SessionId,
    long Sequence,
    string RequestHash,
    EnterpriseLearningMetricReceipt Receipt,
    EnterpriseLearningReceiptIntentState State,
    string? ProcessingOwner,
    DateTimeOffset? ProcessingLeaseUntil,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    int Ttl)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "enterpriseLearningReceiptIntent";
    public const int CompletedTtlSeconds = 3_600;

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static EnterpriseLearningReceiptIntent From(
        EnterpriseLearningHeartbeat heartbeat,
        DateTimeOffset acceptedAt) =>
        new(
            EnterpriseMetricDocumentIds.ReceiptIntent(
                heartbeat.OrganizationId,
                heartbeat.SessionId,
                heartbeat.Sequence),
            heartbeat.OrganizationId,
            CurrentSchemaVersion,
            Type,
            heartbeat.MetricSubjectId,
            heartbeat.SessionId,
            heartbeat.Sequence,
            heartbeat.RequestHash,
            EnterpriseLearningMetricReceipt.From(heartbeat, acceptedAt),
            EnterpriseLearningReceiptIntentState.Pending,
            null,
            null,
            acceptedAt,
            acceptedAt,
            -1);

    public EnterpriseLearningReceiptIntent Claim(
        string owner,
        DateTimeOffset now,
        TimeSpan lease)
    {
        if (State == EnterpriseLearningReceiptIntentState.Processing
            && ProcessingLeaseUntil > now)
        {
            throw new EnterpriseLearningIntentLeaseException();
        }
        if (State is EnterpriseLearningReceiptIntentState.Completed
            or EnterpriseLearningReceiptIntentState.SkippedRevoked)
        {
            return this;
        }
        return this with
        {
            State = EnterpriseLearningReceiptIntentState.Processing,
            ProcessingOwner = owner,
            ProcessingLeaseUntil = now.Add(lease),
            UpdatedAt = now,
        };
    }

    public EnterpriseLearningReceiptIntent Complete(
        string owner,
        DateTimeOffset now,
        bool skippedRevoked)
    {
        if (State != EnterpriseLearningReceiptIntentState.Processing
            || !string.Equals(ProcessingOwner, owner, StringComparison.Ordinal))
        {
            throw new EnterpriseLearningIntentLeaseException();
        }
        return this with
        {
            State = skippedRevoked
                ? EnterpriseLearningReceiptIntentState.SkippedRevoked
                : EnterpriseLearningReceiptIntentState.Completed,
            ProcessingOwner = null,
            ProcessingLeaseUntil = null,
            UpdatedAt = now,
            Ttl = CompletedTtlSeconds,
        };
    }
}

public sealed record EnterpriseLearningDailyAggregateShard(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    DateOnly Day,
    int Shard,
    string ContributorBitmap,
    long LearningSeconds,
    long ProgressBasisPoints,
    long CompletionCount,
    long ReadinessBasisPoints,
    long ReadinessSampleCount,
    long HeartbeatCount,
    DateTimeOffset UpdatedAt,
    int Ttl)
{
    public const int CurrentSchemaVersion = 3;
    public const string Type = "enterpriseLearningDailyAggregateShard";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static EnterpriseLearningDailyAggregateShard Apply(
        EnterpriseLearningHeartbeat heartbeat,
        EnterpriseLearningDailyAggregateShard? current,
        DateTimeOffset acceptedAt)
    {
        var day = DateOnly.FromDateTime(heartbeat.OccurredAt.UtcDateTime);
        var bitmap = ReadOrCreateBitmap(
            current?.ContributorBitmap,
            heartbeat.MetricCohortSubjectId);
        var cutoff = day.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc)
            .AddDays(EnterpriseLearningMetricsPolicy.AggregateRetentionDays + 1);
        var remainingTtl = Math.Max(
            1,
            checked((int)Math.Ceiling((cutoff - acceptedAt.UtcDateTime).TotalSeconds)));
        return new EnterpriseLearningDailyAggregateShard(
            EnterpriseMetricDocumentIds.Aggregate(
                heartbeat.OrganizationId,
                day,
                heartbeat.AggregateShard),
            heartbeat.OrganizationId,
            CurrentSchemaVersion,
            Type,
            day,
            heartbeat.AggregateShard,
            bitmap,
            checked((current?.LearningSeconds ?? 0) + heartbeat.Fact.LearningSeconds),
            checked((current?.ProgressBasisPoints ?? 0) + heartbeat.Fact.ProgressBasisPoints),
            checked((current?.CompletionCount ?? 0) + heartbeat.Fact.CompletionCount),
            checked((current?.ReadinessBasisPoints ?? 0)
                + (heartbeat.Fact.ReadinessBasisPoints ?? 0)),
            checked((current?.ReadinessSampleCount ?? 0)
                + (heartbeat.Fact.ReadinessBasisPoints.HasValue ? 1 : 0)),
            checked((current?.HeartbeatCount ?? 0) + 1),
            acceptedAt,
            remainingTtl);
    }

    internal static string ReadOrCreateBitmap(string? current, string metricSubjectId)
    {
        var bitmap = current is null
            ? new byte[EnterpriseLearningMetricsPolicy.ContributorBitmapBits / 8]
            : Convert.FromBase64String(current);
        SetContributor(bitmap, metricSubjectId);
        return Convert.ToBase64String(bitmap);
    }

    public static int CountContributors(IEnumerable<string> bitmaps)
    {
        var merged = new byte[EnterpriseLearningMetricsPolicy.ContributorBitmapBits / 8];
        foreach (var encoded in bitmaps)
        {
            var bitmap = Convert.FromBase64String(encoded);
            if (bitmap.Length != merged.Length)
            {
                throw new OrganizationValidationException(
                    "The enterprise metrics contributor bitmap is invalid.");
            }
            for (var index = 0; index < merged.Length; index++)
            {
                merged[index] |= bitmap[index];
            }
        }
        return merged.Sum(value => BitOperations.PopCount(value));
    }

    private static void SetContributor(byte[] bitmap, string metricSubjectId)
    {
        var hash = metricSubjectId[(metricSubjectId.LastIndexOf(':') + 1)..];
        var bit = int.Parse(hash.AsSpan(2, 4), NumberStyles.HexNumber, CultureInfo.InvariantCulture)
            % EnterpriseLearningMetricsPolicy.ContributorBitmapBits;
        bitmap[bit / 8] |= (byte)(1 << (bit % 8));
    }
}

public sealed record EnterpriseLearningActiveSubjectShard(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    DateTimeOffset BucketStartedAt,
    int Shard,
    string ContributorBitmap,
    DateTimeOffset UpdatedAt,
    int Ttl)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "enterpriseLearningActiveSubjectShard";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static EnterpriseLearningActiveSubjectShard Apply(
        EnterpriseLearningHeartbeat heartbeat,
        EnterpriseLearningActiveSubjectShard? current,
        DateTimeOffset acceptedAt)
    {
        var bucket = EnterpriseMetricDocumentIds.ActiveBucket(acceptedAt);
        return new EnterpriseLearningActiveSubjectShard(
            EnterpriseMetricDocumentIds.Active(
                heartbeat.OrganizationId,
                bucket,
                heartbeat.AggregateShard),
            heartbeat.OrganizationId,
            CurrentSchemaVersion,
            Type,
            bucket,
            heartbeat.AggregateShard,
            EnterpriseLearningDailyAggregateShard.ReadOrCreateBitmap(
                current?.ContributorBitmap,
                heartbeat.MetricCohortSubjectId),
            acceptedAt,
            EnterpriseLearningMetricsPolicy.ActiveWindowSeconds * 2);
    }
}

public sealed record OrganizationOffboardingTombstone(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string TargetMembershipId,
    int MembershipCycle,
    string MetricSubjectId,
    IReadOnlyList<string> ReceiptPartitionKeys,
    DateTimeOffset RevokedAt,
    DateTimeOffset? PurgeCompletedAt,
    int Ttl)
{
    public const int CurrentSchemaVersion = 2;
    public const string Type = "organizationOffboardingTombstone";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static OrganizationOffboardingTombstone Create(
        OrganizationMembership target,
        DateTimeOffset revokedAt) =>
        new(
            EnterpriseMetricDocumentIds.OffboardingTombstone(
                target.OrganizationId,
                target.PersonId,
                target.Cycle),
            target.OrganizationId,
            CurrentSchemaVersion,
            Type,
            target.Id,
            target.Cycle,
            EnterpriseMetricDocumentIds.Subject(
                target.OrganizationId,
                target.PersonId,
                target.Cycle),
            EnterpriseMetricDocumentIds.ReceiptPartitions(
                target.OrganizationId,
                revokedAt,
                EnterpriseMetricDocumentIds.AggregateShard(
                    EnterpriseMetricDocumentIds.CohortSubject(
                        target.OrganizationId,
                        target.PersonId))),
            revokedAt,
            null,
            -1);
}

public static class EnterpriseMetricDocumentIds
{
    public static string RequestHash(
        string sessionId,
        string operationId,
        long sequence,
        DateTimeOffset occurredAt) =>
        OrganizationDocumentIds.Hash(
            "certigo-enterprise-metric-heartbeat-request:v3",
            sessionId,
            operationId,
            sequence.ToString(CultureInfo.InvariantCulture),
            occurredAt.ToUniversalTime().ToString("O"));

    public static string Subject(string organizationId, string personId, int cycle) =>
        $"enterprise-metric-subject::v3::{OrganizationDocumentIds.Hash(
            "certigo-enterprise-metric-subject:v3",
            organizationId,
            personId,
            cycle.ToString(CultureInfo.InvariantCulture))}";

    public static string CohortSubject(string organizationId, string personId) =>
        $"enterprise-metric-cohort::v1::{OrganizationDocumentIds.Hash(
            "certigo-enterprise-metric-cohort:v1",
            organizationId,
            personId)}";

    public static string Lease(string organizationId, string metricSubjectId) =>
        $"enterprise-learning-lease::v1::{OrganizationDocumentIds.Hash(
            "certigo-enterprise-learning-lease:v1",
            organizationId,
            metricSubjectId)}";

    public static string Receipt(string organizationId, string sessionId, long sequence) =>
        $"enterprise-metric-receipt::v3::{OrganizationDocumentIds.Hash(
            "certigo-enterprise-metric-receipt:v3",
            organizationId,
            sessionId,
            sequence.ToString(CultureInfo.InvariantCulture))}";

    public static string ReceiptIntent(string organizationId, string sessionId, long sequence) =>
        $"enterprise-metric-receipt-intent::v1::{OrganizationDocumentIds.Hash(
            "certigo-enterprise-metric-receipt-intent:v1",
            organizationId,
            sessionId,
            sequence.ToString(CultureInfo.InvariantCulture))}";

    public static string ReceiptPartition(
        string organizationId,
        DateTimeOffset occurredAt,
        int shard) =>
        $"{organizationId}|{occurredAt.UtcDateTime:yyyyMMdd}|{shard:D3}";

    public static IReadOnlyList<string> ReceiptPartitions(
        string organizationId,
        DateTimeOffset revokedAt,
        int shard) =>
        Enumerable.Range(0, 30)
            .Select(offset => ReceiptPartition(organizationId, revokedAt.AddDays(-offset), shard))
            .ToArray();

    public static int AggregateShard(string metricSubjectId)
    {
        var hash = metricSubjectId[(metricSubjectId.LastIndexOf(':') + 1)..];
        return int.Parse(hash.AsSpan(0, 2), NumberStyles.HexNumber, CultureInfo.InvariantCulture)
            % EnterpriseLearningMetricsPolicy.AggregateShardCount;
    }

    public static string Aggregate(string organizationId, DateOnly day, int shard) =>
        $"enterprise-learning-aggregate::v3::{OrganizationDocumentIds.Hash(
            "certigo-enterprise-learning-aggregate:v3",
            organizationId,
            day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture),
            shard.ToString(CultureInfo.InvariantCulture))}";

    public static DateTimeOffset ActiveBucket(DateTimeOffset value)
    {
        var ticks = value.UtcTicks
            - value.UtcTicks % TimeSpan.FromSeconds(
                EnterpriseLearningMetricsPolicy.ActiveWindowSeconds).Ticks;
        return new DateTimeOffset(ticks, TimeSpan.Zero);
    }

    public static string Active(
        string organizationId,
        DateTimeOffset bucket,
        int shard) =>
        $"enterprise-learning-active::v1::{OrganizationDocumentIds.Hash(
            "certigo-enterprise-learning-active:v1",
            organizationId,
            bucket.ToString("O"),
            shard.ToString(CultureInfo.InvariantCulture))}";

    public static string OffboardingTombstone(
        string organizationId,
        string personId,
        int cycle) =>
        $"organization-offboarding::v2::{OrganizationDocumentIds.Hash(
            "certigo-organization-offboarding:v2",
            organizationId,
            personId,
            cycle.ToString(CultureInfo.InvariantCulture))}";
}

public sealed class EnterpriseLearningSequenceException()
    : Exception("The heartbeat sequence or lease window is invalid.");
public sealed class EnterpriseLearningLeaseConflictException()
    : Exception("An active enterprise learning session lease already exists.");
public sealed class EnterpriseLearningIntentLeaseException()
    : Exception("The enterprise learning receipt intent lease is not available.");
