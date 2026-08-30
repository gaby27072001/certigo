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
    IUserContext userContext,
    IOrganizationRepository organizations,
    IOrganizationTokenGenerator tokenGenerator,
    IClock clock) : IOrganizationService
{
    public async Task<OrganizationDto> CreateAsync(
        string name,
        string idempotencyKey,
        CancellationToken cancellationToken = default)
    {
        var organization = Organization.Create(
            userContext.UserId,
            name,
            idempotencyKey,
            clock.UtcNow);
        var owner = OrganizationMembership.Create(
            organization.Id,
            userContext.UserId,
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
        _ = await RequireMembershipAsync(organizationId, userContext.UserId, cancellationToken);
        return ToDto(await organizations.GetOrganizationAsync(organizationId, cancellationToken)
            ?? throw new OrganizationNotFoundException());
    }

    public async Task<OrganizationInvitationDto> InviteAsync(
        string organizationId,
        string recipientEmail,
        OrganizationRole role,
        string idempotencyKey,
        CancellationToken cancellationToken = default)
    {
        var actor = await RequireMembershipAsync(
            organizationId,
            userContext.UserId,
            cancellationToken);
        if (!OrganizationAuthorization.CanInvite(actor.Role))
        {
            throw new OrganizationAccessDeniedException();
        }

        var token = tokenGenerator.NewToken();
        var candidate = OrganizationInvitation.Create(
            organizationId,
            userContext.UserId,
            recipientEmail,
            role,
            idempotencyKey,
            token,
            clock.UtcNow);
        var result = await organizations.CreateInvitationAsync(
            actor,
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
        var existing = await organizations.GetMembershipAsync(
            organizationId,
            userContext.UserId,
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
        var issuer = await RequireMembershipAsync(
            organizationId,
            invitation.CreatedByPersonId,
            cancellationToken);
        if (!OrganizationAuthorization.CanInvite(issuer.Role))
        {
            throw new OrganizationAccessDeniedException();
        }
        var accepted = invitation.Accept(userContext.UserId, token, clock.UtcNow);
        var membership = OrganizationMembership.Create(
            organizationId,
            userContext.UserId,
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
        var actor = await RequireMembershipAsync(
            organizationId,
            userContext.UserId,
            cancellationToken);
        if (!OrganizationAuthorization.CanManageTeams(actor.Role))
        {
            throw new OrganizationAccessDeniedException();
        }

        var candidate = OrganizationTeam.Create(
            organizationId,
            userContext.UserId,
            name,
            idempotencyKey,
            clock.UtcNow);
        var result = await organizations.CreateTeamAsync(actor, candidate, cancellationToken);
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
        var actor = await RequireMembershipAsync(
            organizationId,
            userContext.UserId,
            cancellationToken);
        if (!OrganizationAuthorization.CanManageTeams(actor.Role))
        {
            throw new OrganizationAccessDeniedException();
        }
        var target = await RequireMembershipAsync(organizationId, personId, cancellationToken);
        _ = await organizations.GetTeamAsync(organizationId, teamId, cancellationToken)
            ?? throw new OrganizationTeamNotFoundException();
        await organizations.AddTeamMemberAsync(
            actor,
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
        var actor = await RequireMembershipAsync(
            organizationId,
            userContext.UserId,
            cancellationToken);
        var target = await RequireMembershipAsync(organizationId, personId, cancellationToken);
        if (target.Role == OrganizationRole.Owner)
        {
            throw new OrganizationOwnerOffboardingException();
        }
        if (!string.Equals(actor.PersonId, target.PersonId, StringComparison.Ordinal)
            && !OrganizationAuthorization.CanRemove(actor.Role, target.Role))
        {
            throw new OrganizationAccessDeniedException();
        }

        await organizations.OffboardAsync(actor, target, cancellationToken);
        return new OrganizationOffboardingDto(
            organizationId,
            personId,
            clock.UtcNow);
    }

    private async Task<OrganizationMembership> RequireMembershipAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken) =>
        await organizations.GetMembershipAsync(organizationId, personId, cancellationToken)
        ?? throw new OrganizationMembershipNotFoundException();

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
