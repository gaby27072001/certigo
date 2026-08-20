using Certigo.Application.Dtos;
using Certigo.Domain.Identity;

namespace Certigo.Application.Abstractions;

public enum PersonLinkedIdentityFeatureMode
{
    Off,
    Shadow,
}

public sealed record PersonLinkedIdentityOptions(PersonLinkedIdentityFeatureMode Mode)
{
    public static PersonLinkedIdentityOptions Parse(string? value)
    {
        if (string.IsNullOrWhiteSpace(value)
            || string.Equals(value.Trim(), "off", StringComparison.OrdinalIgnoreCase))
        {
            return new PersonLinkedIdentityOptions(PersonLinkedIdentityFeatureMode.Off);
        }

        if (string.Equals(value.Trim(), "shadow", StringComparison.OrdinalIgnoreCase))
        {
            return new PersonLinkedIdentityOptions(PersonLinkedIdentityFeatureMode.Shadow);
        }

        throw new InvalidOperationException(
            "PERSON_LINKED_IDENTITY_V1 must be either 'off' or 'shadow'.");
    }
}

public sealed record LegacyIdentityObservation(
    string LegacyUserId,
    IdentityLocator Locator,
    LinkedIdentityVerification Verification);

public interface ILegacyIdentityObservationSource
{
    LegacyIdentityObservation? Current { get; }
}

public enum LinkedIdentityCreateStatus
{
    Created,
    Replayed,
}

public sealed record LinkedIdentityCreateResult(
    LinkedIdentityCreateStatus Status,
    LinkedIdentity Identity);

public sealed record AccountDeletionIdentityCleanupResult(
    int TombstonedIdentities,
    int DeletedJournals);

public interface IPersonLinkedIdentityRepository
{
    Task<LinkedIdentity?> GetAsync(
        IdentityLocator locator,
        CancellationToken cancellationToken = default);

    Task<LinkedIdentityCreateResult> CreateOrReadAsync(
        LinkedIdentity identity,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<LinkedIdentity>> ListByPersonAsync(
        string personId,
        CancellationToken cancellationToken = default);

    Task<AccountDeletionIdentityCleanupResult> CleanupForAccountDeletionAsync(
        string personId,
        DateTimeOffset revokedAt,
        CancellationToken cancellationToken = default);
}

public interface IIdentitySubjectGenerator
{
    string NewSubject();
}

public enum PersonIdentityTelemetryOperation
{
    PersonMigration,
    LocalSubjectMigration,
    IdentityMirror,
    Reconciliation,
    AccountDeletionCleanup,
}

public enum PersonIdentityTelemetryOutcome
{
    Created,
    Replayed,
    Matched,
    Skipped,
    Conflict,
    Failed,
}

public sealed record PersonIdentityTelemetryEvent(
    PersonIdentityTelemetryOperation Operation,
    PersonIdentityTelemetryOutcome Outcome,
    DateTimeOffset OccurredAt,
    string? Provider = null,
    string? IdentityType = null,
    string? FailureCode = null,
    string? ExceptionType = null);

public interface IPersonLinkedIdentityTelemetry
{
    void Track(PersonIdentityTelemetryEvent telemetryEvent);
}

public interface IPersonLinkedIdentityShadowRuntime
{
    Task<UserProfileDto> TryMirrorProfileAsync(
        IUserRepository profiles,
        UserProfileDto profile,
        LegacyIdentityObservation? observation,
        CancellationToken cancellationToken = default);

    Task TryMirrorLocalAsync(
        string personId,
        UserCredentialRecord credential,
        CancellationToken cancellationToken = default);
}

public sealed class IdentityAlreadyLinkedException()
    : Exception("The identity is already linked to another Person.");

public sealed class IdentityHashCollisionException()
    : Exception("The deterministic identity hash resolved to another locator.");
