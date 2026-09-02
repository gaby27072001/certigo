using System.Security.Cryptography;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Identity;

namespace Certigo.Application.Services;

public sealed class CryptographicIdentitySubjectGenerator : IIdentitySubjectGenerator
{
    private const int SubjectBytes = 16;

    public string NewSubject() =>
        Convert.ToHexString(RandomNumberGenerator.GetBytes(SubjectBytes))
            .ToLowerInvariant();
}

public sealed class PersonLinkedIdentityShadowService(
    PersonLinkedIdentityOptions options,
    IPersonLinkedIdentityRepository identities,
    IUserCredentialRepository credentials,
    IIdentitySubjectGenerator subjectGenerator,
    IClock clock,
    IPersonLinkedIdentityTelemetry telemetry) : IPersonLinkedIdentityShadowRuntime
{
    private const int MaximumConcurrencyAttempts = 5;

    public async Task<UserProfileDto> TryMirrorProfileAsync(
        IUserRepository profiles,
        UserProfileDto profile,
        LegacyIdentityObservation? observation,
        CancellationToken cancellationToken = default)
    {
        if (options.Mode == PersonLinkedIdentityFeatureMode.Off)
        {
            return profile;
        }

        var visibleProfile = profile;
        try
        {
            (visibleProfile, var migrationOutcome) = await EnsurePersonMetadataAsync(
                profiles,
                profile,
                cancellationToken);
            telemetry.Track(new PersonIdentityTelemetryEvent(
                PersonIdentityTelemetryOperation.PersonMigration,
                migrationOutcome,
                clock.UtcNow));

            if (observation is null
                || !string.Equals(
                    observation.LegacyUserId,
                    visibleProfile.Id,
                    StringComparison.Ordinal))
            {
                return visibleProfile;
            }

            await MirrorIdentityAsync(
                visibleProfile.Id,
                observation.Locator,
                observation.Verification,
                cancellationToken);
            return visibleProfile;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (IdentityAlreadyLinkedException ex)
        {
            TrackFailure(
                PersonIdentityTelemetryOperation.Reconciliation,
                observation?.Locator,
                PersonIdentityTelemetryOutcome.Conflict,
                "identity_already_linked",
                ex);
            return visibleProfile;
        }
        catch (IdentityHashCollisionException ex)
        {
            TrackFailure(
                PersonIdentityTelemetryOperation.Reconciliation,
                observation?.Locator,
                PersonIdentityTelemetryOutcome.Conflict,
                "identity_hash_collision",
                ex);
            return visibleProfile;
        }
        catch (Exception ex)
        {
            TrackFailure(
                PersonIdentityTelemetryOperation.IdentityMirror,
                observation?.Locator,
                PersonIdentityTelemetryOutcome.Failed,
                "shadow_write_failed",
                ex);
            return visibleProfile;
        }
    }

    public async Task TryMirrorLocalAsync(
        string personId,
        UserCredentialRecord credential,
        CancellationToken cancellationToken = default)
    {
        if (options.Mode == PersonLinkedIdentityFeatureMode.Off)
        {
            return;
        }

        IdentityLocator? locator = null;
        try
        {
            var migratedCredential = await EnsureLocalSubjectAsync(
                personId,
                credential,
                cancellationToken);
            var subject = migratedCredential.IdentitySubject
                ?? throw new PersonIdentityIntegrityException();
            locator = new IdentityLocator(
                IdentityLocator.LocalProvider,
                IdentityLocator.LocalTenant,
                subject,
                IdentityLocator.LocalPasswordType).EnsureCanonical();
            var now = clock.UtcNow;
            await MirrorIdentityAsync(
                personId,
                locator,
                new LinkedIdentityVerification(
                    LinkedIdentityVerification.VerifiedState,
                    LinkedIdentityVerification.LegacyCredentialBackfillMethod,
                    now,
                    now,
                    Issuer: null,
                    Audience: null),
                cancellationToken);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            throw;
        }
        catch (IdentityAlreadyLinkedException ex)
        {
            TrackFailure(
                PersonIdentityTelemetryOperation.Reconciliation,
                locator,
                PersonIdentityTelemetryOutcome.Conflict,
                "identity_already_linked",
                ex);
        }
        catch (IdentityHashCollisionException ex)
        {
            TrackFailure(
                PersonIdentityTelemetryOperation.Reconciliation,
                locator,
                PersonIdentityTelemetryOutcome.Conflict,
                "identity_hash_collision",
                ex);
        }
        catch (Exception ex)
        {
            TrackFailure(
                PersonIdentityTelemetryOperation.IdentityMirror,
                locator,
                PersonIdentityTelemetryOutcome.Failed,
                "shadow_write_failed",
                ex);
        }
    }

    private async Task<(UserProfileDto Profile, PersonIdentityTelemetryOutcome Outcome)>
        EnsurePersonMetadataAsync(
            IUserRepository profiles,
            UserProfileDto profile,
            CancellationToken cancellationToken)
    {
        var current = profile;
        for (var attempt = 1; attempt <= MaximumConcurrencyAttempts; attempt++)
        {
            if (current.IdentityMetadata is not null)
            {
                current.IdentityMetadata.EnsureConsistentWith(current.Id);
                return (current, PersonIdentityTelemetryOutcome.Replayed);
            }

            var candidate = current with
            {
                IdentityMetadata = PersonIdentityMetadata.Shadow(current.Id, clock.UtcNow),
            };
            try
            {
                return (
                    await profiles.UpsertAsync(candidate, cancellationToken),
                    PersonIdentityTelemetryOutcome.Created);
            }
            catch (ConcurrencyConflictException) when (attempt < MaximumConcurrencyAttempts)
            {
                current = await profiles.GetAsync(profile.Id, cancellationToken)
                    ?? throw new PersonIdentityIntegrityException();
            }
        }

        throw new ConcurrencyConflictException(
            "The Person identity overlay changed repeatedly; retry the shadow migration.");
    }

    private async Task<UserCredentialRecord> EnsureLocalSubjectAsync(
        string personId,
        UserCredentialRecord credential,
        CancellationToken cancellationToken)
    {
        string? generatedSubject = null;
        for (var attempt = 1; attempt <= MaximumConcurrencyAttempts; attempt++)
        {
            var current = await credentials.FindByEmailAsync(
                credential.Email,
                cancellationToken)
                ?? throw new PersonIdentityIntegrityException();
            if (!string.Equals(current.Id, credential.Id, StringComparison.Ordinal)
                || !string.Equals(current.UserId, personId, StringComparison.Ordinal))
            {
                // Email lookup is only a point-read mechanism for the exact credential;
                // it is never accepted as evidence that two identities are equivalent.
                throw new PersonIdentityIntegrityException();
            }

            if (!string.IsNullOrWhiteSpace(current.IdentitySubject))
            {
                _ = new IdentityLocator(
                    IdentityLocator.LocalProvider,
                    IdentityLocator.LocalTenant,
                    current.IdentitySubject,
                    IdentityLocator.LocalPasswordType).EnsureCanonical();
                telemetry.Track(new PersonIdentityTelemetryEvent(
                    PersonIdentityTelemetryOperation.LocalSubjectMigration,
                    PersonIdentityTelemetryOutcome.Replayed,
                    clock.UtcNow,
                    IdentityLocator.LocalProvider,
                    IdentityLocator.LocalPasswordType));
                return current;
            }

            try
            {
                generatedSubject ??= subjectGenerator.NewSubject();
                var updated = current with { IdentitySubject = generatedSubject };
                await credentials.UpdateAsync(updated, cancellationToken);
                telemetry.Track(new PersonIdentityTelemetryEvent(
                    PersonIdentityTelemetryOperation.LocalSubjectMigration,
                    PersonIdentityTelemetryOutcome.Created,
                    clock.UtcNow,
                    IdentityLocator.LocalProvider,
                    IdentityLocator.LocalPasswordType));
                return updated;
            }
            catch (ConcurrencyConflictException) when (attempt < MaximumConcurrencyAttempts)
            {
                // Another writer may have persisted the subject. Re-read the exact
                // credential and use that winner rather than generating a new identity.
            }
        }

        throw new ConcurrencyConflictException(
            "The local identity subject changed repeatedly; retry the shadow migration.");
    }

    private async Task MirrorIdentityAsync(
        string personId,
        IdentityLocator locator,
        LinkedIdentityVerification verification,
        CancellationToken cancellationToken)
    {
        var candidate = LinkedIdentity.Create(personId, locator, verification, clock.UtcNow);
        var result = await identities.CreateOrReadAsync(candidate, cancellationToken);
        if (!string.Equals(result.Identity.PersonId, personId, StringComparison.Ordinal))
        {
            throw new IdentityAlreadyLinkedException();
        }
        if (result.Identity.Locator != locator)
        {
            throw new IdentityHashCollisionException();
        }

        telemetry.Track(new PersonIdentityTelemetryEvent(
            PersonIdentityTelemetryOperation.IdentityMirror,
            result.Status == LinkedIdentityCreateStatus.Created
                ? PersonIdentityTelemetryOutcome.Created
                : PersonIdentityTelemetryOutcome.Replayed,
            clock.UtcNow,
            locator.Provider,
            locator.Type));
        telemetry.Track(new PersonIdentityTelemetryEvent(
            PersonIdentityTelemetryOperation.Reconciliation,
            PersonIdentityTelemetryOutcome.Matched,
            clock.UtcNow,
            locator.Provider,
            locator.Type));
    }

    private void TrackFailure(
        PersonIdentityTelemetryOperation operation,
        IdentityLocator? locator,
        PersonIdentityTelemetryOutcome outcome,
        string failureCode,
        Exception exception)
    {
        telemetry.Track(new PersonIdentityTelemetryEvent(
            operation,
            outcome,
            clock.UtcNow,
            locator?.Provider,
            locator?.Type,
            failureCode,
            exception.GetType().Name));
    }
}

public sealed class PersonLinkedIdentityShadowUserRepository(
    IUserRepository inner,
    IPersonLinkedIdentityShadowRuntime shadowRuntime,
    ILegacyIdentityObservationSource observations) : IUserRepository
{
    public async Task<UserProfileDto?> GetAsync(
        string userId,
        CancellationToken cancellationToken = default)
    {
        var profile = await inner.GetAsync(userId, cancellationToken);
        return profile is null
            ? null
            : await shadowRuntime.TryMirrorProfileAsync(
                inner,
                profile,
                observations.Current,
                cancellationToken);
    }

    public async Task<UserProfileDto?> FindByHandleAsync(
        string handle,
        CancellationToken cancellationToken = default)
    {
        var profile = await inner.FindByHandleAsync(handle, cancellationToken);
        return profile is null
            ? null
            : await shadowRuntime.TryMirrorProfileAsync(
                inner,
                profile,
                observations.Current,
                cancellationToken);
    }

    public async Task<UserProfileDto> UpsertAsync(
        UserProfileDto profile,
        CancellationToken cancellationToken = default)
    {
        var stored = await inner.UpsertAsync(profile, cancellationToken);
        return await shadowRuntime.TryMirrorProfileAsync(
            inner,
            stored,
            observations.Current,
            cancellationToken);
    }
}
