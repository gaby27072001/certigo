using System.Text.Json;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Identity;
using FluentAssertions;
using Xunit;

namespace Certigo.Application.Tests;

public sealed class PersonLinkedIdentityShadowServiceTests
{
    private const string PersonId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    private const string OtherPersonId = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
    private const string Tenant = "11111111-1111-4111-8111-aaaaaaaaaaaa";
    private const string Subject = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
    private const string LocalSubject = "0123456789abcdef0123456789abcdef";

    private static readonly DateTimeOffset Now =
        new(2026, 8, 20, 12, 0, 0, TimeSpan.Zero);

    [Theory]
    [InlineData(null, PersonLinkedIdentityFeatureMode.Off)]
    [InlineData("", PersonLinkedIdentityFeatureMode.Off)]
    [InlineData("off", PersonLinkedIdentityFeatureMode.Off)]
    [InlineData("SHADOW", PersonLinkedIdentityFeatureMode.Shadow)]
    public void Feature_mode_accepts_only_off_and_shadow(
        string? configured,
        PersonLinkedIdentityFeatureMode expected)
    {
        PersonLinkedIdentityOptions.Parse(configured).Mode.Should().Be(expected);
    }

    [Theory]
    [InlineData("resolve")]
    [InlineData("link")]
    [InlineData("enabled")]
    public void Future_or_unknown_feature_modes_fail_fast(string configured)
    {
        var action = () => PersonLinkedIdentityOptions.Parse(configured);

        action.Should().Throw<InvalidOperationException>()
            .WithMessage("*off*shadow*");
    }

    [Fact]
    public async Task Off_mode_preserves_the_legacy_profile_without_shadow_writes()
    {
        var rawProfiles = new InMemoryUserRepository();
        rawProfiles.Seed(Profile(PersonId));
        var identities = new FakePersonLinkedIdentityRepository();
        var telemetry = new CapturingPersonIdentityTelemetry();
        var repository = BuildRepository(
            PersonLinkedIdentityFeatureMode.Off,
            rawProfiles,
            identities,
            telemetry,
            Observation());

        var loaded = await repository.GetAsync(PersonId);

        loaded!.IdentityMetadata.Should().BeNull();
        identities.Stored.Should().BeEmpty();
        telemetry.Events.Should().BeEmpty();
        (await rawProfiles.GetAsync(PersonId))!.IdentityMetadata.Should().BeNull();
    }

    [Fact]
    public async Task Shadow_read_migrates_person_and_mirrors_validated_external_identity()
    {
        var rawProfiles = new InMemoryUserRepository();
        var original = rawProfiles.Seed(Profile(PersonId))!;
        var identities = new FakePersonLinkedIdentityRepository();
        var telemetry = new CapturingPersonIdentityTelemetry();
        var repository = BuildRepository(
            PersonLinkedIdentityFeatureMode.Shadow,
            rawProfiles,
            identities,
            telemetry,
            Observation());

        var loaded = await repository.GetAsync(PersonId);

        loaded!.IdentityMetadata.Should().NotBeNull();
        loaded.IdentityMetadata!.PersonId.Should().Be(PersonId);
        loaded.IdentityMetadata.LegacyUserId.Should().Be(PersonId);
        loaded.Id.Should().Be(PersonId);
        loaded.Xp.Should().Be(original.Xp);
        loaded.Gems.Should().Be(original.Gems);
        identities.Stored.Should().ContainSingle();
        identities.Stored.Single().PersonId.Should().Be(PersonId);
        identities.Stored.Single().Locator.Should().Be(Observation().Locator);
        telemetry.Events.Should().Contain(entry =>
            entry.Operation == PersonIdentityTelemetryOperation.Reconciliation
            && entry.Outcome == PersonIdentityTelemetryOutcome.Matched);
    }

    [Fact]
    public async Task Exact_shadow_replay_is_idempotent()
    {
        var rawProfiles = new InMemoryUserRepository();
        rawProfiles.Seed(Profile(PersonId));
        var identities = new FakePersonLinkedIdentityRepository();
        var telemetry = new CapturingPersonIdentityTelemetry();
        var repository = BuildRepository(
            PersonLinkedIdentityFeatureMode.Shadow,
            rawProfiles,
            identities,
            telemetry,
            Observation());

        var first = await repository.GetAsync(PersonId);
        var replay = await repository.GetAsync(PersonId);

        replay!.IdentityMetadata.Should().Be(first!.IdentityMetadata);
        identities.Stored.Should().ContainSingle();
        identities.CreateCalls.Should().Be(2);
        telemetry.Events.Should().Contain(entry =>
            entry.Operation == PersonIdentityTelemetryOperation.IdentityMirror
            && entry.Outcome == PersonIdentityTelemetryOutcome.Replayed);
    }

