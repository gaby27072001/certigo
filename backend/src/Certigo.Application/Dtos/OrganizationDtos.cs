using Certigo.Domain.Organizations;

namespace Certigo.Application.Dtos;

public sealed record CreateOrganizationRequest(string Name);
public sealed record CreateOrganizationInvitationRequest(string RecipientEmail, OrganizationRole Role);
public sealed record AcceptOrganizationInvitationRequest(string OrganizationId, string Token);
public sealed record CreateOrganizationTeamRequest(string Name);

public sealed record OrganizationDto(
    string Id,
    int SchemaVersion,
    string Name,
    string OwnerPersonId,
    DateTimeOffset CreatedAt);

public sealed record OrganizationMembershipDto(
    string OrganizationId,
    string PersonId,
    OrganizationRole Role,
    int Cycle,
    DateTimeOffset JoinedAt);

public sealed record OrganizationInvitationDto(
    string Id,
    string OrganizationId,
    OrganizationRole Role,
    DateTimeOffset ExpiresAt,
    string Token);

public sealed record OrganizationTeamDto(
    string Id,
    string OrganizationId,
    string Name,
    DateTimeOffset CreatedAt);

public sealed record OrganizationOffboardingDto(
    string OrganizationId,
    string PersonId,
    DateTimeOffset OffboardedAt);
