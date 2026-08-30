namespace Certigo.Application.Dtos;

public sealed record EnterpriseLearningSessionDto(
    string SessionId,
    string LeaseToken,
    DateTimeOffset ExpiresAt);

public sealed record EnterpriseLearningHeartbeatRequest(
    string SessionId,
    string LeaseToken,
    string OperationId,
    long Sequence,
    DateTimeOffset OccurredAt);

public sealed record EnterpriseLearningHeartbeatDto(
    string SessionId,
    DateTimeOffset LastHeartbeatAt,
    bool Replayed);

public sealed record EnterpriseLearningDailySummaryDto(
    string OrganizationId,
    DateOnly Day,
    bool Suppressed,
    long LearningSeconds,
    long ProgressBasisPoints,
    long CompletionCount,
    double? AverageReadinessPercent,
    long HeartbeatCount);

public sealed record EnterpriseLearningActiveSummaryDto(
    string OrganizationId,
    DateTimeOffset BucketStartedAt,
    bool Suppressed,
    int ActiveContributorCountLowerBound);
