using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;

namespace Certigo.Application.Abstractions;

public enum AccountIdentityKind
{
    Local,
    External,
}

public enum AccountDeletionRecordStatus
{
    Pending,
    Completed,
}

public sealed record AccountDeletionRecord(
    string Id,
    string UserId,
    string? SubjectUserId,
    string RequestId,
    AccountIdentityKind IdentityKind,
    IReadOnlyList<string> RequiredSteps,
    IReadOnlyList<string> CompletedSteps,
    AccountDeletionRecordStatus Status,
    DateTimeOffset RequestedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? CompletedAt = null,
    string? FailureCode = null,
    int AttemptCount = 0,
    DateTimeOffset? NextRetryAt = null,
    int Ttl = -1)
{
    public const string RecordId = "account-deletion";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public bool HasCompleted(string step) =>
        CompletedSteps.Contains(step, StringComparer.Ordinal);
}

public static class AccountDeletionSubject
{
    private const string DomainSeparator = "certigo-account-deletion:v1:";

    public static string Hash(string userId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(DomainSeparator + userId));
        return Convert.ToHexString(bytes).ToLowerInvariant();
    }
}

public sealed class RecentAuthenticationRequiredException()
    : Exception("Une authentification récente est requise pour supprimer ce compte.");

public sealed class AccountDeletionStepException(string failureCode, Exception innerException)
    : Exception("Account deletion could not complete a retryable step.", innerException)
{
    public string FailureCode { get; } = failureCode;
}

public sealed class AccountDeletionInProgressException()
    : Exception("Account deletion is in progress; user data can no longer be modified.");

public sealed class AccountDeletionDisabledException()
    : Exception("Account deletion is temporarily unavailable.");

public interface IAccountDeletionRepository
{
    Task<AccountDeletionRecord?> GetAsync(
        string subjectHash,
        CancellationToken cancellationToken = default);

    Task<AccountDeletionRecord> GetOrCreateAsync(
        AccountDeletionRecord record,
        CancellationToken cancellationToken = default);

    Task<AccountIdentityKind> ResolveIdentityKindAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default);

    Task<AccountDeletionRecord> MarkStepCompletedAsync(
        string subjectHash,
        string step,
        DateTimeOffset updatedAt,
        CancellationToken cancellationToken = default);

    Task<AccountDeletionRecord> MarkFailureAsync(
        string subjectHash,
        string failureCode,
        DateTimeOffset updatedAt,
        DateTimeOffset nextRetryAt,
        CancellationToken cancellationToken = default);

    Task<AccountDeletionRecord> MarkCompletedAsync(
        string subjectHash,
        DateTimeOffset completedAt,
        int retentionSeconds,
        CancellationToken cancellationToken = default);

    Task ReconcileDataAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default);

    Task DeleteSocialDataAsync(string subjectUserId, CancellationToken cancellationToken = default);
    Task DeleteLearningDataAsync(string subjectUserId, CancellationToken cancellationToken = default);
    Task DeleteEconomyDataAsync(string subjectUserId, CancellationToken cancellationToken = default);
    Task DeleteProfileAsync(string subjectUserId, CancellationToken cancellationToken = default);
    Task DeleteCredentialsAsync(string subjectUserId, CancellationToken cancellationToken = default);
}

public interface IExternalIdentityDeletion
{
    Task DeleteAsync(string subjectUserId, CancellationToken cancellationToken = default);
}

public sealed record AccountDeletionAuditEvent(
    string RequestId,
    string EventType,
    DateTimeOffset OccurredAt,
    string? Step = null,
    string? FailureCode = null);

public interface IAccountDeletionAudit
{
    void Record(AccountDeletionAuditEvent auditEvent);
}

public interface IAccountDeletionAccessGuard
{
    Task<bool> IsBlockedAsync(string subjectUserId, CancellationToken cancellationToken = default);
}

public interface IReauthenticationProofValidator
{
    Task<TokenValidationResult> TryValidateAsync(
        string token,
        CancellationToken cancellationToken = default);
}
