using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class OrganizationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

    [Theory]
    [InlineData(1, 50)]
    [InlineData(2, 100)]
    [InlineData(3, 200)]
    [InlineData(4, 400)]
    public void Offboarding_retry_delay_uses_bounded_exponential_values(
        int attempt,
        double expectedMilliseconds)
    {
        OrganizationOffboardingRecoveryWorker.RetryDelayForAttempt(attempt)
            .Should().Be(TimeSpan.FromMilliseconds(expectedMilliseconds));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(5)]
    public void Offboarding_retry_delay_rejects_attempts_outside_retryable_range(int attempt)
    {
        var act = () => OrganizationOffboardingRecoveryWorker.RetryDelayForAttempt(attempt);

        act.Should().Throw<ArgumentOutOfRangeException>()
            .Which.ParamName.Should().Be("attempt");
    }

    [Fact]
    public async Task Invitation_acceptance_uses_authenticated_person_and_is_single_use()
    {
        var repository = new MemoryOrganizationRepository();
        var ownerService = CreateService("owner-person", repository);
        var organization = await ownerService.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");
        var invitation = await ownerService.InviteAsync(
            organization.Id,
            "shared-email@example.test",
            OrganizationRole.Learner,
            "invitation-key-0001");
        var learnerService = CreateService("portable-person", repository);

        var membership = await learnerService.AcceptInvitationAsync(
            organization.Id,
            invitation.Id,
            invitation.Token);

        membership.PersonId.Should().Be("portable-person");
        membership.Role.Should().Be(OrganizationRole.Learner);
        var replay = () => learnerService.AcceptInvitationAsync(
            organization.Id,
            invitation.Id,
            invitation.Token);
        await replay.Should().ThrowAsync<OrganizationInvitationReplayException>();
    }

    [Fact]
    public async Task Learner_cannot_invite_and_service_does_not_auto_merge_by_email()
    {
        var repository = new MemoryOrganizationRepository();
        var ownerService = CreateService("owner-person", repository);
        var organization = await ownerService.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");
        var invitation = await ownerService.InviteAsync(
            organization.Id,
            "same@example.test",
            OrganizationRole.Learner,
            "invitation-key-0001");
        var learnerService = CreateService("person-a", repository);
        await learnerService.AcceptInvitationAsync(
            organization.Id,
            invitation.Id,
            invitation.Token);

        var action = () => learnerService.InviteAsync(
            organization.Id,
            "same@example.test",
            OrganizationRole.Learner,
            "invitation-key-0002");

        await action.Should().ThrowAsync<OrganizationAccessDeniedException>();
        repository.Memberships.Should().ContainKey((organization.Id, "person-a"));
        repository.Memberships.Should().NotContainKey((organization.Id, "same@example.test"));
    }

    [Fact]
    public async Task Offboarding_removes_only_organization_membership()
    {
        var repository = new MemoryOrganizationRepository();
        var ownerService = CreateService("owner-person", repository);
        var organization = await ownerService.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");
        var invitation = await ownerService.InviteAsync(
            organization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "invitation-key-0001");
        await CreateService("portable-person", repository).AcceptInvitationAsync(
            organization.Id,
            invitation.Id,
            invitation.Token);

        await ownerService.OffboardAsync(organization.Id, "portable-person");

        repository.Memberships.Should().NotContainKey((organization.Id, "portable-person"));
        repository.OffboardedPersonIds.Should().Equal("portable-person");
    }

    [Fact]
    public async Task Offboarding_revokes_before_purging_more_than_one_hundred_metric_documents()
    {
        var repository = new MemoryOrganizationRepository();
        var ownerService = CreateService("owner-person", repository);
        var organization = await ownerService.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");
        var invitation = await ownerService.InviteAsync(
            organization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "invitation-key-0001");
        await CreateService("portable-person", repository).AcceptInvitationAsync(
            organization.Id,
            invitation.Id,
            invitation.Token);
        repository.SeedMetricDocuments(250);

        await ownerService.OffboardAsync(organization.Id, "portable-person");

        repository.MembershipWasRemovedBeforePurge.Should().BeTrue();
        repository.RemainingMetricDocuments.Should().Be(0);
    }

    [Fact]
    public async Task Rejoin_is_blocked_until_recovery_completes_then_uses_new_cycle()
    {
        var repository = new MemoryOrganizationRepository { FailPurgeAttempts = 1 };
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync("Contoso", "organization-key-0001");
        var firstInvitation = await owner.InviteAsync(
            organization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "invitation-key-0001");
        var learner = CreateService("portable-person", repository);
        await learner.AcceptInvitationAsync(
            organization.Id,
            firstInvitation.Id,
            firstInvitation.Token);
        var offboard = () => owner.OffboardAsync(organization.Id, "portable-person");
        await offboard.Should().ThrowAsync<InvalidOperationException>();
        var secondInvitation = await owner.InviteAsync(
            organization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "invitation-key-0002");

        var blocked = () => learner.AcceptInvitationAsync(
            organization.Id,
            secondInvitation.Id,
            secondInvitation.Token);
        await blocked.Should().ThrowAsync<OrganizationOffboardingInProgressException>();

        repository.FailPurgeAttempts = 2;
        var worker = new OrganizationOffboardingRecoveryWorker(repository);
        (await worker.RunBatchAsync(10)).Should().Be(1);
        var rejoined = await learner.AcceptInvitationAsync(
            organization.Id,
            secondInvitation.Id,
            secondInvitation.Token);
        repository.Memberships[(organization.Id, "portable-person")].Cycle.Should().Be(2);
        rejoined.PersonId.Should().Be("portable-person");
    }

    [Fact]
    public async Task Offboarding_api_retry_resumes_tombstone_when_membership_is_absent()
    {
        var repository = new MemoryOrganizationRepository { FailPurgeAttempts = 1 };
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync("Contoso", "organization-key-0001");
        var invitation = await owner.InviteAsync(
            organization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "invitation-key-0001");
        await CreateService("portable-person", repository).AcceptInvitationAsync(
            organization.Id,
            invitation.Id,
            invitation.Token);
        var first = () => owner.OffboardAsync(organization.Id, "portable-person");
        await first.Should().ThrowAsync<InvalidOperationException>();

        var retried = await owner.OffboardAsync(organization.Id, "portable-person");

        retried.PersonId.Should().Be("portable-person");
        (await repository.GetLatestOffboardingAsync(
            organization.Id,
            "portable-person"))!.PurgeCompletedAt.Should().NotBeNull();
    }

    [Fact]
    public async Task Manager_cannot_recover_another_members_tombstone()
    {
        var repository = new MemoryOrganizationRepository { FailPurgeAttempts = 1 };
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync("Contoso", "organization-key-0001");
        var managerInvitation = await owner.InviteAsync(
            organization.Id,
            "manager@example.test",
            OrganizationRole.Manager,
            "manager-invite-0001");
        var manager = CreateService("manager-person", repository);
        await manager.AcceptInvitationAsync(
            organization.Id,
            managerInvitation.Id,
            managerInvitation.Token);
        var learnerInvitation = await owner.InviteAsync(
            organization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "learner-invite-0001");
        await CreateService("learner-person", repository).AcceptInvitationAsync(
            organization.Id,
            learnerInvitation.Id,
            learnerInvitation.Token);
        var first = () => owner.OffboardAsync(organization.Id, "learner-person");
        await first.Should().ThrowAsync<InvalidOperationException>();

        var unauthorized = () => manager.OffboardAsync(
            organization.Id,
            "learner-person");

        await unauthorized.Should().ThrowAsync<OrganizationMembershipNotFoundException>();
    }

    [Fact]
    public async Task Owner_cannot_be_offboarded()
    {
        var repository = new MemoryOrganizationRepository();
        var service = CreateService("owner-person", repository);
        var organization = await service.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");

        var action = () => service.OffboardAsync(organization.Id, "owner-person");

        await action.Should().ThrowAsync<OrganizationOwnerOffboardingException>();
    }

    [Fact]
    public async Task Offboarded_invitation_issuer_cannot_restore_admin_access()
    {
        var repository = new MemoryOrganizationRepository();
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");
        var adminInvitation = await owner.InviteAsync(
            organization.Id,
            "admin@example.test",
            OrganizationRole.Admin,
            "admin-invite-key-01");
        var admin = CreateService("admin-person", repository);
        await admin.AcceptInvitationAsync(
            organization.Id,
            adminInvitation.Id,
            adminInvitation.Token);
        var retainedInvitation = await admin.InviteAsync(
            organization.Id,
            "next-admin@example.test",
            OrganizationRole.Admin,
            "retained-token-key");
        await owner.OffboardAsync(organization.Id, "admin-person");

        var action = () => CreateService("next-admin", repository).AcceptInvitationAsync(
            organization.Id,
            retainedInvitation.Id,
            retainedInvitation.Token);

        await action.Should().ThrowAsync<OrganizationMembershipNotFoundException>();
        repository.Memberships.Should().NotContainKey((organization.Id, "next-admin"));
    }

    [Fact]
    public async Task Concurrent_issuer_offboarding_blocks_invitation_acceptance()
    {
        var repository = new MemoryOrganizationRepository();
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");
        var adminInvitation = await owner.InviteAsync(
            organization.Id,
            "admin@example.test",
            OrganizationRole.Admin,
            "admin-invite-key-01");
        var admin = CreateService("admin-person", repository);
        await admin.AcceptInvitationAsync(
            organization.Id,
            adminInvitation.Id,
            adminInvitation.Token);
        var retainedInvitation = await admin.InviteAsync(
            organization.Id,
            "next-admin@example.test",
            OrganizationRole.Admin,
            "retained-token-key");
        repository.BeforePrivilegedWrite = () =>
            repository.Memberships.Remove((organization.Id, "admin-person"));

        var action = () => CreateService("next-admin", repository).AcceptInvitationAsync(
            organization.Id,
            retainedInvitation.Id,
            retainedInvitation.Token);

        await action.Should().ThrowAsync<ConcurrencyConflictException>();
        repository.Memberships.Should().NotContainKey((organization.Id, "next-admin"));
    }

    [Theory]
    [InlineData("invitation")]
    [InlineData("team")]
    [InlineData("assignment")]
    public async Task Concurrent_actor_offboarding_blocks_privileged_write(string operation)
    {
        var repository = new MemoryOrganizationRepository();
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync(
            "Contoso Learning",
            "organization-key-0001");
        var adminInvitation = await owner.InviteAsync(
            organization.Id,
            "admin@example.test",
            OrganizationRole.Admin,
            "admin-invite-key-01");
        var admin = CreateService("admin-person", repository);
        await admin.AcceptInvitationAsync(
            organization.Id,
            adminInvitation.Id,
            adminInvitation.Token);
        var learnerInvitation = await owner.InviteAsync(
            organization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "learner-key-0001");
        await CreateService("learner-person", repository).AcceptInvitationAsync(
            organization.Id,
            learnerInvitation.Id,
            learnerInvitation.Token);
        var team = await owner.CreateTeamAsync(
            organization.Id,
            "Security",
            "team-key-0000001");
        repository.BeforePrivilegedWrite = () =>
            repository.Memberships.Remove((organization.Id, "admin-person"));

        Func<Task> action = operation switch
        {
            "invitation" => () => admin.InviteAsync(
                organization.Id,
                "another@example.test",
                OrganizationRole.Learner,
                "another-key-0001"),
            "team" => () => admin.CreateTeamAsync(
                organization.Id,
                "Platform",
                "team-key-0000002"),
            "assignment" => () => admin.AddTeamMemberAsync(
                organization.Id,
                team.Id,
                "learner-person"),
            _ => throw new InvalidOperationException(),
        };

        await action.Should().ThrowAsync<ConcurrencyConflictException>();
    }

    [Fact]
    public async Task Identity_without_person_is_rejected_before_any_organization_write()
    {
        var repository = new MemoryOrganizationRepository();
        var service = CreateService("missing-person", repository, seedPerson: false);

        var action = () => service.CreateAsync("Contoso", "organization-key-0001");

        await action.Should().ThrowAsync<OrganizationPersonNotFoundException>();
        repository.OrganizationWriteCount.Should().Be(0);
    }

    [Fact]
    public async Task Cross_tenant_and_unknown_organization_share_the_same_lookup_shape()
    {
        var repository = new MemoryOrganizationRepository();
        var first = CreateService("first-owner", repository);
        var firstOrganization = await first.CreateAsync(
            "First",
            "organization-key-0001");
        var second = CreateService("second-owner", repository);
        var secondOrganization = await second.CreateAsync(
            "Second",
            "organization-key-0002");

        repository.ResetReadCounts();
        var crossTenant = () => first.GetAsync(secondOrganization.Id);
        await crossTenant.Should().ThrowAsync<OrganizationMembershipNotFoundException>();
        var crossTenantReads = repository.ReadCounts;

        repository.ResetReadCounts();
        var unknown = () => first.GetAsync("organization::v1::unknown");
        await unknown.Should().ThrowAsync<OrganizationMembershipNotFoundException>();

        repository.ReadCounts.Should().Be(crossTenantReads);
        crossTenantReads.Should().Be((1, 0));
        firstOrganization.Id.Should().NotBe(secondOrganization.Id);
    }

    [Fact]
    public async Task Client_requested_role_never_elevates_a_manager_membership()
    {
        var repository = new MemoryOrganizationRepository();
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync(
            "Contoso",
            "organization-key-0001");
        var managerInvitation = await owner.InviteAsync(
            organization.Id,
            "manager@example.test",
            OrganizationRole.Manager,
            "manager-key-00001");
        var manager = CreateService("manager-person", repository);
        await manager.AcceptInvitationAsync(
            organization.Id,
            managerInvitation.Id,
            managerInvitation.Token);

        var action = () => manager.InviteAsync(
            organization.Id,
            "admin@example.test",
            OrganizationRole.Admin,
            "admin-key-0000001");

        await action.Should().ThrowAsync<OrganizationAccessDeniedException>();
    }

    [Fact]
    public async Task Team_resource_from_another_partition_is_hidden_as_not_found()
    {
        var repository = new MemoryOrganizationRepository();
        var firstOwner = CreateService("first-owner", repository);
        var firstOrganization = await firstOwner.CreateAsync(
            "First",
            "organization-key-0001");
        var foreignTeam = await firstOwner.CreateTeamAsync(
            firstOrganization.Id,
            "Foreign team",
            "team-key-0000001");
        var secondOwner = CreateService("second-owner", repository);
        var secondOrganization = await secondOwner.CreateAsync(
            "Second",
            "organization-key-0002");
        repository.SeedTeam(secondOrganization.Id, foreignTeam.Id, firstOrganization.Id);

        var action = () => secondOwner.AddTeamMemberAsync(
            secondOrganization.Id,
            foreignTeam.Id,
            "second-owner");

        await action.Should().ThrowAsync<OrganizationNotFoundException>();
    }

    [Fact]
    public async Task Invitation_resource_cannot_be_used_as_a_confused_deputy()
    {
        var repository = new MemoryOrganizationRepository();
        var firstOwner = CreateService("first-owner", repository);
        var firstOrganization = await firstOwner.CreateAsync(
            "First",
            "organization-key-0001");
        var invitation = await firstOwner.InviteAsync(
            firstOrganization.Id,
            "learner@example.test",
            OrganizationRole.Learner,
            "invitation-key-0001");
        var secondOwner = CreateService("second-owner", repository);
        var secondOrganization = await secondOwner.CreateAsync(
            "Second",
            "organization-key-0002");
        repository.SeedInvitation(
            secondOrganization.Id,
            invitation.Id,
            firstOrganization.Id,
            "first-owner");
        var learner = CreateService("learner-person", repository);

        var action = () => learner.AcceptInvitationAsync(
            secondOrganization.Id,
            invitation.Id,
            invitation.Token);

        await action.Should().ThrowAsync<OrganizationNotFoundException>();
        repository.Memberships.Should()
            .NotContainKey((secondOrganization.Id, "learner-person"));
    }

    [Fact]
    public async Task Membership_without_current_cas_token_is_not_active()
    {
        var repository = new MemoryOrganizationRepository();
        var owner = CreateService("owner-person", repository);
        var organization = await owner.CreateAsync(
            "Contoso",
            "organization-key-0001");
        var key = (organization.Id, "owner-person");
        repository.Memberships[key] = repository.Memberships[key] with { ETag = null };

        var action = () => owner.GetAsync(organization.Id);

        await action.Should().ThrowAsync<OrganizationMembershipNotFoundException>();
    }

    private static OrganizationService CreateService(
        string personId,
        MemoryOrganizationRepository repository,
        bool seedPerson = true)
    {
        if (seedPerson)
        {
            repository.People.Seed(new UserProfileDto(
                personId,
                personId,
                personId,
                null,
                0,
                1,
                0,
                0,
                50,
                0,
                0,
                null));
        }
        var people = new OrganizationPersonResolver(
            new StubUserContext(personId),
            repository.People);
        var memberships = new OrganizationMembershipResolver(repository);
        var authorization = new OrganizationAuthorizationHandler(people, memberships);
        return new OrganizationService(
            people,
            memberships,
            authorization,
            repository,
            new StubTokenGenerator(),
            new RecordingOrganizationTelemetry(),
            new StubClock());
    }

    private sealed class StubUserContext(string userId) : IUserContext
    {
        public string UserId { get; } = userId;
        public string DisplayName => UserId;
    }

    private sealed class StubClock : IClock
    {
        public DateTimeOffset UtcNow => Now;
    }

    private sealed class StubTokenGenerator : IOrganizationTokenGenerator
    {
        public string NewToken() => "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    }

    private sealed class RecordingOrganizationTelemetry : IOrganizationTelemetry
    {
        public List<OrganizationTelemetryEvent> Events { get; } = [];

        public void Track(OrganizationTelemetryEvent telemetryEvent) => Events.Add(telemetryEvent);
    }

    private sealed class MemoryOrganizationRepository : IOrganizationRepository
    {
        private readonly Dictionary<string, Organization> _organizations = [];
        private readonly Dictionary<(string OrganizationId, string Id), OrganizationInvitation>
            _invitations = [];
        private readonly Dictionary<(string OrganizationId, string Id), OrganizationTeam> _teams = [];
        private readonly List<OrganizationOffboardingTombstone> _tombstones = [];

        public Dictionary<(string OrganizationId, string PersonId), OrganizationMembership>
            Memberships
        { get; } = [];
        public InMemoryUserRepository People { get; } = new();
        public List<string> OffboardedPersonIds { get; } = [];
        public Action? BeforePrivilegedWrite { get; set; }
        public int OrganizationWriteCount { get; private set; }
        public int MembershipReadCount { get; private set; }
        public int OrganizationReadCount { get; private set; }
        public int RemainingMetricDocuments { get; private set; }
        public bool MembershipWasRemovedBeforePurge { get; private set; }
        public int FailPurgeAttempts { get; set; }
        public int TeamMembershipCount { get; private set; }
        public (int Memberships, int Organizations) ReadCounts =>
            (MembershipReadCount, OrganizationReadCount);

        public Task<OrganizationCreateResult> CreateOrganizationAsync(
            Organization organization,
            OrganizationMembership ownerMembership,
            CancellationToken cancellationToken = default)
        {
            OrganizationWriteCount++;
            if (_organizations.TryGetValue(organization.Id, out var existing))
            {
                return Task.FromResult(new OrganizationCreateResult(
                    OrganizationCreateStatus.Replayed,
                    existing));
            }
            _organizations.Add(organization.Id, organization);
            Memberships.Add(
                (ownerMembership.OrganizationId, ownerMembership.PersonId),
                ownerMembership with { ETag = "etag" });
            return Task.FromResult(new OrganizationCreateResult(
                OrganizationCreateStatus.Created,
                organization));
        }

        public Task<Organization?> GetOrganizationAsync(
            string organizationId,
            CancellationToken cancellationToken = default)
        {
            OrganizationReadCount++;
            return Task.FromResult(_organizations.GetValueOrDefault(organizationId));
        }

        public Task<OrganizationMembership?> GetMembershipAsync(
            string organizationId,
            string personId,
            CancellationToken cancellationToken = default)
        {
            MembershipReadCount++;
            return Task.FromResult(Memberships.GetValueOrDefault((organizationId, personId)));
        }

        public Task<OrganizationInvitationCreateResult> CreateInvitationAsync(
            OrganizationMembership actor,
            OrganizationInvitation invitation,
            CancellationToken cancellationToken = default)
        {
            RequireCurrent(actor);
            if (_invitations.TryGetValue((invitation.OrganizationId, invitation.Id), out var existing))
            {
                return Task.FromResult(new OrganizationInvitationCreateResult(
                    OrganizationCreateStatus.Replayed,
                    existing));
            }
            var stored = invitation with { ETag = "etag" };
            _invitations.Add((invitation.OrganizationId, invitation.Id), stored);
            return Task.FromResult(new OrganizationInvitationCreateResult(
                OrganizationCreateStatus.Created,
                stored));
        }

        public Task<OrganizationInvitation?> GetInvitationAsync(
            string organizationId,
            string invitationId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_invitations.GetValueOrDefault((organizationId, invitationId)));

        public Task<OrganizationMembership> AcceptInvitationAsync(
            OrganizationMembership issuer,
            OrganizationInvitation invitation,
            OrganizationMembership membership,
            CancellationToken cancellationToken = default)
        {
            RequireCurrent(issuer);
            _invitations[(invitation.OrganizationId, invitation.Id)] = invitation;
            var stored = membership with { ETag = "etag" };
            Memberships.Add((membership.OrganizationId, membership.PersonId), stored);
            return Task.FromResult(stored);
        }

        public Task<OrganizationTeamCreateResult> CreateTeamAsync(
            OrganizationMembership actor,
            OrganizationTeam team,
            CancellationToken cancellationToken = default)
        {
            RequireCurrent(actor);
            _teams[(team.OrganizationId, team.Id)] = team;
            return Task.FromResult(new OrganizationTeamCreateResult(
                OrganizationCreateStatus.Created,
                team));
        }

        public Task<OrganizationTeam?> GetTeamAsync(
            string organizationId,
            string teamId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_teams.GetValueOrDefault((organizationId, teamId)));

        public Task AddTeamMemberAsync(
            OrganizationMembership actor,
            OrganizationMembership target,
            OrganizationTeamMembership teamMembership,
            CancellationToken cancellationToken = default)
        {
            RequireCurrent(actor);
            RequireCurrent(target, invokeHook: false);
            TeamMembershipCount++;
            return Task.CompletedTask;
        }

        public Task OffboardAsync(
            OrganizationMembership actor,
            OrganizationMembership target,
            DateTimeOffset revokedAt,
            CancellationToken cancellationToken = default)
        {
            RequireCurrent(actor);
            RequireCurrent(target, invokeHook: false);
            var tombstone = OrganizationOffboardingTombstone.Create(target, revokedAt)
                with { ETag = $"tombstone-{target.Cycle}" };
            _tombstones.Add(tombstone);
            Memberships.Remove((target.OrganizationId, target.PersonId));
            MembershipWasRemovedBeforePurge = !Memberships.ContainsKey(
                (target.OrganizationId, target.PersonId));
            OffboardedPersonIds.Add(target.PersonId);
            return PurgeOffboardingAsync(
                target.OrganizationId,
                tombstone.Id,
                cancellationToken);
        }

        public Task PurgeOffboardingAsync(
            string organizationId,
            string tombstoneId,
            CancellationToken cancellationToken = default)
        {
            if (FailPurgeAttempts > 0)
            {
                FailPurgeAttempts--;
                throw new InvalidOperationException("simulated purge crash");
            }
            while (RemainingMetricDocuments > 0)
            {
                RemainingMetricDocuments -= Math.Min(50, RemainingMetricDocuments);
            }
            var index = _tombstones.FindIndex(item =>
                item.OrganizationId == organizationId && item.Id == tombstoneId);
            if (index >= 0)
            {
                _tombstones[index] = _tombstones[index] with
                {
                    PurgeCompletedAt = Now,
                    Ttl = 2_592_000,
                };
            }
            return Task.CompletedTask;
        }

        public Task<OrganizationOffboardingTombstone?> GetLatestOffboardingAsync(
            string organizationId,
            string personId,
            CancellationToken cancellationToken = default)
        {
            var membershipId = OrganizationDocumentIds.Membership(organizationId, personId);
            return Task.FromResult(_tombstones
                .Where(item => item.TargetMembershipId == membershipId)
                .OrderByDescending(item => item.MembershipCycle)
                .FirstOrDefault());
        }

        public Task<IReadOnlyList<OrganizationOffboardingTombstone>>
            ListIncompleteOffboardingsAsync(
                int maximumTombstones,
                CancellationToken cancellationToken = default) =>
            Task.FromResult<IReadOnlyList<OrganizationOffboardingTombstone>>(
                _tombstones
                    .Where(item => item.PurgeCompletedAt is null)
                    .Take(maximumTombstones)
                    .ToArray());

        public Task<TeamMembershipVolumetryObservation> CountTeamMembershipsAsync(
            CancellationToken cancellationToken = default) =>
            Task.FromResult(new TeamMembershipVolumetryObservation(TeamMembershipCount, Capped: false));

        public void SeedMetricDocuments(int count) => RemainingMetricDocuments = count;

        private void RequireCurrent(
            OrganizationMembership membership,
            bool invokeHook = true)
        {
            if (invokeHook)
            {
                var hook = BeforePrivilegedWrite;
                BeforePrivilegedWrite = null;
                hook?.Invoke();
            }
            if (!Memberships.TryGetValue(
                    (membership.OrganizationId, membership.PersonId),
                    out var current)
                || !string.Equals(current.ETag, membership.ETag, StringComparison.Ordinal)
                || current.Role != membership.Role)
            {
                throw new ConcurrencyConflictException(
                    "The organization membership changed before commit.");
            }
        }

        public void ResetReadCounts()
        {
            MembershipReadCount = 0;
            OrganizationReadCount = 0;
        }

        public void SeedTeam(string partitionOrganizationId, string teamId, string resourceOrganizationId)
        {
            _teams[(partitionOrganizationId, teamId)] = OrganizationTeam.Create(
                resourceOrganizationId,
                "first-owner",
                "Foreign team",
                "seed-team-key-0001",
                Now) with { Id = teamId };
        }

        public void SeedInvitation(
            string partitionOrganizationId,
            string invitationId,
            string resourceOrganizationId,
            string issuerPersonId)
        {
            _invitations[(partitionOrganizationId, invitationId)] = OrganizationInvitation.Create(
                resourceOrganizationId,
                issuerPersonId,
                "learner@example.test",
                OrganizationRole.Learner,
                "seed-invite-key-01",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                Now) with
            {
                Id = invitationId,
                ETag = "etag",
            };
        }
    }
}
