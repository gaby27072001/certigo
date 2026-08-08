using System.Text.Json;
using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
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
