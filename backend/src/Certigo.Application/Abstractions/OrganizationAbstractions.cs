using Certigo.Application.Dtos;
using Certigo.Domain.Organizations;

namespace Certigo.Application.Abstractions;

public enum OrganizationFeatureMode
{
    Off,
    Shadow,
}

public sealed record OrganizationFeatureOptions(OrganizationFeatureMode Mode)
{
    /// <summary>
    /// True only for a mode that exposes the V1 HTTP surface to callers. Neither
    /// <see cref="OrganizationFeatureMode.Off"/> nor <see cref="OrganizationFeatureMode.Shadow"/>
    /// grants HTTP access: shadow only runs a strictly read-only background observation (see
    /// <see cref="IOrganizationShadowObservationReader"/>) and instruments existing code paths
    /// with non-PII telemetry; it adds no reachable route and performs no create/update/delete of
    /// user data. A future `read`/`write` mode is the only one expected to flip this, and — per
    /// ADR-015 — requires its own ADR.
    /// </summary>
    public bool HttpSurfaceEnabled => false;

    public static OrganizationFeatureOptions Parse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)
            || string.Equals(value.Trim(), "off", StringComparison.OrdinalIgnoreCase))
        {
            return new OrganizationFeatureOptions(OrganizationFeatureMode.Off);
        }

        if (string.Equals(value.Trim(), "shadow", StringComparison.OrdinalIgnoreCase))
        {
            return new OrganizationFeatureOptions(OrganizationFeatureMode.Shadow);
        }

        throw new InvalidOperationException(
            "ORGANIZATION_MEMBERSHIP_V1 must be either 'off' or 'shadow'.");
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

public interface IOrganizationRepository
    : IOrganizationInvitationReader, IOrganizationShadowObservationReader
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
}

public interface IOrganizationInvitationReader
{
    Task<OrganizationInvitation?> GetInvitationAsync(
        string organizationId,
        string invitationId,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Result of the bounded team-membership volumetry observation. Always a lower bound, never an
/// exact total: <see cref="Capped"/> is true when the observation hit its safety cap, meaning the
/// real count may be higher. No consumer should treat <see cref="TeamMembershipCountLowerBound"/>
/// as exact.
/// </summary>
public sealed record TeamMembershipVolumetryObservation(
    long TeamMembershipCountLowerBound,
    bool Capped);

/// <summary>
/// Strictly read-only surface consumed by the shadow observation background job
/// (<c>OrganizationShadowObservationFunctions</c>). Deliberately excludes every create/replace/
/// delete member of <see cref="IOrganizationRepository"/> so that a component depending only on
/// this interface is structurally incapable of mutating Organization/Membership data — this is
/// enforced at compile time, not merely by convention or test coverage.
/// </summary>
public interface IOrganizationShadowObservationReader
{
    Task<IReadOnlyList<OrganizationOffboardingTombstone>> ListIncompleteOffboardingsAsync(
        int maximumTombstones,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Team membership volumetry, as a lower bound capped by the implementation (a bounded
    /// query, not an unbounded full-container aggregate) so its Cosmos RU cost stays predictable
    /// regardless of how large the container grows after a future activation.
    /// </summary>
    Task<TeamMembershipVolumetryObservation> CountTeamMembershipsAsync(
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

/// <summary>
/// Operations tracked by <see cref="IOrganizationTelemetry"/>. The <c>Observe*</c> members are the
/// only ones ever emitted automatically by the live shadow runtime (via
/// <c>OrganizationShadowObservationFunctions</c>, which is strictly read-only). Every other member
/// instruments a mutating <see cref="IOrganizationRepository"/>/<see cref="IOrganizationService"/>
/// code path that is reachable only through direct unit tests and opt-in Cosmos-emulator
/// integration tests today, because the V1 HTTP surface stays disabled
/// (<see cref="OrganizationFeatureOptions.HttpSurfaceEnabled"/> is false) in every mode this
/// contract increment supports.
/// </summary>
public enum OrganizationTelemetryOperation
{
    CreateOrganization,
    CreateInvitation,
    AcceptInvitation,
    CreateTeam,
    AddTeamMember,
    Offboard,
    ObserveIncompleteOffboardings,
    ObserveTeamMembershipVolumetry,
}

public enum OrganizationTelemetryOutcome
{
    Created,
    Replayed,
    Conflict,
    Completed,
    Observed,
    Failed,
}

public sealed record OrganizationTelemetryEvent(
    OrganizationTelemetryOperation Operation,
    OrganizationTelemetryOutcome Outcome,
    DateTimeOffset OccurredAt,
    double? RequestChargeRequestUnits = null,
    long? Count = null,
    bool? Capped = null);

/// <summary>
/// Non-PII telemetry sink for Organization/Membership. Mirrors
/// <c>IPersonLinkedIdentityTelemetry</c>: bounded dimensions only (operation/outcome/RU/count),
/// never an organization id, person id, e-mail, or name.
/// </summary>
public interface IOrganizationTelemetry
{
    void Track(OrganizationTelemetryEvent telemetryEvent);
}
