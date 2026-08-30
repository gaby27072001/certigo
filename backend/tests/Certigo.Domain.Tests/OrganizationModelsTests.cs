using Certigo.Domain.Organizations;
using FluentAssertions;
using Xunit;

namespace Certigo.Domain.Tests;

public sealed class OrganizationModelsTests
{
    private static readonly DateTimeOffset Now =
        new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

    [Fact]
    public void Document_ids_are_deterministic_and_scope_memberships_to_the_organization()
    {
        var first = Organization.Create(
            "person-1",
            "Contoso Learning",
            "1111111111111111",
            Now);
        var replay = Organization.Create(
            "person-1",
            "Contoso Learning",
            "1111111111111111",
            Now);

        first.Id.Should().Be(replay.Id);
        OrganizationDocumentIds.Membership(first.Id, "person-1")
            .Should().NotBe(OrganizationDocumentIds.Membership("another-org", "person-1"));
        first.OrganizationId.Should().Be(first.Id);
    }

    [Fact]
    public void Invitation_acceptance_uses_the_token_not_the_recipient_email()
    {
        var invitation = OrganizationInvitation.Create(
            "org-1",
            "person-admin",
            "learner@example.test",
            OrganizationRole.Learner,
            "1111111111111111",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now);

        var accepted = invitation.Accept(
            "portable-person",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now.AddMinutes(5));

        accepted.AcceptedByPersonId.Should().Be("portable-person");
        accepted.Status.Should().Be(OrganizationInvitationStatus.Accepted);
        accepted.RecipientHintHash.Should().NotContain("learner");
    }

    [Fact]
    public void Accepted_invitation_cannot_be_replayed()
    {
        var invitation = OrganizationInvitation.Create(
            "org-1",
            "person-admin",
            "learner@example.test",
            OrganizationRole.Learner,
            "1111111111111111",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now);
        var accepted = invitation.Accept(
            "person-1",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now.AddMinutes(1));

        var action = () => accepted.Accept(
            "person-1",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now.AddMinutes(2));

        action.Should().Throw<OrganizationInvitationReplayException>();
    }

    [Fact]
    public void Expired_or_wrong_token_invitation_is_rejected()
    {
        var invitation = OrganizationInvitation.Create(
            "org-1",
            "person-admin",
            "learner@example.test",
            OrganizationRole.Learner,
            "1111111111111111",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now);

        invitation.Invoking(value => value.Accept(
                "person-1",
                "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                Now.AddMinutes(1)))
            .Should().Throw<OrganizationInvitationTokenException>();
        invitation.Invoking(value => value.Accept(
                "person-1",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                Now.AddDays(8)))
            .Should().Throw<OrganizationInvitationExpiredException>();
    }

    [Theory]
    [InlineData(OrganizationRole.Owner, true, true)]
    [InlineData(OrganizationRole.Admin, true, true)]
    [InlineData(OrganizationRole.Manager, false, true)]
    [InlineData(OrganizationRole.Learner, false, false)]
    public void Minimal_roles_have_closed_permissions(
        OrganizationRole role,
        bool canInvite,
        bool canManageTeams)
    {
        OrganizationAuthorization.CanInvite(role).Should().Be(canInvite);
        OrganizationAuthorization.CanManageTeams(role).Should().Be(canManageTeams);
    }

    [Theory]
    [InlineData(OrganizationRole.Owner, true, true, true, true)]
    [InlineData(OrganizationRole.Admin, true, true, true, true)]
    [InlineData(OrganizationRole.Manager, false, true, true, true)]
    [InlineData(OrganizationRole.Learner, false, false, false, true)]
    public void Operation_matrix_is_fail_closed(
        OrganizationRole role,
        bool canManageInvitations,
        bool canManageTeams,
        bool canManageAssignments,
        bool canViewAssignments)
    {
        OrganizationAuthorization.CanPerform(role, OrganizationOperation.CreateInvitation)
            .Should().Be(canManageInvitations);
        OrganizationAuthorization.CanPerform(role, OrganizationOperation.ManageTeams)
            .Should().Be(canManageTeams);
        OrganizationAuthorization.CanPerform(role, OrganizationOperation.ManageAssignments)
            .Should().Be(canManageAssignments);
        OrganizationAuthorization.CanPerform(role, OrganizationOperation.ViewAssignments)
            .Should().Be(canViewAssignments);
    }

    [Fact]
    public void Undefined_roles_and_owner_grants_are_denied()
    {
        OrganizationAuthorization.CanPerform(
                (OrganizationRole)999,
                OrganizationOperation.ViewOrganization)
            .Should().BeFalse();
        OrganizationAuthorization.CanGrantInvitationRole(
                OrganizationRole.Admin,
                OrganizationRole.Owner)
            .Should().BeFalse();
        OrganizationAuthorization.CanChangeRole(
                OrganizationRole.Admin,
                OrganizationRole.Admin)
            .Should().BeFalse();
    }

    [Fact]
    public void Owner_role_cannot_be_invited_or_offboarded()
    {
        var invite = () => OrganizationInvitation.Create(
            "org-1",
            "person-admin",
            "owner@example.test",
            OrganizationRole.Owner,
            "1111111111111111",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now);

        invite.Should().Throw<OrganizationValidationException>();
        OrganizationAuthorization.CanRemove(OrganizationRole.Owner, OrganizationRole.Owner)
            .Should().BeFalse();
    }

    [Fact]
    public void Undefined_numeric_role_cannot_be_persisted()
    {
        var invite = () => OrganizationInvitation.Create(
            "org-1",
            "person-admin",
            "learner@example.test",
            (OrganizationRole)999,
            "1111111111111111",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            Now);

        invite.Should().Throw<OrganizationValidationException>();
    }
}
