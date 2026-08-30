using Certigo.Application.Abstractions;
using Certigo.Application.Services;
using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class OrganizationServiceTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

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

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("shadow")]
    [InlineData("enabled")]
    public void Feature_mode_is_fail_closed(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            OrganizationFeatureOptions.Parse(value).Mode.Should().Be(OrganizationFeatureMode.Off);
            return;
        }

        var action = () => OrganizationFeatureOptions.Parse(value);
        action.Should().Throw<InvalidOperationException>();
    }

    private static OrganizationService CreateService(
        string personId,
        MemoryOrganizationRepository repository) =>
        new(
            new StubUserContext(personId),
            repository,
            new StubTokenGenerator(),
            new StubClock());

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

    private sealed class MemoryOrganizationRepository : IOrganizationRepository
    {
        private readonly Dictionary<string, Organization> _organizations = [];
        private readonly Dictionary<(string OrganizationId, string Id), OrganizationInvitation>
            _invitations = [];
        private readonly Dictionary<(string OrganizationId, string Id), OrganizationTeam> _teams = [];

        public Dictionary<(string OrganizationId, string PersonId), OrganizationMembership>
            Memberships
        { get; } = [];
        public List<string> OffboardedPersonIds { get; } = [];
        public Action? BeforePrivilegedWrite { get; set; }

        public Task<OrganizationCreateResult> CreateOrganizationAsync(
            Organization organization,
            OrganizationMembership ownerMembership,
            CancellationToken cancellationToken = default)
        {
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
            CancellationToken cancellationToken = default) =>
            Task.FromResult(_organizations.GetValueOrDefault(organizationId));

        public Task<OrganizationMembership?> GetMembershipAsync(
            string organizationId,
            string personId,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(Memberships.GetValueOrDefault((organizationId, personId)));

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
            return Task.CompletedTask;
        }

        public Task OffboardAsync(
            OrganizationMembership actor,
            OrganizationMembership target,
            CancellationToken cancellationToken = default)
        {
            RequireCurrent(actor);
            RequireCurrent(target, invokeHook: false);
            Memberships.Remove((target.OrganizationId, target.PersonId));
            OffboardedPersonIds.Add(target.PersonId);
            return Task.CompletedTask;
        }

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
    }
}
