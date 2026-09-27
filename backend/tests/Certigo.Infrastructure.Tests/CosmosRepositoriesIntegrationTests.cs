using System.Text.Json;
using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Domain.Identity;
using Certigo.Domain.Organizations;
using Certigo.Infrastructure.Cosmos;
using Xunit;

namespace Certigo.Infrastructure.Tests;

/// <summary>
/// Round-trip integration tests for the Cosmos repository layer, executed against
/// a local Azure Cosmos DB emulator. They are gated behind
/// <see cref="CosmosEmulatorFactAttribute"/> (see <see cref="CosmosEmulatorFixture"/>),
/// so by default they report as skipped.
///
/// The behaviours asserted here are precisely the ones an in-memory fake cannot
/// prove, because they depend on real Cosmos semantics:
///   • optimistic concurrency on user upsert (ETag / HTTP 412),
///   • idempotent friend removal (HTTP 404 swallowed),
///   • idempotent attempt creation (HTTP 409),
///   • the recent-activity SQL aggregate (COUNT/SUM) that backs the anti-cheat
///     rate window introduced for the exam path.
/// One <see cref="CosmosEmulatorFixture"/> (one ephemeral database) is shared by the
/// whole class; every test uses freshly-generated ids, so they never collide.
/// </summary>
[Trait(CosmosEmulatorFixture.TraitName, CosmosEmulatorFixture.TraitValue)]
public sealed class CosmosRepositoriesIntegrationTests(CosmosEmulatorFixture fixture)
    : IClassFixture<CosmosEmulatorFixture>
{
    [CosmosEmulatorFact]
    public async Task User_upsert_then_get_round_trips_and_populates_etag()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosUserRepository(context);
        var profile = NewProfile();

        await repository.UpsertAsync(profile);
        var loaded = await repository.GetAsync(profile.Id);

        loaded.Should().NotBeNull();
        loaded!.DisplayName.Should().Be(profile.DisplayName);
        loaded.Handle.Should().Be(profile.Handle);
        loaded.Xp.Should().Be(profile.Xp);
        loaded.Gems.Should().Be(profile.Gems);
        loaded.ActiveTrackId.Should().Be(profile.ActiveTrackId);
        loaded.ETag.Should().NotBeNullOrEmpty("Cosmos stamps the system _etag on every read");
    }

    [CosmosEmulatorFact]
    public async Task User_find_by_handle_matches_then_misses()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosUserRepository(context);
        var profile = NewProfile();

        await repository.UpsertAsync(profile);

        var byHandle = await repository.FindByHandleAsync(profile.Handle);
        byHandle.Should().NotBeNull();
        byHandle!.Id.Should().Be(profile.Id);

        var missing = await repository.FindByHandleAsync($"unknown-{Guid.NewGuid():N}");
        missing.Should().BeNull();
    }

    [CosmosEmulatorFact]
    public async Task User_upsert_with_stale_etag_throws_concurrency_conflict()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosUserRepository(context);
        var profile = NewProfile();

        await repository.UpsertAsync(profile);
        var firstRead = await repository.GetAsync(profile.Id);
        firstRead!.ETag.Should().NotBeNullOrEmpty();

        // A second writer advances the stored ETag out from under `firstRead`.
        await repository.UpsertAsync(firstRead with { Xp = firstRead.Xp + 50 });

        // Re-applying the now-stale ETag must surface as a domain-level conflict.
        Func<Task> staleWrite = () => repository.UpsertAsync(firstRead with { Xp = 999 });
        await staleWrite.Should().ThrowAsync<ConcurrencyConflictException>();
    }

    [CosmosEmulatorFact]
    public async Task Friend_lifecycle_is_idempotent_on_remove()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosFriendRepository(context);
        var userId = $"user-{Guid.NewGuid():N}";
        var friendUserId = $"friend-{Guid.NewGuid():N}";

        // GetAsync/RemoveAsync derive the document id as "{userId}:{friendUserId}",
        // so the stored edge must use exactly that id to be addressable.
        var edge = new FriendEdge($"{userId}:{friendUserId}", userId, friendUserId, DateTimeOffset.UtcNow);

        await repository.UpsertAsync(edge);

        (await repository.ListAsync(userId)).Should().ContainSingle(e => e.FriendUserId == friendUserId);
        (await repository.GetAsync(userId, friendUserId)).Should().NotBeNull();

        await repository.RemoveAsync(userId, friendUserId);
        (await repository.GetAsync(userId, friendUserId)).Should().BeNull();

        // Removing an already-removed edge is a no-op, not a 404.
        Func<Task> removeAgain = () => repository.RemoveAsync(userId, friendUserId);
        await removeAgain.Should().NotThrowAsync();
    }

    [CosmosEmulatorFact]
    public async Task Attempt_create_is_idempotent_on_duplicate_id()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosAttemptRepository(context);
        var userId = $"user-{Guid.NewGuid():N}";
        var attempt = NewAttempt(userId, xpEarned: 25, submittedAt: DateTimeOffset.UtcNow);

        await repository.CreateAsync(attempt);

        // The same id within the same partition must fail the create (409), not
        // double-apply — this is the atomic idempotency guard.
        Func<Task> duplicate = () => repository.CreateAsync(attempt);
        await duplicate.Should().ThrowAsync<DuplicateRecordException>();
    }

    [CosmosEmulatorFact]
    public async Task Canonical_email_reservation_has_one_concurrent_winner()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosUserCredentialRepository(context);
        var canonical = $"test-{Guid.NewGuid():N}@gmail.com";
        var id = UserCredentialRecord.CanonicalIdFor(canonical);
        var now = DateTimeOffset.UtcNow;
        var first = new UserCredentialRecord(
            id,
            $"t.e.s.t+one-{Guid.NewGuid():N}@gmail.com",
            $"user-{Guid.NewGuid():N}",
            "First",
            "hash",
            now,
            CanonicalEmail: canonical,
            ProvisioningState: CredentialProvisioningState.Pending,
            ProvisioningLeaseExpiresAt: now.AddMinutes(2));
        var second = first with
        {
            Email = canonical,
            UserId = $"user-{Guid.NewGuid():N}",
            DisplayName = "Second",
        };

        var outcomes = await Task.WhenAll(new[] { first, second }.Select(async record =>
        {
            try
            {
                await repository.CreateAsync(record);
                return true;
            }
            catch (DuplicateRecordException)
            {
                return false;
            }
        }));

        outcomes.Should().ContainSingle(success => success);
        (await repository.FindByCanonicalEmailAsync(canonical))!.Id.Should().Be(id);
    }

    [CosmosEmulatorFact]
    public async Task Legacy_credential_is_found_by_normalized_email_before_canonical_fallback()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosUserCredentialRepository(context);
        var email = $"legacy-{Guid.NewGuid():N}@example.com";
        var legacy = await repository.CreateAsync(new UserCredentialRecord(
            UserCredentialRecord.IdFor(email),
            email,
            $"user-{Guid.NewGuid():N}",
            "Legacy",
            "original-hash",
            DateTimeOffset.UtcNow));

        var found = await repository.FindByEmailAsync(email.ToUpperInvariant());

        found.Should().NotBeNull();
        found!.Id.Should().Be(legacy.Id);
        found.UserId.Should().Be(legacy.UserId);
        found.PasswordHash.Should().Be(legacy.PasswordHash);
        found.ETag.Should().Be(legacy.ETag);
        (await repository.FindByCanonicalEmailAsync(email)).Should().BeNull();
    }

    [CosmosEmulatorFact]
    public async Task Linked_identity_create_replays_and_hash_collision_fails_closed()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosPersonLinkedIdentityRepository(context);
        var now = DateTimeOffset.UtcNow;
        var personId = $"person-{Guid.NewGuid():N}";
        var locator = new IdentityLocator(
            IdentityLocator.LocalProvider,
            IdentityLocator.LocalTenant,
            PersonIdentityDocumentIds.Hash("local-subject", personId),
            IdentityLocator.LocalPasswordType);
        var verification = new LinkedIdentityVerification(
            LinkedIdentityVerification.VerifiedState,
            LinkedIdentityVerification.LegacyCredentialBackfillMethod,
            now,
            now,
            null,
            null);
        var candidate = LinkedIdentity.Create(personId, locator, verification, now);

        var created = await repository.CreateOrReadAsync(candidate);
        var replay = await repository.CreateOrReadAsync(candidate);

        created.Status.Should().Be(LinkedIdentityCreateStatus.Created);
        replay.Status.Should().Be(LinkedIdentityCreateStatus.Replayed);
        replay.Identity.Should().BeEquivalentTo(created.Identity);

        var collisionLocator = new IdentityLocator(
            IdentityLocator.EntraProvider,
            "11111111-1111-4111-8111-aaaaaaaaaaaa",
            "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            IdentityLocator.EntraExternalIdType);
        var collisionCandidate = LinkedIdentity.Create(
            $"person-{Guid.NewGuid():N}",
            collisionLocator,
            verification,
            now);
        var differentLocator = new IdentityLocator(
            IdentityLocator.EntraProvider,
            "11111111-1111-4111-8111-aaaaaaaaaaaa",
            "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
            IdentityLocator.EntraExternalIdType);
        var collidingDocument = LinkedIdentity.Create(
            $"person-{Guid.NewGuid():N}",
            differentLocator,
            verification,
            now) with
        {
            Id = collisionCandidate.Id,
        };
        await context.Users.CreateItemAsync(
            collidingDocument,
            new Microsoft.Azure.Cosmos.PartitionKey(collisionCandidate.Id));

        Func<Task> collision = () => repository.CreateOrReadAsync(collisionCandidate);

        await collision.Should().ThrowAsync<IdentityHashCollisionException>();
        var persisted = await context.Users.ReadItemAsync<LinkedIdentity>(
            collisionCandidate.Id,
            new Microsoft.Azure.Cosmos.PartitionKey(collisionCandidate.Id));
        persisted.Resource.Locator.Should().Be(differentLocator);
    }

    [CosmosEmulatorFact]
    public async Task Durable_economy_operation_resumes_steps_with_etag()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosEconomyOperationRepository(context);
        var userId = $"user-{Guid.NewGuid():N}";
        var now = DateTimeOffset.UtcNow;
        var candidate = new EconomyOperationRecord(
            EconomyOperationRecord.IdFor("quiz", Guid.NewGuid().ToString("N")),
            userId,
            "quiz",
            "attempt",
            "{}",
            ["profile", "events"],
            [],
            EconomyOperationRecord.PendingStatus,
            now,
            now);

        var created = await repository.GetOrCreateAsync(candidate);
        var withOutcome = await repository.SetOutcomeAsync(
            userId,
            created.Id,
            "{\"attemptId\":\"result-1\"}");
        var afterProfile = await repository.MarkStepCompletedAsync(userId, created.Id, "profile");
        var completed = await repository.MarkStepCompletedAsync(userId, created.Id, "events");

        created.ETag.Should().NotBeNullOrEmpty();
        withOutcome.OutcomeJson.Should().Be("{\"attemptId\":\"result-1\"}");
        withOutcome.Ttl.Should().Be(-1);
        afterProfile.Status.Should().Be(EconomyOperationRecord.PendingStatus);
        completed.Status.Should().Be(EconomyOperationRecord.CompletedStatus);
        completed.CompletedSteps.Should().BeEquivalentTo(["profile", "events"]);
    }

    [CosmosEmulatorFact]
    public async Task Account_deletion_removes_user_partitions_and_keeps_only_pseudonymous_tombstone()
    {
        var context = await fixture.GetContextAsync();
        var users = new CosmosUserRepository(context);
        var credentials = new CosmosUserCredentialRepository(context);
        var friends = new CosmosFriendRepository(context);
        var attempts = new CosmosAttemptRepository(context);
        var identityRepository = new CosmosPersonLinkedIdentityRepository(context);
        var deletion = new CosmosAccountDeletionRepository(
            context,
            identityRepository);
        var profile = NewProfile();
        var now = DateTimeOffset.UtcNow;
        var friendId = $"friend-{Guid.NewGuid():N}";
        await users.UpsertAsync(profile);
        await credentials.CreateAsync(new UserCredentialRecord(
            UserCredentialRecord.CanonicalIdFor($"{profile.Id}@example.com"),
            $"{profile.Id}@example.com",
            profile.Id,
            profile.DisplayName,
            "hash",
            now,
            CanonicalEmail: $"{profile.Id}@example.com",
            ProvisioningState: CredentialProvisioningState.Active,
            IdentitySubject: PersonIdentityDocumentIds.Hash(
                "deletion-local-subject",
                profile.Id)));
        var identityLocator = new IdentityLocator(
            IdentityLocator.LocalProvider,
            IdentityLocator.LocalTenant,
            PersonIdentityDocumentIds.Hash("deletion-local-subject", profile.Id),
            IdentityLocator.LocalPasswordType);
        await identityRepository.CreateOrReadAsync(LinkedIdentity.Create(
            profile.Id,
            identityLocator,
            new LinkedIdentityVerification(
                LinkedIdentityVerification.VerifiedState,
                LinkedIdentityVerification.LegacyCredentialBackfillMethod,
                now,
                now,
                null,
                null),
            now));
        var intent = new IdentityLinkIntent(
            IdentityLinkIntent.IdFor(profile.Id, "integration-intent"),
            IdentityLinkIntent.CurrentSchemaVersion,
            profile.Id,
            identityLocator.StableId(),
            IdentityLocator.EntraProvider,
            "11111111-1111-4111-8111-aaaaaaaaaaaa",
            IdentityLocator.EntraExternalIdType,
            new string('a', 64),
            new string('b', 64),
            "pending",
            now,
            now.AddMinutes(5));
        var operation = new IdentityLinkOperation(
            IdentityLinkOperation.IdFor(profile.Id, "integration-operation"),
            IdentityLinkOperation.CurrentSchemaVersion,
            profile.Id,
            intent.Id,
            null,
            new string('c', 64),
            new string('d', 64),
            "pending",
            null,
            now,
            now);
        await context.Users.CreateItemAsync(
            intent,
            new Microsoft.Azure.Cosmos.PartitionKey(intent.Id));
        await context.Users.CreateItemAsync(
            operation,
            new Microsoft.Azure.Cosmos.PartitionKey(operation.Id));
        await friends.UpsertAsync(new FriendEdge(
            $"{profile.Id}:{friendId}",
            profile.Id,
            friendId,
            DateTimeOffset.UtcNow));
        await friends.UpsertAsync(new FriendEdge(
            $"{friendId}:{profile.Id}",
            friendId,
            profile.Id,
            DateTimeOffset.UtcNow));
        var attempt = NewAttempt(
            profile.Id,
            xpEarned: 10,
            submittedAt: DateTimeOffset.UtcNow);
        await attempts.CreateAsync(attempt);

        var subjectHash = AccountDeletionSubject.Hash(profile.Id);
        await using var admittedMutation =
            await context.AcquireAccountWriteLeaseAsync(profile.Id);
        await deletion.GetOrCreateAsync(new AccountDeletionRecord(
            AccountDeletionRecord.RecordId,
            subjectHash,
            profile.Id,
            Guid.NewGuid().ToString("n"),
            AccountIdentityKind.Local,
            ["social", "learning", "economy", "profile", "identity", "reconciliation"],
            [],
            AccountDeletionRecordStatus.Pending,
            DateTimeOffset.UtcNow,
            DateTimeOffset.UtcNow));

        (await context.HasActiveAccountWriteLeasesAsync(subjectHash)).Should().BeTrue();
        await admittedMutation.DisposeAsync();
        (await context.HasActiveAccountWriteLeasesAsync(subjectHash)).Should().BeFalse();

        Func<Task> recreateProfile = () => users.UpsertAsync(profile with { ETag = null });
        await recreateProfile.Should().ThrowAsync<AccountDeletionInProgressException>();
        Func<Task> recreateAttempt = () => attempts.CreateAsync(NewAttempt(
            profile.Id,
            xpEarned: 99,
            submittedAt: DateTimeOffset.UtcNow));
        await recreateAttempt.Should().ThrowAsync<AccountDeletionInProgressException>();
        Func<Task> recreateFriend = () => friends.UpsertAsync(new FriendEdge(
            $"{friendId}:{profile.Id}",
            friendId,
            profile.Id,
            DateTimeOffset.UtcNow));
        await recreateFriend.Should().ThrowAsync<AccountDeletionInProgressException>();

        (await deletion.ResolveIdentityKindAsync(profile.Id)).Should()
            .Be(AccountIdentityKind.Local);
        await deletion.ReconcileDataAsync(profile.Id);
        await deletion.DeleteLinkedIdentityDataAsync(profile.Id, now);
        var tombstone = await deletion.MarkCompletedAsync(
            subjectHash,
            DateTimeOffset.UtcNow,
            (int)TimeSpan.FromDays(30).TotalSeconds);
        var replayedFailure = await deletion.MarkFailureAsync(
            subjectHash,
            "late-concurrent-failure",
            DateTimeOffset.UtcNow,
            DateTimeOffset.UtcNow.AddMinutes(1));

        (await users.GetAsync(profile.Id)).Should().BeNull();
        (await credentials.FindByEmailAsync($"{profile.Id}@example.com")).Should().BeNull();
        (await friends.GetAsync(profile.Id, friendId)).Should().BeNull();
        (await friends.GetAsync(friendId, profile.Id)).Should().BeNull();
        (await attempts.GetByClientAttemptIdAsync(profile.Id, attempt.ClientAttemptId))
            .Should().BeNull();
        var linkedIdentityTombstone = await identityRepository.GetAsync(identityLocator);
        linkedIdentityTombstone.Should().NotBeNull();
        linkedIdentityTombstone!.Revocation.State.Should()
            .Be(LinkedIdentityRevocation.RevokedState);
        linkedIdentityTombstone.Revocation.Generation.Should().Be(2);
        linkedIdentityTombstone.Revocation.Reason.Should()
            .Be(LinkedIdentityRevocation.AccountDeletionReason);
        (await context.Users.ReadOrDefaultAsync<IdentityLinkIntent>(
            intent.Id,
            new Microsoft.Azure.Cosmos.PartitionKey(intent.Id))).Should().BeNull();
        (await context.Users.ReadOrDefaultAsync<IdentityLinkOperation>(
            operation.Id,
            new Microsoft.Azure.Cosmos.PartitionKey(operation.Id))).Should().BeNull();
        tombstone.SubjectUserId.Should().BeNull();
        tombstone.UserId.Should().Be(subjectHash);
        tombstone.Ttl.Should().Be((int)TimeSpan.FromDays(30).TotalSeconds);
        replayedFailure.Status.Should().Be(AccountDeletionRecordStatus.Completed);
        replayedFailure.FailureCode.Should().BeNull();
    }

    [CosmosEmulatorFact]
    public async Task Attempt_recent_activity_aggregates_count_and_xp_within_window()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosAttemptRepository(context);
        var userId = $"user-{Guid.NewGuid():N}";
        var now = DateTimeOffset.UtcNow;

        await repository.CreateAsync(NewAttempt(userId, xpEarned: 10, submittedAt: now.AddMinutes(-30)));
        await repository.CreateAsync(NewAttempt(userId, xpEarned: 20, submittedAt: now.AddMinutes(-20)));
        await repository.CreateAsync(NewAttempt(userId, xpEarned: 30, submittedAt: now.AddMinutes(-10)));

        var within = await repository.GetRecentActivityAsync(userId, now.AddHours(-1));
        within.Attempts.Should().Be(3);
        within.Xp.Should().Be(60);

        // The window is inclusive of `since`; a future cutoff excludes everything,
        // and SUM over the empty set coalesces to 0 rather than null.
        var future = await repository.GetRecentActivityAsync(userId, now.AddMinutes(5));
        future.Attempts.Should().Be(0);
        future.Xp.Should().Be(0);
    }

    [CosmosEmulatorFact]
    public async Task Issued_exam_round_trips_with_ttl_and_is_user_scoped()
    {
        var context = await fixture.GetContextAsync();
        var repository = new CosmosExamRepository(context);
        var userId = $"user-{Guid.NewGuid():N}";
        var now = DateTimeOffset.UtcNow;
        var exam = NewExam(userId, now);

        await repository.CreateAsync(exam);

        var loaded = await repository.GetAsync(userId, exam.ExamId);
        loaded.Should().BeEquivalentTo(exam);
        loaded!.Kind.Should().Be("exam-issued");
        loaded.Ttl.Should().Be(86_700);
        (await repository.GetAsync("different-user", exam.ExamId)).Should().BeNull();

        using var rawResponse = await context.Attempts.ReadItemStreamAsync(
            exam.Id,
            new Microsoft.Azure.Cosmos.PartitionKey(userId));
        using var rawDocument = await JsonDocument.ParseAsync(rawResponse.Content);
        rawDocument.RootElement.TryGetProperty("ttl", out var ttlProperty).Should().BeTrue();
        ttlProperty.GetInt32().Should().Be(86_700);

        var container = await context.Attempts.ReadContainerAsync();
        container.Resource.DefaultTimeToLive.Should().Be(-1);

        Func<Task> duplicate = () => repository.CreateAsync(exam);
        await duplicate.Should().ThrowAsync<DuplicateRecordException>();
    }

    [CosmosEmulatorFact]
    public async Task Team_membership_volumetry_observation_counts_seeded_memberships_uncapped()
    {
        var context = await fixture.GetContextAsync();
        var receipts = new CosmosEnterpriseLearningMetricReceiptRepository(context);
        var metrics = new CosmosEnterpriseLearningMetricsRepository(context, receipts);
        var telemetry = new RecordingOrganizationTelemetry();
        var repository = new CosmosOrganizationRepository(context, receipts, metrics, telemetry);
        var organizationId = $"org-{Guid.NewGuid():N}";
        var teamId = $"team-{Guid.NewGuid():N}";
        var seeded = Enumerable.Range(0, 3)
            .Select(index => OrganizationTeamMembership.Create(
                organizationId,
                teamId,
                $"person-{index}-{Guid.NewGuid():N}",
                DateTimeOffset.UtcNow))
            .ToArray();
        foreach (var membership in seeded)
        {
            await context.Organizations.CreateItemAsync(
                membership,
                new Microsoft.Azure.Cosmos.PartitionKey(organizationId));
        }

        var observation = await repository.CountTeamMembershipsAsync();

        // The container is shared across the whole test class, so other concurrently-seeded
        // organizations may also contribute team memberships; this only asserts a floor.
        observation.TeamMembershipCountLowerBound.Should().BeGreaterOrEqualTo(3);
        observation.Capped.Should().BeFalse("far fewer than the 10,000-document observation cap were seeded");
        telemetry.Events.Should().Contain(item =>
            item.Operation == OrganizationTelemetryOperation.ObserveTeamMembershipVolumetry
            && item.Outcome == OrganizationTelemetryOutcome.Observed
            && item.RequestChargeRequestUnits > 0
            && item.Capped == false);
    }

    private sealed class RecordingOrganizationTelemetry : IOrganizationTelemetry
    {
        public List<OrganizationTelemetryEvent> Events { get; } = [];

        public void Track(OrganizationTelemetryEvent telemetryEvent) => Events.Add(telemetryEvent);
    }

    private static UserProfileDto NewProfile() => new(
        Id: $"user-{Guid.NewGuid():N}",
        DisplayName: "Integration Tester",
        Handle: $"handle-{Guid.NewGuid():N}",
        AvatarUrl: null,
        Xp: 1200,
        Level: 5,
        StreakDays: 7,
        FreezeTokens: 1,
        DailyGoalXp: 50,
        DailyXpEarned: 20,
        Gems: 300,
        ActiveTrackId: "az-900");

    private static AttemptRecord NewAttempt(string userId, int xpEarned, DateTimeOffset submittedAt)
    {
        var attemptId = $"attempt-{Guid.NewGuid():N}";
        var rewards = new RewardsDto(
            XpEarned: xpEarned,
            NewXp: xpEarned,
            LevelUp: false,
            StreakExtended: false,
            GemsEarned: 0,
            AchievementsUnlocked: []);
        var result = new SubmitQuizResult(
            AttemptId: attemptId,
            ScorePct: 100,
            Results: [],
            Rewards: rewards,
            WeakConcepts: [],
            NextReviewDueAt: null);
        return new AttemptRecord(
            Id: attemptId,
            UserId: userId,
            ClientAttemptId: $"client-{Guid.NewGuid():N}",
            TrackId: "az-900",
            LessonId: "lesson-1",
            StartedAt: submittedAt.AddMinutes(-1),
            SubmittedAt: submittedAt,
            Result: result);
    }

    private static ExamRecord NewExam(string userId, DateTimeOffset createdAt)
    {
        var examId = Guid.NewGuid().ToString("N");
        const int durationSeconds = 300;
        return new ExamRecord(
            Id: $"exam::{examId}",
            UserId: userId,
            ExamId: examId,
            TrackId: "az-900",
            ItemIds: ["item-1", "item-2"],
            CreatedAt: createdAt,
            DurationSeconds: durationSeconds,
            ExpiresAt: createdAt.AddSeconds(durationSeconds),
            Ttl: durationSeconds + (int)TimeSpan.FromDays(1).TotalSeconds);
    }
}
