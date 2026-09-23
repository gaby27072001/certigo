using System.Text.Json;
using System.Text.Json.Nodes;
using FluentAssertions;
using Certigo.Application.Abstractions;
using Certigo.Application.Dtos;
using Certigo.Application.Services;
using Certigo.Domain.Content;
using Certigo.Domain.Progress;
using Xunit;

namespace Certigo.Application.Tests;

internal sealed class QuizServiceHarness
{
    public InMemoryUserRepository Users { get; } = new();
    public InMemoryProgressRepository Progress { get; } = new();
    public InMemoryLeaderboardRepository Leaderboard { get; } = new();
    public InMemoryEventRepository Events { get; } = new();
    public InMemoryAttemptRepository Attempts { get; } = new();
    public InMemoryLearnerModelRepository LearnerModels { get; } = new();
    public InMemoryEconomyOperationRepository EconomyOperations { get; } = new();
    public FakeClock Clock { get; } = new(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
    public string UserId { get; } = "user-1";
    public InMemoryContentRepository Content { get; } = TestContent.Build();

    public QuizService Build()
    {
        var content = Content;
        var context = new FakeUserContext(UserId, "Tester");
        return new QuizService(
            context,
            Clock,
            content,
            Progress,
            Attempts,
            Events,
            Users,
            Leaderboard,
            LearnerModels,
            EconomyOperations);
    }

    public static SubmitQuizRequest Request(string attemptId, params AnswerDto[] answers)
        => new(attemptId, TestContent.TrackId, new DateTimeOffset(2025, 1, 6, 11, 59, 0, TimeSpan.Zero), answers.ToList());

    public static AnswerDto Answer(string itemId, params string[] selected)
        => new(itemId, ItemType.Mcq, selected.ToList(), 5_000);
}

public sealed class QuizServiceTests
{
    [Fact]
    public async Task SubmitAsync_rejects_invalid_manifest_before_idempotency_reads()
    {
        var h = new QuizServiceHarness();
        var service = h.Build();
        var request = QuizServiceHarness.Request(
            "invalid-manifest",
            QuizServiceHarness.Answer("l1-i1", "a")) with
        {
            PublicManifestId = "sha256:not-a-digest",
        };

        var action = () => service.SubmitAsync("l1", request);

        await action.Should().ThrowAsync<ContentReleaseValidationException>()
            .WithMessage("publicManifestId must be a lowercase sha256 content identity.");
        h.EconomyOperations.GetCount.Should().Be(0);
        h.Attempts.GetByClientAttemptIdCount.Should().Be(0);
    }

    [Fact]
    public async Task SubmitAsync_rejects_duplicate_item_ids_before_rewards()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var act = () => service.SubmitAsync(
            "l1",
            QuizServiceHarness.Request(
                "duplicate-items",
                QuizServiceHarness.Answer("l1-i1", "a"),
                QuizServiceHarness.Answer("L1-I1", "a")));

        await act.Should().ThrowAsync<RequestValidationException>()
            .WithMessage("*Duplicate item id*");
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(0);
        profile.Gems.Should().Be(0);
        h.Leaderboard.Xp.Should().NotContainKey(h.UserId);
        h.Events.Events.Should().BeEmpty();
        (await h.Progress.GetMasteryAsync(h.UserId, TestContent.TrackId, "c1"))
            .Should().BeNull();
    }

