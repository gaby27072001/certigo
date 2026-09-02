using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;

namespace Certigo.Domain.Organizations;

public enum OrganizationRole
{
    Owner,
    Admin,
    Manager,
    Learner,
}

public enum OrganizationInvitationStatus
{
    Pending,
    Accepted,
    Revoked,
}

public enum OrganizationOperation
{
    ViewOrganization,
    ViewMemberships,
    ChangeMembershipRole,
    CreateInvitation,
    RevokeInvitation,
    ViewTeams,
    ManageTeams,
    ViewAssignments,
    ManageAssignments,
    RecordEnterpriseMetrics,
    ViewEnterpriseMetrics,
    OffboardMembership,
}

public sealed record Organization(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string Name,
    string OwnerPersonId,
    string CreationRequestHash,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "organization";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static Organization Create(
        string ownerPersonId,
        string name,
        string idempotencyKey,
        DateTimeOffset createdAt)
    {
        OrganizationDomainRules.EnsureIdentifier(ownerPersonId, nameof(ownerPersonId));
        OrganizationDomainRules.EnsureName(name, nameof(name));
        OrganizationDomainRules.EnsureIdempotencyKey(idempotencyKey);
        var id = OrganizationDocumentIds.Organization(ownerPersonId, idempotencyKey);
        return new Organization(
            id,
            id,
            CurrentSchemaVersion,
            Type,
            name.Trim(),
            ownerPersonId,
            OrganizationDocumentIds.Hash("certigo-organization-request:v1", name.Trim()),
            createdAt,
            createdAt);
    }
}

public sealed record OrganizationMembership(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string PersonId,
    OrganizationRole Role,
    int Cycle,
    DateTimeOffset JoinedAt,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "organizationMembership";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static OrganizationMembership Create(
        string organizationId,
        string personId,
        OrganizationRole role,
        DateTimeOffset joinedAt,
        int cycle = 1)
    {
        OrganizationDomainRules.EnsureIdentifier(organizationId, nameof(organizationId));
        OrganizationDomainRules.EnsureIdentifier(personId, nameof(personId));
        return new OrganizationMembership(
            OrganizationDocumentIds.Membership(organizationId, personId),
            organizationId,
            CurrentSchemaVersion,
            Type,
            personId,
            role,
            cycle > 0
                ? cycle
                : throw new OrganizationValidationException("Membership cycle must be positive."),
            joinedAt,
            joinedAt);
    }
}

public sealed record OrganizationTeam(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string Name,
    string CreatedByPersonId,
    string CreationRequestHash,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "organizationTeam";

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static OrganizationTeam Create(
        string organizationId,
        string createdByPersonId,
        string name,
        string idempotencyKey,
        DateTimeOffset createdAt)
    {
        OrganizationDomainRules.EnsureIdentifier(organizationId, nameof(organizationId));
        OrganizationDomainRules.EnsureIdentifier(createdByPersonId, nameof(createdByPersonId));
        OrganizationDomainRules.EnsureName(name, nameof(name));
        OrganizationDomainRules.EnsureIdempotencyKey(idempotencyKey);
        return new OrganizationTeam(
            OrganizationDocumentIds.Team(organizationId, idempotencyKey),
            organizationId,
            CurrentSchemaVersion,
            Type,
            name.Trim(),
            createdByPersonId,
            OrganizationDocumentIds.Hash("certigo-team-request:v1", name.Trim()),
            createdAt,
            createdAt);
    }
}

public sealed record OrganizationTeamMembership(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string TeamId,
    string PersonId,
    string MembershipId,
    DateTimeOffset AddedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "organizationTeamMembership";

    public static OrganizationTeamMembership Create(
        string organizationId,
        string teamId,
        string personId,
        DateTimeOffset addedAt)
    {
        OrganizationDomainRules.EnsureIdentifier(organizationId, nameof(organizationId));
        OrganizationDomainRules.EnsureIdentifier(teamId, nameof(teamId));
        OrganizationDomainRules.EnsureIdentifier(personId, nameof(personId));
        return new OrganizationTeamMembership(
            OrganizationDocumentIds.TeamMembership(organizationId, teamId, personId),
            organizationId,
            CurrentSchemaVersion,
            Type,
            teamId,
            personId,
            OrganizationDocumentIds.Membership(organizationId, personId),
            addedAt);
    }
}

