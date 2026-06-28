namespace Certigo.Application.Abstractions;

/// Bounded retry wrapper for optimistic-concurrency (ETag) writes. It re-runs the
/// supplied read-modify-write delegate whenever a <see cref="ConcurrencyConflictException"/>
/// is raised, so concurrent economy mutations (XP, gems, streak) converge on the
/// latest server state instead of silently losing an update (last-writer-wins).
///
/// The delegate MUST re-read the record on every invocation and re-apply the same
/// deterministic deltas, so a retry produces a correct result against fresh state.
public static class OptimisticConcurrency
{
    public const int DefaultMaxAttempts = 5;

    public static async Task<T> ExecuteAsync<T>(
        Func<Task<T>> action,
        int maxAttempts = DefaultMaxAttempts,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(action);
        for (var attempt = 1; ; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                return await action();
            }
            catch (ConcurrencyConflictException) when (attempt < maxAttempts)
            {
                // Transient conflict: another writer won the race. Loop to re-read
                // the latest state and re-apply on the next iteration.
            }
        }
    }

    public static Task ExecuteAsync(
        Func<Task> action,
        int maxAttempts = DefaultMaxAttempts,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(action);
        return ExecuteAsync<object?>(async () =>
        {
            await action();
            return null;
        }, maxAttempts, cancellationToken);
    }
}