    [Fact]
    public async Task Profile_overlay_retry_preserves_a_concurrent_profile_update()
    {
        var rawProfiles = new InMemoryUserRepository();
        var original = rawProfiles.Seed(Profile(PersonId))!;
        var concurrentProfiles = new BumpThenConflictUserRepository(
            rawProfiles,
            profile => profile with { Gems = profile.Gems + 17 });
        var identities = new FakePersonLinkedIdentityRepository();
        var telemetry = new CapturingPersonIdentityTelemetry();
        var repository = BuildRepository(
            PersonLinkedIdentityFeatureMode.Shadow,
            concurrentProfiles,
            identities,
            telemetry,
            Observation());

        var loaded = await repository.GetAsync(PersonId);

        loaded!.Gems.Should().Be(original.Gems + 17);
        loaded.IdentityMetadata!.PersonId.Should().Be(PersonId);
        concurrentProfiles.UpsertCalls.Should().Be(2);
        var persisted = await rawProfiles.GetAsync(PersonId);
        persisted!.Gems.Should().Be(original.Gems + 17);
        persisted.IdentityMetadata.Should().NotBeNull();
    }

    [Fact]
    public async Task Local_migration_persists_one_opaque_subject_and_never_uses_email()
    {
        var credentialId = UserCredentialRecord.CanonicalIdFor("shared@example.com");
        var credentialStore = new FakeCredentialRepository();
        var credential = credentialStore.Seed(new UserCredentialRecord(
            credentialId,
            "shared@example.com",
            PersonId,
            "Learner",
            "hash",
            Now,
            ProvisioningState: CredentialProvisioningState.Active));
        var identities = new FakePersonLinkedIdentityRepository();
        var telemetry = new CapturingPersonIdentityTelemetry();
        var generator = new FixedSubjectGenerator(LocalSubject);
        var runtime = BuildRuntime(
            PersonLinkedIdentityFeatureMode.Shadow,
            identities,
            credentialStore,
            telemetry,
            generator);

        await runtime.TryMirrorLocalAsync(PersonId, credential);
        await runtime.TryMirrorLocalAsync(PersonId, credential);

        var persisted = await credentialStore.FindByEmailAsync("shared@example.com");
        persisted!.IdentitySubject.Should().Be(LocalSubject);
        generator.Calls.Should().Be(1);
        identities.Stored.Should().ContainSingle();
        identities.Stored.Single().Locator.Subject.Should().Be(LocalSubject);
        identities.Stored.Single().Id.Should().NotContain("shared");
        identities.Stored.Single().Id.Should().NotContain("@");
    }

    [Fact]
    public async Task Local_subject_retry_uses_the_concurrent_winner_without_clobbering_it()
    {
        const string winningSubject = "abcdef0123456789abcdef0123456789";
        var credentialId = UserCredentialRecord.CanonicalIdFor("race@example.com");
        var innerCredentials = new FakeCredentialRepository();
        var credential = innerCredentials.Seed(new UserCredentialRecord(
            credentialId,
            "race@example.com",
            PersonId,
            "Learner",
            "hash",
            Now,
            ProvisioningState: CredentialProvisioningState.Active));
        var credentials = new ConcurrentSubjectCredentialRepository(
            innerCredentials,
            winningSubject);
        var identities = new FakePersonLinkedIdentityRepository();
        var telemetry = new CapturingPersonIdentityTelemetry();
        var generator = new FixedSubjectGenerator(LocalSubject);
        var runtime = BuildRuntime(
            PersonLinkedIdentityFeatureMode.Shadow,
            identities,
            credentials,
            telemetry,
            generator);

        await runtime.TryMirrorLocalAsync(PersonId, credential);

        (await innerCredentials.FindByEmailAsync("race@example.com"))!
            .IdentitySubject.Should().Be(winningSubject);
        identities.Stored.Should().ContainSingle()
            .Which.Locator.Subject.Should().Be(winningSubject);
        generator.Calls.Should().Be(1);
        telemetry.Events.Should().Contain(entry =>
            entry.Operation == PersonIdentityTelemetryOperation.LocalSubjectMigration
            && entry.Outcome == PersonIdentityTelemetryOutcome.Replayed);
    }