public sealed record OrganizationInvitation(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string TokenHash,
    string RecipientHintHash,
    OrganizationRole Role,
    OrganizationInvitationStatus Status,
    string CreatedByPersonId,
    string CreationRequestHash,
    DateTimeOffset CreatedAt,
    DateTimeOffset ExpiresAt,
    DateTimeOffset? AcceptedAt,
    string? AcceptedByPersonId,
    int Ttl)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "organizationInvitation";
    public static readonly TimeSpan DefaultLifetime = TimeSpan.FromDays(7);

    [JsonPropertyName("_etag")]
    public string? ETag { get; init; }

    public static OrganizationInvitation Create(
        string organizationId,
        string createdByPersonId,
        string recipientHint,
        OrganizationRole role,
        string idempotencyKey,
        string token,
        DateTimeOffset createdAt,
        TimeSpan? lifetime = null)
    {
        OrganizationDomainRules.EnsureIdentifier(organizationId, nameof(organizationId));
        OrganizationDomainRules.EnsureIdentifier(createdByPersonId, nameof(createdByPersonId));
        OrganizationDomainRules.EnsureRecipientHint(recipientHint);
        OrganizationDomainRules.EnsureInvitableRole(role);
        OrganizationDomainRules.EnsureIdempotencyKey(idempotencyKey);
        OrganizationDomainRules.EnsureInvitationToken(token);
        var duration = lifetime ?? DefaultLifetime;
        if (duration <= TimeSpan.Zero || duration > TimeSpan.FromDays(30))
        {
            throw new OrganizationValidationException(
                "Invitation lifetime must be between zero and 30 days.");
        }

        var canonicalHint = recipientHint.Trim().ToLowerInvariant();
        return new OrganizationInvitation(
            OrganizationDocumentIds.Invitation(organizationId, idempotencyKey),
            organizationId,
            CurrentSchemaVersion,
            Type,
            OrganizationDocumentIds.Hash("certigo-organization-invitation-token:v1", token),
            OrganizationDocumentIds.Hash("certigo-organization-recipient-hint:v1", canonicalHint),
            role,
            OrganizationInvitationStatus.Pending,
            createdByPersonId,
            OrganizationDocumentIds.Hash(
                "certigo-organization-invitation-request:v1",
                canonicalHint,
                role.ToString()),
            createdAt,
            createdAt.Add(duration),
            null,
            null,
            checked((int)Math.Ceiling(duration.TotalSeconds)));
    }

    public OrganizationInvitation Accept(
        string personId,
        string token,
        DateTimeOffset acceptedAt)
    {
        OrganizationDomainRules.EnsureIdentifier(personId, nameof(personId));
        OrganizationDomainRules.EnsureInvitationToken(token);
        if (Status != OrganizationInvitationStatus.Pending)
        {
            throw new OrganizationInvitationReplayException();
        }
        if (acceptedAt >= ExpiresAt)
        {
            throw new OrganizationInvitationExpiredException();
        }

        var presentedHash = OrganizationDocumentIds.Hash(
            "certigo-organization-invitation-token:v1",
            token);
        if (!CryptographicOperations.FixedTimeEquals(
                Convert.FromHexString(TokenHash),
                Convert.FromHexString(presentedHash)))
        {
            throw new OrganizationInvitationTokenException();
        }

        return this with
        {
            Status = OrganizationInvitationStatus.Accepted,
            AcceptedAt = acceptedAt,
            AcceptedByPersonId = personId,
            Ttl = -1,
        };
    }
}

public sealed record OrganizationInvitationReceipt(
    string Id,
    string OrganizationId,
    int SchemaVersion,
    string DocumentType,
    string InvitationId,
    string CreationRequestHash,
    DateTimeOffset CreatedAt)
{
    public const int CurrentSchemaVersion = 1;
    public const string Type = "organizationInvitationReceipt";

    public static OrganizationInvitationReceipt From(OrganizationInvitation invitation) =>
        new(
            OrganizationDocumentIds.InvitationReceipt(
                invitation.OrganizationId,
                invitation.Id),
            invitation.OrganizationId,
            CurrentSchemaVersion,
            Type,
            invitation.Id,
            invitation.CreationRequestHash,
            invitation.CreatedAt);
}

public static class OrganizationAuthorization
{
    public static bool CanInvite(OrganizationRole role) =>
        CanPerform(role, OrganizationOperation.CreateInvitation);

    public static bool CanManageTeams(OrganizationRole role) =>
        CanPerform(role, OrganizationOperation.ManageTeams);

    public static bool CanRemove(OrganizationRole actor, OrganizationRole target) =>
        actor == OrganizationRole.Owner && target != OrganizationRole.Owner
        || actor == OrganizationRole.Admin
            && target is OrganizationRole.Manager or OrganizationRole.Learner;

    public static bool CanPerform(OrganizationRole role, OrganizationOperation operation) =>
        operation switch
        {
            OrganizationOperation.ViewOrganization
                or OrganizationOperation.ViewTeams
                or OrganizationOperation.ViewAssignments
                or OrganizationOperation.RecordEnterpriseMetrics => Enum.IsDefined(role),
            OrganizationOperation.ViewMemberships
                or OrganizationOperation.ManageTeams
                or OrganizationOperation.ManageAssignments
                or OrganizationOperation.ViewEnterpriseMetrics =>
                role is OrganizationRole.Owner
                    or OrganizationRole.Admin
                    or OrganizationRole.Manager,
            OrganizationOperation.CreateInvitation
                or OrganizationOperation.RevokeInvitation
                or OrganizationOperation.ChangeMembershipRole =>
                role is OrganizationRole.Owner or OrganizationRole.Admin,
            OrganizationOperation.OffboardMembership => Enum.IsDefined(role),
            _ => false,
        };

