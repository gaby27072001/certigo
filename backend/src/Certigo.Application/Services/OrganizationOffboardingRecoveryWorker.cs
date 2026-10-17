using Certigo.Application.Abstractions;

namespace Certigo.Application.Services;

public sealed class OrganizationOffboardingRecoveryWorker(
    IOrganizationRepository organizations) : IOrganizationOffboardingRecoveryWorker
{
    private const int MaximumAttempts = 5;

    public async Task<int> RunBatchAsync(
        int maximumTombstones,
        CancellationToken cancellationToken = default)
    {
        var tombstones = await organizations.ListIncompleteOffboardingsAsync(
            maximumTombstones,
            cancellationToken);
        var completed = 0;
        var failures = new List<Exception>();
        foreach (var tombstone in tombstones)
        {
            for (var attempt = 1; attempt <= MaximumAttempts; attempt++)
            {
                try
                {
                    await organizations.PurgeOffboardingAsync(
                        tombstone.OrganizationId,
                        tombstone.Id,
                        cancellationToken);
                    completed++;
                    break;
                }
                catch (Exception ex) when (
                    ex is not OperationCanceledException
                    && attempt < MaximumAttempts)
                {
                    await Task.Delay(
                        RetryDelayForAttempt(attempt),
                        cancellationToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    failures.Add(ex);
                }
            }
        }
        if (failures.Count > 0)
        {
            throw new AggregateException(
                "One or more organization offboarding purges could not be recovered.",
                failures);
        }
        return completed;
    }

    internal static TimeSpan RetryDelayForAttempt(int attempt)
    {
        if (attempt < 1 || attempt >= MaximumAttempts)
        {
            throw new ArgumentOutOfRangeException(nameof(attempt));
        }

        return TimeSpan.FromMilliseconds(25d * (1 << attempt));
    }
}