    [Fact]
    public async Task SubmitAsync_correct_answer_awards_xp_gems_and_updates_leaderboard()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "a")));

        result.ScorePct.Should().Be(100);
        result.Results.Should().ContainSingle().Which.Correct.Should().BeTrue();
        result.Rewards.XpEarned.Should().BeGreaterThan(0);
        result.Rewards.GemsEarned.Should().Be(6); // 1 correct + 5 perfect bonus

        h.Leaderboard.Xp[h.UserId].Should().Be(result.Rewards.XpEarned);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(result.Rewards.XpEarned);
        profile.Gems.Should().Be(6);
        profile.DailyXpEarned.Should().Be(result.Rewards.XpEarned);

        var stored = await h.Progress.GetMasteryAsync(h.UserId, TestContent.TrackId, "c1");
        stored.Should().NotBeNull();
        stored!.Reps.Should().Be(1);
    }

    [Fact]
    public async Task SubmitAsync_is_idempotent_per_client_attempt_id()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        var request = QuizServiceHarness.Request("dup", QuizServiceHarness.Answer("l1-i1", "a"));

        var first = await service.SubmitAsync("l1", request);
        var second = await service.SubmitAsync("l1", request);

        second.AttemptId.Should().Be(first.AttemptId);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(first.Rewards.XpEarned); // not doubled
        h.Leaderboard.Xp[h.UserId].Should().Be(first.Rewards.XpEarned);
    }

    [Fact]
    public async Task SubmitAsync_returns_legacy_attempt_without_reapplying_rewards()
    {
        var h = new QuizServiceHarness();
        var result = new SubmitQuizResult(
            "legacy-result",
            100,
            new List<ItemResultDto>(),
            new RewardsDto(10, 10, false, false, 6, new List<string>()),
            new List<string>(),
            null);
        h.Users.Seed(TestContent.NewProfile(h.UserId) with { Xp = 10, Gems = 6 });
        h.Attempts.Seed(new AttemptRecord(
            "attempt::legacy",
            h.UserId,
            "legacy",
            TestContent.TrackId,
            "l1",
            h.Clock.UtcNow.AddMinutes(-1),
            h.Clock.UtcNow,
            result));

        var replay = await h.Build().SubmitAsync(
            "l1",
            QuizServiceHarness.Request("legacy", QuizServiceHarness.Answer("l1-i1", "a")));

        replay.Should().BeEquivalentTo(result);
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Xp.Should().Be(10);
        profile.Gems.Should().Be(6);
        h.Leaderboard.Xp.Should().BeEmpty();
        (await h.EconomyOperations.GetAsync(
            h.UserId,
            EconomyOperationRecord.IdFor("quiz", "legacy"))).Should().BeNull();
    }

    [Fact]
    public async Task SubmitAsync_reconciles_after_event_failure_without_double_rewards()
    {
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile("user-1"));
        var events = new InMemoryEventRepository();
        var leaderboard = new InMemoryLeaderboardRepository();
        var operations = new InMemoryEconomyOperationRepository();
        var service = new QuizService(
            new FakeUserContext("user-1", "Tester"),
            new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero)),
            TestContent.Build(),
            new InMemoryProgressRepository(),
            new InMemoryAttemptRepository(),
            new FailOnceEventRepository(events),
            users,
            leaderboard,
            new InMemoryLearnerModelRepository(),
            operations);
        var request = QuizServiceHarness.Request(
            "event-retry",
            QuizServiceHarness.Answer("l1-i1", "a"));

        var first = () => service.SubmitAsync("l1", request);
        await first.Should().ThrowAsync<InvalidOperationException>();
        var afterFailure = await users.GetAsync("user-1");
        var result = await service.SubmitAsync("l1", request);
        var afterRetry = await users.GetAsync("user-1");

        afterRetry!.Xp.Should().Be(afterFailure!.Xp);
        afterRetry.Gems.Should().Be(afterFailure.Gems);
        afterRetry.Xp.Should().Be(result.Rewards.XpEarned);
        leaderboard.Xp["user-1"].Should().Be(result.Rewards.XpEarned);
        events.Events.Count(e => e.Type == "quiz.submitted").Should().Be(1);
    }

    [Fact]
    public async Task SubmitAsync_reconciliation_preserves_newer_periods_and_progress()
    {
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile("user-1") with { LifetimePerfectLessons = 3 });
        var progress = new InMemoryProgressRepository();
        var operations = new InMemoryEconomyOperationRepository();
        var attempts = new InMemoryAttemptRepository();
        var events = new InMemoryEventRepository();
        var clock = new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var service = new QuizService(
            new FakeUserContext("user-1", "Tester"),
            clock,
            TestContent.Build(),
            progress,
            attempts,
            events,
            users,
            new InMemoryLeaderboardRepository(),
            new InMemoryLearnerModelRepository(),
            new MutateOnceOnEconomyCreateRepository(
                operations,
                () =>
                {
                    users.ForceConcurrentWrite("user-1", profile => profile with
                    {
                        DailyXpDate = new DateOnly(2025, 1, 7),
                        DailyXpEarned = 77,
                        DailyLessonsCompleted = 7,
                        DailyCorrectAnswers = 7,
                        DailyPerfectLessons = 7,
                        LastActiveDate = new DateOnly(2025, 1, 7),
                        MonthlyAnchor = new DateOnly(2025, 2, 1),
                        MonthlyXpEarned = 88,
                        MonthlyLessonsCompleted = 8,
                        MonthlyPerfectLessons = 8,
                        LifetimePerfectLessons = 4,
                    });
                    progress.Seed(
                        "user-1",
                        new ConceptMastery(
                            "user-1",
                            TestContent.TrackId,
                            "c1",
                            0.9,
                            10,
                            3,
                            clock.UtcNow.AddDays(2),
                            10,
                            0,
                            clock.UtcNow.AddDays(1)));
                }));

        var result = await service.SubmitAsync(
            "l1",
            QuizServiceHarness.Request("delayed", QuizServiceHarness.Answer("l1-i1", "a")));

        result.Rewards.AchievementsUnlocked.Should().ContainSingle().Which.Should().Be("flawless-5");
        var profile = await users.GetAsync("user-1");
        profile!.DailyXpDate.Should().Be(new DateOnly(2025, 1, 7));
        profile.DailyXpEarned.Should().Be(77);
        profile.DailyLessonsCompleted.Should().Be(7);
        profile.MonthlyAnchor.Should().Be(new DateOnly(2025, 2, 1));
        profile.MonthlyXpEarned.Should().Be(88);
        profile.LifetimePerfectLessons.Should().Be(5);
        profile.Achievements.Should().Contain("flawless-5");
        var receipt = profile.EconomyReceipts.Should().ContainSingle().Subject;
        receipt.OutcomeJson.Should().NotContain("results");
        JsonSerializer.Deserialize<RewardsDto>(
            receipt.OutcomeJson,
            new JsonSerializerOptions(JsonSerializerDefaults.Web))
            .Should().BeEquivalentTo(result.Rewards);
        var storedAttempt = await attempts.GetByClientAttemptIdAsync("user-1", "delayed");
        storedAttempt!.Result.Should().BeEquivalentTo(result);
        var submittedEvent = events.Events.Single(candidate => candidate.Type == "quiz.submitted");
        submittedEvent.Payload.Should().BeEquivalentTo(result);
        var operation = await operations.GetAsync(
            "user-1",
            EconomyOperationRecord.IdFor("quiz", "delayed"));
        JsonSerializer.Deserialize<SubmitQuizResult>(
            operation!.OutcomeJson!,
            new JsonSerializerOptions(JsonSerializerDefaults.Web))
            .Should().BeEquivalentTo(result);
        var mastery = await progress.GetMasteryAsync("user-1", TestContent.TrackId, "c1");
        mastery!.Reps.Should().Be(10);
        mastery.LastReviewedAt.Should().Be(clock.UtcNow.AddDays(1));
    }

    [Fact]
    public async Task SubmitAsync_migrates_legacy_profile_marker_without_reapplying_reward()
    {
        const string clientAttemptId = "legacy-marker";
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile("user-1"));
        var operations = new InMemoryEconomyOperationRepository();
        var operationId = EconomyOperationRecord.IdFor("quiz", clientAttemptId);
        var service = new QuizService(
            new FakeUserContext("user-1", "Tester"),
            new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero)),
            TestContent.Build(),
            new InMemoryProgressRepository(),
            new InMemoryAttemptRepository(),
            new InMemoryEventRepository(),
            users,
            new InMemoryLeaderboardRepository(),
            new InMemoryLearnerModelRepository(),
            new MutateOnceOnEconomyCreateRepository(
                operations,
                () => users.ForceConcurrentWrite(
                    "user-1",
                    profile => profile with
                    {
                        Xp = 17,
                        Gems = 6,
                        LifetimeLessonsCompleted = 1,
                        LifetimePerfectLessons = 1,
                        AppliedEconomyOperations = [operationId],
                    })));

        var result = await service.SubmitAsync(
            "l1",
            QuizServiceHarness.Request(
                clientAttemptId,
                QuizServiceHarness.Answer("l1-i1", "a")));
        var profile = await users.GetAsync("user-1");

        result.Rewards.NewXp.Should().Be(17);
        profile!.Xp.Should().Be(17);
        profile.Gems.Should().Be(6);
        profile.LifetimeLessonsCompleted.Should().Be(1);
        profile.AppliedEconomyOperations.Should().BeNull();
        profile.EconomyReceipts.Should().ContainSingle(
            receipt => receipt.OperationId == operationId);
    }

    [Fact]
    public async Task SubmitAsync_backfills_outcome_for_completed_legacy_journal()
    {
        const string clientAttemptId = "legacy-completed";
        var source = new QuizServiceHarness();
        source.Users.Seed(TestContent.NewProfile(source.UserId));
        var request = QuizServiceHarness.Request(
            clientAttemptId,
            QuizServiceHarness.Answer("l1-i1", "a"));
        var expected = await source.Build().SubmitAsync("l1", request);
        var operationId = EconomyOperationRecord.IdFor("quiz", clientAttemptId);
        var legacyOperation = await source.EconomyOperations.GetAsync(
            source.UserId,
            operationId);
        var migratedOperations = new InMemoryEconomyOperationRepository();
        migratedOperations.Seed(legacyOperation! with { OutcomeJson = null });
        var migratedUsers = new InMemoryUserRepository();
        migratedUsers.Seed((await source.Users.GetAsync(source.UserId))!);
        var service = new QuizService(
            new FakeUserContext(source.UserId, "Tester"),
            source.Clock,
            TestContent.Build(),
            new InMemoryProgressRepository(),
            new InMemoryAttemptRepository(),
            new InMemoryEventRepository(),
            migratedUsers,
            new InMemoryLeaderboardRepository(),
            new InMemoryLearnerModelRepository(),
            migratedOperations);

        var result = await service.SubmitAsync("l1", request);
        var migrated = await migratedOperations.GetAsync(source.UserId, operationId);

        result.Should().BeEquivalentTo(expected);
        migrated!.OutcomeJson.Should().NotBeNullOrWhiteSpace();
        migrated.Status.Should().Be(EconomyOperationRecord.CompletedStatus);
    }

    [Fact]
    public async Task SubmitAsync_legacy_partial_attempt_keeps_persisted_reward_set_canonical()
    {
        const string clientAttemptId = "legacy-partial";
        var source = new QuizServiceHarness();
        source.Users.Seed(TestContent.NewProfile(source.UserId));
        var request = QuizServiceHarness.Request(
            clientAttemptId,
            QuizServiceHarness.Answer("l1-i1", "a"));
        await source.Build().SubmitAsync("l1", request);
        var operationId = EconomyOperationRecord.IdFor("quiz", clientAttemptId);
        var sourceOperation = await source.EconomyOperations.GetAsync(source.UserId, operationId);
        var persistedAttempt = await source.Attempts.GetByClientAttemptIdAsync(
            source.UserId,
            clientAttemptId);
        var operations = new InMemoryEconomyOperationRepository();
        operations.Seed(sourceOperation! with
        {
            CompletedSteps = ["attempt"],
            Status = EconomyOperationRecord.PendingStatus,
            OutcomeJson = null,
        });
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile(source.UserId) with { LifetimePerfectLessons = 4 });
        var attempts = new InMemoryAttemptRepository();
        attempts.Seed(persistedAttempt!);
        var events = new InMemoryEventRepository();
        var service = new QuizService(
            new FakeUserContext(source.UserId, "Tester"),
            source.Clock,
            TestContent.Build(),
            new InMemoryProgressRepository(),
            attempts,
            events,
            users,
            new InMemoryLeaderboardRepository(),
            new InMemoryLearnerModelRepository(),
            operations);

        var result = await service.SubmitAsync("l1", request);
        var profile = await users.GetAsync(source.UserId);
        var operation = await operations.GetAsync(source.UserId, operationId);

        result.Should().BeEquivalentTo(persistedAttempt!.Result);
        profile!.LifetimePerfectLessons.Should().Be(5);
        profile.Achievements.Should().BeNullOrEmpty();
        events.Events.Single(candidate => candidate.Type == "quiz.submitted").Payload
            .Should().BeEquivalentTo(persistedAttempt.Result);
        JsonSerializer.Deserialize<SubmitQuizResult>(
            operation!.OutcomeJson!,
            new JsonSerializerOptions(JsonSerializerDefaults.Web))
            .Should().BeEquivalentTo(persistedAttempt.Result);
    }

    [Fact]
    public async Task SubmitAsync_legacy_rejected_payload_cannot_mutate_profile()
    {
        const string clientAttemptId = "legacy-rejected";
        var source = new QuizServiceHarness();
        source.Users.Seed(TestContent.NewProfile(source.UserId));
        var request = QuizServiceHarness.Request(
            clientAttemptId,
            QuizServiceHarness.Answer("l1-i1", "a")) with
        {
            StartedAt = source.Clock.UtcNow.AddMinutes(1),
        };
        await source.Build().SubmitAsync("l1", request);
        var operationId = EconomyOperationRecord.IdFor("quiz", clientAttemptId);
        var sourceOperation = await source.EconomyOperations.GetAsync(source.UserId, operationId);
        var legacyPayload = JsonNode.Parse(sourceOperation!.PayloadJson)!.AsObject();
        legacyPayload.Remove("profileMutationAllowed");
        var persistedAttempt = await source.Attempts.GetByClientAttemptIdAsync(
            source.UserId,
            clientAttemptId);
        var operations = new InMemoryEconomyOperationRepository();
        operations.Seed(sourceOperation with
        {
            PayloadJson = legacyPayload.ToJsonString(),
            CompletedSteps = ["attempt"],
            Status = EconomyOperationRecord.PendingStatus,
            OutcomeJson = null,
        });
        var users = new InMemoryUserRepository();
        users.Seed(TestContent.NewProfile(source.UserId) with
        {
            Xp = 25,
            Gems = 7,
            LifetimeLessonsCompleted = 9,
            LifetimePerfectLessons = 4,
        });
        var attempts = new InMemoryAttemptRepository();
        attempts.Seed(persistedAttempt!);
        var service = new QuizService(
            new FakeUserContext(source.UserId, "Tester"),
            source.Clock,
            TestContent.Build(),
            new InMemoryProgressRepository(),
            attempts,
            new InMemoryEventRepository(),
            users,
            new InMemoryLeaderboardRepository(),
            new InMemoryLearnerModelRepository(),
            operations);

        var result = await service.SubmitAsync("l1", request);
        var profile = await users.GetAsync(source.UserId);

        result.Should().BeEquivalentTo(persistedAttempt!.Result);
        profile!.Xp.Should().Be(25);
        profile.Gems.Should().Be(7);
        profile.LifetimeLessonsCompleted.Should().Be(9);
        profile.LifetimePerfectLessons.Should().Be(4);
        profile.Achievements.Should().BeNullOrEmpty();
    }

    [Fact]
    public async Task SubmitAsync_compacts_completed_profile_receipts_and_keeps_old_retries_idempotent()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();
        var firstRequest = QuizServiceHarness.Request(
            "receipt-0",
            QuizServiceHarness.Answer("l1-i1", "a"));
        var first = await service.SubmitAsync("l1", firstRequest);

        for (var index = 1; index <= 130; index++)
        {
            await service.SubmitAsync(
                "l1",
                QuizServiceHarness.Request(
                    $"receipt-{index}",
                    QuizServiceHarness.Answer("l1-i1", "b")));
        }

        var beforeRetry = await h.Users.GetAsync(h.UserId);
        beforeRetry!.EconomyReceipts.Should().HaveCount(128);
        beforeRetry.EconomyReceipts.Should().NotContain(
            receipt => receipt.OperationId == EconomyOperationRecord.IdFor("quiz", "receipt-0"));
        var oldestJournal = await h.EconomyOperations.GetAsync(
            h.UserId,
            EconomyOperationRecord.IdFor("quiz", "receipt-0"));
        oldestJournal!.Status.Should().Be(EconomyOperationRecord.CompletedStatus);
        oldestJournal.Ttl.Should().Be(-1);

        var replay = await service.SubmitAsync("l1", firstRequest);
        var afterRetry = await h.Users.GetAsync(h.UserId);

        replay.Should().BeEquivalentTo(first);
        afterRetry.Should().BeEquivalentTo(beforeRetry);
    }

    [Fact]
    public async Task SubmitAsync_extends_streak_when_daily_goal_met()
    {
        var h = new QuizServiceHarness();
        var today = DateOnly.FromDateTime(h.Clock.UtcNow.UtcDateTime);
        h.Users.Seed(TestContent.NewProfile(h.UserId, dailyGoalXp: 1) with
        {
            StreakDays = 3,
            LastActiveDate = today.AddDays(-1)
        });
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "a")));

        result.Rewards.StreakExtended.Should().BeTrue();
        var profile = await h.Users.GetAsync(h.UserId);
        profile!.StreakDays.Should().Be(4);
        profile.LastActiveDate.Should().Be(today);
        profile.DailyXpDate.Should().Be(today);
    }

    [Theory]
    [InlineData(ItemType.Ordering)]
    [InlineData(ItemType.Cloze)]
    [InlineData(ItemType.Applied)]
    public async Task SubmitAsync_grades_ordered_items_by_their_order(ItemType type)
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        TestContent.AddTypedLesson(h.Content, "l4", type, ["a", "b", "c"]);
        var service = h.Build();

        var wrongOrder = await service.SubmitAsync(
            "l4",
            QuizServiceHarness.Request("ordered-wrong", new AnswerDto("l4-i1", type, ["c", "b", "a"], 5_000)));
        var rightOrder = await service.SubmitAsync(
            "l4",
            QuizServiceHarness.Request("ordered-right", new AnswerDto("l4-i1", type, ["a", "b", "c"], 5_000)));

        wrongOrder.Results.Should().ContainSingle().Which.Correct.Should().BeFalse();
        rightOrder.Results.Should().ContainSingle().Which.Correct.Should().BeTrue();
    }

    [Fact]
    public async Task SubmitAsync_grades_match_pairs_as_a_set_of_pair_tokens()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        TestContent.AddTypedLesson(h.Content, "l5", ItemType.MatchPairs, ["a:y", "b:x"]);
        var service = h.Build();

        var swapped = await service.SubmitAsync(
            "l5",
            QuizServiceHarness.Request("pairs-order", new AnswerDto("l5-i1", ItemType.MatchPairs, ["b:x", "a:y"], 5_000)));
        var wrongPairs = await service.SubmitAsync(
            "l5",
            QuizServiceHarness.Request("pairs-wrong", new AnswerDto("l5-i1", ItemType.MatchPairs, ["a:x", "b:y"], 5_000)));

        swapped.Results.Should().ContainSingle().Which.Correct.Should().BeTrue();
        wrongPairs.Results.Should().ContainSingle().Which.Correct.Should().BeFalse();
    }

    [Fact]
    public async Task SubmitAsync_incorrect_answer_reveals_key_and_awards_nothing()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "b")));

        result.ScorePct.Should().Be(0);
        var item = result.Results.Should().ContainSingle().Subject;
        item.Correct.Should().BeFalse();
        item.CorrectAnswer.Should().BeEquivalentTo(new[] { "a" });
        item.Explanation.Should().NotBeNullOrEmpty();
        result.Rewards.XpEarned.Should().Be(0);
        result.Rewards.GemsEarned.Should().Be(0);
        result.Rewards.StreakExtended.Should().BeFalse();
        result.WeakConcepts.Should().Contain("c1");
    }

    [Fact]
    public async Task SubmitAsync_unlocks_achievement_awarding_bonus_gems_on_top_of_lesson_gems()
    {
        var h = new QuizServiceHarness();
        // Four prior flawless lessons: a fifth perfect lesson crosses the
        // "Sans-faute · Bronze" (flawless-5) threshold.
        h.Users.Seed(TestContent.NewProfile(h.UserId) with { LifetimePerfectLessons = 4 });
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "a")));

        result.Rewards.AchievementsUnlocked.Should().ContainSingle().Which.Should().Be("flawless-5");
        result.Rewards.GemsEarned.Should().Be(6); // lesson gems only, excludes the achievement bonus

        var profile = await h.Users.GetAsync(h.UserId);
        profile!.Achievements.Should().Contain("flawless-5");
        profile.LifetimePerfectLessons.Should().Be(5);
        profile.LifetimeLessonsCompleted.Should().Be(1);
        profile.Gems.Should().Be(26); // 6 lesson gems + 20 achievement reward
    }

    [Fact]
    public async Task SubmitAsync_recovers_the_reward_when_the_profile_write_conflicts_once()
    {
        // A concurrent non-quiz writer (e.g. a shop purchase) bumps the profile
        // between our read and our write, so the first upsert conflicts. The
        // optimistic-concurrency retry must re-read and re-apply, crediting the
        // reward exactly once — never lost, never doubled.
        var inner = new InMemoryUserRepository();
        inner.Seed(TestContent.NewProfile("user-1"));
        var users = new ConflictOnceUserRepository(inner);
        var clock = new FakeClock(new DateTimeOffset(2025, 1, 6, 12, 0, 0, TimeSpan.Zero));
        var attempts = new InMemoryAttemptRepository();
        var leaderboard = new InMemoryLeaderboardRepository();
        var service = new QuizService(
            new FakeUserContext("user-1", "Tester"),
            clock,
            TestContent.Build(),
            new InMemoryProgressRepository(),
            attempts,
            new InMemoryEventRepository(),
            users,
            leaderboard,
            new InMemoryLearnerModelRepository(),
            new InMemoryEconomyOperationRepository());

        var result = await service.SubmitAsync(
            "l1",
            QuizServiceHarness.Request("a1", QuizServiceHarness.Answer("l1-i1", "a")));

        users.UpsertCalls.Should().BeGreaterThanOrEqualTo(2); // conflicted once, then re-applied
        var profile = await inner.GetAsync("user-1");
        profile!.Xp.Should().Be(result.Rewards.XpEarned); // recovered, not lost
        profile.Gems.Should().Be(6); // applied exactly once, not doubled
        leaderboard.Xp["user-1"].Should().Be(result.Rewards.XpEarned);
    }

    [Fact]
    public async Task SubmitAsync_flags_submission_spam_via_the_rate_window()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId));
        var at = h.Clock.UtcNow;
        // 40 prior attempts in the trailing hour = the per-window cap; the 41st trips
        // the (previously dormant) AttemptRateExceeded detector.
        for (var i = 0; i < 40; i++)
        {
            h.Attempts.Seed(new AttemptRecord(
                $"attempt::seed-{i}", h.UserId, $"seed-{i}", TestContent.TrackId, "l1", at, at,
                new SubmitQuizResult($"r{i}", 100, new List<ItemResultDto>(),
                    new RewardsDto(0, 0, false, false, 0, new List<string>()),
                    new List<string>(), null)));
        }
        var service = h.Build();

        var result = await service.SubmitAsync("l1", QuizServiceHarness.Request("rate-1", QuizServiceHarness.Answer("l1-i1", "a")));

        var flagged = h.Events.Events.SingleOrDefault(e => e.Type == "attempt.flagged");
        flagged.Should().NotBeNull();
        ((AttemptIntegritySignal)flagged!.Payload).Flags.Should().Contain("AttemptRateExceeded");
        ((AttemptIntegritySignal)flagged.Payload).Decision.Should().Be("Flag");

        // La cadence seule est un signal mou (Flag) : on détecte mais on NE sanctionne PAS.
        // Les récompenses restent créditées, le leaderboard est mis à jour.
        result.Rewards.XpEarned.Should().BeGreaterThan(0);
        h.Leaderboard.Xp[h.UserId].Should().Be(result.Rewards.XpEarned);
    }

    [Fact]
    public async Task SubmitAsync_integrity_rejection_persists_audit_without_profile_progress()
    {
        var h = new QuizServiceHarness();
        h.Users.Seed(TestContent.NewProfile(h.UserId) with
        {
            Xp = 25,
            Gems = 7,
            LifetimeLessonsCompleted = 9,
            LifetimePerfectLessons = 4,
        });
        var request = QuizServiceHarness.Request(
            "rejected-profile",
            QuizServiceHarness.Answer("l1-i1", "a")) with
        {
            StartedAt = h.Clock.UtcNow.AddMinutes(1),
        };

        var result = await h.Build().SubmitAsync("l1", request);
        var profile = await h.Users.GetAsync(h.UserId);

        result.Rewards.XpEarned.Should().Be(0);
        profile!.Xp.Should().Be(25);
        profile.Gems.Should().Be(7);
        profile.LifetimeLessonsCompleted.Should().Be(9);
        profile.LifetimePerfectLessons.Should().Be(4);
        profile.Achievements.Should().BeNullOrEmpty();
        profile.EconomyReceipts.Should().ContainSingle();
        h.Leaderboard.Xp.Should().BeEmpty();
    }
}

/// Wraps the in-memory user repo to throw a single optimistic-concurrency conflict
/// on the first write, simulating a competing writer. Subsequent writes delegate.
internal sealed class ConflictOnceUserRepository(InMemoryUserRepository inner) : IUserRepository
{
    private bool _thrown;

    public int UpsertCalls { get; private set; }

    public Task<UserProfileDto?> GetAsync(string userId, CancellationToken cancellationToken = default)
        => inner.GetAsync(userId, cancellationToken);

    public Task<UserProfileDto?> FindByHandleAsync(string handle, CancellationToken cancellationToken = default)
        => inner.FindByHandleAsync(handle, cancellationToken);

    public Task<UserProfileDto> UpsertAsync(UserProfileDto profile, CancellationToken cancellationToken = default)
    {
        UpsertCalls++;
        if (!_thrown)
        {
            _thrown = true;
            throw new ConcurrencyConflictException("simulated concurrent write");
        }

        return inner.UpsertAsync(profile, cancellationToken);
    }
}