    public static bool CanGrantInvitationRole(
        OrganizationRole actor,
        OrganizationRole requested) =>
        CanPerform(actor, OrganizationOperation.CreateInvitation)
        && requested != OrganizationRole.Owner
        && Enum.IsDefined(requested);

    public static bool CanChangeRole(
        OrganizationRole actor,
        OrganizationRole requested) =>
        actor == OrganizationRole.Owner
            && requested != OrganizationRole.Owner
            && Enum.IsDefined(requested)
        || actor == OrganizationRole.Admin
            && requested is OrganizationRole.Manager or OrganizationRole.Learner;
}

public static class OrganizationDocumentIds
{
    public static string Organization(string ownerPersonId, string idempotencyKey) =>
        $"organization::v1::{Hash("certigo-organization:v1", ownerPersonId, idempotencyKey)}";

    public static string Membership(string organizationId, string personId) =>
        $"organization-membership::v1::{Hash(
            "certigo-organization-membership:v1",
            organizationId,
            personId)}";

    public static string Team(string organizationId, string idempotencyKey) =>
        $"organization-team::v1::{Hash(
            "certigo-organization-team:v1",
            organizationId,
            idempotencyKey)}";

    public static string TeamMembership(string organizationId, string teamId, string personId) =>
        $"organization-team-membership::v1::{Hash(
            "certigo-organization-team-membership:v1",
            organizationId,
            teamId,
            personId)}";

    public static string Invitation(string organizationId, string idempotencyKey) =>
        $"organization-invitation::v1::{Hash(
            "certigo-organization-invitation:v1",
            organizationId,
            idempotencyKey)}";

    public static string InvitationReceipt(string organizationId, string invitationId) =>
        $"organization-invitation-receipt::v1::{Hash(
            "certigo-organization-invitation-receipt:v1",
            organizationId,
            invitationId)}";

    public static string Hash(params string[] values)
    {
        if (values.Any(string.IsNullOrWhiteSpace))
        {
            throw new OrganizationValidationException("Hash inputs must not be blank.");
        }
        return Convert.ToHexString(
                SHA256.HashData(Encoding.UTF8.GetBytes(string.Join("\0", values))))
            .ToLowerInvariant();
    }
}

internal static class OrganizationDomainRules
{
    public static void EnsureIdentifier(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value)
            || value != value.Trim()
            || value.Any(char.IsControl))
        {
            throw new OrganizationValidationException($"{parameterName} is invalid.");
        }
    }

    public static void EnsureName(string value, string parameterName)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Trim().Length is < 2 or > 120)
        {
            throw new OrganizationValidationException(
                $"{parameterName} must contain between 2 and 120 characters.");
        }
    }

    public static void EnsureRecipientHint(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > 320 || !value.Contains('@'))
        {
            throw new OrganizationValidationException("The invitation recipient hint is invalid.");
        }
    }

    public static void EnsureIdempotencyKey(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length is < 16 or > 200)
        {
            throw new OrganizationValidationException(
                "Idempotency-Key must contain between 16 and 200 characters.");
        }
    }

    public static void EnsureInvitationToken(string value)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length < 32)
        {
            throw new OrganizationInvitationTokenException();
        }
    }

    public static void EnsureInvitableRole(OrganizationRole role)
    {
        if (!Enum.IsDefined(role) || role == OrganizationRole.Owner)
        {
            throw new OrganizationValidationException(
                "The invitation role must be admin, manager, or learner.");
        }
    }
}

public sealed class OrganizationValidationException(string message) : Exception(message);
public sealed class OrganizationAccessDeniedException()
    : Exception("The authenticated Person is not authorized for this organization operation.");
public sealed class OrganizationNotFoundException()
    : Exception("The organization was not found.");
public sealed class OrganizationMembershipNotFoundException()
    : Exception("The organization membership was not found.");
public sealed class OrganizationPersonNotFoundException()
    : Exception("The authenticated Person was not found.");
public sealed class OrganizationTeamNotFoundException()
    : Exception("The organization team was not found.");
public sealed class OrganizationIdempotencyConflictException()
    : Exception("The idempotency key was already used with another request.");
public sealed class OrganizationInvitationReplayException()
    : Exception("The invitation was already consumed or revoked.");
public sealed class OrganizationInvitationExpiredException()
    : Exception("The invitation expired.");
public sealed class OrganizationInvitationTokenException()
    : Exception("The invitation token is invalid.");
public sealed class OrganizationOwnerOffboardingException()
    : Exception("The organization owner cannot be offboarded.");
public sealed class OrganizationOffboardingInProgressException()
    : Exception("Organization offboarding cleanup is still in progress.");
