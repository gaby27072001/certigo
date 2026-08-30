using Certigo.Application.Dtos;
using Certigo.Domain.Organizations;

namespace Certigo.Application.Abstractions;

public enum OrganizationFeatureMode
{
    Off,
}

public sealed record OrganizationFeatureOptions(OrganizationFeatureMode Mode)
{
    public static OrganizationFeatureOptions Parse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)
            || string.Equals(value.Trim(), "off", StringComparison.OrdinalIgnoreCase))
        {
            return new OrganizationFeatureOptions(OrganizationFeatureMode.Off);
        }

        throw new InvalidOperationException(
            "ORGANIZATION_MEMBERSHIP_V1 only supports 'off' in this contract increment.");
    }
}

public enum OrganizationCreateStatus
{
    Created,
    Replayed,
}

public sealed record OrganizationCreateResult(
    OrganizationCreateStatus Status,
    Organization Organization);

public sealed record OrganizationInvitationCreateResult(
    OrganizationCreateStatus Status,
    OrganizationInvitation Invitation);

public sealed record OrganizationTeamCreateResult(
    OrganizationCreateStatus Status,
    OrganizationTeam Team);

public sealed record OrganizationContext(
    string OrganizationId,
    string PersonId,
    OrganizationMembership Membership);

public sealed record OrganizationAuthorizationTarget(
    string OrganizationId,
    string? PersonId = null,
    OrganizationRole? Role = null);

public interface IOrganizationPersonResolver
{
    Task<string> ResolveAsync(CancellationToken cancellationToken = default);
}

public interface IOrganizationMembershipResolver
{
    Task<OrganizationMembership> ResolveActiveAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken = default);
}

public interface IOrganizationAuthorizationHandler
{
    Task<OrganizationContext> AuthorizeAsync(
        string organizationId,
        OrganizationOperation operation,
        OrganizationAuthorizationTarget? target = null,
        CancellationToken cancellationToken = default);

    void AuthorizeMembership(
        OrganizationMembership actor,
        OrganizationOperation operation,
        OrganizationAuthorizationTarget? target = null);
}

public interface IOrganizationRepository : IOrganizationInvitationReader
{
    Task<OrganizationCreateResult> CreateOrganizationAsync(
        Organization organization,
        OrganizationMembership ownerMembership,
        CancellationToken cancellationToken = default);
    Task<Organization?> GetOrganizationAsync(
        string organizationId,
        CancellationToken cancellationToken = default);
    Task<OrganizationMembership?> GetMembershipAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken = default);
    Task<OrganizationInvitationCreateResult> CreateInvitationAsync(
        OrganizationMembership actor,
        OrganizationInvitation invitation,
        CancellationToken cancellationToken = default);
    Task<OrganizationMembership> AcceptInvitationAsync(
        OrganizationMembership issuer,
        OrganizationInvitation invitation,
        OrganizationMembership membership,
        CancellationToken cancellationToken = default);
    Task<OrganizationTeamCreateResult> CreateTeamAsync(
        OrganizationMembership actor,
        OrganizationTeam team,
        CancellationToken cancellationToken = default);
    Task<OrganizationTeam?> GetTeamAsync(
        string organizationId,
        string teamId,
        CancellationToken cancellationToken = default);
    Task AddTeamMemberAsync(
        OrganizationMembership actor,
        OrganizationMembership target,
        OrganizationTeamMembership teamMembership,
        CancellationToken cancellationToken = default);
    Task OffboardAsync(
        OrganizationMembership actor,
        OrganizationMembership target,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken = default);
    Task PurgeOffboardingAsync(
        string organizationId,
        string tombstoneId,
        CancellationToken cancellationToken = default);
    Task<OrganizationOffboardingTombstone?> GetLatestOffboardingAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken = default);
    Task<IReadOnlyList<OrganizationOffboardingTombstone>> ListIncompleteOffboardingsAsync(
        int maximumTombstones,
        CancellationToken cancellationToken = default);
}

public interface IOrganizationInvitationReader
{
    Task<OrganizationInvitation?> GetInvitationAsync(
        string organizationId,
        string invitationId,
        CancellationToken cancellationToken = default);
}

public interface IOrganizationTokenGenerator
{
    string NewToken();
}

public interface IOrganizationService
{
    Task<OrganizationDto> CreateAsync(
        string name,
        string idempotencyKey,
        CancellationToken cancellationToken = default);
    Task<OrganizationDto> GetAsync(
        string organizationId,
        CancellationToken cancellationToken = default);
    Task<OrganizationInvitationDto> InviteAsync(
        string organizationId,
        string recipientEmail,
        OrganizationRole role,
        string idempotencyKey,
        CancellationToken cancellationToken = default);
    Task<OrganizationMembershipDto> AcceptInvitationAsync(
        string organizationId,
        string invitationId,
        string token,
        CancellationToken cancellationToken = default);
    Task<OrganizationTeamDto> CreateTeamAsync(
        string organizationId,
        string name,
        string idempotencyKey,
        CancellationToken cancellationToken = default);
    Task AddTeamMemberAsync(
        string organizationId,
        string teamId,
        string personId,
        CancellationToken cancellationToken = default);
    Task<OrganizationOffboardingDto> OffboardAsync(
        string organizationId,
        string personId,
        CancellationToken cancellationToken = default);
}

public sealed class OrganizationFeatureDisabledException()
    : Exception("The organization membership V1 surface is disabled.");
