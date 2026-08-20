using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class AccountDeletionServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 18, 20, 0, 0, TimeSpan.Zero);

    [Fact]
    public async Task First_request_requires_recent_authentication_before_persisting_anything()
    {
        var repository = new FakeAccountDeletionRepository();
        var service = Build(repository);

        var act = () => service.RequestAsync(Now.AddMinutes(-11));

        await act.Should().ThrowAsync<RecentAuthenticationRequiredException>();
        repository.Record.Should().BeNull();
        repository.Calls.Should().BeEmpty();
    }

    [Fact]
    public async Task Request_executes_ordered_deletion_and_is_idempotent()
    {
        var repository = new FakeAccountDeletionRepository();
        var identity = new FakeExternalIdentityDeletion();
        var audit = new CapturingAccountDeletionAudit();
        var service = Build(repository, identity, audit);

        var first = await service.RequestAsync(Now.AddMinutes(-1));
        var replay = await service.RequestAsync(null);

        first.Status.Should().Be(AccountDeletionStatus.Completed);
        replay.Should().Be(first);
        repository.Calls.Should().Equal(
            "social",
            "learning",
            "economy",
            "profile",
            "social",
            "social",
            "learning",
            "economy",
            "profile",
            "social",
            "identity",
            "linked-identity");
        identity.Subjects.Should().Equal("external-user-1");
        repository.Record!.SubjectUserId.Should().BeNull();
        repository.Record.Ttl.Should().Be((int)TimeSpan.FromDays(30).TotalSeconds);
        audit.Events.Select(entry => entry.EventType).Should().ContainInOrder(
            "requested",
            "step-completed",
            "step-completed",
            "step-completed",
            "step-completed",
            "step-completed",
            "step-completed",
            "completed");
    }

    [Fact]
    public async Task Retry_resumes_after_the_last_completed_step_without_new_reauthentication()
    {
        var repository = new FakeAccountDeletionRepository
        {
            FailOnceOn = "learning",
        };
        var service = Build(repository);

        var pending = await service.RequestAsync(Now);
        var completed = await service.RequestAsync(null);

        pending.Status.Should().Be(AccountDeletionStatus.Pending);
        pending.CompletedSteps.Should().Be(1);
        pending.FailureCode.Should().Be("learning-data-delete-failed");
        completed.Status.Should().Be(AccountDeletionStatus.Completed);
        repository.Calls.Should().Equal(
            "social",
            "learning",
            "learning",
            "economy",
            "profile",
            "social",
            "social",
            "learning",
            "economy",
            "profile",
            "social",
            "identity",
            "linked-identity");
    }

    [Fact]
    public async Task Get_status_does_not_create_a_request()
    {
        var repository = new FakeAccountDeletionRepository();
        var status = await Build(repository).GetStatusAsync();

        status.Status.Should().Be(AccountDeletionStatus.NotRequested);
        repository.Record.Should().BeNull();
    }

    [Fact]
    public async Task Disabled_feature_fails_closed()
    {
        IAccountDeletionService service = new DisabledAccountDeletionService();

        await FluentActions.Invoking(() => service.GetStatusAsync())
            .Should().ThrowAsync<AccountDeletionDisabledException>();
        await FluentActions.Invoking(() => service.RequestAsync(Now))
            .Should().ThrowAsync<AccountDeletionDisabledException>();
    }

    [Fact]
    public void Subject_hash_is_stable_non_reversible_and_contains_no_raw_identifier()
    {
        var first = AccountDeletionSubject.Hash("person@example.com");
        var second = AccountDeletionSubject.Hash("person@example.com");

        first.Should().Be(second);
        first.Should().HaveLength(64);
        first.ToLowerInvariant().Should().NotContain("person");
        first.Should().NotContain("@");
    }

    private static AccountDeletionService Build(
        FakeAccountDeletionRepository repository,
        FakeExternalIdentityDeletion? identity = null,
        CapturingAccountDeletionAudit? audit = null)
        => new(
            new FakeUserContext("external-user-1", "Deleted User"),
            repository,
            identity ?? new FakeExternalIdentityDeletion(),
            audit ?? new CapturingAccountDeletionAudit(),
            new FakeClock(Now));

    private sealed class FakeAccountDeletionRepository : IAccountDeletionRepository
    {
        public AccountDeletionRecord? Record { get; private set; }
        public List<string> Calls { get; } = [];
        public string? FailOnceOn { get; init; }
        private bool _failed;

        public Task<AccountDeletionRecord?> GetAsync(
            string subjectHash,
            CancellationToken cancellationToken = default)
            => Task.FromResult(Record);

        public Task<AccountDeletionRecord> GetOrCreateAsync(
            AccountDeletionRecord record,
            CancellationToken cancellationToken = default)
        {
            Record ??= record with { ETag = "\"1\"" };
            return Task.FromResult(Record);
        }

        public Task<AccountIdentityKind> ResolveIdentityKindAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Task.FromResult(AccountIdentityKind.External);

        public Task<AccountDeletionRecord> MarkStepCompletedAsync(
            string subjectHash,
            string step,
            DateTimeOffset updatedAt,
            CancellationToken cancellationToken = default)
        {
            Record = Record! with
            {
                CompletedSteps = Record.CompletedSteps.Append(step).ToArray(),
                UpdatedAt = updatedAt,
                FailureCode = null,
                NextRetryAt = null,
            };
            return Task.FromResult(Record);
        }

        public Task<AccountDeletionRecord> MarkFailureAsync(
            string subjectHash,
            string failureCode,
            DateTimeOffset updatedAt,
            DateTimeOffset nextRetryAt,
            CancellationToken cancellationToken = default)
        {
            Record = Record! with
            {
                FailureCode = failureCode,
                UpdatedAt = updatedAt,
                NextRetryAt = nextRetryAt,
                AttemptCount = Record.AttemptCount + 1,
            };
            return Task.FromResult(Record);
        }

        public Task<AccountDeletionRecord> MarkCompletedAsync(
            string subjectHash,
            DateTimeOffset completedAt,
            int retentionSeconds,
            CancellationToken cancellationToken = default)
        {
            Record = Record! with
            {
                SubjectUserId = null,
                Status = AccountDeletionRecordStatus.Completed,
                UpdatedAt = completedAt,
                CompletedAt = completedAt,
                Ttl = retentionSeconds,
            };
            return Task.FromResult(Record);
        }

        public async Task ReconcileDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
        {
            await Execute("social");
            await Execute("learning");
            await Execute("economy");
            await Execute("profile");
            await Execute("social");
            await Execute("identity");
        }

        public Task DeleteSocialDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Execute("social");

        public Task DeleteLearningDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Execute("learning");

        public Task DeleteEconomyDataAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Execute("economy");

        public Task DeleteProfileAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Execute("profile");

        public Task DeleteCredentialsAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
            => Execute("identity");

        public Task DeleteLinkedIdentityDataAsync(
            string subjectUserId,
            DateTimeOffset revokedAt,
            CancellationToken cancellationToken = default)
            => Execute("linked-identity");

        private Task Execute(string step)
        {
            Calls.Add(step);
            if (!_failed && string.Equals(step, FailOnceOn, StringComparison.Ordinal))
            {
                _failed = true;
                throw new AccountDeletionStepException(
                    $"{step}-data-delete-failed",
                    new InvalidOperationException("simulated transient failure"));
            }

            return Task.CompletedTask;
        }
    }

    private sealed class FakeExternalIdentityDeletion : IExternalIdentityDeletion
    {
        public List<string> Subjects { get; } = [];

        public Task DeleteAsync(
            string subjectUserId,
            CancellationToken cancellationToken = default)
        {
            Subjects.Add(subjectUserId);
            return Task.CompletedTask;
        }
    }

    private sealed class CapturingAccountDeletionAudit : IAccountDeletionAudit
    {
        public List<AccountDeletionAuditEvent> Events { get; } = [];

        public void Record(AccountDeletionAuditEvent auditEvent) => Events.Add(auditEvent);
    }
}
