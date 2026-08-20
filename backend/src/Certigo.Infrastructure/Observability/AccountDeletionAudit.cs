using Microsoft.Extensions.Logging;
using Certigo.Application.Abstractions;

namespace Certigo.Infrastructure.Observability;

public sealed class AccountDeletionAudit(ILogger<AccountDeletionAudit> logger)
    : IAccountDeletionAudit
{
    public void Record(AccountDeletionAuditEvent auditEvent)
    {
        logger.LogInformation(
            "Account deletion audit: RequestId={RequestId}, EventType={EventType}, Step={Step}, FailureCode={FailureCode}, OccurredAt={OccurredAt}.",
            auditEvent.RequestId,
            auditEvent.EventType,
            auditEvent.Step,
            auditEvent.FailureCode,
            auditEvent.OccurredAt);
    }
}
