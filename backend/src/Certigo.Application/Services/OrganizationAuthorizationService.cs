using Certigo.Application.Abstractions;
using Certigo.Domain.Identity;
using Certigo.Domain.Organizations;

namespace Certigo.Application.Services;

public sealed class OrganizationPersonResolver(
    IUserContext userContext,
    IUserRepository people) : IOrganizationPersonResolver
{
    public async Task<string> ResolveAsync(CancellationToken cancellationToken = default)
    {
        var authenticatedId = userContext.UserId;
        var person = await people.GetAsync(authenticatedId, cancellationToken);
        if (person is null
            || !string.Equals(person.Id, authenticatedId, StringComparison.Ordinal))
        {
            throw new OrganizationPersonNotFoundException();
        }

        try
        {
            person.IdentityMetadata?.EnsureConsistentWith(person.Id);
        }
        catch (PersonIdentityIntegrityException)
        {
            throw new OrganizationPersonNotFoundException();
        }

        return person.Id;
    }
}

public sealed class OrganizationMembershipResolver(
    IOrganizationRepository organizations) : IOrganizationMembershipResolver
{
    public async Task<OrganizationMembership> ResolveActiveAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken = default)
    {
        var membership = await organizations.GetMembershipAsync(
            organizationId,
            personId,
            cancellationToken);
        if (membership is null
            || !string.Equals(membership.OrganizationId, organizationId, StringComparison.Ordinal)
            || !string.Equals(membership.PersonId, personId, StringComparison.Ordinal)
            || !string.Equals(
                membership.Id,
                OrganizationDocumentIds.Membership(organizationId, personId),
                StringComparison.Ordinal)
            || membership.SchemaVersion != OrganizationMembership.CurrentSchemaVersion
            || membership.DocumentType != OrganizationMembership.Type
            || !Enum.IsDefined(membership.Role)
            || membership.Cycle <= 0
            || string.IsNullOrWhiteSpace(membership.ETag))
        {
            throw new OrganizationMembershipNotFoundException();
        }

        return membership;
    }
}

public sealed class OrganizationAuthorizationHandler(
    IOrganizationPersonResolver people,
    IOrganizationMembershipResolver memberships) : IOrganizationAuthorizationHandler
{
    public async Task<OrganizationContext> AuthorizeAsync(
        string organizationId,
        OrganizationOperation operation,
        OrganizationAuthorizationTarget? target = null,
        CancellationToken cancellationToken = default)
    {
        var personId = await people.ResolveAsync(cancellationToken);
        var membership = await memberships.ResolveActiveAsync(
            organizationId,
            personId,
            cancellationToken);
        AuthorizeMembership(membership, operation, target);
        return new OrganizationContext(organizationId, personId, membership);
    }

    public void AuthorizeMembership(
        OrganizationMembership actor,
        OrganizationOperation operation,
        OrganizationAuthorizationTarget? target = null)
    {
        EnsureOrganization(actor.OrganizationId, target?.OrganizationId);
        if (!OrganizationAuthorization.CanPerform(actor.Role, operation))
        {
            throw new OrganizationAccessDeniedException();
        }

        if (operation == OrganizationOperation.CreateInvitation
            && target?.Role is { } invitationRole
            && !OrganizationAuthorization.CanGrantInvitationRole(actor.Role, invitationRole))
        {
            throw new OrganizationAccessDeniedException();
        }

        if (operation == OrganizationOperation.ChangeMembershipRole
            && target?.Role is { } membershipRole
            && !OrganizationAuthorization.CanChangeRole(actor.Role, membershipRole))
        {
            throw new OrganizationAccessDeniedException();
        }

        if (operation == OrganizationOperation.OffboardMembership)
        {
            AuthorizeOffboarding(actor, target);
        }
    }

    public static void EnsureOrganization(string expected, string? actual)
    {
        if (actual is not null
            && !string.Equals(expected, actual, StringComparison.Ordinal))
        {
            throw new OrganizationNotFoundException();
        }
    }

    private static void AuthorizeOffboarding(
        OrganizationMembership actor,
        OrganizationAuthorizationTarget? target)
    {
        if (target?.PersonId is null || target.Role is null)
        {
            throw new OrganizationAccessDeniedException();
        }
        if (target.Role == OrganizationRole.Owner)
        {
            throw new OrganizationOwnerOffboardingException();
        }

        var self = string.Equals(actor.PersonId, target.PersonId, StringComparison.Ordinal);
        if (!self && !OrganizationAuthorization.CanRemove(actor.Role, target.Role.Value))
        {
            throw new OrganizationAccessDeniedException();
        }
    }
}
