using Certigo.Application.Abstractions;

namespace Certigo.Application.Services;

public sealed class EnterpriseLearningReceiptOutboxWorker(
    IEnterpriseLearningReceiptOutboxRepository outbox,
    IEnterpriseLearningMetricReceiptRepository receipts,
    IClock clock) : IEnterpriseLearningReceiptOutboxWorker
{
    private static readonly TimeSpan ProcessingLease = TimeSpan.FromMinutes(2);

    public async Task<int> RunBatchAsync(
        int maximumIntents,
        CancellationToken cancellationToken = default)
    {
        var now = clock.UtcNow;
        var owner = Guid.NewGuid().ToString("N");
        var candidates = await outbox.ListClaimableAsync(
            maximumIntents,
            now,
            cancellationToken);
        var completed = 0;
        foreach (var candidate in candidates)
        {
            var claimed = await outbox.ClaimAsync(
                candidate,
                owner,
                now,
                ProcessingLease,
                cancellationToken);
            if (claimed is null)
            {
                continue;
            }
            var revoked = await outbox.IsSubjectRevokedAsync(
                claimed.OrganizationId,
                claimed.MetricSubjectId,
                cancellationToken);
            if (!revoked)
            {
                await receipts.CreateOrVerifyAsync(claimed.Receipt, cancellationToken);
            }
            await outbox.CompleteAsync(
                claimed,
                owner,
                clock.UtcNow,
                revoked,
                cancellationToken);
            completed++;
        }
        return completed;
    }
}
