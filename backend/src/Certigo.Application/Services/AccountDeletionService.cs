using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;

namespace Certigo.Application.Services;

public interface IAccountDeletionService
{
    Task<AccountDeletionDto> GetStatusAsync(CancellationToken cancellationToken = default);

    Task<AccountDeletionDto> RequestAsync(
        DateTimeOffset? authenticatedAt,
        CancellationToken cancellationToken = default);
}

public sealed class AccountDeletionService(
    IUserContext userContext,
    IAccountDeletionRepository repository,
    IExternalIdentityDeletion externalIdentityDeletion,
    IAccountDeletionAudit audit,
    IClock clock) : IAccountDeletionService
{
    private static readonly TimeSpan RecentAuthenticationWindow = TimeSpan.FromMinutes(10);
    private static readonly TimeSpan MaximumClockSkew = TimeSpan.FromMinutes(2);
    private static readonly TimeSpan CompletedRecordRetention = TimeSpan.FromDays(30);

    private const string SocialStep = "social";
    private const string LearningStep = "learning";
    private const string EconomyStep = "economy";
    private const string ProfileStep = "profile";
    private const string IdentityStep = "identity";
    private const string ReconciliationStep = "reconciliation";

    private static readonly IReadOnlyList<string> RequiredSteps =
    [
        SocialStep,
        LearningStep,
        EconomyStep,
        ProfileStep,
        ReconciliationStep,
        IdentityStep,
    ];

    public async Task<AccountDeletionDto> GetStatusAsync(CancellationToken cancellationToken = default)
    {
        var record = await repository.GetAsync(
            AccountDeletionSubject.Hash(userContext.UserId),
            cancellationToken);
        return ToDto(record, clock.UtcNow);
    }

    public async Task<AccountDeletionDto> RequestAsync(
        DateTimeOffset? authenticatedAt,
        CancellationToken cancellationToken = default)
    {
        var subjectUserId = userContext.UserId;
        var subjectHash = AccountDeletionSubject.Hash(subjectUserId);
        var record = await repository.GetAsync(subjectHash, cancellationToken);

        if (record is null)
        {
            EnsureRecentAuthentication(authenticatedAt);
            var now = clock.UtcNow;
            record = await repository.GetOrCreateAsync(
                new AccountDeletionRecord(
                    AccountDeletionRecord.RecordId,
                    subjectHash,
                    subjectUserId,
                    Guid.NewGuid().ToString("n"),
                    await repository.ResolveIdentityKindAsync(subjectUserId, cancellationToken),
                    RequiredSteps,
                    [],
                    AccountDeletionRecordStatus.Pending,
                    now,
                    now),
                cancellationToken);
            audit.Record(new AccountDeletionAuditEvent(record.RequestId, "requested", now));
        }

        if (record.Status == AccountDeletionRecordStatus.Completed)
        {
            record = await repository.MarkCompletedAsync(
                subjectHash,
                record.CompletedAt ?? clock.UtcNow,
                checked((int)CompletedRecordRetention.TotalSeconds),
                cancellationToken);
            return ToDto(record, clock.UtcNow);
        }

        var persistedSubject = record.SubjectUserId
            ?? throw new InvalidOperationException(
                "A pending account deletion record must retain its subject until completion.");

        foreach (var step in RequiredSteps)
        {
            if (record.HasCompleted(step))
            {
                continue;
            }

            try
            {
                await ExecuteStepAsync(record.IdentityKind, step, persistedSubject, cancellationToken);
                record = await repository.MarkStepCompletedAsync(
                    subjectHash,
                    step,
                    clock.UtcNow,
                    cancellationToken);
                audit.Record(new AccountDeletionAuditEvent(
                    record.RequestId,
                    "step-completed",
                    clock.UtcNow,
                    Step: step));
            }
            catch (AccountDeletionStepException ex)
            {
                var now = clock.UtcNow;
                var nextRetryAt = now + RetryDelay(record.AttemptCount + 1);
                record = await repository.MarkFailureAsync(
                    subjectHash,
                    ex.FailureCode,
                    now,
                    nextRetryAt,
                    cancellationToken);
                audit.Record(new AccountDeletionAuditEvent(
                    record.RequestId,
                    "retry-scheduled",
                    now,
                    Step: step,
                    FailureCode: ex.FailureCode));
                return ToDto(record, now);
            }
        }

        record = await repository.MarkCompletedAsync(
            subjectHash,
            clock.UtcNow,
            checked((int)CompletedRecordRetention.TotalSeconds),
            cancellationToken);
        audit.Record(new AccountDeletionAuditEvent(record.RequestId, "completed", clock.UtcNow));
        return ToDto(record, clock.UtcNow);
    }

    private void EnsureRecentAuthentication(DateTimeOffset? authenticatedAt)
    {
        var now = clock.UtcNow;
        if (authenticatedAt is null
            || authenticatedAt < now - RecentAuthenticationWindow
            || authenticatedAt > now + MaximumClockSkew)
        {
            throw new RecentAuthenticationRequiredException();
        }
    }

    private async Task ExecuteStepAsync(
        AccountIdentityKind identityKind,
        string step,
        string subjectUserId,
        CancellationToken cancellationToken)
    {
        switch (step)
        {
            case SocialStep:
                await repository.DeleteSocialDataAsync(subjectUserId, cancellationToken);
                break;
            case LearningStep:
                await repository.DeleteLearningDataAsync(subjectUserId, cancellationToken);
                break;
            case EconomyStep:
                await repository.DeleteEconomyDataAsync(subjectUserId, cancellationToken);
                break;
            case ProfileStep:
                await repository.DeleteProfileAsync(subjectUserId, cancellationToken);
                // Removing the profile prevents new handle lookups. Sweep social
                // projections again before identity deletion to catch edges created
                // by a request that raced the first social pass.
                await repository.DeleteSocialDataAsync(subjectUserId, cancellationToken);
                break;
            case IdentityStep when identityKind == AccountIdentityKind.Local:
                await repository.DeleteCredentialsAsync(subjectUserId, cancellationToken);
                break;
            case IdentityStep when identityKind == AccountIdentityKind.External:
                await externalIdentityDeletion.DeleteAsync(subjectUserId, cancellationToken);
                break;
            case ReconciliationStep:
                // Writers hold distributed leases acquired against the same
                // lifecycle partition that deletion closes atomically. Their
                // session tokens form the cross-container visibility barrier.
                await repository.ReconcileDataAsync(
                    subjectUserId,
                    cancellationToken);
                break;
            case IdentityStep:
                throw new InvalidOperationException(
                    $"Unsupported account identity kind '{identityKind}'.");
            default:
                throw new InvalidOperationException($"Unknown account deletion step '{step}'.");
        }
    }

    private static TimeSpan RetryDelay(int attempt)
    {
        var exponent = Math.Min(Math.Max(attempt - 1, 0), 6);
        return TimeSpan.FromSeconds(Math.Min(5 * (1 << exponent), 300));
    }

    private static AccountDeletionDto ToDto(AccountDeletionRecord? record, DateTimeOffset now)
    {
        if (record is null)
        {
            return new AccountDeletionDto(
                AccountDeletionStatus.NotRequested,
                0,
                RequiredSteps.Count);
        }

        int? retryAfter = record.Status == AccountDeletionRecordStatus.Pending
            && record.NextRetryAt is { } next
            ? Math.Max(0, (int)Math.Ceiling((next - now).TotalSeconds))
            : null;
        return new AccountDeletionDto(
            record.Status == AccountDeletionRecordStatus.Completed
                ? AccountDeletionStatus.Completed
                : AccountDeletionStatus.Pending,
            record.CompletedSteps.Count,
            record.RequiredSteps.Count,
            record.RequestedAt,
            record.CompletedAt,
            record.FailureCode,
            retryAfter);
    }
}

public sealed class DisabledAccountDeletionService : IAccountDeletionService
{
    public Task<AccountDeletionDto> GetStatusAsync(CancellationToken cancellationToken = default)
        => throw new AccountDeletionDisabledException();

    public Task<AccountDeletionDto> RequestAsync(
        DateTimeOffset? authenticatedAt,
        CancellationToken cancellationToken = default)
        => throw new AccountDeletionDisabledException();
}

public sealed class AccountDeletionAccessGuard(IAccountDeletionRepository repository)
    : IAccountDeletionAccessGuard
{
    public async Task<bool> IsBlockedAsync(
        string subjectUserId,
        CancellationToken cancellationToken = default)
        => await repository.GetAsync(
            AccountDeletionSubject.Hash(subjectUserId),
            cancellationToken) is not null;
}
