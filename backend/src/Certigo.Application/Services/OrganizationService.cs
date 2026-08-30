using System.Security.Cryptography;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Organizations;

namespace Certigo.Application.Services;

public sealed class CryptographicOrganizationTokenGenerator : IOrganizationTokenGenerator
{
    private const int TokenBytes = 32;

    public string NewToken() =>
        Convert.ToHexString(RandomNumberGenerator.GetBytes(TokenBytes)).ToLowerInvariant();
}

public sealed class OrganizationService(
    IOrganizationPersonResolver people,
    IOrganizationMembershipResolver memberships,
    IOrganizationAuthorizationHandler authorization,
    IOrganizationRepository organizations,
    IOrganizationTokenGenerator tokenGenerator,
    IClock clock) : IOrganizationService
{
    public async Task<OrganizationDto> CreateAsync(
        string name,
        string idempotencyKey,
        CancellationToken cancellationToken = default)
    {
        var personId = await people.ResolveAsync(cancellationToken);
        var organization = Organization.Create(
            personId,
            name,
            idempotencyKey,
            clock.UtcNow);
        var owner = OrganizationMembership.Create(
            organization.Id,
            personId,
            OrganizationRole.Owner,
            clock.UtcNow);
        var result = await organizations.CreateOrganizationAsync(
            organization,
            owner,
            cancellationToken);
        if (!string.Equals(
                result.Organization.CreationRequestHash,
                organization.CreationRequestHash,
                StringComparison.Ordinal))
        {
            throw new OrganizationIdempotencyConflictException();
        }
        return ToDto(result.Organization);
    }

    public async Task<OrganizationDto> GetAsync(
        string organizationId,
        CancellationToken cancellationToken = default)
    {
        _ = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ViewOrganization,
            cancellationToken: cancellationToken);
        var organization = await organizations.GetOrganizationAsync(
            organizationId,
            cancellationToken) ?? throw new OrganizationNotFoundException();
        OrganizationAuthorizationHandler.EnsureOrganization(
            organizationId,
            organization.OrganizationId);
        return ToDto(organization);
    }

    public async Task<OrganizationInvitationDto> InviteAsync(
        string organizationId,
        string recipientEmail,
        OrganizationRole role,
        string idempotencyKey,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.CreateInvitation,
            new OrganizationAuthorizationTarget(organizationId, Role: role),
            cancellationToken);

        var token = tokenGenerator.NewToken();
        var candidate = OrganizationInvitation.Create(
            organizationId,
            context.PersonId,
            recipientEmail,
            role,
            idempotencyKey,
            token,
            clock.UtcNow);
        var result = await organizations.CreateInvitationAsync(
            context.Membership,
            candidate,
            cancellationToken);
        if (!string.Equals(
                result.Invitation.CreationRequestHash,
                candidate.CreationRequestHash,
                StringComparison.Ordinal))
        {
            throw new OrganizationIdempotencyConflictException();
        }
        if (result.Status == OrganizationCreateStatus.Replayed)
        {
            // Invitation secrets are returned only at creation and cannot be recovered.
            throw new OrganizationInvitationReplayException();
        }
        return new OrganizationInvitationDto(
            result.Invitation.Id,
            organizationId,
            role,
            result.Invitation.ExpiresAt,
            token);
    }

    public async Task<OrganizationMembershipDto> AcceptInvitationAsync(
        string organizationId,
        string invitationId,
        string token,
        CancellationToken cancellationToken = default)
    {
        var personId = await people.ResolveAsync(cancellationToken);
        var existing = await organizations.GetMembershipAsync(
            organizationId,
            personId,
            cancellationToken);
        if (existing is not null)
        {
            throw new OrganizationInvitationReplayException();
        }

        var invitation = await organizations.GetInvitationAsync(
            organizationId,
            invitationId,
            cancellationToken)
            ?? throw new OrganizationInvitationTokenException();
        OrganizationAuthorizationHandler.EnsureOrganization(
            organizationId,
            invitation.OrganizationId);
        var issuer = await memberships.ResolveActiveAsync(
            organizationId,
            invitation.CreatedByPersonId,
            cancellationToken);
        authorization.AuthorizeMembership(
            issuer,
            OrganizationOperation.CreateInvitation,
            new OrganizationAuthorizationTarget(organizationId, Role: invitation.Role));
        var accepted = invitation.Accept(personId, token, clock.UtcNow);
        var membership = OrganizationMembership.Create(
            organizationId,
            personId,
            accepted.Role,
            clock.UtcNow);
        var stored = await organizations.AcceptInvitationAsync(
            issuer,
            accepted,
            membership,
            cancellationToken);
        return ToDto(stored);
    }

    public async Task<OrganizationTeamDto> CreateTeamAsync(
        string organizationId,
        string name,
        string idempotencyKey,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ManageTeams,
            cancellationToken: cancellationToken);

        var candidate = OrganizationTeam.Create(
            organizationId,
            context.PersonId,
            name,
            idempotencyKey,
            clock.UtcNow);
        var result = await organizations.CreateTeamAsync(
            context.Membership,
            candidate,
            cancellationToken);
        if (!string.Equals(
                result.Team.CreationRequestHash,
                candidate.CreationRequestHash,
                StringComparison.Ordinal))
        {
            throw new OrganizationIdempotencyConflictException();
        }
        return ToDto(result.Team);
    }

    public async Task AddTeamMemberAsync(
        string organizationId,
        string teamId,
        string personId,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ManageTeams,
            cancellationToken: cancellationToken);
        var target = await memberships.ResolveActiveAsync(
            organizationId,
            personId,
            cancellationToken);
        var team = await organizations.GetTeamAsync(organizationId, teamId, cancellationToken)
            ?? throw new OrganizationTeamNotFoundException();
        OrganizationAuthorizationHandler.EnsureOrganization(organizationId, team.OrganizationId);
        await organizations.AddTeamMemberAsync(
            context.Membership,
            target,
            OrganizationTeamMembership.Create(
                organizationId,
                teamId,
                personId,
                clock.UtcNow),
            cancellationToken);
    }

    public async Task<OrganizationOffboardingDto> OffboardAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken = default)
    {
        var context = await authorization.AuthorizeAsync(
            organizationId,
            OrganizationOperation.ViewOrganization,
            cancellationToken: cancellationToken);
        var target = await memberships.ResolveActiveAsync(
            organizationId,
            personId,
            cancellationToken);
        authorization.AuthorizeMembership(
            context.Membership,
            OrganizationOperation.OffboardMembership,
            new OrganizationAuthorizationTarget(
                target.OrganizationId,
                target.PersonId,
                target.Role));

        await organizations.OffboardAsync(context.Membership, target, cancellationToken);
        return new OrganizationOffboardingDto(
            organizationId,
            personId,
            clock.UtcNow);
    }

    private static OrganizationDto ToDto(Organization organization) =>
        new(
            organization.Id,
            organization.SchemaVersion,
            organization.Name,
            organization.OwnerPersonId,
            organization.CreatedAt);

    private static OrganizationMembershipDto ToDto(OrganizationMembership membership) =>
        new(
            membership.OrganizationId,
            membership.PersonId,
            membership.Role,
            membership.JoinedAt);

    private static OrganizationTeamDto ToDto(OrganizationTeam team) =>
        new(team.Id, team.OrganizationId, team.Name, team.CreatedAt);
}