    [Fact]
    public async Task Email_lookup_can_never_merge_a_different_credential()
    {
        var supplied = new UserCredentialRecord(
            "credential::expected",
            "shared@example.com",
            PersonId,
            "Learner",
            "hash",
            Now,
            ProvisioningState: CredentialProvisioningState.Active);
        var credentialStore = new FakeCredentialRepository();
        credentialStore.Seed(supplied with
        {
            Id = "credential::different",
            UserId = OtherPersonId,
        });
        var identities = new FakePersonLinkedIdentityRepository();
        var telemetry = new CapturingPersonIdentityTelemetry();
        var runtime = BuildRuntime(
            PersonLinkedIdentityFeatureMode.Shadow,
            identities,
            credentialStore,
            telemetry);

        await runtime.TryMirrorLocalAsync(PersonId, supplied);

        identities.Stored.Should().BeEmpty();
        telemetry.Events.Should().ContainSingle(entry =>
            entry.Outcome == PersonIdentityTelemetryOutcome.Failed
            && entry.FailureCode == "shadow_write_failed");
    }

    [Fact]
    public async Task Existing_binding_to_another_person_never_changes_authority_or_merges()
    {
        var rawProfiles = new InMemoryUserRepository();
        rawProfiles.Seed(Profile(PersonId));
        var identities = new FakePersonLinkedIdentityRepository();
        identities.Seed(LinkedIdentity.Create(
            OtherPersonId,
            Observation().Locator,
            Observation().Verification,
            Now));
        var telemetry = new CapturingPersonIdentityTelemetry();
        var repository = BuildRepository(
            PersonLinkedIdentityFeatureMode.Shadow,
            rawProfiles,
            identities,
            telemetry,
            Observation());

        var loaded = await repository.GetAsync(PersonId);

        loaded!.Id.Should().Be(PersonId);
        identities.Stored.Should().ContainSingle()
            .Which.PersonId.Should().Be(OtherPersonId);
        telemetry.Events.Should().Contain(entry =>
            entry.Outcome == PersonIdentityTelemetryOutcome.Conflict
            && entry.FailureCode == "identity_already_linked");
    }

