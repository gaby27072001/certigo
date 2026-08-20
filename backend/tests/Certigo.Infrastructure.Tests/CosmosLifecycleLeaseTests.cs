using Certigo.Infrastructure.Cosmos;
using FluentAssertions;
using Xunit;

namespace Certigo.Infrastructure.Tests;

public sealed class CosmosLifecycleLeaseTests
{
    [Fact]
    public async Task Barrier_failure_ignores_request_cancellation_and_retains_lease()
    {
        CancellationToken observedToken = default;
        var released = false;
        var lease = new CosmosContext.AccountWriteLease(
            (_, _, token) =>
            {
                observedToken = token;
                throw new InvalidOperationException("barrier unavailable");
            },
            () =>
            {
                released = true;
                return Task.CompletedTask;
            });
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();

        Func<Task> commit = () => lease.CommitAsync(
            CosmosContainers.Attempts,
            "session-token",
            cancellation.Token);

        await commit.Should().ThrowAsync<InvalidOperationException>();
        observedToken.CanBeCanceled.Should().BeFalse();
        await lease.DisposeAsync();
        released.Should().BeFalse("a possibly committed mutation must keep deletion blocked");
    }

    [Fact]
    public async Task Lease_without_a_committed_mutation_is_released()
    {
        var released = false;
        var lease = new CosmosContext.AccountWriteLease(
            (_, _, _) => Task.CompletedTask,
            () =>
            {
                released = true;
                return Task.CompletedTask;
            });

        await lease.DisposeAsync();

        released.Should().BeTrue();
    }

    [Fact]
    public async Task Failed_pre_dispatch_persistence_releases_uncommitted_lease()
    {
        var released = false;
        var lease = new CosmosContext.AccountWriteLease(
            (_, _, _) => Task.CompletedTask,
            () =>
            {
                released = true;
                return Task.CompletedTask;
            },
            () => throw new InvalidOperationException("lease expired"));

        Func<Task> dispatch = lease.MarkMutationDispatchedAsync;

        await dispatch.Should().ThrowAsync<InvalidOperationException>();
        await lease.DisposeAsync();
        released.Should().BeTrue();
    }

    [Fact]
    public async Task Dispatched_mutation_with_unknown_outcome_retains_lease()
    {
        var released = false;
        var lease = new CosmosContext.AccountWriteLease(
            (_, _, _) => Task.CompletedTask,
            () =>
            {
                released = true;
                return Task.CompletedTask;
            });

        await lease.MarkMutationDispatchedAsync();
        await lease.DisposeAsync();

        released.Should().BeFalse();
    }

    [Fact]
    public async Task Definitive_non_commit_releases_dispatched_lease()
    {
        var released = false;
        var lease = new CosmosContext.AccountWriteLease(
            (_, _, _) => Task.CompletedTask,
            () =>
            {
                released = true;
                return Task.CompletedTask;
            });

        await lease.MarkMutationDispatchedAsync();
        lease.MarkDefinitelyNotCommitted();
        await lease.DisposeAsync();

        released.Should().BeTrue();
    }

    [Fact]
    public async Task Persisted_barrier_replaces_active_lease_without_releasing_it()
    {
        var persisted = false;
        var released = false;
        var lease = new CosmosContext.AccountWriteLease(
            (_, _, _) =>
            {
                persisted = true;
                return Task.CompletedTask;
            },
            () =>
            {
                released = true;
                return Task.CompletedTask;
            });

        await lease.CommitAsync(CosmosContainers.Users, "session-token");
        await lease.DisposeAsync();

        persisted.Should().BeTrue();
        released.Should().BeFalse();
    }
}