    [Fact]
    public async Task Hash_collision_fails_closed_but_does_not_block_the_legacy_read()
    {
        var rawProfiles = new InMemoryUserRepository();
        rawProfiles.Seed(Profile(PersonId));
        var observation = Observation();
        var identities = new FakePersonLinkedIdentityRepository();
        var collidingLocator = new IdentityLocator(
            IdentityLocator.EntraProvider,
            Tenant,
            "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            IdentityLocator.EntraExternalIdType);
        identities.Seed(LinkedIdentity.Create(
            OtherPersonId,
            collidingLocator,
            observation.Verification,
            Now) with
        {
            Id = observation.Locator.StableId(),
        });
        var telemetry = new CapturingPersonIdentityTelemetry();
        var repository = BuildRepository(
            PersonLinkedIdentityFeatureMode.Shadow,
            rawProfiles,
            identities,
            telemetry,
            observation);

        var loaded = await repository.GetAsync(PersonId);

        loaded!.Id.Should().Be(PersonId);
        identities.Stored.Should().ContainSingle()
            .Which.Locator.Should().Be(collidingLocator);
        telemetry.Events.Should().Contain(entry =>
            entry.Outcome == PersonIdentityTelemetryOutcome.Conflict
            && entry.FailureCode == "identity_hash_collision");
    }

    [Fact]
    public async Task Shadow_failure_is_non_blocking_visible_and_contains_no_pii()
    {
        var rawProfiles = new InMemoryUserRepository();
        rawProfiles.Seed(Profile(PersonId));
        var identities = new FakePersonLinkedIdentityRepository
        {
            Failure = new InvalidOperationException("simulated"),
        };
        var telemetry = new CapturingPersonIdentityTelemetry();
        var repository = BuildRepository(
            PersonLinkedIdentityFeatureMode.Shadow,
            rawProfiles,
            identities,
            telemetry,
            Observation());

        var loaded = await repository.GetAsync(PersonId);

        loaded!.Id.Should().Be(PersonId);
        var failure = telemetry.Events.Should().ContainSingle(entry =>
            entry.Outcome == PersonIdentityTelemetryOutcome.Failed).Subject;
        failure.FailureCode.Should().Be("shadow_write_failed");
        failure.ExceptionType.Should().Be(nameof(InvalidOperationException));
        var wire = JsonSerializer.Serialize(failure);
        wire.Should().NotContain(PersonId);
        wire.Should().NotContain(Subject);
        wire.Should().NotContain("shared@example.com");
    }

    private static PersonLinkedIdentityShadowUserRepository BuildRepository(
        PersonLinkedIdentityFeatureMode mode,
        IUserRepository profiles,
        FakePersonLinkedIdentityRepository identities,
        CapturingPersonIdentityTelemetry telemetry,
        LegacyIdentityObservation? observation)
    {
        var runtime = BuildRuntime(
            mode,
            identities,
            new FakeCredentialRepository(),
            telemetry);
        return new PersonLinkedIdentityShadowUserRepository(
            profiles,
            runtime,
            new StaticObservationSource(observation));
    }

    private static PersonLinkedIdentityShadowService BuildRuntime(
        PersonLinkedIdentityFeatureMode mode,
        FakePersonLinkedIdentityRepository identities,
        IUserCredentialRepository credentials,
        CapturingPersonIdentityTelemetry telemetry,
        IIdentitySubjectGenerator? subjectGenerator = null) =>
        new(
            new PersonLinkedIdentityOptions(mode),
            identities,
            credentials,
            subjectGenerator ?? new FixedSubjectGenerator(LocalSubject),
            new FakeClock(Now),
            telemetry);

    private static LegacyIdentityObservation Observation()
    {
        var locator = new IdentityLocator(
            IdentityLocator.EntraProvider,
            Tenant,
            Subject,
            IdentityLocator.EntraExternalIdType);
        return new LegacyIdentityObservation(
            PersonId,
            locator,
            new LinkedIdentityVerification(
                LinkedIdentityVerification.VerifiedState,
                LinkedIdentityVerification.OidcReauthenticationMethod,
                Now,
                Now,
                "https://issuer.example",
                "api://certigo"));
    }

    private static UserProfileDto Profile(string id) => new(
        id,
        "Learner",
        "learner",
        null,
        123,
        2,
        4,
        1,
        50,
        12,
        30,
        "az-900");

    private sealed class StaticObservationSource(LegacyIdentityObservation? observation)
        : ILegacyIdentityObservationSource
    {
        public LegacyIdentityObservation? Current { get; } = observation;
    }

    private sealed class FixedSubjectGenerator(string subject) : IIdentitySubjectGenerator
    {
        public int Calls { get; private set; }

        public string NewSubject()
        {
            Calls++;
            return subject;
        }
    }

    private sealed class CapturingPersonIdentityTelemetry : IPersonLinkedIdentityTelemetry
    {
        public List<PersonIdentityTelemetryEvent> Events { get; } = [];

        public void Track(PersonIdentityTelemetryEvent telemetryEvent) =>
            Events.Add(telemetryEvent);
    }

    private sealed class FakePersonLinkedIdentityRepository
        : IPersonLinkedIdentityRepository
    {
        private readonly Dictionary<string, LinkedIdentity> _stored =
            new(StringComparer.Ordinal);

        public IReadOnlyList<LinkedIdentity> Stored => _stored.Values.ToArray();
        public int CreateCalls { get; private set; }
        public Exception? Failure { get; init; }

        public void Seed(LinkedIdentity identity) => _stored[identity.Id] = identity;

        public Task<LinkedIdentity?> GetAsync(
            IdentityLocator locator,
            CancellationToken cancellationToken = default)
        {
            var identity = _stored.GetValueOrDefault(locator.StableId());
            if (identity is not null && identity.Locator != locator)
            {
                throw new IdentityHashCollisionException();
            }
            return Task.FromResult(identity);
        }

        public Task<LinkedIdentityCreateResult> CreateOrReadAsync(
            LinkedIdentity identity,
            CancellationToken cancellationToken = default)
        {
            CreateCalls++;
            if (Failure is not null)
            {
                throw Failure;
            }
            if (_stored.TryGetValue(identity.Id, out var existing))
            {
                if (existing.Locator != identity.Locator)
                {
                    throw new IdentityHashCollisionException();
                }
                if (!string.Equals(
                    existing.PersonId,
                    identity.PersonId,
                    StringComparison.Ordinal))
                {
                    throw new IdentityAlreadyLinkedException();
                }
                return Task.FromResult(new LinkedIdentityCreateResult(
                    LinkedIdentityCreateStatus.Replayed,
                    existing));
            }

            _stored.Add(identity.Id, identity);
            return Task.FromResult(new LinkedIdentityCreateResult(
                LinkedIdentityCreateStatus.Created,
                identity));
        }

        public Task<IReadOnlyList<LinkedIdentity>> ListByPersonAsync(
            string personId,
            CancellationToken cancellationToken = default)
        {
            IReadOnlyList<LinkedIdentity> result = _stored.Values
                .Where(identity => identity.PersonId == personId)
                .ToArray();
            return Task.FromResult(result);
        }

        public Task<AccountDeletionIdentityCleanupResult>
            CleanupForAccountDeletionAsync(
                string personId,
                DateTimeOffset revokedAt,
                CancellationToken cancellationToken = default)
        {
            var count = 0;
            foreach (var identity in _stored.Values
                         .Where(identity => identity.PersonId == personId)
                         .ToArray())
            {
                if (identity.Revocation.State == LinkedIdentityRevocation.RevokedState)
                {
                    continue;
                }
                _stored[identity.Id] = identity with
                {
                    Revocation = identity.Revocation with
                    {
                        State = LinkedIdentityRevocation.RevokedState,
                        Generation = identity.Revocation.Generation + 1,
                        RevokedAt = revokedAt,
                        Reason = LinkedIdentityRevocation.AccountDeletionReason,
                    },
                };
                count++;
            }
            return Task.FromResult(new AccountDeletionIdentityCleanupResult(count, 0));
        }
    }

    private sealed class FakeCredentialRepository : IUserCredentialRepository
    {
        private UserCredentialRecord? _record;
        private long _version;

        public UserCredentialRecord Seed(UserCredentialRecord record)
        {
            _record = record with { ETag = NextETag() };
            return _record;
        }

        public Task<UserCredentialRecord?> FindByEmailAsync(
            string email,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(
                _record is not null
                && string.Equals(_record.Email, email, StringComparison.OrdinalIgnoreCase)
                    ? _record
                    : null);

        public Task<UserCredentialRecord?> FindByCanonicalEmailAsync(
            string canonicalEmail,
            CancellationToken cancellationToken = default) =>
            Task.FromResult(
                _record?.CanonicalEmail == canonicalEmail
                    ? _record
                    : null);

        public Task<UserCredentialRecord> CreateAsync(
            UserCredentialRecord record,
            CancellationToken cancellationToken = default)
        {
            if (_record is not null)
            {
                throw new DuplicateRecordException("duplicate");
            }
            return Task.FromResult(Seed(record));
        }

        public Task UpdateAsync(
            UserCredentialRecord record,
            CancellationToken cancellationToken = default)
        {
            if (_record is null
                || string.IsNullOrWhiteSpace(record.ETag)
                || !string.Equals(record.ETag, _record.ETag, StringComparison.Ordinal))
            {
                throw new ConcurrencyConflictException("stale");
            }
            _record = record with { ETag = NextETag() };
            return Task.CompletedTask;
        }

        public Task<bool> DeletePendingAsync(
            UserCredentialRecord record,
            CancellationToken cancellationToken = default)
        {
            var deleted = _record?.IsProvisioning == true;
            if (deleted)
            {
                _record = null;
            }
            return Task.FromResult(deleted);
        }

        private string NextETag() =>
            $"\"{Interlocked.Increment(ref _version)}\"";
    }

    private sealed class ConcurrentSubjectCredentialRepository(
        FakeCredentialRepository inner,
        string winningSubject) : IUserCredentialRepository
    {
        private bool _conflicted;

        public Task<UserCredentialRecord?> FindByEmailAsync(
            string email,
            CancellationToken cancellationToken = default) =>
            inner.FindByEmailAsync(email, cancellationToken);

        public Task<UserCredentialRecord?> FindByCanonicalEmailAsync(
            string canonicalEmail,
            CancellationToken cancellationToken = default) =>
            inner.FindByCanonicalEmailAsync(canonicalEmail, cancellationToken);

        public Task<UserCredentialRecord> CreateAsync(
            UserCredentialRecord record,
            CancellationToken cancellationToken = default) =>
            inner.CreateAsync(record, cancellationToken);

        public async Task UpdateAsync(
            UserCredentialRecord record,
            CancellationToken cancellationToken = default)
        {
            if (!_conflicted)
            {
                _conflicted = true;
                var current = await inner.FindByEmailAsync(
                    record.Email,
                    cancellationToken)
                    ?? throw new InvalidOperationException("Credential disappeared.");
                await inner.UpdateAsync(
                    current with { IdentitySubject = winningSubject },
                    cancellationToken);
                throw new ConcurrencyConflictException(
                    "simulated concurrent identity-subject writer");
            }

            await inner.UpdateAsync(record, cancellationToken);
        }

        public Task<bool> DeletePendingAsync(
            UserCredentialRecord record,
            CancellationToken cancellationToken = default) =>
            inner.DeletePendingAsync(record, cancellationToken);
    }
}
